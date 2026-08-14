---
name: plaud-theme-feedback-triage
description: >
  PLAUD Shopify 主题矩阵的反馈归因入口（order 8）：把运营/PM/QA/线上来的反馈逐条判成
  「交付缺陷」还是「需求演进」，并给出依据与去向。按《DTC 开发交付标准 v1.0》§六、§七执行。
  用户说这条反馈算不算 bug、算缺陷还是变更、算不算返工、这轮返工几条、
  运营说不好看要不要改、验收反馈来了、QA 打回了、PM 说要改、线上反馈、用户投诉、
  这是需求变更吧、改稿算不算变更、要不要计返工轮次、责任归谁、扣不扣工时、
  Linear 状态怎么点、Feedback Revision、Requirement Change、Requirement Interruption、
  Ready for QA、被阻塞了状态要不要改 时使用。
  判定口径：能在 PRD、Figma 或 UX Spec 里找到依据 = DeliveryDefect（计返工）；
  找不到依据 = RequirementEvolution（算变更，不计返工）；依据不明 = Undetermined。
  产出 ArtifactKind: FeedbackTriage 工件：逐条 ClassificationRecommendation、EvidenceRefs、
  PMDecision、NextRoute、LinearStatusAdvice。
  三条硬规则：**判定人是 PM，本 skill 只给建议**；**判为缺陷必须新开工作项从 Assess 重进，
  不得复用旧 ChangeSet 打补丁**；**Linear 状态不自动改，只给建议**。
  本 skill 不写代码、不修 bug、不做影响面评估、不做验收判定、不判可交付、不发版。
  不要路由到本 skill：直接改 bug → plaud-theme-dev；影响面 → plaud-theme-impact；
  提测材料 → plaud-theme-qa-intake；技术验收 → plaud-theme-qa；推站发版 → plaud-theme-release-ops。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Feedback Triage（反馈归因）

开工前必读 `plaud-theme-shared/references/handoff-schema.md` §9.1.3（本 skill 的产出契约）。

## 先确认：这条反馈该不该进本 skill

> 🔴 **QA 的机械失败不进本 skill。**

| 来源 | 例子 | 去哪 |
|---|---|---|
| **QA 机械失败** | Theme Check 新增 offense、断点回归 `Failed`、A11y `Failed`、写死宽高、图片清晰度 | **直接回实现 skill 返修**（新 `ChangeSetId`）。本 skill 不接 |
| **运营 / PM 验收反馈** | 与 Figma 不一致、觉得间距小、想加动效、配置项不好用 | ✅ 本 skill |
| **线上反馈 / 用户投诉** | 上线后发现的问题 | ✅ 本 skill |
| **内部发现** | 自查发现与 PRD 不符 | ✅ 本 skill |

理由：机械失败没有"是缺陷还是变更"可判——规则是矩阵自己定的，违反了就是要修。塞进本 skill 等于让 PM 去审批一件本来就该修的技术问题，白白多一道人工门。

`FeedbackSource: QA打回` 只用于**QA 结论本身有争议**的情形（例如实现方认为某项 `Failed` 判错了），不用于常规返修。

---

## 这个 skill 解决什么

一条反馈进来，只有两种可能，而**分错的代价是不对称的**：

| 类型 | 例子 | 归属 | 后果 |
|---|---|---|---|
| **交付缺陷** | 与 Figma 不一致、PRD 功能缺失、UX Spec 明显未遵守、配置项不可用、弄坏现有功能 | 开发 | **计返工**，结算时可能扣对应工时 |
| **需求演进** | 看到实物后的新想法：间距再大点、换张图、加个动效、文案改一下 | 需求方 | 算变更，走排期，**不计返工** |

DTC §六 的判定规则一句话：

> **能在 PRD、Figma 或 UX1.3 里找到依据的 = 缺陷；找不到依据的 = 变更。判定人是 PM。**

DTC §八 还有一条对等约束：**未标类型的按变更处理**。

## 三条硬规则

### 1. 判定人是 PM，本 skill 只给建议

`ClassificationRecommendation` 是**推荐值**，不是结论。`PMDecision: Pending` 时不得当定论往下走，更不得据此宣布"这条要返工"或"这条不算我们的"。

本 skill 的价值在于**把依据摆出来**：这条反馈对应 PRD 的哪一条、Figma 的哪个节点、UX Spec 的哪一节——让 PM 判起来有据可依，而不是替 PM 判。

### 2. 判为缺陷 ≠ 回实现 skill 打补丁

必须**新开工作项，从 Assess 重新进入**，生成新的 `ChangeSetId`。

> 🔴 原因见 handoff-schema §2.8 失效语义：**QA 通过后代码再变，原 QA 结论自动失效。** 复用旧 `ChangeSetId` 直接改，会让 QA 验的是一批它从未见过的代码——这正是身份三元组（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`，📎 v0.3.0 取代 v0.2.3 的单字段 `ChangeSetFingerprint`）要堵的洞。
>
> "就改一行，不用重新走流程吧" —— 不行。改一行也是改：改在可发布面上，`ThemeTreeOid` 就变了。
>
> 🔴 **而且这条规则不靠"身份会变"兜底。** 万一那一行改在可发布面之外（build 源、`.theme-check.yml`），`ThemeTreeOid` 可能一动不动，但它照样会改变 QA 与构建结果（handoff-schema §2 的残余风险条目）。**复用旧 ChangeSet 本身就是契约违规，与身份变不变无关。**

### 3. Linear 状态不自动改

`LinearStatusAdvice` 只是建议，实际点状态是外部动作，**需用户显式授权**。顺序严格按 DTC §七：

| 情形 | 操作 |
|---|---|
| 收到反馈 / QA 打回 | **先点 `Feedback Revision`，再点回 `In Dev`** —— 两步，顺序不能省 |
| 需求变更 | 点 `Requirement Change` 并写明变更内容 |
| 被紧急需求打断 | 点 `Requirement Interruption` 并写明打断来源 |
| 提测 | `Ready for QA` |
| 被阻塞（等稿、等裁决） | **不改状态**，在评论区写明阻塞项与阻塞方 |

DTC 原文：「状态不点，返工和打断就算不出来，最后全算成'交付慢'。」

---

## 执行顺序

```
Step 0  逐条拆分反馈 —— 不合并、不改写原文
Step 1  为每条找依据（PRD / Figma / UX Spec）
Step 2  给 ClassificationRecommendation（三值之一）
Step 3  定 NextRoute
Step 4  给 LinearStatusAdvice（建议，不执行）
Step 5  输出 §9.1.3 契约块
```

### Step 0 — 逐条拆分，不合并

运营的一段反馈里常混着三四件事：「这个模块间距太小了，而且移动端标题没左对齐，另外能不能加个动效」。

**三件事，三种归属**：间距（要查 Figma/Spec）、移动端左对齐（Spec 有明确规定 → 大概率缺陷）、加动效（Spec 里没有 → 变更）。

合并成一条判定 = 必然判错。`FeedbackItems` 里**原文照录**，不要改写成自己的话——改写会丢掉判定所需的细节。

### Step 1 — 找依据（本 skill 的核心工作）

依据的优先级与查法见 **`references/evidence-lookup.md`**。要点：

| 依据源 | 找什么 | 找不到时 |
|---|---|---|
| **PRD** | 该功能是否在需求里写明 | 写"PRD 未涵盖" |
| **Figma** | 该视觉细节在稿里是什么值（节点要能定位） | 注意**无稿区间**，见下 |
| **UX Spec** | 该项是否有规范条款（现读 `plaud-theme-shared/references/`） | 写"Spec 未覆盖" |

> 🔴 **1280–769px 是明确的无稿区间。** DTC §八 对等承诺：「**1280–769px 等无稿区间不以还原度问责**，只考核 UX1.3」。
> 所以在这个区间里，「和设计稿不一样」**不构成缺陷**（根本没有稿），只有「违反 UX Spec」才构成。这条最容易判错。

> 🔴 **规范与代码 token 不一致时，算 PLAUD 缺口，不打回开发**（DTC §八）。发现 Spec 说 A、仓库 token 是 B 时，不要判成开发缺陷——记进 `BlockingGaps` 要求修 Spec 或 token。这与 `repo-drift.md` 是同一类问题。

### Step 2 — 三值判定

| 取值 | 条件 |
|---|---|
| `DeliveryDefect` | 找到了明确依据，且实现与依据不符 |
| `RequirementEvolution` | 遍查三个源都找不到依据 —— 这就是变更，不是"我没找到" |
| `Undetermined` | 依据可能存在但当前拿不到（如 Figma 无访问权限、PRD 版本不确定）→ 列出需要 PM 补什么 |

> ⚠️ **不要为了给个结论而硬套。** `Undetermined` 是合法取值，硬判成缺陷会让开发白背返工，硬判成变更会让真缺陷溜走。
>
> 另有几类特殊情形见 `references/classification-rules.md`：事前商议过但 Figma 未同步、运营 AI 生成的模块、承诺时间未提供预览、sandbox 与线上环境差异。

### Step 3 — 去向

| `NextRoute` | 什么时候 |
|---|---|
| **`AwaitPMDecision`** | **`PMDecision: Pending` 时只能取这个值** —— PM 没判之前不得预先安排去向 |
| `NewWorkItem(Assess)` | 判为缺陷**且 PM 已 `Confirmed`** → 从 `plaud-theme-impact` 重新进入；`NewWorkItemRef` 记**外部工作项**（Linear issue 等） |
| `Backlog(排期)` | 判为变更且 PM 已确认 → 进排期，**不进状态机**，重新计费与排期 |
| `NoAction` | 反馈基于误解，或已在其它工作项覆盖 |

> 🔴 **`PMDecision: Pending` 配 `NewWorkItem` 是违规。** 那等于拿着本 skill 的建议直接开工，PM 的判定权形同虚设。
> 🔴 **`PMDecision: Confirmed` 必须同时给 `PMDecisionValue`**（PM 确认的是缺陷还是变更）——只写 Confirmed，下游看不出该走哪条路。

> 🔴 **`NewWorkItemRef` 填的是外部工作项，不是 `ChangeSetId`。** 本 skill 不创建工作项，也无法预知新 `ChangeSetId`——那要到 Implement 才产生。它引用的是 PM / 用户在 Assess **之前**已建好的那条 Linear issue。
>
> **反向的链**由实现 skill 接：实现工件（§4）里填 `OriginTriageRef`（本工件的 `TriageId` + `ItemId`）回指过来。返工轮次靠这条反向链统计。
>
> **单块返工不必经过 orchestrator**：直接 `plaud-theme-impact` → 实现 skill 即可。

工件里还要填 `OriginChangeSetId`（这批反馈针对的原 ChangeSet），否则返工轮次算不出来。

---

## 本 skill 不做什么

| 不做 | 归谁 |
|---|---|
| 改代码、修 bug | 三个实现 skill（且必须新开 ChangeSet） |
| 影响面评估 | `plaud-theme-impact` |
| 技术验收、断点回归 | `plaud-theme-qa` |
| 提测材料校验 | `plaud-theme-qa-intake` |
| 推站、发版 | `plaud-theme-release-ops` |
| **替 PM 下最终判定** | PM |
| **自动点 Linear 状态** | 需用户显式授权的外部动作 |

本 skill 不输出 `ReadyForDelivery`，也不输出任何阶段工件字段。

---

## 停机点

| 情形 | 动作 |
|---|---|
| 拿不到 PRD / Figma / 无访问权限 | 该条判 `Undetermined`，在 `BlockingGaps` 写明要什么 |
| 反馈原文含糊（"感觉不太对"） | 停，向反馈方要具体现象与位置，不脑补 |
| 反馈涉及的模块找不到 | 停，要模块名或页面 URL |
| PM 未标类型且未确认 | `PMDecision: Pending`；按 DTC §八，**未标类型的按变更处理**，但仍要把缺陷嫌疑写出来 |
| 用户要求本 skill 直接改代码 | 拒绝并路由到实现 skill，说明必须新开 ChangeSet |

---

## 输出

回复的最后必须是 handoff-schema §9.1.3 的 ` ```yaml ` 契约块。

**`FeedbackItems` 是逐条结构**：每条都有自己的 `ItemId` / `Text` / `ClassificationRecommendation` / `EvidenceRefs` / `PMDecision` / `PMDecisionValue` / `PMDecisionRef` / `NextRoute` / `NewWorkItemRef`。**不得**把分类和去向提到顶层给一个总体结论——一段反馈里常混着缺陷与新想法，合并判定必然判错。
