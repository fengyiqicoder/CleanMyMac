#!/usr/bin/env bash
# execute.sh — apply module cleanups. Emits one JSON object per module to stdout.
#
# Usage:
#   execute.sh --yes                 # run all modules (requires --yes; orchestrator gates this)
#   execute.sh --scope dev,browser   # filter by category
#   execute.sh --with-sudo           # also run sudo-required modules
#   execute.sh --dry-run             # don't actually delete

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SCOPE_FILTER=""
YES=0
WITH_SUDO=0
SCOPE_NEXT=0

for arg in "$@"; do
  if [[ "$SCOPE_NEXT" -eq 1 ]]; then SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue; fi
  case "$arg" in
    --scope) SCOPE_NEXT=1 ;;
    --scope=*) SCOPE_FILTER="${arg#--scope=}" ;;
    --yes|-y) YES=1 ;;
    --with-sudo) WITH_SUDO=1 ;;
    --dry-run) export DRY_RUN=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) err "unknown arg: $arg"; exit 2 ;;
  esac
done

if [[ "$YES" != "1" && "${DRY_RUN:-0}" != "1" ]]; then
  err "execute.sh requires --yes (or --dry-run). Use autoclean.sh for interactive flow."
  exit 2
fi

scope_matches() {
  [[ -z "$SCOPE_FILTER" ]] && return 0
  case ",$SCOPE_FILTER," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

command_is_safe() {
  case "$1" in
    *"docker volume prune"*|*"rm -rf /"*|*"sudo "*) return 1 ;;
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

total_freed=0
shopt -s nullglob
for module_file in "$MODULES_DIR"/*.sh; do
  base="$(basename "$module_file")"
  case "$base" in _*) continue ;; esac

  if ! load_module "$module_file" >/dev/null 2>&1; then
    emit_report module="$base" error="load_failed"
    continue
  fi

  if ! scope_matches "${MODULE_CATEGORY:-other}"; then
    emit_report module="$base" name="$MODULE_NAME" skipped=1 reason="out_of_scope"
    continue
  fi

  if [[ "${MODULE_REQUIRES_SUDO:-0}" -eq 1 && "$WITH_SUDO" -ne 1 ]]; then
    emit_report module="$base" name="$MODULE_NAME" skipped=1 reason="requires_sudo"
    continue
  fi

  if ! module_requirements_met; then
    emit_report module="$base" name="$MODULE_NAME" skipped=1 reason="missing_requires_${MODULE_REQUIRES:-unknown}"
    continue
  fi

  bytes_before=0
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    bytes_before=$((bytes_before + $(path_bytes "$p")))
  done

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
      log "[$base] running: $MODULE_COMMAND"
      bash -c "$MODULE_COMMAND" >>"$LOG_FILE" 2>&1 || cmd_status=$?
    fi
  else
    items=$(apply_paths)
  fi

  bytes_after=0
  for p in "${MODULE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    p="${p/#\~/$HOME}"
    bytes_after=$((bytes_after + $(path_bytes "$p")))
  done

  bytes_freed=$((bytes_before - bytes_after))
  [[ $bytes_freed -lt 0 ]] && bytes_freed=0
  total_freed=$((total_freed + bytes_freed))

  emit_report \
    module="$base" \
    name="$MODULE_NAME" \
    bytes_before="$bytes_before" \
    bytes_after="$bytes_after" \
    bytes_freed="$bytes_freed" \
    human_freed="$(format_bytes "$bytes_freed")" \
    items="$items" \
    command_used="$command_used" \
    exit_code="$cmd_status"
done

emit_report module="_total" bytes_freed="$total_freed" human_freed="$(format_bytes "$total_freed")" disk_free="$(disk_free_bytes)"
log "Execute complete: $(format_bytes "$total_freed") reclaimed."
