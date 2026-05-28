# Module Spec

A CleanMyMac **module** is a shell file in `skills/cleanmymac/modules/` that declares one cleanup category. Modules are pure data — the runtime in `skills/cleanmymac/scripts/{scan,execute}.sh` does all the work.

## Required fields

| Field | Type | Description |
|---|---|---|
| `MODULE_NAME` | string | Short human name (shown in scan report). |
| `MODULE_DESCRIPTION` | string | One-sentence description: what it targets + how it regenerates. |
| `MODULE_RISK` | enum | `low` / `medium` / `high`. Controls confirmation gate. |
| `MODULE_PATHS` *or* `MODULE_COMMAND` | array or string | At least one must be set. |

## Optional fields

| Field | Type | Description |
|---|---|---|
| `MODULE_CATEGORY` | string | `dev` / `browser` / `system` / `social` / `game` / `media`. Used by `--scope`. |
| `MODULE_COMMAND` | string | Native command preferred over raw deletion. Examples: `brew cleanup -s`, `docker image prune -f`. |
| `MODULE_AGE_DAYS` | int | Only touch entries with mtime older than N days. `0` = no filter. |
| `MODULE_REQUIRES` | string | Binary that must be on PATH for this module to run. |
| `MODULE_REQUIRES_SUDO` | 0/1 | Skip unless `--with-sudo` flag is set. |
| `MODULE_NOTES` | string | Optional note shown in scan report. |

## Build-time validation

`tests/test_module_files.sh` validates every `skills/cleanmymac/modules/*.sh`:

1. Sources without error via `load_module`
2. All required fields present and non-empty
3. `MODULE_RISK` is one of `low|medium|high`
4. Either `MODULE_PATHS` non-empty or `MODULE_COMMAND` non-empty
5. Every path in `MODULE_PATHS` passes `is_whitelisted()`
6. `MODULE_COMMAND` does **not** contain any banned string:
   - `docker volume prune`
   - `rm -rf /`
   - `sudo `

## Examples

### Path-only module

```sh
MODULE_NAME="System Caches"
MODULE_DESCRIPTION="App-level caches under ~/Library/Caches. Apps rebuild on next launch."
MODULE_RISK="low"
MODULE_CATEGORY="system"
MODULE_PATHS=("$HOME/Library/Caches")
```

### Command-backed module

```sh
MODULE_NAME="Homebrew"
MODULE_DESCRIPTION="Old downloads, outdated formula caches, unused dependencies."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")
MODULE_COMMAND="brew cleanup -s && brew autoremove"
MODULE_REQUIRES="brew"
```

### Age-gated module

```sh
MODULE_NAME="Downloads (older than 90 days)"
MODULE_DESCRIPTION="Files in ~/Downloads not touched in 90 days."
MODULE_RISK="medium"
MODULE_CATEGORY="system"
MODULE_PATHS=("$HOME/Downloads")
MODULE_AGE_DAYS=90
```

## Adding a new module

1. Copy `skills/cleanmymac/modules/_template.sh` → `skills/cleanmymac/modules/<category>.sh`
2. Fill in fields
3. If your paths are not already in `whitelist.txt`, add the prefix there and document it in `whitelist.md`
4. Run `bash tests/test_module_files.sh` to validate
5. Open a PR

Files starting with `_` are skipped by the loader and the validator.
