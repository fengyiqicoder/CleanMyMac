MODULE_NAME="DNS cache flush"
MODULE_DESCRIPTION="Flushes the system DNS cache. Requires sudo."
MODULE_RISK="low"
MODULE_CATEGORY="system"
MODULE_PATHS=("$HOME/Library/Logs")
MODULE_COMMAND="dscacheutil -flushcache && killall -HUP mDNSResponder"
MODULE_REQUIRES_SUDO=1
MODULE_NOTES="Requires sudo. Skipped unless --with-sudo flag is passed."
