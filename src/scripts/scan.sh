#!/usr/bin/env bash
# scan.sh — read-only disk-usage scan of every module.
# Emits one JSON object per line to stdout. Human progress to stderr.
#
# Usage:
#   scan.sh                       # scan all modules
#   scan.sh --scope dev,browser   # filter by category
#   scan.sh --json                # only emit JSON (no progress messages)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SCOPE_FILTER=""
QUIET=0
SCOPE_NEXT=0
for arg in "$@"; do
  if [[ "$SCOPE_NEXT" -eq 1 ]]; then
    SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue
  fi
  case "$arg" in
    --scope) SCOPE_NEXT=1 ;;
    --scope=*) SCOPE_FILTER="${arg#--scope=}" ;;
    --json|--quiet) QUIET=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) err "unknown arg: $arg"; exit 2 ;;
  esac
done

scope_matches() {
  [[ -z "$SCOPE_FILTER" ]] && return 0
  local cat="$1"
  case ",$SCOPE_FILTER," in
    *",$cat,"*) return 0 ;;
    *) return 1 ;;
  esac
}

total_bytes=0
total_modules=0
scanned_modules=0

[[ $QUIET -eq 0 ]] && log "Scanning modules in $MODULES_DIR..."

shopt -s nullglob
for module_file in "$MODULES_DIR"/*.sh; do
  base="$(basename "$module_file")"
  case "$base" in _*) continue ;; esac
  total_modules=$((total_modules+1))

  if ! load_module "$module_file" >/dev/null 2>&1; then
    emit_report module="$base" error="load_failed"
    continue
  fi

  if ! scope_matches "${MODULE_CATEGORY:-other}"; then continue; fi
  if ! module_requirements_met; then
    emit_report module="$base" name="$MODULE_NAME" available=0 reason="requires_${MODULE_REQUIRES:-unknown}_not_installed"
    continue
  fi

  scanned_modules=$((scanned_modules+1))
  module_bytes=0
  paths_present=0
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    if [[ -e "$p" ]]; then
      paths_present=$((paths_present+1))
      b=$(path_bytes "$p")
      module_bytes=$((module_bytes+b))
    fi
  done

  total_bytes=$((total_bytes+module_bytes))

  emit_report \
    module="$base" \
    name="$MODULE_NAME" \
    category="${MODULE_CATEGORY:-other}" \
    risk="$MODULE_RISK" \
    bytes="$module_bytes" \
    human="$(format_bytes "$module_bytes")" \
    paths_present="$paths_present" \
    has_command="$([[ -n "${MODULE_COMMAND:-}" ]] && echo 1 || echo 0)" \
    requires_sudo="${MODULE_REQUIRES_SUDO:-0}"
done

emit_report \
  module="_summary" \
  modules_total="$total_modules" \
  modules_scanned="$scanned_modules" \
  bytes_total="$total_bytes" \
  human_total="$(format_bytes "$total_bytes")" \
  disk_free="$(disk_free_bytes)" \
  disk_used_pct="$(disk_used_pct)"

[[ $QUIET -eq 0 ]] && log "Scan complete: $scanned_modules modules, $(format_bytes "$total_bytes") reclaimable."
