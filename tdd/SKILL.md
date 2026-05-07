---
name: tdd
description: "Test-driven development with red-green-refactor loop. Use when writing tests, creating new features, or fixing bugs. Includes planning phase, tracer bullets, async leak detection, deep module design, and condition-based waiting."
paths:
  - "**/*.test.{ts,tsx}"
  - "**/*.spec.{ts,tsx}"
  - "**/*.integration.{ts,tsx}"
  - "**/*.unit.{ts,tsx}"
---

# Test-Driven Development

## Iron Law

**No prod code without failing test first.** No exceptions.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all impl.** Bulk tests test *imagined* behavior, not *actual*.

**Correct**: Vertical slices -- one test -> one impl -> repeat.

    WRONG:  RED: test1,test2,test3  ->  GREEN: impl1,impl2,impl3
    RIGHT:  RED->GREEN: test1->impl1  ->  RED->GREEN: test2->impl2

## State Machine

Full state diagram: [REFERENCE.md#state-machine](REFERENCE.md#state-machine).

## Workflow

### 0. PLAN -- Coverage gap analysis

- Use project's domain glossary for test/interface names; respect ADRs in the area
- Run `vitest run --coverage.enabled --coverage.reporter=text`
- Find uncovered lines/branches/functions in changed files -> test targets
- Confirm behaviors w/ user (prioritize gaps over covered)
- Find [deep module](deep-modules.md) chance (small interface, deep impl)
- Design interfaces for [testability](interface-design.md); test behaviour through public interface, not impl ([tests.md](tests.md))

### 1. RED -- Failing test (tracer bullet)

- ONE test, ONE behavior, clear name
- Real code, no mocks (unless unavoidable -- see [mocking.md](mocking.md))
- Verify fails for RIGHT reason

### 2. GREEN -- Minimal code to pass

- Only enough to pass | no premature optimization
- Run test | see green

### 3. REFACTOR -- Clean up while green

- Kill duplication | fix naming | deepen modules
- Tests after every change -- stay green
- **Never refactor while RED.** Get GREEN first.
- Flag unit tests >500ms, integration >2s
- Avoid per-keystroke sim (slow, flaky) -> bulk input
- Commit when clean

### Reactive TDD with Monitor

`Monitor: vitest --watch` -- stream pass/fail as edit. Edit->fail->fix->pass->refactor->repeat.

### 4. REPEAT -- Next behavior

RED->GREEN->REFACTOR per behavior. One at a time.

### Per-Cycle Checklist

- [ ] Test describe behavior, not impl
- [ ] Test use public interface only
- [ ] Test survive internal refactor
- [ ] Code minimal for this test
- [ ] No speculative features

## Test Classification

| Suffix | Purpose | DOM? |
|--------|---------|------|
| `.test.ts` | Unit -- pure logic | No |
| `.test.tsx` / `.integration.tsx` | Integration -- render components | Yes |
| `e2e/*.spec.ts` | E2E -- Playwright browser | Browser |

## Visual Regression Tests (Route Files)

New TanStack Router routes need `*.browser.test.tsx` sibling -- only if project use vitest browser mode (existing `*.browser.test.*` files or `@vitest/browser` dep). Skip layout/redirect-only routes. See [REFERENCE.md](REFERENCE.md).

## When Done

- [ ] All pass (`vitest run`)
- [ ] **Zero warnings** -- green run w/ `DeprecationWarning` / React `act()` / unhandled rejection / `@ts-ignore` is NOT done. `test-warning-check` hook surfaces; fix at source. Escape: `// allow: test-warning` w/ reason.
- [ ] No async leaks (`vitest run --detectAsyncLeaks`) -- Stop hook run auto
- [ ] No `setTimeout` hacks -- condition-based wait
- [ ] Coverage gaps closed -- re-run coverage, verify changed files
- [ ] Selector priority: `getByRole` > `getByText` > `getByTestId` > `querySelector`
- [ ] Portal tests: `defaultOpen` for content tests | `waitFor` for close assertions
- [ ] Tests verify behavior, not impl | `expect.soft()` for multi-assertion state tests
- [ ] CI green AND `ci-warning-audit` clean -- `gh run view <id> --log | grep -E 'Warning|Deprecation'` returns nothing

See [REFERENCE.md](REFERENCE.md) for element selectors, portal testing, mock patterns, diagnostics, Vitest config.