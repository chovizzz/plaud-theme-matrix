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
Step 0  取上游 Implement 工件（ChangeSetId / ChangeSetFingerprint / ModifiedFiles / AssessmentRef / OriginTriageRef）
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

🔴 **`OriginTriageRef` 也必须在 Step 0 一起取**（v0.2.2 第八轮补）。它是 §4 里唯一承载"这一块是不是返工"的字段（`N/A` = 非返工；填了 §9.1.3 的 `TriageId` + `ItemId` = 由反馈返工产生）。Step 2 的 `ReworkDeltaStatus` 要判"首轮还是返工"，此前的消费清单里却没有它——没有事实源，agent 只能默认填 `NotApplicable`，于是**返工轮次的「本轮修改点」整份漏收**。判据固定为：

| `OriginTriageRef` | `ReworkDeltaStatus` |
|---|---|
| `N/A` | `NotApplicable`（首轮提测） |
| 有 `TriageId` + `ItemId` | 必须收到「本轮修改点」，否则 `Incomplete` |
| 字段整个缺失 | 停机，要实现 skill 按 §4 重出——**缺失 ≠ `N/A`** |

### Step 1 — 材料不得落进主题仓库（前置门）

> 🔴 这是本 skill 唯一会把整件事搞砸的操作，所以放在最前面。

截图、配置文档、测试报告写进主题仓库工作树的**常规位置**时，`ChangeSetFingerprint` 会变化 → QA 的 Step 1 判 `ChangeSetIdMatched: No` 并停机。

> 🔴 **但"指纹会变"不是一道门，别指望它兜底**（v0.2.2 第十轮实测更正：此前这里写的是"提测方会因为交了材料而过不了自己的准入门"，实测**两条路完全不成立**）：
> - 材料放进**任何被 gitignore 的非发布目录**（如 `qa-artifacts/`）→ 指纹不变、`git status` 也看不见，intake 与 QA 双双看到一个干净的绑定。§2 的 `IGNORED_PUBLISHABLE_FILE` 门只扫八个可发布目录，兜不住。
> - 材料是 `memory/` 下的 **`.md`** → 指纹排除 `memory/`、本 skill 的校验命令也排除它，而 §2 那条盲区自检只找**非 `.md`** 文件 —— 三层全部看不见。
>
> 所以这道门必须**自己查**，下面三条命令缺一不可，不能只跑第一条。

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
git log --name-only --pretty=format: "<BaseHeadSha>..HEAD" -- . ':(exclude)memory/' | sed '/^$/d' | LC_ALL=C sort -u

# 在主题仓库根目录跑。下面三条都要跑：
# (1) 常规位置：工作树是否与 Implement 交付时一致
# 🔴 必须排除 memory/：它不属于 ChangeSet，也已排除在 §2 指纹与 QA 集合比对之外。
#    不排除的话，Path C 合法的 memory/模块清单.md 更新会被当成"材料落仓"，正常流程被假阻断。
git status --porcelain=v1 --untracked-files=all -- . ':(exclude)memory/'

# (2) 🔴 被 gitignore 的位置（指纹与 git status 都看不见的盲区）
git ls-files --others --ignored --exclude-standard -- . ':(exclude)memory/'

# (3) 🔴 memory/ 下的一切（指纹排除它，§2 盲区自检只找非 .md）
git status --porcelain=v1 --untracked-files=all -- memory/
find memory -type f 2>/dev/null | LC_ALL=C sort
```

以上**任何一条**（含站位检查、材料根边界、已提交清单）列出本次提测的六项材料（截图 / 配置文档 / 测试报告 / 影响范围说明 / 返工修改点）→ **停机**，要求把材料移到仓库外的独立目录或云文档，然后重新走 Implement 的指纹生成。(2)(3) 命中的尤其要停：那两处**指纹绑不住**，材料事后被换掉没有任何机制会发现。

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

命令见 handoff-schema §9.1.2。它绑的是**材料本身**（各文件 hash + 预览 URL 原文），与主题仓库的 `ChangeSetFingerprint` 是两条独立的链。

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

🔴 **不存在"免提测包但仍进 QA"的情形**（v0.2.2 第八轮更正）。此前这里写「零改动只读任务免提测包，QA 填 `SubmissionId: N/A` + `QAAdmissionStatus: Accepted`」——那条路第七轮已随 `ZeroChangeReadOnly` 一并废止：零改动任务**根本不进本 skill、也不进 QA**（handoff-schema §2 / §5 准入门第 3 条），它由实现 skill 出 §4 工件 + `ReadOnlyProof`，`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)` 收尾。给一个没有 ChangeSet 的只读审计发 `Accepted`，等于发一张没有验证含义的通过记录。

用户说"这次不走提测流程"时，QA 的 `QAAdmissionStatus` 仍为 `Blocked`（按 handoff-schema §1.5 的弃检口径处理，`ReadyForDelivery` 恒为 `No`）——用户可以决定不交材料，但不会因此拿到一张"准入通过"的记录。

「改动很小」也不是理由——那是 `ReconMode: InlineLite` 的判据，与提测材料无关。

> 🔴 **提测的 8 张截图不能替代 QA 自己的断点回归。** 前者是给运营/PM 看的交付材料，后者是 QA 实跑的验证（Path C 为 `PC / 1599 / 1279 / 767 / 375`）。两者互不顶替，都要有。记 `PC` 时写出实际像素宽度（如 `PC(1920)`），光写 `PC` 无法复核。

---

## 输出

回复的最后必须是 handoff-schema §9.1.2 的 ` ```yaml ` 契约块，字段不得增删改名。

再说一遍：**这个块里不出现 `ReadyForDelivery`。**
