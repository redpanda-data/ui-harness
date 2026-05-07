# Issue tracker: GitHub

For GitHub-hosted repos, use the `gh` CLI. Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Conventions

- **Create**: `gh issue create --title "..." --body "..."` (heredoc for multi-line bodies)
- **Read**: `gh issue view <number> --comments`
- **List**:
  ```sh
  gh issue list --state open --json number,title,body,labels,comments \
    --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'
  ```
  Filter with `--label`, `--state`, `--author` as needed.
- **Comment**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..." --remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

## Mapping triage roles to GitHub labels

The five state roles + two category roles map to GitHub labels of the same name by default. If the project already uses different label vocabulary (e.g. `bug:triage`), infer the mapping from existing labels on closed issues, ask the maintainer once, and use the project's strings.

## When the skill says "publish to the issue tracker"

Create a GitHub issue.

## When the skill says "fetch the relevant ticket"

`gh issue view <number> --comments`.
