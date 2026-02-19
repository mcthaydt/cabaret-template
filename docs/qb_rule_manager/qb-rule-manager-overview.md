# QB Rule Manager - Architecture Overview

## Problem Statement

6 ECS systems independently duplicate identical pause-gating code (S_MovementSystem, S_JumpSystem, S_GravitySystem, S_RotateToInputSystem, S_InputSystem, S_FootstepSoundSystem). 3 systems independently check spawn freeze with different side effects. Death/checkpoint/victory logic is hardcoded across scattered systems. This makes the template hostile to mods and AI-generated rules.

**Note on S_FootstepSoundSystem**: Uses a slightly different pause check pattern (`U_StateUtils.try_get_store()` with `Engine.is_editor_hint()` guard instead of `U_StateUtils.get_store()`), but the gating logic is functionally identical.

## Solution

The QB Rule Manager introduces a data-driven condition-effect engine with declarative `.tres` rules. The key design decision: **no CALL_METHOD** -- complex effects use `PUBLISH_EVENT` to dedicated handler systems, making the engine fully extensible for modders and AI without subclassing.

**Scope**: Decision/gating logic only. Physics math stays in existing systems. Migration is additive.

---

## Core Concepts

### Rules

A rule is a condition-effect pair: "when ALL conditions are met, execute effects."

```
Rule: "pause_gate_paused"
  Conditions:
    - REDUX gameplay.paused == true
  Effects:
    - SET_QUALITY: is_gameplay_active = false

Rule: "death_sync"
  Conditions:
    - COMPONENT C_HealthComponent.is_dead == true
  Effects:
    - SET_QUALITY: is_dead = true
```

### OR Logic

OR conditions are expressed as multiple rules with the same effect. Two rules:
- `cfg_pause_gate_paused.tres`: condition `gameplay.paused == true` -> SET_QUALITY is_gameplay_active = false
- `cfg_pause_gate_shell.tres`: condition `navigation.shell != "gameplay"` -> SET_QUALITY is_gameplay_active = false

### 4 Effect Types (No CALL_METHOD)

| Type | Description |
|------|-------------|
| `DISPATCH_ACTION` | Dispatch a Redux action to M_StateStore |
| `PUBLISH_EVENT` | Publish an ECS event via U_ECSEventBus (auto-injects context) |
| `SET_COMPONENT_FIELD` | Write a value to an ECS component field |
| `SET_QUALITY` | Write a value to the brain data component (C_CharacterStateComponent) |

Complex effects (ragdoll spawning, checkpoint activation, victory execution) use `PUBLISH_EVENT` to dedicated handler systems. This eliminates the need for CALL_METHOD and makes the engine fully extensible without subclassing.

### PUBLISH_EVENT Context Injection

PUBLISH_EVENT auto-injects context so `.tres` files don't need dynamic values:

```gdscript
static func _execute_publish_event(effect: RS_QBEffect, context: Dictionary) -> void:
    var event_payload: Dictionary = effect.payload.duplicate(true)
    # Auto-inject entity_id from context if not explicitly set in payload
    if context.has("entity_id") and not event_payload.has("entity_id"):
        event_payload["entity_id"] = context["entity_id"]
    # Forward original event payload for EVENT-triggered rules
    if context.has("event_payload"):
        var original: Dictionary = context["event_payload"]
        for key in original:
            if not event_payload.has(key):
                event_payload[key] = original[key]
    U_ECSEventBus.publish(StringName(effect.target), event_payload)
```

### Handler Systems

Handler systems subscribe to events published by rules for complex behavior:

- **S_DeathHandlerSystem**: Subscribes to `entity_death_requested` / `entity_respawn_requested` -- spawns/frees ragdoll, hides/restores entity
- **S_CheckpointHandlerSystem**: Subscribes to `checkpoint_activation_requested` -- activates checkpoint, dispatches state, resolves spawn position
- **S_VictoryHandlerSystem**: Subscribes to `victory_execution_requested` -- validates trigger, checks prerequisites, dispatches actions

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
- **Cooldown**: Minimum time between firings (global or per-context)
- **Per-context cooldown**: Cooldown tracked independently per composite key (e.g., per-zone-per-entity). Configured via `cooldown_key_fields` on the rule definition
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
  RS_QBEffect                  -- Effect action (4 types, no CALL_METHOD)
  RS_QBRuleDefinition          -- Complete rule resource

Engine (logic):
  BaseQBRuleManager            -- Abstract rule evaluation engine (extends BaseECSSystem, priority=1)
    S_CharacterRuleManager       -- Per-entity character rules + brain data
    S_GameRuleManager            -- World-level game rules (checkpoint, victory via events)
    S_CameraRuleManager          -- Camera behavior rules

Handler Systems (event subscribers):
  S_DeathHandlerSystem         -- Subscribes to entity_death_requested/entity_respawn_requested
  S_CheckpointHandlerSystem    -- Subscribes to checkpoint_activation_requested
  S_VictoryHandlerSystem       -- Subscribes to victory_execution_requested

Utilities:
  U_QBRuleEvaluator            -- Pure condition evaluation functions
  U_QBEffectExecutor           -- Pure effect execution functions (4 types)
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
        |
        v
  [SET_QUALITY -> brain data] / [DISPATCH_ACTION -> Redux] /
  [PUBLISH_EVENT -> handler systems] / [SET_COMPONENT_FIELD -> components]
```

---

## Domain-Specific Rule Managers

### S_CharacterRuleManager (Character State)

Handles per-entity character decision logic:
- Pause gating (is gameplay active?) -- TWO rules for OR logic
- Spawn freeze gating (is entity physics frozen?)
- Death sync (health <= 0 -> set is_dead flag in brain data)

Writes computed qualities to `C_CharacterStateComponent` (the "brain data") each tick. Existing physics systems (movement, jump, gravity, etc.) read from this component instead of duplicating gating checks.

**Spawn freeze approach**: Rule sets `C_CharacterStateComponent.is_spawn_frozen = true`. Each system keeps its own freeze side effects but reads the flag from the component instead of independently checking C_SpawnStateComponent.

**Death detection stays in S_HealthSystem**: Tightly coupled to damage/invincibility flow. Rule manager only syncs the `is_dead` flag to brain data. Ragdoll logic extracts to `S_DeathHandlerSystem`.

### S_GameRuleManager (Game State)

Simple event-rule host (no custom `process_tick` iteration). Holds checkpoint and victory rules. EVENT-triggered rules fire via `_on_event_received()`.

- Checkpoint rule: EVENT `checkpoint_zone_entered` -> PUBLISH_EVENT `checkpoint_activation_requested` (forwards payload)
- Victory rule: EVENT `victory_triggered` -> PUBLISH_EVENT `victory_execution_requested` (forwards payload)

**S_DamageSystem stays as-is**: Its stateful zone-body tracking + per-entity cooldown loop doesn't decompose cleanly into rules. Just centralize event names in U_ECSEventNames.

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
| Effect types | 4 types, no CALL_METHOD | PUBLISH_EVENT to handler systems is fully extensible for modders/AI without subclassing |
| Handler systems | Dedicated event subscribers | Complex effects (ragdoll, checkpoint, victory) live in focused handler systems |
| Condition value type | Typed fields (value_float, value_int, value_string, value_bool, value_string_name) | Godot 4.x cannot export Variant; typed fields are inspector-friendly |
| OR conditions | Multiple rules with same effect | Two rules: "paused==true" and "shell!=gameplay" both set is_gameplay_active=false |
| Spawn freeze | Flag only; systems keep side effects | Rule sets is_spawn_frozen; each system still runs its own freeze behavior |
| S_DamageSystem | Stays as-is, centralize event names only | Stateful zone-body tracking + per-entity cooldown loop doesn't decompose cleanly into rules |
| Death detection | Stays in S_HealthSystem | Tightly coupled to damage/invincibility flow; ragdoll extracts to S_DeathHandlerSystem |
| PUBLISH_EVENT context | Auto-inject entity_id and event_payload | `.tres` files don't need dynamic values; handler systems get full context |
| Delayed effects | Deferred to post-Phase 6 | Remove delay from Phase 1 RS_QBEffect to reduce speculative complexity |
| Event salience | Auto-disabled for EVENT mode | Events are instantaneous; salience only applies to TICK/BOTH modes |
| Execution priority | Explicit low number (1) | Most systems default to 0; rule managers at 1 run in priority-sorted order before them |
| Rule ordering | rule_id alphabetical (StringName comparison) | Deterministic, predictable within same priority |
| Physics math | Stays in existing systems | Too complex for condition-effect; rules handle gating only |
| Migration | Additive wrapping | Never breaks existing behavior |
| Per-context cooldowns | `cooldown_key_fields` + `cooldown_from_context_field` on RS_QBRuleDefinition | Future use (damage zones, custom mod rules); empty array = global cooldown (backwards compatible) |
| Event names | Centralize in U_ECSEventNames before rule consumption | Checkpoint/victory/damage events are currently local constants in component/system files |

---

## What Does NOT Become a Rule

- `S_MovementSystem._apply_second_order_dynamics()` -- physics math
- `S_JumpSystem` coyote time / buffer time / air jump counting -- frame-precise mechanics
- `S_GravitySystem` gravity application -- simple accumulator
- `S_FloatingSystem` raycast + spring-damper hover -- physics math
- `S_PlaytimeSystem` -- too simple (increment counter when unpaused)
- `S_SceneTriggerSystem` -- single Input.is_action_just_pressed check
- `S_DamageSystem` -- stateful zone-body tracking + per-entity cooldown loop; stays as-is
- Interactable controllers -- they publish events, rules consume them
- Sound/particle publisher systems -- already event-driven, clean pattern (note: S_FootstepSoundSystem IS consolidated for pause gating since it duplicates the same check as the 5 physics/input systems)
- Single-use logic that isn't duplicated across systems

---

## Anti-Patterns

- Do NOT rule-ify physics math (second-order dynamics, spring-damper, coyote time)
- Do NOT create rules for single-use logic that isn't duplicated
- Do NOT use `@export var value: Variant` (Godot 4.x can't export Variant)
- Do NOT assume spawn freeze checks are identical across systems (each has different side effects)
- Do NOT add pause gating to systems that don't currently have it (S_AlignWithSurfaceSystem, S_FloatingSystem for pause)
- Do NOT use CALL_METHOD -- use PUBLISH_EVENT to handler systems instead
- Do NOT use salience for EVENT-triggered rules (events are instantaneous, not persistent)
- Do NOT use runtime DirAccess for rule loading (use const preload arrays for mobile compatibility)
- Do NOT use `delay` on effects in Phase 1 (deferred to post-Phase 6)
- Do NOT try to decompose S_DamageSystem into rules (its stateful zone tracking doesn't fit)

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
- Publish ECS events via `RS_QBEffect.EffectType.PUBLISH_EVENT` (auto-injects context)

### With ECS Components

Rules can:
- Read component fields via `RS_QBCondition.Source.COMPONENT`
- Write component fields via `RS_QBEffect.EffectType.SET_COMPONENT_FIELD`
- The rule manager queries components via the standard `get_components()` pattern

### With Handler Systems

Handler systems subscribe to events published by rules:
- `S_DeathHandlerSystem` subscribes to `entity_death_requested` / `entity_respawn_requested`
- `S_CheckpointHandlerSystem` subscribes to `checkpoint_activation_requested`
- `S_VictoryHandlerSystem` subscribes to `victory_execution_requested`

### With Existing Systems

Existing systems read from `C_CharacterStateComponent` for gating decisions instead of independently querying the store. The rule manager runs at `execution_priority = 1` (before default-0 systems) to ensure brain data is populated before systems read it. Systems that set explicit priorities (health=200, damage=250, etc.) already run later.
