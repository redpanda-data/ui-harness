# Evals for mcp-ban.sh — PreToolUse hook that denies verbose MCP tool
# calls and redirects to CLI equivalents (acli, gws, agent-browser, gh, etc.)

HOOK="$REPO_ROOT/.claude/hooks/mcp-ban.sh"
CLAUDE_SETTINGS="$REPO_ROOT/.claude/settings.json"
CODEX_HOOKS="$REPO_ROOT/.codex/hooks.json"

run_file_eval "$HOOK" "mcp-ban.sh exists"
run_executable_eval "$HOOK" "mcp-ban.sh executable"

# Registration: must appear in both Claude Code + Codex PreToolUse matchers
for cfg in "$CLAUDE_SETTINGS" "$CODEX_HOOKS"; do
  label=$(basename "$(dirname "$cfg")")/$(basename "$cfg")
  if grep -q '"matcher": "mcp__' "$cfg" 2>/dev/null && grep -q 'mcp-ban.sh' "$cfg" 2>/dev/null; then
    echo "  PASS  $label registers mcp-ban with mcp__ matcher"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label missing mcp-ban registration"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: mcp-ban not registered in $label"
  fi
done

# Helper: run hook and capture stderr/exit
_run_mcp() {
  local tool="$1"
  local err; err=$(mktemp); local ec=0
  echo "{\"tool_name\":\"$tool\",\"tool_input\":{}}" | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"
}

# Helper: assert denies with CLI hint
_assert_denied() {
  local tool="$1" expect_cli="$2" label="$3"
  _run_mcp "$tool"
  if [ "$_last_exit" = "2" ] && echo "$_last_stderr" | grep -q '"permissionDecision": "deny"' \
     && echo "$_last_stderr" | grep -q "$expect_cli"; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label (exit=$_last_exit, stderr missing deny or $expect_cli)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $label"
  fi
}

# Each MCP family: one smoke test per CLI redirect
_assert_denied "mcp__claude_ai_Atlassian__editJiraIssue" "acli" "Jira -> acli"
_assert_denied "mcp__claude_ai_Gmail__gmail_search_messages" "gws" "Gmail -> gws"
_assert_denied "mcp__claude-in-chrome__read_page" "agent-browser" "claude-in-chrome -> agent-browser"
_assert_denied "mcp__chrome-devtools__evaluate_script" "agent-browser" "chrome-devtools -> agent-browser"
_assert_denied "mcp__playwright__browser_navigate" "agent-browser" "playwright -> agent-browser"
_assert_denied "mcp__blacksmith__list_runs" "gh run" "blacksmith -> gh"
_assert_denied "mcp__claude_ai_Google_Calendar__list_events" "gws calendar" "Calendar -> gws"
_assert_denied "mcp__claude_ai_Google_Drive__files_list" "gws drive" "Drive -> gws"
_assert_denied "mcp__claude_ai_Buildkite_read-only__list" "bk" "Buildkite -> bk"
_assert_denied "mcp__claude_ai_Box__files_list" "box" "Box -> box"
_assert_denied "mcp__claude_ai_Microsoft_365__teams" "m365" "M365 -> m365"

# JSON validity on every deny — prevent regressions from unescaped quotes
_run_mcp "mcp__claude_ai_Gmail__gmail_search_messages"
if echo "$_last_stderr" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
  echo "  PASS  gmail deny produces valid JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL  gmail deny emits malformed JSON"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: mcp-ban JSON malformed"
fi

# Passthrough for unrelated tools
_run_mcp "Bash"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  silent passthrough on non-MCP tool"
  PASS=$((PASS + 1))
else
  echo "  FAIL  non-MCP tool should silent-pass (exit=$_last_exit)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: mcp-ban non-MCP passthrough"
fi
