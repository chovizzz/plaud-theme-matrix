# 提测包六项材料 —— 逐项验收标准

**何时读我**：判定某份材料算不算 `Complete` 时。测试用例的格式细则另见 `test-case-format.md`。

来源：《DTC 开发交付标准 v1.0》§四「交付物要求」。原文口径是「**提测时必须同时提供，缺一不进验收**」。

> 判定原则：**逐条可查**。判 `Incomplete` 时必须指出缺的是哪一项的哪个字段，不写"材料不全"。

---

## 1. 预览链接（`PreviewManifest` 内容 / `PreviewManifestStatus` 判定）

| 项 | 要求 |
|---|---|
| 数量 | **两条**：后台链接 + 前端链接。只给一条判 `Incomplete` |
| 后台链接 | 必须**可配置**——打开能看到该 section 的 schema 字段并能改。只能看不能改的只读预览不算 |
| 前端链接 | 必须**可访问**——实际打开过，不是"理论上应该能开" |
| 实测记录 | 记下检查时间。DTC 原文：**失效链接视同未提测** |
| 定位精度 | 链接要落到具体主题 + 具体页面，不是店铺首页让人自己找 |

记录形态：

```
后台：https://admin.shopify.com/store/<store>/themes/<themeId>/editor?template=<t>  ✅ 2026-08-12 14:30 可访问、可配置
前端：https://<store>.myshopify.com/?preview_theme_id=<themeId>                     ✅ 2026-08-12 14:31 可访问
```

**多站点提测**：`TargetSites` 里的每个站点都要有自己的一对链接，不能用一个站点的链接代表全部。

---

## 2. 配置文档（`ConfigurationGuideStatus`）

**触发条件**：本次新增了 section 或新增了配置项。两者都没有才可填 `NotApplicable`（并写明理由）。

必须包含四件事，缺一判 `Incomplete`：

| 内容 | 说明 | 反例 |
|---|---|---|
| 字段说明 | 每个 schema 字段是干什么的 | 只列字段名 |
| 默认值 | 每个字段的默认值是什么 | "默认就行" |
| 使用场景 | 什么情况下该改它 | 缺失 |
| **填错怎么办** | 填了非法值 / 留空会发生什么 | 缺失（最常漏的一项） |

**关键部分必须有截图**——DTC 原文要求。纯文字的配置文档判 `Incomplete`。「关键部分」指：后台该 section 的配置面板全貌、以及任何需要按特定格式填写的字段。

> 与 QA-B 的「空配置 / 满配置双测」呼应：配置文档里写的"留空会怎样"，QA 会实际去测。两边说法不一致时以 QA 实测为准，并退回补文档。

---

## 3. 测试文档（`SelfTestReportStatus`）

格式细则见 **`test-case-format.md`**。此处只记判定线：

| 判定 | 条件 |
|---|---|
| `Complete` | ① 每条用例四段齐全（前置条件 / 操作步骤 / 预期结果 / 结论）**且**有附件截图或视频；② **`TestSetTrace` + `PreviousAcceptedTestSetTrace` 齐全**（见 §3）；③ 换了测试文档时**另有合法的 `TestSetMigrationRef`**（见 §3.1） |
| `Incomplete` | 任一条用例的预期结果写成"显示正常""功能可用""无异常"——DTC 原文：**这类用例视同未测** |
| `Incomplete` | 有用例但无截图/视频附件 |
| `Incomplete` | 只有结论没有步骤（"测过了，没问题"） |

**不接受 `NotApplicable`**：任何改动都有可测面。真的无从测起时说明本身就是问题，停机问清楚。

### 测试集溯源：一行 `TestSetTrace`（DTC §一 第 3 条）

DTC 要求 agency **维护测试集并随交付更新，不是一次性文档**。v0.2.0 为此要求三项分别手写；**设计方评审指出「测试做太多重复性工作很影响效率」**，v0.2.1 据此收敛为一行；v0.2.2 又补了两处（三类分列、与上一轮比对），因为只有本轮一行仍证明不了"跨交付的增量维护"。

语法：

```yaml
TestSetTrace: <稳定文档ID>@<不可变revision>; Added=[TC-…]; Updated=[TC-…]; Removed=[TC-…]
# 本轮无增删时：
TestSetTrace: <稳定文档ID>@<不可变revision>; None(<reason>)
PreviousAcceptedTestSetTrace: <上一轮已通过准入的同一行原文> | None(FirstSubmission) | Unavailable(<原因>)
# 换了一份新测试文档时必填（语法见 §3.1）：
TestSetMigrationRef: From=…; To=…; Reason=…; ReasonRef=…; CaseDisposition=… | N/A(SameDocument) | N/A(NoPreviousTrace)
```

| 组成 | 取值 | 说明 |
|---|---|---|
| `<稳定文档ID>` | 测试集的**长期**文档 ID（不是本次临时文档的链接） | 只有它能证明是同一份长期资产 |
| `@<不可变revision>` | 版本号 / revision / 快照时间 | 🔴 **不可省略**。URL 可以被覆盖内容，不带 revision 就无法区分"增量维护"与"每次现编"。**若平台 URL 本身已含不可变 revision，两段合并成一个字段即可** |
| `Added=[…]` / `Updated=[…]` | 本轮新增 / 修改的用例 ID，**三类分列**（v0.2.1 写成 `Added/Updated/Removed=[…]` 一个列表，无法表达某个 ID 属于哪类，已废） | 这两类**不要另写清单**：测试报告里每条用例自带 `Added` / `Updated` / `Unchanged` 标记时，直接由标记汇总 |
| `Removed=[…]` | 本轮从测试集**删除**的用例 ID | ⚠️ **必须显式列，推不出来**：被删的用例已不在本轮报告里，`Added/Updated/Unchanged` 标记覆盖不到它。无删除时写 `Removed=[]` |
| `None(<reason>)` | 本轮确实没有增删时的合法取值（替代上面三段） | 必须给理由（如 `None(纯样式改动，复用 TC-042/TC-043)`）。**空着不算** |
| `PreviousAcceptedTestSetTrace` | 上一轮通过准入时那一行的**原文** | 🔴 **这是"长期增量维护"唯一能被查证的地方**（v0.2.2 补）。只比 ID 与 revision，**不复制测试集内容** |
| `TestSetMigrationRef` | 换了一份新测试文档时的**结构化**迁移声明；未换填 `N/A(SameDocument)` | 🔴 **v0.2.2 起自由文本理由不再成立**——文档 ID 一变链就断，而"正常换库"与"重新现编一份"在自由文本里长得一样。完整语法与判定见 **§3.1** |

| 判定 | 条件 |
|---|---|
| `Complete` | `TestSetTrace` 齐全（含 revision；三段分列或 `None(reason)`）**且** `PreviousAcceptedTestSetTrace` 的稳定文档 ID 与本轮一致、revision 不同（= 同一份资产往前推进了一版）；**或**文档 ID 不同但附了合法的 **`TestSetMigrationRef`**（见 §3.1） |
| `Incomplete` | 缺 revision（只给链接）；delta 段留空；`Removed` 段缺失；文档 ID 指向本次临时文档 |
| `Incomplete` | **文档 ID 与上一轮不同**，而 `TestSetMigrationRef` 缺失 / 取 `N/A(SameDocument)` / 不合法 —— 这正是「每轮新建一份文档并称其为稳定 ID」的绕过形态（v0.2.2 起**自由文本理由不再成立**，必须是 §3.1 的结构化形态） |
| `Incomplete` | revision 与上一轮**完全相同**却声明了 `Added` / `Updated` / `Removed` —— 自相矛盾（测试集没变却说改了用例） |
| 首次提测 | `PreviousAcceptedTestSetTrace: None(FirstSubmission)` 合法，但**只有第一次**，且**必须配 `TestSetMigrationRef: N/A(NoPreviousTrace)`** |

**上一轮那一行从哪里来（v0.2.2 明确取数路径，避免这条控制写了却不可执行）：**

| 优先级 | 来源 | 说明 |
|---|---|---|
| ① | 项目侧 `memory/changeset-log.md` 里**最近一条 `TestSetTrace` 非 `N/A` 的行** | v0.2.2 起该列由 `plaud-theme-qa` 在本轮 **`QAAdmissionStatus: Accepted`** 时写入（与 `ReadyForDelivery` 无关，所以 QA 失败的返工轮也有值；列定义见 `plaud-theme-shared/references/handoff-schema.md` §9.2「`memory/` 记录字段」）。这是**首选**权威来源；它不可得时才走②，**②不是「可选的偷懒路径」，是日志确实读不到时的唯一替代** |
| ② | 用户直接给的**一对**工件：上一轮的 `QAIntake` 工件原文 **+** 同一 `SubmissionId` / `ChangeSetId` 的那一轮 **QA §5 工件**，且后者 `QAAdmissionStatus: Accepted` | ①不可得时用。🔴 **必须成对**：`QAAdmissionStatus` 是 QA 工件的字段，**`QAIntake` 工件里根本没有它**——只给一份 `QAIntake` 无法证明「已通过准入」，那样谁都能拿一份自己写的草稿冒充上一轮。两份对不上 `SubmissionId` / `ChangeSetId`，或 QA 工件不是 `Accepted` → 当作①②都不可得，走③ |
| ③ | 都拿不到 | 🔴 **不判 `Incomplete`，也不假装查过**：本轮 `PreviousAcceptedTestSetTrace` 填 `Unavailable(<原因>)`，`SelfTestReportStatus` 按其余条件判定，并在 QA 的 `Advisories` 记「测试集跨轮次连续性本轮无法核验」。**这是过渡条款**：`changeset-log.md` 在 v0.2.2 之前没有 `TestSetTrace` 列，早期项目必然命中③；一旦该列有值就不再适用 |

> ⚠️ **`Unavailable(...)` 的成立条件（v0.2.2 收紧措辞）**：**在 `changeset-log.md` 里找不到任何一条 `TestSetTrace` 非 `N/A` 的历史行，且用户也给不出上一轮已通过准入的工件**。
> 这包含三种真实情形：① 日志根本没有这一列（v0.2.2 之前的旧日志）；② 有这一列但历史行全是 `N/A(NotAccepted)` / `N/A(NoTestSet)`（例如前几轮都卡在准入）；③ 日志文件本身缺失。
> **不成立**的情形：日志里明明有可用的历史 trace 却填 `Unavailable` = 契约违规。
>
> 🔴 **`None(FirstSubmission)` 与 `Unavailable(...)` 的分界（否则「首次」变成一个谁都能自称的状态）**：「首次」的事实源同样是 `changeset-log.md` —— **日志读到了、且其中没有任何一条非 `N/A` 的 `TestSetTrace` 行** → `None(FirstSubmission)`；**日志读不到 / 没有这一列 / 有列但历史行全是 `N/A`** → `Unavailable(<原因>)`。区别就在「读到了但确实是空的」与「根本读不到」。两者都必须配 `TestSetMigrationRef: N/A(NoPreviousTrace)`；日志里明明有可用历史行却填 `None(FirstSubmission)`，与填 `Unavailable` 同样是契约违规。
> 填了 `Unavailable` 就必须在 QA 的 `Advisories` 记「测试集跨轮次连续性本轮无法核验」+ 写明属于上面哪一种。

> ⚠️ **矩阵不拥有测试集本身**（与 `memory/` 同类，项目侧长期资产，不随包分发）。这里只查"有没有挂在测试集上、这一版是哪一版、这轮动了哪几条"，**不查测试集内容**。
> Aily 的审查是**外部人工流程**，矩阵不代替：尚未双方固化时记 QA 的 `Advisories`，**不进 `BlockingGaps`**（那是停机项），也**不因此判 `Incomplete`**。

### 3.1 换了一份新测试文档：结构化 `TestSetMigrationRef`（v0.2.2 补）

**要解决的是什么**：`PreviousAcceptedTestSetTrace` 靠「同一个稳定文档 ID」把两轮串起来，**文档 ID 一变链就断**。v0.2.1/v0.2.2 只要求"说明迁移原因"，而自由文本里「我们换到 Linear 了」和「上一轮那份找不到了，我重新整理了一份」长得一模一样——**正常换库**与**重新现编一份来掩盖没做增量维护**因此不可区分。这一节把它改成结构化、可机械比对的一行。

语法（**唯一事实源在此**；`handoff-schema.md` §9.1.2 / §9.2 只登记字段与取值，不复制语法）：

```yaml
TestSetMigrationRef: From=<旧稳定文档ID>@<旧revision>; To=<新稳定文档ID>@<新revision>; Reason=<封闭枚举>; ReasonRef=<locator>; CaseDisposition=Mapped(<locator>) | BulkRetired(<locator>)
# 🔴 算 PackageFingerprint 前必须 cd 到材料根并 export PLAUD_PACKAGE_ROOT=$(pwd -P)（v0.2.2 第十轮）：
#    否则在子目录跑会静默算出子集指纹且 rc=0，两边同样错就 Accepted 照发、材料根本没被绑住。
# <locator> 只有两种合法形态，指向的对象必须在提测材料里（因而进 PackageFingerprint）：
#   Local(<相对提测材料根的路径>)     —— 本地文件，如 Local(testset/migration-map.tsv)
#   Manifest(<materials.tsv 条目名>)  —— 云端材料，须带不可变 revision / digest（§9.1.2 既有规则）
# 🔴 适用范围不同，不可互换：
#   ReasonRef        两种都可以（只核存在性 + 内容绑定）
#   CaseDisposition  **只能 Local(...)** —— 清单要核条数 / 重复 ID / 空理由，而云端材料按 §9.1.2
#                    只重取 revision / digest、取不到内容，写 Manifest(...) 就是写了一条查不了的规则
# 未换文档：
TestSetMigrationRef: N/A(SameDocument)
# 本轮没有可比对的上一轮（PreviousAcceptedTestSetTrace 为 None(FirstSubmission) 或 Unavailable(...)）：
TestSetMigrationRef: N/A(NoPreviousTrace)
```

**五段的取值与判定**（`From` / `To` / `Reason` / `ReasonRef` / `CaseDisposition`，**缺一即 `Incomplete`**）：

| 段 | 取值 | 判定（不满足即 `SelfTestReportStatus: Incomplete`） |
|---|---|---|
| `From` | `<旧稳定文档ID>@<旧revision>` | 🔴 **必须与本轮 `PreviousAcceptedTestSetTrace` 的 `ID@revision` 逐字一致**。它的事实源就是矩阵自己已有的那一行，**不引入任何需要另外去查的新事实源**。🔴 **比的是那一行的 `ID@revision` 前缀段，不是整行**——日志列里存的是 `ID@revision; Added=[…]; …` 的完整原文，取第一个 `;` 之前那段做逐字比对。**按来源分支**：走取数路径① 时，`From` 还要等于 `memory/changeset-log.md` 里最近一条 `TestSetTrace` 非 `N/A` 行的同一前缀段；走路径②（日志不可得、用成对工件）时**只与那对工件里的 `QAIntake.TestSetTrace` 比**，不得再去要求日志——路径②的前提就是日志不可用，再卡日志等于把合法输入锁死；走路径③ 时本字段应为 `N/A(NoPreviousTrace)`。对不上 = 迁移声明与历史记录矛盾 |
| `To` | `<新稳定文档ID>@<新revision>` | 🔴 **必须与本轮 `TestSetTrace` 的 `ID@revision` 逐字一致**。对不上 = 声明迁到 A、实际交的是 B |
| `Reason` | **封闭枚举，三值**：`PlatformMigration`（换承载平台/工具，如飞书文档 → Linear 文档）\| `OwnerHandover`（agency 或测试负责人交接，旧文档不再由本方维护）\| `Deprecated`（旧文档被平台下线 / 永久不可访问 / 被判作废） | 不在枚举内**不得自造、不得硬套**：判 `Incomplete`，`BlockingGaps` 写 `TestSetMigrationReasonOutsideClosedEnum: <一句话实情>`，由 maintainer 决定下一版是否扩枚举（枚举增删同样要发版，见 `version-manifest.md` §1.1）。**刻意不提供 `Other(...)` 兜底**——兜底会立刻变成默认选项，这一行就退回自由文本 |
| `ReasonRef` | 该迁移决定的**书面出处**（迁移说明 / 工单 / 纪要导出件）的 `<locator>` | 只核**两件事**：① locator 指向的对象**确实在提测材料里**（`Local(...)` 的文件存在、`Manifest(...)` 的条目存在且带不可变 revision / digest）；② 因此它已被 `PackageFingerprint` 绑定、事后不可替换。**悬空引用**（文件/条目不存在）、**无版本外链**、**整段缺失** → `Incomplete`。🔴 **矩阵不核它的内容真伪**（写得对不对、批没批），那是 agency 与测试同学之间的事 |
| `CaseDisposition` | `Mapped(<locator>)`（旧用例**逐条**映射到新用例或显式弃用）\| `BulkRetired(<locator>)`（旧用例**整体废弃**） | 两种形态都**必须**指向一份进了提测材料的清单文件，见下 |

**`CaseDisposition` 指向的那份清单**（这是本节唯一新增的材料要求）：

🔴 **这份清单只能用 `Local(...)`**：`Manifest(...)`（云端）指向的材料，矩阵按 §9.1.2 只重新取 **revision / digest**、**取不到内容**，条数 / 重复 ID / 空理由这些核对根本做不了——允许它就等于写了一条查不了的规则。清单放云端时先下载一份进材料目录再用 `Local(...)` 指。

它是**提测材料目录里的一个普通文件**（如 `testset/migration-map.tsv`），用 `Local(<相对路径>)` 指向，因此**自动进 `PackageFingerprint`**——走的是 §9.1.2 已有的材料绑定机制，不是一条新的外部查询链路。清单原本在云端时**先下载一份进材料目录**再用 `Local(...)` 指；直接写 `Manifest(...)` 一律 `Incomplete`（`Manifest(...)` 只适用于 `ReasonRef`）。两种 locator 之外的写法（裸 URL、只写个文件名而材料里找不到）一律视为**悬空引用** → `Incomplete`。🔴 `Local(...)` 的路径**必须解析后仍落在提测材料根之内**：含 `../`、绝对路径、或经 symlink 跑出根的一律 `Incomplete` —— 包指纹只 hash 材料根下的普通文件（symlink 本来就 fail closed），跑出根的对象**根本不进指纹**，「locator 可读」与「内容被绑定」是两回事，只查前者等于绑定承诺不成立。

| 形态 | 清单内容 | 自洽性核对（intake 与 QA 都做） |
|---|---|---|
| `Mapped` | **头部一行** `OldCaseCount=<N>`；其后每行一条：`<TC-old>\t<TC-new>` 或 `<TC-old>\tDropped\t<理由>` | 数据行条数必须 = `OldCaseCount`；旧用例 ID **不得重复出现**；`Dropped` 行必须有非空理由 |
| `BulkRetired` | **头部两行** `OldCaseCount=<N>` 与 `RetireReason=<一句话>`；其后逐条列出被废弃的旧用例 ID，一行一个 | 数据行条数必须 = `OldCaseCount`；旧 ID 不得重复；`RetireReason` 非空。🔴 **"旧文档已经打不开了所以列不出来"不是免除理由**——换库前本方本来就持有这份资产；列不出来就判 `Incomplete`，不给 `Unavailable` 之类的降级取值（这里不存在"矩阵去查外部系统失败"这回事） |

> **分工**：`plaud-theme-qa-intake` 做**全量**判定（五段齐不齐、locator 是否悬空、清单条数 / 重复 ID / 空 `Dropped` 理由）；`plaud-theme-qa` 在 Step 0 重算 `PackageFingerprint` 时**复核**同样几项（它本来就要进材料目录，不额外增加取数动作），发现 intake 判错按 `QAAdmissionReason: PackageIncomplete` 退回。
>
> 🔴 **矩阵能保证的到此为止，多的不要声称。** 核的是**自洽性 + 内容绑定**：清单在材料里、进了指纹（事后不可替换）、条数与声明一致、旧 ID 不重复。它**不核真实性**——`TC-1042` 在旧文档里是否真的存在、`Dropped` 的理由是否属实，矩阵**查不到也不查**（`矩阵不拥有测试集本身`，见上）。举证责任在 agency；这一行的价值是**把说法固定下来、事后可追**，不是替测试同学做审查（Aily 的人工审查仍在矩阵之外）。

**本版明确不支持的迁移形状**（诚实的能力边界，不要硬套）：

- **一拆多**（一份旧测试集拆成多份新文档）与**多合一**（多份旧文档合并成一份）：`From` / `To` 都是单值，而 `PreviousAcceptedTestSetTrace` 本身只有"最近一条"、不是旧文档集合，**表达不了**。遇到这种情形**停机**，`BlockingGaps` 写 `TestSetMigrationShapeUnsupported: <实情>`，**不得**挑一份旧文档冒充成一对一。留待后续版本。

**降级取值一览**（每一种都必须有诚实落点）：

| 情形 | `TestSetMigrationRef` | `SelfTestReportStatus` |
|---|---|---|
| 文档 ID 与上一轮相同 | `N/A(SameDocument)` | 按 §3 主表判 |
| `PreviousAcceptedTestSetTrace` 为 `None(FirstSubmission)` 或 `Unavailable(<原因>)` | `N/A(NoPreviousTrace)` | 不因本字段判 `Incomplete`；QA 记 `Advisories`「本轮无可比对的上一轮，迁移无从核验」（与取数路径③同口径） |
| ID 变了、`TestSetMigrationRef` 缺失或写成自由文本 | —— | `Incomplete` |
| ID 变了、填了 `N/A(SameDocument)` | —— | `Incomplete`（自相矛盾） |
| ID 没变、却填了完整迁移声明 | —— | `Incomplete`（自相矛盾） |
| `PreviousAcceptedTestSetTrace` 是**具体一行**，却填 `N/A(NoPreviousTrace)` | —— | `Incomplete`（自相矛盾；**intake 就要判**，不要留给 QA 的 Step 0 (4e) 兜底） |
| `PreviousAcceptedTestSetTrace` 为 `None(FirstSubmission)` / `Unavailable(...)`，却提交了**完整迁移声明** | —— | `Incomplete`（没有 `From` 可比，声明无从核验） |
| `From` / `To` 与两行 trace 对不上 | —— | `Incomplete`；已进到 QA 才发现的走 `QAAdmissionReason: BindingMismatch`（见 `plaud-theme-qa/SKILL.md` Step 0） |

---

## 4. 断点截图（`ScreenshotManifestStatus`）

**8 张，一张不能少**：

| 类型 | 宽度 |
|---|---|
| 标准档 | `375` / `768` / `1024` / `1280` / `1440` |
| **边界值** | `767` / `1279` / `1599` |

边界值是重点——`767` / `1279` / `1599` 正对着矩阵的三个 `.98` 判定断点（`responsive-and-spacing.md` §1），是布局最容易在整边界上错位的位置。少了边界截图判 `Incomplete`，不能用"标准档看着没问题"顶替。

**每张截图要能认出是哪个断点**：文件名带宽度，或截图里带浏览器宽度指示。一堆没标注的图判 `Incomplete`。

> ⚠️ 这 8 张是**交付材料**，不是 QA 的回归证据。QA 自己还要跑 `PC / 1599 / 1279 / 767 / 375`（Path C），两套并存。

---

## 5. 影响范围说明（`ImpactScopeStatus`）

两个维度，缺一不可：

| 维度 | 来源 | 内容 |
|---|---|---|
| 模板 / 实例 | **引用 `AssessmentRef`**，不自行重算 | 本模块被几个模板使用、`ActiveInstances` / `DisabledInstances` / `ActualAffectedInstances` |
| 站点 | 本 skill 的 `TargetSites` / `ExcludedSites` / `ThemeIds` | 涉及哪些站点、排除了谁、各自主题 ID |

> 🔴 **不得在这里重新算一遍影响面。** 那是 `plaud-theme-impact` 的职责，重算会产生第二个事实源。本 skill 只做两件事：确认 `AssessmentRef` 存在且对应本次 ChangeSet，以及补上它不覆盖的站点维度。
>
> 没有 `AssessmentRef`（`ReconMode: InlineLite` 的任务）→ 引用实现工件里的 `InlineLite` 豁免理由，仍要有站点维度。

---

## 6. 返工修改点（`ReworkDeltaStatus`）

**只在返工轮次要求**。首轮提测填 `NotApplicable` + 一句"首轮提测"。

返工轮次必须给「本轮修改点」清单，逐条三段：

```
反馈原文 → 改了什么 → 落在哪个文件（含行号或函数名）
```

判 `Incomplete` 的情形：

- 只写"按反馈修改了"，没有逐条对应
- 有改动但清单里没列（清单条目数与 `ModifiedFiles` 明显对不上）
- 把**需求变更**混进返工清单——变更不计返工轮次，归属由 `plaud-theme-feedback-triage` 判，本 skill 发现混装时记进 `BlockingGaps`

---

## 汇总判定

**下表是单块提测包的判定。集成提测包（`ChangeSetId: N/A(Integration)`）**在此之上**还要满足 §7 的全部追加条件，六项全绿也不够 —— 见 §7.3 / §7.4 / §7.5 / §7.6。**

| `SubmissionPackageStatus` | 条件 |
|---|---|
| `Complete` | **六项 Status** 全为 `Complete`（`ConfigurationGuideStatus` / `ReworkDeltaStatus` 可为 `NotApplicable` + 理由），且 `PreviewManifestStatus: Complete`（两条链接实测可访问）**；集成包另须 §7 全部条件成立** |
| `Incomplete` | 其余任何情况 |

**没有中间态**。「大部分齐了」「就差截图」一律 `Incomplete` —— DTC 的原文是「缺一不进验收」。

---

## 7. 集成提测包的 `IntegrationOf`（v0.3.0 新增，R-BLOCK-1）

集成 QA（`QAScope: Integration`）**结构上取不到任何一块的提测包**——每块的包绑的是那一块的树。裁决是由本 skill 出一份**集成提测包**：`ChangeSetId: N/A(Integration)`、`ChangeSetScopeFingerprint: N/A(Integration)`、`IntegrationOf` 非空，材料 = **各块材料的并集 + 集成本身的 ReworkDelta**。

### 7.1 语法

```
IntegrationOf:
  - ChangeSetId: CS-20260812-A02
    SubmissionId: SUB-20260813-04
  - ChangeSetId: CS-20260812-B01
    SubmissionId: SUB-20260813-05
```

- 逐块一条，**每条两段齐**（`ChangeSetId` + `SubmissionId`），缺段即 `Incomplete`。
- 顶层 `SubmissionId` 是**新开的**集成包 ID，🔴 **不得复用任何成员的 `SubmissionId`**。

### 7.2 每一段的取数路径与降级取值

🔴 **这一节存在的理由**：本 skill 历史上最贵的一族缺陷是「写了一条控制，但它依赖的数据根本取不到」（`PreviousAcceptedTestSetTrace` 曾写成「从 `changeset-log` 取」，而那个文件没有承载它的列）。所以每一段都必须回答三问：**谁写的？schema 放得下吗？取不到时填什么？**

| 段 | 唯一事实源（谁写的 / 放得下吗） | 取不到时填什么 |
|---|---|---|
| 成员 `ChangeSetId` 全集 | §9.1 Coordination 工件的 `IntegrationPlan.MemberChangeSets`，producer = `plaud-theme-orchestrator`，schema 明确承载 | **没有 `IntegrationPlan`** → 停机回 orchestrator。**没有降级值**：本 skill 不自行拟定成员清单 |
| 每块的 `SubmissionId` | ① §9.1 Coordination 工件的 `ChangeSetStatus`（canonical 原文「含 `SubmissionId`（提测准入）」）；② 用户直接给出该块那份 `QAIntake` 工件原文——它才是 `SubmissionPackageStatus` 的一手承载者 | **分两种情形**（见 §7.3）：ID 拿得到但那份包不是 `Complete` → 照写真实 ID + 整包 `Incomplete`；该块**根本没有提测包** → **停机不出契约块**，🔴 不得自造占位取值 |

🔴 **`memory/changeset-log.md` 不是 `SubmissionId` 的取数路径。** 它的列定义（handoff-schema §9.2「`memory/` 记录字段」+ `plaud-theme-qa/references/evidence-and-invalidation.md` 的表头）里**没有 `SubmissionId` 这一列**——写「从 changeset-log 取」就是又写了一条查不了的规则。

🔴 **该块的单块 QA §5 工件里的 `SubmissionId` 只是派生指针**，可以用来**定位**那份包，但**不能单独用来证明**「包仍然存在且 `Complete`」——仍要回查那份 `QAIntake` 工件本身。

### 7.3 成员包不齐时怎么办（两种情形，处置不同）

canonical 要求每项「真实存在**且** `SubmissionPackageStatus: Complete`」，两个条件缺一不可。**但这两个条件失败的方式不一样，必须分开处置**——混成一条就会逼出一个契约里根本没有的取值：

| 情形 | 处置 |
|---|---|
| **A. `SubmissionId` 已知，但那份包不是 `Complete`** | **出工件**：`IntegrationOf` 里照写**那个真实的 `SubmissionId`**（它确实存在，不许改写成别的东西）；顶层 `SubmissionPackageStatus: Incomplete`；`BlockingGaps` 指名「哪一块的包缺哪一项 Status」；下游集成 QA 填 `QAAdmissionStatus: Blocked` + `QAAdmissionReason: PackageIncomplete`。**完全可序列化，这就是 R-BLOCK-1 说的降级** |
| **B. 该块根本没有提测包**（`ChangeSetStatus` 与用户手上都拿不到该块的 `SubmissionId`） | **停机，不出契约块**。26 key 契约要求 `IntegrationOf` 每项都有 `SubmissionId`，而这个值**不存在**。`BlockingGaps` 写进正文，指名是哪一块从未提测，要它**先补一次单块提测**拿到真 ID 与 `Complete` 的包 |

🔴 **情形 B 不得自造占位取值。** `Unavailable(...)` / `N/A` / `TBD` 一概不行：canonical §9.1.2 与 §9.2 都**没有**为这个位置定义"取不到"的取值，自造一个就是给封闭契约开口子，而且它必然被下游当成一个"我处理过了"的信号。本 skill 既有的同族做法正是停机：拿不到 `ChangeSetId` 停机不编，`PACKAGE_FINGERPRINT_FAILED` 停机不用占位符。

🔴 **两种情形都不许把那一块从 `IntegrationOf` 里删掉**（A 里它必须在场，B 里压根不出块）。删掉之后集合等式变成与一份被裁剪过的成员清单比，那一块的材料**整份缺席而 intake 照样 `Complete`**——正是 canonical 点名要堵的洞。

**怎么核"那份包确实存在且 `Complete`"**：拿到一个 ID 不算数。顺着 `ChangeSetStatus` 里该块的 handoff 引用、或用户提供的该块 `QAIntake` 工件原文，逐项核 `ChangeSetId` / `SubmissionId` / `SubmissionPackageStatus` 三者自洽。**原工件读不到 → 顶层 `Incomplete` + `BlockingGaps` 指名**；🔴 **"读不到"不得当成"核过了"**。

> 📌 **上报给 shared 的缺口**：R-BLOCK-1 写的是「任一块 `SubmissionId` 缺失 → `SubmissionPackageStatus: Incomplete`」，但 §9.1.2 / §9.2 没有为**嵌套项**定义缺失时的合法表达，因此"缺失"这一格在本版只能落成停机（情形 B）。要让它也能出 `Incomplete` 工件，需要 shared 先定义该 nested 字段的合法 blocked 取值。**本 skill 不自行定义。**

### 7.4 集合等式与三条结构门

| 门 | 判据 | 不满足 |
|---|---|---|
| 集合相等 | `IntegrationOf` 的 `ChangeSetId` 集合与 `IntegrationPlan.MemberChangeSets` **逐项相等** | 停机 |
| 本侧无重复 | `IntegrationOf` 里 `ChangeSetId` 不得重复 | 停机 |
| **计划侧无重复** | `IntegrationPlan.MemberChangeSets` **自身**不得有重复项。🔴 只核集合相等挡不住它：`MemberChangeSets: [A, A]` 与 `IntegrationOf: [A]` 的**集合**是相等的，等式照样成立，而那份集成计划本身已经是坏的 | 停机**回 orchestrator**（这是计划的错，不是提测包的错，本 skill 不替它去重） |
| `SubmissionId` 互异 | 两块不得引用同一个 `SubmissionId`——一个包绑的是一块的树，不可能同时是两块的材料；且都不得等于本集成包顶层的 `SubmissionId` | 停机 |

### 7.5 材料并集：真拷贝，不许 symlink

集成包的材料根必须**真的**含各块材料（截图 / 配置文档 / 自测报告 / 影响范围说明）+ 集成本身的 ReworkDelta。

🔴 **不得用 symlink 把各块材料"链"进集成材料根。** 说精确：`plaud_package_fingerprint` 对 symlink 是 fail closed —— 它**直接报 `UNSUPPORTED_MATERIAL_OBJECT` 并返回 1，一个指纹都算不出来**，不是"算出一个漏掉 symlink 内容的指纹"。所以后果不是"绑定弱"而是"整包出不了指纹 → 停机"。要并集就**真拷贝**。

**并集怎么核**：

1. 对 `IntegrationOf` 里**每一块**，用它的 `SubmissionId` 找回那份 `QAIntake` 工件，读它的 **`PackageRootRef`**（这是 26 key 里真实存在的字段）；
2. 从该 `PackageRootRef` **枚举**该块的材料（本地目录直接列；材料在云端时列它的 `materials.tsv`），再与集成材料根逐条对；
3. 任一块的 `QAIntake` 工件或它的 `PackageRootRef` **读不到** → `BlockingGaps` 指名是哪一块无法核对。🔴 **"读不到"不得当成"核过了"**，也不得当成"那块没有材料所以不用核"。

🔴 **这道门的强度取决于第 2 步能不能枚举，必须如实分档，不要混为一谈**：

| 情况 | 这道门是什么 |
|---|---|
| 该块 `PackageRootRef` 可达、材料可枚举 | **硬门**：少了某块的截图 / 自测报告 → 相应项 `Incomplete` |
| `PackageRootRef` 不可达（目录已删、云端无权限） | **降为 advisory**：记进 `BlockingGaps` 说明"该块材料并集未能核对"，**不得**据此判"并集没问题"，也不得据此单独判 `Complete` |

> 📌 **为什么只能做到这一步**：`QAIntake` 的 26 key 里**没有材料清单/inventory 字段**，`PackageFingerprint` 也**反推不出**文件清单（它是单向 hash）。所以"成员材料 → 集成材料"的逐条映射在本版没有受契约绑定的承载物。**已上报 shared**。

> **矩阵能保证的到此为止，多的不要声称。** 上面这套是**逐项人读核对**：它能发现"某块的材料整份没进来"，但不能机械证明"进来的那份就是该块当初提测的那份字节"——集成包只有**一个** `PackageRootRef` / `PackageFingerprint`，`IntegrationOf` 只承载 `ChangeSetId` + `SubmissionId`，**没有**逐成员的包根或包指纹。矩阵能机械证明的只有「集成材料根自准入以来没被替换」。**不要把它写成、也不要读成指纹级保证。**


### 7.6 集成包的 `ReworkDeltaStatus`

集成包**没有单一的 `OriginTriageRef`**，所以不走 §6 那张首轮/返工判据表。它判的是**集成本身的 ReworkDelta**：合并过程中为消解冲突所做的改动（token / locale 键 / schema 值的取舍）。

**事实源固定**（🔴 不能靠口述，否则这条又是一个"写了但不可执行"的控制）：由 `IntegrationPlan.Integrator`（人）交一份**冲突消解记录**，放进**集成材料根**因而进 `PackageFingerprint`；no-op 合并同样要交一份写明"本次集成未做任何冲突消解改动"的记录。

| 情况 | `ReworkDeltaStatus` |
|---|---|
| 有记录且逐条可对（改了什么 / 在哪个文件 / 为什么） | `Complete` |
| 记录里写明本次集成为 no-op 合并 | `NotApplicable` |
| **没有任何记录**（只有口头"没改什么"） | 🔴 `Incomplete` —— **不得凭口述填 `NotApplicable`**：那等于让集成过程中最容易出问题的一步不留痕 |

**各块自己的返工 delta 已经在各块的包里，不在这里重收。**
