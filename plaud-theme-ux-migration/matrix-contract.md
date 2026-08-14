# Matrix Contract — `plaud-theme-ux-migration`

矩阵位置：**Path C · Implement 阶段（order 5）**。
唯一契约以 `plaud-theme-shared/references/handoff-schema.md` 为准；本文件只写本 skill 的接线，不新增字段。

```
plaud-theme-impact (Assess)  ──AssessmentRef──▶  plaud-theme-ux-migration (Implement)
                                                        │
                                                 ChangeSetId + ModifiedFiles
                                                        ▼
                                                 plaud-theme-qa (Verify)  ──▶ ReadyForDelivery
```

---

## 1. 上游：`plaud-theme-shared`（order 0，必读）

开工前必读 `SKILL.md` + `references/handoff-schema.md`（§1 交付权 / §3 消费的工件 / §4 产出契约 / §7 停机 / §8 红线）。

- 视觉与 UX 数值的**唯一副本**在 shared 的 `typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` ——
  本 skill **引用文件名，不复制数值**
- 全路径红线（§8）本 skill 全部继承；与本 skill 任何配方冲突时**红线优先**

## 2. 上游：`plaud-theme-impact`（Assess）

**消费 `handoff-schema.md` §3 的全部字段**，重点：

| 字段 | 本 skill 怎么用 |
|---|---|
| `AssessmentRef` | 写进自己的 `AssessmentRef`；报告正文引用它标注 blast radius 出处 |
| `ReconMode` | 原样带到 §4 输出块，**必须与 Assess 一致** |
| `TheoreticalReferences` / `ActiveInstances` / `DisabledInstances` | 「用量 → 推荐入口」启发式的输入（`spec-value-rules.md` §4.1）；**不重算** |
| `ActualAffectedInstances` | 判断改动落哪层、要不要走独立色板、回归点怎么列 |
| `SharedPropagation` | token→class 全实例覆盖（§4.15）、build 产物 vs 源（§4.20）、dangling 扫描范围 |
| `EntrypointCandidates` | 三层入口的**候选与风险**；**最终选哪层由本 skill 决定并写理由** |
| `RequiredQAProfile` | **原样继承**，只断言其中含 `QA-C`。🔴 **不得写 `QA-Global`**（由 QA 按 §5 恒执行，写进本字段是字段越界，§9.2；🔴 上游误写则**停机退回 `plaud-theme-impact` 重出工件**，不得自行剔除后继续——QA 对枚举违规恒判停机、且明令不得替上游修；实现侧悄悄修好只会把 producer 的契约错误藏起来，并同时破坏「原样继承」这条规则。v0.2.2 第九轮更正：本行原写「剔除」，与 SKILL.md 的停机口径相反）。🔴 **不得因为"我是 Path C"就改写成只有 `QA-C`** —— impact 因 RiskTier High 或跨路径追加的 `QA-A` / `QA-B` 必须带下去；确需变更 → 退回 impact 重评，不在 Implement 阶段自行改 |
| `BlockingGaps` / `ReadyForImplement` | `ReadyForImplement: No` → **不得开工** |

**边界**：本 skill **不重跑 blast radius / 共享调用方 grep 生成第二份清单**。
disabled 实例命令是**交叉验证**手段（目的是审计与日志资格，非影响面），结果必须与 `DisabledInstances` 一致，不一致就停下核对；
`AssessmentRef` 只给计数不给实例 ID / 不给共享 markup 实例清单 → 视为工件不完整，**退回 impact 补，不在本地补算**。

**豁免**：满足 `handoff-schema.md` §3 `InlineLite` 全部条件时可跳过 Assess，
`AssessmentRef` 填 `InlineLite` 并附豁免理由。**拿不准就不是 InlineLite。**

## 3. 下游：`plaud-theme-qa-intake` → `plaud-theme-qa`（Verify）

> 🔴 **v0.2.0 起先过 `plaud-theme-qa-intake`。** `NextRequiredSkill` 填 `plaud-theme-qa-intake`；提测包齐备后 QA 才启动（handoff-schema §9.1.2）。下文关于 QA 的内容仍然成立，只是多了一道前置关口。

产出 `handoff-schema.md` §4 的 yaml 块。QA 侧的对接点：

- `ChangeSetId` 格式 **`CS-<YYYYMMDD>-C<NN>`**；QA 回填 `ChangeSetIdMatched`
- 身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）**在交付工件那一刻现场生成**（函数见 `handoff-schema.md` §2.5，整段原样复制）；`BaseHeadSha` 相反，**在开工前取**（写成交付时 HEAD 会让所有声明路径落进 `DECLARED_DIFF_UNCHANGED`、QA 恒阻断），required 且必须可解析。
  QA 在**任何检查之前**重算三元组并逐字比对——这是堵"交付后、QA 前偷改同一批文件"的唯一手段，只绑文件名挡不住它。算完不要再改可发布面的内容
- `ModifiedFiles` **必须与工作树一致（`memory/` 除外）、且逐字精确**（路径用双引号包住，不 trim、不 glob、不写目录——它是 `ChangeSetScopeFingerprint` 与 `DeclaredDiffCheck` 的机器输入）—— 不一致 QA 停机，不得"顺便一起验了"。交付前自查用 `plaud_changeset_scope <逐字路径清单>`（每行一条，见 `handoff-schema.md` §2.5）；独占工作树时还可以跑 `plaud_declared_diff <BaseHeadSha> <清单>` 做归属自检。🔴 **不要用 `git status` / `git diff HEAD` 扫整棵工作树**：同树并行 Implement 下它会把兄弟块的改动误报成本块的文件；而且 v0.3.0 起主题改动 commit 掉不再让身份失效，commit 之后 `git diff HEAD` 会是空的。
  🔴 **迁移日志与 `memory/*.md` 的更新不列进 `ModifiedFiles`**（它们不属于 ChangeSet，也**不在可发布面内**——因此改它们不会改变 `ThemeTreeOid`），要交代就写在正文。
  📎 **v0.3.0 起解除**：v0.2.2 那条「`memory/` 的更新留在工作树、不单独 commit」的硬规则没有了——新模型的身份里没有 HEAD，改 / `git add` / `git commit` `memory/` 之后三元组逐字不变（实测）。**这一条与「不列进 `ModifiedFiles`」是两条不同的规则，后者照旧**
- `RequiredQAProfile` 恒含 `QA-C`，其覆盖内容（disabled 实例已跳过 / 空 heading 未进总览 / 三层入口选择正确 /
  20 条踩坑适用项 / 日志时机）**正是本 skill 必须在正文交代清楚的部分**
- `ThemeCheckRequired` / `VisualRegressionRequired` / `BuildRequired` 由本 skill 判定，**实跑归 QA**
- QA 通过后代码若再变 → 原 QA 自动失效，**重新生成 `ChangeSetId`**

## 4. 平级：`plaud-theme-dev` / `plaud-theme-section-build`

- 迁移中发现 **bug / 性能问题** → 不在本 skill 顺手修（那是 Path A，`plaud-theme-dev`）；
  登记为待评估或另起 ChangeSet
- 迁移中需要**新建 `sa-*` section** → Path B（`plaud-theme-section-build`）。
  **B+C 交叉的唯一口径**（与 `MATRIX.md` / orchestrator / section-build 一致）：
  **单一 ChangeSet 能装下的 B+C 直接由 `plaud-theme-section-build` 实现**（实现规则用 B 的、spec 取值用 C 的，
  `RequiredQAProfile` 取 `QA-B, QA-C`，不写 `QA-Global`），**不绕 orchestrator**；
  只有还需**拆出第二个可独立验收的 ChangeSet** 时才进 orchestrator

## 5. `plaud-theme-orchestrator`

进入门槛只有一条（与 `plaud-theme-shared/SKILL.md` 同一条）：**这项工作必须拆成 ≥2 个可独立验收的 ChangeSet**——
典型是跨多模板的迁移 wave、跨多个互不相干模块的批量改动。
**单一 ChangeSet 装得下的工作一律直接走实现 skill**：单模块迁移不绕 orchestrator，单一 ChangeSet 的 B+C 交叉同样不绕。
"涉及好几个文件"或"跨了路径"都**不是**理由。

## 6. 项目状态文件（`memory/`，不随包分发）

| 文件 | 本 skill 的关系 |
|---|---|
| `memory/模板清单.md` | 读 + 写（**视觉验收后**写 `视觉已确认，待 QA`；**完成态需 QA 背书**） |
| `memory/模块清单.md` | 读 + 写（同上） |
| `memory/全局已知偏差.md` | 读 + 写（新发现的跨模板待评估项**不必等验收**即可登记；`已修` / `DONE` 需 QA 背书） |
| `memory/changeset-log.md` | **只读** —— 由 `plaud-theme-qa` 维护，本 skill 不写。其中 `QAStatus: Pending\|Valid\|Invalidated` 是 §9.2 的 **`memory/` 记录字段**枚举，与阶段契约块的 `QAStatus` 不是一套 |

**缺失时一律按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表执行——本文件只引用，不自行规定。**
格式见 `references/project-state-schema.md`；种子在 `references/memory-seed/`（2026-07 快照，其中的数值是实测历史证据、不是规范值）。

## 7. 交付权与完成态

> **只有 `plaud-theme-qa` 能输出 `ReadyForDelivery: Yes`。**

本 skill 恒输出 `ReadyForDelivery: No` + `QAStatus: NotRun`，禁用一切终态措辞（含旧模板里的「迁移完成」标题）。

「**用户视觉验收通过**」（`VisualAcceptance: Accepted`，可以写日志的条件）与「**可交付**」（QA 的判定）是两件**正交**的事，不得互相折算。

🔴 **`memory/` 里的完成态（`✅ DONE` / `已迁` / `已修`）也需要 QA 背书**：changeset-log 中存在对应 `ChangeSetId`、该块 QA 的 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件，且身份三元组未失效。
只有视觉验收时，状态只能写 `视觉已确认，待 QA（<ChangeSetId>）`。规则源是 `plaud-theme-shared/SKILL.md`。
