# QB Rule Manager - Architecture Overview

## Problem Statement

6 ECS systems independently duplicate identical pause-gating code (S_MovementSystem, S_JumpSystem, S_GravitySystem, S_RotateToInputSystem, S_InputSystem, S_FootstepSoundSystem). 3 systems independently check spawn freeze with different side effects. Death sequencing, checkpoint activation, and victory prerequisites are hardcoded if/then chains scattered across systems.

**Note on S_FootstepSoundSystem**: Uses a slightly different pause check pattern (`U_StateUtils.try_get_store()` with `Engine.is_editor_hint()` guard instead of `U_StateUtils.get_store()`), but the gating logic is functionally identical.

## Solution

The QB Rule Manager introduces a data-driven condition-effect rule engine that centralizes decision logic into declarative rules (Resource `.tres` files), while leaving the existing physics math (second-order dynamics, spring-damped hover, coyote time, slope limits) in the systems where it belongs.

**Scope**: Decision/gating logic only. Physics math stays in existing systems. Migration is additive.

---

## Core Concepts

### Rules

A rule is a condition-effect pair: "when ALL conditions are met, execute effects."

```
Rule: "death_sequence"
  Conditions:
    - C_HealthComponent.current_health <= 0
    - C_CharacterStateComponent.is_dead == false
  Effects:
    - SET_COMPONENT_FIELD: C_CharacterStateComponent.is_dead = true
    - DISPATCH_ACTION: gameplay/trigger_death
    - CALL_METHOD: _handle_spawn_ragdoll
```

### OR Logic

OR conditions are expressed as multiple rules with the same effect. Two rules:
- `cfg_pause_gate_paused.tres`: condition `gameplay.paused == true` -> SET_QUALITY is_gameplay_active = false
- `cfg_pause_gate_shell.tres`: condition `navigation.shell != "gameplay"` -> SET_QUALITY is_gameplay_active = false

### Conditions (RS_QBCondition)

A condition evaluates a single quality against a typed comparison value using an operator.

**Sources**: Component fields, Redux state slices, event payloads, entity tags, custom qualities.

**Operators**: EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GTE, LTE, HAS, NOT_HAS, IS_TRUE, IS_FALSE.

**Typed values**: Godot 4.x cannot export Variant. Conditions use typed fields:
- `value_float: float`
- `value_int: int`
- `value_string: String`
- `value_bool: bool`
- `value_string_name: StringName`

A `ValueType` enum selects which field the evaluator reads.

### Effects (RS_QBEffect)

An effect is an action triggered when all conditions pass.

**Types**: DISPATCH_ACTION (Redux), PUBLISH_EVENT (ECS event bus), SET_COMPONENT_FIELD, CALL_METHOD, SET_QUALITY.

**CALL_METHOD**: Complex effects (ragdoll spawning, checkpoint activation) are subclass handler methods on the rule manager. The effect's `target` field names the method (e.g., `"_handle_spawn_ragdoll"`).

**No delay in Phase 1**: The `delay` field is deferred to post-Phase 6 to reduce speculative complexity.

### Qualities

Observable properties of entities and the world. Read by the Quality Provider from:
- ECS components (e.g., `C_HealthComponent.current_health`)
- Redux state (e.g., `gameplay.player_health`)
- Entity tags (e.g., has tag "player")
- Event payloads (for event-triggered rules)

### Salience

Rules are salient -- they only fire when their conditions transition from false to true, not continuously. This prevents a "health <= 0" rule from firing every tick while the entity is dead.

**Event salience auto-disable**: Events are instantaneous, not persistent. Salience is automatically disabled for EVENT trigger mode rules (regardless of the `requires_salience` setting). Only TICK and BOTH modes use salience.

### Lifecycle

Rules have lifecycle properties:
- **Priority**: Evaluation order (higher = evaluated first; ties broken by rule_id alphabetical)
- **Cooldown**: Minimum time between firings
- **One-shot**: Fire once then deactivate
- **Active/inactive**: Runtime enable/disable

### Trigger Modes

- **TICK**: Evaluated every physics frame (salience applies)
- **EVENT**: Evaluated when a specific ECS event is published (salience auto-disabled)
- **BOTH**: Evaluated on both tick and event (salience applies for tick evaluations)

---

## Class Hierarchy

```
Resources (data):
  RS_QBCondition               -- Typed condition predicate (value_float/int/string/bool/string_name)
  RS_QBEffect                  -- Effect action (no delay in Phase 1)
  RS_QBRuleDefinition          -- Complete rule resource

Engine (logic):
  BaseQBRuleManager            -- Abstract rule evaluation engine (extends BaseECSSystem, priority=1)
    S_CharacterRuleManager       -- Per-entity character rules
    S_GameRuleManager            -- World-level game rules (checkpoint, victory)
    S_CameraRuleManager          -- Camera behavior rules

Utilities:
  U_QBRuleEvaluator            -- Pure condition evaluation functions
  U_QBEffectExecutor           -- Pure effect execution functions
  U_QBQualityProvider          -- Reads qualities from ECS components + Redux state
  U_QBRuleValidator            -- Authoring-time validation

Components:
  C_CharacterStateComponent    -- Aggregated character qualities ("brain data")
  C_CameraStateComponent       -- Camera qualities (fov, trauma)
```

---

## Data Flow

```
[ECS Components] + [Redux State]
        |
        v
  U_QBQualityProvider.read_quality()    -- unified adapter
        |
        v
  BaseQBRuleManager.process_tick(delta)
        |
        v  (subclass loops over target entities)
  _build_quality_context(entity, delta) -> Dictionary
        |
        v
  _evaluate_rules_for_context(context)
        |
        v
  U_QBRuleEvaluator.check_conditions(rule, qualities)
        |  (true if ALL conditions pass AND salience transition for TICK mode)
        v
  U_QBEffectExecutor.execute_effects(rule.effects, context)
  + rule_manager._handle_effect(effect, context) for CALL_METHOD
        |
        v
  [Writes to Components] / [Dispatches Redux Actions] / [Publishes ECS Events]
```

---

## Domain-Specific Rule Managers

### S_CharacterRuleManager (Character State)

Handles per-entity character decision logic:
- Pause gating (is gameplay active?) -- TWO rules for OR logic
- Spawn freeze gating (is entity physics frozen?)
- Death sequence (health <= 0 -> mark dead -> ragdoll -> transition)
- Invincibility window (damage received -> invincibility timer)

Writes computed qualities to `C_CharacterStateComponent` (the "brain data") each tick. Existing physics systems (movement, jump, gravity, etc.) read from this component instead of duplicating gating checks.

**Spawn freeze approach**: Rule sets `C_CharacterStateComponent.is_spawn_frozen = true`. Each system keeps its own freeze side effects but reads the flag from the component instead of independently checking C_SpawnStateComponent.

**CALL_METHOD handlers**: `_handle_spawn_ragdoll(context)`, `_handle_mark_dead(context)` contain the complex logic currently in S_HealthSystem.

### S_GameRuleManager (Game State)

Handles world-level decision logic:
- Checkpoint activation (zone entered + is player -> activate + dispatch + publish)
- Victory trigger (event + prerequisites met -> dispatch actions)
- Victory game-complete (all areas completed -> game complete)

Replaces S_CheckpointSystem (~110 lines) and S_VictorySystem (~89 lines).

**No C_GameStateComponent needed**: Game rules are purely event-driven. No brain data aggregation component. This asymmetry with character/camera domains is intentional.

**S_DamageSystem stays as-is**: See "What Does NOT Become a Rule" for rationale.

**Typed event compatibility**: S_CheckpointSystem publishes typed events (`Evn_CheckpointActivated` via `U_ECSEventBus.publish_typed()`). Rule event triggers work with string-based event names. The typed event class_name becomes the event name string, so this is compatible -- but be aware that typed event payloads are accessed differently (as the event object itself, not a Dictionary payload). CALL_METHOD handlers must handle both payload shapes.

### S_CameraRuleManager (Camera State)

Handles camera behavior rules (additive, does not replace M_CameraManager):
- Shake-on-damage (damage event -> add trauma to C_CameraStateComponent)
- Zone-based FOV (in FOV zone -> blend to target fov)

M_CameraManager keeps all transition/blend code. Camera rules add new capabilities.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rule format | Resource `.tres` files | Consistent with RS_* pattern, editor-friendly, mobile-safe preload |
| Condition value type | Typed fields (value_float, value_int, value_string, value_bool, value_string_name) | Godot 4.x cannot export Variant; typed fields are inspector-friendly |
| OR conditions | Multiple rules with same effect | Two rules: "paused==true" and "shell!=gameplay" both set is_gameplay_active=false |
| Spawn freeze | Flag only; systems keep side effects | Rule sets is_spawn_frozen; each system still runs its own freeze behavior |
| CALL_METHOD | Subclass handler methods | Complex effects (ragdoll, checkpoint activate) are methods on the rule manager subclass |
| Delayed effects | Deferred to post-Phase 6 | Remove delay from Phase 1 RS_QBEffect to reduce speculative complexity |
| Event salience | Auto-disabled for EVENT mode | Events are instantaneous; salience only applies to TICK/BOTH modes |
| Execution priority | Explicit low number (1) | Most systems default to 0; rule managers at 1 run in priority-sorted order before them |
| Rule ordering | rule_id alphabetical (StringName comparison) | Deterministic, predictable within same priority |
| Physics math | Stays in existing systems | Too complex for condition-effect; rules handle gating only |
| Migration | Additive wrapping | Never breaks existing behavior |
| S_DamageSystem | Keep as-is (not rule-ified) | Stateful tick-based zone tracking with per-entity cooldowns doesn't fit condition-effect pattern; 177 lines, no duplicated logic |
| Event names | Centralize in U_ECSEventNames before rule consumption | Checkpoint/victory/damage events are currently local constants in component/system files |

---

## What Does NOT Become a Rule

- `S_MovementSystem._apply_second_order_dynamics()` -- physics math
- `S_JumpSystem` coyote time / buffer time / air jump counting -- frame-precise mechanics
- `S_GravitySystem` gravity application -- simple accumulator
- `S_FloatingSystem` raycast + spring-damper hover -- physics math
- `S_PlaytimeSystem` -- too simple (increment counter when unpaused)
- `S_SceneTriggerSystem` -- single Input.is_action_just_pressed check
- Interactable controllers -- they publish events, rules consume them
- Sound/particle publisher systems -- already event-driven, clean pattern (note: S_FootstepSoundSystem IS consolidated for pause gating since it duplicates the same check as the 5 physics/input systems)
- `S_DamageSystem` -- stateful per-tick zone tracking with enter/exit event-driven zone membership (`_zone_bodies` dictionary), per-zone per-entity cooldown management, stale zone cleanup, and two damage paths (instant death vs cooldown damage). This is not duplicated logic -- it's a self-contained 177-line system. A single EVENT rule on `damage_zone_entered` cannot replicate continuous tick-based damage while an entity remains in a zone. Keeping S_DamageSystem as-is is correct.
- Single-use logic that isn't duplicated across systems

---

## Anti-Patterns

- Do NOT rule-ify physics math (second-order dynamics, spring-damper, coyote time)
- Do NOT create rules for single-use logic that isn't duplicated
- Do NOT use `@export var value: Variant` (Godot 4.x can't export Variant)
- Do NOT assume spawn freeze checks are identical across systems (each has different side effects)
- Do NOT add pause gating to systems that don't currently have it (S_AlignWithSurfaceSystem, S_FloatingSystem for pause)
- Do NOT try to rule-ify S_DamageSystem (stateful zone tracking with per-tick cooldowns doesn't fit condition-effect pattern)
- Do NOT use salience for EVENT-triggered rules (events are instantaneous, not persistent)
- Do NOT use runtime DirAccess for rule loading (use const preload arrays for mobile compatibility)
- Do NOT use `delay` on effects in Phase 1 (deferred to post-Phase 6)

---

## Integration Points

### With Redux State (M_StateStore)

Rules can:
- Read Redux state via `RS_QBCondition.Source.REDUX` (e.g., `gameplay.is_dead`)
- Dispatch Redux actions via `RS_QBEffect.EffectType.DISPATCH_ACTION`
- The rule manager supports `@export var state_store: I_StateStore` for DI testing

### With ECS Event Bus (U_ECSEventBus)

Rules can:
- Trigger on ECS events via `RS_QBRuleDefinition.trigger_mode = EVENT`
- Read event payloads via `RS_QBCondition.Source.EVENT_PAYLOAD`
- Publish ECS events via `RS_QBEffect.EffectType.PUBLISH_EVENT`

### With ECS Components

Rules can:
- Read component fields via `RS_QBCondition.Source.COMPONENT`
- Write component fields via `RS_QBEffect.EffectType.SET_COMPONENT_FIELD`
- The rule manager queries components via the standard `get_components()` pattern

### With Existing Systems

Existing systems read from `C_CharacterStateComponent` for gating decisions instead of independently querying the store. The rule manager runs at `execution_priority = 1` (before default-0 systems) to ensure brain data is populated before systems read it. Systems that set explicit priorities (health=200, damage=250, etc.) already run later.
