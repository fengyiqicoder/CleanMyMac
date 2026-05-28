HEURISTIC_NAME="Orphaned App Support"
HEURISTIC_DESCRIPTION="Application Support folders for apps no longer installed (Pearcleaner-style detection)."

discover() {
  local as_dir="$HOME/Library/Application Support"
  [[ -d "$as_dir" ]] || return 0
  for support in "$as_dir"/*; do
    [[ -d "$support" ]] || continue
    name="$(basename "$support")"
    # Skip system-level common dirs
    case "$name" in
      "App Store"|"CrashReporter"|".DS_Store"|"Apple"|"com.apple.*"|"MobileSync") continue ;;
    esac
    b=$(path_bytes "$support")
    [[ "$b" -lt 104857600 ]] && continue  # < 100 MB
    # Heuristic: try to find a matching .app bundle by name
    found=0
    for app_dir in /Applications "$HOME/Applications"; do
      if /usr/bin/find "$app_dir" -maxdepth 2 -iname "${name}*.app" -print -quit 2>/dev/null | grep -q .; then
        found=1; break
      fi
    done
    [[ "$found" -eq 1 ]] && continue
    days=$(( ( $(date +%s) - $(stat -f '%m' "$support" 2>/dev/null || echo 0) ) / 86400 ))
    [[ $days -lt 90 ]] && continue
    la=$(stat -f '%Sm' -t '%Y-%m-%d' "$support" 2>/dev/null || echo unknown)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Orphan: $name" "$support" "$b" "$la" "Review" "Leftover data for an app that appears uninstalled. Verify before deleting."
  done
}
