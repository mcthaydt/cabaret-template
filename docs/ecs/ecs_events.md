# ECS Event Bus Reference

**Last Updated**: 2025-12-16 (Phase 10B-6)

## Overview

The ECS event bus (`U_ECSEventBus`) provides a publish/subscribe infrastructure for decoupled communication between ECS components, systems, and managers. As of Phase 10B-6, the event bus supports **typed events** with **priority-based subscriber ordering** and **duplicate subscription detection**.

## Table of Contents

1. [Event Architecture](#event-architecture)
2. [Standard Events](#standard-events)
3. [Typed Event Classes](#typed-event-classes)
4. [Priority System](#priority-system)
5. [Subscription Patterns](#subscription-patterns)
6. [Best Practices](#best-practices)
7. [Migration Guide](#migration-guide)

---

## Event Architecture

### Event Bus Infrastructure

- **Location**: `scripts/events/ecs/u_ecs_event_bus.gd`
- **Base**: `scripts/events/base_event_bus.gd`
- **Event Classes**: `scripts/events/ecs/evn_*.gd`

### Event Flow

```
Publisher (Component/System)
    ↓
Creates Typed Event (Evn_HealthChanged, etc.)
    ↓
Calls U_ECSEventBus.publish_typed(event)
    ↓
Event Bus converts class name to event name
    ↓
Subscribers called in priority order (highest first)
    ↓
Event stored in rolling history buffer (1000 events)
```

### Features (Phase 10B-6)

- **Typed Events**: Type-safe event classes with structured payloads
- **Priority Support**: Control subscriber execution order (0-∞, higher = first)
- **Source Tracking**: Debug which file/class subscribed to events
- **Duplicate Detection**: Warns when same callable subscribes twice
- **History Buffer**: Rolling 1000-event history for debugging
- **Automatic Unsubscribe**: Subscribe returns cleanup callable

---

## Standard Events

### Event Catalog

| Event Name | Typed Class | Publisher | Subscribers | Priority |
|------------|-------------|-----------|-------------|----------|
| `health_changed` | `Evn_HealthChanged` | `C_HealthComponent` | _(none - state-driven)_ | - |
| `entity_death` | `Evn_EntityDeath` | `C_HealthComponent` | `M_SceneManager` (10)<br>`S_GamepadVibrationSystem` (0) | High for scene manager |
| `victory_triggered` | `Evn_VictoryTriggered` | `C_VictoryTriggerComponent` | `S_VictorySystem` (10)<br>`M_SceneManager` (5) | Process state before transition |
| `checkpoint_activated` | `Evn_CheckpointActivated` | `S_CheckpointSystem` | `UI_HudController` (0) | - |
| `victory_zone_entered` | _(StringName)_ | `C_VictoryTriggerComponent` | _(internal)_ | - |
| `checkpoint_zone_entered` | _(StringName)_ | `C_CheckpointComponent` | `S_CheckpointSystem` (0) | - |
| `damage_zone_entered` | _(StringName)_ | `C_DamageZoneComponent` | `S_DamageSystem` (0) | - |
| `damage_zone_exited` | _(StringName)_ | `C_DamageZoneComponent` | `S_DamageSystem` (0) | - |
| `entity_jumped` | _(StringName)_ | `S_JumpSystem` | VFX/Audio systems | - |
| `entity_landed` | _(StringName)_ | `S_JumpSystem` | `S_GamepadVibrationSystem` | - |
| `component_registered` | _(StringName)_ | `BaseECSComponent` | _(system queries)_ | - |
| `entity_registered` | _(StringName)_ | `M_ECSManager` | _(systems)_ | - |
| `entity_unregistered` | _(StringName)_ | `M_ECSManager` | _(systems)_ | - |

**Note**: Not all events have been migrated to typed classes yet. StringName events continue to work alongside typed events.

---

## Typed Event Classes

### Base Class: BaseECSEvent

**Location**: `scripts/events/ecs/base_ecs_event.gd`

All typed events extend `BaseECSEvent`:

```gdscript
extends RefCounted
class_name BaseECSEvent

var timestamp: float = 0.0
var _payload: Dictionary = {}

func get_payload() -> Dictionary:
    return _payload.duplicate(true)
```

### Evn_HealthChanged

**File**: `scripts/events/ecs/evn_health_changed.gd`
**Publisher**: `C_HealthComponent`
**Published When**: Health changes (damage/heal)

**Properties**:
```gdscript
var entity_id: StringName
var previous_health: float
var new_health: float
var is_dead: bool
```

**Usage**:
```gdscript
var event := Evn_HealthChanged.new(
    entity_id,
    previous_health,
    new_health,
    is_dead
)
U_ECSEventBus.publish_typed(event)
```

### Evn_EntityDeath

**File**: `scripts/events/ecs/evn_entity_death.gd`
**Publisher**: `C_HealthComponent`
**Published When**: Entity health reaches 0

**Properties**:
```gdscript
var entity_id: StringName
var previous_health: float
var new_health: float  # Always 0
var is_dead: bool      # Always true
```

**Subscribers**:
- `M_SceneManager._on_entity_death()` - Priority 10 (transitions to game_over)
- `S_GamepadVibrationSystem._on_entity_death()` - Priority 0 (haptic feedback)

### Evn_VictoryTriggered

**File**: `scripts/events/ecs/evn_victory_triggered.gd`
**Publisher**: `C_VictoryTriggerComponent`
**Published When**: Player enters victory zone

**Properties**:
```gdscript
var entity_id: StringName
var trigger_node: Node
var body: Node3D
```

**Subscribers**:
- `S_VictorySystem._on_victory_triggered()` - Priority 10 (updates state/objectives)
- `M_SceneManager._on_victory_triggered()` - Priority 5 (scene transition after state update)

### Evn_CheckpointActivated

**File**: `scripts/events/ecs/evn_checkpoint_activated.gd`
**Publisher**: `S_CheckpointSystem`
**Published When**: Player activates checkpoint

**Properties**:
```gdscript
var checkpoint_id: StringName
var spawn_point_id: StringName
```

**Subscribers**:
- `UI_HudController._on_checkpoint_event()` - Priority 0 (shows toast notification)

---

## Priority System

### How Priority Works

- **Higher priority = called first** (10 before 5 before 0)
- **Default priority**: 0 (if not specified)
- **Range**: 0 to ∞ (typically 0-10)
- **Sorting**: Automatic on subscribe, stable sort preserves insertion order for ties

### Priority Assignment Guidelines

| Priority | Use Case | Example |
|----------|----------|---------|
| **10** | Critical state updates before transitions | `S_VictorySystem` processes objectives before scene change |
| **5-9** | Important processing order | `M_SceneManager` transitions after state systems |
| **0** | Default, no special ordering | Haptic feedback, UI updates, VFX |

### Priority Example

```gdscript
# High priority - process state BEFORE scene transition
U_ECSEventBus.subscribe(
    StringName("victory_triggered"),
    _on_victory_triggered,
    10  # High priority
)

# Medium priority - transition AFTER state processed
U_ECSEventBus.subscribe(
    StringName("victory_triggered"),
    _on_victory_triggered,
    5   # Medium priority
)

# Default priority - haptic feedback doesn't need ordering
U_ECSEventBus.subscribe(
    StringName("entity_death"),
    _on_entity_death,
    0   # Default priority (can omit parameter)
)
```

**Execution Order**: Subscribers called in order: Priority 10 → Priority 5 → Priority 0

---

## Subscription Patterns

### Basic Subscription (StringName Events)

```gdscript
var _unsubscribe: Callable

func _ready() -> void:
    _unsubscribe = U_ECSEventBus.subscribe(
        StringName("entity_death"),
        _on_entity_death,
        10  # Optional priority
    )

func _on_entity_death(event: Dictionary) -> void:
    var payload: Dictionary = event.get("payload", {})
    var entity_id: StringName = payload.get("entity_id")
    # Handle death...

func _exit_tree() -> void:
    if _unsubscribe != null and _unsubscribe.is_valid():
        _unsubscribe.call()
```

### Typed Event Subscription

Subscribers receive the same `Dictionary` format regardless of whether the event was published as typed or StringName:

```gdscript
func _on_entity_death(event: Dictionary) -> void:
    var payload: Dictionary = event.get("payload", {})
    # Payload contains: entity_id, previous_health, new_health, is_dead
    var entity_id: StringName = payload.get("entity_id")
    var is_dead: bool = payload.get("is_dead", false)
```

### Publishing Typed Events

```gdscript
# Create typed event
var death_event := Evn_EntityDeath.new(
    _get_entity_id(),
    previous_health,
    0.0,    # new_health
    true    # is_dead
)

# Publish (automatically converts to "entity_death" event name)
U_ECSEventBus.publish_typed(death_event)
```

### Array of Unsubscribes Pattern

For multiple subscriptions:

```gdscript
var _event_unsubscribes: Array[Callable] = []

func on_configured() -> void:
    _event_unsubscribes.append(
        U_ECSEventBus.subscribe(EVENT_ENTITY_LANDED, _on_entity_landed)
    )
    _event_unsubscribes.append(
        U_ECSEventBus.subscribe(EVENT_ENTITY_DEATH, _on_entity_death, 10)
    )

func _exit_tree() -> void:
    for unsubscribe in _event_unsubscribes:
        if unsubscribe != null and unsubscribe.is_valid():
            unsubscribe.call()
    _event_unsubscribes.clear()
```

---

## Best Practices

### When to Use Typed Events

✅ **Use typed events for**:
- Core gameplay events (death, victory, checkpoints)
- Events with complex payloads
- Events used across multiple systems
- Events that need type safety

❌ **StringName events are fine for**:
- Internal component events (zone_entered)
- Temporary/prototype events
- Events with simple payloads
- Legacy events not yet migrated

### Priority Guidelines

- **Don't overuse high priorities** - Most events should use default (0)
- **Use priorities for ordering dependencies** - E.g., "process state before transition"
- **Document why you need priority** - Add comment explaining the ordering requirement
- **Test priority ordering** - Verify critical flows work correctly

### Subscription Management

✅ **Do**:
- Always unsubscribe in `_exit_tree()`
- Store unsubscribe callable immediately
- Use array pattern for multiple subscriptions
- Subscribe in `_ready()` or `on_configured()`

❌ **Don't**:
- Subscribe without storing unsubscribe callable (causes leaks)
- Subscribe in `_process()` or frame-based callbacks
- Forget to check `is_valid()` before calling unsubscribe
- Modify event payloads without `duplicate(true)`

### Payload Design

- **Keep payloads small** - Only essential data
- **Use consistent keys** - `entity_id` not `entityId` or `id`
- **Document payload structure** - In event class or publisher
- **Deep copy when mutating** - `payload.duplicate(true)`

### Duplicate Subscription Detection

The event bus warns about duplicate subscriptions:

```
BaseEventBus: Duplicate subscription to 'entity_death' from s_health_system.gd
```

**When you see this**:
1. Check if you're subscribing twice in the same script
2. Verify you're not calling subscribe in a loop
3. Ensure you're unsubscribing properly in `_exit_tree()`

---

## Migration Guide

### Migrating from Direct Calls to Events

**Before** (direct coupling):
```gdscript
# In S_HealthSystem
func _process_death(entity: Node) -> void:
    var scene_manager := get_manager_node()
    scene_manager.trigger_game_over()  # Direct call
```

**After** (event-driven):
```gdscript
# In C_HealthComponent
func mark_dead() -> void:
    var death_event := Evn_EntityDeath.new(
        _get_entity_id(),
        current_health,
        0.0,
        true
    )
    U_ECSEventBus.publish_typed(death_event)

# In M_SceneManager
func _ready() -> void:
    _entity_death_unsubscribe = U_ECSEventBus.subscribe(
        StringName("entity_death"),
        _on_entity_death,
        10  # High priority for quick response
    )

func _on_entity_death(event: Dictionary) -> void:
    transition_to_scene(StringName("game_over"), "fade", Priority.CRITICAL)
```

### Migrating StringName Events to Typed Events

**Step 1**: Create typed event class:

```gdscript
# scripts/events/ecs/evn_my_event.gd
extends BaseECSEvent
class_name Evn_MyEvent

var my_data: String

func _init(p_my_data: String) -> void:
    my_data = p_my_data

    const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
    timestamp = U_ECS_UTILS.get_current_time()

    _payload = {
        "my_data": my_data
    }
```

**Step 2**: Update publisher:

```gdscript
# Before
U_ECSEventBus.publish(StringName("my_event"), {
    "my_data": my_data
})

# After
var my_event := Evn_MyEvent.new(my_data)
U_ECSEventBus.publish_typed(my_event)
```

**Step 3**: Subscribers don't need changes (payloads are identical)

**Step 4**: Update tests to use typed events

---

## Event History & Debugging

### Accessing Event History

```gdscript
# Get all events in history
var history: Array = U_ECSEventBus.get_event_history()

# Filter for specific event
var deaths := history.filter(func(e): return e.get("name") == StringName("entity_death"))

# Check if event was published
var was_published := deaths.size() > 0
```

### History Configuration

```gdscript
# Set history buffer size (default: 1000)
U_ECSEventBus.set_history_limit(5000)

# Clear history
U_ECSEventBus.clear_history()

# Reset bus entirely (clear subscribers + history)
U_ECSEventBus.reset()  # Use in test cleanup
```

### Debugging Subscription Issues

If events aren't being received:

1. **Check subscription timing** - Subscribe in `_ready()` or `on_configured()`
2. **Verify event name** - Use constants or StringName correctly
3. **Check history** - Was event published at all?
4. **Check unsubscribe** - Did you unsubscribe too early?
5. **Check callable validity** - Is the callback object still alive?

---

## API Reference

### U_ECSEventBus

```gdscript
# Subscribe to event (returns unsubscribe callable)
static func subscribe(
    event_name: StringName,
    callback: Callable,
    priority: int = 0
) -> Callable

# Publish StringName event
static func publish(
    event_name: StringName,
    payload: Variant = null
) -> void

# Publish typed event (converts class name automatically)
static func publish_typed(event: BaseECSEvent) -> void

# Unsubscribe from event
static func unsubscribe(
    event_name: StringName,
    callback: Callable
) -> void

# Clear all subscribers (or specific event)
static func clear(event_name: StringName = StringName()) -> void

# Get event history
static func get_event_history() -> Array

# Clear event history
static func clear_history() -> void

# Set history buffer size
static func set_history_limit(limit: int) -> void

# Reset bus (subscribers + history)
static func reset() -> void
```

### BaseECSEvent

```gdscript
# Properties
var timestamp: float        # Auto-set to current time
var _payload: Dictionary    # Serialized payload

# Get deep copy of payload
func get_payload() -> Dictionary
```

---

## Related Documentation

- [ECS Architecture](./ecs_architecture.md) - Full ECS system overview
- [STYLE_GUIDE.md](../general/STYLE_GUIDE.md) - Event naming conventions
- [Phase 10B Implementation Plan](../general/cleanup/phase-10b-implementation-plan.md) - Event bus migration context
