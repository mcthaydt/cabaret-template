# Redux State Store Usage Guide

**Version**: 1.0  
**Last Updated**: 2025-10-27  
**For**: SSA Rising State Store v3.0

This guide shows common patterns and examples for using the Redux-style state store in SSA Rising.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Common Patterns](#common-patterns)
4. [Adding New State](#adding-new-state)
5. [ECS System Integration](#ecs-system-integration)
6. [Testing State Code](#testing-state-code)
7. [Debugging & Tools](#debugging--tools)
8. [Hot Reload & Live Editing](#hot-reload--live-editing)
9. [Performance Tips](#performance-tips)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Accessing the Store

```gdscript
# In any node (system, manager, UI):
func _ready() -> void:
    # Wait for store to register in group
    await get_tree().process_frame
    
    var store: M_StateStore = U_StateUtils.get_store(self)
    if not store:
        push_error("Could not find M_StateStore")
        return
```

### Dispatching Actions

```gdscript
# Dispatch an action to update state
store.dispatch(U_GameplayActions.update_health(80))
store.dispatch(U_GameplayActions.add_score(100))
store.dispatch(U_MenuActions.navigate_to_screen("settings"))
```

### Reading State

```gdscript
# Get entire slice
var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
var health: int = gameplay_state.get("health", 100)

# Use selectors for derived state
var is_low_health: bool = GameplaySelectors.is_low_health(gameplay_state)
var is_game_over: bool = GameplaySelectors.is_game_over(gameplay_state)
```

### Subscribing to Changes

```gdscript
var _store: M_StateStore
var _subscription_id: int

func _ready() -> void:
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    
    # Subscribe to slice updates
    _subscription_id = _store.subscribe(_on_state_changed)

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
    print("State changed by: ", action.get("type"))
    
    # Read updated state
    var gameplay: Dictionary = new_state.get("gameplay", {})
    var health: int = gameplay.get("health", 0)
    _update_health_bar(health)

func _exit_tree() -> void:
    # Clean up subscription
    if _store and _subscription_id >= 0:
        _store.unsubscribe(_subscription_id)
```

---

## Core Concepts

### State Slices

State is organized into **slices** - independent domains of state:

- **boot**: Loading progress, initialization state
- **menu**: Active screen, character/difficulty selection
- **gameplay**: Health, score, level, pause state

Each slice has its own:
- Initial state resource (`RS_*InitialState`)
- Actions (`U_*Actions`)
- Reducer (`*Reducer`)
- Selectors (`*Selectors`)

### Actions

Actions are plain dictionaries describing state changes:

```gdscript
{
    "type": StringName("gameplay/update_health"),
    "payload": {"health": 80}
}
```

**Never create action dictionaries manually** - always use action creators:

```gdscript
# CORRECT
store.dispatch(U_GameplayActions.update_health(80))

# WRONG - fragile, no type checking
store.dispatch({"type": "gameplay/update_health", "payload": {"health": 80}})
```

### Reducers

Reducers are pure functions that compute new state:

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    
    match action.get("type"):
        U_GameplayActions.ACTION_UPDATE_HEALTH:
            next_state["health"] = action.get("payload", {}).get("health", 0)
        
        U_GameplayActions.ACTION_TAKE_DAMAGE:
            var amount: int = action.get("payload", {}).get("amount", 0)
            next_state["health"] = max(0, next_state.get("health", 0) - amount)
    
    return next_state
```

**Rules for reducers:**
1. Always duplicate state first: `state.duplicate(true)`
2. Never modify input state directly
3. Return new state object
4. Keep logic pure (no side effects, no I/O)

### Selectors

Selectors derive computed values from state:

```gdscript
class_name GameplaySelectors

# Simple field access
static func get_health(state: Dictionary) -> int:
    return state.get("health", 100)

# Derived/computed values
static func is_low_health(state: Dictionary) -> bool:
    return get_health(state) < 30

static func is_game_over(state: Dictionary) -> bool:
    return get_health(state) <= 0
```

---

## Common Patterns

### Pattern 1: UI Subscribing to State

```gdscript
# HUD displays health from state
extends Control

var _store: M_StateStore
var _sub_id: int
@onready var health_label: Label = $HealthLabel

func _ready() -> void:
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _sub_id = _store.subscribe(_on_state_changed)
    
    # Initialize UI with current state
    _update_ui(_store.get_state())

func _on_state_changed(_action: Dictionary, new_state: Dictionary) -> void:
    _update_ui(new_state)

func _update_ui(state: Dictionary) -> void:
    var gameplay: Dictionary = state.get("gameplay", {})
    var health: int = GameplaySelectors.get_health(gameplay)
    health_label.text = "Health: %d" % health

func _exit_tree() -> void:
    if _store:
        _store.unsubscribe(_sub_id)
```

### Pattern 2: ECS System Dispatching Actions

```gdscript
# System updates state based on entity changes
extends ECSSystem

var _store: M_StateStore

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)

func process_tick(_delta: float) -> void:
    # Get player entity
    var player: Node3D = _get_player()
    if not player:
        return
    
    # Read component
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if not health_comp:
        return
    
    # Sync component to state
    var current_state: Dictionary = _store.get_slice(StringName("gameplay"))
    var state_health: int = GameplaySelectors.get_health(current_state)
    
    if health_comp.current_health != state_health:
        _store.dispatch(U_GameplayActions.update_health(health_comp.current_health))
```

### Pattern 3: State-Driven System Behavior

```gdscript
# System reacts to state changes
extends ECSSystem

var _store: M_StateStore
var _is_paused: bool = false

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name == "gameplay":
        var was_paused: bool = _is_paused
        _is_paused = GameplaySelectors.get_is_paused(slice_state)
        
        if _is_paused != was_paused:
            _on_pause_changed(_is_paused)

func _on_pause_changed(paused: bool) -> void:
    if paused:
        print("Game paused - stop processing")
    else:
        print("Game unpaused - resume processing")

func process_tick(delta: float) -> void:
    if _is_paused:
        return  # Skip processing while paused
    
    # Normal system logic...
```

### Pattern 4: State Transitions

```gdscript
# Transitioning between game states
func _on_start_game_pressed() -> void:
    # Read menu configuration
    var menu_state: Dictionary = _store.get_slice(StringName("menu"))
    var config: Dictionary = {
        "character": menu_state.get("pending_character"),
        "difficulty": menu_state.get("pending_difficulty")
    }
    
    # Transition to gameplay with config
    _store.dispatch(U_TransitionActions.transition_to_gameplay(config))
    
    # Load gameplay scene
    get_tree().change_scene_to_file("res://scenes/gameplay/level_01.tscn")
```

---

## Adding New State

Follow this 5-step pattern to add new state fields:

### Step 1: Update Initial State Resource

```gdscript
# scripts/state/resources/rs_gameplay_initial_state.gd
class_name RS_GameplayInitialState
extends Resource

@export var health: int = 100
@export var score: int = 0
@export var level: int = 1
@export var combo: int = 0  # NEW FIELD
```

### Step 2: Add Action Creator

```gdscript
# scripts/state/u_gameplay_actions.gd
const ACTION_UPDATE_COMBO := StringName("gameplay/update_combo")

static func _static_init() -> void:
    # Register action
    ActionRegistry.register_action(ACTION_UPDATE_COMBO)
    # ... other registrations

static func update_combo(combo: int) -> Dictionary:
    return {
        "type": ACTION_UPDATE_COMBO,
        "payload": {"combo": combo}
    }
```

### Step 3: Update Reducer

```gdscript
# scripts/state/reducers/gameplay_reducer.gd
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var next_state: Dictionary = state.duplicate(true)
    
    match action.get("type"):
        U_GameplayActions.ACTION_UPDATE_COMBO:
            var combo: int = action.get("payload", {}).get("combo", 0)
            next_state["combo"] = combo
        # ... other cases
    
    return next_state
```

### Step 4: Add Selector (if needed)

```gdscript
# scripts/state/selectors/gameplay_selectors.gd
static func get_combo(state: Dictionary) -> int:
    return state.get("combo", 0)

static func is_combo_active(state: Dictionary) -> bool:
    return get_combo(state) > 0
```

### Step 5: Add Tests

```gdscript
# tests/unit/state/test_gameplay_slice_reducers.gd
func test_update_combo() -> void:
    # GIVEN initial state with combo = 0
    var initial: Dictionary = _create_initial_state()
    assert_eq(initial.get("combo"), 0)
    
    # WHEN update_combo action dispatched
    var action: Dictionary = U_GameplayActions.update_combo(5)
    var next: Dictionary = GameplayReducer.reduce(initial, action)
    
    # THEN combo should update
    assert_eq(next.get("combo"), 5)
    
    # AND original state unchanged (immutability)
    assert_eq(initial.get("combo"), 0)
```

---

## ECS System Integration

### Recommended Pattern: State as Source of Truth

Use state store as the **single source of truth**, with ECS components as implementation details:

```gdscript
# S_HealthSystem.gd - syncs components to state
extends ECSSystem

var _store: M_StateStore

func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    _store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name != "gameplay":
        return
    
    # Read state
    var health: int = GameplaySelectors.get_health(slice_state)
    
    # Sync to component
    var player: Node3D = _get_player()
    if not player:
        return
    
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if health_comp:
        health_comp.current_health = health

func process_tick(_delta: float) -> void:
    # System can still update state based on game logic
    var player: Node3D = _get_player()
    if not player:
        return
    
    var health_comp: C_HealthComponent = player.get_node_or_null("C_HealthComponent")
    if not health_comp:
        return
    
    # Detect health changes and dispatch
    var state: Dictionary = _store.get_slice(StringName("gameplay"))
    var state_health: int = GameplaySelectors.get_health(state)
    
    if health_comp.current_health != state_health:
        _store.dispatch(U_GameplayActions.update_health(health_comp.current_health))
```

---

## Testing State Code

### Reducer Tests

```gdscript
extends GutTest

func before_each() -> void:
    # Reset action registry between tests
    ActionRegistry._registered_actions.clear()
    U_GameplayActions._static_init()

func test_take_damage_reduces_health() -> void:
    # GIVEN state with 100 health
    var state: Dictionary = {"health": 100, "score": 0}
    
    # WHEN take_damage action for 20 damage
    var action: Dictionary = U_GameplayActions.take_damage(20)
    var next: Dictionary = GameplayReducer.reduce(state, action)
    
    # THEN health reduced by 20
    assert_eq(next.get("health"), 80)
    
    # AND original state unchanged
    assert_eq(state.get("health"), 100)

func test_health_cannot_go_negative() -> void:
    # GIVEN state with 10 health
    var state: Dictionary = {"health": 10}
    
    # WHEN take_damage for 50 (more than current)
    var action: Dictionary = U_GameplayActions.take_damage(50)
    var next: Dictionary = GameplayReducer.reduce(state, action)
    
    # THEN health clamped to 0
    assert_eq(next.get("health"), 0)
```

### Selector Tests

```gdscript
func test_is_low_health_threshold() -> void:
    # GIVEN state with 29 health
    var state: Dictionary = {"health": 29}
    
    # WHEN checking is_low_health
    var result: bool = GameplaySelectors.is_low_health(state)
    
    # THEN should return true (< 30)
    assert_true(result)

func test_is_not_low_health() -> void:
    # GIVEN state with 30 health
    var state: Dictionary = {"health": 30}
    
    # WHEN checking is_low_health
    var result: bool = GameplaySelectors.is_low_health(state)
    
    # THEN should return false (>= 30)
    assert_false(result)
```

### Integration Tests

```gdscript
func test_full_store_integration() -> void:
    # GIVEN a configured store
    var store: M_StateStore = autofree(M_StateStore.new())
    var settings := RS_StateStoreSettings.new()
    settings.enable_history = true
    store.settings = settings
    
    # Add gameplay slice
    var initial_state := RS_GameplayInitialState.new()
    initial_state.health = 100
    store.gameplay_initial_state = initial_state
    
    store._initialize()
    
    # WHEN dispatching actions
    store.dispatch(U_GameplayActions.take_damage(20))
    store.dispatch(U_GameplayActions.add_score(100))
    
    # THEN state updates correctly
    var state: Dictionary = store.get_slice(StringName("gameplay"))
    assert_eq(state.get("health"), 80)
    assert_eq(state.get("score"), 100)
    
    # AND history recorded
    assert_eq(store.get_action_count(), 2)
```

---

## Debugging & Tools

### Debug Overlay (F3)

Press **F3** to toggle the debug overlay showing:
- Current state for all slices
- Recent action history (last 10 actions)
- Timestamps and action types

### Manual State Inspection

```gdscript
# Get full state tree
var full_state: Dictionary = store.get_state()
print(JSON.stringify(full_state, "  "))

# Get specific slice
var gameplay: Dictionary = store.get_slice(StringName("gameplay"))
print("Health: ", gameplay.get("health"))
print("Score: ", gameplay.get("score"))
```

### Action History

```gdscript
# Get recent actions
var history: Array = store.get_action_history(10)
for action_entry in history:
    print("[%d] %s - %s" % [
        action_entry.get("timestamp"),
        action_entry.get("action", {}).get("type"),
        action_entry.get("action", {}).get("payload")
    ])
```

### Benchmarking Performance

```gdscript
# Measure dispatch overhead
var start_time: int = Time.get_ticks_usec()

for i in range(1000):
    store.dispatch(U_GameplayActions.add_score(1))

var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
var avg_per_dispatch: float = elapsed_ms / 1000.0
print("Avg dispatch time: %.3f ms" % avg_per_dispatch)
```

---

## Hot Reload & Live Editing

The state store supports Godot's hot reload feature with some caveats:

### What Persists During Hot Reload

- **Current state values**: All slice data persists
- **Action history**: Recent actions remain in memory
- **Subscriptions**: Signal connections persist

### What Requires Scene Restart

- **Reducer logic changes**: Modified reducer functions won't apply until scene restart
- **New actions**: Adding new action types requires ActionRegistry re-initialization
- **Slice structure changes**: Adding/removing slices requires full restart

### Initial State Resource Editing

Changes to `.tres` files apply on next scene load:

1. Edit `default_gameplay_initial_state.tres` in inspector
2. Save resource
3. Reload scene (F6) or restart game
4. New initial state takes effect

**Example**: Change default health from 100 to 150
- Edit resource → Save → Reload scene → New games start with 150 health

### Live Debugging Workflow

1. **Run game** (F5)
2. **Toggle debug overlay** (F3) to see state
3. **Dispatch actions** via game interactions
4. **Edit reducer logic** → Save
5. **Hot reload** (happens automatically)
6. **Restart scene** (F6) to see reducer changes

---

## Performance Tips

### Tip 1: Use Selectors for Derived State

```gdscript
# GOOD - selector caches logic
var is_low: bool = GameplaySelectors.is_low_health(state)

# AVOID - recalculating every time
var is_low: bool = state.get("health", 0) < 30
```

### Tip 2: Minimize State Duplication

```gdscript
# GOOD - store IDs, derive rest
{
    "selected_character_id": "warrior",
    "selected_difficulty": "hard"
}

# AVOID - storing redundant computed data
{
    "selected_character_id": "warrior",
    "selected_character_name": "Warrior",  # Can be derived
    "selected_character_health": 100,       # Can be derived
    "selected_difficulty": "hard"
}
```

### Tip 3: Batch Related Actions

```gdscript
# AVOID - multiple dispatches
store.dispatch(U_GameplayActions.update_health(health))
store.dispatch(U_GameplayActions.update_score(score))
store.dispatch(U_GameplayActions.set_level(level))

# BETTER - single compound action (if frequently used together)
const ACTION_UPDATE_PLAYER_STATS := StringName("gameplay/update_player_stats")

static func update_player_stats(health: int, score: int, level: int) -> Dictionary:
    return {
        "type": ACTION_UPDATE_PLAYER_STATS,
        "payload": {"health": health, "score": score, "level": level}
    }
```

### Tip 4: Subscribe to Specific Slices

```gdscript
# GOOD - react only to gameplay changes
_store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name != "gameplay":
        return  # Ignore boot/menu updates
    
    _update_ui(slice_state)

# AVOID - subscribing to all state changes
_store.state_updated.connect(_on_every_change)  # Fires for ALL slices
```

---

## Troubleshooting

### Problem: "Could not find M_StateStore"

**Cause**: Store not in scene tree or accessed before `_ready()`

**Solution**:
```gdscript
func _ready() -> void:
    await get_tree().process_frame  # Wait for store to register
    var store: M_StateStore = U_StateUtils.get_store(self)
```

### Problem: State Not Updating

**Causes**:
1. Action not registered in ActionRegistry
2. Reducer not handling action type
3. Reducer not registered with store

**Debug**:
```gdscript
# Check action registered
if not ActionRegistry.is_registered(U_GameplayActions.ACTION_UPDATE_HEALTH):
    print("Action not registered!")

# Enable verbose logging
store.settings.enable_logging = true
```

### Problem: "Unrecognized UID" Scene Errors

**Cause**: Manually-specified UIDs in `.tscn` files

**Solution**: Remove `uid="uid://xxx"` from scene headers, let Godot generate UIDs automatically

### Problem: Buttons Not Clickable in UI

**Cause**: Overlay container blocking input

**Solution**: Set `mouse_filter = 2` (MOUSE_FILTER_IGNORE) on full-screen containers that shouldn't intercept clicks

### Problem: Test Failures with "Unexpected Errors"

**Cause**: Missing `StateStoreEventBus.reset()` or `ActionRegistry` cleanup

**Solution**:
```gdscript
func before_each() -> void:
    StateStoreEventBus.reset()
    ActionRegistry._registered_actions.clear()
```

---

## Action Type Naming Conventions

Follow these conventions for consistent action naming:

### Format: `domain/verb_noun`

```gdscript
# Domain: gameplay, menu, boot, transition
# Verb: update, set, add, remove, toggle, navigate, etc.
# Noun: health, score, screen, character, etc.

const ACTION_UPDATE_HEALTH := StringName("gameplay/update_health")
const ACTION_ADD_SCORE := StringName("gameplay/add_score")
const ACTION_NAVIGATE_TO_SCREEN := StringName("menu/navigate_to_screen")
const ACTION_TRANSITION_TO_GAMEPLAY := StringName("transition/to_gameplay")
```

### Examples by Pattern

**Update (set to new value)**:
- `gameplay/update_health`
- `gameplay/update_score`
- `menu/update_difficulty`

**Add/Remove (modify by delta)**:
- `gameplay/add_score`
- `gameplay/take_damage`
- `menu/add_save_file`

**Set (explicit assignment)**:
- `gameplay/set_level`
- `menu/set_character`

**Toggle (boolean flip)**:
- `gameplay/pause`
- `gameplay/unpause`

**Navigate (screen/state transitions)**:
- `menu/navigate_to_screen`
- `transition/to_gameplay`

**Complex (multi-field)**:
- `gameplay/player_died`
- `gameplay/level_complete`

---

## Next Steps

- Review [PRD](./redux-state-store-prd.md) for architecture details
- Check [tasks.md](./redux-state-store-tasks.md) for implementation status
- See [DEV_PITFALLS.md](../general/DEV_PITFALLS.md) for common mistakes
- Run tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`

---

**Questions?** Check the PRD or inspect working examples in `scenes/debug/state_test_*.gd`
