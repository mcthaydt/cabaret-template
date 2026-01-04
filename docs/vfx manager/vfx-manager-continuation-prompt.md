# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 7 Complete (Particles Toggle)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 82/82 VFX unit + 13/13 VFX integration (style enforcement passing)
- **Phase 6 status**: Complete (integration + manual QA)
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
- **Integration tests**: Added `tests/integration/vfx/test_vfx_camera_integration.gd` and `tests/integration/vfx/test_vfx_settings_ui.gd`
- **Particles toggle**: Added `vfx.particles_enabled` (default true) and gated particle spawns via `U_ParticleSpawner`
- **Post-audit fixes applied**:
  - Fixed `M_StateStore.subscribe()` callback arity mismatch in `UI_VFXSettingsOverlay`
  - Updated `M_VFXManager` to parse typed `health_changed` payload (`previous_health/new_health`) and `entity_landed` payload (`vertical_velocity`)
  - Updated `UI_VFXSettingsOverlay` to preserve local edits (ignore state updates while editing)

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

- Manual playtest: verify `particles_enabled` toggles jump/landing/spawn particles in-game and persists across save/load.
- Decide whether to expand beyond a global toggle (per-effect toggles, particle quality/intensity slider).
