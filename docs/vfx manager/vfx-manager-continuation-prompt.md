# VFX Manager - Continuation Prompt

## Current Status (2026-01-16)

- **Refactor status**: Phase 6 implementation complete (Preload & Publisher Cleanup), commit pending.
- **Phase 5 commit**: `994da2e`.
- **Next phase**: Phase 6 commit + docs, then Phase 7 (Testing Improvements).
- **New helper**: `m_shake_result.gd` (ShakeResult).
- **Tests run**: `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_vfx_manager_cleanup.gd -gexit`, `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`.
- **Manual QA**: Pending Phase 1 (T1.13), Phase 2 (T2.6), Phase 3 (T3.11), Phase 4 (T4.11), Phase 5 (T5.10).

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

- Commit Phase 6 implementation, then commit doc updates separately, then proceed to Phase 7 tests.
