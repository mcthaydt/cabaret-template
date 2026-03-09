# vCam First-Person — Task Checklist

**Scope:** First-person camera mode — resource, evaluator, evaluator refactor, and manual validation.

**Depends on:** Phase 2B (orbit evaluator creates `U_VCamModeEvaluator`) must be complete before Phase 3 extends it.

---

## Pre-Implementation Checklist

Before starting Phase 3, verify:

- [ ] **PRE-1**: Phase 2 (orbit) is fully complete (all 18 orbit tests pass, evaluator exists and handles orbit mode)
- [ ] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections — first-person notes)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeFirstPerson)
  - Read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- [ ] **PRE-3**: Understand existing patterns by reading:
  - `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` (resource pattern from Phase 2)
  - `scripts/managers/helpers/u_vcam_mode_evaluator.gd` (evaluator pattern from Phase 2)
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (test pattern from Phase 2)
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (resource test pattern)
- [ ] **PRE-4**: Verify branch is `vcam` and working tree is clean
- [ ] **PRE-5**: Verify orbit tests still pass before extending the evaluator:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  ```

---

## Per-Phase Documentation Cadence (Mandatory)

- [ ] **DOC-1**: After Phase 3 completion, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [ ] **DOC-2**: After Phase 3 completion, update this file (`vcam-fps-tasks.md`) with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` if first-person evaluation reveals new stable architecture/pattern contracts.
- [ ] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with any first-person-specific pitfalls discovered.
- [ ] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

---

## Phase 3: First-Person Camera Mode

**Exit Criteria:** All ~18 first-person tests pass (8 resource + 10 evaluator), default preset created, first-person evaluation produces correct transforms with pitch clamping and head offset (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 3A: RS_VCamModeFirstPerson Resource

- [ ] **Task 3A.1 (Red)**: Write tests for RS_VCamModeFirstPerson
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
  - Test `head_offset` field exists with default (e.g. `Vector3(0, 1.7, 0)`)
    - Verify type is `Vector3`
    - Verify default Y is approximately head height above entity origin
  - Test `look_multiplier` field exists with default `1.0`
    - Verify type is `float`
  - Test `pitch_min` field exists with default (e.g. -89.0)
    - Verify type is `float`
    - Verify default allows looking nearly straight down
  - Test `pitch_max` field exists with default (e.g. 89.0)
    - Verify type is `float`
    - Verify default allows looking nearly straight up
  - Test `fov` field exists with default (e.g. 75.0)
    - Verify type is `float`
  - Test `fov` must be within valid range (1.0-179.0)
    - Set fov to 0.0, verify validation rejects or clamps
    - Set fov to 180.0, verify validation rejects or clamps
  - Test `look_multiplier` must be positive
    - Set look_multiplier to 0.0, verify validation rejects
    - Set look_multiplier to -1.0, verify validation rejects
  - Test `pitch_min` < `pitch_max` constraint
    - Set pitch_min = 10.0, pitch_max = -10.0, verify validation catches inversion
  - **Target: 8 tests**

- [ ] **Task 3A.2 (Green)**: Implement RS_VCamModeFirstPerson
  - Create `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamModeFirstPerson`
  - All `@export` fields with sensible defaults:
    - `head_offset: Vector3 = Vector3(0, 1.7, 0)` — offset from entity origin to eye level
    - `look_multiplier: float = 1.0` — per-vCam authored rotation multiplier (input is pre-scaled)
    - `pitch_min: float = -89.0` — lowest vertical look angle (degrees, negative = down)
    - `pitch_max: float = 89.0` — highest vertical look angle (degrees, positive = up)
    - `fov: float = 75.0` — authored field of view
  - All tests should pass

- [ ] **Task 3A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 3B: First-Person Mode Evaluator

- [ ] **Task 3B.1 (Red)**: Write tests for first-person evaluation in U_VCamModeEvaluator
  - Add to existing `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test first-person evaluation returns a valid `transform` key (is `Transform3D`)
  - Test first-person evaluation returns correct `fov` key matching resource (`75.0`)
  - Test first-person evaluation returns `mode_name == "first_person"`
  - Test first-person camera is positioned at follow target + `head_offset`
    - Given follow target at `Vector3(5, 0, 10)` and head_offset `Vector3(0, 1.7, 0)`
    - Assert `result.transform.origin` is approximately `Vector3(5, 1.7, 10)`
  - Test first-person applies `runtime_yaw` for horizontal rotation
    - Pass `runtime_yaw = 90.0` degrees
    - Verify camera basis has rotated 90 degrees around Y axis
    - Verify camera position stays at follow_target + head_offset (rotation is in-place)
  - Test first-person applies `runtime_pitch` for vertical rotation
    - Pass `runtime_pitch = -30.0` degrees
    - Verify camera looks downward by 30 degrees
    - Verify camera position is unchanged (pitch is in-place rotation)
  - Test first-person clamps pitch to `pitch_min`/`pitch_max` range
    - Pass `runtime_pitch = -100.0` with `pitch_min = -89.0`
    - Verify actual pitch is clamped to -89.0 degrees
  - Test first-person pitch at min boundary does not exceed
    - Pass `runtime_pitch = -89.0` exactly
    - Verify pitch is exactly at boundary, not overshooting
  - Test first-person pitch at max boundary does not exceed
    - Pass `runtime_pitch = 89.0` exactly
    - Verify pitch is exactly at boundary, not overshooting
  - Test first-person with null follow target returns empty dictionary
  - **Target: 10 tests**

  **Test helper setup pattern:**
  ```gdscript
  # Create a follow target as Node3D at known position
  var follow_target := Node3D.new()
  follow_target.global_transform.origin = Vector3(5, 0, 10)
  add_child(follow_target)

  # Create first-person mode resource with test values
  var mode := RS_VCamModeFirstPerson.new()
  mode.head_offset = Vector3(0, 1.7, 0)
  mode.look_multiplier = 1.0
  mode.pitch_min = -89.0
  mode.pitch_max = 89.0
  mode.fov = 75.0

  # Evaluate with runtime rotation
  var result := U_VCamModeEvaluator.evaluate(mode, follow_target, null, 45.0, -15.0)
  ```

- [ ] **Task 3B.2 (Green)**: Implement first-person evaluation in U_VCamModeEvaluator
  - Extend `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with first-person branch
  - Handle first-person mode branch:
    - Guard: return `{}` if mode is null or follow_target is null
    - Camera position = `follow_target.global_position + mode.head_offset`
    - Clamp runtime_pitch to `[pitch_min, pitch_max]`
    - Build rotation basis:
      - Apply `runtime_yaw` as Y-axis rotation
      - Apply clamped `runtime_pitch` as X-axis rotation
    - Construct `Transform3D` from basis and position
    - Return `{transform = camera_xform, fov = mode.fov, mode_name = "first_person"}`
  - All tests should pass
  - Verify orbit tests still pass (no regressions)

  **First-person transform construction contract:**
  ```gdscript
  var clamped_pitch := clampf(runtime_pitch, mode.pitch_min, mode.pitch_max)
  var yaw_rad := deg_to_rad(runtime_yaw)
  var pitch_rad := deg_to_rad(clamped_pitch)

  var basis := Basis.IDENTITY
  basis = basis.rotated(Vector3.UP, yaw_rad)
  basis = basis.rotated(basis.x, pitch_rad)

  var pos := follow_target.global_position + mode.head_offset
  var xform := Transform3D(basis, pos)
  ```

- [ ] **Task 3B.3**: Create default first-person resource instance
  - Create `resources/display/vcam/cfg_default_first_person.tres`
  - Set all fields to resource defaults (head_offset=Vector3(0,1.7,0), look_multiplier=1.0, pitch_min=-89.0, pitch_max=89.0, fov=75.0)
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_first_person.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeFirstPerson)
    ```

- [ ] **Task 3B.4 (Refactor)**: Review U_VCamModeEvaluator for clarity
  - Review evaluator now that it handles two modes (orbit + first-person)
  - Ensure both mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across modes:
    - Both modes return `{}` for null mode resource
    - Both modes return `{}` for null follow_target
    - Neither mode emits warnings for null resources
  - Verify no shared mutable state between mode evaluations
  - No new functionality, only code quality
  - All existing tests still pass after refactor

- [ ] **Task 3B.5**: Run full regression
  - Run orbit resource tests (no regressions)
  - Run orbit evaluator tests (no regressions)
  - Run first-person resource tests
  - Run first-person evaluator tests
  - Run style enforcement tests
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit
  ```

---

### Cross-Cutting Checks (First-Person)

- [ ] Verify `RS_VCamModeFirstPerson` resource can be assigned to `C_VCamComponent.mode` export (type compatibility)
- [ ] Verify first-person evaluator does not import or depend on any scene-tree nodes beyond the passed `follow_target`
- [ ] Verify evaluator remains fully static (no instance state, no side effects) after adding first-person branch
- [ ] Verify `cfg_default_first_person.tres` loads on both desktop and mobile (no runtime directory scanning)
- [ ] Verify first-person evaluation handles edge case: `pitch_min == pitch_max` (locked vertical angle) without crash
- [ ] Verify first-person evaluation handles edge case: `head_offset = Vector3.ZERO` (camera at entity origin) works correctly
- [ ] Verify `look_multiplier` field exists on resource but is NOT consumed by the evaluator (consumed later by `S_VCamSystem` in Phase 6)
- [ ] Verify pitch clamping happens inside the evaluator, not deferred to `S_VCamSystem`
- [ ] Verify orbit evaluation still works identically after first-person branch is added (no shared state pollution)

---

### Manual Validation (Desktop — First-Person)

These checks gate Phase 6C completion for first-person mode:

- [ ] **MT-13**: First-person camera positioned at player + head offset
  - Launch game with first-person vCam active
  - Verify camera is at player entity position + configured `head_offset`
  - Move player, verify camera follows at head height
  - Change `head_offset.y` in resource, verify camera height changes
- [ ] **MT-14**: First-person camera rotates with mouse/right-stick look input
  - Move mouse horizontally, verify camera yaws left/right
  - Move mouse vertically, verify camera pitches up/down
  - Use right stick on gamepad, verify same behavior
  - Verify rotation feels responsive and matches expected speed
- [ ] **MT-15**: First-person camera pitch is clamped at min/max boundaries
  - Look all the way down, verify pitch stops at `pitch_min`
  - Look all the way up, verify pitch stops at `pitch_max`
  - Verify no jitter or oscillation at pitch boundaries
  - Verify camera does not flip upside down
- [ ] **MT-18**: First-person `look_multiplier` scales rotation speed
  - Set `look_multiplier = 0.5`, verify camera rotates at half speed
  - Set `look_multiplier = 2.0`, verify camera rotates at double speed
  - Verify feel is consistent across mouse and gamepad

### Manual Validation (Mobile — First-Person)

These checks gate Phase 7D completion for first-person mode:

- [ ] **MT-16**: First-person camera on mobile: drag-look rotates view
  - Touch and drag on empty screen area
  - Verify camera rotates in the dragged direction
  - Verify sensitivity matches `look_drag_sensitivity` touchscreen setting
  - Verify `invert_look_y` works when enabled
- [ ] **MT-17**: First-person camera on mobile: simultaneous move + look works
  - Hold move joystick with one finger
  - Drag-look with another finger simultaneously
  - Verify player moves while camera rotates independently
  - Verify no touch ID conflicts or gesture stealing

### Manual Validation (Feel — First-Person)

These checks gate Phase 13 cross-mode QA completion:

- [ ] **MT-66**: Entering first-person preserves intended facing direction
  - Switch from orbit to first-person
  - Verify camera yaw carries from orbit (player keeps facing the same world direction)
  - Verify pitch resets to level horizon
- [ ] **MT-67**: Shake recovery lands at correct view direction
  - Trigger screen shake while first-person is active
  - After shake completes, verify camera is at exact pre-shake orientation
  - Verify no accumulated drift from shake offsets
- [ ] **MT-68**: Follow target loss / respawn does not jerk camera
  - Free the follow target while first-person is active
  - Verify camera holds last valid pose
  - Respawn the target, verify camera resumes at head offset without snap

---

### Manual Validation (Blend — First-Person)

These checks gate Phase 9F completion:

- [ ] **MT-20**: Switching from fixed to first-person blends smoothly
  - Trigger a vCam switch from fixed to first-person
  - Verify smooth interpolation over `blend_duration`
  - Verify no visible snap or teleport
  - Verify first-person camera lands at correct head-offset position
- [ ] **MT-33**: Screen shake during first-person camera works
  - Trigger screen shake while first-person camera is active
  - Verify shake is visible and feels correct from first-person perspective
  - Verify camera returns to correct position/orientation after shake completes

---

## Test Commands

```bash
# Run first-person resource tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person -ginclude_subdirs=true -gexit

# Run evaluator tests (includes orbit + first-person)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_vcam_mode_evaluator -ginclude_subdirs=true -gexit

# Run all mode-related tests together (orbit + first-person)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit

# Run style enforcement after adding new files
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit

# Full regression: all vcam tests so far
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam -ginclude_subdirs=true -gexit
```

---

## Common Pitfalls (First-Person)

1. Do not use `mouse_sensitivity` naming. The field is `look_multiplier` — a per-vCam authored multiplier that scales already-processed input from the shared `gameplay.look_input` pipeline.
2. Do not consume `look_multiplier` inside the evaluator. The evaluator receives pre-computed `runtime_yaw`/`runtime_pitch`; `look_multiplier` is consumed by `S_VCamSystem` when updating those runtime values (Phase 6).
3. Do not skip pitch clamping in the evaluator. Unlike orbit (where clamping is deferred to `S_VCamSystem`), first-person pitch clamping MUST happen in the evaluator because the pitch min/max values are authored on the mode resource.
4. Do not use `look_at()` for first-person camera construction. Build the basis from yaw + pitch rotations directly to avoid up-vector ambiguity near vertical angles.
5. Do not confuse `pitch_min`/`pitch_max` sign convention. Negative pitch = looking down, positive pitch = looking up. `pitch_min` should be negative, `pitch_max` should be positive.
6. Do not add `head_offset` to the evaluator as a runtime-accumulated value. It is a static authored offset from the entity origin — always applied as-is each frame.
7. Do not forget to verify orbit regression after extending the evaluator. Adding a new branch must not break existing orbit evaluation.

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
