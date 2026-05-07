# TOON Format Evaluation

**Date:** 2026-04-12
**Status:** Declined -- revisit if structured data enters LLM context
**Repository:** https://github.com/toon-format/toon

## What is TOON?

Token-Oriented Object Notation (TOON) is a compact, human-readable encoding of the JSON data model optimized for LLM input. It declares structure once (field names, array lengths) and streams values compactly -- eliminating repeated keys that inflate token counts in standard JSON.

```
// JSON: 235 tokens
{"hikes": [{"id": 1, "name": "Blue Lake Trail", "distanceKm": 7.5}, ...]}

// TOON: 106 tokens (55% reduction)
hikes[3]{id,name,distanceKm}:
  1,Blue Lake Trail,7.5
  2,Ridge Overlook,9.2
  3,Wildflower Loop,5.1
```

Spec v3.0 (2025-11-24). Reference implementation in TypeScript (`@toon-format/toon` v2.1.0). CLI, VS Code extension, tree-sitter grammar, and 8+ language implementations available.

## Key Strengths

- **40-60% token savings** on uniform arrays of objects (tabular data)
- **76.4% accuracy** vs JSON's 75.0% across 4 LLMs, using 39.9% fewer tokens
- Structural validation: `[N]` length markers detect truncation and corruption
- Lossless round-trip with JSON
- Production-ready: 303 commits, 99 closed issues, active maintenance

## Why We Declined

### Content shape mismatch

Our skills ecosystem content is prose instructions, shell scripts, and markdown checklists -- not structured data arrays.

| Our content type | Tokens | TOON benefit |
|---|---|---|
| SKILL.md files (33) | ~19K | None -- prose, not tabular |
| REFERENCE.md files (24) | ~32K | None -- code examples, diagnostics |
| Hook shell scripts | ~4K | None -- not structured data |
| AGENTS.md | ~1K | None -- rule lists, not arrays |

TOON adds **31.9% overhead** on deeply nested/non-uniform structures -- the opposite of what we want.

### Existing token efficiency patterns

We already address token costs through:
1. **One-shot guidance** -- orchestration hooks emit per-category guidance once per session
2. **suppressOutput** -- most PostToolUse hooks suppress context pollution
3. **Caveman compression** -- `/caveman` cuts prose ~75%
4. **Lazy references** -- REFERENCE.md loads on-demand, not injected automatically
5. **Progressive injection** -- light at SessionStart, heavy only at Stop

### TOON's sweet spot vs ours

**What TOON excels at (not our use case):**
- API response payloads with repeated schemas (employee records, analytics rows)
- Large uniform datasets injected into LLM prompts
- Replacing JSON/CSV in data-heavy context windows

**What our ecosystem needs:**
- Prose compression (caveman mode)
- Selective context injection (hook architecture)
- Code example efficiency (already minimal)

## Benchmark Highlights

| Format | Accuracy | Tokens | Efficiency (acc%/1K tokens) |
|---|---|---|---|
| TOON | 76.4% | 2,759 | 27.7 |
| JSON compact | 73.7% | 3,104 | 23.7 |
| YAML | 74.5% | 3,749 | 19.9 |
| JSON | 75.0% | 4,587 | 16.4 |
| XML | 72.1% | 5,221 | 13.8 |

Source: Official benchmarks across Claude Haiku, Gemini 3 Flash, GPT-5 Nano, Grok 4.1 (209 questions, 5,016 evaluations).

## When to Revisit

- We add skills that inject **large structured datasets** into LLM context (component registries, evaluation result tables)
- We build **data extraction or analytics** skills where TOON's tabular format shines
- Context window costs become a bottleneck despite existing compression patterns
