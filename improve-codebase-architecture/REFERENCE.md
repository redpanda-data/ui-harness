# Reference

## Dependency Categories

1. **In-process**: Pure computation, no I/O. Always deepenable.
2. **Local-substitutable**: Deps with local test stand-ins (e.g., PGLite for Postgres).
3. **Remote but owned (Ports & Adapters)**: Own services across network boundary. Define port interface.
4. **True external (Mock)**: Third-party, no control. Mock at boundary.

## Testing Strategy

Core principle: **replace, don't layer.**
- Old unit tests on shallow modules = waste once boundary tests exist -- delete
- Write new tests at deepened module's interface boundary
- Tests assert observable outcomes through public interface

## Issue Template

    ## Problem
    Describe the architectural friction.

    ## Proposed Interface
    The chosen interface design with signature, usage example, and what it hides.

    ## Dependency Strategy
    Which category applies and how dependencies are handled.

    ## Testing Strategy
    New boundary tests to write, old tests to delete, test environment needs.

    ## Implementation Recommendations
    Durable architectural guidance NOT coupled to current file paths.