# vCam Orbit — Task Checklist

**Scope:** Orbit camera mode — resource, evaluator, default preset, then later orbit-specific game feel (look-ahead, auto-level, soft zone, hysteresis, ground-relative anchoring, look-release smoothing, button recenter), and manual validation.

**Depends on:** Phase 1 (base resources) must be complete before Phase 2B evaluator tests.

---

## Pre-Implementation Checklist

Before starting Phase 2, verify:

- [x] **PRE-1**: Phase 0 and Phase 1 are fully complete (all base state, persistence, and authoring resource tests pass)
- [x] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeOrbit)
  - Read `docs/vcam_manager/vcam-manager-prd.md` (orbit requirements)
  - Read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- [x] **PRE-3**: Understand existing patterns by reading:
  - `scripts/resources/display/vcam/rs_vcam_soft_zone.gd` (resource pattern from Phase 1)
  - `scripts/resources/display/vcam/rs_vcam_blend_hint.gd` (resource pattern from Phase 1)
  - Any existing `tests/unit/resources/display/vcam/` tests (test pattern from Phase 1)
- [x] **PRE-4**: Verify branch is `vcam` and working tree is clean

---

## Per-Phase Documentation Cadence (Mandatory)

- [x] **DOC-1**: After Phase 2 completion, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [x] **DOC-2**: After Phase 2 completion, update this file (`vcam-orbit-tasks.md`) with `[x]` marks and completion notes.
- [x] **DOC-3**: Update `AGENTS.md` if orbit evaluation reveals new stable architecture/pattern contracts.
- [x] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with any orbit-specific pitfalls discovered.
- [x] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

**Documentation completion note (March 10, 2026):** Continuation/tasks docs updated and synchronized, AGENTS vCam runtime contracts updated for orbit resolved-values behavior, and post-`0f51c36` retune docs/tests now pin the active `cfg_default_response.tres` baseline plus authored-scene debug-logging defaults.

### Post-0f51 Retune Audit (March 10, 2026)

- [x] Added preset coverage for `cfg_default_response.tres` tuned orbit response values in `tests/unit/resources/display/vcam/test_vcam_mode_presets.gd`
- [x] Added style guard to fail on authored `debug_rotation_logging = true` overrides in gameplay/template scenes (`tests/unit/style/test_style_enforcement.gd`)

---

## Phase 2: Orbit Camera Mode

**Exit Criteria:** All ~23 orbit tests pass (11 resource + 12 evaluator), orbit evaluation produces correct transforms for all authored configurations (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 2A: RS_VCamModeOrbit Resource

- [x] **Task 2A.1 (Red)**: Write tests for RS_VCamModeOrbit
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
  - Test `distance` field exists with default (e.g. 5.0)
  - Test `authored_pitch` field exists with default (e.g. -20.0 degrees)
  - Test `authored_yaw` field exists with default (e.g. 0.0)
  - Test `allow_player_rotation` field exists with default `true`
  - Test `rotation_speed` field exists with default (e.g. 2.0)
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `distance` must be positive (reject zero or negative)
  - Test `fov` must be within valid range (1.0-179.0)
  - **Target: 11 tests** (8 baseline + 3 resolved-value safety checks)

- [x] **Task 2A.2 (Green)**: Implement RS_VCamModeOrbit
  - Create `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamModeOrbit`
  - All `@export` fields with sensible defaults:
    - `distance: float = 5.0`
    - `authored_pitch: float = -20.0` (degrees, negative = looking down)
    - `authored_yaw: float = 0.0` (degrees)
    - `allow_player_rotation: bool = true`
    - `rotation_speed: float = 2.0`
    - `fov: float = 75.0`
  - All tests should pass

- [x] **Task 2A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 2B: Orbit Mode Evaluator

- [x] **Task 2B.1 (Red)**: Write tests for orbit evaluation in U_VCamModeEvaluator
  - Create `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test orbit evaluation with default settings returns a valid `transform` key (is `Transform3D`)
  - Test orbit evaluation returns correct `fov` key matching resource (`75.0`)
  - Test orbit evaluation returns `mode_name == "orbit"`
  - Test orbit camera is positioned at `distance` behind and above follow target based on `authored_pitch`
    - Verify spherical-to-cartesian: given pitch=-20deg, yaw=0, distance=5, camera should be at correct offset from follow target
    - Assert `result.transform.origin` is approximately `follow_target.origin + spherical_offset`
  - Test orbit camera looks at the follow target
    - Verify the camera's -Z basis direction points toward the follow target position
    - Use `result.transform.basis` dot-product or `looking_at` comparison
  - Test orbit with `allow_player_rotation = true` applies `runtime_yaw` and `runtime_pitch`
    - Pass `runtime_yaw = 90.0` degrees and verify camera orbits 90 degrees around target
    - Pass `runtime_pitch = -10.0` degrees and verify camera adjusts vertical angle
  - Test orbit with `allow_player_rotation = false` ignores `runtime_yaw` and `runtime_pitch`
    - Pass non-zero runtime_yaw/runtime_pitch, verify result matches zero-rotation evaluation
  - Test orbit with zero distance returns empty dictionary (invalid config)
  - Test orbit with null follow target returns empty dictionary
  - Test orbit with null mode resource returns empty dictionary without warnings (no `push_warning` or `push_error` in output)
  - **Target: 12 tests** (10 baseline + 2 resolved-value evaluator checks)

  **Test helper setup pattern:**
  ```gdscript
  # Create a follow target as Node3D at known position
  var follow_target := Node3D.new()
  follow_target.global_transform.origin = Vector3(0, 0, 0)
  add_child(follow_target)

  # Create orbit mode resource with test values
  var mode := RS_VCamModeOrbit.new()
  mode.distance = 5.0
  mode.authored_pitch = -20.0
  mode.authored_yaw = 0.0

  # Evaluate
  var result := U_VCamModeEvaluator.evaluate(mode, follow_target, null, 0.0, 0.0)
  ```

- [x] **Task 2B.2 (Green)**: Implement orbit evaluation in U_VCamModeEvaluator
  - Create `scripts/managers/helpers/u_vcam_mode_evaluator.gd`
  - Add `class_name U_VCamModeEvaluator`
  - Implement `static func evaluate(mode: Resource, follow_target: Node3D, look_at_target: Node3D, runtime_yaw: float, runtime_pitch: float, fixed_anchor: Node3D = null) -> Dictionary`
  - Handle orbit mode branch:
    - Guard: return `{}` if mode is null, follow_target is null, or distance <= 0
    - Compute total yaw: `authored_yaw + (runtime_yaw if allow_player_rotation else 0.0)`
    - Compute total pitch: `authored_pitch + (runtime_pitch if allow_player_rotation else 0.0)`
    - Convert spherical coordinates (distance, total_pitch, total_yaw) to cartesian offset
    - Camera position = follow_target.global_position + cartesian_offset
    - Camera transform = `Transform3D.IDENTITY.looking_at_from_position(camera_pos, follow_target.global_position, Vector3.UP)`
    - Return `{transform = camera_xform, fov = mode.fov, mode_name = "orbit"}`
  - All tests should pass

  **Spherical-to-cartesian contract:**
  ```gdscript
  # pitch in degrees (negative = above target), yaw in degrees
  var pitch_rad := deg_to_rad(total_pitch)
  var yaw_rad := deg_to_rad(total_yaw)
  var offset := Vector3(
      distance * cos(pitch_rad) * sin(yaw_rad),
      -distance * sin(pitch_rad),
      distance * cos(pitch_rad) * cos(yaw_rad)
  )
  ```

- [x] **Task 2B.3**: Create default orbit resource instance
  - Create `resources/display/vcam/cfg_default_orbit.tres`
  - Set all fields to resource defaults (distance=5.0, authored_pitch=-20.0, authored_yaw=0.0, allow_player_rotation=true, rotation_speed=2.0, fov=75.0)
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_orbit.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeOrbit)
    ```

- [x] **Task 2B.4**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with all new files
  - Verify `u_vcam_mode_evaluator.gd` is in `scripts/managers/helpers/` per file structure
  - Verify test file is in `tests/unit/managers/helpers/`

**Completion notes (March 10, 2026):**
- Added `RS_VCamModeOrbit` resource + resolved-values clamp/sanitation helper with expanded resource tests (`11/11` passing).
- Added `U_VCamModeEvaluator` orbit branch + resolved-value consumption with expanded evaluator coverage (`12/12` orbit assertions, `37/37` evaluator tests passing total).
- Added `cfg_default_orbit.tres`.
- Added `test_vcam_mode_presets.gd` to validate default mode preset loading (`3/3` passing).
- Verified combined mode baseline tests (`test_vcam_mode`, `72/72` passing) and style suite (`15/15` passing).

---

## Phase 2C: Orbit Game Feel

**Depends on:** Phase 6A2 (second-order dynamics in S_VCamSystem) must be complete before implementing orbit feel features.

### Phase 2C1: Look-Ahead (Predictive Offset)

> **Why:** In third-person orbit, the camera trails behind the player. Look-ahead offsets the camera ahead in the movement direction so the player can see more of where they're going. This is an orbit-only concept — first-person cameras ARE the player's eyes and don't need predictive offset.

- [x] **Task 2C1.1**: Add look-ahead fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var look_ahead_distance: float = 0.0` — max world-space offset in the follow target's movement direction (0 = disabled)
    - `@export var look_ahead_smoothing: float = 3.0` — Hz for look-ahead offset second-order dynamics (prevents jitter on direction changes)
  - Add tests verifying fields exist with defaults and non-negative validation
  - **Target: 3 tests**
  - Completion note (2026-03-10): Added `look_ahead_distance` and `look_ahead_smoothing` exports to `RS_VCamResponse`, added resolved-value clamping, and expanded `tests/unit/resources/display/vcam/test_vcam_response.gd` with defaults/clamp coverage.

- [x] **Task 2C1.2 (Red)**: Write tests for look-ahead in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `look_ahead_distance = 0.0`: no offset applied (disabled)
  - Test `look_ahead_distance > 0.0` with moving follow target: camera position shifts in the target's velocity direction
    - Move target from `Vector3(0,0,0)` to `Vector3(5,0,0)` over several ticks
    - Verify camera position is offset ahead (positive X) compared to raw evaluator position
  - Test look-ahead offset magnitude does not exceed `look_ahead_distance`
  - Test look-ahead direction changes smoothly when target reverses (second-order dynamics at `look_ahead_smoothing` Hz prevents snap)
  - Test stationary target produces zero look-ahead offset
  - Test look-ahead resets on mode switch / target change (no stale velocity)
  - Test look-ahead is a no-op for first-person mode (only applies to orbit)
  - **Target: 7 tests**
  - Completion note (2026-03-10): Added 7 look-ahead tests to `test_vcam_system` for disable/enable behavior, movement-direction offset, clamp bounds, stationary zero-offset behavior, mode/target reset, and first-person no-op gating.

- [x] **Task 2C1.3 (Green)**: Implement look-ahead in S_VCamSystem
  - Resolve movement velocity from gameplay snapshots first (`state.gameplay.entities[*].velocity`), with movement-component/body fallback when state is unavailable
  - Do not derive look-ahead direction from follow-target transform deltas (prevents rotation-only offsets on local follow markers)
  - Compute look-ahead offset: `velocity.normalized() * look_ahead_distance` (clamped to `look_ahead_distance`)
  - Smooth the offset through a dedicated `U_SecondOrderDynamics3D` instance (using `look_ahead_smoothing` Hz, critically damped, `r=0.0`)
  - Add smoothed offset to the evaluated camera position BEFORE the main follow dynamics
  - Gate: only apply when active mode is orbit (skip for first-person and fixed)
  - Reset look-ahead dynamics on mode switch / target change
  - All tests should pass
  - Completion note (2026-03-10): `S_VCamSystem` now applies orbit-only look-ahead pre-smoothing with per-vCam state (`_look_ahead_state`), movement-velocity sampling (state first, then component/body fallback), response-driven distance/smoothing tuning, and deterministic state clears on mode/target/disabled paths.

  **Look-ahead integration point:**
  ```gdscript
  # In process_tick, after evaluating ideal pose (orbit mode only):
  var target_velocity := (follow_target.global_position - _prev_target_pos) / delta
  _prev_target_pos = follow_target.global_position
  var ahead_offset := target_velocity.normalized() * resp.look_ahead_distance
  var smooth_ahead := _look_ahead_dynamics[vcam_id].step(ahead_offset, delta)
  # Add to ideal position before main follow dynamics
  raw_result.transform.origin += smooth_ahead
  ```

---

### Phase 2C2: Auto-Level (Horizon Correction)

> **Why:** In orbit mode, the camera can drift to awkward pitch angles after the player stops actively looking. Auto-level gradually returns the camera pitch to the horizon when no look input is active. This is orbit-specific because first-person pitch drift is the player's own view direction (resetting it feels like the game is fighting the player).

- [x] **Task 2C2.1**: Add auto-level fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var auto_level_speed: float = 0.0` — degrees/sec pitch decays toward horizon when no look input active (0 = disabled)
    - `@export var auto_level_delay: float = 1.0` — seconds of zero look input before auto-level begins
  - Add tests verifying fields exist with defaults and non-negative validation
  - **Target: 4 tests**
  - Completion note (2026-03-10): Added `auto_level_speed` and `auto_level_delay` exports + resolved-value non-negative clamps in `RS_VCamResponse`, covered by expanded response tests.

- [x] **Task 2C2.2 (Red)**: Write tests for auto-level in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `auto_level_speed = 0.0`: pitch stays at current value indefinitely (disabled)
  - Test `auto_level_speed > 0.0` with zero look input for > `auto_level_delay` seconds: `runtime_pitch` decays toward `0.0`
  - Test auto-level does NOT activate while look input is non-zero (player is actively looking)
  - Test auto-level delay timer resets each frame that look input is non-zero
  - Test auto-level respects `auto_level_speed` rate (degrees/sec — after 1 second at speed=30, pitch should decay ~30 degrees)
  - Test auto-level is a no-op for first-person and fixed modes
  - **Target: 6 tests**
  - Completion note (2026-03-10): Added 6 auto-level tests to `test_vcam_system` for disable/enable timing, active-look suppression, timer-reset behavior, speed-rate validation, and non-orbit gating.

- [x] **Task 2C2.3 (Green)**: Implement auto-level in S_VCamSystem
  - Track per-vCam `_no_look_input_timer` (float, incremented when look input is zero, reset when non-zero)
  - When timer exceeds `auto_level_delay` and `auto_level_speed > 0.0`:
    - `runtime_pitch = move_toward(runtime_pitch, 0.0, auto_level_speed * delta)`
  - Apply BEFORE evaluator call (pitch is an input to evaluation, not a post-process)
  - Gate: only apply for orbit mode (skip for first-person and fixed)
  - All tests should pass
  - Completion note (2026-03-10): `S_VCamSystem` now tracks per-vCam no-look timers (`_orbit_no_look_input_timers`) and applies orbit-only pitch recentering after configurable delay using `auto_level_speed`, with timer reset on active look input.

---

### Phase 2C3: Projection-Based Soft Zone

> **Why:** Soft zones keep the follow target framed within screen-space bounds, creating cinematic follow behavior in third-person orbit. First-person cameras don't have an external target to frame — the camera IS the player's eyes. This is orbit-only.

**Exit Criteria:** All ~14 soft zone tests pass (10 base + 4 hysteresis), correction is projection-aware with dead zone hysteresis, handles multiple viewport sizes and depths

- [x] **Task 2C3.1 (Red)**: Write tests for U_VCamSoftZone
  - Create `tests/unit/managers/helpers/test_vcam_soft_zone.gd`
  - Test target inside dead zone produces zero correction
  - Test target in soft zone produces damped non-zero correction
  - Test target outside soft zone (hard zone) clamps back inside viewport boundary
  - Test correction magnitude scales with damping parameter
  - Test correction is zero when soft zone resource is null (disabled)
  - Test correction works at different viewport sizes
  - Test correction works at different target depths (near vs far)
  - Test correction direction is toward the nearest allowed zone boundary
  - Test zero-size dead zone means any offset triggers correction
  - Test full-viewport soft zone means no clamping
  - **Target: 10 tests**
  - Completion note (2026-03-10): Added `tests/unit/managers/helpers/test_vcam_soft_zone.gd` with 10 projection/damping/depth/viewport baseline tests plus the 2C4 hysteresis scenarios (14 total helper tests).

- [x] **Task 2C3.2 (Green)**: Implement U_VCamSoftZone
  - Create `scripts/managers/helpers/u_vcam_soft_zone.gd`
  - Implement `static func compute_camera_correction(camera, follow_world_pos, desired_transform, soft_zone, delta) -> Vector3`
  - **Projection method contract:**
    - Use the active gameplay camera viewport inside `GameViewport`; never use the persistent root manager node's viewport for this helper
    - Use `camera.unproject_position(follow_world_pos)` to project the follow target to screen space from the desired camera pose
    - Use `camera.project_position(corrected_screen_point, depth)` to reproject back to world space
    - All zone tests use normalized viewport coordinates (`screen_pos / viewport_size`)
    - **Near-plane guard:** Check `(follow_world_pos - cam_pos).dot(-cam_basis.z) > 0.0` before projecting. If the target is behind the near plane, skip correction for that tick.
    - **Hysteresis state tracking:** `S_VCamSystem` maintains per-vCam `_in_dead_zone: bool` (per axis X/Y) and passes it to the helper. The helper uses `dead_zone + hysteresis_margin` as exit threshold and `dead_zone - hysteresis_margin` as entry threshold to prevent correction toggling at the boundary.
  - Project follow target, test zone membership, reproject correction
  - **Note:** The `damping` field on `RS_VCamSoftZone` controls correction magnitude (how aggressively the camera corrects when the target enters the soft zone). The temporal smoothing of that correction is handled by the second-order dynamics in `S_VCamSystem` (Phase 6A2) — the soft zone helper computes the instantaneous correction vector, and the dynamics smooth the resulting camera position over time.
  - All tests should pass
  - Completion note (2026-03-10): Added `scripts/managers/helpers/u_vcam_soft_zone.gd` with projection-aware correction (`unproject_position` + `project_position`), near-plane guard, damping-scaled soft-zone correction, hard-zone clamp, and optional dead-zone state handoff for hysteresis.

---

### Phase 2C4: Dead Zone Hysteresis

> **Why:** Without hysteresis, a target oscillating exactly at the dead zone boundary causes per-frame correction toggling (jitter). Hysteresis uses slightly different enter/exit thresholds — the dead zone is smaller to enter (correction starts) and larger to exit (correction stops), preventing boundary flutter.

- [x] **Task 2C4.1**: Add `hysteresis_margin` field to RS_VCamSoftZone
  - Modify `scripts/resources/display/vcam/rs_vcam_soft_zone.gd`:
    - `@export var hysteresis_margin: float = 0.02` — fraction of screen space added/subtracted to dead zone for enter/exit thresholds
  - Modify existing tests to verify field exists with default
  - Completion note (2026-03-10): Extended `RS_VCamSoftZone` with `hysteresis_margin` and `get_resolved_values()` clamping; updated `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd` for default/non-negative coverage.

- [x] **Task 2C4.2 (Red)**: Write tests for hysteresis behavior
  - Add to `tests/unit/managers/helpers/test_vcam_soft_zone.gd`
  - Test target crossing OUT OF dead zone boundary: correction starts only after `dead_zone + hysteresis_margin` (stay-in-dead hysteresis)
  - Test target crossing INTO dead zone boundary: correction stops only after `dead_zone - hysteresis_margin` (re-enter-dead hysteresis)
  - Test target oscillating at exact dead zone boundary (alternating +/- epsilon): correction state remains stable (no per-frame toggling)
  - Test `hysteresis_margin = 0.0` behaves identically to non-hysteresis (backward compatible)
  - **Target: 4 tests**
  - Completion note (2026-03-10): Added 4 hysteresis tests to `test_vcam_soft_zone` covering exit-threshold behavior, entry-threshold behavior, oscillation stability, and `hysteresis_margin = 0.0` compatibility.

- [x] **Task 2C4.3 (Green)**: Implement hysteresis in U_VCamSoftZone
  - Track per-axis `_was_in_dead_zone` state (bool pair for X/Y)
  - Use `dead_zone + hysteresis_margin` as exit threshold (stay in dead zone longer)
  - Use `dead_zone - hysteresis_margin` as entry threshold (leave dead zone slightly early)
  - **Note:** `_was_in_dead_zone` is per-call state passed as an optional parameter or tracked externally by `S_VCamSystem` (helper remains stateless)
  - All tests should pass
  - Completion note (2026-03-10): `U_VCamSoftZone` now applies per-axis Schmitt-style dead-zone hysteresis (`exit = dead + margin`, `entry = dead - margin`) with helper-managed state handoff.

---

### Phase 2C5: Soft Zone Integration

- [x] **Task 2C5.1**: Integrate soft-zone correction into S_VCamSystem
  - Modify `scripts/ecs/systems/s_vcam_system.gd`: apply correction to evaluated transform before submitting
  - Gate: only apply when active mode is orbit and component has a soft zone resource
  - Add regression tests to `test_vcam_system.gd`:
    - Test soft zone correction is applied when orbit component has soft zone resource
    - Test no correction when component has no soft zone resource
    - Test no correction when active mode is first-person (even if soft zone resource is set)
  - Completion note (2026-03-10): `S_VCamSystem` now applies orbit-only soft-zone correction before response smoothing using `U_VCamSoftZone`, tracks per-vCam dead-zone state (`_soft_zone_dead_zone_state`), and includes 3 system regression tests for enabled/disabled/non-orbit gating.

---

### Phase 2C6: Ground-Relative Positioning

> **Why:** Orbit camera height tied directly to player/root transform can bob during jumps or jitter on uneven ground. Ground-relative anchoring keeps the camera's vertical reference stable while airborne and only re-anchors when the player lands on meaningfully different terrain.

- [x] **Task 2C6.1**: Add ground-relative fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var ground_relative_enabled: bool = false` — enables dual-anchor ground-relative orbit height behavior
    - `@export var ground_reanchor_min_height_delta: float = 0.5` — minimum landed height delta (meters) required before re-anchoring camera ground baseline
    - `@export var ground_probe_max_distance: float = 12.0` — max downward probe distance used to detect ground reference
    - `@export var ground_anchor_blend_hz: float = 4.0` — smoothing frequency for ground-anchor updates/re-anchors
  - Add tests verifying fields exist, defaults are stable, and resolved-value clamps are non-negative where applicable
  - **Target: 5 tests**
  - Completion note (2026-03-11): Added all four ground-relative exports to `RS_VCamResponse` and extended resolved-value clamping/coverage in `tests/unit/resources/display/vcam/test_vcam_response.gd` (`20/20` passing).

- [x] **Task 2C6.2 (Red)**: Write tests for ground-relative positioning in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test jump bob suppression: while airborne, camera vertical anchor remains stable even when player body/root Y changes
  - Test airborne vertical lock: no per-frame camera Y chase while character remains ungrounded
  - Test thresholded re-anchor: landing on a surface with `height_delta < ground_reanchor_min_height_delta` does not re-anchor
  - Test significant terrain change: landing with `height_delta >= ground_reanchor_min_height_delta` re-anchors smoothly
  - Test uneven terrain stability over short slope/step traversal without micro-bobbing
  - Test non-orbit mode is a strict no-op
  - **Target: 6 tests**
  - Completion note (2026-03-11): Added 6 `2C6` regression tests in `test_vcam_system` covering airborne lock, landing-threshold behavior, uneven-terrain stability, and non-orbit no-op behavior.

- [x] **Task 2C6.3 (Green)**: Implement ground-relative positioning in S_VCamSystem
  - Add per-vCam dual-anchor runtime state (`follow anchor` + `ground anchor`)
  - Resolve grounded state from existing movement/character grounding signals and lock camera vertical anchor while airborne
  - Probe/update ground anchor only when grounded and valid ground reference exists (bounded by `ground_probe_max_distance`)
  - Re-anchor only when landed height delta meets/exceeds `ground_reanchor_min_height_delta`; otherwise preserve previous anchor
  - Smooth anchor changes with dedicated dynamics using `ground_anchor_blend_hz`
  - Gate: orbit mode only, and only when `ground_relative_enabled = true`
  - All tests should pass
  - Completion note (2026-03-11): `S_VCamSystem` now applies orbit-only ground-relative dual-anchor behavior via `_ground_relative_state`, grounded-state resolution (`state.gameplay.entities[*].is_on_floor` first, character/body fallback), grounded-only probe/re-anchor rules, and dedicated anchor blending with `U_SecondOrderDynamics`.

---

### Phase 2C7: Input Smoothing (Enhancement)

> **Why:** Orbit look release can feel abrupt if rotation immediately stops when input drops to zero. A release-damping pass should decelerate rotation naturally, with axis-specific control and explicit stop-threshold clamping to avoid drift.

- [ ] **Task 2C7.1**: Add look-release damping fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var look_release_yaw_damping: float = 10.0` — damping applied to yaw velocity after look input release
    - `@export var look_release_pitch_damping: float = 12.0` — damping applied to pitch velocity after look input release
    - `@export var look_release_stop_threshold: float = 0.05` — absolute velocity threshold below which release velocity snaps to zero
  - Add tests verifying field defaults and non-negative resolved-value clamping
  - **Target: 4 tests**

- [ ] **Task 2C7.2 (Red)**: Write tests for look-release smoothing in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test natural deceleration after look input release (no hard stop in one frame)
  - Test asymmetric damping: yaw and pitch settle at different rates when damping values differ
  - Test stop threshold: near-zero rotational velocity clamps to zero and does not drift
  - Test orbit-only gating (first-person/fixed remain unchanged by this orbit pass)
  - **Target: 4 tests**

- [ ] **Task 2C7.3 (Green)**: Implement look-release smoothing enhancement in S_VCamSystem
  - Reuse existing look-smoothing velocity state (`yaw_velocity` / `pitch_velocity`) rather than introducing a replacement pipeline
  - On look-input release, apply per-axis damping (`look_release_yaw_damping`, `look_release_pitch_damping`) to rotational velocities
  - Clamp small release velocities to zero via `look_release_stop_threshold` to prevent micro-drift
  - Keep runtime yaw/pitch authority and current look-smoothing contracts intact (enhancement only)
  - Gate: orbit mode only
  - All tests should pass

---

### Phase 2C8: Camera Centering (Button Only)

> **Why:** Players need a quick orientation recovery action that recenters the camera behind the character without manual stick/mouse correction. This pass adds explicit button-driven recentering only (no idle auto-center behavior).

- [ ] **Task 2C8.1**: Add `camera_center` input action + wiring
  - Add `camera_center` InputMap action in `project.godot`
  - Wire the action through existing input-source/system paths so `S_VCamSystem` can consume a recenter trigger without bypassing the input pipeline
  - Add/adjust input profile coverage tests so bindings and action availability are validated
  - **Target: 3 tests**

- [ ] **Task 2C8.2 (Red)**: Write tests for button recentering in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test pressing center button starts a recenter operation from arbitrary yaw
  - Test centering completes smoothly in ~`0.3s` (interpolated, no snap)
  - Test manual look input is ignored/overridden while centering is active
  - Test re-pressing center during active centering restarts interpolation deterministically from the current runtime pose
  - **Target: 4 tests**

- [ ] **Task 2C8.3 (Green)**: Implement button recentering in S_VCamSystem
  - Add per-vCam centering runtime state (active flag, start yaw/pitch, target yaw, elapsed time)
  - On `camera_center` trigger, compute target yaw that places camera behind player/follow heading and start a ~`0.3s` interpolation window
  - While centering is active, suppress manual look-driven runtime rotation updates for that vCam
  - Support safe restart/cancel semantics when recenter is triggered again mid-operation
  - Explicitly do not add idle/timer-based auto-centering in this phase
  - All tests should pass

---

### Phase 2C9: RS_RoomFadeSettings Resource + C_RoomFadeGroupComponent (Data Layer)

> **Why:** Xenogears-style room wall/ceiling fading: when the orbit camera looks at the back side of a wall or ceiling, that geometry alpha-dissolves so the player remains visible. This complements (not replaces) Phase 10 silhouette occlusion — walls/ceilings use room fading, other occluders use silhouettes.

**Exit Criteria:** All ~18 tests pass (7 resource + 11 component), resource exposes resolved values, component collects mesh targets and provides world-space fade normal

- [ ] **Task 2C9.1 (Red)**: Write tests for RS_RoomFadeSettings resource
  - Create `tests/unit/resources/display/vcam/test_room_fade_settings.gd`
  - Test `fade_dot_threshold` field exists with default (e.g. `0.3`)
  - Test `fade_speed` field exists with default (e.g. `4.0`)
  - Test `min_alpha` field exists with default (e.g. `0.05`)
  - Test `fade_dot_threshold` is clamped to `0.0..1.0` by `get_resolved_values()`
  - Test `fade_speed` is clamped non-negative by `get_resolved_values()`
  - Test `min_alpha` is clamped to `0.0..1.0` by `get_resolved_values()`
  - Test `get_resolved_values()` returns dictionary with all expected keys
  - **Target: 7 tests**

- [ ] **Task 2C9.2 (Green)**: Implement RS_RoomFadeSettings resource
  - Create `scripts/resources/display/vcam/rs_room_fade_settings.gd`
  - Extend `Resource`
  - Add `class_name RS_RoomFadeSettings`
  - All `@export` fields with sensible defaults:
    - `fade_dot_threshold: float = 0.3` — dot product threshold above which geometry begins fading (camera looking at back side)
    - `fade_speed: float = 4.0` — alpha change rate per second
    - `min_alpha: float = 0.05` — minimum alpha when fully faded (never fully invisible for visual grounding)
  - Implement `get_resolved_values() -> Dictionary` with clamped outputs
  - All tests should pass

- [ ] **Task 2C9.3 (Red)**: Write tests for C_RoomFadeGroupComponent
  - Create `tests/unit/ecs/components/test_room_fade_group_component.gd`
  - Test `group_tag` field exists with default `StringName("")`
  - Test `fade_normal` field exists with default `Vector3(0, 0, -1)` (outward-facing wall normal in local space)
  - Test `settings` field accepts `RS_RoomFadeSettings` resource (nullable)
  - Test `current_alpha` initializes to `1.0` (fully opaque)
  - Test `COMPONENT_TYPE` is `StringName("RoomFadeGroup")`
  - Test `collect_mesh_targets()` returns `Array[MeshInstance3D]` from sibling/child hierarchy
  - Test `collect_mesh_targets()` skips nodes without valid mesh resources
  - Test `get_fade_normal_world()` returns `fade_normal` transformed by the component's parent global basis
  - Test `get_fade_normal_world()` returns normalized vector even if `fade_normal` is not unit length
  - Test component extends `BaseECSComponent`
  - Test `get_snapshot()` includes `group_tag`, `fade_normal`, `current_alpha`
  - **Target: 11 tests**

- [ ] **Task 2C9.4 (Green)**: Implement C_RoomFadeGroupComponent
  - Create `scripts/ecs/components/c_room_fade_group_component.gd`
  - Extend `BaseECSComponent`
  - Add `class_name C_RoomFadeGroupComponent`
  - `const COMPONENT_TYPE := StringName("RoomFadeGroup")`
  - Exports:
    - `group_tag: StringName = &""` — optional tag for grouping multiple fade surfaces
    - `fade_normal: Vector3 = Vector3(0, 0, -1)` — authored outward-facing normal in local space
    - `settings: RS_RoomFadeSettings` — per-group tuning (nullable, system uses default if null)
  - Runtime state:
    - `current_alpha: float = 1.0` — current fade alpha (1.0 = opaque, min_alpha = faded)
  - Methods:
    - `collect_mesh_targets() -> Array[MeshInstance3D]` — recursively gathers mesh instances from parent entity
    - `get_fade_normal_world() -> Vector3` — transforms `fade_normal` by parent global basis, normalized
    - `get_snapshot() -> Dictionary` — includes `group_tag`, `fade_normal`, `current_alpha`
  - All tests should pass

- [ ] **Task 2C9.5**: Create default RS_RoomFadeSettings resource instance
  - Create `resources/display/vcam/cfg_default_room_fade.tres`
  - Set all fields to resource defaults (`fade_dot_threshold=0.3`, `fade_speed=4.0`, `min_alpha=0.05`)
  - Verify resource loads without errors

- [ ] **Task 2C9.6**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with all new files
  - Verify file naming follows conventions (`rs_` prefix for resource, `c_` prefix for component)
  - Verify scripts are in correct directories per style guide

---

### Phase 2C10: S_RoomFadeSystem + U_RoomFadeMaterialApplier + Shader (Logic + Rendering)

> **Why:** The system computes per-group fade decisions based on camera-vs-wall dot product, the material applier manages shader overrides for alpha dissolve, and the shader provides the classic Xenogears translucent wall aesthetic.

**Exit Criteria:** All ~16 tests pass (6 material applier + 10 system), system runs after camera evaluation, shader produces correct alpha dissolve

> **Architecture note:** `S_RoomFadeSystem` is a standalone system, NOT inside `S_VCamSystem`. Room fading consumes camera output (rendering concern), it doesn't produce camera transforms. `S_VCamSystem` is already 2900+ lines. Separate system enables isolated testing. `execution_priority` must be set after `S_VCamSystem` to ensure camera transform is evaluated before fade decisions.

- [ ] **Task 2C10.1**: Create `sh_room_fade.gdshader`
  - Create `assets/shaders/sh_room_fade.gdshader`
  - Spatial shader with `blend_mix`, `depth_draw_opaque`
  - Uniforms:
    - `uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;`
    - `uniform sampler2D albedo_texture : source_color;`
    - `uniform vec4 albedo_color : source_color = vec4(1.0);`
  - Fragment:
    - Sample albedo texture and multiply by `albedo_color`
    - Set `ALPHA = fade_alpha * base_alpha`
    - Use `ALPHA_SCISSOR_THRESHOLD` for clean cutoff at very low alpha
  - Render priority hint for correct transparency sorting

- [ ] **Task 2C10.2 (Red)**: Write tests for U_RoomFadeMaterialApplier
  - Create `tests/unit/lighting/test_room_fade_material_applier.gd`
  - Test `apply_fade_material()` replaces original material with `ShaderMaterial` using `sh_room_fade.gdshader`
  - Test `apply_fade_material()` carries forward `albedo_texture` from original `StandardMaterial3D`
  - Test `apply_fade_material()` caches original material for restoration
  - Test `update_fade_alpha()` sets `fade_alpha` uniform on applied shader material
  - Test `restore_original_materials()` restores cached originals and clears cache
  - Test `restore_original_materials()` is safe to call when no materials are cached (no-op)
  - **Target: 6 tests**

- [ ] **Task 2C10.3 (Green)**: Implement U_RoomFadeMaterialApplier
  - Create `scripts/utils/lighting/u_room_fade_material_applier.gd`
  - Add `class_name U_RoomFadeMaterialApplier`
  - Follow `U_CharacterLightingMaterialApplier` pattern:
    - Cache original `material_override` per `MeshInstance3D` (dictionary keyed by instance ID) — note: this caches `material_override` only, not per-surface-slot materials
    - Resolve source material for albedo texture extraction using priority: `material_override` → surface override materials → mesh built-in surface materials (same as `U_CharacterLightingMaterialApplier._resolve_source_material()`)
    - `apply_fade_material(targets: Array[MeshInstance3D])` — for each target, cache original `material_override`, create `ShaderMaterial` with `sh_room_fade.gdshader`, carry forward `albedo_texture` from resolved source material, set as `material_override`
    - `update_fade_alpha(targets: Array[MeshInstance3D], alpha: float)` — set `fade_alpha` uniform on each target's current shader material
    - `restore_original_materials(targets: Array[MeshInstance3D])` — restore cached `material_override` values, clear cache entries
  - All tests should pass

- [ ] **Task 2C10.4 (Red)**: Write tests for S_RoomFadeSystem
  - Add to `tests/unit/ecs/systems/test_room_fade_system.gd`
  - Test system discovers `C_RoomFadeGroupComponent` instances via ECS manager
  - Test dot product computation: `dot(-camera_basis.z, fade_normal_world)` above threshold triggers fade-down
  - Test dot product below threshold triggers fade-up (restore toward opaque)
  - Test `current_alpha` decreases at `fade_speed` rate per second when fading
  - Test `current_alpha` increases at `fade_speed` rate per second when restoring
  - Test `current_alpha` clamps to `[min_alpha, 1.0]` range
  - Test system uses default `RS_RoomFadeSettings` when component `settings` is null
  - Test system is a no-op when no `C_RoomFadeGroupComponent` instances exist
  - Test system is a no-op when active camera mode is not orbit (first-person/fixed restore all faded geometry immediately)
  - Test mode switch from orbit to non-orbit restores all groups to `current_alpha = 1.0`
  - **Target: 10 tests**

- [ ] **Task 2C10.5 (Green)**: Implement S_RoomFadeSystem
  - Create `scripts/ecs/systems/s_room_fade_system.gd`
  - Extend `BaseECSSystem`
  - Add `class_name S_RoomFadeSystem`
  - `execution_priority` after `S_VCamSystem` (e.g. `110`)
  - In `process_tick(delta)`:
    - Read active camera transform from the live `Camera3D` node via `camera_manager` service (`camera_manager.get_main_camera().global_transform`), with `get_viewport().get_camera_3d()` fallback (camera transform is NOT in Redux state — it lives on the node)
    - Read active camera mode from Redux `state.vcam` to gate orbit-only behavior
    - Query all `C_RoomFadeGroupComponent` instances
    - For each group:
      - Compute `dot(-camera_basis.z, component.get_fade_normal_world())`
      - If dot > `fade_dot_threshold` (camera looking at back side): decrease `current_alpha` toward `min_alpha` at `fade_speed * delta`
      - Else: increase `current_alpha` toward `1.0` at `fade_speed * delta`
      - Clamp `current_alpha` to `[min_alpha, 1.0]`
      - Update material alpha via `U_RoomFadeMaterialApplier`
    - Non-orbit mode: restore all groups to `1.0` immediately
  - Lazy-init material applier state on first tick per component
  - All tests should pass

- [ ] **Task 2C10.6**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with all new files
  - Verify system naming follows `s_` prefix convention
  - Verify utility naming follows `u_` prefix convention
  - Verify shader is in `assets/shaders/`

---

### Phase 2C11: Integration + Polish

> **Why:** Verify room fading works end-to-end with multiple groups, ceiling support, mode switching, and coexistence with silhouette occlusion. Ensure mobile compatibility and document scene template wiring.

**Exit Criteria:** All ~7 integration tests pass, no regressions in existing orbit/silhouette tests

- [ ] **Task 2C11.1 (Red)**: Write integration tests
  - Create `tests/unit/ecs/systems/test_room_fade_integration.gd`
  - Test orbit-only gating: room fade is active in orbit mode, inactive in first-person/fixed
  - Test multi-group independence: two groups with different normals fade independently based on camera angle
  - Test ceiling support: group with `fade_normal = Vector3(0, -1, 0)` (downward-facing ceiling normal) fades when camera looks up
  - Test mode-switch cleanup: switching from orbit to first-person restores all groups to opaque within one tick
  - Test coexistence with silhouette occlusion: room fade components and silhouette occluders can exist simultaneously without conflict
  - Test per-group settings override: group A uses custom `RS_RoomFadeSettings` while group B uses default; each respects its own tuning
  - Test material restoration completeness: after full restore, mesh materials match their original pre-fade state
  - **Target: 7 tests**

- [ ] **Task 2C11.2 (Green)**: Fix any failing integration tests
  - Address edge cases discovered during integration testing
  - Verify no regressions in existing orbit tests (`test_vcam_system.gd`, `test_vcam_soft_zone.gd`)
  - Verify no regressions in silhouette occlusion tests
  - All tests should pass

- [ ] **Task 2C11.3**: Scene template wiring documentation
  - Document how to add `C_RoomFadeGroupComponent` to wall/ceiling meshes in gameplay scenes
  - Document `S_RoomFadeSystem` placement in `Systems/Core` with correct `execution_priority`
  - Document `fade_normal` authoring conventions (outward-facing, local space)
  - Note: actual scene wiring deferred to runtime integration phase

- [ ] **Task 2C11.4**: Mobile compatibility verification
  - Verify `sh_room_fade.gdshader` compiles on mobile renderers (Compatibility / Mobile)
  - Verify `cfg_default_room_fade.tres` loads without runtime directory scanning (preload-safe)
  - Verify material applier handles mobile shader fallback gracefully

- [ ] **Task 2C11.5**: Run full regression gate
  - All Phase 2C9 tests pass (~18)
  - All Phase 2C10 tests pass (~16)
  - All Phase 2C11 integration tests pass (~7)
  - All existing orbit tests pass (no regressions)
  - Style enforcement passes
  - **Total new tests: ~41**

---

### Manual Validation (Orbit Game Feel)

- [ ] **MT-24**: Player in dead zone: camera does not move
- [ ] **MT-25**: Player in soft zone: camera follows with damped lag
- [ ] **MT-26**: Player near screen edge: camera corrects to keep player in frame
- [ ] **MT-81**: Look-ahead active while sprinting: camera leads slightly ahead of player movement direction
- [ ] **MT-82**: Look-ahead direction reversal: when player reverses, look-ahead offset smoothly swings to new direction (no snap)
- [ ] **MT-83**: Look-ahead stationary: when player stops, look-ahead offset settles back to zero
- [ ] **MT-84**: Look-ahead disabled (distance=0): no offset applied, camera centered on follow target
- [ ] **MT-85**: Auto-level active: after 2 seconds of no look input, camera pitch slowly returns to horizon
- [ ] **MT-86**: Auto-level interrupted: player provides look input during auto-level, auto-level stops immediately and delay timer resets
- [ ] **MT-87**: Auto-level disabled (speed=0): pitch stays wherever the player left it indefinitely
- [ ] **MT-95**: Dead zone hysteresis: target oscillating at dead zone boundary does NOT cause per-frame correction jitter
- [ ] **MT-107**: Ground-relative jump stability: camera vertical anchor remains stable while player jumps/airborne
- [ ] **MT-108**: Ground-relative minor landing delta: no re-anchor when landing height change is below threshold
- [ ] **MT-109**: Ground-relative major landing delta: smooth re-anchor when landing height change exceeds threshold
- [ ] **MT-110**: Release smoothing deceleration: camera rotation eases out naturally after look input release
- [ ] **MT-111**: Asymmetric release damping: yaw and pitch settle at distinct configured rates
- [ ] **MT-112**: Release stop threshold: near-zero rotational velocity clamps cleanly to zero (no drift)
- [ ] **MT-113**: Button recenter start: pressing `camera_center` begins behind-player recenter from arbitrary yaw
- [ ] **MT-114**: Button recenter interpolation: camera aligns behind player in ~`0.3s` with no visible snap
- [ ] **MT-115**: Button recenter restart: pressing `camera_center` again during recenter restarts deterministically
- [ ] **MT-116**: Room fade basic: orbit camera behind a wall causes that wall to alpha-dissolve, player remains visible
- [ ] **MT-117**: Room fade restore: moving orbit camera to front of wall restores full opacity smoothly
- [ ] **MT-118**: Room fade ceiling: looking up in orbit mode fades ceiling geometry with downward-facing normal
- [ ] **MT-119**: Room fade multi-group: two adjacent walls with different normals fade independently based on camera angle
- [ ] **MT-120**: Room fade mode switch: switching from orbit to first-person immediately restores all faded geometry to opaque
- [ ] **MT-121**: Room fade min alpha: fully faded wall still shows faint geometry at `min_alpha` (not fully invisible)
- [ ] **MT-122**: Room fade speed: adjusting `fade_speed` in settings changes how quickly walls dissolve and restore
- [ ] **MT-123**: Room fade coexistence: silhouette occlusion and room fade both active simultaneously without visual conflict
- [ ] **MT-124**: Room fade mobile: wall fading shader renders correctly on mobile/Compatibility renderer

---

### Cross-Cutting Checks (Orbit Game Feel)

- [ ] Verify look-ahead reads movement velocity from gameplay state snapshots first, with movement-component/body fallback, and does NOT use follow-target transform deltas
- [ ] Verify look-ahead offset is smoothed through its own `U_SecondOrderDynamics3D` instance (not the main follow dynamics)
- [ ] Verify look-ahead is gated to orbit mode only (no-op for first-person and fixed)
- [ ] Verify auto-level only activates after `auto_level_delay` seconds of zero look input (not immediately)
- [ ] Verify auto-level is gated to orbit mode only (no-op for first-person and fixed)
- [ ] Verify soft zone correction is gated to orbit mode only
- [ ] Verify dead zone hysteresis margin is backward compatible (`hysteresis_margin = 0.0` produces identical behavior to no hysteresis)
- [ ] Verify ground-relative mode locks vertical anchor while airborne and does not chase per-frame player Y motion during jumps
- [ ] Verify ground-relative re-anchor occurs only when landed terrain height delta meets/exceeds `ground_reanchor_min_height_delta`
- [ ] Verify ground-anchor updates are smoothed using `ground_anchor_blend_hz` and bounded by `ground_probe_max_distance`
- [ ] Verify look-release damping uses axis-specific controls (`look_release_yaw_damping`, `look_release_pitch_damping`) and stop-threshold clamp (`look_release_stop_threshold`)
- [ ] Verify `camera_center` trigger flows through the shared input pipeline and does not bypass `S_InputSystem`/state-driven input contracts
- [ ] Verify centering remains button-only in this phase (no idle auto-center timer behavior)
- [ ] Verify `S_RoomFadeSystem` is a standalone system with `execution_priority` after `S_VCamSystem` (not embedded inside `S_VCamSystem`)
- [ ] Verify room fade dot product uses `dot(-camera_basis.z, wall_outward_normal)` convention (positive = camera looking at back side)
- [ ] Verify `C_RoomFadeGroupComponent.fade_normal` is author-placed in local space, not auto-detected from mesh geometry
- [ ] Verify `U_RoomFadeMaterialApplier` caches original materials and restores them cleanly on cleanup (follows `U_CharacterLightingMaterialApplier` pattern)
- [ ] Verify room fading is orbit-only gated: first-person/fixed modes restore all faded geometry immediately
- [ ] Verify room fading coexists with Phase 10 silhouette occlusion without material/shader conflicts
- [ ] Verify `sh_room_fade.gdshader` uses `blend_mix` + `depth_draw_opaque` + `ALPHA_SCISSOR_THRESHOLD` for correct transparency
- [ ] Verify `cfg_default_room_fade.tres` uses `const` preload pattern for mobile compatibility (no runtime directory scanning)
- [ ] Verify `current_alpha` is clamped to `[min_alpha, 1.0]` and never reaches `0.0` (always slightly visible for visual grounding)

---

### Cross-Cutting Checks (Orbit)

- [ ] Verify `RS_VCamModeOrbit` resource can be assigned to `C_VCamComponent.mode` export (type compatibility)
- [ ] Verify orbit evaluator does not import or depend on any scene-tree nodes beyond the passed `follow_target`
- [ ] Verify evaluator is fully static (no instance state, no side effects)
- [ ] Verify `cfg_default_orbit.tres` loads on both desktop and mobile (no runtime directory scanning)
- [ ] Verify orbit evaluation handles edge case: `authored_pitch = -90.0` (straight down) without gimbal lock crash
- [ ] Verify orbit evaluation handles edge case: `authored_pitch = 0.0` (level) produces correct horizontal orbit
- [ ] Verify `rotation_speed` field exists on resource but is NOT consumed by the evaluator (consumed later by `S_VCamSystem` in Phase 6)

---

### Manual Validation (Desktop — Orbit)

These checks gate Phase 6C completion for orbit mode:

- [ ] **MT-01**: Orbit camera follows player at configured distance and pitch
  - Launch game, verify camera maintains orbit distance from player
  - Move player, verify camera follows at constant offset
  - Change `distance` in resource, verify offset changes
- [ ] **MT-02**: Orbit camera rotates horizontally with mouse/right-stick look input
  - Move mouse horizontally, verify camera orbits around player on Y axis
  - Use right stick on gamepad, verify same behavior
  - Verify rotation speed matches `rotation_speed` resource value
- [ ] **MT-03**: Orbit camera rotates vertically with mouse/right-stick look input (pitch clamped)
  - Move mouse vertically, verify camera adjusts pitch angle
  - Verify pitch does not go below horizon or above directly overhead (reasonable clamping)
  - Verify camera always looks at the follow target during pitch changes
- [ ] **MT-04**: Orbit camera with `allow_player_rotation = false` stays at authored angle
  - Set `allow_player_rotation = false` on the orbit resource
  - Move mouse/right-stick, verify camera does NOT rotate
  - Verify camera stays locked at `authored_pitch` and `authored_yaw`

### Manual Validation (Mobile — Orbit)

These checks gate Phase 7D completion for orbit mode:

- [ ] **MT-05**: Orbit camera on mobile: drag-look rotates camera horizontally
  - Touch and drag on empty screen area (not joystick/buttons)
  - Verify camera orbits horizontally around player
  - Verify drag speed matches `look_drag_sensitivity` setting
- [ ] **MT-06**: Orbit camera on mobile: drag-look rotates camera vertically
  - Touch and drag vertically on empty screen area
  - Verify camera adjusts pitch angle
  - Verify pitch clamping works on mobile
- [ ] **MT-07**: Orbit camera on mobile: simultaneous move joystick + drag-look works
  - Hold move joystick with one finger
  - Drag-look with another finger simultaneously
  - Verify both inputs work independently without conflict
- [ ] **MT-08**: Orbit camera on mobile: pressing button during drag-look does not disrupt
  - Start a drag-look gesture
  - While dragging, press a virtual button (jump/sprint)
  - Verify drag-look continues uninterrupted
  - Verify button press registers correctly

### Manual Validation (Feel — Orbit)

These checks gate Phase 13 cross-mode QA completion:

- [ ] **MT-59**: Switching into orbit keeps expected facing direction (no heading pop)
  - Switch from first-person or fixed to orbit
  - Verify camera lands at expected yaw (carried from first-person, or reseeded from authored for fixed)
  - Verify no single-frame snap to a different heading
- [ ] **MT-60**: Rapid repeated switching into/out of orbit does not pop
  - Toggle orbit ↔ fixed ↔ orbit rapidly
  - Verify every transition is smooth or intentionally authored
- [ ] **MT-61**: Orbit resumes from expected heading after returning from fixed
  - Enter orbit, rotate camera, switch to fixed, switch back to orbit
  - Verify orbit resumes at authored angles (not stale rotation from before the fixed switch)
- [ ] **MT-62**: Orbit follow target disappears / respawns: camera recovers gracefully
  - Remove or free the follow target while orbit is active
  - Verify camera holds last valid pose, does not snap to origin
  - Respawn the target, verify camera resumes following without jerk

---

### Manual Validation (Blend — Orbit)

These checks gate Phase 9F completion:

- [ ] **MT-19**: (see [vcam-fixed-tasks.md](vcam-fixed-tasks.md) — orbit-to-fixed blend is owned by the fixed mode task file)
- [ ] **MT-21**: Switching between two moving orbit cameras blends live (not frozen)
  - Have two orbit cameras following moving targets
  - Switch between them
  - Verify blend shows both cameras' live positions (not a frozen origin transform)
- [ ] **MT-32**: Screen shake during orbit camera works (shake visible, returns to correct position)
  - Trigger screen shake (e.g. via damage) while orbit camera is active
  - Verify shake is visible and feels correct
  - Verify camera returns to correct orbit position after shake completes

---

## Test Commands

```bash
# Run orbit resource tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_orbit -ginclude_subdirs=true -gexit

# Run orbit evaluator tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_vcam_mode_evaluator -ginclude_subdirs=true -gexit

# Run all orbit-related tests together
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit

# Run style enforcement after adding new files
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit

# Run room fade settings resource tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_room_fade_settings -ginclude_subdirs=true -gexit

# Run room fade group component tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/components -gselect=test_room_fade_group_component -ginclude_subdirs=true -gexit

# Run room fade system tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gselect=test_room_fade_system -ginclude_subdirs=true -gexit

# Run room fade material applier tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/lighting -gselect=test_room_fade_material_applier -ginclude_subdirs=true -gexit

# Run room fade integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gselect=test_room_fade_integration -ginclude_subdirs=true -gexit

# Run all room fade tests together
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_room_fade -ginclude_subdirs=true -gexit
```

---

## Common Pitfalls (Orbit)

1. Do not use `mouse_sensitivity` naming in the orbit resource. The input pipeline already scales look input; `rotation_speed` is the per-vCam authored multiplier.
2. Do not consume `rotation_speed` inside the evaluator. The evaluator receives pre-computed `runtime_yaw`/`runtime_pitch`; `rotation_speed` is consumed by `S_VCamSystem` when updating those runtime values (Phase 6).
3. Do not use `look_at()` directly on `Transform3D` — use `Transform3D.IDENTITY.looking_at_from_position()` or construct the basis manually to avoid Godot's `look_at` up-vector restrictions.
4. Do not skip the `allow_player_rotation = false` guard in the evaluator. When disabled, `runtime_yaw` and `runtime_pitch` must be ignored entirely.
5. Do not compute orbit soft-zone projection against the root manager viewport. Always use the active gameplay camera viewport inside `GameViewport`.
6. Do not forget to handle the edge case where `distance` is zero or negative — return `{}` rather than producing NaN transforms.
7. Do not add pitch clamping to the resource or evaluator. Pitch clamping is applied by `S_VCamSystem` when updating `runtime_pitch` on the component (Phase 6). The evaluator trusts whatever pitch values it receives.
8. Do not let ground-relative anchoring sample/overwrite vertical anchor while airborne. Airborne camera height should stay locked until a grounded re-anchor decision is made.
9. Do not implement button recenter as an instantaneous yaw snap. Recenter must interpolate over the authored short duration (~`0.3s`) for orientation continuity.
10. Do not leave release smoothing without a stop threshold. Without velocity clamping near zero, low-amplitude drift can persist after input release.
11. Do not embed room fading logic inside `S_VCamSystem`. Room fading is a rendering concern that consumes camera output; it belongs in a standalone `S_RoomFadeSystem` with `execution_priority` after `S_VCamSystem`.
12. Do not auto-detect fade normals from mesh geometry. Author-placed `fade_normal` on `C_RoomFadeGroupComponent` gives artistic control over which direction triggers fading.
13. Do not use raycasts for room fade decisions. The tagged ECS group approach with authored normals is deterministic and cheaper than per-frame raycasts.
14. Do not let `current_alpha` reach `0.0`. Use `min_alpha` floor so faded geometry remains faintly visible for spatial grounding (classic Xenogears aesthetic).
15. Do not forget to restore materials on mode switch. When switching from orbit to first-person/fixed, all faded groups must immediately restore to `current_alpha = 1.0` and original materials.
16. Do not apply room fade shader to materials that are already `ShaderMaterial` without checking for conflicts with silhouette occlusion shaders. Cache and restore original materials cleanly.
17. Do not compute `get_fade_normal_world()` without normalizing the result. Non-unit `fade_normal` exports would produce incorrect dot product magnitudes.
18. Do not run `S_RoomFadeSystem` before `S_VCamSystem`. The fade system needs the post-evaluation camera transform; running it before camera evaluation produces stale-frame decisions.
19. Do not use `depth_draw_alpha_prepass` in `sh_room_fade.gdshader`. Use `depth_draw_opaque` with `ALPHA_SCISSOR_THRESHOLD` for correct transparency sorting without the prepass overhead.
20. Do not forget mobile compatibility for the shader. Verify `sh_room_fade.gdshader` compiles under the Compatibility renderer, and ensure `cfg_default_room_fade.tres` is preload-safe (no `DirAccess` scanning).

---

## New Files (Room Fade — Phases 2C9/2C10/2C11)

| File | Type | Directory |
|------|------|-----------|
| `rs_room_fade_settings.gd` | Resource script | `scripts/resources/display/vcam/` |
| `cfg_default_room_fade.tres` | Resource instance | `resources/display/vcam/` |
| `c_room_fade_group_component.gd` | Component script | `scripts/ecs/components/` |
| `s_room_fade_system.gd` | System script | `scripts/ecs/systems/` |
| `u_room_fade_material_applier.gd` | Utility script | `scripts/utils/lighting/` |
| `sh_room_fade.gdshader` | Shader | `assets/shaders/` |
| `test_room_fade_settings.gd` | Test | `tests/unit/resources/display/vcam/` |
| `test_room_fade_group_component.gd` | Test | `tests/unit/ecs/components/` |
| `test_room_fade_system.gd` | Test | `tests/unit/ecs/systems/` |
| `test_room_fade_material_applier.gd` | Test | `tests/unit/lighting/` |
| `test_room_fade_integration.gd` | Test | `tests/unit/ecs/systems/` |

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [First-Person Tasks](vcam-fps-tasks.md)
- [Fixed Tasks](vcam-fixed-tasks.md)
- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
