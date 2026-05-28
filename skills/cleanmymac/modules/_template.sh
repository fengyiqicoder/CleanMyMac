# Template for a CleanMyMac cleanup module.
# Copy this file as src/modules/<your_category>.sh and fill in the values.
# This file (starting with _) is skipped by the loader.

# Required: short human name shown in the scan report.
MODULE_NAME="Example Category"

# Required: one-sentence description of what this targets and how it regenerates.
MODULE_DESCRIPTION="What this module cleans, and how the data comes back after."

# Required: low | medium | high
MODULE_RISK="low"

# Optional: dev | browser | system | social | game | media (used by --scope filter)
MODULE_CATEGORY="dev"

# At least one of MODULE_PATHS or MODULE_COMMAND must be set.

# Paths to size during scan and remove during execute. Use $HOME, not ~.
# Every entry must pass is_whitelisted (build-time test enforces this).
MODULE_PATHS=(
  "$HOME/Library/Caches/com.example.app"
)

# Optional: a shell command run during execute INSTEAD of removing MODULE_PATHS.
# Used when the tool ships its own safe cleanup (brew, docker, xcrun, npm cache).
# MODULE_PATHS is still used for scan sizing.
# Banned: "docker volume prune", "rm -rf /", "sudo " (use MODULE_REQUIRES_SUDO=1 instead).
MODULE_COMMAND=""

# Optional: only quarantine entries whose mtime is older than N days. 0 = no filter.
MODULE_AGE_DAYS=0

# Optional: skip this module if the named binary is not on PATH.
MODULE_REQUIRES=""

# Optional: 1 if the cleanup needs sudo. Skipped unless --with-sudo is passed.
MODULE_REQUIRES_SUDO=0

# Optional: human note shown in scan report.
MODULE_NOTES=""
