# Codex Compatibility Reference

## Current Codex Hook Compatibility

Codex hook support is no longer Bash-only. Prefer direct translation first.

## Compatibility matrix

| Claude Code hook shape | Codex target | Status | Notes |
| --- | --- | --- | --- |
| `SessionStart` command | `SessionStart` | direct | Codex supports start-source matchers. |
| `UserPromptSubmit` command | `UserPromptSubmit` | direct | Codex ignores matchers for this event. |
| `PreToolUse` / `PostToolUse` `Bash` | same event + matcher | direct | Regex matcher over tool name. |
| `PreToolUse` / `PostToolUse` `Edit|Write` | same event + `"matcher": "Edit\\|Write"` | direct | Codex maps aliases to `apply_patch`. |
| `PreToolUse` / `PostToolUse` `apply_patch` | same event + `apply_patch` | direct | Prefer `Edit\\|Write` when sharing config with Claude. |
| `PreToolUse` / `PostToolUse` `mcp__.*` | same event + MCP matcher | direct | Hook scripts must tolerate Codex MCP payload differences. |
| `PermissionRequest` `Bash`, `apply_patch`, MCP | `PermissionRequest` | direct with shim | Only if script handles Codex decision fields. |
| Claude `if` filters | split script-side checks | direct with shim | Codex matcher is regex over tool name, not args. Move arg logic into script. |
| `PostToolUseFailure` | none or `Stop` fallback | fallback only | Codex does not provide same event in this compatibility layer. |
| `PostToolBatch`, `FileChanged`, `PreCompact`, `PostCompact`, `SessionEnd`, `Notification`, subagent events | none | unsupported | Do not pretend parity. Use AGENTS.md soft guidance or explicit scripts. |
| `http`, `prompt`, `agent`, `mcp_tool` hook handlers | command shim or unsupported | direct with shim / unsupported | Codex compatibility target is command hooks. |

## Direct `.codex/hooks.json` template

Generate from `.claude/settings.json`. Copy supported events directly. Add the batch checker only as fallback only for hooks that cannot safely run per-event.

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
        "matcher": "Edit\\|Write\\|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/violation-nudge.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/enforce-toolchain.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/conventional-commits-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      },
      {
        "matcher": "mcp__.*",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/mcp-ban.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit\\|Write",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/react-rules-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/tailwind-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/unhappy-path-check.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      },
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
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/biome-autofix.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          },
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/typecheck-stop.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "Bash|mcp__.*|Edit\\|Write",
        "hooks": [
          {
            "type": "command",
            "command": "f=$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/codex-permission-request-guard.sh; [ -x \"$f\" ] && exec \"$f\"; exit 0"
          }
        ]
      }
    ]
  }
}
```

## Batch fallback: `codex-batch-check.sh`

Stop hook wrapper. Runs selected Claude `PostToolUse`-style checks on changed files when direct mapping is impossible or unsafe. Reuses `.claude/hooks/` scripts. No duplication. Handles JS/TS, CSS/SCSS via `tailwind-check`, and `package.json` via `bundle-guard`.

> Script: [`scripts/codex-batch-check.sh`](scripts/codex-batch-check.sh)

Use this fallback only when:

- a Claude event has no Codex equivalent;
- a hook depends on Claude-only output fields;
- a hook needs batch-level state rather than single tool payload;
- you deliberately want end-of-turn enforcement instead of immediate feedback.

Do not use batch fallback for ordinary `PostToolUse` `Edit|Write` checks. Map those directly.

`_hook-lib.sh` and `shared/hook-lib.sh` must be accessible alongside check scripts.

## Plugin-bundled hooks

Codex supports plugin-bundled hooks when `[features].plugin_hooks = true`. Prefer packaging reusable compatibility hooks in a plugin rather than copying repo-local config everywhere.

- Default path: `hooks/hooks.json` inside plugin root.
- Manifest override: `.codex-plugin/plugin.json` can point `hooks` to a path or inline object.
- Codex exposes `PLUGIN_ROOT` / `PLUGIN_DATA` and compatibility env vars `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA`.
- Plugin hooks need user trust review before they run.

## Output compatibility notes

- `PreToolUse` and `PermissionRequest` support `systemMessage`; do not rely on Claude-only `additionalContext` here.
- `SessionStart`, `UserPromptSubmit`, and `Stop` can return shared JSON output fields.
- `continue`, `stopReason`, and `suppressOutput` are not portable for `PreToolUse` in this layer.
- Move Claude `if` conditions into command scripts because Codex matchers do not inspect tool arguments.

## Codex limitations: subagent and lifecycle events

Codex does not fully match Claude Code events such as `SubagentStart`, `SubagentStop`, `PostToolBatch`, `FileChanged`, `PreCompact`, `PostCompact`, and `SessionEnd` in this compatibility layer.

Self-review loop enforcement that depends on subagent hooks should become soft guidance in `AGENTS.md`. Findings schema (`agents/findings-schema.md`) and agent definitions remain readable by Codex, but output enforcement is best effort.

## AGENTS.md

Generated at repo root: [`AGENTS.md`](../AGENTS.md). Enforced rules as soft guidance for Codex. Customize per installed skills.
