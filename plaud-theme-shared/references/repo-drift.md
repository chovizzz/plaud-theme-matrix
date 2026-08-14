# 规范值 vs 目标仓库编译产物

**何时读我**：🔴 **在任何仓库动 spec 数值、或依赖某个 token / 工具类之前**。也在"按规范改完却没生效""同一个类在两个仓库表现不同""变量写了没颜色"时读。

---

## 1. 核心结论

> **规范就是规范** —— 本层 reference 记录的值即为准。
> 但 **任何仓库的 `snippets/design-system.liquid` 都可能落后于规范**：它是 `design-tokens.scss` + `design-utilities.scss` 的 **build 产物**，包含哪些 token / 工具类、它们当前是什么值，取决于**该仓库最后一次 build 的时间点**。
> 所以**开工前必须核对目标仓库的实际编译值** —— 不是因为某个仓库特殊，而是因为 build 产物本来就会滞后于规范。

两个方向的失败模式：

| 方向 | 表现 |
|---|---|
| 拿规范去改滞后的仓库 | 依赖的 token / 工具类**在该仓库不存在或语义不同** → 静默失效、视觉回归 |
| 拿仓库实测值去推翻规范 | 把某次 build 的历史快照当成规范，**规范值被旧值污染** → 越改越回退 |

**两个方向都要避免。** 规范值不因某仓库落后而失效；实测值也不能升级成规范。

---

## 2. 开工前的强制核对

`design-system.liquid` 是"这个仓库当前真正生效的值"的唯一凭据（不是 `assets/critical.css` —— 它已在 `theme.liquid` 注释禁用，grep 它无意义）。

```bash
F=<repo>/snippets/design-system.liquid

# 该仓库实际的字阶 token
grep -oE '\-\-text-[a-z0-9-]*: *[0-9]+px;' "$F"

# 该仓库实际的 container 内边距阶梯
grep -o '\.container{[^}]*}' "$F"

# 该仓库 use-color-scheme 实际重绑了哪些
grep -o '\.use-color-scheme{[^}]*}' "$F"

# 某个工具类 / 变量在这个仓库到底存不存在
grep -c '\.separator-b' "$F"          # 0 = 不存在，别用
grep -c '\.richtext-container' "$F"
grep -c '\-\-color-purple' "$F"
```

**取不到该文件、或实测值与本层 reference 冲突** → 按 `handoff-schema.md` §7 停机，把冲突报给用户，**不擅自选一边**。

---

## 3. 已知案例：编译产物可能缺什么 / 差什么

以下是在真实仓库编译产物中**实测到过**的差异（3.1–3.5 于 2026-08-06，3.6–3.7 于 2026-08-12）。它们不绑定任何特定站点 —— 任何仓库只要 build 时间点早于对应变更，就会出现同样情况。**用作核对时的检查清单。**

### 3.1 `.container` 左右内边距可能仍是旧值

| | 值 |
|---|---|
| **规范值** | XS / Mobile = **24px**（DTC-399，2026-06-15，由 15px 改） |
| 某仓库实测 | base（< 576）= **15px**；≥ 768 才 24px；≥ 1200 = 40px；≥ 1280 = 80px；≥ 1440 = 160px |

→ 看到 15px **不代表规范是 15px**。做"小屏内容区收窄"前先确认目标仓库是否已落 DTC-399；未落则这是一次独立的、需授权的拉齐改动（见 §4）。

### 3.2 `.use-color-scheme` 重绑范围可能更广（塌缩问题仍在）

| | 行为 |
|---|---|
| **规范值** | `label-disabled` / `label-inverse-primary` / `label-inverse-secondary` **不重绑**（固定 spec 值）；`bg-card` / `bg-soft` 重绑到独立 `surface_color`；`separator` 与 `border_color` **已脱钩** |
| 某仓库实测 | `label-tertiary` / `-disabled` / `-inverse-primary` / `-inverse-secondary` **全部**重绑到 `var(--color-text)` 或 `var(--color-heading)`；`bg-primary` / `-secondary` / `-tertiary` **全部**塌到 `var(--color-background)`；`separator-default` 与 `-emphasized` **都**绑到 `var(--color-border)` |

→ 该状态 = 2026-06-30 修正**之前**。在这样的仓库里给深底反色元素、卡片色面、分隔线开 `use-color-scheme`，会遇到文档称"已解决"的塌缩；此时 `colors-and-schemes.md` §6 的**独立色板配方仍然需要**。

### 3.3 品牌色变量可能是另一套命名

| | 存在的变量 |
|---|---|
| vendor §3.3 表 | `--color-black` / `--color-purple` / `--color-blue` / `--color-green` / `--color-white` + `--hover-color-*` |
| 某仓库实测 | 只有 `--color-black`、`--color-white`；紫 / 青 / 绿走 **`--color-highlight-purple` / `-cyan` / `-green`**（+ `-hover` 后缀），另有 `--color-brand-dark` / `-hover`、`--color-brand-cyan` |

→ 变量不存在且无 fallback 时，属性**直接失效**（不是回退成默认色，是整条声明作废）。写 `var(--color-purple)` 前先 `grep -c` 确认；highlight 系命名在实测中更普遍。**色值本身两套一致**。

### 3.4 部分工具类可能尚未 build 进来

| 工具类 | 某仓库实测 |
|---|---|
| `.separator-t` / `-b` / `-y` / `-strong` | **不存在**（记为 2026-06-30 新增，需 build） |
| `.richtext-container` | **不存在** |

→ 用前 `grep -c` 确认。不存在 = 该仓库还没 build 这批 utility，应按 `responsive-and-spacing.md` §3.1 的流程补源再 build，**不要内联替代**。

### 3.5 `.bg-card` 与 `.bg-soft` 消费不同变量

| 工具类 | 消费变量 | 实测默认值 |
|---|---|---|
| `.bg-card` | `--color-bg-secondary` | `#F7F5F3` |
| `.bg-soft` | `--color-bg-tertiary` | `#F7F7F7` |

→ ux-spec 文档笼统说"bg-card / bg-soft 重绑到 surface `#F7F7F7`"，但编译产物里两者**变量不同、默认色也不同**。需要两层浅色面拉开层次时这 2 点色差可用，但**不要假设两者可互换**。

### 3.6 outline 按钮在仓库里是两条链，且 label 变量重绑已实际发生

**已实测（`shopify-plaud-yidian`，2026-08-12）**：

| 事实 | 证据 |
|---|---|
| `.btn-outline` 消费 `--btn-outline-border-color`（scheme 级可配，setting `btn_outline_border_color` default `#39F672`，映射 `role.secondary_button_border`） | `assets/critical.css:520`；`config/settings_schema.json`；`layout/theme.liquid:350`、`layout/password.liquid:87` |
| `.btn-secondary-outline` **不**消费该变量，而是写死 `1px solid var(--color-label-secondary)` | `snippets/design-system.liquid` |
| 同一产物的 `.use-color-scheme` 把 `--color-label-secondary` 重绑为 `var(--color-text)` → 借用 label 变量做边框**确实会变色**（不是理论风险） | `snippets/design-system.liquid` |
| 10 个 color scheme 存的 `btn_outline_border_color` **全是 `#39f672`**（`btn_outline_background` 亦同），与 spec 的 `#717171` 不一致 | `config/settings_data.json` |
| 已有模块把 outline 边框覆盖成 label-secondary | `assets/sa-user-guide-anchor.css:56` |
| `--color-label-secondary: #7A7A7A`、`--color-label-tertiary: #A3A3A3` 仍在产物里 → 2026-08-11 基线的 `#717171` / tertiary 废止**尚未落库** | `snippets/design-system.liquid` |

→ 结论：**「仓库已经有边框变量」不等于「直接复用即可」**。选路规则见 `colors-and-schemes.md` §3；两条链的关系未裁决时**停机**。

### 3.7 全局 heading 规则仍是旧 vendor 值，另有一套死变量声明

`assets/critical.css:107/148` 的 `:where(h1..h6)` 走 `--size` × `--heading-font-scale`，根字号 `html{font-size:16px}`（`critical.css:8`）：`h5` = `1.8rem` → **28.8px**，`h1` = `clamp(3.6rem, …, 4rem)` → **57.6–64px**，正是 `typography.md` §3 标为**已废止**的 vendor 64px。**这是唯一真正生效的一套。**

另有 `layout/theme.liquid:418-424` 的 `--h0-size…--h6-size`（`--h5-size: 18px`）—— **只有声明、没有消费点**：全仓 `grep -r 'var(--h5-size)'` 零命中，它对渲染结果没有影响。核对时不要把它当成"h5 = 18px 已落地"。

→ **不要**用"复用全局 h5 规则"来解决字号问题（v0.2.0 曾这样写，v0.2.1 已撤回）；也**不要**去消费 `--h5-size`（接上死变量等于新造一条渲染路径）。按 `typography.md` §4 处理：标签与字号解耦。

---

## 4. 报告要求

一旦在目标仓库发现漂移：

1. **不改本层 reference 的规范值**；
2. 在 handoff 的 `BlockingGaps` 或改动说明里写明：**规范值 X / 该仓库实测 Y / 本次按哪个执行 / 理由**；
3. 需要把该仓库拉齐到规范时，那是一次**独立的、需授权的**改动（改 `shopify-common` 源 + `npm run build`），**不得夹带在当前任务里顺手做**。

---

## 5. 实测与规范一致、可直接采信的部分

以下在实测中与本层 reference **完全吻合**，未发现过漂移：

| 项 | 值 |
|---|---|
| `--space-N` | 4 / 8 / 16 / 24 / 32 / 40 / 56 |
| `--radius-base` / `-lg` / `-xl` | 5 / 10 / 15px |
| `--container-max-*` 7 阶 | 1600 / 1440 / 1280 / 1140 / 960 / 720 / 540 |
| ~~label 色阶~~ | 🔴 **已移出本表**：2026-08-11 基线把 secondary 改为 `#717171`、**废止 tertiary 档**。实测中见到的 `#7A7A7A` / `#A3A3A3` 现在是**漂移**（build 早于新基线），不再是"与规范一致"。现行值见 `colors-and-schemes.md` §2.1，动它之前必须 grep 核对 |
| separator 色 | default #EBEBEB、emphasized #CCCCCC |
| 行高 | `--head-line-height` 1.2 / `--body-line-height` 1.5 |
| 字阶 9 档 | 48/40、40/32、32/28、28/24、24/20、20/18、16/16、14/14、12/12 |
| 按钮尺寸档 | 见 `responsive-and-spacing.md` §3.3 |
| 断点精度 | `.98`（`max-width: 767.98px` 等） |

> ⚠️ "未发现过漂移"≠"保证不会漂移"。这张表用于**缩小核对范围**，不替代 §2 的核对。
