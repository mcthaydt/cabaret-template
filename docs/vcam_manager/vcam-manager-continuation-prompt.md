# vCam Manager - Continuation Prompt

## Current Focus

- **Feature / story**: Virtual Camera (vCam) Manager
- **Branch**: `vcam`
- **Status summary**: Phases 0A, 0A2, 0B, 0C, 0D, 0E, 0F, 1A, 1B, 1C, 1D, 1E, 1F, 2A, 2B, 4A, 4B, 5, 6A, 6B, 6A2, 6A.3, 6A3a, 6A3b, 6A3c, plus Phase 8 orbit subphases 2C1/2C2/2C3/2C4/2C5/2C6/2C7/2C8/2C9/2C10/2C11, the Orbit UX improvement follow-up pass, the Movement-Style Camera Smoothing follow-up pass, the Camera Look Smoothing Parity pass, the post-`0f51c36` orbit retune doc/test catch-up pass, the 2C8 input-consistency/icon-coverage follow-up, and the mobile drag-look/touch gating prerequisite work (Phase 7A/7B/7B2/7C) are complete as of March 15, 2026. Phase 3 reset is in progress: Phases 3A (`RS_VCamModeOTS` resource), 3B (OTS evaluator + default preset), 3C1 (OTS collision avoidance), 3C2 (OTS shoulder sway), and 3C3 (OTS landing camera response) are now complete (March 15, 2026); next target is Phase 3C4 OTS aiming behavior.

## Next Planned Work (March 15, 2026)

- Orbit follow-up backlog `2C11` is now complete in `docs/vcam_manager/vcam-orbit-tasks.md`.
- Mobile drag-look/touch gating prerequisites are complete in `docs/vcam_manager/vcam-base-tasks.md` (Phase 7A/7B/7B2/7C).
- Phase 3 reset: first-person camera mode replaced with RE4-style OTS (over-the-shoulder). Phase 9 game feel also reset for OTS-specific features.
- Phase 3C1 collision avoidance is now complete in `S_VCamSystem` with unit coverage and no-op regression gating.
- Phase 3C2 shoulder sway is now complete in `S_VCamSystem` with per-vCam sway dynamics state and OTS-only no-op gating coverage.
- Phase 3C3 landing camera response is now complete in `S_VCamSystem` with event-driven OTS distance compression and stacked shared-impact coverage.
- Immediate implementation target:
  - Phase 3C4: OTS aiming behavior in `S_VCamSystem` + movement/rotation/UI integrations (`docs/vcam_manager/vcam-ots-tasks.md`)

## OTS Mode Replacement (March 14, 2026)

- First-person camera mode (`RS_VCamModeFirstPerson`) replaced with RE4-style OTS (over-the-shoulder) camera (`RS_VCamModeOTS`).
- The OTS camera is "always aimed" — the default framing IS the tight shoulder view, no ADS toggle.
- Camera sits behind and to one side of the character with collision avoidance to prevent wall clipping.
- Phase 3 (resource + evaluator) and Phase 9 (game feel) are fully reset since the mode changes fundamentally.
- Previous first-person strafe tilt work is superseded by OTS shoulder sway (same concept, different context).
- See `docs/vcam_manager/vcam-ots-tasks.md` for complete task breakdown.

## OTS Mode Resource (Phase 3A, March 15, 2026)

- Added OTS mode resource:
  - `scripts/resources/display/vcam/rs_vcam_mode_ots.gd` (`RS_VCamModeOTS`)
- Authoring/runtime fields implemented:
  - `shoulder_offset`, `camera_distance`, `look_multiplier`, `pitch_min`, `pitch_max`, `fov`
  - `collision_probe_radius`, `collision_recovery_speed`
  - `shoulder_sway_angle`, `shoulder_sway_smoothing`
  - `landing_dip_distance`, `landing_dip_recovery_speed`
- `get_resolved_values()` now enforces OTS clamp/order contract:
  - `look_multiplier` resolves positive
  - `pitch_min`/`pitch_max` resolve ordered bounds
  - `fov` resolves into `1.0..179.0`
  - collision/landing recovery speeds resolve positive
  - distance/radius/sway/dip magnitudes resolve non-negative
- New coverage:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18` passing, includes default preset load contract + shoulder sway clamp)
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Mode Evaluator (Phase 3B, March 15, 2026)

- Added OTS evaluator branch in `U_VCamModeEvaluator`:
  - mode dispatch now handles `RS_VCamModeOTS`
  - OTS evaluation builds yaw/pitch basis, clamps pitch via resolved bounds, rotates shoulder offset by yaw, and positions camera with `basis.z * camera_distance`
  - returns `{transform, fov, mode_name = "ots"}` and remains null-target safe (`{}`) without warning-channel output
- Added `_resolve_ots_values(...)` fallback path to preserve evaluator behavior when resolved dictionaries are unavailable.
- Added default preset resource:
  - `resources/display/vcam/cfg_default_ots.tres`
- Expanded evaluator coverage:
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` now includes OTS transform/fov/mode-name, yaw/pitch application, pitch clamp/boundary, and null-target tests (`49/49` total).
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (`14/14`)
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (`49/49`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`17/17`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Collision Avoidance (Phase 3C1, March 15, 2026)

- Added OTS collision-avoidance pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_collision_avoidance(...)` runs after evaluator output and before downstream submission.
  - mode-gated to `RS_VCamModeOTS` (non-OTS modes are strict no-ops and clear stale collision state).
- Collision query/runtime contract implemented:
  - collision checks run against gameplay physics space via `follow_target.get_world_3d().direct_space_state`.
  - spherecast path uses `PhysicsDirectSpaceState3D.cast_motion(...)` with `collision_probe_radius`.
  - initial-overlap guard uses `intersect_shape(...)` (treat overlap as hit-distance `0.0`).
  - zero-radius fallback uses raycast.
  - on hit, distance clamps to `hit_distance - collision_probe_radius` with minimum distance floor (`0.1`).
- Recovery/runtime state implemented:
  - per-vCam `_ots_collision_state` tracks `follow_target_id`, `recovery_speed_hz`, `current_distance`, and reused `U_SecondOrderDynamics`.
  - recovery is smooth when obstruction clears; hit frames clamp immediately to avoid clipping.
  - stale-vCam prune and non-OTS paths clear collision state.
- New/updated coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - no-collision full-distance behavior
  - obstructed clamp behavior
  - probe-radius off-axis sensitivity behavior
  - minimum-distance floor behavior
  - smooth recovery-after-clear behavior
  - orbit/fixed no-op gating behavior
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`107/107`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`17/17`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Shoulder Sway (Phase 3C2, March 15, 2026)

- Added OTS shoulder-sway pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_shoulder_sway(...)` runs after evaluator output and before collision avoidance/response smoothing.
  - mode-gated to `RS_VCamModeOTS` (orbit/fixed/first-person modes are strict no-ops and clear stale sway state).
- Runtime sway contract implemented:
  - reads lateral intent from shared `input.move_input` (`move_input.x`) via `U_InputSelectors.get_move_input(...)`.
  - computes target roll as `move_input.x * shoulder_sway_angle` and clamps input to `[-1.0, 1.0]`.
  - smooths roll through per-vCam `U_SecondOrderDynamics` in `_shoulder_sway_state` keyed by `vcam_id`, with rebuild on smoothing changes.
  - applies roll on camera local forward axis (`basis.z`) and orthonormalizes resulting basis.
  - clears sway state on non-OTS mode, disabled angle (`0.0`), invalid transform payloads, and stale-vCam prune/clear paths.
- New/updated coverage:
  - `tests/unit/ecs/systems/test_vcam_system.gd`:
    - OTS sway disabled no-op
    - left/right strafe sign behavior
    - partial/full lateral-input scaling
    - authored max-angle bound
    - release-to-zero recovery
    - orbit/fixed no-op gating
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd`:
    - `shoulder_sway_angle` non-negative clamp behavior
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`115/115`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Landing Camera Response (Phase 3C3, March 15, 2026)

- Added OTS landing-response pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_landing_camera_response(...)` runs after response smoothing and before shared `landing_impact_offset` application.
  - mode-gated to `RS_VCamModeOTS` (non-OTS modes are strict no-ops and clear stale landing-response state).
- Event + runtime contract implemented:
  - `S_VCamSystem` now subscribes to `U_ECSEventNames.EVENT_ENTITY_LANDED` and extracts player-only landing payloads.
  - fall-speed normalization for OTS dip follows shared landing-impact thresholds (`5.0..30.0` -> `0.0..1.0`), supporting `fall_speed`, `vertical_velocity`, or `velocity.y` payloads.
  - per-vCam `_ots_landing_response_state` tracks `follow_target_id`, `recovery_speed_hz`, `current_offset`, `dynamics`, and `last_event_serial`.
  - on landing event, per-vCam dip triggers as `landing_dip_distance * normalized_fall_speed`; recovery runs through `U_SecondOrderDynamics` at `landing_dip_recovery_speed` toward zero.
  - distance compression is applied along OTS cast direction using the same shoulder-height cast origin contract as collision avoidance, with `OTS_MIN_CAMERA_DISTANCE` floor.
  - stale-vCam prune and non-OTS/disabled paths clear landing-response state.
- New/updated coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - disabled dip-distance no-op
  - landing-event distance compression
  - fall-speed scaling
  - smooth recovery toward authored distance
  - critically damped recovery (no distance overshoot above baseline)
  - stacking with shared landing-impact offset (distance + vertical dip)
  - orbit/fixed no-op gating
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`122/122`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Previous: First-Person Strafe Tilt (Phase 9 / 3C1, March 15, 2026) — SUPERSEDED

- _This section is retained for historical context. The first-person mode has been replaced with OTS._
- Added first-person authored strafe-tilt fields:
  - `RS_VCamModeFirstPerson` exported `strafe_tilt_angle` and `strafe_tilt_smoothing`.
  - `get_resolved_values()` clamped both fields non-negative.
- Runtime strafe-tilt integration:
  - `S_VCamSystem` now reads `move_input` via `U_InputSelectors.get_move_input(state)`.
  - Added first-person-only roll application after evaluator output and before downstream smoothing (`_apply_first_person_strafe_tilt(...)`).
  - Roll target is `move_input.x * strafe_tilt_angle`, smoothed with per-vCam `U_SecondOrderDynamics` state keyed by `vcam_id`.
  - Strafe-tilt state resets when mode is not first-person, when authored angle is disabled (`0.0`), and during stale-vCam prune/clear.
- New/updated coverage:
  - `test_vcam_mode_first_person` +3 tests for strafe-tilt defaults/clamp (`11/11` total).
  - `test_vcam_system` +7 tests for first-person strafe-tilt behavior (`101/101` total):
    - disabled-path no-op
    - left/right sign
    - partial/full input scaling
    - authored max-angle bound
    - release-to-zero recovery
    - orbit/fixed no-op gating
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd` (`11/11`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`101/101`)
  - `tests/unit/style/test_style_enforcement.gd` remains at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Mobile Drag-Look + Touch Gating (Phase 7A/7B/7B2/7C, March 15, 2026)

- Runtime input ownership updates:
  - `UI_MobileControls` now tracks dedicated free-screen drag-look touches and exposes `consume_look_delta()` + `is_touch_look_active()`.
  - `S_TouchscreenSystem` now dispatches `U_InputActions.update_look_input(...)` from touch drag deltas and updates component look action strength.
  - `S_TouchscreenSystem` now dispatches `U_GameplayActions.set_touch_look_active(...)` on gesture lifecycle transitions.
  - `S_InputSystem` now hard-gates active touchscreen ticks so touch-owned move/look/button state is not zero-clobbered by `TouchscreenSource`.
- State/store contract updates:
  - `gameplay.touch_look_active` added to `RS_GameplayInitialState`, `U_GameplayActions`, `U_GameplayReducer`, and `U_GameplaySelectors`.
  - `U_StateSliceManager` now marks `touch_look_active` transient in gameplay slice config.
- New/updated coverage:
  - `test_mobile_controls` (drag-look delta + consume lifecycle + sensitivity/invert)
  - `test_s_touchscreen_system` (look dispatch + sensitivity/invert + one-shot delta + active flag lifecycle)
  - `test_input_system` (touchscreen no-clobber guard + touch-look-active preservation)
  - `test_gameplay_slice_reducers`, `test_state_selectors`, `test_m_state_store` (flag reducer/selector/transient config coverage)
- Validation run:
  - `tests/unit/ui/test_mobile_controls.gd` (`14/14`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`7/7`)
  - `tests/unit/ecs/systems/test_input_system.gd` (`13/13`)
  - `tests/unit/state/test_gameplay_slice_reducers.gd` (`10/10`)
  - `tests/unit/state/test_state_selectors.gd` (`7/7`)
  - `tests/unit/state/test_m_state_store.gd` (`29/29`)
  - `tests/unit/state/test_state_persistence.gd` (`9/9`)
  - `tests/integration/state/test_state_persistence.gd` (`2/2`)
  - `tests/unit/state/test_action_registry.gd` (`14/14`)
  - `tests/unit/state/test_u_gameplay_actions.gd` (`7/7`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tests/unit/style/test_style_enforcement.gd` remains at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Camera Center Input Consistency + Icon Coverage (Follow-up, March 15, 2026)

- Default binding alignment:
  - `camera_center` default gamepad binding is now `JOY_BUTTON_RIGHT_STICK` (`R3`, index `8`) in `project.godot`, `cfg_default_gamepad.tres`, and `cfg_accessibility_gamepad.tres`.
  - `sprint` remains `JOY_BUTTON_LEFT_STICK` (`L3`, index `7`).
- Prompt/icon contract updates:
  - `U_ButtonPromptRegistry` now uses Godot joypad constants for label mapping (canonical `L3`/`R3`/`R1` behavior).
  - Added explicit `camera_center` prompt defaults: keyboard `key_c` glyph and gamepad `button_rs` (`R3`).
  - Gameplay prompts are now binding-aware: resolve icon from current `InputMap` event first, fallback to registry defaults second.
  - Added `KEY_C` texture support in `U_InputEventDisplay`.
- Touchscreen recenter input:
  - `UI_MobileControls` now supports empty-space double-tap recenter (`0.30s` max interval, `72px` max distance) and exposes one-shot `consume_camera_center_just_pressed()`.
  - `S_TouchscreenSystem` now dispatches `update_camera_center_state(...)` from this one-shot consume path instead of hardcoded `false`.
- New/updated coverage:
  - `test_u_button_prompt_registry` (constant mapping + camera-center icon defaults + binding-aware icon resolution)
  - `test_button_prompt` (live gamepad rebind icon tracking for `camera_center`)
  - `test_mobile_controls` (double-tap success/over-control reject/threshold reject + one-shot consume)
  - `test_s_touchscreen_system` (double-tap dispatches one-frame `camera_center_just_pressed`)
  - `test_m_input_profile_manager_reset` + `test_rs_input_profile` (default `camera_center=R3`, `sprint=L3`)
- Validation run:
  - `tests/unit/input_manager` (`102/102`)
  - `tests/unit/ui/test_button_prompt.gd` (`15/15`)
  - `tests/unit/ui/test_hud_button_prompts.gd` (`3/3`)
  - `tests/unit/ui/test_mobile_controls.gd` (`12/12`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`4/4`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tests/unit/managers/test_m_input_profile_manager_reset.gd` (`1/1`)
  - `tests/unit/resources/test_rs_input_profile.gd` (`8/8`)
  - `tests/unit/style/test_style_enforcement.gd` remains unchanged at known pre-existing HUD inline-theme failure (`16/17`).

## Orbit Room Fade Integration + Polish (Phase 2C11, March 15, 2026)

- Added integration coverage:
  - `tests/unit/ecs/systems/test_room_fade_integration.gd` (`7/7` passing)
- Integration coverage now verifies:
  - orbit-only gating (first-person/fixed no-op)
  - multi-group independence from authored normals
  - downward-normal ceiling fade behavior
  - one-tick mode-switch restore to opaque/original materials
  - coexistence with pre-existing silhouette-like shader overrides (restore-safe)
  - per-group custom-vs-default settings behavior
  - mesh + CSG full material restoration completeness
- Regression + compatibility validation run:
  - Room-fade suite aggregate (`test_room_fade*`): `48/48` passing
  - Orbit regressions: `test_vcam_system` (`94/94`) and `test_vcam_soft_zone` (`14/14`) passing
  - Silhouette settings integration proxy: `test_vfx_settings_ui` (`8/8`) passing
  - Renderer compatibility checks: `test_room_fade_integration` re-run with `--rendering-method mobile` and `--rendering-method gl_compatibility` (`7/7` each)
  - Style suite unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Room Fade Runtime (Phase 2C10, March 14, 2026)

- Added room-fade runtime/rendering stack:
  - `assets/shaders/sh_room_fade.gdshader`
  - `scripts/utils/lighting/u_room_fade_material_applier.gd`
  - `scripts/ecs/systems/s_room_fade_system.gd`
- Runtime contracts implemented:
  - `sh_room_fade.gdshader` uses `blend_mix` + `depth_draw_never` with room-fade uniforms (`fade_alpha`, `albedo_texture`, `albedo_color`) on the current transparency path (no alpha-scissor branch).
  - `U_RoomFadeMaterialApplier` caches/restores `material_override`, resolves source albedo (`material_override` -> surface override -> mesh surface), applies shader overrides, and updates per-target `fade_alpha`.
  - `S_RoomFadeSystem` runs as a standalone post-vCam system (`execution_priority = 110`), resolves camera from `camera_manager.get_main_camera()` with `Viewport.get_camera_3d()` fallback, gates to orbit via `state.vcam.active_mode`, computes fade using `dot(-camera_basis.z, wall_normal)`, and restores groups/materials immediately outside orbit mode.
- Added regression coverage:
  - `tests/unit/lighting/test_room_fade_material_applier.gd` (`6/6` passing)
  - `tests/unit/ecs/systems/test_room_fade_system.gd` (`15/15` passing)
- Validation run:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd` (`7/7` passing)
  - `tests/unit/ecs/components/test_room_fade_group_component.gd` (`11/11` passing)
  - `tests/unit/lighting/test_room_fade_material_applier.gd` (`6/6` passing)
  - `tests/unit/ecs/systems/test_room_fade_system.gd` (`15/15` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Room Fade Data Layer (Phase 2C9, March 14, 2026)

- Added room-fade data resource + component:
  - `scripts/resources/display/vcam/rs_room_fade_settings.gd`
  - `scripts/ecs/components/c_room_fade_group_component.gd`
  - `resources/display/vcam/cfg_default_room_fade.tres`
- Data-layer contracts implemented:
  - `RS_RoomFadeSettings` defaults (`fade_dot_threshold=0.3`, `fade_speed=4.0`, `min_alpha=0.05`) with clamp-safe `get_resolved_values()`.
  - `C_RoomFadeGroupComponent` exports (`group_tag`, `fade_normal`, nullable `settings`), runtime `current_alpha`, recursive mesh-target collection, parent-basis world-normal conversion, and snapshot reporting.
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd` (`7/7` passing)
  - `tests/unit/ecs/components/test_room_fade_group_component.gd` (`11/11` passing)
- Validation run:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd`
  - `tests/unit/ecs/components/test_room_fade_group_component.gd`
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Button Recenter (Phase 2C8, March 14, 2026)

- Added input action + pipeline wiring for button recenter:
  - Added `camera_center` in `project.godot` + `U_InputMapBootstrapper.REQUIRED_ACTIONS`.
  - Extended input-source capture contract with `camera_center_just_pressed`.
  - Added `U_InputActions.update_camera_center_state(...)`, reducer/selectors plumbing, and `S_InputSystem` dispatch path so recenter intent flows through the shared input pipeline.
  - Updated input profiles/rebind category/localization coverage for the new action.
- Patched `S_VCamSystem` orbit recenter flow:
  - Added per-vCam runtime centering state (`_orbit_centering_state`) keyed by `vcam_id`.
  - On `camera_center` trigger, computes behind-player runtime yaw target (authored-yaw compensated), then interpolates over `0.3s` using smoothstep.
  - While centering is active, manual look-driven rotation updates are suppressed.
  - Re-triggering `camera_center` mid-center restarts deterministically from the current runtime pose.
  - No idle/timer auto-center behavior added.
- Added regression coverage:
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +4 tests (`94/94` total) for start, interpolation completion, manual-look suppression, and deterministic restart.
  - Input/rebind coverage updates:
    - `tests/unit/input/test_input_map.gd`
    - `tests/unit/input_manager/test_u_input_actions.gd`
    - `tests/unit/input_manager/test_u_input_reducer.gd`
    - `tests/unit/input_manager/test_u_input_selectors.gd`
    - `tests/unit/ecs/systems/test_input_system.gd`
    - `tests/unit/ui/test_input_rebinding_overlay.gd`
    - `tests/unit/integration/test_rebinding_flow.gd`
- Validation run:
  - `tests/unit/input/test_input_map.gd`
  - `tests/unit/input_manager` (full directory)
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/ui/test_input_rebinding_overlay.gd`
  - `tests/unit/integration/test_rebinding_flow.gd`
  - `tests/unit/integration/test_input_manager_integration_points.gd`
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Input Release Smoothing (Phase 2C7, March 14, 2026)

- Extended `RS_VCamResponse` with orbit release-smoothing fields:
  - `look_release_yaw_damping`
  - `look_release_pitch_damping`
  - `look_release_stop_threshold`
  - `get_resolved_values()` now clamps all three fields to non-negative values.
- Patched `S_VCamSystem` orbit look-release path in `_resolve_runtime_rotation_for_evaluation(...)`:
  - reuses existing look-smoothing velocity state (`yaw_velocity` / `pitch_velocity`),
  - applies axis-specific release damping after input release,
  - clamps low-amplitude release velocities to zero via `look_release_stop_threshold`,
  - remains orbit-only (first-person/fixed behavior unchanged).
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`: +4 tests for new defaults/clamps (`24/24` total)
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +4 tests for deceleration, asymmetric damping, stop-threshold clamp/no-drift, and orbit-only gating (`86/86` total)
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`24/24` passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`86/86` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing failure in `scenes/ui/hud/ui_hud_overlay.tscn` inline theme overrides)

## Orbit Ground-Relative Positioning (Phase 2C6, March 11, 2026)

- Extended `RS_VCamResponse` with ground-relative tuning fields:
  - `ground_relative_enabled`
  - `ground_reanchor_min_height_delta`
  - `ground_probe_max_distance`
  - `ground_anchor_blend_hz`
  - `get_resolved_values()` now clamps ground-relative numeric fields to non-negative values.
- Patched `S_VCamSystem` with orbit-only ground-relative dual-anchor runtime state (`_ground_relative_state`) keyed by `vcam_id`:
  - resolves grounded state from gameplay/entity signals (`state.gameplay.entities[*].is_on_floor` first, then character/body fallback),
  - probes ground reference height only while grounded (bounded by `ground_probe_max_distance`),
  - keeps airborne vertical anchor locked (no per-frame Y chase while airborne),
  - re-anchors only on landing transitions meeting `ground_reanchor_min_height_delta`,
  - blends anchor updates with dedicated second-order dynamics using `ground_anchor_blend_hz`,
  - remains a strict no-op for non-orbit modes and when `ground_relative_enabled = false`.
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`: +5 tests for ground-relative defaults/clamps (`20/20` total)
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +6 tests for jump lock, airborne lock, minor/major landing behavior, uneven-terrain stability, and non-orbit no-op (`78/78` total)
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Orbit UX Improvement Pass (March 10, 2026)

- Added `S_VCamSystem` to `scenes/gameplay/gameplay_interior_house.tscn` and `scenes/gameplay/gameplay_exterior.tscn` under `Systems/Core` with `execution_priority = 100` so gameplay scene coverage now matches base/bar/alleyway wiring.
- Patched `S_VCamSystem` so the active vCam writes evaluated `fov` into the primary camera-state `base_fov` each tick (`1..179` clamp, missing/invalid value no-op).
- Retuned global defaults for a balanced locked-pitch orbit pass:
  - `cfg_default_orbit.tres`: `distance=9.0`, `authored_pitch=-24.0`, `lock_y_rotation=true`, `rotation_speed=1.6`, `fov=65.0`
  - `cfg_default_response.tres` (superseded by later post-`0f51c36` tuning): `follow=4.2/0.85/1.0`, `rotation=9.0/0.9/1.0`, `look_ahead_distance=0.5`, `look_ahead_smoothing=4.0`
  - `cfg_default_soft_zone.tres`: `dead_zone=0.18/0.16`, `soft_zone=0.55/0.48`, `damping=3.0`, `hysteresis_margin=0.03`
  - `U_InputReducer` gamepad defaults: `right_stick_deadzone=0.16`, `right_stick_sensitivity=1.15`, `deadzone_curve=1`
- Added regression coverage:
  - `test_vcam_system`: active vCam `fov` sync to `base_fov`, clamp behavior, and missing/invalid `fov` no-op
  - `test_entity_scene_registration`: asserts `S_VCamSystem` exists in exterior/interior scenes
  - `test_u_input_reducer`: asserts updated gamepad defaults
- Validation run (green):
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/input_manager/test_u_input_reducer.gd`
  - `tests/unit/ecs/test_entity_scene_registration.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Movement-Style Camera Smoothing Follow-up (March 10, 2026)

- Patched `S_VCamSystem` to keep `C_VCamComponent.runtime_yaw` / `runtime_pitch` as raw target values while feeding evaluator rotation through per-vCam look-smoothing state (`smoothed_yaw`, `smoothed_pitch`, `yaw_velocity`, `pitch_velocity`).
- Added movement-style spring-damper stepping for orbit/first-person look smoothing:
  - `accel = error * (omega^2) - velocity * (2 * damping * omega)`
  - per-axis velocity+angle integration each physics tick with large-`delta` guard.
- Added deterministic look-smoothing reset rules on mode changes, follow-target changes, response tuning changes, null-response passthrough paths, and per-vCam prune/clear cleanup.
- Prevented double-softness in rotation:
  - kept follow-position response smoothing unchanged,
  - made orbit/first-person look smoothing the rotation authority,
  - preserved fixed-mode rotation smoothing behavior.
- Expanded `tests/unit/ecs/systems/test_vcam_system.gd` with 6 follow-up tests:
  - raw runtime yaw/pitch remain immediate with response enabled,
  - first-frame large-look jump submits smoothed rotation,
  - rotation converges to raw evaluator pose,
  - reset behavior on mode switch, follow-target switch, and response change.
- Validation run (green):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, `62/62` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`15/15` passing)

## Camera Look Smoothing Parity Pass (March 10, 2026)

- Extended `RS_VCamResponse` with response-driven look feel controls:
  - `look_input_deadzone`, `look_input_hold_sec`, `look_input_release_decay`
  - `orbit_look_bypass_enable_speed`, `orbit_look_bypass_disable_speed` (disable speed clamped to `>=` enable speed)
- Retuned `resources/display/vcam/cfg_default_response.tres` to include conservative defaults for the new look filter and speed-aware orbit bypass fields.
- Patched `S_VCamSystem` with per-vCam look-input activity filtering state (`_look_input_filter_state`) that keeps bursty look streams active through a short hold/decay window for smoothing/gating decisions without adding extra runtime yaw/pitch accumulation.
- Added per-vCam follow-target motion sampling (`_follow_target_motion_state`) and replaced orbit's unconditional look-input bypass with speed-aware hysteresis gating:
  - stationary/slow targets keep the no-lag bypass behavior,
  - moving targets keep follow-position smoothing active while rotating.
- Expanded regression coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - first-person + orbit look-hold continuity checks (no extra runtime rotation),
  - look-release decay deactivation,
  - moving-target bypass disablement,
  - bypass hysteresis between enable/disable thresholds.
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`15/15` passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`70/70` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/16` passing)

## Post-0f51 Orbit Retune Doc/Test Catch-up (March 10, 2026)

- Synced continuation/overview/tasks docs with the current tuned orbit response baseline in `cfg_default_response.tres`:
  - `follow_frequency=3.8`, `follow_damping=1.0`
  - `rotation_frequency=4.8`, `rotation_damping=0.9`
  - `look_ahead_distance=0.02`, `look_ahead_smoothing=1.77`
  - `orbit_look_bypass_enable_speed=7.0`, `orbit_look_bypass_disable_speed=8.5`
- Added preset regression coverage in `tests/unit/resources/display/vcam/test_vcam_mode_presets.gd` for:
  - `cfg_default_response.tres` load/type contract (`RS_VCamResponse`)
  - tuned baseline value assertions for the fields above
- Added style-guard coverage in `tests/unit/style/test_style_enforcement.gd` to fail if authored scenes re-enable `debug_rotation_logging = true`.
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_mode_presets.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Phase 0 Progress (March 10, 2026)

- Completed Phase 0A:
  - Persisted touchscreen look settings (`look_drag_sensitivity`, `invert_look_y`) through reducer/serialization paths.
  - Patched `UI_TouchscreenSettingsOverlay` scene/controller for new controls, localization, and apply/reset flow.
  - Updated touchscreen settings resource defaults and unit/UI localization tests.
- Completed Phase 0A2:
  - Added dedicated `look_left/right/up/down` actions to InputMap bootstrap and keyboard profiles.
  - Added keyboard-look action/reducer/serialization plumbing in input settings.
  - Extended `KeyboardMouseSource` + `S_InputSystem` to emit keyboard-look through shared `gameplay.look_input`.
  - Added `UI_KeyboardMouseSettingsOverlay` + scene-registry/UI-registry wiring + settings-menu entrypoint.
  - Updated rebind action category/localization surface and added overlay/unit/integration tests.
- Completed Phase 0B:
  - Added persisted `vfx.occlusion_silhouette_enabled` defaults to `RS_VFXInitialState` and reducer state.
  - Added `U_VFXActions.set_occlusion_silhouette_enabled(...)` plus reducer/selectors/global-settings apply plumbing.
  - Wired silhouette toggle UI in `UI_VFXSettingsOverlay` scene/controller (apply/cancel/reset + focus/theme/localization/tooltips).
  - Added new VFX silhouette localization keys across all UI locale resources.
  - Updated VFX/state/unit/integration tests to cover silhouette state, UI behavior, and global-settings load path.
- Completed Phase 0C:
  - Added `scripts/resources/state/rs_vcam_initial_state.gd` with the full 11-field runtime observability contract (including `in_fov_zone`).
  - Added `resources/state/cfg_default_vcam_initial_state.tres` for upcoming state-store/root wiring.
  - Added `tests/unit/state/test_vcam_initial_state.gd` with 12 assertions covering default values and key count.
- Completed Phase 0D:
  - Added `scripts/state/actions/u_vcam_actions.gd` with 8 registered action creators (`set_active_runtime`, blend lifecycle, silhouette count, target validity, recovery reason, `update_fov_zone`).
  - Added `scripts/state/reducers/u_vcam_reducer.gd` with full state-default merge + action handling (`blend_progress` clamp, silhouette non-negative clamp, unknown action unchanged-state return).
  - Added vCam ECS event constants to `scripts/events/ecs/u_ecs_event_names.gd` (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`).
  - Added new tests `tests/unit/state/test_vcam_actions.gd` (8) and `tests/unit/state/test_vcam_reducer.gd` (13).
- Completed Phase 0E:
  - Added `scripts/state/selectors/u_vcam_selectors.gd` and `tests/unit/state/test_vcam_selectors.gd` (23 tests) for null-safe vCam runtime/selector access.
  - Wired `vcam_initial_state` export into `M_StateStore` and `U_StateSliceManager.initialize_slices(...)`.
  - Registered `vcam` in `U_StateSliceManager` with `is_transient = true` and reducer hookup to `U_VCamReducer`.
  - Patched `scenes/root.tscn` so `M_StateStore.vcam_initial_state` references `cfg_default_vcam_initial_state.tres`.
  - Added integration assertions proving `vcam` exists at runtime, is marked transient, is excluded from save payloads, and is excluded from global-settings serialization.
- Completed Phase 0F:
  - Patched `S_CameraStateSystem` to resolve FOV-zone state through `U_VCamSelectors.is_in_fov_zone(state)` instead of legacy `state.camera` reads.
  - Updated `resources/qb/camera/cfg_camera_zone_fov_rule.tres` to `state_path = "vcam.in_fov_zone"` so rule-driven FOV behavior matches migrated runtime state.
  - Updated QB camera unit/integration tests to seed `set_slice("vcam", {"in_fov_zone": ...})` and removed remaining non-doc `camera.in_fov_zone` references.
- Completed Phase 1A:
  - Added `RS_VCamSoftZone` (`scripts/resources/display/vcam/rs_vcam_soft_zone.gd`) with exported dead-zone/soft-zone dimensions and damping defaults.
  - Added `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd` (7 tests) for default values and bounds/order guards.
- Completed Phase 1B:
  - Added `RS_VCamBlendHint` (`scripts/resources/display/vcam/rs_vcam_blend_hint.gd`) with blend/tween fields and `is_instant_cut()` helper.
  - Added `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd` (7 tests) for defaults, non-negative constraints, and zero-duration cut semantics.
- Completed Phase 1C:
  - Added `resources/display/vcam/cfg_default_soft_zone.tres`.
  - Added `resources/display/vcam/cfg_default_blend_hint.tres`.
- Completed Phase 1D:
  - Added `scripts/utils/math/u_second_order_dynamics.gd` (`U_SecondOrderDynamics`) with semi-implicit integration, frequency clamp, large-`dt` guard, and finite-value fallback handling.
  - Added `tests/unit/utils/test_second_order_dynamics.gd` (13 tests) covering convergence, damping regimes, reset behavior, and response tuning.
- Completed Phase 1E:
  - Added `scripts/utils/math/u_second_order_dynamics_3d.gd` (`U_SecondOrderDynamics3D`) as a 3-axis wrapper over `U_SecondOrderDynamics`.
  - Added `tests/unit/utils/test_second_order_dynamics_3d.gd` (7 tests) covering vector convergence, axis independence, reset, and damping-regime behavior.
- Completed Phase 1F:
  - Added `scripts/resources/display/vcam/rs_vcam_response.gd` (`RS_VCamResponse`) with follow/rotation second-order tuning fields.
  - Added `tests/unit/resources/display/vcam/test_vcam_response.gd` (8 tests) covering defaults and resolved non-negative/positive clamp behavior.
  - Added `resources/display/vcam/cfg_default_response.tres` with Phase 1F defaults (`follow: 3.0/0.7/1.0`, `rotation: 4.0/1.0/1.0`).
- Completed Phase 2A:
  - Added `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` (`RS_VCamModeOrbit`) with authored orbit defaults (`distance`, `authored_pitch`, `authored_yaw`, `allow_player_rotation`, `lock_x_rotation`, `lock_y_rotation`, `rotation_speed`, `fov`) plus `get_resolved_values()` clamp/sanitation helper for deterministic runtime reads.
  - Added/expanded `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (14 tests) for defaults, baseline constraints, axis-lock defaults, and resolved-value safety behavior.
- Completed Phase 2B:
  - Added `scripts/managers/helpers/u_vcam_mode_evaluator.gd` (`U_VCamModeEvaluator`) with orbit-mode evaluation branch, resolved-value consumption, and null-safe invalid-input guards.
  - Added/expanded `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (14 orbit tests, 39 evaluator tests total) for transform/FOV/mode-name outputs, authored/runtime rotation behavior, and invalid-input handling.
  - Added `resources/display/vcam/cfg_default_orbit.tres` with baseline orbit defaults for scene/template wiring.
- Completed Legacy Phase 3A (Superseded):
  - Added `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd` (`RS_VCamModeFirstPerson`) with defaults (`head_offset`, `look_multiplier`, `pitch_min`, `pitch_max`, `fov`) and `get_resolved_values()` clamping/ordering helpers.
  - Added `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd` (8 tests) for defaults and resolved constraint behavior (`fov`, `look_multiplier`, pitch-bound ordering).
- Completed Legacy Phase 3B (Superseded):
  - Extended `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with first-person evaluation branch (position from `follow_target + head_offset`, yaw/pitch basis construction, in-evaluator pitch clamp, and null-safe guards).
  - Extended `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` with first-person coverage (10 new tests, 20 total evaluator tests).
  - Added `resources/display/vcam/cfg_default_first_person.tres` with baseline first-person defaults.
- Completed Phase 4A:
  - Added `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd` (`RS_VCamModeFixed`) with fixed-camera defaults (`use_world_anchor`, `track_target`, `fov`, `tracking_damping`, `follow_offset`, `use_path`, `path_max_speed`, `path_damping`) and `get_resolved_values()` clamp helpers.
  - Added `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd` (13 tests) for fixed resource defaults and resolved constraint behavior.
- Completed Phase 4B:
  - Extended `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with fixed evaluation branch (world-anchor mode, follow-offset mode, path mode, runtime yaw/pitch ignore contract, and null-safe guards).
  - Extended `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` with fixed coverage (15 new tests, 35 total evaluator tests).
  - Added `resources/display/vcam/cfg_default_fixed.tres` with baseline fixed defaults.
- Completed Phase 5:
  - Added `scripts/ecs/components/c_vcam_component.gd` (`C_VCamComponent`) with full authoring exports (`vcam_id`, priority/mode/paths, entity-id/tag follow fallbacks, soft-zone/blend/response resources, `is_active`), strict `RS_VCamResponse` export hint/guarding, and runtime orientation fields (`runtime_yaw`, `runtime_pitch`).
  - Added null-safe component getters (`get_follow_target`, `get_look_at_target`, `get_fixed_anchor`, `get_path_node`) plus `get_mode_name()` normalization for runtime observability/event payloads.
  - Added ServiceLocator-driven vCam-manager registration lifecycle in `C_VCamComponent` (`register_vcam` on ready/registration, `unregister_vcam` on exit) so persistent manager references are cleaned up on scene unload.
  - Added `scripts/interfaces/i_vcam_manager.gd` with the 8-method manager contract (`register/unregister`, active selection, blend observability, same-frame submission API).
  - Added `scripts/managers/m_vcam_manager.gd` with core registry, ServiceLocator registration, explicit-id and priority-based active selection, deterministic tie-break (`vcam_id` ascending), inactive-camera exclusion, re-selection on runtime state changes, and active-clear event correctness for unregister/pruned-active flows.
  - Added `M_VCamManager` observability/event integration:
    - Redux dispatch via `U_VCamActions.set_active_runtime(...)` (injection-first store lookup with ServiceLocator fallback).
    - ECS publish via `U_ECSEventBus.publish(U_ECSEventNames.EVENT_VCAM_ACTIVE_CHANGED, {...})`.
    - Same-frame handoff API stubbed via `submit_evaluated_camera(vcam_id, result)` for Phase 6 system integration.
  - Added Phase 5 tests:
    - `tests/unit/ecs/components/test_vcam_component.gd` (15 tests).
    - `tests/unit/managers/test_vcam_manager.gd` (22 tests: registration + active selection + clear/recovery transition + dispatch/event coverage).
- Completed Phase 6A:
  - Added `scripts/ecs/systems/s_vcam_system.gd` with ServiceLocator/injection lookup for `I_VCamManager`, Redux look-input consumption, orbit/first-person runtime angle updates, active/outgoing vCam evaluation during blends, and same-frame submission via `submit_evaluated_camera(...)`.
  - Implemented follow-target resolution priority in `S_VCamSystem`: `follow_target_path` -> `follow_target_entity_id` (`get_entity_by_id`) -> `follow_target_tag` (`get_entities_by_tag`) -> recovery.
  - Added gameplay-local fixed-path helper handling in `S_VCamSystem` (`PathFollow3D` under authored `Path3D`), including invalid-target recovery behavior that does not fabricate new path progress.
  - Added `tests/unit/ecs/systems/test_vcam_system.gd` with 17 tests covering the full Phase 6A contract.
  - Extended ECS manager interface/mocks with `get_entities_by_tag(...)` / `get_entities_by_tags(...)` for typed target-resolution queries in systems/tests.
- Completed Phase 6B:
  - Added `M_VCamManager` node to `scenes/root.tscn`.
  - Updated `scripts/root.gd` ServiceLocator bootstrap to register `vcam_manager` and declare `vcam_manager -> {state_store, camera_manager}` dependencies.
  - Added `S_VCamSystem` to `scenes/templates/tmpl_base_scene.tscn` and gameplay scene system trees (`scenes/gameplay/gameplay_base.tscn`, `scenes/gameplay/gameplay_bar.tscn`, `scenes/gameplay/gameplay_alleyway.tscn`) under `Systems/Core` with `execution_priority = 100` (after movement, before feedback).
  - Added default `C_VCamComponent` to `scenes/templates/tmpl_camera.tscn` with `cfg_default_orbit.tres` plus default soft-zone/blend/response resources and `follow_target_entity_id = &"player"`.
- Completed Phase 6A2:
  - Extended `scripts/ecs/systems/s_vcam_system.gd` with per-vCam response smoothing state: `U_SecondOrderDynamics3D` for position and per-axis `U_SecondOrderDynamics` for rotation.
  - Added `RS_VCamResponse` integration path in `S_VCamSystem` with null-response passthrough behavior (raw evaluator output when no response resource is assigned).
  - Added deterministic smoothing lifecycle rules: create-on-first-eval, recreate on response tuning change, reset on mode switch and follow-target switch.
  - Added Euler unwrapping for rotation smoothing targets to avoid long-path spins across angle wrap boundaries.
  - Expanded `tests/unit/ecs/systems/test_vcam_system.gd` from 17 to 25 tests with dedicated Phase 6A2 coverage.
- Completed Phase 6A.3:
  - Added 6 rotation-continuity tests to `tests/unit/ecs/systems/test_vcam_system.gd` covering orbit↔first-person carry/reset, orbit→fixed outgoing preservation, fixed→orbit authored reseed, and same-mode target-aware carry/reseed behavior.
  - Patched `S_VCamSystem` with active-vCam transition continuity policy hooks so runtime yaw/pitch apply carry/reset/reseed rules before evaluation on mode switches.
  - Added continuity helper rules for same-mode shared-target carry and authored-angle reseed fallback when follow targets differ.
- Completed Phase 6A3a:
  - Added `tests/unit/ecs/components/test_camera_state_component.gd` to cover landing-impact and speed-FOV component defaults/exports.
  - Extended `C_CameraStateComponent` with `landing_impact_offset`, `landing_impact_recovery_speed`, `speed_fov_bonus`, and `speed_fov_max_bonus`.
  - Extended `C_CameraStateComponent.reset_state()` and `get_snapshot()` so the new runtime fields are reset/snapshotted consistently for downstream systems.
- Completed Phase 6A3b:
  - Added `resources/qb/camera/cfg_camera_speed_fov_rule.tres` (`camera_speed_fov`) and registered it in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`.
  - Extended `S_CameraStateSystem` context building to expose primary movement-speed magnitude to QB camera rules through a `C_MovementComponent` component snapshot.
  - Patched `S_CameraStateSystem._resolve_target_fov()` to compose `base_target + clamp(speed_fov_bonus, 0.0, speed_fov_max_bonus)` and clamp/write back invalid bonus values.
  - Extended QB effect execution with winner-score context and added `RS_EffectSetField` score scaling (`scale_by_rule_score`) so speed-FOV rules can map normalized condition score to authored max bonus.
  - Expanded `tests/unit/qb/test_camera_state_system.gd` with 6 speed-FOV coverage tests and `tests/unit/qb/test_effect_set_field.gd` with score-scaling coverage.
- Completed Phase 6A3c:
  - Added `resources/qb/camera/cfg_camera_landing_impact_rule.tres` (`camera_landing_impact`) and registered it in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`.
  - Extended `RS_EffectSetField` with `vector3` literal support plus rule-score scaling for vector values, enabling score-scaled `landing_impact_offset` writes.
  - Patched `S_CameraStateSystem` event evaluation to prefilter event rules by subscribed event name before scoring, preventing cross-event side effects when score thresholds allow zero-score winners.
  - Added landing impact application/recovery in `S_VCamSystem`: reads `C_CameraStateComponent.landing_impact_offset`, applies offset to evaluated transforms, and recovers/writes back toward `Vector3.ZERO` via `U_SecondOrderDynamics3D` at `landing_impact_recovery_speed`.
  - Expanded tests in `tests/unit/qb/test_camera_state_system.gd`, `tests/unit/ecs/systems/test_vcam_system.gd`, and `tests/unit/qb/test_effect_set_field.gd` for landing-rule scaling and recovery behavior.
- Completed Phase 2C1:
  - Extended `RS_VCamResponse` with `look_ahead_distance` + `look_ahead_smoothing`, including non-negative resolved-value clamping.
  - Extended `S_VCamSystem` with orbit-only look-ahead state (`_look_ahead_state`) using movement velocity samples (`state.gameplay.entities[*].velocity` first, then movement-component/body fallback) and pre-smoothing position offsets before main response smoothing.
  - Added look-ahead coverage to `tests/unit/ecs/systems/test_vcam_system.gd` (disabled path, moving offset, clamp bound, stationary zero-offset, mode-switch clear, target-switch reset, first-person no-op, rotation-only target motion no-op).
  - Updated `resources/display/vcam/cfg_default_response.tres` with explicit defaults for look-ahead fields.
- Completed Phase 2C2:
  - Extended `RS_VCamResponse` with `auto_level_speed` + `auto_level_delay`, including non-negative resolved-value clamping.
  - Extended `S_VCamSystem` with orbit-only no-look timer tracking (`_orbit_no_look_input_timers`) and delayed pitch recentering via `move_toward(...)`.
  - Added auto-level coverage to `tests/unit/ecs/systems/test_vcam_system.gd` (disabled path, delayed decay, non-zero look suppression, timer reset, speed-rate behavior, first-person/fixed no-op).
- Completed Phase 2C3:
  - Added `scripts/managers/helpers/u_vcam_soft_zone.gd` (`U_VCamSoftZone`) with projection-based correction (`unproject_position`/`project_position`), near-plane guard, normalized-zone evaluation, damping-scaled soft-zone correction, and hard-zone clamping.
  - Added `tests/unit/managers/helpers/test_vcam_soft_zone.gd` baseline coverage for dead-zone no-op, soft/hard correction behavior, damping scaling, viewport/depth coverage, boundary direction correctness, null-disable behavior, and zero-dead/full-soft edge cases.
- Completed Phase 2C4:
  - Extended `RS_VCamSoftZone` with `hysteresis_margin` plus resolved-value clamping via `get_resolved_values()`.
  - Extended `U_VCamSoftZone` with optional per-axis hysteresis state handoff (`dead_zone_state`) and Schmitt-style thresholds (`exit = dead + margin`, `entry = dead - margin`).
  - Extended helper tests with hysteresis coverage for exit/entry thresholds, boundary oscillation stability, and `hysteresis_margin = 0.0` backward compatibility.
- Completed Phase 2C5:
  - Integrated orbit-only soft-zone correction into `S_VCamSystem` before response smoothing (`_apply_orbit_soft_zone(...)`) so second-order follow dynamics smooth the resulting corrected pose.
  - Added per-vCam dead-zone tracking in `S_VCamSystem` (`_soft_zone_dead_zone_state`) and stale-state pruning alongside existing vCam lifecycle cleanup.
  - Added `S_VCamSystem` regression tests for orbit correction enablement, missing soft-zone no-op, and first-person no-op gating.
- Validation run (green):
  - `tests/unit/input_manager/test_u_input_reducer.gd`
  - `tests/unit/input/test_input_map.gd`
  - `tests/unit/resources/test_rs_touchscreen_settings.gd`
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
  - `tests/unit/ui/test_input_rebinding_overlay.gd`
  - `tests/unit/ui/test_keyboard_mouse_settings_overlay.gd`
  - `tests/unit/integration/test_rebinding_flow.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0B):
  - `tests/unit/state/test_vfx_initial_state.gd`
  - `tests/unit/state/test_vfx_reducer.gd`
  - `tests/unit/state/test_vfx_selectors.gd`
  - `tests/unit/state/test_global_settings_persistence.gd`
  - `tests/integration/state/test_vfx_slice_integration.gd`
  - `tests/integration/vfx/test_vfx_settings_ui.gd`
  - `tests/unit/ui/test_vfx_settings_overlay_localization.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0C):
  - `tests/unit/state/test_vcam_initial_state.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0D):
  - `tests/unit/state/test_vcam_actions.gd`
  - `tests/unit/state/test_vcam_reducer.gd`
  - `tests/unit/state/test_action_registry.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0E):
  - `tests/unit/state/test_vcam_selectors.gd`
  - `tests/unit/state/test_m_state_store.gd`
  - `tests/unit/state/test_state_persistence.gd`
  - `tests/unit/state/test_global_settings_persistence.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0F):
  - `tests/unit/qb/test_camera_state_system.gd`
  - `tests/integration/qb/test_camera_shake_pipeline.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 1A/1B/1C):
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1D):
  - `tests/unit/utils/test_second_order_dynamics.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1E):
  - `tests/unit/utils/test_second_order_dynamics_3d.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1F):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 2A/2B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 3A/3B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 4A/4B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 5):
  - `tests/unit/ecs/components/test_vcam_component.gd`
  - `tests/unit/managers/test_vcam_manager.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 2A-5 gap-closure hardening):
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/ecs/components` (`-gselect=test_vcam_component`)
  - `tests/unit/managers` (`-gselect=test_vcam_manager`)
  - `tests/unit/style` (`-ginclude_subdirs=true`)
- Validation run (green, Phase 6A/6B):
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/managers/test_vcam_manager.gd`
  - `tests/unit/ecs/components/test_vcam_component.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 6A2):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 25/25 passing)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 6A.3):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 31/31 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3a):
  - `tests/unit/ecs/components/test_camera_state_component.gd` (`-gselect=test_camera_state_component`, 5/5 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 11/11 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3b):
  - `tests/unit/qb/test_effect_set_field.gd` (`-gselect=test_effect_set_field`, 7/7 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 16/16 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3c):
  - `tests/unit/qb/test_effect_set_field.gd` (`-gselect=test_effect_set_field`, 8/8 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 20/20 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 35/35 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C1/2C2):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`-gselect=test_vcam_response`, 11/11 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 48/48 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C3/2C4/2C5):
  - `tests/unit/managers/helpers/test_vcam_soft_zone.gd` (`-gselect=test_vcam_soft_zone`, 14/14 passing)
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd` (`-gselect=test_vcam_soft_zone`, 8/8 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 51/51 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C6):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`-gselect=test_vcam_response`, 20/20 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 78/78 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 17/17 passing)

## What Changed In The Docs

- Runtime wiring is now explicit: `M_VCamManager` belongs in `scenes/root.tscn`, and `S_VCamSystem` belongs in gameplay system trees.
- vCam top-level docs are now status-aligned: overview/PRD/task index/continuation now mark Phases 2A-5 plus 6A/6B/6A2/6A.3/6A3a/6A3b/6A3c and Phase 8 orbit feel/data/runtime subphases 2C1-2C11 complete.
- Orbit follow-up backlog planning is now explicit: `docs/vcam_manager/vcam-orbit-tasks.md` marks `2C11` complete, and mobile drag-look/touch gating prerequisites are now complete in `docs/vcam_manager/vcam-base-tasks.md` (Phase 7A/7B/7B2/7C).
- `S_VCamSystem` baseline contract is now implementation-backed: manager resolution, target resolution fallback order, blend-aware active/outgoing evaluation, and same-frame submission are in code/tests.
- `S_VCamSystem` response-smoothing contract is now implementation-backed: `RS_VCamResponse` drives position/rotation second-order smoothing, response-null passthrough keeps backward compatibility, and mode/target/response transitions reset or recreate smoothing state deterministically.
- `S_VCamSystem` movement-style look smoothing contract is now implementation-backed for orbit/OTS: runtime yaw/pitch remain raw targets on `C_VCamComponent`, evaluator rotation is fed by per-vCam spring-damper look state, and fixed-mode rotation smoothing remains owned by response smoothing.
- _`RS_VCamModeFirstPerson` strafe-tilt authoring contract was implementation-backed but is now superseded by OTS mode replacement (March 14, 2026)._
- _`S_VCamSystem` first-person strafe-tilt runtime contract was implementation-backed for Phase 9/3C1 but is now superseded by OTS shoulder sway (March 14, 2026)._
- `S_VCamSystem` OTS collision-avoidance contract is now implementation-backed for Phase 3C1: gameplay-world spherecast + initial-overlap guard, per-vCam collision distance state (`_ots_collision_state`), immediate hit clamping with minimum distance floor, smooth recovery via `U_SecondOrderDynamics`, and non-OTS/stale-vCam state cleanup.
- `S_VCamSystem` OTS shoulder-sway contract is now implementation-backed for Phase 3C2: reads shared `input.move_input.x`, applies OTS-only roll target (`move_input.x * shoulder_sway_angle`), smooths via per-vCam `U_SecondOrderDynamics` state (`_shoulder_sway_state`), and clears/reset state on non-OTS, disabled-angle, and stale-vCam prune paths.
- `S_VCamSystem` OTS landing-response contract is now implementation-backed for Phase 3C3: subscribes to `EVENT_ENTITY_LANDED`, normalizes player landing fall speed (`5..30`) to OTS dip strength, applies OTS-only distance compression via per-vCam `_ots_landing_response_state` (`U_SecondOrderDynamics`), stacks with shared `landing_impact_offset`, and clears/reset state on non-OTS/disabled/stale paths.
- `RS_VCamResponse` orbit-feel contract is now implementation-backed: `look_ahead_distance`, `look_ahead_smoothing`, `auto_level_speed`, and `auto_level_delay` are authored/clamped fields with defaults persisted in `cfg_default_response.tres`.
- `S_VCamSystem` rotation-continuity contract is now implementation-backed: active-vCam switches apply transition-aware carry/reset/reseed of `runtime_yaw`/`runtime_pitch`, with same-target carry in same-mode transitions and authored-angle reseed when targets differ.
- `S_VCamSystem` orbit game-feel contract is now implementation-backed for Phase 2C1-2C5: look-ahead offsets are applied before main response smoothing using per-vCam movement-velocity state (not follow-target transform deltas), auto-level pitch recentering is orbit-only with delayed activation and look-input reset behavior, and projection-based soft-zone correction (with per-vCam dead-zone hysteresis state) is applied before response smoothing.
- `S_VCamSystem` orbit ground-relative contract is now implementation-backed for Phase 2C6: per-vCam dual-anchor state (`follow` + `ground`) locks vertical anchor while airborne, uses grounded-only ground references bounded by `ground_probe_max_distance`, and only re-anchors on qualifying landings (`ground_reanchor_min_height_delta`) with dedicated anchor blending (`ground_anchor_blend_hz`).
- `U_VCamSoftZone` now defines the canonical projection/reprojection helper contract for orbit framing correction, including near-plane skip behavior and damping/hysteresis handling.
- `C_CameraStateComponent` now exposes landing-impact and speed-FOV fields required by the Phase 6A3 QB feel pipeline, and includes those fields in component reset/snapshot behavior.
- `S_CameraStateSystem` speed-FOV composition is now implementation-backed: movement-speed rule context, score-scaled `RS_EffectSetField` writes, and target-FOV composition/clamping now flow through the default `camera_speed_fov` QB rule.
- Runtime scene wiring is now landed in authored scenes: `M_VCamManager` in root, `S_VCamSystem` in template/gameplay system trees, and `C_VCamComponent` defaults in `tmpl_camera.tscn`.
- The `vcam` Redux slice is now defined as transient runtime observability only.
- The silhouette enable/disable toggle moved to the persisted `vfx` slice.
- VFX settings UI integration is now explicit: wire the silhouette toggle into `UI_VFXSettingsOverlay` (`scripts/ui/settings/ui_vfx_settings_overlay.gd` + `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`) and localize it in all `cfg_locale_*_ui.tres` files.
- The blend design now evaluates both outgoing and incoming cameras live during blends.
- The camera integration now requires a shake-safe `M_CameraManager.apply_main_camera_transform(...)` API instead of direct `camera.global_transform` writes.
- Soft-zone math is now defined as projection-based rather than basis-vector offset math.
- Soft-zone projection and occlusion raycasts are now explicitly tied to the active gameplay camera viewport and `World3D` inside `GameViewport`, not the root manager node's viewport/world.
- Mobile drag-look is now a hard requirement for rotatable orbit and OTS support.
- Mobile drag-look settings belong in `settings.input_settings.touchscreen_settings`, and the touch look path must extend `UI_MobileControls` plus `S_TouchscreenSystem`.
- `S_InputSystem` must be gated so it does not overwrite touchscreen gameplay input with zero `TouchscreenSource` payloads.
- Fixed-mode anchor ownership is now explicit: fixed cameras must resolve `C_VCamComponent.fixed_anchor_path` first, then fall back to a vCam host entity-root `Node3D`; never read component transform.
- Path-follow helpers for `use_path` stay scene-local in the gameplay world; do not parent them under the persistent root manager.
- Occlusion rollout is now explicit: naming layer 6 `vcam_occludable` is not enough; authored occluding geometry in gameplay/prefab scenes must be migrated to that layer.
- Stale test paths were corrected (`test_u_input_reducer.gd`, `test_input_system.gd`, `tests/integration/camera_system/test_camera_manager.gd`).
- ECS Event Bus integration added: `M_VCamManager` publishes lifecycle events (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`) through `U_ECSEventBus` so `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe to vCam state changes.
- vCam event constants are now added to `scripts/events/ecs/u_ecs_event_names.gd` following existing `EVENT_*` pattern.
- Entity-based target resolution added: `C_VCamComponent` supports `follow_target_entity_id` and `follow_target_tag` exports as fallbacks when NodePath is empty. `S_VCamSystem` resolves targets via `M_ECSManager.get_entity_by_id()` / `get_entities_by_tag()`, leveraging the existing `BaseECSEntity` ID/tag system. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- QB rule context enrichment: `S_CameraStateSystem._build_camera_context()` is extended with `vcam_active_mode`, `vcam_is_blending`, `vcam_active_vcam_id` so camera rules can condition on vCam state using standard `RS_ConditionContextField`.
- Per-phase doc cadence is now explicit and mandatory: update continuation prompt + tasks after each phase, and update AGENTS/DEV_PITFALLS when new stable contracts or pitfalls appear.
- Camera slice migration is complete: `S_CameraStateSystem`, default QB camera-zone rule config, and QB camera tests now use `state.vcam.in_fov_zone`; legacy runtime/test reads of `state.camera.in_fov_zone` are retired.
- Touch look gating now uses the top-level gameplay `touch_look_active` Redux flag, and the field is registered as transient so it does not persist through save/load or shell handoff.
- Keyboard-look scope is now complete: patch `U_InputMapBootstrapper`, `tests/unit/input/test_input_map.gd`, `U_GlobalSettingsSerialization`, `U_RebindActionListBuilder`, locale action keys, and a new `UI_KeyboardMouseSettingsOverlay` instead of treating the settings surface as optional.
- Same-frame camera apply is now explicit: `S_VCamSystem` submits the authoritative current-frame result, and `M_VCamManager` consumes that handoff instead of relying on root `_physics_process` order against gameplay ECS.
- Silhouette rendering routes through `M_VFXManager`: vCam publishes `EVENT_SILHOUETTE_UPDATE_REQUEST` with `{entity_id, occluders, enabled}`, VFX manager subscribes and delegates to `U_VCamSilhouetteHelper`. This is what lets existing player gating and transition blocking apply.
- Naming paths now follow the repo style guide:
  - `scripts/resources/display/vcam/`
  - `scripts/utils/display/`
  - `assets/shaders/sh_vcam_silhouette_shader.gdshader`
- Orbit mode baseline is now explicit:
  - `RS_VCamModeOrbit` is authored in `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` with default preset `resources/display/vcam/cfg_default_orbit.tres`.
  - `RS_VCamModeOrbit.get_resolved_values()` now provides canonical orbit clamp/sanitation reads (`distance`, `fov`, authored angles) and axis-lock flags (`lock_x_rotation`, `lock_y_rotation`).
  - `U_VCamModeEvaluator.evaluate(...)` now consumes orbit resolved values, returns `{transform, fov, mode_name}` for orbit resources, and returns `{}` for null/invalid inputs without warning noise.
- OTS baseline (replaces first-person, March 15, 2026):
  - `RS_VCamModeOTS` is now authored in `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`; `get_resolved_values()` is the canonical OTS clamp/order read path for evaluator/runtime consumers.
  - `U_VCamModeEvaluator.evaluate(...)` now includes the OTS branch and returns `{transform, fov, mode_name: "ots"}` with shoulder-offset rotation and evaluator-owned pitch clamping.
  - OTS game feel implementation status in `S_VCamSystem`: collision avoidance (3C1), shoulder sway (3C2), and landing camera response (3C3) complete; next target is OTS aiming behavior (3C4).
- Fixed baseline is now explicit:
  - `RS_VCamModeFixed` is authored in `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd` with default preset `resources/display/vcam/cfg_default_fixed.tres`.
  - `U_VCamModeEvaluator.evaluate(...)` now supports fixed world-anchor, follow-offset, and path branches while ignoring runtime yaw/pitch for fixed mode.
- Phase 5 component/interface/manager core is now explicit:
  - `C_VCamComponent` is authored in `scripts/ecs/components/c_vcam_component.gd` with mode/target/anchor/path/response exports and runtime yaw/pitch fields.
  - `I_VCamManager` (`scripts/interfaces/i_vcam_manager.gd`) defines the 8-method core manager API used by upcoming `S_VCamSystem`.
  - `M_VCamManager` (`scripts/managers/m_vcam_manager.gd`) now owns registration and active-vcam selection core.
- Active-selection runtime contract is now explicit:
  - Selection order is `set_active_vcam` explicit override first, then highest `priority`, then ascending `vcam_id` tie-break.
  - Components with `is_active = false` are excluded from selection and trigger reselection when active ownership changes.
  - Active changes publish both Redux observability (`vcam/set_active_runtime`) and ECS lifecycle events (`EVENT_VCAM_ACTIVE_CHANGED`), including clear transitions to empty active IDs when the active vCam is removed.

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
- `scripts/ecs/systems/s_vcam_system.gd`
- `scripts/ecs/systems/s_room_fade_system.gd`
- `scripts/input/u_input_map_bootstrapper.gd`
- `scripts/ecs/systems/s_camera_state_system.gd` (QB rule context, FOV composition, shake trauma)
- `scripts/ecs/components/c_camera_state_component.gd` (base_fov, target_fov, shake_trauma API)
- `scripts/events/ecs/u_ecs_event_bus.gd` (event subscription/publish pattern)
- `scripts/events/ecs/u_ecs_event_names.gd` (event constant pattern — vCam events added here)
- `scripts/utils/qb/u_rule_scorer.gd` (QB rule scoring for camera rules)
- `scripts/state/utils/u_state_slice_manager.gd`
- `scripts/utils/u_global_settings_serialization.gd`
- `scripts/utils/display/u_cinema_grade_preview.gd`
- `scripts/ui/helpers/u_rebind_action_list_builder.gd`
- `scripts/managers/m_vfx_manager.gd`
- `scripts/ui/hud/ui_mobile_controls.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `scripts/ui/overlays/ui_input_rebinding_overlay.gd`
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`
- `scripts/resources/input/rs_touchscreen_settings.gd`
- `scripts/utils/lighting/u_room_fade_material_applier.gd`
- `resources/localization/cfg_locale_en_ui.tres`
- `resources/localization/cfg_locale_es_ui.tres`
- `resources/localization/cfg_locale_ja_ui.tres`
- `resources/localization/cfg_locale_pt_ui.tres`
- `resources/localization/cfg_locale_zh_CN_ui.tres`
- `tests/unit/input_manager/test_u_input_reducer.gd`
- `tests/unit/input/test_input_map.gd`
- `tests/unit/ecs/systems/test_input_system.gd`
- `tests/unit/ecs/systems/test_vcam_system.gd`
- `tests/unit/ecs/systems/test_room_fade_system.gd`
- `tests/unit/ecs/systems/test_room_fade_integration.gd`
- `tests/unit/lighting/test_room_fade_material_applier.gd`
- `tests/unit/qb/test_camera_state_system.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
- `tests/unit/ui/test_input_rebinding_overlay.gd`
- `tests/integration/camera_system/test_camera_manager.gd`
- `scenes/root.tscn`
- `scenes/templates/tmpl_base_scene.tscn`
- `scenes/templates/tmpl_camera.tscn`
- `scenes/gameplay/gameplay_base.tscn`

## Next Steps

1. Continue Phase 3C OTS game feel (`docs/vcam_manager/vcam-ots-tasks.md`) with 3C4 OTS aiming behavior.
2. Preserve `S_VCamSystem` ordering (`execution_priority = 100`, after movement) and the same-frame handoff contract while extending continuity/recovery work.
3. During occlusion work, migrate authored occluding geometry to physics layer 6 in gameplay/prefab scenes; do not stop at `project.godot` layer naming.
4. After each completed phase, update continuation prompt + tasks immediately and commit docs separately from implementation.

## Key Decisions To Preserve

- vCam does not replace `M_CameraManager`.
- vCam does not replace `S_CameraStateSystem`.
- vCam does not bypass the gameplay input pipeline.
- OTS pitch clamp is evaluator-owned (`U_VCamModeEvaluator`), while OTS `look_multiplier` scaling remains system-owned (`S_VCamSystem`) to avoid double-scaling runtime angles.
- Keyboard look uses dedicated `look_*` actions (not `ui_*`) so bindings stay correct across input profiles; settings live in `mouse_settings`.
- Keyboard-look work is not complete unless the InputMap bootstrapper, input-map tests, rebind category/action labels, localization keys, and settings-save triggers are patched together.
- vCam does not treat mobile as special at the camera layer; touch look must still feed the shared `gameplay.look_input` path.
- vCam does not persist runtime slice state.
- vCam does not write `camera.fov` directly.
- vCam does not write `camera.global_transform` directly.
- vCam blends are live blends between two evaluated cameras, not frozen-transform lerps.
- `S_VCamSystem` response smoothing is per-vCam state keyed by `vcam_id` and must recreate/reset on response/mode/target transitions; null `response` must remain a raw-evaluator passthrough path.
- Orbit/OTS look smoothing uses a separate per-vCam spring-damper state keyed by `vcam_id`; `runtime_yaw`/`runtime_pitch` stay raw input targets while evaluator rotation consumes smoothed values.
- Soft-zone hysteresis state is per-vCam state keyed by `vcam_id` and should persist independently of response-smoothing resets (`_soft_zone_dead_zone_state` must not be cleared just because `response == null`).
- Orbit ground-relative anchoring is per-vCam state keyed by `vcam_id` (`_ground_relative_state`) and must only sample/update ground reference while grounded; airborne ticks must not overwrite anchor state.
- Fixed mode ignores player runtime look angles (`runtime_yaw`/`runtime_pitch`); path mode uses anchor/path tangent orientation and ignores `track_target`.
- fixed-mode world anchoring resolves from `fixed_anchor_path` first, then host entity-root `Node3D` fallback; not from component transform assumptions.
- vCam publishes lifecycle events through `U_ECSEventBus`, not just Redux — enabling reactive integration with QB rules and other systems.
- QB camera rules can condition on vCam state via enriched context fields (`vcam_active_mode`, `vcam_is_blending`) — no vCam-specific rule types needed.
- Follow target resolution uses existing entity ID/tag system as fallback when NodePaths are empty. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- The informal `camera` slice is retired for FOV-zone observability. `in_fov_zone` now lives in `state.vcam.in_fov_zone`; do not reintroduce `state.camera.in_fov_zone` reads.
- Touch input ownership is `S_TouchscreenSystem` when `active_device == TOUCHSCREEN`, with `gameplay.touch_look_active` used as transient observability/gating state for drag-look lifecycle.
- Projection math and occlusion raycasts use the active gameplay camera viewport/world inside `GameViewport`.
- Silhouette rendering lifecycle is owned by `M_VFXManager` (detection in vCam, rendering in VFX) via `{entity_id, occluders, enabled}` request payload. This follows the `U_ScreenShake` helper pattern.

## Known Risks

- shake layering can regress if the camera-manager integration is implemented with direct global-transform writes
- soft-zone math can drift if depth-aware reprojection is skipped
- silhouettes can leak on scene swap if the persistent manager keeps stale occluder references
- root/gameplay scene wiring can be missed if only templates are edited
- orbit/OTS can appear “done” on desktop while still being broken on mobile if `S_TouchscreenSystem` continues to dispatch zero look input
- touch-look can conflict with joystick/buttons if `UI_MobileControls` does not claim a dedicated free-screen look touch
- touch gameplay input can be silently overwritten if `S_InputSystem` continues processing `TouchscreenSource` zero payloads
- silhouette persistence can ship without user control if `UI_VFXSettingsOverlay` is not updated alongside state/actions/reducer/selectors
- keyboard look can appear implemented but still fail in runtime/profile/rebind flows if `U_InputMapBootstrapper`, `test_input_map.gd`, `U_RebindActionListBuilder`, locale keys, or save-trigger actions are left behind
- collision detector can appear correct in tests but fail in gameplay if authored occluding geometry is not migrated to layer 6 `vcam_occludable`
- gameplay camera math can pass isolated helper tests but still fail in live scenes if projection/raycast work accidentally uses the persistent root manager's viewport/world instead of the gameplay `SubViewport`
- same-frame camera application can hitch or lag a frame if implementation relies on root `_physics_process` tree order instead of the explicit `S_VCamSystem` -> `M_VCamManager` handoff
- **orientation continuity**: mode switches can cause disorienting heading jumps if rotation carry/reseed policy regresses in `S_VCamSystem` (see overview Rotation Continuity Contract)
- **reentrant blend**: a second `set_active_vcam()` during an active blend can pop or wedge blend state if mid-blend interruption semantics are not implemented
- **invalid target recovery**: freed follow targets or fixed anchors during gameplay can produce NaN transforms or crashes if per-tick validity checks are missing
- **tag ambiguity**: `follow_target_tag` can silently retarget the camera after scene-authoring changes unless multiple-match behavior is defined and warned
- **path recovery**: `use_path` cameras can drift or jump if path progress keeps advancing after the follow target becomes invalid
- **silhouette flicker**: occluders on marginal ray boundaries can cause per-frame material churn without debounce/hysteresis logic in `U_VCamSilhouetteHelper`
- **performance**: per-frame dictionary allocations in blend evaluation, soft-zone, and occlusion can cause frame-pacing regressions on mobile without reuse patterns
- silhouette color/opacity configurability is deferred to post-v1 (ship with single authored shader values)
- orbit zoom behavior is deferred to post-v1 (static authored distance for v1)

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Tasks](vcam-manager-tasks.md)
