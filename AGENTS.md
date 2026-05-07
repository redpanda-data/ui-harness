# Project Rules

## Quick Reference

Rules: bun tsgo biome vitest | React Compiler handles memoization | fix types properly (type guards, generics) | UI from @/components/ui/ | <Button> for all buttons | zustand:create<T>()() useShallow | env from @/env | TanStack Router for routing | connect-query for data fetching | TDD: failing test first, always

## Toolchain

bun (pkg mgr) | tsgo (type check) | Biome (lint/format) | --force-with-lease for force pushes
Safe rm -rf: node_modules, dist, .next, build, .cache, .turbo, coverage

## Commits

`type(scope): description` -- feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert. Scope required. Lowercase, 5-72 chars.

## Code Quality

Run `bun run lint:fix` + `bun run type:check` before finish. Prefer: date-fns>moment, lodash-es>lodash, clsx>classnames.

## React

- Functional components only (React Compiler require)
- `@/components/ui/` for all form/interactive UI
- DOMPurify for user HTML. JSON.parse() for data, textContent for text, setHTML for safe HTML
- Type guards/generics/schema validation -- no `as any`, no `@ts-ignore`
- `focus-visible:ring-*` not outline. React Compiler handle memo -- remove useMemo/useCallback/React.memo
- `aria-label` on icon buttons. `<Button>` need: onClick|asChild|type="submit"|disabled
- `<Link>` for navigation. Direct source imports (tree-shaking). `{ passive: true }` on scroll/touch/wheel
- `React.lazy()` for heavy deps. `structuredClone()` for cloning. `.requestSubmit()` for forms
- `Number()` or `parseInt(s,10)`. `Number.isNaN()`. Named useEffect callbacks.

## Tailwind

Utility classes. Design tokens (`bg-primary`). Fix specificity at source. variant prop on registry components. `100dvh` for viewport. `width:100%` for containers. Keep user-scalable enabled.

## Env

`import { env } from "@/env"` (t3-env+zod). All vars in `src/env.ts`. Exception: `process.env` in build/test configs.

## Accessibility

`<img>` need alt. Clickable div/span need role+tabIndex+keyboard handler. combobox->aria-expanded+aria-controls. dialog->aria-label/labelledby. tablist->child role="tab".

## Zustand

`create<T>()()` double-parens. `useShallow` for multi-value selectors. `persist` for localStorage.

## State & Data

zustand=client, TanStack Query=server. connect-query for ConnectRPC (exception: useTransport/callUnaryMethod). Proto v2: `create(Schema,{})`, `timestampFromDate()`, `anyPack()` with typeRegistry. `handleSubmit(onSubmit, onError)`.

## Lifecycle

1. Understand -> 2. Plan -> 2b. `/domain-model` (DDD-light grill + CONTEXT.md/ADR updates) -> 3. TDD (RED->GREEN->REFACTOR) -> 4-6. `/go` (verify -> self-review -> `/simplify` -> `/commit-push-pr` -> monitor CI -> fix -> done). Hard bug? `/diagnose` (feedback-loop-first 6-phase). Bug to ticket? `/triage` (GH or Jira).

Aliases: `/work` = `/development-lifecycle` (full). `/go` = phases 4-6 (ship tail).

Effort: high (Understand) -> xhigh (Plan) -> xhigh (TDD) -> high (Simplify) -> high (Verify) -> xhigh (Review). No `max` on Opus 4.7 (diminishing returns + overthinking).

Subagent model: Explore -> Sonnet (codebase greps don't need Opus). Plan/Review -> Opus xhigh. general-purpose -> Sonnet if plan is atomic, Opus otherwise.

## UX Copy

Sentence case. No Latin abbreviations (for example, that is, and so on, through). No ableist language. Gender-neutral.

## Tests

Failing test FIRST. `userEvent.setup()` + `getByRole`. `waitFor()` for async. .test.ts=unit, .test.tsx=integration, e2e/*.spec.ts=Playwright. Co-locate with source.

## Resilience

Route data fetching->errorComponent. React.lazy()->`<Suspense fallback>`. Query hooks->loading/error/empty states. Async handlers->error handling.

### Unhappy Paths (enforced by hook)

- **Catch blocks**: set error state, re-throw, or call error handler -- never swallow silent
- **Error + form**: early return with error UI when deserialization/parse fail -- don't render form below broken Alert
- **Validation depth**: check format (URL regex, enum values, UPPER_SNAKE pattern), not just presence/truthiness
- **Exhaustive switch**: `default: never` or `satisfies never` -- new union variants must fail loud
- **Async validation**: onChange + async validator need AbortController or debounce -- no stale race conditions
- **All errors visible**: `errors.map()` not `errors[0]` -- user see every validation failure
- **Oneof/union fields**: clear previous branch values on switch -- ghost data cause silent bugs
- **Form inputs**: URL fields use `type="url"`, secret-ref fields use `type="text"` (user verify format)
- **aria-invalid** on error inputs, not just data-invalid -- screen readers need ARIA

## Auto-Generated (skip)

*.gen.ts/tsx, *_pb.ts/js, *_connectquery.ts, files with @generated/DO NOT EDIT in first 5 lines.