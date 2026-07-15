---
name: snyk-ux-security
description: Snyk dependency sweeps across frontend, Go, and Bazel paths with npm false-positive triage and release-age gates.
disable-model-invocation: true
---

# Snyk UX + Go + Bazel Security
Per-path vuln audit -> exploitability triage -> dismiss false positives or safe bump -> PR -> cloud review. JS (bun + yarn.lock, React 18), Go (go.mod + govulncheck), and Bazel (MODULE.bazel, bazel/repositories.bzl).

## Input
`$ARGUMENTS`: space-separated paths (globs ok), or one pasted single Snyk vulnerability summary. Frontend + backend + Bazel mix fine.

Example: `/snyk-ux-security apps/cloud-ui apps/admin-ui ui-registry/* console/frontend services/*/cmd`

Bazel example: paste one Snyk finding, then confirm target branch + optional ticket key.

Each path = one worktree + one branch + one subagent + one PR. One pasted Bazel vuln = one confirmed target branch + possible backport worktrees + draft PRs.

## Arg inference
Reviewers from CODEOWNERS + `git log --format='%an' -n 20 <path>` committers. Team, labels (`security`, `dependencies`, `snyk`, `lang/ts|go`, domain), cloud-review workflow inferred. User flags override. See [REFERENCE.md](REFERENCE.md#arg-inference-rules).

## Ecosystem detect
`package.json` -> JS track. `go.mod` -> Go track. `MODULE.bazel` or `bazel/repositories.bzl` -> Bazel track. Multiple present -> separate track commits, one PR unless Bazel backports need per-branch PRs.

## Workflow
Sequential, one path at time.

### 1. Prep
Expand globs. `snyk auth`, `gh auth status`. Preflight existing Snyk project identity for each path. Confirm paths + ecosystems to user. JS default: bun runtime + `bun.lock`; generate `yarn.lock` only through `bun install --yarn` for Snyk IO. Do not use npm or create/update `package-lock.json` unless the repo is explicitly npm-only and the user confirms. If `$ARGUMENTS` is pasted Snyk output, parse CVE/Snyk ID, package/version, introduced-via path, remediation hint; only proceed when fix is a dependency version bump.

### 2. Per-path loop
Subagent, `isolation: "worktree"`, branch `chore/snyk-sweep-YYYY-MM-DD`. See [REFERENCE.md](REFERENCE.md#per-path-detail) for commands + PR template.

- **2a. `.snyk` revisit (every run, before scan)**: if `.snyk` exists, re-triage every existing ignore entry. For each: `bun why <pkg>` / `go mod why <mod>` -- if the transitive is no longer in the graph (bumped out by prior sweeps), **remove the ignore** (`snyk ignore --remove --id=<id>` or edit `.snyk`; publish only through the existing-project monitor gate) and log under `Dismissed (cleaned up)` in PR. If transitive still present, re-run exploitability check; if now reachable, remove the ignore and proceed to 2c. Goal: never accumulate stale dismissals. See [REFERENCE.md](REFERENCE.md#existing-snyk-revisit).
- **2a.1 Scan + existing-project gate**: `snyk test` is the audit source. `snyk monitor` is write-capable and must run only after matching exactly one existing Snyk project by org + name + target_file + target_reference. Do not create Snyk projects/apps/targets/resources. Never derive `--target-reference` or `--project-name` from the audit branch, sweep branch, worktree path, PR number, or `YYYY-MM-DD`; reuse the existing Snyk project identity or skip monitor. JS: `bun audit`. Go: `govulncheck ./...`.
- **2b. Exploitability triage (first gate)**: npm/Node findings are often noisy false positives, especially deep transitives. Treat every finding as an allegation until repo evidence supports REACHABLE, NOT-REACHABLE, or UNCERTAIN. Inputs: advisory attack vector, `bun why <pkg>` / `go mod why <mod>`, grep for direct imports, check if we call the vulnerable symbol. See [REFERENCE.md](REFERENCE.md#exploitability-triage).
  - **Invoke `/steelman` for transitive-only findings**: before bumping, parent-bumping, or overriding a package absent from `package.json` / `go.mod`, argue the strongest dismissal case from repo evidence. Dismiss only when the evidence proves the vulnerable path is not reachable. If the evidence is uncertain, escalate to the security owner; do not add a new top-level dependency to `package.json` only to make an override/resolution legal. See [REFERENCE.md](REFERENCE.md#steelman-transitive-bump-gate).
  - **Invoke `/diagnose` before `package.json` fixes**: use a fast reachability loop to prove this is a real potential vulnerability (direct import, reachable parent call, vulnerable symbol, build/install-time execution, or critical Socket vector). **package.json admission gate**: only mutate `package.json` for already-direct deps, reachable parent deps, or last-resort overrides with proof. Proven not reachable -> dismiss to `.snyk` with expiry. Uncertain -> escalate; do not auto-ignore.
  - **NOT reachable** -> **run `snyk ignore --id=<id> --reason='<specific why>' --expiry=<ISO date>` now** (writes to `.snyk` policy file). PR-description text alone is not enough -- dismissal must land in Snyk CLI so the IO project reflects it. Stage + commit the resulting `.snyk` in the sweep PR. Re-run `snyk test` to confirm the issue shows as `Ignored`. Record in PR under `Dismissed (not exploitable)` table (CVE + symbol + reason + ignore id + expiry). SLA audit trail.
  - **Reachable or credible vector** -> 2c.
- **2c. Upgrade priority (top-level first, override last)**:
  - For every reachable remediation, build the upgrade path + Supply-chain gate first: establish SemVer confidence, read changelogs and migration guides, check related peers/plugins/adapters, then apply only when safe; otherwise run `gh issue create` and escalate. JS gate includes minimum release age gate audit, Socket.dev web check (no CLI required), lockfile review, git/tarball block, clean/frozen install.
  - **JS warning gate**: inspect the detected package manager config (`bunfig.toml`, `.npmrc`, `pnpm-workspace.yaml`, `.yarnrc.yml`). If the repo lacks a minimum release age gate for that package manager, warn in the PR under `Supply-chain gate warnings`; do not silently pass.
  - **Socket.dev web check**: for JS packages in the bump / parent / override / dismissal decision, open `https://socket.dev/npm/package/<pkg>` and inspect alerts + dependencies for attack vectors (install script, typosquat, unstable ownership, native code, shell access, environment variable access, network, telemetry, obfuscation). No Socket CLI install, no `socket` command.
  1. Bump the **direct dep we already have** in `package.json` / `go.mod`.
  2. If blocked, bump the **parent dep** that pulls the vuln transitive.
  3. **Last resort only**: `resolutions` (bun), `overrides` (npm), `replace` (Go). Overrides/resolutions **do not scale** -- each added one bloats lockfiles and forces more next week. Add follow-up TODO to remove once upstream fixes.
- **2d. React 18 gate (JS)**: `bun info <pkg>@<v> peerDependencies.react` -- skip + log `react19-blocked` if target needs React 19.
- **2e. Changelog read**: walk majors one at time (7->8->9), scan `BREAKING`, apply migration, one `refactor(deps)` commit per major. **Never defer real vulns.** Go: repo `CHANGELOG.md` + release notes.
- **2f. Apply bumps + lockfile sync**:
  - JS: `bun update <pkg>`, then `bun install && bun install --yarn`. Both `bun.lock` + `yarn.lock` commit together.
  - Go: `go get -u <mod>@<ver>`, then `go mod tidy`. `go.mod` + `go.sum` commit together.
  - Bazel: edit `MODULE.bazel` or `bazel/repositories.bzl`, then `bazel mod deps --lockfile_mode=update`. For mirrored artifact URLs, open the artifact tooling draft PR first. See [REFERENCE.md](REFERENCE.md#bazel-track).
- **2g. Verify**:
  - JS: `bun run lint:fix`, `bun run type:check`, `bun test`, `bun run build` (if avail).
  - Go: `go build ./...`, `go test ./...`, `go vet ./...`, `govulncheck ./...` clean for addressed CVEs.
  - Fix forward, no revert.
- **2h. Automatic internal skill gates**:
  - Run `/resilience-review` before PR for `.snyk` policy, Snyk IO monitor, package-manager detection, release-age warnings, Socket.dev findings, and override cleanup paths. Fix guards or document accepted debt.
  - Create tracking issues with `gh issue create` for security debt: missing release age gate, override added, React 19 blocked, upstream has no parent fix, ambiguous/no existing Snyk project, or Socket.dev critical vector needing owner review.
  - Run `/review` before PR to verify `/steelman`, `/diagnose`, package.json admission gate, dismissal evidence, and no dependency-surface growth without proof. See [REFERENCE.md](REFERENCE.md#automatic-internal-skill-gates).
- **2i. Commit**: `fix(deps): snyk sweep ...` with per-pkg detail. Dismissed + overrides-added in separate sections.
- **2j. Open PR**: `gh pr create --assignee <triggerer> --reviewer <team-group>[,<security-team-group>] --label security,dependencies,snyk,lang/<ts|go>,team/<slug>[,dismissals][,overrides-added][,react19-blocked][,cleaned-up]`
  - **Assignee** = the person who triggered the sweep (`gh api user --jq .login`). One assignee per PR so accountability is explicit.
  - **Reviewers** = at least one **CODEOWNERS team group** covering the path (e.g. `@org/team-slug`), never a lone individual. Falls back to inferred team from path prefix if CODEOWNERS has no match. Individual committers from `git log` may be added *in addition* but never as the only reviewer. Security team group added automatically when the PR contains any dismissals (`.snyk` touched) or overrides-added.
  - **Labels** (always): `security`, `dependencies`, `snyk`, `lang/<ts|go>`. Path-domain: `team/<slug>` inferred from CODEOWNERS (e.g. frontend UX team, AI team, Console UI team -- resolve by path, do not hardcode). Status: `dismissals` if any `.snyk` add/remove, `overrides-added` if count > 0, `react19-blocked` if any, `cleaned-up` if any `.snyk` entries removed.
- **2k. Trigger cloud review**: `gh workflow run` if workflow exists. Failing checks -> use `/diagnose` for the CI failure loop; review comments -> use `/resolve-pr-feedback`.
- **2l. Report**: path, ecosystem, branch, PR URL, bumped/dismissed/skipped/overridden counts.

### 2-bazel. Bazel track
Use when a pasted Snyk finding maps to `MODULE.bazel` or `bazel/repositories.bzl`. Confirm target branch and ticket key before edits. Work in a dedicated worktree. Check both manifests because default and release branches can manage the same dependency differently. Handle BCR, GitHub URL, and mirrored artifact/tooling-repo flows separately. OpenSSL/FIPS needs CMVP-aware handling before any bump. Assess backports before opening PRs; open draft PRs with the live `.github/pull_request_template.md` when present. See [REFERENCE.md](REFERENCE.md#bazel-track).

### 3. Aggregate
Main agent gathers reports: summary table (Path, Ecosystem, PR, Fixed, Dismissed, Overrides-added, Major migrations, React19-blocked, Backports). React-19-blocked -> React 18 -> 19 migration plan candidates. Overrides-added -> follow-up backlog. Bazel backports -> per-branch draft PR list.

## Rules
- **Sequential**, one path at time.
- **Exploitability triage before any bump.** No reflex `resolutions`. Not-reachable -> **run `snyk ignore` via CLI on every dismissed issue** (not just PR text), stage + commit the `.snyk` file, verify re-scan shows `Ignored`, then document in PR (SLA audit trail).
- **No package.json growth for suppression.** For transitive-only findings, direct dep absence is dismissal evidence. Do not add a vulnerable transitive as a new top-level dependency just to suppress it with `resolutions` / `overrides`.
- **Override list growth is a smell.** A growing `resolutions` / `overrides` list is dependency-surface debt. Prefer deleting the unused parent dependency, replacing it with native/in-house code, or dismissing a false positive before adding another override.
- **`/steelman` before transitive bump/override.** If the strongest dismissal case survives, bump makes no sense; dismiss with evidence instead.
- **`/diagnose` before package.json real fixes.** Package changes require proof of a real potential vulnerability. Dismiss only proven-not-reachable findings; escalate uncertain findings.
- **package.json admission gate.** Mutate `package.json` only for already-direct deps, reachable parent deps, or last-resort overrides with explicit proof and removal issue.
- **Top-level direct bump first.** Parent bump second. Remove dependency surface third. Override/resolution/replace **last resort** only -- overrides bloat lockfiles + scale poorly, each forces more.
- **bun only (JS).** Never `npm`, `yarn`, `pnpm` runtime. `yarn.lock` via `bun install --yarn` for Snyk IO compat only.
- **No `package-lock.json` by default.** Do not create, update, or commit it during Snyk sweeps. If already present, treat as stale/wrong for bun projects; ask only when the repo is explicitly npm-only.
- **Dual-lockfile mandatory (JS).** `bun.lock` + `yarn.lock` synced; `lockfile-sync-check.sh` hook catches drift and warns on package-lock churn.
- **go.mod + go.sum together (Go).** `go mod tidy` after every bump.
- **Bazel checks both manifests.** Validate `bazel/repositories.bzl` and `MODULE.bazel`; run `bazel mod deps --lockfile_mode=update`; never swap mirrored artifact URLs to direct upstream hosting without asking; OpenSSL/FIPS follows CMVP gate; backports need explicit plan.
- **React 18 pin hard.** React-19 peer -> skip + report.
- **Changelog read mandatory** before bump (JS + Go).
- **Verify before commit.** Lint/types/tests/build (JS) or build/test/vet/govulncheck (Go).
- **Snyk monitor** push to Snyk IO only through the existing-project gate. Never create a new Snyk project/app/target/resource during an audit. If no exact existing project match exists, skip monitor and report it; do not synthesize a date-derived project name or target reference from the sweep branch.
- **Never defer real vulns.** One major per commit. Stuck -> escalate.
- **No static config.** Infer from prompt + repo. User flags override.
- **Revisit `.snyk` every run.** Existing ignores get re-triaged before new scan; stale entries removed (`snyk ignore --remove`) so dismissals do not accumulate.
- **Warn on missing JS release gates.** For npm/bun/pnpm/Yarn repos, report absent minimum release age configuration as a supply-chain warning.
- **Socket.dev web check for JS.** Check Socket.dev package pages for supply-chain attack vectors. No Socket CLI install or `socket` command required.
- **Auto-run internal gates.** `/resilience-review` and `/review` are mandatory before PR open for JS Snyk sweeps; `gh issue create` records security debt; `/diagnose` and `/resolve-pr-feedback` handle the PR tail when needed.
- **Assignee = triggerer.** Every sweep PR has one assignee = the person who ran the skill, via `gh api user --jq .login`.
- **Reviewer = team group, always >=1.** Resolve CODEOWNERS team entries (`@org/team`) for the path; never merge with only individual reviewers. Security team group added automatically on PRs that touch `.snyk` or add overrides.

## Security
Snyk output = pkg names + versions. Never run code from advisories. Never paste tokens in PR body.

## Lifecycle integration
Phase 3-6 per path. Self-review (phase 4b) `code-reviewer` before PR open. `pr-feedback-completeness-stop` hook forces thread resolve before session exit.
