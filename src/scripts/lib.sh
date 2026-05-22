#!/usr/bin/env bash
# lib.sh — shared helpers for MacAutoClean scripts.
# Compatible with macOS default bash 3.2. No bash 4+ features.

: "${MAC_AUTOCLEAN_VERSION:=0.1.0}"
: "${LOG_FILE:=$HOME/Library/Logs/macautoclean.log}"
: "${DRY_RUN:=0}"

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${WHITELIST_FILE:=$_LIB_DIR/../references/whitelist.txt}"
: "${MODULES_DIR:=$_LIB_DIR/../modules}"
: "${HEURISTICS_DIR:=$_LIB_DIR/../advisor-heuristics}"
: "${TEMPLATES_DIR:=$_LIB_DIR/../templates}"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG_FILE" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG_FILE" >&2; }
err()  { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG_FILE" >&2; }

path_bytes() {
  local p="$1" out
  [[ -e "$p" ]] || { echo 0; return 0; }
  out=$(/usr/bin/du -sk "$p" 2>/dev/null | awk 'NR==1{print $1*1024; exit}')
  echo "${out:-0}"
}

format_bytes() {
  local b="$1"
  awk -v b="$b" 'BEGIN{
    split("B KB MB GB TB",u," ")
    i=1; while (b>=1024 && i<5) { b=b/1024; i++ }
    if (i==1) printf "%d %s\n", b, u[i]
    else printf "%.1f %s\n", b, u[i]
  }'
}

is_whitelisted() {
  local target="$1"
  [[ -z "$target" ]] && return 1
  [[ -f "$WHITELIST_FILE" ]] || return 1
  case "$target" in
    /*) ;;
    *)
      local parent
      parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd)" || return 1
      target="$parent/$(basename "$target")"
      ;;
  esac
  while IFS= read -r prefix; do
    [[ -z "$prefix" || "$prefix" == \#* ]] && continue
    prefix="${prefix/#\~/$HOME}"
    case "$target" in
      "$prefix"|"$prefix"/*) return 0 ;;
    esac
  done <"$WHITELIST_FILE"
  return 1
}

safe_rm() {
  local p="$1"
  if [[ -z "$p" || "$p" == "/" ]]; then
    err "safe_rm refused: empty or root path"
    return 1
  fi
  if ! is_whitelisted "$p"; then
    err "safe_rm refused: path not whitelisted: $p"
    return 1
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN would rm -rf: $p"
    return 0
  fi
  /bin/rm -rf -- "$p" 2>/dev/null || { err "rm failed: $p"; return 1; }
}

load_module() {
  local module_file="$1"
  [[ -f "$module_file" ]] || { err "module not found: $module_file"; return 1; }
  unset MODULE_NAME MODULE_DESCRIPTION MODULE_RISK MODULE_CATEGORY
  unset MODULE_PATHS MODULE_COMMAND MODULE_AGE_DAYS MODULE_REQUIRES
  unset MODULE_REQUIRES_SUDO MODULE_NOTES
  MODULE_PATHS=()
  # shellcheck disable=SC1090
  . "$module_file" || { err "module failed to source: $module_file"; return 1; }
  [[ -n "${MODULE_NAME:-}" ]]        || { err "module $module_file: missing MODULE_NAME"; return 1; }
  [[ -n "${MODULE_DESCRIPTION:-}" ]] || { err "module $module_file: missing MODULE_DESCRIPTION"; return 1; }
  [[ -n "${MODULE_RISK:-}" ]]        || { err "module $module_file: missing MODULE_RISK"; return 1; }
  case "${MODULE_RISK}" in low|medium|high) ;; *) err "module $module_file: invalid MODULE_RISK '$MODULE_RISK'"; return 1 ;; esac
  if [[ "${#MODULE_PATHS[@]}" -eq 0 && -z "${MODULE_COMMAND:-}" ]]; then
    err "module $module_file: must set MODULE_PATHS or MODULE_COMMAND"
    return 1
  fi
  return 0
}

module_requirements_met() {
  [[ -z "${MODULE_REQUIRES:-}" ]] && return 0
  command -v "$MODULE_REQUIRES" >/dev/null 2>&1
}

emit_report() {
  printf '{'
  local first=1 kv k v
  for kv in "$@"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    [[ $first -eq 0 ]] && printf ','
    first=0
    case "$v" in
      ''|*[!0-9]*)
        v="${v//\\/\\\\}"
        v="${v//\"/\\\"}"
        printf '"%s":"%s"' "$k" "$v"
        ;;
      *) printf '"%s":%s' "$k" "$v" ;;
    esac
  done
  printf '}\n'
}

disk_free_bytes() {
  /bin/df -k / | awk 'NR==2 {print $4*1024}'
}

disk_used_pct() {
  /bin/df / | awk 'NR==2 {gsub("%","",$5); print $5}'
}
