# 证据规则、QA 失效、changeset-log、用户豁免

---

## 1. 证据的最低形态

`Evidence` 字段不是叙述，是**可复核的取证记录**。每条至少含：检查项名 + 取证手段 + 结果。

| 取证手段 | 最低形态 | 反例（判 `Blocked`） |
|---|---|---|
| 命令 | 命令原文 + 输出摘要（含数字） | "跑了 theme check，没问题" |
| 代码阅读 | `文件:行号` + 该行内容或结论 | "看过 JS 了，清理没问题" |
| 视觉 / 运行时 | 页面 + 断点 + 观察到的现象 | "各断点都正常" |
| 上游引用 | 引用哪个工件的哪个字段 + 本次**复算**结果 | "按 Assess 说的" |

**三条硬规则：**

1. `Evidence` 里没有对应条目的检查项，无论标了什么值，一律降级为 `Blocked`。
2. `Passed` 需要正面证据；`NotApplicable` 需要"为什么不适用"的一句话；`Blocked` 需要"缺什么"。三者都不能空着。
3. **不允许把一句总结覆盖多项。** "已按 vendor §8–§11 检查" 不构成四项证据；每项各自成条。

### 允许的证据压缩

同一 grep 命中大量结果时，可写「命令原文 + 命中数 + 逐条裁定表（只列需裁定的）」，不必粘贴全量输出。但**命令原文与命中总数不能省**——它们是复核的入口。

---

## 2. QA 失效 — 身份三元组（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`）

> QA 通过后可发布内容再变，原 QA **自动失效**（handoff-schema §2.8）。

### 2.1 取证函数在 shared，不在这里

三个身份字段的**唯一权威定义是 handoff-schema §2.5 里那几个函数**：

| 函数 | 产出 | 用在哪 |
|---|---|---|
| `plaud_theme_tree` | `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest> [<objdir>]` | 实现 skill 交付、QA Step 1 / Stage / Step 5、零改动 `ReadOnlyProof` |
| `plaud_changeset_scope <pathlist>` | `<ObjectFormat> <ScopeTreeOid> <ScopeDigest>` | 实现 skill 交付、QA Step 1 |
| `plaud_declared_diff <base> <pathlist>` | `<ObjectFormat> <BaseTreeOid> <ThemeTreeOid> DECLARED_DIFF_OK` | QA 的 `DeclaredDiffCheck` |
| `plaud_stage_workspace <空目录>` | `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>` | QA 的 `StageDirRef` —— **所有检查在这里跑** |
| `plaud_stage_verified <空目录>` | 同上 | **只**归 release 推站用，QA 不用 |

> 🔴 **原样复制，不要凭记忆敲、不要删注释、不要自造变体。** 两边算的必须是同一个东西——改一个字符（换 hash、加一个 `sort`、换 pathspec）就永远对不上，QA 会把正常交付全判成失配。更严重的是漏掉 `-c core.hooksPath=/dev/null`：`git add` 会触发 hook，那等于在取证时执行仓库里的任意脚本。需要改进算法时改 shared，不要在本 skill 里分叉。

`ThemeTreeOid` 覆盖的是**可发布面**：`assets blocks config layout locales sections snippets templates` + 仓库根 `.shopifyignore`。`ChangeSetScopeFingerprint` 只覆盖本 ChangeSet 的**声明路径**（形态是 `<ScopeTreeOid> <ScopeDigest>` 两段，删除只体现在第二段的 `absent` 行，**必须两段一起比**）。
`ThemeTreeDigest` **不进任何工件**：它只用于人读 diff 与跨 object-format 防误判，**不提供抗碰撞**。

### 2.2 算三次，写进 `FingerprintVerifiedAt`

| 时点 | 用途 |
|---|---|
| **Step 1（物化前，任何检查之前）** | 与上游 §4 工件（或 `IntegrationOf.Members[]`）比对 → 决定 `ChangeSetIdMatched` |
| **Stage（物化回环复算）** | `plaud_stage_workspace` 在快照里重算 → 确认快照就是被验证的那棵树 |
| **Step 5（所有检查完成后、写 changeset-log 之前）** | 与前两次比对 → 确认验证期间可发布内容没变 |

`FingerprintVerifiedAt` 如实写三次的时点与值。只写"已核验" → 视为证据为空。

**`memory/` 不在可发布面内**，所以写 `changeset-log.md` 天然不会改变 `ThemeTreeOid`（语义从 v0.2.x 的「排除项」变成 v0.3.0 的「范围外」）。
> **顺序仍建议保持**（先算 Step 5、再写 log）：它让证据链的时间顺序与因果顺序一致。

📎 **QA 期间在仓库里留临时文件（`tc-diff.js` / `tc-before.json` 等）v0.3.0 起不再造成假失效** —— 它们不在可发布面。但仍**一律放 scratchpad**（见 `theme-check-gate.md` §5）：不该往用户仓库里写东西，这条与指纹无关。

### 2.3 两类盲区现在由取证函数自动挡（QA 不再手查）

| 旧的补充门 | 现在 |
|---|---|
| 索引标志门（`assume-unchanged` / `skip-worktree`）📎 **v0.3.0 起解除** | **已退役**。新模型用的是**空白临时索引**，用户 index 上的标志不生效 —— 实测两种标志下改内容仍判 CHANGED。手查它只会给出一个不再成立的停机理由 |
| submodule gitlink | 由 `GITLINK_IN_THEME_TREE` / `GITLINK_IN_SCOPE` **自动 fail closed**。命中即停机，**不存在**"递归取子模块指纹后继续"这条路 |

📎 **同族退役的还有三个，v0.3.0 起解除**（洞被构造性堵上，逐条实测）：`IGNORED_PUBLISHABLE_FILE`（`git add -A -f` 让 ignored 的可发布文件直接进树）、`PATH_CASE_MISMATCH`（空白索引从磁盘重扫，记的就是磁盘上的名字）、`UNTRACKED_COUNT_MISMATCH` / `UNHASHABLE_UNTRACKED_DIR`（`git add -A` 自己枚举，不再有手写的未跟踪文件循环）。

### 2.4 为什么不用 mtime

```
git checkout / 格式化工具 / 编辑器保存  → mtime 变了但内容没变（误判失效）
touch 之后又改回内容                    → 内容变了但 mtime 可能一致（漏判）
```

一律按内容判定，不看时间戳。

### 2.5 字节保真门：CRLF / clean filter / fileMode / symlink

🔴 **这一族全是 fail-closed 门，不是「注明一下」就行。** 理由只有一条：**tree 记的是 blob 字节，而 Shopify push 推的是工作树字节**——任何让两者不等的机制都会让 `ThemeTreeOid` 绑不住实际上线的内容。

| 门 | 触发条件 |
|---|---|
| `BYTE_FIDELITY_ATTR` | 任一待判路径的**生效属性**里有 `filter` / `text` / `eol` / `crlf` / `ident` / `working-tree-encoding` / `export-ignore` / `export-subst` |
| `BYTE_FIDELITY_AUTOCRLF` | `core.autocrlf` 归一为真（含 `yes` / `on` / `1` / `input`、大小写变体，以及**没有等号的裸键**），或取值不认识 |
| `CORE_FILEMODE_FALSE` | `core.fileMode` 的**布尔归一值**为 `false`（注意：裸键 `fileMode` 归一为 **true**，而 `core.fileMode=`（有等号、值为空）归一为 **false**，两者 `--get` 下都是空串） |
| `SYMLINK_IN_*` / `GITLINK_IN_*` | 可发布面 / 声明范围里存在 symlink（**已跟踪的也算**）或嵌套 git 仓库 |
| `NEWLINE_IN_PATH*` | 待判路径或 tree 条目里含换行（技术上能算，但 POSIX shell 里做不出可靠的 `git check-attr -z` 三元组解析器，**所以不装这个能力**） |
| `GIT_TOO_OLD` / `OBJECT_FORMAT_UNKNOWN` / `OID_LENGTH_MISMATCH` / `NOT_REPO_ROOT` / `NO_THEME_DIRS` / `EMPTY_THEME_TREE` | 环境或仓库形态不满足前提 |

命中任一条 → 取证不可用，身份与归属检查**全部 `Blocked` + 停机**。QA **不得**自行放行，也不得"先跑起来再说"：要求先移除该机制（或换一台满足前提的机器）再重新取证。

🔴 **`text=auto` / CRLF 的旧口径「判定不受影响，注明即可」已删除。** 那是 v0.2.x 的写法，在新模型里直接相反：`core.autocrlf` 与 `.gitattributes` 的 `text` / `eol` 属于同一族，都会让 tree 字节 ≠ 工作树字节，**是 fail-closed 门，不是注记项**。

📎 **属性门的实现方式也变了**：v0.2.x 是**扫 `.gitattributes` 文件**去 grep `filter=`；v0.3.0 是对**每条待判路径问 `git check-attr` 生效属性**。两个直接后果：堵上了「被 gitignore 的 `.gitattributes`」「`.git/info/attributes`」「`core.attributesFile`」三条绕过路径（实测都能绕过旧门）；同时不再误停机——filter 只作用于**非可发布目录**（`tools/` 之类）时，问生效属性的写法不会命中。

### 2.6 这是**可发布内容**指纹

`ThemeTreeOid` 绑的是「当前可发布内容写成的那个不可变 tree 对象」，不是仓库状态文本。因此：

| v0.2.x 的老问题 | v0.3.0 |
|---|---|
| `git add` / `git reset`（内容不变）→ 指纹变、QA 失效 | **解开**，逐字不变 |
| `git commit memory/` → 失效（HEAD 在 payload 第一行） | **解开**，逐字不变 |
| 主题改动 commit（内容一字未改）→ 失效 | **解开**，且 oid 与 commit 的子树相同 |
| 仓库根 scratch 临时文件（`tc-diff.js` / `node_modules` / `.env`）→ 失效 | **解开**（不在可发布面） |
| `.gitattributes` 被 gitignore 时绕过 clean filter 门 | **解开**（改问 `git check-attr` 生效属性） |
| 纯大小写改名判不出来 | **解开**（空白索引从磁盘重扫） |
| clean filter / `text` / `ident` / `working-tree-encoding` | **仍在**，fail closed（§2.5） |
| `core.fileMode` 假值 / symlink / 嵌套 git 仓库 / 路径含换行 | **仍在**，fail closed |
| Windows | **不支持取证**（典型 git 配置直接命中两道字节保真门） |

**新的边界是字节保真门，不是"仓库状态"。** 两条必须一起记住的界线：

- **可发布面之外的改动不改变 `ThemeTreeOid`，但会改变 QA / build 结果。** build 源、`.theme-check.yml`、lockfile 都在归属核对之外——所以 QA 在 workspace 快照（`plaud_stage_workspace`）里跑，而不是在只含可发布面的目录里跑。
- **`DeclaredDiffCheck` 判的是可发布路径集合，不是逐项四元组。** 「路径没变但 mode / 内容变了」由 `ChangeSetScopeFingerprint` 承担，两者分工，不重复。

处置规则：

- **QA 不得因为"我觉得内容没变"就绕过失配。** 失配即 `ChangeSetIdMatched: No`，停机要求上游重新生成。
- 想改算法**必须在 shared 里统一升级**，并同步全部 producer skill、QA、changeset-log 与 eval。**禁止任何单个 skill 自行变体**——producer 与 verifier 算的必须是同一个规范对象，局部分叉会把正常交付全判成失配。

---

### 2.7 失效后的处理

1. 把 changeset-log 中该行 `Status` 改为 `Invalidated`，`Note` 写失效原因。
2. 要求实现 skill 生成**新的** `ChangeSetId` + 三个身份字段（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`）。`BaseHeadSha` 照旧必填、必须可解析，但它**不是**失效判据。
3. **整轮重跑**，不允许"只补验变动的那部分"——同族 bug 与传播链正是靠全量重跑抓到的，增量补验会系统性漏检。

📎 **不算失效的四类**（§2.6 上表左列的前四行），不得据此判 `Invalidated`。
🔴 **算失效、且不能降级成 `Advisories` 的一类**：`ThemeTreeOid` 变了而本块 `ChangeSetScopeFingerprint` 没变 —— 那是别的块的改动落进了同一棵树。按 §2.12 这不是"正常的并行现象"，而是这棵树已经变成 A+B，本轮只能改按 `QAScope: Integration` 处理（`DeclaredDiffCheck` 也会把它判成 `DECLARED_DIFF_ORPHAN`）。

---

## 3. `memory/changeset-log.md`

**项目侧文件，不随包分发**（写进包里会在下次 install 被整包覆盖）。位置由项目决定，通常是仓库根的 `memory/changeset-log.md`。

文件不存在时：按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表执行——**`changeset-log.md` 询问用户后可创建空日志**（它是本矩阵自己产生的记录，不存在"历史状态丢失"问题）。**不要凭空重建历史记录**（不得补写从没跑过的 QA 行）。

其余三个迁移状态文件（`模板清单.md` / `模块清单.md` / `全局已知偏差.md`）缺失是**默认停机**，且由 `plaud-theme-ux-migration` 处理，本 skill 不写它们。本节只引用 shared 的那张表，不自行规定；两边不一致时以 shared 为准。

### 格式

```markdown
# ChangeSet QA Log

| ChangeSetId | Path | QAProfilesRun | ReadyForDelivery | RunAt | ObjectFormat | ThemeTreeOid | ScopeFP | Status | TestSetTrace | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| CS-20260806-A03 | A | QA-A, QA-Global | Yes | 2026-08-06T14:22+08:00 | sha1 | a1b2c3d4e5f6 | 5e4d3c2b1a09 | Valid | TESTSET-PLAUD@rev12; Added=[TC-118]; Updated=[]; Removed=[] | ThemeCheck 新增 0（VER-20260806-01） |
| CS-20260806-C11 | C | QA-C, QA-Global | No  | 2026-08-06T16:05+08:00 | sha1 | 9f8e7d6c5b4a | 1a2b3c4d5e6f | Valid | TESTSET-PLAUD@rev12; None(复用 TC-042/TC-043) | QA-C 首项 Failed：字号总览含 disabled 实例（**准入过了，所以 trace 照记**） |
| N/A(Integration) | A+C | QA-A, QA-C, QA-Global | Yes | 2026-08-06T18:30+08:00 | sha1 | c3d4e5f60718 | N/A(Integration) | Valid | TESTSET-PLAUD@rev12; Added=[TC-119]; Updated=[]; Removed=[] | 集成 QA（VER-20260806-03），Members=CS-20260806-A03, CS-20260806-C11 |
| CS-20260804-B07 | B | QA-B, QA-Global | No  | 2026-08-04T09:12+08:00 | sha1 | 7a6b5c4d3e2f | 0f1e2d3c4b5a | Valid | N/A(NotAccepted) | 提测材料不齐，QAAdmissionStatus: Blocked，零验证项执行 |
```

规则：

- **每次 QA 都追加一行**，包括 `ReadyForDelivery: No` 的和被豁免的——失败记录同样有追溯价值。
- `ObjectFormat` 原样记（`sha1` / `sha256`）；`ThemeTreeOid` 记前 12 位；`ScopeFP` 记 `ChangeSetScopeFingerprint` 的 `ScopeTreeOid` 前 12 位。**全长一律写进正文 `Evidence` / `FingerprintVerifiedAt`**——12 位只是给人扫的。
- 📎 **这几列 v0.3.0 新增，取代 v0.2.3 的 `ChangeSetFingerprint` 一列。旧行不回填**（回填等于编造历史）：v0.2.3 及以前的行保留原列并按旧语义阅读，新行一律用新列。🔴 同一棵 `memory/` 被两个版本的 spec 处理正是「客户端漂移」事故形态——四个客户端必须**同时**升级到 v0.3.0。
- 🔴 **没有 `VerificationId` 列，也没有 `ReadyForIntegration` 列。** 📎 §9.2 的 `memory/` 记录字段枚举只授权了「把 v0.2.3 的 `ChangeSetFingerprint` 一列换成 `ObjectFormat` + `ThemeTreeOid` + `ScopeFP`」，**本 skill 不自行给日志加列**——加列要先在 shared 里定义（连同 `VER-<NN>` 的并发安全分配方式），否则同一棵 `memory/` 又会出现两版 spec。
  需要人读追溯时把 `VER-…` 写进 `Note` 列（`Note` **不被下游消费**，只是给人看的）；机器追溯走 `plaud-theme-release-ops` 的 `ReleaseQARef` / `ReleaseScope[].QARef` → QA 工件本身，不查日志。
- 集成 QA 的行 `ChangeSetId` 填 `N/A(Integration)`，`ScopeFP` 列填 `N/A(Integration)`（逐块取值在工件的 `IntegrationOf` 里）。
- `Status` ∈ `Pending` / `Valid` / `Invalidated`（`handoff-schema.md` §9.2 的 **`memory/` 记录字段**枚举，对应那里的 `QAStatus`）。只追加与改 `Status`，**不删除历史行**。
- **`TestSetTrace` 列（v0.2.2 新增）**：只要本轮 **`QAAdmissionStatus: Accepted`**（= 提测包过了准入），就把提测包里那一行**原样抄进去**（来自 `QAIntake` 工件，QA 不重编、不规整、不补全），**与 `ReadyForDelivery` 是 `Yes` 还是 `No` 无关**。
  - `QAAdmissionStatus: Blocked`（材料不齐 / 绑定失配 / 用户弃材料）→ 写 `N/A(NotAccepted)`；该轮确实没有测试集 → `N/A(NoTestSet)`。
  - 🔴 **锚点是"最近一次准入通过"，不是"最近一次交付通过"。** 下一轮 `PreviousAcceptedTestSetTrace` 取的是**最近一条 `TestSetTrace` 非 `N/A` 的行**。这样 QA 失败的返工轮次也留下了测试集版本，测试集的连续性不会因为一轮 `ReadyForDelivery: No` 就断链——那正是返工轮次最容易换文档的时候。
  - **换了新测试文档的那一轮**：`TestSetTrace` 列照抄本轮那一行（已是**新**文档 ID），因此下一轮取到的自然是新 ID，链不断。`TestSetMigrationRef` **不入日志列**；可在 `Note` 列写 `Migrated(<旧ID> -> <新ID>)` 作**人读备注**——🔴 `Note` 列**不被 `plaud-theme-qa-intake` 消费**，不得声称"靠它让下一轮取到新 ID"。要机器审计迁移，查那一轮的 `QAIntake` 工件（`TestSetMigrationRef` 与它指向的清单已被 `PackageFingerprint` 绑定）。
  🔴 **这一列存在的唯一目的**：下一轮 `plaud-theme-qa-intake` 取 `PreviousAcceptedTestSetTrace` 时有个权威来源可查（`plaud-theme-qa-intake/references/package-checklist.md` §3 的取数路径①）。不写这一列，"测试集随交付增量维护"就退回不可查。
  ⚠️ **旧日志兼容**：v0.2.2 之前的行没有这一列，**不要回填**（回填等于编造历史）。下一轮命中「取不到」时按取数路径③走 `Unavailable(...)` + `Advisories`。
  - `Pending` — 已登记但结论尚未落定（例如等补证据）
  - `Valid` — 该行的 QA 结论当前仍有效（指纹未失效）
  - `Invalidated` — 代码已再次变化，该 QA 结论失效
- 🔴 **这三个取值是 `memory/` 记录字段的合法枚举，但绝不允许出现在 §5 的阶段契约 yaml 块里。** §9.2 明文分两套：阶段契约字段的 `QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`（且 §5 的块里**根本没有** `QAStatus` 字段），`Invalidated` / `Valid` / `Pending` 只活在 `changeset-log.md`。往契约块塞 `Invalidated` 是自造取值，违反契约首条。
- 一个 `ChangeSetId` 重跑 → 新增一行，旧行标 `Invalidated`，不覆盖。
- **本文件不在可发布面内**（可发布面 = `assets blocks config layout locales sections snippets templates` + 仓库根 `.shopifyignore`），所以写 log 不会改变 `ThemeTreeOid`。语义是「范围外」而不是「排除项」：`memory/` 里的东西**不会上线**，所以也不需要被身份绑住；反过来，如果 `memory/` 里出现了本该上线的东西，那说明**目录放错了**（核对命令见 `plaud-theme-impact/SKILL.md` 的停机点）。

---

## 4. 用户要求跳过验证（豁免）

用户明说"不用检查了直接发""我赶时间，跳过 QA"：

**仍不得输出 `ReadyForDelivery: Yes`。** 交付权的含义是"验证通过才能说可交付"；用户可以放弃验证，但不能让 QA 改口。

### 关键约束：`QAStatus` 不进 §5 yaml 块

handoff-schema 开头明令「任何 skill 都不得自行定义字段、改字段名、或新增终态词汇」，且 §5 的字段表里**没有** `QAStatus`——它只出现在 §4（实现 skill 的工件）。所以：

- **§5 yaml 块保持纯净**，只含 §5 定义的 **35 个字段**，一个不多、一个不少（含 `VerificationId` / `QAScope` / `IntegrationOf` / `SubmissionId` / `QAAdmissionStatus` / `ObjectFormat` / `VerifiedThemeTreeOid` / `DiffBaseTreeOid` / `DeclaredDiffCheck` / `StageDirRef` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` / `Advisories` / `ReadyForIntegration`）。

> ⚠️ **区分两种「用户豁免」**，输出不一样：
>
> | 用户说的 | `QAAdmissionStatus` | 检查项 | 正文 |
> |---|---|---|---|
> | "不用检查了直接发"（弃 **QA**） | 按提测包实际情况填 | 全部 `Blocked` | 说明已跳过验证，风险由用户承担 |
> | "这次不准备提测材料"（弃 **材料**） | `Blocked` | **照常执行并填实际结果** | 说明已跳过提测材料校验 |
>
> 两者的 `ReadyForDelivery` 都恒为 `No`。
- `QAStatus: Skipped(UserWaived)` 写在**正文**里（handoff-schema §1 条款 5 的措辞），不写进 yaml 块。
- 豁免事实同时体现在 §5 的既有字段中：`QAProfilesRun: None`、各检查项 `Blocked`、`Evidence: 无 —— 用户要求跳过验证`、`BlockingGaps: 全部验证项未执行（UserWaived）`。

> 🔴 **下面给的是「弃 QA」那一种的模板。两种豁免的字段取值不同，不要拿一个套另一个**（v0.2.2 补——此前只有一份模板，固定写成 `UserWaivedMaterials` + 全部 `Blocked`，既表达不了"提测包 Accepted、用户弃 QA"，又会把"弃材料后照跑的技术检查结果"覆盖掉）：
>
> | | 弃 **QA**（"不用检查了直接发"） | 弃 **材料**（"这次不准备提测材料"） |
> |---|---|---|
> | `QAAdmissionStatus` | 按提测包实际情况填（材料齐就是 `Accepted`） | `Blocked` |
> | `QAAdmissionReason` | 材料齐 → `Normal`；材料也不全 → `PackageIncomplete` | `UserWaivedMaterials` |
> | 十一个检查项 | 全部 `Blocked` | **照常执行、填实际结果**（`Passed`/`Failed`/…） |
> | `QAProfilesRun` | `None` | 实际跑过的 profile |
> | `FingerprintVerifiedAt` | `未执行（用户豁免…）` | **照常两次重算并如实写** |
> | `Evidence` | `无 —— 用户要求跳过验证` | 照常写命令原文与输出摘要 |
> | `BlockingGaps` | `全部验证项未执行（UserWaived）` | `用户弃提测流程，未经完整交付流程` |
> | `DeclaredDiffCheck` / `StageDirRef` | `Blocked` / 未物化 | **照常跑**（绑定有效，归属核对与物化都仍有意义） |
> | `ReadyForIntegration` | `No` | `No` |
> | `ReadyForDelivery` | `No` | `No` |
>
> 两者唯一相同的是 `ReadyForDelivery: No`。**弃材料 ≠ 弃验证**：绑定是有效的，验证本身仍有意义，只是不产生许可。

正文形态（**弃 QA**）：

```
已按用户要求跳过验证（QAStatus: Skipped(UserWaived)）；未经验证的改动上线风险由用户承担。
```

对应的 §5 块（**弃 QA** 那一种；弃材料时按上表逐字段改，尤其检查项要填实际结果）：

```yaml
VerificationId: VER-<YYYYMMDD>-<NN>
QAScope: <SingleChangeSet | Integration>
ChangeSetId: <上游给的，没有就写 Unknown>
IntegrationOf: <N/A（SingleChangeSet）| 映射（Integration）>
SubmissionId: <引用提测包；材料确实没交时写 N/A(UserWaivedMaterials)>
QAAdmissionStatus: <Accepted 若材料齐 | Blocked 若材料不全>   # 弃 QA 不等于材料不全
QAAdmissionReason: <Normal 若材料齐 | PackageIncomplete 若不全>
ObjectFormat: <sha1 | sha256；连取证都没跑时写 Unavailable(用户豁免) 并在 BlockingGaps 说明>
ChangeSetIdMatched: <Yes | No —— 封闭枚举只有这两个值；未校验时填 No，理由进 BlockingGaps>
VerifiedThemeTreeOid: <本轮验的 oid；未取证时写 Unavailable(用户豁免)>
DiffBaseTreeOid: Unavailable(用户豁免，未跑 plaud_declared_diff)
DeclaredDiffCheck: Blocked        # 未执行 → Blocked，绝不填 Passed / NotApplicable
StageDirRef: 未物化（用户豁免）
FingerprintVerifiedAt: 未执行（用户豁免，Step1/Stage/Step5 均未重算）
QAProfilesRun: None
ThemeCheck: Blocked
ThemeCheckEvidence: 用户豁免，未执行
ThemeRuntimePreview: Blocked
AdminSchemaSave: Blocked
RegressionMatrix: Blocked
BreakpointsCovered: None
LocalizationCheck: Blocked
A11yCheck: Blocked
FixedDimensionCheck: Blocked        # 未执行 → Blocked（四值均合法，见下）
ImageQualityCheck: Blocked          # 同上
CopyConfigurabilityCheck: Blocked   # 同上
StyleHardRuleCheck: Blocked         # 同上
ApprovedExceptionsChecked: Blocked  # 未读上游工件 → Blocked，不是 NotApplicable
ApprovedExceptionsEvidence: 无 —— 用户豁免，未核
ProfileSpecificResults: 全部 Blocked（用户豁免，未执行）
Advisories: 无
Evidence: 无 —— 用户要求跳过验证
BlockingGaps: 全部验证项未执行（UserWaived）
ReadyForIntegration: No
ReadyForDelivery: No
```

> ⚠️ **`ChangeSetIdMatched` 没有 `Blocked`。** §9.2 的封闭枚举只有 `Yes` / `No`。校验没跑或跑不了一律填 `No`（"未确认匹配"就是"不匹配"，保守方向），原因写进 `BlockingGaps`。往这个字段塞 `Blocked` 是自造取值。

> 🟢 **三项枚举已收口（v0.2.0）。**
>
> `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 曾被记录为「handoff-schema §5 与 §9.2 规定不一致」。**复核结论：§9.2 枚举表这三项本来就含 `Blocked`**，两处一致，所谓缺口不存在——这条提示自 v0.1.0 起就是过时描述，v0.2.0 予以删除。
>
> 现行规定：四值 `Passed` / `Failed` / `Blocked` / `NotApplicable` 全部合法，不必再在 `BlockingGaps` 登记契约歧义。
>
> **三条不得越界的红线不变：**
> 1. **绝不**把未执行改填 `NotApplicable` —— 伪装成"不需要验"，是最直接的绕过交付门方式。
> 2. **绝不**改填 `Passed`。
> 3. **绝不**改填 `Failed` —— `Failed` 的语义是"验了且发现缺陷"。把未执行写成 `Failed` 会让实现 skill 去追一个不存在的缺陷。
>
> 未执行一律 `Blocked` + 原因。无论取哪个值，`ReadyForDelivery` 恒为 `No`。

不劝说、不重复、不列举"你可能会遇到的 12 种问题"。用户已经做了决定，QA 的职责是留下准确记录，不是说服。

changeset-log 照常追加一行，`ReadyForDelivery` 填 `No`，`Note` 写 `UserWaived`。

### 部分豁免

用户说"theme check 就别跑了，其它照跑"：被豁免项标 `Blocked`（原因写"用户豁免"），其余照常执行。因为有 `Blocked`，`ReadyForDelivery` 仍是 `No`。**没有"除了 X 项之外全部通过所以算通过"这种折算。**

---

## 5. 常见规避话术与对应判定

| 话术 | 正确判定 |
|---|---|
| "代码逻辑上看没问题" | 不是证据。相应项 `Blocked` |
| "这个改动很小，不用跑 theme check" | `ThemeCheckRequired` 由文件类型决定，不由改动大小决定 |
| "本地跑不了预览，但静态检查过了" | `ThemeRuntimePreview: Blocked`，不得用 `ThemeCheck` 顶替 |
| "5 个断点里有两个看着一样，看一个就行" | `BreakpointsCovered` 必须五档齐；少一档 → `RegressionMatrix: Blocked` |
| "德语测试上次做过了" | 上次不是本 ChangeSet。本轮未做 → `Blocked` |
| "只有 warning，没有 error" | 本次新增的 offense 不分 severity，一律 `Failed` |
| "顺手把另一个 bug 也修了" | ChangeSet 失配 → Step 1 停机，要求重新生成 |
| "这条 offense 原来就有" | 要给出 baseline 里的对应条目（check + message + 行号）才成立，见 `theme-check-gate.md` §6 |
| "删的那个文件没人用" | 要给出 §7 的全仓 basename 扫描原文 + 运行时预览结论 |
| "我只是 git add 了一下，代码没变" | 📎 v0.3.0 起 `git add` / `git reset` 确实不再改变身份（§2.6 实测）。但**失配就是失配**：真的对不上说明动的是可发布内容，QA 不得自行放行，要求上游重新生成 |
| "别的块的改动落进来了，但我这块的 ScopeFP 没变，可以继续" | 不行。`ThemeTreeOid` 变了这棵树就是 A+B，按 §2.12 只能改走 `QAScope: Integration`，不是记个 `Advisories` 继续 |
| "基准 commit 找不到了，DeclaredDiffCheck 就当不适用吧" | `NotApplicable` **不适用于任何有改动的 ChangeSet**。基准不可解析一律 `Blocked`，本轮拿不到交付许可 |
| "QA 就在工作树里跑吧，反正刚算过指纹" | 不行。算完到逐文件读取之间工作树还能再变（TOCTOU）。必须 `plaud_stage_workspace` 物化后在 `StageDirRef` 里跑 |
| "集成就用最后那一块的 QA 结论吧" | 不行。集成 QA 是**独立工件**（自己的 `VerificationId` + `ChangeSetId: N/A(Integration)` + 非空 `IntegrationOf`），不得复用任何一块的 |
| "基本都过了" | 无中间态。任一 gate 字段非 `Passed`/`NotApplicable` → `ReadyForDelivery: No` |
