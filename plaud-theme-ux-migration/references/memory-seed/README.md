# 一次性迁移种子（2026-07 快照）

## 这是什么

本目录三个文件是 **2026-07 时点** `shopify-plaud-us` 的模板 / 模块 / 全局偏差状态**快照**，
从旧单 skill 的 `ux-spec-v13-migration.md` 附录 A / B / 全局已知偏差表原样搬运而来。

## 🔴 种子里的数值是「实测历史证据」，不是规范值

这三个文件里出现的字号 / 间距 / 颜色 / 断点等具体数值，记录的是 **2026-07 当时仓库里实测到的状态**（"当时是 42px、spec 是 40px，差 2px"这类事实），
**不是**规范值，**不构成**第二份事实源。

> **规范一律以 `plaud-theme-shared/references/` 为准**（`typography.md` / `colors-and-schemes.md` / `responsive-and-spacing.md` / `media-quality.md`）。
> 种子与 shared 的数值不一致时，**shared 是对的**，种子只说明"当时偏差是多少"。
> **禁止**把种子里的数值当成 spec 拿去落地，也禁止拿它反推/覆盖 shared 的规范值。

保留这些数值的唯一价值是**项目历史可追溯**：让下一个人知道某个偏差是历史遗留还是新引入的回归。

## 怎么用（只用一次）

**仅当项目侧 `memory/` 下还没有这三个文件时**，复制过去：

```bash
cp references/memory-seed/模板清单.seed.md   <项目>/memory/模板清单.md
cp references/memory-seed/模块清单.seed.md   <项目>/memory/模块清单.md
cp references/memory-seed/全局已知偏差.seed.md <项目>/memory/全局已知偏差.md
```

复制后**必须**：

1. 告知用户「这是 2026-07 的快照，需要人工核对当前真实状态」
2. 与仓库实际情况对一遍（模板是否还在、实例数是否还对、状态是否已推进）

## 🔴 复制之后，种子不再是事实源

- **项目侧 `memory/` 的副本才是事实源**，由项目维护
- 本目录**不随包更新**、也**不反向同步** —— 下次 install 时 skill 包被整体替换，这三个种子文件会回到 2026-07 的内容
- 所以：**永远不要**把项目侧的最新状态回写到这里，也**永远不要**在项目已有 `memory/` 文件时用种子去覆盖它

## 已有 `memory/` 文件但内容可疑时

**停机问用户**，不要用种子覆盖，也不要凭空重建 —— 见 `../project-state-schema.md`。

字段含义与填写规则同样见 `../project-state-schema.md`。
