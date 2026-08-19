#!/usr/bin/env python3
"""Keep a repo's vendored copy of the matrix in step with the released package.

The theme repo carries `.github/codex/plaud-theme-matrix/` so CI review runs
against the same rules as the interactive skills. That copy goes stale silently
— CI keeps reviewing with old rules and nothing says so.

This proposes the update as a **Draft PR**. It never merges, never touches the
user's working tree, and never pushes anything but its own branch.

Separate opt-in from auto-update on purpose: updating your own machine and
pushing a branch to a shared repository are different levels of consent.

Guardrails, each one a way this could go wrong:

- The target must be a real git worktree whose remote is the configured repo.
- Work happens in a temporary worktree at a detached remote SHA, so the user's
  checkout, branch and index are never touched — dirty tree or not.
- The projection is explicit: only `plaud-theme-*` skill directories are
  synced, and `VENDORED.md` (the theme repo's own metadata, absent upstream) is
  preserved. "Replace the directory" would delete it.
- The base branch is read from the remote, not assumed to be `main`, and is
  re-read before pushing.
- Idempotent: an existing branch or an open PR for the same tag means stop, not
  a second branch and never a force-push.
- Breaking releases are not proposed automatically; a human should be deciding.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VENDOR_PATH = ".github/codex/plaud-theme-matrix"
SKILL_PREFIX = "plaud-theme-"
PRESERVE = ("VENDORED.md",)  # theme-repo metadata that upstream does not have


class SyncError(RuntimeError):
    pass


def git(args: list[str], cwd: Path | None = None, check: bool = True) -> str:
    proc = subprocess.run(["git", *args], cwd=cwd, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and proc.returncode != 0:
        raise SyncError((proc.stderr or proc.stdout).strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def gh(args: list[str], cwd: Path | None = None) -> str:
    proc = subprocess.run(["gh", *args], cwd=cwd, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise SyncError((proc.stderr or proc.stdout).strip() or f"gh {' '.join(args)} failed")
    return proc.stdout


def normalize_remote(url: str) -> tuple[str | None, str]:
    """(host, owner/repo). The host matters: `evil.example/Owner/Repo` is not
    `github.com/Owner/Repo`, and comparing only the last two segments would let
    a lookalike remote pass as the target repository."""
    v = url.strip().lower().rstrip("/")
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


def find_remote(repo_path: Path, want: str) -> str:
    """The single remote pointing at `want`. Both its fetch and push URL must
    match: a remote can push somewhere other than it fetches."""
    want_host, want_repo = normalize_remote(want)
    raw = git(["remote", "-v"], cwd=repo_path)
    urls: dict[str, set[tuple[str | None, str]]] = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            urls.setdefault(parts[0], set()).add(normalize_remote(parts[1]))

    names = []
    for name, seen in urls.items():
        if not all(repo == want_repo for _, repo in seen):
            continue
        if want_host is not None and any(
            h is not None and h != want_host for h, _ in seen
        ):
            continue
        names.append(name)
    if not names:
        raise SyncError(f"{repo_path} has no remote whose fetch AND push URL point at {want}")
    if len(names) > 1:
        raise SyncError(f"{repo_path} has several remotes for {want}: {', '.join(sorted(names))}")
    return names[0]


def default_branch(repo_path: Path, remote: str) -> str:
    """Ask the remote, never assume `main`.

    `ls-remote --symref` reads the remote's HEAD with plain git, so this works
    for any host and does not depend on gh being authenticated.
    """
    out = git(["ls-remote", "--symref", remote, "HEAD"], cwd=repo_path)
    for line in out.splitlines():
        if line.startswith("ref:"):
            ref = line.split()[1]
            if ref.startswith("refs/heads/"):
                return ref[len("refs/heads/"):]
    raise SyncError(f"could not read the default branch from {remote}")


def remote_sha(repo_path: Path, remote: str, branch: str) -> str:
    out = git(["ls-remote", "--exit-code", "--heads", remote, f"refs/heads/{branch}"],
              cwd=repo_path)
    return out.split("\t")[0].strip()


def branch_exists(repo_path: Path, remote: str, branch: str) -> bool:
    proc = subprocess.run(["git", "ls-remote", "--exit-code", "--heads", remote,
                           f"refs/heads/{branch}"], cwd=repo_path, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode == 0


def local_branch_exists(repo_path: Path, branch: str) -> bool:
    proc = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"],
                          cwd=repo_path, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode == 0


def pr_exists(repo: str, tag: str) -> str | None:
    out = gh(["pr", "list", "--repo", repo, "--state", "all", "--limit", "100",
              "--json", "number,headRefName,url"])
    want = f"chore/vendor-matrix-{tag}"
    for pr in json.loads(out or "[]"):
        if pr.get("headRefName") == want:
            return pr.get("url")
    return None


def local_edits(package_root: Path, vendor_dir: Path) -> list[str]:
    """Files under the vendored skills that the release does not have.

    Someone hand-editing the vendored copy is a real possibility — `VENDORED.md`
    itself tells people not to, which is evidence that they might. Overwriting
    added files silently would erase work without a trace, so an unexpected file
    stops the sync instead.
    """
    extra: list[str] = []
    if not vendor_dir.exists():
        return extra
    for child in sorted(vendor_dir.iterdir()):
        if not (child.is_dir() and child.name.startswith(SKILL_PREFIX)):
            continue
        upstream = package_root / child.name
        if not upstream.exists():
            continue  # a skill the release dropped; the projection handles it
        for f in sorted(child.rglob("*")):
            if f.is_file() and not (upstream / f.relative_to(child)).exists():
                extra.append(str(f.relative_to(vendor_dir)))
    return extra


def refresh_vendored_md(vendor_dir: Path, tag: str, skill_count: int) -> None:
    """Keep the repo's own metadata file honest about which tag is vendored.

    Preserving it verbatim would leave it claiming an old tag forever — worse
    than deleting it, because it reads as authoritative.
    """
    md = vendor_dir / "VENDORED.md"
    if not md.exists():
        return
    text = md.read_text(encoding="utf-8")
    text = re.sub(r"(\| 矩阵包版本 \| tag \*\*`)v\d+\.\d+\.\d+(`\*\*)",
                  rf"\g<1>{tag}\g<2>", text)
    text = re.sub(r"(\| skill 数 \| \*\*)\d+(\*\*)", rf"\g<1>{skill_count}\g<2>", text)
    text = re.sub(r"^TAG=v\d+\.\d+\.\d+$", f"TAG={tag}", text, flags=re.MULTILINE)
    md.write_text(text, encoding="utf-8")


def project(package_root: Path, vendor_dir: Path) -> list[str]:
    """Copy the released skills into the vendored dir; keep repo-owned metadata.

    Returns the list of skill dirs written. Only `plaud-theme-*` moves: bundled
    tool skills are for humans' machines, not for CI review.
    """
    written = []
    extra = local_edits(package_root, vendor_dir)
    if extra:
        raise SyncError(
            "the vendored copy has files the release does not: "
            + ", ".join(extra[:5])
            + ("…" if len(extra) > 5 else "")
            + ". Someone edited it by hand; resolve that before syncing."
        )
    keep = {name: (vendor_dir / name).read_bytes()
            for name in PRESERVE if (vendor_dir / name).exists()}

    for child in sorted(vendor_dir.iterdir()) if vendor_dir.exists() else []:
        if child.is_dir() and child.name.startswith(SKILL_PREFIX):
            shutil.rmtree(child)

    vendor_dir.mkdir(parents=True, exist_ok=True)
    for src in sorted(package_root.iterdir()):
        if src.is_dir() and src.name.startswith(SKILL_PREFIX) and (src / "SKILL.md").exists():
            shutil.copytree(src, vendor_dir / src.name)
            written.append(src.name)
    for name, blob in keep.items():
        (vendor_dir / name).write_bytes(blob)
    if not written:
        raise SyncError("the package tree held no plaud-theme-* skills to vendor")
    return written


def sync(repo_path: Path, repo: str, package_root: Path, tag: str,
         push: bool = False) -> str:
    if not (repo_path / ".git").exists():
        raise SyncError(f"{repo_path} is not a git worktree")
    remote = find_remote(repo_path, repo)
    base = default_branch(repo_path, remote)
    base_sha = remote_sha(repo_path, remote, base)
    branch = f"chore/vendor-matrix-{tag}"

    if branch_exists(repo_path, remote, branch):
        return f"{branch} already exists on {remote}; nothing to do."
    if local_branch_exists(repo_path, branch):
        # A previous prepare run left it here. Never reuse or force it -- the
        # human either pushes that branch or deletes it.
        return (f"{branch} already exists locally in {repo_path} (from an earlier run); "
                f"push it or delete it, then re-run.")
    if push:
        # Only needs gh, so only when we are actually going to open one.
        existing = pr_exists(repo, tag)
        if existing:
            return f"a PR for {tag} already exists: {existing}"

    git(["fetch", remote, base], cwd=repo_path)
    with tempfile.TemporaryDirectory(prefix="vendor-sync-") as tmp:
        wt = Path(tmp) / "wt"
        try:
            # Detached worktree at the remote base: the user's checkout, branch
            # and index are never touched, so a dirty tree is not a blocker.
            git(["worktree", "add", "--detach", str(wt), base_sha], cwd=repo_path)
            written = project(package_root, wt / VENDOR_PATH)
            refresh_vendored_md(wt / VENDOR_PATH, tag, len(written))
            git(["add", "--", VENDOR_PATH], cwd=wt)
            if not git(["status", "--porcelain", "--", VENDOR_PATH], cwd=wt).strip():
                return f"vendored copy is already at {tag}; nothing to do."
            git(["checkout", "-b", branch], cwd=wt)
            msg = (f"chore(ci): vendored 矩阵跟进上游 {tag}\n\n"
                   f"同步 {len(written)} 个 skill：{', '.join(written)}\n"
                   f"由 plaud-theme-matrix 的 vendor-sync 生成；{', '.join(PRESERVE)} 保留未动。\n")
            git(["-c", "user.name=plaud-matrix-sync",
                 "-c", "user.email=noreply@example.com",
                 "commit", "-m", msg], cwd=wt)

            if not push:
                return (f"prepared {branch} locally ({len(written)} skills). "
                        f"Re-run with --push to open a Draft PR.")

            if remote_sha(repo_path, remote, base) != base_sha:
                # Drop the branch so a re-run is not blocked by its own leftovers.
                git(["branch", "-D", branch], cwd=repo_path, check=False)
                return f"{base} moved while preparing; nothing pushed. Re-run."
            git(["push", "-u", remote, branch], cwd=wt)
            try:
                url = gh(["pr", "create", "--repo", repo, "--base", base, "--head", branch,
                          "--draft", "--title", f"chore(ci): vendored 矩阵跟进上游 {tag}",
                          "--body", vendor_pr_body(tag, written)], cwd=wt).strip()
            except SyncError as exc:
                # The branch is pushed; only the PR failed. Say so — silence here
                # would leave a branch nobody knows about.
                raise SyncError(
                    f"pushed {branch} to {remote}, but opening the Draft PR failed: {exc}. "
                    f"Open it by hand, or delete the branch."
                ) from exc
            return f"opened Draft PR for {tag}: {url.splitlines()[-1] if url else '(no url)'}"
        finally:
            # Remove first, prune second, and prune last of all: the temp dir is
            # about to disappear, and stale worktree metadata in the target repo
            # would break the next run.
            git(["worktree", "remove", "--force", str(wt)], cwd=repo_path, check=False)
            git(["worktree", "prune"], cwd=repo_path, check=False)


def vendor_pr_body(tag: str, written: list[str]) -> str:
    skills = "\n".join(f"  - `{s}`" for s in written)
    return f"""## Summary
- 把 CI 评审用的 vendored 矩阵同步到上游 **{tag}**
- 同步范围只有 `{VENDOR_PATH}/` 下的 `plaud-theme-*`（{len(written)} 个）：
{skills}
- `{', '.join(PRESERVE)}` 是本仓自己的元数据，保留未动

## Test Plan / Verification Evidence
- Shopify preview: 待补充：不适用（本 PR 不改主题代码）
- Manual verification: 由 plaud-theme-matrix 的 vendor-sync 从发布 tag 投影生成，未手工编辑
- Screenshots / Recording: 待补充：不适用

## Risk / Rollback
- 主要风险：CI 评审规则随之更新；不改任何 `sections/` `snippets/` `assets/` `templates/`，站点无影响
- 回滚方案：revert 本 PR

## Regression Matrix
- Desktop ≥1025: 不适用（无主题代码改动）
- Tablet 768-1024: 不适用
- Mobile ≤767: 不适用
- Related schema/block/effect switches: 不适用

## Commits
- 见本 PR 的提交列表
"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Propose a vendored-matrix update as a Draft PR.")
    ap.add_argument("--repo-path", required=True, help="Local checkout of the target repo.")
    ap.add_argument("--repo", required=True, help="OWNER/REPO it must point at.")
    ap.add_argument("--package-root", required=True, help="Released package tree to vendor from.")
    ap.add_argument("--tag", required=True, help="Release tag being vendored.")
    ap.add_argument("--push", action="store_true",
                    help="Push the branch and open the Draft PR. Without it, stop after "
                         "preparing the commit locally.")
    args = ap.parse_args()
    try:
        print(sync(Path(args.repo_path).expanduser(), args.repo,
                   Path(args.package_root).expanduser(), args.tag, push=args.push))
        return 0
    except SyncError as exc:
        print(f"vendor-sync: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
