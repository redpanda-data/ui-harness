# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
A customer's request to purchase one or more items.
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

## Relationships

- An **Order** produces one or more **Invoices**
- An **Invoice** belongs to exactly one **Customer**

## Example Dialogue

> **Dev:** "When a **Customer** places an **Order**, do we create the **Invoice** immediately?"
> **Domain expert:** "No -- an **Invoice** is only generated once a **Fulfillment** is confirmed."

## Flagged Ambiguities

- "account" was used to mean both **Customer** and **User** -- resolved: distinct concepts.
```

## Rules

- **Opinionated.** Multiple words for same concept -> pick best one, list others as _Avoid_.
- **Flag conflicts.** Ambiguous term -> "Flagged Ambiguities" with clear resolution.
- **Tight definitions.** One sentence max. Define what it IS, not what it does.
- **Show relationships.** Bold term names, express cardinality where obvious.
- **Project-specific terms only.** No general programming concepts (timeouts, error types).
- **Group naturally.** Subheadings when clusters emerge. Flat list if single area.
- **Example dialogue.** Dev + domain expert conversation showing terms interact naturally.

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
