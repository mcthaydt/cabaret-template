# vCam Fixed — Task Checklist

**Scope:** Fixed camera mode — resource, evaluator, and manual validation, with `use_path` helpers staying scene-local in the gameplay world.

**Depends on:** Phase 3B (OTS evaluator extends `U_VCamModeEvaluator`) must be complete before Phase 4B extends it further.

---

## Pre-Implementation Checklist

Before starting Phase 4, verify:

- [x] **PRE-1**: Phase 2 (orbit) and Phase 3 (OTS) are fully complete (all mode tests pass, evaluator handles both modes)
- [x] **PRE-2**: Read required documentation
  - Read `docs/vcam_manager/vcam-manager-plan.md` (Commit 1.1, Commit 2.3 sections — fixed-mode notes)
  - Read `docs/vcam_manager/vcam-manager-overview.md` (Camera Modes > RS_VCamModeFixed)
  - Read `AGENTS.md` (vCam Runtime Contracts — fixed-mode anchor resolution)
  - Read `docs/guides/pitfalls/` and `docs/guides/STYLE_GUIDE.md`
- [x] **PRE-3**: Understand existing patterns by reading:
  - `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` (resource pattern from Phase 2)
  - `scripts/resources/display/vcam/rs_vcam_mode_ots.gd` (resource pattern from Phase 3)
  - `scripts/managers/helpers/u_vcam_mode_evaluator.gd` (evaluator with orbit + OTS branches)
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (existing evaluator tests)
- [x] **PRE-4**: Verify branch is `vcam` and working tree is clean
- [x] **PRE-5**: Verify orbit + OTS tests still pass before extending the evaluator:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  ```

---

## Per-Phase Documentation Cadence (Mandatory)

- [x] **DOC-1**: After Phase 4 completion, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [x] **DOC-2**: After Phase 4 completion, update this file (`vcam-fixed-tasks.md`) with `[x]` marks and completion notes.
- [x] **DOC-3**: Update `AGENTS.md` if fixed evaluation reveals new stable architecture/pattern contracts.
- [x] **DOC-4**: Update `docs/guides/pitfalls/` with any fixed-mode-specific pitfalls discovered.
- [x] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

**Documentation completion note (March 10, 2026):** Continuation/tasks docs are synchronized for Phase 4 completion, AGENTS vCam contracts remain aligned, and no additional fixed-mode-specific DEV_PITFALLS entries were identified in this phase.

---

## Phase 4: Fixed Camera Mode

**Exit Criteria:** All ~28 fixed tests pass (13 resource + 15 evaluator), default preset created, fixed evaluation produces correct transforms for both anchor modes (world anchor and follow-offset) and tracking configurations (runtime manual checks deferred to Phase 6C after scene wiring), evaluator refactored for clarity across all three modes

### Phase 4A: RS_VCamModeFixed Resource

- [x] **Task 4A.1 (Red)**: Write tests for RS_VCamModeFixed
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
  - Test `use_world_anchor` field exists with default `true`
    - Verify type is `bool`
    - Verify default means the camera stays at its authored world position
  - Test `track_target` field exists with default `false`
    - Verify type is `bool`
    - Verify default means the camera keeps its authored rotation
  - Test `fov` field exists with default (e.g. 75.0)
    - Verify type is `float`
  - Test `fov` must be within valid range (1.0-179.0)
    - Set fov to 0.0, verify validation rejects or clamps
    - Set fov to 180.0, verify validation rejects or clamps
  - Test `tracking_damping` field exists with default (e.g. 5.0)
    - Verify type is `float`
    - Verify default provides smooth tracking (not instant snap)
  - Test `tracking_damping` must be non-negative
    - Set tracking_damping to -1.0, verify validation rejects
    - Set tracking_damping to 0.0, verify it is accepted (instant tracking)
  - Test `follow_offset` field exists with default `Vector3(0, 3, 5)`
    - Verify type is `Vector3`
  - Test `follow_offset` is only consumed when `use_world_anchor = false`
  - Test `use_path` field exists with default `false`
    - Verify type is `bool`
  - Test `path_max_speed` field exists with default `10.0`
    - Verify type is `float`
  - Test `path_max_speed` must be non-negative
    - Set path_max_speed to -1.0, verify validation rejects
    - Set path_max_speed to 0.0, verify it is accepted (instant)
  - Test `path_damping` field exists with default `5.0`
    - Verify type is `float`
  - Test `path_damping` must be non-negative
    - Set path_damping to -1.0, verify validation rejects
    - Set path_damping to 0.0, verify it is accepted (no smoothing)
  - **Target: 13 tests**

- [x] **Task 4A.2 (Green)**: Implement RS_VCamModeFixed
  - Create `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamModeFixed`
  - All `@export` fields with sensible defaults:
    - `use_world_anchor: bool = true` — when true, camera uses the fixed anchor position; when false, camera positions at `follow_target.global_position + follow_offset`
    - `track_target: bool = false` — when true, camera rotates to look at the follow target; when false, keeps authored rotation
    - `fov: float = 75.0` — authored field of view
    - `tracking_damping: float = 5.0` — smoothing factor for target tracking rotation (0.0 = instant snap)
    - `follow_offset: Vector3 = Vector3(0, 3, 5)` — offset from follow target when `use_world_anchor = false`; ignored when `use_world_anchor = true`
    - `use_path: bool = false` — when true, camera follows a Path3D; `use_world_anchor` and `follow_offset` are ignored
    - `path_max_speed: float = 10.0` — max speed along path (units/sec), 0.0 = instant
    - `path_damping: float = 5.0` — smoothing factor for path progress
  - All tests should pass

- [x] **Task 4A.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify file naming follows `rs_` prefix convention
  - Verify script is in `scripts/resources/display/vcam/` per style guide

---

### Phase 4B: Fixed Mode Evaluator

- [x] **Task 4B.1 (Red)**: Write tests for fixed evaluation in U_VCamModeEvaluator
  - Add to existing `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test fixed evaluation with `use_world_anchor = true` uses resolved fixed-anchor `Node3D` transform
    - Create a `Node3D` as the fixed anchor at a known world position (e.g. `Vector3(10, 5, -3)`)
    - Pass it as the `fixed_anchor` parameter
    - Assert `result.transform.origin` matches the anchor's `global_position`
    - Verify the camera does NOT use the follow target position
    - **Critical contract**: the anchor is `C_VCamComponent.fixed_anchor_path` resolved to a `Node3D`, with fallback to the vCam host entity-root `Node3D` — never the component transform itself
  - Test fixed evaluation returns correct `fov` matching resource (`75.0`)
  - Test fixed evaluation returns `mode_name == "fixed"`
  - Test fixed with `track_target = true` looks toward follow target
    - Place fixed anchor at `Vector3(10, 5, 0)`, follow target at `Vector3(0, 0, 0)`
    - Verify camera's -Z basis direction points approximately toward follow target
    - Use dot product or angle check between camera forward and direction to target
  - Test fixed with `track_target = false` keeps authored rotation
    - Set a specific rotation on the fixed anchor node
    - Verify `result.transform.basis` matches the anchor's authored basis
    - Verify follow target position does not influence camera rotation
  - Test fixed with `track_target = true` but null follow target falls back to authored rotation
    - Pass `follow_target = null` with `track_target = true`
    - Verify camera uses the anchor's authored rotation (same as `track_target = false`)
    - Verify no error or warning emitted
  - Test fixed with null mode resource returns empty dictionary
    - Pass `mode = null`
    - Verify `result == {}`
    - Verify no `push_warning` or `push_error` in output
  - Test fixed evaluation ignores `runtime_yaw` and `runtime_pitch` (fixed cameras are not player-rotatable)
    - Pass non-zero `runtime_yaw = 90.0` and `runtime_pitch = -45.0`
    - Verify result is identical to evaluation with zero runtime rotation
  - Test `use_world_anchor = false` positions camera at `follow_target.global_position + follow_offset`
    - Set `use_world_anchor = false`, `follow_offset = Vector3(0, 3, 5)`
    - Place follow target at `Vector3(10, 0, 0)`
    - Assert `result.transform.origin` is approximately `Vector3(10, 3, 5)`
  - Test `use_world_anchor = false` with `track_target = true` looks at follow target from offset position
    - Set `use_world_anchor = false`, `track_target = true`, `follow_offset = Vector3(0, 3, 5)`
    - Place follow target at `Vector3(0, 0, 0)`
    - Verify camera's -Z basis direction points approximately toward follow target
  - Test `use_world_anchor = false` with null follow target returns `{}`
    - Set `use_world_anchor = false`, pass `follow_target = null`
    - Verify `result == {}`
  - Test `use_path = true` with path-resolved anchor uses anchor position and basis (path tangent)
    - Set `use_path = true`, provide a `Node3D` as `fixed_anchor` (simulating a resolved `PathFollow3D`)
    - Assert `result.transform.origin` matches anchor's `global_position`
    - Assert `result.transform.basis` matches anchor's `global_transform.basis` (path tangent)
  - Test `use_path = true` ignores `track_target = true` (camera still faces path tangent)
    - Set `use_path = true`, `track_target = true`, provide anchor and follow target at different positions
    - Assert camera faces along anchor basis, NOT toward follow target
  - Test `use_path = true` with null `fixed_anchor` returns `{}`
    - Set `use_path = true`, pass `fixed_anchor = null`
    - Verify `result == {}`
  - Test `use_path = true` ignores `follow_offset` and `use_world_anchor` values
    - Set `use_path = true`, `use_world_anchor = false`, `follow_offset = Vector3(99, 99, 99)`
    - Provide a `Node3D` anchor at a known position
    - Assert `result.transform.origin` matches anchor position (not follow target + offset)
  - **Target: 15 tests**

  **Test helper setup pattern:**
  ```gdscript
  # Create a fixed anchor at known world position
  var fixed_anchor := Node3D.new()
  fixed_anchor.global_transform = Transform3D(Basis.IDENTITY, Vector3(10, 5, -3))
  add_child(fixed_anchor)

  # Create a follow target for tracking tests
  var follow_target := Node3D.new()
  follow_target.global_transform.origin = Vector3(0, 0, 0)
  add_child(follow_target)

  # Create fixed mode resource
  var mode := RS_VCamModeFixed.new()
  mode.use_world_anchor = true
  mode.track_target = false
  mode.fov = 75.0

  # Evaluate — note fixed_anchor is passed as the last parameter
  var result := U_VCamModeEvaluator.evaluate(mode, follow_target, null, 0.0, 0.0, fixed_anchor)
  ```

  **Fixed-anchor resolution contract (enforced in evaluator tests):**
  - The evaluator receives a pre-resolved `Node3D` as `fixed_anchor`
  - Resolution order (`fixed_anchor_path` -> entity root) is handled by `S_VCamSystem` (Phase 6), not the evaluator
  - For `use_path`, that pre-resolved anchor is a scene-local `PathFollow3D` that lives in the gameplay world, not under the persistent root manager
  - The evaluator simply uses whichever `Node3D` it is given
  - If `fixed_anchor` is null and `use_world_anchor = true`, return `{}`

- [x] **Task 4B.2 (Green)**: Implement fixed evaluation in U_VCamModeEvaluator
  - Extend `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with fixed mode branch
  - Handle fixed mode branch:
    - Guard: return `{}` if mode is null
    - When `mode.use_path == true`: treat as `use_world_anchor = true` + `track_target = false` (camera uses path-resolved anchor position and basis); return `{}` if `fixed_anchor` is null
    - Guard: return `{}` if `use_world_anchor = true` and `fixed_anchor` is null
    - Guard: return `{}` if `use_world_anchor = false` and `follow_target` is null
    - Camera position = `fixed_anchor.global_position` (when `use_world_anchor = true`)
    - Camera position = `follow_target.global_position + mode.follow_offset` (when `use_world_anchor = false`)
    - Camera rotation:
      - If `track_target = true` AND `follow_target` is not null: build `looking_at` basis toward follow target
      - Otherwise: use `fixed_anchor.global_transform.basis` (authored rotation)
    - Ignore `runtime_yaw` and `runtime_pitch` entirely (fixed cameras do not rotate with player input)
    - Return `{transform = camera_xform, fov = mode.fov, mode_name = "fixed"}`
  - All tests should pass
  - Verify orbit and OTS tests still pass (no regressions)

  **Fixed transform construction contract:**
  ```gdscript
  # Path mode: S_VCamSystem passes PathFollow3D as fixed_anchor
  # Treat as world-anchor + no tracking (camera faces path tangent)
  if mode.use_path:
      if fixed_anchor == null:
          return {}
      var camera_xform := Transform3D(fixed_anchor.global_transform.basis, fixed_anchor.global_position)
      return {transform = camera_xform, fov = mode.fov, mode_name = "fixed"}

  var pos: Vector3
  var default_basis: Basis

  if mode.use_world_anchor:
      if fixed_anchor == null:
          return {}
      pos = fixed_anchor.global_position
      default_basis = fixed_anchor.global_transform.basis
  else:
      if follow_target == null:
          return {}
      pos = follow_target.global_position + mode.follow_offset
      default_basis = Basis.IDENTITY

  var basis: Basis
  if mode.track_target and follow_target != null:
      var xform := Transform3D.IDENTITY.looking_at_from_position(pos, follow_target.global_position, Vector3.UP)
      basis = xform.basis
  else:
      basis = default_basis

  var camera_xform := Transform3D(basis, pos)
  ```

  **Note on `tracking_damping`**: The damping value is NOT consumed by the evaluator. Damping is applied by `S_VCamSystem` (Phase 6) which interpolates the tracking rotation over time. The evaluator computes the instantaneous target rotation for the current frame.

- [x] **Task 4B.3**: Create default fixed resource instance
  - Create `resources/display/vcam/cfg_default_fixed.tres`
  - Set all fields to resource defaults (use_world_anchor=true, track_target=false, fov=75.0, tracking_damping=5.0, follow_offset=Vector3(0,3,5))
  - Verify resource loads without errors:
    ```gdscript
    var res := load("res://resources/display/vcam/cfg_default_fixed.tres")
    assert_not_null(res)
    assert_is(res, RS_VCamModeFixed)
    ```

- [x] **Task 4B.4 (Refactor)**: Final review of U_VCamModeEvaluator across all three modes
  - Review evaluator now that it handles all three modes (orbit + OTS + fixed)
  - Ensure all three mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across all modes:
    - All modes return `{}` for null mode resource
    - Orbit and OTS return `{}` for null follow_target
    - Fixed returns `{}` for null fixed_anchor when `use_world_anchor = true`
    - No mode emits warnings for null resources
  - Verify no shared mutable state between mode evaluations
  - Verify the `evaluate()` function signature is clean and supports all three modes without excessive parameter count
  - Consider whether a type-dispatch pattern (`mode is RS_VCamModeOrbit`, etc.) is cleaner than the current branching
  - No new functionality, only code quality
  - All existing tests still pass after refactor

- [x] **Task 4B.5**: Run full regression across all modes
  - Run orbit resource tests (no regressions)
  - Run orbit evaluator tests (no regressions)
  - Run OTS resource tests (no regressions)
  - Run OTS evaluator tests (no regressions)
  - Run fixed resource tests
  - Run fixed evaluator tests
  - Run style enforcement tests
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit
  ```

**Completion notes (March 10, 2026):**
- Added `RS_VCamModeFixed` with resolved-value clamping for `fov`, `tracking_damping`, `path_max_speed`, and `path_damping`.
- Added fixed resource tests (`13/13` passing).
- Extended `U_VCamModeEvaluator` with fixed branches for world-anchor, follow-offset, and path-anchor evaluation.
- Extended evaluator tests with fixed coverage (`35/35` evaluator tests passing total).
- Added `cfg_default_fixed.tres`.
- Verified mode regression suite (`test_vcam_mode`, `64/64` passing) and style suite (`15/15` passing).

---

### Cross-Cutting Checks (Fixed)

- [ ] Verify `RS_VCamModeFixed` resource can be assigned to `C_VCamComponent.mode` export (type compatibility)
- [ ] Verify fixed evaluator does not import or depend on any scene-tree nodes beyond the passed `fixed_anchor` and `follow_target`
- [ ] Verify evaluator remains fully static (no instance state, no side effects) after adding fixed branch
- [ ] Verify `cfg_default_fixed.tres` loads on both desktop and mobile (no runtime directory scanning)
- [ ] Verify fixed evaluation handles edge case: fixed anchor and follow target at the same position with `track_target = true` (zero-length look direction) without crash or NaN
- [ ] Verify fixed evaluation handles edge case: fixed anchor with non-identity scale does not produce distorted camera basis
- [ ] Verify `tracking_damping` field exists on resource but is NOT consumed by the evaluator (consumed later by `S_VCamSystem` in Phase 6)
- [ ] Verify `runtime_yaw` and `runtime_pitch` are truly ignored — fixed cameras must never respond to player look input
- [ ] Verify orbit and OTS evaluation still work identically after fixed branch is added (no shared state pollution)
- [ ] Verify the evaluator's `fixed_anchor` parameter is null-safe when mode is not fixed (orbit/OTS ignore it)
- [ ] Verify `follow_offset` is ignored when `use_world_anchor = true` (camera uses fixed anchor position regardless of `follow_offset` value)
- [ ] Verify `fixed_anchor` parameter is ignored when `use_world_anchor = false` (camera uses follow target + offset regardless of anchor)
- [ ] Verify `path_max_speed` and `path_damping` are NOT consumed by evaluator (consumed by `S_VCamSystem`)
- [ ] Verify `use_path = true` forces path-tangent facing regardless of `track_target` value

---

### Manual Validation (Desktop — Fixed)

These checks gate Phase 6C completion for fixed mode:

- [x] **MT-09**: Fixed camera stays at authored world position
  - Place a fixed vCam in the scene with `use_world_anchor = true`
  - Launch game, verify camera is at the authored position
  - Move player around, verify camera position does NOT change
  - Verify camera does not drift or jitter over time
- [x] **MT-10**: Fixed camera with `track_target = true` rotates to follow player
  - Set `track_target = true` on the fixed vCam resource
  - Move player around the scene
  - Verify camera smoothly rotates to keep player in view
  - Verify `tracking_damping` controls the smoothness (higher = smoother, 0 = instant)
- [x] **MT-11**: Fixed camera with `track_target = false` keeps authored rotation
  - Set `track_target = false` on the fixed vCam resource
  - Move player around
  - Verify camera rotation stays fixed at the authored angle
  - Verify player can walk out of frame (camera does not follow)
- [x] **MT-12**: Fixed camera does not respond to look input
  - With fixed vCam active, move mouse or right stick
  - Verify camera does NOT rotate from player input
  - Verify this holds for both `track_target = true` and `track_target = false` configurations

### Manual Validation (Feel — Fixed)

These checks gate Phase 13 cross-mode QA completion:

- [x] **MT-63**: Entering fixed is intentionally authored (camera lands at authored position/rotation exactly)
  - Switch from orbit or OTS to fixed
  - Verify camera blend ends at the exact authored anchor position
  - Verify no drift or jitter after landing
- [x] **MT-64**: Leaving fixed preserves expected heading / reseeds intentionally
  - Switch from fixed to orbit: verify orbit reseeds to authored yaw/pitch (not stale pre-fixed rotation)
  - Switch from fixed to OTS: verify OTS reseeds to authored defaults
- [x] **MT-65**: Fixed anchor freed at runtime: camera recovers gracefully
  - Free or remove the fixed anchor node while fixed vCam is active
  - Verify camera falls back to entity root or holds last valid pose
  - Verify no crash or NaN camera state
- [x] **MT-69**: Fixed camera with `use_world_anchor = false` follows player at configured offset
  - Set `use_world_anchor = false` and `follow_offset = Vector3(0, 3, 5)` on the fixed vCam resource
  - Move player around, verify camera maintains constant offset from player
  - Verify camera does NOT respond to look input (mouse/right-stick)
  - Verify `track_target = true` causes camera to look at player from the offset position
  - Verify `track_target = false` keeps camera facing its default direction at the offset position
- [x] **MT-69B**: Fixed camera with `use_path = true` follows Path3D smoothly
  - Place a Path3D in scene, set `path_node_path` on vCam component
  - Move player along/across path, verify camera follows at closest point
  - Verify camera speed is clamped to `path_max_speed`
  - Verify camera faces along path tangent direction
  - Verify `track_target` setting has no effect
- [x] **MT-69C**: Path-following with closed vs open path
  - Test with a closed (looping) Path3D
  - Verify camera wraps smoothly around the loop
  - Test with an open path, verify camera clamps to endpoints

---

### Manual Validation (Blend — Fixed)

These checks gate Phase 9F completion:

- [x] **MT-19**: Switching from orbit to fixed blends smoothly (no snap)
  - Trigger a vCam switch from orbit to fixed
  - Verify smooth interpolation of both position and rotation over `blend_duration`
  - Verify no visible snap or teleport
  - Verify camera lands exactly at fixed anchor position
- [x] **MT-20**: (see [vcam-ots-tasks.md](vcam-ots-tasks.md) — fixed-to-OTS blend is owned by the OTS mode task file)

Completion note (March 22, 2026): Fixed manual blend checklist passed (`MT-19/20`).

---

## Test Commands

```bash
# Run fixed resource tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_fixed -ginclude_subdirs=true -gexit

# Run evaluator tests (includes orbit + OTS + fixed)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_vcam_mode_evaluator -ginclude_subdirs=true -gexit

# Run all mode-related tests together (orbit + OTS + fixed)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam_mode -ginclude_subdirs=true -gexit

# Run style enforcement after adding new files
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit

# Full regression: all vcam tests so far (state + resources + evaluator)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_vcam -ginclude_subdirs=true -gexit
```

---

## Common Pitfalls (Fixed)

1. Do not use the `C_VCamComponent` node's own transform as the fixed anchor. `C_VCamComponent` extends `BaseECSComponent` which extends `Node` (not `Node3D`), so it has no spatial transform. The anchor must come from a resolved `Node3D` — either `fixed_anchor_path` or the entity root.
2. Do not resolve `fixed_anchor_path` inside the evaluator. The evaluator receives a pre-resolved `Node3D`. Anchor resolution (path lookup, entity-root fallback) is `S_VCamSystem`'s responsibility (Phase 6).
3. Do not apply `tracking_damping` inside the evaluator. The evaluator computes the instantaneous target rotation. Damping (smoothing over time) is applied by `S_VCamSystem` which has access to `delta` and previous frame state.
4. Do not allow `runtime_yaw`/`runtime_pitch` to affect fixed camera evaluation. Fixed cameras are architect-controlled, not player-controlled. The evaluator must ignore these values entirely for fixed mode.
5. Do not use `look_at()` directly on the fixed camera node. Use `Transform3D.IDENTITY.looking_at_from_position()` to construct the tracking basis, avoiding Godot's `look_at` up-vector edge cases when target is directly above or below the camera.
6. Do not forget the zero-distance edge case: if the fixed anchor and follow target are at exactly the same position with `track_target = true`, the look direction is zero-length. Guard this to avoid NaN in the basis.
7. Do not forget to verify orbit and OTS regression after extending the evaluator. Adding a third branch must not break existing mode evaluations.
8. Do not confuse the final refactor (Task 4B.4) with adding new functionality. It is strictly a code quality pass — all tests must pass before and after with identical behavior.
9. Do not resolve `Path3D` or compute path progress inside the evaluator. Path resolution and progress smoothing are `S_VCamSystem`'s responsibility. The evaluator only sees a pre-resolved `PathFollow3D` as `fixed_anchor`.
10. Do not apply `path_max_speed` or `path_damping` in the evaluator. These are consumed by `S_VCamSystem`.
11. Do not parent `PathFollow3D` helpers under the persistent root manager. They must live in the gameplay world so their transforms and lifetime match the gameplay scene.
12. Do not keep advancing `use_path` progress after the follow target becomes invalid. Enter the standard invalid-target recovery path instead of fabricating path progress from stale data.

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [Orbit Tasks](vcam-orbit-tasks.md)
- [OTS Tasks](vcam-ots-tasks.md)
- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
