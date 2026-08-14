# 全局已知偏差 / 待评估（跨模板共享）

> 🔴 **本 seed 是 2026-07 快照，其中 label 色阶相关条目已被 2026-08-11 UX 基线 supersede**（secondary `#7A7A7A` → `#717171`、**tertiary 档废止**）。复制到项目侧后**需重新评估**这些条目，不要直接沿用。历史记录本身不改写——它记的是当时的事实。

> ⚠️ **一次性种子 — 2026-07 快照。** 首次使用时复制到项目 `memory/全局已知偏差.md`，之后即由项目维护，**不再随包更新**。
> 字段含义见 `../project-state-schema.md`；使用规则见 `README.md`。
>
> 🔴 **本文件内的字号 / 间距 / 颜色 / 断点等数值是「实测历史证据」（2026-07 当时仓库的实际状态），不是规范值。规范一律以 `plaud-theme-shared/references/` 为准；两者不一致时以 shared 为准，禁止拿本文件的数值当 spec 落地或反推覆盖 shared。**

| 项 | 现状 | 状态 |
|---|---|---|
| cs-section-header Heading PC = 42 | spec large-title-2 = 40，+2px 偏差 | **已修**：本轮 v1.3 wave 中 cs-section-header CSS 直接消费 `var(--text-large-title-2)`（40px PC），偏差消除 |
| cs-section-header 与下方内容间距 | 之前 48px（非 spec） | **已修**：space-8 (32px)，全 8 模块统一收紧 |
| 按钮 MD vs SM 档差 | spec §3.2 中 MD = 8/24+16，SM = 5/15+12 间隔偏大 | 已挂 Landing 模块待评估 |
| 富文本 H1–H6 字号 | 走主题历史值，未对齐 spec §1.2 | 已挂 FAQ 模块待评估，全站影响 |
| 默认配色方案 border #E5E5E5 → #EBEBEB | 已修 | DONE |
| v1.3 label 色阶重组 | secondary #3D3D3D→#7A7A7A，tertiary #7A7A7A→#A3A3A3，quaternary 移除 | **已修**：design-tokens.scss + design-utilities.scss 同步落实；全站 .text-secondary / .text-tertiary 调浅 |
| `--color-label-quaternary` 引用 | v1.2 token 已删除 | 6 模块迁移时已扫描 + 改为 tertiary（同 hex 无视觉影响）|
| Tailwind text-align! 物理对齐类 | 早期 index.html 字面量未覆盖 | **已修（2026-06）**：`.text-left!/.text-center!/.text-right!`（及 start/end）已确认在 critical bundle（base-style），可直接 emit 物理值，`right→end`/`left→start` 映射降为可选（见 12 条约定 #4）|
| 移动端断点 | 历史各模块用 767 / 768 / 767.98 混用 | **已修**：全统一 767.98（min-width 侧仍 768） |
| .container 左右留白（Xs / 手机端） | 历史 15px | **已修（2026-06-15 DTC-399）**：改 24px；影响全站所有用统一容器的模块，小屏与手机端内容区收窄 |
| 商品角标 §2.6 颜色 | 过去后台可调 5 种角标字色/底色 | **已修（2026-06-30）**：角标颜色锁规范色板（新增 badge token + `.badge-*` 类，元素叠 `.badge-sale/-sold-out/-new/-pre-order/-subscription`，由类设 `--badges-bg/--badges-color`、`.product__badges-inner` 消费）；字号→`fs-body-sm`、字重去除、圆角→`radius-base`；删 `settings_schema.json` 9 个角标颜色字段 + 圆角字段、清 `theme.liquid`/`password.liquid` 角标 CSS 变量、9 个文件删 dead `data-*`、`theme.js` 动态角标改用类（去 `setProperty`/`subheading_weight`）；custom 角标保留可配；已验证无残留引用。**影响全站商品卡 + 商品页** |
