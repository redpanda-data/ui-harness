#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_get_added_lines

# ── Check 1: Block new biome-ignore noExplicitAny ─────────────────
# This rule is absolute — fix types properly instead of suppressing.

if echo "$added_lines" | grep -qE 'biome-ignore.*noExplicitAny'; then
  hook_block "No biome-ignore for noExplicitAny. Fix types properly: type guards, generics, schema validation. See CLAUDE.md."
fi

# ── Check 2: Warn on any new biome-ignore or @ts-ignore ──────────
# Every suppression becomes a pattern LLMs copy. Resist adding them.

# @ts-ignore/@ts-expect-error now owned by as-cast-check.sh
ignore_lines=$(echo "$added_lines" | grep -E 'biome-ignore' | grep -vE 'noExplicitAny' || true)

if [ -n "$ignore_lines" ]; then
  sample=$(echo "$ignore_lines" | head -2 | sed 's/^+//' | tr '\n' ' ')
  if ! hook_has_escape "lint-ignore"; then
    hook_warn "New lint suppression added. Every ignore pattern gets copied by LLMs — fix the type instead. Found: $sample. Escape: // allow: lint-ignore [reason]" "biome-ignore-warn"
  fi
fi

exit 0
