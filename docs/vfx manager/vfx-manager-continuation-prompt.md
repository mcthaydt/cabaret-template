# VFX Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 0 Complete (Redux Foundation)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Tests passing**: 33/33 Redux tests (5 initial state + 15 reducer + 13 selectors)

## Phase 0 Completion Summary

**Files Created:**
- `scripts/state/resources/rs_vfx_initial_state.gd` - VFX initial state resource with screen shake and damage flash settings
- `scripts/state/actions/u_vfx_actions.gd` - Action creators for VFX state mutations
- `scripts/state/reducers/u_vfx_reducer.gd` - Pure reducer with intensity clamping (0.0-2.0)
- `scripts/state/selectors/u_vfx_selectors.gd` - Selectors with edge case handling
- `tests/unit/state/test_vfx_initial_state.gd` - 5 passing tests
- `tests/unit/state/test_vfx_reducer.gd` - 15 passing tests
- `tests/unit/state/test_vfx_selectors.gd` - 13 passing tests

**Files Modified:**
- `scripts/state/m_state_store.gd` - Added VFX reducer const, vfx_initial_state export, passed to initialize_slices
- `scripts/state/utils/u_state_slice_manager.gd` - Added VFX slice registration after debug slice

**VFX State Schema:**
```gdscript
{
  "vfx": {
    "screen_shake_enabled": bool,     # default: true
    "screen_shake_intensity": float,  # default: 1.0, clamped 0.0-2.0
    "damage_flash_enabled": bool      # default: true
  }
}
```

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

- Start at **Phase 1** in `docs/vfx manager/vfx-manager-tasks.md` and complete tasks in order.
- Phase 1 focuses on VFX Core Manager: trauma system, ECS event subscriptions, and basic manager lifecycle.
- After each completed phase:
  - Update `docs/vfx manager/vfx-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY

