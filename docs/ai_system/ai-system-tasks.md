# AI System (GOAP / HTN) - Tasks Checklist

**Branch**: `GOAP-AI`
**Status**: Milestone 2 complete (2/10 milestones)
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred
**Reference**: `docs/ai_system/ai-system-plan.md`

---

## Milestone 1: Task Resource Skeleton + I_AIAction Interface

**Goal**: Create RS_AITask base class, RS_AIPrimitiveTask (holds typed action via I_AIAction), RS_AICompoundTask, and the I_AIAction interface.

- [x] **Commit 1** — Create `tests/unit/ai/resources/test_rs_ai_task.gd` with resource + interface tests (TDD RED):
  - `test_primitive_task_holds_action_resource` — RS_AIPrimitiveTask.action accepts an I_AIAction implementor
  - `test_compound_task_has_subtasks_array` — RS_AICompoundTask.subtasks holds ordered RS_AITask entries
  - `test_task_id_is_string_name` — RS_AITask.task_id typed as StringName
  - `test_i_ai_action_interface_contract` — verify I_AIAction declares start/tick/is_complete methods
  - `test_primitive_task_action_defaults_to_null` — action is optional (null until assigned)
- [x] **Commit 2** — Implement `i_ai_action.gd`, `rs_ai_task.gd`, `rs_ai_primitive_task.gd`, `rs_ai_compound_task.gd` (TDD GREEN):
  - `scripts/interfaces/i_ai_action.gd` — interface with `start(context, task_state)`, `tick(context, task_state, delta)`, `is_complete(context, task_state)` (matches I_Condition/I_Effect pattern)
  - `scripts/resources/ai/rs_ai_task.gd` — base Resource with `@export var task_id: StringName`
  - `scripts/resources/ai/rs_ai_primitive_task.gd` — extends RS_AITask with `@export var action: Resource` (I_AIAction)
  - `scripts/resources/ai/rs_ai_compound_task.gd` — extends RS_AITask with `subtasks: Array[Resource]`, `method_conditions: Array[Resource]`
- [x] **Commit 3** — Verify style enforcement passes; refactor if needed

**M1 Verification**:
- [x] All 5 resource/interface tests green
- [x] I_AIAction interface follows I_Condition/I_Effect pattern
- [x] RS_AIPrimitiveTask.action accepts typed action resources
- [x] RS_ prefix, I_ prefix, and snake_case file names
- [x] `test_style_enforcement.gd` passes

**M1 Completion Notes (2026-04-02)**:
- RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_task.gd` failed with expected missing-script assertions.
- GREEN confirmed: same test target passed `5/5` after implementing M1 scripts.
- Style confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed `17/17`.
- Full-suite baseline run executed: `tools/run_gut_suite.sh` finished `3613/3631` passing with `9` failing tests in existing save/state persistence integration suites (outside M1 scope).

---

## Milestone 2: Goal & Brain Settings Resources

**Goal**: Create RS_AIGoal and RS_AIBrainSettings. RS_AIGoal wraps QB conditions + root task. RS_AIBrainSettings holds goal arrays and evaluation config.

- [x] **Commit 1** — Create `tests/unit/ai/resources/test_rs_ai_goal.gd` with resource tests (TDD RED):
  - `test_goal_has_id_conditions_and_root_task`
  - `test_goal_priority_defaults_to_zero`
  - `test_brain_settings_holds_goals_array`
  - `test_brain_settings_default_goal_id`
  - `test_brain_settings_evaluation_interval_default`
- [x] **Commit 2** — Implement `rs_ai_goal.gd` and `rs_ai_brain_settings.gd` (TDD GREEN)

**M2 Verification**:
- [x] All 5 resource tests green
- [x] RS_AIGoal.conditions accepts existing QB condition types (RS_ConditionComponentField, etc.)
- [x] RS_AIBrainSettings can hold multiple RS_AIGoal instances
- [x] `test_style_enforcement.gd` passes

**M2 Completion Notes (2026-04-02)**:
- RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` failed with expected missing-script assertions for `rs_ai_goal.gd` and `rs_ai_brain_settings.gd`.
- GREEN confirmed: same test target passed `5/5` after implementing M2 scripts.
- Style confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` passed `17/17`.
- Full-suite baseline run executed: `tools/run_gut_suite.sh` finished `3618/3636` passing with `9` failing tests in existing save/state persistence integration suites (outside M2 scope).

---

## Milestone 3: C_AIBrainComponent

**Goal**: Create the ECS component that holds per-NPC AI runtime state. Follows BaseECSComponent conventions.

- [ ] **Commit 1** — Create `tests/unit/ecs/components/test_c_ai_brain_component.gd` with component tests (TDD RED):
  - `test_component_type_constant`
  - `test_brain_settings_export_is_assignable`
  - `test_runtime_state_defaults`
  - `test_registers_with_ecs_manager`
  - `test_validate_required_settings_fails_without_brain_settings`
- [ ] **Commit 2** — Implement `c_ai_brain_component.gd` (TDD GREEN):
  - `const COMPONENT_TYPE := StringName("C_AIBrainComponent")`
  - `@export var brain_settings: RS_AIBrainSettings`
  - Runtime vars: `active_goal_id`, `current_task_queue`, `current_task_index`, `task_state`, `evaluation_timer`
  - Override `_validate_required_settings()`

**M3 Verification**:
- [ ] All 5 component tests green
- [ ] Component registers with M_ECSManager and is queryable via `get_components(&"C_AIBrainComponent")`
- [ ] `_validate_required_settings()` rejects null brain_settings
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 4: U_HTNPlanner

**Goal**: Recursive task decomposition utility. Flattens compound tasks into primitive task queues. Pure logic, no ECS dependency.

- [ ] **Commit 1** — Create `tests/unit/ai/test_u_htn_planner.gd` with decomposition tests (TDD RED):
  - `test_decompose_single_primitive_returns_itself`
  - `test_decompose_compound_flattens_subtasks`
  - `test_decompose_nested_compounds`
  - `test_decompose_with_method_conditions_selects_first_passing`
  - `test_decompose_cycle_detection`
  - `test_decompose_empty_compound_returns_empty`
  - `test_decompose_null_task_returns_empty`
  - `test_max_depth_guard`
- [ ] **Commit 2** — Implement `u_htn_planner.gd` (TDD GREEN):
  - `static func decompose(task: Resource, context: Dictionary, max_depth: int = 20) -> Array[Resource]`
  - Recursive `_decompose_recursive` with visited set for cycle detection
  - Uses `U_RuleScorer.score_rules()` for method_conditions evaluation

**M4 Verification**:
- [ ] All 8 planner tests green
- [ ] Cycle detection prevents infinite recursion
- [ ] Method conditions correctly gate compound branch selection
- [ ] Integrates with existing U_RuleScorer
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 5: Goal Evaluation Loop

**Goal**: S_AIBehaviorSystem shell with per-tick goal evaluation. Composes QB v2 utilities for scoring/selection. No task execution yet.

- [ ] **Commit 1** — Create `tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` with goal evaluation tests (TDD RED):
  - `test_system_extends_base_ecs_system`
  - `test_selects_highest_scoring_goal`
  - `test_ties_broken_by_priority`
  - `test_default_goal_used_when_no_goal_passes`
  - `test_goal_change_clears_task_queue`
  - `test_evaluation_interval_throttles_scoring`
  - `test_no_brain_component_no_crash`
- [ ] **Commit 2** — Implement `s_ai_behavior_system.gd` goal evaluation loop (TDD GREEN):
  - Compose: U_RuleScorer, U_RuleSelector, U_RuleStateTracker
  - `process_tick(delta)`: query entities, score goals, select winner, detect change, decompose via U_HTNPlanner
  - Build context dict from entity components (follow S_CharacterStateSystem pattern)

**M5 Verification**:
- [ ] All 7 goal evaluation tests green
- [ ] System composes QB v2 utilities (not inheriting)
- [ ] Goal switching triggers re-planning (clears queue, decomposes new root task)
- [ ] Evaluation interval throttling prevents per-tick scoring overhead
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 6: Typed Action Resources (Instant) + Task Runner

**Goal**: Create RS_AIActionWait, RS_AIActionPublishEvent, RS_AIActionSetField implementing I_AIAction. Build polymorphic task runner in S_AIBehaviorSystem (no match blocks).

- [ ] **Commit 1** — Create `tests/unit/ai/actions/test_ai_actions_instant.gd` with per-action unit tests (TDD RED):
  - `test_wait_action_completes_after_duration` — instantiate RS_AIActionWait, call start/tick/is_complete with mock context + task_state
  - `test_wait_action_tracks_elapsed_in_task_state` — verify task_state["elapsed"] increments
  - `test_publish_event_action_fires_and_completes_immediately` — RS_AIActionPublishEvent publishes to U_ECSEventBus, is_complete returns true after start
  - `test_set_field_action_modifies_component_and_completes` — RS_AIActionSetField resolves target, sets value, completes immediately
  - `test_set_field_action_typed_exports` — verify @export fields for float/int/bool/string values
- [ ] **Commit 2** — Implement typed action resources in `scripts/resources/ai/actions/` (TDD GREEN):
  - `rs_ai_action_wait.gd` — `@export var duration: float = 1.0`; implements I_AIAction; tracks elapsed in task_state
  - `rs_ai_action_publish_event.gd` — `@export var event_name: StringName`, `@export var payload: Dictionary`; implements I_AIAction
  - `rs_ai_action_set_field.gd` — `@export var field_path: String`, `@export_enum(...)  var value_type`, typed value exports; implements I_AIAction; uses U_PathResolver
- [ ] **Commit 3** — Create task runner tests + implement polymorphic runner (TDD RED → GREEN):
  - `test_task_runner_dispatches_via_i_ai_action` — verify runner calls action.start/tick/is_complete (no match blocks)
  - `test_task_queue_advances_sequentially` — mixed action types execute in order
  - `test_task_queue_completion_resets_state` — index resets, task_state cleared after queue completes
  - `test_empty_queue_does_nothing` — no crash on empty queue
  - Implement `_execute_current_task(brain, delta, context)` in S_AIBehaviorSystem using polymorphic I_AIAction dispatch

**M6 Verification**:
- [ ] All 9 tests green (5 action unit + 4 runner)
- [ ] Each action testable in isolation (no system dependency for action logic)
- [ ] Task runner uses I_AIAction polymorphic dispatch (no match/type-check blocks)
- [ ] Wait respects delta timing; instant actions complete in same tick
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 7: Typed Action Resources (Movement + Stub)

**Goal**: Create RS_AIActionMoveTo, RS_AIActionScan, RS_AIActionAnimate (stub) implementing I_AIAction. All 6 action types complete.

- [ ] **Commit 1** — Create `tests/unit/ai/actions/test_ai_actions_movement.gd` with per-action unit tests (TDD RED):
  - `test_move_to_action_sets_target_in_task_state` — RS_AIActionMoveTo.start writes target to task_state
  - `test_move_to_action_completes_when_within_threshold` — is_complete true when entity near target
  - `test_move_to_action_stays_active_when_far` — is_complete false when entity far from target
  - `test_move_to_action_resolves_waypoint_index` — waypoint_index parameter resolves to position from context waypoints
  - `test_scan_action_completes_after_duration` — RS_AIActionScan tracks elapsed, sets scan flags in task_state
  - `test_animate_stub_sets_state_field` — RS_AIActionAnimate sets task_state["animation_state"]
  - `test_animate_stub_completes_immediately` — is_complete returns true after start
- [ ] **Commit 2** — Implement typed action resources in `scripts/resources/ai/actions/` (TDD GREEN):
  - `rs_ai_action_move_to.gd` — `@export var target_position: Vector3`, `@export var target_node_path: NodePath`, `@export var waypoint_index: int = -1`, `@export var arrival_threshold: float = 0.5`; implements I_AIAction
  - `rs_ai_action_scan.gd` — `@export var scan_duration: float = 2.0`, `@export var rotation_speed: float = 1.0`; implements I_AIAction
  - `rs_ai_action_animate.gd` (stub) — `@export var animation_state: StringName`; sets task_state field, completes immediately

- [ ] **Commit 3** — Create `tests/unit/ecs/systems/test_s_ai_navigation_system.gd` and `tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` (TDD RED):
  - `test_system_extends_base_ecs_system` — S_AINavigationSystem extends BaseECSSystem
  - `test_execution_priority_is_negative_five` — runs after S_AIBehaviorSystem (-10), before S_InputSystem (0)
  - `test_writes_direction_toward_target` — entity at origin, target at (10,0,10), verify move_vector produces correct world-space movement after camera transform
  - `test_writes_zero_when_no_target` — empty task_state → Vector2.ZERO
  - `test_writes_zero_when_at_target` — within epsilon → Vector2.ZERO
  - `test_ignores_y_axis` — target at (0, 100, 10), only XZ direction matters
  - `test_skips_entity_without_body` — null body → no crash
  - `test_updates_direction_when_target_changes` — target moves between ticks, move_vector updates
  - `test_handles_no_camera_gracefully` — no camera in scene, falls back to direct mapping
  - `test_input_system_skips_entities_without_player_tag` — C_InputComponent without C_PlayerTagComponent not overwritten by player input
  - `test_input_system_still_writes_to_player_entity` — C_InputComponent + C_PlayerTagComponent still receives player input
- [ ] **Commit 4** — Implement `s_ai_navigation_system.gd` + modify `s_input_system.gd` (TDD GREEN):
  - `scripts/ecs/systems/s_ai_navigation_system.gd` — extends BaseECSSystem, execution_priority = -5
    - Queries entities with C_AIBrainComponent + C_InputComponent + C_MovementComponent
    - Reads `brain.task_state.get("ai_move_target")` → Vector3 target
    - Gets entity position via `C_MovementComponent.get_character_body().global_position`
    - Calculates world-space XZ direction to target
    - Inverse-transforms through active camera basis (via `U_ECSUtils.get_active_camera()`) to produce camera-relative Vector2
    - Writes to `C_InputComponent.set_move_vector()` — NPCs flow through same S_MovementSystem path as player
    - Falls back to direct mapping when no camera
    - Writes Vector2.ZERO when no target or within epsilon
  - `scripts/ecs/systems/s_input_system.gd` — add C_PlayerTagComponent to query filter so player input only writes to player-tagged entities
- [ ] **Commit 5** — Verify style enforcement passes; run full test suite for regressions

**M7 Verification**:
- [ ] All 7 action unit tests green
- [ ] All 9 navigation system tests green
- [ ] All 2 input filter tests green
- [ ] move_to resolves all 3 parameter variants (position, node_path, waypoint_index)
- [ ] S_AINavigationSystem bridges task_state["ai_move_target"] → C_InputComponent.move_vector via inverse camera transform
- [ ] NPCs use the same S_MovementSystem camera-relative code path as the player
- [ ] S_InputSystem only writes player input to C_PlayerTagComponent entities
- [ ] Each action has typed @export fields visible in Godot inspector
- [ ] animate is explicitly minimal (stub only — sets state, completes immediately)
- [ ] All 6 action types now implemented and independently testable
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 8: Integration Tests

**Goal**: End-to-end pipeline validation. Goal evaluation → HTN decomposition → task execution → re-planning. No new implementation — exercises M1–M7.

- [ ] **Commit 1** — Create `tests/unit/ai/integration/test_ai_pipeline_integration.gd` with integration tests:
  - `test_full_pipeline_patrol_pattern` — compound [move_to(A), wait(0.5), move_to(B), wait(0.5)], verify positions visited and waits elapsed
  - `test_goal_switch_replans_mid_queue` — change state mid-queue, verify new goal's tasks replace old
  - `test_cooldown_prevents_goal_thrashing` — rapid state changes don't cause constant re-planning
  - `test_default_goal_fallback_executes` — all goals fail, default_goal_id tasks execute
  - `test_compound_method_selection_in_context` — compound with 2 branches, correct branch chosen
- [ ] **Commit 2** — Fix bugs discovered during integration testing (if any)

**M8 Verification**:
- [ ] All 5 integration tests green
- [ ] Full pipeline works end-to-end
- [ ] Re-planning is clean (no leftover state)
- [ ] All existing project tests still pass (regression)
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 9: Demo Scene Creation

**Goal**: Build 3 gameplay scenes with CSG geometry, waypoints, triggers, and NPC entity placeholders. No NPC behavior yet.

- [ ] **Commit 1** — Create `scenes/gameplay/gameplay_power_core.tscn` (Patrol Drone room):
  - CSG industrial room with central power core (CSGCylinder)
  - Waypoint markers: WaypointA, WaypointB, WaypointC, WaypointD
  - Activatable node Area3D (investigate trigger)
  - Player spawn point
  - E_PatrolDrone placeholder (CSGSphere + C_AIBrainComponent, no settings)
- [ ] **Commit 2** — Create `scenes/gameplay/gameplay_comms_array.tscn` (Sentry room):
  - CSG open area with antenna structures (CSGBox pillars)
  - Guard post waypoints
  - Noise source Area3D positions
  - Player spawn point
  - E_Sentry placeholder (CSGBox + C_AIBrainComponent, no settings)
- [ ] **Commit 3** — Create `scenes/gameplay/gameplay_nav_nexus.tscn` (Guide Prism room):
  - CSG vertical platforming room with floating platforms (CSGBox)
  - Path marker Node3Ds for guide destinations
  - Fall detection Area3D below platforms
  - Victory trigger zone at top
  - Player spawn point
  - E_GuidePrism placeholder (CSGSphere + C_AIBrainComponent, no settings)

**M9 Verification**:
- [ ] Each scene loads without errors
- [ ] Player can spawn and move in each room
- [ ] Waypoint/marker nodes properly positioned and named
- [ ] NPC placeholder entities are visible
- [ ] `test_style_enforcement.gd` passes

---

## Milestone 10: Demo NPC Behavior Authoring & Tuning

**Goal**: Author `.tres` resources for 3 demo NPCs, wire into scenes, playtest and tune.

- [ ] **Commit 1** — Author Patrol Drone resources (`resources/ai/patrol_drone/`):
  - `cfg_patrol_drone_brain.tres` — RS_AIBrainSettings, default `&"patrol"`, interval 0.5
  - `cfg_goal_patrol.tres` — RS_AIGoal, conditions: constant 0.5, root_task: compound [move_to(WP_A), wait(1.0), move_to(WP_B), wait(1.0), ...]
  - `cfg_goal_investigate.tres` — RS_AIGoal, conditions: proximity + node_recently_activated, root_task: compound [move_to(activated_node), scan(2.0), wait(1.0)]
  - Wire brain settings onto E_PatrolDrone in gameplay_power_core.tscn
- [ ] **Commit 2** — Author Sentry resources (`resources/ai/sentry/`):
  - `cfg_sentry_brain.tres` — default `&"guard"`
  - `cfg_goal_guard.tres` — root_task: compound [scan(3.0), move_to(WP_A), scan(3.0), move_to(WP_B)]
  - `cfg_goal_investigate_disturbance.tres` — conditions: noise_level, root_task: compound [move_to(noise_source), scan(4.0), move_to(guard_post)]
  - Wire into gameplay_comms_array.tscn
- [ ] **Commit 3** — Author Guide Prism resources (`resources/ai/guide_prism/`):
  - `cfg_guide_brain.tres` — default `&"show_path"`
  - `cfg_goal_show_path.tres` — conditions: player_progress, root_task: [move_to(next_platform), wait(2.0)]
  - `cfg_goal_encourage.tres` — conditions: player_fell_recently, root_task: [move_to(respawn_point), animate("pulse"), wait(1.5)]
  - `cfg_goal_celebrate.tres` — conditions: is_at_goal, root_task: [animate("spin"), publish_event("celebration"), wait(3.0)]
  - Wire into gameplay_nav_nexus.tscn
- [ ] **Commit 4** — Playtest and tune: QB condition ranges, cooldowns, evaluation intervals, waypoint positions, threshold distances

**M10 Verification**:
- [ ] Patrol Drone switches between patrol and investigate based on player interaction
- [ ] Sentry loops guard pattern, interrupts for disturbances, returns to post
- [ ] Guide Prism shows path, encourages on fall, celebrates at goal
- [ ] No performance regression with 3 simultaneous AI NPCs
- [ ] Goal change mid-task-queue works cleanly for all 3 NPCs
- [ ] All unit + integration tests still green
- [ ] `test_style_enforcement.gd` passes

---

## Final Completion Check

- [ ] All milestones above marked complete
- [ ] All tests green (unit, integration, style)
- [ ] Continuation prompt updated to "Complete"
- [ ] AGENTS.md updated with AI System patterns (if applicable)
- [ ] DEV_PITFALLS.md updated with any new pitfalls discovered
- [ ] Branch merged to main
