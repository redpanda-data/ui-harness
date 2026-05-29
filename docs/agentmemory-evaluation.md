# agentmemory Evaluation

**Date:** 2026-05-20
**Status:** Delayed -- useful, but opt-in only until privacy, latency, and hook-overlap risks are proven acceptable
**Repository:** https://github.com/rohitg00/agentmemory

## What is agentmemory?

Persistent memory for AI coding agents. It captures session/tool activity through hooks, stores searchable observations, exposes MCP tools, and can inject relevant prior context into later sessions. It supports Claude Code, Codex CLI, Cursor, Gemini CLI, OpenCode, and generic MCP clients.

As of evaluation, the repo is active, Apache-2.0 licensed, and ships a Codex plugin with MCP plus lifecycle hooks.

## Why It Looked Interesting

- **Cross-session memory** -- our harness is strong at real-time enforcement, but mostly session-scoped for learning.
- **Session replay** -- useful for debugging agent failures and understanding long-session drift.
- **Searchable observations** -- could help recall previous architectural decisions, recurring hook violations, and rejected approaches.
- **Codex support** -- upstream plugin registers Codex hooks plus MCP tools.
- **Local-first path** -- server/viewer run locally, with no required external database.

## Why We Delayed Adoption

### Hook overlap

Our harness already owns SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, Stop, and other lifecycle events. Installing agentmemory by default would add another broad hook layer that captures tool inputs/outputs. That risks:

- extra latency on every turn
- duplicated context injection
- noisy interaction with our deterministic checkers
- harder debugging when a session behaves oddly

### Privacy and consent

agentmemory stores prompts, tool inputs, and tool outputs. It includes secret redaction, but raw coding sessions can still contain sensitive project context. This should be explicit opt-in, not bundled default.

### Dependency maturity

The project currently depends on a pinned `iii-engine` version because newer engine architecture changed enough to break recall. That is acceptable for experimentation, but too much operational surface for default harness install.

### Benchmark caveat

The retrieval benchmarks look promising, but some competitor comparisons use different datasets. We should run our own harness-specific eval before depending on the numbers.

## Preferred Future Shape

Do **not** install agentmemory automatically.

If we revisit, prefer a narrow adapter:

1. Detect `AGENTMEMORY_URL`.
2. On Stop or SessionEnd, write only high-value summaries:
   - domain-model decisions
   - ADR pointers
   - recurring hook violations
   - PR feedback themes
   - test failures fixed
   - rejected approaches to avoid suggesting again
3. Avoid raw PostToolUse firehose capture by default.
4. Provide `/setup-agentmemory` as an optional skill/doc, not part of the core frontend-skills plugin.

## Ideas Worth Borrowing

- Session replay for harness/hook events
- Searchable violation history
- Memory governance/delete affordances
- Cross-session pattern detection
- Benchmark suite for memory usefulness
- Stronger privacy-filter tests

## When to Revisit

- We have a harness-specific benchmark showing fewer repeated mistakes or lower context cost
- agentmemory stabilizes its runtime dependency story
- We design explicit consent and redaction rules for captured coding sessions
- We need cross-agent memory for long multi-session work
- We can integrate via high-value summary writes instead of broad tool capture
