# Path A 按任务类型工作流

只读与本次任务对应的那一节。所有节共享 SKILL.md 的三条前置：Assess 工件已到手（或合法 `InlineLite`）、OODA 门控已过、终态措辞禁令生效。

**本文件不复制任何视觉数值、Swiper effect 约束表、主题架构速记。**它们的唯一副本在 `plaud-theme-shared/references/`（`javascript-swiper.md` / `media-quality.md` / `typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` / `liquid-schema-format.md` / `a11y.md`）。

---

## 1. 性能优化

**恒为非平凡任务**：必须走完 OODA，方案需用户确认。

### 步骤

1. **从 Assess 工件读传播链** — 性能改动几乎必然落在共享层（共享 JS bundle、全局 CSS、循环内 snippet；**具体有哪些共享 JS 文件、各自承载什么，查 shared `javascript-swiper.md` 的主题架构速记，不要凭记忆列**）。`SharedPropagation` 决定改动能不能就地做。
2. **先量化，再归因** — 说清楚"慢在哪个阶段"：解析阻塞 / 重复计算 / 重复 DOM 构建 / 布局抖动（CLS）/ 资源重复下载 / 内存泄漏。归不出阶段就还没到 Orient。
3. **Decide** — 至少两个方案，典型对立轴是「就地优化」vs「上移到共享层复用」vs「延后加载」。写清每个方案对未点名实例的行为影响。
4. **Act 最小化** — 只改定位到的那一处机制，不顺手重写模块。
5. **标明待 QA 验证的点** — 性能改动的验证点通常包含：改动前后行为一致性、Swiper effect 是否仍正常、custom element 反复插拔后无残留监听、图片是否仍防 CLS 且未被下采样糊掉。

### 高频项清单（逐条对照，命中即处理）

| 高频项 | 症状 / 代价 | 处理方向 |
|---|---|---|
| **DOMParser 重复 new** | 每次调用新建解析器，热路径上开销累积 | 复用单例 parser 实例 |
| **timer / observer / 监听 / subscription 未清理** | custom element 反复插拔后泄漏、回调重复触发 | 全部在 `disconnectedCallback` 清理（红线 §8.6） |
| **图片缺 `width` / `height`** | CLS 布局抖动 | 补尺寸属性防 CLS；**取值规则见 shared `media-quality.md` 的清晰度红线**——`width:` 只防 CLS / 适配容器，不得取过小值把展示图下采样糊掉（红线 §8.3） |
| **循环内 snippet 输出 `stylesheet_tag`** | 同一样式表被输出 N 次 | 样式表输出移到循环外 / section 顶层，循环内 snippet 只出结构 |
| **Swiper 懒加载 / effect 相关** | 图不加载、白块、渲染异常 | **本文件不持有任何 Swiper 结论。**改 Swiper 参数或排查其图片加载问题前，必须先读 shared `javascript-swiper.md` 的 effect 约束表，按表判定 |
| **section 内 `<style>` 输出了规则而非仅自定义属性** | 重复 CSS、优先级混乱 | 保持 section 内 `<style>` 只输出 CSS 自定义属性，规则落到 `assets/*.css` |

---

## 2. 新功能

**恒为非平凡任务。未经用户确认不得直接编码。**

### 步骤

1. **依赖树 / Assess** — 新功能常常挂在既有 section 上，属于 `LegacyImpact`；纯新增且无存量调用方时由 impact 走 `IntegrationSurface`。不要自己给新功能编"模板使用量"。
2. **OODA** — Observe 现有实现与可复用基类。**先查 shared `javascript-swiper.md` 的主题架构速记，确认这类交互有没有既有基类可继承，再决定新写还是继承**——本文件不列基类清单（会与 shared 漂移）；不查就新写一套是重复造轮子。
3. **PRD（≥2 方案）** — 至少包含：功能边界、数据来源（Liquid data attribute → `window.siteData` → 异步 fetch → 第三方 API，越靠后越是最后手段）、schema 字段设计（展示文案必须走 schema 或 locales，红线 §8.1）、响应式与断点策略（走 CSS 自定义属性，不写 inline style）、无障碍要求、两个及以上实现方案 + 取舍。
4. **等用户确认** —— 这一步是硬门。用户未对 PRD 表态前，`BlockingGaps` 写「方案待用户拍板」，**不落任何代码**。
5. **实现** — 最小化，按确认的方案落地。
6. **标明待 QA 验证的点** — 新功能通常需要：空配置 / 满配置双测、schema 在 admin 能保存、多语言长文案、断点覆盖、A11y 底线、Theme Check。**你只列清单，不跑、不判定。**

---

## 3. Bug 修复

### 步骤

1. **依赖树 / Assess** — 从 `ActualAffectedInstances` 判断这是单实例问题还是共享层问题。单实例问题**不要**在共享层改。
2. **根因（Orient）** — 机制层。判别标准：根因必须能解释"为什么条件 A 下坏、条件 B 下好"，并**能预测同族 bug 出现在哪里**。做不到预测就还没到根因。
3. **最小修复（Act）** — 只改根因那一处。不顺手重构、不顺手改格式。
4. **同族扫描（必做）** — 见 `bug-family-scan.md`。**一个 bug 常伴 3–5 个同族 bug**，修完必须主动扫同族。
5. **标明待 QA 验证的点** — 含同族扫描结果里"已确认存在但本次未修"的项，交给 QA 与用户决定是否另起 ChangeSet。

### 症状 → 根因 → 修复对照表

这是历史高发表，可扩充，不可当成穷举。**先按对照表怀疑，再验证，不要直接照抄修法。**

| 症状 | 机制层根因 | 修复方向 |
|---|---|---|
| 移动端样式不生效 | inline style 优先级高于媒体查询，媒体查询根本没机会命中 | CSS 变量桥接：inline 只写自定义属性值，规则在样式表里按断点消费 |
| 下拉 / 浮层不显示或被切掉 | 祖先链上某级 `overflow: hidden` 裁切 | 打开态把该级切成 `overflow: visible`（或改用脱离该裁切上下文的定位方案）；连带检查 z-index 链 |
| Swiper 图不加载 / 渲染异常 | 与该 effect 的渲染与加载约束相关 | **根因与处理方式一律以 shared `javascript-swiper.md` 的 effect 约束表为准**；本表不持有 Swiper 结论 |
| 点击触发多次 | 事件重复注册（元素被复用 / `connectedCallback` 多次触发 / 未解绑） | 只注册一次，或注册前先 `removeEventListener`；并在 `disconnectedCallback` 清理 |
| custom element 复用后行为错乱 | 生命周期未清理，旧监听 / timer / observer 残留 | `disconnectedCallback` 统一清理（红线 §8.6） |
| 报 null / undefined 崩在初始化 | 缺 null 守卫或 TDZ 问题（`section.id` 不存在、DOM 尚未插入） | 加守卫；确认取值时机在 `connectedCallback` 之后 |
| 同页组件互相干扰 | 同页 id 重复（含 `{{ section.id }}` 用法不当） | id 加 section 作用域，或改用 data attribute 定位 |
| 文案在某语言下溢出 / 遮挡 | 组件写死宽高或按英文长度设计（红线 §8.2） | 用内容、比例、`min-*` / `max-*`、容器与断点变量驱动尺寸 |

---

## 4. UX 微调

平凡判据同 SKILL.md；多数 UX 微调是**非平凡**，因为往往触及共享 CSS 或多实例。

### 检查顺序

1. **值从哪来** — 字号 / 颜色 / 间距 / 圆角 / 断点一律走 token 或 CSS 自定义属性（红线 §8.4）。**具体取值查 shared `typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md`，不要凭印象填数，也不要在本 skill 的产出里复制这些数值。**
2. **CSS 变量桥接** — 响应式值走自定义属性，不写 inline style；端变量 → 运行变量 → 属性消费运行变量。
3. **overflow / z-index 链路** — 改浮层、hover 态、展开态前，先把祖先链的 `overflow` 与层叠上下文捋一遍。
4. **对比度与焦点** — 前景/背景改动必须过对比度底线与 `focus-visible`（红线 §8.5，阈值见 shared `a11y.md`）。
5. **写死宽高** — 不得为了对齐而写死组件 `width` / `height`；例外范围与说明义务见红线 §8.2。
6. **文案可配置性** — 顺手改到的展示文案必须仍走 schema / locales，不得 `| default: '...'` 兜底（红线 §8.1）。

---

## 5. code review / A11y 审计（只读任务）

**不改代码。**输出问题清单，交由用户决定是否另起一次 Implement。

### 输出格式

每条问题写成：

```
[严重度] <文件>:<行> — <问题>
根因：<机制层>
建议：<改法，一句话>
命中红线：<§8.N 或"无">
```

严重度用 `Blocker` / `Major` / `Minor` / `Nit` 四档。`Blocker` 限于：会导致运行时报错、内存泄漏、数据丢失、明确违反全路径红线且用户可见。

### A11y 审计覆盖面

按红线 §8.5 逐条核：button 语义（不是 `div` 挂 click）、`aria-label`、dialog `trapFocus`、轮播控件是 button + 有 label、对比度、skip link、`focus-visible`。**阈值与细则见 shared `a11y.md`。**

### code review 覆盖面

Liquid / CSS / JS 质量规则（细则见 shared `liquid-schema-format.md` 与 `javascript-swiper.md`）：HTML 尺寸属性只能是数字、同页 id 不重复、展示文案走 schema/locales 且无 `| default` 兜底、`blank` 不输出空壳 DOM、`image_url` 带 `width:` 且未下采样糊图、生产代码无 `console.log`、响应式值走自定义属性、section 上下间距走 schema / 主题类而非硬编码 margin、JS null 守卫 / TDZ 安全 / `disconnectedCallback` 清理、build 产物未被手改。

### 输出块

按 `handoff-schema.md` §2「零改动任务」取值：`ChangeSetId: N/A`、`BaseHeadSha: N/A`、`ObjectFormat: N/A`、`ThemeTreeOid: N/A`、`ChangeSetScopeFingerprint: N/A`、`ModifiedFiles: []`、`AssessmentRef: N/A(ReadOnly)`、`ReconMode: N/A(ReadOnly)`（**不得借用 `InlineLite`**）、`RootCause` 写审计范围内的共性根因（无则 `N/A`）、`OptionsConsidered: Trivial`（只读任务无实现方案）、`ThemeCheckRequired: No`、`VisualRegressionRequired: No`、`BuildRequired: No`、`QAStatus: NotRun`、`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`。

`ReadOnlyProof` **必填**：审计前后各跑一次 **§2.5 的 `plaud_theme_tree`**（handoff-schema §2.5 整段原样复制），两次的 `ObjectFormat` + `ThemeTreeOid` 必须逐字相等（**不比 HEAD**）；不一致即退出只读通道，生成正式 ChangeSet 走全流程。
🔴 **不要用 `git status --porcelain | shasum` 做这个快照**：它只含状态码与路径、不含内容，工作树一开始就 dirty 时改同一文件的内容前后 hash 相同——等于给「先改代码再声称只读」开了后门（v0.2.2 第五轮实测复现）。

**审计"没发现问题"也不等于可交付**——只能陈述发现了什么，不得断言"这个模块没问题 / 可以上线"。
