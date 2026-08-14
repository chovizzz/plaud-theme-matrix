# Changelog — PLAUD Shopify Theme Matrix

版本按**全量快照**发布：切新版本 = 整包复制到新目录再改，不做原地修改。

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
