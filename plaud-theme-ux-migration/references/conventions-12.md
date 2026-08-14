# 模块迁移 12 条约定 + 加载分层（FOUC 防治）

12 条约定在 v1.3 wave 已全部落地，**每次迁移一个模块都必查**。
数值（字号 / 色值 / 间距 / 断点）见 `plaud-theme-shared/references/`，本文件只写结构与选择规则。

---

## 一、12 条约定

| # | 规则 | 反例 / 守则 |
|---|---|---|
| **1** | **HTML 三层结构**：outer wrapper（scheme + `overflow-hidden` **同层**）→ inner container（id + `container` + `section_top_pc/bottom_pc`）→ 内容 | 不要把 scheme 类放 `__outer`、把 overflow 放 outermost —— 同层维护更直观 |
| **2** | **schema 四件套**统一加：`enable_color_scheme` + `color_scheme` + `remove_duplicate_spaces` + `section_disclaimer` | 字段位置与 Faq List TT 一致；配色相关字段（`color_scheme` / 自定背景色板）可加 `visible_if: "{{ section.settings.enable_color_scheme }}"`，仅勾选 opt-in 时显示。<br>🔴 **例外**：模块本来就 **scheme 常开**（每实例都有方案、无开关，如 Floating Image TT）→ **不加 `enable_color_scheme` / `visible_if` 两段式开关**，直接 `color-{scheme} use-color-scheme` 常开（保原行为 + 补 spec 重绑），余下 `remove_duplicate_spaces` / `section_disclaimer` 照加 |
| **3** | **schema option values 永远不改**，stored 实例值优先 | 想换 emit 出来的 class / token，**只在 Liquid 端做映射**。这是用户硬规则（`hard-rules.md` §2.2），不是风格偏好 |
| **4** | **`left/right` 对齐可直接 emit**（映射降为可选） | **2026-06 更新**：`.text-left! / .text-center! / .text-right!`（及 `start` / `end`）现已确认在 critical bundle（base-style）里，区头 / 免责声明等**可直接 emit 物理值** `text-{align}!`，不必再映射（Floating Image TT 区头对齐即如此）。`right → end` / `left → start` 映射降为**逻辑属性偏好（非必须）**；**仅当 emit 后某值确实未生效**，再退回 `\| replace: 'right','end' \| replace: 'left','start'` |
| **5** | `enable_color_scheme` checkbox **不加 info** | label 已自解释 |
| **6** | **`enable_color_scheme` 默认值按模块历史决定** | 历史有非空 stored 值 → `true`；否则 `false` |
| **7** | **`anchor_id` 在 `.container` 同层** | 跳转锚点要落在**内容上沿**，不是 wrapper margin 之上 |
| **8** | **`section-disclaimer` 用 utility class** 挂 HTML，对齐跟随 `header_align_pc/mb`（同一映射变量） | 不要在 disclaimer CSS 里重写字号 / 颜色——`design-utilities.scss` 里已 direct token 消费 |
| **9** | **`bg-white` 与 scheme 互斥** | card 模式（默认 `bg-white`）vs full-bleed scheme，**二选一** |
| **10** | **Card-identity 模块不接 scheme** | 如 SA: Team DTC Landing —— 卡片是模块身份特征，scheme 全宽接管会破坏 |
| **11** | **`btn-primary` 颜色 lock 不必要** | 默认 scheme 已是 brand-dark；scheme on 时商家选什么 scheme 就接受 |
| **12** | **若模块 CSS 硬锁 spec token，必须用 `:not(.use-color-scheme)` 守卫** | 否则 scheme 开关**失效**（token 被硬锁，重绑不生效） |

---

## 二、加载分层 → utility class vs 组件 CSS

**这是 FOUC 防治规则，不是代码风格。**

| 类型 | 加载层 | 字号 / 颜色处理 |
|---|---|---|
| **Universal**（每页都用）<br>`cs-section-header` / `section-disclaimer` / `.container` | `design-utilities.scss` → critical inline | **组件 CSS 直接消费 token**：`color: var(--color-label-primary)` |
| **Section-scoped**（部分页面用，**async**）<br>FAQ / accordion / pricing card 等 | `shopify-common/sections-*` | **utility class 挂 HTML**：`<div class="faq-question fs-headline text-secondary">` |

**理由**：section-scoped 模块的结构 CSS 走 async，字号 / 颜色若也写在 async CSS 里会在首次 paint 时 FOUC。
utility class 来自 critical bundle、已加载，**HTML 解析瞬间生效**。

### 2.1 补充一：不止字号 / 颜色

首屏可见的 box 样式（**内边距 / 背景 / 圆角 / 间隙**）放进 async SCSS **同样 FOUC**，也应走 critical 工具类挂 HTML（`.pad-4` / `.bg-soft` / `.radius-base` / `.gap-sp-6`），**不要写进模块 SCSS**。

> 别只搬字号、把颜色 `var(--color-*)` 留在 async CSS——**同样 FOUC**（2026-06-30 对比弹窗踩过）。字号和颜色**都要避**。

### 2.2 补充二：动态内容例外（无法挂类 → 合理保留 token）

metaobject / 富文本字段渲染出来的标签（如对比表 value 里运营填的 `<p>` / `<t>` / `<span>`）markup 不可控、**加不了 utility 类**，其字号 / 色只能在（可能 async 的）组件 CSS 用 descendant 选择器消费 `var(--token)`。

**这部分 FOUC 不可避免，是允许的例外**——只把**结构可控**的元素搬到 critical 工具类即可，不必为动态内容强行造类。

### 2.3 怎么判断某 bundle 是否 async

看 `layout/theme.liquid`（或引用它的 section）加载该 bundle 时是否用：

```
media="print" onload="this.media='all'"
```

- **有** = async → 受本节全部约束
- **无**（普通 `stylesheet_tag`，如 `main-cart.min.css`）= 同步 → 无 FOUC 顾虑，响应式 scss 可放心用（见 `pitfalls-css.md` §4.9）
