---
name: yidian-draft-pr
description: Enforce the yidian pull request workflow for GitHub repos. Use when a user asks to create, inspect, or prepare a PR for a yidian repo, especially requests involving cherry-picking selected commits onto a fresh PR branch (any base branch — develop, us/yidian-dev, global/yidian-dev, jp/yidian-main, us/yidian-main, main, or any other). This skill requires cherry-pick based PR branches, requires all created PRs to be Draft PRs, and requires the yidian Shopify PR body sections for summary, verification evidence, screenshots, risk, rollback, and regression matrix. It does not restrict which branch a PR targets.
---

# Yidian Draft PR

Create yidian PRs by cherry-picking selected commits onto a fresh PR branch. Never merge an entire source branch, and never create a ready-for-review PR.

> 本 skill 是 `plaud-theme-matrix` 包内**附带的工具 skill**，不属于主题矩阵的阶段轴：
> 它不占 order、不进路由判定树、不产出也不消费 `ChangeSetId` / `HandoffContract` 等矩阵契约字段。
> 主题改动本身的评估、实现与验收仍走 `plaud-theme-*` 矩阵；本 skill 只管把已有 commit 变成一个合规的 Draft PR。

## Hard Rules

- Any base branch is allowed. Take the base from the user; when it is not stated, ask instead of guessing.
- Create PRs only as Draft PRs.
- Start from the latest state of the chosen base branch and create a separate PR branch.
- Cherry-pick only the commits selected by the user or confirmed after inspection.
- Use the required PR body template; do not leave placeholder fields when evidence can be derived from git, gh, or local verification.
- Do not use `git merge <source-branch>` for this workflow.
- Do not mark a PR ready for review unless the user explicitly asks after PR creation.
- Never push directly to the chosen base branch, or to any other shared/protected branch. The PR branch you created is the only branch you push.
- Do not use destructive git commands such as `git reset --hard` or `git checkout -- <file>` unless the user explicitly requests them.

## Workflow

1. Confirm the target repo and working tree.

```bash
git status -sb
git remote -v
gh repo view
```

2. Fetch remotes.

```bash
git fetch origin --prune
```

3. Identify candidate commits from the source branch.

```bash
git log --oneline origin/<base>..origin/<source-branch>
git show --stat <commit-sha>
git show --name-only <commit-sha>
```

Ask for confirmation before cherry-picking if the commit set is ambiguous.

4. Create a fresh PR branch from the latest base.

```bash
git switch <base>
git pull --ff-only origin <base>
git switch -c pr/<task-name>-to-<base-slug>
```

The base slug is the base branch name with `/` replaced by `-` (`us/yidian-dev` → `us-yidian-dev`, `develop` → `develop`, `main` → `main`).

5. Cherry-pick the selected commits in original order.

```bash
git cherry-pick <commit-sha-1>
git cherry-pick <commit-sha-2>
```

If conflicts occur, show `git status -sb` and the conflicting files. Resolve only task-related conflicts, then continue:

```bash
git add <resolved-files>
git cherry-pick --continue
```

Abort only when the selected commits are wrong or the user asks:

```bash
git cherry-pick --abort
```

6. Validate before pushing.

```bash
git status -sb
git log --oneline origin/<base>..HEAD
git diff --stat origin/<base>...HEAD
git diff --name-only origin/<base>...HEAD
git diff --check origin/<base>...HEAD
```

Run project checks when available and relevant, such as `pnpm lint`, `pnpm test`, or `pnpm typecheck`.

7. Push the PR branch.

```bash
git push -u origin HEAD
```

If push is rejected, fetch and inspect remote differences. Do not force-push unless it is the agent-created PR branch and `--force-with-lease` is clearly safe.

8. Create the PR with the bundled script.

Prefer `scripts/create_draft_pr.py`, which ships next to this SKILL.md. It always adds `--draft`, requires an explicit `--head` that differs from `--base`, and refuses a body missing any of the five required sections.

The script lives in the **installed skill directory**, not in the repo you are working in — the git commands above run in the target repo, so a bare relative path would resolve against that repo and fail. Resolve the skill directory first:

```bash
# whichever client installed the matrix package
skill_dir="$HOME/.claude/skills/yidian-draft-pr"   # or ~/.codex, ~/.cursor, ~/.agents

python3 "$skill_dir/scripts/create_draft_pr.py" \
  --base develop \
  --head pr/example-to-develop \
  --title "feat: example" \
  --body-file /tmp/pr-body.md
```

If none of those paths exist, fall back to `gh pr create --draft --base <base> --head <pr-branch> --title <title> --body-file <file>` and check the five body sections yourself.

Use `--body` for short bodies. Use `--body-file` for multi-line PR descriptions.

## PR Body

Use this required structure. Fill every field with concrete information when possible. If a field cannot be completed, write `待补充：<specific missing item>` rather than a generic placeholder.

```markdown
## Summary
- <业务目的和主要改动>

## Test Plan / Verification Evidence
- Shopify preview: <预览链接；没有则写 待补充：Shopify preview URL>
- Manual verification: <实际验收步骤和结果>
- Screenshots / Recording: <截图或录屏链接；没有则写 待补充：截图/录屏>

## Risk / Rollback
- 主要风险：<影响范围、潜在回归点和验证范围>
- 回滚方案：<可执行回滚方式，如 revert PR 或 revert commit>

## Regression Matrix
- Desktop ≥1025: <验收结果或待补充项>
- Tablet 768-1024: <验收结果或待补充项>
- Mobile ≤767: <验收结果或待补充项>
- Related schema/block/effect switches: <相关 schema、block、effect、开关验收结果>

## Commits
- <sha> <message>
```

Before creating the PR, derive what you can:

- Summary from selected commit messages and changed files.
- Manual verification from commands actually run, such as `git diff --check origin/<base>...HEAD`, lint, tests, or theme checks.
- Risk from `git diff --name-only origin/<base>...HEAD`, especially `sections/`, `snippets/`, `assets/`, `templates/`, `locales/`, and schema changes.
- Rollback from the PR branch/commit list, usually `revert this PR` or `git revert <sha>`.
- Regression matrix from the files and UI surfaces touched. If visual verification was not performed, say exactly that.

## Final Response

Report:

- PR URL
- base and head branch
- cherry-picked commit SHAs
- whether the PR is draft
- validation commands and PR body fields that remain `待补充`

If no PR was created, report the blocker and the current branch/status.
