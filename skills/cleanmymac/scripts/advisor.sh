#!/usr/bin/env bash
# advisor.sh — Smart Advisor: surface large/stale folders the user might want to delete.
# Each src/advisor-heuristics/*.sh defines a discover() function emitting TSV:
#   name<TAB>path<TAB>bytes<TAB>last_access<TAB>recommendation<TAB>explanation
#
# Usage:
#   advisor.sh                 # scan + print table
#   advisor.sh --interactive   # ask per-row [d]elete / [k]eep / [s]kip / [q]uit
#   advisor.sh --json          # emit raw JSON lines instead of human table

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

INTERACTIVE=0
JSON=0
for arg in "$@"; do
  case "$arg" in
    --interactive|-i) INTERACTIVE=1 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) err "unknown arg: $arg"; exit 2 ;;
  esac
done

log "$(i18n 'Smart Advisor — scanning for large/stale folders...')"

# Collect all TSV rows
TSV="$(mktemp)"
shopt -s nullglob
for h_file in "$HEURISTICS_DIR"/*.sh; do
  base="$(basename "$h_file")"
  case "$base" in _*) continue ;; esac
  # Load heuristic in subshell so HEURISTIC_NAME etc. don't leak between runs.
  ( . "$h_file" && declare -f discover >/dev/null && discover ) >> "$TSV" 2>/dev/null || true
done

# Sort by bytes desc (column 3)
SORTED="$(mktemp)"
sort -t$'\t' -k3 -n -r "$TSV" > "$SORTED"
rm -f "$TSV"

count=$(wc -l < "$SORTED" | tr -d ' ')

if [[ "$JSON" -eq 1 ]]; then
  while IFS=$'\t' read -r name path bytes last_access rec expl; do
    [[ -z "$name" ]] && continue
    emit_report name="$name" path="$path" bytes="$bytes" human="$(format_bytes "$bytes")" last_access="$last_access" recommendation="$rec" explanation="$expl"
  done < "$SORTED"
  rm -f "$SORTED"
  exit 0
fi

if [[ "$count" -eq 0 ]]; then
  log "$(i18n 'No advisor candidates found. Your large folders look reasonable.')"
  rm -f "$SORTED"
  exit 0
fi

echo ""
printf "$(i18n 'Found %d candidates for review:')\n" "$count"
echo ""
printf "  %-40s %-9s %-12s %-30s %s\n" \
  "$(i18n 'ITEM')" "$(i18n 'SIZE')" "$(i18n 'LAST USED')" "$(i18n 'RECOMMENDATION')" "$(i18n 'PATH')"
printf "  %-40s %-9s %-12s %-30s %s\n" "----" "----" "---------" "--------------" "----"
idx=0
while IFS=$'\t' read -r name path bytes last_access rec expl; do
  [[ -z "$name" ]] && continue
  idx=$((idx+1))
  hum=$(format_bytes "$bytes")
  printf "  %-40.40s %-9s %-12s %-30.30s %s\n" "$name" "$hum" "$last_access" "$rec" "$path"
done < "$SORTED"
echo ""

if [[ "$INTERACTIVE" -eq 0 ]]; then
  log "$(i18n 'Re-run with --interactive to delete items one-by-one.')"
  rm -f "$SORTED"
  exit 0
fi

# --- Interactive mode ---
echo ""
echo "$(i18n 'Interactive review — for each item: [d]elete, [k]eep, [s]kip, [q]uit')"
echo ""

total_freed=0
while IFS=$'\t' read -r name path bytes last_access rec expl; do
  [[ -z "$name" ]] && continue
  [[ -e "$path" ]] || continue
  hum=$(format_bytes "$bytes")
  echo "── $name ──"
  printf "  %-16s%s\n" "$(i18n 'Path:')"          "$path"
  printf "  %-16s%s\n" "$(i18n 'Size:')"          "$hum"
  printf "  %-16s%s\n" "$(i18n 'Last modified:')" "$last_access"
  printf "  %-16s%s\n" "$(i18n 'Recommendation:')" "$rec"
  echo "  $expl"
  printf "%s" "$(i18n '  > [d/k/s/q]: ')"
  read -r choice </dev/tty
  case "$choice" in
    d|D)
      if is_whitelisted "$path"; then
        if safe_rm "$path"; then
          total_freed=$((total_freed + bytes))
          printf "$(i18n '  ✓ Deleted: %s freed')\n" "$hum"
        else
          echo "$(i18n '  ✗ Delete failed (see log)')"
        fi
      else
        echo "$(i18n '  ⚠  Path outside whitelist. Refusing to delete from advisor.')"
        printf "$(i18n '     To remove manually: rm -rf "%s"  (verify carefully first)')\n" "$path"
      fi
      ;;
    s|S) echo "$(i18n '  Skipped.')" ;;
    q|Q) echo "$(i18n '  Exiting.')"; break ;;
    *)   echo "$(i18n '  Kept.')" ;;
  esac
  echo ""
done < "$SORTED"

log "$(printf "$(i18n 'Advisor session complete. Total freed: %s')" "$(format_bytes "$total_freed")")"
rm -f "$SORTED"
