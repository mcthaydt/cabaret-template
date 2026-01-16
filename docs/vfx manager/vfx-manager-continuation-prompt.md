# VFX Manager - Continuation Prompt

## Current Status (2026-01-17)

- **Refactor status**: Phase 2 complete (Service Locator + dependency injection).
- **Phase 2 commit**: `9cde55d`.
- **Next phase**: Phase 3 (Player-only & transition gating).
- **Injection support**: `M_VFXManager` exposes `@export` `state_store` and `camera_manager` for tests.
- **Service registration**: `scripts/scene_structure/main.gd` registers `M_VFXManager`; no self-registration.
- **Tests run**: VFX injection unit tests + VFX manager unit tests (all passing).
- **Manual QA**: Pending Phase 1 (T1.13) and Phase 2 (T2.6).

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`.
- Follow `docs/vfx manager/vfx-manager-refactor-tasks.md` in TDD order.
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`.

## Repo Reality Checks (Do Not Skip)

- There is **no** `MockECSEventBus`; use `U_ECSEventBus.reset()` in `before_each()`.
- `U_ECSEventNames` centralizes ECS event/service names; use constants for subscriptions.
- Publisher systems publish typed requests via `U_ECSEventBus.publish_typed()`.
- `M_VFXManager` processes request queues inside `_physics_process()`; event handlers only enqueue.
- `M_VFXManager` no longer self-registers; `main.gd` handles ServiceLocator bootstrap.

## Next Step

- Phase 3: implement player-only and transition gating + tests.
