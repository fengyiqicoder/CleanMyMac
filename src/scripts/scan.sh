#!/usr/bin/env bash
# scan.sh — read-only disk scan. NEVER crashes on per-module errors.
# Classifies each module as: auto_safe (low risk), review (medium/high risk), skipped (perm/missing).
# Emits one JSON object per line to stdout. Human progress to stderr (suppressed by --json).

# IMPORTANT: no `set -e` — we must continue scanning even if individual modules fail (TCC, missing dirs, etc.)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SCOPE_FILTER=""
QUIET=0
SCOPE_NEXT=0
for arg in "$@"; do
  if [[ "$SCOPE_NEXT" -eq 1 ]]; then SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue; fi
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
  case ",$SCOPE_FILTER," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

total_bytes=0
auto_safe_bytes=0
review_bytes=0
total_modules=0
scanned_modules=0
auto_safe_count=0
review_count=0
skipped_count=0

[[ $QUIET -eq 0 ]] && log "Scanning modules in $MODULES_DIR..."

shopt -s nullglob
for module_file in "$MODULES_DIR"/*.sh; do
  base="$(basename "$module_file")"
  case "$base" in _*) continue ;; esac
  total_modules=$((total_modules+1))

  if ! load_module "$module_file" >/dev/null 2>&1; then
    emit_report module="$base" tier="skipped" reason="load_failed"
    skipped_count=$((skipped_count+1))
    continue
  fi

  if ! scope_matches "${MODULE_CATEGORY:-other}"; then
    continue  # silently filtered, don't emit
  fi

  # Sudo-required modules are always "skipped" unless user explicitly opts in.
  if [[ "${MODULE_REQUIRES_SUDO:-0}" -eq 1 ]]; then
    emit_report module="$base" name="$MODULE_NAME" tier="skipped" reason="requires_sudo" risk="$MODULE_RISK"
    skipped_count=$((skipped_count+1))
    continue
  fi

  if ! module_requirements_met; then
    emit_report module="$base" name="$MODULE_NAME" tier="skipped" reason="requires_${MODULE_REQUIRES:-unknown}_not_installed"
    skipped_count=$((skipped_count+1))
    continue
  fi

  scanned_modules=$((scanned_modules+1))
  module_bytes=0
  paths_present=0

  # Per-path sizing wrapped against any unexpected failures.
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    if [[ -e "$p" ]]; then
      paths_present=$((paths_present+1))
      b=$(path_bytes "$p" 2>/dev/null || echo 0)
      b="${b:-0}"
      module_bytes=$((module_bytes + b))
    fi
  done

  total_bytes=$((total_bytes + module_bytes))

  # Classify: low risk + has data → auto_safe; medium/high risk → review
  tier="auto_safe"
  case "${MODULE_RISK}" in
    medium|high) tier="review" ;;
  esac

  if [[ "$tier" == "auto_safe" ]]; then
    auto_safe_bytes=$((auto_safe_bytes + module_bytes))
    auto_safe_count=$((auto_safe_count+1))
  else
    review_bytes=$((review_bytes + module_bytes))
    review_count=$((review_count+1))
  fi

  emit_report \
    module="$base" \
    name="$MODULE_NAME" \
    category="${MODULE_CATEGORY:-other}" \
    risk="$MODULE_RISK" \
    tier="$tier" \
    bytes="$module_bytes" \
    human="$(format_bytes "$module_bytes")" \
    paths_present="$paths_present" \
    has_command="$([[ -n "${MODULE_COMMAND:-}" ]] && echo 1 || echo 0)" \
    description="${MODULE_DESCRIPTION:-}"
done

emit_report \
  module="_summary" \
  modules_total="$total_modules" \
  modules_scanned="$scanned_modules" \
  bytes_total="$total_bytes" \
  human_total="$(format_bytes "$total_bytes")" \
  auto_safe_bytes="$auto_safe_bytes" \
  auto_safe_human="$(format_bytes "$auto_safe_bytes")" \
  auto_safe_count="$auto_safe_count" \
  review_bytes="$review_bytes" \
  review_human="$(format_bytes "$review_bytes")" \
  review_count="$review_count" \
  skipped_count="$skipped_count" \
  disk_free="$(disk_free_bytes)" \
  disk_used_pct="$(disk_used_pct)"

if [[ $QUIET -eq 0 ]]; then
  log "Scan complete: $auto_safe_count auto-safe ($(format_bytes "$auto_safe_bytes")), $review_count review ($(format_bytes "$review_bytes")), $skipped_count skipped."
fi
exit 0
