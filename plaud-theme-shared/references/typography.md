# Typography — 字体 / 字阶 / 标题层级

**何时读我**：需要字体族、字重、字号 token、`.fs-*` 工具类、H1–H6 字号、或区头（Pre/Heading/Sub Heading）样式数值时。改 timer、改 JS、纯 schema 字段时不要读。

> 本文是矩阵内字体相关数值的**唯一事实源**。其它 skill 不得复制这里的数值，只得引用本文件。
> 凡与 vendor 对外版旧表冲突处，**一律以 v1.3 为准**（本文已按 v1.3 落实，并标注被废弃的旧值）。
> 🔴 本文记录的是**规范值**；目标仓库 `snippets/design-system.liquid` 的实际编译值可能落后，**动手前自行核对**——见 **`repo-drift.md`**（`.richtext-container` 已知可能尚未 build）。

---

## 1. 字体族与字重

| 项 | 规定 |
|---|---|
| 字体族 | 全站**仅** `Jokker`。不引入第二字体族 |
| 默认字重 | **Regular 400** —— 所有标题、正文、按钮、导航、标签的默认值 |
| 允许的第二字重 | **Semibold 600** —— 仅限**局部强调文字、数据数值、价格突出**。**不用于标题**，不可大面积使用 |
| 禁止 | 400 / 600 以外的任何字重、`font-weight: bold`（=700）/ `.fwb`、组件内自定 `font-family`、浏览器合成粗体 |

> 🔴 **Semibold 600 是 2026-08-11 基线放开的**（spec §1.1）。v0.1.0 写的是「全站仅 Regular 400，禁止新增字重」，**已废止**。
> 但放开的是**规范许可**，不等于随手能用，落地前必须核三件事：
>
> 1. **字体文件在不在**：`grep -rn 'Jokker' <repo>/assets/ <repo>/snippets/ | grep -i 'semibold\|600'`。只有 Regular 字重文件时，写 `font-weight: 600` 会触发浏览器 **synthetic bold**（把 400 字形硬拉粗），字形会变形、与设计稿不符。
> 2. **`@font-face` 声明了没有**：必须有独立的 `font-weight: 600` 声明块指向 Semibold 字体文件，不能靠 `font-weight: 400` 那条兜。
> 3. **加载策略**：新增一个字重就是新增一个字体文件请求，须确认 `font-display` 与 preload 策略，别把首屏拖慢。
>
> 三条任一不满足 → **停机**，向用户确认是否补字体资源，**不得**先写上 600 等着看效果。
>
> 用量边界：「局部强调」指句内个别词、单个数值、单个价格。整段、整个标题、整张卡片的文字改 600 **不算局部**，判违规。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 |
|---|---|
| 标题加粗 / 多字重（700+） | 标题恒 Regular 400 |
| 「全站仅 400，禁止新增字重」（v0.1.0 口径） | **400 默认 + 600 局部强调**（2026-08-11 基线） |
| admin 字段 `subheading_weight` 解析为 **500** | 迁移时归 **400**（500 仍不是合法字重，不得借 600 放开为由保留） |
| legacy 内联类 `fs__50` / `fs__30` + `fwb` | 换 spec 字号类，去 `fwb`（`.fwb` 是 700，不在两档内） |

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

> 「典型用途」列里的 `H1`/`H2`/`H3`/`H4`/`H6` 只是**矩阵侧的标签↔档位映射约定**，方便迁移时对照旧文档；**UX Spec v1.3 本身不定义 H1–H6**（见 §4）。不要反向推断「spec 规定 H2 = 40px」。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 | 出处 |
|---|---|---|
| **large-title-1 = 64px PC / 36px MB**（vendor §6 旧表，旧表称 H1） | **48px PC / 40px MB** | 已裁决，以 token 为准；spec 层只有 `large-title-1`，没有「H1」这个档 |
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

## 4. HTML 标题标签（h1–h6）—— 不是 UX Spec 的档位

> 🔴 **UX Spec v1.3（2026-08-11 基线）没有 H1–H6 字号表。** §1.2 字阶只有上面那 9 个语义 token；`H1`…`H6` 这套命名来自 **vendor 旧文档**，不是现行设计规范。因此"H5 是多少 px"这个问题在 spec 层**无答案**，不要按标签名去 spec 里找档位。

**正确做法**：按**用途**选 §3 的 9 档 token（区头走 §5、正文按 body-md/lg 判定），标签语义（h1/h2/…）只用于文档结构与 SEO，**与字号解耦**。

### 4.1 仓库里的 h5 现状：一套生效规则 + 一处死变量声明（改前必看）

矩阵 v0.2.0 曾写「H5 = 22px 是现行规范值」「优先复用既有 `h5 {}` 全局规则」——**两句都是错的**，已在 v0.2.1 撤回。实测（`shopify-plaud-yidian`，2026-08-12）：

| 来源 | 性质 | 定义 | h5 实际值 |
|---|---|---|---|
| `assets/critical.css:148` `:where(h5, .h5)` | ✅ **唯一真正生效的全局规则** | `--size: 1.8rem`，经 `font-size: calc(var(--heading-font-scale) * var(--size))`；根字号 `html{font-size:16px}`（`critical.css:8`），`heading_font_scale=100` | **28.8px** |
| `layout/theme.liquid:418-424` `--h0-size … --h6-size`（`--h5-size` = 18px） | ⚠️ **只有声明、没有消费点** —— 全仓 `grep 'var(--h5-size)'` 零命中，这套变量对渲染结果**没有影响** | `calc(var(--heading-font-scale) * 18px)` | 声明值 18px，**实际未生效** |
| `snippets/design-system.liquid` 9 个语义类 | 与标签**正交**的字号体系 | 无 h5 概念，按用途取档 | — |

> v0.2.1 把这三项笼统写成「三套并行的实现」，不准确 —— 只有第一项真正决定 h5 渲染值，第二项是死声明，第三项根本不按标签走。v0.2.2 更正。

⚠️ 所以**不得**再照 v0.2.0 的话去「复用既有 `h5 {}` 全局规则」：那条规则产出 28.8px（`h1` 同理是 57.6–64px，正是 §3 表里标为已废止的 vendor 64px），复用它等于把废止值搬进新代码。同样**不要**去消费 `--h5-size`：它现在是死变量，接上它等于新造一条渲染路径，属改动全局 heading 行为。碰到 h1–h6 的字号问题，按 §3 选档 + `.richtext-container`（§7）统一，不要动全局 heading 规则。

### 4.2 `.fs-*` 有两套，别混

| 体系 | 出处 | 命名 | 是否 spec 对齐 |
|---|---|---|---|
| **语义类**（9 个） | `snippets/design-system.liquid`（build 产物） | `.fs-large-title-1/2`、`.fs-title-1/2/3`、`.fs-headline`、`.fs-body-lg/md/sm` | ✅ 与 v1.3 §1.2 逐值一致（已实测） |
| **数字遗留类** | `assets/critical.css` §字号段 + `snippets/critical-style.liquid` | `.fs-10 .fs-11 .fs-12 .fs-13 .fs-14 .fs-15 .fs-16 .fs-18 .fs-20 .fs-22 .fs-24 .fs-26 .fs-36 …` | ❌ 主题历史值，不对齐 spec |

v0.2.0 写的「`.fs-*` 只有 9 档，22px 在工具类体系里根本不存在」是**把语义类当成了全部 `.fs-*`**。事实上 `.fs-22` 存在（`critical.css:1019` `font-size: 1.38rem` = **22.08px**，注意精确 22px 应为 `1.375rem`），且仍有活跃引用（`sections/newsletter-popup.liquid:79`、`sections/login-popup.liquid:15`）。

**约束**：新代码**只用语义类 / `var(--text-*)`**；数字遗留类视为存量，不新增引用、也不因本次改动被强制清理（存量复用豁免见 `handoff-schema.md` §8.1.2）。需要 spec 没有的字号时**仍然停机请示**——但理由是「spec 无此档」，不再是「工具类里没有 22px」。

- **不开放字体大小自定义**：结构型模块（Banner 标题、Section 标题/描述、卖点标题）字号锁定，不提供富文本工具栏与字号修改。
- 具体仓库里富文本 h1–h6 是否已对齐 spec 属**项目运行时状态**（见项目侧 `memory/全局已知偏差.md`），本层不裁决；迁移时不要顺手改。

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
