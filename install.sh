#!/usr/bin/env bash
# install.sh — link skills/macautoclean/ into ~/.claude/skills/macautoclean so Claude Code can discover it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO_ROOT/skills/macautoclean"
DST="$HOME/.claude/skills/macautoclean"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: $SRC not found. Are you in the repo root?" >&2
  exit 1
fi

mkdir -p "$HOME/.claude/skills"

if [[ -L "$DST" ]]; then
  rm "$DST"
elif [[ -e "$DST" ]]; then
  echo "ERROR: $DST exists and is not a symlink. Move it aside first." >&2
  exit 1
fi

ln -s "$SRC" "$DST"
chmod +x "$SRC"/scripts/*.sh 2>/dev/null || true

cat <<EOF
✓ Installed: $DST -> $SRC

Try it in any Claude Code session:
  "Clean my Mac" / "全自动清理 Mac"

Or run the CLI directly:
  $SRC/scripts/autoclean.sh             # scan only
  $SRC/scripts/autoclean.sh --execute --yes
  $SRC/scripts/advisor.sh --interactive
  $SRC/scripts/schedule.sh
EOF
