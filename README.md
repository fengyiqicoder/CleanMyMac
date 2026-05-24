<p align="right">
  <b>English</b> ・ <a href="README.zh-CN.md">简体中文</a>
</p>

# MacAutoClean

> Tell your AI agent **"clean my Mac"** — and it just does it. Safely.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![skills.sh](https://skills.sh/b/fengyiqicoder/MacAutoClean)](https://skills.sh/fengyiqicoder/MacAutoClean)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compliant-blue)](https://agentskills.io)

MacAutoClean is the **AI-native disk cleaner** for macOS. It installs as an [Agent Skill](https://agentskills.io) into any compatible AI coding agent (Claude Code, Cursor, Codex, Copilot, Gemini CLI, OpenCode, Goose, Junie, Amp, …) and turns a casual phrase like *"my disk is full"* into a guided, scan-first, whitelist-gated cleanup. **68 cleanup modules**, **9 smart-advisor heuristics**, optional **weekly auto-run** via `launchd` — all in pure bash 3.2, zero dependencies.

---

## ✨ Why MacAutoClean

|  | Reality |
|---|---|
| 💸 **Free & open** | MIT. No subscription. No telemetry. No upsells. |
| 🤖 **Talk to it naturally** | *"clean my Mac"*, *"硬盘满了"*, *"Xcode is eating my disk"* — built-in trigger phrases in English & 中文. |
| 🛡️ **Five safety layers** | Hard-coded whitelist refuses ~/Documents, iCloud, Keychain, SSH keys, browser cookies, Docker volumes — even if the AI asks. |
| 📊 **Scan-first** | Read-only by default. Confirmation gated at >5 GB reclaim. Bulk delete only after you see the tier breakdown. |
| 🔁 **Native commands** | Uses `brew cleanup`, `docker prune`, `xcrun simctl`, `tmutil` — battle-tested code paths from Apple & tool vendors. |
| ⏰ **Set & forget** | One-time interactive `schedule.sh` installs a `launchd` agent. Weekly safe cleanup, zero further prompts. |

---

## 🚀 Quick start

### Option A — Install via [skills.sh](https://skills.sh) *(recommended)*

One command, works with every Agent-Skills-compliant tool:

```bash
npx skills add fengyiqicoder/MacAutoClean
```

That's it. Now open Claude Code (or Cursor / Codex / Copilot / Gemini CLI / OpenCode / …) and say:

> *"clean my Mac"* · *"free up disk space"* · *"show me a disk map"* · *"清理我的 Mac"* · *"Xcode 占了 100GB"*

The agent reads the skill's `SKILL.md` and walks you through scan → confirm → execute → advise → optional schedule.

### Option B — Clone & install locally

If you want to hack on the modules or read the code first:

```bash
git clone https://github.com/fengyiqicoder/MacAutoClean.git
cd MacAutoClean
bash install.sh
```

`install.sh` symlinks `skills/macautoclean/` → `~/.claude/skills/macautoclean/`. Claude Code picks it up immediately.

### Option C — CLI only (no AI agent)

Every script also runs standalone:

```bash
# See where your disk space is — auto-classified into 3 tiers
~/.claude/skills/macautoclean/scripts/diskmap.sh

# Bulk-delete the safe stuff (caches, build artifacts)
~/.claude/skills/macautoclean/scripts/autoclean.sh --auto-safe --yes

# Walk through the borderline stuff interactively
~/.claude/skills/macautoclean/scripts/autoclean.sh --review

# Surface stale node_modules, old AI models, abandoned VMs, …
~/.claude/skills/macautoclean/scripts/advisor.sh --interactive

# Install weekly auto-cleanup
~/.claude/skills/macautoclean/scripts/schedule.sh
```

---

## 🎯 How it works — the 5-phase workflow

### Phase 1 — Discover (`diskmap.sh`)

Walks your filesystem from any root (default `$HOME`), shows every folder ≥ 2 GB classified into three actionable tiers:

```
✅ AUTO-SAFE — 27.7 GB — delete in bulk, no impact
  4.2 GB │ Xcode DerivedData       │ ~/Library/Developer/Xcode/DerivedData
  2.8 GB │ Docker build cache      │ ~/Library/Containers/com.docker.docker/Data
  2.1 GB │ npm cache               │ ~/.npm
   …

⚠️ NEEDS REVIEW — 12.4 GB — decide per item
  3.1 GB │ Ollama models           │ ~/.ollama/models
  2.6 GB │ iOS device backup       │ ~/Library/Application Support/MobileSync
   …

🔒 NEVER-TOUCH — 155 GB — your data, protected
  120 GB │ iCloud Drive            │ ~/Library/Mobile Documents
   25 GB │ Photos library          │ ~/Pictures/Photos Library.photoslibrary
   …
```

### Phase 2 — Act (`autoclean.sh`)

| Flag | Behavior |
|---|---|
| *(none)* | Scan only — read-only, shows the tier breakdown |
| `--auto-safe --yes` | Bulk-delete the auto-safe tier (typical: 5-30 GB reclaim) |
| `--review` | Per-item interactive walk through the review tier (`[d]elete / [k]eep / [q]uit`) |
| `--all` | Both above |
| `--dry-run` | Show what would happen without touching anything |

### Phase 3 — Drill (`diskmap.sh <path>`)

If diskmap surfaces a large unknown folder (e.g. a new AI tool's cache), drill in:

```bash
diskmap.sh ~/.cursor
diskmap.sh ~/Library/Containers
diskmap.sh / --top 20         # full-disk view (some TCC denials expected)
```

### Phase 4 — Smart Advisor (`advisor.sh`)

Nine specialized heuristics for things diskmap can't classify by path alone:

| Heuristic | What it finds |
|---|---|
| `ai_models` | Ollama / HuggingFace / LM Studio model weights ≥ 1 GB |
| `vm_disks` | Parallels / VMware / UTM / VirtualBox disk images |
| `ios_backups_old` | iPhone/iPad backups older than 6 months |
| `stale_node_modules` | `node_modules` in projects with no commits in 90 days |
| `stale_python_envs` | venv / conda envs unused for 90 days |
| `ide_workspaces` | JetBrains / VS Code / Cursor workspace storage |
| `media_caches` | Chat-app downloaded media (WeChat, Telegram, …) |
| `orphaned_app_support` | `~/Library/Application Support/<app>` for uninstalled apps |
| `large_misc` | Generic fallback: any folder ≥ 5 GB not matched above |

### Phase 5 — Schedule (`schedule.sh`)

Interactive prompt picks cadence (weekly / biweekly / monthly / custom) and scope (safe-only / safe + review-with-defaults). Installs a `launchd` LaunchAgent — no further intervention needed.

```bash
schedule.sh                 # interactive setup
schedule.sh --status        # what's installed
unschedule.sh               # remove
```

---

## 📦 Coverage

### 68 cleanup modules

<details>
<summary><b>Click to expand the full module list</b></summary>

| Category | Modules |
|---|---|
| **System** | system_caches, system_logs, trash, downloads_aged, apfs_snapshots, diagnostic_reports, dns_cache, inactive_memory, group_containers |
| **Xcode** | xcode_deriveddata, xcode_archives, xcode_devicesupport, ios_simulators, ios_backups |
| **Package managers** | brew, npm, yarn, pnpm, bun, pip, poetry, pyenv, uv_cache, nvm_versions, cargo, go_modcache, gradle, m2_maven, composer, gem, nuget, conan, cocoapods |
| **Flutter / Dart** | flutter_pub_cache, flutter_sdk, dart_server_cache, hermes_cache |
| **Containers** | docker (images & build cache — **never volumes**) |
| **Browsers** | chrome, safari, firefox, edge, brave, arc, chromium |
| **IDEs** | jetbrains, android_studio, vscode_caches, cursor_caches, cursor_full, zed_caches, claude_app |
| **Adobe & creative** | adobe |
| **Chat & social** | slack, discord, microsoft_teams, telegram, wechat_data, obsidian, notion_app |
| **AI tools** | ollama_models, huggingface_cache, lm_studio_models |
| **Games** | steam, minecraft, lunarclient |
| **Cloud sync** | dropbox, google_drive |

</details>

### 9 advisor heuristics
See *Phase 4 — Smart Advisor* above.

---

## 🛡️ Safety model — five independent layers

| # | Guarantee | Mechanism |
|---|---|---|
| **1** | **Whitelist hard-gate** | `safe_rm()` refuses any path not whitelisted in `references/whitelist.txt`. Test suite verifies 33 known-safe paths allowed + 22 sensitive paths actively rejected. |
| **2** | **Native commands first** | `brew cleanup -s`, `docker image prune` (never `volume prune`), `xcrun simctl delete unavailable`, `tmutil deletelocalsnapshots` |
| **3** | **Regenerable data only** | Touch only paths the originating tool can recreate (caches, build artifacts, downloaded packages) |
| **4** | **Scan-first mandate** | `autoclean.sh` is read-only by default. `--execute` requires `--yes` or interactive confirmation. >5 GB reclaim auto-triggers a second confirm. |
| **5** | **No sudo, no Docker volumes, no external disks** | Hard-coded refusals. `docker volume prune` is grep-banned at module-validation build time. |

### What's *never* touched

Hard-coded blocklist that cannot be overridden:

`~/Documents` · `~/Desktop` · `~/Movies` · `~/Music` · `~/Pictures` · `~/Library/Mobile Documents` (iCloud) · `~/Library/Mail` · `~/Library/Messages` · `~/Library/Keychains` · `~/.ssh` · `~/.gnupg` · `~/.aws` · `~/.kube` · browser `Cookies` / `Login Data` / `History` / `Bookmarks` / `Preferences` · Docker volumes · external & network volumes

See [`skills/macautoclean/references/safety-rules.md`](skills/macautoclean/references/safety-rules.md).

---

## 🌍 Multi-language

MacAutoClean is **bilingual** — auto-detects from `$LANG`:

- `zh*` → 中文
- anything else → English

Force a specific language any time:

```bash
MAC_AUTOCLEAN_LANG=zh ~/.claude/skills/macautoclean/scripts/diskmap.sh
MAC_AUTOCLEAN_LANG=en ~/.claude/skills/macautoclean/scripts/autoclean.sh
```

This README in other languages:
- 🇺🇸 **English** *(this file)*
- 🇨🇳 [简体中文](README.zh-CN.md)

Want to add another language? Translation dictionary is a single bash file: [`skills/macautoclean/references/i18n.sh`](skills/macautoclean/references/i18n.sh). PRs welcome.

---

## 🧱 Architecture

```
MacAutoClean/
├── skills/
│   └── macautoclean/                 # ⭐ the skill itself — Agent Skills spec
│       ├── SKILL.md                  # what the AI agent reads & follows
│       ├── scripts/                  # lib, scan, execute, diskmap, autoclean, advisor, schedule
│       ├── modules/                  # 68 cleanup categories (declarative shell files)
│       ├── advisor-heuristics/       # 9 advisor rule packs
│       ├── references/               # whitelist, safety rules, i18n dictionary, cleanup catalog
│       └── templates/                # launchd plist template
├── skills.sh.json                    # skills.sh directory-page display config
├── tests/                            # 6 test files, ~270+ assertions
├── docs/                             # architecture, module spec, advisor spec, schedule guide
├── install.sh / uninstall.sh         # local symlink installer
└── PLAN.md                           # development history
```

### Module format — pure data

Each cleanup category is a single declarative shell file. Adding one = 5 minutes.

```bash
# skills/macautoclean/modules/homebrew.sh
MODULE_NAME="Homebrew"
MODULE_NAME_ZH="Homebrew"
MODULE_DESCRIPTION="Outdated bottles, old downloads, unused dependencies"
MODULE_DESCRIPTION_ZH="过期的瓶子文件、旧下载、未使用的依赖"
MODULE_RISK="low"                                       # low → auto-safe tier
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")
MODULE_COMMAND="brew cleanup -s && brew autoremove"     # prefer native command
MODULE_REQUIRES="brew"                                  # skipped if brew not installed
```

Full spec: [`docs/module-spec.md`](docs/module-spec.md) · Advisor spec: [`docs/advisor-spec.md`](docs/advisor-spec.md) · Architecture: [`docs/architecture.md`](docs/architecture.md)

---

## 📊 vs. other Mac cleaners

| | **MacAutoClean** | CleanMyMac | mac-cleanup-py | Pearcleaner |
|---|---|---|---|---|
| Open source | ✅ MIT | ❌ Commercial | ✅ Apache-2.0 | ✅ Apache + CC |
| Free | ✅ | ❌ $40/yr | ✅ | ✅ |
| AI-agent-native | ✅ Any Agent Skills client | ❌ | ❌ | ❌ |
| Bilingual EN/ZH | ✅ | Partial | ❌ | ❌ |
| Module count | **68** | (proprietary) | 48 | App-uninstall focused |
| Smart advisor (AI models / VMs / stale envs) | ✅ | Partial | ❌ | Partial |
| Scheduled auto-run | ✅ `launchd` | ✅ | ❌ | ❌ |
| Whitelist hard-gate | ✅ test-verified | ⚠️ | ⚠️ trusts module config | ✅ |
| Dependencies | **None** (bash 3.2) | macOS app | Python ≥ 3.8 | Swift / macOS 13+ |
| Telemetry | ❌ | ✅ | ❌ | ❌ |

---

## 🧪 Tests

```bash
bash tests/test_lib.sh                       # 20 assertions — helper functions
bash tests/test_whitelist_enforcement.sh     # 33 assertions — safe_rm hard-gate
bash tests/test_module_files.sh              # 204 assertions — every module validated
bash tests/test_i18n.sh                      # 10 assertions — translation dictionary
bash tests/test_smoke.sh                     # 6 end-to-end checks
```

---

## 🤝 Contributing

PRs welcome. Common contributions:

- **New cleanup module** — copy `skills/macautoclean/modules/_template.sh`, fill in fields, run `bash tests/test_module_files.sh`. 5 minutes.
- **New advisor heuristic** — copy `skills/macautoclean/advisor-heuristics/large_misc.sh`, implement `discover()`.
- **New language** — add a `_i18n_<code>()` function in `references/i18n.sh` plus a dispatch case.

See [`docs/contributing.md`](docs/contributing.md).

---

## 🗑️ Uninstall

```bash
bash uninstall.sh
```

Removes the `~/.claude/skills/macautoclean` symlink and any installed LaunchAgent.

---

## 📝 License

MIT — see [LICENSE](LICENSE).

---

## 🙏 Acknowledgements

- **[Agent Skills](https://agentskills.io)** — the open format from Anthropic that makes cross-agent skills possible
- **[mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py)** — module-as-data architecture inspiration
- **[Pearcleaner](https://github.com/alienator88/Pearcleaner)** — orphan app-leftover detection inspiration
- **[skills.sh](https://skills.sh)** — the directory making this skill discoverable

---

<p align="center"><sub>Made for people who care about their disk space <i>and</i> their data.</sub></p>
