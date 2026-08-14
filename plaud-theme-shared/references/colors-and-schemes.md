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
| 白色 | `#FFFFFF` | `#E9E6E6` | `--color-white` / `--hover-color-white` |

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

**hex 字面量大小写**：新写 spec 字符串统一**大写**（`#FFFFFF` / `#413D3B`）；老代码 hex 小写**不连动改**（用户硬规则：hex case 不动模板）。

---

## 2. Spec 语义色阶（v1.3）

### 2.1 文字色（label）

| token 语义 | 工具类 | hex | 说明 |
|---|---|---|---|
| label-primary | `.text-primary` | `#000000` | 标题 / 主文字 |
| label-secondary | `.text-secondary` | `#7A7A7A` | 副标题 / 正文 |
| label-tertiary | `.text-tertiary` | `#A3A3A3` | 三级 / 小字 / 划线价 / 脚注 |
| label-disabled | `.text-disabled` | `#C7C7C7` | 禁用态 |
| label-inverse-primary | `.text-inverse-primary` | `#FFFFFF` | 深底反色主文字 |
| label-inverse-secondary | `.text-inverse-secondary` | `#ABABAB` | 深底反色副文字 |

**被 v1.3 覆盖的旧值（label 色阶重组）**：

| 旧值（已废） | 现值 |
|---|---|
| secondary `#3D3D3D` | **`#7A7A7A`** |
| tertiary `#7A7A7A` | **`#A3A3A3`** |
| `.text-quaternary` / `--color-label-quaternary` | **已删除**，并入 tertiary（同 hex `#A3A3A3`） |

遇到 `--color-label-quaternary` 残留引用 → 改为 tertiary（同 hex，零视觉影响）。

### 2.2 背景色（spec §2.4）

| 工具类 | 消费变量 | 实测默认值 | 说明 |
|---|---|---|---|
| `.bg-page` | `--color-bg-primary` | `#F2EFEB` | 页面大底 |
| `.bg-card` | `--color-bg-secondary` | `#F7F5F3` | 卡片面 |
| `.bg-soft` | `--color-bg-tertiary` | `#F7F7F7` | 浅起面 |

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

**Announcement 渐变**：仅公告栏场景，不泛化到其它 section。

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
| label-secondary（副标题 / 正文） | `secondary_text_color` | `#7A7A7A` | — |
| label-tertiary（三级 / 小字 / 划线价） | `tertiary_text_color` | `#A3A3A3` | **不再塌成黑** |
| bg-card / bg-soft（卡片 / 浅起面） | `surface_color` | `#F7F7F7` | **不再塌成区块底** |
| separator（分隔线） | `separator_color` | `#EBEBEB` | 已与 `border_color` 脱钩 |
| label-primary / bg-white / bg-primary | `heading_color` / `background` | — | 仍跟随方案 |
| **label-disabled（禁用）** | **不重绑** | `#C7C7C7` | 固定 spec 值，不随方案 |
| **label-inverse-primary / -inverse-secondary（深底反色）** | **不重绑** | `#FFFFFF` / `#ABABAB` | 固定 spec 值 |

**关于 inverse 不重绑**：方案系统没有"深底 / 反色"档。早期错误重绑到 heading/text 会让深底元素（页脚深底、深色促销条、图上白字 caption）在方案下变深字、对比度失效。已从 `.use-color-scheme` 移除该重绑（改的是 shopify-common 源 `design-utilities.scss`，**需 build**）。

**残留陷阱**：仅 `.bg-white` 与区块大底（bg-primary）仍跟随方案背景。

> 🔴 **核对提醒：上表是规范值，目标仓库的编译产物可能尚未跟上。**
> 实测中出现过仍停在 2026-06-30 修正**之前**的仓库——`label-tertiary` / `-disabled` / `-inverse-primary` / `-inverse-secondary` **全部**重绑，`bg-primary/-secondary/-tertiary` **全部**塌到 `--color-background`，两个 separator **都**绑到 `--color-border`。
> 也就是说：文档称"已解决"的塌缩问题在这类仓库里**依然存在**，§6 的独立色板配方**仍然需要**。
> **规范值仍以上表为准**；动手前先 `grep -o '\.use-color-scheme{[^}]*}' <repo>/snippets/design-system.liquid` 核对。已知案例见 `repo-drift.md` §3.2。

### 5.1 判断"给共享 section 加 use-color-scheme"的真实影响

理论 blast radius ≠ 真实视觉影响，按三点收敛：

1. **只有用了 spec 颜色类的元素才会被重绑**。`use-color-scheme` 只改 `--color-label-*` / `--color-bg-*` / `--color-separator-*` 这些**变量**，不直接设 `color`。写死 hex（含 `<style>` 注入块）、内联 `style="color:…"`、或只用 `py-*` / `fs-*` / `text-center` 等非颜色类的元素**完全不受影响**；只有挂了 `.text-*` / `.bg-*` / `.separator-*` 的元素才跟随。
2. **方案默认态 ≈ 零变化**。v1.3 已把方案默认色设成 spec 值（heading #000 / secondary #7A7A7A / tertiary #A3A3A3 / separator #EBEBEB / surface #F7F7F7）。商家没自定义过方案色 → 重绑前后同值。
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

要上色的元素若是 richtext 渲染的 `<p>`（加不了 class）：退回 section 的 `custom_css` 设选择器（Shopify 自动按 `#shopify-section-…` 限定本 section），但**颜色仍走 token**（`var(--color-label-secondary)` = `#7A7A7A`），不写死 hex。

用 token 本身合规；此处的受控例外只是"richtext `<p>` 加不了工具类才退回 template-scoped `custom_css`"——一般情况下禁止在组件 CSS 重写字号 / 色。

---

## 9. 对比度

所有前景 / 背景组合对比度 **≥ 4.5:1**。判定方法与检查清单见 `a11y.md` §5。
