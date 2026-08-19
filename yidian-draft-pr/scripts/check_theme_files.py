#!/usr/bin/env python3
"""Report which of a PR branch's changed files are not Shopify theme code.

Run this in the target repo after cherry-picking and BEFORE pushing. The same
classification runs again inside `create_draft_pr.py`, so a branch that fails
here cannot be turned into a PR by skipping this step.

  python3 check_theme_files.py --base origin/develop --head HEAD

Exit codes:
  0  nothing outside the theme (or every extra path explicitly --allow'd)
  1  junk and/or unconfirmed non-theme paths present
  2  the diff could not be evaluated (not a git repo, unknown ref, no merge base)

Exit 2 is never treated as a pass: a gate that opens when it cannot see is not
a gate.
"""

from __future__ import annotations

import argparse
import json
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))

from theme_files import GitError, evaluate, render  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Classify a PR branch's changed files as theme / junk / ask."
    )
    ap.add_argument(
        "--base",
        required=True,
        help="Base ref. Prefer the fetched remote ref (origin/develop), not a "
        "local branch that may be behind.",
    )
    ap.add_argument("--head", default="HEAD", help="Head ref. Default: HEAD.")
    ap.add_argument(
        "--allow",
        action="append",
        default=[],
        help="Exact path the user confirmed belongs in this PR despite not being "
        "theme code. Repeatable. Never applies to junk paths.",
    )
    ap.add_argument("--json", action="store_true", help="Machine-readable output.")
    ap.add_argument("-C", dest="cwd", default=None, help="Run in this directory.")
    args = ap.parse_args()

    try:
        result = evaluate(args.base, args.head, allow=set(args.allow), cwd=args.cwd)
    except GitError as exc:
        if args.json:
            print(json.dumps({"verdict": "unevaluable", "error": str(exc)}))
        else:
            print(f"Cannot evaluate the diff: {exc}", file=sys.stderr)
            print(
                "Run this inside the target repo, and `git fetch origin --prune` "
                "first so the base ref resolves (e.g. --base origin/develop).",
                file=sys.stderr,
            )
        return 2

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("\n".join(render(result)))
    return 1 if result["verdict"] == "blocked" else 0


if __name__ == "__main__":
    sys.exit(main())
