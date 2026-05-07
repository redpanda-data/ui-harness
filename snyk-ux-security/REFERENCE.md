# Snyk UX + Go Security -- Reference

Deep-dive details split out of SKILL.md to keep the main doc under the
line cap. See [SKILL.md](SKILL.md) for the high-level flow.

## Arg inference rules

From the user message, infer per path:

- **reviewers**: CODEOWNERS of the path; fall back to
  `git log --format='%an' -n 20 <path> | sort -u` top contributors.
- **team**: match path prefix -> team slug via `.github/CODEOWNERS`
  team entries. `apps/*-ui`, `ui-registry/*`, `console/frontend` ->
  UX team. `services/*`, `cmd/*`, paths with `go.mod` -> backend
  team.
- **labels**: always `security`, `dependencies`, `snyk`. Add a domain
  label if inferable from path (e.g. `cloud-ui` -> `area/cloud`;
  `services/ingest` -> `area/ingest`). Add `lang/go` on Go paths,
  `lang/ts` on JS paths.
- **cloud review workflow**: look for
  `.github/workflows/*cloud*review*.yml` or equivalent; skip the
  trigger step if none found.
- **PR title/body**: generate per path. Mention ecosystem.

User can override any of these in the prompt:
`/snyk-ux-security apps/cloud-ui --reviewer @alice --label area/cloud`.

## Per-path detail

### 2a. Existing `.snyk` revisit (every run, before scan)

Run this before `snyk test` so the rescan reflects cleanup. Goal:
never let the `.snyk` policy file accumulate stale dismissals. Each
sweep should leave `.snyk` **shorter** than it started, unless the
codebase genuinely needs new ignores.

For every entry in the repo-root `.snyk` (if any):

1. **Still in the dep graph?**
   ```bash
   # JS
   bun why <pkg>
   # Go
   go mod why <module>
   ```
   No results / "not a dependency" -> the transitive was bumped out
   by a prior sweep. Remove the ignore:
   ```bash
   snyk ignore --remove --id=<issue-id>
   # or edit .snyk directly + snyk monitor
   ```
   Log under PR `Dismissed (cleaned up)` section.

2. **Still not reachable?** If the transitive is present, re-run the
   exploitability check from 2b. If reachable now (new caller, new
   entrypoint, code moved), remove the ignore and proceed to 2c to
   upgrade/fix properly.

3. **Expiry passed?** If `expiry` is before today, the CLI already
   stops honoring it -- remove the entry so `.snyk` stays clean.

4. **Reason still valid?** Skim the reason; if the advisory surface
   changed (new CVE on same pkg, patch landed upstream), re-triage.

Report: include a `Revisited .snyk` count (existing entries
inspected) and a `Cleaned up` count (entries removed) in the PR
body + subagent 2k report. Cleanup trims long-term override debt.

### 2a.1 Scan

Resolve the branch reference once:
```bash
branch=$(git rev-parse --abbrev-ref HEAD)
repo_slug=$(basename "$(git rev-parse --show-toplevel)")
ref="${repo_slug}-${branch}"           # e.g. cloudv2-release-2.8
```

JS path:
```bash
snyk test --all-projects --json > .snyk-findings.json
snyk monitor --all-projects --target-reference="$branch"
# Fallback on older CLIs without --target-reference:
# snyk monitor --all-projects --project-name="$ref"
bun audit --json > .bun-audit.json
```

Go path:
```bash
snyk test --file=go.mod --json > .snyk-findings.json
snyk monitor --file=go.mod --target-reference="$branch"
# Fallback: snyk monitor --file=go.mod --project-name="$ref"
govulncheck -json ./... > .govulncheck.json
```

**Why `--target-reference` / `--project-name` is mandatory:**
Without it, every branch that runs `snyk monitor` for the same
repo collapses into a single Snyk IO project id. Master and
release branches then **overwrite each other** on every run, so
the dashboard shows only the findings from whichever branch ran
`monitor` last -- per-branch state is lost.

Observed: `master` + `release-2.8` both monitoring into project id
`22b24cf1-96d9-49e6-9c88-0640121b3aa0` means the security team
cannot distinguish which branch has which findings.

Rule: every `snyk monitor` invocation (new scan and `.snyk`
revisit-cleanup push) supplies `--target-reference="$branch"`.
If the CLI version does not support `--target-reference`, fall
back to `--project-name="${repo}-${branch}"`. The skill never
runs a bare `snyk monitor` without one of the two.

Snyk IO reads `yarn.lock`, not `bun.lock`. If JS repo has no
`yarn.lock`, generate first: `bun install --yarn`.

### 2b. Exploitability triage

For every finding, decide REACHABLE vs NOT-REACHABLE **before any
bump**. This is the most important gate -- skipping it leads to
reflex `resolutions`/`overrides` that bloat `node_modules` and force
more upgrades later.

Inputs:
- Advisory attack vector: read the CVE / GHSA description. Which
  function / endpoint / input surface is the exploit? Server-side
  parser? Client-side SSR? CLI arg? Build-time plugin?
- Import graph:
  - JS: `bun why <pkg>` -- why it's included, which parent(s).
    `grep -rn "from '<pkg>'"` to see if we import it directly.
  - Go: `go mod why <mod>` + `grep -rn '"<mod>"' --include='*.go'`
    for direct imports.
- Our usage: do we call the vulnerable function / hit the vulnerable
  code path? Example: `hono-server` ships as a transitive of the MCP
  SDK protocol package, but we may only use the client half. Server
  feature never imported -> NOT-REACHABLE.

Decision:

- **NOT-REACHABLE** -- dismiss **via the Snyk CLI, not via PR
  description alone**. PR text is not an audit artifact; `.snyk` +
  Snyk IO project state are. Do this per finding, in order:

  1. Run the dismiss now:
     ```bash
     snyk ignore --id=<issue-id> \
       --reason='Not reachable: <specific pkg path + why we do not hit it>' \
       --expiry=$(date -u -v+90d +%Y-%m-%dT%H:%M:%SZ)
     ```
     This writes a policy entry to the `.snyk` file at repo root
     (creates the file if absent). Run from the repo root so the
     policy applies project-wide.
  2. Stage + commit `.snyk` as part of the sweep PR. The dismissal
     must land in git alongside the bumps. A dismissal that only
     lives in the PR description is invisible to CI, auditors, and
     the next sweep.
  3. Push dismissals to Snyk IO:
     ```bash
     # Always include --target-reference="$branch" (or
     # --project-name="${repo}-${branch}") so per-branch state is
     # preserved; see 2a rule below.
     snyk monitor --all-projects --target-reference="$branch"   # JS
     snyk monitor --file=go.mod --target-reference="$branch"    # Go
     ```
     Monitor applies the `.snyk` policy to the IO project, so the IO
     dashboard shows the issue as `Ignored` with the reason +
     expiry. Re-run `snyk test` locally to confirm the issue is
     listed under `Ignored issues` before opening the PR.
  4. **Do not** add the package to `resolutions` / `overrides` /
     `replace`. Dismissal replaces the bump, it does not accompany
     one.

  Record the dismissal in the PR body under `Dismissed (not
  exploitable)`. Include CVE, vulnerable symbol, usage check,
  `snyk ignore` issue id used, reason, expiry date, and a link to
  the IO issue. Expiry forces re-triage so dismissals do not rot.

  If `snyk ignore` errors (e.g. the issue is already ignored,
  auth missing, wrong org context), fix the CLI state before
  opening the PR. Do not fall back to "note in the description"
  -- escalate instead.

- **REACHABLE** (or exploit vector credible and reachability cannot
  be proved false) -- proceed to 2c.

### 2c. Upgrade priority (top-level first, override last)

Always try these in order. Document the order actually taken in the
PR body.

1. **Direct dep bump.** The package is already in our `package.json`
   / `go.mod`. Bump it to a fixing version. This is the default path.
   ```bash
   # JS
   bun update <pkg>@<fixed-version>
   # Go
   go get -u <module>@<fixed-version>
   ```
2. **Parent dep bump.** The vuln is in a transitive. Look up which of
   our direct deps pulls it. Bump that direct dep to a version whose
   transitives pin the fixed version. Prefer this over override --
   one bump, upstream-maintained.
3. **Override / resolution / replace (last resort).** Only when
   direct + parent bump are both blocked (upstream has no fix;
   fixing version needs React 19 and our React 18 pin stands; etc).
   - JS: `package.json` `"resolutions"` (bun/yarn-compatible) or
     `"overrides"` (npm-compatible). We use `resolutions` under bun.
   - Go: `replace` directive in `go.mod`.
   - Add a follow-up TODO: **Remove this override once upstream
     ships a fix**. Include the override in a dedicated PR section
     (`Overrides added -- follow-up to remove`).
   - Explain in the PR body why steps 1 and 2 were blocked.

**Why this order matters:** every added override is tomorrow's
forced upgrade. Overrides accumulate, node_modules bloats,
maintenance compounds weekly. Top-level bumps are upstream-tracked
and self-maintaining.

### 2d. React 18 gate (JS, mandatory)

```bash
bun info <pkg>@<fixed-version> peerDependencies.react
```

- Need `^19` or `>=19` -> **SKIP**. Log `react19-blocked`.
- OK with `^18`, `^17 || ^18`, or `^18 || ^19` -> proceed.

### 2e. Changelog read -- incremental major migration

Vulns **never defer** when reachable. Breaking changes across majors
**must apply**. Only React 19 peer = hard stop.

```bash
# JS
bun info <pkg> repository.url
# Go
go list -m -u <module>
```

Then `curl` raw CHANGELOG.md, or `gh release list --repo <owner>/<repo>`.

**Walk majors one at a time.** Current `7.x` -> target `9.x`:

1. Read `7.x -> 8.0.0` migration notes. Apply code changes. Verify
   (2g). Commit: `refactor(deps): migrate <pkg> to 8.x -- <summary>`.
2. Read `8.x -> 9.0.0` migration notes. Apply. Verify. Commit.
3. Final bump to target patch. Verify. Commit.

Per major step, log in PR body: from-ver, to-ver, `BREAKING` items
done, code spots touched.

Stuck -> escalate (PR comment or ask user). **No skip.** Real
reachable vuln unpatched is not acceptable. Exception: target needs
React 19 peer (2d gate).

### 2f. Apply bumps + lockfile sync

JS:
```bash
bun update <pkg>@<target>
bun install                # sync bun.lock
bun install --yarn         # sync yarn.lock
```

Both lockfiles **must commit together**. Snyk IO scans `yarn.lock`
(no native `bun.lock` support yet). `bun.lock` (text, bun >= 1.2 --
never binary `bun.lockb`) is source of truth for runtime.

Sync checked by `lockfile-sync-check.sh` hook via two signals:

1. `git diff` parity -- both lockfiles must appear in same diff.
2. Package presence -- each added `pkg@ver` in `bun.lock` must
   appear in `yarn.lock` at same version.

Drift -> hook nudges with regen command.

Go:
```bash
go get -u <module>@<target>
go mod tidy
```

`go.mod` + `go.sum` must commit together.

### 2g. Verify

JS:
```bash
bun run lint:fix
bun run type:check
bun test
bun run build              # if available
```

Go:
```bash
go build ./...
go test ./...
go vet ./...
govulncheck ./...          # must be clean for addressed CVEs
```

Any fail -> diagnose, fix, re-run. Must pass before next step. No
revert -- fix forward. Truly stuck -> escalate, no skip.

### 2h. Commit

```
fix(deps): snyk sweep -- <cve-count> vulns, <pkg-count> bumps, <n> dismissed

<bullet per package: pkg@from -> to, CVE, severity>

Dismissed (not exploitable) -- applied via `snyk ignore` + `.snyk` committed:
- <pkg> -- <CVE>, <reason>, snyk ignore --id=<id> expiry <date>

Overrides added (follow-up to remove):
- <pkg> -- <CVE>, <why direct+parent bump blocked>

Lockfiles: bun.lock + yarn.lock regenerated (bun i && bun i --yarn).
Go modules: go.mod + go.sum regenerated (go mod tidy).
Policy: .snyk updated with <n> ignore entries; snyk monitor pushed to IO.

Skipped (React 19 peer only -- everything else migrated):
- <pkg> -- react19-blocked
```

### 2i. Open PR

```bash
# Resolve metadata
triggerer=$(gh api user --jq .login)
team_reviewers=$(bash "$SKILL_DIR/scripts/codeowners-teams.sh" "<path>")
# team_reviewers must be non-empty; if empty, fall back to path-prefix
# -> team map (documented below). Never open a PR with only individual
# reviewers -- require >=1 team group.
labels="security,dependencies,snyk,lang/<ts|go>"
# Add team-domain labels resolved from CODEOWNERS (e.g. team/ux,
# team/ai, team/console-ui). Add status labels based on state.
[ -s .snyk_diff ]            && labels="$labels,dismissals"
[ -s .overrides-added ]      && labels="$labels,overrides-added"
[ -s .react19-blocked ]      && labels="$labels,react19-blocked"

# Always add security team group when .snyk touched or overrides added.
security_team="@<org>/security"

gh pr create \
  --title "fix(deps): snyk sweep <path> -- $(date +%Y-%m-%d)" \
  --body-file .pr-body.md \
  --reviewer "$team_reviewers,$security_team" \
  --label "$labels,team/<slug>" \
  --assignee "$triggerer"
```

**Assignee rule**: one assignee per PR, = the user who triggered
the sweep. Resolve via `gh api user --jq .login` (the authenticated
gh user). Gives clear accountability: anyone scanning open PRs sees
who ran the audit.

**Reviewer rule**: at least one **team group** (`@<org>/<team>`)
resolved from CODEOWNERS entries for the path. Falls back to
path-prefix inference only if CODEOWNERS has no team owner (edit
CODEOWNERS rather than leaving the PR without a team). Individual
committers from `git log` may be added *in addition*, but a PR
with only individual reviewers is rejected (opens a follow-up note
asking the user to update CODEOWNERS). Security team group is
added automatically whenever the PR touches `.snyk` (dismissals)
or adds an `overrides` entry -- they need visibility on every
dismissal + override.

**Label rule**: always `security`, `dependencies`, `snyk`,
`lang/ts` or `lang/go`. Plus team-domain label derived from
CODEOWNERS team slug (examples from Redpanda monorepo: UX team
paths, AI team paths, Console UI team paths -- resolved by path,
not hardcoded). Plus status labels: `dismissals` (on any `.snyk`
add or remove), `overrides-added`, `react19-blocked`, `cleaned-up`
(when `.snyk` entries removed). Labels give one-click filters for
dashboards and oncall sweeps.

### PR body template (`.pr-body.md`)

```markdown
## Summary
Snyk sweep for `<path>` (ecosystem: <js|go|both>) -- <n> CVEs
addressed, <m> newly dismissed, <k> existing `.snyk` entries
revisited, <c> cleaned up (transitive gone / reachable now /
expired). Triggered by @<triggerer>.

## Bumped (top-level direct first, parent dep second)
| Package | From | To | CVE | Severity | Priority path | Major hops |
|---|---|---|---|---|---|---|
| ... | ... | ... | ... | ... | direct / parent / override | 7->8->9 |

## Dismissed (not exploitable)

All entries below were applied via `snyk ignore` (Snyk CLI writes to
`.snyk` policy file, committed in this PR) and pushed to Snyk IO via
`snyk monitor`. PR-description text alone is not an audit artifact --
`.snyk` + IO project state are.

| Package | CVE | Vulnerable symbol | Our usage check | Reason | Snyk ignore id | Expiry | IO link |
|---|---|---|---|---|---|---|---|
| hono-server | CVE-XXXX-YYYY | server.listen | grep -rn "hono-server": only client-side import via MCP SDK protocol; server feature never called | Server feature not imported -- attack surface zero in this repo | 12345 | 2026-07-22 | [IO](https://app.snyk.io/...) |

Verify: `snyk test` shows each row as `Ignored` before PR open.

## Dismissed (cleaned up)

Existing `.snyk` entries removed this sweep -- transitive gone,
reachability changed, or expiry passed. `snyk monitor` pushed the
cleanup to IO so the dashboard reflects fewer live ignores.

| Package | Original CVE | Original ignore id | Reason removed | Proof |
|---|---|---|---|---|
| <pkg> | CVE-... | <id> | Transitive bumped out / reachable now / expired | `bun why <pkg>` -> no results |

## Overrides added (follow-up to remove)
| Package | CVE | Why direct + parent bump blocked | Tracking issue |
|---|---|---|---|
| ... | ... | upstream has no fix yet; filed #NN | #NN |

## Migration notes (per major hop)
- `pkg 7 -> 8`: <breaking changes handled, code locations>
- `pkg 8 -> 9`: <breaking changes handled, code locations>

## Skipped (React 19 peer only)
- `pkg` -- requires React 19, frozen on React 18, tracked as follow-up

## Lockfiles
JS: both regenerated via `bun i && bun i --yarn`. Snyk IO scans
yarn.lock; runtime uses bun.lock.
Go: `go mod tidy` ran; `go.mod` + `go.sum` committed together.

## Changelog review
<link per bumped pkg>

## Verify
JS:
- [x] `bun run lint:fix`
- [x] `bun run type:check`
- [x] `bun test`
- [x] Snyk rescan clean for addressed CVEs
- [x] `.snyk` committed with <n> new ignore entries
- [x] `snyk monitor` pushed ignores to IO
- [x] `snyk test` confirms all dismissed items show as `Ignored`
Go:
- [x] `go build ./...`
- [x] `go test ./...`
- [x] `go vet ./...`
- [x] `govulncheck ./...` clean for addressed CVEs

## Cloud review
Triggered via `<workflow>`.
```

### 2j. Trigger cloud review
```bash
gh workflow run <inferred_workflow> --ref <branch>
```

Skip silently if no cloud-review workflow detected.

### 2k. Report
Subagent returns: path, ecosystem (js/go/both), branch, PR URL,
triggerer (assignee), team reviewers (resolved from CODEOWNERS),
labels applied, `.snyk` revisited count, `.snyk` cleaned-up count
(transitive gone / reachable now / expired), newly-dismissed list
(CVE + reason + snyk ignore id + expiry), `snyk monitor` push
confirmation, bumped list, overrides-added list (CVE + blocker),
skipped list (reason), CI status.

## Aggregate

Main agent gathers reports. Summary table:

| Path | Ecosystem | PR | Fixed (direct) | Fixed (parent) | Overrides added | Dismissed | Major migrations | React19-blocked |
|---|---|---|---|---|---|---|---|---|

Show React-19-blocked pkgs -- candidates for the React 18 -> 19
migration plan. Show overrides-added as a follow-up backlog --
remove each once upstream ships a fix.

## Go ecosystem notes

- Use `snyk test --file=go.mod --file=go.sum`. Snyk supports Go
  modules natively.
- `govulncheck` is the Go-native static reachability tool from the Go
  security team. Prefer its reachability verdict over raw CVE lists
  -- it flags only vulns actually reachable from call graph. This
  feeds the exploitability triage (2b) for Go paths.
- For transitive-only vulns that `govulncheck` marks non-reachable,
  dismiss via `snyk ignore` with reason `govulncheck: not reachable
  from call graph`.
- Never use `replace` directive as a first move. Direct
  `go get -u <module>` comes first; `replace` is last resort and
  needs a tracking issue.
- `go mod tidy` after every change. Never hand-edit `go.sum`.
- Ensure `go.mod` `go 1.XX` directive stays within the repo's
  supported range (don't bump the toolchain line as part of a CVE
  sweep -- that's a separate change).
