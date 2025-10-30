@icon("res://resources/editor_icons/manager.svg")
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
const M_CursorManager = preload("res://scripts/managers/m_cursor_manager.gd")
const U_SceneActions = preload("res://scripts/state/actions/u_scene_actions.gd")
const SceneRegistry = preload("res://scripts/scene_management/scene_registry.gd")
const InstantTransition = preload("res://scripts/scene_management/transitions/instant_transition.gd")
const FadeTransition = preload("res://scripts/scene_management/transitions/fade_transition.gd")

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
var _cursor_manager: M_CursorManager = null
var _active_scene_container: Node = null
var _ui_overlay_stack: CanvasLayer = null
var _transition_overlay: CanvasLayer = null

## Transition queue
var _transition_queue: Array[TransitionRequest] = []
var _is_processing_transition: bool = false

## Current scene tracking for reactive cursor updates
var _current_scene_id: StringName = StringName("")

## Store subscription
var _unsubscribe: Callable

## Skip initial scene load (for tests)
var skip_initial_scene_load: bool = false

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

	# Find M_CursorManager via group
	var cursor_managers: Array = get_tree().get_nodes_in_group("cursor_manager")
	if cursor_managers.size() > 0:
		_cursor_manager = cursor_managers[0] as M_CursorManager
	else:
		push_warning("M_SceneManager: No M_CursorManager found in 'cursor_manager' group")

	# Find container nodes
	_find_container_nodes()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)

	# Validate SceneRegistry door pairings
	if not SceneRegistry.validate_door_pairings():
		push_error("M_SceneManager: SceneRegistry door pairing validation failed")

	# Load initial scene (main_menu) unless skipped for tests
	if not skip_initial_scene_load:
		_load_initial_scene()

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
func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	# Detect scene changes and update cursor reactively
	var scene_state: Dictionary = state.get("scene", {})
	var new_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))

	# Only update cursor when scene_id actually changes and is not empty
	if new_scene_id != _current_scene_id and not new_scene_id.is_empty():
		_current_scene_id = new_scene_id
		_update_cursor_for_scene(new_scene_id)

## Load initial scene on startup
func _load_initial_scene() -> void:
	# Load main_menu as the initial scene
	transition_to_scene(StringName("main_menu"), "instant", Priority.CRITICAL)

## Transition to a new scene
func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = Priority.NORMAL) -> void:
	# Validate scene exists in registry
	var scene_data: Dictionary = SceneRegistry.get_scene(scene_id)
	if scene_data.is_empty():
		# Silently ignore missing scenes (graceful handling)
		print_debug("M_SceneManager: Scene '%s' not found in SceneRegistry" % scene_id)
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

	# Create transition effect based on type
	var transition_effect = _create_transition_effect(request.transition_type)

	# Track if scene swap has completed (use Array for closure to work)
	var scene_swap_complete: Array = [false]

	# Define scene swap callback (called at mid-transition for fades, immediately for instant)
	var scene_swap_callback := func() -> void:
		# Remove current scene from ActiveSceneContainer
		if _active_scene_container != null:
			_remove_current_scene()

		# Load new scene
		var new_scene: Node = _load_scene(scene_path)
		if new_scene == null:
			push_error("M_SceneManager: Failed to load scene '%s'" % scene_path)
			return

		# Add new scene to ActiveSceneContainer
		if _active_scene_container != null:
			_add_scene(new_scene)

		scene_swap_complete[0] = true

	# Track if transition has fully completed (use Array for closure to work)
	var transition_complete: Array = [false]

	# Define completion callback
	var completion_callback := func() -> void:
		transition_complete[0] = true

	# Execute transition effect
	if transition_effect != null:
		# For fade transitions, set mid-transition callback for scene swap
		if transition_effect is FadeTransition:
			(transition_effect as FadeTransition).mid_transition_callback = scene_swap_callback
			transition_effect.execute(_transition_overlay, completion_callback)
		else:
			# For instant transitions, scene swap happens in completion callback
			transition_effect.execute(_transition_overlay, func() -> void:
				scene_swap_callback.call()
				completion_callback.call()
			)
	else:
		# Fallback: instant scene swap if no transition effect
		scene_swap_callback.call()
		completion_callback.call()

	# Wait for transition to complete
	while not transition_complete[0]:
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

## Update cursor state based on scene type
func _update_cursor_for_scene(scene_id: StringName) -> void:
	if _cursor_manager == null:
		return

	var scene_data: Dictionary = SceneRegistry.get_scene(scene_id)
	if scene_data.is_empty():
		return

	var scene_type: int = scene_data.get("scene_type", SceneRegistry.SceneType.GAMEPLAY)

	# UI/Menu/End-game scenes: cursor visible + unlocked
	# Gameplay scenes: cursor hidden + locked
	match scene_type:
		SceneRegistry.SceneType.MENU, SceneRegistry.SceneType.UI, SceneRegistry.SceneType.END_GAME:
			_cursor_manager.set_cursor_state(false, true)  # unlocked, visible
		SceneRegistry.SceneType.GAMEPLAY:
			_cursor_manager.set_cursor_state(true, false)  # locked, hidden

## Create transition effect based on type
func _create_transition_effect(transition_type: String):
	match transition_type.to_lower():
		"instant":
			return InstantTransition.new()
		"fade":
			var fade := FadeTransition.new()
			fade.duration = 0.2  # Shorter duration for faster tests
			return fade
		_:
			# Unknown type, use instant as fallback
			push_warning("M_SceneManager: Unknown transition type '%s', using instant" % transition_type)
			return InstantTransition.new()
