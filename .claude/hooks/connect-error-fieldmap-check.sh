#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Enforce: when a form file handles a ConnectError onError, it must
# unpack BadRequest.FieldViolation into form.setError per field — not
# just toast the aggregated message. Missing per-field mapping loses
# server-side validation feedback (fields stay green while toast dies).

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

file_content=$(cat "$file_path")

# Gate: file must be a form handler (uses react-hook-form / useProtoForm)
# AND surface ConnectError errors (formatConnectError / ConnectError.from).
if ! echo "$file_content" | grep -qE 'useProtoForm|useForm\(|handleSubmit'; then
  exit 0
fi
if ! echo "$file_content" | grep -qE 'formatConnectError|ConnectError\.from|ConnectError<'; then
  exit 0
fi

# If file already wires per-field mapping, pass.
if echo "$file_content" | grep -qE '\.setError\(|setError\s*\(|fieldViolations|BadRequest'; then
  exit 0
fi

if hook_has_escape "connect-error-fieldmap"; then
  exit 0
fi

hook_warn "ConnectError surfaced with toast-only — lost server-side FieldViolation feedback. Unpack BadRequest.FieldViolation in onError and call form.setError({ type: 'server', message }) per field; reserve toast for non-field errors. Escape: // allow: connect-error-fieldmap [reason]" "connect-error-fieldmap"

exit 0
