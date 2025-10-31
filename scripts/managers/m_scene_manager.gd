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

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const INSTANT_TRANSITION := preload("res://scripts/scene_management/transitions/instant_transition.gd")
const FADE_TRANSITION := preload("res://scripts/scene_management/transitions/fade_transition.gd")

const OVERLAY_META_SCENE_ID := StringName("_scene_manager_overlay_scene_id")

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

## Scene history tracking for UI navigation (T109)
## Only tracks UI/Menu scenes, cleared when entering gameplay
var _scene_history: Array[StringName] = []

## Pending return info for settings opened from pause
var _pending_return_scene_id: StringName = StringName("")
var _pending_overlay_after_transition: StringName = StringName("")

## Store subscription
var _unsubscribe: Callable

## Skip initial scene load (for tests)
var skip_initial_scene_load: bool = false

## Initial scene to load on startup (configurable for testing)
@export var initial_scene_id: StringName = StringName("main_menu")

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
	_sync_overlay_stack_state()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)

	# Validate U_SceneRegistry door pairings
	if not U_SCENE_REGISTRY.validate_door_pairings():
		push_error("M_SceneManager: U_SceneRegistry door pairing validation failed")

	# Load initial scene (main_menu) unless skipped for tests
	if not skip_initial_scene_load:
		_load_initial_scene()

func _exit_tree() -> void:
	# Unsubscribe from state updates
	if _unsubscribe != null and _unsubscribe.is_valid():
		_unsubscribe.call()

## Input handler for ESC pause trigger (T117)
func _input(event: InputEvent) -> void:
	# Check for ESC key to trigger pause
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and key_event.pressed and not key_event.is_echo():
			# Only pause if in gameplay scene and no overlays active
			var scene_type: int = _get_current_scene_type()
			if scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY and _ui_overlay_stack.get_child_count() == 0:
				push_overlay(StringName("pause_menu"))
				get_viewport().set_input_as_handled()
			# If already paused, ESC pops the top overlay (resume/back)
			elif _ui_overlay_stack.get_child_count() > 0:
				pop_overlay()
				get_viewport().set_input_as_handled()

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
	# Load initial scene (configurable via export var)
	transition_to_scene(initial_scene_id, "instant", Priority.CRITICAL)

## Transition to a new scene
func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = Priority.NORMAL) -> void:
	# Validate scene exists in registry
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(scene_id)
	if scene_data.is_empty():
		# Silently ignore missing scenes (graceful handling)
		print_debug("M_SceneManager: Scene '%s' not found in U_SceneRegistry" % scene_id)
		return

	# Create transition request
	var request := TransitionRequest.new(scene_id, transition_type, priority)

	# Add to queue based on priority
	_enqueue_transition(request)
	# Debug logs live in tests, not here

	# Process queue if not already processing
	if not _is_processing_transition:
		_process_transition_queue()

## Enqueue transition based on priority
func _enqueue_transition(request: TransitionRequest) -> void:
	# Drop duplicate requests for the same target already in the queue
	for existing in _transition_queue:
		if existing.scene_id == request.scene_id and existing.transition_type == request.transition_type:
			# Keep the higher-priority one
			if existing.priority >= request.priority:
				return
			# Replace existing lower-priority with the new one
			_transition_queue.erase(existing)
			break

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
		_store.dispatch(U_SCENE_ACTIONS.transition_started(
			request.scene_id,
			request.transition_type
		))

	# Perform transition
	await _perform_transition(request)

	# Dispatch transition completed action
	if _store != null:
		_store.dispatch(U_SCENE_ACTIONS.transition_completed(request.scene_id))

	# If a post-transition overlay was requested, push it now
	if not _pending_overlay_after_transition.is_empty():
		var overlay_to_push: StringName = _pending_overlay_after_transition
		_pending_overlay_after_transition = StringName("")
		push_overlay(overlay_to_push)

	# Process next transition in queue
	await get_tree().physics_frame
	_process_transition_queue()

## Perform the actual scene transition
func _perform_transition(request: TransitionRequest) -> void:
	# Get scene path from registry
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(request.scene_id)
	if scene_path.is_empty():
		push_error("M_SceneManager: No path for scene '%s'" % request.scene_id)
		return

	# Track scene history based on scene type (T111-T113)
	_update_scene_history(request.scene_id)

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

		# Restore player spawn point if transitioning from door trigger
		_restore_player_spawn_point(new_scene)

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
	# Load and add overlay scene
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(scene_id)
	if scene_path.is_empty():
		push_warning("M_SceneManager: Scene '%s' not found for overlay" % scene_id)
		return

	var overlay_scene: Node = _load_scene(scene_path)
	if overlay_scene == null:
		push_error("M_SceneManager: Failed to load overlay scene '%s'" % scene_id)
		return

	if _ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found for overlay '%s'" % scene_id)
		overlay_scene.queue_free()
		return

	_configure_overlay_scene(overlay_scene, scene_id)
	if _ui_overlay_stack != null:
		_ui_overlay_stack.add_child(overlay_scene)
		# Dispatch push overlay action after successful add
		if _store != null:
			_store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))
		_update_pause_state()

## Pop top overlay from UIOverlayStack
func pop_overlay() -> void:
	if _ui_overlay_stack == null:
		return

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return  # Nothing to pop

	# Dispatch pop overlay action
	if _store != null:
		_store.dispatch(U_SCENE_ACTIONS.pop_overlay())

	# Remove top overlay
	var top_overlay: Node = _ui_overlay_stack.get_child(overlay_count - 1)
	_ui_overlay_stack.remove_child(top_overlay)
	top_overlay.queue_free()
	_update_pause_state()

## Configure overlay scene for pause handling
func _configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	if overlay_scene == null:
		return

	overlay_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_scene.set_meta(OVERLAY_META_SCENE_ID, scene_id)

## Update SceneTree pause + cursor state based on overlay stack
func _update_pause_state() -> void:
	if _ui_overlay_stack == null:
		return

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	var should_pause: bool = overlay_count > 0

	if get_tree().paused != should_pause:
		get_tree().paused = should_pause

	# Keep gameplay state in sync so HUD/selectors reflect pause status
	if _store != null:
		var gameplay_state: Dictionary = _store.get_slice(StringName("gameplay"))
		var is_paused_in_state: bool = false
		if not gameplay_state.is_empty():
			is_paused_in_state = gameplay_state.get("paused", false)

		if should_pause and not is_paused_in_state:
			_store.dispatch(U_GAMEPLAY_ACTIONS.pause_game())
		elif not should_pause and is_paused_in_state:
			_store.dispatch(U_GAMEPLAY_ACTIONS.unpause_game())

	if _cursor_manager != null:
		if should_pause:
			_cursor_manager.set_cursor_state(false, true)  # unlocked, visible
		else:
			_cursor_manager.set_cursor_state(true, false)  # locked, hidden

## Ensure scene_stack metadata matches actual overlay stack
func _sync_overlay_stack_state() -> void:
	if _store == null or _ui_overlay_stack == null:
		return

	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	if scene_state.is_empty():
		_update_pause_state()
		return

	var current_stack_variant: Array = scene_state.get("scene_stack", [])
	var current_stack: Array[StringName] = []
	for entry in current_stack_variant:
		if entry is StringName:
			current_stack.append(entry)
		elif entry is String:
			current_stack.append(StringName(entry))

	var desired_stack: Array[StringName] = _get_overlay_scene_ids_from_ui()

	if _overlay_stacks_match(current_stack, desired_stack):
		_update_pause_state()
		return

	if current_stack.size() > 0:
		_clear_scene_stack_state(current_stack.size())

	for scene_id in desired_stack:
		_store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))

	_update_pause_state()

## Collect overlay scene IDs from UIOverlayStack metadata
func _get_overlay_scene_ids_from_ui() -> Array[StringName]:
	var overlay_ids: Array[StringName] = []

	if _ui_overlay_stack == null:
		return overlay_ids

	for child in _ui_overlay_stack.get_children():
		if child.has_meta(OVERLAY_META_SCENE_ID):
			var scene_id_meta: Variant = child.get_meta(OVERLAY_META_SCENE_ID)
			if scene_id_meta is StringName:
				overlay_ids.append(scene_id_meta)
			elif scene_id_meta is String:
				overlay_ids.append(StringName(scene_id_meta))
			else:
				push_warning("M_SceneManager: Overlay has invalid scene_id metadata")
		else:
			push_warning("M_SceneManager: Overlay missing scene_id metadata")

	return overlay_ids

## Clear scene_stack metadata by dispatching pop actions
func _clear_scene_stack_state(count: int) -> void:
	if _store == null or count <= 0:
		return

	for _i in range(count):
		_store.dispatch(U_SCENE_ACTIONS.pop_overlay())

## Compare overlay stacks for equality
func _overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	if stack_a.size() != stack_b.size():
		return false

	for i in range(stack_a.size()):
		if stack_a[i] != stack_b[i]:
			return false

	return true

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

	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(scene_id)
	if scene_data.is_empty():
		return

	var scene_type: int = scene_data.get("scene_type", U_SCENE_REGISTRY.SceneType.GAMEPLAY)

	# UI/Menu/End-game scenes: cursor visible + unlocked
	# Gameplay scenes: cursor hidden + locked
	match scene_type:
		U_SCENE_REGISTRY.SceneType.MENU, U_SCENE_REGISTRY.SceneType.UI, U_SCENE_REGISTRY.SceneType.END_GAME:
			_cursor_manager.set_cursor_state(false, true)  # unlocked, visible
		U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			_cursor_manager.set_cursor_state(true, false)  # locked, hidden

## Create transition effect based on type
func _create_transition_effect(transition_type: String):
	match transition_type.to_lower():
		"instant":
			return INSTANT_TRANSITION.new()
		"fade":
			var fade := FADE_TRANSITION.new()
			fade.duration = 0.2  # Shorter duration for faster tests
			return fade
		_:
			# Unknown type, use instant as fallback
			push_warning("M_SceneManager: Unknown transition type '%s', using instant" % transition_type)
			return INSTANT_TRANSITION.new()


## Open settings as a full scene when invoked from pause
func open_settings_from_pause() -> void:
	# Record current gameplay scene to return to later and remove pause overlay
	_pending_return_scene_id = _current_scene_id
	if _ui_overlay_stack != null and _ui_overlay_stack.get_child_count() > 0:
		pop_overlay()

	# Transition to settings scene
	transition_to_scene(StringName("settings_menu"), "instant", Priority.HIGH)

## Resume back to gameplay and re-open pause after leaving settings
func resume_from_settings() -> void:
	if _pending_return_scene_id.is_empty():
		# Nothing to resume to; ignore
		return

	var target: StringName = _pending_return_scene_id
	_pending_return_scene_id = StringName("")
	# Schedule pause overlay to be restored after the transition completes
	_pending_overlay_after_transition = StringName("pause_menu")
	transition_to_scene(target, "instant", Priority.HIGH)

## Get current scene type (helper for input handler)
func _get_current_scene_type() -> int:
	if _current_scene_id.is_empty():
		return -1
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(_current_scene_id)
	return scene_data.get("scene_type", -1)

## Check if can navigate back in history (T110)
func can_go_back() -> bool:
	return _scene_history.size() > 0

## Navigate back to previous UI scene (T110)
func go_back() -> void:
	if not can_go_back():
		return  # No history to go back to

	# Pop the most recent scene from history
	var previous_scene: StringName = _scene_history.pop_back()

	# Transition to that scene
	# Use HIGH priority to jump the queue for back navigation
	transition_to_scene(previous_scene, "instant", Priority.HIGH)

## Restore player to spawn point after area transition (T095)
func _restore_player_spawn_point(loaded_scene: Node) -> void:
	if _store == null:
		return

	# Get target spawn point from gameplay state
	var state: Dictionary = _store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))

	# If no spawn point specified, do nothing (normal scene transition)
	if target_spawn.is_empty():
		return

	# Find spawn point node in loaded scene
	var spawn_node: Node3D = _find_spawn_point(loaded_scene, target_spawn)
	if spawn_node == null:
		push_warning("M_SceneManager: Spawn point '%s' not found in scene" % target_spawn)
		# Clear spawn point even if not found to prevent repeated warnings
		_clear_target_spawn_point()
		return

	# Find player entity in loaded scene
	var player: Node3D = _find_player_entity(loaded_scene)
	if player == null:
		push_warning("M_SceneManager: Player entity not found in scene for spawn restoration")
		_clear_target_spawn_point()
		return

	# Position player at spawn point
	player.global_position = spawn_node.global_position
	player.global_rotation = spawn_node.global_rotation

	# Clear target spawn point from state (one-time use)
	_clear_target_spawn_point()

## Find spawn point node by name in scene tree
func _find_spawn_point(scene_root: Node, spawn_name: StringName) -> Node3D:
	# Search for spawn point marker (Node3D with matching name)
	var spawn_points: Array = []
	_find_nodes_by_name(scene_root, spawn_name, spawn_points)

	if spawn_points.is_empty():
		return null

	# Return first match
	return spawn_points[0] as Node3D

## Find player entity in scene (node with name starting with "E_Player")
func _find_player_entity(scene_root: Node) -> Node3D:
	var players: Array = []
	_find_nodes_by_prefix(scene_root, "E_Player", players)

	if players.is_empty():
		return null

	return players[0] as Node3D

## Recursive helper to find nodes by exact name
func _find_nodes_by_name(node: Node, target_name: StringName, results: Array) -> void:
	if node.name == target_name:
		results.append(node)

	for child in node.get_children():
		_find_nodes_by_name(child, target_name, results)

## Recursive helper to find nodes by name prefix
func _find_nodes_by_prefix(node: Node, prefix: String, results: Array) -> void:
	if node.name.begins_with(prefix):
		results.append(node)

	for child in node.get_children():
		_find_nodes_by_prefix(child, prefix, results)

## Clear target spawn point from gameplay state
func _clear_target_spawn_point() -> void:
	if _store == null:
		return

	# Dispatch action to clear spawn point
	var clear_action: Dictionary = U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName(""))
	_store.dispatch(clear_action)

## Update scene history based on scene type (T111-T113)
func _update_scene_history(target_scene_id: StringName) -> void:
	# Get current and target scene types
	var current_scene_type: int = _get_current_scene_type()
	var target_scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(target_scene_id)
	var target_scene_type: int = target_scene_data.get("scene_type", -1)

	# T112: UI/Menu scenes automatically track history
	# Add current scene to history BEFORE transitioning (if it's a UI/Menu scene)
	var is_ui_or_menu: bool = (current_scene_type == U_SCENE_REGISTRY.SceneType.UI or
								current_scene_type == U_SCENE_REGISTRY.SceneType.MENU)
	if is_ui_or_menu and not _current_scene_id.is_empty():
		# Avoid adding duplicate consecutive entries
		if _scene_history.is_empty() or _scene_history.back() != _current_scene_id:
			_scene_history.append(_current_scene_id)

	# T113: Gameplay scenes explicitly disable history (clear history stack)
	if target_scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
		_scene_history.clear()
