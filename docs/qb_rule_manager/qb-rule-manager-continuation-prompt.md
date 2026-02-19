# QB Rule Manager - Continuation Prompt

Use this prompt to resume work on the QB Rule Manager feature in a new session.

---

## Current Status

**Phase**: Not started (documentation created)
**Branch**: QB-Rule-Manager
**Last Commit**: Documentation files only

---

## Context

You are implementing a Quality-Based (QB) Rule Manager for a Godot 4.6 ECS game template. The rule manager is a data-driven condition-effect engine that replaces scattered decision/gating logic across 27+ ECS systems with declarative rules defined as Resource `.tres` files.

**Key design decisions:**
- Rules are Resource `.tres` files (RS_QBCondition, RS_QBEffect, RS_QBRuleDefinition)
- Rule managers extend BaseECSSystem (gets process_tick, DI, auto-registration)
- Scope is decision logic only -- physics math stays in existing systems
- C_CharacterStateComponent is an aggregated "brain data" component
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
- `scripts/ecs/systems/s_checkpoint_system.gd` -- replaced by game rules
- `scripts/ecs/systems/s_victory_system.gd` -- replaced by game rules
- `scripts/events/ecs/u_ecs_event_bus.gd` -- event bus for rule triggers
- `scripts/interfaces/i_state_store.gd` -- DI interface for store access
- `tests/mocks/` -- MockStateStore, MockECSManager for testing

### Scene files to modify:
- `scenes/templates/tmpl_character.tscn` -- add C_CharacterStateComponent
- `scenes/gameplay/gameplay_base.tscn` -- add rule manager systems
- `scenes/prefabs/prefab_player.tscn` -- add C_CharacterStateComponent

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
- `resources/qb/character/cfg_*.tres` (rule definitions)

**Game domain** (Phase 4):
- `scripts/ecs/systems/s_game_rule_manager.gd`
- `resources/qb/game/cfg_*.tres` (rule definitions)

**Camera domain** (Phase 5):
- `scripts/ecs/components/c_camera_state_component.gd`
- `scripts/ecs/systems/s_camera_rule_manager.gd`
- `resources/qb/camera/cfg_*.tres` (rule definitions)

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
- Inner class names must start with a capital letter
- Resource preloading required for mobile (const preload arrays, not runtime DirAccess)

---

## Commit Strategy

- Commit at the end of each completed phase
- Run full test suite before each commit
- Documentation updates in the same commit as the phase they document
- Update this continuation prompt after each phase with current status
