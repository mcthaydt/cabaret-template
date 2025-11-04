# Mock to Real Data Migration Guide

**Date**: 2025-10-27  
**Phase**: 16.5  
**Status**: Complete

## Overview

This guide documents the migration from test-only mock data to production-ready state structure in the Redux state store. Phase 16.5 removed all mock fields, actions, and selectors that were only used for testing, leaving a clean production state with real gameplay data.

## What Was Removed

### State Fields (RS_GameplayInitialState)

```gdscript
# REMOVED - Test-only mock data
@export var health: int = 100
@export var score: int = 0
@export var level: int = 1
```

**Why removed**: These fields were placeholders for testing state store functionality. Real health/score/progression systems don't exist yet. When they're built, they should use ECS components as the source of truth, not state store fields.

### Action Creators (U_GameplayActions)

```gdscript
# REMOVED - Test-only actions
static func update_health(health: int) -> Dictionary
static func update_score(score: int) -> Dictionary
static func set_level(level: int) -> Dictionary
static func take_damage(amount: int) -> Dictionary
static func add_score(points: int) -> Dictionary
```

**Why removed**: These actions had no real gameplay purpose. They were used in tests to demonstrate action dispatch patterns.

### Reducers (GameplayReducer)

```gdscript
# REMOVED - Test-only reducer cases
U_GameplayActions.ACTION_UPDATE_HEALTH
U_GameplayActions.ACTION_UPDATE_SCORE
U_GameplayActions.ACTION_SET_LEVEL
U_GameplayActions.ACTION_TAKE_DAMAGE
U_GameplayActions.ACTION_ADD_SCORE
```

### Selectors (GameplaySelectors)

```gdscript
# REMOVED - Test-only selectors
static func get_current_health(gameplay_state: Dictionary) -> int
static func get_current_score(gameplay_state: Dictionary) -> int
static func get_is_player_alive(gameplay_state: Dictionary) -> bool
static func get_is_game_over(gameplay_state: Dictionary) -> bool
static func get_completion_percentage(gameplay_state: Dictionary) -> float
```

**Why removed**: These selectors computed derived state from non-existent fields. Real selectors should compute from actual gameplay data.

### Systems

```gdscript
# REMOVED
scripts/ecs/systems/s_health_system.gd
```

**Why removed**: This was a proof-of-concept system that only applied periodic damage for testing. It had no real gameplay value and used removed mock actions.

### Test Files

**Unit tests removed:**
- `tests/unit/integration/test_poc_health_system.gd`

**Visual test scenes removed:**
- `scenes/debug/state_test_us1d.gd` - Tested mock action creators
- `scenes/debug/state_test_us1e.gd` - Tested mock selectors
- `scenes/debug/state_test_us1f.gd` - Tested signal batching with mock actions
- `scenes/debug/state_test_us1g.gd` - Tested action history with mock actions
- `scenes/debug/state_test_us1h.gd` - Tested persistence with mock data
- `scenes/debug/state_test_us5_full_flow.gd` - Full flow test with mock data

**Why removed**: These tests validated mock data functionality. Unit tests now cover all real functionality using pause/unpause and entity snapshots.

## What Was Updated

### HUD Overlay

**Before:**
```gdscript
func _update_display(gameplay_state: Dictionary) -> void:
    var health: int = GameplaySelectors.get_current_health(gameplay_state)
    var score: int = GameplaySelectors.get_current_score(gameplay_state)
    var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
    
    health_label.text = "Health: %d" % health
    score_label.text = "Score: %d" % score
    pause_label.text = "[PAUSED]" if is_paused else ""
```

**After:**
```gdscript
func _update_display(gameplay_state: Dictionary) -> void:
    var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
    pause_label.text = "[PAUSED]" if is_paused else ""
```

### S_JumpSystem

**Before:**
```gdscript
# Award points for jumping (PoC integration with state store)
if store:
    store.dispatch(U_GameplayActions.add_score(10))
```

**After:**
```gdscript
# Score dispatch removed - no mock actions
```

### All Test Files

All remaining test files refactored to use:
- `U_GameplayActions.pause_game()` / `unpause_game()` instead of health/score actions
- `U_EntityActions.update_entity_snapshot()` for testing entity coordination
- Real production fields: `paused`, `entities`, `move_input`, etc.

### Documentation

**redux-state-store-usage-guide.md** - All examples updated:
- Replaced `update_health()`, `add_score()` examples with `pause_game()`, `update_entity_snapshot()`
- Updated selector examples to use `get_is_paused()`, `get_player_position()`
- Fixed all code samples to reflect production state structure

## Production State Structure

### Current Fields (Production)

```gdscript
# Core gameplay state (writable)
@export var paused: bool = false

# Player input state (writable - single player)
@export var move_input: Vector2 = Vector2.ZERO
@export var look_input: Vector2 = Vector2.ZERO
@export var jump_pressed: bool = false
@export var jump_just_pressed: bool = false

# Global settings (writable)
@export var gravity_scale: float = 1.0
@export var show_landing_indicator: bool = true
@export var particle_settings: Dictionary = {}
@export var audio_settings: Dictionary = {}

# Entity snapshots (read-only coordination layer)
@export var entities: Dictionary = {}
```

**All fields are used by real game systems:**
- `paused`: Used by S_PauseSystem and all gameplay systems
- Input fields: Used by S_InputSystem
- Settings: Used by S_GravitySystem, S_LandingIndicatorSystem
- `entities`: Entity Coordination Pattern for multi-entity state

## Migration Patterns

### Pattern 1: If You Need Health/Score/Level

**Don't add them to state store.** Instead:

1. **Use ECS Components** as the source of truth:
   ```gdscript
   # Create a C_HealthComponent
   var health_comp: C_HealthComponent
   var current_health: int = health_comp.current_health
   ```

2. **Optionally dispatch snapshots** to state for coordination:
   ```gdscript
   # If other systems need to read health
   store.dispatch(U_EntityActions.update_entity_snapshot("player", {
       "health": health_comp.current_health
   }))
   ```

3. **Use EntitySelectors** to read from state:
   ```gdscript
   var player_health: int = EntitySelectors.get_entity(state, "player").get("health", 0)
   ```

### Pattern 2: Testing State Store Functionality

**Use real actions in tests:**

```gdscript
# BEFORE (mock data)
func test_action_dispatches() -> void:
    store.dispatch(U_GameplayActions.update_health(75))
    var state: Dictionary = store.get_slice(StringName("gameplay"))
    assert_eq(state.get("health"), 75)

# AFTER (production data)
func test_action_dispatches() -> void:
    store.dispatch(U_GameplayActions.pause_game())
    var state: Dictionary = store.get_slice(StringName("gameplay"))
    assert_eq(state.get("paused"), true)
```

### Pattern 3: UI Display

**Use real state fields or entity snapshots:**

```gdscript
# BEFORE (mock data)
func _update_ui(state: Dictionary) -> void:
    health_label.text = "Health: %d" % GameplaySelectors.get_current_health(state)
    score_label.text = "Score: %d" % GameplaySelectors.get_current_score(state)

# AFTER (entity data)
func _update_ui(state: Dictionary) -> void:
    var player: Dictionary = EntitySelectors.get_entity(state, "player")
    if player.has("health"):
        health_label.text = "Health: %d" % player.get("health")
    if player.has("score"):
        score_label.text = "Score: %d" % player.get("score")
```

## Testing Impact

### Before Phase 16.5
- 213/213 tests passing (100%)
- Included tests for mock health/score/level functionality
- 9 unit test files + 11 visual test scenes

### After Phase 16.5
- 104/104 tests passing (100%)
- All tests use production data
- 8 unit test files + 5 visual test scenes
- Cleaner, more focused test suite

## Future Guidance

### When to Add Fields to State

**DON'T add to state store if:**
- Data is entity-specific (use Entity Coordination Pattern instead)
- Data is internal to a component (keep in C_* component)
- Data is purely visual (keep in UI nodes)

**DO add to state store if:**
- Data is global game-wide state (pause, game mode, difficulty)
- Data is player input (for replay/netcode)
- Data is settings/configuration (gravity modifiers, debug flags)
- Data coordinates multiple systems (current scene, transition state)

### Entity Coordination Pattern

For entity-specific data (health, position, velocity):

1. **Component is source of truth**: `C_HealthComponent.current_health`
2. **Dispatch snapshots to state**: `U_EntityActions.update_entity_snapshot("player", {...})`
3. **Other systems read via selectors**: `EntitySelectors.get_entity(state, "player")`
4. **State is read-only coordination layer**, not the authoritative data store

See `docs/state store/redux-state-store-entity-coordination-pattern.md` for details.

## References

- **Audit Document**: `docs/state store/mock-data-removal-plan.md`
- **Usage Guide**: `docs/state store/redux-state-store-usage-guide.md`
- **Entity Coordination**: `docs/state store/redux-state-store-entity-coordination-pattern.md`
- **PRD**: `docs/state store/redux-state-store-prd.md` (Version 3.1)

## Conclusion

Phase 16.5 successfully removed all test-only mock data, resulting in a clean production-ready state store. The state now contains only real fields used by actual game systems, with the Entity Coordination Pattern providing a clear path for future entity-specific data needs.

All 104 unit tests pass, documentation is updated, and the state store is ready for production use.
