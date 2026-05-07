#!/bin/bash
set -euo pipefail

# Guard: CLAUDE_ENV_FILE may not exist during /clear-triggered SessionStart
CLAUDE_ENV_FILE="${CLAUDE_ENV_FILE:-}"

# LLM-friendly test output: only show failures, suppress passing tests
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export AI_AGENT=1" >> "$CLAUDE_ENV_FILE"
  echo "export CLAUDECODE=1" >> "$CLAUDE_ENV_FILE"
fi

exit 0
