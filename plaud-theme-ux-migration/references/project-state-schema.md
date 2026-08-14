# 项目状态文件 schema（`memory/*.md`）

## 为什么这三个文件不在 skill 包里

模板迁移状态、模块迁移状态、全局已知偏差是**项目运行时状态**，**不是规范**。它们随每一次迁移变化。

🔴 **写进 skill 包 = 下次 install 时被整包覆盖**（installer 对每个 skill 目录做 `rm -rf` 再展开），
真实迁移进度会被**一次安装抹掉**，后果是**重复迁移**（把已迁模块再刷一遍）或**漏迁**（以为已完成）。

所以它们必须存放在**项目侧** `memory/`，由项目维护：

| 文件 | 内容 | 维护者 |
|---|---|---|
| `memory/模板清单.md` | per-template：状态、section 渲染顺序、已迁模块、实例特殊约束 | `plaud-theme-ux-migration` + 用户 |
| `memory/模块清单.md` | per-module：后台名、实例数、迁移状态、schema 约束、关键字段 | `plaud-theme-ux-migration` + 用户 |
| `memory/全局已知偏差.md` | 跨模板共享的待评估项与已修项 | `plaud-theme-ux-migration` |
| `memory/changeset-log.md` | ChangeSetId → QA 结果 | `plaud-theme-qa`（**不是本 skill**） |

## 🔴 文件缺失时的处理：按 shared 的唯一初始化规则

**唯一事实源是 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表。本节只做转述，不自行规定；两边不一致时以 shared 为准。**

**开工前必须读**前三个文件。任一缺失 →

- **默认停机**，写进 `BlockingGaps`，问用户要文件 / 要路径
- **不得凭空重建一份**
- **仅当用户明确确认「这是首次接入、本项目没有历史迁移状态」后**，才可从 `references/memory-seed/` 复制种子初始化（见该目录 README），并**明确告知用户这是 2026-07 快照、需要人工核对当前真实状态**。复制之后，种子**不再是事实源**，项目侧的副本才是。
- `memory/changeset-log.md`（由 `plaud-theme-qa` 维护，本 skill 只读）缺失时：询问用户后可创建空日志——它是本矩阵自己产生的记录，不存在"历史状态丢失"问题。

> 凭空重建的清单**看起来完整、实际与真实进度脱节** —— 它会把"已迁"记成"待办"（导致重复迁移、覆盖掉别人验收过的成果），
> 或把"待办"记成"已迁"（导致漏迁）。**一份错的清单比没有清单更危险**，因为它会被下一个人当成事实。

---

## 🔴 完成态必须由 QA 背书（贯穿本文件所有状态列）

下面三张表里的**完成态标记**——`✅ DONE`、`已迁`（含 `✅` / `🟢`）、`**已修**`、`DONE`——**只能**在同时满足以下两条时写入（规则源：`plaud-theme-shared/SKILL.md`）：

1. `memory/changeset-log.md` 中存在对应的 `ChangeSetId`，且该块 QA 工件的 `ReadyForIntegration: Yes`，**并且存在一份覆盖它的、`ReadyForDelivery: Yes` 的 QA 工件**（单块直发时就是该块自己那份；多块批次里是那份 `QAScope: Integration` 的集成 QA 工件）
2. 该记录的身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）与当前逐字相等（未失效）
   📎 **v0.3.0 起「别的块把改动落进同一棵工作树」不算失效**：`ChangeSetScopeFingerprint` 只覆盖本块的声明路径；`git add` / `git reset` / commit（含 commit `memory/`）与仓库根 scratch 文件同样不再让它变。

**用户的视觉验收 ≠ QA 通过。** 用户说"看着对了"时，状态只能写成 **`视觉已确认，待 QA`**，不得推进为完成态。

`VisualAcceptance` 与 `QAStatus` 是两个**正交**状态，分开记：

| 状态 | 取值 | 谁来置 | 位置 |
|---|---|---|---|
| `VisualAcceptance` | `Pending` \| `Accepted` | 用户预览确认 | 本文件的三张表 |
| `QAStatus` | `Pending` \| `Valid` \| `Invalidated` | `plaud-theme-qa` | `memory/changeset-log.md` |

只有 `VisualAcceptance: Accepted` **且** `QAStatus: Valid`（即上面那两条背书条件都成立：该块 `ReadyForIntegration: Yes` + 覆盖它的 `ReadyForDelivery: Yes` 工件存在 + 身份三元组未失效）才写完成态。写完成态时**必须同时写上背书它的 `ChangeSetId`**，否则下一个人无从复核。

（这两组取值属于 `handoff-schema.md` §9.2 的 **`memory/` 记录字段**枚举，与阶段契约块的枚举是两套，互不通用；它们**不得**出现在 skill 回复末尾的阶段 yaml 块里。）

---

## 一、`memory/模板清单.md`

> 每完成一个模板加一行。**启动新模板审计前先看这张表。**

```markdown
# 模板清单（per-template metadata）

| 模板 | 状态 | section 渲染顺序 | 已迁移模块（在此模板内）| 实例特殊约束 / 历史遗留 |
| --- | --- | --- | --- | --- |
```

| 列 | 含义 | 填写规则 |
|---|---|---|
| **模板** | `templates/` 下的文件名（可省 `.json`） | 一模板一行；section group（如 `header`）也可占一行 |
| **状态** | `✅ DONE` / `🟡 进行中（<已完成的部分>）` / `👀 视觉已确认，待 QA（<ChangeSetId>）` / `待办` | 「进行中」必须括注**已完成到哪**，否则等于没写。🔴 **`✅ DONE` 需 QA 背书**：changeset-log 中有对应 `ChangeSetId`、该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、身份三元组未失效，并把该 ID 写进本格；用户只做了视觉验收时写 `👀 视觉已确认，待 QA` |
| **section 渲染顺序** | 按页面从上到下列出 section，`×N` 表示同模块多实例；**末尾括注 `（disabled：…）`** | 🔴 disabled 实例**必须单列在括号里**，与启用实例分开 —— 这张表是「日志按渲染顺序排模块」和「规则 1 跳过 disabled」的依据 |
| **已迁移模块（在此模板内）** | 本模板内已完成 spec 对齐的模块名 + 实例数 | 写「N 个：A / B / C」或「Multi WW ×5（4 迁 1 跳）」。🔴 只列**已获 QA 背书**的模块；仅通过视觉验收的另起一行写「待 QA：<模块>（<ChangeSetId>）」 |
| **实例特殊约束 / 历史遗留** | 该模板独有的、会影响下次迁移判断的事实 | 脏值、后台手填 HTML 不审、某实例跳过的原因、按 Figma 二次对齐的日期与范围、待评估项 |

## 二、`memory/模块清单.md`

> 每完成一个模块的迁移加一行。**启动新模块迁移前先看这张表。**

```markdown
# 模块清单（per-module metadata）

| 模块 (代码标识符) | Shopify 后台名 | 实例数 | 迁移状态 | 已知 schema 约束 | 关键 admin 字段 / 备注 |
| --- | --- | --- | --- | --- | --- |
```

| 列 | 含义 | 填写规则 |
|---|---|---|
| **模块（代码标识符）** | `"type"` 值 / section 文件名 | 与 `sections/<name>.liquid` 一致 |
| **Shopify 后台名** | 运营在 admin 里看到的名字 | 🔴 **写日志时用的就是这一列**（`migration-log.md` §6.5 措辞约束） |
| **实例数** | 全站实例数（可括注模板数） | **数据来自 `AssessmentRef`**，不在这里现数；变了要回写 |
| **迁移状态** | `✅` / `🟡 进行中（…）` / `👀 视觉已确认，待 QA（<ChangeSetId>）` / `待办` / `🟢 <日期> <一句话>` | 已迁的要写**迁到什么程度**（"已加 scheme 四件套 + 字号全 spec"），不要只打勾。🔴 `✅` / `🟢`（完成态）需 QA 背书：changeset-log 中该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、身份三元组未失效，并在本格写上该 `ChangeSetId`；只有视觉验收时写 `👀 视觉已确认，待 QA` |
| **已知 schema 约束** | 阻挡过 spec 值的 step / min / max / 默认值，以及放宽后的新值 | 空写 `—`；写成 `column_gap step 5→1、max 50→60、default 30→24` |
| **关键 admin 字段 / 备注** | 下次动这个模块必须知道的事 | 例外约定（不接 scheme / scheme 常开）、CSS 在哪个 bundle（是否 async）、模块级改动及其回归范围、已验收的设计特例、待评估项 |

> **备注列是本表的价值所在**：模块级改动（影响全站所有实例）必须在这里留痕，写清「改了什么 + 影响多少实例 + 日期」，
> 否则下一个人无从判断某个偏差是历史遗留还是刚引入的回归。

## 三、`memory/全局已知偏差.md`

> 跨模板共享的偏差与待评估项。**属于哪个模块说不清的，都归这里**（`migration-log.md` §7.4）。

```markdown
# 全局已知偏差 / 待评估（跨模板共享）

| 项 | 现状 | 状态 |
| --- | --- | --- |
```

| 列 | 含义 | 填写规则 |
|---|---|---|
| **项** | 偏差对象（token / 组件 / 全局行为） | 一句话可定位，如「富文本 H1–H6 字号」 |
| **现状** | 偏差的**事实描述**：现在是什么、spec 是什么、差多少 | 已修项写**原来**是什么，便于回溯 |
| **状态** | `待评估` / `已挂 <模块> 待评估` / `视觉已确认，待 QA（<ChangeSetId>）` / `**已修**：<怎么修的>（<ChangeSetId>）` / `DONE` | 🔴 「已修」必须写**怎么修的 + 影响范围**，不能只写"已修"。🔴 `已修` / `DONE` 是完成态，需 QA 背书（changeset-log 中该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、身份三元组未失效）并写上 `ChangeSetId`；只有视觉验收时写 `视觉已确认，待 QA` |

**归属判定**（与 `migration-log.md` §7.4 一致）：

| 类型 | 去处 |
|---|---|
| 单模块内未处理项 | `memory/模块清单.md` 该模块的备注列 + 日志里该模块对比表下方 |
| 跨模块全局议题（区头偏差、按钮档差合理性、富文本 H 标签字号等） | **本文件** + 日志的全局待评估段 |

---

## 四、什么时候写这三个文件

| 时机 | 写什么 |
|---|---|
| 认领模块 / 开始一个模板 | `模板清单` 状态改 `🟡 进行中`（**协调元数据，不受"验收后"约束**） |
| 改动完成、等验收 | **先不写**任何已迁 / 已修状态 |
| 🔴 用户**视觉验收通过**后（`VisualAcceptance: Accepted`） | 写迁移日志；三个文件的状态写成 **`视觉已确认，待 QA（<ChangeSetId>）`**。**不得**写 `✅ DONE` / `已迁` / `已修` |
| 🔴 `plaud-theme-qa` 给出该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、changeset-log 记为 `QAStatus: Valid` 且身份三元组未失效后 | 才把状态推进为完成态（`✅ DONE` / `已迁` / `已修`），并在该格写上背书它的 `ChangeSetId` |
| QA 结论因代码再变而失效（changeset-log 记为 `Invalidated`） | 把对应完成态**退回** `🟡 进行中` 或 `视觉已确认，待 QA`，等新 ChangeSet 的 QA 结论 |
| 发现新的跨模板偏差、但本轮不处理 | 立刻写进 `全局已知偏差`（状态 `待评估`）—— **这条不用等验收**，它是待办登记不是成果登记 |
