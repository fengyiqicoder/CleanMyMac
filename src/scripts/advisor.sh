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

log "Smart Advisor — scanning for large/stale folders..."

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
  log "No advisor candidates found. Your large folders look reasonable."
  rm -f "$SORTED"
  exit 0
fi

echo ""
echo "Found $count candidates for review:"
echo ""
printf "  %-40s %-9s %-12s %-30s %s\n" "ITEM" "SIZE" "LAST USED" "RECOMMENDATION" "PATH"
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
  log "Re-run with --interactive to delete items one-by-one."
  rm -f "$SORTED"
  exit 0
fi

# --- Interactive mode ---
echo ""
echo "Interactive review — for each item: [d]elete, [k]eep, [s]kip, [q]uit"
echo ""

total_freed=0
while IFS=$'\t' read -r name path bytes last_access rec expl; do
  [[ -z "$name" ]] && continue
  [[ -e "$path" ]] || continue
  hum=$(format_bytes "$bytes")
  echo "── $name ──"
  echo "  Path:           $path"
  echo "  Size:           $hum"
  echo "  Last modified:  $last_access"
  echo "  Recommendation: $rec"
  echo "  $expl"
  echo -n "  > [d/k/s/q]: "
  read -r choice </dev/tty
  case "$choice" in
    d|D)
      if is_whitelisted "$path"; then
        if safe_rm "$path"; then
          total_freed=$((total_freed + bytes))
          echo "  ✓ Deleted: $hum freed"
        else
          echo "  ✗ Delete failed (see log)"
        fi
      else
        echo "  ⚠  Path outside whitelist. Refusing to delete from advisor."
        echo "     To remove manually: rm -rf \"$path\"  (verify carefully first)"
      fi
      ;;
    s|S) echo "  Skipped." ;;
    q|Q) echo "  Exiting."; break ;;
    *)   echo "  Kept." ;;
  esac
  echo ""
done < "$SORTED"

log "Advisor session complete. Total freed: $(format_bytes "$total_freed")"
rm -f "$SORTED"
