#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "tsx"
hook_skip_ui_dirs
hook_skip_generated

# Skip if React Compiler not installed
_has_compiler=false
if [ -f "package.json" ] && grep -q 'babel-plugin-react-compiler' package.json 2>/dev/null; then
  _has_compiler=true
elif ls rsbuild.config.* vite.config.* babel.config.* .babelrc* 2>/dev/null | head -1 | while read cfg; do
  grep -q 'react-compiler' "$cfg" 2>/dev/null && echo "found"
done | grep -q "found" 2>/dev/null; then
  _has_compiler=true
fi

if [ "$_has_compiler" = false ]; then
  exit 0
fi

# Skip 'use no memo' files
if head -5 "$file_path" | grep -qF "'use no memo'" || head -5 "$file_path" | grep -qF '"use no memo"'; then
  exit 0
fi

# Annotation mode: only check 'use memo' files
if [ "${REACT_COMPILER_MODE:-infer}" = "annotation" ]; then
  if ! head -5 "$file_path" | grep -qF "'use memo'" && ! head -5 "$file_path" | grep -qF '"use memo"'; then
    exit 0
  fi
fi

hook_get_added_lines

# ── Check 1: Ban manual memoization ─────────────────────────────
found=""
if echo "$added_lines" | grep -qE '\buseMemo\b'; then
  found="useMemo"
elif echo "$added_lines" | grep -qE '\buseCallback\b'; then
  found="useCallback"
elif echo "$added_lines" | grep -qE '\bReact\.memo\b|\bmemo\('; then
  found="React.memo"
fi

if [ -n "$found" ]; then
  hook_block "Remove $found — Compiler auto-memoizes. Or add 'use no memo' at file top."
fi

# ── Check 2: Derived state via useEffect anti-pattern ────────────
if echo "$added_lines" | grep -qE '\buseEffect\b'; then
  file_content=$(cat "$file_path")
  if echo "$file_content" | grep -qE 'const \[.*,\s*set\w+\]\s*=\s*useState' && \
     echo "$added_lines" | grep -qE 'useEffect\(\(\)\s*=>\s*\{?\s*set'; then
    hook_block "No useState+useEffect for derived state. Compute inline during render."
  fi
fi

# ── Check 3: useRef as memoization cache ─────────────────────────
if echo "$added_lines" | grep -qE 'useRef\(' && \
   echo "$added_lines" | grep -qE '\.current\s*=.*\?\?=|\.current\s*\?\?=|if.*\.current.*===.*null'; then
  hook_block "No useRef as memo cache. Compiler owns caching — write plain derived values."
fi

exit 0
