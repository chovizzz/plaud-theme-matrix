# plaud-theme-impact — Matrix Contract

契约字段的唯一定义在 `plaud-theme-shared/references/handoff-schema.md`。本文件只说明本 skill 在矩阵中的位置与交接方式，**不重复定义字段、不新增字段**。

---

## 位置

| 阶段 | Path A | Path B | Path C |
|---|---|---|---|
| **Assess** | **plaud-theme-impact**（LegacyImpact） | **plaud-theme-impact**（IntegrationSurface） | **plaud-theme-impact**（LegacyImpact）+ 迁移实例审计 |
| Implement | plaud-theme-dev | plaud-theme-section-build | plaud-theme-ux-migration |
| Verify | plaud-theme-qa（QA-A + Global） | plaud-theme-qa（QA-B + Global） | plaud-theme-qa（QA-C + Global） |

order 2。阶段单向推进 `Assess → Implement → Verify`；可跳过 Assess 的唯一情形是 `InlineLite` 豁免。

> 🔴 **本 skill 不产出站点清单。** `AssessmentRef` 回答的是「哪些**模板 / 实例**受影响」，不回答「要推**哪些站点**」。站点维度（`TargetSites` / `ExcludedSites` / `ThemeIds` / `ScopeSourceRef`）归 `plaud-theme-qa-intake`（handoff-schema §9.1.2），发版前的二次确认归 `plaud-theme-release-ops`。
> 不得推断「这个模块看起来是全站的所以 17 站都要推」——那不是影响面事实，是猜测。

---

## 上游

| 来源 | 传入什么 |
|---|---|
| `plaud-theme-shared` | 契约（handoff schema、停机规则、全路径红线、视觉基线索引）。**开工前必读** |
| `plaud-theme-orchestrator` | 全流程任务的路径判定与任务描述（跨多模块 / 交叉路径 / 迁移 wave 时） |
| 用户直接调用 | 「改这个会影响什么」类问题，或实现 skill 开工前主动来评估 |
| `plaud-theme-dev` / `-section-build` / `-ux-migration` | 实现中发现影响面超出预期，退回重评 |
| 项目侧 `memory/模板清单.md`、`memory/模块清单.md` | 模板与模块的运行时状态。缺失时**停机问用户，不得凭空重建** |

---

## 下游

产出 §3 的 yaml 块，被三方消费：

| 消费方 | 消费什么 |
|---|---|
| `plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` | `AssessmentRef`（填进自己的同名字段）、`EntrypointCandidates`（选层）、`ActualAffectedInstances`（定回归范围）、`RequiredQAProfile`（透传）、`SharedPropagation`（判 `BuildRequired`） |
| `plaud-theme-qa` | `AssessmentRef` + `EvidenceCommands`（复算理论/实际影响数）、`ActualAffectedInstances`（回归矩阵覆盖面）、`RequiredQAProfile`（跑哪些 profile） |
| `plaud-theme-qa-intake` | `AssessmentRef` + `ActualAffectedInstances` / `ActiveInstances` / `DisabledInstances` —— 作为提测包的「影响范围说明」，**只引用不重算** |
| `plaud-theme-orchestrator` | `RiskTier` + `ReadyForImplement`（决定是否放行进入 Implement） |

`ReadyForImplement: No` 时**不得**进入 Implement 阶段；实现 skill 收到 `No` 必须停下，先补齐 `BlockingGaps`。

`RequiredQAProfile` 只含 `QA-A` / `QA-B` / `QA-C`；`QA-Global` 由 `plaud-theme-qa` 按 §5 恒执行，不写进本字段。

**AssessmentRef 失效条件**：Implement 阶段若开始修改任何原计划写入集之外的存量共享 / 入口文件，本次 Assess 失效，必须退回重评——不得在实现收尾时补一句"升级为 LegacyImpact"了事。

---

## 职责边界（不得越界）

本 skill **只产出事实**。以下字段属于别人，不得在本 skill 的输出块里出现：

| 字段 | 归属 |
|---|---|
| `RootCause` | 实现 skill（§4） |
| `OptionsConsidered` | 实现 skill（§4） |
| `ChangeSetId` / `ModifiedFiles` | 实现 skill（§2 / §4） |
| `ThemeCheckRequired` / `BuildRequired` / `VisualRegressionRequired` | 实现 skill（§4）——本 skill 提供判断依据（`SharedPropagation`），不代填 |
| `QAStatus` / `ReadyForDelivery` / 一切 QA 检查项 | `plaud-theme-qa`（§5） |

对应的行为红线：

- 不改任何文件（`sections/` `snippets/` `assets/` `templates/` `locales/` `config/` 全部只读）
- 不写"根因是……""建议改成……""这样改最稳"
- 不判定可交付，不使用「交付完成」「上线可用」「全部通过」等终态措辞
- 不批准 `templates/*.json` 编辑——只列候选与风险，授权归用户

---

## ReconMode 与路径的对应

| 路径 | 默认 ReconMode | 升级条件 |
|---|---|---|
| A | `LegacyImpact` | — |
| B | `IntegrationSurface` | 计划写入集包含任何存量 section/snippet/layout/template/section group/全局 CSS/token/build 源 → **升级为 `LegacyImpact`**，`RequiredQAProfile` 变为 `QA-A, QA-B` |
| C | `LegacyImpact` | — |
| 任意 | `InlineLite` | 仅当 8 条豁免条件全部满足；拿不准就不是 |

判定细节见 `references/recon-modes.md`。

---

## 输出块

回复最后必须是 `handoff-schema.md` §3 的 yaml 块，字段一字不差、不增不删不改名。字段缺失视为契约违规。
