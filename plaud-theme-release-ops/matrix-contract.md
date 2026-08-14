# plaud-theme-release-ops — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准（本 skill 的产出定义在 §9.1.4）。

## 位置

| 项 | 值 |
|---|---|
| order | 9 |
| 阶段 | **不占阶段轴** —— 位于 Verify 之后 |
| 路径 | 与路径无关 |
| 工件 | `ArtifactKind: ReleaseOps` |
| 交付权 | **无**。消费 QA 的结论，不生产结论。🔴 QA 的 `ReadyForDelivery: Yes` 语义是「这棵被验过的 tree 有资格被后续 release 使用」，**不是「可以发了」**（§2.11） |

```
各块 plaud-theme-qa（QAScope: SingleChangeSet → ReadyForIntegration: Yes）
        ↓  多块同批时：由**人**（IntegrationPlan.Integrator）集成到一棵树，矩阵不做 merge
plaud-theme-qa（QAScope: Integration → ReadyForDelivery: Yes）→ ReleaseQARef
        +
PM / 运营验收（AcceptanceStatus: Accepted，逐块）
        ↓
plaud-theme-release-ops ← 你在这里：物化推站源 + 归属复核 + 推站二次确认 + 发版清单
        ↓  用户显式授权 → 推站紧前再复算一次 → 从 ReleaseStageDir 推
   实际推送（外部动作）
        ↓
上线后跟踪 → 发现问题 → plaud-theme-feedback-triage
```

## 上游（ProducerSkill）

| 上游 | 消费的字段 |
|---|---|
| `plaud-theme-qa`（块 QA） | §5 的 `QAScope: SingleChangeSet` / `ReadyForIntegration` / `ChangeSetId` / `VerificationId` —— 逐个记入 `ReleaseScope[].QAConclusion`（抄 `ReadyForIntegration`）+ `ReleaseScope[].QARef`（记 `VerificationId` + 出处） |
| `plaud-theme-qa`（集成 QA） | §5 的 `QAScope: Integration` / `VerificationId` / `ReadyForDelivery` / `ObjectFormat` / `VerifiedThemeTreeOid` / `IntegrationOf` —— 顶层 `ReleaseQARef` 指向它，`ReleaseSourceTreeOid` 必须逐字等于它的 `VerifiedThemeTreeOid`。**v0.3.0 支持多块同批发版**，前提就是这份集成 QA 存在且 oid 相等；缺它即停机并指出缺什么，**不得自行吸收成 QA 或规划任务** |
| `plaud-theme-orchestrator` | §9.1 的 `IntegrationPlan.IntegrationBaseCommit` —— 多块同批时 `ReleaseDiffBaseCommit` 抄它（单块直发抄该块 §4 的 `BaseHeadSha`）；`IntegrationPlan.Integrator` 是「`IncludedInThisPush: No` 的块从发布源树里撤掉」这个动作的执行人 |
| `plaud-theme-qa-intake` | §9.1.2 的 `TargetSites` `ExcludedSites` `ThemeIds` `ScopeSourceRef` —— 作为**第一次**站点确认 |
| PM / 运营 | 逐块的 `AcceptanceStatus` + `AcceptanceRef`、发版前的**第二次**站点确认、推送授权（`AuthorizationRef`） |
| agency | PR 链接 |

## 下游（ConsumerSkill）

| 去向 | 内容 |
|---|---|
| 用户 | 发版清单，**等显式授权后才执行推送** |
| `plaud-theme-feedback-triage` | 上线后发现的问题，走归因入口回流 |
| 实现 skill（间接） | 经 triage 判为缺陷后新开的工作项 |
| 项目侧测试集 | `RegressionCasesAdded` + **`TestSetTraceAfterArchive`**（同稳定文档 ID + 入库后新 revision + 三段齐；无线上 bug 填 `N/A(NoOnlineBug)`）。不随包分发 |

## 不做的事

- 不判可交付、不跑任何验证（`plaud-theme-qa` 唯一交付权）
- 不校验提测材料（`plaud-theme-qa-intake`）
- 不判反馈归属（`plaud-theme-feedback-triage`）
- 不写代码、不修 bug（三个实现 skill）
- **不做 merge / 不构造集成**（那是 `IntegrationPlan.Integrator` 这个人做的），也**不自行吸收**"帮我跑一下集成 QA"这类请求（那是 `plaud-theme-qa`）
- **不自行执行推送 / 合并 PR / `git push` / `shopify theme push`** —— 不可逆外部动作，需用户显式授权
- 不输出 `ReadyForDelivery`

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §0.1 非阶段 skill | 本 skill 是其中之一，产出 `ArtifactKind: ReleaseOps` |
| §1 / §1.1 交付权边界 | 严格守住「QA 通过 ≠ PM 验收 ≠ 可推站」；本 skill 守的是第三道 |
| §2.8 失效语义 | 发版前用 `plaud_theme_tree` 重算 `ThemeTreeOid`，与 `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid` 逐字比对。🔴 **判据是 tree oid，不是 HEAD**——期间 commit / rebase 不再让结论失效 |
| §2.6 两层物化 | 推站源是 `plaud_stage_verified` 的 `ReleaseStageDir`（只含可发布面），**不是** QA 的 `StageDirRef`（完整 workspace 快照）。两者 `ThemeTreeOid` 必须相同 |
| §2.11 两层门 | 第一层在 QA（当场可验），**第二层发布门在本 skill**：oid 相等 + `ReleaseDeclaredDiffCheck: Passed` + `PushCommandCompliance: Compliant` + 推站紧前再复算一次 |
| §2.14 `IncludedInThisPush: No` | 物化**没有减去某块的能力**；唯一出路是人撤掉 + 重新取证 + 重跑集成 QA。承载字段 `ReleaseDiffBaseCommit` / `ReleaseDeclaredDiffCheck` |
| §7 Stop, don't guess | 拿不到验收状态、站点清单、PR → 停机要，不默认 Accepted、不推断站点 |
| §8.1 运营协作红线 3 | **验收完成前禁止发版对应 section / page** —— 本 skill 是执行方 |
| §8.1 运营协作红线 4 | **发版前确认推送站点清单** —— 第二次确认在本 skill |
| §9.1.4 发版工件 | 输出契约，字段一字不差 |

## DTC §五 的五条落点

| DTC 条款 | 落在哪 |
|---|---|
| 1. agency 提供 PR，前端用 agent 同步合并 | `PRRef`；无 PR 停机，不替 agency 开分支 |
| 2. 发版前确认推送站点；不需要的站点提前说明 | `TargetSites` / `ExcludedSites` / `SiteListConfirmedBy` |
| 3. 上线后功能类 bug 当天解决 | `PostReleaseWatch` + 分级表（`references/release-checklist.md` §4）；实际推送结果记 `PushResult` / `PushedAt` |
| 4. 样式类进最近一次迭代 | 同上 |
| 5. 每个线上 bug 反推一条回归用例 | `RegressionCasesAdded`，为空即未完成 |
