HEURISTIC_NAME="iOS Device Backups (old)"
HEURISTIC_DESCRIPTION="Backups under MobileSync/Backup older than 6 months."

discover() {
  local base="$HOME/Library/Application Support/MobileSync/Backup"
  [[ -d "$base" ]] || return 0
  for backup in "$base"/*; do
    [[ -d "$backup" ]] || continue
    b=$(path_bytes "$backup")
    days=$(( ( $(date +%s) - $(stat -f '%m' "$backup" 2>/dev/null || echo 0) ) / 86400 ))
    [[ $days -lt 180 ]] && continue
    la=$(stat -f '%Sm' -t '%Y-%m-%d' "$backup" 2>/dev/null || echo unknown)
    rec="Review"
    [[ $days -gt 365 ]] && rec="Safe (1y+ — likely superseded)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "iOS backup: $(basename "$backup")" "$backup" "$b" "$la" "$rec" "Old iOS device backup. NOT recoverable once deleted."
  done
}
