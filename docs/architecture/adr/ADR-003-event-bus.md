# ADR-003: Event Bus for Cross-System Communication

**Status**: Accepted  
**Date**: 2025-12-17  

## Context

Some gameplay interactions need to be broadcast without introducing direct dependencies:

- “Entity landed” should trigger VFX/SFX/haptics without hard-wiring systems together.
- “Checkpoint activated” and “victory triggered” should be observable by multiple consumers.
- Managers (e.g., `M_SceneManager`) should react to gameplay events without ECS systems calling manager APIs directly.

Signals can work, but wiring signals across unrelated nodes tends to create scene-specific coupling and difficult-to-trace dependencies.

## Decision

Use an event bus abstraction with domain separation:

- Shared implementation: `scripts/events/base_event_bus.gd`
- ECS-domain bus: `scripts/ecs/u_ecs_event_bus.gd`
- State-domain bus: `scripts/state/u_state_event_bus.gd` (used by state store/tests)

Events use a small standard payload shape (`{event_name, payload, time}`), and some flows also publish typed event objects (`Evn_*`).

## Consequences

**Positive**

- Reduces direct manager/system coupling
- Encourages “publish/subscribe” patterns that test well
- Keeps event histories separate per domain (ECS vs State), reducing accidental cross-talk

**Negative**

- Harder to trace than a direct method call if logging/observability is poor
- Requires consistent event naming and payload shape discipline

## Alternatives Considered

- **Direct dependencies** (system calls manager): easy at first, but degrades modularity and testability.
- **Global Godot signals / autoload signal bus**: workable, but often turns into an implicit global API without dependency documentation.

## References

- `docs/ecs/ecs_architecture.md`
- `scripts/events/base_event_bus.gd`
- `scripts/ecs/u_ecs_event_bus.gd`
- `scripts/state/u_state_event_bus.gd`

