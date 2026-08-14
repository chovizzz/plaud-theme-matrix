# 证据规则、QA 失效、changeset-log、用户豁免

---

## 1. 证据的最低形态

`Evidence` 字段不是叙述，是**可复核的取证记录**。每条至少含：检查项名 + 取证手段 + 结果。

| 取证手段 | 最低形态 | 反例（判 `Blocked`） |
|---|---|---|
| 命令 | 命令原文 + 输出摘要（含数字） | "跑了 theme check，没问题" |
| 代码阅读 | `文件:行号` + 该行内容或结论 | "看过 JS 了，清理没问题" |
| 视觉 / 运行时 | 页面 + 断点 + 观察到的现象 | "各断点都正常" |
| 上游引用 | 引用哪个工件的哪个字段 + 本次**复算**结果 | "按 Assess 说的" |

**三条硬规则：**

1. `Evidence` 里没有对应条目的检查项，无论标了什么值，一律降级为 `Blocked`。
2. `Passed` 需要正面证据；`NotApplicable` 需要"为什么不适用"的一句话；`Blocked` 需要"缺什么"。三者都不能空着。
3. **不允许把一句总结覆盖多项。** "已按 vendor §8–§11 检查" 不构成四项证据；每项各自成条。

### 允许的证据压缩

同一 grep 命中大量结果时，可写「命令原文 + 命中数 + 逐条裁定表（只列需裁定的）」，不必粘贴全量输出。但**命令原文与命中总数不能省**——它们是复核的入口。

---

## 2. QA 失效 — ChangeSetFingerprint

> QA 通过后代码再变，原 QA **自动失效**（handoff-schema §1.4）。

### 2.1 指纹算法在 shared，不在这里

`ChangeSetFingerprint` 的**唯一权威定义是 handoff-schema §2 里那段命令**。实现 skill 交工件时当场生成，QA 用**同一段命令**重算比对。

> 🔴 **照抄，不要自造变体。** 两边算的必须是同一个东西——改一个字符（换 hash 算法、加一个 `sort`、换 `--untracked-files` 取值）就永远对不上，QA 会把正常交付全判成失配。需要改进算法时改 shared，不要在本 skill 里分叉。

它覆盖：HEAD、工作树状态（含全部未跟踪文件）、tracked 内容 diff 的 hash、未跟踪文件逐个 `git hash-object` + 权限位。

### 2.2 算两次，写进 `FingerprintVerifiedAt`

| 时点 | 用途 |
|---|---|
| **Step 1（任何检查之前）** | 与上游 §4 工件里的 `ChangeSetFingerprint` 比对 → 决定 `ChangeSetIdMatched` |
| **所有检查完成后、写 changeset-log 之前** | 与 Step 1 比对 → 确认验证期间代码没变 |

`FingerprintVerifiedAt` 如实写两次的时点与值。只写"已核验" → 视为证据为空。

**顺序不能反**：§2 的命令用 `--untracked-files=all`，会把 `memory/changeset-log.md` 的改动算进去。**先算完 Step 2 指纹，再写 log**；反过来会把刚记录的结论当场写失效。

同理，QA 期间不要在仓库里留临时文件（tc-diff.js、tc-before.json 等一律放 scratchpad，见 `theme-check-gate.md` §5）——它们会进指纹，让 Step 2 无故失配。

### 2.3 两条补充门：指纹算不到的盲区

§2 的命令基于 `git status` / `git diff` / `git ls-files --others`，以下两类改动它**看不见**。QA 必须单独查，**命中后不得直接继续，必须按本节末尾的二选一处理**：

```bash
cd <theme-root>

# 门 1：assume-unchanged / skip-worktree —— 被标记文件的改动对 git 完全隐形
#       小写状态字母 = assume-unchanged，S = skip-worktree
git ls-files -v | grep -E '^[a-z] |^S '

# 门 2：submodule —— gitlink 指向的子模块内部变化不进指纹
#       只看 .gitmodules 不够：它可能本轮被删、或仓库残缺但索引里仍有 160000
[ -f .gitmodules ] && echo ".gitmodules 存在"
git ls-files -s | awk '$1=="160000"{print "gitlink: " $4}'
```

处理方式二选一，**没有第三种**：① 解除索引标志 / 对每个 submodule 递归取指纹并把结果并入 `Evidence`，此时可继续；② 做不到 → `ReadyForDelivery: No` + `BlockingGaps` 写明。**不得**当作"没问题"继续。

### 2.4 为什么不用 mtime

```
git checkout / 格式化工具 / 编辑器保存  → mtime 变了但内容没变（误判失效）
touch 之后又改回内容                    → 内容变了但 mtime 可能一致（漏判）
```

一律按内容判定，不看时间戳。

### 2.5 CRLF / clean filter

`.gitattributes` 配了 `text=auto` 或自定义 clean filter 时，工作树字节与仓库对象字节不同。§2 的命令走 `git hash-object` / `git diff`（仓库侧语义），前后两次一致，所以判定不受影响。但 **baseline worktree 里同一文件可能被 checkout 成不同行尾**，这会影响 theme check 的差集。`git check-attr text -- <files>` 显示有转换时，在 `ThemeCheckEvidence` 里注明。

### 2.6 已知限制（v0.1）：这是仓库状态指纹，不是纯内容指纹

handoff-schema §2 的规范命令里含 `git status --porcelain=v1`，它输出的 `XY` 两列同时反映**索引**与**工作树**状态。因此：

> **仅改变 staging 的 `git add` / `git reset` 也会改变指纹**，即使 `git diff HEAD` 的最终内容一字未变。

这是**保守型失效**——它只会把"其实没变"误判成"变了"，不会把"变了"误判成"没变"，所以不构成漏报。

处置规则：

- **QA 不得因为"我觉得内容没变"就绕过失配。** 失配即 `ChangeSetIdMatched: No`，停机要求上游重新生成。
- 想改成纯内容语义，**必须在 shared 里统一升级**，并同步全部 producer skill、QA、changeset-log 与 eval。**禁止任何单个 skill 自行变体**——producer 与 verifier 算的必须是同一个规范对象，局部分叉会把正常交付全判成失配。

---

### 2.7 失效后的处理

1. 把 changeset-log 中该行 `Status` 改为 `Invalidated`，`Note` 写失效原因。
2. 要求实现 skill 生成**新的** `ChangeSetId` + `ChangeSetFingerprint` + `BaseHeadSha`。
3. **整轮重跑**，不允许"只补验变动的那部分"——同族 bug 与传播链正是靠全量重跑抓到的，增量补验会系统性漏检。

---

## 3. `memory/changeset-log.md`

**项目侧文件，不随包分发**（写进包里会在下次 install 被整包覆盖）。位置由项目决定，通常是仓库根的 `memory/changeset-log.md`。

文件不存在时：按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」表执行——**`changeset-log.md` 询问用户后可创建空日志**（它是本矩阵自己产生的记录，不存在"历史状态丢失"问题）。**不要凭空重建历史记录**（不得补写从没跑过的 QA 行）。

其余三个迁移状态文件（`模板清单.md` / `模块清单.md` / `全局已知偏差.md`）缺失是**默认停机**，且由 `plaud-theme-ux-migration` 处理，本 skill 不写它们。本节只引用 shared 的那张表，不自行规定；两边不一致时以 shared 为准。

### 格式

```markdown
# ChangeSet QA Log

| ChangeSetId | Path | QAProfilesRun | ReadyForDelivery | RunAt | ChangeSetFingerprint | Status | Note |
|---|---|---|---|---|---|---|---|
| CS-20260806-A03 | A | QA-A, QA-Global | Yes | 2026-08-06T14:22+08:00 | a1b2c3d4e5f6 | Valid | ThemeCheck 新增 0 |
| CS-20260806-C11 | C | QA-C, QA-Global | No  | 2026-08-06T16:05+08:00 | 9f8e7d6c5b4a | Valid | QA-C 首项 Failed：字号总览含 disabled 实例 |
| CS-20260805-A01 | A | QA-A, QA-Global | Yes | 2026-08-05T11:40+08:00 | 4d3c2b1a0f9e | Invalidated | 2026-08-06 工作树再次变动，需新 ChangeSetId |
```

规则：

- **每次 QA 都追加一行**，包括 `ReadyForDelivery: No` 的和被豁免的——失败记录同样有追溯价值。
- `ChangeSetFingerprint` 取 handoff-schema §2 那段命令算出的 hash 的前 12 位（全长写进正文 `Evidence` / `FingerprintVerifiedAt`）。
- `Status` ∈ `Pending` / `Valid` / `Invalidated`（`handoff-schema.md` §9.2 的 **`memory/` 记录字段**枚举，对应那里的 `QAStatus`）。只追加与改 `Status`，**不删除历史行**。
  - `Pending` — 已登记但结论尚未落定（例如等补证据）
  - `Valid` — 该行的 QA 结论当前仍有效（指纹未失效）
  - `Invalidated` — 代码已再次变化，该 QA 结论失效
- 🔴 **这三个取值是 `memory/` 记录字段的合法枚举，但绝不允许出现在 §5 的阶段契约 yaml 块里。** §9.2 明文分两套：阶段契约字段的 `QAStatus` 只有 `NotRun` / `Skipped(UserWaived)`（且 §5 的块里**根本没有** `QAStatus` 字段），`Invalidated` / `Valid` / `Pending` 只活在 `changeset-log.md`。往契约块塞 `Invalidated` 是自造取值，违反契约首条。
- 一个 `ChangeSetId` 重跑 → 新增一行，旧行标 `Invalidated`，不覆盖。
- **本文件不排除在指纹之外**（§2 的规范命令用 `--untracked-files=all`，没有 `EXCLUDE` 机制，也不许自造）。靠**顺序**规避自失效：先算完 Step 2 指纹，再写这个 log，见 §2.2。

---

## 4. 用户要求跳过验证（豁免）

用户明说"不用检查了直接发""我赶时间，跳过 QA"：

**仍不得输出 `ReadyForDelivery: Yes`。** 交付权的含义是"验证通过才能说可交付"；用户可以放弃验证，但不能让 QA 改口。

### 关键约束：`QAStatus` 不进 §5 yaml 块

handoff-schema 开头明令「任何 skill 都不得自行定义字段、改字段名、或新增终态词汇」，且 §5 的字段表里**没有** `QAStatus`——它只出现在 §4（实现 skill 的工件）。所以：

- **§5 yaml 块保持纯净**，只含 §5 定义的 19 个字段，一个不多。
- `QAStatus: Skipped(UserWaived)` 写在**正文**里（handoff-schema §1 条款 5 的措辞），不写进 yaml 块。
- 豁免事实同时体现在 §5 的既有字段中：`QAProfilesRun: None`、各检查项 `Blocked`、`Evidence: 无 —— 用户要求跳过验证`、`BlockingGaps: 全部验证项未执行（UserWaived）`。

正文形态：

```
已按用户要求跳过验证（QAStatus: Skipped(UserWaived)）；未经验证的改动上线风险由用户承担。
```

对应的 §5 块：

```yaml
ChangeSetId: <上游给的，没有就写 Unknown>
ChangeSetIdMatched: <Yes | No —— 封闭枚举只有这两个值；未校验时填 No，理由进 BlockingGaps>
FingerprintVerifiedAt: 未执行（用户豁免，Step1/Step2 均未重算）
QAProfilesRun: None
ThemeCheck: Blocked
ThemeCheckEvidence: 用户豁免，未执行
ThemeRuntimePreview: Blocked
AdminSchemaSave: Blocked
RegressionMatrix: Blocked
BreakpointsCovered: None
LocalizationCheck: Blocked
A11yCheck: Blocked
FixedDimensionCheck: Blocked        # ⚠️ 见下「三项枚举缺口」
ImageQualityCheck: Blocked          # ⚠️ 同上
CopyConfigurabilityCheck: Blocked   # ⚠️ 同上
ProfileSpecificResults: 全部 Blocked（用户豁免，未执行）
Evidence: 无 —— 用户要求跳过验证
BlockingGaps: 全部验证项未执行（UserWaived）
ReadyForDelivery: No
```

> ⚠️ **`ChangeSetIdMatched` 没有 `Blocked`。** §9.2 的封闭枚举只有 `Yes` / `No`。校验没跑或跑不了一律填 `No`（"未确认匹配"就是"不匹配"，保守方向），原因写进 `BlockingGaps`。往这个字段塞 `Blocked` 是自造取值。

> 🔴 **三项枚举缺口 —— 这是 shared 内部的自相矛盾，不是本 skill 的自造取值。**
>
> `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 在 handoff-schema 里被规定了两次，两次不一致：
>
> | 出处 | 规定 |
> |---|---|
> | **§5 开头** | 「每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`」——**含 `Blocked`** |
> | **§9.2 枚举表** | 这三项只有 `Passed` / `Failed` / `NotApplicable`——**不含 `Blocked`** |
>
> **本 skill 按 §5 执行**（§5 是专门定义本阶段工件的条款，更具体；这与 `NotApplicable` 那条歧义的收口方式一致）：用户豁免 / ChangeSet 失配时这三项确实**没有执行**，照实填 `Blocked`，并在 `BlockingGaps` 里显式登记这一契约歧义。
>
> **三条不得越界的红线：**
> 1. **绝不**改填 `NotApplicable` —— 未执行伪装成"不需要验"，是最直接的绕过交付门方式。
> 2. **绝不**改填 `Passed`。
> 3. **绝不**改填 `Failed` —— `Failed` 的语义是"验了且发现缺陷"。把未执行写成 `Failed` 会让实现 skill 去追一个不存在的缺陷，是另一种失真；用错误的取值换取形式合规不划算。
>
> **收口必须由 shared 做**（把 `Blocked` 加进这三项的 §9.2 枚举，或为"未执行"另设取值），本 skill 无权修改 shared。每次出现时在正文提示矩阵维护者。无论取哪个值，`ReadyForDelivery` 恒为 `No`，交付门本身不受影响。

不劝说、不重复、不列举"你可能会遇到的 12 种问题"。用户已经做了决定，QA 的职责是留下准确记录，不是说服。

changeset-log 照常追加一行，`ReadyForDelivery` 填 `No`，`Note` 写 `UserWaived`。

### 部分豁免

用户说"theme check 就别跑了，其它照跑"：被豁免项标 `Blocked`（原因写"用户豁免"），其余照常执行。因为有 `Blocked`，`ReadyForDelivery` 仍是 `No`。**没有"除了 X 项之外全部通过所以算通过"这种折算。**

---

## 5. 常见规避话术与对应判定

| 话术 | 正确判定 |
|---|---|
| "代码逻辑上看没问题" | 不是证据。相应项 `Blocked` |
| "这个改动很小，不用跑 theme check" | `ThemeCheckRequired` 由文件类型决定，不由改动大小决定 |
| "本地跑不了预览，但静态检查过了" | `ThemeRuntimePreview: Blocked`，不得用 `ThemeCheck` 顶替 |
| "5 个断点里有两个看着一样，看一个就行" | `BreakpointsCovered` 必须五档齐；少一档 → `RegressionMatrix: Blocked` |
| "德语测试上次做过了" | 上次不是本 ChangeSet。本轮未做 → `Blocked` |
| "只有 warning，没有 error" | 本次新增的 offense 不分 severity，一律 `Failed` |
| "顺手把另一个 bug 也修了" | ChangeSet 失配 → Step 1 停机，要求重新生成 |
| "这条 offense 原来就有" | 要给出 baseline 里的对应条目（check + message + 行号）才成立，见 `theme-check-gate.md` §6 |
| "删的那个文件没人用" | 要给出 §7 的全仓 basename 扫描原文 + 运行时预览结论 |
| "我只是 git add 了一下，代码没变" | 有可能——指纹是仓库状态指纹，不是纯内容指纹（见 §2.6）。但失配就是失配：QA 不得自行放行，要求上游重新生成 |
| "基本都过了" | 无中间态。任一 gate 字段非 `Passed`/`NotApplicable` → `ReadyForDelivery: No` |
