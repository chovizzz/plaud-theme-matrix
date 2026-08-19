#!/usr/bin/env python3
"""Shared classification of a PR branch's changed files.

`check_theme_files.py` (the standalone gate an agent runs before pushing) and
`create_draft_pr.py` (the gate that runs before the PR is opened) both import
this module. One implementation, so the two gates can never disagree about what
counts as theme code.

Three buckets:

  theme  the Shopify theme itself -- fine to ship
  junk   never belongs in a PR: editor droppings, agent/tooling dirs, build
         caches, archives. Not a judgement call, so `--allow` does not apply
  ask    everything else: plausible (CI, docs, repo scripts) but not theme
         code, so a human decides per path

Plus one flag that is theme code but still needs confirming: `config/settings_data.json`
carries per-store/per-environment state, and a cherry-pick routinely drags in
another site's settings.
"""

from __future__ import annotations

import fnmatch
import subprocess

# Directories that ARE the Shopify Online Store theme.
THEME_DIRS = (
    "assets",
    "blocks",
    "config",
    "layout",
    "locales",
    "sections",
    "snippets",
    "templates",
)

# Theme-level tooling config that ships with the theme.
THEME_FILES = (
    ".theme-check.yml",
    ".theme-check.yaml",
    ".shopifyignore",
    "shopify.theme.toml",
)

# Theme files that are environment/store state rather than code. They stay in
# the `theme` bucket, but the gates require an explicit confirmation for them.
THEME_SENSITIVE_FILES = ("config/settings_data.json",)

# Never belongs in a PR. Matched against EVERY path segment, not just the first:
# `sections/.DS_Store` and `.claude/x` are equally unwanted.
# Deliberately narrow -- anything arguable belongs in `ask`, where a human sees
# it, rather than here, where it is refused outright.
JUNK_DIRS = (
    ".backup",
    ".claude",
    ".codex",
    ".cursor",
    ".agents",
    ".shopify",
    ".playwright-mcp",
    ".codegraph",
    "node_modules",
    ".cache",
    ".pytest_cache",
    ".venv",
    "__pycache__",
)
JUNK_NAMES = (".DS_Store", "Thumbs.db", "desktop.ini")
JUNK_GLOBS = ("*.log", "*.orig", "*.rej", "*.bak", "*~", "*.pyc", "*.swp")


class GitError(RuntimeError):
    """The diff could not be evaluated -- never treat this as 'clean'."""


def git(args: list[str], cwd: str | None = None) -> str:
    # surrogateescape: git can hold paths that are not valid UTF-8. Decoding
    # must not raise -- the caller needs a GitError or a classification, not a
    # UnicodeDecodeError from inside the gate.
    proc = subprocess.run(
        ["git", *args],
        text=True,
        errors="surrogateescape",
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise GitError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def classify(path: str) -> str:
    segments = path.split("/")
    name = segments[-1]
    # Case-insensitive: macOS and Windows checkouts hand back `.DS_store`,
    # `Thumbs.DB` and friends, and a case variant is the same dropping.
    folded = [seg.casefold() for seg in segments]
    junk_dirs = {d.casefold() for d in JUNK_DIRS}
    junk_names = {n.casefold() for n in JUNK_NAMES}

    if any(seg in junk_dirs for seg in folded):
        return "junk"
    if folded[-1] in junk_names or any(
        fnmatch.fnmatch(folded[-1], g.casefold()) for g in JUNK_GLOBS
    ):
        return "junk"
    # `segments[0] in THEME_DIRS` only counts when it really is a directory,
    # i.e. something follows it. A top-level file literally named `assets` is not
    # theme code.
    if (len(segments) > 1 and segments[0] in THEME_DIRS) or path in THEME_FILES:
        return "theme"
    return "ask"


# git file modes worth treating specially.
MODE_SYMLINK = "120000"
MODE_GITLINK = "160000"


def changed_files(
    base: str, head: str, cwd: str | None = None
) -> list[tuple[str, str, str]]:
    """[(status, dst_mode, path)] for what `head` adds on top of the merge base.

    Three-dot, so files the base moved on its own are not reported as this PR's.
    `--raw -z` rather than `--name-status`: it carries the destination mode, which
    is how a symlink or a submodule pointer hiding under `assets/` is caught --
    path alone would classify those as theme code. `-z` because paths may contain
    newlines; `--no-renames` so a rename reads as the add it effectively is.
    """
    merge_base = git(["merge-base", base, head], cwd=cwd).strip()
    if not merge_base:
        raise GitError(f"no merge base between {base} and {head}")
    raw = git(["diff", "--raw", "-z", "--no-renames", f"{base}...{head}"], cwd=cwd)

    # Fields alternate metadata, path, metadata, path, ... with a trailing empty
    # field. Metadata is ":<src-mode> <dst-mode> <src-sha> <dst-sha> <status>".
    fields = raw.split("\0")
    out: list[tuple[str, str, str]] = []
    i = 0
    while i + 1 < len(fields):
        meta = fields[i]
        if not meta.startswith(":"):
            break
        parts = meta[1:].split()
        if len(parts) < 5:
            raise GitError(f"unparseable diff record: {meta!r}")
        dst_mode, status = parts[1], parts[4][:1]
        out.append((status, dst_mode, fields[i + 1]))
        i += 2
    return out


def evaluate(
    base: str,
    head: str,
    allow: set[str] | None = None,
    cwd: str | None = None,
) -> dict:
    """Classify the diff and decide whether a PR may be opened.

    Deleted paths never block: a PR whose whole point is removing `.DS_Store`
    must be allowed through.
    """
    allow = set(allow or ())
    entries = changed_files(base, head, cwd=cwd)

    buckets: dict[str, list[str]] = {"theme": [], "junk": [], "ask": []}
    deleted: list[str] = []
    live: list[str] = []
    special: list[str] = []
    for status, dst_mode, path in entries:
        bucket = classify(path)
        # A symlink or submodule pointer is not theme code however it is named.
        if status != "D" and dst_mode in (MODE_SYMLINK, MODE_GITLINK) and bucket == "theme":
            bucket = "ask"
            special.append(path)
        buckets[bucket].append(path)
        (deleted if status == "D" else live).append(path)

    live_set = set(live)
    deleted_set = set(deleted)
    junk_live = [p for p in buckets["junk"] if p in live_set]
    # A deleted junk path is exactly what we want -- never block it. A deleted
    # non-theme path is still a change to something outside the theme, so it
    # goes through the same confirmation as any other ask path.
    ask_live = [p for p in buckets["ask"] if p in live_set or p in deleted_set]
    ask_unallowed = [p for p in ask_live if p not in allow]
    sensitive = [
        p
        for p in buckets["theme"]
        if p in THEME_SENSITIVE_FILES and p in live_set and p not in allow
    ]
    # An --allow naming something that is not an ask path in THIS diff is a
    # stale or mistyped confirmation; surface it rather than silently ignoring.
    allow_on_junk = sorted(allow & set(buckets["junk"]))
    # Only paths this diff actually needs confirming may be confirmed. An
    # --allow naming anything else is a stale or mistyped flag, and it blocks:
    # silently ignoring it is how a confirmation drifts onto the wrong path.
    confirmable = set(ask_live) | {
        p for p in buckets["theme"] if p in THEME_SENSITIVE_FILES and p in live_set
    }
    allow_unused = sorted(allow - confirmable - set(allow_on_junk))

    blocked = bool(
        junk_live or ask_unallowed or sensitive or allow_on_junk or allow_unused or not entries
    )
    return {
        "verdict": "blocked" if blocked else "clean",
        "base": base,
        "head": head,
        # An empty diff blocks: there is nothing to open a PR for, and a gate
        # that says "clean" here reads as approval of a branch with no content.
        "empty": not entries,
        "special_modes": special,
        "theme": buckets["theme"],
        "junk": buckets["junk"],
        "ask": buckets["ask"],
        "deleted": deleted,
        "junk_live": junk_live,
        "ask_unallowed": ask_unallowed,
        "sensitive_unconfirmed": sensitive,
        "allowed": sorted(allow),
        "allow_unused": allow_unused,
        "allow_on_junk": allow_on_junk,
    }


def render(result: dict) -> list[str]:
    """Human-readable report lines."""
    lines: list[str] = []
    total = len(result["theme"]) + len(result["junk"]) + len(result["ask"])
    lines.append(f"{total} changed file(s) in {result['base']}...{result['head']}")
    lines.append(f"  theme : {len(result['theme'])}")
    if result["deleted"]:
        lines.append(f"  (of which {len(result['deleted'])} deletion(s), never blocking)")

    if result["junk_live"]:
        lines.append("")
        lines.append(f"NOT THEME CODE — must not go into the PR ({len(result['junk_live'])}):")
        lines += [f"  {p}" for p in result["junk_live"]]
        lines.append("  These are not a judgement call; --allow does not apply. Drop them.")
    if result["ask_unallowed"]:
        lines.append("")
        lines.append(
            f"NOT THEME CODE — ask the user before keeping ({len(result['ask_unallowed'])}):"
        )
        lines += [f"  {p}" for p in result["ask_unallowed"]]
        lines.append("  Drop them, or pass --allow <path> once the user confirms each one.")
    if result["sensitive_unconfirmed"]:
        lines.append("")
        lines.append("Theme file, but per-store/per-environment state — confirm explicitly:")
        lines += [f"  {p}" for p in result["sensitive_unconfirmed"]]
        lines.append("  Keep it only if the user says this settings change is intended (--allow).")
    if result["allow_on_junk"]:
        lines.append("")
        lines.append("REFUSED --allow (junk is never allowed):")
        lines += [f"  {p}" for p in result["allow_on_junk"]]
    if result["allow_unused"]:
        lines.append("")
        lines.append("--allow named path(s) that this diff does not need:")
        lines += [f"  {p}" for p in result["allow_unused"]]

    if result["special_modes"]:
        lines.append("")
        lines.append("Symlink or submodule pointer under a theme path — needs confirming:")
        lines += [f"  {p}" for p in result["special_modes"]]
    if result["empty"]:
        lines.append("")
        lines.append(f"Nothing to review: {result['head']} has no changes on top of {result['base']}.")
        lines.append("  Cherry-pick first, or check the base ref.")

    if result["verdict"] == "clean":
        lines.append("")
        lines.append("OK: nothing outside the theme.")
    return lines
