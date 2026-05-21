#!/usr/bin/env bash
# autoclean.sh — master orchestrator for MacAutoClean.
#
# Usage:
#   autoclean.sh                              # scan only
#   autoclean.sh --execute                    # scan, then interactive prompt + execute
#   autoclean.sh --execute --yes              # skip prompt (used by SKILL.md after conversational consent)
#   autoclean.sh --execute --yes --scope dev,browser
#   autoclean.sh --execute --yes --with-sudo  # also run sudo-required modules
#   autoclean.sh --execute --dry-run --yes    # rehearsal
#   autoclean.sh --notify silent|notify|claude

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

EXECUTE=0
YES=0
SCOPE_FILTER=""
WITH_SUDO=0
NOTIFY_MODE=""
SCOPE_NEXT=0
NOTIFY_NEXT=0

GATE_GB=5  # confirmation gate (GB) when reclaim exceeds this and --yes not set

usage() {
  sed -n '2,12p' "$0"
}

for arg in "$@"; do
  if [[ "$SCOPE_NEXT" -eq 1 ]]; then SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue; fi
  if [[ "$NOTIFY_NEXT" -eq 1 ]]; then NOTIFY_MODE="$arg"; NOTIFY_NEXT=0; continue; fi
  case "$arg" in
    --execute) EXECUTE=1 ;;
    --yes|-y) YES=1 ;;
    --scope) SCOPE_NEXT=1 ;;
    --scope=*) SCOPE_FILTER="${arg#--scope=}" ;;
    --with-sudo) WITH_SUDO=1 ;;
    --dry-run) export DRY_RUN=1 ;;
    --notify) NOTIFY_NEXT=1 ;;
    --notify=*) NOTIFY_MODE="${arg#--notify=}" ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown arg: $arg"; usage; exit 2 ;;
  esac
done

# ---- Step 1: scan ----
log "═══ STEP 1: SCAN ═══"
SCAN_OUT="$(mktemp)"
scan_args=()
[[ -n "$SCOPE_FILTER" ]] && scan_args+=( --scope "$SCOPE_FILTER" )
scan_args+=( --json )
"$SCRIPT_DIR/scan.sh" "${scan_args[@]}" > "$SCAN_OUT"

# Pull total bytes from _summary line. We don't depend on jq.
TOTAL_BYTES="$(awk -F'"bytes_total":' '/"_summary"/{split($2, a, ","); gsub(/[^0-9]/, "", a[1]); print a[1]; exit}' "$SCAN_OUT")"
TOTAL_BYTES="${TOTAL_BYTES:-0}"
TOTAL_HUMAN="$(format_bytes "$TOTAL_BYTES")"
DISK_FREE="$(disk_free_bytes)"
DISK_PCT="$(disk_used_pct)"

# Human-friendly summary table (one row per module with bytes > 0).
echo ""
printf "  %-32s %-9s %-7s %s\n" "MODULE" "SIZE" "RISK" "NOTE"
printf "  %-32s %-9s %-7s %s\n" "------" "----" "----" "----"
awk -F'[:,]' '
  /"module":/ {
    mod=""; nm=""; ris=""; hum=""; req=""
    for (i=1; i<=NF; i++) {
      if ($i ~ /"name"/)         { gsub(/[ "]+/, "", $(i+1)); nm=$(i+1); }
      if ($i ~ /"risk"/)         { gsub(/[ "]+/, "", $(i+1)); ris=$(i+1); }
      if ($i ~ /"human"/)        { gsub(/[ "]+/, "", $(i+1)); hum=$(i+1); }
      if ($i ~ /"requires_sudo"/){ gsub(/[ "]+/, "", $(i+1)); req=$(i+1); }
      if ($i ~ /"module"/)       { gsub(/[ "]+/, "", $(i+1)); mod=$(i+1); }
    }
    if (mod ~ /^_/) next
    if (hum == "" || hum == "0B") next
    if (nm == "")  nm = mod
    note = (req == "1") ? "(sudo)" : ""
    printf "  %-32.32s %-9s %-7s %s\n", nm, hum, ris, note
  }
' "$SCAN_OUT"
echo ""
log "Total reclaimable: $TOTAL_HUMAN | Disk free: $(format_bytes "$DISK_FREE") | Used: ${DISK_PCT}%"

if [[ "$EXECUTE" != "1" ]]; then
  log "Scan complete. Use --execute to reclaim."
  rm -f "$SCAN_OUT"
  exit 0
fi

# ---- Confirmation gate ----
GATE_BYTES=$((GATE_GB * 1024 * 1024 * 1024))
if [[ "$YES" != "1" && "$TOTAL_BYTES" -gt "$GATE_BYTES" ]]; then
  log "⚠  Scan projects > ${GATE_GB} GB reclaim. Confirm to proceed."
  echo -n "Proceed? [yes/no] " >&2
  read -r confirm
  case "$confirm" in y|yes|Y|YES) ;; *) log "Aborted by user."; rm -f "$SCAN_OUT"; exit 0 ;; esac
fi

# ---- Step 2: execute ----
log "═══ STEP 2: EXECUTE ═══"
exec_args=( --yes )
[[ -n "$SCOPE_FILTER" ]] && exec_args+=( --scope "$SCOPE_FILTER" )
[[ "$WITH_SUDO" -eq 1 ]] && exec_args+=( --with-sudo )
[[ "${DRY_RUN:-0}" == "1" ]] && exec_args+=( --dry-run )

EXEC_OUT="$(mktemp)"
"$SCRIPT_DIR/execute.sh" "${exec_args[@]}" > "$EXEC_OUT"

TOTAL_FREED="$(awk -F'"bytes_freed":' '/"_total"/{split($2, a, ","); gsub(/[^0-9]/, "", a[1]); print a[1]; exit}' "$EXEC_OUT")"
TOTAL_FREED="${TOTAL_FREED:-0}"

echo ""
log "═══ DONE ═══"
log "Reclaimed: $(format_bytes "$TOTAL_FREED")"
log "Disk free now: $(format_bytes "$(disk_free_bytes)") (was $(format_bytes "$DISK_FREE"))"
log "Used now: $(disk_used_pct)% (was ${DISK_PCT}%)"

# ---- Notification ----
case "$NOTIFY_MODE" in
  notify|silent_notify|claude)
    if [[ -x "$SCRIPT_DIR/notify.sh" ]]; then
      "$SCRIPT_DIR/notify.sh" "MacAutoClean reclaimed $(format_bytes "$TOTAL_FREED")" "Disk free: $(format_bytes "$(disk_free_bytes)")" || true
    fi
    ;;
esac

rm -f "$SCAN_OUT" "$EXEC_OUT"
