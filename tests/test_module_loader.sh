#!/usr/bin/env bash
# Extra edge-case tests for the module loader.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export WHITELIST_FILE="$REPO/skills/macautoclean/references/whitelist.txt"
. "$REPO/skills/macautoclean/scripts/lib.sh"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  ✗ $1" >&2; }

TMP="$(mktemp -d)"

# 1. Missing file
if load_module "$TMP/missing.sh" 2>/dev/null; then bad "should reject missing file"; else ok; fi

# 2. Syntax error file
cat > "$TMP/syntax_err.sh" <<EOF
MODULE_NAME="x"
MODULE_DESCRIPTION="x"
MODULE_RISK="low
MODULE_PATHS=()
EOF
if load_module "$TMP/syntax_err.sh" 2>/dev/null; then bad "should reject syntax error"; else ok; fi

# 3. RISK case sensitivity (must be lowercase)
cat > "$TMP/upper_risk.sh" <<EOF
MODULE_NAME="x"
MODULE_DESCRIPTION="x"
MODULE_RISK="LOW"
MODULE_PATHS=("\$HOME/.cache/x")
EOF
if load_module "$TMP/upper_risk.sh" 2>/dev/null; then bad "should reject uppercase RISK"; else ok; fi

# 4. Command-only module is valid (empty PATHS but COMMAND present)
cat > "$TMP/cmd_only.sh" <<EOF
MODULE_NAME="x"
MODULE_DESCRIPTION="x"
MODULE_RISK="low"
MODULE_PATHS=()
MODULE_COMMAND="echo hello"
EOF
if load_module "$TMP/cmd_only.sh" 2>/dev/null; then ok; else bad "should accept command-only module"; fi

# 5. Multi-path module
cat > "$TMP/multi_path.sh" <<EOF
MODULE_NAME="multi"
MODULE_DESCRIPTION="x"
MODULE_RISK="low"
MODULE_PATHS=("\$HOME/a" "\$HOME/b" "\$HOME/c")
EOF
if load_module "$TMP/multi_path.sh" 2>/dev/null; then
  if [[ "${#MODULE_PATHS[@]}" -eq 3 ]]; then ok; else bad "expected 3 paths, got ${#MODULE_PATHS[@]}"; fi
else bad "multi-path module should load"; fi

# 6. State reset between loads
cat > "$TMP/has_age.sh" <<EOF
MODULE_NAME="aged"
MODULE_DESCRIPTION="x"
MODULE_RISK="low"
MODULE_PATHS=("\$HOME/x")
MODULE_AGE_DAYS=30
EOF
cat > "$TMP/no_age.sh" <<EOF
MODULE_NAME="not aged"
MODULE_DESCRIPTION="x"
MODULE_RISK="low"
MODULE_PATHS=("\$HOME/y")
EOF
load_module "$TMP/has_age.sh" >/dev/null 2>&1
[[ "${MODULE_AGE_DAYS:-0}" == "30" ]] || bad "AGE_DAYS should be 30 after has_age"
load_module "$TMP/no_age.sh" >/dev/null 2>&1
if [[ -z "${MODULE_AGE_DAYS:-}" || "${MODULE_AGE_DAYS:-0}" == "0" ]]; then ok
else bad "AGE_DAYS should reset (was leftover ${MODULE_AGE_DAYS:-})"; fi

rm -rf "$TMP"

echo "Module-loader edge tests: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
