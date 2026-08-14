---
name: plaud-theme-impact
description: >
  PLAUD Shopify 主题矩阵的 Assess 阶段（order 2）：改动影响面侦察。
  用户问"改这个会影响什么""影响范围多大""blast radius""波及哪些模板/页面""依赖树""上下游调用方"
  "这个 snippet 谁在用""改共享 snippet / 全局 CSS / token 会不会炸全站""旧 section 有没有连带影响"
  "有多少实例""实例数""disabled 实例算不算""改动风险高不高""该动模板存值还是 schema 还是模块代码"
  时使用；Path A 改已有 section/snippet/CSS、Path B 新建 sa-* section 查复用面与冲突面、
  Path C UX 迁移前的 Blast Radius 与实例审计，都先过本 skill。
  产出 LegacyImpact / IntegrationSurface / InlineLite 三种 ReconMode 下的事实：
  理论引用数 vs 实际受影响实例清单、启用/disabled 实例分列、依赖树、共享传播链、
  token→class 全实例覆盖核查、dangling 引用核查、build 产物 vs 源文件区分、
  可选修改入口与各自风险、RiskTier、应跑的 QA profile。
  本 skill 只产出事实与证据命令：不改任何代码、不写 section、不做 UX 迁移、
  不下 RootCause 根因结论、不选实现方案、不做验收、不判定可交付、不批准模板存值编辑。
  不用于非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Impact（Assess 阶段）

**开工前必读**：`plaud-theme-shared/SKILL.md` + `plaud-theme-shared/references/handoff-schema.md`（尤其 §3 本 skill 的产出契约、§7 停机规则）。视觉/UX 数值一律引用 shared 的 reference 文件名，**本 skill 不复制任何数值**。

## 本 skill 做什么

只做一件事：**在动代码之前，把"这次改动到底会碰到谁"变成可复算的事实。**

- 建依赖树（section / block / snippet / schema / JS 继承链 / CSS 作用域）
- 分开报**理论引用**与**实际受影响实例**，后者必须带清单
- 单列 `disabled: true` 实例，不并入启用数
- 追共享 snippet / 全局 CSS / token / build 产物的传播链
- 列可选修改入口 + 各自风险
- 定 `RiskTier`，推荐 `RequiredQAProfile`
- 证据不足就停机要材料

## 本 skill 不做什么

- **不改任何文件**（不改 `sections/` `snippets/` `assets/` `templates/` `locales/` `config/`）
- **不下 `RootCause`** — 机制层根因是实现 skill（`plaud-theme-dev` / `plaud-theme-section-build` / `plaud-theme-ux-migration`）的字段
- **不选方案**、不写 `OptionsConsidered`、不推荐"应该怎么改"
- **不做验收**、不输出 `ReadyForDelivery`（那是 `plaud-theme-qa` 的唯一权限）
- **不批准模板存值编辑** — `templates/*.json` 默认只读，本 skill 只列出"动它"这个候选入口和它的风险，授权归用户

> 分界线的一句话版本：**本 skill 回答"会碰到谁"，实现 skill 回答"为什么坏 / 怎么改"。** 一旦你开始写"根因是……"或"建议改成……"，就已经越界了。

---

## 第一步 — 选 ReconMode

三选一，写进 `ReconMode`。定义以 `handoff-schema.md` §3 为准，此处只给判定流程。

**判据是「本次计划写入集」，不是当前 git diff。** Assess 发生在实现之前，此时工作树通常是干净的——用空 diff 推出 `IntegrationSurface` 是系统性误判。判定输入是：用户/上游给出的**预计新增文件**与**预计修改的存量文件**。

```
本次计划写入集是否包含以下任一？
  1. 任一存量 section / snippet / layout / template / section group
  2. 任一全局 CSS、design token、build 源或 build 产物
  3. 任一会改变存量消费方行为的 schema / locale / config 项
  ├─ 是 ────────────────────────────────────→ LegacyImpact
  └─ 否
      ├─ 纯新建（新 sa-* section / 新 asset），无存量调用方 → IntegrationSurface
      └─ 单文件 + 8 条豁免条件全满足 → InlineLite（需逐条自证）
```

注意第 1 条**不要求**"该文件被其它文件引用"——`layout/theme.liquid`、`templates/*.json`、section group 通常没有代码层引用方，但它们是运行时入口，改动一样是存量影响。

拿不到计划写入集 → `BlockingGaps` 写明"需要上游列出预计新增文件与预计修改的存量文件"，不要用空 diff 猜。

### 关键歧义：新建 section 顺手改了共享 snippet

Path B 场景最常见的误判。**只要计划写入集包含任何存量共享文件，模式就是 `LegacyImpact`，不是 `IntegrationSurface`——哪怕主体工作是新建一个 `sa-*` section。**

辅助核对（不是主判据，只用来发现计划外的漂移）：

```bash
git status --porcelain               # ?? / A = 新增；M = 修改存量（含未 staged）
git diff --name-only HEAD            # 含 staged 的存量改动清单
```

- 计划写入集全为新增文件 → `IntegrationSurface`
- 计划写入集含任何存量文件 → **`LegacyImpact`**：对存量文件走完整 LegacyImpact 流程，新建部分的复用面/冲突面检查照做，两套都要报
- 拿不准某个文件算不算存量影响 → 按 `LegacyImpact` 处理（保守方向永远是升级，不是降级）

**范围漂移必须退回重评**：Implement 阶段若开始修改任何原计划外的存量共享/入口文件，原 `AssessmentRef` 失效，必须重新 Assess——不得在实现收尾时补一句"顺便升级为 LegacyImpact"了事。

完整边界表（新 section 接入已有模板、locale 新增 key 等 10 个场景）见 `references/recon-modes.md`。

### InlineLite 豁免（严格）

**全部**满足才成立，任一条不满足或**拿不准**，就不是 InlineLite：

- [ ] 改动 ≤ 1 个文件
- [ ] 该文件无其它引用方（已用 grep 证明，不是"看起来没有"）
- [ ] 非共享 snippet
- [ ] 非全局 CSS（`critical.css` / `theme.css` / `base_more*` / design-system 类）
- [ ] 非 design token
- [ ] 非 build 产物（见 §「build 产物 vs 源文件」）
- [ ] 不改 schema
- [ ] 不改模板存值

> **拿不准就不是 InlineLite。** InlineLite 是"没什么可评估"的声明，不是"我懒得评估"的出口。豁免成立时，实现 skill 内联完成评估并在自己的 HandoffContract 写明 `ReconMode: InlineLite` + 豁免理由；本 skill 若被调用，仍要把上面 8 条的核查结果和 `EvidenceCommands` 交出去。

---

## 第二步 — 依赖树（Path A 最高频漏项）

**不靠文件名猜影响范围。** 七层，逐层给出实际查法。详细模式与变体见 `references/dependency-tree.md`。

| 层 | 查什么 | 命令骨架 |
|---|---|---|
| 1. section 本体 + block type | section 有哪些 block、哪些 layout 分支 | `grep -n '"type"' sections/<m>.liquid` |
| 2. render 的 snippets | 本 section 往下拉了谁 | `grep -nE "\{%-?\s*(render\|include)" sections/<m>.liquid` |
| 3. schema 选项 | 哪些 setting 会改变渲染分支 | `grep -nE '"id":|"type":|"default":' sections/<m>.liquid` |
| 4. snippet 的上游调用方 | 改的是 snippet 时，谁在用它 | `grep -rn "render '<snippet>'" sections/ snippets/ templates/ layout/` |
| 5. 循环内的资源输出 | 循环里输出 `stylesheet_tag` / `script_tag` 会重复 N 次 | `grep -nB 8 "stylesheet_tag\|javascript_tag" snippets/<s>.liquid` |
| 6. JS custom element 继承链 | 基类改动会波及所有子类 | `grep -rn "extends <Class>\|customElements.define" assets/*.js shopify-common/src/**/*.js` |
| 7. CSS 作用域与断点覆盖 | 类名在哪些文件被定义/覆盖、哪些断点有覆盖 | `grep -rn "\.<class-name>" assets/*.css shopify-common/src/**/*.scss` |

每一层都要**落成清单**，不是"已建依赖树"一句话。空层写"无"，不要省略。

### 真正加载的入口以 `layout/theme.liquid` 为准

同名/近名文件常有多份，改了没加载的那份 = 零影响也零修复。定位加载入口：

```bash
grep -nE "render|stylesheet_tag|javascript_tag|asset_url" layout/theme.liquid
```

依赖树里凡涉及全局 CSS/JS 的层，必须注明"加载的是哪一份"。

---

## 第三步 — 理论影响 vs 实际影响（本 skill 的灵魂）

> `TheoreticalReferences` 与 `ActualAffectedInstances` **必须分开报**。只报"可能影响 N 处"是不合格的 Assess。

四步收敛法（实测方法论出处：共享 section 接入配色方案的评估，表面 17 模板 + footer，实际仅 footer 一条线变化）。完整判定步骤与更多收敛维度见 `references/theoretical-vs-actual.md`。

### 3.1 理论引用数

```bash
grep -lr "\"type\": \"<module>\"" templates/ | wc -l        # 模板数
grep -c "\"type\": \"<module>\"" templates/*.json           # 每模板实例数
```

写进 `TheoreticalReferences`，并注明口径（模板数 / 实例数 / 调用点数，别混）。

**新建 section 不得虚构"模板使用量 N"**——没有存量调用方就是没有。`IntegrationSurface` 下如实写：

```yaml
TheoreticalReferences: "PreExistingCallers: 0; NewPlannedCallers: templates/page.xxx.json"
```

（字段名不变，只是值写清"存量调用方 0 + 计划新增的接入点"。若计划接入的是**已有**模板，模式应已升级为 `LegacyImpact`。）

### 3.2 扣除 disabled 实例

```bash
# 首选：结构化读取，不受缩进/嵌套影响
node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").replace(/^\s*\/\*[\s\S]*?\*\//,""));
for (const [id,s] of Object.entries(j.sections||{})) if (s.type==="<module>") console.log(id, s.type, !!s.disabled);' templates/<t>.json
# 预筛选（脆弱，仅用于快速扫一眼，不作为最终清单）
grep -B 1 '"disabled": true' templates/<t>.json | grep '"type"'
```

逐模板跑，汇总成清单。`DisabledInstances` **必须单列，不得并入 `ActiveInstances`**——disabled 实例不进影响面、不进对比表、不动 stored 值。剩下的是 `ActiveInstances`。

**口径限制**：`ActiveInstances = 理论实例数 − disabled 实例数` 只适用于**可从 template JSON 枚举的 section 实例**。目标是 snippet / 全局 CSS / token / layout / JS custom element / locale key 时，按**调用点数**或**消费点数**统计，并在字段值里注明口径（例：`ActiveInstances: 4 (render 调用点数，非模板实例)`）。

### 3.3 逐项判断"是否真触发"

对每个启用实例，问三个问题（任一为"否"即从实际影响里剔除，并在清单里写明剔除理由）：

1. **这个实例真的走到被改的代码分支了吗？** —— 被改的是某 `{% if %}` 分支 / 某 block type / 某 schema 开关下的路径时，实例的 stored 值决定它是否进入该分支。查实例存值：
   ```bash
   # 首选：结构化读取（awk 范围匹配遇嵌套 blocks/settings 会提前截断）
   node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").replace(/^\s*\/\*[\s\S]*?\*\//,""));
   console.log(JSON.stringify(j.sections[process.argv[2]],null,2));' templates/<t>.json <instance-id>
   ```
2. **这个实例的元素真的挂了被改的那个钩子吗？** —— 改的是 CSS 变量/颜色类/utility 时，只有**挂了对应类名**的元素才跟随；写死 hex、内联 `style="…"`、只挂非相关类（间距/对齐类）的元素完全不受影响。
3. **改动前后的计算值真的不同吗？** —— 变量重绑但新旧同值 = 零视觉差（例：默认配色方案值已与 spec 同值，只有被自定义过的方案才偏移）。空值/缺省的继承行为也要查清（例：空 `color_scheme: ""` 会落到 `:root` 上挂的 default 方案，不是"无方案"）。

### 3.4 输出实际影响

`ActualAffectedInstances` = **数字 + 清单**。清单每行：`模板 : 实例 id / type : 变化描述`。只给数字视为不合格。剔除项另列一段「已核查排除」+ 理由，让 QA 可复算。

---

## 第四步 — 共享 / 全局改动的传播链（用户点名的漏项）

写进 `SharedPropagation` 与 `LegacyImpact` 两个字段。详细清单见 `references/shared-propagation.md`。

### 4.1 共享 snippet 的 blast radius 远大于单个 section

`product-item.liquid`、`price.liquid`、`buy-buttons.liquid`、`product-badges.liquid` 这类共享 snippet 被多处 render，改一处波及集合页、搜索页、推荐位、mega 菜单等**互不相邻的上下文**。

```bash
grep -rn "render '<snippet>'" sections/ snippets/ templates/ layout/
grep -rn "render \"<snippet>\"" sections/ snippets/ templates/ layout/
```

调用方之间常有**上下文参数差异**（同一 snippet 在不同调用点传不同参数，走不同分支）。必须把每个调用点传的参数列出来，判断改动落在哪些上下文。

### 4.2 token → class 重构必须全实例覆盖

把共享 class 的 spec 值从组件 CSS 移到 HTML utility 类时，**未迁移的实例会静默丢样式**（字号回退继承、内距归零），且常在其它分支 / 其它 snippet 里，肉眼看不到。这是真实发生过的回归源。

强制顺序：

```bash
# ① 全仓找出所有 markup 实例（先找全，再谈剥离）
grep -rn 'class="[^"]*<class-name>' sections/ snippets/ templates/ layout/ shopify-common/
# ② 逐一确认每个实例都已挂等价 utility —— 全覆盖前不得剥 CSS 声明
# ③ 剥完回归验证
```

本 skill 的产出是**①的完整实例清单 + 每个实例当前是否已挂等价 utility 的核查结果**。清单不全就不要说"可以剥"。

### 4.3 删除类改动必须全仓查 dangling 引用

删 schema 字段 / CSS 变量 / `data-*` 属性后，残留引用会静默失效：

```bash
grep -rn "var(--<var-name>)" assets/ shopify-common/ sections/ snippets/
grep -rn "settings\.<field>\|block\.settings\.<field>\|section\.settings\.<field>" sections/ snippets/ templates/
grep -rn "dataset\.<camelName>\|data-<kebab-name>" assets/ sections/ snippets/ shopify-common/
```

三条都要跑，命中即列为 dangling 风险项。`RiskTier` 不得低于 Medium。

### 4.4 build 产物 vs 源文件

改错层 = 下次 build 覆盖 / 与源分叉。

- **源**：`shopify-common/src/**`、`sections-*/**` 下的 `.scss` / `.liquid` / `.js` —— 改这里，需 `npm run build`
- **产物（勿手改）**：`snippets/design-system.liquid`、`assets/sectionsTT.min.css`、`assets/base_more.css` 等

判定命令：

```bash
grep -rn "<被改的类名或变量>" shopify-common/src/ 2>/dev/null   # 命中 → 源在这里，产物是编译输出
```

在 `SharedPropagation` 里**作为事实注明**：改动落在源还是产物、是否触及 build 源因而需要执行 build、以及**实际加载的是哪一份**（以 `layout/theme.liquid` 为准，同名文件可能有多份）。

> `BuildRequired` 是 §4 的字段，由实现 skill 填写。本 skill 只给"触及 build 源"这个事实，**不代填该字段、不在输出块里写 `BuildRequired`**。

### 4.5 旧 section / 旧类名 / 旧断点的连带影响

写进 `LegacyImpact`：旧模块保留的旧类名是否仍被其它地方消费、旧断点值（非 `.98` 精度的杂散断点）是否与新改动冲突、旧控件 DOM 是否还有残留消费方。

---

## 第五步 — EntrypointCandidates（只列候选，不做授权决定）

按 `handoff-schema.md` §3 输出 `EntrypointCandidates`：三层各自的适用场景、风险和影响范围。

| 层 | 影响范围 | 风险 | 前置 |
|---|---|---|---|
| 模板存值（`templates/*.json` 实例值） | 仅该模板该实例 | 低 | `templates/*.json` 默认只读，实际编辑需用户明确批准 |
| schema 配置（section liquid 内 schema） | 该模块所有**新建**实例；旧 stored 值不变但需向后兼容 | 中 | — |
| 模块代码（liquid / SCSS / JS） | 该模块**所有命中该路径的现存实例** | 高 | 可能触发 build |

每个候选只报**事实**：要改哪类文件、波及哪些既有/新建实例（引用已核实的清单）、是否需要模板授权、是否产生向后兼容要求、是否触及 build 源、当前还缺哪些证据。

**禁止措辞**：推荐、建议、倾向、最稳、应该选、直接锁定、根本性修复。选哪层由实现 skill 与用户决定。

**授权与停机的关系**（不要过度阻塞）：仅当以下任一成立时，模板授权才进 `BlockingGaps` 并置 `ReadyForImplement: No` ——

1. 用户已指定模板存值为目标入口
2. 其他入口已被事实排除，模板存值是唯一可行入口
3. 完成本次 Assess 所需的 stored 值本身读不到
4. 上游要求评估实际的模板修改，但未授权读取/编辑目标文件

模板存值**只是三个候选之一**时，在该候选条目里注明"需用户批准"即可，**不因此单独令 `ReadyForImplement: No`**。

---

## 第六步 — RiskTier 与 RequiredQAProfile

### RiskTier

判定顺序（**先 High、再 Medium、最后才 Low**）：

| Tier | 判定规则 |
|---|---|
| **High** | **任一**命中：改共享 snippet / 全局 CSS / design token / build 源里的共享组件或全局样式；token→class 重构；`ActualAffectedInstances` > 10；JS 基类或继承链；pub/sub 事件名或 payload 变更；跨路径交叉（B+C、A+C）；`ActualAffectedInstances` 无法逐项核实清 |
| **Medium** | 未命中 High，且**任一**命中：`ActualAffectedInstances` 2–10；改 schema；改单个 section 的共享行为；存在待核 dangling 引用；改 build 源里仅作用于单模块的 scoped 样式/脚本；改动落在 critical bundle |
| **Low** | **全部**满足：单文件；已 grep 证明无其它引用方；`ActualAffectedInstances` ≤ 1；不碰 schema / token / 全局 CSS / build 源或产物 / JS 基类；且该文件不是运行时入口（`layout/*.liquid`、已有 `templates/*.json`、已有 section group JSON） |

Low 是"全部满足"而非"任一命中"——否则"只改一个文件"就能把全局 CSS 判成 Low。

`ActualAffectedInstances` 因证据不足而无法收敛时 → **High + `BlockingGaps` 非空 + `ReadyForImplement: No`**，不得用"估计不大"降档。

### RequiredQAProfile

§3 该字段的取值只能是 `QA-A` / `QA-B` / `QA-C`（可多选）：

- Path A（改已有模块 / bug / 性能 / A11y）→ `QA-A`
- Path B（纯新建 `sa-*`）→ `QA-B`
- Path C（UX 迁移）→ `QA-C`
- 交叉场景多选：B 主体但计划写入存量共享文件 → `QA-A, QA-B`；A+C → `QA-A, QA-C`

RiskTier High 时，至少追加 `QA-A`（同族 bug 扫描 + 依赖树回归 + 旧 section 连带影响）。

> **`QA-Global` 不写进 `RequiredQAProfile`。** 它是 §5 规定的 Verify 阶段恒执行项，由 `plaud-theme-qa` 自动叠加，与路径无关；把它塞进 §3 的枚举值是字段越界。正文里可以提醒"QA-Global 恒执行"，字段值里不要出现。

---

## 第七步 — 停机点（Stop, don't guess）

以下任一成立 → `BlockingGaps` 非空 + `ReadyForImplement: No`，并明确写出**需要用户提供什么**。不要输出半成品再附一句"可能需要确认"。

- 找不到目标 section / snippet / asset 的实际文件 → 要路径
- 需要编辑 `templates/*.json` 存值（按第五步四条判定，**不是"只是列为候选"**）→ 要授权
- 拿不到本次计划写入集（预计新增文件 + 预计修改的存量文件）→ 要清单，不得用空 git diff 推 `IntegrationSurface`
- 证据不足以区分理论影响与实际影响（拿不到模板存值、拿不到实例配置、grep 无法判定分支是否触发）→ 要材料
- 仓库不是 theme root，或 `templates/` / `shopify-common/` 不可读 → 要正确的仓库路径
- 同名文件多份且无法确定 `layout/theme.liquid` 加载哪份 → 要确认
- 依赖 `memory/模板清单.md` / `memory/模块清单.md` 但文件缺失 → 停下问用户，**不得凭空重建**（会与真实迁移进度脱节）
- 🔴 **`memory/` 下出现了不该有的东西**：`memory/` **不在可发布面**（可发布面只有 `assets` / `blocks` / `config` / `layout` / `locales` / `sections` / `snippets` / `templates` + `.shopifyignore`，见 `plaud-theme-shared/references/handoff-schema.md` §2），所以那里的文件**不会上线**、也不进 `ThemeTreeOid`。判据因此不是"指纹看不见所以危险"，而是：**不在可发布面 = 不会上线；如果它真的会上线，说明这个文件目录放错了。** 📎 v0.2.2 这里写的是"指纹盲区"，v0.3.0 改成可发布面口径——**核对命令与停机结论一个字都没变**。开工前跑这两条，**任一有输出即停机**，不要自行判断"应该没事"：

  ```bash
  # ① memory/ 下只应有记录类 .md。有非 .md 文件 → 多半是目录放错了（它不会上线）
  find memory -type f ! -name '*.md' 2>/dev/null
  # ② 主题可发布目录不应引用 memory/ 下的任何东西
  grep -rn "memory/" assets blocks config layout locales sections snippets templates 2>/dev/null | grep -v '\.md'
  ```

---

## 证据纪律

`EvidenceCommands` 必须是**实际跑过的命令原文**，供 QA 复算。规则：

- 写命令原文 + 关键输出摘要，不写"已 grep"
- 每个数字（`TheoreticalReferences` / `ActiveInstances` / `DisabledInstances` / `ActualAffectedInstances`）都要有对应命令
- 没跑过的命令不得写进 `EvidenceCommands`
- grep 无命中也是证据，照写（`# 0 results` 也是结论）

---

## Reference 索引（按需加载，不要全读）

| 何时读 | 文件 |
|---|---|
| 三种模式边界拿不准 / 新建但改了共享文件 | `references/recon-modes.md` |
| 建依赖树、需要各层完整 grep 模式 | `references/dependency-tree.md` |
| 收敛实际影响、判断实例是否真触发 | `references/theoretical-vs-actual.md` |
| 改共享 snippet / 全局 CSS / token / build 产物 | `references/shared-propagation.md` |
| 定 RiskTier、选 QA profile、列修改入口 | `references/risk-and-entrypoints.md` |
| 与上下游 skill 的交接 | `matrix-contract.md` |

视觉与 UX 数值（字号 / 颜色 / 间距 / 断点）**不在本 skill**，在 `plaud-theme-shared/references/` —— 需要时引用文件名，不复制数值。

---

## 输出契约

正文可自由组织（依赖树、实例清单、传播链、入口对比表），但**回复的最后必须是一个 `yaml` 代码块**，字段与 `handoff-schema.md` §3 一字不差，不得增删改名：

```yaml
AssessmentRef:            # ASMT-<YYYYMMDD>-<NN>
ReconMode:                # LegacyImpact | IntegrationSurface | InlineLite
TargetSubject:            # 被改的 section / snippet / asset / token 名
TheoreticalReferences:    # 理论引用数（grep 命中的模板/文件数）
ActiveInstances:          # 启用实例数
DisabledInstances:        # disabled: true 的实例数（必须单列，不得并入 Active）
ActualAffectedInstances:  # 逐项核查后真正会触发变化的实例数 + 清单
SharedPropagation:        # 共享 snippet / 全局 CSS / token / build 产物的传播链
LegacyImpact:             # 旧 section / 旧类名 / 旧断点 的连带影响
EntrypointCandidates:     # 可选修改入口（模板存值 / schema / 模块代码）+ 各自风险
RiskTier:                 # Low | Medium | High
RequiredQAProfile:        # QA-A | QA-B | QA-C（可多选）
EvidenceCommands:         # 实际跑过的 grep/ls/node 命令原文，供 QA 复算
BlockingGaps:             # 缺失且必须由用户补的证据；非空则不得进入 Implement
ReadyForImplement:        # Yes | No
```

**不得**在这个块里出现 `RootCause`、`OptionsConsidered`、`ChangeSetId`、`ReadyForDelivery`、`QAStatus` —— 那些是 Implement / Verify 阶段的字段。
