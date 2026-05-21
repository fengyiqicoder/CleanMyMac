MODULE_NAME="iOS / iPad Backups"
MODULE_DESCRIPTION="Device backups under ~/Library/Application Support/MobileSync/Backup. HIGH RISK — backups are not auto-recoverable. The Smart Advisor surfaces specific old backups; this module is rarely run as a default."
MODULE_RISK="high"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Application Support/MobileSync/Backup")
MODULE_AGE_DAYS=365
MODULE_NOTES="Strongly recommend using the Advisor (advisor.sh) to review specific backups instead of bulk-clearing."
