# QB Rule Manager - Implementation Plan

## Phase 1: Core Framework + Tests

**Goal**: Build the rule engine infrastructure with full test coverage. Zero changes to existing systems.

### 1.1 Resource Definitions

Create the three core resource classes:

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
- `effect_type: EffectType` enum (DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, CALL_METHOD, SET_QUALITY)
- `target: String` -- action type, event name, component.field path, or handler method name
- `payload: Dictionary` -- effect parameters
- No `delay` field in Phase 1 (deferred to post-Phase 6)

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

### 1.2 Utility Classes

**U_QBRuleEvaluator** (`scripts/utils/qb/u_qb_rule_evaluator.gd`):
- `static func evaluate_condition(condition: RS_QBCondition, quality_value: Variant) -> bool`
- `static func evaluate_all_conditions(conditions: Array[RS_QBCondition], context: Dictionary) -> bool`
- Pure functions, no side effects, maximally testable
- Uses `condition.value_type` to select which typed field to compare against

**U_QBEffectExecutor** (`scripts/utils/qb/u_qb_effect_executor.gd`):
- `static func execute_effect(effect: RS_QBEffect, context: Dictionary) -> void`
- `static func execute_effects(effects: Array[RS_QBEffect], context: Dictionary) -> void`
- Context dictionary carries store reference, event bus, component references
- CALL_METHOD effects delegate to `rule_manager._handle_effect(effect, context)`

**U_QBQualityProvider** (`scripts/utils/qb/u_qb_quality_provider.gd`):
- `static func read_quality(condition: RS_QBCondition, context: Dictionary) -> Variant`
- Reads from components, Redux state, event payloads, or entity tags based on condition.source
- Component path format: "ComponentType.field_name" (e.g., "C_HealthComponent.current_health")
- Redux path format: "slice.field" (e.g., "gameplay.is_dead")

**U_QBRuleValidator** (`scripts/utils/qb/u_qb_rule_validator.gd`):
- `static func validate_rule(rule: RS_QBRuleDefinition) -> Array[String]` -- returns list of error messages
- Validates: rule_id not empty, conditions have valid paths, effects have valid targets, EVENT rules have trigger_event set

### 1.3 Base Rule Manager

**BaseQBRuleManager** (`scripts/ecs/systems/base_qb_rule_manager.gd`):
- Extends `BaseECSSystem`, default `execution_priority = 1`
- `@export var state_store: I_StateStore = null`
- `@export var rule_definitions: Array[RS_QBRuleDefinition] = []`
- Runtime state: `_rule_states: Dictionary` (rule_id -> {active, last_fired, was_true, cooldown_remaining})
- `_event_unsubscribes: Array[Callable]` for cleanup
- `on_configured()` -- register rules, subscribe to trigger events
- `process_tick(delta)` -- tick cooldowns; subclass loops over target entities calling `_evaluate_rules_for_context(context)`
- `_on_event_received(event_name, payload)` -- evaluate EVENT/BOTH rules; salience auto-disabled for EVENT mode
- `_build_quality_context(entity, delta) -> Dictionary` -- virtual, subclasses override
- `_evaluate_rules_for_context(context) -> void` -- evaluate all matching rules against a quality context
- `_handle_effect(effect, context) -> void` -- virtual, subclasses override for CALL_METHOD effects
- `_register_rules(definitions)` -- initialize rule runtime state, sort by priority then rule_id
- `_tick_cooldowns(delta)` -- decrement cooldown_remaining for all rules
- `_exit_tree()` -- unsubscribe from events

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

### 1.4 Tests

**test_qb_condition_evaluation.gd** (`tests/unit/qb/`):
- Test every Operator variant against float, int, String, bool, StringName typed values
- Test negate flag
- Test null/missing quality value handling
- Test type mismatches (comparing string to int gracefully)

**test_qb_effect_execution.gd** (`tests/unit/qb/`):
- Test DISPATCH_ACTION with MockStateStore
- Test PUBLISH_EVENT with U_ECSEventBus subscription
- Test SET_COMPONENT_FIELD
- Test SET_QUALITY
- Test CALL_METHOD delegation to _handle_effect

**test_qb_rule_lifecycle.gd** (`tests/unit/qb/`):
- Test cooldown: rule fires, then blocked until cooldown expires
- Test salience: rule only fires on false->true transition, not while continuously true
- Test one-shot: rule fires once, then is_active becomes false
- Test priority: higher priority rules evaluated first; ties broken by rule_id alphabetical
- Test EVENT trigger mode: rule only evaluated when matching event arrives
- Test BOTH trigger mode: rule evaluated on tick AND on matching event
- Test event salience auto-disable: EVENT mode rules ignore requires_salience

**test_qb_quality_provider.gd** (`tests/unit/qb/`):
- Test COMPONENT source reading from component dictionary
- Test REDUX source reading from state dictionary
- Test EVENT_PAYLOAD source reading from event payload
- Test ENTITY_TAG source with HAS/NOT_HAS operators
- Test missing/null quality paths return null gracefully

**test_qb_rule_validator.gd** (`tests/unit/qb/`):
- Test valid rule passes validation
- Test empty rule_id fails
- Test EVENT mode without trigger_event fails
- Test condition with empty quality_path fails

---

## Phase 2: Character State Component + Rule Manager

**Goal**: Create the character brain data component and rule manager. Existing systems unchanged -- nobody reads from C_CharacterStateComponent yet.

### 2.1 C_CharacterStateComponent

`scripts/ecs/components/c_character_state_component.gd`:
- Extends `BaseECSComponent`
- `const COMPONENT_TYPE := StringName("C_CharacterStateComponent")`
- Computed qualities (written by S_CharacterRuleManager each tick):
  - `is_gameplay_active: bool = true` -- not paused, not transitioning
  - `is_grounded: bool = false` -- on floor or floating supported
  - `is_moving: bool = false` -- horizontal velocity > threshold
  - `is_sprinting: bool = false` -- sprint input active
  - `is_spawn_frozen: bool = false` -- physics frozen during spawn
  - `is_dead: bool = false` -- health <= 0
  - `is_invincible: bool = false` -- invincibility window active
  - `health_percent: float = 1.0` -- current/max health ratio
  - `vertical_state: int = 0` -- -1 falling, 0 grounded, 1 rising
  - `has_input: bool = false` -- movement input magnitude > 0

### 2.2 S_CharacterRuleManager

`scripts/ecs/systems/s_character_rule_manager.gd`:
- Extends `BaseQBRuleManager` (inherits execution_priority=1)
- `_build_quality_context(entity, delta)` -- reads from C_HealthComponent, C_MovementComponent, C_InputComponent, C_SpawnStateComponent, C_FloatingComponent and builds quality dictionary
- After rule evaluation, writes computed qualities to C_CharacterStateComponent
- Queries entities that have C_CharacterStateComponent
- CALL_METHOD handlers: `_handle_spawn_ragdoll(context)`, `_handle_mark_dead(context)`

### 2.3 Scene Integration

- Add C_CharacterStateComponent to `scenes/templates/tmpl_character.tscn` and `scenes/prefabs/prefab_player.tscn`
- Add S_CharacterRuleManager to all 5 gameplay scenes (gameplay_base, interior_house, bar, exterior, alleyway)
- Author pause gate rules (TWO .tres files for OR logic) and spawn freeze rule

### 2.4 Tests

**test_character_rule_manager.gd** (`tests/unit/qb/`):
- Test brain data population from mock components
- Test pause gate rule sets is_gameplay_active = false when paused
- Test pause gate rule sets is_gameplay_active = false when shell != "gameplay"
- Test spawn freeze rule sets is_spawn_frozen = true when frozen
- Use MockECSManager + MockStateStore for isolation

---

## Phase 3: Character System Gating Consolidation

**Goal**: Existing systems read from C_CharacterStateComponent instead of duplicating gating logic.

### 3.1 Systems to Modify for Pause Gating (5 systems -- verified)

Each system currently has its own independent pause check. Replace with read from C_CharacterStateComponent.is_gameplay_active:

1. **S_MovementSystem** (lines 23-34) -- remove independent pause check
2. **S_JumpSystem** (lines 22-34) -- remove pause check
3. **S_GravitySystem** (lines 18-29) -- remove pause check
4. **S_RotateToInputSystem** (lines 22-33) -- remove pause check
5. **S_InputSystem** (lines 80-84) -- remove pause check

### 3.2 Systems to Modify for Spawn Freeze (3 systems -- each with DIFFERENT side effects)

Each system reads `is_spawn_frozen` from C_CharacterStateComponent but keeps its own freeze behavior:

1. **S_MovementSystem**: Resets velocity to zero, resets dynamics state
2. **S_JumpSystem**: Flags debug snapshot with `spawn_frozen: true`
3. **S_FloatingSystem**: Updates support state even while frozen

### 3.3 Systems NOT Modified

- **S_AlignWithSurfaceSystem**: No pause check, no freeze check currently -- do NOT add gating
- **S_FloatingSystem**: No pause check currently -- do NOT add pause gating (only freeze check)

### 3.4 Death Sequence Rules

- Create `cfg_death_sequence_rule.tres` -- conditions: health <= 0, not already dead; effects: CALL_METHOD _handle_mark_dead, DISPATCH_ACTION trigger_death, CALL_METHOD _handle_spawn_ragdoll
- Create `cfg_invincibility_rule.tres` -- conditions: damage received event, not invincible; effects: trigger invincibility
- Migrate S_HealthSystem death-triggering to CALL_METHOD rule chain (timer ticking, regen math, damage queue processing STAY in S_HealthSystem)

### 3.5 Verification

- Run full existing ECS test suite -- all tests must pass (behavioral equivalence)
- Run QB unit tests
- Manual playtest: movement, jumping, death/respawn, pause/unpause, spawn freeze

---

## Phase 4: Game State Rules + Damage Zone

**Goal**: Replace S_CheckpointSystem and S_VictorySystem with declarative rules. Migrate S_DamageSystem zone-overlap logic.

### 4.1 S_GameRuleManager

`scripts/ecs/systems/s_game_rule_manager.gd`:
- Extends `BaseQBRuleManager`
- Subscribes to: `checkpoint_zone_entered`, `victory_triggered`, `damage_zone_entered` events
- Rule evaluation context includes Redux gameplay slice
- No C_GameStateComponent needed -- game rules are purely event-driven

### 4.2 Rule Definitions

- `cfg_checkpoint_activation_rule.tres`:
  - Trigger: EVENT (checkpoint_zone_entered)
  - Conditions: event has checkpoint data, checkpoint not already activated
  - Effects: CALL_METHOD activate checkpoint, DISPATCH_ACTION set_last_checkpoint, PUBLISH_EVENT checkpoint_activated

- `cfg_victory_area_rule.tres`:
  - Trigger: EVENT (victory_triggered)
  - Conditions: trigger_node valid, not already triggered, dependencies met
  - Effects: DISPATCH_ACTION trigger_victory, DISPATCH_ACTION mark_area_complete

- `cfg_victory_game_complete_rule.tres`:
  - Trigger: EVENT (victory_triggered)
  - Conditions: victory_type == GAME_COMPLETE, completed_areas HAS required_final_area
  - Effects: DISPATCH_ACTION game_complete

- `cfg_damage_zone_rule.tres`:
  - Trigger: EVENT (damage_zone_entered)
  - Conditions: zone overlap + player tag check + cooldown
  - Effects: CALL_METHOD queue damage to health component

### 4.3 Migration

- Replace S_CheckpointSystem with checkpoint rules
- Replace S_VictorySystem with victory rules
- Migrate S_DamageSystem zone-overlap logic to damage zone rules
- S_CheckpointSystem._resolve_spawn_point_position() resolves position and includes it in the event payload -- rules consume this

### 4.4 Tests

**test_game_rule_manager.gd**:
- Test checkpoint activation via mock event
- Test victory trigger with prereqs met / not met
- Test game complete with all areas / missing areas
- Test damage zone with player tag / cooldown

---

## Phase 5: Camera State Rules

**Goal**: Add rule-driven camera behaviors. Purely additive -- M_CameraManager unchanged.

### 5.1 C_CameraStateComponent

`scripts/ecs/components/c_camera_state_component.gd`:
- `target_fov: float = 75.0`
- `shake_trauma: float = 0.0`
- `fov_blend_speed: float = 2.0`

### 5.2 S_CameraRuleManager

`scripts/ecs/systems/s_camera_rule_manager.gd`:
- Extends `BaseQBRuleManager`
- Reads C_CameraStateComponent, evaluates camera rules
- Applies shake trauma to M_CameraManager
- Applies FOV changes to camera

### 5.3 Rule Definitions

- `cfg_camera_shake_rule.tres`:
  - Trigger: EVENT (entity_death, health_changed)
  - Effects: SET_COMPONENT_FIELD shake_trauma += value

- `cfg_camera_zone_fov_rule.tres`:
  - Trigger: TICK
  - Conditions: entity in FOV zone
  - Effects: SET_COMPONENT_FIELD target_fov = zone_fov

### 5.4 Tests

**test_camera_rule_manager.gd**:
- Test shake trauma applied on damage event
- Test FOV blending when zone condition met

---

## Phase 6: Documentation + Validation + Anti-Patterns

**Goal**: Finalize documentation, add editor validation, update project-level docs.

### 6.1 Documentation

- Finalize all docs in `docs/qb_rule_manager/`
- Add anti-patterns section to overview
- Update continuation prompt with final status

### 6.2 Validation Tooling

- U_QBRuleValidator validates all rules at load time (called in on_configured)
- Push warnings for: empty rule_id, EVENT mode without trigger_event, invalid quality_path format
- Rule validation at load time

### 6.3 Project-Level Updates

- Update `AGENTS.md` with QB Rule Manager patterns section
- Update `docs/general/DEV_PITFALLS.md` if new pitfalls found

### 6.4 Final Verification

- Run full test suite (ECS + QB + style)
- Manual playtest: full gameplay loop (walk, jump, take damage, die, respawn, checkpoint, victory)

---

## Critical Files Reference

| Existing File | Relevance |
|---------------|-----------|
| `scripts/ecs/base_ecs_system.gd` | Base class for BaseQBRuleManager |
| `scripts/ecs/base_ecs_component.gd` | Base class for C_CharacterStateComponent |
| `scripts/ecs/systems/s_health_system.gd` | Primary refactor target (death sequence) |
| `scripts/ecs/systems/s_movement_system.gd` | Pause/freeze gating consolidation (lines 23-34) |
| `scripts/ecs/systems/s_jump_system.gd` | Pause/freeze gating consolidation (lines 22-34) |
| `scripts/ecs/systems/s_gravity_system.gd` | Pause gating consolidation (lines 18-29) |
| `scripts/ecs/systems/s_rotate_to_input_system.gd` | Pause gating consolidation (lines 22-33) |
| `scripts/ecs/systems/s_input_system.gd` | Pause gating consolidation (lines 80-84) |
| `scripts/ecs/systems/s_floating_system.gd` | Freeze check only (no pause check) |
| `scripts/ecs/systems/s_checkpoint_system.gd` | Replaced by game rules |
| `scripts/ecs/systems/s_victory_system.gd` | Replaced by game rules |
| `scripts/ecs/systems/s_damage_system.gd` | Zone-overlap logic migrated to game rules |
| `scripts/events/ecs/u_ecs_event_bus.gd` | Event subscription for rule triggers |
| `scripts/interfaces/i_state_store.gd` | DI interface for store access |
| `scripts/managers/m_camera_manager.gd` | Camera rules integrate with (not replace) |
| `scenes/templates/tmpl_character.tscn` | Add C_CharacterStateComponent |
| `scenes/prefabs/prefab_player.tscn` | Add C_CharacterStateComponent |
| `tests/mocks/` | MockStateStore, MockECSManager for testing |
