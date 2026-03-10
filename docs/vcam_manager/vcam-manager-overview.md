# vCam Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-06
**Updated**: 2026-03-10
**Status**: Phases 0A-0F + 1A-1F + 2A-2B + 3A-3B + 4A-4B + 5 + 6A + 6B + 6A2 + 6A.3 complete (state/persistence + base authoring resources + dynamics + response tuning + mode resource/evaluator baselines + component/interface/manager core + `S_VCamSystem` baseline + runtime scene wiring + response-driven second-order smoothing integration + rotation continuity policy/tests); Phase 6A3a next

## Summary

The vCam Manager is a gameplay camera orchestration layer inspired by Cinemachine. It adds virtual-camera authoring and selection on top of the current camera stack without replacing the existing low-level camera manager or QB camera-state systems.

For this feature to be complete, player-controlled orbit and first-person camera behavior must also work on mobile through drag-look, not only on mouse and gamepad.

This overview mixes implemented phase contracts and upcoming phase planning. Completed phases above are reflected in code/tests; later phases remain implementation targets.

The corrected stack is:

```text
Gameplay input and camera authorship
        |
        v
S_InputSystem / S_TouchscreenSystem -> gameplay.look_input
        |
        v
S_VCamSystem + C_VCamComponent + vCam mode resources
        |
        v
M_VCamManager
        |
        v
M_CameraManager + C_CameraStateComponent + S_CameraStateSystem
```

`M_VCamManager` chooses which virtual camera should drive gameplay, owns live vCam-to-vCam blend state, detects occluders, routes silhouette requests through VFX, and publishes runtime observability into Redux. `M_CameraManager` still owns scene-transition blending and shake layering. `S_CameraStateSystem` still owns the final `camera.fov` write.

## Repo Reality Checks

- `scenes/root.tscn` is the persistent app root. Long-lived managers live there.
- Gameplay scenes own their own `M_ECSManager`.
- `S_InputSystem` already captures `look_input` and dispatches it into the gameplay slice.
- `S_TouchscreenSystem` currently handles move/jump/sprint only and hard-codes look strength to `0.0`, so mobile drag-look is still a required dependency for vCam parity.
- `M_CameraManager` is already registered in `U_ServiceLocator` as `camera_manager`.
- `M_CameraManager` may insert a `ShakeParent` above the active camera to apply screen shake.
- Because of that `ShakeParent`, vCam must not write `camera.global_transform` directly.
- `C_CameraStateComponent` and `S_CameraStateSystem` already exist and already own FOV composition and shake-trauma behavior.
- `U_GlobalSettingsSerialization` already persists the `vfx` slice, so player-facing silhouette enablement belongs there.
- `UI_VFXSettingsOverlay` already exists (`scripts/ui/settings/ui_vfx_settings_overlay.gd`) and now includes a persisted silhouette toggle row (`vfx.occlusion_silhouette_enabled`) with localization coverage.
- `settings.input_settings.touchscreen_settings` is already the persisted home for mobile control tuning, so drag-look sensitivity and invert-Y belong there, not in `vcam`.
- Existing gameplay scenes use both `MeshInstance3D` and `CSGBox3D`-style geometry, so occlusion logic cannot assume mesh-only scene content.
- Phase 0F completed the FOV-zone migration: `S_CameraStateSystem`, default camera-zone QB rule config, and QB camera tests now read `state.vcam.in_fov_zone`.
- `scripts/input/u_input_map_bootstrapper.gd`, `tests/unit/input/test_input_map.gd`, and the UI locale action labels now include the `look_*` action family for keyboard-look flows; rebind camera categorization should stay aligned to `look_*` as the canonical camera action names.
- Gameplay runs inside `scenes/root.tscn/GameViewportContainer/GameViewport`. Soft-zone projection and occlusion raycasts must use that active gameplay viewport and `World3D`, never the root manager node's viewport/world.

## Runtime Wiring

These nodes and files are required for the feature to exist at runtime:

- `scenes/root.tscn`
  - add `M_VCamManager` under `Managers`
  - assign `vcam_initial_state` on `M_StateStore`
- `scenes/templates/tmpl_base_scene.tscn`
  - add `S_VCamSystem` under `Systems/Core`
- `scenes/gameplay/gameplay_base.tscn`
  - update concrete system tree until template propagation covers it
- `scenes/templates/tmpl_camera.tscn`
  - add the default `C_VCamComponent`
  - later add the editor-only rule-of-thirds preview node
- `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`
  - add a silhouette enable/disable control bound to the `vfx` slice (`occlusion_silhouette_enabled`)
  - localize new label/tooltip keys across `resources/localization/cfg_locale_*_ui.tres`

Updating only `tmpl_camera.tscn` is not enough.

## Goals

- Support orbit, fixed, and first-person virtual camera modes.
- Support soft-zone follow behavior with dead-zone and damping.
- Blend smoothly between virtual cameras.
- Handle occluders with silhouettes instead of dolly push-in.
- Provide an editor-only rule-of-thirds preview.
- Expose active camera runtime state through a transient Redux slice.
- Support mobile drag-look for rotatable orbit and first-person cameras.
- Fit the existing scene-manager, state-store, and camera-manager architecture cleanly.

## Non-Goals

- Replacing `M_CameraManager`
- Replacing `S_CameraStateSystem`
- Replacing the existing input pipeline
- Dolly or push-in collision response
- Cinematic timeline tooling
- Split-screen or multi-viewport support
- 2D cameras

## Responsibilities and Boundaries

### `M_VCamManager`

Owns:

- registration and lifetime of active `C_VCamComponent` instances
- active vCam selection
- vCam blend state
- Redux `vcam` observability updates
- occlusion detection and silhouette request publication to `M_VFXManager`
- final handoff of gameplay transform data into `M_CameraManager`

Does not own:

- scene-transition blends
- shake layering
- direct final `camera.fov` writes

### `S_VCamSystem`

Owns:

- reading current `look_input` from Redux (`gameplay.look_input` from `S_InputSystem` / `S_TouchscreenSystem`)
- evaluating the active vCam every physics tick
- evaluating the outgoing vCam as well when a blend is active
- updating `runtime_yaw` and `runtime_pitch` on the correct component
- applying soft-zone correction before results are submitted
- resolving follow targets using entity queries (`M_ECSManager.get_entity_by_id()`, `get_entities_by_tag()`) as fallback when `C_VCamComponent` NodePath exports are empty
- resolving `follow_target_tag` deterministically when multiple entities match: first valid ECS-registration-order match, plus a debug warning recommending `follow_target_entity_id` when deterministic targeting matters
- owning any `PathFollow3D` helper state for `use_path` fixed cameras inside the gameplay scene world, not under the persistent root manager
- submitting the latest evaluated result as the same-frame handoff into `M_VCamManager`
- applying rotation continuity policy on mode switches

### `M_CameraManager`

Remains the low-level camera runtime owner:

- registers and discovers the main scene camera
- owns the transition camera
- owns shake-parent creation and shake transforms
- exposes a shake-safe API for vCam gameplay transform application

### `S_CameraStateSystem`

Remains the FOV and trauma owner:

- QB-driven camera rules (rules can now condition on `vcam_active_mode` and `vcam_is_blending` from the enriched context)
- base-FOV composition (vCam writes `C_CameraStateComponent.base_fov`; `S_CameraStateSystem` blends toward `target_fov` and applies `camera.fov`)
- final `camera.fov` application
- shake trauma decay (`C_CameraStateComponent.shake_trauma` decays at 2.0/sec; `M_CameraManager` applies shake offsets through named `set_shake_source()` / `clear_shake_source()`)

## Interaction Flow

```text
S_InputSystem
  -> dispatches gameplay.look_input (mouse + optional keyboard look via look_* actions)

S_TouchscreenSystem
  -> dispatches gameplay.look_input for mobile drag-look using UI_MobileControls

S_VCamSystem.process_tick(delta)
  -> resolve active vCam from M_VCamManager
  -> resolve outgoing vCam too when blend is active
  -> update per-vCam runtime_yaw/runtime_pitch from gameplay.look_input
  -> evaluate mode resource(s)
  -> apply projection-based soft-zone correction
  -> submit evaluated camera result(s) back to M_VCamManager

M_VCamManager._physics_process(delta)
  -> consume the most recent same-frame submission from S_VCamSystem
  -> if M_CameraManager.is_blend_active(): suspend gameplay camera writes
  -> select live blended result or active result
  -> M_CameraManager.apply_main_camera_transform(transform)
  -> update C_CameraStateComponent.base_fov
  -> detect occluders in gameplay World3D and publish EVENT_SILHOUETTE_UPDATE_REQUEST
  -> dispatch transient vcam slice updates

S_CameraStateSystem.process_tick(delta)
  -> reads camera-state component (QB rule context now includes vcam state for mode-aware rules)
  -> applies final camera.fov

U_ECSEventBus
  <- M_VCamManager publishes vCam lifecycle events:
     EVENT_VCAM_ACTIVE_CHANGED, EVENT_VCAM_BLEND_STARTED,
     EVENT_VCAM_BLEND_COMPLETED, EVENT_VCAM_RECOVERY
  <- M_VCamManager also publishes EVENT_SILHOUETTE_UPDATE_REQUEST
     with {entity_id, occluders, enabled}
  <- other systems (S_GameEventSystem, S_CameraStateSystem) can subscribe
     to react to camera orchestration changes through the standard event pattern
```

## Runtime Contracts

- `S_VCamSystem` runs after gameplay input and movement systems so camera evaluation sees current-frame `look_input` and current-frame target transforms.
- Soft-zone projection/reprojection uses the active gameplay camera's viewport from `GameViewport`, never the root manager node's viewport.
- Occlusion raycasts use the active gameplay camera's `World3D` / `PhysicsDirectSpaceState3D`, never the persistent root manager's world.
- Same-frame correctness must not depend on scene-tree `_physics_process` order between root managers and gameplay ECS. `submit_evaluated_camera(...)` is the explicit handoff path, and `M_VCamManager` applies only the latest result submitted for the active physics frame.
- Any `PathFollow3D` helper created for `use_path` lives under the gameplay scene or vCam host entity so it shares the gameplay world and is destroyed with that scene.

## Public API

### `M_VCamManager`

```gdscript
func register_vcam(vcam: C_VCamComponent) -> void
func unregister_vcam(vcam: C_VCamComponent) -> void
func set_active_vcam(vcam_id: StringName, blend_duration: float = -1.0) -> void
func get_active_vcam_id() -> StringName
func get_previous_vcam_id() -> StringName
func submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void
func get_blend_progress() -> float
func is_blending() -> bool
```

### ECS Event Bus Integration

`M_VCamManager` publishes lifecycle events through `U_ECSEventBus` using constants defined in `U_ECSEventNames`:

| Event Constant | Payload | Published When |
|------|---------|---------------|
| `EVENT_VCAM_ACTIVE_CHANGED` | `{vcam_id: StringName, previous_vcam_id: StringName, mode: String}` | active vCam selection changes |
| `EVENT_VCAM_BLEND_STARTED` | `{from_vcam_id: StringName, to_vcam_id: StringName, duration: float}` | a vCam-to-vCam blend begins |
| `EVENT_VCAM_BLEND_COMPLETED` | `{vcam_id: StringName}` | a blend finishes or cuts |
| `EVENT_VCAM_RECOVERY` | `{reason: String, vcam_id: StringName}` | recovery policy activates (target freed, anchor invalid, etc.) |

These events complement the Redux `vcam` slice. Redux provides snapshot-style observability; ECS events provide the reactive channel that `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe to.

### QB Rule Context Enrichment

`S_CameraStateSystem` builds a context dictionary for QB rule evaluation. vCam enriches this context so camera rules can be mode-aware:

| Context Key | Type | Source |
|------|------|--------|
| `vcam_active_mode` | `String` | `U_VCamSelectors.get_active_mode(state)` |
| `vcam_is_blending` | `bool` | `U_VCamSelectors.is_blending(state)` |
| `vcam_active_vcam_id` | `StringName` | `U_VCamSelectors.get_active_vcam_id(state)` |

This enables rules like "reduce FOV zone intensity during blends" or "suppress shake in first-person mode" without coupling `S_CameraStateSystem` to vCam internals — rules simply read context fields.

### `M_CameraManager` additions required by vCam

```gdscript
func apply_main_camera_transform(xform: Transform3D) -> void  # new API — Phase 9
func is_blend_active() -> bool                                 # new API — Phase 9
```

Both methods are **new API — Phase 9**. They do not exist on `M_CameraManager` today and must be implemented as part of Phase 9C (Shake-Safe Camera-Manager Integration).

`apply_main_camera_transform(...)` exists specifically so gameplay camera motion can coexist with `ShakeParent`-based shake.

## State Model

### Transient `vcam` slice

| Field | Type | Notes |
|------|------|-------|
| `active_vcam_id` | `StringName` | currently active gameplay vCam |
| `active_mode` | `String` | mode name for debugging/UI |
| `previous_vcam_id` | `StringName` | outgoing vCam during a live blend |
| `blend_progress` | `float` | `0.0..1.0` |
| `is_blending` | `bool` | whether live vCam blending is active |
| `silhouette_active_count` | `int` | number of active silhouette overrides |
| `blend_from_vcam_id` | `StringName` | debug: source vCam during an active blend |
| `blend_to_vcam_id` | `StringName` | debug: destination vCam during an active blend |
| `active_target_valid` | `bool` | debug: whether the active vCam's follow target is currently valid |
| `last_recovery_reason` | `String` | debug: reason for last recovery action (e.g. `"target_freed"`, `"anchor_invalid"`) |
| `in_fov_zone` | `bool` | `false` — canonical runtime flag for whether the active vCam's follow target is inside an FOV zone |

> **Migration note (camera slice → vcam):** Phase 0F retired legacy runtime/test `state.camera.in_fov_zone` reads. Use `state.vcam.in_fov_zone` and `U_VCamSelectors.is_in_fov_zone(state)` for FOV-zone state.

This slice is whole-slice transient. It is not save data and not a player settings surface. The `blend_from/to`, `active_target_valid`, and `last_recovery_reason` fields are debug-only and may be omitted in release builds.

### Persisted VFX setting

| Slice | Field | Purpose |
|------|-------|---------|
| `vfx` | `occlusion_silhouette_enabled` | player-facing enable/disable toggle |

### Persisted keyboard look settings

| Slice | Field | Purpose |
|------|-------|---------|
| `settings.input_settings.mouse_settings` | `keyboard_look_enabled` | enable keyboard look actions (`look_left/right/up/down`) as camera rotation input |
| `settings.input_settings.mouse_settings` | `keyboard_look_speed` | keyboard look speed multiplier (default 2.0) |

### Persisted mobile look settings

| Slice | Field | Purpose |
|------|-------|---------|
| `settings.input_settings.touchscreen_settings` | `look_drag_sensitivity` | mobile drag-look tuning |
| `settings.input_settings.touchscreen_settings` | `invert_look_y` | mobile drag-look inversion |

## Camera Modes

### `RS_VCamModeOrbit`

- authored distance/pitch/yaw
- optional player rotation
- `rotation_speed` is used only when player rotation is enabled
- authored FOV feeds `C_CameraStateComponent.base_fov`

### `RS_VCamModeFixed`

- When `use_world_anchor = true` (default): camera uses a fixed world anchor. Anchor comes from `C_VCamComponent.fixed_anchor_path` when set, with fallback to the vCam host entity-root `Node3D`. Useful for room cameras and authored framing.
- When `use_world_anchor = false`: camera maintains a constant `follow_offset` from the follow target — useful for simple chase cameras or over-shoulder views without player rotation. Position = `follow_target.global_position + follow_offset`. Returns invalid if follow target is null.
- When `use_path = true`: camera follows a `Path3D` node, finding the closest point on the curve to the follow target. Movement along the path is smoothed via `path_max_speed` (max travel speed in units/sec, 0.0 = instant) and `path_damping` (second-order smoothing factor). Camera faces along the path tangent direction; `track_target` is forced off. Requires `C_VCamComponent.path_node_path` to be set. When `use_path = true`, both `use_world_anchor` and `follow_offset` are ignored.
- When `use_path = true` and the follow target is invalid, `S_VCamSystem` falls back to the standard invalid-target recovery policy. It does not fabricate path progress from stale data.
- `follow_offset: Vector3 = Vector3(0, 3, 5)` — only consumed when `use_world_anchor = false`
- `path_max_speed: float = 10.0` — max travel speed along the path (units/sec), 0.0 = instant
- `path_damping: float = 5.0` — second-order smoothing for path progress changes
- optional tracking toward the follow target (`track_target`) applies in both anchor modes; forced off when `use_path = true` (camera faces path tangent)
- `runtime_yaw`/`runtime_pitch` are always ignored (fixed cameras never respond to player input)

### `RS_VCamModeFirstPerson`

- authored head offset
- authored `look_multiplier`
- pitch clamping
- authored FOV feeds `C_CameraStateComponent.base_fov`

`look_multiplier` is a per-vCam authored multiplier. The input layer already provides scaled `look_input`.

On mobile, that same `look_input` must come from drag-look through the existing touchscreen input path rather than through a separate vCam-only control scheme.

## Rotation Continuity Contract

When switching between camera modes, `runtime_yaw` and `runtime_pitch` follow these rules:

- **Orbit → First-Person**: carry `runtime_yaw` as-is so the player keeps facing the same world direction. Reset `runtime_pitch` to `0.0` (level horizon) since orbit pitch semantics differ from first-person pitch.
- **First-Person → Orbit**: carry `runtime_yaw` as-is. Reset `runtime_pitch` to `0.0` (authored orbit pitch takes over).
- **Orbit → Fixed**: rotation state is irrelevant to fixed cameras. Preserve `runtime_yaw`/`runtime_pitch` on the outgoing component so they are intact if the player returns to that vCam.
- **Fixed → Orbit / First-Person**: reseed `runtime_yaw` to the authored yaw of the incoming vCam. Reset `runtime_pitch` to `0.0`. The camera should land at its authored default rather than inheriting stale rotation from a previous session.
- **Same-mode switch** (e.g. orbit → orbit): carry both `runtime_yaw` and `runtime_pitch` when the two cameras share the same follow target. When they follow different targets, reseed to authored angles.

`S_VCamSystem` is responsible for applying this policy during `set_active_vcam()`. The contract is: no disorienting heading jumps on any common transition.

## Soft-Zone System

Soft-zone behavior is still defined in normalized screen space, but the implementation has to be projection-aware.

Correct process:

1. Evaluate the vCam mode to get a desired camera pose.
2. Project the follow target into the viewport from that desired pose.
3. Determine whether the target is in the dead zone, soft zone, or outside the allowed bounds.
4. Find the corrected screen-space target point.
5. Reproject that point back into world space at the same camera-space depth.
6. Convert the difference into a world-space correction applied to the desired camera pose.

### Projection Method Details

- Use `camera.unproject_position(follow_world_pos)` to get the screen-space position of the follow target from the desired camera pose.
- Use `camera.project_position(screen_point, depth)` to convert a corrected screen point back into world space at the same camera-space depth.
- All zone tests use normalized viewport coordinates (`screen_pos / viewport_size`), not pixel coordinates.
- **Near-plane guard:** Before projecting, verify the follow target is in front of the camera using a dot-product check: `(follow_world_pos - camera_pos).dot(-camera_basis.z) > 0.0`. If the target is behind the near plane, skip soft-zone correction entirely for that tick.
- **Hysteresis state machine:** Track `_in_dead_zone: bool` per axis (X/Y) to implement enter/exit thresholds:
  - Enter dead zone (stop correcting) at `dead_zone_size + hysteresis_margin`
  - Exit dead zone (start correcting) at `dead_zone_size - hysteresis_margin`
  - This prevents correction toggling when the target oscillates at the dead zone boundary.

What the implementation must not do:

- assume `target_screen_pos` already exists without a projection step
- treat normalized screen deltas like direct world-space units

## Blend System

The original draft froze the outgoing transform at blend start. That is not sufficient for moving cameras.

Correct blend behavior:

- store outgoing and incoming vCam IDs, not only old transforms
- evaluate both cameras every tick while a blend is active
- blend the two live results each tick
- apply `RS_VCamBlendHint.ease_type` and `RS_VCamBlendHint.trans_type`
- if `cut_on_distance_threshold > 0.0` and the evaluated camera positions are farther apart than the threshold, cut immediately instead of blending

### Reentrant Switch (Mid-Blend Interruption)

If `set_active_vcam(...)` is called while a blend is already active:

- the current blended pose becomes the new "from" pose (snapshot the interpolated result at the moment of interruption)
- the newly requested vCam becomes the new "to" target
- `previous_vcam_id` updates to reflect the interrupted blend's source
- blend progress resets to `0.0` with the new target's blend hint
- the old outgoing vCam stops being evaluated (only the snapshot and the new incoming vCam are live)

This prevents pops from restarting a blend from the original source position and avoids wedged blend state from rapid switching.

## Complete RS_VCamResponse Contract

`RS_VCamResponse` is the per-vCam response tuning resource. It controls second-order dynamics for camera follow and mode-specific game-feel features. All fields are `@export` with sensible defaults so an untuned response still feels reasonable.

| Field | Type | Default | Phase Introduced | Notes |
|-------|------|---------|-----------------|-------|
| `follow_frequency` | `float` | `3.0` | 1F | Second-order dynamics frequency (Hz) for position follow |
| `follow_damping` | `float` | `0.7` | 1F | Damping ratio for position follow (< 1 = underdamped/bouncy, 1 = critical, > 1 = overdamped) |
| `follow_initial_response` | `float` | `1.0` | 1F | Initial velocity response (0 = smooth start, 1 = immediate) |
| `rotation_frequency` | `float` | `4.0` | 1F | Second-order dynamics frequency for rotation follow |
| `rotation_damping` | `float` | `1.0` | 1F | Damping ratio for rotation follow |
| `rotation_initial_response` | `float` | `1.0` | 1F | Initial response term for rotation smoothing |
| `look_ahead_distance` | `float` | `0.0` | 2C1 | Max world-space offset in follow target's movement direction (0 = disabled, orbit only) |
| `look_ahead_smoothing` | `float` | `3.0` | 2C1 | Hz for look-ahead offset dynamics (orbit only) |
| `auto_level_speed` | `float` | `0.0` | 2C2 | Degrees/sec pitch decays toward horizon when no look input (0 = disabled, orbit only) |
| `auto_level_delay` | `float` | `1.0` | 2C2 | Seconds of zero look input before auto-level begins (orbit only) |
| `landing_impact_scale` | `float` | `1.0` | 6A3c | Multiplier for QB-driven landing impact offset on this vCam (0 = suppress) |

> **Note:** Fields introduced in Phases 2C1 and 2C2 are added to the resource when those orbit game-feel features are implemented. Fields are shown here holistically for reference; the implementation adds them incrementally.

## Mobile Drag-Look Contract

Mobile support is not complete unless the shared `gameplay.look_input` path works for touch.

Required behavior:

- `UI_MobileControls` tracks a dedicated look touch separate from the move joystick and virtual buttons.
- A touch that begins on the joystick or on a button remains owned by that control.
- A touch that begins elsewhere becomes a drag-look gesture.
- `S_TouchscreenSystem` dispatches `U_InputActions.update_look_input(look_delta)` each tick for touchscreen mode.
- `S_InputSystem` must not overwrite touchscreen gameplay input with zero payloads from `TouchscreenSource`.
- Mobile drag-look settings persist through `settings.input_settings.touchscreen_settings`, not the `vcam` slice.
- If `gameplay.touch_look_active` is added as a top-level gameplay flag, it must be registered as transient in `U_StateSliceManager` and reset on load/handoff. It must not persist through save/load accidentally.
- `S_VCamSystem` remains device-agnostic and simply consumes the shared `look_input` value.

## Keyboard Look Contract

Keyboard look is an optional alternative input for camera rotation on keyboard/mouse, complementing mouse look.

The project has input profiles that remap keys (default: WASD=movement/arrows=UI, alternate: arrows=movement/WASD=UI). To stay profile-aware, keyboard look uses dedicated `look_left`, `look_right`, `look_up`, `look_down` input actions — not `ui_*` actions — so each profile can bind them to the appropriate physical keys.

Required behavior:

- Four new input actions are registered in `project.godot`: `look_left`, `look_right`, `look_up`, `look_down`.
- `scripts/input/u_input_map_bootstrapper.gd` adds the same four actions to `REQUIRED_ACTIONS`, and `tests/unit/input/test_input_map.gd` is updated so bootstrap coverage matches the profile resources.
- Each `RS_InputProfile` includes bindings for these actions:
  - **Default keyboard**: arrow keys (matching the non-movement keys).
  - **Alternate keyboard**: WASD (matching the non-movement keys in that layout).
  - **Gamepad profiles**: right stick already feeds `look_input` via `GamepadSource`; `look_*` actions are not bound on gamepad.
  - **Touchscreen**: not applicable; drag-look feeds `look_input` directly.
- `KeyboardMouseSource` checks `keyboard_look_enabled` from `mouse_settings` each tick.
- When enabled, reads `look_left`/`look_right`/`look_up`/`look_down` action strength and produces a fixed-rate delta scaled by `keyboard_look_speed * delta`.
- Keyboard look is additive with mouse look — both sources combine into the same `look_input` vector.
- `keyboard_look_speed` defaults to `2.0` and is clamped to `0.1–10.0`.
- Keyboard look respects the existing `invert_y_axis` setting from `mouse_settings`.
- Settings persist through `settings.input_settings.mouse_settings`, not the `vcam` slice.
- If dedicated `set_keyboard_look_*` actions are introduced, add them to `scripts/utils/u_global_settings_serialization.gd` `INPUT_SETTINGS_ACTIONS` so changes trigger the existing settings-save flow.
- `S_VCamSystem` remains input-source-agnostic and simply consumes the shared `look_input` value.
- `scripts/ui/helpers/u_rebind_action_list_builder.gd` must list `look_*` under the camera category, and the `input.action.look_*` localization keys must be added across the supported `cfg_locale_*_ui.tres` files.
- Because there is no existing mouse/keyboard settings overlay in this repo, keyboard-look settings live in a new `UI_KeyboardMouseSettingsOverlay` wired from `UI_SettingsMenu`, not as an implicit "if one exists" follow-up.

## Runtime Recovery Policy

When a target or vCam becomes invalid during gameplay, the system follows these rules:

### Follow target freed or disappeared

- hold the last valid evaluated pose for up to 1 physics frame
- if the target remains invalid, cut to the highest-priority vCam that still has a valid target
- if no valid vCam exists, hold the last valid camera pose (do not snap to origin)

### Fixed anchor freed

- fall back to the vCam host entity-root `Node3D` (the standard anchor fallback)
- if the entity root is also invalid, hold the last valid pose and log a warning

### vCam becomes invalid mid-blend

- if the outgoing vCam is freed: complete the blend immediately (cut to the incoming result)
- if the incoming vCam is freed: cancel the blend and hold the outgoing pose; trigger priority reselection
- if both are freed: hold the last valid blended pose and clear blend state

### Scene transition

- clear all silhouettes
- clear blend state
- do not carry stale vCam references across scene boundaries

`M_VCamManager` is responsible for checking validity before each evaluation tick. Invalid states must never produce NaN transforms or crash the pipeline.

## Collision and Silhouette

### Detection

- cast against physics layer 6 named `vcam_occludable`
- raycasts use the active gameplay camera's `World3D` / `direct_space_state`
- detect `GeometryInstance3D` occluders
- support `MeshInstance3D` and `CSGShape3D`
- migrate authored occluding geometry in gameplay/prefab scenes onto layer 6; naming the layer in `project.godot` alone is not sufficient

### Rendering

- use `assets/shaders/sh_vcam_silhouette_shader.gdshader`
- `M_VCamManager` does not apply materials directly. It publishes `EVENT_SILHOUETTE_UPDATE_REQUEST` with `{entity_id, occluders, enabled}`.
- `M_VFXManager` owns rendering, applies existing player gating and transition blocking, and delegates actual material override work to `U_VCamSilhouetteHelper`.
- store original override state so restoration is deterministic
- clear all overrides when no active gameplay vCam exists or a scene swap invalidates the previous result set

### Stability (Anti-Flicker)

- maintain a "stable occluder set" — only add/remove occluders when their status has been consistent for at least 2 consecutive physics frames (debounce)
- when the occluder set is unchanged from the previous frame, skip material override application entirely (no per-frame churn)
- grace-frame removal: when an occluder leaves the ray, keep its silhouette for 2 additional frames before restoring the original material
- this prevents visible flicker when an occluder repeatedly crosses the ray boundary or when raycast results jitter frame-to-frame

## Editor Preview

Use a helper patterned after `U_CinemaGradePreview`:

- file: `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`
- `@tool`
- extends `Node`
- creates its own `CanvasLayer` and drawing child internally
- frees itself at runtime

This intentionally avoids a new `scripts/tools` category.

## Entity-Based Target Resolution

`C_VCamComponent` supports two target resolution strategies:

1. **NodePath exports** (primary): `follow_target_path`, `look_at_target_path`, `fixed_anchor_path` — resolved via `get_node_or_null()` per the standard ECS component pattern.
2. **Entity ID fallback**: when NodePath exports are empty, `S_VCamSystem` can resolve targets through `M_ECSManager.get_entity_by_id(target_entity_id)` or `M_ECSManager.get_entities_by_tag(tag)`. This enables dynamic target assignment (e.g., follow the entity tagged `"player"`) without hard-coded scene paths.
3. **Multiple tag matches**: if `follow_target_tag` resolves more than one valid entity, use the first valid ECS-registration-order match and emit a debug warning. Use `follow_target_entity_id` when deterministic targeting matters across scene-authoring changes.

Entity resolution uses the existing `BaseECSEntity` ID and tag system documented in AGENTS.md. `S_VCamSystem` queries the ECS manager that the gameplay scene owns.

## File Layout

```text
scripts/managers/m_vcam_manager.gd
scripts/interfaces/i_vcam_manager.gd
scripts/ecs/components/c_vcam_component.gd
scripts/ecs/systems/s_vcam_system.gd
scripts/resources/display/vcam/*.gd
scripts/resources/state/rs_vcam_initial_state.gd
scripts/state/actions/u_vcam_actions.gd
scripts/state/reducers/u_vcam_reducer.gd
scripts/state/selectors/u_vcam_selectors.gd
scripts/utils/display/u_vcam_rule_of_thirds_preview.gd
assets/shaders/sh_vcam_silhouette_shader.gdshader
resources/state/cfg_default_vcam_initial_state.tres
resources/display/vcam/*.tres
```

## Testing Strategy

### Unit coverage

- state resource, reducer, selectors
- vCam mode resources
- soft-zone helper
- blend evaluator
- collision detector
- silhouette helper
- `M_VCamManager`
- `S_VCamSystem`
- mobile drag-look regression coverage in `S_TouchscreenSystem` and `UI_MobileControls`
- zero-clobber regression coverage for `S_InputSystem` when touchscreen is active
- `M_CameraManager` regression coverage for the new API
- `MockCameraManager` coverage for new interface methods

### Integration coverage

- root scene registers `M_VCamManager`
- gameplay scenes include `S_VCamSystem`
- switching active vCams blends correctly
- moving outgoing and incoming cameras stay live through the blend
- vCam gameplay motion and shake coexist
- silhouettes work on both mesh and CSG occluders
- VFX settings overlay exposes and persists `occlusion_silhouette_enabled` with localization coverage
- mobile drag-look feeds orbit and first-person cameras through the same `gameplay.look_input` path

## Resolved Decisions

| Topic | Decision |
|------|----------|
| root wiring | `M_VCamManager` lives in `scenes/root.tscn` |
| gameplay wiring | `S_VCamSystem` lives in gameplay `Systems/Core` |
| state persistence | `vcam` is transient; silhouette enablement persists in `vfx` |
| input ownership | reuse `gameplay.look_input` from `S_InputSystem` and touchscreen drag-look via `S_TouchscreenSystem` |
| shake compatibility | vCam uses `M_CameraManager.apply_main_camera_transform(...)` |
| blend correctness | evaluate both cameras live during blends |
| soft-zone math | projection-based correction |
| naming/style | use `scripts/resources/display/vcam`, `scripts/utils/display`, `sh_*_shader.gdshader` |
| keyboard look | optional keyboard camera rotation via dedicated `look_*` actions bound per-profile, settings in `mouse_settings` |
| silhouette ownership | detect in vCam, render in `M_VFXManager` via `{entity_id, occluders, enabled}` request payload |
