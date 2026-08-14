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

阶段单向推进：`Assess → Implement → Verify`。不得跳过 Assess 直接 Implement，除非满足 §3 的 `InlineLite` 豁免条件。**任何情况下不得跳过 Verify。**

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

---

## 2. ChangeSetId 绑定

`ChangeSetId` 是把「谁改的」和「谁验的」焊在一起的唯一凭据。QA 验的必须**就是**实现 skill 交出的那批改动。

**格式**：`CS-<YYYYMMDD>-<path><NN>`，例如 `CS-20260806-A03`、`CS-20260806-C11`。
- `<path>` ∈ `A` / `B` / `C`
- `<NN>` 为当日该路径的序号，从 `01` 起

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
  {
    git rev-parse HEAD                                              || return 1
    git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' || return 1
    git diff HEAD --no-renames --binary                             || return 1
    # 未跟踪文件 git diff 看不到，逐个 hash + 记权限
    git ls-files --others --exclude-standard -z | tr '\0' '\n' | sort | while IFS= read -r f; do
      [ -n "$f" ] || continue
      printf '%s %s %s\n' "$f" "$(git hash-object -- "$f")" \
        "$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f")"
    done                                                            || return 1
  } | shasum -a 256 | cut -d' ' -f1
)
plaud_fingerprint || echo "FINGERPRINT_FAILED"
```

> 🔴 **绝不可省略 `set -o pipefail` 与各段的 `|| return 1`。** 任何一段静默失败时，管道仍会继续，`shasum` 会对残缺输入求值，算出一个**看似正常、实则与内容无关**的常量——校验因此永远通过，P0 漏洞原样复活。
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

### 零改动任务（只读审计 / code review / A11y 审计）

统一记为 `ChangeSetId: N/A` + `ModifiedFiles: []`。此类任务：

- **免 Assess**——`AssessmentRef` 填 `N/A(ReadOnly)`
- **免 QA**——`NextRequiredSkill` 填 `None`，`ReadyForDelivery` 填 `N/A(ReadOnly)`
- **不得借用 `ReconMode: InlineLite`**。只读与 InlineLite 是两回事：InlineLite 是"改动小到可以内联评估"，只读是"根本没有改动"。混用会让只读任务继续输出 `QAStatus: NotRun` / `ReadyForDelivery: No`，与本节取值冲突。只读任务的 `ReconMode` 填 `N/A(ReadOnly)`。
- **不免措辞禁令**：审计结论只能陈述"发现了什么"，不得断言"这个模块没问题 / 可以上线"

#### 🔴 零改动必须有证明，不能靠自称

否则可以先改代码、再输出 `ModifiedFiles: []` 并声称"这只是审计"，从而完全绕开 QA。审计**开始前**和**结束后**各取一次快照，两次必须完全一致：

```bash
git rev-parse HEAD
git status --porcelain -z --untracked-files=all | tr '\0' '\n' | sort | shasum -a 256
```

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
Path:                     # A | B | C
ReconMode:                # 与 Assess 一致；InlineLite 需附豁免理由；只读填 N/A(ReadOnly)
ModifiedFiles:            # 逐个文件路径 + 一句话改动；必须与工作树一致；零改动填 []
RootCause:                # 机制层根因（bugfix / 迁移偏差）；新建 section 填 N/A
OptionsConsidered:        # 非平凡任务 ≥2 方案 + 取舍；平凡改动填 Trivial
RequiredQAProfile:        # QA-A | QA-B | QA-C（可多选）。不要填 QA-Global——它由 QA 按 §5 恒执行，无需任何上游声明
ThemeCheckRequired:       # Yes | No（判定见 §6）
VisualRegressionRequired: # Yes | No
BuildRequired:            # Yes | No（是否动了 shopify-common/src 需 npm run build）
BlockingGaps:             # 实现中发现但无权处理的（如需模板存值编辑授权）
QAStatus: NotRun          # 恒为 NotRun；唯一例外是用户明确弃检时填 Skipped(UserWaived)，见 §1.5
NextRequiredSkill: plaud-theme-qa   # 零改动任务填 None
ReadyForDelivery: No      # 恒为 No，见 §1；零改动任务填 N/A(ReadOnly)
```

> ⚠️ 上面每个 `key:` 与注释之间都有空格。YAML 里 `Key:# 注释` 是解析错误（`#` 会被当成值的一部分或直接报错），照抄时不要压掉那个空格。

---

## 5. Verify 阶段工件（`plaud-theme-qa` 产出）

每项检查的取值只能是 `Passed` / `Failed` / `Blocked` / `NotApplicable`，**不得**用勾选框或"已检查"。`Blocked` 必须附原因。

```yaml
ChangeSetId:             # 被验的那个
ChangeSetIdMatched:      # Yes | No —— 必须同时校验文件集合、ChangeSetFingerprint、BaseHeadSha（见 §2）
FingerprintVerifiedAt:   # Step1(验证前) / Step2(验证后) 两次重算的指纹，必须都与工件一致
QAProfilesRun:           # 实际跑了哪些 profile
ThemeCheck:              # Passed | Failed | Blocked | NotApplicable
ThemeCheckEvidence:      # CLI 版本 / 检查目录 / exit code / baseline 增量数（见 §6）
ThemeRuntimePreview:     # Passed | Blocked | NotApplicable
AdminSchemaSave:         # Passed | Blocked | NotApplicable
RegressionMatrix:        # Passed | Failed | Blocked（附覆盖的断点与状态）
BreakpointsCovered:      # 实际验过的断点，Path C 为 PC/1599/1279/767/375
LocalizationCheck:       # Passed | Failed | Blocked | NotApplicable（英译德长文案）
A11yCheck:               # Passed | Failed | Blocked | NotApplicable
FixedDimensionCheck:     # Passed | Failed | Blocked | NotApplicable（组件写死宽高；例外须已说明理由）
ImageQualityCheck:       # Passed | Failed | Blocked | NotApplicable（图片清晰度红线）
CopyConfigurabilityCheck: # Passed | Failed | Blocked | NotApplicable（展示文案走 schema/locales）
ProfileSpecificResults:  # 各 profile 的逐项结果
Evidence:                # 命令原文 + 输出摘要；不接受"我看过了"
BlockingGaps:
ReadyForDelivery:        # Yes 仅当上述全部为 Passed 或 NotApplicable
```

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
5. A11y 底线：button 语义、aria-label、dialog trapFocus、轮播 button + aria-label、对比度 ≥ 4.5:1、skip link、focus-visible
6. JS：null 守卫、TDZ 安全，监听 / timer / observer / subscription 在 `disconnectedCallback` 清理
7. 生成文件（build 产物）勿手改，改动落到源 + 重新 build
8. 最终交付必须经 `plaud-theme-qa`（§1）

---

## 9. 输出块格式

每个 skill 回复的**最后**必须是一个 ` ```yaml ` 代码块，内含该阶段对应的字段（§3 / §4 / §5）。字段缺失视为契约违规。正文可以自由组织，但契约块不得省略、不得改名、不得塞进正文段落里。

### 9.1 协调工件（`plaud-theme-orchestrator` 专用）

orchestrator **不是阶段 producer**——它不产生影响面事实、不产生代码改动、不产生验证结论，因此不使用 §3 / §4 / §5 的任何模板。它输出的是协调工件：

```yaml
ArtifactKind: Coordination
OrchestrationId:          # ORCH-<YYYYMMDD>-<NN>
PathResolved:             # A | B | C | Cross(B+C) | Cross(A+C)
ChangeSetPlan:            # 拆出的每个 ChangeSet：编号 / 范围 / 归属 skill / 依赖关系
ParallelSafe:             # 哪些 ChangeSet 可并行；碰同一文件的必须串行
ChangeSetStatus:          # 各 ChangeSet 当前阶段与 handoff 引用
BlockingGaps:
AllChangeSetsDelivered:   # Yes | No —— 全部下辖 ChangeSet 的 QA 均为 ReadyForDelivery: Yes 时才为 Yes
```

`AllChangeSetsDelivered` 是**汇总读数，不是交付许可**。它只能反映各 ChangeSet 的 QA 结论，orchestrator 不得据此自行宣布可交付，也不得在任一 ChangeSet 的 QA 未通过时置 Yes。交付权仍然只在 `plaud-theme-qa`（§1）。

### 9.2 字段取值枚举

以下字段的取值是**封闭枚举**，不得自造：

**阶段契约字段**（§3 / §4 / §5 / §9.1 的 yaml 块内）：

| 字段 | 允许值 |
|---|---|
| `QAStatus` | `NotRun` \| `Skipped(UserWaived)` |
| `ReadyForDelivery` | `Yes`（仅 QA）\| `No` \| `N/A(ReadOnly)` |
| `ReadyForImplement` | `Yes` \| `No` |
| `ChangeSetIdMatched` | `Yes` \| `No` |
| `ReconMode` | `LegacyImpact` \| `IntegrationSurface` \| `InlineLite` \| `N/A(ReadOnly)` |
| `RiskTier` | `Low` \| `Medium` \| `High` |
| `RequiredQAProfile` | `QA-A` \| `QA-B` \| `QA-C`（可多选）。**不含 `QA-Global`**——它由 QA 恒执行并记入 `QAProfilesRun`，任何上游工件写它都是违规 |
| `ThemeCheck` / `RegressionMatrix` / `LocalizationCheck` / `A11yCheck` / `ThemeRuntimePreview` / `AdminSchemaSave` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `FixedDimensionCheck` / `ImageQualityCheck` / `CopyConfigurabilityCheck` | `Passed` \| `Failed` \| `Blocked` \| `NotApplicable` |
| `ArtifactKind` | `Coordination`（仅 orchestrator；阶段 skill 不填此字段） |
| `AllChangeSetsDelivered` | `Yes` \| `No` |

> **`Blocked` 与 `Failed` 不可混用。** `Failed` = 验了、发现缺陷（实现 skill 应去修）；`Blocked` = 该验但没验成（用户豁免、ChangeSet 失配、工具不可用）。把未执行填成 `Failed` 会让下游去追不存在的缺陷；填成 `Passed` 或无证据的 `NotApplicable` 则是谎报。两者都不允许。

阶段契约字段出现枚举外的值（如 `Done`、`Partial`）一律视为违规。需要表达枚举覆盖不到的状态时写进 `BlockingGaps` 正文，不要新造取值。

**`memory/` 记录字段**（不是阶段契约，单独一套枚举）：

| 字段 | 允许值 | 位置 |
|---|---|---|
| `QAStatus` | `Pending` \| `Valid` \| `Invalidated` | `changeset-log.md` |
| `VisualAcceptance` | `Pending` \| `Accepted` | 迁移状态文件 |
| 模块 / 模板迁移态 | `待办` \| `进行中` \| `已迁`（需 QA 背书，见 shared SKILL.md） | 模板/模块清单 |

`Invalidated` 在 `changeset-log.md` 里是**合法**取值（表示该 QA 结论已因代码变化失效）；它只是不允许出现在阶段契约块里。两套枚举互不通用。
