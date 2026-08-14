# QA-Global — 恒执行七项（可执行步骤）

与路径无关，每次 QA 都跑。

**阈值一律现读 `plaud-theme-shared/references/` 的当前值，本文件不复制数值**——对比度下限读 `a11y.md`、图片 DPI 倍率与 width 取值规则读 `media-quality.md`、断点与间距读 `responsive-and-spacing.md`、字阶读 `typography.md`。复制会产生第二个事实源，spec 一升级就漂移。

（唯一的例外是 `BreakpointsCovered` 的五档取值——它由 handoff-schema §5 字段说明直接规定，属于契约本身，不是视觉 reference 的数值。）

每项输出 `Passed` / `Failed` / `Blocked` / `NotApplicable` + 证据。证据为空 → 降级 `Blocked`。

🔴 **在哪里跑（v0.3.0 起，handoff-schema §2.6）**：

| 命令类型 | 跑在哪 |
|---|---|
| 读文件 / grep / 跑工具（theme check、build、预览） | **`StageDirRef` 指向的 workspace 快照**（`plaud_stage_workspace` 的产物），**不在活工作树上跑**——重算相等之后、逐文件读取期间工作树还能再变（TOCTOU） |
| 需要 git 历史的举证（`git show <BaseHeadSha>:<file>`、`git diff <BaseHeadSha> …`） | **原仓库**，一律带 `git -C <theme-root>` —— 快照里没有 `.git` |
| Theme Check 的 baseline | 从 `BaseHeadSha` 另行物化，见 `theme-check-gate.md` §2 |

`Evidence` / `ThemeCheckEvidence` 里必须写明每条命令实际跑在哪个目录（快照路径 / 仓库路径），否则无法复核。
📎 **本文所有 `git diff` 的基准从 `HEAD` 改成了 `<BaseHeadSha>`**：v0.3.0 起实施期间 commit 是合法的（§2.8 不再拿 HEAD 做失配判据），继续用 `HEAD` 做基准会在改动已被提交时**扫出空 diff、系统性漏检**。`BaseHeadSha` 不可解析时这些举证一律 `Blocked`（§2.5 / handoff-schema §2.5 注释），不得降级放行。

> 本文件的七项之外，SKILL.md 还规定了三条**附加触发式检查**（shared 红线 4 颜色 token / 红线 6 JS 生命周期 / 红线 7 build 产物勿手改），同样与路径无关，结果写进 `ProfileSpecificResults`。细则分别见 `qa-profile-a.md` A5 与 `qa-profile-c.md`——**Path B/C 也要跑 A5，Path A/B 也要跑 build 产物那条**，不要因为"不是我这条 profile 的"就跳过。

---

## 1. ThemeCheck

见 `theme-check-gate.md`（全文）。触发条件（handoff-schema §6）：改了 `.liquid` / theme JSON / schema / `snippets/` / `sections/` / `templates/` / `config/` / `locales/` 任一者 → `ThemeCheckRequired: Yes`。纯文档 / 纯注释 → `NotApplicable`（附一句理由，且该理由须能从 `ModifiedFiles` 复核；没有理由的 `NotApplicable` 按 `Blocked` 处理）。

🔴 两条不可打折的执行要求（handoff-schema §6，细则见 `theme-check-gate.md` §3 / §6）：

1. **改动前后两次都必须全仓跑**，`--path` 指向 theme root。**不得只扫 `ModifiedFiles`**——删 asset / 删 locale key / 删 snippet 会让 offense 出现在**未被修改的调用方文件**里（`MissingAsset` / `TranslationKeyExists` / `MissingTemplate`），只比对改动文件范围会系统性漏掉这类外溢。
2. **`addedInModifiedFiles` 与 `addedOutsideModifiedFiles` 两个指标都必须为 0** 才能 `Passed`。范围外新增必须逐条归因：本次改动引起 → `Failed`；基线漂移 → `Blocked` + 说明。**任何情况下不得判 `Passed`。**

---

## 2. RegressionMatrix + BreakpointsCovered

### 2.1 先算"受影响页面"，不是"改了哪个文件"

```bash
# section / snippet 的模板占用
grep -rl '"type": "<module-name>"' <theme-root>/templates/ | sort
# snippet 的调用方
grep -rn "render '<snippet>'\|include '<snippet>'" <theme-root>/{sections,snippets,layout}/
# CSS / JS 资产的引用方
grep -rn "<asset-file>" <theme-root>/{layout,sections,snippets}/
```

上游 `plaud-theme-impact` 已给出 `ActualAffectedInstances` 时**以它为准并复算一次**（抽查 ≥2 条）。复算不上 → `Blocked`，要求 Assess 重做。上游没做 Assess（`InlineLite`）→ 自己跑上面的 grep。

### 2.2 矩阵形状

必须是 **页面 × 断点** 的二维表，不是一句"各断点都看了"：

| 页面 / 实例 | PC | 1599 | 1279 | 767 | 375 |
|---|---|---|---|---|---|

- 断点取值 **PC / 1599 / 1279 / 767 / 375**，五档缺一不可，写进 `BreakpointsCovered`。
- 除断点外还要覆盖：layout mode、schema 选项组合、block type、Swiper effect、关键开关（这几维来自旧 skill 的全量回归矩阵）。
- 每格填结论（OK / 具体问题），**不填勾**。
- 无法真实预览（无 dev store / 无浏览器）→ `RegressionMatrix: Blocked` + 原因。**不得**用"读代码推断没问题"顶替。

### 2.3 与 ThemeRuntimePreview / AdminSchemaSave 的分工

- `ThemeRuntimePreview` — 主题在真实预览环境能否正常渲染、JS 无报错。拿不到预览 → `Blocked`。
- `AdminSchemaSave` — 改过 schema 时，去 Shopify admin 后台保存一次。**`step` / `max` / `min` / `range` 约束只有后台保存才会校验**，静态检查查不出来。没改 schema → `NotApplicable`；改了但没法进后台 → `Blocked`。

---

## 3. LocalizationCheck（英译德长文案）

德语是本站长文案压力测试基准（复合词长、单词不可断）。

步骤：

1. 取本次改动涉及的**全部**展示文案字段（schema `default`、locales key、实例 stored 值）。
2. 逐条译成德语（或用等长德语占位），代入 theme editor / locale 文件。
3. 在 **375 与 767** 两档重点看（窄屏最先炸），PC 档看按钮与表头。
4. 观察三类症状：**溢出**（横向滚动条 / 内容出容器）、**遮挡**（重叠、被裁）、**异常换行**（单词中断、孤字、按钮撑破）。

证据形态：用了哪几条德语文案 + 在哪个断点 + 观察结果。只写"德语测过了没问题" → `Blocked`。

本次未涉及任何展示文案 → `NotApplicable` + 理由。

---

## 4. A11yCheck

底线清单见 `plaud-theme-shared` 红线 5 / `references/a11y.md`。逐项在改动范围内核查：

| 项 | 取证方式 |
|---|---|
| 交互元素用语义 `button` / `a`，不是裸 `div` + onclick | grep `onclick`、`role="button"`，逐条看标签 |
| 图标按钮、轮播按钮有 `aria-label` | grep `<button`，逐个看有无可访问名 |
| dialog / drawer / popup 有 `trapFocus` | grep `trapFocus`，对照新增弹窗 |
| 对比度达标（下限现读 `plaud-theme-shared/references/a11y.md`） | 取前景/背景实际色值算一次，写出比值与所用下限 |
| `focus-visible` 样式存在且未被 `outline: none` 干掉 | grep `outline:[[:space:]]*none` / `:focus` |
| skip link 未被破坏 | 改了 `layout/theme.liquid` 时才查 |

改动完全不含 markup / CSS / JS 交互面 → `NotApplicable` + 理由。

---

## 5. FixedDimensionCheck

红线：禁止无理由写死组件宽高（shared 红线 2，例外范围以 shared 为准）。

**扫描分两步：先把所有尺寸声明捞全，再逐条裁定。不要用整行 `grep -v` 过滤。**

```bash
# 第 1 步：捞全所有尺寸属性声明（含逻辑属性、含 var()/calc()、含内联 style）
#          -o 只输出命中的声明本身，避免一行里有合法+非法两条时被整行过滤掉
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -E '^\+' \
  | grep -oE '(^|[^-a-z])(min-|max-)?(width|height|inline-size|block-size)[[:space:]]*:[^;"}]*'

# HTML 属性形式
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*(width|height)="[^"]*"'
```

**第 2 步：对捞出的每一条声明逐条裁定**（不能靠模式一刀切）：

| 声明形态 | 裁定 |
|---|---|
| `min-width` / `min-height` / `min-inline-size` / `min-block-size` | ✅ 允许（红线只禁固定尺寸） |
| `width: auto` / `height: auto` / `…-size: auto` | ✅ 允许 |
| `max-height` / `max-block-size` + 固定值 | ⚠️ **不自动放行** —— 它会裁掉超长文案，与红线的多语言意图冲突。要么确认内容不可能溢出，要么判 `Failed` |
| `width` / `height` / `inline-size` / `block-size` + 字面量（`40px` / `2rem` / `50vh`…） | 属 shared 红线 2 的允许例外 → 记豁免 + 引用哪条；实现工件已说明理由 → 引用；否则 **`Failed`** |
| `height: var(--x)` / `block-size: calc(...)` | **同样要查** —— 变量/计算式里可能就是个固定值。追到定义处看它是不是固定 px；追不到 → `Blocked` + 说明 |
| 内联 `style="height: …"` | **高危**，媒体查询盖不住。除非是技术例外，一律 `Failed` |

> 🔴 **三个常见的漏检姿势：**
>
> 1. **只 grep `width|height`** —— `block-size: 40px` / `inline-size: 200px` 与它们等效，会直接漏过。
> 2. **整行 `grep -v '(min|max)-'`** —— 一行里同时有 `min-height: 40px; height: 40px` 时，整行被过滤，非法的那条跟着一起漏了。所以第 1 步用 `-o` 逐声明输出。
> 3. **只匹配数字字面量** —— `height: var(--card-h)` / `block-size: calc(100% - 20px)` 匹配不到，但它们照样可能是写死的固定高。

对每条命中做**三选一**裁定，逐条写进证据：

- 属 shared 红线 2 列出的允许例外（图标 / 1px 线 / 明确固定的技术容器 / Swiper cube·vertical 要求的固定 px height）→ 记为豁免 + 引用哪条例外。
- 实现工件（§4 `OptionsConsidered` 或正文）里已说明理由 → 引用那段说明。
- 两者都没有 → `FixedDimensionCheck: Failed`，列出文件:行号。

**注意 `<img width height>` 属性是防 CLS 必需，不属于本项违规**（那是第 6 项的范畴）。

### 5.1 按钮高度的特殊口径（2026-08-11 基线）

新基线给出了按钮四档高度（LG 40 / MD 35 / SM 25 / Outline PC 35·MB 32）。**这不是写死 `height` 的许可**：

| 写法 | 判定 |
|---|---|
| `min-block-size: 40px` + `height: auto` + padding 撑开 | `Passed` —— 这是正确落地方式 |
| `height: 40px` / `min-height` 之外的固定高 | **`Failed`** —— 长语言换行会溢出或被裁 |
| 任何固定 `width` | `Failed` —— 本次基线未放开宽度 |

数值现读 `plaud-theme-shared/references/responsive-and-spacing.md` §3.3.1，不要凭记忆。
校验手法与 `LocalizationCheck` 共用一组素材：换德语长文案后按钮**变高**而不是文字溢出。

---

## 6. ImageQualityCheck

红线：`image_url` 的 `width:` **只**用于防 CLS / 适配容器，须按容器实际显示宽度 × 高 DPI 取值；禁止用过小 width 把展示图下采样糊掉（shared 红线 3）。**具体倍率与取值规则现读 `plaud-theme-shared/references/media-quality.md`，不要凭记忆用数字。**

### 触发条件（两类，缺一会漏报）

只 grep `image_url` 是不够的：**图片请求宽度没变、但容器变宽了，图片立刻欠采样。** 两类都要查：

```bash
# (1) 图片请求本身变了
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*(image_url|srcset|sizes=)'

# (2) 图片的显示容器变了
#     两个要点：① 同时看 + 和 - 两侧（**删掉**一条声明同样会让容器变宽）
#              ② 不只是 width/grid —— padding / gap / inline-size / 容器类替换
#                 都会改变图片的实际显示宽度
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> \
  | grep -nE '^[+-][^+-].*((max-|min-)?(width|inline-size)|grid-template-columns|grid-cols|col-span|flex-basis|flex:|gap|padding|aspect-ratio|@media|container|class=)'
```

命中面偏宽是有意的：**误报一条只是多算一次容器宽度，漏报一条就是线上一张糊图。** 逐条判断"这个改动会不会让某张图的显示宽度变大"，判完写进证据。

(2) 有命中时，必须回头找**该容器里渲染的所有图片**（即使它们的 `image_url` 一行没动），逐个重算：

```bash
grep -rn 'image_url' <包含该容器的 section/snippet>
```

### 逐条核

1. 有没有 `width:`？没有 → `ImgWidthAndHeight` 会在 theme check 里报，同时本项 `Failed`。
2. 该图在**最大断点**下的容器显示宽度是多少？（从 CSS / grid 列数 / container 宽推算，写出推算过程）
3. `width:` 取值是否满足 `media-quality.md` 规定的倍率？或用了 `master` / 响应式 `srcset`？否则 `Failed`，写出"容器约 N px，width 只给了 M，欠采样"。
4. 展示型 section（banner / 大图 / 卡片配图 / slideshow / accordion / multi-content 等）是重点；纯图标 / 缩略图按实际用途判断。

`NotApplicable` 的条件是**两类触发都无命中**——只说"没改 image_url"不够，必须同时说明容器宽度未变。

---

## 7. CopyConfigurabilityCheck

红线 1：展示文案必须走 schema 字段或 locales；Liquid 不得 `| default: '...'` 兜底；`blank` 不输出空壳 DOM。

```bash
# 兜底文案
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE "^\+.*[|][[:space:]]*default[[:space:]]*:[[:space:]]*['\"]"
# 硬编码展示文案。三类都要抓：
#   (a) 标签之间的文本节点（含中文、德语变音符等非 ASCII，所以用"非标签非 Liquid 字符"取反匹配）
#   (b) JS 里直接写进 DOM 的字面量
#   (c) Liquid assign / capture 出来的展示字符串
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*>[^<>{}\"']*[^[:space:]<>{}\"'][^<>{}\"']*<"
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*(textContent|innerHTML|innerText|placeholder|aria-label|title)[[:space:]]*=[[:space:]]*['\"]"
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*\{%-?[[:space:]]*(assign|capture)[[:space:]].*['\"][^'\"]{3,}['\"]"
# 空壳 DOM 风险：新增的展示标签是否有 != blank 守卫
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*<(h[1-6]|p|a|img)\b'
```

裁定：

- `| default: '文案'` 命中 → `Failed`（`| default:` 后接数字、token、非展示值不算）。
- 展示文案字面量写死在 liquid / js → `Failed`。
- 新增展示标签外层没有 `!= blank` 守卫 → `Failed`（会出 `<h2></h2>` 空壳）。
- schema `default` 字段里写英文占位 → **合法**，不是违规（运营可在 theme editor 改）。
- schema 的 `label` / `info` / `content` 直接写英文、不用 `t:` 前缀 → **合法**。

改动不含任何展示文案 → `NotApplicable` + 理由。

### 7.1 判定范围：本次触及的行（v0.2.1 收窄）

上面所有 `git -C <theme-root> diff <BaseHeadSha> -U0` 命令**只看本 ChangeSet 新增/修改的行**，这不是取巧，是本项的**判定范围定义**（`handoff-schema.md` §8.1 红线⑤按范围分级）：

| 情形 | 判定 |
|---|---|
| 本次新增 / 修改的行里有硬编码展示文案 | 🔴 `Failed` |
| 未被本次改动触及的存量硬编码（复用旧 section / snippet 时常见） | 🟡 进 `Advisories`，**不判 Failed、不要求顺手修**（`handoff-schema.md` §8.1.2） |
| ⚠️ 本次改动让**原本不可达**的旧硬编码进入了新的可达路径 | 🔴 `Failed`，按新增判 |

🔴 **第三种 `git diff` 抓不到，必须人工判。** 触发形态：复用旧 snippet、放开原本 false 的条件分支、把旧 section 挂到新模板 / 新实例、扩大某个 `{% if %}` 的命中范围。判定动作：对 `ModifiedFiles` 里每一处**新增的引用 / 挂载 / 条件放开**，去被引用方 grep 一次硬编码文案，命中即按 🔴 判，并在结论里写明"经由本次哪一处接入而可达"。

写 `Advisories` 时必须标明「存量，`BaseHeadSha` 已存在」+ 证据命令，否则按新引入判（豁免的举证责任在实现方，见 §11）。

---

## 8. 附加触发式检查（补 §5 profile 表的红线空隙）

§5 的 QA-Global 七项没有覆盖 shared 红线 4 / 6 / 7，而这三条原本只散落在单个 profile 里——换条路径就漏检。以下三项**与路径无关**，触发即查，结果写进 `ProfileSpecificResults`（**不新增 yaml 字段**）。

### 8.1 红线 4 — 颜色走 token / CSS 变量

触发：diff 含 `.css` / `.scss` / Liquid 内联 `<style>` / inline `style=`。

```bash
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*#[0-9a-fA-F]{3,8}\b'
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*(rgba?|hsla?)\('
```

逐条裁定：走 `var(--token)` → 合规；写死 hex / rgb 且不属于 `colors-and-schemes.md` 已文档化的例外（设计系统固定渐变资产等）→ `Failed`。Path C 另有"新 hex 必须大写"的约定（见 `qa-profile-c.md` C4 §4.2），Path A/B 不适用该约定但仍受本项约束。

### 8.2 红线 6 — JS 生命周期 / null 守卫 / TDZ

触发：diff 含任何 `.js`。**Path B 和 Path C 同样要跑**——新 section 带 custom element、迁移改了模块 JS，都会踩这条。

细则完全照 `qa-profile-a.md` 的 A5 执行（四项逐条 + 注册/清理成对证据）。QA-A 已跑过就直接引用其结果，不必重复。

### 8.3 红线 7 — build 产物勿手改

触发：diff 触及 build 输出目录（`shopify-common` 的 dist / 生成的 `design-system.liquid` 等）。**Path A 和 Path B 同样要跑**。

```bash
git -C <theme-root> diff --name-only <BaseHeadSha> | grep -nE '(dist/|design-system\.liquid|\.min\.(js|css)$)'
```

- 命中且源文件未同步改 → `Failed`（手改产物，下次 build 即被覆盖）。
- 命中且源已改 → 确认跑过 `npm run build`、产物与源一致；未跑 → `Failed`（同时会让 `ThemeCheck` 失真，见 `theme-check-gate.md` §1）。
- 无命中 → `NotApplicable`。

---

## 9. StyleHardRuleCheck —— DTC §2.1 硬性 10 条

来源：《DTC 开发交付标准 v1.0》§2.1「硬性（不符合即不合格）」，落在 handoff-schema §5 的 `StyleHardRuleCheck` 字段。

**判定原则（DTC 原文）**：硬性项**逐条可查**；不符合即不合格。任一条 `Failed` → `StyleHardRuleCheck: Failed` → `ReadyForDelivery: No`。

| # | 要求 | 怎么查 |
|---|---|---|
| 1 | **同一页面内左右上下边距一致**，不同 section 间不得有无理由的边距差 | 逐 section 量 `.container` 内边距与 section 上下间距；差异要能指向 schema 存值或 spec 条款 |
| 2 | **同一页面内背景色成体系**，不得无理由色块跳变 | 逐 section 记背景 token；出现非 spec 色或无理由跳变即 `Failed` |
| 3 | **字号层级不得倒置** —— 描述不能比标题大、子标题不能比主标题大 | 量同一区块内标题 / 子标题 / 描述的 computed font-size，逐级递减 |
| 4 | **圆角只用 5 / 10 / 15px，默认 5px** | grep 改动文件里的 `border-radius`；例外只有倒计时 2px、极细装饰线 1px、头像 50%（见 `responsive-and-spacing.md` §3.2） |
| 5 | **不得加粗** —— 仅 Regular 400 / Semibold 600，Semibold 只用于局部强调、不用于标题 | grep `font-weight`；出现 700/`bold`/`.fwb` 即 `Failed`；600 用在标题或大段文字上同样 `Failed`（见 `typography.md` §1） |
| 6 | **不得使用文字渐变（AI 相关除外）、单词局部放大**等装饰效果 | grep `background-clip: text` / `-webkit-text-fill-color` / 单词级 `font-size` 覆盖 |
| 7 | **文字色用规范色值**，深色底禁用灰字 | 逐条比对 `colors-and-schemes.md` §2.1；深底必须用 inverse token，用 `.text-secondary` 压深底即 `Failed` |
| 8 | **移动端**不遮挡、不裁切、不溢出，文字不被固定高度截断 | 375 / 767 两档实测；与 `RegressionMatrix` 共用截图 |
| 9 | **按钮不硬设 height / width**，尺寸落在规范四档内 | 见 §5.1 |
| 10 | **含模块标题的 section 必须提供独立于 PC 的移动端对齐配置** | 查 schema 是否有移动端对齐字段（`header_align_mb` 等），且 Liquid 把它传进 `section-header` snippet |

> ⚠️ 第 10 条查的是**能力**（有没有这个配置项），不是**存值**（某个实例是否已设为左对齐）。逐实例存值属 QA-C 的范畴。

`NotApplicable` 的合法情形：本次改动完全不涉及样式（如纯 JS 逻辑、纯 locale 文案）——须给出适用性证据。

---

## 10. Advisories —— DTC §2.2 软性项（非阻断）

软性项写进 §5 的 `Advisories` 字段，**不影响 `ReadyForDelivery`**。

DTC 原文判定原则：「软性项**只在同页面内部明显不自洽时才提**。」

| 软性项 | 何时提 |
|---|---|
| 字号尽量落在字阶表内 | 同页面同类元素字号不一致时才提；规范未覆盖的场景以同页一致为准 |
| 模块上下间距尽量走全局变量 | 硬编码间距且与同页其它模块不一致时才提 |
| sandbox 与线上环境差异 | 已知差异如实记录；线上配置差异导致的未测出**免责** |

**A11y 的 🔴 待裁决项也进 `Advisories`**，但**只限 `a11y.md` §5.1 那张封闭 allowlist 里的配对**（`#717171` 压 `#F2EFEB` 4.26 / 压 `#F7F5F3` 4.49、`#8F53ED` 压 `#F2EFEB` 3.96、角标 Hot `#FF0000` on `#FCDEDE` 3.17）。色值是设计方给的、矩阵无权改，如实记录并标待裁决，不判 `A11yCheck: Failed`。

> 🔴 **Advisories 不是降级通道，三条闸门：**
>
> 1. **`< 3.0` 一律 `Failed`**，spec 给的也不行 —— 包括角标 Pre Order（`#39F672` on `#D7FDE3` = **1.30**）。3.0 以下不是"略差"，是看不见。
> 2. **不在 allowlist 里的配对一律按常规判定**（`< 4.5` → `Failed`）。allowlist 是封闭表，QA 无权扩充。
> 3. **每条 Advisory 必须带「已知偏差批准引用」**（设计方 / PM 的确认链接）。**批准引用为空 → 该条降级为 `Failed`**。
>
> 硬性 10 条（§9）任何情况下都判 `Failed`，不进 Advisories。

---

## 11. 🟠 可论证放行项的复核（v0.2.1 新增，v0.2.2 收口）

`handoff-schema.md` §8.1 把 #8 / #9(纯新增) 定为 🟠 `EvidenceBased`，#10 未触及的存量默认值定为 🟡。**QA 不是"看到理由就放行"**，按类型走不同复核：

| 类型 | 适用范围 | QA 复核动作 | 判定 |
|---|---|---|---|
| **EvidenceBased** | §8.1 第 8 条（三层入口顺序）、第 9 条纯新增 option | 检查 `OptionsConsidered`（§4 工件）是否给出≥2 方案与取舍、是否引用了 `AssessmentRef` 与 `ActualAffectedInstances`。**不需要任何人"审批"** | 三者齐 → `Passed`（结论里引用出处）；缺任一或只有套话、无影响面引用 → `Blocked`（可补）；证据反而证明上层入口本可用 → `Failed` |
| **ApprovedException** | 🔴 **封闭清单，逐项现读已安装包的 `handoff-schema.md` §8.1「`ApprovedException` 的封闭适用清单」那张表**（v0.2.2 收口：本处**不再复述当前成员**——运行时文档里再抄一份就是第二份适用清单，canonical 一改、QA 仍按旧复述执行）。清单外的条款一律按其当前档位判，`ApprovalRef` 再齐也不改判定 | 逐项核 §4 的 `ApprovedExceptions` **四件事**：① `ApprovalRef` 存在且指向本 ChangeSet 的这一项 ② `ApprovedBy` 是 PLAUD 侧（PM / 设计 / 技术 owner） ③ `Clause` 在封闭清单内 ④ **`ApprovalRef` 的批准内容覆盖得住所填 `Scope`** | 四者齐 → `Passed`；**任一不成立 → `Failed`**（含 `ApprovalRef` 为空、自批、`Clause` 越界、批了一处而 `Scope` 写了一片）；**提供了但核不动**（403 / 权限不足 / 平台故障）→ `Blocked`。结论写进 `ApprovedExceptionsChecked` + `ApprovedExceptionsEvidence` |

🔴 **`Scope` 必须逐对象绑定，聚合写法直接 `Failed`。** A11y 例外要一条一项写「前景色 + 背景色 + 出现实例 + 实测 ratio」；写成"全站所有按钮""所有该色配对""以下若干处"的，QA **不追问、直接 `Failed`** —— 一条批准覆盖一片是这个机制唯一的实质绕过面。

🔴 **两条不可退让：**

1. **agency 自写自批不成立** —— 提供论证的人与批准的人必须不同方。模板化套话（"按现状实现""与设计确认过"无链接）视同为空。
2. **红线不因批准而放行。** 典型误用：本次**新建或修改**的 UX 字段用了不合规默认值，拿到设计方书面批准就想放行 —— **先去现读 §8.1 那张表**；截至本包发布时它不在清单内，因此**不行**。批准链接只能让它进 `BlockingGaps` 记「规范缺口待裁决」，`StyleHardRuleCheck` 仍判 `Failed`；正确处理是先改规范或改默认值再交付。

🔴 **清单只有 canonical 能改，会议纪要不改变本轮判定**（v0.2.2 收口；规则正文唯一在 `handoff-schema.md` §8.1「封闭清单的变更权限」，本处**不复制清单、不复制 owner 规则**，只记 QA 侧的三条动作）：

1. **当前包优先**：QA 判的依据永远是**已安装包**的 §8.1 表。用户/agency 出示双周会纪要说"这条已经同意可以豁免"，而包内清单没有它 → **不采信**，按其当前档位照常判。
2. **不一致就停机**：纪要与包内文本冲突 → 按 `handoff-schema.md` §7 停机报用户（附 `ContractVersion` 与纪要日期），**不擅自选一边**、也不替 canonical 扩容。
3. **待议条款的落点**：`ApprovedExceptions` 该 `[]` 就 `[]`（因此 `ApprovedExceptionsChecked: NotApplicable`，**不是** `Failed`——没声明就没有可判的对象）；阻断由该条款原本的检查字段（`StyleHardRuleCheck` / `A11yCheck` / `CopyConfigurabilityCheck` …）+ `BlockingGaps` 承载，`BlockingGaps` 写固定形态 `PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>`。
   `Advisories` 的措辞**不得**暗示当前红线已失效：写「清单扩容提案尚未进入当前 ContractVersion；本轮仍按当前 §8.1 判定，待议结论不改变本轮的 Failed / Blocked 结果」，**不许**写「本轮不适用」「已与运营达成一致，暂不阻断」。

### 11.1 存量复用豁免的三项核查（`handoff-schema.md` §8.1.2）

实现方声明某偏差属存量豁免时，QA 逐项核，**任一项不成立 → 按新引入判 🔴**：

1. **已存在**：给出证据证明该偏差在 `BaseHeadSha` 上就有（`git show <BaseHeadSha>:<file> | grep …` 之类的可复跑命令）。
2. **未加重**：没有在更多实例 / 更多断点 / 新模板上出现，也没有因本次接入变成新的可达行为（判法见 §7.1 第三种）。
3. **回归未缩小**：`RegressionMatrix` 仍覆盖 `plaud-theme-impact` 的 `ActualAffectedInstances` 全量；**QA-B 的空配置 / 满配置双测不因本条豁免**——新接入的上下文、本次改过的字段与 schema、本次可达的所有路径都要双测。

> 举证责任在实现方。豁免声明没有可复跑证据命令 → 直接按新引入判，不必来回追问。

