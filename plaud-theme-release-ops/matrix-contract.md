# plaud-theme-release-ops — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准（本 skill 的产出定义在 §9.1.4）。

## 位置

| 项 | 值 |
|---|---|
| order | 9 |
| 阶段 | **不占阶段轴** —— 位于 Verify 之后 |
| 路径 | 与路径无关 |
| 工件 | `ArtifactKind: ReleaseOps` |
| 交付权 | **无**。消费 QA 的结论，不生产结论 |

```
plaud-theme-qa（ReadyForDelivery: Yes）
        +
PM / 运营验收（AcceptanceStatus: Accepted）
        ↓
plaud-theme-release-ops ← 你在这里：推站二次确认 + 发版清单
        ↓  用户显式授权
   实际推送（外部动作）
        ↓
上线后跟踪 → 发现问题 → plaud-theme-feedback-triage
```

## 上游（ProducerSkill）

| 上游 | 消费的字段 |
|---|---|
| `plaud-theme-qa` | §5 的 `ReadyForDelivery` `ChangeSetId` `FingerprintVerifiedAt` —— 逐个记入 `ReleaseScope[].QAConclusion`。**v0.2.2 只支持单块发布**：多块同批发版直接停机，没有「集成 QA」这条路（该方案在绑工作树的指纹模型下跑不通，字段已移除；留 v0.3.0） |
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
- **不自行执行推送 / 合并 PR / `git push` / `shopify theme push`** —— 不可逆外部动作，需用户显式授权
- 不输出 `ReadyForDelivery`

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §0.1 非阶段 skill | 本 skill 是其中之一，产出 `ArtifactKind: ReleaseOps` |
| §1 / §1.1 交付权边界 | 严格守住「QA 通过 ≠ PM 验收 ≠ 可推站」；本 skill 守的是第三道 |
| §1.4 QA 结论失效 | 发版前必须核对 HEAD / 工作树自 QA 收尾后未变，变了就重跑 |
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
