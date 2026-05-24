# Changelog

All notable changes to MacAutoClean.

## [Unreleased]

### Changed
- **Repo layout follows the [Agent Skills](https://agentskills.io/) spec.** Skill source moved from `src/` to `skills/macautoclean/`, so `SKILL.md` lives at the standard path that `npx skills add fengyiqicoder/MacAutoClean` (and skills.sh) expects. `install.sh`, tests, and docs updated accordingly — no functional change.

### Added
- `skills.sh.json` at the repo root — display config for the [skills.sh](https://skills.sh/fengyiqicoder/MacAutoClean) directory page.
- README: install-via-skills.sh instructions and badge.

## [0.1.0] — 2026-05-22

Initial public release.

### Added
- **51 cleanup modules** covering system caches, logs, trash, aged Downloads, APFS snapshots, diagnostic reports, Xcode (Derived Data, Archives, Device Support, Simulators, iOS backups), Homebrew, Docker, package managers (npm, yarn, pnpm, bun, pip, poetry, pyenv, cargo, go, gradle, maven, composer, nuget, conan, gem), IDEs (JetBrains, Android Studio, VS Code), Adobe, browsers (Chrome, Safari, Firefox, Edge, Brave, Arc, Chromium), social/chat (Slack, Discord, Teams, Telegram, Obsidian), cloud sync (Dropbox, Google Drive), games (Steam, Minecraft, Lunar Client), DNS cache and inactive-memory purge.
- **9 Smart Advisor heuristics**: Local AI models (Ollama, HuggingFace, LM Studio), VM disks (Parallels, VMware, UTM, VirtualBox), old iOS backups, stale `node_modules`, stale Python envs (venv + conda), IDE workspace storage, chat-app downloaded media, orphaned `Application Support`, generic large-folder fallback.
- **Scheduled auto-run** via macOS `launchd` — weekly / biweekly / monthly / custom presets with scope and notification options.
- **`safe_rm()` whitelist enforcement** — every delete checks against `whitelist.txt`. Enforcement test verifies 33 known-safe paths allowed + 22 sensitive paths rejected.
- **218+ test assertions** across 5 test files.
- **Claude Code skill discoverability** via `src/SKILL.md` frontmatter.

### Security
- `docker volume prune` is grep-banned at module-validation build time.
- No `sudo` without explicit `--with-sudo` consent.
- Browser cookies, login data, history, bookmarks, and preferences are explicitly excluded from all cache-clearing modules.
- iCloud Drive, Mail, Messages, Keychain, SSH/GPG/AWS credentials are never touched.

[0.1.0]: https://github.com/fengyiqicoder/MacAutoClean/releases/tag/v0.1.0
