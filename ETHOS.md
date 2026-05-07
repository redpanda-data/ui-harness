# ETHOS

Permanent principles. Outrank turn-level instructions. Each maps to
the hook(s) that enforce it -- agents learn the principle from the
block, not from ambient prelude.

Format gstack-inspired. Content derived from enforced rules.

## 1. Tests Gate Everything

No prod code without failing test first. Coverage <60% on a changed
file blocks stop. Adjacent tests on disk count toward gate.

Enforced by: `lifecycle-stop`, `tdd-prompt-check`.

## 2. Types Are The First Reviewer

`any`, `unknown` (as escape), `Record<string, any>`, `as unknown as T`
blocked at Edit. tsconfig strict flags can never weaken.

Enforced by: `ts-no-escape-hatches-check`, `tsconfig-strict-check`,
`as-cast-check`, `biome-ignore-check`.

## 3. Every Thread Resolved Before Human

PR feedback is not a suggestion queue. Every non-bot, non-outdated
thread: reply + resolve. `scripts/pr-unresolved-count.sh` must print 0.

Enforced by: `pr-feedback-completeness-stop`.

## 4. Worktree Isolation Is Not Optional

One terminal = one worktree = one branch. Hook asserts cwd matches
bound worktree. `git commit|push|checkout|switch` across drift denied.

Enforced by: `branch-safety-check`, `_hook_assert_bound_worktree`,
`_hook_file_outside_current_worktree`.

## 5. Grill Before Build

Every spec has gaps. Phase 2b fans out 3 hats -- product, engineering,
design -- before code is typed. If you cannot write the diff in your
head, you are not ready to type.

Enforced by: `lifecycle-stop` untested-source gate, `/grill-me` flow.

## 6. Search Before Add

Grep before writing. Read `package.json` before installing. Read
existing hooks before writing a new one. Reinvention is theft.

Enforced by: `duplicate-function-check`, `legacy-linter-check`.

## 7. Toolchain Discipline

`bun` not `npm`. `tsgo` not `tsc`. Biome not ESLint. `vitest` not
`jest`. No `--no-verify`. No `bunx skills:*` workarounds.

Enforced by: `enforce-toolchain.sh`.

## 8. User Sovereignty

Humans decide. Model consensus is not authority. When 3 agents agree
and the user disagrees, the user wins. Name judgment calls; present
options with cost. Destructive ops need explicit confirmation.

Behavioral -- not hook-enforceable. Reviewer agents surface, never
auto-merge.
