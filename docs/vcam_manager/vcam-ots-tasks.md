# vCam OTS (Over-the-Shoulder) — Task Checklist

**Scope:** RE4-style over-the-shoulder camera mode — resource, evaluator, then OTS-specific game feel (collision avoidance, shoulder sway, landing camera response), and manual validation.

**Depends on:** Phase 2B (orbit evaluator creates `U_VCamModeEvaluator`) must be complete before Phase 3 extends it.

---

## Pre-Implementation Checklist

Before starting Phase 3, verify:

- [x] **PRE-1**: Phase 2 (orbit) is fully complete (all 18 orbit tests pass, evaluator exists and handles orbit mode)
- [x] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections — OTS notes)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeOTS)
  - Read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- [x] **PRE-3**: Understand existing patterns by reading:
  - `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` (resource pattern from Phase 2)
  - `scripts/managers/helpers/u_vcam_mode_evaluator.gd` (evaluator pattern from Phase 2)
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (test pattern from Phase 2)
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (resource test pattern)
- [x] **PRE-4**: Verify branch is `vcam` and working tree is clean
- [x] **PRE-5**: Verify orbit tests still pass before extending the evaluator:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  ```

---

## Per-Phase Documentation Cadence (Mandatory)

- [x] **DOC-1**: After each completed phase, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.  
  - Phase 3A update completed (March 15, 2026): continuation prompt now marks OTS 3A complete and 3B as next target.
  - Phase 3B update completed (March 15, 2026): continuation prompt now marks OTS 3B complete and 3C as next target.
- [x] **DOC-2**: After each completed phase, update this file (`vcam-ots-tasks.md`) with `[x]` marks and completion notes.  
  - Phase 3A checklist + validation notes updated (March 15, 2026).
  - Phase 3B checklist + validation notes updated (March 15, 2026).
- [x] **DOC-3**: Update `AGENTS.md` if OTS evaluation reveals new stable architecture/pattern contracts.  
  - No new AGENTS deltas from 3A; current OTS resource contract already matched implementation targets.
- [x] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with any OTS-specific pitfalls discovered.  
  - No new 3A pitfalls discovered.
- [x] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

---

## Phase 3: OTS Camera Mode

**Exit Criteria:** All ~10 OTS resource tests pass, ~10 evaluator tests pass, default preset created, OTS evaluation produces correct transforms with pitch clamping and shoulder offset (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 3A: RS_VCamModeOTS Resource

- [x] **Task 3A.1 (Red)**: Write tests for RS_VCamModeOTS
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd`
  - Test `shoulder_offset` field exists with default `Vector3(0.3, 1.6, -0.5)`
    - Verify type is `Vector3`
    - Verify default places camera right of, above, and behind entity origin
  - Test `camera_distance` field exists with default `1.8`
    - Verify type is `float`
    - Verify default provides suitable distance behind character
  - Test `look_multiplier` field exists with default `1.0`
    - Verify type is `float`
  - Test `pitch_min` field exists with default `-60.0`
    - Verify type is `float`
    - Verify default is tighter than first-person (RE4-style constraint)
  - Test `pitch_max` field exists with default `50.0`
    - Verify type is `float`
  - Test `fov` field exists with default `60.0`
    - Verify type is `float`
    - Verify tighter than orbit for intimate OTS framing
  - Test `fov` must be within valid range (1.0-179.0)
    - Set fov to 0.0, verify validation rejects or clamps
    - Set fov to 180.0, verify validation rejects or clamps
  - Test `look_multiplier` must be positive
    - Set look_multiplier to 0.0, verify validation rejects
    - Set look_multiplier to -1.0, verify validation rejects
  - Test `pitch_min` < `pitch_max` constraint
    - Set pitch_min = 10.0, pitch_max = -10.0, verify validation catches inversion
  - Test `collision_probe_radius` field exists with default `0.15`
    - Verify type is `float`
  - Added landing-dip baseline coverage (`landing_dip_distance`, `landing_dip_recovery_speed`) to match AGENTS OTS resource contract.
  - **Completion note (March 15, 2026):** `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` added with `16/16` passing.

- [x] **Task 3A.2 (Green)**: Implement RS_VCamModeOTS
  - Create `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamModeOTS`
  - All `@export` fields with sensible defaults:
    - `shoulder_offset: Vector3 = Vector3(0.3, 1.6, -0.5)` — right/up/behind from entity origin
    - `camera_distance: float = 1.8` — distance behind character along offset direction
    - `look_multiplier: float = 1.0` — per-vCam authored rotation multiplier (input is pre-scaled)
    - `pitch_min: float = -60.0` — lowest vertical look angle (degrees, negative = down)
    - `pitch_max: float = 50.0` — highest vertical look angle (degrees, positive = up)
    - `fov: float = 60.0` — authored field of view (tighter than orbit for intimate framing)
    - `collision_probe_radius: float = 0.15` — spherecast radius for collision avoidance
    - `collision_recovery_speed: float = 8.0` — Hz for distance recovery after obstruction clears
    - `shoulder_sway_angle: float = 0.0` — max roll angle in degrees when strafing (0 = disabled)
    - `shoulder_sway_smoothing: float = 6.0` — Hz for sway second-order dynamics
    - `landing_dip_distance: float = 0.0` — authored landing dip magnitude for future OTS feel pass
    - `landing_dip_recovery_speed: float = 6.0` — Hz for landing dip recovery
  - `get_resolved_values()` implemented with clamp/order guarantees (positive look/recovery, ordered pitch bounds, `fov` clamped to `1..179`, non-negative magnitudes).
  - All tests should pass

- [x] **Task 3A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` remains unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 3B: OTS Mode Evaluator

- [x] **Task 3B.1 (Red)**: Write tests for OTS evaluation in U_VCamModeEvaluator
  - Add to existing `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test OTS evaluation returns a valid `transform` key (is `Transform3D`)
  - Test OTS evaluation returns correct `fov` key matching resource (`60.0`)
  - Test OTS evaluation returns `mode_name == "ots"`
  - Test OTS camera is positioned behind and to the side of the follow target:
    - Given follow target at `Vector3(5, 0, 10)` and `shoulder_offset = Vector3(0.3, 1.6, -0.5)`
    - Get follow target position
    - Rotate `shoulder_offset` by `runtime_yaw` around Y axis
    - Camera position = target + rotated offset + back vector * camera_distance
    - Assert `result.transform.origin` is approximately at the expected position
  - Test OTS applies `runtime_yaw` for horizontal rotation
    - Pass `runtime_yaw = 90.0` degrees
    - Verify camera basis has rotated 90 degrees around Y axis
    - Verify shoulder offset rotates with yaw (camera stays behind + beside)
  - Test OTS applies `runtime_pitch` for vertical rotation
    - Pass `runtime_pitch = -30.0` degrees
    - Verify camera looks downward by 30 degrees
  - Test OTS clamps pitch to `pitch_min`/`pitch_max` range
    - Pass `runtime_pitch = -100.0` with `pitch_min = -60.0`
    - Verify actual pitch is clamped to -60.0 degrees
  - Test OTS pitch at min boundary does not exceed
    - Pass `runtime_pitch = -60.0` exactly
    - Verify pitch is exactly at boundary, not overshooting
  - Test OTS pitch at max boundary does not exceed
    - Pass `runtime_pitch = 50.0` exactly
    - Verify pitch is exactly at boundary, not overshooting
  - Test OTS with null follow target returns empty dictionary
  - **Completion note (March 15, 2026):** Added OTS evaluator coverage in `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (`49/49` total) including transform/fov/mode-name contract, yaw/pitch behavior, pitch clamping/boundaries, and null-target guards.

  **Test helper setup pattern:**
  ```gdscript
  # Create a follow target as Node3D at known position
  var follow_target := Node3D.new()
  follow_target.global_transform.origin = Vector3(5, 0, 10)
  add_child(follow_target)

  # Create OTS mode resource with test values
  var mode := RS_VCamModeOTS.new()
  mode.shoulder_offset = Vector3(0.3, 1.6, -0.5)
  mode.camera_distance = 1.8
  mode.look_multiplier = 1.0
  mode.pitch_min = -60.0
  mode.pitch_max = 50.0
  mode.fov = 60.0

  # Evaluate with runtime rotation
  var result := U_VCamModeEvaluator.evaluate(mode, follow_target, null, 45.0, -15.0)
  ```

  **OTS evaluator contract:**
  1. Get follow target position
  2. Rotate `shoulder_offset` by `runtime_yaw` around Y axis
  3. Camera position = target + rotated offset + back vector * camera_distance
  4. Clamp pitch to [pitch_min, pitch_max]
  5. Build basis from yaw + pitch
  6. Return `{transform, fov, mode_name: "ots"}`

- [x] **Task 3B.2 (Green)**: Implement OTS evaluation in U_VCamModeEvaluator
  - Extend `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with OTS branch
  - Handle OTS mode branch:
    - Guard: return `{}` if mode is null or follow_target is null
    - Rotate `shoulder_offset` by `runtime_yaw` around Y axis
    - Camera position = `follow_target.global_position + rotated_offset + back_vector * camera_distance`
    - Clamp runtime_pitch to `[pitch_min, pitch_max]`
    - Build rotation basis:
      - Apply `runtime_yaw` as Y-axis rotation
      - Apply clamped `runtime_pitch` as X-axis rotation
    - Construct `Transform3D` from basis and position
    - Return `{transform = camera_xform, fov = mode.fov, mode_name = "ots"}`
  - All tests should pass
  - Verify orbit tests still pass (no regressions)
  - **Completion note (March 15, 2026):** `U_VCamModeEvaluator` now dispatches `RS_VCamModeOTS` and evaluates OTS using resolved pitch bounds + yaw-rotated shoulder offset + back-distance positioning, returning `{transform, fov, mode_name: "ots"}`.

  **OTS transform construction contract:**
  ```gdscript
  var clamped_pitch := clampf(runtime_pitch, mode.pitch_min, mode.pitch_max)
  var yaw_rad := deg_to_rad(runtime_yaw)
  var pitch_rad := deg_to_rad(clamped_pitch)

  # Rotate shoulder offset by yaw
  var rotated_offset := mode.shoulder_offset.rotated(Vector3.UP, yaw_rad)

  # Build camera basis
  var basis := Basis.IDENTITY
  basis = basis.rotated(Vector3.UP, yaw_rad)
  basis = basis.rotated(basis.x, pitch_rad)

  # Camera position: target + shoulder offset + distance behind
  var back_dir := basis.z  # camera's forward is -Z, so basis.z points backward
  var pos := follow_target.global_position + rotated_offset + back_dir * mode.camera_distance
  var xform := Transform3D(basis, pos)
  ```

- [x] **Task 3B.3**: Create default OTS resource instance
  - Create `resources/display/vcam/cfg_default_ots.tres`
  - Set all fields to resource defaults (shoulder_offset=Vector3(0.3,1.6,-0.5), camera_distance=1.8, look_multiplier=1.0, pitch_min=-60.0, pitch_max=50.0, fov=60.0, collision_probe_radius=0.15, collision_recovery_speed=8.0, shoulder_sway_angle=0.0, shoulder_sway_smoothing=6.0, landing_dip_distance=0.0, landing_dip_recovery_speed=6.0)
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_ots.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeOTS)
    ```
  - **Completion note (March 15, 2026):** Added `resources/display/vcam/cfg_default_ots.tres` and default-preset load assertion in `test_vcam_mode_ots.gd` (`17/17` total).

- [x] **Task 3B.4 (Refactor)**: Review U_VCamModeEvaluator for clarity
  - Review evaluator now that it handles two modes (orbit + OTS)
  - Ensure both mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across modes:
    - Both modes return `{}` for null mode resource
    - Both modes return `{}` for null follow_target
    - Neither mode emits warnings for null resources
  - Verify no shared mutable state between mode evaluations
  - No new functionality, only code quality
  - All existing tests still pass after refactor
  - **Completion note (March 15, 2026):** Added `_resolve_ots_values(...)` helper and kept branch-local pure evaluation with null-safe `{}` behavior to mirror existing orbit/fixed contracts.

- [x] **Task 3B.5**: Run full regression
  - Run orbit resource tests (no regressions)
  - Run orbit evaluator tests (no regressions)
  - Run OTS resource tests
  - Run OTS evaluator tests
  - Run style enforcement tests
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_orbit -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_vcam_mode_evaluator -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_ots -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gselect=test_style_enforcement -ginclude_subdirs=true -gexit
  ```
  - **Completion note (March 15, 2026):**
    - `test_vcam_mode_orbit`: `14/14`
    - `test_vcam_mode_evaluator`: `49/49`
    - `test_vcam_mode_ots`: `17/17`
    - style suite unchanged at known pre-existing HUD inline-theme failure: `16/17` in `scenes/ui/hud/ui_hud_overlay.tscn`

---

## Phase 3C: OTS Game Feel

**Depends on:** Phase 6A2 (second-order dynamics in S_VCamSystem) and Phase 3B (OTS evaluator) must be complete before implementing OTS feel features.

> **Why OTS-specific?** Over-the-shoulder game feel differs from both orbit and first-person. The camera sits behind and beside the character in a tight shoulder view — collision avoidance is critical to prevent wall clipping, shoulder sway provides embodied movement feedback from the third-person perspective, and landing camera response uses distance compression rather than pitch dip since the camera is external to the character.

### Phase 3C1: Collision Avoidance (Most Critical OTS Feature)

> **Why:** The camera sits close behind the character, so wall/obstacle collision is the most visible OTS artifact. A spherecast from the follow target toward the desired camera position detects obstructions, and the camera distance is clamped to prevent clipping. Smooth recovery via second-order dynamics prevents the camera from snapping back when the obstruction clears.

- [ ] **Task 3C1.1**: Add collision avoidance fields to RS_VCamModeOTS
  - Fields already present from 3A.2:
    - `collision_probe_radius: float = 0.15` — spherecast radius for collision avoidance
    - `collision_recovery_speed: float = 8.0` — Hz for distance recovery after obstruction clears
  - Add tests verifying fields exist with defaults
  - Test `collision_probe_radius` must be non-negative
  - Test `collision_recovery_speed` must be positive
  - **Target: ~4 tests**

- [ ] **Task 3C1.2 (Red)**: Write tests for collision avoidance in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test no collision: camera stays at full `camera_distance`
  - Test wall between target and camera: camera distance clamps to hit point minus margin
  - Test spherecast radius: narrow gap smaller than `collision_probe_radius` triggers collision
  - Test minimum distance floor: camera cannot pass through the character (clamp to minimum)
  - Test obstruction clears: camera smoothly recovers to full distance via second-order dynamics
  - Test recovery speed matches `collision_recovery_speed` Hz
  - Test collision avoidance is a no-op for orbit and fixed modes
  - Test collision avoidance uses gameplay `World3D` physics space
  - **Target: ~8 tests**

- [ ] **Task 3C1.3 (Green)**: Implement collision avoidance in S_VCamSystem
  - Spherecast from follow target toward desired camera position
  - If hit, clamp distance to `hit_distance - margin`
  - Smooth recovery via `U_SecondOrderDynamics` at `collision_recovery_speed` Hz
  - Per-vCam `_ots_collision_state` dictionary; uses gameplay `World3D` physics space
  - Minimum distance floor prevents camera passing through character
  - Gate: only apply when active mode is OTS
  - Reset collision state on mode switch
  - All tests should pass

  **Collision avoidance integration point:**
  ```gdscript
  # In process_tick, after evaluating OTS pose:
  var target_pos := follow_target.global_position
  var camera_pos := result.transform.origin
  var cast_dir := (camera_pos - target_pos).normalized()
  var cast_distance := target_pos.distance_to(camera_pos)

  var space := follow_target.get_world_3d().direct_space_state
  var query := PhysicsRayQueryParameters3D.create(target_pos, camera_pos)
  query.collision_mask = collision_mask  # gameplay obstacle layers
  var hit := space.intersect_ray(query)

  if hit:
      var safe_distance := target_pos.distance_to(hit.position) - mode.collision_probe_radius
      safe_distance = maxf(safe_distance, MIN_OTS_DISTANCE)
      _ots_collision_state[vcam_id].target_distance = safe_distance
  else:
      _ots_collision_state[vcam_id].target_distance = mode.camera_distance

  var smooth_distance := _ots_collision_dynamics[vcam_id].step(
      _ots_collision_state[vcam_id].target_distance, delta
  )
  # Reposition camera at smooth_distance along cast direction
  result.transform.origin = target_pos + cast_dir * smooth_distance
  ```

---

### Phase 3C2: Shoulder Sway (Roll on Lateral Movement)

> **Why:** Subtle camera roll when strafing left/right creates a sense of physicality and movement weight from the third-person OTS perspective. Same pattern as the old first-person strafe tilt but renamed and contextualized for OTS. The roll angle is proportional to lateral input, smoothed through second-order dynamics.

- [ ] **Task 3C2.1**: Add shoulder sway fields to RS_VCamModeOTS
  - Fields already present from 3A.2:
    - `shoulder_sway_angle: float = 0.0` — max roll angle in degrees when strafing at full speed (0 = disabled)
    - `shoulder_sway_smoothing: float = 6.0` — Hz for sway second-order dynamics (higher = snappier response)
  - Add tests verifying fields exist with defaults
  - Test `shoulder_sway_angle` must be non-negative
  - **Target: ~3 tests**

- [ ] **Task 3C2.2 (Red)**: Write tests for shoulder sway in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `shoulder_sway_angle = 0.0`: no roll applied (disabled)
  - Test strafing left (negative lateral input): camera rolls in the strafing direction (negative roll)
  - Test strafing right (positive lateral input): camera rolls in the strafing direction (positive roll)
  - Test roll magnitude scales with lateral input strength (partial input = partial sway)
  - Test roll magnitude does not exceed `shoulder_sway_angle`
  - Test sway smoothly returns to zero when lateral input stops (second-order dynamics)
  - Test shoulder sway is a no-op for orbit and fixed modes
  - **Target: ~7 tests**

- [ ] **Task 3C2.3 (Green)**: Implement shoulder sway in S_VCamSystem
  - Read lateral component of `gameplay.move_input` (the X component in the player's local frame)
  - Compute target roll: `lateral_input * shoulder_sway_angle`
  - Smooth through a dedicated `U_SecondOrderDynamics` instance at `shoulder_sway_smoothing` Hz (critically damped)
  - Apply smoothed roll to the evaluated camera basis AFTER yaw/pitch construction
  - Gate: only apply when active mode is OTS
  - Reset sway dynamics on mode switch
  - All tests should pass

  **Shoulder sway integration point:**
  ```gdscript
  # In process_tick, after evaluating OTS pose:
  var lateral_input := move_input.x  # local-frame strafe axis
  var target_roll := lateral_input * mode.shoulder_sway_angle
  var smooth_roll := _shoulder_sway_dynamics[vcam_id].step(target_roll, delta)
  # Apply roll to camera basis
  var roll_rad := deg_to_rad(smooth_roll)
  result_basis = result_basis.rotated(result_basis.z, roll_rad)
  ```

---

### Phase 3C3: Landing Camera Response (External-View Landing Feedback)

> **Why:** While the shared landing impact (Phase 6A3c) applies a camera dip via QB rules to any mode, OTS benefits from an additional external-view landing response — a temporary camera distance reduction on impact that creates a visual "punch-in" effect. This stacks with the shared position dip and screen shake for a layered landing feel, but uses distance compression rather than an embodied pitch dip since the camera is external to the character.

- [ ] **Task 3C3.1**: Add landing response fields to RS_VCamModeOTS
  - Modify `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`:
    - `@export var landing_dip_distance: float = 0.0` — temporary distance reduction on hard landing in world units (0 = disabled)
    - `@export var landing_dip_recovery_speed: float = 6.0` — Hz for distance recovery second-order dynamics
  - Add tests verifying fields exist with defaults
  - **Target: ~2 tests**

- [ ] **Task 3C3.2 (Red)**: Write tests for landing camera response
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `landing_dip_distance = 0.0`: no distance change on landing (disabled)
  - Test landing event with `landing_dip_distance > 0`: camera distance temporarily reduces
  - Test dip magnitude scales with `fall_speed` from landing event (same normalization as shared impact)
  - Test distance recovers toward normal via second-order dynamics at `landing_dip_recovery_speed` Hz
  - Test recovery is critically damped (single smooth return, no distance oscillation)
  - Test landing camera response is a no-op for orbit and fixed modes
  - **Target: ~6 tests**

- [ ] **Task 3C3.3 (Green)**: Implement landing camera response in S_VCamSystem
  - Subscribe to `EVENT_ENTITY_LANDED` (same event as shared landing impact)
  - On landing, set per-vCam `_landing_distance_offset` to `landing_dip_distance * normalized_fall_speed`
  - Each tick, drive `_landing_distance_offset` toward `0.0` via `U_SecondOrderDynamics` at `landing_dip_recovery_speed` Hz (critically damped)
  - Subtract `_landing_distance_offset` from `camera_distance` AFTER collision avoidance
  - Gate: only apply when active mode is OTS
  - All tests should pass

  **Relationship to shared landing impact:**
  - Shared landing impact (Phase 6A3c): vertical position dip (camera drops down) — works in all modes
  - OTS landing camera response (this phase): distance compression (camera pushes in) — OTS only
  - Both stack with screen shake for a three-layer landing feel:
    - Distance punch-in (medium-frequency, visual intensity ramp) — OTS only
    - Position dip (low-frequency, gut-punch) — all modes
    - Screen shake (high-frequency, violent vibration) — all modes

---

### Manual Validation (OTS Game Feel)

- [ ] **MT-96**: Shoulder sway while moving left: camera tilts subtly in strafe direction
- [ ] **MT-97**: Shoulder sway while moving right: camera tilts subtly in strafe direction
- [ ] **MT-98**: Shoulder sway returns to level when lateral input stops (no lingering roll)
- [ ] **MT-99**: Shoulder sway disabled (angle=0): camera stays level during strafing
- [ ] **MT-100**: Collision avoidance: camera pulls in when wall is behind character
- [ ] **MT-101**: Collision avoidance: camera smoothly recovers to full distance when wall clears
- [ ] **MT-102**: Collision avoidance: camera does not clip through thin walls
- [ ] **MT-103**: Collision avoidance: minimum distance floor prevents camera inside character mesh
- [ ] **MT-104**: Landing camera response on hard landing: brief distance compression, springs back smoothly
- [ ] **MT-105**: Landing camera response + shared impact + shake: all three layers visible simultaneously, compound feel
- [ ] **MT-106**: Landing camera response disabled (dip=0): no distance change on landing (shared position dip + shake still work)

---

### Cross-Cutting Checks (OTS Game Feel)

- [ ] Verify collision avoidance spherecast uses gameplay `World3D` physics space
- [ ] Verify collision avoidance minimum distance floor prevents camera passing through character
- [ ] Verify collision avoidance dynamics reset on mode switch (no residual state)
- [ ] Verify shoulder sway is gated to OTS mode only (no-op for orbit and fixed)
- [ ] Verify shoulder sway reads lateral input from the same `gameplay.move_input` used by movement systems
- [ ] Verify shoulder sway dynamics reset on mode switch (no residual roll from previous mode)
- [ ] Verify landing camera response stacks with shared landing impact (both apply simultaneously)
- [ ] Verify landing camera response is gated to OTS mode only
- [ ] Verify all OTS game feel dynamics instances are pre-created and reused (zero per-frame allocations)

---

### Cross-Cutting Checks (OTS)

- [ ] Verify `RS_VCamModeOTS` resource can be assigned to `C_VCamComponent.mode` export (type compatibility)
- [ ] Verify OTS evaluator does not import or depend on any scene-tree nodes beyond the passed `follow_target`
- [ ] Verify evaluator remains fully static (no instance state, no side effects) after adding OTS branch
- [ ] Verify `cfg_default_ots.tres` loads on both desktop and mobile (no runtime directory scanning)
- [ ] Verify OTS evaluation handles edge case: `pitch_min == pitch_max` (locked vertical angle) without crash
- [ ] Verify OTS evaluation handles edge case: `shoulder_offset = Vector3.ZERO` (camera directly behind entity) works correctly
- [ ] Verify `look_multiplier` field exists on resource but is NOT consumed by the evaluator (consumed later by `S_VCamSystem` in Phase 6)
- [ ] Verify pitch clamping happens inside the evaluator, not deferred to `S_VCamSystem`
- [ ] Verify orbit evaluation still works identically after OTS branch is added (no shared state pollution)

---

### Manual Validation (Desktop — OTS)

These checks gate Phase 6C completion for OTS mode:

- [ ] **MT-13**: OTS camera positioned behind and beside player at shoulder offset
  - Launch game with OTS vCam active
  - Verify camera is behind and to one side of the character at configured `shoulder_offset`
  - Move player, verify camera follows at shoulder position
  - Change `shoulder_offset` in resource, verify camera position changes
- [ ] **MT-14**: OTS camera rotates with mouse/right-stick look input
  - Move mouse horizontally, verify camera orbits around character maintaining shoulder offset
  - Move mouse vertically, verify camera pitches up/down
  - Use right stick on gamepad, verify same behavior
  - Verify rotation feels responsive and matches expected speed
- [ ] **MT-15**: OTS camera pitch is clamped at min/max boundaries
  - Look all the way down, verify pitch stops at `pitch_min`
  - Look all the way up, verify pitch stops at `pitch_max`
  - Verify no jitter or oscillation at pitch boundaries
  - Verify camera does not flip upside down
- [ ] **MT-18**: OTS `look_multiplier` scales rotation speed
  - Set `look_multiplier = 0.5`, verify camera rotates at half speed
  - Set `look_multiplier = 2.0`, verify camera rotates at double speed
  - Verify feel is consistent across mouse and gamepad

### Manual Validation (Mobile — OTS)

These checks gate Phase 7D completion for OTS mode:

- [ ] **MT-16**: OTS camera on mobile: drag-look rotates view
  - Touch and drag on empty screen area
  - Verify camera rotates around character maintaining shoulder offset
  - Verify sensitivity matches `look_drag_sensitivity` touchscreen setting
  - Verify `invert_look_y` works when enabled
- [ ] **MT-17**: OTS camera on mobile: simultaneous move + look works
  - Hold move joystick with one finger
  - Drag-look with another finger simultaneously
  - Verify player moves while camera rotates independently
  - Verify no touch ID conflicts or gesture stealing

### Manual Validation (Feel — OTS)

These checks gate Phase 13 cross-mode QA completion:

- [ ] **MT-66**: Entering OTS preserves intended facing direction
  - Switch from orbit to OTS
  - Verify camera yaw carries from orbit (player keeps facing the same world direction)
  - Verify pitch resets to level horizon
- [ ] **MT-67**: Shake recovery lands at correct view direction
  - Trigger screen shake while OTS is active
  - After shake completes, verify camera is at exact pre-shake orientation
  - Verify no accumulated drift from shake offsets
- [ ] **MT-68**: Follow target loss / respawn does not jerk camera
  - Free the follow target while OTS is active
  - Verify camera holds last valid pose
  - Respawn the target, verify camera resumes at shoulder offset without snap

---

### Manual Validation (Blend — OTS)

These checks gate Phase 9F completion:

- [ ] **MT-20**: Switching from fixed to OTS blends smoothly
  - Trigger a vCam switch from fixed to OTS
  - Verify smooth interpolation over `blend_duration`
  - Verify no visible snap or teleport
  - Verify OTS camera lands at correct shoulder-offset position
- [ ] **MT-33**: Screen shake during OTS camera works
  - Trigger screen shake while OTS camera is active
  - Verify shake is visible and feels correct from OTS perspective
  - Verify camera returns to correct position/orientation after shake completes

---

## Test Commands

```bash
# Run OTS resource tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_ots -ginclude_subdirs=true -gexit

# Run evaluator tests (includes orbit + OTS)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_vcam_mode_evaluator -ginclude_subdirs=true -gexit

# Run all mode-related tests together (orbit + OTS)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit

# Run style enforcement after adding new files
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit

# Full regression: all vcam tests so far
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam -ginclude_subdirs=true -gexit
```

---

## Common Pitfalls (OTS)

1. Do not use `mouse_sensitivity` naming. The field is `look_multiplier` — a per-vCam authored multiplier that scales already-processed input from the shared `gameplay.look_input` pipeline.
2. Do not consume `look_multiplier` inside the evaluator. The evaluator receives pre-computed `runtime_yaw`/`runtime_pitch`; `look_multiplier` is consumed by `S_VCamSystem` when updating those runtime values (Phase 6).
3. Do not skip pitch clamping in the evaluator. OTS pitch clamping MUST happen in the evaluator because the pitch min/max values are authored on the mode resource.
4. Do not use `look_at()` for OTS camera construction. Build the basis from yaw + pitch rotations directly to avoid up-vector ambiguity near vertical angles.
5. Do not confuse `pitch_min`/`pitch_max` sign convention. Negative pitch = looking down, positive pitch = looking up. `pitch_min` should be negative, `pitch_max` should be positive.
6. Do not forget collision avoidance on the evaluator output. The evaluator computes the ideal position, and collision avoidance in `S_VCamSystem` clamps the actual distance.
7. Do not forget to verify orbit regression after extending the evaluator. Adding a new branch must not break existing orbit evaluation.
8. Do not perform collision raycasts in the evaluator. Collision avoidance is a system-level concern (`S_VCamSystem`) that needs physics space access, not an evaluator responsibility.

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [Orbit Tasks](vcam-orbit-tasks.md)
- [Fixed Tasks](vcam-fixed-tasks.md)
- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
