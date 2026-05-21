# MacAutoClean — Open-Source Skill Development Plan (v2)

> **Identity:** This plan is written from the perspective of a **skill developer** maintaining the open-source `macautoclean` skill repository at `/Users/fengyq/Desktop/MacAutoClean/`. All implementation work modifies source files in this repo. Users install the skill by cloning the repo and running `install.sh`, which symlinks `src/` into `~/.claude/skills/macautoclean`. We never write directly into the user's Claude skill directory.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## 🎯 Goal

Build a **distributable, open-source Claude Code skill** that, when invoked, performs an immediate Mac disk cleanup with breadth-of-coverage parity to industry leaders, plus two differentiating features:

1. **Smart Advisor** — beyond fixed categories, heuristically surface large/stale folders the user *might want to* delete (local AI models, abandoned project deps, old VM disks, iOS backups, IDE workspace caches, etc.), with a clear explanation of *what each is*, *where it lives*, and a recommendation (`Safe` / `Review` / `Keep`).
2. **Scheduled Auto-Run** — guide the user through setting up automated recurring cleanup (weekly / biweekly / monthly / custom) via macOS-native `launchd`.

## 🧬 Architecture & Inspiration

| Inspiration | What we borrow |
|---|---|
| **[mac-cleanup-py](https://github.com/mac-cleanup/mac-cleanup-py)** (2.4k★, Apache-2.0, actively maintained) | **Module-as-data architecture** — each cleanup category is a declarative config file in `src/modules/`, parsed by a single generic engine. 48-module coverage parity. |
| **[Pearcleaner](https://github.com/alienator88/Pearcleaner)** (13.2k★, Apache-2.0) | **App-leftover detection heuristics** — used by the Smart Advisor to find orphaned support files for uninstalled apps. |

**Key architectural decisions:**

- **No quarantine.** Direct delete after whitelist + native-command guards. The reversibility comes from the data itself: caches regenerate, brew re-downloads, Xcode recompiles. `/tmp` is on the same APFS volume so a hold-area would not free space.
- **Module format:** plain shell-sourceable `.sh` files (not TOML) — zero parsing dependencies on default macOS bash 3.2. Each module declares: name, description, paths, risk, optional native command, optional age-gate. Adding a new category = adding one `.sh` file.
- **Skill source is `src/`, not the whole repo.** Tests, docs, and dev tooling live outside `src/` so they never load into Claude Code's context.
- **No daemons, no Python, no Node.** Pure bash + native macOS tools (`launchctl`, `osascript`, `mdfind`, `tmutil`, `xcrun`, `du`, `find`, `stat`).

## 📁 Repository Layout

```
/Users/fengyq/Desktop/MacAutoClean/                # open-source repo root
├── README.md                                      # user-facing install/usage
├── LICENSE                                        # MIT
├── PLAN.md                                        # this document
├── CHANGELOG.md
├── install.sh                                     # ln -s src → ~/.claude/skills/macautoclean
├── uninstall.sh                                   # rm symlink + unschedule launchd
│
├── src/                                           # ⭐ the only thing Claude Code sees
│   ├── SKILL.md                                   # skill entry — workflow Claude follows
│   ├── scripts/
│   │   ├── lib.sh                                 # shared helpers (logging, whitelist, safe_rm, JSON emit, module loader)
│   │   ├── scan.sh                                # read-only: enumerate modules + advisor candidates → JSON report
│   │   ├── execute.sh                             # apply module deletions; called by autoclean.sh
│   │   ├── autoclean.sh                           # master orchestrator
│   │   ├── advisor.sh                             # ⭐ Smart Advisor — heuristic stale/large folder scan
│   │   ├── schedule.sh                            # ⭐ Schedule installer (interactive: weekly/biweekly/monthly/custom)
│   │   ├── unschedule.sh                          # remove launchd agent
│   │   └── notify.sh                              # osascript notification wrapper
│   ├── modules/                                   # ⭐ 48 cleanup categories (mac-cleanup-py parity)
│   │   ├── _template.sh                           # blank module skeleton
│   │   ├── system_caches.sh
│   │   ├── system_logs.sh
│   │   ├── trash.sh
│   │   ├── downloads_aged.sh
│   │   ├── apfs_snapshots.sh
│   │   ├── diagnostic_reports.sh
│   │   ├── xcode_deriveddata.sh
│   │   ├── xcode_archives.sh
│   │   ├── xcode_devicesupport.sh
│   │   ├── ios_simulators.sh
│   │   ├── ios_backups.sh
│   │   ├── brew.sh
│   │   ├── docker.sh
│   │   ├── npm.sh
│   │   ├── yarn.sh
│   │   ├── pnpm.sh
│   │   ├── bun.sh
│   │   ├── pip.sh
│   │   ├── poetry.sh
│   │   ├── pyenv.sh
│   │   ├── cargo.sh
│   │   ├── go_modcache.sh
│   │   ├── gradle.sh
│   │   ├── m2_maven.sh
│   │   ├── composer.sh
│   │   ├── nuget.sh
│   │   ├── conan.sh
│   │   ├── gem.sh
│   │   ├── jetbrains.sh
│   │   ├── android_studio.sh
│   │   ├── vscode_caches.sh
│   │   ├── chrome.sh
│   │   ├── safari.sh
│   │   ├── firefox.sh
│   │   ├── edge.sh
│   │   ├── brave.sh
│   │   ├── arc.sh
│   │   ├── chromium.sh
│   │   ├── adobe.sh
│   │   ├── slack.sh
│   │   ├── discord.sh
│   │   ├── microsoft_teams.sh
│   │   ├── telegram.sh
│   │   ├── obsidian.sh
│   │   ├── dropbox.sh
│   │   ├── google_drive.sh
│   │   ├── steam.sh
│   │   ├── minecraft.sh
│   │   ├── lunarclient.sh
│   │   ├── dns_cache.sh
│   │   └── inactive_memory.sh
│   ├── advisor-heuristics/                        # ⭐ Smart Advisor rule packs
│   │   ├── ai_models.sh                           # Ollama, HuggingFace, LM Studio, llama.cpp models
│   │   ├── vm_disks.sh                            # Parallels, VMware, UTM, VirtualBox
│   │   ├── ios_backups_old.sh                     # iOS device backups not touched in 6m+
│   │   ├── stale_node_modules.sh                  # node_modules in projects not opened in 90d+
│   │   ├── stale_python_envs.sh                   # venvs / conda envs not used in 90d+
│   │   ├── ide_workspaces.sh                      # VS Code workspaceStorage, JetBrains caches per project
│   │   ├── media_caches.sh                        # Slack/Discord/Teams downloaded media
│   │   ├── orphaned_app_support.sh                # Pearcleaner-style: support files for uninstalled apps
│   │   └── large_misc.sh                          # generic >5GB folders touched <90d
│   ├── references/
│   │   ├── whitelist.txt                          # safe_rm allow-list (machine-readable)
│   │   ├── whitelist.md                           # whitelist explained
│   │   ├── safety-rules.md                        # invariants every script must enforce
│   │   └── cleanup-catalog.md                     # one row per module: name, paths, reclaim, risk
│   └── templates/
│       └── com.macautoclean.plist.tmpl            # launchd LaunchAgent template
│
├── tests/                                         # not part of installed skill
│   ├── test_lib.sh
│   ├── test_whitelist_enforcement.sh
│   ├── test_module_loader.sh
│   ├── test_module_files.sh                       # validates every modules/*.sh has required fields
│   ├── test_advisor.sh
│   ├── test_schedule.sh
│   └── test_smoke.sh
│
└── docs/
    ├── architecture.md
    ├── module-spec.md                             # how to author a modules/*.sh file
    ├── advisor-spec.md                            # how Smart Advisor decides Safe/Review/Keep
    ├── schedule-guide.md                          # launchd, permissions, troubleshooting
    └── contributing.md
```

## 🧩 Module File Spec (the core abstraction)

Every cleanup category is a shell file sourced by `lib.sh::load_module`. Required fields:

```bash
# src/modules/xcode_deriveddata.sh
MODULE_NAME="Xcode Derived Data"
MODULE_DESCRIPTION="Compiled intermediates and indexes from Xcode builds. Recreated on next build (first build will be slower)."
MODULE_RISK="low"                                   # low | medium | high
MODULE_CATEGORY="dev"                               # dev | browser | system | social | game | media
MODULE_PATHS=(
  "$HOME/Library/Developer/Xcode/DerivedData"
)
MODULE_COMMAND=""                                   # optional: native cmd to run instead of rm
MODULE_AGE_DAYS=0                                   # optional: only touch entries older than N days (0 = no filter)
MODULE_REQUIRES="xcode"                             # optional: skip if this binary not present
MODULE_NOTES=""                                     # optional human note shown in scan report
```

For modules backed by official tools, `MODULE_COMMAND` takes precedence:

```bash
# src/modules/brew.sh
MODULE_NAME="Homebrew"
MODULE_DESCRIPTION="Old downloads, outdated formula caches, and unused dependencies."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")      # used only for scan sizing
MODULE_COMMAND="brew cleanup -s && brew autoremove"
MODULE_REQUIRES="brew"
```

Scan engine uses `MODULE_PATHS` to size; execute engine prefers `MODULE_COMMAND` when present, falls back to `safe_rm` on `MODULE_PATHS`.

## 🔍 Advisor Heuristic Spec

Advisor heuristics extend modules with **discovery** logic — they don't have hardcoded paths, they go look. Each heuristic implements:

```bash
# src/advisor-heuristics/ai_models.sh
HEURISTIC_NAME="Local AI Models"
HEURISTIC_DESCRIPTION="Downloaded large language models from Ollama, HuggingFace, LM Studio, etc."

# Function: print one TSV record per candidate.
# Columns: name<TAB>path<TAB>bytes<TAB>last_access_iso<TAB>recommendation<TAB>explanation
discover() {
  # Ollama models
  if [[ -d "$HOME/.ollama/models" ]]; then
    for model_dir in "$HOME/.ollama/models/manifests"/*/*/*; do
      [[ -d "$model_dir" ]] || continue
      local name="${model_dir##*/manifests/}"
      local bytes; bytes=$(path_bytes "$model_dir")
      local last; last=$(stat -f '%Sm' -t '%Y-%m-%d' "$model_dir")
      local days_old; days_old=$(( ( $(date +%s) - $(stat -f '%m' "$model_dir") ) / 86400 ))
      local rec="Review"
      [[ $days_old -gt 90 && $bytes -gt $((5*1024**3)) ]] && rec="Safe (large + unused 90d+)"
      [[ $days_old -lt 30 ]] && rec="Keep (recently used)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "Ollama model: $name" "$model_dir" "$bytes" "$last" "$rec" \
        "Local LLM weights. Re-pull with: ollama pull $name"
    done
  fi
  # HuggingFace hub cache
  if [[ -d "$HOME/.cache/huggingface/hub" ]]; then
    for model_dir in "$HOME/.cache/huggingface/hub"/models--*; do
      # … same shape
    done
  fi
  # LM Studio, llama.cpp, etc.
}
```

The advisor engine collects all TSV rows, sorts by `bytes` desc, presents to the user as an interactive table. User picks per-row: `[d]elete / [k]eep / [s]kip / [q]uit`.

## 📅 Schedule Feature Spec

`schedule.sh` is interactive:

```
$ macautoclean schedule
How often should MacAutoClean run?
  1) Weekly (Sunday 3 AM)
  2) Every 2 weeks (1st & 15th, 3 AM)
  3) Monthly (1st, 3 AM)
  4) Custom (provide day-of-week + hour)
> 1

What scope on each run?
  1) Auto-clean safe categories only (caches, logs, trash) — silent
  2) Auto-clean safe categories + send notification with reclaim
  3) Notify only — open Claude when ready                  [recommended]
> 2

Installing LaunchAgent ~/Library/LaunchAgents/com.macautoclean.plist …
Loaded. Next run: Sunday 2026-05-24 03:00.

Tip: run `macautoclean schedule --status` to inspect; `macautoclean unschedule` to remove.
```

Template `templates/com.macautoclean.plist.tmpl`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.macautoclean</string>
  <key>ProgramArguments</key>
  <array>
    <string>{{SRC_DIR}}/scripts/autoclean.sh</string>
    <string>--execute</string>
    <string>--scope</string><string>{{SCOPE}}</string>
    <string>--notify</string><string>{{NOTIFY_MODE}}</string>
  </array>
  <key>StartCalendarInterval</key>
  {{CALENDAR_DICT_OR_ARRAY}}
  <key>StandardOutPath</key><string>{{LOG_PATH}}</string>
  <key>StandardErrorPath</key><string>{{LOG_PATH}}</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
```

`schedule.sh` substitutes placeholders and calls:
```bash
launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/com.macautoclean.plist"
```

## 🛡️ Safety Model (no quarantine)

Five layers, each independently sufficient to prevent disaster:

| Layer | Implementation |
|---|---|
| 1. **Whitelist hard-gate** | `safe_rm` in `lib.sh` checks `references/whitelist.txt` — any path not prefix-matched is **rejected with error**, no exceptions. |
| 2. **Prefer native tools** | `brew cleanup`, `docker prune` (no `--volumes`), `xcrun simctl delete unavailable`, `tmutil deletelocalsnapshots`, `npm cache clean --force`, `pip3 cache purge`, `go clean -modcache`. These are designed for the job. |
| 3. **Self-regenerating data** | We only touch paths whose data is rebuildable by the tool that created it. Stated explicitly per-module in `MODULE_DESCRIPTION`. |
| 4. **Scan-first mandate** | `autoclean.sh` without `--execute` is read-only. `--execute` without `--yes` requires interactive confirmation. `SKILL.md` instructs Claude to always show the scan and get conversational consent. |
| 5. **No sudo, no volumes, no external disks** | Hard-coded refusals. `docker volume prune` is grep-banned in CI. |

## 🗺️ Task Decomposition

Each task ends with: lint (`shellcheck`), all tests pass, commit.

### Task 1 — Repo scaffolding & install/uninstall

- [ ] **Step 1**: create directory tree (per "Repository Layout" above).
- [ ] **Step 2**: write `LICENSE` (MIT, 2026, Yiqi Feng).
- [ ] **Step 3**: write `install.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  SRC="$(cd "$(dirname "$0")/src" && pwd)"
  DST="$HOME/.claude/skills/macautoclean"
  mkdir -p "$HOME/.claude/skills"
  [[ -L "$DST" ]] && rm "$DST"
  [[ -e "$DST" ]] && { echo "ERROR: $DST exists and is not a symlink" >&2; exit 1; }
  ln -s "$SRC" "$DST"
  echo "✓ Installed: $DST → $SRC"
  ```
- [ ] **Step 4**: write `uninstall.sh` (removes symlink + calls `src/scripts/unschedule.sh`).
- [ ] **Step 5**: stub `src/SKILL.md` with frontmatter only (full content in Task 11).
- [ ] **Step 6**: `git init` + initial commit.

### Task 2 — `lib.sh` core + tests (TDD)

- [ ] **Step 1**: write `tests/test_lib.sh` asserting `format_bytes`, `is_whitelisted`, `safe_rm` (deletes whitelisted, refuses non-whitelisted), `load_module` (sources a module, sets `MODULE_*` vars), `path_bytes`. Run — expect FAIL.
- [ ] **Step 2**: implement `src/scripts/lib.sh` with:
  - `log` / `warn` / `err` (stderr + log file)
  - `path_bytes` (uses `du -sk`)
  - `format_bytes`
  - `is_whitelisted` (prefix-match against `references/whitelist.txt`, expanding `~`)
  - `safe_rm` (whitelist check → `/bin/rm -rf`; honors `DRY_RUN=1`)
  - `load_module <path>` (sources file in a subshell, validates required fields, exports `MODULE_*`)
  - `emit_report` (one-line JSON to stdout)
- [ ] **Step 3**: re-run tests — expect PASS. `shellcheck` clean. Commit.

### Task 3 — Whitelist + safety rules + enforcement test

- [ ] **Step 1**: write `tests/test_whitelist_enforcement.sh` asserting must-allow paths (caches, dev caches, Trash, Downloads) and must-reject paths (`~/Documents`, `~/Desktop`, `~/Pictures`, `~/Library/Mobile Documents`, `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `/System`, `/etc`).
- [ ] **Step 2**: write `src/references/whitelist.txt` (prefix list).
- [ ] **Step 3**: write `src/references/safety-rules.md` (never-touch list + invariants).
- [ ] **Step 4**: write `src/references/whitelist.md` (human explanation).
- [ ] **Step 5**: enforcement test passes. Commit.

### Task 4 — Module engine + module spec doc

- [ ] **Step 1**: write `src/modules/_template.sh` with all fields commented.
- [ ] **Step 2**: write `docs/module-spec.md` defining the schema.
- [ ] **Step 3**: write `tests/test_module_files.sh` that:
  - Loops every `src/modules/*.sh`
  - Sources it in subshell
  - Asserts `MODULE_NAME`, `MODULE_DESCRIPTION`, `MODULE_PATHS`, `MODULE_RISK` are set
  - Asserts every path in `MODULE_PATHS` passes `is_whitelisted` (catches whitelist drift)
  - Asserts `MODULE_COMMAND` (if set) doesn't contain `docker volume prune` or `rm -rf /` or `sudo`
- [ ] **Step 4**: this test will run after each new module is added (Task 6). Commit spec + template.

### Task 5 — Scan engine

- [ ] **Step 1**: write `src/scripts/scan.sh` — discovers `src/modules/*.sh`, loads each, sizes `MODULE_PATHS` via `path_bytes`, emits one JSON object per module. Skips modules whose `MODULE_REQUIRES` binary isn't present.
- [ ] **Step 2**: smoke test: `src/scripts/scan.sh | jq -s '.' >/dev/null`. Commit.

### Task 6 — Author 48 modules (in 6 sub-batches)

Each sub-batch: write the modules, ensure `test_module_files.sh` passes, commit.

- [ ] **6a**: system core (5) — `system_caches`, `system_logs`, `trash`, `downloads_aged` (with `MODULE_AGE_DAYS=90`), `diagnostic_reports`, `apfs_snapshots`
- [ ] **6b**: apple-dev (5) — `xcode_deriveddata`, `xcode_archives`, `xcode_devicesupport`, `ios_simulators` (cmd: `xcrun simctl delete unavailable`), `ios_backups`
- [ ] **6c**: package managers (12) — `brew`, `npm`, `yarn`, `pnpm`, `bun`, `pip`, `poetry`, `pyenv`, `cargo`, `go_modcache`, `gradle`, `m2_maven`, `composer`, `nuget`, `conan`, `gem`
- [ ] **6d**: IDEs + dev infra (5) — `jetbrains`, `android_studio`, `vscode_caches`, `docker` (cmd: `docker container prune -f && docker image prune -f && docker builder prune -f && docker network prune -f`), `adobe`
- [ ] **6e**: browsers (7) — `chrome`, `safari`, `firefox`, `edge`, `brave`, `arc`, `chromium`
- [ ] **6f**: social/misc (10) — `slack`, `discord`, `microsoft_teams`, `telegram`, `obsidian`, `dropbox`, `google_drive`, `steam`, `minecraft`, `lunarclient`, `dns_cache` (cmd: `sudo dscacheutil -flushcache` — **noted as requires sudo, so skipped by default**), `inactive_memory` (cmd: `sudo purge` — same handling)

> Modules requiring sudo are written but marked `MODULE_REQUIRES_SUDO=1`. They are skipped in non-interactive runs and only attempted when user explicitly opts in via `--with-sudo`.

### Task 7 — Execute engine

- [ ] **Step 1**: write `src/scripts/execute.sh` — for each module: if `MODULE_COMMAND` set and required binary present → eval the command (in a controlled subshell with timeout); else iterate `MODULE_PATHS` and `safe_rm` each child older than `MODULE_AGE_DAYS`.
- [ ] **Step 2**: emit per-module JSON `{module, bytes_freed, items_removed, command_used, errors}`. Commit.

### Task 8 — Orchestrator (`autoclean.sh`)

- [ ] **Step 1**: write `src/scripts/autoclean.sh` parsing flags: `--execute`, `--yes`, `--scope safe|all|interactive`, `--notify silent|notify|claude`, `--with-sudo`, `--dry-run`. Always runs scan first.
- [ ] **Step 2**: confirmation gate (>5 GB reclaim or any `MODULE_RISK=high` without `--yes`).
- [ ] **Step 3**: aggregates before/after `df -h /` into final report. Commit.

### Task 9 — Smart Advisor (⭐ feature)

- [ ] **Step 1**: write `docs/advisor-spec.md` defining the heuristic interface (every `advisor-heuristics/*.sh` exposes a `discover()` function emitting TSV: `name<TAB>path<TAB>bytes<TAB>last_access<TAB>recommendation<TAB>explanation`).
- [ ] **Step 2**: write `tests/test_advisor.sh` — for each heuristic, mock a fake `$HOME` tree, assert it surfaces the expected candidates and ignores unrelated paths.
- [ ] **Step 3**: write the 9 heuristics:
  - `ai_models.sh` — Ollama (`~/.ollama/models`), HuggingFace (`~/.cache/huggingface/hub`), LM Studio (`~/.cache/lm-studio/models`), llama.cpp models in common locations
  - `vm_disks.sh` — Parallels (`~/Parallels`), VMware (`~/Virtual Machines.localized`), UTM (`~/Library/Containers/com.utmapp.UTM/Data/Documents`), VirtualBox VMs
  - `ios_backups_old.sh` — `~/Library/Application Support/MobileSync/Backup/<UDID>` older than 6 months
  - `stale_node_modules.sh` — find `node_modules` whose parent dir mtime > 90 days
  - `stale_python_envs.sh` — `.venv`, `venv`, `env` dirs + `~/.conda/envs/*` with last-activated mtime > 90 days
  - `ide_workspaces.sh` — `~/Library/Application Support/Code/User/workspaceStorage/*`, JetBrains caches per stale project
  - `media_caches.sh` — Slack downloads, Discord downloaded media >1 GB
  - `orphaned_app_support.sh` — Pearcleaner-style: enumerate `~/Library/Application Support/*`, check if any installed app bundle ID references it; orphans → candidates
  - `large_misc.sh` — generic fallback: any dir >5 GB under `$HOME` not touched in 90 days, excluding everything caught above
- [ ] **Step 4**: write `src/scripts/advisor.sh` — load all heuristics, collect TSV, sort by bytes desc, format as table for stdout, support `--interactive` (per-row `d/k/s/q` prompt). Each `d` calls `safe_rm` (still whitelist-gated; if path isn't in whitelist, tells user "this path is outside the safety zone — delete manually with `rm -rf <path>` if you're sure" rather than silently failing).
- [ ] **Step 5**: tests pass. Commit.

### Task 10 — Schedule feature (⭐ feature)

- [ ] **Step 1**: write `docs/schedule-guide.md` — covers permissions (TCC Full Disk Access for the LaunchAgent), inspect (`launchctl list | grep macautoclean`), logs (`~/Library/Logs/macautoclean-scheduled.log`), troubleshooting.
- [ ] **Step 2**: write `src/templates/com.macautoclean.plist.tmpl`.
- [ ] **Step 3**: write `tests/test_schedule.sh` — uses a stub `$HOME/Library/LaunchAgents` dir; asserts the generated plist parses with `plutil -lint`, has the right `Label`, the right `StartCalendarInterval` for each preset.
- [ ] **Step 4**: write `src/scripts/schedule.sh`:
  - Interactive menu (weekly / biweekly / monthly / custom)
  - Scope menu (safe-silent / safe-notify / notify-only)
  - Render template (`sed` substitutions; `plutil -lint` validate)
  - `launchctl bootstrap gui/$UID …` (handle already-loaded case with `launchctl bootout` first)
  - `schedule --status` and `schedule --next-run`
- [ ] **Step 5**: write `src/scripts/unschedule.sh` (bootout + rm plist).
- [ ] **Step 6**: write `src/scripts/notify.sh` (wraps `osascript -e 'display notification "..." with title "MacAutoClean"'`; fall back to `terminal-notifier` if installed).
- [ ] **Step 7**: tests pass. Commit.

### Task 11 — SKILL.md workflow

- [ ] **Step 1**: write `src/SKILL.md` with frontmatter and 5-phase workflow:

  ```markdown
  ---
  name: macautoclean
  description: Use when the user wants to free disk space on a Mac. Triggers on "clean my Mac", "free up space", "disk full", "where did my storage go", "全自动清理 Mac", "清理储存空间", "Xcode is eating my disk", "Docker is huge", "set up auto cleanup", "find large unused folders". Runs a 48-category sweep, surfaces large/stale folders for review (AI models, VMs, old node_modules, iOS backups), and can schedule recurring auto-cleanup via launchd.
  ---
  ```

  Phases:
  1. **Baseline** — run `~/.claude/skills/macautoclean/scripts/scan.sh`; show table + `df -h /`.
  2. **Cleanup** — confirm with user → `autoclean.sh --execute --yes --scope all`; stream output.
  3. **Smart Advisor** — run `advisor.sh --interactive`; walk user through candidates one-by-one.
  4. **Schedule** — ask "want this to run automatically?" → if yes, `schedule.sh`.
  5. **Report** — before/after `df`, per-module bytes freed, advisor outcomes, schedule status.

  Plus mandatory sections: "What you don't do" (no sudo unless asked, no volumes, no external disks, no Cookies/Logins, no Documents/Desktop/iCloud) and "Red flags to surface" (Xcode/Docker running, free space <5 GB after run, advisor candidate >50 GB, etc.).

- [ ] **Step 2**: commit.

### Task 12 — End-to-end smoke test + real-machine validation

- [ ] **Step 1**: write `tests/test_smoke.sh`:
  - Lint every shell script (`shellcheck`)
  - Source `lib.sh`; smoke every public function
  - `scan.sh` produces valid JSON-lines
  - `autoclean.sh --execute --dry-run --yes` modifies no mtimes on `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Library/Mobile Documents`
  - `advisor.sh` runs without error (output may be empty on clean systems)
  - `schedule.sh` (with `--dry-run`) emits a `plutil -lint`-valid plist
- [ ] **Step 2**: real-machine run end-to-end. Verify `df -h /` shows reclaim. Verify no protected paths touched. Document any issues.
- [ ] **Step 3**: write `tests/test_module_loader.sh` covering edge cases (missing required field, malformed array, etc.).
- [ ] **Step 4**: commit.

### Task 13 — README + CHANGELOG + release prep

- [ ] **Step 1**: write `README.md` — install, quick-start, features, FAQ, comparison table vs mac-cleanup-py & Pearcleaner.
- [ ] **Step 2**: write `CHANGELOG.md` for v0.1.0.
- [ ] **Step 3**: tag `v0.1.0`. Final commit.

## 🚨 Risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| Module file deletes unwhitelisted path | Low | Catastrophic | `test_module_files.sh` validates every path against whitelist at build time |
| `docker volume prune` slips in | Low | Catastrophic | grep ban in `test_module_files.sh`; code review |
| `launchctl bootstrap` fails silently | Medium | Medium | `schedule.sh` reads back `launchctl list` to confirm + tells user logs path |
| LaunchAgent runs without Full Disk Access → silent partial cleanup | Medium | Medium | First scheduled run sends notification with reclaim — user notices if it's anomalously low; `schedule-guide.md` documents the TCC grant flow |
| Advisor mis-classifies a needed model as "safe" | Medium | Medium | Default rec is "Review" not "Delete"; only `Safe` for explicitly very-large + very-old + verbose explanation |
| User's bash 3.2 vs 4.x divergence | Low | Low | Plan locks to bash 3.2 syntax; shellcheck enforces |
| `osascript` notifications need approval | High | Low | First run prompts; fallback to log file |
| Apple changes path layout in macOS 27 | Low | Medium | Catalog + modules versioned; modules can be patched in isolation |

## ✅ Acceptance Criteria

- [ ] 13 tasks complete, each ending with `shellcheck` clean and all tests passing
- [ ] 48 modules authored; `test_module_files.sh` validates each at build time
- [ ] 9 advisor heuristics with at least one positive + one negative test case each
- [ ] `schedule.sh` end-to-end on real machine: agent loads, `launchctl list` confirms, scheduled run produces a log entry, `unschedule.sh` cleanly removes
- [ ] Real-machine `scan → execute → advisor → schedule` succeeds; `df -h /` shows actual reclaim; `~/Documents`, `~/Desktop`, `~/Pictures`, iCloud Drive, `~/.ssh` mtimes byte-identical before/after
- [ ] `install.sh` works from a fresh clone; uninstall removes both symlink and any active LaunchAgent
- [ ] Claude Code, asked "全自动清理 Mac", triggers the skill via `SKILL.md` description

---

**Status:** awaiting confirmation. Reply:
- `proceed` / `开始` — start Task 1
- `modify: <change>` — adjust before coding
- `skip task N` — drop a task
