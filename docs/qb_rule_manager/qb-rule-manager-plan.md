# QB Rule Manager - Implementation Plan

## Phase 1: Core Framework + Tests

**Goal**: Build the rule engine infrastructure with full test coverage. Zero changes to existing systems.

### 1.1 Resource Definitions

Create the three core resource classes:

**RS_QBCondition** (`scripts/resources/qb/rs_qb_condition.gd`):
- `source: Source` enum (COMPONENT, REDUX, EVENT_PAYLOAD, ENTITY_TAG, CUSTOM)
- `quality_path: String` -- dot-separated path (e.g., "C_HealthComponent.current_health")
- `operator: Operator` enum (EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GTE, LTE, HAS, NOT_HAS, IS_TRUE, IS_FALSE)
- `value: Variant` -- comparison value
- `negate: bool` -- invert result

**RS_QBEffect** (`scripts/resources/qb/rs_qb_effect.gd`):
- `effect_type: EffectType` enum (DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, CALL_METHOD, SET_QUALITY)
- `target: String` -- action type, event name, or component.field path
- `payload: Dictionary` -- effect parameters
- `delay: float` -- optional delay before execution

**RS_QBRuleDefinition** (`scripts/resources/qb/rs_qb_rule_definition.gd`):
- `rule_id: StringName`
- `description: String`
- `conditions: Array[RS_QBCondition]`
- `effects: Array[RS_QBEffect]`
- `priority: int` (higher = evaluated first)
- `is_one_shot: bool`
- `cooldown: float`
- `requires_salience: bool` (default true, only fire on false->true transition)
- `trigger_mode: TriggerMode` enum (TICK, EVENT, BOTH)
- `trigger_event: StringName`

### 1.2 Utility Classes

**U_QBRuleEvaluator** (`scripts/utils/qb/u_qb_rule_evaluator.gd`):
- `static func evaluate_condition(condition: RS_QBCondition, quality_value: Variant) -> bool`
- `static func evaluate_all_conditions(conditions: Array[RS_QBCondition], context: Dictionary) -> bool`
- Pure functions, no side effects, maximally testable

**U_QBEffectExecutor** (`scripts/utils/qb/u_qb_effect_executor.gd`):
- `static func execute_effect(effect: RS_QBEffect, context: Dictionary) -> void`
- `static func execute_effects(effects: Array[RS_QBEffect], context: Dictionary) -> void`
- Context dictionary carries store reference, event bus, component references

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
- Extends `BaseECSSystem`
- `@export var state_store: I_StateStore = null`
- `@export var rule_definitions: Array[RS_QBRuleDefinition] = []`
- Runtime state: `_rule_states: Dictionary` (rule_id -> {active: bool, last_fired: float, was_true: bool, cooldown_remaining: float})
- `on_configured()` -- register rules, subscribe to trigger events
- `process_tick(delta)` -- tick cooldowns, evaluate TICK/BOTH rules
- `_on_event_received(event_name, payload)` -- evaluate EVENT/BOTH rules for matching event
- `_evaluate_rule(rule, context) -> bool` -- check conditions + salience (was_true tracking)
- `_execute_rule_effects(rule, context)` -- execute effects, update last_fired, handle one-shot
- `_build_quality_context(entity, delta) -> Dictionary` -- virtual, subclasses override
- `_tick_cooldowns(delta)` -- decrement cooldown_remaining for all rules
- `_exit_tree()` -- unsubscribe from events (existing pattern)

### 1.4 Tests

**test_qb_condition_evaluation.gd** (`tests/unit/qb/`):
- Test every Operator variant against int, float, String, bool, Array values
- Test negate flag
- Test null/missing quality value handling
- Test type mismatches (comparing string to int gracefully)

**test_qb_effect_execution.gd** (`tests/unit/qb/`):
- Test DISPATCH_ACTION with MockStateStore
- Test PUBLISH_EVENT with U_ECSEventBus subscription
- Test SET_COMPONENT_FIELD
- Test SET_QUALITY
- Test delay > 0 behavior

**test_qb_rule_lifecycle.gd** (`tests/unit/qb/`):
- Test cooldown: rule fires, then blocked until cooldown expires
- Test salience: rule only fires on false->true transition, not while continuously true
- Test one-shot: rule fires once, then is_active becomes false
- Test priority: higher priority rules evaluated first
- Test EVENT trigger mode: rule only evaluated when matching event arrives
- Test BOTH trigger mode: rule evaluated on tick AND on matching event

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

**Goal**: Create the character brain data component and rule manager shell. Existing systems unchanged.

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
- Extends `BaseQBRuleManager`
- `execution_priority = 50` (runs BEFORE movement=100, health=200, etc.)
- `_build_quality_context(entity, delta)` -- reads from C_HealthComponent, C_MovementComponent, C_InputComponent, C_SpawnStateComponent, C_FloatingComponent and builds quality dictionary
- After rule evaluation, writes computed qualities to C_CharacterStateComponent
- Queries entities that have C_CharacterStateComponent

### 2.3 Scene Integration

- Add C_CharacterStateComponent to `scenes/templates/tmpl_character.tscn`
- Add S_CharacterRuleManager to gameplay scene System nodes (under Core category)
- Author initial rule `.tres` files in `resources/qb/character/`

### 2.4 Tests

**test_character_rule_manager.gd** (`tests/unit/qb/`):
- Test brain data population from mock components
- Test pause gate rule sets is_gameplay_active = false when paused
- Test spawn freeze rule sets is_spawn_frozen = true when frozen
- Test death sequence rule chain
- Use MockECSManager + MockStateStore for isolation

---

## Phase 3: Character System Gating Consolidation

**Goal**: Existing systems read from C_CharacterStateComponent instead of duplicating gating logic.

### 3.1 Systems to Modify

Each of these systems currently has its own pause check and/or spawn freeze check. Replace with a read from C_CharacterStateComponent:

1. **S_MovementSystem** -- remove independent pause check (lines 25-34), read `is_gameplay_active` and `is_spawn_frozen` from C_CharacterStateComponent
2. **S_JumpSystem** -- remove pause check, read `is_gameplay_active` and `is_spawn_frozen`
3. **S_GravitySystem** -- remove pause check, read `is_gameplay_active` and `is_spawn_frozen`
4. **S_FloatingSystem** -- read `is_gameplay_active`
5. **S_RotateToInputSystem** -- remove pause check, read `is_gameplay_active`
6. **S_AlignWithSurfaceSystem** -- read `is_gameplay_active`

### 3.2 S_HealthSystem Death Sequence Migration

- Death-triggering conditions (health <= 0, not already dead) become rule conditions
- Ragdoll spawning becomes a CALL_METHOD effect
- Redux dispatches (trigger_death, increment_death_count) become DISPATCH_ACTION effects
- Timer ticking, regen math, damage queue processing STAY in S_HealthSystem

### 3.3 Rule Definitions

Author `.tres` files:
- `cfg_pause_gate_rule.tres` -- conditions: gameplay.paused == true OR navigation.shell != "gameplay"; effects: SET_QUALITY is_gameplay_active = false
- `cfg_spawn_freeze_rule.tres` -- conditions: C_SpawnStateComponent.is_physics_frozen == true; effects: SET_QUALITY is_spawn_frozen = true
- `cfg_death_sequence_rule.tres` -- conditions: C_HealthComponent.current_health <= 0, C_CharacterStateComponent.is_dead == false; effects: SET_COMPONENT_FIELD is_dead = true, DISPATCH_ACTION trigger_death, PUBLISH_EVENT entity_death
- `cfg_invincibility_rule.tres` -- conditions: damage_received event, C_CharacterStateComponent.is_invincible == false; effects: SET_QUALITY is_invincible = true

### 3.4 Verification

- Run full existing ECS test suite -- all tests must pass (behavioral equivalence)
- Run QB unit tests
- Manual playtest: movement, jumping, death, respawn, pause/unpause

---

## Phase 4: Game State Rules

**Goal**: Replace S_CheckpointSystem and S_VictorySystem with declarative rules.

### 4.1 S_GameRuleManager

`scripts/ecs/systems/s_game_rule_manager.gd`:
- Extends `BaseQBRuleManager`
- Subscribes to: `checkpoint_zone_entered`, `victory_triggered` events
- Rule evaluation context includes Redux gameplay slice

### 4.2 Rule Definitions

- `cfg_checkpoint_activation_rule.tres`:
  - Trigger: EVENT (checkpoint_zone_entered)
  - Conditions: event has checkpoint data, checkpoint not already activated for this spawn_point_id
  - Effects: CALL_METHOD activate checkpoint, DISPATCH_ACTION set_last_checkpoint, PUBLISH_EVENT checkpoint_activated

- `cfg_victory_area_rule.tres`:
  - Trigger: EVENT (victory_triggered)
  - Conditions: trigger_node valid, not already triggered, dependencies met
  - Effects: DISPATCH_ACTION trigger_victory, DISPATCH_ACTION mark_area_complete

- `cfg_victory_game_complete_rule.tres`:
  - Trigger: EVENT (victory_triggered)
  - Conditions: victory_type == GAME_COMPLETE, completed_areas HAS required_final_area
  - Effects: DISPATCH_ACTION game_complete

### 4.3 Migration

- S_CheckpointSystem and S_VictorySystem become thin shells or are removed
- Their event subscriptions move to S_GameRuleManager
- Their Redux dispatches become rule effects

### 4.4 Tests

**test_game_rule_manager.gd**:
- Test checkpoint activation via mock event
- Test victory trigger with prereqs met / not met
- Test game complete with all areas / missing areas

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

## Phase 6: Documentation + Validation Tooling

**Goal**: Finalize documentation, add editor validation, update project-level docs.

### 6.1 Documentation

- Finalize `docs/qb_rule_manager/` files (overview, plan, tasks, continuation prompt)
- Update `AGENTS.md` with QB Rule Manager patterns section

### 6.2 Validation Tooling

- U_QBRuleValidator validates all rules at load time
- Push warnings for: empty rule_id, EVENT mode without trigger_event, invalid quality_path format, unknown effect targets
- Optional: debug overlay showing active rules per entity (deferred if not needed)

### 6.3 AGENTS.md Update

Add QB Rule Manager section covering:
- Rule authoring patterns
- Quality path format
- Effect types and usage
- Testing with mock injection
- Anti-patterns (don't rule-ify physics math, don't make rules for single-use logic)

---

## Critical Files Reference

| Existing File | Relevance |
|---------------|-----------|
| `scripts/ecs/base_ecs_system.gd` | Base class for BaseQBRuleManager |
| `scripts/ecs/base_ecs_component.gd` | Base class for C_CharacterStateComponent |
| `scripts/ecs/systems/s_health_system.gd` | Primary refactor target (death sequence) |
| `scripts/ecs/systems/s_movement_system.gd` | Pause/freeze gating consolidation |
| `scripts/ecs/systems/s_checkpoint_system.gd` | Replaced by game rules |
| `scripts/ecs/systems/s_victory_system.gd` | Replaced by game rules |
| `scripts/events/ecs/u_ecs_event_bus.gd` | Event subscription for rule triggers |
| `scripts/interfaces/i_state_store.gd` | DI interface for store access |
| `scripts/managers/m_camera_manager.gd` | Camera rules integrate with (not replace) |
| `scenes/templates/tmpl_character.tscn` | Add C_CharacterStateComponent |
| `tests/mocks/` | MockStateStore, MockECSManager for testing |
