# plaud-theme-feedback-triage — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准（本 skill 的产出定义在 §9.1.3）。

## 位置

| 项 | 值 |
|---|---|
| order | 8 |
| 阶段 | **不占阶段轴** —— 事件入口，可在任意时点触发 |
| 路径 | 与路径无关 |
| 工件 | `ArtifactKind: FeedbackTriage` |
| 交付权 | **无**，也不输出任何阶段工件字段 |

**触发时机**（DTC §六 的反馈来源）：

```
QA 打回 ──┐
运营验收 ─┼→ plaud-theme-feedback-triage → PM 判定 → NewWorkItem(Assess) / Backlog / NoAction
线上反馈 ─┤
内部发现 ─┘
```

它是矩阵里唯一的**回流入口**：其它 skill 都是从 Assess 往 Verify 推，本 skill 把反馈接回来重新入场。

## 上游（ProducerSkill）

| 上游 | 内容 |
|---|---|
| `plaud-theme-qa` | **仅限 QA 结论本身有争议**时（实现方认为某项判错了）。**常规机械失败不进本 skill**——Theme Check 新增 offense、断点回归 / A11y `Failed`、写死宽高等直接回实现 skill 返修并生成新 `ChangeSetId` |
| 用户 / 运营 / PM | 验收反馈原文、线上 bug 报告 |
| `plaud-theme-release-ops` | 上线后发现的线上问题 |
| PRD / Figma / UX Spec | 判定依据（`plaud-theme-shared/references/` 现读，本包不留副本） |

## 下游（ConsumerSkill）

| `NextRoute` | 去向 |
|---|---|
| `AwaitPMDecision` | **`PMDecision: Pending` 时只能取此值** —— PM 未确认前不得预先安排去向 |
| `NewWorkItem(Assess)` | `plaud-theme-impact` —— **新开工作项、新 `ChangeSetId`**，不复用旧的 |
| `Backlog(排期)` | 排期流程，**不进状态机**；重新计费与排期 |
| `NoAction` | 结束 |

> ⚠️ **`NewWorkItemRef` 引用的是外部工作项（Linear issue 等），不是新 `ChangeSetId`。** 本 skill 不创建工作项、也无法预知新 `ChangeSetId`（那要到 Implement 才产生）——它引用的是 PM / 用户在 Assess **之前**已创建的那条工作项。新 `ChangeSetId` 由实现 skill 生成后回填进 orchestrator 台账，不回填本工件。
>
> 单块返工**不必经过 orchestrator**：直接 `plaud-theme-impact` → 实现 skill 即可，实现工件里记 `OriginTriageRef`（本工件的 `TriageId`）以便算返工轮次。

> 🔴 **判为缺陷不得直接回实现 skill 打补丁。** handoff-schema §2.8 失效语义：QA 通过后代码再变，原 QA 自动失效。复用旧 `ChangeSetId` 会让 QA 验一批没见过的代码——正是身份三元组（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`，📎 v0.3.0 取代 v0.2.3 的单字段 `ChangeSetFingerprint`）要堵的洞。改动落在可发布面之外时身份可能不变，但**复用旧 ChangeSet 本身即违规，不以身份是否变化为条件**。

## 不做的事

- 不改代码、不修 bug（判为缺陷也要走完整链路重进）
- 不做影响面评估（`plaud-theme-impact`）
- 不做技术验收（`plaud-theme-qa`）
- 不校验提测材料（`plaud-theme-qa-intake`）
- 不推站发版（`plaud-theme-release-ops`）
- **不替 PM 下最终判定** —— `ClassificationRecommendation` 是建议，`PMDecision` 由 PM 给
- **不自动改 Linear 状态** —— `LinearStatusAdvice` 是建议，执行需用户显式授权
- 不复制 shared 里的 spec 数值

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §0.1 非阶段 skill | 本 skill 是其中之一，产出 `ArtifactKind: FeedbackTriage` |
| §1.1 交付权边界 | 明确「QA 通过 ≠ PM 验收」——本 skill 处理的正是 QA 通过之后仍被判缺陷的那类反馈 |
| §2.8 失效语义 | 缺陷必须新开 ChangeSet 的根据（QA 通过后代码再变，原结论自动失效） |
| §7 Stop, don't guess | 反馈含糊、拿不到 PRD/Figma → `Undetermined` + `BlockingGaps`，不脑补依据 |
| §8.1 运营协作红线（DTC §三，**三档**） | 判定时按 🔴 / 🟠 / 🟡 分级引用；🟡 与存量复用豁免项不单独构成 `DeliveryDefect`（§3.1）。**另**：DTC **§2.1 样式硬规则 10 条**仍是逐条可查的直接依据（§3），与本行的 §三 是两套不同条款 |
| §9.1.3 反馈分类工件 | 输出契约，字段一字不差 |

## 双方对等约束（DTC §八）

本 skill 判定时必须同时守住对**开发侧**有利的条款，不能只往开发身上判：

| 条款 | 效果 |
|---|---|
| 需求信息不全导致的返工 | **不计**开发返工轮次 |
| Figma 未定稿 | 不启动开发，排期顺延不计延期 |
| 1280–769px 无稿区间 | 不以还原度问责，只考核 UX Spec |
| 改稿 | 即变更，重新计费与排期；口头不生效 |
| 验收反馈窗口 2 个工作日 | 之后追加的算下一轮 |
| 未标类型的反馈 | **按变更处理** |
| 规范与代码 token 不一致 | 算 PLAUD 缺口，修好之前不打回 |
