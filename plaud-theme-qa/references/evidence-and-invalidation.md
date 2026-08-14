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

## 2. QA 失效 — ChangeSetFingerprint

> QA 通过后代码再变，原 QA **自动失效**（handoff-schema §1.4）。

### 2.1 指纹算法在 shared，不在这里

`ChangeSetFingerprint` 的**唯一权威定义是 handoff-schema §2 里那段命令**。实现 skill 交工件时当场生成，QA 用**同一段命令**重算比对。

> 🔴 **照抄，不要自造变体。** 两边算的必须是同一个东西——改一个字符（换 hash 算法、加一个 `sort`、换 `--untracked-files` 取值）就永远对不上，QA 会把正常交付全判成失配。需要改进算法时改 shared，不要在本 skill 里分叉。

它覆盖：HEAD、工作树状态（含全部未跟踪文件）、tracked 内容 diff 的 hash、未跟踪文件逐个 `git hash-object` + 权限位。

### 2.2 算两次，写进 `FingerprintVerifiedAt`

| 时点 | 用途 |
|---|---|
| **Step 1（任何检查之前）** | 与上游 §4 工件里的 `ChangeSetFingerprint` 比对 → 决定 `ChangeSetIdMatched` |
| **所有检查完成后、写 changeset-log 之前** | 与 Step 1 比对 → 确认验证期间代码没变 |

`FingerprintVerifiedAt` 如实写两次的时点与值。只写"已核验" → 视为证据为空。

**`memory/` 已排除在指纹之外（v0.2.2）**：§2 的规范命令带 `-- . ':(exclude)memory/'`，所以写 `changeset-log.md` **不会**改变指纹。
> 这条以前是「靠顺序规避自失效」（先算指纹再写 log）——那只能让**同一轮**两次校验相等，任何**后续**重算（release-ops 复核、§1.4 失效判定）仍然失配。现在从根上排除了。
> **但顺序仍建议保持**（先算 Step 2、再写 log）：它让证据链的时间顺序与因果顺序一致，且不依赖「排除已生效」这个前提。

同理，QA 期间不要在仓库里留临时文件（tc-diff.js、tc-before.json 等一律放 scratchpad，见 `theme-check-gate.md` §5）——它们会进指纹，让 Step 2 无故失配。

### 2.3 两条补充门：指纹算不到的盲区

§2 的命令基于 `git status` / `git diff` / `git ls-files --others`，以下两类改动它**看不见**。QA 必须单独查，**命中后不得直接继续，必须按本节末尾的二选一处理**：

```bash
cd <theme-root>

# 门 1：assume-unchanged / skip-worktree —— 被标记文件的改动对 git 完全隐形
#       小写状态字母 = assume-unchanged，S = skip-worktree
git ls-files -v | grep -E '^[a-z] |^S '

# 门 2：submodule —— gitlink 指向的子模块内部变化不进指纹
#       只看 .gitmodules 不够：它可能本轮被删、或仓库残缺但索引里仍有 160000
[ -f .gitmodules ] && echo ".gitmodules 存在"
git ls-files -s | awk '$1=="160000"{print "gitlink: " $4}'
```

处理方式二选一，**没有第三种**：① 解除索引标志 / 对每个 submodule 递归取指纹并把结果并入 `Evidence`，此时可继续；② 做不到 → `ReadyForDelivery: No` + `BlockingGaps` 写明。**不得**当作"没问题"继续。

### 2.4 为什么不用 mtime

```
git checkout / 格式化工具 / 编辑器保存  → mtime 变了但内容没变（误判失效）
touch 之后又改回内容                    → 内容变了但 mtime 可能一致（漏判）
```

一律按内容判定，不看时间戳。

### 2.5 CRLF / clean filter

🔴 **自定义 clean filter 不是「注明一下」就行，它是 §2 的 fail-closed 门**（v0.2.2 第九轮更正：本节原文写「判定不受影响，注明即可」，与 canonical 直接相反，照它做会在指纹被绕过时继续 QA）。理由：clean filter 让**工作树字节变了而 git 语义不变**，`git diff` / `git status` 都看不见，指纹也就绑不住工作树。§2 的 `plaud_fingerprint` 会枚举 tracked 与未跟踪的 `.gitattributes`，加上 `$GIT_DIR/info/attributes` 与 `core.attributesFile`，任一挂了 `filter=` 即 `GITATTRIBUTES_CLEAN_FILTER` 停机——此时 QA **不得**自行放行，要求先移除该 filter 或改用别的取证方式。

`text=auto` / CRLF 是另一回事，仍按旧口径：它只影响 checkout 行尾，指纹判定不受影响，但 **baseline worktree 里同一文件可能被 checkout 成不同行尾**，会影响 theme check 的差集。`git check-attr text -- <files>` 显示有转换时，在 `ThemeCheckEvidence` 里注明。

### 2.6 已知限制（v0.1）：这是仓库状态指纹，不是纯内容指纹

handoff-schema §2 的规范命令里含 `git status --porcelain=v1`，它输出的 `XY` 两列同时反映**索引**与**工作树**状态。因此：

> **仅改变 staging 的 `git add` / `git reset` 也会改变指纹**，即使 `git diff HEAD` 的最终内容一字未变。
>
> 🔴 **`memory/` 是唯一的例外，而且例外只到 `commit` 为止**（v0.2.2 第九轮实测）：改 `memory/` 不变、`git add memory/` 不变、**`git commit` 变**（HEAD 在 payload 第一行）。所以"QA 写 changeset-log 不自失效"这个保证**只在日志不被提交时成立**。见 `handoff-schema.md` §2 的硬规则。

这是**保守型失效**——它只会把"其实没变"误判成"变了"，不会把"变了"误判成"没变"，所以不构成漏报。

处置规则：

- **QA 不得因为"我觉得内容没变"就绕过失配。** 失配即 `ChangeSetIdMatched: No`，停机要求上游重新生成。
- 想改成纯内容语义，**必须在 shared 里统一升级**，并同步全部 producer skill、QA、changeset-log 与 eval。**禁止任何单个 skill 自行变体**——producer 与 verifier 算的必须是同一个规范对象，局部分叉会把正常交付全判成失配。

---

### 2.7 失效后的处理

1. 把 changeset-log 中该行 `Status` 改为 `Invalidated`，`Note` 写失效原因。
2. 要求实现 skill 生成**新的** `ChangeSetId` + `ChangeSetFingerprint` + `BaseHeadSha`。
3. **整轮重跑**，不允许"只补验变动的那部分"——同族 bug 与传播链正是靠全量重跑抓到的，增量补验会系统性漏检。

---

## 3. `memory/changeset-log.md`

**项目侧文件，不随包分发**（写进包里会在下次 install 被整包覆盖）。位置由项目决定，通常是仓库根的 `memory/changeset-log.md`。

文件不存在时：按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表执行——**`changeset-log.md` 询问用户后可创建空日志**（它是本矩阵自己产生的记录，不存在"历史状态丢失"问题）。**不要凭空重建历史记录**（不得补写从没跑过的 QA 行）。

其余三个迁移状态文件（`模板清单.md` / `模块清单.md` / `全局已知偏差.md`）缺失是**默认停机**，且由 `plaud-theme-ux-migration` 处理，本 skill 不写它们。本节只引用 shared 的那张表，不自行规定；两边不一致时以 shared 为准。

### 格式

```markdown
# ChangeSet QA Log

| ChangeSetId | Path | QAProfilesRun | ReadyForDelivery | RunAt | ChangeSetFingerprint | Status | TestSetTrace | Note |
|---|---|---|---|---|---|---|---|---|
| CS-20260806-A03 | A | QA-A, QA-Global | Yes | 2026-08-06T14:22+08:00 | a1b2c3d4e5f6 | Valid | TESTSET-PLAUD@rev12; Added=[TC-118]; Updated=[]; Removed=[] | ThemeCheck 新增 0 |
| CS-20260806-C11 | C | QA-C, QA-Global | No  | 2026-08-06T16:05+08:00 | 9f8e7d6c5b4a | Valid | TESTSET-PLAUD@rev12; None(复用 TC-042/TC-043) | QA-C 首项 Failed：字号总览含 disabled 实例（**准入过了，所以 trace 照记**） |
| CS-20260804-B07 | B | QA-B, QA-Global | No  | 2026-08-04T09:12+08:00 | 7a6b5c4d3e2f | Valid | N/A(NotAccepted) | 提测材料不齐，QAAdmissionStatus: Blocked，零验证项执行 |
| CS-20260805-A01 | A | QA-A, QA-Global | Yes | 2026-08-05T11:40+08:00 | 4d3c2b1a0f9e | Invalidated | TESTSET-PLAUD@rev11; None(纯样式改动) | 2026-08-06 工作树再次变动，需新 ChangeSetId |
```

规则：

- **每次 QA 都追加一行**，包括 `ReadyForDelivery: No` 的和被豁免的——失败记录同样有追溯价值。
- `ChangeSetFingerprint` 取 handoff-schema §2 那段命令算出的 hash 的前 12 位（全长写进正文 `Evidence` / `FingerprintVerifiedAt`）。
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
- **本文件已排除在指纹之外**（v0.2.2）：§2 的规范命令带 `-- . ':(exclude)memory/'`，写 log 不会改变指纹。**排除范围只有 `memory/`，不许自造别的排除项**；`memory/` 因此成为指纹盲区，那里不得出现任何非记录类文件（核对命令见 `plaud-theme-shared/references/handoff-schema.md` §2 与 `plaud-theme-impact/SKILL.md` 停机点）。

---

## 4. 用户要求跳过验证（豁免）

用户明说"不用检查了直接发""我赶时间，跳过 QA"：

**仍不得输出 `ReadyForDelivery: Yes`。** 交付权的含义是"验证通过才能说可交付"；用户可以放弃验证，但不能让 QA 改口。

### 关键约束：`QAStatus` 不进 §5 yaml 块

handoff-schema 开头明令「任何 skill 都不得自行定义字段、改字段名、或新增终态词汇」，且 §5 的字段表里**没有** `QAStatus`——它只出现在 §4（实现 skill 的工件）。所以：

- **§5 yaml 块保持纯净**，只含 §5 定义的 26 个字段，一个不多、一个不少（含 `SubmissionId` / `QAAdmissionStatus` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` / `Advisories`）。

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
> | `ReadyForDelivery` | `No` | `No` |
>
> 两者唯一相同的是 `ReadyForDelivery: No`。**弃材料 ≠ 弃验证**：绑定是有效的，验证本身仍有意义，只是不产生许可。

正文形态（**弃 QA**）：

```
已按用户要求跳过验证（QAStatus: Skipped(UserWaived)）；未经验证的改动上线风险由用户承担。
```

对应的 §5 块（**弃 QA** 那一种；弃材料时按上表逐字段改，尤其检查项要填实际结果）：

```yaml
ChangeSetId: <上游给的，没有就写 Unknown>
SubmissionId: <引用提测包；材料确实没交时写 N/A(UserWaivedMaterials)>
QAAdmissionStatus: <Accepted 若材料齐 | Blocked 若材料不全>   # 弃 QA 不等于材料不全
QAAdmissionReason: <Normal 若材料齐 | PackageIncomplete 若不全>
ChangeSetIdMatched: <Yes | No —— 封闭枚举只有这两个值；未校验时填 No，理由进 BlockingGaps>
FingerprintVerifiedAt: 未执行（用户豁免，Step1/Step2 均未重算）
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
| "我只是 git add 了一下，代码没变" | 有可能——指纹是仓库状态指纹，不是纯内容指纹（见 §2.6）。但失配就是失配：QA 不得自行放行，要求上游重新生成 |
| "基本都过了" | 无中间态。任一 gate 字段非 `Passed`/`NotApplicable` → `ReadyForDelivery: No` |
