# ADR-001: Redux-Style State Management

**Status**: Accepted  
**Date**: 2025-12-17  

## Context

The project needs a centralized, testable source of truth for:

- UI navigation and overlay stack
- Gameplay session state that persists across scene transitions
- Player/settings/input profiles that persist across sessions (save/load)
- Deterministic event flows that are easy to audit in tests

Godot’s scene tree and signals are powerful but tend to produce implicit, ad-hoc coupling when used as the primary “state layer” for cross-scene concerns.

## Decision

Adopt a Redux-style architecture implemented by `M_StateStore`:

- State is stored as plain `Dictionary` slices (e.g., `gameplay`, `scene`, `navigation`, `settings`, `input`).
- Writes occur via **actions** (`Dictionary` with `type: StringName` + `payload`), created by `U_*Actions`.
- State updates occur via pure reducers (`U_*Reducer`), using immutability patterns (`.duplicate(true)`).
- Reads occur via selectors (`U_*Selectors`) to keep call sites stable and testable.
- Signal emission is batched per physics frame for stability.

## Consequences

**Positive**

- Single source of truth across managers/UI/gameplay systems
- Predictable flows: `dispatch(action) → reducer → new state → selectors`
- Unit-testable without scene tree via mocks (`I_StateStore` + `MockStateStore`)
- Enables persistence/versioning and controlled normalization during load

**Negative**

- Extra boilerplate (actions/reducers/selectors)
- Requires discipline to avoid direct state mutation at call sites
- Debugging requires understanding action types and slice boundaries

## Alternatives Considered

- **Signals-only**: simpler locally, but coupling and cross-scene coordination grow quickly and become difficult to test.
- **Autoload singleton state**: convenient, but increases global hidden dependencies and makes tests harder to isolate.

## References

- `docs/state_store/redux-state-store-prd.md`
- `scripts/state/m_state_store.gd`

