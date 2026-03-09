# vCam Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.6)  
**Status**: Documentation remediated with gap patching, implementation not started  
**Methodology**: Test-driven, integration-first where scene wiring matters

## Overview

This plan replaces the original draft where it diverged from repo reality.

The corrected implementation contract is:

- `M_VCamManager` is a persistent root manager under `scenes/root.tscn/Managers`.
- `S_VCamSystem` is a gameplay ECS system under `Systems/Core`.
- `C_VCamComponent` remains the authoring surface for virtual cameras in gameplay scenes.
- Mobile drag-look is a hard requirement for `allow_player_rotation` orbit cameras and first-person cameras.
- The `vcam` Redux slice is transient runtime observability only.
- The player-facing silhouette toggle lives in the persisted `vfx` slice, not `vcam`.
- `M_CameraManager` keeps ownership of scene-transition blends and shake layering.
- vCam must not write `camera.global_transform` directly; that would fight `M_CameraManager`'s `ShakeParent` hierarchy.
- Soft-zone correction is projection-based. It cannot be implemented by converting normalized screen offsets straight into world-space basis vectors.
- During vCam-to-vCam blends, both the outgoing and incoming cameras are evaluated live every tick so moving cameras blend correctly.
- New vCam resources live under `scripts/resources/display/vcam/` and the editor preview lives under `scripts/utils/display/`, which fits the current style guide and style-enforcement rules without inventing new categories.
- Mobile camera look must extend the existing `UI_MobileControls` + `S_TouchscreenSystem` + `settings.input_settings.touchscreen_settings` path instead of creating a vCam-specific touch-input stack.

## Runtime Wiring

The original docs missed the runtime integration points. The implementation must wire all of these:

- Add `M_VCamManager` to `scenes/root.tscn` under `Managers`.
- Extend `scripts/state/m_state_store.gd` with `@export var vcam_initial_state: RS_VCamInitialState`.
- Assign the new `vcam_initial_state` resource in `scenes/root.tscn`.
- Reuse the existing root `MobileControls` instance in `scenes/root.tscn`; do not add a second mobile camera-controls layer.
- Add `S_VCamSystem` under `Systems/Core` in `scenes/templates/tmpl_base_scene.tscn`.
- Update already-authored gameplay scenes that do not automatically inherit the new system tree yet, at minimum `scenes/gameplay/gameplay_base.tscn`.
- Extend `scenes/templates/tmpl_camera.tscn` with a default `C_VCamComponent`.
- Add the editor-only rule-of-thirds preview node to `tmpl_camera.tscn` only after the preview helper exists.

## Documentation Cadence (Mandatory)

After every completed phase, update docs immediately so written guidance matches implementation state:

- update `docs/vcam_manager/vcam-manager-continuation-prompt.md`
- update `docs/vcam_manager/vcam-manager-tasks.md` with `[x]` marks and completion notes
- update `AGENTS.md` when stable architecture/pattern contracts change
- update `docs/general/DEV_PITFALLS.md` for new pitfalls discovered during implementation
- commit documentation updates separately from implementation commits

## Phase 0: State and Persistence

### Commit 0.0: Touchscreen drag-look settings prerequisite

**Files to modify**

- `scripts/resources/input/rs_touchscreen_settings.gd`
- `resources/input/touchscreen_settings/cfg_default_touchscreen_settings.tres`
- `scripts/state/reducers/u_input_reducer.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `tests/unit/input_manager/test_u_input_reducer.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay.gd`

**Behavior**

- Extend `settings.input_settings.touchscreen_settings` with persisted mobile look settings:
  - `look_drag_sensitivity: float = 1.0`
  - `invert_look_y: bool = false`
- Keep these settings in the existing input-settings domain. Do not add vCam-specific copies.
- Extend the touchscreen settings overlay so mobile users can tune drag-look without entering a separate camera settings flow.

**Why**

- Mobile drag-look is part of the input system, not the vCam runtime.
- Orbit and first-person cameras are not truly complete on mobile until drag-look settings exist.

### Commit 0.1: Persisted silhouette toggle in VFX settings

**Files to modify**

- `scripts/resources/state/rs_vfx_initial_state.gd`
- `scripts/state/actions/u_vfx_actions.gd`
- `scripts/state/reducers/u_vfx_reducer.gd`
- `scripts/state/selectors/u_vfx_selectors.gd`
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`
- `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`
- `resources/localization/cfg_locale_en_ui.tres`
- `resources/localization/cfg_locale_es_ui.tres`
- `resources/localization/cfg_locale_ja_ui.tres`
- `resources/localization/cfg_locale_pt_ui.tres`
- `resources/localization/cfg_locale_zh_CN_ui.tres`
- `tests/unit/state/test_vfx_initial_state.gd`
- `tests/unit/state/test_vfx_reducer.gd`
- `tests/unit/state/test_vfx_selectors.gd`
- `tests/unit/ui/test_vfx_settings_overlay_localization.gd`
- `tests/unit/ui/test_vfx_settings_overlay.gd` (create if missing)

**Behavior**

- Add `occlusion_silhouette_enabled: bool = true` to the `vfx` slice.
- Persist it through the existing global-settings pipeline automatically via the `vfx` slice.
- Use the existing action shape conventions: `StringName` action constants, `payload`, and `U_ActionRegistry`.
- Expose the toggle in the VFX settings overlay (Apply/Cancel + Reset flows) so players can actually control the persisted field.
- Add localization label/tooltip keys for the new toggle across all supported UI locale resources.

**Why**

- `U_GlobalSettingsSerialization.build_settings_from_state(...)` already persists the full `vfx` slice.
- Putting this toggle in `vcam` would incorrectly persist transient runtime state alongside observability.

### Commit 0.2: vCam initial state resource

**Files to create**

- `scripts/resources/state/rs_vcam_initial_state.gd`
- `resources/state/cfg_default_vcam_initial_state.tres`
- `tests/unit/state/test_vcam_initial_state.gd`

**Initial state**

```gdscript
func to_dictionary() -> Dictionary:
	return {
		"active_vcam_id": &"",
		"active_mode": "",
		"previous_vcam_id": &"",
		"blend_progress": 1.0,
		"is_blending": false,
		"silhouette_active_count": 0,
		"blend_from_vcam_id": &"",
		"blend_to_vcam_id": &"",
		"active_target_valid": true,
		"last_recovery_reason": "",
	}
```

**Contract**

- This slice is runtime-only observability for debugging and UI.
- It is not save data and not a player settings surface.

### Commit 0.3: vCam actions and reducer

**Files to create**

- `scripts/state/actions/u_vcam_actions.gd`
- `scripts/state/reducers/u_vcam_reducer.gd`
- `tests/unit/state/test_vcam_reducer.gd`

**Actions**

- `vcam/set_active_runtime`
- `vcam/start_blend`
- `vcam/update_blend`
- `vcam/complete_blend`
- `vcam/update_silhouette_count`

**ECS Event Constants**

Extend `scripts/events/ecs/u_ecs_event_names.gd` with vCam lifecycle event constants:

- `EVENT_VCAM_ACTIVE_CHANGED` — published when active vCam selection changes
- `EVENT_VCAM_BLEND_STARTED` — published when a vCam-to-vCam blend begins
- `EVENT_VCAM_BLEND_COMPLETED` — published when a blend finishes or cuts
- `EVENT_VCAM_RECOVERY` — published when the recovery policy activates (target freed, anchor invalid)

These follow the existing `EVENT_*` naming pattern and are published through `U_ECSEventBus` so `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe.

**Reducer behavior**

- `set_active_runtime`: updates `active_vcam_id` and `active_mode`
- `start_blend`: sets `is_blending = true`, `blend_progress = 0.0`, `previous_vcam_id`, `blend_from_vcam_id`, `blend_to_vcam_id`
- `update_blend`: clamps `progress` to `0.0..1.0`
- `complete_blend`: clears `previous_vcam_id`, `blend_from_vcam_id`, `blend_to_vcam_id`, resets `blend_progress = 1.0`
- `update_silhouette_count`: stores a non-negative count
- `update_target_validity`: sets `active_target_valid`
- `record_recovery`: sets `last_recovery_reason`

### Commit 0.4: selectors, store export, and transient slice registration

**Files to create**

- `scripts/state/selectors/u_vcam_selectors.gd`
- `tests/unit/state/test_vcam_selectors.gd`

**Files to modify**

- `scripts/state/m_state_store.gd`
- `scripts/state/utils/u_state_slice_manager.gd`
- `scenes/root.tscn`

**Contract**

- Register `vcam` as `is_transient = true`.
- Do not mix persisted fields into the slice.
- Keep selector behavior null-safe and slice-safe, matching current repo patterns.

**Tests**

- selectors return sane defaults with missing slice data
- store can initialize with the new resource export
- slice registration marks `vcam` transient

## Phase 1: Authoring Resources and Component

### Commit 1.1: Camera mode resources

**Files to create**

- `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`
- `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
- `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`
- `scripts/resources/display/vcam/rs_vcam_soft_zone.gd`
- `scripts/resources/display/vcam/rs_vcam_blend_hint.gd`
- `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
- `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
- `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
- `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
- `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`

**Resource notes**

- `RS_VCamModeOrbit`
  - owns authored distance/pitch/yaw
  - uses `rotation_speed` when `allow_player_rotation = true`
- `RS_VCamModeFixed`
  - fixed world anchor, optional target tracking
  - `follow_offset: Vector3 = Vector3(0, 3, 5)` — consumed only when `use_world_anchor = false`
  - When `use_world_anchor = false`, camera positions at `follow_target.global_position + follow_offset`
  - `use_path: bool = false` — when true, camera follows a `Path3D`; `use_world_anchor` and `follow_offset` are ignored
  - `path_max_speed: float = 10.0` — max travel speed along the path (units/sec), 0.0 = instant
  - `path_damping: float = 5.0` — second-order smoothing for path progress changes
- `RS_VCamModeFirstPerson`
  - use `look_multiplier`, not `mouse_sensitivity`
  - input already arrives pre-scaled from the input pipeline
- `RS_VCamSoftZone`
  - dead-zone, soft-zone, damping values only
- `RS_VCamBlendHint`
  - `blend_duration`
  - `ease_type`
  - `trans_type` (e.g. `Tween.TRANS_CUBIC`)
  - `cut_on_distance_threshold`

**Rationale for `look_multiplier`**

- `S_InputSystem` already dispatches scaled `look_input` through the gameplay slice.
- `S_TouchscreenSystem` must dispatch the same `look_input` field for mobile drag-look.
- Reusing the name `mouse_sensitivity` inside the vCam resource would blur the line between global input settings and per-vCam authored behavior.

### Commit 1.2: `C_VCamComponent`

**Files to create**

- `scripts/ecs/components/c_vcam_component.gd`
- `tests/unit/ecs/components/test_vcam_component.gd`

**Component contract**

- extends `BaseECSComponent`
- exports:
  - `vcam_id: StringName`
  - `priority: int`
  - `mode: Resource`
  - `fixed_anchor_path: NodePath`
  - `follow_target_path: NodePath`
  - `follow_target_entity_id: StringName` — entity ID fallback for dynamic target resolution via `M_ECSManager.get_entity_by_id()`
  - `follow_target_tag: StringName` — tag fallback for target resolution via `M_ECSManager.get_entities_by_tag()`
  - `look_at_target_path: NodePath`
  - `path_node_path: NodePath` — resolved to `Path3D` by `S_VCamSystem` for path-following fixed cameras
  - `soft_zone: Resource`
  - `blend_hint: Resource`
  - `is_active: bool`
- runtime-only state:
  - `runtime_yaw`
  - `runtime_pitch`

**Behavior**

- Resolve follow/look targets with null-safe typed getters.
- Target resolution priority (applied by `S_VCamSystem`): `follow_target_path` NodePath → `follow_target_entity_id` via `M_ECSManager.get_entity_by_id()` → `follow_target_tag` via `M_ECSManager.get_entities_by_tag()` → null (triggers recovery). This leverages the existing `BaseECSEntity` ID and tag system for dynamic target assignment.
- Register with `M_VCamManager` on readiness/registration.
- Unregister on `_exit_tree()` so the persistent manager never keeps dead scene references.

### Commit 1.3: Default presets and template camera

**Files to create**

- `resources/display/vcam/cfg_default_orbit.tres`
- `resources/display/vcam/cfg_default_soft_zone.tres`
- `resources/display/vcam/cfg_default_blend_hint.tres`

**Files to modify**

- `scenes/templates/tmpl_camera.tscn`

**Template result**

- Default player-follow vCam is authored on `E_CameraRoot/Components/C_VCamComponent`.
- The template remains backward compatible with the existing `E_PlayerCamera` and `C_CameraStateComponent`.

## Phase 2: Core Runtime and Scene Wiring

### Commit 2.1: `I_VCamManager`

**Files to create**

- `scripts/interfaces/i_vcam_manager.gd`

**Interface methods**

- `register_vcam(vcam: C_VCamComponent) -> void`
- `unregister_vcam(vcam: C_VCamComponent) -> void`
- `set_active_vcam(vcam_id: StringName, blend_duration: float = -1.0) -> void`
- `get_active_vcam_id() -> StringName`
- `get_previous_vcam_id() -> StringName`
- `submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void`
- `get_blend_progress() -> float`
- `is_blending() -> bool`

### Commit 2.2: `M_VCamManager`

**Files to create**

- `scripts/managers/m_vcam_manager.gd`
- `tests/unit/managers/test_vcam_manager.gd`

**Manager responsibilities**

- register/unregister `C_VCamComponent` instances
- resolve the active vCam by:
  - explicit override if set
  - otherwise highest `priority`
  - tie-break by `vcam_id` ascending
- maintain blend state:
  - `active_vcam_id`
  - `previous_vcam_id`
  - `blend_elapsed`
  - `blend_duration`
  - `blend_hint`
- own collision and silhouette helpers
- dispatch Redux observability updates (`U_VCamActions` → `vcam` slice)
- publish ECS lifecycle events through `U_ECSEventBus` (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`)
- clear runtime state and silhouettes when gameplay scenes unload or all cameras unregister

**Dependency pattern**

- Prefer injection-first for tests.
- Fall back to `U_ServiceLocator` for:
  - `camera_manager`
  - `state_store`
  - `ecs_manager`

### Commit 2.3: `U_VCamModeEvaluator`

**Files to create**

- `scripts/managers/helpers/u_vcam_mode_evaluator.gd`
- `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`

**Contract**

- Accepts a mode resource plus resolved targets, a resolved fixed-anchor `Node3D`, and rotation state.
- Returns a dictionary with:
  - `transform`
  - `fov`
  - `mode_name`
- Null and invalid-resource cases return `{}` without warning-channel noise.
- If the follow target or fixed anchor is an invalid (freed) object reference, return `{}` immediately without crashing.
- Fixed-mode `use_world_anchor = true` reads world transform from `C_VCamComponent.fixed_anchor_path` when authored; otherwise falls back to vCam host entity root. It must not read transform from `C_VCamComponent` (which extends `Node`).
- Fixed-mode `use_world_anchor = false` positions at `follow_target.global_position + mode.follow_offset`. Returns `{}` if follow target is null. `track_target` still applies; `runtime_yaw`/`runtime_pitch` still ignored.
- Fixed-mode `use_path = true`: evaluator treats this as `use_world_anchor = true` + `track_target = false` (the path-resolved `PathFollow3D` is passed as `fixed_anchor` by `S_VCamSystem`). Returns `{}` if `fixed_anchor` is null.

### Commit 2.4: `S_VCamSystem`

**Files to create**

- `scripts/ecs/systems/s_vcam_system.gd`
- `tests/unit/ecs/systems/test_vcam_system.gd`

**System responsibilities**

- resolve `I_VCamManager`
- read gameplay look input from Redux via the existing input pipeline (`gameplay.look_input`)
- resolve follow targets using `C_VCamComponent` NodePath exports first; fall back to entity queries (`M_ECSManager.get_entity_by_id()` or `get_entities_by_tag()`) when NodePaths are empty — enables dynamic target assignment (e.g., follow the entity tagged `"player"`)
- evaluate the active vCam every tick
- when a blend is active, also evaluate the outgoing vCam every tick
- resolve a `Node3D` fixed anchor for each vCam (`fixed_anchor_path` when set, entity root default otherwise) before mode evaluation
- for path-enabled fixed vCams (`use_path = true`):
  - resolve `Path3D` from `C_VCamComponent.path_node_path`
  - maintain a `PathFollow3D` child per path-enabled vCam
  - each tick: compute closest point on curve to follow target, smooth progress via `path_max_speed` + `path_damping`, update `PathFollow3D.progress`
  - pass the `PathFollow3D` as `fixed_anchor` to evaluator
- update `runtime_yaw` and `runtime_pitch` on the component that owns the rotation context
- apply rotation continuity policy on mode switches (see overview Rotation Continuity Contract): carry, reset, or reseed yaw/pitch based on mode transition type
- validate follow target and fixed anchor before evaluation each tick; dispatch `update_target_validity` and `record_recovery` on state changes
- submit evaluated results back to `M_VCamManager`

**Input contract**

- Read `look_input` from the gameplay slice rather than polling input directly.
- Orbit mode:
  - when `allow_player_rotation = true`, update yaw/pitch using `rotation_speed * delta`
- First-person mode:
  - update yaw/pitch using `look_multiplier`
- The system consumes the already-scaled `look_input` values produced by `S_InputSystem`, `keyboard_mouse_source.gd`, `gamepad_source.gd`, and touchscreen drag-look once `S_TouchscreenSystem` is extended.

### Commit 2.4a: Mobile drag-look plumbing

**Files to modify**

- `scripts/ui/hud/ui_mobile_controls.gd`
- `scripts/ecs/systems/s_touchscreen_system.gd`
- `scripts/ecs/systems/s_input_system.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `tests/unit/ecs/systems/test_s_touchscreen_system.gd`
- `tests/unit/ecs/systems/test_input_system.gd`
- `tests/unit/ui/test_mobile_controls.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay.gd`

**Behavior**

- `UI_MobileControls` tracks one dedicated look touch id in addition to joystick and button touches.
- A touch that begins on the joystick or on a virtual button stays owned by that control.
- A touch that begins elsewhere becomes a drag-look gesture.
- `UI_MobileControls` exposes per-frame `look_delta`.
- `S_TouchscreenSystem` dispatches `U_InputActions.update_look_input(look_delta)` and updates look action strength instead of hard-coding `look_input` and look strength to zero.
- Apply persisted `look_drag_sensitivity` and `invert_look_y` from `settings.input_settings.touchscreen_settings`.
- Clear mobile look delta after each dispatch so state remains delta-based like mouse and right-stick input.
- `S_InputSystem` must not overwrite touchscreen gameplay input with `TouchscreenSource.capture_input()` zeros. When the active device type is touchscreen, gameplay move/look/jump/sprint dispatch for touch input is owned by `S_TouchscreenSystem`.

**Tests**

- drag-look dispatches non-zero `look_input`
- move + look work simultaneously on separate touches
- pressing a virtual button does not create drag-look
- releasing the look touch clears subsequent deltas
- touchscreen settings overlay updates the new look settings fields
- `S_InputSystem` does not clobber touchscreen `look_input` or `move_input` with zero payloads

**Why**

- The current touchscreen path only drives move/jump/sprint.
- Rotatable orbit and first-person cameras are blocked on mobile until touch drag-look feeds the shared `gameplay.look_input` path.

### Commit 2.5: Scene wiring

**Files to modify**

- `scenes/root.tscn`
- `scenes/templates/tmpl_base_scene.tscn`
- `scenes/gameplay/gameplay_base.tscn`

**Required wiring**

- add `M_VCamManager` under root `Managers`
- add `S_VCamSystem` under gameplay `Systems/Core`
- keep `M_VCamManager` persistent across gameplay scene swaps
- ensure already-authored gameplay scenes receive the new system until template propagation is complete

## Phase 3: Projection-Based Soft Zone

### Commit 3.1: `U_VCamSoftZone`

**Files to create**

- `scripts/managers/helpers/u_vcam_soft_zone.gd`
- `tests/unit/managers/helpers/test_vcam_soft_zone.gd`

**Corrected contract**

The helper must work in projected screen space and reproject back to world space at the tracked depth.

**Recommended signature**

```gdscript
static func compute_camera_correction(
	camera: Camera3D,
	follow_world_pos: Vector3,
	desired_transform: Transform3D,
	soft_zone: RS_VCamSoftZone,
	delta: float
) -> Vector3
```

**Algorithm**

1. Temporarily reason about the desired camera pose.
2. Project the follow target into viewport coordinates.
3. Convert to normalized screen coordinates for dead/soft/hard zone tests.
4. Clamp toward the nearest allowed point inside the configured zone.
5. Reproject that corrected screen point back into world space at the same camera-space depth.
6. Return the world-space camera correction vector needed to preserve framing.

**Performance notes**

- Avoid allocating new `Vector2`/`Vector3` temporaries each call; reuse locals.
- Skip the projection step entirely when no soft zone resource is assigned.
- Cache viewport size per frame rather than querying it per-vCam.

**Why the original draft was wrong**

- It assumed `target_screen_pos` existed without defining the world-to-screen projection step.
- It converted normalized screen offsets directly into `camera.basis.x/y` world units, which ignores depth, viewport size, and FOV.

### Commit 3.2: Soft-zone integration

**Files to modify**

- `scripts/ecs/systems/s_vcam_system.gd`

**Tests**

- dead zone produces no correction
- soft zone produces damped correction
- hard zone clamps target back inside the viewport boundary
- same behavior holds across multiple viewport sizes and target depths

## Phase 4: Live Blend Evaluation and Camera Manager Integration

### Commit 4.1: `U_VCamBlendEvaluator`

**Files to create**

- `scripts/managers/helpers/u_vcam_blend_evaluator.gd`
- `tests/unit/managers/helpers/test_vcam_blend_evaluator.gd`

**Contract**

- Blend between two fully evaluated camera results, not between one live result and one frozen transform.
- Respect `RS_VCamBlendHint.ease_type`.
- Respect `cut_on_distance_threshold`.

**Blend inputs**

- `from_result`
- `to_result`
- `hint`
- `progress`

### Commit 4.2: Live blend state in `M_VCamManager`

**Files to modify**

- `scripts/managers/m_vcam_manager.gd`
- `tests/unit/managers/test_vcam_manager.gd`

**Correct behavior**

- `set_active_vcam(...)` starts a blend between vCam IDs, not between cached transforms.
- During the blend, `S_VCamSystem` continues evaluating both cameras each frame.
- `M_VCamManager` blends the two live results in `_physics_process`.
- If the blend hint says to cut, skip interpolation and complete immediately.

**Reentrant switch (mid-blend interruption)**

- If `set_active_vcam(...)` is called while a blend is already active, snapshot the current blended pose as the new "from" pose, reset blend progress to `0.0`, and target the newly requested vCam.
- The old outgoing vCam stops being evaluated; only the snapshot and the new incoming vCam are live.
- `previous_vcam_id` updates to reflect the interrupted blend's source.

**Invalid vCam during blend**

- If the outgoing vCam becomes invalid (freed): complete the blend immediately (cut to incoming result).
- If the incoming vCam becomes invalid (freed): cancel the blend, hold the outgoing pose, trigger priority reselection.
- If both are freed: hold the last valid blended pose, clear blend state, dispatch `record_recovery("blend_both_invalid")`.

**Performance notes**

- Reuse the blend result dictionary across frames instead of allocating a new one each tick.
- Skip blend evaluation entirely when `blend_progress >= 1.0`.

### Commit 4.3: Shake-safe integration with `M_CameraManager`

**Files to modify**

- `scripts/interfaces/i_camera_manager.gd`
- `scripts/managers/m_camera_manager.gd`
- `tests/mocks/mock_camera_manager.gd`
- `tests/integration/camera_system/test_camera_manager.gd`
- `tests/unit/managers/test_vcam_manager.gd`

**New camera-manager API**

- `apply_main_camera_transform(xform: Transform3D) -> void`
- `is_blend_active() -> bool`

**Why this API is required**

- `M_CameraManager` may wrap the active scene camera in a `ShakeParent`.
- Writing `camera.global_transform` directly from vCam would cancel or distort active shake offsets.
- `M_CameraManager.apply_main_camera_transform(...)` can preserve the shake hierarchy while updating the base pose.

**vCam apply flow**

1. If `camera_manager.is_blend_active()` is true, suspend all vCam transform writes.
2. Otherwise, pass the blended or unblended result into `camera_manager.apply_main_camera_transform(...)`.
3. Update `C_CameraStateComponent.base_fov` with the vCam-authored FOV (use `set_base_fov()` setter which clamps to valid range).
4. Let `S_CameraStateSystem` remain the sole writer of `camera.fov`.

**QB rule context enrichment**

After vCam state is dispatched to Redux, `S_CameraStateSystem` can read vCam fields from the `vcam` slice when building its rule evaluation context. Enrich the camera context with:

- `vcam_active_mode` — enables rules like "reduce FOV zone effect during first-person mode"
- `vcam_is_blending` — enables rules like "suppress shake during camera blends"
- `vcam_active_vcam_id` — enables per-vCam rule targeting

This requires modifying `S_CameraStateSystem._build_camera_context()` to read from the `vcam` slice via `U_VCamSelectors`. Camera rules remain authored in `.tres` files using the standard `RS_Rule` + condition/effect pattern — no vCam-specific rule engine is needed.

## Phase 5: Occlusion and Silhouette

### Commit 5.1: `U_VCamCollisionDetector`

**Files to create**

- `scripts/managers/helpers/u_vcam_collision_detector.gd`
- `tests/unit/managers/helpers/test_vcam_collision_detector.gd`

**Files to modify**

- `project.godot`

**Contract**

- Name physics layer 6 `vcam_occludable`.
- Detect `GeometryInstance3D` occluders, not only `MeshInstance3D`.
- Support the geometry types already used heavily in this repo, especially `CSGBox3D`.

**Tests**

- empty result when nothing hits
- mesh occluder detected
- CSG occluder detected
- invalid or freed collider skipped safely

### Commit 5.1a: Occluder layer rollout in authored scenes

**Files to modify**

- `scenes/gameplay/gameplay_base.tscn`
- any gameplay/prefab scenes with geometry expected to occlude camera-to-target line of sight in vCam flows

**Contract**

- layer-name setup in `project.godot` is only schema; authored geometry must also be assigned to layer 6 `vcam_occludable`
- only true camera blockers belong on this layer; triggers/zones stay on their existing layers

**Validation**

- add or extend tests proving wrong-layer colliders are ignored and migrated colliders are detected
- run style/scene-organization gates after scene edits

### Commit 5.2: `U_VCamSilhouetteHelper`

**Files to create**

- `scripts/managers/helpers/u_vcam_silhouette_helper.gd`
- `assets/shaders/sh_vcam_silhouette_shader.gdshader`
- `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd`

**Contract**

- Apply silhouette overrides to `GeometryInstance3D`.
- Preserve and restore original override state cleanly.
- Track active count for Redux observability.
- Implement anti-flicker behavior:
  - Maintain a stable occluder set; only add an occluder after it has been detected for 2 consecutive frames.
  - Grace-frame removal: keep silhouette for 2 frames after the occluder leaves the ray before restoring the original material.
  - When the occluder set is unchanged from the previous frame, skip material override application entirely (no per-frame churn).
  - Avoid material/shader instance allocation when applying the same override to the same node.

### Commit 5.3: Per-tick occlusion integration

**Files to modify**

- `scripts/managers/m_vcam_manager.gd`
- `tests/unit/managers/test_vcam_manager.gd`

**Behavior**

- detect occluders between follow target and final camera pose
- consult `U_VFXSelectors.is_occlusion_silhouette_enabled(state)`
- apply silhouettes only when the persisted VFX toggle is enabled
- dispatch `U_VCamActions.update_silhouette_count(...)` on count changes
- clear all silhouettes when gameplay ends, no active vCam exists, or scene transition ownership changes
- validate follow target is still valid before occlusion detection each tick; skip detection if target is invalid

**Performance notes**

- Reuse the occluder result array across frames instead of allocating a new one each tick.
- Skip occlusion detection entirely when silhouettes are disabled or no active vCam exists.
- Do not reapply material overrides when the stable occluder set is unchanged from the previous frame.

## Phase 6: Editor Preview

### Commit 6.1: Rule-of-thirds preview helper

**Files to create**

- `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`

**Files to modify**

- `scenes/templates/tmpl_camera.tscn`

**Pattern**

- Follow `U_CinemaGradePreview`.
- `@tool`
- extend `Node`
- create and manage a `CanvasLayer` and drawing node internally
- `queue_free()` outside the editor so runtime cost stays zero

**Why**

- This fits the existing display-preview pattern already present in the repo.
- It avoids inventing a new `scripts/tools` category and avoids extra style-test work.

## Phase 7: Polish, Docs, and Regression Coverage

### Commit 7.1: Optional observability enrichment

**Optional**

- If implementation benefits from it, add `vcam_id` to `C_CameraStateComponent` snapshots for debugging only.
- Do not make this a prerequisite for the core feature.

### Commit 7.2: Documentation and project guidance

**Files to modify**

- `docs/vcam_manager/vcam-manager-overview.md`
- `docs/vcam_manager/vcam-manager-prd.md`
- `docs/vcam_manager/vcam-manager-tasks.md`
- `docs/vcam_manager/vcam-manager-continuation-prompt.md`
- `AGENTS.md` if new architectural patterns prove stable
- `docs/general/DEV_PITFALLS.md` if implementation discovers new camera-specific pitfalls

### Commit 7.3: Test gates

**Run at minimum**

- relevant new unit suites
- camera-manager regression tests
- touchscreen/mobile control regression tests for drag-look
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style`

## Common Pitfalls

1. Do not register only the component and forget the runtime scene wiring. `M_VCamManager` in root plus `S_VCamSystem` in gameplay are both required.
2. Do not persist the `vcam` slice. It is transient runtime observability.
3. Do not store the silhouette toggle in `vcam`. Persist it in `vfx`.
4. Do not write `camera.global_transform` directly from vCam. Go through `M_CameraManager.apply_main_camera_transform(...)` so shake layering survives.
5. Do not freeze the outgoing camera transform at blend start. Evaluate both cameras live during blends.
6. Do not use raw normalized-screen deltas as world-space camera offsets. Soft-zone math must account for depth and projection.
7. Do not bypass the existing input pipeline. Consume `gameplay.look_input` produced by `S_InputSystem` and touchscreen drag-look once `S_TouchscreenSystem` is extended.
8. Do not treat mobile as automatically covered by that input contract. `S_TouchscreenSystem` currently hard-codes look input to zero, so mobile drag-look must be implemented explicitly.
9. Do not rely on scene-tree order to “fix” mobile touch input. `S_InputSystem` currently resolves `TouchscreenSource`, which returns zeros, so it must be explicitly gated from overwriting touchscreen gameplay input.
10. Do not introduce `scripts/tools` or `assets/shaders/vcam_*.gdshader` paths that fight the current style guide. Use `scripts/utils/display/` and `sh_*_shader.gdshader`.
11. Do not assume occluders are only `MeshInstance3D`. Current gameplay scenes use `CSGBox3D` extensively.
12. Do not forget to update `tests/mocks/mock_camera_manager.gd` when `I_CameraManager` grows new methods.
13. Do not stop at state wiring for `occlusion_silhouette_enabled`; wire it into `UI_VFXSettingsOverlay` and localization resources so players can control it.
14. Do not assume naming physics layer 6 is enough; migrate authored occluder geometry to that layer in scenes/prefabs.

## File Structure

```text
scripts/managers/
  m_vcam_manager.gd
  helpers/
    u_vcam_mode_evaluator.gd
    u_vcam_soft_zone.gd
    u_vcam_blend_evaluator.gd
    u_vcam_collision_detector.gd
    u_vcam_silhouette_helper.gd

scripts/interfaces/
  i_vcam_manager.gd

scripts/ecs/components/
  c_vcam_component.gd

scripts/ecs/systems/
  s_vcam_system.gd

scripts/resources/display/vcam/
  rs_vcam_mode_orbit.gd
  rs_vcam_mode_fixed.gd
  rs_vcam_mode_first_person.gd
  rs_vcam_soft_zone.gd
  rs_vcam_blend_hint.gd

scripts/resources/state/
  rs_vcam_initial_state.gd

scripts/state/actions/
  u_vcam_actions.gd

scripts/state/reducers/
  u_vcam_reducer.gd

scripts/state/selectors/
  u_vcam_selectors.gd

scripts/utils/display/
  u_vcam_rule_of_thirds_preview.gd

assets/shaders/
  sh_vcam_silhouette_shader.gdshader

resources/state/
  cfg_default_vcam_initial_state.tres

resources/display/vcam/
  cfg_default_orbit.tres
  cfg_default_soft_zone.tres
  cfg_default_blend_hint.tres

tests/unit/
  state/
    test_vcam_initial_state.gd
    test_vcam_reducer.gd
    test_vcam_selectors.gd
  ecs/components/
    test_vcam_component.gd
  ecs/systems/
    test_vcam_system.gd
  resources/display/vcam/
    test_vcam_mode_orbit.gd
    test_vcam_mode_fixed.gd
    test_vcam_mode_first_person.gd
    test_vcam_soft_zone.gd
    test_vcam_blend_hint.gd
  managers/
    test_vcam_manager.gd
    helpers/
      test_vcam_mode_evaluator.gd
      test_vcam_soft_zone.gd
      test_vcam_blend_evaluator.gd
      test_vcam_collision_detector.gd
      test_vcam_silhouette_helper.gd
```

## References

- [vCam Manager PRD](vcam-manager-prd.md)
- [vCam Manager Overview](vcam-manager-overview.md)
- [vCam Manager Tasks](vcam-manager-tasks.md)
- [VFX Manager Plan](../vfx_manager/vfx-manager-plan.md)

**End of vCam Manager Plan**
