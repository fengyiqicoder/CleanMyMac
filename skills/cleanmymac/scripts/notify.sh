#!/usr/bin/env bash
# notify.sh — send a macOS notification.
# Usage: notify.sh "message" "subtitle"
set -euo pipefail
MSG="${1:-CleanMyMac run complete}"
SUB="${2:-}"

if command -v terminal-notifier >/dev/null 2>&1; then
  if [[ -n "$SUB" ]]; then
    terminal-notifier -title "CleanMyMac" -subtitle "$SUB" -message "$MSG" >/dev/null 2>&1 || true
  else
    terminal-notifier -title "CleanMyMac" -message "$MSG" >/dev/null 2>&1 || true
  fi
else
  # Escape double quotes in message for osascript
  esc_msg="${MSG//\"/\\\"}"
  esc_sub="${SUB//\"/\\\"}"
  if [[ -n "$SUB" ]]; then
    /usr/bin/osascript -e "display notification \"$esc_msg\" with title \"CleanMyMac\" subtitle \"$esc_sub\"" >/dev/null 2>&1 || true
  else
    /usr/bin/osascript -e "display notification \"$esc_msg\" with title \"CleanMyMac\"" >/dev/null 2>&1 || true
  fi
fi
