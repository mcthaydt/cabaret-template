# vCam Orbit — Task Checklist

**Scope:** Orbit camera mode — resource, evaluator, default preset, and manual validation.

**Depends on:** Phase 1 (base resources) must be complete before Phase 2B evaluator tests.

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
  - Test `distance` must be positive
  - Test `fov` must be within valid range (1.0-179.0)
  - **Target: 8 tests**

- [ ] **Task 2A.2 (Green)**: Implement RS_VCamModeOrbit
  - Create `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 2B: Orbit Mode Evaluator

- [ ] **Task 2B.1 (Red)**: Write tests for orbit evaluation in U_VCamModeEvaluator
  - Create `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test orbit evaluation with default settings returns a valid `transform` key
  - Test orbit evaluation returns correct `fov` key matching resource
  - Test orbit evaluation returns `mode_name == "orbit"`
  - Test orbit camera is positioned at `distance` behind and above follow target based on `authored_pitch`
  - Test orbit camera looks at the follow target
  - Test orbit with `allow_player_rotation = true` applies `runtime_yaw` and `runtime_pitch`
  - Test orbit with `allow_player_rotation = false` ignores `runtime_yaw` and `runtime_pitch`
  - Test orbit with zero distance returns empty dictionary (invalid)
  - Test orbit with null follow target returns empty dictionary
  - Test orbit with null mode resource returns empty dictionary without warnings
  - **Target: 10 tests**

- [ ] **Task 2B.2 (Green)**: Implement orbit evaluation in U_VCamModeEvaluator
  - Create `scripts/managers/helpers/u_vcam_mode_evaluator.gd`
  - Implement `static func evaluate(mode, follow_target, look_at_target, runtime_yaw, runtime_pitch) -> Dictionary`
  - Handle orbit mode: compute spherical-to-cartesian position from follow target
  - Return `{transform, fov, mode_name}` or `{}` on invalid input
  - All tests should pass

- [ ] **Task 2B.3**: Create default orbit resource instance
  - Create `resources/display/vcam/cfg_default_orbit.tres`
  - Verify resource loads and evaluates without errors

---

### Manual Validation (Desktop — Orbit)

These checks gate Phase 6C completion for orbit mode:

- [ ] **MT-01**: Orbit camera follows player at configured distance and pitch
- [ ] **MT-02**: Orbit camera rotates horizontally with mouse/right-stick look input
- [ ] **MT-03**: Orbit camera rotates vertically with mouse/right-stick look input (pitch clamped)
- [ ] **MT-04**: Orbit camera with `allow_player_rotation = false` stays at authored angle

### Manual Validation (Mobile — Orbit)

These checks gate Phase 7D completion for orbit mode:

- [ ] **MT-05**: Orbit camera on mobile: drag-look rotates camera horizontally
- [ ] **MT-06**: Orbit camera on mobile: drag-look rotates camera vertically
- [ ] **MT-07**: Orbit camera on mobile: simultaneous move joystick + drag-look works
- [ ] **MT-08**: Orbit camera on mobile: pressing button during drag-look does not disrupt

### Manual Validation (Blend — Orbit)

- [ ] **MT-19**: Switching from orbit to fixed blends smoothly (no snap)
- [ ] **MT-21**: Switching between two moving orbit cameras blends live (not frozen)
- [ ] **MT-32**: Screen shake during orbit camera works (shake visible, returns to correct position)

---

## Links

- [Main Task Index](vcam-manager-tasks.md)
- [Base Tasks](vcam-base-tasks.md)
- [Fixed Tasks](vcam-fixed-tasks.md)
- [First-Person Tasks](vcam-fps-tasks.md)
