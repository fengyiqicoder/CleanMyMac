#!/usr/bin/env bash
# diskmap.sh — full-disk tree-walk scanner with module-based annotation.
# Usage:
#   diskmap.sh                       # scan $HOME, top 30
#   diskmap.sh /Users/fengyq         # drill into a specific path
#   diskmap.sh / --top 20            # full-disk view (TCC may deny some)
#   diskmap.sh --depth 2 ~/Library   # show 2 levels deep
#   diskmap.sh --json                # JSON output for Claude
#
# How it works:
#   1. du -sk on each immediate child of START path (one level deep)
#   2. For each child, lookup its path against the registry
#      (51 modules + hardcoded never-touch list = ground truth for classification)
#   3. Annotate each row with tier (auto_safe / review / never_touch / unknown)
#   4. Sort by size desc, print
#
# Permission denials are silently captured and surfaced as the well-known
# "need permission to fully scan" line (à la OmniDiskSweeper).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
. "$SCRIPT_DIR/lib-registry.sh"

START="$HOME"
DEPTH=1
TOP=30
JSON=0
SHOW_KNOWN_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth) DEPTH="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --known-only) SHOW_KNOWN_ONLY=1; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    -*) err "unknown flag: $1"; exit 2 ;;
    *) START="$1"; shift ;;
  esac
done

# Resolve absolute path
START="$(cd "$START" 2>/dev/null && pwd)" || { err "cannot enter $START"; exit 1; }

build_registry

# Gather one-level children via du. Capture stderr to detect permission denials.
TMP_OUT="$(mktemp)"
TMP_ERR="$(mktemp)"
# du -d 1 prints directory totals one level deep, including the parent on the last line.
/usr/bin/du -sk "$START"/* "$START"/.[!.]* 2>"$TMP_ERR" | sort -rn > "$TMP_OUT" || true

PERM_DENIED=0
if grep -qi "permission denied\|operation not permitted" "$TMP_ERR" 2>/dev/null; then
  PERM_DENIED=1
fi

# Pre-walk: aggregate totals per tier so we can show a summary at the end
TOTAL_AUTO_SAFE=0
TOTAL_REVIEW=0
TOTAL_NEVER=0
TOTAL_UNKNOWN=0
SUM_BYTES=0
ROW_COUNT=0

# Build display rows in a temp file (we'll print after totals are known)
TMP_ROWS="$(mktemp)"
TMP_JSON="$(mktemp)"

while IFS=$'\t' read -r kb path; do
  [[ -z "$path" ]] && continue
  [[ -z "$kb" ]] && continue
  bytes=$((kb * 1024))
  ROW_COUNT=$((ROW_COUNT+1))
  SUM_BYTES=$((SUM_BYTES+bytes))

  lookup=$(lookup_path "$path")
  tier="${lookup%%|*}"; rest="${lookup#*|}"
  module="${rest%%|*}"; rest="${rest#*|}"
  risk="${rest%%|*}"; desc="${rest#*|}"

  case "$tier" in
    auto_safe)  TOTAL_AUTO_SAFE=$((TOTAL_AUTO_SAFE+bytes)); icon="✅" ;;
    review)     TOTAL_REVIEW=$((TOTAL_REVIEW+bytes));       icon="⚠️ " ;;
    never_touch) TOTAL_NEVER=$((TOTAL_NEVER+bytes));        icon="🔒" ;;
    *)          TOTAL_UNKNOWN=$((TOTAL_UNKNOWN+bytes));     icon="❓" ;;
  esac

  if [[ "$SHOW_KNOWN_ONLY" -eq 1 && "$tier" == "unknown" ]]; then continue; fi
  [[ "$ROW_COUNT" -gt "$TOP" ]] && continue

  human="$(format_bytes "$bytes")"
  short_path="${path##*/}"
  short_desc="${desc:0:60}"
  printf "  %s  %-10s  %-32s  %-12s  %s\n" "$icon" "$human" "${short_path:0:32}" "$tier" "$short_desc" >> "$TMP_ROWS"

  # JSON
  json_path="${path//\\/\\\\}"; json_path="${json_path//\"/\\\"}"
  json_desc="${desc//\\/\\\\}"; json_desc="${json_desc//\"/\\\"}"
  printf '{"path":"%s","bytes":%d,"human":"%s","tier":"%s","module":"%s","risk":"%s","description":"%s"}\n' \
    "$json_path" "$bytes" "$human" "$tier" "$module" "$risk" "$json_desc" >> "$TMP_JSON"
done < "$TMP_OUT"

if [[ "$JSON" -eq 1 ]]; then
  cat "$TMP_JSON"
  # JSON summary
  printf '{"_summary":1,"path":"%s","sum_bytes":%d,"auto_safe":%d,"review":%d,"never_touch":%d,"unknown":%d,"row_count":%d,"perm_denied":%d}\n' \
    "$START" "$SUM_BYTES" "$TOTAL_AUTO_SAFE" "$TOTAL_REVIEW" "$TOTAL_NEVER" "$TOTAL_UNKNOWN" "$ROW_COUNT" "$PERM_DENIED"
  rm -f "$TMP_OUT" "$TMP_ERR" "$TMP_ROWS" "$TMP_JSON"
  exit 0
fi

# Human output
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
printf "║  Disk map: %-66s║\n" "$START"
if [[ "$PERM_DENIED" -eq 1 ]]; then
  printf "║  ⚠️  some entries denied by macOS — true size ≥ %-30s║\n" "$(format_bytes "$SUM_BYTES")"
fi
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
printf "  %s  %-10s  %-32s  %-12s  %s\n" " " "SIZE" "NAME" "TIER" "WHAT IT IS"
printf "  %s  %-10s  %-32s  %-12s  %s\n" " " "----" "----" "----" "----------"
cat "$TMP_ROWS"

echo ""
echo "──────────────────────────────────────────────────────────────────────────────"
printf "  ✅ AUTO-SAFE total:    %-12s  → safe to delete (regenerable)\n"     "$(format_bytes "$TOTAL_AUTO_SAFE")"
printf "  ⚠️  REVIEW total:       %-12s  → decide per-item\n"                  "$(format_bytes "$TOTAL_REVIEW")"
printf "  🔒 NEVER-TOUCH total:  %-12s  → protected user/system data\n"        "$(format_bytes "$TOTAL_NEVER")"
printf "  ❓ UNKNOWN total:      %-12s  → no rule yet; drill deeper or inspect\n" "$(format_bytes "$TOTAL_UNKNOWN")"
echo "──────────────────────────────────────────────────────────────────────────────"
echo ""
echo "Tip: drill into any folder by passing its path:"
echo "       $0 <path>"
echo ""

rm -f "$TMP_OUT" "$TMP_ERR" "$TMP_ROWS" "$TMP_JSON"
exit 0
