# plaud-theme-orchestrator — 矩阵接线

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准。本文件只描述本 skill 在矩阵中的接线，不重复定义字段。

## 1. 定位

| | |
|---|---|
| order | 1 |
| 阶段 | **不在阶段轴上**（handoff-schema §0.1 的四个非阶段 skill 之一） |
| 产出 | §9.1 协调工件（`ArtifactKind: Coordination`），**不产出** §3 / §4 / §5 |
| 交付权 | 无。`ReadyForDelivery: Yes` 只有 `plaud-theme-qa` 能出 |

**进入门槛只有一条**：这件事必须拆成 **≥2 个可独立验收的 ChangeSet**（`MATRIX.md`）。单一 ChangeSet 一律直接走实现 skill——「涉及好几个文件」「改的是共享 snippet / 全局 CSS / token」「要完整走 Assess → Implement → Verify」**都不是**进入条件。Cross(B+C) 不裂块，直接走 `plaud-theme-section-build`。

## 2. 上游（ProducerSkill）

| 上游 | 消费的字段 |
|---|---|
| 用户 | 任务清单、验收边界、站点范围 |
| `plaud-theme-impact` | §3 的 `AssessmentRef` `ActualAffectedInstances` `SharedPropagation` `RiskTier` `RequiredQAProfile` —— 用于排序（底座先行、高 RiskTier 先做）与冲突面判定 |
| 实现 skill（dev / section-build / ux-migration） | §4 的 `ChangeSetId` `ModifiedFiles` `QAStatus` `BuildRequired` —— 进台账；`QAStatus` **抄 §4 的值**，只能是 `NotRun` / `Skipped(UserWaived)`（QA 的 §5 工件里没有这个字段） |
| `plaud-theme-qa` | §5 的 `ReadyForDelivery` —— 作为该块的阶段门结论，本 skill 只汇总不改判 |
| `plaud-theme-feedback-triage` | §9.1.3 的 `TriageId` / `ItemId` —— 返工块的 `OriginTriageRef` 由实现 skill 回指 |

## 3. 下游（ConsumerSkill）

按每块的 `Path` 与 `Stage` 派给 `plaud-theme-impact` → 实现 skill → `plaud-theme-qa-intake` → `plaud-theme-qa`；发版归 `plaud-theme-release-ops`。本 skill **不自己实现任何代码改动**。

## 4. 串并行（v0.2.2 第七/八轮收窄）

🔴 **同一个工作树里，Implement / 指纹生成 / QA / release 一律逐块串行。** `ChangeSetFingerprint` 绑的是整个工作树，第二块只要落盘，第一块的指纹与 QA 结论当场失效——`ModifiedFiles` 互不相交**不能**让它们并行。

可并行的只有两种：**Assess（只读）**，以及**各块在独立 worktree / clone 里开发**（集成回主树时仍逐块串行、重新生成 `ChangeSetId` 重跑 QA）。`ParallelSafe` 只描述这两种，不表示可以在同一棵树里同时进入 Implement。

v0.2.2 **不支持多 ChangeSet 同批发版**：遇到多块要一起发 → 停机，要求逐块串行（彻底解法留 v0.3.0）。

## 5. 停机条件

- 门槛不满足（拆不出 ≥2 个可独立验收的 ChangeSet）→ 输出 `Mode: SingleSkill` + 目标 skill，然后停手
- `memory/` 必读文件缺失 → 停机要材料，不得凭经验补
- 某块的 `ReadyForImplement: No` → 该块不得进 Implement
- 用户要求多块同批发版 → 停机（见上）
