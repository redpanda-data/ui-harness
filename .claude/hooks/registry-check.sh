#!/bin/bash
set -eo pipefail

# Only run in repos that ARE the UI registry (have registry.json at root)
# Consumer repos that USE registry components don't need this check —
# the orchestration-guidance.sh registry sync nudge handles consumers
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if [ ! -f "$repo_root/registry.json" ]; then
  exit 0
fi

# Source hook-lib for session-scoped file tracking
source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

# Session-scoped: only check files this session touched
if type hook_session_changed_files &>/dev/null; then
  changed=$(hook_session_changed_files)
else
  changed=$(git diff --name-only HEAD 2>/dev/null || true)
fi

if [ -z "$changed" ]; then
  exit 0
fi

ui_changed=$(echo "$changed" | grep -E 'redpanda-ui/' || true)

if [ -z "$ui_changed" ]; then
  exit 0
fi

# Check if registry.json was also updated
registry_changed=$(echo "$changed" | grep -F 'registry.json' || true)

if [ -z "$registry_changed" ]; then
  # Write to shared findings — quality-gate-stop.sh aggregates
  _session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
  echo "redpanda-ui modified, registry.json not rebuilt. Run: bun run build:registry && bunx changeset" >> "$_session_dir/stop-findings" 2>/dev/null
  exit 0
fi

# Check if a changeset was added (.changeset/*.md, excluding config.json)
changeset_added=$(echo "$changed" | grep -E '^\.changeset/.*\.md$' || true)

if [ -z "$changeset_added" ]; then
  _session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
  echo "registry.json rebuilt but no changeset added. Run: bunx changeset" >> "$_session_dir/stop-findings" 2>/dev/null
  exit 0
fi

exit 0
