# Deep Modules

From "A Philosophy of Software Design" (John Ousterhout):

**Deep module** = small interface + lots of implementation

```
┌─────────────────────┐
│   Small Interface   │  <- Few methods, simple params
├─────────────────────┤
│                     │
│                     │
│  Deep Implementation│  <- Complex logic hidden
│                     │
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid)

```
┌─────────────────────────────────┐
│       Large Interface           │  <- Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  <- Just passes through
└─────────────────────────────────┘
```

## Design Questions

- Can I reduce method count?
- Can I simplify parameters?
- Can I hide more complexity inside?
- Am I extracting functions just for testability? (If yes, test at boundary instead.)

## Why This Matters for Testing

Deep modules = test at boundary through public interface. Tests survive refactors.

Shallow modules = tests couple to implementation. Internal rename breaks tests even though behavior unchanged.

Deep modules are more testable AND more AI-navigable.
