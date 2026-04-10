# AI System Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the AI System (GOAP / HTN) by following the tasks outlined in the documentation in sequential order.

**Branch**: `GOAP-AI`
**Status**: Milestone 15 + Refactor R1-R2 complete — AI system refactor in progress (R3–R10 remaining)
**Next Task**: Begin R3 in `docs/ai_system/ai-system-refactor-tasks.md` (Split `s_ai_behavior_system.gd` Into Collaborators)

---

## Current Status: Milestone 15 + Refactor R1-R2 Complete

- Overview: `docs/ai_system/ai-system-overview.md` — system architecture, goals, non-goals, resource definitions, demo integration.
- Plan: `docs/ai_system/ai-system-plan.md` — 10 milestones, work breakdown, dependency graph, risks.
- Tasks: `docs/ai_system/ai-system-tasks.md` — checklist (15 complete milestones).
- **Refactor Tasks (ACTIVE)**: `docs/ai_system/ai-system-refactor-tasks.md` — 10-milestone TDD refactor plan (R1–R10) to type-safe, split, and DRY the AI pipeline after M15. **R1-R2 are complete; start at R3.**

### Completed in M1 (2026-04-02)

- Added `tests/unit/ai/resources/test_rs_ai_task.gd` with red-green resource/interface tests (now 6 total including post-M2 audit hardening for `method_conditions`).
- Implemented:
  - `scripts/interfaces/i_ai_action.gd`
  - `scripts/resources/ai/rs_ai_task.gd`
  - `scripts/resources/ai/rs_ai_primitive_task.gd`
  - `scripts/resources/ai/rs_ai_compound_task.gd`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_task.gd` → `6/6` passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing
  - `tools/run_gut_suite.sh` run currently completes with `3627/3636` passing, `9` pending/risky (headless/platform skips), and `0` failing tests

### Completed in M2 (2026-04-02)

- Added `tests/unit/ai/resources/test_rs_ai_goal.gd` with the 5 required red-green tests (now 6 total after audit hardening for goal gate fields).
- Implemented:
  - `scripts/resources/ai/rs_ai_goal.gd`
  - `scripts/resources/ai/rs_ai_brain_settings.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` failed with expected missing-script assertions.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` → `5/5` passing (current `6/6` after audit hardening).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3666/3675` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M3 (2026-04-02)

- Added `tests/unit/ecs/components/test_c_ai_brain_component.gd` with the 5 required red-green component tests.
- Implemented:
  - `scripts/ecs/components/c_ai_brain_component.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` failed with expected missing-script assertions.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` → `5/5` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3633/3642` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M4 (2026-04-02)

- Added `tests/unit/ai/test_u_htn_planner.gd` with the 8 required red-green decomposition tests.
- Implemented:
  - `scripts/utils/ai/u_htn_planner.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_u_htn_planner.gd` failed with expected missing-script assertions for `u_htn_planner.gd`.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_u_htn_planner.gd` → `8/8` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3641/3650` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M5 (2026-04-02)

- Added `tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` with the 7 required red-green goal-loop tests (now 10 total after hardening coverage for cooldown/one-shot/rising-edge gates).
- Implemented:
  - `scripts/ecs/systems/s_ai_behavior_system.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` failed with expected missing-script assertions for `s_ai_behavior_system.gd`.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `7/7` passing (current `10/10` after hardening).
  - Hardening confirmed: goal cooldown/one-shot state is now marked only for selected winners (not all gated candidates).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3666/3675` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.
  - Pending/risky tests (pre-existing, unrelated to M5 implementation): `tests/integration/display/test_color_blind_ui_filter.gd::test_ui_color_blind_layer_has_higher_layer_than_ui_overlay`; `tests/unit/save/test_screenshot_capture.gd::test_capture_viewport_returns_image_with_expected_dimensions`; `tests/unit/scene_manager/test_loading_screen_transition.gd::test_loading_fake_progress_enforces_min_duration`; `tests/unit/scene_manager/test_transitions.gd::{test_transition_cleans_up_tween,test_fade_transition_uses_tween,test_input_blocking_enabled,test_fade_transition_easing}`; `tests/unit/ui/test_display_settings_mobile_visibility.gd::{test_desktop_controls_hidden_on_mobile,test_mobile_controls_still_visible_on_mobile}`.

### Completed in M6 (2026-04-02)

- Added `tests/unit/ai/actions/test_ai_actions_instant.gd` with the 5 required red-green instant-action tests.
- Added `tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` with the 4 required red-green task-runner tests (now 6 total after hardening coverage for invalid task/action skip behavior).
- Added test helper:
  - `tests/mocks/mock_ai_action_track.gd`
- Implemented:
  - `scripts/resources/ai/actions/rs_ai_action_wait.gd`
  - `scripts/resources/ai/actions/rs_ai_action_publish_event.gd`
  - `scripts/resources/ai/actions/rs_ai_action_set_field.gd`
  - `scripts/ecs/systems/s_ai_behavior_system.gd` (`_execute_current_task(...)` + per-tick task execution integration)
- Verification:
  - RED confirmed (actions): `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_instant.gd` failed with expected missing-script assertions.
  - GREEN confirmed (actions): `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_instant.gd` → `5/5` passing.
  - RED confirmed (runner): `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` failed before runner implementation on missing task execution assertions.
  - GREEN confirmed (runner): `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` → `4/4` passing (current `6/6` after hardening).
  - Regression guard: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `10/10` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3666/3675` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M7 (2026-04-02)

- Added `tests/unit/ai/actions/test_ai_actions_movement.gd` with the 7 required red-green movement/stub action tests (now 10 total after target-node-path hardening coverage).
- Added `tests/unit/ecs/systems/test_s_ai_navigation_system.gd` with the 9 required red-green AI navigation bridge tests.
- Added `tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` with the 2 required red-green input filter tests.
- Updated regression fixtures to align with new player-tag input contract:
  - `tests/unit/ecs/systems/test_input_system.gd`
  - `tests/unit/integration/test_device_detection_flow.gd`
  - `tests/unit/integration/test_input_manager_integration_points.gd`
- Implemented:
  - `scripts/resources/ai/actions/rs_ai_action_move_to.gd`
  - `scripts/resources/ai/actions/rs_ai_action_scan.gd`
  - `scripts/resources/ai/actions/rs_ai_action_animate.gd` (stub)
  - `scripts/ecs/systems/s_ai_navigation_system.gd`
  - `scripts/ecs/systems/s_input_system.gd` (player-tag query filter)
  - `scripts/ecs/systems/s_ai_behavior_system.gd` (`execution_priority = -10` ordering contract)
  - `scripts/utils/qb/u_rule_state_tracker.gd` (context-scoped one-shot tracking)
  - `scenes/templates/tmpl_base_scene.tscn` and `scenes/gameplay/gameplay_base.tscn` (shared AI runtime wiring)
- Verification:
  - RED confirmed (actions): `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_movement.gd` failed before scripts existed.
  - GREEN confirmed (actions): `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_movement.gd` → `10/10` passing.
  - RED confirmed (navigation/input): navigation/filter suites failed before implementation.
  - GREEN confirmed (navigation/input): `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_navigation_system.gd` → `9/9` passing; `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` → `2/2` passing.
  - Hardening confirmed: same-goal replay now replans after queue completion; one-shot gating is now isolated per NPC context (`rule_id + context_key`).
  - Shared-scene wiring confirmed: `S_AIBehaviorSystem(-10)` and `S_AINavigationSystem(-5)` are now present by default in both shared base scenes, ahead of `S_InputSystem(0)`.
  - Regression guard: updated input-system integration suites pass (`13/13`, `4/4`, `7/7` respectively).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
- Full suite: `tools/run_gut_suite.sh` completes with `3695/3704` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M8 (2026-04-02)

- Added `tests/unit/ai/integration/test_ai_pipeline_integration.gd` with the required red-green integration tests (now 6 total):
  - `test_full_pipeline_patrol_pattern`
  - `test_pipeline_moves_entity_via_real_movement_system`
  - `test_goal_switch_replans_mid_queue`
  - `test_cooldown_prevents_goal_thrashing`
  - `test_default_goal_fallback_executes`
  - `test_compound_method_selection_in_context`
- Implementation/debugging fixes discovered by RED run:
  - Switched test-local `C_AIBrainComponent` annotations to headless-safe `Variant` usage to avoid class-resolution parse failures.
  - Mounted integration fixtures under an in-tree root (`add_child_autofree`) so camera/body `global_transform` reads are valid in headless tests.
- Verification:
  - RED confirmed: initial M8 test run failed on expected parse/runtime issues above.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` → `6/6` passing.
  - Regression guards:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `12/12`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` → `6/6`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_movement.gd` → `10/10`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_navigation_system.gd` → `9/9`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` → `2/2`
  - Style: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - Full suite: `tools/run_gut_suite.sh` completes with `3695/3704` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M9 (2026-04-02)

- Added gameplay prototype scenes:
  - `scenes/gameplay/gameplay_power_core.tscn`
  - `scenes/gameplay/gameplay_comms_array.tscn`
  - `scenes/gameplay/gameplay_nav_nexus.tscn`
- Added shared placeholder AI brain resource:
  - `resources/ai/cfg_ai_brain_placeholder.tres`
- Scene authoring delivered for milestone scope:
  - Power Core includes CSG power-core geometry, four waypoint markers, activatable Area3D, and `E_PatrolDrone` with `C_AIBrainComponent`.
  - Comms Array includes CSG antenna/pillar geometry, guard waypoints, two noise-source Area3Ds, and `E_Sentry` with `C_AIBrainComponent`.
  - Nav Nexus includes vertical CSG platforms, path markers, fall-detection Area3D, victory-zone Area3D, and `E_GuidePrism` with `C_AIBrainComponent`.
- Post-audit integration pass completed:
  - Added runtime trigger wiring for all demo trigger zones:
    - `scripts/gameplay/inter_ai_demo_flag_zone.gd` on Power/Comms/Victory triggers for durable AI flags (`power_core_activated`, `comms_disturbance_heard`, `nav_goal_reached`)
    - `Inter_FallDetectionArea` now uses `Inter_HazardZone` + `resources/interactions/hazards/cfg_hazard_nav_nexus_fall.tres`
  - Added scene registry entries and mobile-safe preload/backfill coverage:
    - `resources/scene_registry/cfg_power_core_entry.tres`
    - `resources/scene_registry/cfg_comms_array_entry.tres`
    - `resources/scene_registry/cfg_nav_nexus_entry.tres`
    - `scripts/scene_management/helpers/u_scene_registry_loader.gd` preload manifest + backfill updated
  - Updated default New Game location to `power_core`:
    - `scripts/ui/menus/ui_main_menu.gd` (`DEFAULT_GAMEPLAY_SCENE`)
    - `scripts/ui/menus/ui_splash_screen.gd` (`DEFAULT_GAMEPLAY_SCENE_ID`)
    - `resources/cfg_game_config.tres` (`retry_scene_id = &"power_core"`)
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd` → `24/24` passing (includes mobile preloaded-manifest assertions).
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd` → `14/14` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_splash_screen.gd` → `13/13` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` full regression → `3704/3713` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M10 (2026-04-02)

- Added demo NPC behavior resource stacks:
  - `resources/ai/patrol_drone/cfg_patrol_drone_brain.tres`
  - `resources/ai/patrol_drone/cfg_goal_patrol.tres`
  - `resources/ai/patrol_drone/cfg_goal_investigate.tres`
  - `resources/ai/sentry/cfg_sentry_brain.tres`
  - `resources/ai/sentry/cfg_goal_guard.tres`
  - `resources/ai/sentry/cfg_goal_investigate_disturbance.tres`
  - `resources/ai/guide_prism/cfg_guide_brain.tres`
  - `resources/ai/guide_prism/cfg_goal_show_path.tres`
  - `resources/ai/guide_prism/cfg_goal_encourage.tres`
  - `resources/ai/guide_prism/cfg_goal_celebrate.tres`
- Rewired scene NPC brains from placeholder to authored resources:
  - `scenes/gameplay/gameplay_power_core.tscn` (`E_PatrolDrone`)
  - `scenes/gameplay/gameplay_comms_array.tscn` (`E_Sentry`)
  - `scenes/gameplay/gameplay_nav_nexus.tscn` (`E_GuidePrism`)
- Added per-NPC runtime movement stack for `move_to` execution parity:
  - `CharacterBody3D` + `CollisionShape3D`
  - `C_InputComponent`
  - `C_MovementComponent` with `cfg_movement_default`
- Added M10 RED/GREEN verification coverage:
  - `tests/unit/ai/resources/test_ai_demo_behavior_resources.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` failed before resource authoring/scene rewiring.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` → `6/6` passing (expanded to cover durable flag condition paths + trigger-zone runtime wiring).
  - Gameplay-state guard coverage: `tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_gameplay_slice_reducers.gd` → `11/11` passing (includes `gameplay/set_ai_demo_flag` + reset clearing).
  - Style confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
- Full regression confirmed: `tools/run_gut_suite.sh` → `3704/3713` passing, `9` pending/risky, `0` failing.

### Completed in M11 (2026-04-03)

- Added AI spawn-point recovery hardening (no last-supported-position dependency):
  - `scripts/ecs/systems/s_ai_spawn_recovery_system.gd`
  - `scripts/resources/ai/rs_ai_brain_settings.gd` respawn exports
  - `scripts/interfaces/i_spawn_manager.gd` + `scripts/managers/m_spawn_manager.gd` generic entity spawn API
- Added/updated scene and resource authoring:
  - `resources/spawn_metadata/cfg_sp_ai_patrol_drone.tres`
  - `resources/ai/patrol_drone/cfg_patrol_drone_brain.tres` (respawn spawn id + delay/cooldown)
  - Recovery system wiring in base/gameplay scenes and `sp_ai_patrol_drone` in `gameplay_power_core`.
- Added verification coverage:
  - `tests/unit/ecs/systems/test_s_ai_spawn_recovery_system.gd`
  - `tests/integration/spawn_system/test_ai_spawn_recovery_power_core.gd`
  - Extended `tests/unit/spawn_system/test_spawn_validation.gd` for generic spawn failures/success.
- Verification:
  - `Godot --headless ... -gdir=res://tests/unit/ecs/systems -gselect=test_s_ai_spawn_recovery_system -gexit` → `3/3`
  - `Godot --headless ... -gdir=res://tests/unit/spawn_system -gselect=test_spawn_validation -gexit` → `19/19`
  - `Godot --headless ... -gdir=res://tests/integration/spawn_system -gselect=test_ai_spawn_recovery_power_core -gexit` → `1/1`
  - `Godot --headless ... -gdir=res://tests/unit/style -gselect=test_style_enforcement -gexit` → `17/17`
- Hardening note: recovery integration test now forces unsupported state deterministically (support-grace set to `0.0`, immediate post-recovery assertions) to avoid false negatives from support-grace windows and next-frame AI rewrites.

### Completed in M12 (2026-04-03)

- Removed NPC visual self-collision in all demo gameplay scenes by disabling CSG `use_collision` on:
  - `E_PatrolDrone/NPC_Body/Visual`
  - `E_Sentry/NPC_Body/Visual`
  - `E_GuidePrism/NPC_Body/Visual`
- Implemented per-task arrival-threshold handoff:
  - `RS_AIActionMoveTo` now writes `task_state["ai_arrival_threshold"]` in `start()`/`tick()`.
  - `S_AINavigationSystem` now reads `ai_arrival_threshold` (fallback `0.5`) instead of a hardcoded nav epsilon.
- Simplified AI movement path to world-space:
  - `S_AINavigationSystem` now writes direct world-space move vectors (`Vector2(direction.x, direction.z)`), independent of active camera basis.
  - `S_MovementSystem` now detects `C_AIBrainComponent` and consumes AI move vectors via `_get_desired_velocity()` (world-space), while keeping player camera-relative handling unchanged.
- Added/updated tests:
  - `tests/unit/ai/actions/test_ai_actions_movement.gd` (arrival-threshold task-state assertion)
  - `tests/unit/ecs/systems/test_s_ai_navigation_system.gd` (threshold + world-space assertions)
  - `tests/unit/ecs/systems/test_movement_system.gd` (AI world-space movement assertion)
  - `tests/unit/ai/integration/test_ai_pipeline_integration.gd` (world-space nav expectation updates)
  - `tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` (NPC visual collision guard)
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_movement.gd` → `11/11`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_navigation_system.gd` → `12/12`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_movement_system.gd` → `10/10`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` → `6/6`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` → `7/7`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
  - Initial post-implementation full regression: `tools/run_gut_suite.sh` → `3708/3734` passing, `17` failing, `9` pending/risky.
  - Post-stabilization full regression: `tools/run_gut_suite.sh` → `3725/3734` passing, `0` failing, `9` pending/risky (headless/mobile skips).
- Post-M12 stabilization hardening (2026-04-03):
  - Updated `scenes/templates/tmpl_base_scene.tscn` room-fade fixture blocks (`SO_Block`, `SO_Block2`, `SO_Block3`) to use `BaseECSEntity` roots with explicit `entity_id`/`room_fade_group` tags, removing `C_RoomFadeGroupComponent` registration errors in shared-scene ECS suites.
  - Updated `scripts/ecs/systems/s_ai_spawn_recovery_system.gd` to avoid emitting non-actionable missing-`spawn_manager` warnings in harness contexts (debug-log only when explicitly enabled), while keeping missing-spawn-point hard errors unchanged.
  - Hardened two timing-sensitive state-store microbenchmarks for headless:
    - `tests/unit/state/test_m_state_store.gd` (`test_signal_batching_overhead_less_than_0_05ms`) now uses a headless-aware threshold.
    - `tests/unit/state/test_state_store_copy_optimization.gd` (`test_a1_dispatch_with_multiple_subscribers_is_faster_than_per_subscriber_copy`) now runs against a dedicated history-disabled store and uses a headless-aware threshold.

### Completed in M13 (2026-04-03)

- Added RED/GREEN prefab structure coverage:
  - `tests/unit/ai/resources/test_prefab_npc.gd` (`5/5`) verifies base character stack inheritance, required AI/input components, and absence of player-only components.
- Implemented shared NPC prefab:
  - `scenes/prefabs/prefab_demo_npc.tscn` (inherits `tmpl_character.tscn`, adds `C_InputComponent` + `C_AIBrainComponent`, defaults tags to `npc/ai/character`).
- Replaced inline NPC entities with prefab instances:
  - `scenes/gameplay/gameplay_power_core.tscn` (`E_PatrolDrone`)
  - `scenes/gameplay/gameplay_comms_array.tscn` (`E_Sentry`)
  - `scenes/gameplay/gameplay_nav_nexus.tscn` (`E_GuidePrism`)
- Preserved archetype differences while unifying stack:
  - Scene-local overrides keep per-NPC `brain_settings`, transform, tags, and custom visual geometry.
  - Patrol drone keeps floating tuning override via `cfg_floating_patrol_drone_default`.
- Preserved collision guardrail from M12:
  - NPC visual CSG children now live under prefab `Player_Body/Visual` with `use_collision = false`.
- Expanded migration regression coverage:
  - `tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` now includes unified stack assertions (`8/8`).
  - `tests/integration/spawn_system/test_ai_spawn_recovery_power_core.gd` updated for prefab body path (`Player_Body`) and remains green (`1/1`).
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_prefab_npc.gd` → `5/5`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` → `8/8`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `12/12`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` → `6/6`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_navigation_system.gd` → `12/12`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` → `6/6`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_spawn_recovery_system.gd` → `3/3`
  - `tools/run_gut_suite.sh -gtest=res://tests/integration/spawn_system/test_ai_spawn_recovery_power_core.gd` → `1/1`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
  - Full regression: `tools/run_gut_suite.sh` → `3731/3740` passing, `9` pending/risky, `0` failing.

### Completed in M14 (2026-04-05)

- Added RED/GREEN showcase scene coverage:
  - `tests/unit/ai/resources/test_ai_showcase_scene.gd` (`11/11`) verifies scene loads, has 4 NPCs with correct brain resources, unified component stacks, all required waypoint/marker/trigger nodes, and scene registry registration.
- Authored combined showcase scene:
  - `scenes/gameplay/gameplay_ai_showcase.tscn` — 60×30 unit CSG room with 3 color-coded zones (blue=patrol, red=guard, green=guide), 6m gap passages at x=±10, 4 NPC instances (E_PatrolDroneA, E_PatrolDroneB, E_Sentry, E_GuidePrism) using `prefab_demo_npc.tscn` with per-NPC `C_AIBrainComponent` brain overrides.
- Registered showcase scene:
  - `resources/scene_registry/cfg_ai_showcase_entry.tres`
  - `scripts/scene_management/helpers/u_scene_registry_loader.gd` — preload const + backfill entry added.
- Updated default new-game routing to target `ai_showcase`:
  - `scripts/ui/menus/ui_main_menu.gd` (`DEFAULT_GAMEPLAY_SCENE`)
  - `scripts/ui/menus/ui_splash_screen.gd` (`DEFAULT_GAMEPLAY_SCENE_ID`)
  - `scripts/managers/m_scene_manager.gd` (background preload target)
  - `resources/cfg_game_config.tres` (`retry_scene_id = &"ai_showcase"`)
- Updated regression tests for new default:
  - `tests/unit/scene_manager/test_scene_registry.gd` — ai_showcase backfill + manifest assertions added.
  - `tests/unit/ui/test_main_menu.gd` — two `power_core` → `ai_showcase` target assertions updated.
  - `tests/integration/scene_manager/test_endgame_flows.gd` — `game_config` now wired in `before_each` so retry_scene_id comes from the actual .tres.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_showcase_scene.gd` → `11/11`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/scene_manager/test_scene_registry.gd` → `24/24`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd` → `14/14`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
  - Full regression: `tools/run_gut_suite.sh` → `3782/3792` passing, `9` pending/risky, `1` pre-existing vcam failure (`test_vcam_runtime.gd`), `0` new failures.

### Completed in M15 (2026-04-09)

- Added RED/GREEN interaction-trigger coverage:
  - `tests/unit/ecs/components/test_c_detection_component.gd` (`4/4`)
  - `tests/unit/ecs/systems/test_s_ai_detection_system.gd` (`5/5`)
  - `tests/unit/ecs/systems/test_s_ai_demo_alarm_relay_system.gd` (`3/3`)
  - `tests/unit/ai/resources/test_ai_showcase_scene.gd` expanded to `18/18` with M15 assertions
- Implemented new detection + relay runtime:
  - `scripts/ecs/components/c_detection_component.gd`
  - `scripts/ecs/systems/s_ai_detection_system.gd` (`execution_priority = -12`)
  - `scripts/ecs/systems/s_ai_demo_alarm_relay_system.gd` (`execution_priority = -11`)
  - `scripts/gameplay/inter_ai_demo_guard_barrier.gd`
- Updated showcase behavior/resources for trigger-driven interactions:
  - Added guide showcase resources:
    - `resources/ai/guide_prism/cfg_goal_idle_showcase.tres`
    - `resources/ai/guide_prism/cfg_goal_show_path_showcase.tres`
    - `resources/ai/guide_prism/cfg_guide_showcase_brain.tres`
  - Updated `resources/ai/sentry/cfg_goal_investigate_disturbance.tres` to publish `ai_alarm_triggered` for cross-NPC cascade behavior.
  - Updated `scenes/prefabs/prefab_demo_npc.tscn` to include `C_DetectionComponent`.
  - Updated `scenes/gameplay/gameplay_ai_showcase.tscn` with:
    - systems: `S_AIDetectionSystem`, `S_AIDemoAlarmRelaySystem`
    - interactions: `Inter_AlarmButton`, `Inter_DoorSwitch`, `Inter_GuideCollectible`
    - barrier listener node: `SO_GuardBarrier` (`Inter_AIDemoGuardBarrier`)
- Implementation contract correction:
  - Demo flags in M15 are dispatched via `U_GameplayActions.set_ai_demo_flag(...)` (not `U_NavigationActions`).
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_detection_component.gd` → `4/4`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_detection_system.gd` → `5/5`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_demo_alarm_relay_system.gd` → `3/3`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_showcase_scene.gd` → `18/18`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
  - Full regression snapshot: `tools/run_gut_suite.sh` → `3820/3859` passing, `30` failing, `9` pending/risky (failures concentrated in wall-visibility/vcam suites, outside M15 change set).

### Completed in R1 (2026-04-10)

- Added RED/GREEN typed-contract coverage:
  - `tests/unit/ai/resources/test_rs_ai_goal.gd` (expanded to `10/10`)
  - `tests/unit/ai/resources/test_rs_ai_task.gd` (expanded to `9/9`)
  - `tests/unit/ecs/components/test_c_ai_brain_component.gd` (expanded to `11/11`)
- Implemented typed AI data contracts:
  - `scripts/resources/ai/rs_ai_brain_settings.gd` (`goals: Array[RS_AIGoal]`)
  - `scripts/resources/ai/rs_ai_goal.gd` (`root_task: RS_AITask`, `conditions: Array[I_Condition]`)
  - `scripts/resources/ai/rs_ai_primitive_task.gd` (`action: I_AIAction`)
  - `scripts/resources/ai/rs_ai_compound_task.gd` (`subtasks: Array[RS_AITask]`, `method_conditions: Array[I_Condition]`)
  - `scripts/ecs/components/c_ai_brain_component.gd` (`brain_settings: RS_AIBrainSettings`, `current_task_queue: Array[RS_AIPrimitiveTask]`, typed accessors)
- Removed AI hot-path duck-typing usage from `scripts/ecs/systems/s_ai_behavior_system.gd` in favor of typed brain/settings/goal/task/action flow.
- Verification:
  - Targeted suites:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` → `10/10`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_task.gd` → `9/9`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` → `11/11`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `17/17`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` → `6/6`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` → `6/6`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
  - Full regression snapshot (2026-04-10): `tools/run_gut_suite.sh` → `3870/3880` passing, `1` failing, `9` pending/risky.
  - Remaining failure is pre-existing and outside R1 scope:
    - `tests/integration/vcam/test_vcam_runtime.gd::test_root_scene_registers_vcam_manager_in_service_locator`
    - Error: `M_SaveManager: Save file 'current_scene_id' is empty`

### Completed in R2 (2026-04-10)

- Added RED/GREEN action-base and shared-key coverage:
  - `tests/unit/ai/test_u_ai_task_state_keys.gd` (`4/4`)
  - `tests/unit/ai/test_i_ai_action_base.gd` (`2/2`)
  - `tests/unit/style/test_style_enforcement.gd` expanded to `18/18` (AI move-target magic-string guard)
- Implemented shared AI task-state keys:
  - `scripts/utils/ai/u_ai_task_state_keys.gd` (`class_name U_AITaskStateKeys`)
- Hardened `I_AIAction` base contract:
  - `scripts/interfaces/i_ai_action.gd` now asserts on base virtual invocation (`start`, `tick`, `is_complete`).
  - All action resources now extend `I_AIAction` via class name:
    - `rs_ai_action_move_to.gd`
    - `rs_ai_action_wait.gd`
    - `rs_ai_action_scan.gd`
    - `rs_ai_action_animate.gd`
    - `rs_ai_action_publish_event.gd`
    - `rs_ai_action_set_field.gd`
- Replaced duplicated task-state string literals with `U_AITaskStateKeys` in:
  - `scripts/resources/ai/actions/rs_ai_action_move_to.gd`
  - `scripts/ecs/systems/s_ai_behavior_system.gd`
  - `scripts/ecs/systems/s_ai_navigation_system.gd`
- Verification:
  - Targeted suites:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_u_ai_task_state_keys.gd` → `4/4`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_i_ai_action_base.gd` → `2/2`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `18/18`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_instant.gd` → `5/5`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/actions/test_ai_actions_movement.gd` → `11/11`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `17/17`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` → `6/6`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_navigation_system.gd` → `12/12`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` → `6/6`
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_goal_resume.gd` → `3/3`
  - Full regression snapshot (2026-04-10): `tools/run_gut_suite.sh` → `3877/3887` passing, `1` failing, `9` pending/risky.
  - Remaining failure is pre-existing and outside R2 scope:
    - `tests/integration/vcam/test_vcam_runtime.gd::test_root_scene_registers_vcam_manager_in_service_locator`
    - Error: `M_SaveManager: Save file 'current_scene_id' is empty`

### Key Design Decisions

- **GOAP + HTN**: QB v2 scores goals (GOAP layer), winning goal's root task is decomposed by HTN planner into primitive actions.
- **Typed action resources (I_AIAction)**: All 6 typed actions are now implemented (`RS_AIActionMoveTo`, `RS_AIActionWait`, `RS_AIActionScan`, `RS_AIActionAnimate`, `RS_AIActionPublishEvent`, `RS_AIActionSetField`) and executed polymorphically via `S_AIBehaviorSystem._execute_current_task(...)`.
- **Goal gate authoring is exposed on RS_AIGoal**: `score_threshold`, `cooldown`, `one_shot`, and `requires_rising_edge` are exported and consumed by `S_AIBehaviorSystem` through QB-style gating.
- **Same-goal replay is explicit**: when the selected goal remains unchanged but the current queue has completed, `S_AIBehaviorSystem` now replans for that same goal to avoid idle stalls.
- **One-shot gating is per NPC context**: `U_RuleStateTracker` now scopes one-shot spend by `rule_id + context_key` so two entities sharing a goal id do not suppress each other.
- **Designer-friendly @exports**: Action resources use typed `@export` fields (for example RS_AIActionMoveTo `target_position: Vector3`, `arrival_threshold: float`) instead of opaque `Dictionary parameters`.
- **No blackboard**: QB conditions already read component fields, Redux state, and event payloads via U_PathResolver.
- **No behavior trees**: QB scorer is the decision layer; HTN replaces BT-style decomposition.
- **Animate remains an intentional stub**: `RS_AIActionAnimate` sets `task_state["animation_state"]` and completes immediately; full animation integration is deferred.
- **Navigation bridge is now world-space (M12)**: `S_AINavigationSystem` (`execution_priority = -5`) reads `task_state["ai_move_target"]` + optional `task_state["ai_arrival_threshold"]`, emits world-space `C_InputComponent.move_vector`, and leaves player camera-relative transforms to player-only input paths.
- **Player input filtering is now enforced**: `S_InputSystem` writes gameplay input only to entities with `C_PlayerTagComponent`, preventing player-input clobbering of AI move vectors.
- **M8 pipeline integration coverage is now live**: `tests/unit/ai/integration/test_ai_pipeline_integration.gd` validates GOAP scoring → HTN decomposition → typed action execution → AI navigation bridge → player-input filtering end-to-end.
- **M9 demo scenes are now authored**: Power Core, Comms Array, and Nav Nexus gameplay scenes exist with required prototype geometry, markers/triggers, and NPC placeholder entities bound to valid `RS_AIBrainSettings` resources.
- **M9 mobile-safe scene registration is complete**: Power Core/Comms Array/Nav Nexus are now first-class `scene_registry` entries and are included in the loader preload manifest/backfill safety net for mobile/web exports.
- **M10 demo behavior integration is complete**: Patrol Drone, Sentry, and Guide Prism now use durable gameplay AI flags for investigate/celebrate gating, and trigger zones are runtime-wired (including Nav fall hazard + victory flagging) so authored behaviors execute reliably in-scene.
- **Default new-game routing now targets the AI showcase**: New Game + splash preload + retry routing resolve to `ai_showcase` (updated in M14 from `power_core`).
- **M13 character stack unification is complete**: authored NPCs now instance `prefab_demo_npc.tscn` (inherits `tmpl_character.tscn`), so they share the same baseline runtime component stack as player characters while excluding player-only components.
- **M14 combined showcase is complete**: `gameplay_ai_showcase.tscn` hosts all three archetypes simultaneously — two patrol drones (zone A), one sentry (zone B), one guide prism (zone C) — in a single 60×30 CSG room. NPC brain overrides use `parent_id_path=PackedInt32Array(<npc_uid>, 1373490017)` (Components node UID in `prefab_demo_npc.tscn`). Both patrol drones share `cfg_patrol_drone_brain.tres` and recover to `sp_ai_patrol_drone`.
- **M15 proximity/cascade trigger runtime is complete**: `C_DetectionComponent` + `S_AIDetectionSystem(-12)` provide player-range enter/exit state and optional enter-event publication; `S_AIDemoAlarmRelaySystem(-11)` fans `ai_alarm_triggered` into durable gameplay flags for cross-NPC reactions.
- **M15 AI demo flag dispatch uses gameplay actions, not navigation actions**: use `U_GameplayActions.set_ai_demo_flag(...)` for alarm/door/collectible/proximity flag updates.
- **R1 typed AI contracts are now enforced in runtime resources/components**: brain/goal/task/action references are strongly typed (`RS_AIBrainSettings`, `RS_AIGoal`, `RS_AITask`, `RS_AIPrimitiveTask`, `I_AIAction`, `I_Condition`) and AI hot-path logic no longer relies on `_read_*_property` duck-typing.
- **R2 shared task-state keys + action-base hardening are complete**: AI move-target/arrival/action-started/debug keys now resolve through `U_AITaskStateKeys`, and all concrete AI actions extend `I_AIAction` by class name with assert-based base virtual safeguards.

---

## Instructions — YOU MUST DO THIS - NON-NEGOTIABLE

### 1. Review Project Foundations

- `AGENTS.md` — Project conventions, ECS guidelines, QB v2 patterns.
- `docs/general/DEV_PITFALLS.md` — Common mistakes to avoid.
- `docs/general/STYLE_GUIDE.md` — Code style, naming prefixes, formatting requirements.

### 2. Review AI System Documentation

- `docs/ai_system/ai-system-overview.md` — Full system specification: architecture, resources, primitive task types, demo NPC archetypes.
- `docs/ai_system/ai-system-plan.md` — Implementation plan with 10 milestones and dependency graph.
- `docs/ai_system/ai-system-tasks.md` — Task list with commit-level checkboxes per milestone.

### 3. Understand Existing Architecture

Study these existing consumers of QB v2 — they define the pattern you must follow:

- `scripts/ecs/systems/s_character_state_system.gd` — QB v2 composition pattern (U_RuleScorer, U_RuleSelector, U_RuleStateTracker). Study `_build_entity_context()` for context dict construction.
- `scripts/ecs/systems/s_game_event_system.gd` — Event-driven QB evaluation pattern with per-entity context fan-out.
- `scripts/ecs/systems/s_camera_state_system.gd` — QB v2 with camera-specific context building.

Study these for ECS conventions:

- `scripts/ecs/base_ecs_system.gd` — Base system class, `process_tick(delta)` contract.
- `scripts/ecs/base_ecs_component.gd` — Base component class, `COMPONENT_TYPE`, `_validate_required_settings()`.
- `scripts/managers/m_ecs_manager.gd` — Component registration, queries, entity management.

Study these for the typed resource + interface pattern (I_AIAction follows this exactly):

- `scripts/interfaces/i_condition.gd` — Interface: `evaluate(context) -> float`. AI actions follow this pattern with `start/tick/is_complete`.
- `scripts/interfaces/i_effect.gd` — Interface: `execute(context) -> void`. Same polymorphic dispatch pattern.
- `scripts/resources/qb/conditions/rs_condition_component_field.gd` — Example typed condition with `@export_group` + `@export` fields for inspector UX.
- `scripts/resources/qb/effects/rs_effect_set_field.gd` — Example typed effect with multiple `@export` value types.

Study these for movement/input foundations used by the implemented M7 AI navigation bridge:

- `scripts/ecs/systems/s_input_system.gd` — Player input writer with `C_PlayerTagComponent` query filtering so player input writes only to player-tagged entities.
- `scripts/ecs/systems/s_movement_system.gd` — Player movement remains camera-relative; AI entities (`C_AIBrainComponent`) now consume world-space `C_InputComponent.move_vector` via `_get_desired_velocity()`.
- `scripts/utils/ecs/u_ecs_utils.gd` — Active camera lookup helpers used by movement-oriented ECS systems.

Study these for utility and event patterns:

- `scripts/utils/qb/u_rule_scorer.gd` — Rule scoring API.
- `scripts/utils/qb/u_rule_selector.gd` — Winner selection API.
- `scripts/utils/qb/u_rule_state_tracker.gd` — Cooldowns, salience, one-shot gating.
- `scripts/utils/qb/u_path_resolver.gd` — Dot-path traversal for condition evaluation.
- `scripts/events/ecs/u_ecs_event_bus.gd` — Event publishing for RS_AIActionPublishEvent.

### 4. Execute AI System Refactor Tasks in Order

M1–M15 are complete. **The AI system refactor is in progress.** Work through the milestones in `docs/ai_system/ai-system-refactor-tasks.md` sequentially, continuing from R3.

1. **R1** — Typed Brain Settings, Goals, and Tasks (eliminate `_read_*_property` duck-typing from the AI hot path) **COMPLETE (2026-04-10)**
2. **R2** — Promote `I_AIAction` to a Proper Action Base + Task State Keys Registry **COMPLETE (2026-04-10)**
3. **R3** — Split `s_ai_behavior_system.gd` Into Focused Collaborators (goal selector, task runner, replanner, context builder) **← START HERE**
4. **R4** — Extract Debug Probe + Log Throttle Utilities (delete duplicated `_build_render_probe` + `_tick_debug_log_cooldowns`)
5. **R5** — Share Spawn Recovery Between Player and NPCs (promote `s_ai_spawn_recovery_system.gd` to generic `s_spawn_recovery_system.gd`)
6. **R6** — Generalize the Move-Target Navigation Bridge (rename `s_ai_navigation_system.gd` → `s_move_target_follower_system.gd`, add `C_MoveTargetComponent`)
7. **R7** — Reorganize AI Resource Directories (`scripts/resources/ai/{brain,goals,tasks,actions}/`)
8. **R8** — Move Demo-Only Systems Out of Production Folder (`s_ai_demo_alarm_relay_system.gd` → `scripts/gameplay/`)
9. **R9** — HTN Planner Context Object (collapse recursive params into `HTNPlannerContext`)
10. **R10** — Behavior System Orchestration Integration (final pass: `s_ai_behavior_system.gd` under 200 lines)

The original M1–M10 feature milestones and M11–M15 hardening milestones are complete — see the "Completed" sections above for their history. Do **not** redo them.

### 5. Follow TDD Discipline

For each milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation or rename.
6. Commit with a clear, focused message.

### 6. Preserve Compatibility

You MUST:

- Keep all existing ECS systems, QB v2 consumers, and state management flows working.
- Follow existing composition patterns — compose QB v2 utilities, do not inherit from a QB base class.
- Use `U_ECSEventBus` for `publish_event` tasks, not direct signal connections.
- Use `U_PathResolver` for `set_field` tasks, matching existing condition/effect resolution.
- Register C_AIBrainComponent with M_ECSManager following the standard component lifecycle.

---

## Critical Notes

- **No Autoloads**: AI system follows existing ECS patterns. S_AIBehaviorSystem lives in gameplay scene system groups. C_AIBrainComponent attaches to NPC entities.
- **C_AIBrainComponent settings are required**: `brain_settings` must be a valid `RS_AIBrainSettings` resource. Placeholder/demo NPC scene entities cannot leave this field null.
- **Compose, Don't Inherit**: S_AIBehaviorSystem composes U_RuleScorer, U_RuleSelector, U_RuleStateTracker, and U_HTNPlanner. It does NOT inherit from a QB base class.
- **Typed Actions via I_AIAction (M7 complete)**: Each action resource (RS_AIAction*) implements I_AIAction with `start(context, task_state)`, `tick(context, task_state, delta)`, `is_complete(context, task_state)`. `S_AIBehaviorSystem._execute_current_task(...)` dispatches polymorphically (no match blocks/action-type switching).
- **RS_AIPrimitiveTask is a Wrapper**: RS_AIPrimitiveTask holds `@export var action: I_AIAction`. The task is the "what" (position in the HTN plan), the action is the "how" (self-executing logic + typed @export config).
- **Animate Stub Scope (implemented)**: `RS_AIActionAnimate` sets `task_state["animation_state"]` to a StringName and completes immediately. Full animation system integration is a separate effort.
- **M7/M12 Movement Bridge (implemented + hardened)**: `RS_AIActionMoveTo` writes task-state entries keyed by `U_AITaskStateKeys.MOVE_TARGET` + `U_AITaskStateKeys.ARRIVAL_THRESHOLD`; `S_AINavigationSystem` (`execution_priority = -5`) resolves world-space XZ direction into `C_InputComponent.set_move_vector()` and applies per-task arrival threshold; `S_MovementSystem` consumes world-space vectors for AI entities while preserving player camera-relative controls.
- **M15 interaction trigger contract (implemented)**: `C_DetectionComponent` + `S_AIDetectionSystem(-12)` own player-proximity enter/exit state, and `S_AIDemoAlarmRelaySystem(-11)` fans `ai_alarm_triggered` to durable gameplay flags. Demo-flag updates dispatch via `U_GameplayActions.set_ai_demo_flag(...)`.
- **Shared runtime wiring is now default**: both `scenes/templates/tmpl_base_scene.tscn` and `scenes/gameplay/gameplay_base.tscn` include `S_AIBehaviorSystem(-10)` and `S_AINavigationSystem(-5)` before `S_InputSystem(0)`.
- **Demo Scenes are CSG Prototypes**: Use CSG geometry for all level geometry. Functional prototypes, not polished levels.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (S_, C_, RS_, U_, I_, E_, etc.).
- **Update Docs After Each Milestone**: Per AGENTS.md mandate, update this continuation prompt and the tasks checklist after completing each milestone.

---

## Next Steps

1. **Begin R3** in `docs/ai_system/ai-system-refactor-tasks.md` — Split `s_ai_behavior_system.gd` into focused collaborators (`U_AIGoalSelector`, `U_AITaskRunner`, `U_AIReplanner`, `U_AIContextBuilder`) with util-level RED/GREEN coverage.
2. Proceed through R4–R10 in order; each milestone has its own RED/GREEN/refactor commit cadence. Update the completion-notes slot in `ai-system-refactor-tasks.md` inline after each milestone.
3. Optional follow-up (post-refactor): run in-editor playtest passes to tune waypoint spacing, scan durations, cooldown values, and detection radii for feel.
4. Optional stabilization: triage current non-AI wall-visibility/vcam regressions in full-suite runs before branch merge.
5. Merge `GOAP-AI` once R1–R10 and regression review pass.
