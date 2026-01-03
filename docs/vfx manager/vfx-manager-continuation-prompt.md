# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 2 Complete (Screen Shake System)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 65/60 tests (33/33 Redux + 17/17 Manager + 15/15 ScreenShake)
- **Manager added**: `M_VFXManager` added to `scenes/root.tscn` under `Managers/` hierarchy
- **Screen shake helper**: `U_ScreenShake` implemented with quadratic falloff and noise-based randomness

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

- Start at **Phase 3** in `docs/vfx manager/vfx-manager-tasks.md` and complete tasks in order.
- Phase 3 focuses on Camera Manager Integration: Adding shake parent node to M_CameraManager and wiring VFX Manager to apply screen shake.
- After each completed phase:
  - Update `docs/vfx manager/vfx-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY
