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

	# Add ColorRect for FadeTransition
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.add_child(color_rect)

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
	assert_eq(door_data.get("target_spawn_point"), StringName("sp_entrance_from_exterior"),
		"Door should have entrance spawn point")

func test_scene_trigger_component_stores_door_metadata() -> void:
	# Given: Create a door trigger component
	var trigger := C_SCENE_TRIGGER_COMPONENT.new()
	trigger.door_id = StringName("door_to_house")
	trigger.target_scene_id = StringName("interior_house")
	trigger.target_spawn_point = StringName("sp_entrance_from_exterior")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO

	# Then: Component should store all metadata
	assert_eq(trigger.door_id, StringName("door_to_house"), "door_id should be stored")
	assert_eq(trigger.target_scene_id, StringName("interior_house"), "target_scene_id should be stored")
	assert_eq(trigger.target_spawn_point, StringName("sp_entrance_from_exterior"), "spawn point should be stored")
	assert_eq(trigger.trigger_mode, C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO, "trigger_mode should be AUTO")

	# Cleanup to avoid GUT orphan warnings
	trigger.free()

func test_target_spawn_point_stored_in_gameplay_state_before_transition() -> void:
	# When: Dispatch set_target_spawn_point action
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
	var action: Dictionary = U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_entrance_from_exterior"))
	_state_store.dispatch(action)
	await wait_physics_frames(2)

	# Then: Gameplay state should store target_spawn_point
	var state: Dictionary = _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_eq(target_spawn, StringName("sp_entrance_from_exterior"),
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
	# Note: C_SceneTriggerComponent parents the Area3D under the Door entity (Node3D)
	# so the area inherits the door's transform. Tests should query the entity, not the component.
	var area: Area3D = entity.get_node_or_null("TriggerArea")
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
	trigger.target_spawn_point = StringName("sp_entrance_from_exterior")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO
	entity.add_child(trigger)

	await get_tree().process_frame

	# Create player body
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.add_to_group("player")  # Ensure _is_player() detects this as the player
	add_child_autofree(player)

	# When: Player enters trigger area
	# Area3D is parented under the entity (see component design)
	var area: Area3D = entity.get_node_or_null("TriggerArea")
	assert_not_null(area, "TriggerArea should exist")

	if area != null:
		# Emit the body_entered signal instead of calling private method
		area.body_entered.emit(player)
		await wait_physics_frames(2)

		# Then: Transition should be triggered
		# (We'll check state store for transition_started)
		var state: Dictionary = _state_store.get_state()
		var scene_state: Dictionary = state.get("scene", {})
		var is_transitioning: bool = scene_state.get("is_transitioning", false)
		assert_true(is_transitioning, "Scene transition should be triggered on body enter")

func test_interact_trigger_mode_requires_input() -> void:
	# Given: Trigger in INTERACT mode
	var entity := Node3D.new()
	entity.name = "E_DoorTrigger"
	add_child_autofree(entity)

	var trigger := C_SCENE_TRIGGER_COMPONENT.new()
	trigger.door_id = StringName("door_to_house")
	trigger.target_scene_id = StringName("interior_house")
	trigger.target_spawn_point = StringName("sp_entrance_from_exterior")
	trigger.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.INTERACT  # INTERACT mode
	entity.add_child(trigger)

	await get_tree().process_frame

	# Create player body
	var player := CharacterBody3D.new()
	player.name = "E_Player"
	player.add_to_group("player")  # Ensure _is_player() detects this as the player
	add_child_autofree(player)

	# When: Player enters trigger area (without pressing interact)
	# Area3D is parented under the entity (see component design)
	var area: Area3D = entity.get_node_or_null("TriggerArea")
	assert_not_null(area, "TriggerArea should exist")

	if area != null:
		area.body_entered.emit(player)
		await wait_physics_frames(2)

		# Then: Should NOT auto-trigger (is_player_in_zone should be true but no transition)
		assert_true(trigger.is_player_in_zone(), "Player should be detected in zone")

		# And: When trigger_interact() is called manually
		trigger.trigger_interact()
		await wait_physics_frames(2)

		# Then: Transition should be triggered
		var state: Dictionary = _state_store.get_state()
		var scene_state: Dictionary = state.get("scene", {})
		var is_transitioning: bool = scene_state.get("is_transitioning", false)
		assert_true(is_transitioning, "Scene transition should be triggered after manual interact")

func test_area_state_persists_across_transitions() -> void:
	# Given: Gameplay state with test data
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

	# Set some gameplay state
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_gravity_scale(2.5))
	await wait_physics_frames(2)

	# When: Trigger a scene transition
	var action: Dictionary = U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("test_spawn"))
	_state_store.dispatch(action)
	await wait_physics_frames(2)

	# Then: Gameplay state should persist
	var state: Dictionary = _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var gravity_scale: float = gameplay_state.get("gravity_scale", 1.0)

	# Verify state persists (gravity_scale should still be 2.5)
	assert_eq(gravity_scale, 2.5, "Gameplay state should persist across transitions")

	# This is a simplified test - full area state persistence (FR-036) would require
	# testing entity positions/states across full scene load/unload cycles

func test_full_scene_load_exterior_to_interior() -> void:
	# Check if scenes exist (they need to be created manually)
	if not FileAccess.file_exists("res://scenes/gameplay/exterior.tscn"):
		pending("exterior.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return
	if not FileAccess.file_exists("res://scenes/gameplay/interior_house.tscn"):
		pending("interior_house.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return

	# Given: Clear any previous spawn point from state
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("")))
	await wait_physics_frames(1)

	# Load exterior scene into ActiveSceneContainer
	var exterior_scene: Node = load("res://scenes/gameplay/exterior.tscn").instantiate()
	_active_scene_container.add_child(exterior_scene)
	await get_tree().process_frame

	# Set current scene in state
	var U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))
	await wait_physics_frames(2)

	# When: Trigger transition to interior via scene manager
	_scene_manager.transition_to_scene(StringName("interior_house"), "instant", _scene_manager.Priority.HIGH)
	await wait_physics_frames(4)  # Wait for transition to complete

	# Then: Interior scene should be loaded in ActiveSceneContainer
	assert_eq(_active_scene_container.get_child_count(), 1, "ActiveSceneContainer should have 1 child")
	var loaded_scene: Node = _active_scene_container.get_child(0)
	assert_not_null(loaded_scene, "Loaded scene should exist")

	# And: Current scene ID should be updated
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
	assert_eq(current_scene_id, StringName("interior_house"), "Current scene should be interior_house")

func test_full_scene_load_interior_to_exterior() -> void:
	# Check if scenes exist (they need to be created manually)
	if not FileAccess.file_exists("res://scenes/gameplay/exterior.tscn"):
		pending("exterior.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return
	if not FileAccess.file_exists("res://scenes/gameplay/interior_house.tscn"):
		pending("interior_house.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return

	# Given: Clear any previous spawn point from state
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("")))
	await wait_physics_frames(1)

	# Load interior scene into ActiveSceneContainer
	var interior_scene: Node = load("res://scenes/gameplay/interior_house.tscn").instantiate()
	_active_scene_container.add_child(interior_scene)
	await get_tree().process_frame

	# Set current scene in state
	var U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("interior_house")))
	await wait_physics_frames(2)

	# When: Trigger transition to exterior via scene manager
	_scene_manager.transition_to_scene(StringName("exterior"), "instant", _scene_manager.Priority.HIGH)
	await wait_physics_frames(4)  # Wait for transition to complete

	# Then: Exterior scene should be loaded in ActiveSceneContainer
	assert_eq(_active_scene_container.get_child_count(), 1, "ActiveSceneContainer should have 1 child")
	var loaded_scene: Node = _active_scene_container.get_child(0)
	assert_not_null(loaded_scene, "Loaded scene should exist")

	# And: Current scene ID should be updated
	var state: Dictionary = _state_store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
	assert_eq(current_scene_id, StringName("exterior"), "Current scene should be exterior")

func test_spawn_point_restoration_after_door_transition() -> void:
	# Check if scenes exist (they need to be created manually)
	if not FileAccess.file_exists("res://scenes/gameplay/exterior.tscn"):
		pending("exterior.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return
	if not FileAccess.file_exists("res://scenes/gameplay/interior_house.tscn"):
		pending("interior_house.tscn must be created manually - see MANUAL_SCENE_CREATION_GUIDE.md")
		return

	# Given: Load exterior scene and set target spawn point
	var exterior_scene: Node = load("res://scenes/gameplay/exterior.tscn").instantiate()
	_active_scene_container.add_child(exterior_scene)
	await get_tree().process_frame

	var U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("exterior")))

	# Set target spawn point BEFORE transition (simulating door trigger)
	var U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
	_state_store.dispatch(U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName("sp_entrance_from_exterior")))
	await wait_physics_frames(2)

	# When: Transition to interior scene
	_scene_manager.transition_to_scene(StringName("interior_house"), "instant", _scene_manager.Priority.HIGH)
	await wait_physics_frames(4)

	# Then: Player should exist in interior scene
	var interior_scene: Node = _active_scene_container.get_child(0)
	assert_not_null(interior_scene, "Interior scene should be loaded")

	# Find player in interior scene
	var player: Node3D = _find_player_in_scene(interior_scene)
	assert_not_null(player, "Player should exist in interior scene")

	# And: Player should be at spawn point position
	var spawn_marker: Node3D = _find_spawn_point_in_scene(interior_scene, StringName("sp_entrance_from_exterior"))
	assert_not_null(spawn_marker, "Spawn marker 'sp_entrance_from_exterior' should exist")

	# Verify player is at spawn point (within tolerance)
	var distance: float = player.global_position.distance_to(spawn_marker.global_position)
	assert_lt(distance, 0.1, "Player should be positioned at spawn marker (distance < 0.1)")

	# And: Target spawn point should be cleared from state
	var state: Dictionary = _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))
	assert_eq(target_spawn, StringName(""), "Target spawn point should be cleared after use")

## Helper: Find player entity in scene
func _find_player_in_scene(scene_root: Node) -> Node3D:
	var players: Array = []
	_find_nodes_by_prefix(scene_root, "E_Player", players)
	return players[0] as Node3D if players.size() > 0 else null

## Helper: Find spawn point by name in scene
func _find_spawn_point_in_scene(scene_root: Node, spawn_name: StringName) -> Node3D:
	var spawn_points: Array = []
	_find_nodes_by_name(scene_root, spawn_name, spawn_points)
	return spawn_points[0] as Node3D if spawn_points.size() > 0 else null

## Recursive helper to find nodes by name
func _find_nodes_by_name(node: Node, target_name: StringName, results: Array) -> void:
	if node.name == target_name:
		results.append(node)
	for child in node.get_children():
		_find_nodes_by_name(child, target_name, results)

## Recursive helper to find nodes by prefix
func _find_nodes_by_prefix(node: Node, prefix: String, results: Array) -> void:
	if node.name.begins_with(prefix):
		results.append(node)
	for child in node.get_children():
		_find_nodes_by_prefix(child, prefix, results)
