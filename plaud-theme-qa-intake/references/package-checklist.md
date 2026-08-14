# 提测包六项材料 —— 逐项验收标准

**何时读我**：判定某份材料算不算 `Complete` 时。测试用例的格式细则另见 `test-case-format.md`。

来源：《DTC 开发交付标准 v1.0》§四「交付物要求」。原文口径是「**提测时必须同时提供，缺一不进验收**」。

> 判定原则：**逐条可查**。判 `Incomplete` 时必须指出缺的是哪一项的哪个字段，不写"材料不全"。

---

## 1. 预览链接（`PreviewManifest` 内容 / `PreviewManifestStatus` 判定）

| 项 | 要求 |
|---|---|
| 数量 | **两条**：后台链接 + 前端链接。只给一条判 `Incomplete` |
| 后台链接 | 必须**可配置**——打开能看到该 section 的 schema 字段并能改。只能看不能改的只读预览不算 |
| 前端链接 | 必须**可访问**——实际打开过，不是"理论上应该能开" |
| 实测记录 | 记下检查时间。DTC 原文：**失效链接视同未提测** |
| 定位精度 | 链接要落到具体主题 + 具体页面，不是店铺首页让人自己找 |

记录形态：

```
后台：https://admin.shopify.com/store/<store>/themes/<themeId>/editor?template=<t>  ✅ 2026-08-12 14:30 可访问、可配置
前端：https://<store>.myshopify.com/?preview_theme_id=<themeId>                     ✅ 2026-08-12 14:31 可访问
```

**多站点提测**：`TargetSites` 里的每个站点都要有自己的一对链接，不能用一个站点的链接代表全部。

---

## 2. 配置文档（`ConfigurationGuideStatus`）

**触发条件**：本次新增了 section 或新增了配置项。两者都没有才可填 `NotApplicable`（并写明理由）。

必须包含四件事，缺一判 `Incomplete`：

| 内容 | 说明 | 反例 |
|---|---|---|
| 字段说明 | 每个 schema 字段是干什么的 | 只列字段名 |
| 默认值 | 每个字段的默认值是什么 | "默认就行" |
| 使用场景 | 什么情况下该改它 | 缺失 |
| **填错怎么办** | 填了非法值 / 留空会发生什么 | 缺失（最常漏的一项） |

**关键部分必须有截图**——DTC 原文要求。纯文字的配置文档判 `Incomplete`。「关键部分」指：后台该 section 的配置面板全貌、以及任何需要按特定格式填写的字段。

> 与 QA-B 的「空配置 / 满配置双测」呼应：配置文档里写的"留空会怎样"，QA 会实际去测。两边说法不一致时以 QA 实测为准，并退回补文档。

---

## 3. 测试文档（`SelfTestReportStatus`）

格式细则见 **`test-case-format.md`**。此处只记判定线：

| 判定 | 条件 |
|---|---|
| `Complete` | ① 每条用例四段齐全（前置条件 / 操作步骤 / 预期结果 / 结论）**且**有附件截图或视频；② **测试集溯源三项齐全**（见下） |
| `Incomplete` | 任一条用例的预期结果写成"显示正常""功能可用""无异常"——DTC 原文：**这类用例视同未测** |
| `Incomplete` | 有用例但无截图/视频附件 |
| `Incomplete` | 只有结论没有步骤（"测过了，没问题"） |

**不接受 `NotApplicable`**：任何改动都有可测面。真的无从测起时说明本身就是问题，停机问清楚。

### 测试集溯源三项（DTC §一 第 3 条）

DTC 要求 agency **维护测试集并随交付更新，不是一次性文档**。要能查证这一点，光有用例不够：

| 项 | 要求 | 缺了会怎样 |
|---|---|---|
| 测试集引用 | 本次用例挂在哪个测试集下（链接 / 文档 ID） | 看不出是不是同一份长期资产 |
| 基线版本 | 该测试集的版本号或快照时间 | 无法判断是否在最新基线上做的 |
| **本轮增删清单** | 新增了哪几条、更新了哪几条（逐条标 ID） | 分不出"增量维护"和"每次现编一份" |

三项缺任一 → `SelfTestReportStatus: Incomplete`。

> ⚠️ **矩阵不拥有测试集本身**（与 `memory/` 同类，项目侧长期资产，不随包分发）。这里只查"有没有挂在测试集上"，不查测试集内容。
> Aily 的审查是**外部人工流程**，矩阵不代替：尚未双方固化时记 QA 的 `Advisories`，**不进 `BlockingGaps`**（那是停机项），也**不因此判 `Incomplete`**。

---

## 4. 断点截图（`ScreenshotManifestStatus`）

**8 张，一张不能少**：

| 类型 | 宽度 |
|---|---|
| 标准档 | `375` / `768` / `1024` / `1280` / `1440` |
| **边界值** | `767` / `1279` / `1599` |

边界值是重点——`767` / `1279` / `1599` 正对着矩阵的三个 `.98` 判定断点（`responsive-and-spacing.md` §1），是布局最容易在整边界上错位的位置。少了边界截图判 `Incomplete`，不能用"标准档看着没问题"顶替。

**每张截图要能认出是哪个断点**：文件名带宽度，或截图里带浏览器宽度指示。一堆没标注的图判 `Incomplete`。

> ⚠️ 这 8 张是**交付材料**，不是 QA 的回归证据。QA 自己还要跑 `PC / 1599 / 1279 / 767 / 375`（Path C），两套并存。

---

## 5. 影响范围说明（`ImpactScopeStatus`）

两个维度，缺一不可：

| 维度 | 来源 | 内容 |
|---|---|---|
| 模板 / 实例 | **引用 `AssessmentRef`**，不自行重算 | 本模块被几个模板使用、`ActiveInstances` / `DisabledInstances` / `ActualAffectedInstances` |
| 站点 | 本 skill 的 `TargetSites` / `ExcludedSites` / `ThemeIds` | 涉及哪些站点、排除了谁、各自主题 ID |

> 🔴 **不得在这里重新算一遍影响面。** 那是 `plaud-theme-impact` 的职责，重算会产生第二个事实源。本 skill 只做两件事：确认 `AssessmentRef` 存在且对应本次 ChangeSet，以及补上它不覆盖的站点维度。
>
> 没有 `AssessmentRef`（`ReconMode: InlineLite` 的任务）→ 引用实现工件里的 `InlineLite` 豁免理由，仍要有站点维度。

---

## 6. 返工修改点（`ReworkDeltaStatus`）

**只在返工轮次要求**。首轮提测填 `NotApplicable` + 一句"首轮提测"。

返工轮次必须给「本轮修改点」清单，逐条三段：

```
反馈原文 → 改了什么 → 落在哪个文件（含行号或函数名）
```

判 `Incomplete` 的情形：

- 只写"按反馈修改了"，没有逐条对应
- 有改动但清单里没列（清单条目数与 `ModifiedFiles` 明显对不上）
- 把**需求变更**混进返工清单——变更不计返工轮次，归属由 `plaud-theme-feedback-triage` 判，本 skill 发现混装时记进 `BlockingGaps`

---

## 汇总判定

| `SubmissionPackageStatus` | 条件 |
|---|---|
| `Complete` | **六项 Status** 全为 `Complete`（`ConfigurationGuideStatus` / `ReworkDeltaStatus` 可为 `NotApplicable` + 理由），且 `PreviewManifestStatus: Complete`（两条链接实测可访问） |
| `Incomplete` | 其余任何情况 |

**没有中间态**。「大部分齐了」「就差截图」一律 `Incomplete` —— DTC 的原文是「缺一不进验收」。
