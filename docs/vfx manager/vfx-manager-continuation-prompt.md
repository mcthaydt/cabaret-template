# VFX Manager - Continuation Prompt

## Current Status (2026-01-17)

- **Refactor status**: Phase 4 complete (Resource-Driven Configuration).
- **Phase 4 commit**: `1dae3c9`.
- **Next phase**: Phase 5 (Typed Results & Helper Fixes).
- **New resources**: `RS_ScreenShakeTuning` + `RS_ScreenShakeConfig` with defaults under `resources/vfx/`.
- **Tests run**: `test_rs_screen_shake_tuning`, `test_s_screen_shake_publisher_system`, style enforcement (all passing; Godot aborted after summary with `recursive_mutex lock failed` on the publisher run).
- **Manual QA**: Pending Phase 1 (T1.13), Phase 2 (T2.6), Phase 3 (T3.11), Phase 4 (T4.11).

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

- Phase 5: add typed `ShakeResult`, fix alpha bug, update helper APIs, add testing hooks.
