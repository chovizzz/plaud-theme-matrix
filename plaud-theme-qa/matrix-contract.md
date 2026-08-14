# plaud-theme-qa — Matrix Contract

契约以 `plaud-theme-shared/references/handoff-schema.md` 为准。本文件只描述本 skill 在矩阵中的接线，不重复定义字段。

## 位置

| 项 | 值 |
|---|---|
| order | 7 |
| 阶段 | **Verify**（阶段轴终点） |
| 路径 | A / B / C 全部经过本 skill |
| 唯一性 | **矩阵中唯一有权输出 `ReadyForDelivery: Yes` 的 skill** |

阶段单向推进 `Assess → Implement → Verify`。**任何情况下不得跳过 Verify**（`InlineLite` 只豁免 Assess，不豁免 Verify）。

## 上游（ProducerSkill）

| 上游 | 路径 | 消费的字段（handoff-schema §4） |
|---|---|---|
| `plaud-theme-dev` | A | `ChangeSetId` `BaseHeadSha` `ChangeSetFingerprint` `AssessmentRef` `Path` `ReconMode` `ModifiedFiles` `RootCause` `RequiredQAProfile` `ThemeCheckRequired` `VisualRegressionRequired` `BuildRequired` `BlockingGaps` |
| `plaud-theme-section-build` | B | 同上（`RootCause` 为 `N/A`） |
| `plaud-theme-ux-migration` | C | 同上 |
| `plaud-theme-impact`（间接） | A/B/C | §3 的 `AssessmentRef` `ActualAffectedInstances` `SharedPropagation` `EvidenceCommands` `RequiredQAProfile` —— QA 复算而非照抄 |
| `plaud-theme-orchestrator` | 全流程 | 调度本 skill，并接收 §5 结果做阶段门 |
| **`plaud-theme-qa-intake`** | A/B/C | §9.1.2 的 `SubmissionId` `SubmissionPackageStatus` `PreviewManifest` `TargetSites` `ThemeIds` —— 据此判 `QAAdmissionStatus`（Step 0，早于指纹校验） |

**准入门（Step 0，最早）**：三查——intake 的 `ChangeSetId` / `ChangeSetFingerprint` 与 Implement 工件逐字比对（防重放）、重算 `PackageFingerprint`（防准入后替换）、`SubmissionPackageStatus`。

`Blocked` 之后**跑不跑检查取决于原因**：

| 原因 | 跑不跑 | `ReadyForDelivery` |
|---|---|---|
| 绑定失配 / 材料不齐 / 无工件 | **零执行**（准入门的强制效果） | `No` |
| **用户主动弃提测材料** | **照跑技术检查项** | `No` |

**唯一免提测包（`SubmissionId: N/A` + `Accepted`）的情形是零改动只读任务。** 用户弃流程**不产生** `Accepted`。「改动很小」不是理由——那是 `InlineLite` 的判据。

**入口前置门**：缺 `ChangeSetId` / `ChangeSetFingerprint` / `BaseHeadSha` / `ModifiedFiles` 任一项，或三样比对不上 → 停机，`ChangeSetIdMatched: No` + `ReadyForDelivery: No`，要求上游重新输出 §4 工件。零改动任务走 §2 的只读通道（`ChangeSetId: N/A` + `ReadOnlyProof`，`ReadyForDelivery: N/A(ReadOnly)`）。

## 下游（ConsumerSkill）

本 skill 是阶段轴终点，没有下游 skill。产出的去向：

| 去向 | 内容 |
|---|---|
| 用户 / `plaud-theme-orchestrator` | §5 契约块，作为交付判定 |
| 实现 skill（`ReadyForDelivery: No` 时） | `ProfileSpecificResults` 中的 `Failed` 项 + `BlockingGaps`，回到 Implement 阶段修复，**修完必须重新生成 `ChangeSetId`** |
| **`plaud-theme-release-ops`**（`ReadyForDelivery: Yes` 时） | QA 结论 + `ChangeSetId` + `FingerprintVerifiedAt`，供发版前核对。**QA 通过 ≠ 可发版**，还需运营验收与站点二次确认（handoff-schema §1.1） |
| **`plaud-theme-feedback-triage`**（QA 打回后有争议时） | `Failed` 项作为反馈条目，判缺陷还是变更 |
| `plaud-theme-impact`（`Blocked` 于影响面时） | 退回 Assess 重做 `ActualAffectedInstances` |
| 项目侧 `memory/changeset-log.md` | 追溯记录（**不随包分发**） |

## 不做的事

- 不改任何主题文件；发现问题只报，不顺手修（顺手修 = ChangeSet 失配 = 自己把自己判停机）
- 不做根因分析、不出方案
- 不写迁移日志内容、不代替用户验收（`ReadyForDelivery: Yes` ≠ 用户已验收）
- 不复制 `plaud-theme-shared/references/` 里的视觉 / spec 数值——只引用文件名

## 与 shared 的关系

| shared 条款 | 本 skill 的落地 |
|---|---|
| §1 交付权 | 唯一实现方 |
| §2 ChangeSetId | 消费方，回填 `ChangeSetIdMatched` + `FingerprintVerifiedAt`；文件集合 / `ChangeSetFingerprint` / `BaseHeadSha` 三样任一失配即停机；指纹算法照抄 §2，不自造变体 |
| §5 Verify 工件 | 输出契约，字段一字不差 |
| §6 Theme Check 门 | 执行手册见 `references/theme-check-gate.md`（baseline 增量） |
| §7 Stop, don't guess | 拿不到 ChangeSetId / 无法预览 / 解析失败 → 停机或 `Blocked`，不猜 |
| §8.1 运营协作红线 | DTC §2.1 硬性 10 条由 `StyleHardRuleCheck` 覆盖（`qa-global.md` §9）；§2.2 软性项进 `Advisories`，**不阻断交付**（§10） |
| §8 全路径红线 | 红线 1/2/3/5/8 由 QA-Global 七项覆盖；**红线 4（颜色 token）、6（JS 生命周期）、7（build 产物）§5 profile 表未覆盖全路径，由 `qa-global.md` §8 的附加触发式检查补上**，结果写进 `ProfileSpecificResults`，不新增 yaml 字段 |

阈值数值（对比度下限、图片 DPI 倍率、断点、字阶、间距）一律现读 `plaud-theme-shared/references/` 的当前值——本包只引用文件名，不留副本。唯一例外是 `BreakpointsCovered` 的五档，它由 handoff-schema §5 字段说明直接规定，属契约本身。
