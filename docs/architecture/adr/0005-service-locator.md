# ADR 0005: Service Locator for Manager Dependency Access

**Status**: Accepted (amended 2026-04-23 — V8 P3)  
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
- Tests isolate services with `U_ServiceLocator.push_scope()` and `pop_scope()`. `BaseTest` owns the standard scope lifecycle.
- `register()` fails on conflicting replacement; use `register_or_replace()` only when replacement is intentional.
- The project does not use Godot autoloads for managers. Persistent services live as scene nodes under `scenes/root.tscn` and register explicitly.

Group lookup remains a fallback in some areas for backward compatibility and test environments.

## Consequences

**Positive**

- Explicit, centralized dependency map (supports validation + graph output)
- Faster lookups (Dictionary) and consistent error handling
- Simplifies dependency injection patterns in tests
- Scope isolation prevents test services from leaking across GUT cases.
- Avoiding autoloads keeps manager lifetime visible in scenes and avoids hidden global state.

**Negative**

- Introduces a global registry that must be kept in sync with `root.tscn`
- Overuse can hide dependencies if not paired with validation and documentation
- Tests that bypass `BaseTest` must manage ServiceLocator scopes manually.

## Alternatives Considered

- **Continue using group lookups**: simpler API surface, but scales poorly and keeps dependencies implicit.
- **Autoload manager singletons**: reduces lookup code, but increases global hidden state and makes tests harder to isolate.

## References

- `scripts/core/u_service_locator.gd`
- `scripts/root.gd`
- `scenes/root.tscn`
