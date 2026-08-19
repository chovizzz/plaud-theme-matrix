# PLAUD Shopify Theme Matrix v0.3.6

Plaud 品牌 Shopify Online Store 主题开发的 **10 个 skill 矩阵**。它取代原来的单 skill
`plaud-shopify-theme` —— 同一份规范被拆成契约层、编排层、Assess / Implement / Verify 三阶段，
并按 Path A / B / C 三条路径分工。

矩阵接线、状态机与流程图见 [`MATRIX.md`](MATRIX.md)；给 agent 看的安装导航见 [`AGENTS.md`](AGENTS.md)；
版本变更见 [`CHANGELOG.md`](CHANGELOG.md)。

## 10 个 skill

| Order | Skill | 一句话 |
|---:|---|---|
| 0 | `plaud-theme-shared` | 契约层：两轴状态机、handoff schema、ChangeSetId 绑定、交付权归属、全路径红线、视觉/UX 基线索引 |
| 1 | `plaud-theme-orchestrator` | 全流程编排：路径判定、阶段推进、多块拆分与串并行、工件台账。**普通 bugfix 不绕它** |
| 2 | `plaud-theme-impact` | Assess：影响面侦察 —— 理论引用数 vs 实际受影响实例、依赖树、共享传播链、RiskTier |
| 3 | `plaud-theme-dev` | Path A Implement：bug、性能、新功能、UX 微调、A11y、code review |
| 4 | `plaud-theme-section-build` | Path B Implement：Figma → `sa-*` section，schema 与 vendor 规范 |
| 5 | `plaud-theme-ux-migration` | Path C Implement：UX Spec v1.3 迁移、刷模块、迁移日志 |
| 6 | `plaud-theme-qa-intake` | 提测准入：DTC §四 六项交付物、站点清单、包指纹 —— **材料不齐 QA 不启动** |
| 7 | `plaud-theme-qa` | Verify：Theme Check baseline 增量、5 断点回归、多语言、A11y、红线核查 —— **唯一有交付权** |
| 8 | `plaud-theme-feedback-triage` | 反馈归因：交付缺陷 vs 需求演进、依据、去向、Linear 状态建议 —— **判定人是 PM** |
| 9 | `plaud-theme-release-ops` | 发版与上线后：推站二次确认、PR、线上 bug 时效、回归用例入库 |

**该调哪个**：单个 bug / 性能 / UX 微调 → `plaud-theme-dev`；单个 Figma 稿 → `plaud-theme-section-build`；
单个模板或模块的 spec 迁移 → `plaud-theme-ux-migration`；只问影响面 → `plaud-theme-impact`；
只要验收 → `plaud-theme-qa`；提测材料齐不齐 → `plaud-theme-qa-intake`；这条反馈算缺陷还是变更 →
`plaud-theme-feedback-triage`；要发版推站 / 上线后 bug → `plaud-theme-release-ops`。

**只有当这件事必须拆成 ≥2 个能各自独立验收的 ChangeSet 时**才用 `plaud-theme-orchestrator`：
迁移 wave、多块并行/串行编排、Cross(A+C) 裂块。改共享 snippet / 全局 CSS / token
的**单一** ChangeSet 仍走 `plaud-theme-dev`；要走完 Assess → Implement → Verify 也不是理由 ——
那是每一块的正常链路。Cross(B+C)（按设计稿新建 section 且要符合 spec）是**一个** ChangeSet，
直接走 `plaud-theme-section-build`，只是 QA 多带一个 QA-C profile。

## 包内附带工具 skill（不占 order）

除 10 个矩阵 skill 外，包里还随装一个**附带工具 skill**。它**不属于矩阵**：不占 order、
不进路由判定树、没有 `matrix-contract.md`，也不产出/消费 `ChangeSetId`、`HandoffContract`
这些契约字段。放进同一个包只是为了一条命令装完整套工具链。

| Skill | 干什么 | 为什么不在矩阵里 |
|---|---|---|
| `yidian-draft-pr` | 把选定的 commit cherry-pick 到一条新分支，按 yidian 必填 PR body 开一个 **Draft PR**（base 分支不限） | 它操作的是 git / GitHub，不是主题代码；不读矩阵状态、不替矩阵做任何判定。用户要开 PR 时才加载，矩阵不会路由到它 |

`version-manifest.md` 里的「skill 数 = 10」只数矩阵 skill；附带 skill 在那里单列。

**它保留的护栏**：只建 Draft PR、只 cherry-pick 不 merge 整条分支、只推 PR 分支不直推 base 分支、
PR body 五段必填（Summary / Test Plan / Risk-Rollback / Regression Matrix / Commits）、
**只让 Shopify 主题代码进 PR**（v0.3.3 起：垃圾文件直接剔除，其余非主题文件逐条问用户）。
**它不再限制的**：base 分支白名单与「`main` 仅 `chovizzz` 可用」的判定，v0.3.2 起任意 base 都能开 PR。

## 安装

**一条命令，装最新发布版**（四个客户端全装：`cursor` / `claude` / `codex` / `agents`）：

```bash
# macOS / Linux / WSL / Git Bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh
```

```powershell
# Windows PowerShell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1)))
```

> 🔴 **Windows 这行不能简写成 `irm ... | iex`** —— `iex` 传不了参数，`-Ref` / `-Check` 一律进不去。
> 要传参数就必须用上面的 scriptblock 形式。

仓库是**公开**的，所以这两条命令都不需要任何鉴权 —— 不用 token、不用登录、不用 SSH key。

**钉一个版本**（复现某次交付时用这个，别用「最新」）：

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --ref v0.3.6
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -Ref v0.3.6
```

**自检**（装了什么版本、树是否逐文件一致、有没有陈旧残留）：

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --check
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -Check
```

**回滚到旧 tag** —— 就是把 `--ref` 指回去再装一次，然后自检：

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --ref v0.2.2
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --check
```

回滚**不会**自动删掉新版才有的 skill —— 安装器绝不删除它没在装的东西。`--check` 会把它们逐个
列成 `STALE SKILL`，按提示手动 `rm -rf` 掉。**这一步不能省**：新版删掉的 skill 留在客户端会继续被
路由，等于同一份 `memory/` 被两套 spec 处理。

### 参数

sh 与 PowerShell 两边**同名同义**：

| sh | PowerShell | 含义 |
|---|---|---|
| `--ref v0.3.6` | `-Ref v0.3.6` | 装哪个发布 tag。缺省 = 最新 tag；**解析不出来就报错，绝不静默装 `main`** |
| `--check` | `-Check` | 自检，不安装 |
| `--dry-run` | `-DryRun` | 只报告要做什么，不碰任何安装目标 |
| `--clients cursor,claude` | `-Clients cursor,claude` | 只装子集（**不推荐**，见下） |
| `--create-missing all` | `-CreateMissing all` | 客户端 skills 目录不存在时创建它 |
| `--repo <url>` | `-Repo <url>` | 换仓库（fork / 私有镜像） |

`--retire-legacy` / `--keep-legacy` / `--yes` 见下一节「从单 skill 迁移」。

**不要用 `--clients` 缩小范围。** 不带参数已经默认四个客户端；只装子集正是 reddit 矩阵在
2026-07-29 撞到的客户端漂移（两个客户端落后两个版本，同一份 `memory/` 被两套规范处理）。

### 装到哪里、怎么替换

安装器取该 tag 的**归档包**（`codeload.github.com` 的 tar.gz / zip，**不需要本机有 git**），
扫描根级目录里含 `SKILL.md` 的子目录，各自装到 `~/.<client>/skills/<skill-name>/`。

替换是**整目录替换**，不是合并，而且走的是**事务式**流程：

1. 先解包到该 skills 目录内部的 `.plaud-staging-*`（同一块盘，**此时线上目录一个字节没动**）
2. 逐文件核对暂存树与包一致（路径 + 类型 + 内容）
3. 打上 `.plaud-install-inprogress` 标记，再逐个 `rm -rf` 旧目录 + 移入新目录
4. **安装后再逐文件比对一次**：目标多出来的文件即上个版本的陈旧残留，直接判失败
5. 写 `.plaud-installed-ref`（tag、commit sha、安装时间、本次安装的 skill 清单、来源）
6. 清掉 in-progress 标记

所以：**第 2 步之前失败，客户端完全没被碰过**；失败在第 3 步之后，`.plaud-install-inprogress`
会留在原地，`--check` 会把这个客户端报成「INTERRUPTED INSTALL」，而不是报「一致」。

安装脚本自身不会被装进 skills 目录。

### `--check` 到底验什么

`.plaud-installed-ref` 只是一个**声明**，永远不当证据用 —— 手改它骗不过 `--check`，因为树每次都会
按 ref 重新逐文件比对。具体四项：

1. 该客户端**声明**装的 tag / commit / 时间 / 来源
2. 与该 ref 的树**逐文件比对**：路径、类型、以及**内容字节**（等价于过去手工跑的 `0/10` tree diff）
3. **陈旧 skill**：仓库该 ref 里已经没有、客户端却还留着且仍会被路由的 skill
4. **中断的安装**：残留的 `.plaud-install-inprogress`、残留的 `.plaud-staging-*`、
   或还占着的 `.plaud-install-lock`

marker 里的 `commit:` 也会跟该 tag **当前实际指向的 commit** 比对 —— tag 被移动过、
或 marker 被伪造，都会报 `COMMIT MISMATCH`。marker 被清空、被换成目录、或 `ref:` 被改成
一个分支名（想让 `--check` 去按分支取树），一律判为「provenance unproven」并非零退出。

只比文件名是不够的 —— 实测 v0.2.2 与 v0.2.3 的**文件名清单完全相同**，只有内容不同；
只比清单的话会把一个装错版本的客户端报成「一致」。

### 同时跑两个安装

不行，也不该。安装器在每个 skills 目录用 `mkdir` 原子地占一把 `.plaud-install-lock`：
第二个进程直接失败退出（rc=1），不会跟第一个交错 swap。**它绝不会自动删掉不是自己创建的锁**
—— 崩溃留下的锁必须人看一眼再手动 `rmdir`，因为另一种做法是在一个未知的半成品状态上继续覆盖。

### 想先看一眼脚本再跑

`curl … | sh` 这种流式执行看不到 curl 的退出码。脚本本身做了截断防护（全部语句在函数里，
唯一的顶层动作是最后一行的 `main "$@"`，截断即什么都不跑），但要完全掌控就先下载再执行：

```bash
curl -fsSL -o /tmp/plaud-install.sh https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh
less /tmp/plaud-install.sh          # 看一眼
sh /tmp/plaud-install.sh --ref v0.3.6
```

### WSL / Git Bash 与 PowerShell 不要互相污染

同一台 Windows 机器上两边装的是**两个不同的 HOME**：sh 版落到 `$HOME/.cursor/skills`
（WSL 里是 Linux 家目录），PowerShell 版落到 `$env:USERPROFILE\.cursor\skills`。
两边各自独立，各自 `--check`。挑一边用，别来回换。

### 退出码

| 码 | 含义 |
|---:|---|
| 0 | 成功 |
| 1 | 参数错误，或安装失败（包括部分失败：会打印 `FAILED: X of Y clients installed`） |
| 2 | **中止：检测到旧 skill 且未退役**——没装任何东西，也没删任何东西 |
| 3 | 用 `--keep-legacy` 装了，双规范并存，**UNSUPPORTED** |
| 4 | `--check` 发现问题 |

### 三个要知道的限制

- **只添加和覆盖，从不删除**（`--retire-legacy` 是唯一例外）。一个从新版本里删掉的 skill 会留在
  每个客户端目录里继续被路由到 —— 所以装完**必须**跑一次 `--check`，它会把这些列成 `STALE SKILL`。
- **客户端 skills 目录不存在时会被跳过**，除非 `--create-missing` 点名它（或 `all`）。安装器会在结尾
  明确列出被跳过的客户端 —— 这是「我以为装好了」的主要来源。
- **`--ref` 缺省依赖 GitHub API**。离线、被限流、或仓库还没有 tag 时，安装器**报错退出**，
  不会退回去装 `main`（未评审的 `main` 不是一个发布）。这时显式给 `--ref v0.3.6`。

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
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --dry-run                  # 先看会不会被拦下
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --retire-legacy --yes      # 退役后安装（推荐）
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --keep-legacy              # 双规范并存（不推荐）
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -RetireLegacy -Yes
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -KeepLegacy
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

## v0.3.5 关键变化

**更新检查现在也由 skill 调用触发，四端都覆盖到**（v0.3.4 只有 Claude Code 的会话钩子）。
矩阵的每个 skill 开工前会跑一行 `plaud-matrix-update guard`：不阻塞（后台联网，主进程
0.1 秒内返回）、不写 stdout、同一版本只提醒一次、失败静默。

**它不会在 skill 运行中替换文件。** social-hub CLI 敢边跑边升级是因为有进程边界
（本次旧代码跑完、下次新进程生效）；skill 是文件，没有这个边界，中途替换会让 agent
拿着旧 SKILL.md 去读新 reference。所以：**skill 调用只检查和提示，安装发生在下一次
新会话或你显式 `plaud-matrix-update apply --yes`**。

关掉：`PLAUD_NO_UPDATE_CHECK=1`（不检查）、`PLAUD_NO_AUTO_UPDATE=1`（只提示不装）、
`CI=true`（自动跳过）。

⚠️ 已知边界：cursor 的 workspace 级 skill 会遮蔽全局安装，guard 更新的是全局副本。

## v0.3.4 关键变化

**自动更新。** 装了包之后不用再手动跑 `curl | sh`：开一个**新的** Claude Code 会话时，
hook 会查有没有新版本，**声明为兼容的就直接装上**，并在会话里留一行说明。默认关闭：

```bash
sh install.sh --enable-auto-update      # 开
sh install.sh --auto-update-status      # 看状态
sh install.sh --disable-auto-update     # 关
```

**带破坏性变更的版本不会自动装** —— 只提示，等你 `plaud-matrix-update apply --yes`。
判据是发版时写进 `release-meta.json` 的 `compatibility` 字段，不是版本号，也不是
`ContractVersion`（本包每个 patch 都会递增它，拿它判会把所有 patch 误判成破坏性）。
拿不准一律不装：没有 metadata、版本对不上、skill 有增删、本地树与自称版本对不上、
另一个会话正在更新，全都只提示。没网就闭嘴，绝不因为更新失败挡住你开工。

只在 `startup` 事件安装：resume / compact 时会话已经读过 skill，那时换文件会让同一次
会话前后按两套规则工作。

**vendored 副本是另一个开关**（`plaud-matrix-update vendor add …`）：注册主题仓后，
每次更新会在那边开一个 Draft PR 同步 CI 用的矩阵副本。更新自己的机器和往共享仓推分支
是两回事，所以分开开启。

## v0.3.3 关键变化

`yidian-draft-pr` 新增**改动文件门禁**：只有 Shopify 主题代码能进 PR。
`.DS_Store` / `.claude/` / 缓存 / 备份这类垃圾文件直接剔除不问；`.github/`、`scripts/`、
`docs/`、锁文件、顶层 md 这类**逐条问用户**，确认一条放行一条；`config/settings_data.json`
虽是主题文件但属环境状态，同样要确认。**删 junk 不阻断**（专门删 `.DS_Store` 的 PR 该放行），但删一个非主题路径仍要确认。

门禁在 push 前（`check_theme_files.py`）和建 PR 前（`create_draft_pr.py`，`--dry-run` 也跑）
各跑一次，共用同一份分类实现，**没有跳过开关**；**看不见 diff 时一律拒绝而不是放行**（不在 git
仓库、ref 解析失败、`--repo` 指向的不是本地 remote、空 diff）。建 PR 前还要求 head 分支已推送
且远端与本地同一个 commit，否则 PR 会带上门禁没看过的代码。裸 `gh pr create` 兜底路径已删除
—— 它会绕过全部检查。测试见 `yidian-draft-pr/tests/test_theme_files.py`。

## v0.3.2 关键变化

**包里多了一个 skill 目录，矩阵还是 10 个。** 新增包内附带工具 skill `yidian-draft-pr`
（cherry-pick 选定 commit → 开 Draft PR），它不占 order、不进路由、不碰契约字段，
定位见上面「包内附带工具 skill」一节。它的 **base 分支白名单与「`main` 仅 `chovizzz`」
判定已去掉**，任意 base 都能开 PR；Draft-only、独立 PR 分支、PR body 五段必填这几条护栏
保留；后两条脚本能兜底一部分（`--head` 必填且不得与 `--base` 同名、body 五段行首标题缺一即拒），
但脚本不查 git，「head 是不是一条干净的新分支」仍靠 skill 工作流保证。

安装器 `--check` 的 stale 扫描加了一个附带 skill 名单 —— 否则从 v0.3.2 回滚到旧 tag 时，
这个不带 `plaud-theme-` 前缀的目录会留在盘上继续被路由而不被报告。

`ContractVersion` 按约定同步递增到 v0.3.2（契约语义未改，只是版本戳）；顺带修掉 v0.3.1
漏改的 `plaud-theme-shared/evals` 两处 `v0.3.0` 残留。

## v0.3.1 关键变化

纯**路由口径修正**（patch），字段、枚举、指纹模型一字未改。

`plaud-theme-dev` 的直接下游在契约里早就是 `plaud-theme-qa-intake`（提测准入，v0.2.0 起），
但包里有七处仍写着实现工件直接交 `plaud-theme-qa` —— dev 的收尾句、dev 的 frontmatter 路由文本、
dev 的下游表、orchestrator 正文与它的 `orch-05` eval、`MATRIX.md` 的消费者列、`AGENTS.md`。
矛盾的后果是实现工件可能**绕过提测准入**直接进验收。全部改为 `dev → qa-intake → qa`。

只改路由口径，不动权限口径：验证仍由 QA 执行，`ReadyForDelivery: Yes` 仍然只有 QA 能给。

另新增 `dev-16-next-required-skill-is-intake` —— dev 原有 15 条 eval 一条都没覆盖 intake 路由，
这正是这个矛盾能活下来的原因。`ContractVersion` 按约定同步递增到 v0.3.1。

## v0.3.0 关键变化

**契约层破坏性变更：ChangeSet 身份从「工作树状态文本的 SHA-256」改绑「不可变 git tree 对象的 oid」。**
这是 v0.2.3 里那条「彻底解法留 v0.3.0」的兑现，跨版本**不兼容**。

- **`ChangeSetFingerprint` 废止**，身份改为三元组 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`。
  旧工件里的该字段**不可换算**成新值——在途的 ChangeSet 必须重新生成身份并重跑 QA，不得手工映射。
- **`plaud_fingerprint()` 废止**，换成六个函数（`plaud_theme_tree` / `plaud_changeset_scope` /
  `plaud_declared_diff` / `plaud_base_theme_tree` / `plaud_stage_workspace` / `plaud_stage_verified`）。
- **`BaseHeadSha` 降级**为「开工前捕获的 baseline commit」，仍必填、仍须可解析，但**不再是失配判据**。
- **指纹范围改成只收可发布面**（`assets blocks config layout locales sections snippets templates` +
  仓库根 `.shopifyignore`）。`memory/` 天然落在范围外，不再需要显式排除。
- **多块同批发版从「不支持」改为「支持但必须有集成 QA」**（`QAScope: Integration`）；
  `IncludedInThisPush: Yes` 至多一个的限制删除。**并行语义随之反转**——不再是「同树一律串行」。
- **工件字段数全变**：§4 20→22、§5 26→35、§9.1 Coordination 8→9、§9.1.2 QAIntake 23→26、
  §9.1.4 ReleaseOps 16→28。
- **`ModifiedFiles` 格式收紧**为逐条 `- "<逐字路径>": <一句话改动>`，它同时是
  `ChangeSetScopeFingerprint` 与 `DeclaredDiffCheck` 的机器输入；路径含双引号 → 函数 fail closed。
- **`memory/changeset-log.md` 的列变了**：`ChangeSetFingerprint` 一列 →
  `ObjectFormat` + `ThemeTreeOid`（前 12 位）+ `ScopeFP` 三列。旧行不回填，按旧语义阅读。
- **新增三条运行环境前提**：可写 `TMPDIR`、git ≥ 2.25、**取证只支持 macOS / Linux**
  （Windows 上 Git 默认 `core.fileMode=false` + `core.autocrlf=true`，两道字节保真门必然停机）。

🔴 **升级须四端同时进行**。同一棵 `memory/` 被两个版本的 spec 处理，是本项目记录在案的客户端漂移事故形态；
v0.3.0 的 `changeset-log.md` 列结构与 v0.2.x 不同，混用会让 QA 把正常交付判成失配。

完整的 13 条破坏性变更清单与迁移口径见 [`CHANGELOG.md`](CHANGELOG.md)。

## v0.2.2 关键变化

**v0.2.1 的门禁收口版。** v0.2.1 发布后外部评审（Codex gpt-5.6-sol）判**不通过**，找出两处会改变门禁语义的高危问题 + 若干接线不一致。v0.2.2 只修这些，不再引入新机制：

| # | 问题 | 修法 |
|---|---|---|
| 1 | **🔴 `ApprovedException` 把红线开了洞** —— v0.2.1 定义了「批准即可放行」这一类，却没给封闭适用清单，理论上任何红线都能尝试走批准通道；`qa-global.md` 更把「本次新建字段的不合规默认值」当成批准例子，与唯一事实源「第 10 条这一半是 🔴 不可豁免」直接矛盾 | 新增 **`ApprovedException` 封闭适用清单**（`handoff-schema.md` §8.1）：当前清单里**只有** §8 红线⑤ 的 A11y `3.0 ≤ x < 4.5` allowlist 配对一项，**§8.1 的 11 条没有任何一条在内**。明写「红线不因批准而放行」，第 10 条的批准链接只能进 `BlockingGaps`，`StyleHardRuleCheck` 仍 `Failed` |
| 2 | **🔴 `ApprovalRef` 不在任何工件里** —— §8.1 要求逐项核它、枚举表也把它当字段，但 Implement / Verify 工件都没有，QA 无法机械判空或绑定条款 | Implement 工件加 **`ApprovedExceptions`** 逐项结构（`Clause` / `Scope` / `ApprovalRef` / `ApprovedBy`，无则 `[]`）；Verify 工件加 **`ApprovedExceptionsChecked`** + `ApprovedExceptionsEvidence`；`ApprovedBy` 填 agency 自己视同为空。取值界线：`ApprovalRef` **为空 / 越界 / 自批 → `Failed`**；**提供了但核不动**（403、权限不足、平台故障）→ `Blocked`（初版曾写「不取 `Blocked`」，与 §5 总则冲突，已在同版评审中改回） |
| 3 | `TestSetTrace` 证明不了**跨交付**的增量维护 —— 只校验本轮「稳定 ID + revision」，agency 每轮新建一份文档并称其为稳定 ID 仍能通过 | 加 **`PreviousAcceptedTestSetTrace`**：与本轮同稳定文档 ID、revision 必须不同。文档 ID 变了又没有迁移说明 → `Incomplete`；revision 与上一轮相同却声明了增删 → `Incomplete`（自相矛盾） |
| 4 | delta 语法表达不了「某个 ID 属于哪类」，且 `Removed` 推不出来（被删的用例已不在本轮报告里） | 改为 **三段分列** `Added=[…]; Updated=[…]; Removed=[…]`；`Removed` 必须显式列，无删除写 `Removed=[]`；`Added`/`Updated` 仍由每条用例自带标记汇总 |
| 5 | release 侧「回归用例必须进同一份测试集」无处可记 | ReleaseOps 工件加 **`TestSetTraceAfterArchive`**（同稳定 ID + 入库后的新 revision + `Added` 含新用例 ID；无线上 bug 填 `N/A(NoOnlineBug)`） |
| 6 | QA 接线层残留旧口径 | `qa-global.md` §11「未触及存量默认值」🟠 → 🟡（与 §8.1 一致）；`qa-profile-c.md` C3 裁定行「改了 option value → Failed」收窄为「删除或修改既有 value」；`qa` / `feedback-triage` 的 `matrix-contract.md` 不再把 shared §8.1 描述成「硬性 10 条」，并注明 DTC **§三** 与 **§2.1** 是两套不同的 10 条 |
| 7 | 7 条新 eval 全无反向约束（substring harness 下反向答案可能通过） | 全部补 `forbidden` 数组；改写自相矛盾的那条（既说是 ApprovedException 又说是红线）；修正 ux-migration 那条违反「验收前不写迁移日志」的期望；新增 3 条（`ApprovedExceptions: []` 该填 NotApplicable / 每轮换文档冒充稳定 ID / 回归用例归档 trace） |
| 8 | 事实表述不准确 | §4.1 原写「三套并行的 h5 实现」——实测 `--h0-size…--h6-size` **全仓无 `var(--h5-size)` 消费点**，是死声明。改为「一套生效规则（28.8px）+ 一处无消费点的死变量声明 + 一套与标签正交的语义体系」，并明写不要去接那个死变量 |
| 9 | `version-manifest.md` 一条已失实 | 原写「`repo-drift.md` 不在 `SKILL.md` 索引表里、下次补进」，实际早已在（`shared/SKILL.md:135`） |

---

## v0.2.1 关键变化（评审回应版）

v0.2.1 回应设计方对 v0.2.0 那 15 项待确认清单给出的 9 条评审意见：其中 2 条明确反对矩阵侧的收紧、1 条指出矩阵写错了事实。只做这三类修正，不引入新 skill、不动阶段轴。

### 1. 撤回一条写错的规范表述（H1–H6 / 22px）

v0.2.0 的 `typography.md` §4 写「H5 = 22px 是现行规范值」，并说「22px 在工具类体系里根本不存在」，建议「优先复用既有 `h5 {}` 全局规则」。**三句都不成立**，实测（2026-08-12）：

| v0.2.0 的说法 | 事实 |
|---|---|
| H5 = 22px 是现行规范值 | UX Spec v1.3（2026-08-11 基线）**通篇没有 H1–H6 表、没有 22px**；§1.2 字阶只有 9 个语义 token。H1–H6 这套命名来自 vendor 旧文档 |
| 工具类体系里没有 22px | `.fs-22` **存在**（`assets/critical.css:1019` `1.38rem` = 22.08px，另在 `snippets/critical-style.liquid`），且 `newsletter-popup` / `login-popup` 两个 section 仍在用。v0.2.0 把「`design-system.liquid` 的 9 个**语义**类」误当成了全部 `.fs-*` |
| 优先复用既有 `h5 {}` 全局规则 | 那条规则实测产出 **28.8px**（`--size:1.8rem` × 根字号 16px），`h1` 同理是 57.6–64px —— 正是被标为**已废止**的 vendor 64px。照做等于把废止值搬进新代码 |

改法：`typography.md` §4 重写为「HTML 标题标签不是 UX Spec 的档位」，标签语义与字号解耦；新增 §4.1（仓库 h5 现状：唯一生效的全局规则 28.8px + 一处无消费点的死变量声明）与 §4.2（`.fs-*` 的语义类 vs 数字遗留类）。`version-manifest.md` 的对应缺口条目标记撤回，`repo-drift.md` 补 §3.6 / §3.7 两条实测漂移。

### 2. DTC §三 红线从「一刀切」改为三档（回应「过于绝对化」）

设计方原话：过于绝对化的验收标准会导致设计/开发/测试任何环节的偏差都要全环节对齐，降低效率，应给出合理空间，并点名「复用 section」的情形。

| 档 | 含义 | QA 后果 |
|---|---|---|
| 🔴 红线 | 踩了必然出事且机械可判 | `Failed`，阻断交付 |
| 🟠 可论证放行 | 偏离不必然出事，但必须可复核 | 分 **EvidenceBased**（自证，QA 核 `OptionsConsidered` + `AssessmentRef` 是否齐）与 **ApprovedException**（须 PM/设计/技术 owner 的 `ApprovalRef`，**为空直接 `Failed`**）。agency 自写自批不成立 |
| 🟡 建议 | 只在同页明显不自洽时提 | `Advisories`，不阻断 |

保持 🔴 的是 #1 #2 #3 #4 #6 #7（六条运营/发版安全项）。**#5 #9 #10 不整条降级，改成按范围判**：#5 只对本次新增/修改的行判 🔴（但「本次让旧硬编码变得可达」按新增判，须人工核）；#9 删/改既有 option value 仍 🔴、纯新增放行但要验映射与兼容；#10 留空崩溃永远 🔴、新建/修改字段的默认值仍 🔴。#8 三层入口降 🟠 EvidenceBased，**复用既有 `OptionsConsidered`，不新增字段**。

新增 §8.1.2 **存量复用豁免**：复用旧 section 时不因未触及的存量偏差判 `Failed`。它豁免的是**修复义务**，不是验证范围 —— 必须举证偏差在 `BaseHeadSha` 已存在、未加重、未变成新可达行为；回归仍按 impact 的 `ActualAffectedInstances` 全量，**QA-B 空/满配置双测不豁免**。

### 3. 测试集溯源三项收敛为一行 `TestSetTrace`（回应「重复性工作影响效率」）

```yaml
TestSetTrace: <稳定文档ID>@<不可变revision>; Added=[TC-…]; Updated=[…]; Removed=[…]
# 本轮无增删：
TestSetTrace: <稳定文档ID>@<不可变revision>; None(<reason>)
PreviousAcceptedTestSetTrace: <上一轮已通过准入的同一行原文> | None(FirstSubmission) | Unavailable(<原因>)
# 换了一份新测试文档时必填（否则 ID 一变链就断）：
TestSetMigrationRef: From=<旧ID>@<旧rev>; To=<新ID>@<新rev>; Reason=<PlatformMigration|OwnerHandover|Deprecated>;
                     ReasonRef=<locator>; CaseDisposition=Mapped(<locator>)|BulkRetired(<locator>)
                     # <locator> = Local(<相对材料根的路径>) | Manifest(<materials.tsv 条目名>)
                     #   —— CaseDisposition 的清单**只能 Local**（要核条数/重复 ID，云端只能核 revision/digest）
                     #   清单头部 OldCaseCount=<N>，数据行条数必须与之相等
                     # 或 N/A(SameDocument) / N/A(NoPreviousTrace)
```

> ⚠️ v0.2.1 曾写成合并的 `Added/Updated/Removed=[…]` 一个列表，v0.2.2 改为**三段分列**（表达不了某个 ID 属于哪类），并加了 `PreviousAcceptedTestSetTrace`。**完整语法与判定唯一见 `plaud-theme-qa-intake/references/package-checklist.md` §3。**

`@<revision>` 不可省 —— 只给链接的话，同一 URL 既可被覆盖内容也可每次指向临时文档，「增量维护 vs 每次现编」完全不可查。delta 段由测试报告里每条用例自带的 `Added/Updated/Unchanged` 标记推出，**不需要另写清单**。`release-ops` 的回归用例归档必须指向同一个稳定文档 ID。

> ⚠️ **v0.2.2 又补了三处**：加 `PreviousAcceptedTestSetTrace`（否则每轮新建文档冒充稳定 ID 仍能通过），delta 改三段分列且 `Removed` 必须显式列（它推不出来），以及**换文档时的结构化 `TestSetMigrationRef`**——自由文本理由里「我们换到 Linear 了」和「上一轮那份找不到了、我重新整理了一份」长得一模一样，结构化之后 `From` 必须逐字等于历史记录里的那一行，且旧用例去向要给一份进了 `PackageFingerprint` 的本地清单（`Local(...)`，头部 `OldCaseCount`）。见上面 v0.2.2 第 3、4 条与 `package-checklist.md` §3.1。
>
> 🔴 **能力边界**：矩阵核的是**自洽性 + 内容绑定**（清单在材料里、条数与声明一致、事后不可替换），**不核真实性**——`TC-1042` 是否真的在旧文档里，矩阵查不到也不查。一拆多 / 多合一的迁移形状本版**不支持**，须停机。

---

## v0.2.0 关键变化（上一版）

v0.2.0 有两条主线：**接入《DTC 开发交付标准 v1.0》**（2026-08-06，运营与产研共同维护），以及**跟进 2026-08-11 的 UX Spec 设计 Token 基线**。

### 1. 新增 3 个 skill（7 → 10），都不占阶段轴

| skill | 管什么 | 阻断能力 |
|---|---|---|
| `plaud-theme-qa-intake`（order 6） | 提测准入：六项交付物、站点清单、包指纹 | **有** —— 材料不齐 QA 零验证项执行 |
| `plaud-theme-feedback-triage`（order 8） | 反馈归因：缺陷 vs 变更、依据、去向 | 无（但会新开工作项回 Assess） |
| `plaud-theme-release-ops`（order 9） | 发版与上线后：推站二次确认、线上 bug 时效、回归用例 | 无（前置是 QA 的 Yes） |

> 🔴 **qa-intake 在 Verify 之前，不是之后。** DTC §四 原文「提测时必须同时提供，**缺一不进验收**」——交付物是进验收的**准入条件**，不是验收的产物。阶段轴仍恒为 `Assess / Implement / Verify` 三值，写 `Stage: Handover` 一律违规。

### 2. 交付权边界说清楚了

`ReadyForDelivery: Yes` 只代表**通过了矩阵内部的技术验证**。它不等于提测材料齐备（qa-intake）、不等于 PM 已验收（feedback-triage）、不等于可以推站（release-ops）。四者正交。

新工件刻意用不同语法防误读：提测包用 `Complete/Incomplete`，交付许可用 `Yes/No`，两套不可互换。三个新 skill 的产出里**都不出现 `ReadyForDelivery` 字段**。

### 3. UX Spec 跟进 2026-08-11 基线

| 项 | 变化 |
|---|---|
| **字重** | `Semibold 600` 放开用于局部强调 / 数据数值 / 价格突出（不用于标题、不可大面积）。v0.1.0 的「全站仅 400」已废止。落地前须核字体文件、`@font-face 600`、加载策略，缺一停机——否则触发浏览器 synthetic bold |
| **label 色阶** | `secondary` `#7A7A7A` → **`#717171`**；**`tertiary` 档废止**（走墓碑流程，不是全仓一把删）；新增 `label-purple/cyan/green` |
| **新增整节** | 角标色板 7 种、透明度叠加 4 个 token、品牌渐变 5 停色标、组件尺寸（导航/卡片/倒计时）、布局网格每档内边距与内容宽度 |
| **按钮** | 补全 5 个 Primary 变体 + Secondary-Outline（1px `#717171`）+ 四档高度；白色 hover 统一 `#EEEEEE`（此前 colors 表与按钮表自相矛盾） |
| **背景 token** | 新增 `--color-bg-white` / `--color-bg-dark` |

三条落地纪律：

- **按钮高度是「单行目标最小高度」**，落实为 `min-block-size` + `height: auto`，**不得写死 `height`**（德/法/西/俄比英文长 30–50%，写死会溢出或被裁）。固定 `width` 仍全面禁止。
- **组件尺寸表里的 px 要先分类**再决定写法：设计参考（不进 CSS）/ 比例约束（`aspect-ratio`）/ 最小尺寸（`min-*`）/ 技术固定例外（图标、倒计时数字格）。不得全翻译成固定宽高。
- **品牌渐变只有色标、没有几何参数**（圆心、半径、stop 位置全缺），不足以直接写 CSS —— 要落地时**停机**要 Figma 节点，不得编造 stop position。

### 4. A11y：实测对比度 + 待裁决机制

新增 `a11y.md` §5.1 配对表（矩阵实算，非文档声明值）。几组 spec 直接给出的配对不达标：

| 配对 | 比值 |
|---|---|
| `#717171` 压暖白底 `#F2EFEB` | 4.26 🔴 |
| 角标 Hot / -X% off（`#FF0000` on `#FCDEDE`） | 3.17 🔴 |
| 角标 Pre Order（`#39F672` on `#D7FDE3`） | **1.30 → `Failed`** |

处理口径：色值**按 spec 照录**（矩阵无权改规范去凑对比度）。`3.0–4.5` 且在**封闭 allowlist** 里的四组进 `Advisories`、不判 `Failed`；**`< 3.0` 一律 `Failed`（spec 给的也不行）**——Pre Order 的 1.30 是看不见的量级，`BlockingGaps` 写明需设计方裁决，性质是规范缺口而非开发错误。cyan/green 文字压浅底（1.83 / 1.44）同样 `Failed`。

防滥用还有两条：allowlist 封闭、QA 无权扩充；每条 Advisory 必须带**已知偏差批准引用**，为空则降级 `Failed`。

> 🟢 **这次改动是 A11y 净改善，不是倒退**：旧 `secondary #7A7A7A` 白底 4.29、暖白底 3.74，**本来就不达标**；新值白底 4.88 ✅。旧 `tertiary #A3A3A3` 白底仅 **2.52**，废止它等于拿掉一个长期不合规的档位。

### 5. 运营协作红线进契约

DTC §三 的 11 条进 handoff-schema §8.1。当时把其中可机械判定的 10 条一律提为 🔴 红线，公共文件注释保持 🟡 建议级。「主流程必须做成开关」保留了原文「**且会修改全站默认配置**」这个前提，没有省掉。

> ⚠️ **这条已被 v0.2.1 修订**：设计方评审指出「一刀切」会降低效率，现改为 🔴 / 🟠 / 🟡 三档 + 存量复用豁免，见上面「v0.2.1 关键变化」第 2 节；🟠 的封闭适用清单见 v0.2.2 第 1 条。

公共文件的英文注释规范（§8.2）与矩阵原有的「默认不写注释」冲突，因此限定了 allowlist（共享 snippet / 全局 CSS / theme.liquid / 共享 JS）、禁写清单（**build 产物、`templates/*.json`**）和各文件类型的合法注释语法（`.liquid` 用 `{% comment %}`，不是 `//`）。

### 6. 发布前经过一轮外部评审并打回重修

初版方案被指出 14 项问题，其中 **4 项能真正绕过门禁**：QA 的交付条件漏查新增的两道门、留了两条显式绕过链（用户弃流程直接得 `Accepted`、紧急上线"照做"）、多 ChangeSet 发版在指纹模型下无法闭环、提测包没有可信绑定（可重放、可在准入后替换）。全部已修，明细见 CHANGELOG §8。

其中两项与 v0.1.0 那个指纹 bug 属**同一类错误**：`PackageFingerprint` 命令在命令替换里静默失败（`|| return 1` 永远不触发，指纹退化成只反映文件名），以及 `FixedDimensionCheck` 只 grep `width|height`、`block-size: 40px` 可直接绕过。这类问题静态校验和 evals 都抓不到。

### 7. QA 侧

- 新增 Step 0 准入门 `QAAdmissionStatus`，比指纹校验更早
- §5 工件 19 → **24 字段**（+ `SubmissionId` / `QAAdmissionStatus` / `QAAdmissionReason` / `StyleHardRuleCheck` / `Advisories`）
- QA-Global 新增 §9（DTC 硬性 10 条）与 §10（软性项 → Advisories）
- **修掉一处既有契约漂移**：QA SKILL 长期声称三个状态字段存在「§9.2 枚举缺口」，复核发现 §9.2 本来就含 `Blocked`，缺口不存在，该提示已删除

### 8. 沿用 v0.1.0 的机制（未变）

ChangeSet 内容绑定（`ChangeSetId` + `BaseHeadSha` + `ChangeSetFingerprint`，QA 在任何检查之前三者重算比对）、Theme Check baseline 增量双指标、只读任务的 `ReadOnlyProof`、理论影响 vs 实际影响分开报、项目状态存 `memory/`、安装器 legacy 退役 fail-closed。

详见 [`CHANGELOG.md`](CHANGELOG.md)。

## 已知取舍与局限

发布前跑过 6 个真实任务的行为评测（Path A）与 14 条路由探针，以下是**实测确认**的行为，不是推测：

| 现象 | 说明 |
|---|---|
| 随口说"改完了跑下检查"**可能不进 QA** | `plaud-theme-qa` 的触发被刻意收窄为「已有 `ChangeSetId`」**或**「明确要最终交付判定**且该任务确有改动**」，避免跟 `dev` 抢没有 ChangeSet 的只读 review。🔴 零改动只读任务即使用户点名要交付判定也归 `dev`——QA 的 §5 工件没有 `ReadOnlyProof`，接了只能原样转回（v0.2.2 第八轮）。说清 ChangeSet（"这个 ChangeSet 改完了…"）或直接点名 skill 即可命中 |
| 指纹命令对 git 版本敏感 | 必须用 §2 原文（`--no-renames --binary` + `set -o pipefail`）。**`--find-renames=false` 在 git 2.52+ 是非法参数**，且错误走 stderr、管道继续，会算出一个只反映文件集合、不反映内容的常量——指纹退化成摆设。拿到 `FINGERPRINT_FAILED` 必须停机 |
| Path B / Path C 未做行为评测 | 6 个评测场景全在 Path A。B/C 的契约与 evals 齐备，但没有真实任务验证过 |
| `install.ps1` 从未在 Windows 上跑过 | **仅静态审查**（本机无 PowerShell，连语法解析都没跑过），是 `install.sh` 的静态移植。`install.sh` 则在 macOS 上实跑验证过：装最新 / 钉 `--ref v0.2.2` / `--check` / `--dry-run`、造陈旧残留、注入失败的 `tar`/`git`/`curl`/`mktemp`、`chmod 500` 使删除失败、symlink 目标、截断的管道，bash 3.2 / dash / zsh 三家。首次在 Windows 上用前先跑 `-DryRun`，再跑 `-Check` |
| 三个新 skill 未做行为评测 | `qa-intake` / `feedback-triage` / `release-ops` 的契约与 evals（各 12 条）齐备，但**没有真实任务验证过**。v0.1.0 的教训是：四轮 Codex 评审 + 205 条 eval + 全套静态校验都没抓到的指纹 bug，只有真跑才发现 |
| UX Spec 有两处待设计方裁决 | ① A11y 项（Advisory：`#717171` 压暖白底 4.26 / 压卡片底 4.49、`#8F53ED` 压暖白底 3.96、角标 Hot 3.17；**Failed**：角标 Pre Order 1.30）；② 品牌渐变 §2.8 说「渐变仅用于 Announcement Bar」，字面上会读成 AI 渐变也不许用——本版判定为**未覆盖而非废止**，原样保留 AI 渐变并标记待确认 |
| **取证只支持 macOS / Linux** | v0.3.0 的身份三元组取证需要**可写 `TMPDIR`** 与 **git ≥ 2.25**。Windows 上 Git 默认 `core.fileMode=false` + `core.autocrlf=true`，两道字节保真门必然停机 → 取证不可用（安装器本身仍可在 Windows 上跑） |
| 提测材料必须能内容绑定 | 放在无版本号 / 无 digest 的外链上的材料判 `Incomplete` —— 要么下载到本地参与 hash，要么换成能取版本号的载体（飞书文档 revision、Linear 附件 ID）。否则防替换链有洞 |
| 品牌渐变无法直接落地 | 只有 5 个色标，圆心 / 半径 / 形状 / stop 位置全缺。要用时停机要 Figma，不得编造 |
| `memory/` 四个文件需先建 | 缺失时 skill 会停机问你，不会凭空重建。首次接入可从 `plaud-theme-ux-migration/references/memory-seed/` 复制种子（那是 2026-07 快照，复制后即由项目维护） |
