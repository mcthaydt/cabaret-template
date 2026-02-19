# QB Rule Manager - Tasks Checklist

## Phase 1: Core Framework + Tests (TDD)

### 1A: Resource Definitions

- [ ] T1.1: Create `scripts/resources/qb/rs_qb_condition.gd` (RS_QBCondition) - Source enum, Operator enum, ValueType enum, typed value fields (value_float/int/string/bool/string_name), quality_path, negate
- [ ] T1.2: Create `scripts/resources/qb/rs_qb_effect.gd` (RS_QBEffect) - EffectType enum (4 types: DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, SET_QUALITY -- no CALL_METHOD), target, payload
- [ ] T1.3: Create `scripts/resources/qb/rs_qb_rule_definition.gd` (RS_QBRuleDefinition) - rule_id, conditions, effects, priority, is_one_shot, cooldown, requires_salience (auto-disabled for EVENT mode), trigger_mode, trigger_event, cooldown_key_fields (Array[String], empty=global), cooldown_from_context_field (String, empty=use rule.cooldown)

### 1B: Utility Stubs + Tests First

- [ ] T1.4: Create stub `scripts/utils/qb/u_qb_rule_evaluator.gd` (U_QBRuleEvaluator) - empty static methods returning default values
- [ ] T1.5: Create `tests/unit/qb/test_qb_condition_evaluation.gd` - All operators with typed values (float, int, string, bool, string_name), negate, null handling, type mismatches
- [ ] T1.6: Run tests -- confirm they FAIL (red)
- [ ] T1.7: Implement U_QBRuleEvaluator -- pure static condition evaluation for all operators using typed value fields
- [ ] T1.8: Run tests -- confirm they PASS (green)

- [ ] T1.9: Create stub `scripts/utils/qb/u_qb_quality_provider.gd` (U_QBQualityProvider) - empty static methods
- [ ] T1.10: Create `tests/unit/qb/test_qb_quality_provider.gd` - All source types, missing paths, edge cases
- [ ] T1.11: Run tests -- confirm they FAIL (red)
- [ ] T1.12: Implement U_QBQualityProvider -- quality reading from component dict, Redux state, event payload, entity tags
- [ ] T1.13: Run tests -- confirm they PASS (green)

- [ ] T1.14: Create stub `scripts/utils/qb/u_qb_effect_executor.gd` (U_QBEffectExecutor) - empty static methods
- [ ] T1.15: Create `tests/unit/qb/test_qb_effect_execution.gd` - All 4 effect types with mocks, PUBLISH_EVENT context injection (entity_id + event_payload merge)
- [ ] T1.16: Run tests -- confirm they FAIL (red)
- [ ] T1.17: Implement U_QBEffectExecutor -- pure static effect execution for 4 types; PUBLISH_EVENT merges context (entity_id, event_payload) into published payload
- [ ] T1.18: Run tests -- confirm they PASS (green)

- [ ] T1.19: Create stub `scripts/utils/qb/u_qb_rule_validator.gd` (U_QBRuleValidator) - empty static methods
- [ ] T1.20: Create `tests/unit/qb/test_qb_rule_validator.gd` - Valid/invalid rule validation
- [ ] T1.21: Run tests -- confirm they FAIL (red)
- [ ] T1.22: Implement U_QBRuleValidator -- authoring-time validation (empty rule_id, missing trigger_event for EVENT mode, invalid paths)
- [ ] T1.23: Run tests -- confirm they PASS (green)

### 1C: Base Rule Manager (TDD)

- [ ] T1.24: Create stub `scripts/ecs/systems/base_qb_rule_manager.gd` (BaseQBRuleManager extends BaseECSSystem) - execution_priority=1, empty virtual methods
- [ ] T1.25: Create `tests/unit/qb/test_qb_rule_lifecycle.gd` - Cooldown, salience (false->true), one-shot, priority ordering (higher first, then rule_id alphabetical), event salience auto-disable, per-context cooldown (two contexts fire independently), cooldown_from_context_field (context overrides rule.cooldown), stale context cleanup
- [ ] T1.26: Run tests -- confirm they FAIL (red)
- [ ] T1.27: Implement BaseQBRuleManager -- rule registration, tick evaluation, event handling with salience auto-disable for EVENT mode, cooldown management (global + per-context via cooldown_key_fields), no _handle_effect virtual (effects fully processed by U_QBEffectExecutor)
- [ ] T1.28: Run tests -- confirm they PASS (green)

### 1D: Regression Check

- [ ] T1.29: Run full existing ECS test suite to confirm zero regressions

**Phase 1 Commit**: Core QB framework with full unit test coverage

---

## Phase 2: Character State Component + Rule Manager (TDD)

### 2A: Component

- [ ] T2.1: Create `scripts/ecs/components/c_character_state_component.gd` (C_CharacterStateComponent) - Brain data fields: is_gameplay_active, is_grounded, is_moving, is_spawn_frozen, is_dead, is_invincible, health_percent, vertical_state, has_input

### 2B: Rule Manager (TDD)

- [ ] T2.2: Create stub `scripts/ecs/systems/s_character_rule_manager.gd` (S_CharacterRuleManager extends BaseQBRuleManager) - inherits execution_priority=1, empty overrides
- [ ] T2.3: Create `tests/unit/qb/test_character_rule_manager.gd` - Brain data population, pause gate rules (both OR paths), spawn freeze rule
- [ ] T2.4: Run tests -- confirm they FAIL (red)
- [ ] T2.5: Implement S_CharacterRuleManager -- builds quality context from character components, writes to C_CharacterStateComponent, no CALL_METHOD handlers (all complex effects are PUBLISH_EVENT)
- [ ] T2.6: Run tests -- confirm they PASS (green)

### 2C: Rule Definitions (OR via multiple .tres files)

- [ ] T2.7: Create `resources/qb/character/cfg_pause_gate_paused.tres` - Condition: REDUX gameplay.paused == true; Effect: SET_QUALITY is_gameplay_active = false
- [ ] T2.8: Create `resources/qb/character/cfg_pause_gate_shell.tres` - Condition: REDUX navigation.shell != "gameplay"; Effect: SET_QUALITY is_gameplay_active = false
- [ ] T2.9: Create `resources/qb/character/cfg_spawn_freeze_rule.tres` - Condition: COMPONENT C_SpawnStateComponent.is_physics_frozen == true; Effect: SET_QUALITY is_spawn_frozen = true

### 2D: Scene Integration

- [ ] T2.10: Add C_CharacterStateComponent to `scenes/templates/tmpl_character.tscn`
- [ ] T2.11: Add C_CharacterStateComponent to `scenes/prefabs/prefab_player.tscn` and any character prefabs
- [ ] T2.12: Add S_CharacterRuleManager to all 5 gameplay scenes (gameplay_base, interior_house, bar, exterior, alleyway)

### 2E: Regression Check

- [ ] T2.13: Run full existing test suite -- zero regressions (rule manager writes to new component, nothing reads it yet)

**Phase 2 Commit**: Character state component and rule manager (additive, no behavioral changes)

---

## Phase 3: System Gating Consolidation + Death Handler

### 3A: Pause Gating Modifications (6 systems)

- [ ] T3.1: Modify `S_MovementSystem` - Replace independent pause check (lines 22-34) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.2: Modify `S_JumpSystem` - Replace pause check (lines 21-34) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.3: Modify `S_GravitySystem` - Replace pause check (lines 17-29) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.4: Modify `S_RotateToInputSystem` - Replace pause check (lines 21-33) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.5: Modify `S_InputSystem` - Replace pause check (lines 80-84) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.6: Modify `S_FootstepSoundSystem` - Replace pause check (lines 46-56, uses `try_get_store` variant) with C_CharacterStateComponent.is_gameplay_active read

### 3B: Spawn Freeze Modifications (3 systems -- each keeps different side effects)

- [ ] T3.7: Modify `S_MovementSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: reset velocity to zero, reset dynamics state)
- [ ] T3.8: Modify `S_JumpSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: flag debug snapshot with spawn_frozen: true)
- [ ] T3.9: Modify `S_FloatingSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: update support state even while frozen)

### NOT Modified

- S_AlignWithSurfaceSystem: No pause check, no freeze check currently -- do NOT add gating
- S_FloatingSystem: No pause check currently -- do NOT add pause gating

### 3C: Death Handler System

- [ ] T3.10: Add new event names to `U_ECSEventNames`: EVENT_ENTITY_DEATH_REQUESTED, EVENT_ENTITY_RESPAWN_REQUESTED
- [ ] T3.11: Create `scripts/ecs/systems/s_death_handler_system.gd` (S_DeathHandlerSystem extends BaseECSSystem) - subscribes to entity_death_requested (spawn ragdoll, hide entity) and entity_respawn_requested (free ragdoll, restore visibility)
- [ ] T3.12: Extract ragdoll logic from S_HealthSystem into S_DeathHandlerSystem: _spawn_ragdoll(), _restore_entity_state(), get_ragdoll_for_entity(), PLAYER_RAGDOLL preload, _rng, _ragdoll_spawned, _ragdoll_instances, _entity_refs, _entity_original_visibility
- [ ] T3.13: Modify S_HealthSystem: _handle_death_sequence() publishes entity_death_requested instead of calling _spawn_ragdoll(); _reset_death_flags() publishes entity_respawn_requested
- [ ] T3.14: Create `tests/unit/qb/test_death_handler_system.gd` - ragdoll spawn on death event, ragdoll cleanup on respawn event

### 3D: Brain Data Death Sync Rule

- [ ] T3.15: Create `resources/qb/character/cfg_death_sync_rule.tres` - TICK trigger, requires_salience: false; Condition: COMPONENT C_HealthComponent.is_dead == true; Effect: SET_QUALITY is_dead = true

### 3E: Verification

- [ ] T3.16: Run full existing ECS test suite -- all tests must pass (behavioral equivalence)
- [ ] T3.17: Run QB unit tests
- [ ] T3.18: Manual playtest: movement, jumping, death/respawn, pause/unpause, spawn freeze, footstep sounds during pause

**Phase 3 Commit**: System gating consolidated + death handler extracted

---

## Phase 4: Game State Rules -- Checkpoint + Victory (TDD)

### 4A: Event Name Centralization (prerequisite)

- [ ] T4.1: Add checkpoint/victory/damage event name constants to `scripts/events/ecs/u_ecs_event_names.gd` (EVENT_CHECKPOINT_ZONE_ENTERED, EVENT_CHECKPOINT_ACTIVATED, EVENT_CHECKPOINT_ACTIVATION_REQUESTED, EVENT_VICTORY_TRIGGERED, EVENT_VICTORY_EXECUTION_REQUESTED, EVENT_DAMAGE_ZONE_ENTERED, EVENT_DAMAGE_ZONE_EXITED)
- [ ] T4.2: Update S_CheckpointSystem to use centralized constants from U_ECSEventNames
- [ ] T4.3: Update S_VictorySystem to use centralized constants from U_ECSEventNames
- [ ] T4.4: Update S_DamageSystem to use centralized constants from U_ECSEventNames
- [ ] T4.5: Run full test suite to confirm zero regressions from constant centralization

### 4B: Rule Manager (TDD)

- [ ] T4.6: Create `scripts/ecs/systems/s_game_rule_manager.gd` (S_GameRuleManager extends BaseQBRuleManager) - simple event-rule host, no custom process_tick iteration
- [ ] T4.7: Create `tests/unit/qb/test_game_rule_manager.gd` - Checkpoint rule forwards event payload via PUBLISH_EVENT, victory rule forwards event payload via PUBLISH_EVENT
- [ ] T4.8: Run tests -- confirm they FAIL (red)
- [ ] T4.9: Implement S_GameRuleManager
- [ ] T4.10: Run tests -- confirm they PASS (green)

### 4C: Handler Systems (TDD)

- [ ] T4.11: Create `scripts/ecs/systems/s_checkpoint_handler_system.gd` (S_CheckpointHandlerSystem extends BaseECSSystem) - execution_priority=100, subscribes to checkpoint_activation_requested; activates checkpoint, dispatches set_last_checkpoint, resolves spawn position, publishes typed Evn_CheckpointActivated
- [ ] T4.12: Create `tests/unit/qb/test_checkpoint_handler_system.gd` - checkpoint activation flow
- [ ] T4.13: Create `scripts/ecs/systems/s_victory_handler_system.gd` (S_VictoryHandlerSystem extends BaseECSSystem) - execution_priority=300, subscribes to victory_execution_requested; validates trigger, checks prerequisites, dispatches actions
- [ ] T4.14: Create `tests/unit/qb/test_victory_handler_system.gd` - victory execution flow

### 4D: Rule Definitions

- [ ] T4.15: Create `resources/qb/game/cfg_checkpoint_rule.tres` - EVENT trigger: checkpoint_zone_entered; Effect: PUBLISH_EVENT checkpoint_activation_requested (forwards event payload)
- [ ] T4.16: Create `resources/qb/game/cfg_victory_rule.tres` - EVENT trigger: victory_triggered; Effect: PUBLISH_EVENT victory_execution_requested (forwards event payload)

### 4E: Migration

- [ ] T4.17: Remove S_CheckpointSystem from gameplay scenes
- [ ] T4.18: Remove S_VictorySystem from gameplay scenes
- [ ] T4.19: Add S_GameRuleManager, S_CheckpointHandlerSystem, S_VictoryHandlerSystem to gameplay scenes
- [ ] T4.20: S_DamageSystem stays as-is (just uses centralized event names from T4.4)

### 4F: Verification

- [ ] T4.21: Run full existing test suite -- verify behavioral equivalence
- [ ] T4.22: Run QB unit tests

**Phase 4 Commit**: Game state rules replace checkpoint and victory systems

---

## Phase 5: Camera State Rules (TDD)

### 5A: Component

- [ ] T5.1: Create `scripts/ecs/components/c_camera_state_component.gd` (C_CameraStateComponent) - target_fov, shake_trauma, fov_blend_speed

### 5B: Rule Manager (TDD)

- [ ] T5.2: Create stub `scripts/ecs/systems/s_camera_rule_manager.gd` (S_CameraRuleManager extends BaseQBRuleManager)
- [ ] T5.3: Create `tests/unit/qb/test_camera_rule_manager.gd` - Shake on damage, FOV zone blending
- [ ] T5.4: Run tests -- confirm they FAIL (red)
- [ ] T5.5: Implement S_CameraRuleManager
- [ ] T5.6: Run tests -- confirm they PASS (green)

### 5C: Rule Definitions + Integration

- [ ] T5.7: Create `resources/qb/camera/cfg_camera_shake_rule.tres` - EVENT trigger: entity_death/health_changed; Effects: add shake_trauma
- [ ] T5.8: Create `resources/qb/camera/cfg_camera_zone_fov_rule.tres` - TICK trigger; Conditions: entity in FOV zone; Effects: set target_fov
- [ ] T5.9: Add C_CameraStateComponent to camera entity in character/scene templates
- [ ] T5.10: Add S_CameraRuleManager to gameplay scenes
- [ ] T5.11: Wire S_CameraRuleManager to apply shake_trauma via M_CameraManager
- [ ] T5.12: Wire FOV blending to Camera3D

### 5D: Verification

- [ ] T5.13: Run full test suite

**Phase 5 Commit**: Camera state rules (additive)

---

## Phase 6: Validation + Final Verification

### Validation Tooling

- [ ] T6.1: Enhance U_QBRuleValidator with load-time validation (called in on_configured)
- [ ] T6.2: Add push_warning for misconfigured rules in editor

### Project-Level Updates

- [ ] T6.3: Update `AGENTS.md` with QB Rule Manager patterns section
- [ ] T6.4: Update `docs/general/DEV_PITFALLS.md` with any new pitfalls discovered

### Final Verification

- [ ] T6.5: Run full test suite (ECS + QB + style)
- [ ] T6.6: Manual playtest: full gameplay loop (walk, jump, take damage, die, respawn, checkpoint, victory)

**Phase 6 Commit**: Validation tooling and final verification
