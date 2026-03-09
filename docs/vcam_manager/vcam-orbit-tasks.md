# vCam Orbit — Task Checklist

**Scope:** Orbit camera mode — resource, evaluator, default preset, and manual validation.

**Depends on:** Phase 1 (base resources) must be complete before Phase 2B evaluator tests.

---

## Pre-Implementation Checklist

Before starting Phase 2, verify:

- [ ] **PRE-1**: Phase 0 and Phase 1 are fully complete (all base state, persistence, and authoring resource tests pass)
- [ ] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeOrbit)
  - Read `docs/vcam_manager/vcam-manager-prd.md` (orbit requirements)
  - Read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- [ ] **PRE-3**: Understand existing patterns by reading:
  - `scripts/resources/display/vcam/rs_vcam_soft_zone.gd` (resource pattern from Phase 1)
  - `scripts/resources/display/vcam/rs_vcam_blend_hint.gd` (resource pattern from Phase 1)
  - Any existing `tests/unit/resources/display/vcam/` tests (test pattern from Phase 1)
- [ ] **PRE-4**: Verify branch is `vcam` and working tree is clean

---

## Per-Phase Documentation Cadence (Mandatory)

- [ ] **DOC-1**: After Phase 2 completion, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [ ] **DOC-2**: After Phase 2 completion, update this file (`vcam-orbit-tasks.md`) with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` if orbit evaluation reveals new stable architecture/pattern contracts.
- [ ] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with any orbit-specific pitfalls discovered.
- [ ] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

---

## Phase 2: Orbit Camera Mode

**Exit Criteria:** All ~18 orbit tests pass (8 resource + 10 evaluator), orbit evaluation produces correct transforms for all authored configurations (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 2A: RS_VCamModeOrbit Resource

- [ ] **Task 2A.1 (Red)**: Write tests for RS_VCamModeOrbit
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
  - Test `distance` field exists with default (e.g. 5.0)
  - Test `authored_pitch` field exists with default (e.g. -20.0 degrees)
  - Test `authored_yaw` field exists with default (e.g. 0.0)
  - Test `allow_player_rotation` field exists with default `true`
  - Test `rotation_speed` field exists with default (e.g. 2.0)
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `distance` must be positive (reject zero or negative)
  - Test `fov` must be within valid range (1.0-179.0)
  - **Target: 8 tests**

- [ ] **Task 2A.2 (Green)**: Implement RS_VCamModeOrbit
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

- [ ] **Task 2A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 2B: Orbit Mode Evaluator

- [ ] **Task 2B.1 (Red)**: Write tests for orbit evaluation in U_VCamModeEvaluator
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
  - **Target: 10 tests**

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

- [ ] **Task 2B.2 (Green)**: Implement orbit evaluation in U_VCamModeEvaluator
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

- [ ] **Task 2B.3**: Create default orbit resource instance
  - Create `resources/display/vcam/cfg_default_orbit.tres`
  - Set all fields to resource defaults (distance=5.0, authored_pitch=-20.0, authored_yaw=0.0, allow_player_rotation=true, rotation_speed=2.0, fov=75.0)
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_orbit.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeOrbit)
    ```

- [ ] **Task 2B.4**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with all new files
  - Verify `u_vcam_mode_evaluator.gd` is in `scripts/managers/helpers/` per file structure
  - Verify test file is in `tests/unit/managers/helpers/`

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

- [ ] **MT-19**: Switching from orbit to fixed blends smoothly (no snap)
  - Trigger a vCam switch from orbit to fixed
  - Verify smooth interpolation over `blend_duration`
  - Verify no visible snap or teleport
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
5. Do not forget to handle the edge case where `distance` is zero or negative — return `{}` rather than producing NaN transforms.
6. Do not add pitch clamping to the resource or evaluator. Pitch clamping is applied by `S_VCamSystem` when updating `runtime_pitch` on the component (Phase 6). The evaluator trusts whatever pitch values it receives.

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
