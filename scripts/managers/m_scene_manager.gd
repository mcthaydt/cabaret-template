extends Node
class_name M_SceneManager

## Scene Manager - Coordinates scene transitions and overlays
##
## Responsibilities:
## - Manage transition queue with priorities
## - Load/unload scenes from ActiveSceneContainer
## - Manage UI overlay stack
## - Dispatch scene actions to M_StateStore
## - Subscribe to scene state changes
##
## Discovery: Add to "scene_manager" group, discoverable via get_tree().get_nodes_in_group()

const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const U_SceneActions = preload("res://scripts/state/u_scene_actions.gd")
const SceneRegistry = preload("res://scripts/scene_management/scene_registry.gd")

## Priority enum for transition queue
enum Priority {
	NORMAL = 0,   # Standard transitions
	HIGH = 1,     # User-initiated transitions (back button)
	CRITICAL = 2  # System-critical transitions (error, death)
}

## Transition request structure
class TransitionRequest:
	var scene_id: StringName
	var transition_type: String
	var priority: int

	func _init(p_scene_id: StringName, p_transition_type: String, p_priority: int) -> void:
		scene_id = p_scene_id
		transition_type = p_transition_type
		priority = p_priority

## Internal references
var _store: M_StateStore = null
var _active_scene_container: Node = null
var _ui_overlay_stack: CanvasLayer = null
var _transition_overlay: CanvasLayer = null

## Transition queue
var _transition_queue: Array[TransitionRequest] = []
var _is_processing_transition: bool = false

## Store subscription
var _unsubscribe: Callable

func _ready() -> void:
	# Add to scene_manager group for discovery
	add_to_group("scene_manager")

	# Find M_StateStore via group
	await get_tree().process_frame  # Wait for store to register
	var stores: Array = get_tree().get_nodes_in_group("state_store")
	if stores.size() > 0:
		_store = stores[0] as M_StateStore
	else:
		push_error("M_SceneManager: No M_StateStore found in 'state_store' group")
		return

	# Find container nodes
	_find_container_nodes()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)

	# Validate SceneRegistry door pairings
	if not SceneRegistry.validate_door_pairings():
		push_error("M_SceneManager: SceneRegistry door pairing validation failed")

func _exit_tree() -> void:
	# Unsubscribe from state updates
	if _unsubscribe != null and _unsubscribe.is_valid():
		_unsubscribe.call()

## Find container nodes in the scene tree
func _find_container_nodes() -> void:
	var root: Node = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

	# Find ActiveSceneContainer
	_active_scene_container = root.find_child("ActiveSceneContainer", true, false)
	if _active_scene_container == null:
		push_error("M_SceneManager: ActiveSceneContainer not found")

	# Find UIOverlayStack
	_ui_overlay_stack = root.find_child("UIOverlayStack", true, false)
	if _ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found")

	# Find TransitionOverlay
	_transition_overlay = root.find_child("TransitionOverlay", true, false)
	if _transition_overlay == null:
		push_error("M_SceneManager: TransitionOverlay not found")

## State change callback
func _on_state_changed(_action: Dictionary, _state: Dictionary) -> void:
	# React to scene state changes if needed
	# For now, this is a placeholder for future reactivity
	pass

## Transition to a new scene
func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = Priority.NORMAL) -> void:
	# Validate scene exists in registry
	var scene_data: Dictionary = SceneRegistry.get_scene(scene_id)
	if scene_data.is_empty():
		push_warning("M_SceneManager: Scene '%s' not found in SceneRegistry" % scene_id)
		return

	# Create transition request
	var request := TransitionRequest.new(scene_id, transition_type, priority)

	# Add to queue based on priority
	_enqueue_transition(request)

	# Process queue if not already processing
	if not _is_processing_transition:
		_process_transition_queue()

## Enqueue transition based on priority
func _enqueue_transition(request: TransitionRequest) -> void:
	# Insert based on priority (higher priority = earlier in queue)
	var insert_index: int = _transition_queue.size()

	for i in range(_transition_queue.size()):
		if request.priority > _transition_queue[i].priority:
			insert_index = i
			break

	_transition_queue.insert(insert_index, request)

## Process transition queue
func _process_transition_queue() -> void:
	if _transition_queue.is_empty():
		_is_processing_transition = false
		return

	_is_processing_transition = true

	# Get next transition from queue
	var request: TransitionRequest = _transition_queue.pop_front()

	# Dispatch transition started action
	if _store != null:
		_store.dispatch(U_SceneActions.transition_started(
			request.scene_id,
			request.transition_type
		))

	# Perform transition
	await _perform_transition(request)

	# Dispatch transition completed action
	if _store != null:
		_store.dispatch(U_SceneActions.transition_completed(request.scene_id))

	# Process next transition in queue
	await get_tree().physics_frame
	_process_transition_queue()

## Perform the actual scene transition
func _perform_transition(request: TransitionRequest) -> void:
	# Get scene path from registry
	var scene_path: String = SceneRegistry.get_scene_path(request.scene_id)
	if scene_path.is_empty():
		push_error("M_SceneManager: No path for scene '%s'" % request.scene_id)
		return

	# Remove current scene from ActiveSceneContainer
	if _active_scene_container != null:
		_remove_current_scene()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Load new scene
	var new_scene: Node = _load_scene(scene_path)
	if new_scene == null:
		push_error("M_SceneManager: Failed to load scene '%s'" % scene_path)
		return

	# Add new scene to ActiveSceneContainer
	if _active_scene_container != null:
		_add_scene(new_scene)

	# Wait for scene to initialize
	await get_tree().process_frame

## Remove current scene from ActiveSceneContainer
func _remove_current_scene() -> void:
	if _active_scene_container == null:
		return

	# Remove all children from active scene container
	for child in _active_scene_container.get_children():
		_active_scene_container.remove_child(child)
		child.queue_free()

## Load scene via ResourceLoader (sync for now)
func _load_scene(scene_path: String) -> Node:
	# Use ResourceLoader for synchronous loading
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("M_SceneManager: Failed to load PackedScene at '%s'" % scene_path)
		return null

	var instance: Node = packed_scene.instantiate()
	return instance

## Add scene to ActiveSceneContainer
func _add_scene(scene: Node) -> void:
	if _active_scene_container == null:
		return

	_active_scene_container.add_child(scene)

## Push overlay scene onto UIOverlayStack
func push_overlay(scene_id: StringName) -> void:
	# Dispatch push overlay action
	if _store != null:
		_store.dispatch(U_SceneActions.push_overlay(scene_id))

	# Load and add overlay scene
	var scene_path: String = SceneRegistry.get_scene_path(scene_id)
	if scene_path.is_empty():
		push_warning("M_SceneManager: Scene '%s' not found for overlay" % scene_id)
		return

	var overlay_scene: Node = _load_scene(scene_path)
	if overlay_scene == null:
		push_error("M_SceneManager: Failed to load overlay scene '%s'" % scene_id)
		return

	if _ui_overlay_stack != null:
		_ui_overlay_stack.add_child(overlay_scene)

## Pop top overlay from UIOverlayStack
func pop_overlay() -> void:
	if _ui_overlay_stack == null:
		return

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return  # Nothing to pop

	# Dispatch pop overlay action
	if _store != null:
		_store.dispatch(U_SceneActions.pop_overlay())

	# Remove top overlay
	var top_overlay: Node = _ui_overlay_stack.get_child(overlay_count - 1)
	_ui_overlay_stack.remove_child(top_overlay)
	top_overlay.queue_free()

## Get current scene ID from state
func get_current_scene() -> StringName:
	if _store == null:
		return StringName("")

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	return scene_state.get("current_scene_id", StringName(""))

## Check if currently transitioning
func is_transitioning() -> bool:
	if _store == null:
		return false

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	return scene_state.get("is_transitioning", false)
