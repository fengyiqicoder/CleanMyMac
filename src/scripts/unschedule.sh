#!/usr/bin/env bash
# unschedule.sh — remove the MacAutoClean LaunchAgent.
set -euo pipefail
AGENT="$HOME/Library/LaunchAgents/com.macautoclean.plist"

if [[ ! -f "$AGENT" ]]; then
  echo "No LaunchAgent installed (looked for $AGENT)."
  exit 0
fi

launchctl bootout "gui/$UID" "$AGENT" 2>/dev/null || true
rm -f "$AGENT"
echo "✓ Unscheduled. LaunchAgent removed: $AGENT"
