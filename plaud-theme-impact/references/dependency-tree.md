# 依赖树 — 七层与实际查法

**不靠文件名猜影响范围。** 每层都要落成清单；空层写"无"，不省略。所有命令在 theme root 下跑。

---

## 层 1 — section 本体 + block type

被改的 section 有哪些 block type、哪些 layout 分支。block type 是最常见的"改了 A 分支没测 B 分支"来源。

```bash
grep -nE '"type"|"name"' sections/<module>.liquid          # schema 里的 block type
grep -nE "block\.type|section\.settings\.[a-z_]+" sections/<module>.liquid   # 渲染分支条件
grep -nE "\{%-?\s*(if|elsif|case|when)" sections/<module>.liquid            # 全部条件分支
```

产出：block type 清单 + 每个 type 对应的渲染路径 + 本次改动落在哪些路径。

---

## 层 2 — render 的 snippets

section 往下拉了谁。递归一层：被 render 的 snippet 自己也可能 render 别人。

```bash
grep -nE "\{%-?\s*(render|include)" sections/<module>.liquid
# 对每个查到的 snippet 再来一次
grep -nE "\{%-?\s*(render|include)" snippets/<child>.liquid
```

注意 `render` 的参数传递：同一 snippet 在不同调用点传不同参数会走不同分支，参数必须记进清单。

---

## 层 3 — schema 选项

哪些 setting 会改变渲染分支、哪些有 `step` / `min` / `max` 约束（约束会阻挡 spec 值，且 admin 保存时才校验）。

```bash
grep -nE '"id":|"type":|"default":|"min":|"max":|"step":|"visible_if"' sections/<module>.liquid
```

产出：setting 清单 + 哪些参与本次改动的分支判定 + 哪些约束可能阻挡目标值。

---

## 层 4 — snippet 的上游调用方（改 snippet 时必做）

```bash
grep -rn "render '<snippet>'"  sections/ snippets/ templates/ layout/
grep -rn 'render "<snippet>"'  sections/ snippets/ templates/ layout/
grep -rn "include '<snippet>'" sections/ snippets/ templates/ layout/
```

三种写法都要跑（单引号 / 双引号 / 旧 `include`）。产出：调用方清单 + **每个调用点传入的参数**。参数差异决定改动落在哪些上下文——共享 snippet 常靠某个参数区分上下文（例：`product-item.liquid` 用 `card_bg == 'white'` 区分"mega 菜单里的商品卡"与"集合页等其它位置"）。

---

## 层 5 — 循环内的资源输出

循环体里输出 `stylesheet_tag` / `javascript_tag` / `<style>` 会重复 N 次，是 Plaud 主题的高发性能问题。改动若在循环内、或改的 snippet 被循环调用，必须核查。

```bash
grep -nB 8 "stylesheet_tag\|javascript_tag\|<style" snippets/<snippet>.liquid sections/<module>.liquid
grep -nE "\{%-?\s*for " sections/<module>.liquid snippets/<snippet>.liquid
```

产出：资源输出点 + 是否在循环内 + 循环最大次数来源（block 数 / 产品数）。

---

## 层 6 — JS custom element 继承链

改基类 = 波及所有子类。Plaud 主题的常见基类：`PopupBase`、`SlideSection`、`DeferredMedia`，以及 pub/sub（`subscribe()` / `publish()`）。

```bash
grep -rn "class .* extends <Class>" assets/*.js shopify-common/src/
grep -rn "customElements.define" assets/*.js shopify-common/src/
grep -rn "subscribe(\|publish(" assets/*.js shopify-common/src/         # pub/sub 隐式耦合
grep -rn "<custom-element-tag>" sections/ snippets/                      # markup 侧使用点
```

产出：继承链（父 → 子）+ 所有 `customElements.define` 的标签名 + markup 里的使用点 + pub/sub 事件名的发布方与订阅方。

**pub/sub 是隐式依赖**：grep 不到"引用关系"但改事件名/payload 会断。事件名必须单独列。

---

## 层 7 — CSS 作用域与断点覆盖

类名在哪些文件被定义、被谁覆盖、哪些断点有覆盖。同一类名在 critical / theme / section-scoped / build 产物里可能各有一份，谁赢取决于加载顺序。

```bash
grep -rn "\.<class-name>" assets/*.css shopify-common/src/ sections/ snippets/
grep -rn "@media" <命中的 css 文件>                    # 断点覆盖点
grep -rn "\-\-<var-name>" assets/ shopify-common/src/  # CSS 变量的定义方与消费方
```

断点精度是 Plaud 的既有约定（`.98` 系列，具体数值见 `plaud-theme-shared/references/responsive-and-spacing.md`）。核查时注意**杂散断点**（非 `.98` 精度的整数断点）——它们与规范断点交界处会出现 1px 缝隙或双重生效。

产出：定义点清单（文件 + 行）+ 加载顺序上谁最终生效 + 有覆盖的断点清单。

---

## 加载入口核查（贯穿层 6/7）

**真正加载的入口以 `layout/theme.liquid` 为准。** 同名/近名文件常有多份，改了没加载的那份等于零影响。

```bash
grep -nE "render|stylesheet_tag|javascript_tag|asset_url|section_group" layout/theme.liquid
```

例：`{% render 'base-more-style' %}` 与 `assets/base_more.css` 可能是两份不同内容，加载的只有其中一份。依赖树里凡涉及全局 CSS/JS 的层，必须注明"加载的是哪一份"，无法确定时停机要确认（见 SKILL.md 第七步）。

---

## 依赖树输出格式（建议）

```
TargetSubject: snippets/product-item.liquid

L1 section 本体/block type   : N/A（目标是 snippet）
L2 下游 render               : price-format, product-badges
L3 schema 选项               : N/A（snippet 无 schema；参数见 L4）
L4 上游调用方（含传参）      :
   - sections/collection.liquid:88   card_bg 默认 tertiary
   - sections/mega-menu.liquid:142   card_bg: 'white'   ← 唯一菜单上下文
   - snippets/recommendations.liquid:31  card_bg 默认
L5 循环内资源输出            : 无 stylesheet_tag；本 snippet 被 for 循环调用（collection 每页 24 次）
L6 JS 继承链                 : 无 custom element
L7 CSS 作用域/断点           : .product-item 定义于 assets/theme.css:412、
                               shopify-common/src/... （源）；断点覆盖：移动端与平板两档
                               （具体数值现读 plaud-theme-shared/references/responsive-and-spacing.md，
                                本 skill 不复制数值——写实测到的断点时须与该文件核对并注明出处）
加载入口                     : theme.css 经 layout/theme.liquid:57 stylesheet_tag 加载
```
