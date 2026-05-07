#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_get_added_lines

# Read full file for context checks
file_content=$(cat "$file_path")
imports_zustand=false
if echo "$file_content" | grep -qE "from\s+['\"]zustand"; then
  imports_zustand=true
fi

# ── Check 1: Ban single-parens create<T>() — must be create<T>()() ──

if [ "$imports_zustand" = true ]; then
  if echo "$added_lines" | grep -qE 'create<[^>]+>\(' && ! echo "$added_lines" | grep -qE 'create<[^>]+>\(\)\s*\('; then
    hook_block "Use create<T>()() double-parens. Single-parens breaks middleware types."
  fi
fi

# ── Check 2: Ban inline object selectors — suggest useShallow ────────

if echo "$added_lines" | grep -qE 'use\w+Store\(.*=>\s*\(\{'; then
  hook_block "Wrap multi-field selector with useShallow. Inline object = new ref = infinite re-render."
fi

# ── Check 3: Ban localStorage/sessionStorage in zustand stores ──

if [ "$imports_zustand" = true ]; then
  if echo "$added_lines" | grep -qE '\b(localStorage|sessionStorage)\b'; then
    hook_block "No direct localStorage in stores. Use zustand persist middleware."
  fi
fi

exit 0
