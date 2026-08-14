# 团队协作（多人分担同一站 UX 迁移）

> 适用场景：多个 PLAUD 开发者**并行**做 US（或 jp / sg / eu）的 spec 迁移。

---

## 1. 入职 checklist（新成员第一天）

按权限分两种路径。

### 路径 A — 全权限（lead 或核心 dev）

1. **本地仓库**：clone 齐三个
   - `shopify-plaud-us`（或目标 region 站）
   - `shopify-common`（共享底层）
   - `shopify-claude`（迁移日志 + 操作手册 + 版本审计）
2. **Vite build 自测**：`cd shopify-common && npm install && npm run build` 不报错
3. **读 spec 源**（可选）：`~/Downloads/PLAUD_UX_规范基准_v1.3.md`；
   本地不存在时据 `spec-value-rules.md` §1 的 v1.3 修订段 + `pitfalls-*.md` 执行即可，**不阻断**
4. **读迁移日志**：浏览 `shopify-claude/ux-spec-migration/shopify-plaud-us/ux-spec-v1.2.md`，了解已完成项 + 全局待评估项
5. **读项目状态文件**：`memory/模板清单.md` / `memory/模块清单.md` / `memory/全局已知偏差.md`（格式见 `project-state-schema.md`）
6. **熟悉 skill 矩阵**：Path C 的入口是 `plaud-theme-ux-migration`；开工前必读 `plaud-theme-shared`

### 路径 B — 限权队友（只动 plaud-us，不动 shopify-common，可能无 git push 权限）

1. 跟 lead 索取 **`MODULE-UX-SPEC-RULES.md`**（位置：`shopify-claude/ux-spec-migration/shopify-plaud-us/MODULE-UX-SPEC-RULES.md`）——
   精简版规则速查，含 12 条约定 + utility class 全套清单 + 业务化的代码示例
2. 跟 lead 索取 spec 源文档
3. 在 lead 协调下**认领模块**；改完代码提给 lead 合并并触发 build
4. **不需要本机跑 Vite** —— 所有 spec utility 都已编译进 plaud-us 仓库内的 snippet，**HTML 加类名即可生效**

---

## 2. 模块认领协议（防撞车的最小协议）

> 注：「进行中 / Owners」认领表是**协调元数据**，**不受**「验收后才写日志」约束 ——
> 那条约束只针对迁移 **UX 差异日志内容**（`hard-rules.md` §2.3）。

1. 看迁移日志末尾的「进行中 / Owners」表
2. 选一个 `状态 = 待办` 的模块，把**自己的名字 + 日期**填进去
3. 开干前在 PR 或群里同步一句"我接 XXX"
4. 完成并**用户视觉验收通过后** → 把对应日志条目 append 到该模板的 wave 段，认领表与 `memory/模块清单.md` 状态写 `视觉已确认，待 QA（<ChangeSetId>）`；
   **`已迁` 这个完成态要等 `plaud-theme-qa` 给出该块 `ReadyForIntegration: Yes`、存在覆盖它的 `ReadyForDelivery: Yes` 工件、且身份三元组未失效才能写**（见 `project-state-schema.md`「完成态必须由 QA 背书」）
5. 阻塞 → 状态改 `卡住 + 原因`，让 lead 协调

---

## 3. 共享必须 vs 个人例外

| 类型 | 共享 | 备注 |
|---|---|---|
| 迁移日志 + 队友规则速查 | ✅ 单一 source of truth | 在 `shopify-claude/ux-spec-migration/shopify-plaud-us/`（`ux-spec-v1.2.md` + `MODULE-UX-SPEC-RULES.md`） |
| 项目状态文件（模板 / 模块 / 全局偏差清单） | ✅ 单一 source of truth | 项目侧 `memory/`，**不随 skill 包分发**（见 `project-state-schema.md`） |
| 本 skill 方法论 | ✅ 同一矩阵包 | 通过 `plaud-shopify-theme-matrix` 分发 |
| 个人 memory（临时偏好、调试上下文） | ❌ 不共享 | 每人自己的 `~/.claude/projects/.../memory/` |
| Shopify store 凭证 | ❌ 不共享 | 个人本地 `.shopify` |

---

## 4. 视觉验收闭环

代码改完**不是结束** —— 预览验收是验收链路的一部分：

1. 改完跑 `npm run build` 重新 build
2. shopify CLI 推到 dev store（或直接 preview）
3. 提交 PR；reviewer 在 `pre-release` 分支拉测试主题确认视觉
4. **验收通过后才更新 UX 差异日志内容**（「进行中 / Owners」协调元数据除外）
5. 交付判定仍走 `plaud-theme-qa` —— 用户验收视觉 ≠ `ReadyForDelivery: Yes`

---

## 5. 沟通禁区

- 🔴 **不在 PR 评论 / Slack 里贴 spec 源文档全文**（保密）
- 🔴 **不把 stored 配置值（特别是商家 API key / scheme id）粘公网**
