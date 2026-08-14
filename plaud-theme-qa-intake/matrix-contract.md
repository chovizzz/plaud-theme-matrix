# plaud-theme-qa-intake — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准（本 skill 的产出定义在 §9.1.2）。本文件只描述接线，不重复定义字段。

## 位置

| 项 | 值 |
|---|---|
| order | 6 |
| 阶段 | **不占阶段轴** —— 是 Implement → Verify 之间的**过渡关口** |
| 路径 | A / B / C 全部经过本 skill |
| 工件 | `ArtifactKind: QAIntake` |
| 交付权 | **无**。本 skill 永不输出 `ReadyForDelivery` |

> 🔴 **不是第四个阶段。** 阶段轴恒为 `Assess / Implement / Verify` 三值（handoff-schema §0.1）。本 skill 产出的是过渡工件，语义是「提测材料齐不齐」，与「代码行不行」正交。
>
> **为什么在 Verify 之前**：DTC §四 原文「提测时必须同时提供，缺一不进验收」——交付物是进验收的**准入条件**，不是验收的产物。

## 上游（ProducerSkill）

| 上游 | 消费的字段 |
|---|---|
| `plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` | §4 的 `ChangeSetId` **`ObjectFormat` `ThemeTreeOid` `ChangeSetScopeFingerprint`**（身份三元组，📎 取代 v0.2.3 的单字段 `ChangeSetFingerprint`）`BaseHeadSha` `ModifiedFiles` `AssessmentRef` `Path` `ReconMode` **`OriginTriageRef`**（三者的 `NextRequiredSkill` 均指向本 skill）。🔴 `OriginTriageRef` 是判首轮 / 返工的**唯一事实源**（`N/A` = 首轮 → `ReworkDeltaStatus: NotApplicable`；带 `TriageId` + `ItemId` = 返工 → 必须收到「本轮修改点」，否则 `Incomplete`；**整字段缺失 ≠ `N/A`**，缺失即停机要求重出）。v0.2.2 第九轮补：此前本清单漏了它，agent 没有事实源就只能默认填 `NotApplicable`，返工 delta 整份漏收 |
| `plaud-theme-orchestrator`（**仅集成提测包**） | §9.1 的 **`IntegrationPlan.MemberChangeSets`**（成员清单的**唯一**事实源）、**`IntegrationResultTreeOid`**（顶层 `ObjectFormat` / `ThemeTreeOid` 的**唯一**事实源，原样透传；未补第 6 项即停机）、**`ChangeSetStatus`**（逐块 `SubmissionId` 的取数路径①）与 **`IntegrationBaseCommit`**（集成路径下 Step 1「已 commit 的材料」那条命令的基准，替代单块的 `BaseHeadSha`；不可解析 → 停机**回 orchestrator**，而单块的 `BaseHeadSha` 缺失是**回实现 skill**）。🔴 拿不到 `IntegrationPlan` → 停机回 orchestrator，本 skill **不自行拟定成员清单**；`memory/changeset-log.md` **不是** `SubmissionId` 的来源（它没有这一列） |
| `plaud-theme-impact`（间接） | §3 的 `AssessmentRef` `ActualAffectedInstances` `ActiveInstances` `DisabledInstances` —— **只引用，不重算** |
| 用户 / 运营 | 站点清单及其出处（`ScopeSourceRef`）、预览链接、配置与测试文档、断点截图；`memory/changeset-log.md` 不可得时，`PreviousAcceptedTestSetTrace` 的**取数路径②**要的那**一对**工件（上一轮 `QAIntake` + **同 `SubmissionId` 且同 `ChangeSetId`** 的 QA §5 工件，后者须 `QAAdmissionStatus: Accepted` —— `QAIntake` 自己没有这个字段，单给一份证明不了「已通过准入」）|

`ChangeSetId` 与身份三元组 `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` **原样透传，不重算不改写**——重算与比对是 QA 的 Step 1 职责，本 skill 既不是 producer 也不是 verifier。

**集成提测包**（`ChangeSetId: N/A(Integration)`）也一样是透传，只是**换了一个上游**：集成树是人做的 merge，没有任何 §4 工件可抄，`IntegrationPlan.IntegrationBaseTreeOid` 是基准树不是结果树，集成 QA 的 `VerifiedThemeTreeOid` 又在本 skill 之后才产生 —— 所以这一对改从 **`IntegrationPlan.IntegrationResultTreeOid`** 原样透传（producer 是 `Integrator` 那个人，集成落盘后跑 `plaud_theme_tree` 取前两段，由 orchestrator 更新同一份协调工件补上；handoff-schema §9.1「两个时点」）。🔴 **本 skill 不得自己跑 `plaud_theme_tree` 现算**（v0.3.0 收尾验收改）：现算只能证明"提测那一刻树长什么样"，绑不住"集成者交付了什么"。协调工件没补第 6 项 → 停机，**不得填 `N/A`**、不得拿基准树或成员树顶替。

## 下游（ConsumerSkill）

| 下游 | 内容 |
|---|---|
| `plaud-theme-qa` | 全部 §9.1.2 字段（**26 个**）。集成提测包另供 **`IntegrationOf`**（**只有 `ChangeSetId` + `SubmissionId` 两段**）：QA 以 `QAScope: Integration` 取证时，据它确认「每一块都有一份 `Complete` 的提测包」，并核 `IntegrationOf` 与 `IntegrationPlan.MemberChangeSets` **集合相等且无重复**。🔴 **逐块三元组比对不走本工件** —— 那要用 §5 `IntegrationOf.Members[]` 里的 `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`，由 QA 自己从各块 §4 工件取；提测工件装不下这些字段（26 key 封闭集）。QA 的 Step 0 据 `SubmissionPackageStatus` 判 `QAAdmissionStatus: Accepted / Blocked`；并**重核** `TestSetTrace` / `PreviousAcceptedTestSetTrace` / **`TestSetMigrationRef`** 三者的绑定自洽（`From`/`To` 逐字比对），对不上 → `Blocked` / `BindingMismatch` |
| 实现 skill（`Incomplete` 时） | `BlockingGaps` —— 缺哪份材料的哪个字段 |
| `plaud-theme-release-ops`（间接） | `TargetSites` / `ExcludedSites` / `ThemeIds` 作为发版前二次确认的第一次记录 |

**准入判定的效果**：`SubmissionPackageStatus: Incomplete` → QA **零验证项执行**并停机。这是本 skill 唯一的阻断能力，也是它存在的理由。

## 不做的事

- 不跑 Theme Check、不做断点回归、不测多语言、不审 A11y、不看代码质量（全归 `plaud-theme-qa`）
- 不重算影响面（归 `plaud-theme-impact`，本 skill 只引用 `AssessmentRef`）
- 不判反馈是缺陷还是变更（归 `plaud-theme-feedback-triage`）
- 不做推站二次确认、不发版（归 `plaud-theme-release-ops`）
- 不改任何文件、不替提测方补材料
- **不输出 `ReadyForDelivery`，任何形式都不**

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §0.1 非阶段 skill | 本 skill 是其中之一，产出 `ArtifactKind: QAIntake` |
| §1 / §1.1 交付权 | 严格回避。提测通过 ≠ 交付许可 ≠ PM 验收 ≠ 可推站，四者正交 |
| §2 ChangeSetId | 只透传，不重算（集成包透传 `IntegrationResultTreeOid` 的两段，见上）。**并守住「材料不得落进工作树」这道前置门**——落进**可发布面**会让 QA 的身份校验失配；落进非发布面则**身份根本看不见**，所以 Step 1 的三条命令必须逐条跑，不能指望身份兜底 |
| §9.1 `IntegrationPlan`（集成提测） | 成员清单与逐块 `SubmissionId` 的事实源；`IntegrationOf` 与 `MemberChangeSets` 集合相等且无重复 |
| §7 Stop, don't guess | 拿不到站点清单 / 主题 ID / ChangeSetId → 停机要，不推断"应该是全站" |
| §8.1 运营协作红线 | 第 4 条（发版前确认推送站点清单）的**第一次确认**在这里；第二次在 `plaud-theme-release-ops` |
| §9.1.2 提测准入工件 | 输出契约，字段一字不差；`Complete/Incomplete` 与 `Yes/No` 不可互换 |

材料判定标准见本包 `references/package-checklist.md` 与 `references/test-case-format.md`；断点数值、字阶、色值一律现读 `plaud-theme-shared/references/`，本包不留副本。
