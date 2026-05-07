#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_bash

# Check if this is a git commit command with -m flag
if ! echo "$command" | grep -qE 'git\s+commit\b.*\s+-m\s'; then
  exit 0
fi

# Extract the commit message from various formats
msg=""

# Try simple quoted extraction first
msg=$(echo "$command" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$msg" ]; then
  msg=$(echo "$command" | sed -n "s/.*-m[[:space:]]*'\\([^']*\\)'.*/\\1/p")
fi

# Try heredoc/multi-line — match both type(scope): and type: patterns
if [ -z "$msg" ]; then
  conventional_line=$(echo "$command" | grep -E '^\s*(feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert)(\(|:)' | head -1 | sed 's/^[[:space:]]*//')
  if [ -n "$conventional_line" ]; then
    msg="$conventional_line"
  else
    exit 0
  fi
fi

# Split into subject line
subject=$(echo "$msg" | head -1)

# ── Validate type ──────────────────────────────────────────────
valid_types="feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert"

if ! echo "$subject" | grep -qE "^($valid_types)\("; then
  if echo "$subject" | grep -qE "^($valid_types):"; then
    hook_deny "Missing scope. Use: type(scope): description."
  fi
  hook_deny "Invalid commit type. Use: feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert."
fi

# ── Validate scope ─────────────────────────────────────────────
if ! echo "$subject" | grep -qE "^($valid_types)\([a-z][a-z0-9_-]*\):"; then
  hook_deny "Invalid scope. Lowercase alphanumeric+hyphens: type(my-scope): desc."
fi

# ── Extract description ────────────────────────────────────────
desc=$(echo "$subject" | sed -E "s/^($valid_types)\([a-z][a-z0-9_-]*\):[[:space:]]*//" )

if [ -z "$desc" ]; then
  hook_deny "Missing description after type(scope):."
fi

# ── Validate: lowercase first letter ──────────────────────────
first_char=$(echo "$desc" | cut -c1)
if echo "$first_char" | grep -qE '[A-Z]'; then
  hook_deny "Description must start lowercase."
fi

# ── Validate: no trailing period ───────────────────────────────
if echo "$desc" | grep -qE '\.$'; then
  hook_deny "No trailing period in description."
fi

# ── Validate length (5-72 chars) ──────────────────────────────
desc_len=${#desc}
if [ "$desc_len" -lt 5 ]; then
  hook_deny "Description too short ($desc_len chars, min 5)."
fi

if [ "$desc_len" -gt 72 ]; then
  hook_deny "Description too long ($desc_len chars, max 72). Move details to body."
fi

# ── Suggest body for feat/fix ──────────────────────────────────
body=$(echo "$msg" | tail -n +2 | sed '/^$/d')
commit_type=$(echo "$subject" | sed -E "s/^($valid_types)\(.*/\1/")

if [ -z "$body" ] && { [ "$commit_type" = "feat" ] || [ "$commit_type" = "fix" ]; }; then
  echo "{\"decision\":\"allow\",\"reason\":\"Consider adding body for $commit_type commits.\"}" >&2
  exit 0
fi

exit 0
