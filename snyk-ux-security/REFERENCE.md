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

Reachable remediation follows the upgrade flow below. This skill owns vulnerability triage, Snyk IO state, the version path, SemVer confidence, changelog/migration/codemod research, related dependency checks, and the apply-vs-issue risk gate.

Bazel remediation is intentionally separate from the JS/Go upgrade flow:
the risk is usually in Bazel manifest semantics, release/backport branch
differences, S3-hosted artifacts, and FIPS validation. Use the
[Bazel track](#bazel-track) when the finding maps to
`MODULE.bazel` or `bazel/repositories.bzl`.

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
   # or edit .snyk directly; publish only through the existing-project
   # monitor gate in 2a.1
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

### 2a.1 Scan + existing Snyk project preflight

`snyk monitor` creates a project in Snyk IO when the supplied identity
does not already exist. In this skill, audits must **not** create new
Snyk projects, targets, apps, or resources. The default audit signal is
`snyk test`; `monitor` is a gated publish step that reuses exactly one
existing Snyk project.

Resolve repo identity once:
```bash
repo_slug=$(basename "$(git rev-parse --show-toplevel)" .git)
```

The audit branch (often `chore/snyk-sweep-YYYY-MM-DD`) is **never** a
Snyk identity. Do not derive `--target-reference`, `--project-name`,
target names, app names, or resource names from the audit branch,
sweep branch, worktree path, PR number, date, or timestamp.

Preflight existing projects before any monitor call:
```bash
# Requires Snyk Projects API read permission (`org.project.read`).
# Query `/orgs/{org_id}/projects` and filter by stable Snyk identity:
# `names_start_with`, `target_file`, and existing `target_reference`.
: "${SNYK_ORG_ID:?Set SNYK_ORG_ID to the existing Snyk org UUID}"
: "${SNYK_TOKEN:?Set SNYK_TOKEN for read-only project preflight}"
curl -fsS \
  -H "Authorization: Token ${SNYK_TOKEN}" \
  -H "Accept: application/vnd.api+json" \
  "https://api.snyk.io/rest/orgs/${SNYK_ORG_ID}/projects?version=2025-11-05&names_start_with=${repo_slug}" \
  > .snyk-projects.json
```

Match rules:

1. Match by existing org, project `name`, `target_file`
   (`package.json`, workspace manifest path, `go.mod`, and so on), and
   `target_reference` if the existing project has one.
2. Exactly one match per target file -> monitor may run using that
   exact identity.
3. Zero matches -> **skip monitor**. Do not run `snyk monitor`; do not
   create a project. Record `monitor: skipped (no existing project)`.
4. More than one match -> **skip monitor** and ask the Snyk/security
   owner to disambiguate. Do not guess.
5. Do not run `snyk monitor --all-projects`. Use per-file monitor calls
   only after exact preflight.

JS path:
```bash
snyk test --all-projects --json > .snyk-findings.json
bun audit --json > .bun-audit.json

# Existing-project publish only, after the API preflight found one
# exact project for this target_file.
snyk monitor \
  --file="$existing_target_file" \
  --org="$SNYK_ORG_ID" \
  --project-name="$existing_project_name" \
  ${existing_target_reference:+--target-reference="$existing_target_reference"}
```

Go path:
```bash
snyk test --file=go.mod --json > .snyk-findings.json
govulncheck -json ./... > .govulncheck.json

# Existing-project publish only, after the API preflight found one
# exact go.mod project.
snyk monitor \
  --file="$existing_target_file" \
  --org="$SNYK_ORG_ID" \
  --project-name="$existing_project_name" \
  ${existing_target_reference:+--target-reference="$existing_target_reference"}
```

If the existing project has no `target_reference`, omit
`--target-reference`; adding a new branch/reference would create
another project. If the existing project uses a stable reference such
as `main`, `master`, or a release line, reuse that exact value. Never
use the audit branch.

Snyk IO reads `yarn.lock`, not `bun.lock`. If JS repo has no
`yarn.lock`, generate first: `bun install --yarn`.

### 2a.2 JS package manager stance

Use Snyk IO plus `bun audit` plus Socket.dev for JS signal. Do not
reach for npm tooling during sweeps.

Rules:

1. **Runtime/install/update/audit commands use bun.** Use `bun why`,
   `bun update`, `bun install`, `bun install --yarn`, `bun audit`,
   and `bun info`. Do not run `npm audit`, `npm install`,
   `npm update`, `npm view`, `yarn add`, `yarn audit`, or `pnpm audit`.
2. **`yarn.lock` is a Snyk compatibility mirror.** Generate it with
   `bun install --yarn`; do not run Yarn directly.
3. **`package-lock.json` is not part of the default flow.** Do not
   create, update, or commit `package-lock.json` for a bun project.
   If a Snyk sweep introduces one, delete it and rerun
   `bun install && bun install --yarn`.
4. **Existing `package-lock.json` gets suspicion, not churn.** If the
   repo also has `bun.lock` or project docs say bun, treat
   `package-lock.json` as stale/wrong and leave a note or remove it
   only if the sweep created it. If the repo is explicitly npm-only
   (`packageManager: "npm@..."`, no bun/yarn lockfiles), ask the user
   before touching dependencies; this skill is optimized for bun +
   Snyk IO.
5. **Evidence gate for npm transitives.** Deep Node/npm transitives are
   commonly not exploitable from shipped code. A Snyk "introduced via"
   chain is not enough. Dismiss only when repo evidence proves the
   vulnerable path is not reachable and Socket.dev shows no credible
   install/build-time risk. Escalate uncertain findings.

### 2b. Exploitability triage

For every finding, decide REACHABLE vs NOT-REACHABLE vs UNCERTAIN
**before any bump**. This is the most important gate -- skipping it leads to
reflex `resolutions`/`overrides` that bloat `node_modules` and force
more upgrades later.

Default stance for npm/Node.js packages: Snyk output is an allegation,
not proof. Many findings are false positives for browser/UI repos,
dev-only tools, optional server plugins, and packages present only in
lockfiles. Dismiss with `.snyk` when no repo code path reaches the
vulnerable behavior and Socket.dev does not show credible
install-time/build-time risk. If the evidence remains uncertain,
escalate to the security owner rather than auto-ignoring the finding.

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

### /steelman transitive bump gate

Invoke `/steelman` before any JS transitive-only bump, parent bump, or
override/resolution when the vulnerable package is absent from
`package.json`.

Goal: prevent "fixes" that merely grow `package.json` or lockfile debt
when the app does not use the vulnerable package.

Required output in PR evidence:

1. **Claim to challenge:** "We need to bump or override `<pkg>`."
2. **Strongest case to dismiss:** argue the strongest case for
   dismissal first, using repo evidence:
   - package absent from `package.json`;
   - `bun why <pkg>` shows only deep transitive path;
   - no direct imports;
   - parent feature/code path unused by shipped UI;
   - vulnerable symbol not called;
   - Socket.dev shows no install-time/build-time credible vector.
3. **Contradicting evidence:** direct import, reachable parent call,
   vulnerable symbol usage, install script, build-time execution, or
   critical Socket.dev supply-chain alert.
4. **Verdict:**
   - `dismiss`: strongest dismissal case survives -> `snyk ignore`
     with parent chain + symbol evidence.
   - `fix-parent`: vulnerable path reachable only through parent ->
     bump parent, not transitive.
   - `override-last-resort`: direct + parent blocked, vector credible,
     and policy cannot dismiss.

If evidence proves the vulnerable behavior is not reachable, the bump
makes no sense. Dismiss with expiry instead of growing the dependency
surface. If the evidence is inconclusive, escalate; absence of proof is
not proof that the finding is safe to ignore.

### /diagnose reachability loop

Invoke `/diagnose` before any `package.json` change that claims to fix
a JS security finding. Treat the Snyk finding as a bug report and build
a fast feedback loop that can prove the vulnerable surface is relevant
to this repo.

Acceptable loops:

- `grep` / import graph proves app code imports the vulnerable package
  or the direct parent feature that calls it.
- A unit or integration harness calls the same parent API and reaches
  the vulnerable symbol / file.
- A bundler or build script path proves the vulnerable package executes
  during build, install, or CI.
- Socket.dev shows a critical install-time or build-time supply-chain
  vector: known malware, install script payload, shell access,
  environment variable access, typosquat, or unstable ownership plus a
  newly introduced version.

Not enough:

- Snyk says "introduced via" without evidence the parent path is used.
- The package exists somewhere in `node_modules`.
- The package name appears only in lockfiles.
- "Fix available" exists but the package is several layers deep and no
  vulnerable symbol is reachable.

Verdict rule:

- Proven reachable / credible install-time vector -> proceed to the
  [Package.json admission gate](#packagejson-admission-gate).
- Proven not reachable -> dismiss with `snyk ignore`, expiry, parent
  chain, and diagnostic evidence.
- Uncertain -> escalate to the security owner; do not auto-ignore or
  mutate `package.json`.

The PR must call this a **real potential vulnerability** before any
package manifest change is allowed.

### Package.json admission gate

`package.json` is not a suppression ledger. It is the public dependency
surface. A Snyk fix may mutate `package.json` only when one of these
admission reasons is true:

1. **Already-direct vulnerable dependency.** The vulnerable package is
   already declared in `dependencies` / `devDependencies`, and
   `/diagnose` proves direct use or install/build-time execution.
2. **Reachable direct parent.** The vulnerable package is transitive,
   but the direct parent is already declared and `/diagnose` proves the
   parent path reaches the vulnerable behavior. Bump the parent, not the
   transitive.
3. **Last-resort override.** Direct and parent fixes are blocked,
   the vulnerability is a real potential vulnerability, security policy
   cannot dismiss it, and the PR includes a removal tracking issue.

Anything else stays out of `package.json`. Use `.snyk` dismissal with a
90-day expiry and precise reason only when the finding is proven not
reachable. Escalate uncertain findings instead of hiding them or
creating dependency debt.

Treat every new `resolutions` / `overrides` entry as a code smell and
every existing long override list as a burn-down queue. The safest
dependency is the one absent from the graph: before adding an override,
ask whether the direct parent can be deleted, whether the feature is
unused, or whether native/in-house code can replace the third-party
dependency with less total surface area. Lower third-party surface area
means fewer future advisories, fewer transitive surprises, and less
lockfile churn.

### Transitive-only dismissal checklist

Use this checklist before adding any override/resolution for a finding
several layers deep in `node_modules`.

1. **Direct dependency absence is evidence.** If the vulnerable package
   is not listed in `package.json`, that supports a dismissal path; it
   does not justify adding the transitive as a new top-level dependency.
2. Identify the parent chain with `bun why <pkg>` and record the first
   direct parent that introduced it.
3. Grep imports for both package names:
   ```bash
   grep -rn "from ['\"]<pkg>['\"]\\|require(['\"]<pkg>['\"])" .
   grep -rn "from ['\"]<parent>['\"]\\|require(['\"]<parent>['\"])" .
   ```
4. Map the advisory to a vulnerable symbol / file / runtime behavior.
   A CVE on a server parser, CLI, dev-only loader, or optional plugin
   is not automatically reachable from a browser UI bundle.
5. If the parent code path is unused, optional, SSR-only, build-only, or
   outside shipped UI code, dismiss with `snyk ignore` and a precise
   reason. Include the parent chain + symbol proof.
6. If the parent code path is reachable, first ask whether the parent
   dependency or feature can be removed entirely. Prefer deletion,
   native platform behavior, or small in-house code when that lowers
   total dependency surface area.
7. If removal is not viable, fix the parent before any override. Do
   not add the vulnerable transitive to `package.json` just to make a
   suppression-only override easier.
8. Override/resolution only when direct + parent remediation and
   dependency removal are all blocked, and the vulnerability is still
   reachable or Snyk cannot be ignored for policy reasons. Add a
   removal issue and a burn-down note.
9. In short: do not add a transitive package to `package.json` just to
   suppress a nested finding.

Anti-pattern to reject in review:

```diff
+ "vulnerable-transitive": "x.y.z"
+ "resolutions": { "vulnerable-transitive": "x.y.z" }
```

If we do not use the library directly, this grows the public dependency
surface just to silence a nested finding. Prefer `.snyk` dismissal with
expiry when not reachable, or parent bump when reachable.

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
  3. Publish dismissals to Snyk IO only if an existing project match
     was verified in 2a.1:
     ```bash
     # Use the exact existing Snyk project identity from 2a.1.
     snyk monitor --file="$existing_target_file" \
       --org="$SNYK_ORG_ID" \
       --project-name="$existing_project_name" \
       ${existing_target_reference:+--target-reference="$existing_target_reference"}
     ```
     Monitor applies the `.snyk` policy to the existing IO project, so
     the dashboard shows the issue as `Ignored` with the reason +
     expiry. If there is no exact existing project match, **skip
     monitor** and record that IO will update after merge through the
     normal Snyk integration or after a security owner links the
     existing resource. Re-run `snyk test` locally to confirm the issue
     is listed under `Ignored issues` before opening the PR.
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

- **UNCERTAIN** -- stop and escalate to the security owner. Do not
  auto-ignore and do not mutate dependency manifests without a verdict.

- **REACHABLE** (or exploit vector credible) -- proceed to 2c.

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
3. **Dependency surface removal.** If the parent dependency exists only
   for a small/unused feature, remove it or replace it with native or
   in-house code before accepting more third-party surface area. This
   is often safer than pinning nested packages forever.
4. **Override / resolution / replace (last resort).** Only when
   direct + parent bump and dependency removal are all blocked
   (upstream has no fix; fixing version needs React 19 and our React
   18 pin stands; etc).
   - JS: `package.json` `"resolutions"` (bun/yarn-compatible) or
     `"overrides"` (npm-compatible). We use `resolutions` under bun.
   - Go: `replace` directive in `go.mod`.
   - Add a follow-up TODO: **Remove this override once upstream
     ships a fix**. Include the override in a dedicated PR section
     (`Overrides added -- follow-up to remove`).
   - Explain in the PR body why steps 1 and 2 were blocked.

**Why this order matters:** every added override is tomorrow's forced
upgrade and a smell that the dependency graph is taking control of the
app. Overrides accumulate, node_modules bloats, maintenance compounds
weekly, and each nested pin can pull in more packages with their own
advisories. Lower third-party surface area is the durable win.

### Minimum release age gate audit (JS)

For Node.js / TypeScript / UI repos, treat dependency installation as a
supply-chain boundary. A lockfile helps reproducibility, but it does not
stop a fresh malicious version from entering the lockfile during an
upgrade. Audit the detected package manager before applying a JS bump.

Detection:

| Package manager signal | Config to check | Expected gate |
|---|---|---|
| `bun.lock` or bun toolchain | `bunfig.toml` | `minimumReleaseAge = <seconds>` |
| `package-lock.json` or npm toolchain | `.npmrc` | npm-only exception; otherwise warn and do not touch `package-lock.json` |
| `pnpm-lock.yaml` | `pnpm-workspace.yaml` or `.npmrc` | `minimumReleaseAge: <minutes>` |
| `.yarnrc.yml` / modern Yarn | `.yarnrc.yml` | `npmMinimalAgeGate: "<duration>"` |

If the detected package manager has no gate, add this PR warning:

```markdown
## Supply-chain gate warnings
- WARN: release age gate missing for <bun|npm|pnpm|yarn>.
  Configure the package-manager-native minimum release age gate before
  broad dependency churn. This sweep continued because it fixes a Snyk
  issue, but future upgrades should not silently accept fresh releases.
```

Do not invent config in the Snyk PR unless the user asked for policy
hardening. The warning is enough for a vuln sweep; a separate follow-up
can set org-wide policy.

If `package-lock.json` is present in a bun repo, add this PR warning
instead of using npm:

```markdown
## Supply-chain gate warnings
- WARN: package-lock.json present in a bun/Snyk sweep. Do not use npm
  or commit package-lock churn. Keep `bun.lock` as runtime truth and
  `yarn.lock` as the Snyk IO mirror generated by `bun install --yarn`.
```

Reference docs checked while creating this gate:

- Bun: `minimumReleaseAge` in `bunfig.toml` or
  `--minimum-release-age` filters newly published npm versions.
  https://bun.com/docs/pm/cli/install#minimum-release-age
- npm: `min-release-age` in `.npmrc` constrains installs to versions
  older than the given number of days.
  https://docs.npmjs.com/cli/install/#min-release-age
- pnpm: `minimumReleaseAge` is minutes, applies to direct and
  transitive deps, and has exclusions.
  https://pnpm.io/settings#minimumreleaseage
- Yarn: `npmMinimalAgeGate` delays installing newly published packages;
  `npmPreapprovedPackages` bypasses package gates.
  https://yarnpkg.com/features/security#age-gate

### Socket.dev web check

Use Socket.dev as an extra web-only supply-chain signal for JS package
decisions. This is **no Socket CLI** flow: no install, no `socket`
command, no local plugin requirement.

For each package involved in a bump, parent bump, override, or
dismissal decision:

1. Open the package page:
   - unscoped: `https://socket.dev/npm/package/<pkg>`
   - scoped: `https://socket.dev/npm/package/%40scope/name`
2. Check the overview / alerts / dependencies pages. Record high-signal
   attack vectors:
   - known malware, typosquat, protestware/troll package;
   - recently published, unstable ownership, new author;
   - install script, shell access, environment variable access,
     filesystem access, network access, telemetry;
   - obfuscated file, high entropy strings, native code;
   - git/http dependency, wildcard dependency, unpublished/deprecated
     package, unmaintained package.
3. Treat Socket as a triage signal, not a replacement for Snyk:
   - A critical Socket supply-chain alert can upgrade a NOT-REACHABLE
     CVE into "credible vector" if install-time or build-time execution
     affects CI/dev machines.
   - Low capability alerts alone do not block a security bump, but must
     be recorded when they explain added risk.
4. Add a `Socket.dev` row to PR evidence:
   `pkg`, page URL, highest alert, attack vector, decision impact.

Useful Socket docs:

- Package pages expose score, alerts, dependencies, maintainers, and
  version views: https://socket.dev/npm/package/react
- Socket alert categories include supply-chain risk, quality,
  maintenance, vulnerability, and license:
  https://docs.socket.dev/docs/package-issues
- Socket GitHub/App docs list common vectors like install scripts,
  telemetry, native code, known malware, mutable git/http deps,
  protestware, and typosquats:
  https://docs.socket.dev/docs/socket-for-github
- Socket capability detection covers network, shell, filesystem,
  `eval()`, and environment variables:
  https://docs.socket.dev/docs/faq#how-does-sockets-capability-detection-work

### Automatic internal skill gates

The Snyk sweep owns security state, so it should invoke these skills
internally instead of relying on the user to remember them.

1. **`/resilience-review` before PR.**
   Run after verify and before commit/PR. Focus the review on:
   - `.snyk` write succeeded, expiry exists, rescan shows `Ignored`;
   - existing-project Snyk IO monitor pushed or skipped with reason;
   - package manager detection is correct;
   - missing release age gate warning is visible;
   - Socket.dev web check result is recorded;
   - override has removal issue and rollback path;
   - ambiguous workspace or multi-lockfile cases have guards.
   `NEEDS_GUARDS` means fix or document an explicit accepted risk in
   PR evidence.

2. **Create tracking issues with `gh issue create` for security debt.**
   Create or draft issues whenever the sweep leaves follow-up work:
   - missing release age gate;
   - override / resolution / Go replace added;
   - React 19 blocked;
   - upstream has no parent fix;
   - no exact existing Snyk project match or ambiguous project match;
   - Socket.dev critical/high vector needs owner review but was not
     fixed in this PR.
   If tracker publishing is unavailable, include issue drafts in the PR
   body with owners and acceptance criteria.

3. **`/review` before PR.**
   Review must explicitly check the package.json admission gate,
   `/steelman` dismissal argument, `/diagnose` reachability loop,
   `.snyk` dismissal evidence, and absence of dependency-surface growth
   without proof. A review finding on these gates blocks PR open unless
   the user or security owner overrides it in writing.

4. **PR tail.**
   After PR open, failing checks route to `/diagnose`; review
   comments route to `/resolve-pr-feedback`.

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

Any fail -> `/diagnose`, fix, re-run. Must pass before next step. No
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
Policy: .snyk updated with <n> ignore entries.
Existing-project monitor: pushed to existing Snyk IO project <id> /
skipped (<reason>; no new project created).

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

## Reachability diagnosis (`/diagnose`)
| Package | Finding | Feedback loop | Real potential vulnerability? | Decision |
|---|---|---|---|---|
| <pkg> | <CVE/GHSA> | grep/import graph / harness / Socket.dev critical vector | yes/no | bump parent / direct bump / dismiss to `.snyk` |

## Package.json admission gate
| Package | Admission reason | Why `.snyk` dismissal is not enough | Removal issue if override |
|---|---|---|---|
| <pkg> | already-direct / reachable parent / override-last-resort | <proof> | #NN or none |

## Internal skill gates
- `/resilience-review`: PASS / NEEDS_GUARDS / BLOCKED -- <summary>
- `gh issue create`: <n> issue(s) created or drafted for missing release age gate / overrides / React 19 / upstream no fix / Snyk project ambiguity / Socket.dev critical vector
- `/review`: PASS / BLOCKED -- package.json admission gate, `/steelman`, `/diagnose`, and `.snyk` evidence checked

## Supply-chain gate warnings
- WARN: release age gate missing for `<package-manager>` (if absent).
  Follow-up: configure the package-manager-native minimum release age
  gate (`bunfig.toml`, `.npmrc`, `pnpm-workspace.yaml`, or
  `.yarnrc.yml`) before broad dependency churn.

## Socket.dev web check
No Socket CLI was installed or required.

| Package | Socket URL | Highest alert | Attack vector | Decision impact |
|---|---|---|---|---|
| <pkg> | https://socket.dev/npm/package/<pkg> | <alert> | install script / typosquat / unstable ownership / native code / shell access / environment variable access / none | bumped / dismissed / escalated |

## Dismissed (not exploitable)

All entries below were applied via `snyk ignore` (Snyk CLI writes to
`.snyk` policy file, committed in this PR). If the existing-project
preflight found an exact match, `snyk monitor` pushed them to that
existing Snyk IO project. If no exact match existed, monitor was
skipped rather than creating a new project; the committed `.snyk` file
is still the audit artifact. PR-description text alone is not an audit
artifact.

| Package | CVE | Vulnerable symbol | Our usage check | Reason | Snyk ignore id | Expiry | IO link |
|---|---|---|---|---|---|---|---|
| hono-server | CVE-XXXX-YYYY | server.listen | grep -rn "hono-server": only client-side import via MCP SDK protocol; server feature never called | Server feature not imported -- attack surface zero in this repo | 12345 | 2026-07-22 | [IO](https://app.snyk.io/...) |

Verify: `snyk test` shows each row as `Ignored` before PR open.

## Dismissed (cleaned up)

Existing `.snyk` entries removed this sweep -- transitive gone,
reachability changed, or expiry passed. Existing-project `snyk monitor`
pushed the cleanup to IO when the project match was exact; otherwise
monitor was skipped to avoid project churn.

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
No npm commands ran, and no `package-lock.json` was created or
updated. If `package-lock.json` already existed in a bun repo, it was
reported as supply-chain drift instead of being used.
Go: `go mod tidy` ran; `go.mod` + `go.sum` committed together.

## Changelog review
<link per bumped pkg>

## Verify
JS:
- [x] `bun run lint:fix`
- [x] `bun run type:check`
- [x] `bun test`
- [x] Minimum release age gate audit completed; warnings recorded if missing
- [x] Socket.dev web check completed for JS packages; no Socket CLI used
- [x] Snyk rescan clean for addressed CVEs
- [x] `.snyk` committed with <n> new ignore entries
- [x] Existing-project `snyk monitor` pushed ignores to IO, or skipped
      with reason and no new project created
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
(CVE + reason + snyk ignore id + expiry), existing-project
`snyk monitor` status (pushed/skipped + reason), bumped list,
overrides-added list (CVE + blocker), JS release-age gate status
(configured/missing + package manager), Socket.dev findings
(package + highest alert + decision impact),
skipped list (reason), CI status.

## Aggregate

Main agent gathers reports. Summary table:

| Path | Ecosystem | PR | Fixed (direct) | Fixed (parent) | Overrides added | Dismissed | Major migrations | React19-blocked |
|---|---|---|---|---|---|---|---|---|

Show React-19-blocked pkgs -- candidates for the React 18 -> 19
migration plan. Show overrides-added as a follow-up backlog --
remove each once upstream ships a fix. Show release-age gate missing
warnings and Socket.dev high/critical alerts as supply-chain follow-up
items.

## Bazel track

Use for Snyk findings in Bazel dependency manifests. This mode normally
starts from one pasted Snyk vulnerability summary, not a path sweep.

### Parse and gate

Extract from the pasted Snyk output:

- CVE, GHSA, or Snyk issue id.
- Vulnerable package, installed version, and fixed version.
- "Introduced via" dependency path.
- Remediation hint.

Only fix findings resolved by increasing a dependency version. If the
hint requires a code change, patch file, config change, or a product
mitigation, stop and tell the user which non-bump action is needed.

### Branch, ticket, and worktree

Before edits:

1. Show the current branch with `git branch --show-current`.
2. Ask the user to confirm the target branch. Use the repo default or
   mainline branch for primary fixes; release branches follow repo policy.
3. Ask whether there is a ticket key. If provided, append `FIXES=<key>`
   or the repo-specific tracker footer to every PR body so auto-linking
   works.
4. Fetch the confirmed branch and create a separate worktree. Branch
   naming: `snyk/<cve-id>-<package>-<version>`. Include the target
   branch in the worktree path so parallel backports do not collide.

Work only in the worktree. Never modify the user's current checkout for
Bazel CVE fixes.

### Manifest validation

Check both files on every target branch:

```bash
grep -n "<package>" bazel/repositories.bzl || true
grep -n "<package>" MODULE.bazel || true
```

- `bazel/repositories.bzl` manages `http_archive` style dependencies,
  including GitHub URLs and mirrored artifact URLs.
- `MODULE.bazel` manages BCR dependencies through `bazel_dep`.

A package may be in either file, and branch drift is common: the default
branch can use BCR while a release branch still uses a mirrored artifact.
If the package appears in neither file, stop and report that the Snyk
path does not match this branch.

### Update mechanism

| Manifest location | Action | Follow-up |
|---|---|---|
| `MODULE.bazel` `bazel_dep` | Bump the version field. | Run `bazel mod deps --lockfile_mode=update`. If BCR has not published the fix yet, still open a draft PR and let CI prove availability before inventing workarounds. |
| `bazel/repositories.bzl` GitHub URL | Update URL/tag, `sha256`, and `strip_prefix` when present. | Run `bazel mod deps --lockfile_mode=update`. |
| `bazel/repositories.bzl` mirrored artifact URL | Add the new upstream artifact to the repository's artifact mirror/tooling repo first, then point the Bazel manifest at the mirrored artifact. | Open the artifact tooling draft PR first; the target PR depends on it. Never change a mirrored artifact URL to `github.com` or any direct upstream host without asking the user. |
| Other URL source | Stop and ask. | Do not guess hosting policy. |

For direct URL updates, compute and record the new `sha256` from the
actual release artifact. Do not reuse checksums or hand-edit lockfiles.

### Artifact mirror dependency flow

When the current URL points at an organization-owned S3, GCS, or binary
artifact mirror:

1. Find the new upstream release artifact and checksum it.
2. Locate or clone the artifact tooling repository named in project docs.
3. Add the new artifact entry to the repo's dependency mirror manifest
   with mirror filename, source URL, and `sha256`.
4. Open an artifact tooling `--draft` PR from a branch named
   `snyk/<cve-id>-<package>-<version>`.
5. Update `bazel/repositories.bzl` in the target worktree only after
   the tooling PR exists; tell reviewers the target PR cannot land until
   the mirror update merges and uploads the artifact.

### OpenSSL and FIPS

OpenSSL findings need named-entry handling:

- Search `bazel/repositories.bzl` by `name =`, not only package text.
- Treat `@openssl` as the normal base OpenSSL build; update for routine
  CVEs when tests pass.
- Treat `@openssl-fips` as a CMVP-validated FIPS provider. Do not bump
  it unless the target version is CMVP validated for the required FIPS
  certificate path.

Decision tree for `@openssl-fips`:

1. Check whether a CMVP-validated fixed version exists.
2. If yes, bump like a normal dependency and document the validation
   source.
3. If no, decide reachability: is the vulnerable algorithm or code path
   used by the FIPS build? If not reachable, suppress through Snyk with
   a specific rationale and security approval. If reachable or unknown,
   escalate to security engineering for impact assessment; do not land a
   blind version bump that invalidates FIPS.

Useful sources to check during execution: NIST CMVP validated modules,
NIST modules in process, project FIPS docs, and upstream OpenSSL
security policy documents.

### Backport assessment

Before opening target PRs, inspect each affected branch, including the
default branch if the first target is a release branch:

```bash
git show origin/<branch>:bazel/repositories.bzl | grep -A6 "<package>" || true
git show origin/<branch>:MODULE.bazel | grep "<package>" || true
```

For every branch, record:

- current dependency version;
- correct fixed version for that branch line;
- mechanism: BCR, GitHub URL, mirrored artifact, or other;
- whether an artifact tooling PR is needed;
- expected PR base branch.

Present the backport plan to the user and ask which branches to proceed
with before opening PRs. Each confirmed branch gets its own worktree and
draft PR.

### Bazel PR format

Open all Bazel PRs as draft PRs with `gh pr create --draft` when the fix touches release/backport branches, mirrored artifacts, FIPS-sensitive dependencies, or uncertain BCR availability.

Target PR body:

1. Read `.github/pull_request_template.md` from the live target branch
   when present; otherwise use the standard skill PR body.
2. Preserve all HTML comments when a template exists.
3. Fill the top summary with the package bump, CVE/Snyk id, affected
   branches, and artifact-tooling dependency note if applicable.
4. Leave backport checkboxes unchecked; reviewers decide.
5. Fill release notes with a `### Bug Fixes` entry for the CVE fix.
6. Append `FIXES=<ticket-key>` at the end when a ticket key was provided.

Title and commit format for security bumps:

```text
build/deps: upgrade <package> to vX.Y.Z (<CVE-ID>)
```

If an artifact tooling PR exists, include its URL in the target PR body
and in the final report.

### Bazel report

Return:

- target branch and backport branches;
- manifest path touched (`MODULE.bazel` or `bazel/repositories.bzl`);
- old and new dependency versions;
- lockfile command result for `bazel mod deps --lockfile_mode=update`;
- artifact tooling draft PR URL, if any;
- target draft PR URL per branch;
- ticket key used or "none";
- FIPS decision, if OpenSSL-related.

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
