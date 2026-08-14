---
name: plaud-theme-qa
description: >
  PLAUD Shopify 主题矩阵的 Verify 阶段（order 7）——矩阵唯一有权宣布可交付的 skill。
  触发前提二选一，缺一不得路由到本 skill：已存在 ChangeSetId / HandoffContract，
  或用户明确要求最终交付判定**且该任务确有改动**（零改动只读任务恒归 plaud-theme-dev，用户点名也不接）。进入前还须先过 plaud-theme-qa-intake 的提测准入
  （SubmissionPackageStatus: Complete），材料不齐则 QAAdmissionStatus: Blocked、零验证项执行。该前提之外的 review / 审计请求都不属于本 skill。
  在此前提下覆盖：验收、验证、回归、上线前检查、发布前 review、能不能发了、可以上线吗、
  QA、质检、theme check、lint、静态检查、断点回归、5 断点、PC/1599/1279/767/375、视觉回归、
  德语长文案测试、英译德溢出、多语言验收，以及同样以该前提为限的 A11y 审计、无障碍、对比度、
  focus-visible、code review、写死宽高、图片清晰度、文案可配置性、空配置与满配置双测、
  schema 完整性、disabled 实例核对、同族 bug 扫描、依赖树回归、Swiper effect 约束；
  实现 skill 交出 ChangeSetId + ObjectFormat + ThemeTreeOid + ChangeSetScopeFingerprint
  时必须调用本 skill。
  也覆盖**集成 QA**（QAScope: Integration）：多块同批发版前对合并后的那棵树取证、
  集成验收、合并后回归、多个 ChangeSet 一起发、cohort 发布前的最终验证——
  但没有 plaud-theme-orchestrator 的 IntegrationPlan（集成者 / 集成基准 / 成员清单 /
  **集成结果树 IntegrationResultTreeOid**）时不接，先回 plaud-theme-orchestrator 要集成计划
  或要集成者补取证；本 skill 不做 merge、也不代算集成结果树的 oid，只对集成完成后的树取证。
  只有本 skill 能输出 ReadyForDelivery: Yes；别的 skill 说「改完了」都不算交付许可。
  不要路由到本 skill：提测材料齐不齐、预览链接、配置/测试文档、断点截图、推送站点清单 →
  plaud-theme-qa-intake；反馈算缺陷还是变更、要不要计返工、Linear 状态 → plaud-theme-feedback-triage；
  发版推站、上线后 bug 时效、回归用例入库 → plaud-theme-release-ops。
  没有 ChangeSetId、用户也没要交付判定的只读 code review / A11y 审计 /
  无障碍 / 对比度检查归 plaud-theme-dev（走零改动通道出 ReadOnlyProof，不进 Verify）；
  没有 ChangeSet 的找 bug / 性能优化 / 写代码 → plaud-theme-dev；
  改前影响面评估、blast radius、依赖树测绘 → plaud-theme-impact；
  新建 sa-* section → plaud-theme-section-build；UX Spec 迁移 → plaud-theme-ux-migration。
  本 skill 不写代码、不修 bug、不新建 section——只做取证与判定。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme QA（Verify 阶段，唯一交付权）

开工前必读 `plaud-theme-shared/references/handoff-schema.md`（§1 交付权、§2 ChangeSetId、§5 本 skill 产出契约、§6 Theme Check 门）。本文件不重复其中的数值与红线，只引用。

## 铁律：证据，不是声明

> **每一项检查都必须给出命令原文或可复核的证据。「我看过了」「已检查」「应该没问题」一律视为未执行。**

- 每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`（handoff-schema §5 开头）。**禁止勾选框、禁止叙述式过关。**
  > 🟢 **`FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 三项曾被记为「§5 与 §9.2 枚举不一致」，v0.2.0 复核后确认两处一致、该缺口不存在**，v0.2.0 起已删除该提示。四值全部合法，不必再在 `BlockingGaps` 登记契约歧义。
- `Blocked` 必须附原因（缺什么、为什么拿不到）。
- `Passed` 必须在 `Evidence` 里有对应条目：命令原文 + 输出摘要，或明确的观察对象（文件:行号 / 截图 / 预览 URL）。
- `NotApplicable` 必须附一句"为什么不适用"（例如"本次未改 JS，无生命周期清理面"）。
- **`Evidence` 为空的检查项，无论标了什么，一律降级为 `Blocked`。**
- 任一项非 `Passed` / `NotApplicable` → `ReadyForDelivery: No`（块 QA 同时 `ReadyForIntegration: No`）。`Blocked` 不折算为 pass。

## 本 skill 不做什么

- 不改任何 `sections/` `snippets/` `assets/` `templates/` `locales/` 文件。发现问题只报，不顺手修。
- 不做根因分析、不出修复方案——那是实现 skill 的职责。
- 不写迁移日志内容（那是 `plaud-theme-ux-migration` 在用户验收后做的事）。
- 不替实现 skill 补 `ChangeSetId`；拿不到就停机要。

---

## 执行顺序（不可跳步）

```
Step 0  取上游工件（ChangeSetId / ObjectFormat / ThemeTreeOid / ChangeSetScopeFingerprint /
        BaseHeadSha（溯源 + diff 基准，**不与当前 HEAD 比对**）/ ModifiedFiles /
        RequiredQAProfile / ThemeCheckRequired…）+ 提测包工件（SubmissionId /
        SubmissionPackageStatus，来自 plaud-theme-qa-intake）
        → 判 QAScope 与 QAAdmissionStatus  ← 准入门，比对象校验更早
Step 1  四重绑定校验（文件集合 + ObjectFormat + ThemeTreeOid + ChangeSetScopeFingerprint）
        ← 前置门，先于任何检查；不过就停机，后面一步都不做
        通过后**立刻 plaud_stage_workspace 物化**（记 StageDirRef / VerifiedThemeTreeOid），
        并跑 plaud_declared_diff 填 DeclaredDiffCheck / DiffBaseTreeOid
Step 2  登记「收尾必须重算 ThemeTreeOid」这项义务（三个时点：物化前 / 物化回环 / 收尾）
Step 3  QA-Global（恒执行）—— **在 StageDirRef 指向的 workspace 快照里跑**
Step 4  路径 profile（QA-A / QA-B / QA-C，可多选）—— 同上
Step 5  收尾重算 ThemeTreeOid 与 Step 1 比对 → 判 ReadyForIntegration →
        判 ReadyForDelivery（§2.11 第一层四条）→ 最后才写 memory/changeset-log.md
Step 6  输出 §5 契约 yaml 块（35 字段）
```

> ⚠️ **Step 2 不是"在 Step 3 之前再算一次"。** 它在这里只是登记义务；收尾那一次重算的时点是**所有检查跑完之后、写 changeset-log 之前**（Step 5 的第一件事）。提前算等于没算。

> 🔴 **三条环境前提，拿不到就是 `Blocked`**（handoff-schema §2.3）：可写的 `TMPDIR`（`mktemp` 失败 → 取证函数 fail closed）、git ≥ 2.25（`GIT_TOO_OLD`）、**只支持 macOS / Linux**（Windows 上的典型 git 配置——`core.fileMode` 为假、`core.autocrlf` 为真，**具体取值随安装时的选项而定，不要写成「默认必然如此」**——会直接命中两道字节保真门）。命中任一条：全部身份 / 归属检查填 `Blocked` + 理由（"平台不支持 / 字节保真前提不满足"），**不得填 `Passed` 或 `NotApplicable`**。

---

## Step 0 — 提测准入门（`QAAdmissionStatus`）

**这道门比对象绑定校验还早。** 依据 DTC《开发交付标准 v1.0》§四：「提测时必须同时提供，**缺一不进验收**」——材料不齐，验收根本不开始。

取 `plaud-theme-qa-intake` 的 `ArtifactKind: QAIntake` 工件（handoff-schema §9.1.2）。

**四项都要查，缺一即 `Blocked`：**

```bash
# (1) 提测包绑的是不是本次这个对象 —— 防重放。逐字比对，不是"看着像"
#     QAScope: SingleChangeSet —— 四项逐字比：
#       intake.ChangeSetId               == implement.ChangeSetId
#       intake.ObjectFormat              == implement.ObjectFormat
#       intake.ThemeTreeOid              == implement.ThemeTreeOid
#       intake.ChangeSetScopeFingerprint == implement.ChangeSetScopeFingerprint
#         🔴 ScopeFP 是 `<ScopeTreeOid> <ScopeDigest>` 两段，必须**两段一起**逐字比：
#            删除只体现在 ScopeDigest 的 absent 行，单比 ScopeTreeOid 会漏
#     QAScope: Integration —— 见下方「集成 QA 的准入」：集成提测包的顶层
#       ChangeSetScopeFingerprint 是 N/A(Integration)，比对**逐成员**做，
#       不拿那个 N/A 去凑三元组

# (2) 材料在 intake 之后有没有被换过 —— 防替换
#     cd 到 intake.PackageRootRef，export PLAUD_PACKAGE_ROOT="$(pwd -P)"，
#     用 §9.1.2 的 plaud_package_fingerprint 重算，与 intake.PackageFingerprint 精确比对
#     🔴 必须在材料**根目录**跑并设 PLAUD_PACKAGE_ROOT（v0.2.2 第十轮补）：该函数此前没有
#        根守卫，在子目录跑会静默算出子集指纹且 rc=0。危险的不是失配 —— 是 intake 与本 skill
#        用同一个错误的 PackageRootRef 时**两边算出同一个值、Accepted 照发**，而自测报告 /
#        配置说明 / 截图全部不在绑定链里。拿到 NOT_PACKAGE_ROOT / NO_PACKAGE_ROOT 一律 Blocked
#     🔴 云端材料还要**重新查远端当前 revision / digest**，与 manifest 记录值比对——
#        只比本地 manifest 的话，manifest 没更新而云文档内容变了照样通过
#     拿到 PACKAGE_FINGERPRINT_FAILED / 空值 / 取不到远端 revision → Blocked，不得放行

# (3) SubmissionPackageStatus

# (4) 测试集三行的绑定自洽 —— 逐字比对，不需要访问任何外部系统
#     比的是 ID@revision 前缀段（日志列存的是完整原文，取第一个 ; 之前那段）。
#     (4a) 填了完整迁移声明时：
#          intake.TestSetMigrationRef.From == intake.PreviousAcceptedTestSetTrace 的 ID@revision
#          intake.TestSetMigrationRef.To   == intake.TestSetTrace 的 ID@revision
#          且**当 memory/changeset-log.md 里存在非 N/A 的 TestSetTrace 行时**（= intake 走的是取数路径①），
#          From 还要等于其中最近一条的同一前缀段。日志确无该行（路径②/③）时不得再拿日志卡它。
#     (4b) 填 N/A(SameDocument) 时：本轮 TestSetTrace 与 PreviousAcceptedTestSetTrace 的稳定文档 ID
#          **必须真的相同**——不同却填 SameDocument 是自相矛盾，不是可跳过项。
#     (4c) 填 N/A(NoPreviousTrace) 时：PreviousAcceptedTestSetTrace 必须确为 None(FirstSubmission)
#          或 Unavailable(...)——有具体上一轮 trace 却填 NoPreviousTrace 同样是自相矛盾。
#     (4d) 迁移清单的自洽性复核（在重算 PackageFingerprint 时顺带做，不额外取数）：
#          ReasonRef / CaseDisposition 的 locator 未悬空、清单条数 == OldCaseCount、
#          旧用例 ID 无重复、Mapped 的 Dropped 行理由非空、BulkRetired 的 RetireReason 非空。
#          🔴 CaseDisposition 的清单只能是 Local(...)：它在材料目录里、内容已进 PackageFingerprint，
#             读它不需要额外取数。Manifest(...)（云端）不得用于清单——远端复核只取 revision/digest，
#             拿不到内容，条数/重复 ID 根本没法核。判据唯一见 package-checklist.md §3.1
#     (4e) N/A 与 Previous 的**双向**约束：
#          Previous 为 None(FirstSubmission) / Unavailable(...) → TestSetMigrationRef **必须**是
#          N/A(NoPreviousTrace)（此时也不得再提交完整迁移声明——没有 From 可比，声明无从核验）；
#          Previous 是具体一行 → 不得填 N/A(NoPreviousTrace)。两个方向都要核，只核单向可以被绕过。
```

| 情形 | `QAAdmissionStatus` / `QAAdmissionReason` | 后续 |
|---|---|---|
| **四项全对**且 `SubmissionPackageStatus: Complete` | `Accepted` / `Normal` | 继续 Step 1 |
| intake 绑的 `ChangeSetId` / `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` 与 Implement 工件对不上 | `Blocked` / **`BindingMismatch`** | 停机 —— **这是一份别的任务的提测包**，不得复用 |
| `QAScope: Integration` 却拿不到 `IntegrationPlan`，或 `IntegrationOf` 为空 / `ChangeSetId` 不是 `N/A(Integration)` | `Blocked` / **`MissingArtifact`** | 停机 —— 契约违规。回 `plaud-theme-orchestrator` 要集成计划，**不得**自己拟一份 |
| `PackageFingerprint` 或云端 revision 重算不一致 | `Blocked` / **`BindingMismatch`** | 停机 —— 材料在准入之后被改过 |
| `TestSetMigrationRef` **字段齐全但绑定对不上**（(4a) 的 `From` / `To` 比对失败，或 (4b)/(4c)/(4e) 的 `N/A` 与实际 trace 自相矛盾——含「Previous 明明是具体一行却填 `N/A(NoPreviousTrace)`」与「Previous 是 `Unavailable` 却仍提交完整迁移声明」两个方向） | `Blocked` / **`BindingMismatch`** | 停机 —— 声明迁自 A、历史记录却是 B |
| `TestSetMigrationRef` **缺失 / 语法坏 / `Reason` 越界 / locator 悬空或跑出材料根 / 清单用了 `Manifest(...)` / 清单条数与 `OldCaseCount` 对不上 / 旧 ID 重复 / `Dropped` 理由或 `RetireReason` 为空**（ID 变了却没有合法迁移声明） | `Blocked` / **`PackageIncomplete`** | 停机 —— 这是 intake 该判 `Incomplete` 的项，本应到不了这里；退回 `plaud-theme-qa-intake` 重出 |
| `PreviousAcceptedTestSetTrace` 为 `Unavailable(...)` / `None(FirstSubmission)` **且** `TestSetMigrationRef: N/A(NoPreviousTrace)`（两者必须同时成立，见 (4e)；只满足其一是自相矛盾，走上一行的 `BindingMismatch`），其余项都对 | **不阻断**（照常 `Accepted`） | 在 `Advisories` 记「测试集跨轮次连续性本轮无法核验」+ 属于 `package-checklist.md` §3 取数路径③ 的哪一种；**不进 `BlockingGaps`** |
| `SubmissionPackageStatus: Incomplete` | `Blocked` / `PackageIncomplete` | 停机，零执行 |
| 压根没有提测包工件 | `Blocked` / `MissingArtifact` | 停机，零执行 |
| 用户主动弃提测材料 | `Blocked` / `UserWaivedMaterials` | **照跑技术检查项**，`Evidence` 记弃流程的出处 |

> 🔴 **表里没有零改动只读任务这一行，这是刻意的**（v0.2.2 第七轮废止该分支，第八轮清掉残留表头与旧行）：§5 的 35 字段里既没有 `ModifiedFiles` 也没有 `ReadOnlyProof`，本 skill 结构上就无法为零改动任务输出完整契约。收到这类请求 → 转 `plaud-theme-dev` 的零改动通道，**不输出 §5 工件、不发 `Accepted`**（详见下方「(b) 真正的零改动任务」）。
**`Blocked` 之后跑不跑检查，取决于是哪种 Blocked：**

| Blocked 的原因 | 跑不跑检查 | 为什么 |
|---|---|---|
| 绑定失配（intake 的 `ChangeSetId` / 三元组对不上，或 `PackageFingerprint` 重算不符） | **零执行** | 根本不知道在验什么——验了也不能归属到任何 ChangeSet |
| `SubmissionPackageStatus: Incomplete`（材料不齐） | **零执行** | 这是准入门本身的强制效果。DTC：「缺一不进验收」——验收就是不开始 |
| **用户明确弃提测流程** | **照常执行技术检查项** | 绑定是有效的，只是用户主动放弃了材料这道门。此时验证本身有意义，只是不产生许可 |

前两种的输出：`ReadyForDelivery: No`、**十一个**状态字段与 `ProfileSpecificResults` 一律 `Blocked`（原因写"提测包不全/绑定失配，未执行"）、把 qa-intake 的 `BlockingGaps` **原样带出**（不要改写成自己的话，运营要按它去补材料）。

第三种的输出：`QAAdmissionStatus: Blocked` + 各检查项照实填实际结果（`Passed`/`Failed`/...），但 `ReadyForDelivery` **恒为 `No`**（判定条件第 0 条不满足），`BlockingGaps` 写"用户弃提测流程，未经完整交付流程"。

> 🔴 **三种都不产生 `Accepted`。** 区别只在"验不验"，不在"给不给许可"。

**关于零改动只读任务**：它**不进本 skill**（handoff-schema §2 / §5 准入门第 3 条），所以本 skill 里不存在「免提测包却给 `Accepted`」这条路。转 `plaud-theme-dev`。

> 🔴 **用户说"不走提测流程"不产生 `Accepted`。** 此时 `QAAdmissionStatus` 仍为 `Blocked`，走上表第三行：照常执行技术检查项，`ReadyForDelivery` 恒为 `No`，正文一句话说明风险由用户承担。用户可以决定不交材料，但不能因此拿到一张"准入通过"的记录。

> 🔴 **「改动很小」不是免除理由。** 那是 `ReconMode: InlineLite` 的判据（Assess 豁免），与提测材料无关。QA **不得**自行免除提测包。

> 🔴 **提测包里的 8 张断点截图不能顶替本 skill 的断点回归。** 前者是交付材料，后者是 QA 实跑（`BreakpointsCovered`，Path C 为 `PC / 1599 / 1279 / 767 / 375`）。看到提测包有截图就跳过回归 = 谎报。记 `PC` 时写出实际像素宽度。

### 判 `QAScope`：单块还是集成

`QAScope` 不由用户口头决定，也不"看起来像"，靠字段判：

| 事实 | `SingleChangeSet` | `Integration` |
|---|---|---|
| 上游工件 | 一份 §4 Implement 工件 | **没有**「集成的 §4 工件」——集成不是任何 skill 的实现产出 |
| `ChangeSetId` | 具体编号 | `N/A(Integration)` |
| `IntegrationOf` | `N/A` | **必填非空**（`PlanRef` / `BaseTreeOid` / `Members[]`） |
| 提测包 | 该块的提测包 | **集成提测包**（§9.1.2 的 `ChangeSetId: N/A(Integration)` + `IntegrationOf`） |
| `DeclaredDiffCheck` 的基准 | `BaseHeadSha` | `IntegrationPlan.IntegrationBaseCommit` |
| `ReadyForIntegration` | `Yes` / `No` | 恒 `N/A(Integration)` |

🔴 **没有 `IntegrationPlan` 就没有集成 QA。** `IntegrationPlan` 是 `plaud-theme-orchestrator` 的 §9.1 协调工件里的一个字段（`Integrator` / `IntegrationBaseCommit` / `IntegrationBaseTreeOid` / `MemberChangeSets` / …），**由用户或 orchestrator 把那份协调工件递给本 skill**。拿不到 → **不要自己拟一份**，回 `plaud-theme-orchestrator` 要；无人认领集成时它同样停机要授权（§2.13）。

🔴 **本 skill 不做 merge**（§2.13）。集成是**人**的动作（用户 / 具体 owner），矩阵只在集成完成后对那棵树取证。

### 集成 QA 的准入（`QAScope: Integration`）

**集成 QA 不走 Step 1 的单块 §4 结构核**——集成没有 §4 工件，套 22 字段门会把每一个合法集成请求都误挡。改为逐成员核这四件事：

| 核什么 | 事实源 | 取不到 / 不成立时 |
|---|---|---|
| `IntegrationOf.PlanRef` 能解析到那份 §9.1 协调工件，且 `IntegrationOf.Members` 与 `IntegrationPlan.MemberChangeSets` **集合相等且无重复** | orchestrator 的 §9.1 协调工件 | `Blocked` / `MissingArtifact`，停机 |
| 每个 `Members[].ImplementArtifactRef` 可解析，且该块 §4 工件的 `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` 与 `Members[]` 里抄的值**逐字相等** | 各块 §4 Implement 工件 | `Blocked` / `MissingArtifact`（解析不到）或 `BindingMismatch`（值对不上），停机 |
| 每个 `Members[].QARef` 可解析到该块的 §5 工件，且其 `ReadyForIntegration: Yes` | 各块自己的 QA 工件 | 停机 —— 未验过的块不得进集成，**不得**用集成 QA 顺带把它验了 |
| 每个 `Members[].SubmissionId` 与集成提测包 `IntegrationOf` 里列的逐块 `SubmissionId` **一一对应**，且各自 `SubmissionPackageStatus: Complete` | §9.1.2 集成提测包 | `Blocked` / `PackageIncomplete`，停机 |
| 集成提测包顶层的 `ObjectFormat` / `ThemeTreeOid` 逐字等于 `IntegrationPlan.IntegrationResultTreeOid`，且与本轮 `plaud_theme_tree` 现算值逐字相等（三方等式，见下方红框） | orchestrator 的 §9.1 协调工件（**已补第 6 项的那一版**）+ §9.1.2 集成提测包 + 本轮现算 | 缺失 → `Blocked` / `MissingArtifact`；不等 → `Blocked` / `BindingMismatch`。均停机，**不得**由本 skill 代算 |

> 🔴 **集成提测包顶层的 `ObjectFormat` / `ThemeTreeOid` 是三方等式的中间一环**（v0.3.0 收尾验收补齐：此前这里写着"没有闭合的 producer、该项恒 `Blocked`"，那个缺口已由 canonical §9.1 的 `IntegrationPlan.IntegrationResultTreeOid` 填上）。
> 三方是：**`IntegrationPlan.IntegrationResultTreeOid`**（producer = `Integrator` 那个人，集成落盘后跑 `plaud_theme_tree` 取前两段）→ **集成提测包顶层**（qa-intake **原样透传**）→ **本 skill 现算**。
> 本 skill 的做法是把三者逐字比 ——
> - 三者都在且逐字相等（含 `ObjectFormat` 相同）→ 这项绑定成立，继续；
> - 都在但任意两者不等 → `QAAdmissionStatus: Blocked` / `BindingMismatch`。**分清指向**：intake 值 ≠ Plan 值 = 材料绑的不是集成者声明的那棵树；现算值 ≠ 另两者 = 准入之后树被改过。两种都停机，`Evidence` 写清是哪一对不等；
> - 协调工件没补 `IntegrationResultTreeOid`（还是规划期那一版），或 intake 没填 / 填了 `N/A` → `QAAdmissionStatus: Blocked` / **`MissingArtifact`**，`BlockingGaps` 指名要 `Integrator` 先补取证、qa-intake 重出集成包。
> 🔴 **不得由 QA 自己现算一个值回填进 intake 工件、或直接拿现算值当"已核对"** —— 那是自证，等于什么都没绑住。同理**不得**让 qa-intake 现算：取证方（集成者）与验证方（本 skill）必须是两个人，中间那一环只能是搬运。

---

## Step 1 — 身份绑定校验（前置门）+ 物化

**这是第一步，先于任何检查**（handoff-schema §2.8 要求 QA 在执行任何检查之前重算三个身份字段并逐字比对）。

🔴 **先做 §4 工件的结构核（v0.2.2 第六轮补），任一不满足就停机，不要"先跑起来再说"**（**仅 `QAScope: SingleChangeSet`**——集成 QA 没有 §4 工件，走 Step 0 的逐成员核）：

| 核什么 | 不满足时 |
|---|---|
| **22 个字段齐全**（handoff-schema §4；`ApprovedExceptions` 无声明填 `[]`、`OriginTriageRef` 非返工填 `N/A` —— **整字段缺失 ≠ 填 `[]`/`N/A`**） | 停机，`BlockingGaps` 写"§4 工件缺字段：<逐个列出>，需实现 skill 重新输出" |
| **字段取值在 §9.2 封闭枚举内** | 停机。**不得自行"纠正"**：把 `RequiredQAProfile` 里的非法 `QA-Global` 删掉照跑、或替上游补一个缺失取值，都等于替上游修工件，下一轮同样的错会再来一次 |
| `ChangeSetId` / `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` / `ModifiedFiles` 有值 | 同上 |
| `BaseHeadSha` 有值**且可解析**（`git -C <theme-root> rev-parse --verify "<BaseHeadSha>^{commit}"`） | 它**不再是失配判据**（§2.8），但缺失 / 不可解析 → `DeclaredDiffCheck: Blocked`、Theme Check 的 baseline 物化 `Blocked`、存量偏差举证 `Blocked`。**不是 `Advisories`，不是 `NotApplicable`**；而 `Blocked` 不折算为 pass → 本轮拿不到交付许可 |

输出 `ChangeSetIdMatched: No` + `ReadyForIntegration: No` + `ReadyForDelivery: No`，十一个检查项全 `Blocked`（原因写"§4 工件不合格，未执行"）。

handoff-schema §2.1 规定身份是**三个字段**（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`），连同文件集合一共**四样**要绑，**只比对文件名不合格**：

```bash
cd <theme-root>          # 🔴 必须是仓库根：取证函数带 NOT_REPO_ROOT 守卫

# 🔴 三个取证函数的**唯一事实源是 handoff-schema §2.5**。用的时候把那一整段**原样复制**，
#    不要凭记忆敲、不要删注释、不要自造变体：
#      · 漏掉一个 `-c core.hooksPath=/dev/null` 的抄本，会在取证时**执行仓库里的任意脚本**
#        （`git add` 触发 hook，既是副作用也是投毒入口）；
#      · 改一个字符（换 hash、加一个 sort、换 pathspec）两边算的就不是同一个东西，
#        正常交付会被全判成失配。
#    需要改进算法时改 shared，不要在本 skill 里分叉。

# (1) ObjectFormat + ThemeTreeOid —— 整棵可发布面的 tree
# 🔴 两行一起抄，**不要只抄第一行**：`plaud_theme_tree || echo "..."` 会打印错误串却让整段
#    rc=0，任何按 $? 分支或跑在 set -e 下的调用方都会以为这道门通过了。既看输出也看退出码。
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }
#     成功输出： <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest> [<objdir>]
#     🔴 ThemeTreeDigest **不进任何工件**：它只用于人读 diff 与跨 object-format 防误判，
#        不提供抗碰撞。

# (2) ChangeSetScopeFingerprint —— 只覆盖本块声明路径
#     pathlist 逐行照抄 §4 的 ModifiedFiles 路径，**逐字**、不 trim、不做 glob
printf '%s\n' <ModifiedFiles 的每一条路径> > "$SCOPE_LIST"
plaud_changeset_scope "$SCOPE_LIST" || { echo "SCOPE_FAILED"; exit 1; }
#     成功输出： <ObjectFormat> <ScopeTreeOid> <ScopeDigest>
#     🔴 身份要**后两段一起看**：删除只体现在 ScopeDigest 的 absent 行，单比 ScopeTreeOid 会漏

# (3) 文件集合 / 改动归属 —— DeclaredDiffCheck（§2.7）
#     base：QAScope: SingleChangeSet 用 BaseHeadSha；
#           QAScope: Integration     用 IntegrationPlan.IntegrationBaseCommit。
#           两者都必须可解析——没有基准就无法证明"树里只有已声明、已归属的改动"
plaud_declared_diff "<base-commit-ish>" "$SCOPE_LIST" || { echo "DECLARED_DIFF_FAILED"; exit 1; }
#     成功输出： <ObjectFormat> <BaseTreeOid> <ThemeTreeOid> DECLARED_DIFF_OK
#     第 2 段记进 DiffBaseTreeOid。失败形态：
#       DECLARED_DIFF_ORPHAN     树里有无主改动（兄弟块的半成品 / 别人的残留）
#       DECLARED_DIFF_UNCHANGED  声明了却没变（声明不实）
#       DIFF_BASE_UNREACHABLE    基准不可解析
#     🔴 它判的是**可发布路径集合**，不是逐项四元组比对：raw 记录只用于格式守卫，
#        "路径没变但 mode / 内容变了"由 ChangeSetScopeFingerprint 承担。不要在别处
#        把这道门表述成"四元组逐项相等"。
#     🔴 声明清单里的**非可发布路径**（build 源等）不参与本比对——它们不上线，
#        绑定由 ChangeSetScopeFingerprint 承担。
```

四样与上游 §4 工件逐项比对（**以下是 `QAScope: SingleChangeSet` 的判法**；集成 QA 的比法不同，见下方红框与「集成 QA」一节）：

| 情形 | 判定 |
|---|---|
| 四样全对 | `ChangeSetIdMatched: Yes`，`FingerprintVerifiedAt` 记 `Step1` 的重算值，继续 |
| `ObjectFormat` 不一致（换了仓库 / 换了 object format） | `No` — 停机。sha1 与 sha256 对**同一内容**算出的 oid 完全不同，**不得**"换算"或忽略 |
| `ThemeTreeOid` 不一致（可发布面的内容变了） | `No` — 停机。🔴 **哪怕本块的 `ChangeSetScopeFingerprint` 仍然相等也一样**：那说明别的块的改动已经落进同一棵树，按 §2.12 这就不是两次块 QA、而是**一次集成 QA 的一个副本**，必须改按 `QAScope: Integration` 处理（`DeclaredDiffCheck` 也会把它判成 `DECLARED_DIFF_ORPHAN`）。**不得**降级成 `Advisories` 继续 |
| `ChangeSetScopeFingerprint`（两段中任一段）不一致 | `No` — 停机。这正是只绑文件名会漏掉的情形：QA 会去验一批它从未见过的代码 |
| `DECLARED_DIFF_ORPHAN` / `DECLARED_DIFF_UNCHANGED` | `DeclaredDiffCheck: Failed` — 停机。它同时命中 §2.8 的「`ModifiedFiles` 与工作树文件集合不一致」，所以 `ChangeSetIdMatched` 一并判 `No`。**两者是同向的两项独立证据**，不是一个从另一个推出来的 |
| `DIFF_BASE_UNREACHABLE`（`BaseHeadSha` 缺失 / 不可解析） | `DeclaredDiffCheck: Blocked`（**不得**降级成 `Passed` 或 `NotApplicable`）。三元组照比，`ChangeSetIdMatched` 按能验到的部分如实判；§2.11 第一层第 3 条不满足 → `ReadyForDelivery: No` |
| 字节保真门命中（`BYTE_FIDELITY_ATTR` / `BYTE_FIDELITY_AUTOCRLF` / `CORE_FILEMODE_FALSE` / `SYMLINK_IN_*` / `GITLINK_IN_*` / `NEWLINE_IN_PATH*` / `GIT_TOO_OLD` / `OBJECT_FORMAT_UNKNOWN` …） | 取证不可用 → 停机。`DeclaredDiffCheck` 与十一个状态字段填 `Blocked`；**`ChangeSetIdMatched` 填 `No`**（它的封闭枚举只有 `Yes` / `No`，没有 `Blocked`，未校验一律填 `No`）。**不得**自行放行（细则见 `references/evidence-and-invalidation.md` §2.5） |
| `BaseHeadSha` 与当前 HEAD 不同（期间 commit / rebase / checkout） | 📎 **不是判据，v0.3.0 起解除**（§2.8）：payload 里没有 HEAD，实测 commit 前后 `ThemeTreeOid` 逐字不变。如实记进 `Evidence`，**不停机** |

> 🔴 **集成 QA 不套上面这张表的第 3 行。** `QAScope: Integration` 时，合法的集成树里本来就有多个块的改动，**整树 `ThemeTreeOid` 必然不等于任何一个成员 §4 工件里的 `ThemeTreeOid`** —— 拿它去逐成员比，会把每一次合法集成都判成失配。集成的比法是三层分开的：
>
> | 事实 | 与什么比 |
> |---|---|
> | **成员溯源** | 各成员 §4 工件的 `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`，与 `IntegrationOf.Members[]` 里抄的值逐字相等（证明 `Members[]` 没被改写） |
> | **成员在集成树里的身份** | 逐成员用**它自己的** `ModifiedFiles` 做 pathlist 跑 `plaud_changeset_scope`，在**集成树里重算**的 `ChangeSetScopeFingerprint` 必须与该成员 §4 工件的值逐字相等（证明这一块的内容原样进了集成树、没被合并改掉） |
> | **最终集成树** | 只进 `VerifiedThemeTreeOid` 与物化（`StageDirRef`），**不与任何成员的 `ThemeTreeOid` 比** |
>
> `ObjectFormat` 仍要求全体一致（成员之间、与本轮现算值之间）。

**失配时绝不可自行把额外改动"顺便一起验了"。** 正确做法：停下，要求实现 skill 重新生成 `ChangeSetId` + 三个身份字段 + `ModifiedFiles`，然后重跑 QA。

上游工件缺三元组任一项（只给了 `ModifiedFiles`）→ 同样停机，`BlockingGaps` 写"需要按 §2.1 补齐 `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`"。**不得**退化成只比文件名。
缺 `BaseHeadSha` 或它不可解析 → **不是失配**，但 `DeclaredDiffCheck: Blocked` + 交付许可拿不到（见上表）。

失配时输出的 yaml：

- **十一个状态字段**（`ThemeCheck` / `ThemeRuntimePreview` / `AdminSchemaSave` / `RegressionMatrix` / `LocalizationCheck` / `A11yCheck` / `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked`）与 `ProfileSpecificResults` 一律 `Blocked`（原因：ChangeSet 失配，未执行）。
  > ⚠️ `ApprovedExceptionsChecked` 在失配场景填 `Blocked`（该验但没验成），**不是** `NotApplicable` —— 后者只在 §4 的 `ApprovedExceptions` 确为 `[]` 时成立，而失配时根本没读到上游工件。
  > 🟢 **v0.2.0 已收口**：`FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 三项在 handoff-schema §5 与 §9.2 枚举表里**现已一致**，四值（`Passed`/`Failed`/`Blocked`/`NotApplicable`）都合法。v0.1.0 那条"枚举缺口"提示已废止，不必再在 `BlockingGaps` 登记该歧义。
  > 判定纪律不变：未执行填 `Blocked`，**绝不**改填 `NotApplicable`（未执行伪装成"不需要验"）、`Passed`、或 `Failed`（`Failed` 意为"验了且发现缺陷"，会让实现 skill 去追不存在的缺陷）。
- **记录字段不填状态枚举**：`QAProfilesRun: None`、`BreakpointsCovered: None`、`FingerprintVerifiedAt` 写 `Step1` 的重算结果与失配说明、`ThemeCheckEvidence` / `Evidence` 写一句"ChangeSet 失配，未执行"，`BlockingGaps` 写需要用户/上游做什么。往记录字段里塞 `Blocked` 是类型错误。
- `ChangeSetIdMatched: No`（该字段封闭枚举只有 `Yes` / `No`，**没有 `Blocked`**；未校验一律填 `No`）、`ReadyForIntegration: No`、`ReadyForDelivery: No`。

### 通过后立刻物化（`StageDirRef`）

**QA 不得在活工作树上跑**（handoff-schema §2.6）：重算相等之后、逐文件读取期间工作树还能再变（TOCTOU），验的会是一个从没被确认过的混合状态。

```bash
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/plaud-qa-stage.XXXXXX")"   # 🔴 必须是仓库外的空目录
plaud_stage_workspace "$STAGE" || { echo "STAGE_FAILED"; exit 1; }   # 🔴 同样两行一起抄
#   成功输出： <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>
```

- 输出的 `ThemeTreeOid` 必须与上面 (1) 的逐字相等 —— 这就是三次重算里的**第二次**（物化回环复算）。不等 → 停机。
- `StageDirRef` 记 `$STAGE` 的**绝对路径**，`VerifiedThemeTreeOid` 记本轮验的那个 oid。
- `STAGE_ROUNDTRIP_MISMATCH` / `STAGE_DST_INSIDE_REPO` / `STAGE_DST_NOT_EMPTY` / `STAGE_GIT_LEAKED` 任一 → 停机，**不得**改用活工作树"先跑起来"。
- 🔴 **用 `plaud_stage_workspace`，不是 `plaud_stage_verified`。** 后者只物化可发布面，那里**没有** `.theme-check.yml`、没有 build 源与 lockfile —— 在那种目录里"跑 theme check"是自相矛盾的。`plaud_stage_verified` 归 `plaud-theme-release-ops` 推站专用。
- 🔴 **不要把它称作"不可变快照"**（§2.6）。准确的边界是：只有**可发布面**有回环复算背书；非可发布面（`.theme-check.yml` / lockfile / build 源 / `memory/`）拷贝期间可以变化，非发布 symlink 按 `cp -RP` 保留因而仍可能指向快照外的可变对象，非发布目录下的嵌套 `.git` 会被一起拷进去，快照建成之后目录仍可被改。**QA 期间不要动它。**
- 代价如实记：workspace 快照是整棵工作树的拷贝，会包含 `node_modules` 之类的大目录。想省时间就**先清理工作树**，不要靠缩小拷贝范围 —— 缩了就跑不了它本来要跑的检查。

> **Theme Check 的 baseline 从 `BaseHeadSha` 物化**（`git archive <BaseHeadSha>^{tree}`，见 `references/theme-check-gate.md` §2）。baseline 的成立性由 **`BaseHeadSha` 可解析**保证，📎 **不再**由"HEAD 就是改动前状态"保证 —— v0.3.0 里 HEAD 不被校验，实施期间 commit 是合法的（§2.8）。

## Step 2 — 重算义务登记（QA 失效基线）

QA 通过后可发布内容再变，原 QA **自动失效**（handoff-schema §2.8）。所以 `ThemeTreeOid` 要算**三次**，`FingerprintVerifiedAt` 字段就是记这三次的：

| 时点 | 动作 |
|---|---|
| **Step 1（物化前）** | 已算过，与上游 §4 工件（或 `IntegrationOf.Members[]`）逐字比对，记为 `Step1` |
| **Stage（物化回环复算）** | `plaud_stage_workspace` 在快照里重新算的那一次，记为 `Stage` |
| **Step 5（所有检查完成后、写 changeset-log 之前）** | 再算一次，记为 `Step5` |

三次不完全一致 → 验证期间可发布内容又变了，本轮作废：`ReadyForIntegration: No` + `ReadyForDelivery: No`，`BlockingGaps` 写"验证期间可发布面变动，需重新生成 ChangeSetId"。

`FingerprintVerifiedAt` 要如实写出三次的时点与值，例如 `Step1(14:22) <oid> / Stage(14:23) <oid> / Step5(14:51) <oid> 三次一致`。只写"已核验"→ 视为证据为空。

**`memory/` 不在可发布面内**（可发布面 = `assets blocks config layout locales sections snippets templates` + 仓库根 `.shopifyignore`），所以写 `changeset-log.md` 天然不会改变 `ThemeTreeOid`。**但顺序仍建议保持**（先算完 `Step5` 再写 log）：它让证据链的时间顺序与因果顺序一致。

📎 **v0.2.2 第九轮那条「写完 log 不要 commit `memory/`」的硬规则，v0.3.0 起解除。** 它存在的唯一原因是 v0.2.x 的指纹 payload 第一行是 `git rev-parse HEAD`；新模型的 payload 里根本没有 HEAD —— 实测「改 `memory/`」「`git add memory/`」「`git commit memory/`」三步之后 `ThemeTreeOid` 与 `ChangeSetScopeFingerprint` **逐字不变**。**不要继续遵守一条已经不存在的约束**，也**不得**因为日志被提交了就判 `Invalidated`。

### 两类盲区现在由取证函数自动挡（QA 不再手查）

| 旧的补充门 | 现在 |
|---|---|
| 索引标志门（`assume-unchanged` / `skip-worktree`）📎 **v0.3.0 起解除** | **已退役**：新模型用的是**空白临时索引**，用户 index 上的标志不生效 —— 实测两种标志下改内容仍判 CHANGED。继续手查它只会给出一个不再成立的停机理由 |
| submodule gitlink | 由取证函数的 `GITLINK_IN_THEME_TREE` / `GITLINK_IN_SCOPE` **自动 fail closed**，QA 不再手查。命中即停机，**不存在**"递归取子模块指纹后继续"这条路 |

其余仍然存在的 fail-closed 门（clean filter 与 `text` / `eol` / `ident` / `working-tree-encoding` / `export-ignore` / `export-subst` 家族、`core.autocrlf`、`core.fileMode` 假值、symlink、路径含换行、git < 2.25、object format 查不到）见 handoff-schema §2.9 与 `references/evidence-and-invalidation.md` §2.5。**它们不是遗留缺陷，是 fail-closed 的设计**：这些机制下 tree 字节 ≠ 上线字节，算得出指纹反而更危险。命中时相关检查项 `Blocked` + 停机，不得自行放行。

---

## Step 3 — QA-Global（恒执行，与路径无关）

七项，一项都不能省。完整可执行步骤见 `references/qa-global.md`；Theme Check 的 baseline 增量流程与解析脚本见 `references/theme-check-gate.md`。

> 🔴 **全部在 `StageDirRef` 指向的 workspace 快照里跑**，不在活工作树上跑（§2.6）。两个例外必须写清楚：需要 git 历史的举证命令（`git show <BaseHeadSha>:<file>`、`git diff <BaseHeadSha> -- <ModifiedFiles>`）**在原仓库里**用 `git -C <theme-root>` 跑 —— 快照里没有 `.git`；Theme Check 的 baseline 另行从 `BaseHeadSha` 物化。`ThemeCheckEvidence` / `Evidence` 里要写明每条命令实际跑在哪个目录。

| 字段 | 检查 | 证据形态 |
|---|---|---|
| `ThemeCheck` | baseline 增量，**绝不是全仓绝对 pass** | CLI 版本 / 检查目录 / 两次 JSON / 新增 offense 数 |
| `RegressionMatrix` + `BreakpointsCovered` | 5 断点 PC / 1599 / 1279 / 767 / 375 × 受影响页面 | 页面 × 断点矩阵 + 每格结论 |
| `LocalizationCheck` | 英译德长文案：溢出 / 遮挡 / 异常换行 | 用了哪段德语、在哪个断点、观察结果 |
| `A11yCheck` | 引用 shared 红线 5 的 A11y 底线逐项 | 选择器 + 行号 / 对比度计算值 |
| `FixedDimensionCheck` | 组件写死宽高；例外须已在实现工件里说明理由 | grep 命中 + 逐条裁定 |
| `ImageQualityCheck` | 图片清晰度红线（`image_url` 的 `width:` 取值） | grep 命中 + 容器宽 × DPI 推算 |
| `CopyConfigurabilityCheck` | 展示文案走 schema / locales；无 `\| default: '...'`；`blank` 不出空壳 DOM | grep 命中 + 逐条裁定 |

### QA-Global 附加触发式检查（补 shared §8 红线的覆盖空隙）

§5 的 QA-Global 七项没有覆盖到三条红线，它们原本只落在单个 profile 里，导致换条路径就漏检。以下三项**与路径无关**，触发即查，结果写进 `ProfileSpecificResults`（不新增 yaml 字段）：

| 红线 | 触发条件 | 检查 |
|---|---|---|
| 红线 4 颜色走 token | diff 含 CSS / Liquid 内联样式 | 新增 `#hex` 字面量逐条裁定；仅设计系统已文档化例外可豁免 |
| 红线 6 JS 生命周期 | diff 含 `.js` | 注册与 `disconnectedCallback` 清理成对、null 守卫、TDZ、无 `console.log`（细则见 `qa-profile-a.md` A5，**Path B/C 同样要跑**） |
| 红线 7 build 产物勿手改 | diff 触及 build 输出目录 | 改动必须落在源 + 重新 build；直接改产物 → `Failed`（细则见 `qa-profile-c.md`，**Path A/B 同样要跑**） |

三条不可越权的表述规则：

1. **`ThemeCheck: Passed` 只代表静态 lint 无新增 offense。** 不得表述为"Shopify 兼容性全部通过""theme check 全绿"。运行时行为、视觉、admin schema 保存分别由 `ThemeRuntimePreview` / `RegressionMatrix` / `AdminSchemaSave` 承担，各自独立取值。
2. **无法预览就标 `Blocked`。** `ThemeRuntimePreview` / `AdminSchemaSave` 拿不到环境时取 `Blocked` + 原因，绝不猜"应该没问题"，也不用静态检查顶替。
3. **CLI 不可用 / 仓库非 theme root / build 产物缺失 → `ThemeCheck: Blocked`**，不可 `Passed`。

## Step 4 — 路径 profile

`RequiredQAProfile` 由上游 Assess / Implement 工件给出（QA-A / QA-B / QA-C，可多选）。**上游没给 → 停机要**（见下方红框，不再按 `Path` 反推）。

> 🔴 **上游在 `RequiredQAProfile` 里写 `QA-Global` 是枚举违规，按 Step 1 的结构核**停机**，不是"照跑不误"**（v0.2.2 第六轮改）。
> 旧写法（"照跑，但在正文指出写法有误"）等于 QA 替上游修工件：这一轮糊过去了，下一轮同样的错还会来，而且它与 Step 1 的"取值必须在封闭枚举内"自相矛盾。
> `QA-Global` 由本 skill 按 §5 恒执行、不需要任何声明；上游写了就是工件不合格。
>
> **上游完全没给 `RequiredQAProfile`** 也一样停机 —— 不要按 `Path` 反推替它填上（那是替上游做决定，且掩盖了工件缺字段这个事实）。

| Profile | 覆盖 | 展开位置 |
|---|---|---|
| **QA-A** | 同族 bug 扫描、依赖树回归、Swiper effect 约束、旧 section 连带影响、JS 生命周期清理 | `references/qa-profile-a.md` |
| **QA-B** | `sa-*`/`SA:`/BEM 根类名、vendor §1–§12、素材来源、schema 完整性、空配置与满配置双测、多语言 | `references/qa-profile-b.md` |
| **QA-C** | disabled 实例已跳过、空 pre/sub heading 未进字号总览、三层入口选择、20 条踩坑规则适用项、日志时机 | `references/qa-profile-c.md` |

逐项结果写进 `ProfileSpecificResults`，每项同样只取 `Passed`/`Failed`/`Blocked`/`NotApplicable` + 证据。**同样在 `StageDirRef` 快照里跑**（需要 git 历史的举证命令除外，见 Step 3 的红框）。

## Step 5 — 汇总判定与追溯登记

先重算 `ThemeTreeOid` 并与 Step 1 比对（三次里的最后一次），再判两个终态字段。`VerificationId` / `ChangeSetId` / `ThemeCheckEvidence` / `BreakpointsCovered` / `Evidence` / `BlockingGaps` / `QAProfilesRun` / `StageDirRef` / `DiffBaseTreeOid` / `FingerprintVerifiedAt` 是记录字段，不参与取值判定：

```
0. QAAdmissionStatus == Accepted（提测准入门，Step 0）
1. ChangeSetIdMatched == Yes
     四样全对：文件集合 + ObjectFormat + ThemeTreeOid + ChangeSetScopeFingerprint
     （QAScope: Integration 时，IntegrationOf.Members[] 每一项的三元组都要逐字比）
2. DeclaredDiffCheck == Passed
     §2.7：树里只有本工件覆盖的 ChangeSet 声明的改动 —— 没有兄弟块的半成品、
     没有无主改动。基准不可解析是 Blocked，**不得**降级成 Passed 或 NotApplicable
3. 十一个状态字段 ∈ {Passed, NotApplicable}：
     ThemeCheck / ThemeRuntimePreview / AdminSchemaSave / RegressionMatrix /
     LocalizationCheck / A11yCheck / FixedDimensionCheck /
     ImageQualityCheck / CopyConfigurabilityCheck / StyleHardRuleCheck /
     ApprovedExceptionsChecked（§4 的 ApprovedExceptions 为 [] 时它是 NotApplicable）
     —— NotApplicable 必须**带适用性证据**
4. ProfileSpecificResults 中每一项 ∈ {Passed, NotApplicable}（含上面三条附加触发式检查）
5. BreakpointsCovered 含全部五档（除非 RegressionMatrix 为 NotApplicable）
6. Evidence 对每个 Passed 项都有对应条目；BlockingGaps 为空
7. FingerprintVerifiedAt 的 Step1 / Stage / Step5 三次一致
```

| `QAScope` | `ReadyForIntegration` | `ReadyForDelivery` |
|---|---|---|
| `SingleChangeSet` | 0–7 全部成立 → `Yes`；任一条不成立 → `No` | **同一组条件**（这正是 §2.11 的第一层）→ `Yes` / `No` |
| `Integration` | **恒 `N/A(Integration)`** —— 集成工件不是任何一块的结论 | 0–7 全部成立 → `Yes` |

> 块 QA 场景两者同真同假，**区别在语义与消费者**：`ReadyForIntegration` 是「这一块本身验过了」，被 §9.1.4 的 `ReleaseScope[].QAConclusion` 逐块抄走；`ReadyForDelivery` 是「这棵被验过的 tree 有资格被后续 release 使用」。

任一条不成立 → `No`。**没有"基本通过""只差一点"这种中间态。**

🔴 **`ReadyForDelivery: Yes` 不等于"可以发了"，不要在任何地方这样表述它。** 上面 0–7 只是 §2.11 的**第一层**（QA 侧，全部当场可验）。**第二层是 release 侧的发布门**，由 `plaud-theme-release-ops` 执行、不满足即停机不发版：`ReleaseSourceTreeOid` 逐字等于本工件的 `VerifiedThemeTreeOid`（且 `ObjectFormat` 相同）+ `ReleaseDeclaredDiffCheck: Passed` + `PushCommandCompliance: Compliant`（含 `--path <ReleaseStageDir>` 逐字相等）+ 执行 push **紧前**再复算一次。
**本 skill 不判第二层**，也不得把第二层的条件写成自己给 `Yes` 的前提 —— QA 出工件时 release 工件还不存在，那样就成了"release 要 QA 的 `Yes`、QA 又要 release 的字段"的流程死循环。
🔴 多块合并之后**没有任何单块 QA 持有那棵合并树的 oid**，所以第二层第 1 条在结构上必然要求一份集成 QA。这是一条可机械核对的等式，不是靠自觉遵守的流程规定。
🔴 `ReadyForDelivery: Yes` 也**不替代**运营验收、站点清单二次确认与推站授权（§1.1）。

### `NotApplicable` 的使用边界

按 handoff-schema §1.3：`Blocked` / `NotRun` 不得折算为 pass；`NotApplicable` 是**合法终态**，但必须带适用性证据。落到本 skill：

- `NotApplicable` = "根本不需要验"。必须写出理由并可从 `ModifiedFiles` / diff 复核，例如"本次未改任何 `.liquid`，Theme Check 不适用"。
- `Blocked` = "该验但验不了"。拿不到环境、跑不了工具、没时间——**一律 `Blocked`**。
- **没有证据的 `NotApplicable` 按 `Blocked` 处理**（§1.3 原文）。把 `Blocked` 写成 `NotApplicable` 是最直接的绕过交付门的方式，判契约违规。
- 存疑时选 `Blocked`。

本份工件的 `VerificationId` 形如 `VER-<YYYYMMDD>-<NN>`（canonical §5）。
🔴 **`<NN>` 的分配器 canonical 没有定义，本 skill 也不自造一个。** 特别是**不要**去 `memory/changeset-log.md` 里推算"当日最大序号 + 1"：那个文件没有这一列（它的列由 §9.2 的 `memory/` 记录字段枚举封闭），而且在有条件并行的块 QA 下，两个进程会读到同一个最大序号 → 撞号。
在 shared 定义分配器与并发防线之前：同一天要出多份 QA 工件时，**由调用方（用户 / `plaud-theme-orchestrator`）指定或确认 `<NN>`**，QA 不自行推算；确认不了就停机要，并把这条缺口写进 `Advisories`。

结果追加到项目侧 `memory/changeset-log.md`（**项目运行时状态，不随包分发**；格式与失效语义见 `references/evidence-and-invalidation.md`）。

> 🔴 **日志的列以 `references/evidence-and-invalidation.md` §3 为准**：📎 v0.3.0 只把 v0.2.3 的 `ChangeSetFingerprint` 一列换成 `ObjectFormat` + `ThemeTreeOid` + `ScopeFP`（§9.2 授权的范围），**没有** `VerificationId` / `ReadyForIntegration` 列；要人读追溯就把 `VER-…` 写进 `Note`（`Note` 不被下游消费）。
>
> 🔴 **迁移轮次照抄本轮那一行（新文档 ID）**：`TestSetMigrationRef` 不进日志列，只可在 `Note` 列写 `Migrated(<旧ID> -> <新ID>)` 作**人读备注**——`Note` 列**不被下游消费**，下一轮 `PreviousAcceptedTestSetTrace` **优先**从 `TestSetTrace` 列取最近一条非 `N/A` 的行（那一行已经是新 ID，链不断）；日志不可得时才走 `package-checklist.md` §3 取数路径②的成对工件。要机器审计迁移本身，查该轮的 `QAIntake` 工件。
>
> 🔴 **v0.2.2 起该表多一列 `TestSetTrace`**：**只要本轮 `QAAdmissionStatus: Accepted`**（提测包过了准入），就把 `QAIntake` 工件里的那一行**原样抄进去**（不重编、不规整、不补全），**与 `ReadyForDelivery` 是 `Yes` 还是 `No` 无关**；`QAAdmissionStatus: Blocked` 才写 `N/A(NotAccepted)`，该轮确无测试集写 `N/A(NoTestSet)`。
> **锚点是「准入通过」不是「交付通过」**：QA 失败的返工轮同样要留下测试集版本，否则跨轮次连续性会在返工那一轮断链——而返工正是最容易换文档的时候。完整规则见 `references/evidence-and-invalidation.md`。

**该文件不存在时**：按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表——**询问用户后可创建空日志**（本 skill 只引用该表，不自行规定；不得凭空补写从没跑过的 QA 行）。另三个迁移状态文件缺失是默认停机，归 `plaud-theme-ux-migration`，本 skill 不写。

log 里的 `Status`（对应 §9.2 的 `memory/` 记录字段 `QAStatus`）取值是 `Pending` / `Valid` / `Invalidated`——它们是**合法的 memory 枚举**，但 🔴 **绝不允许出现在 §5 的阶段契约块里**（§5 的块根本没有 `QAStatus` 字段；阶段契约字段的 `QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`，那是 §4 的事）。两套枚举互不通用。

---

## 集成 QA（`QAScope: Integration`）

多块同批发版时，**没有任何单块 QA 持有那棵合并树的 oid**（§2.10 / §2.11 第二层第 1 条），所以 cohort 必须多做一份集成 QA。它是**独立工件**，不是任何一块工件的改写：

- 有自己的 `VerificationId`（`VER-<YYYYMMDD>-<NN>`）—— §9.1.4 的 `ReleaseQARef` 指的就是它；
- `ChangeSetId: N/A(Integration)`、`QAScope: Integration`、`IntegrationOf` 非空、`ReadyForIntegration: N/A(Integration)`；
- 🔴 **不得**把集成结论写进任何一块的 QA 工件，**不得**复用某一块的 `VerificationId`，**不得**拿最后一块的 QA 当集成结论。
- 与块 QA **共用同一套 35 key 封闭集**（靠 `QAScope` 判别），不另立模板：两套近似模板必然漂移。

`IntegrationOf` 是**映射**（不是裸列表），逐字形态以 handoff-schema §5 为准：

```yaml
IntegrationOf:
  PlanRef:                      # §9.1 协调工件的 OrchestrationId
  BaseTreeOid:                  # 逐字抄 IntegrationPlan.IntegrationBaseTreeOid
  Members:
    - ChangeSetId:
      ImplementArtifactRef:
      QARef:                    # 该块 QA 工件的 VerificationId，其 ReadyForIntegration 必须是 Yes
      SubmissionId:
      ObjectFormat:
      ThemeTreeOid:
      ChangeSetScopeFingerprint:
```

四道额外的机械门，任一不成立即停机 —— **不得**"看起来对得上"就放行：

| 门 | 判据 | 不成立时 |
|---|---|---|
| **基准三方等式** | `IntegrationPlan.IntegrationBaseTreeOid` == `IntegrationOf.BaseTreeOid` == 本工件的 `DiffBaseTreeOid`，**三者逐字相等**且同一 `ObjectFormat` | `DeclaredDiffCheck: Blocked` —— 少了这道等式，可以记一个漂亮的基准 oid、却拿另一个 commit 去算 diff |
| **成员集合** | `IntegrationOf.Members` 与 `IntegrationPlan.MemberChangeSets` **集合相等且无重复** | 停机（多一块 = 有块没被计划；少一块 = 它的材料与验收整份缺席） |
| **成员身份** | 逐成员：`ImplementArtifactRef` / `QARef` / `SubmissionId` 都可解析；该块 §4 工件的三元组与 `Members[]` 抄的值逐字相等；`ChangeSetScopeFingerprint` **在集成树里重算**同样逐字相等；`QARef` 那份块 QA 的 `ReadyForIntegration: Yes` | `ChangeSetIdMatched: No` + 停机（§9.2：`Integration` 时 `IntegrationOf` **每一项**都要比，任一不匹配即 `No`） |
| **声明路径两两不相交** | `plaud_declared_diff` 的期望集合是各成员声明路径的**并集**，而并集会**折叠重复路径** —— 所以必须**另外**核一遍成员之间路径不重叠 | 相交 → `DeclaredDiffCheck: Failed` + 停机（orchestrator 派活时的"两两不重叠"是同一条判据的上游版本，上游漏派、下游就得抓住） |

### 集成 QA 的 pathlist 与逐成员取证（可执行顺序）

```bash
# (0) 逐成员各写一份 pathlist：内容是**该成员自己**的 §4 ModifiedFiles，逐字、每行一条
printf '%s\n' <成员 i 的 ModifiedFiles 每一条路径> > "$SCOPE_i"

# (1) 逐成员在**集成树**里重算 ScopeFP，与该成员 §4 工件的值逐字比
plaud_changeset_scope "$SCOPE_i" || { echo "SCOPE_FAILED"; exit 1; }
#     不等 → 这一块的内容在集成过程中被改掉了 → ChangeSetIdMatched: No + 停机

# (2) 两两不相交核对（并集会折叠重复路径，所以这一步不能省）
#     任意两个成员的 pathlist 有交集 → DeclaredDiffCheck: Failed + 停机

# (3) 并集作为期望集合，跑一次归属核对
sort -u "$SCOPE_1" "$SCOPE_2" ... > "$SCOPE_UNION"
plaud_declared_diff "<IntegrationPlan.IntegrationBaseCommit>" "$SCOPE_UNION" \
  || { echo "DECLARED_DIFF_FAILED"; exit 1; }
```

> 🔴 **(2) 必须在 (3) 之前做**：`sort -u` 把重复路径折叠掉之后，"两个块声明了同一条路径"这道洞在并集里看不出来。
> 🔴 **逐成员还要核 `ChangeSetId` 一致**：`Members[i].ImplementArtifactRef` 指向的 §4 工件、`Members[i].QARef` 指向的 §5 工件、`Members[i].SubmissionId` 指向的 §9.1.2 工件，**三者的 `ChangeSetId` 都必须等于 `Members[i].ChangeSetId`**。只核"集合相等"不核这一条，可以把 A 的实现工件配上 B 的 QA 与 C 的提测包，而集合检查照样通过。

其余接线：

- diff 基准用 `IntegrationPlan.IntegrationBaseCommit`（必须可解析；不可解析 → `DeclaredDiffCheck: Blocked`，**不是**可以降级放行的情形）。
- 提测包用**集成提测包**（§9.1.2 支持 `ChangeSetId: N/A(Integration)` + `IntegrationOf`），集成提测材料 = 各块材料的并集 + 集成本身的 `ReworkDelta`。集成提测包顶层的 `ChangeSetScopeFingerprint` 是 `N/A(Integration)`，逐块取值在 `IntegrationOf` 里 —— **不要拿那个 `N/A` 去凑三元组比对**。
- `ReadyForDelivery` 仍按 Step 5 的 0–7 判（集成场景同样是第一层，第二层仍在 release 侧）。

### 🔴 同树 A、B 已同时落盘时，块 QA 怎么判（这条必须照做，不要绕）

`Members[].QARef` 要求每一块**已经**拿到 `ReadyForIntegration: Yes`；而块 QA 只有在**其它块的改动尚未落进同一棵树**时才成立（§2.12：各块在独立 worktree 里开发，或同树但按落盘时序抢先物化）。两者相遇就是这个死角：A、B 都落盘之后再想补 A 的块 QA，补不出来。

**判什么（没有含糊空间）：**

| 字段 | 取值 | 依据 |
|---|---|---|
| `DeclaredDiffCheck` | **`Failed`** | B 的改动相对 A 的声明是无主改动 → `DECLARED_DIFF_ORPHAN`（§2.7） |
| `ChangeSetIdMatched` | **`No`** | 整树 `ThemeTreeOid` 与 A 的 §4 工件不一致（§2.8）——**即使 A 的 `ChangeSetScopeFingerprint` 仍然相等** |
| `ReadyForIntegration` | **`No`** | Step 5 的 0–7 不成立 |
| `ReadyForDelivery` | **`No`** | 同上 |
| 十一个状态字段 | **`Blocked`**（原因："隔离前提被破坏，未执行"） | 前置门没过，检查不开始 |

**产出的是一份 `No` 工件，不是"没有工件"** —— 记录这轮为什么不成立，比什么都不出更有追溯价值。

🔴 **没有诚实的降级取值能把它变成 `Yes`。** `ReadyForIntegration` 的封闭枚举是 `Yes` / `No` / `N/A(Integration)`，而 `N/A(Integration)` **是集成工件专用**，块 QA 借用它就是伪造一个"这一块不需要结论"的事实。物化也救不了：此刻物化出来的两份快照**都是 A+B**，那不是两次块 QA，而是一次集成 QA 的两个副本。

**两条合法出路，都不在 QA 内部：**

1. **回退隔离后重跑**：由集成者（人）把其它块的改动从这棵树里撤掉（revert / stash / 换 base），或把该块挪到独立 worktree 重做，然后**重新取证**（新的 `ThemeTreeOid`）并重跑块 QA。这与 §2.14 对 `IncludedInThisPush: No` 的处置是同一条出路，代价也一样。
2. **落盘时序上抢先**：下一轮派活时给每块留出"其它块落盘之前完成物化"的窗口——这是**事前**的安排，事后补不了。

**不得**为了让集成跑下去而给某一块补发一张 `ReadyForIntegration: Yes`，也不得跳过 `Members[].QARef` 这道要求。停机，把缺口写进 `BlockingGaps`，交回 `plaud-theme-orchestrator` / 集成者。

---

## 特殊情形

### 用户要求跳过验证

用户明说"不用检查了直接发"时：**仍不得输出 `ReadyForDelivery: Yes`。**

正确做法（完整模板见 `references/evidence-and-invalidation.md` §4）：

- §5 yaml 块**保持纯净**——只含 §5 定义的 35 个字段（含 `VerificationId` / `QAScope` / `IntegrationOf` / `SubmissionId` / `QAAdmissionStatus` / `ObjectFormat` / `VerifiedThemeTreeOid` / `DiffBaseTreeOid` / `DeclaredDiffCheck` / `StageDirRef` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` / `Advisories` / `ReadyForIntegration`）。`QAProfilesRun: None`，未执行项一律 `Blocked`，`BlockingGaps` 写 `全部验证项未执行（UserWaived）`，`ReadyForDelivery: No`。
- `QAStatus: Skipped(UserWaived)` 写在**正文**里，**不写进 yaml 块**——handoff-schema §5 没有这个字段，§4 才有；往 §5 块里塞它就是自造字段，违反契约首条。
- 正文用**一句话**说明：已按用户要求跳过验证，未经验证的改动上线风险由用户承担。不劝说、不重复、不长篇解释。

### QA 已通过但代码又变了

按 handoff-schema §2.5 的函数重算 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`，与 `changeset-log` 中记录的值比对，任一不等即失效。失效后：把该行的状态列改为 `Invalidated`，要求实现 skill 生成**新的** `ChangeSetId` + 三个身份字段，整轮重跑。**不允许**"只补验变动的那部分"——同族 bug 与传播链正是靠全量重跑抓到的。

📎 **v0.3.0 起不再算失效的三类**（§2.8 逐条实测）：`git add` / `git reset`（内容不变）、`git commit memory/`、把主题改动 commit 掉（内容一字未改）、以及仓库根的 scratch 临时文件（`tc-diff.js` / `node_modules` / `.env`——不在可发布面）。这些场景下三个身份字段逐字不变，**不得**据此判 `Invalidated`。
🔴 **`ThemeTreeOid` 变了就是变了**，即使本块的 `ChangeSetScopeFingerprint` 没变：那说明别的块的改动落进了同一棵树，按 §2.12 应改走 `QAScope: Integration`，**不是**记个 `Advisories` 继续。

### 上游根本没走过 Assess / Implement

分两种，不要混：

**(a) 有改动但上游没走流程** —— 停机。说明矩阵阶段单向推进，要求先过实现 skill 拿 `ChangeSetId` + `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`（外加仍必填、必须可解析的 `BaseHeadSha`）。

**(b) 真正的零改动任务**（只读审计 / code review / A11y 审计）—— **本 skill 没有零改动分支。**

handoff-schema §2 规定零改动任务**免 QA**（`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`），工件由实现 skill 按 §4 输出并登记 `ReadOnlyProof`（两次 `plaud_theme_tree` 的 `ObjectFormat` + `ThemeTreeOid` 逐字相等）。而 §5 的 35 个字段里既没有 `ModifiedFiles` 也没有 `ReadOnlyProof`——本 skill 在结构上就无法为零改动任务输出完整契约。

所以遇到零改动请求：**说明归属并转给 `plaud-theme-dev`**（Path A 的只读通道），不要自己接、不要输出 §5 块、更不要给 `ReadyForDelivery`。

即使用户说"就让 QA 来审"，也照样转——理由一句话说清即可：QA 的产出契约绑定的是"某个 ChangeSet 验没验过"，零改动没有 ChangeSet 可绑，硬填 `N/A` 只会产出一份没有验证含义的通过记录。

> 与 handoff-schema §9「每个 skill 回复的最后必须是阶段 yaml 块」不冲突：**没有消费 §4 的 Verify 输入就没有进入 Verify 阶段**，此时本 skill 处在负路由态，不产出阶段工件。一旦接下 `ChangeSetId`，§9 无条件生效。

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| **每次 QA 必读** | `plaud-theme-shared/references/handoff-schema.md` |
| 跑 Theme Check（`ThemeCheckRequired: Yes`） | `references/theme-check-gate.md` |
| QA-Global 各项 + DTC 硬性 10 条 + Advisories | `references/qa-global.md` |
| 本次含 QA-A | `references/qa-profile-a.md` |
| 本次含 QA-B | `references/qa-profile-b.md` |
| 本次含 QA-C | `references/qa-profile-c.md` |
| 写 changeset-log / 判失效 / 处理豁免 | `references/evidence-and-invalidation.md` |
| 需要红线数值（字阶 / token / 断点 / 媒体 / A11y） | `plaud-theme-shared/references/*.md`（**不在本包复制数值**） |

---

## Step 6 — 输出契约（不可省略、不可改名）

回复的**最后**必须是一个 ```yaml 代码块，字段与 handoff-schema §5 **一字不差**：**35 个 key、顺序一致**，不得增删字段、不得改名、不得塞进正文段落。**任何场景都不例外**——用户豁免时也不往块里加 `QAStatus`（写正文）。

块 QA 与集成 QA **共用这一套封闭集**，靠 `QAScope` 判别；`IntegrationOf` 在 `QAScope: SingleChangeSet` 时填 `N/A`，在 `Integration` 时是上面那个映射结构。

```yaml
VerificationId:              # VER-<YYYYMMDD>-<NN> —— 本份 QA 工件自己的稳定身份
QAScope:                     # SingleChangeSet | Integration
ChangeSetId:                 # QAScope: Integration 时填 N/A(Integration)
IntegrationOf:               # Integration 时必填非空（PlanRef / BaseTreeOid / Members[]）；否则 N/A
SubmissionId:
QAAdmissionStatus:
QAAdmissionReason:
ObjectFormat:                # sha1 | sha256 —— 本轮实际取证时的 object format
ChangeSetIdMatched:
VerifiedThemeTreeOid:        # 本轮实际验的那个 tree oid；release 的 ReleaseSourceTreeOid 必须逐字等于它
DiffBaseTreeOid:             # plaud_declared_diff 输出的第 2 段；取不到填 Unavailable(<原因>)
DeclaredDiffCheck:           # Passed | Failed | Blocked | NotApplicable（基准不可解析是 Blocked）
StageDirRef:                 # 本轮检查实际跑在哪个 workspace 快照（plaud_stage_workspace 的产物，绝对路径）
FingerprintVerifiedAt:       # 三次：Step1(物化前) / Stage(物化回环) / Step5(收尾)
QAProfilesRun:
ThemeCheck:
ThemeCheckEvidence:
ThemeRuntimePreview:
AdminSchemaSave:
RegressionMatrix:
BreakpointsCovered:
LocalizationCheck:
A11yCheck:
FixedDimensionCheck:
ImageQualityCheck:
CopyConfigurabilityCheck:
StyleHardRuleCheck:
ApprovedExceptionsChecked:   # Passed | Failed | NotApplicable | Blocked（Blocked 仅限批准链接不可达这类「该验但验不了」）
ApprovedExceptionsEvidence:  # 逐项：Clause + Scope + 核了哪条链接 + 结论
ProfileSpecificResults:
Advisories:
Evidence:
BlockingGaps:
ReadyForIntegration:         # Yes | No | N/A(Integration)（QAScope: Integration 时恒取 N/A(Integration)）
ReadyForDelivery:            # Yes | No —— 只是 §2.11 的第一层，不等于"可以发了"
```

`QAScope: Integration` 时 `IntegrationOf` 的嵌套形态：

```yaml
IntegrationOf:
  PlanRef:
  BaseTreeOid:
  Members:
    - ChangeSetId:
      ImplementArtifactRef:
      QARef:
      SubmissionId:
      ObjectFormat:
      ThemeTreeOid:
      ChangeSetScopeFingerprint:
```
