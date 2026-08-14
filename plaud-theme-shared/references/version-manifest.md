# Version Manifest — 版本清单与 skill 职责

**何时读我**：需要确认矩阵版本、某个 skill 归谁管、本包对应哪版 UX Spec，或想知道旧的单 skill 包去哪了。

---

## 1. 版本

| 项 | 值 |
|---|---|
| 矩阵包版本 | **v0.1.0** |
| 包名 | `plaud-shopify-theme-matrix-v0.1.0` |
| 契约版本（`ContractVersion`） | **v0.1.0** |
| 对应 UX Spec 版本 | **v1.3**（源文档 `PLAUD_UX_规范基准_v1.3.md`，含 2026-07 的「📌 v1.3 spec 补充修订」4 条） |
| 前身 | 单 skill 包 `plaud-shopify-theme-skill`（`plaud-shopify-theme`） |
| skill 数 | 7 |

**`ContractVersion` 与包版本同步递增。** 任一 skill 输出的 `ContractVersion` 与本文件不符 → 视为版本漂移，停机并要求重装。

---

## 2. 7 个 skill 的 order 与职责

| order | skill | 一句话职责 | 阶段 / 路径 |
|---|---|---|---|
| **0** | `plaud-theme-shared` | 契约层：两轴状态机、handoff schema、全路径红线、视觉与技术基线的唯一副本。**不改任何代码** | 全部（被引用） |
| **1** | `plaud-theme-orchestrator` | 全流程路由与阶段门控；仅跨多资源、B+C / A+C 交叉、迁移 wave 或用户明确要完整交付时进入 | 全部（编排） |
| **2** | `plaud-theme-impact` | Assess 阶段唯一执行者：影响面评估，只产出**事实**（理论引用 vs 实际影响），不下根因、不选方案 | Assess / A·B·C |
| **3** | `plaud-theme-dev` | Path A 实现：bug 修复、性能、新功能、UX 微调、review、A11y | Implement / A |
| **4** | `plaud-theme-section-build` | Path B 实现：Figma → `sa-*` section（`SA:` schema、BEM 根类、vendor 交付约束） | Implement / B |
| **5** | `plaud-theme-ux-migration` | Path C 实现：按 UX Spec v1.3 刷模块 / 迁移、三层入口选择、迁移日志 | Implement / C |
| **6** | `plaud-theme-qa` | Verify 阶段唯一执行者，**唯一有权输出 `ReadyForDelivery: Yes`**；跑 QA-A/B/C + QA-Global | Verify / A·B·C |

入口暴露分层（不是七个平级入口）：

- **正常用户入口**：`dev` / `section-build` / `ux-migration`
- **全流程入口**：`orchestrator`
- **阶段能力 / 专家入口**：`shared` / `impact` / `qa`

---

## 3. 本层 reference 清单

| 文件 | 覆盖内容 | 唯一事实源范围 |
|---|---|---|
| `handoff-schema.md` | 两轴状态机、交付权、ChangeSetId、Assess/Implement/Verify 工件、Theme Check 门、停机点、**全路径红线正文**、输出块格式 | 契约与红线的规范性表述 |
| `typography.md` | 字体族 / 字重、`--text-*` 与 `.fs-*` 分工、字阶表、H1–H6、区头三件套、行高、`.richtext-container` | 全部字体数值 |
| `colors-and-schemes.md` | 品牌色变量、spec 色阶、AI 渐变、`color_scheme` schema + Liquid、`.use-color-scheme` 重绑表、自定义颜色规则 | 全部颜色数值 |
| `responsive-and-spacing.md` | CSS 判定断点 + 组件特例、设计画板断点、`--space-N`、间距/圆角/按钮尺寸工具类、容器宽度 7 阶、section 间距、三层响应式变量、**三个高频陷阱** | 全部断点与间距数值 |
| `media-quality.md` | 图片清晰度红线操作化、防 CLS、懒加载与 Swiper 冲突、`<source media>`、视频、素材来源 | 媒体取值方法 |
| `liquid-schema-format.md` | 文案 i18n 三规则、schema 标签、完整显示、价格规范、HTML 格式、命名、schema 向后兼容、**Theme Check 高发项对照** | Liquid / schema 规则 |
| `javascript-swiper.md` | 主题架构速记、基类选择、数据传递优先级、生命周期清理、**Swiper effect 约束表**、`section-swiper`、bug 对照表 | JS / Swiper 约束 |
| `a11y.md` | 7 条 A11y 底线的**判定方法** | A11y 判定细则 |
| **`repo-drift.md`** | 规范值 vs 目标仓库编译产物：为什么会滞后、开工前核对命令、5 类已知漂移案例 | build 产物滞后 |
| `version-manifest.md` | 本文件 | 版本与职责 |

> 🔴 `repo-drift.md` 是**后加的第 9 个 reference**，`SKILL.md` 的 Reference 索引表（本版不可改）里没有它。
> 加载规则：**任何要落地 spec 数值 / 依赖某个 token 或工具类的任务都应读**（build 产物滞后与仓库无关）；`typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` 三处已在正文交叉指向它。下次可改 `SKILL.md` 时应补进索引表。

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
| ① | 字重全站 Regular 400 | 标题加粗 / 多字重；`subheading_weight`=500 | `typography.md` §1 |
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
| **H5 = 22px 无同值工具类** | 22px 是现行规范值（vendor §6）；**已实证**编译产物 `.fs-*` 只有 9 档（48/40/32/28/24/20/16/14/12），22px 确实不存在 | **不得**改成 20 或 24。优先复用既有 H5 全局规则；确需工具类化 → 停机请示是否新增语义 token（`typography.md` §4） |
| ~~H1：64/36 vs large-title-1：48/40~~ | ✅ **已裁决**：以 token **48/40** 为准，vendor §6 的 64/36 **作废** | 已落进 `typography.md` §3、§4 |
| ~~`.btn-primary-lg` 字号未给值~~ | ✅ **已解决**：编译产物实测 LG = 18px PC / 16px MB | 已补进 `responsive-and-spacing.md` §3.3 |
| **H 标签表的断点标注** | vendor §6 写 "Desktop（≥1920px）/ Mobile（≤768px）"，与 CSS 判定值 1599.98 / 767.98 不是同一套 | 表内**数值有效**；断点标注按 `responsive-and-spacing.md` §1 理解，中间档离散取值 |
| **区头 992 vs 全站 767.98 / 1279.98** | 区头样式表按 992 分 PC/MB | 已确认为**组件特例**，勿泛化（`typography.md` §5、`responsive-and-spacing.md` §1.1） |

> **不属于本节的**：某仓库"富文本 H1–H6 是否已对齐""按钮档差是否要调"这类**项目运行时状态**，在项目侧 `memory/全局已知偏差.md`，不写进契约层。
