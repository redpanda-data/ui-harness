#!/bin/bash
set -euo pipefail

# PostToolUse hook: warn when known-heavy dependencies are added to package.json.
# Only checks production "dependencies" (not devDependencies).

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

hook_parse_edit_write

# Only check package.json files
case "$file_path" in
  */package.json|package.json) ;;
  *) exit 0 ;;
esac

hook_get_added_lines

deps_block=$(jq -r '.dependencies // {} | keys[]' "$file_path" 2>/dev/null || true)

# ── Check: moment ──
if echo "$added_lines" | grep -qE '"moment"' && echo "$deps_block" | grep -qx 'moment'; then
  hook_block "No moment (330KB). Use date-fns (22KB)."
fi

# ── Check: lodash (but not lodash-es or lodash/) ──
if echo "$added_lines" | grep -qE '"lodash"' && ! echo "$added_lines" | grep -qE '"lodash-es"|"lodash/' && echo "$deps_block" | grep -qx 'lodash'; then
  hook_block "No full lodash (530KB). Use lodash-es or per-function imports."
fi

# ── Check: jquery ──
if echo "$added_lines" | grep -qE '"jquery"' && echo "$deps_block" | grep -qx 'jquery'; then
  hook_block "No jQuery in React. Use native DOM APIs or refs."
fi

# ── Check: core-js ──
if echo "$added_lines" | grep -qE '"core-js"' && echo "$deps_block" | grep -qx 'core-js'; then
  hook_block "No full core-js (250KB+). Use specific polyfills or @babel/preset-env useBuiltIns:'usage'."
fi

# ── Check: classnames ──
if echo "$added_lines" | grep -qE '"classnames"' && echo "$deps_block" | grep -qx 'classnames'; then
  hook_block "No classnames (1.8KB). Use clsx (330B)."
fi

exit 0
