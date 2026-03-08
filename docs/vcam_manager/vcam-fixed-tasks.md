# vCam Fixed — Task Checklist

**Scope:** Fixed camera mode — resource, evaluator, and manual validation.

**Depends on:** Phase 2B (orbit evaluator creates `U_VCamModeEvaluator`) must be complete before Phase 3B extends it.

---

## Phase 3: Fixed Camera Mode

**Exit Criteria:** All ~14 fixed tests pass (6 resource + 8 evaluator), default preset created, fixed evaluation produces correct transforms for anchored and tracking configurations (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 3A: RS_VCamModeFixed Resource

- [ ] **Task 3A.1 (Red)**: Write tests for RS_VCamModeFixed
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
  - Test `use_world_anchor` field exists with default `true`
  - Test `track_target` field exists with default `false`
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `fov` must be within valid range (1.0-179.0)
  - Test `tracking_damping` field exists with default (e.g. 5.0)
  - Test `tracking_damping` must be non-negative
  - **Target: 6 tests**

- [ ] **Task 3A.2 (Green)**: Implement RS_VCamModeFixed
  - Create `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 3B: Fixed Mode Evaluator

- [ ] **Task 3B.1 (Red)**: Write tests for fixed evaluation in U_VCamModeEvaluator
  - Add to `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test fixed evaluation with `use_world_anchor = true` uses resolved `C_VCamComponent.fixed_anchor_path` `Node3D` transform, with fallback to vCam host entity-root `Node3D`, not `C_VCamComponent` transform
  - Test fixed evaluation returns correct `fov` matching resource
  - Test fixed evaluation returns `mode_name == "fixed"`
  - Test fixed with `track_target = true` looks toward follow target
  - Test fixed with `track_target = false` keeps authored rotation
  - Test fixed with `track_target = true` but null follow target falls back to authored rotation
  - Test fixed with null mode resource returns empty dictionary
  - Test fixed evaluation ignores `runtime_yaw` and `runtime_pitch` (fixed cameras are not player-rotatable)
  - **Target: 8 tests**

- [ ] **Task 3B.2 (Green)**: Implement fixed evaluation in U_VCamModeEvaluator
  - Extend evaluator to handle fixed mode
  - Ensure evaluator consumes resolved fixed-anchor `Node3D` input (`fixed_anchor_path` first, entity-root fallback)
  - All tests should pass

- [ ] **Task 3B.3**: Create default fixed resource instance
  - Create `resources/display/vcam/cfg_default_fixed.tres`
  - Verify resource loads and evaluates without errors

---

### Manual Validation (Desktop — Fixed)

These checks gate Phase 6C completion for fixed mode:

- [ ] **MT-09**: Fixed camera stays at authored world position
- [ ] **MT-10**: Fixed camera with `track_target = true` rotates to follow player
- [ ] **MT-11**: Fixed camera with `track_target = false` keeps authored rotation
- [ ] **MT-12**: Fixed camera does not respond to look input

### Manual Validation (Blend — Fixed)

- [ ] **MT-19**: Switching from orbit to fixed blends smoothly (no snap)
- [ ] **MT-20**: Switching from fixed to first-person blends smoothly

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [Orbit Tasks](vcam-orbit-tasks.md)
- [First-Person Tasks](vcam-fps-tasks.md)
