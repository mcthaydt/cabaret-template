# QB Rule Manager - Architecture Overview

## Problem Statement

The codebase has 27+ ECS systems with decision/gating logic (pause checks, spawn freeze, death sequencing, victory prerequisites) scattered and duplicated across them. Each system independently queries the Redux store for pause state, checks spawn freeze flags, and implements its own if/then branching. This creates maintenance burden and makes it hard to add new cause-effect behaviors without touching multiple files.

## Solution

The QB Rule Manager introduces a data-driven condition-effect rule engine that centralizes decision logic into declarative rules (Resource `.tres` files), while leaving the existing physics math (second-order dynamics, spring-damped hover, coyote time, slope limits) in the systems where it belongs.

**Scope**: Decision/gating logic only. Physics math stays in existing systems. Migration is additive -- nothing breaks.

---

## Core Concepts

### Rules

A rule is a condition-effect pair: "when X conditions are ALL met, execute Y effects."

```
Rule: "death_sequence"
  Conditions:
    - C_HealthComponent.current_health <= 0
    - C_CharacterStateComponent.is_dead == false
  Effects:
    - SET_COMPONENT_FIELD: C_CharacterStateComponent.is_dead = true
    - DISPATCH_ACTION: gameplay/trigger_death
    - PUBLISH_EVENT: entity_death
```

### Conditions (RS_QBCondition)

A condition evaluates a single quality against a comparison value using an operator.

**Sources**: Component fields, Redux state slices, event payloads, entity tags, custom qualities.

**Operators**: EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GTE, LTE, HAS, NOT_HAS, IS_TRUE, IS_FALSE.

### Effects (RS_QBEffect)

An effect is an action triggered when all conditions pass.

**Types**: DISPATCH_ACTION (Redux), PUBLISH_EVENT (ECS event bus), SET_COMPONENT_FIELD, CALL_METHOD, SET_QUALITY.

### Qualities

Observable properties of entities and the world. Read by the Quality Provider from:
- ECS components (e.g., `C_HealthComponent.current_health`)
- Redux state (e.g., `gameplay.player_health`)
- Entity tags (e.g., has tag "player")
- Event payloads (for event-triggered rules)

### Salience

Rules are salient -- they only fire when their conditions transition from false to true, not continuously. This prevents a "health <= 0" rule from firing every tick while the entity is dead.

### Lifecycle

Rules have lifecycle properties: priority (evaluation order), cooldown (minimum time between firings), one-shot (fire once then deactivate), and active/inactive state.

### Trigger Modes

- **TICK**: Evaluated every physics frame
- **EVENT**: Evaluated when a specific ECS event is published
- **BOTH**: Evaluated on both tick and event

---

## Class Hierarchy

```
Resources (data):
  RS_QBCondition               -- Single condition predicate
  RS_QBEffect                  -- Single effect action
  RS_QBRuleDefinition          -- Complete rule (conditions + effects + lifecycle)

Engine (logic):
  BaseQBRuleManager            -- Abstract rule evaluation engine (extends BaseECSSystem)
    S_CharacterRuleManager       -- Character-domain rules (per-entity)
    S_GameRuleManager            -- Game/world-level rules
    S_CameraRuleManager          -- Camera behavior rules

Utilities:
  U_QBRuleEvaluator            -- Pure condition evaluation functions
  U_QBEffectExecutor           -- Pure effect execution functions
  U_QBQualityProvider          -- Reads qualities from ECS components + Redux state
  U_QBRuleValidator            -- Authoring-time validation

Components:
  C_CharacterStateComponent    -- Aggregated character qualities ("brain data")
  C_CameraStateComponent       -- Camera qualities (fov, trauma, blend targets)
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
  BaseQBRuleManager._evaluate_rules()
        |
        v
  U_QBRuleEvaluator.check_conditions(rule, qualities)
        |  (true if ALL conditions pass AND salience transition detected)
        v
  U_QBEffectExecutor.execute_effects(rule.effects, context)
        |
        v
  [Writes to Components] / [Dispatches Redux Actions] / [Publishes ECS Events]
```

---

## Domain-Specific Rule Managers

### S_CharacterRuleManager (Character State)

Handles per-entity character decision logic:
- Pause gating (is gameplay active?)
- Spawn freeze gating (is entity physics frozen?)
- Death sequence (health <= 0 -> mark dead -> ragdoll -> transition)
- Invincibility window (damage received -> invincibility timer)

Writes computed qualities to `C_CharacterStateComponent` (the "brain data") each tick. Existing physics systems (movement, jump, gravity, floating) read from this component instead of duplicating gating checks.

### S_GameRuleManager (Game State)

Handles world-level decision logic:
- Checkpoint activation (zone entered + is player -> activate + dispatch + publish)
- Victory trigger (event + prerequisites met -> dispatch actions)
- Victory game-complete (all areas completed -> game complete)

Replaces the small S_CheckpointSystem (~110 lines) and S_VictorySystem (~89 lines).

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
| Rule manager type | BaseECSSystem | Gets process_tick, DI, auto-registration for free |
| Physics math | Stays in existing systems | Too complex for condition-effect; rules handle gating only |
| Brain data | Aggregated C_CharacterStateComponent | Single source of truth, written once per tick |
| Migration | Additive wrapping | Never breaks existing behavior |
| Salience | Built into base manager | Only fires on false-true transition |
| Camera rules | Additive to M_CameraManager | Manager keeps transitions, rules add behaviors |

---

## What Does NOT Become a Rule

- `S_MovementSystem._apply_second_order_dynamics()` -- physics math
- `S_JumpSystem` coyote time / buffer time / air jump counting -- frame-precise mechanics
- `S_GravitySystem` gravity application -- simple accumulator
- `S_FloatingSystem` raycast + spring-damper hover -- physics math
- `S_PlaytimeSystem` -- too simple (increment counter when unpaused)
- `S_SceneTriggerSystem` -- single Input.is_action_just_pressed check
- Interactable controllers -- they publish events, rules consume them
- Sound/particle publisher systems -- already event-driven, clean pattern

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

Existing systems read from `C_CharacterStateComponent` for gating decisions instead of independently querying the store. The rule manager runs at a low execution_priority (before other systems) to ensure brain data is populated before systems read it.
