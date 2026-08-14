# JavaScript / Custom Element / Swiper

**何时读我**：写或改 JS、custom element、弹窗 / drawer / 轮播交互，或排查"点击触发多次 / 图不加载 / 下拉不显示"这类症状时。

> 本文是矩阵内 JS 与 Swiper 约束的**唯一事实源**。其它 skill 不得复制这里的规则，只得引用本文件。
> JS 生命周期红线正文在 `handoff-schema.md` §8.6。

---

## 1. 主题架构速记

**新增交互前先查现有基类，不要另起炉灶。**

### `assets/global.js`

| 能力 | 用途 |
|---|---|
| `PopupBase` | 弹窗基类 —— 所有 modal / popup 继承它 |
| `SlideSection` | 轮播基类 —— 所有 Swiper section 走它 |
| `DeferredMedia` | 延迟加载媒体（视频 / iframe）|
| `trapFocus()` | dialog 焦点陷阱（A11y 必用，见 `a11y.md` §3）|
| `subscribe()` / `publish()` | pub-sub 跨组件通信 |
| `getScrollBarWidth` | 滚动条宽度补偿（弹窗锁滚动时防抖动）|
| `Shopify.formatMoney` | JS 价格格式化（见 `liquid-schema-format.md` §5.4）|

### `assets/theme.js`

`LocalizationForm`、`CartNotification`、`RegionSelector`、`MultiContent` / `MultiContentWW`、`bls__drawer`

### `assets/components.js`

`Swatch`、`QuickView`、`VideoPopup` 等 custom elements

### CSS 分层

`critical.css` / `theme.css` / `assets/*.css`。section 内 `<style>` **只输出 CSS 自定义属性**，不写具体规则。

> ⚠️ `assets/critical.css` 已在 `theme.liquid` 注释禁用，grep 它无意义。真正加载的 critical 入口是 `snippets/design-system.liquid`（spec tokens + utilities）、`snippets/base-style.liquid`（`text-{x}!` important 对齐类）、`snippets/critical-style.liquid`（legacy 对齐类 + 全局按钮基础样式）。验证某个类是否生效 → grep 这三个 snippet。

### 选基类速查

| 需求 | 用什么 |
|---|---|
| 弹窗 / modal | `PopupBase` |
| 轮播 | `SlideSection` |
| 跨组件通信 | `subscribe()` / `publish()` |
| 延迟媒体 | `DeferredMedia` |
| 焦点管理 | `trapFocus()` |

---

## 2. 数据传递优先级

```
Liquid data attribute  →  window.siteData  →  异步 fetch  →  第三方 API（最后手段）
```

能在 Liquid 渲染时用 `data-*` 传的，不要用 fetch 拿。

---

## 3. §8.6 的清理映射与检查方法

> 规范性正文见 `handoff-schema.md` §8.6。本节只给"哪类资源对应哪个清理动作"和"怎么查"。

custom element 在 `disconnectedCallback` 里的清理对照：

| 类型 | 清理动作 |
|---|---|
| 事件监听 | `removeEventListener`（或用 `AbortController` + `signal`） |
| timer | `clearTimeout` / `clearInterval` |
| observer | `IntersectionObserver` / `ResizeObserver` / `MutationObserver` 的 `.disconnect()` |
| subscription | pub-sub 的 `unsubscribe()` |
| Swiper 实例 | `.destroy()` |

§8.6 同条覆盖的另外两项，判定口径：

- **null 守卫**：`querySelector` 结果先判空再用；
- **TDZ 安全**：`const` / `let` 声明前不引用。

另：生产代码无 `console.log`。

判定方法（QA 可执行）：

```bash
# 有 connectedCallback 但没有 disconnectedCallback 的自定义元素
grep -n "connectedCallback" <file> && grep -n "disconnectedCallback" <file>
# 有 addEventListener 但同文件无 removeEventListener / AbortController
grep -c "addEventListener" <file>; grep -cE "removeEventListener|AbortController" <file>
grep -n "console\.log" <file>   # 必须为空
```

---

## 4. Swiper effect 约束表

| Effect | 必须 | 禁止 |
|---|---|---|
| `cards` | `loop: false`、`rewind: true`、horizontal 方向、**全量渲染** | `loop: true`、`data-src` lazy |
| `cube` | `spaceBetween: 0`、**固定 px height** | `height: auto` |
| `fade` | `slidesPerView: 1` | `slidesPerView > 1` |
| `vertical` | **固定 px height**（取自 firstSlide） | `height: auto` |

> `cube` / `vertical` 要求的**固定 px height 是"禁写死宽高"红线的已文档化例外**（`handoff-schema.md` §8.2），但仍须在 `ModifiedFiles` / 改动说明里写明原因。

改 effect 时必须跑全量回归（`QA-A` 的 Swiper effect 约束项）。

---

## 5. `section-swiper.liquid` 统一控件

所有用 Swiper 的模块（商品轮播、图文轮播、评价轮播）**分页与翻页按钮必须使用统一样式**，不得每个 section 自行实现。

```liquid
{%- render 'section-swiper', class: 'mt-6', style: '' -%}
```

该 snippet 输出 `.cs-section-swiper`，已包含：

- `.swiper-button-prev`（`#icon-back`）
- `.swiper-pagination`
- `.swiper-button-next`（`#icon-next`）

默认 `flex justify-end` 布局，通过 `class` / `style` 参数微调位置。样式在 critical，无 FOUC。

初始化时选择器指向 snippet 输出的节点：

```js
new Swiper(el, {
  navigation: {
    prevEl: el.querySelector('.swiper-button-prev'),
    nextEl: el.querySelector('.swiper-button-next'),
  },
  pagination: { el: el.querySelector('.swiper-pagination'), clickable: true },
});
```

**禁止**在 section 内重写 `.swiper-button-prev` / `.swiper-button-next` / `.swiper-pagination` 的视觉样式。有设计差异 → 提 PM 评审后扩展公共样式。位置调整通过 `class`（`justify-start` / `justify-center` / `justify-end` / `mt-*`）传入，**不要复制 snippet 再改**。

### 5.1 迁移旧控件时

| 动作 | 说明 |
|---|---|
| 删旧标记 | `.delta-trust-pagination-progressbar` / `.trust-arrow` / `.swiper-actions` 这类旧控件 DOM |
| 删 `trust-swiper` 类 | 它带 `padding-bottom: 50px`（旧底部绝对定位进度条的预留位），换 section-swiper 后是多余空白 |
| 保留 | `swiper` 核心类与懒加载类 |
| slide-section 自动绑定 | JS 用通用 `.swiper-button-prev/next` + `.swiper-pagination`（正是 section-swiper 提供）；`data-pagination-progressbar="true"` 走 `.cs-section-swiper .swiper-pagination` 的 critical 进度条样式，无需额外接线 |

### 5.2 "无下一页时隐藏控件"

`.cs-section-swiper` 自带 `padding: 20px 0` —— 仅靠 Swiper 的 lock 类隐藏内部按钮/分页**仍留约 40px 容器空白**。需隐藏整个控件容器：

| 场景 | 做法 |
|---|---|
| slide-section（固定 perView，多断点） | 按"数量 > 当前断点每屏数"用 **critical 内联 CSS** 控制 `.cs-section-swiper` 的 `display`（mobile > 1 / tablet > 2 / desktop > 每行数）。断点用 **768 / 1025 对齐 slide-section**——⚠️ 组件既有断点特例，**勿泛化到全局 767.98 / 1279.98 判定** |
| `slidesPerView: auto`（2 档） | liquid 按 `数量 > 每行数`(PC) / `数量 > 1`(MB) 设 `--action-display`，配 `.xxx { display: var(--action-display, none) !important }` |

两种做法都是 flash-free（critical 内联，不靠运行时 JS）。

### 5.3 轮播间距

用 `data-custom-breakpoints`（含 0 档）传断点间距，**不用运行时 JS 改 `spaceBetween`**。

---

## 6. 常见 bug：症状 → 根因 → 修复

| 症状 | 根因 | 修复 |
|---|---|---|
| 移动端样式不生效 | inline style 覆盖媒体查询 | CSS 变量桥接（三层 `-m`/`-pc` 变量，见 `responsive-and-spacing.md` §6.2） |
| 下拉 / 弹层不显示 | 父级 `overflow: hidden` 裁切 | 打开态 `overflow: visible` |
| Swiper cards / cube 图不加载 | `data-src` 与 effect 不兼容 | 全量渲染或禁用 lazy（见 §4） |
| 点击触发多次 | 事件重复注册 | 只注册一次，或先 `removeEventListener` |
| 同页多实例只有第一个能用 | 重复 id（含 `{{ section.id }}` 拼接） | id 加实例唯一后缀（`liquid-schema-format.md` §6） |
| 间距 / 内距整段消失 | legacy `mb-custom` / `pb-custom` 的 `calc(var()*1px)` 单位陷阱 | 改用 `.mar-b-*` / `.pad-b-*`（`responsive-and-spacing.md` §7.3） |
| 网格列宽 / 列距错乱 | `.grid-cols` 叠了 `gap-sp-*` | 改内联 `--col-gap`（同上 §7.1） |
| 想要的下间距被吃掉 | `my-0` 盖掉 `mar-b-*` | `mt-0` + `mar-b-*`（同上 §7.2） |
| 首屏字号 / 颜色闪一下 | async bundle 里写了字号/色/box 样式 | 搬到 critical 工具类挂 HTML（同上 §8） |
| 首屏价格跳变 | 首屏用 JS 渲染价格 | 首屏走 `price-format`，与 `Shopify.formatMoney` 等价 |

> **一个 bug 常伴 3–5 个同族 bug**（`QA-A` 的同族扫描项）。修完一个，用同样的 grep 模式扫全仓同类写法。

---

## 7. 按任务类型的工作流

| 类型 | 流程 | 高频关注点 |
|---|---|---|
| **性能优化** | 建依赖树 → 定位 → 最小修改 → 验收 | DOMParser 复用、timer/observer 清理、图片 width/height 防 CLS、循环 snippet 不输出 `stylesheet_tag`、lazy-load 与 Swiper cards/cube 不兼容、`ParserBlockingScript` |
| **新功能** | 建依赖树 → OODA → PRD（≥2 方案）→ 用户确认 → 实现 → 全量回归 | — |
| **Bug 修复** | 建依赖树 → 回归矩阵 → 根因 → 最小修复 → 验证 | 同族 bug 扫描 |
| **UX 调整** | CSS var 桥接 → overflow / z-index 检查 → 对比度 ≥ 4.5:1 | — |

**依赖树至少包含**：section 及 block type、render 的 snippets、schema 选项；snippet 的上游调用方与循环内资源输出；JS custom element 继承链；CSS 作用域与断点覆盖。

**回归矩阵至少覆盖**：layout mode、schema 选项、block type、断点（PC / 1599 / 1279 / 767 / 375）、Swiper effect、关键开关。

---

## 8. 共享 snippet 的作用域隔离

`render` 是**隔离作用域**——抽公共片段时必须**显式传参**（product / section / 各 enable 标志 / skeleton / 通知块等），不能指望外层变量可见。漏传会触发 Theme Check `UndefinedObject`，或更糟：静默渲染空白。

---

## 9. 生成文件（build 产物）勿手改

`snippets/design-system.liquid`、`assets/sectionsTT.min.css`、`assets/base_more.css` 等是 `shopify-common` 的 **build 产物**。改动要落到**源**（`shopify-common/src/**`、`sections-tt/**` 的 scss / liquid）+ 重新 build：

```bash
cd shopify-common && npm run build
```

别手改产物（下次 build 会覆盖 / 与源分叉）。真正加载的入口以 `layout/theme.liquid` 为准（如 `{% render 'base-more-style' %}` 是加载的那份，`base_more.css` 是另一份）。

红线正文见 `handoff-schema.md` §8.7；`BuildRequired` 字段见 §4。

---

## 10. 第三方插件的 JS / CSS

商品 / 购物车页常嵌第三方应用（Affirm、Klarna、Selleasy、Judge.me / Okendo）：

- **不改插件生成的 JS / CSS**——改了无效（运行时重新生成）/ 会被插件更新覆盖；
- **在主题层集中覆盖**（如 `snippets/base-more-style.liquid` 的 `<style>` 块），按插件容器选择器覆盖到 spec；插件用 inline style 时需 `!important`：
  ```css
  .affirm-as-low-as { font-size: var(--text-body-sm) !important; }
  ```
- 插件里"看着像品牌色"的值先查是不是 spec token（见 `colors-and-schemes.md` §1）；
- 插件小组件的紧凑 `line-height: 1.2` 谨慎动（见 `typography.md` §6）。
