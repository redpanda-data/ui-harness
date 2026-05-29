# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Opinionated.** Multiple words for same concept -> pick best one, list others as _Avoid_.
- **Flag conflicts.** Ambiguous term -> "Flagged Ambiguities" with clear resolution.
- **Tight definitions.** One or two sentences max. Define what it IS, not what it does.
- **Project-specific terms only.** No general programming concepts (timeouts, error types, utility patterns). Before adding a term, ask: is this unique to this context, or general programming? Only the former belongs.
- **Group naturally.** Subheadings when clusters emerge. Flat list if single area.

## Single vs Multi-Context

**Single context (most repos):** One `CONTEXT.md` at repo root.

**Multiple contexts:** `CONTEXT-MAP.md` at root lists contexts + relationships:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) -- receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) -- generates invoices and processes payments

## Relationships

- **Ordering -> Billing**: Ordering emits `OrderPlaced` events; Billing consumes them
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

Skill infers which structure applies. Neither exists -> create root `CONTEXT.md` lazily.
