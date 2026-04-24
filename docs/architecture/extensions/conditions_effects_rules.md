# Add Condition / Effect / Rule

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new condition type (extends `RS_BaseCondition`)
- A new effect type (extends `RS_BaseEffect`)
- A new rule resource (`.tres` using `RS_Rule`)
- A new consumer system that uses the QB scoring pipeline

This recipe does **not** cover:

- AI behavior (see `ai.md`)
- ECS component/system authoring (see `ecs.md`)
- Event bus subscriptions (see `events.md`)

## Governing ADR(s)

- [ADR 0004: Event Bus](../adr/0004-event-bus.md) (event-triggered rules)
- [ADR 0006: AI Architecture](../adr/0006-ai-architecture-utility-bt-with-scoped-planning.md) (BT conditions use `I_Condition`)

## Canonical Example

- Condition: `scripts/resources/qb/conditions/rs_condition_component_field.gd`
- Effect: `scripts/resources/qb/effects/rs_effect_publish_event.gd`
- Rule: `resources/qb/<domain>/cfg_<name>.tres` (`RS_Rule`)
- Consumer: `scripts/ecs/systems/s_character_state_system.gd`
- Scoring: `scripts/utils/qb/u_rule_scorer.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `I_Condition` | Interface: `evaluate(context) -> float` (0.0–1.0). |
| `I_Effect` | Interface: `execute(context) -> void`. |
| `RS_BaseCondition` | Base: `response_curve: Curve`, `invert: bool`, virtual `_evaluate_raw(context) -> float`. Helpers: `_score_numeric()`, `_matches_string()`. |
| `RS_BaseEffect` | Base: virtual `execute(context) -> void`. |
| `RS_Rule` | Resource: `conditions: Array[I_Condition]`, `effects: Array[I_Effect]`, `rule_id`, `trigger_mode`, `score_threshold`, `decision_group`, `priority`, `cooldown`, `one_shot`, `requires_rising_edge`. |
| `U_RuleScorer` | Static: `score_rules(rules, context) -> Array[Dictionary]`. Multiplicative product, short-circuits on 0.0. |
| `U_RuleSelector` | Static: `select_winners(scored) -> Array[Dictionary]`. Groups by `decision_group`, highest score wins. |
| `U_RuleStateTracker` | Per-system instance: cooldowns, rising-edge, one-shot tracking. |
| `U_RuleValidator` | Static: `validate_rules(rules) -> Dictionary`. Checks rule_id, conditions, event requirements. |

Conditions under `scripts/resources/qb/conditions/`. Effects under `scripts/resources/qb/effects/`.

## Recipe

### Adding a new condition type

1. Create `scripts/resources/qb/conditions/rs_condition_<name>.gd`: extend `RS_BaseCondition`, `class_name RS_Condition<Name>`, `@export` fields with `@export_group` annotations, override `_evaluate_raw(context) -> float` returning 0.0–1.0.
2. Use inherited helpers: `_score_numeric_or_bool()`, `_matches_string()`, `_get_dict_value_string_or_name()`.
3. Use `U_PathResolver.resolve()` for dot-path traversal if needed.
4. Add validation case to `U_RuleValidator._validate_condition_entry()` for required fields.

### Adding a new effect type

1. Create `scripts/resources/qb/effects/rs_effect_<name>.gd`: extend `RS_BaseEffect`, `class_name RS_Effect<Name>`, `@export` fields, override `execute(context) -> void`.
2. Add validation case to `U_RuleValidator._validate_effects()` for required fields.

### Adding a new rule

1. Create `.tres` under `resources/qb/<domain>/cfg_<name>.tres` with `RS_Rule` class.
2. Set `rule_id`, `trigger_mode`, `score_threshold`, `decision_group`, `priority`, `cooldown`, `one_shot`, `requires_rising_edge`.
3. Add at least one condition. If `trigger_mode` is `"event"` or `"both"`, must include `RS_ConditionEventName`.
4. Add effects.
5. Consumer loads, validates via `U_RuleValidator.validate_rules()`, scores via `U_RuleScorer.score_rules()`, selects via `U_RuleSelector.select_winners()`.

### Adding a new consumer system

1. Own a `U_RuleStateTracker` instance (one per domain, never shared).
2. Build context per entity/tick with standard keys: `state_store`, `redux_state`, `entity_id`, `entity_tags`, `entity`, `components`, `event_name`, `event_payload`.
3. Score → select → execute effects.
4. Tick cooldowns: `_tracker.tick_cooldowns(delta)`.

## Anti-patterns

- **Subclassing the scoring library**: Compose it, don't extend it.
- **Domain logic in condition/effect subclasses**: Keep them pure data resolvers/writers.
- **Sharing `U_RuleStateTracker` instances across domains**: Each domain gets its own.
- **Using `RS_EffectSetField` for complex multi-step logic**: Publish an event and write a handler system instead.
- **One-off condition subclasses**: Use `RS_ConditionConstant` with `invert` or pre-compute in context building.
- **Caching `redux_state` across ticks**: Always snapshot fresh.
- **`U_PathResolver` has no method-call fallback**: Conditions/effects must resolve through dictionary/object property paths only.

## Out Of Scope

- AI behavior: see `ai.md`
- ECS events: see `events.md`
- Manager registration: see `managers.md`

## References

- [QB Rule Manager v2 Overview](../../systems/qb_rule_manager/qb-v2-overview.md)