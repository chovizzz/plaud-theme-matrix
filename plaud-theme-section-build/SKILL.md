---
name: plaud-theme-section-build
description: >
  PLAUD 主题矩阵 Path B 的 Implement 阶段（order 4）：把 Figma 设计稿按 vendor 规范实现成 sa- 前缀 section。
  触发："按设计稿做模块""按稿搭模块""设计还原/切图还原""Figma 转 Shopify""Figma link/node"
  "新建 sa- 开头的 section""做个 SA: 模块""Section AI""新增主题编辑器模块"；
  在新建 sa- section 语境下也覆盖 vendor §8 文案配置 / §9 按钮 / §10 价格 / §11 轮播 怎么写、
  schema label 要不要 t:、能不能自创按钮类名、运营素材能不能放 assets、设计稿数值在 spec 阶梯上两可取哪档。
  产出 sa- 前缀 section/snippet/CSS + SA: schema + BEM 根类名，container 与 section_top_pc/section_bottom_pc 间距，
  同时加 gradient 与动态 color- 类，复用 section-header，三层响应式变量，素材走 schema 不写死 assets，空/满配置双测。
  开工前须消费 plaud-theme-impact 的 IntegrationSurface 评估；写入任何存量文件（或新增文件被存量机制自动消费）
  即升级 LegacyImpact 回 impact 重评。设计稿值等距两可或无近邻 token 时停机问用户。
  不做验收、不判定可交付（唯 plaud-theme-qa 有权），恒输出 ReadyForDelivery 为 No。
  不用于改已有 section、bug、性能、无 Figma 上下文的新功能（走 plaud-theme-dev）；
  不用于 UX Spec v1.3 迁移与刷模块（走 plaud-theme-ux-migration）；
  B+C 交叉（新建 sa- 且要对齐 v1.3）单一 ChangeSet 装得下就直接用本 skill，只有需拆出第二个
  可独立验收 ChangeSet 时才走 plaud-theme-orchestrator；
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Section Build（Path B · Implement）

**开工前必读**：`plaud-theme-shared/SKILL.md` + `plaud-theme-shared/references/handoff-schema.md`（尤其 §1 交付权、§4 本 skill 的产出契约、§7 停机、§8 全路径红线）。

视觉与 UX 数值（字号 / 字重 / 颜色 / 间距 / 断点 / 弧角 / 容器宽度）**全部在 `plaud-theme-shared/references/`**——本 skill 只引用文件名，**一个数值都不复制**。复制会造出第二个事实源，spec 一升级必然漂移。

## 本 skill 做什么

把设计稿变成一个**符合 PLAUD vendor 规范、运营可配置、多语种安全**的新 section：

- 强制命名（`sa-*` 文件 / `SA:` schema / BEM 根类名）
- 结构骨架（`container`、Section Space schema、`gradient` + `color-{scheme}`、`section-header` 复用、anchor id）
- vendor §8 文案 / §9 按钮 / §10 价格 / §11 轮播 合规
- 媒体资源不写死进 `assets/`
- 三层响应式变量策略
- 空配置与满配置双测 + 英译德长文案自检

## 本 skill 不做什么

- **不改已有 section / snippet 的功能**——那是 `plaud-theme-dev`（Path A）
- **不做独立的 UX Spec v1.3 迁移 / 刷模块 / 对齐 spec**——那是 `plaud-theme-ux-migration`（Path C）

> **B+C 交叉的路由（与 `MATRIX.md` / orchestrator 一致）**：Figma 新建**同时**明确要求对齐 v1.3 spec 时——
> **单一 ChangeSet 能装下的 B+C 直接由本 skill 实现**（实现规则用 Path B 的、spec 取值用 Path C 的，`RequiredQAProfile` 取 `QA-B, QA-C`），**不绕 orchestrator**。
> 只有当这项工作还需要**拆出第二个可独立验收的 ChangeSet**（例如新建 section 之外还要刷一批存量模块 / 跨多模板的迁移 wave）时，才先走 `plaud-theme-orchestrator` 编排，由它调用本 skill 做其中的 B 部分。
> 判据是「**要不要拆成 ≥2 个可独立验收的 ChangeSet**」，不是「有没有跨路径」——后者会让每个 B+C 都无谓地绕一圈。
- **不做验收、不判定可交付**——`ReadyForDelivery` 恒为 `No`，只有 `plaud-theme-qa` 能给 `Yes`
- **不自己做影响面评估**——上游是 `plaud-theme-impact`
- **不擅自决定 Figma 值落哪一档**（见「停机点」）

---

## 上游：消费 Assess 工件

开工前必须拿到 `plaud-theme-impact` 的产出（`handoff-schema.md` §3），把 `AssessmentRef` 抄进自己的输出。

Path B 的常态是 **`ReconMode: IntegrationSurface`**——纯新建，无存量调用方，查的是**复用面与冲突面**：

- 可复用的 snippet：`section-header` / `section-swiper` / `price-format` 等，是否已覆盖需求
- `sa-<feature>` 文件名、BEM 根类名、CSS 变量前缀是否与既有模块冲突
- 素材是否会误入 `assets/`
- schema / locales / 数据源是否完整
- bundle 加载方式（`stylesheet_tag` 放哪、会不会进循环）
- 是否需要接入模板或 section group

`IntegrationSurface` 下 `TheoreticalReferences` 应是 `0 (new module, no existing callers)`——**不要为新建 section 伪造"模板使用量 N"**。

拿不到 Assess 工件 → 停机要它。`InlineLite` 豁免对 Path B 基本不成立（新建 section 至少涉及 schema）。

### 🔴 升级为 LegacyImpact 的触发条件（必须回 impact 重评）

> **只要本次改动以任何方式写入（修改 / 删除 / 重命名 / 移动）了任何一个存量文件，模式立刻从 `IntegrationSurface` 升级为 `LegacyImpact`——哪怕主体工作是新建一个 `sa-*` section。**

**判定门是「有没有写入存量文件」，不是「能不能找到调用方」。** 静态引用数只用于**算影响面**（Assess 的事情），**不是**是否升级的门——「我 grep 不到别人用它」不构成不升级的理由（动态引用、bundle 自动打包、约定式加载都 grep 不到）。

具体触发清单，命中**任意一条**即升级：

| 触发 | 例子 |
|---|---|
| 写入任何既有 snippet | `section-header.liquid`、`section-swiper.liquid`、`price-format.liquid`、`product-item.liquid`、`critical-style.liquid`，以及任何已在仓库里的 snippet |
| 写入全局 CSS | `critical.css`、`theme.css`、`base_more*.css`、design-system 类样式表 |
| 写入 design token / 全局 CSS 变量 | 新增或修改 `--color-*` / `--space-*` / `--text-*` / `--btn-*` |
| 动了配色方案 | 新增 color scheme 或改全局颜色变量（本来就禁止，须先经确认） |
| 写入 build 产物或其源 | `shopify-common/src/**`、`snippets/design-system.liquid`、`assets/*.min.css` |
| 写入既有 section / 既有 schema 字段 | 为了接入新模块顺手改了别的 section |
| 写入 `templates/*.json` / `sections/*.json`（section group） | 把新 section 接进模板或 section group；模板存值默认只读，另需用户授权 |
| 写入 `layout/` / `config/` | `theme.liquid`、`settings_schema.json`、`settings_data.json` |
| 写入 `locales/*.json` 的既有 key | 改 / 删 / 移动 / 覆盖既有 key 一律升级。**唯一不升级的情形**：只新增本模块独立 namespace 下的全新 key，且与既有 key 无同名碰撞（须用 grep 证明） |
| 新增文件但被存量机制自动消费 | 新 CSS/JS 被全局 bundle、manifest、约定式 loader 自动打包或自动加载——文件状态是 `A`，传播面却已存在，同样升级 |

**判定命令**。**开工前先取 baseline，收尾时只判定"本 ChangeSet 新产生的"变化**——工作树里开工前就存在的、属于**别的块**的改动，既不吸收进 `ModifiedFiles`，也不单独导致本任务升级。

📎 **v0.3.0 起这一整段换了机制。** v0.2.3 那套 `sb_worktree_set()` + `mktemp` + `comm` 的 86 行 shell 已**整体废弃**：ChangeSet 身份从「工作树状态文本的 SHA-256」改绑「不可变 git tree 对象的 oid」之后，「本轮改了什么」由 `plaud_declared_diff` 拿两棵 tree 的 raw diff 直接给出，不再需要采两次名字集合再做差集。**逐条去向见本节末尾的对照表**——那里同时说明每一条守卫是被谁接手了、还是因为洞被构造性堵上而不再需要。

```bash
# 前提（缺一不可，缺了就是 Blocked 不是 Passed）：
#   · 先把 `plaud-theme-shared/references/handoff-schema.md` §2.5 的函数**原样复制**进来
#     （含全部 `_plaud_*` 内部函数与注释），在**仓库根**执行；
#   · shell 是 bash(≥3.2) 或 zsh —— 这几段用了 `set -o pipefail`，`dash` 不支持；
#   · git ≥ 2.25、可写 TMPDIR、macOS / Linux（Windows 不支持取证）。

# ---- ① 开工前（写下第一个字节之前）------------------------------------------
# BaseHeadSha 必须在**这一刻**取，不是交付时取；理由见「输出契约」那一节。
BASE_HEAD_SHA=$(git rev-parse HEAD) || { echo "BASE_HEAD_FAILED"; exit 1; }
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }   # baseline 留痕 + 环境自检

# ---- ② 开工前的归属门：本任务**将要**声明的路径，现在是不是已经脏了 -----------
# PATHLIST = 计划声明的逐字路径清单，每行一条（= 将来的 §4 ModifiedFiles）
sb_baseline_overlap "$BASE_HEAD_SHA" "$PATHLIST" || exit 1

# ---- ③ 收尾（交付工件那一刻）--------------------------------------------------
plaud_theme_tree                  || { echo "THEME_TREE_FAILED"; exit 1; }  # ObjectFormat + ThemeTreeOid
plaud_changeset_scope "$PATHLIST" || { echo "SCOPE_FAILED";      exit 1; }  # ChangeSetScopeFingerprint

# ---- ④ 归属自检：真正变化的可发布路径集合 == 本块声明的集合？------------------
# 🔴 只有**独占工作树**时这条自检才成立。同树并行 Implement 时别的块的改动会被判成
#    DECLARED_DIFF_ORPHAN，那不是你的错误，也不允许把别人的路径吸收进 ModifiedFiles ——
#    此时跳过本条，归属核对由 QA 拿各块声明的**并集**完成（shared §2.7）。
plaud_declared_diff "$BASE_HEAD_SHA" "$PATHLIST" || exit 1

# ---- ⑤ 存量写入判定（本节的主判据）------------------------------------------
# 声明路径里，哪些在 baseline commit 里**就已经存在**。② 已经证明这些路径在开工前与
# baseline 逐条相同，所以「baseline 里已存在」+「本轮被 ④ 判为变了」= 本 ChangeSet
# 写入了存量文件。输出非空即升级 LegacyImpact。
set --
while IFS= read -r p; do [ -n "$p" ] && set -- "$@" ":(literal)$p"; done < "$PATHLIST"
git -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    ls-tree -r --full-tree -z "$BASE_HEAD_SHA^{tree}" -- "$@" \
  | tr '\0' '\n' | sed '/^$/d' | cut -f2-
```

`sb_baseline_overlap` 的定义（本 skill 自己的函数，**不在** canonical 里；它依赖 §2.5 的 `_plaud_*` 内部函数，必须先把 §2.5 整段复制进来）：

```bash
# ---- Path B 开工前：本任务声明路径的 baseline 脏重叠门 -----------------------
# sb_baseline_overlap <BaseHeadSha> <pathlist-file>
#   pathlist-file：本任务**将要**声明的逐字路径清单，每行一条（= 将来的 §4 ModifiedFiles）。
# 成功输出一行： BASELINE_CLEAN <BaseHeadSha> <声明路径条数>
#
# 🔴 它答的是「改动归属」，不是「树里有什么」。DeclaredDiffCheck 能证明某条路径变了，
#    答不出「是谁改的」；开工前这些路径就已经脏，本轮改完之后没有任何机械手段能把两拨
#    改动拆开 —— 所以必须在**写下第一个字节之前**停机隔离。
# 🔴 只判**本任务声明的路径**，不判整棵树：v0.3.0 同树并行 Implement 是主推路径，
#    别的块的改动躺在同一棵工作树里是**合法**的，整树判会把正常并行判成停机。
# 🔴 判法与 §2.5 同构：把声明路径按**空白临时索引**写成 tree，与 baseline commit 的
#    同名条目逐条比 `<mode> <type> <oid> <path>`。**不用 `git diff <base> -- <paths>`**
#    —— 那条命令读用户的 index。📎 v0.3.0 起解除：`git update-index --assume-unchanged` /
#    `--skip-worktree` 这两个索引标志的补充门已退役，因为空白索引从磁盘重扫、标志不生效；
#    但**那只在走 canonical 函数时成立**，`git diff <base> -- <paths>` 走的是用户 index，
#    实测会对已改脏的文件回报「无差异」、函数照样 rc=0 说 BASELINE_CLEAN。所以这里必须
#    用空白索引重建 tree —— 洞是被**构造性**堵上的，不需要另加一道门。
sb_baseline_overlap() (
  set -o pipefail
  _base="${1-}"; _list="${2-}"
  [ -n "$_base" ]                    || { printf 'BASELINE_BASE_MISSING\n' >&2; return 1; }
  [ -n "$_list" ] && [ -f "$_list" ] || { printf 'BASELINE_LIST_MISSING\n' >&2; return 1; }
  _plaud_at_root                                                                     || return 1
  _plaud_git_capable                                                                 || return 1
  git rev-parse -q --verify "$_base^{commit}" >/dev/null 2>&1 || {
    printf 'BASELINE_BASE_UNREACHABLE: %s 不可达（浅克隆 / 已被 gc / 写错 / 还没有 commit）\n' "$_base" >&2
    return 1; }
  # 与 §2.5 同口径：清单含 NUL 或双引号一律 fail closed
  _nul=$(tr -cd '\0' < "$_list" | wc -c | tr -d ' ')                                  || return 1
  [ -n "$_nul" ] || return 1
  [ "$_nul" = "0" ] || { printf 'BASELINE_LIST_HAS_NUL\n' >&2; return 1; }
  _q=$(tr -cd '"' < "$_list" | wc -c | tr -d ' ')                                     || return 1
  [ -n "$_q" ] || return 1
  [ "$_q" = "0" ] || { printf 'BASELINE_LIST_HAS_QUOTE: 声明路径含双引号，先重命名\n' >&2; return 1; }

  _plaud_iso_setup                                                                   || return 1
  _T="$_PLAUD_OBJDIR"
  # 🔴 不 trim：真实存在的 `assets/a.css ` 被剥成 `assets/a.css` 会让本门判错文件
  sed '/^$/d' "$_list" | LC_ALL=C sort -u > "$_T/declared"                            || { rm -rf "$_T"; return 1; }
  _n=$(_plaud_count . "$_T/declared")                                                 || { rm -rf "$_T"; return 1; }
  [ "$_n" -gt 0 ] || { printf 'BASELINE_LIST_EMPTY\n' >&2; rm -rf "$_T"; return 1; }
  # 🔴 `for _p in $(cat …)` 在 zsh 下不做词分割、在 bash 下又会按 IFS 切碎含空格的路径。
  #    一律 `set --` 逐行累积；:(literal) 防止 `assets/g[1].css` 被当 glob 吸收别的文件。
  set --
  while IFS= read -r _p; do [ -n "$_p" ] && set -- "$@" ":(literal)$_p"; done < "$_T/declared"
  [ "$#" -gt 0 ]                                                                     || { rm -rf "$_T"; return 1; }
  # 字节保真门：core.autocrlf / core.fileMode / filter 等机制会让「工作树字节 ≠ tree 字节」，
  # 那时下面的 mode / oid 比对都不可信 —— 与 §2.5 同一道门，同样 fail closed。
  _plaud_bytes_gate "$@"                                                             || { rm -rf "$_T"; return 1; }

  # ---- now：声明路径在**当前工作树**里的样子（空白临时索引，含未跟踪与被 gitignore 的）
  : > "$_T/exists"; _dirbad=""
  while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    # 与 §2.5 同口径：声明清单里出现目录一律 fail closed（ModifiedFiles 必须逐个文件）
    if [ -d "$_p" ] && [ ! -L "$_p" ]; then _dirbad="$_dirbad$_p
"; continue; fi
    if [ -e "$_p" ] || [ -L "$_p" ]; then printf '%s\n' "$_p" >> "$_T/exists" || { rm -rf "$_T"; return 1; }; fi
  done < "$_T/declared"
  [ -z "$_dirbad" ] || {
    printf 'DECLARED_DIRECTORY: 声明清单里出现目录，ModifiedFiles 必须逐个文件：\n%s' "$_dirbad" >&2
    rm -rf "$_T"; return 1; }
  LC_ALL=C sort -u "$_T/exists" -o "$_T/exists"                                       || { rm -rf "$_T"; return 1; }
  _ne=$(_plaud_count . "$_T/exists")                                                  || { rm -rf "$_T"; return 1; }
  if [ "$_ne" -gt 0 ]; then
    sed 's/^/:(literal)/' "$_T/exists" > "$_T/pathspec"                               || { rm -rf "$_T"; return 1; }
    # add 失败不许吞：吞掉 "did not match any files" 会让索引为空、算出**空树**却返回 0
    if ! GIT_INDEX_FILE="$_T/nidx" _plaud_git_iso add -A -f --pathspec-from-file="$_T/pathspec" \
         2>"$_T/adderr"; then
      printf 'BASELINE_ADD_FAILED:\n' >&2; cat "$_T/adderr" >&2; rm -rf "$_T"; return 1
    fi
    _noid=$(GIT_INDEX_FILE="$_T/nidx" _plaud_git_iso write-tree)                      || { rm -rf "$_T"; return 1; }
    [ -n "$_noid" ]                                                                   || { rm -rf "$_T"; return 1; }
    _plaud_git_iso ls-tree -r --full-tree -z "$_noid" > "$_T/nls"                     || { rm -rf "$_T"; return 1; }
    # 🔴 收全性核对：磁盘上存在的声明路径**必须**逐条出现在树里。**嵌套 git 仓库里的
    #    文件对父仓库的 `git add` 是隐形的** —— 它既不进树、`ls-files --cached --others`
    #    也枚举不到，于是 base 与 now 双双为空、比对相等，函数会对一个真实存在的脏文件
    #    回报 BASELINE_CLEAN（Codex 评审实测复现）。多或少都 fail closed。
    _plaud_mode_gate "$_T/nls" "BASELINE_NOW"                                         || { rm -rf "$_T"; return 1; }
    tr '\0' '\n' < "$_T/nls" | sed '/^$/d' | cut -f2- | LC_ALL=C sort -u > "$_T/present" \
      || { rm -rf "$_T"; return 1; }
    if ! LC_ALL=C diff "$_T/exists" "$_T/present" > "$_T/setdiff" 2>&1; then
      printf 'BASELINE_SET_MISMATCH: 声明存在的路径与 tree 条目不一致（典型成因：路径落在嵌套 git 仓库里，对父仓库不可见）：\n' >&2
      head -40 "$_T/setdiff" >&2; rm -rf "$_T"; return 1
    fi
  else
    : > "$_T/nls"
  fi
  # ---- base：同一批路径在 baseline commit 里的样子
  _plaud_git_iso ls-tree -r --full-tree -z "$_base^{tree}" -- "$@" > "$_T/bls"        || {
    printf 'BASELINE_LS_TREE_FAILED\n' >&2; rm -rf "$_T"; return 1; }
  # symlink / 嵌套 git 仓库出现在声明范围里 → 与 §2.5 同一道门，fail closed
  _plaud_mode_gate "$_T/bls" "BASELINE_BASE"                                          || { rm -rf "$_T"; return 1; }

  # 逐条比 `<mode> <type> <oid>TAB<path>`：内容变（oid）、只改 mode（mode）、新增 /
  # 删除 / 纯大小写改名（条目有无）全都落在这一个比对里。
  # 🔴 mode_gate 已保证两份 -z 流里没有换行，所以 tr '\0' '\n' 不会拆行。
  tr '\0' '\n' < "$_T/nls" | sed '/^$/d' | LC_ALL=C sort > "$_T/nlines"                || { rm -rf "$_T"; return 1; }
  tr '\0' '\n' < "$_T/bls" | sed '/^$/d' | LC_ALL=C sort > "$_T/blines"                || { rm -rf "$_T"; return 1; }
  LC_ALL=C diff "$_T/blines" "$_T/nlines" > "$_T/delta" 2>&1; _drc=$?
  # 🔴 `if diff …; then` 之后取 `$?` 拿到的是 if 语句的状态（没走分支时是 0），不是 diff 的
  #    —— 必须当场落到变量里。diff 的退出码：0 = 相同，1 = 有差异，>1 = 它自己出错。
  if [ "$_drc" -gt 1 ]; then
    printf 'BASELINE_DIFF_FAILED(rc=%s)\n' "$_drc" >&2; rm -rf "$_T"; return 1
  fi
  if [ "$_drc" -eq 0 ]; then
    rm -rf "$_T" || { printf 'BASELINE_CLEANUP_FAILED\n' >&2; return 1; }
    printf 'BASELINE_CLEAN %s %s\n' "$_base" "$_n"
    return 0
  fi
  printf 'BASELINE_DIRTY_OVERLAP: 本任务将要声明的路径在开工前就相对 %s 有差异（内容 / 权限位 / 已存在的未跟踪文件 / 已删除）——改动归属无法判定，先隔离（stash / 独立 worktree / 先提交无关改动）再开工。前 40 行：\n' "$_base" >&2
  head -40 "$_T/delta" | sed 's/^/  /' >&2
  rm -rf "$_T"
  return 1
)
```

> 🛑 **拿到 `BASELINE_DIRTY_OVERLAP` → 停机隔离，不要在混合工作树上继续。** 这条规则从 v0.2.3 原样保留，只换了实现：`plaud_declared_diff` 只能把无主改动**抓出来**，抓出来之后「是谁改的」仍然要人判。开工前隔离（stash / 独立 worktree / 先提交无关改动）是唯一能在事后仍然分得清的做法。
>
> 🔴 **中途要扩大声明范围时必须回到 ②。** `sb_baseline_overlap` 只守住它跑那一刻清单里的路径；实施中发现「还得改一个存量文件」时，**必须在写入那个文件之前**把它加进 `PATHLIST` 并**重跑 ②**。已经写过再补进 `ModifiedFiles` → tree diff 只能证明它变了、证明不了是谁改的，此时**停机隔离、取新的 `BaseHeadSha`、从 ① 重来**，不要事后补声明。
>
> 🔴 **残余风险，如实记：这不是对非合作并发的机械保证。** 从 `sb_baseline_overlap` 返回 `BASELINE_CLEAN` 到你写下第一个字节之间，别人仍然可以改这批路径（TOCTOU，Codex 评审实测可复现）。矩阵不创造原子性。要求是人层的：**这段窗口内其它写者不得动本块的声明路径**；做不到就用独立 worktree 或串行。事后怀疑重叠 → 隔离、取新的 `BaseHeadSha`、从 ① 重来。

**v0.2.3 那 86 行的逐条去向**（删注释前先确认知识有落点）：

| v0.2.3 的哪一段 | v0.3.0 的去向 |
|---|---|
| 📎 `sb_worktree_set()` 本体（`git diff --name-status HEAD` + `ls-files --others`） | **废弃**。名字集合答不了「内容变没变」；身份与改动集合都改由 tree 对象承担 |
| `mktemp` + `comm` + 两次落盘的守卫链，`BASELINE_FAILED` / `AFTER_FAILED` | **废弃**。没有中间文件就没有这两个失败态；它们当初修的是「管道退出码是最后一个命令的」，那条教训在新代码里以 `_drc=$?` 当场落变量的形式**仍然在用** |
| `?\t` 前缀的未跟踪土办法 | **废弃**。空白临时索引下 `git add -A -f` 自己枚举未跟踪与被 gitignore 的文件，不再有手写循环，也不再需要行数核对 |
| 本函数自己的 `NOT_REPO_ROOT` 守卫 | 由 §2.5 的 `_plaud_at_root` 承担（`sb_baseline_overlap` 直接调它） |
| 本函数自己的 `NEWLINE_IN_PATH` 守卫 | 由 §2.5 的 `NEWLINE_IN_PATH` / `NEWLINE_IN_PATH_*` 承担 —— 它们是**保留门**，不是被删掉的门：可发布面由 `plaud_theme_tree` 的字节保真门挡，tree 条目由 `_plaud_mode_gate` 挡。🔴 **逐行路径清单在结构上表达不了含换行的路径**（一条会被拆成两行、指向两条不存在的路径），所以**含换行的路径一律先重命名**，不要试图声明它 |
| ②b / ②c 的 34 行 dirty-hash 差集（`$BASE.dirty` / `.dirtyhash` / `.dirtyhash.after`） | **具体 bug 消失，规则保留、换形态**。它当初修的是「`comm` 把 baseline 的 `M` 与收尾的 `M` 抵消 → delta 为空」；新模型比的是 blob oid 与 mode，不是 name-status 的字母，baseline 脏文件本轮再改照样出现在差异里，所以那 34 行不再需要。但**「baseline 已脏且与本任务路径重叠 → 停机」这条规则本身照旧**，由 ② 的 `sb_baseline_overlap` 在**开工前**执行——而且比 v0.2.3 更早、更严：它不再是收尾时才发现「delta 可疑」，而是开工前就拒绝在混合工作树上开工 |
| ③ 存量写入判定（`--diff-filter=MDRCTU`） | 换成对 **baseline commit 的 tree 查询**（见上 ⑤）。理由：② 已保证声明路径在开工前与 baseline 逐条相同，「baseline 里已存在」就等价于「本轮写入了存量文件」，不必再去读工作树 |
| ④ delta（`comm -13`） | 由 `plaud_declared_diff` 承担（独占工作树时可自检；同树并行时由 QA 用并集核） |
| v0.2.3 三条 awk 修复里的知识 | **(a) 未跟踪行**：`git add -A -f` 原生覆盖，Path B 的主场景不再需要特判。**(b) `R<score>\told\tnew` 取错列**：不再解析 name-status，`--no-renames` 与逐路径 tree 条目让改名表现为「一条消失 + 一条出现」。**(c) 只改 mode**：tree 的 mode 位（`100644` / `100755`）参与 ② 的逐条比对与 `ChangeSetScopeFingerprint`，所以能看见；但 🔴 git 只记 executable **一个 bit**，其余权限位不进树——「ChangeSet 身份覆盖权限」是过度声明（v0.2.3 已更正，勿回退）；且 `core.fileMode` 归一为 false 时这个 bit 对 git 隐形，由 `CORE_FILEMODE_FALSE` 门 fail closed |
| 「不要用 `git status --porcelain` 的双状态列做判据」 | **保留**（见下方要点） |

- ⑤ 的输出为空，且新增文件不被任何存量机制自动消费 → 保持 `IntegrationSurface`
- ⑤ 列出任何路径（即本 ChangeSet 写入了 baseline 里已存在的文件）→ **停止实现，回 `plaud-theme-impact` 以 `LegacyImpact` 重评**被写入的存量文件；新建部分的复用面/冲突面检查照做，**两套都要报**
- **不要用 `git status --porcelain` 的双状态列做判据**：`AM` 表示"新增后又有未暂存修改"，相对 baseline 仍是全新文件，按 porcelain 首列过滤会把它误判成存量改动。判存量与否一律以 ⑤（对 baseline commit 的 tree 查询）为准。
- 拿不准（不确定有没有调用方、不确定是否被自动打包、不确定 locale key 有无碰撞）→ 按 `LegacyImpact` 处理（**保守方向永远是升级，不是降级**）

升级的连带后果，一并执行：

1. `ReconMode` 改为 `LegacyImpact`，`AssessmentRef` 换成重评后的新工件编号
2. `RequiredQAProfile` 变为 **`QA-A, QA-B`**（`QA-A` 覆盖依赖树回归与旧 section 连带影响）。🔴 **不写 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进本字段是字段越界（§9.2）
3. 若被改的是 `shopify-common/src/**` → `BuildRequired: Yes`
4. 在 handoff 正文单列"存量文件改动"一段，逐个文件写清改了什么、为什么新建 section 需要它

> **反模式**：为了"不触发升级"而把本该改共享 snippet 的逻辑复制一份到 `sa-*` 里。复制 snippet 是更坏的结果（分叉 + 双事实源）。正确做法是升级重评，不是绕开。

---

## 强制命名

| 层级 | 规则 | 示例 |
|---|---|---|
| Section 文件 | `sections/sa-<feature>.liquid` | `sections/sa-shop-banner.liquid` |
| Snippet 文件 | `snippets/sa-<feature>-<part>.liquid` | `snippets/sa-shop-banner-card.liquid` |
| CSS 文件 | `assets/sa-<feature>.css` | `assets/sa-shop-banner.css` |
| Schema name / preset | `"name": "SA: <Feature>"` | `"name": "SA: Shop Banner"` |
| BEM 根类名 | `sa-<feature>` | `<div class="sa-shop-banner">` |
| CSS 变量前缀 | `--sa-<feature>-*` | `--sa-shop-banner-gap` |

`<feature>` 小写 kebab-case，**五处同一个串**。子元素 `sa-<feature>__<el>`，修饰符 `sa-<feature>--<mod>`。

---

## 结构骨架（要点，细节见 reference）

```liquid
{{ 'sa-<feature>.css' | asset_url | stylesheet_tag }}

<div id="{{ section.settings.anchor_id_for_category | handle }}"
     class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
  <div class="sa-<feature> gradient color-{{ section.settings.color_scheme }}">
    {%- render 'section-header',
        pre_heading: section.settings.pre_heading,
        heading:     section.settings.heading,
        sub_heading: section.settings.sub_heading -%}
    …
  </div>
</div>
```

- **内容区用 `container`**（少数全宽模块例外，须说明理由）；不重写 `.container` 的宽度/内边距
- **上下间距走 `section_top_pc` / `section_bottom_pc` schema**，CSS 里不为 section 硬编码 `margin-top` / `margin-bottom`；option 的 `value` 不得改
- **需切换背景/文字色时，`gradient` 和 `color-{{ ….color_scheme }}` 两个类必须同时出现**，缺一不可
- **标题复用 `section-header`**，`pre_heading` / `heading` / `sub_heading` 一律 `textarea`
- **`anchor_id_for_category` 挂在 `.container` 同层**
- `stylesheet_tag` 在 section 顶层输出一次，**绝不进 block 循环**
- section 内 `<style>` 只输出 CSS 自定义属性，不写规则集

完整骨架、schema 片段、CSS/JS 挂载与 schema 完整性要求 → `references/naming-and-structure.md`

---

## 媒体资源红线（高发漏项）

> **新增 section 不得把内容图片 / 视频 / icon 写死为 `{{ 'xxx' | asset_url }}`，也不得新增 `assets/*.png|jpg|svg|mp4` 作为内容素材。**

运营可配置素材一律走 schema（`image_picker` / `video` / `url`）或产品 / metaobject 数据源。`assets/` **只放 CSS / JS 与确认全站固定的技术资源**；例外须**需求明确并经用户确认**，并在 handoff 正文写明理由——不得自行决定。

```bash
git status --porcelain assets/ | grep -iE '\.(png|jpe?g|webp|svg|mp4|webm|gif)$'   # 应为空
grep -nE "asset_url" sections/sa-<feature>.liquid                                   # 只应命中自己的 css/js
```

`image_url` 必须带 `width:`，按容器实际显示宽度 × 高 DPI 取值，**不得用过小 width 把展示图下采样糊掉**（图片清晰度红线，见 shared `media-quality.md`）。

---

## vendor 合规速查（§8–§11 是外包交付最高发的问题）

完整条文、代码示例与自检命令 → `references/vendor-compliance.md`

**§8 文案**
- 禁止在 Liquid / JS 硬编码任何展示文案；走 schema 字段或 locales `| t`
- 禁止 `| default: '...'` 兜底展示文案（运营清空后会留下无法翻译的英文）
- `blank` 时不输出 DOM，禁止 `<h2></h2>` / `<a href="#"></a>` / 空 `<img>` 空壳
- schema 的 `label` / `info` / `content` / option `label` **直接写英文，不用 `t:` 前缀**
- 配置文案必须完整显示：禁 `overflow:hidden`+固定高、`text-overflow:ellipsis`、`-webkit-line-clamp`、`white-space:nowrap`（价格单元除外）；折叠组件是例外且**必须有展开方式**；卡片网格用 `align-items:stretch` + `min-height`，不固定 `height`
- 不得在代码里判断语言后切换字面量

**§9 按钮**
- 只用 `btn-primary` / `btn-outline` / `btn-white` 三个基础类，**禁止自创按钮类名**
- 尺寸叠**纯尺寸类** `btn-primary-{lg|md|sm}`：**LG 只用 Banner，其它一律 MD，仅特殊说明才 SM**
- **禁止固定 `width` / `height`**，只允许 `min-width` / `min-height`，尺寸由 padding 撑开；同组对齐用 flex
- 特殊定制**只覆盖颜色 CSS 变量**；直接写色值须设计明确要求并经确认；尺寸不在此自定义

**§10 价格**
- Liquid 走 `{%- render 'price-format', price: … -%}`
- 外层 `price-wrap` + `white-space: nowrap`；原价/划线价/折扣价并排时**每个单元各自加**，不整体包一层
- 禁硬编码货币符号（`$` `€` `¥`）与价格数字，禁在 settings 里填价格
- 数据源优先 product / variant；JS 动态渲染用 `Shopify.formatMoney`，不自写格式化函数

**§11 Swiper**
- 统一 `{%- render 'section-swiper', class: '…', style: '' -%}`
- **禁止在 section 内重写** `.swiper-button-prev` / `.swiper-button-next` / `.swiper-pagination` 的视觉样式
- 位置调整走 `class` 参数（`justify-*` / `mt-*`），**不复制 snippet 再改**
- effect 约束见 shared `javascript-swiper.md`；轮播按钮须语义 `button` + `aria-label`

---

## 响应式三层变量策略

**端变量 `--sa-xxx-m` / `--sa-xxx-pc` → 运行变量 `--sa-xxx` → 属性只读运行变量。**

- 断点内**只改变量映射**，media query 里不出现字面 px
- 属性声明只读运行变量，读端变量就是越层
- mobile-first：默认样式即移动端，grid 从 1 列起
- 端变量取值绑 spec token（`var(--space-*)` / `var(--text-*)`），不是裸 px
- 组件宽高同理：流式宽度 / `min-*` / `max-*` / `aspect-ratio` / 变量映射；例外仅限 `plaud-theme-shared/references/handoff-schema.md` §8.2 列明的几类（细线、图标、明确固定的技术容器、Swiper 特定 effect 要求的固定 height），且须说明原因

完整写法示例 → `references/figma-workflow.md`（末节）；断点与间距档值 → shared `responsive-and-spacing.md`

---

## Figma 工作流（六步）

| 步 | 做什么 |
|---|---|
| 1 | **读稿** → 拆 grid / blocks / settings，同时产出「素材清单」（每张图的来源） |
| 2 | **映射数据** → settings / blocks；按钮永远 label + link 两字段；必带 anchor id、Section Space、presets |
| 3 | **写 Liquid** → `stylesheet_tag`（不进循环）、`section-header`、`image_url` + `width`、逐字段 `!= blank` |
| 4 | **写 Schema** → `+ Heading` / 业务字段 / `color_scheme` / anchor id / `+ Section Space` / presets `SA:` |
| 5 | **写 CSS** → mobile-first、三层端变量、不重写 container/按钮/swiper 视觉 |
| 6 | **自检** → **空配置与满配置双测**、英译德长文案、多语种、逐断点、vendor Checklist |

第 6 步的**双测不是可选项**：只测满配置是最常见漏项，运营上线时字段往往是半空的。

详细步骤 → `references/figma-workflow.md`

---

## 停机点（Stop, don't guess）

任一成立 → 写 `BlockingGaps`，说清**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"。

### Figma 值不在 spec 阶梯上

```
Figma 值 v，spec 阶梯 …a < v < b…
  ├─ v 明显更接近某一档              → 就近 snap，并在正文注明「Figma v → spec X（snap）」
  ├─ v 与两档等距/接近等距
  │   （示例见 shared handoff-schema §7）  → 🛑 停机问用户选哪一档，不得擅自定
  └─ 无近邻 token 且视觉重要          → 🛑 先与用户确认，确认后方可用字面 px，并标注为已确认例外
```

**"等距两可"必须停。** 自行择一不会报错、QA 也未必看得出，但会让整站阶梯逐渐失真——这是 Path B 最隐蔽的偏差来源。就近 snap 也要留痕，让 QA 能复算。

### 其它停机点

- 拿不到 `plaud-theme-impact` 的 Assess 工件
- 设计稿信息不足（缺某断点稿、缺状态稿、缺空态定义）
- 素材来源无法确定，或确需放进 `assets/` → 要用户确认
- 需要新增 color scheme 或改全局颜色变量 → 要设计/用户确认
- 按钮需要非标尺寸、需要新按钮类名 → 要确认（默认答案是不行）
- 文案需要截断（`line-clamp` 等）→ 要 PM 评审确认 + schema 行数开关
- 需要把新 section 接进 `templates/*.json` → 要授权（模板存值默认只读）
- 发现必须改共享 snippet / 全局 CSS / token → 停下升级为 `LegacyImpact`，回 impact 重评
- 找不到 `section-header` / `section-swiper` / `price-format` 的实际文件 → 要仓库路径

---

## 终态措辞禁令（handoff-schema §1）

> 本 skill **永远无权宣布可交付**。

- 恒输出 `ReadyForDelivery: No` + `QAStatus: NotRun`
- **禁止**使用：「交付完成」「上线可用」「全部通过」「可以发布」「已验收」「没问题了」「改完了可以用」
- **允许**的说法只有：「**改动已就位，待 QA**」
- 自检跑过的项写进正文作为证据，但自检**不等于**通过；Theme Check、admin schema 保存、视觉回归、A11y、多语言由 `plaud-theme-qa` 判定（跑 QA-B，外加它恒执行的 QA-Global——后者**不写进** `RequiredQAProfile`）
- 用户即使明说"不用检查了直接给我"，仍照常输出 `No`，把 `QAStatus` 写成 `Skipped(UserWaived)`，并在正文一句话说明风险由用户承担

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| 命名、容器骨架、Section Space、color_scheme、section-header、素材红线、schema 完整性 | `references/naming-and-structure.md` |
| §8 文案 / §9 按钮 / §10 价格 / §11 轮播 的完整条文与提交前 Checklist | `references/vendor-compliance.md` |
| 六步工作流、三层变量写法、Figma 取值决策 | `references/figma-workflow.md` |
| 与上下游 skill 的交接 | `matrix-contract.md` |

视觉与 UX 数值**不在本 skill**：字号字阶 → shared `typography.md`；颜色 token / 配色方案 → shared `colors-and-schemes.md`；断点 / 间距 / 容器宽度 → shared `responsive-and-spacing.md`；图片清晰度 → shared `media-quality.md`；Liquid/schema 格式 → shared `liquid-schema-format.md`；JS / Swiper → shared `javascript-swiper.md`；无障碍 → shared `a11y.md`。**引用文件名，不复制数值。**

---

## 输出契约

### 交付工件时**当场**生成身份三元组（`handoff-schema.md` §2）

`ChangeSetId` 只绑 `ModifiedFiles` 的**文件名集合**是不够的：交出工件之后、QA 开始之前，如果同一批文件的**内容**又被改过，文件集合仍然一致，QA 会错误地判 `ChangeSetIdMatched: Yes`，验的是一批它从未见过的代码。v0.3.0 起身份是 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint` **三元组**（绑不可变 git tree 对象），三个一起才构成身份：`ThemeTreeOid` 单独表达不了声明范围，`ChangeSetScopeFingerprint` 单独表达不了整树，`ObjectFormat` 不比就会把「换了个仓库」误判成「内容变了」。

🔴 **`BaseHeadSha` 是「开工前（写下第一个字节之前）捕获的 baseline commit」，不是「交付工件时的 HEAD」。**
写成后者的实测后果：实现者只要先 commit 再交工件，基准里就已经含本次改动 → 所有声明路径落进 `DECLARED_DIFF_UNCHANGED` → QA 恒阻断，而这与「主题改动 commit 不再让身份失效」直接矛盾。所以**开工第一件事**就是 `git rev-parse HEAD` 并记下来；中途 commit / rebase / checkout **都不改这个值**，事后也不得用当时的 HEAD 覆盖它。
它 v0.3.0 起**不再是失配判据**（不与当前 HEAD 比对），但**仍然 required、且必须是可解析的 commit-ish**：QA 的 `DeclaredDiffCheck`、theme check 的 baseline 物化、以及若干条存量偏差举证都要 `git show <BaseHeadSha>:<file>`。缺失或不可解析时那些检查一律 `Blocked`（**不是 `Advisories`、不是 `N/A`**），`Blocked` 不得折算为 pass → 该轮拿不到交付许可。零改动只读任务填 `N/A`。

因此在**开工前**取 ① ，在**写下面这个 yaml 块的那一刻**（不是改动开始时、不是估算）跑 ②：

```bash
# ① 开工前 —— BaseHeadSha
git rev-parse HEAD

# ② 交付工件那一刻 —— 在**仓库根**跑（先原样复制 §2.5 的整段函数定义）
# 🔴 原样抄这两行，**不要只抄第一行**：旧写法只有 `plaud_theme_tree || echo "..."`，
#    它打印了错误串却让整段 rc=0 —— 任何按 `$?` 分支、或跑在 `set -e` 下的调用方都会
#    认为这道门通过了。判定既要看输出、也要看退出码。
# PATHLIST：本块声明的逐字路径清单，每行一条（= ModifiedFiles 双引号里的字符串）
plaud_theme_tree                  || { echo "THEME_TREE_FAILED"; exit 1; }
plaud_changeset_scope "$PATHLIST" || { echo "SCOPE_FAILED";      exit 1; }
```

`plaud_theme_tree` 输出 `<ObjectFormat> <ThemeTreeOid> <ThemeTreeDigest>`——前两段进工件，**`ThemeTreeDigest` 不进任何工件**（它只用于人读 diff 与跨 object-format 防误判，**不提供抗碰撞**）。`plaud_changeset_scope` 输出 `<ObjectFormat> <ScopeTreeOid> <ScopeDigest>`，`ChangeSetScopeFingerprint` 填**后两段合起来的 `"<ScopeTreeOid> <ScopeDigest>"`**：删除只体现在 `ScopeDigest`，两段必须一起逐字比。三元组一律**逐字原样记录**，不得缩写 oid、不得假定 `sha1`、不得自己重算或换别的命令算。

🔴 **这三个函数的定义不在本文件里，只在 `plaud-theme-shared/references/handoff-schema.md` §2.5。**
去那里**原样复制整段**（含全部 `_plaud_*` 内部函数与全部注释）执行，不要凭记忆敲、不要用任何别处看到的版本、**不要删注释**。

> **为什么这里不再内嵌一份副本**（v0.2.2 删除，v0.3.0 加重）：本节以前抄了一份，附一句"冲突时以 §2 为准"——但那句话拦不住任何人：命令是**可执行**的，抄本一旦落后就会真的算出另一个值。
> 后果不是"多阻断"：producer 算出一个假身份、QA 用 canonical 重算必然失配，正常交付会被永久判 `ChangeSetIdMatched: No`；两边都用同一份旧抄本时，未跟踪文件、被 gitignore 的可发布文件、纯大小写改名可能压根不进身份。
> 🔴 **v0.3.0 起后果还多一档，且严重一个量级**：这几个函数内部会跑 `git add`，而 `git add` 会触发 `post-index-change` hook（实测复现）。canonical 的每一条内部 git 调用都带 `-c core.hooksPath=/dev/null -c core.fsmonitor=false`，clean filter 这个同族入口由**字节保真门在 `git add` 之前**拦下。**一个漏掉 `-c core.hooksPath=/dev/null`、或删掉那道字节保真门的抄本，等于让取证动作执行仓库里的任意脚本**——比 v0.2.x 的「算出一个假指纹」严重一个量级。
> 身份类命令**只允许有一处事实源**。

QA 会在**执行任何检查之前**用同一段 canonical 函数重算三元组并**逐字精确比对**，任一不符即 `ChangeSetIdMatched: No` + 停机。函数本身失败（`TMPDIR` 不可写、git < 2.25、Windows、命中任一 fail-closed 门）→ 相关检查项填 `Blocked`，**不得**填 `Passed` / `NotApplicable`，也不得改用自己写的命令降级取值。**生成三元组之后不要再改可发布面的内容。**

📎 **v0.3.0 起这些动作不再让身份失效**（逐条实测；旧文档里「别 `git add`，会让指纹失配」「`memory/` 的更新不要单独 commit」之类的说法**已过时，不要继续遵守**）：`git add` / `git reset`（内容不变）、`git commit`（含 commit `memory/`、含把本次主题改动 commit 掉）、仓库根的 scratch 临时文件（`tc-diff.js` / `node_modules` / `.env`）。真正会让它变的只有**可发布面的内容变化**。
🔴 **但这不是对这些动作的授权，也不改变 `BaseHeadSha` 的取值**：它仍然是开工前那一个 commit，不得因为中途 commit 过就换成新的 HEAD。canonical 内部的 `git add` 用的是隔离的临时索引，**不动用户的 `.git/index`**。

**Path B 尤其注意**：新建的 `sa-*` 文件多为 untracked。v0.2.x 需要一段专门的未跟踪文件循环来收它们，漏掉那一段就等于身份不覆盖本次主体产出；v0.3.0 由空白临时索引下的 `git add -A -f` 自己枚举（未跟踪、被 gitignore、纯大小写改名都在内），这个坑被构造性堵上了——但**前提是你真的原样复制了 canonical**。

### HandoffContract

正文可自由组织（文件清单、命名合规、vendor Checklist、响应式说明、取值决策），但**回复的最后必须是一个 `yaml` 代码块**，字段名与顺序与 `handoff-schema.md` §4 一字不差，不得增删改名：

```yaml
ChangeSetId:              # CS-<YYYYMMDD>-B<NN>，例 CS-20260806-B01
BaseHeadSha:              # 🔴 **开工前（写下第一个字节之前）捕获的 baseline commit**，不是交付时的 HEAD；
                          #   零改动填 N/A。v0.3.0 起不再是失配判据，但 required 且必须可解析：
                          #   缺失 / 不可解析 → DeclaredDiffCheck 等检查填 Blocked（不是 Advisories、不是 N/A）
ObjectFormat:             # sha1 | sha256 —— git rev-parse --show-object-format 的原样输出；零改动填 N/A
ThemeTreeOid:             # plaud_theme_tree 输出的第 2 段；零改动填 N/A
ChangeSetScopeFingerprint: # plaud_changeset_scope 输出的第 2、3 段，形态 "<ScopeTreeOid> <ScopeDigest>"
                          #   —— 两段必须一起逐字比：删除只体现在 ScopeDigest；零改动填 N/A
ReadOnlyProof: N/A        # 仅零改动只读任务填写；Path B 恒为 N/A
AssessmentRef:            # 引用 plaud-theme-impact 的 ASMT-<YYYYMMDD>-<NN>
OriginTriageRef:          # 本块若由反馈返工产生：TriageId + ItemId；否则 N/A
Path: B
ReconMode:                # IntegrationSurface（纯新建常态）｜LegacyImpact（写入了任何存量文件——含 snippet/全局 CSS/token/既有 section/templates/layout/config/locales 既有 key/build 产物，或新增文件被存量机制自动消费——须回 impact 重评）
ModifiedFiles:            # 逐条 `- "<逐字路径>": <一句话改动>`；必须与工作树一致
                          #   🔴 **路径必须用双引号包住且逐字精确**（不 trim、不 glob、不写目录）：
                          #   它同时是 ChangeSetScopeFingerprint 与 DeclaredDiffCheck 的**机器输入**，
                          #   下游把引号内的字符串逐字取出、每行一条喂给那两个函数。带尾空格的真实
                          #   路径被 trim 掉会让声明指错文件；路径含双引号 → 函数 fail closed，先重命名
                          #   🔴 **不含 memory/ 下的文件**：memory/ 不属于 ChangeSet，也不在可发布面内
RootCause: N/A            # 新建 section 填 N/A
OptionsConsidered:       # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:       # QA-B；升级为 LegacyImpact 时加 QA-A；B+C 交叉时加 QA-C。🔴 不得写 QA-Global——QA 按 §5 恒执行
ThemeCheckRequired:      # Yes | No（新建 .liquid + schema 恒为 Yes）
VisualRegressionRequired: # Yes | No
BuildRequired:           # Yes | No（是否动了 shopify-common/src 需 npm run build）
ApprovedExceptions:      # 逐项声明的 🟠 ApprovedException；无则填 []
                         #   Clause 只能取 shared §8.1 封闭清单内的条款；Scope 必须逐对象/配对绑定
                         #   ApprovalRef 为空、或 ApprovedBy 是自己 → QA 判 Failed（见 shared §8.1）
                         #   🔴 双周会「已同意但清单尚未更新」的条款**不得**写进来（Clause 越界 = 谎报，
                         #      QA 判 ApprovedExceptionsChecked: Failed）。正确处理：本字段保持 [] 或不列该项，
                         #      条款按其当前档位照常判，BlockingGaps 记
                         #      PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>
                         #      清单扩容只能由 maintainer 在新版本快照里做（见 shared §8.1「封闭清单的变更权限」）
BlockingGaps:            # 实现中发现但无权处理的（素材来源、模板接入授权、spec 取值二选一…）
QAStatus: NotRun         # 恒为 NotRun
NextRequiredSkill: plaud-theme-qa-intake
ReadyForDelivery: No     # 恒为 No，见 handoff-schema §1
```

> ⚠️ 每个 `key:` 与注释之间**必须有空格**。YAML 里 `Key:# 注释` 是解析错误，照抄时不要压掉那个空格。

`ChangeSetId` 的 `<NN>` 是当日 Path B 的序号，从 `01` 起。`ModifiedFiles` 必须与工作树一致且逐字精确，身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）必须是交付当刻现算的，`BaseHeadSha` 必须是**开工前**取的那个 commit——任一不符会让 `plaud-theme-qa` 输出 `ChangeSetIdMatched: No` 并停机。

**不得**在这个块里出现 `AssessmentRef` 以外的 Assess 字段（`TheoreticalReferences` / `RiskTier` / `ReadyForImplement`），也不得出现 Verify 阶段字段（`ChangeSetIdMatched` / `ThemeCheck` / 各 `*Check`）。
