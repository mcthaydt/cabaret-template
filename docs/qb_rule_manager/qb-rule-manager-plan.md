# QB Rule Manager - Implementation Plan

## Phase 1: Core Framework + Tests

**Goal**: Rule engine infrastructure with full test coverage. One prerequisite change to BaseECSSystem (widen priority clamp), otherwise zero changes to existing systems.

### 1-Pre: Prerequisite -- Widen BaseECSSystem Priority Clamp

`scripts/ecs/base_ecs_system.gd` currently clamps `execution_priority` to `[0, 1000]` (line 22: `clampi(value, 0, 1000)`). Rule managers need to run BEFORE default-0 systems, but M_ECSManager sorts ascending (lower priority values first, `_compare_system_priority` returns `priority_a < priority_b`). Change the clamp to `clampi(value, -100, 1000)` so negative priorities are valid. This is a one-line change with zero behavioral impact on existing systems (all existing systems use priority >= 0).

### 1A: Resource Definitions

**RS_QBCondition** (`scripts/resources/qb/rs_qb_condition.gd`):
- `source: Source` enum (COMPONENT, REDUX, EVENT_PAYLOAD, ENTITY_TAG, CUSTOM)
- `quality_path: String` -- dot-separated path (e.g., "C_HealthComponent.current_health")
- `operator: Operator` enum (EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GTE, LTE, HAS, NOT_HAS, IS_TRUE, IS_FALSE)
- `value_type: ValueType` enum (FLOAT, INT, STRING, BOOL, STRING_NAME) -- selects which typed field to use
- `value_float: float = 0.0`
- `value_int: int = 0`
- `value_string: String = ""`
- `value_bool: bool = false`
- `value_string_name: StringName = &""`
- `negate: bool` -- invert result

**RS_QBEffect** (`scripts/resources/qb/rs_qb_effect.gd`):
- `effect_type: EffectType` enum (DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, SET_QUALITY) -- 4 types, no CALL_METHOD
- `target: String` -- action type, event name, or component.field path
- `payload: Dictionary` -- effect parameters
- `SET_COMPONENT_FIELD` payload contract:
  - `operation: StringName` -- `set` (default) or `add`
  - `value_type: RS_QBCondition.ValueType`
  - typed value fields (`value_float`, `value_int`, `value_string`, `value_bool`, `value_string_name`)
  - optional numeric clamps (`clamp_min`, `clamp_max`)
  - `"add"` allowed only for numeric fields; invalid config is warning + no-op

**RS_QBRuleDefinition** (`scripts/resources/qb/rs_qb_rule_definition.gd`):
- `rule_id: StringName`
- `description: String`
- `conditions: Array[RS_QBCondition]`
- `effects: Array[RS_QBEffect]`
- `priority: int` (higher = evaluated first; ties broken by rule_id alphabetical)
- `is_one_shot: bool`
- `cooldown: float`
- `requires_salience: bool` (default true; auto-disabled for EVENT trigger mode)
- `trigger_mode: TriggerMode` enum (TICK, EVENT, BOTH)
- `trigger_event: StringName`
- `cooldown_key_fields: Array[String] = []` -- Empty = global cooldown. `["entity_id"]` = per-entity. `["zone_id", "entity_id"]` = per-zone-per-entity. Fields resolved from quality context, joined with ":"
- `cooldown_from_context_field: String = ""` -- Empty = use rule.cooldown as duration. Non-empty = read duration from context field

### 1B: Utility Classes (TDD -- stub -> red -> implement -> green)

**U_QBRuleEvaluator** (`scripts/utils/qb/u_qb_rule_evaluator.gd`):
- `static func evaluate_condition(condition: RS_QBCondition, quality_value: Variant) -> bool`
- `static func evaluate_all_conditions(conditions: Array[RS_QBCondition], context: Dictionary) -> bool`
- Pure functions, no side effects, maximally testable
- Uses `condition.value_type` to select which typed field to compare against

**U_QBQualityProvider** (`scripts/utils/qb/u_qb_quality_provider.gd`):
- `static func read_quality(condition: RS_QBCondition, context: Dictionary) -> Variant`
- Reads from components, Redux state, event payloads, or entity tags based on condition.source
- Component path format: "ComponentType.field_name" (e.g., "C_HealthComponent.current_health")
- Redux path format: "slice.field" (e.g., "gameplay.paused", "navigation.shell", "scene.is_transitioning")

**U_QBEffectExecutor** (`scripts/utils/qb/u_qb_effect_executor.gd`):
- `static func execute_effect(effect: RS_QBEffect, context: Dictionary) -> void`
- `static func execute_effects(effects: Array[RS_QBEffect], context: Dictionary) -> void`
- Executes 4 effect types. No CALL_METHOD.
- SET_QUALITY writes to the `context` dictionary (not directly to the component). The calling rule manager copies context → component via `_write_brain_data()` after all rules evaluate. This enables the defaults-each-tick pattern.
- SET_COMPONENT_FIELD applies `set`/`add` operation contract, then optional clamp for numeric fields
- PUBLISH_EVENT merges context (entity_id, event_payload) into published payload:

```gdscript
static func _execute_publish_event(effect: RS_QBEffect, context: Dictionary) -> void:
    var event_payload: Dictionary = effect.payload.duplicate(true)
    if context.has("entity_id") and not event_payload.has("entity_id"):
        event_payload["entity_id"] = context["entity_id"]
    if context.has("event_payload"):
        var original: Dictionary = context["event_payload"]
        for key in original:
            if not event_payload.has(key):
                event_payload[key] = original[key]
    U_ECSEventBus.publish(StringName(effect.target), event_payload)
```

**U_QBRuleValidator** (`scripts/utils/qb/u_qb_rule_validator.gd`):
- `static func validate_rule(rule: RS_QBRuleDefinition) -> Array[String]` -- returns list of error messages
- Validates: rule_id not empty, conditions have valid paths, effects have valid targets, EVENT rules have trigger_event set

### 1C: Base Rule Manager (TDD)

**BaseQBRuleManager** (`scripts/ecs/systems/base_qb_rule_manager.gd`):
- Extends `BaseECSSystem`, default `execution_priority = -1` (runs before default-0 systems in ascending sort)
- `@export var state_store: I_StateStore = null`
- `@export var rule_definitions: Array[RS_QBRuleDefinition] = []`
- `get_default_rule_definitions() -> Array[RS_QBRuleDefinition]` virtual
- Runtime state: `_rule_states: Dictionary` (rule_id -> {active, last_fired, was_true, cooldown_remaining, context_cooldowns: Dictionary})
- `on_configured()` -- if exported `rule_definitions` is empty, load from `get_default_rule_definitions()`; then register rules and subscribe to trigger events
- `process_tick(delta)` -- tick cooldowns; subclass loops over target entities
- `_on_event_received(event_name, payload)` -- evaluate EVENT/BOTH rules (salience auto-disabled for EVENT)
- `_build_quality_context(entity, delta) -> Dictionary` -- virtual, subclasses override
- `_evaluate_rules_for_context(context) -> void` -- evaluate all matching rules
- `_register_rules(definitions)` -- init state, sort by priority then rule_id alphabetical
- `_tick_cooldowns(delta)` -- decrement global + per-context cooldowns
- `_resolve_cooldown_key(rule, context) -> String` -- composite key from cooldown_key_fields
- No `_handle_effect()` virtual -- effects fully processed by U_QBEffectExecutor

Entity iteration pattern (in subclass process_tick):
```gdscript
func process_tick(delta: float) -> void:
    _tick_cooldowns(delta)
    var components: Array = get_components(C_CharacterStateComponent.COMPONENT_TYPE)
    for entry in components:
        var char_state := entry as C_CharacterStateComponent
        if char_state == null: continue
        var context := _build_quality_context(char_state, delta)
        _evaluate_rules_for_context(context)
        _write_brain_data(char_state, context)
```

### 1D: Tests

| Test File | Coverage |
|-----------|----------|
| `tests/unit/qb/test_qb_condition_evaluation.gd` | All operators x typed values, negate, null, type mismatches |
| `tests/unit/qb/test_qb_quality_provider.gd` | All source types, missing paths, nested fields |
| `tests/unit/qb/test_qb_effect_execution.gd` | All 4 effect types, SET_COMPONENT_FIELD `set`/`add`/clamp behavior, context injection for PUBLISH_EVENT |
| `tests/unit/qb/test_qb_rule_validator.gd` | Valid/invalid rules, EVENT without trigger_event |
| `tests/unit/qb/test_qb_rule_lifecycle.gd` | Cooldown, salience (false->true), one-shot, priority ordering, event salience auto-disable, per-context cooldown, cooldown_from_context_field, default-rule fallback when export array is empty |

### 1E: Regression check + commit

---

## Phase 2: Character State Component + Rule Manager

**Goal**: Create brain data component and rule manager. Existing systems unchanged -- nobody reads from C_CharacterStateComponent yet.

### 2A: C_CharacterStateComponent

`scripts/ecs/components/c_character_state_component.gd` -- extends `BaseECSComponent`

Brain data fields (written by S_CharacterRuleManager each tick):
- `is_gameplay_active: bool` -- not paused, not transitioning, shell == "gameplay"
- `is_grounded: bool` -- on floor or floating supported
- `is_moving: bool` -- horizontal velocity > threshold
- `is_spawn_frozen: bool` -- physics frozen during spawn
- `is_dead: bool` -- health <= 0 (synced from C_HealthComponent)
- `is_invincible: bool` -- invincibility window active
- `health_percent: float` -- current/max ratio
- `vertical_state: int` -- -1 falling, 0 grounded, 1 rising
- `has_input: bool` -- movement input magnitude > 0

### 2B: S_CharacterRuleManager (TDD)

`scripts/ecs/systems/s_character_rule_manager.gd` -- extends `BaseQBRuleManager`

- `_build_quality_context(entity, delta)` -- initializes context with defaults, then reads current state:
  - **Defaults** (reset every tick): `is_gameplay_active = true`, `is_spawn_frozen = false`, `is_dead = false`
  - **Reads** (from components): `is_grounded`, `is_moving`, `has_input`, `health_percent`, `vertical_state`, `is_invincible` from C_HealthComponent, C_MovementComponent, C_InputComponent, C_SpawnStateComponent, C_FloatingComponent
  - **Reads** (from Redux via state_store): `gameplay` and `navigation` and `scene` slices for rule conditions
- SET_QUALITY effects override defaults in the context dictionary (not the component directly)
- `_write_brain_data(char_state, context)` -- copies final context values to C_CharacterStateComponent after all rules evaluate
- `get_default_rule_definitions()` returns const-preloaded character rule resources (pause gate x3 + spawn freeze + death sync when Phase 3 lands)
- No CALL_METHOD handlers -- all complex effects are PUBLISH_EVENT

### 2C: Rule .tres Files

| File | Conditions | Effects |
|------|-----------|---------|
| `resources/qb/character/cfg_pause_gate_paused.tres` | REDUX `gameplay.paused == true` | SET_QUALITY `is_gameplay_active = false` |
| `resources/qb/character/cfg_pause_gate_shell.tres` | REDUX `navigation.shell != "gameplay"` | SET_QUALITY `is_gameplay_active = false` |
| `resources/qb/character/cfg_pause_gate_transitioning.tres` | REDUX `scene.is_transitioning == true` | SET_QUALITY `is_gameplay_active = false` |
| `resources/qb/character/cfg_spawn_freeze_rule.tres` | COMPONENT `C_SpawnStateComponent.is_physics_frozen == true` | SET_QUALITY `is_spawn_frozen = true` |

All pause gate and spawn freeze rules use `requires_salience: false` (SET_QUALITY must fire every tick to maintain the override, since brain data resets to defaults each tick).

### 2D: Scene Integration

- Add `C_CharacterStateComponent` to `scenes/templates/tmpl_character.tscn` and `scenes/prefabs/prefab_player.tscn`
- Add `S_CharacterRuleManager` to all 5 gameplay scenes (gameplay_base, interior_house, bar, exterior, alleyway)
- Rule wiring pattern: leave `rule_definitions` export empty in scenes to use manager defaults; only set it explicitly for overrides/tests

### 2E: Tests + regression check + commit

---

## Phase 3: System Gating Consolidation + Death Handler

**Goal**: Existing systems read brain data instead of duplicating gating logic. Ragdoll logic extracts to handler.

### 3A: Pause Gating (6 systems)

Replace independent pause checks with `C_CharacterStateComponent.is_gameplay_active`:

| System | Current Pattern (remove) | New Pattern |
|--------|------------------------|-------------|
| `S_MovementSystem` (lines 22-34) | Store lookup -> `get_is_paused()` | Read `is_gameplay_active` from brain data |
| `S_JumpSystem` (lines 21-34) | Same | Same |
| `S_GravitySystem` (lines 17-29) | Same | Same |
| `S_RotateToInputSystem` (lines 21-33) | Same | Same |
| `S_InputSystem` (lines 80-84) | Same | Same |
| `S_FootstepSoundSystem` (lines 46-56) | `try_get_store` variant | Look up character's brain data component |

### 3B: Spawn Freeze (3 systems -- each keeps different side effects)

| System | Side Effect (keep) |
|--------|-------------------|
| `S_MovementSystem` | Reset velocity to zero, reset dynamics state |
| `S_JumpSystem` | Flag debug snapshot with `spawn_frozen: true` |
| `S_FloatingSystem` | Update support state even while frozen |

### 3C: Death Handler System

Extract ragdoll logic from `S_HealthSystem` (lines 167-284) into `scripts/ecs/systems/s_death_handler_system.gd`:

**Moves to handler**: `_spawn_ragdoll()`, `_restore_entity_state()`, `get_ragdoll_for_entity()`, PLAYER_RAGDOLL preload, `_rng`, `_ragdoll_spawned`, `_ragdoll_instances`, `_entity_refs`, `_entity_original_visibility`

**Stays in S_HealthSystem**: All damage/heal/regen/death-timer/invincibility logic. `_handle_death_sequence()` changes from calling `_spawn_ragdoll()` to publishing `entity_death_requested` event. `_reset_death_flags()` publishes `entity_respawn_requested`.

**New event names** in `U_ECSEventNames`:
- `EVENT_ENTITY_DEATH_REQUESTED := StringName("entity_death_requested")`
- `EVENT_ENTITY_RESPAWN_REQUESTED := StringName("entity_respawn_requested")`

**Canonical payload contract**:
- `entity_death_requested`: requires `entity_id: String`; optional `health_component`, `entity_root`, `body`
- `entity_respawn_requested`: requires `entity_id: String`; optional `entity_root`

Both publisher and handler must use the event bus payload envelope shape (`event["payload"]`).

**Handler pattern**:
```gdscript
class_name S_DeathHandlerSystem extends BaseECSSystem
# Subscribes to entity_death_requested -> spawns ragdoll, hides entity
# Subscribes to entity_respawn_requested -> frees ragdoll, restores visibility
```

### 3D: Brain Data Death Sync Rule

`resources/qb/character/cfg_death_sync_rule.tres`:
- Trigger: TICK, requires_salience: false
- Condition: COMPONENT `C_HealthComponent.is_dead == true`
- Effect: SET_QUALITY `is_dead = true`

(This syncs the flag to brain data -- actual death detection stays in S_HealthSystem)

### 3E: Integration Test

`tests/integration/qb/test_qb_brain_data_pipeline.gd`:
- Verify end-to-end: S_CharacterRuleManager populates brain data -> S_MovementSystem reads `is_gameplay_active` and gates correctly
- Test with MockStateStore returning paused=true -> brain data `is_gameplay_active=false` -> movement system returns early
- Test with MockStateStore returning paused=false, shell="gameplay", is_transitioning=false -> brain data `is_gameplay_active=true` -> movement system processes normally

### 3F: Tests + full regression + manual playtest + commit

---

## Phase 4: Game State Rules (Checkpoint + Victory)

**Goal**: Replace S_CheckpointSystem and S_VictorySystem with rule + handler pairs. S_DamageSystem stays as-is.

### 4A: Event Name Centralization

Add to `scripts/events/ecs/u_ecs_event_names.gd`:
```
EVENT_CHECKPOINT_ZONE_ENTERED, EVENT_CHECKPOINT_ACTIVATED,
EVENT_CHECKPOINT_ACTIVATION_REQUESTED,
EVENT_VICTORY_TRIGGERED, EVENT_VICTORY_EXECUTION_REQUESTED,
EVENT_DAMAGE_ZONE_ENTERED, EVENT_DAMAGE_ZONE_EXITED
```

Update S_CheckpointSystem, S_VictorySystem, S_DamageSystem to use centralized constants.

### 4B: S_GameRuleManager

`scripts/ecs/systems/s_game_rule_manager.gd` -- extends `BaseQBRuleManager`

Simple event-rule host (no custom `process_tick` iteration). Holds checkpoint and victory rules. EVENT-triggered rules fire via `_on_event_received()`.
- `get_default_rule_definitions()` returns const-preloaded game rule resources (`cfg_checkpoint_rule`, `cfg_victory_rule`)

### 4C: Handler Systems

**`scripts/ecs/systems/s_checkpoint_handler_system.gd`** (replaces S_CheckpointSystem):
- Subscribes to `checkpoint_activation_requested`
- `checkpoint.activate()`, dispatch `set_last_checkpoint`, resolve spawn position via `_resolve_spawn_point_position()` (replicate from S_CheckpointSystem lines 90-109 — `find_child` traversal for perf optimization), publish typed `Evn_CheckpointActivated`
- `execution_priority = 100`
- Expects payload contract in `event["payload"]`: required `checkpoint`, `spawn_point_id`; optional `entity_id`

**`scripts/ecs/systems/s_victory_handler_system.gd`** (replaces S_VictorySystem):
- Subscribes to `victory_execution_requested` (with subscription priority 10, matching S_VictorySystem's current priority to process before scene manager at priority 5)
- Validate trigger (`trigger_once` + `is_triggered` guard), check prerequisites (GAME_COMPLETE requires `completed_areas.has("bar")` — replicate `REQUIRED_FINAL_AREA` constant and `_can_trigger_victory()` logic from S_VictorySystem lines 56-73), dispatch actions (`trigger_victory`, `mark_area_complete`, `game_complete`), call `trigger.set_triggered()`
- `execution_priority = 300`
- Expects payload contract in `event["payload"]`: required `trigger_node`; optional `entity_id`

### 4D: Rule .tres Files

| File | Trigger | Effects |
|------|---------|---------|
| `resources/qb/game/cfg_checkpoint_rule.tres` | EVENT: `checkpoint_zone_entered` | PUBLISH_EVENT: `checkpoint_activation_requested` (forwards event payload, preserving required `checkpoint` + `spawn_point_id`) |
| `resources/qb/game/cfg_victory_rule.tres` | EVENT: `victory_triggered` | PUBLISH_EVENT: `victory_execution_requested` (forwards event payload, preserving required `trigger_node`) |

### 4E: Migration

- Remove S_CheckpointSystem and S_VictorySystem from gameplay scenes
- Add S_GameRuleManager, S_CheckpointHandlerSystem, S_VictoryHandlerSystem
- S_DamageSystem stays (just centralized event names)

### 4F: Tests + regression + commit

---

## Phase 5: Camera State Rules (Additive)

**Goal**: Rule-driven camera shake and FOV zones. Purely additive -- M_CameraManager unchanged.

### 5A: C_CameraStateComponent

`scripts/ecs/components/c_camera_state_component.gd`:
- `target_fov: float = 75.0`, `shake_trauma: float = 0.0`, `fov_blend_speed: float = 2.0`

### 5B: S_CameraRuleManager + Rules

- `SET_COMPONENT_FIELD` for trauma addition on damage events
  - `target = "C_CameraStateComponent.shake_trauma"`
  - `payload.operation = "add"`
  - `payload.value_type = FLOAT`
  - optional clamp to keep trauma in valid range
- `SET_COMPONENT_FIELD` for FOV zone blending on tick
  - `target = "C_CameraStateComponent.target_fov"`
  - `payload.operation = "set"`
  - `payload.value_type = FLOAT`
- `get_default_rule_definitions()` returns const-preloaded camera rules
- Wire to M_CameraManager for actual camera application

### 5C: Tests + commit

---

## Phase 6: Validation + Final Verification

- Enhance U_QBRuleValidator with load-time validation in `on_configured()`
- Run full test suite (ECS + QB + style)
- Manual playtest: full gameplay loop
- Update AGENTS.md with QB Rule Manager patterns section
- Commit

---

## Files Summary

### New Files (Core)
```
scripts/resources/qb/rs_qb_condition.gd
scripts/resources/qb/rs_qb_effect.gd
scripts/resources/qb/rs_qb_rule_definition.gd
scripts/ecs/systems/base_qb_rule_manager.gd
scripts/utils/qb/u_qb_rule_evaluator.gd
scripts/utils/qb/u_qb_quality_provider.gd
scripts/utils/qb/u_qb_effect_executor.gd
scripts/utils/qb/u_qb_rule_validator.gd
```

### New Files (Domain)
```
scripts/ecs/components/c_character_state_component.gd
scripts/ecs/systems/s_character_rule_manager.gd
scripts/ecs/systems/s_death_handler_system.gd
scripts/ecs/systems/s_game_rule_manager.gd
scripts/ecs/systems/s_checkpoint_handler_system.gd
scripts/ecs/systems/s_victory_handler_system.gd
scripts/ecs/components/c_camera_state_component.gd
scripts/ecs/systems/s_camera_rule_manager.gd
```

### New Files (Rules)
```
resources/qb/character/cfg_pause_gate_paused.tres
resources/qb/character/cfg_pause_gate_shell.tres
resources/qb/character/cfg_pause_gate_transitioning.tres
resources/qb/character/cfg_spawn_freeze_rule.tres
resources/qb/character/cfg_death_sync_rule.tres
resources/qb/game/cfg_checkpoint_rule.tres
resources/qb/game/cfg_victory_rule.tres
resources/qb/camera/cfg_camera_shake_rule.tres
resources/qb/camera/cfg_camera_zone_fov_rule.tres
```

### Modified Files
```
scripts/ecs/base_ecs_system.gd                   -- Widen priority clamp from [0,1000] to [-100,1000] (Phase 1 prerequisite)
scripts/ecs/systems/s_health_system.gd          -- Extract ragdoll logic (lines 167-284), publish events
scripts/ecs/systems/s_movement_system.gd        -- Read brain data for pause/freeze (keep @export state_store for entity snapshots)
scripts/ecs/systems/s_jump_system.gd             -- Read brain data for pause/freeze (keep @export state_store for accessibility reads)
scripts/ecs/systems/s_gravity_system.gd          -- Read brain data for pause (keep @export state_store for gravity_scale reads)
scripts/ecs/systems/s_rotate_to_input_system.gd  -- Read brain data for pause (keep @export state_store for rotation snapshot dispatch)
scripts/ecs/systems/s_input_system.gd            -- Read brain data for pause (keep @export state_store for other checks)
scripts/ecs/systems/s_footstep_sound_system.gd   -- Read brain data for pause (can remove @export state_store entirely)
scripts/ecs/systems/s_floating_system.gd         -- Read brain data for freeze
scripts/ecs/systems/s_damage_system.gd           -- Centralize event name constants only
scripts/events/ecs/u_ecs_event_names.gd          -- Add new event constants
scenes/templates/tmpl_character.tscn             -- Add C_CharacterStateComponent
scenes/prefabs/prefab_player.tscn                -- Add C_CharacterStateComponent
scenes/gameplay/*.tscn (5 scenes)                -- Add rule managers + handler systems
```

### Test Files
```
tests/unit/qb/test_qb_condition_evaluation.gd
tests/unit/qb/test_qb_quality_provider.gd
tests/unit/qb/test_qb_effect_execution.gd
tests/unit/qb/test_qb_rule_validator.gd
tests/unit/qb/test_qb_rule_lifecycle.gd
tests/unit/qb/test_character_rule_manager.gd
tests/unit/qb/test_death_handler_system.gd
tests/unit/qb/test_game_rule_manager.gd
tests/unit/qb/test_checkpoint_handler_system.gd
tests/unit/qb/test_victory_handler_system.gd
tests/unit/qb/test_camera_rule_manager.gd
tests/integration/qb/test_qb_brain_data_pipeline.gd
```

## Critical Files Reference

| Existing File | Relevance |
|---------------|-----------|
| `scripts/ecs/base_ecs_system.gd` | Base class for BaseQBRuleManager; Phase 1 prerequisite: widen priority clamp line 22 from `clampi(value, 0, 1000)` to `clampi(value, -100, 1000)` |
| `scripts/ecs/base_ecs_component.gd` | Base class for C_CharacterStateComponent |
| `scripts/ecs/systems/s_health_system.gd` | Extract ragdoll logic (lines 167-284), publish death events |
| `scripts/ecs/systems/s_movement_system.gd` | Pause/freeze gating consolidation (lines 22-34) |
| `scripts/ecs/systems/s_jump_system.gd` | Pause/freeze gating consolidation (lines 21-34) |
| `scripts/ecs/systems/s_gravity_system.gd` | Pause gating consolidation (lines 17-29) |
| `scripts/ecs/systems/s_rotate_to_input_system.gd` | Pause gating consolidation (lines 21-33) |
| `scripts/ecs/systems/s_input_system.gd` | Pause gating consolidation (lines 80-84) |
| `scripts/ecs/systems/s_footstep_sound_system.gd` | Pause gating consolidation (lines 46-56) |
| `scripts/ecs/systems/s_floating_system.gd` | Freeze check only (no pause check) |
| `scripts/ecs/systems/s_checkpoint_system.gd` | Replaced by checkpoint rule + handler |
| `scripts/ecs/systems/s_victory_system.gd` | Replaced by victory rule + handler |
| `scripts/ecs/systems/s_damage_system.gd` | Stays as-is, centralize event names only |
| `scripts/events/ecs/u_ecs_event_names.gd` | Centralize event constants |
| `scripts/events/ecs/u_ecs_event_bus.gd` | Event subscription for rule triggers |
| `scripts/interfaces/i_state_store.gd` | DI interface for store access |
| `scripts/managers/m_camera_manager.gd` | Camera rules integrate with (not replace) |
| `scenes/templates/tmpl_character.tscn` | Add C_CharacterStateComponent |
| `scenes/prefabs/prefab_player.tscn` | Add C_CharacterStateComponent |
| `tests/mocks/` | MockStateStore, MockECSManager for testing |
