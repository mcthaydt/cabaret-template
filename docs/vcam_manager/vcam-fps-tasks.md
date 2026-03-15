# vCam First-Person — Task Checklist

**Scope:** First-person camera mode — resource, evaluator, evaluator refactor, then later FP-specific game feel (strafe tilt, head bob, landing head dip), and manual validation.

**Depends on:** Phase 2B (orbit evaluator creates `U_VCamModeEvaluator`) must be complete before Phase 3 extends it.

---

## Pre-Implementation Checklist

Before starting Phase 3, verify:

- [x] **PRE-1**: Phase 2 (orbit) is fully complete (all 18 orbit tests pass, evaluator exists and handles orbit mode)
- [x] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections — first-person notes)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeFirstPerson)
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

- [x] **DOC-1**: After Phase 3 completion, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [x] **DOC-2**: After Phase 3 completion, update this file (`vcam-fps-tasks.md`) with `[x]` marks and completion notes.
- [x] **DOC-3**: Update `AGENTS.md` if first-person evaluation reveals new stable architecture/pattern contracts.
- [x] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with any first-person-specific pitfalls discovered.
- [x] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

**Documentation completion note (March 10, 2026):** Continuation/tasks docs are synchronized for Phase 3 completion, AGENTS vCam contracts remain aligned, and no additional first-person-specific DEV_PITFALLS entries were identified in this phase.

---

## Phase 3: First-Person Camera Mode

**Exit Criteria:** All ~18 first-person tests pass (8 resource + 10 evaluator), default preset created, first-person evaluation produces correct transforms with pitch clamping and head offset (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 3A: RS_VCamModeFirstPerson Resource

- [x] **Task 3A.1 (Red)**: Write tests for RS_VCamModeFirstPerson
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

- [x] **Task 3A.2 (Green)**: Implement RS_VCamModeFirstPerson
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

- [x] **Task 3A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 3B: First-Person Mode Evaluator

- [x] **Task 3B.1 (Red)**: Write tests for first-person evaluation in U_VCamModeEvaluator
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

- [x] **Task 3B.2 (Green)**: Implement first-person evaluation in U_VCamModeEvaluator
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

- [x] **Task 3B.3**: Create default first-person resource instance
  - Create `resources/display/vcam/cfg_default_first_person.tres`
  - Set all fields to resource defaults (head_offset=Vector3(0,1.7,0), look_multiplier=1.0, pitch_min=-89.0, pitch_max=89.0, fov=75.0)
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_first_person.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeFirstPerson)
    ```

- [x] **Task 3B.4 (Refactor)**: Review U_VCamModeEvaluator for clarity
  - Review evaluator now that it handles two modes (orbit + first-person)
  - Ensure both mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across modes:
    - Both modes return `{}` for null mode resource
    - Both modes return `{}` for null follow_target
    - Neither mode emits warnings for null resources
  - Verify no shared mutable state between mode evaluations
  - No new functionality, only code quality
  - All existing tests still pass after refactor

- [x] **Task 3B.5**: Run full regression
  - Run orbit resource tests (no regressions)
  - Run orbit evaluator tests (no regressions)
  - Run first-person resource tests
  - Run first-person evaluator tests
  - Run style enforcement tests
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit
  ```

**Completion notes (March 10, 2026):**
- Added `RS_VCamModeFirstPerson` with resolved-value clamping/order helpers for `look_multiplier`, `fov`, and pitch bounds.
- Added first-person resource tests (`8/8` passing).
- Extended `U_VCamModeEvaluator` with first-person evaluation (head-offset position, yaw/pitch basis, evaluator-side pitch clamping, null-safe guards).
- Extended evaluator tests with first-person coverage (`20/20` evaluator tests passing).
- Added `cfg_default_first_person.tres`.
- Verified mode regression suite (`test_vcam_mode`, `36/36` passing) and style suite (`15/15` passing).

---

## Phase 3C: First-Person Game Feel

**Depends on:** Phase 6A2 (second-order dynamics in S_VCamSystem) and Phase 3B (first-person evaluator) must be complete before implementing FP feel features.

> **Why FP-specific?** First-person game feel is fundamentally different from orbit. The camera IS the player's eyes, so effects must feel embodied — physical sensations like tilting into a strafe, head bobbing while walking, and a visceral head dip on landing. Orbit game feel (look-ahead, soft zone, auto-level) is about framing an external target, which is irrelevant when you are the camera.

### Phase 3C1: Strafe Tilt (Roll on Lateral Movement)

> **Why:** Subtle camera roll when strafing left/right creates a strong sense of physicality and speed. Common in modern FPS games (Doom, Titanfall, Mirror's Edge). The roll angle is proportional to lateral input, smoothed through second-order dynamics.

- [x] **Task 3C1.1**: Add strafe tilt fields to RS_VCamModeFirstPerson
  - Modify `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`:
    - `@export var strafe_tilt_angle: float = 0.0` — max roll angle in degrees when strafing at full speed (0 = disabled)
    - `@export var strafe_tilt_smoothing: float = 6.0` — Hz for tilt second-order dynamics (higher = snappier response)
  - Add tests verifying fields exist with defaults
  - Test `strafe_tilt_angle` must be non-negative
  - **Target: 3 tests**

- [x] **Task 3C1.2 (Red)**: Write tests for strafe tilt in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `strafe_tilt_angle = 0.0`: no roll applied (disabled)
  - Test strafing left (negative lateral input): camera rolls in the strafing direction (negative roll)
  - Test strafing right (positive lateral input): camera rolls in the strafing direction (positive roll)
  - Test roll magnitude scales with lateral input strength (partial input = partial tilt)
  - Test roll magnitude does not exceed `strafe_tilt_angle`
  - Test tilt smoothly returns to zero when lateral input stops (second-order dynamics)
  - Test strafe tilt is a no-op for orbit and fixed modes
  - **Target: 7 tests**

- [x] **Task 3C1.3 (Green)**: Implement strafe tilt in S_VCamSystem
  - Read lateral component of `gameplay.move_input` (the X component in the player's local frame)
  - Compute target roll: `lateral_input * strafe_tilt_angle`
  - Smooth through a dedicated `U_SecondOrderDynamics` instance at `strafe_tilt_smoothing` Hz (critically damped)
  - Apply smoothed roll to the evaluated camera basis AFTER yaw/pitch construction
  - Gate: only apply when active mode is first-person
  - Reset tilt dynamics on mode switch
  - All tests should pass

  **Strafe tilt integration point:**
  ```gdscript
  # In process_tick, after evaluating first-person pose:
  var lateral_input := move_input.x  # local-frame strafe axis
  var target_roll := lateral_input * mode.strafe_tilt_angle
  var smooth_roll := _strafe_tilt_dynamics[vcam_id].step(target_roll, delta)
  # Apply roll to camera basis
  var roll_rad := deg_to_rad(smooth_roll)
  result_basis = result_basis.rotated(result_basis.z, roll_rad)
  ```

**Completion notes (March 15, 2026):**
- `RS_VCamModeFirstPerson` now exports `strafe_tilt_angle` and `strafe_tilt_smoothing`; resolved values clamp both fields to non-negative.
- `S_VCamSystem` now reads shared `move_input` from `U_InputSelectors` and applies first-person-only strafe roll via `_apply_first_person_strafe_tilt(...)` after evaluator yaw/pitch construction.
- Strafe tilt runtime state is per-vCam (`_first_person_strafe_tilt_state`) with `U_SecondOrderDynamics` smoothing keyed by `vcam_id`; stale/mode-disabled paths clear state.
- Added/updated coverage:
  - `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`: `11/11` (includes +3 strafe field/default/clamp tests)
  - `tests/unit/ecs/systems/test_vcam_system.gd`: `101/101` (includes +7 strafe tilt behavior tests)
- Style suite unchanged at known pre-existing HUD inline-theme debt: `tests/unit/style/test_style_enforcement.gd` `16/17` (`scenes/ui/hud/ui_hud_overlay.tscn`).

---

### Phase 3C2: Head Bob (Rhythmic Position Oscillation)

> **Why:** Subtle vertical and horizontal oscillation while walking/running creates embodied movement feel. The bob frequency and amplitude scale with movement speed. Uses a simple sine-wave approach driven by distance traveled, not time — so stopping mid-stride freezes the bob naturally.

- [ ] **Task 3C2.1**: Add head bob fields to RS_VCamModeFirstPerson
  - Modify `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`:
    - `@export var head_bob_amplitude: Vector2 = Vector2.ZERO` — vertical (Y) and horizontal (X) bob magnitude in world units (0 = disabled)
    - `@export var head_bob_frequency: float = 2.0` — bob cycles per meter traveled (higher = faster stepping cadence)
    - `@export var head_bob_speed_threshold: float = 0.5` — minimum movement speed to activate bob (avoids micro-drift bob)
  - Add tests verifying fields exist with defaults
  - Test `head_bob_amplitude` components must be non-negative
  - Test `head_bob_frequency` must be positive
  - **Target: 4 tests**

- [ ] **Task 3C2.2 (Red)**: Write tests for head bob in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `head_bob_amplitude = Vector2.ZERO`: no bob applied (disabled)
  - Test moving at speed above threshold: camera position oscillates vertically
  - Test bob amplitude scales with movement speed (faster = larger bob, clamped to `head_bob_amplitude`)
  - Test bob frequency matches `head_bob_frequency` cycles per meter traveled
  - Test stopping mid-stride: bob freezes at current phase (distance-driven, not time-driven)
  - Test speed below `head_bob_speed_threshold`: no bob (avoids micro-drift)
  - Test head bob is a no-op for orbit and fixed modes
  - **Target: 7 tests**

- [ ] **Task 3C2.3 (Green)**: Implement head bob in S_VCamSystem
  - Track per-vCam `_bob_distance_accumulator` (float, incremented by `speed * delta` each tick)
  - Compute bob phase: `_bob_distance_accumulator * head_bob_frequency * TAU`
  - Compute bob offset:
    - Y: `sin(phase) * head_bob_amplitude.y * speed_factor`
    - X: `sin(phase * 0.5) * head_bob_amplitude.x * speed_factor` (half frequency for horizontal sway)
  - `speed_factor`: 0.0 below threshold, ramps to 1.0 at sprint speed
  - Add bob offset to evaluated camera position in local camera space
  - Gate: only apply when active mode is first-person
  - Freeze accumulator when speed is below threshold (preserves phase)
  - Reset accumulator on mode switch
  - All tests should pass

  **Head bob integration point:**
  ```gdscript
  # In process_tick, after evaluating first-person pose:
  var speed := move_input.length() * max_move_speed  # approximate ground speed
  if speed >= mode.head_bob_speed_threshold:
      _bob_distance[vcam_id] += speed * delta
  var phase := _bob_distance[vcam_id] * mode.head_bob_frequency * TAU
  var bob_offset := Vector3(
      sin(phase * 0.5) * mode.head_bob_amplitude.x,
      sin(phase) * mode.head_bob_amplitude.y,
      0.0
  ) * speed_factor
  # Transform bob offset into camera local space
  result.transform.origin += result.transform.basis * bob_offset
  ```

---

### Phase 3C3: Landing Head Dip (FP-Specific Impact)

> **Why:** While the shared landing impact (Phase 6A3c) applies a camera dip via QB rules to any mode, first-person benefits from an additional embodied response — a brief pitch dip (looking down on impact) that recovers via second-order dynamics. This stacks with the shared position dip and screen shake for a layered, visceral landing feel.

- [ ] **Task 3C3.1**: Add landing dip fields to RS_VCamModeFirstPerson
  - Modify `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`:
    - `@export var landing_pitch_dip: float = 0.0` — max pitch dip in degrees on hard landing (0 = disabled, negative = look down)
    - `@export var landing_dip_recovery_speed: float = 6.0` — Hz for pitch recovery second-order dynamics
  - Add tests verifying fields exist with defaults
  - **Target: 2 tests**

- [ ] **Task 3C3.2 (Red)**: Write tests for landing head dip
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `landing_pitch_dip = 0.0`: no pitch offset on landing (disabled)
  - Test landing event with `landing_pitch_dip < 0`: camera pitch dips downward briefly
  - Test dip magnitude scales with `fall_speed` from landing event (same normalization as shared impact)
  - Test pitch recovers toward zero via second-order dynamics at `landing_dip_recovery_speed` Hz
  - Test recovery is critically damped (single smooth return, no pitch oscillation)
  - Test landing head dip is a no-op for orbit and fixed modes
  - **Target: 6 tests**

- [ ] **Task 3C3.3 (Green)**: Implement landing head dip in S_VCamSystem
  - Subscribe to `EVENT_ENTITY_LANDED` (same event as shared landing impact)
  - On landing, set per-vCam `_landing_pitch_offset` to `landing_pitch_dip * normalized_fall_speed`
  - Each tick, drive `_landing_pitch_offset` toward `0.0` via `U_SecondOrderDynamics` at `landing_dip_recovery_speed` Hz (critically damped)
  - Add `_landing_pitch_offset` to `runtime_pitch` AFTER normal pitch computation but BEFORE evaluator
  - Gate: only apply when active mode is first-person
  - All tests should pass

  **4-stage pipeline ordering (FP landing feel):**
  1. **FP pitch dip** (before evaluator): `S_VCamSystem` adds `_landing_pitch_offset` to `runtime_pitch` before calling the evaluator. This rotates the view downward on impact.
  2. **Evaluator**: `U_VCamModeEvaluator.evaluate()` processes the modified `runtime_pitch` as normal input.
  3. **Position offset** (after evaluator): `S_VCamSystem` reads `C_CameraStateComponent.landing_impact_offset` and adds it to the evaluated camera position. This moves the camera down.
  4. **Shake** (after submit): `M_CameraManager` applies shake offsets through `ShakeParent` after `apply_main_camera_transform()`. This vibrates the final result.

  **Relationship to shared landing impact:**
  - Shared landing impact (Phase 6A3c): vertical position dip (camera drops down) — works in all modes (stage 3)
  - FP landing head dip (this phase): pitch rotation dip (camera looks down) — first-person only (stage 1)
  - Both stack with screen shake for a three-layer landing feel:
    - Pitch dip (stage 1, medium-frequency, embodied nod) — FP only
    - Position dip (stage 3, low-frequency, gut-punch) — all modes
    - Screen shake (stage 4, high-frequency, violent vibration) — all modes

---

### Manual Validation (First-Person Game Feel)

- [ ] **MT-96**: Strafe tilt while moving left: camera tilts subtly in strafe direction
- [ ] **MT-97**: Strafe tilt while moving right: camera tilts subtly in strafe direction
- [ ] **MT-98**: Strafe tilt returns to level when lateral input stops (no lingering roll)
- [ ] **MT-99**: Strafe tilt disabled (angle=0): camera stays level during strafing
- [ ] **MT-100**: Head bob while walking: subtle vertical oscillation at walking cadence
- [ ] **MT-101**: Head bob while sprinting: larger amplitude, faster cadence
- [ ] **MT-102**: Head bob stops cleanly when player stops (no drift or jitter)
- [ ] **MT-103**: Head bob disabled (amplitude=0,0): no oscillation during movement
- [ ] **MT-104**: Landing head dip on hard landing: brief downward pitch dip, springs back smoothly
- [ ] **MT-105**: Landing head dip + shared impact + shake: all three layers visible simultaneously, compound feel
- [ ] **MT-106**: Landing head dip disabled (dip=0): no pitch change on landing (shared position dip + shake still work)

---

### Cross-Cutting Checks (First-Person Game Feel)

- [x] Verify strafe tilt is gated to first-person mode only (no-op for orbit and fixed)
- [x] Verify strafe tilt reads lateral input from the same `gameplay.move_input` used by movement systems
- [x] Verify strafe tilt dynamics reset on mode switch (no residual roll from previous mode)
- [ ] Verify head bob is distance-driven, not time-driven (stopping freezes the phase)
- [ ] Verify head bob is gated to first-person mode only
- [ ] Verify head bob speed threshold prevents micro-drift oscillation
- [ ] Verify landing head dip stacks with shared landing impact (both apply simultaneously)
- [ ] Verify landing head dip is gated to first-person mode only
- [ ] Verify all FP game feel dynamics instances are pre-created and reused (zero per-frame allocations)

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
