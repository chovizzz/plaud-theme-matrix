# 同族 bug 扫描

> **关键认知：一个 bug 常伴 3–5 个同族 bug。**
>
> 理由是机制性的：bug 极少来自"手滑一次"，多来自一个被反复套用的错误写法、一个被误解的 API 语义、或一次复制粘贴的扩散。修掉触发点而不扫同族，等于把同一个根因留在仓库里，下周以另一个 issue 的形式回来。

**修完必扫。**扫描结果无论有没有命中，都要在正文写出来——写"已扫，0 命中，扫描命令如下"是合格的；不写是不合格的。

---

## 什么是"同族"

同族 = **同一机制层根因的其它发作点**。不是"看起来相似的代码"。

判定方法：把你在 Orient 阶段写下的根因改写成一句可检索的**特征描述**，再问"这个特征还出现在哪"。

| 根因 | 同族特征（要搜的东西） |
|---|---|
| inline style 覆盖媒体查询 | 其它在 Liquid 里直接输出 `style="..."` 的响应式属性 |
| 事件重复注册 | 其它在 `connectedCallback` / 初始化里 `addEventListener` 却无对应移除的地方 |
| 生命周期未清理 | 其它 `setInterval` / `setTimeout` / `new *Observer` / `subscribe(` 没有配对清理的地方 |
| Swiper effect 相关（根因以 shared `javascript-swiper.md` 的约束表为准） | 其它使用同类 effect 的 Swiper 初始化点 |
| 循环内输出 `stylesheet_tag` | 其它在 `for` / `tablerow` 内 render 的 snippet |
| 图片缺 `width` / 或 width 取值过小 | 其它 `image_url` 调用点 |
| 展示文案硬编码 / `\| default:` 兜底 | 其它同一 section 家族里的文案输出点 |
| 同页 id 重复 | 其它未加 `section.id` 作用域的 `id="..."` |
| 缺 null 守卫 | 其它对同一 DOM 查询结果直接取属性的地方 |

---

## 扫描方法（四步）

### 1. 把根因写成特征

一句话，包含**可 grep 的字面标记**。写不出可 grep 的标记，说明根因还太抽象，回去继续 Orient。

### 2. 定扫描范围（由窄到宽，逐圈扩）

| 圈层 | 范围 | 何时必扫 |
|---|---|---|
| 第 1 圈 | 出问题的那个文件 | 恒扫 |
| 第 2 圈 | 同一 section 家族（section + 它 render 的 snippets + 它的 CSS/JS） | 恒扫 |
| 第 3 圈 | 同一基类 / 同一 custom element 继承链上的所有实现 | 根因在 JS 生命周期、事件、Swiper 时必扫 |
| 第 4 圈 | 全仓同类调用点 | 根因是"写法被反复套用"型（inline style、`image_url`、`stylesheet_tag`、`\| default:`）时必扫 |

第 4 圈的命中量可能很大，**不要因此放弃扫描**——扫是必做的，修不修由分诊决定（见第 4 步）。

### 3. 跑命令，记原文

用 `grep -rn` / `grep -rln` 在 `sections/` `snippets/` `assets/` `templates/` 上按特征扫。**命令原文必须写进正文**，让 QA 能复算（`QA-A` 的第一项就是同族 bug 扫描）。

模式：

```bash
# 特征字面量扫描
grep -rn '<特征字面量>' sections/ snippets/ assets/

# 配对缺失扫描：找到注册点，再逐个确认有没有对应清理
grep -rln 'addEventListener' assets/*.js
grep -rn 'disconnectedCallback' assets/*.js

# 循环内 render 扫描（找到 for 块后逐个看块内 snippet）
grep -rn '{%-\? *for ' sections/ snippets/
```

只写 `grep` 不看输出等于没扫。命中项要**逐个打开确认**是不是真同族——`ActualAffectedInstances` 的教训在这里同样适用：**理论命中 ≠ 真同族**，两者必须分开报。

### 4. 分诊，不要顺手全修

扫出来的每一条分三类：

| 分类 | 处理 |
|---|---|
| **同 ChangeSet 内修** | 与本次根因同一文件、同一机制、改动量小、不扩大影响面 → 一并修，写进 `ModifiedFiles` |
| **本次不修，报出来** | 确认是同族但落在本次授权范围外、或需要独立 Assess（触及共享层 / 多实例 / 需要模板存值授权）→ 写进正文"同族发现（本次未修）"并进"待 QA 验证的点"，由用户决定是否另起 ChangeSet |
| **误报** | 打开后确认不是同一根因 → 记一句排除理由，不列入 |

**红线：同族修复不得让改动扩散出授权范围。**"顺手把全仓 200 处 `image_url` 都改了"是把一次 bugfix 变成不可验的大改动，QA 会因 `ChangeSetId` 与工作树不符而停机。宁可报出来另起一个 ChangeSet。

---

## 正文里怎么写

```
## 同族扫描
特征：<可 grep 的根因特征>
范围：第 N 圈（<列出目录/文件>）
命令：
  <命令原文>
理论命中：N 处
真同族：M 处
  - 本次一并修：<列表>
  - 本次未修（需另起 ChangeSet）：<列表 + 原因>
  - 误报排除：<列表 + 一句排除理由>
```

`M = 0` 是合法结果，但必须附命令原文——**"我看了一遍没发现"不算扫描**（shared 核心规则 3：证据，不是声明）。
