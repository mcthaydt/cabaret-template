# Scene Director - Tasks Checklist

## Phase 1: State Infrastructure (TDD)

### 1A: Objective Resources

- [x] T1.1: Create `scripts/resources/scene_director/rs_objective_definition.gd` (RS_ObjectiveDefinition) - objective_id, description, objective_type enum (STANDARD, VICTORY, CHECKPOINT — NOTE: CHECKPOINT type is defined for future use; M_ObjectivesManager treats it as STANDARD in Phase 1-6), conditions (Array[Resource] — use RS_ConditionReduxField, RS_ConditionEventPayload, RS_ConditionConstant subclasses; no RS_ConditionComponentField), completion_effects (Array[Resource]), completion_event_payload (Dictionary — arbitrary data merged into the published completion event; e.g., VICTORY objectives set `{"target_scene": StringName("victory")}`), dependencies (Array[StringName]), auto_activate
- [x] T1.2: Create `scripts/resources/scene_director/rs_objective_set.gd` (RS_ObjectiveSet) - set_id, description, objectives (Array[Resource], entries should be RS_ObjectiveDefinition)

### 1B: Scene Director Resources

- [x] T1.3: Create `scripts/resources/scene_director/rs_beat_definition.gd` (RS_BeatDefinition) - beat_id, description, preconditions (Array[Resource]), effects (Array[Resource]), wait_mode enum (INSTANT, TIMED, SIGNAL), duration, wait_event
- [x] T1.4: Create `scripts/resources/scene_director/rs_scene_directive.gd` (RS_SceneDirective) - directive_id, description, target_scene_id, selection_conditions (Array[Resource]), priority, beats (Array[Resource], entries should be RS_BeatDefinition)

### 1C: Redux -- Objectives Slice (TDD)

- [x] T1.5: Create `scripts/resources/state/rs_objectives_initial_state.gd` (RS_ObjectivesInitialState) - statuses Dictionary, active_set_id StringName, event_log Array[Dictionary] (typed — entries are Dictionaries from U_ObjectiveEventLog.create_entry()); implement `to_dictionary()`
- [x] T1.6: Create stub `scripts/state/actions/u_objectives_actions.gd` (U_ObjectivesActions) - static methods returning action dictionaries: activate, complete, fail, set_active_set, log_event, reset_all, bulk_activate
- [x] T1.7: Create stub `scripts/state/reducers/u_objectives_reducer.gd` (U_ObjectivesReducer) - static reduce function returning unmodified state
- [x] T1.8: Create `scripts/state/selectors/u_objectives_selectors.gd` (U_ObjectivesSelectors) - get_objective_status, get_active_objectives, is_completed, get_event_log, get_active_set_id
- [x] T1.8a: Create `tests/unit/scene_director/test_objectives_selectors.gd` - get_objective_status returns correct status string, get_active_objectives returns only "active" entries, is_completed returns true only for "completed" status, get_event_log returns the log array, get_active_set_id returns the set_id; all selectors return safe defaults on empty/missing state
- [x] T1.9: Create `tests/unit/scene_director/test_objectives_reducer.gd` - All action types: activate changes status to "active", complete changes to "completed", fail changes to "failed", set_active_set updates set_id, log_event appends to event_log, reset_all clears statuses, bulk_activate activates multiple
- [x] T1.10: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): Explicit red-step logs were not preserved in the commit trail; red was observed during local TDD iteration before reducer implementation.
- [x] T1.11: Implement U_ObjectivesReducer -- handle all action types with immutable state updates
- [x] T1.12: Run tests -- confirm they PASS (green)

### 1D: Redux -- Scene Director Slice (TDD)

- [x] T1.13: Create `scripts/resources/state/rs_scene_director_initial_state.gd` (RS_SceneDirectorInitialState) - active_directive_id StringName, current_beat_index int, state String ("idle"); implement `to_dictionary()`
- [x] T1.14: Create stub `scripts/state/actions/u_scene_director_actions.gd` (U_SceneDirectorActions) - static methods: start_directive(directive_id), advance_beat() (NO beat_index parameter — reducer always increments by 1), complete_directive(), reset()
- [x] T1.15: Create stub `scripts/state/reducers/u_scene_director_reducer.gd` (U_SceneDirectorReducer) - static reduce function returning unmodified state
- [x] T1.16: Create `scripts/state/selectors/u_scene_director_selectors.gd` (U_SceneDirectorSelectors) - get_active_directive_id, get_current_beat_index, is_running, get_director_state
- [x] T1.16a: Create `tests/unit/scene_director/test_scene_director_selectors.gd` - get_active_directive_id returns directive_id string, get_current_beat_index returns int, is_running returns true only when state="running", get_director_state returns the state string; all selectors return safe defaults on empty state
- [x] T1.17: Create `tests/unit/scene_director/test_scene_director_reducer.gd` - start_directive sets directive_id and state="running" and beat_index=0, advance_beat increments current_beat_index by 1 (action has no parameter), complete_directive sets state="completed", reset returns to idle with beat_index=-1
- [x] T1.18: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): Explicit red-step logs were not preserved in the commit trail; red was observed during local TDD iteration before reducer implementation.
- [x] T1.19: Implement U_SceneDirectorReducer -- handle all action types
- [x] T1.20: Run tests -- confirm they PASS (green)

### 1E: Slice Registration

- [x] T1.21: Add objectives slice to `U_StateSliceManager.initialize_slices()` -- persistent slice (saved/loaded)
- [x] T1.22: Add scene_director slice to `U_StateSliceManager.initialize_slices()` -- register with `is_transient = true` (same pattern as the `navigation` slice; all three fields are runtime-only so the whole slice is excluded from saves, not individual fields)
- [x] T1.23: Add `@export var objectives_initial_state: Resource` to `M_StateStore`
- [x] T1.24: Add `@export var scene_director_initial_state: Resource` to `M_StateStore`

### 1F: Event Constants

- [x] T1.25: Add objective event constants to `U_ECSEventNames`: EVENT_OBJECTIVE_ACTIVATED, EVENT_OBJECTIVE_COMPLETED, EVENT_OBJECTIVE_FAILED, EVENT_OBJECTIVE_VICTORY_TRIGGERED
- [x] T1.26: Add directive event constants to `U_ECSEventNames`: EVENT_DIRECTIVE_STARTED, EVENT_DIRECTIVE_COMPLETED, EVENT_BEAT_ADVANCED

### 1G: Regression Check

- [x] T1.27: Run full existing test suite and confirm no new regressions (allow documented pre-existing failures)
- [x] T1.28: Update continuation prompt (`scene-director-continuation-prompt.md`) with Phase 1 status

**Phase 1 Commit**: State infrastructure for objectives and scene director (no behavioral changes)

Phase 1 completion notes (2026-02-25):
- Added all Phase 1 resource/state infrastructure files and slice wiring in `M_StateStore` + `U_StateSliceManager`.
- Added Scene Director unit coverage (`tests/unit/scene_director/*`) for objectives/scene_director reducers and selectors.
- Regression validation: targeted suites passed (`unit/qb`, `unit/ecs`, `unit/ecs/systems`, `unit/style`, `integration/scene_manager`).
- Full `res://tests` run completed with one existing unrelated failure in `tests/integration/lighting/test_character_zone_lighting_flow.gd` (`test_multi_character_multi_zone_performance_smoke`, 10.375 ms vs < 6.0 ms threshold).

---

## Phase 2: Objectives Manager Core (TDD)

### 2A: Graph Helper (TDD)

- [ ] T2.1: Create stub `scripts/utils/scene_director/u_objective_graph.gd` (U_ObjectiveGraph) - empty static methods returning default values
- [ ] T2.2: Create `tests/unit/scene_director/test_objective_graph.gd` - Build graph from objective definitions, cycle detection (returns errors for circular deps), missing reference detection (dependency IDs not in known_ids), get_ready_dependents (returns dependents whose prerequisites are all completed), topological sort (returns valid evaluation order). Note: validate_graph signature is `validate_graph(graph: Dictionary, known_ids: Array[StringName]) -> Array[String]`; tests must pass known_ids.
- [ ] T2.3: Run tests -- confirm they FAIL (red)
- [ ] T2.4: Implement U_ObjectiveGraph -- adjacency list construction, DFS cycle detection, dependent readiness check, topological sort via Kahn's algorithm; validate_graph takes both graph and known_ids
- [ ] T2.5: Run tests -- confirm they PASS (green)

### 2B: Event Log Helper (TDD)

- [ ] T2.6: Create stub `scripts/utils/scene_director/u_objective_event_log.gd` (U_ObjectiveEventLog) - empty static methods
- [ ] T2.7: Create `tests/unit/scene_director/test_objective_event_log.gd` - Entry creation with timestamp, format_log produces readable output, all event types (activated, completed, failed, dependency_met, condition_checked)
- [ ] T2.8: Run tests -- confirm they FAIL (red)
- [ ] T2.9: Implement U_ObjectiveEventLog -- structured entry creation, formatted output
- [ ] T2.10: Run tests -- confirm they PASS (green)

### 2C: M_ObjectivesManager (TDD)

- [ ] T2.11: Create stub `scripts/managers/m_objectives_manager.gd` (M_ObjectivesManager extends Node) - @export state_store, @export objective_sets, empty methods for load_objective_set, _check_conditions, _execute_effects, _complete_objective, _fail_objective, _activate_dependents, get_objective_status, _build_context
- [ ] T2.12: Create `tests/unit/scene_director/test_objectives_manager.gd` - Set loading activates auto_activate objectives (activates on load, not on event), condition evaluation via direct condition.evaluate(context) calls, completion dispatches actions + executes effects via effect.execute(context) + activates dependents, failure dispatches fail action, event logging records transitions, graph validation rejects cycles. For VICTORY type: completion publishes EVENT_OBJECTIVE_VICTORY_TRIGGERED with objective.completion_event_payload as the event payload.
- [ ] T2.13: Run tests -- confirm they FAIL (red)
- [ ] T2.14: Implement M_ObjectivesManager -- store discovery (injection + ServiceLocator), _ready() calls load_objective_set for each set in objective_sets, event subscriptions, set loading with graph build + validate_graph(graph, known_ids), condition checking via direct condition.evaluate(context) loop, effect execution via effect.execute(context) loop, completion flow with dependent activation, event logging. VICTORY completion: read objective.completion_event_payload, publish EVENT_OBJECTIVE_VICTORY_TRIGGERED with that dict as payload.
- [ ] T2.15: Run tests -- confirm they PASS (green)

### 2D: Regression Check

- [ ] T2.16: Run full existing test suite -- zero regressions
- [ ] T2.17: Update continuation prompt with Phase 2 status

**Phase 2 Commit**: Objectives manager core with graph, event log, and condition evaluation

---

## Phase 3: Scene Director Core (TDD)

### 3A: Beat Runner Helper (TDD)

- [ ] T3.1: Create stub `scripts/utils/scene_director/u_beat_runner.gd` (U_BeatRunner extends RefCounted) - empty methods for start, execute_current_beat(context: Dictionary), advance, is_complete, get_current_beat, get_current_index, update, on_signal_received
- [ ] T3.2: Create `tests/unit/scene_director/test_beat_runner.gd` - Start initializes with beat list at index 0, INSTANT beats auto-advance after effect execution, TIMED beats advance after duration elapsed via update(delta), SIGNAL beats advance on matching event, precondition gating skips beat effects when conditions fail (condition.evaluate(context) returns 0.0), is_complete returns true when all beats done, empty beat list is immediately complete. Context must include {"state_store": mock_store, "redux_state": {}} for tests.
- [ ] T3.3: Run tests -- confirm they FAIL (red)
- [ ] T3.4: Implement U_BeatRunner -- state machine with current index tracking, wait mode handling, precondition evaluation via condition.evaluate(context) loop, effect execution via effect.execute(context) loop. Beat conditions should use RS_ConditionReduxField/RS_ConditionEventPayload/RS_ConditionConstant subclasses.
- [ ] T3.5: Run tests -- confirm they PASS (green)

### 3B: M_SceneDirector (TDD)

- [ ] T3.6: Create stub `scripts/managers/m_scene_director.gd` (M_SceneDirector extends Node) - @export state_store, @export directives, empty methods for _select_directive, _start_directive, _on_directive_complete, _build_context
- [ ] T3.7: Create `tests/unit/scene_director/test_scene_director.gd` - Directive selection picks highest priority matching scene + conditions (conditions evaluated via condition.evaluate(context)), beat execution ticks via _physics_process for TIMED, signal advancement for SIGNAL beats, directive completion dispatches complete action + publishes event, no directive selected for scene with no matching directives. Context must include {"state_store": mock_store, "redux_state": {}}. SIGNAL subscription tests: event subscriptions created on directive start (only for events referenced by SIGNAL beats), cleaned up on directive complete, cleaned up on reset.
- [ ] T3.8: Run tests -- confirm they FAIL (red)
- [ ] T3.9: Implement M_SceneDirector -- store discovery, _build_context() returns {"state_store": _store, "redux_state": _store.get_state()}, directive selection (evaluate selection_conditions via condition.evaluate(context) loop), beat runner lifecycle, _physics_process ticking with _build_context(), event subscription for signals (merges event payload into context)
- [ ] T3.10: Run tests -- confirm they PASS (green)

### 3C: Regression Check

- [ ] T3.11: Run full existing test suite -- zero regressions
- [ ] T3.12: Update continuation prompt with Phase 3 status

**Phase 3 Commit**: Scene director core with beat runner and directive selection

---

## Phase 4: Victory Migration (TDD)

### 4A: Victory Objective Resources

- [ ] T4.1: Create `resources/scene_director/objectives/cfg_obj_level_complete.tres` (RS_ObjectiveDefinition) - STANDARD type, `auto_activate: true` (objective activates immediately when the set is loaded in _ready(), NOT when an area completes — auto_activate means "skip the inactive state on load"). Conditions: `RS_ConditionReduxField` checking `gameplay.completed_areas`. No completion_effects needed.
- [ ] T4.2: Create `resources/scene_director/objectives/cfg_obj_game_complete.tres` (RS_ObjectiveDefinition) - VICTORY type, `dependencies: [&"level_complete"]`, conditions: `RS_ConditionReduxField` checking required final area in completed_areas. `completion_effects: [RS_EffectDispatchAction: game_complete]`. `completion_event_payload: {"target_scene": StringName("victory")}` — M_ObjectivesManager reads this and includes it as the `EVENT_OBJECTIVE_VICTORY_TRIGGERED` event payload; M_SceneManager reads `event.payload.get("target_scene")` for the transition.
- [ ] T4.3: Create `resources/scene_director/sets/cfg_objset_default.tres` (RS_ObjectiveSet) - default progression set containing level_complete + game_complete objectives

### 4B: M_ObjectivesManager Victory Flow

- [ ] T4.4: Wire M_ObjectivesManager to subscribe to `victory_executed` event from S_VictoryHandlerSystem
- [ ] T4.5: Implement VICTORY objective completion in M_ObjectivesManager: after `completion_effects` execute via `effect.execute(context)`, read `objective.completion_event_payload` and publish `EVENT_OBJECTIVE_VICTORY_TRIGGERED` with that dict as the event payload (e.g., `{"target_scene": StringName("victory")}`). M_SceneManager receives the event and reads `event.payload.get("target_scene")` for the transition target.
- [ ] T4.6: Wire M_ObjectivesManager to subscribe to `action_dispatched` for `gameplay/mark_area_complete` actions to evaluate objective conditions

### 4C: M_SceneManager Refactor

- [ ] T4.7: Remove `_on_victory_executed()` handler from M_SceneManager (lines 323-331)
- [ ] T4.8: Remove `_get_victory_target_scene()` method from M_SceneManager (lines 334-339)
- [ ] T4.9: Remove `_victory_executed_unsubscribe` variable, subscription, and cleanup from M_SceneManager (lines 153, 212, 294-295)
- [ ] T4.10: Remove `C_VICTORY_TRIGGER_COMPONENT` preload from M_SceneManager (line 36)
- [ ] T4.11: Add subscription to `EVENT_OBJECTIVE_VICTORY_TRIGGERED` in M_SceneManager
- [ ] T4.12: Implement `_on_objective_victory(event)` in M_SceneManager -- read target_scene from event payload, call transition_to_scene

### 4D: Scene Integration

- [ ] T4.13: Add M_ObjectivesManager node to `scenes/root.tscn` under Managers
- [ ] T4.14: Register M_ObjectivesManager in `root.gd` ServiceLocator with dependency on state_store
- [ ] T4.15: Wire default objective set to M_ObjectivesManager in root.tscn

### 4E: Tests

- [ ] T4.16: Create `tests/unit/scene_director/test_victory_migration.gd` - Victory objective completion triggers EVENT_OBJECTIVE_VICTORY_TRIGGERED, game_complete prerequisite still enforced via objective dependencies, M_SceneManager no longer subscribes to victory_executed
- [ ] T4.17: Create `tests/integration/scene_director/test_objectives_integration.gd` - End-to-end: victory_executed event -> M_ObjectivesManager evaluates objectives -> VICTORY objective completes -> objective_victory_triggered published -> M_SceneManager transitions

### 4F: Save Migration

- [ ] T4.18: Add save migration to `U_SaveMigrationEngine` — inject empty objectives slice (`{statuses: {}, active_set_id: "", event_log: []}`) into saves missing it
- [ ] T4.19: Implement status reconciliation in M_ObjectivesManager.load_objective_set() — apply saved statuses to loaded resource definitions, discard orphaned statuses for objectives no longer in the set
- [ ] T4.20: Test save migration + reconciliation — old save loads cleanly, statuses preserved for matching objectives, orphaned statuses discarded

### 4G: Verification

- [ ] T4.21: Run full existing test suite -- verify behavioral equivalence
- [ ] T4.22: Run scene director unit tests
- [ ] T4.23: Manual playtest: checkpoint, victory (level + game complete), verify transitions work
- [ ] T4.24: Update continuation prompt with Phase 4 status

**Phase 4 Commit**: Victory transitions migrated from M_SceneManager to objectives

---

## Phase 5: Scene Director Integration

### 5A: Directive Resources

- [ ] T5.1: Create `resources/scene_director/directives/cfg_directive_gameplay_base.tres` (RS_SceneDirective) - target_scene_id: "gameplay_base", basic introductory beats

### 5B: Scene Integration

- [ ] T5.2: Add M_SceneDirector node to `scenes/root.tscn` under Managers
- [ ] T5.3: Register M_SceneDirector in `root.gd` ServiceLocator with dependencies on state_store and objectives_manager
- [ ] T5.4: Wire directives to M_SceneDirector in root.tscn

### 5C: Tests

- [ ] T5.5: Create `tests/integration/scene_director/test_scene_director_integration.gd` - Scene load triggers directive selection, beats execute in order, directive completes and publishes event

### 5D: Verification

- [ ] T5.6: Run full test suite
- [ ] T5.7: Update continuation prompt with Phase 5 status

**Phase 5 Commit**: Scene director integrated with scene flow

---

## Phase 6: Cleanup + Verification

### 6A: Project-Level Updates

- [ ] T6.1: Update `AGENTS.md` with Scene Director / Objectives Manager patterns section
- [ ] T6.2: Update `docs/general/DEV_PITFALLS.md` with any new pitfalls discovered

### 6B: Final Verification

- [ ] T6.3: Run full test suite (ECS + QB + Scene Director + Style)
- [ ] T6.4: Manual playtest: full gameplay loop (walk, checkpoint, victory, game complete, beat sequences)

**Phase 6 Commit**: Cleanup and final verification
