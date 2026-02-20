# QB Rule Manager - Continuation Prompt

Use this prompt to resume work on the QB Rule Manager feature in a new session.

---

## Current Status

**Phase**: Phase 3 complete (`T3.1`-`T3.20` complete)
**Branch**: QB-Rule-Manager
**Last Commit**: `1622595` - docs(qb): update Phase 3 continuation and tasks

**Next Task**: `T4.1` - Add checkpoint/victory/damage event name constants to `U_ECSEventNames`
**Latest Verification**:
- `tests/unit/qb` passing (49/49)
- `tests/unit/ecs` passing (126/126)
- `tests/unit/ecs/systems` passing (200/200)
- `tests/integration/qb` passing (1/1)
- `tests/unit/style` suite passing (12/12)
- Manual playtest passed on February 20, 2026 (movement/jump/death/respawn/pause/spawn-freeze/footsteps)

---

## Context

You are implementing a Quality-Based (QB) Rule Manager for a Godot 4.6 ECS game template. The rule manager is a data-driven condition-effect engine that replaces scattered decision/gating logic across ECS systems with declarative rules defined as Resource `.tres` files.

**Key design decisions:**
- **4 effect types, no CALL_METHOD**: DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, SET_QUALITY
- **Handler systems** subscribe to events published by rules for complex behavior (ragdoll, checkpoint, victory)
- **PUBLISH_EVENT auto-injects context** -- entity_id and original event_payload merge into published payload so `.tres` files don't need dynamic values
- **SET_COMPONENT_FIELD contract** -- `target = Component.field`, payload includes `operation` (`set`/`add`), `value_type` + typed value fields, optional `clamp_min`/`clamp_max`; invalid config = warning + no-op
- **Rule loading contract** -- managers use const-preloaded default rule arrays via `get_default_rule_definitions()` when exported `rule_definitions` is empty (no runtime DirAccess scans)
- **S_DamageSystem stays as-is** -- stateful zone-body tracking + per-entity cooldown loop doesn't decompose cleanly into rules. Just centralize event names
- **Death detection stays in S_HealthSystem** -- tightly coupled to damage/invincibility flow. Ragdoll logic (lines 167-284) extracts to `S_DeathHandlerSystem`. Rule manager only syncs brain data (`is_dead` flag)
- **Canonical requested-event payloads**:
  - `entity_death_requested`: requires `entity_id`; optional `health_component`, `entity_root`, `body`
  - `entity_respawn_requested`: requires `entity_id`; optional `entity_root`
  - `checkpoint_activation_requested`: requires `checkpoint`, `spawn_point_id`; optional `entity_id`
  - `victory_execution_requested`: requires `trigger_node`; optional `entity_id`
- **Typed value fields** (value_float/int/string/bool/string_name) -- Godot 4.x cannot export Variant
- **OR conditions** via multiple rules with same effect (THREE pause gate .tres files: paused, wrong shell, transitioning)
- **Event salience auto-disabled** -- events are instantaneous, salience only for TICK/BOTH
- **SET_QUALITY salience OFF** -- brain data resets to defaults each tick, so SET_QUALITY rules use `requires_salience: false` to fire every tick
- **execution_priority = -1** on BaseQBRuleManager (M_ECSManager sorts ascending — lower values first; -1 runs before default-0 systems). Requires Phase 1 prerequisite: widen `base_ecs_system.gd` clamp from `[0, 1000]` to `[-100, 1000]`
- **Rule ordering** within same priority: rule_id alphabetical (StringName comparison)
- **Spawn freeze**: Rule sets flag only; each system keeps different side effects
- **Per-context cooldowns** remain on RS_QBRuleDefinition for future use (damage zones, custom mod rules)
- **Brain data defaults-each-tick**: `_build_quality_context()` initializes defaults (is_gameplay_active=true, is_spawn_frozen=false, is_dead=false), SET_QUALITY overrides them in the context dict, `_write_brain_data()` copies context → component. When no rule fires, defaults persist.
- **SET_QUALITY writes to context dictionary** (not directly to component) — the rule manager copies context → component via `_write_brain_data()` after all rules evaluate
- Migration is additive with intentional hardening — shell and transitioning checks are NEW gating conditions the 6 systems didn't previously enforce
- **Store retention after pause-gate migration** -- keep store in Gravity (gravity_scale reads) and RotateToInput (rotation snapshot dispatch); FootstepSound can drop store if pause gating is its only store use

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
- `scripts/ecs/base_ecs_system.gd` -- base class for BaseQBRuleManager; Phase 1 prerequisite: line 22 clamp change
- `scripts/ecs/base_ecs_component.gd` -- base class for C_CharacterStateComponent
- `scripts/resources/ecs/rs_health_settings.gd` -- pattern for resource definitions
- `scripts/ecs/systems/s_health_system.gd` -- extract ragdoll logic (lines 167-284), publish death events
- `scripts/ecs/systems/s_movement_system.gd` -- pause gating pattern (lines 22-34); keep @export state_store for entity snapshots
- `scripts/ecs/systems/s_jump_system.gd` -- pause + freeze gating (lines 21-34); keep @export state_store for accessibility reads
- `scripts/ecs/systems/s_gravity_system.gd` -- pause gating (lines 17-29); keep @export state_store for gravity_scale reads (lines 69-73)
- `scripts/ecs/systems/s_rotate_to_input_system.gd` -- pause gating (lines 21-33); keep @export state_store for rotation snapshot dispatch (lines 133-139)
- `scripts/ecs/systems/s_input_system.gd` -- pause gating (lines 80-84); keep @export state_store for other checks
- `scripts/ecs/systems/s_footstep_sound_system.gd` -- pause gating (lines 46-56, uses try_get_store variant); can remove @export state_store
- `scripts/ecs/systems/s_floating_system.gd` -- freeze only (no pause check)
- `scripts/ecs/systems/s_checkpoint_system.gd` -- replaced by checkpoint rule + handler; note `_resolve_spawn_point_position()` at lines 90-109
- `scripts/ecs/systems/s_victory_system.gd` -- replaced by victory rule + handler; note `REQUIRED_FINAL_AREA = "bar"` at line 7 and `_can_trigger_victory()` at lines 56-73; event subscription priority 10 at line 29
- `scripts/ecs/systems/s_damage_system.gd` -- stays as-is, centralize event names only
- `scripts/events/ecs/u_ecs_event_names.gd` -- centralize event constants
- `scripts/events/ecs/u_ecs_event_bus.gd` -- event bus for rule triggers
- `scripts/interfaces/i_state_store.gd` -- DI interface for store access
- `tests/mocks/` -- MockStateStore, MockECSManager for testing

### Scene files to modify:
- `scenes/templates/tmpl_character.tscn` -- add C_CharacterStateComponent
- `scenes/prefabs/prefab_player.tscn` -- add C_CharacterStateComponent
- `scenes/gameplay/gameplay_base.tscn` -- add rule manager + handler systems
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
- `scripts/ecs/systems/s_death_handler_system.gd`
- `resources/qb/character/cfg_pause_gate_paused.tres` (OR rule 1)
- `resources/qb/character/cfg_pause_gate_shell.tres` (OR rule 2)
- `resources/qb/character/cfg_pause_gate_transitioning.tres` (OR rule 3)
- `resources/qb/character/cfg_spawn_freeze_rule.tres`
- `resources/qb/character/cfg_death_sync_rule.tres`

**Game domain** (Phase 4):
- `scripts/ecs/systems/s_game_rule_manager.gd`
- `scripts/ecs/systems/s_checkpoint_handler_system.gd`
- `scripts/ecs/systems/s_victory_handler_system.gd`
- `resources/qb/game/cfg_checkpoint_rule.tres`
- `resources/qb/game/cfg_victory_rule.tres`

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
- `tests/unit/qb/test_death_handler_system.gd`
- `tests/unit/qb/test_game_rule_manager.gd`
- `tests/unit/qb/test_checkpoint_handler_system.gd`
- `tests/unit/qb/test_victory_handler_system.gd`
- `tests/unit/qb/test_camera_rule_manager.gd`
- `tests/integration/qb/test_qb_brain_data_pipeline.gd`

---

## Design Summary (Key Differences from Earlier Designs)

These are the current design decisions that must be followed:

1. **No CALL_METHOD** -- 4 effect types only (DISPATCH_ACTION, PUBLISH_EVENT, SET_COMPONENT_FIELD, SET_QUALITY)
2. **Handler systems** subscribe to events published by rules for complex behavior
3. **PUBLISH_EVENT auto-injects context** -- entity_id and event_payload merge into published payload
4. **SET_COMPONENT_FIELD contract** -- operation (`set`/`add`), typed value selection, optional clamp; invalid configs warn + no-op
5. **Rule loading contract** -- managers load const-preloaded defaults via `get_default_rule_definitions()` when exported `rule_definitions` is empty
6. **S_DamageSystem stays as-is** -- just centralize event names in U_ECSEventNames
7. **Death detection stays in S_HealthSystem** -- ragdoll extracts to S_DeathHandlerSystem (lines 167-284); rule manager only syncs `is_dead` flag to brain data
8. **Canonical requested-event payloads** -- death/respawn/checkpoint/victory requested events have required payload keys and handlers validate them
9. **Typed value fields** (value_float/int/string/bool/string_name) -- Godot 4.x can't export Variant
10. **Three pause gate .tres files** for OR logic (paused, wrong shell, transitioning)
11. **Event salience auto-disabled** -- events are instantaneous
12. **execution_priority = -1** on BaseQBRuleManager (M_ECSManager sorts ascending; -1 runs before default-0 systems). Phase 1 prerequisite: widen clamp in `base_ecs_system.gd` line 22 from `clampi(value, 0, 1000)` to `clampi(value, -100, 1000)`
13. **Spawn freeze: flag only** -- each system keeps different side effects
14. **6 systems with pause gating** (Movement, Jump, Gravity, RotateToInput, InputSystem, FootstepSoundSystem) -- NOT AlignWithSurface or FloatingSystem
15. **3 systems with freeze checks** (Movement, Jump, Floating) -- each with DIFFERENT side effects
16. **Event name centralization** -- checkpoint/victory/damage event names move from local constants to U_ECSEventNames
17. **Per-context cooldowns** on RS_QBRuleDefinition for future use; empty array = global cooldown
18. **Brain data defaults-each-tick** -- `_build_quality_context()` sets defaults, SET_QUALITY overrides in context dict, `_write_brain_data()` copies to component. SET_QUALITY rules use `requires_salience: false`.
19. **SET_QUALITY writes to context dict** (not component directly) -- rule manager copies context → component after all rules evaluate
20. **Migration is additive with intentional hardening** -- shell and transitioning checks are NEW gating (current systems only check `gameplay.paused`)
21. **Post-migration store retention** -- keep @export state_store in S_GravitySystem (gravity_scale reads) and S_RotateToInputSystem (rotation snapshot dispatch); S_FootstepSoundSystem can drop it
22. **S_VictoryHandlerSystem** must replicate `REQUIRED_FINAL_AREA = "bar"` prerequisite check and use event subscription priority 10
23. **S_CheckpointHandlerSystem** must replicate `_resolve_spawn_point_position()` for perf optimization

---

## Testing Commands

```bash
# Run QB tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/qb -gexit

# Run all ECS tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Run style tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Run integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/qb -gexit
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
