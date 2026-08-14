# 零容忍硬规则 + 用户硬规则 + 检查清单

本文件是 Path C 的**规则底线**。SKILL.md 里的摘要是索引，判定以本文件为准。
与任何"配方""踩坑经验""效率考虑"冲突时，**一律以本文件为准**。

---

## 一、零容忍硬规则（每个模板审计 + 每次写日志前必查）

### 规则 1 — `disabled: true` 实例必须跳过

任何 `"disabled": true` 的实例：

- **不进**字号总览大表
- **不进**修改前后对比表
- **不动**其 stored 配置值（**即使它偏离 spec 也不改**）

**强制检查命令**（开始审计前先跑，不是事后补跑）：

```bash
# 列出本模板所有 disabled 实例
grep -B 1 '"disabled": true' templates/<template>.json | grep '"type"'
```

把输出的 type + 实例 ID 记进本地 scratchpad，**整个会话期间反复 cross-check**。

> **与 `plaud-theme-impact` 的关系**：disabled 清单的**事实源是 `AssessmentRef.DisabledInstances`**（impact 产出，含实例 ID）。
> 本 skill 跑上面这条命令是为了**交叉验证 + 日志资格判定**（哪些实例不许进表、不许动值），**不是另起一份口径**：
> - 两边结果不一致 → **有一方漏看，停下核对**，不要各报各的
> - `AssessmentRef` 只给了计数、没给实例 ID → 视为 **Assess 工件不完整**，退回 impact 补，**不在本地补算成自己的清单**

### 规则 2 — stored 值为空的 Pre / Sub heading 必须跳过

字号总览**只列实际渲染元素**。每个模块的每个实例都要逐个检查，不能按模块一刀切。

| 模块 | 字段 | 检查命令 |
|---|---|---|
| Slideshow / 各模块 | `pre_heading` / `subheading` / `sub_heading` | `awk '/<module-id>/,/^    \},/' templates/<template>.json \| grep -E '"(pre_heading\|subheading\|sub_heading)":'` |

只要 stored 值是 `""`（空字符串），就**不要**在字号总览里列该元素的字号行。

> ⚠️ 字段名不统一是本规则的主要漏点：`subheading` / `sub_heading` 两种写法并存，标题字段也有例外（Marquee 的标题是 `text_heading`，不是 `heading`）。**批量 grep `"heading"` 会同时漏掉 Marquee、并把空 `heading` 误判成"无区头"**——按模块逐个确认实际渲染的字段名（见 `pitfalls-components.md` §4.13）。

### 规则 3 — 任一条漏看，必须立即回溯修正

写日志中途发现漏看规则 1 或规则 2，**先修正再继续**。
**不允许**"先记着、等下次一起改"——一次漏登记会污染整张合并大表，越往后越难回溯。

---

## 二、用户硬规则（授权边界，非风格偏好）

### 2.1 `templates/*.json` 默认只读

- 删字段 / 改默认值 / hex case 统一 / preset 改动，**一律不连动模板**
- 只有 stored 值本身阻断（如 schema 拒值）等**文档化例外**场景，才谈得上动模板
- 真要动 → **需用户明确批准**，且写进 `BlockingGaps` 等授权，不得先改后说

**已知的受控例外**（每一条仍需用户当次明确批准，不是常设许可）：

| 场景 | 出处 |
|---|---|
| Slideshow 配置层迁移：翻 `disabled`（旧 slider_item 隐藏 / new_slide 启用） | `pitfalls-migration.md` §4.8 |
| 无预置 new_slide 时新建 block、开 `new_banner_enbale` | §4.8.1 / §4.8.2 |
| 验收期保留两张 slide + 临时开导航、签收后收尾 | §4.8.3 |
| 旧版 Multi Content → WW 在模板存值层 1:1 重建 | §4.12 |
| WW 文本块字号/上色在存值层改数字 | §4.12.1 |
| 逐实例补移动端区头对齐字段 | `pitfalls-components.md` §4.13 |

### 2.2 schema setting 已有 option values 永不改

哪怕只是"换个命名风格"（`left` → `start`）**也不行**。
需要不同的 emit 结果时，**只在 Liquid 端做映射**，stored 实例值优先。

**约束对象是"删除或修改既有 `value`"**（会让存量实例存值静默失效）。**纯新增 option 允许**，但要在 `OptionsConsidered` 写清三件事：新 value 的 Liquid 端映射、schema 保存验证、旧存值向后兼容结论（`handoff-schema.md` §8.1 第 9 条）。"新增一律允许、无需验证"不成立。

### 2.2.1 复用既有模块时的存量偏差（v0.2.1）

迁移里常见"这个模块本来就有别的偏差"。按 `handoff-schema.md` §8.1.2：**不要求顺手修**，但三条不放松：

> 🔴 **记在哪、什么时候记**（与下面 §2.3「验收前不动迁移日志」不冲突，v0.2.2 明确）：
> **验收前**只写进 Implement 工件的改动说明 + QA 的 `Advisories`；**验收通过后**才写进迁移日志的待评估项。不要在验收前先往迁移日志里落笔。

三条约束：

1. 必须给出可复跑证据证明该偏差在 `BaseHeadSha` 上已存在；
2. 不得加重，也不得因本次接入让它变成新的可达行为（否则按本次引入判 🔴）；
3. 回归范围仍按 `plaud-theme-impact` 的 `ActualAffectedInstances` 全量，空 / 满配置双测不豁免。

### 2.3 验收前不动迁移日志

- 约束对象是 **UX 差异日志内容**
- **例外**：「进行中 / Owners」认领表属**协调元数据**，不受此约束，随时可更新

### 2.4 新写 hex 一律大写

- 新写的 spec 字符串统一大写（见 `pitfalls-css.md` §4.2）
- **老代码里的小写 hex 不连动改**（连动改会触发 2.1 的模板只读约束）

---

---

## 二·五、前置 — 环境与必读文件

### 运行平台

平台检测：macOS / Linux 用 **Bash**、Windows 用 **PowerShell**。
本包所有命令示例为 Bash（`grep` / `awk` / `sed`），Windows 下**按平台替换**，不要原样假跑。

🔴 **但身份取证是例外，不存在"平台替换"这条路**：`handoff-schema.md` §2.5 的 `plaud_theme_tree` / `plaud_changeset_scope` / `plaud_declared_diff` **只支持 macOS / Linux**（用了 `set -o pipefail`、POSIX 文件模式、`git check-attr -z` 的解析约定；Windows 上典型的 `core.fileMode` 假值与 `core.autocrlf` 为真还会直接命中两道字节保真门）。**不得自己写一份 PowerShell 等价物**——那会是一份行为不同的抄本，算出的 oid 与 QA 用 canonical 重算的必然不等。Windows 环境下取证不可用：对应的 QA / release 检查项填 `Blocked`，理由写「平台不支持 / 字节保真前提不满足」，`Blocked` 不得折算为 pass。

### 必读文件（各自的定位，别找错地方）

| 文件 | 是什么 | 注意 |
|---|---|---|
| `~/Downloads/PLAUD_UX_规范基准_v1.3.md` | spec 源文档（v1.3） | **本地不存在不阻断** —— `spec-value-rules.md` §1 的 v1.3 修订段 + 零容忍 + `pitfalls-*.md` 已充分操作化该 spec |
| `shopify-common/src/util/design-tokens.scss` | token 定义（v1.3 已落实） | 数值的实现出处；spec 层定义见 shared reference |
| `shopify-common/src/util/design-utilities.scss` | **spec utility class 的定义处** | 与 tokens 通过 `src/design-system.js` 打包成**单一 critical CSS bundle**；缺 utility 时补在这里（§4.5） |
| `shopify-common/src/base.css` | **Tailwind preflight + theme legacy 兼容** | 🔴 **不再放 spec 工具类** —— 别去这里找 spec utility，更**不得**把新的 UX Spec utility 写进这个文件 |
| `shopify-claude/ux-spec-migration/shopify-plaud-us/ux-spec-v1.2.md` | 迁移日志 | 文件名仍含 v1.2，但**内含 v1.3 wave**；别因名字对不上而新建一份 |
| `shopify-claude/ux-spec-migration/shopify-plaud-us/MODULE-UX-SPEC-RULES.md` | 队友规则速查 | 给无 `shopify-common` 权限的同事看；全权限 lead 也可作快速参考 |

> 仓库根路径按本地 clone 位置调整（Windows 常见 `D:/shopify/`，macOS 按本地路径）。

---

## 三、检查清单 — 迁移前自检

- [ ] **已确认运行平台**：macOS / Linux 用 Bash、Windows 用 PowerShell。本包所有命令示例都是 **Bash**；
      在 Windows 下 `grep` / `awk` / `sed` **必须换成 PowerShell 等价命令**（`Select-String` 等），
      🔴 **不得原样贴一条跑不了的命令然后当成"已核查"**
- [ ] **已确认取证平台**：§2.5 的三个身份函数只支持 macOS / Linux；在 Windows 上**不得**改写成 PowerShell 版本降级生成，
      身份相关检查项一律 `Blocked`（见上「运行平台」）
- [ ] **已确认必读文件的定位**（下节「必读文件」表）
- [ ] 已读 `memory/模板清单.md` / `memory/模块清单.md` / `memory/全局已知偏差.md`（缺失 → 按 `plaud-theme-shared/SKILL.md`「缺失时的唯一初始化规则」：**默认停机问用户，不得凭空重建**；仅用户确认"首次接入无历史状态"后才可复制 `memory-seed/` 种子）
- [ ] 已拿到 `AssessmentRef`（或已自证 `InlineLite` 豁免），blast radius 数据来自 impact 而非自行重算
- [ ] 已读 spec 对应章节（源文档缺失时据 `spec-value-rules.md` 的 v1.3 修订段执行，不阻断）
- [ ] 已读模块代码 + 当前模板的实例存值
- [ ] 已跑规则 1 的 disabled 命令，清单已落 scratchpad
- [ ] 已跑规则 2 的空 heading 检查，逐实例（不是逐模块）
- [ ] 已识别所有 spec 偏离项
- [ ] 已选定修改入口（模板存值 / schema / 模块代码），且动模板存值的已拿到明确授权
- [ ] 改动**优先 utility class**，其次 token，最后字面量
- [ ] 已按 `pitfalls-*.md` 核对本次命中的踩坑条目（**未读适用条目就动手 = 停机点**）
- [ ] 改动后 JSON 已 node 校验
- [ ] 改动后视觉回归点已列出（断点清单见 `plaud-theme-shared/references/responsive-and-spacing.md`；实跑归 QA）
- [ ] 🔴 删了 schema 字段 / CSS 变量 / `data-*` 属性后，**全仓 grep 残留引用**（CSS `var(--xxx)` / liquid `settings.xxx` / JS `dataset.xxx`），确认无 dangling 再收尾
- [ ] **未动日志内容**，等用户验收

> **共享 snippet / 非 section 模块的迁移**（商品角标 `product-badges.liquid`、价格 `price.liquid`、加购 `buy-buttons.liquid` 等——不在模块清单里、但全站多处引用）：blast radius 比单个 section 大得多，**必须先过 `plaud-theme-impact`**。锁规范色 / 字号时建立 **token + `.xxx-*` 工具类**体系（类设 `--var`、组件 CSS 消费 `var`）；删后台颜色字段时做**九宫格式连带清理**——schema 字段、`theme.liquid`/`password.liquid` 等全局 CSS 变量、各引用文件的 dead `data-*`、动态创建该组件的 JS（改用类、去 `setProperty`），最后跑上面的 dangling-ref 扫描。验证新 `.xxx-*` 类 / token 已 build 进 `design-system.liquid`（**复用别人加的 utility 前也先 grep 确认已 build**）。

---

## 四、检查清单 — 验收后写日志

- [ ] 用户**明确**说了"验收 ok / 加入日志"（沉默、未回复、"看着还行"都不算）
- [ ] 仅记 UX 视觉差异，跳过零视觉变化
- [ ] 模块名用 Shopify 后台显示名
- [ ] 措辞业务可读（无 schema / scheme / class / file path / JS 函数名）
- [ ] 影响等级 + 量化描述（±N px、N 模板可见）
- [ ] 字号总览表更新（合并大表，模块列只填首行）
- [ ] 模块按页面渲染顺序 + 编号
- [ ] 待评估归属正确（单模块 vs 全局）
- [ ] **disabled 实例不登记**（再次确认本模板所有 disabled 列表）
- [ ] **空值 Pre / Sub heading 不列**（再次扫一遍所有模块的相关 stored 值）
- [ ] 已同步更新 `memory/模板清单.md` / `memory/模块清单.md` / `memory/全局已知偏差.md`（格式见 `project-state-schema.md`）
