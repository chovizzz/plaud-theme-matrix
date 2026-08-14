---
name: plaud-theme-dev
description: >
  PLAUD Shopify 主题 Path A 通用开发（Implement 阶段，order 3）：bug 修复、性能优化、
  新功能、UX 微调。用户说改 Plaud 主题 bug、修 Swiper、
  swiper cards/cube 图不加载、点击触发多次、下拉被 overflow 裁切、移动端样式不生效、
  inline style 覆盖媒体查询、弹窗 popup、drawer、custom element 泄漏、
  disconnectedCallback 没清理 timer/observer、DOMParser 重复创建、循环里输出
  stylesheet_tag、图片没 width/height 导致 CLS、lazy-load 与 Swiper effect 冲突、
  组件写死宽高需要适配、给某个 section 加个新功能/新开关；
  以及**零改动（没有 ChangeSetId）**的只读 code review /
  A11y 无障碍审计 / 对比度、aria-label、focus-visible 审计——
  **用户要不要"最终交付判定"都不改变归属**：零改动没有 ChangeSet 可绑，
  plaud-theme-qa 结构上接不了、会原样转回来（v0.2.2 第八轮修掉的 dev↔QA 回环）；
  此时按 §2 只读通道出 ReadOnlyProof，ReadyForDelivery 填 N/A(ReadOnly) 并说明
  "零改动不存在交付判定"。已有 ChangeSetId（即有改动）→ 走 plaud-theme-qa-intake（提测准入），由它放行到 plaud-theme-qa。
  只要是 Plaud 主题（plaudRelease、plaudAsen、
  PLAUD SG、shopify-plaud-sg-test 等仓库）的 sections/snippets/assets/Liquid/CSS/JS
  改动且不属于 Path B / Path C，就用本 skill。
  本 skill 只做 Orient / Decide / Act（根因、方案、最小实现），
  不做影响面事实收集（那是 plaud-theme-impact），也无权宣布可交付（那是 plaud-theme-qa）。
  不适用：Figma / 设计稿 / 新建 sa-* section → plaud-theme-section-build；
  UX Spec v1.3 迁移 / 刷模块 / 对齐 ux / 迁移日志 → plaud-theme-ux-migration；
  非 Plaud 主题、Hydrogen/headless、Shopify App/Admin/Checkout Extension、WooCommerce。
---

# PLAUD Theme Dev（Path A · Implement）

Path A 的实现层。**输入**是 `plaud-theme-impact` 的 Assess 工件，**输出**是一批已就位、待 QA 的改动。

## 🔴 开工前两条硬约束

**一、终态措辞禁令（`plaud-theme-shared/references/handoff-schema.md` §1）**

> 你**无权**宣布任何东西可交付。改完只能说：**「改动已就位，待 QA」**。

**这是语义级禁令，不是关键词黑名单。**根本规则：

> 在回复的**任何位置**，不得断言本次改动的**正确性、稳定性、可用性、验证结果、验收状态，或合并 / 部署 / 发布资格**。你只能陈述：**做了什么**、**为什么这么做**、**待验证什么**。

因此以下全部禁止，换说法也一样禁止：「修好了」「已修复完成」「问题已解决」「功能已恢复正常」「可以上线」「上线可用」「已具备上线条件」「达到发布标准」「生产就绪」「可以合并 / 部署 / 发布」「剩下只需发布操作」「全部通过」「回归都过了」「验证无误」「测试没问题」「风险已清零」「无需进一步检查」「QA 可以直接放行」「验收条件均已满足」「已验收」「没问题了」「应该没问题」。
同样禁止**完成度声明**——「开发完成」「实现结束」「代码已经齐了」「不用再改了」「无需继续修改」：它们不需要验证就能为真，却同样暗示终态。允许的等价表述是「本次 ChangeSet 的改动已落地」。

判别法两条，任一命中即不能说：
1. **这句话如果为真，需要有人执行过验证吗？** 需要 → 不能说。
2. **这句话是否暗示"这件事到此为止了"？** 是 → 不能说；终结权在 `plaud-theme-qa`。

输出块里 `QAStatus` 恒为 `NotRun`、`ReadyForDelivery` 恒为 `No`（唯一变形是零改动只读任务的 `ReadyForDelivery: N/A(ReadOnly)`，见「只读任务的契约变形」）。
用户明说"不用检查直接给我"时，仍输出 `ReadyForDelivery: No`，把 `QAStatus` 写成 `Skipped(UserWaived)`（此取值由 `handoff-schema.md` **§1.5 明文授权**，不是自造），并一句话说明风险由用户承担。

**二、必读契约**

开工前先读 `plaud-theme-shared/references/handoff-schema.md`（尤其 §1 交付权、§3 Assess 工件、§4 你的输出契约、§7 停机规则、§8 全路径红线）。
其余 shared reference **按需加载**，不要全读：改一个 JS timer 不需要字阶表。

| 本次任务涉及 | 加载 |
|---|---|
| JS / custom element / Swiper / 主题架构速记 | `plaud-theme-shared/references/javascript-swiper.md` |
| Liquid / schema / 文案配置 / 文件格式 | `plaud-theme-shared/references/liquid-schema-format.md` |
| 无障碍审计 | `plaud-theme-shared/references/a11y.md` |
| 图片 / 视频清晰度与懒加载 | `plaud-theme-shared/references/media-quality.md` |
| 字号 / 字阶 | `plaud-theme-shared/references/typography.md` |
| 颜色 token / 配色 | `plaud-theme-shared/references/colors-and-schemes.md` |
| 断点 / 间距 / 容器宽度 | `plaud-theme-shared/references/responsive-and-spacing.md` |

**所有视觉数值（字号、颜色、间距、断点、圆角、按钮尺寸）、Swiper effect 约束表、主题架构速记的唯一副本都在 shared。**本 skill 只引用，不复述——复述会造成双事实源，spec 一升级必然漂移。

---

## 本 skill 的职责边界

| | 谁负责 |
|---|---|
| Observe（影响面事实：引用数、实例数、传播链、入口候选、风险等级） | `plaud-theme-impact` |
| **Orient（机制层根因）** | **本 skill** |
| **Decide（≥2 方案 + 取舍）** | **本 skill** |
| **Act（最小化实现）** | **本 skill** |
| Verify（Theme Check、回归、断点、多语言、A11y、交付判定） | `plaud-theme-qa` |

覆盖任务类型：**bug 修复 / 性能优化 / 新功能 / UX 微调 / code review / A11y 审计**。

**不属于本 skill：** Figma 设计稿转 `sa-*` section → `plaud-theme-section-build`；UX Spec v1.3 迁移 / 刷模块 / 对齐 ux → `plaud-theme-ux-migration`。判不准时按 shared SKILL.md 的路径判定树走。

---

## 第一步：拿到 Assess 工件

**没有 Assess 工件、又不满足 `InlineLite` 豁免 → 停机。** 不要"先改了再说"，也不要自己顺手 grep 一遍就当评估做完了。

### 读 `AssessmentRef` 的哪几个字段，怎么用

| 字段 | 你据此决定什么 |
|---|---|
| `ActualAffectedInstances` | **改哪一层**。真实影响 1 处 → 可在模块代码锁死；影响多处 → 必须让改动对未点名实例保持行为不变（新增可选参数 / 默认值保持旧行为 / 加作用域类），否则回到 Decide 重出方案 |
| `TheoreticalReferences` vs `ActualAffectedInstances` 的差 | 差值大说明多数引用是死路径或 disabled 实例——**不要按理论数去做防御性大改**，那是过度工程 |
| `DisabledInstances` | 这些实例不验证、不动其 stored 值、不作为方案取舍依据 |
| `SharedPropagation` | 命中共享 snippet / 全局 CSS / token / build 产物 → 禁止在共享层做单点特判；改动须在共享层语义上自洽。命中 build 产物 → `BuildRequired: Yes`（红线 §8.7：改源不改产物） |
| `LegacyImpact` | 旧 section / 旧类名 / 旧断点是否连带。有连带 → 方案必须点名说明旧路径怎么处理（保留 / 迁移 / 明确不管） |
| `EntrypointCandidates` + 各自风险 | 候选入口不是让你随便挑：**低风险优先，需要改 `templates/*.json` 存值的入口默认不可用**（模板存值默认只读，未获授权 → `BlockingGaps` 停机） |
| `RiskTier` | `Low` → 可直接 Act；`Medium` → 必须走完 OODA 并等用户确认方案；`High` → 方案必须含回滚方式，且明确列出需要浏览器预览的点 |
| `RequiredQAProfile` | 原样带进你的输出块（Path A 恒含 `QA-A`）。🔴 **不得写 `QA-Global`**——它由 `plaud-theme-qa` 按 §5 恒执行，写进本字段是字段越界（`handoff-schema.md` §9.2） |
| `BlockingGaps` | 非空 → **不得进入 Implement**。先把缺口交回用户/impact |

### `InlineLite` 豁免（唯一可跳过 Assess 的口子）

条件在 `handoff-schema.md` §3，必须**全部**满足：改动 ≤ 1 个文件、该文件无其它引用方、非共享 snippet / 非全局 CSS / 非 token / 非 build 产物、不改 schema、不改模板存值。

这是**窄口**，不是默认路径。**默认答案是"走 impact"**；InlineLite 需要被主动证明，证明不了就不适用。

### 正向白名单（不在表内 = 不是 InlineLite，不必再论证）

只有以下三类可能适用：

| 允许类 | 说明 |
|---|---|
| **纯文档 / `.md` 改动** | 不进入主题渲染，不产生任何运行时行为或渲染差异 |
| **单个私有 snippet 的排版符号修正** | 该 snippet 恰好有 **1 个已知调用方**；且改动**只动动态输出周围的排版符号 / 空白 / 标点**，不动 schema、不动 JS 钩子、不改类名。**改的若是硬编码的 storefront 展示文案字面量 → 不适用**：那本身违反红线 §8.1，正确处理是迁到 schema / locales，属于需要 Assess 的改动 |
| **单个 section 私有 CSS 文件内的局部样式修正** | 选择器完全落在该 section 的 BEM 根类作用域内，不含全局选择器、不含被其它文件复用的类名、不改 token |

其余一律走 `plaud-theme-impact`。特别地，以下**永远不是** InlineLite，即使只改一行、即使只改注释：任何 `.liquid` 的结构 / 逻辑 / schema 改动、**任何运行时 JS 文件（含只改其中的注释）**、custom element（含其基类与继承链任一环）、Swiper 初始化参数、`locales/`、`config/`、`templates/`、全局 CSS、token、build 产物、任何新功能、任何性能优化。

**黑白名单冲突时，黑名单优先。**"这是注释所以安全"不能推翻文件所在类别的判定。

### 必须固定跑的证据维度（缺一条 = 不成立）

"无其它引用方"不是印象，也不是"随便 grep 一下 0 命中"。**注意：私有 snippet 的正确判据是「恰好 1 个已知调用方」，不是 0 命中**——搜出 0 命中通常说明搜索词选窄了，那是伪证据。

**搜索范围固定为整个主题根目录**（至少覆盖 `sections/ snippets/ assets/ templates/ layout/ config/ locales/`），用 `grep -rn`，**不得只搜当前目录、不得只搜单个文件类型**。pattern 用**去扩展名的 basename**而非全路径（全路径搜不到按名引用），命中后逐个打开确认。

逐条跑并把**命令原文 + 命中数**写进 `ReconMode` 的豁免理由：

1. 文件全路径引用
2. basename / 去扩展名（Shopify `render` / `include` / `section` 按名引用）
3. section type 名（是否被 `templates/*.json`、section group、layout 接入）
4. asset URL 引用（`asset_url` / `stylesheet_tag` / `script_tag`）
5. custom element 标签名与类继承链（若文件含 JS）
6. 改动涉及的核心 CSS 选择器 / 类名（是否被其它文件消费）
7. 动态拼接引用（变量拼 snippet 名 / asset 名的写法）

任一维度出现预期外命中 → 不是 InlineLite，走 impact。

### 其它纪律

- **拿不准就不是 InlineLite** —— 只要需要"想一下应该没别的地方用吧"，就不是。
- 单文件 ≠ 低传播。共享类名、继承、全局选择器都会让"一个文件"产生跨实例影响。
- **同一会话内最多用一次**（提醒性护栏，不是主门；主门是上面的白名单 + 七维证据）。本次改动若是上一次 InlineLite 的延伸或返工，一律走 impact——连续 InlineLite 是绕过 Assess 的典型形态。
- 用了豁免就必须写 `ReconMode: InlineLite` + **白名单归类 + §3 五个条件逐条对照 + 七维证据命令原文**。写不满 → 说明它本来就不该走豁免。

---

## 第二步：OODA 门控

非平凡任务必须走完 **Observe → Orient → Decide → Act**，且 **Act 前等用户确认方案**。

### 什么算"平凡"（判据，不留解释空间）

**同时满足全部**才算平凡，可直接 Act：

1. 改动 ≤ 1 个文件且 ≤ 约 10 行；
2. 根因当场可见、无需推断（如明显 typo、漏了 null 守卫、少写一个 aria-label）；
3. `RiskTier: Low`；
4. `ActualAffectedInstances` ≤ 1；
5. 不改 schema、不改模板存值、不改共享 snippet / 全局 CSS / token / build 产物；
6. 不改变任何组件的公开行为（DOM 结构、事件、schema 字段、CSS 类名契约都不变）。

**只要有一条不满足，就是非平凡**，必须走 OODA 并等确认。特别地，以下**恒为非平凡**，不论行数多少：新功能、性能优化、任何 Swiper effect 相关改动、任何 custom element 生命周期改动、任何触及共享层的改动、`RiskTier` 为 `Medium`/`High`。

平凡任务在输出块里 `OptionsConsidered: Trivial`，并在正文一句话说明为什么落在平凡判据内。

### 四步各自要产出什么

- **Observe** — 不重做 impact 的工作。这里只是把 Assess 工件的结论 + 目标文件当前实际代码摆出来。找不到目标文件 → 停机要路径（§7）。
- **Orient** — **机制层根因，不是表面症状**。"移动端没生效"不是根因，"inline style 优先级高于媒体查询"才是。判别方法：根因必须能解释"为什么在 A 条件下坏、B 条件下好"，且能预测同族 bug 出现在哪里。写不出这个预测，说明还停在症状层。
- **Decide** — **至少 2 个方案**，每个写清：改哪一层、影响范围、代价/风险、为什么选/不选。只有一个方案时不要凑数编第二个，而是应当承认这是"约束已经把解唯一确定"，并写清是哪个约束——但这种情况极少，多数时候第二方案是"在更上游的层改"。方案取舍受 `EntrypointCandidates` 风险排序约束。
- **Act** — **最小化实现**。不顺手重构、不顺手改格式、不扩散到 `ModifiedFiles` 之外的文件。发现的其它问题写进正文的"顺带发现"，不动手。

---

## 第三步：按任务类型执行

详细步骤见 `references/task-workflows.md`（按本次任务类型只读对应一节）。要点索引：

| 任务类型 | 核心纪律 |
|---|---|
| **性能优化** | 恒非平凡。高频项：DOMParser 复用、timer/observer/监听/subscription 在 `disconnectedCallback` 清理、图片 `width`/`height` 防 CLS（清晰度红线见 shared `media-quality.md`）、循环内 snippet 不重复输出 `stylesheet_tag`、懒加载与 Swiper effect 的兼容性（**具体哪些 effect、怎么处理，一律现查 shared `javascript-swiper.md`，不得凭记忆改参数**） |
| **新功能** | 恒非平凡。OODA → PRD（≥2 方案）→ **用户确认** → 实现。**未经用户确认不得直接编码** |
| **Bug 修复** | 根因 → 最小修复 → **同族扫描**（一个 bug 常伴 3–5 个同族），见 `references/bug-family-scan.md` |
| **UX 微调** | CSS 变量桥接、overflow / z-index 链路检查、对比度（红线 §8.5） |
| **code review / A11y 审计** | **只读任务**，不改代码。输出问题清单 + 严重度 + 建议改法。`ModifiedFiles: []`、`ChangeSetId: N/A` |

### 只读任务（零改动）的契约变形 —— 全部取自 `handoff-schema.md` §2「零改动任务」

**无 `ChangeSetId` 的只读审计（code review / A11y 审计）归本 skill**，不归 `plaud-theme-qa`——QA 的触发前提是「已有 `ChangeSetId`」或「用户明确要最终交付判定**且该任务确有改动**」。🔴 零改动时用户要「最终判定」也不转 QA（v0.2.2 第八轮修的 dev↔QA 回环）：直接答复「零改动没有 ChangeSet 可绑，不存在交付判定」，出 `ReadOnlyProof` + `ReadyForDelivery: N/A(ReadOnly)` 收尾。

| 字段 | 只读任务取值 |
|---|---|
| `ChangeSetId` | `N/A` |
| `BaseHeadSha` / `ObjectFormat` / `ThemeTreeOid` / `ChangeSetScopeFingerprint` | `N/A` |
| `ReadOnlyProof` | **必填**，见下 |
| `AssessmentRef` | `N/A(ReadOnly)` |
| `ReconMode` | `N/A(ReadOnly)` |
| `ModifiedFiles` | `[]`（不要留空 scalar） |
| `ThemeCheckRequired` / `VisualRegressionRequired` / `BuildRequired` | `No` |
| `OptionsConsidered` | `Trivial` |
| `QAStatus` | `NotRun` |
| `NextRequiredSkill` | `None`（零改动免 QA） |
| `ReadyForDelivery` | `N/A(ReadOnly)` |

> 🔴 **只读任务不得借用 `ReconMode: InlineLite`**（`handoff-schema.md` §2）。InlineLite 是"改动小到可以内联评估"，只读是"根本没有改动"，两者不是一回事；混用会让只读任务继续输出 `QAStatus: NotRun` / `ReadyForDelivery: No`，与本表冲突。只读任务的 `ReconMode` 一律 `N/A(ReadOnly)`，也**不需要**跑 InlineLite 的七维证据。

#### 🔴 零改动必须有证明（`ReadOnlyProof`）

否则可以先改代码、再输出 `ModifiedFiles: []` 并声称"这只是审计"，从而完全绕开 QA。**审计开始前和结束后各取一次快照，两次必须完全一致**：

```bash
# 🔴 用 handoff-schema §2.5 的 plaud_theme_tree，整段原样复制（含 _plaud_* 内部函数与注释）。
# 原样抄这两行，不要写成 `plaud_theme_tree || echo "..."` —— 那样打印了错误串却让整段 rc=0。
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }   # 审计开始前
# …… 执行审计 ……
plaud_theme_tree || { echo "THEME_TREE_FAILED"; exit 1; }   # 审计结束后
```

> 🔴 **不要用 `git status --porcelain | shasum` 做这个快照**（v0.2.2 第五轮修）：它只含状态码与路径、不含内容。工作树**一开始就 dirty** 时，审计中改**同一个文件的内容**，前后两次 hash **完全相同**（已实测复现）——那正好是本节要堵的"先改代码再声称只读"，旧命令堵不住。`ThemeTreeOid` 是可发布内容的 tree oid，改内容必然变。

🔴 **判据是两次的 `ObjectFormat` + `ThemeTreeOid` 逐字相等，不比 HEAD。** v0.3.0 起 HEAD 不进身份：审计期间别人 commit 会让 HEAD 变而内容没变，按旧写法会把一个真正的只读任务误判成非只读。`ReadOnlyProof` 里如实登记两次的 `ObjectFormat` + `ThemeTreeOid`，以及取快照时的 `BaseHeadSha`。

📎 **v0.3.0 的一处语义收窄，必须知道**：`ThemeTreeOid` 只覆盖**可发布面**。「只读审计期间改了 `src/` 下的 build 源、但没跑 build」这种情形两次会相等——这不是漏洞而是定义（build 源不上线）；一旦跑了 build、产物落进 `assets/`，就会被立刻抓到。只读通道的措辞禁令照旧：审计 skill 本来就不该动任何文件。

**两次不一致 = 这不是只读任务**：立即退出只读通道，生成正式 `ChangeSetId` + `BaseHeadSha` + 三元组，走完 Assess → Implement → Verify。不得以"只是顺手改了一点"为由留在只读通道里。

**不免措辞禁令**：审计结论只能陈述"发现了什么"，不得断言"这个模块没问题 / 可以上线"。
若审计后用户要求真的动手改，那是**新的一次 Implement**，重新生成 `ChangeSetId` 走完整流程。

---

## 第四步：输出

正文按 Path A 模板组织（完整模板与写法见 `references/output-template.md`）：

```
## 依赖树
（来自 Assess 工件；标明哪些是 impact 报的、哪些是本次新发现）

## 根因（Orient）
（机制层，不是症状）

## 方案（Decide）
（≥2 方案 + 取舍；平凡任务写 Trivial 及判据依据）

## 待 QA 验证的点
（列出该验什么，不写验证结果）

## 改动清单（Act）
（文件 + 一句话）
```

> **「待 QA 验证的点」不是回归矩阵结果。**你只负责标明"该验什么"——覆盖哪些 layout mode / schema 选项 / block type / Swiper effect / 关键开关，需要哪几个断点、要不要浏览器预览、要不要英译德长文案检查、要不要 admin schema 保存验证。**具体断点档位、长文案语种规则见 shared reference 与 `handoff-schema.md` §5，不在此复制。**每一项写成"待验：…"，禁止写成"已验证 / 通过 / 无异常"。

---

## 停机点（`BlockingGaps` 非空则不得继续）

- 找不到目标 section / snippet / asset 的实际文件 → 停，要路径
- 拿不到 Assess 工件且不满足 `InlineLite` → 停，先做 Assess
- Assess 工件的 `BlockingGaps` 非空 → 停，先补齐
- 需要编辑 `templates/*.json` 模板存值但未获授权 → 停，要授权
- 方案需要用户拍板（≥2 方案取舍、非平凡任务、新功能 PRD）→ 停，等确认再编码
- 需要浏览器预览才能确定行为但无法预览 → 停/标明，**不猜"应该没问题"**
- 改动会触及共享层但 Assess 未覆盖该传播链 → 停，回 impact 补

停机时输出 `BlockingGaps` 并明确写出**需要用户提供什么**，不要输出半成品再附一句"可能需要确认"。

---

## 交付工件时**当场**生成身份三元组（`handoff-schema.md` §2）

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

零改动（只读）任务这四个字段（`BaseHeadSha` + 三元组）填 `N/A`，改填 `ReadOnlyProof`——**不得**反过来伪造一次 tree 身份来替代零改动契约。

## HandoffContract（回复的最后必须是这个 yaml 块）

字段取自 `plaud-theme-shared/references/handoff-schema.md` §4，**字段名与顺序一字不差**，不得改名、不得省略、不得自造。

```yaml
ChangeSetId:              # CS-<YYYYMMDD>-A<NN>；只读 review/审计任务填 N/A
BaseHeadSha:              # 🔴 **开工前（写下第一个字节之前）捕获的 baseline commit**，不是交付时的 HEAD；
                          #   零改动填 N/A。v0.3.0 起不再是失配判据，但 required 且必须可解析：
                          #   缺失 / 不可解析 → DeclaredDiffCheck 等检查填 Blocked（不是 Advisories、不是 N/A）
ObjectFormat:             # sha1 | sha256 —— git rev-parse --show-object-format 的原样输出；零改动填 N/A
ThemeTreeOid:             # plaud_theme_tree 输出的第 2 段；零改动填 N/A
ChangeSetScopeFingerprint: # plaud_changeset_scope 输出的第 2、3 段，形态 "<ScopeTreeOid> <ScopeDigest>"
                          #   —— 两段必须一起逐字比：删除只体现在 ScopeDigest；零改动填 N/A
ReadOnlyProof:            # 仅零改动任务：审计前后两次的 ObjectFormat + ThemeTreeOid（必须相等）
                          #   + 取快照时的 BaseHeadSha；其余填 N/A
AssessmentRef:            # ASMT-<YYYYMMDD>-<NN>；InlineLite 时填 InlineLite；只读填 N/A(ReadOnly)
OriginTriageRef:          # 本块若由反馈返工产生：TriageId + ItemId；否则 N/A
Path: A
ReconMode:                # LegacyImpact | InlineLite（须附豁免理由 + 判定命令原文）；只读填 N/A(ReadOnly)
ModifiedFiles:            # 逐条 `- "<逐字路径>": <一句话改动>`；必须与工作树一致；只读任务填 []
                          #   🔴 **路径必须用双引号包住且逐字精确**（不 trim、不 glob、不写目录）：
                          #   它同时是 ChangeSetScopeFingerprint 与 DeclaredDiffCheck 的**机器输入**，
                          #   下游把引号内的字符串逐字取出、每行一条喂给那两个函数。带尾空格的真实
                          #   路径被 trim 掉会让声明指错文件；路径含双引号 → 函数 fail closed，先重命名
                          #   🔴 **不含 memory/ 下的文件**：memory/ 不属于 ChangeSet，也不在可发布面内
RootCause:                # 机制层根因
OptionsConsidered:       # 非平凡 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:       # QA-A（可多选 QA-B / QA-C）。🔴 不得写 QA-Global——QA 按 §5 恒执行
ThemeCheckRequired:      # Yes | No
VisualRegressionRequired: # Yes | No
BuildRequired:           # Yes | No
ApprovedExceptions:      # 逐项声明的 🟠 ApprovedException；无则填 []
                         #   Clause 只能取 shared §8.1 封闭清单内的条款；Scope 必须逐对象/配对绑定
                         #   ApprovalRef 为空、或 ApprovedBy 是自己 → QA 判 Failed（见 shared §8.1）
                         #   🔴 双周会「已同意但清单尚未更新」的条款**不得**写进来（Clause 越界 = 谎报，
                         #      QA 判 ApprovedExceptionsChecked: Failed）。正确处理：本字段保持 [] 或不列该项，
                         #      条款按其当前档位照常判，BlockingGaps 记
                         #      PendingClauseListAmendment: <条款号> / <决议ref> / <YYYY-MM-DD> / <目标版本 | Unknown(未排期)>
                         #      清单扩容只能由 maintainer 在新版本快照里做（见 shared §8.1「封闭清单的变更权限」）
BlockingGaps:
QAStatus: NotRun
NextRequiredSkill: plaud-theme-qa-intake   # 零改动任务填 None
ReadyForDelivery: No     # 恒为 No；零改动任务填 N/A(ReadOnly)
```

> ⚠️ 每个 `key:` 与注释之间**必须有空格**。YAML 里 `Key:# 注释` 是解析错误，照抄时不要压掉那个空格。

`ChangeSetId` 格式 `CS-<YYYYMMDD>-A<NN>`，`<NN>` 为当日 Path A 的序号，从 `01` 起。
`QAStatus` / `Path` 为常量，任何情况下不得改写（`QAStatus` 的唯一其它合法取值是用户明确弃检时的 `Skipped(UserWaived)`）。`NextRequiredSkill` / `ReadyForDelivery` 只在**零改动只读任务**下取 `None` / `N/A(ReadOnly)`，其余情况恒为 `plaud-theme-qa-intake` / `No`。
交出这个块之后，你这一轮的话到此为止——下一句该由 `plaud-theme-qa-intake` 说（提测准入先于验收；材料齐了 QA 才启动）。
