# MacAutoClean

> An open-source Claude Code skill for safe, automated macOS storage cleanup.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

MacAutoClean turns a typed phrase like _"clean my Mac"_ into a guided, safe, end-to-end disk cleanup. It ships **51 cleanup modules**, **9 smart-advisor heuristics**, and a **`launchd`-based recurring scheduler** — all gated by a hard-coded whitelist so user data is untouchable.

## ✨ Features

| | |
|---|---|
| **51 cleanup modules** | System caches, Xcode, Docker, Homebrew, npm/yarn/pnpm/pip/cargo/go/gradle/maven, browsers, IDEs, Adobe, Slack/Discord/Teams, games, APFS snapshots, and more — parity with [mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py) |
| **🧠 Smart Advisor** | Heuristically surfaces large/stale folders the user might want to delete: local AI models (Ollama / HuggingFace / LM Studio), VM disks (Parallels / VMware / UTM), old iOS backups, abandoned `node_modules` / Python venvs / conda envs, IDE workspace caches, chat-app downloaded media, orphaned `Application Support` folders |
| **⏰ Scheduled auto-run** | Interactive setup for weekly / biweekly / monthly / custom recurring cleanup via macOS `launchd` |
| **🛡️ Hard-coded whitelist** | Every delete passes through `safe_rm` which refuses any path not in `whitelist.txt`. Documents, Desktop, Photos, iCloud, Mail, Messages, Keychain, SSH/GPG/AWS keys, browser cookies, Docker volumes — **all unreachable** |
| **⚡ Native commands first** | Uses `brew cleanup`, `docker prune`, `xcrun simctl`, `tmutil`, `npm cache clean`, `pip cache purge` where available — battle-tested code paths from Apple/tool vendors |
| **No quarantine** | Disk space is freed **immediately**. Reversibility comes from regenerable data: caches rebuild, package managers re-download, Xcode recompiles |

## 🚀 Quick start

```bash
git clone https://github.com/fengyiqicoder/MacAutoClean.git ~/Desktop/MacAutoClean
cd ~/Desktop/MacAutoClean
bash install.sh
```

Then in any Claude Code session say:

> "Clean my Mac" / "全自动清理 Mac" / "Free up disk space"

Claude will walk you through scan → confirm → execute → advisor → optional schedule.

You can also use the CLI directly:

```bash
# Scan only
~/.claude/skills/macautoclean/scripts/autoclean.sh

# Execute (interactive — confirmation gated at >5 GB)
~/.claude/skills/macautoclean/scripts/autoclean.sh --execute

# Smart Advisor
~/.claude/skills/macautoclean/scripts/advisor.sh
~/.claude/skills/macautoclean/scripts/advisor.sh --interactive

# Schedule
~/.claude/skills/macautoclean/scripts/schedule.sh
~/.claude/skills/macautoclean/scripts/schedule.sh --status
~/.claude/skills/macautoclean/scripts/unschedule.sh
```

## 🧱 Architecture

```
MacAutoClean/
├── src/                              # ⭐ everything Claude Code sees (symlinked by install.sh)
│   ├── SKILL.md                      # workflow Claude follows when invoked
│   ├── scripts/                      # lib, scan, execute, autoclean, advisor, schedule, notify
│   ├── modules/                      # 51 cleanup categories (declarative shell files)
│   ├── advisor-heuristics/           # 9 advisor rule packs
│   ├── references/                   # whitelist, safety rules, cleanup catalog
│   └── templates/                    # launchd plist template
├── tests/                            # 5 test files, ~218 assertions
├── docs/                             # architecture, module spec, advisor spec, schedule guide
├── install.sh / uninstall.sh
└── PLAN.md                           # the development plan
```

### Module format (declarative)

Each cleanup category is a shell file in `src/modules/`. Adding a new category = adding one file. Example:

```sh
# src/modules/homebrew.sh
MODULE_NAME="Homebrew"
MODULE_DESCRIPTION="Old formula downloads, outdated bottles, unused dependencies."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")
MODULE_COMMAND="brew cleanup -s && brew autoremove"
MODULE_REQUIRES="brew"
```

See [`docs/module-spec.md`](docs/module-spec.md) for the full schema.

## 🛡️ Safety model

Five independent layers, each sufficient to prevent disaster:

1. **Whitelist hard-gate** — `safe_rm()` refuses any path not in `whitelist.txt`. Enforcement test (`test_whitelist_enforcement.sh`) verifies 33 known-safe paths allowed + 22 sensitive paths rejected.
2. **Native commands first** — Prefer `brew cleanup`, `docker prune` (no `--volumes`), `xcrun simctl`, etc.
3. **Self-regenerating data** — Only touch paths whose contents the originating tool can recreate.
4. **Scan-first mandate** — `autoclean.sh` is read-only by default. `--execute` requires `--yes` or interactive confirmation; gate auto-triggers above 5 GB reclaim.
5. **No `sudo`, no Docker volumes, no external disks** — Hard-coded refusals. `docker volume prune` is grep-banned at module-validation time.

### What's never touched

`~/Documents`, `~/Desktop`, `~/Movies`, `~/Music`, `~/Pictures`, `~/Library/Mobile Documents` (iCloud), `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube`, browser `Cookies` / `Login Data` / `History` / `Bookmarks`, Docker volumes, external/network volumes. See [`src/references/safety-rules.md`](src/references/safety-rules.md).

## 📊 Comparison

| | **MacAutoClean** | mac-cleanup-py | Pearcleaner |
|---|---|---|---|
| Open source | ✅ MIT | ✅ Apache-2.0 | ✅ Apache-2.0 + CC |
| Module coverage | **51** | 48 | App-uninstall focused |
| Smart advisor (stale/AI models/VMs) | ✅ | ❌ | Partial (apps only) |
| Scheduled auto-run | ✅ `launchd` | ❌ | ❌ |
| Whitelist enforcement | ✅ Hard-coded | ⚠️ Trusts module config | ✅ |
| Native command preference | ✅ | ✅ | ✅ |
| Dependencies | **None** (default bash 3.2) | Python ≥ 3.8 | Swift / macOS 13+ |
| Claude Code skill | ✅ Native | ❌ | ❌ |

## 🧪 Tests

```bash
bash tests/test_lib.sh                       # 20 assertions
bash tests/test_whitelist_enforcement.sh     # 33 assertions
bash tests/test_module_files.sh              # 153 assertions (51 modules × 3 checks)
bash tests/test_module_loader.sh             # 6 edge cases
bash tests/test_smoke.sh                     # 6 end-to-end checks
```

## 🗑️ Uninstall

```bash
bash uninstall.sh
```

Removes the symlink and any installed LaunchAgent.

## 🤝 Contributing

PRs welcome. Adding a new cleanup category is a 5-minute job — copy `src/modules/_template.sh`, fill it in, run `bash tests/test_module_files.sh` to validate. See [`docs/module-spec.md`](docs/module-spec.md).

## 📝 License

MIT — see [LICENSE](LICENSE).

## 🙏 Acknowledgements

- [mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py) — module-as-data architecture inspiration
- [Pearcleaner](https://github.com/alienator88/Pearcleaner) — orphan app-leftover detection inspiration
