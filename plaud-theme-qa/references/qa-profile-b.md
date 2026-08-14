# QA-B — Path B（Figma → `sa-*` Section）

覆盖六项（handoff-schema §5 表）：命名、vendor §1–§12、素材来源、schema 完整性、空配置与满配置双测、多语言。

具体数值（宽度 / 间距 / 字阶 / 圆角 / 断点）以 `plaud-theme-shared/references/` 为准，本文件**不复制数值**——需要阈值时读 `liquid-schema-format.md` / `typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` 的当前值。

> 本文件把 vendor §1–§12 的**可执行判定**自带齐全，不依赖旧单 skill 包 `plaud-shopify-theme`（该包在矩阵安装后应被移除，引用它会在部分客户端失效）。若上游实现工件引用了 vendor 原文中本文件未覆盖的条款，向用户要该条原文，不要凭印象补。

---

## B1. 命名合规（`sa-*` / `SA:` / BEM 根类名）

```bash
ls <theme-root>/sections/sa-*.liquid <theme-root>/assets/sa-*.css
grep -n '"name"' <theme-root>/sections/sa-<feature>.liquid       # 必须 "SA: ..."
grep -n 'class="sa-' <theme-root>/sections/sa-<feature>.liquid   # 根类名 BEM
grep -n '"presets"' -A3 <theme-root>/sections/sa-<feature>.liquid
```

| 层级 | 规则 | 判定 |
|---|---|---|
| Section 文件 | `sections/sa-<feature>.liquid` | 不符 → `Failed` |
| Snippet | `snippets/sa-<feature>-<part>.liquid` | 有 snippet 才查 |
| CSS | `assets/sa-<feature>.css` | 不符 → `Failed` |
| schema `name` | `SA: ` 前缀 | 不符 → `Failed`（theme check `ValidSchemaName` 也会报） |
| 根类名 | BEM `sa-<feature>` | 不符 → `Failed` |
| presets | 存在且 name 带 `SA:` | 缺 → `Failed`（后台加不进去） |

**根类名冲突**也要查：`grep -rn "\.sa-<feature>" <theme-root>/assets/` 确认没有另一个 section 已占用同名根类。

---

## B2. vendor §1–§12 逐条

| § | 检查 | 不符判定 |
|---|---|---|
| §1 模块宽度 | 内容区用 `container`，未自造宽度容器 | `Failed` |
| §2 模块间距 | 上下间距走 `section_top_pc` / `section_bottom_pc` schema，CSS 无 section 级硬编码 `margin-top/bottom` | `Failed` |
| §3 颜色 | `color_scheme` schema + Liquid 同时加 `gradient` 与 `color-{{ …color_scheme }}`；无写死 hex（token / CSS 变量除外） | `Failed` |
| §4 字体字号 | 用语义字号 token / `.fs-*` 工具类，不散点硬编码 `font-size` | `Failed`（命中且非 token） |
| §5 圆角 | 走 `radius-*` 语义层 | `Failed` |
| §6 全局 H 标签 | 标题层级与全局 H 规则一致（层级取值见 shared reference） | `Failed` |
| §7 断点 | 断点值与主题基准一致（基准取自 `plaud-theme-shared/references/responsive-and-spacing.md`），无杂散值 | `Failed` |
| §8 文案 | 见 B4 与 QA-Global 第 7 项 | `Failed` |
| §9 按钮 | 只用 `btn-primary` / `btn-outline` / `btn-white` + 纯尺寸类 `btn-primary-{lg,md,sm}`；**无自造按钮类名**；无固定 `width`/`height`（只允许 `min-*`） | `Failed` |
| §10 价格 | 走 `{% render 'price-format' %}`；外层 `price-wrap` + `white-space: nowrap`；不硬编码货币符号 | `Failed` |
| §11 轮播 | 复用 `{% render 'section-swiper' %}`；未自行重写 pagination / arrow 视觉 | `Failed` |
| §12 公共片段 | section 容器 / schema 片段 / 标题块尽量复用（`section-header`）；未复用需说明原因 | 未复用且无理由 → `Failed` |

取证命令（**注意 ERE 里的 alternation 写 `|` 不写 `\|`**——`grep -E 'a\|b'` 匹配的是字面竖线，会静默零命中；`\s` 在部分 BSD grep 上不支持，用 `[[:space:]]`）：

```bash
cd <theme-root>
S=sections/sa-<feature>.liquid ; C=assets/sa-<feature>.css

grep -n 'class="[^"]*container' "$S"                              # §1
grep -nE 'section_top_pc|section_bottom_pc' "$S"                  # §2
grep -nE 'margin-(top|bottom)[[:space:]]*:' "$C"                  # §2 反例
grep -nE 'color_scheme|gradient' "$S"                             # §3
grep -nE '#[0-9a-fA-F]{3,8}' "$C"                                 # §3 反例
grep -nE 'font-size:[[:space:]]*[0-9]' "$C"                       # §4 反例
grep -nE 'border-radius:[[:space:]]*[0-9]' "$C"                   # §5 反例
grep -nE '(min|max)-width:[[:space:]]*[0-9]+' "$C"                # §7
grep -n 'class="[^"]*btn' "$S"                                    # §9
grep -nE '\.(btn|button)[a-z0-9_-]*[^{]*\{' "$C"                  # §9 自造按钮类名
grep -nE 'price-format|nowrap' "$S"                               # §10
grep -nE '[$€£¥]' "$S"                                            # §10 硬编码货币符号
grep -n 'section-swiper' "$S"                                     # §11
grep -nE 'swiper-pagination|swiper-button' "$C"                   # §11 反例
grep -n 'section-header' "$S"                                     # §12
```

> **零命中不等于通过。** 上面每条反例 grep 返回空时，必须先确认命令本身能在已知违规样本上命中（正则写错会静默零命中），再判 `Passed`。证据里写命令原文 + 命中数。

§9 的"无自造按钮类名"、§10 的"不硬编码货币符号"、§8 的"不用 `default:` 兜底"是 vendor 文档点名的**交付最常见问题**，这三条要在证据里逐条显式回答，不能合并成一句"§8–§11 已查"。

### §8.3 文案完整显示（易漏）

正文 / 描述类文本禁止截断：`overflow: hidden` + 固定 height、`text-overflow: ellipsis`、多行 `-webkit-line-clamp`、`white-space: nowrap`（价格不换行单元除外）。

```bash
grep -nE 'line-clamp|text-overflow|overflow:[[:space:]]*hidden|white-space:[[:space:]]*nowrap' <theme-root>/assets/sa-*.css
```

命中且不属于折叠组件（FAQ / Accordion / Show more，且有展开方式）或价格单元 → `Failed`。
卡片网格须 `align-items: stretch` + `min-height`，不得固定 `height`。

### 响应式三层变量策略

端变量 `--sa-xxx-m` / `--sa-xxx-pc` → 运行变量 `--sa-xxx` → 属性只读运行变量；断点内**只改变量映射，不写死 px**。

```bash
grep -nE '\-\-sa-[a-z-]+(-m|-pc)?[[:space:]]*:' <theme-root>/assets/sa-*.css
```

媒体查询块内出现直接写 px 的属性值（而非重绑变量） → `Failed`。mobile-first、grid 从 1 列起、无横向滚动同查。

---

## B3. 素材来源（未写死 assets）

新建 section **不得**把内容图片 / 视频 / icon 写死为 `{{ 'xxx.png' | asset_url }}` 或依赖 `assets/*.png|jpg|jpeg|svg|webp|mp4`。运营可配置素材必须走 schema（`image_picker` / `video` / `url`）或产品 / metaobject 数据源。

```bash
grep -nE "asset_url|assets/[^\"']+\.(png|jpe?g|svg|webp|gif|mp4)" <theme-root>/sections/sa-*.liquid <theme-root>/assets/sa-*.css
# 🔴 相对 BaseHeadSha 取，不用 git status：v0.3.0 起实施期间 commit 是合法的（§2.8），
#    工作树干净不等于本次没往 assets/ 里塞图
git -C <theme-root> diff --name-status <BaseHeadSha> -- assets/ | grep -iE '\.(png|jpe?g|svg|webp|gif|mp4)$'
git -C <theme-root> status --porcelain -- assets/ | grep -iE '\.(png|jpe?g|svg|webp|gif|mp4)$'   # 尚未提交的那部分
```

- 命中内容型素材 → `Failed`。
- `assets/` 只放 CSS / JS 与"确认全站固定的技术资源"；例外须需求明确并**已经用户确认**——证据里要引用那句确认，不能自己认定"这个应该算技术资源"。
- 第二条命令抓的是"本次顺手把 Figma 导出图塞进 assets/"，这是最常见的违规形态。

---

## B4. schema 完整性

```bash
# schema 块能否被解析（Liquid 里的 JSON）
sed -n '/{% schema %}/,/{% endschema %}/p' <theme-root>/sections/sa-<feature>.liquid \
  | sed '1d;$d' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{JSON.parse(s);console.log('schema JSON OK')})"
```

逐项：

| 项 | 判定 |
|---|---|
| 每个展示文案元素都有对应 schema setting / block setting | 缺 → `Failed` |
| `label` / `info` / `content` / option `label` 为**英文字面量**，未用 `t:` 前缀 | 用了 `t:` → `Failed` |
| `default` 里可以有英文占位（合法），但 Liquid 里不得 `\| default: '...'` 兜底 | 兜底 → `Failed` |
| Section Space schema（`section_top_pc` / `section_bottom_pc`）齐全 | 缺 → `Failed` |
| `color_scheme` / `enable_color_scheme` 按模块性质配置 | 缺且模块需要切换背景 → `Failed` |
| `presets` 存在，name 带 `SA:` | 缺 → `Failed` |
| 所有 setting `id` 在本 schema 内唯一；`type` 合法 | 重复 / 非法 → `Failed` |
| 同页不重复 `id`（含 `{{ section.id }}` 拼接） | 重复 → `Failed` |
| schema `step` / `max` / `min` / `range` 约束 | 静态查不出 → 交 `AdminSchemaSave`，本项不冒充 |

---

## B5. 空配置与满配置双测（两次都要跑，缺一 `Blocked`）

**这是 QA-B 最容易被跳过的一项。** 只测其中一种 → `Blocked`，不是 `Passed`。

### 空配置（所有 setting 清空 / 用默认新建实例）

- 每个 blank 字段对应的 DOM **不输出**：无 `<h2></h2>`、`<a href="#"></a>`、空 `<img>`、空 `<p>`。
- 无兜底英文文案泄漏到页面。
- section 整体不塌成空白高度块，也不报 JS 错。
- 取证：新建一个空实例，抓渲染后 HTML（或逐个 `!= blank` 守卫对照 markup 逐元素列出）。

### 满配置（所有 setting 填满 + block 加到上限 + 长文案）

- 布局不溢出 / 不遮挡；文字未被截断（呼应 §8.3）。
- block 数量到上限时 grid / swiper 正常。
- 长文案与 B6 的德语测试合并跑。

**两种配置各自覆盖全部五档断点**（PC / 1599 / 1279 / 767 / 375），结论并入 `RegressionMatrix`。没有"只看两档就够"的简化版——空配置的塌陷和满配置的溢出都是断点相关的。

> 🔴 **存量复用豁免（`handoff-schema.md` §8.1.2）不豁免本项。** 复用旧 section / snippet 时，「这个字段的问题以前就有」只免除**修复义务**，不免除**双测**：新接入的上下文、本次改过的字段与 schema、以及本次改动后可达的所有路径，空 / 满两种配置都要实测。留空导致崩溃**永远**是 🔴（红线⑩无豁免）。

---

## B6. 多语言

- 展示文案全部走 schema 或 locales（vendor §8.1），无 liquid / js 硬编码。**判定范围**：本次新增/修改的行；存量未触及的硬编码进 `Advisories`，但「本次让旧硬编码变得可达」按新增判——见 `qa-global.md` §7.1。
- 新增 locale key 时 `locales/en.default.json` 与其它 `locales/*.json` 同步——否则 theme check 会新增 `TranslationKeyExists` / `MatchingTranslations`，`ThemeCheck` 直接 `Failed`。
- **不得在代码中判断语言后切换字面量**：`grep -nE "request.locale|shop.locale" sections/sa-*.liquid` 命中且用于选文案 → `Failed`。
- 英译德长文案测试见 QA-Global 第 3 项（`LocalizationCheck`），本项只查配置面。
