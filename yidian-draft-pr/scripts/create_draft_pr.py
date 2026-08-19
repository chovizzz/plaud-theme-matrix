#!/usr/bin/env python3
"""Create a yidian Draft PR.

Any base branch is allowed. What this script still enforces:

- the PR is created as a Draft (`gh pr create --draft`);
- `--head` is explicit and is not the base branch itself (the workflow always puts
  the cherry-picked commits on a separate PR branch);
- the body carries the five required yidian sections;
- nothing outside the Shopify theme rides along -- junk (editor/agent droppings,
  caches, archives) is refused outright, anything else non-theme needs an explicit
  --allow-nontheme per path, meaning the user was asked. Same classification module
  as `check_theme_files.py`, so the pre-push check and this one cannot disagree.

There is no flag to skip the file gate. If it cannot evaluate the branch, the run
is refused -- a gate that opens when it cannot see is not a gate.

The gate reads the LOCAL repo, so what it inspects must be what GitHub will see:

- run it from inside a checkout of the target repository (with --repo, one of that
  checkout's remotes must point at OWNER/REPO, and that remote is the one used);
- both refs are read from the REMOTE with `git ls-remote`, not from local
  tracking refs, which can be stale in either direction. The head branch must
  already be pushed and the remote must be at the local commit; the base is
  compared at whatever commit the remote branch is on right now.

Cross-fork PRs (head on a fork, base upstream) are not supported.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from theme_files import GitError, evaluate, git, render  # noqa: E402

DEFAULT_BODY = """## Summary
- 待补充：本 PR 的业务目的和主要改动

## Test Plan / Verification Evidence
- Shopify preview: 待补充：Shopify preview URL
- Manual verification: 待补充：实际验收步骤和结果
- Screenshots / Recording: 待补充：截图或录屏链接

## Risk / Rollback
- 主要风险：待补充：影响范围、潜在回归点和验证范围
- 回滚方案：待补充：可执行回滚方式

## Regression Matrix
- Desktop ≥1025: 待补充
- Tablet 768-1024: 待补充
- Mobile ≤767: 待补充
- Related schema/block/effect switches: 待补充

## Commits
- 待补充：cherry-picked commit SHA 和 message
"""


def run(args: list[str]) -> int:
    completed = subprocess.run(args)
    return completed.returncode


REQUIRED_SECTIONS = (
    "Summary",
    "Test Plan / Verification Evidence",
    "Risk / Rollback",
    "Regression Matrix",
    "Commits",
)


def has_heading(body: str, title: str) -> bool:
    """True only for a real `## <title>` line.

    Substring matching would accept a heading buried in an HTML comment or in a
    fenced code block quoting the template, which is exactly how a body with no
    real sections slips through.
    """
    pattern = rf"^[ \t]*##[ \t]+{re.escape(title)}[ \t]*$"
    return re.search(pattern, body, re.MULTILINE) is not None


def check_body(body: str) -> None:
    missing = [f"## {h}" for h in REQUIRED_SECTIONS if not has_heading(body, h)]
    if missing:
        raise SystemExit(
            "Refusing PR: body is missing required section(s): " + ", ".join(missing)
        )


def read_body(args: argparse.Namespace) -> str:
    if args.body and args.body_file:
        raise SystemExit("Use only one of --body or --body-file.")
    if args.body_file:
        return Path(args.body_file).read_text(encoding="utf-8")
    return args.body or DEFAULT_BODY


def normalize_repo(value: str) -> tuple[str | None, str]:
    """(host, owner/repo) from a repo argument or a remote URL, lowercased.

    Accepts `owner/repo`, `HOST/owner/repo`, `git@host:owner/repo`,
    `ssh://git@host/owner/repo`, `https://host/owner/repo`, with or without a
    trailing `.git` or `/`. host is None when the value carried none -- a bare
    `owner/repo` matches any host, but an explicit host must match, so
    `ghe.example/owner/repo` never binds to a github.com remote.
    """
    v = value.strip().lower().rstrip("/")
    if v.endswith(".git"):
        v = v[: -len(".git")]
    v = v.rstrip("/")
    if "://" in v:
        v = v.split("://", 1)[1]
    if "@" in v and "/" not in v.split("@", 1)[0]:
        v = v.split("@", 1)[1]
    v = v.replace(":", "/")
    parts = [p for p in v.split("/") if p]
    host = parts[-3] if len(parts) >= 3 else None
    return host, "/".join(parts[-2:])


def remotes_for_repo(repo: str) -> list[str]:
    """Names of the remotes that point at OWNER/REPO."""
    try:
        raw = git(["remote", "-v"])
    except GitError:
        return []
    want_host, want_repo = normalize_repo(repo)
    found: list[str] = []
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        host, name = normalize_repo(parts[1])
        if name != want_repo:
            continue
        if want_host is not None and host is not None and host != want_host:
            continue
        if parts[0] not in found:
            found.append(parts[0])
    return found


def resolve_remote(args: argparse.Namespace) -> str:
    if not args.repo:
        try:
            git(["remote", "get-url", "origin"])
        except GitError:
            raise SystemExit(
                "Refusing PR: this checkout has no `origin` remote, so the changed-file "
                "gate cannot tell which repository the PR is against. Pass --repo "
                "OWNER/REPO from a checkout of that repository."
            )
        return "origin"

    matches = remotes_for_repo(args.repo)
    if not matches:
        raise SystemExit(
            f"Refusing PR: --repo {args.repo} is not a remote of this checkout, so the "
            "changed-file gate would be reading an unrelated diff. Run this from a "
            "checkout of that repository. Cross-fork PRs are not supported."
        )
    if len(matches) > 1:
        raise SystemExit(
            f"Refusing PR: {args.repo} matches several remotes ({', '.join(matches)}), "
            "so the gate cannot tell which one the PR is against. Run from a checkout "
            "with a single remote for that repository, or remove the duplicate."
        )
    return matches[0]


def remote_branch_sha(remote: str, branch: str) -> str | None:
    """The branch's commit ON THE REMOTE, right now.

    `ls-remote`, not the local `<remote>/<branch>` tracking ref: that ref is a
    cache, and it goes stale in both directions -- someone else pushing to the PR
    branch would leave the gate approving a diff GitHub no longer has.
    """
    try:
        out = git(["ls-remote", "--exit-code", "--heads", remote, f"refs/heads/{branch}"])
    except GitError:
        return None
    line = out.strip().splitlines()[0] if out.strip() else ""
    return line.split("\t")[0].strip() if line else None


def local_sha(ref: str) -> str:
    try:
        return git(["rev-parse", "--verify", f"{ref}^{{commit}}"]).strip()
    except GitError:
        raise SystemExit(f"Refusing PR: cannot resolve ref '{ref}' in this checkout.")


def have_commit(sha: str) -> bool:
    try:
        git(["cat-file", "-e", f"{sha}^{{commit}}"])
        return True
    except GitError:
        return False


def resolve_refs(remote: str, base: str, head: str) -> tuple[str, str]:
    """(base_sha, head_sha) as the REMOTE has them, verified against local."""
    head_remote = remote_branch_sha(remote, head)
    if head_remote is None:
        raise SystemExit(
            f"Refusing PR: {remote} has no branch '{head}'. Push it first "
            f"(`git push -u {remote} {head}`) so the PR ships what was just checked."
        )
    head_local = local_sha(head)
    if head_remote != head_local:
        raise SystemExit(
            f"Refusing PR: {remote}/{head} is at {head_remote[:12]} on the remote but "
            f"the local branch is at {head_local[:12]}. The PR would not ship what the "
            "file gate inspected. Push (or fetch) until they agree, then re-run."
        )

    base_sha = remote_branch_sha(remote, base)
    if base_sha is None:
        raise SystemExit(f"Refusing PR: {remote} has no base branch '{base}'.")
    if not have_commit(base_sha):
        raise SystemExit(
            f"Refusing PR: {remote}/{base} is at {base_sha[:12]}, which this checkout "
            f"does not have. Run `git fetch {remote} {base}` and re-run."
        )
    return base_sha, head_local


def run_file_gate(args: argparse.Namespace) -> None:
    """Refuse the PR unless every changed path is theme code or confirmed."""
    remote = resolve_remote(args)
    base_sha, head_sha = resolve_refs(remote, args.base, args.head)

    try:
        result = evaluate(base_sha, head_sha, allow=set(args.allow_nontheme))
    except GitError as exc:
        raise SystemExit(
            f"Refusing PR: cannot evaluate the changed files ({exc}). Run this inside "
            f"the target repo after `git fetch {remote} --prune`."
        )
    # Report against names a human recognises, not raw SHAs.
    result["base"] = f"{remote}/{args.base} ({base_sha[:12]})"
    result["head"] = f"{args.head} ({head_sha[:12]})"

    if result["verdict"] == "blocked":
        print("\n".join(render(result)), file=sys.stderr)
        raise SystemExit(
            "Refusing PR: see above. Non-theme paths must be dropped, or confirmed "
            "with the user and passed as --allow-nontheme <path> (one per path). "
            "Junk paths are never allowed."
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a yidian Draft PR against any base branch."
    )
    parser.add_argument(
        "--base",
        required=True,
        help="GitHub base branch for the PR, e.g. develop. Passed to gh as-is.",
    )
    parser.add_argument(
        "--head",
        required=True,
        help="PR branch holding the cherry-picked commits. Must differ from --base.",
    )
    parser.add_argument("--title", required=True, help="PR title.")
    parser.add_argument("--body", help="PR body text.")
    parser.add_argument("--body-file", help="Path to PR body markdown.")
    parser.add_argument(
        "--repo",
        help="Optional gh repo selector, e.g. OWNER/REPO.",
    )
    parser.add_argument(
        "--allow-nontheme",
        action="append",
        default=[],
        metavar="PATH",
        help="Exact path the user confirmed belongs in this PR despite not being "
        "theme code. Repeatable. Never accepts junk paths.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the gh command instead of creating the PR.",
    )
    args = parser.parse_args()

    if args.head == args.base:
        raise SystemExit(
            f"Refusing PR: --head and --base are both '{args.base}'. "
            "Cherry-pick onto a separate PR branch first."
        )

    body = read_body(args)
    check_body(body)
    run_file_gate(args)

    cmd = [
        "gh",
        "pr",
        "create",
        "--base",
        args.base,
        "--draft",
        "--title",
        args.title,
        "--body",
        body,
    ]
    if args.head:
        cmd.extend(["--head", args.head])
    if args.repo:
        cmd.extend(["--repo", args.repo])

    if args.dry_run:
        print(" ".join(repr(part) for part in cmd))
        return 0

    return run(cmd)


if __name__ == "__main__":
    sys.exit(main())
