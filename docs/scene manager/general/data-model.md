# Scene Manager Data Model

**Date**: 2025-10-28
**Phase**: Phase 0 - Architecture Validation
**Status**: In Progress

## Purpose

This document defines the data structures, interfaces, and integration patterns for the Scene Manager system.

---

## R006: Scene State Slice Schema

### State Slice Structure

```gdscript
{
    "scene": {
        # Persistent fields (saved to disk)
        "current_scene_id": String,      # Active scene identifier (e.g., "gameplay_base", "main_menu")
        "scene_stack": Array[String],    # Overlay stack (e.g., ["pause_menu", "settings_menu"])

        # Transient fields (excluded from save_state())
        "is_transitioning": bool         # True during active transition
    }
}
```

### Field Descriptions

**current_scene_id** (String, persistent):
- Identifier matching U_SceneRegistry scene_id
- Represents the currently active base scene (not overlays)
- Example values: "main_menu", "gameplay_base", "exterior", "interior_house"
- Updated only on `transition_complete` action

**scene_stack** (Array[String], persistent):
- Stack of overlay scene identifiers (UI overlays only)
- Top of stack = most recent overlay
- Used for pause/settings menu stacking
- Example: `["pause_menu"]` when paused, `["pause_menu", "settings_menu"]` when settings opened from pause
- **Important**: This is metadata for save/debug; actual source of truth is UIOverlayStack in scene tree

**is_transitioning** (bool, transient):
- `true` when transition in progress (between dispatch and completion)
- `false` when no transition active
- Prevents duplicate transitions
- **Marked transient**: Excluded from `M_StateStore.save_state()` serialization

### Initial State Resource

**RS_SceneInitialState** (Resource):
```gdscript
extends Resource
class_name RS_SceneInitialState

@export var current_scene_id: String = ""
@export var scene_stack: Array[String] = []
@export var is_transitioning: bool = false

func to_dictionary() -> Dictionary:
    return {
        "current_scene_id": current_scene_id,
        "scene_stack": scene_stack.duplicate(),
        "is_transitioning": is_transitioning
    }
```

### RS_StateSliceConfig Registration

```gdscript
# In M_StateStore._initialize_slices()
if scene_initial_state != null:
    var scene_config := RS_StateSliceConfig.new(StringName("scene"))
    scene_config.reducer = Callable(SceneReducer, "reduce")
    scene_config.initial_state = scene_initial_state.to_dictionary()
    scene_config.dependencies = []
    scene_config.transient_fields = [StringName("is_transitioning")]  # Exclude from save
    register_slice(scene_config)
```

---

## R007: U_SceneRegistry Structure with Door Pairings

### Scene Metadata Structure

```gdscript
# Static dictionary in U_SceneRegistry
static var _scenes: Dictionary = {
    "scene_id": {
        "path": String,                   # res:// path to .tscn file
        "type": SceneType,                # MENU, GAMEPLAY, UI, ENDGAME
        "default_transition": String,     # "instant", "fade", "loading_screen"
        "preload_priority": int           # 0-10, higher = preload at startup
    }
}
```

### SceneType Enum

```gdscript
enum SceneType {
    MENU,       # Main menu, intro screens
    GAMEPLAY,   # Playable game areas (exterior, interior, dungeon)
    UI,         # Overlays, settings, pause menus
    ENDGAME     # Game over, victory, credits
}
```

### Door Pairing Structure

```gdscript
# Static dictionary in U_SceneRegistry
static var _door_pairings: Dictionary = {
    "door_id": {
        "target_scene": String,         # Scene ID to load
        "spawn_point": String,          # Node name of spawn point in target scene
        "reverse_door": String          # door_id of reverse pairing (for bidirectional)
    }
}
```

### Example Scene Definitions

```gdscript
static var _scenes: Dictionary = {
    "main_menu": {
        "path": "res://scenes/ui/main_menu.tscn",
        "type": SceneType.MENU,
        "default_transition": "instant",
        "preload_priority": 10
    },
    "gameplay_base": {
        "path": "res://scenes/gameplay/gameplay_base.tscn",
        "type": SceneType.GAMEPLAY,
        "default_transition": "fade",
        "preload_priority": 0
    },
    "exterior": {
        "path": "res://scenes/gameplay/exterior_template.tscn",
        "type": SceneType.GAMEPLAY,
        "default_transition": "fade",
        "preload_priority": 0
    },
    "interior_house": {
        "path": "res://scenes/gameplay/interior_template.tscn",
        "type": SceneType.GAMEPLAY,
        "default_transition": "fade",
        "preload_priority": 0
    }
}
```

### Example Door Pairings

```gdscript
static var _door_pairings: Dictionary = {
    # Exterior house door → Interior entrance
    "exterior_house_door": {
        "target_scene": "interior_house",
        "spawn_point": "entrance_main",
        "reverse_door": "interior_exit_main"
    },
    # Interior exit → Exterior spawn point
    "interior_exit_main": {
        "target_scene": "exterior",
        "spawn_point": "house_exterior_spawn",
        "reverse_door": "exterior_house_door"
    }
}
```

### Validation Method

```gdscript
static func validate_door_pairings() -> bool:
    var all_valid := true

    for door_id in _door_pairings:
        var pairing: Dictionary = _door_pairings[door_id]
        var reverse_door: String = pairing.get("reverse_door", "")

        # Check reverse door exists
        if not _door_pairings.has(reverse_door):
            push_error("U_SceneRegistry: door '", door_id, "' reverse_door '", reverse_door, "' not found")
            all_valid = false
            continue

        # Check bidirectional consistency
        var reverse_pairing: Dictionary = _door_pairings[reverse_door]
        if reverse_pairing.get("reverse_door") != door_id:
            push_error("U_SceneRegistry: door '", door_id, "' reverse pairing mismatch")
            all_valid = false

        # Check target scene exists
        var target_scene: String = pairing.get("target_scene", "")
        if not _scenes.has(target_scene):
            push_error("U_SceneRegistry: door '", door_id, "' target_scene '", target_scene, "' not found")
            all_valid = false

    return all_valid
```

---

## R008: BaseTransitionEffect Interface

### Base Class Interface

```gdscript
extends RefCounted
class_name BaseTransitionEffect

## Signals
signal transition_started
signal transition_completed

## Properties
var _overlay_node: CanvasLayer = null
var _is_active: bool = false

## Methods

# Initialize with overlay node from main.tscn
func initialize(overlay_node: CanvasLayer) -> void

# Start the transition effect (fade out, show loading screen, etc.)
func start_transition() -> void

# Update transition progress during async loading (0.0 to 1.0)
func update_progress(progress: float) -> void

# Complete the transition effect (fade in, hide loading screen, etc.)
func complete_transition() -> void

# Check if transition is currently active
func is_active() -> bool

# Get expected duration in seconds
func get_duration() -> float
```

### Transition Types

**Trans_Instant**:
- No visual effect
- Immediate scene swap
- `get_duration()` returns 0.0
- Use for: UI menu → UI menu transitions

**Trans_Fade**:
- Fade to black/color then fade back
- Uses Tween on ColorRect.modulate.a
- `get_duration()` returns `fade_duration * 2.0`
- Configurable: `fade_duration`, `fade_color`
- Use for: Menu → gameplay, area transitions

**Trans_LoadingScreen**:
- Display loading screen with progress bar
- `update_progress()` updates ProgressBar.value
- `get_duration()` returns variable (depends on load time)
- Use for: Large gameplay area loads (> 3s)

### Usage Pattern

```gdscript
# In M_SceneManager.transition_to_scene()
var transition: BaseTransitionEffect = _get_transition_effect(transition_type)
transition.initialize(_transition_overlay)

# Start transition effect
await transition.start_transition()

# Perform scene load (async if loading screen)
if transition_type == "loading_screen":
    # Async load with progress updates
    while loading:
        transition.update_progress(progress)
        await get_tree().process_frame
else:
    # Sync load
    var scene = ResourceLoader.load(path)

# Complete transition effect
await transition.complete_transition()
```

---

## R009: Action/Reducer Signatures

### Action Creators (U_SceneActions)

```gdscript
# Action type constants
const ACTION_TRANSITION_TO := StringName("scene/transition_to")
const ACTION_TRANSITION_COMPLETE := StringName("scene/transition_complete")
const ACTION_PUSH_OVERLAY := StringName("scene/push_overlay")
const ACTION_POP_OVERLAY := StringName("scene/pop_overlay")

# Action creator methods
static func transition_to(scene_id: String, transition_type: String = "fade") -> Dictionary:
    return {
        "type": ACTION_TRANSITION_TO,
        "payload": {
            "scene_id": scene_id,
            "transition_type": transition_type
        }
    }

static func transition_complete(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_TRANSITION_COMPLETE,
        "payload": {"scene_id": scene_id}
    }

static func push_overlay(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_PUSH_OVERLAY,
        "payload": {"scene_id": scene_id}
    }

static func pop_overlay() -> Dictionary:
    return {
        "type": ACTION_POP_OVERLAY,
        "payload": null
    }
```

### Reducer Signature (SceneReducer)

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", StringName())

    match action_type:
        U_SceneActions.ACTION_TRANSITION_TO:
            var new_state: Dictionary = state.duplicate(true)
            new_state["is_transitioning"] = true
            # Don't update current_scene_id yet - wait for completion
            return new_state

        U_SceneActions.ACTION_TRANSITION_COMPLETE:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            new_state["current_scene_id"] = payload.get("scene_id", "")
            new_state["is_transitioning"] = false
            return new_state

        U_SceneActions.ACTION_PUSH_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            var scene_id: String = payload.get("scene_id", "")
            if not scene_id.is_empty():
                var stack: Array = new_state.get("scene_stack", []).duplicate()
                stack.append(scene_id)
                new_state["scene_stack"] = stack
            return new_state

        U_SceneActions.ACTION_POP_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var stack: Array = new_state.get("scene_stack", []).duplicate()
            if not stack.is_empty():
                stack.pop_back()
            new_state["scene_stack"] = stack
            return new_state

        _:
            # Unknown action - return state unchanged
            return state
```

### Important Patterns

**Immutability**:
- Always use `.duplicate(true)` when modifying state
- Never mutate `state` parameter directly
- Return new Dictionary

**Two-Phase Transitions**:
- `transition_to` sets `is_transitioning = true` but does NOT change `current_scene_id`
- `transition_complete` sets `is_transitioning = false` AND updates `current_scene_id`
- This prevents race conditions if transition is cancelled

---

## R010: Integration Points (ActionRegistry, RS_StateSliceConfig, U_SignalBatcher)

### ActionRegistry Integration

**Purpose**: Validates action types at runtime, prevents typos/errors

**Registration Pattern**:
```gdscript
# In U_SceneActions._static_init()
static func _static_init() -> void:
    ActionRegistry.register_action(ACTION_TRANSITION_TO)
    ActionRegistry.register_action(ACTION_TRANSITION_COMPLETE)
    ActionRegistry.register_action(ACTION_PUSH_OVERLAY)
    ActionRegistry.register_action(ACTION_POP_OVERLAY)
```

**Benefit**: ActionRegistry.validate_action() will reject unknown action types

### RS_StateSliceConfig Integration

**Purpose**: Configures scene slice in M_StateStore

**Configuration Pattern**:
```gdscript
# In M_StateStore._initialize_slices()
if scene_initial_state != null:
    var scene_config := RS_StateSliceConfig.new(StringName("scene"))
    scene_config.reducer = Callable(SceneReducer, "reduce")
    scene_config.initial_state = scene_initial_state.to_dictionary()
    scene_config.dependencies = []  # No dependencies on other slices
    scene_config.transient_fields = [StringName("is_transitioning")]
    register_slice(scene_config)
```

**Key Fields**:
- `reducer`: Callable pointing to SceneReducer.reduce()
- `initial_state`: Dictionary from RS_SceneInitialState.to_dictionary()
- `dependencies`: Empty array (scene slice independent)
- `transient_fields`: Array of field names to exclude from serialization

### Signal Batching (U_StateEventBus)

**Purpose**: Batches state updates per-frame to avoid redundant subscriptions

**Subscription Pattern**:
```gdscript
# In M_SceneManager._ready()
func _ready() -> void:
    _state_store = U_StateUtils.get_store(self)
    _state_store.subscribe(_on_state_changed)

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
    var scene_slice: Dictionary = new_state.get("scene", {})

    # React to specific action types
    if action.get("type") == U_SceneActions.ACTION_TRANSITION_COMPLETE:
        var scene_id: String = scene_slice.get("current_scene_id", "")
        # Handle transition completion
```

**Batching Behavior**:
- Multiple dispatches in same frame → single notification at frame end
- Subscribers receive `(action, new_state)` tuple
- Action is the LATEST action that caused state change
- New state is current state after all updates

### M_StateStore Modification Plan (FR-112)

**Required Changes**:

1. Add exported property:
```gdscript
@export var scene_initial_state: RS_SceneInitialState
```

2. Register scene slice in `_initialize_slices()`:
```gdscript
# After existing boot/menu/gameplay registrations
if scene_initial_state != null:
    var scene_config := RS_StateSliceConfig.new(StringName("scene"))
    scene_config.reducer = Callable(SceneReducer, "reduce")
    scene_config.initial_state = scene_initial_state.to_dictionary()
    scene_config.dependencies = []
    scene_config.transient_fields = [StringName("is_transitioning")]
    register_slice(scene_config)
```

**Safety Validation**:
- Adding new slice registration does NOT affect existing slices
- Scene slice has no dependencies, so registration order doesn't matter
- Transient field exclusion already implemented in save_state() logic
- StateHandoff already supports arbitrary slice names

---

## M_SceneManager Controller Pattern

### Coordinator Role (Not State Owner)

**Key Principle**: M_SceneManager performs operations, THEN dispatches completion to store

**Pattern**:
```gdscript
func transition_to_scene(scene_id: String, transition_type: String) -> void:
    # 1. Dispatch start action
    _state_store.dispatch(U_SceneActions.transition_to(scene_id, transition_type))

    # 2. Perform actual transition (scene loading, effects, etc.)
    await _perform_transition(scene_id, transition_type)

    # 3. Dispatch completion action
    _state_store.dispatch(U_SceneActions.transition_complete(scene_id))
```

**Why This Pattern**:
- Avoids circular loops (manager dispatches → reducer → manager subscribes → manager dispatches)
- Manager performs actual operations (scene tree manipulation)
- State store tracks current state (for save/load)
- Clear separation: Manager = controller, Store = model

---

## Summary

**Scene Slice**:
- 3 fields: `current_scene_id`, `scene_stack`, `is_transitioning`
- `is_transitioning` marked transient (excluded from save)

**U_SceneRegistry**:
- Static class with `_scenes` and `_door_pairings` dictionaries
- Validation method checks bidirectional consistency

**BaseTransitionEffect**:
- Base class with `start_transition()`, `update_progress()`, `complete_transition()`
- Three implementations: Instant, Fade, LoadingScreen

**Actions/Reducers**:
- 4 action types: `transition_to`, `transition_complete`, `push_overlay`, `pop_overlay`
- Immutable reducer pattern with `.duplicate(true)`

**Integration**:
- ActionRegistry: Register actions in `_static_init()`
- RS_StateSliceConfig: Configure slice with transient fields
- U_StateEventBus: Subscribe to batched updates
- M_StateStore: Add `scene_initial_state` property and register in `_initialize_slices()`

**Next Steps**: Safety checks on M_StateStore modification (R022-R026)
