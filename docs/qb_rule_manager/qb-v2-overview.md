# QB Rule Engine v2 — Architecture Overview

## What Changed from v1

v1 was a **rule engine baked into an ECS system**. `BaseQBRuleManager` extended `BaseECSSystem` and owned everything: the tick loop, context building, scoring, selection, effect execution, cooldown tracking, salience detection, and event subscriptions — 632 lines in the base class alone, plus 5 utility classes (~800 lines).

v2 inverts the design. The rule engine is a **stateless scoring library** — two pure functions. Every domain system (character, camera, game, and future systems like AI, narrative, scene director) calls the library when it needs a decision. The complexity lives in the domain, not the engine.

### Why

v1 served 3 managers with 9 rules. The roadmap adds objectives, scene director, vCam, HTN AI, narrative, dialogue, cutscenes, and animation — all quality-based. Under v1, each would subclass `BaseQBRuleManager`, inherit 632 lines of tick/cooldown/salience machinery, and override 3-5 virtual methods to inject domain context. Under v2, each domain system composes a ~15-line scoring call with its own context and interprets the results in its domain-specific way.

### Breaking Changes

No backwards compatibility. All v1 scripts, resources, and tests are replaced.

---

## Core Mental Model

```
Rule = Conditions[] + Effects[] + metadata
         |
         v
  evaluate each condition → score (0.0 to 1.0)
         |
         v
  multiply all scores → final rule score
         |
         v
  if score > threshold → candidate
         |
         v
  decision group competition → winners
         |
         v
  execute winner effects (optional — domain may interpret winners directly)
```

**Everything is a score.** There is no separate boolean evaluation pass. A binary condition returns 0.0 or 1.0. The multiplicative product means any 0.0 condition kills the rule (logical AND). Response curves remap raw scores for non-linear preferences.

---

## The Three Layers

### Layer 1 — Data (Resources, designer-authored)

Resource hierarchy using `RS_BaseCondition`/`RS_BaseEffect` subclasses. `RS_Rule` currently uses `Array[Resource]` fallback for headless parser stability, with runtime subtype validation in `U_RuleValidator`.

```
RS_Rule                          ← rule definition with Resource arrays + validator checks
RS_BaseCondition                 ← abstract, virtual evaluate() → float
├── RS_ConditionComponentField   ← reads ECS component property
├── RS_ConditionReduxField       ← reads Redux state path
├── RS_ConditionEntityTag        ← checks tag presence (binary)
├── RS_ConditionEventName        ← checks current event_name (binary)
├── RS_ConditionEventPayload     ← reads from event payload
└── RS_ConditionConstant         ← fixed score (weighting / fallback weighting)

RS_BaseEffect                    ← abstract, virtual execute()
├── RS_EffectDispatchAction      ← dispatches Redux action
├── RS_EffectPublishEvent        ← publishes ECS event
├── RS_EffectSetField            ← sets component field (typed exports)
└── RS_EffectSetContextValue     ← writes to context dict (brain data)
```

Each subclass exposes only its relevant fields in the inspector. A `RS_ConditionComponentField` shows component_type, field_path, range_min, range_max. A `RS_ConditionEntityTag` shows tag_name. No enum soup.

### Layer 2 — Engine (Pure functions, stateless)

```gdscript
# Score all rules against a context. Returns Array[Dictionary] of {rule, score}.
U_RuleScorer.score_rules(rules: Array[RS_Rule], context: Dictionary) -> Array[Dictionary]

# Select winners from scored results. Handles decision groups + tiebreak.
U_RuleSelector.select_winners(scored_results: Array[Dictionary]) -> Array[Dictionary]
```

Two static functions. ~100 lines total. No state, no side effects, trivially testable.

**Scoring algorithm:**
1. For each rule, evaluate every condition: `condition.evaluate(context) → float`
   - Rules with empty condition arrays are invalid (validator error) and score as `0.0` at runtime
2. If condition has a `response_curve`, remap: `curve.sample_baked(clampf(score, 0.0, 1.0))`
3. If condition has `invert`, flip: `1.0 - score`
4. Multiply all condition scores (short-circuit on 0.0)
5. If final score > `rule.score_threshold`, the rule is a candidate

**Selection algorithm:**
1. Partition candidates by `decision_group`
2. Rules with empty group fire independently (all of them)
3. Within each non-empty group, pick the best candidate:
   - Highest score wins
   - Tie: highest priority wins
   - Tie: alphabetically first `rule_id` wins (deterministic)

### Layer 3 — State Tracking (Opt-in, per-consumer instance)

```gdscript
var _tracker := RuleStateTracker.new()

# In tick:
_tracker.tick_cooldowns(delta)
if _tracker.is_on_cooldown(rule_id, context_key):
    # skip
if _tracker.check_rising_edge(rule_id, context_key, is_passing_now):
    # rule just became true (was false last tick)

# After firing:
_tracker.mark_fired(rule_id, context_key, cooldown_duration)
_tracker.mark_one_shot_spent(rule_id)

# Maintenance:
_tracker.cleanup_stale_contexts(active_context_keys)
```

Each domain consumer creates its own `RuleStateTracker` instance. No shared mutable static state. ~80-100 lines.

Tracks:
- **Cooldowns**: Per-rule or per-rule+context. Global and context-scoped.
- **Rising edge**: Per-rule+context boolean history for "just became true" detection.
- **One-shot**: Per-rule "already fired" flag.

---

## Resource Definitions

### RS_Rule

```gdscript
class_name RS_Rule extends Resource

@export_group("Identity")
@export var rule_id: StringName
@export_multiline var description: String

@export_group("Trigger")
@export_enum("tick", "event", "both") var trigger_mode: String = "tick"

@export_group("Evaluation")
@export var conditions: Array[Resource] = []  ## fallback; validator enforces RS_BaseCondition
@export var effects: Array[Resource] = []     ## fallback; validator enforces RS_BaseEffect
@export var score_threshold: float = 0.0

@export_group("Selection")
@export var decision_group: StringName
@export var priority: int = 0

@export_group("Behavior")
@export var cooldown: float = 0.0
@export var one_shot: bool = false
@export var requires_rising_edge: bool = false
```

**Key differences from v1 `RS_QBRuleDefinition`:**
- `conditions/effects` remain `Array[Resource]` in Phase 1 due headless parser instability; subtype checks are enforced by `U_RuleValidator` until typed arrays are safely reintroduced
- `requires_rising_edge` — clearer name (was `requires_salience`)
- `score_threshold` — explicit minimum score to be a candidate (was implicit > 0.0)
- Removed: `cooldown_key_fields`, `cooldown_from_context_field` — context-scoped cooldowns are handled by `RuleStateTracker` API, not baked into the resource

### RS_BaseCondition

```gdscript
class_name RS_BaseCondition extends Resource

@export var response_curve: Curve  ## optional: remaps raw 0-1 score
@export var invert: bool = false   ## flips score: 1.0 - score

## Override in subclasses. Return 0.0 (irrelevant) to 1.0 (perfect fit).
func evaluate(_context: Dictionary) -> float:
    return 0.0
```

### RS_ConditionComponentField

```gdscript
class_name RS_ConditionComponentField extends RS_BaseCondition

@export_group("Source")
@export var component_type: StringName  ## e.g. &"C_HealthComponent"
@export var field_path: String          ## e.g. "health_percent" or "nested.field"

@export_group("Normalize")
@export var range_min: float = 0.0      ## maps to score 0.0
@export var range_max: float = 1.0      ## maps to score 1.0
```

Reads a component field from `context["components"][component_type]`, traverses `field_path` via dot-path resolution. Booleans → 0.0/1.0 directly. Numerics → normalized via `clampf((value - range_min) / (range_max - range_min), 0.0, 1.0)` with division-by-zero guard.

### RS_ConditionReduxField

```gdscript
class_name RS_ConditionReduxField extends RS_BaseCondition

@export_group("Source")
@export var state_path: String          ## e.g. "gameplay.health_percent" or "navigation.shell"

@export_group("Match")
@export_enum("normalize", "equals", "not_equals") var match_mode: String = "normalize"
@export var match_value_string: String  ## for equals/not_equals mode

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0
```

Two modes: **normalize** (numeric range → 0-1 score, same as component field) or **equals/not_equals** (string/bool comparison → binary 0.0/1.0). Covers the v1 use cases (IS_TRUE on booleans, NOT_EQUALS on shell string) with clearer semantics.

### RS_ConditionEntityTag

```gdscript
class_name RS_ConditionEntityTag extends RS_BaseCondition

@export var tag_name: StringName  ## tag to check for
```

Returns 1.0 if `context["entity_tags"]` contains `tag_name`, 0.0 otherwise. Binary.

### RS_ConditionEventPayload

```gdscript
class_name RS_ConditionEventPayload extends RS_BaseCondition

@export_group("Source")
@export var field_path: String  ## path into event_payload dict

@export_group("Match")
@export_enum("exists", "normalize", "equals", "not_equals") var match_mode: String = "exists"
@export var match_value_string: String

@export_group("Normalize")
@export var range_min: float = 0.0
@export var range_max: float = 1.0
```

Reads from `context["event_payload"]`. `exists` mode returns 1.0 if field is non-null. Other modes match component/redux behavior.

### RS_ConditionEventName

```gdscript
class_name RS_ConditionEventName extends RS_BaseCondition

@export_group("Source")
@export var expected_event_name: StringName

@export_group("Match")
@export_enum("equals", "not_equals") var match_mode: String = "equals"
```

Reads `context["event_name"]` and returns binary score based on match mode.

### RS_ConditionConstant

```gdscript
class_name RS_ConditionConstant extends RS_BaseCondition

@export_range(0.0, 1.0) var score: float = 1.0
```

Always returns `score`. Useful for weighting rules in a decision group (e.g., a "preferred fallback" rule with score 0.5 that loses to any real condition scoring above 0.5).

### RS_BaseEffect

```gdscript
class_name RS_BaseEffect extends Resource

## Override in subclasses.
func execute(_context: Dictionary) -> void:
    pass
```

### RS_EffectDispatchAction

```gdscript
class_name RS_EffectDispatchAction extends RS_BaseEffect

@export var action_type: StringName
@export var payload: Dictionary
```

Dispatches `{type: action_type, payload: payload}` to `context["state_store"]`.

### RS_EffectPublishEvent

```gdscript
class_name RS_EffectPublishEvent extends RS_BaseEffect

@export var event_name: StringName
@export var payload: Dictionary
@export var inject_entity_id: bool = true  ## auto-adds entity_id from context
```

Publishes via `U_ECSEventBus.publish()`. If `inject_entity_id` is true and context has `entity_id`, it's merged into the payload.

### RS_EffectSetField

```gdscript
class_name RS_EffectSetField extends RS_BaseEffect

@export_group("Target")
@export var component_type: StringName
@export var field_name: StringName

@export_group("Value")
@export_enum("set", "add") var operation: String = "set"
@export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "float"
@export var float_value: float
@export var int_value: int
@export var bool_value: bool
@export var string_value: String
@export var string_name_value: StringName

@export_group("Dynamic Value")
@export var use_context_value: bool = false
@export var context_value_path: String  ## reads value from context instead of literal

@export_group("Clamp")
@export var use_clamp: bool = false
@export var clamp_min: float = 0.0
@export var clamp_max: float = 1.0
```

Resolves the typed value (literal or from context via `context_value_path`), applies operation (set or add), optionally clamps. Writes to `context["components"][component_type][field_name]`.

**Key improvement over v1:** `use_context_value` + `context_value_path` enables dynamic effect values. A FOV zone rule can read the desired FOV from context instead of hardcoding 60.0.

### RS_EffectSetContextValue

```gdscript
class_name RS_EffectSetContextValue extends RS_BaseEffect

@export var context_key: StringName
@export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "bool"
@export var float_value: float
@export var int_value: int
@export var bool_value: bool
@export var string_value: String
@export var string_name_value: StringName
```

Writes directly to `context[context_key]`. Used for brain data patterns (character state defaults overridden by rules, then written back to component in post-tick).

---

## Shared Utility: U_PathResolver

Single utility replacing v1's `U_QBQualityProvider._resolve_path_from_container` and `U_QBRuleEvaluator._resolve_quality_value`:

```gdscript
class_name U_PathResolver extends RefCounted

## Resolves a dot-path through nested Dictionaries, Arrays, and Objects.
## Returns null if any segment fails to resolve.
static func resolve(root: Variant, path: String) -> Variant
```

Handles:
- Dictionary keys (tries both String and StringName)
- Array indices (integer segments)
- Object properties (via `get()` — no method-call fallback, unlike v1)

Used by condition subclasses internally. Not called by consumers directly.

---

## Rule Validation: U_RuleValidator

Adapted from v1's `U_QBRuleValidator`. Validates at configure time:

- `rule_id` non-empty
- `conditions` must contain at least one entry
- event/both trigger modes require at least one `RS_ConditionEventName` condition
- Conditions are valid `RS_BaseCondition` instances (enforced by `U_RuleValidator` while `RS_Rule` uses `Array[Resource]` fallback)
- Effects are valid `RS_BaseEffect` instances
- `RS_ConditionComponentField`: `component_type` non-empty, `field_path` non-empty, `range_min < range_max` when both non-zero
- `RS_ConditionReduxField`: `state_path` non-empty, contains `.` (slice.field format)
- `RS_ConditionEventName`: `expected_event_name` non-empty
- `RS_EffectSetField`: `component_type` and `field_name` non-empty
- Warning (alongside validation error): decision group on unconditional rule with no rising edge requirement

Returns `{valid_rules: Array[RS_Rule], errors_by_index: Dictionary, errors_by_rule_id: Dictionary}`.

---

## Domain Consumers: Migrated Managers

### S_CharacterStateSystem (was S_CharacterRuleManager)

Renamed to reflect its actual responsibility: computing character brain data. Still an ECS system (`extends BaseECSSystem`), still ticks every physics frame.

**Responsibilities:**
1. Query entities with `C_CharacterStateComponent`
2. Build context per entity (defaults + component reads + Redux snapshot)
3. Call `U_RuleScorer.score_rules()` + `U_RuleSelector.select_winners()`
4. Execute winning effects (writes to context via `RS_EffectSetContextValue`)
5. Write final context values back to `C_CharacterStateComponent`

**Key change:** No base class inheritance from a rule manager. Composes the scoring library directly. The `RuleStateTracker` is instantiated locally.

```gdscript
@export var rules: Array[RS_Rule] = []   ## designer can add rules in inspector
var _tracker := RuleStateTracker.new()

const DEFAULT_RULES: Array[RS_Rule] = [
    preload("res://resources/qb/character/cfg_pause_gate_paused.tres"),
    # ...
]

func process_tick(delta: float) -> void:
    _tracker.tick_cooldowns(delta)
    var all_rules: Array[RS_Rule] = DEFAULT_RULES + rules
    for entity_context in _build_entity_contexts():
        var scored := U_RuleScorer.score_rules(all_rules, entity_context)
        var winners := U_RuleSelector.select_winners(scored)
        _execute_effects(winners, entity_context)
        _write_brain_data(entity_context)
```

### S_GameEventSystem (was S_GameRuleManager)

Renamed to reflect its actual responsibility: routing game events through configurable rules. Still an ECS system but event-driven (no tick evaluation).

**Responsibilities:**
1. Subscribe to configured trigger events
2. On event: build context from event payload + Redux state
3. Score rules, select winners, execute effects
4. Handler systems (`S_CheckpointHandlerSystem`, `S_VictoryHandlerSystem`, `S_DeathHandlerSystem`) remain unchanged — they subscribe to the published events

**Key change:** Now has a global tick context option. If any rules have `trigger_mode = "tick"`, the system builds a single global context (Redux state + game metadata) and evaluates tick rules each frame. This enables frame-polled game-level conditions.

### S_CameraStateSystem (was S_CameraRuleManager)

Renamed. Still an ECS system, still ticks every frame.

**Responsibilities:**
1. Query camera entities with `C_CameraStateComponent`
2. Build context per camera
3. Score rules, select winners, execute effects
4. Apply camera state (FOV blending, trauma shake)

**Key change:** Camera-specific logic (FOV lerp, shake decay, baseline FOV capture) remains in this system. It is domain-specific behavior that belongs here, not in the rule engine.

---

## Context Dictionary Contract

Every domain builds a context `Dictionary` before calling the scorer. The contract is simple: conditions read from it, effects write to it.

### Standard Keys (available in all contexts)

| Key | Type | Description |
|---|---|---|
| `state_store` | `I_StateStore` | For effects that dispatch actions |
| `redux_state` | `Dictionary` | Snapshot of full Redux state |
| `entity_id` | `StringName` | Entity ID (if per-entity context) |
| `entity_tags` | `Array[StringName]` | Entity tags (if per-entity context) |
| `entity` | `Node` | Entity node reference |
| `components` | `Dictionary` | `{component_type → component_instance}` |
| `event_name` | `StringName` | Current event name (if event-triggered evaluation) |
| `event_payload` | `Dictionary` | Event data (if event-triggered evaluation) |

**Context availability by consumer level:** `entity_id`, `entity_tags`, `entity`, and `components` are only available in per-entity contexts (ECS systems like S_CharacterStateSystem, S_CameraStateSystem). Manager-level consumers (M_ObjectivesManager, M_SceneDirector, future narrative/dialogue systems) build contexts without entity data — use `RS_ConditionReduxField`, `RS_ConditionEventName`, `RS_ConditionEventPayload`, or `RS_ConditionConstant` in those contexts, not `RS_ConditionComponentField` or `RS_ConditionEntityTag`.

### Domain-Specific Keys

Each domain adds its own keys. The character system adds `is_gameplay_active`, `is_grounded`, `is_dead`, `health_percent`, etc. The camera system adds `shake_trauma`, `base_fov`, `target_fov`. Future domains add whatever they need. The scoring library doesn't know or care about these keys — conditions resolve them via their configured paths.

---

## How Domain Systems Consume the Library

Every consumer follows the same 5-line pattern:

```gdscript
var context := _build_my_context()                          # domain-specific
var scored := U_RuleScorer.score_rules(_my_rules, context)  # universal
var winners := U_RuleSelector.select_winners(scored)        # universal
_do_something_with_winners(winners, context)                # domain-specific
```

Some domains execute effects. Others interpret the winning rule's identity:

| Domain | Evaluates when | Winner interpretation |
|---|---|---|
| Character state | Every tick per entity | Execute effects → write brain data |
| Game events | On ECS events | Execute effects (publish forwarded events) |
| Camera state | Every tick per camera | Execute effects → apply FOV/shake |
| Scene director (future) | Every N seconds | Winner = current pacing beat |
| HTN AI (future) | Every tick per NPC | Winner = active behavior |
| Narrative (future) | On trigger | Winner = story beat to advance |
| Dialogue (future) | On interaction | Winner = line to speak |
| Animation (future) | Every tick per entity | Winner = animation state to blend |
| Objectives (future) | On game events | Winners = active/completed objectives |

---

## Anti-Patterns

- Do NOT subclass the scoring library — compose it
- Do NOT put domain logic in condition/effect subclasses — keep them pure data resolvers/writers
- Do NOT share `RuleStateTracker` instances across domains — each gets its own
- Do NOT use `RS_EffectSetField` for complex multi-step logic — write a handler system that subscribes to a published event instead
- Do NOT add new condition subclasses for one-off checks — use `RS_ConditionConstant` with `invert` or pre-compute in context building
- Do NOT cache `redux_state` across ticks — always snapshot fresh

---

## File Summary

### New Files

| File | Class | Lines (est.) |
|---|---|---|
| `scripts/resources/qb/rs_rule.gd` | `RS_Rule` | ~40 |
| `scripts/resources/qb/rs_base_condition.gd` | `RS_BaseCondition` | ~15 |
| `scripts/resources/qb/conditions/rs_condition_component_field.gd` | `RS_ConditionComponentField` | ~40 |
| `scripts/resources/qb/conditions/rs_condition_redux_field.gd` | `RS_ConditionReduxField` | ~45 |
| `scripts/resources/qb/conditions/rs_condition_entity_tag.gd` | `RS_ConditionEntityTag` | ~15 |
| `scripts/resources/qb/conditions/rs_condition_event_name.gd` | `RS_ConditionEventName` | ~30 |
| `scripts/resources/qb/conditions/rs_condition_event_payload.gd` | `RS_ConditionEventPayload` | ~40 |
| `scripts/resources/qb/conditions/rs_condition_constant.gd` | `RS_ConditionConstant` | ~10 |
| `scripts/resources/qb/rs_base_effect.gd` | `RS_BaseEffect` | ~10 |
| `scripts/resources/qb/effects/rs_effect_dispatch_action.gd` | `RS_EffectDispatchAction` | ~20 |
| `scripts/resources/qb/effects/rs_effect_publish_event.gd` | `RS_EffectPublishEvent` | ~25 |
| `scripts/resources/qb/effects/rs_effect_set_field.gd` | `RS_EffectSetField` | ~60 |
| `scripts/resources/qb/effects/rs_effect_set_context_value.gd` | `RS_EffectSetContextValue` | ~25 |
| `scripts/utils/qb/u_rule_scorer.gd` | `U_RuleScorer` | ~50 |
| `scripts/utils/qb/u_rule_selector.gd` | `U_RuleSelector` | ~50 |
| `scripts/utils/qb/u_rule_state_tracker.gd` | `RuleStateTracker` | ~100 |
| `scripts/utils/qb/u_rule_validator.gd` | `U_RuleValidator` | ~80 |
| `scripts/utils/qb/u_path_resolver.gd` | `U_PathResolver` | ~50 |

### Deleted Files (v1)

| File | Reason |
|---|---|
| `scripts/ecs/systems/base_qb_rule_manager.gd` | Replaced by library + per-domain systems |
| `scripts/resources/qb/rs_qb_condition.gd` | Replaced by typed condition subclasses |
| `scripts/resources/qb/rs_qb_effect.gd` | Replaced by typed effect subclasses |
| `scripts/resources/qb/rs_qb_rule_definition.gd` | Replaced by `RS_Rule` |
| `scripts/utils/qb/u_qb_rule_evaluator.gd` | Replaced by `U_RuleScorer` |
| `scripts/utils/qb/u_qb_quality_provider.gd` | Replaced by condition subclass `evaluate()` methods |
| `scripts/utils/qb/u_qb_effect_executor.gd` | Replaced by effect subclass `execute()` methods |
| `scripts/utils/qb/u_qb_variant_utils.gd` | Replaced by `U_PathResolver` |
| `scripts/utils/qb/u_qb_rule_validator.gd` | Replaced by `U_RuleValidator` |

### Modified Files (migrated)

| File | Change |
|---|---|
| `scripts/ecs/systems/s_character_rule_manager.gd` | Rename → `s_character_state_system.gd`, compose library instead of extending base |
| `scripts/ecs/systems/s_game_rule_manager.gd` | Rename → `s_game_event_system.gd`, compose library, add global tick context |
| `scripts/ecs/systems/s_camera_rule_manager.gd` | Rename → `s_camera_state_system.gd`, compose library instead of extending base |
| All 9 `.tres` files in `resources/qb/` | Recreate with new resource types |
| `AGENTS.md` | Update QB sections |
| `docs/general/STYLE_GUIDE.md` | Remove `base_qb_rule_manager.gd` naming exception |
| `docs/general/DEV_PITFALLS.md` | Update QB pitfall entries |

### Unchanged Files

| File | Why |
|---|---|
| `scripts/ecs/systems/s_checkpoint_handler_system.gd` | Subscribes to events — no coupling to rule engine internals |
| `scripts/ecs/systems/s_victory_handler_system.gd` | Same — event subscriber |
| `scripts/ecs/systems/s_death_handler_system.gd` | Same — event subscriber |
