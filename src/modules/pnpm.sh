MODULE_NAME="pnpm store"
MODULE_DESCRIPTION="pnpm content-addressable store. prune removes entries not referenced by any project."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/pnpm" "$HOME/Library/pnpm/store")
MODULE_COMMAND="pnpm store prune"
MODULE_REQUIRES="pnpm"
