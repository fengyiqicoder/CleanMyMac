#!/usr/bin/env bash
# Verifies that whitelist.txt allows known-safe paths and rejects sensitive ones.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export WHITELIST_FILE="$REPO/skills/cleanmymac/references/whitelist.txt"
. "$REPO/skills/cleanmymac/scripts/lib.sh"

PASS=0; FAIL=0

allow() {
  if is_whitelisted "$1"; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); echo "  ✗ should allow: $1" >&2; fi
}
reject() {
  if is_whitelisted "$1"; then FAIL=$((FAIL+1)); echo "  ✗ should reject: $1" >&2
  else PASS=$((PASS+1)); fi
}

# --- must allow ---
allow "$HOME/Library/Caches/com.apple.bird"
allow "$HOME/Library/Caches/Homebrew/downloads/x.tar.gz"
allow "$HOME/.npm/_cacache/index-v5/12/34"
allow "$HOME/.cargo/registry/cache/github.com-xyz"
allow "$HOME/Library/Developer/Xcode/DerivedData/MyApp-abc/Build"
allow "$HOME/Library/Developer/CoreSimulator/Devices/uuid"
allow "$HOME/.Trash/foo"
allow "$HOME/Downloads/oldfile.zip"
allow "$HOME/Library/Caches/Google/Chrome/Default"
allow "$HOME/Library/Application Support/Slack/Cache/data_0"
allow "/tmp/cleanmymac/run-001"

# --- must reject ---
reject "$HOME/Documents/tax-return.pdf"
reject "$HOME/Desktop/important.key"
reject "$HOME/Pictures/Photos Library.photoslibrary/Masters"
reject "$HOME/Movies/wedding.mov"
reject "$HOME/Music/iTunes/iTunes Media"
reject "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Notes"
reject "$HOME/Library/Mail/V10/data.sqlite"
reject "$HOME/Library/Messages/chat.db"
reject "$HOME/Library/Keychains/login.keychain-db"
reject "$HOME/.ssh/id_ed25519"
reject "$HOME/.ssh/known_hosts"
reject "$HOME/.gnupg/private-keys-v1.d"
reject "$HOME/.aws/credentials"
reject "$HOME/.kube/config"
reject "/System/Library/CoreServices"
reject "/etc/hosts"
reject "/usr/local/bin/brew"
reject "/var/log/system.log"
reject "$HOME/Library/Application Support/Google/Chrome/Default/Cookies"
reject "$HOME/Library/Application Support/Google/Chrome/Default/Login Data"
reject "$HOME/Library/Application Support/Code/User/settings.json"
reject "$HOME/Library/Application Support/Slack/storage/leveldb"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] || exit 1
echo "PASS"
