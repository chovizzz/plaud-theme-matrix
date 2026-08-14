# Typography — 字体 / 字阶 / 标题层级

**何时读我**：需要字体族、字重、字号 token、`.fs-*` 工具类、H1–H6 字号、或区头（Pre/Heading/Sub Heading）样式数值时。改 timer、改 JS、纯 schema 字段时不要读。

> 本文是矩阵内字体相关数值的**唯一事实源**。其它 skill 不得复制这里的数值，只得引用本文件。
> 凡与 vendor 对外版旧表冲突处，**一律以 v1.3 为准**（本文已按 v1.3 落实，并标注被废弃的旧值）。
> 🔴 本文记录的是**规范值**；目标仓库 `snippets/design-system.liquid` 的实际编译值可能落后，**动手前自行核对**——见 **`repo-drift.md`**（`.richtext-container` 已知可能尚未 build）。

---

## 1. 字体族与字重

| 项 | 规定 |
|---|---|
| 字体族 | 全站**仅** `Jokker Regular 400`。不新增第二字体族 |
| 字重 | 全站 **Regular 400**（spec §1.1）。标题**不加粗** |
| 禁止 | 新增字重、`font-weight: bold` / `.fwb`、组件内自定 `font-family` |

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 |
|---|---|
| 标题加粗 / 多字重 | 全站 Regular 400 |
| admin 字段 `subheading_weight` 解析为 **500** | 迁移时归 **400** |
| legacy 内联类 `fs__50` / `fs__30` + `fwb` | 换 spec 字号类，去 `fwb` |

> ⚠️ 改字重 class 的副作用：若某处渐变色 `custom_css` 挂在字重 class 上，把 500 改 400 会让 class 变化、渐变失配。正解是把渐变选择器改挂稳定结构类（如 `.sec__content-subheading`），不要为保渐变而留 500。

---

## 2. `--text-*` token 与 `.fs-*` 工具类的分工

**这是两套东西，用途不同，不要混用：**

| 层 | 形式 | 用在哪 |
|---|---|---|
| **工具类** `.fs-*` | `<div class="fs-headline">` | **markup 上挂类**。section-scoped / 异步加载的组件必须走这条（critical bundle 已加载，避免 FOUC） |
| **CSS token** `var(--text-*)` | `font-size: var(--text-large-title-2)` | **组件 CSS 消费**。universal 组件（`cs-section-header` / `section-disclaimer` / `.container`）本身就在 critical 层，直接消费 token |

判定规则：

| 情形 | 用哪个 |
|---|---|
| 非响应式字号（PC/MB 同档或单一 token 命中） | markup 工具类 `.fs-*` |
| 响应式（PC/MB 不同值且无单一 token 命中） | 组件 SCSS + `var(--text-*)` + 媒体查询 |
| 需要 `currentColor` 继承（如 SVG 随父色） | 组件 SCSS + token |
| 动态内容（metaobject / richtext 渲染出的 `<p>` `<span>`，markup 不可控加不了类） | 组件 CSS 用后代选择器消费 `var(--text-*)`；**这是允许的例外**，FOUC 不可避免 |

**禁止**：散点硬编码字号（`font-size: 18px`）、组件内插值（在两档之间取中间值）、为单个 section 自造字号类。

---

## 3. 字阶表（token / 工具类 / PC / MB）

| 工具类 | token | PC | MB | 典型用途 |
|---|---|---|---|---|
| `.fs-large-title-1` | `--text-large-title-1` | 48px | 40px | H1、首屏主标 |
| `.fs-large-title-2` | `--text-large-title-2` | **40px** | 32px | H2、**区头 Heading**、Slideshow New Slide 标题 |
| `.fs-title-1` | `--text-title-1` | 32px | 28px | 大数字 / 装饰字号 |
| `.fs-title-2` | `--text-title-2` | 28px | 24px | 价格 amount 等 |
| `.fs-title-3` | `--text-title-3` | 24px | 20px | H3 / H4、卡片标题 |
| `.fs-headline` | `--text-headline` | 20px | 18px | H6、tab 标签、视频/FAQ 问题标题、New Slide 描述 |
| `.fs-body-lg` | `--text-body-lg` | 16px | 16px | **长文阅读 / 正文段落** |
| `.fs-body-md` | `--text-body-md` | 14px | **14px** | **卡片描述 / 辅助说明** |
| `.fs-body-sm` | `--text-body-sm` | 12px | 12px | 划线价、免责小字、角标 |

上表 9 档已用编译产物 `design-system.liquid` 实测核对，**完全一致**。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 | 出处 |
|---|---|---|
| **H1 / large-title-1 = 64px PC / 36px MB**（vendor §6 旧表） | **48px PC / 40px MB** | 已裁决，以 token 为准 |
| `text-body-md` MB = 12px | **MB = 14px** | v1.3 §1.2 修订 |
| 区头 Heading PC = 42px（`cs-section-header` 历史值） | **40px**（直接消费 `var(--text-large-title-2)`） | v1.3 优先级② |
| 中间断点按线性插值取字号 | **按档离散取值，组件内不插值** | v1.3 优先级⑦ |

### text-body-md vs text-body-lg（必须先判用途再选档）

| 用途 | 选哪个 | 例 |
|---|---|---|
| 卡片描述、辅助说明、图注、次要注释 | `body-md`（14/14） | 卡片小字、发货说明 |
| 长文阅读、正文段落、成段描述 | `body-lg`（16/16） | Marquee 详情卡长文、FAQ 答案、Core Features 正文 |

对齐正文时**不要按视觉大小就近取档**，按"这是卡片辅助还是正文段落"判定。

---

## 4. H1–H6 全局字号表

| 标签 | 字重 | Desktop | Mobile | 行高 | 对应档 |
|---|---|---|---|---|---|
| H1 | 400 | **48px** | **40px** | 1.2 | large-title-1 |
| H2 | 400 | 40px | 32px | 1.2 | large-title-2 |
| H3 | 400 | 24px | 20px | 1.2 | title-3 |
| H4 | 400 | 24px | 20px | 1.2 | title-3 |
| H5 | 400 | 22px | 20px | 1.2 | ⚠️ 无同值 `.fs-*` 工具类（见下） |
| H6 | 400 | 20px | 18px | 1.2 | headline |

- 🔴 **H1 = 48 / 40，vendor §6 旧表的 64px PC / 36px MB 已废止，不得照抄。** 翻到旧文档看到 64/36 时，以本表为准。
- H3–H6 **非等差递减**，按上表离散取值；中间断点不插值。
- ⚠️ **H5 = 22px 是现行规范值**，只是 `--text-*` 阶梯里没有同值工具类。
  **已实证**：编译产物 `design-system.liquid` 里 `.fs-*` 只有 48/40/32/28/24/20/16/14/12 九档，**22px 在工具类体系里根本不存在** —— 这是真实的 spec 缺口，不是我没找到。
  **不得**因为"没有对应类"就把它改成 20 或 24——那是改规范值，不是选档。
  正确做法：优先复用既有的 H5 全局规则（`h5 { … }`）；若确需工具类化，**停机请示是否新增语义 token**，由用户决策，不擅自 snap。
- **不开放字体大小自定义**：结构型模块（Banner 标题、Section 标题/描述、卖点标题）字号锁定，不提供富文本工具栏与字号修改。
- 具体仓库里富文本 H1–H6 是否已对齐 spec 属**项目运行时状态**（见项目侧 `memory/全局已知偏差.md`），本层不裁决；迁移时不要顺手改。

### 内容型模块的富文本边界

| 允许 | 禁止 |
|---|---|
| 段落、粗体、斜体、下划线、列表、引用、分隔线、超链接、基础表格 | 自定义 `font-size` / `font-family`、行内 `<style>`、脚本与外链资源、色彩选择器 |

---

## 5. 区头三件套（Pre Heading / Heading / Sub Heading）

统一走 snippet **`section-header`**（输出 `.cs-section-header`）。输入框统一 `textarea`（便于运营插入 `<span>` 样式）。

| 字段 | PC（width > 992） | Mobile（width ≤ 992） |
|---|---|---|
| **Pre Heading** | 色 `#2FADED`；24px；400；行高 1.2；下间距 24px；居中 | 色 `#2FADED`；20px；400；行高 1.2；下间距 16px；居中 |
| **Heading** | 色 `#000000`；**40px**；400；行高 1.2；居中 | 色 `#000000`；32px；400；行高 1.2；居中 |
| **Sub Heading** | 色 `#000000`；24px；400；行高 1.2；上间距 24px；居中 | 色 `#000000`；20px；400；行高 1.2；上间距 16px；居中 |
| **Section Header 整块** | 宽 100%（最大 1024px）；下间距 **32px**（space-8） | 宽 100%；下间距 **32px** |

**注意事项：**

- ⚠️ 这里的 **992 是区头组件特例**，不是全站 CSS 判定断点。全站判定值见 `responsive-and-spacing.md`（767.98 / 1279.98 / 1599.98）。**勿泛化。**
- 特殊情况：Mobile 端 delta 页面模块标题部分为居左对齐。
- 区头**对齐要传参进 snippet**（`text_align_pc` / `text_align_mb`），不要靠外层 `.text-*`——外层非 important，会被 snippet 给每个标题元素输出的 `text-{x}!`（important，来自 base-style 全局 bundle，默认 center）盖掉。模块当前若靠外层 `.text-*`，多半是没生效的遗留。

**对齐值的 emit 规则：**

| 项 | 现行做法 |
|---|---|
| `.text-left!` / `.text-center!` / `.text-right!`（及 `start` / `end`） | **已确认在 critical bundle**（`base-style.liquid`） |
| 输出物理值 `text-{align}!` | ✅ **可直接 emit**，不必再映射 |
| `left → start` / `right → end` 映射 | 已**降为逻辑属性偏好（非必须）**；仅当 emit 后某值确实未生效，再退回 `\| replace: 'right','end' \| replace: 'left','start'` |
| schema option values | **不得**为了统一命名而修改；只在 Liquid 端做映射 |
- 「模块已迁」≠「该实例已左对齐」：移动端区头对齐是**每实例存值**，缺字段走 schema 默认（多为 center），必须逐实例查。
- 对齐存值的 option value **因模块而异**（`left` vs `start`）、字段名也因模块而异（`header_alignment_mobile` / `header_align_mb` / `title_align_mb`），标题字段名也不统一（Marquee 是 `text_heading`）——按各模块 schema 实际 option value 填，schema option values 不得改。

**被 v1.3 覆盖的旧值：**

| 旧值（已废） | 现值 |
|---|---|
| Section Header 下间距 48px | **32px（space-8）** |
| 外层 `.section__header mb-33 mb-sm-20` 双重间距（折叠取 33px；`mb-sm-20` 实为失效死类，两端都渲染 33） | **去掉外层类**，交回 `.cs-section-header` 自带的 32px |
| Heading PC 42px | **40px** |

---

## 6. `.fs-*` 自带 line-height —— 不要再写 `line-height`

| 类族 | 行高变量 | 值 |
|---|---|---|
| `.fs-large-title-*` / `.fs-title-*` / `.fs-headline` | `--head-line-height` | **1.2** |
| `.fs-body-*` | `--body-line-height` | **1.5** |

两个方向的坑：

1. 加了 `.fs-*` 还显式写 `line-height` = 冗余，且和规范打架。
2. **反向坑**：把原本紧凑（`line-height: 1.2`）的组件文字换成 `.fs-body-*`，行高会从 1.2 变 **1.5**（变松），布局可能被撑开。要保留非规范紧凑行高**必须显式覆盖并知会用户**，否则就接受规范行高。

第三方插件小组件（Affirm / Klarna / Selleasy / 评价插件）常用 `line-height: 1.2`，强改 1.5 可能撑乱——**按需保留，且须经用户确认或明确登记为已批准偏差**（不是"知会一声"就行）。

---

## 7. `.richtext-container`

**用途**：富文本 / `textarea` 内容块（运营可能塞 H1–H6、`<p>`、`<span>` 等任意标签）的字号统一。

> ⚠️ 该类**可能尚未 build 进目标仓库**（实测中出现过不存在的情况）。用前 `grep -c '\.richtext-container' <repo>/snippets/design-system.liquid` 确认，见 `repo-drift.md` §3.4。

**行为**：让后代元素（`sub` / `sup` 除外）的 `font-size` / `color` / `margin` 全部 `inherit`，统一继承容器上的 `.fs-*` / `.text-*`。不管运营放 h 几，渲染字号/色都一致。

**为什么优先用它**：

- 特异性高于裸 `h2 { font-size }`；
- 在 critical bundle，即时生效、无 FOUC；
- 不必自写 `.xxx *:not(sub,sup){font-size:inherit}` 这类 scoped 规则。

用法：给富文本容器同时挂 `.richtext-container` + 目标 `.fs-*` / `.text-*`。

---

## 8. 富文本字段上色的字段类型陷阱

| 字段类型 | 能否加 class/style | 做法 |
|---|---|---|
| `textarea`（如 WW 的 `description`） | ✅ 允许任意 HTML | 直接 `<span class="text-secondary">…</span>` |
| `richtext`（如 WW 的 `rich_description`） | ❌ `<p>` **禁带 `class` / `style`** | Shopify 校验拒绝、**整模板上传失败**（报"`<p>` 标签上不允许使用属性"）；即便绕过，richtext 的 `<p>` 着色规则特异性更高会盖掉 `.text-*` |

**解法**：把要上色的内容放 `description`（textarea）字段、清空 `rich_description`，用 `<span class="text-…">` 包裹（span 子元素能盖过 `<p>` 着色规则）。颜色仍走 token，见 `colors-and-schemes.md`。

---

## 9. 不重复固定容器已有的工具类

容器 markup 已挂 `.fs-body-md` 时，**SCSS 里不要再把同属性固定一遍**——多余，且会引出"该用 inherit 还是显式值"的纠结。只对**确实需要的后代 / 状态**加规则。
