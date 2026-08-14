# plaud-theme-dev — Matrix Contract

**位置**：Path A（通用主题开发）· Implement 阶段 · order 3
**契约源**：`plaud-theme-shared/references/handoff-schema.md`（唯一事实源；本文件只做定位说明，字段定义以 shared 为准，冲突时以 shared 为准）

---

## 上游

| 来源 | 传入 | 缺失时 |
|---|---|---|
| `plaud-theme-impact`（Assess，`ReconMode: LegacyImpact`） | `handoff-schema.md` §3 的 Assess 工件，尤其 `ActualAffectedInstances` / `TheoreticalReferences` / `DisabledInstances` / `SharedPropagation` / `LegacyImpact` / `EntrypointCandidates` / `RiskTier` / `RequiredQAProfile` / `BlockingGaps` | **停机**，先做 Assess。唯一例外是满足 §3 全部条件的 `InlineLite` 豁免 |
| `plaud-theme-orchestrator` | 跨 section / 交叉路径场景下的调度与路径判定 | 普通 bugfix 不经 orchestrator，用户可直接调用本 skill |
| 用户 | 目标文件路径、方案拍板、模板存值编辑授权、浏览器预览结果 | 任一缺失 → `BlockingGaps` 非空，停机要材料 |

`AssessmentRef` 的 `BlockingGaps` 非空 → **不得进入 Implement**。

## 下游：`plaud-theme-qa-intake` → `plaud-theme-qa`

> 🔴 **v0.2.0 起下游是 `plaud-theme-qa-intake`（提测准入），不是 `plaud-theme-qa`。** 交出 ChangeSet 后先过提测包校验（DTC §四「缺一不进验收」），材料齐了 QA 才启动。见 handoff-schema §0.1 / §9.1.2。

| 去向 | 传出 | 约束 |
|---|---|---|
| **① `plaud-theme-qa-intake`（提测准入，直接下游）** | `handoff-schema.md` §4 的 Implement 工件 | 本 skill 的话到此为止，下一句由 `qa-intake` 说。它校验提测包并产出 §9.1.2 工件；只有 `SubmissionPackageStatus: Complete` 才放行到 QA，材料不齐则 `QAAdmissionStatus: Blocked`、QA 零验证项执行 |
| ② `plaud-theme-qa`（Verify，**经 intake 转交，不直接对接**） | 同上工件，由 intake 转交 | 绑定凭据是 `ChangeSetId` + 身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）；`BaseHeadSha` 是开工前 baseline，required 且必须可解析，但不再是失配判据：`ModifiedFiles` 必须与工作树一致，且指纹必须由**交付当刻**生成。QA 在任何检查之前重算比对，任一不符 → `ChangeSetIdMatched: No` 并停机 |

`NextRequiredSkill` 恒为 `plaud-theme-qa-intake`（唯一例外是零改动只读任务，填 `None`——§2 明文规定零改动免 QA）。**有改动的任务任何情况下不得跳过 Verify。**

---

## 本 skill 的权限边界

**有权：**
- 判定机制层根因（`RootCause`）
- 提出并取舍实现方案（`OptionsConsidered`）
- 落地最小化实现（`ModifiedFiles`）
- 生成 `ChangeSetId`（格式 `CS-<YYYYMMDD>-A<NN>`）
- 标明待 QA 验证的点

**无权：**
- 收集影响面事实（`plaud-theme-impact` 的职责；本 skill 只消费其结论，不重做，也不用自己顺手 grep 代替）
- 执行验证或判定任何检查项的 `Passed`（`plaud-theme-qa` 的职责）
- 输出 `ReadyForDelivery: Yes`（`handoff-schema.md` §1，不可协商）
- 使用终态措辞（「修好了」「可以上线」「全部通过」「没问题了」「已验收」「交付完成」）
- 修改 `templates/*.json` 模板存值（默认只读，需用户明确授权）
- 手改 build 产物（红线 §8.7）
- 走 Path B / Path C 的实现规则（分别属于 `plaud-theme-section-build` / `plaud-theme-ux-migration`）

---

## 常量字段

以下四项在本 skill 的输出中恒定，任何情况下不得改写（`NextRequiredSkill` / `ReadyForDelivery` 的唯一变形见「只读任务」一节，由 shared §2 明文规定）：

```yaml
Path: A
QAStatus: NotRun            # 唯一其它合法值：Skipped(UserWaived)，仍配 ReadyForDelivery: No
NextRequiredSkill: plaud-theme-qa-intake
ReadyForDelivery: No
```

`RequiredQAProfile` 恒含 `QA-A`。🔴 **不得含 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进上游工件是字段越界（`handoff-schema.md` §9.2）。

---

## 路径归属边界

| 信号 | 归属 |
|---|---|
| bug / 性能 / 新功能 / UX 微调 / code review / A11y 审计 | **本 skill（Path A）** |
| Figma / 设计稿 / 新建 `sa-*` section / Section AI | `plaud-theme-section-build`（Path B） |
| UX Spec v1.3 / 刷模块 / spec 迁移 / 对齐 ux / 迁移日志 | `plaud-theme-ux-migration`（Path C） |
| B / C 与 A 交叉 | 走 B / C 的实现规则；**Path A 的质量规则全局继承，永远适用** |

---

## 只读任务（code review / A11y 审计）的契约变形

**取值全部由 `handoff-schema.md` §2「零改动任务」规定，本节只做转述，不覆盖 shared、不新增约定。冲突时以 shared 为准。**

`ChangeSetId: N/A`、`BaseHeadSha: N/A`、`ObjectFormat: N/A`、`ThemeTreeOid: N/A`、`ChangeSetScopeFingerprint: N/A`、`ModifiedFiles: []`、`AssessmentRef: N/A(ReadOnly)`、`ReconMode: N/A(ReadOnly)`、`ThemeCheckRequired: No`、`VisualRegressionRequired: No`、`BuildRequired: No`、`OptionsConsidered: Trivial`、`QAStatus: NotRun`、`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`。

`ReadOnlyProof` **必填**：审计前后各跑一次 **§2.5 的 `plaud_theme_tree`**（整段原样复制；**不得**用 `git status | shasum`——它不含内容、可被绕过，见 handoff-schema §2 零改动小节），判据是两次的 `ObjectFormat` + `ThemeTreeOid` 逐字相等（**不比 HEAD**：期间别人 commit 不影响本次是否只读），两次必须一致。不一致 = 这不是只读任务 → 退出只读通道，生成正式 `ChangeSetId` + 指纹，走完 Assess → Implement → Verify。

**不得借用 `ReconMode: InlineLite`** 表示只读（§2 明文禁止）。

**归属**：无 `ChangeSetId` 的 code review / A11y 审计归本 skill，不归 `plaud-theme-qa`——QA 的触发前提是「已有 `ChangeSetId`」或「用户明确要最终交付判定**且该任务确有改动**」。🔴 **用户要求「最终判定」不能把零改动任务推给 QA**（v0.2.2 第八轮）：QA 对所有零改动请求恒转回本 skill，两边都写「归对方」就成了死循环。本 skill 此时按 §2 只读通道收尾，并说明零改动不存在交付判定。
审计后若用户要求动手改 → 那是**新的一次 Implement**，重新生成 `ChangeSetId`，重走 Assess 判定。
