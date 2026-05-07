#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: useMutation result should end in *Mutation ──────────
# Convention: const deleteMutation = useMutation(...)
# Not: const deleteHandler = useMutation(...)

mutation_vars=$(echo "$added_lines" | grep -E '(const|let)\s+\w+\s*=\s*useMutation\(' | grep -vE 'Mutation\s*=' || true)

if [ -n "$mutation_vars" ]; then
  sample=$(echo "$mutation_vars" | head -2 | sed 's/^+//' | tr '\n' ' ')
  if ! hook_has_escape "mutation-naming"; then
    hook_warn "useMutation result should be named *Mutation (e.g. deleteMutation). Found: $sample. Escape: // allow: mutation-naming [reason]" "mutation-naming"
  fi
fi

# ── Check 2: Custom mutation hooks should be named use*Mutation ──

hook_defs=$(echo "$added_lines" | grep -E '(export\s+)?(function|const)\s+use\w+\s*=' | grep -iE 'mutat' | grep -vE 'Mutation' || true)

if [ -n "$hook_defs" ]; then
  if ! hook_has_escape "mutation-naming"; then
    hook_warn "Custom mutation hooks should be named use*Mutation (e.g. useDeleteUserMutation). Escape: // allow: mutation-naming [reason]" "mutation-naming-hook"
  fi
fi

exit 0
