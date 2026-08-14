# 发布流程

这套矩阵现在按 **git 仓库 + tag** 发布，仓库：
<https://github.com/chovizzz/plaud-theme-matrix>（**公开**）。

**仓库根就是一个版本的内容**。没有 `-vX.Y.Z` 目录，没有 zip。版本靠 tag 钉。

---

## 这套流程取代了什么

以前的发布方式是**全量快照**：

| 旧做法（已废止） | 现在 |
|---|---|
| 整包复制到 `plaud-shopify-theme-matrix-vX.Y.Z+1/` 新目录，在新目录里改 | 直接在仓库里改，`git commit` |
| 旧版本目录原地冻结，靠目录名区分版本 | `git tag vX.Y.Z`，旧版本靠 tag 取回 |
| 在 `dist/` 根重新打一个 `…vX.Y.Z+1.zip` | **不再打 zip**。GitHub 的 `codeload` 端点按 tag 现生成归档包 |
| 用户拿到 zip，解压，`cd` 进去跑随包分发的 `install-macos-linux.sh` | 用户跑一条 `curl … \| sh`（或 PowerShell 一行），安装器自己按 tag 取包 |
| 每个版本目录里各带一份安装脚本，改安装器要改 N 份 | 安装器只有一份（`install.sh` / `install.ps1`），在仓库根 |
| 「装的是哪一版」只能靠 `version-manifest.md` 里的**声明**，真证据要手工跑 tree diff | `.plaud-installed-ref` 记 tag + commit sha + 时间 + skill 清单；`--check` 自动做逐文件比对 |

**保留下来没变的**：整目录替换（不合并）、旧单 skill `plaud-shopify-theme` 必须先退役、
安装后逐文件清单比对、部分失败非零退出。这些是血泪教训，换发布方式不等于放弃它们。

**历史版本已经灌进 git 历史**：`v0.1.0` / `v0.2.0` / `v0.2.1` / `v0.2.2` / `v0.2.3` 各一个 commit + tag，
内容与当初冻结的目录快照**逐文件字节一致**。
（唯一差异：`plaud-theme-orchestrator/references/` 是个**空目录**，git 不跟踪空目录，所以取回的树里没有它。
不含任何文件，对行为无影响。）

---

## 发布 vX.Y.Z+1

### 1. 改内容

直接在仓库里改。要动的通常有：

- 相关 skill 的 `SKILL.md` / `references/` / `evals/evals.json`
- `plaud-theme-shared/references/version-manifest.md`
- `README.md` 顶部标题的版本号 + 新增一节「vX.Y.Z+1 关键变化」
- `CHANGELOG.md` 顶部新增一节
- `MATRIX.md` / `AGENTS.md`（只有矩阵接线变了才需要）

改完先自查：

```bash
# 还有没有漏掉的旧版本号
grep -rn 'v0\.2\.3' --include='*.md' . | grep -v CHANGELOG.md
```

### 2. 发布前先在隔离环境实装一次

**不要跳过这步。** tag 一旦推上去就是别人 `--ref` 会装到的东西。

```bash
HOME=/tmp/plaud-rehearse ./install.sh --source . --create-missing all
HOME=/tmp/plaud-rehearse ./install.sh --source . --check
```

`--source .` 装的是**工作树**（marker 里会如实标 `UNVERIFIED PROVENANCE`），
所以这一步验的是内容本身能不能装、能不能通过逐文件比对，不是发布链路。

想连发布链路一起演练，用本地仓库当远端：

```bash
git tag vX.Y.Z+1                  # 先在本地打
HOME=/tmp/plaud-rehearse2 ./install.sh --repo "$PWD" --ref vX.Y.Z+1 --create-missing all
HOME=/tmp/plaud-rehearse2 ./install.sh --repo "$PWD" --check
```

`--repo <本地路径>` 走 `git archive` 生成归档包，之后的解包、暂存、比对、写 marker
与线上路径**是同一段代码**。

### 3. 提交 + 打 tag

```bash
git add -A                        # 不要只 add 新文件：版本之间是有文件删除的
git commit -m "vX.Y.Z+1 — <一句话>

<CHANGELOG 首段要点，几条>"
git tag -a vX.Y.Z+1 -m "vX.Y.Z+1"
git push origin main
git push origin vX.Y.Z+1
```

tag 命名**必须**是 `vMAJOR.MINOR.PATCH`。安装器只接受这个形状 —— 别的形状会被
`--ref must be a release tag` 直接拒掉，也不会被「最新 tag」解析选中。

### 4. 在 GitHub 上建一个 Release

指向刚才那个 tag。**这不是可选的装饰**：`--ref` 缺省时安装器先问
`/releases/latest`，取不到才退回去扫 `/tags`。建 Release 等于明确声明「这个 tag 是发布」，
让「最新」由一个发布动作定义，而不是由「版本号最大的 tag」推断出来。

### 5. 用发布链路真装一次并自检

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --check
```

`--check` 必须四个客户端全部 `OK`。特别盯两样：

- **`tree diff: 0/N mismatched`** —— 这才是真证据。marker 里的版本号只是声明。
- **`STALE SKILL`** —— 新版本删掉某个 skill 时必然出现。安装器**不会**替你删；
  按它打印的路径手动 `rm -rf`，然后再跑一次 `--check` 直到干净。

---

## 用户侧回滚

回滚不需要发新版本，把 `--ref` 指回旧 tag 再装一次即可：

```bash
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --ref v0.2.2
curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --check
```

回滚**同样**会留下 `STALE SKILL`（新版新增的 skill 在旧 tag 里不存在），照样手动清。

---

## 几条不要踩的

- **不要改已发布的 tag。** tag 移动了，所有钉着它的人装到的东西会悄悄变，
  而 `--check` 会突然报一堆 `CONTENT DIFFERS` 却说不出为什么。要改就发新版本。
  建议在 GitHub 上给 `v*` 配一条 tag protection ruleset。
- **不要往历史 tag 里补 `install.sh`。** `v0.1.0`–`v0.2.3` 这几个 tag 是当初发布内容的
  忠实记录，里面带的是那时的 `install-macos-linux.sh`。安装器永远从 `main` 取，
  内容才按 `--ref` 取 —— 两者本来就是分开的。
- **不要用 `--clients` 只装一部分。** 四端漂移（两个客户端一个 spec、另两个另一个 spec，
  却处理同一份 `memory/`）是这个项目实际出过的事故。
- **不要再打 zip 往 `dist/` 里放。** 那是旧发布方式的产物，留着只会让人装到冻结的旧包。
- **`main` 不是发布。** 安装器缺省装的是最新 **tag**；解析不出来时它**报错退出**，
  而不是退回去装 `main`。别用「反正 main 是最新的」当理由绕过打 tag。

---

## 安装器本身的验证状态

| | 状态 |
|---|---|
| `install.sh` | **实跑验证过**（macOS）：装最新 tag / 钉 `--ref v0.2.2` / `--check` / `--dry-run`；造陈旧残留文件与陈旧 skill 目录并确认能报出、重装能清；注入恒失败的 `tar` / `git` / `curl` / `mktemp`；`chmod 500` 复现「删除失败却报成功」的历史事故；symlink 目标目录；`HOME` 未设；管道截断。`bash 3.2` / `dash` / `zsh` 三家一致。另外按外部评审（Codex）构造的攻击逐条实测：清空 marker、伪造 `commit:`、把 marker 的 `ref:` 改成分支名、把 in-progress 标记换成目录、把被删掉的 skill 改成不带 `plaud-theme-` 前缀的名字、残留 staging 目录、并发两个不同 ref、swap 中途 `kill -9` —— 全部报出问题并非零退出，没有一条能让 `--check` 说"一致" |
| `install.ps1` | **从未在 Windows 上跑过，连语法解析都没跑过**（开发机没有 PowerShell）。是 `install.sh` 的静态移植。首次在 Windows 上用前先 `-DryRun`，再 `-Check`，别直接实装 |

改安装器之后**至少**要重跑这几条：

```bash
sh -n install.sh && bash -n install.sh && zsh -n install.sh
HOME=/tmp/h1 ./install.sh --repo "$PWD" --ref v0.2.3 --create-missing all
HOME=/tmp/h1 ./install.sh --repo "$PWD" --check
# 注入失败，确认非零退出且不谎报成功
mkdir -p /tmp/badbin && printf '#!/bin/sh\nexit 1\n' > /tmp/badbin/tar && chmod +x /tmp/badbin/tar
HOME=/tmp/h2 PATH=/tmp/badbin:$PATH ./install.sh --repo "$PWD" --ref v0.2.3 --create-missing all; echo "rc=$?  # 必须非 0"
```
