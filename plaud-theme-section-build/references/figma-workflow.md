# Figma → `sa-*` Section 工作流

六步，顺序不可打乱。第 6 步的双测不是可选项——空配置崩溃是 Path B 最常见的返工原因。

> 设计稿里的**数值**（字号 / 间距 / 弧角 / 颜色 / 断点）不在本文件也不在本 skill 的任何文件里，
> 一律去 `plaud-theme-shared/references/typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` 查档位。

---

## 第 1 步 — 读稿，拆 grid / blocks / settings

把设计稿拆成三类东西，落成清单再动手：

| 拆出什么 | 判断依据 |
|---|---|
| **grid / 布局骨架** | PC 与 Mobile 各几列、间距关系、对齐方式、是否轮播 |
| **blocks（可重复单元）** | 稿子里重复出现且数量可能变的单元 → block |
| **settings（单值配置）** | 每个实例只有一份的内容 → section settings |

同时标出：哪些是**运营会改的内容**（→ schema），哪些是**结构固定的**（→ 代码）。判不准就按"运营会改"处理——多给一个字段的成本远低于上线后回来加字段。

**这一步就要产出「素材清单」**：每张图 / 每段视频 / 每个 icon 分别来自 `image_picker` / `video` / 产品数据 / metaobject。凡是列不出来源的素材，都是准备写死进 `assets/` 的隐患（见 `naming-and-structure.md` §6）。

## 第 2 步 — 映射数据到 settings / blocks

- 每个设计稿元素对应一个字段，字段 `id` 用 snake_case 且语义化。
- 文案字段类型：短文案 `text`，可能换行/需内嵌 span 的 `textarea`，富文本内容 `richtext`（`section-header` 的三个标题字段固定 `textarea`）。
- 按钮永远是 **label + link 两个字段**，渲染时两者都非空才输出。
- 需要切换背景/文字色 → 加 `color_scheme`。
- 必带：`anchor_id_for_category`、`section_top_pc`、`section_bottom_pc`、`presets`。
- blocks 的 `type` 名同样语义化；有数量上限就写 `limit`。

## 第 3 步 — 写 Liquid

骨架顺序：

```liquid
{{ 'sa-<feature>.css' | asset_url | stylesheet_tag }}

<div id="{{ section.settings.anchor_id_for_category | handle }}"
     class="container {{ section.settings.section_top_pc }} {{ section.settings.section_bottom_pc }}">
  <div class="sa-<feature> gradient color-{{ section.settings.color_scheme }}">
    {%- render 'section-header',
        pre_heading: section.settings.pre_heading,
        heading:     section.settings.heading,
        sub_heading: section.settings.sub_heading -%}
    …
  </div>
</div>
```

要点：

- `stylesheet_tag` 在 section 顶层输出一次，**绝不放进 block 循环**。
- `image_url` 带 `width:`，按容器实际显示宽度 × 高 DPI 取值。
- 每个可配置字段外面包 `!= blank` 判断。
- section 内 `<style>` 只输出 CSS 自定义属性（把 schema 值桥接成变量），不写规则集。
- 同页不重复 DOM `id`；需要唯一 id 时拼 `{{ section.id }}`。

## 第 4 步 — 写 Schema

固定构成：

1. `+ Heading` header + `pre_heading` / `heading` / `sub_heading`（`textarea`）
2. 业务字段 / blocks
3. `color_scheme`（需要时）
4. `anchor_id_for_category`
5. `+ Section Space` header + `section_top_pc` / `section_bottom_pc`（原样复制，`value` 不改）
6. `presets`，`name` 带 `SA:` 前缀

`"name": "SA: <Feature>"`；`label` / `info` / `content` / option `label` 一律直接写英文，不用 `t:`。

## 第 5 步 — 写 CSS（mobile-first + 端变量）

- 文件 `assets/sa-<feature>.css`，全部选择器挂在 `.sa-<feature>` 根类下。
- **mobile-first**：默认样式是移动端，grid 从 1 列起，向上用 media query 加列。
- 任何断点下都不得出现横向滚动条；产品图保持原始比例，禁止强制裁剪。
- 走三层变量策略（下一节），断点内**只改变量映射**。
- 不重写 `.container` 的宽度/内边距，不写 section 级 margin，不重定义按钮与 swiper 控件视觉。

## 第 6 步 — 自检

| 检查 | 做法 |
|---|---|
| **空配置** | theme editor 里把所有可选字段清空、blocks 删光 → 不得报错、不得留空壳 DOM、不得塌成怪异布局 |
| **满配置** | 所有字段填满、blocks 加到上限、文案取长值 → 不得溢出、遮挡、截断 |
| **英译德长文案** | 把英文文案翻成德语（通常长 30–50%）再看 UI |
| **多语种** | 至少再验一个小语种站点，确认无硬编码英文残留 |
| **断点** | 按 shared `responsive-and-spacing.md` 的断点逐档看 |
| **vendor §8–§11** | 跑 `vendor-compliance.md` 的 Checklist |

空配置与满配置**两端都要测**——只测满配置是最常见的漏项，运营上线时字段往往是半空的。

Theme Check、admin schema 保存、视觉回归、A11y 由 `plaud-theme-qa` 判定（跑 QA-B，外加它恒执行的 QA-Global；后者**不写进** `RequiredQAProfile`）；实现侧的自检结果写进 handoff 正文，**不得**据此宣布通过。

---

## 响应式三层变量策略

**端变量 → 运行变量 → 属性只读运行变量。** 三层缺一层就会退化成"在断点里写死 px"。

```css
.sa-<feature> {
  /* 第 1 层：端变量，按端各存一份。
     取值绑 spec token（--space-* / --text-* 等），token 名与档位查 shared responsive-and-spacing.md，
     下面的 SPACE_TOKEN_M / SPACE_TOKEN_PC / COLS_PC 是占位，写代码时替换成真实 token 名与列数 */
  --sa-<feature>-gap-m:  var(--SPACE_TOKEN_M);
  --sa-<feature>-gap-pc: var(--SPACE_TOKEN_PC);
  --sa-<feature>-cols-m:  1;
  --sa-<feature>-cols-pc: COLS_PC;

  /* 第 2 层：运行变量，默认映射到移动端（mobile-first） */
  --sa-<feature>-gap:  var(--sa-<feature>-gap-m);
  --sa-<feature>-cols: var(--sa-<feature>-cols-m);
}

/* 断点内只改映射，不出现字面 px */
@media (min-width: …) {          /* 断点值查 shared responsive-and-spacing.md */
  .sa-<feature> {
    --sa-<feature>-gap:  var(--sa-<feature>-gap-pc);
    --sa-<feature>-cols: var(--sa-<feature>-cols-pc);
  }
}

/* 第 3 层：属性只读运行变量，不直接读端变量、不写字面值 */
.sa-<feature>__grid {
  display: grid;
  grid-template-columns: repeat(var(--sa-<feature>-cols), minmax(0, 1fr));
  gap: var(--sa-<feature>-gap);
}
```

规则：

1. 端变量命名 `--sa-<feature>-<prop>-m` / `--sa-<feature>-<prop>-pc`。
2. 运行变量 `--sa-<feature>-<prop>`，默认绑 `-m`。
3. **属性声明只读运行变量**；出现 `padding: var(--sa-x-gap-pc)` 就是越层。
4. **media query 内只出现变量重绑**；出现 `font-size: <字面 px>` 这类硬值就是违规。
5. 端变量的取值本身要绑 spec token（`var(--space-*)` / `var(--text-*)` 等），不是裸 px——具体 token 名查 shared 的 reference。
6. 需要第三档（如 pad）时按同样模式加 `-pad` 端变量，不破坏三层结构。

组件宽高同理：用流式宽度、`min-*` / `max-*`、`aspect-ratio` 和变量映射驱动，**不写死 `width` / `height`**。例外仅限 `plaud-theme-shared/references/handoff-schema.md` §8.2 列明的几类（细线、图标、明确固定的技术容器、Swiper 特定 effect 要求的固定 height），且须在 handoff 里说明原因。

---

## Figma 值不落在 spec 阶梯上时怎么办（停机点）

设计稿给的是像素，spec 给的是离散档位，两者对不齐是常态。**三种情况，处理方式不同，其中一种必须停机问用户。**

```
Figma 值 v，spec 阶梯 …a < v < b…
  ├─ v 明显更接近某一档（近邻 token 存在且距离不等）
  │     → 就近 snap 到该档，在 handoff 正文注明「Figma v → spec X（snap）」
  ├─ v 与两档等距 / 距离接近到难分（具体示例见 shared handoff-schema.md §7）
  │     → 🛑 停机问用户选哪一档，不得擅自定
  └─ spec 阶梯里明确没有近邻 token，且该值在视觉上重要（不是可忽略的微差）
        → 🛑 先与用户确认，确认后方可使用字面 px，并在 handoff 正文标注为已确认的例外
```

要点：

- **"等距两可"必须停。** 自行择一是 Path B 里最隐蔽的偏差来源：它不会报错、QA 也未必看得出，但会让整站阶梯逐渐失真。
- **就近 snap 也要留痕**，写进 handoff 正文的取值说明，让 QA 能复算。
- **字面 px 永远是例外**，需要"用户确认"这一前置动作，不能事后补一句"设计稿就是这么标的"。
- 停机时按 `plaud-theme-shared/references/handoff-schema.md` §7 的要求写 `BlockingGaps`：说清是哪个属性、Figma 值多少、候选档位有哪些、需要用户选什么。不要输出半成品再附"可能需要确认"。
- 字重、行高同样适用：全站字重是单一档，设计稿标了别的字重 → 按 spec 走并告知，不要为它自造字重。
