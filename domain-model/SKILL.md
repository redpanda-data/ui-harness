---
name: domain-model
description: "LEGACY LOCAL. Prefer `/grill-with-docs` for docs-first domain grilling and CONTEXT.md/ADR updates. Use only when user explicitly requests `/domain-model` or local three-hat review."
---

> Legacy: prefer `/grill-with-docs`. Keep only for backward compatibility with local three-hat workflow.

# Domain Model

Grill + document. Three-hat adversarial review PLUS institutional memory captured inline as CONTEXT.md + ADRs.

## Step 1: Interview

Walk every branch of decision tree. Resolve dependencies one-by-one. Each question, give recommended answer. One at time.

If question answerable by exploring codebase, explore first.

## Light DDD -- Document, Don't Prescribe

USE: Ubiquitous Language | Bounded Contexts | ADRs
SKIP: Entities | Value Objects | Aggregates | Domain Events

Goal = "just enough docs" make codebase navigable. Language into software, not patterns into software.

## Domain Awareness

During codebase exploration, look for existing docs:

### Single context (most repos)

    /
    ├── CONTEXT.md
    ├── docs/adr/
    │   ├── 0001-event-sourced-orders.md
    │   └── 0002-postgres-for-write-model.md
    └── src/

### Multi-context (if CONTEXT-MAP.md exists at root)

    /
    ├── CONTEXT-MAP.md
    ├── docs/adr/                    <- system-wide decisions
    ├── src/
    │   ├── ordering/
    │   │   ├── CONTEXT.md
    │   │   └── docs/adr/            <- context-specific decisions
    │   └── billing/
    │       ├── CONTEXT.md
    │       └── docs/adr/

Create files lazy -- only when first term resolved or first ADR needed.

## Step 2: Domain Grill

**Challenge glossary**: Term conflict with CONTEXT.md? Call out now.

**Sharpen language**: Vague or overloaded term? Propose precise canonical term. "You say 'account' -- Customer or User? Different things."

**Concrete scenarios**: Stress-test relationships with edge cases. Force precision on boundaries.

**Cross-reference code**: User state how something works -> verify code agrees. Surface contradictions.

## Step 3: Three-Hat Fan-Out (parallel)

Once user present coherent plan + terms resolved, spawn three reviewers **in parallel** (single message, multiple Agent tool calls):

- **`plan-product-hat`**: persona, pain, success metric, scope, reversibility, TTV
- **`plan-engineering-hat`**: architecture, error paths, perf, security, test strategy, rollback
- **`plan-design-hat`**: flow, a11y, copy, visual consistency, states (empty/loading/error)

Each emit `{reviewer, status, findings[], must_answer[]}` per findings-schema.md.

## Step 4: Merge + Document

Consolidate all `must_answer` questions into single list, deduped. Surface to user. User answer each. Plan updated inline.

**Update CONTEXT.md inline**: Term resolved or scope clarified -> update now. No batch. See [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md).

**Offer ADRs sparingly**: Only when ALL three true: hard reverse, surprising without context, result of real trade-off. See [ADR-FORMAT.md](ADR-FORMAT.md).

Any reviewer return `status: BLOCKED` -> plan no advance until blocking finding addressed or user override.

## Step 5: Approve

All hats return `APPROVED` or user override specific findings -> plan approved -> Phase 3 (Implement).

## Skip Gate

Skip three-hat fan-out only if:
- Trivial bug fix, AND
- <3 tasks in plan, AND
- No architectural / product / UX decisions

Else, fan-out mandatory. For a light grill without DDD docs, use `/grill-me` instead.
