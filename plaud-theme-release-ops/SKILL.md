---
name: plaud-theme-release-ops
description: >
  PLAUD Shopify 主题矩阵的发版与上线后治理（order 9），在 Verify 之后：
  按《DTC 开发交付标准 v1.0》§五 做发版前的推送站点二次确认、PR 汇总、上线后跟踪与回归用例入库。
  用户说要发版了、能发了吗、准备上线、推到线上、推哪几个站、推送站点清单、二次确认站点、
  别推错站、这个站不要推、合并 PR、agency 提的 PR、同步 PR、发布前检查清单、
  上线后出 bug 了、线上 bug、当天要修吗、样式问题排下个迭代、回归用例入库、
  这个问题上次也出过、上线后跟踪、发版记录 时使用。
  前置条件：本次涉及的每个 ChangeSet 都已由 plaud-theme-qa 给出 ReadyForDelivery: Yes，
  且运营/PM 验收状态为 Accepted。任一不满足即停机，不出发版清单。
  产出 ArtifactKind: ReleaseOps 工件：ReleaseId、ReleaseScope（逐 ChangeSet 的 QA 结论与验收状态）、
  TargetSites、ExcludedSites、ThemeIds、SiteListConfirmedBy、PRRef、AuthorizationRef、
  PushResult、PerSitePushResult、PushedAt、PostReleaseWatch、RegressionCasesAdded。
  **v0.2.0 只支持单块发布**：IncludedInThisPush: Yes 的块多于一个即停机，改逐块串行。
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
① QA 技术门     每个 ChangeSet 的 ReadyForDelivery: Yes   ← plaud-theme-qa 给
② 运营验收门     AcceptanceStatus: Accepted                ← PM / 运营给
③ 站点确认门     两次确认且有出处                          ← 本 skill 守
```

> 🔴 **QA 通过不等于可以发版。** handoff-schema §1.1：`ReadyForDelivery: Yes` 只代表通过了矩阵内部的技术验证，**不代表** PM 已验收、也不代表可以推站。
>
> DTC §三 第 3 条是硬红线：**禁止在运营验收完成前发版对应 section / page**。

三道门任一不满足 → 停机，不出发版清单，不执行任何推送动作。

## 本 skill 不做什么

| 不做 | 归谁 |
|---|---|
| 判可交付、跑 Theme Check / 断点回归 | `plaud-theme-qa`（**唯一交付权**） |
| 校验提测材料 | `plaud-theme-qa-intake` |
| 判反馈是缺陷还是变更 | `plaud-theme-feedback-triage` |
| 修 bug、写代码、改 schema | 三个实现 skill |
| 影响面评估 | `plaud-theme-impact` |

**本 skill 不输出 `ReadyForDelivery`**。它消费 QA 的结论（记进 `ReleaseScope[].QAConclusion`），不生产结论。

---

## 执行顺序

```
Step 0  收齐本次发版包含的全部 ChangeSet，逐个核对 QA 结论
Step 1  确认运营/PM 验收状态
Step 2  推送站点二次确认（本 skill 的核心工作）
Step 3  汇总 PR
Step 4  输出发版清单 → 等用户显式授权才执行推送
Step 5  上线后：跟踪 + 回归用例入库
```

### Step 0 — 逐个核对 QA 结论

**`ReleaseScope` 逐个 ChangeSet 填**（不是顶层一个标量），每块五个字段：`ChangeSetId` / `QAConclusion`（QA 的 `ReadyForDelivery` 取值 + 出处）/ `AcceptanceStatus` / `AcceptanceRef` / `IncludedInThisPush`。

`IncludedInThisPush: Yes` 的块，`QAConclusion` **任一不是 `Yes` → 停机**。

⚠️ 还要核对 QA 结论**是否仍然有效**：handoff-schema §1.4，QA 通过后代码再变则原结论自动失效。发版前若工作树或 HEAD 有变化，要求重新走 QA，不得用旧结论发版。

> 🔴 **v0.2.0 只支持单块发布。** `IncludedInThisPush: Yes` 的块**至多一个**；多于一个 → **停机**，要求改为逐块串行发布（每块走完 实现 → 提测 → QA → 发版，再做下一块）。
> 原因见 handoff-schema §2：指纹绑的是整个工作树，第二块落盘时第一块的 QA 就失效了，**不可能同时持有 N 个仍然有效的 QA 结论**；而"合并后跑一次集成 QA"在绑工作树的模型下也跑不通（合并提交后工作树是干净的，与"各块并集"必然失配）。
> 彻底解法（指纹改绑不可变 commit / tree 对象）留 v0.3.0。**不要**自己发明变通——那正是这条限制要防的。

### Step 1 — 运营验收（逐块）

`AcceptanceStatus` 在 `ReleaseScope` 里**逐块**给，一个标量表达不了"A 验收了、B 还没"：

| 该块的 `AcceptanceStatus` | `IncludedInThisPush` |
|---|---|
| `Accepted` | `Yes` |
| `Pending` | **`No`** —— 留到下次 |

拿不到验收状态 → 停机问 PM，不默认 `Accepted`。

> 🔴 **"部分发布"不是在 push 命令上排除，而是要构造只含已验收块的发布树。**
> 一次 `shopify theme push` 推的是**整个主题**，`IncludedInThisPush: No` 只是一条记录，**它不会自动把未验收的代码挡在外面**。
> 正确做法：把未验收块的改动从发布树里剥离（revert / 分支挑拣），得到一棵只含已验收内容的树，**再对这棵树跑一次集成 QA**（见 Step 0 的红框），`IntegrationQARef` 引用它。
> 做不到剥离时 → **停机**，等未验收块也验收完一起发。**不得**把未验收代码混进这次 push 却在工件里写 `No`——那是记录与事实不符。

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

输出发版清单后停下等确认，不要"既然都通过了我就顺手推了"。

授权与结果如实记录：

| 字段 | 取值 |
|---|---|
| `AuthorizationRef` | 用户显式授权的出处；未授权填 `NotAuthorized` |
| `PushResult` | `NotExecuted` / `Executed` / **`PartiallyExecuted`** |
| `PerSitePushResult` | **逐站点**结果：站点 / `Succeeded`\|`Failed`\|`NotAttempted` / 时间 / 失败原因 |
| `PushedAt` | 首个成功推送的时间；`NotExecuted` 时填 `N/A` |

> 🔴 **部分站点失败必须填 `PartiallyExecuted`，不能填 `NotExecuted`。**
> 填 `NotExecuted` 会**抹掉已经发生的线上副作用** —— 下次有人看到"没推过"就重推一遍，已成功的站点被重复推送。
> 逐站点结果一条都不能省：哪个成功了、哪个失败了、为什么。补推时只补 `Failed` / `NotAttempted` 的站点。

### Step 5 — 上线后

| 问题类型 | 时效（DTC §五） |
|---|---|
| **功能类 bug（非样式）** | **当天解决** |
| 样式类问题 | 进最近一次迭代修复 |

分类不清时按功能类处理（更严的那一档）。

> 🔴 **每个线上 bug 必须反推一条回归用例入库** —— DTC §五 第 5 条：「同一个问题不允许出现第二次」。
>
> 修完 bug 而 `RegressionCasesAdded` 为空 = 本次上线治理**未完成**，不得关闭。用例格式见 `plaud-theme-qa-intake/references/test-case-format.md`（四段式 + 附件）。

线上 bug 的修复本身走完整链路：`plaud-theme-feedback-triage` 判归属 → 新工作项 → Assess → Implement → qa-intake → QA → 回到本 skill。**不得**因为"线上着火了"就跳过 QA 直接推。

---

## 停机点

| 情形 | 动作 |
|---|---|
| `IncludedInThisPush: Yes` 的块里，任一 `QAConclusion` 不是 `Yes` | 停，退回 QA |
| 有块 `AcceptanceStatus: Pending` 但无法从发布树剥离 | 停，等它验收完一起发；不得混进本次 push |
| `IncludedInThisPush: Yes` 的块多于一个 | 停，v0.2.0 不支持多块同批发版，改逐块串行（见 Step 0） |
| QA 通过后代码又变了 | 停，要求重新生成 ChangeSetId 并重跑 QA |
| `AcceptanceStatus: Pending` | 停（对应 section / page 部分） |
| 站点清单只确认过一次 | 停，补第二次确认 |
| 站点清单无出处 | 停，要出处 |
| 有站点在 Target 与 Excluded 里都没出现 | 停，确认遗漏 |
| 没有 PR | 停，要 agency 提供 |
| 用户要求跳过 QA 紧急上线 | **不出发版清单、不给"可以推"的结论**（三道门未过）。如实列出缺了哪些验证与风险，给出最短合规路径（`references/release-checklist.md` §4）。`ReleaseScope[].QAConclusion` 照实写"缺失"，**不得**伪造。推送是用户自己的动作，本 skill 不代为编排、不为它背书 |
| 线上 bug 修完但无回归用例 | 停，`RegressionCasesAdded` 不得为空 |

---

## 输出

回复的最后必须是 handoff-schema §9.1.4 的 ` ```yaml ` 契约块。

这个块里**不出现 `ReadyForDelivery`** —— QA 的结论在 `ReleaseScope[].QAConclusion` 里引用。
