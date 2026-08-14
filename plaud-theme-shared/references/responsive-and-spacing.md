# Responsive & Spacing — 断点 / 间距 / 容器宽度

**何时读我**：需要 CSS 断点判定值、`--space-*` 阶梯、`.pad-*` / `.mar-*` / `.gap-sp-*` 工具类、容器最大宽度、section 上下间距，或排查"间距莫名消失 / 网格列距错乱"时。

> 本文是矩阵内断点与间距数值的**唯一事实源**。其它 skill 不得复制数值，只得引用本文件。
> 凡与 vendor 对外版旧表冲突处，**一律以 v1.3 为准**（本文已按 v1.3 落实，并标注被废弃的旧值）。
> 🔴 本文记录的是**规范值**；目标仓库 `snippets/design-system.liquid` 的实际编译值可能落后，**动手前自行核对**——见 **`repo-drift.md`**（`.container` 内边距已知会漂移）。

---

## 1. CSS 判定断点（唯一判定值）

| 边界 | max-width 侧 | min-width 侧 |
|---|---|---|
| Mobile / Tablet | `767.98px` | `768px` |
| Tablet / Laptop | `1279.98px` | `1280px` |
| Laptop / Desktop | `1599.98px` | `1600px` |

- **精度 `.98` 是硬要求**（spec §7）。写 `767px` / `768px` 整数会在整边界上错位。
- header / nav 一律 `1280 / 1279.98`，**不得留 `1024` / `1025` / `768`**。
- 改到旧代码时留意残留整数断点，顺手统一——**仅限本次授权影响范围内**；范围外登记「待评估」，勿扩散。
- `<source media>`（`<video>` / `<picture>` 选移动/桌面源）**也用 `max-width: 767.98px`**，详见 `media-quality.md` §5。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 |
|---|---|
| 各模块混用 `767` / `768` / `767.98` | 统一 **`767.98`**（min-width 侧仍 768） |
| header/nav 用 `1024` / `1025` | 统一 **`1279.98` / `1280`** |

### 1.1 组件断点特例（⚠️ 勿泛化到全局）

以下是**特定组件已确认的例外**，只在该组件内成立，不得当作全站判定值：

| 组件 | 特例断点 | 原因 |
|---|---|---|
| 区头 `cs-section-header` / 标题样式表 | **992** | 区头 PC/MB 分档按 992（见 `typography.md` §5） |
| `.container` 宽度阶梯 / `.gap` 桌面切换 | **992** | 容器与列间隙在 992 切换 |
| slide-section 控件显隐 | **768 / 1025** | 对齐 slide-section 自身的 perView 断点 |
| WW `fs-custom` | `≥768` 消费 `--font-size`（PC）、`≤767.98` 消费 `--font-size-m` | `--font-size-pad`（平板）是死值——**平板恒渲染 PC 值** |

---

## 2. 设计参考画板断点（⚠️ 非 CSS 判定值）

下表是**设计稿画板断点**，用于读 Figma、对设计意图，**不是 media query 边界**：

| 断点名 | 设备场景 | 最小宽度 |
|---|---|---|
| XS | 手机横屏 | 390px |
| S | 平板竖屏 | 768px |
| M | 平板横屏 / 小桌面 | 1366px |
| L | MacBook Air / 标准桌面 | 1440px |
| B | 宽屏桌面 | 1920px |
| 2K | 超高清 | 2560px |

**不得把 390 / 1366 / 1440 / 1920 / 2560 写进 CSS media query。** CSS 一律用 §1 的三个 `.98` 值。

**视觉回归验证断点**（QA 用）：`PC / 1599 / 1279 / 767 / 375`。

---

## 3. 间距阶梯 `--space-N`

| token | 值 |
|---|---|
| `--space-1` | 4px |
| `--space-2` | 8px |
| `--space-4` | 16px |
| `--space-6` | 24px |
| `--space-8` | 32px |
| `--space-10` | 40px |
| `--space-14` | 56px |

基础网格 = 4px。**只用阶梯上的档，不在档之间插值。**

### 3.1 间距工具类

| 族 | 类名 | 说明 |
|---|---|---|
| padding 纵向 | `.pad-y-*` | N ∈ 1/2/4/6/8/10/14 |
| padding 横向 | `.pad-x-*` | 同上 |
| padding 全向 | `.pad-*` | 同上 |
| margin | `.mar-t-*` / `.mar-b-*` / `.mar-y-*` | 同上 |
| 间隙 | `.gap-sp-*` | 同上（⚠️ 见 §7 网格陷阱） |

`.pad-x-*` 与 margin 族是后补齐的（之前缺，曾被迫退回 legacy `mt-*` / `px-*`）。**缺 spec 值对应的 utility 时，补到 `design-utilities.scss` 再 build，不要内联**：

1. 扫冲突：新类名不撞 Tailwind（`.p-*`）、旧主题（`.py-*` / `.px-*`）、HTML 裸类引用；
2. 加类 → build → 校验已进 critical（`design-system.liquid`）；
3. 命名避开既有命名空间（`.pad-*` / `.gap-sp-*` 前缀即为此）。

**legacy `.mt-24` 是主题 bug**（实为 `margin-bottom`），勿用。

### 3.2 圆角

| token | 值 | 等价 legacy 类 | 工具类 |
|---|---|---|---|
| `radius-base` | 5px | `rounded-5` | `.radius-base` |
| `radius-lg` | 10px | `rounded-10` | `.radius-lg` |
| `radius-xl` | 15px | — | `.radius-xl` |
| — | 全圆 | — | `.radius-full` |

**`rounded-5` / `rounded-10` 与 `radius-base` / `radius-lg` 是同一物，两套命名等价**（v1.3 优先级⑤）。元素默认弧角：按钮 5px；输入框 / 卡片 / 图片横幅 / 导航栏 / 模态框 10px。

规则：**主规范档位统一为 5 或 5 的倍数，默认 5px**。以下是 spec 明确列出的**组件私有例外**（不入主规范，不得泛化）：

| 例外值 | 用在哪 | 出处 |
|---|---|---|
| `2px` | 倒计时数字格 | spec §4 + §6.4 |
| `1px` | 极细分隔线装饰 | spec §4 |
| `50%` | 用户头像（圆形） | spec §6.3 |

除上表外出现的圆角值一律判违规。反过来，**QA 不得**因为看到 `2px` / `1px` / `50%` 就判 `Failed`——先核对是不是这三处。

### 3.3 按钮尺寸档（padding 走间距阶梯）

| 档 | padding（y/x） | 字号 PC | 字号 MB（≤767.98） | 字重 | 用法 |
|---|---|---|---|---|---|
| `.btn-primary-lg` | `--space-2` / `--space-6` = **8 / 24** | **18px** | **16px** | 400 | **只用在 Banner** |
| `.btn-primary-md` | `--space-2` / `--space-6` = **8 / 24** | **16px** | 16px（无 MB 覆盖） | 400 | **默认档，其它一律用它** |
| `.btn-primary-sm` | `--btn-padding-sm-y` / `-x` = **5 / 15** | **12px** | 12px（无 MB 覆盖） | 400 | 仅特殊说明才用 |
| `.btn-secondary-outline` | 8 / 24 | 16px | **14px** | 400 | 描边次级；`line-height: 1.2` |

padding 走 `--space-*` 阶梯（LG/MD = space-2/space-6），与 spec §3.2 的 8/24、5/15 吻合。**只有 LG 与 secondary-outline 有移动端字号覆盖**，MD / SM 两端同值。

### 3.3.1 按钮高度是**目标最小高度**，不是固定高度

2026-08-11 基线给出了每档的高度值：

| 档 | PC 高 | MB 高 | 圆角 |
|---|---|---|---|
| `.btn-primary-lg` | 40px | 40px | 5px |
| `.btn-primary-md` | 35px | 35px | 5px |
| `.btn-primary-sm` | 25px | 25px | 5px |
| `.btn-secondary-outline` | 35px | **32px** | 5px |

> 🔴 **这组值与全路径红线②「禁止无理由写死组件 width / height」表面冲突，落地口径如下，不得直接写 `height`：**
>
> | 写法 | 判定 |
> |---|---|
> | `height: 40px` | ❌ 违规。长语言（德/法/西/俄比英文长 30–50%）换行时文字会溢出或被裁 |
> | `min-block-size: 40px` + `height: auto` + 横向 padding 撑开 | ✅ 正确。单行时**自然落在** 40px，换行时允许变高 |
> | 固定 `width` | ❌ 任何情况下都禁止，本次基线未放开 |
>
> 也就是说：**高度是「单行状态下的结果值」，不是「强制值」**。QA 的 `FixedDimensionCheck` 按此判——看到 `min-block-size` 落在四档上判 `Passed`，看到写死 `height` 判 `Failed`。
>
> 校验方式：把按钮文案换成德语长文案，高度应当增加而不是文字溢出（与 `LocalizationCheck` 同一组用例）。

`.btn-primary-*` 是**纯尺寸类**（只设 padding / font-size / font-weight，**不设颜色/背景/边框**），因此可直接**叠加**在 `.btn-outline` / `.btn-white` 上取 spec 尺寸而保留原外观——不必改全局按钮类，也不必新建 size-only utility。基础按钮样式来自 `:where(.btn-primary, .btn-outline, …)`（零特异性），任何单类工具都能覆盖其 padding / font / weight。

按钮**禁止固定宽高**（德/法/西/俄语可能比英文长 30–50%）：只允许 `min-width` / `min-height`，由 padding 撑开；同组对齐用 flex，不得以固定宽高强制对齐。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 |
|---|---|
| 按钮档"就近取档" | **LG 只 Banner / 其它 MD / 特殊 SM** |
| 只有 `.btn-primary` / `.btn-outline` 两档 | 新增 **`.btn-white`**（背景 `#FFFFFF` / 文字 `#000000` / Hover `#EEEEEE`），叠 `.btn-primary-*` 取尺寸 |

> `.btn-secondary-outline` 与 vendor / SKILL 里的 `.btn-outline` 是**同一物**，只是命名空间不同。

---

## 4. 容器宽度

### 4.1 spec token 阶梯（7 阶，唯一现行值）

`--container-max-{xxl, xl, lg-wide, lg, md, sm, xs}` = **1600 / 1440 / 1280 / 1140 / 960 / 720 / 540** px

**被 v1.3 覆盖的旧值**——vendor §1 的历史容器宽度表（勿照抄）：

| 屏幕宽度 | 旧模块最大宽度（**已废**） |
|---|---|
| ≥ 1920 | 1600px |
| 1600 ≤ w < 1920 | ~~1480px~~ |
| 1280 ≤ w < 1600 | ~~1200px~~ |
| 992 ≤ w < 1280 | 960px |
| 768 ≤ w < 992 | 720px |
| 576 ≤ w < 768 | 540px |
| < 576 | 100% |

即 **1480 / 1200 是旧值，现为 1440 / 1280**（v1.3 优先级④）。spec-compliant 的新工作一律用 `--container-max-*` token 阶梯。

### 4.1.1 网格全表（spec §7，2026-08-11 补全内边距与内容宽度）

v0.1.0 只记了 container 最大宽度这一列。完整表：

| 断点 | 视口范围 | container 最大宽 | 内边距（每侧） | 内容宽度 |
|---|---|---|---|---|
| XXL | ≥ 1600px | 1600px | 160px | 1280px |
| XL | 1440–1599px | 1440px | 160px | 1120px |
| LG-Wide | 1280–1439px | 1280px | 80px | 1120px |
| LG | 1200–1279px | 1140px | 40px | 1060px |
| MD | 992–1199px | 960px | 24px | 912px |
| SM | 768–991px | 720px | 24px | 672px |
| XS | 576–767px | 540px | 24px | 492px |
| Mobile | < 576px | 100% | 24px | 视口宽 − 48px |

移动端统一以 **390px** 为基准（iPhone 14/15 标准宽度）。导航 nav 全宽，内容区加 24px 横向边距。

> 🔴 **这张表的 576 / 992 / 1200 / 1440 / 1600 是「容器网格档位」，不是「全局行为断点」。** 两套断点体系必须分开，不得混用：
>
> | 体系 | 值 | 用途 |
> |---|---|---|
> | **全局行为判定断点**（§1） | `767.98 / 1279.98 / 1599.98` | media query 边界、组件 PC/MB 分档、`<source media>` |
> | **容器网格档位**（本表） | `576 / 768 / 992 / 1200 / 1280 / 1440 / 1600` | `.container` 的最大宽 / 内边距阶梯 |
> | **设计画板断点**（§2） | `390 / 768 / 1366 / 1440 / 1920 / 2560` | 读 Figma 用，**永不进 CSS** |
>
> v0.1.0 的表述「CSS 判定断点只有三个 `.98` 值」在**行为判定**层面依然成立，但不能再宣称"全站只有三档"——容器阶梯本来就是 8 档，只是它管的是宽度与内距，不是显隐与布局切换。写 media query 前先想清楚你在改哪一层。

### 4.2 `.container` 使用规则

- 除少数特殊模块（`Header` / `Slideshow` / `Footer` 等）外，**所有新增模块的内容容器统一用类名 `container`**，保证各模块左右留白对齐一致。
- 部分通用模块（Divider / Custom HTML / Custom Liquid / Featured product）保留 section width 选择，适配多种情况。
- **`.container` 左右内边距（XS / Mobile 断点）= 24px**，其余各档见 §4.1.1 全表（XXL/XL 160、LG-Wide 80、LG 40、MD 及以下 24）。

**被 v1.3 覆盖的旧值**：

| 旧值（已废） | 现值 |
|---|---|
| `.container` XS/Mobile 左右内边距 **15px** | **24px**（2026-06-15 DTC-399 落实；影响全站所有用统一容器的模块，小屏与手机端内容区收窄） |

> 🔴 **核对提醒**：实测中出现过编译产物**仍是 15px**（≥768 才 24px）的仓库，即该仓库的 build 早于 DTC-399。
> **规范值仍是 24px** —— 不得因为看到 15px 就以为规范是 15px。动这个值前**必须先核对目标仓库的 `snippets/design-system.liquid`**。已知案例与核对命令见 **`repo-drift.md`** §2、§3.1。

---

## 5. Section 上下间距 —— 走 schema，CSS 不硬编码

所有新增模块的上下间距**统一通过 schema 控制**，**不得在 CSS 中为 section 硬编码 `margin-top` / `margin-bottom`**：

```json
{ "type": "header", "content": "+ Section Space" },
{
  "type": "select", "id": "section_top_pc", "label": "Section Top",
  "default": "section-top-pc-b",
  "options": [
    { "label": "none",   "value": "section-top-pc-a" },
    { "label": "normal", "value": "section-top-pc-b" }
  ]
},
{
  "type": "select", "id": "section_bottom_pc", "label": "Section Bottom",
  "default": "section-bottom-pc-b",
  "options": [
    { "label": "none",   "value": "section-bottom-pc-a" },
    { "label": "normal", "value": "section-bottom-pc-b" }
  ]
}
```

Liquid：

```liquid
<div class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
```

| 值 | 含义 |
|---|---|
| `section-top-pc-b` / `section-bottom-pc-b` | 有间距（normal），**默认** |
| `section-top-pc-a` / `section-bottom-pc-a` | 无间距（none） |

- 吸顶栏、面包屑等结构性模块把 `default` 改为 `"section-top-pc-a"`。
- 商品位作为页面首模块时上间距默认 none（如 Featured product）。

### 5.1 各断点 normal 间距值（由全局 CSS 统一定义，运营可在"全局配置"调整）

| 屏幕宽度 | normal 间距 |
|---|---|
| ≥ 1600（Desktop） | 180px |
| 1280 ≤ w < 1600（Laptop） | 160px |
| 768 ≤ w < 1280（Pad） | 120px |
| < 768（Mobile） | 100px |

> 模块**之间**的间距走 `--section-space`；模块**内部**的间距走 `--space-N` 阶梯。别混。

`anchor_id` 要放在 `.container` **同层**（跳转锚点落在内容上沿，不是 wrapper margin 之上）。

---

## 6. 响应式策略

### 6.1 Mobile-first

- 核心内容与主操作在 XS 断点下必须完整可用。
- grid 从 1 列起，逐级加列。
- 字号 / 间距跟随断点**按表格值阶梯变化，不在组件内插值**。
- section 背景色块保持全宽，**任何断点下不得出现横向滚动条**。
- 产品图片始终保持原始比例，禁止强制裁剪。

### 6.2 三层响应式变量策略（`-m` / `-pc`）

新建 `sa-*` section 与迁移模块统一用三层：

```
端变量  --sa-xxx-m / --sa-xxx-pc     ← 每端各定义一份字面值
   ↓
运行变量 --sa-xxx                     ← 断点内只改这一层的映射
   ↓
属性     padding: var(--sa-xxx)       ← 属性只读运行变量
```

- **断点内只改变量映射，不写死 px**。
- 响应式值走 CSS 自定义属性，**不写 inline style**（inline style 会覆盖媒体查询，是"移动端样式不生效"的头号根因）。
- 组件宽高不得直接写死在 CSS / inline style / Liquid 输出里；用内容、比例、容器和断点变量驱动尺寸（红线正文见 `handoff-schema.md` §8.2）。

### 6.3 Figma 值不在 spec 阶梯时的取值

| 情形 | 处理 |
|---|---|
| 有近邻 token、**明显**更近某档 | **就近 snap**（默认口径）。实例：22→space-6(24)、15→space-4(16)、38→space-10(40)。日志标 ±px delta |
| **等距两可**（20 在 16/24 之间、12 在 8/16 之间、28 在 24/32 之间、48 在 40/56 之间） | 🔴 **停下问用户选哪档，不得擅自 snap** |
| Figma 明确、无近邻 token、视觉重要 | 可用字面 px 贴 Figma，但**须先与用户确认再执行**，不擅自硬编码 |
| 为适配固定尺寸算出的值（如固定高 40、字 14 → padding `(40-14)/2 = 13px`） | 用计算值；**前提是该固定尺寸本身已作为例外经确认**，改完主动提醒用户复核 |

**跨端 token 冲突**（Figma 给 PC/MB = 16/14、24/18 这类"PC 降一档"，而 token 曲线是 body-lg 16/16、body-md 14/14、title-3 24/20）：

- 默认**取 M 端命中的档**（M 值优先匹配 Figma），但**选哪档须先与用户确认**，不擅自定 token；
- PC 端接受 ±delta；PC 偏差不可接受时加 PC 专属覆盖（媒体查询）；
- 两端都要严格贴 Figma 且无单一 token 同时命中 → PC 用 token、**M 端保留 `rem` 覆盖**贴 Figma；
- 日志标 M ✓ 与 PC 的 ±delta。

---

## 7. 🔴 三个高频陷阱（必查）

### 7.1 `.grid grid-cols` 禁叠 `gap-sp-*`

主题的 `.grid.grid-cols` 用 `--gap: var(--col-gap-desktop, var(--col-gap))` **参与列宽计算**——它只设列模板 + `--gap` 变量（用于把列宽算窄预留间隙），**本身不写 `gap` 属性**。

| 做法 | 结果 |
|---|---|
| ❌ `.grid grid-cols` + `.gap-sp-6` | `gap-sp-*` 直接写 `gap`，与列宽 calc **冲突**，列宽/列距错乱 |
| ✅ `.grid grid-cols` + `.gap` 类 | 消费 `--col-gap` / `--col-gap-desktop`（桌面在 992 切换） |
| ✅ 需要 spec 间距值时 | **内联 `--col-gap: var(--space-N)`** 喂给网格（与仓内其它 `--col-gap: var(--space-4)` 写法一致） |
| ✅ 普通 `display: grid`（非 `.grid-cols`） | 无此约束，可直接挂 `.gap-sp-*` |

⚠️ `.grid-cols` **不自带 gap**——只写 `grid-cols` 不写 `.gap` 类，列间距会是 0。

### 7.2 `my-0` 会盖掉 `mar-b-*`

`my-0`（`margin-block: 0`）把上下 margin 都归 0，与 `mar-b-*` **同特异性、后加载者胜** → 常把想要的下间距吃掉。

要"上 0 + 保留下间距" → 用 **`mt-0` + `mar-b-*`**（`mt-0` 只设上）。

### 7.3 legacy `mt-custom` / `mb-custom` / `pb-custom` 单位不一致，会**静默归零**

| 类 | 消费方式 | 需要的值 |
|---|---|---|
| `mt-custom` | `var(--space-top)` | **带单位**长度（如 `16px`） |
| `mb-custom` / `pb-custom` | `calc(var(--space-bottom) * 1px)` | **无单位**数字（如 `16`） |

给 `--space-bottom` 传 `var(--space-4)`（= `16px`）→ 算成 `calc(16px * 1px)` → **非法、静默归零**，间距/内距整个消失，极难发现。

**处理**：优先改用 `.mar-t-*` / `.mar-b-*` / `.pad-b-*` 工具类。万不得已要复用 legacy 类时，`--space-bottom` **只能填裸数字**（如 `16`）。

### 7.4 附加：gap-flex 父级里的空 wrapper 吃 gap

父级用 `flex flex-col gap-sp-*` 统一子块间距时，**空的 wrapper `<div>` 仍是 flex item、照样吃 gap** → 撑出幽灵空白。

可选区块（可能整段为空）要包成"有内容才渲染"：

```liquid
{%- capture x -%}…{%- endcapture -%}
{%- assign x = x | strip -%}
{%- if x != blank -%}<div>{{ x }}</div>{%- endif -%}
```

---

## 8. utility class vs 组件 CSS（加载分层）

| 类型 | 加载层 | 间距 / box 样式处理 |
|---|---|---|
| **Universal**（每页都用）：`cs-section-header` / `section-disclaimer` / `.container` | `design-utilities.scss` → critical inline | 组件 CSS 直接消费 token |
| **Section-scoped**（部分页面、async）：FAQ / accordion / pricing card 等 | `shopify-common/sections-*` | **utility class 挂 HTML** |

理由：section-scoped 模块的结构 CSS 走 async，样式若也写在 async CSS 里会首次 paint FOUC；utility class 来自 critical bundle，HTML 解析瞬间生效。

⚠️ **不止字号 / 颜色**：首屏可见的 **box 样式（内边距 / 背景 / 圆角 / 间隙）** 放进 async SCSS 同样 FOUC，也应走 critical 工具类挂 HTML（`.pad-4` / `.bg-soft` / `.radius-base` / `.gap-sp-6`）。

**判断某 bundle 是否 async**：看 `layout/theme.liquid`（或引用它的 section）是否用 `media="print" onload="this.media='all'"` 加载。是 = async，受此约束。非 async bundle（如用普通 `stylesheet_tag` 加载的 `main-cart.min.css`）无此顾虑，响应式 scss 可放心用。

**动态内容例外**：metaobject / 富文本渲染出的标签 markup 不可控、加不了类，只能在组件 CSS 用后代选择器消费 `var(--token)`——这是允许的例外，只把**结构可控**的元素搬到 critical 工具类即可。

### 8.1 token→class 重构必须"全实例覆盖"（高频回归源）

把某个**共享 class** 的 spec 值（字号/内距/圆角/间距）从组件 CSS 移到 HTML utility 类时，**必须先全局 grep 该 class 的所有 markup 用法逐一补类**——否则未迁移的实例（常在其它分支 / 其它 snippet）会**静默丢样式**（字号回退继承、内距归零）。

顺序：① `grep 'class="[^"]*<class-name>'` 全仓找出所有 markup 实例 → ② 剥 CSS 声明**前**确认每个实例都已挂等价 utility → ③ 剥完再回归验证。

**例外（留 token 在 CSS 是合理的）**：无对应 utility 的属性（如 `margin-inline-end` 单侧 margin），或"共享组件基类一次定义、不散落"的 padding。

---

## 9. 长宽比工具类

`.aspect-1-1` / `.aspect-7-10` / `.aspect-9-7` / `.aspect-16-9`

视频优先 **16:9**（见 `media-quality.md` §6）。这四个类正是 §10 组件尺寸表的派生。

---

## 10. 组件尺寸（spec §6.2–§6.4，2026-08-11 新增）

> 🔴 **这三张表里的 px 值不是"照抄成 CSS 固定宽高"的许可。** 每个值必须先归类，再决定写法：
>
> | 类别 | 写法 | 判定 |
> |---|---|---|
> | **设计参考** | 不进 CSS，只用于对稿 | 画板宽度（1440 / 390）属此类 |
> | **比例约束** | `aspect-ratio` / `.aspect-*` 工具类 | 卡片与视频容器属此类 |
> | **最小尺寸** | `min-block-size` / `min-inline-size` | 导航栏高度属此类 |
> | **技术固定例外** | 允许写死 `width`/`height`，须说明理由 | 图标、倒计时数字格属此类（红线②已列明的例外） |

### 10.1 导航栏（spec §6.2）

| 组件 | 宽 | 高 | 类别 | 备注 |
|---|---|---|---|---|
| Announcement Bar (PC) | 1440px | 50px | 宽=设计参考；高=**min** | 黑底白字。宽度实际由 `.container` 阶梯决定，不写死 |
| Navigation Bar (PC) | 1440px | ~64px | 宽=设计参考；高=**min** | 白底、黑 Logo + 链接。原文写「~64px」本身就是约数 |
| Navigation Bar (MB) | 390px | 46px | 宽=设计参考；高=**min** | `radius-base`（5px），含汉堡菜单 |
| Nav Icon | 24px | 24px | **技术固定例外** | 图标尺寸，红线②明确豁免 |

⚠️ 1440 / 390 是**画板宽度**（§2），写进 CSS 即违规。

### 10.2 卡片 / 图片容器（spec §6.3）

| 组件 | 宽 | 高 | 比例 | 圆角 | 类别 |
|---|---|---|---|---|---|
| 产品缩略图 | 56px | 80px | 7:10 | 5px | **比例约束**（`.aspect-7-10`） |
| 视频预览卡 | 432px | 243px | 16:9 | 10px | **比例约束**（`.aspect-16-9`） |
| 大视频卡 | 544px | 306px | 16:9 | 10px | **比例约束**（`.aspect-16-9`） |
| 玻璃浮卡（Hero） | 432px | 336px | 9:7 | 10px | **比例约束**（`.aspect-9-7`） |
| 侧边浮层卡 | 168px | 240px | 7:10 | 15px | **比例约束**（`.aspect-7-10`） |
| 用户头像 | 24px | 24px | 1:1 | **50%** | **技术固定例外**（图标尺寸 + 圆形） |

所有卡片宽高均为 **8px 的整数倍**，可直接映射网格系统；视频卡统一 16:9。
spec 备注了几处对齐历史：产品缩略图原 54×75、大视频卡原 546×317、玻璃浮卡原 433×341、侧边浮层卡原 164×229，**均已向 8px 格对齐**——遇到旧代码里的原值，按新值改，不要以为是两套设计。

> 🟢 **优先用比例，不要用固定宽高。** 这些 px 是设计稿在某个断点下的**实例值**；容器宽度随断点变化，锁死宽高会在其它断点直接崩。正确写法是 `.aspect-*` + 容器百分比宽。

### 10.3 倒计时组件（spec §6.4）

| 属性 | 值 | 类别 |
|---|---|---|
| 单格宽 × 高 | 16px × 25px | **技术固定例外**（两格并排的数字格） |
| 数字格背景 | `rgba(254,251,248,0.2)`（= `--color-white-20`） | — |
| 数字格圆角 | **2px** | 组件私有例外（§3.2） |
| 数字字号 | 20px | **组件私有值** |
| 单位标签字号 | **8px** | **组件私有值** |
| 组件总宽 | 217px | 设计参考（含四组格子与分隔符） |
| 组件总高 | 43px | 设计参考 |

> 🔴 **单位标签 8px 不在九档字阶内**（最小档是 `body-sm` 12px）。这不是遗漏，spec §1.2 原文已声明「倒计时组件内部字号属**组件私有值**，见 6.4 节」。
> 因此：倒计时内部的 20px / 8px **不得**被"就近 snap 到字阶"改成 20（headline）/ 12（body-sm）——那是改规范。同理**不得**把它当先例，给别的组件也开私有字号；组件私有值只对 spec 点名的组件成立。
