#!/usr/bin/env bash
# schedule.sh — install a launchd LaunchAgent to run autoclean.sh on a schedule.
#
# Usage:
#   schedule.sh                       # interactive setup
#   schedule.sh --status              # show whether scheduled and next-run
#   schedule.sh --next-run            # print next-run datetime only
#   schedule.sh --preset weekly       # non-interactive (weekly|biweekly|monthly)
#   schedule.sh --dry-run             # render plist, do not install

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

AGENT_PATH="$HOME/Library/LaunchAgents/com.macautoclean.plist"
LOG_PATH="$HOME/Library/Logs/macautoclean-scheduled.log"
TEMPLATE="$TEMPLATES_DIR/com.macautoclean.plist.tmpl"
LABEL="com.macautoclean"

if [[ ! -f "$TEMPLATE" ]]; then
  err "template not found: $TEMPLATE"; exit 1
fi

PRESET=""
DRY=0
ACTION=install
for arg in "$@"; do
  case "$arg" in
    --status) ACTION=status ;;
    --next-run) ACTION=next ;;
    --preset) PRESET_NEXT=1 ;;
    --preset=*) PRESET="${arg#--preset=}" ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *)
      if [[ "${PRESET_NEXT:-0}" -eq 1 ]]; then PRESET="$arg"; PRESET_NEXT=0
      else err "unknown arg: $arg"; exit 2; fi
      ;;
  esac
done

# ---- Status mode ----
if [[ "$ACTION" == "status" ]]; then
  if [[ -f "$AGENT_PATH" ]]; then
    echo "✓ Scheduled. LaunchAgent: $AGENT_PATH"
    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
      echo "  State: loaded"
    else
      echo "  State: NOT loaded (try: launchctl bootstrap gui/$UID \"$AGENT_PATH\")"
    fi
    echo "  Log:   $LOG_PATH"
  else
    echo "Not scheduled."
  fi
  exit 0
fi

if [[ "$ACTION" == "next" ]]; then
  if [[ -f "$AGENT_PATH" ]]; then
    /usr/bin/plutil -extract StartCalendarInterval xml1 -o - "$AGENT_PATH" 2>/dev/null || echo "(no calendar set)"
  else
    echo "Not scheduled."
  fi
  exit 0
fi

# ---- Interactive (or preset) setup ----
echo "MacAutoClean — Scheduled Auto-Run Setup"
echo ""

if [[ -z "$PRESET" ]]; then
  echo "How often should MacAutoClean run?"
  echo "  1) Weekly (Sunday 3 AM)"
  echo "  2) Every 2 weeks (1st and 15th of the month, 3 AM)"
  echo "  3) Monthly (1st of the month, 3 AM)"
  echo "  4) Custom (you'll provide weekday + hour)"
  echo -n "> "
  read -r choice
  case "$choice" in
    1) PRESET="weekly" ;;
    2) PRESET="biweekly" ;;
    3) PRESET="monthly" ;;
    4) PRESET="custom" ;;
    *) err "invalid choice"; exit 2 ;;
  esac
fi

# Build CALENDAR_BLOCK
build_calendar() {
  case "$PRESET" in
    weekly)
      cat <<XML
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>0</integer>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
XML
      ;;
    biweekly)
      cat <<XML
  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Day</key><integer>1</integer>
      <key>Hour</key><integer>3</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
    <dict>
      <key>Day</key><integer>15</integer>
      <key>Hour</key><integer>3</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
  </array>
XML
      ;;
    monthly)
      cat <<XML
  <key>StartCalendarInterval</key>
  <dict>
    <key>Day</key><integer>1</integer>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
XML
      ;;
    custom)
      echo -n "  Weekday (0=Sun, 1=Mon, ... 6=Sat): " >&2; read -r wd
      echo -n "  Hour (0-23, e.g. 3 for 3 AM): " >&2; read -r hr
      cat <<XML
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>$wd</integer>
    <key>Hour</key><integer>$hr</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
XML
      ;;
    *) err "unknown preset: $PRESET"; exit 2 ;;
  esac
}

# Scope (default = safe categories only)
SCOPE="system,dev,browser"
NOTIFY_MODE="notify"
if [[ -z "${PRESET_AUTO:-}" && "$DRY" -eq 0 ]]; then
  echo ""
  echo "What should each run do?"
  echo "  1) Clean safe categories (caches, logs, trash) + send notification  [recommended]"
  echo "  2) Clean all 51 modules + send notification"
  echo "  3) Notify only (do not clean automatically — open Claude when ready)"
  echo -n "> "
  read -r scope_choice
  case "$scope_choice" in
    1) SCOPE="system,browser,social,game"; NOTIFY_MODE="notify" ;;
    2) SCOPE="system,dev,browser,social,game,media"; NOTIFY_MODE="notify" ;;
    3) SCOPE="none"; NOTIFY_MODE="claude" ;;
    *) err "invalid choice"; exit 2 ;;
  esac
fi

# Render plist via sed substitutions
CAL_BLOCK="$(build_calendar)"
RENDERED="$(mktemp)"
SCRIPTS_DIR_ABS="$SCRIPT_DIR"

# Note: sed substitution with multi-line CAL_BLOCK is tricky; use python-free approach:
#   read template, do simple textual replacements with bash.
template_content="$(cat "$TEMPLATE")"
template_content="${template_content//__SCRIPTS_DIR__/$SCRIPTS_DIR_ABS}"
template_content="${template_content//__SCOPE__/$SCOPE}"
template_content="${template_content//__NOTIFY_MODE__/$NOTIFY_MODE}"
template_content="${template_content//__LOG_PATH__/$LOG_PATH}"
# CAL_BLOCK has newlines; bash ${var//pat/replacement} handles this fine.
template_content="${template_content//__CALENDAR_BLOCK__/$CAL_BLOCK}"
echo "$template_content" > "$RENDERED"

# Validate
if ! /usr/bin/plutil -lint "$RENDERED" >/dev/null 2>&1; then
  err "rendered plist failed plutil -lint:"
  /usr/bin/plutil -lint "$RENDERED" >&2 || true
  cat "$RENDERED" >&2
  rm -f "$RENDERED"
  exit 1
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "--- DRY RUN: rendered plist ---"
  cat "$RENDERED"
  rm -f "$RENDERED"
  exit 0
fi

# Install
mkdir -p "$(dirname "$AGENT_PATH")"
# If previously loaded, bootout first.
if [[ -f "$AGENT_PATH" ]]; then
  launchctl bootout "gui/$UID" "$AGENT_PATH" 2>/dev/null || true
fi
mv "$RENDERED" "$AGENT_PATH"
chmod 644 "$AGENT_PATH"

if ! launchctl bootstrap "gui/$UID" "$AGENT_PATH" 2>/dev/null; then
  err "launchctl bootstrap failed. You may need to remove a stale entry: launchctl bootout gui/$UID $AGENT_PATH"
  exit 1
fi

echo ""
echo "✓ Scheduled: $PRESET ($SCOPE)"
echo "  Agent:  $AGENT_PATH"
echo "  Log:    $LOG_PATH"
echo "  Status: $SCRIPT_DIR/schedule.sh --status"
echo "  Stop:   $SCRIPT_DIR/unschedule.sh"
