# Contributing to CleanMyMac

Thanks for the interest! CleanMyMac is intentionally simple and contributor-friendly. Most additions are 5-minute jobs.

## Common contributions

### 1. Add a new cleanup module

```bash
cp skills/cleanmymac/modules/_template.sh skills/cleanmymac/modules/<your_category>.sh
$EDITOR skills/cleanmymac/modules/<your_category>.sh
bash tests/test_module_files.sh    # must pass
```

If your path isn't already whitelisted, add the prefix to `skills/cleanmymac/references/whitelist.txt` and document it in `skills/cleanmymac/references/whitelist.md`.

### 2. Add a new advisor heuristic

```bash
cp skills/cleanmymac/advisor-heuristics/large_misc.sh skills/cleanmymac/advisor-heuristics/<your_rule>.sh
$EDITOR skills/cleanmymac/advisor-heuristics/<your_rule>.sh
skills/cleanmymac/scripts/advisor.sh    # smoke check
```

Heuristics must implement `discover()` emitting TSV (see `docs/advisor-spec.md`).

### 3. Improve scan/execute logic

These live in `skills/cleanmymac/scripts/scan.sh` and `skills/cleanmymac/scripts/execute.sh`. After any change:

```bash
bash tests/test_lib.sh
bash tests/test_module_files.sh
bash tests/test_smoke.sh
```

## Style

- Bash 3.2 syntax only (macOS default). No `mapfile`, no `${var,,}`, no `[[ -v ]]`.
- Two-space indent for bash.
- Every deletion goes through `safe_rm`. No direct `rm` calls.
- Modules are data — keep them declarative. If you find yourself writing complex logic in a module file, that logic probably belongs in the engine.

## Forbidden

- `docker volume prune` (banned by `test_module_files.sh`)
- `sudo` in modules (use `MODULE_REQUIRES_SUDO=1` instead)
- Any path under `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Movies`, `~/Music`, `~/Library/Mobile Documents`, `~/Library/Mail`, `~/Library/Messages`, `~/Library/Keychains`, `~/.ssh`, `~/.gnupg`, `~/.aws` — the enforcement test will catch you.

## Reporting issues

Please include:
- macOS version (`sw_vers`)
- The command you ran
- Output of `~/Library/Logs/cleanmymac.log` if relevant
- Whether `bash tests/test_smoke.sh` passes
