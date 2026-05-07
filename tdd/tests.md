# Good and Bad Tests

## Good Tests

**Integration-style**: test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: tests observable behaviour
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behaviour users / callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: coupled to internal structure.

```typescript
// BAD: tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = vi.spyOn(paymentService, "process");
  await checkout(cart, payment);
  expect(mockPayment).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts / order of internal collaborators
- Test breaks when refactoring without behaviour change
- Test name describes HOW not WHAT
- Verifying through external means instead of through the interface

```typescript
// BAD: bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

## Heuristic

If you rename an internal function and tests fail, those tests were testing implementation, not behaviour. Refactor the test, not the production code.
