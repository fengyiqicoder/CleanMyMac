---
name: macautoclean
description: Use when the user wants to free disk space on a Mac. Triggers on "clean my Mac", "free up space", "disk full", "where did my storage go", "全自动清理 Mac", "清理储存空间", "Xcode is eating my disk", "Docker is huge", "set up auto cleanup", "find large unused folders", "find old AI models", "schedule cleanup". Runs a 51-module cleanup sweep across system caches, dev tools, browsers, IDEs, social apps, and games; surfaces large/stale folders for review (local AI models, VMs, old node_modules, iOS backups, orphaned app data); and can install a recurring auto-cleanup via launchd.
---

# MacAutoClean

## What this skill does

Three operations, in order:

1. **Cleanup** — Run 51 prebuilt cleanup modules (caches, logs, package caches, dev artifacts, browser caches, etc.) using safe native commands where possible (`brew cleanup`, `docker prune`, `xcrun simctl`, `tmutil`, `npm cache clean`, `pip cache purge`).
2. **Smart Advisor** — Surface large/stale folders the user may want to delete: local LLM weights (Ollama, HuggingFace, LM Studio), VM disks (Parallels, VMware, UTM), old iOS backups, stale `node_modules` / Python venvs / conda envs from abandoned projects, VS Code workspace storage, chat-app downloaded media, and orphaned `Application Support` folders for uninstalled apps.
3. **Schedule (optional)** — Install a macOS `launchd` LaunchAgent so cleanup runs weekly / biweekly / monthly automatically.

All deletes go through `safe_rm()` which rejects any path not in `references/whitelist.txt`. Caches, build artifacts, and package downloads regenerate automatically. Documents, Desktop, Photos, iCloud Drive, Mail, Messages, Keychain, browser cookies, SSH/GPG/AWS credentials, and Docker volumes are **never** touched.

## Workflow

Whenever the user asks to clean their Mac, follow these phases. Skip phases the user opts out of.

### Phase 1 — Baseline scan

```
~/.claude/skills/macautoclean/scripts/autoclean.sh
```

Read the output table. Present it back to the user with:
- Total reclaimable bytes
- Current free space (`df -h /`)
- Top 5 modules by size (so the user knows what categories dominate)

Example phrasing: "Scan shows **14.8 GB** reclaimable. Top 5: npm cache (4.3 GB), Xcode caches (2.7 GB), system caches (3.0 GB), Docker (1.1 GB), Slack (1.1 GB). Free space now: 49 GB. Proceed?"

### Phase 2 — Confirm and execute cleanup

If the user says yes:

```
~/.claude/skills/macautoclean/scripts/autoclean.sh --execute --yes
```

If they want a subset only, pass `--scope`, comma-separated, choosing from `system,dev,browser,social,game,media`. Examples:
- "Just dev tools" → `--scope dev`
- "Just caches" → `--scope system,browser`

If they want to include sudo-required cleanups (DNS flush, inactive memory purge), add `--with-sudo` and tell them they will be prompted for their password.

Stream the per-module JSON output to the user as it runs. At the end, show before/after `df -h /`.

### Phase 3 — Smart Advisor

After cleanup, ask: "Want me to look for additional folders you might want to delete? I'll surface things like old AI models, stale project node_modules, and orphaned app data."

If yes:

```
~/.claude/skills/macautoclean/scripts/advisor.sh
```

This produces a table sorted by size. Read it to the user; explain the recommendation column (`Safe` / `Review` / `Keep`). For each `Safe`-rated item, offer to delete:

```
~/.claude/skills/macautoclean/scripts/advisor.sh --interactive
```

The interactive mode prompts per-row `d/k/s/q`. Walk the user through it, deferring to their preference. Be cautious with `Review`-rated items — ask before deleting.

### Phase 4 — Schedule (optional)

Ask: "Want me to set up automatic cleanup so this happens weekly without you having to ask?"

If yes:

```
~/.claude/skills/macautoclean/scripts/schedule.sh
```

This is interactive — it asks for cadence (weekly/biweekly/monthly/custom) and scope (safe-only with notification / all 51 modules with notification / notify-only). Help the user pick:
- **Most users**: weekly + safe-only with notification — recovers steady-state without surprises
- **Power users**: weekly + all 51 modules — maximum reclaim
- **Cautious users**: notify-only — get a heads-up, then run manually

Confirm with `schedule.sh --status` after installation.

### Phase 5 — Report

End with a summary:
- Bytes reclaimed (from execute step)
- Advisor items handled
- Schedule status
- Anything skipped (sudo-required, errors) — and how to act on them

## What you don't do

- ❌ Never run `rm -rf` directly. All deletes go through `safe_rm`.
- ❌ Never bypass the whitelist. If a user asks to delete something outside it, refuse and tell them to delete it manually with full paths visible.
- ❌ Never `sudo` without explicit `--with-sudo` consent.
- ❌ Never `docker volume prune`. Volumes hold user databases and persistent state.
- ❌ Never touch `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Movies`, `~/Music`, `~/Library/Mobile Documents` (iCloud), `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `~/.ssh`, `~/.gnupg`, `~/.aws`.
- ❌ Never touch browser `Cookies`, `Login Data`, `History`, `Bookmarks`, `Preferences`. Only caches are in scope.
- ❌ Never touch external/network volumes — only `/`.
- ❌ Do not promise a specific GB reclaim before scanning.
- ❌ Do not auto-execute when scan estimates >5 GB without explicit user `yes` (the orchestrator gates this; respect it).

## Red flags to surface

1. **🚨 Free space <5 GB after cleanup** — recommend the user review Advisor candidates next, especially VM disks and old AI models.
2. **🚨 Single Advisor candidate >50 GB** — pause and double-check the user really wants to delete it.
3. **🚨 Docker is running** — tell the user `docker prune` will skip running containers (which is correct, but they may expect more reclaim).
4. **🚨 Xcode is running** — DerivedData may be locked. Suggest quitting Xcode first if reclaim seems anomalously low.
5. **⚠️ Old iOS backup >5 GB** — these are not auto-recoverable. Always ask twice.
6. **⚠️ Orphaned `Application Support/<vendor>` with recent mtime** — could be a sandbox bug or an app that uses a non-standard name. Don't bulk-delete; let user review.
7. **⚠️ Total scan <500 MB** — the user probably already cleaned recently. Suggest the Advisor instead.

## References

- [whitelist.txt](references/whitelist.txt) — paths `safe_rm` is allowed to touch (machine-readable)
- [whitelist.md](references/whitelist.md) — whitelist explained
- [safety-rules.md](references/safety-rules.md) — invariants every script enforces
