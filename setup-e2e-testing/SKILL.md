---
name: setup-e2e-testing
description: Set up Playwright + Testcontainers + axe-core for e2e and accessibility testing. Includes patterns for forms, tables, workflows. Use when setting up e2e tests or writing Playwright tests.
paths:
  - "e2e/**/*.spec.ts"
  - "playwright.config.ts"
---

# E2E Testing

## Conventions

- `e2e/*.spec.ts` -- all e2e tests use `.spec.ts`
- Name by feature: `login.spec.ts`, `create-topic.spec.ts`
- Selectors: `getByRole` > `getByLabel` > `getByText` > `getByTestId` > CSS
- Test IDs: `{feature}-{element}`, `{feature}-{element}-{index}`, `{feature}-{state}`

## Accessibility -- axe on every page

```ts
import { test, expect } from '../fixtures/base'
test('page is accessible', async ({ page, makeAxeBuilder }) => {
  await page.goto('/topics/create')
  const results = await makeAxeBuilder().analyze()
  expect(results.violations).toEqual([])
})
```

## Monitor for E2E
`Monitor: bun run test:e2e` -- stream results, react fail before suite finish.

## Agent-Browser vs Playwright

| Task | Tool |
|------|------|
| Test suites | Playwright via `Monitor: bun run test:e2e` |
| Generate selectors | `agent-browser snapshot` (a11y tree) |
| Visual smoke test | `agent-browser screenshot --annotate` |
| Interactive debug | Playwright UI mode |
| CI | Playwright |
| AI page inspection | agent-browser |

Setup (install, config, fixtures, Testcontainers): see [SETUP.md](SETUP.md).