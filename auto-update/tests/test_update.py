#!/usr/bin/env python3
"""Tests for the auto-updater's decision logic.

  python3 auto-update/tests/test_update.py

No network and no real HOME: the GitHub calls and the installer are stubbed, and
every path the updater touches is redirected into a temp dir. What is under test
is the decision — install / hold / say nothing — not curl.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

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


class World:
    """A fake machine: HOME, installed markers, releases, installer behaviour."""

    def __init__(self, tmp: Path, installed: str | None = "v0.3.3",
                 clients=("cursor", "claude", "codex", "agents")):
        self.home = tmp
        self.latest = ("v0.3.4", "sha-334")
        self.meta: dict = {"schema": 1, "version": "v0.3.4", "compatibility": "compatible",
                           "headline": "fine", "breaking_reasons": []}
        self.remote_skills = {"plaud-theme-dev", "plaud-theme-shared", "yidian-draft-pr"}
        self.local_skills = set(self.remote_skills)
        # Non-skill directories that really exist in the package root. The first
        # version of the check counted these and blocked every update.
        self.remote_dirs = ["auto-update", "auto-update/tests", ".github"]
        self.tree_truncated = False
        self.check_rc = 0
        self.install_rc = 0
        self.installs: list[list[str]] = []
        for c in clients:
            if installed is None:
                continue
            d = self.home / f".{c}" / "skills"
            d.mkdir(parents=True, exist_ok=True)
            (d / ".plaud-installed-ref").write_text(
                "schema: 1\nref: %s\n%s" % (
                    installed, "".join(f"skill: {s}\n" for s in sorted(self.local_skills))),
                encoding="utf-8")

    def install(self, args: list[str]) -> tuple[int, str]:
        self.installs.append(args)
        if self.install_rc == 0 and "--ref" in args:
            tag = args[args.index("--ref") + 1]
            for c in ("cursor", "claude", "codex", "agents"):
                m = self.home / f".{c}" / "skills" / ".plaud-installed-ref"
                if m.exists():
                    m.write_text(
                        "schema: 1\nref: %s\n%s" % (
                            tag, "".join(f"skill: {s}\n" for s in sorted(self.remote_skills))),
                        encoding="utf-8")
        return self.install_rc, "install output"


def build(world: World):
    """Import a fresh module bound to this world."""
    for mod in list(sys.modules):
        if mod == "update":
            del sys.modules[mod]
    os.environ["PLAUD_HOME"] = str(world.home)
    os.environ["PLAUD_STATE_DIR"] = str(world.home / "state")
    os.environ["PLAUD_RUNTIME_DIR"] = str(world.home / "runtime")
    import update  # noqa: PLC0415

    update.resolve_latest = lambda state: world.latest
    update.fetch_meta = lambda sha, tag: (
        {"compatibility": "unknown", "why": "no release-meta.json"} if world.meta is None
        else update.__dict__["_validate_meta"](world.meta, tag)
        if "_validate_meta" in update.__dict__ else _validate(world.meta, tag)
    )

    def run_installer(args):
        if "--check" in args:
            return (world.check_rc, "" if world.check_rc == 0 else "  x: CONTENT DIFFERS")
        return world.install(args)

    update.run_installer = run_installer
    # Do NOT stub skill_sets_match: stubbing it is exactly how the
    # "auto-update/ counts as a skill" bug slipped through. Stub the HTTP layer
    # underneath it instead, with a tree shaped like the real repository.
    def http_json(url: str):
        if "git/trees" in url:
            entries = [{"path": f"{name}/SKILL.md", "type": "blob"}
                       for name in sorted(world.remote_skills)]
            entries += [{"path": p, "type": "tree"} for p in world.remote_dirs]
            entries += [{"path": "auto-update/update.py", "type": "blob"},
                        {"path": "README.md", "type": "blob"}]
            return {"tree": entries, "truncated": world.tree_truncated}
        raise AssertionError(f"unexpected http_json: {url}")

    update.http_json = http_json
    return update


def _validate(meta: dict, tag: str) -> dict:
    if meta.get("schema") != 1 or meta.get("version") != tag:
        return {"compatibility": "unknown", "why": "metadata does not match the tag"}
    if meta.get("compatibility") not in ("compatible", "breaking"):
        return {"compatibility": "unknown", "why": "compatibility is not a known value"}
    return {"compatibility": meta["compatibility"], "headline": meta.get("headline", ""),
            "breaking_reasons": meta.get("breaking_reasons", []), "why": ""}


def case(name: str, tmp: Path, **kw):
    d = tmp / name.replace(" ", "_")
    d.mkdir(parents=True)
    return World(d, **kw)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="plaud-au-") as t:
        tmp = Path(t)

        # a compatible release installs, on startup
        w = case("compatible", tmp)
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        contains("compatible release installs", msg, "updated")
        check("…and called the installer with the tag",
              any("--ref" in a and "v0.3.4" in a for a in w.installs), True)
        check("…and cleared pending", (w.home / "state" / "pending.json").exists(), False)

        # a breaking release is held, not installed
        w = case("breaking", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "contract change", "breaking_reasons": ["ChangeSetId is now required"]}
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        contains("breaking release is announced", msg, "breaking")
        check("…and NOT installed", w.installs, [])
        check("…and left pending", (w.home / "state" / "pending.json").exists(), True)

        # metadata that does not match the tag is 'unknown' -> hold
        w = case("meta_mismatch", tmp)
        w.meta = {"schema": 1, "version": "v9.9.9", "compatibility": "compatible"}
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("mismatched metadata does not install", w.installs, [])
        contains("…and says why", msg, "not installed")

        # missing metadata (old tags) -> hold
        w = case("meta_missing", tmp)
        w.meta = None
        u = build(w)
        u.do_run(event="startup", force=True)
        check("missing metadata does not install", w.installs, [])

        # not a startup event -> never installs, even when compatible
        w = case("resume", tmp)
        u = build(w)
        msg = u.do_run(event="resume", force=True)
        check("resume/compact never installs", w.installs, [])
        contains("…and says the session is already running", msg, "session already running")

        # a skill was added upstream -> hold
        w = case("skillset", tmp)
        w.remote_skills = w.local_skills | {"plaud-theme-new"}
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("skill-set change does not install", w.installs, [])
        contains("…and says so", msg, "skill set changed")

        # local tree drifted -> hold
        w = case("dirty", tmp)
        w.check_rc = 4
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("non-pristine tree does not install", w.installs, [])
        contains("…and says so", msg, "not pristine")

        # already current -> silence
        w = case("current", tmp, installed="v0.3.4")
        u = build(w)
        check("already current says nothing", u.do_run(event="startup", force=True), "")

        # package not installed at all -> never auto-install onto this machine
        w = case("absent", tmp, installed=None)
        u = build(w)
        check("absent package stays absent", u.do_run(event="startup", force=True), "")
        check("…and no installer call", w.installs, [])

        # network failure -> silent, and backed off
        w = case("offline", tmp)
        u = build(w)

        def boom(state):
            raise OSError("no route to host")

        u.resolve_latest = boom
        check("network failure is silent", u.do_run(event="startup", force=True), "")
        state = json.loads((w.home / "state" / "state.json").read_text())
        check("…and recorded a failure", state["last_failure"]["kind"], "network")
        check("…and backed off", state["next_check_after"] > time.time() + 60, True)

        # install failure -> reported, pending kept
        w = case("install_fails", tmp)
        w.install_rc = 1
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        contains("install failure is reported", msg, "failed")
        check("…and left pending", (w.home / "state" / "pending.json").exists(), True)

        # the frequency valve
        w = case("valve", tmp)
        u = build(w)
        u.do_run(event="startup", force=True)
        before = len(w.installs)
        u.do_run(event="startup", force=False)  # too soon
        check("second run inside the interval does not re-check", len(w.installs), before)

        # a held release can be applied on purpose
        w = case("manual_apply", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "contract change", "breaking_reasons": ["x"]}
        u = build(w)
        u.do_run(event="startup", force=True)
        check("breaking held", w.installs, [])
        msg = u.do_run(event="manual", force=True, apply_breaking=True)
        contains("explicit apply installs it", msg, "updated")

        # lock: a second concurrent run stays out
        w = case("lock", tmp)
        u = build(w)
        lock = u.Lock()
        lock.__enter__()
        try:
            check("second runner defers to the lock holder",
                  u.do_run(event="startup", force=True), "")
        finally:
            lock.__exit__()

        # remote text must not be able to paint the terminal
        w = case("sanitize", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "evil\n\x1b[31mRED\x1b[0m" + "x" * 500, "breaking_reasons": []}
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("no control characters reach the message", "\x1b" in msg or "\n" in msg, False)
        check("…and it is bounded", len(msg) < 600, True)

        # --- the regressions Codex's review turned up ---

        # a root dir that is not a skill (auto-update/) must not read as "added skill"
        w = case("nonskill_dirs", tmp)
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        contains("non-skill root dirs do not block the update", msg, "updated")

        # a truncated tree listing is not evidence of anything
        w = case("truncated", tmp)
        w.tree_truncated = True
        u = build(w)
        u.do_run(event="startup", force=True)
        check("truncated tree listing does not install", w.installs, [])

        # manual apply waives 'breaking' — and nothing else
        w = case("apply_dirty", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "x", "breaking_reasons": ["y"]}
        w.check_rc = 4  # tree is not pristine
        u = build(w)
        msg = u.do_run(event="manual", force=True, apply_breaking=True)
        check("apply --yes does NOT override a dirty tree", w.installs, [])
        contains("…and says why", msg, "not pristine")

        w = case("apply_unknown", tmp)
        w.meta = {"schema": 1, "version": "v9.9.9", "compatibility": "compatible"}
        u = build(w)
        u.do_run(event="manual", force=True, apply_breaking=True)
        check("apply --yes does NOT override unidentifiable metadata", w.installs, [])

        w = case("apply_skillset", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "x", "breaking_reasons": []}
        w.remote_skills = w.local_skills | {"plaud-theme-new"}
        u = build(w)
        u.do_run(event="manual", force=True, apply_breaking=True)
        check("apply --yes does NOT override a skill-set change", w.installs, [])

        # the pinned commit reaches the installer
        w = case("pinned", tmp)
        u = build(w)
        u.do_run(event="startup", force=True)
        args = w.installs[-1]
        check("installer gets --commit", "--commit" in args, True)
        check("…with the resolved sha", args[args.index("--commit") + 1], "sha-334")

        # confirming release X must not install release Y
        w = case("tag_drift", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "x", "breaking_reasons": []}
        u = build(w)
        u.do_run(event="startup", force=True)
        w.latest = ("v0.3.5", "sha-335")
        w.meta = {"schema": 1, "version": "v0.3.5", "compatibility": "compatible"}
        msg = u.do_run(event="manual", force=True, apply_breaking=True, expect_tag="v0.3.4")
        check("confirming an older tag does not install the newer one", w.installs, [])
        contains("…and says so", msg, "confirm again")

        # verification failure after a zero-exit install is not success
        w = case("verify_fails", tmp)
        u = build(w)

        calls = {"n": 0}
        real_install = w.install

        def install_then_dirty(args):
            rc, out = real_install(args)
            calls["n"] += 1
            w.check_rc = 4  # post-install --check reports drift
            return rc, out

        w.install = install_then_dirty
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("post-install verification failure keeps pending",
              (w.home / "state" / "pending.json").exists(), True)
        contains("…and reports it", msg, "verification")

        # a network blip must not hide an existing breaking notice
        w = case("blip", tmp)
        w.meta = {"schema": 1, "version": "v0.3.4", "compatibility": "breaking",
                  "headline": "x", "breaking_reasons": ["y"]}
        u = build(w)
        u.do_run(event="startup", force=True)

        def boom2(state):
            raise OSError("offline")

        u.resolve_latest = boom2
        msg = u.do_run(event="startup", force=True)
        contains("offline still shows the pending breaking release", msg, "breaking")

        # clients on different versions is itself a blocker
        w = case("mixed", tmp)
        (w.home / ".claude" / "skills" / ".plaud-installed-ref").write_text(
            "schema: 1\nref: v0.3.1\nskill: plaud-theme-dev\n", encoding="utf-8")
        u = build(w)
        msg = u.do_run(event="startup", force=True)
        check("mixed client versions do not auto-install", w.installs, [])
        contains("…and says so", msg, "different versions")

        # corrupt state must not wedge the checker
        w = case("corrupt_state", tmp)
        u = build(w)
        (w.home / "state").mkdir(parents=True, exist_ok=True)
        (w.home / "state" / "state.json").write_text('{"next_check_after": "soon"}',
                                                     encoding="utf-8")
        check("unreadable next_check_after re-checks", u.should_check(
            {"next_check_after": "soon"}, False), True)
        check("NaN next_check_after re-checks", u.should_check(
            {"next_check_after": float("nan")}, False), True)

        # the installer must be told which HOME to install into
        w = case("home_env", tmp)
        u = build(w)
        seen = {}

        def capture_env(args):
            import subprocess as sp
            seen["env"] = {**os.environ, "HOME": str(u.HOME)}
            return w.install(args) if "--check" not in args else (0, "")

        u.run_installer = capture_env
        u.do_run(event="startup", force=True)
        check("installer is handed the resolved HOME",
              seen.get("env", {}).get("HOME"), str(w.home))

        # --- guard: the skill-invocation entry point ---

        # a skill invocation never installs, however compatible the release is
        w = case("guard_no_install", tmp)
        u = build(w)
        msg = u.do_run(event="skill", force=True)
        check("a skill invocation does not replace files in use", w.installs, [])
        contains("…and says why", msg, "not replaced mid-task")

        # …and its deadline is its own, not the session's
        w = case("guard_deadline", tmp)
        u = build(w)
        now = time.time()
        state = {"next_check_startup": now + 9999, "next_check_skill": 0}
        check("a skill check is not blocked by the session deadline",
              u.should_check(state, False, event="skill"), True)
        check("…and vice versa",
              u.should_check({"next_check_skill": 0, "next_check_startup": now + 9999},
                             False, event="startup"), False)

        # the notice is printed once per release, not at every skill call
        w = case("guard_once", tmp)
        u = build(w)
        u.PENDING_FILE.parent.mkdir(parents=True, exist_ok=True)
        u.PENDING_FILE.write_text(json.dumps(
            {"tag": "v0.3.4", "compatibility": "breaking", "breaking_reasons": ["x"],
             "blockers": ["release declares breaking changes"]}), encoding="utf-8")
        first = u.guard_notice()
        second = u.guard_notice()
        contains("the first skill call announces the release", first, "v0.3.4")
        check("…and the second stays quiet", second, "")

        # env switches must read as booleans, not as "any value at all"
        w = case("guard_env", tmp)
        u = build(w)
        for value, want in (("1", True), ("true", True), ("0", False),
                            ("false", False), ("", False)):
            os.environ["PLAUD_TEST_FLAG"] = value
            check(f"env_true({value!r})", u.env_true("PLAUD_TEST_FLAG"), want)
        os.environ.pop("PLAUD_TEST_FLAG", None)

        # installer timeout is a failure, not a crash
        w = case("timeout", tmp)
        u = build(w)

        def timeout_install(args):
            if "--check" in args:
                return 0, ""
            raise __import__("subprocess").TimeoutExpired(cmd="install.sh", timeout=600)

        u.run_installer = timeout_install
        msg = u.do_run(event="startup", force=True)
        contains("installer timeout is reported, not raised", msg, "could not run")

    print()
    if FAILURES:
        print(f"{len(FAILURES)} failing: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
