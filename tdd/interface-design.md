# Interface Design for Testability

## 1. Accept Dependencies, Don't Create Them

```typescript
// Testable
function processOrder(order, paymentGateway) {}

// Hard to test
function processOrder(order) {
  const gateway = new StripeGateway();
}
```

## 2. Return Results, Don't Produce Side Effects

```typescript
// Testable
function calculateDiscount(cart): Discount {}

// Hard to test
function applyDiscount(cart): void {
  cart.total -= discount;
}
```

## 3. Small Surface Area

- Fewer methods = fewer tests needed
- Fewer params = simpler test setup
- Hide complexity behind simple interfaces

## 4. SDK-Style Over Generic Fetchers

```typescript
// Each function independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// Mocking requires conditional logic -- avoid
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

SDK approach: each mock returns one shape, no conditionals in test setup, type safety per endpoint.
