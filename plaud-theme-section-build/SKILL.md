---
name: plaud-theme-section-build
description: >
  PLAUD 主题矩阵 Path B 的 Implement 阶段（order 4）：把 Figma 设计稿按 vendor 规范实现成 sa- 前缀 section。
  触发："按设计稿做模块""按稿搭模块""设计还原/切图还原""Figma 转 Shopify""Figma link/node"
  "新建 sa- 开头的 section""做个 SA: 模块""Section AI""新增主题编辑器模块"；
  在新建 sa- section 语境下也覆盖 vendor §8 文案配置 / §9 按钮 / §10 价格 / §11 轮播 怎么写、
  schema label 要不要 t:、能不能自创按钮类名、运营素材能不能放 assets、设计稿数值在 spec 阶梯上两可取哪档。
  产出 sa- 前缀 section/snippet/CSS + SA: schema + BEM 根类名，container 与 section_top_pc/section_bottom_pc 间距，
  同时加 gradient 与动态 color- 类，复用 section-header，三层响应式变量，素材走 schema 不写死 assets，空/满配置双测。
  开工前须消费 plaud-theme-impact 的 IntegrationSurface 评估；写入任何存量文件（或新增文件被存量机制自动消费）
  即升级 LegacyImpact 回 impact 重评。设计稿值等距两可或无近邻 token 时停机问用户。
  不做验收、不判定可交付（唯 plaud-theme-qa 有权），恒输出 ReadyForDelivery 为 No。
  不用于改已有 section、bug、性能、无 Figma 上下文的新功能（走 plaud-theme-dev）；
  不用于 UX Spec v1.3 迁移与刷模块（走 plaud-theme-ux-migration）；
  B+C 交叉（新建 sa- 且要对齐 v1.3）单一 ChangeSet 装得下就直接用本 skill，只有需拆出第二个
  可独立验收 ChangeSet 时才走 plaud-theme-orchestrator；
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Section Build（Path B · Implement）

**开工前必读**：`plaud-theme-shared/SKILL.md` + `plaud-theme-shared/references/handoff-schema.md`（尤其 §1 交付权、§4 本 skill 的产出契约、§7 停机、§8 全路径红线）。

视觉与 UX 数值（字号 / 字重 / 颜色 / 间距 / 断点 / 弧角 / 容器宽度）**全部在 `plaud-theme-shared/references/`**——本 skill 只引用文件名，**一个数值都不复制**。复制会造出第二个事实源，spec 一升级必然漂移。

## 本 skill 做什么

把设计稿变成一个**符合 PLAUD vendor 规范、运营可配置、多语种安全**的新 section：

- 强制命名（`sa-*` 文件 / `SA:` schema / BEM 根类名）
- 结构骨架（`container`、Section Space schema、`gradient` + `color-{scheme}`、`section-header` 复用、anchor id）
- vendor §8 文案 / §9 按钮 / §10 价格 / §11 轮播 合规
- 媒体资源不写死进 `assets/`
- 三层响应式变量策略
- 空配置与满配置双测 + 英译德长文案自检

## 本 skill 不做什么

- **不改已有 section / snippet 的功能**——那是 `plaud-theme-dev`（Path A）
- **不做独立的 UX Spec v1.3 迁移 / 刷模块 / 对齐 spec**——那是 `plaud-theme-ux-migration`（Path C）

> **B+C 交叉的路由（与 `MATRIX.md` / orchestrator 一致）**：Figma 新建**同时**明确要求对齐 v1.3 spec 时——
> **单一 ChangeSet 能装下的 B+C 直接由本 skill 实现**（实现规则用 Path B 的、spec 取值用 Path C 的，`RequiredQAProfile` 取 `QA-B, QA-C`），**不绕 orchestrator**。
> 只有当这项工作还需要**拆出第二个可独立验收的 ChangeSet**（例如新建 section 之外还要刷一批存量模块 / 跨多模板的迁移 wave）时，才先走 `plaud-theme-orchestrator` 编排，由它调用本 skill 做其中的 B 部分。
> 判据是「**要不要拆成 ≥2 个可独立验收的 ChangeSet**」，不是「有没有跨路径」——后者会让每个 B+C 都无谓地绕一圈。
- **不做验收、不判定可交付**——`ReadyForDelivery` 恒为 `No`，只有 `plaud-theme-qa` 能给 `Yes`
- **不自己做影响面评估**——上游是 `plaud-theme-impact`
- **不擅自决定 Figma 值落哪一档**（见「停机点」）

---

## 上游：消费 Assess 工件

开工前必须拿到 `plaud-theme-impact` 的产出（`handoff-schema.md` §3），把 `AssessmentRef` 抄进自己的输出。

Path B 的常态是 **`ReconMode: IntegrationSurface`**——纯新建，无存量调用方，查的是**复用面与冲突面**：

- 可复用的 snippet：`section-header` / `section-swiper` / `price-format` 等，是否已覆盖需求
- `sa-<feature>` 文件名、BEM 根类名、CSS 变量前缀是否与既有模块冲突
- 素材是否会误入 `assets/`
- schema / locales / 数据源是否完整
- bundle 加载方式（`stylesheet_tag` 放哪、会不会进循环）
- 是否需要接入模板或 section group

`IntegrationSurface` 下 `TheoreticalReferences` 应是 `0 (new module, no existing callers)`——**不要为新建 section 伪造"模板使用量 N"**。

拿不到 Assess 工件 → 停机要它。`InlineLite` 豁免对 Path B 基本不成立（新建 section 至少涉及 schema）。

### 🔴 升级为 LegacyImpact 的触发条件（必须回 impact 重评）

> **只要本次改动以任何方式写入（修改 / 删除 / 重命名 / 移动）了任何一个存量文件，模式立刻从 `IntegrationSurface` 升级为 `LegacyImpact`——哪怕主体工作是新建一个 `sa-*` section。**

**判定门是「有没有写入存量文件」，不是「能不能找到调用方」。** 静态引用数只用于**算影响面**（Assess 的事情），**不是**是否升级的门——「我 grep 不到别人用它」不构成不升级的理由（动态引用、bundle 自动打包、约定式加载都 grep 不到）。

具体触发清单，命中**任意一条**即升级：

| 触发 | 例子 |
|---|---|
| 写入任何既有 snippet | `section-header.liquid`、`section-swiper.liquid`、`price-format.liquid`、`product-item.liquid`、`critical-style.liquid`，以及任何已在仓库里的 snippet |
| 写入全局 CSS | `critical.css`、`theme.css`、`base_more*.css`、design-system 类样式表 |
| 写入 design token / 全局 CSS 变量 | 新增或修改 `--color-*` / `--space-*` / `--text-*` / `--btn-*` |
| 动了配色方案 | 新增 color scheme 或改全局颜色变量（本来就禁止，须先经确认） |
| 写入 build 产物或其源 | `shopify-common/src/**`、`snippets/design-system.liquid`、`assets/*.min.css` |
| 写入既有 section / 既有 schema 字段 | 为了接入新模块顺手改了别的 section |
| 写入 `templates/*.json` / `sections/*.json`（section group） | 把新 section 接进模板或 section group；模板存值默认只读，另需用户授权 |
| 写入 `layout/` / `config/` | `theme.liquid`、`settings_schema.json`、`settings_data.json` |
| 写入 `locales/*.json` 的既有 key | 改 / 删 / 移动 / 覆盖既有 key 一律升级。**唯一不升级的情形**：只新增本模块独立 namespace 下的全新 key，且与既有 key 无同名碰撞（须用 grep 证明） |
| 新增文件但被存量机制自动消费 | 新 CSS/JS 被全局 bundle、manifest、约定式 loader 自动打包或自动加载——文件状态是 `A`，传播面却已存在，同样升级 |

**判定命令**。**开工前先存 baseline，收尾时只判定"本 ChangeSet 新产生的"变化**——工作树里开工前就存在的无关改动，既不吸收进 `ModifiedFiles`，也不单独导致本任务升级。

```bash
# ① 开工前：记录 baseline（用 mktemp，避免并行任务互相覆盖）
BASE=$(mktemp -t sb-baseline)
git diff --name-status HEAD > "$BASE"
git status --porcelain >> "$BASE"

# ② 收尾时：相对 HEAD 的完整状态（含已暂存），这是主判据
git diff --name-status HEAD

# ③ 只看存量文件的写入：排除相对 HEAD 全新的文件（A）
git diff --name-status --diff-filter=MDRCTU HEAD

# ④ 与 baseline 比对，得出「本 ChangeSet 新产生的」那部分
diff <(git diff --name-status HEAD) "$BASE"
```

> 🛑 **baseline 已脏且与本任务路径重叠 → 停机。** name-status 只给"文件是否被改"，给不出"是谁改的"：某文件在 baseline 里已经是 `M`，收尾时仍是 `M`，diff 看不出本 ChangeSet 又动过它。**只要本任务需要写入的任何文件在 baseline 里已经是脏的，就停下要求先隔离**（stash / 单独 worktree / 先提交无关改动），不要在混合工作树上继续——`ModifiedFiles` 会被污染，QA 的 `ChangeSetIdMatched` 必失配。

- ③ 的输出**扣除 baseline 已有项后为空**，且新增文件不被任何存量机制自动消费 → 保持 `IntegrationSurface`
- ③ 出现 `M`（修改）/ `D`（删除）/ `R`（重命名）/ `C`（复制）/ `T`（类型变更）/ `U`（冲突）中任意一种 → **停止实现，回 `plaud-theme-impact` 以 `LegacyImpact` 重评**被写入的存量文件；新建部分的复用面/冲突面检查照做，**两套都要报**
- **不要用 `git status --porcelain` 的双状态列做判据**：`AM` 表示"新增后又有未暂存修改"，相对 `HEAD` 仍是全新文件，按 porcelain 首列过滤会把它误判成存量改动。判存量与否一律以 ③（相对 `HEAD` 的 `--diff-filter`）为准。
- 拿不准（不确定有没有调用方、不确定是否被自动打包、不确定 locale key 有无碰撞）→ 按 `LegacyImpact` 处理（**保守方向永远是升级，不是降级**）

升级的连带后果，一并执行：

1. `ReconMode` 改为 `LegacyImpact`，`AssessmentRef` 换成重评后的新工件编号
2. `RequiredQAProfile` 变为 **`QA-A, QA-B`**（`QA-A` 覆盖依赖树回归与旧 section 连带影响）。🔴 **不写 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进本字段是字段越界（§9.2）
3. 若被改的是 `shopify-common/src/**` → `BuildRequired: Yes`
4. 在 handoff 正文单列"存量文件改动"一段，逐个文件写清改了什么、为什么新建 section 需要它

> **反模式**：为了"不触发升级"而把本该改共享 snippet 的逻辑复制一份到 `sa-*` 里。复制 snippet 是更坏的结果（分叉 + 双事实源）。正确做法是升级重评，不是绕开。

---

## 强制命名

| 层级 | 规则 | 示例 |
|---|---|---|
| Section 文件 | `sections/sa-<feature>.liquid` | `sections/sa-shop-banner.liquid` |
| Snippet 文件 | `snippets/sa-<feature>-<part>.liquid` | `snippets/sa-shop-banner-card.liquid` |
| CSS 文件 | `assets/sa-<feature>.css` | `assets/sa-shop-banner.css` |
| Schema name / preset | `"name": "SA: <Feature>"` | `"name": "SA: Shop Banner"` |
| BEM 根类名 | `sa-<feature>` | `<div class="sa-shop-banner">` |
| CSS 变量前缀 | `--sa-<feature>-*` | `--sa-shop-banner-gap` |

`<feature>` 小写 kebab-case，**五处同一个串**。子元素 `sa-<feature>__<el>`，修饰符 `sa-<feature>--<mod>`。

---

## 结构骨架（要点，细节见 reference）

```liquid
{{ 'sa-<feature>.css' | asset_url | stylesheet_tag }}

<div id="{{ section.settings.anchor_id_for_category | handle }}"
     class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
  <div class="sa-<feature> gradient color-{{ section.settings.color_scheme }}">
    {%- render 'section-header',
        pre_heading: section.settings.pre_heading,
        heading:     section.settings.heading,
        sub_heading: section.settings.sub_heading -%}
    …
  </div>
</div>
```

- **内容区用 `container`**（少数全宽模块例外，须说明理由）；不重写 `.container` 的宽度/内边距
- **上下间距走 `section_top_pc` / `section_bottom_pc` schema**，CSS 里不为 section 硬编码 `margin-top` / `margin-bottom`；option 的 `value` 不得改
- **需切换背景/文字色时，`gradient` 和 `color-{{ ….color_scheme }}` 两个类必须同时出现**，缺一不可
- **标题复用 `section-header`**，`pre_heading` / `heading` / `sub_heading` 一律 `textarea`
- **`anchor_id_for_category` 挂在 `.container` 同层**
- `stylesheet_tag` 在 section 顶层输出一次，**绝不进 block 循环**
- section 内 `<style>` 只输出 CSS 自定义属性，不写规则集

完整骨架、schema 片段、CSS/JS 挂载与 schema 完整性要求 → `references/naming-and-structure.md`

---

## 媒体资源红线（高发漏项）

> **新增 section 不得把内容图片 / 视频 / icon 写死为 `{{ 'xxx' | asset_url }}`，也不得新增 `assets/*.png|jpg|svg|mp4` 作为内容素材。**

运营可配置素材一律走 schema（`image_picker` / `video` / `url`）或产品 / metaobject 数据源。`assets/` **只放 CSS / JS 与确认全站固定的技术资源**；例外须**需求明确并经用户确认**，并在 handoff 正文写明理由——不得自行决定。

```bash
git status --porcelain assets/ | grep -iE '\.(png|jpe?g|webp|svg|mp4|webm|gif)$'   # 应为空
grep -nE "asset_url" sections/sa-<feature>.liquid                                   # 只应命中自己的 css/js
```

`image_url` 必须带 `width:`，按容器实际显示宽度 × 高 DPI 取值，**不得用过小 width 把展示图下采样糊掉**（图片清晰度红线，见 shared `media-quality.md`）。

---

## vendor 合规速查（§8–§11 是外包交付最高发的问题）

完整条文、代码示例与自检命令 → `references/vendor-compliance.md`

**§8 文案**
- 禁止在 Liquid / JS 硬编码任何展示文案；走 schema 字段或 locales `| t`
- 禁止 `| default: '...'` 兜底展示文案（运营清空后会留下无法翻译的英文）
- `blank` 时不输出 DOM，禁止 `<h2></h2>` / `<a href="#"></a>` / 空 `<img>` 空壳
- schema 的 `label` / `info` / `content` / option `label` **直接写英文，不用 `t:` 前缀**
- 配置文案必须完整显示：禁 `overflow:hidden`+固定高、`text-overflow:ellipsis`、`-webkit-line-clamp`、`white-space:nowrap`（价格单元除外）；折叠组件是例外且**必须有展开方式**；卡片网格用 `align-items:stretch` + `min-height`，不固定 `height`
- 不得在代码里判断语言后切换字面量

**§9 按钮**
- 只用 `btn-primary` / `btn-outline` / `btn-white` 三个基础类，**禁止自创按钮类名**
- 尺寸叠**纯尺寸类** `btn-primary-{lg|md|sm}`：**LG 只用 Banner，其它一律 MD，仅特殊说明才 SM**
- **禁止固定 `width` / `height`**，只允许 `min-width` / `min-height`，尺寸由 padding 撑开；同组对齐用 flex
- 特殊定制**只覆盖颜色 CSS 变量**；直接写色值须设计明确要求并经确认；尺寸不在此自定义

**§10 价格**
- Liquid 走 `{%- render 'price-format', price: … -%}`
- 外层 `price-wrap` + `white-space: nowrap`；原价/划线价/折扣价并排时**每个单元各自加**，不整体包一层
- 禁硬编码货币符号（`$` `€` `¥`）与价格数字，禁在 settings 里填价格
- 数据源优先 product / variant；JS 动态渲染用 `Shopify.formatMoney`，不自写格式化函数

**§11 Swiper**
- 统一 `{%- render 'section-swiper', class: '…', style: '' -%}`
- **禁止在 section 内重写** `.swiper-button-prev` / `.swiper-button-next` / `.swiper-pagination` 的视觉样式
- 位置调整走 `class` 参数（`justify-*` / `mt-*`），**不复制 snippet 再改**
- effect 约束见 shared `javascript-swiper.md`；轮播按钮须语义 `button` + `aria-label`

---

## 响应式三层变量策略

**端变量 `--sa-xxx-m` / `--sa-xxx-pc` → 运行变量 `--sa-xxx` → 属性只读运行变量。**

- 断点内**只改变量映射**，media query 里不出现字面 px
- 属性声明只读运行变量，读端变量就是越层
- mobile-first：默认样式即移动端，grid 从 1 列起
- 端变量取值绑 spec token（`var(--space-*)` / `var(--text-*)`），不是裸 px
- 组件宽高同理：流式宽度 / `min-*` / `max-*` / `aspect-ratio` / 变量映射；例外仅限 `plaud-theme-shared/references/handoff-schema.md` §8.2 列明的几类（细线、图标、明确固定的技术容器、Swiper 特定 effect 要求的固定 height），且须说明原因

完整写法示例 → `references/figma-workflow.md`（末节）；断点与间距档值 → shared `responsive-and-spacing.md`

---

## Figma 工作流（六步）

| 步 | 做什么 |
|---|---|
| 1 | **读稿** → 拆 grid / blocks / settings，同时产出「素材清单」（每张图的来源） |
| 2 | **映射数据** → settings / blocks；按钮永远 label + link 两字段；必带 anchor id、Section Space、presets |
| 3 | **写 Liquid** → `stylesheet_tag`（不进循环）、`section-header`、`image_url` + `width`、逐字段 `!= blank` |
| 4 | **写 Schema** → `+ Heading` / 业务字段 / `color_scheme` / anchor id / `+ Section Space` / presets `SA:` |
| 5 | **写 CSS** → mobile-first、三层端变量、不重写 container/按钮/swiper 视觉 |
| 6 | **自检** → **空配置与满配置双测**、英译德长文案、多语种、逐断点、vendor Checklist |

第 6 步的**双测不是可选项**：只测满配置是最常见漏项，运营上线时字段往往是半空的。

详细步骤 → `references/figma-workflow.md`

---

## 停机点（Stop, don't guess）

任一成立 → 写 `BlockingGaps`，说清**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"。

### Figma 值不在 spec 阶梯上

```
Figma 值 v，spec 阶梯 …a < v < b…
  ├─ v 明显更接近某一档              → 就近 snap，并在正文注明「Figma v → spec X（snap）」
  ├─ v 与两档等距/接近等距
  │   （示例见 shared handoff-schema §7）  → 🛑 停机问用户选哪一档，不得擅自定
  └─ 无近邻 token 且视觉重要          → 🛑 先与用户确认，确认后方可用字面 px，并标注为已确认例外
```

**"等距两可"必须停。** 自行择一不会报错、QA 也未必看得出，但会让整站阶梯逐渐失真——这是 Path B 最隐蔽的偏差来源。就近 snap 也要留痕，让 QA 能复算。

### 其它停机点

- 拿不到 `plaud-theme-impact` 的 Assess 工件
- 设计稿信息不足（缺某断点稿、缺状态稿、缺空态定义）
- 素材来源无法确定，或确需放进 `assets/` → 要用户确认
- 需要新增 color scheme 或改全局颜色变量 → 要设计/用户确认
- 按钮需要非标尺寸、需要新按钮类名 → 要确认（默认答案是不行）
- 文案需要截断（`line-clamp` 等）→ 要 PM 评审确认 + schema 行数开关
- 需要把新 section 接进 `templates/*.json` → 要授权（模板存值默认只读）
- 发现必须改共享 snippet / 全局 CSS / token → 停下升级为 `LegacyImpact`，回 impact 重评
- 找不到 `section-header` / `section-swiper` / `price-format` 的实际文件 → 要仓库路径

---

## 终态措辞禁令（handoff-schema §1）

> 本 skill **永远无权宣布可交付**。

- 恒输出 `ReadyForDelivery: No` + `QAStatus: NotRun`
- **禁止**使用：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」「没问题了」「改完了可以用」
- **允许**的说法只有：「**改动已就位，待 QA**」
- 自检跑过的项写进正文作为证据，但自检**不等于**通过；Theme Check、admin schema 保存、视觉回归、A11y、多语言由 `plaud-theme-qa` 判定（跑 QA-B，外加它恒执行的 QA-Global——后者**不写进** `RequiredQAProfile`）
- 用户即使明说"不用检查了直接给我"，仍照常输出 `No`，把 `QAStatus` 写成 `Skipped(UserWaived)`，并在正文一句话说明风险由用户承担

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| 命名、容器骨架、Section Space、color_scheme、section-header、素材红线、schema 完整性 | `references/naming-and-structure.md` |
| §8 文案 / §9 按钮 / §10 价格 / §11 轮播 的完整条文与提交前 Checklist | `references/vendor-compliance.md` |
| 六步工作流、三层变量写法、Figma 取值决策 | `references/figma-workflow.md` |
| 与上下游 skill 的交接 | `matrix-contract.md` |

视觉与 UX 数值**不在本 skill**：字号字阶 → shared `typography.md`；颜色 token / 配色方案 → shared `colors-and-schemes.md`；断点 / 间距 / 容器宽度 → shared `responsive-and-spacing.md`；图片清晰度 → shared `media-quality.md`；Liquid/schema 格式 → shared `liquid-schema-format.md`；JS / Swiper → shared `javascript-swiper.md`；无障碍 → shared `a11y.md`。**引用文件名，不复制数值。**

---

## 输出契约

### 交付工件时**当场**生成指纹（`handoff-schema.md` §2）

只绑 `ModifiedFiles` 的**文件名集合**挡不住"交付后偷改"：交出工件之后、QA 开始之前若同一批文件的**内容**又变了，文件集合仍一致，QA 会错判 `ChangeSetIdMatched: Yes`。所以**在写下面这个 yaml 块的那一刻**跑：

```bash
# BaseHeadSha
git rev-parse HEAD

# ChangeSetFingerprint —— 覆盖内容、权限、删除态、未跟踪文件
{
  git rev-parse HEAD
  git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n'
  git diff HEAD --find-renames=false | git hash-object --stdin
  git ls-files --others --exclude-standard -z | tr '\0' '\n' | sort | while read -r f; do
    [ -n "$f" ] && printf '%s %s %s\n' "$f" "$(git hash-object "$f")" "$(ls -l "$f" | cut -c1-10)"
  done
} | shasum -a 256 | cut -d' ' -f1
```

命令原文以 §2 为准。QA 会在**执行任何检查之前**用同一命令重算并精确比对。**生成指纹后不要再动工作树。** Path B 尤其注意：新建的 `sa-*` 文件多为 untracked，上面命令的最后一段就是为它们准备的——漏掉它等于指纹不覆盖本次主体产出。

### HandoffContract

正文可自由组织（文件清单、命名合规、vendor Checklist、响应式说明、取值决策），但**回复的最后必须是一个 `yaml` 代码块**，字段名与顺序与 `handoff-schema.md` §4 一字不差，不得增删改名：

```yaml
ChangeSetId:             # CS-<YYYYMMDD>-B<NN>，例 CS-20260806-B01
BaseHeadSha:             # 交付工件时的 git rev-parse HEAD
ChangeSetFingerprint:    # 见上，交付工件时当场生成
ReadOnlyProof: N/A       # 仅零改动只读任务填写；Path B 恒为 N/A
AssessmentRef:           # 引用 plaud-theme-impact 的 ASMT-<YYYYMMDD>-<NN>
Path: B
ReconMode:               # IntegrationSurface（纯新建常态）｜LegacyImpact（写入了任何存量文件——含 snippet/全局 CSS/token/既有 section/templates/layout/config/locales 既有 key/build 产物，或新增文件被存量机制自动消费——须回 impact 重评）
ModifiedFiles:           # 逐个文件路径 + 一句话改动；必须与工作树一致
RootCause: N/A           # 新建 section 填 N/A
OptionsConsidered:       # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:       # QA-B；升级为 LegacyImpact 时加 QA-A；B+C 交叉时加 QA-C。🔴 不得写 QA-Global——QA 按 §5 恒执行
ThemeCheckRequired:      # Yes | No（新建 .liquid + schema 恒为 Yes）
VisualRegressionRequired: # Yes | No
BuildRequired:           # Yes | No（是否动了 shopify-common/src 需 npm run build）
BlockingGaps:            # 实现中发现但无权处理的（素材来源、模板接入授权、spec 取值二选一…）
QAStatus: NotRun         # 恒为 NotRun
NextRequiredSkill: plaud-theme-qa
ReadyForDelivery: No     # 恒为 No，见 handoff-schema §1
```

> ⚠️ 每个 `key:` 与注释之间**必须有空格**。YAML 里 `Key:# 注释` 是解析错误，照抄时不要压掉那个空格。

`ChangeSetId` 的 `<NN>` 是当日 Path B 的序号，从 `01` 起。`ModifiedFiles` 必须与工作树一致，`ChangeSetFingerprint` / `BaseHeadSha` 必须是交付当刻现算的——任一不符会让 `plaud-theme-qa` 输出 `ChangeSetIdMatched: No` 并停机。

**不得**在这个块里出现 `AssessmentRef` 以外的 Assess 字段（`TheoreticalReferences` / `RiskTier` / `ReadyForImplement`），也不得出现 Verify 阶段字段（`ChangeSetIdMatched` / `ThemeCheck` / 各 `*Check`）。
