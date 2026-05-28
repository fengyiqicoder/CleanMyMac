# CleanMyMac Safety Rules

These rules are **law**. Every script in `src/scripts/` and every module in `src/modules/` must enforce them. The whitelist (`whitelist.txt`) is the technical realization; this document explains the intent and lists invariants that have no representation in code but must still be honored.

## Never touch

| Path | Why |
|---|---|
| `~/Documents`, `~/Desktop`, `~/Movies`, `~/Music` | User-authored content. Irreplaceable. |
| `~/Pictures`, `~/Pictures/Photos Library.photoslibrary` | Photo library — single largest source of irreplaceable data. |
| `~/Library/Mobile Documents` | iCloud Drive. Touching it can trigger sync storms, redownload loops, or silent loss. |
| `~/Library/Mail` | Mail database. Deleting → permanent loss of stored emails. |
| `~/Library/Messages` | iMessage database. Same as above. |
| `~/Library/Keychains` | Stored passwords and certificates. |
| `~/Library/Calendars`, `~/Library/AddressBook` | Calendar and contacts data. |
| `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube`, `~/.docker/config.json`, `~/.config/gcloud` | Credentials. |
| Browser `Cookies`, `Login Data`, `History`, `Bookmarks`, `Preferences` | Active sessions, saved passwords, browsing history. |
| `/System`, `/Library` (system-level), `/usr`, `/etc`, `/var`, `/private/var` (outside specific exceptions) | OS files. Requires sudo; out of scope. |
| Any external/network volume (anything mounted outside `/`) | User may not want it touched; impossible to make safe assumptions. |
| `~/Library/Containers/<app>/Data/Documents` | Sandboxed app documents. |
| Docker **volumes** (`docker volume *`) | Hold user databases, persistent app state. |

## Invariants

1. **All deletes go through `safe_rm()`.** No script uses `/bin/rm`, `rm -rf`, `find -delete`, or any other deletion primitive directly. `safe_rm()` enforces the whitelist check.
2. **`safe_rm /` is unconditionally refused.** Empty paths, `/`, and `~` (un-expanded) are refused before any whitelist lookup.
3. **No `sudo`.** If a cleanup requires elevation (e.g. `dscacheutil -flushcache`, `purge`), the module sets `MODULE_REQUIRES_SUDO=1` and is skipped unless the user explicitly opts in with `--with-sudo`.
4. **No `docker volume prune`.** Banned at module-write time; `tests/test_module_files.sh` greps every `MODULE_COMMAND` for this string and fails the build if found.
5. **No path outside `/` is touched.** External disks, network mounts, and anything under `/Volumes/<other>` are out of scope.
6. **Scan-first.** Any execute path runs the scan first and shows the user (or, in scheduled mode, the user's last consent) what will be touched.
7. **Confirmation gate.** `autoclean.sh --execute` without `--yes` requires interactive confirmation. The gate triggers automatically when estimated reclaim exceeds 5 GB.
8. **Idempotent.** Running any script twice in a row is safe; the second run produces zero deletes and zero errors.

## What we don't promise

- We do not reclaim space from macOS Storage's "Other" / "System Data" category — that's a UI label, not a filesystem path.
- We do not defragment APFS (it's copy-on-write; defrag is meaningless).
- We do not sync, repair, or migrate iCloud Drive — that's a sync surface, not local junk.
- We do not modify or repair user-owned files in any way. Cleaning means deleting whole files, not editing them.

## Recovery model

Because we use direct delete (no quarantine), recovery comes from the data itself:
- **Caches regenerate.** App relaunch rebuilds them.
- **Compiled artifacts rebuild.** First compile after Xcode DerivedData purge is slower; subsequent builds are normal.
- **Package caches re-download.** `brew install`, `npm install`, `pip install`, etc. fetch from upstream registries.
- **Trash is the system-level safety net.** macOS keeps Trash for 30 days by default before auto-purge.
- **Snapshots aren't backups.** Time Machine local snapshots are convenience copies; the authoritative backup is the remote Time Machine target. Deleting local snapshots does not affect remote backups.

If a user needs more permanent rollback (rare), they should rely on Time Machine, not on CleanMyMac.
