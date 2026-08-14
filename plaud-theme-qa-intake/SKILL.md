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
Step 0  取上游 Implement 工件（ChangeSetId / ChangeSetFingerprint / ModifiedFiles / AssessmentRef）
Step 1  确认提测材料**不在主题仓库工作树内**  ← 前置门，先于一切
Step 2  逐项校验六份材料（见 references/package-checklist.md）
Step 3  站点维度：TargetSites / ExcludedSites / ThemeIds / ScopeSourceRef
Step 4  算 PackageFingerprint
Step 5  汇总 SubmissionPackageStatus，输出 §9.1.2 契约块
```

### Step 0 — 取上游工件

`ChangeSetId` 与 `ChangeSetFingerprint` **从 Implement 工件原样带过来，不重算、不改写**。本 skill 不是主题指纹的 producer 也不是 verifier——重算是 QA 的 Step 1 职责。

> 🔴 **带这两个字段是为了把提测包焊死在某个具体 ChangeSet 上。** QA 的 Step 0 会拿它们与当前 Implement 工件**逐字比对**：对不上 = 这是一份别的任务的提测包，直接 `Blocked`。少写或写错这两个字段，等于交了一份可以被重放到任意任务上的包。

拿不到 `ChangeSetId` → 停机，要实现 skill 补。**不得**自己编一个。

### Step 1 — 材料不得落进主题仓库（前置门）

> 🔴 这是本 skill 唯一会把整件事搞砸的操作，所以放在最前面。

截图、配置文档、测试报告一旦写进主题仓库工作树，`ChangeSetFingerprint` 立刻变化 → QA 的 Step 1 会判 `ChangeSetIdMatched: No` 并停机。**提测方会因为交了材料而过不了自己的准入门。**

校验：

```bash
# 在主题仓库根目录跑，确认工作树与 Implement 交付时一致
git status --porcelain=v1 --untracked-files=all
```

输出里若出现 `.png` / `.jpg` / `.md` / `.pdf` 等材料文件 → **停机**，要求把材料移到仓库外的独立目录或云文档，然后重新走 Implement 的指纹生成。

材料的正确落点：仓库外的独立目录、飞书云文档、Linear 附件。

### Step 2 — 六份材料

逐项判定标准见 **`references/package-checklist.md`**；测试用例的可复核格式见 **`references/test-case-format.md`**。

| 字段 | 一句话判据 |
|---|---|
| `PreviewManifestStatus` | 后台 + 前端链接都**实测访问过**并记时间；后台链接必须能看到并修改配置。内容记在 `PreviewManifest`，判定记在本字段 |
| `ConfigurationGuideStatus` | 新 section / 新配置项必交，含字段说明 + 默认值 + 使用场景 + 填错怎么办 + **关键部分截图** |
| `SelfTestReportStatus` | 用例四段式且**有附件截图/视频**；预期结果写"显示正常"的**视同未测**；另需**测试集溯源三项**（引用 / 基线版本 / 本轮增删清单） |
| `ScreenshotManifestStatus` | 8 张：`375 / 768 / 1024 / 1280 / 1440` + 边界 `767 / 1279 / 1599` |
| `ImpactScopeStatus` | 引用 `AssessmentRef` 的模板/实例结论 + 本 skill 补的站点维度 |
| `ReworkDeltaStatus` | 返工轮次必交「本轮修改点」；首轮提测填 `NotApplicable` |

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

命令见 handoff-schema §9.1.2。它绑的是**材料本身**（各文件 hash + 预览 URL 原文），与主题仓库的 `ChangeSetFingerprint` 是两条独立的链。

**材料放飞书云文档 / Linear 附件时**：本地目录放一份 `materials.tsv` manifest（材料名 / URI / 版本号 / digest 或人工核对时间）参与 hash，见 handoff-schema §9.1.2。manifest 只能证明"引用没变"，云文档内容变化只有平台给了版本号才能测出——这是该链的已知弱环，在 `BlockingGaps` 如实注明。

拿到 `PACKAGE_FINGERPRINT_FAILED` 或空值 → 停机，不得用占位符填。

**QA 会重算这个指纹并与本工件比对**（防止材料在准入通过之后被替换）。所以算完指纹之后**不要再动材料**——动了就要回来重出提测包。

### Step 5 — 汇总

`SubmissionPackageStatus: Complete` 的条件：**六项 Status** 全部为 `Complete` 或 `NotApplicable`（`ConfigurationGuideStatus` / `ReworkDeltaStatus` 可 `NotApplicable` + 理由；其余不可）。

任一项 `Incomplete` → `SubmissionPackageStatus: Incomplete`，`BlockingGaps` 逐条写清**缺哪份材料的哪个字段**，不写"材料不全"。

---

## 停机点

| 情形 | 动作 |
|---|---|
| 拿不到 `ChangeSetId` / Implement 工件 | 停，要实现 skill 补 |
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

**唯一免提测包的情形**（此时 QA 填 `SubmissionId: N/A` + `QAAdmissionStatus: Accepted`）：**零改动只读任务**。

用户说"这次不走提测流程"时，QA 的 `QAAdmissionStatus` 仍为 `Blocked`（按 handoff-schema §1.5 的弃检口径处理，`ReadyForDelivery` 恒为 `No`）——用户可以决定不交材料，但不会因此拿到一张"准入通过"的记录。

「改动很小」也不是理由——那是 `ReconMode: InlineLite` 的判据，与提测材料无关。

> 🔴 **提测的 8 张截图不能替代 QA 自己的断点回归。** 前者是给运营/PM 看的交付材料，后者是 QA 实跑的验证（Path C 为 `PC / 1599 / 1279 / 767 / 375`）。两者互不顶替，都要有。记 `PC` 时写出实际像素宽度（如 `PC(1920)`），光写 `PC` 无法复核。

---

## 输出

回复的最后必须是 handoff-schema §9.1.2 的 ` ```yaml ` 契约块，字段不得增删改名。

再说一遍：**这个块里不出现 `ReadyForDelivery`。**
