#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Enforce: form.setValue(name, value) must pass { shouldDirty: true,
# shouldValidate: true } options unless intentional. Without options,
# value updates silently and validation state goes stale — surprising
# users and bypassing resolver feedback.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# Gate: only hunks that touch setValue
if ! echo "$added_lines" | grep -qE '\.setValue\('; then
  exit 0
fi

# Multiline scan the file for setValue calls lacking shouldDirty/shouldValidate.
# Grep for setValue(...) arguments — if the call closes on same line with
# only 2 args (no options object), flag it.
_bad=$(echo "$added_lines" | grep -E '\.setValue\(' | grep -vE 'shouldDirty|shouldValidate' || true)

if [ -z "$_bad" ]; then
  exit 0
fi

# Filter out setValue calls that span multiple lines (no closing paren
# on same line). Same-line closers without options object are the clear
# violation — nested wrappers ({ ... }) after the call are fine.
_real_bad=$(echo "$_bad" | grep -E '\.setValue\([^)]*\)' || true)

if [ -z "$_real_bad" ]; then
  exit 0
fi

if hook_has_escape "setvalue-options"; then
  exit 0
fi

hook_warn "form.setValue() missing { shouldDirty: true, shouldValidate: true } — value updates silently, validation goes stale. Pass options unless the silence is intentional. Escape: // allow: setvalue-options [reason]" "setvalue-options"

exit 0
