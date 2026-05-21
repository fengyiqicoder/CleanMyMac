# Advisor Heuristic Spec

A Smart Advisor heuristic is a shell file in `src/advisor-heuristics/` that surfaces deletion candidates beyond fixed cleanup modules.

## Required

```sh
HEURISTIC_NAME="..."          # short label
HEURISTIC_DESCRIPTION="..."   # one-sentence summary

# Function that emits TSV rows to stdout. One row per candidate.
discover() {
  # Each row, TAB-separated:
  # name<TAB>path<TAB>bytes<TAB>last_access<TAB>recommendation<TAB>explanation
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Display name" "/abs/path" 1234567 "2025-12-01" "Safe (90d+)" "Why this is here and how to recreate it"
}
```

## Recommendation strings

| String | Meaning |
|---|---|
| `Safe (...)` | Confident deletion is non-destructive (e.g. cache, regenerable build artifact, untouched in 90+ days) |
| `Review` | Worth surfacing but the user should confirm |
| `Keep (...)` | Recently used; recommend keeping |

The advisor engine sorts rows by `bytes` desc and presents them as a table. In `--interactive` mode, each row gets a `[d]elete / [k]eep / [s]kip / [q]uit` prompt.

## Engine safety

- The engine still routes deletes through `safe_rm()`. If a candidate path is outside the whitelist, the engine **refuses the delete** and tells the user to remove it manually with the full path printed.
- Heuristics never delete anything themselves. They only emit candidates.

## Bundled heuristics

| File | What it surfaces |
|---|---|
| `ai_models.sh` | Ollama, HuggingFace, LM Studio model weights >1 GB |
| `vm_disks.sh` | Parallels, VMware, UTM, VirtualBox VM disks >1 GB |
| `ios_backups_old.sh` | iOS device backups untouched 6+ months |
| `stale_node_modules.sh` | `node_modules` in projects untouched 90+ days |
| `stale_python_envs.sh` | venv / .venv / conda envs untouched 90+ days |
| `ide_workspaces.sh` | VS Code workspaceStorage entries >10 MB, untouched 60+ days |
| `media_caches.sh` | Slack/Discord/Teams downloaded media >1 GB |
| `orphaned_app_support.sh` | `Application Support` folders for apps that aren't installed (Pearcleaner-style heuristic) |
| `large_misc.sh` | Generic fallback — any `$HOME` subdir >5 GB untouched 90+ days |

## Adding a new heuristic

1. Copy any existing file in `src/advisor-heuristics/` and adapt.
2. Make sure `discover()` is well-behaved on machines that don't have the relevant data (return zero rows, don't error out).
3. Use `[[ -d "$path" ]] || continue` guards.
4. Add a test row to `tests/test_advisor.sh` (TODO — not yet bundled).

The advisor runs all heuristics in subshells, so leaked variables don't bleed between heuristics.
