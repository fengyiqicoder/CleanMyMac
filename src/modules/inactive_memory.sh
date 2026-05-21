MODULE_NAME="Inactive memory purge"
MODULE_DESCRIPTION="Forces macOS to free inactive memory pages. Requires sudo."
MODULE_RISK="low"
MODULE_CATEGORY="system"
MODULE_PATHS=("$HOME/Library/Logs")
MODULE_COMMAND="purge"
MODULE_REQUIRES_SUDO=1
MODULE_NOTES="Requires sudo. Frees inactive memory rather than disk space; included for parity with mac-cleanup-py."
