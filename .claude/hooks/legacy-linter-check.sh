#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_get_added_lines

# ── Check 1: eslint directive comments ────────────────────────────
# Project uses Biome, not ESLint. eslint-disable comments are dead
# weight and signal wrong toolchain knowledge.

if echo "$added_lines" | grep -qE '(//|/\*)\s*eslint-disable'; then
  hook_block "ESLint directive found. Project uses Biome, not ESLint. Convert to biome-ignore or fix the code."
fi

if echo "$added_lines" | grep -qF 'eslint-enable'; then
  hook_block "eslint-enable found. Project uses Biome, not ESLint. Remove eslint directives."
fi

# ── Check 2: prettier directive comments ──────────────────────────

if echo "$added_lines" | grep -qE '(//|/\*|<!--)\s*prettier-ignore'; then
  hook_block "prettier-ignore found. Project uses Biome for formatting. Remove prettier directives."
fi

exit 0
