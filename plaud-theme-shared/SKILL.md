---
name: plaud-theme-shared
description: >
  PLAUD Shopify 主题矩阵的契约层（order 0）：两轴状态机、handoff schema、ChangeSetId 绑定、
  交付权归属、Stop-don't-guess 停机规则、全路径红线、视觉与 UX 基线索引、版本清单。
  矩阵内任何 skill 在开工前都必须先读本 skill；全流程任务必须过本层契约。
  本 skill 不实现任何主题改动、不做 bug 修复、不写 section、不做 UX 迁移、不做验收——
  它只定义规则与交接格式。用户不需要直接调用本 skill；由 plaud-theme-orchestrator /
  plaud-theme-impact / plaud-theme-dev / plaud-theme-section-build / plaud-theme-ux-migration /
  plaud-theme-qa-intake / plaud-theme-qa / plaud-theme-feedback-triage / plaud-theme-release-ops 引用。若用户直接问"矩阵怎么衔接""handoff 字段是什么""为什么必须过 QA"，可直接读本 skill 回答。
---

# PLAUD Theme Shared（契约层）

矩阵的单一事实源。产出的不是主题代码，而是**规则**：谁在什么阶段、凭什么证据、可以说什么话。

## 包更新提示（不属于矩阵，也不影响任何判定）

开工前跑一次这条命令。它**不是矩阵的步骤**：不属于 Assess / Implement / Verify，
不产出证据、不进 handoff、不进 `BlockingGaps`，失败与否都不改变任何判定。

```sh
sh ~/.local/share/plaud-theme-matrix/bin/plaud-matrix-update guard || true
```

- 没装更新器、命令不存在、网络不通 —— 这条都会静默成功，**照常继续本来的任务**。
- **不要重定向它的 stderr**：它唯一会说的话就写在那里。
- 通常它什么都不打印。只有当发现一个你还没被告知过的新版本时，才在 stderr 打一行。
- 打印了就**转告用户**；带 `BREAKING` 字样时更要转告，别自己决定装不装。
- 它**不会替换正在用的 skill 文件** —— 那会让同一次任务前半段按旧规则、后半段按新规则走。
  安装发生在下一次新会话，或用户显式跑 `plaud-matrix-update apply --yes`。
- 关掉：`PLAUD_NO_UPDATE_CHECK=1`；CI 环境自动跳过。

> 若你**确实**在本次会话中途装了新版本（比如用户让你跑 `apply`），那么此前读进上下文的
> 矩阵文档已经过期：**重读**当前 skill 的 `SKILL.md` 与你正在用的 reference 再继续。

## 本 skill 做什么

- 定义两轴状态机（阶段 × 路径）与阶段推进条件，以及阶段轴之外的四个非阶段 skill（§0.1）
- 定义唯一 handoff schema 与 `ChangeSetId` 绑定机制
- 规定交付权归属（**只有 `plaud-theme-qa` 能说可交付**）
- 规定 Stop-don't-guess 停机点
- 持有全路径红线与视觉/UX 基线的**唯一副本**
- 持有版本清单与 reference 索引

## 本 skill 不做什么

- 不改任何 `sections/` `snippets/` `assets/` `templates/` 文件
- 不做根因分析、不出方案、不做验收判定
- 不替代 `plaud-theme-impact` 的影响面评估

---

## 适用边界（整个矩阵共享）

**用矩阵：**

- 用户提到 Plaud / PLAUD / PLAUD SG，或仓库内容明显是 Plaud Shopify 主题
- 改 `sections/`、`snippets/`、`assets/`、Liquid、CSS、JS、自定义元素、Swiper、弹窗、drawer
- Figma 转 Shopify section、按设计稿做 `sa-*` section
- 按 UX Spec v1.3 对齐模板/模块
- 性能优化、Bug 修复、新功能、UX 调整、无障碍审计、上线前 review

**不用：**

- 非 Plaud 主题的一般 Shopify 开发
- Shopify App、Admin API、Checkout Extension、Hydrogen / headless、WooCommerce
- 只读 UX 规范文档总结、无 Plaud 上下文的泛化 CSS/Liquid review

---

## 两轴状态机

**路径决定"按什么规则实现"，阶段决定"现在处于评估、实现还是验证"。**

| 阶段 | Path A 通用开发 | Path B Figma section | Path C UX 迁移 |
|---|---|---|---|
| **Assess** | `plaud-theme-impact`（LegacyImpact） | `plaud-theme-impact`（IntegrationSurface） | `plaud-theme-impact`（LegacyImpact） |
| **Implement** | `plaud-theme-dev` | `plaud-theme-section-build` | `plaud-theme-ux-migration` |
| **Verify** | `plaud-theme-qa`（QA-A + Global） | `plaud-theme-qa`（QA-B + Global） | `plaud-theme-qa`（QA-C + Global） |

### 路径判定

```
用户请求
  ├─ 含 Figma / 设计稿 / 新建 sa-* / Section AI？   → Path B
  ├─ 含 UX Spec v1.3 / 刷模块 / spec 迁移 / 对齐 ux？ → Path C
  └─ 否则（bug / 性能 / 新功能 / UX 微调 / review / A11y） → Path A
```

交叉场景以更具体的规范优先：B + C 同时命中 → 走 B 的实现规则 + C 的 spec 取值；A 的质量规则全局继承，永远适用。

### 入口暴露

不是十个平级入口。

- **正常用户入口**：`plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration`
- **全流程入口**：`plaud-theme-orchestrator` — 进入门槛只有一条：**这项工作必须拆成 ≥2 个可独立验收的 ChangeSet**（典型是迁移 wave、跨多个互不相干模块的批量改动）。单一 ChangeSet 能装下的工作一律直接走实现 skill，**普通 bugfix 不绕 orchestrator**。"改动涉及好几个文件"不是理由——同一个 ChangeSet 里本来就可以有多个文件。
- **阶段能力 / 专家入口**：`plaud-theme-shared`（本文件）、`plaud-theme-impact`、`plaud-theme-qa`

阶段单向推进 `Assess → Implement → Verify`。可跳过 Assess 的唯一情形是 `InlineLite` 豁免（条件见 handoff-schema §3）。**任何有改动的任务都不得跳过 Verify。**（有改动的任务；§2 的零改动只读任务免 QA）

---

## 核心规则

### 1. 交付权唯一

> **只有 `plaud-theme-qa` 有权输出 `ReadyForDelivery: Yes`。**

实现类 skill 恒输出 `ReadyForDelivery: No` + `QAStatus: NotRun`，且禁止使用「交付完成」「上线可用」「全部通过」「可以发布」等终态措辞。允许的说法是「改动已就位，待 QA」。

`Blocked` / `NotRun` 不得折算为 pass。`NotApplicable` 是**合法终态**，但必须带适用性证据——无证据的按 `Blocked` 处理（详见 handoff-schema §1.3）。QA 通过后**可发布内容**再变，原 QA 自动失效（v0.3.0 起 `git add` / `commit` / 仓库根临时文件不再算"再变"，见 handoff-schema §2.8）。

> 🔴 **v0.3.0 起 `ReadyForDelivery: Yes` 有两个合法来源**：`QAScope: SingleChangeSet`（单块直发）与 `QAScope: Integration`（多块同批）。真正的门不是 scope，而是 handoff-schema §2.11 的三道机械等式——`DeclaredDiffCheck: Passed` + `ReleaseSourceTreeOid == VerifiedThemeTreeOid` + `PushCommandCompliance: Compliant`。多块合并后没有任何单块 QA 持有那棵合并树的 oid，于是**结构上必然**要求一份集成 QA。

### 2. ChangeSetId 绑定的是不可变 git 对象，不只绑文件名

实现 skill 交付时**当场**生成 `ModifiedFiles`（文件集合）+ **三个身份字段**：`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`。QA 必须在**执行任何检查之前**全部重算逐字比对，任一不符即 `ChangeSetIdMatched: No` + 停机。

只绑文件名挡不住"交付后偷改同一批文件"——集合没变、内容变了，校验照样通过。命令与失配处理见 handoff-schema §2。

> 📎 🔴 **v0.3.0 的破坏性变更**：`ChangeSetFingerprint`（v0.2.x 的工作树状态文本 hash）**已废止**。新身份是 `plaud_theme_tree` / `plaud_changeset_scope` 用**空白临时索引 + `git write-tree`** 生成的 tree oid——不 commit、不动 HEAD / ref / 用户 index / 工作树，默认连 `.git/objects` 都不写。
> 由此解开的：`git add` / `git reset` / `commit`（含 `commit memory/`）/ 仓库根 scratch 临时文件**都不再让 QA 结论失效**；同树可并行 Implement。
> 由此新增的前提：**可写 `TMPDIR`**、**git ≥ 2.25**、**只支持 macOS / Linux 取证**（Windows 上两道字节保真门必然停机）。
> `BaseHeadSha` 降级为**不再是失配判据**，但**仍然必填且必须是可解析的 commit-ish**——`DeclaredDiffCheck`、theme check baseline、存量偏差举证都要它。

### 2.1 改动归属：`DeclaredDiffCheck`

指纹能证明"树是什么"，证明不了"这些改动是谁的"。`plaud_declared_diff` 用四元组比对：**相对基准真正变化的可发布路径集合，必须恰好等于本工件覆盖的 ChangeSet 声明的可发布路径集合**。多出来的是无主改动 → 停机；少掉的是声明不实 → 停机。
这是同树并行下"把别人的半成品一起推上线"的唯一机械防线，也是 `IncludedInThisPush: No` 的块被剔除干净的唯一验证手段。详见 handoff-schema §2.7 / §2.14。

### 3. 证据，不是声明

handoff 传递的是**结构化事实和命令原文**，不是"我做过了"。`EvidenceCommands` / `Evidence` 字段为空的检查项视为未执行。

### 4. 理论影响 ≠ 实际影响

`TheoreticalReferences` 与 `ActualAffectedInstances` 必须分开报。只报"可能影响 N 处"是不合格的评估——逐项核查后真实影响往往收敛很小。

### 5. Stop, don't guess

缺证据就停，要材料；不凭经验补齐。完整停机点清单见 `references/handoff-schema.md` §7。

---

## 全路径红线

以下与路径无关，任何 skill 不得违反，也**不得在自己的文件里复制数值**（复制会产生多个事实源，spec 一升级必然漂移）——只引用本层 reference：

1. 展示文案必须走 schema 或 locales；Liquid 不用 `| default: '...'` 兜底；`blank` 不输出空壳 DOM
2. 禁止无理由写死组件宽高（例外须说明原因）
3. 图片清晰度红线：`width:` 只防 CLS / 适配容器，按容器宽 × 高 DPI 取值，不得下采样糊掉展示图
4. 颜色走 token / CSS 变量，不写死 hex
5. A11y 底线：语义化 button、aria-label、trapFocus、对比度 ≥ 4.5:1、focus-visible
6. JS：null 守卫、TDZ 安全、`disconnectedCallback` 清理监听 / timer / observer / subscription
7. build 产物勿手改，改动落到源 + 重新 build
8. 最终交付必须经 `plaud-theme-qa`

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| **任何 skill 开工前（必读）** | `references/handoff-schema.md` |
| **要落地任何 spec 数值、或依赖某个 token / 工具类之前（必读）** | `references/repo-drift.md` |
| 需要字体 / 字阶 / 标题层级数值 | `references/typography.md` |
| 需要颜色 token / 配色方案 / gradient | `references/colors-and-schemes.md` |
| 需要断点 / 间距 / 容器宽度 | `references/responsive-and-spacing.md` |
| 涉及图片 / 视频清晰度与懒加载 | `references/media-quality.md` |
| 写 Liquid / schema / 文案配置 / 文件格式 | `references/liquid-schema-format.md` |
| 写 JS / custom element / Swiper | `references/javascript-swiper.md` |
| 无障碍审计 | `references/a11y.md` |
| 查版本与各 skill 职责 | `references/version-manifest.md` |

> 🔴 `handoff-schema.md` 在 v0.2.0 新增了三类工件（§9.1.2 提测准入 / §9.1.3 反馈分类 / §9.1.4 发版）、
> 运营协作红线（§8.1–§8.2）与 `ReadyForDelivery` 的边界（§1.1）。涉及提测、反馈归因、发版的任务必读这几节。

Path A 改一个 JS timer 时**不需要**加载完整字体字阶表。按当前任务实际需要加载，读多了就是重演单 skill 时代的注意力稀释。

### ⚠️ 规范值 ≠ 目标仓库的编译产物

本层 reference 记录的是**规范值**。而 `snippets/design-system.liquid` 是 **build 产物**——它包含哪些 token 与工具类、当前是什么值，取决于该仓库最后一次 build 的时间点。两者之间必然存在时间差，与仓库身份无关。

实测中出现过的差异包括：品牌色变量是另一套命名（照规范写 `var(--color-purple)` 会解析失败、属性静默失效）、`.container` 移动端内边距仍是旧值、`.use-color-scheme` 的重绑范围更广、`.separator-*` 与 `.richtext-container` 根本没 build 进去。

**要落地任何 spec 数值、或依赖某个 token / 工具类之前，先读 `references/repo-drift.md` 并按其中的命令核对目标仓库实际值。** 两个方向都会出事：

- 照规范写没 build 进去的工具类 → 样式静默失效
- 拿实测值去推翻规范 → 规范被旧值污染，越改越回退

正确做法是两边都不动：规范照旧、实测记为事实，差异写进 `BlockingGaps`。拉齐仓库是独立的、需授权的改动，不得夹带在当前任务里。

---

## 项目状态文件（`memory/`，不随包分发）

模板清单、模块迁移状态、全局已知偏差属于**项目运行时状态**，不是规范。它们随每次迁移变化，必须存放在项目侧，不得写进本包 —— 写进包里会在下次 install 时被整包覆盖。

| 文件 | 内容 | 维护者 |
|---|---|---|
| `memory/模板清单.md` | per-template：状态、section 渲染顺序、已迁模块、实例特殊约束 | `plaud-theme-ux-migration` + 用户 |
| `memory/模块清单.md` | per-module：后台名、实例数、迁移状态、schema 约束、关键字段 | `plaud-theme-ux-migration` + 用户 |
| `memory/全局已知偏差.md` | 跨模板共享的待评估项与已修项 | `plaud-theme-ux-migration` |
| `memory/changeset-log.md` | ChangeSetId → QA 结果，供追溯与失效判定；**v0.2.2 起多一列 `TestSetTrace`**（该轮**通过准入**（`QAAdmissionStatus: Accepted`）的测试集行原文，与 `ReadyForDelivery` 无关，供下一轮提测核连续性） | `plaud-theme-qa` |

### 缺失时的唯一初始化规则

各 skill 一律引用本表，不得自行规定：

| 文件 | 缺失时 |
|---|---|
| `模板清单.md` / `模块清单.md` / `全局已知偏差.md` | **默认停机**。仅当用户明确确认"这是首次接入、本项目没有历史迁移状态"后，才可从 `plaud-theme-ux-migration/references/memory-seed/` 复制种子初始化 |
| `changeset-log.md` | 询问用户后可创建空日志（它是本矩阵自己产生的记录，不存在"历史状态丢失"问题） |

除上述情形外一律停机。**绝不可**凭空重建迁移状态——会与真实进度脱节，导致重复迁移或漏迁。

### 🔴 完成态必须由 QA 背书

`模板清单.md` / `模块清单.md` / `全局已知偏差.md` 里的完成态标记（`✅ DONE`、`已迁`、`已修`）**只能**在同时满足以下三条时写入：

1. `memory/changeset-log.md` 中存在对应的 `ChangeSetId`（日志只做**追溯索引**，判据不在日志里取）
2. 该块的 QA 工件 `ReadyForIntegration: Yes`，**并且存在一份覆盖它的、`ReadyForDelivery: Yes` 的 QA 工件**
   —— 单块直发时就是该块自己那份；多块批次里是那份 `IntegrationOf.Members` 含本块的 `QAScope: Integration` 集成 QA 工件
3. 该记录的 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` 与当前重算结果逐字一致（未失效）

> 🔴 **v0.3.0 改判据**（此前第 1 条写的是「日志中该 `ChangeSetId` 的 `ReadyForDelivery: Yes`」，两处都错）：
> ① `changeset-log.md` **没有 `ReadyForDelivery` 这一列**（列见 §9.2「`memory/` 记录字段」），那是一条查不到的判据；
> ② 多块批次里每一块的树都含兄弟改动，块 QA 的 `ReadyForDelivery` **恒为 `No`**，照旧判据没有任何模块能被标成
> `已迁` —— 那正是 handoff-schema R-BLOCK-3 拆成两层门要解决的死锁。`plaud-theme-ux-migration` 全套已按新判据落地，本节与它一致。
> 🔴 第 3 条比的是**该块自己的 `ChangeSetScopeFingerprint`**（在当前树里重算），**不是**要求当前整树的
> `ThemeTreeOid` 仍等于该块交付时的值 —— 集成之后整树必然因兄弟块而不同，那是合法的。

**用户的视觉验收不等于 QA 通过**——它们是正交的两件事。用户说"看着对了"只能写成 `视觉已确认，待 QA`，不得推进为完成态。否则未经验证的代码会被永久记录为"已迁"，后续 agent 把它当事实源，漏检就此固化下来。

两个状态分开记，不要合并成一个字段：

| 状态 | 取值 | 谁来置 |
|---|---|---|
| `VisualAcceptance` | `Pending` \| `Accepted` | 用户预览确认 |
| `QAStatus`（记录于 changeset-log） | `Pending` \| `Valid` \| `Invalidated` | `plaud-theme-qa` |

只有 `VisualAcceptance: Accepted` **且** `QAStatus: Valid` 才写完成态。

---

## SharedContractCheck

> 🔴 **这是正文自检块，不是阶段工件**（handoff-schema §9）：写在阶段契约块**之前**，**不得**把它的字段并进 §3/§4/§5 契约块（那两个是 22 / 35 字段的封闭集合，多一个 key 即结构违规），下游也**不得**拿它当事实源。

被其它 skill 引用时，输出：

```yaml
ContractVersion: v0.3.6
PathResolved:            # A | B | C | Cross(B+C) | Cross(A+C)
StageResolved:           # Assess | Implement | Verify | N/A(NonStage)（后者用于 §0.1 的四个非阶段 skill；v0.2.2 第九轮与 matrix-contract 对齐）
RequiredSkill:           # 当前阶段应由哪个 skill 执行
ReferencesLoaded:        # 本次实际加载的 reference
RedlinesApplicable:      # 本次任务命中的全路径红线编号
BlockingGaps:
```

## HandoffContract

> 🔴 **这不是 canonical 工件，是本层的引用回执**（v0.2.2 第九轮补明）。`plaud-theme-shared` 是 order 0 的被引用层，不在阶段轴上、也不是 §0.1 的四个非阶段 skill 之一，所以它既不出 §3/§4/§5，也没有 `ArtifactKind`。`ProducerSkill` / `ConsumerSkill` / `ReadyForNextSkill` 这几个名字在 canonical §9.2 里没有定义，**不得**被当成阶段字段：不并进任何阶段契约块（§4 是 22 字段、§5 是 35 字段的封闭集合），下游也不得据 `ReadyForNextSkill` 做阶段门——阶段推进的唯一依据是 §3 的 `ReadyForImplement`、§4 的 `QAStatus` / `NextRequiredSkill`、§5 的 `ReadyForDelivery`。

```yaml
ProducerSkill: plaud-theme-shared
ConsumerSkill:           # 引用本层的 skill
ContractVersion: v0.3.6
BlockingGaps:
ReadyForNextSkill:       # Yes | No
```
