/**
 * LLM-optimized Playwright reporter. In-house, zero deps.
 *
 * Silent-on-pass trailer: `ok N` (~10 bytes). Includes `skip N` / `flaky N`
 * only when non-zero. Fail-case: single-line JSON capped at MAX_FAILURES.
 * No progress, no colors, no HTML, no traces in stdout.
 *
 * Wire in playwright.config.ts:
 *
 *   export default defineConfig({
 *     reporter: [['./shared/reporters/playwright-llm-reporter.ts']],
 *   });
 *
 * Tune via env vars:
 *   PW_LLM_MAX_FAILURES  (default 15)
 *   PW_LLM_STACK_LINES   (default 3)
 *
 * Prior art / further reading:
 *   - @zenai/playwright-coding-agent-reporter: https://github.com/getzenai/playwright-coding-agent-reporter
 *   - Playwright Reporter API: https://playwright.dev/docs/api/class-reporter
 *   - Playwright Test Agents (official): https://playwright.dev/docs/test-agents
 */

import type { FullResult, Reporter, TestCase, TestResult } from '@playwright/test/reporter';

type Failure = {
  file: string;
  test: string;
  line?: number;
  status: string;
  attempt: number;
  msg: string;
  stack?: string;
};

// allow: env-validation -- reporter runs in Node test-runner context, pre-@/env boundary
const env: Record<string, string | undefined> = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process?.env ?? {};
const MAX_FAILURES = Number(env.PW_LLM_MAX_FAILURES ?? 15);
const STACK_LINES = Number(env.PW_LLM_STACK_LINES ?? 3);

export default class PwLlmReporter implements Reporter {
  private failures: Failure[] = [];
  private passed = 0;
  private skipped = 0;
  private flaky = 0;
  // allow: env-validation -- reporter runs in Node test-runner context
  private cwd = (globalThis as { process?: { cwd?: () => string } }).process?.cwd?.() ?? '';

  onTestEnd(test: TestCase, result: TestResult): void {
    if (result.status === 'passed') {
      if (result.retry > 0) this.flaky++;
      this.passed++;
      return;
    }

    if (result.status === 'skipped') {
      this.skipped++;
      return;
    }

    const error = result.errors[0];
    this.failures.push({
      file: test.location.file.replace(this.cwd + '/', ''),
      test: test.titlePath().slice(1).join(' > '),
      line: test.location.line,
      status: result.status,
      attempt: result.retry,
      msg: (error?.message ?? 'unknown').split('\n')[0],
      stack: error?.stack?.split('\n').slice(0, STACK_LINES).join(' | '),
    });
  }

  onEnd(result: FullResult): void | Promise<void> {
    if (this.failures.length === 0) {
      const parts = [`ok ${this.passed}`];
      if (this.skipped > 0) parts.push(`skip ${this.skipped}`);
      if (this.flaky > 0) parts.push(`flaky ${this.flaky}`);
      if (this.passed === 0 && this.skipped === 0) parts.push('[ZERO-TESTS]');
      if (result.status !== 'passed') parts.push(`status=${result.status}`);
      process.stdout.write(parts.join(' ') + '\n');
      return;
    }

    const payload = {
      status: result.status,
      passed: this.passed,
      failed: this.failures.length,
      skipped: this.skipped,
      flaky: this.flaky,
      failures: this.failures.slice(0, MAX_FAILURES),
      truncated: this.failures.length > MAX_FAILURES,
    };
    process.stdout.write(JSON.stringify(payload) + '\n');
  }

  printsToStdio(): boolean {
    return true;
  }
}
