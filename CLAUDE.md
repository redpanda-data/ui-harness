# Project Rules

## Quick Ref (every turn)

bun tsgo biome vitest | Compiler memoize | fix type (guard, generic) | `@/components/ui/` | `<Button>` always | zustand `create<T>()()` `useShallow` | `@/env` | TanStack Router | connect-query | TDD: fail first | browser: `agent-browser` / `bunx playwright` (CLI) -- never "no browser tools"

## Toolchain

`bun` pkg | `tsgo` typecheck | Biome lint/fmt | `--force-with-lease` | safe rm: node_modules dist .next build .cache .turbo coverage

## Bash Discipline

`find` -> `-maxdepth N` or `| head` | `git log` -> `-n 30` or `--oneline` | `grep -r` -> Grep tool | `cat` >200 line -> Read | `llm-truncate` cap 4KB | `bash-verbose-guard` nudge pre-exec | `rtk-rewrite` auto-prefix git/cargo/test/gh/tsc w/ `rtk` (60-90% cut) -- get: `brew install rtk` -- filter: `.rtk/filters.toml`

## Commits

`type(scope): description` -- feat fix refactor style test docs chore perf ci build revert -- scope need -- lowercase, 5-72 char

## Code Quality

`bun run lint:fix` + `bun run type:check` pre-done | light dep: date-fns lodash-es clsx

## React

- Functional only (Compiler) | `@/components/ui/` | DOMPurify user HTML
- `JSON.parse()` data, `textContent` text, `setHTML` safe HTML
- Fix type: guard, generic, schema -- no `as any`/`as never`/`biome-ignore noExplicitAny`
- `focus-visible:ring-*` not outline:none | Compiler memoize -- no `useMemo`/`useCallback`/`React.memo`
- `aria-label` icon-only `<Button>` | every `<Button>`: `onClick`/`asChild`/`type="submit"`/`disabled`
- `<Link>` nav | direct import (tree-shake) | `{ passive: true }` scroll/touch/wheel
- `React.lazy()` heavy dep | `structuredClone()` deep clone | `.requestSubmit()` form
- `.filter()`/`Array.with()` remove | `Number()`/`parseInt(s,10)` | `Number.isNaN()`
- `<Button>` click thing | function to `setTimeout` | name useEffect: `useEffect(function syncX(){...},[deps])`
- Form mode: `onChange` only | field validate need | err inline via FormMessage
- Hook in `/hooks/`, not route file | route >300 LOC -> `/request-refactor-plan`
- No `window.location` -- router/env | side-effect: `useMutation` not raw fetch
- No `throw new Error()` ConnectRPC -- `ConnectError.from()` | proto enum not magic number
- `useWatch()` not `form.watch()` | spread `...field` RHF | `mutate()` need `onError`
- `ConnectError.from(error)` + `formatToastErrorMessageGRPC()` | `*Mutation` suffix
- No `@redpanda-data/ui` -- registry | no direct `lucide-react` -- `components/icons`
- No inline `staleTime`/`gcTime` -- named const
- Proto form: `useProtoForm` own state -- no parallel `useState<*Config>` / `useState<*Auth>` (hook)
- `form.setValue(name, v, { shouldDirty: true, shouldValidate: true })` -- option need unless silence on purpose (hook)
- Multi-field form: render `<FormErrorSummary>` / `role="alert"` / `aria-live` (hook) -- submit err screen-reader visible
- Proto label/desc: hydrate from `getFieldDescription(schema, field)` via `ProtoAnnotations` registry -- no hardcode string in JSX when proto annotation exist

## Tailwind

Utility class | design token `var(--destructive)` `bg-primary` | fix specificity at source | variant prop registry component | `100dvh` | `width:100%` | keep user-scalable (WCAG 1.4.4)

## Env Vars

`@/env` (t3-env+zod) | declare in `src/env.ts` | `process.env` OK build/test config only

## A11y

`<img>` need `alt` | click div/span: `role` `tabIndex` kbd handler | combobox: `aria-expanded`+`aria-controls` | dialog: `aria-label`/`aria-labelledby` | tablist need tab child | disabled `<Button>`: wrap `<Tooltip>` why | `aria-invalid` need `aria-describedby` | no nested interactive

## Zustand

`create<T>()()` | `useShallow` multi-select | `persist` local storage

## State & Data

zustand client, TanStack Query server | connect-query for ConnectRPC (except `useTransport`/`callUnaryMethod`) | Protobuf v2: `create(Schema,{...})` schema-first | `timestampFromDate()` Timestamp | `anyPack()` Any+`typeRegistry` | `handleSubmit(onSubmit, onError)` | FieldMask: `Object.keys(dirtyFields)` never hardcode | `invalidateQueries` > `refetchQueries` -- always `await` | new file need test -- `/tdd`

## Lifecycle (MANDATORY -- hooks enforce)

Order every task. Hooks block skipped steps.

1. **Understand** -- explore, one question at time, propose
2. **Plan** -- exact path, code, expect output
3. **Implement** -- `/tdd` every file. Fail first -> pass -> refactor
4-6. **`/go`** -- verify -> self-review -> `/simplify` -> `/commit-push-pr` -> monitor CI -> fix -> done

Alias: `/work` = `/development-lifecycle` (full). `/go` = phase 4-6 (ship tail).

### Effort per phase (Opus 4.7)

Default `high`. Implement(TDD) + Plan + Review(sec/arch) = `xhigh`. No `max` -- diminish return + overthink 4.7. Never inject `ultrathink` prompt/hook/skill -- 4.7 silent downgrade xhigh->high.

### Subagent model choice (cost)

Explore -> Sonnet (grep no need Opus). Plan/Review -> Opus xhigh. general-purpose -> Sonnet if plan atomic, Opus else. Haiku 4.5 lookup/boilerplate.

### Monitor (not sleep)

`Bash(run_in_background)` + `Monitor` stream output:
CI: `gh pr checks <n> --watch` | dev server | vitest watcher | container log | build output

## UX Copy

Sentence case | no Latin abbrev (for example, that is, and so on, through) | no ableist word | they/them

## Tests

Fail first -> pass | `userEvent.setup()` + `getByRole` | `await waitFor(()=>expect(...))` async | `.test.ts` unit `.test.tsx` integration `.browser.test.tsx` visual `e2e/*.spec.ts` Playwright | co-locate | `test()` not `it()` | `vi.fn()`/`vi.mock()`/`vi.spyOn()` | `.toBeVisible()` > `.toBeInTheDocument()` | no `waitForTimeout` | no `test.skip` E2E (`test.fixme()` known bug) | `createRouterTransport` ConnectRPC mock | `data-testid` interactive | `test.step()` Playwright
Green != done. Zero warn local AND CI. `DeprecationWarning`, React `act()`, unhandled rejection, `@ts-ignore`, `npm WARN deprecated` = fix at source. Hook: `test-warning-check` (local, Bash PostToolUse) + `ci-warning-audit` (Stop, scan `gh run view --log` on green). Escape: `// allow: test-warning` in test file w/ reason, or `TEST_WARNINGS_ALLOW=1` / `CI_WARNING_AUDIT=0` env.

## Logging

Structured JSON | requestId/traceId every entry | log at decision point | named level per module | never log secret/PII

## Error Handling

Boundary: route+loader -> `errorComponent` (hook) | `React.lazy()` in `<Suspense>` | handle loading+error+empty
Catch: set err state / re-throw / handler -- no silent fallback, no log-only UI | parse err: early return `<ErrorState />`
ConnectError field: `findDetails(BadRequestSchema)` in `onError` -> iterate `fieldViolations` -> `form.setError` per violation -- toast only non-field (hook)
Validate: format not presence | UPPER_SNAKE pattern | exhaustive: `default: never`/`satisfies never`
Async: `onChange` async need `AbortController` | `mutate()` need `onError` (hook) | `Promise.allSettled` partial-fail
Form UX: show ALL err | `aria-invalid`+`aria-describedby` (hook) | disabled submit: `<Tooltip>` why (hook) | URL: `type="url"` | secret: `type="text"` when verify
State: oneof clear prev on switch | auth/config separate from form | FieldMask `paths`: `Object.keys(dirtyFields)` (hook)

## Auto Mode

Deny rule mirror `enforce-toolchain.sh` | test `bunx skills:*` allow rule | admin: `autoMode.environment` whitelist | `claude auto-mode defaults` schema | plan->approve->auto natural fit

## Auto-Generated (skip)

`*.gen.ts`/`*.gen.tsx` | `*_pb.ts`/`*_pb.js` | `*_connectquery.ts` | `@generated`/`DO NOT EDIT` first 5 line