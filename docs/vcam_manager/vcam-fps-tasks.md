# vCam First-Person — Task Checklist

**Scope:** First-person camera mode — resource, evaluator, evaluator refactor, and manual validation.

**Depends on:** Phase 3B (fixed evaluator extends `U_VCamModeEvaluator`) must be complete before Phase 4B extends it further.

---

## Phase 4: First-Person Camera Mode

**Exit Criteria:** All ~18 first-person tests pass (8 resource + 10 evaluator), default preset created, first-person evaluation produces correct transforms with pitch clamping and head offset (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 4A: RS_VCamModeFirstPerson Resource

- [ ] **Task 4A.1 (Red)**: Write tests for RS_VCamModeFirstPerson
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
  - Test `head_offset` field exists with default (e.g. `Vector3(0, 1.7, 0)`)
  - Test `look_multiplier` field exists with default `1.0`
  - Test `pitch_min` field exists with default (e.g. -89.0)
  - Test `pitch_max` field exists with default (e.g. 89.0)
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `fov` must be within valid range (1.0-179.0)
  - Test `look_multiplier` must be positive
  - Test `pitch_min` < `pitch_max` constraint
  - **Target: 8 tests**

- [ ] **Task 4A.2 (Green)**: Implement RS_VCamModeFirstPerson
  - Create `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 4B: First-Person Mode Evaluator

- [ ] **Task 4B.1 (Red)**: Write tests for first-person evaluation in U_VCamModeEvaluator
  - Add to `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test first-person evaluation returns a valid `transform` key
  - Test first-person evaluation returns correct `fov` matching resource
  - Test first-person evaluation returns `mode_name == "first_person"`
  - Test first-person camera is positioned at follow target + `head_offset`
  - Test first-person applies `runtime_yaw` for horizontal rotation
  - Test first-person applies `runtime_pitch` for vertical rotation
  - Test first-person clamps pitch to `pitch_min`/`pitch_max` range
  - Test first-person pitch at min boundary does not exceed
  - Test first-person pitch at max boundary does not exceed
  - Test first-person with null follow target returns empty dictionary
  - **Target: 10 tests**

- [ ] **Task 4B.2 (Green)**: Implement first-person evaluation in U_VCamModeEvaluator
  - Extend evaluator to handle first-person mode
  - All tests should pass

- [ ] **Task 4B.3**: Create default first-person resource instance
  - Create `resources/display/vcam/cfg_default_first_person.tres`
  - Verify resource loads and evaluates without errors

- [ ] **Task 4B.4 (Refactor)**: Review U_VCamModeEvaluator for clarity
  - Ensure all three mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across modes
  - No new functionality, only code quality

---

### Manual Validation (Desktop — First-Person)

These checks gate Phase 6C completion for first-person mode:

- [ ] **MT-13**: First-person camera positioned at player + head offset
- [ ] **MT-14**: First-person camera rotates with mouse/right-stick look input
- [ ] **MT-15**: First-person camera pitch is clamped at min/max boundaries
- [ ] **MT-18**: First-person `look_multiplier` scales rotation speed

### Manual Validation (Mobile — First-Person)

These checks gate Phase 7D completion for first-person mode:

- [ ] **MT-16**: First-person camera on mobile: drag-look rotates view
- [ ] **MT-17**: First-person camera on mobile: simultaneous move + look works

### Manual Validation (Blend — First-Person)

- [ ] **MT-20**: Switching from fixed to first-person blends smoothly
- [ ] **MT-33**: Screen shake during first-person camera works

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [Orbit Tasks](vcam-orbit-tasks.md)
- [Fixed Tasks](vcam-fixed-tasks.md)
