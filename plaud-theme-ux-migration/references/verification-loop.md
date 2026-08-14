# 第五步 — 实现侧验证闭环（自查，不替代 QA）

> 🔴 **本文件的检查全部是实现侧自查。** 通过它们**不代表**可交付 ——
> `ReadyForDelivery` 只能由 `plaud-theme-qa` 输出（`handoff-schema.md` §1）。
> 本 skill 恒输出 `QAStatus: NotRun` / `ReadyForDelivery: No`。

| 验证 | 工具 / 做法 | 谁负责 |
|---|---|---|
| **JSON 语法** | `node -e "JSON.parse(require('fs').readFileSync('<t>.json','utf8').replace(/^\s*\/\*[\s\S]*?\*\//,''))"`（跳过 Shopify 自动添加的注释头） | 本 skill 必跑（动过 `templates/*.json` 时） |
| **Schema 范围** | 改完用 Shopify admin 后台**保存试一下** —— `step` / `max` / `range` 限制**只有 admin 才会检查** | 本 skill 自查；QA 以 `AdminSchemaSave` 复验 |
| **Bundle 重 build** | 动过 `shopify-common` → `cd shopify-common && npm run build`；输出 `BuildRequired: Yes` | 本 skill 必跑 |
| **视觉回归点** | **列出**受影响的所有页面 + 断点（断点清单见 `plaud-theme-shared/references/responsive-and-spacing.md`） | 本 skill 只**列**；**实跑归 QA**（`RegressionMatrix` / `BreakpointsCovered`） |
| **Theme Check** | 判定方式是 **baseline 增量**、不是绝对 pass（见 `handoff-schema.md` §6） | **QA 实跑**；本 skill 只输出 `ThemeCheckRequired` |
| **共享 / 全局改动真实影响核查** | grep 枚举真实实例 + 逐个判断是否真触发，区分理论 blast radius 与实际受影响 | 🔴 **归 `plaud-theme-impact`**；本 skill **消费** `AssessmentRef`，不重算（机制说明见 `pitfalls-shared-scope.md` §4.6.1） |
| **多文件 diff 并行审查**（大改动收尾） | 见下 | 本 skill |

---

## 多文件 diff 并行审查（大改动收尾）

一轮改动横跨多文件时，收尾可**并行派若干审查 agent 分块跑 `git diff`**，各自按**三维**回报：

1. **功能 bug / 缺失** —— 断裂的 Liquid、token→class 剥离后**未补类的实例**（§4.15）、条件误伤
2. **断点一致性** —— 是否都用 spec 断点与 `.98` 精度，有无杂散历史整数值（§4.11；断点值见 shared `responsive-and-spacing.md`）
3. **冗余 / 死改** —— 无 CSS 的死类、死态 hover、**手改了生成文件**（§4.20）

🔴 **主 agent 必须汇总 + 逐条核实**：审查 agent **会记岔**（实测把无关文件误报成目标文件），
**先核实再定修法**，不要把 agent 的回报直接当结论写进 `ModifiedFiles`。

实测收益：这一步发现并修了 token→class 全实例回归。

---

## 收尾自检顺序

1. 跑 `hard-rules.md` §三「迁移前自检」里尚未打勾的项（尤其 dangling 引用扫描）
2. 跑本文件表格里属于本 skill 的检查
3. 生成 `ChangeSetId`（`CS-<YYYYMMDD>-C<NN>`）+ `ModifiedFiles`，**必须与工作树一致（`memory/` 除外）、且逐字精确**
   （自查用 `plaud_changeset_scope <逐字路径清单>`（每行一条，见 `handoff-schema.md` §2.5）；独占工作树时还可以跑 `plaud_declared_diff <BaseHeadSha> <清单>` 做归属自检。🔴 **不要用 `git status` / `git diff HEAD` 扫整棵工作树**：同树并行 Implement 下它会把兄弟块的改动误报成本块的文件；而且 v0.3.0 起主题改动 commit 掉不再让身份失效，commit 之后 `git diff HEAD` 会是空的。不一致 QA 会直接停机。
   🔴 `memory/` 下的迁移日志/清单更新**不列进** `ModifiedFiles`），
   并在交出工件那一刻**当场**算身份三元组 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`（函数见 `handoff-schema.md` §2.5，整段原样复制）——算完不要再改可发布面的内容。`BaseHeadSha` 不在这一刻取：它是**开工前**那个 baseline commit
4. 按 SKILL.md 的报告模板向用户汇报 → **等预览验收**
5. 用户视觉验收通过 → 写日志（`migration-log.md`），`memory/*.md` 状态写 `视觉已确认，待 QA（<ChangeSetId>）`
6. `plaud-theme-qa` 给出该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、且身份三元组未失效 → 才把 `memory/*.md` 推进为完成态（`✅ DONE` / `已迁` / `已修`）
