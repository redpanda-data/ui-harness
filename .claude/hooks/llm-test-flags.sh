#!/bin/bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [ -z "$command" ]; then
  exit 0
fi

suggestions=""
rewritten="$command"
must_rewrite=false

# ── Vitest / bun test optimization ──────────────────────────────

if echo "$rewritten" | grep -qE '(vitest|bun (test|run test\S*))'; then

  # Strip --verbose (hard enforcement — wastes tokens)
  if echo "$rewritten" | grep -qE '\-\-verbose'; then
    rewritten=$(echo "$rewritten" | sed -E 's/[[:space:]]+--verbose//g; s/--verbose[[:space:]]+//g; s/--verbose$//g')
    must_rewrite=true
  fi

  if ! echo "$rewritten" | grep -qE '\-\-pool[= ]'; then
    suggestions="$suggestions\n- --pool=forks prevents zombie processes"
  fi

  if ! echo "$rewritten" | grep -qE '\-\-bail[= ]'; then
    suggestions="$suggestions\n- --bail=1 fails fast, saves tokens"
  fi

  if ! echo "$rewritten" | grep -qE '\-\-teardownTimeout[= ]'; then
    suggestions="$suggestions\n- --teardownTimeout=5000 prevents hanging teardown"
  fi

  if ! echo "$rewritten" | grep -qE '\-\-reporter[= ]'; then
    if [ "${CI:-}" = "true" ]; then
      suggestions="$suggestions\n- --reporter=github for inline PR annotations"
    else
      # Prefer in-house LLM reporter if wired in consumer's vitest.config.
      # We do not rewrite the command because we cannot be certain the reporter
      # is registered; we only nudge. Consumer wires it in config.
      suggestions="$suggestions\n- Wire shared/reporters/vitest-llm-reporter.ts as default reporter to cut stdout 10-100x"
    fi
  fi
fi

# -- Playwright optimization --------------------------------------

if echo "$rewritten" | grep -qE '\bplaywright (test|show-report)\b'; then

  # Strip --reporter=html or --reporter=list during iteration (too noisy)
  if echo "$rewritten" | grep -qE '\-\-reporter=(html|list)'; then
    rewritten=$(echo "$rewritten" | sed -E 's/--reporter=(html|list)/--reporter=dot/g')
    must_rewrite=true
    suggestions="$suggestions\n- Swapped --reporter=html/list -> --reporter=dot for token efficiency"
  fi

  if ! echo "$rewritten" | grep -qE '\-\-reporter[= ]'; then
    if [ "${CI:-}" = "true" ]; then
      suggestions="$suggestions\n- CI: prefer --reporter=github or --reporter=junit"
    else
      suggestions="$suggestions\n- Wire shared/reporters/playwright-llm-reporter.ts in playwright.config.ts"
    fi
  fi

  # Iteration speed helpers
  if ! echo "$rewritten" | grep -qE '\-\-max-failures'; then
    suggestions="$suggestions\n- --max-failures=3 fails fast on broken iteration"
  fi
fi

# ── Jest optimization ───────────────────────────────────────────

if echo "$rewritten" | grep -qE '\bjest\b'; then

  if echo "$rewritten" | grep -qE '\-\-verbose'; then
    rewritten=$(echo "$rewritten" | sed -E 's/[[:space:]]+--verbose//g; s/--verbose[[:space:]]+//g; s/--verbose$//g')
    must_rewrite=true
  fi

  if ! echo "$rewritten" | grep -qE '\-\-bail'; then
    suggestions="$suggestions\n- --bail fails fast"
  fi

  if ! echo "$rewritten" | grep -qE '\-\-forceExit'; then
    suggestions="$suggestions\n- --forceExit prevents zombie processes"
  fi
fi

# ── Apply ────────────────────────────────────────────────────────

if [ "$must_rewrite" = true ]; then
  updated_input=$(echo "$input" | jq --arg cmd "$rewritten" '.tool_input | .command = $cmd')
  if [ -n "$suggestions" ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":$updated_input,\"additionalContext\":\"Test suggestions:$suggestions\"}}" >&2
  else
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":$updated_input}}" >&2
  fi
  exit 0
fi

if [ -n "$suggestions" ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"Test suggestions:$suggestions\"}}" >&2
  exit 0
fi

exit 0
