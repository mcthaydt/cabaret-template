# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 3 Complete (Camera Manager Integration)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 65/65 tests (33/33 Redux + 17/17 Manager + 15/15 ScreenShake)
- **Manager added**: `M_VFXManager` added to `scenes/root.tscn` under `Managers/` hierarchy
- **Screen shake helper**: `M_ScreenShake` implemented with quadratic falloff and noise-based randomness
- **Camera integration**: `M_CameraManager` has shake parent node hierarchy (ShakeParent → TransitionCamera); `M_VFXManager` applies shake via `apply_shake_offset()`
- **ServiceLocator registration**: Both `M_VFXManager` and `M_CameraManager` registered with ServiceLocator

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/vfx manager/vfx-manager-tasks.md`
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`

## Repo Reality Checks (Do Not Skip)

- There is **no** `scenes/main.tscn` in this project; add `M_VFXManager` to `scenes/root.tscn` under `Managers/`.
- `U_ServiceLocator` lives at `res://scripts/core/u_service_locator.gd` and its API is `U_ServiceLocator.register(...)` / `get_service(...)` / `try_get_service(...)`.
- There is **no** `MockECSEventBus` under `tests/mocks/`; use real `U_ECSEventBus` and call `U_ECSEventBus.reset()` in `before_each()` to prevent subscription leaks.
- `M_CameraManager` now supports both camera blending AND screen shake via `apply_shake_offset(offset: Vector2, rotation: float)`.
- `LoadingOverlay` in `scenes/root.tscn` uses `layer = 100`; if you add a damage flash overlay scene, pick an explicit layer below it (docs recommend `layer = 50`).

## Next Step

- Start at **Phase 4** in `docs/vfx manager/vfx-manager-tasks.md` and complete tasks in order.
- Phase 4 focuses on Damage Flash System: Creating damage flash overlay scene, implementing U_DamageFlash helper, and integrating with VFX Manager.
- After each completed phase:
  - Update `docs/vfx manager/vfx-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY
