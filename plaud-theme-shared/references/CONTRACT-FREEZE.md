# v0.3.0 契约冻结件 — 第三波落地的唯一输入

> **状态：冻结。** 本文件是其余九个 skill 落地 v0.3.0 时的**唯一输入**。字段名、取值、函数签名、停机条件以本文件与 `handoff-schema.md` 为准；两者冲突时以 `handoff-schema.md` 为准（它是 canonical，本文件是它的施工视图）。
>
> **本文件不是运行时事实源。** agent 判定时读 `handoff-schema.md`，不读这里。这里只回答"第三波要改什么、改成什么"。

---

## 0. 一句话

📎 ChangeSet 的身份从「工作树状态文本的 SHA-256」改绑「不可变 git tree 对象的 oid」。**`ChangeSetFingerprint` 废止**；新身份是三元组 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`；改动归属由新的 `DeclaredDiffCheck` 承担；QA 在完整 workspace 快照里跑，release 从只含可发布面的物化目录推。

---

## 1. 六个规范函数（签名、输出、环境要求）

全部定义在 `handoff-schema.md` §2.5，**必须逐字原样复制，不得凭记忆敲、不得删注释**。

| 函数 | 参数 | 成功输出（单行） | 用在哪 |
|---|---|---|---|
| `plaud_theme_tree` | 无 | `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest> [<objdir>]`（第 4 段仅当 `PLAUD_TREE_KEEP_OBJECTS=1`） | 实现 skill 交付、QA Step 1 / Step 5、零改动 `ReadOnlyProof` |
| `plaud_changeset_scope` | `<pathlist-file>`（每行一条**逐字**路径） | `<ObjectFormat> <ScopeTreeOid> <ScopeDigest>` | 实现 skill 交付、QA Step 1 |
| `plaud_declared_diff` | `<base-commit-ish> <pathlist-file>` | `<ObjectFormat> <BaseTreeOid> <ThemeTreeOid> DECLARED_DIFF_OK` | QA 的 `DeclaredDiffCheck`、release 的 `ReleaseDeclaredDiffCheck` |
| `plaud_base_theme_tree` | `<commit-ish>` | `<ObjectFormat> <BaseTreeOid>` | orchestrator 的 `IntegrationPlan.IntegrationBaseTreeOid`（**v0.3.0 收尾验收新增**：此处原写 `plaud_theme_tree "<commit>"`，而那是**无参函数**，会静默返回当前工作树的 oid） |
| `plaud_stage_workspace` | `<空目录>`（**必须在仓库外**） | `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>` | QA 的 `StageDirRef`——**所有检查在这里跑** |
| `plaud_stage_verified` | `<空目录>`（**必须在仓库外**） | `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>` | release 的 `ReleaseStageDir`——**只用于推站** |

**必须原样保留的两个环境变量**（不是可选项）：

- `PLAUD_TREE_KEEP_OBJECTS=1` —— 让 `plaud_theme_tree` 把 scratch 对象目录作为第 4 段返回，供 `plaud_stage_verified` 精确接手。**不要用 `ls -dt` 去 `TMPDIR` 里回捞**：并发时会拿到、甚至删掉别的进程的对象目录。
- `PLAUD_TREE_WRITE_TO_REPO=1` —— 显式 opt-in 把对象写进仓库（默认关闭）。**不要拿它当持久化手段**，写进去的是 dangling 对象，会被 `git gc` 回收。

**必须写进每个下游 skill 停机表的三条新环境前提**：

| 前提 | 拿不到时 |
|---|---|
| 可写 `TMPDIR` | `mktemp` 失败 → 函数 fail closed → 相关检查项 `Blocked`，不得填 `Passed` / `NotApplicable` |
| git ≥ 2.25 | `GIT_TOO_OLD` → 同上 |
| **只支持 macOS / Linux** | Windows 上的典型 git 配置（`core.fileMode` 为假、`core.autocrlf` 为真——**具体取值随安装时的选项而定，不要写成「默认必然如此」**）会直接命中两道字节保真门 → 取证不可用，全部身份/归属检查 `Blocked`，理由写「平台不支持 / 字节保真前提不满足」 |

🔴 **`git add` 会执行 hook 与 clean filter。** 函数内部一律带 `-c core.hooksPath=/dev/null -c core.fsmonitor=false`，clean filter 由字节保真门在 `git add` 之前拦下。**一个漏掉 `-c core.hooksPath=/dev/null` 的抄本，后果是执行仓库里的任意脚本**——比 v0.2.x 的「算出假指纹」严重一个量级。三处「原样复制、不要凭记忆敲」的散文（`dev/SKILL.md`、`section-build/SKILL.md`、`ux-migration/SKILL.md`）措辞要相应加重。

---

## 2. 最终字段清单与顺序（封闭集合）

| 工件 | v0.2.3 | **v0.3.0** | 变化 |
|---|---:|---:|---|
| §3 Assess | 15 | **15** | 不变 |
| 📎 §4 Implement | 20 | **22** | −`ChangeSetFingerprint`，+`ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` |
| §5 Verify | 26 | **35** | +`VerificationId` / `QAScope` / `IntegrationOf` / `ObjectFormat` / `VerifiedThemeTreeOid` / `DiffBaseTreeOid` / `DeclaredDiffCheck` / `StageDirRef` / `ReadyForIntegration` |
| §9.1 Coordination | 8 | **9** | +`IntegrationPlan` |
| 📎 §9.1.2 QAIntake | 23 | **26** | −`ChangeSetFingerprint`，+`IntegrationOf` / `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` |
| §9.1.3 FeedbackTriage | 7 | **7** | 不变 |
| §9.1.4 ReleaseOps | 16 | **28** | +`ReleaseQARef` / `ObjectFormat` / `ReleaseSourceTreeOid` / `ReleaseStageDir` / `StagedAt` / `ShopifyCliVersion` / `PushCommand` / `PushCommandCompliance` / `EffectivePayloadManifest` / `RemoteVerifyResult` / `ReleaseDiffBaseCommit` / `ReleaseDeclaredDiffCheck` |

> 🔴 **设计文档给的「§4 20→22、§5 26→30」里，§5 那个数是错的。** 逐字段复核后 §5 是 **35**：设计只列了 4 个新字段，但闭合三层契约还需要 `VerificationId`（集成 QA 的稳定身份，否则 `ReleaseQARef` 无处可指）、`ObjectFormat`（工件自含，release 要拿它比 oid 格式）、`DiffBaseTreeOid` + `DeclaredDiffCheck`（改动归属，DESIGN R6 原本只写在正文里、没有承载字段）。

> **被考虑过、最终没有加的字段：`BaseThemeTreeOid`（§4）。**
> 理由：默认模式下 `plaud_theme_tree` 算完就删 scratch 对象库，「开工前算的那个 oid」**不是可达对象**，事后 `git diff` 根本解析不了——记下来会是个死字段。基准树改为**从 `BaseHeadSha` 的可发布子树现算**（`plaud_declared_diff` 内部完成，两棵树在同一个 scratch 对象库里同时可达）。§5 的 `DiffBaseTreeOid` 记录算出来的那个值。
> 这个改法顺带堵上另一个洞：**开工前就已经躺在工作树里的别人的半成品**，在「开工前 oid」做基准时会被当成基线的一部分而漏掉，在 commit 做基准时会作为无主改动被抓出来（实测）。

**逐工件的 key 顺序**以 `handoff-schema.md` 里的 yaml 模板为准，validator 的 `expectedKeys` **必须逐字、按序**照抄那份模板，不得自己排。

---

## 3. 枚举变更（§9.2）

**新增**

| 字段 | 取值 |
|---|---|
| `QAScope` | `SingleChangeSet` \| `Integration` |
| `ReadyForIntegration` | `Yes` \| `No` \| `N/A(Integration)` |
| `ObjectFormat` | `sha1` \| `sha256` \| `N/A`（仅零改动） |
| `DeclaredDiffCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `PushCommandCompliance` | `Compliant` \| `Violation` |
| `RemoteVerifyResult` | `Matched` \| `Mismatched` \| `Unavailable` \| `N/A(NotExecuted)`（整个字段，仅 `PushResult: NotExecuted`）\| `N/A(NotAttempted)`（逐站点，该站点没推）|
| `ReleaseScope[].QAConclusion` / `.QARef` | `Yes` \| `No` \| `N/A(NotIncluded)`（仅 `IncludedInThisPush: No` 且该块无块 QA 工件）|

**改**

- `PerSitePushResult[].Status` 新增取值 **`Unverified`**。
- `ReadyForDelivery` 的 `Yes`：**两种 `QAScope` 都可取**（见 §4 的 R-BLOCK-3 裁决），但要满足**分两层**的门。
📎 - `IncludedInThisPush`：**删除**「`Yes` 至多一个」的限制。
- `ChangeSetIdMatched`：取值不变，语义随 `QAScope` 变。

📎 **废止**：`ChangeSetFingerprint`（是字段不是枚举，但下游任何地方再出现即违规）。

📎 **`memory/changeset-log.md` 的列**：`ChangeSetFingerprint` 一列 → `ObjectFormat` + `ThemeTreeOid`（前 12 位）+ `ScopeFP`（`ScopeTreeOid` 前 12 位）三列。**旧行不回填**，按旧语义阅读。

---

## 4. 11 条阻断项的裁决

### R-BLOCK-1 集成 QA 取不到提测包 → **裁决：qa-intake 支持集成提测包**

`§9.1.2` 的 `ChangeSetId` 允许取 `N/A(Integration)`，并新增 `IntegrationOf`（非空时列出被集成的 ChangeSetId + 各自 `SubmissionId`）。集成提测材料 = **各块材料的并集 + 集成本身的 ReworkDelta**。
- **producer**：`plaud-theme-qa-intake`。
- **降级取值**：任一块的 `SubmissionId` 缺失 → `SubmissionPackageStatus: Incomplete`，集成 QA 的 `QAAdmissionStatus: Blocked` / `PackageIncomplete`。
- **停机条件**：`ChangeSetId: N/A(Integration)` 而 `IntegrationOf` 为空 → 契约违规，停机。
- **否掉的两条**：「集成 QA 豁免 Step 0」——那是一条无材料的交付通道，与 DTC「缺一不进验收」直接冲突；「复用最后一块的提测包」——明显错误。

### R-BLOCK-2 `AllChangeSetsDelivered` 永远取不到 Yes → **裁决：改定义**

`Yes` = 全部下辖 ChangeSet 的 **`ReadyForIntegration: Yes`**，**且**存在一份集成 QA 工件且其 `ReadyForDelivery: Yes`。canonical §9.1 已改；orchestrator 侧照抄。

### R-BLOCK-3 单块拿不到 `ReadyForDelivery` → **裁决：两种 QAScope 都可给 Yes，门分两层落**

不写「只有集成 QA 能给 Yes」——那会要求每一个普通 bugfix 都多跑一次全量集成 QA（orchestrator 的进入门槛本来就是「≥2 个 ChangeSet」，单块明确不走它）。

真正的不变量是「本次 QA 验过的 tree 就是 release 要推的 tree，且树里没有它没验过的东西」。

🔴 **它必须分两层落，不能全塞进 QA 的 `ReadyForDelivery`**——QA 出工件时 release 工件还不存在，写成一层就是「release 要 QA 的 Yes、QA 又要 release 的字段」的流程死循环（Codex 二轮指出，已改）：

**第一层 · QA 侧**（`ReadyForDelivery: Yes` 的全部条件，都是 QA 当场可验证的）：`QAAdmissionStatus: Accepted` + `ChangeSetIdMatched: Yes` + `DeclaredDiffCheck: Passed` + §5 全部检查项 `Passed` 或带证据的 `NotApplicable`。
**第二层 · release 侧**（发布门，不满足即停机不发版）：`ReleaseSourceTreeOid == VerifiedThemeTreeOid`（同 `ObjectFormat`）+ `ReleaseDeclaredDiffCheck: Passed` + `PushCommandCompliance: Compliant`（含 `--path <ReleaseStageDir>` 逐字相等）+ 推站紧前再复算一次。

多块合并后没有任何单块 QA 持有那棵合并树的 oid → 第二层第 1 条**结构上必然**要求集成 QA。
`ReadyForDelivery: Yes` 的语义因此是「**这棵被验过的 tree 有资格被后续 release 使用**」，不是「这次发布一定合法」。**不要在下游文档里把它写成「可以发了」。**

**连带**：`ux-migration` 的「完成态需 QA 背书」六处复述点，判据从「该块 QA 的 `ReadyForDelivery: Yes`」改为「该块 QA 的 `ReadyForIntegration: Yes` **且** 覆盖它的那份 `ReadyForDelivery: Yes` 工件存在」。

### R-BLOCK-4 没有「集成者」角色 → **裁决：矩阵不做 merge，`Integrator` 填人**

- `IntegrationPlan.Integrator` **填人**（用户 / 具体 owner），不填 skill 名。
- 矩阵只做**校验**：集成完成后由 `plaud-theme-qa` 以 `QAScope: Integration` 取证，`DeclaredDiffCheck` 核对「最终 diff 恰好等于各块声明并集」。
- **停机条件**：无人认领集成 → orchestrator 停机要授权，不得自行 merge，不得假装集成已完成。
- **consumer**：`IntegrationPlan` 的 consumer 是**人 + `plaud-theme-qa`**（后者读 `IntegrationBaseCommit` 做 diff 基准、读 `MemberChangeSets` 填 `IntegrationOf`）。它不是孤儿字段。

### R-BLOCK-5 `RemoteVerifyResult: Unavailable` 无映射 → **裁决：新增 `Unverified`**

`Matched`→`Succeeded` ／ `Mismatched`→`Failed` ／ `Unavailable`→**`Unverified`**。
`Unverified` **不得**折算为 `Succeeded`（复核不动 ≠ 推成功），也不是 `NotAttempted`（推已经发生了）。`PushResult: Executed` 仅当**每个**站点都是 `Succeeded`。
🔴 **补一条集合约束**（Codex 二轮指出）：`TargetSites` / `RemoteVerifyResult` / `PerSitePushResult` 三者必须**逐站点一一对应、无重复、且 `TargetSites` 非空**——空站点集合会让「每个站点都成功」在真空里成立，`PushResult: Executed` 就成了假读数。

### R-BLOCK-6 `ReleaseScope[].QAConclusion` 映射断了 → **裁决：逐块抄 `ReadyForIntegration`**

`ReleaseScope[]` 拆成两个子键：`QAConclusion` 抄该块 QA 工件的 `ReadyForIntegration`（`Yes` / `No`），**新增 `QARef`** 记该 QA 工件的 `VerificationId` + 出处。**恒定一个来源，不分场景**——单块直发时该块 QA 同样要给 `ReadyForIntegration: Yes`。
🔴 `QARef` 是必需的（Codex 二轮指出）：只有一个标量 `QAConclusion` 时，填 `Yes` 也无法机械证明它来自哪份 QA。
本次的**交付许可**不在 `ReleaseScope` 里，在顶层的 `ReleaseQARef`。
> 字段名用 `ReleaseQARef` 而不是 `IntegrationQARef`：单块直发时它指的不是集成工件。v0.2.2 曾因无 producer 清掉过一个 `IntegrationQARef`，这次 producer 是 `plaud-theme-release-ops`（填），指向 `plaud-theme-qa` 产出的工件（`VerificationId`），闭合。

### R-BLOCK-7 `IncludedInThisPush: No` 的块怎么剔除 → **裁决：只有一条出路，且它可检测**

**明说做不到的部分**：`plaud_stage_verified` 物化的是一整棵 `ThemeTreeOid`，**没有「减去某块」的能力**（与「不能从混合工作树还原单块快照」是同一个限制）。**「停机」不是物化方案**，所以要给出唯一的物化出路：

> 该块的改动**必须从发布源树里撤掉**（由 §R-BLOCK-4 的集成者执行，撤法是 revert / stash / 换 base，属于人的动作），撤完之后**重新取证**（新的 `ThemeTreeOid`）并**重跑集成 QA**。
> 撤不掉、或不愿撤 → 该块只能改判为 `IncludedInThisPush: Yes` 并补齐它的验收，否则**本次 cohort 不能发**。

**承载字段**（Codex 二轮指出「只有正文要求、没有字段」，已补）：§9.1.4 新增 **`ReleaseDeclaredDiffCheck`** 与 **`ReleaseDiffBaseCommit`**。release 前以「`IncludedInThisPush: Yes` 的块的声明并集」为期望集合重跑一次 `plaud_declared_diff`，`No` 块的改动只要还在树里就会被判成 `DECLARED_DIFF_ORPHAN`。

**残余风险如实记**：这把「同树并行 + 部分发版」的收益削掉一半。新模型没有让这件事变便宜，只是让它**变得可检测**。

### R-BLOCK-8 `IntegrationBase` 不能用 `BaseHeadSha` 表达 → **裁决：记两个，判 tree oid，并加等式**

`IntegrationPlan` 同时记：
- `IntegrationBaseCommit`（commit-ish，**必须可解析**）——它只是让基准对象可达的**手段**；
- `IntegrationBaseTreeOid` + 配套 `ObjectFormat`——**判据用的是它**。

🔴 **机械等式**（Codex 二轮指出「只记不比 = 只是文档声明」，已补）：§5 的 `IntegrationOf.BaseTreeOid` 逐字抄 `IntegrationPlan.IntegrationBaseTreeOid`，且**必须与本工件的 `DiffBaseTreeOid` 逐字相等**；不等即 `DeclaredDiffCheck: Blocked`。少了这道等式，可以记一个漂亮的 `IntegrationBaseTreeOid`、却拿另一个 commit 去算 diff。

### R-BLOCK-9 `BaseHeadSha` 必填性两套口径 → **裁决：required 且必须可解析**

一条口径，写死在 canonical §2.1 / §4：

> `BaseHeadSha` **不再是失配判据**（不与当前 HEAD 比对，期间 commit / rebase / checkout 不再让 ChangeSet 失效），但**仍然必填、且必须是可解析的 commit-ish**。
> 🔴 **它是「开工前（实施第一个字节之前）捕获的 baseline commit」，不是「交付工件时的 HEAD」**（Codex 二轮指出的时间语义冲突，已改）：写成后者时，实现者只要先 commit 再交工件，基准就已经含本次改动 → 所有声明路径落进 `DECLARED_DIFF_UNCHANGED` → QA 恒阻断，而这与「主题改动 commit 不再让身份失效」直接矛盾。
> **本条只适用于有改动的 ChangeSet。** 零改动只读任务 `BaseHeadSha` 填 `N/A`，只读通道不做 `DeclaredDiffCheck`。
> 缺失或不可解析时：`DeclaredDiffCheck: Blocked`、theme check baseline 物化 `Blocked`、存量偏差举证 `Blocked`。
> **不是 `Advisories`，不是 `N/A`。** `Blocked` 才是「该验但验不了」的正确取值，而 `Blocked` 不得折算为 pass → 该轮拿不到交付许可。

四条硬依赖它可解析的举证链（第三波逐条核对）：`qa/references/qa-global.md` 的两处 `git show <BaseHeadSha>:<file>`、`ux-migration/references/hard-rules.md` 的豁免举证、`feedback-triage/references/classification-rules.md` 的 `RequirementEvolution` 举证、`qa` Step 3 的 theme check baseline。

### R-FACT-1 物化目录跑不了完整 QA → **裁决：两层物化，两个函数都已落地**

**这条已经从「设计已定、原型只实现了后者」变成两层都有可跑函数**：

| 函数 | 产出字段 | 内容 | 谁用 |
|---|---|---|---|
| `plaud_stage_workspace` | §5 `StageDirRef` | 整棵工作树的拷贝（除 `.git`）：含 `.theme-check.yml`、build 源、lockfile、`memory/` | **QA 在这里跑**所有检查 |
| `plaud_stage_verified` | §9.1.4 `ReleaseStageDir` | 只含可发布面 | **只用于推站** |

两者的 `ThemeTreeOid` 必须相同，不同即停机。
🔴 **第三波不得写「Step 3/4 的检查在 release 物化目录里跑」**——那是「要求在跑不了 theme check 的目录里跑 theme check」。写 `StageDirRef`（workspace 快照）。
**代价如实记**：workspace 快照是整棵工作树的拷贝，会包含 `node_modules` 之类的大目录。想省时间就先清理工作树，**不要靠缩小拷贝范围**——缩了就跑不了它本来要跑的检查。

### R-FACT-A 「两个独立块 QA」不是无条件的 → **裁决：并行语义必须带条件**

块 QA 可并行**当且仅当**各块的 workspace 快照被物化时，**其它块的改动尚未落进同一棵树**（典型是各块在独立 worktree 里开发，或同树但按落盘时序抢先物化）。
A、B 已经同时落在同一棵活工作树上之后再物化，两份快照**都是 A+B**——那不是两次块 QA，而是一次集成 QA 的两个副本，必须按集成 QA 处理。
**这条不用靠自觉**：`DeclaredDiffCheck` 会把 B 的改动判成 A 的 `DECLARED_DIFF_ORPHAN` 并停机。

🔴 **第三波在 orchestrator / qa 里复述并行语义时，不得写成无条件的。**

---

## 5. 孤儿字段的处置（明写"只记不判"）

| 字段 | 处置 |
|---|---|
| `StagedAt` | **只记不判**（审计留痕），canonical 已明写。不是判据，不构成停机条件 |
| `EffectivePayloadManifest` | **只记不判**，是给人看的推送凭证。判定由 `RemoteVerifyResult` 承担 |
| `IntegrationPlan` | consumer 是**人 + `plaud-theme-qa`**（读 `IntegrationBaseCommit` / `MemberChangeSets`），不是孤儿 |
| `ThemeTreeDigest` | **不进任何工件**。它是函数输出的第 3 段，只用于人读 diff 与跨 object-format 防误判，**不提供抗碰撞** |

---

## 6. 每个下游 skill 要改什么

> 行号会漂，**一律用 grep 锚点定位**，不要照抄任何行号。

### 6.1 `plaud-theme-qa`（改动最大）

| 位置 | 改成什么 |
|---|---|
| 📎 Step 0 准入 | 比对项 `ChangeSetFingerprint` → **三元组逐字比**；新增：`QAScope: Integration` 时 `SubmissionId` 指向**集成提测包** |
| Step 1 | 三重绑定 → **四重**：文件集合 + `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`。**`BaseHeadSha` 从判据里移除**（不一致不再停机，只记；但缺失/不可解析 → 相关项 `Blocked`）。通过后**立刻 `plaud_stage_workspace` 物化**，并跑 `plaud_declared_diff` 填 `DeclaredDiffCheck` |
| 📎 Step 2 | 义务登记改为「收尾重算 `ThemeTreeOid`」；**删掉 assume-unchanged 那条补充门**（空白临时索引下索引标志不生效，已实测）；submodule 那条改为「由 `GITLINK_IN_*` 自动挡，QA 不再手查」 |
| Step 3 / 4 | 所有检查在 **`StageDirRef`**（workspace 快照）里跑。theme check 的 baseline worktree 改为从 `BaseHeadSha` 物化（`git archive <BaseHeadSha>^{tree}`），不再 `git worktree add` |
| 📎 Step 5 | 重算 `ThemeTreeOid` 与 Step 1 比对；判 `ReadyForIntegration`；按 §2.11 三道门判 `ReadyForDelivery`。**删掉「写完 log 不要 commit `memory/`」** |
| §5 工件 | 26 → **35** key，顺序照 canonical。`IntegrationOf` 是**映射**（`PlanRef` / `BaseTreeOid` / `Members[]`），不是裸列表；`BaseTreeOid` 必须与 `DiffBaseTreeOid` 逐字相等，不等即 `DeclaredDiffCheck: Blocked` |
| `references/evidence-and-invalidation.md` | §2.1 算法引用照改；§2.2 两次 → **三次**（物化前 / 物化回环 / 收尾）；§2.3 见上；**§2.5 `text=auto` / CRLF 的旧口径「判定不受影响，注明即可」必须删掉**（新模型里它是 fail-closed 门）；**§2.6「这是仓库状态指纹，不是纯内容指纹」整节删除**，换成「这是**可发布内容**指纹」+ 新的边界（字节保真门）；§3 changeset-log 表头改三列 |
| `references/qa-global.md` | 检查在 workspace 快照里跑；两处 `git show <BaseHeadSha>:<file>` 保留（`BaseHeadSha` 仍必填可解析） |
| `references/theme-check-gate.md` | §5「临时文件放 scratchpad」的**理由**要更新（现在临时文件不在可发布面就不影响指纹，但仍不该进仓库）；baseline 改物化 |
| `matrix-contract.md` | 消费字段 20 → **22**；新增集成 QA 工件的消费 |
| description | 加「集成 QA」触发语；**没有 `IntegrationPlan` 的「集成 QA」请求先回 orchestrator** |

### 6.2 `plaud-theme-orchestrator`

📎 - 顶部红框「同树一律串行」→ **同树可并行 Implement**（条件：`ModifiedFiles` 两两不重叠、不共享 build 产物、不改同一 token / locale 键）；**QA 有条件并行**（见 R-FACT-A，不得写成无条件）。
- 「顺序原则」第 3 条改回「可以并行」+ 前提；第 4 条「每块 Implement 完立刻进 Verify」改写为「攒批现在合法，但集成 QA 必须做」。
- `ParallelSafe` 语义扩大（canonical 已给注释原文，三处复述点照抄）。
- **新增 `IntegrationPlan`**（**6 个子字段**，见 canonical §9.1；`IntegrationResultTreeOid` 是第 6 个，由 `Integrator` 在集成落盘后提供、orchestrator 更新同一份工件写入，规划期不得预填任何值）。
- `AllChangeSetsDelivered` 改定义（R-BLOCK-2）。
- **新增停机条件**：无人认领集成 → 停机要授权。
- `IntegrationPlan: N/A(SingleChangeSet)` **不设这个取值**——orchestrator 不接单块任务，设了会反过来诱导单块任务进 orchestrator。
- 派活时明写「每块生成 `ChangeSetId` 后**立刻**在 `memory/changeset-log.md` 占位」——同树并行时两个 agent 同时写同一个日志文件是新的竞态，占位是唯一防线。
📎 - 🔴 **必须 grep 到尽**：`grep -rn --include='*.md' --include='*.json' -e '一律串行' -e '逐块串行' -e 'ParallelSafe' -e '独立 worktree' -e '完整 20 字段' -e 'ChangeSetFingerprint' .`

### 6.3 `plaud-theme-release-ops`

- §9.1.4 工件 16 → **28** key（与本文件 §2 摘要表和 canonical §9.1.4 一致；此处原写 26，是第三轮复核抓到的内部矛盾——第三波读的正是本节，照 26 会建出错的 validator）。
📎 - 删除「v0.2.3 只支持单块发布 / `IncludedInThisPush: Yes` 至多一个」（`SKILL.md` 与 `references/release-checklist.md` 各查一遍）。
- 新增推站流程：`plaud_stage_verified` 物化 → **执行 push 命令紧前再复算一次**并与 `ReleaseSourceTreeOid` 比对 → 从物化目录推。
- `PushCommandCompliance`：`--only` / `--ignore` → `Violation` + 停机；`--nodelete` 不判 Violation 但必须出现在 `PushCommand` 并在正文说明影响。
- 按 `TargetSites` 分 cohort；三者集合约束见 R-BLOCK-5。
- **新增 `ReleaseDiffBaseCommit` + `ReleaseDeclaredDiffCheck`**：推站前以「`IncludedInThisPush: Yes` 的块的声明并集」为期望集合重跑一次 `plaud_declared_diff`。
- `PushCommand` 必须逐字包含 `--path <ReleaseStageDir>`，否则 `PushCommandCompliance: Violation`（命令里没有 `--only` / `--ignore` 也可能推的是别处那棵树）。
- `RemoteVerifyResult` → `PerSitePushResult[].Status` 的三条映射（R-BLOCK-5）。
- **没有集成 QA 的多块发版请求**：release-ops **停机并指出缺什么**，不得自行吸收成 QA 或规划任务。

### 6.4 三个实现 skill（`dev` / `section-build` / `ux-migration`）

📎 - §4 工件 20 → **22** key；产出三元组；`ChangeSetFingerprint` 全部删除。
- `ModifiedFiles` 改为 `- "<逐字路径>": <一句话改动>` 形态（路径用双引号包住，机器可解析）。
- `dev` 的零改动通道 `ReadOnlyProof` 改为**两次 `plaud_theme_tree`**（`ObjectFormat` + `ThemeTreeOid` 必须相等），并写明 v0.3.0 的语义收窄：只覆盖可发布面。
📎 - `section-build` 的 `sb_worktree_set()` **整个换掉**：开工前 `plaud_theme_tree`，收尾 `plaud_declared_diff` —— `mktemp` + `comm` + 两次落盘的守卫链、`BASELINE_FAILED` / `AFTER_FAILED` 两个死守卫全部消失。
  🔴 **但要保留那条「baseline 已脏且与本任务路径重叠 → 停机」的规则**——它解决的是「改动归属」，`DeclaredDiffCheck` 只能证明「树里有什么」，同样答不了「是谁改的」（它只是把无主改动**抓出来**，抓出来之后还是要人判）。
- `ux-migration` 的迁移日志时机：**`memory/` commit 限制解除**（v0.3.0 起 commit 不影响身份）；完成态判据按 R-BLOCK-3 的连带条款改。
- 三处「原样复制 §2 函数、不要凭记忆敲」的散文**加重措辞**（R-FACT-4）。

### 6.5 `plaud-theme-qa-intake`

- §9.1.2 工件 23 → **26** key；支持集成提测包（R-BLOCK-1）。
📎 - Step 0 消费清单：`ChangeSetFingerprint` → 三元组。
- `PackageFingerprint` **算法完全不变**（它 hash 的是提测材料目录，与 git 无关；`PLAUD_PACKAGE_ROOT` 根目录守卫保留）。
- 「提测材料不得写进主题仓库」的**理由**更新：现在只有落进**可发布目录**才会改 `ThemeTreeOid`；**真正的门仍是 Step 1 的三条命令**（常规位置 / ignored 位置 / `memory/` 全量），必须逐条跑——这条 v0.2.3 的更正不受新模型影响。

### 6.6 `plaud-theme-impact` / `plaud-theme-feedback-triage`

- `impact`：`memory/` 盲区核对的**语义**从「指纹盲区」改为「不在可发布面 = 不会上线；若真会上线说明目录放错了」。两条核对命令**保留**。
- `feedback-triage`：字段名同步；`RequirementEvolution` 举证链依赖 `BaseHeadSha` 可解析（R-BLOCK-9）。

### 6.7 包级文件（第三波第 3 步）

`MATRIX.md` / `README.md` / `AGENTS.md`：版本串、机制描述、**删除「不支持多块同批发版」的表述**、加 macOS/Linux only 与 `TMPDIR` / git ≥ 2.25 前提。
`install-windows.ps1`：加一句「v0.3.0 的指纹取证不支持 Windows」。

---

## 7. eval 改动

### 7.1 必须删除的 6 条 `forbidden`（已确认，逐条给理由）

| eval | forbidden 串 | 为什么必须删 |
|---|---|---|
| `orch-09` | `"disjoint 就可以在同一棵树里并行"` | v0.3.0 下这对 **Implement 阶段就是正确答案**。它对 QA 阶段仍不成立，但那是**条件**问题，不能用一条字符串黑名单表达 → 改用 assertions 要求答案里同时出现阶段限定 |
| `qa-46` | `ChangeSetIdMatched: Yes` | 见 7.2，该 eval 整条反转，`Yes` 变成正确答案 |
| `qa-46` | `ReadyForDelivery: Yes` | 同上 |
| release `2` | `"我构造了只含已验收块的发布树"` | v0.3.0 下这是 R-BLOCK-7 的**唯一合法出路**的正确描述 |
| release `2` | `"我对该树重跑了集成 QA"` | 同上——重跑集成 QA 正是要求的动作 |
| release `2` | `"建议等它验收完一起发"` | 多块同批发版已支持，这条建议不再是错的 |

🔴 改完 `forbidden` **必须立刻重跑自伤扫描**（被自身 `expected` / `prompt` 命中；是合法枚举值的真前缀），不是收尾时跑一次。这一轮大量出现 `可以并行` / `必须串行` / `ReadyForDelivery: Yes` / `ReadyForIntegration: Yes` 这类串，而**并行语义是反转的**，最容易写出自伤条目。动作类一律用第一人称承诺句，字段类用赋值形态，**能用 assertions 表达的一律不进 forbidden**。

### 7.2 三条整条反转的 eval —— **已在新模型上实测确认，可以反转**

| eval | 原意 | 新模型实测 | 结论 |
|---|---|---|---|
| `qa-46` | commit `memory/` 会绕过排除、让 QA 结论失效 | 改 `memory/` → `ThemeTreeOid` SAME；`git add memory/` → SAME；**`git commit memory/` → SAME**；同时该块的 `ChangeSetScopeFingerprint` 也 SAME | ✅ 可反转。**它在 v0.2.x 是一道真门**（payload 第一行是 `git rev-parse HEAD`），v0.3.0 的 payload 里根本没有 HEAD，所以它是**过时门**不是被删掉的真门 |
| `qa-23` | `git add` / 仓库根 scratch 文件导致失效 | `git add`（内容不变）→ SAME；`git reset` → SAME；仓库根 `tc-diff.js` → SAME | ✅ 可反转 |
| 📎 `qa-30` | assume-unchanged 需要补充门 | `git update-index --assume-unchanged` 后改内容 → **仍 CHANGED**；`--skip-worktree` 同样 → **仍 CHANGED** | ✅ 可反转。原因是新模型用的是**空白临时索引**，用户 index 上的标志不生效 |

### 7.3 validator

四条 `yaml-block-exact-keys` validator（dev / section-build / ux / qa）的 `expectedKeys` 按新字段数改：**§4 = 22、§5 = 35**。
orchestrator（9）、qa-intake（26）两条同改；release-ops 需要**新建**一条（28）。
**这一段是第三波的施工要求，第一波（本波）没有改任何下游 skill 的 eval。**
**不新增「集成 QA validator」**——集成 QA 与块 QA 共用同一套 35 key 封闭集，靠 `QAScope` 判别。两套近似模板必然漂移，validator 也要维护两份；「独立工件」指的是**工件实例与身份独立**（`VerificationId` / `ChangeSetId: N/A(Integration)` / 非空 `IntegrationOf`），不是 key 集合必须不同。
改完 eval JSON 必须 `json.load` 通过。

---

## 8. 落地时的实测证据（可复跑）

契约里写的每一段 shell 都在 bash 3.2 与 zsh 下实跑过，**188 条断言全通过，两家输出逐字节一致**。覆盖：正常改动 / 多块 disjoint 并行 / `git add` / `git reset` / commit `memory/` / 主题改动 commit / 未跟踪文件 / 权限 / 删除 / 大小写改名 / symlink（未跟踪、已跟踪、指向 `memory/`、指向目录、指向仓库外、5 千量级）/ 嵌套 git repo / clean filter 五个来源 / `text` `eol` `ident` `working-tree-encoding` `export-ignore` `export-subst` / `core.autocrlf` 全部别名与**裸键** / `core.fileMode` 全部假值与**空值** / `GIT_CONFIG_*` 注入 / 含换行、空格、TAB、尾空格、glob 元字符的路径 / 非默认 object format（sha256）/ 多 locale / `precomposeUnicode` / 8 路并发物化 / 诱饵 scratch 目录 / 以及注入恒失败的 `git` `sort` `mktemp` `shasum` `tr` `wc` `awk` `sed` `cut` `grep` `diff` `comm`。

**落地过程中新发现并修掉的两个 fail-open**（设计原型里都有）：

1. **`core.autocrlf` 裸键**。`.git/config` 里写一个没有等号的 `autocrlf`，git 语义上当 **true**（实测 CRLF 文件进 tree 时真的被转成 LF：工作树 `a\r\nb\r\n`，blob `a\nb\n`），而 `git config --get core.autocrlf` 打印**空串且 rc=0**。原型把空串当「未设置」→ 放行。修法：`_plaud_cfg_raw` 返回三态 `UNSET` / `SET:<值>` / 查询失败。**不能用 `--type=bool` 替代**——合法取值 `input` 会 `fatal`（rc=128）。
2. **`core.fileMode` 空值**。`core.fileMode=`（有等号、值为空）被 git 归一为 **false**（实测：0755 的文件被记成 100644），而**裸键** `fileMode` 归一为 **true**。两者 `--get` 下都是空串。修法：`core.fileMode` 必须走 `_plaud_cfg_bool`（`--type=bool`），**不能与 `core.autocrlf` 共用同一个读法**。

---

## 9. 已知残余风险（不要在下游文档里承诺它们已解决）

1. **物化目录不是真不可变。** 推站前复算能抓到篡改，但同权限进程在 CLI 逐文件读取期间改目录，矩阵挡不住——**不创造原子性**。
2. **多站点 push 不是原子的。** 远端校验失败时远端可能已经部分改变，`PushResult` 不得填 `NotExecuted`。
3. **sha1 仓库只适合非对抗威胁模型。** `ThemeTreeDigest` 不提供抗碰撞。要更强就把仓库迁到 sha256。
4. **`ThemeTreeOid` ≠ Shopify 实际上传集合。** CLI 版本、文件投影、`.shopifyignore`、`--nodelete`、远端现状都是额外输入。
5. **disjoint 不保证可合并。** 共享 token / locale key / schema 值 / 生成产物 / 构建输入都可能逻辑冲突——那是集成 QA 查的。
6. **同树混合后无法恢复 A-only 快照。**
7. **集成 QA 是每个 release cohort 的串行屏障**，消不掉。最终树、集成计划、测试环境或有效 payload 变了都要重跑。
8. **`IncludedInThisPush: No` 的块**只能撤销重验，收益被削一半（R-BLOCK-7）。
9. **`core.precomposeUnicode`** 在本机实测翻转不影响指纹（文件系统已归一），但它是新模型的一个**外部输入**、不在任何门的覆盖范围内。跨文件系统（如 Linux ext4 上的 NFD 路径）尚未回归，**不要声称已覆盖**。
10. **Windows 不支持取证。**
11. **QA 的 `ReadyForDelivery` 不替代**运营验收、站点清单二次确认与推站授权（canonical §1.1）。
12. **workspace 快照不是原子/不可变快照。** 只有可发布面有回环复算背书；非发布面（`.theme-check.yml` / lockfile / build 源 / `memory/`）拷贝期间可以变化，非发布 symlink 按 `cp -RP` 保留因而仍指向快照外的可变对象，非发布目录下的嵌套 `.git` 会被一起拷进去，快照建成后目录仍可被改。
13. **`DeclaredDiffCheck` 判的是可发布路径集合，不是逐项四元组。** raw 记录只用于格式守卫；「路径没变但 mode / 内容变了」由 `ChangeSetScopeFingerprint` 承担。
14. **非可发布面的改动不改变 `ThemeTreeOid`，但会改变 QA / build 结果。** build 源、`.theme-check.yml`、lockfile 都在归属核对之外。
15. **QA 工件本身没有不可变引用或 digest。** `ReleaseQARef` 指向 `VerificationId`，工件内容若被事后改写，引用仍然"有效"。这条本波没有解法，如实记。
16. **`EffectivePayloadManifest` 只记不判**，不能被描述成对实际上传集合的机械保证。


---

## 10. 收尾验收（v0.3.0 第四步）对本冻结件的四处修正

第三波交付后的**跨 skill 一致性验收**发现四处冻结件与 canonical 都需要改。这四条已同步落进 `handoff-schema.md` 与相应下游 skill；**本节是冻结件的正式增补，读到本文件旧段落时以本节为准**。

| # | 问题 | 会让 agent 做出的错误动作 | 处置 |
|---|---|---|---|
| 1 | `IntegrationBaseTreeOid` 的构造命令写成 `$(plaud_theme_tree "<IntegrationBaseCommit>")`，而 `plaud_theme_tree` 是**无参函数**（函数体里没有 `$1`） | 参数被静默丢弃，返回的是**当前工作树**的 oid 却被命名成「基准树 oid」。§5 的三方等式恒不成立 → `DeclaredDiffCheck` 恒 `Blocked` → **多块集成结构性死锁**，而两侧都"算得出值"、看不出错 | §2.5 新增第 6 支函数 **`plaud_base_theme_tree <commit-ish>`**（与 `plaud_declared_diff` 的 base 半段共用同一支内部实现 `_plaud_base_tree_build`，两者必然同口径）。orchestrator 四处调用点全部改用它 |
| 2 | `IntegrationPlan.IntegrationResultTreeOid`（集成结果树）只写在 canonical，三个下游各持一套互斥模型：orchestrator 只有 5 个子字段、qa-intake 自己现算、qa 写着"这一对没有 producer、恒 `Blocked`" | 集成 QA 要么恒 `Blocked` 拿不到交付许可（死锁），要么由材料装配方自证——集成者事后改了树再叫提测照样得到一份自洽的包 | 统一往 canonical 收敛：producer = `Integrator`（人）→ qa-intake **原样透传** → QA **独立重算比对**。并补 `IntegrationPlan` 的**两个时点**规则（规划期只写前 5 项，第 6 项在集成落盘后由集成者交值、orchestrator 更新同一份工件补上；只有已补第 6 项的那一版可被消费） |
| 3 | `plaud-theme-shared/SKILL.md`「完成态必须由 QA 背书」仍是 v0.2.3 判据：「`changeset-log` 中该 `ChangeSetId` 的 `ReadyForDelivery: Yes`」 | ① `changeset-log` 根本没有这一列，是条查不到的判据；② 多块批次里块 QA 的 `ReadyForDelivery` 恒 `No`，照它判**没有任何模块能被标成 `已迁`** —— 正是 R-BLOCK-3 要解决的死锁。`ux-migration` 全套 11 处已改，只有 shared（order 0，所有人都读）没改 | shared 侧收敛到 R-BLOCK-3 的连带条款：该块 `ReadyForIntegration: Yes` **且**存在覆盖它的 `ReadyForDelivery: Yes` 工件；并写明第 3 条比的是该块自己的 Scope 指纹，不是当前整树的 `ThemeTreeOid` |
| 4 | `RemoteVerifyResult` 与 `ReleaseScope[].QAConclusion` / `.QARef` 的**诚实降级取值**（`N/A(NotExecuted)` / `N/A(NotAttempted)` / `N/A(NotIncluded)`）只在 release-ops 侧写着，canonical §9.1.4 与 §9.2 封闭枚举都没收录 | 按包自己的规矩「阶段契约字段出现枚举外的值一律视为违规」，**每一份推前发版清单都是违规工件**；反过来若照枚举填，就只能给没推过的站点编一个推后语义的值（`Unavailable` → 被映射成 `Unverified`「推已经发生了」），凭空捏造一次没发生的推送 | 三个取值连同适用条件一起收进 canonical §9.1.4 注释与 §9.2 枚举表 |

> 这四条的共同形态与本文件 §8 记的两个 fail-open 是同一族：**两侧都"算得出值"、都能出一份自洽的工件，错误不在任何一处报错，只在跨 skill 对齐时才暴露**。机械核对脚本查不到它们——它查的是字段在不在、key 数对不对，查不了「这个命令真的能产出这个值吗」。
