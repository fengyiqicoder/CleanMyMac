#!/usr/bin/env bash
# Tests for i18n — verifies:
#   1. Language detection from CLEAN_MY_MAC_LANG (priority) and $LANG (fallback)
#   2. tr() / i18n() returns key verbatim when no translation
#   3. Every i18n key referenced in scripts has a zh translation
#   4. The old `tr` shadow bug doesn't reappear (function must be named i18n)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPTS="$REPO/skills/cleanmymac/scripts"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  ✗ $1" >&2; }
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && ok || bad "$label: expected [$expected], got [$actual]"
}

# ---- 1. Language detection ----

# CLEAN_MY_MAC_LANG=zh forces Chinese regardless of $LANG
(
  unset MAC_LANG
  export CLEAN_MY_MAC_LANG=zh LANG=en_US.UTF-8
  . "$SCRIPTS/lib.sh"
  [[ "$MAC_LANG" == "zh" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "CLEAN_MY_MAC_LANG=zh should force zh"

# CLEAN_MY_MAC_LANG unset → falls through to LANG
(
  unset MAC_LANG CLEAN_MY_MAC_LANG
  export LANG=zh_CN.UTF-8
  . "$SCRIPTS/lib.sh"
  [[ "$MAC_LANG" == "zh" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "\$LANG=zh_CN should select zh"

# Neither set → defaults to en
(
  unset MAC_LANG CLEAN_MY_MAC_LANG LANG LC_ALL LC_CTYPE
  . "$SCRIPTS/lib.sh"
  [[ "$MAC_LANG" == "en" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "no locale should default to en"

# Explicit CLEAN_MY_MAC_LANG=en wins over zh-locale
(
  unset MAC_LANG
  export CLEAN_MY_MAC_LANG=en LANG=zh_CN.UTF-8
  . "$SCRIPTS/lib.sh"
  [[ "$MAC_LANG" == "en" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "CLEAN_MY_MAC_LANG=en should override zh-locale"

# ---- 2. i18n() basics ----

(
  unset MAC_LANG; export CLEAN_MY_MAC_LANG=en
  . "$SCRIPTS/lib.sh"
  out=$(i18n "Disk map")
  [[ "$out" == "Disk map" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "en: i18n returns English key verbatim"

(
  unset MAC_LANG; export CLEAN_MY_MAC_LANG=zh
  . "$SCRIPTS/lib.sh"
  out=$(i18n "Disk map")
  [[ "$out" == "磁盘地图" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "zh: 'Disk map' should translate to 磁盘地图"

# Unknown key → falls back to itself
(
  unset MAC_LANG; export CLEAN_MY_MAC_LANG=zh
  . "$SCRIPTS/lib.sh"
  out=$(i18n "completely-fabricated-key-12345")
  [[ "$out" == "completely-fabricated-key-12345" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "zh: unknown key should fall back to itself"

# ---- 3. Dictionary coverage: every $(i18n "...") key in scripts must have a zh entry ----

(
  unset MAC_LANG; export CLEAN_MY_MAC_LANG=zh
  . "$SCRIPTS/lib.sh"

  # Extract every literal passed to i18n in any script.
  # Pattern: $(i18n 'KEY') or $(i18n "KEY")
  missing=0
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    translated=$(i18n "$key")
    if [[ "$translated" == "$key" ]]; then
      printf "    (untranslated): %s\n" "$key" >&2
      missing=$((missing+1))
    fi
  done < <(
    grep -rhoE '\$\(i18n '\''[^'\'']+'\''' "$SCRIPTS" 2>/dev/null \
      | sed -E "s/^\\\$\\(i18n '(.*)'\$/\\1/" \
      | sort -u
    # also handle double-quoted (rare — autoclean format-section)
    grep -rhoE '\$\(i18n "[^"]+"\)' "$SCRIPTS" 2>/dev/null \
      | sed -E 's/^\$\(i18n "(.*)"\)$/\1/' \
      | sort -u
  )
  exit "$missing"
)
n_missing=$?
[[ "$n_missing" -eq 0 ]] && ok || bad "$n_missing key(s) referenced in scripts have no zh translation"

# ---- 4. Function is named i18n, not tr (shadow-bug regression) ----

(
  . "$SCRIPTS/lib.sh"
  # System `tr` must still work — verifies our function is NOT called `tr`.
  out=$(echo "hello world" | tr -d ' ')
  [[ "$out" == "helloworld" ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "system tr command must not be shadowed (function should be named i18n)"

# ---- 5. format-string keys preserve %s placeholders ----

(
  unset MAC_LANG; export CLEAN_MY_MAC_LANG=zh
  . "$SCRIPTS/lib.sh"
  fmt=$(i18n "About to clean %s auto-safe + %s review.")
  # Translated string must still contain two %s placeholders
  count=$(printf '%s' "$fmt" | grep -o '%s' | wc -l | tr -d ' ')
  [[ "$count" -eq 2 ]] || exit 1
  # And printf must successfully expand them
  rendered=$(printf "$fmt" "1.0 GB" "500 MB")
  [[ "$rendered" == *"1.0 GB"* && "$rendered" == *"500 MB"* ]] || exit 1
)
[[ $? -eq 0 ]] && ok || bad "zh format strings must preserve %s placeholders"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
