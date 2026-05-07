# When to Mock

## Mock at System Boundaries Only

- External APIs (payment, email, etc.)
- Databases (sometimes -- prefer test DB or PGLite)
- Time / randomness
- File system (sometimes)

## Don't Mock

- Your own classes/modules
- Internal collaborators
- Anything you control

**Warning sign**: Test breaks on refactor but behavior unchanged -> testing implementation, not behavior.

## Dependency Injection for Mockability

```typescript
// Easy to mock -- dependency injected
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock -- dependency created internally
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

## Heavy Mocking = Design Problem

If you need to mock 5+ things for one test -> module has too many dependencies. Redesign for testability rather than mocking harder.

See [interface-design.md](interface-design.md) for patterns that make testing natural.
