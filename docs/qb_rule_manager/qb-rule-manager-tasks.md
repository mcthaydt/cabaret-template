# QB Rule Manager - Tasks Checklist

## Phase 1: Core Framework + Tests

### Resources
- [ ] T1.1: Create `scripts/resources/qb/rs_qb_condition.gd` (RS_QBCondition) - Source enum, Operator enum, quality_path, value, negate
- [ ] T1.2: Create `scripts/resources/qb/rs_qb_effect.gd` (RS_QBEffect) - EffectType enum, target, payload, delay
- [ ] T1.3: Create `scripts/resources/qb/rs_qb_rule_definition.gd` (RS_QBRuleDefinition) - rule_id, conditions, effects, lifecycle fields, trigger mode

### Utilities
- [ ] T1.4: Create `scripts/utils/qb/u_qb_rule_evaluator.gd` (U_QBRuleEvaluator) - Pure static condition evaluation functions for all operators
- [ ] T1.5: Create `scripts/utils/qb/u_qb_effect_executor.gd` (U_QBEffectExecutor) - Pure static effect execution for all effect types
- [ ] T1.6: Create `scripts/utils/qb/u_qb_quality_provider.gd` (U_QBQualityProvider) - Quality reading from component dict, Redux state, event payload, entity tags
- [ ] T1.7: Create `scripts/utils/qb/u_qb_rule_validator.gd` (U_QBRuleValidator) - Authoring-time validation (empty rule_id, missing trigger_event for EVENT mode, invalid paths)

### Base Rule Manager
- [ ] T1.8: Create `scripts/ecs/systems/base_qb_rule_manager.gd` (BaseQBRuleManager extends BaseECSSystem) - Rule registration, tick evaluation, event handling, salience tracking, cooldown management, lifecycle management

### Tests
- [ ] T1.9: Create `tests/unit/qb/test_qb_condition_evaluation.gd` - All operators, negate, null handling, type mismatches
- [ ] T1.10: Create `tests/unit/qb/test_qb_effect_execution.gd` - All effect types with mocks
- [ ] T1.11: Create `tests/unit/qb/test_qb_rule_lifecycle.gd` - Cooldown, salience (false->true), one-shot, priority ordering
- [ ] T1.12: Create `tests/unit/qb/test_qb_quality_provider.gd` - All source types, missing paths, edge cases
- [ ] T1.13: Create `tests/unit/qb/test_qb_rule_validator.gd` - Valid/invalid rule validation
- [ ] T1.14: Run full existing ECS test suite to confirm zero regressions

**Phase 1 Commit**: Core QB framework with full unit test coverage

---

## Phase 2: Character State Component + Rule Manager Shell

### Component
- [ ] T2.1: Create `scripts/ecs/components/c_character_state_component.gd` (C_CharacterStateComponent) - Brain data fields: is_gameplay_active, is_grounded, is_moving, is_sprinting, is_spawn_frozen, is_dead, is_invincible, health_percent, vertical_state, has_input
- [ ] T2.2: Add C_CharacterStateComponent to `scenes/templates/tmpl_character.tscn`
- [ ] T2.3: Add C_CharacterStateComponent to `scenes/prefabs/prefab_player.tscn` and any character prefabs

### Rule Manager System
- [ ] T2.4: Create `scripts/ecs/systems/s_character_rule_manager.gd` (S_CharacterRuleManager extends BaseQBRuleManager) - execution_priority=50, builds quality context from character components, writes to C_CharacterStateComponent
- [ ] T2.5: Add S_CharacterRuleManager to gameplay scenes (under Systems/Core)

### Initial Rules
- [ ] T2.6: Create `resources/qb/character/cfg_pause_gate_rule.tres` - Conditions: paused or non-gameplay shell; Effects: set is_gameplay_active = false
- [ ] T2.7: Create `resources/qb/character/cfg_spawn_freeze_rule.tres` - Conditions: C_SpawnStateComponent.is_physics_frozen; Effects: set is_spawn_frozen = true

### Tests
- [ ] T2.8: Create `tests/unit/qb/test_character_rule_manager.gd` - Brain data population, pause gate rule, spawn freeze rule
- [ ] T2.9: Run full existing test suite -- zero regressions (rule manager writes to new component, nothing reads it yet)

**Phase 2 Commit**: Character state component and rule manager shell (additive, no behavioral changes)

---

## Phase 3: Character System Gating Consolidation

### System Modifications
- [ ] T3.1: Modify `S_MovementSystem` - Replace independent pause check (lines 25-34) with read from C_CharacterStateComponent.is_gameplay_active; replace spawn freeze gating with C_CharacterStateComponent.is_spawn_frozen
- [ ] T3.2: Modify `S_JumpSystem` - Replace pause check and spawn freeze check with C_CharacterStateComponent reads
- [ ] T3.3: Modify `S_GravitySystem` - Replace pause check and spawn freeze check with C_CharacterStateComponent reads
- [ ] T3.4: Modify `S_FloatingSystem` - Read is_gameplay_active from C_CharacterStateComponent
- [ ] T3.5: Modify `S_RotateToInputSystem` - Replace pause check with C_CharacterStateComponent read
- [ ] T3.6: Modify `S_AlignWithSurfaceSystem` - Read is_gameplay_active from C_CharacterStateComponent

### Death Sequence Rules
- [ ] T3.7: Create `resources/qb/character/cfg_death_sequence_rule.tres` - Conditions: health <= 0, not already dead; Effects: mark dead, dispatch trigger_death, publish entity_death
- [ ] T3.8: Create `resources/qb/character/cfg_invincibility_rule.tres` - Conditions: damage received event, not invincible; Effects: trigger invincibility
- [ ] T3.9: Refactor S_HealthSystem death-triggering to delegate to rule definitions (timer ticking, regen math, damage queue stay)

### Verification
- [ ] T3.10: Run full existing ECS test suite -- all tests must pass (behavioral equivalence)
- [ ] T3.11: Run QB unit tests
- [ ] T3.12: Manual playtest: movement, jumping, death/respawn, pause/unpause, spawn freeze

**Phase 3 Commit**: Character gating consolidated through rule manager

---

## Phase 4: Game State Rules

### Rule Manager
- [ ] T4.1: Create `scripts/ecs/systems/s_game_rule_manager.gd` (S_GameRuleManager extends BaseQBRuleManager) - Subscribes to checkpoint_zone_entered, victory_triggered events
- [ ] T4.2: Add S_GameRuleManager to gameplay scenes (under Systems/Core)

### Rule Definitions
- [ ] T4.3: Create `resources/qb/game/cfg_checkpoint_activation_rule.tres` - EVENT trigger: checkpoint_zone_entered; Effects: activate checkpoint, dispatch set_last_checkpoint, publish checkpoint_activated
- [ ] T4.4: Create `resources/qb/game/cfg_victory_area_rule.tres` - EVENT trigger: victory_triggered; Conditions: valid trigger, not already triggered; Effects: dispatch trigger_victory, mark_area_complete
- [ ] T4.5: Create `resources/qb/game/cfg_victory_game_complete_rule.tres` - EVENT trigger: victory_triggered; Conditions: GAME_COMPLETE type, required areas completed; Effects: dispatch game_complete

### Migration
- [ ] T4.6: Migrate S_CheckpointSystem logic to checkpoint rules (remove or stub original)
- [ ] T4.7: Migrate S_VictorySystem logic to victory rules (remove or stub original)

### Tests
- [ ] T4.8: Create `tests/unit/qb/test_game_rule_manager.gd` - Checkpoint activation, victory with/without prereqs, game complete
- [ ] T4.9: Run full existing test suite -- verify behavioral equivalence

**Phase 4 Commit**: Game state rules replace checkpoint and victory systems

---

## Phase 5: Camera State Rules

### Component
- [ ] T5.1: Create `scripts/ecs/components/c_camera_state_component.gd` (C_CameraStateComponent) - target_fov, shake_trauma, fov_blend_speed
- [ ] T5.2: Add C_CameraStateComponent to camera entity in character/scene templates

### Rule Manager
- [ ] T5.3: Create `scripts/ecs/systems/s_camera_rule_manager.gd` (S_CameraRuleManager extends BaseQBRuleManager)
- [ ] T5.4: Add S_CameraRuleManager to gameplay scenes

### Rule Definitions
- [ ] T5.5: Create `resources/qb/camera/cfg_camera_shake_rule.tres` - EVENT trigger: entity_death/health_changed; Effects: add shake_trauma
- [ ] T5.6: Create `resources/qb/camera/cfg_camera_zone_fov_rule.tres` - TICK trigger; Conditions: entity in FOV zone; Effects: set target_fov

### Integration
- [ ] T5.7: Wire S_CameraRuleManager to apply shake_trauma via M_CameraManager
- [ ] T5.8: Wire FOV blending to Camera3D

### Tests
- [ ] T5.9: Create `tests/unit/qb/test_camera_rule_manager.gd` - Shake on damage, FOV zone blending
- [ ] T5.10: Run full test suite

**Phase 5 Commit**: Camera state rules (additive)

---

## Phase 6: Documentation + Validation + Cleanup

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
