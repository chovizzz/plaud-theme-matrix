# Liquid / Schema / 文案格式规范

**何时读我**：写或改 `.liquid`、schema JSON、locales、价格渲染、文案配置字段时；或 Theme Check 报错要对照规则时。

> 本文是矩阵内 Liquid / schema / 文案规则的**唯一事实源**。其它 skill 不得复制这里的规则，只得引用本文件。
> 「展示文案走 schema 或 locales」的**红线正文**在 `handoff-schema.md` §8.1；本文是它的可执行细则。

---

## 1. §8.1 执行配方（文案 i18n）

> 规范性判定只见 `handoff-schema.md` §8.1。本节不重新定义"违没违规"，只给三件事的**做法与扫描方法**。
> 本站面向多语种（含小语种），这是外包交付中**最高发**的问题环节。

### 1.1 走 schema 还是走 locales

**判定对象**：liquid / js 中硬编码的展示文案——按钮文字、提示语、占位符、弹窗标题、空态文案、错误文案。

两种合法方案（按场景选）：

| 场景 | 方案 |
|---|---|
| 需要运营覆盖的文案 | **schema 可配置字段**：`text` / `textarea` / `richtext`，运营在 theme editor 填写 |
| 主题级固定词汇 | **Shopify locales**：`{{ 'section.xxx.button_label' | t }}`，翻译写进 `locales/en.default.json` / `locales/*.json` |

**不得在代码中判断语言后切换字面量。** 字段内容一律交由运营在 theme editor 填写。

扫描方法：`grep -nE '>[A-Za-z][A-Za-z ]{3,}<' sections/<file>.liquid` 找裸英文文本节点；JS 侧 `grep -nE "(textContent|innerHTML|placeholder)\s*=\s*['\"][A-Za-z]"`。

### 1.2 `| default:` 兜底的扫描与替换

`| default: 'xxx'` 会在运营清空字段后仍强制展示英文，导致小语种站点出现**无法翻译的硬编码字符串**。

扫描：`grep -nE "\|\s*default:\s*['\"]" sections/ snippets/`，逐条判断命中的是不是**展示文案**（见下方例外）。

```liquid
{{- '❌ 禁止：代码里写死兜底文案' -}}
{%- assign price_from_text = bl.price_line_1 | default: 'From' -%}

{{- '✅ 正确：配置为空时直接不渲染' -}}
{%- if bl.price_line_1 != blank -%}
  {{ bl.price_line_1 }}
{%- endif -%}
```

> 注意区分：**schema 的 `default` 字段可以填英文**（见 §2），这是合法占位；禁止的是 **Liquid 代码里的 `| default:` 过滤器兜底展示文案**。
> `| default:` 用于**非文案**的技术回退（如 `image_ipad | default: image` 选图源、`card_background_color | default: '#F7F7F7'` 取色）**不在禁止之列**。

### 1.3 `blank` 字段的条件渲染模板

settings 为 `blank` 时对应 DOM 节点**不输出**，禁止出现 `<h2></h2>`、`<a href="#"></a>`、空 `<img>`（造成样式空洞 + SEO 问题）：

```liquid
{%- if section.settings.heading != blank -%}
  <h2 class="section-heading">{{ section.settings.heading }}</h2>
{%- endif -%}

{%- if section.settings.button_label != blank and section.settings.button_link != blank -%}
  <a href="{{ section.settings.button_link }}" class="btn btn-primary btn-primary-md">
    {{ section.settings.button_label }}
  </a>
{%- endif -%}

{%- if section.settings.image != blank -%}
  {{ section.settings.image | image_url: width: 1200 | image_tag }}
{%- endif -%}
```

公共块 `section-header` 已按此实现，新写 section 必须保持同样行为。

⚠️ 关联陷阱：flex + `gap-sp-*` 父级下，**空 wrapper `<div>` 仍吃 gap** 撑出幽灵空白——见 `responsive-and-spacing.md` §7.4 的 `capture` + `strip` 写法。

### 1.4 `section_disclaimer`

免责声明块同样"有内容才渲染"，字号/颜色走 critical utility class，对齐跟随区头映射变量——细则见 `colors-and-schemes.md` §4.3。

---

## 2. Schema 编辑器标签：直接写英文，不用 `t:`

| 位置 | 写法 |
|---|---|
| settings / blocks 的 `label` / `info` / `content`、option `label` | **直接在 schema JSON 里写英文** |
| 是否用 `t:` 前缀 | **不用** |
| 是否维护 `locales/*.schema.json` | **不强制** |

**schema `default` 可以填英文**——运营可在 theme editor 修改，这是合法的占位方式；但配套必须做 `!= blank` 判断（§1 规则 3）。

区分口径：`t:` / locales 面向 **storefront 展示文案**（顾客看得到）；schema 的 label / info 是**后台编辑器界面文案**（只有运营看得到），直接英文即可。

---

## 3. 配置文案必须完整显示

除明确带"折叠 / 展开"交互的模块外，所有配置文案必须完整显示，不得因样式被裁剪。

**禁止**对正文 / 描述类文本使用：

- `overflow: hidden` + 固定 `height` / `max-height`
- `text-overflow: ellipsis` 或多行 `-webkit-line-clamp`
- `white-space: nowrap`（价格不换行单元除外，见 §5.5）

```css
/* ❌ 禁止 */
.card-desc { height: 60px; overflow: hidden; text-overflow: ellipsis; }

/* ✅ 推荐 */
.card-desc { /* 让内容自然撑开 */ }
.card      { min-height: 320px; display: flex; flex-direction: column; }
```

容器须允许内容撑开高度；卡片网格用 `align-items: stretch` + `min-height`，**不得固定 `height`**。

**允许的例外**：

| 例外 | 条件 |
|---|---|
| 折叠组件（FAQ / Accordion / Show more） | 截断后**必须有展开方式** |
| 标题按设计稿要求省略 | 需 PM 评审确认，并在 schema 提供行数开关 |
| 已确认的设计特例（如 Marquee 详情卡的 `line-clamp: 3`） | 须 PM 明确确认并登记为已批准偏差 |

---

## 4. 多语言长文案验收

德 / 法 / 西 / 俄语可能比英文长 30–50%。**把英文文案翻成德语再看 UI**：是否溢出、换行异常、遮挡。这是 `QA-Global` 的 `LocalizationCheck` 项，不是可选项。

---

## 5. 价格规范

### 5.1 数据源优先级

1. **后台 product / variant 数据**：`product.price`、`product.compare_at_price`、`variant.price`、`product.selected_or_first_available_variant.price`；
2. section settings 仅在后台确无对应数据时作为补充（极少情况）；
3. **禁止**在 section settings 里硬编码价格数字，也禁止在 liquid 中拼接 `"$99"` 这类字符串。

### 5.2 多货币

- 用 Shopify 原生多货币能力：`cart.currency`、`shop.currency`、`Shopify.currency.active`；
- **禁止固定货币符号**——`$`、`€`、`¥` 必须由过滤器或格式化方法输出；
- Markets / Currency selector 变更时页面须正确反映。

### 5.3 Liquid 渲染：`price-format.liquid`

```liquid
<span class="price-wrap">
  {%- render 'price-format', price: product.price -%}
</span>
```

snippet 内部逻辑：

1. 默认 `{{ price | money }}`；
2. `settings.show_currency_code` 开启 → `{{ price | money_with_currency }}`；
3. `settings.enable_custom_currency_format` 开启且当前货币 = 商店货币 → 按 `settings.custom_currency_format_string` 的占位符匹配下列 8 种之一。

| 占位符 | 输出示例 | 说明 |
|---|---|---|
| `amount` | `1,234.56` | 标准千分符 + 小数点 |
| `amount_no_decimals` | `1,234` | 无小数 |
| `amount_with_comma_separator` | `1.234,56` | 逗号小数点（欧式） |
| `amount_no_decimals_with_comma_separator` | `1.234` | 欧式无小数 |
| `amount_with_space_separator` | `1 234,56` | 空格千分符 |
| `amount_no_decimals_with_space_separator` | `1 234` | 空格无小数 |
| `amount_with_apostrophe_separator` | `1'234.56` | 撇号千分符 |
| `amount_no_decimals_with_apostrophe_separator` | `1'234` | 撇号无小数 |

**少数自定义场景**（snippet 满足不了特殊布局）可直接用 Shopify 原生过滤器，但必须同样兼容 `settings.show_currency_code`。

首屏价格优先走 `price-format`（与 JS 的 `Shopify.formatMoney` 等价），可消除首屏跳变。

### 5.4 JS 渲染：`Shopify.formatMoney`

```js
// cents 单位为分；money_format 从页面注入的 cartStrings 取
const priceStr = Shopify.formatMoney(cart.total_price, cartStrings?.money_format);
```

- 定义在目标仓库的 `assets/global.js`；
- 支持的格式占位符与 `price-format.liquid` 的 8 种**完全对应**；
- 入参 `cents` 接受数字或字符串（自动去除小数点）；
- `cartStrings` 是页面通过 `<script>` 注入的 JSON 对象，含 `money_format` 等后台配置字符串。

### 5.5 价格与货币不能换行

```css
.price-wrap { display: inline-block; white-space: nowrap; }
```

原价 + 划线价 + 折扣价并排时，在**每一个 `price-wrap` 单元**上加 `white-space: nowrap`，**不要整体包一层**。

（这是 §3 禁 `white-space: nowrap` 的唯一例外。）

---

## 6. HTML / Liquid 基础格式规则

| 规则 | 说明 |
|---|---|
| **HTML 尺寸属性只能是数字** | `width="1200"` ✅ / `width="1200px"` ❌ / `width="100%"` ❌ |
| **同页不重复 id** | 含 `{{ section.id }}` 拼接的 id。多实例同页时重复 id 会让"仅首个可用"（视频弹窗踩过） |
| 生产代码无 `console.log` | — |
| 响应式值走 CSS 自定义属性 | 不写 inline style（inline style 覆盖媒体查询） |
| 组件宽高不写死 | 不在 CSS / inline style / Liquid 输出里写死；红线正文见 `handoff-schema.md` §8.2 |
| section 上下间距走 schema | CSS 不硬编码 `margin-top` / `margin-bottom`；见 `responsive-and-spacing.md` §5 |
| section 内 `<style>` 只输出 CSS 自定义属性 | 不写具体规则 |
| `stylesheet_tag` 在 section 顶层输出**一次** | 新建 `sa-*` section 的 CSS 用 `{{ 'sa-<feature>.css' \| asset_url \| stylesheet_tag }}` 放在 section 顶层；**不得**放进 block 循环或被循环 render 的 snippet（会重复输出 N 次）。资源已由全局 bundle 加载时不要重复输出 |
| build 产物勿手改 | 落到源 + 重新 build；红线正文见 `handoff-schema.md` §8.7 |

### 6.1 注释纪律

- **默认不写注释**；只在 WHY 非显然时一行内说明。
- 禁止「used by X / added for Y flow / removed because Z」这类指向当下任务的注释。
- 禁止跨文件指引（"详见 style.scss"）。

---

## 7. 命名规范（Path B 新建 section）

| 层级 | 规则 | 示例 |
|---|---|---|
| Section | `sections/sa-<feature>.liquid` | `sa-shop-banner.liquid` |
| Snippet | `snippets/sa-<feature>-<part>.liquid` | 按需 |
| CSS | `assets/sa-<feature>.css` | `sa-shop-banner.css` |
| Schema name | `SA: ` 前缀 | `"name": "SA: Shop Banner"` |
| **Preset name** | `SA: ` 前缀（`presets[].name` 同样要带） | `"presets": [{ "name": "SA: Shop Banner" }]` |
| 根类名 | BEM `sa-<feature>` | `<div class="sa-shop-banner">` |

### 7.1 HTML 三层结构

```
outer wrapper   → scheme 类（gradient + color-{scheme}）与 overflow-hidden 放在【同一层】
  inner container → anchor id + container + section_top_pc + section_bottom_pc
    content       → 实际模块内容
```

- **不要**把 scheme 类放到 `__outer`、把 `overflow` 放到最外层——同层维护更直观。
- `anchor_id` 必须与 `.container` **同层**：跳转锚点要落在内容上沿，不是 wrapper margin 之上。
- card 模式（默认 `bg-white`）与 full-bleed scheme **互斥**，二选一——见 `colors-and-schemes.md` §2.2。

Section 容器标准写法：

```liquid
<div id="{{ section.settings.anchor_id_for_category | handle }}"
     class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
</div>
```

配套 schema：

```json
{ "type": "text", "id": "anchor_id_for_category", "label": "Anchor ID For Category" }
```

标题公共块：

```liquid
{%- render 'section-header',
    pre_heading: section.settings.pre_heading,
    heading:     section.settings.heading,
    sub_heading: section.settings.sub_heading -%}
```

```json
{ "type": "header",   "content": "+ Heading" },
{ "type": "textarea", "id": "pre_heading", "label": "Pre Heading" },
{ "type": "textarea", "id": "heading",     "label": "Heading" },
{ "type": "textarea", "id": "sub_heading", "label": "Sub Heading" }
```

---

## 8. Schema 放宽的向后兼容

放宽 `step` / `min` / `max` **前**必须确认：

1. **老的合法值在新约束下仍合法**。例：`step: 5` 下的 0/5/10/…/50，在 `step: 1, max: 60` 下依然合法（步长收紧 vs 上限拉高——**通常拉高安全，收紧危险**）。
2. **默认值改动只影响新建实例**，存量不变。
3. **删 schema 字段允许**（如字号锁定后移除 H1–H6 select）：模板里残留的该字段 stored 值被 Shopify 忽略、不报错。这与"templates 只读"**不冲突**——只读约束针对**主动改模板存值**，不针对删 schema 定义。
4. 🔴 **删了 schema 字段 / CSS 变量 / `data-*` 属性后，全仓 grep 残留引用**（CSS `var(--xxx)` / liquid `settings.xxx` / JS `dataset.xxx`），确认无 dangling 再收尾。共享 snippet / 全站组件迁移尤其要做九宫格式连带清理：schema 字段 → 全局 CSS 变量（`theme.liquid` / `password.liquid`）→ 各引用文件的 dead `data-*` → 动态创建该组件的 JS。

**schema setting 已有的 option values 永远不改**——哪怕只换命名风格也不行。想换 emit 出来的 class / token，只在 **Liquid 端做映射**。

**Schema 范围验证**：改完用 Shopify admin 后台保存试一下——`step` / `max` / `range` 限制只有 admin 才会检查。

**JSON 语法验证**（模板 / 配置 JSON）：
```bash
node -e "const fs=require('fs');const f=process.argv[1];JSON.parse(fs.readFileSync(f,'utf8').replace(/^\s*\/\*[\s\S]*?\*\//,''));console.log('ok',f)" templates/index.json
```
（`replace` 用于跳过 Shopify 自动添加的注释头。）

---

## 9. Theme Check 高发项 → 对应规则

`ThemeCheck` 的**执行方式与判定口径**（baseline 增量，不是绝对 pass）定义在 `handoff-schema.md` §6，本节只给"报了这条错该翻哪条规则"。

| check | 症状 | 对应规则 |
|---|---|---|
| `LiquidHTMLSyntaxError` | Liquid 标签 / HTML 未正确闭合或嵌套 | 本文 §6 Liquid 文件格式 |
| `UnclosedHTMLElement` | 有开标签无闭标签 | 同上。常见于 `{% if %}` 分支里只写了一半标签 |
| `ImgWidthAndHeight` ⚠️**高发** | `<img>` 缺 `width` / `height` **HTML 属性**（与 `image_url: width:` 无关） | `media-quality.md` §2（防 CLS）；注意 `width` 属性只能是数字（本文 §6）。实测某仓库全仓 **35 条 error**，是真实高发项，值得在 baseline 比对时单独盯 |
| `ValidSchemaName` | schema `name` 不合规 / 超长 | 本文 §7 —— Path B 必须 `SA: ` 前缀 |
| `MissingAsset` / `MissingTemplate` | 引用了不存在的 `asset_url` / template | 检查文件是否已提交；若引用的是内容素材，见 `media-quality.md` §7（素材不得写死进 assets） |
| `UnknownFilter` | 用了不存在的过滤器（常见拼写错误） | 本文 §5 价格过滤器 / §1 `| t` 用法 |
| `DeprecatedFilter` | 用了已废弃过滤器（如 `img_url`） | 改用 `image_url` + `image_tag`（`media-quality.md` §1.2） |
| `UndefinedObject` | 用了未定义的对象 / 变量 | 常见于 snippet 未显式传参——`render` 是隔离作用域，必须显式传 `product` / `section` / 各标志位 |
| `UnusedAssign` | `assign` 了没用的变量 | 删掉；常是重构剩下的死代码 |
| `ParserBlockingScript` | 同步 `<script>` 阻塞解析 | 加 `defer` / `async`，或移到 body 末；性能项 |

> `ThemeCheck: Passed` 只代表**静态 lint 无新增 offense**，不得表述为"Shopify 兼容性全部通过"。运行时行为、视觉、admin 保存分别由 `ThemeRuntimePreview` / `AdminSchemaSave` / `RegressionMatrix` 承担（`handoff-schema.md` §6）。

---

## 10. Path B 提交自查（文案 / 价格 / 格式相关）

- [ ] 所有 storefront 展示文案走 schema 字段或 locales，Liquid / JS 无硬编码
- [ ] Liquid 中无 `| default: '...'` 兜底展示文案
- [ ] 所有可空字段做了 `!= blank` 判断，无空壳 DOM
- [ ] schema 编辑器标签（`label` / `info` / `content`）为英文，未用 `t:` 前缀
- [ ] 正文 / 描述类文案无 `overflow: hidden` / `line-clamp` 截断（折叠组件除外）
- [ ] 所有价格走 `render 'price-format'`，每个 `price-wrap` 单元加 `white-space: nowrap`
- [ ] 无硬编码货币符号
- [ ] HTML 尺寸属性均为数字；同页无重复 id
- [ ] schema `name` **与 `presets[].name`** 均带 `SA: ` 前缀
- [ ] `stylesheet_tag` 在 section 顶层输出一次，未落进 block 循环
- [ ] HTML 三层结构正确；`anchor_id` 与 `.container` 同层
- [ ] Section 标题已复用 `section-header`
- [ ] 上下间距走 `section_top_pc` / `section_bottom_pc`，无 section 级硬编码 margin
- [ ] 英文文案已翻成德语做长度测试，UI 无溢出 / 遮挡 / 异常换行
