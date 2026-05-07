# Test-Driven Development Reference

## Condition-Based Waiting

Replace arbitrary timeouts with condition polling. Flaky tests = timing assumptions.

```ts
// BAD -- arbitrary delay
await new Promise(r => setTimeout(r, 500))
await page.waitForTimeout(1000)

// GOOD -- wait for actual condition
await waitFor(() => expect(element).toBeVisible())
await expect.poll(() => fetchStatus()).toBe('ready')
await page.waitForSelector('[data-testid="loaded"]')

// GOOD -- event-based
await waitForEvent(manager, threadId, 'DONE')
```

Result: 60% -> 100% pass rate, 40% faster.

## Custom Fixtures (test.extend())

Encapsulate reusable setup into declarative fixtures. Tests become assertion-only.

```ts
import { test as base } from 'vitest'

// Define fixture with setup + teardown
const test = base.extend<{ db: TestDatabase }>({
  db: async ({}, use) => {
    const db = await createTestDatabase()
    await use(db)       // test runs here
    await db.cleanup()  // teardown after test
  },
})

// Compose -- fixture depends on another
const test = base.extend<{ db: TestDatabase; user: User }>({
  db: async ({}, use) => { /* ... */ await use(db) },
  user: async ({ db }, use) => {
    const user = await db.createUser({ name: 'test' })
    await use(user)
  },
})

// Tests = pure assertions
test('user has default role', async ({ user }) => {
  expect(user.role).toBe('viewer')
})
```

**Auto-fixtures**: `{ auto: true }` runs every test, no explicit reference:

```ts
const test = base.extend<{ mockApi: void }>({
  mockApi: [async ({}, use) => {
    const server = setupMockServer()
    await use()
    server.close()
  }, { auto: true }],
})
```

Same API as Playwright `test.extend()` -- patterns transfer unit ↔ E2E.

## Advanced Assertions

### Custom Matchers (expect.extend())

Domain-specific assertions = better readability · central validation.

```ts
// vitest.setup.ts
import { expect } from 'vitest'
import { z } from 'zod'

expect.extend({
  toMatchSchema(received, schema: z.ZodSchema) {
    const result = schema.safeParse(received)
    return {
      pass: result.success,
      message: () => result.success
        ? `Expected value not to match schema`
        : `Schema validation failed: ${result.error.message}`,
    }
  },
})

// Usage
test('API response matches schema', () => {
  expect(response).toMatchSchema(UserSchema)
})
```

Type declaration (`vitest.d.ts` or setup file):

```ts
import type { Assertion, AsymmetricMatchersContaining } from 'vitest'

interface CustomMatchers<R = unknown> {
  toMatchSchema(schema: z.ZodSchema): R
}

declare module 'vitest' {
  interface Assertion<T = any> extends CustomMatchers<T> {}
  interface AsymmetricMatchersContaining extends CustomMatchers {}
}
```

### Asymmetric Matchers

Custom matchers from `expect.extend()` work asymmetric -- mix literals with pattern matchers:

```ts
expect(response).toEqual({
  id: expect.any(String),
  data: expect.objectContaining({ status: 'ok' }),
  metadata: expect.toMatchSchema(MetadataSchema),  // custom matcher, asymmetric
})
```

### Custom Equality Testers

Teach Vitest equivalent objects equal (Money · units · dates):

```ts
// vitest.setup.ts
import { expect } from 'vitest'

function measurementTester(a: unknown, b: unknown): boolean | undefined {
  if (a instanceof Measurement && b instanceof Measurement) {
    return a.toBaseUnit() === b.toBaseUnit()
  }
  return undefined  // not our types -- defer to default
}

expect.addEqualityTesters([measurementTester])
```

Register in `setupFiles`. Expensive testers slow all deep equality -- keep fast.

### Retryable Assertions (expect.poll())

Retry callback til pass. Cleaner than `waitFor` for non-Promise async (polling APIs · DOM side effects · event-driven state):

```ts
await expect.poll(() => fetchStatus()).toBe('ready')

// Custom interval and timeout
await expect.poll(() => document.querySelectorAll('.item').length, {
  interval: 100,  // default: 50ms
  timeout: 5000,  // default: 1000ms
}).toBeGreaterThan(3)
```

`expect.poll()` for eventual assertions | `waitFor()` for Promise chains.

### Soft Assertions (expect.soft())

Run all assertions even when one fails. Full picture one pass:

```ts
test('user profile has all required fields', () => {
  expect.soft(profile.name).toBe('Alice')
  expect.soft(profile.email).toContain('@')
  expect.soft(profile.role).toBe('admin')
  // All three report on failure -- not just first
})
```

Still fail test. No short-circuit. Use for complex state needing full debug picture.

## Reactive TDD with Monitor

**Monitor** streams test runner watch mode during implementation. RED->GREEN->REFACTOR = continuous feedback.

```
Monitor: vitest --watch
```

1. Start Monitor on watch mode
2. Write failing test (RED) -- Monitor report failure immediate
3. Write minimal code -- Monitor report pass (GREEN) on save
4. Refactor -- Monitor confirm green after each change

**When**: Phase 3 rapid iteration with many small changes.

## Async Leak Detection with Monitor

```
Monitor: vitest run --detectAsyncLeaks
```

Surface open handles as detected, not buffered til exit.

## Coverage Gap Analysis

```bash
# Text report -- quick overview
vitest run --coverage.enabled --coverage.reporter=text

# JSON report -- parseable
vitest run --coverage.enabled --coverage.reporter=json

# Related files only -- faster, scoped
vitest run --coverage.enabled --coverage.reporter=text --related src/features/auth/
```

### Reading Coverage Output

```
File            | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s
----------------|---------|----------|---------|---------|-------------------
useAuth.ts      |   72.5  |    50.0  |   80.0  |   72.5  | 34-41,67-72
AuthForm.tsx    |   85.0  |    75.0  |  100.0  |   85.0  | 23-28
```

**Uncovered Line #s** = exact targets for new tests.

### Priority Order for Coverage Gaps

1. **Uncovered branches** (if/else · switch · error paths) -- top bug risk
2. **Uncovered functions** -- entire untested behaviors
3. **Uncovered lines in covered functions** -- edge cases

### Don't Chase 100%

Coverage = tool for finding gaps, not goal. Accept lower for:
- Type stubs · barrel exports · re-exports
- Framework glue (route config · provider wrappers)
- Generated code

Target: **80% lines, 70% branches** for feature code. Focus behavior-critical paths.

## Visual Regression Tests (Route Files)

Add `*.browser.test.tsx` for new route files when project uses `@vitest/browser`:

```ts
// routes/oauth-providers/index.browser.test.tsx
import { test, expect } from 'vitest'

test('oauth providers list renders', async ({ page }) => {
  await page.goto('/oauth-providers')
  await expect(page.getByRole('heading', { name: /oauth providers/i })).toBeVisible()
  await expect(page).toMatchSnapshot()
})
```

Detection: existing `*.browser.test.*` files or `@vitest/browser` in package.json.

## Diagnostic Commands

```bash
vitest run --detectAsyncLeaks          # async leaks
vitest run --reporter=verbose --pool=forks  # profile slow tests
grep -rn 'getByRole' --include='*.integration.*' | wc -l  # slow selectors
```

## Vitest Config Optimization

Tune `vitest.config.*` for faster runs. Settings compound.

### pool: 'threads'

Worker threads = less spawn overhead than forks. Import time drop ~30%.

```ts
// vitest.config.mts
export default defineConfig({
  test: {
    pool: 'threads',
  },
})
```

Safe everywhere for unit and integration.

### Multi-Workspace Configuration

Monorepos with different runtimes need separate configs sharing one root:

```ts
// vitest.workspace.ts
export default [
  { extends: './vitest.config.mts', test: { name: 'unit', include: ['src/**/*.test.ts'] } },
  { extends: './vitest.config.mts', test: { name: 'integration', environment: 'happy-dom', include: ['src/**/*.test.tsx'] } },
  { extends: './vitest.edge.mts', test: { name: 'edge', include: ['edge/**/*.test.ts'] } },
]
```

Each workspace get own pool · environment · isolation. Use for multi-runtime monorepos only.

### Concurrent Tests (it.concurrent)

Run independent tests within single file concurrent. Different from `pool:'threads'` (across files).

```ts
describe.concurrent('independent API calls', () => {
  it('fetches users', async ({ expect }) => { /* ... */ })
  it('fetches roles', async ({ expect }) => { /* ... */ })
  it('fetches permissions', async ({ expect }) => { /* ... */ })
})
```

Safety: tests must not share mutable state · each set up own fixtures.

### What NOT to change

| Setting | Why skip |
|---|---|
| `isolate: false` | Incompatible with per-file `vi.mock()` -- passes locally, fails CI |
| `experimental.fsModuleCache` | Experimental -- stale cache issues in CI |
| Sharding | See [CI Pipeline REFERENCE](../setup-ci-pipeline/REFERENCE.md) -- useful for suites >60s |

### Benchmarks (`pool: 'threads'`, 23 unit + 12 integration files)

| Category | Metric | Before | After |
|---|---|---|---|
| Unit | Import time | 3.0s | 2.2s (27% faster) |
| Integration | Duration | 2.59s | 2.04s (21% faster) |
| Integration | Import time | 7.9s | 5.5s (30% faster) |

## Element Selectors -- Priority Order

1. **`getByRole` with `{ name }`** -- always first
2. **`getByText`** -- non-interactive text only
3. **`getByTestId`** -- when role queries fail
4. **`document.querySelector('[data-slot="..."]')`** -- last resort

### Query Type Rules

| Query | When |
|-------|------|
| `getBy` | Element MUST exist. Throws if missing. |
| `queryBy` | ONLY for "not visible" assertions |
| `findBy` | Async elements. Returns Promise. |
| `getAllBy` | Multiple elements expected. |

### Selector Gotchas

- Always include `{ name }` with `getByRole` when many elements share same role
- Password inputs no `textbox` role -> use `document.querySelector('input[data-slot="input"]')`
- Number inputs use `spinbutton` role
- Make helpers for repeated ambiguous queries at `describe` level

```ts
const getTrigger = () => screen.getByRole('button', { name: 'Select option' })
```

### Common Role Mappings

| Element | Role |
|---------|------|
| `<button>` | `button` |
| `<a href>` | `link` |
| `<input type="text">` | `textbox` |
| `<input type="number">` | `spinbutton` |
| `<input type="password">` | (none -- use data-slot) |
| `<select>` / Combobox | `combobox` |
| Dropdown option | `option` |

## Portal Component Testing

Portal components (Dialog · AlertDialog · DropdownMenu · Popover · Sheet · Combobox · MultiSelect) render outside normal DOM hierarchy.

### Required Tests

1. Trigger opens content
2. Content not visible initially (`queryByText` before opening)
3. Action callbacks fire with correct args
4. Close callbacks fire (`onOpenChange(false)`)
5. Close mechanisms: Escape · click outside · cancel button
6. Disabled state -- trigger does nothing

### Key Patterns

**`defaultOpen` for content-only tests.** Skip trigger interaction when testing buttons/callbacks inside portal. Faster, avoid animation timing.

**`waitFor` for ALL close assertions.** Portal content animates out async:

```ts
await waitFor(() => {
  expect(screen.queryByText('Content')).not.toBeInTheDocument()
})
```

**Click-outside -- render sibling button:**

```ts
render(
  <div>
    <Combobox {...props} />
    <button type="button">Outside</button>
  </div>
)
await user.click(screen.getByText('Outside'))
```

**Escape key:** `await user.keyboard('{Escape}')` after opening portal.

**Portal content queryable via `screen`** -- no special container needed.

## Test Mock Patterns

Common browser API mocks for jsdom. Configure in `vitest.setup.ts`, not per-test.

| API | Components | Mock |
|-----|-----------|------|
| `navigator.clipboard` | CopyButton | `writeText`/`readText` as `vi.fn()` |
| `ResizeObserver` | Tags, responsive | No-op observe/unobserve/disconnect |
| `Element.scrollIntoView` | Command (cmdk) | `vi.fn()` stub |
| `window.matchMedia` | Responsive hooks | Returns `matches: false` default |

### Rules

- No re-mock in test files -- global setup applies
- No test actual browser behavior -- mocks = stubs
- ResizeObserver callbacks never fire -- test behavior via props/interaction
- Add new mocks to `vitest.setup.ts` only

### Missing Mock Error Guide

| Error | Missing Mock |
|-------|------------|
| `TypeError: navigator.clipboard is not defined` | Clipboard API |
| `ReferenceError: ResizeObserver is not defined` | ResizeObserver |
| `TypeError: element.scrollIntoView is not a function` | scrollIntoView |
| `TypeError: window.matchMedia is not a function` | matchMedia |

### matchMedia Per-Test Override

```ts
vi.mocked(window.matchMedia).mockImplementation((query) => ({
  matches: query === '(max-width: 768px)',
  media: query,
  onchange: null,
  addListener: vi.fn(),
  removeListener: vi.fn(),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
  dispatchEvent: vi.fn(),
}))
```

## Framework Detection

| Runner | Detect | Related tests |
|--------|--------|---------------|
| Vitest | `node_modules/.bin/vitest` | `vitest run --related <files>` |

## Unhappy Path Testing Checklist

Every form · validator · async op need unhappy path tests. LLMs default happy path -- counteract.

### Validation Exhaustiveness

Feed **every** constraint type through validation/humanization layer. Assert none leak raw messages.

```ts
test('humanizes all proto constraint types', () => {
  const constraints = [
    { type: 'REQUIRED', raw: 'field is required' },
    { type: 'MIN_LENGTH', raw: 'value length must be at least 3' },
    { type: 'MAX_LENGTH', raw: 'value length must be at most 255' },
    { type: 'PATTERN', raw: 'value must match pattern ^[A-Z_]+$' },
    { type: 'GT', raw: 'value must be greater than 0' },
    { type: 'LT', raw: 'value must be less than 100' },
    { type: 'MAX_ITEMS', raw: 'repeated field must have at most 10 items' },
  ]

  for (const { type, raw } of constraints) {
    const result = humanizeValidationError(raw)
    expect(result, `unhandled constraint: ${type}`).not.toBe(raw)
  }
})
```

### Catch Block Behavior

Test errors surface to user, never swallowed:

```ts
test('shows error toast on JSON parse failure', async () => {
  const user = userEvent.setup()
  render(<JsonEditor onChange={vi.fn()} />)

  await user.clear(screen.getByRole('textbox'))
  await fireEvent.change(screen.getByRole('textbox'), {
    target: { value: '{invalid json' },
  })

  await waitFor(() => {
    expect(screen.getByText(/invalid json/i)).toBeVisible()
  })
})
```

### Error Guard / Early Return

When deserialization fails, form must NOT render:

```ts
test('renders error state instead of form on deserialize failure', () => {
  render(<EditForm data={corruptedProtoBytes} />)

  expect(screen.getByRole('alert')).toBeVisible()
  expect(screen.queryByRole('form')).not.toBeInTheDocument()
})
```

### Oneof / Discriminated Union Switching

Previous branch values must clear:

```ts
test('clears OAuth fields when switching to SAML', async () => {
  const user = userEvent.setup()
  render(<AuthConfigForm />)

  await fillOAuthFields(user)

  await user.click(screen.getByRole('combobox', { name: /auth type/i }))
  await user.click(screen.getByRole('option', { name: /saml/i }))

  const formValues = getFormValues()
  expect(formValues.oauth).toBeUndefined()
})
```

### Async Validation Race Condition

Rapid edits must not show stale validation:

```ts
test('cancels stale async validation on rapid input', async () => {
  const user = userEvent.setup()
  const validateFn = vi.fn()
    .mockResolvedValueOnce({ valid: false, error: 'stale' }) // slow first
    .mockResolvedValueOnce({ valid: true })                   // fast second

  render(<ValidatedInput validate={validateFn} />)

  await fireEvent.change(input, { target: { value: 'a' } })
  await fireEvent.change(input, { target: { value: 'ab' } })

  await waitFor(() => {
    expect(screen.queryByText('stale')).not.toBeInTheDocument()
  })
})
```

### All Errors Visible

Show all errors, not just first:

```ts
test('displays all validation errors not just first', async () => {
  const user = userEvent.setup()
  render(<ConfigForm />)

  await user.click(screen.getByRole('button', { name: /save/i }))

  await waitFor(() => {
    expect(screen.getByText(/name is required/i)).toBeVisible()
    expect(screen.getByText(/url must be valid/i)).toBeVisible()
  })
})
```

### Error Path Priority

Cover these paths in order:
1. **Invalid input** -- empty · wrong format · too long/short · special chars
2. **Network failure** -- fetch rejects · timeout · 4xx/5xx
3. **Parse failure** -- malformed JSON · corrupt proto · missing required fields
4. **State transition errors** -- switch types clear old data · concurrent edits
5. **Partial failure** -- batch where some items fail (Promise.allSettled)

## Common Agent Excuses

| Excuse | Counter |
|---|---|
| "I'll add test later" | No. Failing test FIRST (RED). |
| "Too simple to test" | Simple things become complex. Test now. |
| "Test duplicates implementation" | Test behavior, not implementation. |
| "Can't test without mocking everything" | Redesign for testability. Heavy mocking = design problem. |
| "Tests slow development" | Tests catch bugs that slow dev 10x more. |
| "I'll verify manually" | Manual no prevent regressions. |