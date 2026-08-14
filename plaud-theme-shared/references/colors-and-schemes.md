# Colors & Color Schemes — 颜色 token / 配色方案

**何时读我**：需要品牌色变量、spec 文字/背景/分隔线色阶、AI 渐变、`color_scheme` 配置与 Liquid 写法、`.use-color-scheme` 重绑行为，或判断"某元素开方案后会不会变色"时。

> 本文是矩阵内颜色相关数值的**唯一事实源**。其它 skill 不得复制这里的 hex，只得引用本文件。
> 「颜色走 token / 不写死 hex」这条**红线本身**定义在 `handoff-schema.md` §8.4；本文只给该红线的可执行取值与已文档化的例外。
> 🔴 本文记录的是**规范值**；目标仓库 `snippets/design-system.liquid` 的实际编译值可能落后。变量命名与 `use-color-scheme` 重绑范围**已知会漂移**，动手前先读 **`repo-drift.md`**。

---

## 1. 品牌色 CSS 变量

组件内引用品牌色**必须用变量**，禁止直接写色值（便于全局切换）：

| 颜色 | 默认色值 | Hover 色值 | CSS 变量 |
|---|---|---|---|
| 黑色 | `#000000` | `#000000` | `--color-black` / `--hover-color-black` |
| 紫色 | `#8F53ED` | `#7B35EB` | `--color-purple` / `--hover-color-purple` |
| 蓝色 | `#00D0FF` | `#07AFD5` | `--color-blue` / `--hover-color-blue` |
| 绿色 | `#39F672` | `#30D462` | `--color-green` / `--hover-color-green` |
| 白色 | `#FFFFFF` | `#EEEEEE` | `--color-white` / `--hover-color-white` |

> 🔴 **上表的变量名有两套并存，用前必须 grep 确认目标仓库有哪一套。** 实测中出现过**只有** `--color-black` / `--color-white`、紫/青/绿全走 highlight 系的仓库；此时写 `var(--color-purple)` 会解析失败、整条声明直接作废。色值本身两套一致。

Highlight / brand 系（实测中更普遍存在）：

| 变量 | 值 | Hover 变量 | Hover 值 |
|---|---|---|---|
| `--color-highlight-purple` | `#8F53ED` | `--color-highlight-purple-hover` | `#7B35EB` |
| `--color-highlight-cyan` | `#00D0FF` | `--color-highlight-cyan-hover` | `#07AFD5` |
| `--color-highlight-green` | `#39F672` | `--color-highlight-green-hover` | `#30D462` |
| `--color-brand-dark` | `#413D3B` | `--color-brand-dark-hover` | `#635F5D` |
| `--color-brand-cyan` | `#00D0FF` | — | — |

> 插件 / 旧代码里"看着像品牌色"的裸 hex，**先查是不是 spec token**再动——如 Selleasy CTA 的 `#00D0FF` 就是 `--color-highlight-cyan`，直接 token 化即可，不必改色。

> 🔴 **白色 hover 由 `#E9E6E6` 改为 `#EEEEEE`**（2026-08-11 基线 §6.1 Hover 表）。v0.1.0 里这个值本身就自相矛盾——本表写 `#E9E6E6`、`responsive-and-spacing.md` 的 `.btn-white` 写 `#EEEEEE`。现已统一为 **`#EEEEEE`**，两处同源。遇到仓库里的 `#E9E6E6` 按 `repo-drift.md` 流程核对后再改，不要见一个改一个。

**hex 字面量大小写**：新写 spec 字符串统一**大写**（`#FFFFFF` / `#413D3B`）；老代码 hex 小写**不连动改**（用户硬规则：hex case 不动模板）。

---

## 2. Spec 语义色阶（v1.3）

### 2.1 文字色（label）

#### 现行档（2026-08-11 基线）

| token 语义 | 工具类 | hex | 说明 |
|---|---|---|---|
| label-primary | `.text-primary` | `#000000` | 主文字、标题、主要图标 |
| label-secondary | `.text-secondary` | **`#717171`** | 次级文字、副标题、未点击状态、说明文字 |
| label-disabled | `.text-disabled` | `#C7C7C7` | 禁用状态、不可点击、表单禁用项 |
| label-inverse-primary | `.text-inverse-primary` | `#FFFFFF` | 深色底主文字、深色卡片、深色 banner 主标题 |
| label-inverse-secondary | `.text-inverse-secondary` | `#ABABAB` | 深色底次级文字、深色背景说明文字 |
| **label-purple** | `.text-purple` | `#8F53ED` | 高亮紫文字；白色 / 米色背景下高亮突出 |
| **label-cyan** | `.text-cyan` | `#00D0FF` | 高亮青文字、New 角标 |
| **label-green** | `.text-green` | `#39F672` | 高亮绿文字；**深色背景**下高亮突出 |

🔴 三个彩色 label 有严格的背景配对限制（白底对比度远不达标），**用前必读 `a11y.md` §5.1 的配对表**。

#### 🪦 `label-tertiary` 已废止（墓碑）

`label-tertiary` / `.text-tertiary` / `--color-label-quaternary` **全部退出现行规范**：2026-08-11 基线的 label 色阶只有上表八档，没有 tertiary 这一层。

| 时期 | secondary | tertiary | quaternary |
|---|---|---|---|
| 更早 | `#3D3D3D` | `#7A7A7A` | 有 |
| v0.1.0（2026-06-30 重组） | `#7A7A7A` | `#A3A3A3` | 已删，并入 tertiary |
| **现行（2026-08-11）** | **`#717171`** | **已废止 → 并入 secondary** | — |

落地纪律（**不是"全仓一把删"**）：

1. **新代码禁止使用** `.text-tertiary` / `--color-label-tertiary` / `--color-label-quaternary`。QA 对**新增**使用判 `Failed`。
2. **存量不得盲删**。`.text-tertiary` 在真实主题里用于划线价、脚注、免责小字，直接删会让这些元素回退继承父色（多为纯黑），视觉与语义都出问题。动它之前必须走 `plaud-theme-impact`，按 **High** RiskTier 评估。
3. **过渡期允许一个版本的兼容 alias**：`--color-label-tertiary: var(--color-label-secondary)`，即旧类继续可用但取 secondary 的值。这是迁移脚手架，不是规范档位。

   > 🔴 **加 alias 的同时必须删掉 `.use-color-scheme` 里的 tertiary 重绑**（§5 那一行），两件事同一步做完。
   > 原因：alias 定义在 `:root`，而 `.use-color-scheme` 会在更高特异性上把 `--color-label-tertiary` 重绑到 `tertiary_text_color`。**只加 alias 不删重绑，方案一开启 alias 就失效**——元素拿到的仍是方案里那个已经没人维护的 tertiary 色，比不加 alias 更难排查。
   > 若因故必须保留该重绑，就让它也指向 secondary：`--color-label-tertiary: var(--color-label-secondary)`，两条路径同值。
4. **零引用之后**才删除 alias 与 `.text-tertiary` utility。（`.use-color-scheme` 里的 tertiary 重绑**不等到这一步**——它在第 3 步加 alias 时就必须一起删掉，见 §5 与第 3 步的红框。）
5. 历史记录（`memory-seed` 里写着 tertiary 的迁移日志）**不改写历史**，只标注「被 2026-08-11 基线 supersede，需重新评估」。

> 🟢 **顺带说明：这次改动是 A11y 的净改善，不是倒退。** 实测对比度——旧 secondary `#7A7A7A` 在白底 4.29、在暖白底 `#F2EFEB` 仅 3.74，**本来就不达标**；新值 `#717171` 白底 4.88 ✅、暖白底 4.26（仍差一点，见 `a11y.md` §5.1）。旧 tertiary `#A3A3A3` 白底只有 **2.52**，删掉它等于拿掉一个长期不合规的档位。

### 2.2 背景色（spec §2.4）

| 工具类 | 消费变量 | 值 | 说明 |
|---|---|---|---|
| — | **`--color-bg-white`** | `#FFFFFF` | **纯白页面背景色**（2026-08-11 新增 token） |
| `.bg-page` | `--color-bg-primary` | `#F2EFEB` | 暖白底页面背景 |
| **—** | **`--color-bg-dark`** | `#413D3B` | **深色底页面背景**（2026-08-11 新增 token） |
| `.bg-card` | `--color-bg-secondary` | `#F7F5F3` | 卡片、页面背景底色 |
| `.bg-soft` | `--color-bg-tertiary` | `#F7F7F7` | 白色底下的灰底区分 |

> 🔴 **`--color-bg-white` 的加入改变了 `.bg-white` 的定性。** v0.1.0 写的是「`.bg-white` 不在 spec 工具类里——那是 Tailwind 自带的」；现在 spec **有**了纯白背景 token。
> 但**这两者仍不是一回事**：Tailwind 的 `.bg-white` 写死 `#FFFFFF` 且会跟随方案背景（见 §5 残留陷阱），spec 的 `--color-bg-white` 是一个语义 token。需要"纯白页面底"时消费 token，不要因为 spec 认了白色就默认 `.bg-white` 合规了。目标仓库是否已 build 出 `--color-bg-white` / `--color-bg-dark`，**用前 grep 核对**（`repo-drift.md`）。

> ⚠️ **`.bg-card` 与 `.bg-soft` 不是同一个值**。ux-spec 文档笼统说"bg-card / bg-soft 重绑到 surface `#F7F7F7`"，但编译产物实测两者消费**不同变量**、默认色也不同（`#F7F5F3` vs `#F7F7F7`）。
> 需要两层浅色面拉开层次时，这个 2 点色差是可用的；但**不要假设两者可互换**。上表以实测为准。

- `.bg-white` **不在 spec 工具类里**——那是 Tailwind 自带的，且它会跟随方案背景（见 §5「残留陷阱」）。
- 需要"白卡片 vs 有色大底"两层时，卡片改用 `.bg-card` / `.bg-soft`（走独立 surface 色）即可拉开层次。
- **`.bg-white` 与 scheme 互斥**：card 模式（默认 bg-white）vs full-bleed scheme，二选一。

### 2.3 分隔线（spec §2.5）

| 工具类 | 颜色 | 消费变量 |
|---|---|---|
| `.separator-t` / `.separator-b` / `.separator-y` | `#EBEBEB`（default） | `--color-separator-default` |
| `.separator-t-strong` / `.separator-b-strong` / `.separator-y-strong` | `#CCCCCC`（emphasized） | `--color-separator-emphasized` |

均为 **1px 实线 border**。和 `.text-*` / `.bg-*` 一样，在 `.use-color-scheme` 下重绑到方案 separator。

> ⚠️ 这组工具类**可能尚未 build 进目标仓库**（实测中出现过不存在的情况）。用前 `grep -c '\.separator-b' <repo>/snippets/design-system.liquid` 确认；不存在就按 `responsive-and-spacing.md` §3.1 的流程补源再 build，不要内联替代。

**不要**为了"跟方案"改用裸 `var(--color-separator)`：那是方案专属变量，出了方案会塌成 `currentColor`（= 文字色），且绕过 opt-in 变成系统特例。要让某段 spec 色整体跟方案，正解是给该 section 加 `use-color-scheme`，而非单独特殊化分隔线。

**命名避坑**：不要用 Tailwind `.border-b`（仅设宽度）或 legacy `.border-bottom`（死类，只有 `.border-0.border-bottom` 组合才有规则，且用非 spec 的 `#A3A3A3`）。

**默认配色方案 border**：`#E5E5E5` → **`#EBEBEB`**（已修）。

### 2.4 角标色板（2026-08-11 新增，spec §2.6）

七种商品角标的固定配色。**这是一张封闭表，不得自造角标配色，也不得开放后台调色**（角标颜色已于 2026-06-30 锁死为规范色板，见 ux-migration 的全局已知偏差）。

| 角标 | 背景色 | 文字色 | 实测对比度 |
|---|---|---|---|
| New | `#00D0FF` | `#000000` | 11.47 ✅ |
| Hot | `#FCDEDE` | `#FF0000` | 3.17 🔴 |
| -X% off | `#FCDEDE` | `#FF0000` | 3.17 🔴 |
| Out of Stock | `#F0F0F0` | `#000000` | 18.43 ✅ |
| Pre Order | `#D7FDE3` | `#39F672` | **1.30 🔴🔴** |
| Subscription | `#8F53ED` | `#FFFFFF` | 4.54 ✅ |
| Best Value | `#39F672` | `#000000` | 14.60 ✅ |

> 🔴 **三组配对不满足 4.5:1 红线，但处理方式不同**（判定口径见 `a11y.md` §5.1）：
>
> | 配对 | 比值 | QA 怎么判 |
> |---|---|---|
> | Hot / -X% off | 3.17 | 在 allowlist 内 → 记 `Advisories`，**须带偏差批准引用**，引用为空则降级 `Failed` |
> | **Pre Order** | **1.30** | **`A11yCheck: Failed`** —— `< 3.0` 无豁免。`BlockingGaps` 写明需设计方裁决该角标配色 |
>
> 色值**按 spec 照录**（设计方给的固定资产），**不得**自行调整去凑对比度——那是改规范。判 `Failed` 指向的是**规范缺口**，不是开发的实现错误。

### 2.5 透明度叠加（2026-08-11 新增，spec §2.7）

| token | 值 | 用途 |
|---|---|---|
| `--color-white-60` | `rgba(255,255,255,0.6)` | 玻璃卡片文字层 |
| `--color-white-40` | `rgba(255,255,255,0.4)` | 浮动卡片玻璃背景 |
| `--color-white-20` | `rgba(254,251,248,0.2)` | 倒计时数字背景格 |
| `--color-bg-frosted` | `rgba(235,235,235,0.93)` | 半透明浅背景 |

⚠️ `--color-white-20` 的底色是 `254,251,248`（暖白）而**不是**纯白 `255,255,255`——照抄时别顺手改成 255。
⚠️ 半透明层上的文字对比度**取决于它压着什么**，无法静态判定。玻璃卡片上放文字时必须实测最坏情况（最亮背景图）下的对比度。

---

## 3. AI 专属渐变（设计系统固定资产）

仅用于 **AI 功能相关元素**，不得滥用到普通 section。

```css
background: linear-gradient(
  87.4deg,
  var(--color-purple) 4.82%,
  #2ca3ff 49.84%,
  var(--color-green) 96.62%
);
```

> 代码字面量保持源码原样的小写 `#2ca3ff`（老代码 hex case 不连动改，见 §1）；在文档/新代码里**引用**该常量时写大写 `#2CA3FF`。同一色值，勿视为两个值。

> 🟢 **这是设计系统固定渐变资产，不是组件配色配方。** 其中 `#2ca3ff` 是该渐变的专用常量——它**不算违反**「禁写死 hex」红线（`handoff-schema.md` §8.4 括号里的"设计系统固定渐变资产等已文档化例外"指的就是这一项）。QA 不得把它判为 `FixedColorCheck: Failed`。

**Announcement 渐变（spec §2.8，2026-08-11 给出色标）**：公告栏装饰用**径向**渐变，弧形背景装饰，五个色停：

`#DAFFE7` → `#74D9D2` → `#3B95DF` → `#7272C3` → `#413D3B`

> 🔴 **只有色标，没有几何参数——不足以直接写 CSS。** spec 说明是"径向渐变、弧形背景装饰"，但**未给出**圆心位置、半径、形状（circle / ellipse）、以及五个 stop 的百分比位置。凭这五个色值硬写一条 `radial-gradient()` 出来的效果与设计稿不会一致。
> 需要落地这条渐变时：**停机**，向用户要 Figma 节点或原始 CSS。不得自行编造 stop position。
> 用途边界：**仅 Announcement Bar 装饰背景**，不泛化到其它 section。

> 🟢 **本条不推翻上面的 AI 专属渐变。** spec §2.8 的原文是「渐变仅用于 Announcement Bar 装饰背景，不用于其他场景」，字面上会读成"AI 渐变也不许用了"——但该基线文档通篇未提 AI 渐变，属于**未覆盖**而非**废止**。AI 渐变是已文档化的设计系统固定资产，本版**原样保留**，同时标记 🔴 **待设计方确认二者关系**。不得据 §2.8 的措辞自行删除 AI 渐变。

---

## 3.1 按钮变体配色（spec §6.1，2026-08-11 补全）

尺寸档（padding / 字号 / 高度）在 `responsive-and-spacing.md` §3.3；**本表只管颜色**。

| VARIANT | 背景 | 文字 | 边框 | 典型用途 |
|---|---|---|---|---|
| Primary-Dark | `#413D3B` | `#FFFFFF` | 无 | "Get Started"、"Shop Devices"（默认主按钮） |
| Primary-Purple | `#8F53ED` | `#FFFFFF` | 无 | Subscription CTA |
| Primary-Green | `#39F672` | `#000000` | 无 | Best Value 按钮、Pre Order CTA |
| Primary-Cyan | `#00D0FF` | `#000000` | 无 | "Shop Now"（公告栏紧凑按钮） |
| Primary-White | `#FFFFFF` | `#000000` | 无 | 白色按钮 |
| Secondary-Outline | `transparent` | `#000000` | **1px `#717171`** | "Compare"（PC & MB 通用） |

Hover（**仅 PC**）：见 §1 的品牌色 hover 表（黑 `#635F5D` / 蓝 `#07AFD5` / 紫 `#7B35EB` / 绿 `#30D462` / 白 `#EEEEEE`）。
过渡统一 `transition: background-color 0.2s ease`，**过渡时长不单独 token 化**。

- 颜色一律走变量，不写死 hex（红线④）。需要局部微调时覆盖 `--btn-primary-bg-color` / `--btn-primary-hover-bg-color`，见 §7。
- Secondary-Outline 的边框色 `#717171` 与 `label-secondary` 同值，但**语义不同**——写边框时用边框变量，别借 `--color-label-secondary`（label 变量在 `.use-color-scheme` 下会被重绑，边框会跟着变色）。
  🔴 **spec 未给这个边框定义语义 token**。

  ⚠️ **v0.2.1 实测更正（`shopify-plaud-yidian`，2026-08-12）——「借用 label-secondary 会变色」不是假设，已经是既存现实；而且仓库里 outline 是两条互不相通的样式链，选路前必须先算 blast radius：**

  | 类 | 边框色来源 | 是否消费 `--btn-outline-border-color` |
  |---|---|---|
  | `.btn-outline`（旧，`assets/critical.css:520`） | `var(--btn-outline-border-color)`，由 `layout/theme.liquid:350` / `layout/password.liquid:87` 按 color scheme 输出，setting 定义在 `config/settings_schema.json`（`btn_outline_border_color`，default `#39F672`，并映射 `role.secondary_button_border`） | ✅ 是 |
  | `.btn-secondary-outline`（新，`snippets/design-system.liquid`） | 写死 `1px solid var(--color-label-secondary)`；而同一产物的 `.use-color-scheme` 把 `--color-label-secondary` 重绑成 `var(--color-text)` | ❌ 否 |

  另外 `config/settings_data.json` 的 **10 个 color scheme 存的边框值全是 `#39f672`**（`btn_outline_background` 同为 `#39f672`），与 spec 的 `#717171` 不一致；`assets/sa-user-guide-anchor.css:56` 已经把 `--btn-outline-border-color` 覆盖成 `var(--color-label-secondary)`。

  🔴 **因此「仓库已有变量 → 直接复用」这个推论不成立**，落地前先回答一个问题并在改动说明里写明结论：

  | 前置判断 | 落地方式 |
  |---|---|
  | `.btn-outline` 与 `.btn-secondary-outline` 要**统一**成同一语义（灰边框） | 复用 `--btn-outline-border-color`，**不新增 token**；但改 10 个 scheme 存值会同时改变所有旧 `.btn-outline` 按钮 → 属改运营线上配置，走 §8.1 红线②的授权流程，并先跑 `plaud-theme-impact` |
  | 旧 `.btn-outline` 必须**保留**现有品牌绿行为，Secondary-Outline 要稳定为灰 | 仍需独立语义变量：新增 `--color-border-outline: #717171` 到 `design-utilities.scss` 再 build |
  | 两条链的关系尚未裁决 | **停机**要设计方/PM 裁决，不得自行选一条 |

  两种落地都**禁止内联硬编码 hex**。

---

## 4. `color_scheme` 配置与 Liquid 写法

### 4.1 schema

所有需要运营切换背景色 / 文字色的模块或 block，统一使用：

```json
{
  "type": "color_scheme",
  "id": "color_scheme",
  "label": "Color scheme"
}
```

### 4.2 Liquid —— 两个类必须同时出现

```liquid
{{- 'section 级别' -}}
<div class="section gradient color-{{ section.settings.color_scheme }} ...">

{{- 'block 级别' -}}
<div class="gradient color-{{ block.settings.color_scheme }} ...">
```

| 类 | 职责 |
|---|---|
| `gradient` | 渐变背景的基础样式层 |
| `color-{scheme}` | 注入具体颜色变量 |

**两个类缺一不可。** 颜色变量（文字色、背景色、按钮色）全部由方案 CSS 变量驱动，不得在组件内直接写死颜色值。

### 4.3 schema 四件套（迁移模块统一加）

`enable_color_scheme` + `color_scheme` + `remove_duplicate_spaces` + `section_disclaimer`。

- 配色相关字段可加 `visible_if: "{{ section.settings.enable_color_scheme }}"`，仅勾选 opt-in 时显示。
- `enable_color_scheme` checkbox **不加 `info`**（label 已自解释）。
- `enable_color_scheme` **默认值按模块历史决定**：历史有非空 stored 值 → `true`；否则 `false`。
- **例外**：模块本来就 scheme 常开（每实例都有方案、无开关，如 Floating Image TT / Custom HTML）→ **不加两段式开关**，直接 `color-{scheme} use-color-scheme` 常开（保原行为 + 补 spec 重绑），余下 `remove_duplicate_spaces` / `section_disclaimer` 照加。
- **Card-identity 模块不接 scheme**（如 SA: Team DTC Landing）：卡片是模块身份特征，scheme 全宽接管会破坏。
- **`btn-primary` 颜色 lock 不必要**：默认 scheme 已是 brand-dark；scheme 开时商家选什么就接受。
- 模块 CSS 若硬锁 spec token，必须用 `:not(.use-color-scheme)` 守卫，否则 scheme 开关失效。

**`section_disclaimer` 的执行细则**（四件套里最容易做错的一个）：

| 项 | 规定 |
|---|---|
| 渲染条件 | 有内容才渲染（`!= blank`），空则不输出 wrapper——空 wrapper 在 flex+gap 父级下会吃 gap 撑出幽灵空白 |
| 字号 / 颜色 | **用 critical utility class 挂 HTML**（如 `.fs-body-sm` + `.text-secondary`） |
| 对齐 | **跟随区头 `header_align_pc` / `header_align_mb`**（同一映射变量），不单独开对齐字段 |
| 禁止 | 在 disclaimer 组件 CSS 里重写字号 / 颜色——`design-utilities.scss` 已 direct token 消费；异步 section CSS 里再固定一遍会 FOUC |

**空 `color_scheme: ""` 的行为**：wrapper 类变成 `color-`（匹配不到任何 `.color-{id}`）→ 继承 `:root`，而 `:root` 挂的是**第一个 / default 方案**的色（theme.liquid 把首个方案选择器写成 `:root, .color-{id1}`）。所以空方案 + `use-color-scheme` = 跟随 default 方案。

---

## 5. `.use-color-scheme` 重绑表

`.use-color-scheme` 与 `.color-{scheme-id}` **加在同一元素上**，激活 spec token → scheme token 的 rebind。

| spec token | 开方案时重绑到 | 默认值 | 说明 |
|---|---|---|---|
| label-secondary（副标题 / 正文） | `secondary_text_color` | `#717171` | — |
| 🪦 ~~label-tertiary~~（已废止，见 §2.1） | **重绑立即移除** | — | 🔴 过渡期**第一步**就删掉这条重绑，不能等零引用；否则 scheme 开启时 `tertiary_text_color` 会盖掉 root 上的 alias |
| bg-card / bg-soft（卡片 / 浅起面） | `surface_color` | `#F7F7F7` | **不再塌成区块底** |
| separator（分隔线） | `separator_color` | `#EBEBEB` | 已与 `border_color` 脱钩 |
| label-primary / bg-white / bg-primary | `heading_color` / `background` | — | 仍跟随方案 |
| **label-disabled（禁用）** | **不重绑** | `#C7C7C7` | 固定 spec 值，不随方案 |
| **label-inverse-primary / -inverse-secondary（深底反色）** | **不重绑** | `#FFFFFF` / `#ABABAB` | 固定 spec 值 |
| **label-purple / -cyan / -green（彩色高亮）** | **不重绑** | `#8F53ED` / `#00D0FF` / `#39F672` | 固定 spec 值；背景配对受限，见 `a11y.md` §5.1 |

**关于 inverse 不重绑**：方案系统没有"深底 / 反色"档。早期错误重绑到 heading/text 会让深底元素（页脚深底、深色促销条、图上白字 caption）在方案下变深字、对比度失效。已从 `.use-color-scheme` 移除该重绑（改的是 shopify-common 源 `design-utilities.scss`，**需 build**）。

**残留陷阱**：仅 `.bg-white` 与区块大底（bg-primary）仍跟随方案背景。

> 🔴 **核对提醒：上表是规范值，目标仓库的编译产物可能尚未跟上。**
> 实测中出现过仍停在 2026-06-30 修正**之前**的仓库——`label-tertiary` / `-disabled` / `-inverse-primary` / `-inverse-secondary` **全部**重绑，`bg-primary/-secondary/-tertiary` **全部**塌到 `--color-background`，两个 separator **都**绑到 `--color-border`。
> 也就是说：文档称"已解决"的塌缩问题在这类仓库里**依然存在**，§6 的独立色板配方**仍然需要**。
> **规范值仍以上表为准**；动手前先 `grep -o '\.use-color-scheme{[^}]*}' <repo>/snippets/design-system.liquid` 核对。已知案例见 `repo-drift.md` §3.2。

### 5.1 判断"给共享 section 加 use-color-scheme"的真实影响

理论 blast radius ≠ 真实视觉影响，按三点收敛：

1. **只有用了 spec 颜色类的元素才会被重绑**。`use-color-scheme` 只改 `--color-label-*` / `--color-bg-*` / `--color-separator-*` 这些**变量**，不直接设 `color`。写死 hex（含 `<style>` 注入块）、内联 `style="color:…"`、或只用 `py-*` / `fs-*` / `text-center` 等非颜色类的元素**完全不受影响**；只有挂了 `.text-*` / `.bg-*` / `.separator-*` 的元素才跟随。
2. **方案默认态 ≈ 零变化**。方案默认色已设成 spec 值（heading #000 / secondary **#717171** / separator #EBEBEB / surface #F7F7F7）。商家没自定义过方案色 → 重绑前后同值。
   ⚠️ secondary 由 `#7A7A7A` 改为 `#717171` 后，这条「零变化」在**未重新 build 的仓库里不再成立**：方案默认值可能仍是旧 hex。动 secondary 前按 `repo-drift.md` 核对编译产物。
3. **空 `color_scheme: ""` → 跟随 default 方案**（见 §4.3）。

→ "改的是共享文件"不等于"全站都会变"。这与 `handoff-schema.md` §3 的 `TheoreticalReferences` vs `ActualAffectedInstances` 是同一条纪律。

---

## 6. 方案下需要"固定色"的元素（免疫配方）

开启 `use-color-scheme` 后，任何读 `--color-*` token 的类（含 `.bg-soft` / `.text-*`）都会 rebind。某 chrome 元素若需在方案下**保持固定色**，不能用 token 类。

> ⚠️ 配色方案已新增 **UX Spec Colors 分组**并修正重绑，早期的"塌缩"问题**大部分已在方案层解决**——独立色板配方**多数场景不再需要**。卡片类模块现在多数直接 `.bg-card` / `.bg-soft` 跟随 scheme 即可（自动取独立 surface 色、与大底拉开层次）。

仅两种情况另作处理：

| 选择 | 适用 | 做法 |
|---|---|---|
| **跳过 scheme** | 卡片就是模块身份、不希望被方案接管 | 不加 scheme |
| **独立色板**（仅特例） | 卡片固定色要**与方案 surface 色不同**、且需运营单独可调 | 见下方配方 |

**独立色板配方**（scheme 关用 spec token、开用商家自定固定色）：

1. schema 加 `color` 字段 + `visible_if` 仅 opt-in 时显示：
   ```json
   { "type": "color", "id": "card_background_color", "label": "Card Background Color",
     "default": "#F7F7F7", "visible_if": "{{ section.settings.enable_color_scheme }}" }
   ```
2. 用**自定义变量名**（不在重绑列表里 → 天然免疫），条件式赋值：
   ```liquid
   --card-bg: {% if section.settings.enable_color_scheme %}{{ section.settings.card_background_color | default: '#F7F7F7' }}{% else %}var(--color-bg-tertiary){% endif %};
   ```
3. 元素消费 `background-color: var(--card-bg)`，**不要**用 `.bg-soft`（会随方案塌缩）。

> 关键点：`use-color-scheme` 只重绑 `--color-*` 系列，自起的 `--card-bg` / `--xxx-bg` 不在其列，天然免疫。

> 🔴 **这是受控例外，不是默认许可。** 给已存在模块的卡片开 color picker，是对 §7「后台不提供独立字体颜色配置」的受控例外，**须用户确认**；**新建 `sa-*` section 不得套用**。

其它需要在方案下固定色的场景（标签栏背景、卡片色面），只能用固定值（内联 / `<style>`），且**仅在设计明确要求且用户确认后**。"免疫固定色"与"跟随方案"不可兼得，按需取舍。

---

## 7. 自定义颜色规则

- 非特殊情况，**后台不提供独立字体颜色配置**，运营只能切换颜色方案。
- 需要局部自定义颜色时，在 `pre_heading` / `heading` / `sub_heading` 等文本字段里内嵌，**优先用变量而非裸色值**：
  ```html
  <span style="color: var(--color-blue)">…</span>
  ```
  注意字段类型限制：`richtext` 字段的 `<p>` 禁带 `class` / `style`（会导致模板上传失败），详见 `typography.md` §8。
- **新增颜色方案由设计方维护，开发不得擅自新增 scheme 或修改全局颜色变量。**
- 确有差异的按钮配色：**仅覆盖颜色 CSS 变量**微调；特殊情况才直接用色值，且须设计明确要求并经确认。
  ```css
  /* ✅ 优先：通过变量 */
  .my-section .btn-primary {
    --btn-primary-bg-color: var(--color-purple);
    --btn-primary-hover-bg-color: var(--hover-color-purple);
  }
  ```

---

## 8. 无对应工具类时（richtext `<p>` 等）的退路

要上色的元素若是 richtext 渲染的 `<p>`（加不了 class）：退回 section 的 `custom_css` 设选择器（Shopify 自动按 `#shopify-section-…` 限定本 section），但**颜色仍走 token**（`var(--color-label-secondary)` = `#717171`），不写死 hex。

用 token 本身合规；此处的受控例外只是"richtext `<p>` 加不了工具类才退回 template-scoped `custom_css`"——一般情况下禁止在组件 CSS 重写字号 / 色。

---

## 9. 对比度

所有前景 / 背景组合对比度 **≥ 4.5:1**。判定方法与检查清单见 `a11y.md` §5。
