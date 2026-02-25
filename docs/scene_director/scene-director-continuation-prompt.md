# Scene Director - Continuation Prompt

Use this prompt to resume work on the Scene Director / Objectives Manager feature in a new session.

---

## Current Status

**Phase**: Phase 3 complete
**Branch**: scene-director
**Next Task**: T4.1 -- Create `cfg_obj_level_complete.tres`
**Prerequisite**: QB v2 must be complete before starting (v2 typed resources are required)

**Latest Verification**: 2026-02-25 -- `tests/unit/scene_director -gselect=test_scene_director` (18/18), `tests/unit/scene_director` (57/57), `tests/unit/qb` (134/134), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (197/197), `tests/unit/style` (12/12), `tests/integration/scene_manager` (90/90). Full `tests/**` baseline still has one existing unrelated lighting performance failure (`test_multi_character_multi_zone_performance_smoke`).

---

## Context

You are implementing a Scene Director and Objectives Manager for a Godot 4.6 ECS game template. This builds on top of the completed QB v2 rule engine (typed resources + stateless scoring library). The feature adds three systems:

1. **M_ObjectivesManager** -- Dependency graph, win/loss conditions, event logging
2. **M_SceneDirector** -- Beat runner for intra-scene sequences
3. **Scene Manager refactor** -- Strip victory logic from M_SceneManager

**Key design decisions:**

- **Manager, not ECS system**: M_ObjectivesManager and M_SceneDirector extend Node, not BaseECSSystem -- objectives are global game state, not per-entity tick behavior
- **Direct v2 condition/effect evaluation**: Conditions self-evaluate via `condition.evaluate(context)`, effects self-execute via `effect.execute(context)`. No utility classes needed — much simpler than v1's three-utility-class indirection
- **Objectives own dependency graph**: DAG at objectives layer with cycle detection and topological sort
- **Victory as objective type**: VICTORY objectives trigger scene transitions via events; no hardcoded scene selection in M_SceneManager
- **S_VictoryHandlerSystem stays as-is**: Validates triggers, dispatches state updates, publishes `victory_executed`. M_ObjectivesManager listens to this event
- **S_CheckpointHandlerSystem stays as-is**: No changes needed
- **Two new Redux slices**: `objectives` (persistent) and `scene_director` (transient)
- **Resource-defined everything**: RS_ObjectiveDefinition, RS_ObjectiveSet, RS_BeatDefinition, RS_SceneDirective use const preload arrays (mobile-safe, no runtime DirAccess)
- **Beat runner as RefCounted helper**: Pure state machine logic; M_SceneDirector owns the Node lifecycle
- **Both debug + runtime event log**: U_ObjectiveEventLog tracks all objective state transitions
- **M_SceneManager becomes pure loader**: Victory handling moves to objectives; scene manager only handles transitions

**What gets removed from M_SceneManager:**
- `_on_victory_executed()` handler (lines 323-331)
- `_get_victory_target_scene()` method (lines 334-339)
- `_victory_executed_unsubscribe` variable, subscription, cleanup (lines 153, 212, 294-295)
- `C_VICTORY_TRIGGER_COMPONENT` preload (line 36)

**What stays unchanged:**
- `S_VictoryHandlerSystem` -- validates triggers, dispatches state, publishes `victory_executed`
- `S_CheckpointHandlerSystem` -- activates checkpoints, dispatches state
- `_on_entity_death()` in M_SceneManager -- game over transition stays (not objective-driven)
- All QB v2 code (RS_Rule, RS_BaseCondition subclasses, RS_BaseEffect subclasses, U_RuleScorer, U_RuleSelector, RuleStateTracker)

**Documentation location**: `docs/scene_director/`
- Overview: `scene-director-overview.md`
- Plan: `scene-director-plan.md`
- Tasks: `scene-director-tasks.md`
- Continuation prompt: `scene-director-continuation-prompt.md` (this file)

---

## Before Continuing

1. Read `AGENTS.md` for project conventions
2. Read `docs/general/DEV_PITFALLS.md` for known pitfalls
3. Read `docs/scene_director/scene-director-tasks.md` for the task checklist
4. Check task checklist for current progress (look for `[x]` vs `[ ]`)
5. Read `docs/scene_director/scene-director-overview.md` for architecture context
6. Read `docs/scene_director/scene-director-plan.md` for phased implementation details

---

## Key Files to Reference

### v2 QB types used by objectives/beats:
- `scripts/resources/qb/rs_base_condition.gd` -- base condition class; subclasses self-evaluate via `evaluate(context) -> float`
- `scripts/resources/qb/conditions/rs_condition_redux_field.gd` -- reads Redux state paths (primary condition type for objectives)
- `scripts/resources/qb/conditions/rs_condition_event_payload.gd` -- reads event payload fields
- `scripts/resources/qb/conditions/rs_condition_constant.gd` -- fixed score for unconditional beats
- `scripts/resources/qb/rs_base_effect.gd` -- base effect class; subclasses self-execute via `execute(context)`
- `scripts/resources/qb/effects/rs_effect_dispatch_action.gd` -- dispatches Redux action
- `scripts/resources/qb/effects/rs_effect_publish_event.gd` -- publishes ECS event

### Existing patterns to follow:
- `scripts/state/actions/u_gameplay_actions.gd` -- pattern for action creators
- `scripts/state/reducers/u_gameplay_reducer.gd` -- pattern for reducers
- `scripts/state/selectors/u_gameplay_selectors.gd` -- pattern for selectors
- `scripts/resources/state/rs_gameplay_initial_state.gd` -- pattern for initial state resources
- `scripts/state/utils/u_state_slice_manager.gd` -- add new slices here
- `scripts/state/m_state_store.gd` -- add @export for new initial state resources

### Files to modify:
- `scripts/state/utils/u_state_slice_manager.gd` -- add objectives + scene_director slices
- `scripts/state/m_state_store.gd` -- add @export for objectives + scene_director initial state
- `scripts/root.gd` -- register M_ObjectivesManager + M_SceneDirector with ServiceLocator (keys: `"objectives_manager"`, `"scene_director"`)
- `scripts/events/ecs/u_ecs_event_names.gd` -- add objective/directive event constants
- `scripts/managers/m_scene_manager.gd` -- remove victory handling, add objective_victory subscription
- `scenes/root.tscn` -- add M_ObjectivesManager + M_SceneDirector nodes
- `AGENTS.md` -- add `"objectives_manager"` and `"scene_director"` to the available services list in the Quick How-Tos section (Phase 6A)

### Files that stay unchanged:
- `scripts/ecs/systems/s_victory_handler_system.gd` -- stays as-is (93 lines)
- `scripts/ecs/systems/s_checkpoint_handler_system.gd` -- stays as-is
- `scripts/ecs/systems/s_game_event_system.gd` -- stays as-is (v2 name)
- All v2 QB core code

### New files created by this feature:

**Resources** (Phase 1):
- `scripts/resources/scene_director/rs_objective_definition.gd`
- `scripts/resources/scene_director/rs_objective_set.gd`
- `scripts/resources/scene_director/rs_beat_definition.gd`
- `scripts/resources/scene_director/rs_scene_directive.gd`

**State -- Objectives** (Phase 1):
- `scripts/state/actions/u_objectives_actions.gd`
- `scripts/state/reducers/u_objectives_reducer.gd`
- `scripts/state/selectors/u_objectives_selectors.gd`
- `scripts/resources/state/rs_objectives_initial_state.gd`

**State -- Scene Director** (Phase 1):
- `scripts/state/actions/u_scene_director_actions.gd`
- `scripts/state/reducers/u_scene_director_reducer.gd`
- `scripts/state/selectors/u_scene_director_selectors.gd`
- `scripts/resources/state/rs_scene_director_initial_state.gd`

**Helpers** (Phase 2-3):
- `scripts/utils/scene_director/u_objective_graph.gd`
- `scripts/utils/scene_director/u_objective_event_log.gd`
- `scripts/utils/scene_director/u_beat_runner.gd`

**Managers** (Phase 2-3):
- `scripts/managers/m_objectives_manager.gd`
- `scripts/managers/m_scene_director.gd`

**Resource Instances** (Phase 4-5):
- `resources/scene_director/objectives/cfg_obj_level_complete.tres`
- `resources/scene_director/objectives/cfg_obj_game_complete.tres`
- `resources/scene_director/sets/cfg_objset_default.tres`
- `resources/scene_director/directives/cfg_directive_gameplay_base.tres`

**Tests**:
- `tests/unit/scene_director/test_objectives_selectors.gd`
- `tests/unit/scene_director/test_objectives_reducer.gd`
- `tests/unit/scene_director/test_scene_director_selectors.gd`
- `tests/unit/scene_director/test_scene_director_reducer.gd`
- `tests/unit/scene_director/test_objective_graph.gd`
- `tests/unit/scene_director/test_objective_event_log.gd`
- `tests/unit/scene_director/test_objectives_manager.gd`
- `tests/unit/scene_director/test_beat_runner.gd`
- `tests/unit/scene_director/test_scene_director.gd`
- `tests/unit/scene_director/test_victory_migration.gd`
- `tests/integration/scene_director/test_objectives_integration.gd`
- `tests/integration/scene_director/test_scene_director_integration.gd`

---

## Design Summary (Key Decisions)

1. **Manager, not ECS system** -- M_ObjectivesManager and M_SceneDirector extend Node (global game state, not per-entity)
2. **Direct v2 condition/effect evaluation** -- call condition.evaluate(context) and effect.execute(context) directly on typed resources; no utility classes needed
3. **Objectives own dependency graph** -- DAG at objectives layer with cycle detection and topological sort
4. **Victory as objective type** -- VICTORY objectives publish events; M_SceneManager subscribes
5. **Two new Redux slices** -- `objectives` (persistent) and `scene_director` (transient)
6. **Resource-defined everything** -- const preload arrays for mobile compatibility
7. **Beat runner as RefCounted** -- pure state machine; M_SceneDirector owns Node lifecycle
8. **Event log for debugging** -- all objective state transitions logged
9. **S_VictoryHandlerSystem stays as-is** -- validates triggers, dispatches state, publishes events
10. **S_CheckpointHandlerSystem stays as-is** -- no changes needed
11. **M_SceneManager becomes pure loader** -- victory handling removed, subscribes to objective events
12. **`_on_entity_death()` stays in M_SceneManager** -- game over is not objective-driven (yet)
13. **Objective status lifecycle** -- inactive -> active -> completed | failed
14. **auto_activate flag** -- objective activates immediately when the set loads in _ready(); this is "skip inactive state on load", not "activate when an event fires"
15. **Directive selection by conditions** -- highest priority directive matching scene + conditions wins; conditions evaluated via condition.evaluate(context)
16. **Beat wait modes** -- INSTANT (immediate), TIMED (duration), SIGNAL (event-driven)
17. **Context building** -- both M_ObjectivesManager and M_SceneDirector implement `_build_context() -> {"state_store": _store, "redux_state": _store.get_state()}` and pass it to condition.evaluate()/effect.execute() calls; for SIGNAL beats also include `"event_payload"`. RS_ConditionComponentField/RS_ConditionEntityTag not supported (no per-entity context at manager level).
18. **VICTORY completion_event_payload** -- RS_ObjectiveDefinition has `completion_event_payload: Dictionary`; M_ObjectivesManager reads this after effects execute and publishes it as the EVENT_OBJECTIVE_VICTORY_TRIGGERED payload. VICTORY objectives set `{"target_scene": StringName("victory")}` here. This is the general mechanism — not a victory-specific field.
19. **CHECKPOINT type deferred** -- enum value exists so resources can be authored, but M_ObjectivesManager treats CHECKPOINT the same as STANDARD in Phase 1-6; save-trigger behavior is a future phase.
20. **SIGNAL subscription strategy** -- M_SceneDirector pre-scans all beats on directive start, subscribes to unique `wait_event` names via `U_ECSEventBus`, unsubscribes on complete/reset. Stores unsubscribe callables for cleanup.
21. **Event-driven objective evaluation** -- M_ObjectivesManager evaluates objectives only when subscribed events fire (checkpoint_activated, victory_executed, area_complete actions), never per-tick. Milestones, not polls.

---

## Testing Commands

```bash
# Run scene director tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_director -gexit

# Run scene director integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_director -gexit

# Run QB tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/qb -gexit

# Run all ECS tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Run ECS system tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gexit

# Run style tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Run scene manager integration tests (regression check for victory migration)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit
```

---

## GDScript 4.6 Pitfalls to Remember

- `tr` cannot be a static method name (collides with Object.tr)
- `String(value)` fails for arbitrary Variants -- use `str(value)`
- Inner class names must start with a capital letter (no `class _MockFoo`)
- Resource preloading required for mobile (const preload arrays, not runtime DirAccess)

## Context Contract

Both M_ObjectivesManager and M_SceneDirector build a context Dictionary before calling condition/effect methods:

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

**Condition evaluation (binary AND):**
```gdscript
func _check_conditions(conditions: Array[Resource], context: Dictionary) -> bool:
    for condition in conditions:
        if condition.evaluate(context) <= 0.0:
            return false
    return true
```

**Effect execution:**
```gdscript
func _execute_effects(effects: Array[Resource], context: Dictionary) -> void:
    for effect in effects:
        effect.execute(context)
```

**Appropriate condition subclasses for objectives/beats:**
- `RS_ConditionReduxField` -- Redux state checks
- `RS_ConditionEventPayload` -- event payload checks
- `RS_ConditionConstant` -- unconditional / weighting

**Not supported:** `RS_ConditionComponentField`, `RS_ConditionEntityTag` (no per-entity context at manager level)

---

## Commit Strategy

- Commit at the end of each completed phase
- Run full test suite before each commit
- Documentation updates paired with the phase they document
- Update this continuation prompt after each phase with current status
