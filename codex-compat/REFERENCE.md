# Codex Compatibility Reference

## codex-batch-check.sh

Stop hook wrapper. Runs all PostToolUse Edit|Write checks on changed files.
Reuses `.claude/hooks/` scripts. No duplication.
Handles JS/TS, CSS/SCSS (tailwind-check), package.json (bundle-guard).

> Script: [`scripts/codex-batch-check.sh`](scripts/codex-batch-check.sh)

## .codex/hooks.json template

Generate from `.claude/settings.json`. Copy PreToolUse Bash, SessionStart, Stop hooks direct. Add batch checker as Stop hook.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/session-env.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/llm-env.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/user-prompt-context.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/intent-detect.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/enforce-toolchain.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/llm-test-flags.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/conventional-commits-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/llm-truncate.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.codex/hooks/codex-batch-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0",
            "statusMessage": "Running code quality checks on changed files..."
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/biome-autofix.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/typecheck-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/react-doctor-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/registry-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/orchestration-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/test-perf-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/lifecycle-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/violation-summary-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ]
  }
}
```

**Notes:**
- SessionStart, UserPromptSubmit, PreToolUse Bash, PostToolUse Bash, Stop hooks identical on Codex
- PostToolUse Edit|Write NOT in `.codex/hooks.json`. `codex-batch-check.sh` auto-discovers `*-check.sh` scripts at Stop time
- `_hook-lib.sh` and `shared/hook-lib.sh` must be accessible alongside check scripts

## Codex Limitations: SubagentStart/SubagentStop

Codex **no** support `SubagentStart`/`SubagentStop`. Claude Code only.

Self-review loop (phase 4b) needs these for session context injection + structured findings validation. **Workaround**: soft guidance in AGENTS.md. Findings schema (`agents/findings-schema.md`) markdown -- works anywhere. Agent definitions (`self-reviewer.md`, `adversarial-reviewer.md`, `code-reviewer.md`) readable by Codex. Output format best-effort without SubagentStop enforcement.

## AGENTS.md

Generated at repo root: [`AGENTS.md`](../AGENTS.md). Enforced rules as soft guidance for Codex. Customize per installed skills.