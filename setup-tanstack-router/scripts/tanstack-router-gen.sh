#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

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
