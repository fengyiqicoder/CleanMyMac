#!/usr/bin/env bash
# lib-registry.sh — builds a path→classification lookup table from all modules + safety rules.
# Used by diskmap.sh to annotate every folder it walks.

NEVER_TOUCH_PREFIXES=(
  "$HOME/Documents"
  "$HOME/Desktop"
  "$HOME/Pictures"
  "$HOME/Movies"
  "$HOME/Music"
  "$HOME/Library/Mobile Documents"
  "$HOME/Library/Mail"
  "$HOME/Library/Messages"
  "$HOME/Library/Keychains"
  "$HOME/Library/Calendars"
  "$HOME/Library/AddressBook"
  "$HOME/.ssh"
  "$HOME/.gnupg"
  "$HOME/.aws"
  "$HOME/.kube"
  "$HOME/.docker/config.json"
  "$HOME/.config/gcloud"
  "/System"
  "/usr"
  "/etc"
  "/var"
  "/private/var"
  "/Library/Application Support"
  "/Library/Frameworks"
  "/Library/Extensions"
)
NEVER_TOUCH_DESCS=(
  "User documents — irreplaceable"
  "Active workspace — irreplaceable"
  "Photos library — irreplaceable"
  "Video library"
  "Music library"
  "iCloud Drive — sync surface, do not touch"
  "Mail database"
  "iMessage database"
  "Stored passwords and certificates"
  "Calendar data"
  "Contacts database"
  "SSH keys"
  "GPG keys"
  "AWS credentials"
  "Kubernetes credentials"
  "Docker registry credentials"
  "Google Cloud credentials"
  "macOS system files"
  "System binaries"
  "System config"
  "System runtime"
  "System runtime (mirrored)"
  "System-level application support"
  "System frameworks"
  "System extensions"
)

REGISTRY_PATH=()
REGISTRY_TIER=()
REGISTRY_MODULE=()
REGISTRY_RISK=()
REGISTRY_DESC=()

build_registry() {
  REGISTRY_PATH=(); REGISTRY_TIER=(); REGISTRY_MODULE=(); REGISTRY_RISK=(); REGISTRY_DESC=()
  local i=0
  while [[ $i -lt ${#NEVER_TOUCH_PREFIXES[@]} ]]; do
    REGISTRY_PATH+=("${NEVER_TOUCH_PREFIXES[$i]}")
    REGISTRY_TIER+=("never_touch")
    REGISTRY_MODULE+=("")
    REGISTRY_RISK+=("")
    REGISTRY_DESC+=("${NEVER_TOUCH_DESCS[$i]}")
    i=$((i+1))
  done
  shopt -s nullglob
  local mf base tier p
  for mf in "$MODULES_DIR"/*.sh; do
    base="$(basename "$mf")"
    case "$base" in _*) continue ;; esac
    if ! load_module "$mf" >/dev/null 2>&1; then continue; fi
    tier="auto_safe"
    case "${MODULE_RISK:-low}" in medium|high) tier="review" ;; esac
    for p in "${MODULE_PATHS[@]:-}"; do
      [[ -z "$p" ]] && continue
      p="${p/#\~/$HOME}"
      REGISTRY_PATH+=("$p")
      REGISTRY_TIER+=("$tier")
      REGISTRY_MODULE+=("$base")
      REGISTRY_RISK+=("$MODULE_RISK")
      REGISTRY_DESC+=("$MODULE_DESCRIPTION")
    done
  done
}

lookup_path() {
  local target="$1"
  local n=${#REGISTRY_PATH[@]}
  local best_idx=-1 best_len=0
  local i=0 p plen
  while [[ $i -lt $n ]]; do
    p="${REGISTRY_PATH[$i]}"
    plen=${#p}
    case "$target" in
      "$p"|"$p"/*)
        if [[ $plen -gt $best_len ]]; then best_len=$plen; best_idx=$i; fi
        ;;
    esac
    i=$((i+1))
  done
  if [[ $best_idx -ge 0 ]]; then
    printf '%s|%s|%s|%s\n' "${REGISTRY_TIER[$best_idx]}" "${REGISTRY_MODULE[$best_idx]}" "${REGISTRY_RISK[$best_idx]}" "${REGISTRY_DESC[$best_idx]}"
  else
    printf 'unknown|||No matching rule — inspect manually.\n'
  fi
}
