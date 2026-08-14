# 踩坑库 — 组件层（§4.7 §4.13 §4.18 §4.19）

> **配方前提**：本文件是「**已获授权的迁移中怎么做**」，不是做出改动的授权本身。
> 一律在 Path C 硬规则之下运行：① `templates/*.json` 默认只读；② 不写死颜色 / 不逐元素开 color picker；
> ③ 不写死组件宽高；④ 非 spec 值等距两可**问用户**、不擅自 snap；⑤ schema option values 不改、验收前不写 UX 差异日志内容。
> 冲突时**以硬规则 + 其授权为准**。完整总纲见 SKILL.md「§4.x 配方的适用前提」。

---

## §4.7 轮播控件统一（swiper 导航 / 分页）

迁移带轮播的模块时，把旧式控件标记统一成 `{%- render 'section-swiper' -%}`
（输出 `.cs-section-swiper`：上一页按钮 + 进度条 / 分页 + 下一页；样式在 critical，**无 FOUC**；与 delta-trust-carousel 同款）。

- **删旧标记**：`.delta-trust-pagination-progressbar` / `.trust-arrow` / `.swiper-actions` 这类旧控件 DOM
- **删 `trust-swiper` 类**：它带一段 `padding-bottom`（旧底部绝对定位进度条的预留位），换 section-swiper 后是多余空白。**保留 `swiper` 核心类与懒加载类**
- **slide-section 自动绑定**：JS 用通用 `.swiper-button-prev/next` + `.swiper-pagination`（正是 section-swiper 提供的），`data-pagination-progressbar="true"` 走 `.cs-section-swiper .swiper-pagination` 的 critical 进度条样式，**无需额外接线**

### 「无下一页时隐藏控件」

🔴 `.cs-section-swiper` **自带纵向 padding** —— 仅靠 Swiper 的 lock 类隐藏内部按钮 / 分页，**仍会留下约两倍 padding 的容器空白**。必须隐藏**整个控件容器**：

- **slide-section（固定 perView，多断点）**：按"数量 > 当前断点每屏数"用 **critical 内联 CSS** 控制 `.cs-section-swiper` 的 `display`（mobile > 1 / tablet > 2 / desktop > 每行数）。
  ⚠️ 该组件的断点是 **组件既有断点特例（768 / 1025），勿泛化到全局 `.98` 精度判定**。flash-free。
- **`slidesPerView: auto`（2 档）**：参照 custom-product-list —— liquid 按 `数量 > 每行数`(PC) / `数量 > 1`(MB) 设 `--action-display`，配 `.xxx{display: var(--action-display, none) !important}`

> `<source media>` 的断点精度（§4.11）见 `pitfalls-shared-scope.md`。

## §4.13 模块区头：间距与对齐的通用坑（`cs-section-header`）

迁移任何用 `section-header` snippet（输出 `.cs-section-header`）的模块区头时**必查**：

### 1. legacy 双重间距 `.section__header mb-33 mb-sm-20`

很多模块（legacy multi-content、ww-multi-content 等）把区头包在 `.section__header mb-33 mb-sm-20` 外层，而里层 `.cs-section-header` 自己**已带 spec 的 space-8 下间距**；margin 折叠后取大值（33px，双重）。

- **去掉外层 `mb-33 mb-sm-20`** → 由 spec 间距接管
- ⚠️ `mb-sm-20` 实测是**失效死类**（移动端也渲染 33、不是 20），所以**两端都是 33 → spec 值**，不是只改桌面

### 2. 区头对齐要走 snippet 参数，不是外层 `text-*`

`.section__header` 外层的 `text-{align}` 是**非 important**，会被 snippet 给每个标题元素输出的 `text-{x}!`（important，来自 base-style 全局 bundle，默认 center）**盖掉** → 外层对齐其实**不生效**。

- 控制某模块区头对齐**必须传参进 snippet**（`text_align_pc` / `text_align_mb`）
- 若模块当前靠外层 `text-*`，**多半是没生效的遗留**

### 3. 「模块已迁」≠「该实例移动端已左对齐」——必须逐实例查存值

移动端区头对齐是**每实例存值**：某实例若从未设过对齐字段 → 走 schema 默认（多为 `center`），**即便模块代码层早已迁移，该实例移动端仍居中**。

审计某模板「移动端区头左对齐」时**逐个实例查**（缺字段 = 默认居中，要补），**别因"这模块在别处刷过了"就跳过**。
补法 = 给该实例存值加对齐字段 —— 🔴 **本轮已获模板存值编辑授权才补；否则报告「待确认」，勿擅改模板。**

**三个易错点（都会让批量处理出错）：**

- 🔴 **「左」的存值因模块而异**：`ww-multi-content` / `tt-fade-switch-video` = **`left`**；`delta-trust-carousel` / `ss-marquee` = **`start`**（center / 右 = `end`）。
  **按各模块 schema 的 option value 填，别统一写 `left`**（schema option values 不改，见 `hard-rules.md` §2.2）
- 🔴 **对齐字段名因模块而异**：`header_alignment_mobile`（WW / fade-switch）/ `header_align_mb`（faq-list / delta-trust / marquee）/ `title_align_mb`（delta-accordion）
- 🔴 **标题字段名也不统一**：Marquee 的标题是 `text_heading`（**非** `heading`）。批量 grep `"heading"` 审计**会漏 Marquee**，也会把空 `heading` 误判成「无区头」——**按模块逐个确认实际渲染的标题字段**

## §4.18 gap-flex 父级里的可选子块要"有内容才渲染"

父级用 `flex flex-col gap-sp-*` 统一子块间距时，**空的 wrapper `<div>` 仍是 flex item、照样吃 gap** → 撑出**幽灵空白**。

可选区块（可能整段为空的视觉区 / 注入区）用 capture + strip 包起来，空则不渲染 div：

```liquid
{%- capture x -%}…{%- endcapture -%}
{%- assign x = x | strip -%}
{%- if x != blank -%}<div>{{ x }}</div>{%- endif -%}
```

## §4.19 product-item 的"菜单上下文"判断用 `card_bg == 'white'`

共享 `snippets/product-item.liquid` 要区分"下拉大菜单里的商品卡 vs 集合页等其它位置"做条件样式时，用 **`card_bg == 'white'`** ——
mega 菜单的 render 传 `card_bg: 'white'`，其余场景默认 `tertiary`，所以这个参数是可靠的"菜单上下文"信号。

实战用途：把图片区内距限定为"仅菜单卡片"，不波及集合页 / 搜索页 / 推荐位。

> 🔴 **用前先核对当前有哪些调用方传 `white`** —— 调用点会随版本变化，
> 清单取自 `AssessmentRef` 的 `SharedPropagation`（impact §4.1 会列出每个调用点传的参数），**不要凭"只有两处"的旧印象下判断**。
