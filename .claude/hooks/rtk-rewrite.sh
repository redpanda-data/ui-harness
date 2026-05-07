#!/bin/bash
# PreToolUse Bash: auto-prefix known bloaters with `rtk` for per-command
# output compression. Complements llm-truncate.sh (post-output byte cap).
#
# Mechanism: `rtk hook claude` reads the tool_input JSON from stdin and
# emits a Claude Code hookSpecificOutput with `updatedInput.command`
# rewritten to `rtk <command>` when rtk has a filter for it.
#
# Fail-open: if rtk is not installed, exit 0 silently. rtk-install-check.sh
# (SessionStart) nudges the user once per session.
#
# Run LAST in the PreToolUse Bash chain so upstream hooks (deny rules,
# bash-verbose-guard nudges) see the original command, not the rtk-wrapped
# form — preserves their regex accuracy.

set -eo pipefail
trap 'exit 0' ERR

if ! command -v rtk >/dev/null 2>&1; then
  exit 0
fi

exec rtk hook claude
