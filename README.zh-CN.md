<p align="right">
  <a href="README.md">English</a> ・ <b>简体中文</b>
</p>

# MacAutoClean

> 对你的 AI 助手说一句**"清理我的 Mac"** —— 它就帮你搞定了。安全地。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![skills.sh](https://skills.sh/b/fengyiqicoder/MacAutoClean)](https://skills.sh/fengyiqicoder/MacAutoClean)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compliant-blue)](https://agentskills.io)

MacAutoClean 是为 macOS 设计的 **AI 原生磁盘清理工具**。它以 [Agent Skill](https://agentskills.io) 格式安装到任何兼容的 AI 编码助手里（Claude Code、Cursor、Codex、Copilot、Gemini CLI、OpenCode、Goose、Junie、Amp 等），把一句随口的 *"硬盘满了"* 转化成有引导、扫描优先、白名单严格守护的清理流程。**68 个清理模块**、**9 个智能顾问启发式规则**，可选的 `launchd` **每周自动清理**——全部用纯 bash 3.2 编写，零依赖。

---

## ✨ 为什么选 MacAutoClean

|  | 实际情况 |
|---|---|
| 💸 **免费 & 开源** | MIT 协议。无订阅，无埋点，无广告。 |
| 🤖 **用自然语言聊** | *"清理 Mac"*、*"硬盘满了"*、*"Xcode 占了好多空间"*——中英文触发词都内置好了。 |
| 🛡️ **五层安全** | 硬编码白名单守护 ~/Documents、iCloud、钥匙串、SSH 密钥、浏览器 Cookie、Docker volume——AI 说什么都没用。 |
| 📊 **先扫描再行动** | 默认只读。回收量 >5 GB 自动二次确认。看完三色清单再决定是否批量删。 |
| 🔁 **优先调原生命令** | 用 `brew cleanup`、`docker prune`、`xcrun simctl`、`tmutil`——Apple 和工具厂商久经考验的清理路径。 |
| ⏰ **设置一次就忘记** | `schedule.sh` 一次交互安装好 `launchd` 任务。每周自动清安全项，再不打扰你。 |

---

## 🚀 快速开始

### 方式 A —— 通过 [skills.sh](https://skills.sh) 安装 *（推荐）*

一行命令，所有支持 Agent Skills 的工具都通用：

```bash
npx skills add fengyiqicoder/MacAutoClean
```

完事。打开 Claude Code（或 Cursor / Codex / Copilot / Gemini CLI / OpenCode 等等），跟它说：

> *"清理我的 Mac"* · *"硬盘满了"* · *"看看磁盘地图"* · *"Xcode 占了 100GB"* · *"free up disk space"*

AI 会读取 skill 的 `SKILL.md` 并带你走完 扫描 → 确认 → 执行 → 建议 → 可选定时 五个阶段。

### 方式 B —— 克隆仓库本地安装

如果你想自己改模块、看看代码再装：

```bash
git clone https://github.com/fengyiqicoder/MacAutoClean.git
cd MacAutoClean
bash install.sh
```

`install.sh` 会把 `skills/macautoclean/` 软链到 `~/.claude/skills/macautoclean/`，Claude Code 立刻能识别。

### 方式 C —— 纯命令行使用（不用 AI）

所有脚本都能独立运行：

```bash
# 看看磁盘空间都去哪了——自动分成三色清单
~/.claude/skills/macautoclean/scripts/diskmap.sh

# 批量删安全项（缓存、构建产物）
~/.claude/skills/macautoclean/scripts/autoclean.sh --auto-safe --yes

# 手动审查临界项
~/.claude/skills/macautoclean/scripts/autoclean.sh --review

# 找出陈旧的 node_modules、旧的 AI 模型、废弃的虚拟机
~/.claude/skills/macautoclean/scripts/advisor.sh --interactive

# 装个每周自动清理
~/.claude/skills/macautoclean/scripts/schedule.sh
```

---

## 🎯 工作原理 —— 五阶段流程

### 阶段 1 —— 探查（`diskmap.sh`）

从任意路径开始（默认 `$HOME`）遍历文件系统，把每个 ≥ 2 GB 的目录归到三类可操作清单：

```
✅ 安全可删 —— 27.7 GB —— 可批量删除，无任何影响
  4.2 GB │ Xcode DerivedData       │ ~/Library/Developer/Xcode/DerivedData
  2.8 GB │ Docker 构建缓存          │ ~/Library/Containers/com.docker.docker/Data
  2.1 GB │ npm 缓存                │ ~/.npm
   …

⚠️ 需要审查 —— 12.4 GB —— 逐项决定
  3.1 GB │ Ollama 模型             │ ~/.ollama/models
  2.6 GB │ iOS 设备备份             │ ~/Library/Application Support/MobileSync
   …

🔒 绝不触碰 —— 155 GB —— 你的数据，受保护
  120 GB │ iCloud 云盘             │ ~/Library/Mobile Documents
   25 GB │ 照片图库                 │ ~/Pictures/Photos Library.photoslibrary
   …
```

### 阶段 2 —— 执行（`autoclean.sh`）

| 参数 | 行为 |
|---|---|
| *（无参数）* | 只扫描——只读，显示三色清单 |
| `--auto-safe --yes` | 批量删除安全可删的（典型回收 5-30 GB） |
| `--review` | 逐项交互审查（`[d] 删 / [k] 留 / [q] 退出`） |
| `--all` | 以上两者 |
| `--dry-run` | 演示模式，不实际删除 |

### 阶段 3 —— 钻入（`diskmap.sh <路径>`）

如果 diskmap 显示一个未分类的大目录（比如新装的某 AI 工具的缓存），可以钻进去看：

```bash
diskmap.sh ~/.cursor
diskmap.sh ~/Library/Containers
diskmap.sh / --top 20         # 全盘视图（部分目录会因 TCC 拒绝）
```

### 阶段 4 —— 智能顾问（`advisor.sh`）

九个专项启发式规则，处理 diskmap 仅凭路径分类不了的情况：

| 启发式 | 找什么 |
|---|---|
| `ai_models` | Ollama / HuggingFace / LM Studio 上 ≥ 1 GB 的模型 |
| `vm_disks` | Parallels / VMware / UTM / VirtualBox 的虚拟机磁盘文件 |
| `ios_backups_old` | 超过 6 个月没用的 iPhone/iPad 备份 |
| `stale_node_modules` | 项目 90 天没提交过、却还留着的 `node_modules` |
| `stale_python_envs` | 90 天没用过的 venv / conda 环境 |
| `ide_workspaces` | JetBrains / VS Code / Cursor 的工作区缓存 |
| `media_caches` | 聊天工具下载的图片视频（微信、Telegram 等） |
| `orphaned_app_support` | `~/Library/Application Support/<app>`，对应的 app 已经卸载 |
| `large_misc` | 通用兜底：以上都不匹配的 ≥ 5 GB 目录 |

### 阶段 5 —— 定时（`schedule.sh`）

交互式问你选周期（每周 / 双周 / 每月 / 自定义）和范围（仅安全项 / 安全+审查项默认动作）。安装一个 `launchd` LaunchAgent——之后再不打扰。

```bash
schedule.sh                 # 交互式安装
schedule.sh --status        # 查看已安装的任务
unschedule.sh               # 卸载
```

---

## 📦 覆盖范围

### 68 个清理模块

<details>
<summary><b>点击展开完整模块列表</b></summary>

| 类别 | 模块 |
|---|---|
| **系统** | system_caches、system_logs、trash、downloads_aged、apfs_snapshots、diagnostic_reports、dns_cache、inactive_memory、group_containers |
| **Xcode** | xcode_deriveddata、xcode_archives、xcode_devicesupport、ios_simulators、ios_backups |
| **包管理器** | brew、npm、yarn、pnpm、bun、pip、poetry、pyenv、uv_cache、nvm_versions、cargo、go_modcache、gradle、m2_maven、composer、gem、nuget、conan、cocoapods |
| **Flutter / Dart** | flutter_pub_cache、flutter_sdk、dart_server_cache、hermes_cache |
| **容器** | docker（镜像 & 构建缓存——**绝不动 volume**） |
| **浏览器** | chrome、safari、firefox、edge、brave、arc、chromium |
| **IDE** | jetbrains、android_studio、vscode_caches、cursor_caches、cursor_full、zed_caches、claude_app |
| **Adobe 创意软件** | adobe |
| **聊天 & 社交** | slack、discord、microsoft_teams、telegram、wechat_data、obsidian、notion_app |
| **AI 工具** | ollama_models、huggingface_cache、lm_studio_models |
| **游戏** | steam、minecraft、lunarclient |
| **云盘** | dropbox、google_drive |

</details>

### 9 个智能顾问启发式
见上文 *阶段 4 —— 智能顾问*。

---

## 🛡️ 安全模型 —— 五层独立防护

| # | 保证 | 机制 |
|---|---|---|
| **1** | **白名单硬门禁** | `safe_rm()` 拒绝任何不在 `references/whitelist.txt` 中的路径。测试用例验证：33 条已知安全路径放行 + 22 条敏感路径主动拒绝。 |
| **2** | **优先用原生命令** | `brew cleanup -s`、`docker image prune`（永远不 `volume prune`）、`xcrun simctl delete unavailable`、`tmutil deletelocalsnapshots` |
| **3** | **只动可再生数据** | 只清除发起方工具能重建的内容（缓存、构建产物、可重下的包） |
| **4** | **扫描优先原则** | `autoclean.sh` 默认只读。`--execute` 需要 `--yes` 或交互确认。回收量 >5 GB 自动触发二次确认。 |
| **5** | **不 sudo、不动 Docker volume、不动外置硬盘** | 硬编码拒绝。`docker volume prune` 在模块校验阶段就被 grep 禁止。 |

### 绝不触碰

硬编码黑名单，无法覆盖：

`~/Documents` · `~/Desktop` · `~/Movies` · `~/Music` · `~/Pictures` · `~/Library/Mobile Documents`（iCloud） · `~/Library/Mail` · `~/Library/Messages` · `~/Library/Keychains` · `~/.ssh` · `~/.gnupg` · `~/.aws` · `~/.kube` · 浏览器 `Cookies` / `Login Data` / `History` / `Bookmarks` / `Preferences` · Docker volumes · 外置 & 网络卷

详见 [`skills/macautoclean/references/safety-rules.md`](skills/macautoclean/references/safety-rules.md)。

---

## 🌍 多语言

MacAutoClean 是**双语**的——自动根据 `$LANG` 检测：

- `zh*` → 中文
- 其它 → English

随时强制指定语言：

```bash
MAC_AUTOCLEAN_LANG=zh ~/.claude/skills/macautoclean/scripts/diskmap.sh
MAC_AUTOCLEAN_LANG=en ~/.claude/skills/macautoclean/scripts/autoclean.sh
```

本 README 的其它语言版本：
- 🇺🇸 [English](README.md)
- 🇨🇳 **简体中文** *（当前页）*

想加入其它语言？翻译字典就是一个 bash 文件：[`skills/macautoclean/references/i18n.sh`](skills/macautoclean/references/i18n.sh)。欢迎 PR。

---

## 🧱 架构

```
MacAutoClean/
├── skills/
│   └── macautoclean/                 # ⭐ skill 本体 —— 遵循 Agent Skills 规范
│       ├── SKILL.md                  # AI 助手读取并执行的工作流
│       ├── scripts/                  # lib、scan、execute、diskmap、autoclean、advisor、schedule
│       ├── modules/                  # 68 个清理类别（声明式 shell 文件）
│       ├── advisor-heuristics/       # 9 个顾问规则包
│       ├── references/               # 白名单、安全规则、i18n 字典、清理目录
│       └── templates/                # launchd plist 模板
├── skills.sh.json                    # skills.sh 目录页展示配置
├── tests/                            # 6 个测试文件，270+ 断言
├── docs/                             # 架构、模块规范、顾问规范、定时指南
├── install.sh / uninstall.sh         # 本地软链安装器
└── PLAN.md                           # 开发历史
```

### 模块格式 —— 纯数据

每个清理类别都是一个声明式 shell 文件。新加一个 = 5 分钟。

```bash
# skills/macautoclean/modules/homebrew.sh
MODULE_NAME="Homebrew"
MODULE_NAME_ZH="Homebrew"
MODULE_DESCRIPTION="Outdated bottles, old downloads, unused dependencies"
MODULE_DESCRIPTION_ZH="过期的瓶子文件、旧下载、未使用的依赖"
MODULE_RISK="low"                                       # low → 安全可删
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")
MODULE_COMMAND="brew cleanup -s && brew autoremove"     # 优先调原生命令
MODULE_REQUIRES="brew"                                  # 没装 brew 就跳过
```

完整规范：[`docs/module-spec.md`](docs/module-spec.md) · 顾问规范：[`docs/advisor-spec.md`](docs/advisor-spec.md) · 架构文档：[`docs/architecture.md`](docs/architecture.md)

---

## 📊 与其它 Mac 清理工具对比

| | **MacAutoClean** | CleanMyMac | mac-cleanup-py | Pearcleaner |
|---|---|---|---|---|
| 开源 | ✅ MIT | ❌ 商业软件 | ✅ Apache-2.0 | ✅ Apache + CC |
| 免费 | ✅ | ❌ ¥298/年 | ✅ | ✅ |
| AI 助手原生支持 | ✅ 任何 Agent Skills 客户端 | ❌ | ❌ | ❌ |
| 中英双语 | ✅ | 部分 | ❌ | ❌ |
| 模块数量 | **68** | （专有） | 48 | 主打 app 卸载 |
| 智能顾问（AI 模型 / 虚拟机 / 陈旧环境） | ✅ | 部分 | ❌ | 部分 |
| 定时自动清理 | ✅ `launchd` | ✅ | ❌ | ❌ |
| 白名单硬门禁 | ✅ 测试验证 | ⚠️ | ⚠️ 依赖模块配置 | ✅ |
| 依赖 | **无**（bash 3.2 即可） | macOS app | Python ≥ 3.8 | Swift / macOS 13+ |
| 数据埋点 | ❌ | ✅ | ❌ | ❌ |

---

## 🧪 测试

```bash
bash tests/test_lib.sh                       # 20 断言 —— 辅助函数
bash tests/test_whitelist_enforcement.sh     # 33 断言 —— safe_rm 硬门禁
bash tests/test_module_files.sh              # 204 断言 —— 每个模块都验证
bash tests/test_i18n.sh                      # 10 断言 —— 翻译字典
bash tests/test_smoke.sh                     # 6 个端到端检查
```

---

## 🤝 贡献

欢迎 PR。常见贡献方式：

- **新增清理模块** —— 复制 `skills/macautoclean/modules/_template.sh`，填好字段，跑 `bash tests/test_module_files.sh`。5 分钟搞定。
- **新增顾问启发式** —— 复制 `skills/macautoclean/advisor-heuristics/large_misc.sh`，实现 `discover()`。
- **新增语言** —— 在 `references/i18n.sh` 里加一个 `_i18n_<code>()` 函数加 dispatch 分支。

详见 [`docs/contributing.md`](docs/contributing.md)。

---

## 🗑️ 卸载

```bash
bash uninstall.sh
```

会移除 `~/.claude/skills/macautoclean` 软链和已安装的 LaunchAgent。

---

## 📝 许可

MIT —— 见 [LICENSE](LICENSE)。

---

## 🙏 致谢

- **[Agent Skills](https://agentskills.io)** —— Anthropic 发起的开放格式，让跨 AI 助手的 skill 成为可能
- **[mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py)** —— 模块即数据架构的灵感来源
- **[Pearcleaner](https://github.com/alienator88/Pearcleaner)** —— 孤儿 app 残留检测的灵感来源
- **[skills.sh](https://skills.sh)** —— 让这个 skill 能被发现的目录站

---

<p align="center"><sub>献给同时在乎磁盘空间<i>和</i>数据安全的人。</sub></p>
