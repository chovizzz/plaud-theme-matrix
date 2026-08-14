# 踩坑库 — CSS / 工具类层（§4.2 §4.3 §4.9 §4.10 §4.16 §4.17）

> **配方前提**：本文件是「**已获授权的迁移中怎么做**」，不是做出改动的授权本身。
> 一律在 Path C 硬规则之下运行：① `templates/*.json` 默认只读；② 不写死颜色 / 不逐元素开 color picker；
> ③ 不写死组件宽高；④ 非 spec 值等距两可**问用户**、不擅自 snap；⑤ schema option values 不改、验收前不写 UX 差异日志内容。
> 冲突时**以硬规则 + 其授权为准**。完整总纲见 SKILL.md「§4.x 配方的适用前提」。

---

## §4.2 hex 字面量大小写

- 新写 spec 字符串**统一大写**
- 老代码 hex 小写**不连动改**（用户规则：hex case 不动模板）

## §4.3 注释纪律

- **默认不写注释**。只在 WHY 非显然时用一行说明
- 禁止「used by X / added for Y flow / removed because Z」这类**指向当下任务**的注释
- 禁止跨文件指引（"详见 style.scss"）

## §4.9 markup 工具类 vs scss token 的取舍（与「加载分层」互补）

`conventions-12.md` 的「加载分层」按 **FOUC** 决定 utility-on-HTML vs 组件 CSS；本条按**响应式 / 继承**再补一刀：

- **非响应式**的字号 / 色 / 圆角 / 底色 / 间隙 → **markup 工具类**（`fs-*` / `text-*` / `radius-base` / `bg-*` / `gap-sp-*`）
- **响应式**（PC / MB 不同值、单一工具类命不中）或**需 `currentColor` 继承**（如 SVG 图标随父色）→ **scss + `var(--token)`** 配媒体查询
- ⚠️ **async** 加载的 section-scoped bundle 里，响应式 box 样式写 scss 仍有 FOUC 风险（见加载分层）；
  **非 async bundle**（如 `main-cart.min.css` 用普通 `stylesheet_tag` 加载）无此顾虑，响应式 scss 可放心用

## §4.10 不重复固定容器已有的工具类

容器 markup 已挂工具类（如 `fs-body-md`）时，**scss 里不要再把容器同属性固定一遍**——多余，且易引出"该用 inherit 还是显式值"的纠结。只对**需要的后代 / 状态**加规则。

### 🔴 `fs-*` 类已自带 line-height，别再写 `line-height`（2026-06-30）

- 标题类（`fs-large-title-*` / `fs-title-*` / `fs-headline`）走 `--head-line-height`
- 正文类（`fs-body-*`）走 `--body-line-height`
- 两个变量的具体值见 shared `typography.md`

两个方向的坑：

1. **正向冗余**：加了 `fs-*` 还显式写 `line-height` 是冗余，且和规范打架
2. 🔴 **反向坑**：把原本**紧凑**行高的组件文字换成 `fs-body-*` 正文类，行高会**从紧凑变松**。
   要保留非规范紧凑行高，**必须显式覆盖并知会用户**；否则就接受规范行高——**不要默默变松再让用户在预览里发现**

### 富文本 / textarea 内容块 → 优先 `.richtext-container`

运营可能在富文本里塞 H1–H6。直接给容器加 critical 现成工具类 **`.richtext-container`**：

- 它让后代（`sub` / `sup` 除外）`font-size / color / margin: inherit`，统一继承容器的 `fs-*` / `text-*`
- **不管放 h 几，字号 / 色都一致**
- 特异性高于裸 `h2{font-size}`，在 critical 即时生效、**无 FOUC**

🔴 **优先用它**，不要自写 `.container *:not(sub,sup){font-size:inherit}` 这类 scoped 规则。

## §4.16 `.grid grid-cols` 网格禁止叠 `gap-sp-*` 类

主题的 `.grid.grid-cols` 用 `--gap: var(--col-gap-desktop, var(--col-gap))` **参与列宽计算**。
再叠一个 `gap-sp-*`（直接写 `gap`）会与列宽 calc 冲突 → **列宽 / 列距错乱**。

- **改用内联 `--col-gap: var(--space-N)`** 喂给网格（与本仓其它 `--col-gap: var(--space-4)` 写法一致）
- 普通 `display:grid`（**非** `.grid-cols`）无此约束，可直接挂 `gap-sp-*`
- 另注意：`.grid-cols` **只设 `--gap` 不写 `gap`**，做网格间距时**还得补 `.gap` 类**（见 `utility-reference.md` §2.5）

## §4.17 `my-0` 会盖掉 `mar-b-*`

`my-0`（`margin-block: 0`）把上下 margin **都**归 0，与 `mar-b-*` **同特异性、后加载者胜** → 常把想要的下间距吃掉。

- 要"上 0 + 保留下间距" → 用 **`mt-0` + `mar-b-*`**（`mt-0` 只设上）
