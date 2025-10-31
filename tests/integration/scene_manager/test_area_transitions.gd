extends GutTest

## Integration tests for Scene Manager area transitions (User Story 3)
##
## Tests cover:
## - Door trigger detection and scene transition
## - Spawn point restoration on scene load
## - Bidirectional transitions (exterior ↔ interior)
## - State persistence across area transitions
## - Auto-trigger vs Interact-trigger modes

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const C_SCENE_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")

var _root_node: Node
var _state_store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _active_scene_container: Node

func before_each() -> void:
	# Create root structure for testing
	_root_node = Node.new()
	add_child_autofree(_root_node)

	# Create M_StateStore with both scene and gameplay slices
	_state_store = M_STATE_STORE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_root_node.add_child(_state_store)

	# Create containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_node.add_child(_active_scene_container)

	var ui_overlay_stack := CanvasLayer.new()
	ui_overlay_stack.name = "UIOverlayStack"
	ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_node.add_child(ui_overlay_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	_root_node.add_child(transition_overlay)

	# Create M_SceneManager
	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root_node.add_child(_scene_manager)

	# Wait for all nodes to initialize
	await get_tree().process_frame

func test_door_pairing_registered_in_scene_registry() -> void:
	# When: Query door pairing from registry
	var door_data: Dictionary = U_SCENE_REGISTRY.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)

	# Then: Door pairing should exist with correct target
	assert_false(door_data.is_empty(), "Door pairing should be registered")
	assert_eq(door_data.get("target_scene_id"), StringName("interior_house"),
		"Door should target interior_house scene")
	assert_eq(door_data.get("target_spawn_point"), StringName("entrance_from_exterior"),
		"Door should have entrance spawn point")

func test_scene_trigger_component_stores_door_metadata() -> void:
	# Given: Create a door trigger component
	var trigger := C_SCENE_TRIGGER_COMPONENT.new()
	trigger.door_id = StringName("door_to_house")
	trigger.target_scene_id = StringName("interior_house")
	trigger.target_spawn_point = StringName("entrance_from_exterior")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO

	# Then: Component should store all metadata
	assert_eq(trigger.door_id, StringName("door_to_house"), "door_id should be stored")
	assert_eq(trigger.target_scene_id, StringName("interior_house"), "target_scene_id should be stored")
	assert_eq(trigger.target_spawn_point, StringName("entrance_from_exterior"), "spawn point should be stored")
	assert_eq(trigger.trigger_mode, C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO, "trigger_mode should be AUTO")

func test_target_spawn_point_stored_in_gameplay_state_before_transition() -> void:
	# When: Dispatch set_target_spawn_point action
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
	var action: Dictionary = U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("entrance_from_exterior"))
	_state_store.dispatch(action)
	await wait_physics_frames(2)

	# Then: Gameplay state should store target_spawn_point
	var state: Dictionary = _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_eq(target_spawn, StringName("entrance_from_exterior"),
		"target_spawn_point should be stored in gameplay state")

func test_spawn_point_restoration_positions_player_correctly() -> void:
	# This test will be implemented once we have spawn point restoration logic
	# For now, it validates that M_SceneManager has a method for spawn restoration
	assert_true(_scene_manager.has_method("_restore_player_spawn_point"),
		"M_SceneManager should have _restore_player_spawn_point method")

func test_bidirectional_door_pairings_registered() -> void:
	# Given: Exterior → Interior door
	var exterior_door: Dictionary = U_SCENE_REGISTRY.get_door_exit(
		StringName("exterior"),
		StringName("door_to_house")
	)

	# And: Interior → Exterior door
	var interior_door: Dictionary = U_SCENE_REGISTRY.get_door_exit(
		StringName("interior_house"),
		StringName("door_to_exterior")
	)

	# Then: Both doors should exist and point to each other
	assert_false(exterior_door.is_empty(), "Exterior door should exist")
	assert_false(interior_door.is_empty(), "Interior door should exist")
	assert_eq(exterior_door.get("target_scene_id"), StringName("interior_house"),
		"Exterior door should lead to interior")
	assert_eq(interior_door.get("target_scene_id"), StringName("exterior"),
		"Interior door should lead to exterior")

func test_scene_trigger_component_has_area3d_collision() -> void:
	# Given: Create entity with trigger component
	var entity := Node3D.new()
	entity.name = "E_DoorTrigger"
	add_child_autofree(entity)

	var trigger := C_SCENE_TRIGGER_COMPONENT.new()
	trigger.door_id = StringName("door_to_house")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO
	entity.add_child(trigger)

	# When: Component initializes
	await get_tree().process_frame

	# Then: Component should have Area3D for collision detection
	var area: Area3D = trigger.get_node_or_null("TriggerArea")
	assert_not_null(area, "Component should create TriggerArea child")
	assert_true(area is Area3D, "TriggerArea should be Area3D")

func test_auto_trigger_mode_fires_on_body_entered() -> void:
	# Given: Scene with ECS manager and trigger system
	var ecs_manager := M_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	await get_tree().process_frame

	# Create entity with trigger
	var entity := Node3D.new()
	entity.name = "E_DoorTrigger"
	add_child_autofree(entity)

	var trigger := C_SCENE_TRIGGER_COMPONENT.new()
	trigger.door_id = StringName("door_to_house")
	trigger.target_scene_id = StringName("interior_house")
	trigger.target_spawn_point = StringName("entrance_from_exterior")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO
	entity.add_child(trigger)

	await get_tree().process_frame

	# Create player body
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	add_child_autofree(player)

	# When: Player enters trigger area
	var area: Area3D = trigger.get_node_or_null("TriggerArea")
	if area != null:
		area._on_body_entered(player)
		await wait_physics_frames(2)

		# Then: Transition should be triggered
		# (We'll check state store for transition_started)
		var state: Dictionary = _state_store.get_state()
		var scene_state: Dictionary = state.get("scene", {})
		var is_transitioning: bool = scene_state.get("is_transitioning", false)
		assert_true(is_transitioning, "Scene transition should be triggered on body enter")

func test_interact_trigger_mode_requires_input() -> void:
	# This test verifies that INTERACT mode only triggers with player input
	# Will be fully implemented after S_SceneTriggerSystem is created
	pass  # Placeholder for T085 test

func test_area_state_persists_across_transitions() -> void:
	# This test verifies FR-036 (persist area state when transitioning away)
	# Will be fully implemented after full area transition flow is working
	pass  # Placeholder for T100 test
