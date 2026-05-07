# E2E Testing Setup

## Steps

### 1. Install dependencies

```bash
bun add -D @playwright/test @testcontainers/playwright @axe-core/playwright --yarn
bunx playwright install --with-deps chromium
```

### 2. Configure Playwright

Create `playwright.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'github' : 'html',
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: { mode: 'only-on-failure', fullPage: true },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
})
```

### 3. Add package.json scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug"
  }
}
```

### 4. Create test directory structure

```
e2e/
├── fixtures/          # Shared test fixtures and page objects
│   └── base.ts        # Extended test with axe-core
├── helpers/           # Testcontainers setup, utilities
└── *.spec.ts          # Test files
```

### 5. Set up axe-core base fixture

Create `e2e/fixtures/base.ts`:

```ts
import { test as base } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

export const test = base.extend<{ makeAxeBuilder: () => AxeBuilder }>({
  makeAxeBuilder: async ({ page }, use) => {
    await use(() => new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']))
  },
})

export { expect } from '@playwright/test'
```

### 6. Verify & Commit

- [ ] `bunx playwright test --list` show discovered tests
- [ ] axe-core fixture available, `e2e/` dir exists
- Commit: `Add Playwright e2e testing with Testcontainers and axe-core`

## Testcontainers Setup

Spin up real backend services for integration-level e2e:

```ts
import { GenericContainer, Wait } from 'testcontainers'

let container: StartedTestContainer

test.beforeAll(async () => {
  container = await new GenericContainer('redpandadata/redpanda:latest')
    .withExposedPorts(9092, 8082)
    .withWaitStrategy(Wait.forLogMessage('Successfully started Redpanda'))
    .start()

  process.env.BASE_URL = `http://${container.getHost()}:${container.getMappedPort(8082)}`
})

test.afterAll(async () => {
  await container.stop()
})
```

### Docker Compose for multi-service stacks

```ts
import { DockerComposeEnvironment } from 'testcontainers'

let environment: StartedDockerComposeEnvironment

test.beforeAll(async () => {
  environment = await new DockerComposeEnvironment('.', 'docker-compose.test.yml')
    .withWaitStrategy('api', Wait.forHealthCheck())
    .up()
})

test.afterAll(async () => {
  await environment.down()
})
```