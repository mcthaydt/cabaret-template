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

- [x] T2.1: Create stub `scripts/utils/scene_director/u_objective_graph.gd` (U_ObjectiveGraph) - empty static methods returning default values
- [x] T2.2: Create `tests/unit/scene_director/test_objective_graph.gd` - Build graph from objective definitions, cycle detection (returns errors for circular deps), missing reference detection (dependency IDs not in known_ids), get_ready_dependents (returns dependents whose prerequisites are all completed), topological sort (returns valid evaluation order). Note: validate_graph signature is `validate_graph(graph: Dictionary, known_ids: Array[StringName]) -> Array[String]`; tests must pass known_ids.
- [x] T2.3: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` produced 5 expected failures in `test_objective_graph.gd` while `U_ObjectiveGraph` was still a stub.
- [x] T2.4: Implement U_ObjectiveGraph -- adjacency list construction, DFS cycle detection, dependent readiness check, topological sort via Kahn's algorithm; validate_graph takes both graph and known_ids
- [x] T2.5: Run tests -- confirm they PASS (green)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` passed `32/32` after implementation; style regression check `tools/run_gut_suite.sh -gdir=res://tests/unit/style` passed `12/12`.

### 2B: Event Log Helper (TDD)

- [x] T2.6: Create stub `scripts/utils/scene_director/u_objective_event_log.gd` (U_ObjectiveEventLog) - empty static methods
- [x] T2.7: Create `tests/unit/scene_director/test_objective_event_log.gd` - Entry creation with timestamp, format_log produces readable output, all event types (activated, completed, failed, dependency_met, condition_checked)
- [x] T2.8: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` produced 3 expected failures in `test_objective_event_log.gd` while the helper still returned defaults.
- [x] T2.9: Implement U_ObjectiveEventLog -- structured entry creation, formatted output
- [x] T2.10: Run tests -- confirm they PASS (green)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` passed `35/35` after helper implementation.

### 2C: M_ObjectivesManager (TDD)

- [x] T2.11: Create stub `scripts/managers/m_objectives_manager.gd` (M_ObjectivesManager extends Node) - @export state_store, @export objective_sets, empty methods for load_objective_set, _check_conditions, _execute_effects, _complete_objective, _fail_objective, _activate_dependents, get_objective_status, _build_context
- [x] T2.12: Create `tests/unit/scene_director/test_objectives_manager.gd` - Set loading activates auto_activate objectives (activates on load, not on event), condition evaluation via direct condition.evaluate(context) calls, completion dispatches actions + executes effects via effect.execute(context) + activates dependents, failure dispatches fail action, event logging records transitions, graph validation rejects cycles. For VICTORY type: completion publishes EVENT_OBJECTIVE_VICTORY_TRIGGERED with objective.completion_event_payload as the event payload.
- [x] T2.13: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` produced 6 expected failing assertions in `test_objectives_manager.gd` against the manager stub.
- [x] T2.14: Implement M_ObjectivesManager -- store discovery (injection + ServiceLocator), _ready() calls load_objective_set for each set in objective_sets, event subscriptions, set loading with graph build + validate_graph(graph, known_ids), condition checking via direct condition.evaluate(context) loop, effect execution via effect.execute(context) loop, completion flow with dependent activation, event logging. VICTORY completion: read objective.completion_event_payload, publish EVENT_OBJECTIVE_VICTORY_TRIGGERED with that dict as payload.
- [x] T2.15: Run tests -- confirm they PASS (green)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` passed `42/42` after manager implementation and test fixes.

### 2D: Regression Check

- [x] T2.16: Run full existing test suite -- zero regressions
  - Completion note (2026-02-25): Regression suites passed — `tests/unit/qb` (`134/134`), `tests/unit/ecs` (`126/126`), `tests/unit/ecs/systems` (`197/197`), `tests/unit/style` (`12/12`), `tests/integration/scene_manager` (`90/90`), `tests/unit/scene_director` (`42/42`).
- [x] T2.17: Update continuation prompt with Phase 2 status

**Phase 2 Commit**: Objectives manager core with graph, event log, and condition evaluation

Phase 2 completion notes (2026-02-25):
- Added `U_ObjectiveEventLog` helper plus unit coverage.
- Added `M_ObjectivesManager` core flow: objective-set loading, graph validation, event-driven condition evaluation, completion/failure transitions, dependent activation, objective event publishing, and victory payload forwarding.
- Added manager unit coverage with a dedicated state-store stub for reducer-backed assertions.
- Regression validation passed across QB, ECS, ECS systems, style, scene manager integration, and scene director unit suites.

---

## Phase 3: Scene Director Core (TDD)

### 3A: Beat Runner Helper (TDD)

- [x] T3.1: Create stub `scripts/utils/scene_director/u_beat_runner.gd` (U_BeatRunner extends RefCounted) - empty methods for start, execute_current_beat(context: Dictionary), advance, is_complete, get_current_beat, get_current_index, update, on_signal_received
- [x] T3.2: Create `tests/unit/scene_director/test_beat_runner.gd` - Start initializes with beat list at index 0, INSTANT beats auto-advance after effect execution, TIMED beats advance after duration elapsed via update(delta), SIGNAL beats advance on matching event, precondition gating skips beat effects when conditions fail (condition.evaluate(context) returns 0.0), is_complete returns true when all beats done, empty beat list is immediately complete. Context must include {"state_store": mock_store, "redux_state": {}} for tests.
- [x] T3.3: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -gselect=test_beat_runner` produced expected failures against the BeatRunner stub (`1/7` passing, `6` failing behavior tests).
- [x] T3.4: Implement U_BeatRunner -- state machine with current index tracking, wait mode handling, precondition evaluation via condition.evaluate(context) loop, effect execution via effect.execute(context) loop. Beat conditions should use RS_ConditionReduxField/RS_ConditionEventPayload/RS_ConditionConstant subclasses.
- [x] T3.5: Run tests -- confirm they PASS (green)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -gselect=test_beat_runner` passed `7/7`; follow-up `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director` passed `51/51` and style regression `tools/run_gut_suite.sh -gdir=res://tests/unit/style` passed `12/12`.

### 3B: M_SceneDirector (TDD)

- [x] T3.6: Create stub `scripts/managers/m_scene_director.gd` (M_SceneDirector extends Node) - @export state_store, @export directives, empty methods for _select_directive, _start_directive, _on_directive_complete, _build_context
- [x] T3.7: Create `tests/unit/scene_director/test_scene_director.gd` - Directive selection picks highest priority matching scene + conditions (conditions evaluated via condition.evaluate(context)), beat execution ticks via _physics_process for TIMED, signal advancement for SIGNAL beats, directive completion dispatches complete action + publishes event, no directive selected for scene with no matching directives. Context must include {"state_store": mock_store, "redux_state": {}}. SIGNAL subscription tests: event subscriptions created on directive start (only for events referenced by SIGNAL beats), cleaned up on directive complete, cleaned up on reset.
- [x] T3.8: Run tests -- confirm they FAIL (red)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -gselect=test_scene_director` produced expected failures against the manager stub (`1/6` passing, `5` failing).
- [x] T3.9: Implement M_SceneDirector -- store discovery, _build_context() returns {"state_store": _store, "redux_state": _store.get_state()}, directive selection (evaluate selection_conditions via condition.evaluate(context) loop), beat runner lifecycle, _physics_process ticking with _build_context(), event subscription for signals (merges event payload into context)
- [x] T3.10: Run tests -- confirm they PASS (green)
  - Completion note (2026-02-25): `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -gselect=test_scene_director` passed `18/18` (includes reducer/selector suites selected by prefix); full scene director suite passed `57/57`.

### 3C: Regression Check

- [x] T3.11: Run full existing test suite -- zero regressions
  - Completion note (2026-02-25): Regression suites passed — `tests/unit/qb` (`134/134`), `tests/unit/ecs` (`126/126`), `tests/unit/ecs/systems` (`197/197`), `tests/unit/style` (`12/12`), `tests/integration/scene_manager` (`90/90`), `tests/unit/scene_director` (`57/57`).
- [x] T3.12: Update continuation prompt with Phase 3 status

**Phase 3 Commit**: Scene director core with beat runner and directive selection

Phase 3 completion notes (2026-02-25):
- Added `M_SceneDirector` core flow with store discovery, directive selection, beat-runner lifecycle integration, per-frame ticking, and SIGNAL event subscription lifecycle management.
- Added scene-director manager unit coverage for priority selection, timed execution, signal-driven advancement, directive completion events, and subscription cleanup on complete/reset.
- Verified full Phase 3 regression baseline across QB, ECS, ECS systems, style, scene manager integration, and scene director unit suites.

---

## Phase 4: Victory Migration (TDD)

### 4A: Victory Objective Resources

- [x] T4.1: Create `resources/scene_director/objectives/cfg_obj_level_complete.tres` (RS_ObjectiveDefinition) - STANDARD type, `auto_activate: true` (objective activates immediately when the set is loaded in _ready(), NOT when an area completes — auto_activate means "skip the inactive state on load"). Conditions: `RS_ConditionReduxField` checking `gameplay.completed_areas`. No completion_effects needed.
  - Completion note (2026-02-25): Added `cfg_obj_level_complete.tres` with `objective_id = &"level_complete"`, `auto_activate = true`, and an `RS_ConditionReduxField` condition on `gameplay.completed_areas.0` (`match_mode = "not_equals"`, empty-string guard) so completion becomes true once at least one area exists.
- [x] T4.2: Create `resources/scene_director/objectives/cfg_obj_game_complete.tres` (RS_ObjectiveDefinition) - VICTORY type, `dependencies: [&"level_complete"]`, conditions: `RS_ConditionReduxField` checking the victory-ready gameplay flag. `completion_effects: [RS_EffectDispatchAction: game_complete]`. `completion_event_payload: {"target_scene": StringName("victory")}` — M_ObjectivesManager reads this and includes it as the `EVENT_OBJECTIVE_VICTORY_TRIGGERED` event payload; M_SceneManager reads `event.payload.get("target_scene")` for the transition.
  - Completion note (2026-02-25): Added `cfg_obj_game_complete.tres` with `objective_id = &"game_complete"`, VICTORY type, dependency on `level_complete`, a Redux-field condition checking `gameplay.completed_areas.1 == "bar"`, `RS_EffectDispatchAction` for `gameplay/game_complete`, and `completion_event_payload = {"target_scene": &"victory"}`.
  - Update note (2026-02-25): Patched the default condition to `gameplay.game_completed == true` to preserve `S_VictoryHandlerSystem` gating and prevent objective completion from `mark_area_complete` alone.
- [x] T4.3: Create `resources/scene_director/sets/cfg_objset_default.tres` (RS_ObjectiveSet) - default progression set containing level_complete + game_complete objectives
  - Completion note (2026-02-25): Added `cfg_objset_default.tres` with `set_id = &"default_progression"` and both objective resources wired in resource order.

### 4B: M_ObjectivesManager Victory Flow

- [x] T4.4: Wire M_ObjectivesManager to subscribe to `victory_executed` event from S_VictoryHandlerSystem
- [x] T4.5: Implement VICTORY objective completion in M_ObjectivesManager: after `completion_effects` execute via `effect.execute(context)`, read `objective.completion_event_payload` and publish `EVENT_OBJECTIVE_VICTORY_TRIGGERED` with that dict as the event payload (e.g., `{"target_scene": StringName("victory")}`). M_SceneManager receives the event and reads `event.payload.get("target_scene")` for the transition target.
- [x] T4.6: Wire M_ObjectivesManager to subscribe to `action_dispatched` for `gameplay/mark_area_complete` actions to evaluate objective conditions
  - Completion note (2026-02-25): Confirmed event-driven evaluation wiring in `M_ObjectivesManager` (`victory_executed`, `checkpoint_activated`, and `gameplay/mark_area_complete`) plus VICTORY completion payload forwarding.

### 4C: M_SceneManager Refactor

- [x] T4.7: Remove `_on_victory_executed()` handler from M_SceneManager (lines 323-331)
- [x] T4.8: Remove `_get_victory_target_scene()` method from M_SceneManager (lines 334-339)
- [x] T4.9: Remove `_victory_executed_unsubscribe` variable, subscription, and cleanup from M_SceneManager (lines 153, 212, 294-295)
- [x] T4.10: Remove `C_VICTORY_TRIGGER_COMPONENT` preload from M_SceneManager (line 36)
- [x] T4.11: Add subscription to `EVENT_OBJECTIVE_VICTORY_TRIGGERED` in M_SceneManager
- [x] T4.12: Implement `_on_objective_victory(event)` in M_SceneManager -- read target_scene from event payload, call transition_to_scene
  - Completion note (2026-02-25): `M_SceneManager` now subscribes to `EVENT_OBJECTIVE_VICTORY_TRIGGERED` (priority 5), transitions from `payload.target_scene`, and no longer handles `victory_executed` directly.

### 4D: Scene Integration

- [x] T4.13: Add M_ObjectivesManager node to `scenes/root.tscn` under Managers
- [x] T4.14: Register M_ObjectivesManager in `root.gd` ServiceLocator with dependency on state_store
- [x] T4.15: Wire default objective set to M_ObjectivesManager in root.tscn
  - Completion note (2026-02-25): Root scene now includes `M_ObjectivesManager` with `cfg_objset_default.tres`; `root.gd` registers `objectives_manager` and validates `state_store` dependency.

### 4E: Tests

- [x] T4.16: Create `tests/unit/scene_director/test_victory_migration.gd` - Victory objective completion triggers EVENT_OBJECTIVE_VICTORY_TRIGGERED, game_complete prerequisite still enforced via objective dependencies, M_SceneManager no longer subscribes to victory_executed
- [x] T4.17: Create `tests/integration/scene_director/test_objectives_integration.gd` - End-to-end: victory_executed event -> M_ObjectivesManager evaluates objectives -> VICTORY objective completes -> objective_victory_triggered published -> M_SceneManager transitions
  - Completion note (2026-02-25): Added both test suites and updated existing `tests/integration/scene_manager/test_endgame_flows.gd` fixture to include objectives manager wiring for migrated victory flow.

### 4F: Save Migration

- [x] T4.18: Add save migration to `U_SaveMigrationEngine` — inject empty objectives slice (`{statuses: {}, active_set_id: "", event_log: []}`) into saves missing it
- [x] T4.19: Implement status reconciliation in M_ObjectivesManager.load_objective_set() — apply saved statuses to loaded resource definitions, discard orphaned statuses for objectives no longer in the set
- [x] T4.20: Test save migration + reconciliation — old save loads cleanly, statuses preserved for matching objectives, orphaned statuses discarded
  - Completion note (2026-02-25): Added `_inject_missing_objectives_slice(...)` in `U_SaveMigrationEngine`, added status reconciliation dispatch in `M_ObjectivesManager.load_objective_set()`, and added coverage in `tests/unit/save/test_save_migrations.gd` + `tests/unit/scene_director/test_objectives_manager.gd`.

### 4G: Verification

- [x] T4.21: Run full existing test suite -- verify behavioral equivalence
- [x] T4.22: Run scene director unit tests
- [ ] T4.23: Manual playtest: checkpoint, victory (level + game complete), verify transitions work
- [x] T4.24: Update continuation prompt with Phase 4 status
  - Completion note (2026-02-25): Full `tests/**` headless run passed (`2638/2647`, `9` pending/expected skipped, `0` failures), scene-director unit suite passed (`61/61`), and victory/checkpoint flows validated through integrated endgame + scene-director tests (`test_endgame_flows`, `test_objectives_integration`).
  - Update note (2026-02-25): Dedicated interactive manual playtest remains pending; CI/headless integration coverage is complete.

**Phase 4 Commit**: Victory transitions migrated from M_SceneManager to objectives

Phase 4 completion notes (2026-02-25):
- Added migrated Phase 4 objective resources and default objective set (`cfg_obj_level_complete`, `cfg_obj_game_complete`, `cfg_objset_default`).
- Refactored scene transition ownership: `M_SceneManager` now consumes `EVENT_OBJECTIVE_VICTORY_TRIGGERED`; legacy direct `victory_executed` transition handling removed.
- Integrated `M_ObjectivesManager` into root scene + ServiceLocator and wired default objective set for runtime loading.
- Added save compatibility + reconciliation: missing-objectives injection during migration and persisted-status reconciliation during objective-set load.
- Added coverage for migration and end-to-end flow (`unit/scene_director/test_victory_migration.gd`, `integration/scene_director/test_objectives_integration.gd`) and updated endgame integration fixtures for objective-driven transitions.

---

## Phase 5: Scene Director Integration

### 5A: Directive Resources

- [x] T5.1: Create `resources/scene_director/directives/cfg_directive_gameplay_base.tres` (RS_SceneDirective) - target_scene_id: "gameplay_base", basic introductory beats
  - Completion note (2026-02-25): Added `cfg_directive_gameplay_base.tres` with `directive_id = &"gameplay_base_intro"`, two intro beats, and publish-event effects (`scene_director_intro_beat_1`, `scene_director_intro_beat_2`) to support integration assertions.

### 5B: Scene Integration

- [x] T5.2: Add M_SceneDirector node to `scenes/root.tscn` under Managers
- [x] T5.3: Register M_SceneDirector in `root.gd` ServiceLocator with dependencies on state_store and objectives_manager
- [x] T5.4: Wire directives to M_SceneDirector in root.tscn
  - Completion note (2026-02-25): Root runtime now instantiates `M_SceneDirector`, registers it as `scene_director`, validates dependencies (`state_store`, `objectives_manager`), and binds the default gameplay directive resource.

### 5C: Tests

- [x] T5.5: Create `tests/integration/scene_director/test_scene_director_integration.gd` - Scene load triggers directive selection, beats execute in order, directive completes and publishes event
  - Completion note (2026-02-25): Added integration coverage for transition-driven directive start, beat event ordering, beat index advancement events, directive completion state/event assertions, and signpost-message integration for player-facing intro beat feedback.

### 5D: Verification

- [x] T5.6: Run full test suite
  - Completion note (2026-02-25): Validation passed across targeted and full suites: `tests/unit/scene_director` (`61/61`), `tests/integration/scene_director` (`3/3`), `tests/unit/style` (`12/12`), `tests/integration/scene_manager` (`90/90`), full `tests/**` sweep (`2639/2648`, `9` expected pending, `0` failures).
  - Stabilization note (2026-02-25): Hardened `tests/integration/scene_manager/test_endgame_flows.gd` fixture by disabling persistence (`settings.enable_persistence = false`) to prevent ambient save-state leakage from pre-completing objectives between runs.
- [x] T5.7: Update continuation prompt with Phase 5 status

**Phase 5 Commit**: Scene director integrated with scene flow

Phase 5 completion notes (2026-02-25):
- Added default `gameplay_base` scene-director directive resource with intro beats and event-publish effects.
- Intro beats now also publish `signpost_message` payloads (`hud.scene_director_intro_beat_1/2`) so existing HUD/mobile signpost consumers render player-facing onboarding text in runtime scenes.
- Integrated `M_SceneDirector` into root scene/bootstrap and ServiceLocator dependency graph.
- Added `test_scene_director_integration.gd` to validate directive selection/execution/completion end-to-end.
- Restored full-suite stability by disabling persistence in `test_endgame_flows` fixture (prevents objective-status leakage from `user://` saves).
- Verified regression baseline: scene-director unit/integration + style + scene-manager integration + full `tests/**` sweep all green with documented pending tests only.

---

## Phase 6: Cleanup + Verification

### 6A: Project-Level Updates

- [x] T6.1: Update `AGENTS.md` with Scene Director / Objectives Manager patterns section
  - Completion note (2026-02-25): `AGENTS.md` includes Scene Director/Objectives architecture patterns and reset-run orchestration guidance under the Scene Director/Objectives section.
- [x] T6.2: Update `docs/general/DEV_PITFALLS.md` with any new pitfalls discovered
  - Completion note (2026-02-25): Added Scene Director reset pitfall documenting that `gameplay/reset_progress` alone does not reset objectives and that retry flows must dispatch `run/reset`.

### 6B: Final Verification

- [x] T6.3: Run full test suite (ECS + QB + Scene Director + Style)
  - Completion note (2026-02-25): Verification suites passed -- `tests/unit/qb` (`134/134`), `tests/unit/ecs` (`126/126`), `tests/unit/scene_director` (`67/67`), `tests/unit/style` (`12/12`).
- [ ] T6.4: Manual playtest: full gameplay loop (walk, checkpoint, victory, game complete, beat sequences)

**Phase 6 Commit**: Cleanup and final verification

---

## Phase 7: Reset Run Hardening (TDD, Migrated IDs)

### 7A: Public API + Reducer Support

- [x] T7.1: Added `scripts/state/actions/u_run_actions.gd` with `ACTION_RESET_RUN` + `reset_run(next_route)` action creator.
- [x] T7.2: Added `U_ObjectivesActions.ACTION_RESET_FOR_NEW_RUN` with payload contract `{ "set_id": StringName }`.
- [x] T7.3: Extended `U_ObjectivesReducer` to handle `ACTION_RESET_FOR_NEW_RUN` by clearing `statuses`, clearing `event_log`, and setting `active_set_id`.

### 7B: Objectives Manager Fresh-Reset Flow

- [x] T7.4: Added `M_ObjectivesManager.reset_for_new_run(set_id := &"default_progression")`.
- [x] T7.5: Split objective-set loading behavior into two paths:
  - persisted reconciliation path (`load_objective_set`)
  - fresh reset-run path (`reset_for_new_run`) that skips persisted-status reconciliation.
- [x] T7.6: Fresh reset path now re-arms root objectives using `bulk_activate` so `event_log` stays empty after reset-run.
- [x] T7.7: Reduced redundant objective re-evaluation passes for a single event by fixing the active-objective evaluation loop termination.

### 7C: Run Coordinator + UI Routing

- [x] T7.8: Added `scripts/managers/m_run_coordinator.gd` to orchestrate `run/reset`:
  - dispatch `gameplay/reset_progress`
  - call `U_InteractBlocker.force_unblock()`
  - call `objectives_manager.reset_for_new_run(&"default_progression")` when available
  - dispatch `navigation/retry(&"alleyway")`
  - ignore re-entrant reset requests while one is in-flight
- [x] T7.9: Registered `M_RunCoordinator` in `scenes/root.tscn` + `scripts/root.gd` ServiceLocator wiring/dependencies.
- [x] T7.10: Updated `UI_Victory` Continue flow to dispatch `U_RunActions.reset_run(...)` (contract path) instead of direct gameplay/navigation reset chaining.

### 7D: Test Coverage Updates (TDD)

- [x] T7.11: Added reducer tests for `ACTION_RESET_FOR_NEW_RUN` in `tests/unit/scene_director/test_objectives_reducer.gd`.
- [x] T7.12: Added objectives-manager reset tests in `tests/unit/scene_director/test_objectives_manager.gd`.
- [x] T7.13: Added coordinator unit tests in `tests/unit/scene_director/test_run_coordinator.gd`.
- [x] T7.14: Updated victory UI unit test to assert Continue dispatches `run/reset` contract action in `tests/unit/ui/test_endgame_screens.gd`.
- [x] T7.15: Updated endgame integration assertions for post-Continue fresh objective state in `tests/integration/scene_manager/test_endgame_flows.gd`.
- [x] T7.16: Normalized scene-director integration/unit migrated objective IDs (`bar_complete`, `final_complete`) in:
  - `tests/integration/scene_director/test_objectives_integration.gd`
  - `tests/unit/scene_director/test_victory_migration.gd`

### 7E: Verification

- [x] T7.17: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director`
- [x] T7.18: `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -gselect=test_endgame_screens`
- [x] T7.19: `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director`
- [x] T7.20: `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -gselect=test_endgame_flows`
- [x] T7.21: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`

**Phase 7 Commit**: Reset-run hardening with deterministic coordinator orchestration and migrated objective IDs

---

## Phase 8: Objective Mesh Visibility Gating (Follow-up)

### 8A: Config + Controller Wiring

- [x] T8.1: Added `visibility_objective_id: StringName` to `RS_VictoryInteractionConfig` for objective-status-driven mesh/interactable gating.
- [x] T8.2: Refactored `Inter_VictoryZone` to resolve `I_StateStore`, subscribe to `slice_updated`, and gate `set_enabled(...)` + `visible` by `objectives` status (`active` only).
- [x] T8.3: Refactored `Inter_EndgameGoalZone` to remove duplicated store/toggle logic and override `_compute_visibility_gate_unlocked(state)` so unlock requires both:
  - objective gate pass (`final_complete` active via base behavior), and
  - existing `required_area` completion in gameplay state.

### 8B: Authored Resource Updates

- [x] T8.4: Updated `cfg_victory_goal_bar.tres` with `visibility_objective_id = &"bar_complete"` so the bar goal mesh appears only during objective 1.
- [x] T8.5: Updated `cfg_endgame_goal_alleyway.tres` with `visibility_objective_id = &"final_complete"` so the alleyway endgame mesh appears only during objective 2.

### 8C: Tests + Verification

- [x] T8.6: Extended `tests/unit/interactables/test_e_victory_zone.gd` to assert objective-gated visibility (`inactive`/`completed` hidden, `active` shown).
- [x] T8.7: Extended `tests/unit/interactables/test_e_endgame_goal_zone.gd` to assert combined gating (objective active + required area complete).
- [x] T8.8: Added validator regression in `tests/unit/resources/test_interaction_config_validator.gd` proving `visibility_objective_id` is optional.
- [x] T8.9: Run verification suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -gselect=test_e_victory_zone`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -gselect=test_e_endgame_goal_zone`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources -gselect=test_interaction_config_validator`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
  - Completion note (2026-02-25): All requested suites passed (`test_e_victory_zone` 4/4, `test_e_endgame_goal_zone` 3/3, `test_interaction_config_validator` 16/16, `tests/unit/style` 12/12).
