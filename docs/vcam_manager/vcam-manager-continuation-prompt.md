# vCam Manager - Continuation Prompt

## Current Focus

- **Feature / story**: vCam Refactor (Mode Simplification + System Decomposition)
- **Branch**: `vcam`
- **Status summary**: Baseline vCam delivery remains complete through Phase 13 (March 22, 2026). Refactor `PRE-1`, `PRE-2`, Phases `1A`-`1I`, and Phases `2A`-`2E` are complete (orbit is the sole mode; OTS, Fixed, and First-Person removed). Phase `2G` is in progress (`2F` dropped).

## Next Planned Work (March 22, 2026)

- Primary objective: continue executing `docs/vcam_manager/vcam-refactor-tasks.md` through Phase 2 coordinator cleanup (`2G` onward). Phase 2F (FP effects) and Phase 4 (Enhance FP) are dropped.
- Immediate implementation target: finish Phase `2G.3` by reducing remaining coordinator/orphaned code in `s_vcam_system.gd` and closing the file-size/decomposition target.
- Preserve current runtime safety contracts during refactor: `S_VCamSystem` ordering (`execution_priority = 100`), frame-stamped handoff, silhouette routing via `U_VCamSilhouetteHelper.update_silhouettes(...)`, and editor-only preview gating.
- After each completed refactor phase, update this continuation prompt and `docs/vcam_manager/vcam-refactor-tasks.md`, then commit docs separately from implementation.
- Sections below remain pre-refactor baseline history until refactor Phase 5 documentation cleanup supersedes them.

## Refactor Phase 1A (March 22, 2026)

- Completed `s_vcam_system.gd` OTS runtime removal pass:
  - removed OTS constants/imports/state dictionaries/debug dictionaries
  - removed OTS pipeline calls (`_apply_ots_shoulder_sway`, `_apply_ots_collision_avoidance`, `_apply_ots_landing_camera_response`)
  - removed OTS helper/debug methods and OTS branches from shared mode checks/smoothing cleanup paths
- Repurposed aim activation to first-person:
  - `_find_aim_target_ots_vcam_id` -> `_find_aim_target_fp_vcam_id`
  - `_resolve_ots_aim_blend_duration` -> `_resolve_aim_blend_duration`
  - `_resolve_ots_aim_exit_blend_duration` -> `_resolve_aim_exit_blend_duration`
  - `aim_pressed` now selects first-person vCam on press and restores prior vCam on release
- Added first-person aim blend authoring fields in `RS_VCamModeFirstPerson`:
  - `aim_blend_duration` default `0.15`
  - `aim_exit_blend_duration` default `0.2`
  - both resolved via `maxf(..., 0.01)`
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd -gunit_test_name=aim` (`5/5`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 1B (March 22, 2026)

- Completed fixed-mode runtime removal pass in `s_vcam_system.gd`:
  - removed fixed mode import/constant and `_path_follow_helpers` state
  - removed fixed helper methods (`_is_path_fixed_mode`, `_resolve_or_create_path_anchor`, `_resolve_fixed_anchor_for_component`, `_prune_path_helpers`, `_teardown_path_helpers`, `_is_fixed_anchor_required`)
  - removed fixed branches from `_evaluate_and_submit`, `_apply_rotation_transition`, `_is_follow_target_required`, and `_step_smoothing_state`
- `S_VCamSystem` follow-target-required gating now only includes orbit and first-person modes.
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd -gunit_test_name=aim` (`5/5`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 1C (March 22, 2026)

- Completed evaluator simplification pass in `u_vcam_mode_evaluator.gd`:
  - removed OTS/fixed script constants (`RS_VCAM_MODE_OTS_SCRIPT`, `RS_VCAM_MODE_FIXED_SCRIPT`)
  - removed OTS/fixed evaluation dispatch branches from `evaluate(...)`
  - removed `fixed_anchor` parameter from `evaluate(...)` signature
  - removed OTS/fixed helpers (`_evaluate_ots`, `_resolve_ots_values`, `_evaluate_fixed`, `_resolve_fixed_values`, `_build_look_at_basis_or_fallback`)
- Updated evaluator call sites and coverage for the new contract:
  - `tests/unit/ecs/systems/test_vcam_system.gd` evaluator expectation helpers now call 5-arg `evaluate(...)`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` now targets orbit/first-person only and includes unsupported-mode guard coverage
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (`25/25`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 1D (March 22, 2026)

- Completed external-system OTS removal pass:
  - `S_MovementSystem` no longer resolves OTS movement profile/sprint overrides; removed OTS mode constant + `_resolve_active_ots_movement_state(...)`.
  - `S_RotateToInputSystem` no longer resolves OTS facing-lock state; removed OTS mode constant + `_resolve_active_ots_facing_lock(...)`.
  - `UI_HudController` no longer contains OTS reticle runtime logic (imports, state, tween helpers, and update-path calls removed).
- Updated unit coverage aligned to removed external OTS contracts:
  - `tests/unit/ecs/systems/test_movement_system.gd` OTS override tests removed.
  - `tests/unit/ecs/systems/test_rotate_to_input_system.gd` OTS lock-facing tests removed.
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_movement_system.gd` (`9/9`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_rotate_to_input_system.gd` (`3/3`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 1E (March 22, 2026)

- Completed component fixed-mode export cleanup in `c_vcam_component.gd`:
  - removed `fixed_anchor_path` and `path_node_path` exports
  - removed `get_fixed_anchor()` and `get_path_node()` getters
- Updated component test expectations:
  - `tests/unit/ecs/components/test_vcam_component.gd` no longer asserts fixed/path exports
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_vcam_component.gd` (`13/13`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 1F (March 22, 2026)

- Completed resource + scene cleanup for removed OTS/fixed paths:
  - deleted production resources/scripts: `rs_vcam_mode_ots.gd`, `rs_vcam_mode_fixed.gd`, `cfg_default_ots.tres`, `cfg_default_fixed.tres`, `cfg_ots_movement_default.tres`
  - `scenes/templates/tmpl_camera.tscn` now references `cfg_default_first_person.tres` and uses `C_VCamFirstPersonComponent` (`vcam_id = &"camera_first_person"`)
  - `scenes/ui/hud/ui_hud_overlay.tscn` no longer includes `OTSReticleContainer` / `ReticleDot`
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -gselect=test_style_enforcement` (`17/17`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/test_entity_scene_registration.gd` (`3/3`)

## Refactor Phase 1G (March 22, 2026)

- Completed test-suite migration to orbit + first-person runtime:
  - deleted OTS/fixed mode resource suites: `test_vcam_mode_ots.gd`, `test_vcam_mode_fixed.gd`
  - removed legacy OTS HUD suite: `tests/unit/ui/hud/test_ots_reticle.gd`
  - `tests/unit/ecs/systems/test_vcam_system.gd` now excludes OTS/fixed scenarios and runs orbit/first-person coverage only (`94/94`)
  - integration/resource suites updated to remove fixed/OTS preset/runtime paths (`test_vcam_runtime.gd`, `test_vcam_mobile.gd`, `test_vcam_mode_presets.gd`)
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_vcam_manager.gd` (`45/45`)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/vcam` (`26/26`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam` (`91/91`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -gselect=test_style_enforcement` (`17/17`)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (`3481/3490` passing, `9` pending baseline)

## Refactor Phase 1H (March 22, 2026)

- Completed Phase 1 closure tasks:
  - implementation commits landed for Phase 1F + 1G (`a16a9b3e`, `d60a1142`)
  - documentation cadence completed (`vcam-refactor-tasks.md` + this continuation prompt)
  - `AGENTS.md` Stage-1 contract cleanup removed stale OTS/fixed mode guidance and aligned vCam runtime contracts to orbit + first-person only
- Phase 2 is now unblocked (`2A` helper extraction kickoff).

## Refactor Phase 1I (March 22, 2026)

- Completed first-person mode + aim pipeline removal (orbit is now the sole mode):
  - `s_vcam_system.gd`: removed FP mode script const, aim state vars, all aim/FP functions (~300 lines), FP branches from rotation/mode-gating helpers, simplified mode checks to orbit-only
  - `u_vcam_mode_evaluator.gd`: removed FP const, dispatch branch, `_evaluate_first_person()`, `_resolve_first_person_values()`
  - Input/state layer: removed `aim_pressed` from `c_input_component.gd`, `s_input_system.gd`, `u_input_actions.gd`, `u_input_reducer.gd`, `u_input_selectors.gd`, and all three input sources + interface
  - External systems: removed aim from `s_touchscreen_system.gd` and `ui_mobile_controls.gd` (aim long-press handling)
  - Deleted: `rs_vcam_mode_first_person.gd`, `cfg_default_first_person.tres`, `test_vcam_mode_first_person.gd`
  - Updated `tmpl_camera.tscn`: removed FP ext_resource + `C_VCamFirstPersonComponent` node
  - Test cleanup: removed FP/aim tests from evaluator, system, input, touchscreen, reducer, selector, mobile controls suites; removed mode-switch/mode-gating tests that required non-orbit mode; replaced `"first_person"` mode strings with `"custom_mode"` in room-fade/region-visibility tests
  - `AGENTS.md`: removed FP mode resource contract, aim activation contract, touch aim contract, updated orbit release-smoothing and rotation continuity contracts for orbit-only
  - Dropped Phase 2F (`u_vcam_first_person_effects.gd`) and Phase 4 (Enhance First-Person) from roadmap
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (`3405/3414` passing, `9` pending baseline)

## Refactor Phase 2A (March 22, 2026)

- Completed look-input helper extraction (`U_VCamLookInput`):
  - added `scripts/ecs/systems/helpers/u_vcam_look_input.gd` with API (`filter_look_input`, `is_active`, `prune`, `clear_all`, `clear_for_vcam`)
  - moved look-filter constants/state and look-filter transition debug logging out of `S_VCamSystem`
  - `S_VCamSystem` now delegates look filtering and helper lifecycle (`prune`/`clear`) through `_look_input_helper`
  - response-signature look-filter fallback defaults now reference helper constants
- Added helper coverage:
  - `tests/unit/ecs/systems/helpers/test_vcam_look_input.gd` (`8/8`)
  - updated `tests/unit/ecs/systems/test_vcam_system.gd` look-filter spike decay regression to assert through helper API
- Style enforcement update:
  - `tests/unit/style/test_style_enforcement.gd` now allows `u_` scripts in `res://scripts/ecs/systems/helpers`
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_look_input.gd` (`8/8`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 2B (March 22, 2026)

- Completed rotation helper extraction (`U_VCamRotation`):
  - added `scripts/ecs/systems/helpers/u_vcam_rotation.gd` with continuity handoff, orbit runtime rotation updates, look spring/release smoothing, orbit recenter state, and helper lifecycle APIs
  - extracted/owned helper state for look-smoothing + centering runtime (`_look_rotation_state`, `_orbit_no_look_input_timers`, `_orbit_centering_state`)
  - `S_VCamSystem` now delegates continuity/update/evaluation rotation paths to `_rotation_helper`
- Added helper coverage:
  - `tests/unit/ecs/systems/helpers/test_vcam_rotation.gd` (`8/8`)
- Compatibility hardening during refactor:
  - retained thin wrappers in `S_VCamSystem` for `_step_orbit_release_axis(...)` and `_resolve_orbit_center_target_yaw(...)` to keep existing unit-test hook surfaces stable
  - preserved centering lifecycle independence from response-smoothing cleanup by splitting helper clear APIs (`clear_rotation_state_for_vcam` vs centering clear)
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_rotation.gd` (`8/8`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 2C (March 22, 2026)

- Completed orbit-effects helper extraction (`U_VCamOrbitEffects`):
  - added `scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd` with look-ahead, ground-relative anchoring, soft-zone correction/dead-zone state, follow-target motion sampling, and orbit smoothing-bypass hysteresis APIs
  - helper now owns `_look_ahead_state`, `_ground_relative_state`, `_soft_zone_dead_zone_state`, and `_follow_target_motion_state` lifecycles (`prune`, `clear_all`, `clear_for_vcam`)
- `S_VCamSystem` refactor wiring:
  - `_apply_orbit_look_ahead`, `_apply_orbit_ground_relative`, `_apply_orbit_soft_zone`, follow-target speed sampling, and orbit bypass gating now delegate to `_orbit_effects_helper`
  - smoothing prune/clear flows now include helper lifecycle delegation
  - compatibility snapshots for existing tests remain available through helper-backed state getters
- Added helper coverage:
  - `tests/unit/ecs/systems/helpers/test_vcam_orbit_effects.gd` (`11/11`)
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_orbit_effects.gd` (`11/11`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 2D (March 22, 2026)

- Completed response-smoother helper extraction (`U_VCamResponseSmoother`):
  - added `scripts/ecs/systems/helpers/u_vcam_response_smoother.gd` with response smoothing flow, per-vCam dynamics state, smoothing metadata transitions, and euler unwrapping cache
  - helper lifecycle APIs (`prune`, `clear_all`, `clear_for_vcam`) now own response-smoothing state cleanup
- `S_VCamSystem` refactor wiring:
  - `_apply_response_smoothing` now delegates to `_response_smoother`
  - helper now owns `_follow_dynamics`, `_rotation_dynamics`, `_smoothing_metadata`, and `_rotation_target_cache`
  - orbit smoothing-bypass handoff remains integrated via helper callback to orbit-effects bypass tracking
  - compatibility snapshots used by existing system tests remain available via helper-backed getters
- Added helper coverage:
  - `tests/unit/ecs/systems/helpers/test_vcam_response_smoother.gd` (`8/8`)
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_response_smoother.gd` (`8/8`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 2E (March 22, 2026)

- Completed landing-impact helper extraction (`U_VCamLandingImpact`):
  - added `scripts/ecs/systems/helpers/u_vcam_landing_impact.gd` with landing event normalization/state (`record_landing_event`, `normalize_fall_speed`)
  - helper now owns landing-impact recovery state and APIs (`resolve_offset`, `apply_offset`, `clear_state`)
- `S_VCamSystem` refactor wiring:
  - removed inline landing recovery members (`_landing_recovery_dynamics`, `_landing_recovery_state_id`, `_landing_recovery_frequency_hz`)
  - `_resolve_landing_impact_offset(...)` now delegates to `_landing_impact_helper.resolve_offset(...)`
  - `_apply_landing_impact_offset(...)` now delegates offset application to helper while retaining debug status logging
  - `_exit_tree()` now clears landing helper state via `_landing_impact_helper.clear_state()`
- Added helper coverage:
  - `tests/unit/ecs/systems/helpers/test_vcam_landing_impact.gd` (`6/6`)
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_landing_impact.gd` (`6/6`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Refactor Phase 2G (March 22, 2026, In Progress)

- Completed coordinator pass for `2G.1` and `2G.2` in `S_VCamSystem`:
  - `_evaluate_and_submit(...)` now coordinates explicit stage functions:
    - `_prepare_vcam_pipeline_state(...)`
    - `_evaluate_vcam_mode_result(...)`
    - `_apply_vcam_effect_pipeline(...)`
  - prune/clear lifecycle is now helper-driven (`helper.prune(...)`) instead of per-snapshot stale-id loops.
  - debug tracking cleanup now routes through coordinator helpers (`_prune_debug_tracking`, `_prune_debug_dictionary`, `_clear_debug_tracking_for_vcam`).
- Additional `2G.3` decomposition progress landed:
  - added `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd` and moved non-coordinator runtime-context logic out of `S_VCamSystem`:
    - follow-target resolution fallback chain + multi-tag ambiguity reporting
    - look-ahead velocity sourcing helpers
    - grounded/probe helpers for orbit ground-relative flow
    - projection-camera + primary camera-state resolution
    - camera-state read/write + base-fov sync utilities
  - `scripts/ecs/systems/s_vcam_system.gd` line count reduced from `1537` to `1185`.
- Validation run (March 22, 2026):
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`78/78`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/helpers/test_vcam_landing_impact.gd` (`6/6`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (`3446/3455` passing, `9` pending baseline)
- Remaining `2G.3` item:
  - `scripts/ecs/systems/s_vcam_system.gd` is still above the target size (`1185` lines) and needs further extraction/decomposition before Phase `2G` can be closed.

## Phase 12 Integration Tests (March 22, 2026)

- Added integration suites:
  - `tests/integration/vcam/test_vcam_state.gd` (`9/9`)
  - `tests/integration/vcam/test_vcam_runtime.gd` (`7/7`)
  - `tests/integration/vcam/test_vcam_blend.gd` (`5/5`)
  - `tests/integration/vcam/test_vcam_mobile.gd` (`6/6`)
  - `tests/integration/vcam/test_vcam_occlusion.gd` (`2/2`)
- Implementation hardening completed during Green/Refactor:
  - `M_VCamManager._set_active_vcam_internal(...)` now dispatches `vcam/set_active_runtime` before `vcam/start_blend`, so reducer `blend_to_vcam_id` resolves to the incoming active camera.
  - `S_VCamSystem` now updates target observability (`vcam.active_target_valid`) and recovery reasons (`target_freed`, `path_anchor_invalid`, `anchor_invalid`, `evaluation_failed`) when active-camera target/anchor/evaluator resolution fails.
  - Mobile integration coverage now re-enters gameplay shell after touchscreen-settings apply in standalone fixture flow to avoid false negatives from overlay close-shell fallback.
- Validation run (March 22, 2026):
  - `tests/integration/vcam` (`29/29`)
  - `tests/unit/managers` (`-gselect=test_vcam_manager`, `49/49`)
  - `tests/unit/style` (`-gselect=test_style_enforcement`, `17/17`)

## Phase 6B2 Runtime Recovery Closure (March 22, 2026)

- Added runtime-recovery regression coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - `test_active_follow_target_loss_holds_last_submission_and_requests_reselection`
  - `test_fixed_world_anchor_missing_falls_back_to_entity_root`
- Recovery implementation hardening:
  - `S_VCamSystem` now resolves fixed world-anchor fallback from the vCam host entity root when `fixed_anchor_path` is missing/invalid.
  - Active target/anchor/evaluator failure paths now publish `EVENT_VCAM_RECOVERY` with `{reason, vcam_id}` and request manager reselection.
  - `M_VCamManager._record_recovery(...)` event payload now includes `vcam_id` in addition to existing active/previous IDs.
- Validation run (March 22, 2026):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`133/133`)
  - `tests/integration/vcam/test_vcam_state.gd` (`9/9`)
  - `tests/unit/managers` (`-gselect=test_vcam_manager`, `49/49`)
  - `tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Phase 12A Observability Validation (March 22, 2026)

- Phase 12A checklist (`MT-40/41/42/47/48/49`) is closed.
- Validation evidence:
  - `tests/integration/vcam/test_vcam_state.gd` (`9/9`) covers active-camera, blend-state, blend debug fields, target-validity, and recovery-reason observability.
  - `tests/integration/vcam/test_vcam_occlusion.gd` (`2/2`) covers silhouette lifecycle updates that drive `vcam.silhouette_active_count`.

## Phase 13 Regression + Docs Closure (March 22, 2026)

- Completed items:
  - `13.1` camera-manager regression coverage (shake-safe apply path + transition blend observability)
  - `13.2` AGENTS review (no additional stable contracts discovered in this closure pass)
  - `13.3` DEV_PITFALLS review (no new pitfalls discovered in this closure pass)
  - `13.4` documentation status refresh
  - `13.5` cross-mode feel QA (manual) marked complete per manual QA sign-off request
  - `13.6` second-order dynamics feel QA (manual) marked complete per manual QA sign-off request
  - `13.6b` QB-driven camera feel QA (manual) marked complete per manual QA sign-off request
  - `13.7` performance regression checks (manual) marked complete per manual QA sign-off request
  - `13.8` automated regression/test gates
- Validation run (March 22, 2026):
  - `tests/unit/style/test_style_enforcement.gd` (`17/17`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`131/131`)
  - `tests/unit/managers/test_vcam_manager.gd` + `test_vcam_manager_silhouette_filter.gd` (`49/49`)
  - `tests/unit/managers/helpers/test_vcam_blend_evaluator.gd` (`10/10`)
  - `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd` (`16/16`)
  - `tests/unit/managers/test_vfx_manager_silhouette_routing.gd` (`8/8`)
  - `tests/integration/vcam` (`29/29`)
  - `tests/integration/camera_system/test_camera_manager.gd` (`16/16`)
  - `tests/unit/ui/test_mobile_controls.gd` (`20/20`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`8/8`)
  - `tests/unit/ecs/systems/test_input_system.gd` (`14/14`)

## Phase 10C2 Anti-Flicker + Stability (March 21, 2026)

- Added anti-flicker silhouette lifecycle in `U_VCamSilhouetteHelper`:
  - new `update_silhouettes(occluders, enabled)` API with two-frame apply debounce
  - one-frame grace removal before clearing missing occluders
  - order-insensitive/stable-set handling to avoid reapplying unchanged occluders each frame
- Updated `M_VFXManager` silhouette path:
  - `_process_silhouette_request(...)` now delegates payload updates to `update_silhouettes(...)` instead of always `remove_all + apply` per tick
  - explicit `enabled=false` clear requests bypass transition-block gating so stale silhouettes can be torn down during transitions
  - `vcam/update_silhouette_count` now dispatches from post-filtered helper state (`get_active_count()`), aligning observability with rendered silhouettes
- New/updated coverage:
  - `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd` (`16/16`)
  - `tests/unit/managers/test_vfx_manager_silhouette_routing.gd` (`8/8`)
- Regression validation run:
  - `tests/unit/managers/test_vfx_manager.gd` (`49/49`)
  - `tests/unit/managers/test_vcam_manager.gd` (`49/49`)
  - `tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Phase 11 Editor Preview (March 22, 2026)

- Added editor-only rule-of-thirds preview helper:
  - `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`
  - `@tool` `Node` with internal `CanvasLayer` + drawing control grid overlay
  - runtime path self-cleans with `queue_free()` when `Engine.is_editor_hint()` is false
- Added template wiring:
  - `scenes/templates/tmpl_camera.tscn` now includes `U_VCamRuleOfThirdsPreview` under camera root
- Validation run:
  - `tests/unit/style/test_style_enforcement.gd` (`17/17`)

## Phase 9 Live Blend Evaluation + Integration (March 15, 2026)

- Added blend helper:
  - `scripts/managers/helpers/u_vcam_blend_evaluator.gd`
  - `tests/unit/managers/helpers/test_vcam_blend_evaluator.gd` (`10/10`)
- `M_VCamManager` live blend/runtime integration is now implementation-backed:
  - blend lifecycle dispatch/event flow (`start/update/complete`, `EVENT_VCAM_BLEND_STARTED/COMPLETED`)
  - frame-stamped handoff gating (`Engine.get_physics_frames`) so stale previous-frame submissions are ignored
  - reentrant blend snapshot handoff (mid-blend `set_active_vcam()` starts from current blended pose)
  - invalid-endpoint recovery (`blend_from_invalid`, `blend_to_invalid`, `blend_both_invalid`) via `record_recovery` + `EVENT_VCAM_RECOVERY`
  - camera apply continues to route through `camera_manager.apply_main_camera_transform(...)` and transition-blend gating via `is_blend_active()`
- Camera-manager integration validation:
  - `tests/integration/camera_system/test_camera_manager.gd` now covers shake-safe `apply_main_camera_transform(...)` and `is_blend_active()` true/false semantics.
  - `M_CameraManager.is_blend_active()` now keys off active transition tween state (`_camera_blend_tween.is_running()`).
- QB context enrichment completed:
  - `S_CameraStateSystem._attach_camera_context(...)` now provides `vcam_active_mode`, `vcam_is_blending`, and `vcam_active_vcam_id`.
  - `tests/unit/qb/test_camera_state_system.gd` includes explicit coverage for new context keys.
- Validation run:
  - `tests/unit/managers/helpers/test_vcam_blend_evaluator.gd` (`10/10`)
  - `tests/unit/managers/test_vcam_manager.gd` (`43/43`)
  - `tests/unit/qb/test_camera_state_system.gd` (`21/21`)
  - `tests/integration/camera_system/test_camera_manager.gd` (`16/16`)
  - `tests/unit/style/test_style_enforcement.gd` (`17/17`)

## OTS Mode Replacement (March 14, 2026)

- First-person camera mode (`RS_VCamModeFirstPerson`) replaced with RE4-style OTS (over-the-shoulder) camera (`RS_VCamModeOTS`).
- The OTS camera is "always aimed" — the default framing IS the tight shoulder view, no ADS toggle.
- Camera sits behind and to one side of the character with collision avoidance to prevent wall clipping.
- Phase 3 (resource + evaluator) and Phase 9 (game feel) are fully reset since the mode changes fundamentally.
- Previous first-person strafe tilt work is superseded by OTS shoulder sway (same concept, different context).
- See `docs/vcam_manager/vcam-ots-tasks.md` for complete task breakdown.

## OTS Mode Resource (Phase 3A, March 15, 2026)

- Added OTS mode resource:
  - `scripts/resources/display/vcam/rs_vcam_mode_ots.gd` (`RS_VCamModeOTS`)
- Authoring/runtime fields implemented:
  - `shoulder_offset`, `camera_distance`, `look_multiplier`, `pitch_min`, `pitch_max`, `fov`
  - `collision_probe_radius`, `collision_recovery_speed`
  - `shoulder_sway_angle`, `shoulder_sway_smoothing`
  - `landing_dip_distance`, `landing_dip_recovery_speed`
- `get_resolved_values()` now enforces OTS clamp/order contract:
  - `look_multiplier` resolves positive
  - `pitch_min`/`pitch_max` resolve ordered bounds
  - `fov` resolves into `1.0..179.0`
  - collision/landing recovery speeds resolve positive
  - distance/radius/sway/dip magnitudes resolve non-negative
- New coverage:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18` passing, includes default preset load contract + shoulder sway clamp)
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Mode Evaluator (Phase 3B, March 15, 2026)

- Added OTS evaluator branch in `U_VCamModeEvaluator`:
  - mode dispatch now handles `RS_VCamModeOTS`
  - OTS evaluation builds yaw/pitch basis, clamps pitch via resolved bounds, rotates shoulder offset by yaw, and positions camera with `basis.z * camera_distance`
  - returns `{transform, fov, mode_name = "ots"}` and remains null-target safe (`{}`) without warning-channel output
- Added `_resolve_ots_values(...)` fallback path to preserve evaluator behavior when resolved dictionaries are unavailable.
- Added default preset resource:
  - `resources/display/vcam/cfg_default_ots.tres`
- Expanded evaluator coverage:
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` now includes OTS transform/fov/mode-name, yaw/pitch application, pitch clamp/boundary, and null-target tests (`49/49` total).
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (`14/14`)
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (`49/49`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`17/17`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Collision Avoidance (Phase 3C1, March 15, 2026)

- Added OTS collision-avoidance pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_collision_avoidance(...)` runs after evaluator output and before downstream submission.
  - mode-gated to `RS_VCamModeOTS` (non-OTS modes are strict no-ops and clear stale collision state).
- Collision query/runtime contract implemented:
  - collision checks run against gameplay physics space via `follow_target.get_world_3d().direct_space_state`.
  - spherecast path uses `PhysicsDirectSpaceState3D.cast_motion(...)` with `collision_probe_radius`.
  - initial-overlap guard uses `intersect_shape(...)` (treat overlap as hit-distance `0.0`).
  - zero-radius fallback uses raycast.
  - on hit, distance clamps to `hit_distance - collision_probe_radius` with minimum distance floor (`0.1`).
- Recovery/runtime state implemented:
  - per-vCam `_ots_collision_state` tracks `follow_target_id`, `recovery_speed_hz`, `current_distance`, and reused `U_SecondOrderDynamics`.
  - recovery is smooth when obstruction clears; hit frames clamp immediately to avoid clipping.
  - stale-vCam prune and non-OTS paths clear collision state.
- New/updated coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - no-collision full-distance behavior
  - obstructed clamp behavior
  - probe-radius off-axis sensitivity behavior
  - minimum-distance floor behavior
  - smooth recovery-after-clear behavior
  - orbit/fixed no-op gating behavior
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`107/107`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`17/17`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Shoulder Sway (Phase 3C2, March 15, 2026)

- Added OTS shoulder-sway pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_shoulder_sway(...)` runs after evaluator output and before collision avoidance/response smoothing.
  - mode-gated to `RS_VCamModeOTS` (orbit/fixed/first-person modes are strict no-ops and clear stale sway state).
- Runtime sway contract implemented:
  - reads lateral intent from shared `input.move_input` (`move_input.x`) via `U_InputSelectors.get_move_input(...)`.
  - computes target roll as `move_input.x * shoulder_sway_angle` and clamps input to `[-1.0, 1.0]`.
  - smooths roll through per-vCam `U_SecondOrderDynamics` in `_shoulder_sway_state` keyed by `vcam_id`, with rebuild on smoothing changes.
  - applies roll on camera local forward axis (`basis.z`) and orthonormalizes resulting basis.
  - clears sway state on non-OTS mode, disabled angle (`0.0`), invalid transform payloads, and stale-vCam prune/clear paths.
- New/updated coverage:
  - `tests/unit/ecs/systems/test_vcam_system.gd`:
    - OTS sway disabled no-op
    - left/right strafe sign behavior
    - partial/full lateral-input scaling
    - authored max-angle bound
    - release-to-zero recovery
    - orbit/fixed no-op gating
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd`:
    - `shoulder_sway_angle` non-negative clamp behavior
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`115/115`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Landing Camera Response (Phase 3C3, March 15, 2026)

- Added OTS landing-response pass in `S_VCamSystem`:
  - new pipeline step `_apply_ots_landing_camera_response(...)` runs after response smoothing and before shared `landing_impact_offset` application.
  - mode-gated to `RS_VCamModeOTS` (non-OTS modes are strict no-ops and clear stale landing-response state).
- Event + runtime contract implemented:
  - `S_VCamSystem` now subscribes to `U_ECSEventNames.EVENT_ENTITY_LANDED` and extracts player-only landing payloads.
  - fall-speed normalization for OTS dip follows shared landing-impact thresholds (`5.0..30.0` -> `0.0..1.0`), supporting `fall_speed`, `vertical_velocity`, or `velocity.y` payloads.
  - per-vCam `_ots_landing_response_state` tracks `follow_target_id`, `recovery_speed_hz`, `current_offset`, `dynamics`, and `last_event_serial`.
  - on landing event, per-vCam dip triggers as `landing_dip_distance * normalized_fall_speed`; recovery runs through `U_SecondOrderDynamics` at `landing_dip_recovery_speed` toward zero.
  - distance compression is applied along OTS cast direction using the same shoulder-height cast origin contract as collision avoidance, with `OTS_MIN_CAMERA_DISTANCE` floor.
  - stale-vCam prune and non-OTS/disabled paths clear landing-response state.
- New/updated coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - disabled dip-distance no-op
  - landing-event distance compression
  - fall-speed scaling
  - smooth recovery toward authored distance
  - critically damped recovery (no distance overshoot above baseline)
  - stacking with shared landing-impact offset (distance + vertical dip)
  - orbit/fixed no-op gating
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`122/122`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`18/18`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Aiming Activation + Movement/Rotation Integration (Phase 3C4 slice, March 15, 2026)

- Added OTS aiming authoring fields in `RS_VCamModeOTS`:
  - `movement_profile`, `disable_sprint`, `lock_facing_to_camera`, `aim_blend_duration`.
  - `get_resolved_values()` now includes aiming passthrough/clamp values.
- Added `aim` input plumbing end-to-end:
  - `project.godot` + `U_InputMapBootstrapper` required action coverage.
  - Input profiles updated (gamepad LT + mouse right button defaults).
  - `U_InputActions`/`U_InputReducer`/`U_InputSelectors` + `C_InputComponent` now carry `aim_pressed`.
  - `I_InputSource`, keyboard/gamepad/touchscreen sources, `S_InputSystem`, and `S_TouchscreenSystem` now propagate `aim_pressed`.
  - `UI_MobileControls` now supports empty-space long-press aim toggle (`consume_aim_pressed()`), consumed by `S_TouchscreenSystem`.
- Added OTS aim activation in `S_VCamSystem`:
  - reads `input.aim_pressed` each tick.
  - `_process_aim_activation(...)` switches to OTS while aim is held and restores previous camera on release.
  - blend duration is read from OTS `aim_blend_duration` (min-clamped), not hardcoded.
  - OTS target selection prefers matching follow target before priority/id tie-break.
- Added OTS movement integration in `S_MovementSystem`:
  - resolves active OTS vCam via `state.vcam.active_vcam_id`.
  - applies `movement_profile` override when present.
  - enforces `disable_sprint` before speed calculation.
- Added OTS facing-lock integration in `S_RotateToInputSystem`:
  - resolves active OTS vCam via `state.vcam.active_vcam_id`.
  - when `lock_facing_to_camera` is true, desired yaw follows active camera yaw.
  - lock path preserves facing updates when move input is zero; non-OTS path unchanged.
- New/updated coverage:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`22/22`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`127/127`)
  - `tests/unit/ecs/systems/test_movement_system.gd` (`13/13`)
  - `tests/unit/ecs/systems/test_rotate_to_input_system.gd` (`6/6`)
  - input/mobile pipeline coverage across:
    - `test_input_map`, `test_u_input_actions`, `test_u_input_reducer`, `test_u_input_selectors`
    - `test_input_system`, `test_s_touchscreen_system`, `test_mobile_controls`
    - rebind/profile/integration suites touching required-action resets and category surfacing.
- Validation run:
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`127/127`)
  - `tests/unit/ecs/systems/test_input_system.gd` (`14/14`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`8/8`)
  - `tests/unit/ui/test_mobile_controls.gd` (`16/16`)
  - `tests/unit/ecs/systems/test_movement_system.gd` (`13/13`)
  - `tests/unit/ecs/systems/test_rotate_to_input_system.gd` (`6/6`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)
- Post-phase QA hardening run (March 15, 2026):
  - `tests/unit/ui/test_mobile_controls.gd` (`20/20`) with new joystick-area long-press exclusion regression.
  - `tests/unit/ecs/systems/test_movement_system.gd` (`14/14`) with new camera-relative OTS strafe regression.
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`131/131`)
  - `tests/unit/ecs/systems/test_rotate_to_input_system.gd` (`6/6`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`8/8`)
  - `tests/unit/ui/hud/test_ots_reticle.gd` (`4/4`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## OTS Reticle + Default Movement Preset (Phase 3C4.9/3C4.10/3C4.11, March 15, 2026)

- Added OTS reticle HUD implementation:
  - `scenes/ui/hud/ui_hud_overlay.tscn` now includes centered `OTSReticleContainer` + `ReticleDot` nodes (hidden by default).
  - `UI_HudController` now updates reticle visibility/fade from `state.vcam.active_mode` with gameplay+pause gating.
  - Reticle fade durations resolve from authored OTS `aim_blend_duration` using active vCam mode data, with `0.15s` fallback.
- Added OTS reticle coverage:
  - `tests/unit/ui/hud/test_ots_reticle.gd` (`4/4`) verifies hidden outside OTS, fade-in/fade-out duration behavior, and center-screen anchoring.
- Added default OTS movement preset:
  - `resources/base_settings/gameplay/cfg_ots_movement_default.tres` (`RS_MovementSettings`) with reduced-speed OTS defaults.
  - `resources/display/vcam/cfg_default_ots.tres` now references `cfg_ots_movement_default.tres` through `movement_profile`.
- Extended OTS mode resource coverage:
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` now includes preset load/value/reference checks (`24/24`).
- Validation run:
  - `tests/unit/ui/hud/test_ots_reticle.gd` (`4/4`)
  - `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd` (`24/24`)
  - `tests/unit/ui` (`-gselect=test_hud`, `28/28`)
  - `tests/unit/ecs/systems/test_movement_system.gd` (`13/13`)
  - `tests/unit/style/test_style_enforcement.gd` unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Previous: First-Person Strafe Tilt (Phase 9 / 3C1, March 15, 2026) — SUPERSEDED

- _This section is retained for historical context. The first-person mode has been replaced with OTS._
- Added first-person authored strafe-tilt fields:
  - `RS_VCamModeFirstPerson` exported `strafe_tilt_angle` and `strafe_tilt_smoothing`.
  - `get_resolved_values()` clamped both fields non-negative.
- Runtime strafe-tilt integration:
  - `S_VCamSystem` now reads `move_input` via `U_InputSelectors.get_move_input(state)`.
  - Added first-person-only roll application after evaluator output and before downstream smoothing (`_apply_first_person_strafe_tilt(...)`).
  - Roll target is `move_input.x * strafe_tilt_angle`, smoothed with per-vCam `U_SecondOrderDynamics` state keyed by `vcam_id`.
  - Strafe-tilt state resets when mode is not first-person, when authored angle is disabled (`0.0`), and during stale-vCam prune/clear.
- New/updated coverage:
  - `test_vcam_mode_first_person` +3 tests for strafe-tilt defaults/clamp (`11/11` total).
  - `test_vcam_system` +7 tests for first-person strafe-tilt behavior (`101/101` total):
    - disabled-path no-op
    - left/right sign
    - partial/full input scaling
    - authored max-angle bound
    - release-to-zero recovery
    - orbit/fixed no-op gating
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd` (`11/11`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`101/101`)
  - `tests/unit/style/test_style_enforcement.gd` remains at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Mobile Drag-Look + Touch Gating (Phase 7A/7B/7B2/7C, March 15, 2026)

- Runtime input ownership updates:
  - `UI_MobileControls` now tracks dedicated free-screen drag-look touches and exposes `consume_look_delta()` + `is_touch_look_active()`.
  - `S_TouchscreenSystem` now dispatches `U_InputActions.update_look_input(...)` from touch drag deltas and updates component look action strength.
  - `S_TouchscreenSystem` now dispatches `U_GameplayActions.set_touch_look_active(...)` on gesture lifecycle transitions.
  - `S_InputSystem` now hard-gates active touchscreen ticks so touch-owned move/look/button state is not zero-clobbered by `TouchscreenSource`.
- State/store contract updates:
  - `gameplay.touch_look_active` added to `RS_GameplayInitialState`, `U_GameplayActions`, `U_GameplayReducer`, and `U_GameplaySelectors`.
  - `U_StateSliceManager` now marks `touch_look_active` transient in gameplay slice config.
- New/updated coverage:
  - `test_mobile_controls` (drag-look delta + consume lifecycle + sensitivity/invert)
  - `test_s_touchscreen_system` (look dispatch + sensitivity/invert + one-shot delta + active flag lifecycle)
  - `test_input_system` (touchscreen no-clobber guard + touch-look-active preservation)
  - `test_gameplay_slice_reducers`, `test_state_selectors`, `test_m_state_store` (flag reducer/selector/transient config coverage)
- Validation run:
  - `tests/unit/ui/test_mobile_controls.gd` (`14/14`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`7/7`)
  - `tests/unit/ecs/systems/test_input_system.gd` (`13/13`)
  - `tests/unit/state/test_gameplay_slice_reducers.gd` (`10/10`)
  - `tests/unit/state/test_state_selectors.gd` (`7/7`)
  - `tests/unit/state/test_m_state_store.gd` (`29/29`)
  - `tests/unit/state/test_state_persistence.gd` (`9/9`)
  - `tests/integration/state/test_state_persistence.gd` (`2/2`)
  - `tests/unit/state/test_action_registry.gd` (`14/14`)
  - `tests/unit/state/test_u_gameplay_actions.gd` (`7/7`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tests/unit/style/test_style_enforcement.gd` remains at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Camera Center Input Consistency + Icon Coverage (Follow-up, March 15, 2026)

- Default binding alignment:
  - `camera_center` default gamepad binding is now `JOY_BUTTON_RIGHT_STICK` (`R3`, index `8`) in `project.godot`, `cfg_default_gamepad.tres`, and `cfg_accessibility_gamepad.tres`.
  - `sprint` remains `JOY_BUTTON_LEFT_STICK` (`L3`, index `7`).
- Prompt/icon contract updates:
  - `U_ButtonPromptRegistry` now uses Godot joypad constants for label mapping (canonical `L3`/`R3`/`R1` behavior).
  - Added explicit `camera_center` prompt defaults: keyboard `key_c` glyph and gamepad `button_rs` (`R3`).
  - Gameplay prompts are now binding-aware: resolve icon from current `InputMap` event first, fallback to registry defaults second.
  - Added `KEY_C` texture support in `U_InputEventDisplay`.
- Touchscreen recenter input:
  - `UI_MobileControls` now supports empty-space double-tap recenter (`0.30s` max interval, `72px` max distance) and exposes one-shot `consume_camera_center_just_pressed()`.
  - `S_TouchscreenSystem` now dispatches `update_camera_center_state(...)` from this one-shot consume path instead of hardcoded `false`.
- New/updated coverage:
  - `test_u_button_prompt_registry` (constant mapping + camera-center icon defaults + binding-aware icon resolution)
  - `test_button_prompt` (live gamepad rebind icon tracking for `camera_center`)
  - `test_mobile_controls` (double-tap success/over-control reject/threshold reject + one-shot consume)
  - `test_s_touchscreen_system` (double-tap dispatches one-frame `camera_center_just_pressed`)
  - `test_m_input_profile_manager_reset` + `test_rs_input_profile` (default `camera_center=R3`, `sprint=L3`)
- Validation run:
  - `tests/unit/input_manager` (`102/102`)
  - `tests/unit/ui/test_button_prompt.gd` (`15/15`)
  - `tests/unit/ui/test_hud_button_prompts.gd` (`3/3`)
  - `tests/unit/ui/test_mobile_controls.gd` (`12/12`)
  - `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`4/4`)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tests/unit/managers/test_m_input_profile_manager_reset.gd` (`1/1`)
  - `tests/unit/resources/test_rs_input_profile.gd` (`8/8`)
  - `tests/unit/style/test_style_enforcement.gd` remains unchanged at known pre-existing HUD inline-theme failure (`16/17`).

## Orbit Room Fade Shared-Wall Ownership Hardening (Phase 2C11A, March 21, 2026)

- Added deterministic shared-target ownership in `S_RoomFadeSystem`:
  - Per-tick pre-pass now assigns each fade target to the first component in filtered processing order.
  - Duplicate owners are skipped (first-owner-wins) and emit warn-and-continue diagnostics.
  - Warning emission is de-duplicated per target/component pair per tick.
- Added/expanded test coverage:
  - `tests/unit/ecs/systems/test_room_fade_system.gd`: added duplicate-ownership regression (`test_duplicate_target_ownership_keeps_first_component_and_skips_duplicate_updates`).
  - `tests/unit/ecs/systems/test_room_fade_scene_audit.gd`: added gameplay-scene ownership audit for `gameplay_interior_a.tscn` (single-owner targets + explicit unique `group_tag` per room-fade group).
- Scene authoring update (`scenes/gameplay/gameplay_interior_a.tscn`):
  - Authored explicit unique `group_tag` values on all six room-fade groups (`MasterBathroom`, `MasterBedroom`, `WalkInCloset`, `EntertainmentArea`, `GymArea`, `OfficeArea`) to make ownership boundaries explicit.
- Validation run:
  - `test_room_fade_integration`: `7/7` passing.
  - `test_room_fade_scene_audit`: `1/1` passing.
  - `test_room_fade_system`: `22/24` passing (`test_csg_normals_use_target_centroid_not_world_origin` + `test_csg_normals_correct_for_room_at_origin` remain red as pre-existing baseline drift unrelated to shared-ownership changes).
  - `test_style_enforcement`: `16/17` passing (known pre-existing path-space failure under `res://assets/textures/Prototype Grids PNG`).

## Orbit Room Fade Integration + Polish (Phase 2C11, March 15, 2026)

- Added integration coverage:
  - `tests/unit/ecs/systems/test_room_fade_integration.gd` (`7/7` passing)
- Integration coverage now verifies:
  - orbit-only gating (first-person/fixed no-op)
  - multi-group independence from authored normals
  - downward-normal ceiling fade behavior
  - one-tick mode-switch restore to opaque/original materials
  - coexistence with pre-existing silhouette-like shader overrides (restore-safe)
  - per-group custom-vs-default settings behavior
  - mesh + CSG full material restoration completeness
- Regression + compatibility validation run:
  - Room-fade suite aggregate (`test_room_fade*`): `48/48` passing
  - Orbit regressions: `test_vcam_system` (`94/94`) and `test_vcam_soft_zone` (`14/14`) passing
  - Silhouette settings integration proxy: `test_vfx_settings_ui` (`8/8`) passing
  - Renderer compatibility checks: `test_room_fade_integration` re-run with `--rendering-method mobile` and `--rendering-method gl_compatibility` (`7/7` each)
  - Style suite unchanged at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Room Fade Runtime (Phase 2C10, March 14, 2026)

- Added room-fade runtime/rendering stack:
  - `assets/shaders/sh_room_fade.gdshader`
  - `scripts/utils/lighting/u_room_fade_material_applier.gd`
  - `scripts/ecs/systems/s_room_fade_system.gd`
- Runtime contracts implemented:
  - `sh_room_fade.gdshader` uses `blend_mix` + `depth_draw_never` with room-fade uniforms (`fade_alpha`, `albedo_texture`, `albedo_color`) on the current transparency path (no alpha-scissor branch).
  - `U_RoomFadeMaterialApplier` caches/restores `material_override`, resolves source albedo (`material_override` -> surface override -> mesh surface), applies shader overrides, and updates per-target `fade_alpha`.
  - `S_RoomFadeSystem` runs as a standalone post-vCam system (`execution_priority = 110`), resolves camera from `camera_manager.get_main_camera()` with `Viewport.get_camera_3d()` fallback, gates to orbit via `state.vcam.active_mode`, computes fade using `dot(-camera_basis.z, wall_normal)`, and restores groups/materials immediately outside orbit mode.
- Added regression coverage:
  - `tests/unit/lighting/test_room_fade_material_applier.gd` (`6/6` passing)
  - `tests/unit/ecs/systems/test_room_fade_system.gd` (`15/15` passing)
- Validation run:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd` (`7/7` passing)
  - `tests/unit/ecs/components/test_room_fade_group_component.gd` (`11/11` passing)
  - `tests/unit/lighting/test_room_fade_material_applier.gd` (`6/6` passing)
  - `tests/unit/ecs/systems/test_room_fade_system.gd` (`15/15` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Room Fade Data Layer (Phase 2C9, March 14, 2026)

- Added room-fade data resource + component:
  - `scripts/resources/display/vcam/rs_room_fade_settings.gd`
  - `scripts/ecs/components/c_room_fade_group_component.gd`
  - `resources/display/vcam/cfg_default_room_fade.tres`
- Data-layer contracts implemented:
  - `RS_RoomFadeSettings` defaults (`fade_dot_threshold=0.3`, `fade_speed=4.0`, `min_alpha=0.05`) with clamp-safe `get_resolved_values()`.
  - `C_RoomFadeGroupComponent` exports (`group_tag`, `fade_normal`, nullable `settings`), runtime `current_alpha`, recursive mesh-target collection, parent-basis world-normal conversion, and snapshot reporting.
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd` (`7/7` passing)
  - `tests/unit/ecs/components/test_room_fade_group_component.gd` (`11/11` passing)
- Validation run:
  - `tests/unit/resources/display/vcam/test_room_fade_settings.gd`
  - `tests/unit/ecs/components/test_room_fade_group_component.gd`
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Button Recenter (Phase 2C8, March 14, 2026)

- Added input action + pipeline wiring for button recenter:
  - Added `camera_center` in `project.godot` + `U_InputMapBootstrapper.REQUIRED_ACTIONS`.
  - Extended input-source capture contract with `camera_center_just_pressed`.
  - Added `U_InputActions.update_camera_center_state(...)`, reducer/selectors plumbing, and `S_InputSystem` dispatch path so recenter intent flows through the shared input pipeline.
  - Updated input profiles/rebind category/localization coverage for the new action.
- Patched `S_VCamSystem` orbit recenter flow:
  - Added per-vCam runtime centering state (`_orbit_centering_state`) keyed by `vcam_id`.
  - On `camera_center` trigger, computes behind-player runtime yaw target (authored-yaw compensated), then interpolates over `0.3s` using smoothstep.
  - While centering is active, manual look-driven rotation updates are suppressed.
  - Re-triggering `camera_center` mid-center restarts deterministically from the current runtime pose.
  - No idle/timer auto-center behavior added.
- Added regression coverage:
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +4 tests (`94/94` total) for start, interpolation completion, manual-look suppression, and deterministic restart.
  - Input/rebind coverage updates:
    - `tests/unit/input/test_input_map.gd`
    - `tests/unit/input_manager/test_u_input_actions.gd`
    - `tests/unit/input_manager/test_u_input_reducer.gd`
    - `tests/unit/input_manager/test_u_input_selectors.gd`
    - `tests/unit/ecs/systems/test_input_system.gd`
    - `tests/unit/ui/test_input_rebinding_overlay.gd`
    - `tests/unit/integration/test_rebinding_flow.gd`
- Validation run:
  - `tests/unit/input/test_input_map.gd`
  - `tests/unit/input_manager` (full directory)
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/ui/test_input_rebinding_overlay.gd`
  - `tests/unit/integration/test_rebinding_flow.gd`
  - `tests/unit/integration/test_input_manager_integration_points.gd`
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing inline theme override failure in `scenes/ui/hud/ui_hud_overlay.tscn`)

## Orbit Input Release Smoothing (Phase 2C7, March 14, 2026)

- Extended `RS_VCamResponse` with orbit release-smoothing fields:
  - `look_release_yaw_damping`
  - `look_release_pitch_damping`
  - `look_release_stop_threshold`
  - `get_resolved_values()` now clamps all three fields to non-negative values.
- Patched `S_VCamSystem` orbit look-release path in `_resolve_runtime_rotation_for_evaluation(...)`:
  - reuses existing look-smoothing velocity state (`yaw_velocity` / `pitch_velocity`),
  - applies axis-specific release damping after input release,
  - clamps low-amplitude release velocities to zero via `look_release_stop_threshold`,
  - remains orbit-only (first-person/fixed behavior unchanged).
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`: +4 tests for new defaults/clamps (`24/24` total)
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +4 tests for deceleration, asymmetric damping, stop-threshold clamp/no-drift, and orbit-only gating (`86/86` total)
- Validation run:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`24/24` passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`86/86` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/17` passing; pre-existing failure in `scenes/ui/hud/ui_hud_overlay.tscn` inline theme overrides)

## Orbit Ground-Relative Positioning (Phase 2C6, March 11, 2026)

- Extended `RS_VCamResponse` with ground-relative tuning fields:
  - `ground_relative_enabled`
  - `ground_reanchor_min_height_delta`
  - `ground_probe_max_distance`
  - `ground_anchor_blend_hz`
  - `get_resolved_values()` now clamps ground-relative numeric fields to non-negative values.
- Patched `S_VCamSystem` with orbit-only ground-relative dual-anchor runtime state (`_ground_relative_state`) keyed by `vcam_id`:
  - resolves grounded state from gameplay/entity signals (`state.gameplay.entities[*].is_on_floor` first, then character/body fallback),
  - probes ground reference height only while grounded (bounded by `ground_probe_max_distance`),
  - keeps airborne vertical anchor locked (no per-frame Y chase while airborne),
  - re-anchors only on landing transitions meeting `ground_reanchor_min_height_delta`,
  - blends anchor updates with dedicated second-order dynamics using `ground_anchor_blend_hz`,
  - remains a strict no-op for non-orbit modes and when `ground_relative_enabled = false`.
- Added regression coverage:
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`: +5 tests for ground-relative defaults/clamps (`20/20` total)
  - `tests/unit/ecs/systems/test_vcam_system.gd`: +6 tests for jump lock, airborne lock, minor/major landing behavior, uneven-terrain stability, and non-orbit no-op (`78/78` total)
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Orbit UX Improvement Pass (March 10, 2026)

- Added `S_VCamSystem` to `scenes/gameplay/gameplay_interior_house.tscn` and `scenes/gameplay/gameplay_exterior.tscn` under `Systems/Core` with `execution_priority = 100` so gameplay scene coverage now matches base/bar/alleyway wiring.
- Patched `S_VCamSystem` so the active vCam writes evaluated `fov` into the primary camera-state `base_fov` each tick (`1..179` clamp, missing/invalid value no-op).
- Retuned global defaults for a balanced locked-pitch orbit pass:
  - `cfg_default_orbit.tres`: `distance=9.0`, `authored_pitch=-24.0`, `lock_y_rotation=true`, `rotation_speed=1.6`, `fov=65.0`
  - `cfg_default_response.tres` (superseded by later post-`0f51c36` tuning): `follow=4.2/0.85/1.0`, `rotation=9.0/0.9/1.0`, `look_ahead_distance=0.5`, `look_ahead_smoothing=4.0`
  - `cfg_default_soft_zone.tres`: `dead_zone=0.18/0.16`, `soft_zone=0.55/0.48`, `damping=3.0`, `hysteresis_margin=0.03`
  - `U_InputReducer` gamepad defaults: `right_stick_deadzone=0.16`, `right_stick_sensitivity=1.15`, `deadzone_curve=1`
- Added regression coverage:
  - `test_vcam_system`: active vCam `fov` sync to `base_fov`, clamp behavior, and missing/invalid `fov` no-op
  - `test_entity_scene_registration`: asserts `S_VCamSystem` exists in exterior/interior scenes
  - `test_u_input_reducer`: asserts updated gamepad defaults
- Validation run (green):
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/input_manager/test_u_input_reducer.gd`
  - `tests/unit/ecs/test_entity_scene_registration.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Movement-Style Camera Smoothing Follow-up (March 10, 2026)

- Patched `S_VCamSystem` to keep `C_VCamComponent.runtime_yaw` / `runtime_pitch` as raw target values while feeding evaluator rotation through per-vCam look-smoothing state (`smoothed_yaw`, `smoothed_pitch`, `yaw_velocity`, `pitch_velocity`).
- Added movement-style spring-damper stepping for orbit/first-person look smoothing:
  - `accel = error * (omega^2) - velocity * (2 * damping * omega)`
  - per-axis velocity+angle integration each physics tick with large-`delta` guard.
- Added deterministic look-smoothing reset rules on mode changes, follow-target changes, response tuning changes, null-response passthrough paths, and per-vCam prune/clear cleanup.
- Prevented double-softness in rotation:
  - kept follow-position response smoothing unchanged,
  - made orbit/first-person look smoothing the rotation authority,
  - preserved fixed-mode rotation smoothing behavior.
- Expanded `tests/unit/ecs/systems/test_vcam_system.gd` with 6 follow-up tests:
  - raw runtime yaw/pitch remain immediate with response enabled,
  - first-frame large-look jump submits smoothed rotation,
  - rotation converges to raw evaluator pose,
  - reset behavior on mode switch, follow-target switch, and response change.
- Validation run (green):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, `62/62` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`15/15` passing)

## Camera Look Smoothing Parity Pass (March 10, 2026)

- Extended `RS_VCamResponse` with response-driven look feel controls:
  - `look_input_deadzone`, `look_input_hold_sec`, `look_input_release_decay`
  - `orbit_look_bypass_enable_speed`, `orbit_look_bypass_disable_speed` (disable speed clamped to `>=` enable speed)
- Retuned `resources/display/vcam/cfg_default_response.tres` to include conservative defaults for the new look filter and speed-aware orbit bypass fields.
- Patched `S_VCamSystem` with per-vCam look-input activity filtering state (`_look_input_filter_state`) that keeps bursty look streams active through a short hold/decay window for smoothing/gating decisions without adding extra runtime yaw/pitch accumulation.
- Added per-vCam follow-target motion sampling (`_follow_target_motion_state`) and replaced orbit's unconditional look-input bypass with speed-aware hysteresis gating:
  - stationary/slow targets keep the no-lag bypass behavior,
  - moving targets keep follow-position smoothing active while rotating.
- Expanded regression coverage in `tests/unit/ecs/systems/test_vcam_system.gd`:
  - first-person + orbit look-hold continuity checks (no extra runtime rotation),
  - look-release decay deactivation,
  - moving-target bypass disablement,
  - bypass hysteresis between enable/disable thresholds.
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`15/15` passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`70/70` passing)
  - `tests/unit/style/test_style_enforcement.gd` (`16/16` passing)

## Post-0f51 Orbit Retune Doc/Test Catch-up (March 10, 2026)

- Synced continuation/overview/tasks docs with the current tuned orbit response baseline in `cfg_default_response.tres`:
  - `follow_frequency=3.8`, `follow_damping=1.0`
  - `rotation_frequency=4.8`, `rotation_damping=0.9`
  - `look_ahead_distance=0.02`, `look_ahead_smoothing=1.77`
  - `orbit_look_bypass_enable_speed=7.0`, `orbit_look_bypass_disable_speed=8.5`
- Added preset regression coverage in `tests/unit/resources/display/vcam/test_vcam_mode_presets.gd` for:
  - `cfg_default_response.tres` load/type contract (`RS_VCamResponse`)
  - tuned baseline value assertions for the fields above
- Added style-guard coverage in `tests/unit/style/test_style_enforcement.gd` to fail if authored scenes re-enable `debug_rotation_logging = true`.
- Validation run (green):
  - `tests/unit/resources/display/vcam/test_vcam_mode_presets.gd`
  - `tests/unit/style/test_style_enforcement.gd`

## Phase 0 Progress (March 10, 2026)

- Completed Phase 0A:
  - Persisted touchscreen look settings (`look_drag_sensitivity`, `invert_look_y`) through reducer/serialization paths.
  - Patched `UI_TouchscreenSettingsOverlay` scene/controller for new controls, localization, and apply/reset flow.
  - Updated touchscreen settings resource defaults and unit/UI localization tests.
- Completed Phase 0A2:
  - Added dedicated `look_left/right/up/down` actions to InputMap bootstrap and keyboard profiles.
  - Added keyboard-look action/reducer/serialization plumbing in input settings.
  - Extended `KeyboardMouseSource` + `S_InputSystem` to emit keyboard-look through shared `gameplay.look_input`.
  - Added `UI_KeyboardMouseSettingsOverlay` + scene-registry/UI-registry wiring + settings-menu entrypoint.
  - Updated rebind action category/localization surface and added overlay/unit/integration tests.
- Completed Phase 0B:
  - Added persisted `vfx.occlusion_silhouette_enabled` defaults to `RS_VFXInitialState` and reducer state.
  - Added `U_VFXActions.set_occlusion_silhouette_enabled(...)` plus reducer/selectors/global-settings apply plumbing.
  - Wired silhouette toggle UI in `UI_VFXSettingsOverlay` scene/controller (apply/cancel/reset + focus/theme/localization/tooltips).
  - Added new VFX silhouette localization keys across all UI locale resources.
  - Updated VFX/state/unit/integration tests to cover silhouette state, UI behavior, and global-settings load path.
- Completed Phase 0C:
  - Added `scripts/resources/state/rs_vcam_initial_state.gd` with the full 11-field runtime observability contract (including `in_fov_zone`).
  - Added `resources/state/cfg_default_vcam_initial_state.tres` for upcoming state-store/root wiring.
  - Added `tests/unit/state/test_vcam_initial_state.gd` with 12 assertions covering default values and key count.
- Completed Phase 0D:
  - Added `scripts/state/actions/u_vcam_actions.gd` with 8 registered action creators (`set_active_runtime`, blend lifecycle, silhouette count, target validity, recovery reason, `update_fov_zone`).
  - Added `scripts/state/reducers/u_vcam_reducer.gd` with full state-default merge + action handling (`blend_progress` clamp, silhouette non-negative clamp, unknown action unchanged-state return).
  - Added vCam ECS event constants to `scripts/events/ecs/u_ecs_event_names.gd` (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`).
  - Added new tests `tests/unit/state/test_vcam_actions.gd` (8) and `tests/unit/state/test_vcam_reducer.gd` (13).
- Completed Phase 0E:
  - Added `scripts/state/selectors/u_vcam_selectors.gd` and `tests/unit/state/test_vcam_selectors.gd` (23 tests) for null-safe vCam runtime/selector access.
  - Wired `vcam_initial_state` export into `M_StateStore` and `U_StateSliceManager.initialize_slices(...)`.
  - Registered `vcam` in `U_StateSliceManager` with `is_transient = true` and reducer hookup to `U_VCamReducer`.
  - Patched `scenes/root.tscn` so `M_StateStore.vcam_initial_state` references `cfg_default_vcam_initial_state.tres`.
  - Added integration assertions proving `vcam` exists at runtime, is marked transient, is excluded from save payloads, and is excluded from global-settings serialization.
- Completed Phase 0F:
  - Patched `S_CameraStateSystem` to resolve FOV-zone state through `U_VCamSelectors.is_in_fov_zone(state)` instead of legacy `state.camera` reads.
  - Updated `resources/qb/camera/cfg_camera_zone_fov_rule.tres` to `state_path = "vcam.in_fov_zone"` so rule-driven FOV behavior matches migrated runtime state.
  - Updated QB camera unit/integration tests to seed `set_slice("vcam", {"in_fov_zone": ...})` and removed remaining non-doc `camera.in_fov_zone` references.
- Completed Phase 1A:
  - Added `RS_VCamSoftZone` (`scripts/resources/display/vcam/rs_vcam_soft_zone.gd`) with exported dead-zone/soft-zone dimensions and damping defaults.
  - Added `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd` (7 tests) for default values and bounds/order guards.
- Completed Phase 1B:
  - Added `RS_VCamBlendHint` (`scripts/resources/display/vcam/rs_vcam_blend_hint.gd`) with blend/tween fields and `is_instant_cut()` helper.
  - Added `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd` (7 tests) for defaults, non-negative constraints, and zero-duration cut semantics.
- Completed Phase 1C:
  - Added `resources/display/vcam/cfg_default_soft_zone.tres`.
  - Added `resources/display/vcam/cfg_default_blend_hint.tres`.
- Completed Phase 1D:
  - Added `scripts/utils/math/u_second_order_dynamics.gd` (`U_SecondOrderDynamics`) with semi-implicit integration, frequency clamp, large-`dt` guard, and finite-value fallback handling.
  - Added `tests/unit/utils/test_second_order_dynamics.gd` (13 tests) covering convergence, damping regimes, reset behavior, and response tuning.
- Completed Phase 1E:
  - Added `scripts/utils/math/u_second_order_dynamics_3d.gd` (`U_SecondOrderDynamics3D`) as a 3-axis wrapper over `U_SecondOrderDynamics`.
  - Added `tests/unit/utils/test_second_order_dynamics_3d.gd` (7 tests) covering vector convergence, axis independence, reset, and damping-regime behavior.
- Completed Phase 1F:
  - Added `scripts/resources/display/vcam/rs_vcam_response.gd` (`RS_VCamResponse`) with follow/rotation second-order tuning fields.
  - Added `tests/unit/resources/display/vcam/test_vcam_response.gd` (8 tests) covering defaults and resolved non-negative/positive clamp behavior.
  - Added `resources/display/vcam/cfg_default_response.tres` with Phase 1F defaults (`follow: 3.0/0.7/1.0`, `rotation: 4.0/1.0/1.0`).
- Completed Phase 2A:
  - Added `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` (`RS_VCamModeOrbit`) with authored orbit defaults (`distance`, `authored_pitch`, `authored_yaw`, `allow_player_rotation`, `lock_x_rotation`, `lock_y_rotation`, `rotation_speed`, `fov`) plus `get_resolved_values()` clamp/sanitation helper for deterministic runtime reads.
  - Added/expanded `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd` (14 tests) for defaults, baseline constraints, axis-lock defaults, and resolved-value safety behavior.
- Completed Phase 2B:
  - Added `scripts/managers/helpers/u_vcam_mode_evaluator.gd` (`U_VCamModeEvaluator`) with orbit-mode evaluation branch, resolved-value consumption, and null-safe invalid-input guards.
  - Added/expanded `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (14 orbit tests, 39 evaluator tests total) for transform/FOV/mode-name outputs, authored/runtime rotation behavior, and invalid-input handling.
  - Added `resources/display/vcam/cfg_default_orbit.tres` with baseline orbit defaults for scene/template wiring.
- Completed Legacy Phase 3A (Superseded):
  - Added `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd` (`RS_VCamModeFirstPerson`) with defaults (`head_offset`, `look_multiplier`, `pitch_min`, `pitch_max`, `fov`) and `get_resolved_values()` clamping/ordering helpers.
  - Added `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd` (8 tests) for defaults and resolved constraint behavior (`fov`, `look_multiplier`, pitch-bound ordering).
- Completed Legacy Phase 3B (Superseded):
  - Extended `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with first-person evaluation branch (position from `follow_target + head_offset`, yaw/pitch basis construction, in-evaluator pitch clamp, and null-safe guards).
  - Extended `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` with first-person coverage (10 new tests, 20 total evaluator tests).
  - Added `resources/display/vcam/cfg_default_first_person.tres` with baseline first-person defaults.
- Completed Phase 4A:
  - Added `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd` (`RS_VCamModeFixed`) with fixed-camera defaults (`use_world_anchor`, `track_target`, `fov`, `tracking_damping`, `follow_offset`, `use_path`, `path_max_speed`, `path_damping`) and `get_resolved_values()` clamp helpers.
  - Added `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd` (13 tests) for fixed resource defaults and resolved constraint behavior.
- Completed Phase 4B:
  - Extended `scripts/managers/helpers/u_vcam_mode_evaluator.gd` with fixed evaluation branch (world-anchor mode, follow-offset mode, path mode, runtime yaw/pitch ignore contract, and null-safe guards).
  - Extended `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` with fixed coverage (15 new tests, 35 total evaluator tests).
  - Added `resources/display/vcam/cfg_default_fixed.tres` with baseline fixed defaults.
- Completed Phase 5:
  - Added `scripts/ecs/components/c_vcam_component.gd` (`C_VCamComponent`) with full authoring exports (`vcam_id`, priority/mode/paths, entity-id/tag follow fallbacks, soft-zone/blend/response resources, `is_active`), strict `RS_VCamResponse` export hint/guarding, and runtime orientation fields (`runtime_yaw`, `runtime_pitch`).
  - Added null-safe component getters (`get_follow_target`, `get_look_at_target`, `get_fixed_anchor`, `get_path_node`) plus `get_mode_name()` normalization for runtime observability/event payloads.
  - Added ServiceLocator-driven vCam-manager registration lifecycle in `C_VCamComponent` (`register_vcam` on ready/registration, `unregister_vcam` on exit) so persistent manager references are cleaned up on scene unload.
  - Added `scripts/interfaces/i_vcam_manager.gd` with the 8-method manager contract (`register/unregister`, active selection, blend observability, same-frame submission API).
  - Added `scripts/managers/m_vcam_manager.gd` with core registry, ServiceLocator registration, explicit-id and priority-based active selection, deterministic tie-break (`vcam_id` ascending), inactive-camera exclusion, re-selection on runtime state changes, and active-clear event correctness for unregister/pruned-active flows.
  - Added `M_VCamManager` observability/event integration:
    - Redux dispatch via `U_VCamActions.set_active_runtime(...)` (injection-first store lookup with ServiceLocator fallback).
    - ECS publish via `U_ECSEventBus.publish(U_ECSEventNames.EVENT_VCAM_ACTIVE_CHANGED, {...})`.
    - Same-frame handoff API stubbed via `submit_evaluated_camera(vcam_id, result)` for Phase 6 system integration.
  - Added Phase 5 tests:
    - `tests/unit/ecs/components/test_vcam_component.gd` (15 tests).
    - `tests/unit/managers/test_vcam_manager.gd` (22 tests: registration + active selection + clear/recovery transition + dispatch/event coverage).
- Completed Phase 6A:
  - Added `scripts/ecs/systems/s_vcam_system.gd` with ServiceLocator/injection lookup for `I_VCamManager`, Redux look-input consumption, orbit/first-person runtime angle updates, active/outgoing vCam evaluation during blends, and same-frame submission via `submit_evaluated_camera(...)`.
  - Implemented follow-target resolution priority in `S_VCamSystem`: `follow_target_path` -> `follow_target_entity_id` (`get_entity_by_id`) -> `follow_target_tag` (`get_entities_by_tag`) -> recovery.
  - Added gameplay-local fixed-path helper handling in `S_VCamSystem` (`PathFollow3D` under authored `Path3D`), including invalid-target recovery behavior that does not fabricate new path progress.
  - Added `tests/unit/ecs/systems/test_vcam_system.gd` with 17 tests covering the full Phase 6A contract.
  - Extended ECS manager interface/mocks with `get_entities_by_tag(...)` / `get_entities_by_tags(...)` for typed target-resolution queries in systems/tests.
- Completed Phase 6B:
  - Added `M_VCamManager` node to `scenes/root.tscn`.
  - Updated `scripts/root.gd` ServiceLocator bootstrap to register `vcam_manager` and declare `vcam_manager -> {state_store, camera_manager}` dependencies.
  - Added `S_VCamSystem` to `scenes/templates/tmpl_base_scene.tscn` and gameplay scene system trees (`scenes/gameplay/gameplay_base.tscn`, `scenes/gameplay/gameplay_bar.tscn`, `scenes/gameplay/gameplay_alleyway.tscn`) under `Systems/Core` with `execution_priority = 100` (after movement, before feedback).
  - Added default `C_VCamComponent` to `scenes/templates/tmpl_camera.tscn` with `cfg_default_orbit.tres` plus default soft-zone/blend/response resources and `follow_target_entity_id = &"player"`.
- Completed Phase 6A2:
  - Extended `scripts/ecs/systems/s_vcam_system.gd` with per-vCam response smoothing state: `U_SecondOrderDynamics3D` for position and per-axis `U_SecondOrderDynamics` for rotation.
  - Added `RS_VCamResponse` integration path in `S_VCamSystem` with null-response passthrough behavior (raw evaluator output when no response resource is assigned).
  - Added deterministic smoothing lifecycle rules: create-on-first-eval, recreate on response tuning change, reset on mode switch and follow-target switch.
  - Added Euler unwrapping for rotation smoothing targets to avoid long-path spins across angle wrap boundaries.
  - Expanded `tests/unit/ecs/systems/test_vcam_system.gd` from 17 to 25 tests with dedicated Phase 6A2 coverage.
- Completed Phase 6A.3:
  - Added 6 rotation-continuity tests to `tests/unit/ecs/systems/test_vcam_system.gd` covering orbit↔first-person carry/reset, orbit→fixed outgoing preservation, fixed→orbit authored reseed, and same-mode target-aware carry/reseed behavior.
  - Patched `S_VCamSystem` with active-vCam transition continuity policy hooks so runtime yaw/pitch apply carry/reset/reseed rules before evaluation on mode switches.
  - Added continuity helper rules for same-mode shared-target carry and authored-angle reseed fallback when follow targets differ.
- Completed Phase 6A3a:
  - Added `tests/unit/ecs/components/test_camera_state_component.gd` to cover landing-impact and speed-FOV component defaults/exports.
  - Extended `C_CameraStateComponent` with `landing_impact_offset`, `landing_impact_recovery_speed`, `speed_fov_bonus`, and `speed_fov_max_bonus`.
  - Extended `C_CameraStateComponent.reset_state()` and `get_snapshot()` so the new runtime fields are reset/snapshotted consistently for downstream systems.
- Completed Phase 6A3b:
  - Added `resources/qb/camera/cfg_camera_speed_fov_rule.tres` (`camera_speed_fov`) and registered it in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`.
  - Extended `S_CameraStateSystem` context building to expose primary movement-speed magnitude to QB camera rules through a `C_MovementComponent` component snapshot.
  - Patched `S_CameraStateSystem._resolve_target_fov()` to compose `base_target + clamp(speed_fov_bonus, 0.0, speed_fov_max_bonus)` and clamp/write back invalid bonus values.
  - Extended QB effect execution with winner-score context and added `RS_EffectSetField` score scaling (`scale_by_rule_score`) so speed-FOV rules can map normalized condition score to authored max bonus.
  - Expanded `tests/unit/qb/test_camera_state_system.gd` with 6 speed-FOV coverage tests and `tests/unit/qb/test_effect_set_field.gd` with score-scaling coverage.
- Completed Phase 6A3c:
  - Added `resources/qb/camera/cfg_camera_landing_impact_rule.tres` (`camera_landing_impact`) and registered it in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`.
  - Extended `RS_EffectSetField` with `vector3` literal support plus rule-score scaling for vector values, enabling score-scaled `landing_impact_offset` writes.
  - Patched `S_CameraStateSystem` event evaluation to prefilter event rules by subscribed event name before scoring, preventing cross-event side effects when score thresholds allow zero-score winners.
  - Added landing impact application/recovery in `S_VCamSystem`: reads `C_CameraStateComponent.landing_impact_offset`, applies offset to evaluated transforms, and recovers/writes back toward `Vector3.ZERO` via `U_SecondOrderDynamics3D` at `landing_impact_recovery_speed`.
  - Expanded tests in `tests/unit/qb/test_camera_state_system.gd`, `tests/unit/ecs/systems/test_vcam_system.gd`, and `tests/unit/qb/test_effect_set_field.gd` for landing-rule scaling and recovery behavior.
- Completed Phase 2C1:
  - Extended `RS_VCamResponse` with `look_ahead_distance` + `look_ahead_smoothing`, including non-negative resolved-value clamping.
  - Extended `S_VCamSystem` with orbit-only look-ahead state (`_look_ahead_state`) using movement velocity samples (`state.gameplay.entities[*].velocity` first, then movement-component/body fallback) and pre-smoothing position offsets before main response smoothing.
  - Added look-ahead coverage to `tests/unit/ecs/systems/test_vcam_system.gd` (disabled path, moving offset, clamp bound, stationary zero-offset, mode-switch clear, target-switch reset, first-person no-op, rotation-only target motion no-op).
  - Updated `resources/display/vcam/cfg_default_response.tres` with explicit defaults for look-ahead fields.
- Completed Phase 2C2:
  - Extended `RS_VCamResponse` with `auto_level_speed` + `auto_level_delay`, including non-negative resolved-value clamping.
  - Extended `S_VCamSystem` with orbit-only no-look timer tracking (`_orbit_no_look_input_timers`) and delayed pitch recentering via `move_toward(...)`.
  - Added auto-level coverage to `tests/unit/ecs/systems/test_vcam_system.gd` (disabled path, delayed decay, non-zero look suppression, timer reset, speed-rate behavior, first-person/fixed no-op).
- Completed Phase 2C3:
  - Added `scripts/managers/helpers/u_vcam_soft_zone.gd` (`U_VCamSoftZone`) with projection-based correction (`unproject_position`/`project_position`), near-plane guard, normalized-zone evaluation, damping-scaled soft-zone correction, and hard-zone clamping.
  - Added `tests/unit/managers/helpers/test_vcam_soft_zone.gd` baseline coverage for dead-zone no-op, soft/hard correction behavior, damping scaling, viewport/depth coverage, boundary direction correctness, null-disable behavior, and zero-dead/full-soft edge cases.
- Completed Phase 2C4:
  - Extended `RS_VCamSoftZone` with `hysteresis_margin` plus resolved-value clamping via `get_resolved_values()`.
  - Extended `U_VCamSoftZone` with optional per-axis hysteresis state handoff (`dead_zone_state`) and Schmitt-style thresholds (`exit = dead + margin`, `entry = dead - margin`).
  - Extended helper tests with hysteresis coverage for exit/entry thresholds, boundary oscillation stability, and `hysteresis_margin = 0.0` backward compatibility.
- Completed Phase 2C5:
  - Integrated orbit-only soft-zone correction into `S_VCamSystem` before response smoothing (`_apply_orbit_soft_zone(...)`) so second-order follow dynamics smooth the resulting corrected pose.
  - Added per-vCam dead-zone tracking in `S_VCamSystem` (`_soft_zone_dead_zone_state`) and stale-state pruning alongside existing vCam lifecycle cleanup.
  - Added `S_VCamSystem` regression tests for orbit correction enablement, missing soft-zone no-op, and first-person no-op gating.
- Validation run (green):
  - `tests/unit/input_manager/test_u_input_reducer.gd`
  - `tests/unit/input/test_input_map.gd`
  - `tests/unit/resources/test_rs_touchscreen_settings.gd`
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
  - `tests/unit/ui/test_input_rebinding_overlay.gd`
  - `tests/unit/ui/test_keyboard_mouse_settings_overlay.gd`
  - `tests/unit/integration/test_rebinding_flow.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0B):
  - `tests/unit/state/test_vfx_initial_state.gd`
  - `tests/unit/state/test_vfx_reducer.gd`
  - `tests/unit/state/test_vfx_selectors.gd`
  - `tests/unit/state/test_global_settings_persistence.gd`
  - `tests/integration/state/test_vfx_slice_integration.gd`
  - `tests/integration/vfx/test_vfx_settings_ui.gd`
  - `tests/unit/ui/test_vfx_settings_overlay_localization.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0C):
  - `tests/unit/state/test_vcam_initial_state.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0D):
  - `tests/unit/state/test_vcam_actions.gd`
  - `tests/unit/state/test_vcam_reducer.gd`
  - `tests/unit/state/test_action_registry.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0E):
  - `tests/unit/state/test_vcam_selectors.gd`
  - `tests/unit/state/test_m_state_store.gd`
  - `tests/unit/state/test_state_persistence.gd`
  - `tests/unit/state/test_global_settings_persistence.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 0F):
  - `tests/unit/qb/test_camera_state_system.gd`
  - `tests/integration/qb/test_camera_shake_pipeline.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 1A/1B/1C):
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1D):
  - `tests/unit/utils/test_second_order_dynamics.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1E):
  - `tests/unit/utils/test_second_order_dynamics_3d.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 1F):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 2A/2B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 3A/3B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phases 4A/4B):
  - `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 5):
  - `tests/unit/ecs/components/test_vcam_component.gd`
  - `tests/unit/managers/test_vcam_manager.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 2A-5 gap-closure hardening):
  - `tests/unit` (`-gselect=test_vcam_mode`)
  - `tests/unit/ecs/components` (`-gselect=test_vcam_component`)
  - `tests/unit/managers` (`-gselect=test_vcam_manager`)
  - `tests/unit/style` (`-ginclude_subdirs=true`)
- Validation run (green, Phase 6A/6B):
  - `tests/unit/ecs/systems/test_vcam_system.gd`
  - `tests/unit/managers/test_vcam_manager.gd`
  - `tests/unit/ecs/components/test_vcam_component.gd`
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 6A2):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 25/25 passing)
  - `tests/unit/style/test_style_enforcement.gd`
- Validation run (green, Phase 6A.3):
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 31/31 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3a):
  - `tests/unit/ecs/components/test_camera_state_component.gd` (`-gselect=test_camera_state_component`, 5/5 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 11/11 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3b):
  - `tests/unit/qb/test_effect_set_field.gd` (`-gselect=test_effect_set_field`, 7/7 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 16/16 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 6A3c):
  - `tests/unit/qb/test_effect_set_field.gd` (`-gselect=test_effect_set_field`, 8/8 passing)
  - `tests/unit/qb/test_camera_state_system.gd` (`-gselect=test_camera_state_system`, 20/20 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 35/35 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C1/2C2):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`-gselect=test_vcam_response`, 11/11 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 48/48 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C3/2C4/2C5):
  - `tests/unit/managers/helpers/test_vcam_soft_zone.gd` (`-gselect=test_vcam_soft_zone`, 14/14 passing)
  - `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd` (`-gselect=test_vcam_soft_zone`, 8/8 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 51/51 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 13/13 passing)
- Validation run (green, Phase 2C6):
  - `tests/unit/resources/display/vcam/test_vcam_response.gd` (`-gselect=test_vcam_response`, 20/20 passing)
  - `tests/unit/ecs/systems/test_vcam_system.gd` (`-gselect=test_vcam_system`, 78/78 passing)
  - `tests/unit/style/test_style_enforcement.gd` (`-gselect=test_style_enforcement`, 17/17 passing)

## What Changed In The Docs

- Runtime wiring is now explicit: `M_VCamManager` belongs in `scenes/root.tscn`, and `S_VCamSystem` belongs in gameplay system trees.
- Phase 12 integration coverage is now implementation-backed with dedicated `tests/integration/vcam/*` suites for state/runtime/blend/mobile/occlusion paths (`29/29` passing).
- Blend observability ordering is now explicit: `M_VCamManager` dispatches `vcam/set_active_runtime` before `vcam/start_blend` so reducer `blend_to_vcam_id` reflects the incoming active camera during live blends.
- vCam top-level docs are now status-aligned: overview/PRD/task index/continuation now mark Phases 2A-5 plus 6A/6B/6A2/6A.3/6A3a/6A3b/6A3c and Phase 8 orbit feel/data/runtime subphases 2C1-2C11 complete.
- Orbit follow-up backlog planning is now explicit: `docs/vcam_manager/vcam-orbit-tasks.md` marks `2C11` complete, and mobile drag-look/touch gating prerequisites are now complete in `docs/vcam_manager/vcam-base-tasks.md` (Phase 7A/7B/7B2/7C).
- `S_VCamSystem` baseline contract is now implementation-backed: manager resolution, target resolution fallback order, blend-aware active/outgoing evaluation, and same-frame submission are in code/tests.
- `S_VCamSystem` response-smoothing contract is now implementation-backed: `RS_VCamResponse` drives position/rotation second-order smoothing, response-null passthrough keeps backward compatibility, and mode/target/response transitions reset or recreate smoothing state deterministically.
- `S_VCamSystem` movement-style look smoothing contract is now implementation-backed for orbit/OTS: runtime yaw/pitch remain raw targets on `C_VCamComponent`, evaluator rotation is fed by per-vCam spring-damper look state, and fixed-mode rotation smoothing remains owned by response smoothing.
- _`RS_VCamModeFirstPerson` strafe-tilt authoring contract was implementation-backed but is now superseded by OTS mode replacement (March 14, 2026)._
- _`S_VCamSystem` first-person strafe-tilt runtime contract was implementation-backed for Phase 9/3C1 but is now superseded by OTS shoulder sway (March 14, 2026)._
- `S_VCamSystem` OTS collision-avoidance contract is now implementation-backed for Phase 3C1: gameplay-world spherecast + initial-overlap guard, per-vCam collision distance state (`_ots_collision_state`), immediate hit clamping with minimum distance floor, smooth recovery via `U_SecondOrderDynamics`, and non-OTS/stale-vCam state cleanup.
- `S_VCamSystem` OTS shoulder-sway contract is now implementation-backed for Phase 3C2: reads shared `input.move_input.x`, applies OTS-only roll target (`move_input.x * shoulder_sway_angle`), smooths via per-vCam `U_SecondOrderDynamics` state (`_shoulder_sway_state`), and clears/reset state on non-OTS, disabled-angle, and stale-vCam prune paths.
- `S_VCamSystem` OTS landing-response contract is now implementation-backed for Phase 3C3: subscribes to `EVENT_ENTITY_LANDED`, normalizes player landing fall speed (`5..30`) to OTS dip strength, applies OTS-only distance compression via per-vCam `_ots_landing_response_state` (`U_SecondOrderDynamics`), stacks with shared `landing_impact_offset`, and clears/reset state on non-OTS/disabled/stale paths.
- Phase 3C4 aiming slice 1 is now implementation-backed: `RS_VCamModeOTS` aiming exports, `aim` input action plumbing (desktop/mobile), `S_VCamSystem` aim enter/exit switching with authored `aim_blend_duration`, `S_MovementSystem` OTS movement-profile + sprint gating, and `S_RotateToInputSystem` OTS camera-facing lock are all landed with tests.
- `RS_VCamResponse` orbit-feel contract is now implementation-backed: `look_ahead_distance`, `look_ahead_smoothing`, `auto_level_speed`, and `auto_level_delay` are authored/clamped fields with defaults persisted in `cfg_default_response.tres`.
- `S_VCamSystem` rotation-continuity contract is now implementation-backed: active-vCam switches apply transition-aware carry/reset/reseed of `runtime_yaw`/`runtime_pitch`, with same-target carry in same-mode transitions and authored-angle reseed when targets differ.
- `S_VCamSystem` orbit game-feel contract is now implementation-backed for Phase 2C1-2C5: look-ahead offsets are applied before main response smoothing using per-vCam movement-velocity state (not follow-target transform deltas), auto-level pitch recentering is orbit-only with delayed activation and look-input reset behavior, and projection-based soft-zone correction (with per-vCam dead-zone hysteresis state) is applied before response smoothing.
- `S_VCamSystem` orbit ground-relative contract is now implementation-backed for Phase 2C6: per-vCam dual-anchor state (`follow` + `ground`) locks vertical anchor while airborne, uses grounded-only ground references bounded by `ground_probe_max_distance`, and only re-anchors on qualifying landings (`ground_reanchor_min_height_delta`) with dedicated anchor blending (`ground_anchor_blend_hz`).
- `U_VCamSoftZone` now defines the canonical projection/reprojection helper contract for orbit framing correction, including near-plane skip behavior and damping/hysteresis handling.
- `C_CameraStateComponent` now exposes landing-impact and speed-FOV fields required by the Phase 6A3 QB feel pipeline, and includes those fields in component reset/snapshot behavior.
- `S_CameraStateSystem` speed-FOV composition is now implementation-backed: movement-speed rule context, score-scaled `RS_EffectSetField` writes, and target-FOV composition/clamping now flow through the default `camera_speed_fov` QB rule.
- Runtime scene wiring is now landed in authored scenes: `M_VCamManager` in root, `S_VCamSystem` in template/gameplay system trees, and `C_VCamComponent` defaults in `tmpl_camera.tscn`.
- Phase 11 editor preview wiring is now implementation-backed: `U_VCamRuleOfThirdsPreview` (`scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`) is wired into `tmpl_camera.tscn`, renders an editor-only thirds grid via internal `CanvasLayer`, and self-frees outside editor for zero runtime cost.
- The `vcam` Redux slice is now defined as transient runtime observability only.
- The silhouette enable/disable toggle moved to the persisted `vfx` slice.
- VFX settings UI integration is now explicit: wire the silhouette toggle into `UI_VFXSettingsOverlay` (`scripts/ui/settings/ui_vfx_settings_overlay.gd` + `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`) and localize it in all `cfg_locale_*_ui.tres` files.
- The blend design now evaluates both outgoing and incoming cameras live during blends.
- Live blend manager behavior is now implementation-backed: `M_VCamManager` blends frame-stamped active/outgoing submissions, supports reentrant snapshot interruption, and dispatches recovery reasons for invalid blend endpoints.
- The camera integration now requires a shake-safe `M_CameraManager.apply_main_camera_transform(...)` API instead of direct `camera.global_transform` writes.
- Soft-zone math is now defined as projection-based rather than basis-vector offset math.
- Soft-zone projection and occlusion raycasts are now explicitly tied to the active gameplay camera viewport and `World3D` inside `GameViewport`, not the root manager node's viewport/world.
- Mobile drag-look is now a hard requirement for rotatable orbit and OTS support.
- Mobile drag-look settings belong in `settings.input_settings.touchscreen_settings`, and the touch look path must extend `UI_MobileControls` plus `S_TouchscreenSystem`.
- `S_InputSystem` must be gated so it does not overwrite touchscreen gameplay input with zero `TouchscreenSource` payloads.
- Fixed-mode anchor ownership is now explicit: fixed cameras must resolve `C_VCamComponent.fixed_anchor_path` first, then fall back to a vCam host entity-root `Node3D`; never read component transform.
- Path-follow helpers for `use_path` stay scene-local in the gameplay world; do not parent them under the persistent root manager.
- Stale test paths were corrected (`test_u_input_reducer.gd`, `test_input_system.gd`, `tests/integration/camera_system/test_camera_manager.gd`).
- ECS Event Bus integration added: `M_VCamManager` publishes lifecycle events (`EVENT_VCAM_ACTIVE_CHANGED`, `EVENT_VCAM_BLEND_STARTED`, `EVENT_VCAM_BLEND_COMPLETED`, `EVENT_VCAM_RECOVERY`) through `U_ECSEventBus` so `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe to vCam state changes.
- vCam event constants are now added to `scripts/events/ecs/u_ecs_event_names.gd` following existing `EVENT_*` pattern.
- Entity-based target resolution added: `C_VCamComponent` supports `follow_target_entity_id` and `follow_target_tag` exports as fallbacks when NodePath is empty. `S_VCamSystem` resolves targets via `M_ECSManager.get_entity_by_id()` / `get_entities_by_tag()`, leveraging the existing `BaseECSEntity` ID/tag system. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- QB rule context enrichment: `S_CameraStateSystem._build_camera_context()` is extended with `vcam_active_mode`, `vcam_is_blending`, `vcam_active_vcam_id` so camera rules can condition on vCam state using standard `RS_ConditionContextField`.
- Per-phase doc cadence is now explicit and mandatory: update continuation prompt + tasks after each phase, and update AGENTS/DEV_PITFALLS when new stable contracts or pitfalls appear.
- Camera slice migration is complete: `S_CameraStateSystem`, default QB camera-zone rule config, and QB camera tests now use `state.vcam.in_fov_zone`; legacy runtime/test reads of `state.camera.in_fov_zone` are retired.
- Touch look gating now uses the top-level gameplay `touch_look_active` Redux flag, and the field is registered as transient so it does not persist through save/load or shell handoff.
- Keyboard-look scope is now complete: patch `U_InputMapBootstrapper`, `tests/unit/input/test_input_map.gd`, `U_GlobalSettingsSerialization`, `U_RebindActionListBuilder`, locale action keys, and a new `UI_KeyboardMouseSettingsOverlay` instead of treating the settings surface as optional.
- Same-frame camera apply is now explicit: `S_VCamSystem` submits the authoritative current-frame result, and `M_VCamManager` consumes that handoff instead of relying on root `_physics_process` order against gameplay ECS.
- Naming paths now follow the repo style guide:
  - `scripts/resources/display/vcam/`
  - `scripts/utils/display/`
- Orbit mode baseline is now explicit:
  - `RS_VCamModeOrbit` is authored in `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd` with default preset `resources/display/vcam/cfg_default_orbit.tres`.
  - `RS_VCamModeOrbit.get_resolved_values()` now provides canonical orbit clamp/sanitation reads (`distance`, `fov`, authored angles) and axis-lock flags (`lock_x_rotation`, `lock_y_rotation`).
  - `U_VCamModeEvaluator.evaluate(...)` now consumes orbit resolved values, returns `{transform, fov, mode_name}` for orbit resources, and returns `{}` for null/invalid inputs without warning noise.
- OTS baseline (replaces first-person, March 15, 2026):
  - `RS_VCamModeOTS` is now authored in `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`; `get_resolved_values()` is the canonical OTS clamp/order read path for evaluator/runtime consumers.
  - `U_VCamModeEvaluator.evaluate(...)` now includes the OTS branch and returns `{transform, fov, mode_name: "ots"}` with shoulder-offset rotation and evaluator-owned pitch clamping.
  - OTS game-feel/aiming implementation status: collision avoidance (3C1), shoulder sway (3C2), landing camera response (3C3), and full 3C4 aiming scope (aim activation/input plumbing/movement+rotation integrations + reticle UI + default movement preset) are implementation-complete.
- Fixed baseline is now explicit:
  - `RS_VCamModeFixed` is authored in `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd` with default preset `resources/display/vcam/cfg_default_fixed.tres`.
  - `U_VCamModeEvaluator.evaluate(...)` now supports fixed world-anchor, follow-offset, and path branches while ignoring runtime yaw/pitch for fixed mode.
- Phase 5 component/interface/manager core is now explicit:
  - `C_VCamComponent` is authored in `scripts/ecs/components/c_vcam_component.gd` with mode/target/anchor/path/response exports and runtime yaw/pitch fields.
  - `I_VCamManager` (`scripts/interfaces/i_vcam_manager.gd`) defines the 8-method core manager API used by upcoming `S_VCamSystem`.
  - `M_VCamManager` (`scripts/managers/m_vcam_manager.gd`) now owns registration and active-vcam selection core.
- Active-selection runtime contract is now explicit:
  - Selection order is `set_active_vcam` explicit override first, then highest `priority`, then ascending `vcam_id` tie-break.
  - Components with `is_active = false` are excluded from selection and trigger reselection when active ownership changes.
  - Active changes publish both Redux observability (`vcam/set_active_runtime`) and ECS lifecycle events (`EVENT_VCAM_ACTIVE_CHANGED`), including clear transitions to empty active IDs when the active vCam is removed.

## Required Reading

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/vcam_manager/vcam-manager-plan.md`
- `docs/vcam_manager/vcam-manager-overview.md`
- `docs/vcam_manager/vcam-manager-prd.md`
- `docs/vcam_manager/vcam-manager-tasks.md`
- `docs/vcam_manager/vcam-refactor-tasks.md`
- `scripts/managers/m_vcam_manager.gd`
- `scripts/managers/m_camera_manager.gd`
- `scripts/interfaces/i_camera_manager.gd`
- `tests/mocks/mock_camera_manager.gd`
- `scripts/ecs/systems/s_input_system.gd`
- `scripts/ecs/systems/s_touchscreen_system.gd`
- `scripts/ecs/systems/s_vcam_system.gd`
- `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd`
- `scripts/ecs/systems/s_movement_system.gd`
- `scripts/ecs/systems/s_rotate_to_input_system.gd`
- `scripts/ecs/systems/s_room_fade_system.gd`
- `scripts/input/u_input_map_bootstrapper.gd`
- `scripts/ecs/systems/s_camera_state_system.gd` (QB rule context, FOV composition, shake trauma)
- `scripts/ecs/components/c_camera_state_component.gd` (base_fov, target_fov, shake_trauma API)
- `scripts/events/ecs/u_ecs_event_bus.gd` (event subscription/publish pattern)
- `scripts/events/ecs/u_ecs_event_names.gd` (event constant pattern — vCam events added here)
- `scripts/utils/qb/u_rule_scorer.gd` (QB rule scoring for camera rules)
- `scripts/state/utils/u_state_slice_manager.gd`
- `scripts/utils/u_global_settings_serialization.gd`
- `scripts/utils/display/u_cinema_grade_preview.gd`
- `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`
- `scripts/ui/helpers/u_rebind_action_list_builder.gd`
- `scripts/managers/m_vfx_manager.gd`
- `scripts/ui/hud/ui_mobile_controls.gd`
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`
- `scripts/ui/overlays/ui_input_rebinding_overlay.gd`
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`
- `scripts/resources/input/rs_touchscreen_settings.gd`
- `scripts/utils/lighting/u_room_fade_material_applier.gd`
- `resources/localization/cfg_locale_en_ui.tres`
- `resources/localization/cfg_locale_es_ui.tres`
- `resources/localization/cfg_locale_ja_ui.tres`
- `resources/localization/cfg_locale_pt_ui.tres`
- `resources/localization/cfg_locale_zh_CN_ui.tres`
- `tests/unit/input_manager/test_u_input_reducer.gd`
- `tests/unit/input/test_input_map.gd`
- `tests/unit/ecs/systems/test_input_system.gd`
- `tests/unit/ecs/systems/test_vcam_system.gd`
- `tests/unit/ecs/systems/test_movement_system.gd`
- `tests/unit/ecs/systems/test_rotate_to_input_system.gd`
- `tests/unit/ecs/systems/test_s_touchscreen_system.gd`
- `tests/unit/ui/test_mobile_controls.gd`
- `tests/unit/ecs/systems/test_room_fade_system.gd`
- `tests/unit/ecs/systems/test_room_fade_integration.gd`
- `tests/unit/lighting/test_room_fade_material_applier.gd`
- `tests/unit/qb/test_camera_state_system.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
- `tests/unit/ui/test_input_rebinding_overlay.gd`
- `tests/integration/camera_system/test_camera_manager.gd`
- `tests/integration/vcam/test_vcam_state.gd`
- `tests/integration/vcam/test_vcam_runtime.gd`
- `tests/integration/vcam/test_vcam_blend.gd`
- `tests/integration/vcam/test_vcam_mobile.gd`
- `tests/integration/vcam/test_vcam_occlusion.gd`
- `scenes/root.tscn`
- `scenes/templates/tmpl_base_scene.tscn`
- `scenes/templates/tmpl_camera.tscn`
- `scenes/gameplay/gameplay_base.tscn`

## Next Steps

1. Finish Phase `2G.3` by extracting additional `S_VCamSystem` coordinator/orphaned logic until the file-size/decomposition target is met.
2. Once `2G` is complete, execute Phase `2H` (implementation commit + docs closure for Phase 2).
3. Keep mandatory per-phase doc cadence and separate docs commits through Phases `2`-`5`.

## Key Decisions To Preserve

- vCam does not replace `M_CameraManager`.
- vCam does not replace `S_CameraStateSystem`.
- vCam does not bypass the gameplay input pipeline.
- Refactor Phase 1I contract: first-person mode and the `aim_pressed` pipeline are removed; orbit is the sole supported vCam mode.
- Keyboard look uses dedicated `look_*` actions (not `ui_*`) so bindings stay correct across input profiles; settings live in `mouse_settings`.
- Keyboard-look work is not complete unless the InputMap bootstrapper, input-map tests, rebind category/action labels, localization keys, and settings-save triggers are patched together.
- vCam does not treat mobile as special at the camera layer; touch look must still feed the shared `gameplay.look_input` path.
- vCam does not persist runtime slice state.
- vCam does not write `camera.fov` directly.
- vCam does not write `camera.global_transform` directly.
- vCam blends are live blends between two evaluated cameras, not frozen-transform lerps.
- Blend observability ordering is contractually fixed: dispatch `vcam/set_active_runtime` before `vcam/start_blend` so `blend_to_vcam_id` matches the incoming active camera.
- Active-target observability must be updated from `S_VCamSystem` evaluation failures (`target_freed`, `path_anchor_invalid`, `anchor_invalid`, `evaluation_failed`) and restored on successful evaluation.
- `S_VCamSystem` response smoothing is per-vCam state keyed by `vcam_id` and must recreate/reset on response/mode/target transitions; null `response` must remain a raw-evaluator passthrough path.
- Orbit/OTS look smoothing uses a separate per-vCam spring-damper state keyed by `vcam_id`; `runtime_yaw`/`runtime_pitch` stay raw input targets while evaluator rotation consumes smoothed values.
- Soft-zone hysteresis state is per-vCam state keyed by `vcam_id` and should persist independently of response-smoothing resets (`_soft_zone_dead_zone_state` must not be cleared just because `response == null`).
- Orbit ground-relative anchoring is per-vCam state keyed by `vcam_id` (`_ground_relative_state`) and must only sample/update ground reference while grounded; airborne ticks must not overwrite anchor state.
- Fixed mode ignores player runtime look angles (`runtime_yaw`/`runtime_pitch`); path mode uses anchor/path tangent orientation and ignores `track_target`.
- fixed-mode world anchoring resolves from `fixed_anchor_path` first, then host entity-root `Node3D` fallback; not from component transform assumptions.
- vCam publishes lifecycle events through `U_ECSEventBus`, not just Redux — enabling reactive integration with QB rules and other systems.
- QB camera rules can condition on vCam state via enriched context fields (`vcam_active_mode`, `vcam_is_blending`) — no vCam-specific rule types needed.
- Follow target resolution uses existing entity ID/tag system as fallback when NodePaths are empty. Multiple tag matches resolve to the first valid ECS-registration-order match and emit a debug warning.
- The informal `camera` slice is retired for FOV-zone observability. `in_fov_zone` now lives in `state.vcam.in_fov_zone`; do not reintroduce `state.camera.in_fov_zone` reads.
- Touch input ownership is `S_TouchscreenSystem` when `active_device == TOUCHSCREEN`, with `gameplay.touch_look_active` used as transient observability/gating state for drag-look lifecycle.
- Projection math and occlusion raycasts use the active gameplay camera viewport/world inside `GameViewport`.
- Silhouette rendering lifecycle is owned by `M_VFXManager` (detection in vCam, rendering in VFX) via `{entity_id, occluders, enabled}` request payload. This follows the `U_ScreenShake` helper pattern.

## Known Risks

- shake layering can regress if the camera-manager integration is implemented with direct global-transform writes
- soft-zone math can drift if depth-aware reprojection is skipped
- silhouettes can leak on scene swap if the persistent manager keeps stale occluder references
- root/gameplay scene wiring can be missed if only templates are edited
- orbit/OTS can appear “done” on desktop while still being broken on mobile if `S_TouchscreenSystem` continues to dispatch zero look input
- touch-look can conflict with joystick/buttons if `UI_MobileControls` does not claim a dedicated free-screen look touch
- touch gameplay input can be silently overwritten if `S_InputSystem` continues processing `TouchscreenSource` zero payloads
- silhouette persistence can ship without user control if `UI_VFXSettingsOverlay` is not updated alongside state/actions/reducer/selectors
- keyboard look can appear implemented but still fail in runtime/profile/rebind flows if `U_InputMapBootstrapper`, `test_input_map.gd`, `U_RebindActionListBuilder`, locale keys, or save-trigger actions are left behind
- gameplay camera math can pass isolated helper tests but still fail in live scenes if projection/raycast work accidentally uses the persistent root manager's viewport/world instead of the gameplay `SubViewport`
- same-frame camera application can hitch or lag a frame if implementation relies on root `_physics_process` tree order instead of the explicit `S_VCamSystem` -> `M_VCamManager` handoff
- **orientation continuity**: mode switches can cause disorienting heading jumps if rotation carry/reseed policy regresses in `S_VCamSystem` (see overview Rotation Continuity Contract)
- **reentrant blend**: a second `set_active_vcam()` during an active blend can pop or wedge blend state if mid-blend interruption semantics are not implemented
- **invalid target recovery**: freed follow targets or fixed anchors during gameplay can produce NaN transforms or crashes if per-tick validity checks are missing
- **tag ambiguity**: `follow_target_tag` can silently retarget the camera after scene-authoring changes unless multiple-match behavior is defined and warned
- **path recovery**: `use_path` cameras can drift or jump if path progress keeps advancing after the follow target becomes invalid
- **silhouette flicker**: occluders on marginal ray boundaries can cause per-frame material churn without debounce/hysteresis logic in `U_VCamSilhouetteHelper`
- **performance**: per-frame dictionary allocations in blend evaluation, soft-zone, and occlusion can cause frame-pacing regressions on mobile without reuse patterns
- silhouette color/opacity configurability is deferred to post-v1 (ship with single authored shader values)
- orbit zoom behavior is deferred to post-v1 (static authored distance for v1)

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Tasks](vcam-manager-tasks.md)
