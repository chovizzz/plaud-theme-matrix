# Media Quality — 图片清晰度 / 视频 / 素材来源

**何时读我**：任务涉及 `image_url`、`image_tag`、`<picture>` / `<source>`、懒加载、视频、或要新增图片 / icon / 视频素材时。

> 本文是**图片清晰度红线的唯一操作化细则**。红线正文（规范性表述）在 `handoff-schema.md` §8.3；本文不重复定义判定标准，只给适用范围与取值方法。其它 skill 不得复制这里的规则，只得引用本文件。

---

## 1. §8.3 的适用范围与取值方法

> 规范性正文见 `handoff-schema.md` §8.3。下面方框内是该条**原文引述**（便于就地对照，**非二次定义**）；本节其余内容回答三个执行问题：哪些图片适用、`width` 怎么算、怎么验证。

> **展示 / 内容型 section 不得给图片加清晰度 / 分辨率上限。**
> `image_url` 的 `width:` 只用于**防 CLS 与适配容器**，取值须按容器**实际显示宽度 × 高 DPI**（通常 ≥ 2×，或用足够大的 width / `master` / 响应式 srcset）。
> **禁止用过小的 `width` 把展示图下采样糊掉。**
> （仍要带 width / height 防 CLS + 懒加载，但不得以牺牲清晰度为代价。）

### 1.1 适用的 section 类型

| 类型 | 举例 |
|---|---|
| 折叠 / 手风琴展示 | `delta-accordion` |
| 首屏轮播 | `slideshow`（含 New Slide） |
| 多内容图文 | `multi-content`、`ww-multi-content` |
| banner / 大图 | 各类 banner、`image_with_text_overlay` 叠图 banner |
| 卡片配图 | 商品卡、KOL 卡、对比图、规格表配图 |
| 其它 | 任何以"图片本身是内容"为主的 section |

判定口径：**图片是"内容"还是"装饰"**。是内容 → 适用红线；纯装饰性小图标、1px 线、技术占位 → 不适用（但仍要防 CLS）。

### 1.2 正确 / 错误取值

```liquid
{{- '❌ 错误：容器 1200px 宽却只取 480，展示图被下采样糊掉' -}}
{{ section.settings.image | image_url: width: 480 | image_tag }}

{{- '✅ 正确：容器显示宽 1200 × 2 DPI' -}}
{{ section.settings.image | image_url: width: 2400 | image_tag:
     widths: '600,1200,1800,2400', sizes: '(max-width: 767.98px) 100vw, 1200px',
     loading: 'lazy', width: 1200, height: 675 }}
```

取值步骤：

1. 量出该图在**当前断点下容器的实际显示宽度**（不是设计稿画板宽）；
2. × 高 DPI 倍率（≥ 2×）；
3. 结果作为 `image_url: width:`；或直接用 `master` / 响应式 `srcset` 覆盖各档；
4. 另外给 `<img>` 标签本身的 `width` / `height` 属性填**布局尺寸**（防 CLS，见 §2）。

`width:` 的作用**只有两个**：防 CLS、适配容器。它**不是**"限制清晰度"的旋钮。

---

## 2. 防 CLS 的 width / height

**这是两件事，不要混为一谈：**

| 写法 | 管什么 | 谁在查 |
|---|---|---|
| `image_url: width: 2400` | **取图分辨率**（资源尺寸 / 清晰度） | 本文 §1；Theme Check 不查这一项 |
| `<img width="1200" height="675">` | **布局占位比例**（防 CLS） | Theme Check **`ImgWidthAndHeight`** |

- `image_url` **必须带 `width:`** —— 这是 PLAUD 主题的取图规则（`handoff-schema.md` §8.3），要取**大**值。
- `<img>` 必须同时有 `width` 和 `height` 属性，值为**布局尺寸**（只能是数字，见 `liquid-schema-format.md` §6），按实际布局取值。
- 容器可用 `.aspect-*` 工具类（`aspect-1-1` / `-7-10` / `-9-7` / `-16-9`）预留比例。

---

## 3. 懒加载与 Swiper effect 不兼容

| effect | 懒加载 | 处理 |
|---|---|---|
| `cards` | ❌ 不兼容 `data-src` lazy | **全量渲染**或禁用 lazy |
| `cube` | ❌ 同上 | 同上 |
| 其它（`slide` / `fade`） | ✅ 可用 | — |

典型症状：**Swiper cards / cube 的图不加载**（停在 `data-src`）。根因：`data-src` 与 effect 不兼容。修复：全量渲染或禁用 lazy。

完整 Swiper 约束表见 `javascript-swiper.md` §5。

### 3.1 WW `image` block 的多断点懒加载 bug

走 `ww_mc_multi_breakpoint` 的 responsive-image 有 bug：**图停在 `data-src`、永不提升、容器也不预留高度**，滚进视口也不加载。

- **单图改用 `image_with_text_below`**（只填图，标题/描述留空），走标准 aspect-ratio 路径，正常加载。
- ⚠️ **仅在「从 legacy 重建」或已确认该图实际加载失败时才转**；既有能正常渲染的 WW `image` block **不主动转换**（模板只读 + 不修没坏的东西）。

---

## 4. 图片加载的验证方法

配置"看着对" ≠ 渲染对。必须浏览器实测：

| 检查 | 方法 |
|---|---|
| 图是否真加载 | `naturalWidth > 0` |
| 是否还停在 data-src | 检查 `<img>` 的 `src` 是否已提升 |
| 清晰度是否够 | 对比 `naturalWidth` 与 `getBoundingClientRect().width × devicePixelRatio` |
| 是否有 CLS | 加载前后布局位移 |

无法预览时标 `Blocked`，**不得猜"应该没问题"**（`handoff-schema.md` §7）。

---

## 5. `<source media>` 断点也用 767.98

`<video>` / `<picture>` 里 `<source media="...">` 选择移动 / 桌面源的断点，要和 CSS 一样用 **`max-width: 767.98px`**（不是 768），避免在 768px 整边界上视频源与桌面布局错位。

```html
<source media="(max-width: 767.98px)" srcset="…mobile…">
<source media="(min-width: 768px)"    srcset="…desktop…">
```

改到旧代码时留意残留的整数断点（`767px` → `767.98px`）——**仅限本次授权影响范围内**顺手统一，范围外登记「待评估」。

完整断点表见 `responsive-and-spacing.md` §1。

---

## 6. 视频

| 项 | 规定 |
|---|---|
| 比例 | **优先 16:9**（`.aspect-16-9`） |
| 圆角 | `radius-lg`（10px） |
| 源切换 | `<source media>` 用 767.98（§5） |
| 海报图 | 同样受 §1 清晰度红线约束 |
| 播放器 | 走 `DeferredMedia` 基类（见 `javascript-swiper.md` §1） |

产品图片始终保持原始比例，**禁止强制裁剪**。

> ⚠️ Slideshow 开启 `new_banner_enbale` 后，背景图从"按比例完整显示"变成"按固定高裁切填充"（`object-fit: cover`），可能裁掉图片边缘——**预览必看**。

---

## 7. 素材不得写死进 `assets/`

**新增 section 不得**把内容图片、视频、icon 写死为 `{{ 'xxx' | asset_url }}` 或依赖 `assets/*.png|jpg|svg|mp4`。

| 素材性质 | 正确来源 |
|---|---|
| 运营可配置素材（banner 图、卡片图、视频、可换的 icon） | schema 字段：`image_picker` / `video` / `video_url` / `url` |
| 商品 / 内容数据 | product / metaobject / collection 数据源 |
| 全站固定的技术资源（CSS / JS / 系统图标） | `assets/` |

`assets/` **只放 CSS/JS 与确认全站固定的技术资源**。例外须需求明确并**经用户确认**。

QA 判定（`QA-B` 素材来源项）：grep 新增 section 里的 `asset_url` 引用，凡指向 `.png` / `.jpg` / `.jpeg` / `.webp` / `.svg` / `.mp4` 且属内容素材的，即 `Failed`。

---

## 8. 图片相关的性能高频项

| 项 | 做法 |
|---|---|
| CLS | `<img width height>` + `.aspect-*` 容器 |
| 懒加载 | `loading="lazy"`（首屏图除外，首屏用 `enable_high_priority` / `fetchpriority`） |
| 循环内不输出 `stylesheet_tag` | snippet 在循环里被 render 时，样式标签会被重复输出 N 次——提到循环外 |
| DOMParser | 复用实例，不在循环里 new |
| Parser-blocking script | 见 `liquid-schema-format.md` §7（Theme Check `ParserBlockingScript`） |
