# MacAutoClean Whitelist Explained

The authoritative machine-readable list is [`whitelist.txt`](./whitelist.txt). This document explains each section in human terms.

> `safe_rm()` in `lib.sh` refuses any path whose absolute form does not start with one of the prefixes listed in `whitelist.txt`. Every module is also checked at build time by `tests/test_module_files.sh` — if a module declares a path outside the whitelist, the test suite fails.

## 1. User-level caches & logs

- `~/Library/Caches` — System and app caches. Largest single recoverable category on most Macs.
- `~/Library/Logs` — Application log files.
- `~/Library/Application Support/CrashReporter` — macOS crash reports.

## 2. Trash & Downloads

- `~/.Trash` — Items moved to Trash via Finder.
- `~/Downloads` — Module touches only entries older than 90 days by default (configurable via `MODULE_AGE_DAYS`).

## 3. Browsers

Cache and code-cache subdirectories **only**. Cookies, Login Data, History, Bookmarks, and Preferences are explicitly excluded.

Supported: Chrome, Safari, Firefox, Edge, Brave, Arc, Chromium.

## 4. Apple developer tools

- `DerivedData`, `Archives`, `*DeviceSupport`, `CoreSimulator/Caches`, `CoreSimulator/Devices`.
- Xcode rebuilds these on next compile/run.
- `xcrun simctl delete unavailable` is preferred over raw path deletion for simulators.

## 5. iOS / iPad backups

`~/Library/Application Support/MobileSync/Backup` is whitelisted, but only the **advisor** suggests specific old backups for deletion. The default modules do not auto-delete iOS backups.

## 6. Package manager caches

npm, yarn, pnpm, bun, pip, poetry, pyenv, cargo, go, gradle, maven, composer, nuget, conan, gem. All caches; never installed packages.

## 7. IDE caches

JetBrains, Android Studio, VS Code Cache/CachedData/Code Cache/GPUCache/logs/workspaceStorage. User settings and extensions are **not** in scope.

## 8. Homebrew

`~/Library/Caches/Homebrew` plus the module runs `brew cleanup -s && brew autoremove`.

## 9. Docker

Native `docker prune` runs for containers, images, builders, networks. Volumes are **never** touched.

## 10. Adobe

Media cache, media cache files, application caches, logs.

## 11. Social / chat apps

Slack, Discord, Microsoft Teams, Telegram — only the Cache / Code Cache / GPUCache / Service Worker / logs subdirectories. Login state and message history are preserved.

## 12. Productivity / cloud sync caches

Obsidian, Dropbox, Google Drive — caches and logs only.

## 13. Games

Steam logs and appcache, Minecraft logs, Lunar Client logs and cache.

## 14. MacAutoClean own state

`/tmp/macautoclean` — used for transient files (run logs, intermediate JSON). Safe to wipe.

---

If you need to add a new path: add the prefix to `whitelist.txt`, document it here, and add a module under `src/modules/` that uses it. The build-time test will refuse modules whose paths are not whitelisted.
