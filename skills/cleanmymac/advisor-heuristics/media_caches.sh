HEURISTIC_NAME="Chat App Downloaded Media"
HEURISTIC_DESCRIPTION="Slack/Discord/Teams downloaded files and media >1 GB total."

discover() {
  for media_dir in \
    "$HOME/Library/Application Support/Slack/storage/slack-downloads" \
    "$HOME/Library/Application Support/discord/Cache" \
    "$HOME/Library/Application Support/Microsoft/Teams/media-stack"; do
    [[ -d "$media_dir" ]] || continue
    b=$(path_bytes "$media_dir")
    [[ "$b" -lt 1073741824 ]] && continue
    la=$(stat -f '%Sm' -t '%Y-%m-%d' "$media_dir" 2>/dev/null || echo unknown)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Chat media: $(basename "$(dirname "$media_dir")")" "$media_dir" "$b" "$la" "Review" "Old downloaded media. Re-downloadable from the original message."
  done
}
