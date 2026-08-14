# Vendor 合规速查（§8 文案 / §9 按钮 / §10 价格 / §11 轮播）

节号沿用 PLAUD 主题开发规范（对外版）。**§8 / §9 / §10 是外包交付中最高发的三类问题**，`sa-*` section 提交前必须逐条自查；§11 紧随其后。

> **数值不在本文件。** 字号、字重、颜色 hex / 变量表、间距档、断点、弧角一律读
> `plaud-theme-shared/references/typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md`。
> 本文件只写**判定规则与代码形态**。凡 vendor 原文里的数值表，此处一律替换为"见 shared 对应 reference"。

---

## §8 文案配置规范 ⚠️

多语种（含小语种）是本站核心需求。本节三条规则任一违反，德语 / 法语 / 俄语站点就会出现无法翻译的硬编码字符串或截断。

### §8.1 禁止硬编码，统一走 i18n

- **禁止在 Liquid / JS 中硬编码任何展示文案**：按钮文字、提示语、占位符、弹窗标题、空态文案、错误文案，无一例外。
- 两条合法路径，按场景选：
  - **schema 可配置字段**（需要运营覆盖的文案）：`text` / `textarea` / `richtext`，运营在 theme editor 填写。
  - **主题级固定词汇**：Shopify locales，`{{ 'section.xxx.button_label' | t }}`，翻译写入 `locales/en.default.json` 与 `locales/*.json`。
- **schema 编辑器标签例外**：settings / blocks 的 `label`、`info`、`content`、option `label` **直接在 schema JSON 里写英文**，不使用 `t:` 前缀，也不强制维护 `locales/*.schema.json`。这条常被反向做错——把 storefront 文案硬编码、却给 schema label 加了 `t:`。
- **不得在代码里判断语言后切换字面量**（`{% if request.locale.iso_code == 'de' %}` 之类）；语言差异一律交给 locales 或运营配置。

自检：

```bash
# section/snippet 里可疑的裸展示文案（>）与 JS 字符串
grep -nE '>[A-Za-z][A-Za-z ,.!?\x27-]{3,}<' sections/sa-<feature>.liquid snippets/sa-<feature>-*.liquid
grep -nE "\bt:" sections/sa-<feature>.liquid      # schema label 不应出现 t:
```

### §8.2 禁止代码兜底默认文案，空配置必须隐藏

**schema 的 `default` 可以填英文**——运营能在 theme editor 改它，这是合法占位方式。

**禁止**的是在 Liquid 里用 `| default: '...'` 兜底展示文案：

```liquid
{{- '❌ 禁止：代码里写死兜底文案' -}}
{%- assign price_from_text = bl.price_line_1 | default: 'From' -%}

{{- '✅ 正确：配置为空时直接不渲染' -}}
{%- if bl.price_line_1 != blank -%}
  {{ bl.price_line_1 }}
{%- endif -%}
```

`| default: 'xxx'` 会在运营清空字段后仍强制展示英文，小语种站点因此出现无法翻译的硬编码串。

settings 为 `blank` 时，对应 DOM 节点**不输出**。禁止 `<h2></h2>`、`<a href="#"></a>`、空 `<img>` 之类空壳元素（造成样式空洞与 SEO 问题）：

```liquid
{%- if section.settings.heading != blank -%}
  <h2 class="sa-<feature>__heading">{{ section.settings.heading }}</h2>
{%- endif -%}

{%- if section.settings.button_label != blank and section.settings.button_link != blank -%}
  <a href="{{ section.settings.button_link }}" class="btn btn-primary btn-primary-md">
    {{ section.settings.button_label }}
  </a>
{%- endif -%}

{%- if section.settings.image != blank -%}
  {%- comment -%} COMPUTED_WIDTH 为伪代码占位，算法见 naming-and-structure.md §7；落地时替换成算出的整数 {%- endcomment -%}
  {{ section.settings.image | image_url: width: COMPUTED_WIDTH | image_tag }}
{%- endif -%}
```

注意按钮是**两个字段都非空**才渲染（只有 label 没有 link，会渲染出死链）。

公共块 `section-header` 已按此规则实现，新写 section 必须保持同样行为。

### §8.3 配置文案必须完整显示

除明确带"折叠 / 展开"交互的模块外，所有配置文案必须完整显示，不得因样式被裁剪。

**禁止**对正文 / 描述类文本使用：

- `overflow: hidden` + 固定 `height` / `max-height`
- `text-overflow: ellipsis`
- 多行 `-webkit-line-clamp`
- `white-space: nowrap`（价格不换行单元不在此列，见 §10.5）

容器须允许内容撑开高度；卡片网格用 `align-items: stretch` + `min-height`，**不得固定 `height`**。

```css
/* ❌ 禁止 */
.sa-x__desc { height: 任意固定值; overflow: hidden; text-overflow: ellipsis; }

/* ✅ 推荐 */
.sa-x__desc { /* 让内容自然撑开 */ }
.sa-x__card { min-height: var(--sa-x-card-min-h); display: flex; flex-direction: column; }
```

**允许的例外**：折叠组件（FAQ / Accordion / Show more）截断后必须有展开方式；标题若设计稿要求省略，须 PM 评审确认并在 schema 中提供行数开关——**不是开发自行决定**，无确认就停机。

自检：

```bash
grep -nE "line-clamp|text-overflow|white-space:\s*nowrap|overflow:\s*hidden" assets/sa-<feature>.css
```

每一条命中都要能说清它属于哪个例外，说不清就是违规。

---

## §9 按钮规范 ⚠️

擅自创建按钮类名、固定宽高、硬编码颜色值——交付中最常见的三个问题。

### §9.1 只用全局按钮类名

基础样式由主题的 `snippets/critical-style.liquid` 全局定义（路径以目标仓库为准）。允许的基础类**仅三个**：

| 类名 | 用途 |
|---|---|
| `.btn-primary` | 实色主按钮（背景色由配色方案变量驱动） |
| `.btn-outline` | 描边次级按钮（透明背景 + 边框） |
| `.btn-white` | 白色主按钮（v1.3 新增；具体色值见 shared `colors-and-schemes.md`） |

**尺寸档**：在基础按钮类上叠加**纯尺寸类** `.btn-primary-{lg|md|sm}`（只设 padding / font-size / font-weight，不改颜色）。用法硬规则：

> **Primary-LG 只用在 Banner；其它一律 Primary-MD；仅特殊说明才用 Primary-SM。**

```liquid
<a href="…" class="btn btn-primary btn-primary-md">…</a>
<a href="…" class="btn btn-outline btn-primary-md">…</a>
<a href="…" class="btn btn-white   btn-primary-lg">…</a>   {%- comment -%} 仅 Banner {%- endcomment -%}
```

基础样式（padding / font-size / border-radius / color / background / border）统一由 CSS 变量控制，section 内**不得**逐个重定义。

**禁止自行创建新按钮类名**（`.sa-x__btn` 之类只能作为定位/布局钩子，不得承载按钮视觉），不得脱离全局类名体系。

### §9.2 特殊定制只改颜色变量

确有差异时，**仅覆盖颜色 CSS 变量**微调；颜色优先用变量，特殊情况才直接用色值，且**须设计明确要求并经确认**。

```css
/* ✅ 优先：通过变量修改颜色 */
.sa-x .btn-primary {
  --btn-primary-bg-color: var(--color-purple);
  --btn-primary-hover-bg-color: var(--hover-color-purple);
}

/* ✅ 允许（须设计要求 + 经确认）：特殊情况直接写色值 */
/* 色值本身查 shared colors-and-schemes.md，不在此处列表 */

/* ✅ 尺寸走 spec 档：叠纯尺寸类，不在此自定 padding / font-size */
```

**尺寸不在此自定义**——按 §9.1 叠纯尺寸类；确需非标尺寸须需求明确并经确认，否则停机。

### §9.3 不可固定宽高

不同语种文案长度差异大（德 / 法 / 西 / 俄可能比英文长 30–50%），固定宽高必然截断或溢出。

- **禁止** `width: <固定值>` / `height: <固定值>`。
- 只允许 `min-width` / `min-height`，实际尺寸由 `padding` 撑开。
- 同组按钮对齐用 flex，不得以固定宽高强制对齐。

自检：

```bash
grep -nE "^\s*(width|height)\s*:\s*[0-9]" assets/sa-<feature>.css
```

---

## §10 产品价格显示 ⚠️

价格硬编码、货币符号写死、未用格式化 snippet / 方法——三大常见问题。

### §10.1 数据源优先级

1. **后台 product / variant 数据**：`product.price`、`product.compare_at_price`、`variant.price`、`product.selected_or_first_available_variant.price`。
2. section settings 仅在后台确无对应数据时作为补充（极少情况）。
3. **禁止**在 section settings 里硬编码价格数字，**禁止**在 Liquid 里拼接 `"$99"` 这类字符串。

### §10.2 多货币

- 使用 Shopify 原生多货币能力：`cart.currency`、`shop.currency`、`Shopify.currency.active`。
- **禁止固定货币符号**：`$`、`€`、`¥` 必须由过滤器或格式化方法输出。
- Markets / Currency selector 变更时页面须正确反映。

### §10.3 Liquid 渲染：优先 `price-format.liquid`

```liquid
<span class="price-wrap">
  {%- render 'price-format', price: product.price -%}
</span>
```

该 snippet 内部逻辑（了解即可，不要复制实现）：

1. 默认 `{{ price | money }}`。
2. `settings.show_currency_code` 开启 → `{{ price | money_with_currency }}`。
3. `settings.enable_custom_currency_format` 开启且当前货币等于商店货币 → 按 `settings.custom_currency_format_string` 的占位符匹配 8 种格式之一：

| 占位符 | 输出示例 | 说明 |
|---|---|---|
| `amount` | `1,234.56` | 标准千分符 + 小数点 |
| `amount_no_decimals` | `1,234` | 无小数 |
| `amount_with_comma_separator` | `1.234,56` | 欧式逗号小数点 |
| `amount_no_decimals_with_comma_separator` | `1.234` | 欧式无小数 |
| `amount_with_space_separator` | `1 234,56` | 空格千分符 |
| `amount_no_decimals_with_space_separator` | `1 234` | 空格无小数 |
| `amount_with_apostrophe_separator` | `1'234.56` | 撇号千分符 |
| `amount_no_decimals_with_apostrophe_separator` | `1'234` | 撇号无小数 |

**少数自定义场景**（snippet 无法满足特殊布局）可直接用 Shopify 原生过滤器，但必须同样兼容 `settings.show_currency_code`。

### §10.4 JS 渲染：`Shopify.formatMoney`

动态渲染价格（加购后更新、变体切换等）用 `assets/global.js` 中定义的 `Shopify.formatMoney`：

```js
// cents 单位为分；money_format 从页面注入的 cartStrings 中取
const priceStr = Shopify.formatMoney(cart.total_price, cartStrings?.money_format);
```

支持的占位符与 `price-format.liquid` 的 8 种完全对应。入参 `cents` 接受数字或字符串（自动去小数点）；`cartStrings` 是页面通过 `<script>` 注入的 JSON，含 `money_format` 等后台配置字符串。**不要自己写一份 money 格式化函数。**

### §10.5 价格与货币不能换行

价格数字与货币符号 / 代码视为整体，任何断点下不允许被拆到两行。

```css
.price-wrap { display: inline-block; white-space: nowrap; }
```

原价 + 划线价 + 折扣价并排时，**在每一个 `price-wrap` 单元上各自加 `white-space: nowrap`，不要整体包一层**——整体包一层会让三个单元之间也无法换行，窄屏溢出。

---

## §11 轮播分页 / 翻页样式统一

所有用 Swiper 的模块（商品轮播、图文轮播、评价轮播）分页与翻页按钮必须统一，不得每个 section 自行实现。

```liquid
{%- render 'section-swiper', class: '…', style: '' -%}
```

`class` 传的是主题 utility（`justify-*` 控位置、`mt-*` 控上间距）；具体上间距档位按设计稿对应的 spacing 档选，档位表见 shared `responsive-and-spacing.md`。

该 snippet 已含 `.swiper-button-prev`（`#icon-back`）、`.swiper-pagination`、`.swiper-button-next`（`#icon-next`），默认 `flex justify-end`。

初始化时选择器指向 snippet 输出的节点：

```js
new Swiper(el, {
  navigation: {
    prevEl: el.querySelector('.swiper-button-prev'),
    nextEl: el.querySelector('.swiper-button-next'),
  },
  pagination: { el: el.querySelector('.swiper-pagination'), clickable: true },
});
```

- **禁止**在 section 内重写 `.swiper-button-prev` / `.swiper-button-next` / `.swiper-pagination` 的**视觉样式**；有设计差异 → 提 PM 评审后扩展公共样式，不在本 section 私改。
- 位置调整通过 `class` 参数传入（`justify-start` / `justify-center` / `justify-end` / `mt-*`），**不要复制 snippet 再改**。
- Swiper effect 的既有约束（cards / cube / fade / vertical 各自的必须与禁止项）见 `plaud-theme-shared/references/javascript-swiper.md`。
- 轮播按钮须是语义 `button` 并带 `aria-label`（A11y 底线，见 shared `a11y.md`）。

自检：

```bash
grep -nE "swiper-(button-(prev|next)|pagination)" assets/sa-<feature>.css
```

任何命中都要能说明它只是布局定位而非视觉重写。

---

## 提交前 Checklist（vendor 原版 + Path B 补充）

> **一处措辞澄清**：vendor 原版 Checklist 有一条写作「schema `default` 不含硬编码展示文案」，与 §8.2 正文「schema 的 `default` 可以填英文」字面冲突。**以 §8.2 正文为准**——那条 Checklist 指的是 **Liquid 里的 `| default:` 兜底**，不是 schema 的 `default` 属性。下面已按正文语义改写，不是漏项。

- [ ] 模块宽度 / 间距 / 字号 / 弧角严格按 shared 的 typography / colors-and-schemes / responsive-and-spacing（**不在 section 内插值、不复制数值**）
- [ ] Section 标题已复用 `section-header` 公共块，三字段为 `textarea`
- [ ] 所有 storefront 展示文案走 schema 字段或 locales，Liquid / JS 无硬编码
- [ ] schema 编辑器标签（`label` / `info` / `content` / option `label`）为英文，未用 `t:` 前缀
- [ ] Liquid 无 `| default: '...'` 兜底展示文案；空配置已做 `!= blank` 判断，不输出空壳 DOM
- [ ] 正文 / 描述类文案无 `overflow:hidden`+固定高 / `ellipsis` / `line-clamp` / `nowrap` 截断（折叠组件例外且有展开方式）
- [ ] 按钮只用 `btn-primary` / `btn-outline` / `btn-white` + 纯尺寸类 `btn-primary-{lg|md|sm}`（LG 只 Banner / 其它 MD / 特殊 SM），无自创按钮类名
- [ ] 所有按钮无固定 `width` / `height`，仅 `min-width` / `min-height`
- [ ] 所有价格走 `render 'price-format'`，每个 `price-wrap` 单元各自 `white-space: nowrap`；无硬编码货币符号与价格数字；JS 用 `Shopify.formatMoney`
- [ ] 所有 Swiper 已复用 `section-swiper.liquid`，未重写分页 / 翻页视觉
- [ ] 内容图片 / 视频 / icon 未写死进 `assets/`，运营素材走 schema 或数据源（例外已经用户确认）
- [ ] `sa-*` 文件名 / `SA:` schema name / BEM 根类名三处一致
- [ ] `container` + `section_top_pc` / `section_bottom_pc`，CSS 无 section 级硬编码 margin
- [ ] 需切换配色处 `gradient` + `color-{{ … }}` 两个类都在
- [ ] `anchor_id_for_category` 在 `.container` 同层
- [ ] 响应式三层变量策略（`-m` / `-pc` → 运行变量 → 属性），断点内只改变量映射
- [ ] 组件未写死宽高；例外已说明原因
- [ ] 空配置与满配置**双测**通过
- [ ] 英译德长文案测试通过（无溢出 / 遮挡 / 异常换行）
