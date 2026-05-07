#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write

# Check if the file is in a routes directory
if ! echo "$file_path" | grep -qE '/routes/'; then
  exit 0
fi

# Only trigger for TS/TSX files
hook_filter_extensions "ts|tsx"

# Regenerate route tree silently
bun run generate:routes > /dev/null 2>&1 || true

echo '{"suppressOutput":true}' >&2
exit 0
