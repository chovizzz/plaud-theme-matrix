# 命名与结构约定（Path B）

`sa-*` section 的骨架规则：文件怎么起名、容器怎么搭、间距/配色/标题走哪套字段、素材放哪里。

> **数值不在本文件。** 容器最大宽度阶梯、断点、间距档值、字号、颜色 token、弧角值一律在
> `plaud-theme-shared/references/typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md`。
> 本文件只写**结构与流程**，需要具体数字时去读那三个文件，**不要把数值抄回这里**（双事实源在 spec 升级时必然漂移）。

---

## 1. 强制命名（不可协商）

| 层级 | 规则 | 示例 |
|---|---|---|
| Section 文件 | `sections/sa-<feature>.liquid` | `sections/sa-shop-banner.liquid` |
| Snippet 文件 | `snippets/sa-<feature>-<part>.liquid` | `snippets/sa-shop-banner-card.liquid` |
| CSS 文件 | `assets/sa-<feature>.css` | `assets/sa-shop-banner.css` |
| Schema name / preset name | `"name": "SA: <Feature>"` | `"name": "SA: Shop Banner"` |
| BEM 根类名 | `sa-<feature>` | `<div class="sa-shop-banner">` |
| BEM 子元素 / 修饰符 | `sa-<feature>__<el>` / `sa-<feature>--<mod>` | `sa-shop-banner__card` |
| CSS 变量前缀 | `--sa-<feature>-*` | `--sa-shop-banner-gap` |

`<feature>` 用小写 kebab-case，与设计稿模块名对应，section / snippet / css / 类名 / 变量前缀**五处必须同一个 feature 串**。

**冲突检查**（新建前跑，属于 Assess 的 `IntegrationSurface` 内容，实现时复核一遍）：

```bash
ls sections/sa-<feature>.liquid snippets/sa-<feature>-*.liquid assets/sa-<feature>.css 2>/dev/null
grep -rn "sa-<feature>" sections/ snippets/ assets/ templates/
```

命中已有同名 feature → 停下问用户是"新建"还是"改已有"；若是改已有，路径不是 B，回 `plaud-theme-dev`（Path A）。

---

## 2. Section 容器骨架

内容区统一用 `container` 类（保证与同级模块左右留白对齐）。极少数全宽模块（Header / Slideshow / Footer 类）例外，例外须在 handoff 正文说明理由。

```liquid
<div id="{{ section.settings.anchor_id_for_category | handle }}"
     class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
  …
</div>
```

- `anchor_id_for_category` 挂在 **`.container` 同层**，不另包一层 div、不挂到内层。
- `container` 的左右内边距、最大宽度阶梯由全局 CSS 提供 → 见 `plaud-theme-shared/references/responsive-and-spacing.md`。section 内**不得**重写 `.container` 的宽度或内边距。
- 部分通用模块（Divider、Custom HTML、Custom Liquid、Featured product 之类）保留 section width 选择器，这是既有约定，新建 `sa-*` 不默认继承。

对应 schema：

```json
{ "type": "text", "id": "anchor_id_for_category", "label": "Anchor ID For Category" }
```

---

## 3. 上下间距：走 schema，不写 CSS margin

**section 的上下间距一律由下面两个 select 控制，CSS 里不得为 section 硬编码 `margin-top` / `margin-bottom`**（各断点实际间距值由全局 CSS 统一定义，运营可在全局配置里调整；具体档值见 shared 的 `responsive-and-spacing.md`）。

```json
{ "type": "header", "content": "+ Section Space" },
{
  "type": "select",
  "id": "section_top_pc",
  "label": "Section Top",
  "default": "section-top-pc-b",
  "options": [
    { "label": "none",   "value": "section-top-pc-a" },
    { "label": "normal", "value": "section-top-pc-b" }
  ]
},
{
  "type": "select",
  "id": "section_bottom_pc",
  "label": "Section Bottom",
  "default": "section-bottom-pc-b",
  "options": [
    { "label": "none",   "value": "section-bottom-pc-a" },
    { "label": "normal", "value": "section-bottom-pc-b" }
  ]
}
```

- `*-pc-a` = none（无间距），`*-pc-b` = normal（有间距）。
- 默认给 `-b`（有间距）；吸顶栏、面包屑等结构性模块默认改 `-a`。
- 商品位作为页面首模块时上间距默认 none。
- **option 的 `value` 不得改动**——它就是全局 CSS 的钩子，改了等于失效。

---

## 4. 配色方案：两个类名，缺一不可

需要运营切换背景色 / 文字色时，schema 用 `color_scheme`：

```json
{ "type": "color_scheme", "id": "color_scheme", "label": "Color scheme" }
```

Liquid 在容器元素上**同时**加 `gradient` 和 `color-{scheme}` 两个类：

```liquid
{%- comment -%} section 级 {%- endcomment -%}
<div class="section gradient color-{{ section.settings.color_scheme }} …">

{%- comment -%} block 级 {%- endcomment -%}
<div class="gradient color-{{ block.settings.color_scheme }} …">
```

- `gradient` 提供渐变背景基础样式层；`color-{scheme}` 注入具体颜色变量。**只写一个 = 配色不生效或背景层缺失**，这是 Path B 的高发漏项。
- 文字色 / 背景色 / 按钮色全部由配色方案 CSS 变量驱动，组件内**不得写死颜色值**。品牌色变量名与用法见 `plaud-theme-shared/references/colors-and-schemes.md`。
- **不得擅自新增 color scheme**、不得修改全局颜色变量；需要新 scheme 时停机要设计侧确认。
- 非特殊情况后台**不提供独立字体颜色配置**，运营只能切换配色方案；局部自定义颜色通过在 `pre_heading` / `heading` / `sub_heading` 文本字段里内嵌 `<span style="color: var(--…)">` 实现，优先变量而非裸色值。

---

## 5. 标题：复用 `section-header`

Section 标题**统一复用** `snippets/section-header.liquid`，不自己写一套标题结构（自写的标题会脱离全站字阶与间距体系）。

```liquid
{%- render 'section-header',
    pre_heading: section.settings.pre_heading,
    heading:     section.settings.heading,
    sub_heading: section.settings.sub_heading
-%}
```

```json
{ "type": "header",   "content": "+ Heading" },
{ "type": "textarea", "id": "pre_heading", "label": "Pre Heading" },
{ "type": "textarea", "id": "heading",     "label": "Heading" },
{ "type": "textarea", "id": "sub_heading", "label": "Sub Heading" }
```

- 三个字段一律用 **`textarea`**（不是 `text`），便于运营插入 `<span>` 之类的受控样式。
- 特殊样式通过在外层加自定义类名扩展，**不复制 `section-header` 再改**。
- `section-header` 内部已实现 `!= blank` 判断（空配置不渲染空壳），复用即继承该行为；自己在外面再包一层容器时，记得容器本身也要在三个字段全空时不输出。
- 标题字号 / 颜色 / 上下间距数值见 `plaud-theme-shared/references/typography.md`，**不在 section CSS 里重定义**。

---

## 6. 媒体资源红线（高发漏项）

> **新增 section 不得把内容图片、视频、icon 写死进主题包。**

禁止：

```liquid
{%- comment -%} ❌ 内容素材写死为主题资源 {%- endcomment -%}
<img src="{{ 'sa-shop-banner-hero.png' | asset_url }}">
<video src="{{ 'sa-shop-banner.mp4' | asset_url }}"></video>
<img src="{{ 'icon-feature-1.svg' | asset_url }}">
```

也不得新增 `assets/*.png|jpg|jpeg|webp|svg|mp4` 作为**内容素材**。

正确做法——运营可配置素材走 schema 字段或数据源：

| 素材类型 | 走什么 |
|---|---|
| 图片 | `image_picker` setting / block setting |
| 视频 | `video` 字段（或 `video_url`，按主题既有用法） |
| 外链资源 | `url` |
| 产品图 / 变体图 | `product.featured_image`、`variant.image` 等产品数据 |
| 结构化内容素材 | metaobject 数据源 |

`assets/` 只放 **CSS / JS 与确认全站固定的技术资源**（如全站通用的 sprite、设计系统固定资产）。确需把某个素材放进 `assets/` 的例外，必须**需求明确并经用户确认**，并写进 handoff 正文说明理由——不得自行决定。

自检命令：

```bash
git status --porcelain assets/ | grep -iE '\.(png|jpe?g|webp|svg|mp4|webm|gif)$'
grep -nE "asset_url" sections/sa-<feature>.liquid snippets/sa-<feature>-*.liquid
```

第二条的合法命中只应是 `stylesheet_tag` / `javascript_tag` 引用自己的 `assets/sa-<feature>.css|js`。

---

## 7. 图片输出

- `image_url` 必须带 `width:`，用于防 CLS / 适配容器。
- **width 取值按容器实际显示宽度 × 高 DPI**，不得用过小 width 把展示图下采样糊掉（图片清晰度红线，见 `plaud-theme-shared/references/media-quality.md`）。
- 图片配置为空时不输出空 `<img>`（见 vendor §8.2）。

```text
伪代码（COMPUTED_WIDTH 是占位，落地时必须替换成算出的整数字面量，不得留占位、不得填 0）：

{%- if section.settings.image != blank -%}
  {{ section.settings.image | image_url: width: COMPUTED_WIDTH | image_tag: loading: 'lazy' }}
{%- endif -%}

COMPUTED_WIDTH = 该图在此容器的实际显示宽度 × 高 DPI 倍数
  · 容器宽度阶梯 → shared responsive-and-spacing.md
  · DPI 倍数     → shared media-quality.md
```

**不同 section、不同容器算出的结果不同**——不要在各 section 之间复制同一个 width 常数，也不要照抄本文件里的任何数字。

---

## 8. CSS / JS 的挂载

- section 自己的样式放 `assets/sa-<feature>.css`，在 section 顶部用 `{{ 'sa-<feature>.css' | asset_url | stylesheet_tag }}` 引入。
- **不得把 `stylesheet_tag` / `javascript_tag` 写在循环体内**（block 循环里输出会重复 N 次）。
- section 内的 `<style>` 只用于输出 CSS 自定义属性（把 schema 值桥接成变量），不写选择器规则集。
- 需要交互时先查主题既有基类（弹窗基类、轮播基类、pub/sub），不另起一套；JS 的监听 / timer / observer / subscription 必须在 `disconnectedCallback` 清理。

---

## 9. Schema 完整性

- 每个 `id` 在本 section 内唯一；同页不得重复 DOM `id`（含 `{{ section.id }}` 拼接）。
- `presets` 必填，preset `name` 同样带 `SA:` 前缀。
- schema 的 `label` / `info` / `content` / option `label` **直接写英文**，不用 `t:` 前缀（见 vendor §8.1）。
- blocks 有 `limit` 需求时显式写 `limit`，不靠约定。
- 新增 schema 字段后必须实跑 Theme Check（`ValidSchemaName` 等），并在 admin 里能保存——这两项由 `plaud-theme-qa` 验，实现侧只负责不留明显缺口。
