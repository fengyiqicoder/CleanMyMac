# Schedule Guide

CleanMyMac uses macOS-native `launchd` to run cleanup automatically.

## Quick start

```bash
~/.claude/skills/cleanmymac/scripts/schedule.sh
```

Follow the interactive prompts.

## Presets

| Preset | When |
|---|---|
| `weekly` | Every Sunday at 03:00 |
| `biweekly` | 1st and 15th of every month at 03:00 |
| `monthly` | 1st of every month at 03:00 |
| `custom` | You provide weekday (0–6, Sun=0) + hour (0–23) |

## Scopes

| Option | Behavior |
|---|---|
| 1 (Safe + notify) | Cleans `system,browser,social,game` categories and shows a notification with reclaimed size |
| 2 (All + notify) | Cleans all 51 modules and notifies |
| 3 (Notify only) | Runs no cleanup; just notifies you it's time to review |

## Inspect

```bash
~/.claude/skills/cleanmymac/scripts/schedule.sh --status
# or
launchctl list | grep com.cleanmymac
```

## Logs

`~/Library/Logs/cleanmymac-scheduled.log` — captures `autoclean.sh`'s stdout and stderr for every scheduled run.

## Remove

```bash
~/.claude/skills/cleanmymac/scripts/unschedule.sh
```

## Permissions

The LaunchAgent may need Full Disk Access (TCC) to read certain paths. If your scheduled runs show anomalously low reclaim:

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Add `/bin/bash` (the interpreter the agent runs as)
3. Restart the agent: `launchctl kickstart -k gui/$UID/com.cleanmymac`

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `launchctl bootstrap` says "already loaded" | Stale agent from prior install | `launchctl bootout gui/$UID ~/Library/LaunchAgents/com.cleanmymac.plist`, then re-run schedule.sh |
| Notifications not appearing | macOS not granted notification permission | Open `System Settings → Notifications → Script Editor`, allow alerts |
| `plutil -lint` errors | Template was edited by hand | Re-render via `schedule.sh --dry-run` to see the issue |
| Scheduled run reclaims 0 bytes | Caches were already empty (good!) or TCC issue (see Permissions) | Check `~/Library/Logs/cleanmymac-scheduled.log` |
