# Sandcastle Reference

## Launch Modes

| | `run()` | `interactive()` |
|---|---|---|
| Mode | Headless (`--print`) | Full TUI (stdin/stdout/stderr) |
| Human interaction | None -- stream-JSON parsed | Direct -- human intervene |
| Use case | CI · batch · parallel · overnight | HITL review · pair-review · local dev |
| Sandbox default | Required (`docker()`) | `noSandbox()` (git worktrees) |
| Iterations | `maxIterations` supported | Single session |
| Completion signal | `<promise>COMPLETE</promise>` | Session exit (Ctrl+C or `/exit`) |

## Headless Batch Template (run)

```typescript
// .sandcastle/main.ts
import { run, claudeCode } from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

// Pick tasks from GitHub issues
const issues = JSON.parse(
  execSync('gh issue list --state open --label "ready" --json number,title,body --limit 5').toString()
);

// Run agents in parallel -- each gets own branch + container
const results = await Promise.all(
  issues.map((issue) =>
    run({
      sandbox: docker(),
      agent: claudeCode("claude-opus-4-7"),
      promptFile: ".sandcastle/implement.md",
      promptArgs: {
        ISSUE_NUMBER: String(issue.number),
        ISSUE_TITLE: issue.title,
        ISSUE_BODY: issue.body,
      },
      branch: `agent/fix-${issue.number}`,
      branchStrategy: { type: "merge-to-head" },
      hooks: {
        onSandboxReady: [
          { command: "bun install --frozen-lockfile" },
          { command: "bunx skills@latest add redpanda-data/ui-harness/frontend-starter-kit --agent claude-code -y" },
          { command: "bunx skills@latest add redpanda-data/ui-harness/development-lifecycle --agent claude-code -y" },
        ],
      },
      maxIterations: 3,
    })
  )
);

// Review pass -- dispatch code-reviewer on each branch
for (const result of results) {
  if (result.commits.length > 0) {
    await run({
      sandbox: docker(),
      agent: claudeCode("claude-sonnet-4-6"),
      prompt: `Review the changes on branch ${result.branch}. Run tests, check types, verify quality. Use Monitor to watch CI in the background after pushing. Report APPROVED or NEEDS_CHANGES.`,
      branch: result.branch,
      branchStrategy: { type: "head" },
    });
  }
}
```

## HITL Review Template (interactive)

```typescript
// .sandcastle/review-interactive.ts
import { interactive, claudeCode } from "@ai-hero/sandcastle";
import { noSandbox } from "@ai-hero/sandcastle/sandboxes/no-sandbox";

// Human watches full TUI -- can Ctrl+C if reviewer goes sideways
const { commits, branch } = await interactive({
  agent: claudeCode("claude-sonnet-4-6"),
  promptFile: ".sandcastle/review.md",
  branchStrategy: { type: "merge-to-head" }, // auto-merge back
  // noSandbox() is default -- no Docker needed for local review
});

console.log(`Review complete: ${commits.length} commits on ${branch}`);
```

## Mixed Pipeline: Headless Implement -> Interactive Review

```typescript
// .sandcastle/implement-then-review.ts
import { run, interactive, claudeCode } from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

// Step 1: Headless implementation in Docker
const implResult = await run({
  sandbox: docker(),
  agent: claudeCode("claude-opus-4-7"),
  promptFile: ".sandcastle/implement.md",
  promptArgs: { ISSUE_NUMBER: "42", ISSUE_TITLE: "Add dark mode" },
  branchStrategy: { type: "branch", branch: "agent/dark-mode" },
  hooks: {
    onSandboxReady: [
      { command: "bun install --frozen-lockfile" },
      { command: "bunx skills@latest add redpanda-data/ui-harness/frontend-starter-kit --agent claude-code -y" },
    ],
  },
  maxIterations: 3,
});

// Step 2: Interactive review -- human watches with full TUI
if (implResult.commits.length > 0) {
  await interactive({
    agent: claudeCode("claude-sonnet-4-6"),
    prompt: `Review changes on ${implResult.branch}. Run tests, check types, fix issues.`,
    branchStrategy: { type: "branch", branch: implResult.branch },
  });
}
```

## createSandbox: Multi-Run on Same Container

```typescript
// .sandcastle/multi-run.ts
import { createSandbox, claudeCode } from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

// Single container, multiple runs -- deps persist between runs
await using sandbox = await createSandbox({
  branch: "agent/fix-42",
  sandbox: docker(),
  hooks: { onSandboxReady: [{ command: "bun install" }] },
});

// Run 1: Implement
await sandbox.run({
  agent: claudeCode("claude-opus-4-7"),
  promptFile: ".sandcastle/implement.md",
  maxIterations: 5,
});

// Run 2: Interactive review on same branch/container
await sandbox.interactive({
  agent: claudeCode("claude-sonnet-4-6"),
  prompt: "Review changes and fix issues",
});
// Container auto-cleaned via `await using`
```

## Prompt Templates

### implement.md

```markdown
# Task: {{ISSUE_TITLE}}

Issue: #{{ISSUE_NUMBER}}

## Requirements
{{ISSUE_BODY}}

## Your Environment

**Skills loaded:**
- /development-lifecycle -- phases: understand -> plan -> TDD -> verify -> review
- /tdd -- iron law: failing test FIRST
- /triage -- bug to ticket: explore -> root cause -> TDD fix plan, files via gh or acli
- /diagnose -- feedback-loop-first 6-phase debugging

**Hooks active (fire automatically):**
- react-rules-check (25): raw HTML · as any · ts-ignore · eval · XSS · barrel imports
- accessibility-check (5): img alt · keyboard handlers · ARIA widgets
- tanstack-router-check (9): route patterns · typed hooks
- connect-query-check (11): protobuf v2 · Connect Query
- orchestration-stop: blocks on missing tests, runs related tests
- typecheck-stop: runs tsgo before completion
- biome-autofix: auto-formats on completion

**Agents available:**
- code-reviewer -- fresh-eyes review before final commit
- verifier -- verify UI changes via browser

## Instructions

1. Read issue requirements carefully
2. Follow /development-lifecycle: understand -> plan -> TDD -> verify
3. Hooks enforce patterns -- follow their guidance when they fire
4. Dispatch code-reviewer before final commit
5. Commit: fix(scope): description. Closes #{{ISSUE_NUMBER}}
6. Run bun run quality:gate as final check

When done, emit: <promise>COMPLETE</promise>
```

### review.md

```markdown
# Code Review: {{SOURCE_BRANCH}}

You are code-reviewer agent. Review with fresh eyes -- you have NOT seen implementation.

## Pre-checks (run first)

```bash
bun test --run --related $(git diff --name-only {{SOURCE_BRANCH}}..main)
bun run type:check
bun run lint
```

## Review Checklist

**Spec compliance:**
- [ ] All requirements addressed | No scope creep | Edge cases handled

**React/TS rules (25 hook checks):**
- [ ] No raw HTML (`<button>` -> `<Button>`) | No `as any` · `@ts-ignore` · `@ts-expect-error`
- [ ] No `dangerouslySetInnerHTML` · `eval()` · `.innerHTML`
- [ ] No barrel imports · `import * as`
- [ ] React Compiler: no manual useMemo/useCallback

**Accessibility (5 checks):**
- [ ] `<img>` has `alt` · icon buttons have `aria-label`
- [ ] Clickable divs have keyboard handlers | ARIA widget roles complete

**Testing:**
- [ ] Tests exist for new code (TDD) | Verify behavior, not implementation
- [ ] No setTimeout/waitForTimeout in tests

**Data layer (if applicable):**
- [ ] Connect Query with ConnectRPC | Protobuf v2: `create()` | Timestamp: `timestampFromDate()`

Report: APPROVED or NEEDS_CHANGES with file:line references.

When done, emit: <promise>COMPLETE</promise>
```

## Dogfooding (Running on This Repo)

```typescript
// .sandcastle/dogfood.ts
const issues = JSON.parse(
  execSync('gh issue list --repo redpanda-data/ui-harness --state open --json number,title,body').toString()
);

await Promise.all(
  issues.map((issue) =>
    run({
      sandbox: docker(),
      agent: claudeCode("claude-opus-4-7"),
      promptFile: ".sandcastle/implement.md",
      promptArgs: { ISSUE_NUMBER: String(issue.number), ISSUE_TITLE: issue.title, ISSUE_BODY: issue.body },
      branch: `agent/issue-${issue.number}`,
      branchStrategy: { type: "merge-to-head" },
    })
  )
);
```

## Integration with Our Stack

| Our layer | How Sandcastle uses it |
|---|---|
| development-lifecycle | Each agent follow 6-phase lifecycle -- both `run()` and `interactive()` |
| Hooks (25 total) | Fire inside each session -- same enforcement headless and interactive |
| code-reviewer agent | Headless via `run()` or HITL via `interactive()` with full TUI |
| verifier agent | Verify UI via agent-browser inside container |
| orchestration-stop | Block completion without tests + type check |
| Monitor tool | Agents watch CI · test output · dev servers in background |
| intent-detect | Not used (agents get explicit prompts) |

Hooks/skills launch-method agnostic -- fire on PostToolUse/PreToolUse regardless of `run()` · `interactive()` · `claude` direct.

## When to Use What

| Scenario | Use |
|---|---|
| Single feature, interactive | Claude Code directly |
| Bug fix needing human input | Claude Code directly |
| Local dev -> quick review | `interactive()` + `noSandbox()` |
| Pair-review with human watching | `interactive()` |
| 5+ independent issues | `run()` -- parallelize in Docker |
| Large plan, independent tasks | `run()` -- one agent per task |
| Overnight batch | `run()` -- AFK |
| Headless implement -> human review | Mixed: `run()` then `interactive()` |

## Cross-Model with Sandcastle

Implement Claude, review Codex. Providers: `claudeCode()` · `codex()` · `pi()` · `opencode()`. Mix per stage. All support `run()` and `interactive()` via `buildPrintCommand` and `buildInteractiveArgs`.

## Prompt Caching Tips

Claude Code [prompt caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) reuse computation -- cached tokens cost 10% of uncached.

| Pattern | Why it works | What breaks it |
|---|---|---|
| `promptFile` with `promptArgs` | Static prefix stay identical -> cache hit | Dynamic prompt strings per-issue |
| Separate `run()` per stage | Each stage own session+cache | Switching model inside single `run()` |
| Same `onSandboxReady` hooks | Tool defs stay identical -- shared prefix | Conditional skill installs per issue |
| `maxIterations: 3` | Prefix preserved between iterations | N/A |

**Key rules:**
1. **Static first, dynamic last** -- caching prefix-matched. Keep system prompt · tools · skills stable. Issue context in `promptArgs` (end).
2. **One model per `run()`** -- switch = full cache rebuild.
3. **No tool change between iterations** -- `onSandboxReady` run once. Conditional install = different prefix = zero cross-agent cache reuse.