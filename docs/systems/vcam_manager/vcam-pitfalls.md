# vCam Pitfalls

Camera, vCam, room-fade, wall-visibility, and camera-rule pitfalls collected from the legacy developer pitfalls guide.

## Room Fade System

- **Use `absf(dot)` for camera-wall facing checks, not signed dot**: The room fade system compares `camera_forward.dot(wall_normal)` against a threshold to decide whether a wall should fade. If only the signed dot is used, walls only fade when the camera faces the same direction as the normal (viewing from outside). From inside the room the dot is negative, so walls between the camera and player stay opaque. Always use `absf(dot_value) > threshold` so walls fade regardless of which side the camera is on.
- **Corridor occlusion must use nearest AABB point, not wall center**: The camera-player occlusion corridor check determines whether a wall is "between" the camera and player. Using the wall's center position fails for large walls where the camera-player line passes near one end; the center can be far from the corridor even though the wall clearly occludes. Use the nearest point on the wall's axis-aligned bounding box, projected to the XZ plane, to the corridor line segment instead.
- **Default new diagnostic debug flags to `true` when adding them for active investigation**: When adding temporary `@export` debug flags to investigate a live bug, default them to `true` so the diagnostics actually fire when you run the game. Defaulting to `false` defeats the purpose of adding the diagnostics.

## QB Camera Rules

- **Hardcoded fallback FOV can override authored scene cameras**: If `S_CameraStateSystem` falls back to a constant FOV, scenes authored with cinematic FOV values can look unexpectedly zoomed out after startup or after leaving a zone.
  - **Fix pattern**: capture baseline FOV from the active `Camera3D` into `C_CameraStateComponent.base_fov` and restore that baseline when no FOV zone rule is active.
  - **Regression check**: keep a unit test that enters/exits a zone and asserts the camera returns to the authored baseline FOV.
- **Do not re-introduce `state.camera.in_fov_zone`**: Phase 0F moved runtime and QB camera tests to `state.vcam.in_fov_zone` and updated `cfg_camera_zone_fov_rule.tres` accordingly. Bringing back the legacy path causes FOV rule drift and split-brain camera state.
  - **Fix pattern**: read FOV-zone state through `U_VCamSelectors.is_in_fov_zone(state)` and seed tests via `set_slice(StringName("vcam"), {"in_fov_zone": ...})`.
- **Speed-FOV rules can leave stale bonus when score hits 0 if thresholding skips the winner**: `U_RuleScorer` drops rules when `score <= score_threshold`; with default `score_threshold = 0.0`, stationary speed produces no winner and `speed_fov_bonus` can stick from the previous frame.
  - **Fix pattern**: for continuous speed breathing, either set `score_threshold` below zero so score `0.0` still executes and writes zero, or add an explicit reset rule.
- **Event-mode camera rules can cross-fire on unrelated events when zero-score winners are allowed**: If a rule uses `trigger_mode = "event"` with `score_threshold < 0.0`, it can still win with score `0.0`; without event-name prefiltering, unrelated events can execute effects authored for another event.
  - **Fix pattern**: in `S_CameraStateSystem`, prefilter event rules by subscribed event name before scoring/selection through `RS_ConditionEventName` extraction, then run winner selection only on matching rules.
  - **Regression check**: keep a test that publishes a non-landing event and asserts `landing_impact_offset` is unchanged.

## Scene Wiring

- **Gameplay scenes can silently ship without orbit runtime if `S_VCamSystem` is missing**: Scenes that instance `tmpl_camera.tscn` still need `S_VCamSystem` in `Systems/Core`; without it, camera look/follow behavior and active-vCam FOV propagation never run in those scenes.
  - **Fix pattern**: keep `S_VCamSystem` present with `execution_priority = 100` in every gameplay scene that uses `E_CameraRoot`/`C_VCamComponent`, and add scene-registration assertions that check for `Systems/Core/S_VCamSystem`.
- **Leaving `debug_rotation_logging = true` in authored scenes can flood runtime logs and hide real signal in QA runs**: Temporary diagnostics are useful while tuning, but scene-level overrides keep logging enabled by default for everyone and can skew runtime profiling.
  - **Fix pattern**: rely on `S_VCamSystem` default (`false`) and remove `.tscn` overrides after diagnostics; keep a style guard test that fails on authored `debug_rotation_logging = true` lines.

## Orbit Evaluator

- **Looking straight up/down can break orbit camera orientation if `Vector3.UP` is always used as the look-at up-vector**: At near-vertical view directions, `looking_at(...)` can hit a degenerate basis and produce unstable orientation.
  - **Fix pattern**: in `U_VCamModeEvaluator`, detect near-parallel forward/up vectors and switch to a fallback up-vector before constructing the look-at transform.

## Orbit Feel

- **Bursty look streams can thrash look-spring and smoothing gates if activity is derived from raw zero/non-zero frames only**: Mouse, touch, and right-stick samples can arrive in bursts with intermittent zero frames; treating every zero as "input stopped" causes repeated spring state transitions and visible roughness.
  - **Fix pattern**: maintain per-vCam look activity filter state and derive active-input from response-tuned deadzone/hold/decay while keeping runtime yaw/pitch accumulation raw-input driven.
- **Auto-level can fight active player look input if the idle timer does not reset every non-zero look frame**: Orbit recentering should only start after continuous idle time.
  - **Fix pattern**: reset the per-vCam no-look timer on every non-zero `look_input` tick before evaluating auto-level delay/speed.
- **Look-ahead can leak stale offsets across mode/target changes**: Reusing previous velocity/offset state when switching targets or switching to non-orbit modes causes incorrect camera drift on the next tick.
  - **Fix pattern**: clear per-vCam look-ahead state whenever mode is non-orbit, look-ahead is disabled, or follow-target identity changes.
- **Look-ahead can falsely trigger while rotating in place if velocity is derived from follow-target transform deltas**: Orbit follow markers are often offset child nodes; yaw-only rotation can move those markers in world space without actual movement.
  - **Fix pattern**: source look-ahead direction from movement velocity first, then movement-component/body fallback, and avoid transform-delta velocity for look-ahead decisions.
- **Look-ahead can fight active camera rotation input if not explicitly gated**: Applying movement look-ahead while the player is actively rotating camera yaw/pitch compounds framing offsets.
  - **Fix pattern**: gate orbit look-ahead on filtered look-input inactivity and clear per-vCam look-ahead state while filtered look input is active.
- **Always bypassing orbit follow-position smoothing during look input makes moving rotation feel harsh**: The old `has_active_look_input` bypass is useful for stationary no-lag framing, but removes useful smoothing while the follow target is translating.
  - **Fix pattern**: gate orbit bypass by follow-target speed with hysteresis using per-vCam sampled target motion state.
- **Ground-relative anchors can drift if ground reference is sampled while airborne or re-anchored without a landing threshold**: Updating anchor reference every frame while the target is in the air reintroduces jump bob and defeats the dual-anchor contract.
  - **Fix pattern**: sample/probe ground reference only while grounded, lock vertical anchor while airborne, and only re-anchor on landing transitions when `height_delta >= ground_reanchor_min_height_delta`.
- **Button recenter can silently cancel when centering state is coupled to response-smoothing cleanup**: Orbit recenter is allowed when `response == null`; if centering state is cleared from response-null smoothing paths, button recenter restarts or drops every tick.
  - **Fix pattern**: keep `_orbit_centering_state` lifecycle independent from response smoothing state; prune it only on vCam removal/prune.

## Wall Visibility

- **Wall visibility can leak dither-dissolved geometry into OTS/fixed if mode gating only disables updates without restoring materials**: Simply skipping visibility updates outside orbit leaves shader overrides and partial dissolve active from previous orbit ticks.
  - **Fix pattern**: in `S_WallVisibilitySystem`, treat non-orbit ticks as a full cleanup path: set each group `current_alpha = 1.0`, restore original materials through `U_WallVisibilityMaterialApplier`, and clear tracked target plus normal cache.
- **Wall visibility can silently stop in tests/runtime scaffolds when camera lookup assumes `camera_manager.get_main_camera()` is always valid**: Some harnesses and transitional scene states only expose the active camera through the viewport, not the manager slot.
  - **Fix pattern**: resolve camera by manager main camera first, then fallback to `get_viewport().get_camera_3d()` before deciding camera is unavailable.
- **Shared wall targets can receive conflicting wall-visibility fade/material writes when multiple `C_RoomFadeGroupComponent` instances collect the same mesh**: Without explicit ownership arbitration, later components in the tick overwrite earlier updates and produce non-deterministic fade behavior.
  - **Fix pattern**: run a per-tick ownership pre-pass so the first component in filtered order owns each target, skip duplicate owners with warn+continue diagnostics, and keep `group_tag` explicit/unique in authored room-fade groups.
- **Walls outside the camera-player occlusion corridor can dissolve incorrectly when only dot-product direction is used**: Dot-product fade cannot distinguish walls the player can see through from walls beside the player.
  - **Fix pattern**: use `_passes_camera_player_occlusion_corridor()` before allowing fade. Use `_resolve_normal_bucket_key()` plus `bucket_has_corridor_hit` for bucket continuity so adjacent wall segments fade together.
- **Fully dissolved walls (`fade_amount = 1.0`) leave confusing gaps**: Without a minimum fade residue, the dither pattern can make walls completely invisible.
  - **Fix pattern**: cap `fade_amount` at `1.0 - min_fade` so a faint outline survives even at maximum fade.

## Soft Zone

- **Clearing dead-zone hysteresis state on response-null paths causes boundary jitter**: `S_VCamSystem` can run with `response = null`. If soft-zone hysteresis state is tied to response-smoothing resets, dead-zone enter/exit history is wiped every tick.
  - **Fix pattern**: keep `_soft_zone_dead_zone_state` lifecycle independent from response smoothing state; clear it only on vCam prune/removal or when orbit/soft-zone gating disables correction.
- **Projection helpers must evaluate from the desired camera pose and restore camera transform after calculations**: Running projection helpers against the wrong transform or leaking the temporary transform causes incorrect correction vectors and can desync live camera state.
  - **Fix pattern**: in `U_VCamSoftZone`, compute depth against `desired_transform`, temporarily project using that transform, then restore the original camera transform before returning.

## OTS Evaluator

- **Do not defer OTS pitch clamping to `S_VCamSystem`**: OTS vertical limits are authored per mode resource. If clamping is deferred, direct evaluator consumers can exceed limits.
  - **Fix pattern**: clamp `runtime_pitch` inside `U_VCamModeEvaluator` for OTS branches using resolved mode bounds before building the yaw/pitch basis.
- **Do not consume `look_multiplier` in evaluator helpers**: Evaluator functions should only convert resolved runtime yaw/pitch inputs into transforms. Applying `look_multiplier` in evaluator code double-scales input.
  - **Fix pattern**: keep `look_multiplier` application in `S_VCamSystem` when updating component runtime rotation state; evaluator consumes already-computed runtime angles.

## OTS Collision

- **`cast_motion(...)` spherecasts can miss near-wall cases when the probe starts already intersecting geometry**: In tight OTS framing, the cast origin can begin overlapping an obstacle. Relying only on motion sweep can report no hit.
  - **Fix pattern**: run an initial-overlap `intersect_shape(...)` check at cast origin before `cast_motion(...)`; treat overlap as hit-distance `0.0`, then apply minimum-distance floor logic.

## Fixed Evaluator

- **Do not apply player look input (`runtime_yaw`/`runtime_pitch`) in fixed mode**: Fixed cameras are authored viewpoints. Letting runtime look rotate fixed evaluations breaks mode boundaries and causes cross-mode carryover bugs.
  - **Fix pattern**: ignore runtime yaw/pitch entirely in fixed branches and derive orientation only from authored anchor basis or explicit `track_target` look-at.
- **`use_path` mode must not track follow target orientation**: Path-follow fixed cameras are expected to face path tangent. If `track_target` is honored in path mode, camera headings jitter and diverge from authored rail direction.
  - **Fix pattern**: in evaluator logic, treat `use_path` as anchor-basis orientation with `track_target` forced off; path progress/smoothing stays in `S_VCamSystem`.

## Runtime Integration

- **Do not write gameplay camera transforms directly to `camera.global_transform`**: vCam runtime motion must flow through `M_CameraManager.apply_main_camera_transform(...)` so `ShakeParent` layering and transition-camera behavior stay intact.
- **`is_blend_active()` must reflect transition tween state, not camera-current state**: Using `TransitionCamera.current` as the blend-active source can report false positives when no transition tween is running, incorrectly blocking gameplay camera writes.
  - **Fix pattern**: drive `is_blend_active()` from active transition tween state: `_camera_blend_tween != null && _camera_blend_tween.is_running()`.
- **Fixed mode must resolve authored anchors via component path first**: `C_VCamComponent` is a `Node`, not the authored world anchor. For fixed cameras, resolve `fixed_anchor_path` to a `Node3D` first and fallback to the vCam host entity-root `Node3D`.
- **`vcam_occludable` naming alone does not enable real occlusion behavior**: After defining physics layer schema, migrate authored camera-blocking geometry in gameplay/prefab scenes onto that layer.
- **Per-frame silhouette clear/reapply causes visible edge flicker and material churn**: Rebuilding silhouettes every tick can flicker when occluders hover on ray boundaries and does unnecessary override churn.
  - **Fix pattern**: route per-tick updates through `U_VCamSilhouetteHelper.update_silhouettes(...)` so silhouettes use debounce/grace semantics and stable-set no-op behavior.
- **Transition-block gating can accidentally drop silhouette clear events**: If `M_VFXManager` rejects all silhouette events while `scene.is_transitioning`, an `enabled=false` clear request can be ignored.
  - **Fix pattern**: keep transition/player gating for `enabled=true` updates, but always process explicit clear requests (`enabled=false`) so teardown is deterministic during scene transitions.
- **`vcam.silhouette_active_count` should reflect rendered silhouettes, not pre-filter detection**: Dispatching count from `M_VCamManager` before debounce/grace filtering can report non-zero while no silhouette is yet visible.
  - **Fix pattern**: dispatch `U_VCamActions.update_silhouette_count(...)` from `M_VFXManager` using `U_VCamSilhouetteHelper.get_active_count()` after update processing.
- **Touch look ownership must stay in `S_TouchscreenSystem`**: `gameplay.look_input` is shared across devices. If `S_InputSystem` keeps dispatching zero touchscreen payloads while touchscreen is active, it clobbers drag-look and breaks mobile orbit/OTS camera control.
- **Live vCam apply must ignore stale submissions from previous physics frames**: Root/gameplay `_physics_process` ordering can vary; if `M_VCamManager` applies the last cached result without frame-gating, camera motion can lag or hitch one frame behind gameplay evaluation.
  - **Fix pattern**: stamp each `submit_evaluated_camera(...)` result with `Engine.get_physics_frames()` and only apply results that match the current frame.
- **Second-order rotation smoothing needs angle unwrapping and deterministic reset boundaries**: Smoothing Euler angles directly from `Basis.get_euler()` without unwrapping can pick the long path across `-PI/PI`. Reusing smoothing state across mode switches or follow-target changes can also drag stale momentum into a new camera context.
  - **Fix pattern**: unwrap each target axis against the previous target angle before stepping rotation dynamics, recreate dynamics when response tuning changes, and reset dynamics on mode/follow-target transitions.
- **Mode switches can inherit stale runtime orientation without explicit continuity policy**: Swapping active vCams without transition-aware carry/reset/reseed rules can cause heading pops.
  - **Fix pattern**: apply continuity policy before evaluation on active-id changes in `S_VCamSystem`: orbit<->OTS carry yaw plus reset pitch, fixed->orbit/OTS reseed incoming yaw/pitch to authored defaults, and same-mode switches carry only when both vCams resolve the same follow target.
