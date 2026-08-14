# 理论影响 vs 实际影响 — 收敛方法论

> "改的是共享文件"**不等于**"全站都会变"。逐项核查后真实影响往往收敛很小。
> 只报"可能影响 N 处"是不合格的 Assess。

方法论来源：一次给**共享 section 接入配色方案**的评估——表面 blast radius 是 17 个模板 + footer，逐项核查后**实际只有 footer 一条线会变化**。下面把那次的判断拆成可复用步骤。

---

## 步骤 1 — 量理论引用（`TheoreticalReferences`）

```bash
grep -lr "\"type\": \"<module>\"" templates/ | wc -l          # 命中模板数
grep -c  "\"type\": \"<module>\"" templates/*.json            # 每模板实例数（含 disabled）
grep -rn "render '<snippet>'" sections/ snippets/ layout/     # snippet 类：调用点数
grep -rn "\.<class-name>\|var(--<token>)" assets/ shopify-common/src/   # CSS/token 类：消费点数
```

这个数字**只是上界**，不是结论。写进 `TheoreticalReferences` 并注明口径（模板数 / 实例数 / 调用点数，别混）。

`IntegrationSurface`（纯新建）下如实写 `PreExistingCallers: 0` + 计划新增的接入点 —— **不得为新建 section 虚构"模板使用量 N"**。若计划接入的是**已有**模板/section group，模式应已升级为 `LegacyImpact`。

---

## 步骤 2 — 扣除 disabled 实例（`DisabledInstances` 必须单列）

```bash
grep -B 1 '"disabled": true' templates/<t>.json | grep '"type"'
```

逐模板跑，把 `type` + 实例 id 记成清单，整个评估期间反复 cross-check。

零容忍规则：`"disabled": true` 的实例**不进影响面、不进对比表、不动 stored 值**（即使它偏离 spec 也不改）。

`DisabledInstances` **不得并入 `ActiveInstances`**。两个数字必须分列，QA 会复算。

```
ActiveInstances = 理论实例数 − disabled 实例数
```

**该公式只适用于可从 template JSON 枚举的 section 实例。** 目标是 snippet 调用点 / 全局 CSS / token 消费方 / layout / footer / JS custom element / locale key 时，没有"模板实例"概念——按**调用点数**或**消费点数**统计，并在字段值里注明口径，例：`ActiveInstances: 4 (render 调用点数，非模板实例)`。此时 `DisabledInstances` 通常为 `0 (N/A — 非模板实例口径)`，照样单列，不得省略字段。

---

## 步骤 3 — 逐项判断"是否真触发"

对每个**启用**实例问三个问题。任一为"否" → 从 `ActualAffectedInstances` 剔除，并在「已核查排除」段写明理由。

### Q1：这个实例真的走到被改的代码分支了吗？

被改的是某 `{% if %}` 分支 / 某 block type / 某 schema 开关下的路径时，实例的 **stored 值**决定它是否进入该分支。

```bash
awk '/<instance-id>/,/^    \},/' templates/<t>.json           # 读该实例全部存值
grep -A 30 '"<instance-id>"' templates/<t>.json               # 备用读法
```

排除范例：改动只作用于 `layout == 'carousel'` 分支，而 12 个实例中 9 个 stored `layout: "grid"` → 那 9 个剔除。

### Q2：这个实例的元素真的挂了被改的那个钩子吗？

改 CSS 变量 / 颜色类 / utility 时，**只有挂了对应类名的元素才跟随**。完全不受影响的：

- 内容里写死 hex（含 section 内 `<style>` 注入块）
- 内联 `style="color:…"`
- 只挂了非相关类的元素（间距 `py-*`、字号 `fs-*`、对齐 `text-center` 等与本次改动无关的维度）

```bash
grep -rn 'class="[^"]*<hook-class>' sections/ snippets/       # 挂了钩子的 markup
grep -rn "style=\"[^\"]*<property>" sections/ snippets/        # 内联覆盖（免疫）
grep -rn "#[0-9A-Fa-f]\{3,6\}" sections/<module>.liquid        # 写死 hex（免疫）
```

关键机制：重绑 CSS 变量（如配色方案只改 `--color-*` 系列变量、不直接设 `color`）时，**自起的自定义变量名不在重绑范围内**——这正是"免疫元素"的来源。

### Q3：改动前后的计算值真的不同吗？

- **默认态同值 = 零视觉差**：若规范默认值已与目标 spec 值一致，重绑前后同值，只有被商家**自定义过**的配置才会偏移。此时实际影响 = 自定义过的实例数，不是全部实例数。
- **空值 / 缺省的继承行为要查清**：空字符串配置不等于"无效果"。例：空 `color_scheme: ""` 会让 wrapper 类变成匹配不到任何选择器的 `color-`，从而继承 `:root`；而 `:root` 上挂着第一个/default 方案的色 —— 所以"空方案 + 重绑"= 跟随 default 方案，不是"不变"。

```bash
grep -rn "<setting-key>" templates/*.json | grep -v '""'      # 有非空自定义值的实例
```

---

## 步骤 4 — 输出 `ActualAffectedInstances`

**数字 + 清单**。只给数字视为不合格。

```
ActualAffectedInstances: 1

  实际受影响：
  - sections/footer.liquid（全站 footer，无模板实例概念）: separator 颜色跟随所选方案

  已核查排除（16 模板 / 22 实例）：
  - page.about.json / custom_html_a1b2 : 内容为写死 hex 的 <style> 块，不挂 spec 颜色类 → Q2 否
  - page.press.json / custom_html_c3d4 : 方案未自定义，重绑前后同值 → Q3 否
  - ...（逐条列全，不省略）
  - product.default.json / custom_html_x9y8 : "disabled": true → 不计入影响面
```

清单每行格式：`模板 : 实例 id / type : 变化描述或剔除理由`。

---

## 收敛不下来时

`ActualAffectedInstances` 因证据不足无法逐项核实（拿不到模板存值、无法判定分支是否触发、无法确定加载的是哪份文件）时：

- **不得**用"估计不大"降档
- `RiskTier: High`
- `BlockingGaps` 写明**需要用户提供什么**（哪个模板的存值、哪份文件是加载入口、哪个方案被自定义过）
- `ReadyForImplement: No`

半收敛也要如实报：`ActualAffectedInstances: ≥3 (3 confirmed, 5 unresolved — see BlockingGaps)`。

---

## 常见收敛维度速查

| 改动类型 | 主要收敛问题 |
|---|---|
| CSS 变量 / token 值 | 消费方是否挂了对应类；默认态是否同值 |
| 颜色方案接入 | 元素是否用 spec 颜色类；方案是否被自定义；空方案的继承落点 |
| schema 字段改约束（step/min/max） | 只影响**新建**实例与 admin 保存；旧 stored 值不变 |
| schema 字段删除 | 全仓 dangling 引用（`settings.<field>`） |
| 共享 snippet 加分支 | 各调用点传的参数是否命中新分支 |
| token→class 重构 | 全仓 markup 实例是否都已挂等价 utility（见 `shared-propagation.md` §2） |
| JS 基类改动 | 所有子类 + markup 使用点 + pub/sub 事件订阅方 |
| build 产物源改动 | 是否 build；加载的是源编译产物还是另一份同名文件 |
