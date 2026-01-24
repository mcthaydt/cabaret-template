# ADR-004: Service Locator for Manager Dependency Access

**Status**: Accepted  
**Date**: 2025-12-17  

## Context

Historically, managers and systems discovered dependencies via:

- group lookups (`get_tree().get_first_node_in_group(...)`)
- parent traversal patterns

As the project grew, this created:

- scattered lookup logic with inconsistent error handling
- implicit dependencies that were not validated at startup
- unnecessary O(n) tree traversals in hot paths

## Decision

Adopt `U_ServiceLocator` as the primary manager/service registry:

- Root scene registers all persistent managers at startup (`root.gd`).
- Consumers use:
  - `U_ServiceLocator.get_service(name)` for required dependencies (errors if missing)
  - `U_ServiceLocator.try_get_service(name)` for optional/test-safe dependencies
- Dependency relationships are declared and validated at startup (`register_dependency(...)`, `validate_all()`).

Group lookup remains a fallback in some areas for backward compatibility and test environments.

## Consequences

**Positive**

- Explicit, centralized dependency map (supports validation + graph output)
- Faster lookups (Dictionary) and consistent error handling
- Simplifies dependency injection patterns in tests

**Negative**

- Introduces a global registry that must be kept in sync with `root.tscn`
- Overuse can hide dependencies if not paired with validation and documentation

## Alternatives Considered

- **Continue using group lookups**: simpler API surface, but scales poorly and keeps dependencies implicit.
- **Autoload manager singletons**: reduces lookup code, but increases global hidden state and makes tests harder to isolate.

## References

- `scripts/core/u_service_locator.gd`
- `scripts/root.gd`
- `scenes/root.tscn`
