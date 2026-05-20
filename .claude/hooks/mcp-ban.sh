#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else exit 0; fi

# PreToolUse: ban verbose MCP servers with CLI alternatives.
# Jira/Confluence MCP -> acli (https://developer.atlassian.com/cloud/acli)
# Gmail MCP           -> gws  (https://github.com/googleworkspace/cli)
#
# Data: mcp__claude_ai_Atlassian__editJiraIssue averaged 23k chars/call,
# mcp__claude_ai_Gmail__gmail_search_messages 15k chars/call. CLI output
# is terse + pipeable + jq-composable. Same pattern as Playwright ban.

_hook_input=$(cat)
tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

case "$tool_name" in
  # ── Atlassian / Jira ───────────────────────────────────────────
  mcp__claude_ai_Atlassian__editJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem edit --key KEY-123 --summary ... --description .... 23x smaller output. Install: brew install atlassian/cli/acli. Auth: acli jira auth login.'
    ;;
  mcp__claude_ai_Atlassian__getJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem view KEY-123 --fields summary,status,assignee. Key is positional (no --key). Default fields include description; narrow with --fields for less output.'
    ;;
  mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql)
    msg='Jira MCP banned. Use: acli jira workitem search --jql "project = ABC" --fields key,summary,status --json --limit 25. Add --csv for terser output.'
    ;;
  mcp__claude_ai_Atlassian__addCommentToJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem comment create --key KEY-123 --body "text". Subcommand is "comment create" (space).'
    ;;
  mcp__claude_ai_Atlassian__transitionJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem transition --key KEY-123 --status "Done" --yes.'
    ;;
  mcp__claude_ai_Atlassian__getTransitionsForJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem view KEY-123 --fields status --json to see current status; transitions list via acli jira workitem transition --help.'
    ;;
  mcp__claude_ai_Atlassian__createJiraIssue)
    msg='Jira MCP banned. Use: acli jira workitem create --project ABC --type Task --summary "..." --description "...".'
    ;;
  mcp__claude_ai_Atlassian__getJiraProjectIssueTypesMetadata|mcp__claude_ai_Atlassian__getJiraIssueTypeMetaWithFields)
    msg='Jira MCP banned. Use: acli jira project view KEY or acli jira field list for metadata.'
    ;;
  mcp__claude_ai_Atlassian__lookupJiraAccountId|mcp__claude_ai_Atlassian__getAccessibleAtlassianResources)
    msg='Jira MCP banned. Use: acli jira auth status or acli jira organization list.'
    ;;
  mcp__claude_ai_Atlassian__*)
    msg='Atlassian MCP banned. Use acli (brew install atlassian/cli/acli). Docs: https://developer.atlassian.com/cloud/acli/reference/commands/'
    ;;

  # ── Gmail / Google Workspace ──────────────────────────────────
  mcp__claude_ai_Gmail__gmail_search_messages)
    msg='Gmail MCP banned. Use: gws gmail users threads list --params (userId:me, q:<query>, maxResults:5) --format json | jq ".threads[] | {id,snippet}". Threads give snippets; messages list returns bare IDs.'
    ;;
  mcp__claude_ai_Gmail__gmail_read_message)
    msg='Gmail MCP banned. Use: gws gmail users messages get --params (userId:me, id:<id>, format:metadata, metadataHeaders:[From,Subject,Date]). WARN: format:full returns 80k+ chars (base64 MIME). For body text use format:full then jq .payload.parts[].body.data | base64 -d.'
    ;;
  mcp__claude_ai_Gmail__gmail_list_labels|mcp__claude_ai_Gmail__list_labels)
    msg='Gmail MCP banned. Use: gws gmail users labels list --params (userId:me).'
    ;;
  mcp__claude_ai_Gmail__gmail_get_profile)
    msg='Gmail MCP banned. Use: gws gmail users getProfile --params (userId:me).'
    ;;
  mcp__claude_ai_Gmail__create_draft|mcp__claude_ai_Gmail__create_label|mcp__claude_ai_Gmail__list_drafts|mcp__claude_ai_Gmail__get_thread|mcp__claude_ai_Gmail__search_threads|mcp__claude_ai_Gmail__label_message|mcp__claude_ai_Gmail__label_thread|mcp__claude_ai_Gmail__unlabel_message|mcp__claude_ai_Gmail__unlabel_thread)
    msg='Gmail MCP banned. Use gws (https://github.com/googleworkspace/cli). Schema: gws schema gmail.users.<resource>.<method>.'
    ;;
  mcp__claude_ai_Gmail__*)
    msg='Gmail MCP banned. Use gws (https://github.com/googleworkspace/cli). Install: brew install googleworkspace/tap/gws.'
    ;;

  # ── Browser automation (Playwright / Chrome DevTools / claude-in-chrome) ──
  mcp__claude-in-chrome__navigate|mcp__chrome-devtools__navigate_page|mcp__playwright__browser_navigate)
    msg='Browser MCP banned. Use: agent-browser open <url>. A11y-tree refs (@e1, @e2), not DOM dumps. ~17x smaller than read_page MCP. Alt: npx playwright open <url>.'
    ;;
  mcp__claude-in-chrome__computer|mcp__claude-in-chrome__find)
    msg='Browser MCP banned. Use: agent-browser click/type/hover <sel-or-@ref>. Get refs via: agent-browser snapshot.'
    ;;
  mcp__claude-in-chrome__read_page|mcp__claude-in-chrome__get_page_text)
    msg='Browser MCP banned. Use: agent-browser snapshot (a11y tree with @e refs). Text only: agent-browser eval "document.body.innerText".'
    ;;
  mcp__claude-in-chrome__javascript_tool|mcp__chrome-devtools__evaluate_script)
    msg='Browser MCP banned. Use: agent-browser eval "<js>". Returns value directly.'
    ;;
  mcp__claude-in-chrome__screenshot)
    msg='Browser MCP banned. Use: agent-browser screenshot [path].'
    ;;
  mcp__claude-in-chrome__read_console_messages)
    msg='Browser MCP banned. Use: agent-browser eval "JSON.stringify(window.__consoleBuf||[])" after wiring console.log proxy, or upgrade agent-browser for console API.'
    ;;
  mcp__claude-in-chrome__read_network_requests)
    msg='Browser MCP banned. Use: agent-browser eval with PerformanceObserver, or curl/httpie for specific endpoints.'
    ;;
  mcp__claude-in-chrome__tabs_context_mcp|mcp__claude-in-chrome__tabs_create_mcp|mcp__claude-in-chrome__switch_browser|mcp__claude-in-chrome__resize_window)
    msg='Browser MCP banned. Use agent-browser directly: agent-browser open <url>. Persistent daemon keeps cookies across calls.'
    ;;
  mcp__claude-in-chrome__*|mcp__chrome-devtools__*|mcp__playwright__*)
    msg='Browser MCP banned. Use: agent-browser (brew install vercel/tap/agent-browser). Alt: npx playwright codegen/open for interactive flows.'
    ;;

  # ── Blacksmith (CI) = GitHub Actions replacement → use gh CLI ──
  mcp__blacksmith__list_runs)
    msg='Blacksmith MCP banned. Blacksmith runs ARE GitHub Actions. Use: gh run list --limit 20 --json databaseId,status,conclusion,workflowName,displayTitle. Avg MCP 16k chars vs gh ~1k chars.'
    ;;
  mcp__blacksmith__list_jobs)
    msg='Blacksmith MCP banned. Use: gh run view <run-id> --json jobs or gh api /repos/{owner}/{repo}/actions/runs/<id>/jobs.'
    ;;
  mcp__blacksmith__get_cache_entries)
    msg='Blacksmith MCP banned. Use: gh cache list --limit 20 --json id,key,sizeInBytes,createdAt.'
    ;;
  mcp__blacksmith__get_job_logs)
    msg='Blacksmith MCP banned. Use: gh run view <run-id> --log --job <job-id> | tail -c 4000. Strip ANSI with sed "s/\\x1b\\[[0-9;]*m//g".'
    ;;
  mcp__blacksmith__*)
    msg='Blacksmith MCP banned. Use gh CLI (GitHub Actions API covers it). gh run/cache/api.'
    ;;

  # ── Google Calendar (via gws) ──
  mcp__claude_ai_Google_Calendar__list_events)
    msg='Calendar MCP banned. Use: gws calendar events list --params (calendarId:primary, timeMin:<ISO>, maxResults:10) --format json | jq ".items[]|{id,summary,start}".'
    ;;
  mcp__claude_ai_Google_Calendar__create_event)
    msg='Calendar MCP banned. Use: gws calendar events insert --params (calendarId:primary) --json <event-body-json>.'
    ;;
  mcp__claude_ai_Google_Calendar__get_event|mcp__claude_ai_Google_Calendar__update_event|mcp__claude_ai_Google_Calendar__delete_event|mcp__claude_ai_Google_Calendar__respond_to_event)
    msg='Calendar MCP banned. Use: gws calendar events (get|patch|delete) --params (calendarId:primary, eventId:<id>).'
    ;;
  mcp__claude_ai_Google_Calendar__list_calendars|mcp__claude_ai_Google_Calendar__suggest_time)
    msg='Calendar MCP banned. Use: gws calendar calendarList list or gws calendar freeBusy query.'
    ;;
  mcp__claude_ai_Google_Calendar__*)
    msg='Calendar MCP banned. Use gws calendar. Schema: gws schema calendar.events.<method>.'
    ;;

  # ── Google Drive (via gws) ──
  mcp__claude_ai_Google_Drive__*)
    msg='Drive MCP banned. Use: gws drive files list --params (q:<query>, pageSize:10, fields:files(id,name,mimeType)) --format json. Get content: gws drive files get --params (fileId:<id>, alt:media).'
    ;;

  # ── Buildkite → bk CLI ──
  mcp__claude_ai_Buildkite_read-only__*|mcp__buildkite__*)
    msg='Buildkite MCP banned. Use: bk build list --pipeline <name> --limit 10 --json. Install: brew install buildkite/buildkite/cli. Auth: bk configure.'
    ;;

  # ── Box → box CLI ──
  mcp__claude_ai_Box__*|mcp__box__*)
    msg='Box MCP banned. Use: box files:get <FILE_ID> --json / box folders:items 0 --json. Install: brew install boxcli.'
    ;;

  # ── GitHub PR thread replies ─────────────────────────────────
  # Keep top-level PR behavior, but don't let agents continue existing PR
  # review discussions/threads as the authenticated human.
  mcp__*github*__*thread*reply*|mcp__*GitHub*__*thread*reply*|mcp__*github*__*reply*thread*|mcp__*GitHub*__*reply*thread*)
    msg='GitHub PR thread reply MCP banned. Ask the user first; for an explicitly approved reply use Bash with CLAUDE_ALLOW_PR_THREAD_REPLY=1 and the gh api replies endpoint.'
    ;;

  # ── Microsoft 365 → m365 CLI ──
  mcp__claude_ai_Microsoft_365__*|mcp__microsoft365__*|mcp__m365__*)
    msg='M365 MCP banned. Use: m365 teams/outlook/sharepoint with -o json. Install: npm i -g @pnp/cli-microsoft365. Auth: m365 login.'
    ;;

  *)
    exit 0
    ;;
esac

_hook_track_violation "mcp-ban" 2>/dev/null || true
_hook_log_entry "deny" "mcp-ban" 2>/dev/null || true

# Build JSON safely via jq so embedded quotes/specials are escaped correctly.
printf '%s' "$msg" | jq -Rs '{hookSpecificOutput:{permissionDecision:"deny"},systemMessage:.}' >&2
exit 2
