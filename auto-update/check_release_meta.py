#!/usr/bin/env python3
"""Release gate for `release-meta.json`. Run before tagging.

  python3 auto-update/check_release_meta.py --tag v0.3.4

Two jobs:

1. **Schema.** The updater treats anything it cannot parse as `unknown` and
   holds the release. A typo here does not break anyone's machine, it silently
   turns auto-update off for everyone — which is worse, because nothing
   complains.

2. **A conservative contract gate.** `compatibility: compatible` is a human's
   claim. This checks that claim against the diff: if a canonical contract file
   changed in any way other than the version stamp, `compatible` is refused.
   The check cannot tell a wording fix from a semantic change, and that is the
   point — it fails toward `breaking`, where the cost is one manual confirmation
   rather than four clients silently switching rules.

Exit 0 = safe to tag. Exit 1 = fix it first.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

META = "release-meta.json"

# Files whose content IS the contract. A change here is presumed to matter.
CANONICAL = [
    "plaud-theme-shared/references/handoff-schema.md",
    "plaud-theme-shared/SKILL.md",
    "plaud-theme-shared/matrix-contract.md",
]
CANONICAL_GLOBS = ["plaud-theme-*/matrix-contract.md"]

VERSION_RE = re.compile(r"v\d+\.\d+\.\d+")
REQUIRED = {"schema": int, "version": str, "previous_version": str,
            "compatibility": str, "breaking_reasons": list, "headline": str}


def fail(msg: str) -> None:
    print(f"release-meta: {msg}", file=sys.stderr)
    sys.exit(1)


def git(args: list[str]) -> str:
    proc = subprocess.run(["git", *args], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        fail((proc.stderr or proc.stdout).strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def canonical_files(root: Path) -> list[str]:
    files = list(CANONICAL)
    for pattern in CANONICAL_GLOBS:
        # Repo-relative: these paths are handed to `git show <tag>:<path>`,
        # which does not understand an absolute path and would report every
        # file as new.
        files += [str(p.relative_to(root)) for p in sorted(root.glob(pattern))]
    return sorted(set(f for f in files if (root / f).exists()))


def semantic_diff(root: Path, base_tag: str, path: str) -> bool:
    """Did `path` change in a way that is not just the version stamp?"""
    old = git(["show", f"{base_tag}:{path}"]) if path_in_tag(base_tag, path) else ""
    new = (root / path).read_text(encoding="utf-8")
    return normalize(old) != normalize(new)


def path_in_tag(tag: str, path: str) -> bool:
    proc = subprocess.run(["git", "cat-file", "-e", f"{tag}:{path}"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc.returncode == 0


def normalize(text: str) -> str:
    """Strip the noise that changes in every release: version stamps and dates."""
    text = VERSION_RE.sub("vX.Y.Z", text)
    text = re.sub(r"\d{4}-\d{2}-\d{2}", "DATE", text)
    return "\n".join(line.rstrip() for line in text.splitlines() if line.strip())


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate release-meta.json before tagging.")
    ap.add_argument("--tag", required=True, help="the tag about to be created")
    ap.add_argument("--root", default=".", help="package root")
    args = ap.parse_args()
    root = Path(args.root).resolve()

    meta_path = root / META
    if not meta_path.exists():
        fail(f"{META} is missing. Without it every client holds the release instead "
             "of installing it.")
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except ValueError as exc:
        fail(f"{META} is not valid JSON: {exc}")

    if not isinstance(meta, dict):
        fail(f"{META} must be a JSON object")
    for key, typ in REQUIRED.items():
        if key not in meta:
            fail(f"{META} is missing '{key}'")
        if not isinstance(meta[key], typ) or isinstance(meta[key], bool) and typ is int:
            fail(f"{META}: '{key}' must be {typ.__name__}")
    if meta["schema"] != 1:
        fail(f"{META}: schema must be 1")
    if meta["version"] != args.tag:
        fail(f"{META}: version is {meta['version']!r} but the tag is {args.tag!r}. "
             "The updater would read that as unknown and hold the release.")
    if not VERSION_RE.fullmatch(meta["version"]):
        fail(f"{META}: version must look like vX.Y.Z")
    if meta["compatibility"] not in ("compatible", "breaking"):
        fail(f"{META}: compatibility must be 'compatible' or 'breaking'")
    if any(not isinstance(r, str) for r in meta["breaking_reasons"]):
        fail(f"{META}: breaking_reasons must be a list of strings")
    if meta["compatibility"] == "breaking" and not meta["breaking_reasons"]:
        fail(f"{META}: a breaking release must say what breaks, in breaking_reasons")
    if len(meta["headline"]) > 200:
        fail(f"{META}: headline must be 200 characters or fewer (it is shown in a terminal)")

    prev = meta["previous_version"]
    if not VERSION_RE.fullmatch(prev):
        fail(f"{META}: previous_version must look like vX.Y.Z")
    if not path_in_tag(prev, META) and not tag_exists(prev):
        fail(f"{META}: previous_version {prev} is not a tag in this repository")

    if meta["compatibility"] == "compatible":
        changed = [f for f in canonical_files(root) if semantic_diff(root, prev, f)]
        if changed:
            fail("compatibility says 'compatible', but these contract files changed "
                 "beyond their version stamp:\n  " + "\n  ".join(changed) +
                 "\n\nIf the change really is only wording, say so in the release notes "
                 "and mark it 'breaking' anyway — one manual confirmation is cheaper "
                 "than four clients silently switching rules.")

    print(f"release-meta: OK — {meta['version']} ({meta['compatibility']}), "
          f"previous {prev}")
    return 0


def tag_exists(tag: str) -> bool:
    proc = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return proc.returncode == 0


if __name__ == "__main__":
    sys.exit(main())
