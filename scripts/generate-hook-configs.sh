#!/bin/bash
set -euo pipefail

# Generate hook configuration files from skill-manifest.json (single source of truth).
#
# Inputs:
#   skill-manifest.json  — events → matcher → [hook scripts]
#
# Outputs:
#   .claude/settings.json        — Claude-compatible full hook surface, repo-local paths
#   hooks/hooks.json             — Claude-compatible full hook surface, plugin-root paths
#   .codex/hooks.json            — Codex-supported hook events only, repo-local paths
#   hooks/codex-hooks.json       — Codex-supported hook events only, plugin-root paths
#
# Flags:
#   --check    compare existing files to would-be generated; exit 1 if drift
#   --apply    write the generated files (default)
#
# Rationale: prevents drift bug (v<2.2.0) where settings.json and hooks.json
# diverged. Change manifest once, regenerate both. Verifies referenced scripts
# exist on disk.

MODE="${1:---apply}"
MODE="${MODE#--}"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

MANIFEST="skill-manifest.json"
[ -f "$MANIFEST" ] || { echo "ERROR: $MANIFEST not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq required" >&2; exit 1; }

# Build hook config from manifest using prefix string.
# jq auto-escapes embedded " → \" during JSON serialization.
_build() {
  local prefix="$1"
  jq --arg prefix "$prefix" '
    {
      hooks: (
        .hooks | to_entries | map(
          .key as $event
          | {
              key: $event,
              value: (
                .value | to_entries | map(
                  (if .key == "" then {} else {matcher: .key} end) + {
                    hooks: (.value | map({
                      type: "command",
                      command: ("f=" + $prefix + "/" + . + "; [ -x \"$f\" ] && exec \"$f\"; exit 0")
                    }))
                  }
                )
              )
            }
        ) | from_entries
      )
    }
  ' "$MANIFEST"
}

SETTINGS_PREFIX='$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks'
PLUGIN_PREFIX='"${CLAUDE_PLUGIN_ROOT}/.claude/hooks'
# Hack: opening quote only; closing quote comes right before `; [ -x ...`
# We want: f="${CLAUDE_PLUGIN_ROOT}/.claude/hooks/X.sh"; [ -x ...
# Assembled string inside jq: "f=" + prefix + "/" + script + "; [ -x ..."
# Needs close-quote before the `;`. Use suffix via jq sub:

NEW_SETTINGS=$(_build "$SETTINGS_PREFIX")

# Codex supports a smaller lifecycle surface than Claude Code. Generate a
# best-effort Codex mapping instead of only dropping unsupported events:
# - direct equivalents stay direct,
# - Claude PostToolUseFailure maps to Codex PostToolUse (Codex includes failures),
# - Codex PermissionRequest gets an adapter that reuses approval-safe deny guards.
CODEX_EVENTS='["SessionStart","PreToolUse","PostToolUse","UserPromptSubmit","Stop"]'
_build_codex() {
  local prefix="$1"
  local close_quote="${2:-}"
  jq --arg prefix "$prefix" --arg close "$close_quote" --argjson events "$CODEX_EVENTS" '
    def command_hook($script): {
      type: "command",
      command: ("f=" + $prefix + "/" + $script + $close + "; [ -x \"$f\" ] && exec \"$f\"; exit 0")
    };
    . as $root
    | def groups_for($event):
      ($root.hooks[$event] // {})
      | to_entries
      | map(
          (if .key == "" then {} else {matcher: .key} end) + {
            hooks: (.value | map(command_hook(.)))
          }
        );
    def supported_direct:
      $root.hooks
      | with_entries(select(.key as $event | $events | index($event)))
      | to_entries
      | map(.key as $event | {key: $event, value: groups_for($event)})
      | from_entries;

    {hooks: supported_direct}
    # Codex PostToolUse runs for failed Bash commands too, so preserve the
    # Claude failure categorizer by appending it to PostToolUse.
    | if ($root.hooks.PostToolUseFailure? // null) != null then
        .hooks.PostToolUse = ((.hooks.PostToolUse // []) + groups_for("PostToolUseFailure"))
      else . end
    # Codex-only event: run an adapter during approval prompts so approval-time
    # Bash/MCP requests still get the same hard-deny guardrails.
    | .hooks.PermissionRequest = [
        {
          matcher: "Bash|mcp__.*",
          hooks: [command_hook("codex-permission-request-guard.sh")]
        }
      ]
  ' "$MANIFEST"
}

NEW_CODEX_SETTINGS=$(_build_codex "$SETTINGS_PREFIX")

# For plugin, rebuild with matching-quote prefix:
NEW_PLUGIN=$(jq --arg prefix '"${CLAUDE_PLUGIN_ROOT}/.claude/hooks' '
  {
    hooks: (
      .hooks | to_entries | map(
        .key as $event
        | {
            key: $event,
            value: (
              .value | to_entries | map(
                (if .key == "" then {} else {matcher: .key} end) + {
                  hooks: (.value | map({
                    type: "command",
                    command: ("f=" + $prefix + "/" + . + "\"; [ -x \"$f\" ] && exec \"$f\"; exit 0")
                  }))
                }
              )
            )
          }
      ) | from_entries
    )
  }
' "$MANIFEST")

NEW_CODEX_PLUGIN=$(_build_codex '"${CLAUDE_PLUGIN_ROOT}/.claude/hooks' '"')

_validate_hook_script_inventory() {
  # Every executable-ish file in .claude/hooks should be either a lifecycle hook
  # in the manifest, a Codex-only adapter, a support library, or a manual utility.
  # This catches silent gaps where a real hook script exists but never runs.
  local _manifest_scripts _exempt_scripts _unaccounted
  _manifest_scripts=$(jq -r '.hooks | .. | .[]? | select(type=="string")' "$MANIFEST" | grep -E '\.sh$' | sort -u)
  _exempt_scripts=$(jq -r '((.supportScripts // []) + (.manualScripts // []) + (.codexOnlyHooks // []))[]?' "$MANIFEST" | sort -u)
  _unaccounted=$(comm -23 \
    <(find .claude/hooks -maxdepth 1 -type f -name '*.sh' -exec basename {} \; | sort -u) \
    <(printf '%s\n%s\n' "$_manifest_scripts" "$_exempt_scripts" | awk 'NF' | sort -u) \
  )
  if [ -n "$_unaccounted" ]; then
    echo "ERROR: hook scripts exist but are neither configured nor exempted:" >&2
    echo "$_unaccounted" >&2
    echo "Add them under .hooks or document them in supportScripts/manualScripts/codexOnlyHooks in $MANIFEST." >&2
    return 1
  fi
}

# Merge permissions from existing settings.json (hand-edited, not generated)
if [ -f ".claude/settings.json" ]; then
  _perms=$(jq '.permissions // empty' .claude/settings.json)
  if [ -n "$_perms" ] && [ "$_perms" != "null" ]; then
    NEW_SETTINGS=$(echo "$NEW_SETTINGS" | jq --argjson p "$_perms" '{permissions: $p, hooks}')
  fi
fi

case "$MODE" in
  check)
    _drift=0
    _cur_settings=$(jq -S . .claude/settings.json 2>/dev/null || echo "{}")
    _new_settings_sorted=$(echo "$NEW_SETTINGS" | jq -S .)
    if ! diff <(echo "$_cur_settings") <(echo "$_new_settings_sorted") >/dev/null 2>&1; then
      echo "DRIFT: .claude/settings.json ≠ manifest" >&2
      _drift=1
    fi
    _cur_plugin=$(jq -S . hooks/hooks.json 2>/dev/null || echo "{}")
    _new_plugin_sorted=$(echo "$NEW_PLUGIN" | jq -S .)
    if ! diff <(echo "$_cur_plugin") <(echo "$_new_plugin_sorted") >/dev/null 2>&1; then
      echo "DRIFT: hooks/hooks.json ≠ manifest" >&2
      _drift=1
    fi
    _cur_codex_settings=$(jq -S . .codex/hooks.json 2>/dev/null || echo "{}")
    _new_codex_settings_sorted=$(echo "$NEW_CODEX_SETTINGS" | jq -S .)
    if ! diff <(echo "$_cur_codex_settings") <(echo "$_new_codex_settings_sorted") >/dev/null 2>&1; then
      echo "DRIFT: .codex/hooks.json ≠ manifest Codex subset" >&2
      _drift=1
    fi
    _cur_codex_plugin=$(jq -S . hooks/codex-hooks.json 2>/dev/null || echo "{}")
    _new_codex_plugin_sorted=$(echo "$NEW_CODEX_PLUGIN" | jq -S .)
    if ! diff <(echo "$_cur_codex_plugin") <(echo "$_new_codex_plugin_sorted") >/dev/null 2>&1; then
      echo "DRIFT: hooks/codex-hooks.json ≠ manifest Codex subset" >&2
      _drift=1
    fi
    if ! _validate_hook_script_inventory; then
      _drift=1
    fi
    [ "$_drift" = "0" ] && echo "OK: hook configs match manifest and hook script inventory is accounted for"
    exit $_drift
    ;;
  apply)
    mkdir -p .codex hooks
    echo "$NEW_SETTINGS" > .claude/settings.json
    echo "$NEW_PLUGIN" > hooks/hooks.json
    echo "$NEW_CODEX_SETTINGS" > .codex/hooks.json
    echo "$NEW_CODEX_PLUGIN" > hooks/codex-hooks.json
    if ! jq empty .claude/settings.json 2>&1; then
      echo "ERROR: generated settings.json invalid" >&2
      exit 1
    fi
    if ! jq empty hooks/hooks.json 2>&1; then
      echo "ERROR: generated hooks/hooks.json invalid" >&2
      exit 1
    fi
    if ! jq empty .codex/hooks.json 2>&1; then
      echo "ERROR: generated .codex/hooks.json invalid" >&2
      exit 1
    fi
    if ! jq empty hooks/codex-hooks.json 2>&1; then
      echo "ERROR: generated hooks/codex-hooks.json invalid" >&2
      exit 1
    fi
    echo "Generated .claude/settings.json, hooks/hooks.json, .codex/hooks.json, and hooks/codex-hooks.json from $MANIFEST"
    # Verify scripts exist
    _missing=0
    while IFS= read -r script; do
      [ -z "$script" ] && continue
      if [ ! -f ".claude/hooks/$script" ]; then
        echo "WARN: .claude/hooks/$script not found on disk" >&2
        _missing=$((_missing + 1))
      fi
    done < <(jq -r '.hooks | .. | .[]? | select(type=="string")' "$MANIFEST" | grep -E '\.sh$' | sort -u)
    if [ "$_missing" -gt 0 ]; then
      echo "WARN: $_missing scripts missing" >&2
      exit 1
    fi
    _validate_hook_script_inventory
    ;;
  *)
    echo "Usage: $0 [--apply|--check]" >&2
    exit 1
    ;;
esac
