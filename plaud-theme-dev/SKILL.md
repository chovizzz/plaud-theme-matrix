---
name: plaud-theme-dev
description: >
  PLAUD Shopify 主题 Path A 通用开发（Implement 阶段，order 3）：bug 修复、性能优化、
  新功能、UX 微调。用户说改 Plaud 主题 bug、修 Swiper、
  swiper cards/cube 图不加载、点击触发多次、下拉被 overflow 裁切、移动端样式不生效、
  inline style 覆盖媒体查询、弹窗 popup、drawer、custom element 泄漏、
  disconnectedCallback 没清理 timer/observer、DOMParser 重复创建、循环里输出
  stylesheet_tag、图片没 width/height 导致 CLS、lazy-load 与 Swiper effect 冲突、
  组件写死宽高需要适配、给某个 section 加个新功能/新开关；
  以及**零改动（没有 ChangeSetId）**的只读 code review /
  A11y 无障碍审计 / 对比度、aria-label、focus-visible 审计——
  **用户要不要"最终交付判定"都不改变归属**：零改动没有 ChangeSet 可绑，
  plaud-theme-qa 结构上接不了、会原样转回来（v0.2.2 第八轮修掉的 dev↔QA 回环）；
  此时按 §2 只读通道出 ReadOnlyProof，ReadyForDelivery 填 N/A(ReadOnly) 并说明
  "零改动不存在交付判定"。已有 ChangeSetId（即有改动）→ 走 plaud-theme-qa。
  只要是 Plaud 主题（plaudRelease、plaudAsen、
  PLAUD SG、shopify-plaud-sg-test 等仓库）的 sections/snippets/assets/Liquid/CSS/JS
  改动且不属于 Path B / Path C，就用本 skill。
  本 skill 只做 Orient / Decide / Act（根因、方案、最小实现），
  不做影响面事实收集（那是 plaud-theme-impact），也无权宣布可交付（那是 plaud-theme-qa）。
  不适用：Figma / 设计稿 / 新建 sa-* section → plaud-theme-section-build；
  UX Spec v1.3 迁移 / 刷模块 / 对齐 ux / 迁移日志 → plaud-theme-ux-migration；
  非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Dev（Path A · Implement）

Path A 的实现层。**输入**是 `plaud-theme-impact` 的 Assess 工件，**输出**是一批已就位、待 QA 的改动。

## 🔴 开工前两条硬约束

**一、终态措辞禁令（`plaud-theme-shared/references/handoff-schema.md` §1）**

> 你**无权**宣布任何东西可交付。改完只能说：**「改动已就位，待 QA」**。

**这是语义级禁令，不是关键词黑名单。**根本规则：

> 在回复的**任何位置**，不得断言本次改动的**正确性、稳定性、可用性、验证结果、验收状态，或合并 / 部署 / 发布资格**。你只能陈述：**做了什么**、**为什么这么做**、**待验证什么**。

因此以下全部禁止，换说法也一样禁止：「修好了」「已修复完成」「问题已解决」「功能已恢复正常」「可以上线」「上线可用」「已具备上线条件」「达到发布标准」「生产就绪」「可以合并 / 部署 / 发布」「剩下只需发布操作」「全部通过」「回归都过了」「验证无误」「测试没问题」「风险已清零」「无需进一步检查」「QA 可以直接放行」「验收条件均已满足」「已验收」「没问题了」「应该没问题」。
同样禁止**完成度声明**——「开发完成」「实现结束」「代码已经齐了」「不用再改了」「无需继续修改」：它们不需要验证就能为真，却同样暗示终态。允许的等价表述是「本次 ChangeSet 的改动已落地」。

判别法两条，任一命中即不能说：
1. **这句话如果为真，需要有人执行过验证吗？** 需要 → 不能说。
2. **这句话是否暗示"这件事到此为止了"？** 是 → 不能说；终结权在 `plaud-theme-qa`。

输出块里 `QAStatus` 恒为 `NotRun`、`ReadyForDelivery` 恒为 `No`（唯一变形是零改动只读任务的 `ReadyForDelivery: N/A(ReadOnly)`，见「只读任务的契约变形」）。
用户明说"不用检查直接给我"时，仍输出 `ReadyForDelivery: No`，把 `QAStatus` 写成 `Skipped(UserWaived)`（此取值由 `handoff-schema.md` **§1.5 明文授权**，不是自造），并一句话说明风险由用户承担。

**二、必读契约**

开工前先读 `plaud-theme-shared/references/handoff-schema.md`（尤其 §1 交付权、§3 Assess 工件、§4 你的输出契约、§7 停机规则、§8 全路径红线）。
其余 shared reference **按需加载**，不要全读：改一个 JS timer 不需要字阶表。

| 本次任务涉及 | 加载 |
|---|---|
| JS / custom element / Swiper / 主题架构速记 | `plaud-theme-shared/references/javascript-swiper.md` |
| Liquid / schema / 文案配置 / 文件格式 | `plaud-theme-shared/references/liquid-schema-format.md` |
| 无障碍审计 | `plaud-theme-shared/references/a11y.md` |
| 图片 / 视频清晰度与懒加载 | `plaud-theme-shared/references/media-quality.md` |
| 字号 / 字阶 | `plaud-theme-shared/references/typography.md` |
| 颜色 token / 配色 | `plaud-theme-shared/references/colors-and-schemes.md` |
| 断点 / 间距 / 容器宽度 | `plaud-theme-shared/references/responsive-and-spacing.md` |

**所有视觉数值（字号、颜色、间距、断点、圆角、按钮尺寸）、Swiper effect 约束表、主题架构速记的唯一副本都在 shared。**本 skill 只引用，不复述——复述会造成双事实源，spec 一升级必然漂移。

---

## 本 skill 的职责边界

| | 谁负责 |
|---|---|
| Observe（影响面事实：引用数、实例数、传播链、入口候选、风险等级） | `plaud-theme-impact` |
| **Orient（机制层根因）** | **本 skill** |
| **Decide（≥2 方案 + 取舍）** | **本 skill** |
| **Act（最小化实现）** | **本 skill** |
| Verify（Theme Check、回归、断点、多语言、A11y、交付判定） | `plaud-theme-qa` |

覆盖任务类型：**bug 修复 / 性能优化 / 新功能 / UX 微调 / code review / A11y 审计**。

**不属于本 skill：** Figma 设计稿转 `sa-*` section → `plaud-theme-section-build`；UX Spec v1.3 迁移 / 刷模块 / 对齐 ux → `plaud-theme-ux-migration`。判不准时按 shared SKILL.md 的路径判定树走。

---

## 第一步：拿到 Assess 工件

**没有 Assess 工件、又不满足 `InlineLite` 豁免 → 停机。** 不要"先改了再说"，也不要自己顺手 grep 一遍就当评估做完了。

### 读 `AssessmentRef` 的哪几个字段，怎么用

| 字段 | 你据此决定什么 |
|---|---|
| `ActualAffectedInstances` | **改哪一层**。真实影响 1 处 → 可在模块代码锁死；影响多处 → 必须让改动对未点名实例保持行为不变（新增可选参数 / 默认值保持旧行为 / 加作用域类），否则回到 Decide 重出方案 |
| `TheoreticalReferences` vs `ActualAffectedInstances` 的差 | 差值大说明多数引用是死路径或 disabled 实例——**不要按理论数去做防御性大改**，那是过度工程 |
| `DisabledInstances` | 这些实例不验证、不动其 stored 值、不作为方案取舍依据 |
| `SharedPropagation` | 命中共享 snippet / 全局 CSS / token / build 产物 → 禁止在共享层做单点特判；改动须在共享层语义上自洽。命中 build 产物 → `BuildRequired: Yes`（红线 §8.7：改源不改产物） |
| `LegacyImpact` | 旧 section / 旧类名 / 旧断点是否连带。有连带 → 方案必须点名说明旧路径怎么处理（保留 / 迁移 / 明确不管） |
| `EntrypointCandidates` + 各自风险 | 候选入口不是让你随便挑：**低风险优先，需要改 `templates/*.json` 存值的入口默认不可用**（模板存值默认只读，未获授权 → `BlockingGaps` 停机） |
| `RiskTier` | `Low` → 可直接 Act；`Medium` → 必须走完 OODA 并等用户确认方案；`High` → 方案必须含回滚方式，且明确列出需要浏览器预览的点 |
| `RequiredQAProfile` | 原样带进你的输出块（Path A 恒含 `QA-A`）。🔴 **不得写 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进本字段是字段越界（`handoff-schema.md` §9.2） |
| `BlockingGaps` | 非空 → **不得进入 Implement**。先把缺口交回用户/impact |

### `InlineLite` 豁免（唯一可跳过 Assess 的口子）

条件在 `handoff-schema.md` §3，必须**全部**满足：改动 ≤ 1 个文件、该文件无其它引用方、非共享 snippet / 非全局 CSS / 非 token / 非 build 产物、不改 schema、不改模板存值。

这是**窄口**，不是默认路径。**默认答案是"走 impact"**；InlineLite 需要被主动证明，证明不了就不适用。

### 正向白名单（不在表内 = 不是 InlineLite，不必再论证）

只有以下三类可能适用：

| 允许类 | 说明 |
|---|---|
| **纯文档 / `.md` 改动** | 不进入主题渲染，不产生任何运行时行为或渲染差异 |
| **单个私有 snippet 的排版符号修正** | 该 snippet 恰好有 **1 个已知调用方**；且改动**只动动态输出周围的排版符号 / 空白 / 标点**，不动 schema、不动 JS 钩子、不改类名。**改的若是硬编码的 storefront 展示文案字面量 → 不适用**：那本身违反红线 §8.1，正确处理是迁到 schema / locales，属于需要 Assess 的改动 |
| **单个 section 私有 CSS 文件内的局部样式修正** | 选择器完全落在该 section 的 BEM 根类作用域内，不含全局选择器、不含被其它文件复用的类名、不改 token |

其余一律走 `plaud-theme-impact`。特别地，以下**永远不是** InlineLite，即使只改一行、即使只改注释：任何 `.liquid` 的结构 / 逻辑 / schema 改动、**任何运行时 JS 文件（含只改其中的注释）**、custom element（含其基类与继承链任一环）、Swiper 初始化参数、`locales/`、`config/`、`templates/`、全局 CSS、token、build 产物、任何新功能、任何性能优化。

**黑白名单冲突时，黑名单优先。**"这是注释所以安全"不能推翻文件所在类别的判定。

### 必须固定跑的证据维度（缺一条 = 不成立）

"无其它引用方"不是印象，也不是"随便 grep 一下 0 命中"。**注意：私有 snippet 的正确判据是「恰好 1 个已知调用方」，不是 0 命中**——搜出 0 命中通常说明搜索词选窄了，那是伪证据。

**搜索范围固定为整个主题根目录**（至少覆盖 `sections/ snippets/ assets/ templates/ layout/ config/ locales/`），用 `grep -rn`，**不得只搜当前目录、不得只搜单个文件类型**。pattern 用**去扩展名的 basename**而非全路径（全路径搜不到按名引用），命中后逐个打开确认。

逐条跑并把**命令原文 + 命中数**写进 `ReconMode` 的豁免理由：

1. 文件全路径引用
2. basename / 去扩展名（Shopify `render` / `include` / `section` 按名引用）
3. section type 名（是否被 `templates/*.json`、section group、layout 接入）
4. asset URL 引用（`asset_url` / `stylesheet_tag` / `script_tag`）
5. custom element 标签名与类继承链（若文件含 JS）
6. 改动涉及的核心 CSS 选择器 / 类名（是否被其它文件消费）
7. 动态拼接引用（变量拼 snippet 名 / asset 名的写法）

任一维度出现预期外命中 → 不是 InlineLite，走 impact。

### 其它纪律

- **拿不准就不是 InlineLite** —— 只要需要"想一下应该没别的地方用吧"，就不是。
- 单文件 ≠ 低传播。共享类名、继承、全局选择器都会让"一个文件"产生跨实例影响。
- **同一会话内最多用一次**（提醒性护栏，不是主门；主门是上面的白名单 + 七维证据）。本次改动若是上一次 InlineLite 的延伸或返工，一律走 impact——连续 InlineLite 是绕过 Assess 的典型形态。
- 用了豁免就必须写 `ReconMode: InlineLite` + **白名单归类 + §3 五个条件逐条对照 + 七维证据命令原文**。写不满 → 说明它本来就不该走豁免。

---

## 第二步：OODA 门控

非平凡任务必须走完 **Observe → Orient → Decide → Act**，且 **Act 前等用户确认方案**。

### 什么算"平凡"（判据，不留解释空间）

**同时满足全部**才算平凡，可直接 Act：

1. 改动 ≤ 1 个文件且 ≤ 约 10 行；
2. 根因当场可见、无需推断（如明显 typo、漏了 null 守卫、少写一个 aria-label）；
3. `RiskTier: Low`；
4. `ActualAffectedInstances` ≤ 1；
5. 不改 schema、不改模板存值、不改共享 snippet / 全局 CSS / token / build 产物；
6. 不改变任何组件的公开行为（DOM 结构、事件、schema 字段、CSS 类名契约都不变）。

**只要有一条不满足，就是非平凡**，必须走 OODA 并等确认。特别地，以下**恒为非平凡**，不论行数多少：新功能、性能优化、任何 Swiper effect 相关改动、任何 custom element 生命周期改动、任何触及共享层的改动、`RiskTier` 为 `Medium`/`High`。

平凡任务在输出块里 `OptionsConsidered: Trivial`，并在正文一句话说明为什么落在平凡判据内。

### 四步各自要产出什么

- **Observe** — 不重做 impact 的工作。这里只是把 Assess 工件的结论 + 目标文件当前实际代码摆出来。找不到目标文件 → 停机要路径（§7）。
- **Orient** — **机制层根因，不是表面症状**。"移动端没生效"不是根因，"inline style 优先级高于媒体查询"才是。判别方法：根因必须能解释"为什么在 A 条件下坏、B 条件下好"，且能预测同族 bug 出现在哪里。写不出这个预测，说明还停在症状层。
- **Decide** — **至少 2 个方案**，每个写清：改哪一层、影响范围、代价/风险、为什么选/不选。只有一个方案时不要凑数编第二个，而是应当承认这是"约束已经把解唯一确定"，并写清是哪个约束——但这种情况极少，多数时候第二方案是"在更上游的层改"。方案取舍受 `EntrypointCandidates` 风险排序约束。
- **Act** — **最小化实现**。不顺手重构、不顺手改格式、不扩散到 `ModifiedFiles` 之外的文件。发现的其它问题写进正文的"顺带发现"，不动手。

---

## 第三步：按任务类型执行

详细步骤见 `references/task-workflows.md`（按本次任务类型只读对应一节）。要点索引：

| 任务类型 | 核心纪律 |
|---|---|
| **性能优化** | 恒非平凡。高频项：DOMParser 复用、timer/observer/监听/subscription 在 `disconnectedCallback` 清理、图片 `width`/`height` 防 CLS（清晰度红线见 shared `media-quality.md`）、循环内 snippet 不重复输出 `stylesheet_tag`、懒加载与 Swiper effect 的兼容性（**具体哪些 effect、怎么处理，一律现查 shared `javascript-swiper.md`，不得凭记忆改参数**） |
| **新功能** | 恒非平凡。OODA → PRD（≥2 方案）→ **用户确认** → 实现。**未经用户确认不得直接编码** |
| **Bug 修复** | 根因 → 最小修复 → **同族扫描**（一个 bug 常伴 3–5 个同族），见 `references/bug-family-scan.md` |
| **UX 微调** | CSS 变量桥接、overflow / z-index 链路检查、对比度（红线 §8.5） |
| **code review / A11y 审计** | **只读任务**，不改代码。输出问题清单 + 严重度 + 建议改法。`ModifiedFiles: []`、`ChangeSetId: N/A` |

### 只读任务（零改动）的契约变形 —— 全部取自 `handoff-schema.md` §2「零改动任务」

**无 `ChangeSetId` 的只读审计（code review / A11y 审计）归本 skill**，不归 `plaud-theme-qa`——QA 的触发前提是「已有 `ChangeSetId`」或「用户明确要最终交付判定**且该任务确有改动**」。🔴 零改动时用户要「最终判定」也不转 QA（v0.2.2 第八轮修的 dev↔QA 回环）：直接答复「零改动没有 ChangeSet 可绑，不存在交付判定」，出 `ReadOnlyProof` + `ReadyForDelivery: N/A(ReadOnly)` 收尾。

| 字段 | 只读任务取值 |
|---|---|
| `ChangeSetId` | `N/A` |
| `BaseHeadSha` / `ChangeSetFingerprint` | `N/A` |
| `ReadOnlyProof` | **必填**，见下 |
| `AssessmentRef` | `N/A(ReadOnly)` |
| `ReconMode` | `N/A(ReadOnly)` |
| `ModifiedFiles` | `[]`（不要留空 scalar） |
| `ThemeCheckRequired` / `VisualRegressionRequired` / `BuildRequired` | `No` |
| `OptionsConsidered` | `Trivial` |
| `QAStatus` | `NotRun` |
| `NextRequiredSkill` | `None`（零改动免 QA） |
| `ReadyForDelivery` | `N/A(ReadOnly)` |

> 🔴 **只读任务不得借用 `ReconMode: InlineLite`**（`handoff-schema.md` §2）。InlineLite 是"改动小到可以内联评估"，只读是"根本没有改动"，两者不是一回事；混用会让只读任务继续输出 `QAStatus: NotRun` / `ReadyForDelivery: No`，与本表冲突。只读任务的 `ReconMode` 一律 `N/A(ReadOnly)`，也**不需要**跑 InlineLite 的七维证据。

#### 🔴 零改动必须有证明（`ReadOnlyProof`）

否则可以先改代码、再输出 `ModifiedFiles: []` 并声称"这只是审计"，从而完全绕开 QA。**审计开始前和结束后各取一次快照，两次必须完全一致**：

```bash
# 🔴 用 handoff-schema §2 那段 plaud_fingerprint，原样复制。
git rev-parse HEAD
plaud_fingerprint
```

> 🔴 **不要用 `git status --porcelain | shasum` 做这个快照**（v0.2.2 第五轮修）：它只含状态码与路径、不含内容。工作树**一开始就 dirty** 时，审计中改**同一个文件的内容**，前后两次 hash **完全相同**（已实测复现）——那正好是本节要堵的"先改代码再声称只读"，旧命令堵不住。

两次的 HEAD 与 hash 如实写进 `ReadOnlyProof`。**两次不一致 = 这不是只读任务**：立即退出只读通道，生成正式 `ChangeSetId` + `BaseHeadSha` + `ChangeSetFingerprint`，走完 Assess → Implement → Verify。不得以"只是顺手改了一点"为由留在只读通道里。

**不免措辞禁令**：审计结论只能陈述"发现了什么"，不得断言"这个模块没问题 / 可以上线"。
若审计后用户要求真的动手改，那是**新的一次 Implement**，重新生成 `ChangeSetId` 走完整流程。

---

## 第四步：输出

正文按 Path A 模板组织（完整模板与写法见 `references/output-template.md`）：

```
## 依赖树
（来自 Assess 工件；标明哪些是 impact 报的、哪些是本次新发现）

## 根因（Orient）
（机制层，不是症状）

## 方案（Decide）
（≥2 方案 + 取舍；平凡任务写 Trivial 及判据依据）

## 待 QA 验证的点
（列出该验什么，不写验证结果）

## 改动清单（Act）
（文件 + 一句话）
```

> **「待 QA 验证的点」不是回归矩阵结果。**你只负责标明"该验什么"——覆盖哪些 layout mode / schema 选项 / block type / Swiper effect / 关键开关，需要哪几个断点、要不要浏览器预览、要不要英译德长文案检查、要不要 admin schema 保存验证。**具体断点档位、长文案语种规则见 shared reference 与 `handoff-schema.md` §5，不在此复制。**每一项写成"待验：…"，禁止写成"已验证 / 通过 / 无异常"。

---

## 停机点（`BlockingGaps` 非空则不得继续）

- 找不到目标 section / snippet / asset 的实际文件 → 停，要路径
- 拿不到 Assess 工件且不满足 `InlineLite` → 停，先做 Assess
- Assess 工件的 `BlockingGaps` 非空 → 停，先补齐
- 需要编辑 `templates/*.json` 模板存值但未获授权 → 停，要授权
- 方案需要用户拍板（≥2 方案取舍、非平凡任务、新功能 PRD）→ 停，等确认再编码
- 需要浏览器预览才能确定行为但无法预览 → 停/标明，**不猜"应该没问题"**
- 改动会触及共享层但 Assess 未覆盖该传播链 → 停，回 impact 补

停机时输出 `BlockingGaps` 并明确写出**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"。

---

## 交付工件时**当场**生成指纹（`handoff-schema.md` §2）

`ChangeSetId` 只绑 `ModifiedFiles` 的**文件名集合**是不够的：交出工件之后、QA 开始之前，如果同一批文件的**内容**又被改过，文件集合仍然一致，QA 会错误地判 `ChangeSetIdMatched: Yes`，验的是一批它从未见过的代码。

因此**在写 yaml 块的那一刻**（不是改动开始时、不是估算）跑下面两条，把结果填进 `BaseHeadSha` / `ChangeSetFingerprint`：

```bash
# BaseHeadSha
git rev-parse HEAD
```

🔴 **`ChangeSetFingerprint` 的命令不在本文件里，只在 `plaud-theme-shared/references/handoff-schema.md` §2。**
去那里**原样复制**那段 `plaud_fingerprint()` 执行，不要凭记忆敲、不要用任何别处看到的版本。

> **为什么这里不再内嵌一份副本**（v0.2.2 删除）：本节以前抄了一份，附一句"冲突时以 §2 为准"——但那句话拦不住任何人：命令是**可执行**的，抄本一旦落后就会真的算出另一个指纹。这份抄本当时落后了整整两代，仍在用 `--find-renames=false`、`printf "$(git hash-object …)"`（命令替换吞错）、`{ … } | shasum`（子 shell 吞错）、且不排除 `memory/`。
> 后果不是"多阻断"，而是**producer 算出一个假指纹、QA 用 canonical 重算必然失配**——正常交付会被永久判 `ChangeSetIdMatched: No`；反过来若两边都用旧抄本，则未跟踪文件与 `memory/` 之外的改动可能压根不进指纹。
> 指纹类命令**只允许有一处事实源**。

QA 会在**执行任何检查之前**用同一命令重算并精确比对；不一致即 `ChangeSetIdMatched: No` + 停机。**生成指纹后不要再动工作树**——包括"顺手把格式化跑一下"。

零改动（只读）任务这两个字段填 `N/A`，改填 `ReadOnlyProof`。

---

## HandoffContract（回复的最后必须是这个 yaml 块）

字段取自 `plaud-theme-shared/references/handoff-schema.md` §4，**字段名与顺序一字不差**，不得改名、不得省略、不得自造。

```yaml
ChangeSetId:             # CS-<YYYYMMDD>-A<NN>；只读 review/审计任务填 N/A
BaseHeadSha:             # 交付工件时的 git rev-parse HEAD；零改动填 N/A
ChangeSetFingerprint:    # 见 §2，交付工件时当场生成；零改动填 N/A
ReadOnlyProof:           # 仅零改动任务：审计前后两次快照的 HEAD + hash，必须一致；其余填 N/A
AssessmentRef:           # ASMT-<YYYYMMDD>-<NN>；InlineLite 时填 InlineLite；只读填 N/A(ReadOnly)
OriginTriageRef:          # 本块若由反馈返工产生：TriageId + ItemId；否则 N/A
Path: A
ReconMode:               # LegacyImpact | InlineLite（须附豁免理由 + 判定命令原文）；只读填 N/A(ReadOnly)
ModifiedFiles:           # 逐个文件路径 + 一句话改动；必须与工作树一致；只读任务填 [] （不要留空 scalar）
                         #   🔴 **不含 memory/ 下的文件**（不属于 ChangeSet，已排除在 §2 指纹与 QA 集合比对之外）
RootCause:               # 机制层根因
OptionsConsidered:       # 非平凡 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:       # QA-A（可多选 QA-B / QA-C）。🔴 不得写 QA-Global——QA 按 §5 恒执行
ThemeCheckRequired:      # Yes | No
VisualRegressionRequired: # Yes | No
BuildRequired:           # Yes | No
ApprovedExceptions:      # 逐项声明的 🟠 ApprovedException；无则填 []
                         #   Clause 只能取 shared §8.1 封闭清单内的条款；Scope 必须逐对象/配对绑定
                         #   ApprovalRef 为空、或 ApprovedBy 是自己 → QA 判 Failed（见 shared §8.1）
                         #   🔴 双周会「已同意但清单尚未更新」的条款**不得**写进来（Clause 越界 = 谎报，
                         #      QA 判 ApprovedExceptionsChecked: Failed）。正确处理：本字段保持 [] 或不列该项，
                         #      条款按其当前档位照常判，BlockingGaps 记
                         #      PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>
                         #      清单扩容只能由 maintainer 在新版本快照里做（见 shared §8.1「封闭清单的变更权限」）
BlockingGaps:
QAStatus: NotRun
NextRequiredSkill: plaud-theme-qa-intake   # 零改动任务填 None
ReadyForDelivery: No     # 恒为 No；零改动任务填 N/A(ReadOnly)
```

> ⚠️ 每个 `key:` 与注释之间**必须有空格**。YAML 里 `Key:# 注释` 是解析错误，照抄时不要压掉那个空格。

`ChangeSetId` 格式 `CS-<YYYYMMDD>-A<NN>`，`<NN>` 为当日 Path A 的序号，从 `01` 起。
`QAStatus` / `Path` 为常量，任何情况下不得改写（`QAStatus` 的唯一其它合法取值是用户明确弃检时的 `Skipped(UserWaived)`）。`NextRequiredSkill` / `ReadyForDelivery` 只在**零改动只读任务**下取 `None` / `N/A(ReadOnly)`，其余情况恒为 `plaud-theme-qa-intake` / `No`。
交出这个块之后，你这一轮的话到此为止——下一句该由 `plaud-theme-qa` 说。
