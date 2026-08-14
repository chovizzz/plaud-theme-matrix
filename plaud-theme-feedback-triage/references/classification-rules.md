# 分类细则 —— 边界情形与双方对等约束

**何时读我**：一条反馈不是「明显缺陷」也不是「明显新想法」，卡在中间时。依据怎么查见 `evidence-lookup.md`。

---

## 1. 基本口径

| | 交付缺陷 | 需求演进 |
|---|---|---|
| 判据 | 能在 PRD / Figma / UX Spec 找到依据 | 三个源都找不到依据 |
| 例子 | 与 Figma 不一致、PRD 功能缺失、UX Spec 明显未遵守、配置项不可用、弄坏现有功能 | 间距再大点、换张图、加个动效、文案改一下 |
| 归属 | 开发 | 需求方 |
| 返工 | **计** | **不计** |
| 判定人 | PM | PM |

**未标类型的按变更处理**（DTC §八）——这是对开发的保护条款，别反过来用。

---

## 2. 六种边界情形

### 2.1 事前商议过，但 Figma 未同步修改

**判：不是缺陷。** DTC §一 例外条款：「事前商议过、实际要求与 Figma 不同但 Figma 未同步修改的，**以商议结论为准**」。

前提：**须有书面 / IM 记录**。口头不生效。

→ `EvidenceRefs` 里填商议记录的链接，`ClassificationRecommendation: RequirementEvolution` 或 `NoAction`（取决于当前实现是否已符合商议结论）。拿不到记录 → `Undetermined`。

### 2.2 无稿区间的还原度问题

**判：不是缺陷**（除非违反 UX Spec）。

DTC §八：「**1280–769px 等无稿区间不以还原度问责**，只考核 UX1.3」。

这个区间没有设计稿，「和稿不一样」在逻辑上不成立。只有当它同时**违反了 UX Spec 的明确条款**（如容器内边距不对、字号不在字阶上）时才是缺陷，且依据要写 Spec 的章节而不是 Figma 节点。

⚠️ 反向也要守住：**这个区间里违反 UX Spec 仍然是缺陷**，不能拿"没有稿"当免责。

### 2.3 运营自己用 AI 生成的模块

**判：开发不兜底。** DTC §一 第 2 条：「运营自行使用 ai 生成的模块部分开发不兜底，建议走正规提需求流程」。

→ `NoAction` + 建议走正规需求流程。不判为开发缺陷，也不进排期（它还不是一条需求）。

### 2.4 规范与代码 token 不一致

**判：PLAUD 缺口，不打回开发。** DTC §八：「规范与代码 token 不一致的，算 PLAUD 缺口，**修好之前不打回**」。

典型：Spec 说 `label-secondary` 是 `#717171`，但仓库编译产物还是旧值（见 `plaud-theme-shared/references/repo-drift.md`）。开发按 token 写没错，是 token 本身没跟上。

→ `Undetermined` + `BlockingGaps` 写明需要先修 Spec 或 build token。

### 2.5 承诺时间未提供预览

**判：算未完成交付**（DTC §一 第 3 点），但有四类免责：

| 免责情形 | 条件 |
|---|---|
| 不可抗力 | — |
| 需求变更 | 变更导致的顺延 |
| 卡在非开发环节 | 等 form ID、等服务器部署等 |
| Figma 未定稿 | DTC §八：稿未定不启动开发，排期顺延不计延期 |

**所有免责都要求提前通知运营**。事后才说的不算。

这类反馈不进 `DeliveryDefect` / `RequirementEvolution` 二分——它是**交付时效**问题，记进 `BlockingGaps` 并说明属于哪类，由 PM 处理。

### 2.6 sandbox 与线上环境差异

**判：多数情况不是缺陷。** DTC §2.2：验收一般在 sandbox 做，「线上站点如有配置等差异导致测试未测出**免责**」。

前提是开发方在按要求定期同步线上配置到 sandbox。

→ 若确认是环境配置差异（不是代码问题）→ `RequirementEvolution` 不合适，用 `NoAction` + 说明是环境差异，并建议同步 sandbox 配置。

---

## 3. 硬性样式项的特殊地位

DTC §2.1 的 10 条硬性样式要求（同页边距一致、背景成体系、字号不倒置、圆角 5/10/15、不加粗、无文字渐变、文字色规范、移动端不裁切、按钮不硬设宽高、移动端对齐配置）是**逐条可查**的。

违反其中任何一条 → **直接判 `DeliveryDefect`**，不需要再去 Figma 里找依据——DTC §2.1 本身就是依据（`EvidenceRefs` 填「DTC §2.1 第 N 条」）。

对应地，§2.2 的软性项（字号尽量落字阶、间距尽量走变量）**不单独构成缺陷**：

> DTC 原文判定原则：「硬性项逐条可查；**软性项只在同页面内部明显不自洽时才提**。」

软性项的问题 → 记进反馈但判 `RequirementEvolution` 或 `NoAction`，并在 QA 侧进 `Advisories`（非阻断）。

### 3.1 存量复用的反馈不算本次交付缺陷（v0.2.1）

复用既有 section / snippet 的改动被反馈时，先分清偏差是**本次引入**还是**本来就有**（`handoff-schema.md` §8.1.2）：

| 情形 | 判定 | 计返工 |
|---|---|---|
| 偏差在 `BaseHeadSha` 上已存在，本次未加重、未使其变得可达 | `RequirementEvolution`（或另开独立治理块），**不算本次 `DeliveryDefect`** | 否 |
| 本次改动让原本不可达的旧偏差进入新的可达路径（复用旧 snippet / 放开条件 / 新模板挂旧 section） | `DeliveryDefect` | **是** |
| 举证不出"已存在"（无可复跑证据命令） | 按本次引入判 `DeliveryDefect` | 是 |

> 举证责任在实现方，不在反馈方。判 `RequirementEvolution` 时 `EvidenceRefs` 必须带那条可复跑的 `git show <BaseHeadSha>:<file>` 证据。

---

## 4. 一条反馈可能同时是两者

「这个卡片间距太小了，而且移动端标题没左对齐」——

- 移动端标题左对齐：UX Spec 有明确条款 → `DeliveryDefect`
- 卡片间距太小：Figma 里是 24px、实现也是 24px，运营只是觉得小 → `RequirementEvolution`

**必须拆开逐条判**（SKILL.md Step 0）。合并判定要么让开发白背一条，要么让真缺陷混过去。

---

## 5. 判定表

| 情形 | 推荐值 | 计返工 |
|---|---|---|
| 与 Figma 明确不符（有稿区间） | `DeliveryDefect` | 是 |
| 违反 UX Spec 明确条款 | `DeliveryDefect` | 是 |
| 违反 DTC §2.1 硬性 10 条 | `DeliveryDefect` | 是 |
| PRD 写了但没做 | `DeliveryDefect` | 是 |
| 配置项不可用 / 弄坏现有功能 | `DeliveryDefect` | 是 |
| 看到实物后的新想法 | `RequirementEvolution` | 否 |
| 无稿区间的还原度 | `RequirementEvolution` / `NoAction` | 否 |
| 事前商议过、Figma 未同步（有书面记录） | `RequirementEvolution` / `NoAction` | 否 |
| 运营 AI 生成的模块 | `NoAction` | 否 |
| 规范与 token 不一致 | `Undetermined` + BlockingGaps | 否（先修缺口） |
| 软性项不自洽 | `RequirementEvolution` | 否 |
| 环境差异（sandbox vs 线上） | `NoAction` | 否 |
| 依据可能存在但拿不到 | `Undetermined` | 待定 |
