# Changelog — PLAUD Shopify Theme Matrix

版本按**全量快照**发布：切新版本 = 整包复制到新目录再改，不做原地修改。

---

## v0.2.3 — 2026-08-14

**第十轮评审 + 首次端到端演练 + 三项"仍未做"收口。** v0.2.2 装到四端后又过了一轮独立评审（第五个评审），同时第一次把整条链路写成**可执行的演练**去跑——这一轮**指纹门与安装器各出一个真实可绕过点，都是演练/评审跑出来的，eval 一条都没抓到**（第十次重复这个模式）。

> **为什么切新版本**：v0.2.2 已发布并装到四端，本轮是契约与门禁的实质改动（新增必填环境变量、准入门从一条命令变三条、`TestSetMigrationRef` 新字段、工件 22→23 key）。原地改一个已发布快照，等于让同一棵 `memory/` 被两套 spec 处理——那正是本项目记录在案的客户端漂移事故。v0.2.2 目录与 zip 保持发布态冻结。

### 🔴 指纹门：两个真实可绕过点

- **被 gitignore 的 `.gitattributes` 完全绕过 clean-filter 门。** 门原来枚举四个来源，其中未跟踪那一路带 `--exclude-standard`，而它**按定义排除 ignored 文件** —— 可一个 `.gitattributes` 是否被 ignore，与它在 git 里生不生效**完全无关**（`.git/info/exclude` 是合法的本地配置）。实测：挂上 clean filter 后三次完全不同的工作树内容算出**同一个指纹**。Shopify push 推的是工作树字节，QA 重算一致就放行 —— 上线的 CSS 与 QA 认证过的不是同一份。已改为连 ignored 一起枚举。
- **`plaud_package_fingerprint` 没有根目录守卫 —— 整套门禁里唯一的 false acceptance。** §2 第七轮为此加了 `NOT_REPO_ROOT`，§9.1.2 一直没有配套：在材料树的子目录里跑，`find .` 只看得见该子目录，**静默算出子集指纹并返回 0**（metamorphic 已证是子集：改兄弟目录的自测报告，子目录指纹纹丝不动）。危险的不是失配 —— 是 intake 与 QA 用同一个错误的 `PackageRootRef` 时**两边算出同一个值、`Accepted` 照发**，而自测报告 / 配置说明 / 截图全部不在绑定链里。已新增**必填**环境变量 `PLAUD_PACKAGE_ROOT`（须等于工件的 `PackageRootRef`），cwd 不等即 `NOT_PACKAGE_ROOT`、未设即 `NO_PACKAGE_ROOT`，两处调用方（qa-intake Step 4、QA Step 0）同步接线。

### 🔴 安装器：「完全替换」这个保证一直是静默失效的

- **`rm -rf "$dest"` 的退出码从不判**，而安装后唯一校验是 `[[ -f "$dest/SKILL.md" ]]` —— SKILL.md 必然存在，**包括它是上个版本残留的那一份**。实测（chmod 500 父目录使删除失败）：脚本打印 "Overwriting…" 与 "Installed…"、**exit 0**，而陈旧 reference 原样存活。这正是本项目文档点名的灾难模式：被新版删掉的 reference 留在客户端继续被路由。根因链还有一层：`install_one_skill … && ok=$((ok+1)) || true` 这个条件上下文让**函数体内的 errexit 被忽略**，所以裸 `rm -rf` 与随后失败的 `tar` 都继续执行。
- **修法**：`rm -rf` 判退出码 + 删除后复查残留 + `mkdir` / `tar` 各自判 + **安装后逐文件清单比对**（源与目标的文件清单必须完全相等，多出来的即陈旧残留，直接列出）。
- **顺带修掉一个被这次检查暴露的既有假失败**：`tar -cf - . | tar -xf -` 在 stock macOS bsdtar 上**必然假报失败** —— 接收端读到归档结束标记先退出，发送端写填充块时吃 EPIPE。原脚本从不判这条管道的退出码所以隐形；一加检查，正常安装全变 exit 1。改走临时归档文件，两端退出码才诚实。（这也解释了为什么注入失败 `tar` 能被发现、而真实的单端 tar 失败一直发现不了。）

### 🔴 两处「声明与行为不符」

- **"提测材料落进工作树 → 你过不了自己的准入门"是错的。** 材料放进**任何被 gitignore 的非发布目录**、或放进 `memory/` 且是 **`.md`**，指纹与 `git status` 都看不见（§2 排除 `memory/`、qa-intake 的校验命令也排除、而 §2 那条盲区自检只找**非 `.md`**），intake 与 QA 会双双看到一个干净的绑定。把一个副作用当成了强制机制。**真正的门**现在是 qa-intake Step 1 的**三条命令**（常规位置 / ignored 位置 / `memory/` 全量），canonical 同一处声明同步改写。
- **"指纹覆盖权限"是过度声明**：tracked 文件 git 只记 executable 一个 bit，0644→0600 指纹纹丝不动。对 Shopify push 无害，但 `CORE_FILEMODE_FALSE` 那道门恰恰是以"覆盖权限"的名义 fail closed 的。已改为准确表述。

### 从 v0.3.0 设计原型回补的两条纯 bug（不改契约）

- **`core.autocrlf` 无门。** 开着 autocrlf 时把工作树文件从 LF 改成 CRLF，git 归一化后语义相同 —— `git status` 空、`git diff` 空、**指纹一字不变**，而 Shopify 推的是工作树字节。与 clean filter 同族，按同样姿态 fail closed（`true` / `input` 及大小写变体）。
- **已跟踪 symlink 的目标内容不在指纹里。** 包里原文写着「已跟踪的 symlink 不受影响」—— 那句话只对**链接字符串**成立，对**推送内容**不成立（Shopify CLI 上传的是解引用后的内容）。实测：目标文件内容换掉，指纹一字不变。精确拦截"目标解析后落在仓库外、或目标不是已跟踪文件"两类，指向仓库内已跟踪文件的合法用法照常放行。

### `sb_worktree_set` 两个盲区

- **换行路径无守卫**：`plaud_fingerprint` 为此专门 fail closed（`NEWLINE_IN_PATH`），本函数一直没有配套 —— 同一个仓库同一个文件，一个门停机、另一个门给出一份坏 `ModifiedFiles` 还说自己成功。已对齐。
- **baseline 已脏的文件再改一次 → delta 为空**：name-status 前后都是 `M`，`comm -13` 抵消，命令层完全看不出来，而「baseline 已脏且与本任务路径重叠 → 停机」只是散文。按命令走、跳过散文的 agent 会交出一个 `ModifiedFiles` 为空的 ChangeSet。已改为命令层可判定：对 baseline 里已脏的路径存内容 hash、收尾重算、差集非空即 `BASELINE_DIRTY_OVERLAP`。

### 三项"仍未做"收口

**这一轮不引入新机制，只把三个已知空位填上。** 外部评审（Codex，read-only）对初稿判「方案 1 有条件通过、方案 2 不通过、方案 3 只能部分通过」，下面是按它的意见改后的落点。

**① 封闭清单的变更权限（治理歧义消除）**

`handoff-schema.md` §8.1 新增「🔴 封闭清单的变更权限」：owner 只有矩阵包 maintainer、只能在切新版本快照时改；变更须同时具备双周会书面结论（纪要 + `YYYY-MM-DD` + 与会方含 PLAUD 侧 PM/设计/技术 owner）**与**该结论已写进新版本包，缺后者即"清单没变"；因为本包按全量快照分发而**纪要不随包分发**，不发版就是四端各读各的旧清单。并把开头那句"以双周会的书面结论为准"消歧为：**它决定下一版怎么写，不改变当前包怎么判**，不一致按 §7 停机。

"已同意但尚未进清单"给了完整的诚实落点，不留无值可填的洞：该条款**不得**写进 `ApprovedExceptions[]`（`Clause` 越界是谎报），`ApprovedExceptions` 保持 `[]` → `ApprovedExceptionsChecked: NotApplicable`（**不是** `Failed`——没声明就没有可判对象，这条是评审当场纠正的）；阻断落在该条款**原本就有**的那个字段（`StyleHardRuleCheck` / `A11yCheck` / `CopyConfigurabilityCheck` / release-ops 的门），**不新造 `ClauseCheck`**；都不承载时只能靠 `BlockingGaps`。`BlockingGaps` 写固定正文形态 `PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>`（**只有目标版本那一栏**可 `Unknown`，ref 与日期拿不到就停机），`Advisories` 措辞被写死，**禁止**写"本轮不适用""暂不阻断"——当前包的红线仍然适用。

接线点：canonical §8.1 + §4 模板注释 + §9.2 `ApprovedExceptions[].Clause` 行、`qa-global.md` §11（只补 QA 侧三条动作，**不复制清单与 owner 规则**）、`shared/matrix-contract.md` 的「红线增删」表新增一行、`version-manifest.md` 新增 §1.1「哪些改动必须伴随一次版本发布」、三个 producer SKILL 的 `ApprovedExceptions` 模板注释、新增 eval `qa-48-pending-clause-list-amendment`。
⚠️ `version-manifest.md` 里明写**它不是安装状态账本**：安装器对不存在的客户端目录静默跳过，"脚本跑完没报错"不等于四端都装上了，把"已校验"写进 Markdown 不构成证据。

**② 测试集换文档：结构化 `TestSetMigrationRef`**

自由文本理由里「我们换到 Linear 了」和「上一轮那份找不到了、我重新整理了一份」**长得一模一样**。新字段（QAIntake 工件第 17 个 key）：`From=<旧ID>@<旧rev>; To=<新ID>@<新rev>; Reason=<封闭枚举>; ReasonRef=<locator>; CaseDisposition=Mapped(<locator>) | BulkRetired(<locator>)`（`<locator>` = `Local(<相对材料根的路径>)` | `Manifest(<materials.tsv 条目名>)`；**清单只能 `Local`**）。

- **不引入新的事实源**：`From` 必须逐字等于本轮 `PreviousAcceptedTestSetTrace`（其权威来源是 QA 自己写的 `memory/changeset-log.md` `TestSetTrace` 列），`To` 必须逐字等于本轮 `TestSetTrace` —— 两端都是矩阵已经持有的字符串，比对不需要访问任何外部系统。
- `Reason` 封闭枚举**三值**：`PlatformMigration` / `OwnerHandover` / `Deprecated`。**刻意不给 `Other` 兜底**（兜底会立刻变成默认选项，这一行就退回自由文本）；越界 → `SelfTestReportStatus: Incomplete` + `BlockingGaps: TestSetMigrationReasonOutsideClosedEnum`。
- 旧用例去向的两种形态都必须指向**一份放进提测材料目录的清单文件**，因此自动进 `PackageFingerprint`（走既有材料绑定机制，不是新链路）：`Mapped` 逐条 `TC-old → TC-new / Dropped(<理由>)`，`BulkRetired` 给 `OldCaseCount` + 逐条旧 ID。🔴 **"旧文档打不开所以列不出来"不是免除理由**，这里不存在"矩阵去查外部系统失败"的降级取值（初稿的 `BulkRetired` 规则自相矛盾——一边要求旧文档不可访问、一边要求可核对的计数，已改）。
- **能力边界写明**：矩阵核**自洽性 + 内容绑定**（清单在材料里、条数与声明一致、旧 ID 不重复、事后不可替换），**不核真实性**（`TC-1042` 是否真在旧文档里，矩阵查不到也不查）。**一拆多 / 多合一的迁移形状本版不支持**（`From`/`To` 单值、上一轮 trace 只有一条），遇到即停机 `TestSetMigrationShapeUnsupported`，不得挑一份旧文档冒充一对一 —— 这是初稿把 `DocumentSplit` / `DocumentMerge` 写进枚举时的硬伤，评审指出后删掉这两个值并改成显式的能力声明。
- 降级取值：未换文档 `N/A(SameDocument)`；无可比对的上一轮（`None(FirstSubmission)` / `Unavailable(...)`）`N/A(NoPreviousTrace)`，不判 `Incomplete`、记 `Advisories`。ID 变了却填 `N/A(SameDocument)`、或 ID 没变却给完整声明，都是自相矛盾 → `Incomplete`。
- QA 的 `QAAdmissionReason` 界线定死：**字段缺失 / 语法坏 / `Reason` 越界 → `PackageIncomplete`**（本该在 intake 就判 `Incomplete`）；**字段齐全但 `From`/`To` 绑定对不上 → `BindingMismatch`**。
- `changeset-log.md` 的 `Note` 列可写 `Migrated(<旧ID> -> <新ID>)`，但**明写它是人读备注、不被下游消费**——下一轮仍只从 `TestSetTrace` 列取最近一条非 `N/A` 的行（那一行已经是新 ID，链本来就不断）。初稿曾声称"靠 Note 列让下一轮取到新 ID"，是假的。
- 接线点：`package-checklist.md` §3 + **新增 §3.1**（唯一语法源）、canonical §9.1.2 模板 + 六项材料表 + §8.1.1 + §9.2 新增枚举行、`qa-intake/SKILL.md` Step 2、`qa-intake/matrix-contract.md` 下游、`qa/SKILL.md` Step 0 新增第 (4) 项机械核对 + 两行准入表 + Step 5 日志规则、`qa/matrix-contract.md` 消费清单、`evidence-and-invalidation.md`、README；eval 新增 `intake-18` / `intake-19` / `qa-47`，改写 `intake-16`（"给个迁移说明"不再够）。

**③ 9 处历史 collision**

这 9 处是第三轮保留的 substring `forbidden`（`dev-12` / `impact-05` / `sb-25` 的 `QA-Global`、`impact-14` 的字段名、`orch-14` 的 `ReadyForDelivery`）。**结论是部分结构化，不是全部**：

| 处 | 结论 |
|---|---|
| `impact-14`（6 条 `\n<字段名>:`） | **已结构化**：语义完全由 validator 的 `forbiddenKeys` 承载 |
| `orch-14`（5 条同形态） | **已结构化**：给它补上此前缺失的 `forbiddenKeys`（并注明只针对**顶层** key —— `ChangeSetPlan` 的值里提到 ChangeSetId 是正常内容） |
| `dev-12` / `sb-25`（`QA-Global`） | **已结构化**：这是**字段值**约束，`yaml-block-exact-keys` 验不了，因此给 validator 加 `fieldValueConstraints`（`mode: "set"`、`allowedValues` / `forbiddenValues`），并写死语义：只解析最后一个 fenced yaml、逐成员比对、正文解释不算违规、未实现按未验证记 |
| `impact-05` / `impact-05b`（`QA-Global`） | 🔴 **做不到，明说**：这两题是问答、回复里**没有最终 yaml 工件块**，结构 validator 无处可用。只能留作 assertions + 赋值形态 forbidden 的文字约定；要机器可判就得改题目的输出契约，那已经不是清理 collision 了 |

🔴 **`forbidden` 一条都没删**（除了两处真会误杀的散文形态 `RequiredQAProfile 含 QA-Global` —— 正确答案写"…含 QA-Global 属违规"就会被命中）。评审的判据是对的：validator 目前只是 eval JSON 里的**声明**，harness 未实现就按"未验证"记，此时删掉 substring 回退，当前 runner 对这些约束就**完全没有机械约束**了。四条 validator 的 `note` 里都写明了：**forbidden 是 validator 落地前的回退，harness 真执行后才可以整批删**。

结构 validator **从 6 个增到 7 个**：新增 `intake-20-artifact-block-exact-fields`（qa-intake 此前**没有任何**结构 validator，`TestSetMigrationRef` 这种新增字段整字段漏写都发现不了），锁 QAIntake 的 23 个 key。

**外部评审第二轮（同一评审读实际改动）又抓出 4 组接线问题，已全部修掉**：

- 🔴 **`qa-global.md` §11 仍复述了清单当前成员**（"只有 A11y 3.0–4.5""§8.1 十一条无一在内"），同一段却写着"本处不复制清单"——那就是运行时文档里的**第二份适用清单**，canonical 一改、QA 仍按旧复述执行。改为「逐项现读已安装包的 §8.1 那张表」，不列成员；`version-manifest.md` 里的 v0.2.2 摘要也标明它是**发布当时的历史快照、不是运行时事实源**。
- 🔴 **`PreviousAcceptedTestSetTrace` 取数路径② 本来就跑不通**：它说"用户给的上一轮 `QAIntake` 工件，须是 `QAAdmissionStatus: Accepted` 的那一轮"，可 **`QAAdmissionStatus` 是 QA §5 工件的字段，`QAIntake` 里根本没有**——单给一份 `QAIntake` 证明不了"已通过准入"，谁都能拿自己写的草稿冒充。改为必须给**一对**工件（上一轮 `QAIntake` + 同 `SubmissionId` 的 QA 工件且后者 `Accepted`）。同时 QA Step 0 的 `From` 比对**按来源分支**：走路径① 才额外核日志，走路径②（前提就是日志不可用）再拿日志卡它会把合法输入锁死。并明确 `From` 比的是那一行的 **`ID@revision` 前缀段**，不是含 delta 的整行（类型本来对不上）。
- 🔴 **`ReasonRef` 与清单 locator 的语法没闭合**：正文写"四段"实际五段、判定表整段漏了 `ReasonRef`；语法要求 `Mapped(<materials.tsv 条目名>)` 而正文又说清单是本地普通文件（本地文件根本不需要 manifest 条目）；`Mapped` 要求"条数 = 头部 `OldCaseCount`"却只给 `BulkRetired` 定义了头部。统一为 **`Local(<相对路径>)` / `Manifest(<条目名>)` 两种 locator**，补上 `ReasonRef` 的判定行（只核**存在性 + 内容绑定**，**不核内容真伪**）、给 `Mapped` 定义头部，并写明 intake 做全量判定、QA 在重算包指纹时复核。
- 🔴 **`N/A` 分支被无条件跳过**：Step 0 原写"取 `N/A(SameDocument)` / `N/A(NoPreviousTrace)` 时跳过本项"，正好漏掉 §3.1 明文规定为自相矛盾的两种工件（ID 不同却填 `SameDocument`、有具体上一轮却填 `NoPreviousTrace`）。改为 (4a)/(4b)/(4c)/(4d) 四支逐项核；准入表另加一行：`Unavailable` / `NoPreviousTrace` 且其余项都对时**不阻断**，进 `Advisories`、**不进 `BlockingGaps`**。顺带把 Step 0 的"三项都要查"改成"四项"、`qa/matrix-contract.md` 的消费清单补回本轮 `TestSetTrace`。
- 🟠 eval 侧：`qa-47` 原题面的 `PreviousAcceptedTestSetTrace` 只给了 `ID@revision` 而不是上一轮完整原文（按契约它本身就该判 `PackageIncomplete`，题目不成立），且断言引用了题面没给的日志内容 —— 已补齐日志行与完整 trace；`intake-18` 原题面没有上一轮的 `Accepted` 证明、断言漏 `ReasonRef` / `OldCaseCount` / 本轮完整 delta —— 已补；`qa-48` 原题面只有"上周、运营/PM"，覆盖不到新治理证据门的"日期 + 完整与会方"—— 已补精确日期并加断言。`fieldValueConstraints` 补 `minItems: 1` / `allowEmpty: false`（否则 `RequiredQAProfile: []` 真空通过）；7 个 `yaml-block-exact-keys` 的 `note` 统一补上「解析时必须拒绝重复 key」（YAML parser 会把重复项折叠掉，缺 key 与重复 key 都验不出来）。

**验证**：10 份 eval JSON 全部 `json.load` 通过；**eval 266 条 / forbidden 185 个 / 结构 validator 7 个**，forbidden 自伤 0、合法值真前缀 0（每次改完 forbidden 都重跑，不只在收尾跑）；新增/改写的 forbidden 一律赋值形态，且在 `expected_output` 里附"不要复述该串"的提示；`intake-19` 因为它的每条错误结论都可能被正确答案以否定形式复述，**整条走 assertions、不设 forbidden**。

### ⚠️ 仍未做（留 v0.3.0）

- **指纹改绑不可变 commit / tree 对象** —— 多 ChangeSet 同批发版的彻底解法。
- **测试集迁移的一拆多 / 多合一形状** —— `TestSetMigrationRef` 本版只支持一对一，其余形状按停机处理（见上）。
- **evaluator 真正实现 `yaml-block-exact-keys` 与 `fieldValueConstraints`** —— 在那之前 7 个结构 validator 全部按"未验证"记，9 处 collision 的 substring 回退**不能删**。
- **真实端到端提测演练** —— 三档、`TestSetTrace` / `TestSetMigrationRef`、`ApprovedExceptions` 至今只经过静态评审。三轮评审里最严重的两个问题（🟠 开洞、指纹自毁）都是**评审**发现的、不是跑出来的，这一层还不够。

### 未变

10 个 skill 与 order、阶段轴三值、交付权归属、ChangeSet 指纹机制、**仍不支持多 ChangeSet 同批发版**（留 v0.3.0）、v0.2.1 的三档框架与存量复用豁免三道闸门（本版只给 🟠 加封闭清单与结构化字段，不放宽任何一档）。

### 仍未做

行为验证依旧没有：三个 v0.2.0 新 skill、三档分级、`TestSetTrace`、`ApprovedExceptions` 全部只经过静态评审 + evals，**没跑过一次真实提测**。v0.2.1 那两处高危问题正是静态评审第二轮才发现的，说明这一层还不够。

---

### 端到端提测演练（首次）

`dist/plaud-theme-matrix-e2e/` —— **不是方案文档，是能跑出 PASS/FAIL 的东西**：按内容锚点从包 Markdown 抽取 shell（不按行号，行号会随编辑漂移）、确定性 fixture 主题仓库（commit 日期钉死故 HEAD sha 可复现）、三组场景（指纹 17 / `sb_worktree_set` 8 / 包指纹 9）、20 条契约规则的 linter（**key 集合运行时从 canonical 模板取，不是转写**）+ 30 个单事实 fixture 的变异测试。首跑 146 断言全过、bash 3.2 与 zsh **连算出的指纹值都逐字节相同**、变异测试 20/20 规则被杀。

**它给自己装了反空跑门**：驱动会检查场景退出码、`E2E_TOTALS` 唯一性，并把 pass/defect 计数钉死成基线；实测两个 saboteur（场景改 `exit 0`、注释掉两条断言）都被抓出。**这一层是本包九轮评审里唯一一次"自证的检查项本身也被证伪过"。**

### eval harness 的真实状态：**未实现**

包里 7 条 `yaml-block-exact-keys` + 2 处 `fieldValueConstraints` 的 validator，**没有任何执行者**：包内无 runner、无 CI；`dist/` 下 26 个 `run_evals.py` 全属别的 suite，最完整的那份只遍历 `assertions`，既不读 `forbidden` 也不读 `validator`。好消息是**接线全对** —— 7 条的 `expectedKeys` 与 canonical 模板逐字逐序相等。这 7 条当前真实状态是 **UNVERIFIED 而不是 PASS**，`e2e/README.md` 给了人工核验流程，`lint/contract_lint.py` 可直接充当核验工具。

### 也修了第九轮记录里的一条假"已修"

第九轮写「去掉 `qa-42` 里连坐的合法正交值 `QAAdmissionStatus: Blocked`」，实际那一条还在；同族的 `qa-43` 还挂着与题面（changeset-log / TestSetTrace）完全无关的 `ApprovedExceptionsChecked: Blocked`，是复制粘贴残留。两条都已处理。**"已修"记录不可单独作为证据。**

### 第十轮演练回打的 6 项（演练套件对齐 v0.2.3 后跑出来的）

演练套件重钉基线后一口气打出 15 条新缺陷，**其中 5 条直接打脸本轮的修法**——修一个门时把同族的另一个漏掉，第十一次重复这个模式：

- **`core.autocrlf` 门可用布尔别名绕过**（`yes` / `on` / `1` / `iNpUt`）。本轮只比了六个字面量，而 git 还认这些。**第八轮给 `core.fileMode` 修的就是同一族**（当时的修法是交给 `git config --bool` 归一化），教训没带到新键上。修法要两条：`--bool` 归一化 + 大小写不敏感的 `input` 匹配（`input` 不是布尔，`--bool` 会直接报错）。
- **`.gitattributes` 的 `text` / `eol=` 在 autocrlf 全关时仍归一化**：两个不同的工作树字节串算出同一指纹且**没有任何门触发**。attributes 门至今只 grep `filter=`，已扩到 `text` / `eol=` / `working-tree-encoding` / `ident`。
- **已跟踪 symlink 指向 `memory/` 里的已跟踪文件**：本轮新加的门放行了它——因为门的前提是「目标已跟踪 ⇒ 内容进指纹」，而 **`memory/` 恰恰是唯一一个指纹刻意看不见的目录**，等于从这道门自己的假设里绕了出去。目标是**目录**时同理（pathspec 也能匹配 index）。两类已补。
- **`sb_worktree_set` 的 ②b/②c 只挡住 `M→M`**：awk 正则不含 `?`，而 **Path B 的产出恰恰全是未跟踪文件**，主场景根本没覆盖；改名行取的是 old path；只改 mode 时 `hash-object` 只看内容，**与指纹「覆盖未跟踪文件权限位」互相矛盾**；删除的文件因为诊断只打 `/^>/` 一个名都不列。四条全修。
- **`set -u` 下裸展开在打 sentinel 之前就崩**（`unbound variable`），仍 fail closed 但不可诊断。改 `${VAR:-}`。

**qa-intake Step 1 两个洞**（材料落仓的唯一门）：**已 commit 的材料三条命令全瞎**（`git add -A` 是最常见落法）；**子目录下三条 rc=0 且输出为空**——报告"干净"而其实什么都没查。已补三件：仓库根站位、**材料根必须落在主题仓库之外**（唯一一条机械可判的硬边界）、相对 `BaseHeadSha` 的已提交清单。

**仍未关闭的一条**：`PLAUD_PACKAGE_ROOT` 只关掉了「站错目录」，没关掉「**声明错目录**」——把某个子目录写成 `PackageRootRef`，producer 与 QA 仍会一致地算出子集。false acceptance 通道被**收窄**（错根写进工件、人能看见）而不是关闭。在"绑工作树"这个模型下没有干净解法，随 v0.3.0 的 tree-oid 改造一并处理。

### 仍未做（留 v0.3.0）

- **指纹改绑不可变 git 对象** —— 设计与可跑原型已完成，见 `dist/_wip-v0.3.0-fingerprint-design/`：新身份是空白临时索引 + `git write-tree` 得到的 tree oid（不 commit、不动 HEAD/ref/用户 index，默认不写 `.git/objects`）。诚实结算：同树串行**只部分解开**（Implement 真并行，但 QA 是对整树的观测，必须先物化不可变快照）；多块同批发版**解开，但集成 QA 这道串行屏障消不掉**；clean filter 族 / `core.fileMode` / symlink / 嵌套 repo / 含换行路径**仍在**。施工图 36 文件 / 173 处。
- 一拆多 / 多合一的测试集迁移形状（`TestSetMigrationRef` 的 `From`/`To` 目前单值）。
- evaluator 实现 `yaml-block-exact-keys` 与 `fieldValueConstraints`；在那之前不得删除作为回退的 substring `forbidden`。
- **真实 agent 黑盒演练**：现在的演练验的是"命令与门禁真跑起来是什么行为"，验不了"agent 读了 SKILL.md 之后会不会照做"。工件字段只能证明**报告称**未执行，不能证明真的零执行。

---

## v0.2.2 — 2026-08-12

**v0.2.1 的门禁收口版。** v0.2.1 发布并装到四端后，外部评审（Codex gpt-5.6-sol，read-only）判**不通过**：三档框架、存量豁免、A6/A7 事实修正都落地了，但 🟠 那一档在两处被写成了实际可绕过的形式。v0.2.2 只修这些，不引入新机制。

### 🔴 高危：`ApprovedException` 曾把红线开了洞

- v0.2.1 定义了「拿到书面批准即可放行」这一类，**却没有给封闭适用清单** —— 理论上 §8.1 的任何一条红线都能尝试走批准通道。
- 更直接的矛盾：`qa-global.md` §11 把「本次新建字段用了不合规默认值」当成 `ApprovedException` 的示例（有链接即 `Passed`），而唯一事实源 `handoff-schema.md` §8.1 第 10 条明写这一半是 🔴 **不可豁免**。同一份包里两个相反规定，实际执行会取宽的那个。新加的 eval 也同时说它「是 ApprovedException」又「是红线」，无法回答"有效批准到底能不能放行"。
- **修法**：`handoff-schema.md` §8.1 新增「`ApprovedException` 的封闭适用清单」。当前清单里**只有** §8 红线⑤ 的 A11y `3.0 ≤ x < 4.5` allowlist 配对一项；**§8.1 的 11 条没有任何一条在内**。明写「红线不因批准而放行」：第 10 条拿到批准也只能进 `BlockingGaps` 记「规范缺口待裁决」，`StyleHardRuleCheck` 仍 `Failed`，正确处理是先改规范或改默认值。`qa-global.md` §11 的表格补「适用范围」列并改写第 2 条不可退让项。

### 🔴 高危：`ApprovalRef` 不在任何结构化工件里

- §8.1 要求 QA 逐项核 `ApprovalRef`、§9.2 枚举表也把它当字段，但 Implement 工件（§4）与 Verify 工件（§5）**都没有这个字段** —— QA 无法机械判空、无法绑定到具体条款、多项 exception 也没地方放。
- **修法**：§4 新增 **`ApprovedExceptions`** 逐项结构（`Clause` / `Scope` / `ApprovalRef` / `ApprovedBy`；无则 `[]`，`Scope` 不得写"整个模块"，`ApprovedBy` 填 agency 自己视同为空）；§5 新增 **`ApprovedExceptionsChecked`** 与 `ApprovedExceptionsEvidence`；§9.2 补两行枚举。
  ⚠️ 初版曾写「刻意不取 `Blocked`」，与 §5 总则「该验但验不了 → `Blocked`」冲突，**已在同版第二轮评审中改回**：`ApprovalRef` 为空 / 越界 / 自批 → `Failed`（判过了，不成立）；提供了但核不动（403、权限不足、平台故障）→ `Blocked`。

### `TestSetTrace` 收口

- **加 `PreviousAcceptedTestSetTrace`**：v0.2.1 只校验本轮「稳定 ID + revision」，agency 每轮新建一份文档并称其为稳定 ID 仍能通过，"跨交付的增量维护"照样不可查。现在要求与上一轮已通过准入的那一行比对：**同稳定文档 ID、不同 revision**。文档 ID 变了又无迁移说明 → `Incomplete`；revision 与上一轮相同却声明了增删 → `Incomplete`（自相矛盾）。首次提测填 `None(FirstSubmission)`。
- **delta 改三段分列** `Added=[…]; Updated=[…]; Removed=[…]`：v0.2.1 写成一个合并列表，表达不了某个 ID 属于哪类。且**`Removed` 必须显式列** —— 被删的用例已不在本轮报告里，`Added/Updated/Unchanged` 标记推不出它；无删除写 `Removed=[]`。
- **单一事实源**：完整语法与判定只在 `package-checklist.md` §3 一处；`handoff-schema.md` §8.1.1 / §9.1.2 / §9.2 与 `qa-intake/SKILL.md` 改为指向它，不再各自复制语法。
- **release 侧可记录**：ReleaseOps 工件（§9.1.4）新增 **`TestSetTraceAfterArchive`** —— v0.2.1 在 `release-checklist.md` 要求「回归用例必须进同一份测试集、给出新 revision」，但工件里只有自由文本 `RegressionCasesAdded`，这条要求无处可记也无法核。现在要求同稳定 ID + 入库后的新 revision + `Added` 含新用例 ID；无线上 bug 填 `N/A(NoOnlineBug)`。`release-ops/SKILL.md` 的停机表同步加一行。

### `PreviousAcceptedTestSetTrace` 的取数路径落地（自查补充）

初版 v0.2.2 只写了「由 `plaud-theme-qa-intake` 从项目侧 `memory/changeset-log.md` 或用户给的上一轮工件里取」—— 但 `changeset-log.md` 由 `plaud-theme-qa` 维护、且**根本没有承载测试集行的列**，这条控制写了却不可执行（正是 v0.1.0 指纹 bug 那一类：文档承诺了实现没有的控制）。补齐：

- `changeset-log.md` **新增 `TestSetTrace` 列**（`plaud-theme-qa/references/evidence-and-invalidation.md` 的格式表 + 规则）：只在 `ReadyForDelivery: Yes` 时写，且**原样抄自 `QAIntake` 工件**（⚠️ 锚点在**同版第四轮**已改为 `QAAdmissionStatus: Accepted`，与 `ReadyForDelivery` 无关——见下文「PreviousAcceptedTestSetTrace 的锚点改为最近一次准入通过」，本行是改动前的记述）（不重编、不规整、不补全，否则失去比对意义）；`No` / 被豁免写 `N/A(NotAccepted)`，确无测试集写 `N/A(NoTestSet)`；**旧日志不回填**（回填等于编造历史）。
- `package-checklist.md` §3 给出**三级取数路径**：① `changeset-log.md` 的该列（唯一权威）→ ② 用户给的上一轮已通过准入的 `QAIntake` 工件 → ③ 都拿不到时填 `PreviousAcceptedTestSetTrace: Unavailable(<原因>)`，**不判 `Incomplete`、也不假装查过**，改记 QA 的 `Advisories`。③ 是明写的过渡条款（v0.2.2 之前的日志必然命中），一旦该列有值即不再适用。
- `handoff-schema.md` §9.2 的 `memory/` 记录字段表定义该列取值；`plaud-theme-shared/SKILL.md` 的 memory 文件表与 `plaud-theme-qa/SKILL.md` 的写 log 步骤同步；新增 eval `changeset-log-testsettrace-column`（考「新列必填 + 原样抄不得规整 + 不回填」）。

### QA 接线层的旧口径

- `qa-global.md` §11：「未触及的存量默认值」由 🟠 改 🟡，与 `handoff-schema.md` §8.1 第 10 条一致。
- `qa-profile-c.md` C3 裁定行：「改了 schema `options` 的 value → `Failed`」收窄为「**删除或修改**既有 `value` → `Failed`」，并补纯新增的 🟠 判法 —— 否则 C3 内部仍会误杀纯新增。
- `plaud-theme-qa/matrix-contract.md`、`plaud-theme-feedback-triage/matrix-contract.md`：不再把 shared §8.1 描述成「硬性 10 条」，并明确 DTC **§三**（运营协作，三档）与 DTC **§2.1**（样式硬规则，逐条可查）是**两套不同的 10 条**，不要混用。`classification-rules.md` / `evidence-lookup.md` 里指向 §2.1 的「10 条」本来就是对的，未动。

### eval 反向约束

- v0.2.1 新增的 7 条 eval 全部只有正向 substring 断言，在 substring-only harness 下「先复述正确关键词、再给相反结论」仍可能通过。现全部补 `forbidden` 数组（`impact` / `orchestrator` 早已在用这个字段）。
- 改写自相矛盾的 `orange-tier-approval-ref-empty` → `approved-exception-closed-list`（明确：拿到有效批准也不放行，因为不在封闭清单内）。
- 修正 `plaud-theme-ux-migration` 那条：v0.2.1 的期望要求「立即记进迁移日志待评估项」，与同 skill `hard-rules.md` §2.3「验收前不动迁移日志」冲突；改为验收前只记 Implement 说明与 QA 的 `Advisories`，验收后才入迁移日志。
- 新增 3 条：`ApprovedExceptions: []` 时该填 `NotApplicable` 而非 `Blocked`、每轮新建文档冒充稳定 ID、回归用例归档 trace。

### 事实表述更正

- `typography.md` §4.1 原写「仓库里存在**三套并行的 h5 实现**」——不准确。实测 `layout/theme.liquid:418-424` 的 `--h0-size…--h6-size` **全仓没有 `var(--h5-size)` 消费点**（`grep -r 'var(--h5-size)'` 零命中），它对渲染结果没有影响。改为「**一套生效规则**（`critical.css:148`，28.8px）+ **一处无消费点的死变量声明** + 一套与标签正交的语义体系」，并明写**不要去接那个死变量**（等于新造一条渲染路径）。`README.md` / `repo-drift.md` §3.7 / `version-manifest.md` 同步。
- `version-manifest.md`：删掉「`repo-drift.md` 不在 `SKILL.md` 索引表里、下次补进」——它早已在 `plaud-theme-shared/SKILL.md` 的索引表里，属过时描述。

### 评审第二轮补的接线（签收前）

第二轮验收又判不通过，问题全在**"字段加进契约但没接到运行路径"**这一族 —— 与 v0.1.0 那个指纹 bug 同源。补齐：

- **`ApprovedExceptions` 接进三个 Implement 输出模板**：`plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` 的 SKILL 末尾 yaml 块此前从 `BuildRequired` 直接跳到 `BlockingGaps`，实际工件**根本没法声明批准例外**。
- **`ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` 接进 QA 输出模板**，并进入 `ReadyForDelivery` 汇总条件（十个状态字段 → **十一个**）。此前即使该项应 `Failed`，QA 的运行手册照样能产出 `ReadyForDelivery: Yes`。
- **字段计数全对齐**：§4 = **20**、§5 = **26**。`MATRIX.md`（原 19）、`plaud-theme-dev` / `plaud-theme-ux-migration` evals（原 19）、`plaud-theme-qa` evals（原 23）、`plaud-theme-qa/SKILL.md` 与 `evidence-and-invalidation.md`（原 24 / 23）全部更新 —— 否则 eval 会把**符合新契约的正确输出判为错**。
- **`ApprovedExceptionsChecked` 恢复 `Blocked`**：v0.2.2 初版禁用它，与 §5 总则「该验但验不了 → `Blocked`」冲突。界线写死：**为空 / 越界 / 自批 → `Failed`**（判过了，不成立）；**提供了但核不动**（403、权限不足、平台故障）→ `Blocked`。
- **堵住 `Scope` 这个绕过面**：原来只禁字面「整个模块」，"全站所有按钮""所有该色配对"仍能通过。现在要求逐对象绑定 —— A11y 例外须一条一项写「前景色 + 背景色 + 出现实例 + 实测 ratio」；聚合写法 QA **不追问、直接 `Failed`**。并新增第四项核查：**`ApprovalRef` 的批准内容必须覆盖得住所填 `Scope`**（批了一处、Scope 写了一片 → `Failed`）。
- **`TestSetTrace` 的"单一语法源"兑现**：`handoff-schema.md` 里仍残留两处旧合并语法（§8.1.1 正文与 §9.1.2 材料表），且说"全部 delta 可由现存标记推出"（与 `Removed` 必须显式列矛盾）。两处都改为只指向 `package-checklist.md` §3。
- **`TestSetTraceAfterArchive` 语法明确**：工件示例只写 `Added=[…]`，枚举却说"与 `TestSetTrace` 同格式"。改为**三段齐**（只新增时后两段写 `[]`），并明写它不接受 `None(reason)`（归档轮次必然有新增用例）。
- **`hard-rules.md` §2.2.1 与 §2.3 的正文冲突**：§2.2.1 原写"记进迁移日志的待评估项"，紧接着 §2.3 又禁止验收前写日志。改为分时点：**验收前**只进 Implement 说明 + QA `Advisories`，**验收后**才入迁移日志。
- **漏改的联动点**：`plaud-theme-qa/matrix-contract.md` 上游字段清单补 `OptionsConsidered` 与 `ApprovedExceptions`、并新增一行 `ApprovedException` 封闭清单接线；`plaud-theme-release-ops/matrix-contract.md` 下游补 `TestSetTraceAfterArchive`；`plaud-theme-orchestrator` 门 2 由"必须交出 `ChangeSetId` + `ModifiedFiles`"改为**结构核 §4 完整 20 字段**，并明写「`ApprovedExceptions` 整字段缺失（退回）≠ 填 `[]`（合法）」。
- **`forbidden` 自伤修掉**：v0.2.2 初版有一条 forbidden（`新增 EntrypointRationale 字段`）正是其 expected（`不新增 EntrypointRationale 字段`）的子串，会误杀正确答案；另有几条会误杀"不要 / 不能 + 禁止短语"的自然表述。全部改写为完整句式，并写了一个扫描脚本核对「本轮新增/改写的 10 条 eval 的 forbidden 均不是自身 expected / assertions 的子串」。

### 评审第三轮补的接线（签收前）

第三轮又判不通过。这轮的发现分两类：**接线只落在主路径、特殊路径仍是旧契约**，以及**指纹命令自身的两个静默失败点**（后者是我在验证排除逻辑时实跑发现的，不在评审清单里）。

**指纹命令（§2 与 §9.1.2 两段，实测发现、实测验证）**

- 🔴 **`changeset-log` 写入会当场把刚记录的 QA 结论算失效。** 指纹覆盖全部未跟踪文件，而 `memory/changeset-log.md` 就在工作树里 —— 这个控制会在第一次使用时自毁。v0.2.1 及以前靠"先算指纹再写 log"绕，但那只能让**同一轮**两次校验相等，任何**后续**重算（release-ops 复核、§1.4 失效判定）仍然失配。**修法：指纹排除 `memory/`**（`:(exclude)memory/`）—— `memory/` 是项目运行时状态，不属于任何 ChangeSet。被否掉的替代方案：把日志移出主题仓库（切断"日志与工作树同源"的可追溯性）、维持原有的写入顺序约定（治不了后续重算）。
- 🔴 **`{ … } | shasum` 的子 shell 吞错。** `{ }` 是管道左端、跑在子 shell 里，里面的 `return 1` 只结束那个子 shell，`shasum` 照样把**残缺输入**算出一个像样的 hash。实测：仓库里有未跟踪目录时，旧命令输出 `e3b0c44298fc…`，即**空输入的 sha256** —— 完全正常、完全错误。修法：先把 payload 收进变量、`|| return 1` 挡住，成功了才 hash。
- 🔴 **未跟踪"目录"被静默跳过。** `git ls-files --others` 对整个目录都未跟踪的情形（嵌套 git repo、本地 worktree、`dev/` 之类）列出的是**目录名**，`git hash-object` 对目录必然失败 —— 旧写法在这里滑过去，该目录整棵树都不进指纹。修法：遇到就 fail closed 并打印 `UNHASHABLE_UNTRACKED_DIR`。
- ⚠️ **`case` 不能用在 `$( )` 里**：第一版修法用了 `case "$f" in */)`，在 macOS 自带的 **bash 3.2** 下直接语法错误（我最初只在 zsh 下测过，所以没暴露）。改用 `[ "${f%/}" != "$f" ]`。
- `PackageFingerprint`（§9.1.2）有同一个 payload-in-pipeline 洞，一并修。
- **验证方式**：把包里那两段命令**原样抽出来**，在真实仓库 `shopify-plaud-yidian` 上跑 —— **bash / zsh / sh 三个 shell** 下都要：连续写 `memory/changeset-log.md` 指纹不变、任何非 `memory/` 改动仍被捕获、未跟踪目录 fail closed、材料内容变则包指纹变且还原可复原、`PLAUD_PREVIEW_URLS` 为空 fail closed。全部通过。

**接线只落在主路径**

- **弃检模板**（`evidence-and-invalidation.md`）声称 26 字段实际只有 23，缺 `QAAdmissionReason` / `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence` 且顺序不对 —— 现已按 canonical 顺序补齐，并写了脚本逐字段比对（26/26、顺序一致）。
- **准入阻断与 ChangeSet 失配两处**仍写"十个状态字段"，漏第 11 项；`MATRIX.md` 的 Verify 仍写 24 字段 —— 都已改。并明确失配场景下 `ApprovedExceptionsChecked` 填 `Blocked`（没读到上游工件）而**不是** `NotApplicable`（那要 §4 确为 `[]`）。
- **`Blocked` 的口径**：canonical 已改对，但 QA eval 42 仍断言"本字段不取 Blocked"（会误杀正确答案），README / CHANGELOG 前文也仍失实 —— 已全部修正并标注"初版曾这样写、同版已改回"。

**`PreviousAcceptedTestSetTrace` 的锚点改为"最近一次准入通过"**

原来只在 `ReadyForDelivery: Yes` 时记 trace，但字段要的是"上一轮**通过准入**"—— 上一轮 intake 过了、QA 失败时**没有合法取值**，而返工轮次正是最容易换文档的时候。现改为：只要 `QAAdmissionStatus: Accepted` 就原样记，与 `ReadyForDelivery` 无关；下一轮取**最近一条非 `N/A` 的行**。日志示例补了一行 QA 失败但 trace 照记、一行准入被 Blocked 记 `N/A(NotAccepted)`。

**release 侧两个运行矛盾**

- 无线上 bug 时 `TestSetTraceAfterArchive` 可填 `N/A(NoOnlineBug)`，但 `RegressionCasesAdded` 又被无条件要求非空 —— 现给它同样的 `N/A(NoOnlineBug)`，并写明**留空 ≠ N/A**（前者是"该补没补"）。
- SKILL 一面声明 v0.2.2 不支持集成 QA，一面仍要求构造发布树并填 `IntegrationQARef` —— **该字段在 v0.2.2 根本不存在**。现统一为"部分发布唯一出路是停机"，并把死字段从 `SKILL.md` / `MATRIX.md` / `release-ops/matrix-contract.md` 三处清掉。

**`forbidden` 二次修正**

上一轮的"不是自身 expected 子串"扫描**不足以证明安全**：`forbidden: "不建议复用既有 h5"` 仍会命中正确答案里的"不建议复用既有 h5 全局规则"这类否定前缀表述。现全部改成**赋值形态 / 肯定结论**（如 `RiskTier: Low`、`ReconMode: IntegrationSurface`），不禁裸概念词。

历史遗留的 15 处同类 collision，按"是否会误杀自然正确答案"分了两类：**6 处已修**（`impact-04/11/12b/17`、`orch-13/17` —— 原来禁的是 `模板使用量`、`建议选`、`IntegrationSurface`、`是 Low`、`ReadyForDelivery: Yes`、`Partial` 这类裸词）；**9 处保留**（`dev-12` / `impact-05` / `sb-25` 的 `QA-Global`、`impact-14` 的五个字段名、`orch-14` 的 `ReadyForDelivery`）—— 它们约束的是**最终纯 YAML 块**的内容，且 `impact-14` / `orch-14` 另有结构化 validator，不构成恒假。

### 评审第四轮：已修两项高危 + 一项自查发现（其余待处理，见下）

- 🔴 **三个 producer 各自内嵌了一份落后两代的指纹命令**（`dev` / `section-build` / `ux-migration` 的 SKILL），且都写着"跑下面命令"。抄本仍在用 `--find-renames=false`（git 2.52 起非法）、`printf "$(git hash-object …)"`（命令替换吞错）、`{ … } | shasum`（子 shell 吞错），且不排除 `memory/`。末尾那句"冲突时以 §2 为准"**拦不住任何人**——命令是可执行的，抄本一旦落后就会真的算出另一个指纹。**三处副本已删除，改为强制去 §2 原样复制**，并写明指纹类命令只允许一处事实源。
- 🔴 **`PackageFingerprint` 第三个静默失败面**：`while … done` 循环**零次迭代时退出码也是 0**（heredoc 建不了临时文件、输入为空等），后续 URL `printf` 又把状态覆盖成 0 —— 实测退化成"只 hash `urls:` 那一行"，材料完全没参与却产出正常指纹。**两段指纹都加了行数核对**（hash 出来的行数必须等于 `git ls-files` / `find` 报的条数），并把 URL 检查提到最前。
- 🔴 **行数核对当场抓出我自己写的 bug**：`printf '%s' "$var" | while read` 的最后一行会被 `read` 读到但返回非 0、循环体不执行 —— **排序最后一个文件永远漏出指纹**。改成 `printf '%s\n'`。这个洞在加守卫之前是完全静默的。
- **验证**（两段命令原样抽出，bash / zsh / sh 三个 shell + 干净临时 repo + 真实仓库）：三 shell 同值；`memory/` 写入指纹不变；排序最后一个未跟踪文件的内容变化被捕获；嵌套 git repo fail closed；人为让 hash 段少输出一行 → `UNTRACKED_COUNT_MISMATCH` 挡住；材料循环拿不到输入 → `FILE_COUNT_MISMATCH` 挡住；空 `PLAUD_PREVIEW_URLS` fail closed。

### 第四轮剩余 6 项 + 4 条 eval：已全部处理

1. **QA 保存 trace 的主路径锚点** —— `qa/SKILL.md` 由 `ReadyForDelivery: Yes` 改为 `QAAdmissionStatus: Accepted`，`shared/SKILL.md` 的 memory 表措辞同步。**准入过、QA 失败的返工轮现在也留 trace**，连续性不会在返工那一轮断链。
2. **`memory/` 排除范围对齐** —— `evidence-and-invalidation.md` 两处「不排除」改为「已排除」（并说明"靠顺序规避自失效"为什么不够、为什么顺序仍建议保持）；**QA 比对文件集合的命令也加上 `-- . ':(exclude)memory/'`** —— 不加的话 QA 自己写的日志会被当成"上游没申报的额外文件"，把合法改动误判成 `ChangeSetIdMatched: No`，正常交付被永久卡死。
3. **弃检模板拆成两种形态** —— 原来只有一份（固定 `UserWaivedMaterials` + 全部 `Blocked`），表达不了"提测包 Accepted、用户弃 QA"，也会覆盖"弃材料但照跑技术检查"的实际结果。现给出逐字段对照表（`QAAdmissionStatus` / `QAAdmissionReason` / 十一个检查项 / `QAProfilesRun` / `FingerprintVerifiedAt` / `Evidence` / `BlockingGaps`），并标明模板本身是「弃 QA」那一种。**弃材料 ≠ 弃验证。**
4. **`Unavailable(...)` 的成立条件收紧为可判定** —— 由"日志确无该列"改为"**找不到任何一条 `TestSetTrace` 非 `N/A` 的历史行，且用户也给不出上一轮已通过准入的工件**"，并列出三种真实情形（旧日志无此列 / 有列但历史行全是 `N/A` / 日志缺失）。原措辞下「有列但全是 N/A」这一支没有合法取值。
5. **云材料口径反向修正** —— `qa-intake/SKILL.md` 原写"无版本载体是已知弱环，在 `BlockingGaps` 如实注明"，与 canonical「必须 `Incomplete`」相反，等于给防替换链留了个公开的洞。现改为一律 `Incomplete` + 四行载体对照表，并写明 `BlockingGaps` 是停机项不是免责栏。
6. **四条 eval 与运行手册对齐** —— release eval 2 删掉"构造发布树重跑集成 QA"的断言、改为"唯一出路是停机"；section-build 的 `sb-22` expected 与 assertion 统一到 `qa-intake`、`sb-25` 补 `ApprovedExceptions`；dev eval 的 20 字段列表补回 `OriginTriageRef`；新增 QA eval 覆盖"准入 Accepted、QA Failed 仍要记 trace"。
7. **修 eval 时又引入并当场修掉两个 `forbidden` 误杀** —— `IntegrationQARef`（新加的断言里正当地提到了它）、以及 `NextRequiredSkill: plaud-theme-qa`（它是正确答案 `…qa-intake` 的**真前缀**）。为此加了一条**前缀扫描**：检查 forbidden 是否为任何合法取值 / skill 名的真前缀。当前只剩 3 处命中，都是**故意**的（Assess / Coordination 工件里 `ReadyForDelivery` 这个字段本身就不许出现）。

### 评审第五轮（换独立评审）——10 项已全部处理

第五轮由一个**不带前四轮上下文**的评审做，实跑了两段指纹并造了前四轮没造的场景。它证伪了几条我原本判为"留 v0.3.0"的：

**静默漏算（实跑复现，不是推演）**

- 🔴 **路径含换行 → 两段指纹都静默漏算，且行数守卫也对得上。** NUL→换行的转换会把 `a\nb` 这种路径拆成两行，两半都 hash 不到；造 `a` / `b` / `a\nb` 后改 `a\nb` 的内容，指纹**完全不变**。现在**先探测再算**，命中就 `NEWLINE_IN_PATH` 退出。
- 🔴 **`ReadOnlyProof` 可以绕开 QA。** 原来它 hash 的是 `git status --porcelain` 文本，那里只有**状态码 + 路径、没有内容**。工作树一开始就 dirty 时，审计中改**同一个文件的内容**，前后 hash 相同（我复现了：`M f.txt` → 改内容 → hash 一字不变）。于是 agent 可以先改代码、再输出 `ChangeSetId: N/A` / `ModifiedFiles: []` 并附一份"两次一致"的证明，**完全绕开 QA** —— 正是这一节要堵的事。现改为用 §2 的 `plaud_fingerprint` 取快照（覆盖内容），canonical + `dev/SKILL.md` + `dev/matrix-contract.md` + `task-workflows.md` 四处同步。
- 🔴 **包指纹静默跳过 symlink 与隐藏文件**（`-type f -not -path '*/.*'`）：改 symlink 目标内容、改隐藏材料内容，指纹都不变。现在遇到两者**fail closed**（`UNSUPPORTED_MATERIAL_OBJECT`），要求换成普通文件——静默排除比报错危险得多。
- ⚠️ **执行环境要求写明**：两段函数都用 `set -o pipefail`，Linux 常见的 `/bin/sh`（dash）**不支持**、会直接以状态 2 退出。macOS 的 `/bin/sh` 实为 bash 所以前几轮测不出来。文档现在明确要求 bash(≥3.2)/zsh。

**范围不一致（会让正常交付假失配停机）**

- 🔴 **QA 的文件集合命令漏了 `--untracked-files=all`**：不加的话**新建目录会被折叠成一条 `?? dir/`**，而 `ModifiedFiles` 是逐文件列的 —— 一个新目录就造成假失配。
- 🔴 **`ModifiedFiles` 与 `memory/` 的矛盾**：canonical 说 `memory/` 不属于 ChangeSet，但 §4 又要求 `ModifiedFiles`"与工作树一致"，而 Path C 实际会写 `memory/`。列进去 → QA 的排除命令假失配；不列 → 违背 producer 模板。现在四处（canonical + 三个 producer 模板）都明确写：**`ModifiedFiles` 不含 `memory/`**，那些更新写在正文。

**文档层不一致**

- `Unavailable(...)` 的三种情形此前只写在 canonical 散文里，可复制模板、§9.2 枚举、`qa-intake/SKILL.md` 摘要都漏 —— 三处补齐。
- 云材料 manifest 仍允许"**人工核对时间**"当内容绑定，与"无 revision/digest 一律 `Incomplete`"矛盾（"某人某时看过"在内容被替换后一个字都不变）—— 该选项删除，两栏必须是机器可复核的值。
- `release-ops` 停机表写"等它验收完一起发" —— **等齐之后就是两块同批，照样撞单块限制**。改为"重新规划为逐块串行"，eval 2 同步。
- README 里仍留着 v0.2.1 那份**已废止**的合并 delta 模板（照抄会生成 canonical 判 `Incomplete` 的工件）—— 换成三段分列 + `PreviousAcceptedTestSetTrace`，并指明唯一事实源。

**eval 反向断言第三轮修正**

- 禁裸 `QA-Global` 会误杀"该字段**不含** QA-Global"这类合法说明（dev-12 / impact-05 / sb-25）—— 改成赋值形态。
- 更根本的问题：字段名类 forbidden 在**全局 substring** 语义下永远有误杀风险。现统一约定：**forbidden 以换行开头（`"\nRootCause:"`）时表示「不得作为 yaml key 出现在行首」**，正文提到该字段名不算违规；已按此规范化 9 处，并写进 eval 文件的 `description`。
- 修的过程中又自造了两处误杀（`IntegrationQARef`、`等它验收完一起发` 与新写的 expected 撞），当场扫出并改掉。现在**子串自伤 0、真前缀风险 0**。

### 评审第六轮——8 项已全部处理（发现比第五轮更靠主路径）

**又三处指纹静默面（评审实跑复现）**

- 🔴 **被 gitignore 的主题可发布文件完全不进指纹。** 两处 `git ls-files` 都用 `--exclude-standard`，而 Shopify push 推的是整个主题目录 —— ignored 的 `assets/*.css` 照样上线却不在指纹里（把它放进 `.git/info/exclude` 后，新增与改内容指纹都不变）。修法：**只对可发布目录**（`assets` `blocks` `config` `layout` `locales` `sections` `snippets` `templates`）探测 ignored 文件，命中即 `IGNORED_PUBLISHABLE_FILE` fail closed —— `node_modules` / `.DS_Store` 本就该 ignore、不在这几个目录下，所以不会误拦（已实测两种情形）。
- 🔴 **GNU `stat` 的 `%Lp` 文件名碰撞。** 原写法 `stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f"`：GNU stat 把 `%Lp` 当成**另一个文件操作数**，仓库里恰好有名为 `%Lp` 的文件时第一支就"成功"、第二支不执行，拿到的是文件系统信息而非权限位 —— 权限改了指纹不变。修法：**循环外先按平台定一次** `STAT_MODE_CMD`，两支都探测不到就 `NO_USABLE_STAT` fail closed。
- 🔴 **材料目录里的 FIFO / socket / device 被静默跳过**（探测只禁了 symlink 与隐藏对象，主体又只取 `-type f`）。修法：改为**只允许普通文件与目录**，其余一律 `UNSUPPORTED_MATERIAL_OBJECT`。顺带去掉 `| head -5` —— `pipefail` 下 head 提前关管道会让 `find` 吃 SIGPIPE、丢掉诊断。
- 补：**未跟踪 symlink 在 §2 也 fail closed** 了（这条是我自测时撞到的）。`git hash-object` 走的是**目标的内容**，所以把 symlink 改指向另一个同内容文件，指纹一点不变。已跟踪的 symlink 不受影响 —— git 存的是链接目标字符串，`git diff HEAD` 覆盖得到（两种都实测过）。

**主路径漂移（这批不是极端造景）**

- 🔴 **release 的"QA 结论时效核对"复用了刚被否掉的旧洞**：它写的是 `git rev-parse HEAD` + `git status --porcelain`。QA 通过后如果改的是**同一个已 dirty 文件的内容**，status 输出一字不变 —— agent 会把"QA 后又改了内容"判成"结论仍有效"，**发出去的是没验过的字节**。改为用 §2 的 `plaud_fingerprint` 逐字比对。
- 🔴 **QA 会接受畸形 §4 工件**：Step 1 只检查四个字段，Step 4 还会替上游按 `Path` 反推补 `RequiredQAProfile`、对非法 `QA-Global`"照跑不误"。现在 Step 1 增加**结构核**（20 字段齐全 + 取值在 §9.2 封闭枚举内 + 明写「整字段缺失 ≠ 填 `[]`/`N/A`」），任一不满足即停机、十一项全 `Blocked`，并**取消"照跑但指出写法有误"与按 `Path` 反推**——那两条等于 QA 替上游修工件，下一轮同样的错还会来。
- 🔴 **section-build 的 baseline 算法失真**：baseline 采 `git diff` + `git status`，收尾只采 `git diff`。于是仓库里本来就有未跟踪文件时**什么都没做也产生假 delta**，而新建的 `sa-*` section 是未跟踪的、**根本不在收尾集合里**——Path B 的主体产出被漏掉。改为 baseline 与收尾共用同一个 `sb_worktree_set()`（相对 HEAD 的改动 + 未跟踪文件，均排除 `memory/`），用 `comm -13` 取差集。实测：无操作时 delta 为空、新建 section 与改存量都被抓到。
- 🔴 **`memory/` 范围仍有两条运行路径没跟上**：`qa-intake` 的"材料落仓"前置门跑的是未排除 `memory/` 的 status（合法的 `memory/模块清单.md` 更新会被误判成材料落仓、假阻断 Path C），`ux-migration` 的 matrix-contract 与 verification-loop 仍要求与 raw 工作树集合一致。三处都已排除。顺带修掉"任意 `.md` 都算材料"——主题仓库里本来就有合法 `.md`（README / docs/ / dev/），判据应是"是否本次六项材料之一"，不是看扩展名。
- **两个旧 eval 还在教已废的做法**：`dev-07` 仍要求用 `git status --porcelain` hash 做 `ReadOnlyProof`（等于认可可绕过 QA 的做法）、QA eval 24 仍称 `changeset-log` 会进指纹。都已重写，并新增一条 QA eval 覆盖"缺 `ApprovedExceptions` / `OriginTriageRef` 的畸形工件必须停机"。
- **`FeedbackItems` 字段计数自相矛盾**：canonical 写"五个字段缺一不可"，紧接的模板实际列九个。按"五个"执行会漏掉 `PMDecisionValue` / `PMDecisionRef` / `NextRoute` / `NewWorkItemRef`——PM 确认与回流链正好断在这里。改为九个并列出字段名。

**forbidden 第四轮修正**

评审独立扫了 258 条 eval / 177 个 forbidden，指出我"真前缀 0"的自查漏了一处：裸 `Partial` 会命中合法值 `PartiallyExecuted`。另有 5 个 forbidden **完全等于合法值**（两个裸 `QA-Global`、两个裸 `IntegrationSurface`、一个裸 `plaud-theme-dev`）——正确答案写"不是 IntegrationSurface"或解释"QA-Global 恒执行"都会被判错。全部改成赋值形态（`ReconMode: IntegrationSurface` / `RequiredQAProfile: QA-Global` / `ChangeSetStatus: Partial` 等）。现在子串自伤 0、真前缀 0；剩下 11 处"等于枚举值"的是 `ReadyForDelivery: Yes` / `ReadyForImplement: Yes` 这种**赋值形态**，场景里正确答案本就该是 `No`，属正当禁令。

> ⚠️ 仍存的残余风险：`forbidden` 在 harness 里是**全局 substring**，换行前缀这个约定只是缩小了误伤面、并没有真正获得"YAML key"语义。彻底解法是把这些条目升级成结构化 validator（`impact-14` / `orch-14` 已有），留 v0.3.0。

### 端到端演练（2026-08-13，构造材料）

按第六轮评审建议，不再做同规模静态扫荡，改为把**包里的命令原样抽出**、在 `/tmp` 的独立主题仓库里跑固定场景。材料是**构造的**（不是真实提测包），所以这轮验的是**流程、命令与门禁是否真的挡住**，不验"真实材料是否符合准入判据"。

抽出执行的三段：§2 `plaud_fingerprint`、§9.1.2 `plaud_package_fingerprint`、section-build 的 `sb_worktree_set`。

| 场景 | 合规路径 | 反例（门禁必须挡住） | 结果 |
|---|---|---|---|
| **Path A 只读审计**（前提：工作树一开始就 dirty） | 两次 `ReadyOnlyProof` 一致 → 留在只读通道 | 审计中偷改同一个已 dirty 文件的内容 | ✓ 指纹变 → 必须退出只读通道。**对照旧写法（`git status` hash）确认 hash 一字不变**，绕过洞成立 |
| **Path B 新建未跟踪 `sa-*`**（前提：仓库里已有无关未跟踪文件） | 未动手时 delta 为空；三个新建文件全部进 delta | 交付后偷改新建文件内容 | ✓ 无假 delta、无漏项（旧算法两头都错）；偷改被 `ChangeSetIdMatched: No` 挡住；`--untracked-files=all` 下三个新文件逐个列出、没被折叠成 `?? sections/` |
| **Path C 含 `memory/` 更新** | 写清单 + 写 changeset-log 后指纹不变；`ModifiedFiles` 自查只列 `sections/existing-hero.liquid` | 真把 `.png` 写进仓库 | ✓ 不自失效、不假阻断；真材料落仓被检出 |
| **提测包指纹** | 11 个材料 + 2 条预览 URL 算出指纹，QA 复算一致 | 偷换一张截图内容 / 清空预览 URL / 塞 symlink / 塞 FIFO | ✓ 四条全部 fail closed |
| **QA→release 时效** | 写完 log 指纹不变 → 结论仍有效 | QA 通过后"顺手又改了点"（同一个已 dirty 文件） | ✓ 指纹变 → 结论自动失效、停机。**对照旧写法输出一字不变**，会发出没验过的字节 |
| **`PreviousAcceptedTestSetTrace` 取数** | 从 changeset-log 取到最近一条非 `N/A` 的 trace | 下一轮换新文档 ID | ✓ 取数路径①可执行，不必回落 `Unavailable`；换 ID 判 `Incomplete` |
| **其余门** | 盲区核对无输出 | `memory/` 塞 `.liquid` / ignored 可发布文件 / assume-unchanged / 未跟踪嵌套 repo / 未跟踪 symlink / 换行路径 | ✓ 六条全部命中并停机；清理后正常路径仍可用 |

**这轮演练没有发现新缺陷。** 但它验不到的部分要说清楚：材料是构造的，所以「配置文档四要素是否齐」「测试用例四段式是否可复核」「预览链接是否真能改配置」这类**内容判据**没验；`ApprovedExceptions` 与三档分级仍未在真实评审场景里跑过（本轮只跑了它们所依赖的指纹与工件门）。

### 评审第七轮（换第三个独立评审）——8 项已处理

**第 1 条是我第六轮自己新加的门禁 fail-open**，评审用 12,000 个 ignored 文件复现：

- 🔴 **`| head -5) || ignored_pub=""` 让 ignored 文件门 fail open。** `pipefail` 下命中量大时上游吃 SIGPIPE 而失败，紧跟的 `|| var=""` 又把证据清空 → 函数两次都返回 0，改其中一个 ignored 文件 hash 仍完全相同。修法：**先数个数**（`tr -cd '\0' | wc -c`）、判定完再用 `head` 只做诊断输出。**门禁的失败分支绝不能兜底成「没命中」** —— 这是本次最该记住的一条。实测低基数(5) 与高基数(12000) 都正确 fail closed。
- 🔴 **tracked 侧三个盲区**（前两个实测可静默漏算）：`.gitattributes` 的 **clean filter**（工作树字节变了但 filter 清洗后 git 语义相同 → diff/status 都看不见；`evidence-and-invalidation.md` 反而声称它"不影响判定"）、**大小写不敏感卷上的纯大小写改名**（`git status` 为空、指纹不变、磁盘文件名已变）、**`core.fileMode=false`**（tracked 权限变化对 git 隐形，而本函数只对未跟踪文件记权限，等于"覆盖权限"这个声明是假的）。修法：前两个 fail closed（非默认配置），大小写用**一次 `find` 取盘上清单再做集合差**并排除已被 `git status` 报告的路径（避免把合法删除误报）。
  ⚠️ 第一版大小写检查逐文件 `ls | grep`，在 1600 个 tracked 文件的仓库上 **>2 分钟没跑完**（会让 agent 挂死）；改成集合差后 **0.8 秒**。
- 🔴 **orchestrator 的「可并行」与全树指纹直接冲突**：原文允许 `ModifiedFiles` disjoint 的块并行，而指纹绑的是整个工作树 —— 第二块落盘就改变第一块的对象，A 的 baseline/delta/指纹会吸收 B 的文件，接着要么 A 把 B 的产出冒充成自己的、要么 A 在 QA Step 1/Step 2 永久失配。改为：**同一工作树内 Implement / 指纹 / QA / release 一律逐块串行**；可并行的只有 Assess（只读）与「各块在独立 worktree 里开发」，且后者集成回主树时仍须逐块串行 + 重新生成 ChangeSetId 重跑 QA。`ParallelSafe` 的语义相应收窄。
- 🔴 **section-build 的 matrix-contract 仍是旧命令**（裸 `git diff --name-status HEAD`）：不含未跟踪文件（新建 `sa-*` 整批漏掉）、不排除 `memory/`（合法 memory 更新被错误升级为 `LegacyImpact`）。改为引用 `sb_worktree_set()`。主 SKILL 上一轮修了、这份复制路径没跟上 —— 又是同一个族。
- 🔴 **§9.2 枚举表不完整**：QA 的结构核要求"20 字段取值都在封闭枚举内"，但表里没有 `Path` / 三个 `*Required` / `NextRequiredSkill` —— agent 既可能放行 `Path: D`、`BuildRequired: Maybe`，也可能因为没有事实源而无依据地停机。四项已补。
- 🔴 **QA 的零改动入口自相矛盾**：准入表有 `Accepted / ZeroChangeReadOnly` 一行，而同文件后面又写「本 skill 没有零改动分支」（§5 的 26 字段里既没 `ModifiedFiles` 也没 `ReadOnlyProof`）。结果是 QA 可能为一个没有 ChangeSet 的审计发出毫无验证含义的 `Accepted`。该分支与 `ZeroChangeReadOnly` 取值一并废止，canonical §5 准入门第 3 条同步改写。
- 🔴 **orchestrator eval 与 SKILL 仍教把 `QA-Global` 写进 `RequiredQAProfile`**（§9.2 明禁）—— agent 照着写，QA 的新结构门会把十一项全部 `Blocked`。已改，并加断言锁住"不含 QA-Global"。
- 🔴 **「改成赋值形态就安全」这个结论不成立。** 典型 `orch-12`：题面前提就是三个 QA 给了 `ReadyForDelivery: Yes`，而 forbidden 全局禁同一串 —— 合理回答"尽管 QA 给了 `ReadyForDelivery: Yes`，协调工件仍无交付权"会被误判。**全局 substring 不理解「不得填」「不成立」这类否定语义。** 处理：扫掉所有会被自身题面命中的 forbidden（8 处），其中 `orch-17` 的守卫有价值、改成赋值形态（`ChangeSetStatus: Done`）而非删除；并把这条约定写进 8 个 eval 文件的 `description`：**不要把否定短语写成 forbidden，要禁就禁赋值形态或明确的错误结论句。**

**顺带纠正 CHANGELOG 自己的数字**：上一轮我写"258 条 eval / 177 个 forbidden"，评审实测是 259/196。当前实际是 **eval 259 条 / forbidden 190 个**（子串自伤 0、题面自身命中 0、合法值真前缀 0；剩 10 处"等于枚举值"的都是 `ReadyForDelivery: Yes` 这类赋值形态且题面/期望不含该串）。

**我自查补的一条**（不在评审清单里）：§2 与 `sb_worktree_set` 都加了**仓库根守卫**。原来"必须在仓库根执行"只写在正文注释里、没有守卫 —— 在子目录跑时 `-- .` 会把范围收到该子目录，**静默算出一个子集指纹并返回 0**（实测根目录与 `sections/` 下得到两个不同的正常 hash）。守卫的错误信息也从 `echo` 改成 `printf` + ASCII 分隔：变量紧贴多字节字符时某些 bash 会截断输出（实测 bash 截断、zsh 正常）。

### 评审第八轮（第四个独立评审 + 我方独立实跑）——16 项已处理

**这一轮第一次出现"上一轮的修法本身留了新洞"以外的模式：我第七轮修 A 门时，同族的 B 门没跟着修。**

指纹门（全部实测复现，bash 3.2 与 zsh 各跑一遍，结果逐字节一致）：

- 🔴 **clean-filter 门 fail open —— 与第七轮那条 `head -5` 同族。** 旧写法 `… | grep -q .`：`grep -q` 命中即退出关闭管道，上游 `while` 吃 SIGPIPE（141），pipefail 下整条管道失败，`if` 于是不进阻断分支。**实测 1 个 `.gitattributes` 正确阻断、3000 个直接放行。** 改法同 ignored 门：不许任何提前退出的消费者，命中项全收进变量再判空。顺带补上第七轮漏掉的两个 attributes 来源：`$GIT_DIR/info/attributes` 与 `core.attributesFile`。
- 🔴 **`core.fileMode` 只认字面 `false`。** git 的布尔值还有 `off` / `no` / `0` / 大小写变体，这些取值**直接通过**该门，而函数只对未跟踪文件记权限 —— "指纹覆盖权限"这句话就是假的。改用 `git config --bool --get` 让 git 自己归一化（实测 `off` / `0` 现在都阻断）。
- 🔴 **tracked symlink 被误报成大小写改名 → 指纹永远算不出来。** 第七轮新加的盘上清单用 `find … -type f`，symlink 不在其中，于是 `tracked − disk` 把它列成 `PATH_CASE_MISMATCH`，整条 QA/交付链死锁，报错还指向一个不存在的问题；同文件另一处明写"已跟踪的 symlink 不受影响"，那句话原本是假的。改为 `\( -type f -o -type l \)`。
- 🔴 **主题目录少一个就静默失败。** `find` 固定传八个可发布目录，少一个（`blocks/` 只有新版 theme architecture 才有）即退出非 0，而那条 `|| return 1` **一句诊断都不打**。改为只传盘上存在的目录，三个采集分支各自给出 `CASE_CHECK_FAILED: <哪一步>`。
- 🔴 **`find $_dirs` 在 zsh 下不做词分割**（本函数明文支持 bash 与 zsh 两家）：整串当成一个参数传给 find。改用 `set -- "$@"` 位置参数，三家 shell 语义一致。
- 🟠 **`-z` 格式下改名的 ORIG_PATH 被 `sed 's/^...//'` 削掉三个字符**（`assets/a.css` → `ets/a.css`），同行的 `s/^.* -> //` 在 `-z` 下是死代码。改为只在行首确实是"两位状态码 + 空格"时才剥。
- 🟠 **提测包指纹把 `.DS_Store` 报成"只接受普通文件与目录"** —— 可它**就是**普通文件，macOS 上用 Finder 打开过材料目录就必然有它，agent 拿到一句自相矛盾、无从下手的报错。拆成 `UNSUPPORTED_MATERIAL_OBJECT` / `HIDDEN_MATERIAL_OBJECT` 两条，各给处置动作。

其余（Standards）：

- 🔴 **`sb_worktree_set | sort > "$BASE" || echo "BASELINE_FAILED"` 的守卫是死的。** 管道退出码取自 `sort`，调用方又没有 `pipefail`（它只在函数自己的 `( )` 子壳里）。实测：在子目录跑，函数打出 `NOT_REPO_ROOT` 并返回 1，而 `BASELINE_FAILED` 一个字都不打、baseline 文件 0 字节 —— 接着 `comm` 会把**整棵工作树**当成"本 ChangeSet 新产生的"。改为先落盘、用 `if` 判函数本身的退出码。
- 🔴 **`mktemp -t sb-baseline` 在 GNU coreutils 上直接报错**（模板必须含 `XXX`），Linux 上 `BASE` 为空 → 往工作目录写 `.raw`、或让 `comm` 拿到空路径。改为 `mktemp "${TMPDIR:-/tmp}/sb-baseline.XXXXXX"` 并判退出码。
- 🟠 **安装器的物理路径校验只在目标目录已存在时才跑** —— 首次安装创建完目录就直奔 `rm -rf`，全程没有 symlink 检查。改为 `mkdir -p` 之后复验，并在物理路径与词法路径不一致时明确打出"rm -rf 实际作用在哪"。

Spec：

- 🔴 **同树并行规则自相矛盾。** 第七轮改了 §四 顶部红框（同树 Implement/指纹/QA/release 一律串行），但同节底下"**可并行**：`ModifiedFiles` 完全 disjoint…"、顺序原则第 3 条"纯新建可与存量改动并行"、`ParallelSafe` 字段注释、以及 `orch-09` 的 expected 全没跟上。四处一并改成"可拆独立 worktree"的口径。
- 🔴 **已废止的零改动 QA 分支在三处复活**（`qa-intake/SKILL.md` 的"唯一免提测包情形"、`qa/matrix-contract.md` 同句、`qa/SKILL.md` 准入表的重复表头与旧行）。零改动任务**不进 qa-intake、也不进 QA**，全部改写并清掉重复表头。
- 🔴 **只读路由形成 dev ↔ QA 死循环**：dev 的 description 把"用户要最终交付判定"的零改动任务推给 QA，QA 又把**所有**零改动请求转回 dev。统一为：零改动恒归 dev，用户点名也不转；QA 触发条件补上"**且该任务确有改动**"（改了 dev/SKILL、dev/matrix-contract、qa/SKILL description、README、2 条 qa eval 断言）。
- 🔴 **ux-migration 会替上游"剔除 `QA-Global` 后再继承"**，而 QA 明令枚举违规停机、不得替上游修 —— 改为停机退回 `plaud-theme-impact` 重出工件。
- 🔴 **qa-intake 没接入 `OriginTriageRef`**：Step 0 的消费清单里没有它，Step 2 的 `ReworkDeltaStatus` 却要判首轮/返工 —— 没有事实源就只能默认 `NotApplicable`，**返工轮次的「本轮修改点」整份漏收**。补进 Step 0 并给出三行判据表（含"字段缺失 ≠ `N/A`"）。
- 🟠 `version-manifest.md` 的 orchestrator 入口还是旧口径（B+C / A+C 交叉、用户要完整交付），与 `MATRIX.md` 的唯一门槛"≥2 个可独立验收 ChangeSet"冲突 —— 已对齐。
- 🟠 `SharedContractCheck` / `ReferencesLoaded` 是 canonical 之外的一套字段。补明它们是**正文自检块**：写在阶段契约块之前、不得并进 §4/§5 的封闭字段集、下游不得消费（canonical §9 + shared 的两份文件同步）。
- 🟠 **字段计数 eval 没真锁住字段集**：QA 那条声称核 26 字段却只断言了 19 个（漏 `StyleHardRuleCheck` / `ApprovedExceptionsChecked` 等 7 个），ux 那条漏 10 个。补齐漏掉的字段名，并给四条工件 eval 都加上 exact-keys 断言（个数 + 顺序 + 无自造 key + 无漏字段）。
- 🟠 **`forbidden` 的第三层陷阱**：第七轮的结论"改成赋值形态就安全"不够 —— 真正的判据是**正确答案即使做否定表述也不会命中**。`可以并行` 被"不可以并行"命中、`拆成` 被"不需要拆成"命中、`可以发布` 被"不可以发布"命中、`判定 ReadyForDelivery` 被"本 skill 不判定 ReadyForDelivery"命中、`直接交给 plaud-theme-qa 判定` 被"不是直接交给 plaud-theme-qa 判定"命中。**动作类一律改成第一人称承诺句**（`我标成可并行了`、`我构造了只含已验收块的发布树`），字段类改赋值形态。共改 26 条 eval 的 forbidden。
  ⚠️ 我在改这批时**自己又踩了一次第七轮那个坑**：给 `orch-12` 重新加回 `ReadyForDelivery: Yes`，而该题的题面前提正是三个 QA 都给了这个值 —— 扫描当场抓出，已移除。**这类扫描必须在每次改完 forbidden 后重跑，不能只在收尾跑一次。**
- 🟡 补 `plaud-theme-orchestrator/matrix-contract.md`（此前 10 个 skill 里唯一没有的）；`qa/matrix-contract.md` 的消费字段从 15 个补到 §4 全量 20 个（Step 1 的结构核就是按这 20 个逐个点）；canonical 的"三个非阶段 skill"改"四个"、`ReadyOnlyProof` 笔误改回 `ReadOnlyProof`；"任何情况下不得跳过 Verify"在 5 处收窄为"任何有改动的任务"（与 §2 的只读免 QA 不再冲突）。

**验证**：指纹函数 11 个场景 × bash 3.2 / zsh 全过且两家逐字节一致（缺目录出指纹、tracked symlink 出指纹、改内容指纹变、大小写改名 fail closed、1 个与 3000 个 clean filter 均 fail closed、`core.fileMode=off` fail closed、ignored 可发布文件 fail closed、嵌套 git repo fail closed、未跟踪 symlink fail closed、子目录 `NOT_REPO_ROOT`）；提测包指纹 clean 场景 hash 与改动前一致（未改变指纹语义）；安装器 `bash -n` + `--help` 通过；10 份 eval JSON 均可解析，**259 条 / 180 个 forbidden，自伤 0、合法值真前缀 0**。

### 评审第九轮（第五个独立评审，首次真跑动态测试）——15 项已处理

**这一轮把评审换成 workspace-write 的一次性副本，让它真的建仓库跑脚本。** 上一轮它的动态测试被只读沙箱挡了、只能静态推理；这一轮它用注入失败命令、3000 个 attributes、多 locale 材料复现出来的问题，**静态读一百遍也看不见**。

指纹侧（我方独立实跑复现 + 修复后逐条回归，bash 3.2 / zsh 两家逐字节一致）：

- 🔴 **第八轮我修 clean-filter 门时写的 `_ga_hit=$( pipeline; : )`，那个 `:` 把 pipeline 的失败整个吞掉** —— 注入 `git ls-files` 失败后，两家 shell 都先打印错误、**随后照样返回一个正常 SHA-256**。同一道门还有三个漏：只枚举 tracked `.gitattributes`（工作树里**未跟踪**的那份照样生效）、`core.attributesFile` 拿到 `~/x` 后 `[ -f ]` **不展开 `~`**、路径含换行时 NUL→换行转换又把它拆成两半。**重写**：列表落临时文件（`$( )` 在 bash 里会直接丢掉 NUL 字节，不能用变量存 `-z` 输出）、每条命令单独判退出码、`while` 从文件读、`git config --path --get` 让 git 自己展开 `~`。
- 🔴 **`sb_worktree_set` 的 `sort` 没被守住**：第八轮我只判了函数的退出码，注入失败的 `sort` 后两家 shell 都只在 stderr 打错误、整段仍 `rc=0`，于是拿着**空的 baseline** 继续 `comm`。改为函数与 `sort` 都成功才算 baseline 成立。
- 🔴 **提测包指纹的文件排序未固定 locale**：同一份含 `ä.txt` / `中.txt` 的材料，`C` / `en_US.UTF-8` / `zh_CN.UTF-8` 排出**三个不同指纹** —— intake 与 QA 环境 locale 不同就必然 `BindingMismatch`，材料一个字节都没改。已固定 `LC_ALL=C`（修后三个 locale × 两家 shell 六次结果全同）。
- 🔴 **安装失败仍整体退出 0**：注入失败的 `tar`，20 次全失败、目标 0 文件，脚本 `rc=0`（每次失败被 `|| true` 吞掉，末尾不核对数量）。改为核对 `ok == targets × sources`，不等即打印 `FAILED: X of Y` 并 `exit 1`。实测正常安装 exit 0 / 注入失败 exit 1。
- 🟠 **`PLAUD_PREVIEW_URLS` 没有可执行的事实源**：只规定"不得为空"，没说从哪来、怎么排、什么分隔——intake 与 QA 各拼一次就是两个指纹。补死：取 `PreviewManifest` 的前后台 URL 全集、trim、`LC_ALL=C sort -u`、单换行连接。
- 🟠 **`ChangeSetId` 的 `<NN>` 没有 allocator**：两个独立 worktree 会各自生成 `CS-20260813-A01`，QA / changeset-log / 返工链把两批内容当成同一个 ChangeSet。补四条规则（读日志取当日该 Path 最大号 +1、生成后**立刻**占位、独立 worktree 下不得自行生成须回 orchestrator 统一分配、撞号即停机不许自造后缀）。

**我自己实跑发现、不在评审清单里的一条**：

- 🔴 **`memory/` 的排除只挡得住工作树与暂存区，`commit` 一下就绕过了。** payload 第一行是 `git rev-parse HEAD`——实测改 `memory/` 不变、`git add memory/` 不变、**`git commit` 变**。也就是说"QA 写 changeset-log 不自失效"这个保证，**只在日志不被提交时成立**；顺手 commit 一下，刚记完的结论连同 `BaseHeadSha` 一起失效，而主题一个字节没动。已在 canonical §2、QA 的 Step 5 与 `evidence-and-invalidation.md` 三处写死规则（日志留工作树不单独 commit；确需入库只能在出结论**之前**连同主题改动一起提交并重新取证），并新增 eval `qa-46-memory-commit-invalidates`。

契约与 eval：

- 🔴 **同树串行的第五、第六处复述点**：canonical 的 `ParallelSafe` 字段注释仍写"碰同一文件的必须串行"、`orch-09` 的 expected 仍奖励 disjoint 并行。（第八轮改了 4 处、漏了这 2 处——**同一条规则的复述点要 grep 到尽**。）
- 🔴 **`ux-migration/matrix-contract.md` 仍写"上游误写 `QA-Global` 则剔除"**，与同 skill 的 SKILL.md 停机口径相反（第八轮只改了 SKILL.md）。
- 🔴 **`evidence-and-invalidation.md` §2.5 仍称 clean filter"判定不受影响、注明即可"**，与 canonical 的 fail-closed 门直接相反 —— 照它做会在指纹被绕过时继续 QA。已改写，并把 `text=auto` / CRLF 与自定义 filter 分开说。
- 🟠 `qa-intake/matrix-contract.md` 的上游字段清单漏 `OriginTriageRef`（第八轮只接进了 SKILL.md），且整个 qa-intake eval 没有返工用例 → 补清单 + 新增 `intake-17-rework-delta-from-origintriageref`。
- 🟠 `qa/matrix-contract.md` 的 QAIntake 消费清单漏 6 个字段（`ChangeSetId` / `ChangeSetFingerprint` / `PackageRootRef` / `PackageFingerprint` / `BlockingGaps` / `PreviousAcceptedTestSetTrace`）——正是它下一行承诺要做的防重放、防替换重算与跨轮连续性的依据。
- 🟠 `shared/matrix-contract.md` 写着"QA 可据 `ReferencesLoaded` 判断"，与 canonical §9「下游不得消费自检块」冲突（QA 拿它当门，会因为上游漏写一行自检而卡住合格的 ChangeSet）；`shared/SKILL.md` 的第二套 `HandoffContract` / `ReadyForNextSkill` 也补明是**引用回执、不是 canonical 工件**。
- 🟠 **第八轮的"exact keys"是假的**：那四条只是普通 substring 断言，全包真正的结构 validator 只有 impact 与 orchestrator 两个。已给 dev / section-build / ux / qa 四条补上 `yaml-block-exact-keys` validator（`expectedKeys` + `forbiddenKeys` + "harness 未实现则按未验证记"的 note），并把 orchestrator 那条的 `keys` 统一成 `expectedKeys`。**结构 validator 从 2 个增到 6 个。**
- 🟠 **`PMDecisionValue: N/A` 不在 §9.2 封闭枚举里**，而模板要求 `PMDecision: Pending` 时填 `N/A` —— 结构核会判非法，等于逼 agent 去伪造一个尚未发生的 PM 决定。已补进枚举并限定适用条件。
- 🟠 **forbidden 的第四层**：`ReconMode: LegacyImpact` / `AllChangeSetsDelivered: Yes` 这类**赋值形态**同样会被正确答案顺带复述命中。定稿判据写进 10 个 eval 文件的 `description`：只写"错误工件里必然出现、正确工件里不可能出现"的赋值；确需禁某个赋值时在 `expected_output` 里注明"不要复述该串"；**能用 assertions 表达的一律走 assertions，不进 forbidden**。同时去掉 `qa-42` 里连坐的合法正交值 `QAAdmissionStatus: Blocked`。
- 🟡 `shared/SKILL.md` 的 `StageResolved` 补上 `N/A(NonStage)`（与 matrix-contract 对齐）。

**两条评审说了但不成立的**（已复验）：安装器 symlink ancestor（评审跑的是它开工前的快照，该问题在它跑动期间已修，当前树对 symlink 的 `skills` 目录与 symlink 祖先都拒绝）；"三份实现 skill 的接线图直接画 Implement→QA"（三份 matrix-contract 早就写的是 `qa-intake → qa`）。

**验证**：指纹函数 13 场景 × bash 3.2 / zsh 全过且两家逐字节一致（含新增的未跟踪 `.gitattributes`、`$GIT_DIR/info/attributes`、`core.fileMode=no`、注入 `git ls-files` 失败、3000 个 attributes 高基数）；包指纹 3 locale × 2 shell 六次同值；`sb_worktree_set` 注入失败 `sort` 两家都打 `BASELINE_FAILED` / `AFTER_FAILED`，正常路径 0 次误报；安装器隔离 HOME 实装 10 个 exit 0、注入失败 `tar` exit 1；`bash -n` / `zsh -n` 全过；**eval 261 条 / forbidden 183 个 / 结构 validator 6 个，自伤 0、合法值真前缀 0**。

---

## v0.2.1 — 2026-08-12

**评审回应版。** v0.2.0 的 15 项待确认清单发给设计方后收到 9 条逐项评审意见，本版只处理其中三类：一条矩阵写错的事实，两条被明确反对的门禁收紧。不新增 skill、不动阶段轴、不动交付权。

### 撤回

- **`typography.md` §4「H5 = 22px 是现行规范值」整条撤回。** UX Spec v1.3（2026-08-11 基线）通篇没有 H1–H6 字号表、没有 22px；该命名来自 vendor 旧文档。§4 重写为「HTML 标题标签不是 UX Spec 的档位」，标签语义与字号解耦。
- **「22px 在工具类体系里根本不存在」撤回。** `.fs-22` 真实存在（`assets/critical.css:1019` = `1.38rem` = 22.08px；另见 `snippets/critical-style.liquid`），且 `sections/newsletter-popup.liquid` / `sections/login-popup.liquid` 仍在引用。原表述把 `design-system.liquid` 的 **9 个语义类**误当成了全部 `.fs-*`。新增 §4.2 区分「语义类 / 数字遗留类」两套体系。
- **「优先复用既有 `h5 {}` 全局规则」撤回并明确禁止。** 该规则实测产出 **28.8px**（`--size: 1.8rem` × 根字号 `16px`），`h1` 同理 57.6–64px，正是被标为已废止的 vendor 64px。新增 §4.1 列出仓库里三套并行的 h5 实现。
- `version-manifest.md` §6 的「H5 = 22px 无同值工具类」「H 标签表的断点标注」两条缺口标记撤回。
- `feedback-triage/references/evidence-lookup.md` 的「已知缺口」示例换成品牌渐变缺几何参数。

### 分级修订（DTC §三 红线）

设计方反对「一刀切」（原话：过于绝对化会导致设计/开发/测试任何环节的偏差都要全环节对齐，降低效率；点名「复用 section」应给空间）。`handoff-schema.md` §8.1 改为三档：

- 新增 🟠 **可论证放行**，且**拆成两类不可互换的子类**：`EvidenceBased`（自证；QA 核 `OptionsConsidered` + `AssessmentRef` + `ActualAffectedInstances` 是否齐，缺 → `Blocked`）与 `ApprovedException`（须 PM / 设计 / 技术 owner 的书面 `ApprovalRef`，**为空直接 `Failed`**）。**agency 自写自批不构成 `ApprovedException`。**
- 保持 🔴：#1 #2 #3 #4 #6 #7。
- 改为**按范围**判定而非整条降级：#5（🔴 本次新增/修改的行；🟡 存量未触及；⚠️ 本次让旧硬编码进入新可达路径 → 按新增判 🔴，`git diff` 抓不到，须人工核）、#9（🔴 删/改既有 option value；纯新增放行但须验 Liquid 映射 / schema 保存 / 旧存值兼容）、#10（🔴 留空崩溃无豁免；🔴 本次新建或修改字段的默认值；🟡 未触及的存量默认值）。
- #8 三层入口 → 🟠 `EvidenceBased`，**复用既有 `OptionsConsidered`，不新增 `EntrypointRationale` 字段**（避免第二个事实源）。
- 新增 §8.1.2 **存量复用豁免（Legacy Reuse Carve-out）**：只豁免**修复义务**，不豁免验证范围。三项硬约束：举证偏差在 `BaseHeadSha` 已存在（可复跑命令）、未加重且未变成新可达行为、回归仍按 `ActualAffectedInstances` 全量。**QA-B 空配置 / 满配置双测不因本条豁免。**
- 联动：`qa-global.md` 新增 §7.1（CopyConfigurability 判定范围）与 §11（🟠 复核 + 豁免三项核查）；`qa-profile-b.md` B5/B6、`qa-profile-c.md` C3、`ux-migration/hard-rules.md` §2.2 / §2.2.1、`feedback-triage/classification-rules.md` §3.1 同步。

### 提测材料简化（DTC §一 第 3 条）

设计方指出「测试做太多重复性工作很影响效率」。原「测试集溯源三项」收敛为一行：

```yaml
TestSetTrace: <稳定文档ID>@<不可变revision>; Added/Updated/Removed=[TC-ID…] | None(<reason>)
```

- `@<revision>` **不可省**：只给 URL 的话，同一链接既可被覆盖内容也可每次指向临时文档，「增量维护 vs 每次现编」完全不可查 —— 这是这条总则唯一还能落地的部分。
- delta 段由测试报告里每条用例自带的 `Added / Updated / Unchanged` 标记推出，**不再另写一份清单**；平台 URL 自带不可变 revision 时两段合并成一个字段。
- `TestSetTrace` 进 `QAIntake` 工件 YAML 与 §9.2 枚举表；`release-ops` 的 `RegressionCasesAdded` 归档必须指向同一稳定文档 ID。

### 新增实测漂移记录

`repo-drift.md` §3.6 / §3.7（2026-08-12 实测，`shopify-plaud-yidian`）：

- outline 按钮在仓库里是**两条互不相通的样式链** —— `.btn-outline` 消费 scheme 级 `--btn-outline-border-color`（10 个 scheme 存值全是 `#39f672`，与 spec 的 `#717171` 不符），`.btn-secondary-outline` 则写死 `var(--color-label-secondary)`，而 `.use-color-scheme` 会把该变量重绑成 `var(--color-text)` —— 「借用 label 变量会变色」已经是既存现实。`colors-and-schemes.md` §3 据此改为**先判两条链是否要统一、再决定复用变量还是新增语义变量，未裁决则停机**，撤回原来「已有变量 → 直接复用」的推论。
- 全局 heading 规则仍是旧 vendor 值（h5 = 28.8px、h1 = 57.6–64px），另有 `layout/theme.liquid` 一套 `--h5-size: 18px`。
- `--color-label-secondary: #7A7A7A` / `--color-label-tertiary: #A3A3A3` 仍在 build 产物里 → 2026-08-11 基线的 `#717171` / tertiary 废止**尚未落库**。

### 未变

交付权（只有 `plaud-theme-qa` 能出 `ReadyForDelivery: Yes`）、10 个 skill 与 order、阶段轴三值、ChangeSet 指纹机制、**v0.2.1 仍不支持多 ChangeSet 同批发版**（彻底解法仍留 v0.3.0）、A11y 三道闸门（Pre Order `1.30` 仍判 `Failed`）。

### 仍未做

三个 v0.2.0 新 skill 依旧只有 evals + 静态校验，**没有跑过真实提测的行为验证**；`TestSetTrace` 与三档分级同样只经过静态评审。

---

## v0.2.0 — 2026-08-12

两条主线：**接入《DTC 开发交付标准 v1.0》**（2026-08-06，运营与产研共同维护，双周会可审议修订），以及**跟进 2026-08-11 的 UX Spec 设计 Token 基线**。

### 1. 新增 3 个 skill（7 → 10）

| order | skill | 承担 | 工件 |
|---:|---|---|---|
| 6 | `plaud-theme-qa-intake` | DTC §四 提测准入：六项交付物、站点清单、包指纹 | `QAIntake` |
| 8 | `plaud-theme-feedback-triage` | DTC §六/§七 反馈归因：缺陷 vs 变更、依据、去向、Linear 建议 | `FeedbackTriage` |
| 9 | `plaud-theme-release-ops` | DTC §五 发版与上线后：推站二次确认、PR、bug 时效、回归用例 | `ReleaseOps` |

原 `plaud-theme-qa` 由 order 6 顺延为 **order 7**。

> 🔴 **提测准入放在 Verify 之前，不是之后。** 初版方案曾把交付包组装放在 QA 通过之后（"验完了再打包交付"），**时序是错的**：DTC §四 原文写的是「提测时必须同时提供，**缺一不进验收**」——交付物是**进验收的准入条件**。放在 QA 之后等于代码验完了才发现没人能复核。
>
> 三个新 skill **均不占阶段轴**。阶段轴恒为 `Assess / Implement / Verify` 三值，写 `Stage: Handover` 之类一律违规。新增 handoff-schema §0.1 专门说明这四个（含 orchestrator）非阶段 skill 的位置与阻断能力。

拆成三个而不是一个的理由：提测包组装、反馈归因、发版治理是**三个不同生命周期**——提测发生在 Verify 前，发版在 Verify 后，反馈归因可在任意时点触发且会**回流**到 Assess。塞进一个 skill 会产生触发歧义与权限混合。

### 2. 交付权边界（§1.1 新增）

`ReadyForDelivery: Yes` 只代表通过了矩阵内部的技术验证。新增明文：它**不代表**提测材料齐备、**不代表** PM 已验收、**不代表**可以推站。四者正交。

> 🔴 **防止产生「第二个交付许可」。** 初版方案打算给提测包一个 `HandoverReady: Yes/No` 字段——与 `ReadyForDelivery` 同构（`Ready` + `Yes/No`），下游极易误读成第二道发布许可。
> 改为**语法隔离**：提测包用 `Complete` / `Incomplete`，交付许可用 `Yes` / `No`，两套枚举明令不可互换。三个新 skill 的产出里**都不出现 `ReadyForDelivery`**；`release-ops` 引用 QA 结论的字段刻意命名为 `QAConclusionRefs` 而非 `ReadyForDeliveryVerified`。

### 3. 提测包的独立内容绑定

`ChangeSetFingerprint` 只覆盖**主题仓库工作树**，对截图、文档、预览 URL 一无所知。新增 `PackageFingerprint`（各材料文件 hash + 预览 URL 原文）单独绑定。

> 🔴 **提测材料不得写进主题仓库。** 截图、文档一旦落进工作树，`ChangeSetFingerprint` 立刻变化 → QA 的 Step 1 判 `ChangeSetIdMatched: No` 并停机——**提测方会因为交了材料而过不了自己的准入门**。qa-intake 的 Step 1 就是查这个，先于一切。

站点维度另立字段（`TargetSites` / `ExcludedSites` / `ThemeIds` / `ScopeSourceRef`）：`AssessmentRef` 回答的是「哪些**模板/实例**受影响」，**不回答**「要推**哪些站点**」。DTC §三 点名推错站点是"过去扣分最多的一项"，因此站点清单要求**两次确认**（需求时 + 发版前）且都有出处，`plaud-theme-impact` 明令不得自行推断站点。

### 4. UX Spec 跟进 2026-08-11 基线

源文档换成设计方新出的 `Plaud-UX-v1.3`「设计 Token 与组件规范文档」（8 页 PDF，打印于 2026-08-11，比 v0.1.0 发布晚 5 天）。版本号仍是 v1.3，但内容是重新整理过的一版。

**冲突项（新基线覆盖旧值）**：

| 项 | v0.1.0 | 新基线 |
|---|---|---|
| 字重 | 「全站**仅** Regular 400，禁止新增字重」 | Regular 400 默认 + **Semibold 600** 用于局部强调 / 数据数值 / 价格突出 |
| `label-secondary` | `#7A7A7A` | **`#717171`** |
| `label-tertiary` | `#A3A3A3` | **该档废止**（新基线无此层） |
| 白色按钮 hover | `#E9E6E6`（colors 表）/ `#EEEEEE`（按钮表）—— 本来就自相矛盾 | 统一 **`#EEEEEE`** |

**纯新增**：角标色板 7 种、透明度叠加 4 个 token、品牌渐变 5 停色标、`--color-bg-white` / `--color-bg-dark`、`label-purple/cyan/green`、按钮 5 变体 + Secondary-Outline 边框 + 四档高度、导航/卡片/倒计时组件尺寸、布局网格 8 档的内边距与内容宽度。

三条落地纪律：

- **`label-tertiary` 走墓碑流程，不是全仓一把删。** 它在真实主题里承载划线价、脚注、免责小字，直接删会让这些元素回退继承父色（多为纯黑）。规范层废止 + 新代码禁用（QA 对新增使用判 `Failed`）+ 过渡期允许一个版本的 alias 指向 secondary + 零引用后才删 utility 与 scheme 重绑 + 历史 seed 不改写只标 supersede。
- **按钮高度是「单行目标最小高度」**，落实为 `min-block-size` + `height: auto` + padding 撑开。写死 `height` 判 `Failed`——德/法/西/俄比英文长 30–50%，换行时会溢出或被裁。固定 `width` 仍全面禁止。这条是新基线与全路径红线②的共存方式。
- **组件尺寸表的 px 先分类再落地**：设计参考（不进 CSS）/ 比例约束（`aspect-ratio`）/ 最小尺寸 / 技术固定例外。不得全翻译成固定宽高。
- **品牌渐变无法直接落地**：只有 5 个色标，圆心、半径、形状、stop 位置全缺。要用时**停机**要 Figma 节点，不得编造 stop position。
- **AI 专属渐变原样保留**：新基线 §2.8 写「渐变仅用于 Announcement Bar 装饰背景，不用于其他场景」，字面上会读成 AI 渐变废止——但该文档通篇未提 AI 渐变，判定为**未覆盖而非废止**，标记待设计方确认。

### 5. A11y：实测对比度 + 待裁决机制

新增 `a11y.md` §5.1 配对表，数值为矩阵**实算**（sRGB 相对亮度，WCAG 2.x），非文档声明值。

| 配对 | 比值 | 处理 |
|---|---|---|
| `#717171` on `#FFFFFF` | 4.88 | ✅ |
| `#717171` on `#F2EFEB`（暖白大底） | **4.26** | 🔴 待裁决 |
| `#717171` on `#F7F5F3`（卡片底） | **4.49** | 🔴 待裁决 |
| Hot / -X% off：`#FF0000` on `#FCDEDE` | **3.17** | 🔴 待裁决 |
| Pre Order：`#39F672` on `#D7FDE3` | **1.30** | ❌ **`Failed`**（几乎不可读，见下） |
| `label-cyan` / `label-green` 压浅底 | 1.83 / 1.44 | ❌ `Failed` |

判定口径分三档：`≥4.5` → `Passed`；`3.0–4.5` **且该配对在封闭 allowlist 里**（spec 直接给出的四组）→ 写进新增的 `Advisories` 字段、不判 `Failed`（色值是设计方给的，矩阵无权改规范去凑对比度）；`<3.0`（**无论出处**）或不在 allowlist 里 → `Failed`。

三条防滥用闸门，防止 `Advisories` 变成降级通道：

1. **`< 3.0` 一律 `Failed`，spec 给的也不行** —— 角标 Pre Order 的 1.30 因此判 `Failed`。3.0 以下不是"略差一点"，是看不见。`BlockingGaps` 写明"需设计方裁决该角标配色"——判 `Failed` 指向的是**规范缺口**，不是开发的实现错误（与「规范与 token 不一致算 PLAUD 缺口」同性质）。
2. **allowlist 是封闭表**（`#717171` 压 `#F2EFEB` / 压 `#F7F5F3`、`#8F53ED` 压 `#F2EFEB`、Hot `#FF0000` on `#FCDEDE`），QA 无权扩充。
3. **每条 Advisory 必须带「已知偏差批准引用」**（设计方 / PM 的确认链接），**引用为空则降级为 `Failed`** —— 否则 Advisory 就成了无人负责的免死金牌。

> 🟢 **这次改动是 A11y 净改善，不是倒退。** 旧 `secondary #7A7A7A` 白底 4.29、暖白底 3.74，**本来就不达标**；旧 `tertiary #A3A3A3` 白底仅 **2.52**。新值 `#717171` 白底 4.88 达标，废止 tertiary 等于拿掉一个长期不合规的档位。

### 6. 运营协作红线进契约（§8.1 / §8.2 新增）

DTC §三 的 11 条进 handoff-schema。**分级处理**：原文标题是「软性，尽量遵守」，本版只把其中**可机械判定、踩了必然出事**的 10 条提升为 🔴 红线，公共文件注释保持 🟡 建议级；并注明这是矩阵侧的收紧，与双方共识冲突时以双周会书面结论为准。

两处刻意保留的限定：

- **「主流程改动必须做成开关」保留了原文的前提「且会修改全站默认配置」** —— 两个条件同时满足才触发。只改单站点存值的主流程改动不受此约束。
- **公共文件的英文注释规范与矩阵原有的「默认不写注释、禁止任务过程注释」直接冲突**，因此限定 allowlist（共享 snippet / 全局 CSS 源 / `theme.liquid` / 共享 JS）、禁写清单（**build 产物**——注释会被下次 build 冲掉；**`templates/*.json`**——JSON 不支持注释，写了直接坏）、各文件类型的合法语法（`.liquid` 用 `{% comment %}` 而不是 `//`，后者会原样输出到 HTML）、ISO 日期、以及"负责人拿不到就停机问，不得填 agent 名"。

locale 条款细化为**分流判定**：固定 UI 文案走 `locales`，运营可配置文案走 schema，两者都不得写死在 Liquid 里。

### 7. QA 侧改动

- 新增 **Step 0 准入门** `QAAdmissionStatus: Accepted | Blocked`，**早于**指纹校验。`Blocked` 时零验证项执行，原样带出 qa-intake 的 `BlockingGaps`
- §5 工件 **19 → 24 字段**：新增 `SubmissionId` / `QAAdmissionStatus` / `QAAdmissionReason` / `StyleHardRuleCheck` / `Advisories`
- QA-Global 新增 §9（DTC §2.1 硬性 10 条的逐条查法）与 §10（§2.2 软性项 → `Advisories`，非阻断）
- 明确 **提测的 8 张断点截图不能顶替 QA 自己的断点回归**；`BreakpointsCovered` 记 `PC` 时须写出实际像素宽度（`PC(1920)`）
- 三个实现 skill 的 `NextRequiredSkill` 由 `plaud-theme-qa` 改为 **`plaud-theme-qa-intake`**

**顺带修掉一处既有契约漂移**：`plaud-theme-qa` 的 SKILL.md 与 `evidence-and-invalidation.md` 长期声称 `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 存在「handoff-schema §5 与 §9.2 规定不一致的枚举缺口」，并要求每次在 `BlockingGaps` 登记该歧义。复核 v0.1.0 原文：**§9.2 枚举表这三项本来就含 `Blocked`**，两处一致——所谓缺口自 v0.1.0 起就是过时描述。已删除该提示，判定纪律（未执行填 `Blocked`，绝不改填 `NotApplicable` / `Passed` / `Failed`）不变。

### 8. 发布前评审加固（14 项）

v0.2.0 的初版方案经外部评审打回一次，以下是被指出并修掉的问题。记录在这里是因为**其中四项能真正绕过门禁**，而它们在静态校验与 evals 里都不会暴露：

| # | 问题 | 修法 |
|---|---|---|
| 1 | QA 的 `ReadyForDelivery: Yes` 判定条件**漏了新增的两道门** —— 只查九个旧字段，硬性 10 条 `Failed` 时仍可能放行 | 判定条件加第 0 条 `QAAdmissionStatus == Accepted`，状态字段九个→十个 |
| 2 | 留了**两条显式绕过链**：用户声明"不走提测流程"直接得 `Accepted`；紧急上线时 release-ops"照做" | 前者改为仍 `Blocked`（照跑检查但不给许可）；后者改为不出发版清单、不给"可以推"的结论，改配一张**最短合规路径**表接住"来不及"这个真实诉求 |
| 3 | **多 ChangeSet 同批发版在当前指纹模型下无法闭环** —— 指纹绑整个工作树，第二块落盘时第一块的 QA 就失效，不可能同时持有 N 个有效结论 | 不改指纹模型，改为要求合并后跑**集成 QA**（新 ChangeSetId、`ModifiedFiles` 取并集），`release-ops` 引用它；工件加 `IntegrationQARef`。彻底解法（绑不可变 commit/tree）留后续版本 |
| 4 | **提测包没有可信绑定** —— QA 只看 `SubmissionPackageStatus`，A 任务的合格包可重放给 B，材料也可在准入后替换 | QA Step 0 改三查：intake 的 `ChangeSetId`/`ChangeSetFingerprint` 与 Implement 工件逐字比对 + 重算 `PackageFingerprint` + 状态 |
| 5 | A11y 三档规则**自相矛盾**（规定 `<3.0` 判 `Failed`，却把 1.30 的 Pre Order 放进 Advisory） | 见上，改封闭 allowlist + 三条闸门 |
| 6 | tertiary 兼容 alias **在 `.use-color-scheme` 下会失效** —— 重绑特异性高于 root alias，只加 alias 不删重绑比不加更难排查 | 重绑改为**过渡期第一步就删**，与加 alias 同一步做完 |
| 7 | 三类新工件**结构表达不了实际状态**：分类是逐条的却放顶层、`Pending` 时仍强制填 `NextRoute`、单个 `AcceptanceStatus` 表达不了部分验收 | `FeedbackItems` 改逐条结构（+`PMDecisionValue`/`NewWorkItemRef`）、`NextRoute` 加 `AwaitPMDecision`、`AcceptanceStatus` 改为 `ReleaseScope` 逐块结构 |
| 8 | orchestrator 台账要求抄录 QA 的 `QAStatus`，**但 §5 工件没有该字段** | 改为抄 Implement 工件（§4）的值，并补 `SubmissionId`/`QAAdmissionStatus`/`TriageId` 台账列 |
| 9 | **QA 打回的路由不统一** —— triage 声称接收 QA 打回，MATRIX 又让 Failed 直接回实现 skill | 分流：**机械失败直接返修**（不进 triage，没有"缺陷还是变更"可判）；只有运营/PM 验收反馈才进 triage |
| 10 | §5 与 §9.2 枚举仍有三处冲突（`ThemeRuntimePreview`/`AdminSchemaSave` 缺 `Failed`、`RegressionMatrix` 缺 `NotApplicable`） | 对齐为四值 |
| 11 | Verify 工件字段数未全量同步（两处仍写旧值）、shared contract 仍写"6 个 skill"、`StageResolved` 只有三值容不下非阶段 skill | 全量同步，`StageResolved` 加 `N/A(NonStage)` |
| 12 | UX 数值仍有旧事实源：两处"全站仅 400"、按钮表有规范里不存在的 `Primary-Light` 且漏 Purple/Green/Cyan；Secondary-Outline 要求用边框变量却没定义 | 全部更新；边框补两种落地方式（复用既有变量或新增 token 再 build，**不得内联硬编码**） |
| 13 | `FixedDimensionCheck` 只 grep `width\|height`，**`block-size: 40px` 可直接绕过** | 覆盖逻辑属性 + 内联 style，并先排除 `min-`/`max-` 前缀避免误报正确写法 |
| 14 | DTC 的**测试集治理**整块缺失；注释格式把原文"年月日时间"缩成日期，"必须英文"的示例却是中文 | 新增 §8.1.1 测试集治理（三条分别落到 qa-intake / release-ops / 外部人工审查，并明写矩阵不拥有测试集本身）；时间精度改 ISO `YYYY-MM-DD HH:MM`，示例换英文 + `{% comment %}` 语法 |

顺带修掉两处自引入的不一致：墓碑流程"零引用后才删重绑"与"立即删重绑"打架；一处 eval 仍写"九个状态字段"。

**评审共跑了三轮**，后两轮又暴露出五个更深的问题，其中三个只有在追问"这套流程真的能执行吗"时才会显形：

| 问题 | 处置 |
|---|---|
| **主指纹命令里还有一处同类吞错** —— `git hash-object` / `stat` 写在 `printf` 的命令替换里，失败时 `printf` 拿到空串照样返回 0，未跟踪文件的内容就从指纹里消失了 | 与 `PackageFingerprint` 同样改为先赋值、判退出码、判空。这是 **v0.1.0 遗留**的漏洞，就藏在那段专门警告这类错误的代码里 |
| **"集成 QA"方案根本跑不通** —— 合并提交后工作树是干净的，`ModifiedFiles = 各块并集` 必然失配；用未提交态过 QA 则一提交 `HEAD` 就变、QA 又失效。绑工作树的模型下**没有稳定对象能从"已验证"走到"实际推送"** | **改为明确声明 v0.2.0 不支持多 ChangeSet 同批发版**，release-ops 遇到多块直接停机、要求逐块串行。彻底解法（指纹改绑不可变 commit / tree 对象）留 v0.3.0 |
| **云端提测材料可以绕过防替换门** —— manifest 只记 URI 时，云文档内容随便换、指纹照样对得上 | 不能内容绑定的材料一律 `Incomplete`（不得带着"已知弱环"拿 `Complete`）；QA 复算时**重新查远端 revision**，不是只比本地 manifest；工件加 `PackageRootRef` 让复算有据可依 |
| **`Blocked` 的原因只能靠聊天上下文猜** | 新增封闭枚举 `QAAdmissionReason`（`Normal` / `ZeroChangeReadOnly` / `PackageIncomplete` / `BindingMismatch` / `MissingArtifact` / `UserWaivedMaterials`），"跑不跑检查"由字段决定而不是自然语言 |
| **部分站点推送失败填 `NotExecuted` 会抹掉线上副作用**，下次有人看到"没推过"就重推一遍 | 新增 `PartiallyExecuted` 与 `PerSitePushResult` 逐站点结果 |

> 🟢 **宁可声明不支持，也不发一套跑不通的流程。** 硬给一条走不通的路，实际效果是使用者发现走不通之后自己找绕过路径——那比明说"这版不支持"危险得多。

> 🔴 **第 4 项和第 13 项值得单独记住**，它们和 v0.1.0 那个指纹 bug 是同一类错误——**在管道 / 命令替换里静默失败，或者匹配模式盖不全等价写法**。`PackageFingerprint` 原本写成 `printf '%s %s' "$f" "$(shasum ...)"`，命令替换里的失败不会让 `printf` 失败，`|| return 1` 永远不触发，指纹退化成只反映文件名列表。写任何校验命令时都要问：这一段失败了，外层真的会知道吗？这个模式盖得住所有等价写法吗？

### 9. 未变

ChangeSet 内容绑定（`ChangeSetId` + `BaseHeadSha` + `ChangeSetFingerprint`，QA 在任何检查之前三者重算比对）、Theme Check baseline 增量双指标、只读任务的 `ReadOnlyProof`、理论影响 vs 实际影响分开报、项目状态存 `memory/`、安装器 legacy 退役 fail-closed。

### 10. 已知局限

- **v0.2.0 不支持多 ChangeSet 同批发版**（见上）。需要一次发多块时只能逐块串行：每块走完 实现 → 提测 → QA → 发版，再做下一块
- 三个新 skill **未做行为评测**，只有各 13–14 条 evals 与静态校验。v0.1.0 的教训：四轮 Codex 评审 + 205 条 eval + 全套静态校验都没抓到的指纹 bug，只有真跑才发现
- UX Spec 有两处待设计方裁决（A11y 🔴 项、AI 渐变与 §2.8 的关系）
- 品牌渐变缺几何参数，无法直接生成 CSS
- Semibold 600 放开后须核字体资源：字体文件、`@font-face 600` 声明、加载策略，缺一会触发浏览器 synthetic bold（字形变形）

---

## v0.1.0 — 2026-08-06（首版）

矩阵的第一个版本。相对于原单 skill `plaud-shopify-theme` 的变化如下。

### 1. 单 skill 拆成 7 个

原来一个 `SKILL.md` 同时承担规范、判定、实现、验收四件事，注意力被稀释：改一个 JS timer
也要读完整套字体字阶表和 Figma 规范。现在按**两轴**拆开 —— 路径轴决定按什么规则实现，
阶段轴决定当前处于评估、实现还是验证。

| Order | Skill | 承担 |
|---:|---|---|
| 0 | `plaud-theme-shared` | 契约：状态机、handoff schema、ChangeSetId、交付权、全路径红线、基线数值 |
| 1 | `plaud-theme-orchestrator` | 编排：路径判定、阶段推进、多块拆分与串并行、工件台账 |
| 2 | `plaud-theme-impact` | Assess |
| 3 | `plaud-theme-dev` | Path A Implement |
| 4 | `plaud-theme-section-build` | Path B Implement |
| 5 | `plaud-theme-ux-migration` | Path C Implement |
| 6 | `plaud-theme-qa` | Verify |

配套的入口分层：三个实现 skill 是正常用户入口，shared / impact / qa 是专家入口。
orchestrator 的**唯一门槛是「这件事必须拆成 ≥2 个能各自独立验收的 ChangeSet」** ——
迁移 wave、多块排序与并行判定、Cross(A+C) 裂块（Cross(B+C) 不裂块，是一个 Path B 的 ChangeSet + QA-C profile）。
「触及共享 snippet / 全局 CSS / token / build 产物」本身不是进入条件，「要走完
Assess → Implement → Verify」本身也不是。**普通 bugfix 不绕 orchestrator。**

红线与基线数值只在 `plaud-theme-shared/references/` 存一份，其它 skill **不得复制数值**，
只得引用 —— 复制会产生多个事实源，spec 一升级必然漂移。

### 2. 引入 ChangeSetId 绑定

新增 `ChangeSetId`（格式 `CS-<YYYYMMDD>-<path><NN>`，`<path>` ∈ A/B/C），把「谁改的」和
「谁验的」焊在一起：

- 实现 skill 交付时**当场**生成三样：`ModifiedFiles`（文件集合）+ `BaseHeadSha` + `ChangeSetFingerprint`（内容指纹）
- `plaud-theme-qa` 在**执行任何检查之前**（Step 1，早于 theme check、早于回归）三者全部重算比对，并回填 `ChangeSetIdMatched` 与 `FingerprintVerifiedAt`
- 任一不符 → `ChangeSetIdMatched: No` + 停机，**不得**「顺便把新改动也验了」
- QA 通过后代码再变，原 QA 自动失效，须重新生成 ID 重跑
- `plaud-theme-orchestrator` 只追踪生命周期记台账，不生成也不改写

> 🔴 **为什么必须绑内容而不能只绑文件名。** 初版只有 `ChangeSetId` + `ModifiedFiles`，存在一条完整的绕过路径：实现 skill 交出工件之后、QA 开始之前，只要继续改**同一批**文件，文件集合仍然一致，校验就判 `Yes`——QA 验的是一批它从未见过的代码。发布前的行为评测复现了这个场景（交付后把 `aria-label="{{ ... | t }}"` 换成硬编码字面量，文件数一个没变），加上指纹后 QA 在 Step 1 即拦下并停机、零验证项执行。
>
> 🔴 **指纹命令对 git 版本敏感。** 早期草稿写的是 `git diff HEAD --find-renames=false`，**git 2.52 起该参数非法**（正确写法 `--no-renames`）。错误走 stderr、管道继续、`shasum` 对残缺输入求值 → 算出一个只反映文件集合、完全不反映内容的常量，指纹退化成摆设、漏洞原样复活。现行命令带 `set -o pipefail` 与各段 `|| return 1`，失败时输出 `FINGERPRINT_FAILED` 强制停机。**这个 bug 是四轮 Codex 评审、205 条 eval、全套静态校验都没抓到、只有真跑才发现的。**

Assess 阶段同步引入 `AssessmentRef`（`ASMT-<YYYYMMDD>-<NN>`），供实现 skill 与 QA 引用。

### 3. QA 独占交付权

> 只有 `plaud-theme-qa` 能输出 `ReadyForDelivery: Yes`。

旧单 skill 里「改完了」「应该可以发了」由实现方自己说，等于没有验收门。现在：

- 实现类 skill 的 `ReadyForDelivery` **恒为 `No`** + `QAStatus: NotRun`
- 禁止终态措辞：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」；允许的说法是「改动已就位，待 QA」
- `Blocked` / `NotRun` **不得**折算为 pass。`NotApplicable` 是**合法终态**，但必须带适用性证据，无证据的按 `Blocked` 处理。`Blocked` = 该验但验不了（风险），`NotApplicable` = 根本不需要验（不是风险），`Failed` = 验了且发现缺陷——三者不可混用，把未执行填成 `Failed` 会让实现 skill 去追不存在的缺陷
- 用户说「不用检查了直接给我」时，正确做法仍是 `No` + `QAStatus: Skipped(UserWaived)`，并说明风险归属
- `plaud-theme-orchestrator` 汇总下辖各 ChangeSet 的 QA 结果，但**汇总不产生交付许可**：`AllChangeSetsDelivered` 是汇总读数，协调工件里根本不出现 `ReadyForDelivery` 字段
- `plaud-theme-orchestrator` 不是阶段 producer：不输出 §3/§4/§5 阶段工件，改用 handoff-schema **§9.1 协调工件**（`ArtifactKind: Coordination` + `OrchestrationId` + `ChangeSetPlan` / `ParallelSafe` / `ChangeSetStatus` / `AllChangeSetsDelivered`）
- **§9.2 封闭枚举**：`QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`（解决了 §1.5 与 §4 的旧不自洽），阶段只有 `Assess` / `Implement` / `Verify`，`ArtifactKind` 仅 orchestrator 可填；出现 `Done` / `Invalidated` / `Partial` 等枚举外取值一律视为契约违规

### 4. Theme Check 改为 baseline 增量判定

旧做法把「`shopify theme check` 全仓零 error」当作通过条件。实测 `shopify-plaud-yidian`
（2026-08-06，CLI 3.92.0）全仓 **3334 errors / 1004 warnings**，其中 `MatchingTranslations`
占 3254 条 —— 那是仓库级的多语言历史状态，与单次改动无关。剔除后仅 80 条。把绝对 pass
当门，等于每个任务永远红着，也就等于没有门。

新判定：

1. 改动**前**（`git stash` 或 worktree@HEAD）跑一次**全仓**记 baseline
2. 改动**后**跑一次**全仓**
3. 分别统计两个指标，**都必须为 0** 才通过：
   - `addedInModifiedFiles` —— 改动文件内新增的 offense，> 0 → `Failed`
   - `addedOutsideModifiedFiles` —— **改动文件之外**新增的 offense，> 0 必须逐条归因：本次改动引起 → `Failed`；基线漂移 → `Blocked`，**不得**判 Passed
4. 顺手修存量 offense 是加分项，但不作为通过条件，也不得扩散到授权范围外的文件

> 🔴 **为什么两次都必须全仓、不能只扫改动文件。** 删除一个 asset / locale key / snippet，offense 会出现在**未被修改的调用方文件**里（`MissingAsset`、`TranslationKeyExists`、`MissingTemplate` 都是这样）。只比对 `ModifiedFiles` 范围会系统性漏掉这类外溢——而它恰恰是删除类改动最典型的破坏方式。
>
> 发布前的行为评测验证了这条：删掉 `assets/animation.js`（`ModifiedFiles` 只有它一个文件），offense 报在 `snippets/scripts-tag.liquid` 上。QA 顺着 `QA-A` 的依赖树回归继续查，发现 `var BlsAnimations` 全仓唯一定义就在被删文件里，而两处调用在**无条件加载**的 `theme.js` 里且无守卫 → `ReferenceError` 会打断 `.finally()` 块、连带打掉 load-more 与商品推荐的懒加载；另有 192 处 `scroll-trigger` 元素会停在 `opacity: 0.01` 且无揭示机制。**上游 `RootCause` 写的「无用的遗留脚本」是事实错误，这个改动会搞坏生产。**

同时明确 `Blocked` 的合法情形（CLI 未装、非 theme root、build 产物缺失、配置依赖缺失、网络不可用），
以及不得越权声明 —— `ThemeCheck: Passed` 只代表静态 lint 无新增 offense，不等于「Shopify 兼容性全部通过」。

### 5. 项目状态移出包外到 `memory/`

模板清单、模块迁移状态、全局已知偏差、ChangeSet 日志是**项目运行时状态**，不是规范。
写在包里会在下次 install 被整包覆盖（安装是先 `rm -rf` 目标 skill 目录再解包），
所以它们迁到项目侧：

- `memory/模板清单.md` — per-template：状态、section 渲染顺序、已迁模块、实例特殊约束
- `memory/模块清单.md` — per-module：后台名、实例数、迁移状态、schema 约束、关键字段
- `memory/全局已知偏差.md` — 跨模板共享的待评估项与已修项
- `memory/changeset-log.md` — ChangeSetId → QA 结果，供追溯与失效判定

缺失时 skill **停机问用户**，不凭空重建（重建出来的清单会与真实迁移进度脱节，导致重复迁移或漏迁）。

### 6. 其它契约级变化

- **理论影响 ≠ 实际影响**：`TheoreticalReferences` 与 `ActualAffectedInstances` 必须分开报；只报「可能影响 N 处」是不合格的 Assess
- **`ReconMode` 三态**：`LegacyImpact`（改存量，默认）/ `IntegrationSurface`（纯新建，查复用面与冲突面，不得为新 section 伪造「模板使用量 N」）/ `InlineLite`（四条件全满足才可跳过 Assess，拿不准就不是）
- **Stop, don't guess** 写成显式停机点清单（handoff-schema §7），并规定停机时必须写清需要用户提供什么，不得输出半成品再附一句「可能需要确认」
- **输出块格式硬性化**：每个**阶段** skill 回复的最后必须是对应阶段的 yaml 契约块，不得改名、不得省略、不得塞进正文段落
- `templates/*.json` 默认只读，需要改存值必须先取得用户授权

### 7. 安装器变化

以旧包的两个 install 脚本为基底，新增：

- **legacy 退役是安装前置条件，安装器 fail closed**：只要任一目标客户端还有单 skill `plaud-shopify-theme`（目录或 symlink），就**中止安装、不写入任何 skill、也不删任何东西**，退出码 2。交互式终端会询问是否退役后继续；非交互（CI / 管道 / `--yes`）必须显式给 `--retire-legacy --yes`；`--keep-legacy` 是明知故犯的逃生口，会并存安装并以退出码 3 结束并打印 UNSUPPORTED 警告。退役后**重新扫描**，仍有残留（校验失败 / 归档已存在 / symlink）一律仍然中止。旧行为「警告一句然后照装不误」会让用户拿到双规范并存的环境，正是拆矩阵要解决的问题本身。
- **退役顺序是归档 → 校验 → 删除**：整目录打成 `<skills-dir>/.plaud-legacy-backup-<timestamp>/plaud-shopify-theme.tar.gz`（Windows `.zip`），校验归档含 `SKILL.md` 且文件数不少于磁盘，才删原目录；校验不过、或归档目标已存在，就原地保留什么都不删。备份采用归档而非目录，是为了让备份里不存在可被客户端扫描发现的目录级 `SKILL.md`（否则路由竞争会从备份里回来）。
- **删除路径的安全边界**：`--target` 解析后必须是最后一段正好为 `skills` 的目录（不是"路径里含 skills"；传客户端根目录时自动补 `skills/` 一层），安装与删除共用同一个校验器。校验器会**解析物理路径**：`skills` 本身或任一祖先是 symlink/junction 时拒绝，避免删除逃逸到别的目录树。删除前再次核验父目录合法、目录名在 legacy 白名单内、且不是 symlink/junction。归档校验是**集合比对**而非计数比对——磁盘上每个文件都必须出现在归档里，归档条目富余不能掩盖缺文件。`--backup-dir` 总会再追加一层带时间戳并按客户端分的子目录，并拒绝 `/`、盘符根、家目录本身、以及被退役 skill 内部的路径；归档目标已存在则跳过该项，绝不覆盖已有备份。PowerShell 侧所有文件系统操作改用 `-LiteralPath`，避免路径里的 `[]` `*` `?` 被当通配符展开。
- **`--dry-run` / `-DryRun`**：打印全部动作，不改动任何安装目标、备份位置或 skill（bash 版本已改用数组，不再落任何临时文件）；检测到 legacy 时**如实显示会中止**并说明退出码 2，不会显示成会成功
- **退出码**：`0` 成功 / `1` 参数配置错误 / `2` 因 legacy 未退役而中止 / `3` 用 `--keep-legacy` 装成了双规范并存（UNSUPPORTED）
- **所有交互提示 fail closed**：EOF 或非交互 host 一律按「否」处理，绝不当作默许。bash 侧原先 `read` 遇 EOF 会在 `set -e` 下静默杀掉脚本（既不报错也不给退出码 2），已改为 `ask_yes_no` 统一处理；PowerShell 侧 `Read-Host` 在 `-NonInteractive` 下会抛终止错误，已用 `Read-YesNo` 包住并显式识别 `-NonInteractive`
- **断链 symlink 也能检测到**：PowerShell 侧改为按名字枚举目录项而非 `Test-Path` 解析（`Test-Path` 对指向不存在目标的 symlink 返回 `$false`，会让旧 skill 溜过闸门、等目标恢复后再变成双规范）
- **跳过客户端明示**：skills 目录不存在而未给 `--create-missing` 时，结尾明确列出被跳过的客户端与路径（旧脚本静默跳过，是「我以为装好了」的主要来源）
- **安装后版本核对**：打印四客户端 `plaud-theme-shared` 的声明版本，并提示声明不等于证据、真正的证据是目录 diff（命令一并打印）
- **不带参数即四客户端**：帮助里明确不建议用 `--clients` 缩小范围（客户端漂移的成因）
- `--help` / `-Help` 完整说明所有开关与退役语义

### 已知遗留

- 旧单 skill 的 zip（`plaud-shopify-theme.zip`）仍在旧包目录里，退役开关不动它 —— 它不在任何 skills 目录中，不参与路由
- 安装器不删除本矩阵**自己**从后续版本里移除的 skill；那仍需手动清理（`--retire-legacy` 只认写死的 legacy 清单）
- 本地无 PowerShell 运行时，`install-windows.ps1` 只做了静态审查（经 Codex 两轮逐行复核），未实跑；首次在 Windows 上使用前建议先跑 `-DryRun -RetireLegacy`
- 退役路径对 symlink 的严格度高于安装路径：删除时要求整条路径不经过任何 symlink/junction（物理路径与字面路径必须相同），否则跳过并提示用户改传解析后的路径。安装路径不做这一硬性要求，以免家目录本身是符号链接时全部客户端被拒
