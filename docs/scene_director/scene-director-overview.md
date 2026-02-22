# Scene Director - Architecture Overview

## Problem Statement

Victory and checkpoint logic lives in handler systems (`S_VictoryHandlerSystem`, `S_CheckpointHandlerSystem`) that were extracted during the QB Rule Manager phase. Scene Manager (`M_SceneManager`) still owns game flow logic -- it subscribes to `victory_executed` events and determines target scenes based on victory type (lines 322-339). There is no objectives system for tracking player goals, dependencies, or win/loss conditions. There is no beat/scene direction system for orchestrating intra-scene sequences (cutscenes, tutorials, scripted moments). Game progression is hard to extend -- adding a new victory condition or objective requires modifying handler systems and scene manager directly.

**Specific pain points:**

- `M_SceneManager._on_victory_executed()` hardcodes target scene selection (`"victory"` for GAME_COMPLETE, `"alleyway"` for others) -- lines 323-339
- `M_SceneManager._get_victory_target_scene()` uses a `match` statement that doesn't scale -- line 334-339
- Victory is the only "objective" concept, with no dependency graph (e.g., "complete areas A and B before unlocking area C")
- No event log for debugging objective state transitions
- No system for sequencing intra-scene events (beats) in a declarative, data-driven way
- `C_VictoryTriggerComponent` preloaded in `M_SceneManager` (line 36) creates unnecessary coupling

## Solution

Three systems, using v2 QB typed resources for condition/effect evaluation:

1. **M_ObjectivesManager** -- Dependency graph, win/loss conditions, event logging. Manages objective lifecycle (inactive -> active -> completed/failed). Uses v2 typed conditions/effects directly — `condition.evaluate(context)` and `effect.execute(context)`. No utility classes or base class inheritance needed.

2. **M_SceneDirector** -- Beat runner for intra-scene sequences. Executes ordered beats within a scene directive. Beats can trigger dialogue, camera moves, spawn events, or any effect expressible through v2 effect subclasses.

3. **Scene Manager refactor** -- Strip victory/game-flow logic from `M_SceneManager`, making it a pure scene loader/transition coordinator. Victory transitions become objective-driven via `M_ObjectivesManager` publishing events that `M_SceneManager` subscribes to.

---

## Core Concepts

### Objectives

Resource-defined goals tracked in Redux state. Objective conditions are evaluated **on event**, not polled every tick. M_ObjectivesManager subscribes to specific gameplay events (checkpoint_activated, victory_executed, area_complete actions) and re-evaluates relevant objectives only when those events fire. This is intentional — objectives represent milestone state changes, not continuous queries.

Each objective has:
- **Status lifecycle**: `inactive` -> `active` -> `completed` | `failed`
- **Conditions**: v2 typed conditions that determine when an objective completes (`Array[RS_BaseCondition]` — use `RS_ConditionReduxField`, `RS_ConditionEventPayload`, `RS_ConditionConstant`)
- **Effects**: v2 typed effects that fire on completion (`Array[RS_BaseEffect]` — use `RS_EffectDispatchAction`, `RS_EffectPublishEvent`, etc.)
- **Dependencies**: Other objective IDs that must be completed before this one activates (DAG)
- **Type**: `STANDARD`, `VICTORY` (triggers win flow), `CHECKPOINT` (triggers save — deferred, not implemented in Phase 1-6)
- **Completion event payload**: `completion_event_payload: Dictionary` — arbitrary data merged into the published completion event. Allows objectives to carry type-specific data (e.g., VICTORY objectives set `{"target_scene": StringName("victory")}`) without polluting the base resource with type-specific fields.

### Objective Sets

A collection of objectives that define a complete game progression. Only one set is active at a time. Swapping sets enables different campaigns, difficulty modes, or mod-defined progressions.

### Dependency Graph (DAG)

Objectives form a directed acyclic graph at the objectives layer. Dependencies are declared on `RS_ObjectiveDefinition` resources. The graph is validated at load time (cycle detection, missing references). When an objective completes, the graph evaluator activates any dependents whose prerequisites are now met.

### Beats

Ordered intra-scene directives. A beat is an atomic step in a scene sequence:
- **Preconditions**: v2 typed conditions that gate beat execution
- **Effects**: v2 typed effects that fire when the beat runs
- **Duration**: Optional timed duration before auto-advancing to next beat
- **Wait mode**: `INSTANT` (advance immediately after effects), `TIMED` (wait duration), `SIGNAL` (wait for event)

### Scene Directives

A named sequence of beats for a specific scene. Multiple directives can exist per scene (e.g., "first_visit", "return_visit", "boss_phase_2"). The active directive is selected based on conditions evaluated against Redux state.

### Victory as Objective Type

Victory is modeled as an objective with type `VICTORY`. When a VICTORY objective completes:
1. Its effects execute via `effect.execute(context)` (e.g., `RS_EffectDispatchAction: game_complete`)
2. `M_ObjectivesManager` reads `objective.completion_event_payload` and publishes `objective_victory_triggered` with that payload
3. `M_SceneManager` subscribes, reads `event.payload.get("target_scene")`, and calls `transition_to_scene(target)`
4. No hardcoded scene selection in `M_SceneManager` -- the objective's `completion_event_payload` determines the target

---

## Resources

```
RS_ObjectiveDefinition         -- Single objective (conditions, effects, dependencies, type)
RS_ObjectiveSet                -- Collection of objectives for a game progression
RS_BeatDefinition              -- Single beat step (preconditions, effects, duration, wait mode)
RS_SceneDirective              -- Ordered sequence of beats for a scene
```

All condition/effect arrays use v2 typed resources (`Array[RS_BaseCondition]`, `Array[RS_BaseEffect]`). The inspector shows valid subclass dropdowns.

---

## Class Hierarchy

```
Resources (data):
  RS_ObjectiveDefinition         -- Objective with typed conditions, effects, dependencies, type
  RS_ObjectiveSet                -- Collection of objectives
  RS_BeatDefinition              -- Beat step (typed preconditions, effects, timing)
  RS_SceneDirective              -- Ordered beat sequence for a scene

Managers:
  M_ObjectivesManager            -- Node; graph eval, event log, Redux sync
  M_SceneDirector                -- Node; beat runner, directive selection

Helpers (pure logic, testable):
  U_ObjectiveGraph               -- DAG validation, dependency resolution, topological sort
  U_ObjectiveEventLog            -- Structured event log for objective state transitions
  U_BeatRunner                   -- Beat execution state machine (current beat, advance, wait)

State (Redux):
  objectives slice               -- {statuses: {}, active_set_id: "", event_log: []}
  scene_director slice           -- {active_directive_id: "", current_beat_index: -1, state: "idle"}

  Actions:
    U_ObjectivesActions           -- activate, complete, fail, set_active_set, log_event
    U_SceneDirectorActions        -- start_directive, advance_beat, complete_directive, reset

  Reducers:
    U_ObjectivesReducer           -- Handles objectives slice mutations
    U_SceneDirectorReducer        -- Handles scene_director slice mutations

  Selectors:
    U_ObjectivesSelectors         -- get_objective_status, get_active_objectives, is_completed, etc.
    U_SceneDirectorSelectors      -- get_active_directive, get_current_beat, is_running, etc.

  Initial State:
    RS_ObjectivesInitialState     -- Default objectives slice state
    RS_SceneDirectorInitialState  -- Default scene_director slice state
```

---

## Data Flow

### Objectives Flow

```
[Game Events]
        |  (checkpoint_activated, victory_triggered, area_complete, etc.)
        v
  M_ObjectivesManager._on_event_received(event)
        |
        v
  _check_conditions(objective.conditions, context)
        |  builds context: {state_store, redux_state}
        |  iterates: condition.evaluate(context) > 0.0 for ALL
        v
  [conditions met?]
        |
        v  YES
  _complete_objective(objective_id)
        |  dispatch U_ObjectivesActions.complete(objective_id)
        |  iterate completion effects: effect.execute(context)
        |  log event via U_ObjectiveEventLog
        v
  _activate_dependents(objective_id)
        |  U_ObjectiveGraph.get_ready_dependents(objective_id, statuses)
        |  dispatch U_ObjectivesActions.activate(dependent_id) for each
        v
  [VICTORY type?]
        |  YES -> publish "objective_victory_triggered"
        |         payload = objective.completion_event_payload
        |         (e.g., {"target_scene": StringName("victory")})
        v
  M_SceneManager._on_objective_victory(event)
        |  target := event.payload.get("target_scene")
        v
  transition_to_scene(target)
```

### Scene Director Flow

```
[Scene loaded / Event trigger]
        |
        v
  M_SceneDirector._select_directive(scene_id)
        |  evaluates directive selection_conditions: condition.evaluate(context)
        |  picks highest-priority passing directive
        v
  M_SceneDirector._start_directive(directive)
        |  dispatch U_SceneDirectorActions.start_directive(directive_id)
        |  pre-scan all beats for unique wait_event values (SIGNAL mode)
        |  subscribe to each via U_ECSEventBus
        v
  U_BeatRunner.start(beats)
        |
        v  (each beat)
  U_BeatRunner.execute_current_beat(context)
        |  check preconditions: condition.evaluate(context) > 0.0 for all
        |  execute effects: effect.execute(context)
        |  wait based on wait_mode (INSTANT / TIMED / SIGNAL)
        v
  U_BeatRunner.advance()
        |  dispatch U_SceneDirectorActions.advance_beat()
        v
  [more beats?]
        |  NO -> dispatch U_SceneDirectorActions.complete_directive()
        v
  M_SceneDirector._on_directive_complete()
        |  unsubscribe all SIGNAL event subscriptions
```

**SIGNAL subscription lifecycle:** On `_start_directive()`, the director pre-scans all beats for unique `wait_event` values and subscribes to those ECS events. On `_on_directive_complete()` or `reset()`, it unsubscribes all. This avoids subscribing to events that no beat in the current directive cares about.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Objectives own dependency graph | DAG at objectives layer | Objectives need ordered progression; rules are condition-effect pairs without dependency semantics |
| Manager, not ECS system | M_ObjectivesManager extends Node | Objectives are global game state, not per-entity ECS behavior; no physics tick needed |
| Absorb victory, keep checkpoint | Victory transitions move to objectives; checkpoint handler stays | Checkpoint activation is a focused handler pattern that works well; victory needs objective context |
| Direct v2 condition/effect evaluation | Call evaluate()/execute() on typed resources | Conditions/effects are self-contained — no utility classes needed. Simpler than v1 which required 3 utility classes |
| Both debug + runtime event log | U_ObjectiveEventLog tracks all state transitions | Essential for debugging progression issues; log is structured and queryable |
| Resource-defined objectives | RS_ObjectiveDefinition .tres files | Consistent with RS_* pattern, editor-friendly, mobile-safe preload |
| Objective sets for modularity | RS_ObjectiveSet groups objectives | Enables campaign/difficulty/mod swapping without code changes |
| Beat runner as helper | U_BeatRunner is RefCounted, not a Node | Pure state machine logic; M_SceneDirector owns the Node lifecycle |
| Two Redux slices | objectives + scene_director | Clean separation of concerns; objectives persist, director state is transient |
| Scene Manager stays a loader | Strip game flow logic, keep transitions | Single responsibility; M_SceneManager should not know about victory conditions |
| Victory target in objective | Objective completion_event_payload determines transition target | No hardcoded match statement; data-driven scene selection |

---

## Anti-Patterns

- Do NOT extend BaseECSSystem for objectives (objectives are global game state, not per-entity tick behavior)
- Do NOT put dependency graph logic in rules (rules are condition-effect pairs, not DAG nodes)
- Do NOT keep victory scene selection in M_SceneManager (move to objective effects)
- Do NOT use runtime DirAccess for objective/directive loading (use const preload arrays)
- Do NOT couple beat execution to physics frames (beats may be timed, signal-based, or instant)
- Do NOT modify checkpoint handler (S_CheckpointHandlerSystem stays as-is)
- Do NOT add objective state to the gameplay Redux slice (use dedicated objectives slice)
- Do NOT use RS_ConditionComponentField or RS_ConditionEntityTag in objectives/beats (no per-entity context at manager level; use RS_ConditionReduxField, RS_ConditionEventPayload, or RS_ConditionConstant)

---

## Integration Points

### With v2 QB Typed Resources

Objectives and beats use v2 condition/effect resources directly. No intermediate utility classes — conditions self-evaluate, effects self-execute:

```gdscript
# Check all conditions pass (binary AND)
func _check_conditions(conditions: Array[RS_BaseCondition], context: Dictionary) -> bool:
    for condition in conditions:
        if condition.evaluate(context) <= 0.0:
            return false
    return true

# Execute effects
func _execute_effects(effects: Array[RS_BaseEffect], context: Dictionary) -> void:
    for effect in effects:
        effect.execute(context)
```

**Appropriate condition subclasses for objectives/beats:**
- `RS_ConditionReduxField` — check Redux state values (e.g., `navigation.shell`, `scene.is_transitioning`)
- `RS_ConditionEventPayload` — check event payload fields (e.g., `trigger_node`, `checkpoint`)
- `RS_ConditionConstant` — fixed score for unconditional beats or weighting

**Context building:**

```gdscript
func _build_context() -> Dictionary:
    return {
        "state_store": _store,
        "redux_state": _store.get_state(),
    }

# When triggered by an event:
func _build_event_context(event_payload: Dictionary) -> Dictionary:
    var context := _build_context()
    context["event_payload"] = event_payload
    return context
```

### With Redux State (M_StateStore)

Two new slices:
- `objectives` -- persistent slice (statuses, active_set_id, event_log)
- `scene_director` -- transient slice (active_directive_id, current_beat_index, state)

New action/reducer/selector/initial-state files follow existing patterns.

#### Save/Load Integration

- Objectives slice is persistent — objective **statuses** are saved/loaded
- Objective **definitions** are always reconstructed from `RS_ObjectiveSet` resources on load (resources are the source of truth for structure; saves are the source of truth for progress)
- `U_SaveMigrationEngine` needs a migration step (v(N) → v(N+1)) that injects an empty `objectives: {statuses: {}, active_set_id: "", event_log: []}` into old save files missing the slice
- On load, M_ObjectivesManager reconciles: loads set from resources, applies saved statuses where objective IDs match, discards statuses for objectives no longer in the set

### With ECS Event Bus (U_ECSEventBus)

New event constants in `U_ECSEventNames`:
- `EVENT_OBJECTIVE_ACTIVATED`, `EVENT_OBJECTIVE_COMPLETED`, `EVENT_OBJECTIVE_FAILED`
- `EVENT_OBJECTIVE_VICTORY_TRIGGERED`
- `EVENT_DIRECTIVE_STARTED`, `EVENT_DIRECTIVE_COMPLETED`, `EVENT_BEAT_ADVANCED`

M_ObjectivesManager subscribes to existing gameplay events (checkpoint_activated, victory_executed, area_complete actions) to evaluate objective conditions.

### With M_SceneManager

- Remove `_on_victory_executed()` handler and `_get_victory_target_scene()` from M_SceneManager
- Remove `C_VICTORY_TRIGGER_COMPONENT` preload (line 36)
- M_SceneManager subscribes to `objective_victory_triggered` event from M_ObjectivesManager
- Victory target scene comes from objective completion_event_payload (data-driven)

### With ServiceLocator (root.gd)

Register two new managers:
- `_register_if_exists(managers_node, "M_ObjectivesManager", StringName("objectives_manager"))`
- `_register_if_exists(managers_node, "M_SceneDirector", StringName("scene_director"))`

Dependencies:
- `objectives_manager` depends on `state_store`
- `scene_director` depends on `state_store`, `objectives_manager`

### With Existing Handler Systems

- `S_VictoryHandlerSystem` stays as-is (validates triggers, dispatches state updates, publishes `victory_executed`)
- `S_CheckpointHandlerSystem` stays as-is (activates checkpoints, dispatches state)
- M_ObjectivesManager listens to handler events to evaluate objective conditions
