# VFX Manager - Continuation Prompt

## Current Status (2026-01-16)

- **Refactor status**: Phase 1 complete (event architecture + request queue).
- **Phase 1 commit**: `6860034`.
- **Next phase**: Phase 2 (Service Locator & dependency injection).
- **New ECS request events**: `Evn_ScreenShakeRequest`, `Evn_DamageFlashRequest`.
- **New publisher systems**: `S_ScreenShakePublisherSystem`, `S_DamageFlashPublisherSystem`.
- **Event name constants**: `U_ECSEventNames` (use constants instead of string literals).
- **Manager behavior**: `M_VFXManager` subscribes to request events, enqueues, processes in `_physics_process()`.
- **Scene wiring**: Publisher systems added under `Systems/Feedback` in `scenes/gameplay/gameplay_base.tscn`.
- **Tests run**: ECS event unit tests, ECS system unit tests, VFX integration tests, style enforcement (all passing).
- **Manual QA**: Pending Phase 1 manual verification.

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`.
- Follow `docs/vfx manager/vfx-manager-refactor-tasks.md` in TDD order.
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`.

## Repo Reality Checks (Do Not Skip)

- There is **no** `MockECSEventBus`; use `U_ECSEventBus.reset()` in `before_each()`.
- `U_ECSEventNames` centralizes ECS event/service names; use constants for subscriptions.
- Publisher systems publish typed requests via `U_ECSEventBus.publish_typed()`.
- `M_VFXManager` processes request queues inside `_physics_process()`; event handlers only enqueue.
- `M_VFXManager` still registers with ServiceLocator (Phase 2 will refactor this).

## Next Step

- Phase 2: add `@export` injection for state store and camera manager, register VFX manager in `scripts/scene_structure/main.gd`, remove self-registration.
