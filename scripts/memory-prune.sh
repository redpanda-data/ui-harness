#!/bin/bash
set -euo pipefail

# Prune auto-memory entries older than N days (default 90).
# Scans ~/.claude/projects/<project>/memory/*.md, checks file mtime,
# and removes stale entries from MEMORY.md index.
#
# Usage:
#   scripts/memory-prune.sh                 # dry run, 90-day cutoff
#   scripts/memory-prune.sh --apply         # delete stale files
#   scripts/memory-prune.sh --days 30       # custom cutoff
#   scripts/memory-prune.sh --dir /path     # custom memory dir

DAYS=90
APPLY=0
MEM_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    --dir) MEM_DIR="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

# Auto-detect memory dir if not given
if [ -z "$MEM_DIR" ]; then
  _project_slug=$(pwd | sed 's|/|-|g')
  MEM_DIR="$HOME/.claude/projects/${_project_slug}/memory"
fi

if [ ! -d "$MEM_DIR" ]; then
  echo "No memory dir at $MEM_DIR" >&2
  exit 0
fi

INDEX="$MEM_DIR/MEMORY.md"
STALE=()

# Find files older than N days, excluding MEMORY.md
while IFS= read -r -d '' f; do
  STALE+=("$f")
done < <(find "$MEM_DIR" -maxdepth 1 -name "*.md" ! -name "MEMORY.md" -mtime "+$DAYS" -print0 2>/dev/null)

if [ "${#STALE[@]}" -eq 0 ]; then
  echo "No memory entries older than $DAYS days in $MEM_DIR"
  exit 0
fi

echo "Stale memory entries (mtime >$DAYS days):"
for f in "${STALE[@]}"; do
  _age_days=$(( ($(date +%s) - $(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")) / 86400 ))
  echo "  $(basename "$f") (${_age_days}d)"
done

if [ "$APPLY" = "0" ]; then
  echo ""
  echo "Dry run. Re-run with --apply to delete."
  exit 0
fi

# Remove files + prune MEMORY.md lines referencing them
for f in "${STALE[@]}"; do
  _name=$(basename "$f")
  rm -f "$f"
  if [ -f "$INDEX" ]; then
    # Remove any line referencing the deleted file
    sed -i.bak "/($_name)/d" "$INDEX" 2>/dev/null && rm -f "$INDEX.bak"
  fi
done

echo "Pruned ${#STALE[@]} entries."
