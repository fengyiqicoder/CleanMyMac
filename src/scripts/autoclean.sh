#!/usr/bin/env bash
# autoclean.sh — master orchestrator with explicit SCAN-vs-CLEAN separation.
#
# Two distinct concepts:
#   SCAN   — one-shot, read-only, permission-agnostic. Reports every module classified as:
#              • auto_safe : low-risk caches/build artifacts (regenerable, no impact)
#              • review    : medium/high risk (you decide per-item)
#              • skipped   : sudo-required / TCC-denied / tool missing
#   CLEAN  — auto-cleans auto_safe in one shot; review tier is per-module interactive.
#
# Usage:
#   autoclean.sh                                # scan only, show 3-tier breakdown
#   autoclean.sh --execute --auto-safe --yes    # clean only auto-safe (recommended)
#   autoclean.sh --execute --review             # interactive per-item for medium/high risk
#   autoclean.sh --execute --all --yes          # both tiers in one go (>5GB gate applies)
#   autoclean.sh --json                         # raw JSON (scan only)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

EXECUTE=0
YES=0
WITH_SUDO=0
SCOPE_FILTER=""
NOTIFY_MODE=""
TIER=""
JSON_ONLY=0
GATE_GB=5

SCOPE_NEXT=0; NOTIFY_NEXT=0
for arg in "$@"; do
  if [[ "$SCOPE_NEXT"  -eq 1 ]]; then SCOPE_FILTER="$arg"; SCOPE_NEXT=0; continue; fi
  if [[ "$NOTIFY_NEXT" -eq 1 ]]; then NOTIFY_MODE="$arg"; NOTIFY_NEXT=0; continue; fi
  case "$arg" in
    --execute) EXECUTE=1 ;;
    --yes|-y) YES=1 ;;
    --with-sudo) WITH_SUDO=1 ;;
    --scope) SCOPE_NEXT=1 ;;
    --scope=*) SCOPE_FILTER="${arg#--scope=}" ;;
    --notify) NOTIFY_NEXT=1 ;;
    --notify=*) NOTIFY_MODE="${arg#--notify=}" ;;
    --auto-safe) TIER="auto_safe"; EXECUTE=1 ;;
    --review)    TIER="review"    ; EXECUTE=1 ;;
    --all)       TIER="all"       ; EXECUTE=1 ;;
    --json) JSON_ONLY=1 ;;
    --dry-run) export DRY_RUN=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) err "unknown arg: $arg"; exit 2 ;;
  esac
done

[[ $JSON_ONLY -eq 0 ]] && log "═══ STEP 1: SCAN (read-only) ═══"
SCAN_OUT="$(mktemp)"
scan_args=( --json )
[[ -n "$SCOPE_FILTER" ]] && scan_args+=( --scope "$SCOPE_FILTER" )
"$SCRIPT_DIR/scan.sh" "${scan_args[@]}" > "$SCAN_OUT" 2>/dev/null || true

if [[ $JSON_ONLY -eq 1 ]]; then
  cat "$SCAN_OUT"
  rm -f "$SCAN_OUT"
  exit 0
fi

SUMMARY="$(grep '"_summary"' "$SCAN_OUT" | head -1)"
extract_str() { echo "$SUMMARY" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }
extract_num() { echo "$SUMMARY" | sed -n "s/.*\"$1\":\([0-9]*\).*/\1/p" | head -1; }
AUTO_SAFE_BYTES=$(extract_num auto_safe_bytes); AUTO_SAFE_BYTES="${AUTO_SAFE_BYTES:-0}"
AUTO_SAFE_HUMAN=$(extract_str auto_safe_human); AUTO_SAFE_HUMAN="${AUTO_SAFE_HUMAN:-0 B}"
AUTO_SAFE_COUNT=$(extract_num auto_safe_count); AUTO_SAFE_COUNT="${AUTO_SAFE_COUNT:-0}"
REVIEW_BYTES=$(extract_num review_bytes); REVIEW_BYTES="${REVIEW_BYTES:-0}"
REVIEW_HUMAN=$(extract_str review_human); REVIEW_HUMAN="${REVIEW_HUMAN:-0 B}"
REVIEW_COUNT=$(extract_num review_count); REVIEW_COUNT="${REVIEW_COUNT:-0}"
SKIPPED_COUNT=$(extract_num skipped_count); SKIPPED_COUNT="${SKIPPED_COUNT:-0}"
DISK_FREE=$(extract_num disk_free); DISK_FREE="${DISK_FREE:-0}"

format_section() {
  local tier_label="$1"
  printf "\n  %-32s %-10s %-8s %s\n" "MODULE" "SIZE" "RISK" "WHAT IT IS / WHAT HAPPENS IF DELETED"
  printf "  %-32s %-10s %-8s %s\n" "------" "----" "----" "------------------------------------"
  grep "\"tier\":\"$tier_label\"" "$SCAN_OUT" | while IFS= read -r line; do
    name=$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
    human=$(echo "$line" | sed -n 's/.*"human":"\([^"]*\)".*/\1/p')
    risk=$(echo "$line" | sed -n 's/.*"risk":"\([^"]*\)".*/\1/p')
    desc=$(echo "$line" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')
    bytes=$(echo "$line" | sed -n 's/.*"bytes":\([0-9]*\).*/\1/p')
    bytes="${bytes:-0}"
    [[ "$bytes" -eq 0 ]] && continue
    short_name="${name:0:30}"
    short_desc="${desc:0:70}"
    printf "  %-32s %-10s %-8s %s\n" "$short_name" "$human" "$risk" "$short_desc"
  done
}

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                       MacAutoClean — SCAN RESULTS                            ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"

echo ""
echo "▼ AUTO-SAFE  ($AUTO_SAFE_COUNT modules, $AUTO_SAFE_HUMAN)  — caches & build artifacts, regenerable, no user impact"
format_section "auto_safe"

echo ""
echo "▼ NEEDS YOUR REVIEW  ($REVIEW_COUNT modules, $REVIEW_HUMAN)  — medium/high risk, decide per item"
if [[ "$REVIEW_COUNT" -eq 0 ]]; then
  echo "  (none)"
else
  format_section "review"
fi

echo ""
echo "▼ SKIPPED  ($SKIPPED_COUNT modules)  — need sudo or permission denied"
grep '"tier":"skipped"' "$SCAN_OUT" | while IFS= read -r line; do
  name=$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
  reason=$(echo "$line" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')
  module=$(echo "$line" | sed -n 's/.*"module":"\([^"]*\)".*/\1/p')
  printf "  %-32s %s\n" "${name:-$module}" "$reason"
done

echo ""
echo "──────────────────────────────────────────────────────────────────────────────"
TOTAL=$((AUTO_SAFE_BYTES + REVIEW_BYTES))
printf "  Total reclaimable: %-10s  |  Disk free now: %-10s\n" \
  "$(format_bytes "$TOTAL")" "$(format_bytes "$DISK_FREE")"
echo "──────────────────────────────────────────────────────────────────────────────"

if [[ $EXECUTE -ne 1 ]]; then
  echo ""
  echo "Next steps (choose one):"
  echo "  1. AUTO-CLEAN safe items (recommended, no impact):"
  echo "       $0 --auto-safe --yes"
  echo "  2. INTERACTIVE review of medium/high-risk items (one-by-one decision):"
  echo "       $0 --review"
  echo "  3. BOTH (auto-safe + interactive review):"
  echo "       $0 --all"
  echo ""
  rm -f "$SCAN_OUT"
  exit 0
fi

echo ""
log "═══ STEP 2: CLEAN (tier=$TIER) ═══"

need_gate=0
if [[ "$TIER" == "all" && $YES -ne 1 ]]; then need_gate=1; fi
if [[ "$TIER" == "auto_safe" && $YES -ne 1 ]]; then
  if [[ "$AUTO_SAFE_BYTES" -gt $((GATE_GB * 1024 * 1024 * 1024)) ]]; then need_gate=1; fi
fi
if [[ $need_gate -eq 1 ]]; then
  echo "About to clean $AUTO_SAFE_HUMAN auto-safe + $REVIEW_HUMAN review."
  echo "Pass --yes to skip this prompt."
  echo -n "Proceed? (yes/no): "
  read -r ans
  case "$ans" in y|yes|Y|YES) ;; *) log "Cancelled."; rm -f "$SCAN_OUT"; exit 1 ;; esac
fi

EXEC_OUT="$(mktemp)"

if [[ "$TIER" == "auto_safe" || "$TIER" == "all" ]]; then
  log "Running auto-safe modules ($AUTO_SAFE_COUNT modules)..."
  exec_args=( --yes --tier auto_safe )
  [[ -n "$SCOPE_FILTER" ]] && exec_args+=( --scope "$SCOPE_FILTER" )
  [[ "$WITH_SUDO" -eq 1 ]] && exec_args+=( --with-sudo )
  "$SCRIPT_DIR/execute.sh" "${exec_args[@]}" >> "$EXEC_OUT" 2>&1 || true
fi

if [[ "$TIER" == "review" || "$TIER" == "all" ]]; then
  if [[ "$REVIEW_COUNT" -eq 0 ]]; then
    log "No review-tier modules with data; skipping."
  else
    echo ""
    log "═══ Interactive review (medium/high risk) ═══"
    echo "For each module: [d]elete  [k]eep (skip)  [q]uit review"
    echo ""
    while IFS= read -r line; do
      name=$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
      human=$(echo "$line" | sed -n 's/.*"human":"\([^"]*\)".*/\1/p')
      risk=$(echo "$line" | sed -n 's/.*"risk":"\([^"]*\)".*/\1/p')
      desc=$(echo "$line" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')
      mod=$(echo "$line" | sed -n 's/.*"module":"\([^"]*\)".*/\1/p')
      bytes=$(echo "$line" | sed -n 's/.*"bytes":\([0-9]*\).*/\1/p')
      [[ "${bytes:-0}" -eq 0 ]] && continue

      echo "─────────────────────────────────────────────────────────────────────"
      echo "  $name  ($human, risk=$risk)"
      echo "  → $desc"
      echo -n "  [d]elete / [k]eep / [q]uit ? "
      read -r answer </dev/tty
      case "$answer" in
        d|D|delete)
          log "Deleting $mod..."
          "$SCRIPT_DIR/execute.sh" --yes --module "$mod" --tier all >> "$EXEC_OUT" 2>&1 || true
          ;;
        q|Q|quit) log "Review aborted by user."; break ;;
        *) log "Kept (skipped) $mod." ;;
      esac
    done < <(grep '"tier":"review"' "$SCAN_OUT")
  fi
fi

echo ""
log "═══ FINAL REPORT ═══"
TOTAL_FREED=$(grep '"_total"' "$EXEC_OUT" | sed -n 's/.*"bytes_freed":\([0-9]*\).*/\1/p' | head -1)
TOTAL_FREED="${TOTAL_FREED:-0}"
DISK_AFTER=$(disk_free_bytes)
log "Reclaimed: $(format_bytes "$TOTAL_FREED")"
log "Disk free: $(format_bytes "$DISK_FREE") → $(format_bytes "$DISK_AFTER")"

if [[ "$NOTIFY_MODE" == "notify" ]] && command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"Reclaimed $(format_bytes "$TOTAL_FREED")\" with title \"MacAutoClean\"" 2>/dev/null || true
fi

rm -f "$SCAN_OUT" "$EXEC_OUT"
exit 0
