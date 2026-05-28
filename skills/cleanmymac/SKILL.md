---
name: cleanmymac
description: Use when the user wants to free disk space on a Mac. Triggers on "clean my Mac", "free up space", "disk full", "where did my storage go", "全自动清理 Mac", "清理储存空间", "Xcode is eating my disk", "Docker is huge", "what's taking my disk", "show me a disk map", "set up auto cleanup", "find large unused folders", "find old AI models", "schedule cleanup". Walks the filesystem from any path, annotates every folder with auto-safe / review / never-touch / unknown based on a 51-module judgment registry, and supports both bulk auto-clean and per-item interactive review. Can install recurring auto-cleanup via launchd.
---

# CleanMyMac

## Architecture — discovery vs judgment vs action

Three separate layers. Never conflate them.

| Layer | What it does | Script | Reversible? |
|---|---|---|---|
| **DISCOVER** | Tree-walks the filesystem from any path (default `$HOME`). For each immediate child, looks up the path against the judgment registry and annotates it. Like OmniDiskSweeper but with built-in classification. | `diskmap.sh` | N/A (read-only) |
| **JUDGE** | 51 cleanup modules + a hardcoded never-touch list form the **registry**. For any path, it answers: is this auto-safe / needs-review / never-touch / unknown? | `lib-registry.sh` (consumed by diskmap & autoclean) | N/A |
| **ACT** | Deletes. Auto-safe runs in bulk. Review runs per-item interactively. Never-touch and unknown require explicit user opt-in. | `autoclean.sh`, `execute.sh` | Caches regenerate; review items are gone forever |

## Workflow

### Phase 1 — Discover with diskmap (default)

```
~/.claude/skills/cleanmymac/scripts/diskmap.sh
```

Output: every folder ≥ 2 GB, auto-drilled to specific classifiable items, grouped into THREE tiers (no "unknown" — diskmap auto-classifies via registry + heuristics):

| Icon | Tier | Meaning |
|---|---|---|
| ✅ | auto_safe | Cache / build artifact (registry match OR cache-name heuristic). Deletable in bulk with no impact. |
| ⚠️ | review | Anything else (app data, sandboxed app, AI model weights, backups). Decide per-item. |
| 🔒 | never_touch | User data, OS files, iCloud, Mail, Messages, Keychain, SSH/GPG/AWS. Protected. |

To drill into a specific path:
```
diskmap.sh <path>          # e.g. diskmap.sh ~/Library
diskmap.sh / --top 20      # full-disk view (some TCC denials expected)
diskmap.sh --threshold 500M  # surface anything ≥ 500 MB
diskmap.sh --json          # JSON output for parsing
```

### ⚠️ MANDATORY OUTPUT RULE — paste diskmap verbatim

When presenting scan results to the user, you **MUST** paste the diskmap output VERBATIM inside a single fenced code block (```text … ```). Do not:
- ❌ Reformat into markdown tables
- ❌ Split items into your own sub-categories ("AI 类 / 应用类 / 开发类")
- ❌ Drop columns, drop rows, or change column order
- ❌ Add your own emoji/colors/icons on top of what diskmap already prints
- ❌ Truncate paths or rename modules

The diskmap output IS the canonical UI. It is fixed-width text with three sections (✅ AUTO-SAFE / ⚠️ NEEDS REVIEW / 🔒 NEVER-TOUCH), one item per line, format `SIZE | WHAT IT IS | WHERE`. Users specifically asked for this layout — preserve it byte-for-byte.

After the code block, you MAY add at most ONE short sentence recommending the next step (e.g. "建议先清 27.7 GB 安全项 → `autoclean.sh --auto-safe --yes`"). Nothing more elaborate than that.

### Phase 2 — Act with autoclean

After the user understands the landscape, ask which mode:

```
~/.claude/skills/cleanmymac/scripts/autoclean.sh                          # scan modules + show 3-tier breakdown
~/.claude/skills/cleanmymac/scripts/autoclean.sh --auto-safe --yes        # delete auto-safe in bulk (recommended)
~/.claude/skills/cleanmymac/scripts/autoclean.sh --review                 # interactive per-item for medium/high
~/.claude/skills/cleanmymac/scripts/autoclean.sh --all                    # both
```

The `--review` mode walks the user through each medium/high-risk module: shows name + size + what-it-is + what-happens-if-deleted, then prompts `[d]elete / [k]eep / [q]uit`.

### Phase 3 — Drill into unknowns (optional)

If diskmap shows large ❓ unknown folders, suggest drilling:

```
diskmap.sh ~/.cursor       # for example, if .cursor was big and unclassified
diskmap.sh ~/Library/Containers
```

For folders that turn out to be safe regenerable data (e.g. a new AI tool's cache), suggest adding a module to the registry — open a PR with `src/modules/<name>.sh` + whitelist entry.

### Phase 4 — Smart Advisor (optional, complementary)

`advisor.sh` runs 9 specific heuristics for things diskmap can't auto-classify by path alone (e.g. old node_modules in any project, stale conda envs, downloaded chat media). Use it when diskmap surfaces unknown folders that match these patterns.

```
~/.claude/skills/cleanmymac/scripts/advisor.sh --interactive
```

### Phase 5 — Schedule (optional)

Ask: "Want auto-cleanup to run weekly without you asking?"

```
~/.claude/skills/cleanmymac/scripts/schedule.sh
```

Interactive: pick cadence (weekly/biweekly/monthly/custom) and scope. Most users want weekly + safe-only.

### Phase 6 — Final report

- Bytes reclaimed (auto-safe + review combined)
- Items reviewed (kept vs deleted)
- Schedule status
- Largest unknowns the user did NOT drill into — list them, suggest module contributions

## What you don't do

- ❌ Never delete an `❓ unknown` path on the user's say-so without first showing them what it contains (drill into it)
- ❌ Never delete anything in the review tier without explicit per-item OK
- ❌ Never run `rm -rf` directly — all deletes go through `safe_rm` (whitelist-gated)
- ❌ Never bypass the whitelist for any reason
- ❌ Never `sudo` without `--with-sudo` consent
- ❌ Never `docker volume prune` (banned at build time)
- ❌ Never touch the `🔒 never_touch` list: `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Movies`, `~/Music`, `~/Library/Mobile Documents` (iCloud), `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `~/.ssh`, `~/.gnupg`, `~/.aws`
- ❌ Never touch browser `Cookies`, `Login Data`, `History`, `Bookmarks`, `Preferences`
- ❌ Never touch external/network volumes — only `/`
- ❌ Do not present medium/high-risk modules as "safe to delete" — they live in the REVIEW tier for a reason

## Red flags to surface

1. **🚨 Unknown total >50 GB** — there's a lot of unclassified data; drill in before any delete
2. **🚨 Single unknown folder >10 GB** — almost always worth investigating (VMs, AI models, abandoned project deps)
3. **🚨 Single review item >5 GB** — pause, double-check the user really wants it deleted
4. **🚨 Free space <5 GB after cleanup** — suggest diskmap drill into ❓ unknowns
5. **🚨 Docker / Xcode running** — `docker prune` skips running containers; DerivedData may be locked. Suggest quitting first
6. **⚠️ TCC permission denied on diskmap** — show "true size ≥ X GB" line and tell user they can grant Full Disk Access in System Settings if they want true totals
7. **⚠️ Review tier includes iOS backups >5 GB** — backups are NOT auto-recoverable; ask twice

## Language / i18n

All scripts auto-detect language from `$LANG` (`zh*` → Chinese, anything else → English). If the user is conversing with you in Chinese but their shell `$LANG` is `en_US.UTF-8` (common on macOS), the disk report will come out in English — which is wrong.

**Fix**: before invoking any script, export `CLEAN_MY_MAC_LANG` to match the conversation language. This always wins over `$LANG`:

```bash
CLEAN_MY_MAC_LANG=zh ~/.claude/skills/cleanmymac/scripts/autoclean.sh
CLEAN_MY_MAC_LANG=en ~/.claude/skills/cleanmymac/scripts/diskmap.sh
```

The override flows into every downstream script via `MAC_LANG` (exported by `lib.sh`). Translation dictionary lives in [`references/i18n.sh`](references/i18n.sh) — keyed on English source strings, gettext-style. Adding a string: wrap with `$(i18n "English literal")` at the call site, add a case branch under `_i18n_zh`.

## References

- [whitelist.txt](references/whitelist.txt) — paths `safe_rm` is allowed to touch
- [whitelist.md](references/whitelist.md) — whitelist explained in prose
- [safety-rules.md](references/safety-rules.md) — invariants every script enforces
- [cleanup-catalog.md](references/cleanup-catalog.md) — every module's purpose, size, recovery
- [i18n.sh](references/i18n.sh) — translation dictionary (add a new language = new `_i18n_<code>` function + dispatch branch)
