# Evals for github-write-guard.sh — PreToolUse Bash deny on GitHub PR thread replies.

HOOK="$REPO_ROOT/.claude/hooks/github-write-guard.sh"

run_file_eval "$HOOK" "github-write-guard.sh exists"
run_executable_eval "$HOOK" "github-write-guard.sh executable"
run_content_eval "$REPO_ROOT/skill-manifest.json" "github-write-guard.sh" \
  "manifest registers github-write-guard"
run_content_eval "$REPO_ROOT/.claude/settings.json" "github-write-guard.sh" \
  "settings registers github-write-guard"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "github-write-guard.sh" \
  "plugin hooks register github-write-guard"
run_content_eval "$REPO_ROOT/.codex/hooks.json" "github-write-guard.sh" \
  "codex hooks register github-write-guard"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 123 --body \"@claude review\""}}' \
  0 "allow: top-level gh pr comment"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 42 --body \"triage\""}}' \
  0 "allow: top-level gh issue comment"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"gh api repos/o/r/pulls/1/comments/99/replies -f body=reply"}}' \
  2 "deny: gh api PR review comment reply" "Refusing PR thread reply"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"gh pr view 123 --json url"}}' \
  0 "allow: read-only gh pr view"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"gh api graphql -f query=\"mutation { addPullRequestReviewThreadReply(input:{}) { clientMutationId } }\""}}' \
  2 "deny: GraphQL PR review thread reply" "Refusing PR thread reply"

run_hook_eval "$HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"CLAUDE_ALLOW_PR_THREAD_REPLY=1 gh api repos/o/r/pulls/1/comments/99/replies -f body=reply"}}' \
  0 "allow: explicit env override"
