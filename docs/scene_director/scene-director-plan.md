# Scene Director - Implementation Plan

## Phase 1: State Infrastructure

**Goal**: Resources + Redux slices for objectives and scene director. No behavioral change -- pure data layer.

### 1A: Objective Resources

**RS_ObjectiveDefinition** (`scripts/resources/scene_director/rs_objective_definition.gd`):
- `objective_id: StringName`
- `description: String`
- `objective_type: ObjectiveType` enum (STANDARD, VICTORY, CHECKPOINT)
  - Note: `CHECKPOINT` type is defined for future use; behavior is **not implemented in Phase 1-6**. The enum value must exist so resources can be authored, but M_ObjectivesManager treats CHECKPOINT the same as STANDARD until a later phase adds save-trigger behavior.
- `conditions: Array[Resource]` -- v2 typed conditions. Use `RS_ConditionReduxField`, `RS_ConditionEventPayload`, or `RS_ConditionConstant` subclasses (no `RS_ConditionComponentField` — no per-entity context at manager level)
- `completion_effects: Array[Resource]` -- v2 typed effects. Use `RS_EffectDispatchAction`, `RS_EffectPublishEvent`, `RS_EffectSetContextValue`, etc.
- `completion_event_payload: Dictionary = {}` -- arbitrary data merged into the published completion event. Enables type-specific data without type-specific fields (e.g., VICTORY objectives set `{"target_scene": StringName("victory")}`).
- `dependencies: Array[StringName]` -- objective IDs that must be completed first
- `auto_activate: bool = false` -- activate immediately when set loads (regardless of dependencies; use for root-level objectives that have no prerequisites)

**RS_ObjectiveSet** (`scripts/resources/scene_director/rs_objective_set.gd`):
- `set_id: StringName`
- `description: String`
- `objectives: Array[Resource]` -- entries should be `RS_ObjectiveDefinition`

### 1B: Scene Director Resources

**RS_BeatDefinition** (`scripts/resources/scene_director/rs_beat_definition.gd`):
- `beat_id: StringName`
- `description: String`
- `preconditions: Array[Resource]` -- v2 typed conditions that gate beat execution
- `effects: Array[Resource]` -- v2 typed effects that fire when beat runs
- `wait_mode: WaitMode` enum (INSTANT, TIMED, SIGNAL)
- `duration: float = 0.0` -- for TIMED wait mode
- `wait_event: StringName = &""` -- for SIGNAL wait mode

**RS_SceneDirective** (`scripts/resources/scene_director/rs_scene_directive.gd`):
- `directive_id: StringName`
- `description: String`
- `target_scene_id: StringName` -- which scene this directive applies to
- `selection_conditions: Array[Resource]` -- v2 typed conditions for selecting this directive
- `priority: int = 0` -- higher priority directives checked first
- `beats: Array[Resource]` -- entries should be `RS_BeatDefinition`

### 1C: Redux Slices -- Objectives

**Actions** (`scripts/state/actions/u_objectives_actions.gd`):
- `activate(objective_id)`, `complete(objective_id)`, `fail(objective_id)`
- `set_active_set(set_id)`, `log_event(event_data)`
- `reset_all()`, `bulk_activate(objective_ids)`

**Reducer** (`scripts/state/reducers/u_objectives_reducer.gd`):
- Handles objectives slice mutations (status transitions, event log append)

**Selectors** (`scripts/state/selectors/u_objectives_selectors.gd`):
- `get_objective_status(state, objective_id)`, `get_active_objectives(state)`
- `is_completed(state, objective_id)`, `get_event_log(state)`
- `get_active_set_id(state)`

**Initial State** (`scripts/resources/state/rs_objectives_initial_state.gd`):
- `statuses: Dictionary = {}` -- objective_id -> status string
- `active_set_id: StringName = &""`
- `event_log: Array = []`

### 1D: Redux Slices -- Scene Director

**Actions** (`scripts/state/actions/u_scene_director_actions.gd`):
- `start_directive(directive_id)`, `advance_beat()` (no parameter — reducer increments index by 1)
- `complete_directive()`, `reset()`

**Reducer** (`scripts/state/reducers/u_scene_director_reducer.gd`):
- Handles scene_director slice mutations
- `advance_beat`: increments `current_beat_index` by 1 (does not accept an index from the caller)

**Selectors** (`scripts/state/selectors/u_scene_director_selectors.gd`):
- `get_active_directive_id(state)`, `get_current_beat_index(state)`
- `is_running(state)`, `get_director_state(state)`

**Initial State** (`scripts/resources/state/rs_scene_director_initial_state.gd`):
- `active_directive_id: StringName = &""`
- `current_beat_index: int = -1`
- `state: String = "idle"` -- idle, running, completed

### 1E: Slice Registration

- Add objectives and scene_director slices to `U_StateSliceManager.initialize_slices()`
- Add `@export` fields to `M_StateStore` for new initial state resources
- Objectives slice: persistent (saved/loaded) — no `is_transient`, no `transient_fields`
- Scene director slice: fully transient — register with `is_transient = true` (same pattern as the `navigation` slice). All three fields are runtime-only state; nothing persists across saves.

### 1F: Event Constants

Add to `U_ECSEventNames`:
```
EVENT_OBJECTIVE_ACTIVATED, EVENT_OBJECTIVE_COMPLETED, EVENT_OBJECTIVE_FAILED
EVENT_OBJECTIVE_VICTORY_TRIGGERED
EVENT_DIRECTIVE_STARTED, EVENT_DIRECTIVE_COMPLETED, EVENT_BEAT_ADVANCED
```

### 1G: Tests + Regression + Commit

| Test File | Coverage |
|-----------|----------|
| `tests/unit/scene_director/test_objectives_reducer.gd` | All action types, status transitions, event log |
| `tests/unit/scene_director/test_scene_director_reducer.gd` | Directive start/advance/complete/reset |

---

## Phase 2: Objectives Manager Core

**Goal**: Dependency graph, event log, and manager. Objectives can be activated, completed, and failed. No victory migration yet.

### 2A: Helpers (TDD)

**U_ObjectiveGraph** (`scripts/utils/scene_director/u_objective_graph.gd`):
- `static func build_graph(objectives: Array[Resource]) -> Dictionary` -- adjacency list keyed by objective_id; entries should be `RS_ObjectiveDefinition`
- `static func validate_graph(graph: Dictionary, known_ids: Array[StringName]) -> Array[String]` -- cycle detection (DFS) + missing reference detection (dependency IDs not in known_ids); returns error strings, empty array = valid
- `static func get_ready_dependents(objective_id: StringName, graph: Dictionary, statuses: Dictionary) -> Array[StringName]` -- dependents whose all prerequisites are completed
- `static func topological_sort(graph: Dictionary) -> Array[StringName]` -- evaluation order via Kahn's algorithm

Note: `validate_graph` requires `known_ids` because the graph's adjacency list can detect cycles and forward-references, but cannot detect whether a dependency ID refers to an objective that simply doesn't exist in the set. Pass `objectives.map(func(o): return o.objective_id)` as `known_ids`.

**U_ObjectiveEventLog** (`scripts/utils/scene_director/u_objective_event_log.gd`):
- `static func create_entry(objective_id: StringName, event_type: String, details: Dictionary = {}) -> Dictionary`
- `static func format_log(entries: Array) -> String` -- human-readable debug output
- Event types: `activated`, `completed`, `failed`, `dependency_met`, `condition_checked`

### 2B: M_ObjectivesManager (TDD)

`scripts/managers/m_objectives_manager.gd` -- extends Node

- `@export var state_store: I_StateStore = null` -- DI for testing
- `@export var objective_sets: Array[Resource] = []` -- sets assigned in root.tscn via ExtResource; entries should be `RS_ObjectiveSet`
- Discovers store via injection-first + ServiceLocator fallback
- In `_ready()`: calls `load_objective_set(set.set_id)` for each set in `objective_sets`
- Subscribes to gameplay events via `U_ECSEventBus` (checkpoint_activated, victory_executed, area_complete via action_dispatched)
- `load_objective_set(set_id)` -- activate set, build graph via `U_ObjectiveGraph.build_graph()`, validate via `validate_graph(graph, known_ids)`, activate auto_activate objectives
- `_check_conditions(conditions, context) -> bool` -- iterates `condition.evaluate(context)`, returns true only if all > 0.0
- `_execute_effects(effects, context)` -- iterates `effect.execute(context)`
- `_build_context() -> Dictionary` -- returns `{"state_store": _store, "redux_state": _store.get_state()}`
- `_complete_objective(objective_id)` -- dispatch complete action, execute effects via `_execute_effects(objective.completion_effects, _build_context())`, activate dependents, log event
- `_fail_objective(objective_id)` -- dispatch fail action
- `get_objective_status(objective_id)` -- read from Redux via selectors
- `_activate_dependents(objective_id)` -- check graph for ready dependents, activate them
- For VICTORY type completion: after effects execute, read `objective.completion_event_payload` and publish `EVENT_OBJECTIVE_VICTORY_TRIGGERED` with that dict as the event payload. `M_SceneManager` reads `event.payload.get("target_scene")` to determine the transition target.

### 2C: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/unit/scene_director/test_objective_graph.gd` | Graph building, cycle detection, ready dependents, topological sort |
| `tests/unit/scene_director/test_objective_event_log.gd` | Entry creation, formatting, event types |
| `tests/unit/scene_director/test_objectives_manager.gd` | Set loading, condition evaluation, completion flow, dependency activation, event logging |

### 2D: Regression + Commit

---

## Phase 3: Scene Director Core

**Goal**: Beat runner and scene director manager. Directives can be started, beats executed, and sequences completed.

### 3A: Helper (TDD)

**U_BeatRunner** (`scripts/utils/scene_director/u_beat_runner.gd`):
- RefCounted state machine
- `start(beats: Array[Resource])` -- initialize with beat list; entries should be `RS_BeatDefinition`
- `execute_current_beat(context: Dictionary)` -- check preconditions via `condition.evaluate(context)`, execute effects via `effect.execute(context)`
- `advance()` -- move to next beat
- `is_complete() -> bool` -- no more beats
- `get_current_beat() -> RS_BeatDefinition`
- `get_current_index() -> int`
- Wait mode handling: INSTANT auto-advances, TIMED uses elapsed time, SIGNAL waits for event
- `update(delta: float)` -- tick for TIMED beats
- `on_signal_received(event_name: StringName)` -- advance SIGNAL beats

Context requirements: The caller (M_SceneDirector) builds it: `{"state_store": _store, "redux_state": _store.get_state()}`. For SIGNAL beats triggered by an ECS event, also include `"event_payload": event.get("payload", {})`. Beat conditions should use `RS_ConditionReduxField`, `RS_ConditionEventPayload`, or `RS_ConditionConstant` — no `RS_ConditionComponentField`.

### 3B: M_SceneDirector (TDD)

`scripts/managers/m_scene_director.gd` -- extends Node

- `@export var state_store: I_StateStore = null` -- DI for testing
- `@export var directives: Array[Resource] = []` -- directives assigned in root.tscn via ExtResource; entries should be `RS_SceneDirective`
- Discovers store via injection-first + ServiceLocator fallback
- Subscribes to `scene/transition_completed` via `action_dispatched` to select directive for new scene
- `_select_directive(scene_id)` -- find highest-priority directive whose `target_scene_id == scene_id` and whose `selection_conditions` all pass (`condition.evaluate(context) > 0.0`)
- `_start_directive(directive)` -- dispatch start action, initialize beat runner. On start: collect unique `wait_event` StringNames from all SIGNAL-mode beats, subscribe to each via `U_ECSEventBus`. On `_on_directive_complete()` or `reset()`: unsubscribe all. Store unsubscribe callables for cleanup.
- `_build_context() -> Dictionary` -- returns `{"state_store": _store, "redux_state": _store.get_state()}`
- `_physics_process(delta)` -- tick beat runner for TIMED beats; pass `_build_context()` to execute_current_beat
- Subscribes to ECS events for SIGNAL beat advancement; passes event payload in context when forwarding to beat runner
- On directive complete: dispatch complete action, publish `directive_completed` event

### 3C: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/unit/scene_director/test_beat_runner.gd` | All wait modes, precondition gating, effect execution, advancement, completion |
| `tests/unit/scene_director/test_scene_director.gd` | Directive selection, beat execution, timed advancement, signal advancement, completion flow |

### 3D: Regression + Commit

---

## Phase 4: Victory Migration

**Goal**: Port victory scene transitions from M_SceneManager into objectives. S_VictoryHandlerSystem stays as-is.

### 4A: Victory Objective Resources

Create objective definitions for victory scenarios:
- `resources/scene_director/objectives/cfg_obj_level_complete.tres` -- STANDARD type, `auto_activate: true` (activates immediately when the set loads; the status goes to `active` on load, not on area completion — completion happens when the condition is met). Conditions: `RS_ConditionReduxField` checking `gameplay.completed_areas`.
- `resources/scene_director/objectives/cfg_obj_game_complete.tres` -- VICTORY type, `dependencies: [level_complete]`. Conditions: `RS_ConditionReduxField` checking required final area. `completion_effects: [RS_EffectDispatchAction: game_complete]`. `completion_event_payload: {"target_scene": StringName("victory")}` — M_ObjectivesManager reads this dict and includes it as the payload of `EVENT_OBJECTIVE_VICTORY_TRIGGERED`; M_SceneManager reads `event.payload.get("target_scene")` to determine the transition target.

Create objective set:
- `resources/scene_director/sets/cfg_objset_default.tres` -- default progression set

### 4B: M_SceneManager Refactor

Remove from M_SceneManager:
- `_on_victory_executed()` handler (lines 323-331)
- `_get_victory_target_scene()` method (lines 334-339)
- `_victory_executed_unsubscribe` variable and subscription (lines 153, 212, 294-295)
- `C_VICTORY_TRIGGER_COMPONENT` preload (line 36)

Add to M_SceneManager:
- Subscribe to `EVENT_OBJECTIVE_VICTORY_TRIGGERED` from M_ObjectivesManager
- `_on_objective_victory(event)` -- read target scene from event payload, transition

### 4C: Wire M_ObjectivesManager

- M_ObjectivesManager subscribes to `victory_executed` event
- On `victory_executed`: evaluate VICTORY objectives' conditions via `condition.evaluate(context)` (context built from `_build_context()`)
- When VICTORY objective completes: execute `completion_effects` via `effect.execute(context)`, then read `objective.completion_event_payload` and publish `EVENT_OBJECTIVE_VICTORY_TRIGGERED` with that dict as the event payload

### 4D: Scene Integration

- Add `M_ObjectivesManager` node to `scenes/root.tscn` under Managers
- Register in `root.gd` ServiceLocator
- Wire default objective set

### 4E: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/unit/scene_director/test_victory_migration.gd` | Victory objective completion triggers scene transition, game_complete prerequisite still enforced |
| `tests/integration/scene_director/test_objectives_integration.gd` | End-to-end: victory_executed -> objective evaluation -> objective_victory_triggered -> scene transition |

### 4F: Save Migration

- Add v(N) → v(N+1) migration to `U_SaveMigrationEngine` that injects an empty objectives slice (`{statuses: {}, active_set_id: "", event_log: []}`) into save files missing it
- M_ObjectivesManager `load_objective_set()` reconciles resource definitions with persisted statuses: loads set from `RS_ObjectiveSet` resources, applies saved statuses where objective IDs match, discards statuses for objectives no longer in the set
- Test: loading a pre-objectives save file produces valid objectives state with no errors

### 4G: Regression + Manual Playtest + Commit

---

## Phase 5: Scene Director Integration

**Goal**: Wire beats to scene flow. Directives execute during gameplay scenes.

### 5A: Directive Resources

Create scene directives:
- `resources/scene_director/directives/cfg_directive_gameplay_base.tres` -- base gameplay directive with introductory beats

### 5B: Scene Integration

- Add `M_SceneDirector` node to `scenes/root.tscn` under Managers
- Register in `root.gd` ServiceLocator
- Wire directives to scene director

### 5C: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/integration/scene_director/test_scene_director_integration.gd` | Scene load -> directive selected -> beats execute -> directive completes |

### 5D: Regression + Commit

---

## Phase 6: Cleanup + Verification

### 6A: Project-Level Updates

- Update `AGENTS.md` with Scene Director / Objectives Manager patterns
- Update `docs/general/DEV_PITFALLS.md` with any new pitfalls discovered

### 6B: Final Verification

- Run full test suite (ECS + QB + Scene Director + Style)
- Manual playtest: full gameplay loop (walk, checkpoint, victory, game complete)
- Verify victory transitions work through objectives (not hardcoded M_SceneManager logic)

### 6C: Commit

---

## Phase 7: Reset Run Hardening (TDD, Migrated IDs)

**Goal**: Make victory Continue deterministic by routing through a single `run/reset` contract that resets gameplay + objectives and retries into `alleyway` with migrated objective IDs only.

### 7A: Contract + State Updates

- Add `U_RunActions.ACTION_RESET_RUN` and `reset_run(next_route := &"retry_alleyway")`
- Add `U_ObjectivesActions.ACTION_RESET_FOR_NEW_RUN` with payload `{ "set_id": StringName }`
- Extend `U_ObjectivesReducer` with `ACTION_RESET_FOR_NEW_RUN` handling:
  - clear `statuses`
  - clear `event_log`
  - set `active_set_id` from payload

### 7B: Objectives Fresh Reset Mode

- Add `M_ObjectivesManager.reset_for_new_run(set_id := &"default_progression")`
- Keep `load_objective_set()` as the persisted save/load reconciliation path
- Split objective loading into two modes:
  - reconciliation mode (save/load)
  - fresh reset mode (reset-run) that skips persisted status reconciliation
- Fresh reset mode re-arms root objectives using bulk activation so objective event log stays empty post-reset

### 7C: Run Coordinator

- Add `M_RunCoordinator` manager that subscribes to store `action_dispatched` and handles `run/reset`
- `retry_alleyway` orchestration order:
  1. `U_GameplayActions.reset_progress()`
  2. `U_InteractBlocker.force_unblock()`
  3. `M_ObjectivesManager.reset_for_new_run(&"default_progression")` (when available)
  4. `U_NavigationActions.retry(&"alleyway")`
- Missing objectives manager should not block gameplay reset + retry
- Re-entrant reset requests while one is in-flight are ignored

### 7D: UI + Root Wiring

- Update `UI_Victory` Continue to dispatch `U_RunActions.reset_run(...)` instead of direct reset/navigation chaining
- Register `M_RunCoordinator` in `scenes/root.tscn` and `scripts/root.gd` ServiceLocator dependency wiring

### 7E: Test Coverage

- Unit coverage for:
  - objectives reducer reset-for-new-run semantics
  - objectives manager fresh reset behavior
  - run coordinator dispatch order + re-entrant guard
  - victory continue contract action path
- Integration coverage for:
  - post-Continue gameplay/objective state + `alleyway` target
  - migrated IDs only (`bar_complete`, `final_complete`) in scene-director objective integration

---

## Files Summary

### New Files (Resources)
```
scripts/resources/scene_director/rs_objective_definition.gd
scripts/resources/scene_director/rs_objective_set.gd
scripts/resources/scene_director/rs_beat_definition.gd
scripts/resources/scene_director/rs_scene_directive.gd
```

### New Files (State)
```
scripts/state/actions/u_objectives_actions.gd
scripts/state/reducers/u_objectives_reducer.gd
scripts/state/selectors/u_objectives_selectors.gd
scripts/resources/state/rs_objectives_initial_state.gd

scripts/state/actions/u_scene_director_actions.gd
scripts/state/reducers/u_scene_director_reducer.gd
scripts/state/selectors/u_scene_director_selectors.gd
scripts/resources/state/rs_scene_director_initial_state.gd
scripts/state/actions/u_run_actions.gd
```

### New Files (Managers + Helpers)
```
scripts/managers/m_objectives_manager.gd
scripts/managers/m_scene_director.gd
scripts/managers/m_run_coordinator.gd
scripts/utils/scene_director/u_objective_graph.gd
scripts/utils/scene_director/u_objective_event_log.gd
scripts/utils/scene_director/u_beat_runner.gd
```

### New Files (Resource Instances)
```
resources/scene_director/objectives/cfg_obj_level_complete.tres
resources/scene_director/objectives/cfg_obj_game_complete.tres
resources/scene_director/sets/cfg_objset_default.tres
resources/scene_director/directives/cfg_directive_gameplay_base.tres
```

### Modified Files
```
scripts/state/utils/u_state_slice_manager.gd    -- Add 2 new slices (objectives, scene_director)
scripts/state/m_state_store.gd                   -- Add @export for new initial state resources
scripts/root.gd                                  -- Register 2 new managers + dependencies
scripts/events/ecs/u_ecs_event_names.gd          -- Add objective/directive event constants
scripts/managers/m_scene_manager.gd              -- Remove victory handling, add objective_victory subscription
scenes/root.tscn                                 -- Add M_ObjectivesManager + M_SceneDirector nodes
scripts/ui/menus/ui_victory.gd                   -- Continue now dispatches run/reset contract action
```

### Test Files
```
tests/unit/scene_director/test_objectives_selectors.gd
tests/unit/scene_director/test_objectives_reducer.gd
tests/unit/scene_director/test_scene_director_selectors.gd
tests/unit/scene_director/test_scene_director_reducer.gd
tests/unit/scene_director/test_objective_graph.gd
tests/unit/scene_director/test_objective_event_log.gd
tests/unit/scene_director/test_objectives_manager.gd
tests/unit/scene_director/test_beat_runner.gd
tests/unit/scene_director/test_scene_director.gd
tests/unit/scene_director/test_victory_migration.gd
tests/unit/scene_director/test_run_coordinator.gd
tests/integration/scene_director/test_objectives_integration.gd
tests/integration/scene_director/test_scene_director_integration.gd
tests/unit/ui/test_endgame_screens.gd
tests/integration/scene_manager/test_endgame_flows.gd
```

## Critical Files Reference

| Existing File | Relevance |
|---------------|-----------|
| `scripts/ecs/systems/s_victory_handler_system.gd` | Stays as-is; M_ObjectivesManager listens to its `victory_executed` events |
| `scripts/ecs/systems/s_checkpoint_handler_system.gd` | Stays as-is; M_ObjectivesManager may listen to `checkpoint_activated` |
| `scripts/managers/m_scene_manager.gd` | Remove victory handling (~20 lines), add objective_victory subscription |
| `scripts/state/utils/u_state_slice_manager.gd` | Add objectives + scene_director slices |
| `scripts/state/m_state_store.gd` | Add @export for objectives + scene_director initial state |
| `scripts/root.gd` | Register M_ObjectivesManager + M_SceneDirector with ServiceLocator |
| `scripts/events/ecs/u_ecs_event_names.gd` | Add objective/directive event constants |
| `scripts/resources/qb/rs_base_condition.gd` | Base class for typed conditions (v2) |
| `scripts/resources/qb/rs_base_effect.gd` | Base class for typed effects (v2) |
| `scenes/root.tscn` | Add M_ObjectivesManager + M_SceneDirector nodes |
| `tests/mocks/` | MockStateStore, MockECSManager for testing |
