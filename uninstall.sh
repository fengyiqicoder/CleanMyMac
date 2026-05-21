#!/usr/bin/env bash
# uninstall.sh — remove the skill symlink and any active LaunchAgent.
set -euo pipefail

DST="$HOME/.claude/skills/macautoclean"
AGENT="$HOME/Library/LaunchAgents/com.macautoclean.plist"

if [[ -f "$AGENT" ]]; then
  echo "Removing LaunchAgent..."
  launchctl bootout "gui/$UID" "$AGENT" 2>/dev/null || true
  rm -f "$AGENT"
fi

if [[ -L "$DST" ]]; then
  rm "$DST"
  echo "✓ Removed symlink: $DST"
elif [[ -e "$DST" ]]; then
  echo "Skipped: $DST exists but is not a symlink." >&2
else
  echo "Skipped: $DST not found."
fi

echo "Uninstall complete."
