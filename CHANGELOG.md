# Changelog — PLAUD Shopify Theme Matrix

版本按**全量快照**发布：切新版本 = 整包复制到新目录再改，不做原地修改。

---

## v0.2.0 — 2026-08-12

两条主线：**接入《DTC 开发交付标准 v1.0》**（2026-08-06，运营与产研共同维护，双周会可审议修订），以及**跟进 2026-08-11 的 UX Spec 设计 Token 基线**。

### 1. 新增 3 个 skill（7 → 10）

| order | skill | 承担 | 工件 |
|---:|---|---|---|
| 6 | `plaud-theme-qa-intake` | DTC §四 提测准入：六项交付物、站点清单、包指纹 | `QAIntake` |
| 8 | `plaud-theme-feedback-triage` | DTC §六/§七 反馈归因：缺陷 vs 变更、依据、去向、Linear 建议 | `FeedbackTriage` |
| 9 | `plaud-theme-release-ops` | DTC §五 发版与上线后：推站二次确认、PR、bug 时效、回归用例 | `ReleaseOps` |

原 `plaud-theme-qa` 由 order 6 顺延为 **order 7**。

> 🔴 **提测准入放在 Verify 之前，不是之后。** 初版方案曾把交付包组装放在 QA 通过之后（"验完了再打包交付"），**时序是错的**：DTC §四 原文写的是「提测时必须同时提供，**缺一不进验收**」——交付物是**进验收的准入条件**。放在 QA 之后等于代码验完了才发现没人能复核。
>
> 三个新 skill **均不占阶段轴**。阶段轴恒为 `Assess / Implement / Verify` 三值，写 `Stage: Handover` 之类一律违规。新增 handoff-schema §0.1 专门说明这四个（含 orchestrator）非阶段 skill 的位置与阻断能力。

拆成三个而不是一个的理由：提测包组装、反馈归因、发版治理是**三个不同生命周期**——提测发生在 Verify 前，发版在 Verify 后，反馈归因可在任意时点触发且会**回流**到 Assess。塞进一个 skill 会产生触发歧义与权限混合。

### 2. 交付权边界（§1.1 新增）

`ReadyForDelivery: Yes` 只代表通过了矩阵内部的技术验证。新增明文：它**不代表**提测材料齐备、**不代表** PM 已验收、**不代表**可以推站。四者正交。

> 🔴 **防止产生「第二个交付许可」。** 初版方案打算给提测包一个 `HandoverReady: Yes/No` 字段——与 `ReadyForDelivery` 同构（`Ready` + `Yes/No`），下游极易误读成第二道发布许可。
> 改为**语法隔离**：提测包用 `Complete` / `Incomplete`，交付许可用 `Yes` / `No`，两套枚举明令不可互换。三个新 skill 的产出里**都不出现 `ReadyForDelivery`**；`release-ops` 引用 QA 结论的字段刻意命名为 `QAConclusionRefs` 而非 `ReadyForDeliveryVerified`。

### 3. 提测包的独立内容绑定

`ChangeSetFingerprint` 只覆盖**主题仓库工作树**，对截图、文档、预览 URL 一无所知。新增 `PackageFingerprint`（各材料文件 hash + 预览 URL 原文）单独绑定。

> 🔴 **提测材料不得写进主题仓库。** 截图、文档一旦落进工作树，`ChangeSetFingerprint` 立刻变化 → QA 的 Step 1 判 `ChangeSetIdMatched: No` 并停机——**提测方会因为交了材料而过不了自己的准入门**。qa-intake 的 Step 1 就是查这个，先于一切。

站点维度另立字段（`TargetSites` / `ExcludedSites` / `ThemeIds` / `ScopeSourceRef`）：`AssessmentRef` 回答的是「哪些**模板/实例**受影响」，**不回答**「要推**哪些站点**」。DTC §三 点名推错站点是"过去扣分最多的一项"，因此站点清单要求**两次确认**（需求时 + 发版前）且都有出处，`plaud-theme-impact` 明令不得自行推断站点。

### 4. UX Spec 跟进 2026-08-11 基线

源文档换成设计方新出的 `Plaud-UX-v1.3`「设计 Token 与组件规范文档」（8 页 PDF，打印于 2026-08-11，比 v0.1.0 发布晚 5 天）。版本号仍是 v1.3，但内容是重新整理过的一版。

**冲突项（新基线覆盖旧值）**：

| 项 | v0.1.0 | 新基线 |
|---|---|---|
| 字重 | 「全站**仅** Regular 400，禁止新增字重」 | Regular 400 默认 + **Semibold 600** 用于局部强调 / 数据数值 / 价格突出 |
| `label-secondary` | `#7A7A7A` | **`#717171`** |
| `label-tertiary` | `#A3A3A3` | **该档废止**（新基线无此层） |
| 白色按钮 hover | `#E9E6E6`（colors 表）/ `#EEEEEE`（按钮表）—— 本来就自相矛盾 | 统一 **`#EEEEEE`** |

**纯新增**：角标色板 7 种、透明度叠加 4 个 token、品牌渐变 5 停色标、`--color-bg-white` / `--color-bg-dark`、`label-purple/cyan/green`、按钮 5 变体 + Secondary-Outline 边框 + 四档高度、导航/卡片/倒计时组件尺寸、布局网格 8 档的内边距与内容宽度。

三条落地纪律：

- **`label-tertiary` 走墓碑流程，不是全仓一把删。** 它在真实主题里承载划线价、脚注、免责小字，直接删会让这些元素回退继承父色（多为纯黑）。规范层废止 + 新代码禁用（QA 对新增使用判 `Failed`）+ 过渡期允许一个版本的 alias 指向 secondary + 零引用后才删 utility 与 scheme 重绑 + 历史 seed 不改写只标 supersede。
- **按钮高度是「单行目标最小高度」**，落实为 `min-block-size` + `height: auto` + padding 撑开。写死 `height` 判 `Failed`——德/法/西/俄比英文长 30–50%，换行时会溢出或被裁。固定 `width` 仍全面禁止。这条是新基线与全路径红线②的共存方式。
- **组件尺寸表的 px 先分类再落地**：设计参考（不进 CSS）/ 比例约束（`aspect-ratio`）/ 最小尺寸 / 技术固定例外。不得全翻译成固定宽高。
- **品牌渐变无法直接落地**：只有 5 个色标，圆心、半径、形状、stop 位置全缺。要用时**停机**要 Figma 节点，不得编造 stop position。
- **AI 专属渐变原样保留**：新基线 §2.8 写「渐变仅用于 Announcement Bar 装饰背景，不用于其他场景」，字面上会读成 AI 渐变废止——但该文档通篇未提 AI 渐变，判定为**未覆盖而非废止**，标记待设计方确认。

### 5. A11y：实测对比度 + 待裁决机制

新增 `a11y.md` §5.1 配对表，数值为矩阵**实算**（sRGB 相对亮度，WCAG 2.x），非文档声明值。

| 配对 | 比值 | 处理 |
|---|---|---|
| `#717171` on `#FFFFFF` | 4.88 | ✅ |
| `#717171` on `#F2EFEB`（暖白大底） | **4.26** | 🔴 待裁决 |
| `#717171` on `#F7F5F3`（卡片底） | **4.49** | 🔴 待裁决 |
| Hot / -X% off：`#FF0000` on `#FCDEDE` | **3.17** | 🔴 待裁决 |
| Pre Order：`#39F672` on `#D7FDE3` | **1.30** | ❌ **`Failed`**（几乎不可读，见下） |
| `label-cyan` / `label-green` 压浅底 | 1.83 / 1.44 | ❌ `Failed` |

判定口径分三档：`≥4.5` → `Passed`；`3.0–4.5` **且该配对在封闭 allowlist 里**（spec 直接给出的四组）→ 写进新增的 `Advisories` 字段、不判 `Failed`（色值是设计方给的，矩阵无权改规范去凑对比度）；`<3.0`（**无论出处**）或不在 allowlist 里 → `Failed`。

三条防滥用闸门，防止 `Advisories` 变成降级通道：

1. **`< 3.0` 一律 `Failed`，spec 给的也不行** —— 角标 Pre Order 的 1.30 因此判 `Failed`。3.0 以下不是"略差一点"，是看不见。`BlockingGaps` 写明"需设计方裁决该角标配色"——判 `Failed` 指向的是**规范缺口**，不是开发的实现错误（与「规范与 token 不一致算 PLAUD 缺口」同性质）。
2. **allowlist 是封闭表**（`#717171` 压 `#F2EFEB` / 压 `#F7F5F3`、`#8F53ED` 压 `#F2EFEB`、Hot `#FF0000` on `#FCDEDE`），QA 无权扩充。
3. **每条 Advisory 必须带「已知偏差批准引用」**（设计方 / PM 的确认链接），**引用为空则降级为 `Failed`** —— 否则 Advisory 就成了无人负责的免死金牌。

> 🟢 **这次改动是 A11y 净改善，不是倒退。** 旧 `secondary #7A7A7A` 白底 4.29、暖白底 3.74，**本来就不达标**；旧 `tertiary #A3A3A3` 白底仅 **2.52**。新值 `#717171` 白底 4.88 达标，废止 tertiary 等于拿掉一个长期不合规的档位。

### 6. 运营协作红线进契约（§8.1 / §8.2 新增）

DTC §三 的 11 条进 handoff-schema。**分级处理**：原文标题是「软性，尽量遵守」，本版只把其中**可机械判定、踩了必然出事**的 10 条提升为 🔴 红线，公共文件注释保持 🟡 建议级；并注明这是矩阵侧的收紧，与双方共识冲突时以双周会书面结论为准。

两处刻意保留的限定：

- **「主流程改动必须做成开关」保留了原文的前提「且会修改全站默认配置」** —— 两个条件同时满足才触发。只改单站点存值的主流程改动不受此约束。
- **公共文件的英文注释规范与矩阵原有的「默认不写注释、禁止任务过程注释」直接冲突**，因此限定 allowlist（共享 snippet / 全局 CSS 源 / `theme.liquid` / 共享 JS）、禁写清单（**build 产物**——注释会被下次 build 冲掉；**`templates/*.json`**——JSON 不支持注释，写了直接坏）、各文件类型的合法语法（`.liquid` 用 `{% comment %}` 而不是 `//`，后者会原样输出到 HTML）、ISO 日期、以及"负责人拿不到就停机问，不得填 agent 名"。

locale 条款细化为**分流判定**：固定 UI 文案走 `locales`，运营可配置文案走 schema，两者都不得写死在 Liquid 里。

### 7. QA 侧改动

- 新增 **Step 0 准入门** `QAAdmissionStatus: Accepted | Blocked`，**早于**指纹校验。`Blocked` 时零验证项执行，原样带出 qa-intake 的 `BlockingGaps`
- §5 工件 **19 → 24 字段**：新增 `SubmissionId` / `QAAdmissionStatus` / `QAAdmissionReason` / `StyleHardRuleCheck` / `Advisories`
- QA-Global 新增 §9（DTC §2.1 硬性 10 条的逐条查法）与 §10（§2.2 软性项 → `Advisories`，非阻断）
- 明确 **提测的 8 张断点截图不能顶替 QA 自己的断点回归**；`BreakpointsCovered` 记 `PC` 时须写出实际像素宽度（`PC(1920)`）
- 三个实现 skill 的 `NextRequiredSkill` 由 `plaud-theme-qa` 改为 **`plaud-theme-qa-intake`**

**顺带修掉一处既有契约漂移**：`plaud-theme-qa` 的 SKILL.md 与 `evidence-and-invalidation.md` 长期声称 `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` 存在「handoff-schema §5 与 §9.2 规定不一致的枚举缺口」，并要求每次在 `BlockingGaps` 登记该歧义。复核 v0.1.0 原文：**§9.2 枚举表这三项本来就含 `Blocked`**，两处一致——所谓缺口自 v0.1.0 起就是过时描述。已删除该提示，判定纪律（未执行填 `Blocked`，绝不改填 `NotApplicable` / `Passed` / `Failed`）不变。

### 8. 发布前评审加固（14 项）

v0.2.0 的初版方案经外部评审打回一次，以下是被指出并修掉的问题。记录在这里是因为**其中四项能真正绕过门禁**，而它们在静态校验与 evals 里都不会暴露：

| # | 问题 | 修法 |
|---|---|---|
| 1 | QA 的 `ReadyForDelivery: Yes` 判定条件**漏了新增的两道门** —— 只查九个旧字段，硬性 10 条 `Failed` 时仍可能放行 | 判定条件加第 0 条 `QAAdmissionStatus == Accepted`，状态字段九个→十个 |
| 2 | 留了**两条显式绕过链**：用户声明"不走提测流程"直接得 `Accepted`；紧急上线时 release-ops"照做" | 前者改为仍 `Blocked`（照跑检查但不给许可）；后者改为不出发版清单、不给"可以推"的结论，改配一张**最短合规路径**表接住"来不及"这个真实诉求 |
| 3 | **多 ChangeSet 同批发版在当前指纹模型下无法闭环** —— 指纹绑整个工作树，第二块落盘时第一块的 QA 就失效，不可能同时持有 N 个有效结论 | 不改指纹模型，改为要求合并后跑**集成 QA**（新 ChangeSetId、`ModifiedFiles` 取并集），`release-ops` 引用它；工件加 `IntegrationQARef`。彻底解法（绑不可变 commit/tree）留后续版本 |
| 4 | **提测包没有可信绑定** —— QA 只看 `SubmissionPackageStatus`，A 任务的合格包可重放给 B，材料也可在准入后替换 | QA Step 0 改三查：intake 的 `ChangeSetId`/`ChangeSetFingerprint` 与 Implement 工件逐字比对 + 重算 `PackageFingerprint` + 状态 |
| 5 | A11y 三档规则**自相矛盾**（规定 `<3.0` 判 `Failed`，却把 1.30 的 Pre Order 放进 Advisory） | 见上，改封闭 allowlist + 三条闸门 |
| 6 | tertiary 兼容 alias **在 `.use-color-scheme` 下会失效** —— 重绑特异性高于 root alias，只加 alias 不删重绑比不加更难排查 | 重绑改为**过渡期第一步就删**，与加 alias 同一步做完 |
| 7 | 三类新工件**结构表达不了实际状态**：分类是逐条的却放顶层、`Pending` 时仍强制填 `NextRoute`、单个 `AcceptanceStatus` 表达不了部分验收 | `FeedbackItems` 改逐条结构（+`PMDecisionValue`/`NewWorkItemRef`）、`NextRoute` 加 `AwaitPMDecision`、`AcceptanceStatus` 改为 `ReleaseScope` 逐块结构 |
| 8 | orchestrator 台账要求抄录 QA 的 `QAStatus`，**但 §5 工件没有该字段** | 改为抄 Implement 工件（§4）的值，并补 `SubmissionId`/`QAAdmissionStatus`/`TriageId` 台账列 |
| 9 | **QA 打回的路由不统一** —— triage 声称接收 QA 打回，MATRIX 又让 Failed 直接回实现 skill | 分流：**机械失败直接返修**（不进 triage，没有"缺陷还是变更"可判）；只有运营/PM 验收反馈才进 triage |
| 10 | §5 与 §9.2 枚举仍有三处冲突（`ThemeRuntimePreview`/`AdminSchemaSave` 缺 `Failed`、`RegressionMatrix` 缺 `NotApplicable`） | 对齐为四值 |
| 11 | Verify 工件字段数未全量同步（两处仍写旧值）、shared contract 仍写"6 个 skill"、`StageResolved` 只有三值容不下非阶段 skill | 全量同步，`StageResolved` 加 `N/A(NonStage)` |
| 12 | UX 数值仍有旧事实源：两处"全站仅 400"、按钮表有规范里不存在的 `Primary-Light` 且漏 Purple/Green/Cyan；Secondary-Outline 要求用边框变量却没定义 | 全部更新；边框补两种落地方式（复用既有变量或新增 token 再 build，**不得内联硬编码**） |
| 13 | `FixedDimensionCheck` 只 grep `width\|height`，**`block-size: 40px` 可直接绕过** | 覆盖逻辑属性 + 内联 style，并先排除 `min-`/`max-` 前缀避免误报正确写法 |
| 14 | DTC 的**测试集治理**整块缺失；注释格式把原文"年月日时间"缩成日期，"必须英文"的示例却是中文 | 新增 §8.1.1 测试集治理（三条分别落到 qa-intake / release-ops / 外部人工审查，并明写矩阵不拥有测试集本身）；时间精度改 ISO `YYYY-MM-DD HH:MM`，示例换英文 + `{% comment %}` 语法 |

顺带修掉两处自引入的不一致：墓碑流程"零引用后才删重绑"与"立即删重绑"打架；一处 eval 仍写"九个状态字段"。

**评审共跑了三轮**，后两轮又暴露出五个更深的问题，其中三个只有在追问"这套流程真的能执行吗"时才会显形：

| 问题 | 处置 |
|---|---|
| **主指纹命令里还有一处同类吞错** —— `git hash-object` / `stat` 写在 `printf` 的命令替换里，失败时 `printf` 拿到空串照样返回 0，未跟踪文件的内容就从指纹里消失了 | 与 `PackageFingerprint` 同样改为先赋值、判退出码、判空。这是 **v0.1.0 遗留**的漏洞，就藏在那段专门警告这类错误的代码里 |
| **"集成 QA"方案根本跑不通** —— 合并提交后工作树是干净的，`ModifiedFiles = 各块并集` 必然失配；用未提交态过 QA 则一提交 `HEAD` 就变、QA 又失效。绑工作树的模型下**没有稳定对象能从"已验证"走到"实际推送"** | **改为明确声明 v0.2.0 不支持多 ChangeSet 同批发版**，release-ops 遇到多块直接停机、要求逐块串行。彻底解法（指纹改绑不可变 commit / tree 对象）留 v0.3.0 |
| **云端提测材料可以绕过防替换门** —— manifest 只记 URI 时，云文档内容随便换、指纹照样对得上 | 不能内容绑定的材料一律 `Incomplete`（不得带着"已知弱环"拿 `Complete`）；QA 复算时**重新查远端 revision**，不是只比本地 manifest；工件加 `PackageRootRef` 让复算有据可依 |
| **`Blocked` 的原因只能靠聊天上下文猜** | 新增封闭枚举 `QAAdmissionReason`（`Normal` / `ZeroChangeReadOnly` / `PackageIncomplete` / `BindingMismatch` / `MissingArtifact` / `UserWaivedMaterials`），"跑不跑检查"由字段决定而不是自然语言 |
| **部分站点推送失败填 `NotExecuted` 会抹掉线上副作用**，下次有人看到"没推过"就重推一遍 | 新增 `PartiallyExecuted` 与 `PerSitePushResult` 逐站点结果 |

> 🟢 **宁可声明不支持，也不发一套跑不通的流程。** 硬给一条走不通的路，实际效果是使用者发现走不通之后自己找绕过路径——那比明说"这版不支持"危险得多。

> 🔴 **第 4 项和第 13 项值得单独记住**，它们和 v0.1.0 那个指纹 bug 是同一类错误——**在管道 / 命令替换里静默失败，或者匹配模式盖不全等价写法**。`PackageFingerprint` 原本写成 `printf '%s %s' "$f" "$(shasum ...)"`，命令替换里的失败不会让 `printf` 失败，`|| return 1` 永远不触发，指纹退化成只反映文件名列表。写任何校验命令时都要问：这一段失败了，外层真的会知道吗？这个模式盖得住所有等价写法吗？

### 9. 未变

ChangeSet 内容绑定（`ChangeSetId` + `BaseHeadSha` + `ChangeSetFingerprint`，QA 在任何检查之前三者重算比对）、Theme Check baseline 增量双指标、只读任务的 `ReadOnlyProof`、理论影响 vs 实际影响分开报、项目状态存 `memory/`、安装器 legacy 退役 fail-closed。

### 10. 已知局限

- **v0.2.0 不支持多 ChangeSet 同批发版**（见上）。需要一次发多块时只能逐块串行：每块走完 实现 → 提测 → QA → 发版，再做下一块
- 三个新 skill **未做行为评测**，只有各 13–14 条 evals 与静态校验。v0.1.0 的教训：四轮 Codex 评审 + 205 条 eval + 全套静态校验都没抓到的指纹 bug，只有真跑才发现
- UX Spec 有两处待设计方裁决（A11y 🔴 项、AI 渐变与 §2.8 的关系）
- 品牌渐变缺几何参数，无法直接生成 CSS
- Semibold 600 放开后须核字体资源：字体文件、`@font-face 600` 声明、加载策略，缺一会触发浏览器 synthetic bold（字形变形）

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
