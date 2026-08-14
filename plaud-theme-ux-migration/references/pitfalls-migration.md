# 踩坑库 — 配置层迁移与模块重建（§4.8 §4.8.1 §4.8.2 §4.8.3 §4.12 §4.12.1）

> **配方前提**：本文件是「**已获授权的迁移中怎么做**」，不是做出改动的授权本身。
> 本文件几乎每条都涉及 **`templates/*.json` 存值编辑** —— 那是**默认只读**的，
> 每一次都需要用户**当次明确批准**；未获批准时写进 `BlockingGaps` 停机要授权，不得先改后说。
> 其余硬规则：不写死颜色 / 不写死宽高 / 等距两可问用户 / schema option values 不改 / 验收前不写 UX 差异日志内容。
> 冲突时**以硬规则 + 其授权为准**。完整总纲见 SKILL.md「§4.x 配方的适用前提」。

---

## §4.8 Slideshow 配置层迁移（Image Slide → New Slide）

Slideshow 是首屏 Hero、全站模板量巨大、blast radius 极大 → **不改模块代码，走配置层迁移**。

- 模块内有两种 block：旧 **`slider_item`（Image Slide）** 与已对齐 spec 的 **`new_slide`（New Slide）**。
  New Slide 用结构化字段 + spec 字号类（`heading_size_class` / `description_size_class`）；
  Image Slide 的标题靠**后台自定义 HTML 内联样式**或 Slideshow 整体字号设置（**均非 spec**）。
- 迁移 = **在模板存值里把对应的 `new_slide` 启用（去 `disabled`）、把旧 `slider_item` 隐藏（加 `"disabled": true`）**。
  很多模板已经预先配好了内容相同的 `new_slide`（heading / 图片 / 按钮一致），直接翻转 `disabled` 即可。
- 🔴 这是少数**允许动 `templates/*.json` 存值**的场景（**仅翻 `disabled`，不改其它配置**）——因为它本质是"切换已存在的 spec 版 block"。**仍需用户明确认可。**
- 迁移**逐模板进行**（每个模板的 Slideshow 实例单独切），**不是一次全站**。

**切换前必须核对 `new_slide` 与被隐藏 `slider_item` 的对应关系**（heading 文案、背景图、按钮一致），并预览确认三件事：

1. 字号收敛到 spec（标题 large-title-2、描述 headline；数值见 shared `typography.md`）
2. **文字块定位系统换了**：旧 `content_position / max_width / padding` → new_slide 的 `左边距% / 宽度% / 垂直锚点`，**水平位置 / 垂直居中可能微变**
3. **入场动效可能不同**（如 zoom-in → fade-in-down）

### §4.8.1 模板没有预置 new_slide → 新建（不能只翻 disabled）

部分模板只有旧 `slider_item`、**没有预配好的 new_slide**。这种要**手动新建**一张 new_slide。
🔴 **新增 block = 模板存值编辑，需用户明确批准，不在「仅翻 disabled」的授权范围内。**

- **字段映射**：照搬 `slider_item` 的 `image` / `image_mobile` / `image_link` / `first_button_*` / `second_button_*` / `enable_high_priority`；
  `heading` **去掉内联包裹**（如 `<nobr>`、自定义 `<style>`）只留纯文本；`description` 去 `<p>` 包裹留纯文本
- **布局参数取 `templates/index.json` 里已启用 Slideshow 的 `new_slide` 作为标准起点**
  （多个候选或没有启用实例 → **停机请用户指定基准 block**，别自己挑一个）。实测起点值：
  `content_left_pc: 20` / `content_width_pc: 25`、`content_left_lp: 10` / `content_width_lp: 34`、
  `content_v_anchor_pc: center`、`content_alignment` + `content_alignment_mobile` 都 `left`；
  字号类 `heading_size_class: fs-large-title-2`、`subheading_size_class: fs-headline`、`description_size_class: fs-headline`
  （这些是**布局百分比与类名**，不是 spec 视觉数值；字号档本身仍以 shared `typography.md` 为准）
- 🔴 **左% / 宽% 是按图微调的起点，不是定值**：取决于 KV 图左侧留白与产品位置
  （历史案例：notepin-s 经预览把 Laptop 宽度从 34 调到 40 —— **案例，不是默认值**）。
  **新建前最好先看一眼 KV 图**确认产品在右、左侧有放文字的空间，否则文字会压在图上
- **缺 Laptop 图（`image_ipad`）可不填**：snippet 自动回退用 PC 图（`image_ipad | default: image`）

### §4.8.2 必开 `new_banner_enbale`（关键，§4.8 主流程没提）

（开启这个 section 级存值**同属需授权的模板编辑**。）

new_slide **依赖 section 级 `new_banner_enbale: true`** 才能正确出高度。很多旧模板的 Slideshow 是 `new_banner_enbale: false`（如 `slide_height: adapt`）。**开启后**：

- **高度改走全局主题设置** `settings.height_1920 / 1440 / 992 / 768`（与首页等所有 new_banner Slideshow **共用**），section 自身的 `desktop_height` / `mobile_height` **失效**
- **背景图从"按比例完整显示"变成"按固定高裁切填充"**（`object-fit: cover`），**可能裁掉图片边缘 —— 预览必看**
- 迁前先确认这几个全局高度变量**有值**（`config/settings_data.json` 缺的取 `settings_schema.json` 默认），**否则高度塌**

### §4.8.3 验收期保留两张 slide + 临时开导航；签收后再收尾

在**已获模板编辑授权**的验收对比中，用户要对比"修改前后"时
（下列 `block_order` / 导航开关 / `disabled` / 移动定位改动**均属模板存值编辑**）：

- **旧 `slider_item` 先不隐藏**，与新 `new_slide` 并存（`block_order` 旧在前、新在后），让用户切着看
- 🔴 **临时打开轮播导航** `show_arrow: true` + `carousel_pagination: show_dots` —— 否则多张 slide 在 `fade` + 非自动播放下**切不动**，用户只看得到第一张
- **签收后收尾**：给旧 `slider_item` 加 `"disabled": true`；把 `show_arrow` / `carousel_pagination` **还原回迁移前的值**（对比用的临时开关，别留着）
- 顺带**归一移动端定位**：旧 `slider_item` 常是 `content_position_mobile: top-center-mobile`（但盒子整宽 + 文字左对齐，"居中"名存实亡），标准是 `top-left-mobile`

---

## §4.12 旧版 Multi Content → Multi Content - WW 重建（结构性坑，实测踩过）

旧版 `multi-content`（legacy）**移动端无独立标题字号**（block 的 `*_font_size` 是单值、PC = MB）。
要 spec 的 PC / MB 双档只能改模块代码 → 波及全站上百实例。

**在已获授权的迁移中，更优解：用已对齐 spec 的 `ww-multi-content`（原生 `*_font_size` + `*_font_size_m` 双档）在模板存值层 1:1 重建目标实例** —— 只动本模板、零全站影响。
🔴 动模板存值属「templates 默认只读」的受控例外，**需用户明确批准**；重建时**保留 section key**、只改 `type`。

**重建必避以下坑：**

### 1. WW 是「`col_parent`（列容器）→ 子块」两层结构，不是平铺 block

section 先遍历 `col_parent`（`arr_colperant`），子块靠 col_parent 之后的**偏移循环**渲染、遇下一个 col_parent 即 break。

🔴 **`block_order` 里没有 col_parent → 所有子块都不渲染**（区头是独立渲染的所以还在，**极易误判成"只是图没加载"**）。

- **静态网格**（如规格表）：**1 个 col_parent（100%）包全部子块**
- **需要移动端轮播 / 每卡各自为 slide**：**每张卡一个 col_parent**（`block_order` = colp1, card1, colp2, card2…）；
  col_parent 设 `content_width`（桌面列宽，如 3 列 = `33.3333%`）/ `content_width_m`（移动列宽，如 `66.6666%` 露出下一卡），
  **卡片自身 `content_width: 100%`**。
  否则单 col_parent 包多卡 → 移动端只会**竖向堆叠、轮播失效**

  **不变量**（比具体百分比更重要）：
  ① 同一行所有 col_parent 的桌面宽度和 + 列间距**不得溢出一行**；
  ② 移动端每个 col_parent **必须小于容器宽度**，否则露不出下一卡、看不出可横滑；
  ③ 子卡 `content_width` **必须占满其 col_parent**（100%）

### 2. WW `image` block 多断点懒加载有 bug

走 `ww_mc_multi_breakpoint` 的 responsive-image：**图停在 `data-src`、永不提升、容器也不预留高度，滚进视口也不加载**。

- **单图改用 `image_with_text_below`**（只填图、标题 / 描述留空），走标准 aspect-ratio 路径，正常加载
- ⚠️ **仅在「从 legacy 重建」或确认该图实际加载失败时才转**；既有能正常渲染的 WW `image` block **不主动转换**
  （历史案例：0426pins / note-0911 的现存对比图 `image` block 均保留未转、照常工作 —— 案例，不是当前状态断言）。
  **模板只读 + 不修没坏的东西。**

### 3. 卡片图上文下

`image_with_text_below` 默认 `additional_class: "p-20 flex-column-reverse"`（内距 + 文字在上）。
要「图上文下、无内距」→ `additional_class` 设 `"flex-column"`。

### 4. 卡片对齐取值

WW 卡片 `content_alignment` 是 `left / center / right`（旧版是 `start / center / end`，映射 `start → left`）。
按各模块 schema 的 option value 填，见 `pitfalls-components.md` §4.13。

### 5. 栏目（卡片间）间距

走 §3.1 `--space-6`（col_parent 的 `column_gap` / `column_gap_mb` + section 的 `column_gap` / `column_gap_mb`）。数值见 shared `responsive-and-spacing.md`。

### 6. 区头

- 主标走 `cs-section-header`（spec large-title-2）
- 副标里的免责小字若要小号灰，**优先给元素挂 `.text-secondary`**
- 仅当该元素是 richtext `<p>`（**不能加类**，见 §4.12.1）时，才退回 section `custom_css` 设 `.section-sub-heading p` 的字号 ——
  **字号必须从 shared `typography.md` 里按"免责小字 / 辅助说明"用途选对应 tier 并消费该 token，不得自由填一个数**；
  🔴 **颜色仍走 token `var(--color-label-secondary)`、不写死 hex**（Shopify 自动按 `#shopify-section-…` 限定本 section）。
  用 token 本身合规；此处的**受控例外**只是"richtext `<p>` 加不了工具类、才退回 template-scoped `custom_css`"（一般禁止在组件 CSS 重写字号 / 色）

### 7. 必须浏览器预览实测两端

桌面网格列数 / 间距、移动端**是否真横滑**、图是否加载（`naturalWidth > 0`）、区头间距。
🔴 **配置"看着对" ≠ 渲染对。**

---

### §4.12.1 WW 文本 / 标题块的字号与上色（不止重建，对齐既有实例也吃这套）

WW 的 `text` / `title` 子块**不走 spec `fs-*` 类**：

- 字号是**后台数字直渲**（`des_font_size` / `title_font_size` + `_m` 双档 → `.fs-custom` / `.fs-medium` 把数字当 px）
- 文字色来自 **block 的配色方案**（非 spec 文字 token）

所以对齐既有 WW 实例 = **在（已授权的）模板存值层改数字 + 处理颜色**，不必动模块代码。

**两个实测踩过的坑：**

#### A. 给 WW 文本上 spec 灰，必须先看字段类型

- `description` 是 **textarea** 字段 → 允许任意 HTML，可直接 `<span class="text-secondary">…</span>`（🪦 `-tertiary` 档已废止，见 shared `colors-and-schemes.md` §2.1） 上色（**生效**）
- 🔴 `rich_description` 是 **richtext** 字段 → **`<p>` 禁带 `class` / `style`**，加了 **Shopify 校验拒绝、整模板上传失败**（报"`<p>` 标签上不允许使用属性"）。
  即便绕过，richtext 里 `<p>` 还有**更高特异性**的着色规则会盖过 `.text-*` 类
- **解法**：要上色的内容放 `description`（textarea）字段、**清空 `rich_description`**，用 `<span class="text-…">` 包裹（span 子元素能盖过 `<p>` 着色规则）；颜色仍引规范 token 类

#### B. 大数字 / 装饰字号

legacy 内联类（`fs__50` / `fs__30` 这类）要对 spec：直接把内联类换成 **spec 字号类**，并**去掉 `fwb`**（`.fwb` 是 700，不在 400/600 两档内。§1.1 现为 Regular 400 默认 + Semibold 600 仅局部强调，见 shared `typography.md` §1）。

#### C. 叠图 banner（`image_with_text_overlay`）/ 标题块曾走流式 clamp、非 spec

snippet 里 `heading_font_size > 24 → fs-medium`、`> 41 → fs-big`，二者是**按视口流式缩放**（floor ×0.8333 ~ cap ×1.1）、**完全不读 `_m`（移动端）值** —— 所以后台填的移动端字号是**死值**，移动端实渲约等于 floor。

要对 spec 离散字阶 → 把 snippet 字号 class **恒置 `fs-custom`**。

- 🔴 **关键机制**：`fs-custom` 只消费 `--font-size`（PC，≥768）与 `--font-size-m`（≤767.98）；
  **`--font-size-pad`（平板）是死值 —— 平板恒渲染 PC 值**。所以平板档存值跟 PC 还是跟 MB 都不影响渲染
- 🔴 此改动影响全站**所有** overlay 实例（模块级），**需抽查回归 —— 改前评估 blast（走 `plaud-theme-impact`）、与用户确认**

#### D. 渐变副标坑

副标 class **直接输出字重字段值**（`subheading_weight` / `body_weight`）。若渐变色 `custom_css` 挂在**字重 class** 上，改字重（500 → 400）会让 class 变、**渐变失配**。

- **把渐变选择器改挂稳定结构类 `.sec__content-subheading`**（只命中副标，不波及同为 `body_weight` 的主标 / 描述）

#### E. PC / MB 布局差异大的实例

常做成「PC 列（`hide_mobile`）+ 移动列（`hide_pc`）+ 共享图列（`always_on`）」**三套并存**。

需要移动端把某块（如标题）排到图片**上方**时：**新增一个 `hide_pc` 的独立列**承载该块，靠 `order`（`max-md:order-N`）排到图片列之前即可；**PC 端该列隐藏、不受影响**（无需动 PC 结构）。
