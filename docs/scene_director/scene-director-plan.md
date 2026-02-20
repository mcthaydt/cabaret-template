# Scene Director - Implementation Plan

## Phase 1: State Infrastructure

**Goal**: Resources + Redux slices for objectives and scene director. No behavioral change -- pure data layer.

### 1A: Objective Resources

**RS_ObjectiveDefinition** (`scripts/resources/scene_director/rs_objective_definition.gd`):
- `objective_id: StringName`
- `description: String`
- `objective_type: ObjectiveType` enum (STANDARD, VICTORY, CHECKPOINT)
- `conditions: Array[RS_QBCondition]` -- reuse existing QB condition resources
- `completion_effects: Array[RS_QBEffect]` -- reuse existing QB effect resources
- `dependencies: Array[StringName]` -- objective IDs that must be completed first
- `auto_activate: bool = false` -- activate immediately when set loads (no dependencies required)

**RS_ObjectiveSet** (`scripts/resources/scene_director/rs_objective_set.gd`):
- `set_id: StringName`
- `description: String`
- `objectives: Array[RS_ObjectiveDefinition]`

### 1B: Scene Director Resources

**RS_BeatDefinition** (`scripts/resources/scene_director/rs_beat_definition.gd`):
- `beat_id: StringName`
- `description: String`
- `preconditions: Array[RS_QBCondition]` -- gate beat execution
- `effects: Array[RS_QBEffect]` -- fire when beat runs
- `wait_mode: WaitMode` enum (INSTANT, TIMED, SIGNAL)
- `duration: float = 0.0` -- for TIMED wait mode
- `wait_event: StringName = &""` -- for SIGNAL wait mode

**RS_SceneDirective** (`scripts/resources/scene_director/rs_scene_directive.gd`):
- `directive_id: StringName`
- `description: String`
- `target_scene_id: StringName` -- which scene this directive applies to
- `selection_conditions: Array[RS_QBCondition]` -- conditions for selecting this directive
- `priority: int = 0` -- higher priority directives checked first
- `beats: Array[RS_BeatDefinition]`

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
- `start_directive(directive_id)`, `advance_beat(beat_index)`
- `complete_directive()`, `reset()`

**Reducer** (`scripts/state/reducers/u_scene_director_reducer.gd`):
- Handles scene_director slice mutations

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
- Objectives slice: persistent (saved/loaded)
- Scene director slice: transient (not saved)

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
- `static func build_graph(objectives: Array[RS_ObjectiveDefinition]) -> Dictionary` -- adjacency list
- `static func validate_graph(graph: Dictionary) -> Array[String]` -- cycle detection, missing refs
- `static func get_ready_dependents(objective_id: StringName, graph: Dictionary, statuses: Dictionary) -> Array[StringName]` -- dependents whose all prerequisites are completed
- `static func topological_sort(graph: Dictionary) -> Array[StringName]` -- evaluation order

**U_ObjectiveEventLog** (`scripts/utils/scene_director/u_objective_event_log.gd`):
- `static func create_entry(objective_id: StringName, event_type: String, details: Dictionary = {}) -> Dictionary`
- `static func format_log(entries: Array) -> String` -- human-readable debug output
- Event types: `activated`, `completed`, `failed`, `dependency_met`, `condition_checked`

### 2B: M_ObjectivesManager (TDD)

`scripts/managers/m_objectives_manager.gd` -- extends Node

- `@export var state_store: I_StateStore = null` -- DI for testing
- `@export var objective_sets: Array[RS_ObjectiveSet] = []` -- const-preloaded sets
- Discovers store via injection-first + ServiceLocator fallback
- Subscribes to gameplay events via `U_ECSEventBus` (checkpoint_activated, victory_executed, area_complete via action_dispatched)
- `load_objective_set(set_id)` -- activate set, build graph, activate auto-activate objectives
- `_check_objective_conditions(objective_id)` -- evaluate conditions via U_QBRuleEvaluator
- `_complete_objective(objective_id)` -- dispatch complete action, execute effects, activate dependents
- `_fail_objective(objective_id)` -- dispatch fail action
- `get_objective_status(objective_id)` -- read from Redux via selectors
- `_activate_dependents(objective_id)` -- check graph for ready dependents, activate them

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
- `start(beats: Array[RS_BeatDefinition])` -- initialize with beat list
- `execute_current_beat(context: Dictionary)` -- check preconditions, fire effects
- `advance()` -- move to next beat
- `is_complete() -> bool` -- no more beats
- `get_current_beat() -> RS_BeatDefinition`
- `get_current_index() -> int`
- Wait mode handling: INSTANT auto-advances, TIMED uses elapsed time, SIGNAL waits for event
- `update(delta: float)` -- tick for TIMED beats
- `on_signal_received(event_name: StringName)` -- advance SIGNAL beats

### 3B: M_SceneDirector (TDD)

`scripts/managers/m_scene_director.gd` -- extends Node

- `@export var state_store: I_StateStore = null` -- DI for testing
- `@export var directives: Array[RS_SceneDirective] = []` -- const-preloaded directives
- Discovers store via injection-first + ServiceLocator fallback
- Subscribes to `scene/transition_completed` via `action_dispatched` to select directive for new scene
- `_select_directive(scene_id)` -- find highest-priority directive matching scene + conditions
- `_start_directive(directive)` -- dispatch start action, initialize beat runner
- `_physics_process(delta)` -- tick beat runner for TIMED beats
- Subscribes to ECS events for SIGNAL beat advancement
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
- `resources/scene_director/objectives/cfg_obj_level_complete.tres` -- STANDARD type, activates on area completion
- `resources/scene_director/objectives/cfg_obj_game_complete.tres` -- VICTORY type, depends on level_complete, effects include `game_complete` action dispatch

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
- On `victory_executed`: evaluate victory objectives' conditions
- When VICTORY objective completes: publish `objective_victory_triggered` with target scene in payload

### 4D: Scene Integration

- Add `M_ObjectivesManager` node to `scenes/root.tscn` under Managers
- Register in `root.gd` ServiceLocator
- Wire default objective set

### 4E: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/unit/scene_director/test_victory_migration.gd` | Victory objective completion triggers scene transition, game_complete prerequisite still enforced |
| `tests/integration/scene_director/test_objectives_integration.gd` | End-to-end: victory_executed -> objective evaluation -> objective_victory_triggered -> scene transition |

### 4F: Regression + Manual Playtest + Commit

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
```

### New Files (Managers + Helpers)
```
scripts/managers/m_objectives_manager.gd
scripts/managers/m_scene_director.gd
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
```

### Test Files
```
tests/unit/scene_director/test_objectives_reducer.gd
tests/unit/scene_director/test_scene_director_reducer.gd
tests/unit/scene_director/test_objective_graph.gd
tests/unit/scene_director/test_objective_event_log.gd
tests/unit/scene_director/test_objectives_manager.gd
tests/unit/scene_director/test_beat_runner.gd
tests/unit/scene_director/test_scene_director.gd
tests/unit/scene_director/test_victory_migration.gd
tests/integration/scene_director/test_objectives_integration.gd
tests/integration/scene_director/test_scene_director_integration.gd
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
| `scripts/utils/qb/u_qb_rule_evaluator.gd` | Reuse for condition evaluation |
| `scripts/utils/qb/u_qb_effect_executor.gd` | Reuse for effect execution |
| `scripts/utils/qb/u_qb_quality_provider.gd` | Reuse for quality reading |
| `scenes/root.tscn` | Add M_ObjectivesManager + M_SceneDirector nodes |
| `tests/mocks/` | MockStateStore, MockECSManager for testing |
