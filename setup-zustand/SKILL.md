---
name: setup-zustand
description: Enforce zustand best practices via PostToolUse hooks -- double-parens create, useShallow selectors, persist middleware. Use when setting up zustand enforcement or preventing re-render issues.
paths:
  - "**/*store*.ts"
  - "**/*store*.tsx"
---

# Zustand Enforcement

## What This Catches

- **Ban single-parens `create<T>()`** -- must be `create<T>()()` for middleware type inference
- **Ban inline object selectors** -- `(s) => ({ a: s.a })` cause infinite re-renders, use `useShallow`
- **Ban localStorage/sessionStorage in store files** -- use zustand `persist` middleware

## Stack Decisions

- **Zustand client state only**: theme, sidebar, selected tab, draft form data. Server data -> TanStack Query / Connect Query.
- **`useShallow` required** for multi-value selectors (hook enforce).
- **Callback form required** for `set()` (hook enforce).

Initial setup (install, config, verify): see [SETUP.md](SETUP.md).