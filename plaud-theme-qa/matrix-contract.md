# plaud-theme-qa — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准。本文件只描述本 skill 在矩阵中的接线，不重复定义字段。

## 位置

| 项 | 值 |
|---|---|
| order | 7 |
| 阶段 | **Verify**（阶段轴终点） |
| 路径 | A / B / C 全部经过本 skill |
| 唯一性 | **矩阵中唯一有权输出 `ReadyForDelivery: Yes` 的 skill** |

阶段单向推进 `Assess → Implement → Verify`。**任何有改动的任务都不得跳过 Verify**（`InlineLite` 只豁免 Assess，不豁免 Verify）。零改动只读任务不进本 skill，见下方入口前置门。

## 上游（ProducerSkill）

| 上游 | 路径 | 消费的字段（handoff-schema §4） |
|---|---|---|
| `plaud-theme-dev` | A | `ChangeSetId` `BaseHeadSha` **`ObjectFormat`** **`ThemeTreeOid`** **`ChangeSetScopeFingerprint`** `ReadOnlyProof` `AssessmentRef` **`OriginTriageRef`** `Path` `ReconMode` `ModifiedFiles` `RootCause` `OptionsConsidered` `RequiredQAProfile` `ThemeCheckRequired` `VisualRegressionRequired` `BuildRequired` **`ApprovedExceptions`** `BlockingGaps` `QAStatus` `NextRequiredSkill` `ReadyForDelivery`（§4 的 **22** 个字段全量；Step 1 的结构核就是按这 22 个逐个点，少列一个就等于结构核漏一个。📎 v0.2.3 的 `ChangeSetFingerprint` 已废止，换成 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` 三元组；`BaseHeadSha` 仍必填、必须可解析，但**不再是失配判据**——它是 `DeclaredDiffCheck` 与 theme check baseline 的基准锚点） |
| `plaud-theme-section-build` | B | 同上（`RootCause` 为 `N/A`） |
| `plaud-theme-ux-migration` | C | 同上 |
| `plaud-theme-impact`（间接） | A/B/C | §3 的 `AssessmentRef` `ActualAffectedInstances` `SharedPropagation` `EvidenceCommands` `RequiredQAProfile` —— QA 复算而非照抄 |
| `plaud-theme-orchestrator` | 全流程 | 调度本 skill，并接收 §5 结果做阶段门。**集成 QA 另消费 §9.1 协调工件的 `IntegrationPlan`**：`Integrator`（人，矩阵不做 merge）/ `IntegrationBaseCommit`（`DeclaredDiffCheck` 的基准，必须可解析）/ `IntegrationBaseTreeOid`（与 `IntegrationOf.BaseTreeOid`、本工件 `DiffBaseTreeOid` 三者逐字相等）/ `MemberChangeSets`（与 `IntegrationOf.Members` 集合相等且无重复）。**拿不到 `IntegrationPlan` 就不做集成 QA**——回 orchestrator 要，不得自拟 |
| **`plaud-theme-qa-intake`** | A/B/C | §9.1.2 的 `SubmissionId` `SubmissionPackageStatus` `PreviewManifest` `TargetSites` `ThemeIds` **`ChangeSetId`** **`ObjectFormat`** **`ThemeTreeOid`** **`ChangeSetScopeFingerprint`**（Step 0 与 Implement 工件逐字比对，防重放：对不上就是别的任务的提测包；集成提测包的顶层 `ChangeSetScopeFingerprint` 是 `N/A(Integration)`，逐块取值在 `IntegrationOf` 里）**`IntegrationOf`**（集成提测包的成员清单 + 逐块 `SubmissionId`，与 `IntegrationPlan.MemberChangeSets` 集合相等且无重复）**`PackageRootRef`** **`PackageFingerprint`**（据此复算材料指纹，防准入后替换）**`BlockingGaps`**（Incomplete 时原样带出）**`TestSetTrace`**（本轮那一行，Step 5 原样抄进 `changeset-log.md`，也是核 `TestSetMigrationRef.To` 的对照物）**`PreviousAcceptedTestSetTrace`**（跨轮测试集连续性，取不到时记 `Advisories` 不判 Incomplete）**`TestSetMigrationRef`**（换测试文档时的结构化迁移声明；Step 0 逐字核 `From` = `PreviousAcceptedTestSetTrace` 的 `ID@revision` **前缀段**、`To` = 本轮 `TestSetTrace` 的前缀段；**仅当** `changeset-log.md` 里确有非 `N/A` 的 `TestSetTrace` 行时（= intake 走的是取数路径①）才额外要求 `From` 等于其中最近一条的同一前缀段——日志不可得而 intake 走了路径②的成对工件时不得再拿日志卡它；对不上 → `BindingMismatch`，缺失/语法坏/`Reason` 越界 → `PackageIncomplete`）—— 据此判 `QAAdmissionStatus`（Step 0，早于指纹校验）。v0.2.2 第九轮补齐：漏掉的这六个正是本 skill 下一行承诺要做的防重放、防替换重算与跨轮连续性的依据 |

**准入门（Step 0，最早）**：四查——intake 的 `ChangeSetId` + **三元组**（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`）与 Implement 工件逐字比对（防重放）、重算 `PackageFingerprint`（防准入后替换）、`SubmissionPackageStatus`、**测试集三行的绑定自洽**（`TestSetTrace` / `PreviousAcceptedTestSetTrace` / `TestSetMigrationRef`，含 `N/A` 的双向约束与迁移清单自洽复核）。

`QAScope: Integration` 时另需 orchestrator §9.1 协调工件的 **`IntegrationPlan.IntegrationResultTreeOid`**（**已补第 6 项的那一版**）——它是集成提测包顶层 `ObjectFormat` / `ThemeTreeOid` 的 producer，本 skill 只做第三方复算比对。准入改为**逐成员核**（本 skill 没有"集成的 §4 工件"可核）：`IntegrationOf.PlanRef` 解析得到 orchestrator 的 §9.1 协调工件、`Members` 与 `IntegrationPlan.MemberChangeSets` 集合相等且无重复、逐成员的 `ImplementArtifactRef` / `QARef`（其 `ReadyForIntegration: Yes`）/ `SubmissionId` 都可解析且三元组逐字相等。**集成提测包顶层的 `ObjectFormat` / `ThemeTreeOid` 走三方等式**：`IntegrationPlan.IntegrationResultTreeOid`（producer = `Integrator` 那个人）→ qa-intake **原样透传** → 本 skill **现算比对**，三者逐字相等才成立。不等 → `Blocked` / `BindingMismatch`；协调工件未补第 6 项或 intake 没填 / 填 `N/A` → `Blocked` / `MissingArtifact` 并写进 `BlockingGaps`。**不得**由 QA 自己现算一个值当作"已核对"，也不得让 qa-intake 现算。

`Blocked` 之后**跑不跑检查取决于原因**：

| 原因 | 跑不跑 | `ReadyForDelivery` |
|---|---|---|
| 绑定失配 / 材料不齐 / 无工件 | **零执行**（准入门的强制效果） | `No` |
| **用户主动弃提测材料** | **照跑技术检查项** | `No` |

🔴 **不存在任何免提测包仍判 `Accepted` 的情形**（v0.2.2 第八轮更正，原文把零改动只读任务列为该情形）。零改动只读任务不进本 skill——见下方入口前置门。用户弃流程同样**不产生** `Accepted`。「改动很小」不是理由——那是 `InlineLite` 的判据。

**入口前置门**：缺 `ChangeSetId` / `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` / `ModifiedFiles` 任一项，或四样（文件集合 + 三元组）比对不上 → 停机，`ChangeSetIdMatched: No` + `ReadyForIntegration: No` + `ReadyForDelivery: No`，要求上游重新输出 §4 工件。`BaseHeadSha` 缺失或不可解析**不是失配**，但 `DeclaredDiffCheck: Blocked` → 本轮拿不到交付许可。零改动任务**不由本 skill 承接**：转 `plaud-theme-dev` 走 §2 的只读通道（`ChangeSetId: N/A` + `ReadOnlyProof`，`NextRequiredSkill: None`，`ReadyForDelivery: N/A(ReadOnly)`）。本 skill 的 §5 工件里既没有 `ModifiedFiles` 也没有 `ReadOnlyProof`，结构上就接不了。

## 下游（ConsumerSkill）

本 skill 是阶段轴终点，没有下游 skill。产出的去向：

| 去向 | 内容 |
|---|---|
| 用户 / `plaud-theme-orchestrator` | §5 契约块，作为交付判定 |
| 实现 skill（`ReadyForDelivery: No` 时） | `ProfileSpecificResults` 中的 `Failed` 项 + `BlockingGaps`，回到 Implement 阶段修复，**修完必须重新生成 `ChangeSetId`** |
| **`plaud-theme-release-ops`** | `VerificationId`（被 `ReleaseQARef` / `ReleaseScope[].QARef` 指住）、`QAScope`、`IntegrationOf`（分辨这是块 QA 还是集成 QA）、`ObjectFormat` + `VerifiedThemeTreeOid`（`ReleaseSourceTreeOid` 必须逐字等于它、格式相同）、`ReadyForIntegration`（`ReleaseScope[].QAConclusion` 逐块抄，且必须经 `QARef` 追溯到具体哪份工件，不是消费一个裸结论）、`ReadyForDelivery`、`FingerprintVerifiedAt`。🔴 **`ReadyForDelivery: Yes` 只是第一层**，release 侧还有四条发布门（§2.11 第二层）；**QA 通过 ≠ 可发版**，另需运营验收与站点二次确认（§1.1） |
| **`plaud-theme-feedback-triage`**（QA 打回后有争议时） | `Failed` 项作为反馈条目，判缺陷还是变更 |
| `plaud-theme-impact`（`Blocked` 于影响面时） | 退回 Assess 重做 `ActualAffectedInstances` |
| 项目侧 `memory/changeset-log.md` | 追溯记录（**不随包分发**） |

## 不做的事

- 不改任何主题文件；发现问题只报，不顺手修（顺手修 = ChangeSet 失配 = 自己把自己判停机）
- 不做根因分析、不出方案
- 不写迁移日志内容、不代替用户验收（`ReadyForDelivery: Yes` ≠ 用户已验收，也 ≠ "可以发了"）
- **不做 merge / 不做集成**（§2.13：集成者是人）。集成完成后才对那棵树取证；无人认领集成时回 `plaud-theme-orchestrator` 要授权
- 不替某一块补发 `ReadyForIntegration: Yes` 好让集成跑下去
- 不复制 `plaud-theme-shared/references/` 里的视觉 / spec 数值——只引用文件名

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §1 交付权 | 唯一实现方 |
| §2 ChangeSetId 与对象绑定 | 消费方，回填 `ChangeSetIdMatched` / `ObjectFormat` / `VerifiedThemeTreeOid` / `FingerprintVerifiedAt` / `DiffBaseTreeOid` / `DeclaredDiffCheck` / `StageDirRef`；**四样**（文件集合 + `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）任一失配即停机；取证函数照抄 §2.5，**原样复制、不自造变体**（漏一个 `-c core.hooksPath=/dev/null` 就等于在取证时执行仓库里的任意脚本） |
| §2.6 两层物化 | 所有检查跑在 `plaud_stage_workspace` 物化的 `StageDirRef` 里，**不在活工作树上跑**；`plaud_stage_verified` 只归 release 推站，QA 不用 |
| §2.7 改动归属 | 跑 `plaud_declared_diff` 填 `DeclaredDiffCheck` / `DiffBaseTreeOid`；`ORPHAN` / `UNCHANGED` → `Failed` 停机，基准不可解析 → `Blocked`（不得降级成 `Passed` / `NotApplicable`） |
| §2.11 交付门两层 | 本 skill 只判**第一层**（准入 + `ChangeSetIdMatched` + `DeclaredDiffCheck` + 全部检查项）；第二层是 release 侧发布门，**不得**写成本 skill 给 `Yes` 的前提（那是流程死循环），也不得把 `ReadyForDelivery: Yes` 表述成"可以发了" |
| §5 Verify 工件 | 输出契约，字段一字不差 |
| §6 Theme Check 门 | 执行手册见 `references/theme-check-gate.md`（baseline 增量） |
| §7 Stop, don't guess | 拿不到 ChangeSetId / 无法预览 / 解析失败 → 停机或 `Blocked`，不猜 |
| §8.1 运营协作红线（DTC §三，**三档**） | 🔴 六条（#1/#2/#3/#4/#6/#7）+ 按范围判定的 #5/#9/#10；🟠 `EvidenceBased` 与封闭清单内的 `ApprovedException` 由 `ApprovedExceptionsChecked` 覆盖（`qa-global.md` §11）；🟡 与存量复用豁免进 `Advisories`。**注意**：这一行说的是 DTC §三；`StyleHardRuleCheck` 覆盖的「硬性 10 条」是 DTC **§2.1 样式硬规则**（`qa-global.md` §9），两者是不同的 10 条，不要混用 |
| §8.1.2 存量复用豁免 | 三项核查见 `qa-global.md` §11.1；只免修复义务，不免回归与空/满双测 |
| §8.1 `ApprovedException` 封闭清单 | 上游 `ApprovedExceptions` 逐项核四件事（存在 / PLAUD 侧批准 / Clause 在清单内 / 批准覆盖得住 Scope），结论写 `ApprovedExceptionsChecked` + `ApprovedExceptionsEvidence`（`qa-global.md` §11） |
| §8 全路径红线 | 红线 1/2/3/5/8 由 QA-Global 七项覆盖；**红线 4（颜色 token）、6（JS 生命周期）、7（build 产物）§5 profile 表未覆盖全路径，由 `qa-global.md` §8 的附加触发式检查补上**，结果写进 `ProfileSpecificResults`，不新增 yaml 字段 |

阈值数值（对比度下限、图片 DPI 倍率、断点、字阶、间距）一律现读 `plaud-theme-shared/references/` 的当前值——本包只引用文件名，不留副本。唯一例外是 `BreakpointsCovered` 的五档，它由 handoff-schema §5 字段说明直接规定，属契约本身。
