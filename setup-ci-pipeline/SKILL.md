---
name: setup-ci-pipeline
description: "Configure GitHub Actions CI for React/TypeScript frontend projects. Coverage gates, visual regression, caching, Blacksmith workers, bundle budgets. Use when setting up CI, optimizing pipelines, or adding quality gates to PRs."
---

# Setup CI Pipeline

GitHub Actions tuned for React/TypeScript:

- Quality gate -- lint, type-check, tests in <5 min
- Coverage gates -- enforce thresholds, post diff on PRs
- Visual regression -- Playwright screenshot compare
- Dependency automation -- dependabot minor/patch
- Bundle budget -- alert on size regressions
- Smart bun caching

See [REFERENCE.md](REFERENCE.md) for workflow templates + Blacksmith tuning.

## Steps

1. Write `.github/workflows/quality-gate.yml` from [REFERENCE.md](REFERENCE.md)
2. Write `.github/dependabot.yml` -- auto minor/patch, manual major
3. Add `toHaveScreenshot()` to Playwright tests
4. Add `--coverage --coverage.thresholds.lines=80` to test scripts

## Verify
- [ ] `gh workflow run quality-gate.yml` runs
- [ ] Coverage report on PRs
- [ ] Dependabot make first PR