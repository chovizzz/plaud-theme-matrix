# QA-A — Path A（通用开发 / bugfix / 性能 / 新功能）

覆盖五项（handoff-schema §5 表）：同族 bug 扫描、依赖树回归、Swiper effect 约束、旧 section 连带影响、JS 生命周期清理。

每项 `Passed` / `Failed` / `Blocked` / `NotApplicable` + 证据，写进 `ProfileSpecificResults`。

---

## A1. 同族 bug 扫描

> **一个 bug 常伴 3–5 个同族。** 只修了报上来那一处、没扫同族的改动，QA 判 `Failed`——不是"改得对不对"，是"扫没扫"。

### 怎么找同族（四条正交路径，全跑）

1. **按根因关键词全仓 grep。** 从实现工件的 `RootCause` 提取机制词，搜同样写法：

   ```bash
   grep -rn "<修复前的错误写法>" <theme-root>/{sections,snippets,assets,layout}/
   ```
   例：根因是"事件重复注册" → grep `addEventListener` 且附近无 `removeEventListener` / 无注册守卫的位置。

2. **按同一 API / 基类的其它使用者。** 修的是 `PopupBase` / `SlideSection` / `DeferredMedia` / `subscribe()` 的用法 → 列出全部继承或调用方，逐个判断是否同病。

   ```bash
   grep -rn "extends PopupBase\|extends SlideSection\|subscribe(" <theme-root>/assets/
   ```

3. **按同一症状族的已知映射表。** 旧 skill 沉淀的高发对：

   | 症状 | 根因 | 同族搜索点 |
   |---|---|---|
   | 移动端样式不生效 | inline style 覆盖媒体查询 | 所有 `style="` 输出响应式值的 Liquid |
   | 下拉 / tooltip 不显示 | 父级 `overflow: hidden` 裁切 | 同一祖先链下的其它浮层 |
   | Swiper cards/cube 图不加载 | `data-src` lazy 与 effect 不兼容 | 全仓其它 cards/cube 实例 |
   | 点击触发多次 | 事件重复注册 | 同文件其它 `addEventListener` |
   | 循环里输出 `stylesheet_tag` | snippet 在 for 内重复注入 | 所有 `{% for %}` 内的 `stylesheet_tag` |
   | timer / observer 未清理 | 无 `disconnectedCallback` | 见 A5 |

4. **按同一文件的相邻实现。** 同一 section / JS 文件里结构相同的兄弟分支（多个 block type、多个断点分支）逐个对照。

### 判定

- 四条路径都跑过、命中项逐条给出"同病 / 不同病 + 依据" → `Passed`。
- 发现同族但本次未修：**不判 `Failed`**（修不修是实现 skill 的范围决策），但必须列进 `BlockingGaps` 让用户决定；若同族与本次改动共用被改代码路径（改了却漏改） → `Failed`。
- 只写"扫过了没发现同族"而无 grep 原文 → `Blocked`。

---

## A2. 依赖树回归

复算实现 / Assess 工件给出的依赖树，不能照抄。至少覆盖四层：

```bash
# 1) section 及其 block type、schema 选项
grep -n '"type"\|{% schema %}' <theme-root>/sections/<x>.liquid
# 2) 该文件 render 的 snippets
grep -nE "render '|include '" <theme-root>/sections/<x>.liquid
# 3) snippet 的上游调用方（反向）
grep -rn "render '<snippet>'" <theme-root>/{sections,snippets,layout}/
# 4) JS custom element 继承链 + CSS 作用域/断点覆盖
grep -rn "customElements.define\|extends " <theme-root>/assets/<x>.js
```

判定：

- 四层都有 grep 原文，且与上游 `ActualAffectedInstances` 一致（或指出差异） → `Passed`。
- 上游只报了 `TheoreticalReferences`（"可能影响 N 处"）而没有逐项核查的 `ActualAffectedInstances` → `Failed`，退回 Assess。
- 改动是纯 CSS 且只作用于单一 BEM 根类、grep 证明无其它引用 → 可 `Passed`，但仍要给 grep。

---

## A3. Swiper effect 约束

只在本次改动触及 Swiper 配置 / 轮播 section 时适用；否则 `NotApplicable` + 理由。

| Effect | 必须 | 禁止 |
|---|---|---|
| `cards` | `loop: false`、`rewind: true`、horizontal、图片全量渲染 | `loop: true`、`data-src` lazy |
| `cube` | `spaceBetween: 0`、固定 px height | `height: auto` |
| `fade` | `slidesPerView: 1` | `slidesPerView > 1` |
| `vertical` | 固定 px height（取自 firstSlide） | `height: auto` |

取证：

```bash
grep -rn "effect[[:space:]]*:[[:space:]]*['\"]" <theme-root>/{assets,sections,snippets}/
grep -rn "data-src\|loop:\|rewind:\|slidesPerView" <改动涉及的 swiper 文件>
```

额外两条：

- 轮播是否复用 `{% render 'section-swiper' %}`、未自行重写 pagination / arrow 视觉（vendor §11）。
- `cube` / `vertical` 的固定 px height 是 **shared 红线 2 的允许例外**，不应被 `FixedDimensionCheck` 误判 —— 在两处证据里互相引用一句。

---

## A4. 旧 section 连带影响

改动碰到共享 snippet / 全局 CSS / token / 旧类名 / 旧断点时必查；纯新建、无存量调用方 → `NotApplicable`。

```bash
# 旧类名残留
grep -rn "<被改/被删的类名>" <theme-root>/{sections,snippets,assets,layout,templates}/
# 删了 schema 字段 / CSS 变量 / data-* 后的 dangling 引用（三处都要扫）
grep -rn "var(--<被删变量>)" <theme-root>/assets/
grep -rn "settings.<被删字段>" <theme-root>/{sections,snippets}/
grep -rn "dataset.<被删属性>\|data-<被删属性>" <theme-root>/{assets,sections,snippets}/
# 杂散断点值（应统一，不应出现 1280 / 768 之类与主题基准不一致的值）
git -C <theme-root> diff <BaseHeadSha> -U0 -- <ModifiedFiles> | grep -nE '^\+.*(min|max)-width:[[:space:]]*[0-9]'
```

判定：

- 任一 dangling 引用未清 → `Failed`（这是 token→class 重构的高频回归源：改了一处、没覆盖全实例）。
- 旧 section 与新改动共用被改的共享文件，但未列入回归矩阵 → `Failed`，退回补矩阵。

---

## A5. JS 生命周期清理

只在本次改动含 JS 时适用；否则 `NotApplicable` + 理由。

```bash
git -C <theme-root> diff <BaseHeadSha> -U0 -- <改动的 js 文件> | grep -nE '^\+.*(addEventListener|setInterval|setTimeout|IntersectionObserver|MutationObserver|ResizeObserver|subscribe\()'
grep -n "disconnectedCallback" <改动的 js 文件>
```

逐条核对四项（shared 红线 6）：

| 项 | 判定 |
|---|---|
| 监听 / timer / observer / subscription 在 `disconnectedCallback` 里清理 | 新增了注册但 `disconnectedCallback` 没有对应清理 → `Failed`，列出哪个注册没配对 |
| null 守卫 | 新增的 `querySelector` 结果直接 `.` 取属性、无 `if (!el) return` → `Failed` |
| TDZ 安全 | `const` / `let` 在声明前被引用（含闭包与事件回调里的提前使用） → `Failed` |
| 生产代码无 `console.log` | `git diff` 里新增 `console.log` → `Failed` |

注册与清理必须**成对**列出证据，例如：
`+ resize 监听 @ assets/x.js:41 → disconnectedCallback removeEventListener @ x.js:78 ✓`
