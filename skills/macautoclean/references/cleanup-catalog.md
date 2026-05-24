# Cleanup Catalog

Every cleanup module, its paths, typical reclaim, risk, and how the data comes back.

| Category | Paths / Command | Typical reclaim | Risk | Recovery |
|---|---|---|---|---|
| System caches | `~/Library/Caches` | 1–10 GB | low | Apps regenerate on next launch |
| System logs | `~/Library/Logs` | 100 MB – 1 GB | low | Logs written fresh on next run |
| Trash | `~/.Trash` | varies | low | Items are gone; restore from Time Machine if needed |
| Downloads (90d+) | `~/Downloads` (mtime >90d) | varies | medium | Files are gone; re-download from source |
| APFS snapshots | `tmutil deletelocalsnapshots /` | 5–100 GB | low | Time Machine remakes local snapshots automatically |
| Diagnostic reports (30d+) | `~/Library/Application Support/CrashReporter` | small | low | New crashes still generate fresh reports |
| Xcode Derived Data | `~/Library/Developer/Xcode/DerivedData` | 5–50 GB | low | Next build recompiles (slower first build) |
| Xcode Archives | `~/Library/Developer/Xcode/Archives` | 1–20 GB | medium | Archived builds gone; cannot symbolicate old crashes |
| Xcode DeviceSupport | `~/Library/Developer/Xcode/*DeviceSupport` | 1–10 GB | low | Re-downloaded next time you connect a device |
| iOS Simulators (unavailable) | `xcrun simctl delete unavailable` | 1–10 GB | low | Re-install via Xcode |
| iOS Backups | `~/Library/Application Support/MobileSync/Backup` | 5–50 GB | **high** | NOT recoverable. Use Advisor instead. |
| Homebrew | `brew cleanup -s && brew autoremove` | 500 MB – 5 GB | low | Re-downloaded on next `brew install` |
| Docker | `docker {container,image,builder,network} prune -f` | 1–50 GB | medium | Volumes preserved; images re-pulled |
| npm | `npm cache clean --force` + `~/.npm/_cacache` | 100 MB – 5 GB | low | Re-downloaded on next `npm install` |
| yarn | `yarn cache clean` | 100 MB – 2 GB | low | Re-downloaded on next install |
| pnpm | `pnpm store prune` | 100 MB – 5 GB | low | Re-downloaded |
| bun | `~/Library/Caches/bun`, `~/.bun/install/cache` | 50 MB – 1 GB | low | Re-downloaded |
| pip | `pip3 cache purge` | 50 MB – 1 GB | low | Re-downloaded |
| poetry | `~/Library/Caches/pypoetry` | 50 MB – 1 GB | low | Re-downloaded |
| pyenv | `~/Library/Caches/pyenv` | 50 MB – 500 MB | low | Re-downloaded |
| cargo | `~/.cargo/registry/{cache,src}`, `~/.cargo/git/db` | 500 MB – 10 GB | low | Re-downloaded on next `cargo build` |
| go modules | `go clean -modcache` | 500 MB – 10 GB | low | Re-downloaded |
| gradle | `~/.gradle/caches` | 500 MB – 5 GB | low | Re-downloaded |
| maven | `~/.m2/repository/.cache` | 100 MB – 1 GB | low | Re-downloaded |
| composer | `~/.composer/cache` | 100 MB – 1 GB | low | Re-downloaded |
| nuget | `~/.nuget/packages` | 100 MB – 5 GB | low | Re-downloaded |
| conan | `~/.conan{,2}` | 100 MB – 2 GB | low | Re-downloaded |
| RubyGems | `~/.gem/cache` | 50 MB – 500 MB | low | Re-downloaded |
| JetBrains | `~/Library/Caches/JetBrains` | 500 MB – 5 GB | low | Re-indexed on next IDE open |
| Android Studio | `~/Library/Caches/{Google,}AndroidStudio*` | 500 MB – 5 GB | low | Re-indexed |
| VS Code | `~/Library/Application Support/Code/{Cache,CachedData,Code Cache,GPUCache,logs}` | 100 MB – 2 GB | low | Recreated on next launch |
| Adobe | media cache + common cache + logs | 1–20 GB | low | Re-rendered on next preview |
| Chrome / Brave / Edge / Arc | HTTP / GPU / code caches (NOT Cookies/Logins) | 500 MB – 5 GB | low | Re-fetched on browsing |
| Safari | `~/Library/Caches/com.apple.Safari` | 100 MB – 2 GB | low | Re-fetched |
| Firefox | `~/Library/Caches/Firefox` | 100 MB – 2 GB | low | Re-fetched |
| Chromium | `~/Library/Caches/Chromium` | small | low | Re-fetched |
| Slack | Cache / Code Cache / GPUCache / Service Worker / logs | 100 MB – 5 GB | low | Re-fetched on next sync |
| Discord | Cache / Code Cache / GPUCache | 100 MB – 2 GB | low | Re-fetched |
| Microsoft Teams | Cache subfolders + logs (classic + new) | 100 MB – 5 GB | low | Re-fetched |
| Telegram | `~/Library/Containers/ru.keepcoder.Telegram/.../Caches` | 100 MB – 5 GB | low | Re-fetched |
| Obsidian | `~/Library/Caches/com.obsidian.Obsidian` | small | low | Re-cached |
| Dropbox | client cache + logs | 100 MB – 1 GB | low | Re-cached |
| Google Drive | DriveFS logs | small | low | Logs rotate on next sync |
| Steam | logs + appcache | 100 MB – 1 GB | low | Library not affected; logs rotate |
| Minecraft | launcher + game logs | small | low | Logs rotate |
| Lunar Client | cache + logs | 100 MB – 1 GB | low | Re-cached |
| DNS cache flush | `dscacheutil -flushcache && killall -HUP mDNSResponder` | n/a | low | Requires sudo. Refreshes DNS resolution. |
| Inactive memory purge | `purge` | n/a (RAM only) | low | Requires sudo. Frees inactive RAM. |
