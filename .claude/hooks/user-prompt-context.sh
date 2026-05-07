#!/bin/bash
set -euo pipefail
trap 'exit 0' ERR

# UserPromptSubmit hook: inject project state into every prompt.
# Target: <200ms total. Claude starts each response knowing the project state
# without wasting tool calls on git status, file reads, or config checks.
#
# Turn-aware output (Opus 4.7 caching optimization):
#   First turn of session:  full context (rules + config + paths + state)
#   Subsequent turns:       delta only (git state + new violations)
#   Rationale: stable rules/config in CLAUDE.md already; re-injecting per-turn
#   wastes ~150 tok/turn. First-turn injection + CLAUDE.md covers cache-miss path.
#
# Levels (PROMPT_CONTEXT_LEVEL env var):
#   minimal  — git state only (~80ms)
#   standard — git + scripts + violations + config + rules (~120ms, default)
#   full     — standard + paths + UI inventory + route tree + proto version (~170ms)

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')

if [ "$hook_event" != "UserPromptSubmit" ]; then
  exit 0
fi

level="${PROMPT_CONTEXT_LEVEL:-standard}"
context=""

# ── First-turn marker ────────────────────────────────────────────
# On first UserPromptSubmit of session: emit full context (rules+config).
# Subsequent turns: emit only dynamic state (git, violations).
# Saves ~150 tok/turn × N turns. CLAUDE.md + CLAUDE_PLUGIN rules cover steady-state.

_session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
mkdir -p "$_session_dir" 2>/dev/null || true
_first_turn_marker="$_session_dir/first-turn-done"
_is_first_turn=0
if [ ! -f "$_first_turn_marker" ]; then
  _is_first_turn=1
  touch "$_first_turn_marker" 2>/dev/null || true
fi

# ── Git state (~80ms) — every turn ──────────────────────────────

branch=$(git branch --show-current 2>/dev/null || echo "detached")
dirty=$(git diff --stat HEAD 2>/dev/null | tail -1 || echo "clean")
last_commit=$(git log --oneline -1 2>/dev/null || echo "no commits")
ahead_behind=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null | awk '{if(NF>=2) print "ahead:"$1" behind:"$2}' 2>/dev/null || echo "")

context="Branch: $branch"
[ -n "$dirty" ] && context="$context | $dirty"
[ -n "$ahead_behind" ] && context="$context | $ahead_behind"
context="$context\nLast commit: $last_commit"

# ── Session violations (~5ms) — every turn, only if present ──────

vfile="$_session_dir/violations"
if [ -f "$vfile" ] && [ -s "$vfile" ]; then
  total=$(wc -l < "$vfile" | tr -d ' ')
  summary=$(sort "$vfile" | uniq -c | sort -rn | head -5 | awk '{print $1"x "$2}' | paste -sd ", " -)
  context="$context\nViolations ($total): $summary"
fi

# ── Standard+ sections — FIRST TURN ONLY ────────────────────────

if [ "$_is_first_turn" = "1" ] && { [ "$level" = "standard" ] || [ "$level" = "full" ]; }; then

  # ── Package.json scripts (~30ms) ───────────────────────────────

  if [ -f "package.json" ]; then
    scripts=$(jq -r '.scripts // {} | keys[]' package.json 2>/dev/null | paste -sd ", " - || echo "")
    [ -n "$scripts" ] && context="$context\nScripts: $scripts"
  fi

  # ── Condensed rules line (~3ms) ────────────────────────────────
  # Compresses 300+ lines of PostToolUse enforcement into one line.
  # Prevents first-violation costs (estimated 3000-8000 tokens/session saved).

  rules=""
  [ "${PKG_MANAGER:-}" ] && rules="$rules ${PKG_MANAGER}"
  [ "${LINTER:-}" ] && rules="$rules ${LINTER}"
  [ "${TEST_RUNNER:-}" ] && rules="$rules ${TEST_RUNNER}"
  rules="$rules | no-memo(compiler) no-as-any no-ts-ignore no-style={{}}"
  [ "${REACT_RULES_BAN_USEEFFECT:-}" = "1" ] && rules="$rules no-useEffect"
  rules="$rules | UI:@/components/ui/ | no-raw-HTML(<button>→<Button>)"
  rules="$rules | zustand:create<T>()() useShallow | env:@/env(no process.env)"

  # Conditional rules based on installed hooks
  [ -f ".claude/hooks/tanstack-router-check.sh" ] && rules="$rules | TanStack-Router(no react-router-dom)"
  [ -f ".claude/hooks/connect-query-check.sh" ] && rules="$rules | connect-query(no raw useQuery)"

  context="$context\nRules:$rules"

  # ── Active config (~5ms) ───────────────────────────────────────

  config=""
  [ "${REACT_COMPILER_MODE:-}" ] && config="$config compiler=$REACT_COMPILER_MODE"
  [ "${ISSUE_TRACKER:-}" ] && config="$config tracker=$ISSUE_TRACKER"
  [ "${HOOKS_FAIL_CLOSED:-}" = "1" ] && config="$config fail-closed=on"
  [ -n "$config" ] && context="$context\nConfig:$config"
fi

# ── Full level sections — FIRST TURN ONLY ───────────────────────

if [ "$_is_first_turn" = "1" ] && [ "$level" = "full" ]; then

  # ── tsconfig path aliases (~8ms) ───────────────────────────────

  if [ -f "tsconfig.json" ]; then
    paths=$(jq -r '.compilerOptions.paths // {} | to_entries[] | "\(.key)=\(.value[0])"' tsconfig.json 2>/dev/null | paste -sd " " - || echo "")
    [ -n "$paths" ] && context="$context\nPaths: $paths"
  fi

  # ── UI component inventory (~5ms) ──────────────────────────────

  ui_dir=""
  [ -d "src/components/ui" ] && ui_dir="src/components/ui"
  [ -d "components/ui" ] && ui_dir="components/ui"

  if [ -n "$ui_dir" ]; then
    components=$(ls "$ui_dir"/*.tsx 2>/dev/null | xargs -I{} basename {} .tsx | paste -sd "," - || echo "")
    [ -n "$components" ] && context="$context\nUI: $components"
  fi

  # ── Route tree (~10ms) ─────────────────────────────────────────

  routes_dir=""
  [ -d "src/routes" ] && routes_dir="src/routes"
  [ -d "app/routes" ] && routes_dir="app/routes"

  if [ -n "$routes_dir" ]; then
    routes=$(find "$routes_dir" -name '*.tsx' -o -name '*.ts' 2>/dev/null | sed "s|$routes_dir/||" | grep -v '__' | sort | head -15 | paste -sd "," - || echo "")
    [ -n "$routes" ] && context="$context\nRoutes: $routes"
  fi

  # ── Protobuf version (~3ms) ────────────────────────────────────

  if [ -f "package.json" ]; then
    proto_v=$(grep -oE '"@bufbuild/protobuf":\s*"[\^~]?([0-9]+)' package.json 2>/dev/null | grep -oE '[0-9]+$' || echo "")
    [ -n "$proto_v" ] && context="$context\nProto: v$proto_v"
  fi

  # ── Last Stop hook outcome (~2ms) ──────────────────────────────

  stop_file="$_session_dir/last-stop"
  if [ -f "$stop_file" ]; then
    stop_result=$(cat "$stop_file" 2>/dev/null | head -1)
    [ -n "$stop_result" ] && context="$context\nLast stop: $stop_result"
  fi
fi

# ── Output ───────────────────────────────────────────────────────

if [ -n "$context" ]; then
  escaped=$(printf '%s' "$context" | jq -Rs . 2>/dev/null) || exit 0
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":$escaped}}" >&2
fi

exit 0
