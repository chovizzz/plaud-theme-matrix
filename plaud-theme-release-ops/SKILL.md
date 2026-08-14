---
name: plaud-theme-release-ops
description: >
  PLAUD Shopify 主题矩阵的发版与上线后治理（order 9），在 Verify 之后：
  按《DTC 开发交付标准 v1.0》§五 做发版前的推送站点二次确认、PR 汇总、上线后跟踪与回归用例入库。
  用户说要发版了、能发了吗、准备上线、推到线上、推哪几个站、推送站点清单、二次确认站点、
  别推错站、这个站不要推、合并 PR、agency 提的 PR、同步 PR、发布前检查清单、
  上线后出 bug 了、线上 bug、当天要修吗、样式问题排下个迭代、回归用例入库、
  这个问题上次也出过、上线后跟踪、发版记录 时使用。
  前置条件按 IncludedInThisPush 分别算，不是全有或全无：**IncludedInThisPush: Yes 的每个块**都已由
  plaud-theme-qa 给出 ReadyForIntegration: Yes（含 QARef）且运营/PM 验收状态为 Accepted；
  且存在一份覆盖本次发布源树的 QA 工件其 ReadyForDelivery: Yes（多块同批时必须是 QAScope: Integration 的集成 QA）。
  AcceptanceStatus: Pending 的块填 IncludedInThisPush: No 是合法的，但它的改动**必须不在发布源树里**
  ——没有"自动剔除"，只能由人撤掉 + 重新取证 + 重跑集成 QA，否则 ReleaseDeclaredDiffCheck 会判 DECLARED_DIFF_ORPHAN。
  任一不满足即停机，不出发版清单。
  产出 ArtifactKind: ReleaseOps 工件（28 字段）：ReleaseId、ReleaseScope（逐 ChangeSet 的 QAConclusion / QARef / 验收状态）、
  ReleaseQARef、ObjectFormat、ReleaseSourceTreeOid、ReleaseStageDir、StagedAt、ShopifyCliVersion、
  PushCommand、PushCommandCompliance、EffectivePayloadManifest、RemoteVerifyResult、
  ReleaseDiffBaseCommit、ReleaseDeclaredDiffCheck、TargetSites、ExcludedSites、ThemeIds、SiteListConfirmedBy、
  PRRef、AuthorizationRef、PushResult、PerSitePushResult、PushedAt、PostReleaseWatch、
  RegressionCasesAdded、TestSetTraceAfterArchive、BlockingGaps。
  **v0.3.0 支持多 ChangeSet 同批发版**：IncludedInThisPush: Yes 多于一个时必须有 ReleaseQARef 指向
  QAScope: Integration 的集成 QA，且其 VerifiedThemeTreeOid 逐字等于 ReleaseSourceTreeOid；
  缺集成 QA 的多块发版请求一律停机并指出缺什么，不得自行吸收成 QA 或规划任务。
  推站源必须是 plaud_stage_verified 物化出的目录，不得从活工作树推。
  三条硬规则：**运营验收未通过前禁止发版对应 section/page**；**推送站点必须两次确认且有出处**；
  **每个线上 bug 必须反推一条回归用例入库**。
  本 skill 不判可交付（唯 plaud-theme-qa 有权）、不写代码、不修 bug、不做验收、不判反馈归属；
  发版动作本身（push / 合并 PR / theme push）是外部动作，需用户显式授权后才执行。
  不要路由到本 skill：技术验收 → plaud-theme-qa；提测材料 → plaud-theme-qa-intake；
  反馈是缺陷还是变更 → plaud-theme-feedback-triage；修 bug → plaud-theme-dev。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Release Ops（发版与上线后）

开工前必读 `plaud-theme-shared/references/handoff-schema.md` §9.1.4（本 skill 的产出契约）与 §1.1（`ReadyForDelivery: Yes` 的边界）。

## 三道门，缺一不发

```
① QA 技术门     每块 ReadyForIntegration: Yes             ← plaud-theme-qa（块 QA）给
                + 一份覆盖发布源树的 ReadyForDelivery: Yes ← plaud-theme-qa（多块同批必须是集成 QA）
② 运营验收门     AcceptanceStatus: Accepted                ← PM / 运营给
③ 站点确认门     两次确认且有出处                          ← 本 skill 守
④ 发布门         ReleaseSourceTreeOid == VerifiedThemeTreeOid ← 本 skill 守（handoff-schema §2.11 第二层）
                + ReleaseDeclaredDiffCheck: Passed
                + PushCommandCompliance: Compliant
                + 执行 push 命令紧前再复算一次
```

> 🔴 **QA 通过不等于可以发版。** handoff-schema §1.1：`ReadyForDelivery: Yes` 只代表通过了矩阵内部的技术验证，**不代表** PM 已验收、也不代表可以推站。
>
> 🔴 **它的准确语义是「这棵被验过的 tree 有资格被后续 release 使用」，不是「这次发布一定合法」**（handoff-schema §2.11）。QA 出工件时 release 工件还不存在，所以那个不变量**分两层落**：第一层是 QA 当场可验的（`QAAdmissionStatus: Accepted` + `ChangeSetIdMatched: Yes` + `DeclaredDiffCheck: Passed` + §5 全部检查项 `Passed` 或带证据的 `NotApplicable`），第二层就是上面的**门 ④**，由本 skill 执行。**不要把第二层的条件塞回 QA 那一层**——那会变成「release 要 QA 的 Yes、QA 又要 release 的字段」的流程死循环。
>
> DTC §三 第 3 条是硬红线：**禁止在运营验收完成前发版对应 section / page**。

四道门任一不满足 → 停机，不出发版清单，不执行任何推送动作。

## 本 skill 不做什么

| 不做 | 归谁 |
|---|---|
| 判可交付、跑 Theme Check / 断点回归 | `plaud-theme-qa`（**唯一交付权**） |
| 校验提测材料 | `plaud-theme-qa-intake` |
| 判反馈是缺陷还是变更 | `plaud-theme-feedback-triage` |
| 修 bug、写代码、改 schema | 三个实现 skill |
| 影响面评估 | `plaud-theme-impact` |

**本 skill 不输出 `ReadyForDelivery`**。它消费 QA 的结论：逐块记进 `ReleaseScope[].QAConclusion`（抄该块的 `ReadyForIntegration`）+ `ReleaseScope[].QARef`，本次的**交付许可**记在顶层的 `ReleaseQARef`。它不生产结论。

---

## 执行顺序

```
Step 0    收齐本次发版包含的全部 ChangeSet，逐个核对 QA 结论 + 定位 ReleaseQARef
Step 1    确认运营/PM 验收状态
Step 1.5  物化推站源（plaud_stage_verified）+ 归属复核（ReleaseDeclaredDiffCheck）
Step 2    推送站点二次确认（本 skill 的核心工作）
Step 3    汇总 PR
Step 4    输出发版清单 → 等用户显式授权 → 推站紧前再复算一次 → 从物化目录推
Step 5    上线后：跟踪 + 回归用例入库
```

### Step 0 — 逐个核对 QA 结论

**`ReleaseScope` 逐个 ChangeSet 填**（不是顶层一个标量），每块**六个**子字段：

| 子字段 | 填法 |
|---|---|
| `ChangeSetId` | 该块的 ChangeSetId |
| `QAConclusion` | 🔴 **v0.3.0 起逐块抄该块 QA 工件的 `ReadyForIntegration`**（`Yes` / `No`），**恒定一个来源、不分场景**——单块直发时该块 QA 同样要给 `ReadyForIntegration: Yes` |
| `QARef` | 该块那份 QA 工件的 `VerificationId` + 出处。🔴 **没有它，`QAConclusion` 就是一个无法追溯来源的标量**，填 `Yes` 也证明不了来自哪份 QA |
| `AcceptanceStatus` | `Accepted` / `Pending`（逐块，见 Step 1） |
| `AcceptanceRef` | 验收出处；`Pending` 时填 `N/A` |
| `IncludedInThisPush` | `Yes` / `No` |

`IncludedInThisPush: Yes` 的块，`QAConclusion` **任一不是 `Yes` → 停机**。

**本次的交付许可不在 `ReleaseScope` 里**，在顶层的 `ReleaseQARef`：那份 `ReadyForDelivery: Yes` 的 QA 工件的 `VerificationId` + 出处。单块直发时它指向该块 QA；**多块同批时它必须指向 `QAScope: Integration` 的集成 QA**。

> 🔴 **v0.3.0 支持多 ChangeSet 同批发版，代价是多一道集成 QA。**
> 身份来自不可变的 tree 对象而不是 `git status` / `git diff`，所以"已验证对象"与"提交后要推送的对象"**是同一个 oid**（实测：commit 前后 `ThemeTreeOid` 逐字不变）。
> 因此 `IncludedInThisPush: Yes` 的块多于一个时，两条**可机械核对**的条件必须同时满足，否则停机：
> 1. `ReleaseQARef` **必须**指向 `QAScope: Integration` 的集成 QA 工件，且其 `VerifiedThemeTreeOid` **逐字等于** `ReleaseSourceTreeOid`（`ObjectFormat` 也必须相同，否则 oid 根本不可比）；
> 2. 按 `TargetSites` 分 cohort：**站点集合不同的块不共用一棵树推站**。
>
> ⚠️ **诚实结算，不打折**：真收益是 Implement 可并行、隔离快照上的块 QA 可并行、N 次发版动作合并成 1 次。**集成 QA 这道串行屏障消不掉**，它是正确性成本、不是可以省掉的一步；最终树、集成计划、测试环境或有效 payload 变了都要重跑。块 QA 只产 `ReadyForIntegration`，**不产交付许可**。
>
> 🔴 **没有集成 QA 的多块发版请求：本 skill 停机并指出缺什么**（缺一份 `QAScope: Integration` 的工件 / 缺 `IntegrationPlan` 的集成者与集成基准），**不得自行吸收成 QA 任务或规划任务**——本 skill 不跑验证、也不做编排。

⚠️ 还要核对 QA 结论**是否仍然对得上这次要推的那棵树**：现在这件事有机械判据，不靠"HEAD 有没有变"这类间接信号——

- 用 `plaud_theme_tree` 重算当前可发布内容，得到 `ObjectFormat` + `ThemeTreeOid`；
- 它必须**逐字等于** `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid`（同 `ObjectFormat`）。不等 → 该 QA 结论覆盖的不是这棵树，停机重跑；
- 🔴 **`BaseHeadSha` / HEAD 变化本身不再是失配判据**（v0.3.0：期间 commit / rebase / checkout 不再让 ChangeSet 失效）。判据是 tree oid，不是 HEAD。

### Step 1 — 运营验收（逐块）

`AcceptanceStatus` 在 `ReleaseScope` 里**逐块**给，一个标量表达不了"A 验收了、B 还没"：

| 该块的 `AcceptanceStatus` | `IncludedInThisPush` |
|---|---|
| `Accepted` | `Yes` |
| `Pending` | **`No`** —— 留到下次 |

拿不到验收状态 → 停机问 PM，不默认 `Accepted`。

> 🔴 **"部分发布"不是在 push 命令上排除，而是发布源树里根本不能有那块的改动。**
> 一次 `shopify theme push` 推的是**整个主题**，`IncludedInThisPush: No` 只是一条记录，**它不会自动把未验收的代码挡在外面**。
>
> 🔴 **必须说清做不到的部分**：`plaud_stage_verified` 物化的是一整棵 `ThemeTreeOid`，**没有「减去某块」的能力**（与「不能从混合工作树还原单块快照」是同一个限制）。**本 skill 不提供、也不得发明任何"自动剔除未验收块"的机制。**
>
> 所以只有**一条**合法出路：
>
> > 该块的改动**必须从发布源树里撤掉**——由 `IntegrationPlan.Integrator`（**人**，矩阵不做 merge）执行，撤法是 revert / stash / 换 base，属于人的动作；撤完之后**重新取证**（新的 `ThemeTreeOid`）并**重跑集成 QA**（新的 `ReleaseQARef`）。
> > 撤不掉、或不愿撤 → 该块只能改判为 `IncludedInThisPush: Yes` 并补齐它的验收，否则**本次 cohort 不能发**。
>
> 这条不靠自觉，**承载字段是 `ReleaseDiffBaseCommit` + `ReleaseDeclaredDiffCheck`**：推站前以「`IncludedInThisPush: Yes` 的块的声明路径并集」为期望集合重跑一次 `plaud_declared_diff`，`No` 块的改动只要还在树里就会被判成 `DECLARED_DIFF_ORPHAN` → `ReleaseDeclaredDiffCheck: Failed` → 停机。
>
> **残余风险如实记**：这把「同树并行 + 部分发版」的收益削掉一半——`No` 块要么提前别落进这棵树，要么就得撤销重验。新模型没有让这件事变便宜，只是让它**变得可检测**。
> **不得**把未验收代码混进这次 push 却在工件里写 `No`——那是记录与事实不符，而且现在会被 `ReleaseDeclaredDiffCheck` 当场抓出来。

### Step 1.5 — 物化推站源 + 归属复核

> 🔴 **必须从物化目录推，不能从活工作树推。** 重算相等之后、CLI 逐文件读取期间工作树还能再变（TOCTOU），推上去的会是一个从没被验过的混合状态。

1. **物化**：`plaud_stage_verified <目标目录>` —— 它一步做完「算当前 `ThemeTreeOid` → 把**同一棵** tree 物化成独立目录 → **回环复算**」。输出 `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>`。
   🔴 **目标目录必须在仓库外、必须已经存在、且必须是空的**（实测：不存在 → `STAGE_DST_MISSING`；非空 → `STAGE_DST_NOT_EMPTY`，两者都 rc=1）。所以要先建：

   ```bash
   STAGE=$(mktemp -d)/release-stage && mkdir -p "$STAGE"
   plaud_stage_verified "$STAGE" || { echo "STAGE_FAILED"; exit 1; }
   ```

   🔴 **原样抄这两行，不要只抄第一行**：只写 `plaud_stage_verified "$STAGE"` 而不判退出码时，函数打印了错误串却让整段 rc=0，按 `$?` 分支或跑在 `set -e` 下的调用方会以为这道门通过了。
   - 目录路径填 `ReleaseStageDir`，`ObjectFormat` / `ThemeTreeOid` 填 `ObjectFormat` / `ReleaseSourceTreeOid`，物化完成时间填 `StagedAt`（**只记不判**，是审计留痕，不构成任何判据、不构成停机条件）。
   - 🔴 **回环复算不是锦上添花，是这道门唯一可信的部分**：`git archive` 会应用 `export-ignore` / `export-subst`，`tar.umask` 还能改掉 exec 位——光"算完再解开"不保证物化结果等于被验证的那个 tree。函数内部已做，输出 `STAGE_ROUNDTRIP_MISMATCH` 即停机。
   - 🔴 **`ReleaseStageDir` 不是 QA 的 `StageDirRef`**：后者是完整 workspace 快照（含 `node_modules` / build 源 / `.theme-check.yml` / `memory/`），整树 push 会把它们全发上线。两者的 `ThemeTreeOid` 必须相同，不同即说明两次取证之间工作树变过，停机。
2. **发布门第 1 条**：`ReleaseSourceTreeOid` **逐字等于** `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid`，且 `ObjectFormat` 相同。不等即停机——这正是「单块 QA 之后、release 之前工作树又变了」和「多块合并后没有任何单块 QA 持有那棵合并树的 oid」两件事的挡法。
3. **归属复核**：`plaud_declared_diff <ReleaseDiffBaseCommit> <pathlist-file>`，期望集合是「`IncludedInThisPush: Yes` 的块的**声明路径并集**」，结论填 `ReleaseDeclaredDiffCheck`（`Passed` / `Failed` / `Blocked` / `NotApplicable`）。
   - `ReleaseDiffBaseCommit`：**单块直发抄该块 §4 的 `BaseHeadSha`；多块同批抄 `IntegrationPlan.IntegrationBaseCommit`**，必须可解析。
   - **退出码 → 取值的映射**（这条不许凭感觉填）：

     | 函数结果 | `ReleaseDeclaredDiffCheck` |
     |---|---|
     | rc=0 且末段是 `DECLARED_DIFF_OK` | `Passed` |
     | rc≠0 且 stderr 是 `DECLARED_DIFF_ORPHAN`（树里有本次没声明的路径）或 `DECLARED_DIFF_UNCHANGED`（声明了却没变） | `Failed` |
     | rc≠0 且是环境原因（基准不可解析 / `GIT_TOO_OLD` / `mktemp` 失败 / 平台不支持） | **`Blocked`** |
     | 零改动只读任务（本 skill 不会遇到） | `NotApplicable` |

   - 🔴 **基准缺失或不可解析 → `Blocked`，不是 `Passed` 也不是 `NotApplicable`**；`Blocked` 不得折算为 pass → 该轮拿不到发布许可。
4. **分 cohort**：按 `TargetSites` 划分，**站点集合不同的块不共用一棵树推站**；每个 cohort 各自物化、各自复核。
5. **命令合规**（`PushCommandCompliance`）：
   - 出现 `--only` / `--ignore` → **`Violation` + 停机**（用了就等于 payload 与 `ReleaseSourceTreeOid` 不同源）；
   - `PushCommand` **必须逐字包含 `--path <ReleaseStageDir>`**，且路径与该字段逐字相等 —— 否则推的可能根本不是被验证的那棵树（cwd 或 `--path` 指向别处时，命令里没有 `--only` / `--ignore` 也照样"合规"）；
   - `--nodelete` **不判 `Violation`**，但必须出现在 `PushCommand` 里并在正文说明影响（它改变远端删除行为）；
   - `ShopifyCliVersion` 记 `shopify --version` 的**原样输出**——换版本可能改变文件投影与删除行为。**取不到时**（CLI 未安装 / 命令失败）填 `Unavailable(<原因>)` 并**停机不推**：拿不到 CLI 版本就等于拿不到"这次推送用的是哪套文件投影与删除行为"，这是发布前提不是可选留痕。**不得**填"最新版""同上"或凭记忆写一个版本号。
6. **执行 push 命令的紧前再复算一次**物化目录的 tree oid，与 `ReleaseSourceTreeOid` 逐字比对。不等即停机、不推。

#### 三条环境前提（拿不到就是 `Blocked`，不得填 `Passed` / `NotApplicable`）

| 前提 | 拿不到时 |
|---|---|
| 可写 `TMPDIR` | `mktemp` 失败 → 函数 fail closed → `ReleaseDeclaredDiffCheck` 等相关项 `Blocked` |
| git ≥ 2.25 | `GIT_TOO_OLD` → 同上 |
| **只支持 macOS / Linux** | Windows 上的典型 git 配置（`core.fileMode` 为假、`core.autocrlf` 为真——具体取值随安装时的选项而定）会直接命中两道字节保真门 → 取证不可用，全部身份/归属检查 `Blocked`，理由写「平台不支持 / 字节保真前提不满足」 |

> 🔴 **函数原样复制 `handoff-schema.md` §2.5，不得凭记忆敲、不得删注释。** 一个漏掉 `-c core.hooksPath=/dev/null` 的抄本，后果是**执行仓库里的任意脚本**（`git add` 会触发 hook 与 clean filter）——那比算出一个假指纹严重一个量级。

#### 三条残余风险（不得在正文里承诺它们已解决）

1. **物化目录不是真不可变。** 推站前复算能抓到篡改，但同权限进程在 CLI 逐文件读取期间改目录，矩阵挡不住——**这道复算不创造原子性**。
2. **多站点 push 不是原子的。** 远端校验失败时远端可能已经部分改变，`PushResult` **不得**填 `NotExecuted`。
3. **`ReleaseSourceTreeOid` ≠ Shopify 实际上传集合。** CLI 版本、文件投影、`.shopifyignore`、`--nodelete`、远端现状都是额外输入；`EffectivePayloadManifest` **只记不判**，是给人看的推送凭证，**不能被描述成对实际上传集合的机械保证**——判定由 `RemoteVerifyResult` 承担。（`.shopifyignore` 本身**已进 `ThemeTreeOid`**：它改变上传集合，必须绑住。）

### Step 2 — 推送站点二次确认

> 🔴 DTC §三 第 4 条原文点名：**推错站点是过去扣分最多的一项。**

两次确认，缺一不可：

| 次序 | 时点 | 谁 | 记在哪 |
|---|---|---|---|
| 第一次 | 运营提需求时填写 | 运营 | `plaud-theme-qa-intake` 的 `TargetSites` / `ScopeSourceRef` |
| **第二次** | **发版前** | 运营/PM 再确认一遍 | 本 skill 的 `SiteListConfirmedBy` |

`SiteListConfirmedBy` **两次的出处都要有**（谁、在哪里、什么时候确认的）。只有一次确认 → 停机补第二次。

清单要求：

- `TargetSites` 逐个站点显式列出，**禁止**"相关站点""全部站点"这类表述
- `ExcludedSites` 明确不推的站点 + **每个的原因**（DTC §五 第 2 条：不需要本次版本的站点提前说明）
- 两个清单加起来应覆盖全部站点；有站点两边都没出现 → 停机确认

**两次清单不一致时**：以第二次为准，但必须在 `BlockingGaps` 里点出差异（哪个站被加了/去了），让运营确认这是有意的而不是漏填。

### Step 3 — PR

DTC §五 第 1 条：**agency 负责提供 PR，前端用 agent 同步和合并 PR**。

`PRRef` 记 agency 提供的 PR 链接。没有 PR → 停机要，不自行开分支替 agency 提。

### Step 4 — 发版动作需授权

> 🔴 **本 skill 只产出清单与判定，不自行执行推送。**
>
> `git push`、`shopify theme push`、合并 PR 都是**不可逆的外部动作**，必须等用户看过清单后显式授权才执行。三道门全绿也不构成自动执行的许可。

输出发版清单后停下等确认，不要"既然都通过了我就顺手推了"。授权之后、**执行 push 命令的紧前**还要再复算一次物化目录（Step 1.5 第 6 条），不等即停机、不推。

授权与结果如实记录：

| 字段 | 取值 |
|---|---|
| `AuthorizationRef` | 用户显式授权的出处；未授权填 `NotAuthorized` |
| `PushResult` | `NotExecuted` / `Executed` / **`PartiallyExecuted`**。**`Executed` 仅当每个站点都是 `Succeeded`** |
| `RemoteVerifyResult` | **逐站点**远端 checksum 复核结论：`Matched` / `Mismatched` / `Unavailable`。它**决定** `PerSitePushResult[].Status`，不是事后观察项。🔴 **推站尚未发生时**（`PushResult: NotExecuted`，即输出发版清单等授权的那一轮）整个字段填 `N/A(NotExecuted)`，**逐站点不得预填 `Unavailable`**——`Unavailable` 的语义是"推了但复核不动"，预填它会让 `PerSitePushResult` 被映射成 `Unverified`（"推已经发生了"），凭空捏造一次没发生的推送。🔴 **推了但某个站点根本没尝试**（cohort 中途停下，`PushResult: PartiallyExecuted`）：该站点填 **`N/A(NotAttempted)`** → `PerSitePushResult[].Status: NotAttempted`。少了这个取值，"逐站点一一对应"与既有的 `NotAttempted` 无法同时成立，只能靠给没推过的站点编一个推后语义的值来凑 |
| `PerSitePushResult` | **逐站点**结果：站点 / `Succeeded`\|`Failed`\|`Unverified`\|`NotAttempted` / 时间 / 原因 |
| `EffectivePayloadManifest` | 逐 cohort / 逐站点：实际上传集合 + 远端 base digest + 时间。**只记不判**。**采集方法**：取 `shopify theme push` 的输出（upload / delete 清单）+ 推送前后各拉一次远端 checksum 作为 base digest。**降级取值**：`PushResult: NotExecuted` 时填 `N/A(NotExecuted)`（**推还没发生就没有"实际上传集合"，不得预填计划集合冒充实际值**）；推了但 CLI 输出拿不到 → 填 `Unavailable(<原因>)`，**不得留空、也不得用 `ReleaseSourceTreeOid` 的文件清单顶替**（那是本地推送源，不是实际上传集合） |
| `PushedAt` | 首个成功推送的时间；`NotExecuted` 时填 `N/A` |

**`RemoteVerifyResult` → `PerSitePushResult[].Status` 的三条映射（逐站点，不得跳过）**：

| `RemoteVerifyResult` | `PerSitePushResult[].Status` |
|---|---|
| `Matched` | `Succeeded` |
| `Mismatched` | `Failed` |
| `Unavailable` | **`Unverified`**（v0.3.0 新增取值） |
| `N/A(NotAttempted)` | `NotAttempted`（该站点根本没推） |

> 🔴 **`Unverified` 不得折算为 `Succeeded`**（复核不动 ≠ 推成功），**也不是 `NotAttempted`**（推已经发生了）。把它算成 `Succeeded` 会让 `PushResult` 变成假读数。

> 🔴 **集合约束：`TargetSites` / `RemoteVerifyResult` / `PerSitePushResult` 三者必须逐站点一一对应、无重复、且 `TargetSites` 非空。**
> 空站点集合会让「每个站点都成功」在真空里成立，`PushResult: Executed` 就成了假读数。三者对不上即停机。
> 🔴 **一一对应这半条只在推站已发生之后（`PushResult` 不是 `NotExecuted`）成立**：输出发版清单等授权的那一轮，`RemoteVerifyResult` 合法地是 `N/A(NotExecuted)`、`PerSitePushResult` 逐站点是 `NotAttempted`，此时拿"逐站点一一对应"去卡会把合法的推前清单停掉。**`TargetSites` 非空这半条则始终成立。**

> 🔴 **部分站点失败必须填 `PartiallyExecuted`，不能填 `NotExecuted`。**
> 填 `NotExecuted` 会**抹掉已经发生的线上副作用** —— 下次有人看到"没推过"就重推一遍，已成功的站点被重复推送。**多站点 push 不是原子的**：远端校验失败时远端可能已经部分改变。
> 逐站点结果一条都不能省：哪个成功了、哪个失败了、哪个没验成、为什么。补推时只补 `Failed` / `Unverified` / `NotAttempted` 的站点。

### Step 5 — 上线后

| 问题类型 | 时效（DTC §五） |
|---|---|
| **功能类 bug（非样式）** | **当天解决** |
| 样式类问题 | 进最近一次迭代修复 |

分类不清时按功能类处理（更严的那一档）。

> 🔴 **每个线上 bug 必须反推一条回归用例入库** —— DTC §五 第 5 条：「同一个问题不允许出现第二次」。
>
> 修完 bug 而 `RegressionCasesAdded` 为空 = 本次上线治理**未完成**，不得关闭。本轮**确实没有线上 bug** 时填 `N/A(NoOnlineBug)`（两个字段都填），不要留空——留空表示「该补没补」。用例格式见 `plaud-theme-qa-intake/references/test-case-format.md`（四段式 + 附件）。
> 🔴 入库后还要填 `TestSetTraceAfterArchive`：稳定文档 ID 必须与本次提测那份 `TestSetTrace` 同一个、revision 取入库后的新值。只写「已入库」不算——两处指向不同文档就等于没有长期测试集（handoff-schema §9.1.4）。

线上 bug 的修复本身走完整链路：`plaud-theme-feedback-triage` 判归属 → 新工作项 → Assess → Implement → qa-intake → QA → 回到本 skill。**不得**因为"线上着火了"就跳过 QA 直接推。

---

## 停机点

| 情形 | 动作 |
|---|---|
| `IncludedInThisPush: Yes` 的块里，任一 `QAConclusion`（该块的 `ReadyForIntegration`）不是 `Yes` | 停，退回 QA |
| **`IncludedInThisPush: Yes` 的块里**任一 `QARef` 为空 | 停。`QAConclusion` 没有出处就是一个无法追溯来源的标量，填 `Yes` 也证明不了来自哪份 QA。🔴 `IncludedInThisPush: No` 的块**不适用**本条：它本轮不发，`QAConclusion` / `QARef` 按实际情况填（该块已有块 QA 就照抄，尚未验收就填 `N/A(NotIncluded)`），不构成停机 |
| 有块 `AcceptanceStatus: Pending` **而它被填成 `IncludedInThisPush: Yes`**，或它虽填 `No` 但改动仍在发布源树里 | 停（DTC §三 第 3 条是**运营验收**门，与身份模型无关）。🔴 **`Pending` 本身不是停机条件**——`Pending → IncludedInThisPush: No` 是合法的部分 cohort；停机的是"未验收却随这棵树发出去"。**「等它验收完一起发」在 v0.3.0 是合法路径**（多块同批已支持），但要走完整条链：该块补齐验收 → 集成到一棵树 → 重跑集成 QA → 新的 `ReleaseQARef`。另一条合法路径是本次不发它，但那要求**它的改动根本不在发布源树里**（见 Step 1 红框：撤掉 + 重新取证 + 重跑集成 QA，没有"自动剔除"） |
| `IncludedInThisPush: Yes` 的块多于一个，但 `ReleaseQARef` 不是 `QAScope: Integration` 的集成 QA | 停，指出缺一份集成 QA；**不得自行吸收成 QA 任务或规划任务** |
| `ReleaseSourceTreeOid` ≠ `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid`（或 `ObjectFormat` 不同） | 停。这棵要推的树没有被那份 QA 验过 |
| `ReleaseDeclaredDiffCheck` 不是 `Passed`（`Failed` / `Blocked` 都算） | 停。`DECLARED_DIFF_ORPHAN` 说明树里有本次没声明的改动（典型是 `IncludedInThisPush: No` 的块还在树里）；`Blocked` 是"该验但验不了"，**不得折算为 pass** |
| `PushCommand` 含 `--only` / `--ignore`，或不含逐字的 `--path <ReleaseStageDir>` | 停，`PushCommandCompliance: Violation` |
| 回环复算不等 / `STAGE_ROUNDTRIP_MISMATCH` / 推站紧前复算与 `ReleaseSourceTreeOid` 不等 | 停，不推 |
| `TargetSites` 为空 | 停。空集合会让「每个站点都成功」在真空里成立，`PushResult: Executed` 就成了假读数 |
| **推站已发生之后**（`PushResult` 不是 `NotExecuted`）`TargetSites` / `RemoteVerifyResult` / `PerSitePushResult` 三者对不上（漏站、重复、多出） | 停。🔴 **这条集合约束只对已尝试推送的轮次成立**：输出发版清单等授权的那一轮 `PushResult: NotExecuted`，此时 `RemoteVerifyResult` / `PerSitePushResult` 合法地是 `N/A(NotExecuted)` / `NotAttempted`，拿它去要求"逐站点一一对应"会把合法的推前清单停掉 |
| 各块 `TargetSites` 不同却共用一棵树推站 | 停，按 cohort 拆 |
| `TMPDIR` 不可写 / git < 2.25 / 在 Windows 上 | 停。相关取证项填 `Blocked`（**不得**填 `Passed` 或 `NotApplicable`），理由如实写 |
| 当前 `plaud_theme_tree` 重算的 `ThemeTreeOid` 与 `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid` 不等 | 停，要求重跑 QA。🔴 **判据是 tree oid，不是 HEAD**——期间 commit / rebase 本身不再让结论失效 |
| 站点清单只确认过一次 | 停，补第二次确认 |
| 站点清单无出处 | 停，要出处 |
| 有站点在 Target 与 Excluded 里都没出现 | 停，确认遗漏 |
| 没有 PR | 停，要 agency 提供 |
| 用户要求跳过 QA 紧急上线 | **不出发版清单、不给"可以推"的结论**（四道门未过）。如实列出缺了哪些验证与风险，给出最短合规路径（`references/release-checklist.md` §4）。`ReleaseScope[].QAConclusion` 照实写"缺失"，**不得**伪造。推送是用户自己的动作，本 skill 不代为编排、不为它背书 |
| 线上 bug 修完但无回归用例 | 停，`RegressionCasesAdded` 不得为空 |
| 回归用例已写但 `TestSetTraceAfterArchive` 为空、或稳定文档 ID 与提测那份不一致 | 停，视为未归档 |

---

## 输出

回复的最后必须是 handoff-schema §9.1.4 的 ` ```yaml ` 契约块，字段与 canonical **逐字一致**、顺序一致，不得增删改名：

```yaml
ArtifactKind: ReleaseOps
ReleaseId:                # REL-<YYYYMMDD>-<NN>
ReleaseScope:             # 见下：逐个 ChangeSet 的 QA 结论 + 验收状态，不用单个标量表达
ReleaseQARef:             # 🔴 **本次发布许可的唯一来源**：那份 ReadyForDelivery: Yes 的 QA 工件的
                          #   VerificationId + 出处。单块直发指向该块 QA；多块同批**必须**指向
                          #   QAScope: Integration 的集成 QA。
                          #   （字段名不叫 IntegrationQARef：单块场景它指的不是集成工件）
ObjectFormat:             # sha1 | sha256 —— 与 ReleaseQARef 那份工件的取值必须相同，否则 oid 不可比
ReleaseSourceTreeOid:     # 本次推送源的 tree oid。**必须逐字等于 ReleaseQARef 那份工件的
                          #   VerifiedThemeTreeOid**；不等即停机（这是 §2.11 第 2 道门）
ReleaseStageDir:          # plaud_stage_verified 物化出的目录绝对路径（只含可发布面）。
                          #   🔴 不是 QA 的 StageDirRef（那是完整 workspace 快照，含 node_modules /
                          #   .env / build 源，整树 push 会把它们全发上线）
StagedAt:                 # 物化完成时间。**只记不判**（审计留痕），不构成任何判据
ShopifyCliVersion:        # shopify CLI --version 原样输出；换版本可能改变文件投影与删除行为
PushCommand:              # 完整命令原文，逐字。🔴 必须包含 `--path <ReleaseStageDir>` 且路径与该字段
                          #   逐字相等 —— 否则推的可能根本不是被验证的那棵树（cwd 或 --path 指向别处时，
                          #   命令里没有 --only/--ignore 也照样"合规"）
PushCommandCompliance:    # Compliant | Violation —— 出现 --only / --ignore 即 Violation 并停机
                          #   （用了就等于 payload 与 ReleaseSourceTreeOid 不同源）。
                          #   --nodelete 不判 Violation，但必须出现在 PushCommand 里并在正文说明影响
EffectivePayloadManifest: # 逐 cohort / 逐站点：实际上传集合 + 远端 base digest。**只记不判**，
                          #   是给人看的推送凭证；判定由 RemoteVerifyResult 承担
RemoteVerifyResult:       # 逐站点：Matched | Mismatched | Unavailable —— 远端 checksum 复核结论。
                          #   推站尚未发生（PushResult: NotExecuted）→ 整个字段 N/A(NotExecuted)；
                          #   推了但某站点根本没尝试 → 该站点 N/A(NotAttempted) → PerSitePushResult: NotAttempted。
                          #   它**决定** PerSitePushResult[].Status，不是事后观察项。
                          #   🔴 TargetSites / RemoteVerifyResult / PerSitePushResult 三者必须**逐站点
                          #   一一对应、无重复、且 TargetSites 非空**——空站点集合会让「每个站点都成功」
                          #   在真空里成立，PushResult: Executed 就成了假读数
ReleaseDiffBaseCommit:    # 归属复核的基准 commit-ish，必须可解析。单块直发抄该块 §4 的 BaseHeadSha；
                          #   多块同批抄 IntegrationPlan.IntegrationBaseCommit
ReleaseDeclaredDiffCheck: # Passed | Failed | Blocked | NotApplicable —— **推站前重跑一次** §2.7，
                          #   期望集合是「IncludedInThisPush: Yes 的块的声明路径并集」。
                          #   🔴 这是 §2.14「No 块不得留在发布源树里」的**唯一承载字段**：
                          #      没有它，那条规则就只是正文要求、没有任何机械核对
TargetSites:              # 二次确认后的推送站点清单，逐个显式列出
ExcludedSites:            # 本次不推的站点 + 每个的原因
ThemeIds:                 # 各目标站点对应的主题 ID
SiteListConfirmedBy:      # 两次确认的出处（需求时 + 发版前），谁/在哪/什么时候
PRRef:                    # agency 提供的 PR 链接
AuthorizationRef:         # 用户显式授权执行推送的出处；未授权填 NotAuthorized
PushResult:               # NotExecuted | Executed | PartiallyExecuted —— 实际推送结果。
                          #   Executed 仅当**每个**站点都是 Succeeded；只要有一个不是且有一个是，
                          #   就必须填 PartiallyExecuted（填 NotExecuted 会抹掉已发生的线上副作用）
PerSitePushResult:        # 逐站点：站点 / Succeeded|Failed|Unverified|NotAttempted / 时间 / 原因。
                          #   🔴 由 RemoteVerifyResult 逐站点决定：
                          #     Matched → Succeeded ／ Mismatched → Failed ／ Unavailable → **Unverified**
                          #   Unverified **不得**折算为 Succeeded，也不是 NotAttempted（推已经发生了）
PushedAt:                 # 实际推送时间；NotExecuted 时填 N/A
PostReleaseWatch:         # 上线后跟踪项：谁/在什么时间窗/看什么
RegressionCasesAdded:     # 每个线上 bug 反推的回归用例（逐条：bug → 用例 ID）
                          #   本轮无线上 bug 时填 N/A(NoOnlineBug)；**留空 ≠ N/A**，留空表示该补没补
TestSetTraceAfterArchive: # 回归用例入库后测试集那一行的新取值。**与 TestSetTrace 同格式、三段齐**：
                          #   <稳定文档ID>@<新revision>; Added=[TC-…]; Updated=[…]; Removed=[…]
                          #   （本次只新增回归用例时写 Updated=[]; Removed=[]，不要省段）
                          #   🔴 稳定文档 ID 必须与本次提测时 QAIntake 的 TestSetTrace 同一个（否则等于没有长期测试集）；
                          #   revision 必须是入库**之后**的新值；Added 段必须含本次新增的回归用例 ID。
                          #   本次无线上 bug 时填 N/A(NoOnlineBug)
BlockingGaps:
```

`ReleaseScope` **逐块展开**（六个子键，见 Step 0）：

```yaml
ReleaseScope:
  - ChangeSetId:
    QAConclusion:       # 抄该块 QA 工件的 ReadyForIntegration（Yes | No）。
                        #   IncludedInThisPush: No 且该块尚未跑过块 QA 时填 N/A(NotIncluded)
    QARef:              # 该块那份 QA 工件的 VerificationId + 出处。
                        #   IncludedInThisPush: No 且尚无块 QA 时填 N/A(NotIncluded)；
                        #   🔴 IncludedInThisPush: Yes 时**不得**为空或 N/A
    AcceptanceStatus:   # Accepted | Pending
    AcceptanceRef:      # 验收出处；Pending 时填 N/A
    IncludedInThisPush: # Yes | No
```

> **本块共 28 个 key**（v0.2.3 为 16 个），顺序即上表顺序，是**封闭集合**——多一个 key 或少一个 key 都是契约违规。

这个块里**不出现 `ReadyForDelivery`** —— QA 的结论在 `ReleaseScope[].QAConclusion` / `ReleaseScope[].QARef` 里逐块引用，本次的交付许可在顶层的 `ReleaseQARef`。
