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

Three systems layered on the existing QB Rule Manager infrastructure:

1. **M_ObjectivesManager** -- Dependency graph, win/loss conditions, event logging. Manages objective lifecycle (inactive -> active -> completed/failed). Uses QB utilities (`U_QBRuleEvaluator`, `U_QBEffectExecutor`, `U_QBQualityProvider`) for condition/effect evaluation without extending `BaseQBRuleManager`.

2. **M_SceneDirector** -- Beat runner for intra-scene sequences. Executes ordered beats within a scene directive. Beats can trigger dialogue, camera moves, spawn events, or any effect expressible through the QB effect system.

3. **Scene Manager refactor** -- Strip victory/game-flow logic from `M_SceneManager`, making it a pure scene loader/transition coordinator. Victory transitions become objective-driven via `M_ObjectivesManager` publishing events that `M_SceneManager` subscribes to.

---

## Core Concepts

### Objectives

Resource-defined goals tracked in Redux state. Each objective has:
- **Status lifecycle**: `inactive` -> `active` -> `completed` | `failed`
- **Conditions**: QB conditions that determine when an objective completes (reuses `RS_QBCondition`)
- **Effects**: QB effects that fire on completion (reuses `RS_QBEffect`)
- **Dependencies**: Other objective IDs that must be completed before this one activates (DAG)
- **Type**: `STANDARD`, `VICTORY` (triggers win flow), `CHECKPOINT` (triggers save)

### Objective Sets

A collection of objectives that define a complete game progression. Only one set is active at a time. Swapping sets enables different campaigns, difficulty modes, or mod-defined progressions.

### Dependency Graph (DAG)

Objectives form a directed acyclic graph at the objectives layer (not QB rules). Dependencies are declared on `RS_ObjectiveDefinition` resources. The graph is validated at load time (cycle detection, missing references). When an objective completes, the graph evaluator activates any dependents whose prerequisites are now met.

### Beats

Ordered intra-scene directives. A beat is an atomic step in a scene sequence:
- **Preconditions**: QB conditions that gate beat execution
- **Effects**: QB effects that fire when the beat runs
- **Duration**: Optional timed duration before auto-advancing to next beat
- **Wait mode**: `INSTANT` (advance immediately after effects), `TIMED` (wait duration), `SIGNAL` (wait for event)

### Scene Directives

A named sequence of beats for a specific scene. Multiple directives can exist per scene (e.g., "first_visit", "return_visit", "boss_phase_2"). The active directive is selected based on conditions evaluated against Redux state.

### Victory as Objective Type

Victory is modeled as an objective with type `VICTORY`. When a VICTORY objective completes:
1. Its effects fire (e.g., `DISPATCH_ACTION: game_complete`)
2. `M_ObjectivesManager` publishes `objective_victory_triggered` event
3. `M_SceneManager` subscribes and transitions to the appropriate scene
4. No hardcoded scene selection in `M_SceneManager` -- the objective's effects determine what happens

---

## Resources

```
RS_ObjectiveDefinition         -- Single objective (conditions, effects, dependencies, type)
RS_ObjectiveSet                -- Collection of objectives for a game progression
RS_BeatDefinition              -- Single beat step (preconditions, effects, duration, wait mode)
RS_SceneDirective              -- Ordered sequence of beats for a scene
```

---

## Class Hierarchy

```
Resources (data):
  RS_ObjectiveDefinition         -- Objective with conditions, effects, dependencies, type
  RS_ObjectiveSet                -- Collection of objectives
  RS_BeatDefinition              -- Beat step (preconditions, effects, timing)
  RS_SceneDirective              -- Ordered beat sequence for a scene

Managers:
  M_ObjectivesManager            -- Node (NOT BaseQBRuleManager); graph eval, event log, Redux sync
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
[Game Events / QB Rules]
        |  (checkpoint_activated, victory_triggered, area_complete, etc.)
        v
  M_ObjectivesManager._on_event_received(event)
        |
        v
  _check_objective_conditions(objective_id)
        |  reads Redux state + ECS components via U_QBQualityProvider
        |  evaluates conditions via U_QBRuleEvaluator
        v
  [conditions met?]
        |
        v  YES
  _complete_objective(objective_id)
        |  dispatch U_ObjectivesActions.complete(objective_id)
        |  execute completion effects via U_QBEffectExecutor
        |  log event via U_ObjectiveEventLog
        v
  _activate_dependents(objective_id)
        |  U_ObjectiveGraph.get_ready_dependents(objective_id, statuses)
        |  dispatch U_ObjectivesActions.activate(dependent_id) for each
        v
  [VICTORY type?]
        |  YES -> publish "objective_victory_triggered" event
        v
  M_SceneManager._on_objective_victory() -> transition_to_scene(target)
```

### Scene Director Flow

```
[Scene loaded / Event trigger]
        |
        v
  M_SceneDirector._select_directive(scene_id)
        |  evaluates directive preconditions against Redux state
        v
  M_SceneDirector._start_directive(directive)
        |  dispatch U_SceneDirectorActions.start_directive(directive_id)
        v
  U_BeatRunner.start(beats)
        |
        v  (each beat)
  U_BeatRunner.execute_current_beat()
        |  check preconditions via U_QBRuleEvaluator
        |  execute effects via U_QBEffectExecutor
        |  wait based on wait_mode (INSTANT / TIMED / SIGNAL)
        v
  U_BeatRunner.advance()
        |  dispatch U_SceneDirectorActions.advance_beat()
        v
  [more beats?]
        |  NO -> dispatch U_SceneDirectorActions.complete_directive()
        v
  M_SceneDirector._on_directive_complete()
```

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Objectives own dependency graph | DAG at objectives layer, not QB rules | QB rules are condition-effect pairs without dependency semantics; objectives need ordered progression |
| Manager, not ECS system | M_ObjectivesManager extends Node | Objectives are global game state, not per-entity ECS behavior; no physics tick needed |
| Absorb victory, keep checkpoint | Victory transitions move to objectives; checkpoint handler stays | Checkpoint activation is a focused handler pattern that works well; victory needs objective context |
| QB utility reuse, not extension | Uses U_QBRuleEvaluator/EffectExecutor/QualityProvider | Same condition/effect evaluation without the per-tick rule loop overhead of BaseQBRuleManager |
| Both debug + runtime event log | U_ObjectiveEventLog tracks all state transitions | Essential for debugging progression issues; log is structured and queryable |
| Resource-defined objectives | RS_ObjectiveDefinition .tres files | Consistent with RS_* pattern, editor-friendly, mobile-safe preload |
| Objective sets for modularity | RS_ObjectiveSet groups objectives | Enables campaign/difficulty/mod swapping without code changes |
| Beat runner as helper | U_BeatRunner is RefCounted, not a Node | Pure state machine logic; M_SceneDirector owns the Node lifecycle |
| Two Redux slices | objectives + scene_director | Clean separation of concerns; objectives persist, director state is transient |
| Scene Manager stays a loader | Strip game flow logic, keep transitions | Single responsibility; M_SceneManager should not know about victory conditions |
| Victory target in objective | Objective effects determine transition target | No hardcoded match statement; data-driven scene selection |

---

## Anti-Patterns

- Do NOT extend BaseQBRuleManager for objectives (objectives need graph semantics, not per-tick rule evaluation)
- Do NOT put dependency graph logic in QB rules (rules are condition-effect pairs, not DAG nodes)
- Do NOT keep victory scene selection in M_SceneManager (move to objective effects)
- Do NOT use runtime DirAccess for objective/directive loading (use const preload arrays)
- Do NOT make M_ObjectivesManager an ECS system (it's global game state, not per-entity)
- Do NOT couple beat execution to physics frames (beats may be timed, signal-based, or instant)
- Do NOT duplicate QB condition/effect logic (reuse U_QBRuleEvaluator, U_QBEffectExecutor, U_QBQualityProvider)
- Do NOT modify checkpoint handler (S_CheckpointHandlerSystem stays as-is)
- Do NOT add objective state to the gameplay Redux slice (use dedicated objectives slice)

---

## Integration Points

### With QB Rule Manager Utilities

Objectives reuse the QB evaluation stack without extending BaseQBRuleManager:
- `U_QBRuleEvaluator.evaluate_condition()` -- check objective completion conditions
- `U_QBEffectExecutor.execute_effects()` -- fire objective completion effects
- `U_QBQualityProvider.read_quality()` -- read qualities for condition evaluation

### With Redux State (M_StateStore)

Two new slices:
- `objectives` -- persistent slice (statuses, active_set_id, event_log)
- `scene_director` -- transient slice (active_directive_id, current_beat_index, state)

New action/reducer/selector/initial-state files follow existing patterns (see `u_gameplay_actions.gd`, `u_gameplay_reducer.gd`, etc.).

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
- Victory target scene comes from objective completion effects (data-driven)

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
