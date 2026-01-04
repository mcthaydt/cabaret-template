# Scene Manager - Quick Start Guide

## Overview

The Scene Manager system provides robust scene transitions, state persistence, preloading, and pause functionality for Project Musical Parakeet. This guide will help you get started quickly.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Basic Usage](#basic-usage)
3. [Creating New Scenes](#creating-new-scenes)
4. [Adding Scene Triggers (Doors)](#adding-scene-triggers-doors)
5. [State Management](#state-management)
6. [Transition Effects](#transition-effects)
7. [Common Patterns](#common-patterns)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Root Scene Pattern

The project uses a persistent root scene (`scenes/root.tscn`) that remains loaded throughout the session:

```
Root (Node)
├─ M_StateStore (persistent)
├─ M_CursorManager (persistent)
├─ M_SceneManager (persistent)
├─ ActiveSceneContainer (Node) - gameplay scenes load here
├─ UIOverlayStack (CanvasLayer) - pause/menu overlays stack here
├─ TransitionOverlay (CanvasLayer) - fade effects
└─ LoadingOverlay (CanvasLayer) - loading screens
```

**Key Concept**: Gameplay scenes are loaded/unloaded dynamically as children of `ActiveSceneContainer`. Managers persist throughout the session.

### Scene Types

Scenes are categorized into types that determine their behavior:

- **UI**: Menu screens, settings (cursor visible, no ECS)
- **GAMEPLAY**: Game worlds (cursor locked, ECS systems active)
- **END_GAME**: Victory, game over, credits (cursor visible, special handling)

---

## Basic Usage

### Triggering a Scene Transition

From any script with access to the scene tree:

```gdscript
# Get the scene manager
var scene_manager := get_tree().get_first_node_in_group("scene_manager") as M_SceneManager

# Transition to a registered scene
scene_manager.transition_to_scene(StringName("gameplay_base"))

# With explicit transition type
scene_manager.transition_to_scene(StringName("main_menu"), "fade")

# With priority (for critical transitions like death)
scene_manager.transition_to_scene(
	StringName("game_over"),
	"fade",
	M_SceneManager.Priority.CRITICAL
)
```

### Transition Types

- **`"instant"`**: No delay, immediate switch (< 100ms)
- **`"fade"`**: Smooth fade out → load → fade in (0.2-0.5s)
- **`"loading"`**: Full loading screen with progress bar (1.5s+ for large scenes)

### Transition Priorities

```gdscript
enum Priority {
	NORMAL = 0,   # Standard navigation
	HIGH = 1,     # Important but not urgent
	CRITICAL = 2  # Death, game over, etc. (jumps to front of queue)
}
```

---

## Creating New Scenes

### Step 1: Create the Scene File

For **gameplay scenes**, duplicate `scenes/gameplay/gameplay_base.tscn`:

```bash
scenes/gameplay/gameplay_base.tscn → scenes/gameplay/my_new_level.tscn
```

**Required structure** (gameplay scenes):
- ✅ M_ECSManager (per-scene instance)
- ✅ Systems (Core, Physics, Movement, Feedback)
- ✅ Entities (player, camera, spawn points)
- ❌ M_StateStore (lives in root.tscn only)
- ❌ M_CursorManager (lives in root.tscn only)

For **UI scenes**, create a simple Control-based scene:

```gdscript
# Example: scenes/ui/my_menu.tscn
Control (root)
└─ VBoxContainer
   ├─ Label ("My Menu")
   └─ Button ("Back to Menu")
```

### Step 2: Register the Scene

Add your scene to `scripts/scene_management/u_scene_registry.gd`:

```gdscript
func _register_all_scenes() -> void:
	# ... existing registrations ...

	# Register your new scene
	_register_scene(
		StringName("my_new_level"),              # Scene ID
		"res://scenes/gameplay/my_new_level.tscn", # Path
		SceneType.GAMEPLAY,                       # Type
		"fade",                                   # Default transition
		5                                         # Preload priority (0-10)
	)
```

**Preload Priority Guidelines**:
- `10`: Critical UI (main_menu, pause_menu) - preloaded at startup
- `5-7`: Frequently accessed scenes
- `0-4`: Occasional access
- `0`: No preload (loaded on-demand)

### Step 3: Add Spawn Points

For gameplay scenes, add spawn markers:

```
E_Player (instance of templates/player_template.tscn)
SpawnPoints (Node3D)
├─ sp_default (Node3D) - default spawn location
├─ sp_entrance_from_exterior (Node3D)
└─ sp_exit_from_house (Node3D)
```

**Naming Convention**: `sp_` prefix + descriptive name (lowercase snake_case)

---

## Adding Scene Triggers (Doors)

### Step 1: Create a Door Trigger Entity

In your gameplay scene, add a door trigger:

```
E_DoorTrigger (Node3D)
├─ C_SceneTriggerComponent (attached to E_DoorTrigger)
├─ Area3D (detection zone)
│  └─ CollisionShape3D (CylinderShape3D for door-like triggers)
└─ CSGCylinder3D (visual door representation)
```

### Step 2: Configure the Trigger Component

Select `C_SceneTriggerComponent` and set properties:

```gdscript
# In the Godot Inspector:
door_id: "door_to_interior"
target_scene_id: "interior_house"
target_spawn_point: "sp_entrance_from_exterior"
trigger_mode: AUTO  # or INTERACT (requires 'E' key press)
cooldown_duration: 1.0
```

### Step 3: Register Door Pairing (Bidirectional)

In `u_scene_registry.gd`, add door pairings for two-way transitions:

```gdscript
func _register_door_pairings() -> void:
	# Exterior ↔ Interior House
	_register_door_pair(
		StringName("exterior"), StringName("door_to_house"),
		StringName("interior_house"), StringName("door_to_exterior")
	)
```

**What this does**: When player uses `door_to_house` in `exterior`, they spawn at `door_to_exterior` in `interior_house`, and vice versa.

### Step 4: Configure Trigger Geometry

For custom trigger shapes, create a settings resource:

```gdscript
# resources/triggers/custom_door_trigger.tres
extends RS_SceneTriggerSettings

shape_type = ShapeType.CYLINDER  # or BOX
cylinder_radius = 1.5
cylinder_height = 3.0
local_offset = Vector3(0, 1.5, 0)  # Center at player height
player_mask = 1  # Collision layer 1 (player)
```

Assign this resource to `C_SceneTriggerComponent.settings` in the Inspector.

**Tip**: Use `local_offset` to position the trigger, not node transforms. Avoid non-uniform scaling on trigger nodes.

---

## State Management

### Persistent Gameplay State

The `gameplay` state slice automatically persists across scene transitions:

```gdscript
# Read state
var store := U_StateUtils.get_store(self)
var state: Dictionary = store.get_state()
var gameplay_state: Dictionary = state.get("gameplay", {})

var health: float = gameplay_state.get("player_health", 100.0)
var death_count: int = gameplay_state.get("death_count", 0)
var completed_areas: Array = gameplay_state.get("completed_areas", [])
```

### Modifying State

Always use action creators:

```gdscript
# Update player health
const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
store.dispatch(U_GameplayActions.take_damage(player_id, 25.0))

# Mark area completed
store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))

# Increment death count
store.dispatch(U_GameplayActions.increment_death_count())
```

### Save/Load State

```gdscript
# Save game state to disk
var save_result: Error = store.save_state("user://savegame.json")
if save_result == OK:
	print("Game saved successfully")

# Load game state from disk
var load_result: Error = store.load_state("user://savegame.json")
if load_result == OK:
	print("Game loaded successfully")
```

**Note**: Transient fields (like `is_transitioning`) are automatically excluded from saves.

---

## Transition Effects

### Using Different Transitions

Each scene has a default transition type (defined in `U_SceneRegistry`), but you can override per-transition:

```gdscript
# Use registry default (recommended)
scene_manager.transition_to_scene(StringName("main_menu"))

# Override with instant (fast UI nav)
scene_manager.transition_to_scene(StringName("settings_menu"), "instant")

# Override with fade (smooth polish)
scene_manager.transition_to_scene(StringName("gameplay_base"), "fade")

# Override with loading screen (large scene)
scene_manager.transition_to_scene(StringName("open_world_area"), "loading")
```

### Camera Blending (Gameplay → Gameplay)

Camera position, rotation, and FOV blend smoothly during gameplay-to-gameplay transitions:

```gdscript
# Automatic camera blending for GAMEPLAY → GAMEPLAY transitions
scene_manager.transition_to_scene(StringName("interior_house"), "fade")
# Camera smoothly interpolates from exterior camera to interior camera
# No additional code needed - handled automatically by M_SceneManager
```

**Scene-specific camera setup**:
```gdscript
# In your scene: E_Camera/E_PlayerCamera (Camera3D)
# Configure per-scene:
# - Exterior: FOV 80°, position (0, 1.5, 4.5) - higher, wider
# - Interior: FOV 65°, position (0, 0.8, 4.5) - lower, narrower
# Blending happens automatically during transitions
```

---

## Common Patterns

### Pause Menu

Open pause overlay (does not unload gameplay scene):

```gdscript
# ESC key opens pause menu automatically via M_SceneManager
# Or manually:
scene_manager.push_overlay(StringName("pause_menu"))

# Resume gameplay (close pause overlay)
scene_manager.pop_overlay()
```

### Settings from Pause Menu

Navigate from pause → settings with return stack:

```gdscript
# In pause_menu.gd, on Settings button pressed:
var scene_manager := get_tree().get_first_node_in_group("scene_manager") as M_SceneManager
scene_manager.push_overlay_with_return(StringName("settings_menu"))

# In settings_menu.gd, on Back button pressed:
scene_manager.pop_overlay_with_return()  # Returns to pause menu
```

**What this does**: Settings replaces pause overlay, but pause overlay is remembered in the return stack. Pressing Back restores pause menu automatically.

### Death → Game Over

From a system (e.g., `S_HealthSystem`):

```gdscript
func _handle_death_sequence(component: C_HealthComponent, entity: Node3D) -> void:
	if component.death_timer <= 0.0:
		# Show death effect for 2.5 seconds
		_spawn_ragdoll(entity)

		# Transition to game over with critical priority
		var scene_manager := get_tree().get_first_node_in_group("scene_manager")
		scene_manager.transition_to_scene(
			StringName("game_over"),
			"fade",
			M_SceneManager.Priority.CRITICAL
		)
```

### Victory → Credits Flow

From a victory system:

```gdscript
# Mark level complete
store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))

# Transition to victory screen
scene_manager.transition_to_scene(StringName("victory"), "fade")

# In victory.tscn script, on "Credits" button:
scene_manager.transition_to_scene(StringName("credits"), "fade")

# Credits auto-returns to main menu after 60 seconds
```

### Retry After Death

From game_over.tscn script:

```gdscript
func _on_retry_pressed() -> void:
	# Soft reset: restore health, keep progress
	const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
	var store := U_StateUtils.get_store(self)
	store.dispatch(U_GameplayActions.heal(0, 100.0))  # Full health

	# Return to exterior (hub world)
	var scene_manager := get_tree().get_first_node_in_group("scene_manager")
	scene_manager.transition_to_scene(StringName("exterior"), "fade")
```

---

## Troubleshooting

### Scene Not Found Error

```
M_SceneManager: Scene 'my_scene' not found in U_SceneRegistry
```

**Solution**: Add your scene to `U_SceneRegistry._register_all_scenes()` with `_register_scene()`.

### Player Spawns at Wrong Location

**Problem**: Player appears at origin (0,0,0) instead of door exit.

**Solutions**:
1. Check spawn marker name matches `target_spawn_point` in door trigger
2. Verify spawn marker is under `SpawnPoints` container
3. Ensure spawn marker naming uses `sp_` prefix (lowercase)

Example:
```gdscript
# In door trigger:
target_spawn_point: "sp_entrance_from_exterior"

# In target scene:
SpawnPoints
└─ sp_entrance_from_exterior (Node3D at global_position where player should spawn)
```

### Door Triggers Ping-Pong (Player Stuck in Loop)

**Problem**: Player exits door and immediately re-enters, causing rapid transitions.

**Solutions**:
1. **Position spawn markers outside trigger zones**:
   ```
   [Door Trigger Zone] → [Exit spawn marker 2-3 units away] ←
   ```
2. **Increase cooldown duration**:
   ```gdscript
   C_SceneTriggerComponent.cooldown_duration = 2.0  # seconds
   ```
3. **Check trigger geometry**:
   - Use cylinder shape (not box) for door-like triggers
   - Avoid oversized trigger zones
   - Verify `local_offset` positions trigger correctly

### Transition During Transition (Queue Not Processing)

**Problem**: Rapid transitions cause state corruption or hangs.

**How it works**: Scene Manager has a transition queue with priority handling. Critical transitions (death, game over) jump to front of queue.

**If stuck**:
1. Check `_is_processing_transition` flag isn't stuck (should be `false` when idle)
2. Verify transition completes (`current_scene_id` updates after transition)
3. Check test logs for error messages during scene loading

### HUD Not Finding State Store

```
ERROR: U_StateUtils.get_store: No M_StateStore in 'state_store' group
```

**Problem**: HUD trying to access store before it's registered.

**Solution**: Add `await get_tree().process_frame` in `_ready()` before calling `get_store()`:

```gdscript
func _ready() -> void:
	await get_tree().process_frame  # Wait for store to register
	_store = U_StateUtils.get_store(self)
	# ... rest of setup
```

### State Not Persisting Across Transitions

**Problem**: Player health/progress resets when changing scenes.

**Checklist**:
1. Verify you're dispatching actions to modify state (not setting fields directly)
2. Check `StateHandoff` logs confirm state preservation:
   ```
   [STATE] Preserved state to StateHandoff for scene transition
   [STATE] Restored slice 'gameplay' from StateHandoff
   ```
3. Ensure systems read state via `U_StateUtils.get_store()`, not local variables
4. Check field isn't marked as transient in `RS_GameplayInitialState.transient_fields`

### Camera Doesn't Blend During Transitions

**Problem**: Camera position/rotation/FOV jumps instead of smoothly blending.

**Requirements for camera blending**:
1. Transition type must be `"fade"` (not instant or loading)
2. Both scenes must be GAMEPLAY type (not UI → GAMEPLAY)
3. Both scenes must have camera in "main_camera" group

**Verify setup**:
```gdscript
# In each gameplay scene:
# E_Camera/E_PlayerCamera (Camera3D node)
# Should be in "main_camera" group (check Inspector → Node tab → Groups)
```

### Tests Failing with "Tween timing unreliable in headless mode"

**Expected**: Some transition timing tests are skipped in headless mode because Tween animations don't run consistently without GPU rendering.

**These tests are marked pending (not failures)**:
- `test_fade_transition_uses_tween`
- `test_input_blocking_enabled`
- `test_fade_transition_easing`

**Solution**: These tests pass when run in the Godot editor with rendering enabled. Use manual validation for transition polish.

### Memory Leaks / Performance Degradation

**Scene cache management**: Scene Manager uses LRU (Least Recently Used) cache eviction:
- Max 5 cached scenes
- Max 100MB memory usage
- Oldest scenes evicted when limits exceeded

**To monitor**:
1. Check `_scene_cache.size()` doesn't grow unbounded
2. Verify `_evict_from_cache()` logs when cache is full
3. Use Godot profiler to track memory usage across transitions

**Manual cache control** (if needed):
```gdscript
# Clear specific scene from cache
scene_manager._scene_cache.erase(StringName("large_scene"))
```

---

## Best Practices

### ✅ DO

- Register all scenes in `U_SceneRegistry` before using them
- Use action creators (`U_GameplayActions`, `U_SceneActions`) to modify state
- Position spawn markers outside trigger zones (2-3 units away)
- Use `"fade"` transitions for menu ↔ gameplay (polished feel)
- Use `"instant"` transitions for rapid UI navigation
- Set cooldowns on door triggers (1-2 seconds)
- Test bidirectional door pairings (ensure you can exit the way you entered)
- Keep gameplay scenes self-contained (don't reference managers that live in root.tscn)

### ❌ DON'T

- Don't modify state directly (use actions/reducers)
- Don't add `M_StateStore` or `M_CursorManager` to gameplay scenes (they belong in root.tscn)
- Don't use non-uniform scaling on trigger nodes (scale the shape resource instead)
- Don't position spawn markers inside trigger zones (causes ping-pong loops)
- Don't forget to call `await get_tree().process_frame` before accessing store in `_ready()`
- Don't create scenes without registering them in `U_SceneRegistry`
- Don't use `"loading"` transitions for small scenes (minimum 1.5s duration is jarring for instant loads)

---

## Quick Reference

### File Locations

- **Root scene**: `scenes/root.tscn`
- **Gameplay template**: `scenes/gameplay/gameplay_base.tscn`
- **Scene registry**: `scripts/scene_management/u_scene_registry.gd`
- **Scene manager**: `scripts/managers/m_scene_manager.gd`
- **Scene actions**: `scripts/state/actions/u_scene_actions.gd`
- **Gameplay actions**: `scripts/state/actions/u_gameplay_actions.gd`
- **State utils**: `scripts/state/utils/u_state_utils.gd`

### Common Imports

```gdscript
const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const U_SceneRegistry = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_SceneActions = preload("res://scripts/state/actions/u_scene_actions.gd")
const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_StateUtils = preload("res://scripts/state/utils/u_state_utils.gd")
const C_SceneTriggerComponent = preload("res://scripts/ecs/components/c_scene_trigger_component.gd")
```

### Scene Manager API

```gdscript
# Transitions
transition_to_scene(scene_id: StringName, transition_type: String = "", priority: Priority = Priority.NORMAL)

# Overlays (pause, settings)
push_overlay(scene_id: StringName)
pop_overlay()
push_overlay_with_return(scene_id: StringName)  # Remember previous overlay
pop_overlay_with_return()  # Restore previous overlay

# Navigation
go_back()  # Navigate back through UI history
can_go_back() -> bool

# Preloading
hint_preload_scene(scene_id: StringName)  # Background load for smooth transitions

# State queries
is_transitioning() -> bool
get_current_scene_id() -> StringName
```

---

## Next Steps

- **For more details**: See `docs/scene_manager/scene-manager-prd.md` (full specification)
- **For implementation patterns**: See `AGENTS.md` (project conventions)
- **For common pitfalls**: See `docs/general/DEV_PITFALLS.md` (Scene Manager section)
- **For architectural details**: See `docs/scene_manager/scene-manager-plan.md`

---

**Last Updated**: 2025-11-03
**Version**: 1.0 (Phase 10 Complete)
