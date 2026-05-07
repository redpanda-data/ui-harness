#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Enforce: a submittable form (useProtoForm + handleSubmit) must render
# a top-level error summary for screen readers and visual scanning.
# Accept any of:
#   - <FormErrorSummary ...>
#   - role="alert" on an element rendering form errors
#   - aria-live on a status region
# Without one, users hit submit, errors appear inline only, and AT /
# offscreen errors are invisible.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

file_content=$(cat "$file_path")

# Gate 1: must be a form handler.
if ! echo "$file_content" | grep -qE 'useProtoForm\b|useForm\('; then
  exit 0
fi
if ! echo "$file_content" | grep -qE 'handleSubmit\('; then
  exit 0
fi

# Gate 2: summary primitive present?
if echo "$file_content" | grep -qE 'FormErrorSummary|role="alert"|role={"alert"}|aria-live='; then
  exit 0
fi

# Skip tiny inline forms (single-field search, filter bars) — heuristic:
# file must render more than one FormField / ProtoField to earn the nudge.
_field_count=$(echo "$file_content" | grep -cE '<(FormField|ProtoField)\b' || true)
if [ "${_field_count:-0}" -lt 2 ]; then
  exit 0
fi

if hook_has_escape "form-error-summary"; then
  exit 0
fi

hook_warn "Multi-field form with no <FormErrorSummary /> / role=\"alert\" / aria-live region. Submit-time errors stay inline-only — screen readers miss them and offscreen errors are invisible. Render a summary from form.formState.errors (or useProtoForm.getNestedErrors). Escape: // allow: form-error-summary [reason]" "form-error-summary"

exit 0
