# Theme Check 门 — baseline 增量判定（可直接执行）

契约见 `plaud-theme-shared/references/handoff-schema.md` §6。本文件是它的**执行手册**：确切命令、baseline 取法、差集脚本、以及已知的钻空子路径与堵法。

> **贯穿原则：宁可误报，不可漏报。** 任何"解析不确定 / 路径不确定 / 映射不确定"的情形一律 `ThemeCheck: Blocked`，绝不按"没查到就是没有"继续。误报的代价是多看一眼；漏报的代价是带病上线。

---

## 0. 为什么不能用"全仓 pass"当门

实测某 Plaud 主题仓库（2026-08-06，Shopify CLI 3.92.0）：

```
3334 errors / 1004 warnings
  其中 MatchingTranslations 3254 条（多语言 locale 完整性，仓库级历史状态，与单次改动无关）
  剔除后 80 条 error：
    ImgWidthAndHeight 35 / TranslationKeyExists 25 / LiquidHTMLSyntaxError 5 /
    ParserBlockingScript 5 / MissingTemplate 3 / MissingAsset 2 / UnknownFilter 2 /
    ContentForHeaderModification 1 / ValidSchemaName 1 / ValidDocParamTypes 1
```

把"全仓零 error"当通过条件 → 每个任务永远红着 → 门失效。**唯一有效判定是 baseline 增量。**

同理，**`shopify theme check` 的 exit code 不是判定依据**（仓库本来就红，恒非 0）。不要 `set -e`，不要用 `&& echo pass`。

---

## 1. 前置门（任一不满足 → `ThemeCheck: Blocked`）

```bash
shopify version                                      # 记录版本号，写进 ThemeCheckEvidence
ls <theme-root>/{sections,snippets,layout,config}    # 确认是 theme root
```

**合法的 Blocked 情形**（handoff-schema §6）：CLI 未安装、仓库不是 theme root、`shopify-common` build 产物缺失导致检查失真、`.theme-check.yml` 依赖缺失、网络不可用导致首次安装失败。

**本地 lint 不需要登录 Shopify 店铺**——输入是本地目录，命令里没有 store / password 参数。需要登录的是 `push` / `preview` / dev store 交互。所以"没登录所以跑不了"**不是**合法的 Blocked 理由。

`BuildRequired: Yes`（动了 `shopify-common/src`）而未 `npm run build` → build 产物与源不一致 → `Blocked`。

### 1.1 检查配置本身必须先被锁住（否则整个门可被静默关闭）

**这是最隐蔽的绕过路径**：本次改动如果动了 `.theme-check.yml`（新增 exclude、关掉某个 check、改 severity），或在代码里加了 suppression 注释，那么 after 那次跑出来的 offense 会被合法地隐藏，差集自然为 0。新增文件也可以靠把自己加进 exclude 来豁免。

```bash
# (a) 检查配置是否被本次改动碰过（基准是 BaseHeadSha，不是 HEAD —— 见 §2 的 📎）
git -C <theme-root> diff --name-only <BaseHeadSha> | grep -E '\.theme-check\.ya?ml|\.shopifyignore'
# (b) 新增的 suppression 指令
git -C <theme-root> diff <BaseHeadSha> -U0 | grep -nE '^\+.*theme-check-(disable|disable-next-line)'
```

| 结果 | 处理 |
|---|---|
| (a) 有命中 | 默认 `ThemeCheck: Blocked`。要继续必须：① 用户明确授权该配置变更；② **before / after 两次都强制用同一份配置**（把 `BaseHeadSha` 版本的配置显式传给两次运行），并在 `ThemeCheckEvidence` 写明用的哪一份。 |
| (b) 有命中 | 逐条列出并要求说明理由。无理由 → `Failed`。suppression 是"承认有问题但选择忽略"，不是"没问题"。 |
| 都无命中 | 继续。仍要在 Evidence 里写"配置未变更"这一句结论。 |

---

## 2. 取 baseline（改动前状态）

前提：Step 1 的四重绑定校验已通过（文件集合 + `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`），且 `BaseHeadSha` **可解析**。**校验未过就不要跑 baseline**——baseline 会把别人的改动一起算进去。

📎 **v0.3.0 起 baseline 的锚点是 `BaseHeadSha`，不是 `HEAD`。** v0.2.x 靠"ChangeSetId 校验通过 ⇒ HEAD 就是改动前状态"来取 baseline；新模型不再拿 HEAD 做失配判据（handoff-schema §2.8），实施期间 commit 是合法的 —— 继续用 `HEAD` 会把**本次的改动当成基线**，差集恒为空、门形同虚设。

**`BaseHeadSha` 缺失或不可解析 → `ThemeCheck: Blocked`**，不是 `NotApplicable`、不是"就用 HEAD 凑合"。

### 唯一方案 — 从 `BaseHeadSha` 物化 baseline

```bash
BASE="$(mktemp -d "${TMPDIR:-/tmp}/plaud-qa-baseline.XXXXXX")"    # 🔴 必须在仓库外
git -C <theme-root> rev-parse --verify "<BaseHeadSha>^{commit}" >/dev/null \
  || { echo "BASE_UNRESOLVABLE"; exit 1; }                        # → ThemeCheck: Blocked
git -C <theme-root> archive --format=tar "<BaseHeadSha>^{tree}" | tar -x -C "$BASE"
shopify theme check --path "$BASE" --output json > "$SCRATCH/tc-before.json" 2>"$SCRATCH/tc-before.err"
```

- `^{tree}` 不能省：`git archive` 收的是那个 commit 的整棵树，写清楚取的是树对象，避免有人传一个 tag / branch 名进来时语义漂移。
- 物化目录**放 scratch，不放仓库内**；用完删掉。

**注意（必查，物化方案下比 worktree 更严重）**：物化目录里**没有** `node_modules`、**没有 ignored 的 build 产物**，也没有任何未跟踪文件。如果 `.gitignore` 覆盖了 `shopify-common` 的输出而 theme check 又依赖它 → baseline 与 after 的产物状态不同 → 差集失真。此时必须在物化目录里按 `BaseHeadSha` 重新 build（记录 build 命令与产物 hash 写进 `Evidence`），做不到就 `ThemeCheck: Blocked`。

```bash
git -C <theme-root> check-ignore -v $(git -C <theme-root> diff --name-only <BaseHeadSha>)   # 有输出即踩雷
```

📎 **`git stash` 方案已删除**（v0.2.3 的方案 B）：stash 得到的是"相对**当前 HEAD** 的干净树"，而新模型的基线是 `BaseHeadSha` —— 中途 commit 过就完全不是同一棵树。它同时还有两个老缺陷（`--include-untracked` 不含 ignored 文件、pop 冲突可能弄丢用户改动）。**不要再用它取 baseline。**

### 改动后

after 那一次跑在 **`StageDirRef` 指向的 workspace 快照**里（不是活工作树，handoff-schema §2.6）：

```bash
shopify theme check --path "$StageDirRef" --output json > "$SCRATCH/tc-after.json" 2>/dev/null
```

`ThemeCheckEvidence` 里 before / after 两个目录都要写出来，否则无法复核跑的是不是同一对对象。

**两次必须用同一 CLI 版本、同一 `--path` 语义（都是 theme root）、同一份 `.theme-check.yml`（见 §1.1）。** 换了任一项，差集无意义。

---

## 3. 必须全仓跑，不能只跑改动文件

诱人的捷径：`shopify theme check --path sections/foo.liquid`。**禁止。**

原因：改动的外溢 offense 出现在**别的文件**上。删掉 `assets/x.css` → `MissingAsset` 报在引用它的 `layout/theme.liquid`；删掉 locale key → `TranslationKeyExists` 报在所有用它的 section。只扫改动文件会全部漏掉。

正确做法：**两次都全仓跑**，在解析阶段做过滤。

---

## 4. 采集差集所需的三份输入

差集不能只靠两份 JSON。逐 occurrence 匹配需要 **rename 清单** 和 **diff hunk**（把 baseline 行号投影到 after 行号），少任一样都有稳定漏报（见 §8）。

三份输入一律用 NUL 分隔采集，避免文件名含空格 / 引号 / 非 ASCII 时被截断：

```bash
cd <theme-root>

# 🔴 两个 git 选项必须固定，否则非 ASCII 路径会被引号化 / 转义，解析不出来：
#    -c core.quotePath=false  → 路径按原样输出，不转成 \\344\\270\\255 这种八进制转义
#    --no-color               → 避免 ANSI 序列混进 header
# 🔴 基准一律是 <BaseHeadSha>，不是 HEAD（§2 的 📎）：改动被 commit 之后 HEAD 的 diff 是空的，
#    manifest 与 hunks 一起变空 → 投影退化成恒等映射 → 位移抵消全部漏报。
# 🔴 用**函数**包，不要写成 GIT="git -c core.quotePath=false" 再 $GIT：zsh 默认不对未加引号的
#    变量做词分割（SH_WORD_SPLIT 关闭），$GIT 会被当成一个可执行文件名 → command not found。
#    bash 3.2 下能跑、zsh 下跑不了的写法，等于一半的机器上这道门直接不执行（实测复现）。
gitq() { git -c core.quotePath=false "$@"; }

# (1) 改动清单（含 rename / copy 识别），NUL 分隔
{ gitq diff --name-status -M --find-renames -z "<BaseHeadSha>";
  gitq ls-files --others --exclude-standard -z \
    | while IFS= read -r -d '' f; do printf 'A\0%s\0' "$f"; done;
} > "$SCRATCH/manifest.bin"

# (2) diff hunk → { "<baseline 路径>": [{o,ol,n,nl}] }
gitq diff -U0 --no-color "<BaseHeadSha>" | node -e '
  let s = "";
  process.stdin.on("data", d => s += d).on("end", () => {
    const out = {}; let f = null; let orphanHunks = 0;
    const unq = (p) => {
      // git 默认会把非 ASCII 路径引号化并转义（core.quotePath）。采集端已关掉它；
      // 万一仍收到引号形式，这里解一层，解不了就当解析失败。
      if (!p.startsWith('"')) return p;
      try { return JSON.parse(p); } catch { return null; }
    };
    for (const l of s.split("\n")) {
      if (l.startsWith("diff --git ")) { f = null; continue; }
      let m = l.match(/^--- (?:a\/(.+)|\/dev\/null)$/);
      if (m) { f = m[1] ? unq(m[1]) : null; continue; }   // 有旧路径就用旧路径（rename 时 key 必须是 baseline 侧）
      m = l.match(/^\+\+\+ (?:b\/(.+)|\/dev\/null)$/);
      if (m) { if (f === null) f = m[1] ? unq(m[1]) : null; continue; }  // 仅新文件才退回新路径
      m = l.match(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/);
      if (m) {
        if (!f) { orphanHunks++; continue; }              // 有 hunk 却没解析出路径 → 必须让下游 Blocked
        (out[f] = out[f] || []).push({
          o: +m[1], ol: m[2] === undefined ? 1 : +m[2],
          n: +m[3], nl: m[4] === undefined ? 1 : +m[4]
        });
      }
    }
    for (const k of Object.keys(out)) out[k].sort((a, b) => a.o - b.o);
    if (orphanHunks) out.__parseErrors = orphanHunks;     // tc-diff.js 见到它就进 blockers
    console.log(JSON.stringify(out));
  });
' > "$SCRATCH/hunks.json"

# (3) ModifiedFiles（来自上游 §4 工件，已在 Step 1 校验过与 (1) 一致）
```

**hunk 的 key 必须是 baseline 侧路径**（`--- a/<path>`），因为投影的输入是 baseline 行号。这就是解析器"有旧路径就用旧路径、只有 `--- /dev/null`（新文件）才退回 `+++ b/` 路径"的原因——rename + 同时改内容时，如果 key 落成新路径，`project()` 查不到 hunk 会退化成恒等映射，位移抵消就漏了。

---

## 5. 差集脚本

`--output json` 走 stdout。JSON 里 `severity` 是**字符串** `"error"` / `"warning"`（不是数字），不要写 `severity === 2`。

### 判定模型：逐 occurrence 匹配（不是计数差集）

> **baseline 的每一条 offense 只能抵消 after 的一条 offense，且行号必须对得上。**

用 diff hunk 把 baseline 的行号投影到 after 行号：

| baseline 行的位置 | 投影 |
|---|---|
| 文件无 hunk | 恒等（行号不变） |
| 在纯新增 hunk（`ol === 0`）的锚点行及之前 | 不受影响——插入发生在旧第 `o` 行**之后**，所以 `row === o` 不能加 delta（这是最容易写错的 off-by-one） |
| 在修改 / 删除 hunk（`ol > 0`）的旧区间 `[o, o+ol-1]` 内 | **`null`——这条 baseline offense 作废，不再抵消任何东西** |
| 在 hunk 之后 | 累加 `delta = Σ(nl - ol)` |

凡是匹配不到 baseline occurrence 的 after offense，一律算新增。**after offense 缺行号时永不抵消**（同时记进 `blockers`）——让无行号的条目随便消费一条 baseline 就是直接的漏报口子。

这个模型一次性覆盖五类漏报：

| 漏报路径 | 为什么被堵住 |
|---|---|
| 修旧引新、数量不变（位移抵消） | 新位置的投影行号对不上任何 baseline occurrence |
| **删若干行导致别的文件冒出 offense，同时同指纹 offense 在本文件消失** | 消失的那条落在被删区间 → 投影 `null` → 作废；新冒出的那条无 occurrence 可匹配 → 算新增 |
| warning → error 升级 | severity 在匹配 key 里 |
| 新增文件的全部 offense | baseline 池里没有该文件的 occurrence |
| offense 缺行号被拿去顶替存量条目 | 无行号一律不参与抵消，且进 `blockers` |

把下面脚本存到 scratchpad（`$SCRATCH`，**不要写进用户仓库**）。
📎 **理由 v0.3.0 起变了**：scratch 文件不在可发布面，**不再**让 `ThemeTreeOid` 失配（v0.2.x 会）。但仍然不该写进用户仓库——那是别人的工作树，QA 只做取证不留痕；而且写进仓库的 `.js` 一旦落在可发布目录下就会真的改变身份、还可能被推上线。

```js
// tc-diff.js — Theme Check baseline 增量判定（逐 occurrence 匹配）
// usage:
//   node tc-diff.js --before <json> --before-root <dir> \
//                   --after <json>  --after-root <dir> \
//                   --manifest <name-status-z.bin> --hunks <hunks.json>
//
// 判定模型：**baseline 的每一条 offense 只能抵消 after 的一条 offense，且行号必须对得上。**
// 用 diff hunk 把 baseline 行号投影到 after 行号；投影不上（该行被删/被改）的 baseline offense
// 不参与抵消。凡是匹配不到 baseline occurrence 的 after offense，一律算新增。
//
// 设计原则：**宁可误报，不可漏报**。任何解析/路径/映射/行号不确定的情形都进 `blockers`；
// 调用方看到非空 blockers 必须判 ThemeCheck: Blocked（不是 Passed）。
const fs = require('fs');
const path = require('path');

const blockers = [];
const argv = process.argv.slice(2);
const arg = (n) => { const i = argv.indexOf(n); return i < 0 ? null : argv[i + 1]; };

function main() {
  // ---------- 1. 改动清单（NUL 分隔 + UTF-8，容忍空格/引号/非 ASCII 文件名） ----------
  const renameMap = new Map();    // afterPath -> beforePath（仅 R；C 不算，见下）
  const statusOf = new Map();     // path -> A|M|D|R|C
  const beforePathOf = new Map(); // afterPath -> beforePath（R/C 都记，供 §7 扫描）

  const mfPath = arg('--manifest');
  if (!mfPath) blockers.push('未提供 --manifest（git diff --name-status -M -z <BaseHeadSha>）');
  else {
    // NUL 不会出现在 UTF-8 多字节序列内部，所以按 utf8 解码后再按 \0 切是安全的
    const toks = fs.readFileSync(mfPath, 'utf8').split('\u0000').filter((t) => t !== '');
    for (let i = 0; i < toks.length;) {
      const st = toks[i][0];
      if (st === 'R' || st === 'C') {
        const oldP = toks[i + 1], newP = toks[i + 2];
        if (oldP === undefined || newP === undefined) { blockers.push('manifest 中 R/C 记录不完整'); break; }
        statusOf.set(newP, st);
        beforePathOf.set(newP, oldP);
        // 只有 R 参与 baseline 归一化；C（copy）是新文件，不得映回源文件抵消其存量 offense
        if (st === 'R') renameMap.set(newP, oldP);
        i += 3;
      } else {
        const p = toks[i + 1];
        if (p === undefined) { blockers.push('manifest 记录不完整'); break; }
        statusOf.set(p, st);
        i += 2;
      }
    }
  }
  const modifiedFiles = [...statusOf.keys()];

  // ---------- 2. hunk → baseline 行号到 after 行号的投影 ----------
  // hunks.json 形如 { "<baseline 路径>": [{o,ol,n,nl}] }（o/ol = 旧起点·旧行数）
  let hunks = {};
  const hPath = arg('--hunks');
  if (!hPath) blockers.push('未提供 --hunks（由 git diff -U0 <BaseHeadSha> 解析），无法做行号投影');
  else {
    try { hunks = JSON.parse(fs.readFileSync(hPath, 'utf8')); }
    catch (e) { blockers.push(`--hunks 解析失败：${e.message}`); hunks = {}; }
    if (hunks === null || typeof hunks !== 'object' || Array.isArray(hunks)) {
      blockers.push('--hunks 结构非法（应为 {file: [hunk]} 对象）');
      hunks = {};
    }
    if (hunks.__parseErrors) {                 // 解析器遇到 hunk 但认不出路径（如引号化路径）
      blockers.push(`--hunks 有 ${hunks.__parseErrors} 个 hunk 未能归属到文件——行号投影不可信`);
      delete hunks.__parseErrors;
    }
  }

  // baselineFile 的第 row 行 → after 行号；被删除/被改写的行返回 null
  const project = (baselineFile, row) => {
    const hs = hunks[baselineFile];
    if (!hs) return row;                       // 该文件无 hunk → 恒等映射
    if (row == null) return null;
    let delta = 0;
    for (const h of hs) {
      // 纯新增 hunk（ol === 0）的锚点在"旧第 o 行之后"，所以 row === o 时不受影响。
      // 修改/删除 hunk（ol > 0）覆盖旧 [o, o+ol-1]，row < o 时不受影响。
      if (h.ol === 0 ? row <= h.o : row < h.o) break;
      if (h.ol > 0 && row < h.o + h.ol) return null;   // 落在被删/被改区间 → 作废
      delta += h.nl - h.ol;
    }
    return row + delta;
  };

  // ---------- 3. 解析 theme check JSON（fail-closed） ----------
  function load(jsonPath, root, tag) {
    if (!jsonPath) { blockers.push(`${tag}: 未提供 JSON 路径`); return []; }
    if (!root) { blockers.push(`${tag}: 未提供 root`); return []; }
    let raw;
    try { raw = JSON.parse(fs.readFileSync(jsonPath, 'utf8')); }
    catch (e) { blockers.push(`${tag}: JSON 无法读取/解析 — ${e.message}`); return []; }

    const files = Array.isArray(raw) ? raw
      : (raw && Array.isArray(raw.files) ? raw.files
        : (raw && Array.isArray(raw.results) ? raw.results : null));
    if (files === null) {
      blockers.push(`${tag}: 顶层结构无法识别（既非数组，也无 files/results 数组）——不得按空结果继续`);
      return [];
    }

    let absRoot;
    try { absRoot = fs.realpathSync(path.resolve(root)); }
    catch (e) { blockers.push(`${tag}: root 不可用 — ${e.message}`); return []; }

    const rel = (p) => {
      if (!p) { blockers.push(`${tag}: offense 缺少路径`); return null; }
      const abs = path.resolve(absRoot, String(p));
      const r = path.relative(absRoot, abs).split(path.sep).join('/');
      if (r === '' || r.startsWith('..')) { blockers.push(`${tag}: offense 路径落在 root 之外：${p}`); return null; }
      return r;
    };

    const out = [];
    for (const f of files) {
      if (f === null || typeof f !== 'object') { blockers.push(`${tag}: 文件条目非法`); continue; }
      const fp = f.path || f.file || f.filename || null;
      if (!Array.isArray(f.offenses)) {
        blockers.push(`${tag}: 文件条目缺少 offenses 数组：${fp || '(无路径)'}`);
        continue;
      }
      for (const o of f.offenses) {
        if (o === null || typeof o !== 'object') { blockers.push(`${tag}: offense 条目非法（${fp}）`); continue; }
        const check = o.check || o.code;
        const sev = String(o.severity ?? '').toLowerCase();
        const file = rel(o.path || o.file || fp);
        if (!check || !sev || file === null) {
          blockers.push(`${tag}: offense 字段不完整：${JSON.stringify(o).slice(0, 120)}`);
          continue;
        }
        const row = Number.isInteger(o.start_row) ? o.start_row
          : (Number.isInteger(o.line) ? o.line : null);
        if (row === null) {
          // 没有行号就无法做 occurrence 匹配。不得让它随便抵消一条 baseline。
          blockers.push(`${tag}: offense 缺行号，无法参与行匹配（${check} @ ${file}）`);
        }
        out.push({ file, check, sev, msg: String(o.message || '').trim(), row, col: o.start_column ?? null });
      }
    }
    return out;
  }

  const before = load(arg('--before'), arg('--before-root'), 'before');
  const after = load(arg('--after'), arg('--after-root'), 'after');

  // ---------- 4. 逐 occurrence 匹配 ----------
  // key 不含行号（行号靠投影单独比），含 severity（防升级漏报）。
  // 分隔符用 NUL：它不可能出现在 check / 路径 / message 里，避免拼接歧义。
  const SEP = '\u0000';
  const baseFileOf = (afterFile) => renameMap.get(afterFile) || afterFile;
  const key = (check, sev, baseFile, msg) => [check, sev, baseFile, msg].join(SEP);

  // baseline occurrence 池：key -> [投影后的 after 行号...]
  const pool = new Map();
  for (const b of before) {
    const projected = project(b.file, b.row);
    if (projected === null) continue;                 // 该行被删/被改 → 作废，不再抵消任何东西
    const k = key(b.check, b.sev, b.file, b.msg);
    if (!pool.has(k)) pool.set(k, []);
    pool.get(k).push(projected);
  }

  const added = [];
  for (const a of after) {
    let matched = false;
    if (a.row !== null) {                             // 无行号 → 永不抵消（保守），已记 blocker
      const rows = pool.get(key(a.check, a.sev, baseFileOf(a.file), a.msg));
      if (rows && rows.length) {
        const i = rows.indexOf(a.row);                // 行号对得上才算同一条
        if (i >= 0) { rows.splice(i, 1); matched = true; }   // 一条 baseline 只抵消一条 after
      }
    }
    if (!matched) added.push(a);
  }

  const inScope = added.filter((o) => modifiedFiles.includes(o.file));
  const outScope = added.filter((o) => !modifiedFiles.includes(o.file));

  return {
    blockers,
    beforeTotal: before.length,
    afterTotal: after.length,
    addedTotal: added.length,                         // 逐 occurrence 计数
    addedInModifiedFiles: inScope.length,
    addedOutsideModifiedFiles: outScope.length,
    addedErrors: added.filter((o) => o.sev === 'error').length,
    addedWarnings: added.filter((o) => o.sev === 'warning').length,
    deletedOrRenamed: [...statusOf]
      .filter(([, s]) => s === 'D' || s === 'R' || s === 'C')
      .map(([p, s]) => ({ status: s, beforePath: s === 'D' ? p : (beforePathOf.get(p) || null), afterPath: s === 'D' ? null : p })),
    inScope, outScope,
  };
}

// 无论抛什么异常，都输出合法 JSON 且 blockers 非空 —— 调用方永远不会把崩溃误读成"无新增"
let result;
try { result = main(); }
catch (e) { result = { blockers: [`脚本异常终止：${e && e.stack ? e.stack : e}`], addedTotal: null }; }
if (!result.blockers || !result.blockers.length) result.blockers = result.blockers || [];
console.log(JSON.stringify(result, null, 2));
```

跑法：

```bash
node "$SCRATCH/tc-diff.js" \
  --before "$SCRATCH/tc-before.json" --before-root "$BASE" \
  --after  "$SCRATCH/tc-after.json"  --after-root  "$StageDirRef" \
  --manifest "$SCRATCH/manifest.bin" --hunks "$SCRATCH/hunks.json"
```

脚本主流程整体 `try/catch`：**无论抛什么异常都输出合法 JSON 且 `blockers` 非空**，调用方永远不会把崩溃误读成"无新增"。

---

## 6. 判定

```
ThemeCheck: Blocked  ⟸  blockers 非空（解析失败 / 缺输入 / 路径异常 / 配置变更未锁）
ThemeCheck: Passed   ⟺  blockers 为空
                       ∧ addedInModifiedFiles == 0
                       ∧ addedOutsideModifiedFiles == 0
                       ∧ §7 的删除 / rename 附加核查全部完成
```

- 脚本输出的 `addedInModifiedFiles` / `addedOutsideModifiedFiles` 就是 handoff-schema §6 判定表里的那两个指标，**两者都必须为 0**。删 asset / 删 locale key 的外溢 offense 落在未被修改的调用方文件里，只看范围内会系统性漏掉。
- `addedOutsideModifiedFiles > 0` 时先判归因：确认由本次改动引起 → `Failed`，正文说明外溢链路；确认 baseline 不干净（例如 baseline 与 after 之间上游 rebase 了）→ `Blocked`，重取 baseline。**不允许**用"这条不是我改的"直接忽略。
- `Failed` 时逐条列出 `check + severity + 文件 + 行号 + message`（脚本的 `inScope` / `outScope` 已带全）。
- **warning 新增也算 `Failed`。** 本次新引入的 offense 不分 severity。存量 warning 不管。
- **申辩通道**：若某条被判新增的 offense 确实是存量位移，可给出 baseline 里的对应条目（check + severity + message + 行号）并说明为什么投影没对上（例如 hunk 采集时机不对）。**空口说"这是原来就有的"不算。**
- 顺手修掉存量 offense 是加分项，**不得**作为通过条件，也不得扩散到 `ModifiedFiles` 之外的文件（扩散了就变成 ChangeSet 失配，回 Step 1 停机）。

---

## 7. 删除与 rename 的附加核查（lint 不够）

脚本输出的 `deletedOrRenamed` 非空时，**光看 theme check 差集不足以判 `Passed`**。Theme Check 只建模了它认识的引用形式；动态 `render`、section group、模板 JSON 里的 `type`、JS 里拼出来的 asset 路径、外部配置引用它都看不见。删掉这类文件可能新增 offense 为零，但线上直接白屏。

每条记录的 **`beforePath`（旧路径）** 必须跑下面三条扫描——注意是旧路径不是新路径，脚本的 `deletedOrRenamed` 输出已把 `{status, beforePath, afterPath}` 拆开给你：

```bash
OLD=<deletedOrRenamed[].beforePath>; BASE_NAME=$(basename "$OLD" | sed 's/\.[^.]*$//')
grep -rn "$BASE_NAME" <theme-root>/{sections,snippets,assets,layout,templates,config,locales}/
grep -rn "\"type\": \"$BASE_NAME\"" <theme-root>/templates/
grep -rn "$BASE_NAME" <theme-root>/templates/*.json <theme-root>/config/*.json
```

- 任一命中且未同步更新 → `ThemeCheck: Failed`（外加在 `ProfileSpecificResults` 里记一条依赖回归失败）。
- 无命中 → 仍必须由 `ThemeRuntimePreview` 兜底确认页面正常。**预览拿不到 → `ThemeRuntimePreview: Blocked`**，因而 `ReadyForDelivery: No`。删除类改动不允许纯静态放行。

---

## 8. 已知钻空子路径与堵法

| 钻法 | 堵法 |
|---|---|
| **新增文件没有 baseline，所以不算新增** | ❌ 错。baseline occurrence 池里没有该文件的任何条目 ⇒ 它的**全部** offense 都匹配不上 ⇒ 全算新增，一条不豁免。逐 occurrence 匹配天然实现，不要加白名单。 |
| **修掉一条、又引入一条一模一样的，计数不变** | §5 逐 occurrence 匹配：新位置的行号投影对不上任何 baseline occurrence → 算新增。缺 `--hunks` 时脚本直接进 `blockers`。 |
| **删掉若干行，导致别的文件冒出 offense，同时同指纹 offense 在本文件消失** | 消失的那条落在被删区间 → 投影为 `null` → 作废，不参与抵消；新冒出来的那条无 occurrence 可匹配 → 算新增。 |
| **`git mv` 之外用 copy（`C` 状态）复制文件，让新文件的 offense 被源文件 baseline 抵消** | 脚本只把 `R` 放进 `renameMap`；`C` 保持新文件语义，其 offense 全算新增。 |
| **文件名带空格 / 引号 / 非 ASCII，把清单解析截断** | manifest 与 untracked 列表一律用 `-z` NUL 分隔采集，脚本按 NUL 解析。 |
| **脚本崩溃，调用方当成"跑完了没新增"** | 主流程整体 `try/catch`，任何异常都输出合法 JSON 且 `blockers` 非空。 |
| **warning 悄悄升级成 error** | 指纹含 `severity`，升级会被当成新指纹。 |
| **改 `.theme-check.yml` 加 exclude / 关 check** | §1.1：配置被碰过默认 `Blocked`；要继续必须两次强制用同一份配置。 |
| **加 `theme-check-disable` 注释** | §1.1 (b)：逐条列出并要求理由，无理由 `Failed`。 |
| **rename 后旧路径 offense 全成"假新增"，淹没真问题** | `--manifest` 用 `-M --find-renames`，脚本把 after 新路径映射回旧路径再比对。 |
| **删文件绕过：lint 没报就算过** | §7：旧路径/basename 全仓引用扫描 + 运行时预览兜底。 |
| **改的是 ignored 的 build 产物，物化出来的 baseline 里没有它** | §2：先跑 `git check-ignore -v`；踩雷则在物化目录内按 `BaseHeadSha` 重 build，做不到 `Blocked`。 |
| **拿 `HEAD` 当 baseline，而改动已经 commit 掉了** | §2 的 📎：基准必须是 `BaseHeadSha`。用 `HEAD` 会算出空 diff、差集恒为 0，门形同虚设。`BaseHeadSha` 不可解析 → `Blocked`，不得"就用 HEAD 凑合"。 |
| **在活工作树上跑 after** | after 必须跑在 `StageDirRef` 快照里（handoff-schema §2.6）：算完到逐文件读取之间工作树还能再变。 |
| 只跑改动后那一次，"看着还行" | 没有 baseline 就没有判定。缺 before JSON → `Blocked`。 |
| 只跑改动文件的 `--path` | §3：外溢 offense 全漏。两次都必须全仓。 |
| 用 exit code 当结论 | 仓库恒非 0，无信息量。只看差集。 |
| 把 `MatchingTranslations` 之类噪声"整类忽略" | ❌ 只能靠 baseline 对消，不能按 check 名整类拉黑——本次真新增了一条就会被放过。 |
| `severity === 2` 之类数字判断 | JSON 里是字符串。数字比较恒 false，等于不过滤。 |
| JSON 结构不认识 → 当成空结果 | 脚本 fail-closed：未知顶层结构、缺 `offenses` 数组、offense 字段不全，全部进 `blockers` → `Blocked`。 |
| CLI 版本前后不同 | 检查集合会变，差集失真。两次同版本，版本号写进 `ThemeCheckEvidence`。 |
| 没跑 `npm run build` 就检查 | `BuildRequired: Yes` 时结果失真 → `Blocked`。 |

---

## 9. 重点关注的 check（Plaud 历史高发，对应矩阵红线）

判 `Failed` 后写正文时点名这些，因为它们直接对应 shared §8 红线：

| check | 对应红线 |
|---|---|
| `LiquidHTMLSyntaxError` / `UnclosedHTMLElement` | Liquid 文件格式 |
| `ImgWidthAndHeight` | `image_url` 带 width / 防 CLS（与"图片清晰度红线"是两件事，见 `qa-global.md`） |
| `ValidSchemaName` | schema 命名（Path B 的 `SA:` 前缀） |
| `MissingAsset` / `MissingTemplate` | 引用了不存在的资源 |
| `UnknownFilter` / `DeprecatedFilter` | Liquid 过滤器 |
| `ParserBlockingScript` | 性能 |
| `UndefinedObject` / `UnusedAssign` | Liquid 正确性 |

---

## 10. ThemeCheckEvidence 写什么

`ThemeCheckEvidence` 是 §5 的必填字段。最少包含：

```
CLI: shopify 3.92.0（两次同版本）
Root: <StageDirRef>（after）/ <物化出来的 baseline 目录>（baseline）
BaselineMethod: archive@<BaseHeadSha>
ConfigLocked: .theme-check.yml 本次未变更 | 已强制两次使用 <BaseHeadSha> 版本
SuppressionAdded: 无
Cmd: shopify theme check --path <root> --output json
Before: 3334 errors / 1004 warnings
After:  3334 errors / 1004 warnings
blockers: []
addedInModifiedFiles: 0
addedOutsideModifiedFiles: 0
DeletedOrRenamed: 无 | <逐个 + §7 扫描结论>
ExitCode: 1（仓库存量 offense 导致，非判定依据）
```

缺 baseline 数字、缺 `addedInModifiedFiles` / `addedOutsideModifiedFiles`、缺 `blockers`、只写"通过" → 视为 `Evidence` 为空，`ThemeCheck` 降级为 `Blocked`。

---

## 11. 不得越权声明

`ThemeCheck: Passed` 的准确含义是：**静态 lint 在本次改动上无新增 offense。** 仅此而已。

禁止表述：「Shopify 兼容性全部通过」「theme check 全绿」「lint 没问题所以能上线」。

运行时行为 → `ThemeRuntimePreview`；视觉与断点 → `RegressionMatrix`；admin 后台 schema 保存（`step` / `max` / `range` 只有后台保存才校验）→ `AdminSchemaSave`。三者独立取值，静态检查一个都顶替不了。
