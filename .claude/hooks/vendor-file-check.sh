#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Extract file path directly — don't use hook_parse_edit_write which
# exits on non-existent files. Vendor paths need checking even for Write (new files).
_hook_input=$(cat)
_hook_tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$_hook_tool_name" != "Edit" ] && [ "$_hook_tool_name" != "Write" ]; then
  exit 0
fi

file_path=$(echo "$_hook_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
if [ -z "$file_path" ]; then
  exit 0
fi

# ── Scope: frontend files only (skip Go, Python, backend, etc.) ──
case "$file_path" in
  *.ts|*.tsx|*.css|*.scss|*.mdx) ;;
  *) exit 0 ;;
esac

# ── Block edits to vendor/registry/generated UI library directories ──
# These files are installed by CLIs (fumadocs, shadcn, redpanda-ui registry)
# and should not be modified directly. Pre-existing lint errors in these dirs
# are not our problem.

_blocked_dirs="redpanda-ui|components/ui/registry|vendor|fumadocs"

if echo "$file_path" | grep -qE "/($_blocked_dirs)/"; then
  # Allow escape hatch for intentional vendor patches
  if [ -f "$file_path" ] && grep -qE '//\s*allow:\s*vendor-edit' "$file_path" 2>/dev/null; then
    exit 0
  fi
  _dir=$(echo "$file_path" | grep -oE "($_blocked_dirs)" | head -1)
  echo "{\"suppressOutput\":true,\"systemMessage\":\"Editing vendor/registry file in $_dir/. These are CLI-installed — don't modify directly. If fixing pre-existing lint, skip the file.\"}" >&2
  exit 2
fi

# Also check for @generated marker in first 5 lines
if [ -f "$file_path" ]; then
  _header=$(head -5 "$file_path" 2>/dev/null || true)
  if echo "$_header" | grep -qE '@generated|DO NOT EDIT|AUTO-GENERATED'; then
    echo '{"suppressOutput":true,"systemMessage":"Editing auto-generated file. Regenerate from source instead of editing directly."}' >&2
    exit 2
  fi
fi

exit 0
