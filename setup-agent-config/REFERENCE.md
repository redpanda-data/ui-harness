# LLM Optimization Reference

## llm-env.sh (SessionStart)

> Script: [`scripts/llm-env.sh`](scripts/llm-env.sh)

## user-prompt-context.sh (UserPromptSubmit)

> Script: [`../shared/user-prompt-context.sh`](../shared/user-prompt-context.sh)

Inject project state into every prompt as `additionalContext` · Claude know state, skip waste tool calls.

### Context Levels

Set `PROMPT_CONTEXT_LEVEL` in SessionStart:

```bash
echo "export PROMPT_CONTEXT_LEVEL=standard" >> "$CLAUDE_ENV_FILE"
```

| Level | Injected | Latency | Tokens |
|-------|----------|---------|--------|
| `minimal` | Git branch, dirty state, last commit, ahead/behind | ~80ms | ~50 |
| `standard` (default) | Minimal + scripts + violations + condensed rules + config | ~120ms | ~200 |
| `full` | Standard + tsconfig paths + UI inventory + route tree + proto version + last stop outcome | ~170ms | ~350 |

### Rules Line

Most valuable injection · compress 300+ lines PostToolUse enforcement to one line Claude apply *before* write code:

```
Rules: bun biome vitest | no-memo(compiler) no-as-any no-ts-ignore no-style={{}} no-useEffect | UI:@/components/ui/ | no-raw-HTML(<button>-><Button>) | zustand:create<T>()() useShallow | env:@/env(no process.env) | TanStack-Router(no react-router-dom) | connect-query(no raw useQuery)
```

Instead of write->block->fix (3 tool calls, ~1500 tokens), Claude write correct first try (1 call). Est savings: **3000-8000 tokens/session**.

### Full Level -- What It Adds

```
Paths: @/*=src/* @/ui/*=src/components/ui/*
UI: button,input,select,dialog,table,label,textarea,badge,card,alert
Routes: index.tsx,users/$userId.tsx,settings.tsx
Proto: v2
Last stop: typecheck PASS, tests PASS
```

Prevent 2-3 Glob/Read calls Claude make discovering import paths, components, route params.

### Codex Compatibility

Codex lack `UserPromptSubmit`. Approximate via:
- **SessionStart**: one-time context snapshot (stale but available)
- **AGENTS.md**: static rules + scripts baked at generation time
- **Stop -> `.codex/session-state.md`**: violations + git state written per-turn

See `codex-compat` REFERENCE.md for approximation strategy.

## llm-test-flags.sh (PreToolUse on Bash)

> Script: [`scripts/llm-test-flags.sh`](scripts/llm-test-flags.sh)

### Hard enforcement (`updatedInput` rewrite)

| Action | Runner | Why |
|--------|--------|-----|
| Strip `--verbose` | Vitest, Jest | Waste tokens -- agent reporters show only failures |

### Soft suggestions (`additionalContext`)

Suggest not force · appear only when flag absent:

| Flag | Runner | Why |
|------|--------|-----|
| `--pool=forks` | Vitest | Own process per file -- OS clean zombies if vitest crash |
| `--bail=1` | Vitest | Fail fast -- skip waste tokens on cascade failures |
| `--teardownTimeout=5000` | Vitest | Kill hang teardown after 5s |
| `--reporter=github` | Vitest (CI) | GitHub Actions annotations inline in PR diffs |
| `--bail` | Jest | Fail fast |
| `--forceExit` | Jest | Force exit -- prevent hang from open handles |

## llm-truncate.sh (PostToolUse on Bash)

> Script: [`scripts/llm-truncate.sh`](scripts/llm-truncate.sh)

## NODE_OPTIONS

`NODE_OPTIONS=--max-old-space-size=8192` set in SessionStart (`session-env.sh`) · 8GB heap prevent OOM on:
- Large test suites | TypeScript compilation (`tsgo`/`tsc`) | Bundler builds | Protobuf codegen

## Vitest Config Optimizations

Hook handle CLI flags · these handle config-level tune.

### Dependency optimization (faster startup)

```ts
export default defineConfig({
  test: {
    deps: {
      optimizer: {
        web: {
          // Pre-bundle heavy deps so vitest doesn't re-transform per test file
          include: ['@bufbuild/protobuf', '@connectrpc/connect', 'zod'],
        },
      },
    },
    server: {
      deps: {
        // Inline ESM-only packages causing resolution issues
        inline: ['@bufbuild/protobuf'],
      },
    },
  },
})
```

### Pool configuration (anti-zombie)

```ts
export default defineConfig({
  test: {
    pool: 'forks',
    poolOptions: {
      forks: {
        maxForks: 4,
        minForks: 1,
      },
    },
    testTimeout: 10000,
    teardownTimeout: 5000,
  },
})
```

### Hanging process detection

Debug zombie issues:

```ts
export default defineConfig({
  test: {
    reporters: process.env.CI
      ? ['github', 'hanging-process']
      : ['default', 'hanging-process'],
  },
})
```

`hanging-process` reporter log which async ops prevent exit · remove once resolved -- add overhead.

## Token Savings Breakdown

| Optimization | Mechanism | Savings |
|-------------|-----------|---------|
| AI_AGENT=1 | Vitest agent reporter: failures only | ~60-80% test output |
| CLAUDECODE=1 | Bun test: hide passing tests | ~60-80% test output |
| Strip --verbose | Prevent verbose mode (`updatedInput` rewrite) | variable |
| --bail=1 | Stop after first failure | ~1,000-50,000 tokens |
| Truncate >200 lines | Cap `bun install`, stack traces, etc. | ~80% large outputs |
| --pool=forks | Reliability (zombie prevention), not savings | 0 |

## Environment Variable Reference

| Var | Vitest | Bun | Rstest |
|-----|--------|-----|--------|
| `AI_AGENT=1` | Agent reporter (failures only) | No effect | Default to md reporter |
| `CLAUDECODE=1` | No effect | Failures + summary only | No effect |
| `NODE_OPTIONS=--max-old-space-size=8192` | 8GB heap for workers | 8GB heap | N/A (Rust) |