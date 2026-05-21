#!/usr/bin/env bash
# Validates every src/modules/*.sh against the module spec.
# Run after authoring or modifying any module file.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export WHITELIST_FILE="$REPO/src/references/whitelist.txt"
. "$REPO/src/scripts/lib.sh"

PASS=0; FAIL=0
banned_patterns=( "docker volume prune" "rm -rf /" "sudo " )

count=0
for module in "$REPO/src/modules/"*.sh; do
  base="$(basename "$module")"
  case "$base" in _*) continue ;; esac
  count=$((count+1))

  # 1. Sources via load_module
  if ! load_module "$module" >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ $base: load_module failed" >&2
    continue
  fi
  PASS=$((PASS+1))

  # 2. All paths whitelisted
  paths_ok=1
  for p in "${MODULE_PATHS[@]}"; do
    [[ -z "$p" ]] && continue
    if ! is_whitelisted "$p"; then
      paths_ok=0
      FAIL=$((FAIL+1)); echo "  ✗ $base: path NOT whitelisted: $p" >&2
    fi
  done
  [[ $paths_ok -eq 1 ]] && PASS=$((PASS+1))

  # 3. MODULE_COMMAND must not contain banned patterns
  cmd_ok=1
  if [[ -n "${MODULE_COMMAND:-}" ]]; then
    for pat in "${banned_patterns[@]}"; do
      if echo "$MODULE_COMMAND" | grep -qF "$pat"; then
        cmd_ok=0
        FAIL=$((FAIL+1)); echo "  ✗ $base: MODULE_COMMAND banned: '$pat'" >&2
      fi
    done
  fi
  [[ $cmd_ok -eq 1 ]] && PASS=$((PASS+1))
done

echo ""
echo "Modules validated: $count"
echo "Results: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
