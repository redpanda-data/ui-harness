#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Block weakening of TypeScript strictness in tsconfig files.
#
# If a tsconfig edit disables any of these (explicitly false) or
# removes 'strict: true', the session is blocked with remediation.
#
#   strict              — master switch
#   noImplicitAny       — implicit `any` errors
#   strictNullChecks    — null/undefined narrowing
#   noUncheckedIndexedAccess — array/record access returns T | undefined
#   noImplicitOverride  — prevents accidental method override
#
# Escape hatch: `// allow: tsconfig-strict [reason]` anywhere in the file.

hook_parse_edit_write

case "$file_path" in
  *tsconfig.json|*tsconfig.*.json) : ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

# Strip comments — tsconfig supports JSONC-style // and /* */.
# Portable perl usage (available on Mac/Linux/Git-Bash); fallback to sed.
if command -v perl >/dev/null 2>&1; then
  content=$(perl -0pe 's{//[^\n]*}{}g; s{/\*.*?\*/}{}gs' "$file_path" 2>/dev/null || cat "$file_path")
else
  content=$(cat "$file_path")
fi

# Escape hatch inside file
if grep -qE '//\s*allow:\s*tsconfig-strict' "$file_path" 2>/dev/null; then
  exit 0
fi

_violations=""

# Explicit false is always a block. Use single-quotes in error text so
# the hook's JSON-embedded systemMessage stays valid (hook_block does
# not escape double-quotes).
for _flag in strict noImplicitAny strictNullChecks noUncheckedIndexedAccess noImplicitOverride strictFunctionTypes noFallthroughCasesInSwitch; do
  if printf '%s' "$content" | grep -qE "\"$_flag\"\\s*:\\s*false"; then
    _violations="${_violations} | '$_flag': false — must be true"
  fi
done

if ! printf '%s' "$content" | grep -qE '"strict"\s*:\s*true'; then
  if ! printf '%s' "$content" | grep -qE '"extends"\s*:'; then
    _violations="${_violations} | 'strict': true missing (and no base config extended)"
  fi
fi

if [ -n "$_violations" ]; then
  hook_block "tsconfig strictness weakened —${_violations}. Restore the strict flags. Strictness is the type-level enforcement that keeps 'any' and friends from spreading. Escape hatch: // allow: tsconfig-strict [reason]" "tsconfig-strict"
fi

exit 0
