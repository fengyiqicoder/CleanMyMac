MODULE_NAME="iOS Simulators (unavailable)"
MODULE_DESCRIPTION="iOS/iPadOS/watchOS/tvOS simulators marked as unavailable by Xcode. Removed via xcrun simctl."
MODULE_RISK="low"
MODULE_CATEGORY="dev"
MODULE_PATHS=("$HOME/Library/Developer/CoreSimulator/Caches")
MODULE_COMMAND="xcrun simctl delete unavailable"
MODULE_REQUIRES="xcrun"
