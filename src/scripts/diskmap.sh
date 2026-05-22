#!/usr/bin/env bash
# diskmap.sh — deep auto-drill disk scanner.
#
# Walks the file tree from START. For every folder >= THRESHOLD (default 2 GB),
# classifies into one of THREE actionable buckets — no "unknown" tier shown:
#
#   ✅ auto_safe    — caches and build artifacts (registry match OR cache-name heuristic)
#   ⚠️ review      — anything else (registry match OR heuristic for app data / sandbox / backup / generic)
#   🔒 never_touch — Photos / Documents / iCloud / Mail / Keychain / etc.
#
# Drills unknown subtrees down to LEAVES (no big sub-children) so that what
# the user sees is at the most-specific-classifiable level (e.g.,
# `~/Library/Application Support/Notion` instead of just `~/Library`).
#
# Usage:
#   diskmap.sh                      # scan $HOME, threshold 2 GB
#   diskmap.sh /                    # full disk
#   diskmap.sh --threshold 500M     # show anything >= 500 MB
#   diskmap.sh ~/Library            # drill into a specific subtree
#   diskmap.sh --json               # JSON output

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
. "$SCRIPT_DIR/lib-registry.sh"

START="$HOME"
THRESHOLD_RAW="2G"
JSON=0
HIDE_NEVER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD_RAW="$2"; shift 2 ;;
    --threshold=*) THRESHOLD_RAW="${1#--threshold=}"; shift ;;
    --json) JSON=1; shift ;;
    --hide-never) HIDE_NEVER=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) err "unknown flag: $1"; exit 2 ;;
    *) START="$1"; shift ;;
  esac
done

to_kb() {
  local v="$1"
  case "$v" in
    *G|*g) echo $(( ${v%[Gg]} * 1024 * 1024 )) ;;
    *M|*m) echo $(( ${v%[Mm]} * 1024 )) ;;
    *K|*k) echo $(( ${v%[Kk]} )) ;;
    *)     echo "$v" ;;
  esac
}
THRESHOLD_KB="$(to_kb "$THRESHOLD_RAW")"

START="$(cd "$START" 2>/dev/null && pwd)" || { err "cannot enter $START"; exit 1; }

build_registry

REG_FILE="$(mktemp)"
i=0
while [[ $i -lt ${#REGISTRY_PATH[@]} ]]; do
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "${REGISTRY_PATH[$i]}" \
    "${REGISTRY_TIER[$i]}" \
    "${REGISTRY_MODULE[$i]}" \
    "${REGISTRY_RISK[$i]}" \
    "${REGISTRY_DESC[$i]}" \
    >> "$REG_FILE"
  i=$((i+1))
done

DU_FILE="$(mktemp)"
DU_ERR="$(mktemp)"
[[ $JSON -eq 0 ]] && log "Walking $START (this can take ~30s for a full home dir)..."
/usr/bin/du -k "$START" 2>"$DU_ERR" > "$DU_FILE" || true
PERM_DENIED=0
if grep -qi "permission denied\|operation not permitted" "$DU_ERR" 2>/dev/null; then
  PERM_DENIED=1
fi

RESULT_FILE="$(mktemp)"
awk -v THRESHOLD_KB="$THRESHOLD_KB" -v REG="$REG_FILE" -v START="$START" '
BEGIN {
  n_reg = 0
  while ((getline line < REG) > 0) {
    split(line, f, "\t")
    n_reg++
    reg_path[n_reg]   = f[1]
    reg_tier[n_reg]   = f[2]
    reg_module[n_reg] = f[3]
    reg_risk[n_reg]   = f[4]
    reg_desc[n_reg]   = f[5]
  }
  close(REG)
}

{
  kb = $1
  path = $0
  sub(/^[0-9]+\t/, "", path)
  size_kb[path] = kb
  if (kb >= THRESHOLD_KB) {
    n_big++
    big_paths[n_big] = path
  }
}

function basename(p,   n, arr) {
  n = split(p, arr, "/")
  return arr[n]
}

function classify_heuristic(p,   bn) {
  bn = basename(p)
  # Cache-like basenames or path contains a cache directory
  if (bn ~ /^(Cache|Caches|CachedData|CachedExtensions|GPUCache|Code Cache|ServiceWorker|Service Worker|logs|log|tmp|temp|cache|caches|.cache|crashpad|sentry|DiagnosticReports|CrashReporter)$/) {
    h_tier = "auto_safe"
    h_desc = "Cache-like folder (heuristic: name matches cache pattern). Regenerated on next use."
    return
  }
  if (index(p, "/Cache/") > 0 || index(p, "/Caches/") > 0 || index(p, "/GPUCache") > 0 || index(p, "/Code Cache") > 0 || index(p, "/logs/") > 0 || index(p, "/log/") > 0) {
    h_tier = "auto_safe"
    h_desc = "Inside cache/log subtree (heuristic). Regenerated on next use."
    return
  }
  if (index(p, "Backup") > 0 || index(p, "backup") > 0 || index(p, ".bak") > 0) {
    h_tier = "review"
    h_desc = "Backup data — verify before deleting."
    return
  }
  if (index(p, "Application Support") > 0) {
    h_tier = "review"
    h_desc = "App data under Application Support — may contain user state. Verify per app."
    return
  }
  if (index(p, "/Containers/") > 0) {
    h_tier = "review"
    h_desc = "Sandboxed app data — may contain user content. Verify per app."
    return
  }
  if (index(p, "/Group Containers/") > 0) {
    h_tier = "review"
    h_desc = "Shared sandboxed data — verify per group."
    return
  }
  if (index(p, "/Developer/") > 0 || index(p, "/Developer$") > 0) {
    h_tier = "auto_safe"
    h_desc = "Developer tools subtree (heuristic). Build artifacts typically regenerable."
    return
  }
  h_tier = "review"
  h_desc = "Large folder, no specific rule. Inspect manually before deleting."
}

END {
  # Pass 1: classify every big path via registry; otherwise mark as needing heuristic.
  for (i = 1; i <= n_big; i++) {
    p = big_paths[i]
    pl = length(p)
    best_len = 0
    best_idx = 0
    for (j = 1; j <= n_reg; j++) {
      rp = reg_path[j]; rl = length(rp)
      if (rl > pl) continue
      if (substr(p, 1, rl) != rp) continue
      if (pl != rl && substr(p, rl+1, 1) != "/") continue
      if (rl > best_len) { best_len = rl; best_idx = j }
    }
    matched_idx[p] = best_idx
    if (best_idx > 0) {
      tier[p]   = reg_tier[best_idx]
      module[p] = reg_module[best_idx]
      risk[p]   = reg_risk[best_idx]
      desc[p]   = reg_desc[best_idx]
      src[p]    = "registry:" best_idx
    } else {
      classify_heuristic(p)
      tier[p]   = h_tier
      desc[p]   = h_desc
      src[p]    = "heuristic:" h_tier
    }
  }

  # Pass 2: emission rules
  #   START itself never emitted.
  #   For registry-classified P: skip if a big ancestor matches the SAME module
  #     (same registry-entry umbrellas P).
  #   For heuristic-classified P: skip if any big DESCENDANT exists at all
  #     (descendants always provide more specific info; we want leaves).
  #   Exception: if heuristic P has no big descendants and no big ancestor is
  #     heuristic-classified with the SAME tier, emit.
  for (i = 1; i <= n_big; i++) {
    p = big_paths[i]
    if (p == START) continue
    pl = length(p)
    skip = 0
    mi_p = matched_idx[p]

    if (mi_p > 0) {
      # Registry-classified
      rp_p = reg_path[mi_p]; rl_p = length(rp_p)
      for (j = 1; j <= n_big; j++) {
        if (i == j) continue
        a = big_paths[j]; al = length(a)
        if (al >= pl) continue
        if (substr(p, 1, al+1) != a "/") continue
        mi_a = matched_idx[a]
        if (mi_a == 0) continue
        rp_a = reg_path[mi_a]; rl_a = length(rp_a)
        if (rl_a > rl_p) continue
        if (substr(rp_p, 1, rl_a) != rp_a) continue
        if (rl_p != rl_a && substr(rp_p, rl_a+1, 1) != "/") continue
        skip = 1; break
      }
    } else {
      # Heuristic — drill to leaves
      for (j = 1; j <= n_big; j++) {
        if (i == j) continue
        d = big_paths[j]; dl = length(d)
        if (dl <= pl) continue
        if (substr(d, 1, pl+1) != p "/") continue
        skip = 1; break
      }
    }

    if (!skip) emit[p] = 1
  }

  for (p in emit) {
    if (!emit[p]) continue
    printf "%s|%d|%s|%s|%s|%s\n", \
      tier[p], size_kb[p]*1024, p, \
      (p in module ? module[p] : ""), \
      (p in risk ? risk[p] : ""), \
      (p in desc ? desc[p] : "")
  }
}
' "$DU_FILE" > "$RESULT_FILE"

SORTED="$(mktemp)"
awk -F'|' '{
  rank = 9
  if ($1 == "auto_safe")   rank = 1
  else if ($1 == "review")    rank = 2
  else if ($1 == "never_touch") rank = 3
  printf "%d|%015d|%s\n", rank, $2, $0
}' "$RESULT_FILE" | sort -t'|' -k1,1n -k2,2r | cut -d'|' -f3- > "$SORTED"

if [[ $JSON -eq 1 ]]; then
  while IFS='|' read -r ttier tbytes tpath tmodule trisk tdesc; do
    json_path="${tpath//\\/\\\\}"; json_path="${json_path//\"/\\\"}"
    json_desc="${tdesc//\\/\\\\}"; json_desc="${json_desc//\"/\\\"}"
    printf '{"tier":"%s","bytes":%s,"human":"%s","path":"%s","module":"%s","risk":"%s","description":"%s"}\n' \
      "$ttier" "$tbytes" "$(format_bytes "$tbytes")" "$json_path" "$tmodule" "$trisk" "$json_desc"
  done < "$SORTED"
  AS=$(awk -F'|' '$1=="auto_safe"{s+=$2} END{print s+0}' "$RESULT_FILE")
  RV=$(awk -F'|' '$1=="review"{s+=$2} END{print s+0}' "$RESULT_FILE")
  NT=$(awk -F'|' '$1=="never_touch"{s+=$2} END{print s+0}' "$RESULT_FILE")
  printf '{"_summary":1,"start":"%s","threshold_kb":%s,"perm_denied":%d,"auto_safe_bytes":%d,"review_bytes":%d,"never_touch_bytes":%d}\n' \
    "$START" "$THRESHOLD_KB" "$PERM_DENIED" "$AS" "$RV" "$NT"
  rm -f "$REG_FILE" "$DU_FILE" "$DU_ERR" "$RESULT_FILE" "$SORTED"
  exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
printf "║  Disk map  —  %-62s║\n" "$START"
printf "║  Threshold ≥ %-7s  •  auto-drilled to specific classifiable items        ║\n" "$(format_bytes "$((THRESHOLD_KB*1024))")"
if [[ $PERM_DENIED -eq 1 ]]; then
  printf "║  ⚠️  some paths denied by macOS TCC — true totals may be higher              ║\n"
fi
echo "╚══════════════════════════════════════════════════════════════════════════════╝"

print_section() {
  local target_tier="$1" label="$2" icon="$3" tagline="$4"
  local total=0 count=0
  local rows="$(mktemp)"
  while IFS='|' read -r tt tb tp tm tr td; do
    [[ "$tt" != "$target_tier" ]] && continue
    total=$((total + tb))
    count=$((count + 1))
    short_path="${tp/#$HOME/~}"
    printf "  %-10s  %s\n              %s\n" "$(format_bytes "$tb")" "$short_path" "$td" >> "$rows"
  done < "$SORTED"
  [[ $count -eq 0 ]] && { rm -f "$rows"; return; }
  echo ""
  printf "%s  %s  (%d items, %s)  — %s\n" "$icon" "$label" "$count" "$(format_bytes "$total")" "$tagline"
  echo "──────────────────────────────────────────────────────────────────────────────────"
  cat "$rows"
  rm -f "$rows"
}

print_section "auto_safe"   "AUTO-SAFE — delete now"     "✅" "no impact, regenerable"
print_section "review"      "NEEDS REVIEW — your call"   "⚠️ " "decide per item"
[[ $HIDE_NEVER -eq 1 ]] || print_section "never_touch" "NEVER-TOUCH — protected (info only)" "🔒" "user/system data"

AS=$(awk -F'|' '$1=="auto_safe"{s+=$2} END{print s+0}' "$RESULT_FILE")
RV=$(awk -F'|' '$1=="review"{s+=$2} END{print s+0}' "$RESULT_FILE")
NT=$(awk -F'|' '$1=="never_touch"{s+=$2} END{print s+0}' "$RESULT_FILE")

echo ""
echo "══════════════════════════════════════════════════════════════════════════════════"
printf "  ✅ Auto-safe (delete):   %s\n" "$(format_bytes "$AS")"
printf "  ⚠️  Review (your call):   %s\n" "$(format_bytes "$RV")"
printf "  🔒 Never-touch (info):   %s\n" "$(format_bytes "$NT")"
echo "══════════════════════════════════════════════════════════════════════════════════"

rm -f "$REG_FILE" "$DU_FILE" "$DU_ERR" "$RESULT_FILE" "$SORTED"
exit 0
