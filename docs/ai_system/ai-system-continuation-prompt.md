# AI System Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the AI System (GOAP / HTN) by following the tasks outlined in the documentation in sequential order.

**Branch**: `GOAP-AI`
**Status**: Milestone 11 complete; Milestones 12-16 planned (jitter fix, character unification, AI showcase, player-NPC interactions, debug overlay)

---

## Current Status: Milestone 11 Complete, 12-16 Planned

- Overview: `docs/ai_system/ai-system-overview.md` — system architecture, goals, non-goals, resource definitions, demo integration.
- Plan: `docs/ai_system/ai-system-plan.md` — 10 milestones, work breakdown, dependency graph, risks.
- Tasks: `docs/ai_system/ai-system-tasks.md` — checklist (11/11 milestones complete, 5 new milestones planned).

### Next Up: M12 — Fix NPC Jitter + Navigation Robustness

**Primary jitter cause (verified):** All 3 NPC entities have CSG visuals with `use_collision = true` and `collision_layer = 33` as children of their CharacterBody3D (`collision_mask = 33`). The CSG creates an internal StaticBody3D that the body collides with during `move_and_slide()` every frame. The player template has zero `use_collision` on visuals.

**Fix priority:**
1. Remove `use_collision = true` from NPC visual CSG nodes (immediate jitter fix)
2. Align nav epsilon with action arrival threshold (robustness)
3. Simplify AI nav to world-space (cleanup)

### Planned: M13-16

- M13: Create `prefab_npc.tscn` extending `tmpl_character.tscn` + replace inline NPCs
- M14: Combined AI showcase scene (all archetypes, 3-5 NPCs, 3 zones)
- M15: Player-NPC interaction triggers (proximity detection, cascading events)
- M16: AI debug overlay system (floating labels, color-coded states)

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
- **Navigation bridge is now live**: `S_AINavigationSystem` (`execution_priority = -5`) reads `task_state["ai_move_target"]`, converts XZ world direction into camera-relative `C_InputComponent.move_vector`, and keeps NPCs on the same movement path as players.
- **Player input filtering is now enforced**: `S_InputSystem` writes gameplay input only to entities with `C_PlayerTagComponent`, preventing player-input clobbering of AI move vectors.
- **M8 pipeline integration coverage is now live**: `tests/unit/ai/integration/test_ai_pipeline_integration.gd` validates GOAP scoring → HTN decomposition → typed action execution → AI navigation bridge → player-input filtering end-to-end.
- **M9 demo scenes are now authored**: Power Core, Comms Array, and Nav Nexus gameplay scenes exist with required prototype geometry, markers/triggers, and NPC placeholder entities bound to valid `RS_AIBrainSettings` resources.
- **M9 mobile-safe scene registration is complete**: Power Core/Comms Array/Nav Nexus are now first-class `scene_registry` entries and are included in the loader preload manifest/backfill safety net for mobile/web exports.
- **M10 demo behavior integration is complete**: Patrol Drone, Sentry, and Guide Prism now use durable gameplay AI flags for investigate/celebrate gating, and trigger zones are runtime-wired (including Nav fall hazard + victory flagging) so authored behaviors execute reliably in-scene.
- **Default new-game routing now targets the AI demo location**: New Game + splash preload + retry routing resolve to `power_core`.

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
- `scripts/ecs/systems/s_movement_system.gd` — Camera-relative movement pipeline. M7 AI navigation should inverse this transform and write to `C_InputComponent.move_vector` so NPCs flow through the same path.
- `scripts/utils/ecs/u_ecs_utils.gd` — Active camera lookup helpers used by movement-oriented ECS systems.

Study these for utility and event patterns:

- `scripts/utils/qb/u_rule_scorer.gd` — Rule scoring API.
- `scripts/utils/qb/u_rule_selector.gd` — Winner selection API.
- `scripts/utils/qb/u_rule_state_tracker.gd` — Cooldowns, salience, one-shot gating.
- `scripts/utils/qb/u_path_resolver.gd` — Dot-path traversal for condition evaluation.
- `scripts/events/ecs/u_ecs_event_bus.gd` — Event publishing for RS_AIActionPublishEvent.

### 4. Execute AI System Tasks in Order

Work through the tasks in `ai-system-tasks.md` sequentially:

1. **M1** — Task Resource Skeleton + I_AIAction Interface (RS_AITask, RS_AIPrimitiveTask, RS_AICompoundTask, I_AIAction)
2. **M2** — Goal & Brain Settings Resources (RS_AIGoal, RS_AIBrainSettings)
3. **M3** — C_AIBrainComponent (ECS component)
4. **M4** — U_HTNPlanner (task decomposition utility)
5. **M5** — Goal Evaluation Loop (S_AIBehaviorSystem + QB v2)
6. **M6** — Typed Action Resources (Instant): RS_AIActionWait, RS_AIActionPublishEvent, RS_AIActionSetField + polymorphic task runner
7. **M7** — Typed Action Resources (Movement + Stub): RS_AIActionMoveTo, RS_AIActionScan, RS_AIActionAnimate
8. **M8** — Integration Tests (full pipeline validation)
9. **M9** — Demo Scene Creation (3 gameplay rooms)
10. **M10** — Demo NPC Behavior Authoring & Tuning

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
- **RS_AIPrimitiveTask is a Wrapper**: RS_AIPrimitiveTask holds `@export var action: Resource` (I_AIAction). The task is the "what" (position in the HTN plan), the action is the "how" (self-executing logic + typed @export config).
- **Animate Stub Scope (implemented)**: `RS_AIActionAnimate` sets `task_state["animation_state"]` to a StringName and completes immediately. Full animation system integration is a separate effort.
- **M7 Movement Bridge (implemented)**: `RS_AIActionMoveTo` writes `task_state["ai_move_target"]` (Vector3), `S_AINavigationSystem` (`execution_priority = -5`) reads that target and writes camera-relative `Vector2` into `C_InputComponent.set_move_vector()`, and `S_InputSystem` is filtered by `C_PlayerTagComponent` so player input does not clobber AI move vectors.
- **Shared runtime wiring is now default**: both `scenes/templates/tmpl_base_scene.tscn` and `scenes/gameplay/gameplay_base.tscn` include `S_AIBehaviorSystem(-10)` and `S_AINavigationSystem(-5)` before `S_InputSystem(0)`.
- **Demo Scenes are CSG Prototypes**: Use CSG geometry for all level geometry. Functional prototypes, not polished levels.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (S_, C_, RS_, U_, I_, E_, etc.).
- **Update Docs After Each Milestone**: Per AGENTS.md mandate, update this continuation prompt and the tasks checklist after completing each milestone.

---

## Next Steps

1. Optional follow-up: run in-editor playtest passes to tune authored waypoint spacing, scan durations, and cooldown values for feel (functional baseline is now automated-test verified).
2. Keep this branch focused on post-M10 polish only; use separate commits for implementation vs documentation deltas.
3. Merge `GOAP-AI` once review is complete.
