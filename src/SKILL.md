---
name: macautoclean
description: Use when the user wants to free disk space on a Mac. Triggers on "clean my Mac", "free up space", "disk full", "where did my storage go", "全自动清理 Mac", "清理储存空间", "Xcode is eating my disk", "Docker is huge", "set up auto cleanup", "find large unused folders", "find old AI models", "schedule cleanup". Runs a 51-module cleanup sweep classified into auto-safe / needs-review / skipped tiers; surfaces large/stale folders for review (local AI models, VMs, old node_modules, iOS backups, orphaned app data); and can install a recurring auto-cleanup via launchd.
---

# MacAutoClean

## Mental model: SCAN vs CLEAN

These are **two distinct concepts**. Never conflate them.

| Concept | What it is | Permissions | Reversible? |
|---|---|---|---|
| **SCAN** | One-shot, read-only audit. Never crashes on permission errors. Classifies every module into **auto-safe** (regenerable cache, no impact) / **needs-review** (medium/high risk, user decides) / **skipped** (sudo or TCC). Reports per-item: what it is + what happens if deleted. | None required | N/A (no writes) |
| **CLEAN** | Deletes. Auto-safe is bulk push-button. Review tier is **per-module interactive** — the user chooses one-by-one. | TCC for some paths | Caches regenerate; review-tier items are gone forever |

The skill **always scans first** and presents the breakdown before any delete.

## Workflow

### Phase 1 — Always scan first

```
~/.claude/skills/macautoclean/scripts/autoclean.sh
```

Output has 3 sections (AUTO-SAFE / NEEDS REVIEW / SKIPPED) plus per-item:
- Module name
- Size
- Risk
- **What it is and what happens if deleted** (from `MODULE_DESCRIPTION`)

Present these back to the user. Lead with the auto-safe total ("X GB freeable with no impact") and the review total ("Y MB across N items needing your decision").

### Phase 2 — Ask which mode

After showing the scan, ask the user one of three things:

| User says | Run |
|---|---|
| "Auto-clean / clean safe stuff / just do the safe ones" | `autoclean.sh --auto-safe --yes` |
| "Let me review the risky ones" | `autoclean.sh --review` (interactive per-item) |
| "Do everything" | `autoclean.sh --all` (auto-safe + interactive review) |

If unsure, default to **auto-safe only** — the no-regret choice.

### Phase 3 — Smart Advisor (optional)

After cleanup, offer: "Want me to look for large unused folders beyond the standard categories? Things like old AI models, stale node_modules, abandoned Python envs."

```
~/.claude/skills/macautoclean/scripts/advisor.sh
~/.claude/skills/macautoclean/scripts/advisor.sh --interactive
```

Walk the user through each candidate. The advisor reports name + path + size + last access + recommendation (Safe/Review/Keep) + explanation.

### Phase 4 — Schedule (optional)

Ask: "Want auto-cleanup to run weekly without you asking?"

```
~/.claude/skills/macautoclean/scripts/schedule.sh
```

Interactive: pick cadence (weekly/biweekly/monthly/custom) and scope. Most users want weekly + safe-only.

Inspect with `schedule.sh --status`. Remove with `unschedule.sh`.

### Phase 5 — Final report

- Bytes reclaimed (auto-safe + review combined)
- Items reviewed (kept vs deleted)
- Schedule status
- Anything skipped (sudo/TCC) — explain how to opt in

## What you don't do

- ❌ Never delete anything in the review tier without the user's explicit per-item OK
- ❌ Never run `rm -rf` directly — all deletes go through `safe_rm` (whitelist-gated)
- ❌ Never bypass the whitelist for any reason
- ❌ Never `sudo` without `--with-sudo` consent
- ❌ Never `docker volume prune` (banned at build time)
- ❌ Never touch: `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Movies`, `~/Music`, `~/Library/Mobile Documents` (iCloud), `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `~/.ssh`, `~/.gnupg`, `~/.aws`
- ❌ Never touch browser `Cookies`, `Login Data`, `History`, `Bookmarks`, `Preferences`
- ❌ Never touch external/network volumes — only `/`
- ❌ Do not promise a specific GB reclaim before scanning
- ❌ Do not present medium/high-risk modules as "safe to delete" — they go in the REVIEW tier for a reason

## Red flags to surface

1. **🚨 Auto-safe total >5 GB after the user already cleaned recently** — caches grow fast, this is normal
2. **🚨 Single review item >5 GB** — pause, double-check
3. **🚨 Free space <5 GB after cleanup** — suggest Advisor next (VMs, AI models)
4. **🚨 Docker / Xcode running** — `docker prune` skips running containers; DerivedData may be locked. Suggest quitting first
5. **⚠️ Skipped count high** — explain it's TCC/sudo, not an error
6. **⚠️ Review tier includes iOS backups >5 GB** — backups are NOT auto-recoverable; ask twice

## References

- [whitelist.txt](references/whitelist.txt) — paths `safe_rm` is allowed to touch
- [whitelist.md](references/whitelist.md) — whitelist explained in prose
- [safety-rules.md](references/safety-rules.md) — invariants every script enforces
- [cleanup-catalog.md](references/cleanup-catalog.md) — every module's purpose, size, recovery
