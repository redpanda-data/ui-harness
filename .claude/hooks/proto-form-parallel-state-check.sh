#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Enforce: a file that uses useProtoForm must not hold form-shape state
# in parallel useState hooks — that splits the source of truth, defeats
# protovalidate / resolver, and forces manual sync with custom
# validateXFields / surfaceXErrors workarounds.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

file_content=$(cat "$file_path")

# Gate: only proto-form files.
if ! echo "$file_content" | grep -qE 'useProtoForm\b'; then
  exit 0
fi

# Heuristic: a useState whose type annotation or initial value carries
# form-shape intent — Config, Auth, Credentials, Secret, Provider,
# Settings, FieldValues, Params, Schema — is suspicious.
_suspect_patterns='useState<\s*(Record<|Partial<|\w*Config|\w*Auth|\w*Credentials|\w*Secret|\w*Provider|\w*Settings|\w*Params|\w*FieldValues|\w*Schema|\w*Form)'

if echo "$file_content" | grep -qE "$_suspect_patterns"; then
  if hook_has_escape "proto-form-parallel-state"; then
    exit 0
  fi
  hook_warn "useState holds form-shape state beside useProtoForm — drift risk. Register the field via form.register / nested FormField / useFieldArray so protovalidate + resolver own validation. Escape: // allow: proto-form-parallel-state [reason]" "proto-form-parallel-state"
fi

exit 0
