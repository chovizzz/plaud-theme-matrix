# RiskTier、QA Profile 与 EntrypointCandidates

---

## 1. RiskTier

**判定顺序：先 High、再 Medium、最后才 Low。** 不取平均、不取"主要感觉"。

| Tier | 判定规则 |
|---|---|
| **High** | **任一**命中：改共享 snippet；改全局 CSS；改 design token；改 build 源里的**共享组件 / 全局样式 / token**；token→class 重构；`ActualAffectedInstances` > 10；JS 基类或继承链；pub/sub 事件名/payload 变更；跨路径交叉（B+C、A+C）；**`ActualAffectedInstances` 无法逐项核实清** |
| **Medium** | 未命中 High，且**任一**命中：`ActualAffectedInstances` 2–10；改 schema（含放宽 step/min/max）；改单个 section 的共享行为；存在待核的 dangling 引用；改 build 源里**仅作用于单模块**的 scoped 样式/脚本（需 build，但作用域不跨模块）；改动落在 critical bundle |
| **Low** | **全部**满足：单文件；已 grep 证明无其它引用方；`ActualAffectedInstances` ≤ 1；不碰 schema / token / 全局 CSS / build 源或产物 / JS 基类；**且该文件不是运行时入口**（`layout/*.liquid`、已有 `templates/*.json`、已有 section group JSON） |

> Low 行是"全部满足"，不是"任一命中"——否则"只改一个文件"就能把全局 CSS 判成 Low。High / Medium 行才是"任一命中"。

### 不得降档的三种情形

1. **收敛不下来** → High，不得用"估计不大"降到 Medium
2. **"只改一行"** → 行数不是维度，影响面才是
3. **"这是紧急修复"** → 紧急性不改变影响面事实

### 允许降档的唯一方式

拿出证据把 `ActualAffectedInstances` 真正收敛下来（走 `theoretical-vs-actual.md` 步骤 3），并把剔除理由逐条写进清单。降档必须在 `EvidenceCommands` 里留下可复算的命令。

---

## 2. RequiredQAProfile

Profile 覆盖内容以 `plaud-theme-shared/references/handoff-schema.md` §5 为准。§3 的 `RequiredQAProfile` 取值只能是 `QA-A` / `QA-B` / `QA-C`（可多选）。

> **`QA-Global` 不写进 `RequiredQAProfile`。** 它是 §5 规定的 Verify 阶段恒执行项，由 `plaud-theme-qa` 自动叠加，与路径无关。正文可以提醒"QA-Global 恒执行"，字段值里不要出现——那是把 Verify 阶段的行为塞进 Assess 字段的枚举值。

| 场景 | RequiredQAProfile |
|---|---|
| Path A — 改已有模块 / bug / 性能 / A11y / review | `QA-A` |
| Path B — 新建 `sa-*`（纯新建） | `QA-B` |
| Path C — UX Spec 迁移 | `QA-C` |
| Path B 主体但计划写入存量共享文件（ReconMode 已升级为 LegacyImpact） | `QA-A, QA-B` |
| Path C 迁移中同时修 bug / 性能 | `QA-A, QA-C` |
| `RiskTier: High`（任何路径） | 在上述基础上**至少追加 `QA-A`**——同族 bug 扫描、依赖树回归、旧 section 连带影响 |

### 追加触发器（命中即在 Profile 里点名）

| 本次改动包含 | 提示 QA 重点关注 |
|---|---|
| token→class 重构 | 全实例覆盖回归（`QA-A` 依赖树回归） |
| 删 schema 字段 / CSS 变量 / `data-*` | dangling 引用（`QA-A`） |
| 改 Swiper 配置或 effect | Swiper effect 约束（`QA-A`） |
| 改 JS 生命周期 / 基类 | 监听 / timer / observer / subscription 清理（`QA-A`） |
| 改 `shopify-common/src/**` | 触及 build 源，产物需重新 build 后再验（`BuildRequired` 由实现 skill 填，本 skill 不代填） |
| 改展示文案 / schema label | 英译德长文案（QA-Global 项，恒执行） |
| 改布局 / 断点 | 5 断点回归（QA-Global 项；Path C 断点集见 handoff-schema §5） |

本 skill 只**选 profile** 并点名重点，**不代替 QA 判定通过与否**，也不输出 `ReadyForDelivery`。

### 措辞纪律

Assess 报的是**事实**，不是检查结论。禁止写"schema 完整性通过""素材检查通过""bundle 加载正确""多语言合格"。改写成：

- "发现 / 未发现缺失项：<清单>"
- "引用位置清单：<清单>"
- "当前加载方式：<同步 / async / critical>"
- "需要 QA-B 验证的风险点：<清单>"

---

## 3. EntrypointCandidates

三层入口，各自的影响范围与风险。**本 skill 只列候选，不选、不批准。**

| 层 | 会改哪类文件 | 影响范围 | 风险 | 前置 |
|---|---|---|---|---|
| **模板存值** | `templates/*.json` 的实例 settings | 仅该模板的该实例 | 低 | `templates/*.json` 默认只读——实际编辑需用户明确批准 |
| **schema 配置** | section liquid 内的 schema 定义 | 该模块所有**新建**实例；既有 stored 值不变，但产生向后兼容要求 | 中 | — |
| **模块代码** | liquid / SCSS / JS | 该模块**所有命中该代码路径的现存实例** | 高 | 落在 `shopify-common/src/**` 时触及 build 源 |

### 每个候选只报事实

- 必须修改的文件类别
- 会影响哪些既有 / 新建实例（引用已核实的 `ActualAffectedInstances` 清单，不另起一套数字）
- 是否需要模板编辑授权
- 是否产生向后兼容要求
- 是否触及 build 源
- 当前还缺哪些证据

**禁止措辞**：推荐、建议、倾向、最稳、应该选、直接锁定、根本性修复。这些是实现选型，属于 `plaud-theme-dev` / `-section-build` / `-ux-migration` 的 `OptionsConsidered`。

`ActiveInstances` 规模是选层的**输入之一**，报数字与清单即可，**不附带"这个规模通常该改哪层"的倾向表**——那等于替实现 skill 做了决定。

### 输出格式

```
EntrypointCandidates:
  - Entrypoint: 模板存值 templates/page.about.json → custom_html_a1b2.settings.padding_top
    影响范围: 仅 page.about 的该实例
    风险: 低
    前置: templates/*.json 默认只读 —— 若选此入口需用户明确批准（仅为候选，未单独阻塞）
  - Entrypoint: schema — sections/custom-html.liquid 的 padding_top step 约束
    影响范围: 该模块所有新建实例；22 个既有实例 stored 值不变
    风险: 中（旧值向后兼容需确认）
  - Entrypoint: 模块代码 — sections/custom-html.liquid 样式层
    影响范围: 该模块全部 22 个启用实例（清单见 ActualAffectedInstances）
    风险: 高
```

每个候选必须带：入口路径、影响范围（引用已核实的实例清单）、风险、前置条件。**不写"建议选 X"。**

---

## 4. 与 BlockingGaps 的联动

以下情形必须同时写进 `BlockingGaps` 并置 `ReadyForImplement: No`：

- `ActualAffectedInstances` 未收敛 → 要材料（哪个模板的存值 / 哪份是加载入口 / 哪些方案被自定义过）
- 找不到目标文件 → 要路径
- 拿不到本次计划写入集 → 要清单（预计新增文件 + 预计修改的存量文件）
- `memory/模板清单.md` / `memory/模块清单.md` 缺失且本次评估依赖它 → 停下问用户，**不得凭空重建**
- **模板存值授权**——仅当以下任一成立时才进 `BlockingGaps`：
  1. 用户已指定模板存值为目标入口
  2. 其他入口已被事实排除，模板存值是唯一可行入口
  3. 完成本次 Assess 所需的 stored 值本身读不到
  4. 上游要求评估实际的模板修改，但未授权读取 / 编辑目标文件

### 不要过度阻塞

`EntrypointCandidates` 按设计几乎总会列出三层候选，其中必含模板存值。**"模板存值是候选之一"不是停机理由**——共享契约 §7 的停机条件是"模板存值**需要编辑**但未获授权"，不是"模板存值可能被选中"。

模板存值只是候选之一时：在该候选条目里写明"若选此入口需用户明确批准"，`ReadyForImplement` 照常按其它条件判定。

`BlockingGaps` 每条写明：**缺什么 + 需要用户提供什么 + 拿到后能解开哪个字段**。
