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
const LOADING_SCREEN_TRANSITION := preload("res://scripts/scene_management/transitions/loading_screen_transition.gd")

const OVERLAY_META_SCENE_ID := StringName("_scene_manager_overlay_scene_id")
const PARTICLE_META_ORIG_SPEED := StringName("_scene_manager_particle_orig_speed")

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

## Camera state capture for blending (Phase 10)
class CameraState:
	var global_position: Vector3
	var global_rotation: Vector3
	var fov: float

	func _init(p_position: Vector3, p_rotation: Vector3, p_fov: float) -> void:
		global_position = p_position
		global_rotation = p_rotation
		fov = p_fov

## Internal references
var _store: M_StateStore = null
var _cursor_manager: M_CursorManager = null
var _active_scene_container: Node = null
var _ui_overlay_stack: CanvasLayer = null
var _transition_overlay: CanvasLayer = null
var _loading_overlay: CanvasLayer = null

## Transition queue
var _transition_queue: Array[TransitionRequest] = []
var _is_processing_transition: bool = false

## Camera blending (Phase 10: T178-T181)
var _transition_camera: Camera3D = null
var _camera_blend_tween: Tween = null
var _camera_blend_duration: float = 0.2  # Match fade transition duration

## Current scene tracking for reactive cursor updates
var _current_scene_id: StringName = StringName("")

## Scene history tracking for UI navigation (T109)
## Only tracks UI/Menu scenes, cleared when entering gameplay
var _scene_history: Array[StringName] = []

## Overlay return stack for generic overlay navigation (Phase 6.5)
## Tracks previous overlay ID when pushing with return, enabling stack-based navigation
## Example: pause→settings→back returns to pause without hardcoded methods
var _overlay_return_stack: Array[StringName] = []

## Scene cache management (Phase 8)
## Cache: path → PackedScene
var _scene_cache: Dictionary = {}

## Background loading tracking (Phase 8)
## Key: path (String), Value: { scene_id, status, start_time }
var _background_loads: Dictionary = {}

## Cache limits (Phase 8)
var _max_cached_scenes: int = 5
var _max_cache_memory: int = 100 * 1024 * 1024  # 100MB

## LRU tracking (Phase 8)
## Key: path (String), Value: timestamp (float)
var _cache_access_times: Dictionary = {}

## Background polling active flag (Phase 8)
var _is_background_polling_active: bool = false

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

	# Create transition camera for camera blending (Phase 10: T181)
	_create_transition_camera()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)

	# Validate U_SceneRegistry door pairings
	if not U_SCENE_REGISTRY.validate_door_pairings():
		push_error("M_SceneManager: U_SceneRegistry door pairing validation failed")

	# Phase 8: Preload critical scenes in background (main_menu, pause_menu, loading_screen)
	_preload_critical_scenes()

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
		var is_pause_trigger: bool = (key_event.keycode == KEY_ESCAPE) or key_event.is_action_pressed("pause")
		if is_pause_trigger and key_event.pressed and not key_event.is_echo():
			# Ignore ESC while a scene transition is in progress (fade/loading)
			# Prevents pausing during transitions which can stall tweens and break transitions
			if is_transitioning() or _is_processing_transition:
				get_viewport().set_input_as_handled()
				return
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

	# Find LoadingOverlay
	_loading_overlay = root.find_child("LoadingOverlay", true, false)
	if _loading_overlay == null:
		push_warning("M_SceneManager: LoadingOverlay not found (loading transitions will not work)")

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

	# Phase 8: Check if scene is cached
	var use_cached: bool = _is_scene_cached(scene_path)

	# Phase 8: Create progress callback for async loading
	var current_progress: Array = [0.0]  # Array for closure to work
	var progress_callback: Callable

	# Phase 8: Set progress handling for LoadingScreenTransition
	if transition_effect is LoadingScreenTransition:
		var loading_transition := transition_effect as LoadingScreenTransition
		progress_callback = func(progress: float) -> void:
			var normalized_progress: float = clamp(progress, 0.0, 1.0)
			current_progress[0] = normalized_progress
			loading_transition.update_progress(normalized_progress * 100.0)

		# Create a Callable that returns current progress for polling loop
		loading_transition.progress_provider = func() -> float:
			return current_progress[0]
	else:
		progress_callback = func(progress: float) -> void:
			current_progress[0] = clamp(progress, 0.0, 1.0)

	# Track if scene swap has completed (use Array for closure to work)
	var scene_swap_complete: Array = [false]

	# Phase 10: Capture old camera state before scene removal (T178-T180)
	var old_camera_state: CameraState = _capture_camera_state()

	# Phase 10: Prepare transition camera BEFORE transition starts (T182.5)
	# This ensures transition camera is active from the very beginning
	var should_blend: bool = old_camera_state != null and request.transition_type != "instant"
	if should_blend:
		# Set transition camera to match old camera state
		_transition_camera.global_position = old_camera_state.global_position
		_transition_camera.global_rotation = old_camera_state.global_rotation
		_transition_camera.fov = old_camera_state.fov
		# Make transition camera current BEFORE transition starts
		_transition_camera.current = true

	# Track new camera for blending after scene load
	var new_camera_ref: Array = [null]  # Use Array for closure

	# Define scene swap callback (called at mid-transition for fades, immediately for instant)
	var scene_swap_callback := func() -> void:
		# Remove current scene from ActiveSceneContainer
		if _active_scene_container != null:
			_remove_current_scene()

		# Load new scene (Phase 8: async for loading transitions, cached if available, sync otherwise)
		var new_scene: Node = null
		if use_cached:
			# Use cached scene (instant)
			var cached := _get_cached_scene(scene_path)
			if cached:
				new_scene = cached.instantiate()
				# Update progress for loading transitions (instant completion)
				if request.transition_type == "loading":
					progress_callback.call(1.0)
		elif request.transition_type == "loading" and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
			# Use async loading for "loading" transitions (Phase 8)
			new_scene = await _load_scene_async(scene_path, progress_callback)
		else:
			# Use sync loading for other transitions (or headless mode)
			new_scene = _load_scene(scene_path)
			# Update progress for loading transitions in headless/sync mode
			if request.transition_type == "loading":
				progress_callback.call(1.0)

		if new_scene == null:
			push_error("M_SceneManager: Failed to load scene '%s'" % scene_path)
			return

		# Add new scene to ActiveSceneContainer
		if _active_scene_container != null:
			_add_scene(new_scene)

		# Restore player spawn point if transitioning from door trigger
		_restore_player_spawn_point(new_scene)

		# Phase 10: Find new scene camera and start tween toward it (T182.5)
		var new_cameras: Array = get_tree().get_nodes_in_group("main_camera")
		if not new_cameras.is_empty():
			new_camera_ref[0] = new_cameras[0] as Camera3D

		# Phase 10: Start tween animation toward new camera (mid-transition)
		# Transition camera is already active, now animate it to new position
		if should_blend:
			# Re-assert transition camera as current (new scene camera may have overridden it)
			_transition_camera.current = true

			var new_camera: Camera3D = new_camera_ref[0] as Camera3D
			if new_camera != null:
				# Start tween to animate from current transition camera state to new camera
				_start_camera_blend_tween(new_camera, _camera_blend_duration)
		else:
			# No blending (instant transition or no camera) - just activate new camera
			var new_camera: Camera3D = new_camera_ref[0] as Camera3D
			if new_camera != null:
				new_camera.current = true

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
		# For loading screen transitions, set mid-transition callback and use loading overlay
		elif transition_effect is LoadingScreenTransition:
			(transition_effect as LoadingScreenTransition).mid_transition_callback = scene_swap_callback
			transition_effect.execute(_loading_overlay, completion_callback)
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

	# Wait for transition to complete (matches original pattern)
	while not transition_complete[0]:
		await get_tree().process_frame

	# Phase 10: Camera blending now happens in scene_swap_callback (T182.5)
	# This ensures blend runs in parallel with fade effect, not sequentially after

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

## Load scene asynchronously with progress callback (Phase 8)
##
## Uses ResourceLoader.load_threaded_* for async loading with real progress updates.
## Falls back to sync loading in headless mode.
##
## Parameters:
##   scene_path: Resource path to .tscn file
##   progress_callback: Callable(progress: float) called with 0.0-1.0 progress
##
## Returns: Instantiated Node or null on failure
func _load_scene_async(scene_path: String, progress_callback: Callable) -> Node:
	# Fallback to sync loading in headless mode (async may not work)
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if progress_callback.is_valid():
			progress_callback.call(1.0)  # Fake instant completion
		if packed_scene:
			return packed_scene.instantiate()
		return null

	# Check if already loading in background
	if _background_loads.has(scene_path):
		# Attach to existing load
		while true:
			var progress: Array = [0.0]
			var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress)

			# Update progress callback
			if progress_callback.is_valid():
				progress_callback.call(progress[0])

			# Check status
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				push_error("M_SceneManager: Async load failed for '%s'" % scene_path)
				return null
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("M_SceneManager: Invalid resource path '%s'" % scene_path)
				return null

			await get_tree().process_frame

		# Remove from background loads
		_background_loads.erase(scene_path)

		# Get loaded resource
		var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
		if packed_scene:
			return packed_scene.instantiate()
		return null

	# Start new async load
	var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		push_error("M_SceneManager: Failed to start async load for '%s' (error %d)" % [scene_path, err])
		return null

	# Poll until loaded
	var progress: Array = [0.0]
	var timeout_time: float = Time.get_ticks_msec() / 1000.0 + 30.0  # 30s timeout
	while true:
		var current_time: float = Time.get_ticks_msec() / 1000.0

		# Timeout protection
		if current_time > timeout_time:
			push_error("M_SceneManager: Async load timeout for '%s'" % scene_path)
			return null

		var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress)

		# Update progress callback
		if progress_callback.is_valid():
			progress_callback.call(progress[0])

		# Check status
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("M_SceneManager: Async load failed for '%s'" % scene_path)
			return null
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("M_SceneManager: Invalid resource path '%s'" % scene_path)
			return null

		await get_tree().process_frame

	# Get loaded resource
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		push_error("M_SceneManager: Failed to get loaded PackedScene for '%s'" % scene_path)
		return null

	return packed_scene.instantiate()

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

## Push overlay with automatic return navigation (Phase 6.5)
##
## Replaces the current overlay (if any) with a new overlay and remembers the previous one.
## When pop_overlay_with_return() is called, the previous overlay will be restored.
##
## This enables generic overlay transitions without hardcoded methods:
## - pause → settings → back (returns to pause)
## - inventory → skill_tree → back (returns to inventory)
## - map → quests → back (returns to map)
##
## Behavior: REPLACE mode (not stack mode)
## - If overlay already exists: pop it, remember it, push new one
## - If no overlay exists: remember empty, push new one
##
## Example:
##   push_overlay("pause_menu")                 # 1 overlay: pause
##   push_overlay_with_return("settings_menu")  # Remember pause, replace → 1 overlay: settings
##   pop_overlay_with_return()                  # Restore pause → 1 overlay: pause
func push_overlay_with_return(overlay_id: StringName) -> void:
	# Remember current top overlay (if any) for return navigation
	var current_top: StringName = _get_top_overlay_id()
	_overlay_return_stack.push_back(current_top)

	# If there's a current overlay, pop it before pushing new one (REPLACE mode)
	if not current_top.is_empty():
		pop_overlay()

	# Push new overlay
	push_overlay(overlay_id)

## Pop overlay with automatic return navigation (Phase 6.5)
##
## Pops the current overlay and restores the previous overlay from the return stack.
## If the return stack is empty, this behaves like pop_overlay().
## If the return stack has a non-empty overlay ID, that overlay is pushed.
##
## This provides stack-based overlay navigation without hardcoded logic.
func pop_overlay_with_return() -> void:
	# Pop current overlay
	pop_overlay()

	# Check return stack for previous overlay to restore
	if not _overlay_return_stack.is_empty():
		var previous_overlay: StringName = _overlay_return_stack.pop_back()

		# Only push if previous overlay was non-empty (not base gameplay)
		if not previous_overlay.is_empty():
			push_overlay(previous_overlay)

## Get the scene_id of the current top overlay (helper for return stack)
##
## Returns StringName("") if no overlays are active.
func _get_top_overlay_id() -> StringName:
	if _ui_overlay_stack == null:
		return StringName("")

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return StringName("")

	var top_overlay: Node = _ui_overlay_stack.get_child(overlay_count - 1)
	if top_overlay.has_meta(OVERLAY_META_SCENE_ID):
		var scene_id_meta: Variant = top_overlay.get_meta(OVERLAY_META_SCENE_ID)
		if scene_id_meta is StringName:
			return scene_id_meta
		elif scene_id_meta is String:
			return StringName(scene_id_meta)

	return StringName("")

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

	# Ensure particles in gameplay respect pause (GPU particles ignore SceneTree pause)
	_set_particles_paused(should_pause)

## Recursively collect particle nodes and set speed_scale to pause/resume simulation
func _set_particles_paused(should_pause: bool) -> void:
	if _active_scene_container == null:
		return

	var particles: Array = []
	_collect_particle_nodes(_active_scene_container, particles)

	for p in particles:
		# Store original speed once
		if should_pause:
			if not p.has_meta(PARTICLE_META_ORIG_SPEED):
				var current: Variant = p.get("speed_scale")
				var orig_speed: float = (current as float) if current is float else 1.0
				p.set_meta(PARTICLE_META_ORIG_SPEED, orig_speed)
			p.set("speed_scale", 0.0)
		else:
			# Restore on resume
			if p.has_meta(PARTICLE_META_ORIG_SPEED):
				var orig: Variant = p.get_meta(PARTICLE_META_ORIG_SPEED)
				p.set("speed_scale", float(orig) if orig is float else 1.0)
				p.set_meta(PARTICLE_META_ORIG_SPEED, null)

func _collect_particle_nodes(node: Node, out: Array) -> void:
	# Check for both 2D and 3D particle node types
	if node is GPUParticles3D or node is CPUParticles3D or node is GPUParticles2D or node is CPUParticles2D:
		out.append(node)

	for child in node.get_children():
		_collect_particle_nodes(child, out)

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
		"loading":
			var loading := LOADING_SCREEN_TRANSITION.new()
			loading.min_duration = 1.5  # Minimum display time
			return loading
		_:
			# Unknown type, use instant as fallback
			print_debug("M_SceneManager: Unknown transition type '%s', using instant" % transition_type)
			return INSTANT_TRANSITION.new()



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

## ============================================================================
## Phase 10: Camera Blending (T178-T182)
## ============================================================================

## Create transition camera for smooth camera blending (T181)
##
## Transition camera is created once in _ready() and reused for all transitions.
## Set to current during blend, then deactivated when blend completes.
func _create_transition_camera() -> void:
	_transition_camera = Camera3D.new()
	_transition_camera.name = "TransitionCamera"
	add_child(_transition_camera)
	_transition_camera.current = false  # Not active by default

## Capture camera state from current scene (T178-T180)
##
## Finds main camera in current scene via "main_camera" group and captures
## its global position, rotation, and FOV for blending.
##
## Returns: CameraState or null if no camera found
func _capture_camera_state() -> CameraState:
	var cameras: Array = get_tree().get_nodes_in_group("main_camera")
	if cameras.is_empty():
		return null

	var camera: Camera3D = cameras[0] as Camera3D
	if camera == null:
		return null

	return CameraState.new(
		camera.global_position,
		camera.global_rotation,
		camera.fov
	)

## Blend transition camera from old state to new camera (T178-T180)
##
## Uses Tween to smoothly interpolate position, rotation, and FOV over
## specified duration. Follows pattern from prototype_camera_blending.gd.
##
## Parameters:
##   from_state: Captured state from old scene camera
##   to_camera: New scene camera to blend towards
##   duration: Blend duration in seconds (0 for instant cut)
##
## Returns: Tween that performs the blend (connect to finished signal)
func _blend_camera(from_state: CameraState, to_camera: Camera3D, duration: float) -> Tween:
	# Kill existing blend tween if running
	if _camera_blend_tween != null and _camera_blend_tween.is_running():
		_camera_blend_tween.kill()

	# Set initial state on transition camera
	_transition_camera.global_position = from_state.global_position
	_transition_camera.global_rotation = from_state.global_rotation
	_transition_camera.fov = from_state.fov

	# Activate transition camera
	_transition_camera.current = true

	# Create tween for blending
	_camera_blend_tween = create_tween()
	_camera_blend_tween.set_parallel(true)  # All properties blend simultaneously
	_camera_blend_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_blend_tween.set_ease(Tween.EASE_IN_OUT)

	# T178: Interpolate position
	_camera_blend_tween.tween_property(_transition_camera, "global_position", to_camera.global_position, duration)

	# T179: Interpolate rotation (quaternion interpolation for smooth results)
	_camera_blend_tween.tween_property(_transition_camera, "global_rotation", to_camera.global_rotation, duration)

	# T180: Interpolate FOV
	_camera_blend_tween.tween_property(_transition_camera, "fov", to_camera.fov, duration)

	return _camera_blend_tween

## Start camera blend tween toward new camera (T182.5)
##
## Assumes transition camera is already positioned and active.
## Creates tween to animate from current transition camera state to new camera.
##
## Parameters:
##   to_camera: New scene camera to blend towards
##   duration: Blend duration in seconds
func _start_camera_blend_tween(to_camera: Camera3D, duration: float) -> void:
	# Kill existing blend tween if running
	if _camera_blend_tween != null and _camera_blend_tween.is_running():
		_camera_blend_tween.kill()

	# Create tween for blending
	_camera_blend_tween = create_tween()
	_camera_blend_tween.set_parallel(true)  # All properties blend simultaneously
	_camera_blend_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_blend_tween.set_ease(Tween.EASE_IN_OUT)

	# T178: Interpolate position
	_camera_blend_tween.tween_property(_transition_camera, "global_position", to_camera.global_position, duration)

	# T179: Interpolate rotation (quaternion interpolation for smooth results)
	_camera_blend_tween.tween_property(_transition_camera, "global_rotation", to_camera.global_rotation, duration)

	# T180: Interpolate FOV
	_camera_blend_tween.tween_property(_transition_camera, "fov", to_camera.fov, duration)

	# Connect to finished signal to finalize camera switch
	_camera_blend_tween.finished.connect(_finalize_camera_blend.bind(to_camera), CONNECT_ONE_SHOT)

## Finalize camera blend by activating new scene camera (T181)
##
## Called when blend tween completes. Deactivates transition camera and
## activates the new scene's camera.
func _finalize_camera_blend(new_camera: Camera3D) -> void:
	if new_camera == null:
		return

	# Deactivate transition camera
	if _transition_camera != null:
		_transition_camera.current = false

	# Activate new scene camera
	new_camera.current = true

## ============================================================================
## Phase 8: Scene Cache Management
## ============================================================================

## Check if scene is cached
func _is_scene_cached(scene_path: String) -> bool:
	return _scene_cache.has(scene_path)

## Get cached PackedScene (updates LRU access time)
func _get_cached_scene(scene_path: String) -> PackedScene:
	if not _scene_cache.has(scene_path):
		return null

	# Update LRU access time
	_cache_access_times[scene_path] = Time.get_ticks_msec() / 1000.0

	return _scene_cache[scene_path] as PackedScene

## Add PackedScene to cache (with eviction if needed)
func _add_to_cache(scene_path: String, packed_scene: PackedScene) -> void:
	if packed_scene == null:
		return

	# Add to cache
	_scene_cache[scene_path] = packed_scene
	_cache_access_times[scene_path] = Time.get_ticks_msec() / 1000.0

	# Check if eviction needed
	_check_cache_pressure()

## Check cache pressure and evict if necessary (hybrid policy)
func _check_cache_pressure() -> void:
	# Evict if exceeds max count
	while _scene_cache.size() > _max_cached_scenes:
		_evict_cache_lru()

	# Evict if exceeds memory limit
	var memory_usage: int = _get_cache_memory_usage()
	while memory_usage > _max_cache_memory and _scene_cache.size() > 0:
		_evict_cache_lru()
		memory_usage = _get_cache_memory_usage()

## Evict least-recently-used scene from cache
func _evict_cache_lru() -> void:
	if _scene_cache.is_empty():
		return

	# Find LRU path
	var lru_path: String = ""
	var lru_time: float = INF

	for path in _cache_access_times:
		var access_time: float = _cache_access_times[path]
		if access_time < lru_time:
			lru_time = access_time
			lru_path = path

	# Evict
	if not lru_path.is_empty():
		_scene_cache.erase(lru_path)
		_cache_access_times.erase(lru_path)

## Get estimated cache memory usage in bytes
func _get_cache_memory_usage() -> int:
	# Rough estimate: ~6.91 MB per gameplay scene (from Phase 0 measurements)
	# UI scenes smaller (~1 MB estimated)
	var total_bytes: int = 0

	for scene_path in _scene_cache:
		# Estimate based on scene type
		if "gameplay" in scene_path:
			total_bytes += 7 * 1024 * 1024  # ~7 MB per gameplay scene
		else:
			total_bytes += 1 * 1024 * 1024  # ~1 MB per UI scene

	return total_bytes

## ============================================================================
## Phase 8: Scene Preloading at Startup
## ============================================================================

## Preload critical scenes at startup (Phase 8)
##
## Loads scenes with priority >= 10 in background for instant transitions.
## Critical scenes: main_menu, pause_menu, loading_screen
func _preload_critical_scenes() -> void:
	# Get critical scenes from registry (priority >= 10)
	var critical_scenes: Array = U_SCENE_REGISTRY.get_preloadable_scenes(10)

	if critical_scenes.is_empty():
		print_debug("M_SceneManager: No critical scenes to preload")
		return

	print_debug("M_SceneManager: Starting preload for %d critical scene(s)" % critical_scenes.size())

	# Start async load for each critical scene
	for scene_data in critical_scenes:
		var scene_id: StringName = scene_data.get("scene_id", StringName(""))
		var scene_path: String = scene_data.get("path", "")

		if scene_path.is_empty():
			push_warning("M_SceneManager: Critical scene '%s' has empty path" % scene_id)
			continue

		# Skip if already cached
		if _is_scene_cached(scene_path):
			print_debug("M_SceneManager: Critical scene '%s' already cached" % scene_id)
			continue

		# Start async load
		var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
		if err != OK:
			push_error("M_SceneManager: Failed to start preload for '%s' (error %d)" % [scene_id, err])
			continue

		# Track in background loads
		_background_loads[scene_path] = {
			"scene_id": scene_id,
			"status": ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			"start_time": Time.get_ticks_msec() / 1000.0
		}

		print_debug("M_SceneManager: Started preload for '%s'" % scene_id)

	# Start background polling if we have loads in progress
	if not _background_loads.is_empty():
		_is_background_polling_active = true
		_start_background_load_polling()

## Start background polling loop for preloaded scenes (Phase 8)
func _start_background_load_polling() -> void:
	while not _background_loads.is_empty():
		var completed_paths: Array = []

		# Poll each background load
		for scene_path in _background_loads:
			var load_data: Dictionary = _background_loads[scene_path]
			var status: int = ResourceLoader.load_threaded_get_status(scene_path)

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				# Load complete - add to cache
				var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
				if packed_scene:
					_add_to_cache(scene_path, packed_scene)
					print_debug("M_SceneManager: Preloaded '%s' successfully" % load_data.get("scene_id"))
				else:
					push_error("M_SceneManager: Failed to get preloaded scene '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)

			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				# Load failed
				push_error("M_SceneManager: Preload failed for '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)

			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# Invalid resource
				push_error("M_SceneManager: Invalid resource for preload '%s'" % load_data.get("scene_id"))
				completed_paths.append(scene_path)

		# Remove completed loads
		for path in completed_paths:
			_background_loads.erase(path)

		# Wait one frame before next poll
		if not _background_loads.is_empty():
			await get_tree().process_frame

	print_debug("M_SceneManager: All critical scenes preloaded")
	_is_background_polling_active = false

## Hint to preload a scene in background (Phase 8)
##
## Called when player approaches a door trigger to preload target scene.
## Non-blocking - loads in background while player is in trigger zone.
##
## @param scene_path: Resource path to .tscn file
func hint_preload_scene(scene_path: String) -> void:
	# Skip if already cached or loading
	if _is_scene_cached(scene_path):
		return

	if _background_loads.has(scene_path):
		return

	print_debug("M_SceneManager: Preload hint received for '%s'" % scene_path)

	# Start background load
	var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		push_error("M_SceneManager: Failed to start hinted preload for '%s' (error %d)" % [scene_path, err])
		return

	# Track in background loads
	_background_loads[scene_path] = {
		"scene_id": scene_path.get_file().get_basename(),
		"status": ResourceLoader.THREAD_LOAD_IN_PROGRESS,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

	# Start polling if not already running
	if not _is_background_polling_active:
		_is_background_polling_active = true
		_start_background_load_polling()
