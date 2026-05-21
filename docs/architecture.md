# Architecture

## Layers

```
                     User says "clean my Mac"
                              │
                              ▼
                        ┌─────────────┐
                        │  SKILL.md   │  5-phase workflow Claude follows
                        └──────┬──────┘
                               │
                               ▼
                        ┌─────────────┐
                        │ autoclean.sh│  master orchestrator
                        └──────┬──────┘
                  ┌────────────┼────────────┐
                  ▼            ▼            ▼
            ┌─────────┐  ┌──────────┐  ┌──────────┐
            │ scan.sh │  │execute.sh│  │advisor.sh│
            └────┬────┘  └─────┬────┘  └────┬─────┘
                 │             │            │
                 │       ┌─────┴─────┐      │
                 │       │           │      │
                 ▼       ▼           ▼      ▼
            ┌──────────────────────────────────┐
            │            lib.sh                │
            │  - log/warn/err                  │
            │  - path_bytes / format_bytes     │
            │  - is_whitelisted                │
            │  - safe_rm  ← the only delete    │
            │  - load_module / module_requires │
            │  - emit_report (JSON)            │
            └─────────────┬────────────────────┘
                          │
                          ▼
            ┌──────────────────────────────────┐
            │     references/whitelist.txt     │
            │  prefix list — every delete must │
            │  start with one of these         │
            └──────────────────────────────────┘
```

## Why declarative modules

Each cleanup category is data, not code. Adding a new category = 6 lines in a new `.sh` file. The engine handles:
- Scan (sizing via `du -sk`)
- Execute (children iteration with age filter, or native command)
- Validation (whitelist coverage, banned commands, required fields)

This means contributors don't write delete logic — they only describe paths. The single delete primitive lives in `safe_rm()`, which is small enough to audit by eye.

## Why no quarantine

The repo evaluated a quarantine model where deleted items move to `/tmp/macautoclean/` for 24h. We dropped it because:
- `/tmp` is on the same APFS volume as `~`, so `mv` does not reclaim disk space.
- Caches and build artifacts are designed to be regenerable.
- macOS already provides a 30-day Trash window for user-initiated deletions.
- Adding a hold area creates a second concept the user has to understand.

Reversibility comes from the data itself, not from a holding pen.

## Whitelist invariants

1. Every entry is a path **prefix** (not a regex).
2. `~` expands to `$HOME` at load time.
3. Comparison is prefix-anchored (`/foo` matches `/foo/bar` but not `/foobar`).
4. Sensitive paths (`~/Documents`, `~/Library/Mail`, browser `Cookies`, etc.) are never in the whitelist — `is_whitelisted` returns false → `safe_rm` refuses.
5. Build-time test (`test_whitelist_enforcement.sh`) asserts both directions: known-safe allowed + sensitive rejected.

## Schedule flow

```
schedule.sh
  │
  ├─ Interactive: pick cadence (weekly/biweekly/monthly/custom) + scope
  ├─ Render: substitute placeholders in templates/com.macautoclean.plist.tmpl
  ├─ Validate: plutil -lint
  ├─ Install: launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.macautoclean.plist
  └─ Confirm: launchctl list | grep com.macautoclean
```

The LaunchAgent runs `autoclean.sh --execute --yes --scope <X> --notify <Y>` at the chosen interval. Output goes to `~/Library/Logs/macautoclean-scheduled.log`.

## Why bash 3.2

macOS ships bash 3.2 by default and has done so for >15 years. Targeting it means:
- Zero install steps beyond `install.sh`
- No Homebrew dependency
- Compatible with corp-locked Macs where users can't install new shells
- Compatible with launchd's default PATH

Trade-off: we avoid bash 4+ features (`mapfile`, `${var,,}`, `[[ -v ]]`).
