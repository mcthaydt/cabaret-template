# vCam Manager - Continuation Prompt

## Current Focus

- **Feature / story**: Virtual Camera (vCam) Manager
- **Branch**: `vcam`
- **Status summary**: Documentation has been remediated for correctness. Implementation has not started. Begin with state and persistence, not scene/template edits.

## What Changed In The Docs

- Runtime wiring is now explicit: `M_VCamManager` belongs in `scenes/root.tscn`, and `S_VCamSystem` belongs in gameplay system trees.
- The `vcam` Redux slice is now defined as transient runtime observability only.
- The silhouette enable/disable toggle moved to the persisted `vfx` slice.
- The blend design now evaluates both outgoing and incoming cameras live during blends.
- The camera integration now requires a shake-safe `M_CameraManager.apply_main_camera_transform(...)` API instead of direct `camera.global_transform` writes.
- Soft-zone math is now defined as projection-based rather than basis-vector offset math.
- Mobile drag-look is now a hard requirement for rotatable orbit and first-person support.
- Mobile drag-look settings belong in `settings.input_settings.touchscreen_settings`, and the touch look path must extend `UI_MobileControls` plus `S_TouchscreenSystem`.
- `S_InputSystem` must be gated so it does not overwrite touchscreen gameplay input with zero `TouchscreenSource` payloads.
- Naming paths now follow the repo style guide:
  - `scripts/resources/display/vcam/`
  - `scripts/utils/display/`
  - `assets/shaders/sh_vcam_silhouette_shader.gdshader`

## Required Reading

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/vcam_manager/vcam-manager-plan.md`
- `docs/vcam_manager/vcam-manager-overview.md`
- `docs/vcam_manager/vcam-manager-prd.md`
- `docs/vcam_manager/vcam-manager-tasks.md`
- `scripts/managers/m_camera_manager.gd`
- `scripts/interfaces/i_camera_manager.gd`
- `tests/mocks/mock_camera_manager.gd`
- `scripts/ecs/systems/s_input_system.gd`
- `scripts/ecs/systems/s_touchscreen_system.gd`
- `scripts/state/utils/u_state_slice_manager.gd`
- `scripts/utils/u_global_settings_serialization.gd`
- `scripts/utils/display/u_cinema_grade_preview.gd`
- `scripts/ui/hud/ui_mobile_controls.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `scripts/resources/input/rs_touchscreen_settings.gd`
- `scenes/root.tscn`
- `scenes/templates/tmpl_base_scene.tscn`
- `scenes/templates/tmpl_camera.tscn`
- `scenes/gameplay/gameplay_base.tscn`

## Next Steps

1. Implement Phase 0 Commit 0.0: add persisted touchscreen drag-look settings and patch the touchscreen settings overlay.
2. Implement Phase 0 Commit 0.1: add persisted `vfx.occlusion_silhouette_enabled`.
3. Implement Phase 0 Commit 0.2: create `RS_VCamInitialState` and `cfg_default_vcam_initial_state.tres`.
4. Implement Phase 0 Commit 0.3: create vCam actions and reducer.
5. Implement Phase 0 Commit 0.4: add selectors, wire the new state export in `M_StateStore`, register `vcam` as transient, and patch `scenes/root.tscn`.
6. Before considering orbit/first-person done, implement mobile drag-look in `UI_MobileControls` and `S_TouchscreenSystem`, and gate `S_InputSystem` so touch input is not clobbered.

## Key Decisions To Preserve

- vCam does not replace `M_CameraManager`.
- vCam does not replace `S_CameraStateSystem`.
- vCam does not bypass the gameplay input pipeline.
- vCam does not treat mobile as special at the camera layer; touch look must still feed the shared `gameplay.look_input` path.
- vCam does not persist runtime slice state.
- vCam does not write `camera.fov` directly.
- vCam does not write `camera.global_transform` directly.
- vCam blends are live blends between two evaluated cameras, not frozen-transform lerps.

## Known Risks

- shake layering can regress if the camera-manager integration is implemented with direct global-transform writes
- soft-zone math can drift if depth-aware reprojection is skipped
- silhouettes can leak on scene swap if the persistent manager keeps stale occluder references
- root/gameplay scene wiring can be missed if only templates are edited
- orbit/first-person can appear “done” on desktop while still being broken on mobile if `S_TouchscreenSystem` continues to dispatch zero look input
- touch-look can conflict with joystick/buttons if `UI_MobileControls` does not claim a dedicated free-screen look touch
- touch gameplay input can be silently overwritten if `S_InputSystem` continues processing `TouchscreenSource` zero payloads

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Tasks](vcam-manager-tasks.md)
