/**
 * LLM-optimized Vitest reporter. In-house, zero deps.
 *
 * Silent-on-pass trailer: `ok N` (~10 bytes).
 * Fail-case: single-line JSON, hard-capped at MAX_FAILURES.
 * Output writes to stdout only. Progress/colors suppressed.
 *
 * Wire in vitest.config.ts:
 *
 *   import LlmReporter from './shared/reporters/vitest-llm-reporter';
 *   export default defineConfig({
 *     test: { reporters: [new LlmReporter()] },
 *   });
 *
 * Tune via env vars:
 *   VITEST_LLM_MAX_FAILURES  (default 20)
 *   VITEST_LLM_STACK_LINES   (default 3)
 *
 * Prior art / further reading:
 *   - vitest-llm-reporter (hansjm10): https://github.com/hansjm10/vitest-llm-reporter
 *   - TOON format: https://github.com/toon-format/toon
 *   - Vitest Reporter interface: https://vitest.dev/advanced/reporters
 */

import type { Reporter, TestModule, TestCase } from 'vitest/node';

type Failure = {
  file: string;
  test: string;
  line?: number;
  msg: string;
  stack?: string;
};

// allow: env-validation -- reporter runs in Node test-runner context, pre-@/env boundary
const env: Record<string, string | undefined> = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process?.env ?? {};
const MAX_FAILURES = Number(env.VITEST_LLM_MAX_FAILURES ?? 20);
const STACK_LINES = Number(env.VITEST_LLM_STACK_LINES ?? 3);

export default class VitestLlmReporter implements Reporter {
  private failures: Failure[] = [];
  private testCount = 0;
  private moduleCount = 0;
  private skipCount = 0;

  onTestModuleCollected(_m: TestModule) {
    this.moduleCount++;
  }

  onTestCaseResult(tc: TestCase) {
    this.testCount++;
    const result = tc.result();
    const state = result?.state;

    if (state === 'skipped') {
      this.skipCount++;
      return;
    }

    if (state !== 'failed') {
      return;
    }

    const error = (result as { errors?: Array<{ message?: string; stack?: string; location?: { line?: number } }> }).errors?.[0];
    this.failures.push({
      file: tc.module.moduleId,
      test: tc.fullName,
      line: error?.location?.line,
      msg: (error?.message ?? 'unknown').split('\n')[0],
      stack: error?.stack?.split('\n').slice(0, STACK_LINES).join(' | '),
    });
  }

  onTestRunEnd() {
    if (this.failures.length === 0) {
      const parts = [`ok ${this.testCount}`];
      if (this.skipCount > 0) parts.push(`skip ${this.skipCount}`);
      if (this.testCount === 0) parts.push('[ZERO-TESTS]');
      process.stdout.write(parts.join(' ') + '\n');
      return;
    }

    const payload = {
      status: 'fail' as const,
      total: this.testCount,
      failed: this.failures.length,
      skipped: this.skipCount,
      modules: this.moduleCount,
      failures: this.failures.slice(0, MAX_FAILURES),
      truncated: this.failures.length > MAX_FAILURES,
    };
    process.stdout.write(JSON.stringify(payload) + '\n');
  }
}
