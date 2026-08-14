---
name: plaud-theme-qa-intake
description: >
  PLAUD Shopify 主题矩阵的提测准入关口（order 6），夹在 Implement 与 Verify 之间：
  按《DTC 开发交付标准 v1.0》§四 组装并校验提测包，材料不齐 QA 不启动。
  用户说提测、送测、交付物、提测材料、要提交验收、agency 交付、能不能进验收、
  预览链接、后台链接、配置文档、配置说明、字段说明文档、测试文档、测试用例、测试报告、
  断点截图、375/768/1024/1280/1440、边界截图 767/1279/1599、影响范围说明、
  推送站点清单、目标站点、要推哪几个站、theme ID、返工提测、本轮修改点、
  「材料齐了吗」「还缺什么才能提测」「这个用例算不算写清楚了」时使用。
  也在实现 skill 交出 ChangeSetId 之后、调用 plaud-theme-qa 之前**必须**经过本 skill。
  **v0.3.0 起还覆盖集成提测包**：用户说这几块合起来提测、多块合并后一起送测、集成提测、
  合并后的验收材料、集成 QA 要哪些材料时，出 ChangeSetId: N/A(Integration) + 非空 IntegrationOf
  的集成提测包（材料 = 各块材料的并集 + 集成本身的 ReworkDelta）。
  🔴 没有 IntegrationPlan（§9.1 Coordination 工件）的「集成提测」请求先回 plaud-theme-orchestrator
  要集成计划，本 skill 不自行拟定成员清单。
  产出 ArtifactKind: QAIntake 工件：SubmissionId、PackageFingerprint、TargetSites、
  ExcludedSites、ThemeIds、PreviewManifest 与六项材料的 Complete/Incomplete 判定。
  本 skill 只判「材料齐不齐」，不判「代码行不行」：不跑 Theme Check、不做断点回归、
  不看代码质量、不做 A11y 审计（全归 plaud-theme-qa），也不改任何代码。
  **本 skill 永不输出 ReadyForDelivery，一个字都不出现** —— 交付权唯一归 plaud-theme-qa。
  不要路由到本 skill：要跑验收 / 要交付判定 → plaud-theme-qa；写代码修 bug → plaud-theme-dev；
  影响面评估 → plaud-theme-impact；运营反馈归因、缺陷还是变更 → plaud-theme-feedback-triage；
  发版推站、上线后跟踪 → plaud-theme-release-ops。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme QA Intake（提测准入关口）

开工前必读 `plaud-theme-shared/references/handoff-schema.md` §9.1.2（本 skill 的产出契约）与 §0.1（为什么这道门在 Verify 之前）。本文件不重复其中的字段定义，只讲怎么执行。

## 这道门为什么在 QA 之前

《DTC 开发交付标准 v1.0》§四 原文：

> **提测时必须同时提供，缺一不进验收。**

交付物是**进验收的准入条件**，不是验收通过后的产物。把它放在 QA 之后是时序错误——那样等于代码验完了才发现没人能复核。

所以链路是：

```
Implement（交出 ChangeSetId）
    ↓
plaud-theme-qa-intake ← 你在这里：材料齐不齐
    ↓  SubmissionPackageStatus: Complete
plaud-theme-qa        ← 代码行不行
    ↓  ReadyForDelivery: Yes
plaud-theme-release-ops ← 能不能推站
```

## 铁律

> **本 skill 判的是材料，不是代码。永远不要输出 `ReadyForDelivery`。**

- 产出字段用 `Complete` / `Incomplete` / `NotApplicable`，**不用** `Yes` / `No`。这是刻意的语法隔离，防止下游把提测通过误读成第二个发布许可（handoff-schema §9.2）。
- 不跑 `shopify theme check`、不开浏览器测断点、不读代码找 bug、不评 A11y。看到代码问题**只记不判**，写进 `BlockingGaps` 交给 QA。
- 不替实现方补材料。截图缺了就是 `Incomplete`，不能"我帮你描述一下大概什么样"。
- 不改任何文件（`ModifiedFiles` 概念在本 skill 不存在）。

## 本 skill 不做什么

| 不做 | 归谁 |
|---|---|
| Theme Check、断点回归、多语言、A11y、写死宽高、图片清晰度 | `plaud-theme-qa` |
| 影响面事实收集（理论引用 vs 实际实例、依赖树） | `plaud-theme-impact`（本 skill 只**引用** `AssessmentRef`，不重算） |
| 判反馈是缺陷还是变更 | `plaud-theme-feedback-triage` |
| 推站清单二次确认、发版、上线后跟踪 | `plaud-theme-release-ops` |
| 写代码、修 bug、补 schema | 三个实现 skill |

---

## 执行顺序

```
Step 0  取上游 Implement 工件（ChangeSetId / ObjectFormat / ThemeTreeOid /
        ChangeSetScopeFingerprint / BaseHeadSha / ModifiedFiles / AssessmentRef / OriginTriageRef）
        集成提测包走 Step 0-I（取 IntegrationPlan：MemberChangeSets + IntegrationBaseCommit +
        IntegrationResultTreeOid〔顶层 ObjectFormat / ThemeTreeOid 原样透传，本 skill 不自算〕，
        出 ChangeSetId: N/A(Integration) + IntegrationOf）
Step 1  确认提测材料**不在主题仓库工作树内**  ← 前置门，先于一切
Step 2  逐项校验六份材料（见 references/package-checklist.md）
Step 3  站点维度：TargetSites / ExcludedSites / ThemeIds / ScopeSourceRef
Step 4  算 PackageFingerprint
Step 5  汇总 SubmissionPackageStatus，输出 §9.1.2 契约块
```

### Step 0 — 取上游工件

`ChangeSetId` 与**身份三元组** `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` **从 Implement 工件（§4）原样带过来，不重算、不改写**。本 skill 不是这三个字段的 producer，也不是 verifier——重算与比对是 QA 的 Step 1 职责。

> 🔴 **v0.3.0：身份是三个字段，不是一个。** 📎 v0.2.3 的单字段 `ChangeSetFingerprint` 已废止（handoff-schema §2.1），下游任何地方再出现即违规。三个必须**一起**抄全：只抄 `ThemeTreeOid` 而丢掉 `ObjectFormat`，`sha1` 与 `sha256` 仓库对同一份内容算出的 oid 完全不同、无从比对；只抄前两个而丢掉 `ChangeSetScopeFingerprint`，就绑不住「这一块声明了哪些路径」。
>
> 🔴 **带这四个字段是为了把提测包焊死在某个具体 ChangeSet 上。** QA 的 Step 0 会拿它们与当前 Implement 工件**逐字比对**：对不上 = 这是一份别的任务的提测包，直接 `Blocked`。少写或写错，等于交了一份可以被重放到任意任务上的包。

`BaseHeadSha` 也要一并取（Step 1 的「已 commit 的材料」那条命令要用它）。v0.3.0 起它**不再是失配判据**（期间 commit / rebase / checkout 不再让 ChangeSet 失效），但**仍然必填、且必须是可解析的 commit-ish**（handoff-schema §2.1 / R-BLOCK-9）。

拿不到 `ChangeSetId` → 停机，要实现 skill 补。**不得**自己编一个。三元组任一字段缺失 → 同样停机要实现 skill 按 §4 重出，**缺失 ≠ `N/A`**（`N/A` 只对零改动只读任务成立，而零改动任务根本不进本 skill）。

🔴 **`OriginTriageRef` 也必须在 Step 0 一起取**（v0.2.2 第八轮补）。它是 §4 里唯一承载"这一块是不是返工"的字段（`N/A` = 非返工；填了 §9.1.3 的 `TriageId` + `ItemId` = 由反馈返工产生）。Step 2 的 `ReworkDeltaStatus` 要判"首轮还是返工"，此前的消费清单里却没有它——没有事实源，agent 只能默认填 `NotApplicable`，于是**返工轮次的「本轮修改点」整份漏收**。判据固定为：

| `OriginTriageRef` | `ReworkDeltaStatus` |
|---|---|
| `N/A` | `NotApplicable`（首轮提测） |
| 有 `TriageId` + `ItemId` | 必须收到「本轮修改点」，否则 `Incomplete` |
| 字段整个缺失 | 停机，要实现 skill 按 §4 重出——**缺失 ≠ `N/A`** |

🔴 **集成提测包不走这张表**：集成包没有单一的 `OriginTriageRef`。它的 `ReworkDeltaStatus` 判的是**集成本身的 ReworkDelta**（合并过程中为消解冲突所做的改动：token / locale 键 / schema 值的取舍）——集成过程一个字都没改时才可填 `NotApplicable`，且要在 `BlockingGaps` 之外的正文里说明"本次集成为 no-op 合并"。各块自己的返工 delta 已经在各块的包里，不在这里重收。

### Step 0-I — 集成提测包（`QAScope: Integration` 的上游）

多块合并后要跑一次集成 QA 时，那次 QA **结构上取不到任何一块的提测包**（每块的包绑的是那一块的树）。R-BLOCK-1 的裁决是：**由本 skill 出一份集成提测包**，而不是豁免 Step 0，也不是复用最后一块的包。

| 字段 | 集成提测包的取值 |
|---|---|
| `ChangeSetId` | `N/A(Integration)` |
| `IntegrationOf` | **必填非空**，逐块一条（下表给来源） |
| `ChangeSetScopeFingerprint` | `N/A(Integration)` |
| `ObjectFormat` / `ThemeTreeOid` | 从 `IntegrationPlan.IntegrationResultTreeOid` **原样透传**（取法见下方红框；本 skill 不自算） |
| `SubmissionId` | **新开一个 `SUB-<YYYYMMDD>-<NN>`**，编号沿用本 skill 既有约定。🔴 **不得复用任何一块的 `SubmissionId`** —— 复用等于把某一块的材料判定冒充成集成包的判定。**本 skill 能机械核的只有一条**：新 ID 不得等于 `IntegrationOf` 里任何一项的 `SubmissionId`。📌 矩阵**没有**全局发号册，"同日全局唯一"本 skill 证明不了，**不要声称**（已上报为 shared 侧待补的承载） |

> 🔴 **本工件的 `IntegrationOf` 只有两段：`ChangeSetId` + `SubmissionId`。** 逐块的 `ImplementArtifactRef` / `QARef` / 三元组是 **§5 Verify 工件**的 `IntegrationOf.Members[]` 才有的结构，**不要往提测工件里加**——加了就是自造字段，26 key 封闭集当场违规。集成 QA 的逐块三元组比对由 QA 自己从各块 §4 工件取，不经本 skill。
>
> 🔴 **`ChangeSetId: N/A(Integration)` 而 `IntegrationOf` 为空 = 契约违规，停机。** 这不是"保守起见留空"：空的 `IntegrationOf` 会让集成 QA 恒 `Blocked` / `MissingArtifact`、恒拿不到交付许可，是死锁不是保守。

**每一项的来源与取不到时的合法取值**（🔴 这张表是本 skill 历史上翻车最多的一族：写了控制却取不到数据）：

| 项 | 唯一事实源 | 取不到时 |
|---|---|---|
| 成员 `ChangeSetId` 清单 | §9.1 Coordination 工件的 `IntegrationPlan.MemberChangeSets`（producer = `plaud-theme-orchestrator`） | **没有 `IntegrationPlan`** → 停机，回 orchestrator 要集成计划。本 skill **不自行拟定成员清单**，"看起来就是这几块"不算来源 |
| 每块的 `SubmissionId` | ① §9.1 Coordination 工件的 `ChangeSetStatus`（canonical 明写「含 `SubmissionId`（提测准入）」）；② 用户直接给出该块那份 `QAIntake` 工件原文（它才是 `SubmissionPackageStatus` 的一手承载者） | 🔴 **`memory/changeset-log.md` 不是来源** —— 它没有 `SubmissionId` 列（列定义见 handoff-schema §9.2「`memory/` 记录字段」）。两条路径都取不到该块的包 → 见下方「降级」 |

**先把两种情形分开——它们的正确处置不同，混成一条就会逼出一个契约里根本没有的取值：**

| 情形 | 处置 |
|---|---|
| **该块的 `SubmissionId` 已知，但那份包的 `SubmissionPackageStatus` 不是 `Complete`** | **出工件**：`IntegrationOf` 里照写**那个真实的 `SubmissionId`**（它确实存在，不许改写成别的东西），顶层 `SubmissionPackageStatus: Incomplete`，`BlockingGaps` 指名"哪一块的包缺哪一项 Status"。这是 R-BLOCK-1 说的降级，完全可序列化 |
| **该块根本没有提测包**（`ChangeSetStatus` 与用户手上都没有该块的 `SubmissionId`） | **停机，不出契约块**。26 key 契约要求 `IntegrationOf` 每项都有 `SubmissionId`，而这个值**不存在**——`BlockingGaps` 写进正文，指名是哪一块从未提测、要它先补一次**单块提测**拿到真 ID 与 `Complete` 的包。🔴 **不得为此自造占位取值**（`Unavailable(...)` / `N/A` / `TBD` 都不行）：canonical §9.1.2 与 §9.2 都没有为这个位置定义"取不到"的取值，自造一个等于给封闭契约开口子。本 skill 既有的同族做法就是这样——拿不到 `ChangeSetId` 停机不编，`PACKAGE_FINGERPRINT_FAILED` 停机不用占位符 |

🔴 **无论走哪一格，都不许把那一块从 `IntegrationOf` 里删掉**（第一格里它必须在场，第二格里压根不出块）。删掉之后集合等式就变成与一份被裁剪过的成员清单比，那一块的材料**整份缺席而 intake 照样 `Complete`**——正是 canonical 点名要堵的洞。

**怎么核"那份包确实存在且 `Complete`"**（不能只拿到一个 ID 就算数）：顺着 `ChangeSetStatus` 里该块的 handoff 引用、或用户提供的该块 `QAIntake` 工件原文，逐项核 `ChangeSetId` / `SubmissionId` / `SubmissionPackageStatus` 三者自洽。**原工件读不到 → 顶层 `Incomplete` + `BlockingGaps` 指名**，🔴 **"读不到"不得当成"核过了"**。

🔴 **另外三条必须当场拦下的结构错**（只核集合相等挡不住）：

1. `IntegrationOf` 里 `ChangeSetId` **重复**，或与 `MemberChangeSets` **集合不等**（多一块、少一块都算）→ 停机。
2. 两块引用了**同一个 `SubmissionId`** → 停机；一个提测包绑的是一块的树，不可能同时是两块的材料。
3. 集成包的材料根**不是各块材料的真并集**（少了某块的截图 / 自测报告）→ 该项 `Incomplete`；核法见 `references/package-checklist.md` §7.5（逐块用 `SubmissionId` 找回该块 `QAIntake` 的 `PackageRootRef` 与材料清单再对，**读不到 ≠ 核过了**）。🔴 **不得用 symlink 把各块材料"链"进集成材料根**——`plaud_package_fingerprint` 对 symlink 是 fail closed，会**直接报 `UNSUPPORTED_MATERIAL_OBJECT` 并返回 1、一个指纹都算不出来**（不是"算出一个漏内容的指纹"）。要并集就**真拷贝**。

> **矩阵能保证的到此为止，多的不要声称。** 集成包只有**一个** `PackageRootRef` / `PackageFingerprint`，`IntegrationOf` 只承载成员的 `ChangeSetId` + `SubmissionId`，**没有**逐成员的包根或包指纹。所以矩阵能机械证明的是「集成材料根自准入以来没被换过」，**不能**机械证明「它确实是各块材料的并集」——那一层靠 §7.5 那套逐项人读核对，能发现"某块材料整份没进来"，但证明不了"进来的就是该块当初提测的那份字节"。**不要把它写成或读成指纹级保证。**

**集成树的 `ObjectFormat` / `ThemeTreeOid` 怎么取。** 集成树是**人**做的 merge（R-BLOCK-4，矩阵不做 merge），因此它**没有任何 Implement 工件**可抄；`IntegrationPlan.IntegrationBaseTreeOid` 是**基准树**不是结果树，抄它就是拿基准冒充结果；集成 QA 的 `VerifiedThemeTreeOid` 又在本 skill **之后**才产生。这三条路确实都不通——所以 canonical 给了第四条：

> 🔴 **集成路径下，这一对从 `IntegrationPlan.IntegrationResultTreeOid` 原样透传**（handoff-schema §9.1「两个时点」）。
> 它的 producer 是 **`Integrator`（那个做 merge 的人）**：集成落盘后、提测之前，由他在集成后的工作树根目录跑一次 `plaud_theme_tree`，把前两段交给 `plaud-theme-orchestrator` 更新**同一个 `OrchestrationId`** 的协调工件。本 skill 只是**搬运**。
> 🔴 **本 skill 不得自己跑 `plaud_theme_tree` 现算一个**（v0.3.0 收尾验收改：此前这里写的正是"本 skill 自己算"）。理由不是洁癖：集成树的身份要绑住的是**集成者交付了什么**，本 skill 现算只是给"提测那一刻工作树长什么样"拍张照——集成者事后改了树再叫提测，照样得到一份自洽的包。让取证方（集成者）与验证方（QA）互相独立，中间这一环就必须是纯透传；本 skill 既不是 producer 也不是 verifier，与开头那条口径一致。

**协调工件没填 `IntegrationResultTreeOid` 一律 fail closed**：拿到的是**未补第 6 项的规划期版本**、或 `ObjectFormat` 与 oid 只有一半、或 oid 长度与 `ObjectFormat` 不符 → **停机，不产出契约块**，`BlockingGaps` 指名要 `Integrator` 先补取证。🔴 **不得填 `N/A`**：`ObjectFormat` 的 `N/A` 只对零改动只读任务成立，在这里填它是把「取证缺席」伪装成「本来就没有」。也不得填占位符、不得拿 `IntegrationBaseTreeOid` 或任一成员的 `ThemeTreeOid` 顶替、不得退到"大概是这个值"。
**QA 那一侧仍会独立重算**：Step 1 在集成树上重算并与本工件逐字比对，所以"材料通过准入之后树被改掉"照样会被抓住 —— 现在多绑住了一层「集成者当初声明的结果树」。

### Step 1 — 材料不得落进主题仓库（前置门）

> 🔴 这是本 skill 唯一会把整件事搞砸的操作，所以放在最前面。

截图、配置文档、测试报告写进主题仓库工作树的**可发布目录**（`assets` / `blocks` / `config` / `layout` / `locales` / `sections` / `snippets` / `templates` + `.shopifyignore`）时，`ThemeTreeOid` 会变化 → QA 的 Step 1 判 `ChangeSetIdMatched: No` 并停机。

> 🔴 **"指纹会变"不是一道门，别指望它兜底 —— v0.3.0 起这条兜底比 v0.2.x 还要弱**（v0.2.2 第十轮实测更正的结论在新模型下**依然成立、而且更强**）：
> - v0.3.0 的身份只绑**可发布内容**（handoff-schema §2.1）。材料放进**任何非可发布目录**（如仓库根的 `qa-artifacts/`，无论是否被 gitignore）→ `ThemeTreeOid` **明确不变**。这在 v0.3.0 是刻意的**收益**（临时文件、build 源、`.theme-check.yml` 都不再让身份漂移），代价就是它**更不可能**顺手挡住材料落仓。
> - 材料是 `memory/` 下的 **`.md`** → `memory/` 本来就不在可发布面，`ThemeTreeOid` 看不见它，本 skill 的校验命令也排除它 —— 依然是三层全部看不见。
> - 材料**只有**在被写进 §4 `ModifiedFiles` 声明清单时才会进 `ChangeSetScopeFingerprint`；而提测材料当然不会被声明成本次改动，所以这条也兜不住。
>
> 📎 v0.2.3 这里曾用 §2 的 `IGNORED_PUBLISHABLE_FILE` 门作反例（"该门只扫八个可发布目录，兜不住"）。v0.3.0 起该门已退役（`git add -A -f` 让被 gitignore 的可发布文件直接进树），**那条论证的对象已经不存在**，所以换成上面按可发布面重述的口径 —— 但**结论一个字都没变**：这道门必须**自己查**，下面三条命令缺一不可，不能只跑第一条。

校验：

```bash
# 🔴 先确认站位与材料落点（v0.2.3 第十轮演练补：下面三条在**子目录**下会 rc=0 且输出为空 ——
#    报告"干净"而其实什么都没查；而**已 commit 的材料**这三条一条都看不见，
#    `git add -A` 恰恰是最常见的落法，此时 Step 1 是材料落仓的唯一门，等于没有门）。
cd "$(git rev-parse --show-toplevel)" || exit 1        # 站位：必须在仓库根
# 材料根必须落在主题仓库**之外** —— 这是唯一一条机械可判的硬边界
PR=$(cd "<PackageRootRef>" && pwd -P) && TOP=$(pwd -P)
case "$PR/" in "$TOP"/*) echo "MATERIALS_INSIDE_REPO: $PR 在主题仓库内，停机"; exit 1 ;; esac
# 已 commit 的材料：看本 ChangeSet 相对 BaseHeadSha 新增/修改了哪些文件
# 🔴 集成提测包用哪个基准（v0.3.0 补）：集成包**没有 §4 工件、因而没有 BaseHeadSha**。
#    此时下面这条里的 <BaseHeadSha> 一律换成 IntegrationPlan.IntegrationBaseCommit
#    （§9.1，canonical 已要求它**必须可解析**）。取不到或不可解析 → 停机回 orchestrator，
#    **不得**退到 HEAD~1 之类的近似基准，也**不得**因为"没有 BaseHeadSha"就跳过这条命令。
#    🔴 换的只是这条命令的输入，**不往 26-key 契约块里加任何字段**。
# 🔴 先验基准可解析再跑（v0.3.0 补）：下面那条管道里 git log 失败会被 sed / sort 吃掉、
#    整条 rc=0 且输出为空 —— 又一次"报告干净而其实什么都没查"。BaseHeadSha 在 v0.3.0 不再是
#    失配判据，但仍必填且必须可解析（§2.1 / R-BLOCK-9），解析不了就是**这道门验不了**，不是"没问题"。
git rev-parse --verify --quiet "<BaseHeadSha>^{commit}" >/dev/null \
  || { echo "BASE_HEAD_UNRESOLVABLE: 基准不可解析（单块=BaseHeadSha / 集成=IntegrationBaseCommit），已 commit 材料这条查不了，停机"; exit 1; }
git log --name-only --pretty=format: "<BaseHeadSha>..HEAD" -- . ':(exclude)memory/' | sed '/^$/d' | LC_ALL=C sort -u

# 在主题仓库根目录跑。下面三条都要跑：
# (1) 常规位置：工作树是否与 Implement 交付时一致
# 🔴 必须排除 memory/：它不属于 ChangeSet，也已排除在 §2 指纹与 QA 集合比对之外。
#    不排除的话，Path C 合法的 memory/模块清单.md 更新会被当成"材料落仓"，正常流程被假阻断。
git status --porcelain=v1 --untracked-files=all -- . ':(exclude)memory/'

# (2) 🔴 被 gitignore 的位置（不在可发布面 = 不进 ThemeTreeOid，git status 也看不见）
git ls-files --others --ignored --exclude-standard -- . ':(exclude)memory/'

# (3) 🔴 memory/ 下的一切（不在可发布面 = 不进 ThemeTreeOid，§2 盲区自检只找非 .md）
git status --porcelain=v1 --untracked-files=all -- memory/
find memory -type f 2>/dev/null | LC_ALL=C sort
```

以上**任何一条**（含站位检查、材料根边界、已提交清单）列出本次提测的六项材料（截图 / 配置文档 / 测试报告 / 影响范围说明 / 返工修改点）→ **停机**，要求把材料移到仓库外的独立目录或云文档，然后重新走 Implement 的指纹生成。(2)(3) 命中的尤其要停：那两处**不在可发布面、身份三元组绑不住**，材料事后被换掉没有任何机制会发现。

> 🔴 **`.md` 不能一律当材料**：主题仓库里本来就有合法的 `.md`（`README` / `docs/` / `dev/` 下的说明）。判据是**这个文件是不是本次提测的六项材料之一**（截图 / 配置文档 / 测试报告 / 影响范围说明 / 返工修改点），不是看扩展名。拿不准就问，别按后缀一刀切。

材料的正确落点：仓库外的独立目录、飞书云文档、Linear 附件。

### Step 2 — 六份材料

逐项判定标准见 **`references/package-checklist.md`**；测试用例的可复核格式见 **`references/test-case-format.md`**。

| 字段 | 一句话判据 |
|---|---|
| `PreviewManifestStatus` | 后台 + 前端链接都**实测访问过**并记时间；后台链接必须能看到并修改配置。内容记在 `PreviewManifest`，判定记在本字段 |
| `ConfigurationGuideStatus` | 新 section / 新配置项必交，含字段说明 + 默认值 + 使用场景 + 填错怎么办 + **关键部分截图** |
| `SelfTestReportStatus` | 用例四段式且**有附件截图/视频**；预期结果写"显示正常"的**视同未测**；另需 **`TestSetTrace`** + **`PreviousAcceptedTestSetTrace`**（稳定文档 ID **@不可变 revision**；Added / Updated / Removed 三类分列，或 `None(reason)`；与上一轮同 ID、不同 revision）。`PreviousAcceptedTestSetTrace` 另可取 `None(FirstSubmission)` 或 `Unavailable(<原因>)`（后者仅限**找不到任何非 `N/A` 历史 trace 且用户给不出上一轮工件**，此时不判 `Incomplete`、改记 QA 的 `Advisories`）。**换了新测试文档时另需 `TestSetMigrationRef`**：结构化**五段**（`From` 逐字等于 `PreviousAcceptedTestSetTrace` 的 `ID@revision` 前缀段、`To` 逐字等于本轮 `TestSetTrace` 的、`Reason` 取封闭枚举三值、`ReasonRef` 用 `Local(<相对路径>)` 或 `Manifest(<条目名>)`、**`CaseDisposition` 只能 `Local(...)`**（清单要核内容，云端只能核 revision/digest）指向**进了 `PackageFingerprint`** 的材料，悬空引用或路径跑出材料根即 `Incomplete`；`CaseDisposition` 的清单还要条数 = `OldCaseCount`、旧 ID 不重复），**自由文本理由一律 `Incomplete`**；未换文档 `N/A(SameDocument)`，无可比对上一轮 `N/A(NoPreviousTrace)`。完整规则见 `references/package-checklist.md` §3 / §3.1 |
| `ScreenshotManifestStatus` | 8 张：`375 / 768 / 1024 / 1280 / 1440` + 边界 `767 / 1279 / 1599` |
| `ImpactScopeStatus` | 引用 `AssessmentRef` 的模板/实例结论 + 本 skill 补的站点维度 |
| `ReworkDeltaStatus` | 返工轮次必交「本轮修改点」；首轮提测填 `NotApplicable`。**首轮/返工以 Step 0 取到的 `OriginTriageRef` 判定**，不靠感觉、不靠用户口述 |

### Step 3 — 站点维度（`AssessmentRef` 覆盖不到）

`plaud-theme-impact` 的 `AssessmentRef` 回答的是「**哪些模板/实例**受影响」，它**不回答**「要推**哪些站点**」。DTC §三 第 4 条点名推错站点是"过去扣分最多的一项"，所以这一层必须单独填：

| 字段 | 要求 |
|---|---|
| `TargetSites` | 逐个站点显式列出。**禁止**写"相关站点""受影响的站"这类模糊表述 |
| `ExcludedSites` | 明确不推的站点 + 每个的原因（17 站里排除了谁、为什么） |
| `ThemeIds` | 各站点对应的主题 ID——预览和验收都要定位到具体主题，只有站点域名不够 |
| `ScopeSourceRef` | 站点清单的来源：运营需求单 / Linear issue / 飞书消息链接。**没有出处的清单不算数** |

拿不到站点清单 → 停机问运营，**不要**按"这个模块看起来是全站的"推断。

### Step 4 — `PackageFingerprint`

命令见 handoff-schema §9.1.2。它绑的是**材料本身**（各文件 hash + 预览 URL 原文），与主题仓库的身份三元组（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`）是两条独立的链。

> 📎 **v0.3.0 的身份模型改动完全没有波及这条链。** `plaud_package_fingerprint` hash 的是提测材料目录，与 git 无关：算法、`PLAUD_PACKAGE_ROOT` 根守卫、`PLAUD_PREVIEW_URLS` 构造规则**一个字都没改**。

🔴 **必须在材料根目录执行，并把 `PLAUD_PACKAGE_ROOT` 设成本工件的 `PackageRootRef`**（v0.2.2 第十轮补）。此前该函数没有根目录守卫：在材料树的**子目录**里跑，`find .` 只看得见该子目录，于是**静默算出一个子集指纹并返回 0**。最坏情形不是失配而是 **false acceptance** —— producer 与 QA 用同一个错误的 `PackageRootRef` 时两边算出同一个值、`Accepted` 照发，而自测报告 / 配置说明 / 截图**全部不在绑定链里**。现在函数会自查 cwd 是否逐字节等于 `PLAUD_PACKAGE_ROOT`，不等即 `NOT_PACKAGE_ROOT` 停机；没设该变量则 `NO_PACKAGE_ROOT` 停机。**拿到这两个错误一律停机重跑，不要退到「大概是对的」。**

```bash
cd "<PackageRootRef>"
export PLAUD_PACKAGE_ROOT="$(pwd -P)"
export PLAUD_PREVIEW_URLS=...   # 构造规则见 §9.1.2 函数内注释
plaud_package_fingerprint || { echo "PACKAGE_FINGERPRINT_FAILED"; exit 1; }
```

**材料放飞书云文档 / Linear 附件时**：本地目录放一份 `materials.tsv` manifest（材料名 / URI / **不可变版本号或 revision** / **内容 digest**）参与 hash，见 handoff-schema §9.1.2。

🔴 **不能内容绑定的材料一律判 `Incomplete`，不是"记进 `BlockingGaps` 就放行"**（v0.2.2 更正：此前这里写成"已知弱环，在 `BlockingGaps` 如实注明"，与 canonical 相反，等于给防替换链留了个公开的洞——把材料挂在无版本外链上、内容随便换、指纹照样对得上、`SubmissionPackageStatus` 照样 `Complete`）。

| 材料位置 | 怎么进指纹链 |
|---|---|
| 本地文件（截图等） | 直接 hash 文件内容 |
| 飞书云文档 | manifest 记 URI + **文档版本号 / revision**；改了内容版本号会变 → 指纹变 |
| Linear 附件 | manifest 记 URI + 附件 ID |
| **无版本号 / 无 digest 可取的外链** | 🔴 **不允许** → 该材料 `Incomplete`。要么下载一份到本地目录参与 hash，要么换成能取版本号的载体 |

`BlockingGaps` 是**停机项**，不是免责栏。完整规则见 handoff-schema §9.1.2。

拿到 `PACKAGE_FINGERPRINT_FAILED` 或空值 → 停机，不得用占位符填。

**QA 会重算这个指纹并与本工件比对**（防止材料在准入通过之后被替换）。所以算完指纹之后**不要再动材料**——动了就要回来重出提测包。

### Step 5 — 汇总

`SubmissionPackageStatus: Complete` 的条件：**六项 Status** 全部为 `Complete` 或 `NotApplicable`（`ConfigurationGuideStatus` / `ReworkDeltaStatus` 可 `NotApplicable` + 理由；其余不可）。

🔴 **集成提测包（`ChangeSetId: N/A(Integration)`）另有一组必要条件，六项全绿也不够**——少了这一层，成员包整份缺席而六份材料看着齐全时照样能出 `Complete`：

🔴 **先分清两类失败**：**结构违规 = 停机不出契约块**（工件本身立不住）；**材料不足 = 出工件并判 `Incomplete`**（工件成立，只是材料没齐）。把前者写成 `Incomplete` 等于交出一份形状就是坏的工件。

| 追加条件 | 不满足时 | 哪一类 |
|---|---|---|
| `IntegrationOf` 非空 | 停机 | 结构违规 |
| 与 `IntegrationPlan.MemberChangeSets` **集合相等**，且两侧各自**无重复** | 停机（计划侧重复回 orchestrator） | 结构违规 |
| 各成员 `SubmissionId` 互异，且都不等于顶层 `SubmissionId` | 停机 | 结构违规 |
| `ObjectFormat` / `ThemeTreeOid` 逐字等于 `IntegrationPlan.IntegrationResultTreeOid`（协调工件已补第 6 项） | 停机，不出契约块 | 结构违规。**不得**自己跑 `plaud_theme_tree` 现算一个顶上 |
| **每一项**的 `SubmissionId` 真实存在（情形 B：不存在 → 停机，见 Step 0-I） | 停机 | 结构违规 |
| 每一项那份包的 `SubmissionPackageStatus` 为 `Complete`（情形 A） | `Incomplete` + `BlockingGaps` 指名 | 材料不足 |
| 集成材料根是各块材料的真并集（核法见 `references/package-checklist.md` §7.5） | `Incomplete`；`PackageRootRef` 不可达时降为 advisory + `BlockingGaps` | 材料不足 |
| 集成本身的冲突消解记录已交（§7.6） | `Incomplete`（**不得凭口述填 `NotApplicable`**） | 材料不足 |

任一项 `Incomplete` → `SubmissionPackageStatus: Incomplete`，`BlockingGaps` 逐条写清**缺哪份材料的哪个字段**，不写"材料不全"。

---

## 停机点

| 情形 | 动作 |
|---|---|
| 拿不到 `ChangeSetId` / Implement 工件 | 停，要实现 skill 补 |
| 身份三元组任一字段缺失（`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint`） | 停，要实现 skill 按 §4 重出。**缺失 ≠ `N/A`** |
| `BaseHeadSha` 缺失或不可解析（单块） | 停。Step 1 的「已 commit 的材料」这条**验不了**（不是"没问题"），要**实现 skill**补一个可解析的 commit-ish |
| 集成提测：拿不到 `IntegrationPlan` | 停，回 `plaud-theme-orchestrator` 要集成计划。**不自行拟定成员清单** |
| 集成提测：`ChangeSetId: N/A(Integration)` 而 `IntegrationOf` 为空 | 停（契约违规）。空 `IntegrationOf` 会让集成 QA 恒 `Blocked`，是死锁不是保守 |
| 集成提测：`IntegrationOf` 与 `MemberChangeSets` 集合不等 / 成员重复 / 两块共用一个 `SubmissionId` | 停 |
| 集成提测：某块 `SubmissionId` 已知但那份包不是 `Complete` | **不停机**，出工件：照写真实 `SubmissionId` + 顶层 `SubmissionPackageStatus: Incomplete` + `BlockingGaps` 指名道姓。🔴 **不得把该块从 `IntegrationOf` 里删掉** |
| 集成提测：某块**根本没有提测包**（ID 不存在） | 停，不出契约块。要它先补一次单块提测。🔴 **不得自造占位取值**（`Unavailable(...)` / `N/A` / `TBD` 都不行） |
| 集成提测：拿不到 `IntegrationPlan.IntegrationBaseCommit` 或它不可解析 | 停，回 orchestrator。Step 1「已 commit 的材料」那条**验不了**，不得退到 `HEAD~1` 之类近似基准，也不得跳过 |
| 集成提测：`plaud_theme_tree` 任何一段失败 | 停，不产出契约块。**不得填 `N/A`**、不得填占位符 |
| 提测材料在主题仓库工作树内 | 停，要求移出并重新生成 ChangeSet |
| 拿不到站点清单或清单没有出处 | 停，问运营；不推断 |
| 预览链接打不开 / 后台链接只读 | `PreviewManifest` 判 `Incomplete`（DTC 原文：失效链接视同未提测） |
| 拿不到主题 ID | 停，要；不用站点域名顶替 |
| 材料里有 PRD 之外的功能 | 记进 `BlockingGaps`，交 `plaud-theme-feedback-triage` 判归属，本 skill 不裁决 |
| `PACKAGE_FINGERPRINT_FAILED` | 停，排查后重算 |

停机时输出 `BlockingGaps` 并写清**需要谁提供什么**，不要交半份包再附一句"可能还差点东西"。

---

## 与 QA 的接力

QA 的 Step 0 会读本工件：

- `SubmissionPackageStatus: Complete` → `QAAdmissionStatus: Accepted`，QA 继续走它的指纹校验。
- `SubmissionPackageStatus: Incomplete` → `QAAdmissionStatus: Blocked` + `ReadyForDelivery: No`，**QA 零验证项执行**，并把本 skill 的 `BlockingGaps` 原样带出。

🔴 **不存在"免提测包但仍进 QA"的情形**（v0.2.2 第八轮更正）。此前这里写「零改动只读任务免提测包，QA 填 `SubmissionId: N/A` + `QAAdmissionStatus: Accepted`」——那条路第七轮已随 `ZeroChangeReadOnly` 一并废止：零改动任务**根本不进本 skill、也不进 QA**（handoff-schema §2 / §5 准入门第 3 条），它由实现 skill 出 §4 工件 + `ReadOnlyProof`，`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)` 收尾。给一个没有 ChangeSet 的只读审计发 `Accepted`，等于发一张没有验证含义的通过记录。

用户说"这次不走提测流程"时，QA 的 `QAAdmissionStatus` 仍为 `Blocked`（按 handoff-schema §1.5 的弃检口径处理，`ReadyForDelivery` 恒为 `No`）——用户可以决定不交材料，但不会因此拿到一张"准入通过"的记录。

「改动很小」也不是理由——那是 `ReconMode: InlineLite` 的判据，与提测材料无关。

> 🔴 **提测的 8 张截图不能替代 QA 自己的断点回归。** 前者是给运营/PM 看的交付材料，后者是 QA 实跑的验证（Path C 为 `PC / 1599 / 1279 / 767 / 375`）。两者互不顶替，都要有。记 `PC` 时写出实际像素宽度（如 `PC(1920)`），光写 `PC` 无法复核。

---

## 输出

回复的最后必须是 handoff-schema §9.1.2 的 ` ```yaml ` 契约块，**26 个字段**（v0.2.3 为 23 个），顺序照 canonical 的 yaml 模板，字段不得增删改名。

> 单块与集成提测**共用同一套 26 key 封闭集**，靠 `ChangeSetId` / `IntegrationOf` 判别，**不另立一份集成模板**——两套近似模板必然漂移。

再说一遍：**这个块里不出现 `ReadyForDelivery`。**
