#!/usr/bin/env python3
"""Tests for vendor-sync: proposing the vendored matrix update as a Draft PR.

  python3 auto-update/tests/test_vendor_sync.py

Builds throwaway repos (a bare "remote" and a checkout) in a temp dir. No
network and no gh: everything up to `--push` is exercised for real, and the
push path is checked by its preconditions.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from vendor_sync import (  # noqa: E402
    SyncError, VENDOR_PATH, find_remote, local_edits, normalize_remote,
    refresh_vendored_md, sync,
)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    ok = got == want
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        print(f"        got  {got!r}\n        want {want!r}")
        FAILURES.append(name)


def contains(name: str, haystack: str, needle: str) -> None:
    ok = needle.lower() in (haystack or "").lower()
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        print(f"        {needle!r} not in {haystack!r}")
        FAILURES.append(name)


def sh(cwd: Path, *args: str) -> str:
    proc = subprocess.run(args, cwd=cwd, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if proc.returncode != 0:
        raise AssertionError(f"{' '.join(args)} failed in {cwd}:\n{proc.stdout}")
    return proc.stdout


def make_package(root: Path) -> Path:
    """A stand-in for a released package tree."""
    pkg = root / "package"
    for name in ("plaud-theme-dev", "plaud-theme-shared"):
        d = pkg / name
        (d / "references").mkdir(parents=True)
        (d / "SKILL.md").write_text(f"# {name}\nnew content\n", encoding="utf-8")
        (d / "references" / "r.md").write_text("ref\n", encoding="utf-8")
    (pkg / "yidian-draft-pr").mkdir()
    (pkg / "yidian-draft-pr" / "SKILL.md").write_text("bundled\n", encoding="utf-8")
    (pkg / "auto-update").mkdir()
    (pkg / "auto-update" / "update.py").write_text("x\n", encoding="utf-8")
    return pkg


VENDORED_MD = """# plaud-theme-matrix（vendored）

| 项 | 值 |
|---|---|
| 矩阵包版本 | tag **`v0.3.1`**（以 version-manifest §1 为准） |
| skill 数 | **10** |

```sh
TAG=v0.3.1
```
"""


def make_repo(root: Path) -> tuple[Path, Path, str]:
    """(checkout, bare remote, repo slug) with an out-of-date vendored copy."""
    bare = root / "theme.git"
    sh(root, "git", "init", "-q", "-b", "main", "--bare", str(bare))
    wc = root / "theme"
    sh(root, "git", "clone", "-q", str(bare), str(wc))
    sh(wc, "git", "config", "user.email", "t@example.com")
    sh(wc, "git", "config", "user.name", "t")
    vd = wc / VENDOR_PATH
    (vd / "plaud-theme-dev").mkdir(parents=True)
    (vd / "plaud-theme-dev" / "SKILL.md").write_text("OLD\n", encoding="utf-8")
    (vd / "VENDORED.md").write_text(VENDORED_MD, encoding="utf-8")
    (wc / "sections").mkdir()
    (wc / "sections" / "a.liquid").write_text("theme code\n", encoding="utf-8")
    sh(wc, "git", "add", "-A")
    sh(wc, "git", "commit", "-qm", "base")
    sh(wc, "git", "push", "-q", "origin", "main")
    slug = f"{root.name}/theme"
    return wc, bare, slug


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="vendor-sync-tests-") as t:
        tmp = Path(t)

        # --- normalize_remote / find_remote ---
        check("normalize keeps the host", normalize_remote("https://github.com/o/r.git"),
              ("github.com", "o/r"))
        check("…and tolerates ssh form", normalize_remote("git@github.com:O/R"),
              ("github.com", "o/r"))
        check("…and a bare slug has no host", normalize_remote("o/r"), (None, "o/r"))

        d = tmp / "hosts"
        d.mkdir()
        wc, _, _ = make_repo(d)
        sh(wc, "git", "remote", "add", "lookalike", "https://evil.example/Tinsley-Chen/theme")
        try:
            find_remote(wc, "github.com/Tinsley-Chen/theme")
            check("a lookalike host is refused", "accepted", "SyncError")
        except SyncError:
            check("a lookalike host is refused", "SyncError", "SyncError")

        # a remote that pushes elsewhere than it fetches must not match
        d = tmp / "pushurl"
        d.mkdir()
        wc, _, slug = make_repo(d)
        sh(wc, "git", "remote", "set-url", "--push", "origin", "https://evil.example/o/r")
        try:
            find_remote(wc, slug)
            check("a divergent push URL is refused", "accepted", "SyncError")
        except SyncError:
            check("a divergent push URL is refused", "SyncError", "SyncError")

        # --- the happy path, without pushing ---
        d = tmp / "prepare"
        d.mkdir()
        pkg = make_package(d)
        wc, _, slug = make_repo(d)
        (wc / "sections" / "a.liquid").write_text("DIRTY\n", encoding="utf-8")  # dirty tree
        msg = sync(wc, slug, pkg, "v0.3.4")
        contains("prepares a branch", msg, "prepared")
        check("user stayed on their branch",
              sh(wc, "git", "branch", "--show-current").strip(), "main")
        check("…with their dirty file untouched",
              (wc / "sections" / "a.liquid").read_text(), "DIRTY\n")
        diff = sh(wc, "git", "-c", "core.quotepath=false", "diff", "--name-only",
                  "main", "chore/vendor-matrix-v0.3.4")
        outside = [ln for ln in diff.splitlines() if ln and not ln.startswith(VENDOR_PATH)]
        check("only the vendored path changed", outside, [])
        show = sh(wc, "git", "show", f"chore/vendor-matrix-v0.3.4:{VENDOR_PATH}/VENDORED.md")
        contains("VENDORED.md is kept", show, "plaud-theme-matrix（vendored）")
        contains("…and its version line refreshed", show, "v0.3.4")
        check("…and the stale tag is gone", "v0.3.1" in show, False)
        names = sh(wc, "git", "ls-tree", "--name-only",
                   f"chore/vendor-matrix-v0.3.4:{VENDOR_PATH}").split()
        check("bundled/non-skill dirs are not vendored",
              sorted(names), ["VENDORED.md", "plaud-theme-dev", "plaud-theme-shared"])

        # --- idempotence ---
        msg = sync(wc, slug, pkg, "v0.3.4")
        contains("a leftover local branch stops the next run", msg, "already exists locally")
        sh(wc, "git", "branch", "-D", "chore/vendor-matrix-v0.3.4")

        # --- hand-edited vendored copy stops the sync ---
        d = tmp / "handedit"
        d.mkdir()
        pkg = make_package(d)
        wc, _, slug = make_repo(d)
        extra = wc / VENDOR_PATH / "plaud-theme-dev" / "LOCAL-NOTE.md"
        extra.write_text("someone's local rule\n", encoding="utf-8")
        sh(wc, "git", "add", "-A")
        sh(wc, "git", "commit", "-qm", "local edit")
        sh(wc, "git", "push", "-q", "origin", "main")
        try:
            sync(wc, slug, pkg, "v0.3.4")
            check("a hand-edited vendored copy is refused", "accepted", "SyncError")
        except SyncError as exc:
            check("a hand-edited vendored copy is refused", "SyncError", "SyncError")
            contains("…naming the file", str(exc), "LOCAL-NOTE.md")

        # --- nothing to do when already in step ---
        d = tmp / "insync"
        d.mkdir()
        pkg = make_package(d)
        wc, _, slug = make_repo(d)
        sync(wc, slug, pkg, "v0.3.4")
        sh(wc, "git", "push", "-q", "origin", "chore/vendor-matrix-v0.3.4:main")
        sh(wc, "git", "branch", "-D", "chore/vendor-matrix-v0.3.4")
        msg = sync(wc, slug, pkg, "v0.3.4")
        contains("already in step is a no-op", msg, "nothing to do")

        # --- a directory that is not a git worktree ---
        try:
            sync(tmp / "nope", "o/r", pkg, "v0.3.4")
            check("a non-repo path is refused", "accepted", "SyncError")
        except SyncError:
            check("a non-repo path is refused", "SyncError", "SyncError")

        # --- refresh_vendored_md leaves an absent file alone ---
        empty = tmp / "empty"
        empty.mkdir()
        refresh_vendored_md(empty, "v0.3.4", 10)
        check("no VENDORED.md is not an error", list(empty.iterdir()), [])

        # --- local_edits ignores skills the release dropped ---
        d = tmp / "dropped"
        d.mkdir()
        pkg = make_package(d)
        vd = d / "vendor"
        (vd / "plaud-theme-gone").mkdir(parents=True)
        (vd / "plaud-theme-gone" / "SKILL.md").write_text("x\n", encoding="utf-8")
        check("a dropped skill is not 'a hand edit'", local_edits(pkg, vd), [])

    print()
    if FAILURES:
        print(f"{len(FAILURES)} failing: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
