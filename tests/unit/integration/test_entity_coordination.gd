extends GutTest

## Test Entity Coordination Pattern
##
## Phase 16: Verify entity snapshots work correctly
## Tests multi-entity support, entity selectors, and coordination

var store: M_StateStore

func before_each() -> void:
	# Clear any state handoff from previous tests
	StateHandoff.clear_all()
	
	store = M_StateStore.new()
	# Initialize gameplay slice with initial state
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child_autofree(store)
	await wait_physics_frames(2)

func after_each() -> void:
	store = null

## Test dispatching entity snapshots
func test_update_entity_snapshot():
	var action = U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6),
		"entity_type": "player"
	})
	store.dispatch(action)
	await wait_physics_frames(1)
	
	var state = store.get_state()
	var entities = state.get("gameplay", {}).get("entities", {})
	assert_true(entities.has("player"), "Should have player entity")
	assert_eq(entities["player"]["position"], Vector3(1, 2, 3), "Position should match")
	assert_eq(entities["player"]["velocity"], Vector3(4, 5, 6), "Velocity should match")
	assert_eq(entities["player"]["entity_type"], "player", "Entity type should match")

## Test merging entity snapshots (preserves existing fields)
func test_merge_entity_snapshot():
	# First snapshot
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(1, 2, 3),
		"health": 100,
		"entity_type": "player"
	}))
	await wait_frames(1)
	
	# Second snapshot (only updates position)
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(10, 20, 30)
	}))
	await wait_frames(1)
	
	var state = store.get_state()
	var player = U_EntitySelectors.get_entity(state, "player")
	assert_eq(player["position"], Vector3(10, 20, 30), "Position should be updated")
	assert_eq(player["health"], 100, "Health should be preserved")
	assert_eq(player["entity_type"], "player", "Entity type should be preserved")

## Test multiple entities
func test_multiple_entities():
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(0, 0, 0),
		"entity_type": "player"
	}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_1", {
		"position": Vector3(10, 0, 10),
		"entity_type": "enemy"
	}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_2", {
		"position": Vector3(-10, 0, -10),
		"entity_type": "enemy"
	}))
	await wait_frames(1)
	
	var state = store.get_state()
	var all_entities = U_EntitySelectors.get_all_entities(state)
	assert_eq(all_entities.size(), 3, "Should have 3 entities")
	assert_true(all_entities.has("player"), "Should have player")
	assert_true(all_entities.has("enemy_1"), "Should have enemy_1")
	assert_true(all_entities.has("enemy_2"), "Should have enemy_2")

## Test entity selectors
func test_entity_selectors():
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(1, 2, 3),
		"velocity": Vector3(4, 5, 6),
		"rotation": Vector3(0, 1.57, 0),
		"is_on_floor": true,
		"is_moving": true,
		"entity_type": "player",
		"health": 100
	}))
	await wait_frames(1)
	
	var state = store.get_state()
	assert_eq(U_EntitySelectors.get_entity_position(state, "player"), Vector3(1, 2, 3))
	assert_eq(U_EntitySelectors.get_entity_velocity(state, "player"), Vector3(4, 5, 6))
	assert_eq(U_EntitySelectors.get_entity_rotation(state, "player"), Vector3(0, 1.57, 0))
	assert_true(U_EntitySelectors.is_entity_on_floor(state, "player"))
	assert_true(U_EntitySelectors.is_entity_moving(state, "player"))
	assert_eq(U_EntitySelectors.get_entity_type(state, "player"), "player")
	assert_eq(U_EntitySelectors.get_entity_health(state, "player"), 100)

## Test get entities by type
func test_get_entities_by_type():
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {"entity_type": "player"}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_1", {"entity_type": "enemy"}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_2", {"entity_type": "enemy"}))
	store.dispatch(U_EntityActions.update_entity_snapshot("npc_1", {"entity_type": "npc"}))
	await wait_frames(1)
	
	var state = store.get_state()
	var enemies = U_EntitySelectors.get_entities_by_type(state, "enemy")
	assert_eq(enemies.size(), 2, "Should have 2 enemies")
	
	var npcs = U_EntitySelectors.get_entities_by_type(state, "npc")
	assert_eq(npcs.size(), 1, "Should have 1 NPC")

## Test player convenience selectors
func test_player_convenience_selectors():
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(5, 10, 15),
		"velocity": Vector3(1, 0, 1),
		"entity_type": "player"
	}))
	await wait_frames(1)
	
	var state = store.get_state()
	assert_eq(U_EntitySelectors.get_player_entity_id(state), "player")
	assert_eq(U_EntitySelectors.get_player_position(state), Vector3(5, 10, 15))
	assert_eq(U_EntitySelectors.get_player_velocity(state), Vector3(1, 0, 1))

## Test get entities within radius
func test_get_entities_within_radius():
	store.dispatch(U_EntityActions.update_entity_snapshot("player", {
		"position": Vector3(0, 0, 0),
		"entity_type": "player"
	}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_close", {
		"position": Vector3(5, 0, 0),  # 5 units away
		"entity_type": "enemy"
	}))
	store.dispatch(U_EntityActions.update_entity_snapshot("enemy_far", {
		"position": Vector3(50, 0, 0),  # 50 units away
		"entity_type": "enemy"
	}))
	await wait_physics_frames(1)
	
	var state = store.get_state()
	var nearby = U_EntitySelectors.get_entities_within_radius(state, Vector3.ZERO, 10.0)
	assert_eq(nearby.size(), 2, "Should find player + close enemy within 10 units")
	
	var very_close = U_EntitySelectors.get_entities_within_radius(state, Vector3.ZERO, 3.0)
	assert_eq(very_close.size(), 1, "Should only find player within 3 units")

## Test remove entity
func test_remove_entity():
	store.dispatch(U_EntityActions.update_entity_snapshot("temp_entity", {
		"position": Vector3(1, 2, 3),
		"entity_type": "temp"
	}))
	await wait_frames(1)
	
	var state = store.get_state()
	assert_true(U_EntitySelectors.get_all_entities(state).has("temp_entity"), "Entity should exist")
	
	store.dispatch(U_EntityActions.remove_entity("temp_entity"))
	await wait_frames(1)
	
	state = store.get_state()
	assert_false(U_EntitySelectors.get_all_entities(state).has("temp_entity"), "Entity should be removed")

## Test entity physics convenience method
func test_entity_physics_convenience():
	var action = U_EntityActions.update_entity_physics(
		"player",
		Vector3(1, 2, 3),      # position
		Vector3(4, 5, 6),      # velocity
		Vector3(0, 1.57, 0),   # rotation
		true,                   # is_on_floor
		true                    # is_moving
	)
	store.dispatch(action)
	await wait_physics_frames(1)
	
	var state = store.get_state()
	var player = U_EntitySelectors.get_entity(state, "player")
	assert_eq(player["position"], Vector3(1, 2, 3))
	assert_eq(player["velocity"], Vector3(4, 5, 6))
	assert_eq(player["rotation"], Vector3(0, 1.57, 0))
	assert_true(player["is_on_floor"])
	assert_true(player["is_moving"])
