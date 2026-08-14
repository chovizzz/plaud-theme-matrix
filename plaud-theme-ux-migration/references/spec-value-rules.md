# Spec 取值规则 — 对照维度、Figma 非 spec 值、跨端冲突

> **数值不在本文件。** 字号 / 颜色 / 间距 / 断点 / 按钮尺寸的**定义**唯一存放在
> `plaud-theme-shared/references/typography.md`、`colors-and-schemes.md`、`responsive-and-spacing.md`。
> 本文件只写**迁移时怎么用这些定义做判定**：查哪些维度、非 spec 值怎么处理、什么时候必须停下问用户。

---

## 1. v1.3 spec 补充修订（源文档评论，2026-07）

以下 4 条是 spec 源文档（`PLAUD_UX_规范基准_v1.3.md`）的最新评论修订，**优先级高于正文旧值**。
数值以 shared reference 为准，本节记录的是**修订带来的选择规则**：

| # | 修订 | 迁移时的判定规则 |
|---|---|---|
| 1 | §6.1 新增【白色按钮】Primary-white | 对应 utility：`.btn-white` **叠** `.btn-primary-{lg/md/sm}` 取尺寸；颜色走该 spec 值，**勿写死其它 hex**。色值见 shared `colors-and-schemes.md` |
| 2 | §7 布局网格：XS 与 Mobile 断点 `.container` 内边距变更（2026-06-15 DTC-399 已落实） | 全站用统一容器的模块**小屏 / 手机端内容区收窄**——迁移这些模块时预期到横向留白变化，不要误判成回归。数值见 shared `responsive-and-spacing.md` |
| 3 | §6.1 按钮尺寸用法 | **Primary-LG 只用在 Banner**；其它按钮一律 **Primary-MD**；仅特殊说明才用 **Primary-SM**。选档按此规则，**不再"就近取档"** |
| 4 | §1.2 字阶：`text-body-md` 的 MB 字号调整 | 用途区分——`text-body-md` 用于**卡片描述 / 辅助说明**，`text-body-lg` 用于**长文阅读 / 正文段落**。对齐正文时**先判断用途再选 md/lg**，不按字号大小挑 |

> **spec 源文档缺失不阻断。** `~/Downloads/PLAUD_UX_规范基准_v1.3.md` 若本地不存在，本文件 + `pitfalls-*.md` + shared 的视觉 reference 已充分操作化该 spec，可直接据此执行。

---

## 2. 模块审计顺序

### 2.1 读模块代码

- `sections/<module>.liquid` — 主模板 + schema
- `snippets/<module>-*.liquid` — 子片段（如果有）
- 对应的 `assets/*.css` 或 `shopify-common/sections-*/<module>/style.scss`
- 对应的 `assets/*.js` 或 `shopify-common/sections-*/<module>/index.js`

### 2.2 读模板实例存值

- 找出本轮目标模板里所有该模块的实例（搜索 `"type": "<module>"`）
- 列出每个实例的配置值与 spec 的偏差

> 实例总数 / 启用数 / disabled 数**取自 `AssessmentRef`**，不在这里重新数一遍（见 SKILL.md「与 impact 的分工」）。本步读的是**每个实例的具体配置值**，用于判定偏差，不是用于算影响面。

### 2.3 对照 spec 找偏离（引用关系表，非数值表）

| 维度 | 对照什么 | 判定要点 |
|---|---|---|
| 字号 | §1.2 `text-*` token | **PC / MB 双档**；不在档时先判断是"PC/MB 跨档"还是"Figma 自定"，再走 §3 |
| 字重 | §1.1 **Regular 400 默认 + Semibold 600 仅局部强调**（不用于标题、不可大面积；2026-08-11 基线放开，落地前须核字体资源，见 shared `typography.md` §1） | admin 字段值 `subheading_weight` 解析为 **500 —— 500 仍不是合法字重，迁移归 400**，不得借 600 放开为由保留；`body_weight` 解析为 400。**改字重会改 class 名**，注意 §4.12.1 的渐变失配坑 |
| 颜色 | §2.1 brand / §2.2 highlight / §2.3 label / §2.4 background / §2.5 separator | 走 token / utility 类，不写死 hex（例外见 `pitfalls-shared-scope.md` §4.6） |
| 间距 | §3.1 `--space-N`（N = 1/2/4/6/8/10/14）；模块间间距走 V1.1 `--section-space` | utility 类为 `.pad-*` / `.mar-*-*` / `.gap-sp-*` |
| 圆角 | §4 `radius-base` / `-lg` / `-xl` | utility 类 `.radius-*` |
| 按钮 | §6.1 六个变体：Primary-Dark / -Purple / -Green / -Cyan / -White / Secondary-Outline（1px `#717171` 边框）；§3.2 padding 档；四档高度走 `min-block-size` | 变体色值见 shared `colors-and-schemes.md` §3.1（**没有 `Primary-Light` 这个变体**，旧文档写过，已废）。尺寸选档按 §1 第 3 条：**LG 只 Banner / 其它 MD / 特殊 SM** |
| 断点 | §7 精度 `.98` | 一律 `.98` 精度，杂散整数断点见 `pitfalls-components.md` §4.11 |
| 区头 | `cs-section-header` 统一渲染，PC / MB 双档（spec large-title-2，v1.3 wave 已对齐） | 间距与对齐坑见 `pitfalls-components.md` §4.13 |

---

## 3. Figma 值不在 spec 阶梯 / 跨端冲突时的取值（§2.4）

Figma 常给非 spec 阶梯的值（间距 15 / 28 / 12、字号 18 等），或 PC / MB 落在不同 token 档。

### 3.1 非 spec 值 → 三种处理（按场景选）

**① 有近邻 token、明显更近某档 → 就近 snap**（默认口径，保住 token 体系）

- 只在**明显更近某一档**时才 snap
- 日志标 ±px delta
- 🔴 **等距两可必须问用户，不得擅自 snap**：两侧 delta 相等时（如 20 介于 16 / 24 之间、48 介于 40 / 56 之间、12 介于 8 / 16 之间、28 介于 24 / 32 之间）→ **停机问用户选哪档**。这是 `handoff-schema.md` §7 明列的停机点，不是可以"取常见值"的地方。

**② Figma 明确、无近邻 token、视觉重要 → 可用字面 px 贴 Figma**

- 这会引入非 token 硬编码（如 estimator 移动端 `gap:12px` / `py:12px`）
- **须先与用户进一步确认再执行**，不擅自硬编码

**③ 为适配固定尺寸算出的值 → 用计算值**

- 例：固定高 40、字 14 → 居中 padding `(40-14)/2 = 13px`
- **前提是该固定尺寸本身已作为例外经确认**（全路径红线 §8-2「禁写死组件宽高」）
- 这类计算值改完**主动提醒用户复核**

### 3.2 跨端 token 冲突 → 根据 M 端选择 token（选档前先经用户决策）

Figma 常给「PC 降一档」的字号（PC/MB = 16/14、24/18、14/12），而 token 的响应式曲线不一定匹配（某些 token 两端同值、某些两端不同）。

- 默认**取 M 端命中的档**（M 值优先匹配 Figma），但**选哪档须先与用户确认再改**，不擅自定 token
- PC 端接受 ±delta；PC 偏差不可接受时加 **PC 专属覆盖**（媒体查询）
- 两端都要严格贴 Figma 且**无单一 token 同时命中** → PC 用 token、**M 端保留 `rem` 覆盖贴 Figma**（如 cart prices、subtotal 两档）
- 日志标 **M ✓ 与 PC 的 ±delta**

---

## 4. 修改入口选择（三层定位）

| 层 | 适用场景 | 风险 |
|---|---|---|
| **模板存值**（JSON 实例值） | 本轮目标模板的针对性优化；blast radius 小 | 低 — 仅影响该模板 |
| **schema 配置**（section liquid 内 schema 定义） | 模块自带约束阻挡 spec 值（step / min / max / 默认） | 中 — 影响该模块所有**新建**实例；旧值需向后兼容 |
| **模块代码**（liquid / SCSS / JS） | 偏离是模块自身实现导致，需根本性修复 | 高 — 影响该模块**所有现存实例** |

**优先级：模板存值 > schema > 模块代码**（除非用户明确要求）。

> 🔴 这条优先级是「**当某处改动已获授权时，选哪一层落地**」——
> **不是**做出改动的授权本身。`templates/*.json` 默认只读，只有经用户明确批准、或有 stored-值阻断等文档化例外时才动模板存值（见 `hard-rules.md` §2.1）。

### 4.1 用量 → 推荐入口（启发式，输入数据来自 `AssessmentRef`）

| 模块用量 | 推荐入口 |
|---|---|
| 1 个模板专用 | 模块代码直接锁 spec 值 |
| 2–10 个模板 | 模块代码（utility class + token），逐模板回归 |
| 10–50 个模板 | 模块 schema 放宽约束 + 模板实例值审计（**不动模板存值**，除非用户明确要求） |
| 50+ 个模板 / 全站 | 只动 schema + **仅本轮目标模板**的实例值（动实例值需用户明确批准）；其它模板挂「待评估」 |

「模板用量 / 实例数」这一列的数字**来自 `plaud-theme-impact` 的 `TheoreticalReferences` / `ActiveInstances` / `DisabledInstances`**。
本 skill **不重跑 blast radius grep**——两边各 grep 一遍会产生两个口径，`ChangeSetId` 与 `AssessmentRef` 就对不上了。
拿不到 `AssessmentRef` 且不满足 `InlineLite` 豁免 → **停机**，回 Assess 阶段。
