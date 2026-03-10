# vCam Orbit — Task Checklist

**Scope:** Orbit camera mode — resource, evaluator, default preset, then later orbit-specific game feel (look-ahead, auto-level, soft zone, hysteresis), and manual validation.

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

**Documentation completion note (March 10, 2026):** Continuation/tasks docs updated and synchronized, AGENTS vCam runtime contracts updated for orbit resolved-values behavior, and no new orbit-specific DEV_PITFALLS additions were required in this pass.

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

- [ ] **Task 2C1.1**: Add look-ahead fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var look_ahead_distance: float = 0.0` — max world-space offset in the follow target's movement direction (0 = disabled)
    - `@export var look_ahead_smoothing: float = 3.0` — Hz for look-ahead offset second-order dynamics (prevents jitter on direction changes)
  - Add tests verifying fields exist with defaults and non-negative validation
  - **Target: 3 tests**

- [ ] **Task 2C1.2 (Red)**: Write tests for look-ahead in S_VCamSystem
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

- [ ] **Task 2C1.3 (Green)**: Implement look-ahead in S_VCamSystem
  - Track follow target velocity via frame-to-frame position delta (do not depend on physics velocity — follow target may not have a body)
  - Compute look-ahead offset: `velocity.normalized() * look_ahead_distance` (clamped to `look_ahead_distance`)
  - Smooth the offset through a dedicated `U_SecondOrderDynamics3D` instance (using `look_ahead_smoothing` Hz, critically damped, r=0.5)
  - Add smoothed offset to the evaluated camera position BEFORE the main follow dynamics
  - Gate: only apply when active mode is orbit (skip for first-person and fixed)
  - Reset look-ahead dynamics on mode switch / target change
  - All tests should pass

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

- [ ] **Task 2C2.1**: Add auto-level fields to RS_VCamResponse
  - Modify `scripts/resources/display/vcam/rs_vcam_response.gd`:
    - `@export var auto_level_speed: float = 0.0` — degrees/sec pitch decays toward horizon when no look input active (0 = disabled)
    - `@export var auto_level_delay: float = 1.0` — seconds of zero look input before auto-level begins
  - Add tests verifying fields exist with defaults and non-negative validation
  - **Target: 4 tests**

- [ ] **Task 2C2.2 (Red)**: Write tests for auto-level in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `auto_level_speed = 0.0`: pitch stays at current value indefinitely (disabled)
  - Test `auto_level_speed > 0.0` with zero look input for > `auto_level_delay` seconds: `runtime_pitch` decays toward `0.0`
  - Test auto-level does NOT activate while look input is non-zero (player is actively looking)
  - Test auto-level delay timer resets each frame that look input is non-zero
  - Test auto-level respects `auto_level_speed` rate (degrees/sec — after 1 second at speed=30, pitch should decay ~30 degrees)
  - Test auto-level is a no-op for first-person and fixed modes
  - **Target: 6 tests**

- [ ] **Task 2C2.3 (Green)**: Implement auto-level in S_VCamSystem
  - Track per-vCam `_no_look_input_timer` (float, incremented when look input is zero, reset when non-zero)
  - When timer exceeds `auto_level_delay` and `auto_level_speed > 0.0`:
    - `runtime_pitch = move_toward(runtime_pitch, 0.0, auto_level_speed * delta)`
  - Apply BEFORE evaluator call (pitch is an input to evaluation, not a post-process)
  - Gate: only apply for orbit mode (skip for first-person and fixed)
  - All tests should pass

---

### Phase 2C3: Projection-Based Soft Zone

> **Why:** Soft zones keep the follow target framed within screen-space bounds, creating cinematic follow behavior in third-person orbit. First-person cameras don't have an external target to frame — the camera IS the player's eyes. This is orbit-only.

**Exit Criteria:** All ~14 soft zone tests pass (10 base + 4 hysteresis), correction is projection-aware with dead zone hysteresis, handles multiple viewport sizes and depths

- [ ] **Task 2C3.1 (Red)**: Write tests for U_VCamSoftZone
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

- [ ] **Task 2C3.2 (Green)**: Implement U_VCamSoftZone
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

---

### Phase 2C4: Dead Zone Hysteresis

> **Why:** Without hysteresis, a target oscillating exactly at the dead zone boundary causes per-frame correction toggling (jitter). Hysteresis uses slightly different enter/exit thresholds — the dead zone is smaller to enter (correction starts) and larger to exit (correction stops), preventing boundary flutter.

- [ ] **Task 2C4.1**: Add `hysteresis_margin` field to RS_VCamSoftZone
  - Modify `scripts/resources/display/vcam/rs_vcam_soft_zone.gd`:
    - `@export var hysteresis_margin: float = 0.02` — fraction of screen space added/subtracted to dead zone for enter/exit thresholds
  - Modify existing tests to verify field exists with default

- [ ] **Task 2C4.2 (Red)**: Write tests for hysteresis behavior
  - Add to `tests/unit/managers/helpers/test_vcam_soft_zone.gd`
  - Test target crossing INTO dead zone boundary: correction stops at `dead_zone + hysteresis_margin` (slightly past boundary)
  - Test target crossing OUT OF dead zone boundary: correction starts at `dead_zone - hysteresis_margin` (slightly before boundary)
  - Test target oscillating at exact dead zone boundary (alternating +/- epsilon): correction state remains stable (no per-frame toggling)
  - Test `hysteresis_margin = 0.0` behaves identically to non-hysteresis (backward compatible)
  - **Target: 4 tests**

- [ ] **Task 2C4.3 (Green)**: Implement hysteresis in U_VCamSoftZone
  - Track per-axis `_was_in_dead_zone` state (bool pair for X/Y)
  - Use `dead_zone + hysteresis_margin` as exit threshold (stay in dead zone longer)
  - Use `dead_zone - hysteresis_margin` as entry threshold (leave dead zone slightly early)
  - **Note:** `_was_in_dead_zone` is per-call state passed as an optional parameter or tracked externally by `S_VCamSystem` (helper remains stateless)
  - All tests should pass

---

### Phase 2C5: Soft Zone Integration

- [ ] **Task 2C5.1**: Integrate soft-zone correction into S_VCamSystem
  - Modify `scripts/ecs/systems/s_vcam_system.gd`: apply correction to evaluated transform before submitting
  - Gate: only apply when active mode is orbit and component has a soft zone resource
  - Add 2 regression tests to `test_vcam_system.gd`:
    - Test soft zone correction is applied when orbit component has soft zone resource
    - Test no correction when component has no soft zone resource
    - Test no correction when active mode is first-person (even if soft zone resource is set)

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

---

### Cross-Cutting Checks (Orbit Game Feel)

- [ ] Verify look-ahead reads follow target velocity from frame-to-frame position delta (does NOT depend on physics body `linear_velocity`)
- [ ] Verify look-ahead offset is smoothed through its own `U_SecondOrderDynamics3D` instance (not the main follow dynamics)
- [ ] Verify look-ahead is gated to orbit mode only (no-op for first-person and fixed)
- [ ] Verify auto-level only activates after `auto_level_delay` seconds of zero look input (not immediately)
- [ ] Verify auto-level is gated to orbit mode only (no-op for first-person and fixed)
- [ ] Verify soft zone correction is gated to orbit mode only
- [ ] Verify dead zone hysteresis margin is backward compatible (`hysteresis_margin = 0.0` produces identical behavior to no hysteresis)

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
