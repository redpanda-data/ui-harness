#!/bin/bash
set -euo pipefail
trap 'exit 0' ERR

# UserPromptSubmit hook: detect intent from prompt keywords and inject
# workflow directives as additionalContext. Runs alongside user-prompt-context.sh.
# Target: <30ms (keyword grep cascade).

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')

if [ "$hook_event" != "UserPromptSubmit" ]; then
  exit 0
fi

prompt=$(echo "$input" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')

if [ -z "$prompt" ]; then
  exit 0
fi

directives=""

# ── Test writing ─────────────────────────────────────────────────

if echo "$prompt" | grep -qiE 'write.*test|add.*test|create.*test|test for|spec for|\btdd\b|red.green'; then
  directives="$directives\n[TDD] RED→GREEN→REFACTOR. No prod w/o failing test. Condition waits, no setTimeout. --detectAsyncLeaks."
fi

# ── Component/UI creation ────────────────────────────────────────

if echo "$prompt" | grep -qiE 'create.*component|new.*component|build.*form|add.*page|add.*dialog|add.*modal|add.*view'; then
  directives="$directives\n[COMPONENT] Prod UI: use @/components/ui/ (tests/stories/docs exempt). kbd-nav, aria-labels, test co-located. DS tokens, no inline."
fi

# ── Bug fix / debugging ─────────────────────────────────────────

if echo "$prompt" | grep -qiE 'fix.*bug|debug|broken|not working|error.*in|crash|triage|investigate|regression'; then
  directives="$directives\n[TRIAGE] reproduce(test)->analyze->hypothesize(1 at a time)->fix ROOT CAUSE. /codex:rescue if avail. Max 2 attempts, else stop + present both. Terminal verify (vitest/biome/tsgo) > browser."
fi

# ── PR/review ────────────────────────────────────────────────────

if echo "$prompt" | grep -qiE 'create.*pr|open.*pr|pull request|push.*branch|submit.*review'; then
  # Only suggest @claude review if we haven't already this session
  review_marker="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}/review-requested"
  if [ -f "$review_marker" ]; then
    directives="$directives\n[PR] quality:gate + type:check first. Conventional commits. (Review already requested.)"
  else
    directives="$directives\n[PR] quality:gate + type:check first. After: @claude review. Conventional commits."
    touch "$review_marker" 2>/dev/null || true
  fi
fi

# ── Refactoring ──────────────────────────────────────────────────

if echo "$prompt" | grep -qiE '\brefactor\b|extract.*into|move.*to|split.*into|consolidate|clean.?up'; then
  directives="$directives\n[REFACTOR] Tests BEFORE (baseline). Small steps, test each. No barrel imports. type:check+tests after."
fi

# ── E2E testing ──────────────────────────────────────────────────

if echo "$prompt" | grep -qiE '\be2e\b|playwright|end.to.end|browser test|user workflow|acceptance test'; then
  directives="$directives\n[E2E] Base fixture (axe-core). makeAxeBuilder(). data-testid. Explicit waits, no hard delays."
fi

# ── Verification / testing in browser ────────────────────────────

if echo "$prompt" | grep -qiE 'test.*browser|check.*browser|verify.*works|test the flow|test.*ui|check.*page|verify.*page|does it work|try it|smoke test'; then
  directives="$directives\n[VERIFY] Self-verify when automatable. No delegate CI/browser/test to user. Escalate only if sandbox lacks creds. Confirm pre-report. Order: Playwright CLI > terminal > agent-browser > MCP (last)."
fi

# ── Browser task detected (URL / navigate / click / visual bug) ──
# Fires when prompt implies live-browser interaction. Reminds that
# CLI browser tools exist (agent-browser, bunx playwright) so Claude
# never replies "no browser tools available".

if echo "$prompt" | grep -qiE 'https?://|localhost:|click on|click the|navigate to|go to.*http|open.*http|screenshot|white flash|flash.*appears|hover over|fill.*form|visual.*bug|rendering issue|ui bug|page load|reload.*page'; then
  directives="$directives\n[BROWSER] Browser tools available via CLI: \`agent-browser\` (installed at ~/.local/state/fnm.../bin/agent-browser, run \`agent-browser --help\`) and \`bunx playwright\` (codegen/test/screenshot). Also mcp__claude-in-chrome__* as fallback. Never say \"no browser tools\" — use the CLI. Order: bunx playwright > agent-browser > claude-in-chrome MCP (last)."
fi

# ── CI fix workflow ──────────────────────────────────────────────

if echo "$prompt" | grep -qiE 'fix ci|green ci|ci failing|ci broken|check failures|fix pipeline|fix checks|fix pr checks|ci red|checks? fail'; then
  directives="$directives\n[CI-FIX] Front-load ALL failures. Run quality:gate (or gh pr checks + lint + type:check + test). List EVERY failure by category BEFORE fixing. Order: proto->types->lint->unit->e2e. Push ONCE after all local pass. Parallel agents for independent categories. Terminal only, no browser."
fi

# ── General: never delegate verification to user ─────────────────
# Only fire on substantive bug fixes, not trivial ("fix indentation", "fix typo")

if echo "$prompt" | grep -qiE 'fix.*bug|broken|not working|blank.*screen|error.*page|crash|regression'; then
  directives="$directives\n[SELF-VERIFY] Verify fix yourself when automatable. Escalate to user only if sandbox lacks access (prod creds, external service)."
fi

# ── Implementation work → full lifecycle mandate ─────────────────
# Detect: build/implement/add/create feature work (not just tests/reviews)
# Inject the full lifecycle sequence so Claude auto-follows every step.

if echo "$prompt" | grep -qiE 'build.*feature|implement|add.*support|create.*endpoint|add.*page|add.*route|add.*hook|add.*component|new.*feature|wire.*up|integrate|set.*up'; then
  directives="$directives\n[LIFECYCLE] MANDATORY sequence: (1) Plan approach (2) /tdd for every new file — failing test first (3) Implement minimal code to pass (4) /simplify changed code (5) Self-verify with browser/tests (6) /commit-push → PR → Monitor CI → fix failures → request review. Hooks enforce this — do NOT skip steps.\n[MINIMAL] Simplest solution first. No new abstractions, utils, helpers, or wrapper components without explicit user request. Inline > extract. If tempted to create utility, use inline approach instead."
fi

# ── PR-number auto-context ───────────────────────────────────────
# When prompt references a PR number near action keywords, inject branch context.

_pr_number=$(echo "$prompt" | grep -oE '(pr|pull request|fix|ci|check|review).*#([0-9]+)' | grep -oE '#[0-9]+' | head -1 | tr -d '#' || true)
if [ -z "$_pr_number" ]; then
  _pr_number=$(echo "$prompt" | grep -oE '#([0-9]{4,})' | head -1 | tr -d '#' || true)
fi

if [ -n "$_pr_number" ]; then
  directives="$directives\n[PR-CONTEXT] Detected PR #$_pr_number. Before changes: gh pr checkout $_pr_number to get on correct branch. All changes on that branch. Do not create new branches."
fi

# ── Scope-lock: prefer committing to current feature branch ─────
# Auto-detected from branch state, not prompt keywords.

_current_branch=$(git branch --show-current 2>/dev/null || true)
case "$_current_branch" in
  main|master|develop|"") ;;
  *)
    directives="$directives\n[SCOPE-LOCK] On feature branch '$_current_branch'. Prefer committing here. Ask before creating new branches or PRs unless explicitly instructed."
    ;;
esac

# ── Risk tier (informs auto mode confidence) ────────────────────
# low: tests, components, refactoring — fully guarded by hooks
# medium: bug fixes, debugging — may need exploratory actions
# high: PRs, deploys, infra — touches shared/external systems

risk=""

if echo "$prompt" | grep -qiE 'fix.*bug|debug|broken|not working|crash|triage|investigate|regression'; then
  risk="medium"
fi

if echo "$prompt" | grep -qiE 'create.*pr|open.*pr|pull request|push|deploy|migration|drop|delete.*branch|force'; then
  risk="high"
fi

# Only emit risk tier for medium/high — low is default, no need to announce
if [ -n "$risk" ]; then
  directives="$directives\n[RISK:$risk]"
fi

# ── CLI-first principle ──────────────────────────────────────────
# Always prefer token-efficient CLI tools over MCP/browser tools.
# Appended to every non-empty directive set.

if [ -n "$directives" ]; then
  directives="$directives\n[CLI-FIRST] Prefer CLI over MCP/browser: gh CLI over GitHub MCP, bunx playwright test over MCP browser, jira/acli over Jira MCP, curl/httpie over fetch-in-browser. CLIs: structured text output, low tokens, deterministic. Browser tools: screenshots, DOM dumps, navigation loops, massive token burn. Use browser ONLY for visual UI verification that no CLI can cover."
fi

# ── Output ───────────────────────────────────────────────────────

if [ -n "$directives" ]; then
  escaped=$(printf '%s' "$directives" | jq -Rs . 2>/dev/null) || exit 0
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":$escaped}}" >&2
fi

exit 0
