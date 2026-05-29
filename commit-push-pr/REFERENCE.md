# Commit-push-pr reference

## Review skill list (Phase 0 pre-flight)

Before `/commit-push-pr`, one review skill must run in session:

- `/simplify` -- small fixes/tweaks
- `/improve-codebase-architecture` -- refactors (prefer this; `/request-refactor-plan` is deprecated)
- `/improve-codebase-architecture` -- cleanup (oversized files, shallow modules, tangled deps)
- `/prototype` -- redesign module or layout (prefer this; `/design-an-interface` is deprecated)
- `/visual-review` -- browser-based review for frontend/visual diffs

Frontend diff -> `/visual-review` must run or an explicit skip reason must be recorded, even if another review skill already ran.

None ran -> warn: "Lifecycle requires review skill before shipping. Recommend: `/simplify` for small changes, `/improve-codebase-architecture` for cleanup, `/visual-review` for frontend changes."

## Conventional commit types (Phase 3)

Group changed files by purpose:

| Type | Matches |
|------|---------|
| `docs` | *.md, SKILL.md, REFERENCE.md, comments-only changes |
| `test` | *.test.ts, *.test.tsx, *.spec.ts, EVAL.ts, agent-evals/ |
| `refactor` | restructure, no behavior change |
| `style` | formatting, whitespace, lint-only fixes |
| `fix` | bug fixes, error corrections |
| `feat` | new features, components, endpoints |
| `chore` | config, deps, build scripts, tooling |
| `perf` | perf improvements |
| `ci` | CI/CD pipeline changes |
| `build` | build system changes |

File fit multiple -> pick most specific.

## Auto-label map (Phase 5)

Map commit types to GitHub labels. Verify label exist first: `gh label list --search "<name>" --json name --jq '.[0].name'` -- only add existing labels.

| Commit type | Label |
|-------------|-------|
| `feat` | `enhancement` |
| `fix` | `bug` |
| `docs` | `documentation` |
| `perf` | `performance` |
| `ci` | `ci` |
| `test` | `testing` |

## PR body template (Phase 5)

```
gh pr create --base <base> --assignee @me --fill-verbose --body "$(cat <<'EOF'
## Summary
<bulleted summary synthesized from commits>

## Commits
<list each commit: hash + message>

## Screenshots
<omit entire section if no frontend changes -- see Frontend detection below>

| View | Before | After | Notes |
|------|--------|-------|-------|
| <route/component> | ![before](<url>) | ![after](<url>) | <what changed> |

## Test plan
<checklist of how to verify -- infer from changes>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Note: `--fill-verbose` set title from commits. Override with `--title` only if auto-gen title poor.

Append `--label <label1> --label <label2>` per verified label.

**Draft mode**: changes look WIP (TODO comments, incomplete impl, test stubs) -> add `--draft`.

## Frontend detection + screenshot table (Phase 5)

**Detect frontend change** -- diff touches any:

- `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.html`
- `tailwind.config.*`, `postcss.config.*`
- `src/components/`, `src/routes/`, `src/pages/`, `src/app/`
- registry UI (`components/ui/`)

Frontend detected -> **require `/visual-review` result or explicit skip reason**, then include Screenshots table. Follow `visual-review/REFERENCE.md` PR evidence contract. Omit section entirely otherwise (no empty table, no "N/A" row).

**Capture before/after:**

- `/visual-review` already ran this session -> reuse its checked views, screenshots, findings, and skip reasons
- `/triage` already ran this session -> reuse captured refs/screenshots (`/qa` is deprecated)
- Else: run `/visual-review`; if user explicitly skips, record reason in PR body
- Fallback: `scripts/skills-browser.sh screenshot --out /tmp/pr-<view>-after.png` per affected view
- Before image: prior PR screenshot, main-branch capture, or `<!-- no prior state -->` for new views
- Upload via `gh pr comment` drag-paste URL, or reference `/tmp/*.png` path if asset host unavailable -- note blocker in PR body

**Row per visual change.** Group by route or component. One-line `Notes` col: what visibly changed (spacing, copy, new state, a11y). No screenshot for backend-only refactors even if a frontend file touched (e.g. type-only `.tsx` edit).