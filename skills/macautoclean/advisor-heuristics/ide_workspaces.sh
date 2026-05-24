HEURISTIC_NAME="IDE Workspace Storage"
HEURISTIC_DESCRIPTION="VS Code workspaceStorage entries for projects no longer present + JetBrains caches."

discover() {
  # VS Code workspaceStorage
  ws_root="$HOME/Library/Application Support/Code/User/workspaceStorage"
  if [[ -d "$ws_root" ]]; then
    for ws in "$ws_root"/*; do
      [[ -d "$ws" ]] || continue
      b=$(path_bytes "$ws")
      [[ "$b" -lt 10485760 ]] && continue  # < 10 MB
      days=$(( ( $(date +%s) - $(stat -f '%m' "$ws" 2>/dev/null || echo 0) ) / 86400 ))
      [[ $days -lt 60 ]] && continue
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$ws" 2>/dev/null || echo unknown)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "VS Code workspace: $(basename "$ws")" "$ws" "$b" "$la" "Safe (60d+)" "Per-workspace state. Recreated when project is reopened."
    done
  fi
}
