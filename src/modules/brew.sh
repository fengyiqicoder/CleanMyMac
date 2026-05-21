MODULE_NAME="Homebrew"
MODULE_DESCRIPTION="Old formula downloads, outdated bottles, unused dependencies."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Caches/Homebrew")
MODULE_COMMAND="brew cleanup -s && brew autoremove"
MODULE_REQUIRES="brew"
