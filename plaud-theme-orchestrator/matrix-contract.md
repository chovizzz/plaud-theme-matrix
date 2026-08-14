# plaud-theme-orchestrator — 矩阵接线

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准。本文件只描述本 skill 在矩阵中的接线，不重复定义字段。

## 1. 定位

| | |
|---|---|
| order | 1 |
| 阶段 | **不在阶段轴上**（handoff-schema §0.1 的四个非阶段 skill 之一） |
| 产出 | §9.1 协调工件（`ArtifactKind: Coordination`），**不产出** §3 / §4 / §5 |
| 交付权 | 无。`ReadyForDelivery: Yes` 只有 `plaud-theme-qa` 能出；多块编排里它只来自 `QAScope: Integration` 的集成 QA 工件（块 QA 给的是 `ReadyForIntegration`）。**即便拿到它也不等于"可以发了"**——发布门在 `plaud-theme-release-ops`（handoff-schema §2.11 第二层） |

**进入门槛只有一条**：这件事必须拆成 **≥2 个可独立验收的 ChangeSet**（`MATRIX.md`）。单一 ChangeSet 一律直接走实现 skill——「涉及好几个文件」「改的是共享 snippet / 全局 CSS / token」「要完整走 Assess → Implement → Verify」**都不是**进入条件。Cross(B+C) 不裂块，直接走 `plaud-theme-section-build`。

## 2. 上游（ProducerSkill）

| 上游 | 消费的字段 |
|---|---|
| 用户 | 任务清单、验收边界、站点范围 |
| `plaud-theme-impact` | §3 的 `AssessmentRef` `ActualAffectedInstances` `SharedPropagation` `RiskTier` `RequiredQAProfile` —— 用于排序（底座先行、高 RiskTier 先做）与冲突面判定 |
| 实现 skill（dev / section-build / ux-migration） | §4 的 `ChangeSetId` `ObjectFormat` `ThemeTreeOid` `ChangeSetScopeFingerprint` `ModifiedFiles` `QAStatus` `BuildRequired` —— 进台账；`QAStatus` **抄 §4 的值**，只能是 `NotRun` / `Skipped(UserWaived)`（QA 的 §5 工件里没有这个字段） |
| `plaud-theme-qa`（块 QA） | §5 的 `QAScope: SingleChangeSet` / `ReadyForIntegration` / `VerificationId` —— 作为该块的阶段门结论进台账，本 skill 只汇总不改判。**块 QA 的 `ReadyForDelivery` 不进台账**（多块流程里它恒为 `No`） |
| `plaud-theme-qa`（集成 QA） | §5 的 `QAScope: Integration` / `VerificationId` / `ReadyForDelivery` / `VerifiedThemeTreeOid` / `IntegrationOf` —— 集成 QA 独立成一行；`AllChangeSetsDelivered` 的第二个条件就读它 |
| `plaud-theme-feedback-triage` | §9.1.3 的 `TriageId` / `ItemId` —— 返工块的 `OriginTriageRef` 由实现 skill 回指 |

## 3. 下游（ConsumerSkill）

按每块的 `Path` 与 `Stage` 派给 `plaud-theme-impact` → 实现 skill → `plaud-theme-qa-intake` → `plaud-theme-qa`（块 QA）；多块同批时再由**人**按 `IntegrationPlan` 集成，`plaud-theme-qa` 以 `QAScope: Integration` 跑集成 QA；发版归 `plaud-theme-release-ops`。本 skill **不自己实现任何代码改动，也不做 merge**。

派活时必须交代：每块生成 `ChangeSetId` 后**立刻**在 `memory/changeset-log.md` 占位——同树并行时当日 `<NN>` 会撞号，占位是唯一防线。

## 4. 串并行（v0.3.0 放开同树 Implement）

🔴 **同一棵工作树里可以并行 Implement，但不可以在活工作树上并行跑 QA。** 身份不再绑整棵工作树：`ChangeSetScopeFingerprint` 只覆盖本 ChangeSet 的**声明路径**，别的块落盘不再让本块失效（handoff-schema §2.1 / §2.12）。

| 阶段 | 同树并行？ | 条件 |
|---|---|---|
| Assess（只读） | ✅ | `plaud-theme-impact` 不写工作树 |
| Implement + 身份生成 | ✅ | 各块 `ModifiedFiles` 两两不重叠、不共享 build 产物、不改同一 token / locale 键 |
| QA | ⚠️ 有条件 | 各块 workspace 快照被物化时其它块尚未落进同一棵树。**已同时落盘的，两份快照都是 A+B**，必须按集成 QA 处理 |
| 集成 QA / release | ❌ | 集成后一次；`QAScope: Integration` 是不可消除的串行屏障 |

`ParallelSafe` 因此**必须区分阶段**：它现在**包含**同树并行 Implement，但**不表示**这些块可以在同一棵活工作树上并行跑 QA。

v0.3.0 **支持多 ChangeSet 同批发版**（handoff-schema §2.10），前提是**必须有集成 QA**：由**人**（`IntegrationPlan.Integrator`，矩阵不做 merge）把各块集成到一棵树，再由 `plaud-theme-qa` 以 `QAScope: Integration` 取证并给 `ReadyForDelivery: Yes`，release-ops 的 `ReleaseQARef` 指向它。块 QA 只给 `ReadyForIntegration`，**不是交付许可**；即便集成 QA 给了 `Yes`，那也只是「这棵被验过的 tree 有资格被后续 release 使用」，发布门在 release-ops（§2.11 第二层）。

`IntegrationPlan`（本 skill 新增字段，**6 个子字段**）是这条链的载体：`Integrator`（填人）/ `IntegrationBaseCommit`（必须可解析）/ `IntegrationBaseTreeOid`（`$(plaud_base_theme_tree "<IntegrationBaseCommit>")`，**不许退到 `^{tree}`、也不许换用无参的 `plaud_theme_tree`**）/ `MemberChangeSets` / `IntegrationQAOwner` / `IntegrationResultTreeOid`（**集成落盘后**由 `Integrator` 跑 `plaud_theme_tree` 取前两段，本 skill 更新同一份工件补上）。它的 consumer 是**人 + `plaud-theme-qa`**（后者读 `IntegrationBaseCommit` 做 diff 基准、读 `MemberChangeSets` 填 §5 的 `IntegrationOf`）**+ `plaud-theme-qa-intake`**（原样透传 `IntegrationResultTreeOid` 成集成提测包顶层的 `ObjectFormat` / `ThemeTreeOid`），不是孤儿字段。

## 5. 停机条件

- 门槛不满足（拆不出 ≥2 个可独立验收的 ChangeSet）→ 输出 `Mode: SingleSkill` + 目标 skill，然后停手
- `memory/` 必读文件缺失 → 停机要材料，不得凭经验补
- 某块的 `ReadyForImplement: No` → 该块不得进 Implement
- 用户要求多块同批发版而本轮**没有集成 QA 计划** → 不是停机：输出 `IntegrationPlan` 并派集成 QA（`QAScope: Integration`）
- **无人认领集成**（`IntegrationPlan.Integrator` 填不出人）→ 停机要授权。矩阵不做 merge，不得自行合并，也不得假装集成已完成
- **`IntegrationBaseCommit` 不可解析、或 `IntegrationBaseTreeOid` 取不到** → 停机，不得退到 `git rev-parse <commit>^{tree}` 或任何近似值，也不得换用无参的 `plaud_theme_tree`
- **集成已落盘但 `Integrator` 给不出 `IntegrationResultTreeOid`** → 停机要它补取证；本 skill / intake / QA 都不得代算
