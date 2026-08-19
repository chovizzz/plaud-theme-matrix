---
name: yidian-draft-pr
description: Enforce the yidian pull request workflow for GitHub repos. Use when a user asks to create, inspect, or prepare a PR for a yidian repo, especially requests involving cherry-picking selected commits onto a fresh PR branch (any base branch — develop, us/yidian-dev, global/yidian-dev, jp/yidian-main, us/yidian-main, main, or any other). This skill requires cherry-pick based PR branches, requires all created PRs to be Draft PRs, and requires the yidian Shopify PR body sections for summary, verification evidence, screenshots, risk, rollback, and regression matrix. It does not restrict which branch a PR targets. It does restrict which FILES reach the PR: only Shopify theme code goes in — editor/agent droppings and caches are dropped outright, and any other non-theme path (CI, repo scripts, docs, lockfiles) is confirmed with the user path by path before it stays.
---

# Yidian Draft PR

Create yidian PRs by cherry-picking selected commits onto a fresh PR branch. Never merge an entire source branch, and never create a ready-for-review PR.

> 本 skill 是 `plaud-theme-matrix` 包内**附带的工具 skill**，不属于主题矩阵的阶段轴：
> 它不占 order、不进路由判定树、不产出也不消费 `ChangeSetId` / `HandoffContract` 等矩阵契约字段。
> 主题改动本身的评估、实现与验收仍走 `plaud-theme-*` 矩阵；本 skill 只管把已有 commit 变成一个合规的 Draft PR。

## 包更新提示（不属于本 skill 的流程）

开工前跑一次，它不改变本 skill 的任何步骤或判定：

```sh
sh ~/.local/share/plaud-theme-matrix/bin/plaud-matrix-update guard || true
```

命令不存在或网络不通都会静默成功，照常继续。**不要重定向它的 stderr** —— 它只在发现新版本时
在那里打一行，打印了就转告用户。它不会替换正在用的文件。关掉：`PLAUD_NO_UPDATE_CHECK=1`。

## Hard Rules

- Any base branch is allowed. Take the base from the user; when it is not stated, ask instead of guessing.
- Create PRs only as Draft PRs.
- Start from the latest state of the chosen base branch and create a separate PR branch.
- Cherry-pick only the commits selected by the user or confirmed after inspection.
- Use the required PR body template; do not leave placeholder fields when evidence can be derived from git, gh, or local verification.
- **Nothing reaches the PR that is not Shopify theme code, unless the user confirmed it path by path.** Junk (editor droppings, agent/tool dirs, caches, backups) is dropped without asking — it is never confirmable. Everything else outside the theme — CI, repo scripts, docs, lockfiles, top-level Markdown — is **asked about, one path at a time**, and only what the user confirms stays. See "Theme-only file gate".
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

5. Cherry-pick the selected commits in original order — **one at a time**, cleaning each before moving on.

```bash
git cherry-pick <commit-sha-1>
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

Then, before picking the next one, classify what this commit brought in and clean it (see "Theme-only file gate"). Cleaning after all the picks does not work: `git commit --amend` only reaches the last commit, so anything dragged in by an earlier one is out of reach without a rebase.

```bash
skill_dir="$HOME/.claude/skills/yidian-draft-pr"   # or ~/.codex, ~/.cursor, ~/.agents
python3 "$skill_dir/scripts/check_theme_files.py" --base HEAD~1 --head HEAD
```

Repeat pick → check → clean → amend for each remaining commit.

6. Validate before pushing.

```bash
git status -sb
git log --oneline origin/<base>..HEAD
git diff --stat origin/<base>...HEAD
git diff --name-only origin/<base>...HEAD
git diff --check origin/<base>...HEAD
```

Run project checks when available and relevant, such as `pnpm lint`, `pnpm test`, or `pnpm typecheck`.

7. Check that only theme code is in the branch.

```bash
skill_dir="$HOME/.claude/skills/yidian-draft-pr"   # or ~/.codex, ~/.cursor, ~/.agents
python3 "$skill_dir/scripts/check_theme_files.py" --base origin/<base> --head HEAD
```

This is the **cumulative** check over the whole branch; step 5 already checked each commit as it landed. Run it again here because a later commit can re-introduce a path an earlier cleanup removed.

Exit 0 = nothing outside the theme. Exit 1 = something needs dropping or confirming; the output groups it. Exit 2 = the check could not run — **fix that and re-run; never treat it as a pass.**

Fix what it reports **before pushing**: once a path is on the remote branch, getting it out means rewriting a pushed branch. The same check runs again inside the PR script (there is no flag to skip it), so a branch that fails here cannot become a PR either way.

8. Push the PR branch.

```bash
git push -u origin HEAD
```

If push is rejected, fetch and inspect remote differences. Do not force-push unless it is the agent-created PR branch and `--force-with-lease` is clearly safe.

9. Create the PR with the bundled script.

Prefer `scripts/create_draft_pr.py`, which ships next to this SKILL.md. It always adds `--draft`, requires an explicit `--head` that differs from `--base`, refuses a body missing any of the five required sections, and re-runs the theme-only file gate.

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

`--base` is the **GitHub base branch name** (no `origin/` prefix); the file gate compares against `<remote>/<base>` on its own. Override that comparison ref with `--base-ref` only if the remote-tracking ref is not what the PR will be diffed against.

The branch must already be pushed and the remote branch must be at the same commit as the local one — otherwise the PR would ship code the gate never saw, and the script refuses. Cross-fork PRs are not supported.

Pass `--allow-nontheme <path>` once per non-theme path the user confirmed (steps 5 and 7). It never accepts a junk path, and a path this diff does not actually need is an error rather than a no-op.

**If the script is missing, stop and tell the user** — do not fall back to a bare `gh pr create`. That path skips every check the script exists to enforce, and the file gate is the one keeping `.DS_Store` and local scratch dirs out of the repo. The user can re-install the matrix package to restore it.

Use `--body` for short bodies. Use `--body-file` for multi-line PR descriptions.

## Theme-only file gate

`scripts/theme_files.py` sorts every changed path into three buckets; both `check_theme_files.py` and `create_draft_pr.py` use it, so they cannot disagree.

| Bucket | What it is | What you do |
|---|---|---|
| **theme** | `assets/ blocks/ config/ layout/ locales/ sections/ snippets/ templates/`, `.theme-check.yml`, `.shopifyignore`, `shopify.theme.toml` | Keep. No question needed |
| **junk** | `.DS_Store`, `.backup/`, `.claude/`, `.codex/`, `.cursor/`, `.agents/`, `.shopify/`, caches, `node_modules/`, `*.log`, `*.bak`, `*.orig` — matched at **any** path depth | Drop. Not a judgement call, and `--allow` will not accept them |
| **ask** | Everything else: `.github/`, `scripts/`, `docs/`, `package.json`, lockfiles, `CLAUDE.md`, top-level Markdown | **Ask the user, path by path.** Keep only what they confirm, via `--allow` / `--allow-nontheme` |

Two more rules the gate applies:

- `config/settings_data.json` is theme code, but it is per-store/per-environment state that a cherry-pick routinely drags in from another site. It needs the same explicit confirmation as an `ask` path.
- **Deleting junk never blocks.** A PR whose point is removing `.DS_Store` is exactly what you want. Deleting an `ask` path (a workflow, a doc) is still a change outside the theme, so it needs the same confirmation as adding one.
- A **symlink or submodule pointer** under a theme path is not theme code however it is named; it lands in `ask`.

### Dropping a path from the branch

🔴 **Before touching anything: `git status --porcelain` must be empty.** These commands overwrite working-tree files. If the tree is dirty — and in this project `.DS_Store` is often tracked *and* modified — stop and ask the user what to do with those changes first. Show the user the exact paths you are about to drop and get confirmation; this is destructive.

Do this **right after the cherry-pick that introduced the path** (step 5), while it is still the last commit. For that commit:

```bash
# the path existed in this commit's parent (the commit modified it) — put it back
git restore --source=HEAD~1 --staged --worktree -- <path>

# the path did not exist in the parent (the commit added it) — remove it
git rm -f -- <path>

git commit --amend --no-edit
```

`--source=HEAD~1`, not the original base: after the first cleanup, each commit's parent is the previous *already-cleaned* commit. Do not "restore" a path the commit **deleted** — that would resurrect it.

If the commit is left with nothing after the cleanup — it carried only junk — it has to be dropped with `git reset --hard HEAD~1`. That is a destructive command, so the hard rule applies: **describe exactly what it will discard and get the user's explicit go-ahead before running it.** Without that, stop and report instead.

Two cherry-pick cases that come up here: a merge commit needs `-m 1` (or the parent the user names), and a pick whose changes are already present ends up empty — `git cherry-pick --skip` moves past it. Both fail safely if you get them wrong; neither is a reason to improvise.

If a later cherry-pick conflicts because it builds on a path you removed, stop and ask the user rather than resurrecting the path silently.

After each amend, re-run the check on the cumulative diff (`--base <remote>/<base> --head HEAD`); a later commit can re-introduce a path you removed from an earlier one.

If the branch is already pushed, the amend rewrites history — only force-push a branch you created yourself, with `--force-with-lease`.

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
