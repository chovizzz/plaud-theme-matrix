# ReconMode 判定 — 完整边界

字段定义以 `plaud-theme-shared/references/handoff-schema.md` §3 为准。本文件只补判定细节与易错场景。

---

## 判定优先级（唯一顺序）

判据是**本次计划写入集**（预计新增文件 + 预计修改的存量文件），不是当前 git diff。Assess 发生在实现之前，工作树通常干净——用空 diff 推 `IntegrationSurface` 是系统性误判。

```
1. 计划写入集是否包含以下任一？
     a. 任一存量 section / snippet / layout / template / section group
     b. 任一全局 CSS、design token、build 源或 build 产物
     c. 任一会改变存量消费方行为的 schema / locale / config 项
     是 → LegacyImpact（终止判定，不再往下看）
2. 是否纯新建、无存量调用方？
     是 → IntegrationSurface
3. 是否逐条满足 InlineLite 全部 8 项豁免条件？
     是 → InlineLite
     否 / 拿不准 → LegacyImpact
```

第 1 条**不附加"且被其它文件引用"的条件**。`layout/theme.liquid`、`templates/*.json`、section group JSON 通常没有代码层引用方，但它们是运行时入口——改它们就是存量影响。"无其它引用方"只是 InlineLite 的豁免条件之一（第 3 步），不是 LegacyImpact 的门槛。

**兜底方向永远是升级，不是降级。** 判不出来就按 `LegacyImpact` 走完整流程——多做的检查是浪费，漏做的检查是回归。

拿不到计划写入集 → `BlockingGaps` 写明需要上游列出预计新增/修改的文件，不猜。

---

## LegacyImpact（默认）

触发：改动触及已存在的 section / snippet / 全局 CSS / token / build 产物。

**"已存在"包括但不限于**：

- `sections/*.liquid` 中已有的模块
- `snippets/*.liquid`，尤其共享类（`product-item` / `price` / `price-format` / `buy-buttons` / `product-badges` / `section-header` / `section-swiper`）
- 全局 CSS：`critical.css` / `theme.css` / `base_more*` / `design-system` 相关
- design token（`shopify-common/src/util/design-tokens.scss` 等源文件里的变量）
- build 产物及其源
- 已有 section 的 schema 字段（改 / 删 / 改约束）
- `layout/theme.liquid`、已有 `templates/*.json`、已有 section group JSON（运行时入口，无需"被引用"）
- `locales/*.json` 中**已有 key 的值变更 / 改名 / 删除**（改名删除 = 全仓 dangling 风险）

必做：依赖树七层 + 理论/实际影响分离 + 共享传播链 + dangling 核查。

---

## IntegrationSurface（纯新建）

触发：Path B 新建 `sa-*` section，无存量调用方。

**不查**"模板使用量 N"——新模块没有存量调用方，虚构这个数字是把 Assess 变成表演。`TheoreticalReferences` 如实写存量调用方与计划新增接入点，例：

```yaml
TheoreticalReferences: "PreExistingCallers: 0; NewPlannedCallers: templates/page.new-shop.json (本次一并新建)"
```

若计划接入的是**已有**模板或 section group → 模式应已升级为 `LegacyImpact`（见下方边界表）。

**改查复用面与冲突面**：

| 维度 | 查什么 | 命令骨架 |
|---|---|---|
| 可复用 snippet | 有没有现成的能用，避免重复造 | `ls snippets/ \| grep -iE "header\|swiper\|price\|button\|badge"` |
| 是否该复用 `section-header` | 标题层（pre/heading/sub）应走共享区头 | `grep -rn "render 'section-header'" sections/ \| head` |
| 是否该复用 `section-swiper` | 轮播控件不重写 | `grep -rn "render 'section-swiper'" sections/ \| head` |
| 是否该复用 `price-format` | 价格不硬编码货币符号 | `grep -rn "render 'price-format'" sections/ snippets/ \| head` |
| token 冲突 | 新起的 CSS 变量名是否与既有 token 撞名 | `grep -rn "\-\-<new-var>" shopify-common/src/ assets/` |
| BEM 根类名冲突 | `sa-<feature>` 根类是否已被占用 | `grep -rn "sa-<feature>" sections/ snippets/ assets/ shopify-common/` |
| 素材是否误入 `assets/` | 内容图片/视频/icon 不得写死 asset | `grep -nE "asset_url\|asset_img_url" sections/sa-<f>.liquid` |
| schema 完整性 | 展示文案是否都有 setting；空/满配置双态 | `grep -nE '"id":\|"type":\|"label":' sections/sa-<f>.liquid` |
| locales / 数据源 | 引用的 key 是否存在；各语言是否齐全；metaobject/product 字段是否可得 | `grep -rn --fixed-strings '"<key>"' locales/`（JSON key 是双引号；嵌套 key 用 `node -e` 按路径读） |
| bundle 加载方式 | CSS/JS 是同步还是 async；是否进 critical | `grep -nE "stylesheet_tag\|javascript_tag\|defer\|async" sections/sa-<f>.liquid layout/theme.liquid` |
| 接入面 | 是否会被加进某模板或 section group（接入**已有**模板 → 升级 LegacyImpact） | `grep -rn "sa-<feature>" templates/ sections/*.json` |
| **是否计划改共享 snippet** | 见下节 | 看计划写入集；辅助 `git status --porcelain` |

locale 缺语言只作为**事实**列进产出（"key X 仅有 en，缺 de/ja"），由 QA-B 验证，**本 skill 不判 pass/fail**。

---

## 边界场景：新建 section + 触及存量文件

**这是本矩阵最容易选错模式的场景。** 用户说"做一个新的 sa-xxx section"，agent 选 `IntegrationSurface`，但为了让新 section 用上共享区头，计划给 `snippets/section-header.liquid` 加一个参数分支——此时影响面已经不是新建面，而是**所有 render 该 snippet 的模块**。

**规则**：模式由「本次计划写入了哪些文件」决定，不由「用户描述的任务类型」决定。

计划写入集包含任何存量 section / snippet / layout / template / section group / 全局 CSS / token / build 源 → **`LegacyImpact`**。此时输出**两套**内容：

1. 对存量文件走完整 LegacyImpact（依赖树 + 理论/实际影响 + 传播链）
2. 新建部分的复用面/冲突面检查照做

`ReconMode` 只填 `LegacyImpact`（字段是单值），在正文注明"主体为 Path B 新建，因计划写入存量共享文件 `<path>` 升级为 LegacyImpact"。`RequiredQAProfile` 相应写 `QA-A, QA-B`（`QA-Global` 由 QA 按 §5 恒执行，不写进字段）。

**范围漂移 → 退回重评**：Implement 阶段若开始修改任何原计划外的存量共享/入口文件，原 `AssessmentRef` **失效**，必须重新调用本 skill 做 Assess——不得在实现收尾时补一句"顺便升级为 LegacyImpact"就算数。

### 边界速查表

| 场景 | ReconMode |
|---|---|
| 新 section 只 render 已有 snippet，不改该 snippet | `IntegrationSurface` |
| 新 section 需要改共享 snippet（哪怕新分支默认不影响旧调用方） | `LegacyImpact` |
| 新 section 的 scoped CSS 全在新文件里 | `IntegrationSurface` |
| 在已有全局 CSS 里加一条只匹配 `.sa-*` 的规则 | `LegacyImpact`（契约明确：触及全局 CSS） |
| 新 asset 只被新 section 使用 | `IntegrationSurface` |
| 新 asset 被接进 `layout/theme.liquid` 或全局 bundle | `LegacyImpact` |
| 在已有 token 源里新增 token | `LegacyImpact`（契约明确：触及 token） |
| 新 section 改了已有 schema 字段或约束 | `LegacyImpact` |
| 只改新 section 自己文件里的 schema / presets | `IntegrationSurface` |
| 新 section 与其模板**同为本次新建** | `IntegrationSurface`；`TheoreticalReferences` 注明 NewPlannedCallers |
| 新 section 被加进**已有**模板 / section group | `LegacyImpact` + 保留 Path B 全部检查；`RequiredQAProfile: QA-A, QA-B` |
| 新 section 加进已有模板但设 `disabled: true` | `LegacyImpact`（模板被改）；实际影响可为 0，`DisabledInstances` 单列 |
| 在已有 locale 文件里**新增**一个仅供新 section 用的 key | `IntegrationSurface`（additive，无存量消费方） |
| 改已有 locale key 的**值** | `LegacyImpact` |
| **重命名 / 删除**已有 locale key | `LegacyImpact` + dangling 核查 |
| 新增 key 的同时改已有 section 去消费它 | `LegacyImpact` |
| 新增 key 只加了部分语言 | 不因此升级；缺语言作为事实列出，交 QA-B 验证 |

---

## InlineLite（严格豁免）

八条**全部**满足才成立：

1. 改动 ≤ 1 个文件
2. 该文件无其它引用方 —— 必须有 grep 证明
3. 非共享 snippet
4. 非全局 CSS
5. 非 design token
6. 非 build 产物
7. 不改 schema
8. 不改模板存值

证明命令：

```bash
grep -rn "<filename-without-ext>" sections/ snippets/ templates/ layout/ assets/ shopify-common/
```

零命中（除文件自身）才算"无其它引用方"。

### 典型的"看起来像但不是 InlineLite"

| 场景 | 为什么不是 |
|---|---|
| 只改一个 section 的一行 CSS | 该 section 有多个模板实例 → 有引用方 |
| 只改一个 CSS 变量的值 | token → 全站消费方 |
| 只改一个 schema 的 label 文案 | 改了 schema |
| 只改 `assets/sectionsTT.min.css` 一行 | build 产物 |
| 只在某 snippet 里加一个 `{% if %}` | 共享 snippet |
| 改一个只有一个实例的 section 的 JS | JS 可能继承自基类 / 被其它模块引用 → 先 grep 再说 |
| "这文件应该没人用吧" | **拿不准就不是 InlineLite** |

### 豁免成立时

实现 skill 可自行内联完成评估，但仍须在自己的 HandoffContract 写 `ReconMode: InlineLite` + 豁免理由。若本 skill 被显式调用，照常输出完整 §3 yaml 块：`TheoreticalReferences: 0`、`ActiveInstances` / `DisabledInstances` 据实、`ActualAffectedInstances: 1 + 清单`、`SharedPropagation: None (verified by grep)`、`RiskTier: Low`，`EvidenceCommands` 带上那条证明无引用方的 grep。
