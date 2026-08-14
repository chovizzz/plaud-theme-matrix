# PLAUD Shopify Theme Matrix v0.1.0

Plaud 品牌 Shopify Online Store 主题开发的 **7 个 skill 矩阵**。它取代原来的单 skill
`plaud-shopify-theme` —— 同一份规范被拆成契约层、编排层、Assess / Implement / Verify 三阶段，
并按 Path A / B / C 三条路径分工。

矩阵接线、状态机与流程图见 [`MATRIX.md`](MATRIX.md)；给 agent 看的安装导航见 [`AGENTS.md`](AGENTS.md)；
版本变更见 [`CHANGELOG.md`](CHANGELOG.md)。

## 7 个 skill

| Order | Skill | 一句话 |
|---:|---|---|
| 0 | `plaud-theme-shared` | 契约层：两轴状态机、handoff schema、ChangeSetId 绑定、交付权归属、全路径红线、视觉/UX 基线索引 |
| 1 | `plaud-theme-orchestrator` | 全流程编排：路径判定、阶段推进、多块拆分与串并行、工件台账。**普通 bugfix 不绕它** |
| 2 | `plaud-theme-impact` | Assess：影响面侦察 —— 理论引用数 vs 实际受影响实例、依赖树、共享传播链、RiskTier |
| 3 | `plaud-theme-dev` | Path A Implement：bug、性能、新功能、UX 微调、A11y、code review |
| 4 | `plaud-theme-section-build` | Path B Implement：Figma → `sa-*` section，schema 与 vendor 规范 |
| 5 | `plaud-theme-ux-migration` | Path C Implement：UX Spec v1.3 迁移、刷模块、迁移日志 |
| 6 | `plaud-theme-qa` | Verify：Theme Check baseline 增量、5 断点回归、多语言、A11y、红线核查 —— **唯一有交付权** |

**该调哪个**：单个 bug / 性能 / UX 微调 → `plaud-theme-dev`；单个 Figma 稿 → `plaud-theme-section-build`；
单个模板或模块的 spec 迁移 → `plaud-theme-ux-migration`；只问影响面 → `plaud-theme-impact`；
只要验收 → `plaud-theme-qa`。

**只有当这件事必须拆成 ≥2 个能各自独立验收的 ChangeSet 时**才用 `plaud-theme-orchestrator`：
迁移 wave、多块并行/串行编排、Cross(A+C) 裂块。改共享 snippet / 全局 CSS / token
的**单一** ChangeSet 仍走 `plaud-theme-dev`；要走完 Assess → Implement → Verify 也不是理由 ——
那是每一块的正常链路。Cross(B+C)（按设计稿新建 section 且要符合 spec）是**一个** ChangeSet，
直接走 `plaud-theme-section-build`，只是 QA 多带一个 QA-C profile。

## 安装

> **先退役旧 skill，否则装不进去。** 见下一节 —— 这是硬前置，不是建议。

从本包根目录运行。不带参数即安装到全部四个客户端（`cursor,claude,codex,agents`）：

```bash
chmod +x install-macos-linux.sh
./install-macos-linux.sh
```

```powershell
.\install-windows.ps1
```

**先看一眼要发生什么**（不改动任何安装目标、备份位置或 skill，会如实显示是否会中止）：

```bash
./install-macos-linux.sh --dry-run
```

**只在某个客户端的 skills 目录还不存在时**才需要创建：

```bash
./install-macos-linux.sh --create-missing cursor,claude,codex,agents
```

安装器扫描根级目录里含 `SKILL.md` 的子目录，各自装到 `~/.<client>/skills/<skill-name>/`。
替换是**整目录替换**，不是合并：目标 skill 目录先被删掉再解包，所以 skill *内部*不会残留旧文件。
安装脚本自身与包根目录不会被装进 skills 目录。

### 退出码

| 码 | 含义 |
|---:|---|
| 0 | 成功 |
| 1 | 参数 / 配置错误 |
| 2 | **中止：检测到旧 skill 且未退役**——没装任何东西，也没删任何东西 |
| 3 | 用 `--keep-legacy` 装了，双规范并存，**UNSUPPORTED** |

三个要知道的限制：

- **只添加和覆盖，从不删除**（`--retire-legacy` 是唯一例外）。一个从新版本里删掉的 skill 会留在每个客户端目录里继续被路由到。
- **客户端 skills 目录不存在时会被静默跳过**，除非 `--create-missing` 点名它。本安装器会在结尾明确列出被跳过的客户端 —— 这是「我以为装好了」的主要来源。
- **它不比较版本**。安装结束后会打印四客户端的声明版本核对，但声明只是声明，真正的证据是目录 diff（命令由脚本打印）。

**不要用 `--clients` 缩小范围。** 不带参数已经默认四个客户端；只装子集正是 reddit 矩阵在
2026-07-29 撞到的客户端漂移（两个客户端落后两个版本，同一份 `memory/` 被两套规范处理）。

## 从单 skill `plaud-shopify-theme` 迁移

**旧的单 skill 必须退役，不能与矩阵并存。** 两者的 description 覆盖同一批触发词
（Plaud 主题、sections/snippets/assets、Swiper、Figma→sa-*、UX Spec v1.3 迁移…），
并存会产生**路由竞争**：同一个任务可能命中旧单 skill 的整体规范，也可能命中矩阵的分阶段契约，
于是同一个项目被两套规范同时处理 —— 这正是矩阵想消除的问题。

所以**退役旧 skill 是安装的前置条件，安装器 fail closed**：只要任一目标客户端还有
`plaud-shopify-theme/`，它就**中止安装、不写入任何 skill、也不删任何东西**，并以退出码 2 结束。
「警告一句然后照装不误」会让你拿到一个双规范并存的环境，而那正是拆矩阵要解决的问题本身。

四种调用形态：

| 形态 | 行为 | 退出码 |
|---|---|---:|
| 交互式终端，不带开关 | 询问「是否归档退役后继续安装？」；答 y → 退役 + 安装；答 n 或 EOF → 中止 | 0 / 2 |
| 非交互（CI / 管道 / `--yes`），不带 `--retire-legacy` | 直接中止，打印手动命令 | 2 |
| `--retire-legacy --yes` | 归档 → 校验 → 删除 → 安装 | 0 |
| `--keep-legacy` | 明知故犯地并存安装，打印醒目 UNSUPPORTED 警告 | 3 |

```bash
./install-macos-linux.sh --dry-run                  # 先看会不会被拦下
./install-macos-linux.sh --retire-legacy --yes      # 退役后安装（推荐）
./install-macos-linux.sh --keep-legacy              # 双规范并存（不推荐）
```

```powershell
.\install-windows.ps1 -DryRun
.\install-windows.ps1 -RetireLegacy -Yes
.\install-windows.ps1 -KeepLegacy
```

退役流程是**先归档、校验、再删除**，不做不可逆操作：

1. 旧 skill 整目录打包成 `~/.<client>/skills/.plaud-legacy-backup-<timestamp>/plaud-shopify-theme.tar.gz`（Windows 为 `.zip`）
2. 校验是**集合比对**：磁盘上每个文件都必须出现在归档里（归档条目富余不能掩盖缺文件）
3. 校验通过才删原目录；**校验不过就原地保留、什么都不删**
4. 归档目标已存在就跳过，绝不覆盖已有备份
5. 退役后**重新扫描**：只要还有任何残留（校验失败、归档已存在、symlink），**仍然中止安装**

恢复：`tar -C ~/.<client>/skills -xzf <archive>`（Windows：`Expand-Archive`）。

**legacy 是 symlink / junction 时**：脚本永不跟随、永不删除它，但它同样**阻断安装**，
必须先手动 `rm` 掉。脚本会把具体命令打出来。

安全边界：

- `--target` 解析后必须是最后一段正好为 `skills` 的目录（不是"路径里含 skills"）。为方便起见，
  传入客户端根目录且其下存在 `skills/` 时脚本会自动补上那一层；其余一律拒绝。
- 该校验器同时守安装与删除，并会**解析物理路径**：`skills` 本身或任一祖先是 symlink/junction
  时拒绝，避免删除逃逸到别的目录树。
- 删除前再次核验父目录合法、目录名在 legacy 白名单内、且该目录不是 symlink。
- `--backup-dir DIR` / `-BackupDir DIR` 可改备份基目录，脚本总会再追加一层带时间戳的唯一子目录
  并按客户端分目录；`/`、盘符根、家目录本身、以及被退役 skill 内部的路径会被拒绝。

**备份为什么是压缩包**：目录形式的备份里带着 `SKILL.md`，一旦某个客户端递归扫描隐藏目录，
路由竞争就又回来了。打成归档后，备份里不存在可被发现的目录级 `SKILL.md`。
本安装器扫描 skill 源时也显式跳过 `.` 开头的目录。

内容层面的迁移对照：

| 旧单 skill 里的东西 | 现在在哪 |
|---|---|
| Path A / B / C 判定 | `plaud-theme-shared`（契约）+ `plaud-theme-orchestrator`（跨路径编排） |
| 全路径红线、颜色/字体/断点/媒体基线 | `plaud-theme-shared/references/`（**唯一副本**，其它 skill 只引用不复制） |
| 改动前的影响面评估 | `plaud-theme-impact`（`AssessmentRef`） |
| Path A 的实现规则 | `plaud-theme-dev` |
| `sa-*` section / vendor 规范 | `plaud-theme-section-build` |
| UX Spec v1.3 迁移与踩坑规则 | `plaud-theme-ux-migration` |
| 验收清单、Theme Check、断点回归 | `plaud-theme-qa`（**唯一交付权**） |
| 模板清单 / 模块清单 / 已知偏差 | 移出包外，见下 |

## 项目状态文件（`memory/`，不随包分发）

模板清单、模块迁移状态、全局已知偏差、ChangeSet 日志属于**项目运行时状态**，不是规范。
写进包里会在下次 install 时被整包覆盖，所以它们只存在于项目侧：

- `memory/模板清单.md`
- `memory/模块清单.md`
- `memory/全局已知偏差.md`
- `memory/changeset-log.md`

缺失时 skill 会**停下问用户**，不会凭空重建一份。

## v0.1.0 关键变化

- 单 skill 拆成 **7 个**：契约层 / 编排层 / Assess / 三条路径的 Implement / Verify
- 引入 **ChangeSet 内容绑定**：`ChangeSetId`（`CS-<YYYYMMDD>-<path><NN>`）+ **`BaseHeadSha`** + **`ChangeSetFingerprint`**。实现 skill 交付时当场生成，QA 在**执行任何检查之前**三者全部重算比对。只绑文件名挡不住"交付后偷改同一批文件"——集合没变、内容变了，校验照样通过
- **交付权唯一**：只有 `plaud-theme-qa` 能输出 `ReadyForDelivery: Yes`；实现 skill 恒 `No` + `QAStatus: NotRun`，禁止终态措辞；orchestrator 输出的是 §9.1 协调工件，`AllChangeSetsDelivered` 只是汇总读数，不产生交付许可
- **Theme Check 改为 baseline 增量判定**：全仓绝对 pass 不可用（实测 3334 errors 里 3254 条是仓库级 `MatchingTranslations`）。改为**全仓跑两次** + 双指标 `addedInModifiedFiles` / `addedOutsideModifiedFiles`，**两者都须为 0**。不能只扫改动文件——删掉一个被引用的 asset / locale key，offense 会报在**未修改的调用方文件**里
- **只读任务需 `ReadOnlyProof`**：审计前后各取一次 `HEAD + git status` 快照，不一致即强制退出只读通道、生成正式 ChangeSet 走全流程。防止"先改代码再声称只是审计"
- **理论影响 ≠ 实际影响**：`TheoreticalReferences` 与 `ActualAffectedInstances` 必须分开报
- **项目状态移出包外**到 `memory/`
- 安装器 **legacy 退役改为 fail-closed**：检测到旧 `plaud-shopify-theme` 即中止安装（exit 2），必须显式 `--retire-legacy`（归档→集合校验→删除）或 `--keep-legacy`（exit 3，明知故犯）。另有 `--dry-run`、跳过客户端明示、安装后版本核对

详见 [`CHANGELOG.md`](CHANGELOG.md)。

## 已知取舍与局限

发布前跑过 6 个真实任务的行为评测（Path A）与 14 条路由探针，以下是**实测确认**的行为，不是推测：

| 现象 | 说明 |
|---|---|
| 随口说"改完了跑下检查"**可能不进 QA** | `plaud-theme-qa` 的触发被刻意收窄为「已有 `ChangeSetId`」**或**「明确要最终交付判定」，避免跟 `dev` 抢没有 ChangeSet 的只读 review。说清 ChangeSet（"这个 ChangeSet 改完了…"）或直接点名 skill 即可命中 |
| 指纹命令对 git 版本敏感 | 必须用 §2 原文（`--no-renames --binary` + `set -o pipefail`）。**`--find-renames=false` 在 git 2.52+ 是非法参数**，且错误走 stderr、管道继续，会算出一个只反映文件集合、不反映内容的常量——指纹退化成摆设。拿到 `FINGERPRINT_FAILED` 必须停机 |
| Path B / Path C 未做行为评测 | 6 个评测场景全在 Path A。B/C 的契约与 evals 齐备，但没有真实任务验证过 |
| `install-windows.ps1` 未实跑 | 仅静态审查。首次在 Windows 上用前先跑 `-DryRun -RetireLegacy` |
| `memory/` 四个文件需先建 | 缺失时 skill 会停机问你，不会凭空重建。首次接入可从 `plaud-theme-ux-migration/references/memory-seed/` 复制种子（那是 2026-07 快照，复制后即由项目维护） |
