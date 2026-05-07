# ADR Format

ADRs live in `docs/adr/` with sequential numbering: `0001-slug.md`, `0002-slug.md`.

Create `docs/adr/` lazily -- only when first ADR needed.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. Most ADRs = single paragraph. Value = recording *that* a decision was made and *why*.

## Optional Sections

Only include when genuinely valuable:

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`)
- **Considered Options** -- only when rejected alternatives worth remembering
- **Consequences** -- only when non-obvious downstream effects

## When to Offer an ADR

ALL three must be true:

1. **Hard to reverse** -- cost of changing mind later is meaningful
2. **Surprising without context** -- future reader will wonder "why on earth?"
3. **Result of real trade-off** -- genuine alternatives existed, picked one for specific reasons

Easy to reverse -> skip. Not surprising -> skip. No real alternative -> skip.

### What Qualifies

- **Architectural shape.** "Monorepo." "Write model is event-sourced, read model projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library -- only the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; others reference by ID only." Explicit no-s are as valuable as yes-s.
- **Deliberate deviations from the obvious path.** "Manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. Stops the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "Can't use AWS -- compliance requirements." "Response times must be under 200ms -- partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** Considered GraphQL, picked REST for subtle reasons -> record it. Otherwise someone will suggest GraphQL again in six months.

## Numbering

Scan `docs/adr/` for highest existing number, increment by one.
