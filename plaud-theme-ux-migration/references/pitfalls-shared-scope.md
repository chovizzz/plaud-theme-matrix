# 踩坑库 — 共享面 / 全局面（§4.4 §4.5 §4.6 §4.6.1 §4.11 §4.14 §4.15 §4.20）

> **配方前提**：本文件是「**已获授权的迁移中怎么做**」，不是做出改动的授权本身。
> 一律在 Path C 硬规则之下运行：① `templates/*.json` 默认只读；② 组件内不写死颜色、不逐元素开 color picker（vendor §3.3 / §3.4），**特例见 §4.6**；
> ③ 不写死组件宽高；④ 非 spec 值等距两可**问用户**、不擅自 snap；⑤ schema option values 不改、验收前不写 UX 差异日志内容。
> 冲突时**以硬规则 + 其授权为准**。完整总纲见 SKILL.md「§4.x 配方的适用前提」。
>
> 本文件覆盖的都是**共享 / 全局面**的改动 —— 这类改动的影响面数据一律来自 `AssessmentRef`
> （`plaud-theme-impact` 的 `SharedPropagation` / `ActualAffectedInstances`），**本 skill 不自行重算 blast radius**。

---

## §4.4 schema 放宽的向后兼容

放宽 `step` / `min` / `max` 前确认：

- **老的合法值在新约束下仍合法**（例：`step:5` 下的 0/5/10/…/50，在 `step:1, max:60` 下仍合法）
- **默认值改动只影响「新建」实例**，存量不变
- **删 schema 字段**（如字号锁定后移除 H1–H6 select）**允许**：模板里残留的该字段 stored 值被 Shopify 忽略、不报错。
  这与"templates 只读"**不冲突** —— 只读约束针对**主动改模板存值**，不针对删 schema 定义
- 删字段后仍须跑 dangling 引用扫描（见 `hard-rules.md` §三）

## §4.5 utility 覆盖按需补全

工具清单**非永久完备**（如曾缺全向 padding，后补了 `.pad-*`）。缺 spec 值对应 utility 时**补到 `design-utilities.scss`，别内联**：

1. **扫冲突**：新类名不撞 Tailwind（`.p-*`）、旧主题（`.py-*` / `.px-*`）、HTML 裸类引用
2. **加类 → build → 校验已进 critical**（`design-system.liquid`）
3. **命名避开既有命名空间**（`.pad-*` / `.gap-sp-*` 前缀即为此）

> 复用别人加的 utility 前也先 grep 确认**已 build 进** `design-system.liquid`。

## §4.6 配色方案下的固定色（免疫元素）

开启 `use-color-scheme` 后，任何读 `--color-*` token 的类（含 `.bg-soft` / `.text-*`）都会 **rebind 跟随商家方案**。
某 chrome 元素（如标签栏背景、卡片色面）若需在方案下**保持固定色**，就不能用 token 类 —— 用固定值（内联 / `<style>`，🔴 **仅在设计明确要求且用户确认后**），或给一个**独立色板**配置让商家自定。
**"免疫固定色"与"跟随方案"不可兼得**，按需取舍。

> ⚠️ **2026-06 更新（配色方案标准化）**：配色方案已新增 **UX Spec Colors 分组**，并修正了 `use-color-scheme` 重绑 ——
> 下面的"塌缩"问题**大部分已在方案层解决**，独立色板配方**多数场景不再需要**。

### 当前 `use-color-scheme` 重绑（开启方案时）

| spec token | 重绑到（方案字段） | 说明 |
|---|---|---|
| label-secondary（副标题 / 正文） | `secondary_text_color` | — |
| 🪦 ~~label-tertiary~~ | **重绑立即移除** | 该档已废止（shared `colors-and-schemes.md` §2.1）。加兼容 alias 的**同一步**就要删掉这条重绑，否则方案一开启 alias 就失效 |
| bg-card / bg-soft（卡片 / 浅起面） | `surface_color` | **不再塌成区块底** |
| separator（分隔线） | `separator_color` | 已与 `border_color` **脱钩** |
| label-disabled（禁用） | **不重绑** | 固定 spec 值，不随方案 |
| label-inverse-primary / -secondary（深底反色白字） | **不重绑** | 固定 spec 值。方案系统没有"深底 / 反色"档，早期错误重绑到 heading/text 会让深底元素（页脚深底、深色促销条、图上白字 caption）在方案下**变深字、对比度失效**；2026-06-30 已从 `.use-color-scheme` 移除重绑（改的是 shopify-common 源 `design-utilities.scss`，**需 build**） |
| label-primary / bg-white / bg-primary | heading_color / background | 仍跟随方案 |

各字段默认色值见 `plaud-theme-shared/references/colors-and-schemes.md`（本文件不复制）。

**残留陷阱**：仅 `.bg-white` 与区块大底（bg-primary）仍跟随方案背景。
需要"白卡片 vs 有色大底"两层时 → **白卡片改用 `.bg-card` / `.bg-soft`**（走独立 surface 色）即可拉开层次。

### 卡片类模块 + 配色方案 → 现在多数直接「跟随 scheme」即可

卡片用 `.bg-card` / `.bg-soft`，开方案自动取独立 surface 色、与大底拉开层次。仅以下另作处理：

| 选择 | 适用 | 做法 |
|---|---|---|
| **跳过 scheme**（约定 #10） | 卡片就是模块身份、不希望被方案接管 | 不加 scheme |
| **独立色板**（**仅特例**） | 卡片固定色要**与方案 surface 色不同**、且需单独可调 | 见下方配方 |

### 独立色板具体配方（scheme 关用 spec token、开用商家自定固定色）

1. schema 加 `color` 字段，`visible_if` 仅在勾选 opt-in 时显示。
   🔴 **Path C 迁移特例**：给「已存在」模块的卡片固定色开 color picker，是对 vendor §3.4「后台不提供独立字体颜色配置」的**受控例外** ——
   **仅当**卡片固定色须区别于方案 surface、且需运营可调时用；**新建 `sa-*` section 不得套用**（多数场景 §4.6 更新后已不需要独立色板）。

   ```json
   { "type": "color", "id": "card_background_color", "label": "Card Background Color",
     "default": "<spec surface 色，取自 shared colors-and-schemes.md>",
     "visible_if": "{{ section.settings.enable_color_scheme }}" }
   ```

2. 用**自定义变量名**（不在 `use-color-scheme` 重绑列表里 → **天然免疫**），条件式赋值：

   ```liquid
   --card-bg: {% if section.settings.enable_color_scheme %}{{ section.settings.card_background_color | default: '<同上 spec surface 色>' }}{% else %}var(--color-bg-tertiary){% endif %};
   ```

   - scheme **关**：走 spec token（无 `use-color-scheme` 不 rebind）→ 与未迁移前同色，**零回归**
   - scheme **开**：用商家色板的字面 hex（固定值）→ **免疫 rebind**，卡片色面独立于区块底色

3. 元素消费 `background-color: var(--card-bg)`，**不要**用 `.bg-soft`（它会随方案塌缩）

> 🔑 第 2 步的"自定义变量名"是免疫的关键：`use-color-scheme` **只重绑 `--color-*` 系列**，自起的 `--card-bg` / `--xxx-bg` 不在其列。

### §4.6.1 "给共享 section 接入配色方案 / 加 `use-color-scheme`"的真实影响（2026-06-30）

> **分工**：`ActualAffectedInstances` 的**结论**由 `plaud-theme-impact` 产出，本节记录的是它所依据的**机制**——
> 迁移时用它来**判断该不该走独立色板 / 该怎么落地**，以及**核对 impact 的收敛结论是否讲得通**。**不是让你再 grep 一遍。**

给一个**共享** section 补 `use-color-scheme`，**真实视觉影响 ≠ 理论 blast radius**，三点收敛：

1. **只有用了 spec 颜色类的元素才会被重绑**：`use-color-scheme` 只改 `--color-label-*` / `--color-bg-*` / `--color-separator-*` 这些**变量**，不直接设 `color`。
   所以内容里写死 hex（含 `<style>` 注入块）、内联 `style="color:…"`、或只用 `py-*` / `fs-*` / `text-center` 等**非颜色类**的元素**完全不受影响**；
   只有挂了 `.text-*` / `.bg-*` / `.separator-*` 的元素才跟随
2. **方案默认态 ≈ 零变化**：v1.3 已把配色方案的默认色设成 spec 值。所以只要商家**没自定义**方案色，重绑前后同值、**无视觉差**；只有**自定义过的方案**才会偏移
3. **空 `color_scheme: ""` 的行为**：wrapper 类变成 `color-`（匹配不到任何 `.color-{id}`）→ 继承 `:root`，而 `:root` 挂了**第一个 / default 方案**的色（`theme.liquid` 把首个方案选择器写成 `:root, .color-{id1}`）。
   所以 **空方案 + use-color-scheme = 跟随 default 方案**，不是"无方案"

→ 据此判断："改的是共享文件"**不等于**"全站都会变"；逐项核查后往往真实影响很小。

> 📎 **历史案例（2026-06-30 custom-html，非当前拓扑断言）**：表面 17 模板 + footer，逐项核查后实际仅 footer 一条分隔线变化。
> **不要把这个数字当成 custom-html 的现状** —— 当前实例数与调用方一律取自 `AssessmentRef`。

## §4.11 `<source media>` 断点也用 spec 的 `.98` 精度

`<video>` / `<picture>` 里 `<source media="...">` 选择移动 / 桌面源的断点，**必须和 CSS 用同一个 spec 断点值、同样的 `.98` 精度**——
用整数值（如 768）会在整边界上**视频源与桌面布局错位**。断点值本身见 `plaud-theme-shared/references/responsive-and-spacing.md`。

> 顺带：改到旧代码时留意**残留的整数断点** —— `767` / `768` / `1024` / `1025` 这类**杂散历史值**（它们不是 spec 值，是遗留错误），
> 一律换成 spec 的 `.98` 精度断点。
> 改附近就顺手统一 —— 🔴 **仅限本次授权影响范围内；范围外登记「待评估」、勿扩散。**

## §4.14 第三方插件文字样式对齐（不改插件生成文件，主题层覆盖）

商品 / 购物车页常嵌第三方应用（Affirm 分期、Klarna 分期、Selleasy 捆绑、Judge.me / Okendo 评价等），文字样式是插件自带的非规范值。

- 🔴 **不改插件生成的 JS / CSS**（如 Affirm 的 `affirmShopify.js` 给元素设内联 `font-size`）——**改了无效**（运行时重新生成）/ 会被插件更新覆盖
- **在主题层集中覆盖**：plaud-us 用 `snippets/base-more-style.liquid` 的 `<style>` 块，按插件容器选择器覆盖到 spec（字号 token、颜色 token、圆角 `radius-base`、内距 spec 阶梯、字重去强制）。
  插件用 inline style 时覆盖需 `!important`（如 `.affirm-as-low-as { font-size: var(--text-body-sm) !important }`）
- **插件已有的"看着像品牌色"的值先查是不是 spec token**：如某 CTA 的 `#00D0FF` 其实就是 `--color-highlight-cyan`，**直接 token 化即可、不必改色**
- ⚠️ **`line-height` 等紧凑布局值谨慎动**：插件小组件常用紧凑行高，强行改成 spec 正文行高**可能撑乱**，按需保留，
  且 🔴 **须经用户确认或明确登记为已批准偏差**（不是"知会一声"就行）

## §4.15 token → class 重构必须"全实例覆盖"（高频回归源）

把某个**共享 class** 的 spec 值（字号 / 内距 / 圆角 / 间距）从组件 CSS 移到 HTML utility 类时，
🔴 **必须先有一份该 class 的全仓 markup 实例清单，并逐一补类** —— 否则未迁移的实例（**常在其它分支 / 其它 snippet**）会**静默丢样式**（字号回退继承、内距归零）。

**判断顺序（不可颠倒）：**

1. **拿到清单** —— 由 `plaud-theme-impact` §4.2 产出，在 `SharedPropagation` 里：全仓 markup 实例清单 + 每个实例当前是否已挂等价 utility。
   🔴 **本 skill 不自行重跑这条 grep 生成第二份清单**；`AssessmentRef` 里没有这份清单 = Assess 工件不完整 → **退回 impact**
2. **剥 CSS 声明前**，确认清单上**每个**实例都已挂等价 utility —— **清单不全就不要剥**
3. 剥完在 `ModifiedFiles` 范围内做残留 / dangling 验证 + 回归

> 📎 **历史案例**：某次只改了"当前正在做的实例"，另一个菜单分支与移动菜单多个分支未补类 → 回归；后靠并行 diff 审查 + grep 补齐。

**例外（留 token 在 CSS 是合理的）**：无对应 utility 的属性（如 `margin-inline-end` 这类单侧 margin），
或"共享组件基类一次定义、不散落"的 padding —— 这类留 `var(--token)` 在组件 CSS **不算"重复"**。

## §4.20 生成文件（build 产物）勿手改

`snippets/design-system.liquid`、`assets/sectionsTT.min.css`、`assets/base_more.css` 等是 shopify-common 的 **build 产物**。

- 改动要落到**源**（`shopify-common/src/**`、`sections-tt/**` 的 scss / liquid）**+ 重新 build**
- 手改产物 → 下次 build 覆盖 / 与源分叉
- 🔴 **真正加载的入口以 `layout/theme.liquid` 为准**（如 `{% render 'base-more-style' %}` 是加载的那份、`base_more.css` 是另一份）——
  改了没加载的那份 = **零影响也零修复**
- 这一条同时是全路径红线第 7 条（`plaud-theme-shared` §8）
