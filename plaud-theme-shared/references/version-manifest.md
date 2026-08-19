# Version Manifest — 版本清单与 skill 职责

**何时读我**：需要确认矩阵版本、某个 skill 归谁管、本包对应哪版 UX Spec，或想知道旧的单 skill 包去哪了。

---

## 1. 版本

| 项 | 值 |
|---|---|
| 矩阵包版本 | **v0.3.6**（已发布，git tag `v0.3.6`） |
| 包名 | `plaud-theme-matrix`（git 仓库 <https://github.com/chovizzz/plaud-theme-matrix>；版本靠 tag 钉，不再有 `-vX.Y.Z` 目录与 zip） |
| 契约版本（`ContractVersion`） | **v0.3.6**（与包版本同步递增；v0.3.2–v0.3.6 都只动包内附带工具 skill 与安装/更新机制（v0.3.5 另在本 skill 加了一节非契约的更新提示），矩阵字段、枚举与路由一字未改——但契约版本仍按约定同步递增，否则四端会判版本漂移） |
| 对应 UX Spec 版本 | **v1.3 · 2026-08-11 设计 Token 基线**（源文档 `Plaud-UX-v1.3`「设计 Token 与组件规范文档」，8 页 PDF）。它取代了 v0.1.0 依据的 `PLAUD_UX_规范基准_v1.3.md`（含 2026-07 补充修订 4 条）——版本号同为 v1.3，但内容是重新整理过的一版，差异见 CHANGELOG |
| 对应交付标准 | **《DTC 开发交付标准 v1.0》**（2026-08-06，运营与产研共同维护，双周会可审议修订） |
| 前身 | v0.1.0（7 skill）；再前身是单 skill 包 `plaud-shopify-theme-skill` |
| skill 数 | 矩阵 skill **10**；包内附带工具 skill **1**（见 §2.1）；安装器实际安装目录 **11** |

**`ContractVersion` 与包版本同步递增。** 任一**矩阵 skill**（§2 那 10 个）输出的 `ContractVersion` 与本文件不符 → 视为版本漂移，停机并要求重装。§2.1 的包内附带工具 skill **不输出 `ContractVersion`，也不参与漂移判定**——它没有这个字段不是漂移。

### 1.1 哪些改动**必须**伴随一次版本发布（v0.2.2 补）

本包按 **git tag** 分发，各端靠仓库根的 `install.sh` / `install.ps1` 按 tag 装成四份独立副本；**会议纪要、飞书文档、Linear issue 都不随包分发**，agent 运行时能读到的只有包内文本。因此下列改动**只改包外文档不算数**，必须切新版本快照并重装：

| 改动 | 为什么必须发版 |
|---|---|
| `handoff-schema.md` §8.1 的 **`ApprovedException` 封闭适用清单**（增删条款） | 规则正文与变更权限唯一见 `handoff-schema.md` §8.1「封闭清单的变更权限」（本表**不复制清单内容、不复制 owner 规则**）。不发版 = 四端仍按旧清单判，而人以为已经放开 |
| §8 / §8.1 红线的增删与档位调整 | 同上；另见 `plaud-theme-shared/matrix-contract.md` 的「红线增删」行 |
| 任何封闭枚举（§9.2）的取值增删 | agent 的结构核直接按包内枚举判，包外新增取值一律会被判非法 |

> 🔴 **本文件不是安装状态账本。** 这里只声明"该发版"，**不记录"四端已装好"**——那要靠 README「发布新版本」一节的**版本 + 内容双重核对**当场跑出来。安装器对**不存在的客户端目录会静默跳过**，所以"脚本跑完没报错"不等于四端都装上了；把"已校验"写进任何一份 Markdown 都不构成证据。

---

## 2. 10 个 skill 的 order 与职责

| order | skill | 一句话职责 | 阶段 / 路径 |
|---|---|---|---|
| **0** | `plaud-theme-shared` | 契约层：两轴状态机、handoff schema、全路径红线、视觉与技术基线的唯一副本。**不改任何代码** | 全部（被引用） |
| **1** | `plaud-theme-orchestrator` | 全流程路由与阶段门控；**唯一门槛是这件事能拆成 ≥2 个可独立验收的 ChangeSet**（迁移 wave、多块编排、Cross(A+C) 裂块，或用户点名把这样一批端到端管起来）。Cross(B+C) 不裂块、单一 ChangeSet 一律走单 skill | 全部（编排） |
| **2** | `plaud-theme-impact` | Assess 阶段唯一执行者：影响面评估，只产出**事实**（理论引用 vs 实际影响），不下根因、不选方案 | Assess / A·B·C |
| **3** | `plaud-theme-dev` | Path A 实现：bug 修复、性能、新功能、UX 微调、review、A11y | Implement / A |
| **4** | `plaud-theme-section-build` | Path B 实现：Figma → `sa-*` section（`SA:` schema、BEM 根类、vendor 交付约束） | Implement / B |
| **5** | `plaud-theme-ux-migration` | Path C 实现：按 UX Spec v1.3 刷模块 / 迁移、三层入口选择、迁移日志 | Implement / C |
| **6** | `plaud-theme-qa-intake` | **提测准入关口**（不占阶段轴）：按 DTC §四 校验六项交付物、站点清单与包指纹；材料不齐 QA 不启动 | Implement→Verify 过渡 |
| **7** | `plaud-theme-qa` | Verify 阶段唯一执行者，**唯一有权输出 `ReadyForDelivery: Yes`**；跑 QA-A/B/C + QA-Global | Verify / A·B·C |
| **8** | `plaud-theme-feedback-triage` | **反馈归因入口**（不占阶段轴）：按 DTC §六 判交付缺陷 vs 需求演进，给依据与去向；判定人是 PM | 事件入口 |
| **9** | `plaud-theme-release-ops` | **发版与上线后**（不占阶段轴，Verify 之后）：按 DTC §五 做推站二次确认、PR 汇总、线上 bug 时效与回归用例入库 | 发版 |

### 2.1 包内附带工具 skill（不占 order，不进矩阵）

上表的 **skill 数 = 10 只数矩阵 skill**。包里另随装下列**附带工具 skill**：它们不占 order、
不进路由判定树、没有 `matrix-contract.md`，不产出也不消费 §4 / §5 的任何契约字段，
`ContractVersion` 漂移判定也不适用于它们。安装后客户端目录里会比矩阵多出这些目录，
**这不是版本漂移**。

| skill | 一句话职责 | 与矩阵的关系 |
|---|---|---|
| `yidian-draft-pr` | 把选定 commit cherry-pick 到新分支，按 yidian 必填 PR body 开 Draft PR（base 分支不限） | 无。它不读矩阵状态、不输出契约字段；**矩阵不得路由到它**，它也不得被当作某个阶段或某个阶段的前后置条件 |

入口暴露分层（不是十个平级入口）：

- **正常用户入口**：`dev` / `section-build` / `ux-migration`
- **全流程入口**：`orchestrator`
- **阶段能力 / 专家入口**：`shared` / `impact` / `qa`
- **运营协作入口**（v0.2.0 新增，均不占阶段轴）：`qa-intake`（提测）/ `feedback-triage`（反馈归因）/ `release-ops`（发版与上线后）

---

## 3. 本层 reference 清单

| 文件 | 覆盖内容 | 唯一事实源范围 |
|---|---|---|
| `handoff-schema.md` | 两轴状态机、交付权、ChangeSetId、Assess/Implement/Verify 工件、Theme Check 门、停机点、**全路径红线正文**、输出块格式 | 契约与红线的规范性表述 |
| `typography.md` | 字体族 / 字重、`--text-*` 与 `.fs-*` 分工（**语义类 vs 数字遗留类**）、字阶表、**h1–h6 标签与字号解耦**、区头三件套、行高、`.richtext-container` | 全部字体数值 |
| `colors-and-schemes.md` | 品牌色变量、spec 色阶、AI 渐变、`color_scheme` schema + Liquid、`.use-color-scheme` 重绑表、自定义颜色规则 | 全部颜色数值 |
| `responsive-and-spacing.md` | CSS 判定断点 + 组件特例、设计画板断点、`--space-N`、间距/圆角/按钮尺寸工具类、容器宽度 7 阶、section 间距、三层响应式变量、**三个高频陷阱** | 全部断点与间距数值 |
| `media-quality.md` | 图片清晰度红线操作化、防 CLS、懒加载与 Swiper 冲突、`<source media>`、视频、素材来源 | 媒体取值方法 |
| `liquid-schema-format.md` | 文案 i18n 三规则、schema 标签、完整显示、价格规范、HTML 格式、命名、schema 向后兼容、**Theme Check 高发项对照** | Liquid / schema 规则 |
| `javascript-swiper.md` | 主题架构速记、基类选择、数据传递优先级、生命周期清理、**Swiper effect 约束表**、`section-swiper`、bug 对照表 | JS / Swiper 约束 |
| `a11y.md` | 7 条 A11y 底线的**判定方法** | A11y 判定细则 |
| **`repo-drift.md`** | 规范值 vs 目标仓库编译产物：为什么会滞后、开工前核对命令、7 类已知漂移案例 | build 产物滞后 |
| `version-manifest.md` | 本文件 | 版本与职责 |
| **`CONTRACT-FREEZE.md`** | v0.3.0 契约冻结件：最终字段清单与顺序、新增/废止枚举、六个函数的签名与环境要求、11 条阻断项裁决、每个下游 skill 的接线清单 | 第三波落地的唯一输入 |

> v0.2.0 的 `handoff-schema.md` 新增：§0.1 四个非阶段 skill、§1.1 `ReadyForDelivery` 的边界、
> §8.1 运营协作红线（DTC §三）、§8.2 公共文件改动注释、§9.1.2–§9.1.4 三类新工件、§9.2 对应枚举。
> `a11y.md` 新增 §5.1 新色板的实测对比度与允许配对表（🔴 待设计方裁决项进 QA 的 `Advisories`，不判 Failed）。

> **v0.2.1 修订**（评审回应，不新增 skill）：
> `handoff-schema.md` §8.1 由「10 条一律红线」改为 **🔴 / 🟠 / 🟡 三档**（🟠 分 `EvidenceBased` 与 `ApprovedException`，后者缺 `ApprovalRef` 直接 `Failed`），#5 / #9 / #10 改为**按范围**判定；新增 §8.1.2 **存量复用豁免**（只免修复义务）；§8.1.1 测试集溯源三项收敛为一行 **`TestSetTrace`**（新增进 §9.1.2 工件与 §9.2 枚举）。
> `typography.md` §4 整节重写（**撤回 H5 = 22px 与「复用 h5 全局规则」**，新增 §4.1 仓库 h5 现状 / §4.2 语义类 vs 数字遗留类）；`colors-and-schemes.md` §3 outline 边框改为**先判两条样式链是否统一再决定复用或新增变量**；`repo-drift.md` 新增 §3.6 / §3.7。

> **v0.2.2 修订**（v0.2.1 的门禁收口，详见 CHANGELOG）：
> 📎 `handoff-schema.md` §8.1 加 **`ApprovedException` 封闭适用清单**（发布当时的成员快照：只有 A11y 3.0–4.5 一项，§8.1 十一条无一在内 —— 🔴 **这是发布说明里的历史快照，不是运行时事实源**，判定一律现读 `handoff-schema.md` §8.1 那张表）；§4 加 `ApprovedExceptions`、§5 加 `ApprovedExceptionsChecked` / `ApprovedExceptionsEvidence`（§4=20 / §5=26 字段）；§2 与 §9.1.2 两段指纹命令**修掉两个静默失败点**（`{ … } | shasum` 的子 shell 吞错、未跟踪目录静默跳过）并**排除 `memory/`**；`package-checklist.md` §3 加 `PreviousAcceptedTestSetTrace` 与三级取数路径；`changeset-log.md` 加 `TestSetTrace` 列；§9.1.4 加 `TestSetTraceAfterArchive` 并移除跑不通的 `IntegrationQARef`。
> **同时更正 v0.2.1 的一处措辞**：§4.1 原写「三套并行的 h5 实现」，实测 `--h0-size…--h6-size` 全仓无消费点，是死声明；现表述为「一套生效规则 + 一处死变量声明 + 一套与标签正交的语义体系」。

> **v0.3.0 修订**（契约层破坏性变更，详见 CHANGELOG）：
> 📎 `handoff-schema.md` §2 **整节重写**——ChangeSet 指纹从「工作树状态文本的 SHA-256」改绑**不可变 git tree 对象**。`ChangeSetFingerprint` **废止**，身份改为三元组 `ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`；`BaseHeadSha` 不再是失配判据但**仍必填且必须可解析**。
> 📎 新增六个规范函数：`plaud_theme_tree` / `plaud_changeset_scope` / `plaud_declared_diff` / `plaud_base_theme_tree` / `plaud_stage_workspace` / `plaud_stage_verified`（取代 `plaud_fingerprint`）。
> 工件字段数：**§4 = 22**（v0.2.3 为 20）、**§5 = 35**（26）、**§9.1 Coordination = 9**（8）、**§9.1.2 QAIntake = 26**（23）、**§9.1.4 ReleaseOps = 28**（16）。§3 与 §9.1.3 不变（15 / 7）。
> 📎 §9.2 新增枚举 `QAScope` / `ReadyForIntegration` / `ObjectFormat` / `DeclaredDiffCheck` / `PushCommandCompliance` / `RemoteVerifyResult`，`PerSitePushResult[].Status` 新增取值 `Unverified`，`IncludedInThisPush` 的「至多一个」限制删除。
> 📎 「不支持多 ChangeSet 同批发版」整节删除并改写为 §2.10–§2.15。`changeset-log.md` 的 `ChangeSetFingerprint` 列 → `ObjectFormat` + `ThemeTreeOid` + `ScopeFP` 三列（**旧行不回填**）。
> **新增运行环境前提**：可写 `TMPDIR`、git ≥ 2.25、**取证只支持 macOS / Linux**（Windows 上两道字节保真门必然停机）。
> 🔴 契约冻结件见 `plaud-theme-shared/references/CONTRACT-FREEZE.md` —— 那是第三波（其余九个 skill 落地）的**唯一输入**。

> `repo-drift.md` 是**后加的第 9 个 reference**，已在 `plaud-theme-shared/SKILL.md` 的 Reference 索引表里（标为「要落地任何 spec 数值、或依赖某个 token / 工具类之前（必读）」）。
> 加载规则：**任何要落地 spec 数值 / 依赖某个 token 或工具类的任务都应读**（build 产物滞后与仓库无关）；`typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` 三处也在正文交叉指向它。
> （v0.2.2 更正：v0.2.1 及以前这里写「索引表里没有它、下次补进」，实际早已补进，属过时描述。）

**按需加载，不要全读。** Path A 改一个 JS timer 时不需要加载完整字阶表。

---

## 4. 从单 skill 迁移而来

本矩阵由单 skill 包 **`plaud-shopify-theme`** 拆分演进而来。

| 原单 skill 内容 | 现归属 |
|---|---|
| `SKILL.md` 路由（Path A/B/C 判定） | `plaud-theme-orchestrator` + 各实现 skill 的 description |
| `SKILL.md` 视觉与 UX 基线 | 拆进本层 `typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` / `media-quality.md` |
| `SKILL.md` Liquid/CSS/JS 规则、Swiper 约束、主题架构速记、无障碍底线 | `liquid-schema-format.md` / `javascript-swiper.md` / `a11y.md` |
| `SKILL.md` 全局门控（依赖树 / OODA / 回归矩阵 / 验收清单） | `handoff-schema.md` §3–§5 的工件字段 + `plaud-theme-qa` 的 profile |
| `references/theme-dev-spec-for-vendors.md`（§1–§12） | 数值全部收敛进本层 8 个 reference；Path B 交付流程留在 `plaud-theme-section-build` |
| `references/ux-spec-v13-migration.md`（v1.3 修订 / 零容忍 / 12 条约定 / §4.x 踩坑库 / 日志规范 / 团队协作 / 附录 A·B） | 数值与通用陷阱收敛进本层；迁移工作流、12 条约定、日志规范留在 `plaud-theme-ux-migration`；附录 A·B（模板/模块清单）**改为项目侧 `memory/`，不随包分发** |

### 相对单 skill 的三个结构性变化

1. **数值单一事实源**：所有视觉与技术基线数值只存在于 `plaud-theme-shared/references/`。其它 6 个 skill **禁止复制数值**，只得引用——复制会产生多事实源，spec 一升级必然漂移。
2. **交付权收口**：单 skill 时代任何路径都能自称"改完了"；现在只有 `plaud-theme-qa` 能输出 `ReadyForDelivery: Yes`。
3. **项目状态外置**：模板清单 / 模块清单 / 全局已知偏差 / changeset log 属**项目运行时状态**，移到项目侧 `memory/*.md`。写进包里会在下次 install 时被整包覆盖。

---

## 5. v1.3 数值优先级（7 条覆盖规则，落实位置索引）

vendor 对外版为早期基线；凡与 v1.3 不一致处**一律以 v1.3 为准**。7 条逐条落实在：

| # | v1.3 覆盖规则 | 旧值（已废） | 落实位置 |
|---|---|---|---|
| ① | 字重 **Regular 400 默认 + Semibold 600 局部强调**（2026-08-11 基线放开；v0.1.0 的「全站仅 400」已废止） | 标题加粗 / 700+ / `.fwb`；`subheading_weight`=500 | `typography.md` §1 |
| ② | 区头 Heading PC = 40px（large-title-2） | 42px | `typography.md` §3、§5 |
| ③ | `.container` XS/Mobile 内边距 = 24px | 15px | `responsive-and-spacing.md` §4.2 |
| ④ | 容器最大宽度 1600/1440/1280/1140/960/720/540 | 1480 / 1200 | `responsive-and-spacing.md` §4.1 |
| ⑤ | `rounded-5`/`rounded-10` ≡ `radius-base`(5)/`radius-lg`(10) | 两套命名被当成两回事 | `responsive-and-spacing.md` §3.2 |
| ⑥ | CSS 判定统一 767.98 / 1279.98 / 1599.98 | 390/768/1366/1440/1920 当判定值；767/768/1024/1025 混用 | `responsive-and-spacing.md` §1、§2 |
| ⑦ | 字号 / 间距按语义档离散取值，组件内不插值 | 中间断点线性插值 | `typography.md` §3、§4；`responsive-and-spacing.md` §3、§6.3 |

补充第 8 条（v1.3 §1.2 修订，未列在 vendor 的 7 条里但同等生效）：**`text-body-md` MB 字号 12px → 14px**，且 md/lg 按用途区分（卡片辅助 vs 正文段落）——见 `typography.md` §3。

---

## 6. 源规范未闭合处（本包不擅自裁决）

以下是三份源文件里**规范值有效、但缺配套**或**标注口径不一致**的点。本包按"停机问用户"处理，不擅自取值：

| 项 | 情况 | 处理 |
|---|---|---|
| ~~H5 = 22px 无同值工具类~~ | ❌ **v0.2.1 撤回：该条本身是错的。** UX Spec v1.3 没有 H1–H6 表，22px 不是 spec 值；且「工具类里不存在 22px」也不成立（`.fs-22` 真实存在于 `assets/critical.css` / `snippets/critical-style.liquid`，且仍被两个 section 引用）。原「优先复用既有 H5 全局规则」的建议会产出 **28.8px**（旧 vendor 值），必须停用 | 已改写为 `typography.md` §4：标签与字号解耦，按用途选 9 档语义 token |
| ~~H1：64/36 vs large-title-1：48/40~~ | ✅ **已裁决**：以 token **48/40** 为准，vendor §6 的 64/36 **作废** | 已落进 `typography.md` §3、§4 |
| ~~`.btn-primary-lg` 字号未给值~~ | ✅ **已解决**：编译产物实测 LG = 18px PC / 16px MB | 已补进 `responsive-and-spacing.md` §3.3 |
| ~~H 标签表的断点标注~~ | ❌ **v0.2.1 一并撤回**：H 标签表已不作为 spec 档位存在（见上条），其断点标注无需再裁决 | 见 `typography.md` §4 |
| **区头 992 vs 全站 767.98 / 1279.98** | 区头样式表按 992 分 PC/MB | 已确认为**组件特例**，勿泛化（`typography.md` §5、`responsive-and-spacing.md` §1.1） |

> **不属于本节的**：某仓库"富文本 h1–h6 是否已对齐""按钮档差是否要调"这类**项目运行时状态**，在项目侧 `memory/全局已知偏差.md`，不写进契约层。
