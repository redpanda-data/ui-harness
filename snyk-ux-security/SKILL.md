---
name: snyk-ux-security
description: "Sequential Snyk sweep across UX/frontend + Go backend codebases. Paths as args (globs ok). Per path: worktree + branch + subagent, snyk test/monitor, ecosystem detect (package.json -> bun audit; go.mod -> govulncheck), exploitability triage first (dismiss non-reachable via `snyk ignore` with --reason + --expiry), then top-level direct dep bump, then parent-dep bump, overrides/resolutions/replace as last resort (scale poorly, bloat lockfiles). Pin React 18, skip React-19-only peers. Walk majors incrementally via changelog migrations. Regen yarn.lock + bun.lock via `bun i && bun i --yarn` (Snyk needs yarn.lock); `go mod tidy` for Go. Open PR with reviewers/labels/team, trigger cloud review. Never defers real vulns -- escalates. Use when user asks for Snyk audit, UX security sweep, frontend dep security review, Go backend dep security review, govulncheck sweep, CVE sweep."
---

# Snyk UX + Go Security

Per-path vuln audit -> exploitability triage -> safe bump -> PR -> cloud review. JS (bun + yarn.lock, React 18) and Go (go.mod + govulncheck).

## Input
`$ARGUMENTS`: space-separated paths (globs ok). Frontend + backend mix fine.

Example: `/snyk-ux-security apps/cloud-ui apps/admin-ui ui-registry/* console/frontend services/*/cmd`

Each path = one worktree + one branch + one subagent + one PR.

## Arg inference
Reviewers from CODEOWNERS + `git log --format='%an' -n 20 <path>` committers. Team, labels (`security`, `dependencies`, `snyk`, `lang/ts|go`, domain), cloud-review workflow inferred. User flags override. See [REFERENCE.md](REFERENCE.md#arg-inference-rules).

## Ecosystem detect
`package.json` -> JS track. `go.mod` -> Go track. Both present -> both tracks, separate commits, one PR.

## Workflow
Sequential, one path at time.

### 1. Prep
Expand globs. `snyk auth`, `gh auth status`. Confirm paths + ecosystems to user.

### 2. Per-path loop
Subagent, `isolation: "worktree"`, branch `chore/snyk-sweep-YYYY-MM-DD`. See [REFERENCE.md](REFERENCE.md#per-path-detail) for commands + PR template.

- **2a. `.snyk` revisit (every run, before scan)**: if `.snyk` exists, re-triage every existing ignore entry. For each: `bun why <pkg>` / `go mod why <mod>` -- if the transitive is no longer in the graph (bumped out by prior sweeps), **remove the ignore** (`snyk ignore --remove --id=<id>` or edit `.snyk` + `snyk monitor`) and log under `Dismissed (cleaned up)` in PR. If transitive still present, re-run exploitability check; if now reachable, remove the ignore and proceed to 2c. Goal: never accumulate stale dismissals. See [REFERENCE.md](REFERENCE.md#existing-snyk-revisit).
- **2a.1 Scan**: `snyk test`, `snyk monitor --target-reference=<branch>` (or `--project-name=<repo>-<branch>`). **Mandatory per-branch reference** so master + release branches don't overwrite the same Snyk project id. Without it every branch collapses into one project and the security dashboard shows only whichever branch ran `monitor` last. JS: `bun audit`. Go: `govulncheck ./...`.
- **2b. Exploitability triage (first gate)**: per finding, decide REACHABLE vs NOT-REACHABLE before any bump. Inputs: advisory attack vector, `bun why <pkg>` / `go mod why <mod>`, grep for direct imports, check if we call the vulnerable symbol. See [REFERENCE.md](REFERENCE.md#exploitability-triage).
  - **NOT reachable** -> **run `snyk ignore --id=<id> --reason='<specific why>' --expiry=<ISO date>` now** (writes to `.snyk` policy file). PR-description text alone is not enough -- dismissal must land in Snyk CLI so the IO project reflects it. Stage + commit the resulting `.snyk` in the sweep PR. Re-run `snyk test` to confirm the issue shows as `Ignored`. Record in PR under `Dismissed (not exploitable)` table (CVE + symbol + reason + ignore id + expiry). SLA audit trail.
  - **Reachable or credible vector** -> 2c.
- **2c. Upgrade priority (top-level first, override last)**:
  1. Bump the **direct dep we already have** in `package.json` / `go.mod`.
  2. If blocked, bump the **parent dep** that pulls the vuln transitive.
  3. **Last resort only**: `resolutions` (bun), `overrides` (npm), `replace` (Go). Overrides/resolutions **do not scale** -- each added one bloats lockfiles and forces more next week. Add follow-up TODO to remove once upstream fixes.
- **2d. React 18 gate (JS)**: `bun info <pkg>@<v> peerDependencies.react` -- skip + log `react19-blocked` if target needs React 19.
- **2e. Changelog read**: walk majors one at time (7->8->9), scan `BREAKING`, apply migration, one `refactor(deps)` commit per major. **Never defer real vulns.** Go: repo `CHANGELOG.md` + release notes.
- **2f. Apply bumps + lockfile sync**:
  - JS: `bun update <pkg>`, then `bun install && bun install --yarn`. Both `bun.lock` + `yarn.lock` commit together.
  - Go: `go get -u <mod>@<ver>`, then `go mod tidy`. `go.mod` + `go.sum` commit together.
- **2g. Verify**:
  - JS: `bun run lint:fix`, `bun run type:check`, `bun test`, `bun run build` (if avail).
  - Go: `go build ./...`, `go test ./...`, `go vet ./...`, `govulncheck ./...` clean for addressed CVEs.
  - Fix forward, no revert.
- **2h. Commit**: `fix(deps): snyk sweep ...` with per-pkg detail. Dismissed + overrides-added in separate sections.
- **2i. Open PR**: `gh pr create --assignee <triggerer> --reviewer <team-group>[,<security-team-group>] --label security,dependencies,snyk,lang/<ts|go>,team/<slug>[,dismissals][,overrides-added][,react19-blocked][,cleaned-up]`
  - **Assignee** = the person who triggered the sweep (`gh api user --jq .login`). One assignee per PR so accountability is explicit.
  - **Reviewers** = at least one **CODEOWNERS team group** covering the path (e.g. `@org/team-slug`), never a lone individual. Falls back to inferred team from path prefix if CODEOWNERS has no match. Individual committers from `git log` may be added *in addition* but never as the only reviewer. Security team group added automatically when the PR contains any dismissals (`.snyk` touched) or overrides-added.
  - **Labels** (always): `security`, `dependencies`, `snyk`, `lang/<ts|go>`. Path-domain: `team/<slug>` inferred from CODEOWNERS (e.g. frontend UX team, AI team, Console UI team -- resolve by path, do not hardcode). Status: `dismissals` if any `.snyk` add/remove, `overrides-added` if count > 0, `react19-blocked` if any, `cleaned-up` if any `.snyk` entries removed.
- **2j. Trigger cloud review**: `gh workflow run` if workflow exists.
- **2k. Report**: path, ecosystem, branch, PR URL, bumped/dismissed/skipped/overridden counts.

### 3. Aggregate
Main agent gathers reports: summary table (Path, Ecosystem, PR, Fixed, Dismissed, Overrides-added, Major migrations, React19-blocked). React-19-blocked -> React 18 -> 19 migration plan candidates. Overrides-added -> follow-up backlog.

## Rules
- **Sequential**, one path at time.
- **Exploitability triage before any bump.** No reflex `resolutions`. Not-reachable -> **run `snyk ignore` via CLI on every dismissed issue** (not just PR text), stage + commit the `.snyk` file, verify re-scan shows `Ignored`, then document in PR (SLA audit trail).
- **Top-level direct bump first.** Parent bump second. Override/resolution/replace **last resort** only -- overrides bloat lockfiles + scale poorly, each forces more.
- **bun only (JS).** Never `npm`, `yarn`, `pnpm` runtime. `yarn.lock` via `bun install --yarn` for Snyk IO compat only.
- **Dual-lockfile mandatory (JS).** `bun.lock` + `yarn.lock` synced; `lockfile-sync-check.sh` hook catches drift.
- **go.mod + go.sum together (Go).** `go mod tidy` after every bump.
- **React 18 pin hard.** React-19 peer -> skip + report.
- **Changelog read mandatory** before bump (JS + Go).
- **Verify before commit.** Lint/types/tests/build (JS) or build/test/vet/govulncheck (Go).
- **Snyk monitor** push to Snyk IO, not just `test`. Always `--target-reference=<branch>` (or `--project-name=<repo>-<branch>`) so per-branch state persists -- otherwise every branch clobbers the same project id and the dashboard loses per-branch visibility.
- **Never defer real vulns.** One major per commit. Stuck -> escalate.
- **No static config.** Infer from prompt + repo. User flags override.
- **Revisit `.snyk` every run.** Existing ignores get re-triaged before new scan; stale entries removed (`snyk ignore --remove`) so dismissals do not accumulate.
- **Assignee = triggerer.** Every sweep PR has one assignee = the person who ran the skill, via `gh api user --jq .login`.
- **Reviewer = team group, always >=1.** Resolve CODEOWNERS team entries (`@org/team`) for the path; never merge with only individual reviewers. Security team group added automatically on PRs that touch `.snyk` or add overrides.

## Security
Snyk output = pkg names + versions. Never run code from advisories. Never paste tokens in PR body.

## Lifecycle integration
Phase 3-6 per path. Self-review (phase 4b) `code-reviewer` before PR open. `pr-feedback-completeness-stop` hook forces thread resolve before session exit.
