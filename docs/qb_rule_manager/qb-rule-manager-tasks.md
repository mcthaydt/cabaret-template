# QB Rule Manager - Tasks Checklist

## Phase 1: Core Framework + Tests (TDD)

### 1A: Resource Definitions (test targets need to exist first as stubs)

- [ ] T1.1: Create `scripts/resources/qb/rs_qb_condition.gd` (RS_QBCondition) - Source enum, Operator enum, ValueType enum, typed value fields (value_float/int/string/bool/string_name), quality_path, negate
- [ ] T1.2: Create `scripts/resources/qb/rs_qb_effect.gd` (RS_QBEffect) - EffectType enum, target, payload (no delay field in Phase 1)
- [ ] T1.3: Create `scripts/resources/qb/rs_qb_rule_definition.gd` (RS_QBRuleDefinition) - rule_id, conditions, effects, priority, is_one_shot, cooldown, requires_salience (auto-disabled for EVENT mode), trigger_mode, trigger_event

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
- [ ] T1.15: Create `tests/unit/qb/test_qb_effect_execution.gd` - All effect types with mocks, CALL_METHOD delegation
- [ ] T1.16: Run tests -- confirm they FAIL (red)
- [ ] T1.17: Implement U_QBEffectExecutor -- pure static effect execution; CALL_METHOD delegates to rule_manager._handle_effect()
- [ ] T1.18: Run tests -- confirm they PASS (green)

- [ ] T1.19: Create stub `scripts/utils/qb/u_qb_rule_validator.gd` (U_QBRuleValidator) - empty static methods
- [ ] T1.20: Create `tests/unit/qb/test_qb_rule_validator.gd` - Valid/invalid rule validation
- [ ] T1.21: Run tests -- confirm they FAIL (red)
- [ ] T1.22: Implement U_QBRuleValidator -- authoring-time validation (empty rule_id, missing trigger_event for EVENT mode, invalid paths)
- [ ] T1.23: Run tests -- confirm they PASS (green)

### 1C: Base Rule Manager (TDD)

- [ ] T1.24: Create stub `scripts/ecs/systems/base_qb_rule_manager.gd` (BaseQBRuleManager extends BaseECSSystem) - execution_priority=1, empty virtual methods
- [ ] T1.25: Create `tests/unit/qb/test_qb_rule_lifecycle.gd` - Cooldown, salience (false->true), one-shot, priority ordering (higher first, then rule_id alphabetical), event salience auto-disable
- [ ] T1.26: Run tests -- confirm they FAIL (red)
- [ ] T1.27: Implement BaseQBRuleManager -- rule registration, tick evaluation with entity iteration pattern, event handling with salience auto-disable for EVENT mode, cooldown management, _handle_effect virtual for CALL_METHOD, _evaluate_rules_for_context, _build_quality_context virtual
- [ ] T1.28: Run tests -- confirm they PASS (green)

### 1D: Regression Check

- [ ] T1.29: Run full existing ECS test suite to confirm zero regressions

**Phase 1 Commit**: Core QB framework with full unit test coverage

---

## Phase 2: Character State Component + Rule Manager (TDD)

### 2A: Component

- [ ] T2.1: Create `scripts/ecs/components/c_character_state_component.gd` (C_CharacterStateComponent) - Brain data fields: is_gameplay_active, is_grounded, is_moving, is_sprinting, is_spawn_frozen, is_dead, is_invincible, health_percent, vertical_state, has_input

### 2B: Rule Manager (TDD)

- [ ] T2.2: Create stub `scripts/ecs/systems/s_character_rule_manager.gd` (S_CharacterRuleManager extends BaseQBRuleManager) - inherits execution_priority=1, empty overrides
- [ ] T2.3: Create `tests/unit/qb/test_character_rule_manager.gd` - Brain data population, pause gate rules (both OR paths), spawn freeze rule, death sequence CALL_METHOD handlers
- [ ] T2.4: Run tests -- confirm they FAIL (red)
- [ ] T2.5: Implement S_CharacterRuleManager -- builds quality context from character components, writes to C_CharacterStateComponent, CALL_METHOD handlers for death sequence
- [ ] T2.6: Run tests -- confirm they PASS (green)

### 2C: Rule Definitions (OR via multiple .tres files)

- [ ] T2.7: Create `resources/qb/character/cfg_pause_gate_paused.tres` - Condition: gameplay.paused == true; Effect: SET_QUALITY is_gameplay_active = false
- [ ] T2.8: Create `resources/qb/character/cfg_pause_gate_shell.tres` - Condition: navigation.shell != "gameplay"; Effect: SET_QUALITY is_gameplay_active = false
- [ ] T2.9: Create `resources/qb/character/cfg_spawn_freeze_rule.tres` - Condition: C_SpawnStateComponent.is_physics_frozen == true; Effect: SET_QUALITY is_spawn_frozen = true

### 2D: Scene Integration

- [ ] T2.10: Add C_CharacterStateComponent to `scenes/templates/tmpl_character.tscn`
- [ ] T2.11: Add C_CharacterStateComponent to `scenes/prefabs/prefab_player.tscn` and any character prefabs
- [ ] T2.12: Add S_CharacterRuleManager to all 5 gameplay scenes (gameplay_base, interior_house, bar, exterior, alleyway)

### 2E: Regression Check

- [ ] T2.13: Run full existing test suite -- zero regressions (rule manager writes to new component, nothing reads it yet)

**Phase 2 Commit**: Character state component and rule manager (additive, no behavioral changes)

---

## Phase 3: Character System Gating Consolidation

### 3A: Pause Gating Modifications (5 systems -- verified identical pattern)

- [ ] T3.1: Modify `S_MovementSystem` - Replace independent pause check (lines 23-34) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.2: Modify `S_JumpSystem` - Replace pause check (lines 22-34) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.3: Modify `S_GravitySystem` - Replace pause check (lines 18-29) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.4: Modify `S_RotateToInputSystem` - Replace pause check (lines 22-33) with C_CharacterStateComponent.is_gameplay_active read
- [ ] T3.5: Modify `S_InputSystem` - Replace pause check (lines 80-84) with C_CharacterStateComponent.is_gameplay_active read

### 3B: Spawn Freeze Modifications (3 systems -- each keeps different side effects)

- [ ] T3.6: Modify `S_MovementSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: reset velocity to zero, reset dynamics state)
- [ ] T3.7: Modify `S_JumpSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: flag debug snapshot with spawn_frozen: true)
- [ ] T3.8: Modify `S_FloatingSystem` - Read is_spawn_frozen from C_CharacterStateComponent (keep: update support state even while frozen)

### NOT Modified

- S_AlignWithSurfaceSystem: No pause check, no freeze check currently -- do NOT add gating
- S_FloatingSystem: No pause check currently -- do NOT add pause gating

### 3C: Death Sequence Rules (TDD)

- [ ] T3.9: Write tests in test_character_rule_manager.gd for death sequence -- health <= 0 triggers CALL_METHOD chain, invincibility on damage event
- [ ] T3.10: Run tests -- confirm they FAIL (red)
- [ ] T3.11: Create `resources/qb/character/cfg_death_sequence_rule.tres` - Conditions: health <= 0, not already dead; Effects: CALL_METHOD _handle_mark_dead, DISPATCH_ACTION trigger_death, CALL_METHOD _handle_spawn_ragdoll
- [ ] T3.12: Create `resources/qb/character/cfg_invincibility_rule.tres` - Conditions: damage received event, not invincible; Effects: trigger invincibility
- [ ] T3.13: Refactor S_HealthSystem death-triggering to delegate to rule definitions (timer ticking, regen math, damage queue processing STAY in S_HealthSystem)
- [ ] T3.14: Run tests -- confirm they PASS (green)

### 3D: Verification

- [ ] T3.15: Run full existing ECS test suite -- all tests must pass (behavioral equivalence)
- [ ] T3.16: Run QB unit tests
- [ ] T3.17: Manual playtest: movement, jumping, death/respawn, pause/unpause, spawn freeze

**Phase 3 Commit**: Character gating consolidated through rule manager

---

## Phase 4: Game State Rules + Damage Zone (TDD)

### 4A: Rule Manager (TDD)

- [ ] T4.1: Create stub `scripts/ecs/systems/s_game_rule_manager.gd` (S_GameRuleManager extends BaseQBRuleManager) - event subscriptions, empty handlers
- [ ] T4.2: Create `tests/unit/qb/test_game_rule_manager.gd` - Checkpoint activation, victory with/without prereqs, game complete, damage zone with player tag/cooldown
- [ ] T4.3: Run tests -- confirm they FAIL (red)
- [ ] T4.4: Implement S_GameRuleManager -- subscribes to checkpoint_zone_entered, victory_triggered, damage_zone_entered events; CALL_METHOD handlers; no C_GameStateComponent (purely event-driven)
- [ ] T4.5: Run tests -- confirm they PASS (green)

### 4B: Rule Definitions

- [ ] T4.6: Create `resources/qb/game/cfg_checkpoint_activation_rule.tres` - EVENT trigger: checkpoint_zone_entered; Effects: CALL_METHOD activate checkpoint, DISPATCH_ACTION set_last_checkpoint, PUBLISH_EVENT checkpoint_activated
- [ ] T4.7: Create `resources/qb/game/cfg_victory_area_rule.tres` - EVENT trigger: victory_triggered; Conditions: valid trigger, not already triggered; Effects: DISPATCH_ACTION trigger_victory, mark_area_complete
- [ ] T4.8: Create `resources/qb/game/cfg_victory_game_complete_rule.tres` - EVENT trigger: victory_triggered; Conditions: GAME_COMPLETE type, required areas completed; Effects: DISPATCH_ACTION game_complete
- [ ] T4.9: Create `resources/qb/game/cfg_damage_zone_rule.tres` - EVENT trigger: damage_zone_entered; Conditions: zone overlap + player tag + cooldown; Effects: CALL_METHOD queue damage

### 4C: Migration

- [ ] T4.10: Replace S_CheckpointSystem with checkpoint rules (remove or stub original)
- [ ] T4.11: Replace S_VictorySystem with victory rules (remove or stub original)
- [ ] T4.12: Migrate S_DamageSystem zone-overlap logic to damage zone rules

### 4D: Scene Integration + Verification

- [ ] T4.13: Add S_GameRuleManager to gameplay scenes (under Systems/Core)
- [ ] T4.14: Run full existing test suite -- verify behavioral equivalence

**Phase 4 Commit**: Game state rules replace checkpoint, victory, and damage zone systems

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

## Phase 6: Documentation + Validation + Anti-Patterns

### Documentation

- [ ] T6.1: Finalize `docs/qb_rule_manager/qb-rule-manager-overview.md`
- [ ] T6.2: Finalize `docs/qb_rule_manager/qb-rule-manager-plan.md`
- [ ] T6.3: Finalize `docs/qb_rule_manager/qb-rule-manager-tasks.md` (mark completed tasks)
- [ ] T6.4: Update `docs/qb_rule_manager/qb-rule-manager-continuation-prompt.md` with final status

### Project-Level Updates

- [ ] T6.5: Update `AGENTS.md` with QB Rule Manager patterns section
- [ ] T6.6: Update `docs/general/DEV_PITFALLS.md` with any new pitfalls discovered

### Validation Tooling

- [ ] T6.7: Enhance U_QBRuleValidator with load-time validation (called in on_configured)
- [ ] T6.8: Add push_warning for misconfigured rules in editor

### Final Verification

- [ ] T6.9: Run full test suite (ECS + QB + style)
- [ ] T6.10: Manual playtest: full gameplay loop (walk, jump, take damage, die, respawn, checkpoint, victory)

**Phase 6 Commit**: Documentation and validation tooling
