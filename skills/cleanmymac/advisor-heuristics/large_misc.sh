HEURISTIC_NAME="Large Folders (>5 GB, untouched 90d+)"
HEURISTIC_DESCRIPTION="Generic fallback — any directory under \$HOME over 5GB and untouched 90+ days, excluding categories already covered above."

discover() {
  # Top-level home subdirs >5GB with mtime >90d
  for dir in "$HOME"/*; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    case "$name" in
      Library|.Trash|Downloads|Documents|Desktop|Pictures|Movies|Music|.git|.cache|.ollama|Parallels|"Virtual Machines.localized") continue ;;
    esac
    b=$(path_bytes "$dir")
    [[ "$b" -lt 5368709120 ]] && continue
    days=$(( ( $(date +%s) - $(stat -f '%m' "$dir" 2>/dev/null || echo 0) ) / 86400 ))
    [[ $days -lt 90 ]] && continue
    la=$(stat -f '%Sm' -t '%Y-%m-%d' "$dir" 2>/dev/null || echo unknown)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Large unused: $name" "$dir" "$b" "$la" "Review" "Large folder you have not touched in 90+ days. Inspect contents manually."
  done
}
