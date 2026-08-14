---
name: plaud-theme-ux-migration
description: >
  PLAUD Shopify 主题矩阵的 Path C 实现阶段（order 5）：UX Spec v1.3 迁移。
  用户说"按 UX Spec v1.3 对齐""刷模块""spec 迁移""对齐 ux""对齐规范""这个模块还没迁"
  "字号总览""修改前后对比表""迁移日志""验收后写日志""待评估项""区头对齐""移动端区头左对齐"
  "disabled 实例要不要算""空 pre_heading / subheading""三层入口""模板存值还是 schema 还是模块代码"
  "utility class 还是组件 CSS""FOUC""critical bundle""12 条约定""schema 四件套""配色方案 opt-in"
  "use-color-scheme""Slideshow 换 New Slide""旧版 Multi Content 重建成 WW""token 改成 utility 类"
  "第三方插件字号对齐""blast radius 出来了怎么改"时使用。
  产出：模块审计与 spec 偏差清单、修改入口选择、按 12 条约定 + §4.1–§4.20 踩坑库落地的改动、
  验收后的迁移日志与 memory 状态更新。
  本 skill 不做影响面评估（blast radius / 理论引用 vs 实际受影响 / 依赖树 / 共享传播链归 plaud-theme-impact，
  本 skill 消费其 AssessmentRef，不自行重算），不做验收判定、不判定可交付（归 plaud-theme-qa）、
  不新建 sa-* section（归 plaud-theme-section-build）、不做 bug 修复与性能优化（归 plaud-theme-dev）。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce，
  也不用于只读 UX 规范文档总结、无 Plaud 上下文的泛化 CSS/Liquid review。
---

# PLAUD Theme UX Migration（Path C · Implement 阶段）

**开工前必读**：`plaud-theme-shared/SKILL.md` + `plaud-theme-shared/references/handoff-schema.md`
（尤其 §1 交付权、§3 你消费的 Assess 工件、§4 你的产出契约、§7 停机点、§8 全路径红线）。

视觉数值（字号 / 颜色 / 间距 / 断点）一律引用 shared 的 reference 文件名，**本 skill 不复制任何数值**。

---

## 本 skill 做什么

把「这个模块 / 模板哪里没对上 UX Spec v1.3」变成**已就位的改动 + 可验收的报告**：

- 模块审计：读模块代码 + 实例存值，逐维度对照 spec 找偏差
- 选修改入口（模板存值 / schema / 模块代码）并落地
- 按 12 条约定 + 加载分层 + §4.1–§4.20 踩坑库实施
- 维护项目状态（`memory/模板清单.md` / `模块清单.md` / `全局已知偏差.md`）
- **用户视觉验收通过后**写迁移日志；**完成态标记另需 QA 背书**（见下）

## 本 skill 不做什么

- ❌ **不做影响面评估** —— 见下「与 impact 的分工」
- ❌ **不做验收判定、不输出 `ReadyForDelivery: Yes`** —— 那是 `plaud-theme-qa` 的唯一权限
- ❌ **不新建 `sa-*` section**（`plaud-theme-section-build`）、**不做 bug 修复 / 性能优化**（`plaud-theme-dev`）
- ❌ **不自行批准模板存值编辑** —— `templates/*.json` 默认只读，授权归用户

---

## 🔴 与 `plaud-theme-impact` 的分工（不要两边各 grep 一遍）

| 谁 | 负责什么 | 字段 / 产物 |
|---|---|---|
| **`plaud-theme-impact`** | **实施影响面**：理论引用数、启用实例数、disabled 实例数、逐项核查后的实际受影响清单、共享传播链、依赖树、修改入口候选与风险、RiskTier | `AssessmentRef` 里的 `TheoreticalReferences` / `ActiveInstances` / `DisabledInstances` / `ActualAffectedInstances` / `SharedPropagation` / `LegacyImpact` / `EntrypointCandidates` |
| **本 skill** | **规范偏差审计**：空 heading 与 stored 值核查、逐维度 spec 偏差、三层入口的**最终选择**、本次命中的 20 条踩坑适用项、**日志资格判定**（哪些改动够格进 UX 差异日志） | `RootCause` / `OptionsConsidered` / `ModifiedFiles` + 报告正文 |

**规则**：

1. blast radius / 实例数 / 影响清单**一律引用 `AssessmentRef`**，不重跑 grep 重算 —— 两边各算一遍会产生两个口径，`ChangeSetId` 与 `AssessmentRef` 就对不上了
2. 三层入口**表**（模板存值 / schema / 模块代码 + 各自风险）本 skill 保留，用于**做选择**；但「这个模块有多少实例」这一输入来自 impact
3. **disabled 清单优先取 `AssessmentRef.DisabledInstances`**（含实例 ID 的清单，不只是计数）。`hard-rules.md` 规则 1 的命令在本 skill 是**交叉验证**手段，不是另起一份口径：
   - `AssessmentRef` 给了实例 ID 清单 → 跑一次命令**核对是否一致**；不一致 = 有一方漏看 → **停下核对**，不要各报各的
   - `AssessmentRef` 只给了计数、没给实例 ID → 视为 **Assess 工件不完整**，退回 `plaud-theme-impact` 补，**不在本地补算成自己的清单**
4. 拿不到 `AssessmentRef` 且不满足 `InlineLite` 豁免（条件见 `handoff-schema.md` §3）→ **停机**，回 Assess 阶段

---

## 🔴 开工第一件事：读项目状态文件

```
memory/模板清单.md      — per-template：状态、section 渲染顺序、已迁模块、实例特殊约束
memory/模块清单.md      — per-module：后台名、实例数、迁移状态、schema 约束、关键字段
memory/全局已知偏差.md  — 跨模板共享的待评估项与已修项
```

这三个文件是**项目运行时状态，不在本包内**（写进包会被下次 install 整包覆盖，真实进度丢失）。

> 🔴 **缺失时的处理一律按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表执行——本 skill 只引用，不自行规定。**
> 该表的现行内容：`模板清单.md` / `模块清单.md` / `全局已知偏差.md` 缺失 → **默认停机**，写进 `BlockingGaps`；
> **仅当用户明确确认"这是首次接入、本项目没有历史迁移状态"后**，才可从 `references/memory-seed/` 复制种子初始化，并明确告知这是 2026-07 快照、需人工核对。
> `changeset-log.md`（由 `plaud-theme-qa` 维护，本 skill 只读）缺失时询问用户后可创建空日志。
> 两份措辞不一致时**以 shared 为准**。
>
> 凭空重建的清单看起来完整、实际与真实进度脱节，会把已迁模块重刷一遍（覆盖别人验收过的成果）或把待办记成已迁（漏迁）。
> **一份错的清单比没有清单更危险。** 格式见 `references/project-state-schema.md`。

---

## 零容忍硬规则（摘要；判定以 `references/hard-rules.md` 为准）

1. **`disabled: true` 实例必须跳过** —— 不进字号总览、不进对比表、**不动其 stored 值**（即使偏离 spec）。
   审计前先跑：`grep -B 1 '"disabled": true' templates/<template>.json | grep '"type"'`，清单落 scratchpad 全程 cross-check
2. **stored 值为空的 pre / sub heading 必须跳过** —— 字号总览**只列实际渲染元素**，逐实例查（不是逐模块）：
   `awk '/<module-id>/,/^    \},/' templates/<t>.json | grep -E '"(pre_heading|subheading|sub_heading)":'`
3. **任一条漏看必须立即回溯修正**，不能"等下次一起改"

## 用户硬规则（授权边界，非风格偏好）

- **`templates/*.json` 默认只读** —— 动模板存值需用户**明确批准**；已知受控例外见 `hard-rules.md` §2.1
- **schema setting 已有 option values 永不改** —— 换命名风格也不行；只在 Liquid 端做映射
- **验收前不动迁移日志** —— 指 UX 差异**日志内容**；「进行中 / Owners」协调元数据除外
- **新写 hex 一律大写**；老代码小写 hex 不连动改

---

## 🔴 §4.x 配方的适用前提（一次性总纲，勿逐条读成无条件默认）

`references/pitfalls-*.md` 与 `utility-reference.md` 是**授权迁移中的操作配方** —— 描述「**已获授权时怎么做**」，
**不是做出改动的授权本身**。所有配方一律在 Path C 硬规则之下运行。
凡触及下列硬规则的配方，都是**需同等授权 / 前提的受控例外**，不是默认许可：

1. `templates/*.json` 默认只读，动模板存值需用户明确批准
2. 组件内不写死颜色、不逐元素开 color picker（vendor §3.3 / §3.4），特例见 `pitfalls-shared-scope.md` §4.6
3. 不写死组件宽高（全路径红线 §8-2），特例须经确认
4. 非 spec 值**等距两可时问用户、不擅自 snap**（`spec-value-rules.md` §3.1）
5. schema option values 不改；验收前不写 UX 差异日志内容（「进行中 / Owners」协调元数据除外）

> **配方与某硬规则冲突时，以硬规则 + 其授权 / 前提为准。**

🖼️ **图片清晰度红线**（迁移 delta-accordion / slideshow / multi-content 等展示 section 时必守）：
**不得给图片加清晰度 / 分辨率上限** —— `image_url` 的 `width:` 只防 CLS / 适配容器，按容器实际显示宽度 × 高 DPI 取值，
禁止用过小 `width` 把展示图下采样糊掉（全路径红线 §8-3）。

---

## 工作流

```
读 memory 三文件 + AssessmentRef
   ↓
模块审计（模块代码 + 实例存值 → 逐维度 spec 偏差）
   ↓
选修改入口（模板存值 > schema > 模块代码；动模板存值需授权）
   ↓
按 12 条约定 + 加载分层 + 命中的踩坑条目实施
   ↓
实现侧验证闭环（JSON 校验 / build / 列回归点 / 多文件 diff 并行审查）
   ↓
向用户报告（改动已就位，待 QA）→ 等预览验收
   ↓
用户视觉验收通过 → VisualAcceptance: Accepted，写迁移日志、memory 状态记为「视觉已确认，待 QA」
   ↓
plaud-theme-qa 给出该块 ReadyForIntegration: Yes + 覆盖它的 ReadyForDelivery: Yes 工件存在
且身份三元组未失效 → 才把 memory 里的状态推进为完成态（✅ DONE / 已迁 / 已修）
```

### 🔴 完成态必须由 QA 背书（`plaud-theme-shared/SKILL.md`）

`模板清单.md` / `模块清单.md` / `全局已知偏差.md` 里的完成态标记（`✅ DONE`、`已迁`、`已修`）**只能**在同时满足以下两条时写入：

1. `memory/changeset-log.md` 中存在对应的 `ChangeSetId`，且该块 QA 工件的 `ReadyForIntegration: Yes`，**并且存在一份覆盖它的、`ReadyForDelivery: Yes` 的 QA 工件**（单块直发时就是该块自己那份；多块批次里是那份 `QAScope: Integration` 的集成 QA 工件）
2. 该记录的身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）与当前逐字相等（未失效）
   📎 **v0.3.0 起「别的块把改动落进同一棵工作树」不算失效**：`ChangeSetScopeFingerprint` 只覆盖本块的声明路径；`git add` / `git reset` / commit（含 commit `memory/`）与仓库根 scratch 文件同样不再让它变。真正会让它失效的只有**本块声明范围或可发布面的内容变化**。
   🔴 **`ReadyForDelivery: Yes` 的语义是「这棵被验过的 tree 有资格被后续 release 使用」，不是「可以发了」**——发布门另有一层在 `plaud-theme-release-ops`（shared §2.11）。

> **用户的视觉验收 ≠ QA 通过。** 用户说"看着对了"只能写成 `视觉已确认，待 QA`，**不得**推进为完成态。否则未经验证的代码会被永久记录为"已迁"，后续 agent 把它当事实源，漏检就此固化。

`VisualAcceptance` 与 `QAStatus` 是**两个正交状态**，分开记，不要合并成一个字段：

| 状态 | 取值 | 谁来置 | 位置 |
|---|---|---|---|
| `VisualAcceptance` | `Pending` \| `Accepted` | 用户预览确认 | 迁移状态文件 |
| `QAStatus` | `Pending` \| `Valid` \| `Invalidated` | `plaud-theme-qa` | `memory/changeset-log.md` |

只有 `VisualAcceptance: Accepted` **且** `QAStatus: Valid` 才写完成态。这两个取值集合属于 `handoff-schema.md` §9.2 的 **`memory/` 记录字段**枚举，**不得**出现在本 skill 的阶段契约 yaml 块里（那里的 `QAStatus` 恒为 `NotRun`）。

### 修改入口优先级

**模板存值 > schema > 模块代码**（除非用户明确要求）。

> 🔴 这是「**当某处改动已获授权时，选哪一层落地**」，**不是**做出改动的授权本身。
> `templates/*.json` 默认只读；只有经用户明确批准，或有 stored-值阻断等文档化例外时才动模板存值。

三层各自的适用场景与风险、以及「用量 → 推荐入口」启发式见 `references/spec-value-rules.md` §4。

### 加载分层（FOUC 防治，必查）

| 类型 | 处理 |
|---|---|
| **Universal**（`cs-section-header` / `section-disclaimer` / `.container`，本身在 critical） | **组件 CSS 直接消费 `var(--token)`** |
| **Section-scoped**（async 加载，FAQ / accordion / card 等） | **utility class 挂 HTML**（来自 critical bundle，HTML 解析瞬间生效） |

两个补充：① **不止字号 / 颜色** —— 首屏可见的 padding / 背景 / 圆角 / 间隙同样要走 critical 工具类；
② **动态内容例外** —— richtext / metaobject 渲染出的标签加不了类，只能在组件 CSS 留 token，FOUC 不可避免、属允许的例外。
判断某 bundle 是否 async：看 `layout/theme.liquid` 有无 `media="print" onload="this.media='all'"`。
完整规则见 `references/conventions-12.md`。

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| **每次开工（必读）** | `references/hard-rules.md` — 零容忍 3 条 + 用户硬规则 + 两张检查清单 |
| **每次开工（必读）** | `references/project-state-schema.md` — memory 三文件的格式与缺失时的停机规则 |
| 判 spec 偏差、Figma 值不在阶梯、跨端 token 冲突、选修改入口 | `references/spec-value-rules.md` |
| 改模块结构 / schema 四件套 / 对齐 emit / 加载分层 | `references/conventions-12.md` |
| 查有哪些 utility 类、类在哪个 bundle、怎么验证生效 | `references/utility-reference.md` |
| 写 CSS / 挂工具类 / 行高 / 网格 / margin 冲突 | `references/pitfalls-css.md` |
| 轮播控件 / 区头间距与对齐 / flex 空子块 / product-item 上下文 | `references/pitfalls-components.md` |
| Slideshow 配置层迁移 / 旧版 Multi Content 重建为 WW | `references/pitfalls-migration.md` |
| 改共享 snippet / 全局 CSS / token / build 产物 / 配色方案 / 第三方插件 / 断点精度 | `references/pitfalls-shared-scope.md` |
| 收尾自查、并行 diff 审查、各项验证归谁 | `references/verification-loop.md` |
| **验收通过后**写日志、异常处理 | `references/migration-log.md` |
| 多人并行迁移、模块认领、入职 | `references/team-collaboration.md` |
| 项目首次接入、`memory/` 还是空的 | `references/memory-seed/README.md` |
| 与上下游 skill 的交接 | `matrix-contract.md` |

视觉与 UX 数值在 `plaud-theme-shared/references/`（`typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md`）——
需要时**引用文件名，不复制数值**。

> 🔴 **未读本次命中的踩坑条目就动手 = 停机点**（`handoff-schema.md` §7：「`plaud-theme-ux-migration` 未读取适用的踩坑规则 → 停，先读再改」）。
> 判断"命中哪些条目"看上表的「何时读」列，不要凭印象跳过。

---

## 停机点（Stop, don't guess）

以下任一成立 → `BlockingGaps` 非空，明确写出**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"：

- `memory/模板清单.md` / `模块清单.md` / `全局已知偏差.md` 缺失 → 要文件，**不重建**
- 拿不到 `AssessmentRef` 且不满足 `InlineLite` 豁免 → 回 Assess 阶段
- 需要编辑 `templates/*.json` 存值（含翻 `disabled` / 新建 block / 开 `new_banner_enbale` / 补对齐字段）→ **要授权**
- spec 值**等距两可**（两侧 delta 相等）→ 问用户选哪档，**不擅自 snap**
- Figma 值无近邻 token 且视觉重要 → 确认后再硬编码
- 跨端 token 冲突需选档 → 先与用户确认再改
- 找不到目标 section / snippet 的实际文件 → 要路径
- 需要浏览器预览验证但无法预览 → 标 `Blocked`，**不猜"应该没问题"**
- 本次命中的踩坑条目还没读 → 先读再改

---

## 🔴 终态措辞禁令

`ReadyForDelivery: Yes` 只有 `plaud-theme-qa` 能输出（`handoff-schema.md` §1）。本 skill **恒输出 `No` + `QAStatus: NotRun`**。

**禁用**：「迁移完成」「交付完成」「上线可用」「全部通过」「可以发布」「已验收」「没问题了」「改完了可以用」。

**允许**：「**改动已就位，待 QA**」+「**请前端预览验证 → 验收通过我再写日志**」。

> 用户即使明说"不用检查了直接给我"，仍照常输出 `No` + `QAStatus: Skipped(UserWaived)`，
> 并在正文一句话说明已按用户要求跳过验证、风险由用户承担。

### 模块报告模板（每完成一个模块）

```
### <Module Name> 迁移改动已就位（待 QA）

**Blast Radius**（引自 <AssessmentRef>）：N 模板 / M 启用实例 / K disabled
**Disabled 跳过**：<列表或「无」>
**空值 heading 跳过**：<列表或「无」>
**修改入口**：模板存值 / schema / 模块代码（+ 为什么选这层；动模板存值的注明授权来源）
**命中的踩坑条目**：<§4.x 列表>

**改动文件**：
- <file path>: <一句话改动概述>

**功能链路自查**（实现侧，非 QA 结论）：
- <核心功能 1，如轮播能切 / 手风琴能展开 / 图片真加载 naturalWidth>0 / 按钮可点>：Passed | Blocked | NotApplicable
- <核心功能 2>：Passed | Blocked | NotApplicable

**视觉影响摘要**（按断点列）：
- PC: <变化>
- MB: <变化>

**待评估**（如有）：
- <项>：<原因>（归属：本模块 / 全局）

改动已就位，待 QA。请前端预览验证 → 验收通过我再写日志。
```

> ⚠️ 标题措辞是「**迁移改动已就位（待 QA）**」，不是旧模板里的「迁移完成」——
> 「完成」与交付权冲突，`plaud-theme-qa` 之外任何人都不能宣布完成。

---

## 输出契约

### 交付工件时**当场**生成身份三元组（`handoff-schema.md` §2）

`ChangeSetId` 只绑 `ModifiedFiles` 的**文件名集合**是不够的：交出工件之后、QA 开始之前，如果同一批文件的**内容**又被改过，文件集合仍然一致，QA 会错误地判 `ChangeSetIdMatched: Yes`，验的是一批它从未见过的代码。v0.3.0 起身份是 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` **三元组**（绑不可变 git tree 对象），三个一起才构成身份：`ThemeTreeOid` 单独表达不了声明范围，`ChangeSetScopeFingerprint` 单独表达不了整树，`ObjectFormat` 不比就会把「换了个仓库」误判成「内容变了」。

🔴 **`BaseHeadSha` 是「开工前（写下第一个字节之前）捕获的 baseline commit」，不是「交付工件时的 HEAD」。**
写成后者的实测后果：实现者只要先 commit 再交工件，基准里就已经含本次改动 → 所有声明路径落进 `DECLARED_DIFF_UNCHANGED` → QA 恒阻断，而这与「主题改动 commit 不再让身份失效」直接矛盾。所以**开工第一件事**就是 `git rev-parse HEAD` 并记下来；中途 commit / rebase / checkout **都不改这个值**，事后也不得用当时的 HEAD 覆盖它。
它 v0.3.0 起**不再是失配判据**（不与当前 HEAD 比对），但**仍然 required、且必须是可解析的 commit-ish**：QA 的 `DeclaredDiffCheck`、theme check 的 baseline 物化、以及若干条存量偏差举证都要 `git show <BaseHeadSha>:<file>`。缺失或不可解析时那些检查一律 `Blocked`（**不是 `Advisories`、不是 `N/A`**），`Blocked` 不得折算为 pass → 该轮拿不到交付许可。零改动只读任务填 `N/A`。

因此在**开工前**取 ① ，在**写下面这个 yaml 块的那一刻**（不是改动开始时、不是估算）跑 ②：

```bash
# ① 开工前 —— BaseHeadSha
git rev-parse HEAD

# ② 交付工件那一刻 —— 在**仓库根**跑（先原样复制 §2.5 的整段函数定义）
# 🔴 原样抄这两行，**不要只抄第一行**：旧写法只有 `plaud_theme_tree || echo "..."`，
#    它打印了错误串却让整段 rc=0 —— 任何按 `$?` 分支、或跑在 `set -e` 下的调用方都会
#    认为这道门通过了。判定既要看输出、也要看退出码。
# PATHLIST：本块声明的逐字路径清单，每行一条（= ModifiedFiles 双引号里的字符串）
plaud_theme_tree                  || { echo "THEME_TREE_FAILED"; exit 1; }
plaud_changeset_scope "$PATHLIST" || { echo "SCOPE_FAILED";      exit 1; }
```

`plaud_theme_tree` 输出 `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>`——前两段进工件，**`ThemeTreeDigest` 不进任何工件**（它只用于人读 diff 与跨 object-format 防误判，**不提供抗碰撞**）。`plaud_changeset_scope` 输出 `<ObjectFormat> <ScopeTreeOid> <ScopeDigest>`，`ChangeSetScopeFingerprint` 填**后两段合起来的 `"<ScopeTreeOid> <ScopeDigest>"`**：删除只体现在 `ScopeDigest`，两段必须一起逐字比。三元组一律**逐字原样记录**，不得缩写 oid、不得假定 `sha1`、不得自己重算或换别的命令算。

🔴 **这三个函数的定义不在本文件里，只在 `plaud-theme-shared/references/handoff-schema.md` §2.5。**
去那里**原样复制整段**（含全部 `_plaud_*` 内部函数与全部注释）执行，不要凭记忆敲、不要用任何别处看到的版本、**不要删注释**。

> **为什么这里不再内嵌一份副本**（v0.2.2 删除，v0.3.0 加重）：本节以前抄了一份，附一句"冲突时以 §2 为准"——但那句话拦不住任何人：命令是**可执行**的，抄本一旦落后就会真的算出另一个值。
> 后果不是"多阻断"：producer 算出一个假身份、QA 用 canonical 重算必然失配，正常交付会被永久判 `ChangeSetIdMatched: No`；两边都用同一份旧抄本时，未跟踪文件、被 gitignore 的可发布文件、纯大小写改名可能压根不进身份。
> 🔴 **v0.3.0 起后果还多一档，且严重一个量级**：这几个函数内部会跑 `git add`，而 `git add` 会触发 `post-index-change` hook（实测复现）。canonical 的每一条内部 git 调用都带 `-c core.hooksPath=/dev/null -c core.fsmonitor=false`，clean filter 这个同族入口由**字节保真门在 `git add` 之前**拦下。**一个漏掉 `-c core.hooksPath=/dev/null`、或删掉那道字节保真门的抄本，等于让取证动作执行仓库里的任意脚本**——比 v0.2.x 的「算出一个假指纹」严重一个量级。
> 身份类命令**只允许有一处事实源**。

QA 会在**执行任何检查之前**用同一段 canonical 函数重算三元组并**逐字精确比对**，任一不符即 `ChangeSetIdMatched: No` + 停机。函数本身失败（`TMPDIR` 不可写、git < 2.25、Windows、命中任一 fail-closed 门）→ 相关检查项填 `Blocked`，**不得**填 `Passed` / `NotApplicable`，也不得改用自己写的命令降级取值。**生成三元组之后不要再改可发布面的内容。**

📎 **v0.3.0 起这些动作不再让身份失效**（逐条实测；旧文档里「别 `git add`，会让指纹失配」「`memory/` 的更新不要单独 commit」之类的说法**已过时，不要继续遵守**）：`git add` / `git reset`（内容不变）、`git commit`（含 commit `memory/`、含把本次主题改动 commit 掉）、仓库根的 scratch 临时文件（`tc-diff.js` / `node_modules` / `.env`）。真正会让它变的只有**可发布面的内容变化**。
🔴 **但这不是对这些动作的授权，也不改变 `BaseHeadSha` 的取值**：它仍然是开工前那一个 commit，不得因为中途 commit 过就换成新的 HEAD。canonical 内部的 `git add` 用的是隔离的临时索引，**不动用户的 `.git/index`**。

**Path C 尤其容易踩**：等预览验收期间「顺手再调一档间距」会让 `ThemeTreeOid` 与 `ChangeSetScopeFingerprint` 当场失配，必须重新生成 `ChangeSetId` 重走一轮。要改就明确开新一轮，不要在已交付的 ChangeSet 上补。

### HandoffContract

正文可自由组织（审计表、偏差清单、入口选择理由、踩坑核对），但**回复的最后必须是一个 `yaml` 代码块**，
字段名与顺序与 `handoff-schema.md` §4 **一字不差**，不得增删改名：

```yaml
ChangeSetId:              # CS-<YYYYMMDD>-C<NN>，NN 为当日 Path C 序号，从 01 起；零改动任务填 N/A
BaseHeadSha:              # 🔴 **开工前（写下第一个字节之前）捕获的 baseline commit**，不是交付时的 HEAD；
                          #   零改动填 N/A。v0.3.0 起不再是失配判据，但 required 且必须可解析：
                          #   缺失 / 不可解析 → DeclaredDiffCheck 等检查填 Blocked（不是 Advisories、不是 N/A）
ObjectFormat:             # sha1 | sha256 —— git rev-parse --show-object-format 的原样输出；零改动填 N/A
ThemeTreeOid:             # plaud_theme_tree 输出的第 2 段；零改动填 N/A
ChangeSetScopeFingerprint: # plaud_changeset_scope 输出的第 2、3 段，形态 "<ScopeTreeOid> <ScopeDigest>"
                          #   —— 两段必须一起逐字比：删除只体现在 ScopeDigest；零改动填 N/A
ReadOnlyProof:            # 仅零改动任务：审计前后两次的 ObjectFormat + ThemeTreeOid（必须相等）
                          #   + 取快照时的 BaseHeadSha；其余填 N/A
AssessmentRef:            # 引用 Assess 工件；InlineLite 时填 InlineLite；只读填 N/A(ReadOnly)
OriginTriageRef:          # 本块若由反馈返工产生：TriageId + ItemId；否则 N/A
Path: C
ReconMode:                # 与 Assess 一致；InlineLite 需附豁免理由；只读填 N/A(ReadOnly)
ModifiedFiles:            # 逐条 `- "<逐字路径>": <一句话改动>`；必须与工作树一致；零改动填 []
                          #   🔴 **路径必须用双引号包住且逐字精确**（不 trim、不 glob、不写目录）：
                          #   它同时是 ChangeSetScopeFingerprint 与 DeclaredDiffCheck 的**机器输入**，
                          #   下游把引号内的字符串逐字取出、每行一条喂给那两个函数。带尾空格的真实
                          #   路径被 trim 掉会让声明指错文件；路径含双引号 → 函数 fail closed，先重命名
                          #   🔴 **不含 memory/ 下的文件**：memory/ 不属于 ChangeSet，也不在可发布面内
                          #   Path C 的迁移日志 / 清单更新照常写 memory/，但**不列进 ModifiedFiles**
RootCause:                # 机制层迁移偏差根因（为什么这个模块偏离 spec）
OptionsConsidered:        # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:        # 原样继承 AssessmentRef，必须含 QA-C。🔴 不得写 QA-Global——QA 按 §5 恒执行
ThemeCheckRequired:       # Yes | No（判定见 handoff-schema.md §6）
VisualRegressionRequired: # Yes | No
BuildRequired:            # Yes | No（是否动了 shopify-common/src 需 npm run build）
ApprovedExceptions:       # 逐项声明的 🟠 ApprovedException；无则填 []
                          #   Clause 只能取 shared §8.1 封闭清单内的条款；Scope 必须逐对象/配对绑定
                          #   ApprovalRef 为空、或 ApprovedBy 是自己 → QA 判 Failed（见 shared §8.1）
                          #   🔴 双周会「已同意但清单尚未更新」的条款**不得**写进来（Clause 越界 = 谎报，
                          #      QA 判 ApprovedExceptionsChecked: Failed）。正确处理：本字段保持 [] 或不列该项，
                          #      条款按其当前档位照常判，BlockingGaps 记
                          #      PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>
                          #      清单扩容只能由 maintainer 在新版本快照里做（见 shared §8.1「封闭清单的变更权限」）
BlockingGaps:             # 实现中发现但无权处理的（如需模板存值编辑授权）
QAStatus: NotRun          # 恒为 NotRun；唯一例外见 handoff-schema.md §1.5
NextRequiredSkill: plaud-theme-qa-intake   # 零改动任务填 None
ReadyForDelivery: No      # 恒为 No，见 §1；零改动任务填 N/A(ReadOnly)
```

> ⚠️ 每个 `key:` 与注释之间**必须有空格**。YAML 里 `Key:# 注释` 是解析错误，照抄时不要压掉那个空格。

- `Path` 恒为 `C`
- `RequiredQAProfile` **原样继承 `AssessmentRef` 的值**，只断言其中含 `QA-C`。
  🔴 **不得写 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进本字段是字段越界（§9.2）。
  🔴 **上游工件误写了 `QA-Global` → 停机退回 `plaud-theme-impact` 重出工件，不要"剔除后再继承"**（v0.2.2 第八轮更正，原文正是这么写的）：QA 的 §4 结构核对枚举违规恒判停机、且明令不得替上游修；实现侧先悄悄修好，只会把 producer 的契约错误藏起来，下一轮同一个 impact 工件继续错，而"原样继承"这条规则也同时被破坏。退回时在 `BlockingGaps` 写清"AssessmentRef <编号> 的 RequiredQAProfile 含越界值 QA-Global，需 impact 重出"。
  🔴 **不得因为"我是 Path C"就改写成只有 `QA-C`** —— impact 因 RiskTier High 或跨路径追加的 `QA-A` / `QA-B` **必须带下去**。
  确需变更 profile（本轮实际动到的面与 Assess 不同）→ 退回 `plaud-theme-impact` 重评，不在 Implement 阶段自行改
- `QAStatus` 恒 `NotRun`；**唯一例外**是用户明确弃检时填 `Skipped(UserWaived)`（`handoff-schema.md` §1.5 的明文规定，不是本 skill 自造的口子）
- `ReadyForDelivery` 恒 `No`
- **不得**在这个块里出现 `ChangeSetIdMatched`、`RegressionMatrix`、`Evidence`、`ReadyForImplement` —— 那些是 Assess / Verify 阶段的字段
