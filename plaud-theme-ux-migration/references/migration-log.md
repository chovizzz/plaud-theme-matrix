# 日志登记规范（第六步）+ 典型异常处理（第七步）

> 🔴 **写日志的前提**：用户**明确验收通过**。这是用户硬规则（`hard-rules.md` §2.3），
> 约束对象是 **UX 差异日志内容**；「进行中 / Owners」认领表属**协调元数据**，不受此约束。
>
> ⚠️ 「验收通过」指用户对**视觉预览**的确认（`VisualAcceptance: Accepted`），与 `plaud-theme-qa` 的 `ReadyForDelivery` 是**两件正交的事**。
> 用户视觉验收通过 → 可以写日志；但**仍不得**输出 `ReadyForDelivery: Yes`（那是 QA 的唯一权限）。
>
> 🔴 **更重要的是：视觉验收也不能把 `memory/` 里的状态推进为完成态。**
> `✅ DONE` / `已迁` / `已修` 需 QA 背书（changeset-log 中对应 `ChangeSetId` 的 `ReadyForIntegration: Yes` + 覆盖它的 `ReadyForDelivery: Yes` 工件存在，且身份三元组未失效），
> 只有视觉验收时写 `视觉已确认，待 QA（<ChangeSetId>）`。规则见 `plaud-theme-shared/SKILL.md` 与 `project-state-schema.md`。
> **日志可以写，完成态不能写**——这两件事的门槛不同。

---

## 6.1 何时登记

- 用户**验收通过**才登记
- **仅记 UX 视觉差异**。纯 token / hex case / 注释 / 结构重构等代码层改动**不登记**
- **零视觉变化**的同色 / 同值替换**不登记**

## 6.2 文件位置

```
shopify-claude/ux-spec-migration/shopify-plaud-us/ux-spec-v1.2.md
```

（文件名仍含 v1.2，但内含 v1.3 wave —— 不要因为名字对不上而新建一份。）

同目录还有 `MODULE-UX-SPEC-RULES.md`（队友规则速查，见 `team-collaboration.md`）。

## 6.3 文档结构

```markdown
# PLAUD UX Spec v1.2 Migration Log — US

## 登记规则
（影响等级定义、模块名约定、按模板分组）

## page.<template-name>.json

### 全页字号总览（本模板配置下实际渲染的文字层级）

> 仅列实际渲染元素（stored 值为空的 Pre / Sub heading 不列）；⚠️ = 非 spec 值或模块未做 spec 迁移

| 模块 | 元素 | PC / MB | spec |
| ... 合并大表，模块列每个模块只填首行 |

**待评估项**（全局，影响所有使用统一区头样式的模块）：
| ... |

---

### 各模块修改前后 UX 对比

#### 1. <Module Name>
> 本模块在 X 个模板使用，视觉变化作用于全站所有引用此模块的位置（如适用）

| 项 | 优化前 | 优化后 | 规范依据 | 影响 |
| ... |

**待评估项**（属其它范畴或本轮未处理）：
| 类型 | 现状 | 备注 |
```

## 6.4 表格列规则

**字号总览（合并表）**

- 列：模块 / 元素 / PC / MB / spec
- spec 列写 `✓ <tier>`，或 `✓ 统一的模块标题样式（large-title-2）`，或 `⚠️ 非 spec 档（<原因>）`

**修改前后对比**

- 列：项 / 优化前 / 优化后 / 规范依据 / 影响
- **影响等级**：高 / 中 / 低，**含量化描述**（如「+4px」「-3 个灰阶」「±N 模板可见」）
- **规范依据**：`§1.1 Regular`、`§3.1 space-6` 这类 **spec 章节引用**

**Multi 实例模块**（单模板内多实例）

- 按实例 1 / 2 / 3 分小段
- 表头改成「**修改的后台字段**」，写运营在 admin 能找到的字段名（如「卡片块 Subheading Font-weight」）

## 6.5 措辞约束（**日志的核心约束，读者是运营 / 设计 / 产品**）

- 用**业务可理解**的语言
- 🔴 **禁用代码术语**：`schema`、`scheme`、CSS class（`.class-name`）、file path、JS 函数名、liquid 变量名
- 必要的代码相关概念**用业务化描述**：

| 不要写 | 要写 |
|---|---|
| `schema heading_font_size_mobile` | **后台「Heading Font size (Mobile)」字段** |
| `scheme` | **配色方案** |
| `.hero-title` 内联 style | **后台自定义 HTML** |
| `cs-section-header` | **统一的模块标题样式** |

## 6.6 模块顺序

详细对比段内**按页面渲染顺序**排列模块，并带数字编号（`#### 1. Slideshow`、`#### 2. SA: Text`…）。
页面渲染顺序取自 `memory/模板清单.md` 的「section 渲染顺序」列。

## 6.7 disabled 实例不登记

模板里 `"disabled": true` 的实例**不参与字号总览、也不参与对比表**（`hard-rules.md` 规则 1）。

## 6.8 ⚠️ 标识用法

- 模块**整体**未做 spec 迁移 → **模块名后**加 ⚠️
- **单元素**非 spec 档 → **spec 列**加 ⚠️
- 🔴 **加完 ⚠️ 必须有具体说明，不能裸标**

---

# 第七步 — 典型异常处理

## 7.1 schema 约束（step / max / min）阻挡 spec 值

例：某模块的 `column_gap` 原本是 `step:5` / `max:50`，而 spec `--space-*` 是 4 的倍数、命不中。

处理：

1. **评估放宽约束的向后兼容性**（步长收紧 vs 上限拉高 —— **通常拉高安全**，收紧危险，见 `pitfalls-shared-scope.md` §4.4）
2. 改 schema 后，所有历史 `step:5` 存值**依然合法**
3. **用户验收通过后**，改动登记在「模块层面（影响全站新建实例）」段

## 7.2 配置驱动的样式没有 admin 等价物

当 spec 要求某属性（如描述文字色）但模块 admin **没有独立字段**控制时：

- 🔴 **不要为此新增 admin 字段**（成本高 + 影响全站实例；且与 vendor §3.4 冲突，例外见 `pitfalls-shared-scope.md` §4.6）
- **在模板级 CSS 文件做覆盖**（如 `assets/<template>-page.css`），覆盖范围**限于该模板**
- **用户验收通过后**登记到日志的「模板级样式清理」段

## 7.3 弃用的稳定性 vs 抖动取舍

某些模块的稳定性逻辑（如 Delta Accordion 的 `calcMinHeight`）可能有 bug，但删了会引入新问题（如 CLS）。

**决策依据是用户的选择，不是技术偏好：**

- 用户明确接受抖动 → 删除，**验收后**登记为「中」等影响
- 用户要稳定 → **修 bug 不删功能**

## 7.4 待评估的两种归属

| 类型 | 归属 |
|---|---|
| 单模块内未处理项 | 跟在**该模块**详细对比表下方 |
| 跨模块全局议题（如区头偏差、按钮档差合理性） | **全局待评估段**（在字号总览末尾或日志末尾），并同步进 `memory/全局已知偏差.md` |
