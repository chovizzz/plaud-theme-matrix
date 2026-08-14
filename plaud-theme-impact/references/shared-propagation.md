# 共享 / 全局改动的传播链

对应 `handoff-schema.md` §3 的 `SharedPropagation` 与 `LegacyImpact` 两个字段。这是用户点名的高频漏项：**共享 snippet 改一处，波及互不相邻的多个上下文。**

---

## 1. 共享 snippet

### 1.1 高风险清单

`product-item.liquid` / `price.liquid` / `price-format.liquid` / `buy-buttons.liquid` / `product-badges.liquid` / `section-header.liquid` / `section-swiper.liquid` —— 这些被多处 render，blast radius 远大于任何单个 section。

典型的**互不相邻上下文**：集合页、搜索结果页、推荐位、mega 菜单商品卡、购物车 drawer、产品页相关推荐。改一处，六个地方一起变，其中至少两个不在开发者当时看的页面上。

### 1.2 调用点枚举（三种写法都要跑）

```bash
grep -rn "render '<snippet>'"  sections/ snippets/ templates/ layout/
grep -rn 'render "<snippet>"'  sections/ snippets/ templates/ layout/
grep -rn "include '<snippet>'" sections/ snippets/ templates/ layout/
```

### 1.3 传参差异必须逐点列出

共享 snippet 常靠某个参数区分上下文，**同一改动在不同调用点走不同分支**。例：`snippets/product-item.liquid` 用 `card_bg == 'white'` 区分"mega 菜单里的商品卡"与"集合页等其它位置"（只有 mega 菜单的两处 render 传 `card_bg: 'white'`，其余默认 `tertiary`）。

产出格式：

```
调用点                                  传参                       是否命中本次改动分支
sections/collection.liquid:88           card_bg 默认(tertiary)     否
sections/mega-menu.liquid:142           card_bg: 'white'           是
sections/mega-menu.liquid:167           card_bg: 'white'           是
snippets/recommendations.liquid:31      card_bg 默认               否
```

---

## 2. token → class 重构：必须全实例覆盖

**高频回归源，真实发生过。**

把某个共享 class 的 spec 值（字号 / 内距 / 圆角 / 间距）从组件 CSS 移到 HTML utility 类时，未迁移的实例会**静默丢样式**——字号回退到继承值、内距归零。这些实例常在**其它分支 / 其它 snippet** 里，改动当下的页面上根本看不到。（实测踩坑：某轮只改了当前正在做的实例，另一个品牌分支 + 移动菜单的多个分支未补类 → 回归；最后靠并行 diff 审查 + 全仓 grep 才补齐。）

### 强制顺序（不得跳步）

```bash
# ① 全仓找出该 class 的所有 markup 实例 —— 先找全，再谈剥离
grep -rn 'class="[^"]*<class-name>' sections/ snippets/ templates/ layout/ shopify-common/
# ② 逐一确认每个实例都已挂等价 utility —— 全覆盖前不得剥 CSS 声明
# ③ 剥完回归验证
```

### 本 skill 的产出

①的**完整实例清单** + 每个实例**当前是否已挂等价 utility** 的核查结果。

```
.at-tag  —— 7 个 markup 实例
  snippets/article-card.liquid:23        已挂 fs-body-md  ✓
  snippets/menu-card.liquid:41           未挂             ✗ ← 剥离后会丢样式
  sections/atlassian-hero.liquid:88      未挂             ✗
  ...
```

清单不全就不要说"可以剥"。任一 `✗` → 该项进 `SharedPropagation`，`RiskTier` 至少 Medium（配合其它维度常为 High）。

### 合理例外（留 token 在组件 CSS）

- 无对应 utility 的属性（如单侧 `margin-inline-end`）
- "共享组件基类一次定义、不散落"的 padding

这类留 `var(--token)` 在组件 CSS 是合理的，不算重复，不需要全实例覆盖。

---

## 3. 删除类改动：全仓 dangling 引用核查

删 schema 字段 / CSS 变量 / `data-*` 属性后，残留引用**静默失效**（不报错、不 lint、只是不生效）。三条都要跑：

```bash
# CSS 变量
grep -rn "var(--<var-name>)" assets/ shopify-common/ sections/ snippets/

# schema 字段（三种访问路径）
grep -rn "section\.settings\.<field>\|block\.settings\.<field>\|settings\.<field>" \
     sections/ snippets/ templates/ layout/

# data-* 属性（markup 侧 kebab、JS 侧 camel）
grep -rn "data-<kebab-name>" sections/ snippets/ layout/
grep -rn "dataset\.<camelName>\|getAttribute('data-<kebab-name>')" assets/ shopify-common/
```

附带：

```bash
grep -rn --fixed-strings "<locale.key>" sections/ snippets/ layout/ templates/  # 删/改名 locale key 前
grep -rn "<removed-class>" sections/ snippets/ assets/ shopify-common/    # 删 class 前
```

任一命中 → 列为 dangling 风险项，`RiskTier` 不得低于 Medium。

---

## 4. build 产物 vs 源文件

改错层的两种后果：改产物 → 下次 build 覆盖，改动凭空消失；改源不 build → 线上无变化。

| 类别 | 路径 | 处理 |
|---|---|---|
| **源** | `shopify-common/src/**`、`sections-*/**` 下的 `.scss` / `.liquid` / `.js` | 改这里，需 `npm run build` |
| **产物（勿手改）** | `snippets/design-system.liquid`、`assets/sectionsTT.min.css`、`assets/base_more.css` 等 | 只读 |

判定：

```bash
grep -rn "<被改的类名或变量>" shopify-common/src/ 2>/dev/null   # 命中 → 源在这里
ls -la shopify-common/package.json 2>/dev/null                   # 确认 build 链存在
```

`SharedPropagation` 里必须注明：改动落在源还是产物、是否需要 build（供实现 skill 填 `BuildRequired`）。

### 4.1 加载的是哪一份

**真正加载的入口以 `layout/theme.liquid` 为准。** 同名/近名文件可能有多份（例：`{% render 'base-more-style' %}` 加载的是 snippet 那份，`assets/base_more.css` 是另一份），改了没加载的那份等于零影响。

```bash
grep -nE "render|stylesheet_tag|javascript_tag|asset_url|section_group" layout/theme.liquid
```

无法确定加载哪份 → 停机要确认，不猜。

---

## 5. 全局 CSS 与 design token

- 全局 CSS：`critical.css` / `theme.css` / `base_more*` / design-system 相关 —— 消费方是全站，收敛必须走 `theoretical-vs-actual.md` 步骤 3
- design token：改变量**值**影响所有消费方；改变量**名**是删除类改动，走 §3 dangling 核查
- critical bundle 与异步 bundle 的差别会影响 FOUC 与首屏，需在 `SharedPropagation` 注明改动落在哪个 bundle

具体 token 名与数值在 `plaud-theme-shared/references/colors-and-schemes.md` / `typography.md` / `responsive-and-spacing.md` —— **本 skill 只引用文件名，不复制数值**。

---

## 6. `LegacyImpact` 字段：旧 section / 旧类名 / 旧断点

单列在 `LegacyImpact`（与 `SharedPropagation` 分开）：

| 维度 | 查什么 | 命令 |
|---|---|---|
| 旧类名残留消费方 | 旧模块留下的类名是否还被其它地方消费 | `grep -rn "<legacy-class>" sections/ snippets/ assets/ shopify-common/` |
| 旧控件 DOM | 被新控件替换后，旧控件的 CSS/JS 是否还有消费方 | `grep -rn "<legacy-control-class>" assets/ shopify-common/src/` |
| 旧断点 | 杂散断点（非规范 `.98` 精度）与新改动交界处的 1px 缝隙 / 双重生效 | `grep -rn "@media" <相关 css> \| grep -v "\.98"` |
| 旧 schema 字段 | 已弃用但仍有 stored 值的字段，向后兼容分支是否被本次改动影响 | `grep -rn "<deprecated-field>" templates/ sections/` |
| 同族 bug | 一个 bug 常伴 3–5 个同族（同一错误模式的其它出现点） | `grep -rn "<错误模式>" sections/ snippets/ assets/` |

同族扫描只列**候选点**，不下"这也是 bug"的结论——根因判定归实现 skill。
