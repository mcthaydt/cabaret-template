# QB Rule Manager - Continuation Prompt

Use this prompt to resume work on the QB Rule Manager feature in a new session.

---

## Current Status

**Phase**: Not started (documentation updated with audit-corrected design)
**Branch**: QB-Rule-Manager
**Last Commit**: Documentation files only

---

## Context

You are implementing a Quality-Based (QB) Rule Manager for a Godot 4.6 ECS game template. The rule manager is a data-driven condition-effect engine that replaces scattered decision/gating logic across ECS systems with declarative rules defined as Resource `.tres` files.

**Key audit-corrected design decisions:**
- Rules are Resource `.tres` files (RS_QBCondition, RS_QBEffect, RS_QBRuleDefinition)
- **Typed value fields** (value_float/int/string/bool/string_name) -- Godot 4.x cannot export Variant
- **No delay on effects** in Phase 1 (deferred to post-Phase 6)
- **OR conditions** via multiple rules with same effect (two pause gate .tres files)
- **Event salience auto-disabled** -- events are instantaneous, salience only for TICK/BOTH
- **execution_priority = 1** on BaseQBRuleManager (runs before default-0 systems)
- **Rule ordering** within same priority: rule_id alphabetical (StringName comparison)
- **CALL_METHOD** effects delegate to subclass handler methods (complex effects like ragdoll, checkpoint)
- **Spawn freeze**: Rule sets flag only; each system keeps its own freeze side effects
- Scope is decision logic only -- physics math stays in existing systems
- C_CharacterStateComponent is an aggregated "brain data" component
- S_GameRuleManager has no C_GameStateComponent -- purely event-driven
- Migration is additive -- nothing breaks at any phase

**Documentation location**: `docs/qb_rule_manager/`
- Overview: `qb-rule-manager-overview.md`
- Plan: `qb-rule-manager-plan.md`
- Tasks: `qb-rule-manager-tasks.md`

---

## Before Continuing

1. Read `AGENTS.md` for project conventions
2. Read `docs/general/DEV_PITFALLS.md` for known pitfalls
3. Read `docs/qb_rule_manager/qb-rule-manager-tasks.md` for the current task checklist
4. Check the task checklist for the first unchecked item -- that's where to resume

---

## Key Files to Reference

### Existing patterns to follow:
- `scripts/ecs/base_ecs_system.gd` -- base class for BaseQBRuleManager
- `scripts/ecs/base_ecs_component.gd` -- base class for C_CharacterStateComponent
- `scripts/resources/ecs/rs_health_settings.gd` -- pattern for resource definitions
- `scripts/ecs/systems/s_health_system.gd` -- primary refactor target (death sequence)
- `scripts/ecs/systems/s_movement_system.gd` -- pause gating pattern (lines 23-34)
- `scripts/ecs/systems/s_jump_system.gd` -- pause + freeze gating (lines 22-34)
- `scripts/ecs/systems/s_gravity_system.gd` -- pause gating (lines 18-29)
- `scripts/ecs/systems/s_rotate_to_input_system.gd` -- pause gating (lines 22-33)
- `scripts/ecs/systems/s_input_system.gd` -- pause gating (lines 80-84)
- `scripts/ecs/systems/s_floating_system.gd` -- freeze only (no pause check)
- `scripts/ecs/systems/s_checkpoint_system.gd` -- replaced by game rules
- `scripts/ecs/systems/s_victory_system.gd` -- replaced by game rules
- `scripts/ecs/systems/s_damage_system.gd` -- zone-overlap logic migrated to game rules
- `scripts/events/ecs/u_ecs_event_bus.gd` -- event bus for rule triggers
- `scripts/interfaces/i_state_store.gd` -- DI interface for store access
- `tests/mocks/` -- MockStateStore, MockECSManager for testing

### Scene files to modify:
- `scenes/templates/tmpl_character.tscn` -- add C_CharacterStateComponent
- `scenes/prefabs/prefab_player.tscn` -- add C_CharacterStateComponent
- `scenes/gameplay/gameplay_base.tscn` -- add rule manager systems
- All 5 gameplay scenes need S_CharacterRuleManager

### New files created by this feature:

**Core framework** (Phase 1):
- `scripts/resources/qb/rs_qb_condition.gd`
- `scripts/resources/qb/rs_qb_effect.gd`
- `scripts/resources/qb/rs_qb_rule_definition.gd`
- `scripts/ecs/systems/base_qb_rule_manager.gd`
- `scripts/utils/qb/u_qb_rule_evaluator.gd`
- `scripts/utils/qb/u_qb_effect_executor.gd`
- `scripts/utils/qb/u_qb_quality_provider.gd`
- `scripts/utils/qb/u_qb_rule_validator.gd`

**Character domain** (Phase 2-3):
- `scripts/ecs/components/c_character_state_component.gd`
- `scripts/ecs/systems/s_character_rule_manager.gd`
- `resources/qb/character/cfg_pause_gate_paused.tres` (OR rule 1)
- `resources/qb/character/cfg_pause_gate_shell.tres` (OR rule 2)
- `resources/qb/character/cfg_spawn_freeze_rule.tres`
- `resources/qb/character/cfg_death_sequence_rule.tres`
- `resources/qb/character/cfg_invincibility_rule.tres`

**Game domain** (Phase 4):
- `scripts/ecs/systems/s_game_rule_manager.gd`
- `resources/qb/game/cfg_checkpoint_activation_rule.tres`
- `resources/qb/game/cfg_victory_area_rule.tres`
- `resources/qb/game/cfg_victory_game_complete_rule.tres`
- `resources/qb/game/cfg_damage_zone_rule.tres`

**Camera domain** (Phase 5):
- `scripts/ecs/components/c_camera_state_component.gd`
- `scripts/ecs/systems/s_camera_rule_manager.gd`
- `resources/qb/camera/cfg_camera_shake_rule.tres`
- `resources/qb/camera/cfg_camera_zone_fov_rule.tres`

**Tests**:
- `tests/unit/qb/test_qb_condition_evaluation.gd`
- `tests/unit/qb/test_qb_effect_execution.gd`
- `tests/unit/qb/test_qb_rule_lifecycle.gd`
- `tests/unit/qb/test_qb_quality_provider.gd`
- `tests/unit/qb/test_qb_rule_validator.gd`
- `tests/unit/qb/test_character_rule_manager.gd`
- `tests/unit/qb/test_game_rule_manager.gd`
- `tests/unit/qb/test_camera_rule_manager.gd`

---

## Audit-Corrected Design (Key Differences from Pre-Audit)

These corrections were made during the design audit and must be followed:

1. **Typed value fields** instead of `@export var value: Variant` (Godot 4.x can't export Variant)
2. **No delay field** on RS_QBEffect in Phase 1
3. **Two pause gate .tres files** for OR logic (not a single rule with OR operator)
4. **Event salience auto-disabled** (events are instantaneous)
5. **execution_priority = 1** (not 50 or other values)
6. **Spawn freeze: flag only** -- each system keeps different side effects
7. **5 systems with pause gating** (Movement, Jump, Gravity, RotateToInput, InputSystem) -- NOT AlignWithSurface or FloatingSystem
8. **3 systems with freeze checks** (Movement, Jump, Floating) -- each with DIFFERENT side effects
9. **S_DamageSystem** zone-overlap logic included in Phase 4 scope
10. **No C_GameStateComponent** -- game rules are purely event-driven

---

## Testing Commands

```bash
# Run QB tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/qb -gexit

# Run all ECS tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Run style tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

---

## GDScript 4.6 Pitfalls to Remember

- `tr` cannot be a static method name (collides with Object.tr)
- `String(value)` fails for arbitrary Variants -- use `str(value)`
- Inner class names must start with a capital letter (no `class _MockFoo`)
- Resource preloading required for mobile (const preload arrays, not runtime DirAccess)

---

## Commit Strategy

- Commit at the end of each completed phase
- Run full test suite before each commit
- Documentation updates in the same commit as the phase they document
- Update this continuation prompt after each phase with current status
