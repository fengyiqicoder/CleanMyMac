#!/usr/bin/env bash
# execute.sh — apply module cleanups. Emits one JSON object per module to stdout.
#
# Usage:
#   execute.sh --yes                       # run all auto-safe modules (default)
#   execute.sh --yes --tier auto_safe      # only low-risk modules (no impact)
#   execute.sh --yes --tier review         # only medium/high-risk (with --review-yes for each)
#   execute.sh --yes --tier all            # both
#   execute.sh --yes --module xcode_archives.sh,downloads_aged.sh  # specific modules only
#   execute.sh --yes --scope dev,browser   # category filter
#   execute.sh --yes --with-sudo
#   execute.sh --dry-run                   # no actual deletes
#
# IMPORTANT: no `set -e` — must continue on per-module errors (TCC denial, missing dirs, etc.)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SCOPE_FILTER=""
TIER_FILTER="auto_safe"   # default: only auto-safe runs unconditionally
MODULE_FILTER=""
YES=0
WITH_SUDO=0

SCOPE_NEXT=0; TIER_NEXT=0; MOD_NEXT=0
for arg in "$@"; do
  if [[ "$SCOPE_NEXT" -eq 1 ]]; then SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue; fi
  if [[ "$TIER_NEXT"  -eq 1 ]]; then TIER_FILTER="$arg";  TIER_NEXT=0;  continue; fi
  if [[ "$MOD_NEXT"   -eq 1 ]]; then MODULE_FILTER="$arg"; MOD_NEXT=0;  continue; fi
  case "$arg" in
    --scope) SCOPE_NEXT=1 ;;
    --scope=*) SCOPE_FILTER="${arg#--scope=}" ;;
    --tier) TIER_NEXT=1 ;;
    --tier=*) TIER_FILTER="${arg#--tier=}" ;;
    --module|--modules) MOD_NEXT=1 ;;
    --module=*|--modules=*) MODULE_FILTER="${arg#*=}" ;;
    --yes|-y) YES=1 ;;
    --with-sudo) WITH_SUDO=1 ;;
    --dry-run) export DRY_RUN=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) err "unknown arg: $arg"; exit 2 ;;
  esac
done

if [[ "$YES" != "1" && "${DRY_RUN:-0}" != "1" ]]; then
  err "execute.sh requires --yes (or --dry-run). Use autoclean.sh for the interactive flow."
  exit 2
fi

scope_matches() {
  [[ -z "$SCOPE_FILTER" ]] && return 0
  case ",$SCOPE_FILTER," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}
module_matches() {
  [[ -z "$MODULE_FILTER" ]] && return 0
  case ",$MODULE_FILTER," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}
tier_matches() {
  # $1 = module's tier (auto_safe|review)
  case "$TIER_FILTER" in
    all) return 0 ;;
    auto_safe) [[ "$1" == "auto_safe" ]] ;;
    review)    [[ "$1" == "review"    ]] ;;
    *) return 1 ;;
  esac
}

command_is_safe() {
  case "$1" in
    *"docker volume prune"*) return 1 ;;
    *"rm -rf /"*) return 1 ;;
    *"sudo "*) return 1 ;;
  esac
  return 0
}

apply_paths() {
  local items=0
  local age="${MODULE_AGE_DAYS:-0}"
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    [[ -e "$p" ]] || continue
    if [[ -d "$p" ]]; then
      local find_args=( "$p" -mindepth 1 -maxdepth 1 )
      [[ "$age" -gt 0 ]] && find_args+=( -mtime "+$age" )
      while IFS= read -r child; do
        [[ -e "$child" ]] || continue
        if safe_rm "$child" >/dev/null 2>&1; then items=$((items+1)); fi
      done < <(/usr/bin/find "${find_args[@]}" 2>/dev/null)
    else
      if safe_rm "$p" >/dev/null 2>&1; then items=$((items+1)); fi
    fi
  done
  echo "$items"
}

sum_paths() {
  local total=0 b
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    b=$(path_bytes "$p" 2>/dev/null || echo 0)
    b="${b:-0}"
    total=$((total + b))
  done
  echo "$total"
}

total_freed=0
shopt -s nullglob
for module_file in "$MODULES_DIR"/*.sh; do
  base="$(basename "$module_file")"
  case "$base" in _*) continue ;; esac

  if ! load_module "$module_file" >/dev/null 2>&1; then
    emit_report module="$base" error="load_failed"
    continue
  fi

  if ! module_matches "$base"; then continue; fi
  if ! scope_matches "${MODULE_CATEGORY:-other}"; then continue; fi

  # Determine tier of this module
  module_tier="auto_safe"
  case "$MODULE_RISK" in medium|high) module_tier="review" ;; esac
  if ! tier_matches "$module_tier"; then continue; fi

  if [[ "${MODULE_REQUIRES_SUDO:-0}" -eq 1 && "$WITH_SUDO" -ne 1 ]]; then
    emit_report module="$base" name="$MODULE_NAME" skipped=1 reason="requires_sudo"
    continue
  fi

  if ! module_requirements_met; then
    emit_report module="$base" name="$MODULE_NAME" skipped=1 reason="missing_requires_${MODULE_REQUIRES:-unknown}"
    continue
  fi

  bytes_before=$(sum_paths)
  bytes_before="${bytes_before:-0}"
  command_used=0
  items=0
  cmd_status=0

  if [[ -n "${MODULE_COMMAND:-}" ]]; then
    if ! command_is_safe "$MODULE_COMMAND"; then
      emit_report module="$base" name="$MODULE_NAME" error="command_banned_at_runtime"
      continue
    fi
    command_used=1
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log "DRY-RUN [$base] would run: $MODULE_COMMAND"
    else
      log "[$base] $MODULE_COMMAND"
      bash -c "$MODULE_COMMAND" >>"$LOG_FILE" 2>&1 || cmd_status=$?
    fi
  else
    items=$(apply_paths)
  fi

  bytes_after=$(sum_paths)
  bytes_after="${bytes_after:-0}"
  bytes_freed=$((bytes_before - bytes_after))
  [[ $bytes_freed -lt 0 ]] && bytes_freed=0
  total_freed=$((total_freed + bytes_freed))

  emit_report \
    module="$base" \
    name="$MODULE_NAME" \
    tier="$module_tier" \
    bytes_before="$bytes_before" \
    bytes_after="$bytes_after" \
    bytes_freed="$bytes_freed" \
    human_freed="$(format_bytes "$bytes_freed")" \
    items="$items" \
    command_used="$command_used" \
    exit_code="$cmd_status"
done

emit_report \
  module="_total" \
  bytes_freed="$total_freed" \
  human_freed="$(format_bytes "$total_freed")" \
  disk_free="$(disk_free_bytes)"

log "Execute complete: $(format_bytes "$total_freed") reclaimed."
exit 0
