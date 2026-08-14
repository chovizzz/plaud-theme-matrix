# §4.1 Utility 速查 + 源文件 vs 实际加载文件对照

> **配方前提**：本文件与所有 `pitfalls-*.md` 一样，描述的是「**已获授权时怎么做**」，不是授权本身。
> 与 `hard-rules.md` 冲突时以 `hard-rules.md` 为准。完整总纲见 SKILL.md「§4.x 配方的适用前提」。

> **数值不在本文件。** utility 类对应的字号 / 色值 / 间距 px / 圆角 px / 断点，定义在
> `plaud-theme-shared/references/typography.md`、`colors-and-schemes.md`、`responsive-and-spacing.md`。
> 本文件只写**有哪些类、类在哪个 bundle、怎么验证它真的生效**。

---

## 1. 源文件 vs 实际加载文件（验证 utility 是否真在生效 bundle 里时查这张表，别再重搜）

| 类 | 源 | plaud-us 实际加载的 snippet（全局，每页） |
|---|---|---|
| spec tokens + utilities（`.fs-*` / `.text-*` / `.pad-*` / `.gap-sp-*` / `.radius-*` / `.btn-primary-*` / `.bg-card` / `.bg-soft` 等） | `design-tokens.scss` + `design-utilities.scss` | **`snippets/design-system.liquid`**（`layout/theme.liquid` 里 `{% render 'design-system' %}`，**早于 base-style 以赢 cascade**） |
| `text-{x}!` / `md:text-{x}!` important 物理对齐类（`cs-section-header` 的 `text_align_pc/mb` 就靠它生效） | — | **`snippets/base-style.liquid`**（全局） |
| legacy `.text-left/center/right` + 响应式 `.text-md-*` | — | **`snippets/critical-style.liquid`** |

**验证某个类是否生效**：grep 上表对应的 snippet。
🔴 **`assets/critical.css` 已在 `theme.liquid` 注释禁用，grep 它无意义。**

`design-system.liquid` / `sectionsTT.min.css` / `base_more.css` 都是 **build 产物**，勿手改（见 `pitfalls-shared-scope.md` §4.20）。

🔴 **`shopify-common/src/base.css` 仅用于 Tailwind preflight + theme legacy 兼容，不再放 spec 工具类。**
别去那里找 spec utility，更**不得**把新的 UX Spec utility 写进它 —— 新 utility 一律加到 `design-utilities.scss`（§4.5）。

---

## 2. Utility 清单

### 2.1 字号

`.fs-large-title-1/-2`、`.fs-title-1/-2/-3`、`.fs-headline`、`.fs-body-lg/-md/-sm`

- 双档（PC / MB）行为与具体 px 见 shared `typography.md`
- 🔴 `fs-*` **自带 line-height**，别再写 `line-height` —— 见 `pitfalls-css.md` §4.10

### 2.2 文字色（v1.3 重组）

`.text-primary` / `-secondary` / `-disabled` / `-inverse-primary` / `-inverse-secondary` / `-purple` / `-cyan` / `-green`

- 🪦 **`.text-tertiary` 已废止**（2026-08-11 基线的 label 色阶无此档，见 shared `colors-and-schemes.md` §2.1）。**新代码禁止使用**，QA 对新增使用判 `Failed`
- 存量 `.text-tertiary` **不得盲删**（划线价 / 脚注 / 免责小字靠它，删了会回退继承父色）：走墓碑迁移流程，过渡期 alias 指向 secondary
- ⚠️ 更早的 `.text-quaternary` / `--color-label-quaternary` 也已删除；遇到残留引用一并迁到 **secondary**（不要再迁到 tertiary，那一档也没了）
- 🔴 三个彩色 label（`-purple` / `-cyan` / `-green`）**背景配对受限**，用前必读 shared `a11y.md` §5.1 —— cyan / green 压浅底判 `Failed`

### 2.3 背景色（spec §2.4）

`.bg-page` / `.bg-card` / `.bg-soft`

- **不含 `.bg-white`** —— 那是 Tailwind 自带的，且它仍跟随配色方案（见 `pitfalls-shared-scope.md` §4.6）

### 2.4 间距（均 = `--space-N`，N = 1/2/4/6/8/10/14）

- padding：纵向 `.pad-y-*` · 横向 `.pad-x-*` · 全向 `.pad-*`
- margin：`.mar-t-*` / `.mar-b-*` / `.mar-y-*`
- 间隙：`.gap-sp-*`

⚠️ `.pad-x-*` 与 margin 族 2026-06-11 才补齐（之前缺，曾被迫退回 legacy `mt-*` / `px-*`）。
legacy `.mt-24` 是主题 bug（**实为 margin-bottom**），**勿用**。缺 spec 值对应 utility 时补到 `design-utilities.scss` 再 build（见 `pitfalls-shared-scope.md` §4.5）。

🔴 **legacy `mt-custom` / `mb-custom` / `pb-custom` 单位不一致、勿复用**（2026-06-30 踩坑）：

- `mt-custom` 用 `var(--space-top)` —— 要**带单位**的长度
- `mb-custom` / `pb-custom` 用 `calc(var(--space-bottom) * 1px)` —— 要**无单位**数字
- 给 `--space-bottom` 传 `var(--space-N)`（带单位）→ 算成 `calc(16px * 1px)` → **非法、静默归零**（间距 / 内距整个消失，**极难发现**）
- **迁移时优先改用 `.mar-t-*` / `.mar-b-*` / `.pad-b-*` 工具类**；万不得已要复用时，`--space-bottom` 只能填**裸数字**

### 2.5 网格

🔴 **`grid-cols` 不自带 `gap`**（2026-06-30 踩坑）：`.grid.grid-cols` 只设列模板 + `--gap` 变量（用于把列宽算窄、预留间隙），**本身不写 `gap` 属性**。

- 做 `.grid-cols` 网格列间距**必须再叠 `.gap`**（消费 `--col-gap` / `--col-gap-desktop`，桌面在 992 切换）
- **不要叠 `.gap-sp-*`** —— 它直接写 `gap`，会与列宽 calc 冲突（详见 `pitfalls-css.md` §4.16）
- 需要 spec 间距值时用内联 `--col-gap: var(--space-N)`
- 普通 `display:grid`（**非** `.grid-cols`）才可直接挂 `.gap-sp-*`

### 2.6 圆角

`.radius-base` / `-lg` / `-xl` / `-full`

### 2.7 分隔线（§2.5，2026-06-30 新增）

`.separator-t/-b/-y`（default）· `.separator-t/-b/-y-strong`（emphasized） —— 1px 实线 border。

- 消费 `--color-separator-default` / `-emphasized`，和 `.text-*` / `.bg-*` 一样，在 `.use-color-scheme` 下重绑到方案 separator
- 🔴 **别为了"跟方案"改用裸 `var(--color-separator)`** —— 那是方案专属变量，出了方案会塌成 `currentColor`（= 文字色），且绕过 opt-in、成为系统特例
- 要让某段 spec 色**整体跟方案**，正解是给该 section 加 `use-color-scheme`（scheme 常开的模块直接常开，约定 #2 例外），**而非单独特殊化分隔线**
- 命名避开 Tailwind `.border-b`（仅宽度）与 legacy `.border-bottom`（**死类**，仅 `.border-0.border-bottom` 有规则，且用的是非 spec 色）

### 2.8 长宽比

`.aspect-1-1` / `-7-10` / `-9-7` / `-16-9`

### 2.9 按钮

- `.btn-primary-lg/-md/-sm` —— **纯尺寸类**
- `.btn-secondary-outline` —— 描边次级（SKILL / vendor 里的 `.btn-outline` 是同一物）
- **（v1.3）** 白色档 `.btn-white`，**叠 `.btn-primary-*` 取尺寸**；色值见 shared `colors-and-schemes.md`
- 尺寸用法：**LG 只用 Banner、其它 MD、特殊才 SM**（见 `spec-value-rules.md` §1）

⚠️ `.btn-primary-*` 是**纯尺寸类**（只设 padding / font-size / font-weight，**不设颜色 / 背景 / 边框**）。
所以可直接**叠加**在 `.btn-outline`、`.btn-white` 等其它按钮上对齐 spec 尺寸，而**保留原按钮外观**——**无需改全局按钮类，也不必新建 size-only utility**。
基础按钮样式来自 `:where(.btn-primary, .btn-outline, …)`（零特异性），任何单类工具都能覆盖其 padding / font / weight。

### 2.10 配色方案 opt-in 包装

`.use-color-scheme` —— 与 `.color-{scheme-id}` **同元素**一起加，激活 spec → scheme token rebind。

### 2.11 富文本容器

`.richtext-container` —— critical 现成工具类，让后代（`sub` / `sup` 除外）`font-size / color / margin: inherit`。
详见 `pitfalls-css.md` §4.10。

---

## 3. 容器宽度 token（spec §7，定义在 `design-tokens.scss`）

`--container-max-{xxl, xl, lg-wide, lg, md, sm, xs}` —— **7 阶**。
各阶的具体 px 见 shared `responsive-and-spacing.md`，本文件不复制。
