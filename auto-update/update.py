#!/usr/bin/env python3
"""plaud-theme-matrix auto-updater.

Runs from the persistent runtime (`~/.local/share/plaud-theme-matrix/runtime`),
not from a skills directory: the skills dirs are what this thing replaces.

What it does, in one sentence: on a NEW Claude Code session, check whether a
newer release exists; install it only when the release declares itself
compatible and every local precondition holds; otherwise leave a one-line
notice and touch nothing.

Deliberate design points, each one a failure this avoids:

- **Only `startup`.** A resume/clear/compact hook fires inside a session that has
  already read the skills; swapping files under it would leave one session
  working from two different rulebooks. The hook passes `--event`; anything but
  `startup` checks and reports, never installs.
- **Compatibility is declared, not guessed.** `release-meta.json` in the target
  tag says `compatible` / `breaking`. Anything else -- missing file, version
  mismatch, unknown value -- is `unknown`, which never auto-installs. Version
  numbers are a hint in the message, never the decision: in this package every
  patch bumps ContractVersion, so a contract-diff heuristic would flag all of
  them.
- **Pinned to one commit.** The tag is resolved to a commit SHA once, and the
  metadata and the tree both come from that SHA, so a tag moving mid-run cannot
  splice two versions together.
- **The local tree must be pristine.** If what is installed does not match the
  release it claims to be (hand-edits, a half-finished install), we do not
  overwrite it -- that is a state a human should look at.
- **Skill set changes are never automatic.** The installer does not delete
  skills a release dropped; auto-installing across an add/remove would leave a
  stale skill still being routed to.
- **Failure is silent to the session, loud in the log.** No network, GitHub
  down, rate limited: the session starts normally. This must never be the reason
  someone cannot work.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = "chovizzz/plaud-theme-matrix"
API = "https://api.github.com"
CLIENTS = ("cursor", "claude", "codex", "agents")
MARKER = ".plaud-installed-ref"

HOME = Path(os.environ.get("PLAUD_HOME", Path.home()))
RUNTIME_DIR = Path(
    os.environ.get("PLAUD_RUNTIME_DIR", HOME / ".local/share/plaud-theme-matrix/runtime")
)
STATE_DIR = Path(os.environ.get("PLAUD_STATE_DIR", HOME / ".local/state/plaud-theme-matrix"))
STATE_FILE = STATE_DIR / "state.json"
PENDING_FILE = STATE_DIR / "pending.json"
LOG_FILE = STATE_DIR / "update.log"
LOCK_DIR = STATE_DIR / "lock"
# Repos whose vendored copy of the matrix should be proposed for update after a
# successful install. Empty by default: pushing a branch to a shared repo is a
# different level of consent than updating this machine, so it is its own opt-in.
VENDOR_FILE = STATE_DIR / "vendor-targets.json"

CHECK_INTERVAL = 6 * 3600  # a release lands a few times a month at most
BACKOFF_NETWORK = 30 * 60
BACKOFF_FAILURE = 24 * 3600
LOCK_STALE_AFTER = 30 * 60
NET_TIMEOUT = 15
MAX_HEADLINE = 200

TAG_RE = re.compile(r"^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


# ----------------------------------------------------------------- utilities


def log(msg: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    try:
        # Rotate rather than grow without bound; one previous file is plenty.
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 512 * 1024:
            LOG_FILE.replace(LOG_FILE.with_suffix(".log.1"))
        with LOG_FILE.open("a", encoding="utf-8") as fh:
            fh.write(f"{stamp} {msg}\n")
    except OSError:
        pass


def read_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write_json(path: Path, data: dict) -> None:
    """Atomic write: a torn state file would be indistinguishable from 'never ran'."""
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def sanitize(text: str, limit: int = MAX_HEADLINE) -> str:
    """Release metadata is remote input; it must not be able to paint the terminal."""
    flat = "".join(ch if ch.isprintable() else " " for ch in str(text))
    flat = " ".join(flat.split())
    return flat[:limit]


def parse_tag(tag: str) -> tuple[int, int, int] | None:
    m = TAG_RE.match(tag or "")
    return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None


def http_json(url: str) -> dict | list | None:
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json",
                                               "User-Agent": "plaud-theme-matrix-updater"})
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=NET_TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "plaud-theme-matrix-updater"})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=NET_TIMEOUT, context=ctx) as resp:
        return resp.read().decode("utf-8")


# ---------------------------------------------------------------------- lock


class Lock:
    """Atomic mkdir lock over check → decide → install.

    Several Claude Code sessions can start at once; two installers writing the
    same skills directories is the one thing worse than not updating.
    """

    def __init__(self) -> None:
        self.held = False
        self.token = ""

    def __enter__(self) -> "Lock":
        LOCK_DIR.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.token = f"{os.getpid()}-{time.time()}"
        try:
            LOCK_DIR.mkdir(mode=0o700)
            self.held = True
        except FileExistsError:
            info = read_json(LOCK_DIR / "owner.json")
            age = time.time() - float(info.get("started", 0) or 0)
            if age > LOCK_STALE_AFTER:
                # Do not steal it. A lock this old means a crashed or wedged run,
                # and that is worth a human's eyes rather than a second writer.
                log(f"lock held since {info.get('started')} by pid {info.get('pid')} — stale, "
                    f"not stealing. Remove {LOCK_DIR} after checking nothing is running.")
            self.held = False
            return self
        write_json(LOCK_DIR / "owner.json",
                   {"pid": os.getpid(), "started": time.time(),
                    "host": os.uname().nodename, "token": self.token})
        return self

    def __exit__(self, *exc) -> None:
        if not self.held:
            return
        # Only remove the lock if it is still ours. Someone may have cleared a
        # stale lock by hand and a new run may already hold this path.
        if read_json(LOCK_DIR / "owner.json").get("token") == self.token:
            shutil.rmtree(LOCK_DIR, ignore_errors=True)


# ------------------------------------------------------------- installed state


def skills_dir(client: str) -> Path:
    return HOME / f".{client}" / "skills"


def marker_field(path: Path, key: str) -> str | None:
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith(f"{key}:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return None


def installed_clients() -> dict[str, str | None]:
    """{client: installed ref} for clients that actually have the package."""
    out: dict[str, str | None] = {}
    for c in CLIENTS:
        marker = skills_dir(c) / MARKER
        if marker.exists():
            out[c] = marker_field(marker, "ref")
    return out


def installer_path() -> Path:
    return RUNTIME_DIR / "install.sh"


def run_installer(args: list[str]) -> tuple[int, str]:
    inst = installer_path()
    if not inst.exists():
        return 127, f"installer not found at {inst}"
    # Hand the installer the same HOME this module resolved its paths from.
    # Inheriting the ambient HOME would let the updater check one machine's
    # skills and install onto another's — which is exactly what happened the
    # first time this ran end to end.
    env = {**os.environ, "HOME": str(HOME)}
    try:
        proc = subprocess.run(
            ["sh", str(inst), *args],
            text=True, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600,
        )
    except subprocess.TimeoutExpired:
        return 124, "installer timed out after 600s"
    return proc.returncode, proc.stdout


# ------------------------------------------------------------ release lookup


def resolve_latest(state: dict) -> tuple[str, str] | None:
    """(tag, commit sha) of the newest release, pinned to one commit."""
    rel = http_json(f"{API}/repos/{REPO}/releases/latest")
    tag = rel.get("tag_name") if isinstance(rel, dict) else None
    if not tag or not parse_tag(tag):
        return None
    ref = http_json(f"{API}/repos/{REPO}/git/ref/tags/{tag}")
    if not isinstance(ref, dict):
        return None
    obj = ref.get("object") or {}
    sha = obj.get("sha")
    if obj.get("type") == "tag":  # annotated tag -> dereference to the commit
        tag_obj = http_json(f"{API}/repos/{REPO}/git/tags/{sha}")
        sha = (tag_obj or {}).get("object", {}).get("sha")
    return (tag, sha) if sha else None


def fetch_meta(sha: str, tag: str) -> dict:
    """release-meta.json from the pinned commit, validated into a verdict."""
    url = f"https://raw.githubusercontent.com/{REPO}/{sha}/release-meta.json"
    try:
        raw = json.loads(http_text(url))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return {"compatibility": "unknown", "why": "release carries no release-meta.json"}
        raise
    except ValueError:
        return {"compatibility": "unknown", "why": "release-meta.json is not valid JSON"}

    if not isinstance(raw, dict) or raw.get("schema") != 1:
        return {"compatibility": "unknown", "why": "release-meta.json schema is not 1"}
    if raw.get("version") != tag:
        return {"compatibility": "unknown",
                "why": f"release-meta.json says {sanitize(raw.get('version'), 20)}, tag says {tag}"}
    compat = raw.get("compatibility")
    if compat not in ("compatible", "breaking"):
        return {"compatibility": "unknown", "why": "compatibility is not a known value"}
    return {
        "compatibility": compat,
        "headline": sanitize(raw.get("headline", "")),
        "breaking_reasons": [sanitize(r, 120) for r in (raw.get("breaking_reasons") or [])][:5],
        "why": "",
    }


# ------------------------------------------------------------- preconditions


def tree_is_pristine(tag: str) -> tuple[bool, str]:
    """Does what is installed still match the release it claims to be?

    `--check` compares file by file against the ref. If a client has been
    hand-edited or a previous install was interrupted, overwriting it silently
    would destroy evidence of a state someone should look at.
    """
    rc, out = run_installer(["--check", "--ref", tag])
    if rc == 0:
        return True, ""
    first = next((ln.strip() for ln in out.splitlines()
                  if any(k in ln for k in ("DIFFERS", "STALE", "MISSING", "INTERRUPTED"))), "")
    return False, sanitize(first or f"--check exited {rc}", 120)


def remote_skill_names(sha: str) -> set[str]:
    """Top-level dirs holding a SKILL.md — the same rule install.sh uses.

    Not "every top-level directory": the package root also carries `auto-update/`
    and other non-skill directories, and counting those would make every release
    look like it added a skill, which would block auto-install forever.
    """
    tree = http_json(f"{API}/repos/{REPO}/git/trees/{sha}?recursive=1")
    names = set()
    for entry in (tree or {}).get("tree", []):
        path = entry.get("path", "")
        if entry.get("type") == "blob" and path.count("/") == 1 and path.endswith("/SKILL.md"):
            top = path.split("/", 1)[0]
            if not top.startswith("."):
                names.add(top)
    if (tree or {}).get("truncated"):
        raise ValueError("release tree listing was truncated")
    return names


def skill_sets_match(sha: str) -> tuple[bool, str]:
    """Refuse to auto-install across an added or removed skill."""
    try:
        remote = remote_skill_names(sha)
    except (urllib.error.URLError, ValueError, TimeoutError, OSError):
        return False, "could not read the release tree"
    if not remote:
        return False, "release tree lists no skills"

    local: set[str] = set()
    for client, _ in installed_clients().items():
        d = skills_dir(client)
        marker_skills = []
        try:
            for line in (d / MARKER).read_text(encoding="utf-8").splitlines():
                if line.startswith("skill:"):
                    marker_skills.append(line.split(":", 1)[1].strip())
        except OSError:
            continue
        local |= set(marker_skills)
        break  # all clients carry the same set; one is enough

    if not local:
        return True, ""  # nothing recorded to compare against
    added, removed = remote - local, local - remote
    if added or removed:
        bits = []
        if added:
            bits.append("adds " + ", ".join(sorted(added)[:3]))
        if removed:
            bits.append("removes " + ", ".join(sorted(removed)[:3]))
        return False, "; ".join(bits)
    return True, ""


# ------------------------------------------------------------------ the run


def should_check(state: dict, force: bool) -> bool:
    if force:
        return True
    raw = state.get("next_check_after", 0)
    try:
        nxt = float(raw or 0)
    except (TypeError, ValueError):
        return True  # unreadable state: check, and the run rewrites it
    if nxt != nxt:  # NaN compares false against everything, including itself
        return True
    now = time.time()
    if nxt > now + 7 * 86400:  # clock moved, or the file is nonsense
        return True
    return now >= nxt


def do_run(event: str, force: bool, apply_breaking: bool = False,
           expect_tag: str | None = None) -> str:
    """Returns the one-line message for the session (empty = say nothing)."""
    state = read_json(STATE_FILE)
    if not should_check(state, force):
        pending = read_json(PENDING_FILE)
        return pending_message(pending) if pending else ""

    with Lock() as lock:
        if not lock.held:
            return ""  # another session is doing this right now
        return _run_locked(state, event, apply_breaking, expect_tag)


def _run_locked(state: dict, event: str, apply_breaking: bool,
                expect_tag: str | None = None) -> str:
    now = time.time()
    state["last_attempt"] = now
    installed = installed_clients()
    if not installed:
        # Never auto-install onto a machine that does not have the package.
        state["next_check_after"] = now + BACKOFF_FAILURE
        write_json(STATE_FILE, state)
        return ""

    try:
        latest = resolve_latest(state)
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
        log(f"check failed: {exc}")
        state["last_failure"] = {"at": now, "kind": "network", "detail": str(exc)[:200]}
        state["next_check_after"] = now + BACKOFF_NETWORK
        write_json(STATE_FILE, state)
        # Keep showing an existing notice: not reaching GitHub is no reason to
        # stop telling someone a breaking release is waiting.
        pending = read_json(PENDING_FILE)
        return pending_message(pending) if pending else ""

    if not latest:
        state["next_check_after"] = now + BACKOFF_NETWORK
        write_json(STATE_FILE, state)
        return ""

    tag, sha = latest
    if expect_tag and tag != expect_tag:
        # The human said yes to a specific release. If a newer one appeared in
        # between, that is a different decision and needs asking again.
        state["next_check_after"] = 0  # look again immediately
        write_json(STATE_FILE, state)
        return (f"plaud-theme-matrix: you confirmed {sanitize(expect_tag, 20)}, but "
                f"{tag} is now the latest. Re-run `plaud-matrix-update check` and "
                "confirm again.")
    state["last_seen_tag"] = tag
    current = sorted({v for v in installed.values() if v})
    state["next_check_after"] = now + CHECK_INTERVAL

    if all(v == tag for v in installed.values()):
        state["last_success"] = {"at": now, "tag": tag, "action": "already-current"}
        PENDING_FILE.unlink(missing_ok=True)
        write_json(STATE_FILE, state)
        return ""

    try:
        meta = fetch_meta(sha, tag)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        log(f"metadata fetch failed for {tag}: {exc}")
        state["next_check_after"] = now + BACKOFF_NETWORK
        write_json(STATE_FILE, state)
        return ""

    compat = meta["compatibility"]
    # Two kinds of blocker, and only one of them is a judgement call.
    # `waivable`: the release is fine, a human just has to agree to it.
    # `hard`: something about this machine or this release is not in a state
    # anyone should be installing over. `apply --yes` must never clear these --
    # confirming "yes, install the breaking release" is not confirming "yes,
    # overwrite my hand-edited tree with a release I could not identify".
    waivable: list[str] = []
    hard: list[str] = []
    if compat == "breaking":
        waivable.append("release declares breaking changes")
    elif compat == "unknown":
        hard.append(meta.get("why") or "compatibility could not be established")
    if event not in ("startup", "manual"):
        hard.append("session already running")

    if not hard:
        ok, why = skill_sets_match(sha)
        if not ok:
            hard.append(f"skill set changed ({why})")
    if not hard:
        # Check the tree against what it claims to be. With clients on different
        # versions there is no single claim to check, so that is itself a blocker.
        if len(current) != 1:
            hard.append(f"clients are on different versions ({', '.join(current) or 'unknown'})")
        else:
            ok, why = tree_is_pristine(current[0])
            if not ok:
                hard.append(f"installed copy is not pristine ({why})")

    waived = apply_breaking and event == "manual"
    blockers = hard + ([] if waived else waivable)

    if blockers:
        record = {
            "tag": tag, "sha": sha, "compatibility": compat,
            "headline": meta.get("headline", ""),
            "breaking_reasons": meta.get("breaking_reasons", []),
            "blockers": blockers, "from": current, "seen_at": now,
        }
        write_json(PENDING_FILE, record)
        state["last_blocked"] = {"at": now, "tag": tag, "blockers": blockers}
        write_json(STATE_FILE, state)
        log(f"{tag} not applied: {'; '.join(blockers)}")
        return pending_message(record)

    try:
        rc, out = run_installer(["--ref", tag, "--commit", sha, "--yes"])
    except (subprocess.SubprocessError, OSError) as exc:
        log(f"installer could not run for {tag}: {exc!r}")
        state["last_failure"] = {"at": now, "kind": "install", "tag": tag, "detail": str(exc)[:200]}
        state["next_check_after"] = now + BACKOFF_FAILURE
        write_json(STATE_FILE, state)
        return f"plaud-theme-matrix: update to {tag} could not run; see {LOG_FILE}"
    log(f"install {tag} (commit {sha}) rc={rc}\n{out}")
    if rc != 0:
        state["last_failure"] = {"at": now, "kind": "install", "tag": tag}
        state["next_check_after"] = now + BACKOFF_FAILURE
        write_json(STATE_FILE, state)
        write_json(PENDING_FILE, {
            "tag": tag, "sha": sha, "compatibility": compat,
            "headline": meta.get("headline", ""), "breaking_reasons": [],
            "blockers": [f"install failed (rc={rc}); see {LOG_FILE}"],
            "from": current, "seen_at": now,
        })
        return f"plaud-theme-matrix: update to {tag} failed; see {LOG_FILE}"

    ok, why = tree_is_pristine(tag)
    after = installed_clients()
    done = sum(1 for v in after.values() if v == tag)
    total = len(after)

    if not ok or done != total:
        # A zero exit from the installer is not proof. Keep this pending and say
        # so; a half-updated set of clients is exactly the state that must not
        # look like success and then go quiet for six hours.
        write_json(PENDING_FILE, {
            "tag": tag, "sha": sha, "compatibility": compat,
            "headline": meta.get("headline", ""), "breaking_reasons": [],
            "blockers": [f"installed on {done}/{total} clients; verification: "
                         f"{why or 'incomplete'}"],
            "from": current, "seen_at": now,
        })
        state["last_failure"] = {"at": now, "kind": "verify", "tag": tag}
        state["next_check_after"] = now + BACKOFF_FAILURE
        write_json(STATE_FILE, state)
        return (f"plaud-theme-matrix: updated to {tag} on {done}/{total} clients — "
                f"verification reported: {why or 'incomplete'}. See {LOG_FILE}")

    PENDING_FILE.unlink(missing_ok=True)
    state["last_success"] = {"at": now, "tag": tag, "action": "installed"}
    write_json(STATE_FILE, state)
    head = sanitize(meta.get("headline") or "")
    tail = f" — {head}" if head else ""
    msg = f"plaud-theme-matrix: updated {current[0] if current else '?'} → {tag} ({done}/{total} clients){tail}"
    for line in run_vendor_sync(tag):
        msg += f"\n  vendored: {line}"
    return msg


def vendor_targets() -> list[dict]:
    data = read_json(VENDOR_FILE)
    targets = data.get("targets") if isinstance(data, dict) else None
    return [t for t in (targets or []) if isinstance(t, dict) and t.get("path") and t.get("repo")]


def run_vendor_sync(tag: str, push: bool = True) -> list[str]:
    """Propose the vendored update in each registered repo. Never fatal."""
    results: list[str] = []
    targets = vendor_targets()
    if not targets:
        return results
    script = RUNTIME_DIR / "vendor_sync.py"
    if not script.exists():
        log("vendor-sync requested but vendor_sync.py is not in the runtime")
        return results
    # Vendor from the tree that was just installed, so what CI gets is exactly
    # what this machine got.
    package_root = skills_dir(next(iter(installed_clients()), "claude"))
    for t in targets:
        cmd = [sys.executable, str(script), "--repo-path", t["path"], "--repo", t["repo"],
               "--package-root", str(package_root), "--tag", tag]
        if push:
            cmd.append("--push")
        try:
            proc = subprocess.run(cmd, text=True, timeout=300,
                                  env={**os.environ, "HOME": str(HOME)},
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            line = sanitize((proc.stdout or "").strip().splitlines()[-1] if proc.stdout else "", 160)
            log(f"vendor-sync {t['repo']} rc={proc.returncode}: {proc.stdout}")
            if proc.returncode == 0 and line:
                results.append(line)
        except (OSError, subprocess.SubprocessError) as exc:
            log(f"vendor-sync {t['repo']} failed: {exc}")
    return results


def pending_message(rec: dict) -> str:
    # Sanitize again here, not only at fetch: this record round-trips through a
    # file on disk, and the message goes straight to a terminal.
    tag = sanitize(rec.get("tag", "?"), 20)
    blocker_list = [sanitize(b, 120) for b in (rec.get("blockers") or [])]
    hard = [b for b in blocker_list if "declares breaking changes" not in b]
    if hard:
        # Say the thing a human has to act on. "It is breaking" is not the
        # actionable part when the tree is also dirty or unidentifiable --
        # confirming the release will not clear those.
        lead = f"{tag} is available"
        if rec.get("compatibility") == "breaking":
            lead += " (and declares BREAKING changes)"
        return (f"plaud-theme-matrix: {lead} but was not installed: {'; '.join(hard)}. "
                f"See {LOG_FILE}")
    if rec.get("compatibility") == "breaking":
        why = "; ".join(sanitize(r, 120) for r in (rec.get("breaking_reasons") or [])) \
            or sanitize(rec.get("headline") or "")
        why = f" {why}" if why else ""
        return (f"plaud-theme-matrix: {tag} is available and declares BREAKING changes — not "
                f"installed.{why} Review, then apply with: plaud-matrix-update apply --yes")
    blockers = "; ".join(sanitize(b, 120) for b in (rec.get("blockers") or [])) or "needs review"
    return (f"plaud-theme-matrix: {tag} is available but was not installed ({blockers}). "
            f"Apply with: plaud-matrix-update apply --yes")


# ----------------------------------------------------------------- hook wiring


HOOK_MARK = "plaud-theme-matrix auto-update"


def hook_entry() -> dict:
    return {
        "matcher": "startup",
        "hooks": [{
            "type": "command",
            "command": f'python3 "{RUNTIME_DIR}/update.py" session-start  # {HOOK_MARK}',
            "timeout": 120,
            "statusMessage": "Checking plaud-theme-matrix updates...",
        }],
    }


def settings_path() -> Path:
    return HOME / ".claude" / "settings.json"


def edit_hook(enable: bool) -> str:
    p = settings_path()
    if not p.exists():
        return f"{p} does not exist; nothing changed."
    data = read_json(p)
    hooks = data.setdefault("hooks", {})
    entries = hooks.setdefault("SessionStart", [])
    entries = [e for e in entries
               if HOOK_MARK not in json.dumps(e, ensure_ascii=False)]
    if enable:
        entries.append(hook_entry())
    if entries:
        hooks["SessionStart"] = entries
    else:
        hooks.pop("SessionStart", None)
    if not hooks:
        data.pop("hooks", None)
    backup = p.with_suffix(f".json.bak-plaud-{int(time.time())}")
    shutil.copy2(p, backup)
    write_json(p, data)
    return (f"auto-update {'enabled' if enable else 'disabled'} in {p} (backup: {backup.name})")


# ---------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description="plaud-theme-matrix auto-updater")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("session-start", help="hook entry point: check, maybe install, print JSON")
    p.add_argument("--event", default="startup")

    sub.add_parser("check", help="check now and report, never install")
    ap_apply = sub.add_parser("apply", help="install the pending release now")
    ap_apply.add_argument("--yes", action="store_true", help="required, and means it")
    sub.add_parser("status", help="what is installed, pending, and when we last looked")
    sub.add_parser("enable-hook", help="add the SessionStart hook to ~/.claude/settings.json")
    sub.add_parser("disable-hook", help="remove it")

    v = sub.add_parser("vendor", help="repos whose vendored matrix copy to keep in step")
    vsub = v.add_subparsers(dest="vcmd", required=True)
    va = vsub.add_parser("add", help="register a repo (opens a Draft PR after each update)")
    va.add_argument("--path", required=True, help="local checkout of that repo")
    va.add_argument("--repo", required=True, help="OWNER/REPO it must point at")
    vsub.add_parser("list", help="show registered repos")
    vr = vsub.add_parser("remove", help="unregister")
    vr.add_argument("--path", required=True)
    vrun = vsub.add_parser("run", help="propose the vendored update now")
    vrun.add_argument("--tag", help="tag to vendor; default: what is installed")
    vrun.add_argument("--push", action="store_true", help="push and open the Draft PR")
    args = ap.parse_args()

    if args.cmd == "session-start":
        # Never let this be the reason a session fails to start.
        try:
            msg = do_run(event=args.event, force=False)
        except Exception as exc:  # noqa: BLE001 - a hook must not raise into the session
            log(f"session-start crashed: {exc!r}")
            msg = ""
        if msg:
            print(json.dumps({"systemMessage": msg,
                              "hookSpecificOutput": {"hookEventName": "SessionStart"}}))
        return 0

    if args.cmd == "check":
        rec_before = read_json(PENDING_FILE)
        msg = do_run(event="check", force=True)
        print(msg or "plaud-theme-matrix: up to date."
              if not rec_before else msg or pending_message(rec_before))
        return 0

    if args.cmd == "apply":
        rec = read_json(PENDING_FILE)
        if not rec:
            print("Nothing pending. Run `plaud-matrix-update check` first.")
            return 0
        if not args.yes:
            print(pending_message(rec))
            print("\nRe-run with --yes to install it.")
            return 1
        print(do_run(event="manual", force=True, apply_breaking=True) or "Nothing to do.")
        return 0

    if args.cmd == "status":
        state, pending = read_json(STATE_FILE), read_json(PENDING_FILE)
        print("installed:")
        for c, ref in (installed_clients() or {}).items():
            print(f"  {c:8} {ref or '(no ref recorded)'}")
        if not installed_clients():
            print("  (package not installed on any client)")
        last = state.get("last_success") or {}
        if last:
            print(f"last: {last.get('action')} {last.get('tag', '')} at "
                  f"{time.strftime('%Y-%m-%d %H:%M', time.localtime(last.get('at', 0)))}")
        nxt = float(state.get("next_check_after", 0) or 0)
        if nxt:
            print(f"next check no earlier than {time.strftime('%Y-%m-%d %H:%M', time.localtime(nxt))}")
        print(f"pending: {pending_message(pending) if pending else 'none'}")
        hooked = HOOK_MARK in json.dumps(read_json(settings_path()), ensure_ascii=False)
        print(f"SessionStart hook: {'enabled' if hooked else 'not enabled'}")
        return 0

    if args.cmd in ("enable-hook", "disable-hook"):
        print(edit_hook(args.cmd == "enable-hook"))
        return 0

    if args.cmd == "vendor":
        targets = vendor_targets()
        if args.vcmd == "add":
            path = str(Path(args.path).expanduser().resolve())
            targets = [t for t in targets if t["path"] != path]
            targets.append({"path": path, "repo": args.repo})
            write_json(VENDOR_FILE, {"targets": targets})
            print(f"registered {args.repo} at {path}.\n"
                  "After each successful update it will open a Draft PR there with the "
                  "vendored matrix refreshed. It never merges and never touches your "
                  "working tree.")
            return 0
        if args.vcmd == "remove":
            path = str(Path(args.path).expanduser().resolve())
            write_json(VENDOR_FILE, {"targets": [t for t in targets if t["path"] != path]})
            print(f"unregistered {path}")
            return 0
        if args.vcmd == "list":
            if not targets:
                print("no vendored repos registered (vendor sync is off)")
            for t in targets:
                print(f"  {t['repo']:45} {t['path']}")
            return 0
        if args.vcmd == "run":
            tag = args.tag or next((v for v in installed_clients().values() if v), None)
            if not tag:
                print("nothing installed; pass --tag")
                return 1
            lines = run_vendor_sync(tag, push=args.push)
            print("\n".join(lines) if lines else
                  "nothing to do (no targets registered, or already in step). "
                  f"See {LOG_FILE} for detail.")
            return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
