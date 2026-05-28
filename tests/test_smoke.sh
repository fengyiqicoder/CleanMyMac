#!/usr/bin/env bash
# End-to-end smoke test. Verifies the full skill works without modifying protected paths.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPTS="$REPO/skills/cleanmymac/scripts"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1" >&2; }

# 1. shellcheck all scripts (if installed)
if command -v shellcheck >/dev/null 2>&1; then
  for s in "$REPO"/install.sh "$REPO"/uninstall.sh "$SCRIPTS"/*.sh; do
    if shellcheck -e SC1091,SC2034,SC2154,SC2068,SC2086,SC2128,SC2207 "$s" >/dev/null 2>&1; then :
    else bad "shellcheck: $(basename "$s")"; continue; fi
  done
  ok "shellcheck passes"
else
  echo "  (shellcheck not installed — skipping)"
fi

# 2. Scan produces JSON-lines
SCAN_OUT="$(mktemp)"
"$SCRIPTS/scan.sh" --json >"$SCAN_OUT" 2>/dev/null
if head -1 "$SCAN_OUT" | grep -q '^{.*}$'; then ok "scan.sh emits JSON-lines"
else bad "scan.sh JSON output invalid"; fi
rm -f "$SCAN_OUT"

# 3. Scan summary parses
SUM="$("$SCRIPTS/scan.sh" --json 2>/dev/null | grep _summary | head -1)"
if echo "$SUM" | grep -q '"bytes_total"'; then ok "scan summary present"
else bad "scan summary missing"; fi

# 4. Dry-run execute does not modify Documents/Desktop/Pictures/iCloud mtime
SNAPSHOT_BEFORE=""
for d in "$HOME/Documents" "$HOME/Desktop" "$HOME/Pictures" "$HOME/Library/Mobile Documents"; do
  [[ -e "$d" ]] && SNAPSHOT_BEFORE+="$(stat -f '%m' "$d" 2>/dev/null || echo 0):"
done
"$SCRIPTS/autoclean.sh" --execute --dry-run --yes >/dev/null 2>&1 || true
SNAPSHOT_AFTER=""
for d in "$HOME/Documents" "$HOME/Desktop" "$HOME/Pictures" "$HOME/Library/Mobile Documents"; do
  [[ -e "$d" ]] && SNAPSHOT_AFTER+="$(stat -f '%m' "$d" 2>/dev/null || echo 0):"
done
if [[ "$SNAPSHOT_BEFORE" == "$SNAPSHOT_AFTER" ]]; then
  ok "dry-run did not modify protected dirs"
else
  bad "dry-run modified mtime of protected dir (before=$SNAPSHOT_BEFORE after=$SNAPSHOT_AFTER)"
fi

# 5. Advisor runs without error (output may be empty on clean systems)
if "$SCRIPTS/advisor.sh" --json >/dev/null 2>&1; then
  ok "advisor.sh runs cleanly"
else bad "advisor.sh failed"; fi

# 6. schedule.sh --dry-run produces a plutil-valid plist
TMP_OUT="$(mktemp)"
if "$SCRIPTS/schedule.sh" --preset weekly --dry-run >"$TMP_OUT" 2>&1; then
  # Strip leading menu line and extract plist starting from <?xml
  if grep -q "<?xml" "$TMP_OUT"; then
    PLIST_TMP="$(mktemp)"
    sed -n '/<?xml/,$p' "$TMP_OUT" > "$PLIST_TMP"
    if /usr/bin/plutil -lint "$PLIST_TMP" >/dev/null 2>&1; then
      ok "schedule.sh produces plutil-valid plist"
    else
      bad "rendered plist failed plutil -lint"
    fi
    rm -f "$PLIST_TMP"
  else
    bad "schedule.sh dry-run produced no plist"
  fi
else
  bad "schedule.sh --dry-run failed"
fi
rm -f "$TMP_OUT"

# 7. Cookies path is rejected (regression test for browser safety)
. "$SCRIPTS/lib.sh"
WHITELIST_FILE="$REPO/skills/cleanmymac/references/whitelist.txt"
if is_whitelisted "$HOME/Library/Application Support/Google/Chrome/Default/Cookies"; then
  bad "Chrome Cookies path should be rejected"
else
  ok "Chrome Cookies path rejected"
fi

echo ""
echo "Smoke test: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
