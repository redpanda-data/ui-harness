# Lightpanda Browser Evaluation

**Date:** 2026-04-12
**Status:** Declined -- revisit at v1.0
**Repository:** https://github.com/lightpanda-io/browser

## What is Lightpanda?

A headless browser built from scratch in Zig, designed for AI agents and web automation. Unlike Playwright/Puppeteer (wrappers around Chromium via CDP), Lightpanda is a new browser engine optimized for server-side usage without graphical rendering overhead.

## Key Strengths

- **11x faster** than headless Chrome on real workloads
- **16x less memory** (24-123 MB vs 207-2000 MB)
- **0.1s startup** vs 3-4s for Chrome
- Scales to **25+ concurrent processes** (Chrome degrades after 5-10)
- **CDP-compatible** -- drop-in replacement for Playwright/Puppeteer scripts
- Has an official **MCP server** (`gomcp`) for AI agent integration
- Written in Zig for systems-level performance

## Why We Declined (v0.2.8)

### Dealbreakers for this codebase

| Limitation | Impact |
|-----------|--------|
| No screenshots or PDFs | Can't replace agent-browser for visual verification |
| React/Vue/Angular compatibility issues | Frontend-focused codebase needs reliable framework support |
| No coordinate-based interactions | Only selector-based clicks |
| Single context per process | 1 connection, 1 context, 1 page only |
| Beta stability | "Errors or crashes may still occur" |

### Our use cases vs Lightpanda's sweet spot

**What we need browsers for:**
1. Visual verification of UI changes (screenshots) -- Lightpanda can't
2. E2E testing of React apps (full framework support) -- Lightpanda is unreliable
3. Authenticated page inspection (full Chrome) -- Lightpanda can't

**What Lightpanda excels at (not our use case):**
- High-concurrency scraping pipelines (100+ parallel processes)
- Server-side data extraction at scale
- AI agent workloads where occasional failures are tolerable

## Current Browser Tool Matrix

| Tool | Purpose | Skills |
|------|---------|--------|
| Playwright | E2E testing, CI assertions | `setup-e2e-testing`, `development-lifecycle` |
| agent-browser | AI visual verification, screenshots | `brainstorming`, `development-lifecycle`, verifier agent |
| claude-in-chrome MCP | Authenticated pages, interactive debug | `development-lifecycle`, `brainstorming` |

No gaps exist in the current matrix. Each tool serves a distinct purpose.

## When to Revisit

- Lightpanda reaches **v1.0** with stable framework support
- Lightpanda adds **rendering/screenshot** capabilities
- We add **scraping or data-extraction** skills (Lightpanda's sweet spot)
- Memory/concurrency becomes a bottleneck in CI browser testing
