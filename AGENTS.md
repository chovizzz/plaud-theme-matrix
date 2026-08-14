# PLAUD Shopify Theme Matrix — Installation Guide for AI Agents

## Goal

Install all skills from this package into supported AI IDE / agent skill directories,
and retire the superseded single skill it replaces.

This package root is **not** a skill. Each root-level directory containing `SKILL.md`
is one independent skill. Never copy the package root itself into a skills directory.

Package version: `v0.3.0`.

## Supported Targets

- Cursor: `~/.cursor/skills`
- Claude: `~/.claude/skills`
- Codex: `~/.codex/skills`
- Agents: `~/.agents/skills`

Windows PowerShell equivalents live under `$HOME\.cursor\skills`, `$HOME\.claude\skills`,
`$HOME\.codex\skills`, and `$HOME\.agents\skills`.

## Important Rules

- Run the installer from this package root.
- **Do not narrow `--clients`.** With no options the installer already targets all four.
  Installing a subset is how client drift happens: two clients on one spec, two on
  another, both processing the same project.
- Do not manually copy individual skills unless the installer fails.
- Existing same-name skills are **fully replaced** (destination is `rm -rf`'d, then
  extracted), so no stale files survive inside a skill.
- Do not edit package contents during installation.
- A workspace-level `.cursor/skills/<skill-name>` can shadow the global install; update
  or remove stale workspace copies when testing.

## macOS / Linux Install

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh
```

Preview without touching install targets, backups, or any skill:

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --dry-run
```

Only when a client's skills dir does not exist yet:

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --create-missing all
```

## Windows PowerShell Install

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1)))
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -CreateMissing all
```

## Legacy Retirement — a PRECONDITION, not an option

This matrix **replaces** the single skill `plaud-shopify-theme`. Both match the same
trigger surface (Plaud theme code, `sections/` `snippets/` `assets/`, Swiper,
Figma → `sa-*`, UX Spec v1.3 migration), so leaving the old skill installed causes
**routing competition** — one task matching two different specs.

The installer therefore **fails closed**: if any target still has the old skill, it
**aborts, installs nothing, deletes nothing**, and exits **2**.

| Invocation | Behaviour | Exit |
|---|---|---:|
| interactive terminal, no switch | asks whether to retire and continue; `y` → retire + install, `n`/EOF → abort | 0 / 2 |
| non-interactive (CI, pipe, `--yes`) without `--retire-legacy` | aborts, prints manual commands | 2 |
| `--retire-legacy --yes` | archive → verify → remove → install | 0 |
| `--keep-legacy` | installs alongside the old skill, loud UNSUPPORTED warning | 3 |

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --dry-run                 # shows the abort truthfully
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --retire-legacy --yes     # recommended
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --keep-legacy             # dual-spec, unsupported
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -RetireLegacy -Yes
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -KeepLegacy
```

Retirement behaviour:

1. Detect `~/.<client>/skills/plaud-shopify-theme/` in every install target.
2. **Archive first, verify, delete second.** The backup is
   `<skills-dir>/.plaud-legacy-backup-<timestamp>/plaud-shopify-theme.tar.gz`
   (`.zip` on Windows). Verification is a **set comparison**: every file on disk must
   appear in the archive — a surplus of archive entries cannot mask a missing file.
   If verification fails, or the archive destination already exists, the original stays
   and nothing is removed.
3. **Re-scan after retirement.** Any survivor (failed verification, pre-existing
   archive, link) still aborts the install. The matrix is never installed over a
   survivor.
4. `--backup-dir DIR` / `-BackupDir DIR` changes the backup base. A unique timestamped
   subdirectory is always appended, so four clients cannot collide on one file. `/`,
   drive roots, the home directory itself, and any path inside the skill being retired
   are rejected.

A legacy path that is a **symlink / junction is never followed or deleted** — the script
refuses to act on it, but it still **blocks the install**. Remove it by hand; the script
prints the exact command. Dangling links are detected too (the scan enumerates directory
entries by name rather than resolving them, so a broken link cannot slip through and
resurface later).

Safety boundaries on the destructive path:

- `--target` must resolve to a directory whose **last component is exactly `skills`** —
  not merely a path containing the word. As a convenience, passing a client root that
  contains a `skills/` subdirectory appends that level; anything else is rejected. The
  same validator guards install and deletion.
- The validator resolves the **physical** path: if the `skills` dir or any ancestor is a
  symlink / junction, the path is refused, so a delete cannot escape into another tree.
- Immediately before deleting, the script re-asserts that the parent is a validated
  skills dir, that the directory name is in the legacy allowlist, and that the directory
  is not a symlink / junction.
- Prompts fail closed: an EOF or a non-interactive host is treated as "no", never as
  silent consent. `--retire-legacy` in a non-interactive host requires `--yes`.
- Backups are archives, not directories, so a backup never contains a discoverable
  directory-level `SKILL.md` that a client could scan and route to. Both installers
  additionally skip dot-prefixed directories when scanning for skill sources.

## Exit Codes

| Code | Meaning |
|---:|---|
| 0 | success |
| 1 | usage / configuration error |
| 2 | aborted: legacy skill present and not retired — nothing installed, nothing deleted |
| 3 | installed with `--keep-legacy` — dual-spec, UNSUPPORTED |

CI should treat anything other than 0 as a failure, and 3 specifically as "the
environment is ambiguous and must be fixed".

## Skipped Clients

A client whose skills dir does not exist is **skipped**, not created, unless
`--create-missing` names it. Both installers list every skipped client and its path at
the end of the run. If a client you expected is in that list, it did **not** get the
matrix.

## Verification

After installation, verify these directories exist under each target:

- `plaud-theme-shared/SKILL.md`
- `plaud-theme-orchestrator/SKILL.md`
- `plaud-theme-impact/SKILL.md`
- `plaud-theme-dev/SKILL.md`
- `plaud-theme-section-build/SKILL.md`
- `plaud-theme-ux-migration/SKILL.md`
- `plaud-theme-qa-intake/SKILL.md`
- `plaud-theme-qa/SKILL.md`
- `plaud-theme-feedback-triage/SKILL.md`
- `plaud-theme-release-ops/SKILL.md`

The installer prints a declared-version table per client at the end. **A declared
version is only a declaration.** The real proof the copy landed is a tree diff — run
this from the package root:

```bash
for c in cursor claude codex agents; do
  d=0
  for s in $(ls -d plaud-theme-*/ | xargs -n1 basename); do
    diff -rq "$s" "$HOME/.$c/skills/$s" >/dev/null 2>&1 || d=$((d+1))
  done
  echo "$c : $d/10 mismatched"
done
```

Every client must print `0/10`. A release that only lands on some clients leaves two
specs running at once against one project.

## Routing Cheat Sheet

Read `MATRIX.md` for the full state machine. For an agent deciding which skill to load:

| User asks for | Skill |
|---|---|
| 单个 bug / 性能 / UX 微调 / A11y / code review | `plaud-theme-dev` |
| Figma 稿 → `sa-*` section | `plaud-theme-section-build` |
| UX Spec v1.3 迁移 / 刷模块 / 对齐 ux | `plaud-theme-ux-migration` |
| "改这个会影响什么" / blast radius / 依赖树 | `plaud-theme-impact` |
| 验收 / 回归 / theme check / 能不能发了 | `plaud-theme-qa` |
| 必须拆成 ≥2 个可独立验收的 ChangeSet：迁移 wave / 多块排序与并行判定 / Cross(A+C) 裂块 | `plaud-theme-orchestrator` |
| "矩阵怎么衔接" / "handoff 字段是什么" | `plaud-theme-shared` |

**Do not route a plain bugfix through the orchestrator.** A single block that walks
Assess → Implement → Verify is the normal chain, not a "full flow"; the three
implementation skills already call `plaud-theme-impact` and hand off to
`plaud-theme-qa` on their own.

## Contract Rules an Agent Must Not Break

Read `plaud-theme-shared/references/handoff-schema.md` before any matrix work.

- **Only `plaud-theme-qa` may output `ReadyForDelivery: Yes`.** Implementation skills
  are permanently `No` + `QAStatus: NotRun`. The orchestrator cannot grant delivery
  either — aggregating QA results does not create permission.
- `ChangeSetId` is generated by the implementation skill and consumed by QA. If the
  working tree does not match `ModifiedFiles`, QA stops. It does not "verify the extra
  changes while it's there".
- **Stop, don't guess.** Missing upstream evidence means halt and ask, never fill in
  from experience.
- Every **stage** skill (`plaud-theme-impact`, the three implementation skills,
  `plaud-theme-qa`) ends its reply with the yaml contract block for its stage
  (handoff-schema §3 / §4 / §5). Fields may not be renamed, omitted, or folded into
  prose. `plaud-theme-orchestrator` is not a stage producer: it emits the §9.1
  coordination artifact (`ArtifactKind: Coordination`) instead and must never fabricate
  a stage artifact.
- **Field values are closed enums** (handoff-schema §9.2), and there are **two sets**:
  values legal in a **stage contract block**, and values legal in **`memory/` record
  files**. `Done` / `Invalidated` / `Partial` are contract violations inside a stage
  block — but `Invalidated` *is* legal in `memory/changeset-log.md`. Do not mix the sets.
  In a contract block, `QAStatus` is only `NotRun` or `Skipped(UserWaived)`; a stage is
  only `Assess` / `Implement` / `Verify`.
- `NotApplicable` is a **legal terminal state**, unlike `Blocked` / `NotRun` — but it
  requires applicability evidence ("no `.liquid` changed, so Theme Check does not
  apply"). A `NotApplicable` with no evidence is treated as `Blocked`.
- `ChangeSetId` binds **content**, not just filenames: the identity triple
  `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` (an immutable git tree
  object, built from a blank temp index; no commit, no HEAD/ref/user-index mutation) is
  recomputed by QA before any check runs. Same file list with changed content is a
  mismatch and stops QA. `BaseHeadSha` is the pre-work baseline — recorded, not compared.
- `AllChangeSetsDelivered` in the orchestrator's artifact is a **roll-up reading, not a
  delivery permission**. The coordination artifact carries no `ReadyForDelivery` field at
  all.
- Redline values and design baselines live only in `plaud-theme-shared/references/`.
  Do not copy numbers into other skills.

## Project State Files (`memory/`, not shipped)

Template inventory, module migration status, known deviations, and the ChangeSet log
are **project runtime state**, not spec. They live on the project side because
installing this package would otherwise overwrite them:

- `memory/模板清单.md`
- `memory/模块清单.md`
- `memory/全局已知偏差.md`
- `memory/changeset-log.md`

If they are missing, **stop and ask the user**. Do not reconstruct them — a
reconstructed inventory drifts from real migration progress and causes duplicate or
missed migrations.

## Troubleshooting

- No install target found → rerun with `--create-missing all`
  or `-CreateMissing all`.
- The IDE still routes to the old `plaud-shopify-theme` → it was not retired; rerun
  with `--retire-legacy`, or check for a workspace-level copy shadowing the global one.
- The IDE still uses an old matrix version → run the `0/10` tree diff above; a declared
  version match is not proof.
