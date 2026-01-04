# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 5 Complete (Settings UI Integration)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 75/75 tests (33/33 Redux + 17/17 Manager + 15/15 ScreenShake + 10/10 DamageFlash)
- **Phase 6 status**: Not started (integration tests + manual QA pending)
- **Manager added**: `M_VFXManager` added to `scenes/root.tscn` under `Managers/` hierarchy
- **Screen shake helper**: `M_ScreenShake` implemented with quadratic falloff and noise-based randomness
- **Damage flash helper**: `M_DamageFlash` implemented with 0.4s fade duration and tween-based animation
- **Damage flash overlay**: Scene created at `scenes/ui/ui_damage_flash_overlay.tscn` (CanvasLayer layer 50)
- **Camera integration**: `M_CameraManager.apply_shake_offset()` applies shake to the active gameplay camera (or TransitionCamera during blends) via a ShakeParent Node3D
- **Flash integration**: `M_VFXManager` loads damage flash overlay on `_ready()` and triggers flash on `health_changed` events when enabled
- **ServiceLocator registration**: Both `M_VFXManager` and `M_CameraManager` registered with ServiceLocator
- **Settings UI**: VFX settings overlay created at `scenes/ui/settings/ui_vfx_settings_overlay.tscn`
- **Settings integration**: "Visual Effects" button added to settings menu, registered in UI/scene registries
- **Apply/Cancel pattern**: Settings use Apply/Cancel/Reset buttons (consistent with gamepad/touchscreen settings)
- **State persistence**: VFX settings persist via Redux state persistence (VFX slice)
- **Post-audit fixes applied**:
  - Fixed `M_StateStore.subscribe()` callback arity mismatch in `UI_VFXSettingsOverlay`
  - Updated `M_VFXManager` to parse typed `health_changed` payload (`previous_health/new_health`) and `entity_landed` payload (`vertical_velocity`)

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/vfx manager/vfx-manager-tasks.md`
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`

## Repo Reality Checks (Do Not Skip)

- There is **no** `scenes/main.tscn` in this project; `M_VFXManager` is already added to `scenes/root.tscn` under `Managers/`.
- `U_ServiceLocator` lives at `res://scripts/core/u_service_locator.gd` and its API is `U_ServiceLocator.register(...)` / `get_service(...)` / `try_get_service(...)`.
- There is **no** `MockECSEventBus` under `tests/mocks/`; use real `U_ECSEventBus` and call `U_ECSEventBus.reset()` in `before_each()` to prevent subscription leaks.
- `M_CameraManager` now supports both camera blending AND screen shake via `apply_shake_offset(offset: Vector2, rotation: float)`.
- `LoadingOverlay` in `scenes/root.tscn` uses `layer = 100`; damage flash overlay uses `layer = 50` (below LoadingOverlay).
- Damage flash overlay is already created and loaded by `M_VFXManager` on `_ready()`.

## Next Step

- Start at **Phase 6** in `docs/vfx manager/vfx-manager-tasks.md` and complete tasks in order.
- Phase 6 focuses on Testing & Integration: Writing integration tests, running full test suite, and performing manual QA.
- Phase 6 requires:
  - Writing integration tests for VFX-Camera interaction
  - Writing integration tests for VFX settings UI
  - Performing manual playtest to verify all VFX features work in-game
  - Running full test suite to ensure 95 tests pass (60 unit + 35 integration)
- After each completed phase:
  - Update `docs/vfx manager/vfx-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY
