# CocoIndex Code Evaluation

**Date:** 2026-04-12
**Status:** Declined -- revisit at v1.0+ or for large monorepo scenarios
**Repository:** https://github.com/cocoindex-io/cocoindex-code

## What is CocoIndex Code?

A lightweight semantic code search CLI built on tree-sitter AST parsing and vector embeddings. Finds conceptually related code via natural language queries rather than regex/keyword matching. Designed to integrate with AI coding agents, claiming 70% token reduction for context gathering.

- **Language:** Python
- **License:** Apache 2.0
- **Stars:** 1.3K (as of 2026-04-12)
- **Maturity:** Alpha (`v1.0.0a24+`)
- **Embedding:** Local SentenceTransformers (all-MiniLM-L6-v2) by default, 100+ cloud providers via LiteLLM
- **Integration:** Claude Code skill, MCP server, or raw CLI

## Key Strengths

- **Semantic search** -- finds conceptually related code even without keyword matches
- **AST-aware chunking** -- language-aware segmentation across 28+ file types
- **Incremental indexing** -- only re-indexes changed files
- **Self-contained** -- no external infrastructure (unlike Sourcegraph)
- **Multiple integration paths** -- skill, MCP server, CLI

## Why We Declined

### Architecture mismatch: enforcement vs discovery

Our ecosystem is enforcement-first. CocoIndex Code solves a discovery problem.

| Our need | Current solution | CocoIndex helps? |
|---|---|---|
| Hook enforcement (37+ checks) | `grep` on `git diff` lines | No -- needs exact pattern match |
| Code exploration | Grep/Glob/Explore agents | Marginal -- ripgrep already fast |
| Find similar patterns | Grep with regex | Maybe -- semantic finds non-obvious matches |
| Token reduction | Hooks are bash, zero LLM tokens | No savings path |

Our 33 hooks use `grep` on `git diff` output for deterministic, zero-false-negative pattern matching. Semantic search adds nothing to enforcement -- you can't fuzzy-match `as any` or `useCallback`.

### Heavy dependency chain

- Python runtime required (our hooks are pure bash)
- Embedding model download (~90MB for MiniLM)
- Indexing daemon for background updates
- YAML configuration files
- Adds operational complexity with no enforcement benefit

### Existing search is sufficient

Our Explore agents + ripgrep + Glob handle code discovery well for our codebase sizes. Semantic search shines on large, unfamiliar codebases -- not the enforcement workflow where we already know what patterns to match.

### Alpha maturity

Engine version `1.0.0a24+` -- not yet stable. API and configuration surface may change.

## Where It Could Add Value (Future)

- **`/triage-issue`** -- finding related code to a bug description via natural language
- **Sandcastle agents** -- initial context gathering on unfamiliar codebases
- **Large monorepo scenarios** -- where ripgrep regex isn't enough to find relevant code

If adopted, MCP server integration is cleanest path -- Claude Code picks it up natively, no custom skill needed.

## Comparison to Alternatives

| Tool | Approach | Our use |
|---|---|---|
| ripgrep | Regex text search | Primary -- hooks + Explore agents |
| ast-grep | Syntactic AST pattern matching | Not adopted -- grep sufficient |
| Sourcegraph | Full code intelligence platform | Too heavy for our scale |
| CocoIndex Code | Semantic vector search | Declined -- enforcement needs exact match |

## When to Revisit

- We move toward **large monorepo scenarios** where ripgrep regex isn't enough
- CocoIndex Code hits **stable v1.0+**
- A **lighter integration path** ships (no Python runtime or model download required)
- We add **discovery-oriented skills** that need semantic code understanding
