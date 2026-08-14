# 发版清单与上线后治理

**何时读我**：执行 Step 2–5 时。三道门的判定在 SKILL.md 正文。

---

## 1. 发版前清单

逐项打勾，任一项不满足即停机。**不接受"基本都齐了"。**

| # | 项 | 通过条件 |
|---|---|---|
| 1a | 逐块 QA 结论 | 每个 `IncludedInThisPush: Yes` 的块都有 `ReadyForIntegration: Yes` + `QARef`（该块 QA 工件的 `VerificationId` + 出处） |
| 1b | 交付许可 | 顶层 `ReleaseQARef` 指向一份 `ReadyForDelivery: Yes` 的 QA 工件。**多块同批时它必须是 `QAScope: Integration` 的集成 QA** |
| 2 | 树身份对得上 | `ReleaseSourceTreeOid` **逐字等于** `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid`，且 `ObjectFormat` 相同 |
| 2b | 归属复核 | `ReleaseDeclaredDiffCheck: Passed`（期望集合 = `IncludedInThisPush: Yes` 的块的声明路径并集） |
| 2c | 物化与复算 | `ReleaseStageDir` 由 `plaud_stage_verified` 产出、回环复算通过；**执行 push 命令紧前再复算一次**并与 `ReleaseSourceTreeOid` 相等 |
| 2d | 命令合规 | `PushCommandCompliance: Compliant`：无 `--only` / `--ignore`，且 `PushCommand` 逐字含 `--path <ReleaseStageDir>` |
| 3 | 运营验收 | `AcceptanceStatus: Accepted`（逐块）；未验收的块其改动**不得留在发布源树里**（见 §1.1） |
| 4 | 站点清单 | `TargetSites` 逐个列出，无模糊表述，**且非空** |
| 5 | 排除清单 | `ExcludedSites` 每个都有原因 |
| 6 | 覆盖完整 | Target + Excluded 覆盖全部站点，无遗漏 |
| 7 | 两次确认 | `SiteListConfirmedBy` 含需求时与发版前**两次**出处 |
| 8 | 主题 ID | 每个目标站点的主题 ID 明确 |
| 9 | PR | `PRRef` 有 agency 提供的 PR 链接 |
| 10 | 授权 | 用户看过清单并**显式授权**执行推送 |

### QA 结论时效的核对（v0.3.0：判 tree oid，不判 HEAD）

```bash
# 原样复制 handoff-schema §2.5 的函数，**不得凭记忆敲、不得删注释**
# （漏掉 -c core.hooksPath=/dev/null 的抄本会执行仓库里的任意脚本）
plaud_theme_tree           # 输出 <ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>
# 与 ReleaseQARef 那份 QA 工件的 ObjectFormat + VerifiedThemeTreeOid **逐字比对**
```

🔴 **判据是 tree oid，不是 HEAD。** v0.3.0 起 `BaseHeadSha` 不再与当前 HEAD 比对——期间 commit / rebase / checkout **不再**让 ChangeSet 失效（实测：把主题改动 commit 掉，`ThemeTreeOid` 逐字不变）。所以"HEAD 变了"不再是失配信号，"tree oid 变了"才是。

> 🔴 **`git status --porcelain` 在这里挡不住任何东西**（v0.2.2 第六轮修）：它只输出状态码与路径、**不含内容**。QA 通过后如果改的是**同一个已 dirty 文件的内容**，status 输出一字不变 —— 而 canonical 的取证会变。用 status 比对等于把"QA 后又改了内容"判成"结论仍有效"，**发出去的是没验过的字节**，恰好是下面那句话要防的事。

`ThemeTreeOid` 与 `VerifiedThemeTreeOid` 不等 → 这棵要推的树没有被那份 QA 验过，停机要求重跑（多块合并之后**没有任何单块 QA 持有那棵合并树的 oid**，所以这一条在结构上必然要求一份集成 QA）。

**这是最容易被绕过的一环**：QA 通过之后到发版之间常常"顺手又改了点"，此时发的是一批没验过的代码。

---

## 1.1 物化推站源与 cohort 划分

> 🔴 **必须从物化目录推，不能从活工作树推**（TOCTOU：重算相等之后、CLI 逐文件读取期间工作树还能再变）。

七步，缺一不推：

1. `plaud_stage_verified <目标目录>` —— 一步做完「算当前 `ThemeTreeOid` → 把同一棵 tree 物化成独立目录 → **回环复算**」。目录路径填 `ReleaseStageDir`，输出的 `ObjectFormat` / `ThemeTreeOid` 填 `ObjectFormat` / `ReleaseSourceTreeOid`，完成时刻填 `StagedAt`（**只记不判**）。
   🔴 **目标目录必须在仓库外、已经存在、且为空**（实测：不存在 → `STAGE_DST_MISSING`，非空 → `STAGE_DST_NOT_EMPTY`，两者 rc=1）：

   ```bash
   STAGE=$(mktemp -d)/release-stage && mkdir -p "$STAGE"
   plaud_stage_verified "$STAGE" || { echo "STAGE_FAILED"; exit 1; }
   ```

   🔴 **原样抄这两行，不要只抄第一行**：不判退出码时函数打印了错误串却让整段 rc=0，调用方会以为门通过了。
2. 🔴 **回环复算不是锦上添花，是这道门唯一可信的部分**：`git archive` 会应用 `export-ignore` / `export-subst`，`tar.umask` 还能改掉 exec 位——光"算完再解开"不保证物化结果等于被验证的那个 tree。`STAGE_ROUNDTRIP_MISMATCH` 即停机。
3. `ReleaseSourceTreeOid` 与 `ReleaseQARef` 那份工件的 `VerifiedThemeTreeOid` 逐字比对（同 `ObjectFormat`），不等即停机。
4. `plaud_declared_diff <ReleaseDiffBaseCommit> <pathlist-file>`（pathlist 每行一条**逐字**路径），期望集合 = 「`IncludedInThisPush: Yes` 的块的声明路径并集」，结论填 `ReleaseDeclaredDiffCheck`：rc=0 且末段 `DECLARED_DIFF_OK` → `Passed`；rc≠0 且 `DECLARED_DIFF_ORPHAN` / `DECLARED_DIFF_UNCHANGED` → `Failed`；rc≠0 且是环境原因（基准不可解析 / `GIT_TOO_OLD` / `mktemp` 失败 / 平台不支持）→ **`Blocked`**。`ReleaseDiffBaseCommit` 单块直发抄该块 §4 的 `BaseHeadSha`、多块同批抄 `IntegrationPlan.IntegrationBaseCommit`；**基准不可解析 → `Blocked`，不是 `Passed` 也不是 `NotApplicable`**。
5. 按 `TargetSites` **分 cohort**：站点集合不同的块不共用一棵树推站，每个 cohort 各自物化、各自复核。
6. 命令合规：禁 `--only` / `--ignore`（用了就等于 payload 与 `ReleaseSourceTreeOid` 不同源）；`PushCommand` 必须逐字含 `--path <ReleaseStageDir>`；`--nodelete` 不判 `Violation` 但必须出现在命令里并在正文说明影响；`ShopifyCliVersion` 记 `shopify --version` 原样输出。`.shopifyignore` **已进 `ThemeTreeOid`**（它改变上传集合，必须绑住）。
7. **执行 push 命令的紧前再复算一次**物化目录并与 `ReleaseSourceTreeOid` 比对，不等即停机、不推。

### `IncludedInThisPush: No` 的块怎么办

🔴 `plaud_stage_verified` 物化的是一整棵 `ThemeTreeOid`，**没有「减去某块」的能力**。**不存在也不得发明"自动剔除"机制。**唯一出路：由 `IntegrationPlan.Integrator`（**人**）把该块的改动从发布源树里撤掉（revert / stash / 换 base）→ **重新取证**（新的 `ThemeTreeOid`）→ **重跑集成 QA**（新的 `ReleaseQARef`）。撤不掉、或不愿撤 → 该块只能改判为 `IncludedInThisPush: Yes` 并补齐验收，否则**本次 cohort 不能发**。
承载字段是 `ReleaseDiffBaseCommit` + `ReleaseDeclaredDiffCheck`：`No` 块的改动只要还在树里就会被判成 `DECLARED_DIFF_ORPHAN`。
**残余风险如实记**：这把「同树并行 + 部分发版」的收益削掉一半。新模型没有让这件事变便宜，只是让它**变得可检测**。

### `EffectivePayloadManifest` 的填法

逐 cohort / 逐站点记：本次 CLI 实际上传（与删除）的文件集合 + 远端的 base digest + 时间。
🔴 **只记不判**，是给人看的推送凭证，**不能被描述成对实际上传集合的机械保证**——判定由 `RemoteVerifyResult` 承担（`Matched` → `Succeeded` ／ `Mismatched` → `Failed` ／ `Unavailable` → `Unverified` ／ `N/A(NotAttempted)` → `NotAttempted`；整轮未推时该字段是 `N/A(NotExecuted)`）。
🔴 **`ReleaseSourceTreeOid` ≠ Shopify 实际上传集合**：CLI 版本、文件投影、`.shopifyignore`、`--nodelete`、远端现状都是额外输入。

### 三条环境前提（拿不到就是 `Blocked`）

| 前提 | 拿不到时 |
|---|---|
| 可写 `TMPDIR` | `mktemp` 失败 → 函数 fail closed → 相关取证项 `Blocked`，**不得**填 `Passed` / `NotApplicable` |
| git ≥ 2.25 | `GIT_TOO_OLD` → 同上 |
| **只支持 macOS / Linux** | Windows 上的典型 git 配置会命中字节保真门 → 取证不可用，全部身份/归属检查 `Blocked`，理由写「平台不支持 / 字节保真前提不满足」 |

---

## 2. 站点清单的写法

### ✅ 合格

```yaml
TargetSites:
  - plaud-us    (theme 123456789)
  - plaud-de    (theme 123456790)
  - plaud-jp    (theme 123456791)
ExcludedSites:
  - plaud-fr    原因：该站尚未上线该产品线，运营 2026-08-10 确认本次不推
  - plaud-uk    原因：正在做独立改版，避免冲突
  - （其余 12 站）原因：本模块仅用于上述产品页模板，其它站点未使用该模板
SiteListConfirmedBy:
  第一次：运营 @xxx，需求单 LIN-1234，2026-08-05
  第二次：运营 @xxx，飞书群消息，2026-08-12 发版前确认
```

### ❌ 不合格

```yaml
TargetSites: 相关站点          # 模糊
ExcludedSites: 其它站          # 无原因
SiteListConfirmedBy: 运营确认过  # 无时间、无出处、看不出是几次
```

### 两次清单不一致

以**第二次为准**，但必须在 `BlockingGaps` 点出差异：

```
⚠️ 站点清单变更：需求时 TargetSites 含 plaud-uk，发版前确认已移除。
   请运营确认这是有意排除而非漏填。
```

不点出差异 = 漏填和有意排除分不开，正是推错站的成因。

---

## 3. 上线后跟踪（`PostReleaseWatch`）

发版后要跟的东西，逐项写明**谁在什么时间窗内看什么**：

| 跟踪项 | 建议窗口 |
|---|---|
| 目标站点的目标页面实际渲染是否正常 | 发版后 30 分钟内逐站点开一遍 |
| 是否有站点被误推 | 发版后即刻核对实际生效的站点与 `TargetSites` |
| 运营配置是否被覆盖 | DTC §三 第 2 条：不得修改运营的线上配置项——发版后核对关键配置项仍是运营设的值 |
| 主流程功能（ATC / 结账） | 若本次触及主流程，实测下单链路 |
| 报错 / 控制台异常 | 目标页面控制台无新增报错 |

写"持续关注"不算跟踪项。

---

## 4. 线上问题分级与时效

| 类型 | 判据 | 时效 |
|---|---|---|
| **功能类** | 影响用户能否完成操作（加购、结账、表单提交、链接跳转、内容不显示） | **当天解决** |
| 样式类 | 只影响观感（间距、对齐、字号、颜色） | 进最近一次迭代 |

**边界情形按功能类处理**（更严的一档）：

- 移动端文字被裁切导致关键信息看不到 → 功能类（信息不可达）
- 按钮存在但样式错位到点不中 → 功能类
- 深色底上文字对比度不足读不清 → 功能类

### 紧急修复也要走完整链路

线上着火不构成跳过 QA 的理由（全路径红线⑧：最终交付必须经 `plaud-theme-qa`；「任何有改动的任务都不得跳过 Verify」）。正确链路：

```
线上 bug → feedback-triage 判归属 → 新工作项 → impact → 实现 skill
        → qa-intake → qa（ReadyForDelivery: Yes）→ release-ops → 推送
```

**最短合规路径**（着火时用这个，而不是绕过）：

| 环节 | 能压到多短 |
|---|---|
| Assess | 满足 `InlineLite` 四条件时可内联——**Assess 是唯一可豁免的阶段** |
| 提测包 | 仍要，但返工轮次以「本轮修改点 + 复现该 bug 的用例 + 目标断点截图」为主 |
| QA | **不可省**。可只跑 `RequiredQAProfile` + QA-Global，Theme Check 走 baseline 增量，通常几分钟。多块同批时**集成 QA 同样不可省**——它是消不掉的串行屏障 |
| release-ops | 站点清单二次确认**不可省**——着火时推错站是二次事故 |

用户坚持跳过 QA 时：**本 skill 不出发版清单，也不给"可以推"的结论**。如实说明缺哪些验证、风险是什么，给出上面这条最短路径；`ReleaseScope[].QAConclusion` / `QARef` 与顶层 `ReleaseQARef` 照实写"缺失"，**不得**伪造。推送本身是用户自己的动作，本 skill 既不代为执行也不为它背书。

---

## 5. 回归用例入库（`RegressionCasesAdded`）

> DTC §五 第 5 条：**每个线上 bug 反推一条回归用例入库 —— 同一个问题不允许出现第二次。**

| 要求 | 说明 |
|---|---|
| 数量 | **每个**线上 bug 至少一条，不是"这批问题写一条" |
| 格式 | 四段式 + 附件，见 `plaud-theme-qa-intake/references/test-case-format.md` |
| 内容 | 前置条件要能**复现原 bug 的那个配置状态**——这是这条用例存在的意义 |
| 归档 | 进测试集，随交付更新（DTC §一 第 3 条）。归档结果**写进工件字段 `TestSetTraceAfterArchive`**（handoff-schema §9.1.4）：稳定文档 ID 必须与 `plaud-theme-qa-intake` 提测时那份 `TestSetTrace` **同一个**，revision 取入库之后的新值，`Added` 段含本次新增的回归用例 ID。两处指向不同文档 = 没有长期测试集，视为未归档。本次无线上 bug 时填 `N/A(NoOnlineBug)` |

`RegressionCasesAdded` 为空 = 本次上线治理未完成，工件不得标记结束。

> ⚠️ **前提是「本轮有线上 bug」。** 本次上线后没有出现任何线上 bug 时，两个字段都取显式的 N/A，**不是留空**：`RegressionCasesAdded: N/A(NoOnlineBug)` + `TestSetTraceAfterArchive: N/A(NoOnlineBug)`。留空与 `N/A(NoOnlineBug)` 的区别就是「该补没补」与「确实不需要补」，工件必须能分清。

**反例**：修了「移动端区头没左对齐」的 bug，回归用例只写"检查区头对齐"——这没有复现条件。要写清是哪个模块、哪个实例、哪个存值状态、哪个断点下出的问题。
