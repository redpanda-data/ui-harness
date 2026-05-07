# TanStack Code Mode Evaluation

**Date:** 2026-04-12
**Status:** Declined -- layer mismatch; revisit if we build AI-powered product features
**Repository:** https://github.com/TanStack/ai

## What is TanStack Code Mode?

An SDK for building AI-powered applications where LLMs write TypeScript programs that execute in sandboxed isolates instead of making sequential tool calls. The LLM composes tools with loops, conditionals, and `Promise.all()` in a single program, executes it in a V8/QuickJS/Cloudflare Worker sandbox, and returns a structured result. Token savings come from reducing tool-call round-trips between an application's LLM and its backend.

Packages: `@tanstack/ai-code-mode`, `@tanstack/ai-code-mode-skills`, isolate drivers (node, quickjs, cloudflare). Model-agnostic (OpenAI, Anthropic, Gemini, Groq, xAI, Ollama).

## Key Strengths

- Eliminates multi-step tool-call round-trips by batching logic into a single TypeScript program
- Enables parallel execution (`Promise.all`), arithmetic correctness, and batch operations inside one LLM turn
- Sandboxed execution via V8 isolates, QuickJS, or Cloudflare Workers -- safe by default
- Typed skill libraries that the LLM composes programmatically (type stubs generated per tool)
- Model-agnostic with adapter system for all major providers

## Why We Declined

### Layer mismatch

Code Mode and our hooks ecosystem operate at fundamentally different layers of the stack:

| Dimension | TanStack Code Mode | Skills/hooks ecosystem |
|---|---|---|
| **Purpose** | SDK for AI-powered product features | Optimization layer for Claude Code (dev tool) |
| **Who calls the LLM** | Your application's backend | Anthropic's Claude Code CLI |
| **Where it runs** | Sandboxed isolate in your app | Shell hooks on developer machine |
| **What it optimizes** | Tool-call round-trips in your AI product | Context injection, output size, enforcement in Claude Code sessions |
| **Integration point** | Your app's LLM orchestration layer | Claude Code lifecycle events (SessionStart, PreToolUse, PostToolUse, Stop) |
| **"Skills" meaning** | Typed TypeScript libraries the LLM composes | Workflow guidance documents (SKILL.md) + shell hook scripts |
| **Control over LLM** | Full -- you own the orchestration | None -- Anthropic owns Claude Code's architecture |

We cannot inject Code Mode into Claude Code's tool-calling mechanism. Claude Code's architecture -- how it decides to call tools, how it sequences operations, how it manages context -- is Anthropic's. Our hooks intercept lifecycle events around that architecture; they do not replace it.

### Token savings: different targets, no overlap

| Optimization | Layer | Mechanism | Savings |
|---|---|---|---|
| Code Mode batch execution | Your app's LLM | Single program replaces N tool-call round-trips | Unquantified |
| `user-prompt-context.sh` injection | Claude Code | Compresses 300+ line CLAUDE.md into ~10-token "Rules:" line | 3,000-8,000 tokens/session |
| `llm-truncate.sh` output capping | Claude Code | Caps >200-line Bash output | ~80% on large outputs |
| `llm-test-flags.sh` rewriting | Claude Code | Strips `--verbose`, suggests `--bail=1` | 60-80% on test output |
| 13 PostToolUse enforcement hooks | Claude Code | Shell script pattern checks, zero LLM tokens | 100% reliable, 0 tokens |

Code Mode saves tokens in **your application's LLM calls**. Our hooks save tokens in **Claude Code sessions**. Installing `@tanstack/ai-code-mode` would not reduce token usage in Claude Code.

### No gap in the current ecosystem

The "write code instead of tool calls" pattern is conceptually interesting, but Claude Code already does this -- it writes code and executes it via Bash. Our hooks solve the discovery and enforcement problem differently: inject context upfront (UserPromptSubmit), validate outputs in real time (PostToolUse), and gate completion (Stop). This is zero-token enforcement via shell scripts, not LLM-generated programs.

### Not a candidate for a setup skill

A `setup-tanstack-ai` skill would only make sense if the team builds AI-powered features in their product using Code Mode. Current TanStack integration is limited to Router (`setup-tanstack-router`) and Query (via `setup-connect-query`) -- UI framework libraries in a different domain from Code Mode's AI orchestration SDK.

## When to Revisit

- We build **AI-powered product features** that use LLM tool-calling (chatbots, agents, AI assistants in our app) -- Code Mode becomes a candidate for orchestrating those features
- Claude Code exposes a **plugin API** that allows injecting custom tool-calling strategies -- Code Mode's "write a program" pattern could replace sequential tool calls
- Code Mode ships a **Claude Code integration** (official skill or MCP server that optimizes Claude Code's own tool usage)
- We adopt **AG-UI protocol** for streaming agent events in our product -- Code Mode's event handling becomes relevant
