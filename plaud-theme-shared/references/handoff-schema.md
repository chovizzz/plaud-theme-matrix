# Handoff Schema — 矩阵唯一契约

本文件是 `plaud-shopify-theme-matrix` 全部 skill 的**唯一** handoff 契约。任何 skill 都不得自行定义字段、改字段名、或新增终态词汇。字段冲突时以本文件为准。

---

## 0. 两轴状态机

矩阵由**阶段轴**和**路径轴**交叉构成。路径决定"按什么规则实现"，阶段决定"现在处于评估、实现还是验证"。

| 阶段 | Path A（通用开发） | Path B（Figma section） | Path C（UX 迁移） |
|---|---|---|---|
| **Assess** | `plaud-theme-impact`（LegacyImpact） | `plaud-theme-impact`（IntegrationSurface） | `plaud-theme-impact`（LegacyImpact）+ 迁移实例审计 |
| **Implement** | `plaud-theme-dev` | `plaud-theme-section-build` | `plaud-theme-ux-migration` |
| **Verify** | `plaud-theme-qa`（QA-A + QA-Global） | `plaud-theme-qa`（QA-B + QA-Global） | `plaud-theme-qa`（QA-C + QA-Global） |

阶段单向推进：`Assess → Implement → Verify`。不得跳过 Assess 直接 Implement，除非满足 §3 的 `InlineLite` 豁免条件。**任何有改动的任务都不得跳过 Verify。**（唯一例外是 §2 的零改动只读任务——它根本没有 ChangeSet 可验，`NextRequiredSkill: None`、`ReadyForDelivery: N/A(ReadOnly)`，由实现 skill 出 `ReadOnlyProof` 收尾。v0.2.2 第八轮更正：原文写「任何情况下」，与 §2 的只读免 QA 直接冲突。）

### 0.1 阶段轴之外的四个非阶段 skill

矩阵里有四个 skill **不在阶段轴上**，它们不产出 §3 / §4 / §5 的阶段工件，只产出 §9.1 的各类工件：

| skill | 位置 | 工件 | 是否阻断阶段推进 |
|---|---|---|---|
| `plaud-theme-orchestrator` | 阶段轴之外（编排） | `ArtifactKind: Coordination` | 否，只记台账 |
| `plaud-theme-qa-intake` | **Implement → Verify 的过渡关口** | `ArtifactKind: QAIntake` | **是**——提测包不全，QA 不启动 |
| `plaud-theme-feedback-triage` | 事件入口（QA 打回 / 运营验收 / 上线后均可触发） | `ArtifactKind: FeedbackTriage` | 否，但会**新开**工作项回到 Assess |
| `plaud-theme-release-ops` | Verify 之后（发版与上线后） | `ArtifactKind: ReleaseOps` | 否，前置是 QA 的 `ReadyForDelivery: Yes` |

> 🔴 **`qa-intake` 不是第四个阶段。** 阶段轴永远只有 `Assess / Implement / Verify` 三值，任何 skill 都不得把它扩成四值、不得输出 `Stage: Handover` 之类的取值。qa-intake 产出的是一份**过渡工件**，夹在 Implement 工件与 Verify 之间，语义是「提测材料齐不齐」，与「代码行不行」正交。
>
> 为什么必须在 Verify **之前**：《DTC 开发交付标准 v1.0》§四 原文是「提测时必须同时提供，**缺一不进验收**」——交付物是**进验收的准入条件**，不是验收通过后的产物。把它放在 QA 之后是时序错误。

---

## 1. 交付权（不可协商）

> **只有 `plaud-theme-qa` 有权输出 `ReadyForDelivery: Yes`。**

推论，全部为硬规则：

1. `plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration` 输出的 `ReadyForDelivery` **恒为 `No`**，且必须带 `QAStatus: NotRun`。
2. 实现类 skill **禁止**使用终态措辞：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」「没问题了」「改完了可以用」。允许的措辞是「改动已就位，待 QA」。
3. `Blocked` 与 `NotRun` **不得**折算为 pass——存在任一项时 `ReadyForDelivery` 必须是 `No`。

   `NotApplicable` 不同：它是**合法终态**，但必须给出适用性证据（例如"本次未改任何 `.liquid`，故 Theme Check 不适用"）。没有证据的 `NotApplicable` 一律按 `Blocked` 处理。区别在于——`Blocked` 是"该验但验不了"，`NotApplicable` 是"根本不需要验"；前者是风险，后者不是。
4. QA 通过后代码若再次变化，该 QA 结果**自动失效**，必须重新生成 `ChangeSetId` 并重跑 QA。
5. 用户即使明说"不用检查了直接给我"，实现 skill 仍不得输出 `ReadyForDelivery: Yes`；正确做法是照常输出 `No` + `QAStatus: Skipped(UserWaived)`，并在正文一句话说明已按用户要求跳过验证、风险由用户承担。

### 1.1 `ReadyForDelivery: Yes` 的边界

它的含义**只有一个**：这批改动通过了矩阵内部的技术验证。它**不**代表：

| 不代表 | 归谁 |
|---|---|
| 运营 / PM 已验收 | PM，依据 PRD / Figma / UX Spec（见 `plaud-theme-feedback-triage`） |
| 可以推送到线上站点 | `plaud-theme-release-ops` 的推站清单二次确认 |
| 提测材料齐备 | `plaud-theme-qa-intake` 的 `SubmissionPackageStatus` |

三者正交，任何一个都不能替代另一个。QA 通过后仍可能被 PM 判为交付缺陷（例如与 Figma 不一致——这是 QA 不检查的维度）。

---

## 2. ChangeSetId 绑定

`ChangeSetId` 是把「谁改的」和「谁验的」焊在一起的唯一凭据。QA 验的必须**就是**实现 skill 交出的那批改动。

**格式**：`CS-<YYYYMMDD>-<path><NN>`，例如 `CS-20260806-A03`、`CS-20260806-C11`。
- `<path>` ∈ `A` / `B` / `C`
- `<NN>` 为当日该路径的序号，从 `01` 起

**`<NN>` 怎么取（v0.2.2 第九轮补：此前只说「从 01 起」，没有 allocator、没有冲突处理，两个独立 worktree 会各自生成 `CS-20260813-A01`，QA / changeset-log / 返工链会把两批内容当成同一个 ChangeSet）**：
1. 读 `memory/changeset-log.md`，取**同一天、同一 `<path>`** 的已有最大序号 + 1；该日该路径没有行则从 `01` 起。
2. 生成后**立刻**在 `changeset-log.md` 追加一行占位（`ChangeSetId` + 生成时间 + 归属 skill），再开始实现——先占位是这套编号唯一的互斥手段。
3. 🔴 **独立 worktree / clone 里开发时 `memory/` 不共享，第 1 步读到的是各自的日志 → 必然撞号。** 此时不得自行生成：回 `plaud-theme-orchestrator` 由它在主树的日志里统一分配，或改为串行。
4. 日志里已有同号但内容不是本块 → **停机**，不要自造 `A01b` 之类的后缀格式。

**生成方**：实现类 skill（dev / section-build / ux-migration），在输出 HandoffContract 时生成。
**消费方**：`plaud-theme-qa`，必须回填 `ChangeSetIdMatched`。

### 🔴 必须绑定内容，不能只绑文件名

只比对 `ModifiedFiles` 的**文件集合**是不够的：实现 skill 交出工件之后、QA 开始之前，如果同一批文件的**内容**又被改过，文件集合仍然一致，`ChangeSetIdMatched` 会错误地判为 `Yes`——QA 验的是一批它从未见过的代码。

因此实现 skill 必须在交付工件时**当场**生成并写入：

```bash
# BaseHeadSha
git rev-parse HEAD

# ChangeSetFingerprint —— 覆盖内容、权限、删除态、未跟踪文件
# 必须在仓库根目录执行。producer 与 verifier 必须用一字不差的同一段命令。
plaud_fingerprint() (
  set -o pipefail
  # 🔴 必须在仓库根执行 —— 这条以前只写在正文里、没有守卫（v0.2.2 第七轮自查补）。
  #    在子目录跑时 `-- .` 会把范围收到该子目录，于是**静默算出一个子集指纹并返回 0**
  #    （实测：根目录与 sections/ 下得到两个不同的正常 hash）。producer 与 verifier 只要
  #    一个不在根目录就是假失配；两边都在同一子目录，则指纹看着正常却只覆盖一部分。
  _top=$(git rev-parse --show-toplevel 2>/dev/null)                                 || return 1
  [ -n "$_top" ] || return 1
  [ "$(cd "$_top" && pwd -P)" = "$(pwd -P)" ] || {
    # printf + ASCII 分隔：把变量紧贴多字节字符（如「根为 $_top）」）在某些 bash 下会截断输出
    printf 'NOT_REPO_ROOT: must run at repo root. cwd=%s toplevel=%s\n' "$(pwd -P)" "$_top" >&2
    return 1; }
  # 🔴 四条不可改的结构约束（v0.2.2 修，全部实测验证过）：
  # (1) 排除 memory/ —— 它是项目运行时状态、不属于 ChangeSet，且由矩阵自己写。
  #     不排除的话，QA 写完 changeset-log 当场就把刚记录的结论算失效（§1.4）。
  # (2) 先把全部输入收进变量、成功了才 hash。**绝不能把 { … } 直接管进 shasum**：
  #     那样 { } 是管道左端、跑在子 shell 里，里面的 return/exit 只结束子 shell，
  #     shasum 照样把残缺输入算出一个像样的 hash（空输入 → e3b0c442…，看不出坏了）。
  # (3) 未跟踪文件**逐行数核对**：循环零次迭代时它的退出码也是 0（heredoc 建不了临时文件、
  #     输入为空等），不核对行数就会静默产出"不含未跟踪文件"的指纹。
  # (4) 未跟踪"目录" fail closed，见下。
  # 必须在仓库根目录执行。producer 与 verifier 必须用一字不差的同一段命令。
  # 🔴 换行文件名必须 fail closed：下面把 NUL 转成换行后逐行读，路径里本身带 \n 的会被
  #    拆成两行、两半都 hash 不到，**指纹静默漏算且行数守卫也对得上**（实测：造 a、b、
  #    "a\nb" 三个文件，改 "a\nb" 的内容，指纹完全不变）。所以先探测、命中就退出。
  nl_probe=$(git ls-files --others --exclude-standard -z -- . ':(exclude)memory/' \
    | tr -d '\0' | tr -cd '\n' | wc -c | tr -d ' ')                                 || return 1
  [ "$nl_probe" = "0" ] || { echo "NEWLINE_IN_PATH: 路径含换行，指纹无法覆盖，先重命名" >&2; return 1; }
  # 🔴 被 gitignore 的**主题可发布文件** fail closed：下面的 --exclude-standard 会跳过 ignored
  #    文件，而 Shopify push 推的是整个主题目录 —— ignored 的 assets/*.css 照样上线，却完全
  #    不在指纹里（实测：放进 .git/info/exclude 后新增与改内容指纹都不变）。
  #    只管可发布目录：node_modules / .DS_Store 之类本就该 ignore，不在这几个目录下。
  #    🔴 **先数个数、不要 head，也绝不能 `|| var=""`**（v0.2.2 第七轮修）：
  #    `| head -5` 在 pipefail 下命中量大时会让上游吃 SIGPIPE 而失败，紧跟的 `|| ignored_pub=""`
  #    又把证据清空 —— 这个门就 **fail open** 了（评审用 12,000 个 ignored assets/*.css 复现：
  #    函数两次都返回 0，改其中一个文件 hash 仍完全相同）。**门禁的失败分支不许兜底成"没命中"。**
  n_ignored=$(git ls-files --others --ignored --exclude-standard -z -- \
    assets blocks config layout locales sections snippets templates \
    | tr -cd '\0' | wc -c | tr -d ' ')                                              || return 1
  [ -n "$n_ignored" ]                                                               || return 1
  if [ "$n_ignored" != "0" ]; then
    printf 'IGNORED_PUBLISHABLE_FILE: %s 个被 gitignore 的文件位于主题可发布目录下，会被 push 但不进指纹。\n' "$n_ignored" >&2
    printf '  先纳入版本控制或移出主题目录。列出前 20 个：\n' >&2
    # 这里可以用 head：它只影响**诊断输出**，判定已由上面的计数完成
    git ls-files --others --ignored --exclude-standard -- \
      assets blocks config layout locales sections snippets templates 2>/dev/null \
      | head -20 | sed 's/^/    /' >&2
    return 1
  fi
  # 🔴 stat 必须**先按平台定一次**，不能写成 `stat -f '%Lp' … || stat -c '%a' …`：
  #    GNU stat 会把 '%Lp' 当成**另一个文件操作数**，仓库里恰好有名为 %Lp 的文件时第一支就
  #    "成功"、第二支不执行，拿到的是文件系统信息而不是权限位 —— 权限改了指纹却不变（已复现）。
  if stat -c '%a' . >/dev/null 2>&1; then STAT_MODE_CMD="stat -c '%a'"      # GNU / Linux
  elif stat -f '%Lp' . >/dev/null 2>&1; then STAT_MODE_CMD="stat -f '%Lp'"  # BSD / macOS
  else echo "NO_USABLE_STAT: 既不支持 GNU 也不支持 BSD 的 stat" >&2; return 1; fi
  # 🔴 tracked 侧的三个盲区（v0.2.2 第七轮补，前两个实测可静默漏算）：
  #  (a) .gitattributes 的 clean filter：工作树字节变了但 filter 清洗后 git 语义相同 →
  #      git diff/status 都看不见。非默认配置，直接 fail closed。
  #  (b) core.fileMode=false：tracked 文件权限 0644→0755 时 status 为空、指纹不变。
  #      本函数只对**未跟踪**文件记权限，所以这里必须 fail closed，否则"覆盖权限"这个声明是假的。
  #  (c) 大小写不敏感卷上的**纯大小写改名**：git status 为空、指纹不变，但磁盘文件名已变。
  #      macOS 默认 core.ignorecase=true，不能因此 fail closed；改为逐路径比对**字节精确**的存在性。
  # 🔴 v0.2.2 第八轮实测修：旧写法 `… | grep -q .` 与第七轮那条 `head -5` 是**同一族**
  #    —— `grep -q` 命中即退出、关闭管道，上游 while 循环吃 SIGPIPE（状态 141），
  #    pipefail 下整条管道失败，`if` 于是不进阻断分支 → **fail open**。
  #    实测：1 个 .gitattributes 正确阻断；3000 个时 bash 3.2 与 zsh 都放行。
  #    改法与 ignored 门一致：**不许任何提前退出的消费者**，把命中项全收进变量再判空。
  #    同时补上第七轮漏掉的两个 attributes 来源：`$GIT_DIR/info/attributes` 与
  #    `core.attributesFile`（全局），它们同样能挂 clean filter 而不进版本控制。
  # 🔴 v0.2.2 第九轮：第八轮的 `_ga_hit=$( pipeline; : )` **仍是 fail open** —— 末尾那个
  #    `:` 把 pipeline 的失败整个吞掉（评审注入 `git ls-files` 失败复现：先打印错误、
  #    随后照样返回一个正常 SHA-256）。同轮还查出三个漏：只枚举 tracked `.gitattributes`
  #    （工作树里**未跟踪**的那份照样生效）、`core.attributesFile` 拿到 `~/x` 后 `[ -f ]`
  #    **不展开 `~`**、以及路径含换行时 NUL→换行转换又把它拆成两半。
  #    改法：列表落**临时文件**（`$( )` 在 bash 里会直接丢掉 NUL 字节，不能用变量存 -z 输出），
  #    每条命令单独判退出码，`while` 从文件读（不起子壳，命中项留得住）。
  _atmp=$(mktemp -d)                                                                || return 1
  git ls-files -z -- '*.gitattributes' > "$_atmp/z1" || {
    printf 'GITATTR_ENUM_FAILED: git ls-files（tracked）失败，无法判定 clean filter\n' >&2
    rm -rf "$_atmp"; return 1; }
  git ls-files --others --exclude-standard -z -- '*.gitattributes' > "$_atmp/z2" || {
    printf 'GITATTR_ENUM_FAILED: git ls-files（untracked）失败，无法判定 clean filter\n' >&2
    rm -rf "$_atmp"; return 1; }
  cat "$_atmp/z1" "$_atmp/z2" > "$_atmp/z"                                          || { rm -rf "$_atmp"; return 1; }
  # 路径含换行 → fail closed（NUL 个数与行数不等即有换行）
  _n_nul=$(tr -cd '\0' < "$_atmp/z" | wc -c | tr -d ' ')                            || { rm -rf "$_atmp"; return 1; }
  _n_lin=$(tr '\0' '\n' < "$_atmp/z" | sed '/^$/d' | wc -l | tr -d ' ')             || { rm -rf "$_atmp"; return 1; }
  [ "$_n_nul" = "$_n_lin" ] || {
    printf 'NEWLINE_IN_ATTR_PATH: .gitattributes 路径含换行，无法可靠判定，先重命名\n' >&2
    rm -rf "$_atmp"; return 1; }
  tr '\0' '\n' < "$_atmp/z" | sed '/^$/d' > "$_atmp/list"                          || { rm -rf "$_atmp"; return 1; }
  printf '%s\n' "$(git rev-parse --git-dir)/info/attributes" >> "$_atmp/list"       || { rm -rf "$_atmp"; return 1; }
  # 🔴 用 --path 让 git 自己展开 `~`：--get 拿到的是字面量 `~/global-attrs`，`[ -f ]` 永假
  _gattr=$(git config --path --get core.attributesFile 2>/dev/null) && [ -n "$_gattr" ] \
    && { printf '%s\n' "$_gattr" >> "$_atmp/list" || { rm -rf "$_atmp"; return 1; }; }
  _ga_hit=""
  while IFS= read -r ga; do
    [ -n "$ga" ] || continue
    [ -f "$ga" ] || continue
    if grep -q 'filter=' -- "$ga"; then _ga_hit="$_ga_hit$ga
"; fi
  done < "$_atmp/list"
  rm -rf "$_atmp"
  [ -z "$_ga_hit" ] || {
    printf 'GITATTRIBUTES_CLEAN_FILTER: 下列 attributes 文件挂了 clean/smudge filter，工作树字节可绕过指纹；本函数不支持：\n%s' "$_ga_hit" >&2
    return 1; }
  # 🔴 v0.2.2 第八轮实测修：git 的布尔值不只有字面 `false` —— `off` / `no` / `0` /
  #    `FALSE` 等都表示假，旧写法只比字面串，这些取值会**直接通过**这道门，而本函数
  #    只对未跟踪文件记权限，于是"指纹覆盖权限"这个声明变成假的。用 `--bool` 让 git
  #    自己归一化；未配置时 git 无输出、退出码非 0，按默认 true 处理。
  _fm=$(git config --bool --get core.fileMode 2>/dev/null) || _fm=true
  [ -n "$_fm" ] || _fm=true
  [ "$_fm" != "false" ] || {
    echo "CORE_FILEMODE_FALSE: core.fileMode 为假值时 tracked 权限变化对 git 隐形，指纹覆盖不到" >&2
    return 1; }
  # (c) tracked 路径必须在磁盘上**字节精确**存在（catch 纯大小写 / unicode 规范化改名）
  #     🔴 一次 find 取盘上清单再做集合差 —— **不要逐文件 ls|grep**：真实仓库 1602 个
  #     tracked 文件时那样跑要 >2 分钟（实测超时），agent 会挂死。
  #     已被 git status 报告的路径（含删除、改名）排除掉，避免把合法删除误报成大小写问题。
  #     🔴 v0.2.2 第八轮实测修的三处（三条都能复现）：
  #     (i)  `find` 的目录清单必须**只含盘上存在的目录**：主题仓库不一定八个目录都有
  #          （`blocks/` 只在新版 theme architecture 里有），少一个 find 就退出非 0，
  #          而这里的 `|| return 1` **一句诊断都不打** —— agent 只看到 FINGERPRINT_FAILED，
  #          无从判断是真被门挡住还是环境不齐（实测：删掉 blocks/ 即静默失败）。
  #     (ii) `find … -type f` 会漏掉 **tracked symlink**：它在盘上存在、git 也正常跟踪，
  #          却不进 disk 清单 → 被误报成 PATH_CASE_MISMATCH，指纹**永远算不出来**，
  #          整条 QA/交付链死锁（实测：assets/link.css 一个 symlink 即复现）。
  #          本函数别处也明说「已跟踪的 symlink 不受影响」——那句话原本是假的。
  #     (iii)`git status --porcelain=v1 -z` 的**改名第二条目**（ORIG_PATH）是裸路径、没有
  #          两字符状态前缀，旧写法 `sed 's/^...//'` 会把它削掉三个字符
  #          （`assets/a.css` → `ets/a.css`），排除清单就少了一条真路径。
  #          `-z` 格式下也根本不存在 ` -> `，那条 sed 是死的。改为只在真有状态前缀时才剥。
  _tmpd=$(mktemp -d)                                                                || return 1
  # 🔴 用位置参数收目录清单，**不要**写 `find $_dirs`：zsh 默认不对未加引号的变量做词分割，
  #    整串会当成一个参数传给 find（实测 zsh 直接 No such file or directory），而本函数
  #    明文支持 bash 与 zsh 两家。`set -- "$@" "$_d"` 在 bash / zsh / sh 下语义一致。
  set --
  for _d in assets blocks config layout locales sections snippets templates; do
    [ -d "$_d" ] && set -- "$@" "$_d"
  done
  [ "$#" -gt 0 ] || {
    printf 'NO_THEME_DIRS: 当前目录下不存在任何主题可发布目录，这不像主题仓库根\n' >&2
    rm -rf "$_tmpd"; return 1; }
  git ls-files -z -- assets blocks config layout locales sections snippets templates \
    | tr '\0' '\n' | sed '/^$/d' | LC_ALL=C sort > "$_tmpd/tracked" || {
    printf 'CASE_CHECK_FAILED: git ls-files 采集 tracked 清单失败\n' >&2
    rm -rf "$_tmpd"; return 1; }
  # symlink 必须一起收（-type l），否则 tracked symlink 会被误判成大小写改名
  find "$@" \( -type f -o -type l \) -print \
    | sed 's|^\./||' | LC_ALL=C sort > "$_tmpd/disk" || {
    printf 'CASE_CHECK_FAILED: find 采集盘上清单失败（目录清单=%s）\n' "$*" >&2
    rm -rf "$_tmpd"; return 1; }
  # 只在行首确实是「两位状态码 + 空格」时才剥前缀；改名的 ORIG_PATH 行保持原样
  git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' \
    | sed 's/^[ MADRCUT?!][ MADRCUT?!] //' | LC_ALL=C sort > "$_tmpd/reported" || {
    printf 'CASE_CHECK_FAILED: git status 采集已报告路径失败\n' >&2
    rm -rf "$_tmpd"; return 1; }
  _casebad=$(LC_ALL=C comm -23 "$_tmpd/tracked" "$_tmpd/disk" \
    | LC_ALL=C comm -23 - "$_tmpd/reported")                                        || { rm -rf "$_tmpd"; return 1; }
  rm -rf "$_tmpd"
  [ -z "$_casebad" ] || {
    printf 'PATH_CASE_MISMATCH: 下列 tracked 路径在磁盘上不是字节精确同名（纯大小写/规范化改名，git 看不见）：\n%s\n' "$_casebad" >&2
    return 1; }
  others=$(git ls-files --others --exclude-standard -z -- . ':(exclude)memory/' \
    | tr '\0' '\n' | sed '/^$/d')                                                  || return 1
  n_others=$(printf '%s\n' "$others" | grep -c '[^[:space:]]')                     || n_others=0
  payload=$(
    git rev-parse HEAD                                                              || exit 1
    git status --porcelain=v1 -z --untracked-files=all -- . ':(exclude)memory/' \
      | tr '\0' '\n'                                                                || exit 1
    git diff HEAD --no-renames --binary -- . ':(exclude)memory/'                    || exit 1
    printf 'untracked_count:%s\n' "$n_others"                                       || exit 1
    # 未跟踪文件 git diff 看不到，逐个 hash + 记权限
    # 🔴 必须用 printf '%s\n'（带结尾换行）：不带的话最后一行被 read 读到但返回非 0、
    #    循环体不执行，**最后一个未跟踪文件永远漏掉**。下面的行数核对就是为抓这个而加的。
    printf '%s\n' "$others" | sort | while IFS= read -r f; do
      [ -n "$f" ] || continue
      # 未跟踪"目录"（多为嵌套 git repo）无法 hash —— **必须失败退出，不能跳过**。
      # 跳过的话该目录整棵树都不在指纹里，而指纹看上去完全正常。
      # 🔴 这里刻意不用 case/esac：macOS 自带的 bash 3.2 无法在 $( ) 里解析 case 的
      #    模式括号，会直接语法错误。用后缀剥除判尾部斜杠，bash/zsh/sh 都能跑。
      if [ "${f%/}" != "$f" ]; then
        echo "UNHASHABLE_UNTRACKED_DIR: $f" >&2
        exit 1
      fi
      # 🔴 未跟踪 symlink 也 fail closed：git hash-object 走的是**目标的内容**，
      #    所以把 symlink 改指向另一个同内容的文件，指纹一点不变（实测）。
      #    已跟踪的 symlink 不受影响 —— git 存的是链接目标字符串，git diff HEAD 覆盖得到。
      if [ -L "$f" ]; then
        echo "UNTRACKED_SYMLINK: $f —— 指纹覆盖不到它的指向，先移除或纳入版本控制" >&2
        exit 1
      fi
      # 🔴 先赋值再判空判退出码。写成 printf "$(git hash-object …)" 时，
      #    命令替换里的失败**不会**让 printf 失败——printf 拿到空串照样返回 0。
      h=$(git hash-object -- "$f")                                                  || exit 1
      [ -n "$h" ]                                                                   || exit 1
      m=$(eval "$STAT_MODE_CMD \"\$f\"")                                            || exit 1
      [ -n "$m" ]                                                                   || exit 1
      printf 'u %s %s %s\n' "$f" "$h" "$m"                                          || exit 1
    done                                                                            || exit 1
  ) || return 1
  [ -n "$payload" ] || return 1
  # 🔴 行数核对：hash 出来的 untracked 行必须与 git 报的条数一致
  got=$(printf '%s\n' "$payload" | grep -c '^u ')                                   || got=0
  [ "$got" -eq "$n_others" ] || { echo "UNTRACKED_COUNT_MISMATCH: $got != $n_others" >&2; return 1; }
  printf '%s\n' "$payload" | shasum -a 256 | cut -d' ' -f1
)
plaud_fingerprint || echo "FINGERPRINT_FAILED"
```

> 🔴 **执行环境要求：`bash`（≥3.2）或 `zsh`，不是任意 `/bin/sh`。** 两段函数都用了 `set -o pipefail`，`dash`（Linux 上常见的 `/bin/sh`）不支持它、会直接以状态 2 退出。macOS 的 `/bin/sh` 实为 bash 所以看不出问题——**在 Linux 上必须显式 `bash -c`**。
>
> 🔴 **五处静默失败点，缺一个指纹就废了**：`set -o pipefail`、各段的 `|| exit 1`、循环内「先赋值再判空」、**payload 先收变量再 hash**、**未跟踪目录 fail closed**。
>
> 第三点是 v0.1.0 遗留的同类漏洞，v0.2.0 才修：原文把 `git hash-object` / `stat` 直接写在 `printf` 的命令替换里，它们失败时 `printf` 拿到空串**照样返回 0**，`|| return 1` 永远不触发——未跟踪文件的内容就从指纹里消失了。同一个包的 `PackageFingerprint`（§9.1.2）当初也踩了这个坑。
>
> 第四、五点是 **v0.2.2 实测发现**的同族漏洞（在真实仓库 `shopify-plaud-yidian` 上跑出来的，不是推演）：
>
> - 旧写法把 `{ … } | shasum` 连成管道，`{ }` 因此跑在**子 shell**里，里面的 `return 1` 只结束那个子 shell，`shasum` 仍然把已经吐出的**残缺输入**算出一个 hash。实测：当仓库里有未跟踪目录时，旧命令输出 `e3b0c44298fc…`（**空输入的 sha256**）—— 一个完全正常、完全错误的指纹。
> - `git ls-files --others` 对「整个目录都未跟踪」的情形（典型是嵌套 git repo、本地 worktree、`dev/` 之类）列出的是**目录名**，`git hash-object` 对目录必然失败。旧写法在这里静默滑过，该目录整棵树都不进指纹。现在遇到就**失败退出**并打印 `UNHASHABLE_UNTRACKED_DIR`，由人决定是清理它还是加进 `.gitignore`。
>
> **实测两条性质**（v0.2.2）：连续两次写 `memory/changeset-log.md` 指纹不变；仓库内任何非 `memory/` 改动仍被捕获。
>
> 通用判据：**这一段失败了，外层真的会知道吗？** 命令替换、管道中段、`while` 子 shell 都是"不会知道"的高发区。 任何一段静默失败时，管道仍会继续，`shasum` 会对残缺输入求值，算出一个**看似正常、实则与内容无关**的常量——校验因此永远通过，P0 漏洞原样复活。
>
> 实测踩过：早期版本写的是 `git diff HEAD --find-renames=false`，**git 2.52 起该参数非法**（正确写法是 `--no-renames` 或 `-M0`）。错误走 stderr，管道照常执行，指纹退化成"只反映文件集合、完全不反映内容"——恰好是本节要堵的那个洞。
>
> 拿到 `FINGERPRINT_FAILED` 或空值时**必须停机**，不得用空串或占位符填进工件。

**自检**：改一个已跟踪文件的内容（不增删文件），指纹必须变化；还原后必须精确复原。做不到就说明命令在当前环境退化了，停机排查。

QA **在执行任何检查之前**（Step 1，早于 theme check、早于回归）必须用同一命令重算，与工件里的 `ChangeSetFingerprint` **精确比对**。

**失配处理**：以下任一情形都必须输出 `ChangeSetIdMatched: No` + `ReadyForDelivery: No` 并停机，要求重新生成 ChangeSet——**不得**自行"顺便把新改动也验了"：

- `ModifiedFiles` 与工作树文件集合不一致（多文件、少文件）
- `ChangeSetFingerprint` 不匹配（**文件没多没少但内容变了**——这正是只绑文件名会漏掉的情形）
- `BaseHeadSha` 与当前 HEAD 不一致（期间发生了 commit / rebase / checkout）

QA 通过后必须**再算一次**指纹并记入 `changeset-log`；后续任何时刻指纹与记录不符，该 QA 结论即失效（§1.4）。

> **为什么指纹排除 `memory/`**：`changeset-log.md` 本身就在 `memory/` 里，由 QA 在记录结论时写。若不排除，QA 一落笔就把刚记下的结论算失效——这个控制会在第一次使用时自毁。排除它是正确的：`memory/` 是项目运行时状态，**不属于任何 ChangeSet**，也不随包分发。
> 被否掉的两个替代方案：把日志移出主题仓库（会切断"日志与工作树同源"这个可追溯性），以及"先算指纹再写日志"（v0.2.1 及以前就是这么写的 —— 它只能让**同一轮**两次校验相等，任何**后续**重算仍然失配，例如 release-ops 复核或 §1.4 的失效判定）。
>
> 🔴 **排除只挡得住工作树与暂存区，挡不住 `commit`（v0.2.2 第九轮实测）。** payload 的第一行是 `git rev-parse HEAD`，所以**把 `memory/` 的改动提交掉，HEAD 一变、指纹照样变**，同时 `BaseHeadSha` 也对不上——排除机制在它唯一存在的那个场景（QA 写 `changeset-log`）被绕过：QA 刚记完结论，有人顺手 `git commit memory/`，这条 ChangeSet 立刻变成 `Invalidated`，而主题一个字节都没动。实测：改 `memory/` 不变、`git add memory/` 不变、`git commit` **变**。
>
> 所以这是一条硬规则：**`memory/` 的更新留在工作树，不单独 commit**；确需入库时，只能在 QA 记录结论**之前**连同本 ChangeSet 的主题改动一起提交，提交后重新生成 `BaseHeadSha` + `ChangeSetFingerprint` 并重跑 QA。**任何在 QA 结论之后发生的 `memory/` 提交都会使该结论失效**，这不是 bug 而是"指纹是仓库状态指纹、不是纯内容指纹"（`evidence-and-invalidation.md` §2.6）的必然结果——不要试图靠"它只是 memory 啊"放行。
>
> 🔴 **排除换来的新风险，一句话挡住：`memory/` 下不得出现任何会影响店铺渲染的文件。** 它只放矩阵自己的项目状态记录（`模板清单.md` / `模块清单.md` / `全局已知偏差.md` / `changeset-log.md` 及同类 `.md`）。
> 主题的可发布内容只在 `assets/` `blocks/` `config/` `layout/` `locales/` `sections/` `snippets/` `templates/` 这几个目录里，`memory/` 不是其中之一，所以正常情况下没有东西能藏进去。但**指纹一旦排除某个路径，那个路径就成了盲区**——任何 skill 在 `memory/` 下看到非 `.md` 文件、或看到被 Liquid / JSON 引用的文件，**一律停机**，不要自行判断"应该没事"。
> 开工前的一条核对（`ReconMode` 判定时顺手跑）：
>
> ```bash
> # 应无输出。有输出即停机：指纹盲区里出现了非记录类文件
> find memory -type f ! -name '*.md' 2>/dev/null
> # 应无输出。有输出说明主题代码在引用 memory/ 下的东西
> grep -rn "memory/" assets blocks config layout locales sections snippets templates 2>/dev/null | grep -v '\.md'
> ```

### 🔴 v0.2.2 不支持多 ChangeSet 同批发版

`ChangeSetFingerprint` 绑的是**整个 HEAD + 整个工作树**，不是"这个 ChangeSet 涉及的那几个文件"。由此推出一个必然结果：

> **同一工作树里第二个 ChangeSet 落盘的那一刻，第一个 ChangeSet 的 QA 结论就失效了**（工作树变了，指纹变了，§1.4 生效）。

所以「N 个块各自 QA 通过 → 一起发版」在当前模型下**不成立**：发版时不可能同时持有 N 个仍然有效的 QA 结论。

**曾经考虑过、但行不通的收口**：让合并方生成一个"集成 ChangeSet"（`ModifiedFiles` = 各块并集）再跑一次 QA。它跑不通——合并提交之后工作树是**干净的**，`git status` / `git diff HEAD` 拿到的是空集，与"各块并集"必然失配；若改用未提交的合并态过 QA，之后一提交 `HEAD` 就变，QA 又自动失效。**在绑工作树的模型下，没有一个稳定对象能从"已验证"走到"实际推送"。**

**v0.2.2 的处置：**

| 场景 | 支持情况 |
|---|---|
| 单 ChangeSet 发版 | ✅ 正常。QA 结论有效期 = 工作树自 QA 收尾后未再变动 |
| **多 ChangeSet 同批发版** | ❌ **本版不支持。** `plaud-theme-release-ops` 遇到 `ReleaseScope` 里有多于一个 `IncludedInThisPush: Yes` 的块 → **停机**，要求改为逐块串行发布（每块：实现 → 提测 → QA → 发版 → 下一块） |
| 各块在独立分支 / worktree | 每块在自己的树里 QA 有效，但**合并到发布分支后那棵树没有被任何 QA 覆盖过** —— 仍按逐块串行处理 |

> 🟢 **为什么宁可不支持也不硬撑。** 硬给一套跑不通的流程，实际效果是使用者发现走不通之后自己找绕过路径——那比明说"这版不支持"危险得多。
>
> **彻底解法留 v0.3.0**：把指纹从"工作树"改绑**不可变的 commit / tree 对象**（`git rev-parse HEAD^{tree}`），QA 验的是一个具体 tree oid，合并产生的新 tree 再验一次即可，"已验证对象 → 推送对象"之间就有了稳定标识。这是一次契约层改动，不适合在 v0.2.2 顺带做。

### 零改动任务（只读审计 / code review / A11y 审计）

统一记为 `ChangeSetId: N/A` + `ModifiedFiles: []`。此类任务：

- **免 Assess**——`AssessmentRef` 填 `N/A(ReadOnly)`
- **免 QA**——`NextRequiredSkill` 填 `None`，`ReadyForDelivery` 填 `N/A(ReadOnly)`
- **不得借用 `ReconMode: InlineLite`**。只读与 InlineLite 是两回事：InlineLite 是"改动小到可以内联评估"，只读是"根本没有改动"。混用会让只读任务继续输出 `QAStatus: NotRun` / `ReadyForDelivery: No`，与本节取值冲突。只读任务的 `ReconMode` 填 `N/A(ReadOnly)`。
- **不免措辞禁令**：审计结论只能陈述"发现了什么"，不得断言"这个模块没问题 / 可以上线"

#### 🔴 零改动必须有证明，不能靠自称

否则可以先改代码、再输出 `ModifiedFiles: []` 并声称"这只是审计"，从而完全绕开 QA。审计**开始前**和**结束后**各取一次快照，两次必须完全一致：

```bash
# 🔴 用 §2 那段 plaud_fingerprint 取快照，**不要**用 git status 文本做 hash。
git rev-parse HEAD
plaud_fingerprint          # 原样复制 §2 的函数
```

> 🔴 **v0.2.2 第五轮修：原来这里写的是 `git status --porcelain … | shasum`，它可以被绕过。**
> `git status --porcelain` 只输出**状态码 + 路径**，不含内容。所以工作树**一开始就已经 dirty**（或已有未跟踪文件）时，审计过程中继续改**同一个文件的内容**，前后两次 hash **完全相同** —— 实测复现：`M f.txt` → 改内容 → 状态行仍是 `M f.txt`，hash 不变。
> 后果是最坏的一种：agent 可以先改代码、再输出 `ChangeSetId: N/A` / `ModifiedFiles: []` 并附一份"两次一致"的 `ReadOnlyProof`，**完全绕开 QA**。这正是本节要堵的那件事，旧命令堵不住。
> `plaud_fingerprint` 覆盖内容（`git diff HEAD --binary` + 未跟踪文件逐个 `hash-object`），改内容必然变。

在契约块里如实登记 `ReadOnlyProof`（两次的 HEAD 与 hash）。**两次不一致 = 这不是只读任务**：立即退出只读模式，生成正式 `ChangeSetId` 与 `ChangeSetFingerprint`，走完 Assess → Implement → Verify。不得以"只是顺手改了一点"为由留在只读通道里。

---

## 3. Assess 阶段工件（`plaud-theme-impact` 产出）

```yaml
AssessmentRef:            # ASMT-<YYYYMMDD>-<NN>，QA 与实现 skill 引用它
ReconMode:               # LegacyImpact | IntegrationSurface | InlineLite
TargetSubject:           # 被改的 section / snippet / asset / token 名
TheoreticalReferences:   # 理论引用数（grep 命中的模板/文件数）
ActiveInstances:         # 启用实例数
DisabledInstances:       # disabled: true 的实例数（必须单列，不得并入 Active）
ActualAffectedInstances: # 逐项核查后真正会触发变化的实例数 + 清单
SharedPropagation:       # 共享 snippet / 全局 CSS / token / build 产物的传播链
LegacyImpact:            # 旧 section / 旧类名 / 旧断点 的连带影响
EntrypointCandidates:    # 可选修改入口（模板存值 / schema / 模块代码）+ 各自风险
RiskTier:                # Low | Medium | High
RequiredQAProfile:       # QA-A | QA-B | QA-C（可多选）。不要填 QA-Global——它由 QA 按 §5 恒执行，不需要下游指定
EvidenceCommands:        # 实际跑过的 grep/ls/node 命令原文，供 QA 复算
BlockingGaps:            # 缺失且必须由用户补的证据；非空则不得进入 Implement
ReadyForImplement:       # Yes | No
```

> 🔴 **`AssessmentRef` 不覆盖「要推哪些站点」。** 它回答的是「哪些**模板 / 实例**受影响」，站点维度（`TargetSites` / `ExcludedSites` / `ThemeIds` / `ScopeSourceRef`）由 `plaud-theme-qa-intake` 在 §9.1.2 里补。
> `plaud-theme-impact` **不要**自行推断站点清单——「这个模块看起来是全站的」不是证据。若在评估中确实拿到了站点信息，写进 `SharedPropagation` 的说明文字，不新造字段。

**`TheoreticalReferences` 与 `ActualAffectedInstances` 必须分开报**。"改的是共享文件"不等于"全站都会变"——逐项核查后真实影响往往收敛很小。只报"可能影响 N 处"是不合格的 Assess。

**`ReconMode` 选择**：

判据一律基于**本次计划写入集**（打算改/新建哪些文件），不是 `git diff`——Assess 发生在实现之前，工作树通常是干净的，用 diff 判会把所有任务误判成 `IntegrationSurface`。git 命令只作辅助核对。

计划写入集在实现过程中扩大（改了原本没打算改的文件）→ 该 `AssessmentRef` **失效**，必须退回重评，不得沿用。

- `LegacyImpact` — 改动触及已存在的 section / snippet / 全局 CSS / token / build 产物。默认模式。判定时注意：
  - `layout/theme.liquid`、`templates/*.json`、section group 通常**没有代码层引用方**，但它们是运行时入口，改动一律算 `LegacyImpact`。"没有引用方"只是 `InlineLite` 的豁免条件之一，不是判 `IntegrationSurface` 的理由。
  - 新建 section **接入**已有模板或 section group → `LegacyImpact`（动了存量运行时入口），同时保留 Path B 的全部检查。
  - 新建 section **同时**改了共享 snippet → `LegacyImpact`，`RequiredQAProfile` 取 `QA-A, QA-B`。
  - locale 改动四分：纯新增独占 key = `IntegrationSurface`；改已有 key 的值 / 改名 / 删除 = `LegacyImpact`。缺部分语言的翻译不升级模式，作为事实交由 QA-B 处理。
- `IntegrationSurface` — 纯新建（如 Path B 新 `sa-*` section），无存量调用方。查的是复用面与冲突面（可复用 snippet、`section-header`/`section-swiper`/`price-format`、token 与 BEM 根类冲突、素材是否误入 assets、schema/locales/数据源完整性、bundle 加载方式、是否被接入模板或 section group、是否顺手改了共享 snippet）。**不要为新建 section 伪造"模板使用量 N"。**
- `InlineLite` — 仅限**全部**满足：改动 ≤ 1 个文件、该文件无其它引用方、非共享 snippet / 非全局 CSS / 非 token / 非 build 产物、不改 schema、不改模板存值。此时实现 skill 可自行内联完成评估，但仍须在 HandoffContract 写明 `ReconMode: InlineLite` 与豁免理由。**拿不准就不是 InlineLite。**

`plaud-theme-impact` 只产出**事实**，不下 `RootCause` 结论、不选方案——那是实现 skill 的职责。

---

## 4. Implement 阶段工件（dev / section-build / ux-migration 产出）

```yaml
ChangeSetId:              # 见 §2；零改动任务填 N/A
BaseHeadSha:              # 交付工件时的 git rev-parse HEAD；零改动填 N/A
ChangeSetFingerprint:     # 见 §2，交付工件时当场生成；零改动填 N/A
ReadOnlyProof:            # 仅零改动任务：审计前后两次快照的 HEAD + hash，必须一致；其余填 N/A
AssessmentRef:            # 引用 §3 的工件；InlineLite 时填 InlineLite；只读填 N/A(ReadOnly)
OriginTriageRef:          # 本块若由反馈返工产生：§9.1.3 的 TriageId + ItemId；否则 N/A
                          #   —— 返工轮次靠它统计，单块返工不必经 orchestrator
Path:                     # A | B | C
ReconMode:                # 与 Assess 一致；InlineLite 需附豁免理由；只读填 N/A(ReadOnly)
ModifiedFiles:            # 逐个文件路径 + 一句话改动；必须与工作树一致；零改动填 []
                          #   🔴 **不含 memory/ 下的文件**：memory/ 是项目运行时状态、不属于 ChangeSet，
                          #   也已排除在 §2 指纹与 QA 的文件集合比对之外（三处范围必须一致）。
                          #   Path C 的迁移日志/清单更新照常写 memory/，但**不列进 ModifiedFiles**；
                          #   要交代那些更新时写在正文，或用 MemoryFilesUpdated 之类的正文小节，不进本字段。
RootCause:                # 机制层根因（bugfix / 迁移偏差）；新建 section 填 N/A
OptionsConsidered:        # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:        # QA-A | QA-B | QA-C（可多选）。不要填 QA-Global——它由 QA 按 §5 恒执行，无需任何上游声明
ThemeCheckRequired:       # Yes | No（判定见 §6）
VisualRegressionRequired: # Yes | No
BuildRequired:            # Yes | No（是否动了 shopify-common/src 需 npm run build）
ApprovedExceptions:       # 本 ChangeSet 声明的 🟠 ApprovedException，逐项一条；无则填 []
                          #   - Clause:      §8.1 或 §8 的条款号，如 8#5（A11y）——必须在 §8.1 封闭清单内
                          #     Scope:       🔴 逐对象绑定，且必须可枚举、可核：
                          #                  A11y 例外 → 逐「前景色 + 背景色 + 出现实例 + 实测 ratio」一条一项
                          #                  其余 → 具体文件 / 字段 / 实例路径
                          #                  禁止聚合写法（"整个模块"/"全站按钮"/"所有该色配对"/"以下若干处"）
                          #                  —— 一条 Scope 覆盖不清的项，QA 判 Failed 而不是追问
                          #     ApprovalRef: 书面批准的链接；**为空即该项 Failed**；
                          #                  批准内容覆盖不到所填 Scope（批了一处、Scope 写了一片）同样 Failed
                          #     ApprovedBy:  批准人（PLAUD PM / 设计 / 技术 owner）；填 agency 自己视同为空
BlockingGaps:             # 实现中发现但无权处理的（如需模板存值编辑授权）
QAStatus: NotRun          # 恒为 NotRun；唯一例外是用户明确弃检时填 Skipped(UserWaived)，见 §1.5
NextRequiredSkill: plaud-theme-qa-intake   # 见 §9.1.2；零改动任务填 None
ReadyForDelivery: No      # 恒为 No，见 §1；零改动任务填 N/A(ReadOnly)
```

> ⚠️ 上面每个 `key:` 与注释之间都有空格。YAML 里 `Key:# 注释` 是解析错误（`#` 会被当成值的一部分或直接报错），照抄时不要压掉那个空格。

---

## 5. Verify 阶段工件（`plaud-theme-qa` 产出）

每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`，**不得**用勾选框或"已检查"。`Blocked` 必须附原因。

```yaml
ChangeSetId:             # 被验的那个
SubmissionId:            # 引用 §9.1.2 的提测包工件；无提测包要求时填 N/A
QAAdmissionStatus:       # Accepted | Blocked —— 提测包准入判定，早于一切检查（见 §9.1.2）
QAAdmissionReason:       # Accepted 时填 Normal；Blocked 时填
                         #   PackageIncomplete | BindingMismatch | MissingArtifact | UserWaivedMaterials
                         #   —— 决定后续跑不跑检查项，见 §5「准入门在最前」
ChangeSetIdMatched:      # Yes | No —— 必须同时校验文件集合、ChangeSetFingerprint、BaseHeadSha（见 §2）
FingerprintVerifiedAt:   # Step1(验证前) / Step2(验证后) 两次重算的指纹，必须都与工件一致
QAProfilesRun:           # 实际跑了哪些 profile
ThemeCheck:              # Passed | Failed | Blocked | NotApplicable
ThemeCheckEvidence:      # CLI 版本 / 检查目录 / exit code / baseline 增量数（见 §6）
ThemeRuntimePreview:     # Passed | Failed | Blocked | NotApplicable
AdminSchemaSave:         # Passed | Failed | Blocked | NotApplicable
RegressionMatrix:        # Passed | Failed | Blocked | NotApplicable（附覆盖的断点与状态）
BreakpointsCovered:      # 实际验过的断点，Path C 为 PC/1599/1279/767/375
LocalizationCheck:       # Passed | Failed | Blocked | NotApplicable（英译德长文案）
A11yCheck:               # Passed | Failed | Blocked | NotApplicable
FixedDimensionCheck:     # Passed | Failed | Blocked | NotApplicable（组件写死宽高；例外须已说明理由）
ImageQualityCheck:       # Passed | Failed | Blocked | NotApplicable（图片清晰度红线）
CopyConfigurabilityCheck: # Passed | Failed | Blocked | NotApplicable（展示文案走 schema/locales）
StyleHardRuleCheck:      # Passed | Failed | Blocked | NotApplicable（DTC §2.1 硬性 10 条，见 qa-global.md）
ApprovedExceptionsChecked: # Passed | Failed | Blocked | NotApplicable —— 逐项核 §4 的 ApprovedExceptions
                         #   Failed（判过了，不成立）：ApprovalRef 为空 / ApprovedBy 是 agency 自己 /
                         #     Clause 不在 §8.1 封闭清单内 / ApprovalRef 覆盖不到所填 Scope
                         #   Blocked（该验但验不了）：批准链接 403、权限不足、平台故障等**核不动**的情形
                         #   NotApplicable：§4 填 []
                         #   🔴 "为空"是 Failed 不是 Blocked —— 没提供 ≠ 提供了但打不开
ApprovedExceptionsEvidence: # 逐项写 Clause + Scope + 核了哪条链接 + 结论；不接受"批准已确认"
ProfileSpecificResults:  # 各 profile 的逐项结果
Advisories:              # DTC §2.2 软性项等**非阻断**观察；不得据此把 ReadyForDelivery 置 No
Evidence:                # 命令原文 + 输出摘要；不接受"我看过了"
BlockingGaps:
ReadyForDelivery:        # Yes 仅当上述全部为 Passed 或 NotApplicable，且 QAAdmissionStatus: Accepted
```

### 准入门在最前

`QAAdmissionStatus` 的判定**早于 §2 的 ChangeSet 校验**，是 QA 的 Step 0：

1. 有 `SubmissionId` 且 `SubmissionPackageStatus: Complete` → `Accepted` + `QAAdmissionReason: Normal`，继续走 Step 1 指纹校验。
2. `SubmissionPackageStatus: Incomplete`、没有提测包工件、或提测包与 Implement 工件**绑定失配** → `QAAdmissionStatus: Blocked` + `ReadyForDelivery: No`，**零验证项执行**，把 qa-intake 的 `BlockingGaps` 原样带出。
3. **零改动只读任务**（§2）本来就**不走 Verify**：它由实现 skill 输出 §4 工件 + `ReadOnlyProof`，`NextRequiredSkill: None`。所以它**不会到达 `plaud-theme-qa`**，也就不存在对应的 `QAAdmissionStatus` / `QAAdmissionReason`。
   🔴 **v0.2.2 第七轮更正**：此前这里与 §9.2 都留了 `Accepted` + `ZeroChangeReadOnly` 这条路，而 QA 侧同时又写着「本 skill 没有零改动分支」——两处矛盾会让 QA 为一个没有 ChangeSet 的审计发出一张毫无验证含义的 `Accepted` 工件。该取值已废止。

> 🔴 **用户弃流程不产生 `Accepted`。** 用户说"这次不走提测流程"时，`QAAdmissionStatus` 仍为 **`Blocked`**，但**执行行为与上面第 2 条不同**：
>
> | 情形 | `QAAdmissionReason` | 跑不跑检查 | `ReadyForDelivery` |
> |---|---|---|---|
> | 材料不齐 | `PackageIncomplete` | **零执行** | `No` |
> | 绑定失配 | `BindingMismatch` | **零执行** | `No` |
> | 没有提测包工件 | `MissingArtifact` | **零执行** | `No` |
> | **用户主动弃提测材料** | `UserWaivedMaterials` | **照常执行技术检查项** | `No` |
>
> 弃材料时 `Evidence` 里要记用户弃流程的出处（谁在哪说的）。**靠字段判，不靠聊天上下文猜。**
>
> 区别在于：前者是"不知道该验什么 / 门本身要求不开始"，后者是"绑定有效，只是用户放弃了材料这道门，验证仍有意义"。两者都**不产生许可**。正文一句话说明"已按用户要求跳过提测材料校验，未经完整交付流程的风险由用户承担"。
> 也就是说：用户可以决定不交材料，但**不能因此得到一张写着"准入通过"的记录**。伪造 `Accepted` 会让下游（release-ops、orchestrator 台账）读到一个不存在的事实。

**不得**因为"改动很小"自行免除提测包——那是 `ReconMode: InlineLite` 的判据，与提测材料无关。

### QA Profile

| Profile | 覆盖内容 |
|---|---|
| **QA-A** | 同族 bug 扫描（一个 bug 常伴 3–5 个同族）、依赖树回归、Swiper effect 约束、旧 section 连带影响、JS 生命周期清理 |
| **QA-B** | `sa-*` / `SA:` / BEM 根类名、vendor §1–§12、素材来源（未写死 assets）、schema 完整性、空配置与满配置双测、多语言 |
| **QA-C** | disabled 实例已跳过、空 pre/sub heading 未进总览、三层入口选择正确、20 条踩坑规则中适用项、日志时机（未验收不得写日志内容） |
| **QA-Global** | Theme Check、5 断点、英译德长文案、A11y 底线、组件写死宽高、图片清晰度、展示文案可配置性 |

**QA-Global 恒执行**，与路径无关。

---

## 6. Theme Check 门（实跑，不是自检）

### 何时必须实跑

修改了 `.liquid`、theme JSON / schema、`snippets/`、`sections/`、`templates/`、`config/`、`locales/` 中任一者 → `ThemeCheckRequired: Yes`。纯文档 / 纯注释改动 → `No`。

### 命令

```bash
shopify theme check --path <theme-root> --output json
```

本地 lint **不需要登录 Shopify 店铺**（输入是本地目录，无 store / password 参数）。需要登录的是 `push` / `preview` / dev store 交互。

### 判定方式：baseline 增量，不是绝对 pass

> 🔴 **绝对 pass 不可用。** 实测某 Plaud 主题仓库（2026-08-06，CLI 3.92.0）全仓 **3334 errors / 1004 warnings**，其中 `MatchingTranslations` 占 3254 条（多语言 locale 完整性，仓库级历史状态，与单次改动无关）。剔除后仅 80 条。把"全仓零 error"当门会让每个任务永远红着，等于没有门。这不是某个仓库的特例——存量 warning 堆积是长期演进的主题仓库的常态。

正确判定：

1. 改动**前**（`git stash` 或 HEAD 版本）跑一次**全仓**，记为 baseline。
2. 改动**后**跑一次**全仓**。
3. 两次都必须是全仓，**不得只扫 `ModifiedFiles`**。原因：删除一个 asset / locale key / snippet 会让 offense 出现在**未被修改的调用方文件**里（`MissingAsset`、`TranslationKeyExists`、`MissingTemplate` 都是这样）。只比对改动文件范围会系统性漏掉这类外溢，而它恰恰是删除类改动最典型的破坏方式。
4. 分别统计并都必须为 0 才通过：

   | 指标 | 含义 | 判定 |
   |---|---|---|
   | `addedInModifiedFiles` | 改动文件内新增的 offense | > 0 → `Failed` |
   | `addedOutsideModifiedFiles` | **改动文件之外**新增的 offense | > 0 → 必须归因（见下） |

5. `addedOutsideModifiedFiles > 0` 时必须逐条归因，**不得笼统略过**：
   - 归因为本次改动引起（典型：删了被引用的资源）→ `ThemeCheck: Failed`
   - 归因为基线漂移（期间有人动了别的文件、依赖重装、build 产物变化）→ `ThemeCheck: Blocked` + 说明，**不得**判 Passed
6. 顺手修掉存量 offense 是加分项，但不得作为通过条件，也不得扩散到本次授权范围外的文件。

### 重点关注的 check

这些是 Plaud 主题历史高发、且与本矩阵红线直接对应的：

| check | 对应红线 |
|---|---|
| `LiquidHTMLSyntaxError` | Liquid 文件格式（用户点名的漏项） |
| `UnclosedHTMLElement` | 同上 |
| `ImgWidthAndHeight` | `image_url` 必须带 width / 防 CLS |
| `ValidSchemaName` | schema 命名（Path B 的 `SA:` 前缀） |
| `MissingAsset` / `MissingTemplate` | 引用了不存在的资源 |
| `UnknownFilter` / `DeprecatedFilter` | Liquid 过滤器 |
| `ParserBlockingScript` | 性能 |
| `UndefinedObject` / `UnusedAssign` | Liquid 正确性 |

### Blocked 的合法情形

CLI 未安装、仓库不是 theme root、`shopify-common` build 产物缺失导致检查失真、`.theme-check.yml` 依赖缺失、网络不可用导致首次安装失败。此时输出 `ThemeCheck: Blocked` + 原因，**绝不可**输出 `Passed`。

### 不得越权声明

`ThemeCheck: Passed` 只代表静态 lint 无新增 offense。**不得**表述为"Shopify 兼容性全部通过"。运行时行为、视觉、admin schema 保存行为分别由 `ThemeRuntimePreview` / `AdminSchemaSave` / `RegressionMatrix` 承担。

---

## 7. Stop, don't guess

任一 skill 在缺少必需上游输入时**必须停下要证据**，不得凭经验补齐、不得用"通常来说"填空。典型停机点：

- 找不到目标 section / snippet 的实际文件 → 停，要路径
- 模板存值需要编辑但未获授权 → 停，要授权（`templates/*.json` 默认只读）
- spec 值等距两可（如 20 介于 16/24、12 介于 8/16）→ 停，问用户选哪档
- Figma 值无近邻 token 且视觉重要 → 停，确认后再硬编码
- `plaud-theme-ux-migration` 未读取适用的踩坑规则 → 停，先读再改
- QA 拿不到 `ChangeSetId` 或 `ModifiedFiles` 与工作树不符 → 停，要求重新生成
- 需要浏览器预览验证但无法预览 → 标 `Blocked`，不猜"应该没问题"

停机时输出 `BlockingGaps` 并明确说明**需要用户提供什么**，不要输出半成品然后附一句"可能需要确认"。

---

## 8. 全路径红线（任何 skill 不得违反）

这些与路径无关，`plaud-theme-shared` 是唯一事实源，各 skill **不得复制数值**，只得引用：

1. 展示文案必须走 schema 字段或 locales；Liquid 不得 `| default: '...'` 兜底；`blank` 不输出空壳 DOM
2. 禁止无理由写死组件 `width` / `height`；例外仅限图标、1px 线、明确固定的技术容器、Swiper cube/vertical 要求的固定 px height，且须说明原因
3. 图片清晰度红线：`image_url` 的 `width:` 只用于防 CLS / 适配容器，须按容器实际显示宽度 × 高 DPI 取值，禁止用过小 width 把展示图下采样糊掉
4. 颜色走 token / CSS 变量，不写死 hex（设计系统固定渐变资产等已文档化例外除外）
5. A11y 底线：button 语义、aria-label、dialog trapFocus、轮播 button + aria-label、**对比度 ≥ 4.5:1（受控偏差见下）**、skip link、focus-visible

   > **对比度的唯一受控偏差**：当某组前景/背景配对**由 UX Spec 直接给出**、比值落在 **3.0 ≤ x < 4.5**、且**已取得设计方或 PM 的书面偏差批准**时，QA 记入 `Advisories` 而不判 `A11yCheck: Failed`。
   > 可用的配对是一张**封闭 allowlist**（`a11y.md` §5.1），QA 无权扩充；**批准引用为空则降级为 `Failed`**；**比值 < 3.0 无任何豁免**，spec 给出的也判 `Failed`（此时 `BlockingGaps` 写明属规范缺口，不算开发的实现错误）。
6. JS：null 守卫、TDZ 安全，监听 / timer / observer / subscription 在 `disconnectedCallback` 清理
7. 生成文件（build 产物）勿手改，改动落到源 + 重新 build
8. 最终交付必须经 `plaud-theme-qa`（§1）

### 8.1 运营协作红线（源自《DTC 开发交付标准 v1.0》§三）

> ⚠️ **原文的性质**：DTC §三 标题写的是「软性，尽量遵守，在开发/测试时注意这些问题」。v0.2.0 把其中 10 条一律提为 🔴 硬红线；**设计方在 v0.2.0 评审中明确反对「一刀切」**（原话：过于绝对化会导致设计/开发/测试任何环节的偏差都要全环节对齐，降低效率，应给出合理空间，并点名"复用 section"的情形）。v0.2.1 据此改为**三档**，并对 #5 / #9 / #10 改成**按范围**判定而不是整条降级。这个分级仍是矩阵侧的解释，**若与运营/agency 的双方共识冲突，以双周会的书面结论为准**。

#### 三档的定义

| 档 | 含义 | QA 后果 |
|---|---|---|
| 🔴 **红线** | 踩了必然出事，且机械可判 | `Failed`，阻断 `ReadyForDelivery` |
| 🟠 **可论证放行** | 偏离本身不必然出事，但必须能被复核 | 论证成立 → `Passed`（附论证引用）；论证缺失/空洞 → `Blocked`（可补）；论证证明确实不该偏离 → `Failed` |
| 🟡 **建议** | 只在同页面内部明显不自洽时才提 | 进 `Advisories`，不阻断 |

🟠 **不是"写了理由就放行"。** 它分两种，判据不同：

| 类型 | 谁提供 | QA 怎么复核 | 空的时候 |
|---|---|---|---|
| **EvidenceBased** | agency / 实现方**自证** | 对着 `AssessmentRef` + `ActualAffectedInstances` + `OptionsConsidered`（§4）核**证据是否齐**，不需要任何人"审批" | 三者缺任一、或只有套话没有影响面引用 → `Blocked` |
| **ApprovedException** | agency 可起草，但**必须**有 PLAUD PM / 设计 / 技术 owner 的书面 `ApprovalRef` | 核 `ApprovalRef` 是否存在、是否指向本 ChangeSet 的这一项、条款是否在下方封闭清单内 | `ApprovalRef` 为空 → **降级为 `Failed`**（与 §8 红线⑤ A11y 豁免同一模式：封闭适用范围 + 批准引用必填 + 空引用回落 Failed） |

🔴 **agency 自写自批不构成 `ApprovedException`。** 提供论证的人和批准的人必须不同方。

#### 🔴 `ApprovedException` 的封闭适用清单（v0.2.2 收口）

**只有下表列出的条款可以走 `ApprovedException`。清单是封闭的，QA 与实现方都无权扩充；不在表内的条款，`ApprovalRef` 再齐也不改变判定。**

| 可走 ApprovedException 的条款 | 出处 | 条件 |
|---|---|---|
| A11y 对比度落在 **3.0 ≤ x < 4.5** 且配对在 `a11y.md` §5.1 的封闭 allowlist 内 | §8 红线⑤ | 批准引用必填；`< 3.0` 无任何豁免；allowlist 外一律按常规判 |

> **§8.1 的 11 条里目前没有任何一条可走 `ApprovedException`。** 尤其：
>
> - **第 10 条本次新建 / 修改字段的默认值合规性是 🔴，不可批准豁免。** 拿到设计方或 PM 的书面批准也不改判——正确处理是**先改规范或改默认值**，再交付。批准链接只能让它进 `BlockingGaps` 说明"规范缺口待裁决"，不能让 `StyleHardRuleCheck` 变 `Passed`。
> - 第 8 条、第 9 条纯新增、第 10 条未触及的存量默认值走的是 **`EvidenceBased` / 🟡**，不是批准豁免。
>
> 这条收口是 v0.2.2 补的：v0.2.1 只定义了 🟠 的两种类型却没给封闭清单，任何红线理论上都能尝试走批准通道。

#### 条款分级表

| # | 条款 | 级别 | 判定方式 |
|---|---|---|---|
| 1 | 涉及主流程（ATC 按钮、购买链路、结账等）的功能改动，**且会修改全站默认配置**时 → 必须做成开关且默认关闭，由运营自行开启 | 🔴 | 两个条件**同时**满足才触发。只改单站点存值、或不动全站默认值的主流程改动不受此约束——原文的"会修改全站默认配置"这个前提不得省略 |
| 2 | 不得修改运营的线上配置项 | 🔴 | `templates/*.json`、`config/settings_data.json` 默认只读，改需授权（已见 §7 停机点） |
| 3 | 运营验收完成前，禁止发版对应 section / page | 🔴 | 由 `plaud-theme-release-ops` 守；QA 通过 ≠ 可发版（§1.1） |
| 4 | 发版前必须确认推送站点清单 | 🔴 | `TargetSites` / `ExcludedSites` 必须显式列出，见 §9.1.4 |
| 5 | 新增文案禁止硬编码 | 🔴 **本次新增/修改的行** / 🟡 存量未触及 | **按范围判**，不整条降级：① 本 ChangeSet `git diff -U0` 新增或修改的行里出现硬编码文案 → 🔴 `Failed`（固定 UI 文案走 `locales`，运营可配文案走 schema 字段）；② 未被本次改动触及的存量硬编码 → 🟡 `Advisories`，**不要求顺手修**；③ ⚠️ 但如果本次改动**让原本不可达的旧硬编码进入了新的可达路径**（复用旧 snippet、放开条件分支、新模板挂载旧 section），它按①判 🔴 —— 这一条**必须人工判**，`git diff` 看不出来 |
| 6 | metafield 的 namespace / key / type 必须与已有定义一致，不得新建未申报字段 | 🔴 | 新建前先 grep 现有定义；无对应定义 → 停机要申报 |
| 7 | 动手前先算影响面 | 🔴 | 已由 `plaud-theme-impact` 承担（§3）。**它是红线的理由不是"不可逆"，而是"没有它后面每一条都失去可复核的基准"** |
| 8 | 优先改模板存值，其次 schema，最后模块代码 | 🟠 **EvidenceBased** | 偏离三层入口顺序时，用**既有的 `OptionsConsidered`（§4）**说明为什么上层入口不适用 + 引用 `AssessmentRef`。**不新增 `EntrypointRationale` 字段**——那会形成第二个事实源 |
| 9 | schema 已有的 option values 永不修改 | 🔴 **删/改既有 value** / 🟠 纯新增 | **删除或修改**既有 `value` → 🔴（会让存量实例存值静默失效）；**纯新增** option 不触发本条，但仍须在 `OptionsConsidered` 里给出：新 value 的 Liquid 端映射、schema 保存验证、旧存值向后兼容结论。「新增一律允许、无需验证」**不成立** |
| 10 | 影响 UX 合规的字段，默认值必须已合规；任何字段留空都不能崩 | 🔴 **留空不崩** + 🔴 **本次新建/修改字段的默认值** / 🟡 未触及的存量默认值 | 崩就是崩，无豁免（QA-B 空配置 / 满配置双测）。默认值合规性：本次**新建或修改**的 UX 相关字段 → 🔴（否则每加一个实例就持续制造新的不合规状态）；本次未触及的存量字段默认值 → 适用 §8.1.2 存量复用豁免 |
| 11 | 公共文件修改的英文注释标记 | 🟡 | 见 §8.2 |

### 8.1.1 测试集治理（DTC §一 第 3 条）

DTC 把「测试集要定期更新，建立 PLAUD 专属测试规范」列为**三条总则之一**，但它跨越多个 skill，因此在契约层单列：

| 条款 | 落点 | 字段 |
|---|---|---|
| agency 维护测试集并**随交付更新**，不是一次性文档 | `plaud-theme-qa-intake` | **v0.2.1 起收敛为一行 `TestSetTrace`** + **v0.2.2 起附 `PreviousAcceptedTestSetTrace`**（原来是三项分别手写，设计方评审指出「重复性工作影响效率」）。🔴 **完整取值规则只在 `package-checklist.md` §3 一处**，本表不复制语法，避免第二个事实源 |
| **每个线上 bug 反推一条回归用例入库** | `plaud-theme-release-ops` | `RegressionCasesAdded`（为空即本次上线治理未完成） |
| 由 PLAUD 测试同学（Aily）**审查** agency 的测试注意文档，双方对齐后固化 | 外部流程 | 矩阵不代替这道人工审查。**不写进 `BlockingGaps`**（那是停机项，会污染语义），改记 QA 的 `Advisories`：「测试规范尚未双方固化」 |

> **为什么不能退到"只给个链接"**：同一个 URL 可以被覆盖内容，也可以每次指向一份临时文档——只要引用不带**不可变 revision**，"长期增量维护"和"每次现编一份"就完全不可区分，这条总则等于没落地。`TestSetTrace` 的成本是一行，其中 `Added` / `Updated` 两段可由测试报告里每条用例自带的标记直接汇总、**不需要另写清单**（`Removed` 推不出来，必须显式列——被删的用例已不在本轮报告里）；若平台 URL 本身已携带不可变 revision，则「引用 + 版本」合并为一个字段即可。**完整语法与判定见 `plaud-theme-qa-intake/references/package-checklist.md` §3，本文件不复制。**

> 🔴 **矩阵不拥有测试集本身。** 测试集是项目侧长期资产（与 `memory/` 同类，不随包分发）。矩阵能做的是：提测时要求用例可复核（`test-case-format.md`）、上线后要求补回归用例、以及在两处都指向同一份测试集。
> **不得**在包里内置一份测试集副本——那会变成第二个事实源，且下次 install 被整包覆盖。

### 8.1.2 存量复用豁免（Legacy Reuse Carve-out）

复用既有 section / snippet / 遗留工具类时，**不因未被本次改动触及的存量偏差判 `Failed`**，记 `Advisories`，也不要求顺手修。

🔴 **它豁免的是"修复义务"，不是"验证范围"。** 三条硬约束：

1. **必须能证明该偏差在 `BaseHeadSha` 上已存在**（给出证据命令或引用）。证不出来 → 按新引入判，不适用豁免。
2. **不得加重，也不得让它变成新的可达行为。** 本次改动使旧偏差在更多实例 / 更多断点 / 新模板上可达 → 按新引入判 🔴（与红线⑤③同一判据）。
3. **回归范围不缩小。** 仍按 `plaud-theme-impact` 的 `ActualAffectedInstances` 全量回归；QA-B 的空配置 / 满配置双测**不因本条豁免**——新接入的上下文、本次改过的字段、schema、以及本次可达的所有路径都要双测。

> 因此本条**依赖** `plaud-theme-impact`，不与它冲突：没有影响面工件就无法证明"已存在且未加重"，豁免自动不成立。

### 8.2 公共文件的改动注释（🟡 建议级，且有前置约束）

DTC §三 第 11 条要求公共文件的改动加英文注释标记。这条与矩阵现有的「默认不写注释、禁止任务过程注释」（`liquid-schema-format.md`）**直接冲突**，因此按下列边界执行，不得无差别铺开：

**只在这些文件生效（allowlist）**：多模块共享的 `snippets/`、全局 CSS / SCSS 源、`layout/theme.liquid`、`assets/` 里的共享 JS。
**禁止写入**：build 产物（`snippets/design-system.liquid` 等生成文件——注释会在下次 build 被冲掉）、`templates/*.json`（JSON 不支持注释，写了直接坏）、单模块自用的 section 文件。

四种格式（**内容必须英文**；注释语法按文件类型选，不得把 `//` 原样塞进 Liquid 或 CSS）：

DTC 原文写的是「年月日时间」，即**日期 + 时刻**。统一用 ISO 8601：`YYYY-MM-DD HH:MM`（需要跨时区协作时用 `YYYY-MM-DDTHH:MM+08:00`）。只写日期不写时刻，同一天多次改动就分不出先后。

| 类型 | 格式（**内容必须英文**） |
|---|---|
| 新增 | 起止都标：`<what it does> - <owner> - YYYY-MM-DD HH:MM - Begin` / `… - End` |
| 插入式 | 旁注一行：`<why changed> - <owner> - YYYY-MM-DD HH:MM` |
| 覆盖式 | 起止都标：`<why overridden> - <owner> - YYYY-MM-DD HH:MM - Begin` / `… - End` |
| 删除 | 删除处留标记：`<why removed> - <owner> - YYYY-MM-DD HH:MM` |

示例（`.liquid`，注意注释语法与英文内容）：

```liquid
{% comment %} Add subscription badge for SA modules - zhang.san - 2026-08-12 14:30 - Begin {% endcomment %}
...
{% comment %} Add subscription badge for SA modules - zhang.san - 2026-08-12 14:30 - End {% endcomment %}
```

| 文件类型 | 注释语法 |
|---|---|
| `.liquid` | `{% comment %} … {% endcomment %}`（**不是** `//`；`//` 在 Liquid 里会原样输出到 HTML） |
| `.css` / `.scss` | `/* … */`（`.scss` 源里可用 `//`，但它不会进编译产物，做标记时用 `/* */`） |
| `.js` | `//` 或 `/* */` |

「负责人 / 修改人」取真实姓名或工号，**不得**填 agent 名或留空；时间用 ISO `YYYY-MM-DD HH:MM`，不用 `2026/8/12` 这类本地格式。拿不到负责人身份时**停机问用户**，不要自己编一个。

---

## 9. 输出块格式

每个 skill 回复的**最后**必须是一个 ` ```yaml ` 代码块，内含该阶段对应的字段（§3 / §4 / §5）。字段缺失视为契约违规。正文可以自由组织，但契约块不得省略、不得改名、不得塞进正文段落里。

> 🔴 **`plaud-theme-shared` 的 `SharedContractCheck` / `ReferencesLoaded` 不是工件字段**（v0.2.2 第八轮补明）。它们是"我读过契约层、解析到哪条路径/阶段"的**正文自检块**，`plaud-theme-shared` 本身是 order 0 的被引用层，既不在阶段轴上、也不在 §0.1 那四个非阶段 skill 之内，因此**没有** `ArtifactKind`、也不出 §3/§4/§5 工件。三条硬约束：
> 1. 自检块写在**正文里、阶段契约块之前**，回复的最后一个 yaml 块永远是阶段工件本身；
> 2. **不得把这两个字段并进阶段契约块** —— §4 是 20 字段、§5 是 26 字段的**封闭集合**，多一个 key 就会被 QA 的结构核判违规；
> 3. **下游不得消费它们**。QA / qa-intake 的事实源只有 §3 / §4 / §9.1.x，没有任何判定可以建立在自检块上。

### 9.1 协调工件（`plaud-theme-orchestrator` 专用）

orchestrator **不是阶段 producer**——它不产生影响面事实、不产生代码改动、不产生验证结论，因此不使用 §3 / §4 / §5 的任何模板。它输出的是协调工件：

```yaml
ArtifactKind: Coordination
OrchestrationId:          # ORCH-<YYYYMMDD>-<NN>
PathResolved:             # A | B | C | Cross(B+C) | Cross(A+C)
ChangeSetPlan:            # 拆出的每个 ChangeSet：编号 / 范围 / 归属 skill / 依赖关系
ParallelSafe:             # 只描述 Assess 只读并行 / 可拆独立 worktree 的块。
                          #   🔴 同一棵工作树里 Implement / 指纹 / QA / release 一律逐块串行
                          #   （指纹绑全树，第二块落盘即让第一块失效）——**disjoint 不构成
                          #   同树并行的理由**（v0.2.2 第九轮更正）
ChangeSetStatus:          # 各 ChangeSet 当前阶段与 handoff 引用；含 SubmissionId（提测准入）与 TriageId（若该块由反馈回流产生）
BlockingGaps:
AllChangeSetsDelivered:   # Yes | No —— 全部下辖 ChangeSet 的 QA 均为 ReadyForDelivery: Yes 时才为 Yes
```

`AllChangeSetsDelivered` 是**汇总读数，不是交付许可**。它只能反映各 ChangeSet 的 QA 结论，orchestrator 不得据此自行宣布可交付，也不得在任一 ChangeSet 的 QA 未通过时置 Yes。交付权仍然只在 `plaud-theme-qa`（§1）。

### 9.1.2 提测准入工件（`plaud-theme-qa-intake` 专用）

```yaml
ArtifactKind: QAIntake
SubmissionId:             # SUB-<YYYYMMDD>-<NN>
ChangeSetId:              # 本次提测对应的 ChangeSet（§2）
ChangeSetFingerprint:     # 从 Implement 工件原样带过来，不重算、不改写
PackageRootRef:           # 提测材料所在位置：本地目录绝对路径 / 云端根文档 URI —— QA 据此复算
PackageFingerprint:       # 见下方「包指纹」；提测材料本身的内容绑定
TargetSites:              # 本次要推的站点清单（显式列出，不得写"相关站点"）
ExcludedSites:            # 明确不推的站点 + 原因
ThemeIds:                 # 各站点对应的主题 ID（预览与验收都要定位到具体主题）
ScopeSourceRef:           # 站点清单的来源（运营需求单 / Linear issue / 飞书消息链接）
PreviewManifest:          # 后台链接 + 前端链接 + 各自实测可访问性与检查时间（内容）
PreviewManifestStatus:    # Complete | Incomplete —— 上述内容的判定（状态）
ConfigurationGuideStatus: # Complete | Incomplete | NotApplicable
SelfTestReportStatus:     # Complete | Incomplete
TestSetTrace:             # 语法与判定**唯一**见 package-checklist.md §3（本处不复制规则）
PreviousAcceptedTestSetTrace: # 上一轮通过准入的那一行原文 | None(FirstSubmission) | Unavailable(<原因>)
                          #   —— 稳定文档 ID 须与本轮一致、revision 须不同；不一致即 SelfTestReportStatus: Incomplete。
                          #   **例外**：取数路径三级都拿不到时填 Unavailable(<原因>)，此时不判 Incomplete、改记 Advisories
                          #   完整取数路径与判定见 package-checklist.md §3（唯一事实源，本处不复制规则）
ScreenshotManifestStatus: # Complete | Incomplete
ImpactScopeStatus:        # Complete | Incomplete
ReworkDeltaStatus:        # Complete | Incomplete | NotApplicable（非返工轮次填 NotApplicable）
SubmissionPackageStatus:  # Complete | Incomplete —— 上述**六项 Status** 全 Complete/NotApplicable 才为 Complete
BlockingGaps:             # 缺哪份材料、缺什么字段，逐项写清
NextRequiredSkill: plaud-theme-qa
```

> 🔴 **提测包必须与某个具体 ChangeSet 焊死，否则可以重放。** `ChangeSetId` + `ChangeSetFingerprint` 从 Implement 工件**原样带过来**，QA 在 Step 0 会拿它与当前 Implement 工件逐字比对——不比对的话，A 任务的 `Complete` 包可以直接拿去给 B 任务用；材料也可以在 intake 通过之后被替换（所以 QA 还要重算 `PackageFingerprint`）。

**这个工件没有 `ReadyForDelivery` 字段，一个字都不许出现。** 它判的是「材料齐不齐」，不是「代码行不行」；语法上刻意与 `ReadyForDelivery` 拉开距离（`Complete/Incomplete` vs `Yes/No`），就是为了防止下游误读成第二个发布许可。

**六项材料的验收标准**（对应 DTC §四）：

| 字段 | Complete 的条件 |
|---|---|
| `PreviewManifest` | 后台链接与前端链接**都实测访问过**并记录时间；后台链接必须可配置（能看到 schema 字段），不是只读预览。失效链接 = 未提测 |
| `ConfigurationGuideStatus` | 新 section / 新配置项必交：字段说明 + 默认值 + 使用场景 + 填错怎么办，**关键部分有截图**。本次未新增任何配置项时才可填 `NotApplicable` |
| `SelfTestReportStatus` | ① 用例写成可复核形式：前置条件（具体站点 + 主题 ID + 配置状态）→ 操作步骤（具体 URL）→ 预期结果（**具体值或现象**）→ 结论，且**有附件截图/视频**。预期结果写"显示正常""功能可用"的用例**视同未测**；② **`TestSetTrace` + `PreviousAcceptedTestSetTrace`** —— 缺 `@<不可变revision>`、delta 段留空、`Removed` 段缺失、或与上一轮的稳定文档 ID 不一致均判 `Incomplete`；**唯一例外**是取数路径三级都拿不到（填 `Unavailable(<原因>)` → 不阻断、记 `Advisories`）。**完整语法与判定唯一见 `package-checklist.md` §3**（本表不复制语法） |
| `ScreenshotManifestStatus` | 8 张：`375 / 768 / 1024 / 1280 / 1440` + 边界 `767 / 1279 / 1599` |
| `ImpactScopeStatus` | 本模块被几个模板使用、涉及哪些站点。**直接引用 `plaud-theme-impact` 的 `AssessmentRef`**，不自行重算；站点维度 `AssessmentRef` 不覆盖，须另填 `TargetSites` |
| `ReworkDeltaStatus` | 返工轮次必交「本轮修改点」清单（逐条：反馈 → 改了什么 → 在哪个文件） |

> 🔴 **提测截图不能替代 QA 自己的回归。** 这 8 张是给运营/PM 看的交付材料；QA 的 `BreakpointsCovered`（Path C 为 `PC / 1599 / 1279 / 767 / 375`）是 QA 自己实跑的，两者互不顶替。记 `PC` 时必须写出实际像素宽度，如 `PC(1920)`，光写 `PC` 无法复核。

**包指纹 `PackageFingerprint`**：§2 的 `ChangeSetFingerprint` 只覆盖**主题仓库工作树**，对截图、配置文档、测试报告、预览 URL 一无所知。因此提测材料另算一份：

```bash
# 在提测材料目录（不在主题仓库内）执行
plaud_package_fingerprint() (
  set -o pipefail
  # 🔴 与 §2 同族的三条约束：payload 先收变量再 hash、逐行数核对、空 URL fail closed。
  #    行数核对不能省：循环零次迭代（heredoc 建不了临时文件、find 无输出等）退出码也是 0，
  #    不核对就会退化成"只 hash 了 urls: 那一行"——材料完全没参与，指纹却完全正常。
  # 🔴 `PLAUD_PREVIEW_URLS` 的事实源与序列化必须固定（v0.2.2 第九轮补：此前只规定「不得为空」，
  #    没说从哪来、怎么排、用什么分隔 —— intake 与 QA 各自拼一次，同一组 URL 因顺序或空白不同
  #    就算出两个 PackageFingerprint，材料没动却判 BindingMismatch）。唯一合法构造：
  #      取 §9.1.2 `PreviewManifest` 里的**前端预览 URL 与后台配置 URL 全集**（不含检查时间、
  #      不含备注），逐条 trim 首尾空白，`LC_ALL=C sort -u` 去重排序，用**单个换行**连接：
  #        PLAUD_PREVIEW_URLS=$(printf "%s\n" "$u1" "$u2" … \
  #          | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | LC_ALL=C sort -u)
  #    producer 与 verifier 必须用一字不差的同一构造；URL 集合变了就是新的提测包，重算即可。
  [ -n "$PLAUD_PREVIEW_URLS" ] || return 1      # 预览 URL 不得为空
  # 🔴 三类必须 fail closed，不能静默排除（v0.2.2 第五轮补，均实测过会静默漏算）：
  #    (a) 路径含换行 → NUL→换行转换会把它拆成两行，两半都 hash 不到
  #    (b) symlink    → -type f 直接跳过；改 symlink 目标内容、或改指向，指纹都不变
  #    (c) 隐藏文件/目录 → 主体 `find . -type f` **确实会 hash 到**它们，但隐藏对象
  #        （`.DS_Store`、`.git/`）要么被系统随时改写、要么携带无关大树，会让同一份材料
  #        算出不同指纹，所以仍然 fail closed —— 是「不许有」，不是「悄悄跳过」。
  nl_probe=$(find . -print0 | tr -d '\0' | tr -cd '\n' | wc -c | tr -d ' ')          || return 1
  [ "$nl_probe" = "0" ] || { echo "NEWLINE_IN_PATH: 材料路径含换行，先重命名" >&2; return 1; }
  # 🔴 只允许普通文件与目录。symlink / FIFO / socket / device 一律 fail closed
  #    —— 主体是 `-type f`，其余类型会被**静默跳过**（实测：材料树里加个 FIFO，指纹不变且返回 0）。
  #    不用 `| head -5`：pipefail 下 head 提前关闭管道会让 find 收到 SIGPIPE、丢掉诊断信息。
  # 🔴 两类分开报（v0.2.2 第八轮）：旧写法把隐藏对象和非普通文件合并成一条
  #    "只接受普通文件与目录"，而 `.DS_Store` **就是**普通文件 —— macOS 上只要用 Finder
  #    打开过材料目录就必然有它，agent 拿到的是一句自相矛盾、无从下手的报错，提测指纹
  #    等于永远算不出来。现在分别给出各自的处置动作。
  bad_type=$(find . ! -type f ! -type d -print)                                       || return 1
  [ -z "$bad_type" ] || { printf 'UNSUPPORTED_MATERIAL_OBJECT: 只接受普通文件与目录，下列对象不进指纹（先移除或换成真实文件）：\n%s\n' "$bad_type" >&2; return 1; }
  bad_hidden=$(find . -name '.*' ! -name '.' -print)                                  || return 1
  [ -z "$bad_hidden" ] || {
    printf 'HIDDEN_MATERIAL_OBJECT: 材料目录不得含隐藏文件/目录（内容会被系统改写或携带无关大树，指纹不可复现）：\n%s\n' "$bad_hidden" >&2
    printf '  处置：确认无用后删除，例如 `find . -name .DS_Store -delete`；有用的材料改成不以点开头的名字。\n' >&2
    return 1; }
  # 🔴 `sort` 必须固定 `LC_ALL=C`（v0.2.2 第九轮实测）：同一份含 `ä.txt` / `中.txt` 的材料，
  #    C / en_US.UTF-8 / zh_CN.UTF-8 排出三种顺序、三个不同指纹 —— intake 与 QA 只要环境
  #    locale 不同就必然 `BindingMismatch`，而材料一个字节都没改。
  files=$(find . -type f -print0 | tr '\0' '\n' | sed '/^$/d' | LC_ALL=C sort)       || return 1
  n_files=$(printf '%s\n' "$files" | grep -c '[^[:space:]]') || return 1
  [ "$n_files" -gt 0 ] || return 1              # 材料目录不得为空
  body=$(
    # 🔴 同 §2：必须带结尾换行，否则最后一个材料文件不进循环
    printf '%s\n' "$files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      # 🔴 必须先取出再判空：$( ) 的失败不会让外层 printf 失败
      h=$(shasum -a 256 -- "$f" | cut -d' ' -f1) || exit 1
      [ -n "$h" ] || exit 1
      printf 'f %s %s\n' "$f" "$h" || exit 1
    done || exit 1
  ) || return 1
  got=$(printf '%s\n' "$body" | grep -c '^f ') || got=0
  [ "$got" -eq "$n_files" ] || { echo "FILE_COUNT_MISMATCH: $got != $n_files" >&2; return 1; }
  printf '%s\nurls:%s\n' "$body" "$PLAUD_PREVIEW_URLS" | shasum -a 256 | cut -d' ' -f1
)
plaud_package_fingerprint || echo "PACKAGE_FINGERPRINT_FAILED"
```

> 🔴 **为什么要把 `shasum` 的结果先赋给变量再判空。** 写成 `printf '%s %s\n' "$f" "$(shasum ...)"` 时，命令替换里的失败**不会**让 `printf` 失败——`printf` 拿到空串照样成功返回 0，`|| return 1` 永远不触发，指纹退化成"只反映文件名列表、不反映文件内容"。
> 这与 §2 那个 `--find-renames=false` 的 bug 是**同一类**错误：管道/替换里的静默失败。写任何指纹命令时都要问一句：这一段失败了，外层真的会知道吗？
>
> **自检**：改一个材料文件的内容（不增删文件），指纹必须变化；还原后必须精确复原。做不到就是命令又退化了。

**材料放云文档时怎么算指纹**：上面的算法只 hash 本地目录。材料在飞书云文档 / Linear 附件里时，本地目录放一份 **manifest**（一个 `materials.tsv` 之类的纯文本文件）参与 hash：

```
<材料名>\t<URI>\t<不可变版本号或 revision>\t<内容 digest>
```

> 🔴 **"人工核对时间"不是内容绑定，v0.2.2 第五轮删除该选项。** 它记的是"某人某时看过"，内容随后被替换时 manifest 一个字都不会变 —— 与下面"无 revision / 无 digest 一律 `Incomplete`"直接矛盾。两栏都必须是**机器可复核**的值。

| 材料位置 | 怎么进指纹链 |
|---|---|
| 本地文件（截图等） | 直接 hash 文件内容 |
| 飞书云文档 | manifest 记 URI + **文档版本号**（飞书文档有 revision）；改了文档版本号会变 → 指纹变 |
| Linear 附件 | manifest 记 URI + 附件 ID |
| **无版本号 / 无 digest 可取的外链** | 🔴 **不允许** —— 该材料判 `Incomplete`。要么下载一份到本地目录参与 hash，要么换成能取版本号的载体 |

> 🔴 **不能内容绑定的材料一律 `Incomplete`，不得带着"已知弱环"拿到 `Complete`。**
> 否则整条防替换链就有一个公开的洞：把材料挂在一个无版本外链上 → 内容随便换 → 指纹照样对得上 → `SubmissionPackageStatus: Complete` → `QAAdmissionStatus: Accepted`。
> **`BlockingGaps` 是停机项，不是"记一笔就放行"的免责栏。**

**QA 复算时对云端材料要重新查远端**：不能只比对本地 manifest（那样 manifest 没更新、云文档内容变了照样通过）。对每条云端材料重新取一次当前 revision / digest，与 manifest 记录值比对，不一致 → `QAAdmissionStatus: Blocked` + `QAAdmissionReason: BindingMismatch`。取不到（无权限 / 服务不可用）→ `Blocked`，不猜。

> 🔴 **提测材料不得写进主题仓库。** 截图、文档一旦落进工作树，`ChangeSetFingerprint` 立刻变化，QA 的 Step 1 会判 `ChangeSetIdMatched: No` 并停机——你会因为交了材料而过不了自己的准入门。材料放仓库外的独立目录或云文档。

### 9.1.3 反馈分类工件（`plaud-theme-feedback-triage` 专用）

```yaml
ArtifactKind: FeedbackTriage
TriageId:                     # TRI-<YYYYMMDD>-<NN>
FeedbackSource:               # QA打回 | 运营验收 | 线上反馈 | 内部发现
OriginChangeSetId:            # 该批反馈针对的原 ChangeSet；无对应时填 N/A
FeedbackItems:                # 见下：每条一个条目，字段逐条填，不得只给总体结论
LinearStatusAdvice:           # 建议的 Linear 状态操作；本 skill 不自动执行
BlockingGaps:
```

`FeedbackItems` **每一条**都是一个完整条目，**九个字段缺一不可**（`ItemId` / `Text` / `ClassificationRecommendation` / `EvidenceRefs` / `PMDecision` / `PMDecisionValue` / `PMDecisionRef` / `NextRoute` / `NewWorkItemRef`）—— 旧文写「五个字段」与下面的模板不符，按「五个」执行会漏掉 PM 确认与回流链所需的后四项（v0.2.2 第六轮更正）：

```yaml
FeedbackItems:
  - ItemId:                       # TRI-<...>-01、-02…
    Text:                         # 反馈原文，不改写、不合并
    ClassificationRecommendation: # DeliveryDefect | RequirementEvolution | Undetermined —— 本 skill 的建议
    EvidenceRefs:                 # 依据：PRD 条目 / Figma 节点 / UX Spec 章节；查过没找到的也要写"未找到"
    PMDecision:                   # Pending | Confirmed
    PMDecisionValue:              # PM 确认的**是哪一类**（DeliveryDefect | RequirementEvolution）；Pending 时填 N/A
    PMDecisionRef:                # PM 确认的出处（Linear 评论 / 飞书消息）；Pending 时填 N/A
    NextRoute:                    # AwaitPMDecision | NewWorkItem(Assess) | Backlog(排期) | NoAction
    NewWorkItemRef:               # NextRoute 为 NewWorkItem 时：**Assess 之前已创建的外部工作项**
                                  #   （Linear issue 等）。**不得填 ChangeSetId** —— 那要到 Implement
                                  #   才产生；新 ID 由实现 skill 在自己的 OriginTriageRef 里回指本工件
```

> 🔴 **分类是逐条的，不是整批的。** 一段反馈里常混着缺陷与新想法（见 `plaud-theme-feedback-triage/SKILL.md` Step 0），把 `ClassificationRecommendation` 放在顶层等于强制合并判定，必然判错。
>
> 🔴 **`PMDecision: Confirmed` 必须同时给 `PMDecisionValue`。** 只写 "Confirmed" 说不出 PM 确认的是缺陷还是变更，下游无法据此决定去向。
>
> 🔴 **`PMDecision: Pending` 时 `NextRoute` 只能是 `AwaitPMDecision`。** 否则下游会拿着一个未经确认的建议直接开工——PM 判定权就形同虚设了。

三条硬规则：

1. **本 skill 只给建议，判定人是 PM。** `ClassificationRecommendation` 是推荐值，`PMDecision` 未 `Confirmed` 前不得当作定论往下走。DTC §六 原文：「判定人是 PM」「未标类型的按变更处理」。
2. **判为缺陷 ≠ 直接回实现 skill 打补丁。** 必须开**新工作项**，从 Assess 重新进入，生成新的 `ChangeSetId`——旧 ChangeSet 的 QA 结论在代码再次变化时已自动失效（§1.4）。复用旧 ChangeSet 是契约违规。
3. **Linear 状态不自动改。** `LinearStatusAdvice` 只是建议；实际点状态是外部动作，需用户显式授权。顺序严格按 DTC §七：收到反馈或 QA 打回 → 先 `Feedback Revision` → 再回 `In Dev`；需求变更点 `Requirement Change`；紧急打断点 `Requirement Interruption`；提测 `Ready for QA`；被阻塞**不改状态**，在评论区写阻塞项与阻塞方。

**判定口径**（DTC §六）：能在 PRD、Figma 或 UX Spec 里找到依据 = `DeliveryDefect`（计返工）；找不到依据 = `RequirementEvolution`（算变更，不计返工）。依据不明时填 `Undetermined` 并列出需要 PM 补的信息，**不要**为了给个结论而硬套。

### 9.1.4 发版工件（`plaud-theme-release-ops` 专用）

```yaml
ArtifactKind: ReleaseOps
ReleaseId:                # REL-<YYYYMMDD>-<NN>
ReleaseScope:             # 见下：逐个 ChangeSet 的 QA 结论 + 验收状态，不用单个标量表达
TargetSites:              # 二次确认后的推送站点清单，逐个显式列出
ExcludedSites:            # 本次不推的站点 + 每个的原因
ThemeIds:                 # 各目标站点对应的主题 ID
SiteListConfirmedBy:      # 两次确认的出处（需求时 + 发版前），谁/在哪/什么时候
PRRef:                    # agency 提供的 PR 链接
AuthorizationRef:         # 用户显式授权执行推送的出处；未授权填 NotAuthorized
PushResult:               # NotExecuted | Executed | PartiallyExecuted —— 实际推送结果
PerSitePushResult:        # 逐站点：站点 / Succeeded|Failed|NotAttempted / 时间 / 失败原因
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

`ReleaseScope` **逐个 ChangeSet 填**，因为验收是**按 section / page 分别发生**的，一个标量表达不了"部分验收"：

```yaml
ReleaseScope:
  - ChangeSetId:
    QAConclusion:       # QA 的 ReadyForDelivery 取值 + 出处；任一不是 Yes 则该块不得发版
    AcceptanceStatus:   # Accepted | Pending —— 该块对应 section/page 的运营验收状态
    AcceptanceRef:      # 验收出处；Pending 时填 N/A
    IncludedInThisPush: # Yes | No —— Pending 的块填 No，留到下次
```

> 🔴 **v0.2.2 只支持单块发布**（§2）：`IncludedInThisPush: Yes` 的块**至多一个**。多于一个 → `plaud-theme-release-ops` 停机，要求逐块串行发布。`ReleaseScope` 仍是列表结构，是为了让"这次发哪块、哪些块留到下次"能一起记清楚。

> 🔴 **`AcceptanceStatus` 必须逐块给。** 顶层一个 `Accepted` 表达不了"A 验收了、B 还没"，而 DTC 要求的正是**只发已验收的部分**。用单标量时，要么把没验收的一起发了，要么把验收了的一起压住——两种都错。

**这个工件同样没有 `ReadyForDelivery` 字段。** 它消费 QA 的结论，不生产结论。

四条硬规则（DTC §五）：

1. **`AcceptanceStatus: Pending` 时不得发版对应 section / page。** QA 通过只是技术门，运营验收是另一道（§1.1）。
2. **推送站点清单要确认两次**：运营提需求时填一次，发版前二次确认。`SiteListConfirmedBy` 两次都要有出处。推错站点是 DTC 原文点名"过去扣分最多的一项"。
3. **上线后功能类 bug（非样式）当天解决**；样式类进最近一次迭代修复。
4. **每个线上 bug 必须反推一条回归用例入库**——同一个问题不允许出现第二次。修完不补用例，`RegressionCasesAdded` 判空即视为未完成。

发版本身（`git push` / Shopify theme push / 合并 PR）是**外部动作**，本 skill 只产出清单与判定，执行需用户显式授权。

### 9.2 字段取值枚举

以下字段的取值是**封闭枚举**，不得自造：

**阶段契约字段**（§3 / §4 / §5 / §9.1 的 yaml 块内）：

| 字段 | 允许值 |
|---|---|
| `QAStatus` | `NotRun` \| `Skipped(UserWaived)` |
| `ReadyForDelivery` | `Yes`（仅 QA）\| `No` \| `N/A(ReadOnly)` |
| `ReadyForImplement` | `Yes` \| `No` |
| `Path` | `A` \| `B` \| `C`（**v0.2.2 第七轮补**：QA 的结构核要按封闭枚举核 20 字段取值，此前这几项没有事实源，`Path: D` 之类既可能被放行、也可能被无依据地停机） |
| `ThemeCheckRequired` / `VisualRegressionRequired` / `BuildRequired` | `Yes` \| `No` |
| `NextRequiredSkill` | `plaud-theme-qa-intake`（实现 skill 的正常下游）\| `plaud-theme-qa`（仅 qa-intake 工件填）\| `None`（零改动只读任务） |
| `ChangeSetIdMatched` | `Yes` \| `No` |
| `ReconMode` | `LegacyImpact` \| `IntegrationSurface` \| `InlineLite` \| `N/A(ReadOnly)` |
| `RiskTier` | `Low` \| `Medium` \| `High` |
| `RequiredQAProfile` | `QA-A` \| `QA-B` \| `QA-C`（可多选）。**不含 `QA-Global`**——它由 QA 恒执行并记入 `QAProfilesRun`，任何上游工件写它都是违规 |
| `ThemeCheck` / `RegressionMatrix` / `LocalizationCheck` / `A11yCheck` / `ThemeRuntimePreview` / `AdminSchemaSave` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `ArtifactKind` | `Coordination`（orchestrator）\| `QAIntake`（qa-intake）\| `FeedbackTriage`（feedback-triage）\| `ReleaseOps`（release-ops）。**阶段 skill 不填此字段** |
| `AllChangeSetsDelivered` | `Yes` \| `No` |
| `QAAdmissionStatus` | `Accepted` \| `Blocked`（仅 QA 填） |
| `QAAdmissionReason` | `Normal` \| `PackageIncomplete` \| `BindingMismatch` \| `MissingArtifact` \| `UserWaivedMaterials`。~~`ZeroChangeReadOnly`~~ **v0.2.2 第七轮废止** —— 零改动任务不进 QA（见 §5 准入门第 3 条） |
| `ConfigurationGuideStatus` / `ReworkDeltaStatus` | `Complete` \| `Incomplete` \| `NotApplicable` |
| `SelfTestReportStatus` / `ScreenshotManifestStatus` / `ImpactScopeStatus` / `SubmissionPackageStatus` | `Complete` \| `Incomplete` |
| `AcceptanceStatus` | `Accepted` \| `Pending`（**逐 ChangeSet 填**，不是整批一个值） |
| `StyleHardRuleCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `ApprovedExceptionsChecked` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable`。🔴 **界线**：`ApprovalRef` **为空 / 越界 / 自批 → `Failed`**（判过了，不成立）；**提供了但核不动**（403、权限不足、平台故障）→ `Blocked`。「没提供」不等于「验不了」，把前者填 `Blocked` 是谎报 |
| `ApprovedExceptions[].Clause` | 只能取 §8.1 **封闭清单**里的条款号。清单外的取值一律视为契约违规，`ApprovedExceptionsChecked: Failed` |
| `ClassificationRecommendation` / `PMDecisionValue` | `DeliveryDefect` \| `RequirementEvolution` \| `Undetermined`（`PMDecisionValue` 不取 `Undetermined`）\| `N/A`（**仅 `PMDecisionValue`，且仅当 `PMDecision: Pending`**——PM 还没决定就不存在决定值。v0.2.2 第九轮补：模板要求 Pending 时填 `N/A`，而本枚举原来不含它，结构核会判非法，等于逼 agent 去伪造一个尚未发生的 PM 决定） |
| `PMDecision` | `Pending` \| `Confirmed` |
| `NextRoute` | `AwaitPMDecision`（`PMDecision: Pending` 时**只能**取此值）\| `NewWorkItem(Assess)` \| `Backlog(排期)` \| `NoAction` |
| `PreviewManifestStatus` | `Complete` \| `Incomplete` |
| `TestSetTrace` / `PreviousAcceptedTestSetTrace` | 自由文本，格式与判定**唯一事实源是 `package-checklist.md` §3**；此表只约束一点：**缺 `@<revision>`、或分号后为空 → 视为未提供**。`PreviousAcceptedTestSetTrace` 另可取 `None(FirstSubmission)` 或 `Unavailable(<原因>)`。**`Unavailable` 的成立条件是「找不到任何一条 `TestSetTrace` 非 `N/A` 的历史行，且用户也给不出上一轮已通过准入的工件」**——含三种情形：日志无此列（旧日志）/ 有列但历史行全是 `N/A` / 日志文件缺失。判定见 `package-checklist.md` §3 |
| 红线分级标记（§8.1） | `🔴 红线` \| `🟠 EvidenceBased` \| `🟠 ApprovedException` \| `🟡 建议`。🟠 的两种**不可互换**：`ApprovedException` 缺 `ApprovalRef` 直接 `Failed`，`EvidenceBased` 缺证据是 `Blocked` |
| `IncludedInThisPush` | `Yes` \| `No` |
| `TestSetTraceAfterArchive` | 与 `TestSetTrace` **同格式且三段齐**（`Added` / `Updated` / `Removed` 都要出现，只新增时后两段写 `[]`；唯一事实源 `package-checklist.md` §3），另可取 `N/A(NoOnlineBug)`。**稳定文档 ID 与 QAIntake 那份不一致 → 视为未归档**。它不接受 `None(reason)`——归档轮次必然有新增用例 |
| `PushResult` | `NotExecuted` \| `Executed` \| `PartiallyExecuted`（部分站点失败时**必须**用它，填 `NotExecuted` 会抹掉已发生的线上副作用、导致重复推送） |
| `PerSitePushResult[].Status` | `Succeeded` \| `Failed` \| `NotAttempted` |
| `FeedbackSource` | `QA打回` \| `运营验收` \| `线上反馈` \| `内部发现` |

> 🔴 **`Complete/Incomplete` 与 `Yes/No` 不可互换。** 提测包用前者、交付许可用后者，这是刻意的语法隔离（§9.1.2）。在提测工件里写 `Yes`、或在 QA 工件里写 `Complete`，都视为契约违规。

> **`Blocked` 与 `Failed` 不可混用。** `Failed` = 验了、发现缺陷（实现 skill 应去修）；`Blocked` = 该验但没验成（用户豁免、ChangeSet 失配、工具不可用）。把未执行填成 `Failed` 会让下游去追不存在的缺陷；填成 `Passed` 或无证据的 `NotApplicable` 则是谎报。两者都不允许。

阶段契约字段出现枚举外的值（如 `Done`、`Partial`）一律视为违规。需要表达枚举覆盖不到的状态时写进 `BlockingGaps` 正文，不要新造取值。

**`memory/` 记录字段**（不是阶段契约，单独一套枚举）：

| 字段 | 允许值 | 位置 |
|---|---|---|
| `QAStatus` | `Pending` \| `Valid` \| `Invalidated` | `changeset-log.md` |
| `TestSetTrace` | 该轮**已通过准入**（`QAAdmissionStatus: Accepted`）的测试集那一行原文（格式见 `plaud-theme-qa-intake/references/package-checklist.md` §3）\| `N/A(NotAccepted)`（该轮 `QAAdmissionStatus: Blocked`）\| `N/A(NoTestSet)` | `changeset-log.md`，**v0.2.2 新增列**，由 `plaud-theme-qa` 在写 log 时**原样抄自 `QAIntake` 工件**（列格式见 `plaud-theme-qa/references/evidence-and-invalidation.md`）—— 它是 `plaud-theme-qa-intake` 下一轮取 `PreviousAcceptedTestSetTrace` 的唯一权威来源。**旧日志不回填** |
| `VisualAcceptance` | `Pending` \| `Accepted` | 迁移状态文件 |
| 模块 / 模板迁移态 | `待办` \| `进行中` \| `已迁`（需 QA 背书，见 shared SKILL.md） | 模板/模块清单 |

`Invalidated` 在 `changeset-log.md` 里是**合法**取值（表示该 QA 结论已因代码变化失效）；它只是不允许出现在阶段契约块里。两套枚举互不通用。
