#!/usr/bin/env bash
# Tests for lib.sh — pure bash, no test framework. Exit 0 on PASS.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
. "$REPO/skills/macautoclean/scripts/lib.sh"

PASS=0; FAIL=0
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); echo "  ✗ $label: expected [$expected], got [$actual]" >&2; fi
}
assert_true() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); echo "  ✗ $label: [$*] returned non-zero" >&2; fi
}
assert_false() {
  local label="$1"; shift
  if ! "$@" >/dev/null 2>&1; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); echo "  ✗ $label: [$*] returned zero" >&2; fi
}

# ---- format_bytes ----
assert_eq "format_bytes 0"        "0 B"     "$(format_bytes 0)"
assert_eq "format_bytes 1024"     "1.0 KB"  "$(format_bytes 1024)"
assert_eq "format_bytes 1572864"  "1.5 MB"  "$(format_bytes 1572864)"
assert_eq "format_bytes 2GB"      "2.0 GB"  "$(format_bytes $((2*1024*1024*1024)))"

# ---- is_whitelisted ----
TMP_WL="$(mktemp)"
printf '%s\n' "$HOME/Library/Caches" "$HOME/.npm/_cacache" >"$TMP_WL"
WHITELIST_FILE="$TMP_WL"
assert_true  "wl allows ~/Library/Caches/foo"  is_whitelisted "$HOME/Library/Caches/foo"
assert_true  "wl allows ~/.npm/_cacache/bar"   is_whitelisted "$HOME/.npm/_cacache/bar"
assert_false "wl rejects ~/Documents/secret"   is_whitelisted "$HOME/Documents/secret"
assert_false "wl rejects /etc/hosts"           is_whitelisted "/etc/hosts"
assert_false "wl rejects empty"                is_whitelisted ""
rm -f "$TMP_WL"

# ---- safe_rm ----
TMP_WL="$(mktemp)"
SAFE_TEST_DIR="${TMPDIR%/}/macautoclean_safe_rm_test"
echo "$SAFE_TEST_DIR" >"$TMP_WL"
WHITELIST_FILE="$TMP_WL"
mkdir -p "$SAFE_TEST_DIR"
echo "hi" >"$SAFE_TEST_DIR/file.txt"

assert_false "safe_rm refuses /"           safe_rm "/"
assert_false "safe_rm refuses non-listed"  safe_rm "$HOME/Documents/x"
assert_true  "safe_rm deletes whitelisted" safe_rm "$SAFE_TEST_DIR/file.txt"
if [[ ! -e "$SAFE_TEST_DIR/file.txt" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ file still exists" >&2; fi

echo "x" >"$SAFE_TEST_DIR/file2.txt"
DRY_RUN=1 safe_rm "$SAFE_TEST_DIR/file2.txt" >/dev/null 2>&1 || true
if [[ -e "$SAFE_TEST_DIR/file2.txt" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  ✗ DRY_RUN deleted" >&2; fi
DRY_RUN=0
rm -rf "$SAFE_TEST_DIR" "$TMP_WL"

# ---- load_module ----
TMP_MOD="$(mktemp -d)"
cat >"$TMP_MOD/good.sh" <<'EOF'
MODULE_NAME="Test Module"
MODULE_DESCRIPTION="testing"
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/.cache/test")
EOF
cat >"$TMP_MOD/missing_name.sh" <<'EOF'
MODULE_DESCRIPTION="x"; MODULE_RISK="low"; MODULE_PATHS=("$HOME/x")
EOF
cat >"$TMP_MOD/bad_risk.sh" <<'EOF'
MODULE_NAME="x"; MODULE_DESCRIPTION="x"; MODULE_RISK="extreme"; MODULE_PATHS=("$HOME/x")
EOF
cat >"$TMP_MOD/no_paths_or_cmd.sh" <<'EOF'
MODULE_NAME="x"; MODULE_DESCRIPTION="x"; MODULE_RISK="low"
EOF

assert_true  "load_module: well-formed"        load_module "$TMP_MOD/good.sh"
assert_eq    "MODULE_NAME loaded"              "Test Module" "$MODULE_NAME"
assert_false "load_module: missing NAME"       load_module "$TMP_MOD/missing_name.sh"
assert_false "load_module: bad RISK"           load_module "$TMP_MOD/bad_risk.sh"
assert_false "load_module: no paths or cmd"    load_module "$TMP_MOD/no_paths_or_cmd.sh"
rm -rf "$TMP_MOD"

# ---- emit_report ----
out=$(emit_report category=test bytes=1024 note="hello world")
assert_eq "emit_report shape" '{"category":"test","bytes":1024,"note":"hello world"}' "$out"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
