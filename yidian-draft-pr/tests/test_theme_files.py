#!/usr/bin/env python3
"""Tests for the theme-only file gate.

  python3 yidian-draft-pr/tests/test_theme_files.py

Builds throwaway git repos in a temp dir; needs only git and python3, no test
framework. Prints one line per case and exits non-zero if any fail.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))

from theme_files import GitError, classify, evaluate  # noqa: E402
from create_draft_pr import normalize_repo  # noqa: E402

BODY = """## Summary
- x

## Test Plan / Verification Evidence
- x

## Risk / Rollback
- x

## Regression Matrix
- x

## Commits
- x
"""

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    ok = got == want
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        print(f"        got  {got!r}\n        want {want!r}")
        FAILURES.append(name)


def sh(cwd: Path, *args: str) -> str:
    proc = subprocess.run(
        args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    if proc.returncode != 0:
        raise AssertionError(f"{' '.join(args)} failed in {cwd}:\n{proc.stdout}")
    return proc.stdout


def write(repo: Path, rel: str, text: str = "x") -> None:
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


def new_repo(root: Path) -> Path:
    repo = root / "repo"
    repo.mkdir()
    sh(repo, "git", "init", "-q", "-b", "develop", ".")
    sh(repo, "git", "config", "user.email", "t@example.com")
    sh(repo, "git", "config", "user.name", "t")
    write(repo, "sections/base.liquid")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "base")
    return repo


def test_classify() -> None:
    cases = {
        "sections/x.liquid": "theme",
        "assets/a.css": "theme",
        "config/settings_data.json": "theme",
        ".theme-check.yml": "theme",
        "assets": "ask",  # a top-level FILE named like a theme dir
        "docs/assets/img.png": "ask",  # theme dir name, but not at the root
        ".DS_Store": "junk",
        "sections/.DS_Store": "junk",
        "a/b/.DS_store": "junk",  # case variant
        ".Claude/notes.md": "junk",
        "node_modules/p/i.js": "junk",
        "x.log": "junk",
        "sections/x.bak": "junk",
        ".github/workflows/ci.yml": "ask",
        "scripts/build.sh": "ask",
        "docs/plan.md": "ask",
        "CLAUDE.md": "ask",
        "package.json": "ask",
        ".env.example": "ask",
        "dev/tool.js": "ask",
    }
    for path, want in cases.items():
        check(f"classify {path}", classify(path), want)


def test_repo_cases(root: Path) -> None:
    repo = new_repo(root)

    # junk + ask + theme on one branch
    sh(repo, "git", "switch", "-qc", "pr/mixed")
    write(repo, "sections/new.liquid")
    write(repo, ".DS_Store")
    write(repo, "sections/.DS_Store")
    write(repo, "docs/plan.md")
    sh(repo, "git", "add", "-A", "-f")
    sh(repo, "git", "commit", "-qm", "mixed")

    r = evaluate("develop", "HEAD", cwd=repo)
    check("mixed: blocked", r["verdict"], "blocked")
    check("mixed: junk found", sorted(r["junk_live"]), [".DS_Store", "sections/.DS_Store"])
    check("mixed: ask found", r["ask_unallowed"], ["docs/plan.md"])

    r = evaluate("develop", "HEAD", allow={"docs/plan.md"}, cwd=repo)
    check("mixed: junk still blocks after allowing the ask path", r["verdict"], "blocked")

    r = evaluate("develop", "HEAD", allow={".DS_Store"}, cwd=repo)
    check("junk is never allowable", r["allow_on_junk"], [".DS_Store"])

    # a clean branch
    sh(repo, "git", "switch", "-qc", "pr/clean", "develop")
    write(repo, "sections/ok.liquid")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "clean")
    check("clean branch passes", evaluate("develop", "HEAD", cwd=repo)["verdict"], "clean")

    # a stale/mistyped --allow is an error, not a no-op
    r = evaluate("develop", "HEAD", allow={"docs/nope.md"}, cwd=repo)
    check("unused allow blocks", r["verdict"], "blocked")
    check("unused allow reported", r["allow_unused"], ["docs/nope.md"])

    # empty diff has nothing to review
    sh(repo, "git", "switch", "-qc", "pr/empty", "develop")
    r = evaluate("develop", "HEAD", cwd=repo)
    check("empty diff blocks", r["verdict"], "blocked")
    check("empty diff flagged", r["empty"], True)

    # deleting junk is the point, not a violation
    sh(repo, "git", "switch", "-q", "develop")
    write(repo, ".DS_Store")
    write(repo, "docs/old.md")
    sh(repo, "git", "add", "-A", "-f")
    sh(repo, "git", "commit", "-qm", "junk on base")
    sh(repo, "git", "switch", "-qc", "pr/cleanup")
    sh(repo, "git", "rm", "-q", ".DS_Store")
    sh(repo, "git", "commit", "-qm", "remove junk")
    check("deleting junk passes", evaluate("develop", "HEAD", cwd=repo)["verdict"], "clean")

    # deleting a non-theme path is still a non-theme change
    sh(repo, "git", "switch", "-qc", "pr/rmdoc", "develop")
    sh(repo, "git", "rm", "-q", "docs/old.md")
    sh(repo, "git", "commit", "-qm", "remove doc")
    r = evaluate("develop", "HEAD", cwd=repo)
    check("deleting an ask path needs confirming", r["ask_unallowed"], ["docs/old.md"])
    check(
        "…and passes once confirmed",
        evaluate("develop", "HEAD", allow={"docs/old.md"}, cwd=repo)["verdict"],
        "clean",
    )

    # settings_data.json is theme code but environment state
    sh(repo, "git", "switch", "-qc", "pr/settings", "develop")
    write(repo, "config/settings_data.json", "{}")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "settings")
    r = evaluate("develop", "HEAD", cwd=repo)
    check("settings_data needs confirming", r["sensitive_unconfirmed"], ["config/settings_data.json"])
    check(
        "…and passes once confirmed",
        evaluate("develop", "HEAD", allow={"config/settings_data.json"}, cwd=repo)["verdict"],
        "clean",
    )

    # a symlink under assets/ is not theme code
    sh(repo, "git", "switch", "-qc", "pr/link", "develop")
    (repo / "assets").mkdir(exist_ok=True)
    (repo / "assets" / "link").symlink_to("/etc/hosts")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "symlink")
    r = evaluate("develop", "HEAD", cwd=repo)
    check("symlink under assets/ flagged", r["special_modes"], ["assets/link"])
    check("symlink blocks", r["verdict"], "blocked")

    # a path containing a newline must not break parsing
    sh(repo, "git", "switch", "-qc", "pr/newline", "develop")
    write(repo, "sections/we\nird.liquid")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "newline path")
    r = evaluate("develop", "HEAD", cwd=repo)
    check("newline path parsed as one entry", r["theme"], ["sections/we\nird.liquid"])

    # an unevaluable request must raise, never read as clean
    try:
        evaluate("no/such/ref", "HEAD", cwd=repo)
        check("unknown ref raises", "no exception", "GitError")
    except GitError:
        check("unknown ref raises", "GitError", "GitError")


def test_normalize_repo() -> None:
    cases = {
        "owner/repo": (None, "owner/repo"),
        "OWNER/Repo": (None, "owner/repo"),
        "owner/repo.git": (None, "owner/repo"),
        "owner/repo/": (None, "owner/repo"),
        "github.com/owner/repo": ("github.com", "owner/repo"),
        "git@github.com:owner/repo.git": ("github.com", "owner/repo"),
        "https://github.com/owner/repo": ("github.com", "owner/repo"),
        "ssh://git@ghe.example/owner/repo.git": ("ghe.example", "owner/repo"),
    }
    for value, want in cases.items():
        check(f"normalize_repo {value}", normalize_repo(value), want)


def run_create(repo: Path, *args: str) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPTS / "create_draft_pr.py"), *args],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return proc.returncode, proc.stdout


def test_create_gate(root: Path) -> None:
    """The PR-creation gate, end to end, against a real (bare) remote."""
    upstream = root / "upstream.git"
    sh(root, "git", "init", "-q", "-b", "develop", "--bare", str(upstream))
    work = root / "work"
    sh(root, "git", "clone", "-q", str(upstream), str(work))
    sh(work, "git", "config", "user.email", "t@example.com")
    sh(work, "git", "config", "user.name", "t")
    write(work, "sections/base.liquid")
    sh(work, "git", "add", "-A")
    sh(work, "git", "commit", "-qm", "base")
    sh(work, "git", "push", "-q", "origin", "develop")

    body = root / "body.md"
    body.write_text(BODY, encoding="utf-8")
    base_args = ["--base", "develop", "--title", "t", "--body-file", str(body), "--dry-run"]

    sh(work, "git", "switch", "-qc", "pr/a")
    write(work, "sections/new.liquid")
    sh(work, "git", "add", "-A")
    sh(work, "git", "commit", "-qm", "work")

    rc, out = run_create(work, *base_args, "--head", "pr/a")
    check("create: unpushed head refused", (rc != 0, "Push it first" in out), (True, True))

    sh(work, "git", "push", "-q", "origin", "pr/a")
    rc, out = run_create(work, *base_args, "--head", "pr/a")
    check("create: pushed and in sync passes", rc, 0)

    write(work, "sections/more.liquid")
    sh(work, "git", "add", "-A")
    sh(work, "git", "commit", "-qm", "ahead")
    rc, out = run_create(work, *base_args, "--head", "pr/a")
    check(
        "create: local ahead of remote refused",
        (rc != 0, "would not ship what the file gate inspected" in out),
        (True, True),
    )
    sh(work, "git", "push", "-q", "origin", "pr/a")

    # someone else pushes to the PR branch: the local tracking ref is still in
    # sync, but the remote has moved. ls-remote catches it; a tracking-ref check
    # would not.
    other = root / "other"
    sh(root, "git", "clone", "-q", str(upstream), str(other))
    sh(other, "git", "config", "user.email", "o@example.com")
    sh(other, "git", "config", "user.name", "o")
    sh(other, "git", "switch", "-q", "pr/a")
    write(other, "sections/theirs.liquid")
    sh(other, "git", "add", "-A")
    sh(other, "git", "commit", "-qm", "theirs")
    sh(other, "git", "push", "-q", "origin", "pr/a")
    rc, out = run_create(work, *base_args, "--head", "pr/a")
    check("create: remote moved under us refused", rc != 0, True)

    # junk on the branch
    sh(work, "git", "fetch", "-q", "origin")
    sh(work, "git", "reset", "-q", "--hard", "origin/pr/a")
    write(work, ".DS_Store")
    sh(work, "git", "add", "-A", "-f")
    sh(work, "git", "commit", "-qm", "junk")
    sh(work, "git", "push", "-q", "origin", "pr/a")
    rc, out = run_create(work, *base_args, "--head", "pr/a")
    check("create: junk refused", (rc != 0, ".DS_Store" in out), (True, True))

    # --repo pointing somewhere this checkout is not
    rc, out = run_create(work, *base_args, "--head", "pr/a", "--repo", "someone/else")
    check("create: foreign --repo refused", (rc != 0, "not a remote" in out), (True, True))

    # an explicit host must match: a GHE path must not bind to this remote
    rc, out = run_create(work, *base_args, "--head", "pr/a", "--repo", "ghe.example/x/y")
    check("create: host-qualified --repo refused", rc != 0, True)


def main() -> int:
    test_classify()
    test_normalize_repo()
    with tempfile.TemporaryDirectory(prefix="theme-gate-tests-") as tmp:
        test_repo_cases(Path(tmp))
    with tempfile.TemporaryDirectory(prefix="theme-gate-create-") as tmp:
        test_create_gate(Path(tmp))
    print()
    if FAILURES:
        print(f"{len(FAILURES)} failing: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
