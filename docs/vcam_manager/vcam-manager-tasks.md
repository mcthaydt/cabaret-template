# vCam Manager - Task Checklist

**Progress:** Documentation alignment complete; implementation not started.  
**Status note:** Checklist expanded to cover mobile drag-look and touchscreen input integration explicitly.

## Documentation Alignment

- [x] Align runtime wiring with actual root and gameplay scene structure
- [x] Split transient `vcam` observability from persisted silhouette settings
- [x] Correct blend, shake, and soft-zone architecture to match repo reality
- [x] Align file paths and naming with the current style guide
- [x] Make mobile drag-look a hard requirement for rotatable orbit and first-person support

## Phase 0: State and Persistence

- [ ] Commit 0.0: Extend `settings.input_settings.touchscreen_settings` and `RS_TouchscreenSettings` with persisted mobile drag-look settings (`look_drag_sensitivity`, `invert_look_y`) and patch the touchscreen settings overlay
- [ ] Commit 0.1: Extend `vfx` state with persisted `occlusion_silhouette_enabled` plus actions/reducer/selectors/tests
- [ ] Commit 0.2: Create `scripts/resources/state/rs_vcam_initial_state.gd`, `resources/state/cfg_default_vcam_initial_state.tres`, and tests
- [ ] Commit 0.3: Create `scripts/state/actions/u_vcam_actions.gd`, `scripts/state/reducers/u_vcam_reducer.gd`, and reducer tests
- [ ] Commit 0.4: Create `scripts/state/selectors/u_vcam_selectors.gd`; add `vcam_initial_state` export to `M_StateStore`; register `vcam` as transient in `U_StateSliceManager`; wire the resource in `scenes/root.tscn`

## Phase 1: Authoring Resources and Component

- [ ] Commit 1.1: Create vCam resources under `scripts/resources/display/vcam/` (`rs_vcam_mode_orbit.gd`, `rs_vcam_mode_fixed.gd`, `rs_vcam_mode_first_person.gd`, `rs_vcam_soft_zone.gd`, `rs_vcam_blend_hint.gd`) with unit tests
- [ ] Commit 1.2: Create `scripts/ecs/components/c_vcam_component.gd` with runtime yaw/pitch state and registration lifecycle tests
- [ ] Commit 1.3: Create default preset resources under `resources/display/vcam/` and update `scenes/templates/tmpl_camera.tscn` with the default `C_VCamComponent`

## Phase 2: Core Runtime and Scene Wiring

- [ ] Commit 2.1: Create `scripts/interfaces/i_vcam_manager.gd`
- [ ] Commit 2.2: Create `scripts/managers/m_vcam_manager.gd` with registration, active selection, blend state, Redux dispatches, and tests
- [ ] Commit 2.3: Create `scripts/managers/helpers/u_vcam_mode_evaluator.gd` and tests
- [ ] Commit 2.4: Create `scripts/ecs/systems/s_vcam_system.gd` that consumes gameplay `look_input`, evaluates active and outgoing cameras, and submits live results
- [ ] Commit 2.4a: Extend `UI_MobileControls`, `S_TouchscreenSystem`, and `S_InputSystem` so mobile drag-look dispatches shared `gameplay.look_input` without zero-clobber
- [ ] Commit 2.5: Add `M_VCamManager` to `scenes/root.tscn`, add `S_VCamSystem` to `scenes/templates/tmpl_base_scene.tscn`, and patch at least `scenes/gameplay/gameplay_base.tscn`

## Phase 3: Projection-Based Soft Zone

- [ ] Commit 3.1: Create `scripts/managers/helpers/u_vcam_soft_zone.gd` with projection/reprojection math and unit tests
- [ ] Commit 3.2: Integrate soft-zone correction into `s_vcam_system.gd` and cover viewport/depth edge cases

## Phase 4: Live Blend and Camera-Manager Integration

- [ ] Commit 4.1: Create `scripts/managers/helpers/u_vcam_blend_evaluator.gd` using live camera results and `RS_VCamBlendHint`
- [ ] Commit 4.2: Update `m_vcam_manager.gd` so outgoing and incoming vCams are both evaluated live during blends
- [ ] Commit 4.3: Extend `I_CameraManager`, `M_CameraManager`, and `MockCameraManager` with `apply_main_camera_transform(...)` and `is_blend_active()`
- [ ] Commit 4.4: Route vCam gameplay transforms through the new shake-safe camera-manager API and update `C_CameraStateComponent.base_fov`

## Phase 5: Occlusion and Silhouette

- [ ] Commit 5.1: Add physics layer 6 name `vcam_occludable` and create `u_vcam_collision_detector.gd`
- [ ] Commit 5.2: Ensure collision detection supports `GeometryInstance3D`, including `CSGShape3D`
- [ ] Commit 5.3: Create `u_vcam_silhouette_helper.gd` plus `assets/shaders/sh_vcam_silhouette_shader.gdshader`
- [ ] Commit 5.4: Integrate silhouettes with `m_vcam_manager.gd`, gate by `vfx.occlusion_silhouette_enabled`, and dispatch silhouette count updates

## Phase 6: Editor Preview

- [ ] Commit 6.1: Create `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd` following the `U_CinemaGradePreview` pattern
- [ ] Commit 6.2: Add the preview helper to `scenes/templates/tmpl_camera.tscn` and verify it frees itself at runtime

## Phase 7: Regression Coverage and Docs

- [ ] Commit 7.1: Add or update camera-manager regression tests for shake-safe gameplay transforms
- [ ] Commit 7.2: Update AGENTS and DEV_PITFALLS if implementation introduces stable new patterns or pitfalls
- [ ] Commit 7.3: Re-run and verify the vCam docs, then update the continuation prompt and task checklist with implementation status
- [ ] Commit 7.4: Run style enforcement and relevant GUT suites before merge

## Cross-Cutting Checks

- [ ] Verify `vcam` slice is whole-slice transient, not merely field-transient
- [ ] Verify no direct `camera.global_transform` writes remain in vCam code paths
- [ ] Verify moving-to-moving blends stay live instead of blending from a frozen origin transform
- [ ] Verify silhouettes restore cleanly on scene swap, vCam deactivation, and freed occluders
- [ ] Verify first-person and orbit look consume the existing input pipeline instead of polling raw input directly
- [ ] Verify mobile drag-look supports simultaneous move joystick + look touch + button presses without gesture conflicts
- [ ] Verify mobile drag-look settings persist through the existing touchscreen settings flow
- [ ] Verify `S_InputSystem` no longer overwrites touchscreen move/look input with zero payloads

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
