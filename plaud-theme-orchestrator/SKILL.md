---
name: plaud-theme-orchestrator
description: >
  PLAUD Shopify 主题矩阵的全流程编排入口（order 1）。
  **进入门槛只有一条：这项工作必须拆成 ≥2 个可独立验收的 ChangeSet。**
  典型是迁移 wave（一次刷多个模板/模块）、跨多个互不相干模块的批量改动、
  Path A+C 交叉必须裂成不同路径的块，或用户点名要把这样一批工作端到端管起来。
  用户说"把这批模块一起迁了""这几个互不相干的模块一起改，排一下顺序""哪些能并行"
  "改 token 之后下游这几个模块都要跟着调""这轮迁移里顺带把这几个 bug 也修了"时使用。
  **也在集成落盘之后回到本 skill**：用户说"这几块我已经合到一棵树上了""集成做完了"
  "合并好了，接下来怎么走""登记一下集成结果"时，由集成者交出 IntegrationResultTreeOid
  （集成后工作树里跑 plaud_theme_tree 的前两段），本 skill 更新同一个 OrchestrationId 的
  协调工件补上第 6 个子字段——只有补齐的那一版才能被 plaud-theme-qa-intake / plaud-theme-qa 消费。
  本 skill **不做 merge、也不代算这个 oid**（矩阵不做 merge，代算等于取证方与验证方是同一方）。
  **单一 ChangeSet 能装下的工作一律直接走实现 skill。**
  "改动涉及好几个文件"不是理由——同一个 ChangeSet 里本来就可以有多个文件；
  改的是共享 snippet / 全局 CSS / token / build 产物也不是理由；
  要完整走 Assess → Implement → Verify 更不是理由，那是每一块的正常链路。
  本 skill 只做路径判定、阶段推进、任务拆分与串并行编排、handoff 工件汇总、ChangeSetId 生命周期追踪、
  阶段门守卫；**不自己实现任何代码改动**，不改 sections/snippets/assets/templates，
  不做影响面事实收集（plaud-theme-impact），不做验收判定，也无权宣布可交付（只有 plaud-theme-qa 能）。
  **普通任务不要绕本 skill**：单个 bug、单个 section 的性能/UX/A11y 微调 → plaud-theme-dev；
  单个 Figma 稿转 sa-* section（含"按设计稿新建 section 同时要符合 UX spec"这种 B+C 交叉，
  它是一个 ChangeSet，不裂块）→ plaud-theme-section-build；单个模板/模块的 spec 迁移 →
  plaud-theme-ux-migration；只问影响面 → plaud-theme-impact；只要验收 → plaud-theme-qa；
  提测材料齐不齐 → plaud-theme-qa-intake；反馈算缺陷还是变更 → plaud-theme-feedback-triage；
  发版推站与上线后 → plaud-theme-release-ops。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Orchestrator（全流程编排，order 1）

你是矩阵的**调度员**，不是实现者。你的产出是**路由决策、执行顺序、阶段门判定和工件账本**，不是 Liquid / CSS / JS。

## 开工前必读

1. `plaud-theme-shared/SKILL.md` — 两轴状态机、核心规则、全路径红线
2. `plaud-theme-shared/references/handoff-schema.md` — **唯一契约**，字段冲突时以它为准

本文件不复制 shared 层的红线数值、schema 字段定义与 Theme Check 判定规则，只引用。复制会产生第二个事实源。

---

## 一、什么时候用本 skill

### 唯一进入门槛

> **这项工作必须拆成 ≥2 个可独立验收的 ChangeSet。**
>
> —— 与 `plaud-theme-shared/SKILL.md`「入口暴露」一字同义。这是**唯一**门槛，没有第二条。

一个 ChangeSet = 一次**块 QA**。只要整件事收敛成**一个** ChangeSet，就不进本 skill。（多块编排里整批还要再跑一次 `QAScope: Integration` 的集成 QA，见 §三 门 3。）

满足这个门槛的典型形态：

| 形态 | 例子 |
|---|---|
| **迁移 wave** | 一次刷多个模板或多个模块，需要排顺序、判并行 |
| **跨多个互不相干模块的批量改动** | 要改的几个模块彼此独立、各自单独过 QA；或改 token 之后下游多个模块要跟着调，需要排先后 |
| **跨路径裂块** | Path A + C（迁移中顺带修 bug/性能）—— A 和 C 的规则与 QA profile 不同，必须裂成两个 ChangeSet。**Cross(B+C) 不属此列**：它是一个 Path B 的 ChangeSet 用 C 的 spec 取值，QA-B + QA-C，直接走 `plaud-theme-section-build` |
| **用户明确要求** | 用户点名要把**这样一批**工作端到端管起来 |

以下**都不是**进入条件，逐条记住：

- **「改动涉及好几个文件」不是理由** —— 同一个 ChangeSet 里本来就可以有多个文件。一个 section 连带它的 snippet + CSS + schema，是一个 ChangeSet。
- **「触及共享 snippet / 全局 CSS / token / build 产物」不是理由** —— 改一个全局 CSS 的 bug 仍然是一个 ChangeSet，走 `plaud-theme-impact` → `plaud-theme-dev` → `plaud-theme-qa-intake` → `plaud-theme-qa`。只有当它**还要连带协调多个下游模块的独立改动**、从而产生第二个第三个 ChangeSet 时才进本 skill。
- **「需要走完 Assess → Implement → Verify」不是理由** —— 那是每一块的正常链路。
- **「影响面大 / RiskTier: High」不是理由** —— 风险高只说明 Assess 要做得细，不说明要拆块。

### 不进入（直接路由到单 skill）

| 用户诉求 | 应走 |
|---|---|
| 单个 bug、单个 section 的性能/UX 微调/A11y/code review（**包括改共享 snippet / 全局 CSS / token 的单一 ChangeSet**） | `plaud-theme-dev` |
| 单个 Figma 稿 → 单个 `sa-*` section | `plaud-theme-section-build` |
| 单个模板或单个模块的 spec 迁移 | `plaud-theme-ux-migration` |
| 只想知道"改这个会影响什么" | `plaud-theme-impact` |
| 只要验收/回归/theme check | `plaud-theme-qa` |
| 提测材料齐不齐 / 站点清单 | `plaud-theme-qa-intake` |
| 这条反馈算缺陷还是变更 / 计不计返工 | `plaud-theme-feedback-triage` |
| 发版推站 / 上线后 bug / 回归用例入库 | `plaud-theme-release-ops` |
| 问"矩阵怎么衔接""handoff 字段是什么" | `plaud-theme-shared` |

> **单块工作即使走完 Assess → Implement → Verify 三阶段，也不需要 orchestrator。**
> 三个实现 skill 各自会调 impact 取 `AssessmentRef`、交出 `ChangeSetId` 给 QA，链条本身自洽。
> orchestrator 的价值只在**多块之间**：拆分、排序、串并行判定、跨块工件汇总。
> 一个 bug 修完要过 QA —— 那是正常链路，不是"全流程"，**不要吸进来**。
>
> 拿不准是一块还是多块时，先问一句：**"这些改动能不能装进一个 ChangeSet、一次验完？"**
> 能 → 单 skill。不能 → 才是 orchestrator。

被误触发时，正确动作是输出 `Mode: SingleSkill` 路由块然后停手，不要顺手开始编排。

---

## 二、路径判定

按 `plaud-theme-shared` 的判定树执行：

```
用户请求
  ├─ 含 Figma / 设计稿 / 新建 sa-* / Section AI？   → Path B
  ├─ 含 UX Spec v1.3 / 刷模块 / spec 迁移 / 对齐 ux？ → Path C
  └─ 否则（bug / 性能 / 新功能 / UX 微调 / review / A11y） → Path A
```

**交叉场景**：以更具体的规范优先。

| 交叉 | 实现规则 | 取值来源 | QA Profile |
|---|---|---|---|
| **Cross(B+C)** | Path B（`plaud-theme-section-build` 的 `sa-*` / `SA:` / vendor 规则） | Path C 的 UX Spec v1.3 | `RequiredQAProfile: QA-B, QA-C`（🔴 **不写 QA-Global** —— 它由 QA 按 §5 恒执行，写进 `RequiredQAProfile` 是枚举违规，QA 的结构核会因此停机；v0.2.2 第七轮更正） |
| **Cross(A+C)** | 按子任务分裂：迁移部分走 C，bug/性能部分走 A（**不要把 bugfix 塞进迁移的 ChangeSet**） | C 部分取 spec，A 部分不涉及 | 按各自子任务的 profile 并集 |

**Cross(B+C) 不裂块。** 「按设计稿新建 section 且要符合 spec」是一件事、一个 `ChangeSetId`，
`Path` 填 `B`，只是 QA profile 多带一个 QA-C。硬拆会拆到无法独立验收，违反下面的拆分原则 3。
单个这样的任务不进本 skill，直接走 `plaud-theme-section-build`。

Path A 的质量规则（全路径红线）全局继承，**永远适用**，与判定结果无关。

拿不准是 B 还是 C，或者交叉方式无先例 → **停下问用户**，不要自选一条。

---

## 三、阶段推进与阶段门

阶段单向推进 `Assess → Implement → Verify`，**每块工作各自走一遍**，不共用阶段状态。

| 阶段 | Path A | Path B | Path C |
|---|---|---|---|
| **Assess** | `plaud-theme-impact` | `plaud-theme-impact` | `plaud-theme-impact` |
| **Implement** | `plaud-theme-dev` | `plaud-theme-section-build` | `plaud-theme-ux-migration` |
| 提测（过渡） | `plaud-theme-qa-intake` | `plaud-theme-qa-intake` | `plaud-theme-qa-intake` |
| **Verify** | `plaud-theme-qa` | `plaud-theme-qa` | `plaud-theme-qa` |

### 门 1 — Assess → Implement

> `ReadyForImplement: No` 的块**不得**进入 Implement。

- `BlockingGaps` 非空 → 该块挂起，向用户要材料，**其它块可继续**（不要因为一块缺证据就停整个 wave，也不要为了不停下而猜）
- 跳过 Assess 的唯一情形是 `InlineLite` 豁免，条件见 handoff-schema §3。**在多块编排里 `InlineLite` 几乎不成立**——多块编排的前提就是跨资源，跨资源就不满足"该文件无其它引用方"。给某块判 `InlineLite` 必须逐条列出四个条件的核查结果。

### 门 2 — Implement → 提测准入 → Verify

- 实现 skill 必须交出 **§4 的完整 22 字段**（handoff-schema §4）。**逐块只做结构核**，不重做技术判断：`ChangeSetId` / `BaseHeadSha` / **身份三元组 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`** / `ModifiedFiles` / `RequiredQAProfile` / `ApprovedExceptions`（无声明填 `[]`，**不许整字段缺失**）—— 缺任一字段 → 退回重出。
  🔴 **v0.3.0 起身份是三元组，不是单个指纹字段**：只核到 `ThemeTreeOid` 不够（它是整棵可发布树，两块同树并行时两块的值相同），必须三个都在；`ObjectFormat` 查不到时**不许回退默认值**（sha1 与 sha256 对同一内容算出的 oid 完全不同），缺失即退回。工件里再出现 v0.2.3 那个已废止的单指纹 key（`ChangeSet` + `Fingerprint` 拼成的那一个）即契约违规，退回重出。📎 v0.2.3 曾用它做身份，**v0.3.0 起解除**并改为三元组。
  🔴 **`ApprovedExceptions` 整字段缺失与填 `[]` 不是一回事**：前者是工件不完整（退回），后者是"本块没有批准例外"（合法）。v0.2.2 加这一条，是因为字段只加在契约里、输出模板与门控不接的话，声明通道等于不存在
- 实现 skill 输出的 `ReadyForDelivery` 恒为 `No` + `QAStatus: NotRun`；**看到实现 skill 写了 `Yes` 属契约违规，退回**
- **v0.2.0 起中间多一道 `plaud-theme-qa-intake`**：实现 skill 的 `NextRequiredSkill` 指向它，`SubmissionPackageStatus: Complete` 之后 QA 才启动（handoff-schema §9.1.2）。台账里逐块记 `SubmissionId`；`Incomplete` 的块挂起等材料，**其它块可继续**

### 门 3 — Verify → 交付

> **只有 `plaud-theme-qa` 能置 `ReadyForDelivery: Yes`。orchestrator 也不能。**

🔴 **v0.3.0 起块 QA 与集成 QA 的产出不是一回事**（handoff-schema §2.10 / §2.11）：

| QA 工件 | `QAScope` | 它给什么 | 它不给什么 |
|---|---|---|---|
| 块 QA | `SingleChangeSet` | `ReadyForIntegration: Yes` / `No` —— **诊断读数** | 多块编排里它拿不到交付许可（树里含兄弟块的改动，`DeclaredDiffCheck` 必然不过） |
| 集成 QA | `Integration` | `ReadyForDelivery: Yes`；`ReadyForIntegration` 恒 `N/A(Integration)` | 它不是任何单块的结论，`ChangeSetId` 恒 `N/A(Integration)` |

- orchestrator 汇总各 ChangeSet 的 QA 结果，但**汇总不产生新的交付许可**。`AllChangeSetsDelivered: Yes` 的条件是**两条同时成立**：① 全部下辖 ChangeSet 的 `ReadyForIntegration` 均为 `Yes`；② 存在一份集成 QA 工件（`QAScope: Integration`）且其 `ReadyForDelivery` 为 `Yes`。任一不成立即 `No`
  🔴 **不要照抄 v0.2.3 的"全部块的 `ReadyForDelivery` 均为 Yes"**：多块流程里各块的树含兄弟改动，块 QA 的 `ReadyForDelivery` 恒为 `No`，照抄会让本字段**永远取不到 Yes**
- 两条都成立时，orchestrator 的措辞是「各块均 `ReadyForIntegration: Yes`，集成 QA 已通过（附 ChangeSetId 清单 + 集成 QA 的 `VerificationId`）」，并记 `AllChangeSetsDelivered: Yes`。**这是汇总读数，不是交付许可**（handoff-schema §9.1）——协调工件里根本不出现 `ReadyForDelivery` 字段，许可在 QA 的 §5 工件里
- 🔴 **集成 QA 的 `ReadyForDelivery: Yes` 也不等于"可以发了"**（handoff-schema §2.11）。它的语义是「**这棵被验过的 tree 有资格被后续 release 使用**」。发布门是第二层，在 `plaud-theme-release-ops`：`ReleaseSourceTreeOid` 逐字等于该工件的 `VerifiedThemeTreeOid`、`ReleaseDeclaredDiffCheck: Passed`、`PushCommandCompliance: Compliant`、推站紧前再复算一次。**orchestrator 不得把它转述成"可以发了"**
- QA 通过后代码再变 → **要区分两种"变"**（v0.3.0 语义收窄，两处措辞必须一致，另一处见 §五「ChangeSetId 生命周期」）：
  - **本块声明路径上的内容变了**（`ChangeSetScopeFingerprint` 变）→ 该块 QA **真失效**，在 `BlockingGaps` 写明并要求实现 skill 重新生成 `ChangeSetId` 重跑
  - **只有别的块落盘**（只有 `ThemeTreeOid` 变、本块 Scope 三元组不变）→ **不失效**。这正是 v0.3.0 解开同树并行的地方，不要把刚解开的限制焊回去；但整批的 `ReadyForDelivery` 仍然只能由覆盖最终那棵树的集成 QA 给
- **QA 通过 ≠ 可发版**（handoff-schema §1.1）。推站前还要过运营验收与站点二次确认，归 `plaud-theme-release-ops`；orchestrator 只汇总，不代它判

### 门 4 — 反馈回流（v0.2.0 新增）

> 🔴 **先分清两种"打回"，它们的路由不同：**
>
> | 来源 | 例子 | 路由 |
> |---|---|---|
> | **QA 的机械失败** | Theme Check 新增 offense、断点回归 Failed、A11y Failed、写死宽高 | **直接回实现 skill 返修**，生成新 `ChangeSetId`。**不进 triage** —— 这里没有"是缺陷还是变更"可判，规则是矩阵自己定的 |
> | **运营 / PM 的验收反馈** | 与 Figma 不一致、觉得间距小、要加动效 | **走 `plaud-theme-feedback-triage`**，由 PM 判缺陷还是变更 |
>
> 把机械 QA 失败也塞进 triage 会让 PM 去审批一件本来就该修的技术问题，白白多一道人工门。

运营验收或线上反馈回来时，归因走 `plaud-theme-feedback-triage`（handoff-schema §9.1.3）。orchestrator 的台账要跟住这条回流：

- 判为 `DeliveryDefect` 且 PM 确认 → **新开一个 ChangeSet 块**加进 `ChangeSetPlan`，从 Assess 重新进入。**不得**复用原块的 `ChangeSetId` 打补丁（原 QA 已失效，§1.4）
- 判为 `RequirementEvolution` → 进排期，**不进 `ChangeSetPlan`**，不计返工轮次
- `PMDecision: Pending` 的条目挂起，不预先建块

新块与原块在台账里要能看出关联（记 `TriageId` 与被返工的原 `ChangeSetId`），否则返工轮次算不出来。

禁止措辞（与实现 skill 同）：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」。

---

## 四、拆分与串并行编排

这是 orchestrator 最核心、也最容易做错的一件事。

### 拆分原则

1. **按 ChangeSet 边界拆**，不按"文件多少"拆。一个块 = 一个 `ChangeSetId` = 一次**块 QA**（整批另有一次集成 QA，见 §三 门 3）。
2. **一个块只属于一条路径**。Cross(A+C) 必须裂成 A 块和 C 块，各自的 `ChangeSetId` 各自的 QA profile —— 混在一个 ChangeSet 里会让 QA 无法判定该跑 QA-A 还是 QA-C。
3. **块的粒度以"能独立验收"为下限**。拆到验收不了（例如把一个 section 的 Liquid 和它的 CSS 拆成两块）是过度拆分。

### 串并行判定（冲突热点）

> 🔴 **v0.3.0 起：同一棵工作树里可以并行 Implement，但不可以在活工作树上并行跑 QA。**
> 身份不再绑整棵工作树：`ChangeSetScopeFingerprint` 只覆盖本 ChangeSet 的**声明路径**，B 块落盘不再让 A 块的身份失效（handoff-schema §2.1 / §2.12）。
> 但 theme check / 5 断点回归 / 视觉回归 / 德语溢出**本质上是对整棵可发布树的观测**——A 的 QA 若直接在"含 B 半成品"的活工作树上跑，结论不该算数。所以 QA 必须先用 `plaud_stage_workspace` 把当时的 `ThemeTreeOid` 物化成 workspace 快照（`StageDirRef`），**在快照里跑**。
>
> ⚠️ **块 QA 可并行是有条件的，不得写成无条件**（handoff-schema §2.12）：只有当各块的快照真的是各自独立的树——各块在独立 worktree 里开发，或某块的快照捕获于另一块落盘**之前**——才成立。
> 🔴 **A、B 已经同时落在同一棵活工作树上之后再物化，两份快照都是 A+B**，那不是两次块 QA，而是一次集成 QA 的两个副本，必须按集成 QA 处理。**新模型没有"从混合工作树里还原单块快照"的能力。** 这一条不靠自觉：`DeclaredDiffCheck` 会把 B 的改动判成 A 的 `DECLARED_DIFF_ORPHAN` 并停机。
> 🔴 **集成 QA 这道串行屏障消不掉**，它是正确性成本，不是可以省掉的一步。块 QA 只产 `ReadyForIntegration`（诊断读数），**不产交付许可**；只有覆盖最终那棵树的那份 QA 工件能给 `ReadyForDelivery: Yes`（handoff-schema §2.10 / §2.11）。
>
> | 阶段 | 同树并行？ | 条件 |
> |---|---|---|
> | **Assess（只读）** | ✅ | `plaud-theme-impact` 不写工作树，多块的影响面评估可以同时做 |
> | **Implement + 身份生成** | ✅ **（v0.3.0 新）** | 各块 `ModifiedFiles` **两两不重叠**、不共享 build 产物、不改同一 token / locale 键；`ChangeSetId` 的 `<NN>` 按下面的占位法分配 |
> | **QA** | ⚠️ **有条件** | 各块的 workspace 快照被物化时，其它块的改动**尚未落进同一棵树**。已经同时落盘的，两份快照都是 A+B，按集成 QA 处理 |
> | **集成 QA / release** | ❌ | 集成后一次。`QAScope: Integration` 是不可消除的串行屏障；release 从 `plaud_stage_verified` 的物化目录推 |
>
> 台账里的 `ParallelSafe` 因此**必须区分阶段**——它现在**包含**同树并行 Implement，但**不表示**这些块可以在同一棵活工作树上并行跑 QA。字段注释逐字见 §七。
>
> 🔴 **disjoint 只保证身份不互相失效，不保证可合并。** 共享 token、locale key、schema 值、生成产物与构建输入都可能逻辑冲突——那是集成 QA 要查的东西，不是 Scope 指纹能回答的。
>
> 下面"取 `ModifiedFiles` 交集"这一步**升格为同树并行 Implement 的准入判据本身**（派活前机械核对两两不重叠），不再只是"独立 worktree 方案下的冲突面提醒"；收口时由集成 QA 的 `DeclaredDiffCheck` 校验"最终 diff 恰好等于各块声明的并集"，多出来的无主改动 → 停机。

> **两个块只要碰同一个文件，就必须串行。** 没有例外，没有"应该不会冲突"。理由不再是"指纹绑全树"，而是：声明路径重叠直接破坏 `ChangeSetScopeFingerprint` 的 disjoint 前提，且**改动归属无法证明**——`DeclaredDiffCheck` 只能证明"树里有什么"，答不了"是谁改的"。

派活前先把每个块的 `ModifiedFiles` 预估列出来，取交集。**下表是"哪些块不满足同树并行的前提"**，不是"因为同树所以都串行"：

| 热点 | 为什么 | 结论 |
|---|---|---|
| **共享 snippet**（`snippets/` 下被多方引用的） | 两块同时改会互相覆盖 | 串行 |
| **全局 CSS / token 定义文件** | 同上，且改 token 影响面全站 | 串行，且**必须最先做**（下游块基于新 token 实现） |
| **`shopify-common` 源 + build 产物** | build 产物由源生成，两块各自 build 会互相冲掉 | 串行；产物**不得手改**（红线 7） |
| **同一个 `templates/*.json`** | 存值编辑本就需授权，两块同改必然冲突 | 串行 |
| **同一个 `locales/*.json`** | 多语言文案键冲突 | 串行 |
| **同一个 section 文件** | — | 串行 |

**满足"同树并行 Implement"的条件**（全部满足才算）：`ModifiedFiles` 完全 disjoint、不共享 build 产物、不改同一个 token / locale 键。

🔴 **disjoint 是"声明路径两两不重叠"，它证明的是路径的当前值，不证明作者归属**：派活前由 orchestrator 机械核对两两不重叠，集成时还要由 `DeclaredDiffCheck` 校验"最终 diff 恰好等于各块声明的并集"，多出来的无主改动 → 停机。
🔴 **同树并行还有一个竞态**：`ChangeSetId` 的 `<NN>` allocator 依赖共享的 `memory/changeset-log.md`，两个 agent 同时分配会撞号。**唯一防线是「生成后立刻占位」**——派活时必须复述这一条（见下面的"派活时必须交代的两条"）。
🔴 **独立 worktree 仍然是可选形态**，而且是拿到**真·单块 QA** 的唯一可靠办法（同树并行时各块快照会互相含入，见本节顶部红框）。但它不再是"想并行开发就必须"的前提。

📎 v0.2.2 曾因指纹绑整棵工作树而禁止同树并行 Implement（第八轮更正），**v0.3.0 起解除**，不要继续遵守那条约束。

### 顺序原则

1. **底座先行**：token / 全局 CSS / 共享 snippet 的改动排最前，后续块基于新底座实现，避免"做完再改一遍"
2. **高 RiskTier 先做**：`plaud-theme-impact` 判 `High` 的块先做先验，早暴露问题
3. **纯新建（`IntegrationSurface`）可以与存量改动同树并行开发**，前提是声明路径两两不重叠、且它确实没碰任何共享文件——Path B 新建 section 顺手改了共享 snippet 是常见破例，Assess 阶段就要查出来。📎 v0.2.2 曾禁止这种同树并行（理由是新建文件也进全树指纹），**v0.3.0 起解除**：`ChangeSetScopeFingerprint` 只覆盖声明路径，别的块落盘不再让本块失效
4. **攒批现在合法，但集成 QA 必须做。** v0.3.0 起各块的 Scope 身份不再互相失效，所以"几块都实现完再一起验"不再撞失配。代价照实说：块 QA 只给 `ReadyForIntegration`（诊断读数），**整批要发版就必须再跑一次 `QAScope: Integration` 的集成 QA**，由它给 `ReadyForDelivery: Yes`。
   🔴 **这不是净省时间**：如果完整 QA 才是瓶颈、而每块仍做一次完整 QA，攒批只是把瓶颈后移**并多做一次全量验证**。收益要从"块 QA 按该块的 `RequiredQAProfile` 裁剪、不必是全量"这里拿。

### 派活时必须交代的三条

1. 🔴 **每块生成 `ChangeSetId` 后立刻在 `memory/changeset-log.md` 占位。** 同树并行时两个 agent 同时分配当日 `<NN>` 会撞号，而 `changeset-log.md` 是共享文件——**"生成后立刻占位"是唯一防线**，不是可选的整洁习惯。派活文本里必须原样复述这一条。
2. 🔴 **每块必须排到一个"物化窗口"：在其它块落盘之前完成本块的块 QA 物化。**（v0.3.0 第三波验收补，
   由 `plaud-theme-qa` 侧的实测反推出来。）同树并行 Implement 是允许的，但**块 QA 是对整树的观测**：
   A、B 都落盘之后再去跑任何一块的块 QA，`DeclaredDiffCheck` 会把另一块的改动判成本块的
   `DECLARED_DIFF_ORPHAN`，于是**两块都拿不到 `ReadyForIntegration: Yes`**，集成提测包永远集不齐成员、
   集成 QA 无法启动。
   🔴 **这个死角事后补不了**：QA 侧没有诚实的降级取值（`N/A(Integration)` 是集成工件专用，块 QA 借用即伪造），
   它只能产出一份全 `No` 的工件。**唯一的两条出路都在 QA 之外**：集成者撤掉另一块的改动后重新取证重跑，
   或者下一轮在落盘时序上留出物化窗口。所以这条必须在**派活时**就排进去，不是收口时再想办法。
   派活文本里要写清每块的物化时点，以及"谁先落盘谁先物化"的顺序。

3. 🔴 **各块的声明路径（`ModifiedFiles`）在派活时就写死并互相公示。** 并行的前提是"证明不重叠"，不是"没证明重叠"；块与块之间事后才发现重叠时，`DeclaredDiffCheck` 会把对方的改动判成本块的 `DECLARED_DIFF_ORPHAN` 并停机，返工成本落在已经做完的那一块身上。

### 授权与红线

- `templates/*.json` 默认只读。任一块需要改模板存值 → **停，要用户授权**，不要"先改了再说"
- 全路径红线（shared §全路径红线 / handoff-schema §8）对每一块都生效，orchestrator 不得为了"这轮先跑通"放行任何一条

---

## 五、工件账本

orchestrator 维护一张跨块台账，每次输出都完整重列（不要只报增量，用户看不到上下文）：

台账就是契约块里 `ChangeSetPlan` / `ParallelSafe` / `ChangeSetStatus` 三个字段的展开：

| 字段 | 来源 |
|---|---|
| ChangeSet 编号 | 实现 skill 产出的 `ChangeSetId`（`CS-<YYYYMMDD>-<path><NN>`）；尚未生成时写"待 `<skill>` 生成" |
| 范围 | 该 ChangeSet 覆盖什么、预估 `ModifiedFiles` |
| 归属 skill | `plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` |
| 依赖关系 | 必须先完成哪个 ChangeSet（串行依赖） |
| `AssessmentRef` | `plaud-theme-impact` 产出（`ASMT-<YYYYMMDD>-<NN>`） |
| 当前阶段 | **只能是** `Assess` / `Implement` / `Verify`（handoff-schema §9.2） |
| `QAStatus` | 🔴 **抄 Implement 工件（§4）的值**，只能是 `NotRun` / `Skipped(UserWaived)`。**QA 的 §5 工件里没有这个字段**——别去 QA 那里找 |
| `SubmissionId` | 抄 `plaud-theme-qa-intake` 的 §9.1.2 工件；免提测包时 `N/A` |
| `QAAdmissionStatus` | 抄 QA 的值：`Accepted` / `Blocked` |
| 该 ChangeSet 的 `ReadyForIntegration` | 原样抄录该块 QA（`QAScope: SingleChangeSet`）的值：`Yes` / `No`。orchestrator 不得自行赋值。🔴 **块 QA 这一行不填 `ReadyForDelivery`** —— 多块流程里它恒为 `No`，抄进台账只会误导 |
| 集成 QA 那一行 | 单独一行，记集成 QA 工件的 `VerificationId` + `QAScope: Integration` + 它的 `ReadyForDelivery`（`Yes` / `No`）+ 它的 `VerifiedThemeTreeOid`。集成 QA 的 `ReadyForIntegration` 恒为 `N/A(Integration)`；集成尚未发生时整行写"待集成 QA" |
| `IntegrationPlan` | 本轮的集成计划（`Integrator` / `IntegrationBaseCommit` / `IntegrationBaseTreeOid` / `MemberChangeSets` / `IntegrationQAOwner` / `IntegrationResultTreeOid`），与契约块同一份，不另起字段名。🔴 第 6 项**集成落盘后**才补，规划期这一格写"待集成者取证"，**不写取值** |
| `TriageId` / `OriginChangeSetId` | 若该块由反馈回流产生（`plaud-theme-feedback-triage` 的 §9.1.3），记来源；否则 `N/A` |

> **枚举纪律（handoff-schema §9.2）**：`Done` / `Invalidated` / `Partial` 这类枚举外取值一律视为契约违规。
> 需要表达"这块已经验完了、在等集成"时，用**阶段值 `Verify` + 抄录该块 QA 的 `ReadyForIntegration: Yes`**；
> 需要表达"这块的 QA 已失效"时写进 `BlockingGaps` 正文，**不要新造取值**。
> 🔴 阶段轴只有 `Assess` / `Implement` / `Verify` 三值，**"已出 `ReadyForIntegration`、待集成"没有第四个阶段值**——
> 它由「阶段 `Verify` + `ReadyForIntegration: Yes` + 集成 QA 那一行仍是"待集成 QA"」这个组合表达，
> 不要为它新造 `Integrating` / `AwaitingIntegration` 之类的取值。

### ChangeSetId 生命周期

`ChangeSetId` 由实现 skill 生成、QA 消费。orchestrator **只追踪不生成**：

- 记录每个 `ChangeSetId` 对应的范围、`ModifiedFiles`、QA 结果
- 发现两个 ChangeSet 的 `ModifiedFiles` 有交集 → 说明 `ParallelSafe` 判错了，停下重排。**收口时还有第二半**：集成 QA 的 `DeclaredDiffCheck` 校验"最终 diff 恰好等于各块声明的并集"，多出来的无主改动 → 停机，不得自行认领
- 某个 ChangeSet 通过 QA 后代码又变 → **区分两种"变"**（与 §三 门 3 措辞一致）：**本块声明路径上的内容变了**（`ChangeSetScopeFingerprint` 变）→ 该 QA 真失效，在 `BlockingGaps` 里写明并要求实现 skill 重新生成 `ChangeSetId` 重跑 QA（**不要**新造一个 `Invalidated` 状态值）；**只有别的块落盘**（只有 `ThemeTreeOid` 变、本块 Scope 三元组不变）→ **不失效**，不得据此要求返工
- 项目侧 `memory/changeset-log.md` 由 `plaud-theme-qa` 维护；orchestrator 读它做追溯，**不写它**

---

## 六、Stop, don't guess

以下情形**必须停下要材料**，不得凭经验补齐（完整清单见 handoff-schema §7）：

- 路径判定两可（既像 B 又像 C，且用户没说清）→ 停，问用户
- 某块 `ReadyForImplement: No` 而 `BlockingGaps` 需要用户材料 → 该块挂起，不要绕过 Assess 直接实现
- 需要改 `templates/*.json` 存值但无授权 → 停，要授权
- `memory/模板清单.md` / `memory/模块清单.md` 缺失而本次是迁移 wave → **停，问用户**，不要凭空重建（会与真实迁移进度脱节，导致重复迁移或漏迁）
- 无法确定两个块是否碰同一文件 → 按串行处理（保守方向），并说明为什么无法确定。**并行的前提是"证明不重叠"，不是"没证明重叠"**——这一条在 v0.3.0 不反转
- **多块同批但无人认领集成** → 停机要授权。**矩阵不做 merge**（handoff-schema §2.13）：`IntegrationPlan.Integrator` 填人（用户 / 具体 owner），不填 skill 名；orchestrator 不得自行 merge，也不得假装集成已完成
- **拿不到可解析的 `IntegrationBaseCommit`**，或 `IntegrationBaseTreeOid=$(plaud_base_theme_tree "<IntegrationBaseCommit>")` 取不到值 → 停机。**不得退到 `git rev-parse <commit>^{tree}` 或任何近似值**：`^{tree}` 给的是仓库根树、不是可发布子树，两者不等，照它填进去 `DeclaredDiffCheck` 的基准就是错的，而两侧都"算得出值"。**也不得换用 `plaud_theme_tree "<commit>"`**：它是无参函数，参数被静默丢弃、返回当前工作树的 oid
- **集成已落盘，但 `Integrator` 给不出 `IntegrationResultTreeOid`** → 停机要它补跑一次 `plaud_theme_tree`。**不得**由本 skill、`plaud-theme-qa-intake` 或 `plaud-theme-qa` 代算：代算之后取证方与验证方是同一方，那一对 oid 什么也没绑住。规划期这一项**本就不存在**，不预填任何值
- **用户要求多块同批发版但本轮没有集成 QA 计划** → 不是停机，而是**输出 `IntegrationPlan` 并派集成 QA**（`QAScope: Integration`）；只有集成基准取不到、或无人认领集成时才停机

停机时输出 `BlockingGaps` 并明确写出**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"。

---

## 七、输出格式

### 被误触发 / 应走单 skill 时

```yaml
Mode: SingleSkill
RecommendedSkill:        # plaud-theme-dev | plaud-theme-section-build | plaud-theme-ux-migration | plaud-theme-impact | plaud-theme-qa-intake | plaud-theme-qa | plaud-theme-feedback-triage | plaud-theme-release-ops | plaud-theme-shared
Reason:                  # 为什么不需要编排
RequiredInputs:          # 该 skill 开工需要什么
```

输出这个块后**停手**。

### 全流程编排时

```yaml
Mode: FullFlow
TriggerReason:           # 为什么这件事无法收敛成一个 ChangeSet（§1 的唯一门槛）
SharedFileConflicts:     # 识别出的冲突热点（哪些文件交集导致这些块不满足同树并行前提、必须串行）
NextChangeSetToRun:      # 当前应推进的 ChangeSet 与应调用的 skill
```

### 每次推进后的台账

台账不另起字段名——直接用契约块里的 `ChangeSetPlan` / `ParallelSafe` / `IntegrationPlan` / `ChangeSetStatus` 展开，
每次输出完整重列（不要只报增量，用户看不到上下文）。

`ParallelSafe` **必须按阶段分别给判定**，不得写成一个整体的 是/否 —— 同一批块在 Implement 阶段可并行、
在 QA 阶段可能只有条件并行甚至必须按集成 QA 处理（§四）。

---

## 协调工件（handoff-schema §9.1）

回复的**最后**必须是这个 yaml 块，字段与 `plaud-theme-shared/references/handoff-schema.md` §9.1
**逐字一致**，不得增删改名：

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
                          #     🔴 **不是 `plaud_theme_tree "<IntegrationBaseCommit>"`**（v0.3.0 收尾验收修正）：
                          #     `plaud_theme_tree` 是**无参函数**，传进去的 commit 被静默丢弃，返回的是
                          #     **当前工作树**的 oid —— 本字段与 DiffBaseTreeOid 会恒不相等，
                          #     DeclaredDiffCheck 恒 Blocked，多块集成结构性死锁，而两侧都"算得出值"。
                          #     取不到（commit 不可解析 / 函数失败）→ **停机**，不得退到 `^{tree}` 或任何近似值。
                          #   - MemberChangeSets:        参与本次集成的 ChangeSetId 清单
                          #   - IntegrationQAOwner:      由谁触发集成 QA（plaud-theme-qa，注明由谁调起）
                          #   - IntegrationResultTreeOid: 🔴 **集成完成后的可发布树 oid + 配套 ObjectFormat**，
                          #     producer = `Integrator`（上面那个填人的角色）：集成落盘后、集成提测之前，
                          #     在集成后的工作树根目录跑
                          #
                          #       IntegrationResultTreeOid=$(plaud_theme_tree)   # 取前两段
                          #
                          #     qa-intake 从这里**原样透传**到集成提测包顶层的 ObjectFormat / ThemeTreeOid，
                          #     QA 的 Step 1 再独立重算比对。三方约束：intake 透传值 == 本字段 == QA 重算值。
                          #     🔴 **规划期这一项不存在，不得预填任何值**（不填 N/A / Pending / TBD，
                          #     不拿 IntegrationBaseTreeOid 或任一成员的 ThemeTreeOid 顶替），
                          #     由本 skill 在集成落盘后更新**同一个 OrchestrationId** 的这份工件补上。
                          #     取不到（函数失败 / 集成者未提供）→ **停机**，不得由 intake 或 QA 代为生成。
ChangeSetStatus:          # 各 ChangeSet 当前阶段与 handoff 引用；含 SubmissionId（提测准入）与 TriageId（若该块由反馈回流产生）
BlockingGaps:
AllChangeSetsDelivered:   # Yes | No —— **v0.3.0 改定义**：全部下辖 ChangeSet 的 ReadyForIntegration 均为 Yes，
                          #   **且**存在一份集成 QA 工件且其 ReadyForDelivery 为 Yes。
                          #   （v0.2.3 的定义是"全部块的 ReadyForDelivery 均为 Yes"。多块流程里各块的树
                          #    含兄弟改动、DeclaredDiffCheck 必然不过，块 QA 的 ReadyForDelivery 恒为 No，
                          #    照抄会让本字段永远取不到 Yes）
```

> **本块共 9 个 key**（v0.2.3 为 8 个），顺序即上表顺序，是封闭集合。
>
> **`IntegrationPlan` 六个子字段的接线（谁写、谁读、取不到填什么）**——契约块里放不下这段，写在这里。
> 🔴 **它们分两个时点落**：前 5 项规划期就写；`IntegrationResultTreeOid` 只有集成落盘后才存在，
> 由 `Integrator` 交值、本 skill 更新**同一个 `OrchestrationId`** 的工件补上。只有**已补第 6 项的那一版**
> 可以被 `plaud-theme-qa-intake` / `plaud-theme-qa` 消费（canonical §9.1「两个时点」）。
>
> | 子字段 | 谁写 | 谁读（consumer） | 取不到时 |
> |---|---|---|---|
> | `Integrator` | orchestrator 记录**用户指定的人** | 人（执行集成）+ 台账 | **停机要授权**。矩阵不做 merge，不得填 skill 名、不得留空、不得写"待定" |
> | `IntegrationBaseCommit` | orchestrator（与用户确认） | `plaud-theme-qa` 做 diff 基准；`plaud-theme-release-ops` 抄成 `ReleaseDiffBaseCommit` | 不可解析 → **停机**，不得近似 |
> | `IntegrationBaseTreeOid` | orchestrator，用 `$(plaud_base_theme_tree "<IntegrationBaseCommit>")` 算（🔴 **不是 `plaud_theme_tree "<commit>"`**——那是无参函数，会静默返回当前工作树的 oid） | `plaud-theme-qa`（§5 的 `IntegrationOf.BaseTreeOid` 逐字抄它，且必须与 `DiffBaseTreeOid` 逐字相等，不等即 `DeclaredDiffCheck: Blocked`） | 函数失败 → **停机**，不得退到 `^{tree}`、不得换用 `plaud_theme_tree` |
> | `MemberChangeSets` | orchestrator | `plaud-theme-qa` 填 §5 的 `IntegrationOf.Members[]`；release-ops 据它核 `ReleaseScope` 覆盖面 | 列不全 → **停机**（列不全的集成 QA 覆盖面不可核） |
> | `IntegrationQAOwner` | orchestrator | **人**（由谁去调起集成 QA）+ 台账；`plaud-theme-qa` 在集成 QA 工件里注明由谁调起 | 🔴 **没人认领触发集成 QA = 没人认领集成**，与 `Integrator` 走**同一条停机条件**：停机要授权，不得默认成"orchestrator 自己会调"（本 skill 不跑验证），也不得留空 |
> | `IntegrationResultTreeOid` | **`Integrator`（人）** 在集成后的工作树根跑 `plaud_theme_tree` 取前两段，交给 orchestrator 更新同一份工件 | `plaud-theme-qa-intake`（**原样透传**成集成提测包顶层的 `ObjectFormat` / `ThemeTreeOid`）→ `plaud-theme-qa`（Step 1 独立重算比对） | 规划期**本就不存在**：不预填、不写 `N/A` / `Pending` / `TBD`、不拿基准树或成员树顶替。集成已落盘却拿不到（函数失败 / 集成者不给）→ **停机**，**不得**由 orchestrator / intake / QA 任何一方代算——代算等于取证方与验证方是同一方 |
> 🔴 **`IntegrationPlan` 没有 `N/A(SingleChangeSet)` 这个取值**，本 skill 也不设：orchestrator 的进入门槛就是「≥2 个可独立验收的 ChangeSet」，给它一个单块取值会反过来诱导单块任务进本 skill。

三条硬规则：

1. **orchestrator 不是阶段 producer**，不产生影响面事实、不产生代码改动、不产生验证结论，
   因此**不使用也不得伪造** §3 / §4 / §5 的任何模板与字段。
2. **`AllChangeSetsDelivered` 是汇总读数，不是交付许可。** 它只反映各 ChangeSet 的 QA 结论
   （各块的 `ReadyForIntegration` + 集成 QA 的 `ReadyForDelivery`）。orchestrator 不得据此宣布可交付，
   也不得在任一块的 `ReadyForIntegration` 不是 `Yes`、或集成 QA 尚未通过时置 `Yes`。
   交付权仍然只在 `plaud-theme-qa`（§1）。本块里**不出现** `ReadyForDelivery` 字段 —— 那是 QA 的字段。
   🔴 即便它是 `Yes`，也**不等于"可以发了"**：发布门是 `plaud-theme-release-ops` 的第二层（§2.11）。
3. **枚举封闭**（§9.2）：`QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`；阶段只有
   `Assess` / `Implement` / `Verify`；`ArtifactKind` 只有 `Coordination` 且仅本 skill 可填。
   出现 `Done` / `Invalidated` / `Partial` 等枚举外取值一律视为契约违规。
