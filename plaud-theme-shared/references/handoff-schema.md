# Handoff Schema — 矩阵唯一契约

本文件是 `plaud-shopify-theme-matrix` 全部 skill 的**唯一** handoff 契约。任何 skill 都不得自行定义字段、改字段名、或新增终态词汇。字段冲突时以本文件为准。

---

## 0. 两轴状态机

矩阵由**阶段轴**和**路径轴**交叉构成。路径决定"按什么规则实现"，阶段决定"现在处于评估、实现还是验证"。

| 阶段 | Path A（通用开发） | Path B（Figma section） | Path C（UX 迁移） |
|---|---|---|---|
| **Assess** | `plaud-theme-impact`（LegacyImpact） | `plaud-theme-impact`（IntegrationSurface） | `plaud-theme-impact`（LegacyImpact）+ 迁移实例审计 |
| **Implement** | `plaud-theme-dev` | `plaud-theme-section-build` | `plaud-theme-ux-migration` |
| **Verify** | `plaud-theme-qa`（QA-A + QA-Global） | `plaud-theme-qa`（QA-B + QA-Global） | `plaud-theme-qa`（QA-C + QA-Global） |

阶段单向推进：`Assess → Implement → Verify`。不得跳过 Assess 直接 Implement，除非满足 §3 的 `InlineLite` 豁免条件。**任何有改动的任务都不得跳过 Verify。**（唯一例外是 §2 的零改动只读任务——它根本没有 ChangeSet 可验，`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`，由实现 skill 出 `ReadOnlyProof` 收尾。v0.2.2 第八轮更正：原文写「任何情况下」，与 §2 的只读免 QA 直接冲突。）

### 0.1 阶段轴之外的四个非阶段 skill

矩阵里有四个 skill **不在阶段轴上**，它们不产出 §3 / §4 / §5 的阶段工件，只产出 §9.1 的各类工件：

| skill | 位置 | 工件 | 是否阻断阶段推进 |
|---|---|---|---|
| `plaud-theme-orchestrator` | 阶段轴之外（编排） | `ArtifactKind: Coordination` | 否，只记台账 |
| `plaud-theme-qa-intake` | **Implement → Verify 的过渡关口** | `ArtifactKind: QAIntake` | **是**——提测包不全，QA 不启动 |
| `plaud-theme-feedback-triage` | 事件入口（QA 打回 / 运营验收 / 上线后均可触发） | `ArtifactKind: FeedbackTriage` | 否，但会**新开**工作项回到 Assess |
| `plaud-theme-release-ops` | Verify 之后（发版与上线后） | `ArtifactKind: ReleaseOps` | 否，前置是 QA 的 `ReadyForDelivery: Yes` |

> 🔴 **`qa-intake` 不是第四个阶段。** 阶段轴永远只有 `Assess / Implement / Verify` 三值，任何 skill 都不得把它扩成四值、不得输出 `Stage: Handover` 之类的取值。qa-intake 产出的是一份**过渡工件**，夹在 Implement 工件与 Verify 之间，语义是「提测材料齐不齐」，与「代码行不行」正交。
>
> 为什么必须在 Verify **之前**：《DTC 开发交付标准 v1.0》§四 原文是「提测时必须同时提供，**缺一不进验收**」——交付物是**进验收的准入条件**，不是验收通过后的产物。把它放在 QA 之后是时序错误。

---

## 1. 交付权（不可协商）

> **只有 `plaud-theme-qa` 有权输出 `ReadyForDelivery: Yes`。**

推论，全部为硬规则：

1. `plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` 输出的 `ReadyForDelivery` **恒为 `No`**，且必须带 `QAStatus: NotRun`。
2. 实现类 skill **禁止**使用终态措辞：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」「没问题了」「改完了可以用」。允许的措辞是「改动已就位，待 QA」。
3. `Blocked` 与 `NotRun` **不得**折算为 pass——存在任一项时 `ReadyForDelivery` 必须是 `No`。

   `NotApplicable` 不同：它是**合法终态**，但必须给出适用性证据（例如"本次未改任何 `.liquid`，故 Theme Check 不适用"）。没有证据的 `NotApplicable` 一律按 `Blocked` 处理。区别在于——`Blocked` 是"该验但验不了"，`NotApplicable` 是"根本不需要验"；前者是风险，后者不是。
4. QA 通过后，**可发布内容**（`ThemeTreeOid`）或**本块声明范围**（`ChangeSetScopeFingerprint`）再次变化时，该 QA 结果**自动失效**，必须重新生成 `ChangeSetId` 并重跑 QA。
   🔴 v0.3.0 起「代码变化」有精确定义，不再等于「仓库里发生了任何事」：`git add` / `git reset` / `commit`（含 `commit memory/`）/ 仓库根 scratch 临时文件**都不算**变化（§2.8）。反过来，QA 跑在物化快照里，快照被篡改同样算失效（§2.6）。
5. 用户即使明说"不用检查了直接给我"，实现 skill 仍不得输出 `ReadyForDelivery: Yes`；正确做法是照常输出 `No` + `QAStatus: Skipped(UserWaived)`，并在正文一句话说明已按用户要求跳过验证、风险由用户承担。

### 1.1 `ReadyForDelivery: Yes` 的边界

它的含义**只有一个**：这批改动通过了矩阵内部的技术验证。它**不**代表：

| 不代表 | 归谁 |
|---|---|
| 运营 / PM 已验收 | PM，依据 PRD / Figma / UX Spec（见 `plaud-theme-feedback-triage`） |
| 可以推送到线上站点 | `plaud-theme-release-ops` 的推站清单二次确认 |
| 提测材料齐备 | `plaud-theme-qa-intake` 的 `SubmissionPackageStatus` |

三者正交，任何一个都不能替代另一个。QA 通过后仍可能被 PM 判为交付缺陷（例如与 Figma 不一致——这是 QA 不检查的维度）。

---

## 2. ChangeSetId 与对象绑定

`ChangeSetId` 是把「谁改的」和「谁验的」焊在一起的唯一凭据。QA 验的必须**就是**实现 skill 交出的那批改动。

**格式**：`CS-<YYYYMMDD>-<path><NN>`，例如 `CS-20260806-A03`、`CS-20260806-C11`。
- `<path>` ∈ `A` / `B` / `C`
- `<NN>` 为当日该路径的序号，从 `01` 起

**`<NN>` 怎么取**：
1. 读 `memory/changeset-log.md`，取**同一天、同一 `<path>`** 的已有最大序号 + 1；该日该路径没有行则从 `01` 起。
2. 生成后**立刻**在 `changeset-log.md` 追加一行占位（`ChangeSetId` + 生成时间 + 归属 skill），再开始实现——先占位是这套编号唯一的互斥手段。
3. 🔴 **独立 worktree / clone 里开发时 `memory/` 不共享，第 1 步读到的是各自的日志 → 必然撞号。** 此时不得自行生成：回 `plaud-theme-orchestrator` 由它在主树的日志里统一分配，或改为串行。
   📎 **v0.3.0 起同树并行 Implement 成为主推路径**，此时 `memory/changeset-log.md` **是共享的**，占位法重新有效——但两个 agent 同时写同一个日志文件是新的竞态，**「生成后立刻占位」是唯一防线**，不得攒到实现结束再补。
4. 日志里已有同号但内容不是本块 → **停机**，不要自造 `A01b` 之类的后缀格式。

### 2.1 身份是三个字段，缺一不可

只比对 `ModifiedFiles` 的**文件集合**是不够的：实现 skill 交出工件之后、QA 开始之前，如果同一批文件的**内容**又被改过，文件集合仍然一致，`ChangeSetIdMatched` 会错误地判为 `Yes`——QA 验的是一批它从未见过的代码。

v0.2.x 的做法是对「工作树状态文本」求 SHA-256。v0.3.0 换成**让 git 把当前可发布内容写成一个不可变的 tree 对象，用它的 oid 作身份**：

| 字段 | 是什么 | 谁产谁验 | 为什么缺它不行 |
|---|---|---|---|
| `ObjectFormat` | `sha1` \| `sha256` | 实现 skill 产、QA / release 验 | sha1 与 sha256 仓库对**同一内容**算出的 oid 完全不同。不记就会把「换了个仓库」误判成「内容变了」 |
| `ThemeTreeOid` | 可发布面（`assets blocks config layout locales sections snippets templates` + 仓库根 `.shopifyignore`）的 git tree oid | 同上 | **QA 验的对象 = release 推的对象**。没有它，「已验证」与「实际推送」之间没有稳定标识 |
| `ChangeSetScopeFingerprint` | 只覆盖本 ChangeSet **声明路径**的 tree oid + 删除项 `absent` 行的 SHA-256，形态是 `<ScopeTreeOid> <ScopeDigest>` 两段 | 同上 | 它是 ChangeSet 的**身份**，不受同树其它块落盘影响 → 这是同树并行 Implement 的全部依据。单比 `ScopeTreeOid` 会漏掉删除（删除只体现在 `ScopeDigest`），所以两段必须一起逐字比 |

`BaseHeadSha` **不再是失配判据**（详见 §2.5），但**仍然必填、且必须是可解析的 commit-ish**。

三个字段一起构成身份：`ThemeTreeOid` 单独不够（表达不了声明范围），`ChangeSetScopeFingerprint` 单独不够（表达不了整树），`ObjectFormat` 不比就会跨仓库误判。

### 2.2 不要求 commit —— 这是全案的关键

实现 skill 交工件的那一刻，改动通常还在工作树里。这正是临时索引存在的理由：`git add` 到一个 `GIT_INDEX_FILE` 指向 scratch 的**空白**索引里，把工作树当前状态（含未跟踪文件、删除、exec 位、被 gitignore 的文件）固化成一个 tree 对象，**用户的 `.git/index` 一个字节都不动，HEAD 不动，没有任何 ref 指向这个 tree**。

正面回答那几个必然会被问到的问题：

| 问题 | 答案 |
|---|---|
| 谁来 commit？ | **没人。矩阵不产生 commit。** |
| commit 到哪个分支？ | 不适用。 |
| 要求干净工作树吗？ | **不要求。** 脏工作树是常态，正是被固化的那个状态。 |
| 提交信息格式？ | 不适用。 |
| 矩阵会变成「必须有写权限的 git 操作者」吗？ | **不会**，但边界要说清，见 §2.3。 |

**「只读取证者」这个姿态仍然成立**，但要害不在「不写对象」，在**oid 是内容的确定性函数**：对象库只是缓存，**校验 = 重算 + 比字符串**，从来不需要去对象库里把对象捞出来。

- **默认模式**：`GIT_OBJECT_DIRECTORY` 指 scratch，`GIT_ALTERNATE_OBJECT_DIRECTORIES` 指仓库的 `objects`（只读）。新对象全落 scratch，算完即删。实测 `.git/objects` 文件数前后不变；把 `.git/objects` 置为只读，默认模式仍能算出指纹。
- **例外是物化**（§2.6）：`git archive` 必须能读到那个 tree 对象，所以 `plaud_stage_verified` 把对象留到 archive 之后再删——仍然只在 scratch 里，仍然不写仓库。
- **`PLAUD_TREE_WRITE_TO_REPO=1`** 是显式 opt-in（把对象写进仓库，之后可 `git cat-file` 查），默认关闭。写进去的是 dangling 对象，等 `git gc` 回收。**不要拿它当持久化手段**——dangling 对象会被 gc 掉。

### 2.3 三条新增的环境前提

1. **可写的临时目录**（`TMPDIR`，取不到时退 `/tmp`）。这是 v0.2.x 不需要的新依赖，`mktemp` 失败即 fail closed。
2. **git ≥ 2.25**（`--pathspec-from-file`）。低于此版本有 `GIT_TOO_OLD` 能力门。
3. **只支持 macOS / Linux 取证。** 这几个函数用了 `set -o pipefail`、POSIX 文件模式与 `git check-attr -z` 的解析约定；同时 Windows 上的典型 git 配置（`core.fileMode` 为假、`core.autocrlf` 为真——具体取值随安装时的选项而定，**不要写成"Windows 默认必然如此"**）会直接命中两道字节保真门。与其给一份行为不同的 PowerShell 实现，不如明说不支持：Windows 环境下取证不可用，对应的 QA / release 检查项填 `Blocked`，理由写「平台不支持 / 字节保真前提不满足」。

### 2.4 `git add` 会执行 hook 与 clean filter

这是取证动作**曾经**能执行仓库里任意脚本的入口（`post-index-change` hook 被触发，实测复现）。现在两条挡法：

- 所有内部 git 调用一律带 `-c core.hooksPath=/dev/null -c core.fsmonitor=false`；
- clean filter 由**字节保真门在 `git add` 执行之前**拦下。

🔴 **因此下游 skill 复制这几个函数时必须逐字原样复制，不得凭记忆敲、不得删注释。** 一个漏掉 `-c core.hooksPath=/dev/null` 的抄本，后果是**执行仓库里的任意脚本**，比 v0.2.x 的「算出一个假指纹」严重一个量级。

### 2.5 生成与校验命令（唯一事实源）

必须在**仓库根目录**执行。producer 与 verifier 必须用一字不差的同一段命令。执行环境是 `bash`（≥3.2）或 `zsh`，**不是任意 `/bin/sh`**——这几段都用了 `set -o pipefail`，`dash` 不支持它、会直接以状态 2 退出；macOS 的 `/bin/sh` 实为 bash 所以看不出问题，**在 Linux 上必须显式 `bash -c`**。

```bash
# BaseHeadSha —— 溯源字段 + diff 基准锚点。**不与当前 HEAD 比对**（期间 commit / rebase /
# checkout 不再让 ChangeSet 失效），但它必须是**可解析的 commit-ish**：§5 的 DeclaredDiffCheck、
# theme check 的 baseline 物化、以及若干条「存量偏差举证」都要 git show <BaseHeadSha>:<file>。
# 缺失或不可解析 → 这些检查填 Blocked，不得填 Advisories，也不得填 N/A。
git rev-parse HEAD

# ==============================================================================
# PLAUD theme matrix v0.3.0 —— 对象绑定的 ChangeSet 指纹
#
# 与 v0.2.x 的根本区别：不再对「工作树状态文本」求 hash，而是让 git 把当前**可发布
# 内容**写成不可变的 tree 对象，用它的 oid 作身份。不 commit、不动 HEAD / ref / 用户
# index / 工作树；默认连 .git/objects 都不写（对象进 scratch，用 alternates 读仓库）。
#
# 🔴 本节全部守卫遵守一条判据：**这一段失败了，外层真的会知道吗？**
#    禁止 `|| var=""`（把「检测失败」改写成「没命中」）、禁止在判定路径上用 head / grep -q
#    之类提前退出的消费者（pipefail 下让上游吃 SIGPIPE）、禁止把 grep 的状态 2 当成
#    「零命中」、禁止把 `git config` 的查询失败或空值默认成安全值。
# ==============================================================================
# ---- 内部：可发布目录清单（唯一事实源） --------------------------------------
# 🔴 Shopify 新增顶层可发布目录时**只改这一处**，并重跑本节自检。清单散在多处 =
#    新目录被静默漏收，指纹看着正常却绑不住新上线的内容。
_plaud_pub_dirs() {
  set --
  for _d in assets blocks config layout locales sections snippets templates; do
    [ -d "$_d" ] && set -- "$@" "$_d"
  done
  [ "$#" -gt 0 ] || return 1
  printf '%s\n' "$@"
}

# ---- 内部：仓库根守卫 --------------------------------------------------------
_plaud_at_root() {
  _top=$(git rev-parse --show-toplevel 2>/dev/null)  || return 1
  [ -n "$_top" ]                                     || return 1
  # printf + ASCII 分隔：变量紧贴多字节字符时某些 bash 会截断输出
  [ "$(cd "$_top" && pwd -P)" = "$(pwd -P)" ] || {
    printf 'NOT_REPO_ROOT: must run at repo root. cwd=%s toplevel=%s\n' "$(pwd -P)" "$_top" >&2
    return 1; }
  return 0
}

# ---- 内部：git 能力门（--pathspec-from-file 需要 >= 2.25） --------------------
_plaud_git_capable() {
  _gv=$(git --version 2>/dev/null | sed -n 's/^git version \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')
  [ -n "$_gv" ] || { printf 'GIT_VERSION_UNKNOWN\n' >&2; return 1; }
  _maj=${_gv% *}; _min=${_gv#* }
  [ "$_maj" -gt 2 ] && return 0
  [ "$_maj" -eq 2 ] && [ "$_min" -ge 25 ] && return 0
  printf 'GIT_TOO_OLD: 需要 git >= 2.25（--pathspec-from-file），当前 %s.%s\n' "$_maj" "$_min" >&2
  return 1
}

# ---- 内部：安全计数（grep 状态 2 = 出错，绝不当成零命中） ----------------------
_plaud_count() {
  _c=$(grep -c -- "$1" "$2"); _rc=$?
  if [ "$_rc" -eq 0 ] || [ "$_rc" -eq 1 ]; then
    [ -n "$_c" ] || return 1
    printf '%s' "$_c"; return 0
  fi
  printf 'GREP_FAILED(rc=%s) on %s\n' "$_rc" "$2" >&2
  return 1
}

# ---- 内部：读 git config 原始值，区分「未设置」/「设置成空」/「查询失败」 ---------
# 打印 `UNSET` 或 `SET:<规整为小写的值>`；查询失败返回 1。**只给 core.autocrlf 用。**
# 🔴 三态是必须的，不能只返回值字符串（v0.3.0 落地实测补）：
#    `[core]` 段下写一个**没有等号的裸键**（`autocrlf`）时，git 语义上把它当 **true**，
#    而 `git config --get core.autocrlf` 打印**空串并返回 0**。把空串当成「未设置」就是
#    fail open —— 实测：裸 `core.autocrlf` 下 CRLF 文件进 tree 时真的被转成 LF
#    （工作树 `a\r\nb\r\n`，blob `a\nb\n`），而设计原型照样算出正常指纹。
# 🔴 `--type=bool` **不能**用在 core.autocrlf 上：合法取值 `input` 会 `fatal: bad boolean
#    config value`（rc=128），把一个真实存在的危险配置变成「查询失败」。
# 🔴 `LC_ALL=C tr`：土耳其语 locale 下 `I` 的小写是 `ı`，不锁 locale 会让 `INPUT`
#    规整成 `ınput` 而落进「取值不认识」分支（方向仍安全，但报错文案会误导）。
_plaud_cfg_raw() {
  _v=$(git config --get "$1" 2>/dev/null); _rc=$?
  if [ "$_rc" -eq 0 ]; then
    printf 'SET:'; printf '%s' "$_v" | LC_ALL=C tr '[:upper:]' '[:lower:]'; return 0
  fi
  [ "$_rc" -eq 1 ] && { printf 'UNSET'; return 0; }
  printf 'GIT_CONFIG_QUERY_FAILED: %s (rc=%s)\n' "$1" "$_rc" >&2
  return 1
}

# ---- 内部：读 git config 的**布尔归一值**（只给 core.fileMode 用） --------------
# 打印 `UNSET` / `true` / `false`；查询失败或值非布尔返回 1。
# 🔴 为什么这里必须用 `--type=bool` 而不能复用 _plaud_cfg_raw（Codex 评审实测，我复现）：
#    `core.fileMode` 的**裸键**归一为 **true**，而 `core.fileMode=`（有等号、值为空）归一为
#    **false**。两者在 `--get` 下都是「空串 + rc=0」，raw 三态区分不了。
#    实测：`git -c core.fileMode= add` 把 0755 的文件记成 100644，`-c core.fileMode=true`
#    记成 100755 —— 把空值当成 true 放行就是 fail open。
_plaud_cfg_bool() {
  _v=$(git config --type=bool --get "$1" 2>/dev/null); _rc=$?
  if [ "$_rc" -eq 0 ]; then
    [ "$_v" = "true" ] || [ "$_v" = "false" ] || {
      printf 'GIT_CONFIG_BOOL_UNEXPECTED: %s=%s\n' "$1" "$_v" >&2; return 1; }
    printf '%s' "$_v"; return 0
  fi
  [ "$_rc" -eq 1 ] && { printf 'UNSET'; return 0; }
  printf 'GIT_CONFIG_BOOL_FAILED: %s (rc=%s) —— 取值非布尔或查询失败\n' "$1" "$_rc" >&2
  return 1
}

# ---- 内部：隔离对象库执行 git ------------------------------------------------
# 🔴 -c core.hooksPath=/dev/null：`git add` 会触发 post-index-change hook（实测复现）。
#    取证动作绝不能执行仓库里的任意脚本 —— 既是副作用，也是投毒入口。
#    clean filter 是同族入口，由字节保真门在 add **之前**拦下。
_plaud_git_iso() {
  if [ "${PLAUD_TREE_WRITE_TO_REPO:-0}" = "1" ]; then
    git -c core.hooksPath=/dev/null -c core.fsmonitor=false "$@"
  else
    GIT_OBJECT_DIRECTORY="${_PLAUD_OBJDIR:-}" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="${_PLAUD_REALOBJ:-}" \
    git -c core.hooksPath=/dev/null -c core.fsmonitor=false "$@"
  fi
}

_plaud_iso_setup() {
  _PLAUD_REALOBJ=$(cd "$(git rev-parse --git-path objects 2>/dev/null)" 2>/dev/null && pwd -P) || return 1
  [ -n "$_PLAUD_REALOBJ" ]                                                           || return 1
  # 新增环境依赖：必须有可写临时目录。mktemp 失败即 fail closed，不许退回 /tmp 猜路径。
  _PLAUD_OBJDIR=$(mktemp -d "${TMPDIR:-/tmp}/plaud-obj.XXXXXX")                       || return 1
  [ -n "$_PLAUD_OBJDIR" ] && [ -d "$_PLAUD_OBJDIR" ]                                  || return 1
  return 0
}

# ---- 内部：字节保真门 --------------------------------------------------------
# tree 记的是 blob 字节，Shopify push 推的是工作树字节。任何让两者不等的机制都必须
# fail closed。参数 = 待判路径集合（可发布面 + 声明范围里的仓外路径）。
# 🔴 判的是**每条路径的生效属性**（git check-attr），不是"扫 .gitattributes 文件"：
#    后者会漏掉被 gitignore 的 .gitattributes、漏掉 .git/info/attributes 与
#    core.attributesFile，也会因为 filter 只作用于非可发布目录而误停机。
_plaud_bytes_gate() {
  _bg_tmp=$(mktemp -d "${TMPDIR:-/tmp}/plaud-bg.XXXXXX")                             || return 1
  # 不加 --exclude-standard：ignored 文件同样会被 push 上线，必须一起判
  _plaud_git_iso ls-files --cached --others -z -- "$@" > "$_bg_tmp/paths" || {
    printf 'ATTR_ENUM_FAILED: 无法枚举待判路径\n' >&2; rm -rf "$_bg_tmp"; return 1; }
  if [ ! -s "$_bg_tmp/paths" ]; then rm -rf "$_bg_tmp"; return 0; fi
  # 🔴 路径含换行 → fail closed，理由是**工具能力**：check-attr -z 的输出要按 NUL 切
  #    三元组，而 macOS 自带 awk 不支持 RS="\0"（实测只读到一条记录），tr '\0' '\n'
  #    又会把含换行的路径拆行、让三元组整体错位。探测必须是"NUL 流里一个 \n 都不许有"
  #    —— 用 sed '/^$/d' + wc -l 会漏掉**以 LF 结尾**的文件名。
  _nl_cnt=$(tr -cd '\n' < "$_bg_tmp/paths" | wc -c | tr -d ' ')                       || { rm -rf "$_bg_tmp"; return 1; }
  [ -n "$_nl_cnt" ]                                                                   || { rm -rf "$_bg_tmp"; return 1; }
  [ "$_nl_cnt" = "0" ] || {
    printf 'NEWLINE_IN_PATH: 待判路径里含换行，属性门无法可靠判定，先重命名\n' >&2
    rm -rf "$_bg_tmp"; return 1; }
  _plaud_git_iso check-attr -z --stdin \
      filter text eol crlf ident working-tree-encoding export-ignore export-subst \
      < "$_bg_tmp/paths" > "$_bg_tmp/attrs" || {
    printf 'ATTR_CHECK_FAILED: git check-attr 失败，无法判定字节保真\n' >&2
    rm -rf "$_bg_tmp"; return 1; }
  tr '\0' '\n' < "$_bg_tmp/attrs" > "$_bg_tmp/lines"                                  || { rm -rf "$_bg_tmp"; return 1; }
  awk 'NR%3==1{p=$0} NR%3==2{a=$0} NR%3==0{v=$0; if (v!="unspecified" && v!="unset") print a"="v" @ "p}' \
      "$_bg_tmp/lines" > "$_bg_tmp/hits"                                              || { rm -rf "$_bg_tmp"; return 1; }
  _nhit=$(_plaud_count . "$_bg_tmp/hits")                                             || { rm -rf "$_bg_tmp"; return 1; }
  if [ "$_nhit" != "0" ]; then
    printf 'BYTE_FIDELITY_ATTR: %s 条路径带有会改写字节或改写归档集合的属性（filter/text/eol/crlf/ident/working-tree-encoding/export-ignore/export-subst）。前 20 条：\n' "$_nhit" >&2
    head -20 "$_bg_tmp/hits" | sed 's/^/  /' >&2     # 只用于诊断，判定已由计数完成
    rm -rf "$_bg_tmp"; return 1
  fi
  rm -rf "$_bg_tmp"
  # core.autocrlf —— 全仓生效，不经 attributes。git 接受 INPUT / TRUE 等大小写变体，
  # 也接受**裸键**（等价于 true）。裸键在 --get 下是「空串 + rc=0」，故必须靠 SET:/UNSET 区分。
  _crlf=$(_plaud_cfg_raw core.autocrlf)                                               || return 1
  case "$_crlf" in
    UNSET|SET:false|SET:no|SET:off|SET:0) : ;;
    SET:true|SET:yes|SET:on|SET:1|SET:input)
      printf 'BYTE_FIDELITY_AUTOCRLF: core.autocrlf=%s 会转换换行\n' "${_crlf#SET:}" >&2; return 1 ;;
    SET:)
      printf 'BYTE_FIDELITY_AUTOCRLF: core.autocrlf 是裸键（git 视为 true），会转换换行\n' >&2; return 1 ;;
    *) printf 'BYTE_FIDELITY_AUTOCRLF_UNKNOWN: core.autocrlf=%s 取值不认识，fail closed\n' "${_crlf#SET:}" >&2; return 1 ;;
  esac
  # core.fileMode 假值 —— tree 只记 100644/100755，配置为假时 exec 位对 git 隐形。
  # 用布尔归一值判：裸键=true（安全），`fileMode=`（空值）=false（危险），两者 --get 都是空串。
  _fm=$(_plaud_cfg_bool core.fileMode)                                                || return 1
  case "$_fm" in
    UNSET|true) : ;;
    false)
      printf 'CORE_FILEMODE_FALSE: core.fileMode 归一为 false 时 exec 位变化不进 tree oid\n' >&2; return 1 ;;
    *) printf 'CORE_FILEMODE_UNKNOWN: core.fileMode 归一值 =%s，fail closed\n' "$_fm" >&2; return 1 ;;
  esac
  return 0
}

# ---- 内部：对一份 -z 的 ls-tree 输出做 mode 门（symlink / gitlink） -----------
# 🔴 判定必须**先计数**，不许 `grep | head` 这种提前退出的消费者，也不许 `|| var=""`：
#    高基数时 head 关闭管道 → 上游 SIGPIPE → pipefail 下整条失败 → `|| var=""`
#    把"检测失败"改写成"没命中" → fail open。（5,000 个 symlink 可复现。）
_plaud_mode_gate() {
  _mg_ls="$1"; _mg_tag="$2"
  # -z 的 ls-tree 记录之间用 NUL 分隔，记录内部不含换行 —— 除非路径本身含换行。
  # 那样 `tr '\0' '\n'` 会把一条记录拆成两行，mode 前缀匹配整体错位（fail open）。
  _mg_nl=$(tr -cd '\n' < "$_mg_ls" | wc -c | tr -d ' ')                                || return 1
  [ -n "$_mg_nl" ]                                                                    || return 1
  [ "$_mg_nl" = "0" ] || {
    printf 'NEWLINE_IN_PATH_%s: tree 条目里含换行路径，mode 门无法可靠判定\n' "$_mg_tag" >&2
    return 1; }
  tr '\0' '\n' < "$_mg_ls" > "$_mg_ls.lines"                                          || return 1
  _n_gl=$(_plaud_count '^160000 commit ' "$_mg_ls.lines")                             || return 1
  [ "$_n_gl" = "0" ] || {
    printf 'GITLINK_IN_%s: %s 个嵌套 git 仓库条目，其内容不在 tree 里。前 20 条：\n' "$_mg_tag" "$_n_gl" >&2
    grep '^160000 commit ' "$_mg_ls.lines" 2>/dev/null | head -20 | sed 's/^/  /' >&2
    return 1; }
  _n_sl=$(_plaud_count '^120000 blob ' "$_mg_ls.lines")                               || return 1
  [ "$_n_sl" = "0" ] || {
    printf 'SYMLINK_IN_%s: %s 个 symlink。tree 只记链接目标字符串，而 Shopify CLI 解引用上传目标内容 —— 改目标内容指纹不会变。先改成真实文件。前 20 条：\n' "$_mg_tag" "$_n_sl" >&2
    grep '^120000 blob ' "$_mg_ls.lines" 2>/dev/null | head -20 | sed 's/^/  /' >&2
    return 1; }
  return 0
}

# ==============================================================================
# plaud_theme_tree —— 当前**可发布内容**的 tree
# 输出一行： <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest> [<objdir>]
#   第 4 段只在 PLAUD_TREE_KEEP_OBJECTS=1 时出现，供 plaud_stage_verified 精确接手
#   （用 `ls -dt` 去 TMPDIR 里回捞会在并发时拿到、甚至删掉别的进程的对象目录）。
# ==============================================================================
plaud_theme_tree() (
  set -o pipefail
  _plaud_at_root                                                                     || return 1
  _plaud_git_capable                                                                 || return 1
  _dirs=$(_plaud_pub_dirs) || {
    printf 'NO_THEME_DIRS: 当前目录下不存在任何主题可发布目录，这不像主题仓库根\n' >&2
    return 1; }
  set --
  while IFS= read -r _d; do [ -n "$_d" ] && set -- "$@" "$_d"; done <<PLAUD_DIRS
$_dirs
PLAUD_DIRS
  [ "$#" -gt 0 ]                                                                     || return 1
  # .shopifyignore 在仓库根、不在可发布目录里，但它**改变 Shopify CLI 的上传集合**，
  # 必须一起进树（只收可发布目录时，改它指纹一动不动而上传内容变了）。
  [ -f .shopifyignore ] && set -- "$@" .shopifyignore

  _plaud_iso_setup                                                                   || return 1
  _plaud_bytes_gate "$@"                                                             || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  # object format 查询失败**不许回退**：sha1 与 sha256 仓库对同一内容算出的 oid 完全不同
  _fmt=$(git rev-parse --show-object-format 2>/dev/null) || {
    printf 'OBJECT_FORMAT_UNKNOWN: git rev-parse --show-object-format 失败\n' >&2
    rm -rf "$_PLAUD_OBJDIR"; return 1; }
  [ "$_fmt" = "sha1" ] || [ "$_fmt" = "sha256" ] || {
    printf 'OBJECT_FORMAT_UNSUPPORTED: %s\n' "$_fmt" >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; }

  _idx="$_PLAUD_OBJDIR/index"
  # 空白 index 从零构建 → 不受用户 index（git add / git reset）影响，也不受
  # core.ignorecase 下"沿用已有条目大小写"的影响。-f：连被 gitignore 的文件一起收。
  if ! GIT_INDEX_FILE="$_idx" _plaud_git_iso add -A -f -- "$@" 2>"$_PLAUD_OBJDIR/adderr"; then
    printf 'ADD_FAILED: 构建临时索引失败：\n' >&2; cat "$_PLAUD_OBJDIR/adderr" >&2
    rm -rf "$_PLAUD_OBJDIR"; return 1
  fi
  _oid=$(GIT_INDEX_FILE="$_idx" _plaud_git_iso write-tree) || {
    printf 'WRITE_TREE_FAILED\n' >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; }
  case "$_fmt" in
    sha1)   [ ${#_oid} -eq 40 ] || { printf 'OID_LENGTH_MISMATCH: fmt=%s oid=%s\n' "$_fmt" "$_oid" >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; } ;;
    sha256) [ ${#_oid} -eq 64 ] || { printf 'OID_LENGTH_MISMATCH: fmt=%s oid=%s\n' "$_fmt" "$_oid" >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; } ;;
  esac

  _plaud_git_iso ls-tree -r -t --full-tree -z "$_oid" > "$_PLAUD_OBJDIR/ls" || {
    printf 'LS_TREE_FAILED\n' >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; }
  # "可发布面全空"必须停机；.shopifyignore 不算主题文件，不能让它把这道门顶开
  tr '\0' '\n' < "$_PLAUD_OBJDIR/ls" | grep '	' > "$_PLAUD_OBJDIR/lsl" 2>/dev/null
  _nblob=$(_plaud_count '^100[67][0-9][0-9] blob ' "$_PLAUD_OBJDIR/lsl")               || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  _nign=0
  if [ -f .shopifyignore ]; then _nign=1; fi
  [ "$_nblob" -gt "$_nign" ] || {
    printf 'EMPTY_THEME_TREE: 可发布目录下一个主题文件都没有\n' >&2
    rm -rf "$_PLAUD_OBJDIR"; return 1; }
  _plaud_mode_gate "$_PLAUD_OBJDIR/ls" "THEME_TREE"                                   || { rm -rf "$_PLAUD_OBJDIR"; return 1; }

  _dig=$(shasum -a 256 < "$_PLAUD_OBJDIR/ls" | cut -d' ' -f1)                          || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  [ -n "$_dig" ]                                                                      || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  if [ "${PLAUD_TREE_KEEP_OBJECTS:-0}" = "1" ]; then
    printf '%s %s %s %s\n' "$_fmt" "$_oid" "$_dig" "$_PLAUD_OBJDIR"
  else
    rm -rf "$_PLAUD_OBJDIR"
    printf '%s %s %s\n' "$_fmt" "$_oid" "$_dig"
  fi
)

# ==============================================================================
# plaud_changeset_scope <pathlist-file>
#   pathlist-file：本 ChangeSet 声明的路径清单（= §4 ModifiedFiles），**每行一条
#   逐字路径**，不 trim、不做 glob（内部加 `:(literal)` 前缀），可含可发布面之外
#   的路径（build 源等）。
# 输出一行： <ObjectFormat> <ScopeTreeOid> <ScopeDigest>
#   身份需要后两段一起看：删除只体现在 ScopeDigest 的 `absent` 行，单比 ScopeTreeOid 会漏。
# ==============================================================================
plaud_changeset_scope() (
  set -o pipefail
  _list="$1"
  [ -n "$_list" ] && [ -f "$_list" ] || { printf 'SCOPE_LIST_MISSING\n' >&2; return 1; }
  _plaud_at_root                                                                     || return 1
  _plaud_git_capable                                                                 || return 1
  # 清单里含 NUL → fail closed（bash 的 read 在 NUL 处截断，zsh 行为又不同）
  _nul=$(tr -cd '\0' < "$_list" | wc -c | tr -d ' ')                                  || return 1
  [ -n "$_nul" ] || return 1
  [ "$_nul" = "0" ] || { printf 'SCOPE_LIST_HAS_NUL\n' >&2; return 1; }
  # 🔴 声明路径含双引号 → fail closed。§4 的 ModifiedFiles 用 `- "<逐字路径>": <说明>`
  #    形态承载机器可解析的路径集合，路径里出现 `"` 会让那层引用无法逐字还原。
  _q=$(tr -cd '"' < "$_list" | wc -c | tr -d ' ')                                     || return 1
  [ -n "$_q" ] || return 1
  [ "$_q" = "0" ] || { printf 'SCOPE_LIST_HAS_QUOTE: 声明路径含双引号，先重命名\n' >&2; return 1; }
  _dirs=$(_plaud_pub_dirs) || { printf 'NO_THEME_DIRS\n' >&2; return 1; }

  _plaud_iso_setup                                                                   || return 1
  _T="$_PLAUD_OBJDIR"
  # 🔴 **不 trim**：`sed 's/[[:space:]]*$//'` 会把真实存在的 `assets/a.css ` 剥成
  #    `assets/a.css`，声明因此指错文件、改真实文件指纹不变。
  sed '/^$/d' "$_list" | LC_ALL=C sort -u > "$_T/declared"                            || { rm -rf "$_T"; return 1; }
  _n=$(_plaud_count . "$_T/declared")                                                 || { rm -rf "$_T"; return 1; }
  [ "$_n" -gt 0 ] || { printf 'SCOPE_LIST_EMPTY\n' >&2; rm -rf "$_T"; return 1; }

  # 🔴 字节保真门必须覆盖**可发布面 + 声明范围**：只传可发布目录时，声明的 build 源
  #    （src/…）上挂的 clean filter 检查不到，改内容 ScopeFingerprint 完全不变，
  #    而且 git add 还会真的去执行那个 filter。
  set --
  while IFS= read -r _d; do [ -n "$_d" ] && set -- "$@" "$_d"; done <<PLAUD_DIRS2
$_dirs
PLAUD_DIRS2
  [ -f .shopifyignore ] && set -- "$@" .shopifyignore
  while IFS= read -r _p; do [ -n "$_p" ] && set -- "$@" "$_p"; done < "$_T/declared"
  _plaud_bytes_gate "$@"                                                             || { rm -rf "$_T"; return 1; }

  _fmt=$(git rev-parse --show-object-format 2>/dev/null) || {
    printf 'OBJECT_FORMAT_UNKNOWN\n' >&2; rm -rf "$_T"; return 1; }
  [ "$_fmt" = "sha1" ] || [ "$_fmt" = "sha256" ] || {
    printf 'OBJECT_FORMAT_UNSUPPORTED: %s\n' "$_fmt" >&2; rm -rf "$_T"; return 1; }

  : > "$_T/exists"; : > "$_T/absentp"; _dirbad=""
  while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    if [ -d "$_p" ] && [ ! -L "$_p" ]; then _dirbad="$_dirbad$_p
"; continue; fi
    if [ -e "$_p" ] || [ -L "$_p" ]; then printf '%s\n' "$_p" >> "$_T/exists" || { rm -rf "$_T"; return 1; }
    else printf '%s\n' "$_p" >> "$_T/absentp" || { rm -rf "$_T"; return 1; }; fi
  done < "$_T/declared"
  [ -z "$_dirbad" ] || {
    printf 'DECLARED_DIRECTORY: 声明清单里出现目录，ModifiedFiles 必须逐个文件：\n%s' "$_dirbad" >&2
    rm -rf "$_T"; return 1; }
  LC_ALL=C sort -u "$_T/exists" -o "$_T/exists"                                       || { rm -rf "$_T"; return 1; }

  _idx="$_T/index"
  _ne=$(_plaud_count . "$_T/exists")                                                  || { rm -rf "$_T"; return 1; }
  if [ "$_ne" -gt 0 ]; then
    # :(literal) —— 不加的话 `assets/g[1].css` 会被当 glob 去吸收 `assets/g1.css`
    sed 's/^/:(literal)/' "$_T/exists" > "$_T/pathspec"                               || { rm -rf "$_T"; return 1; }
    # add 失败不许吞：吞掉 "did not match any files" 时，一条路径不存在就让整个索引
    # 为空、算出**空树** oid 却照样返回 0
    if ! GIT_INDEX_FILE="$_idx" _plaud_git_iso add -A -f --pathspec-from-file="$_T/pathspec" \
         2>"$_T/adderr"; then
      printf 'SCOPE_ADD_FAILED:\n' >&2; cat "$_T/adderr" >&2; rm -rf "$_T"; return 1
    fi
    _oid=$(GIT_INDEX_FILE="$_idx" _plaud_git_iso write-tree) || {
      printf 'SCOPE_WRITE_TREE_FAILED\n' >&2; rm -rf "$_T"; return 1; }
    [ -n "$_oid" ] || { rm -rf "$_T"; return 1; }
    _plaud_git_iso ls-tree -r --full-tree -z "$_oid" > "$_T/ls" || {
      printf 'SCOPE_LS_TREE_FAILED\n' >&2; rm -rf "$_T"; return 1; }
  else
    _oid=$(_plaud_git_iso hash-object -t tree /dev/null) || { rm -rf "$_T"; return 1; }
    [ -n "$_oid" ] || { rm -rf "$_T"; return 1; }
    : > "$_T/ls"
  fi
  _plaud_mode_gate "$_T/ls" "SCOPE_TREE"                                              || { rm -rf "$_T"; return 1; }

  # 收全性核对：tree 条目集合必须与 exists 清单**完全相等**（多或少都 fail closed）。
  # cut -f2- 只切第一个 TAB —— `sed 's/^.*\t//'` 贪婪，路径含 TAB 时会削错。
  tr '\0' '\n' < "$_T/ls" | sed '/^$/d' | cut -f2- | LC_ALL=C sort -u > "$_T/present" \
    || { rm -rf "$_T"; return 1; }
  if ! LC_ALL=C diff "$_T/exists" "$_T/present" > "$_T/setdiff" 2>&1; then
    printf 'SCOPE_SET_MISMATCH: 声明存在的路径与 tree 条目不一致：\n' >&2
    head -40 "$_T/setdiff" >&2; rm -rf "$_T"; return 1
  fi

  sed 's/^/absent /' "$_T/absentp" > "$_T/absent"                                     || { rm -rf "$_T"; return 1; }
  cat "$_T/ls" "$_T/absent" > "$_T/payload"                                           || { rm -rf "$_T"; return 1; }
  _dig=$(shasum -a 256 < "$_T/payload" | cut -d' ' -f1)                                || { rm -rf "$_T"; return 1; }
  [ -n "$_dig" ]                                                                      || { rm -rf "$_T"; return 1; }
  rm -rf "$_T"
  printf '%s %s %s\n' "$_fmt" "$_oid" "$_dig"
)

# ---- 内部：在一棵**普通目录**里重算 tree oid（回环复算 / 推站前复核共用） --------
# 一次性 bare 仓库 + 独立 index，绝不碰源仓库。
# 🔴 必须屏蔽 global / system config 与 core.attributesFile：否则用户机器上的
#    `core.autocrlf` / `core.fileMode` / 全局 attributes 会让"复算"用一套与被验证时
#    不同的规则去读同一批字节，算出一个不等的 oid（假失配），或反过来抹平真差异。
_plaud_recompute_dir() {
  _rd="$1"; _rfmt="$2"; shift 2
  [ "$#" -gt 0 ] || set -- .
  [ -n "$_rd" ] && [ -d "$_rd" ]                     || { printf 'RECOMPUTE_DIR_MISSING\n' >&2; return 1; }
  [ "$_rfmt" = "sha1" ] || [ "$_rfmt" = "sha256" ]   || { printf 'RECOMPUTE_FMT_BAD: %s\n' "$_rfmt" >&2; return 1; }
  _rg=$(mktemp -d "${TMPDIR:-/tmp}/plaud-vg.XXXXXX")                                 || return 1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_DIR="$_rg/g" \
    git -c core.hooksPath=/dev/null init -q --object-format="$_rfmt" --bare >/dev/null 2>&1 || {
    printf 'RECOMPUTE_INIT_FAILED\n' >&2; rm -rf "$_rg"; return 1; }
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  GIT_DIR="$_rg/g" GIT_WORK_TREE="$_rd" GIT_INDEX_FILE="$_rg/idx" \
    git -c core.hooksPath=/dev/null -c core.fsmonitor=false -c core.fileMode=true \
        -c core.autocrlf=false -c core.attributesFile=/dev/null \
        add -A -f -- "$@" 2>/dev/null || {
    printf 'RECOMPUTE_ADD_FAILED\n' >&2; rm -rf "$_rg"; return 1; }
  _roid2=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
           GIT_DIR="$_rg/g" GIT_INDEX_FILE="$_rg/idx" git write-tree)                 || { rm -rf "$_rg"; return 1; }
  rm -rf "$_rg"
  [ -n "$_roid2" ] || return 1
  printf '%s' "$_roid2"
}

# ==============================================================================
# plaud_stage_verified <目标空目录>
#   一步做完：算当前 ThemeTreeOid → 把**同一个 tree** 物化成独立目录 → **回环复算**。
#   QA 与 release 都从这棵目录跑/推，不得从活工作树跑/推：重算相等之后、消费者逐文件
#   读取期间工作树还能再变（TOCTOU），推上去的会是一个从没被验过的混合状态。
#   输出一行： <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>
#
#   🔴 回环复算不是锦上添花，是这道门唯一可信的部分：`git archive` 会应用
#      export-ignore / export-subst，`tar.umask` 还能改掉 exec 位 —— 光"算完再解开"
#      不保证物化结果等于被验证的那个 tree。所以物化之后必须在目标目录里**重新算一次**，
#      与被验证的 oid 逐字相等才算成立。
# ==============================================================================
plaud_stage_verified() (
  set -o pipefail
  _dst="$1"
  [ -n "$_dst" ] && [ -d "$_dst" ]                     || { printf 'STAGE_DST_MISSING\n' >&2; return 1; }
  [ -z "$(ls -A "$_dst" 2>/dev/null)" ]                || { printf 'STAGE_DST_NOT_EMPTY\n' >&2; return 1; }
  _plaud_at_root                                                                     || return 1
  _dstp=$(cd "$_dst" && pwd -P)                        || return 1
  _rootp=$(pwd -P)
  case "$_dstp/" in "$_rootp"/*) printf 'STAGE_DST_INSIDE_REPO: 物化目录不得在仓库内\n' >&2; return 1 ;; esac

  _v=$(PLAUD_TREE_KEEP_OBJECTS=1 plaud_theme_tree)     || return 1
  [ -n "$_v" ]                                         || return 1
  _fmt=$(printf '%s' "$_v" | cut -d' ' -f1)
  _oid=$(printf '%s' "$_v" | cut -d' ' -f2)
  _dig=$(printf '%s' "$_v" | cut -d' ' -f3)
  _od=$(printf '%s' "$_v" | cut -d' ' -f4)             # 精确接手，不用 ls -dt 猜
  [ -n "$_oid" ] && [ -n "$_od" ] && [ -d "$_od" ]     || { printf 'STAGE_OBJDIR_LOST\n' >&2; return 1; }
  _realobj=$(cd "$(git rev-parse --git-path objects)" && pwd -P)                     || { rm -rf "$_od"; return 1; }

  GIT_OBJECT_DIRECTORY="$_od" GIT_ALTERNATE_OBJECT_DIRECTORIES="$_realobj" \
    git -c core.hooksPath=/dev/null -c tar.umask=0022 archive --format=tar "$_oid" > "$_od/t.tar" || {
      printf 'STAGE_ARCHIVE_FAILED\n' >&2; rm -rf "$_od"; return 1; }
  tar -xf "$_od/t.tar" -C "$_dst" || { printf 'STAGE_EXTRACT_FAILED\n' >&2; rm -rf "$_od"; return 1; }
  rm -rf "$_od"

  # 回环复算：在物化目录里建一个**一次性**仓库（object format 与源一致），重算 tree oid，
  # 必须与被验证的 oid 逐字相等。
  _roid=$(_plaud_recompute_dir "$_dstp" "$_fmt")                                     || return 1
  [ "$_roid" = "$_oid" ] || {
    printf 'STAGE_ROUNDTRIP_MISMATCH: 物化结果 %s != 已验证 %s（export-ignore / export-subst / tar.umask 等改写了归档）\n' "$_roid" "$_oid" >&2
    return 1; }
  printf '%s %s %s\n' "$_fmt" "$_oid" "$_dig"
)

# ---- 内部：从一个**已解析成完整 oid 的 commit** 重建可发布子树 -----------------
# 在**调用方已经建好**的 scratch 对象库（_plaud_iso_setup）里建树，只打印 <BaseTreeOid>。
# 🔴 base 树完全来自**已提交对象**：不读工作树、不跑 `git add`、不触发 hook / clean filter，
#    所以这里**不跑字节保真门** —— 那道门判的是「工作树字节 vs blob 字节」，此处没有工作树
#    字节参与。跳过它不是 fail open。
# 🔴 可发布目录在这里**必须按固定清单从 base commit 枚举**，不能用 _plaud_pub_dirs：后者看的
#    是**当前工作树**有哪些目录，会让「基准」随工作树漂移。清单与 _plaud_pub_dirs 必须一致，
#    新增顶层可发布目录时**两处一起改**。
# 🔴 失败时**不清理** scratch 对象库：清理归调用方（plaud_declared_diff 还要用同一个对象库
#    做 diff，base 对象必须一直可达）。
_plaud_base_tree_build() {
  _bt_commit="$1"
  [ -n "$_bt_commit" ] && [ -n "${_PLAUD_OBJDIR:-}" ]                                 || return 1
  _bt_idx="$_PLAUD_OBJDIR/bidx"
  GIT_INDEX_FILE="$_bt_idx" _plaud_git_iso read-tree --empty                          || return 1
  _bt_nsub=0
  for _bt_d in assets blocks config layout locales sections snippets templates; do
    _bt_sub=$(git rev-parse -q --verify "$_bt_commit:$_bt_d" 2>/dev/null) || continue
    [ -n "$_bt_sub" ] || continue
    GIT_INDEX_FILE="$_bt_idx" _plaud_git_iso read-tree --prefix="$_bt_d/" "$_bt_sub"  || return 1
    _bt_nsub=$((_bt_nsub+1))
  done
  [ "$_bt_nsub" -gt 0 ] || {
    printf 'DIFF_BASE_NO_THEME_DIRS: %s 那一版里没有任何可发布目录\n' "$_bt_commit" >&2
    return 1; }
  # 🔴 mode 必须从 base tree 里读，**不能写死 100644**（Codex 评审实测：`.shopifyignore`
  #    完全可能是 100755，写死会让「无改动」也算出伪 diff，进而把正常交付判成
  #    DECLARED_DIFF_ORPHAN/UNCHANGED）。非普通文件（symlink / gitlink）一律 fail closed。
  _bt_nign=0
  git ls-tree "$_bt_commit" -- .shopifyignore > "$_PLAUD_OBJDIR/siline" 2>/dev/null || : > "$_PLAUD_OBJDIR/siline"
  if [ -s "$_PLAUD_OBJDIR/siline" ]; then
    _bt_simode=$(cut -d' ' -f1 < "$_PLAUD_OBJDIR/siline")
    _bt_sitype=$(cut -d' ' -f2 < "$_PLAUD_OBJDIR/siline")
    _bt_si=$(cut -d' ' -f3 < "$_PLAUD_OBJDIR/siline" | cut -f1)
    [ "$_bt_sitype" = "blob" ] && { [ "$_bt_simode" = "100644" ] || [ "$_bt_simode" = "100755" ]; } || {
      printf 'DIFF_BASE_SHOPIFYIGNORE_MODE: 基准里的 .shopifyignore 不是普通文件（mode=%s type=%s）\n' \
        "$_bt_simode" "$_bt_sitype" >&2; return 1; }
    [ -n "$_bt_si" ] || return 1
    GIT_INDEX_FILE="$_bt_idx" _plaud_git_iso update-index --add \
      --cacheinfo "$_bt_simode,$_bt_si,.shopifyignore"                                || return 1
    _bt_nign=1
  fi
  _bt_boid=$(GIT_INDEX_FILE="$_bt_idx" _plaud_git_iso write-tree)                     || return 1
  [ -n "$_bt_boid" ]                                                                  || return 1
  _plaud_git_iso ls-tree -r -t --full-tree -z "$_bt_boid" > "$_PLAUD_OBJDIR/bls"      || return 1
  _plaud_mode_gate "$_PLAUD_OBJDIR/bls" "DIFF_BASE"                                   || return 1
  # 与 plaud_theme_tree / plaud_declared_diff 的 after 侧**同口径**的空主题检查：少了它，
  # 两支函数会对同一棵基准树给出相反结论（Codex 复核指出）。
  tr '\0' '\n' < "$_PLAUD_OBJDIR/bls" | grep '	' > "$_PLAUD_OBJDIR/blsl" 2>/dev/null
  _bt_nblob=$(_plaud_count '^100[67][0-9][0-9] blob ' "$_PLAUD_OBJDIR/blsl")          || return 1
  [ "$_bt_nblob" -gt "$_bt_nign" ] || {
    printf 'EMPTY_BASE_THEME_TREE: %s 那一版的可发布目录下一个主题文件都没有\n' "$_bt_commit" >&2
    return 1; }
  printf '%s\n' "$_bt_boid"
}

# ==============================================================================
# plaud_base_theme_tree <commit-ish>
#   把**某个 commit 的可发布子树**重建出来。输出一行： <ObjectFormat> <BaseTreeOid>
#   用在 §9.1 的 IntegrationPlan.IntegrationBaseTreeOid（也可用于任何需要「某个 commit
#   那一版的可发布树 oid」的场合）。
#
#   🔴 **绝不要用 `plaud_theme_tree "<commit>"` 代替它**（v0.3.0 收尾验收补）：
#      plaud_theme_tree 是**无参函数**，函数体里根本没有 $1 —— 传进去的 commit 被静默丢弃，
#      返回的是**当前工作树**的 oid，却被命名成「基准树 oid」。两侧都"算得出值"，而 §5 的
#      三方等式（IntegrationPlan.IntegrationBaseTreeOid == IntegrationOf.BaseTreeOid ==
#      DiffBaseTreeOid）会恒不成立 → DeclaredDiffCheck 恒 Blocked → 多块集成结构性死锁。
#   🔴 也不要退到 `git rev-parse <commit>^{tree}`：那是**仓库根树**，不是可发布子树。
#   本函数与 plaud_declared_diff 的 base 半段**共用同一支内部实现**（_plaud_base_tree_build），
#   两者必然同口径 —— 两份拷贝必然漂移，而漂移的表现正好是「等式恒不成立」。
# ==============================================================================
plaud_base_theme_tree() (
  set -o pipefail
  [ "$#" -eq 1 ] && [ -n "$1" ] || {
    printf 'BASE_COMMIT_MISSING: 需要恰好一个 commit-ish 参数\n' >&2; return 1; }
  _bc="$1"
  _plaud_at_root                                                                      || return 1
  _plaud_git_capable                                                                  || return 1
  # 🔴 先一次性解析成完整 commit oid，之后只用解析结果：直接把分支名 / HEAD 一路传下去时，
  #    同一次运行里 ref 可能被别的进程移动，基准就不是同一个了。
  _bcoid=$(git rev-parse -q --verify "$_bc^{commit}" 2>/dev/null) || {
    printf 'DIFF_BASE_UNREACHABLE: %s 在本仓库里不可达或不是 commit（浅克隆 / 已被 gc / 写错 / 传了 tree 或 blob）——\n' "$_bc" >&2
    printf '  这不是可以降级放行的情形：没有基准就无法证明「树里只有已声明、已归属的改动」\n' >&2
    return 1; }
  [ -n "$_bcoid" ]                                                                    || return 1
  _fmt=$(git rev-parse --show-object-format 2>/dev/null) || {
    printf 'OBJECT_FORMAT_UNKNOWN\n' >&2; return 1; }
  [ "$_fmt" = "sha1" ] || [ "$_fmt" = "sha256" ] || {
    printf 'OBJECT_FORMAT_UNSUPPORTED: %s\n' "$_fmt" >&2; return 1; }
  _plaud_iso_setup                                                                    || return 1
  _boid=$(_plaud_base_tree_build "$_bcoid")                                           || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  [ -n "$_boid" ]                                                                     || { rm -rf "$_PLAUD_OBJDIR"; return 1; }
  case "$_fmt" in
    sha1)   [ ${#_boid} -eq 40 ] || { printf 'OID_LENGTH_MISMATCH: fmt=%s oid=%s\n' "$_fmt" "$_boid" >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; } ;;
    sha256) [ ${#_boid} -eq 64 ] || { printf 'OID_LENGTH_MISMATCH: fmt=%s oid=%s\n' "$_fmt" "$_boid" >&2; rm -rf "$_PLAUD_OBJDIR"; return 1; } ;;
  esac
  rm -rf "$_PLAUD_OBJDIR"
  printf '%s %s\n' "$_fmt" "$_boid"
)

# ==============================================================================
# plaud_declared_diff <base-commit-ish> <pathlist-file>
#   把「本次可发布面到底变了哪些路径」与「本 ChangeSet（或本批集成）声明了哪些路径」
#   做**四元组**比对，回答 §5 的 DeclaredDiffCheck。
#   输出一行： <ObjectFormat> <BaseThemeTreeOid> <ThemeTreeOid> DECLARED_DIFF_OK
#
#   🔴 为什么 base 取的是**commit**而不是「开工前算的那个 oid」（Codex 评审逼出来的）：
#      默认模式下 plaud_theme_tree 算完就删 scratch 对象库，那个 oid **不是可达对象**，
#      事后 `git diff <BASE> <AFTER>` 根本解析不了。用 BaseHeadSha 的可发布子树做 base，
#      对象天然可达、可复算，而且顺带堵上另一个洞：**开工前就已经躺在工作树里的
#      别人的半成品**，在「开工前 oid」做 base 时会被当成基线的一部分而漏掉，
#      在 commit 做 base 时会作为无主改动被抓出来。
#      代价要说清：BaseHeadSha 因此**同时**是溯源字段与 diff 基准，但它**仍然不与
#      当前 HEAD 比对** —— 期间发生 commit / rebase 不再让 ChangeSet 失效。
#
#   🔴 为什么用 `--raw -z --no-renames` 而不是 `--name-status`（Codex 评审）：
#      name-status 只证明路径与状态字母，证明不了 mode 与新旧 blob，还会被 rename
#      推断改写成 R 记录。四元组（path / old mode+blob / new mode+blob）才是可核的。
# ==============================================================================
plaud_declared_diff() (
  set -o pipefail
  _base="$1"; _list="$2"
  [ -n "$_base" ]                    || { printf 'DIFF_BASE_MISSING\n' >&2; return 1; }
  [ -n "$_list" ] && [ -f "$_list" ] || { printf 'SCOPE_LIST_MISSING\n' >&2; return 1; }
  _plaud_at_root                                                                     || return 1
  _plaud_git_capable                                                                 || return 1
  _nul=$(tr -cd '\0' < "$_list" | wc -c | tr -d ' ')                                  || return 1
  [ -n "$_nul" ] && [ "$_nul" = "0" ] || { printf 'SCOPE_LIST_HAS_NUL\n' >&2; return 1; }
  # 🔴 一次性解析成完整 commit oid，之后只用解析结果：同一次运行里分支 / HEAD 可能被别的
  #    进程移动，两次读到不同基准（与 plaud_base_theme_tree 同口径）。
  _bcoid=$(git rev-parse -q --verify "$_base^{commit}" 2>/dev/null) || {
    printf 'DIFF_BASE_UNREACHABLE: %s 在本仓库里不可达或不是 commit（浅克隆 / 已被 gc / 写错）——\n' "$_base" >&2
    printf '  这不是可以降级放行的情形：没有基准就无法证明「树里只有已声明、已归属的改动」\n' >&2
    return 1; }
  [ -n "$_bcoid" ]                                                                    || return 1
  _dirs=$(_plaud_pub_dirs) || { printf 'NO_THEME_DIRS\n' >&2; return 1; }
  _fmt=$(git rev-parse --show-object-format 2>/dev/null) || {
    printf 'OBJECT_FORMAT_UNKNOWN\n' >&2; return 1; }
  [ "$_fmt" = "sha1" ] || [ "$_fmt" = "sha256" ] || {
    printf 'OBJECT_FORMAT_UNSUPPORTED: %s\n' "$_fmt" >&2; return 1; }

  _plaud_iso_setup                                                                   || return 1
  _T="$_PLAUD_OBJDIR"
  set --
  while IFS= read -r _d; do [ -n "$_d" ] && set -- "$@" "$_d"; done <<PLAUD_DIRS3
$_dirs
PLAUD_DIRS3
  [ "$#" -gt 0 ]                                                                     || { rm -rf "$_T"; return 1; }
  [ -f .shopifyignore ] && set -- "$@" .shopifyignore
  _plaud_bytes_gate "$@"                                                             || { rm -rf "$_T"; return 1; }

  # ---- base：BaseHeadSha 的可发布子树（同一 scratch 对象库里现建，两棵树同时可达）
  # 🔴 与 plaud_base_theme_tree **共用同一支内部实现**，不再各写一份：两份拷贝必然漂移，
  #    而漂移的表现正好是 §5 那道三方等式恒不成立。
  _boid=$(_plaud_base_tree_build "$_bcoid")                                           || { rm -rf "$_T"; return 1; }
  [ -n "$_boid" ]                                                                     || { rm -rf "$_T"; return 1; }
  # ---- after：当前工作树的可发布树（与 plaud_theme_tree 同一算法、同一参数）
  _aidx="$_T/aidx"
  if ! GIT_INDEX_FILE="$_aidx" _plaud_git_iso add -A -f -- "$@" 2>"$_T/adderr"; then
    printf 'ADD_FAILED:\n' >&2; cat "$_T/adderr" >&2; rm -rf "$_T"; return 1
  fi
  _aoid=$(GIT_INDEX_FILE="$_aidx" _plaud_git_iso write-tree)                          || { rm -rf "$_T"; return 1; }
  [ -n "$_aoid" ]                                                                     || { rm -rf "$_T"; return 1; }
  _plaud_git_iso ls-tree -r -t --full-tree -z "$_aoid" > "$_T/als"                     || { rm -rf "$_T"; return 1; }
  _plaud_mode_gate "$_T/als" "THEME_TREE"                                             || { rm -rf "$_T"; return 1; }
  # 与 plaud_theme_tree 同口径的空主题检查：少了它，可发布面全空时本函数会回
  # DECLARED_DIFF_OK 而 plaud_theme_tree 报 EMPTY_THEME_TREE，两个函数对同一棵树给出
  # 相反结论（Codex 评审指出）。
  tr '\0' '\n' < "$_T/als" | grep '	' > "$_T/alsl" 2>/dev/null
  _nblob=$(_plaud_count '^100[67][0-9][0-9] blob ' "$_T/alsl")                         || { rm -rf "$_T"; return 1; }
  _nign=0
  if [ -f .shopifyignore ]; then _nign=1; fi
  [ "$_nblob" -gt "$_nign" ] || {
    printf 'EMPTY_THEME_TREE: 可发布目录下一个主题文件都没有\n' >&2
    rm -rf "$_T"; return 1; }

  # ---- 四元组 diff。--no-renames：rename 推断会把「删 A + 增 B」重写成一条 R 记录，
  #      归属核对要的是逐路径事实，不是 git 的猜测。
  _plaud_git_iso diff --raw -z --no-renames "$_boid" "$_aoid" > "$_T/raw"              || {
    printf 'DIFF_RAW_FAILED\n' >&2; rm -rf "$_T"; return 1; }
  tr '\0' '\n' < "$_T/raw" > "$_T/rawl"                                               || { rm -rf "$_T"; return 1; }
  # 记录成对出现（meta 行 + path 行）。行数为奇数 = 解析错位，fail closed。
  _nl=$(_plaud_count . "$_T/rawl")                                                    || { rm -rf "$_T"; return 1; }
  [ $((_nl % 2)) -eq 0 ] || {
    printf 'DIFF_RAW_PARSE_MISALIGNED: %s 行，无法按 meta/path 成对解析\n' "$_nl" >&2
    rm -rf "$_T"; return 1; }
  awk 'NR%2==0{print}' "$_T/rawl" | LC_ALL=C sort -u > "$_T/changed"                  || { rm -rf "$_T"; return 1; }
  awk 'NR%2==1{print}' "$_T/rawl" > "$_T/meta"                                        || { rm -rf "$_T"; return 1; }
  # 每条 meta 必须是 `:<oldmode> <newmode> <oldsha> <newsha> <status>` 形态；不是就说明
  # 解析假设不成立（例如出现了 rename 的三段记录），fail closed 而不是硬猜。
  _nbad=$(_plaud_count '^:[0-7][0-7]* [0-7][0-7]* [0-9a-f][0-9a-f]* [0-9a-f][0-9a-f]* [ACDMTUX]' "$_T/meta") \
    || { rm -rf "$_T"; return 1; }
  _nmeta=$(_plaud_count . "$_T/meta")                                                 || { rm -rf "$_T"; return 1; }
  [ "$_nbad" = "$_nmeta" ] || {
    printf 'DIFF_RAW_UNEXPECTED_RECORD: %s/%s 条 raw 记录不是预期形态\n' \
      "$((_nmeta - _nbad))" "$_nmeta" >&2; rm -rf "$_T"; return 1; }

  # ---- 声明集合里落在**可发布面**的那部分（build 源等仓内其它路径不参与本比对）
  sed '/^$/d' "$_list" | LC_ALL=C sort -u > "$_T/decl"                                || { rm -rf "$_T"; return 1; }
  awk -F/ '$0=="'".shopifyignore"'" || $1=="assets" || $1=="blocks" || $1=="config" || $1=="layout" || $1=="locales" || $1=="sections" || $1=="snippets" || $1=="templates"' \
    "$_T/decl" | LC_ALL=C sort -u > "$_T/declpub"                                     || { rm -rf "$_T"; return 1; }

  if ! LC_ALL=C comm -13 "$_T/declpub" "$_T/changed" > "$_T/orphan" 2>/dev/null; then
    printf 'DIFF_COMPARE_FAILED\n' >&2; rm -rf "$_T"; return 1; fi
  if ! LC_ALL=C comm -23 "$_T/declpub" "$_T/changed" > "$_T/unchanged" 2>/dev/null; then
    printf 'DIFF_COMPARE_FAILED\n' >&2; rm -rf "$_T"; return 1; fi
  _norph=$(_plaud_count . "$_T/orphan")                                               || { rm -rf "$_T"; return 1; }
  _nunch=$(_plaud_count . "$_T/unchanged")                                            || { rm -rf "$_T"; return 1; }
  if [ "$_norph" != "0" ]; then
    printf 'DECLARED_DIFF_ORPHAN: %s 条可发布路径变了但没有任何 ChangeSet 声明它 —— 无主改动不得随整树发版。前 20 条：\n' "$_norph" >&2
    head -20 "$_T/orphan" | sed 's/^/  /' >&2
    rm -rf "$_T"; return 1
  fi
  if [ "$_nunch" != "0" ]; then
    printf 'DECLARED_DIFF_UNCHANGED: %s 条声明为改动的可发布路径相对基准毫无变化 —— 声明不实。前 20 条：\n' "$_nunch" >&2
    head -20 "$_T/unchanged" | sed 's/^/  /' >&2
    rm -rf "$_T"; return 1
  fi
  rm -rf "$_T"
  printf '%s %s %s DECLARED_DIFF_OK\n' "$_fmt" "$_boid" "$_aoid"
)

# ==============================================================================
# plaud_stage_workspace <目标空目录>
#   物化一份**完整工作区快照**（不只是可发布面），供 QA 在里面跑 theme check / build /
#   断点回归 —— 这些检查要读 .theme-check.yml、lockfile、build 源，只有可发布面跑不了。
#   物化后同样**回环复算**：快照里可发布面的 tree oid 必须与被验证的 ThemeTreeOid 逐字相等。
#   输出一行： <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>
#
#   与 plaud_stage_verified 的分工（DESIGN R7 的两层）：
#     - plaud_stage_workspace → §5 的 StageDirRef，**QA 在这里跑**
#     - plaud_stage_verified  → §9.1.4 的 ReleaseStageDir，**只用于推站**（只含可发布面，
#       多一个文件都会被整树 push 发出去）
#   两者的 ThemeTreeOid 必须相同；不同即说明两次取证之间工作树变过，停机。
#
#   🔴 快照是**整棵工作树的拷贝**（除 .git），因此会包含 node_modules 之类的大目录，
#      也会包含 memory/。这不是缺陷：QA 要的就是一个可运行的工作区。想省时间就先清理
#      工作树，不要靠缩小拷贝范围 —— 缩了就跑不了它本来要跑的检查。
# ==============================================================================
plaud_stage_workspace() (
  set -o pipefail
  _dst="$1"
  [ -n "$_dst" ] && [ -d "$_dst" ]                     || { printf 'STAGE_DST_MISSING\n' >&2; return 1; }
  [ -z "$(ls -A "$_dst" 2>/dev/null)" ]                || { printf 'STAGE_DST_NOT_EMPTY\n' >&2; return 1; }
  _plaud_at_root                                                                     || return 1
  _dstp=$(cd "$_dst" && pwd -P)                        || return 1
  _rootp=$(pwd -P)
  case "$_dstp/" in "$_rootp"/*) printf 'STAGE_DST_INSIDE_REPO: 快照目录不得在仓库内\n' >&2; return 1 ;; esac

  _v=$(plaud_theme_tree)                               || return 1
  [ -n "$_v" ]                                         || return 1
  _fmt=$(printf '%s' "$_v" | cut -d' ' -f1)
  _oid=$(printf '%s' "$_v" | cut -d' ' -f2)
  _dig=$(printf '%s' "$_v" | cut -d' ' -f3)
  [ -n "$_fmt" ] && [ -n "$_oid" ] && [ -n "$_dig" ]   || { printf 'STAGE_TREE_LOST\n' >&2; return 1; }

  # 🔴 **不能用 `find … -exec cp …`**：`find` 不把 `-exec` 子命令的失败传播成自己的退出码
  #    （实测 `find /tmp -maxdepth 0 -exec false \;` 返回 0，连 `exit 255` 在 BSD find 的
  #    `\;` 形态下也不传播）。那样一来非发布文件（.theme-check.yml / lockfile / build 源）
  #    拷贝失败时，可发布面的回环复算照样相等、函数照样成功，QA 就在一份**残缺快照**里跑。
  #    改成显式循环 + 逐次判退出码 + 条目数核对。
  _sw=$(mktemp -d "${TMPDIR:-/tmp}/plaud-sw.XXXXXX")                                  || return 1
  find . -maxdepth 1 -mindepth 1 ! -name .git -print0 > "$_sw/top0" || {
    printf 'STAGE_ENUM_FAILED\n' >&2; rm -rf "$_sw"; return 1; }
  _swnl=$(tr -cd '\n' < "$_sw/top0" | wc -c | tr -d ' ')                              || { rm -rf "$_sw"; return 1; }
  [ -n "$_swnl" ] && [ "$_swnl" = "0" ] || {
    printf 'STAGE_NEWLINE_IN_TOPLEVEL: 顶层条目名含换行，逐项拷贝无法可靠进行\n' >&2
    rm -rf "$_sw"; return 1; }
  tr '\0' '\n' < "$_sw/top0" | sed '/^$/d' > "$_sw/top"                              || { rm -rf "$_sw"; return 1; }
  _want=$(_plaud_count . "$_sw/top")                                                  || { rm -rf "$_sw"; return 1; }
  _got=0
  while IFS= read -r _e; do
    [ -n "$_e" ] || continue
    # -P：保留 symlink 不解引用。快照里的 symlink 仍指向外部可变对象，这一点写在契约里，
    #     可发布面的 symlink 早已被 mode 门挡掉，这里只涉及非发布文件。
    cp -RP "$_e" "$_dstp/" || {
      printf 'STAGE_COPY_FAILED: %s\n' "$_e" >&2; rm -rf "$_sw"; return 1; }
    _got=$((_got+1))
  done < "$_sw/top"
  rm -rf "$_sw"
  [ "$_got" = "$_want" ] || {
    printf 'STAGE_COPY_COUNT_MISMATCH: 拷贝 %s 项，枚举到 %s 项\n' "$_got" "$_want" >&2; return 1; }
  [ -e "$_dstp/.git" ] && { printf 'STAGE_GIT_LEAKED: 快照里出现了 .git\n' >&2; return 1; }

  _dirs2=$(cd "$_dstp" && _plaud_pub_dirs) || {
    printf 'STAGE_NO_THEME_DIRS: 快照里没有可发布目录\n' >&2; return 1; }
  set --
  while IFS= read -r _d; do [ -n "$_d" ] && set -- "$@" "$_d"; done <<PLAUD_DIRS4
$_dirs2
PLAUD_DIRS4
  [ "$#" -gt 0 ]                                       || return 1
  [ -f "$_dstp/.shopifyignore" ] && set -- "$@" .shopifyignore
  _roid=$(_plaud_recompute_dir "$_dstp" "$_fmt" "$@")  || return 1
  [ "$_roid" = "$_oid" ] || {
    printf 'STAGE_ROUNDTRIP_MISMATCH: 快照里重算 %s != 已验证 %s\n' "$_roid" "$_oid" >&2
    return 1; }
  printf '%s %s %s\n' "$_fmt" "$_oid" "$_dig"
)
```

```bash
# 🔴 原样抄这两行，**不要只抄第一行**：旧写法只有 `plaud_theme_tree || echo "..."`，
#    它打印了错误串却让整段 **rc=0** —— 任何按 `$?` 分支、或跑在 `set -e` 下的调用方
#    都会认为这道门通过了。判定既要看输出、也要看退出码。
plaud_theme_tree      || { echo "THEME_TREE_FAILED";  exit 1; }
# ModifiedFiles 的逐字路径清单（每行一条），见 §4
plaud_changeset_scope "$PATHLIST" || { echo "SCOPE_FAILED"; exit 1; }
```

**自检**：改一个已跟踪文件的内容（不增删文件），`ThemeTreeOid` 必须变化；还原后必须精确复原。做不到就说明命令在当前环境退化了，停机排查。

### 2.6 两层物化：QA 跑哪里、release 推哪里

**QA 与 release 都不得在活工作树上跑。** 重算相等之后、消费者逐文件读取期间，工作树还能再变（TOCTOU），验的 / 推的会是一个从没被确认过的混合状态。所以先物化成**不可变快照**，在快照里跑。

两层快照的分工是刻意的，**不可互换**：

| 函数 | 产出 | 内容 | 谁用 |
|---|---|---|---|
| `plaud_stage_workspace <空目录>` | §5 的 `StageDirRef` | **整棵工作树的拷贝**（除 `.git`）：含 `.theme-check.yml`、build 源、lockfile、`memory/` | **QA 在这里跑**所有检查 |
| `plaud_stage_verified <空目录>` | §9.1.4 的 `ReleaseStageDir` | **只含可发布面**（`git archive` 物化的那个 tree） | **只用于推站**——整树 push 会把多出的任何文件一起发出去 |

🔴 **为什么必须是两层，而不是一层。** 只含可发布面的目录里**跑不了** theme check（没有 `.theme-check.yml`）、跑不了 build（没有源与 lockfile）、跑不了依赖 `git diff` 的检查。要求在这样的目录里跑 theme check 是自相矛盾的。反过来，把完整工作区拿去 push 会把 `node_modules`、`.env`、scratch 文件全发上线。

两者的 `ThemeTreeOid` **必须相同**；不同即说明两次取证之间工作树变过，**停机**。

🔴 **不要把 workspace 快照说成「不可变快照」。** 它是一份经过**可发布面回环校验**的普通目录副本，准确的边界是：

- **可发布面**有回环复算背书（快照里重算出的 tree oid 必须等于被验证的 `ThemeTreeOid`）；
- **非可发布面**（`.theme-check.yml` / lockfile / build 源 / `memory/`）**没有**原子快照保证：拷贝期间它们可以变化，形成混合快照；
- 非可发布面的 **symlink 按 `cp -RP` 原样保留**，因此仍可能指向快照外的可变对象；
- **非可发布目录下的嵌套 `.git` 会被一起拷进去**（只排除了仓库根的 `.git`）。可发布面的嵌套 git 仓库另有 `GITLINK_IN_*` 门挡着，这里指的是 `tools/` 之类；
- 快照建成之后目录仍可被改。QA 期间不要动它。

**拷贝失败必须被发现。** 不得用 `find … -exec cp …`：`find` 不把 `-exec` 子命令的失败传播成自己的退出码（实测 `find /tmp -maxdepth 0 -exec false \;` 返回 0，`exit 255` 在 BSD find 的 `\;` 形态下同样不传播）。那样一来非发布文件拷贝失败时，可发布面的回环复算照样相等、函数照样成功，**QA 就在一份残缺快照里跑**。函数用的是显式循环 + 逐次判退出码 + 条目数核对。

🔴 **回环复算不是锦上添花，是这两道门唯一可信的部分。** `git archive` 会应用 `export-ignore` / `export-subst`，`tar.umask` 还能改掉 exec 位——「算完再解开」不保证物化结果等于被验证的那个 tree（实测：`export-ignore` 让文件消失而函数照样成功返回）。所以物化之后必须在目标目录里**重新算一次**，与被验证的 oid 逐字相等才算成立。复算用的一次性仓库屏蔽了 global / system config 与 `core.attributesFile`，否则用户机器上的配置会让「复算」用另一套规则去读同一批字节。

**普通目录不是真「不可变」**，它可被改。所以 release 在执行 push 命令**紧前**还要再复算一次并与 `ReleaseSourceTreeOid` 比对（实测能抓到篡改）。可选加强：把物化目录设为 `a-w`。这仍然**不能**创造原子性——同权限的进程在 CLI 逐文件读取期间篡改目录，矩阵挡不住，这条残余风险如实记在这里。

### 2.7 改动归属：`DeclaredDiffCheck`

指纹能证明「树是什么」，证明不了「这些改动是谁的」。少了这一条，同树并行时把别人的半成品一起推上线是**结构上可能**的。

`plaud_declared_diff <base-commit-ish> <pathlist-file>` 的判定对象是**可发布路径集合**：

> 相对基准真正变化的**可发布路径集合**，必须**恰好等于**本工件覆盖的 ChangeSet 声明的可发布路径集合。
> 多出来的（`DECLARED_DIFF_ORPHAN`）= 无主改动，停机；少掉的（`DECLARED_DIFF_UNCHANGED`）= 声明不实，停机。

三条实现上的选择，每条都堵一个洞：

1. **base 取的是 commit，不是「开工前算的那个 oid」。** 默认模式下 `plaud_theme_tree` 算完就删 scratch 对象库，那个 oid **不是可达对象**，事后 `git diff` 根本解析不了。用 `BaseHeadSha` 的可发布子树做 base，对象天然可达、可复算，而且顺带堵上另一个洞：**开工前就已经躺在工作树里的别人的半成品**，在「开工前 oid」做 base 时会被当成基线的一部分而漏掉，在 commit 做 base 时会作为无主改动被抓出来（实测 M6）。
2. **用 `--raw -z --no-renames`，不用 `--name-status`。**
   🔴 **要精确说清这一步做了什么、没做什么**：raw 记录（`:<oldmode> <newmode> <oldsha> <newsha> <status>`）用于**格式守卫**——记录必须成对、必须匹配预期形态，否则解析假设不成立就 fail closed；`--no-renames` 保证不会出现三段的 `R` 记录把两条路径折叠成一条。**判定本身用的是路径集合，不是逐项比 mode 与 blob。**「路径没变但 mode / 内容变了」由 `ChangeSetScopeFingerprint` 承担（它绑的就是声明路径的 tree + `absent` 行），两者分工，不重复。
   不要在下游文档里把这道门写成「四元组逐项相等」——那是过度表述。
3. **声明清单里的非可发布路径（build 源等）不参与本比对**——它们不上线，也就不存在「无主上线」的问题；它们的绑定由 `ChangeSetScopeFingerprint` 承担。

🔴 **并集会折叠重复路径，所以「两个块声明了同一条路径」这道洞挡不住。** `QAScope: Integration` 时必须**另外**核一遍：`IntegrationOf.Members` 各成员的声明路径**两两不相交**，相交即停机（`DeclaredDiffCheck: Failed`）。orchestrator 派活时的「两两不重叠」是同一条判据的上游版本，两处都要做——上游漏派、下游就得抓住。

`base` 取值：`QAScope: SingleChangeSet` 用 `BaseHeadSha`；`QAScope: Integration` 用 `IntegrationPlan.IntegrationBaseCommit`。两者都必须可解析，**不可解析不是可以降级放行的情形**：没有基准就无法证明「树里只有已声明、已归属的改动」，此时 `DeclaredDiffCheck: Blocked` → 无交付许可。

### 2.8 失效语义

QA **在执行任何检查之前**（Step 1，早于 theme check、早于回归）必须重算三个字段，与工件里的记录**逐字精确比对**。

**失配处理**：以下任一情形都必须输出 `ChangeSetIdMatched: No` + `ReadyForDelivery: No` 并停机，要求重新生成 ChangeSet——**不得**自行「顺便把新改动也验了」：

- `ModifiedFiles` 与工作树文件集合不一致（多文件、少文件）
- `ObjectFormat` 不一致（换了仓库 / 换了 object format）
- `ThemeTreeOid` 不一致（可发布面的内容变了）
- `ChangeSetScopeFingerprint` 不一致（**本块声明范围内**的内容变了——这正是只绑文件名会漏掉的情形）

> 📎 **`BaseHeadSha` 与当前 HEAD 不一致，v0.3.0 起不再是失配判据。** v0.2.x 把 `git rev-parse HEAD` 放进 payload 第一行，于是任何 commit 都改变身份；该限制 v0.3.0 起解除。

QA 通过后必须**再算一次** `ThemeTreeOid` 并记入 `changeset-log`；后续任何时刻三个字段与记录不符，该 QA 结论即失效。

**v0.2.x 的这些假失效，v0.3.0 起全部不再发生**（逐条实测）：

| 场景 | v0.2.x | v0.3.0 |
|---|---|---|
| `git add` / `git reset`（内容不变） | 指纹变、QA 失效 | **不变** |
| `git commit memory/` | 指纹变、QA 失效 | **不变** |
| 主题改动 commit（内容一字未改） | 指纹变、QA 失效 | **不变**，且 oid 与 commit 的子树相同 |
| 仓库根 scratch 临时文件（`tc-diff.js` / `node_modules` / `.env`） | 指纹变、QA 失效 | **不变**（不在可发布面） |

> 📎 **v0.2.2 第九轮那条硬规则「`memory/` 的更新留在工作树、不单独 commit」，v0.3.0 起解除。** 它存在的唯一原因是 HEAD 进了 payload；新模型的 payload 里没有 HEAD，实测「改 `memory/`」「`git add memory/`」「`git commit memory/`」三步之后 `ThemeTreeOid` 与 `ChangeSetScopeFingerprint` 逐字不变。**老用户不要继续遵守一条已经不存在的约束。**

### 2.9 保留 / 退役 / 新增的门

全部 fail closed。

**保留**（理由都是「tree 记的是 blob 字节，而 Shopify push 推的是工作树字节，两者不等就绑不住实际上线内容」）：

| 门 | 触发条件 |
|---|---|
| `BYTE_FIDELITY_ATTR` | 任一待判路径的**生效属性**里有 `filter` / `text` / `eol` / `crlf` / `ident` / `working-tree-encoding` / `export-ignore` / `export-subst` |
| `BYTE_FIDELITY_AUTOCRLF` | `core.autocrlf` 归一为真（含 `yes` / `on` / `1` / `input`、大小写变体、以及**裸键**），或取值不认识 |
| `CORE_FILEMODE_FALSE` | `core.fileMode` 的**布尔归一值**为 `false` |
| `SYMLINK_IN_*` | 可发布面 / 声明范围里存在 symlink（**已跟踪的也算**） |
| `GITLINK_IN_*` | 存在嵌套 git 仓库 |
| `NOT_REPO_ROOT` / `NO_THEME_DIRS` / `EMPTY_THEME_TREE` | 执行位置或仓库形态不对 |
| `NEWLINE_IN_PATH` / `NEWLINE_IN_PATH_*` | 待判路径或 tree 条目里含换行 |
| `GIT_TOO_OLD` | git < 2.25 |
| `OBJECT_FORMAT_UNKNOWN` / `OID_LENGTH_MISMATCH` | object format 查不到或 oid 长度对不上 |

**属性门的实现方式变了**：v0.2.x 是**扫 `.gitattributes` 文件**去 grep `filter=`；v0.3.0 是对**每条待判路径问 `git check-attr` 生效属性**。两个直接后果：

- 堵上一个继承缺陷：扫文件的写法会漏掉**被 gitignore 的 `.gitattributes`**、漏掉 `.git/info/attributes` 与 `core.attributesFile`（三者实测都能绕过旧门）；
- 不再误停机：filter 只作用于**非可发布目录**时（`tools/` 之类），扫文件的写法会停机，问生效属性的写法不会。

**退役**（洞被构造性堵上，不再需要停机——每条都有实测）。📎 下表是 v0.2.x 这些门的**退役溯源记录**：门名在此出现属于历史说明，不是仍在生效的规则（核对脚本按 📎 豁免本节）。

| 退役的门 | 为什么新模型不再需要它 | 实测 |
|---|---|---|
| 📎 `IGNORED_PUBLISHABLE_FILE` | `git add -A -f` 让这些文件直接进树，改它指纹就变 | 新增 / 改内容都 CHANGED |
| 📎 `PATH_CASE_MISMATCH` | 空白索引从磁盘重扫，记的就是磁盘上的名字（不再沿用已有条目的大小写） | 纯大小写改名从 FAILED 变成正确捕获，树里记 `assets/A.css` |
| 📎 `UNTRACKED_COUNT_MISMATCH` / `UNHASHABLE_UNTRACKED_DIR` | `git add -A` 自己枚举，不再有手写的未跟踪文件循环与行数核对 | 未跟踪目录正常算出且 CHANGED |
| 📎 `assume-unchanged` / `skip-worktree` 补充门 | 索引标志在**用户的** index 上，新模型用的是空白临时索引，标志不生效 | 两种标志下改内容仍 CHANGED |

**新增**：`STAGE_ROUNDTRIP_MISMATCH` / `STAGE_DST_INSIDE_REPO` / `STAGE_DST_NOT_EMPTY` / `STAGE_GIT_LEAKED` / `SCOPE_SET_MISMATCH` / `SCOPE_LIST_HAS_NUL` / `SCOPE_LIST_HAS_QUOTE` / `DECLARED_DIRECTORY` / `DECLARED_DIFF_ORPHAN` / `DECLARED_DIFF_UNCHANGED` / `DIFF_BASE_UNREACHABLE` / `DIFF_RAW_PARSE_MISALIGNED` / `DIFF_RAW_UNEXPECTED_RECORD`。

**仍然存在、没有被解开的四项**：clean filter 与 `text` / `ident` / `working-tree-encoding` 家族、`core.fileMode` 假值、symlink、嵌套 git 仓库、路径含换行。它们**不是遗留缺陷，是 fail-closed 的设计**：这些机制下 tree 字节 ≠ 上线字节，算得出指纹反而更危险。

> 🔴 **收回一项能力，写在这里以免以后有人以为它能用**：**路径含换行仍然 fail closed**。技术上能算，但 `git check-attr -z` 的三元组要按 NUL 切，而 macOS 自带 awk 不支持 `RS="\0"`（实测只读到一条记录），`tr '\0' '\n'` 又会把含换行的路径拆行、让三元组整体错位（实测把正常仓库误报成 6 条命中）。POSIX shell 里做不出可靠解析器，**所以不装这个能力**，与 v0.2.x 同口径。

> 🔴 **不吹抗碰撞。** `ThemeTreeDigest` 只是包住 `ls-tree` 清单的 SHA-256，清单里的 oid 在 sha1 仓库里就是 sha1。它提供的是**人读 diff** 与**跨 object-format 防误判**，不是抗碰撞。威胁模型是「粗心的 agent」，不是攻击者；要更强就把仓库迁到 sha256。

### 2.10 多 ChangeSet 同批发版

v0.2.3 写的是「**不支持**」，理由是「合并提交之后工作树是干净的，`git status` / `git diff HEAD` 拿到的是空集，与各块并集必然失配」。**这条论证在 v0.3.0 下整个不成立**——身份不再来自 `status` / `diff`，而是来自 tree 对象；实测把改动 commit 掉，`ThemeTreeOid` 逐字不变，即「已验证对象」与「提交后要推送的对象」是同一个 oid。

**本版支持情况：**

| 场景 | 支持情况 |
|---|---|
| 单 ChangeSet 发版 | ✅ 该块自己的 QA 即可给 `ReadyForDelivery: Yes`，条件见 §2.11 |
| **多 ChangeSet 同批发版** | ✅ **支持，但必须有集成 QA**（`QAScope: Integration`），且 §9.1.4 的 `ReleaseQARef` 指向它 |
| 各块在独立分支 / worktree | ✅ 允许，合并后同样走集成 QA（合并是**人**做的，见 §2.12） |

收口流程：

```
各块并行 Implement（Scope 身份互不干扰）
  → 各块 QA（在各自的 workspace 快照里）→ ReadyForIntegration，**不是**交付许可
  → 集成到一棵树（由人执行，矩阵只校验不 merge）
  → 集成 QA（QAScope: Integration）→ 给 ReadyForDelivery: Yes
  → release-ops：plaud_stage_verified 物化 → 从**物化目录**推站
```

🔴 **诚实的收益结算，不打折：**

- 真收益：Implement 可并行；隔离快照上的块 QA 在满足 §2.12 条件时可并行；N 次发版动作合并成 1 次。
- **集成 QA 这道串行屏障消不掉**，它是正确性成本。如果完整 QA 才是绝对瓶颈、而每块仍做一次完整 QA，那只是把瓶颈后移**并多做一次全量验证**。收益要从「块 QA 按该块的 `RequiredQAProfile` 裁剪，不必是全量」这里拿。
- **新模型没有凭空造出「从混合工作树里还原单块快照」的能力。** A、B 已经同时落在活工作树上时，物化出来的是 A+B，不是 A-only。

### 2.11 `ReadyForDelivery: Yes` 的条件

> 交付权仍然只在 `plaud-theme-qa`（§1）。**`QAScope: SingleChangeSet` 与 `QAScope: Integration` 都可以给 `Yes`。**

之所以不写成「只有集成 QA 能给 Yes」：矩阵的绝对多数流量是单 ChangeSet（orchestrator 的进入门槛本来就是「≥2 个可独立验收的 ChangeSet」，单块明确不走它）。那样写等于要求每一个普通 bugfix 都多跑一次全量集成 QA。

真正的不变量是**「本次 QA 验过的那个 tree，就是 release 将要推送的那个 tree，且树里没有它没验过的东西」**。

🔴 **但这个不变量要分两层落，不能全塞进 QA 的 `ReadyForDelivery`。** QA 出工件时 release 工件还不存在——把「`ReleaseSourceTreeOid` 等于 `VerifiedThemeTreeOid`」写成 QA 给 `Yes` 的前提，就成了「release 要 QA 的 Yes、QA 又要 release 的字段」的流程死循环。所以：

**第一层 —— QA 侧（`ReadyForDelivery: Yes` 的全部条件，都是 QA 当场可验证的）**

1. `QAAdmissionStatus: Accepted`；
2. `ChangeSetIdMatched: Yes`（§2.8 的逐字比对）；
3. `DeclaredDiffCheck: Passed`（§2.7）——树里只有本工件覆盖的 ChangeSet 声明的改动，没有兄弟块的半成品、没有无主改动；
4. §5 的全部检查项为 `Passed` 或**带证据的** `NotApplicable`。

**第二层 —— release 侧（发布门，`plaud-theme-release-ops` 执行，不满足即停机、不发版）**

5. `ReleaseSourceTreeOid` **逐字等于** `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid`，且 `ObjectFormat` 相同；
6. `ReleaseDeclaredDiffCheck: Passed`——以「`IncludedInThisPush: Yes` 的块的声明并集」为期望集合重跑一次（§2.14）；
7. `PushCommandCompliance: Compliant`——禁用 `--only` / `--ignore`，且 `PushCommand` 必须逐字包含 `--path <ReleaseStageDir>`（否则推的可能根本不是被验证的那棵树）；
8. 执行 push 命令**紧前**再复算一次物化目录并与 `ReleaseSourceTreeOid` 比对（§2.6）。

第 5 条就是「单块 QA 之后、release 之前工作树又变了」的挡法：工作树一变，release 重新物化出的 `ReleaseSourceTreeOid` 就不再等于那份 QA 的 `VerifiedThemeTreeOid` → 停机。
多块合并之后，**没有任何单块 QA 持有那棵合并树的 oid**，于是第 5 条在结构上必然要求一份集成 QA——不需要再单独规定。这是刻意的：用一条可机械核对的等式，代替一条靠自觉遵守的流程规定。

> 🔴 **`ReadyForDelivery: Yes` 的语义因此是「这棵被验过的 tree 有资格被后续 release 使用」，不是「这次发布一定合法」。** 后者由第二层决定。不要在下游文档里把它写成「可以发了」。

### 2.12 并行语义（不要无条件复述）

| 阶段 | v0.2.3 | v0.3.0 |
|---|---|---|
| Assess（只读） | 可并行 | 可并行 |
| **Implement + 身份生成** | 必须串行 | **可并行**，条件见下 |
| **QA** | 必须串行 | **有条件并行**，条件见下 |
| release | 串行 | 集成后一次 |

**Implement 可并行的条件**（全部满足才算）：各块 `ModifiedFiles` **两两不重叠**、不共享 build 产物、不改同一 token / locale 键。
🔴 `ChangeSetScopeFingerprint` 证明的是「声明路径的当前值」，**不证明作者归属**。派活前由 orchestrator 机械核对两两不重叠；`DeclaredDiffCheck` 在收口时兜底。
🔴 **disjoint 只保证身份不互相失效，不保证可合并。** 共享 token、locale key、schema 值、生成产物与构建输入都可能逻辑冲突——那是集成 QA 要查的东西，不是 Scope 指纹能回答的。

**QA 可并行的条件**：各块的 workspace 快照被物化时，**其它块的改动尚未落进同一棵树**（典型是各块在独立 worktree 里开发，或同树但按落盘时序抢先物化）。

🔴 **不要写成无条件的。** A、B 已经同时落在同一棵活工作树上之后再物化，两份快照**都是 A+B**——那不是两次块 QA，而是一次集成 QA 的两个副本，必须按集成 QA 处理。这一条不用靠自觉：`DeclaredDiffCheck` 会把 B 的改动判成 A 的 `DECLARED_DIFF_ORPHAN` 并停机。

### 2.13 集成者是谁

**矩阵不做 merge。** orchestrator 写死「不自己实现任何代码改动」，qa 写死「不写代码」，三个实现 skill 各自只对自己的 ChangeSet 负责——**矩阵里没有「集成者」这个 skill，v0.3.0 也不新造一个。**

因此：

- `IntegrationPlan.Integrator` **填人**（用户 / 具体 owner），不填 skill 名。同树并行时集成是 no-op（各块本来就同树），独立 worktree 时是一次真 merge，由人执行。
- 矩阵只做**校验**：集成完成后由 `plaud-theme-qa` 以 `QAScope: Integration` 取证，`DeclaredDiffCheck` 核对「最终 diff 恰好等于各块声明并集」。
- **无人认领集成 → orchestrator 停机要授权**，不得自行 merge，也不得假装集成已完成。

### 2.14 `IncludedInThisPush: No` 的块怎么办

DESIGN 要求「`IncludedInThisPush: No` 的块不得留在物化目录里——整树 push 会把它一起发出去」。**必须说清：`plaud_stage_verified` 物化的是一个完整的 `ThemeTreeOid`，没有「减去某块」的能力**（与「不能从混合工作树还原单块快照」是同一个限制）。

所以只有一条合法出路，**「停机」不是出路的全部**：

> 该块的改动**必须从发布源树里撤掉**（由 §2.13 的集成者执行，撤法是 revert / stash / 换 base，属于人的动作），撤完之后**重新取证**（新的 `ThemeTreeOid`）并**重跑集成 QA**。
> 撤不掉、或不愿撤 → 该块只能改判为 `IncludedInThisPush: Yes` 并补齐它的验收，否则**本次 cohort 不能发**。

这条不靠自觉：release 前的 `DeclaredDiffCheck` 以「`IncludedInThisPush: Yes` 的块的声明并集」为期望集合，`No` 块的改动只要还在树里就会被判成 `DECLARED_DIFF_ORPHAN`。

**残余风险如实记**：这等于把「同树并行 + 部分发版」的收益削掉一半——`No` 块要么提前别落进这棵树，要么就得撤销重验。新模型没有让这件事变便宜，只是让它变得**可检测**。

### 2.15 `ReleaseSourceTreeOid` ≠ Shopify 实际上传集合

`ThemeTreeOid` 标识的是**本地推送源**，不是远端最终状态。同一棵 source tree 推两个站点，实际的 upload / delete 集合可能不同（取决于远端现状、CLI 的文件投影、`.shopifyignore`、默认删除行为）。因此：

- `.shopifyignore` **已进 `ThemeTreeOid`**（它改变上传集合，必须绑住）；
- **禁用 `--only` / `--ignore`**（用了就等于 payload 与 `ReleaseSourceTreeOid` 不同源），`--nodelete` 必须显式记录在 `PushCommand` 里并在正文说明影响；
- 记录 Shopify CLI 版本与完整命令参数；
- 逐站点远端 checksum 复核，且**它决定 `PerSitePushResult[].Status`**，不是事后观察项；
- 不同 `TargetSites` 的 ChangeSet **不共用一棵树推站**，按站点集合分 cohort；
- 多站点 push **不是原子的**。远端校验失败时远端可能已经部分改变，`PushResult` 不得填 `NotExecuted`。

### 零改动任务（只读审计 / code review / A11y 审计）

统一记为 `ChangeSetId: N/A` + `ModifiedFiles: []`。此类任务：

- **免 Assess**——`AssessmentRef` 填 `N/A(ReadOnly)`
- **免 QA**——`NextRequiredSkill` 填 `None`，`ReadyForDelivery` 填 `N/A(ReadOnly)`
- **不得借用 `ReconMode: InlineLite`**。只读与 InlineLite 是两回事：InlineLite 是"改动小到可以内联评估"，只读是"根本没有改动"。混用会让只读任务继续输出 `QAStatus: NotRun` / `ReadyForDelivery: No`，与本节取值冲突。只读任务的 `ReconMode` 填 `N/A(ReadOnly)`。
- **不免措辞禁令**：审计结论只能陈述"发现了什么"，不得断言"这个模块没问题 / 可以上线"

#### 🔴 零改动必须有证明，不能靠自称

否则可以先改代码、再输出 `ModifiedFiles: []` 并声称"这只是审计"，从而完全绕开 QA。审计**开始前**和**结束后**各取一次快照，两次必须完全一致：

```bash
# 🔴 用 §2 那两个函数取快照，**不要**用 git status 文本做 hash。
# 只读通道**不需要** BaseHeadSha 相等（期间别人 commit 不影响本次是否只读），
# 但两次的 ObjectFormat + ThemeTreeOid 必须逐字相等。
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }   # 审计开始前
# …… 执行审计 ……
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }   # 审计结束后
```

> 🔴 **v0.2.2 第五轮修：原来这里写的是 `git status --porcelain … | shasum`，它可以被绕过。**
> `git status --porcelain` 只输出**状态码 + 路径**，不含内容。所以工作树**一开始就已经 dirty**（或已有未跟踪文件）时，审计过程中继续改**同一个文件的内容**，前后两次 hash **完全相同** —— 实测复现：`M f.txt` → 改内容 → 状态行仍是 `M f.txt`，hash 不变。
> 后果是最坏的一种：agent 可以先改代码、再输出 `ChangeSetId: N/A` / `ModifiedFiles: []` 并附一份"两次一致"的 `ReadOnlyProof`，**完全绕开 QA**。这正是本节要堵的那件事，旧命令堵不住。
> `ThemeTreeOid` 是可发布内容的 tree oid，改内容必然变。
>
> 📎 **v0.3.0 的一处语义收窄，必须知道**：`ThemeTreeOid` 只覆盖**可发布面**。因此「只读审计期间改了 `src/` 下的 build 源、但没跑 build」这种情形，两次 `ThemeTreeOid` 会相等。这不是漏洞而是定义——build 源不上线；但一旦跑了 build、产物落进 `assets/`，就会被立刻抓到。只读通道的措辞禁令照旧：审计 skill 本来就不该动任何文件。

在契约块里如实登记 `ReadOnlyProof`（两次的 `ObjectFormat` + `ThemeTreeOid`，以及取快照时的 `BaseHeadSha`）。**两次不一致 = 这不是只读任务**：立即退出只读模式，生成正式 `ChangeSetId` 与 §2.1 的三个身份字段，走完 Assess → Implement → Verify。不得以"只是顺手改了一点"为由留在只读通道里。

---

## 3. Assess 阶段工件（`plaud-theme-impact` 产出）

```yaml
AssessmentRef:            # ASMT-<YYYYMMDD>-<NN>，QA 与实现 skill 引用它
ReconMode:               # LegacyImpact | IntegrationSurface | InlineLite
TargetSubject:           # 被改的 section / snippet / asset / token 名
TheoreticalReferences:   # 理论引用数（grep 命中的模板/文件数）
ActiveInstances:         # 启用实例数
DisabledInstances:       # disabled: true 的实例数（必须单列，不得并入 Active）
ActualAffectedInstances: # 逐项核查后真正会触发变化的实例数 + 清单
SharedPropagation:       # 共享 snippet / 全局 CSS / token / build 产物的传播链
LegacyImpact:            # 旧 section / 旧类名 / 旧断点 的连带影响
EntrypointCandidates:    # 可选修改入口（模板存值 / schema / 模块代码）+ 各自风险
RiskTier:                # Low | Medium | High
RequiredQAProfile:       # QA-A | QA-B | QA-C（可多选）。不要填 QA-Global——它由 QA 按 §5 恒执行，不需要下游指定
EvidenceCommands:        # 实际跑过的 grep/ls/node 命令原文，供 QA 复算
BlockingGaps:            # 缺失且必须由用户补的证据；非空则不得进入 Implement
ReadyForImplement:       # Yes | No
```

> 🔴 **`AssessmentRef` 不覆盖「要推哪些站点」。** 它回答的是「哪些**模板 / 实例**受影响」，站点维度（`TargetSites` / `ExcludedSites` / `ThemeIds` / `ScopeSourceRef`）由 `plaud-theme-qa-intake` 在 §9.1.2 里补。
> `plaud-theme-impact` **不要**自行推断站点清单——「这个模块看起来是全站的」不是证据。若在评估中确实拿到了站点信息，写进 `SharedPropagation` 的说明文字，不新造字段。

**`TheoreticalReferences` 与 `ActualAffectedInstances` 必须分开报**。"改的是共享文件"不等于"全站都会变"——逐项核查后真实影响往往收敛很小。只报"可能影响 N 处"是不合格的 Assess。

**`ReconMode` 选择**：

判据一律基于**本次计划写入集**（打算改/新建哪些文件），不是 `git diff`——Assess 发生在实现之前，工作树通常是干净的，用 diff 判会把所有任务误判成 `IntegrationSurface`。git 命令只作辅助核对。

计划写入集在实现过程中扩大（改了原本没打算改的文件）→ 该 `AssessmentRef` **失效**，必须退回重评，不得沿用。

- `LegacyImpact` — 改动触及已存在的 section / snippet / 全局 CSS / token / build 产物。默认模式。判定时注意：
  - `layout/theme.liquid`、`templates/*.json`、section group 通常**没有代码层引用方**，但它们是运行时入口，改动一律算 `LegacyImpact`。"没有引用方"只是 `InlineLite` 的豁免条件之一，不是判 `IntegrationSurface` 的理由。
  - 新建 section **接入**已有模板或 section group → `LegacyImpact`（动了存量运行时入口），同时保留 Path B 的全部检查。
  - 新建 section **同时**改了共享 snippet → `LegacyImpact`，`RequiredQAProfile` 取 `QA-A, QA-B`。
  - locale 改动四分：纯新增独占 key = `IntegrationSurface`；改已有 key 的值 / 改名 / 删除 = `LegacyImpact`。缺部分语言的翻译不升级模式，作为事实交由 QA-B 处理。
- `IntegrationSurface` — 纯新建（如 Path B 新 `sa-*` section），无存量调用方。查的是复用面与冲突面（可复用 snippet、`section-header`/`section-swiper`/`price-format`、token 与 BEM 根类冲突、素材是否误入 assets、schema/locales/数据源完整性、bundle 加载方式、是否被接入模板或 section group、是否顺手改了共享 snippet）。**不要为新建 section 伪造"模板使用量 N"。**
- `InlineLite` — 仅限**全部**满足：改动 ≤ 1 个文件、该文件无其它引用方、非共享 snippet / 非全局 CSS / 非 token / 非 build 产物、不改 schema、不改模板存值。此时实现 skill 可自行内联完成评估，但仍须在 HandoffContract 写明 `ReconMode: InlineLite` 与豁免理由。**拿不准就不是 InlineLite。**

`plaud-theme-impact` 只产出**事实**，不下 `RootCause` 结论、不选方案——那是实现 skill 的职责。

---

## 4. Implement 阶段工件（dev / section-build / ux-migration 产出）

```yaml
ChangeSetId:              # 见 §2；零改动任务填 N/A
BaseHeadSha:              # 🔴 **开工前（实施第一个字节之前）捕获的 baseline commit**，不是交付时的 HEAD。
                          #   实测过的坑：写成「交付时 HEAD」时，实现者只要先 commit 再交工件，
                          #   基准就已经含本次改动 → 所有声明路径落进 DECLARED_DIFF_UNCHANGED → QA 恒阻断，
                          #   而这与「主题改动 commit 不再让身份失效」直接矛盾。零改动填 N/A
                          #   🔴 v0.3.0 起**不再是失配判据**（不与当前 HEAD 比对），但**仍然必填**
                          #   且必须是**可解析的 commit-ish**：§2.7 的 DeclaredDiffCheck 用它做 diff 基准，
                          #   theme check 的 baseline 物化与若干条存量偏差举证要 git show <BaseHeadSha>:<file>。
                          #   缺失 / 不可解析 → 那些检查填 Blocked（不是 Advisories、不是 N/A）
ObjectFormat:             # sha1 | sha256 —— git rev-parse --show-object-format 的原样输出。
                          #   下面两个 oid 都是在这个格式下算的；零改动填 N/A
ThemeTreeOid:             # plaud_theme_tree 输出的第 2 段；零改动填 N/A
ChangeSetScopeFingerprint: # plaud_changeset_scope 输出的第 2、3 段，形态 "<ScopeTreeOid> <ScopeDigest>"
                          #   —— 两段必须一起逐字比：删除只体现在 ScopeDigest；零改动填 N/A
ReadOnlyProof:            # 仅零改动任务：审计前后两次的 ObjectFormat + ThemeTreeOid（必须相等）
                          #   + 取快照时的 BaseHeadSha；其余填 N/A
AssessmentRef:            # 引用 §3 的工件；InlineLite 时填 InlineLite；只读填 N/A(ReadOnly)
OriginTriageRef:          # 本块若由反馈返工产生：§9.1.3 的 TriageId + ItemId；否则 N/A
                          #   —— 返工轮次靠它统计，单块返工不必经 orchestrator
Path:                     # A | B | C
ReconMode:                # 与 Assess 一致；InlineLite 需附豁免理由；只读填 N/A(ReadOnly)
ModifiedFiles:            # 逐条 `- "<逐字路径>": <一句话改动>`；必须与工作树一致；零改动填 []
                          #   🔴 **路径必须用双引号包住且逐字精确**（不 trim、不 glob、不写目录）：
                          #   它同时是 ChangeSetScopeFingerprint 与 DeclaredDiffCheck 的**机器输入** ——
                          #   下游把引号内的字符串逐字取出、每行一条喂给 plaud_changeset_scope /
                          #   plaud_declared_diff。带尾空格的真实路径被 trim 掉，会让声明指错文件
                          #   （改真实文件指纹不变）。路径本身含双引号 → 函数 fail closed，先重命名。
                          #   🔴 **不含 memory/ 下的文件**：memory/ 是项目运行时状态、不属于 ChangeSet，
                          #   也不在可发布面内（三处范围必须一致）。
                          #   Path C 的迁移日志/清单更新照常写 memory/，但**不列进 ModifiedFiles**。
RootCause:                # 机制层根因（bugfix / 迁移偏差）；新建 section 填 N/A
OptionsConsidered:        # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:        # QA-A | QA-B | QA-C（可多选）。不要填 QA-Global——它由 QA 按 §5 恒执行，无需任何上游声明
ThemeCheckRequired:       # Yes | No（判定见 §6）
VisualRegressionRequired: # Yes | No
BuildRequired:            # Yes | No（是否动了 shopify-common/src 需 npm run build）
ApprovedExceptions:       # 本 ChangeSet 声明的 🟠 ApprovedException，逐项一条；无则填 []
                          #   - Clause:      §8.1 或 §8 的条款号，如 8#5（A11y）——必须在 §8.1 封闭清单内
                          #     Scope:       🔴 逐对象绑定，且必须可枚举、可核：
                          #                  A11y 例外 → 逐「前景色 + 背景色 + 出现实例 + 实测 ratio」一条一项
                          #                  其余 → 具体文件 / 字段 / 实例路径
                          #                  禁止聚合写法（"整个模块"/"全站按钮"/"所有该色配对"/"以下若干处"）
                          #                  —— 一条 Scope 覆盖不清的项，QA 判 Failed 而不是追问
                          #     ApprovalRef: 书面批准的链接；**为空即该项 Failed**；
                          #                  批准内容覆盖不到所填 Scope（批了一处、Scope 写了一片）同样 Failed
                          #     ApprovedBy:  批准人（PLAUD PM / 设计 / 技术 owner）；填 agency 自己视同为空
                          #   🔴 双周会「已同意但清单尚未更新」的条款不得列进来（Clause 越界 = 谎报）：
                          #      本字段保持 []，条款按其当前档位照常判，BlockingGaps 记
                          #      PendingClauseListAmendment: …（见 §8.1「封闭清单的变更权限」）
BlockingGaps:             # 实现中发现但无权处理的（如需模板存值编辑授权）
QAStatus: NotRun          # 恒为 NotRun；唯一例外是用户明确弃检时填 Skipped(UserWaived)，见 §1.5
NextRequiredSkill: plaud-theme-qa-intake   # 见 §9.1.2；零改动任务填 None
ReadyForDelivery: No      # 恒为 No，见 §1；零改动任务填 N/A(ReadOnly)
```

> **本块共 22 个 key，顺序即上表顺序，是封闭集合**（v0.2.3 为 20 个）。多一个 key 或少一个 key 都由 QA 的结构核判违规。
> 📎 v0.2.3 的 `ChangeSetFingerprint` **已废止**，不得再出现；用 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` 三元组取代。

> ⚠️ 上面每个 `key:` 与注释之间都有空格。YAML 里 `Key:# 注释` 是解析错误（`#` 会被当成值的一部分或直接报错），照抄时不要压掉那个空格。

---

## 5. Verify 阶段工件（`plaud-theme-qa` 产出）

每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`，**不得**用勾选框或"已检查"。`Blocked` 必须附原因。

```yaml
VerificationId:          # VER-<YYYYMMDD>-<NN> —— **本份 QA 工件自己的稳定身份**（v0.3.0 新增）。
                         # 🔴 **`<NN>` 由调用方（orchestrator 派活时 / 单块流程由用户）指定，QA 不自行推算**
                         #    （v0.3.0 第三波验收补：此前没有定义分配方式，实施方一度想从 changeset-log
                         #    推最大号 +1 —— 那个日志没有这一列，且**并行 QA 会读到同一个最大号、造出重复
                         #    VerificationId**。日志推号这条路在并发下不成立，不要再走）。
                         #    未指定 → **停机要号**，不得自造、不得复用任一成员块的 VerificationId。
                         #   集成 QA 的 ChangeSetId 是 N/A(Integration)，没有它就没有任何东西
                         #   可以被 §9.1.4 的 ReleaseQARef 指住
QAScope:                 # SingleChangeSet | Integration
ChangeSetId:             # 被验的那个；QAScope: Integration 时填 N/A(Integration)
IntegrationOf:           # QAScope: Integration 时**必填非空**，逐块一条（见下方结构）；
                         #   QAScope: SingleChangeSet 时填 N/A
SubmissionId:            # 引用 §9.1.2 的提测包工件；集成 QA 引用**集成提测包**（§9.1.2 支持
                         #   ChangeSetId: N/A(Integration)）；无提测包要求时填 N/A
QAAdmissionStatus:       # Accepted | Blocked —— 提测包准入判定，早于一切检查（见 §9.1.2）
QAAdmissionReason:       # Accepted 时填 Normal；Blocked 时填
                         #   PackageIncomplete | BindingMismatch | MissingArtifact | UserWaivedMaterials
ObjectFormat:            # sha1 | sha256 —— 本轮实际取证时的 object format。
                         #   工件必须自含：release-ops 拿它与 ReleaseSourceTreeOid 的格式比对
ChangeSetIdMatched:      # Yes | No —— 身份绑定是否逐字匹配（见 §2.8）。
                         #   QAScope: SingleChangeSet → 与该块 Implement 工件的三元组逐字比；
                         #   QAScope: Integration     → **IntegrationOf 每一项**的三元组都要逐字比，
                         #                              任一项不匹配即 No
VerifiedThemeTreeOid:    # 本轮 QA 实际验的那个 tree oid。release 的 ReleaseSourceTreeOid 必须逐字等于它
DiffBaseTreeOid:         # DeclaredDiffCheck 的基准树 oid（plaud_declared_diff 输出的第 2 段）。
                         #   SingleChangeSet 由 BaseHeadSha 推出；Integration 由
                         #   IntegrationPlan.IntegrationBaseCommit 推出。取不到 → Unavailable(<原因>)
DeclaredDiffCheck:       # Passed | Failed | Blocked | NotApplicable —— 见 §2.7。
                         #   Failed：树里有无主改动或声明不实；Blocked：基准不可解析（不得降级成 Passed）
                         #   NotApplicable **不适用于任何有改动的 ChangeSet**，填它必须附适用性证据
StageDirRef:             # 本轮检查实际跑在哪个 workspace 快照（plaud_stage_workspace 的产物，绝对路径）。
                         #   🔴 不是 release 物化目录：那里只有可发布面，跑不了 theme check / build
FingerprintVerifiedAt:   # 三次重算的记录，必须都与工件一致：
                         #   Step1(物化前) / Stage(物化回环复算) / Step5(收尾)
QAProfilesRun:           # 实际跑了哪些 profile
ThemeCheck:              # Passed | Failed | Blocked | NotApplicable
ThemeCheckEvidence:      # CLI 版本 / 检查目录 / exit code / baseline 增量数（见 §6）
ThemeRuntimePreview:     # Passed | Failed | Blocked | NotApplicable
AdminSchemaSave:         # Passed | Failed | Blocked | NotApplicable
RegressionMatrix:        # Passed | Failed | Blocked | NotApplicable（附覆盖的断点与状态）
BreakpointsCovered:      # 实际验过的断点，Path C 为 PC/1599/1279/767/375
LocalizationCheck:       # Passed | Failed | Blocked | NotApplicable（英译德长文案）
A11yCheck:               # Passed | Failed | Blocked | NotApplicable
FixedDimensionCheck:     # Passed | Failed | Blocked | NotApplicable（组件写死宽高；例外须已说明理由）
ImageQualityCheck:       # Passed | Failed | Blocked | NotApplicable（图片清晰度红线）
CopyConfigurabilityCheck: # Passed | Failed | Blocked | NotApplicable（展示文案走 schema/locales）
StyleHardRuleCheck:      # Passed | Failed | Blocked | NotApplicable（DTC §2.1 硬性 10 条，见 qa-global.md）
ApprovedExceptionsChecked: # Passed | Failed | Blocked | NotApplicable —— 逐项核 §4 的 ApprovedExceptions
                         #   Failed（判过了，不成立）：ApprovalRef 为空 / ApprovedBy 是 agency 自己 /
                         #     Clause 不在 §8.1 封闭清单内 / ApprovalRef 覆盖不到所填 Scope
                         #   Blocked（该验但验不了）：批准链接 403、权限不足、平台故障等**核不动**的情形
                         #   NotApplicable：§4 填 []
                         #   🔴 "为空"是 Failed 不是 Blocked —— 没提供 ≠ 提供了但打不开
ApprovedExceptionsEvidence: # 逐项写 Clause + Scope + 核了哪条链接 + 结论；不接受"批准已确认"
ProfileSpecificResults:  # 各 profile 的逐项结果
Advisories:              # DTC §2.2 软性项等**非阻断**观察；不得据此把 ReadyForDelivery 置 No
Evidence:                # 命令原文 + 输出摘要；不接受"我看过了"
BlockingGaps:
ReadyForIntegration:     # Yes | No | N/A(Integration) —— **块 QA 的终态**：这一块本身验过了。
                         #   QAScope: Integration 时恒为 N/A(Integration)（集成工件不是任何一块的结论）。
                         #   §9.1.4 的 ReleaseScope[].QAConclusion 逐块抄的就是它
ReadyForDelivery:        # Yes | No —— 见 §2.11 的三道机械门。两种 QAScope 都可以取 Yes
```

`IntegrationOf` 的结构（`QAScope: Integration` 时；`SingleChangeSet` 时整个字段填 `N/A`）：

```yaml
IntegrationOf:
  PlanRef:                    # §9.1 那份 Coordination 工件的 OrchestrationId —— 本次集成依据的 IntegrationPlan
  BaseTreeOid:                # 逐字抄 IntegrationPlan.IntegrationBaseTreeOid
                              #   🔴 必须与本工件的 DiffBaseTreeOid **逐字相等**；不等即 DeclaredDiffCheck: Blocked。
                              #      少了这道等式，可以记一个漂亮的 IntegrationBaseTreeOid、却拿另一个 commit 去算 diff
  Members:                    # 非空；🔴 与 IntegrationPlan.MemberChangeSets **集合相等且无重复**，不等即停机
    - ChangeSetId:              # 被集成的块
      ImplementArtifactRef:     # 该块 §4 工件的出处
      QARef:                    # 该块自己那份 QA 工件的 VerificationId（其 ReadyForIntegration 必须是 Yes）
      SubmissionId:             # 该块的提测包（集成提测包由它们的并集构成，见 §9.1.2）
      ObjectFormat:             # 该块 §4 工件里的取值
      ThemeTreeOid:             # 该块 §4 工件里的取值（三元组比对要它，缺了 ChangeSetIdMatched 无从逐项判）
      ChangeSetScopeFingerprint: # 该块 §4 工件里的取值，集成树里重算必须逐字相等
```

> **本块共 35 个 key，顺序即上表顺序，是封闭集合**（v0.2.3 为 26 个）。
>
> 🔴 **集成 QA 是独立工件，不是某一块的工件的改写。** 它有自己的 `VerificationId`、`ChangeSetId: N/A(Integration)`、非空的 `IntegrationOf`。**不得**把集成结论写进任何一块的 QA 工件里，也不得复用某一块的 `VerificationId`。
> 之所以与块 QA 共用同一套 35 key 而不是另立一份模板：两套近似模板必然漂移，validator 也要维护两份——「独立」指的是**工件实例独立、身份独立**，不是 key 集合必须不同。

### 准入门在最前

`QAAdmissionStatus` 的判定**早于 §2 的 ChangeSet 校验**，是 QA 的 Step 0：

1. 有 `SubmissionId` 且 `SubmissionPackageStatus: Complete` → `Accepted` + `QAAdmissionReason: Normal`，继续走 Step 1 指纹校验。
2. `SubmissionPackageStatus: Incomplete`、没有提测包工件、或提测包与 Implement 工件**绑定失配** → `QAAdmissionStatus: Blocked` + `ReadyForDelivery: No`，**零验证项执行**，把 qa-intake 的 `BlockingGaps` 原样带出。
3. **零改动只读任务**（§2）本来就**不走 Verify**：它由实现 skill 输出 §4 工件 + `ReadOnlyProof`，`NextRequiredSkill: None`。所以它**不会到达 `plaud-theme-qa`**，也就不存在对应的 `QAAdmissionStatus` / `QAAdmissionReason`。
   🔴 **v0.2.2 第七轮更正**：此前这里与 §9.2 都留了 `Accepted` + `ZeroChangeReadOnly` 这条路，而 QA 侧同时又写着「本 skill 没有零改动分支」——两处矛盾会让 QA 为一个没有 ChangeSet 的审计发出一张毫无验证含义的 `Accepted` 工件。该取值已废止。

> 🔴 **用户弃流程不产生 `Accepted`。** 用户说"这次不走提测流程"时，`QAAdmissionStatus` 仍为 **`Blocked`**，但**执行行为与上面第 2 条不同**：
>
> | 情形 | `QAAdmissionReason` | 跑不跑检查 | `ReadyForDelivery` |
> |---|---|---|---|
> | 材料不齐 | `PackageIncomplete` | **零执行** | `No` |
> | 绑定失配 | `BindingMismatch` | **零执行** | `No` |
> | 没有提测包工件 | `MissingArtifact` | **零执行** | `No` |
> | **用户主动弃提测材料** | `UserWaivedMaterials` | **照常执行技术检查项** | `No` |
>
> 弃材料时 `Evidence` 里要记用户弃流程的出处（谁在哪说的）。**靠字段判，不靠聊天上下文猜。**
>
> 区别在于：前者是"不知道该验什么 / 门本身要求不开始"，后者是"绑定有效，只是用户放弃了材料这道门，验证仍有意义"。两者都**不产生许可**。正文一句话说明"已按用户要求跳过提测材料校验，未经完整交付流程的风险由用户承担"。
> 也就是说：用户可以决定不交材料，但**不能因此得到一张写着"准入通过"的记录**。伪造 `Accepted` 会让下游（release-ops、orchestrator 台账）读到一个不存在的事实。

**不得**因为"改动很小"自行免除提测包——那是 `ReconMode: InlineLite` 的判据，与提测材料无关。

### QA Profile

| Profile | 覆盖内容 |
|---|---|
| **QA-A** | 同族 bug 扫描（一个 bug 常伴 3–5 个同族）、依赖树回归、Swiper effect 约束、旧 section 连带影响、JS 生命周期清理 |
| **QA-B** | `sa-*` / `SA:` / BEM 根类名、vendor §1–§12、素材来源（未写死 assets）、schema 完整性、空配置与满配置双测、多语言 |
| **QA-C** | disabled 实例已跳过、空 pre/sub heading 未进总览、三层入口选择正确、20 条踩坑规则中适用项、日志时机（未验收不得写日志内容） |
| **QA-Global** | Theme Check、5 断点、英译德长文案、A11y 底线、组件写死宽高、图片清晰度、展示文案可配置性 |

**QA-Global 恒执行**，与路径无关。

---

## 6. Theme Check 门（实跑，不是自检）

### 何时必须实跑

修改了 `.liquid`、theme JSON / schema、`snippets/`、`sections/`、`templates/`、`config/`、`locales/` 中任一者 → `ThemeCheckRequired: Yes`。纯文档 / 纯注释改动 → `No`。

### 命令

```bash
shopify theme check --path <theme-root> --output json
```

本地 lint **不需要登录 Shopify 店铺**（输入是本地目录，无 store / password 参数）。需要登录的是 `push` / `preview` / dev store 交互。

### 判定方式：baseline 增量，不是绝对 pass

> 🔴 **绝对 pass 不可用。** 实测某 Plaud 主题仓库（2026-08-06，CLI 3.92.0）全仓 **3334 errors / 1004 warnings**，其中 `MatchingTranslations` 占 3254 条（多语言 locale 完整性，仓库级历史状态，与单次改动无关）。剔除后仅 80 条。把"全仓零 error"当门会让每个任务永远红着，等于没有门。这不是某个仓库的特例——存量 warning 堆积是长期演进的主题仓库的常态。

正确判定：

1. 改动**前**（`git stash` 或 HEAD 版本）跑一次**全仓**，记为 baseline。
2. 改动**后**跑一次**全仓**。
3. 两次都必须是全仓，**不得只扫 `ModifiedFiles`**。原因：删除一个 asset / locale key / snippet 会让 offense 出现在**未被修改的调用方文件**里（`MissingAsset`、`TranslationKeyExists`、`MissingTemplate` 都是这样）。只比对改动文件范围会系统性漏掉这类外溢，而它恰恰是删除类改动最典型的破坏方式。
4. 分别统计并都必须为 0 才通过：

   | 指标 | 含义 | 判定 |
   |---|---|---|
   | `addedInModifiedFiles` | 改动文件内新增的 offense | > 0 → `Failed` |
   | `addedOutsideModifiedFiles` | **改动文件之外**新增的 offense | > 0 → 必须归因（见下） |

5. `addedOutsideModifiedFiles > 0` 时必须逐条归因，**不得笼统略过**：
   - 归因为本次改动引起（典型：删了被引用的资源）→ `ThemeCheck: Failed`
   - 归因为基线漂移（期间有人动了别的文件、依赖重装、build 产物变化）→ `ThemeCheck: Blocked` + 说明，**不得**判 Passed
6. 顺手修掉存量 offense 是加分项，但不得作为通过条件，也不得扩散到本次授权范围外的文件。

### 重点关注的 check

这些是 Plaud 主题历史高发、且与本矩阵红线直接对应的：

| check | 对应红线 |
|---|---|
| `LiquidHTMLSyntaxError` | Liquid 文件格式（用户点名的漏项） |
| `UnclosedHTMLElement` | 同上 |
| `ImgWidthAndHeight` | `image_url` 必须带 width / 防 CLS |
| `ValidSchemaName` | schema 命名（Path B 的 `SA:` 前缀） |
| `MissingAsset` / `MissingTemplate` | 引用了不存在的资源 |
| `UnknownFilter` / `DeprecatedFilter` | Liquid 过滤器 |
| `ParserBlockingScript` | 性能 |
| `UndefinedObject` / `UnusedAssign` | Liquid 正确性 |

### Blocked 的合法情形

CLI 未安装、仓库不是 theme root、`shopify-common` build 产物缺失导致检查失真、`.theme-check.yml` 依赖缺失、网络不可用导致首次安装失败。此时输出 `ThemeCheck: Blocked` + 原因，**绝不可**输出 `Passed`。

### 不得越权声明

`ThemeCheck: Passed` 只代表静态 lint 无新增 offense。**不得**表述为"Shopify 兼容性全部通过"。运行时行为、视觉、admin schema 保存行为分别由 `ThemeRuntimePreview` / `AdminSchemaSave` / `RegressionMatrix` 承担。

---

## 7. Stop, don't guess

任一 skill 在缺少必需上游输入时**必须停下要证据**，不得凭经验补齐、不得用"通常来说"填空。典型停机点：

- 找不到目标 section / snippet 的实际文件 → 停，要路径
- 模板存值需要编辑但未获授权 → 停，要授权（`templates/*.json` 默认只读）
- spec 值等距两可（如 20 介于 16/24、12 介于 8/16）→ 停，问用户选哪档
- Figma 值无近邻 token 且视觉重要 → 停，确认后再硬编码
- `plaud-theme-ux-migration` 未读取适用的踩坑规则 → 停，先读再改
- QA 拿不到 `ChangeSetId` 或 `ModifiedFiles` 与工作树不符 → 停，要求重新生成
- 需要浏览器预览验证但无法预览 → 标 `Blocked`，不猜"应该没问题"

停机时输出 `BlockingGaps` 并明确说明**需要用户提供什么**，不要输出半成品然后附一句"可能需要确认"。

---

## 8. 全路径红线（任何 skill 不得违反）

这些与路径无关，`plaud-theme-shared` 是唯一事实源，各 skill **不得复制数值**，只得引用：

1. 展示文案必须走 schema 字段或 locales；Liquid 不得 `| default: '...'` 兜底；`blank` 不输出空壳 DOM
2. 禁止无理由写死组件 `width` / `height`；例外仅限图标、1px 线、明确固定的技术容器、Swiper cube/vertical 要求的固定 px height，且须说明原因
3. 图片清晰度红线：`image_url` 的 `width:` 只用于防 CLS / 适配容器，须按容器实际显示宽度 × 高 DPI 取值，禁止用过小 width 把展示图下采样糊掉
4. 颜色走 token / CSS 变量，不写死 hex（设计系统固定渐变资产等已文档化例外除外）
5. A11y 底线：button 语义、aria-label、dialog trapFocus、轮播 button + aria-label、**对比度 ≥ 4.5:1（受控偏差见下）**、skip link、focus-visible

   > **对比度的唯一受控偏差**：当某组前景/背景配对**由 UX Spec 直接给出**、比值落在 **3.0 ≤ x < 4.5**、且**已取得设计方或 PM 的书面偏差批准**时，QA 记入 `Advisories` 而不判 `A11yCheck: Failed`。
   > 可用的配对是一张**封闭 allowlist**（`a11y.md` §5.1），QA 无权扩充；**批准引用为空则降级为 `Failed`**；**比值 < 3.0 无任何豁免**，spec 给出的也判 `Failed`（此时 `BlockingGaps` 写明属规范缺口，不算开发的实现错误）。
6. JS：null 守卫、TDZ 安全，监听 / timer / observer / subscription 在 `disconnectedCallback` 清理
7. 生成文件（build 产物）勿手改，改动落到源 + 重新 build
8. 最终交付必须经 `plaud-theme-qa`（§1）

### 8.1 运营协作红线（源自《DTC 开发交付标准 v1.0》§三）

> ⚠️ **原文的性质**：DTC §三 标题写的是「软性，尽量遵守，在开发/测试时注意这些问题」。v0.2.0 把其中 10 条一律提为 🔴 硬红线；**设计方在 v0.2.0 评审中明确反对「一刀切」**（原话：过于绝对化会导致设计/开发/测试任何环节的偏差都要全环节对齐，降低效率，应给出合理空间，并点名"复用 section"的情形）。v0.2.1 据此改为**三档**，并对 #5 / #9 / #10 改成**按范围**判定而不是整条降级。这个分级仍是矩阵侧的解释，**若与运营/agency 的双方共识冲突，以双周会的书面结论为准**——但这句话只决定**下一版包怎么写**，不改变**当前包运行时怎么判**（v0.2.2 消歧，见下方「封闭清单的变更权限」；纪要与包内文本不一致时按 §7 停机，运行时仍按已安装包的文本）。

#### 三档的定义

| 档 | 含义 | QA 后果 |
|---|---|---|
| 🔴 **红线** | 踩了必然出事，且机械可判 | `Failed`，阻断 `ReadyForDelivery` |
| 🟠 **可论证放行** | 偏离本身不必然出事，但必须能被复核 | 论证成立 → `Passed`（附论证引用）；论证缺失/空洞 → `Blocked`（可补）；论证证明确实不该偏离 → `Failed` |
| 🟡 **建议** | 只在同页面内部明显不自洽时才提 | 进 `Advisories`，不阻断 |

🟠 **不是"写了理由就放行"。** 它分两种，判据不同：

| 类型 | 谁提供 | QA 怎么复核 | 空的时候 |
|---|---|---|---|
| **EvidenceBased** | agency / 实现方**自证** | 对着 `AssessmentRef` + `ActualAffectedInstances` + `OptionsConsidered`（§4）核**证据是否齐**，不需要任何人"审批" | 三者缺任一、或只有套话没有影响面引用 → `Blocked` |
| **ApprovedException** | agency 可起草，但**必须**有 PLAUD PM / 设计 / 技术 owner 的书面 `ApprovalRef` | 核 `ApprovalRef` 是否存在、是否指向本 ChangeSet 的这一项、条款是否在下方封闭清单内 | `ApprovalRef` 为空 → **降级为 `Failed`**（与 §8 红线⑤ A11y 豁免同一模式：封闭适用范围 + 批准引用必填 + 空引用回落 Failed） |

🔴 **agency 自写自批不构成 `ApprovedException`。** 提供论证的人和批准的人必须不同方。

#### 🔴 `ApprovedException` 的封闭适用清单（v0.2.2 收口）

**只有下表列出的条款可以走 `ApprovedException`。清单是封闭的，QA 与实现方都无权扩充；不在表内的条款，`ApprovalRef` 再齐也不改变判定。**

| 可走 ApprovedException 的条款 | 出处 | 条件 |
|---|---|---|
| A11y 对比度落在 **3.0 ≤ x < 4.5** 且配对在 `a11y.md` §5.1 的封闭 allowlist 内 | §8 红线⑤ | 批准引用必填；`< 3.0` 无任何豁免；allowlist 外一律按常规判 |

> **§8.1 的 11 条里目前没有任何一条可走 `ApprovedException`。** 尤其：
>
> - **第 10 条本次新建 / 修改字段的默认值合规性是 🔴，不可批准豁免。** 拿到设计方或 PM 的书面批准也不改判——正确处理是**先改规范或改默认值**，再交付。批准链接只能让它进 `BlockingGaps` 说明"规范缺口待裁决"，不能让 `StyleHardRuleCheck` 变 `Passed`。
> - 第 8 条、第 9 条纯新增、第 10 条未触及的存量默认值走的是 **`EvidenceBased` / 🟡**，不是批准豁免。
>
> 这条收口是 v0.2.2 补的：v0.2.1 只定义了 🟠 的两种类型却没给封闭清单，任何红线理论上都能尝试走批准通道。

#### 🔴 封闭清单的变更权限（v0.2.2 补：此前只说"清单封闭"，没说谁能改、怎么改、改了怎么让各端知道）

上一段只回答了「运行时不能扩充」，没回答「那要扩充该走什么」——歧义的后果是 agent 可能把一次双周会纪要当成清单扩容的依据，从而给任意条款开 `ApprovedException`。四条写死：

| 项 | 规定 |
|---|---|
| **owner** | 封闭清单是**契约层文本**，唯一写入点是上面那张表（本文件 §8.1）。有权改它的只有**矩阵包 maintainer**，且只能在**切新版本快照**时改。`plaud-theme-qa` / 三个实现 skill / orchestrator / 任何 agent 在运行时**都不得**扩充、缩减或临时采信一份包外清单 |
| **变更证据** | 两件**同时**具备才算变更完成：① 双周会的**书面结论**（纪要链接 + `YYYY-MM-DD` + 与会方，且须含 PLAUD 侧 PM / 设计 / 技术 owner——只有 agency 单方的纪要不成立）；② 该结论**已写进新版本包**的 §8.1 表。缺 ② 时清单**没有**变更 |
| **必须伴随版本发布** | 是。本包按 **git tag** 分发、各端靠仓库根的 `install.sh` / `install.ps1` 按 tag 安装，会议纪要**不随包分发**，agent 运行时读到的只有包内文本。只改纪要不发版本 = 四端各读各的旧清单，等于同一份 `memory/` 被两套规范处理。变更须走：在仓库里改 → §8.1 表改写 → `ContractVersion` 与 `version-manifest.md` §1 同步 bump → `CHANGELOG.md` 记条目 → 四端安装并跑 README 的版本 + 内容双重核对 |
| **纪要与包内文本不一致时** | 按 §7 **停机**报用户，**运行时仍按已安装包的清单判**。`ContractVersion` 漂移检查（`version-manifest.md` §1）是这条的兜底门 |

🔴 **消歧「以双周会的书面结论为准」（本节开头那句）**：双周会对**分级本身**有最终解释权，但它决定的是**下一版包怎么写**，**不改变当前包运行时怎么判**。"会上同意了" 与 "清单里有了" 是两件事，agent 不得把前者当后者。

**"双周会已同意、但尚未进清单"的条款怎么处理（必须有诚实的降级取值，不能没有合法落点）**：

1. 该条款**不得**写进 §4 的 `ApprovedExceptions[]` —— `Clause` 越界会让 `ApprovedExceptionsChecked: Failed`（§9.2），那是**谎报**，不是"待议"。已同意但未进清单时，`ApprovedExceptions` 该是 `[]` 就填 `[]`。
2. **该条款按其当前档位照常判定**，落点是它原本就有的那个字段，**不新造 `ClauseCheck` 之类的字段**：

   | 条款所属 | 结论落在 |
   |---|---|
   | DTC §2.1 硬性 10 条 / §8.1 中由样式承载的条款 | `StyleHardRuleCheck`（§5） |
   | A11y 相关 | `A11yCheck` |
   | 文案可配置 / 硬编码（§8.1 第 5 条） | `CopyConfigurabilityCheck` |
   | 推站清单 / 发版类（§8.1 第 3、4 条） | `plaud-theme-release-ops` 的门（§9.1.4），不在 §5 |
   | 上述都不承载的条款 | **只能靠 `BlockingGaps` 阻断**，不得因为"没有对应字段"就当它通过 |
3. 同时在 `BlockingGaps` 记一条**固定形态**（正文形态，不是新 YAML 字段，因此不进 §9.2 枚举表）：

   ```text
   PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>
   ```

   - `<决议ref>` 与 `<YYYY-MM-DD>` **拿不到就停机问用户**，不得留空、不得自造；**只有 `<目标版本>` 这一栏**允许填 `Unknown(未排期)`。
   - 它**不产生**任何放行效果，也不是 `ApprovedExceptions` 的替代通道。
4. QA 同时在 `Advisories` 记一句，措辞不得暗示当前红线已失效：

   > ✅ 正确：`清单扩容提案尚未进入当前 ContractVersion；本轮仍按当前 §8.1 判定，待议结论不改变本轮的 Failed / Blocked 结果。`
   > ❌ 错误：`本轮不适用` / `已与运营达成一致，暂不阻断` —— 当前包的红线**仍然适用**，只是会上的意见还没成为当前包的规则。

> ⚠️ **`ApprovedExceptionsChecked` 在这种情形下取什么**：`ApprovedExceptions` 为 `[]` → `NotApplicable`（§5 原有口径）。**不要**因为"有一条待议条款"就把它填 `Failed` —— `Failed` 的语义是"声明了但不成立"（`ApprovalRef` 为空 / 越界 / 自批），没声明就没有可判的对象。承载阻断的是上面第 2 条那个字段 + `BlockingGaps`，不是这个字段。

#### 条款分级表

| # | 条款 | 级别 | 判定方式 |
|---|---|---|---|
| 1 | 涉及主流程（ATC 按钮、购买链路、结账等）的功能改动，**且会修改全站默认配置**时 → 必须做成开关且默认关闭，由运营自行开启 | 🔴 | 两个条件**同时**满足才触发。只改单站点存值、或不动全站默认值的主流程改动不受此约束——原文的"会修改全站默认配置"这个前提不得省略 |
| 2 | 不得修改运营的线上配置项 | 🔴 | `templates/*.json`、`config/settings_data.json` 默认只读，改需授权（已见 §7 停机点） |
| 3 | 运营验收完成前，禁止发版对应 section / page | 🔴 | 由 `plaud-theme-release-ops` 守；QA 通过 ≠ 可发版（§1.1） |
| 4 | 发版前必须确认推送站点清单 | 🔴 | `TargetSites` / `ExcludedSites` 必须显式列出，见 §9.1.4 |
| 5 | 新增文案禁止硬编码 | 🔴 **本次新增/修改的行** / 🟡 存量未触及 | **按范围判**，不整条降级：① 本 ChangeSet `git diff -U0` 新增或修改的行里出现硬编码文案 → 🔴 `Failed`（固定 UI 文案走 `locales`，运营可配文案走 schema 字段）；② 未被本次改动触及的存量硬编码 → 🟡 `Advisories`，**不要求顺手修**；③ ⚠️ 但如果本次改动**让原本不可达的旧硬编码进入了新的可达路径**（复用旧 snippet、放开条件分支、新模板挂载旧 section），它按①判 🔴 —— 这一条**必须人工判**，`git diff` 看不出来 |
| 6 | metafield 的 namespace / key / type 必须与已有定义一致，不得新建未申报字段 | 🔴 | 新建前先 grep 现有定义；无对应定义 → 停机要申报 |
| 7 | 动手前先算影响面 | 🔴 | 已由 `plaud-theme-impact` 承担（§3）。**它是红线的理由不是"不可逆"，而是"没有它后面每一条都失去可复核的基准"** |
| 8 | 优先改模板存值，其次 schema，最后模块代码 | 🟠 **EvidenceBased** | 偏离三层入口顺序时，用**既有的 `OptionsConsidered`（§4）**说明为什么上层入口不适用 + 引用 `AssessmentRef`。**不新增 `EntrypointRationale` 字段**——那会形成第二个事实源 |
| 9 | schema 已有的 option values 永不修改 | 🔴 **删/改既有 value** / 🟠 纯新增 | **删除或修改**既有 `value` → 🔴（会让存量实例存值静默失效）；**纯新增** option 不触发本条，但仍须在 `OptionsConsidered` 里给出：新 value 的 Liquid 端映射、schema 保存验证、旧存值向后兼容结论。「新增一律允许、无需验证」**不成立** |
| 10 | 影响 UX 合规的字段，默认值必须已合规；任何字段留空都不能崩 | 🔴 **留空不崩** + 🔴 **本次新建/修改字段的默认值** / 🟡 未触及的存量默认值 | 崩就是崩，无豁免（QA-B 空配置 / 满配置双测）。默认值合规性：本次**新建或修改**的 UX 相关字段 → 🔴（否则每加一个实例就持续制造新的不合规状态）；本次未触及的存量字段默认值 → 适用 §8.1.2 存量复用豁免 |
| 11 | 公共文件修改的英文注释标记 | 🟡 | 见 §8.2 |

### 8.1.1 测试集治理（DTC §一 第 3 条）

DTC 把「测试集要定期更新，建立 PLAUD 专属测试规范」列为**三条总则之一**，但它跨越多个 skill，因此在契约层单列：

| 条款 | 落点 | 字段 |
|---|---|---|
| agency 维护测试集并**随交付更新**，不是一次性文档 | `plaud-theme-qa-intake` | **v0.2.1 起收敛为一行 `TestSetTrace`** + **v0.2.2 起附 `PreviousAcceptedTestSetTrace`** 与换文档时的 **`TestSetMigrationRef`**（原来是三项分别手写，设计方评审指出「重复性工作影响效率」）。🔴 **完整取值规则只在 `package-checklist.md` §3 一处**，本表不复制语法，避免第二个事实源 |
| **每个线上 bug 反推一条回归用例入库** | `plaud-theme-release-ops` | `RegressionCasesAdded`（为空即本次上线治理未完成） |
| 由 PLAUD 测试同学（Aily）**审查** agency 的测试注意文档，双方对齐后固化 | 外部流程 | 矩阵不代替这道人工审查。**不写进 `BlockingGaps`**（那是停机项，会污染语义），改记 QA 的 `Advisories`：「测试规范尚未双方固化」 |

> **为什么不能退到"只给个链接"**：同一个 URL 可以被覆盖内容，也可以每次指向一份临时文档——只要引用不带**不可变 revision**，"长期增量维护"和"每次现编一份"就完全不可区分，这条总则等于没落地。`TestSetTrace` 的成本是一行，其中 `Added` / `Updated` 两段可由测试报告里每条用例自带的标记直接汇总、**不需要另写清单**（`Removed` 推不出来，必须显式列——被删的用例已不在本轮报告里）；若平台 URL 本身已携带不可变 revision，则「引用 + 版本」合并为一个字段即可。**完整语法与判定见 `plaud-theme-qa-intake/references/package-checklist.md` §3，本文件不复制。**

> 🔴 **矩阵不拥有测试集本身。** 测试集是项目侧长期资产（与 `memory/` 同类，不随包分发）。矩阵能做的是：提测时要求用例可复核（`test-case-format.md`）、上线后要求补回归用例、以及在两处都指向同一份测试集。
> **不得**在包里内置一份测试集副本——那会变成第二个事实源，且下次 install 被整包覆盖。

### 8.1.2 存量复用豁免（Legacy Reuse Carve-out）

复用既有 section / snippet / 遗留工具类时，**不因未被本次改动触及的存量偏差判 `Failed`**，记 `Advisories`，也不要求顺手修。

🔴 **它豁免的是"修复义务"，不是"验证范围"。** 三条硬约束：

1. **必须能证明该偏差在 `BaseHeadSha` 上已存在**（给出证据命令或引用）。证不出来 → 按新引入判，不适用豁免。
2. **不得加重，也不得让它变成新的可达行为。** 本次改动使旧偏差在更多实例 / 更多断点 / 新模板上可达 → 按新引入判 🔴（与红线⑤③同一判据）。
3. **回归范围不缩小。** 仍按 `plaud-theme-impact` 的 `ActualAffectedInstances` 全量回归；QA-B 的空配置 / 满配置双测**不因本条豁免**——新接入的上下文、本次改过的字段、schema、以及本次可达的所有路径都要双测。

> 因此本条**依赖** `plaud-theme-impact`，不与它冲突：没有影响面工件就无法证明"已存在且未加重"，豁免自动不成立。

### 8.2 公共文件的改动注释（🟡 建议级，且有前置约束）

DTC §三 第 11 条要求公共文件的改动加英文注释标记。这条与矩阵现有的「默认不写注释、禁止任务过程注释」（`liquid-schema-format.md`）**直接冲突**，因此按下列边界执行，不得无差别铺开：

**只在这些文件生效（allowlist）**：多模块共享的 `snippets/`、全局 CSS / SCSS 源、`layout/theme.liquid`、`assets/` 里的共享 JS。
**禁止写入**：build 产物（`snippets/design-system.liquid` 等生成文件——注释会在下次 build 被冲掉）、`templates/*.json`（JSON 不支持注释，写了直接坏）、单模块自用的 section 文件。

四种格式（**内容必须英文**；注释语法按文件类型选，不得把 `//` 原样塞进 Liquid 或 CSS）：

DTC 原文写的是「年月日时间」，即**日期 + 时刻**。统一用 ISO 8601：`YYYY-MM-DD HH:MM`（需要跨时区协作时用 `YYYY-MM-DDTHH:MM+08:00`）。只写日期不写时刻，同一天多次改动就分不出先后。

| 类型 | 格式（**内容必须英文**） |
|---|---|
| 新增 | 起止都标：`<what it does> - <owner> - YYYY-MM-DD HH:MM - Begin` / `… - End` |
| 插入式 | 旁注一行：`<why changed> - <owner> - YYYY-MM-DD HH:MM` |
| 覆盖式 | 起止都标：`<why overridden> - <owner> - YYYY-MM-DD HH:MM - Begin` / `… - End` |
| 删除 | 删除处留标记：`<why removed> - <owner> - YYYY-MM-DD HH:MM` |

示例（`.liquid`，注意注释语法与英文内容）：

```liquid
{% comment %} Add subscription badge for SA modules - zhang.san - 2026-08-12 14:30 - Begin {% endcomment %}
...
{% comment %} Add subscription badge for SA modules - zhang.san - 2026-08-12 14:30 - End {% endcomment %}
```

| 文件类型 | 注释语法 |
|---|---|
| `.liquid` | `{% comment %} … {% endcomment %}`（**不是** `//`；`//` 在 Liquid 里会原样输出到 HTML） |
| `.css` / `.scss` | `/* … */`（`.scss` 源里可用 `//`，但它不会进编译产物，做标记时用 `/* */`） |
| `.js` | `//` 或 `/* */` |

「负责人 / 修改人」取真实姓名或工号，**不得**填 agent 名或留空；时间用 ISO `YYYY-MM-DD HH:MM`，不用 `2026/8/12` 这类本地格式。拿不到负责人身份时**停机问用户**，不要自己编一个。

---

## 9. 输出块格式

每个 skill 回复的**最后**必须是一个 ` ```yaml ` 代码块，内含该阶段对应的字段（§3 / §4 / §5）。字段缺失视为契约违规。正文可以自由组织，但契约块不得省略、不得改名、不得塞进正文段落里。

> 🔴 **`plaud-theme-shared` 的 `SharedContractCheck` / `ReferencesLoaded` 不是工件字段**（v0.2.2 第八轮补明）。它们是"我读过契约层、解析到哪条路径/阶段"的**正文自检块**，`plaud-theme-shared` 本身是 order 0 的被引用层，既不在阶段轴上、也不在 §0.1 那四个非阶段 skill 之内，因此**没有** `ArtifactKind`、也不出 §3/§4/§5 工件。三条硬约束：
> 1. 自检块写在**正文里、阶段契约块之前**，回复的最后一个 yaml 块永远是阶段工件本身；
> 2. **不得把这两个字段并进阶段契约块** —— §4 是 22 字段、§5 是 35 字段的**封闭集合**，多一个 key 就会被 QA 的结构核判违规；
> 3. **下游不得消费它们**。QA / qa-intake 的事实源只有 §3 / §4 / §9.1.x，没有任何判定可以建立在自检块上。

### 9.1 协调工件（`plaud-theme-orchestrator` 专用）

orchestrator **不是阶段 producer**——它不产生影响面事实、不产生代码改动、不产生验证结论，因此不使用 §3 / §4 / §5 的任何模板。它输出的是协调工件：

```yaml
ArtifactKind: Coordination
OrchestrationId:          # ORCH-<YYYYMMDD>-<NN>
PathResolved:             # A | B | C | Cross(B+C) | Cross(A+C)
ChangeSetPlan:            # 拆出的每个 ChangeSet：编号 / 范围 / 归属 skill / 依赖关系
ParallelSafe:             # 各块的并行判定，**必须区分阶段**（v0.3.0 语义反转，见 §2.12）：
                          #   - Assess（只读）：可并行
                          #   - Implement + 身份生成：**可同树并行**，前提是各块 ModifiedFiles 两两不重叠、
                          #     不共享 build 产物、不改同一 token / locale 键
                          #   - QA：**有条件并行** —— 只有各块 workspace 快照被物化时其它块尚未落进同一棵树
                          #     才成立；已经同时落盘的，两个快照都是 A+B，必须按集成 QA 处理
                          #   🔴 disjoint 只保证身份不互相失效，**不保证可合并**（token / locale / schema
                          #      冲突是集成 QA 查的，Scope 指纹答不了）
IntegrationPlan:          # 多块同批发版时**必填**；本工件天然只服务多块任务，不存在单块取值
                          #   - Integrator:              🔴 **填人**（用户 / 具体 owner），不填 skill 名。
                          #                              矩阵不做 merge（§2.13）；无人认领即停机要授权
                          #   - IntegrationBaseCommit:   集成基准 commit-ish，**必须可解析**（DeclaredDiffCheck 用它）
                          #   - IntegrationBaseTreeOid:  由上一行推出的可发布子树 oid + 与之配套的 ObjectFormat
                          #                              —— 判据用的是**它**，commit 只是让基准对象可达的手段
                          #     🔴 **构造命令写死，不许 agent 自己猜**（v0.3.0 第三轮复核补：原文只说
                          #     「由上一行推出」，而 `git rev-parse <commit>^{tree}` 给的是**仓库根树**、
                          #     不是可发布子树 —— 复核实测两者不等：root=737a… / base_theme=7a2e…。
                          #     照 `^{tree}` 填进去，DeclaredDiffCheck 的基准就是错的，而两侧都"算得出值"）：
                          #
                          #       IntegrationBaseTreeOid=$(plaud_base_theme_tree "<IntegrationBaseCommit>")
                          #                               # 输出一行：<ObjectFormat> <BaseTreeOid>
                          #
                          #     即：对基准 commit 跑 §2.5 的 `plaud_base_theme_tree`，取它输出的两段。
                          #     🔴 **不是 `plaud_theme_tree "<IntegrationBaseCommit>"`**（v0.3.0 收尾验收
                          #     修正：本行一度就是那样写的）—— `plaud_theme_tree` 是**无参函数**，函数体里
                          #     根本没有 $1，传进去的 commit 被静默丢弃，返回的是**当前工作树**的 oid。
                          #     那样写会让本字段与 DiffBaseTreeOid 恒不相等 → DeclaredDiffCheck 恒 Blocked
                          #     → 多块集成结构性死锁，而两侧都"算得出值"、看不出错。
                          #     取不到（commit 不可解析 / 函数失败）→ **停机**，不得退到 `^{tree}` 或任何近似值。
                          #   - MemberChangeSets:        参与本次集成的 ChangeSetId 清单
                          #   - IntegrationQAOwner:      由谁触发集成 QA（plaud-theme-qa，注明由谁调起）
                          #   - IntegrationResultTreeOid: 🔴 **集成完成后的可发布树 oid + 配套 ObjectFormat**
                          #     （v0.3.0 第三波验收补：这一格原来是**契约真空** —— 集成提测包的顶层
                          #     `ObjectFormat` / `ThemeTreeOid` 没有任何 producer。qa-intake 对主题身份是
                          #     **纯透传**（不是 producer 也不是 verifier），而集成没有 Implement 工件可透传；
                          #     QA 只能重算比对、不能原创。结果是集成 QA 恒 `Blocked`、拿不到交付许可 —— 死锁。）
                          #     **producer = `Integrator`（上面那个填人的角色）**：集成落盘后、提测之前，
                          #     在集成后的工作树根目录跑
                          #
                          #       IntegrationResultTreeOid=$(plaud_theme_tree)
                          #
                          #     取值连同 ObjectFormat 记进本工件；qa-intake 从这里**原样透传**到集成提测包的
                          #     顶层 `ObjectFormat` / `ThemeTreeOid`，QA 的 Step 1 再独立重算比对。
                          #     🔴 三方约束：intake 透传值 == 本字段 == QA 重算值，任一不等即 `ChangeSetIdMatched: No` 停机。
                          #     取不到（函数失败 / 集成者未提供）→ **停机**，不得由 intake 或 QA 代为生成 ——
                          #     那会让"取证方与验证方相互独立"这个前提失效。
ChangeSetStatus:          # 各 ChangeSet 当前阶段与 handoff 引用；含 SubmissionId（提测准入）与 TriageId（若该块由反馈回流产生）
BlockingGaps:
AllChangeSetsDelivered:   # Yes | No —— **v0.3.0 改定义**：全部下辖 ChangeSet 的 ReadyForIntegration 均为 Yes，
                          #   **且**存在一份集成 QA 工件且其 ReadyForDelivery 为 Yes。
                          #   （v0.2.3 的定义是"全部块的 ReadyForDelivery 均为 Yes"。多块流程里各块的树
                          #    含兄弟改动、DeclaredDiffCheck 必然不过，块 QA 的 ReadyForDelivery 恒为 No，
                          #    照抄会让本字段永远取不到 Yes）
```

> **本块共 9 个 key**（v0.2.3 为 8 个），顺序即上表顺序，是封闭集合。
> `IntegrationPlan` 有 **6 个子字段**（`Integrator` / `IntegrationBaseCommit` / `IntegrationBaseTreeOid` /
> `MemberChangeSets` / `IntegrationQAOwner` / `IntegrationResultTreeOid`）；子字段不计进 9 key。

#### 🔴 `IntegrationPlan` 的两个时点（`IntegrationResultTreeOid` 的生命周期）

本工件**不是一次写死的**。`IntegrationPlan` 的 6 个子字段分两个时点落：

| 时点 | 谁写 | 写什么 |
|---|---|---|
| **规划期**（派活时） | `plaud-theme-orchestrator` | 前 5 项。`IntegrationResultTreeOid` **此刻不存在** |
| **集成落盘后、集成提测之前** | `IntegrationPlan.Integrator`（**人**）把值交给 orchestrator，orchestrator 更新**同一个 `OrchestrationId`** 的这份工件 | 补上 `IntegrationResultTreeOid`（`plaud_theme_tree` 输出的第 1、2 段） |

只有**已填第 6 项的那一版**协调工件可以被 `plaud-theme-qa-intake` / `plaud-theme-qa` 消费。配套停机条件：

- 规划期**不得**为 `IntegrationResultTreeOid` 填任何值：不填 `N/A`、不填 `Pending` / `TBD`、不拿
  `IntegrationBaseTreeOid` 或任一成员的 `ThemeTreeOid` 顶替。它此刻**不表示任何 oid**。
- `plaud-theme-qa-intake` 读到的是**未填第 6 项的旧版**、或 `ObjectFormat` 与 oid 只有一半、或 oid 长度与
  `ObjectFormat` 不符 → **停机，不产出 QAIntake 契约块**，要 `Integrator` 先补取证。**不得自己重算**，
  也不得借用基准树 / 成员树 / QA 的 oid —— 那会让「取证方与验证方相互独立」这个前提失效。
- `plaud-theme-qa` 拿到的 intake 顶层 `ObjectFormat` / `ThemeTreeOid` 与最终协调工件的
  `IntegrationResultTreeOid` **不等** → `QAAdmissionStatus: Blocked` / `BindingMismatch`；缺失 →
  `Blocked` / `MissingArtifact`。QA 自己重算的值与之不等 → `ChangeSetIdMatched: No` 并停机，
  要 `Integrator` 重新确认结果树、更新协调工件、重出集成提测包。**QA 不得代为生成这个值。**

`AllChangeSetsDelivered` 是**汇总读数，不是交付许可**。它只能反映各 ChangeSet 的 QA 结论，orchestrator 不得据此自行宣布可交付，也不得在任一 ChangeSet 的 QA 未通过时置 Yes。交付权仍然只在 `plaud-theme-qa`（§1）。

### 9.1.2 提测准入工件（`plaud-theme-qa-intake` 专用）

```yaml
ArtifactKind: QAIntake
SubmissionId:             # SUB-<YYYYMMDD>-<NN>
ChangeSetId:              # 本次提测对应的 ChangeSet（§2）；**集成提测包**填 N/A(Integration)
IntegrationOf:            # ChangeSetId: N/A(Integration) 时**必填非空**：本次集成覆盖的 ChangeSetId 清单，
                          #   每项附该块的 SubmissionId —— 集成提测材料 = 各块材料的并集 + 集成本身的
                          #   ReworkDelta。其余情形填 N/A
                          #   🔴 没有这一项，集成 QA 结构上取不到任何 intake 工件 → 恒 Blocked/MissingArtifact
                          #      → 恒拿不到交付许可。这是死锁，不是保守
                          #   🔴 本清单必须与 IntegrationPlan.MemberChangeSets **集合相等且无重复**，
                          #      且每项的 SubmissionId 必须真实存在且 SubmissionPackageStatus: Complete。
                          #      少了这条等式，可以少列一个块、让它的材料整份缺席而 intake 照样 Complete
                          #   🔴 **嵌套项 SubmissionId 取不到时怎么填（v0.3.0 第三波追认）**：本字段是嵌套
                          #      结构，而「缺失即 Incomplete」原来只对**顶层**字段定义过 —— 嵌套项没有
                          #      合法缺失值，照旧写法只能填个 N/A 蒙混过去。分两种情形，**不得混同**：
                          #      · 该块**已提测但包非 Complete** → 照写它真实的 SubmissionId，顶层判
                          #        SubmissionPackageStatus: Incomplete，BlockingGaps 指名是哪一块的哪一项；
                          #      · 该块**从未提测**（根本没有 SubmissionId 这个对象）→ **停机**，不出集成包，
                          #        要求先把该块提测。**不得**填 N/A / None / Pending 之类自造取值 ——
                          #        那会让「每项 SubmissionId 必须真实存在」这条等式失去意义。
                          #      判据只认对象是否存在，不认口述。
ObjectFormat:             # 从 Implement 工件原样带过来；**集成提测包**改从
                          #   IntegrationPlan.IntegrationResultTreeOid 原样透传（见 §9.1「两个时点」）
ThemeTreeOid:             # 同上，不重算、不改写。🔴 本 skill 对这一对是**纯透传**，既不是 producer
                          #   也不是 verifier：集成路径下**不得**自己跑 plaud_theme_tree 现算一个
                          #   —— 那是把集成者的取证责任挪给材料装配方，责任链断在这里。
                          #   协调工件没填 IntegrationResultTreeOid → **停机**，不出契约块
ChangeSetScopeFingerprint: # 同上；集成提测包填 N/A(Integration)（逐块取值在 IntegrationOf 里）
PackageRootRef:           # 提测材料所在位置：本地目录绝对路径 / 云端根文档 URI —— QA 据此复算
PackageFingerprint:       # 见下方「包指纹」；提测材料本身的内容绑定
TargetSites:              # 本次要推的站点清单（显式列出，不得写"相关站点"）
ExcludedSites:            # 明确不推的站点 + 原因
ThemeIds:                 # 各站点对应的主题 ID（预览与验收都要定位到具体主题）
ScopeSourceRef:           # 站点清单的来源（运营需求单 / Linear issue / 飞书消息链接）
PreviewManifest:          # 后台链接 + 前端链接 + 各自实测可访问性与检查时间（内容）
PreviewManifestStatus:    # Complete | Incomplete —— 上述内容的判定（状态）
ConfigurationGuideStatus: # Complete | Incomplete | NotApplicable
SelfTestReportStatus:     # Complete | Incomplete
TestSetTrace:             # 语法与判定**唯一**见 package-checklist.md §3（本处不复制规则）
PreviousAcceptedTestSetTrace: # 上一轮通过准入的那一行原文 | None(FirstSubmission) | Unavailable(<原因>)
                          #   —— 稳定文档 ID 须与本轮一致、revision 须不同；不一致即 SelfTestReportStatus: Incomplete，
                          #      **除非**附了合法的 TestSetMigrationRef（换文档的正当路径，见下一字段与 §3.1）。
                          #   **例外**：取数路径三级都拿不到时填 Unavailable(<原因>)，此时不判 Incomplete、改记 Advisories
                          #   完整取数路径与判定见 package-checklist.md §3（唯一事实源，本处不复制规则）
TestSetMigrationRef:      # 换了一份新测试文档时的结构化迁移声明 | N/A(SameDocument) | N/A(NoPreviousTrace)
                          #   From= 必须与本轮 PreviousAcceptedTestSetTrace 的 ID@revision 逐字一致，
                          #   To=   必须与本轮 TestSetTrace 的 ID@revision 逐字一致（不引入新的外部事实源）。
                          #   语法、Reason 封闭枚举、CaseDisposition 清单要求**唯一**见 package-checklist.md §3.1
ScreenshotManifestStatus: # Complete | Incomplete
ImpactScopeStatus:        # Complete | Incomplete
ReworkDeltaStatus:        # Complete | Incomplete | NotApplicable（非返工轮次填 NotApplicable）
SubmissionPackageStatus:  # Complete | Incomplete —— 上述**六项 Status** 全 Complete/NotApplicable 才为 Complete
BlockingGaps:             # 缺哪份材料、缺什么字段，逐项写清
NextRequiredSkill: plaud-theme-qa
```

> **本块共 26 个 key**（v0.2.3 为 23 个），顺序即上表顺序，是封闭集合。

> 🔴 **提测包必须与某个具体 ChangeSet 焊死，否则可以重放。** `ChangeSetId` + `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` 从 Implement 工件**原样带过来**，QA 在 Step 0 会拿它与当前 Implement 工件逐字比对——不比对的话，A 任务的 `Complete` 包可以直接拿去给 B 任务用；材料也可以在 intake 通过之后被替换（所以 QA 还要重算 `PackageFingerprint`）。

**这个工件没有 `ReadyForDelivery` 字段，一个字都不许出现。** 它判的是「材料齐不齐」，不是「代码行不行」；语法上刻意与 `ReadyForDelivery` 拉开距离（`Complete/Incomplete` vs `Yes/No`），就是为了防止下游误读成第二个发布许可。

**六项材料的验收标准**（对应 DTC §四）：

| 字段 | Complete 的条件 |
|---|---|
| `PreviewManifest` | 后台链接与前端链接**都实测访问过**并记录时间；后台链接必须可配置（能看到 schema 字段），不是只读预览。失效链接 = 未提测 |
| `ConfigurationGuideStatus` | 新 section / 新配置项必交：字段说明 + 默认值 + 使用场景 + 填错怎么办，**关键部分有截图**。本次未新增任何配置项时才可填 `NotApplicable` |
| `SelfTestReportStatus` | ① 用例写成可复核形式：前置条件（具体站点 + 主题 ID + 配置状态）→ 操作步骤（具体 URL）→ 预期结果（**具体值或现象**）→ 结论，且**有附件截图/视频**。预期结果写"显示正常""功能可用"的用例**视同未测**；② **`TestSetTrace` + `PreviousAcceptedTestSetTrace`** —— 缺 `@<不可变revision>`、delta 段留空、`Removed` 段缺失、均判 `Incomplete`；与上一轮的**稳定文档 ID 不一致**也判 `Incomplete`，**除非**附了合法的 `TestSetMigrationRef`（见下一项③）；另一处例外是没有可比对的上一轮：**日志读到了但确无非 `N/A` 行** → `None(FirstSubmission)`；**日志读不到 / 缺该列 / 历史行全是 `N/A`** → `Unavailable(<原因>)`（两者不可混用，误填会把「不可核验的历史」伪装成「首次提交」）；两者都必须配 `TestSetMigrationRef: N/A(NoPreviousTrace)` → 不阻断、记 `Advisories`。**完整语法与判定唯一见 `package-checklist.md` §3**（本表不复制语法）；③ **`TestSetMigrationRef`** —— 稳定文档 ID 与上一轮不同时**必须**给结构化迁移声明（`From` / `To` / 封闭枚举 `Reason` / `ReasonRef` / `CaseDisposition` + 一份进了 `PackageFingerprint` 的旧用例清单），**自由文本理由一律 `Incomplete`**；未换文档填 `N/A(SameDocument)`，无可比对的上一轮填 `N/A(NoPreviousTrace)`（语法与判定唯一见 `package-checklist.md` §3.1） |
| `ScreenshotManifestStatus` | 8 张：`375 / 768 / 1024 / 1280 / 1440` + 边界 `767 / 1279 / 1599` |
| `ImpactScopeStatus` | 本模块被几个模板使用、涉及哪些站点。**直接引用 `plaud-theme-impact` 的 `AssessmentRef`**，不自行重算；站点维度 `AssessmentRef` 不覆盖，须另填 `TargetSites` |
| `ReworkDeltaStatus` | 返工轮次必交「本轮修改点」清单（逐条：反馈 → 改了什么 → 在哪个文件） |

> 🔴 **提测截图不能替代 QA 自己的回归。** 这 8 张是给运营/PM 看的交付材料；QA 的 `BreakpointsCovered`（Path C 为 `PC / 1599 / 1279 / 767 / 375`）是 QA 自己实跑的，两者互不顶替。记 `PC` 时必须写出实际像素宽度，如 `PC(1920)`，光写 `PC` 无法复核。

**包指纹 `PackageFingerprint`**：§2 的三个身份字段只覆盖**主题仓库的可发布面**，对截图、配置文档、测试报告、预览 URL 一无所知。因此提测材料另算一份：

```bash
# 在提测材料目录（不在主题仓库内）执行
plaud_package_fingerprint() (
  set -o pipefail
  # 🔴 根目录守卫（v0.2.2 第十轮实测补）——§2 第七轮为此加了 NOT_REPO_ROOT，本函数一直没有配套。
  #    在材料树的**子目录**里跑，`find .` 只看得见该子目录，于是**静默算出一个子集指纹并返回 0**
  #    （metamorphic 已证：改兄弟目录里的自测报告，子目录指纹纹丝不动）。最坏情形不是失配而是
  #    **false acceptance**：producer 与 QA 用同一个错误的 PackageRootRef 时两边算出同一个值、
  #    `Accepted` 照发，而自测报告 / 配置说明 / 截图全部不在绑定链里 —— 这是整套门禁里唯一一个
  #    「两边一致却什么都没绑住」的通道，比任何失配都严重。
  #    判据：cwd 必须逐字节等于 §9.1.2 `PackageRootRef` 指向的目录（调用前 export 给本函数）。
  [ -n "${PLAUD_PACKAGE_ROOT:-}" ] || {
    printf 'NO_PACKAGE_ROOT: 未提供 PLAUD_PACKAGE_ROOT（应等于 §9.1.2 的 PackageRootRef），无法确认取证范围\n' >&2
    return 1; }
  _proot=$(cd "${PLAUD_PACKAGE_ROOT:-}" 2>/dev/null && pwd -P)                          || {
    printf 'PACKAGE_ROOT_UNRESOLVABLE: %s 无法解析\n' "${PLAUD_PACKAGE_ROOT:-}" >&2; return 1; }
  [ "$_proot" = "$(pwd -P)" ] || {
    printf 'NOT_PACKAGE_ROOT: must run at the package root. cwd=%s PackageRootRef=%s\n' "$(pwd -P)" "$_proot" >&2
    return 1; }
  # 🔴 与 §2 同族的三条约束：payload 先收变量再 hash、逐行数核对、空 URL fail closed。
  #    行数核对不能省：循环零次迭代（heredoc 建不了临时文件、find 无输出等）退出码也是 0，
  #    不核对就会退化成"只 hash 了 urls: 那一行"——材料完全没参与，指纹却完全正常。
  # 🔴 `PLAUD_PREVIEW_URLS` 的事实源与序列化必须固定（v0.2.2 第九轮补：此前只规定「不得为空」，
  #    没说从哪来、怎么排、用什么分隔 —— intake 与 QA 各自拼一次，同一组 URL 因顺序或空白不同
  #    就算出两个 PackageFingerprint，材料没动却判 BindingMismatch）。唯一合法构造：
  #      取 §9.1.2 `PreviewManifest` 里的**前端预览 URL 与后台配置 URL 全集**（不含检查时间、
  #      不含备注），逐条 trim 首尾空白，`LC_ALL=C sort -u` 去重排序，用**单个换行**连接：
  #        PLAUD_PREVIEW_URLS=$(printf "%s\n" "$u1" "$u2" … \
  #          | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | LC_ALL=C sort -u)
  #    producer 与 verifier 必须用一字不差的同一构造；URL 集合变了就是新的提测包，重算即可。
  [ -n "${PLAUD_PREVIEW_URLS:-}" ] || return 1      # 预览 URL 不得为空
  # 🔴 三类必须 fail closed，不能静默排除（v0.2.2 第五轮补，均实测过会静默漏算）：
  #    (a) 路径含换行 → NUL→换行转换会把它拆成两行，两半都 hash 不到
  #    (b) symlink    → -type f 直接跳过；改 symlink 目标内容、或改指向，指纹都不变
  #    (c) 隐藏文件/目录 → 主体 `find . -type f` **确实会 hash 到**它们，但隐藏对象
  #        （`.DS_Store`、`.git/`）要么被系统随时改写、要么携带无关大树，会让同一份材料
  #        算出不同指纹，所以仍然 fail closed —— 是「不许有」，不是「悄悄跳过」。
  nl_probe=$(find . -print0 | tr -d '\0' | tr -cd '\n' | wc -c | tr -d ' ')          || return 1
  [ "$nl_probe" = "0" ] || { echo "NEWLINE_IN_PATH: 材料路径含换行，先重命名" >&2; return 1; }
  # 🔴 只允许普通文件与目录。symlink / FIFO / socket / device 一律 fail closed
  #    —— 主体是 `-type f`，其余类型会被**静默跳过**（实测：材料树里加个 FIFO，指纹不变且返回 0）。
  #    不用 `| head -5`：pipefail 下 head 提前关闭管道会让 find 收到 SIGPIPE、丢掉诊断信息。
  # 🔴 两类分开报（v0.2.2 第八轮）：旧写法把隐藏对象和非普通文件合并成一条
  #    "只接受普通文件与目录"，而 `.DS_Store` **就是**普通文件 —— macOS 上只要用 Finder
  #    打开过材料目录就必然有它，agent 拿到的是一句自相矛盾、无从下手的报错，提测指纹
  #    等于永远算不出来。现在分别给出各自的处置动作。
  bad_type=$(find . ! -type f ! -type d -print)                                       || return 1
  [ -z "$bad_type" ] || { printf 'UNSUPPORTED_MATERIAL_OBJECT: 只接受普通文件与目录，下列对象不进指纹（先移除或换成真实文件）：\n%s\n' "$bad_type" >&2; return 1; }
  bad_hidden=$(find . -name '.*' ! -name '.' -print)                                  || return 1
  [ -z "$bad_hidden" ] || {
    printf 'HIDDEN_MATERIAL_OBJECT: 材料目录不得含隐藏文件/目录（内容会被系统改写或携带无关大树，指纹不可复现）：\n%s\n' "$bad_hidden" >&2
    printf '  处置：确认无用后删除，例如 `find . -name .DS_Store -delete`；有用的材料改成不以点开头的名字。\n' >&2
    return 1; }
  # 🔴 `sort` 必须固定 `LC_ALL=C`（v0.2.2 第九轮实测）：同一份含 `ä.txt` / `中.txt` 的材料，
  #    C / en_US.UTF-8 / zh_CN.UTF-8 排出三种顺序、三个不同指纹 —— intake 与 QA 只要环境
  #    locale 不同就必然 `BindingMismatch`，而材料一个字节都没改。
  files=$(find . -type f -print0 | tr '\0' '\n' | sed '/^$/d' | LC_ALL=C sort)       || return 1
  n_files=$(printf '%s\n' "$files" | grep -c '[^[:space:]]') || return 1
  [ "$n_files" -gt 0 ] || return 1              # 材料目录不得为空
  body=$(
    # 🔴 同 §2：必须带结尾换行，否则最后一个材料文件不进循环
    printf '%s\n' "$files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      # 🔴 必须先取出再判空：$( ) 的失败不会让外层 printf 失败
      h=$(shasum -a 256 -- "$f" | cut -d' ' -f1) || exit 1
      [ -n "$h" ] || exit 1
      printf 'f %s %s\n' "$f" "$h" || exit 1
    done || exit 1
  ) || return 1
  got=$(printf '%s\n' "$body" | grep -c '^f ') || got=0
  [ "$got" -eq "$n_files" ] || { echo "FILE_COUNT_MISMATCH: $got != $n_files" >&2; return 1; }
  printf '%s\nurls:%s\n' "$body" "$PLAUD_PREVIEW_URLS" | shasum -a 256 | cut -d' ' -f1
)
# 🔴 原样抄这两行，**不要只抄第一行**（v0.2.2 第十轮实测补）：旧写法只有 `plaud_package_fingerprint || echo "PACKAGE_FINGERPRINT_FAILED"`，
#    它打印了 PACKAGE_FINGERPRINT_FAILED 却让整段 **rc=0** —— 任何按 `$?` 分支、或跑在 `set -e` 下的调用方
#    都会认为这道门通过了。判定既要看输出、也要看退出码。
plaud_package_fingerprint || { echo "PACKAGE_FINGERPRINT_FAILED"; exit 1; }
```

> 🔴 **为什么要把 `shasum` 的结果先赋给变量再判空。** 写成 `printf '%s %s\n' "$f" "$(shasum ...)"` 时，命令替换里的失败**不会**让 `printf` 失败——`printf` 拿到空串照样成功返回 0，`|| return 1` 永远不触发，指纹退化成"只反映文件名列表、不反映文件内容"。
> 这与 §2 那个 `--find-renames=false` 的 bug 是**同一类**错误：管道/替换里的静默失败。写任何指纹命令时都要问一句：这一段失败了，外层真的会知道吗？
>
> **自检**：改一个材料文件的内容（不增删文件），指纹必须变化；还原后必须精确复原。做不到就是命令又退化了。

**材料放云文档时怎么算指纹**：上面的算法只 hash 本地目录。材料在飞书云文档 / Linear 附件里时，本地目录放一份 **manifest**（一个 `materials.tsv` 之类的纯文本文件）参与 hash：

```
<材料名>\t<URI>\t<不可变版本号或 revision>\t<内容 digest>
```

> 🔴 **"人工核对时间"不是内容绑定，v0.2.2 第五轮删除该选项。** 它记的是"某人某时看过"，内容随后被替换时 manifest 一个字都不会变 —— 与下面"无 revision / 无 digest 一律 `Incomplete`"直接矛盾。两栏都必须是**机器可复核**的值。

| 材料位置 | 怎么进指纹链 |
|---|---|
| 本地文件（截图等） | 直接 hash 文件内容 |
| 飞书云文档 | manifest 记 URI + **文档版本号**（飞书文档有 revision）；改了文档版本号会变 → 指纹变 |
| Linear 附件 | manifest 记 URI + 附件 ID |
| **无版本号 / 无 digest 可取的外链** | 🔴 **不允许** —— 该材料判 `Incomplete`。要么下载一份到本地目录参与 hash，要么换成能取版本号的载体 |

> 🔴 **不能内容绑定的材料一律 `Incomplete`，不得带着"已知弱环"拿到 `Complete`。**
> 否则整条防替换链就有一个公开的洞：把材料挂在一个无版本外链上 → 内容随便换 → 指纹照样对得上 → `SubmissionPackageStatus: Complete` → `QAAdmissionStatus: Accepted`。
> **`BlockingGaps` 是停机项，不是"记一笔就放行"的免责栏。**

**QA 复算时对云端材料要重新查远端**：不能只比对本地 manifest（那样 manifest 没更新、云文档内容变了照样通过）。对每条云端材料重新取一次当前 revision / digest，与 manifest 记录值比对，不一致 → `QAAdmissionStatus: Blocked` + `QAAdmissionReason: BindingMismatch`。取不到（无权限 / 服务不可用）→ `Blocked`，不猜。

> 🔴 **提测材料不得写进主题仓库。** 材料放仓库外的独立目录或云文档。
>
> 材料落进**可发布目录**时 `ThemeTreeOid` 会变化，QA 的 Step 1 判 `ChangeSetIdMatched: No` 并停机。**但这不是一道门**（v0.2.2 第十轮实测更正：原文把这个副作用写成了强制机制「你会因为交了材料而过不了自己的准入门」）——放进任何**被 gitignore 的非发布目录**、或放进 `memory/` 且是 **`.md`**，指纹与 `git status` 都看不见，intake 与 QA 会双双看到一个干净的绑定，而材料事后被换掉没有任何机制会发现。真正的门是 `plaud-theme-qa-intake` Step 1 的**三条命令**（常规位置 / ignored 位置 / `memory/` 全量），必须逐条跑。

### 9.1.3 反馈分类工件（`plaud-theme-feedback-triage` 专用）

```yaml
ArtifactKind: FeedbackTriage
TriageId:                     # TRI-<YYYYMMDD>-<NN>
FeedbackSource:               # QA打回 | 运营验收 | 线上反馈 | 内部发现
OriginChangeSetId:            # 该批反馈针对的原 ChangeSet；无对应时填 N/A
FeedbackItems:                # 见下：每条一个条目，字段逐条填，不得只给总体结论
LinearStatusAdvice:           # 建议的 Linear 状态操作；本 skill 不自动执行
BlockingGaps:
```

`FeedbackItems` **每一条**都是一个完整条目，**九个字段缺一不可**（`ItemId` / `Text` / `ClassificationRecommendation` / `EvidenceRefs` / `PMDecision` / `PMDecisionValue` / `PMDecisionRef` / `NextRoute` / `NewWorkItemRef`）—— 旧文写「五个字段」与下面的模板不符，按「五个」执行会漏掉 PM 确认与回流链所需的后四项（v0.2.2 第六轮更正）：

```yaml
FeedbackItems:
  - ItemId:                       # TRI-<...>-01、-02…
    Text:                         # 反馈原文，不改写、不合并
    ClassificationRecommendation: # DeliveryDefect | RequirementEvolution | Undetermined —— 本 skill 的建议
    EvidenceRefs:                 # 依据：PRD 条目 / Figma 节点 / UX Spec 章节；查过没找到的也要写"未找到"
    PMDecision:                   # Pending | Confirmed
    PMDecisionValue:              # PM 确认的**是哪一类**（DeliveryDefect | RequirementEvolution）；Pending 时填 N/A
    PMDecisionRef:                # PM 确认的出处（Linear 评论 / 飞书消息）；Pending 时填 N/A
    NextRoute:                    # AwaitPMDecision | NewWorkItem(Assess) | Backlog(排期) | NoAction
    NewWorkItemRef:               # NextRoute 为 NewWorkItem 时：**Assess 之前已创建的外部工作项**
                                  #   （Linear issue 等）。**不得填 ChangeSetId** —— 那要到 Implement
                                  #   才产生；新 ID 由实现 skill 在自己的 OriginTriageRef 里回指本工件
```

> 🔴 **分类是逐条的，不是整批的。** 一段反馈里常混着缺陷与新想法（见 `plaud-theme-feedback-triage/SKILL.md` Step 0），把 `ClassificationRecommendation` 放在顶层等于强制合并判定，必然判错。
>
> 🔴 **`PMDecision: Confirmed` 必须同时给 `PMDecisionValue`。** 只写 "Confirmed" 说不出 PM 确认的是缺陷还是变更，下游无法据此决定去向。
>
> 🔴 **`PMDecision: Pending` 时 `NextRoute` 只能是 `AwaitPMDecision`。** 否则下游会拿着一个未经确认的建议直接开工——PM 判定权就形同虚设了。

三条硬规则：

1. **本 skill 只给建议，判定人是 PM。** `ClassificationRecommendation` 是推荐值，`PMDecision` 未 `Confirmed` 前不得当作定论往下走。DTC §六 原文：「判定人是 PM」「未标类型的按变更处理」。
2. **判为缺陷 ≠ 直接回实现 skill 打补丁。** 必须开**新工作项**，从 Assess 重新进入，生成新的 `ChangeSetId`——旧 ChangeSet 的 QA 结论在代码再次变化时已自动失效（§1.4）。复用旧 ChangeSet 是契约违规。
3. **Linear 状态不自动改。** `LinearStatusAdvice` 只是建议；实际点状态是外部动作，需用户显式授权。顺序严格按 DTC §七：收到反馈或 QA 打回 → 先 `Feedback Revision` → 再回 `In Dev`；需求变更点 `Requirement Change`；紧急打断点 `Requirement Interruption`；提测 `Ready for QA`；被阻塞**不改状态**，在评论区写阻塞项与阻塞方。

**判定口径**（DTC §六）：能在 PRD、Figma 或 UX Spec 里找到依据 = `DeliveryDefect`（计返工）；找不到依据 = `RequirementEvolution`（算变更，不计返工）。依据不明时填 `Undetermined` 并列出需要 PM 补的信息，**不要**为了给个结论而硬套。

### 9.1.4 发版工件（`plaud-theme-release-ops` 专用）

```yaml
ArtifactKind: ReleaseOps
ReleaseId:                # REL-<YYYYMMDD>-<NN>
ReleaseScope:             # 见下：逐个 ChangeSet 的 QA 结论 + 验收状态，不用单个标量表达
ReleaseQARef:             # 🔴 **本次发布许可的唯一来源**：那份 ReadyForDelivery: Yes 的 QA 工件的
                          #   VerificationId + 出处。单块直发指向该块 QA；多块同批**必须**指向
                          #   QAScope: Integration 的集成 QA。
                          #   （字段名不叫 IntegrationQARef：单块场景它指的不是集成工件）
ObjectFormat:             # sha1 | sha256 —— 与 ReleaseQARef 那份工件的取值必须相同，否则 oid 不可比
ReleaseSourceTreeOid:     # 本次推送源的 tree oid。**必须逐字等于 ReleaseQARef 那份工件的
                          #   VerifiedThemeTreeOid**；不等即停机（这是 §2.11 第 2 道门）
ReleaseStageDir:          # plaud_stage_verified 物化出的目录绝对路径（只含可发布面）。
                          #   🔴 不是 QA 的 StageDirRef（那是完整 workspace 快照，含 node_modules /
                          #   .env / build 源，整树 push 会把它们全发上线）
StagedAt:                 # 物化完成时间。**只记不判**（审计留痕），不构成任何判据
ShopifyCliVersion:        # shopify CLI --version 原样输出；换版本可能改变文件投影与删除行为
PushCommand:              # 完整命令原文，逐字。🔴 必须包含 `--path <ReleaseStageDir>` 且路径与该字段
                          #   逐字相等 —— 否则推的可能根本不是被验证的那棵树（cwd 或 --path 指向别处时，
                          #   命令里没有 --only/--ignore 也照样"合规"）
PushCommandCompliance:    # Compliant | Violation —— 出现 --only / --ignore 即 Violation 并停机
                          #   （用了就等于 payload 与 ReleaseSourceTreeOid 不同源）。
                          #   --nodelete 不判 Violation，但必须出现在 PushCommand 里并在正文说明影响
EffectivePayloadManifest: # 逐 cohort / 逐站点：实际上传集合 + 远端 base digest。**只记不判**，
                          #   是给人看的推送凭证；判定由 RemoteVerifyResult 承担
RemoteVerifyResult:       # 逐站点：Matched | Mismatched | Unavailable —— 远端 checksum 复核结论。
                          #   它**决定** PerSitePushResult[].Status，不是事后观察项。
                          #   🔴 两个**推站尚未发生**的合法取值（v0.3.0 收尾验收补：此前只有推后语义的
                          #   三个值，而输出发版清单等授权的那一轮必然还没推 —— 逐站预填 Unavailable
                          #   会被映射成 Unverified，凭空捏造一次没发生的推送）：
                          #     · 整轮未推（PushResult: NotExecuted）→ 整个字段填 N/A(NotExecuted)
                          #     · 已推但某站点根本没尝试（PushResult: PartiallyExecuted）→ 该站点填
                          #       N/A(NotAttempted)，映射到 PerSitePushResult[].Status: NotAttempted
                          #   🔴 TargetSites / RemoteVerifyResult / PerSitePushResult 三者必须**逐站点
                          #   一一对应、无重复、且 TargetSites 非空**——空站点集合会让「每个站点都成功」
                          #   在真空里成立，PushResult: Executed 就成了假读数
ReleaseDiffBaseCommit:    # 归属复核的基准 commit-ish，必须可解析。单块直发抄该块 §4 的 BaseHeadSha；
                          #   多块同批抄 IntegrationPlan.IntegrationBaseCommit
ReleaseDeclaredDiffCheck: # Passed | Failed | Blocked | NotApplicable —— **推站前重跑一次** §2.7，
                          #   期望集合是「IncludedInThisPush: Yes 的块的声明路径并集」。
                          #   🔴 这是 §2.14「No 块不得留在发布源树里」的**唯一承载字段**：
                          #      没有它，那条规则就只是正文要求、没有任何机械核对
TargetSites:              # 二次确认后的推送站点清单，逐个显式列出
ExcludedSites:            # 本次不推的站点 + 每个的原因
ThemeIds:                 # 各目标站点对应的主题 ID
SiteListConfirmedBy:      # 两次确认的出处（需求时 + 发版前），谁/在哪/什么时候
PRRef:                    # agency 提供的 PR 链接
AuthorizationRef:         # 用户显式授权执行推送的出处；未授权填 NotAuthorized
PushResult:               # NotExecuted | Executed | PartiallyExecuted —— 实际推送结果。
                          #   Executed 仅当**每个**站点都是 Succeeded；只要有一个不是且有一个是，
                          #   就必须填 PartiallyExecuted（填 NotExecuted 会抹掉已发生的线上副作用）
PerSitePushResult:        # 逐站点：站点 / Succeeded|Failed|Unverified|NotAttempted / 时间 / 原因。
                          #   🔴 由 RemoteVerifyResult 逐站点决定：
                          #     Matched → Succeeded ／ Mismatched → Failed ／ Unavailable → **Unverified**
                          #   Unverified **不得**折算为 Succeeded，也不是 NotAttempted（推已经发生了）
PushedAt:                 # 实际推送时间；NotExecuted 时填 N/A
PostReleaseWatch:         # 上线后跟踪项：谁/在什么时间窗/看什么
RegressionCasesAdded:     # 每个线上 bug 反推的回归用例（逐条：bug → 用例 ID）
                          #   本轮无线上 bug 时填 N/A(NoOnlineBug)；**留空 ≠ N/A**，留空表示该补没补
TestSetTraceAfterArchive: # 回归用例入库后测试集那一行的新取值。**与 TestSetTrace 同格式、三段齐**：
                          #   <稳定文档ID>@<新revision>; Added=[TC-…]; Updated=[…]; Removed=[…]
                          #   （本次只新增回归用例时写 Updated=[]; Removed=[]，不要省段）
                          #   🔴 稳定文档 ID 必须与本次提测时 QAIntake 的 TestSetTrace 同一个（否则等于没有长期测试集）；
                          #   revision 必须是入库**之后**的新值；Added 段必须含本次新增的回归用例 ID。
                          #   本次无线上 bug 时填 N/A(NoOnlineBug)
BlockingGaps:
```

`ReleaseScope` **逐个 ChangeSet 填**，因为验收是**按 section / page 分别发生**的，一个标量表达不了"部分验收"：

```yaml
ReleaseScope:
  - ChangeSetId:
    QAConclusion:       # 🔴 v0.3.0 起逐块抄该块 QA 工件的 **ReadyForIntegration**（Yes | No）。
                        #   任一 IncludedInThisPush: Yes 的块其 QAConclusion 不是 Yes → 该块不得发版。
                        #   唯一的降级取值 N/A(NotIncluded)：**仅当** IncludedInThisPush: No **且**
                        #   该块根本不存在可解析的块 QA 工件。块 QA 存在就必须照抄真实结论
    QARef:              # 该块那份 QA 工件的 VerificationId + 出处。
                        #   🔴 没有它，QAConclusion 就是一个无法追溯来源的标量，填 Yes 也证明不了来自哪份 QA。
                        #   与 QAConclusion 同条件下可填 N/A(NotIncluded)；IncludedInThisPush: Yes 时为空即停机。
                        #   本次的**交付许可**不在 ReleaseScope 里，在顶层的 ReleaseQARef
    AcceptanceStatus:   # Accepted | Pending —— 该块对应 section/page 的运营验收状态
    AcceptanceRef:      # 验收出处；Pending 时填 N/A
    IncludedInThisPush: # Yes | No —— Pending 的块填 No，留到下次
```

> 📎 🔴 **v0.3.0 支持多块同批发布**（§2.10）。v0.2.3 那条「`IncludedInThisPush: Yes` 至多一个」的硬规则**已删除**。取而代之的是两条可机械核对的条件：
> 1. `IncludedInThisPush: Yes` 多于一个时，`ReleaseQARef` **必须**指向 `QAScope: Integration` 的集成 QA 工件，且其 `VerifiedThemeTreeOid` 逐字等于 `ReleaseSourceTreeOid`；不满足即停机。
> 2. 按 `TargetSites` 分 cohort：**站点集合不同的块不共用一棵树推站**。
>
> 🔴 **`IncludedInThisPush: No` 的块，其改动不得留在发布源树里**（§2.14）。`plaud_stage_verified` 物化的是一整棵 `ThemeTreeOid`，**没有「减去某块」的能力**——所以唯一出路是由集成者（人）把该块从树里撤掉、重新取证、重跑集成 QA。这条不靠自觉：`DeclaredDiffCheck` 以「`IncludedInThisPush: Yes` 的块的声明并集」为期望集合，`No` 块的改动只要还在树里就会被判成 `DECLARED_DIFF_ORPHAN`。

> 🔴 **`AcceptanceStatus` 必须逐块给。** 顶层一个 `Accepted` 表达不了"A 验收了、B 还没"，而 DTC 要求的正是**只发已验收的部分**。用单标量时，要么把没验收的一起发了，要么把验收了的一起压住——两种都错。

**这个工件同样没有 `ReadyForDelivery` 字段。** 它消费 QA 的结论，不生产结论。

四条硬规则（DTC §五）：

1. **`AcceptanceStatus: Pending` 时不得发版对应 section / page。** QA 通过只是技术门，运营验收是另一道（§1.1）。
2. **推送站点清单要确认两次**：运营提需求时填一次，发版前二次确认。`SiteListConfirmedBy` 两次都要有出处。推错站点是 DTC 原文点名"过去扣分最多的一项"。
3. **上线后功能类 bug（非样式）当天解决**；样式类进最近一次迭代修复。
4. **每个线上 bug 必须反推一条回归用例入库**——同一个问题不允许出现第二次。修完不补用例，`RegressionCasesAdded` 判空即视为未完成。

发版本身（`git push` / Shopify theme push / 合并 PR）是**外部动作**，本 skill 只产出清单与判定，执行需用户显式授权。

> **本块共 28 个 key**（v0.2.3 为 16 个），顺序即上表顺序，是封闭集合。
>
> 🔴 **执行 push 命令的紧前必须再复算一次**物化目录的 tree oid 并与 `ReleaseSourceTreeOid` 比对。普通目录不是真「不可变」，复算相等之后到 CLI 逐文件读完之间它还能被改。这道复算能抓到篡改，但**不创造原子性**——同权限进程在读取期间改目录，矩阵挡不住，这条残余风险如实记在这里（§2.6）。

### 9.2 字段取值枚举

以下字段的取值是**封闭枚举**，不得自造：

**阶段契约字段**（§3 / §4 / §5 / §9.1 的 yaml 块内）：

| 字段 | 允许值 |
|---|---|
| `QAStatus` | `NotRun` \| `Skipped(UserWaived)` |
| `ReadyForDelivery` | `Yes`（仅 QA，**两种 `QAScope` 都可取**，条件见 §2.11 的三道机械门）\| `No` \| `N/A(ReadOnly)` |
| `ReadyForIntegration` | `Yes` \| `No` \| `N/A(Integration)`（**`QAScope: Integration` 时恒取此值**——集成工件不是任何一块的结论）。**v0.3.0 新增** |
| `QAScope` | `SingleChangeSet` \| `Integration`。**v0.3.0 新增**。它是 §5 工件的判别式：`Integration` 时 `ChangeSetId` 必须是 `N/A(Integration)` 且 `IntegrationOf` 非空 |
| `ObjectFormat` | `sha1` \| `sha256`（`git rev-parse --show-object-format` 的原样输出）\| `N/A`（仅零改动任务）。**v0.3.0 新增**。查不到时**不许回退默认值**——两种格式对同一内容算出的 oid 完全不同 |
| `DeclaredDiffCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable`。**v0.3.0 新增**（§2.7）。🔴 **基准不可解析是 `Blocked`，不是 `Passed` 也不是 `NotApplicable`**；`NotApplicable` 只对零改动任务成立且须附证据 |
| `PushCommandCompliance` | `Compliant` \| `Violation`。**v0.3.0 新增**。`--only` / `--ignore` 出现即 `Violation` 并停机 |
| `RemoteVerifyResult` | `Matched` \| `Mismatched` \| `Unavailable`（逐站点填）\| `N/A(NotExecuted)`（**整个字段**，仅当 `PushResult: NotExecuted`）\| `N/A(NotAttempted)`（**逐站点**，该站点根本没尝试推送）。**v0.3.0 新增**。🔴 前三个是**推后**语义，推站尚未发生时逐站预填 `Unavailable` = 凭空捏造一次没发生的推送（它会被映射成 `Unverified`「推已经发生了」） |
| `ReadyForImplement` | `Yes` \| `No` |
| `Path` | `A` \| `B` \| `C`（**v0.2.2 第七轮补**：QA 的结构核要按封闭枚举核 §4 全部字段取值，此前这几项没有事实源，`Path: D` 之类既可能被放行、也可能被无依据地停机） |
| `ThemeCheckRequired` / `VisualRegressionRequired` / `BuildRequired` | `Yes` \| `No` |
| `NextRequiredSkill` | `plaud-theme-qa-intake`（实现 skill 的正常下游）\| `plaud-theme-qa`（仅 qa-intake 工件填）\| `None`（零改动只读任务） |
| `ChangeSetIdMatched` | `Yes` \| `No`。语义随 `QAScope` 变：`SingleChangeSet` 比该块 §4 工件的三元组；`Integration` 比 `IntegrationOf` **每一项**的三元组，任一不匹配即 `No` |
| `ReconMode` | `LegacyImpact` \| `IntegrationSurface` \| `InlineLite` \| `N/A(ReadOnly)` |
| `RiskTier` | `Low` \| `Medium` \| `High` |
| `RequiredQAProfile` | `QA-A` \| `QA-B` \| `QA-C`（可多选）。**不含 `QA-Global`**——它由 QA 恒执行并记入 `QAProfilesRun`，任何上游工件写它都是违规 |
| `ThemeCheck` / `RegressionMatrix` / `LocalizationCheck` / `A11yCheck` / `ThemeRuntimePreview` / `AdminSchemaSave` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `ArtifactKind` | `Coordination`（orchestrator）\| `QAIntake`（qa-intake）\| `FeedbackTriage`（feedback-triage）\| `ReleaseOps`（release-ops）。**阶段 skill 不填此字段** |
| `AllChangeSetsDelivered` | `Yes` \| `No` |
| `QAAdmissionStatus` | `Accepted` \| `Blocked`（仅 QA 填） |
| `QAAdmissionReason` | `Normal` \| `PackageIncomplete` \| `BindingMismatch` \| `MissingArtifact` \| `UserWaivedMaterials`。~~`ZeroChangeReadOnly`~~ **v0.2.2 第七轮废止** —— 零改动任务不进 QA（见 §5 准入门第 3 条） |
| `ConfigurationGuideStatus` / `ReworkDeltaStatus` | `Complete` \| `Incomplete` \| `NotApplicable` |
| `SelfTestReportStatus` / `ScreenshotManifestStatus` / `ImpactScopeStatus` / `SubmissionPackageStatus` | `Complete` \| `Incomplete` |
| `AcceptanceStatus` | `Accepted` \| `Pending`（**逐 ChangeSet 填**，不是整批一个值） |
| `StyleHardRuleCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `ApprovedExceptionsChecked` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable`。🔴 **界线**：`ApprovalRef` **为空 / 越界 / 自批 → `Failed`**（判过了，不成立）；**提供了但核不动**（403、权限不足、平台故障）→ `Blocked`。「没提供」不等于「验不了」，把前者填 `Blocked` 是谎报 |
| `ApprovedExceptions[].Clause` | 只能取 §8.1 **封闭清单**里的条款号。清单外的取值一律视为契约违规，`ApprovedExceptionsChecked: Failed`。🔴 **「双周会已同意但清单尚未更新」不构成清单内**——那种条款不得列进 `ApprovedExceptions`，走 `BlockingGaps` 的 `PendingClauseListAmendment` 正文形态（§8.1「封闭清单的变更权限」）；清单本身只能由矩阵包 maintainer 在新版本快照里改 |
| `ClassificationRecommendation` / `PMDecisionValue` | `DeliveryDefect` \| `RequirementEvolution` \| `Undetermined`（`PMDecisionValue` 不取 `Undetermined`）\| `N/A`（**仅 `PMDecisionValue`，且仅当 `PMDecision: Pending`**——PM 还没决定就不存在决定值。v0.2.2 第九轮补：模板要求 Pending 时填 `N/A`，而本枚举原来不含它，结构核会判非法，等于逼 agent 去伪造一个尚未发生的 PM 决定） |
| `PMDecision` | `Pending` \| `Confirmed` |
| `NextRoute` | `AwaitPMDecision`（`PMDecision: Pending` 时**只能**取此值）\| `NewWorkItem(Assess)` \| `Backlog(排期)` \| `NoAction` |
| `PreviewManifestStatus` | `Complete` \| `Incomplete` |
| `TestSetTrace` / `PreviousAcceptedTestSetTrace` | 自由文本，格式与判定**唯一事实源是 `package-checklist.md` §3**；此表只约束一点：**缺 `@<revision>`、或分号后为空 → 视为未提供**。`PreviousAcceptedTestSetTrace` 另可取 `None(FirstSubmission)` 或 `Unavailable(<原因>)`。**`Unavailable` 的成立条件是「找不到任何一条 `TestSetTrace` 非 `N/A` 的历史行，且用户也给不出上一轮已通过准入的工件」**——含三种情形：日志无此列（旧日志）/ 有列但历史行全是 `N/A` / 日志文件缺失。判定见 `package-checklist.md` §3 |
| `TestSetMigrationRef` | 结构化迁移声明（`From=…; To=…; Reason=…; ReasonRef=…; CaseDisposition=…`）\| `N/A(SameDocument)` \| `N/A(NoPreviousTrace)`。其中 **`Reason` 是封闭枚举三值**：`PlatformMigration` \| `OwnerHandover` \| `Deprecated`（**刻意无 `Other` 兜底**，越界即 `SelfTestReportStatus: Incomplete` + `BlockingGaps: TestSetMigrationReasonOutsideClosedEnum`）；`CaseDisposition` 两形态：`Mapped(<locator>)` \| `BulkRetired(<locator>)`，且 locator **只能是 `Local(<相对路径>)`**（清单要核内容，云端 `Manifest(...)` 只能核到 revision/digest）。语法与判定**唯一事实源是 `package-checklist.md` §3.1**，此表只约束一点：**`From` 必须逐字等于本轮 `PreviousAcceptedTestSetTrace` 的 `ID@revision`、`To` 必须逐字等于本轮 `TestSetTrace` 的 `ID@revision`**。一拆多 / 多合一的迁移形状本版**不支持**，须停机（`BlockingGaps: TestSetMigrationShapeUnsupported`），不得挑一份旧文档冒充一对一 |
| 红线分级标记（§8.1） | `🔴 红线` \| `🟠 EvidenceBased` \| `🟠 ApprovedException` \| `🟡 建议`。🟠 的两种**不可互换**：`ApprovedException` 缺 `ApprovalRef` 直接 `Failed`，`EvidenceBased` 缺证据是 `Blocked` |
| `ReleaseScope[].QAConclusion` / `ReleaseScope[].QARef` | `QAConclusion`：`Yes` \| `No`（逐块抄该块 QA 的 `ReadyForIntegration`）\| `N/A(NotIncluded)`；`QARef`：该块 QA 的 `VerificationId` + 出处 \| `N/A(NotIncluded)`。**v0.3.0 新增**。🔴 `N/A(NotIncluded)` **仅当** `IncludedInThisPush: No` **且**该块不存在可解析的块 QA 工件；块 QA 存在就必须照抄真实结论与真实 `VerificationId`。`IncludedInThisPush: Yes` 的块两者都不得取它，`QARef` 为空即停机 |
| `IncludedInThisPush` | 📎 `Yes` \| `No`。🔴 v0.2.3 的「`Yes` 至多一个」限制**已删除**（§9.1.4）；`No` 块的改动不得留在发布源树里（§2.14） |
| `TestSetTraceAfterArchive` | 与 `TestSetTrace` **同格式且三段齐**（`Added` / `Updated` / `Removed` 都要出现，只新增时后两段写 `[]`；唯一事实源 `package-checklist.md` §3），另可取 `N/A(NoOnlineBug)`。**稳定文档 ID 与 QAIntake 那份不一致 → 视为未归档**。它不接受 `None(reason)`——归档轮次必然有新增用例 |
| `PushResult` | `NotExecuted` \| `Executed` \| `PartiallyExecuted`（部分站点失败时**必须**用它，填 `NotExecuted` 会抹掉已发生的线上副作用、导致重复推送） |
| `PerSitePushResult[].Status` | `Succeeded` \| `Failed` \| `Unverified` \| `NotAttempted`。🔴 **由 `RemoteVerifyResult` 逐站点决定**：`Matched`→`Succeeded`／`Mismatched`→`Failed`／`Unavailable`→**`Unverified`**（**v0.3.0 新增取值**）。`Unverified` 不得折算为 `Succeeded`（复核不动 ≠ 推成功），也不是 `NotAttempted`（推已经发生了） |
| `FeedbackSource` | `QA打回` \| `运营验收` \| `线上反馈` \| `内部发现` |

> 🔴 **`Complete/Incomplete` 与 `Yes/No` 不可互换。** 提测包用前者、交付许可用后者，这是刻意的语法隔离（§9.1.2）。在提测工件里写 `Yes`、或在 QA 工件里写 `Complete`，都视为契约违规。

> **`Blocked` 与 `Failed` 不可混用。** `Failed` = 验了、发现缺陷（实现 skill 应去修）；`Blocked` = 该验但没验成（用户豁免、ChangeSet 失配、工具不可用）。把未执行填成 `Failed` 会让下游去追不存在的缺陷；填成 `Passed` 或无证据的 `NotApplicable` 则是谎报。两者都不允许。

阶段契约字段出现枚举外的值（如 `Done`、`Partial`）一律视为违规。需要表达枚举覆盖不到的状态时写进 `BlockingGaps` 正文，不要新造取值。

**`memory/` 记录字段**（不是阶段契约，单独一套枚举）：

| 字段 | 允许值 | 位置 |
|---|---|---|
| `QAStatus` | `Pending` \| `Valid` \| `Invalidated` | `changeset-log.md` |
| `ThemeTreeOid` / `ScopeFP` | 📎 **v0.3.0 新增的两列，取代 v0.2.3 的 `ChangeSetFingerprint` 一列**。`ThemeTreeOid` 记前 12 位，`ScopeFP` 记 `ChangeSetScopeFingerprint` 的 `ScopeTreeOid` 前 12 位；另需一列 `ObjectFormat`。**旧行不回填**：v0.2.3 及以前的行保留原 `ChangeSetFingerprint` 列并按旧语义阅读，新行一律用新列。🔴 同一棵 `memory/` 被两个版本的 spec 处理正是「客户端漂移」事故形态，四客户端必须**同时**升级 | `changeset-log.md` |
| `TestSetTrace` | 该轮**已通过准入**（`QAAdmissionStatus: Accepted`）的测试集那一行原文（格式见 `plaud-theme-qa-intake/references/package-checklist.md` §3）\| `N/A(NotAccepted)`（该轮 `QAAdmissionStatus: Blocked`）\| `N/A(NoTestSet)` | `changeset-log.md`，**v0.2.2 新增列**，由 `plaud-theme-qa` 在写 log 时**原样抄自 `QAIntake` 工件**（列格式见 `plaud-theme-qa/references/evidence-and-invalidation.md`）—— 它是 `plaud-theme-qa-intake` 下一轮取 `PreviousAcceptedTestSetTrace` 的**首选权威来源**（取数路径①；日志不可得时走路径②的成对工件，见 `package-checklist.md` §3）。**旧日志不回填** |
| `VisualAcceptance` | `Pending` \| `Accepted` | 迁移状态文件 |
| 模块 / 模板迁移态 | `待办` \| `进行中` \| `已迁`（需 QA 背书，见 shared SKILL.md） | 模板/模块清单 |

`Invalidated` 在 `changeset-log.md` 里是**合法**取值（表示该 QA 结论已因代码变化失效）；它只是不允许出现在阶段契约块里。两套枚举互不通用。
