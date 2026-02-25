# QB Rule Engine v2 — Continuation Prompt

## Current Focus

- **Feature:** QB Rule Engine v2 — replace v1 inheritance-based rule engine with stateless scoring library + typed resources
- **Branch:** `scene-director`
- **Status:** In progress (Phase 2A complete; Phase 2B next)

## Recent Progress

- v1 is 100% complete (6 feature phases + R1-R7 refactors, 97 QB tests, all green)
- v2 overview, plan, tasks, and continuation prompt written
- v1 docs archived to `docs/qb_rule_manager/v1/`
- Phase 1A completed on 2026-02-25:
  - Added `scripts/utils/qb/u_path_resolver.gd`
  - Added `tests/unit/qb/test_path_resolver.gd` with T1-T11 coverage
  - Verified `test_path_resolver.gd` (10/10 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1B completed on 2026-02-25:
  - Added `scripts/resources/qb/rs_base_condition.gd`
  - Added condition resources under `scripts/resources/qb/conditions/`:
    - `rs_condition_component_field.gd`
    - `rs_condition_redux_field.gd`
    - `rs_condition_entity_tag.gd`
    - `rs_condition_event_payload.gd`
    - `rs_condition_constant.gd`
  - Added test suites:
    - `test_condition_component_field.gd`
    - `test_condition_redux_field.gd`
    - `test_condition_entity_tag.gd`
    - `test_condition_event_payload.gd`
    - `test_condition_constant.gd`
    - `test_base_condition.gd`
  - Verified QB condition tests (28/28 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
  - Stabilized headless parsing by using explicit script-path `extends` for new condition subclasses
- Phase 1C completed on 2026-02-25:
  - Added `scripts/resources/qb/rs_base_effect.gd`
  - Added effect resources under `scripts/resources/qb/effects/`:
    - `rs_effect_dispatch_action.gd`
    - `rs_effect_publish_event.gd`
    - `rs_effect_set_field.gd`
    - `rs_effect_set_context_value.gd`
  - Added test suites:
    - `test_effect_dispatch_action.gd`
    - `test_effect_publish_event.gd`
    - `test_effect_set_field.gd`
    - `test_effect_set_context_value.gd`
  - Verified QB effect tests (13/13 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1D completed on 2026-02-25:
  - Added `scripts/resources/qb/rs_rule.gd`
  - Verified `conditions`/`effects` export metadata in headless via property introspection script
  - Attempted typed arrays (`Array[RS_BaseCondition]`, `Array[RS_BaseEffect]`) but hit headless parser resolution errors for new class symbols
  - Applied documented fallback to `Array[Resource]` in `RS_Rule` pending validator-enforced type checks in Phase 1H
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1E completed on 2026-02-25:
  - Added `scripts/utils/qb/u_rule_scorer.gd`
  - Added `tests/unit/qb/test_rule_scorer.gd` (T81-T90 coverage)
  - Verified QB scorer tests (9/9 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1F completed on 2026-02-25:
  - Added `scripts/utils/qb/u_rule_selector.gd`
  - Added `tests/unit/qb/test_rule_selector.gd` (T93-T100 coverage)
  - Verified QB selector tests (7/7 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1G completed on 2026-02-25:
  - Added `scripts/utils/qb/u_rule_state_tracker.gd` (`class_name RuleStateTracker`)
  - Added `tests/unit/qb/test_rule_state_tracker.gd` (T103-T115 coverage)
  - Verified QB state tracker tests (12/12 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
- Phase 1H completed on 2026-02-25:
  - Added `scripts/utils/qb/u_rule_validator.gd`
  - Added `tests/unit/qb/test_rule_validator.gd` (T118-T129 coverage)
  - Verified QB validator tests (11/11 passing)
  - Verified style suite `tests/unit/style` (12/12 passing)
  - Completed Phase 1 checkpoint (`T1-T131`) with v2 core library implemented in isolation
- Phase 2A completed on 2026-02-25:
  - Deleted 9 v1 QB engine files:
    - `scripts/ecs/systems/base_qb_rule_manager.gd`
    - `scripts/resources/qb/rs_qb_condition.gd`
    - `scripts/resources/qb/rs_qb_effect.gd`
    - `scripts/resources/qb/rs_qb_rule_definition.gd`
    - `scripts/utils/qb/u_qb_rule_evaluator.gd`
    - `scripts/utils/qb/u_qb_quality_provider.gd`
    - `scripts/utils/qb/u_qb_effect_executor.gd`
    - `scripts/utils/qb/u_qb_variant_utils.gd`
    - `scripts/utils/qb/u_qb_rule_validator.gd`
  - Deleted v1 QB tests:
    - 10 v1 unit suites in `tests/unit/qb/`
    - `tests/integration/qb/test_qb_brain_data_pipeline.gd`
  - Deleted 9 legacy v1 QB rule resources under `resources/qb/{character,game,camera}/`
  - Cleared stale deleted-class references from active code
  - Verified style suite `tests/unit/style` (12/12 passing)
  - Verified QB unit suite `tests/unit/qb` (101/101 passing)

## Required Readings

Before making any changes, read these in order:

1. `docs/qb_rule_manager/qb-v2-overview.md` — full architecture (the source of truth)
2. `docs/qb_rule_manager/qb-v2-plan.md` — phased implementation plan
3. `docs/qb_rule_manager/qb-v2-tasks.md` — task checklist (track progress here)
4. `AGENTS.md` — project conventions, naming, testing patterns (will be updated in Phase 5)
5. `docs/general/DEV_PITFALLS.md` — GDScript pitfalls and testing patterns
6. `docs/general/STYLE_GUIDE.md` — prefix conventions

## Architecture Summary (Quick Reference)

**Core change:** The rule engine is a stateless scoring library (two functions), not an ECS base class.

**Layer 1 — Data (Resources):**
- `RS_Rule` — conditions/effects arrays + metadata (currently `Array[Resource]` fallback in headless; validator enforces expected subtypes)
- 5 condition subclasses: ComponentField, ReduxField, EntityTag, EventPayload, Constant
- 4 effect subclasses: DispatchAction, PublishEvent, SetField, SetContextValue
- Typed arrays are planned; headless currently uses `Array[Resource]` fallback with runtime validation

**Layer 2 — Engine (Pure functions):**
- `U_RuleScorer.score_rules(rules, context) → Array[{rule, score}]`
- `U_RuleSelector.select_winners(scored) → Array[{rule, score}]`
- Scoring: per-condition evaluate() → response_curve → invert → multiplicative product → threshold filter
- Selection: partition by decision_group, ungrouped fire independently, grouped pick best (score → priority → rule_id)

**Layer 3 — State tracking (Opt-in):**
- `RuleStateTracker` — cooldowns, rising edge, one-shot. Each consumer creates its own instance.

**Consumers compose the library:**
```gdscript
var context := _build_my_context()
var scored := U_RuleScorer.score_rules(_rules, context)
var winners := U_RuleSelector.select_winners(scored)
_handle_winners(winners, context)  # domain-specific
```

**Key v2 improvements over v1:**
- Typed condition/effect subclasses (no enum soup, no Dictionary payloads)
- `RS_EffectSetField.use_context_value` — dynamic effect values read from context
- `@export var rules: Array[RS_Rule]` on domain systems — designers add rules without editing code
- `S_GameEventSystem` supports global tick context (v1 had no tick capability)
- No 632-line base class to inherit from

## Next Steps

1. **Phase 2B:** Recreate character rule resources with v2 types (`T145-T150`).
2. Work through phases sequentially — each ends with a commit checkpoint.
3. Proceed to Phase 2C once Phase 2B resources pass `U_RuleValidator`.

## Key Design Decisions

1. **Everything is a score.** No separate boolean evaluation. Binary conditions return 0.0 or 1.0. Multiplicative product handles AND.
2. **No method-call fallback.** `U_PathResolver` uses `get()` for Object property access, never `has_method()` + call. Avoids accidental side effects.
3. **Effects are optional.** Some future consumers (AI, dialogue) interpret winning rule identity rather than executing effects. Effects are on the rule but consumers choose whether to execute them.
4. **Handler systems unchanged.** `S_CheckpointHandlerSystem`, `S_VictoryHandlerSystem`, `S_DeathHandlerSystem` subscribe to ECS events. They have zero coupling to rule engine internals and are NOT modified.
5. **Context is a plain Dictionary.** No typed context class. Keys are documented per domain. Conditions resolve paths within it. Effects write to it.
6. **One tracker per consumer.** `RuleStateTracker` instances are not shared. Each domain system manages its own cooldown/rising-edge/one-shot state.
7. **Renamed systems reflect actual responsibility:** `S_CharacterStateSystem` (brain data), `S_GameEventSystem` (event routing), `S_CameraStateSystem` (camera behavior). Not "rule managers."

## File Map (v2)

### New files (Phase 1)

```
scripts/resources/qb/rs_rule.gd
scripts/resources/qb/rs_base_condition.gd
scripts/resources/qb/conditions/rs_condition_component_field.gd
scripts/resources/qb/conditions/rs_condition_redux_field.gd
scripts/resources/qb/conditions/rs_condition_entity_tag.gd
scripts/resources/qb/conditions/rs_condition_event_payload.gd
scripts/resources/qb/conditions/rs_condition_constant.gd
scripts/resources/qb/rs_base_effect.gd
scripts/resources/qb/effects/rs_effect_dispatch_action.gd
scripts/resources/qb/effects/rs_effect_publish_event.gd
scripts/resources/qb/effects/rs_effect_set_field.gd
scripts/resources/qb/effects/rs_effect_set_context_value.gd
scripts/utils/qb/u_rule_scorer.gd
scripts/utils/qb/u_rule_selector.gd
scripts/utils/qb/u_rule_state_tracker.gd
scripts/utils/qb/u_rule_validator.gd
scripts/utils/qb/u_path_resolver.gd
```

### Deleted files (Phase 2A)

```
scripts/ecs/systems/base_qb_rule_manager.gd
scripts/resources/qb/rs_qb_condition.gd
scripts/resources/qb/rs_qb_effect.gd
scripts/resources/qb/rs_qb_rule_definition.gd
scripts/utils/qb/u_qb_rule_evaluator.gd
scripts/utils/qb/u_qb_quality_provider.gd
scripts/utils/qb/u_qb_effect_executor.gd
scripts/utils/qb/u_qb_variant_utils.gd
scripts/utils/qb/u_qb_rule_validator.gd
```

### Renamed files (Phases 2-4)

```
s_character_rule_manager.gd → s_character_state_system.gd (S_CharacterStateSystem)
s_game_rule_manager.gd      → s_game_event_system.gd (S_GameEventSystem)
s_camera_rule_manager.gd    → s_camera_state_system.gd (S_CameraStateSystem)
```

### Unchanged files

```
s_checkpoint_handler_system.gd  (event subscriber, no rule engine coupling)
s_victory_handler_system.gd     (event subscriber, no rule engine coupling)
s_death_handler_system.gd       (event subscriber, no rule engine coupling)
```

## Testing Commands

```bash
# Run QB v2 unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/qb -gexit

# Run QB v2 integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/qb -gexit

# Run ECS tests (verify handler systems still work)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Run style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Run all tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## GDScript Pitfalls (Relevant to v2)

- `tr` cannot be a method name — collides with `Object.tr()`. Use `localize()` or similar.
- `String(value)` fails for arbitrary Variants — use `str(value)`.
- Inner class names must start with a capital letter.
- Typed arrays with Resource subclasses: verify inspector dropdown behavior in Phase 1D before proceeding.
- `@export var conditions: Array[RS_BaseCondition]` — Godot 4.x supports this and shows a subclass picker. If it doesn't work as expected, fall back to `Array[Resource]` with runtime type checks.

## Outstanding Risks

- **Typed Resource arrays in inspector:** Godot 4.6 should support `Array[RS_BaseCondition]` with subclass dropdown. Verify in Phase 1D (T79-T80) before building all resources on this assumption.
- **Scene references after rename:** `.tscn` files referencing old script paths (`s_character_rule_manager.gd`) need updating. Grep all scenes in Phases 2-4.
- **v1 test deletion scope:** Phase 2A deletes v1 tests. Ensure v2 tests from Phase 1 are in separate files that won't be caught in the deletion.

## Links

- [Overview](qb-v2-overview.md)
- [Plan](qb-v2-plan.md)
- [Tasks](qb-v2-tasks.md)
- [v1 Overview (archived)](v1/qb-rule-manager-overview.md)
- [v1 Tasks (archived)](v1/qb-rule-manager-tasks.md)
- [v1 Continuation (archived)](v1/qb-rule-manager-continuation-prompt.md)
