# 依据怎么查 —— PRD / Figma / UX Spec

**何时读我**：给某条反馈找 `EvidenceRefs` 时。边界情形的判定见 `classification-rules.md`。

「找到依据」的标准：**能写出可复核的引用**——PRD 的第几条、Figma 的哪个节点、Spec 的哪一节。写"PRD 里有提到"不算找到。

---

## 1. 查找顺序

按**具体度**从高到低查，先命中先用：

```
1. DTC §2.1 硬性 10 条   ← 最具体，逐条可查，命中即缺陷
2. PRD                   ← 功能层依据
3. Figma                 ← 视觉层依据（注意有稿区间）
4. UX Spec               ← 规范层兜底
```

四个源都查过、都没有 → `RequirementEvolution`。**"没找到"和"没查"是两回事**，`EvidenceRefs` 要写清查了哪些、结果如何。

---

## 2. PRD

| 查什么 | 怎么写引用 |
|---|---|
| 该功能是否在需求里写明 | 「PRD §2.3『订阅卡片支持切换周期』」 |
| 该字段是否要求可配置 | 「PRD 需求表第 5 行」 |
| 验收标准里有没有这一条 | 「PRD 验收标准第 3 条」 |

**PRD 未涵盖 ≠ 变更**：还要继续查 Figma 和 Spec。功能没写但稿里画了，仍是缺陷。

DTC §八 对等承诺：需求必须写明**目标站点、期望效果、验收标准、影响范围**。**信息不全导致的返工不计开发返工轮次**——PRD 里这四项缺失时，因此产生的返工要在 `EvidenceRefs` 里点明，不计返工。

---

## 3. Figma

| 项 | 要求 |
|---|---|
| 引用形态 | **必须能定位到节点**：文件名 + 页面 + frame / 节点名，或直接 node 链接 |
| 断点 | 说明是哪个断点的稿（PC / M 端） |
| 定稿状态 | 未定稿的稿不作为依据（DTC §八：稿未定不启动开发） |

### 🔴 无稿区间

**1280–769px 没有设计稿。** 这个区间的「和稿不一样」不成立——`EvidenceRefs` 只能引 UX Spec，不能引 Figma。

判断某个反馈落在哪个区间：问清楚反馈是在多宽的视口下看到的。反馈方没说 → 停机问，不要默认是 PC。

### 改稿即变更

DTC §八：「**改稿即变更**，重新计费与排期；变更须飞书/确认，口头不生效」。

所以：如果 Figma 在开发之后被改过，按**开发时的版本**判定。查 Figma 版本历史，实现符合旧版 → 不是缺陷，是变更。

---

## 4. UX Spec

现读 `plaud-theme-shared/references/` 的当前值，**不要凭记忆**，也不要引用本 skill 包里的任何数值副本（本包不留副本）：

| 反馈涉及 | 读哪个文件 |
|---|---|
| 字号、字重、标题层级、区头 | `typography.md` |
| 颜色、配色方案、角标、对比度色值 | `colors-and-schemes.md` |
| 断点、间距、圆角、按钮尺寸、容器宽度、组件尺寸 | `responsive-and-spacing.md` |
| 对比度判定、键盘可达、focus | `a11y.md` |
| 图片清晰度、CLS、视频 | `media-quality.md` |
| 文案 i18n、schema 规范、价格格式 | `liquid-schema-format.md` |
| Swiper、JS 生命周期 | `javascript-swiper.md` |

引用写法：「UX Spec / `responsive-and-spacing.md` §4.1.1 容器内边距表：LG-Wide 档每侧 80px」。

### 🔴 先分清「Spec 没规定」和「Spec 规定了但我没找到」

Spec 有已知缺口（如 `colors-and-schemes.md` 记录的**品牌渐变只给色标、缺圆心/半径/形状/stop 位置**，以及 `typography.md` §4 记录的**标签名 h1–h6 在 spec 层没有对应档位**）。遇到看起来没覆盖的项：

1. 先在对应文件里搜一遍关键词；
2. 搜不到 → 看该文件有没有把这一项标为**已知缺口**；
3. 确实没覆盖 → 写「Spec 未覆盖」，判 `RequirementEvolution`；
4. **不要**用"通常来说规范应该是…"补全。

### 🔴 Spec 与仓库 token 不一致

见 `classification-rules.md` §2.4：算 PLAUD 缺口，不打回开发。核对方法见 `plaud-theme-shared/references/repo-drift.md`。

---

## 5. `EvidenceRefs` 的写法

每条反馈一组，**查过的都要写，包括没找到的**：

```yaml
EvidenceRefs:
  - 反馈 #2「移动端标题没左对齐」
      DTC §2.1：第 10 条「含模块标题的 section 必须提供独立于 PC 的移动端对齐配置」→ 命中
      UX Spec typography.md §5：区头对齐须传参进 snippet（text_align_mb）→ 命中
      结论：有明确依据
  - 反馈 #3「卡片间距太小」
      PRD：未涵盖间距要求
      Figma：node 4521:882（PC 稿）间距 24px，实现实测 24px → 一致
      UX Spec responsive-and-spacing.md §3：24px = space-6，在阶梯上 → 合规
      结论：三个源均未支持该反馈
```

第二条的写法很关键：**它证明了"查过且没找到"**，而不是"我觉得这是变更"。这是 PM 能据以判定的形态。
