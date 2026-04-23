# Implementation Plan: AI System (GOAP / HTN)

## Summary

- **Feature / area**: AI System — GOAP goal selection + HTN task decomposition for NPC behavior
- **Branch**: `GOAP-AI`
- **Current status**: Milestone 15 complete (player-NPC interaction triggers)

This plan defines how to build a data-driven NPC behavior system using GOAP goals scored by QB Rule Manager v2 and HTN task decomposition into executable primitive actions. The system runs as an ECS system (`S_AIBehaviorSystem`) consuming `C_AIBrainComponent` data, with all behavior definitions authored as `.tres` resources.

## Milestones

1. **M1 — Task Resource Skeleton + I_AIAction Interface** — Create RS_AITask base, RS_AIPrimitiveTask, RS_AICompoundTask, and the I_AIAction interface (`start`, `tick`, `is_complete`).
2. **M2 — Goal & Brain Settings Resources** — Create RS_AIGoal and RS_AIBrainSettings. RS_AIGoal wraps QB conditions + root task; RS_AIBrainSettings holds goal arrays and evaluation config.
3. **M3 — C_AIBrainComponent** — ECS component holding per-NPC AI runtime state (active goal, task queue, task index, task state).
4. **M4 — U_HTNPlanner** — Recursive task decomposition utility. Flattens compound tasks into primitive task queues with cycle detection and method condition evaluation.
5. **M5 — Goal Evaluation Loop** — S_AIBehaviorSystem shell with per-tick goal evaluation. Composes QB v2 utilities for scoring, selection, and state tracking.
6. **M6 — Typed Action Resources (Instant)** — Create RS_AIActionWait, RS_AIActionPublishEvent, RS_AIActionSetField implementing I_AIAction. Polymorphic task runner in S_AIBehaviorSystem (no match blocks).
7. **M7 — Typed Action Resources (Movement + Stub)** — Create RS_AIActionMoveTo, RS_AIActionScan, RS_AIActionAnimate (stub). All 6 action types complete.
8. **M8 — Integration Tests** — End-to-end pipeline validation: goal evaluation → HTN decomposition → action execution → re-planning.
9. **M9 — Demo Scene Creation** — Build 3 gameplay scenes (Power Core, Comms Array, Nav Nexus) with CSG geometry, waypoints, triggers, and NPC entity placeholders.
10. **M10 — Demo NPC Behavior Authoring & Tuning** — Author `.tres` resources for Patrol Drone, Sentry, and Guide Prism. Wire into demo scenes. Playtest and tune.

## Dependency Graph

```
M1 (Task Resources) ──> M2 (Goal/Brain Resources) ──> M3 (Component)
                                                           │
M4 (HTN Planner) ─────────────────────────────────────────>│
                                                           v
                                                    M5 (Goal Eval System)
                                                           │
                                                    M6 (Actions: wait/event/field)
                                                           │
                                                    M7 (Actions: move/scan/animate)
                                                           │
                                                    M8 (Integration Tests)
                                                           │
                                              ┌────────────┴────────────┐
                                              v                         v
                                    M9 (Demo Scenes)          M10 (NPC .tres + Tuning)
                                              │                         ^
                                              └─────────────────────────┘
```

M4 depends only on M1 (RS_AITask types) so it can run in parallel with M2/M3. M9 can start after M3 (needs component placeholder + valid placeholder `RS_AIBrainSettings`). M10 requires both M8 (proven pipeline) and M9 (scenes).

## Work Breakdown

### M1 — Task Resource Skeleton + I_AIAction Interface

- [x] Write tests for RS_AIPrimitiveTask, RS_AICompoundTask, and I_AIAction interface contract (field assignment, type checks, subtask ordering, action interface detection)
- [x] Implement `scripts/interfaces/i_ai_action.gd` — interface with `start(context, task_state)`, `tick(context, task_state, delta)`, `is_complete(context, task_state)` contract (matching I_Condition/I_Effect pattern)
- [x] Implement `scripts/resources/ai/tasks/rs_ai_task.gd` — base class extending Resource with `@export var task_id: StringName`
- [x] Implement `scripts/resources/ai/tasks/rs_ai_primitive_task.gd` — extends RS_AITask with `@export var action: Resource` (I_AIAction)
- [x] Implement `scripts/resources/ai/tasks/rs_ai_compound_task.gd` — extends RS_AITask with `subtasks`, `method_conditions`
- [x] Verify style enforcement passes

M1 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ai/resources/test_rs_ai_task.gd` (initial 5/5 passing; current 6/6 after audit hardening test coverage for `method_conditions`), style enforcement passed (17/17), and full-suite run currently reports `3627/3636` passing with `9` pending/risky headless/platform skips and `0` failing tests.

### M2 — Goal & Brain Settings Resources

- [x] Write tests for RS_AIGoal and RS_AIBrainSettings (field defaults, goal arrays, condition compatibility)
- [x] Implement `scripts/resources/ai/goals/rs_ai_goal.gd` — `goal_id`, `conditions: Array[Resource]`, `root_task: Resource`, `priority: int`, plus QB gate fields (`score_threshold`, `cooldown`, `one_shot`, `requires_rising_edge`)
- [x] Implement `scripts/resources/ai/brain/rs_ai_brain_settings.gd` — `goals: Array[Resource]`, `default_goal_id`, `evaluation_interval: float`
- [x] Verify RS_AIGoal.conditions accepts existing QB condition types

M2 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ai/resources/test_rs_ai_goal.gd` (initial 5/5 passing; current 6/6 after audit hardening for goal gate fields), style enforcement passed (17/17), and full-suite run currently reports `3666/3675` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M3 — C_AIBrainComponent

- [x] Write component tests (COMPONENT_TYPE constant, settings validation, runtime state defaults, ECS registration)
- [x] Implement `scripts/ecs/components/c_ai_brain_component.gd` extending BaseECSComponent
  - `const COMPONENT_TYPE := StringName("C_AIBrainComponent")`
  - `@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_AIBrainSettings") var brain_settings: Resource`
  - Runtime vars: `active_goal_id`, `current_task_queue`, `current_task_index`, `task_state`, `evaluation_timer`
  - Override `_validate_required_settings()` to require brain_settings
- [x] Verify component registers with M_ECSManager and is queryable

M3 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ecs/components/test_c_ai_brain_component.gd` (5/5 passing), style enforcement passed (17/17), and full-suite run currently reports `3633/3642` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M4 — U_HTNPlanner

- [x] Write decomposition tests (single primitive, flat compound, nested compounds, method condition branching, cycle detection, empty/null input, max depth guard)
- [x] Implement `scripts/utils/ai/u_htn_planner.gd` extending RefCounted
  - `static func decompose(task: Resource, context: Dictionary, max_depth: int = 20) -> Array[Resource]`
  - Recursive `_decompose_recursive` with visited set for cycle detection
  - Uses `U_RuleScorer.score_rules()` to evaluate method_conditions for compound branch selection
- [x] Verify integration with existing U_RuleScorer for condition evaluation

M4 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ai/test_u_htn_planner.gd` (8/8 passing), style enforcement passed (17/17), and full-suite run currently reports `3641/3650` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M5 — Goal Evaluation Loop

- [x] Write goal evaluation tests (highest scorer wins, priority tiebreak, default goal fallback, goal change clears queue, evaluation interval throttling, no-brain-component safety)
- [x] Implement `scripts/ecs/systems/s_ai_behavior_system.gd` extending BaseECSSystem
  - Compose: U_RuleScorer, U_RuleSelector, U_RuleStateTracker (following S_CharacterStateSystem pattern)
  - `process_tick(delta)`: query C_AIBrainComponent entities, score goals as QB rules, select winner, detect goal change, call U_HTNPlanner.decompose
  - Build context dict from entity components
- [x] Verify system composes QB v2 utilities (not inheriting)

M5 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` (initial 7/7 passing; current 10/10 after hardening coverage for cooldown/one-shot/rising-edge gates), winner gating now marks cooldown/one-shot only for the selected goal, style enforcement passed (17/17), and full-suite run currently reports `3666/3675` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M6 — Typed Action Resources (Instant)

- [x] Write unit tests for each action resource in isolation (instantiate, call start/tick/is_complete with mock context and task_state):
  - RS_AIActionWait: completes after duration, tracks elapsed in task_state
  - RS_AIActionPublishEvent: fires event via U_ECSEventBus, completes immediately
  - RS_AIActionSetField: resolves target via U_PathResolver, sets value, completes immediately
- [x] Implement typed action resources in `scripts/resources/ai/actions/`:
  - `rs_ai_action_wait.gd` — `@export var duration: float = 1.0`; tracks elapsed in task_state
  - `rs_ai_action_publish_event.gd` — `@export var event_name: StringName`, `@export var payload: Dictionary`
  - `rs_ai_action_set_field.gd` — `@export var field_path: String`, `@export_enum("float", "int", "bool", "string", "string_name") var value_type: String`, typed value exports
- [x] Write task runner tests (sequential queue advancement, queue completion resets state, empty queue safety, polymorphic dispatch via I_AIAction)
- [x] Implement polymorphic task runner in S_AIBehaviorSystem: `_execute_current_task(brain, delta, context)` — calls `action.start()`, `action.tick()`, `action.is_complete()` on current task's action resource (no match blocks)

M6 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ai/actions/test_ai_actions_instant.gd` (5/5 passing) and `tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` (initial 4/4 passing; current 6/6 after hardening coverage for invalid task/action skip behavior), style enforcement passed (17/17), goal-loop regression guard passed (`tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` 10/10), and full-suite run currently reports `3666/3675` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M7 — Typed Action Resources (Movement + Stub) + AI Navigation System

- [x] Write unit tests for each action resource in isolation:
  - RS_AIActionMoveTo: sets target, completes within threshold, stays active when far, waypoint_index resolution
  - RS_AIActionScan: completes after scan_duration, sets scan flags
  - RS_AIActionAnimate (stub): sets task_state["animation_state"], completes immediately
- [x] Implement typed action resources in `scripts/resources/ai/actions/`:
  - `rs_ai_action_move_to.gd` — `@export var target_position: Vector3`, `@export var target_node_path: NodePath`, `@export var waypoint_index: int = -1`, `@export var arrival_threshold: float = 0.5`
  - `rs_ai_action_scan.gd` — `@export var scan_duration: float = 2.0`, `@export var rotation_speed: float = 1.0`
  - `rs_ai_action_animate.gd` (stub) — `@export var animation_state: StringName`; sets task_state field, completes immediately
- [x] Write navigation system + input filter tests (9 nav tests + 2 input filter tests)
- [x] Implement `scripts/ecs/systems/s_ai_navigation_system.gd` (M7 historical step; superseded by R6 `s_move_target_follower_system.gd`):
  - Extended BaseECSSystem, `execution_priority = -5` (after S_AIBehaviorSystem at -10, before S_InputSystem/S_MovementSystem at 0)
  - Queried entities with `C_AIBrainComponent` + `C_InputComponent` + `C_MovementComponent`
  - Read `brain.task_state["ai_move_target"]` (Vector3), calculated XZ-plane world direction to target
  - Inverse-transformed world direction through active camera basis (via `U_ECSUtils.get_active_camera()`) to produce camera-relative Vector2
  - Wrote to `C_InputComponent.set_move_vector()` — NPCs flowed through same S_MovementSystem path as player
  - Fell back to direct Vector2 mapping when no camera; wrote Vector2.ZERO when no target or within epsilon
- [x] Modify `scripts/ecs/systems/s_input_system.gd`: add `C_PlayerTagComponent` to query filter so player input only writes to player-tagged entities (prevents clobbering AI move_vector)
- [x] Verify style enforcement + full regression suite

M7 completion note (2026-04-02): RED/GREEN cycle completed for `tests/unit/ai/actions/test_ai_actions_movement.gd` (now `10/10` after target-node-path hardening coverage), `tests/unit/ecs/systems/test_s_ai_navigation_system.gd` (`9/9`), and `tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` (`2/2`). Hardening pass updates include same-goal replay replanning when queue completion leaves no active tasks, per-context `one_shot` scoping (`rule_id + context_key`) via `U_RuleStateTracker`, and default shared-scene wiring of `S_AIBehaviorSystem(-10)` + `S_AINavigationSystem(-5)` in both `tmpl_base_scene.tscn` and `gameplay_base.tscn` at that phase. This runtime path was later generalized in R6 to `S_MoveTargetFollowerSystem(-5)`. Style enforcement passed (`17/17`), and full-suite run now reports `3695/3704` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M8 — Integration Tests

- [x] Write integration tests:
  - Full pipeline patrol pattern (move_to → wait → move_to → wait)
  - Goal switch replans mid-queue
  - Cooldown prevents goal thrashing
  - Default goal fallback executes
  - Compound method selection in context
- [x] Fix bugs discovered during integration testing
- [x] Verify all existing tests still pass (regression check)

M8 completion note (2026-04-02): Added `tests/unit/ai/integration/test_ai_pipeline_integration.gd` with 6 end-to-end tests (patrol pipeline, real movement-system coupling, mid-queue replanning, cooldown anti-thrash, default-goal fallback, and context-driven method-branch selection). RED confirmed on initial parse/runtime issues (headless-safe type annotations + scene-tree transform usage), then GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_ai_pipeline_integration.gd` passed `6/6`. Regression guards passed (`test_s_ai_behavior_system_goals.gd` `12/12`, `test_s_ai_behavior_system_tasks.gd` `6/6`, `test_ai_actions_movement.gd` `10/10`, `test_s_ai_navigation_system.gd` `9/9`, `test_s_input_system_ai_filter.gd` `2/2`) for that phase; follower-bridge coverage moved to `test_s_move_target_follower_system.gd` in R6. Style enforcement passed (`17/17`), and full-suite run currently reports `3695/3704` passing with `9` pending/risky headless/platform/mobile skips and `0` failing tests.

### M9 — Demo Scene Creation

- [x] Create `scenes/gameplay/gameplay_power_core.tscn` — industrial room with central power core (CSGCylinder), waypoint markers (A/B/C/D), activatable node Area3D, player spawn
- [x] Create `scenes/gameplay/gameplay_comms_array.tscn` — open area with antenna structures (CSGBox pillars), guard post waypoints, noise source Area3Ds, player spawn
- [x] Create `scenes/gameplay/gameplay_nav_nexus.tscn` — vertical platforming room with floating platforms (CSGBox), path markers, fall detection area, victory trigger zone, player spawn
- [x] Add NPC entity placeholders to each scene (CSG visuals + C_AIBrainComponent with a valid placeholder RS_AIBrainSettings resource assigned)
- [x] Verify scenes load, player can spawn/move, style enforcement passes

M9 completion note (2026-04-02): Authored `gameplay_power_core.tscn`, `gameplay_comms_array.tscn`, and `gameplay_nav_nexus.tscn` with required CSG prototype geometry, marker/trigger nodes, and placeholder NPC entities (`E_PatrolDrone`, `E_Sentry`, `E_GuidePrism`) each wired to a valid shared placeholder brain resource (`resources/ai/cfg_ai_brain_placeholder.tres`). Post-audit integration pass added runtime trigger wiring (`Inter_AIDemoFlagZone` durable AI flags + Nav fall hazard), scene-registry entries and loader preload/backfill coverage for mobile/web exports, and default new-game/retry routing to `power_core`. Validation passed with style enforcement (`17/17`) and targeted scene-registry/main-menu checks.

### M10 — Demo NPC Behavior Authoring & Tuning

- [x] Author Patrol Drone `.tres` resources (`resources/ai/patrol_drone/`):
  - `cfg_patrol_drone_brain.tres`, `cfg_goal_patrol.tres`, `cfg_goal_investigate.tres`
  - Wire onto E_PatrolDrone in gameplay_power_core.tscn
- [x] Author Sentry `.tres` resources (`resources/ai/sentry/`):
  - `cfg_sentry_brain.tres`, `cfg_goal_guard.tres`, `cfg_goal_investigate_disturbance.tres`
  - Wire into gameplay_comms_array.tscn
- [x] Author Guide Prism `.tres` resources (`resources/ai/guide_prism/`):
  - `cfg_guide_brain.tres`, `cfg_goal_show_path.tres`, `cfg_goal_encourage.tres`, `cfg_goal_celebrate.tres`
  - Wire into gameplay_nav_nexus.tscn
- [x] Playtest/tune baseline: authored/tuned QB condition ranges, cooldowns, evaluation intervals, and move thresholds with automated validation harnesses
- [x] Verify all 3 NPCs behave as designed, no performance regression baseline in automated regression

M10 completion note (2026-04-02): Added full demo archetype resource trees under `resources/ai/patrol_drone/`, `resources/ai/sentry/`, and `resources/ai/guide_prism/`; rewired `E_PatrolDrone`, `E_Sentry`, and `E_GuidePrism` to authored brain settings; and added runtime movement wiring for each NPC (`CharacterBody3D`, `C_InputComponent`, `C_MovementComponent`, `cfg_movement_default`). Added `tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` for RED→GREEN verification of resource authoring + scene wiring. Validation passed with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` → `6/6`
- `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17`
- `tools/run_gut_suite.sh` → `3704/3713` passing, `9` pending/risky, `0` failing.

## Testing Strategy

- **Unit Tests** (M1–M7): Resource field validation, component registration, HTN decomposition logic, goal evaluation scoring, primitive task handlers. Follow TDD — tests first, then implementation.
- **Integration Tests** (M8): Full goal-to-execution pipeline, re-planning on goal change, cooldown gating, default fallback.
- **Behavioral Tests** (M10): Playtest each NPC archetype in its demo room to verify correct behavior switching.
- **Regression**: Run existing test suite after each milestone to ensure no breakage. Run `tests/unit/style/test_style_enforcement.gd` after file creation/rename.

## Risks & Mitigations

- **Risk**: QB v2 context building for AI goals differs from existing consumers (character state, game events, camera).
  - Mitigation: Study `S_CharacterStateSystem._build_entity_context()` and replicate the pattern. Start with minimal context and expand as needed.

- **Risk**: HTN decomposition performance with deeply nested compound tasks.
  - Mitigation: Max depth guard (20 levels). Demo NPCs use shallow trees (2-3 levels). Profile if needed.

- **Risk**: `move_to` task completion depends on movement systems that may not exist for AI entities.
  - Mitigation: `S_MoveTargetFollowerSystem` bridges both `C_MoveTargetComponent` targets and AI task-state move targets (`task_state["ai_move_target"]`) into `C_InputComponent.move_vector` in world-space. NPCs and non-AI movers share the same follower bridge. `S_InputSystem` is filtered by `C_PlayerTagComponent` to prevent player input clobbering AI-authored move vectors.

- **Risk**: Demo scene creation scope creep (art, level design).
  - Mitigation: CSG-only geometry. Functional prototypes, not polished levels. Focus on proving AI behavior, not visual quality.

- **Risk**: `animate` stub may be too minimal for demo believability.
  - Mitigation: Stub sets a state field that other systems could consume. Visual feedback can come from CSG color/scale changes rather than skeletal animation.

## File Inventory

### Implemented Now (M1-M10)

| File | Type | Description |
|------|------|-------------|
| `scripts/interfaces/i_ai_action.gd` | Interface | Action contract: `start()`, `tick()`, `is_complete()` |
| `scripts/resources/ai/tasks/rs_ai_task.gd` | Resource | Base task class with task_id |
| `scripts/resources/ai/tasks/rs_ai_primitive_task.gd` | Resource | Primitive task wrapper holding `action: Resource` (I_AIAction) |
| `scripts/resources/ai/tasks/rs_ai_compound_task.gd` | Resource | Compound task with subtasks, method_conditions |
| `scripts/resources/ai/goals/rs_ai_goal.gd` | Resource | Goal with conditions, root_task, priority, and QB gate fields (`score_threshold`, `cooldown`, `one_shot`, `requires_rising_edge`) |
| `scripts/resources/ai/brain/rs_ai_brain_settings.gd` | Resource | Brain settings with goals array, defaults, evaluation config |
| `scripts/ecs/components/c_ai_brain_component.gd` | Component | AI brain ECS component with runtime state and required-settings validation |
| `scripts/utils/ai/u_htn_planner.gd` | Utility | HTN decomposition utility with recursive flattening, cycle detection, and method-condition branch selection via `U_RuleScorer` |
| `scripts/resources/ai/actions/rs_ai_action_wait.gd` | Resource | Instant wait action implementing `I_AIAction`; tracks elapsed task state |
| `scripts/resources/ai/actions/rs_ai_action_publish_event.gd` | Resource | Instant event action implementing `I_AIAction`; publishes via `U_ECSEventBus` |
| `scripts/resources/ai/actions/rs_ai_action_set_field.gd` | Resource | Instant set-field action implementing `I_AIAction`; resolves targets with `U_PathResolver` |
| `scripts/resources/ai/actions/rs_ai_action_move_to.gd` | Resource | Movement action implementing `I_AIAction`; resolves waypoint/node/position targets and completion by XZ arrival threshold |
| `scripts/resources/ai/actions/rs_ai_action_scan.gd` | Resource | Timed scan action implementing `I_AIAction`; tracks elapsed scan state and completion |
| `scripts/resources/ai/actions/rs_ai_action_animate.gd` | Resource | Stub animation action implementing `I_AIAction`; writes animation state and completes immediately |
| `scripts/ecs/systems/s_ai_behavior_system.gd` | System | Goal evaluation + task runner (`_execute_current_task`) composing `U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, and `U_HTNPlanner`; includes same-goal replay replan when queue completes |
| `scripts/ecs/systems/s_move_target_follower_system.gd` | System | Shared move-target bridge (`execution_priority = -5`) converting component/task-state targets into world-space move vectors |
| `scripts/utils/qb/u_rule_state_tracker.gd` | Utility | QB rule state helper with context-scoped `one_shot` tracking (`rule_id + context_key`) while preserving cooldown/rising-edge behavior |
| `scripts/ecs/systems/s_input_system.gd` | System | Player-input writer now filtered to `C_PlayerTagComponent` entities to avoid AI move-vector clobbering |
| `scenes/templates/tmpl_base_scene.tscn` | Scene | Shared base scene now wires `S_AIBehaviorSystem(-10)` and `S_MoveTargetFollowerSystem(-5)` before `S_InputSystem(0)` |
| `scenes/gameplay/gameplay_base.tscn` | Scene | Gameplay base now wires `S_AIBehaviorSystem(-10)` and `S_MoveTargetFollowerSystem(-5)` before `S_InputSystem(0)` |
| `tests/unit/ai/resources/test_rs_ai_task.gd` | Test | M1 resources + I_AIAction interface (includes `method_conditions` coverage) |
| `tests/unit/ai/resources/test_rs_ai_goal.gd` | Test | M2 goal/brain settings resource coverage |
| `tests/unit/ecs/components/test_c_ai_brain_component.gd` | Test | M3 component registration/runtime-state/validation coverage |
| `tests/unit/ai/test_u_htn_planner.gd` | Test | M4 HTN decomposition coverage (primitive/compound/nested/method-conditions/cycle/max-depth) |
| `tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` | Test | M5 goal-loop coverage (highest scorer, priority tiebreak, fallback goal, re-plan on goal switch, same-goal replay after queue completion, interval throttling, cooldown/one-shot/rising-edge gates, per-context one-shot isolation, no-brain safety) |
| `tests/unit/ai/actions/test_ai_actions_instant.gd` | Test | M6 instant action resource coverage (wait/event/set-field) |
| `tests/unit/ai/actions/test_ai_actions_movement.gd` | Test | M7 movement/stub action coverage (move_to/scan/animate) including target_node_path context-resolution hardening |
| `tests/unit/ecs/systems/test_s_ai_behavior_system_tasks.gd` | Test | M6 task-runner coverage (dispatch, sequencing, completion reset, empty queue safety, invalid queue entry/action skip hardening) |
| `tests/unit/ecs/systems/test_s_move_target_follower_system.gd` | Test | R6 shared follower bridge coverage (component + AI task-state paths, target preference, per-entity throttle) |
| `tests/unit/ecs/systems/test_s_input_system_ai_filter.gd` | Test | M7 input filter coverage (`C_PlayerTagComponent` query gating) |
| `tests/unit/ai/integration/test_ai_pipeline_integration.gd` | Test | M8 integration coverage for full GOAP→HTN→action pipeline, real movement-system coupling, mid-queue replanning, cooldown gating, default fallback, and method-branch selection |
| `tests/mocks/mock_ai_action_track.gd` | Test helper | M6 mock action used to assert polymorphic runner call ordering/counters |
| `resources/ai/cfg_ai_brain_placeholder.tres` | Resource instance | M9 placeholder `RS_AIBrainSettings` used by demo NPC entities to satisfy required brain settings |
| `scenes/gameplay/gameplay_power_core.tscn` | Scene | M9 Patrol Drone prototype room (CSG power core, waypoints, activatable node, player spawn, `E_PatrolDrone`) |
| `scenes/gameplay/gameplay_comms_array.tscn` | Scene | M9 Sentry prototype room (CSG antenna/pillar geometry, guard waypoints, noise-source areas, player spawn, `E_Sentry`) |
| `scenes/gameplay/gameplay_nav_nexus.tscn` | Scene | M9 Guide Prism prototype room (CSG vertical platforms, path markers, fall/victory triggers, player spawn, `E_GuidePrism`) |
| `resources/ai/patrol_drone/cfg_patrol_drone_brain.tres` | Resource instance | M10 Patrol Drone brain settings with patrol + investigate goals |
| `resources/ai/patrol_drone/cfg_goal_patrol.tres` | Resource instance | M10 Patrol Drone patrol loop goal authored as compound move/wait task sequence |
| `resources/ai/patrol_drone/cfg_goal_investigate.tres` | Resource instance | M10 Patrol Drone investigate goal (input-triggered move/scan/wait sequence) |
| `resources/ai/sentry/cfg_sentry_brain.tres` | Resource instance | M10 Sentry brain settings with guard + disturbance investigate goals |
| `resources/ai/sentry/cfg_goal_guard.tres` | Resource instance | M10 Sentry guard loop goal (scan/patrol sequence across guard waypoints) |
| `resources/ai/sentry/cfg_goal_investigate_disturbance.tres` | Resource instance | M10 Sentry disturbance investigate goal (noise source scan + return) |
| `resources/ai/guide_prism/cfg_guide_brain.tres` | Resource instance | M10 Guide Prism brain settings with show_path + encourage + celebrate goals |
| `resources/ai/guide_prism/cfg_goal_show_path.tres` | Resource instance | M10 Guide Prism pathing loop goal (path marker progression) |
| `resources/ai/guide_prism/cfg_goal_encourage.tres` | Resource instance | M10 Guide Prism encouragement goal (respawn assist + pulse) |
| `resources/ai/guide_prism/cfg_goal_celebrate.tres` | Resource instance | M10 Guide Prism celebration goal (spin + publish event + wait) |
| `tests/unit/ai/resources/test_ai_demo_behavior_resources.gd` | Test | M10 resource + scene wiring guard (brain files, goals, decomposable action queues, scene brain assignments) |

## References

- [AI System Overview](ai-system-overview.md)
- [AI System Tasks](ai-system-tasks.md)
- [AI System Continuation Prompt](ai-system-continuation-prompt.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
