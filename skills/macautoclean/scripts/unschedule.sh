#!/usr/bin/env bash
# unschedule.sh — remove the MacAutoClean LaunchAgent.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

AGENT="$HOME/Library/LaunchAgents/com.macautoclean.plist"

if [[ ! -f "$AGENT" ]]; then
  printf "$(i18n 'No LaunchAgent installed (looked for %s).')\n" "$AGENT"
  exit 0
fi

launchctl bootout "gui/$UID" "$AGENT" 2>/dev/null || true
rm -f "$AGENT"
printf "$(i18n '✓ Unscheduled. LaunchAgent removed: %s')\n" "$AGENT"
