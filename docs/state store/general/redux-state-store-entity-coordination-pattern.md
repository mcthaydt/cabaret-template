# Entity Coordination Pattern: State Store + ECS Hybrid Architecture

**Author**: Droid (with user guidance)  
**Date**: 2025-10-27  
**Status**: Proposed (Phase 16 refactoring)

---

## Problem Statement

During Phase 16 implementation, we discovered a fundamental scaling issue with the initial approach:

**What We Did (T450-T451):**
```gdscript
gameplay: {
  position: Vector3,      // Single position - whose?
  velocity: Vector3,      // Single velocity - whose?
  rotation: Vector3,      // Single rotation - whose?
  is_on_floor: bool       // Single flag - whose?
}
```

**The Issue:**
- Only works for exactly one entity (the player)
- Doesn't scale to AI enemies, co-op, or multiple characters
- Systems dispatch `bodies[0]` assuming a single entity
- Violates ECS principles (components should be per-entity source of truth)

**User Insight:**
> "How does this scale for multiple characters, like if I had an AI? It seems like, because it's tied to the central state, that it should be tied to the entity rather than just flat no?"

---

## Proposed Solution: Entity Coordination Pattern

### Core Principle

**Components = Source of Truth (Write)**  
ECS components remain the authoritative, writable source for all per-entity data.

**State Store = Coordination Layer (Read)**  
State store provides read-only snapshots for cross-entity coordination and visibility.

### Architecture

```gdscript
gameplay: {
  // Game-wide state (writable by systems)
  paused: bool,
  score: int,
  health: int,
  level: int,
  
  // Player input state (writable - single player input)
  move_input: Vector2,
  look_input: Vector2,
  jump_pressed: bool,
  jump_just_pressed: bool,
  
  // Global settings (writable)
  gravity_scale: float,
  show_landing_indicator: bool,
  particle_settings: Dictionary,
  audio_settings: Dictionary,
  
  // Entity snapshots (read-only for coordination)
  entities: {
    "player": {
      position: Vector3,
      velocity: Vector3,
      rotation: Vector3,
      is_on_floor: bool,
      is_moving: bool,
      health: int,           // Per-entity health
      entity_type: String    // "player", "enemy", "npc"
    },
    "enemy_goblin_1": {
      position: Vector3,
      velocity: Vector3,
      rotation: Vector3,
      is_on_floor: bool,
      is_moving: bool,
      health: int,
      entity_type: String
    },
    "enemy_goblin_2": { ... }
  }
}
```

---

## Data Flow

### Write Flow (Components → Components)
```
System reads from Component
  ↓
System modifies Component
  ↓
System dispatches snapshot to State Store (for coordination)
```

### Read Flow (State → Systems)
```
AI System needs player position
  ↓
AI System reads from State Store entities["player"]
  ↓
AI System uses position for pathfinding/behavior
```

### Example: AI Enemy Chasing Player

**Without State Store (tight coupling):**
```gdscript
# Bad: AI system directly queries player component
var player_entity = manager.find_entity_with_tag("player")
var player_transform = player_entity.get_component("C_TransformComponent")
var player_pos = player_transform.position  # Tight coupling!
```

**With Entity Coordination Pattern:**
```gdscript
# Good: AI reads from state coordination layer
var store = U_StateUtils.get_store(self)
var player_pos = EntitySelectors.get_entity_position(store.get_state(), "player")
# No direct component access, no coupling, scales to multiple entities
```

---

## Implementation Details

### 1. New Action Creators

**U_EntityActions.gd** (new file):
```gdscript
class_name U_EntityActions

## Update entity snapshot in state
static func update_entity_snapshot(entity_id: String, snapshot: Dictionary) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_ENTITY_SNAPSHOT", {
		"entity_id": entity_id,
		"snapshot": snapshot
	})

## Remove entity from state (on despawn)
static func remove_entity(entity_id: String) -> Dictionary:
	return ActionRegistry.create_action("gameplay/REMOVE_ENTITY", {
		"entity_id": entity_id
	})
```

**U_PhysicsActions.gd** (updated):
```gdscript
# OLD (single entity):
static func update_velocity(velocity: Vector3) -> Dictionary

# NEW (multi-entity):
static func update_entity_physics(entity_id: String, physics_data: Dictionary) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_ENTITY_PHYSICS", {
		"entity_id": entity_id,
		"position": physics_data.get("position"),
		"velocity": physics_data.get("velocity"),
		"rotation": physics_data.get("rotation"),
		"is_on_floor": physics_data.get("is_on_floor"),
		"is_moving": physics_data.get("is_moving")
	})
```

### 2. Reducer Updates

**GameplayReducer.reduce():**
```gdscript
"gameplay/UPDATE_ENTITY_SNAPSHOT":
	var new_state: Dictionary = state.duplicate(true)
	var payload: Dictionary = action.get("payload", {})
	var entity_id: String = payload.get("entity_id", "")
	var snapshot: Dictionary = payload.get("snapshot", {})
	
	if entity_id.is_empty():
		return state
	
	# Ensure entities dict exists
	if not new_state.has("entities"):
		new_state["entities"] = {}
	
	# Merge snapshot into entity data
	if new_state["entities"].has(entity_id):
		var existing: Dictionary = new_state["entities"][entity_id]
		for key in snapshot.keys():
			existing[key] = snapshot[key]
	else:
		new_state["entities"][entity_id] = snapshot.duplicate(true)
	
	return new_state

"gameplay/REMOVE_ENTITY":
	var new_state: Dictionary = state.duplicate(true)
	var payload: Dictionary = action.get("payload", {})
	var entity_id: String = payload.get("entity_id", "")
	
	if new_state.has("entities") and new_state["entities"].has(entity_id):
		new_state["entities"].erase(entity_id)
	
	return new_state
```

### 3. New Selectors

**EntitySelectors.gd** (new file):
```gdscript
class_name EntitySelectors

## Get all entity snapshots
static func get_all_entities(state: Dictionary) -> Dictionary:
	return state.get("gameplay", {}).get("entities", {})

## Get specific entity snapshot
static func get_entity(state: Dictionary, entity_id: String) -> Dictionary:
	return get_all_entities(state).get(entity_id, {})

## Get entity position
static func get_entity_position(state: Dictionary, entity_id: String) -> Vector3:
	return get_entity(state, entity_id).get("position", Vector3.ZERO)

## Get entity velocity
static func get_entity_velocity(state: Dictionary, entity_id: String) -> Vector3:
	return get_entity(state, entity_id).get("velocity", Vector3.ZERO)

## Get entity rotation
static func get_entity_rotation(state: Dictionary, entity_id: String) -> Vector3:
	return get_entity(state, entity_id).get("rotation", Vector3.ZERO)

## Check if entity is on floor
static func is_entity_on_floor(state: Dictionary, entity_id: String) -> bool:
	return get_entity(state, entity_id).get("is_on_floor", false)

## Get all entities of a specific type
static func get_entities_by_type(state: Dictionary, entity_type: String) -> Array:
	var result: Array = []
	var all_entities: Dictionary = get_all_entities(state)
	for entity_id in all_entities.keys():
		var entity: Dictionary = all_entities[entity_id]
		if entity.get("entity_type", "") == entity_type:
			result.append({
				"id": entity_id,
				"data": entity
			})
	return result

## Get player entity ID (convenience)
static func get_player_entity_id(state: Dictionary) -> String:
	var entities: Array = get_entities_by_type(state, "player")
	if entities.size() > 0:
		return entities[0]["id"]
	return ""

## Get player position (convenience)
static func get_player_position(state: Dictionary) -> Vector3:
	var player_id: String = get_player_entity_id(state)
	if player_id.is_empty():
		return Vector3.ZERO
	return get_entity_position(state, player_id)
```

### 4. System Integration Pattern

**S_MovementSystem (updated):**
```gdscript
func process_tick(delta: float) -> void:
	# ... existing movement logic ...
	
	for body in bodies:
		var final_velocity: Vector3 = body_state[body].velocity
		body.velocity = final_velocity
		if body.has_method("move_and_slide"):
			body.move_and_slide()
	
	# Phase 16: Dispatch entity snapshots to state store
	if store and bodies.size() > 0:
		for body in bodies:
			# Get entity ID from body metadata
			var entity_id: String = _get_entity_id(body)
			if entity_id.is_empty():
				continue
			
			# Dispatch snapshot for coordination
			var snapshot: Dictionary = {
				"position": body.global_position,
				"velocity": body.velocity,
				"rotation": body.rotation,
				"is_moving": Vector2(body.velocity.x, body.velocity.z).length() > 0.1,
				"entity_type": _get_entity_type(body)  # "player", "enemy", etc.
			}
			store.dispatch(U_EntityActions.update_entity_snapshot(entity_id, snapshot))

func _get_entity_id(body: Node) -> String:
	# Option 1: Use node name
	return body.name
	
	# Option 2: Use metadata
	if body.has_meta("entity_id"):
		return body.get_meta("entity_id")
	
	return ""

func _get_entity_type(body: Node) -> String:
	if body.has_meta("entity_type"):
		return body.get_meta("entity_type")
	
	# Fallback: infer from node name/path
	if "player" in body.name.to_lower():
		return "player"
	elif "enemy" in body.name.to_lower():
		return "enemy"
	
	return "unknown"
```

---

## Benefits

### 1. Scalability
- ✅ Works with any number of entities (players, enemies, NPCs)
- ✅ AI can read player/enemy positions without tight coupling
- ✅ Debug overlay shows all entity state at once

### 2. Proper ECS Architecture
- ✅ Components remain source of truth
- ✅ Systems operate on components (ECS native)
- ✅ State provides coordination, not ownership

### 3. Decoupling
- ✅ AI systems don't need direct component access
- ✅ Systems can query "all enemies near player" via state
- ✅ UI can show entity health bars from state

### 4. Debugging & Visibility
- ✅ Debug overlay shows all entity snapshots
- ✅ Time-travel debugging works for entity coordination
- ✅ Action history shows entity state changes

---

## Use Cases

### Use Case 1: AI Enemy Targeting Player
```gdscript
class_name S_EnemyAISystem

func process_tick(delta: float) -> void:
	var store = U_StateUtils.get_store(self)
	var player_pos = EntitySelectors.get_player_position(store.get_state())
	
	var entities = query_entities(["C_EnemyAIComponent"])
	for entity_query in entities:
		var ai_component = entity_query.get_component("C_EnemyAIComponent")
		var enemy_pos = ai_component.get_body().global_position
		
		# Use player position for targeting
		var direction = (player_pos - enemy_pos).normalized()
		ai_component.set_target_direction(direction)
```

### Use Case 2: UI Health Bars for All Entities
```gdscript
class_name EntityHealthBarsUI

func _process(_delta: float) -> void:
	var store = U_StateUtils.get_store(self)
	var all_entities = EntitySelectors.get_all_entities(store.get_state())
	
	for entity_id in all_entities.keys():
		var entity = all_entities[entity_id]
		var health = entity.get("health", 100)
		var position = entity.get("position", Vector3.ZERO)
		
		_update_health_bar(entity_id, health, position)
```

### Use Case 3: Proximity Query (Find Nearby Enemies)
```gdscript
# In any system
var store = U_StateUtils.get_store(self)
var player_pos = EntitySelectors.get_player_position(store.get_state())
var enemies = EntitySelectors.get_entities_by_type(store.get_state(), "enemy")

var nearby_enemies: Array = []
for enemy_entry in enemies:
	var enemy_pos = enemy_entry["data"].get("position", Vector3.ZERO)
	var distance = player_pos.distance_to(enemy_pos)
	if distance < 10.0:  # Within 10 units
		nearby_enemies.append(enemy_entry)
```

---

## Migration Plan (Phase 16 Refactoring)

### Step 1: Create New Infrastructure
- [ ] Create `U_EntityActions.gd`
- [ ] Create `EntitySelectors.gd`
- [ ] Update `GameplayReducer` with entity snapshot actions
- [ ] Update `RS_GameplayInitialState` with `entities: {}`

### Step 2: Refactor Systems
- [ ] Update `S_MovementSystem` to dispatch entity snapshots
- [ ] Update `S_JumpSystem` to dispatch entity snapshots
- [ ] Update `S_RotateToInputSystem` to dispatch entity snapshots
- [ ] Remove single-entity physics fields (position, velocity, rotation)

### Step 3: Update Existing Integrations
- [ ] Update `S_GravitySystem` (keep gravity_scale global, remove entity physics)
- [ ] Update `S_LandingIndicatorSystem` (can stay as-is, uses components)

### Step 4: Test & Validate
- [ ] Create test with multiple entities (player + 2 enemies)
- [ ] Verify entity snapshots appear in debug overlay
- [ ] Verify AI can read player position
- [ ] Run existing tests (should still pass)

### Step 5: Document & Commit
- [ ] Update usage guide with entity coordination pattern
- [ ] Add examples to ECS integration section
- [ ] Commit: "Phase 16: Entity Coordination Pattern (multi-entity support)"

---

## Design Decisions & Rationale

### Why Not Store Everything in State?
**Rejected Approach**: Make state store the source of truth for all entity data.

**Why Rejected**:
- ECS is designed for efficient per-entity iteration
- Components have better memory locality
- State store updates would create performance bottlenecks
- Violates separation of concerns (ECS for entities, state for game-wide)

### Why Entity Snapshots?
**Chosen Approach**: Periodic snapshots for coordination, components for truth.

**Rationale**:
- AI/UI reads are infrequent (not every frame)
- Snapshots provide "good enough" data for coordination
- Components remain fast for hot paths (physics, movement)
- Debug overlay benefits from consolidated view

### Why String IDs?
**Chosen Approach**: Use string identifiers (`"player"`, `"enemy_goblin_1"`).

**Rationale**:
- Readable in debug overlay
- Easy to serialize for save/load
- Natural mapping to node names
- Flexible (can use UUIDs later if needed)

### Update Frequency
**Decision**: Dispatch snapshots every frame during active movement.

**Rationale**:
- Modern games can handle ~100 entities @ 60fps
- Batch dispatch reduces overhead
- Immutable updates are fast (only changed fields)
- Can throttle later if needed (every 2-3 frames)

---

## Performance Considerations

### Snapshot Overhead
- Each entity snapshot: ~8-10 actions/frame (position, velocity, rotation, etc.)
- 10 entities = 80-100 dispatches/frame
- Current dispatch overhead: 3.5µs per dispatch
- Total: ~350µs/frame for 10 entities (acceptable at 60fps = 16.6ms budget)

### Optimization Opportunities
1. **Batch Dispatches**: Single action with all entity snapshots
2. **Delta Updates**: Only dispatch changed fields
3. **Throttling**: Update snapshots every 2-3 frames for non-critical entities
4. **Spatial Partitioning**: Only update entities near player

### When to Optimize
- ✅ Current: Works fine for 10-20 entities
- ⚠️ If >50 entities: Implement batching
- ⚠️ If frame drops: Implement throttling
- ⚠️ If memory pressure: Implement spatial culling

---

## Alternative Patterns Considered

### Pattern 1: Event Bus for Entity Updates
**Approach**: Publish entity updates via ECSEventBus instead of state store.

**Pros**: Lower overhead, no state duplication  
**Cons**: No time-travel debugging, no debug overlay visibility, ephemeral

**Verdict**: ❌ Rejected - loses state store benefits

### Pattern 2: Per-Frame Entity Queries
**Approach**: Systems query components directly when needed.

**Pros**: No state duplication, always fresh data  
**Cons**: Tight coupling, AI systems need ECS access, hard to debug

**Verdict**: ❌ Rejected - violates decoupling goals

### Pattern 3: Hybrid (Chosen)
**Approach**: Components = truth, state = coordination snapshots.

**Pros**: Best of both worlds, scalable, debuggable  
**Cons**: Slight overhead, eventual consistency

**Verdict**: ✅ **Chosen** - balances all concerns

---

## Testing Strategy

### Unit Tests
```gdscript
# Test entity snapshot dispatch
func test_entity_snapshot_action():
	var action = U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6)
	})
	assert_eq(action.type, "gameplay/UPDATE_ENTITY_SNAPSHOT")
	assert_eq(action.payload.entity_id, "player")

# Test reducer
func test_gameplay_reducer_entity_snapshot():
	var initial_state = {"entities": {}}
	var action = U_EntityActions.update_entity_snapshot("enemy_1", {
		"position": Vector3(10, 0, 10),
		"health": 50
	})
	var new_state = GameplayReducer.reduce(initial_state, action)
	assert_true(new_state.entities.has("enemy_1"))
	assert_eq(new_state.entities["enemy_1"].health, 50)

# Test selectors
func test_entity_selectors():
	var state = {
		"gameplay": {
			"entities": {
				"player": {"position": Vector3(1, 2, 3), "entity_type": "player"},
				"enemy_1": {"position": Vector3(10, 0, 10), "entity_type": "enemy"}
			}
		}
	}
	var player_pos = EntitySelectors.get_player_position(state)
	assert_eq(player_pos, Vector3(1, 2, 3))
	
	var enemies = EntitySelectors.get_entities_by_type(state, "enemy")
	assert_eq(enemies.size(), 1)
```

### Integration Tests
```gdscript
# Test multi-entity coordination
func test_multiple_entities_in_state():
	# Create player and 2 enemies
	# Verify all appear in state
	# Verify AI can read positions
	# Verify debug overlay shows all
```

---

## Future Enhancements

### 1. Batched Entity Updates
```gdscript
static func update_entities_batch(snapshots: Array) -> Dictionary:
	# Single action for multiple entities
```

### 2. Entity Filtering
```gdscript
static func get_entities_within_radius(state: Dictionary, center: Vector3, radius: float) -> Array
```

### 3. Entity Relationships
```gdscript
gameplay: {
	entities: {
		"player": { ... },
		"enemy_1": {
			...,
			"target_entity_id": "player",  # Relationship tracking
			"faction": "hostile"
		}
	}
}
```

### 4. Entity Lifecycle Events
```gdscript
# Automatic cleanup on entity despawn
func on_entity_despawned(entity_id: String):
	store.dispatch(U_EntityActions.remove_entity(entity_id))
```

---

## Conclusion

The **Entity Coordination Pattern** provides a scalable, performant solution for multi-entity games while maintaining proper ECS architecture. By treating the state store as a coordination layer rather than a source of truth, we get:

- ✅ Read-only access to entity data for AI/UI
- ✅ Proper ECS scalability (components = truth)
- ✅ Debug visibility across all entities
- ✅ Time-travel debugging for entity interactions
- ✅ Decoupling between systems

This pattern will guide Phase 16 refactoring and serve as a foundation for future multi-character features.

---

**Next Steps:**
1. Review this document with team/user
2. Implement Step 1 (infrastructure)
3. Migrate existing systems
4. Add multi-entity tests
5. Update usage guide

**Related Documents:**
- `redux-state-store-usage-guide.md` - Section 10 (ECS Integration)
- `redux-state-store-prd.md` - Original requirements
- `redux-state-store-tasks.md` - Phase 16 task list
