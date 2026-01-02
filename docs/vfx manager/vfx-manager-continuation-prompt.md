# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 1 Complete (VFX Core Manager)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 50/60 tests (33/33 Redux + 17/17 Manager)
- **Manager added**: `M_VFXManager` added to `scenes/root.tscn` under `Managers/` hierarchy

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/vfx manager/vfx-manager-tasks.md`
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`

## Repo Reality Checks (Do Not Skip)

- There is **no** `scenes/main.tscn` in this project; add `M_VFXManager` to `scenes/root.tscn` under `Managers/`.
- `U_ServiceLocator` lives at `res://scripts/core/u_service_locator.gd` and its API is `U_ServiceLocator.register(...)` / `get_service(...)` / `try_get_service(...)`.
- There is **no** `MockECSEventBus` under `tests/mocks/`; use real `U_ECSEventBus` and call `U_ECSEventBus.reset()` in `before_each()` to prevent subscription leaks.
- `M_CameraManager` currently supports camera blending only; shake APIs are not implemented yet.
- `LoadingOverlay` in `scenes/root.tscn` uses `layer = 100`; if you add a damage flash overlay scene, pick an explicit layer below it (docs recommend `layer = 50`).

## Next Step

- Start at **Phase 2** in `docs/vfx manager/vfx-manager-tasks.md` and complete tasks in order.
- Phase 2 focuses on Screen Shake System: U_ScreenShake helper with FastNoiseLite algorithm, quadratic falloff, and noise-based offset/rotation.
- After each completed phase:
  - Update `docs/vfx manager/vfx-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY

## Phase 1 Completion Notes

- **Completed Tasks**: Tasks 1.1-1.5 (manager scaffolding, ECS events, trauma system, scene integration)
- **Files Created**:
  - `scripts/managers/m_vfx_manager.gd` - VFX Manager with trauma system
  - `tests/unit/managers/test_vfx_manager.gd` - 17 passing tests
- **Files Modified**:
  - `scenes/root.tscn` - Added M_VFXManager node under Managers/
- **Key Learnings**:
  - BaseEventBus automatically wraps payload in {"name", "payload", "timestamp"} structure
  - Use `lerpf()` for value mapping, not `remap()` (doesn't exist in GDScript)
  - Event handlers receive wrapped event with payload nested inside
  - Trauma decay runs in `_physics_process` at 2.0/sec rate
