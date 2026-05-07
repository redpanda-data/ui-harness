# Accessibility Setup

## Steps

### 1. Install Playwright AXE

```bash
bun add -D @axe-core/playwright --yarn
```

### 2. Create hook script

Copy [`scripts/accessibility-check.sh`](scripts/accessibility-check.sh) and [`scripts/_hook-lib.sh`](scripts/_hook-lib.sh) into `.claude/hooks/`. Make executable.

### 3. Configure hook in `.claude/settings.json`

Add to hooks config: **PostToolUse** (matcher: `Edit|Write`): `.claude/hooks/accessibility-check.sh`

### 4. Create accessibility test helper

Write test fixture into test utilities:

```typescript
// tests/helpers/a11y.ts
import AxeBuilder from '@axe-core/playwright';
import type { Page, TestInfo } from '@playwright/test';

export interface A11yOptions {
  /** CSS selectors to include in scan */
  include?: string[];
  /** CSS selectors to exclude from scan */
  exclude?: string[];
  /** Specific rules to disable */
  disableRules?: string[];
  /** WCAG tags to check (defaults to WCAG 2.1 AA) */
  tags?: string[];
}

export async function checkA11y(
  page: Page,
  testInfo: TestInfo,
  options: A11yOptions = {},
) {
  const {
    include,
    exclude,
    disableRules,
    tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'],
  } = options;

  let builder = new AxeBuilder({ page }).withTags(tags);

  if (include) {
    for (const selector of include) {
      builder = builder.include(selector);
    }
  }

  if (exclude) {
    for (const selector of exclude) {
      builder = builder.exclude(selector);
    }
  }

  if (disableRules) {
    builder = builder.disableRules(disableRules);
  }

  const results = await builder.analyze();

  // Attach full results for debugging
  await testInfo.attach('accessibility-scan-results', {
    body: JSON.stringify(results, null, 2),
    contentType: 'application/json',
  });

  return results;
}
```

```typescript
import { test, expect } from '@playwright/test';
import { checkA11y } from './helpers/a11y';

test.describe('Accessibility', () => {
  test('homepage passes WCAG 2.1 AA', async ({ page }, testInfo) => {
    await page.goto('/');
    const results = await checkA11y(page, testInfo);
    expect(results.violations).toEqual([]);
  });

  test('navigation menu passes after opening', async ({ page }, testInfo) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'Menu' }).click();
    await page.locator('#nav-flyout').waitFor();

    const results = await checkA11y(page, testInfo, {
      include: ['#nav-flyout'],
    });
    expect(results.violations).toEqual([]);
  });

  test('form passes with known issue excluded', async ({ page }, testInfo) => {
    await page.goto('/signup');
    const results = await checkA11y(page, testInfo, {
      exclude: ['#third-party-captcha'],
      disableRules: ['color-contrast'], // vendor widget
    });
    expect(results.violations).toEqual([]);
  });

  test('component scan -- combobox', async ({ page }, testInfo) => {
    await page.goto('/components/combobox');
    const results = await checkA11y(page, testInfo, {
      include: ['[role="combobox"]', '[role="listbox"]'],
    });
    expect(results.violations).toEqual([]);
  });
});
```

### 5. Verify

- [ ] Hook blocks `<div onClick>` without `role` + `tabIndex` + keyboard handler
- [ ] Hook blocks `<img>` without `alt`
- [ ] Hook blocks `role="combobox"` without `aria-expanded`
- [ ] Hook skips non-TSX/JSX files
- [ ] `@axe-core/playwright` installed
- [ ] A11y test helper runs against sample page

### 6. Commit

Stage all files, commit: `Add accessibility enforcement hook + Playwright AXE setup`