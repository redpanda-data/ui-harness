#!/usr/bin/env bash
set -euo pipefail

# Claude Code exec-form hook trampoline.
# Usage from settings.json:
#   {"type":"command","command":".claude/hooks/run-hook.sh","args":["hook-name.sh"]}
# Keeps hook config free of shell quoting while preserving the existing
# repo-local .claude/hooks/*.sh implementation shared by Codex shims.

hook_name="${1:-}"
if [ -z "$hook_name" ]; then
  echo "run-hook.sh: missing hook script name" >&2
  exit 0
fi

case "$hook_name" in
  */*|*..*|*.sh) ;;
  *) hook_name="$hook_name.sh" ;;
esac

case "$hook_name" in
  /*|*../*|../*|*/../*|*/*)
    echo "run-hook.sh: refusing unsafe hook path: $hook_name" >&2
    exit 0
    ;;
esac

root=""
if root_candidate=$(git rev-parse --show-toplevel 2>/dev/null); then
  root="$root_candidate"
elif [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  root="$CLAUDE_PROJECT_DIR"
elif [ -d .claude/hooks ]; then
  root="$PWD"
fi

if [ -z "$root" ]; then
  echo "run-hook.sh: could not locate repo root for $hook_name" >&2
  exit 0
fi

hook_path="$root/.claude/hooks/$hook_name"
if [ ! -x "$hook_path" ]; then
  # Existing shell shims treated missing hooks as no-op. Preserve that behavior
  # because many plugin setups install a subset of hooks.
  exit 0
fi

exec "$hook_path"
