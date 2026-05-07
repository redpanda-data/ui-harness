#!/bin/bash
set -euo pipefail

# Thin wrapper around Vercel's agent-browser for the skills harness.
# Invoked by /qa, /go phase 4 browser smoke, and any skill that needs
# AI-visible browser state (NOT Playwright test code -- those keep
# using @playwright/test directly).
#
# Philosophy (see docs/rfc/browser-daemon.md):
# - Agent-browser is a Rust CLI + persistent daemon. Auto-spawns,
#   cookies preserved between commands, accessibility-tree refs
#   (@e1, @e2 style) instead of full DOM dumps.
# - ~91% token reduction vs mcp__claude-in-chrome__* MCP round trips
#   (back-of-envelope, to be measured post-adoption).
#
# Install hint printed if agent-browser missing. Graceful skip so
# skills can still run without it.
#
# Usage: identical pass-through to agent-browser CLI.
#   scripts/skills-browser.sh navigate https://app.example.com
#   scripts/skills-browser.sh read
#   scripts/skills-browser.sh click @e5
#   scripts/skills-browser.sh type @e12 "value"
#   scripts/skills-browser.sh screenshot --out /tmp/s.png
#   scripts/skills-browser.sh batch < ops.json

if ! command -v agent-browser >/dev/null 2>&1; then
  cat >&2 <<'EOF'
agent-browser not installed. Choose one:

  brew install vercel/tap/agent-browser
  cargo install agent-browser
  curl -fsSL https://get.agent-browser.dev | sh

Once installed, re-run. Skill will skip browser checks until available.
EOF
  exit 127
fi

exec agent-browser "$@"
