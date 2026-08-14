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
  实现 skill 交出 ChangeSetId + BaseHeadSha + ChangeSetFingerprint 时必须调用本 skill。
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

- 每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`（handoff-schema §5 开头；`FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 三项与 §9.2 的枚举表存在已知冲突，处理方式见 Step 1 的「三项枚举缺口」注）。**禁止勾选框、禁止叙述式过关。**
- `Blocked` 必须附原因（缺什么、为什么拿不到）。
- `Passed` 必须在 `Evidence` 里有对应条目：命令原文 + 输出摘要，或明确的观察对象（文件:行号 / 截图 / 预览 URL）。
- `NotApplicable` 必须附一句"为什么不适用"（例如"本次未改 JS，无生命周期清理面"）。
- **`Evidence` 为空的检查项，无论标了什么，一律降级为 `Blocked`。**
- 任一项非 `Passed` / `NotApplicable` → `ReadyForDelivery: No`。`Blocked` 不折算为 pass。

## 本 skill 不做什么

- 不改任何 `sections/` `snippets/` `assets/` `templates/` `locales/` 文件。发现问题只报，不顺手修。
- 不做根因分析、不出修复方案——那是实现 skill 的职责。
- 不写迁移日志内容（那是 `plaud-theme-ux-migration` 在用户验收后做的事）。
- 不替实现 skill 补 `ChangeSetId`；拿不到就停机要。

---

## 执行顺序（不可跳步）

```
Step 0  取上游工件（ChangeSetId / BaseHeadSha / ChangeSetFingerprint / ModifiedFiles /
        RequiredQAProfile / ThemeCheckRequired…）+ 提测包工件（SubmissionId /
        SubmissionPackageStatus，来自 plaud-theme-qa-intake）
        → 判 QAAdmissionStatus  ← 准入门，比指纹校验更早
Step 1  三重绑定校验（文件集合 + ChangeSetFingerprint + BaseHeadSha）
        ← 前置门，先于任何检查；不过就停机，后面一步都不做
Step 2  登记「收尾必须重算指纹」这项义务（真正的重算发生在 Step 5 之前，不是现在）
Step 3  QA-Global（恒执行）
Step 4  路径 profile（QA-A / QA-B / QA-C，可多选）
Step 5  先重算指纹并与 Step 1 比对 → 再汇总判定 → 最后才写 memory/changeset-log.md
Step 6  输出 §5 契约 yaml 块
```

> ⚠️ **Step 2 不是"在 Step 3 之前再算一次"。** 它在这里只是登记义务；重算的时点是**所有检查跑完之后、写 changeset-log 之前**（Step 5 的第一件事）。提前算等于没算。

---

## Step 0 — 提测准入门（`QAAdmissionStatus`）

**这道门比指纹校验还早。** 依据 DTC《开发交付标准 v1.0》§四：「提测时必须同时提供，**缺一不进验收**」——材料不齐，验收根本不开始。

取 `plaud-theme-qa-intake` 的 `ArtifactKind: QAIntake` 工件（handoff-schema §9.1.2）。

**四项都要查，缺一即 `Blocked`：**

```bash
# (1) 提测包绑的是不是本次这个 ChangeSet —— 防重放
#     intake.ChangeSetId          == implement.ChangeSetId
#     intake.ChangeSetFingerprint == implement.ChangeSetFingerprint   # 逐字比对

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
| intake 绑的 `ChangeSetId` / `ChangeSetFingerprint` 与 Implement 工件对不上 | `Blocked` / **`BindingMismatch`** | 停机 —— **这是一份别的任务的提测包**，不得复用 |
| `PackageFingerprint` 或云端 revision 重算不一致 | `Blocked` / **`BindingMismatch`** | 停机 —— 材料在准入之后被改过 |
| `TestSetMigrationRef` **字段齐全但绑定对不上**（(4a) 的 `From` / `To` 比对失败，或 (4b)/(4c)/(4e) 的 `N/A` 与实际 trace 自相矛盾——含「Previous 明明是具体一行却填 `N/A(NoPreviousTrace)`」与「Previous 是 `Unavailable` 却仍提交完整迁移声明」两个方向） | `Blocked` / **`BindingMismatch`** | 停机 —— 声明迁自 A、历史记录却是 B |
| `TestSetMigrationRef` **缺失 / 语法坏 / `Reason` 越界 / locator 悬空或跑出材料根 / 清单用了 `Manifest(...)` / 清单条数与 `OldCaseCount` 对不上 / 旧 ID 重复 / `Dropped` 理由或 `RetireReason` 为空**（ID 变了却没有合法迁移声明） | `Blocked` / **`PackageIncomplete`** | 停机 —— 这是 intake 该判 `Incomplete` 的项，本应到不了这里；退回 `plaud-theme-qa-intake` 重出 |
| `PreviousAcceptedTestSetTrace` 为 `Unavailable(...)` / `None(FirstSubmission)` **且** `TestSetMigrationRef: N/A(NoPreviousTrace)`（两者必须同时成立，见 (4e)；只满足其一是自相矛盾，走上一行的 `BindingMismatch`），其余项都对 | **不阻断**（照常 `Accepted`） | 在 `Advisories` 记「测试集跨轮次连续性本轮无法核验」+ 属于 `package-checklist.md` §3 取数路径③ 的哪一种；**不进 `BlockingGaps`** |
| `SubmissionPackageStatus: Incomplete` | `Blocked` / `PackageIncomplete` | 停机，零执行 |
| 压根没有提测包工件 | `Blocked` / `MissingArtifact` | 停机，零执行 |
| 用户主动弃提测材料 | `Blocked` / `UserWaivedMaterials` | **照跑技术检查项**，`Evidence` 记弃流程的出处 |

> 🔴 **表里没有零改动只读任务这一行，这是刻意的**（v0.2.2 第七轮废止该分支，第八轮清掉残留表头与旧行）：§5 的 26 字段里既没有 `ModifiedFiles` 也没有 `ReadOnlyProof`，本 skill 结构上就无法为零改动任务输出完整契约。收到这类请求 → 转 `plaud-theme-dev` 的零改动通道，**不输出 §5 工件、不发 `Accepted`**（详见下方「(b) 真正的零改动任务」）。
**`Blocked` 之后跑不跑检查，取决于是哪种 Blocked：**

| Blocked 的原因 | 跑不跑检查 | 为什么 |
|---|---|---|
| 绑定失配（intake 的 `ChangeSetId` / `ChangeSetFingerprint` 对不上，或 `PackageFingerprint` 重算不符） | **零执行** | 根本不知道在验什么——验了也不能归属到任何 ChangeSet |
| `SubmissionPackageStatus: Incomplete`（材料不齐） | **零执行** | 这是准入门本身的强制效果。DTC：「缺一不进验收」——验收就是不开始 |
| **用户明确弃提测流程** | **照常执行技术检查项** | 绑定是有效的，只是用户主动放弃了材料这道门。此时验证本身有意义，只是不产生许可 |

前两种的输出：`ReadyForDelivery: No`、**十一个**状态字段与 `ProfileSpecificResults` 一律 `Blocked`（原因写"提测包不全/绑定失配，未执行"）、把 qa-intake 的 `BlockingGaps` **原样带出**（不要改写成自己的话，运营要按它去补材料）。

第三种的输出：`QAAdmissionStatus: Blocked` + 各检查项照实填实际结果（`Passed`/`Failed`/...），但 `ReadyForDelivery` **恒为 `No`**（判定条件第 0 条不满足），`BlockingGaps` 写"用户弃提测流程，未经完整交付流程"。

> 🔴 **三种都不产生 `Accepted`。** 区别只在"验不验"，不在"给不给许可"。

**关于零改动只读任务**：它**不进本 skill**（handoff-schema §2 / §5 准入门第 3 条），所以本 skill 里不存在「免提测包却给 `Accepted`」这条路。转 `plaud-theme-dev`。

> 🔴 **用户说"不走提测流程"不产生 `Accepted`。** 此时 `QAAdmissionStatus` 仍为 `Blocked`，走上表第三行：照常执行技术检查项，`ReadyForDelivery` 恒为 `No`，正文一句话说明风险由用户承担。用户可以决定不交材料，但不能因此拿到一张"准入通过"的记录。

> 🔴 **「改动很小」不是免除理由。** 那是 `ReconMode: InlineLite` 的判据（Assess 豁免），与提测材料无关。QA **不得**自行免除提测包。

> 🔴 **提测包里的 8 张断点截图不能顶替本 skill 的断点回归。** 前者是交付材料，后者是 QA 实跑（`BreakpointsCovered`，Path C 为 `PC / 1599 / 1279 / 767 / 375`）。看到提测包有截图就跳过回归 = 谎报。记 `PC` 时写出实际像素宽度。

---

## Step 1 — ChangeSetId 校验（前置门）

**这是第一步，先于任何检查**（handoff-schema §2 要求 QA 在执行任何检查之前完成指纹比对）。

🔴 **先做 §4 工件的结构核（v0.2.2 第六轮补），任一不满足就停机，不要"先跑起来再说"**：

| 核什么 | 不满足时 |
|---|---|
| **20 个字段齐全**（handoff-schema §4；`ApprovedExceptions` 无声明填 `[]`、`OriginTriageRef` 非返工填 `N/A` —— **整字段缺失 ≠ 填 `[]`/`N/A`**） | 停机，`BlockingGaps` 写"§4 工件缺字段：<逐个列出>，需实现 skill 重新输出" |
| **字段取值在 §9.2 封闭枚举内** | 停机。**不得自行"纠正"**：把 `RequiredQAProfile` 里的非法 `QA-Global` 删掉照跑、或替上游补一个缺失取值，都等于替上游修工件，下一轮同样的错会再来一次 |
| `ChangeSetId` / `ChangeSetFingerprint` / `BaseHeadSha` / `ModifiedFiles` 有值 | 同上 |

输出 `ChangeSetIdMatched: No` + `ReadyForDelivery: No`，十一个检查项全 `Blocked`（原因写"§4 工件不合格，未执行"）。

handoff-schema §2 规定要绑三样，**只比对文件名不合格**：

```bash
cd <theme-root>

# (1) 文件集合 —— 🔴 必须与 §2 指纹**同范围**：排除 memory/
#     不排除的话，QA 自己写的 changeset-log 会被当成"上游没申报的额外文件"，
#     把合法日志改动误判成 ChangeSetIdMatched: No，正常交付被永久卡死。
#     🔴 --untracked-files=all 不可省：不加的话**全新目录会被折叠成一条 `?? dir/`**，
#     而 ModifiedFiles 是逐文件列的 —— 一个新建目录就会造成假失配。
git status --porcelain --untracked-files=all -- . ':(exclude)memory/'
git diff --name-only HEAD -- . ':(exclude)memory/'

# (2) BaseHeadSha
git rev-parse HEAD

# (3) ChangeSetFingerprint —— 用 handoff-schema §2 里那段命令原样重算，不要自造变体
#     （两边算的必须是同一个东西，改一个字符就对不上）
```

三样与上游 §4 工件逐项比对：

| 情形 | 判定 |
|---|---|
| 三样全对 | `ChangeSetIdMatched: Yes`，`FingerprintVerifiedAt` 记 `Step1` 的重算值，继续 |
| 文件集合不一致（多文件 / 少文件） | `No` — 停机 |
| **文件没多没少但 `ChangeSetFingerprint` 不匹配** | `No` — 停机。这正是只绑文件名会漏掉的情形：QA 会去验一批它从未见过的代码 |
| `BaseHeadSha` 与当前 HEAD 不一致（期间 commit / rebase / checkout） | `No` — 停机 |

**失配时绝不可自行把额外改动"顺便一起验了"。** 正确做法：停下，要求实现 skill 重新生成 `ChangeSetId` + `ChangeSetFingerprint` + `ModifiedFiles`，然后重跑 QA。

上游工件缺 `ChangeSetFingerprint` 或 `BaseHeadSha`（只给了 `ModifiedFiles`）→ 同样停机，`BlockingGaps` 写"需要按 §2 补齐指纹与基线 SHA"。**不得**退化成只比文件名。

失配时输出的 yaml：

- **十一个状态字段**（`ThemeCheck` / `ThemeRuntimePreview` / `AdminSchemaSave` / `RegressionMatrix` / `LocalizationCheck` / `A11yCheck` / `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked`）与 `ProfileSpecificResults` 一律 `Blocked`（原因：ChangeSet 失配，未执行）。
  > ⚠️ `ApprovedExceptionsChecked` 在失配场景填 `Blocked`（该验但没验成），**不是** `NotApplicable` —— 后者只在 §4 的 `ApprovedExceptions` 确为 `[]` 时成立，而失配时根本没读到上游工件。
  > 🟢 **v0.2.0 已收口**：`FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 三项在 handoff-schema §5 与 §9.2 枚举表里**现已一致**，四值（`Passed`/`Failed`/`Blocked`/`NotApplicable`）都合法。v0.1.0 那条"枚举缺口"提示已废止，不必再在 `BlockingGaps` 登记该歧义。
  > 判定纪律不变：未执行填 `Blocked`，**绝不**改填 `NotApplicable`（未执行伪装成"不需要验"）、`Passed`、或 `Failed`（`Failed` 意为"验了且发现缺陷"，会让实现 skill 去追不存在的缺陷）。
- **记录字段不填状态枚举**：`QAProfilesRun: None`、`BreakpointsCovered: None`、`FingerprintVerifiedAt` 写 `Step1` 的重算结果与失配说明、`ThemeCheckEvidence` / `Evidence` 写一句"ChangeSet 失配，未执行"，`BlockingGaps` 写需要用户/上游做什么。往记录字段里塞 `Blocked` 是类型错误。
- `ChangeSetIdMatched: No`（该字段封闭枚举只有 `Yes` / `No`，**没有 `Blocked`**；未校验一律填 `No`）、`ReadyForDelivery: No`。

> ChangeSetId 校验通过还有一个副作用：它保证了 `HEAD` 就是"改动前"状态，Step 3 的 Theme Check baseline 才成立。

## Step 2 — 指纹二次核验（QA 失效基线）

QA 通过后代码再变，原 QA **自动失效**（handoff-schema §1.4）。所以指纹要算**两次**，`FingerprintVerifiedAt` 字段就是记这两次的：

| 时点 | 动作 |
|---|---|
| **Step 1（验证前）** | 已在上一步算过，记为 `Step1` |
| **所有检查完成后、写 changeset-log 之前** | 再算一次，记为 `Step2` |

两次不等 → 验证期间代码又变了，本轮作废：`ReadyForDelivery: No`，`BlockingGaps` 写"验证期间工作树变动，需重新生成 ChangeSetId"。

`FingerprintVerifiedAt` 要如实写出两次的时点与值，例如 `Step1(14:22) a1b2c3… / Step2(14:51) a1b2c3… 一致`。只写"已核验"→ 视为证据为空。

**`memory/` 已排除在 §2 指纹之外（v0.2.2）**，所以写 changeset-log 不会让刚记录的结论失效。**但顺序仍建议保持**（先算完 `Step2` 再写 log）：它让证据链的时间顺序与因果顺序一致，且不依赖「排除已生效」这个前提。

🔴 **写完 log 不要 commit `memory/`**（v0.2.2 第九轮实测补）：排除只覆盖工作树与暂存区，`git commit` 会改 HEAD，而 HEAD 在指纹 payload 的第一行 —— 一提交，你刚记下的这条结论连同 `BaseHeadSha` 一起失效。log 留在工作树；确需入库只能在**出结论之前**连同主题改动一起提交、然后重新取证重跑。收尾时如果发现 `memory/` 已被提交，按 §1.4 判 `Invalidated`，**不得**以"它只是 memory"为由放行。

### 两条补充门（§2 指纹算不到的盲区）

指纹本身不覆盖以下两类，必须单独查。命中后二选一：解除标志 / 递归取子模块指纹并入 `Evidence` 后继续，或 `ReadyForDelivery: No` + `BlockingGaps` 说明（细节见 `references/evidence-and-invalidation.md` §2）：

```bash
git ls-files -v | grep -E '^[a-z] |^S '            # assume-unchanged / skip-worktree：改动对 git 隐形
git ls-files -s | awk '$1=="160000"{print $4}'    # submodule gitlink：内部变化不进指纹
```

---

## Step 3 — QA-Global（恒执行，与路径无关）

七项，一项都不能省。完整可执行步骤见 `references/qa-global.md`；Theme Check 的 baseline 增量流程与解析脚本见 `references/theme-check-gate.md`。

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

逐项结果写进 `ProfileSpecificResults`，每项同样只取 `Passed`/`Failed`/`Blocked`/`NotApplicable` + 证据。

## Step 5 — 汇总判定与追溯登记

`ReadyForDelivery: Yes` 当且仅当以下**全部**成立（`ChangeSetId` / `ThemeCheckEvidence` / `BreakpointsCovered` / `Evidence` / `BlockingGaps` / `QAProfilesRun` 是记录字段，不参与取值判定）：

```
0. QAAdmissionStatus == Accepted（提测准入门，Step 0）
1. ChangeSetIdMatched == Yes（文件集合 + ChangeSetFingerprint + BaseHeadSha 三样全对）
2. 十一个状态字段 ∈ {Passed, NotApplicable}：
     ThemeCheck / ThemeRuntimePreview / AdminSchemaSave / RegressionMatrix /
     LocalizationCheck / A11yCheck / FixedDimensionCheck /
     ImageQualityCheck / CopyConfigurabilityCheck / StyleHardRuleCheck /
     ApprovedExceptionsChecked（§4 的 ApprovedExceptions 为 [] 时它是 NotApplicable）
3. ProfileSpecificResults 中每一项 ∈ {Passed, NotApplicable}（含上面三条附加触发式检查）
4. BreakpointsCovered 含全部五档（除非 RegressionMatrix 为 NotApplicable）
5. Evidence 对每个 Passed 项都有对应条目；BlockingGaps 为空
6. FingerprintVerifiedAt 的 Step1 与 Step2 一致，且两条补充门均未命中
```

任一条不成立 → `No`。**没有"基本通过""只差一点"这种中间态。**

### `NotApplicable` 的使用边界

按 handoff-schema §1.3：`Blocked` / `NotRun` 不得折算为 pass；`NotApplicable` 是**合法终态**，但必须带适用性证据。落到本 skill：

- `NotApplicable` = "根本不需要验"。必须写出理由并可从 `ModifiedFiles` / diff 复核，例如"本次未改任何 `.liquid`，Theme Check 不适用"。
- `Blocked` = "该验但验不了"。拿不到环境、跑不了工具、没时间——**一律 `Blocked`**。
- **没有证据的 `NotApplicable` 按 `Blocked` 处理**（§1.3 原文）。把 `Blocked` 写成 `NotApplicable` 是最直接的绕过交付门的方式，判契约违规。
- 存疑时选 `Blocked`。

结果追加到项目侧 `memory/changeset-log.md`（**项目运行时状态，不随包分发**；格式与失效语义见 `references/evidence-and-invalidation.md`）。

> 🔴 **迁移轮次照抄本轮那一行（新文档 ID）**：`TestSetMigrationRef` 不进日志列，只可在 `Note` 列写 `Migrated(<旧ID> -> <新ID>)` 作**人读备注**——`Note` 列**不被下游消费**，下一轮 `PreviousAcceptedTestSetTrace` **优先**从 `TestSetTrace` 列取最近一条非 `N/A` 的行（那一行已经是新 ID，链不断）；日志不可得时才走 `package-checklist.md` §3 取数路径②的成对工件。要机器审计迁移本身，查该轮的 `QAIntake` 工件。
>
> 🔴 **v0.2.2 起该表多一列 `TestSetTrace`**：**只要本轮 `QAAdmissionStatus: Accepted`**（提测包过了准入），就把 `QAIntake` 工件里的那一行**原样抄进去**（不重编、不规整、不补全），**与 `ReadyForDelivery` 是 `Yes` 还是 `No` 无关**；`QAAdmissionStatus: Blocked` 才写 `N/A(NotAccepted)`，该轮确无测试集写 `N/A(NoTestSet)`。
> **锚点是「准入通过」不是「交付通过」**：QA 失败的返工轮同样要留下测试集版本，否则跨轮次连续性会在返工那一轮断链——而返工正是最容易换文档的时候。完整规则见 `references/evidence-and-invalidation.md`。

**该文件不存在时**：按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表——**询问用户后可创建空日志**（本 skill 只引用该表，不自行规定；不得凭空补写从没跑过的 QA 行）。另三个迁移状态文件缺失是默认停机，归 `plaud-theme-ux-migration`，本 skill 不写。

log 里的 `Status`（对应 §9.2 的 `memory/` 记录字段 `QAStatus`）取值是 `Pending` / `Valid` / `Invalidated`——它们是**合法的 memory 枚举**，但 🔴 **绝不允许出现在 §5 的阶段契约块里**（§5 的块根本没有 `QAStatus` 字段；阶段契约字段的 `QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`，那是 §4 的事）。两套枚举互不通用。

---

## 特殊情形

### 用户要求跳过验证

用户明说"不用检查了直接发"时：**仍不得输出 `ReadyForDelivery: Yes`。**

正确做法（完整模板见 `references/evidence-and-invalidation.md` §4）：

- §5 yaml 块**保持纯净**——只含 §5 定义的 26 个字段（含 `SubmissionId` / `QAAdmissionStatus` / `StyleHardRuleCheck` / `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` / `Advisories`）。`QAProfilesRun: None`，未执行项一律 `Blocked`，`BlockingGaps` 写 `全部验证项未执行（UserWaived）`，`ReadyForDelivery: No`。
- `QAStatus: Skipped(UserWaived)` 写在**正文**里，**不写进 yaml 块**——handoff-schema §5 没有这个字段，§4 才有；往 §5 块里塞它就是自造字段，违反契约首条。
- 正文用**一句话**说明：已按用户要求跳过验证，未经验证的改动上线风险由用户承担。不劝说、不重复、不长篇解释。

### QA 已通过但代码又变了

按 handoff-schema §2 的命令重算 `ChangeSetFingerprint`，与 changeset-log 中记录的值比对，不等即失效。失效后：把 changeset-log 中该行的状态列改为 `Invalidated`，要求实现 skill 生成**新的** `ChangeSetId` + `ChangeSetFingerprint` + `BaseHeadSha`，整轮重跑。**不允许**"只补验变动的那部分"——同族 bug 与传播链正是靠全量重跑抓到的。

### 上游根本没走过 Assess / Implement

分两种，不要混：

**(a) 有改动但上游没走流程** —— 停机。说明矩阵阶段单向推进，要求先过实现 skill 拿 `ChangeSetId` + `ChangeSetFingerprint` + `BaseHeadSha`。

**(b) 真正的零改动任务**（只读审计 / code review / A11y 审计）—— **本 skill 没有零改动分支。**

handoff-schema §2 规定零改动任务**免 QA**（`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`），工件由实现 skill 按 §4 输出并登记 `ReadOnlyProof`。而 §5 的 26 个字段里既没有 `ModifiedFiles` 也没有 `ReadOnlyProof`——本 skill 在结构上就无法为零改动任务输出完整契约。

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

## 输出契约（不可省略、不可改名）

回复的**最后**必须是一个 ```yaml 代码块，字段与 handoff-schema §5 **一字不差**：不得增删字段、不得改名、不得塞进正文段落。**任何场景都不例外**——用户豁免时也不往块里加 `QAStatus`（写正文）。

```yaml
ChangeSetId:
SubmissionId:
QAAdmissionStatus:
QAAdmissionReason:
ChangeSetIdMatched:
FingerprintVerifiedAt:
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
ReadyForDelivery:
```
