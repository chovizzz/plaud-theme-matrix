# QA-Global — 恒执行七项（可执行步骤）

与路径无关，每次 QA 都跑。

**阈值一律现读 `plaud-theme-shared/references/` 的当前值，本文件不复制数值**——对比度下限读 `a11y.md`、图片 DPI 倍率与 width 取值规则读 `media-quality.md`、断点与间距读 `responsive-and-spacing.md`、字阶读 `typography.md`。复制会产生第二个事实源，spec 一升级就漂移。

（唯一的例外是 `BreakpointsCovered` 的五档取值——它由 handoff-schema §5 字段说明直接规定，属于契约本身，不是视觉 reference 的数值。）

每项输出 `Passed` / `Failed` / `Blocked` / `NotApplicable` + 证据。证据为空 → 降级 `Blocked`。

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

```bash
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*(width|height)[[:space:]]*:[[:space:]]*[0-9]+(px|rem|%)'
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*(width|height)="[0-9]+"'
```

对每条命中做**三选一**裁定，逐条写进证据：

- 属 shared 红线 2 列出的允许例外（图标 / 1px 线 / 明确固定的技术容器 / Swiper cube·vertical 要求的固定 px height）→ 记为豁免 + 引用哪条例外。
- 实现工件（§4 `OptionsConsidered` 或正文）里已说明理由 → 引用那段说明。
- 两者都没有 → `FixedDimensionCheck: Failed`，列出文件:行号。

**注意 `<img width height>` 属性是防 CLS 必需，不属于本项违规**（那是第 6 项的范畴）。

---

## 6. ImageQualityCheck

红线：`image_url` 的 `width:` **只**用于防 CLS / 适配容器，须按容器实际显示宽度 × 高 DPI 取值；禁止用过小 width 把展示图下采样糊掉（shared 红线 3）。**具体倍率与取值规则现读 `plaud-theme-shared/references/media-quality.md`，不要凭记忆用数字。**

### 触发条件（两类，缺一会漏报）

只 grep `image_url` 是不够的：**图片请求宽度没变、但容器变宽了，图片立刻欠采样。** 两类都要查：

```bash
# (1) 图片请求本身变了
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*(image_url|srcset|sizes=)'

# (2) 图片的显示容器变了
#     两个要点：① 同时看 + 和 - 两侧（**删掉**一条声明同样会让容器变宽）
#              ② 不只是 width/grid —— padding / gap / inline-size / 容器类替换
#                 都会改变图片的实际显示宽度
git diff HEAD -U0 -- <ModifiedFiles> \
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
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE "^\+.*[|][[:space:]]*default[[:space:]]*:[[:space:]]*['\"]"
# 硬编码展示文案。三类都要抓：
#   (a) 标签之间的文本节点（含中文、德语变音符等非 ASCII，所以用"非标签非 Liquid 字符"取反匹配）
#   (b) JS 里直接写进 DOM 的字面量
#   (c) Liquid assign / capture 出来的展示字符串
git diff HEAD -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*>[^<>{}\"']*[^[:space:]<>{}\"'][^<>{}\"']*<"
git diff HEAD -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*(textContent|innerHTML|innerText|placeholder|aria-label|title)[[:space:]]*=[[:space:]]*['\"]"
git diff HEAD -U0 -- <ModifiedFiles> \
  | grep -nE "^\+.*\{%-?[[:space:]]*(assign|capture)[[:space:]].*['\"][^'\"]{3,}['\"]"
# 空壳 DOM 风险：新增的展示标签是否有 != blank 守卫
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*<(h[1-6]|p|a|img)\b'
```

裁定：

- `| default: '文案'` 命中 → `Failed`（`| default:` 后接数字、token、非展示值不算）。
- 展示文案字面量写死在 liquid / js → `Failed`。
- 新增展示标签外层没有 `!= blank` 守卫 → `Failed`（会出 `<h2></h2>` 空壳）。
- schema `default` 字段里写英文占位 → **合法**，不是违规（运营可在 theme editor 改）。
- schema 的 `label` / `info` / `content` 直接写英文、不用 `t:` 前缀 → **合法**。

改动不含任何展示文案 → `NotApplicable` + 理由。

---

## 8. 附加触发式检查（补 §5 profile 表的红线空隙）

§5 的 QA-Global 七项没有覆盖 shared 红线 4 / 6 / 7，而这三条原本只散落在单个 profile 里——换条路径就漏检。以下三项**与路径无关**，触发即查，结果写进 `ProfileSpecificResults`（**不新增 yaml 字段**）。

### 8.1 红线 4 — 颜色走 token / CSS 变量

触发：diff 含 `.css` / `.scss` / Liquid 内联 `<style>` / inline `style=`。

```bash
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*#[0-9a-fA-F]{3,8}\b'
git diff HEAD -U0 -- <ModifiedFiles> | grep -nE '^\+.*(rgba?|hsla?)\('
```

逐条裁定：走 `var(--token)` → 合规；写死 hex / rgb 且不属于 `colors-and-schemes.md` 已文档化的例外（设计系统固定渐变资产等）→ `Failed`。Path C 另有"新 hex 必须大写"的约定（见 `qa-profile-c.md` C4 §4.2），Path A/B 不适用该约定但仍受本项约束。

### 8.2 红线 6 — JS 生命周期 / null 守卫 / TDZ

触发：diff 含任何 `.js`。**Path B 和 Path C 同样要跑**——新 section 带 custom element、迁移改了模块 JS，都会踩这条。

细则完全照 `qa-profile-a.md` 的 A5 执行（四项逐条 + 注册/清理成对证据）。QA-A 已跑过就直接引用其结果，不必重复。

### 8.3 红线 7 — build 产物勿手改

触发：diff 触及 build 输出目录（`shopify-common` 的 dist / 生成的 `design-system.liquid` 等）。**Path A 和 Path B 同样要跑**。

```bash
git diff --name-only HEAD | grep -nE '(dist/|design-system\.liquid|\.min\.(js|css)$)'
```

- 命中且源文件未同步改 → `Failed`（手改产物，下次 build 即被覆盖）。
- 命中且源已改 → 确认跑过 `npm run build`、产物与源一致；未跑 → `Failed`（同时会让 `ThemeCheck` 失真，见 `theme-check-gate.md` §1）。
- 无命中 → `NotApplicable`。
