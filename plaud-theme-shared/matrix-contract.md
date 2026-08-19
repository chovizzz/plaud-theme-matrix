# Matrix Contract — `plaud-theme-shared` 的交接约定

**何时读我**：想知道契约层怎么被引用、它输出什么、以及"数值只准引用不准复制"具体怎么执行时。

> 本文描述 **`plaud-theme-shared` 与其它 9 个 skill 的交接关系**。
> 契约字段本身定义在 `references/handoff-schema.md`（唯一契约），本文不重复定义字段。

---

## 1. 本 skill 在矩阵中的位置

`plaud-theme-shared`（order 0）是**契约层**，不是流水线上的一站。

| 特性 | 说明 |
|---|---|
| 产出 | **规则**，不是主题代码 |
| 上游 | 无。它不消费任何 skill 的 handoff |
| 下游 | 全部 9 个 skill —— 它们**开工前必须先读**本层 |
| 阶段 | 不占 Assess / Implement / Verify 任一阶段 |
| 用户直接调用 | 一般不需要。仅当用户直接问"矩阵怎么衔接""handoff 字段是什么""为什么必须过 QA"时可直接用它回答 |

---

## 2. 被引用时的输出：`SharedContractCheck`

> 🔴 **正文自检块，不是工件**（handoff-schema §9）：不进 §3/§4/§5 契约块、不进 §9.1.x 工件、无 `ArtifactKind`、下游不得消费。

任何 skill 引用本层后，在自己的正文里回报一次：

```yaml
ContractVersion: v0.3.6
PathResolved:            # A | B | C | Cross(B+C) | Cross(A+C)
StageResolved:           # Assess | Implement | Verify | N/A(NonStage)
                         #   ↑ 后者用于 §0.1 的四个非阶段 skill：orchestrator /
                         #     qa-intake / feedback-triage / release-ops
RequiredSkill:           # 当前阶段应由哪个 skill 执行
ReferencesLoaded:        # 本次实际加载的 reference 文件名
RedlinesApplicable:      # 本次任务命中的全路径红线编号（handoff-schema §8）
BlockingGaps:
```

`ReferencesLoaded` 是**按需加载纪律的可审计凭据**：写了哪些就说明读了哪些。🔴 **但它是正文自检块，不是工件字段，QA 不得据它阻断或放行任何阶段推进**（v0.2.2 第九轮更正：本行原写「QA 可据此判断」，与 canonical §9「下游不得消费自检块」冲突——QA 一旦拿它当门，就会因为上游漏写一行自检而卡住一个本来合格的 ChangeSet）。它只用于人读的过程复盘；QA 要判「改了字号却没读 typography.md」，依据是 §4 工件里的 `OptionsConsidered` / `RootCause` 与实际改动，不是这一行。

本层自身的 `HandoffContract`：

> 🔴 **这不是 canonical 工件，是本层的引用回执**（v0.2.2 第九轮补明）。`plaud-theme-shared` 是 order 0 的被引用层，不在阶段轴上、也不是 §0.1 的四个非阶段 skill 之一，所以它既不出 §3/§4/§5，也没有 `ArtifactKind`。`ProducerSkill` / `ConsumerSkill` / `ReadyForNextSkill` 这几个名字在 canonical §9.2 里没有定义，**不得**被当成阶段字段：不并进任何阶段契约块（§4 是 22 字段、§5 是 35 字段的封闭集合），下游也不得据 `ReadyForNextSkill` 做阶段门——阶段推进的唯一依据是 §3 的 `ReadyForImplement`、§4 的 `QAStatus` / `NextRequiredSkill`、§5 的 `ReadyForDelivery`。

```yaml
ProducerSkill: plaud-theme-shared
ConsumerSkill:           # 引用本层的 skill
ContractVersion: v0.3.6
BlockingGaps:
ReadyForNextSkill:       # Yes | No
```

---

## 3. 九个消费者各自必读什么

`references/handoff-schema.md` 对**所有** skill 都是必读。其余按需：

| 消费者 | 必读 | 常用 |
|---|---|---|
| `plaud-theme-orchestrator` | handoff-schema（**§2.12 并行语义 / §2.13 集成者 / §2.14 剔除规则**）、version-manifest | — |
| `plaud-theme-impact` | handoff-schema | responsive-and-spacing（判断断点/token 传播面）、colors-and-schemes §5.1（scheme 真实影响收敛） |
| `plaud-theme-dev` | handoff-schema | javascript-swiper、liquid-schema-format、media-quality、a11y |
| `plaud-theme-section-build` | handoff-schema | 全部 7 个（新建 section 会同时碰字体/颜色/间距/媒体/schema/JS/A11y） |
| `plaud-theme-ux-migration` | handoff-schema | typography、colors-and-schemes、responsive-and-spacing、media-quality |
| `plaud-theme-qa-intake` | handoff-schema（§0.1 / §2.1 / §9.1.2，含**集成提测包**） | — （**不读**视觉数值文件：它不判样式） |
| `plaud-theme-qa` | handoff-schema（**§2 全节**：六个函数、两层物化、`DeclaredDiffCheck`、§2.11 的三道交付门） | 按被验 `ChangeSetId` 的 `ModifiedFiles` 涉及面加载；`a11y.md` 恒读（QA-Global 含 A11yCheck + Advisories allowlist） |
| `plaud-theme-feedback-triage` | handoff-schema（§9.1.3） | 按反馈涉及的维度加载对应数值文件——判「是否违反 Spec」必须现读，不得凭记忆 |
| `plaud-theme-release-ops` | handoff-schema（§1.1 / §2.6 / §2.11 / §2.14 / §2.15 / §9.1.4） | — （**不读**视觉数值文件：它不判样式） |

**反面**：Path A 改一个 JS timer 时加载完整字阶表 = 重演单 skill 时代的注意力稀释。

### 3.1 v0.3.0 新增：契约冻结件

`references/CONTRACT-FREEZE.md` 是**第三波（其余九个 skill 落地 v0.3.0）的唯一输入**：最终字段清单与顺序、枚举增删、六个规范函数的签名与环境要求、11 条阻断项的逐条裁决、每个下游 skill 的接线清单。

> 🔴 **它不是运行时事实源。** agent 判定时读 `handoff-schema.md`，不读它。两者冲突时以 `handoff-schema.md` 为准。落地完成后它转为历史记录，不再被消费。

---

## 4. 「不得复制数值」怎么执行

`SKILL.md` 与 `handoff-schema.md` §8 都写明：各 skill **不得在自己的文件里复制本层的数值**，只得引用。

### 违规形态

| 形态 | 例 |
|---|---|
| 在其它 skill 的 SKILL.md / reference 里重抄数值表 | 在 `plaud-theme-ux-migration` 里再写一遍 `--space-N` 阶梯 |
| 把红线正文抄进其它 skill | 重述 `handoff-schema.md` §8 的 8 条 |
| 在其它 skill 的 eval 里断言具体数值 | 在 `plaud-theme-dev/evals` 里断言输出必须含 "24px" |

> **本层自己的 `evals/evals.json` 例外**：它与事实源同处一个 skill 目录、随同一次 install 一起更新，不会漂移；它的职责恰恰是**验证 agent 能取到正确数值**（尤其"没有从 vendor 旧表误抄"），因此其 `assertions` **允许也应当**断言具体数值。这条豁免只适用于 `plaud-theme-shared/evals/`。

### 合规写法

```
❌ 「container XS/Mobile 内边距 24px」
✅ 「container 内边距见 plaud-theme-shared/references/responsive-and-spacing.md §4.2」

❌ 「区头 Heading PC 40px / MB 32px」
✅ 「区头三件套样式表见 typography.md §5，按表取值」
```

### 允许的例外

- **引用时顺带点名**某个数值以说明"读哪一节"（如"断点精度 `.98`，详见 responsive-and-spacing §1"）——这是索引，不是二次定义；
- QA 的 `Evidence` 字段里写实测到的具体数值——那是**证据**，不是规范副本。

### 为什么

spec 一升级，多副本必然漂移，随后两个 skill 会用两套值处理同一个 `memory/`——这与矩阵最想避免的失败模式（多事实源）完全一致。

---

## 5. 本层与 `handoff-schema.md` §8 的分工（避免双事实源）

红线共 8 条，**正文（规范性表述）只存在于 `handoff-schema.md` §8**。本层各 reference 只提供**可执行细则**，不重新定义判定标准：

| 编号 | 规范正文（唯一） | 执行细则 |
|---|---|---|
| 1 | `handoff-schema.md` §8.1 | `liquid-schema-format.md` §1 |
| 2 | `handoff-schema.md` §8.2 | `responsive-and-spacing.md` §6.2、§3.3；已文档化例外见 `javascript-swiper.md` §4 |
| 3 | `handoff-schema.md` §8.3 | `media-quality.md` §1 |
| 4 | `handoff-schema.md` §8.4 | `colors-and-schemes.md` 全篇；已文档化例外见其 §3 |
| 5 | `handoff-schema.md` §8.5 | `a11y.md` §1–§7 |
| 6 | `handoff-schema.md` §8.6 | `javascript-swiper.md` §3 |
| 7 | `handoff-schema.md` §8.7 | `javascript-swiper.md` §9 |
| 8 | `handoff-schema.md` §8.8 / §1 | 无细则（纯流程规则） |

本表**只做编号 → 位置的索引**，刻意不复述任何一条红线的内容——复述就是第二份正文。

读法：**要判"违没违规"看 §8；要判"具体取什么值 / 怎么检查"看本层 reference。** 两处若表述冲突，以 `handoff-schema.md` 为准（§0 已声明"字段冲突时以本文件为准"）。

---

## 6. 本层不做的事

- 不改任何 `sections/` `snippets/` `assets/` `templates/` 文件
- 不做根因分析、不出方案、不做验收判定
- 不替代 `plaud-theme-impact` 的影响面评估
- 不输出 `ReadyForDelivery: Yes`（那是 `plaud-theme-qa` 的唯一特权）
- **不做 merge、不做集成**（v0.3.0：矩阵里没有「集成者」这个 skill，`IntegrationPlan.Integrator` 填人，见 handoff-schema §2.13）
- **不产生 commit**（v0.3.0 的取证用空白临时索引 + `git write-tree`，不动 HEAD / ref / 用户 index / 工作树）
- 不持有项目运行时状态（模板清单 / 模块清单 / 已知偏差 / changeset log 在项目侧 `memory/`）

---

## 7. 版本漂移的处理

| 情形 | 动作 |
|---|---|
| 某**矩阵 skill** 输出的 `ContractVersion` ≠ `version-manifest.md` 的值 | 停机，要求重装整包（部分安装 = 两套 spec 处理同一 `memory/`）。包内附带工具 skill（`version-manifest.md` §2.1）不输出该字段，缺失**不是**漂移 |
| 本层 reference 更新了数值 | 消费者**不需要改自己的文件**——这正是"只引用不复制"的收益 |
| 新增一个 reference | 同步更新 `SKILL.md` 的 Reference 索引表 + `version-manifest.md` §3 |
| 红线增删 | **规范正文只改 `handoff-schema.md` §8**。`SKILL.md` 的「全路径红线」段是随包分发的索引式摘要（本版不可改），编号须与 §8 保持对齐；两者表述冲突以 `handoff-schema.md` 为准。本层 reference 只调细则，不复制正文 |
| **`ApprovedException` 封闭清单增删** | 唯一写入点是 `handoff-schema.md` §8.1 那张表，唯一 owner 是矩阵包 maintainer，且**必须切新版本快照**（`ContractVersion` bump + `version-manifest.md` §1.1 + CHANGELOG + 四端重装核对）。运行时任何 skill 都不得扩充；双周会纪要只决定**下一版怎么写**，不改变**当前包怎么判**，不一致即按 §7 停机。规则正文见 `handoff-schema.md` §8.1「封闭清单的变更权限」，本表不复制 |
