#!/usr/bin/env python3
"""Create a yidian Draft PR.

Any base branch is allowed. What this script still enforces:

- the PR is created as a Draft (`gh pr create --draft`);
- `--head` is explicit and is not the base branch itself (the workflow always puts
  the cherry-picked commits on a separate PR branch);
- the body carries the five required yidian sections.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

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


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a yidian Draft PR against any base branch."
    )
    parser.add_argument("--base", required=True, help="Base branch for the PR.")
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
