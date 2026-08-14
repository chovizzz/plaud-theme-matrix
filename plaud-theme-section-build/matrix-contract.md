# Matrix Contract — `plaud-theme-section-build`

矩阵位置：**Path B × Implement**，order 4。字段定义以 `plaud-theme-shared/references/handoff-schema.md` 为准，本文件只描述交接关系，**不重复定义字段、不新增字段**。

```
plaud-theme-impact (Assess, IntegrationSurface)
        │  AssessmentRef / ReconMode / SharedPropagation / RequiredQAProfile / ReadyForImplement
        ▼
plaud-theme-section-build (Implement, Path B)      ← 本 skill
        │  ChangeSetId (CS-<YYYYMMDD>-B<NN>) / BaseHeadSha(开工前) /
        │  ObjectFormat + ThemeTreeOid + ChangeSetScopeFingerprint
        │  ModifiedFiles / RequiredQAProfile
        │  QAStatus: NotRun / ReadyForDelivery: No
        ▼
plaud-theme-qa (Verify, QA-B + QA 恒执行的 QA-Global)
        │  ChangeSetIdMatched / 各项 Passed|Failed|Blocked|NotApplicable
        ▼
     ReadyForDelivery: Yes  ← 只有 QA 能给
```

---

## 1. 上游：`plaud-theme-impact`

**必须消费的字段**：

| 字段 | 本 skill 怎么用 |
|---|---|
| `AssessmentRef` | 原样抄进自己的 handoff |
| `ReconMode` | Path B 常态 `IntegrationSurface`；本 skill 保持一致，除非触发升级（见 §3） |
| `SharedPropagation` | 确认哪些既有 snippet 可复用、复用点的参数差异 |
| `EntrypointCandidates` | 判断新 section 接入模板是否需要授权 |
| `RiskTier` / `RequiredQAProfile` | 作为自己 `RequiredQAProfile` 的下限 |
| `BlockingGaps` / `ReadyForImplement` | 非空 / `No` 时**不得开工** |

**拿不到 Assess 工件** → 停机要它。`InlineLite` 豁免对 Path B 基本不成立（新建 section 至少涉及 schema）。

**`IntegrationSurface` 关注面**（Assess 给出，实现时复核）：可复用 snippet（`section-header` / `section-swiper` / `price-format`）、`sa-<feature>` 命名与 BEM 根类冲突、素材是否误入 `assets/`、schema/locales/数据源完整性、bundle 加载方式、是否接入模板或 section group、是否顺手改了共享 snippet。

---

## 2. 下游：`plaud-theme-qa-intake` → `plaud-theme-qa`

> 🔴 **v0.2.0 起先过 `plaud-theme-qa-intake`。** `NextRequiredSkill` 填 `plaud-theme-qa-intake`；提测包 `SubmissionPackageStatus: Complete` 之后 QA 才启动（handoff-schema §9.1.2）。下文关于 QA 的内容仍然成立，只是多了一道前置关口。

交出 `handoff-schema.md` §4 的 yaml 块，其中：

- `ChangeSetId` 格式 **`CS-<YYYYMMDD>-B<NN>`**，`<NN>` 为当日 Path B 序号，从 `01` 起
- 身份三元组（`ObjectFormat` + `ThemeTreeOid` + `ChangeSetScopeFingerprint`）**必须在交付工件那一刻现场生成**（函数见 `handoff-schema.md` §2.5，整段原样复制）；`BaseHeadSha` 相反，**必须在开工前取**（写成交付时 HEAD 会让所有声明路径落进 `DECLARED_DIFF_UNCHANGED`、QA 恒阻断）。QA 在**任何检查之前**重算三元组并逐字比对，用来堵"交付后、QA 前偷改同一批文件"——只绑文件名挡不住它
- `ModifiedFiles` **必须与工作树一致**——不一致 QA 会输出 `ChangeSetIdMatched: No` 并停机，不得让 QA"顺便一起验了"
- `RequiredQAProfile` 至少含 `QA-B`。🔴 **不含 `QA-Global`**——它由 QA 按 §5 恒执行，写进上游工件是字段越界（§9.2）
- `QAStatus: NotRun`、`ReadyForDelivery: No` 恒定

QA-B 会验的（实现侧须自检但**无权判定**）：`sa-*` / `SA:` / BEM 根类名、vendor §1–§12、素材来源（未写死 assets）、schema 完整性、空配置与满配置双测、多语言。QA-Global 由 QA 恒执行（Theme Check、5 断点、英译德长文案、A11y 底线、组件写死宽高、图片清晰度、展示文案可配置性），**不需要也不允许**由本 skill 声明。

**QA 通过后代码再变，原 QA 自动失效**，须重新生成 `ChangeSetId` 并重跑。

---

## 3. 侧向：升级为 `LegacyImpact` 回 impact 重评

> **只要以任何方式写入（修改 / 删除 / 重命名 / 移动）了任何一个存量文件，`IntegrationSurface` 立刻升级为 `LegacyImpact`——哪怕主体工作是新建 `sa-*` section。**

**判定门是「有没有写入存量文件」，不是「能不能找到调用方」**——静态引用数只用于算影响面，不作为是否升级的门。

触发清单（命中任一即升级）：任何既有 snippet（`section-header` / `section-swiper` / `price-format` / `product-item` / `critical-style` …）、全局 CSS（`critical.css` / `theme.css` / `base_more*` / design-system 样式表）、design token 或全局 CSS 变量、color scheme、build 产物或其源（`shopify-common/src/**`、`snippets/design-system.liquid`、`assets/*.min.css`）、既有 section 或既有 schema 字段、`templates/*.json` 与 section group JSON、`layout/`、`config/`、`locales/*.json` 的既有 key（只新增独立 namespace 且无同名碰撞的全新 key 除外，须 grep 证明）、以及**虽是新增但被全局 bundle / manifest / 约定式 loader 自动消费的文件**。

判定：

```bash
# 🔴 用 SKILL.md 里的 tree diff 流程（① 开工前 plaud_theme_tree + sb_baseline_overlap，
#    ③ 收尾 plaud_theme_tree + plaud_changeset_scope，④ plaud_declared_diff，⑤ base-tree 查询）。
#    📎 v0.3.0 起解除：v0.2.3 那句「不要跑裸 git diff」是针对已废弃的名字集合采集法说的，
#    新模型下判据是两棵 tree 的对象比较，`git diff <tree-oid> <tree-oid>` 正是正确写法。
#    📎 v0.2.3 曾担心的两件事在新模型里被构造性解决：未跟踪文件由空白临时索引下的
#    `git add -A -f` 自己枚举（新建的 sa-* 不会被漏掉）；`memory/` 不在可发布面内，
#    合法的 memory/ 更新不会被当成存量主题修改而错误升级。
BASE_HEAD_SHA=$(git rev-parse HEAD)                      # 开工前取
sb_baseline_overlap "$BASE_HEAD_SHA" "$PATHLIST"         # 开工前：声明路径不得已脏
# 收尾：声明路径里哪些在 baseline commit 里就已经存在 → 非空即升级 LegacyImpact
set --
while IFS= read -r p; do [ -n "$p" ] && set -- "$@" ":(literal)$p"; done < "$PATHLIST"
git -c core.hooksPath=/dev/null -c core.fsmonitor=false \
    ls-tree -r --full-tree -z "$BASE_HEAD_SHA^{tree}" -- "$@" | tr '\0' '\n' | sed '/^$/d' | cut -f2-
```

开工前先存 baseline，只判定**本 ChangeSet 新产生的**变化；不要用 `git status --porcelain` 首列过滤（`AM` 会被误判为存量改动）。

拿不准（有无调用方、是否被自动打包、locale key 有无碰撞）→ **按 LegacyImpact 处理**（保守方向永远是升级，不是降级）。

升级后：`ReconMode: LegacyImpact`、换用重评后的 `AssessmentRef`、`RequiredQAProfile` 升为 `QA-A, QA-B`（**不写 `QA-Global`**）、动了 `shopify-common/src` 则 `BuildRequired: Yes`、正文单列"存量文件改动"段。

**不得**为规避升级而把共享 snippet 的逻辑复制一份进 `sa-*`（分叉 + 双事实源，比升级更坏）。

---

## 4. 路径归属与误路由

| 用户诉求 | 归属 |
|---|---|
| Figma / 设计稿 / 新建 `sa-*` / Section AI / SA: schema | **本 skill** |
| 改已有 section 的 bug / 性能 / 新功能 / UX 微调 / A11y / review | `plaud-theme-dev`（Path A） |
| UX Spec v1.3 迁移 / 刷模块 / 对齐 ux / 迁移日志 | `plaud-theme-ux-migration`（Path C） |
| 影响面、blast radius、依赖树、实例数 | `plaud-theme-impact` |
| 验收、能不能上线 | `plaud-theme-qa` |
| 需拆成 ≥2 个可独立验收 ChangeSet 的工作（迁移 wave、跨多个互不相干模块的批量改动） | `plaud-theme-orchestrator` |

**B + C 交叉**（新建 section 且明确要求对齐 v1.3 spec）——与 `MATRIX.md` / orchestrator 一致的唯一口径：

- **单一 ChangeSet 能装下的 B+C → 直接由本 skill 实现，不绕 orchestrator。** 实现规则用 Path B 的、spec 取值用 Path C 的；`RequiredQAProfile` 为 `QA-B, QA-C`（**不写 `QA-Global`**）。
- **只有当这项工作还需要拆出第二个可独立验收的 ChangeSet 时**（如新建 section 之外还要刷一批存量模块），才先进 `plaud-theme-orchestrator` 编排，由它调用本 skill 做其中的 B 部分。

判据是「**要不要拆成 ≥2 个可独立验收的 ChangeSet**」（与 shared SKILL.md 的 orchestrator 进入门槛同一条），**不是**「有没有跨路径」。Path A 的质量规则全局继承，永远适用。

**新建 section 冲突到已有 `sa-<feature>`** → 那是"改已有"，路径不是 B，转 `plaud-theme-dev`。

---

## 5. 数值单一事实源

视觉与 UX 数值（字号 / 字重 / 颜色 / 间距 / 断点 / 弧角 / 容器宽度 / 图片清晰度阈值）的**唯一持有者是 `plaud-theme-shared/references/`**。本 skill 的所有文件只引用文件名，**不复制任何数值**。发现本 skill 文件里出现了具体数值 → 视为契约违规，删掉并改为引用。

---

## 6. 本 skill 无权做的事

- 输出 `ReadyForDelivery: Yes`（唯一归 `plaud-theme-qa`）
- 使用终态措辞（「交付完成」「上线可用」「全部通过」「可以发布」「已验收」）；允许的只有「改动已就位，待 QA」
- 自行做影响面评估替代 `plaud-theme-impact`
- 批准编辑 `templates/*.json` 存值
- 擅自决定等距两可的 spec 取值、擅自新增 color scheme、擅自新增按钮类名或非标尺寸、擅自把素材放进 `assets/`
