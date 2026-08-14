# QA-C — Path C（UX Spec v1.3 迁移）

覆盖五项（handoff-schema §5 表）：disabled 实例已跳过、空 pre/sub heading 未进字号总览、三层入口选择正确、20 条踩坑规则中适用项、日志时机。

spec 数值一律以 `plaud-theme-shared/references/` 为准，本文件**不复制数值**。

> 本文件把 Path C 的**可执行判定**自带齐全，不依赖旧单 skill 包 `plaud-shopify-theme`（该包在矩阵安装后应被移除）。若上游实现工件引用了本文件未覆盖的迁移条款，向用户要原文，不要凭印象补。

---

## C1. disabled 实例已跳过（零容忍规则 1）

`"disabled": true` 的实例：**不进**字号总览、**不进**修改前后对比表、**不动**其 stored 值（即使 spec 偏离也不改）。

**不要用 grep 做这件事。** `grep -B 1 '"disabled": true'` 假定了 JSON 字段顺序（`type` 恰好在 `disabled` 前一行），拿不到可靠的实例 ID，而且**发现不了 disabled 实例内部 setting 被改**——那正是最需要抓的违规。必须解析 JSON、以实例 ID 为 key 做深比较：

```bash
cd <theme-root>
T=templates/<template>.json

# HEAD 版本与工作树版本都解析（注意剥掉 Shopify 自动加的注释头）
node -e '
const fs=require("fs"), cp=require("child_process");
const strip=(s)=>s.replace(/^\s*\/\*[\s\S]*?\*\//,"");
const f=process.argv[1];
const head=JSON.parse(strip(cp.execSync(`git show HEAD:${f}`,{encoding:"utf8"})));
const cur =JSON.parse(strip(fs.readFileSync(f,"utf8")));

// 结构必须是 { sections: {id: {...}} }；不是就 Blocked，不得当成"没有 disabled 实例"
const S=(j,tag)=>{
  const s=j&&j.sections;
  if(s===null||typeof s!=="object"||Array.isArray(s)){
    console.log(`BLOCKED: ${tag} 的 sections 结构无法识别（旧格式 / section group？）`);
    process.exitCode=2; return {};
  }
  return s;
};
const H=S(head,"HEAD"), C=S(cur,"工作树");
const disIds=(o)=>Object.entries(o).filter(([,v])=>v&&v.disabled===true).map(([k])=>k);

console.log("== HEAD 中的 disabled 实例 ==");
for(const id of disIds(H)) console.log(`  ${id}  type=${H[id].type}`);
console.log("== 工作树中的 disabled 实例 ==");
for(const id of disIds(C)) console.log(`  ${id}  type=${C[id].type}`);

// 取两侧 disabled ID 的并集 —— 只遍历 HEAD 侧会漏掉「本轮才变成 disabled」和「本轮新增的 disabled 实例」
console.log("== 违规（应为空） ==");
for(const id of new Set([...disIds(H), ...disIds(C)])){
  const hv=H[id], cv=C[id];
  if(!hv){ console.log(`  NEW-DISABLED ${id} (type=${cv.type}) —— 本轮新增的 disabled 实例，确认是否有意`); continue; }
  if(!cv){ console.log(`  DELETED ${id} (type=${hv.type}) —— disabled 实例被删除`); continue; }
  if(hv.disabled!==true && cv.disabled===true)
    console.log(`  NEWLY-DISABLED ${id} (type=${cv.type}) —— 本轮由 active 改为 disabled`);
  if(JSON.stringify(hv)!==JSON.stringify(cv))
    console.log(`  CHANGED ${id} (type=${(cv||hv).type}) —— stored 值被改动`);
}
' "$T"
```

判定：

- 第三段有任何输出（`CHANGED` / `DELETED` / `NEWLY-DISABLED` / `NEW-DISABLED`）→ `Failed`，除非用户明确要求该变更。`CHANGED` 覆盖"只改 disabled 实例内部 setting、没动 `disabled` 标志"这种 grep 抓不到的情形。
- 迁移报告 / 字号总览里出现了第二段列出的任一实例 → `Failed`。
- 未产出字号总览且未动模板 JSON → `NotApplicable` + 理由。
- **必须给出 disabled 清单原文**（实例 ID + type，即脚本第二段输出）。只说"已跳过 disabled" → `Blocked`。
- 脚本输出 `BLOCKED:`（`sections` 结构不认识，如旧版格式或 section group）→ `Blocked`，**不得**按"没有 disabled 实例"通过。

## C2. 空 pre / sub heading 未进字号总览（零容忍规则 2）

字号总览只列**实际渲染**的元素。**"实际不渲染"不等于"stored 值是空字符串"**——richtext 字段常见的 `<p></p>`、`<p><br></p>`、`&nbsp;`、`null` 一样什么都不显示，只判 `=== ""` 会漏。

同样**不能用 `awk` 截取实例对象**——JSON 里嵌套的 `blocks` / `settings` 出现同缩进的 `},` 时会提前截断，漏掉后半段字段。用 JSON 遍历 + 统一的"视觉为空"判定：

```bash
cd <theme-root>
node -e '
const fs=require("fs");
const strip=(s)=>s.replace(/^\s*\/\*[\s\S]*?\*\//,"");
const j=JSON.parse(strip(fs.readFileSync(process.argv[1],"utf8")));
const KEYS=["pre_heading","subheading","sub_heading","heading","title"];

// 视觉为空：null / undefined / 纯空白 / 只有 HTML 标签与空白实体
const isVisuallyEmpty=(v)=>{
  if(v===null||v===undefined) return true;
  if(typeof v!=="string") return false;
  const t=v.replace(/<[^>]*>/g,"")            // 去标签（含 <br>、<p>）
           .replace(/&nbsp;|&#160;|&#xa0;/gi," ")
           .replace(/ |​|﻿/g," ")
           .trim();
  return t==="";
};

const scan=(label,type,settings)=>{
  const st=settings||{};
  const empty=KEYS.filter(k=>k in st && isVisuallyEmpty(st[k]));
  if(empty.length) console.log(`${label} (type=${type}) 视觉空字段: ${empty.join(", ")}`);
};

for(const [id,sec] of Object.entries(j.sections||{})){
  if(!sec) continue;
  if(sec.disabled===true) continue;                       // disabled 本来就不进总览
  scan(id, sec.type, sec.settings);
  for(const [bid,b] of Object.entries(sec.blocks||{})){
    if(!b) continue;
    scan(`${id}/${bid}`, b.type, b.settings);
  }
}
' templates/<template>.json
```

输出的每一条都**不得**在字号总览里出现对应字号行。总览里出现空值字段的行 → `Failed`。脚本无输出但总览里列了 pre/sub heading → 逐条核对 stored 值确实非空，把值贴进证据。

## C3. 三层入口选择正确

三层：**模板存值（JSON 实例值） > schema 配置 > 模块代码**，优先级即"当改动已获授权时选哪一层落地"。

> **v0.2.1：偏离顺序本身不再直接判 `Failed`。** 三层入口是 🟠 **EvidenceBased**（`handoff-schema.md` §8.1 第 8 条）：偏离时用**既有的 `OptionsConsidered`** 说明上层入口为何不适用并引用 `AssessmentRef`，QA 按 `qa-global.md` §11 核证据是否齐 —— 齐即 `Passed`，缺则 `Blocked`，证据反证上层本可用才 `Failed`。**下表每一层自身的通过条件不变**（模板存值仍需授权证据，缺失仍 `Failed`）。

| 实际落地层 | 通过条件 |
|---|---|
| 模板存值 | ① blast radius 小、是本轮目标模板的针对性优化；**且** ② `templates/*.json` 默认只读，必须有**用户明确授权**或有文档化的 stored-值阻断例外。授权证据缺失 → `Failed` |
| schema | 模块自带约束（`step` / `min` / `max` / `default`）阻挡 spec 值时才用；须评估向后兼容（通常"拉高上限"安全、"收紧步长"危险）。**option values**：删除或修改既有 `value` → 🔴 `Failed`（存量实例存值静默失效）；**纯新增 option 允许**，但须在 `OptionsConsidered` 给出新 value 的 Liquid 端映射、schema 保存验证与旧存值兼容结论（`handoff-schema.md` §8.1 第 9 条） |
| 模块代码 | 偏离由模块自身实现导致、需根本性修复；影响该模块所有现存实例，须有 blast radius 数据支撑 |

取证：

```bash
grep -lr '"type": "<module-name>"' <theme-root>/templates/ | wc -l   # 模板用量
git diff HEAD --name-only                                            # 实际落在哪一层
git diff HEAD -- <theme-root>/sections/<x>.liquid | grep -n '"options"'  # 是否动了 option values
```

判定：

- 动了 `templates/*.json` 而无用户授权引用 → `Failed`。
- 改了 schema `options` 的 value → `Failed`（硬规则）。
- 模板用量与所选入口的风险档不匹配（如用量 1 却改模块代码影响全站、或用量 50+ 却逐模板改存值）→ `Failed`，说明应选哪层。

## C4. 20 条踩坑规则中的适用项

踩坑库来自旧单 skill 的 `ux-spec-v13-migration.md` §4.1–§4.20，**现已收敛进 `plaud-theme-ux-migration/references/pitfalls-css.md` / `pitfalls-components.md` / `pitfalls-migration.md` / `pitfalls-shared-scope.md`**（下表编号沿用原 §4.x 以便对照）。**只查本次改动实际命中的条目**，逐条给结论；未命中的写 `NotApplicable` 并说明为什么不命中（不必逐条罗列 20 项，但要说明筛选依据）。

先做**触发面筛选**，再逐条核：

| # | 触发条件（命中才查） | 核查要点 |
|---|---|---|
| 4.1 | 改了字号 / 颜色 / 间距 | 优先 utility class > token > 字面量 |
| 4.2 | 新增 hex | 新 hex 必须**大写** |
| 4.3 | 新增注释 | 注释纪律（不留过程性注释） |
| 4.4 | 改了 schema 约束 | 历史 stored 值仍合法（向后兼容） |
| 4.5 | 用了新 utility | utility 已在 `design-utilities.scss` 并已 build 进 `design-system.liquid`（复用前先 grep 确认） |
| 4.6 / 4.6.1 | 接入 / 改动 color scheme | 免疫元素处理正确；给共享 section 接 scheme 前先算真实影响（理论 vs 实际） |
| 4.7 | 动了 swiper 导航 / 分页 | 走统一控件，未自绘 |
| 4.8 / 4.8.1–3 | Slideshow 迁移 | 模板无预置 `new_slide` 时**新建**（不能只翻 disabled）；必开 `new_banner_enbale`；验收期保留两张 slide + 临时导航 |
| 4.9 | 决定字号/颜色写哪一层 | 结构可控元素挂 critical 工具类；动态内容（metaobject / 富文本）保留 token 是允许例外 |
| 4.10 | 在固定容器内加类 | 不重复容器已有的工具类 |
| 4.11 | 改了 `<source media>` | 断点值与主题基准一致（与 CSS 断点同源） |
| 4.12 / 4.12.1 | Multi Content → Multi Content-WW | 结构性重建，非改字段；WW 文本/标题块字号与上色对齐 |
| 4.13 | 动了模块区头 | `cs-section-header` 的间距与对齐通用坑 |
| 4.14 | 对齐第三方插件文字样式 | 主题层覆盖，**不改插件生成文件** |
| 4.15 | token → class 重构 | **全实例覆盖**（高频回归源）：grep 出全部实例逐个确认已补类 |
| 4.16 | 用了 `.grid grid-cols` | 禁止叠 `gap-sp-*` 类 |
| 4.17 | 用了 `my-0` | 会盖掉 `mar-b-*` |
| 4.18 | `gap-flex` 父级里有可选子块 | 有内容才渲染，否则出空隙 |
| 4.19 | 改了 product-item | 菜单上下文判断用 `card_bg == 'white'` |
| 4.20 | 改了 build 产物 | **生成文件勿手改** — `git diff` 命中 build 输出目录 → `Failed` |

另外两条与 12 条约定相关的必查（触发即查）：

- 加了 `enable_color_scheme` → 默认值按模块历史决定（历史有非空 stored 值 → `true`，否则 `false`）；checkbox **不加 info**。
- 模块 CSS 硬锁 spec token → 必须有 `:not(.use-color-scheme)` 守卫，否则 scheme 开关失效。

### dangling 引用扫描（删了东西就必须跑）

删过 schema 字段 / CSS 变量 / `data-*` 属性 → 全仓 grep 残留：

```bash
grep -rn "var(--<被删变量>)" <theme-root>/assets/
grep -rn "settings.<被删字段>" <theme-root>/{sections,snippets,layout}/
grep -rn "dataset.<被删属性>\|data-<被删属性>" <theme-root>/{assets,sections,snippets}/
```

任一命中 → `Failed`。

### JSON 语法校验（改过 `templates/*.json` 就必跑）

```bash
node -e "const fs=require('fs');const s=fs.readFileSync('<template>.json','utf8').replace(/^\s*\/\*[\s\S]*?\*\//,'');JSON.parse(s);console.log('JSON OK')"
```

> `.replace(/^\s*\/\*[\s\S]*?\*\//, '')` 是必需的——Shopify 会在模板 JSON 顶部自动加注释头，不剥掉会误报语法错误。

### build 产物

改过 `shopify-common/src` → 必须 `cd shopify-common && npm run build`，且 build 输出已包含在 `ModifiedFiles`。未 build → `Failed`（同时会让 `ThemeCheck` 失真，见 `theme-check-gate.md` §1）。

## C5. 日志时机

> **未获用户验收，不得写迁移日志内容。**

- 「UX 差异日志内容」= 字号总览行、修改前后对比表行、影响等级描述。这些在用户明说"验收 ok / 加入日志"前**一律不得写入**。
- **例外**：「进行中 / Owners」等**协调元数据**可以写（多人并行时的认领状态），不受验收门限制。

取证：

```bash
git diff HEAD -- <日志文件路径>
git status --porcelain | grep -i 'migration\|ux-spec'
```

判定：

| 情形 | 判定 |
|---|---|
| 未验收但 diff 含字号总览 / 对比表 / 影响等级 | `Failed` |
| 未验收，diff 只含 Owners / 进行中标记 | `Passed` |
| 已有用户验收原话，且日志内容符合规范 | `Passed`（顺带核：模块名用后台显示名、措辞业务可读无 class/path、影响等级带量化、模块按渲染顺序编号、disabled 实例未登记、空 pre/sub heading 未列） |
| 本次未触碰日志文件 | `NotApplicable` |

注意 QA 自身也受此约束：**本 skill 不写日志、不代替用户验收。** `ReadyForDelivery: Yes` 只表示"验证通过"，不等于"用户已验收"——写日志的触发条件是用户的明确验收，不是 QA 结论。
