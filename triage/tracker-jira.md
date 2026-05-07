# Issue tracker: Jira

For Jira-tracked work, use the [`acli`](https://developer.atlassian.com/cloud/acli/) CLI. Detect availability with `command -v acli` and a configured `JIRA_PROJECT`.

See `setup-atlassian-workflow/REFERENCE.md` for the canonical command patterns -- this file maps the triage flow onto them.

## Conventions

- **Create**: `acli jira workitem create --project "$JIRA_PROJECT" --type <Bug|Story|Epic> --summary "..." [--description "..."] [--priority High] [--label ...]`
- **Read**: `acli jira workitem view <KEY>` (or web URL via `acli jira workitem url <KEY>`)
- **List**:
  ```sh
  acli jira workitem list --project "$JIRA_PROJECT" --jql 'status = "To Do" AND labels = "needs-triage"'
  ```
- **Comment**: `acli jira workitem comment <KEY> --body "..."`
- **Transition status**: `acli jira workitem transition <KEY> --to "In Progress"`
- **Apply / remove labels**: `acli jira workitem update <KEY> --add-label "..." --remove-label "..."`
- **Link to PR / parent**:
  - `acli jira workitem link <KEY> --url "https://github.com/org/repo/pull/123"`
  - `acli jira workitem link <CHILD> <PARENT> "is caused by"` (or other Jira link types)

Use a heredoc for multi-line descriptions just like with `gh`.

## Mapping triage roles to Jira

The five triage state roles map to Jira **status** transitions or **labels**, depending on how the project is configured. Inspect the project's existing workflow once and pick whichever vocabulary the project already uses; don't invent new statuses.

Typical mappings:

| Triage role | Jira status (common) | Jira label fallback |
|---|---|---|
| `needs-triage` | `To Do` (with no triage label) | `needs-triage` |
| `needs-info` | `Open` / `Waiting for Customer` | `needs-info` |
| `ready-for-agent` | `Ready` / `Selected for Development` | `ready-for-agent` |
| `ready-for-human` | `Ready` (assigned to human) | `ready-for-human` |
| `wontfix` | `Closed` (resolution `Won't Do`) | `wontfix` |

Categories (`bug` / `enhancement`) map to issue **type** (`Bug` / `Story`).

## When the skill says "publish to the issue tracker"

Create a Jira work item under `JIRA_PROJECT`. If `ISSUE_TRACKER=both` is set, also create a GitHub issue and link the Jira item to it via `acli jira workitem link <KEY> --url <GH_URL>`.

## When the skill says "fetch the relevant ticket"

`acli jira workitem view <KEY>`.

## Out-of-scope rejections (Jira)

`.out-of-scope/<concept>.md` lives in the repo regardless of tracker. When closing a Jira enhancement as `wontfix`, write/append to `.out-of-scope/` and link to the file from a Jira comment, exactly as for GitHub.
