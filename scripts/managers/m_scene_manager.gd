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
##
## Signals:
## - transition_visual_complete(scene_id): Emitted when fade-in completes and scene is fully visible

## Emitted when transition visual effects complete and scene is fully visible
## This is the signal MobileControls should use to show controls (not state changes)
signal transition_visual_complete(scene_id: StringName)

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_UI_REGISTRY := preload("res://scripts/ui/u_ui_registry.gd")
const U_TRANSITION_FACTORY := preload("res://scripts/scene_management/u_transition_factory.gd")
const I_SCENE_CONTRACT := preload("res://scripts/scene_management/i_scene_contract.gd")
# T209: Transition class imports removed - now handled by U_TransitionFactory
# Kept for type checking only:
const FADE_TRANSITION := preload("res://scripts/scene_management/transitions/trans_fade.gd")
const LOADING_SCREEN_TRANSITION := preload("res://scripts/scene_management/transitions/trans_loading_screen.gd")

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

## Internal references
var _store: M_StateStore = null
var _cursor_manager: M_CursorManager = null
var _spawn_manager: Node = null  # M_SpawnManager (Phase 12.1)
var _camera_manager: Node = null  # M_CameraManager (Phase 12.2)
var _active_scene_container: Node = null
var _ui_overlay_stack: CanvasLayer = null
var _transition_overlay: CanvasLayer = null
var _loading_overlay: CanvasLayer = null

## Transition queue
var _transition_queue: Array[TransitionRequest] = []
var _is_processing_transition: bool = false

## Current scene tracking for reactive cursor updates
var _current_scene_id: StringName = StringName("")
var _active_transition_target: StringName = StringName("")
var _navigation_pending_scene_id: StringName = StringName("")
var _latest_navigation_state: Dictionary = {}
var _pending_overlay_reconciliation: bool = false
var _navigation_slice_connected: bool = false
var _initial_navigation_synced: bool = false

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

	# Find M_SpawnManager via group (Phase 12.1: T225)
	var spawn_managers: Array = get_tree().get_nodes_in_group("spawn_manager")
	if spawn_managers.size() > 0:
		_spawn_manager = spawn_managers[0]
	else:
		push_error("M_SceneManager: No M_SpawnManager found in 'spawn_manager' group")

	# Find M_CameraManager via group (Phase 12.2: T243)
	var camera_managers: Array = get_tree().get_nodes_in_group("camera_manager")
	if camera_managers.size() > 0:
		_camera_manager = camera_managers[0]
	else:
		push_error("M_SceneManager: No M_CameraManager found in 'camera_manager' group")

	# Find container nodes
	_find_container_nodes()
	_sync_overlay_stack_state()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)
		if not _store.slice_updated.is_connected(_on_slice_updated):
			_store.slice_updated.connect(_on_slice_updated)
			_navigation_slice_connected = true

	# Validate U_SceneRegistry door pairings
	if not U_SCENE_REGISTRY.validate_door_pairings():
		push_error("M_SceneManager: U_SceneRegistry door pairing validation failed")

	# Phase 8: Preload critical scenes in background (main_menu, pause_menu, loading_screen)
	_preload_critical_scenes()

	# Load initial scene (main_menu) unless skipped for tests
	if not skip_initial_scene_load:
		_load_initial_scene()
	call_deferred("_request_navigation_reconciliation")

func _request_navigation_reconciliation() -> void:
	if _initial_navigation_synced:
		return
	_initial_navigation_synced = true
	if skip_initial_scene_load:
		return
	if _store == null:
		return
	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	if nav_state.is_empty():
		return
	_reconcile_navigation_state(nav_state)

func _exit_tree() -> void:
	# Unsubscribe from state updates
	if _unsubscribe != null and _unsubscribe.is_valid():
		_unsubscribe.call()
	if _store != null and _navigation_slice_connected and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	_navigation_slice_connected = false

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

func _ensure_store_reference() -> void:
	if _store != null and is_instance_valid(_store):
		return
	var tree := get_tree()
	if tree == null:
		return
	var stores := tree.get_nodes_in_group("state_store")
	if stores.size() > 0:
		_store = stores[0] as M_StateStore

## State change callback
func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	# Detect scene changes and update cursor reactively
	var scene_state: Dictionary = state.get("scene", {})
	var new_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))

	# Only track scene_id when it actually changes and is not empty
	# Phase 2 (T022): Cursor updates removed - M_PauseManager is now sole authority
	if new_scene_id != _current_scene_id and not new_scene_id.is_empty():
		_current_scene_id = new_scene_id
		if _navigation_pending_scene_id == new_scene_id:
			_navigation_pending_scene_id = StringName("")
		# NOTE: _sync_navigation_shell_with_scene() now called AFTER transition completes
		# in _process_transition_queue() to prevent mobile controls flashing (line 316)

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
		return

	_ensure_store_reference()

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
		_active_transition_target = StringName("")
		_reconcile_pending_navigation_overlays()
		return

	_ensure_store_reference()

	_is_processing_transition = true

	# Get next transition from queue
	var request: TransitionRequest = _transition_queue.pop_front()
	_active_transition_target = request.scene_id

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

	# Sync navigation shell immediately after scene loads
	_sync_navigation_shell_with_scene(request.scene_id)

	# Emit signal that visual transition is complete (scene is fully visible)
	# MobileControls waits for this signal before showing controls
	transition_visual_complete.emit(request.scene_id)

	if _active_transition_target == request.scene_id:
		_active_transition_target = StringName("")

	# Process next transition in queue
	await get_tree().physics_frame
	_process_transition_queue()

## Perform the actual scene transition
##
## **GDScript Closure Pattern** (T208):
## This method uses the "Array wrapper" pattern for closures to work around GDScript's
## limitation that closures cannot capture mutable local variables by reference.
##
## **Why use Arrays?**
## In GDScript, when you create a lambda/closure (e.g., `func() -> void:`), it can only
## capture local variables by VALUE, not by reference. If you try to modify a captured
## variable, you get a compile error: "Cannot assign to a variable captured from outer scope."
##
## **Solution:**
## Wrap mutable values in an Array (e.g., `var progress: Array = [0.0]`). Arrays are
## reference types, so the closure captures the Array reference (by value), but can still
## modify the Array contents (e.g., `progress[0] = 0.5`).
##
## **Example:**
## ```gdscript
## # ❌ This FAILS - cannot modify captured variable:
## var progress: float = 0.0
## var callback := func() -> void:
##     progress = 0.5  # ERROR: Cannot assign to captured variable
##
## # ✅ This WORKS - Array reference captured, contents mutable:
## var progress: Array = [0.0]
## var callback := func() -> void:
##     progress[0] = 0.5  # OK: Modifying array contents, not array reference
## ```
##
## **Where used in this method:**
## - `current_progress: Array = [0.0]` - Progress tracking for async loading
## - `scene_swap_complete: Array = [false]` - Flag for transition callback coordination
## - `new_camera_ref: Array = [null]` - Camera reference for blend callback
##
## **Alternative approaches:**
## - Member variables: Would require complex state management and cleanup
## - Signals: Would add unnecessary indirection and timing complexity
## - Helper classes: Overkill for simple value passing
##
## The Array pattern is the recommended GDScript idiom for this use case.
func _perform_transition(request: TransitionRequest) -> void:
	# Get scene path from registry
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(request.scene_id)
	if scene_path.is_empty():
		push_error("M_SceneManager: No path for scene '%s'" % request.scene_id)
		return

	# Track scene history based on scene type (T111-T113)
	_update_scene_history(request.scene_id)

	# T209: Create transition effect via factory (was _create_transition_effect)
	var transition_effect = U_TRANSITION_FACTORY.create_transition(request.transition_type)

	# Fallback to instant if transition type not found
	if transition_effect == null:
		transition_effect = U_TRANSITION_FACTORY.create_transition("instant")

	# Configure transition-specific settings
	_configure_transition(transition_effect, request.transition_type)

	# Phase 8: Check if scene is cached
	var use_cached: bool = _is_scene_cached(scene_path)

	# Phase 8: Create progress callback for async loading
	# T208: Array wrapper for closure to capture mutable value (see method doc comment)
	var current_progress: Array = [0.0]
	var progress_callback: Callable

	# Phase 8: Set progress handling for Trans_LoadingScreen
	if transition_effect is Trans_LoadingScreen:
		var loading_transition := transition_effect as Trans_LoadingScreen
		# If scene is cached, use FAKE progress (no provider) to show minimal loading
		# Otherwise, wire a real progress provider for async loading.
		if not use_cached:
			progress_callback = func(progress: float) -> void:
				var normalized_progress: float = clamp(progress, 0.0, 1.0)
				current_progress[0] = normalized_progress
				loading_transition.update_progress(normalized_progress * 100.0)

			# Create a Callable that returns current progress for polling loop
			loading_transition.progress_provider = func() -> float:
				return current_progress[0]
		else:
			# Cached scene: fall back to tween-based fake progress; mid-callback will swap scene at 50%
			progress_callback = func(_progress: float) -> void:
				pass
	else:
		progress_callback = func(progress: float) -> void:
			current_progress[0] = clamp(progress, 0.0, 1.0)

	# T208: Track if scene swap has completed (Array wrapper for closure pattern)
	var scene_swap_complete: Array = [false]

	# Phase 12.2: Capture old camera state BEFORE removing scene (T244)
	var old_camera_state = null
	if _camera_manager != null and request.transition_type != "instant":
		if _active_scene_container != null and _active_scene_container.get_child_count() > 0:
			var old_scene: Node = _active_scene_container.get_child(0)
			old_camera_state = _camera_manager.capture_camera_state(old_scene)

	# Phase 10: Determine if camera blending should occur
	var should_blend: bool = old_camera_state != null and _camera_manager != null

	# Reference holder for the newly loaded scene (closure-friendly)
	var new_scene_ref: Array = [null]

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
				# For cached scenes with "loading" transition, we use fake progress,
				# so avoid forcing progress to 100% here.
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

		# Phase 12.5: Validate scene contract (T306)
		_validate_scene_contract(new_scene, request.scene_id)

		# Determine scene type for spawn handling
		var scene_type: int = U_SCENE_REGISTRY.get_scene_type(request.scene_id)

		# Mark gameplay scenes as spawned by M_SceneManager BEFORE adding to tree
		# This must happen before _ready() calls fire, so M_GameplayInitializer sees it
		if _spawn_manager != null and scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			new_scene.set_meta("_scene_manager_spawned", true)

		# Add new scene to ActiveSceneContainer
		if _active_scene_container != null:
			_add_scene(new_scene)
		# Store for post-transition finalization
		new_scene_ref[0] = new_scene

		# Restore player spawn point (Phase 12.1: T226, Phase 12.3: T268)
		# Use spawn_at_last_spawn() which checks priority: target_spawn_point → last_checkpoint → sp_default
		# This handles both door transitions AND death respawn correctly
		# Only apply to GAMEPLAY scenes (not UI/Menu/EndGame)
		if _spawn_manager != null and scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			# Wait for scene tree to fully initialize (spawn points, entities, etc.)
			# This ensures all child nodes have completed their _ready() calls before spawning
			# Multiple waits needed because some nodes use call_deferred for initialization
			await get_tree().process_frame
			await get_tree().physics_frame
			await get_tree().process_frame  # Extra wait for deferred operations

			# Check scene is still valid before spawning (can be freed during test cleanup)
			if is_instance_valid(new_scene):
				await _spawn_manager.spawn_at_last_spawn(new_scene)

		# Phase 12.2: Blend cameras using M_CameraManager (T244)
		if should_blend and _camera_manager != null:
			# Delegate camera blending to M_CameraManager with pre-captured state
			_camera_manager.blend_cameras(null, new_scene, 0.2, old_camera_state)
		else:
			# No blending (instant transition or no camera) - just activate new camera if present
			var new_cameras: Array = get_tree().get_nodes_in_group("main_camera")
			if not new_cameras.is_empty():
				var new_camera: Camera3D = new_cameras[0] as Camera3D
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
		if transition_effect is Trans_Fade:
			(transition_effect as Trans_Fade).mid_transition_callback = scene_swap_callback
			transition_effect.execute(_transition_overlay, completion_callback)
		# For loading screen transitions, set mid-transition callback and use loading overlay
		elif transition_effect is Trans_LoadingScreen:
			(transition_effect as Trans_LoadingScreen).mid_transition_callback = scene_swap_callback
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

	# Safety: Only finalize camera if no active blend tween remains. Without this
	# guard, fade transitions cut the blend short as soon as the fade finishes.
	var has_active_blend: bool = false
	if _camera_manager != null:
		var active_tween: Tween = _camera_manager.get("_camera_blend_tween")
		has_active_blend = active_tween != null and active_tween.is_running()

	if not has_active_blend and _camera_manager != null and new_scene_ref[0] != null and _camera_manager.has_method("finalize_blend_to_scene"):
		_camera_manager.finalize_blend_to_scene(new_scene_ref[0])

	# Re-enable player physics after transition completes (prevents falling during load)
	if new_scene_ref[0] != null:
		_unfreeze_player_physics(new_scene_ref[0])

## Re-enable player physics after transition completes
func _unfreeze_player_physics(scene: Node) -> void:
	if scene == null:
		return

	# Find player entity
	var player: Node3D = _find_player_in_scene(scene)
	if player == null:
		return

	# Check if physics was frozen by spawn system
	if not player.has_meta("_spawn_physics_frozen"):
		return

	# Re-enable physics
	var player_body: CharacterBody3D = player as CharacterBody3D
	if player_body != null:
		player_body.set_physics_process(true)
		player.remove_meta("_spawn_physics_frozen")

## Find player in scene tree
func _find_player_in_scene(scene: Node) -> Node3D:
	if scene == null:
		return null

	# Check if this node is a player
	if scene.name.begins_with("E_Player"):
		return scene as Node3D

	# Recursively search children
	for child in scene.get_children():
		var found_player: Node3D = _find_player_in_scene(child)
		if found_player != null:
			return found_player

	return null

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
func push_overlay(scene_id: StringName, force: bool = false) -> void:
	# Note: Transition guards are enforced at input-handling time (ESC/pause)
	# to avoid pushing overlays during scene transitions. Overlay navigation
	# and direct calls here proceed unconditionally.
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
		_update_particles_and_focus()

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
	_update_particles_and_focus()
	_restore_focus_to_top_overlay()

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

	# Push new overlay (force to bypass transition guard; this is UI-only navigation)
	push_overlay(overlay_id, true)

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
			# Defer restoration to next frame to avoid race with queue_free()
			call_deferred("_push_overlay_for_return", previous_overlay)

## Internal: deferred restore helper for return navigation
func _push_overlay_for_return(scene_id: StringName) -> void:
	push_overlay(scene_id, true)

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

func _restore_focus_to_top_overlay() -> void:
	if _ui_overlay_stack == null:
		return

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	if overlay_count == 0:
		return

	var top_overlay: Node = _ui_overlay_stack.get_child(overlay_count - 1)
	if top_overlay == null:
		return

	var viewport: Viewport = get_tree().root
	var focus_owner: Control = null
	if viewport != null:
		focus_owner = viewport.gui_get_focus_owner()

	var has_focus_in_top: bool = focus_owner != null \
		and focus_owner.is_inside_tree() \
		and top_overlay.is_ancestor_of(focus_owner)
	if has_focus_in_top:
		return

	var target: Control = _find_first_focusable_in(top_overlay)
	if target != null and target.is_inside_tree():
		target.grab_focus()

func _find_first_focusable_in(root: Node) -> Control:
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				return control
			var nested_control := _find_first_focusable_in(control)
			if nested_control != null:
				return nested_control
		else:
			var nested := _find_first_focusable_in(child)
			if nested != null:
				return nested
	return null

## Update particles and focus based on overlay stack
##
## Phase 2 (T022): Refactored to remove pause/cursor authority.
## M_PauseManager is now the sole authority for get_tree().paused and cursor state.
## This method only handles GPU particle workaround (particles ignore SceneTree pause).
func _update_particles_and_focus() -> void:
	if _ui_overlay_stack == null:
		return

	var overlay_count: int = _ui_overlay_stack.get_child_count()
	var should_pause: bool = overlay_count > 0

	# Ensure particles in gameplay respect pause (GPU particles ignore SceneTree pause)
	# This is a workaround - M_PauseManager controls actual pause via get_tree().paused
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

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("navigation"):
		return
	if slice_state.is_empty():
		return
	_reconcile_navigation_state(slice_state)

func _reconcile_navigation_state(nav_state: Dictionary) -> void:
	if nav_state.is_empty():
		return
	_latest_navigation_state = nav_state.duplicate(true)
	var desired_scene_id: StringName = nav_state.get("base_scene_id", StringName(""))
	_reconcile_base_scene(desired_scene_id)
	var desired_overlay_ids: Array[StringName] = _coerce_string_name_array(nav_state.get("overlay_stack", []))
	var current_stack: Array[StringName] = _get_overlay_scene_ids_from_ui()
	_reconcile_overlay_stack(desired_overlay_ids, current_stack)

func _reconcile_base_scene(desired_scene_id: StringName) -> void:
	if desired_scene_id == StringName(""):
		return
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(desired_scene_id)
	if scene_data.is_empty():
		return
	var current_scene_id: StringName = get_current_scene()
	if current_scene_id == desired_scene_id:
		return
	if _active_transition_target == desired_scene_id:
		return
	if _navigation_pending_scene_id == desired_scene_id:
		return
	if _is_scene_in_queue(desired_scene_id):
		return

	var transition_type: String = String(scene_data.get("default_transition", "instant"))
	if transition_type.is_empty():
		transition_type = "instant"

	transition_to_scene(desired_scene_id, transition_type, Priority.HIGH)
	_navigation_pending_scene_id = desired_scene_id

func _is_scene_in_queue(scene_id: StringName) -> bool:
	for request in _transition_queue:
		if request is TransitionRequest and request.scene_id == scene_id:
			return true
	return false

func _reconcile_overlay_stack(desired_overlay_ids: Array[StringName], current_stack: Array[StringName]) -> void:
	# T072: Defer overlay reconciliation during base scene transitions
	# This prevents pause overlays from pushing during gameplay transitions
	if _is_processing_transition or _transition_queue.size() > 0:
		_pending_overlay_reconciliation = true
		return

	const MAX_STACK_DEPTH := 8
	var desired_scene_stack: Array[StringName] = _map_overlay_ids_to_scene_ids(desired_overlay_ids)
	if _overlay_stacks_match(current_stack, desired_scene_stack):
		_pending_overlay_reconciliation = false
		_update_overlay_visibility(desired_overlay_ids)
		return

	var normalized_current: Array[StringName] = current_stack.duplicate(true)
	var prefix_len: int = _get_longest_matching_prefix(normalized_current, desired_scene_stack)

	while normalized_current.size() > prefix_len:
		pop_overlay()
		if not normalized_current.is_empty():
			normalized_current.pop_back()

	var desired_count: int = min(desired_scene_stack.size(), MAX_STACK_DEPTH)
	if desired_scene_stack.size() > MAX_STACK_DEPTH:
		push_warning("M_SceneManager: Desired overlay stack exceeds supported depth (%d); truncating" % MAX_STACK_DEPTH)

	for i in range(prefix_len, desired_count):
		var scene_id: StringName = desired_scene_stack[i]
		if scene_id == StringName(""):
			continue
		if not _push_overlay_scene_from_navigation(scene_id):
			break
		normalized_current.append(scene_id)

	_pending_overlay_reconciliation = false
	_update_overlay_visibility(desired_overlay_ids)

func _reconcile_pending_navigation_overlays() -> void:
	if not _pending_overlay_reconciliation:
		return
	if _latest_navigation_state.is_empty():
		_pending_overlay_reconciliation = false
		return

	var desired_overlay_ids: Array[StringName] = _coerce_string_name_array(
		_latest_navigation_state.get("overlay_stack", [])
	)
	var current_stack: Array[StringName] = _get_overlay_scene_ids_from_ui()
	_reconcile_overlay_stack(desired_overlay_ids, current_stack)

func _get_longest_matching_prefix(stack_a: Array[StringName], stack_b: Array[StringName]) -> int:
	var limit: int = min(stack_a.size(), stack_b.size())
	for i in range(limit):
		if stack_a[i] != stack_b[i]:
			return i
	return limit

func _map_overlay_ids_to_scene_ids(overlay_ids: Array[StringName]) -> Array[StringName]:
	var mapped: Array[StringName] = []
	for overlay_id in overlay_ids:
		var definition: Dictionary = U_UI_REGISTRY.get_screen(overlay_id)
		if definition.is_empty():
			mapped.append(overlay_id)
			continue
		var scene_id_variant: Variant = definition.get("scene_id", overlay_id)
		if scene_id_variant is StringName:
			mapped.append(scene_id_variant)
		elif scene_id_variant is String:
			mapped.append(StringName(scene_id_variant))
		else:
			mapped.append(overlay_id)
	return mapped

func _coerce_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			if entry is StringName:
				result.append(entry)
			elif entry is String:
				result.append(StringName(entry))
	return result

func _push_overlay_scene_from_navigation(scene_id: StringName) -> bool:
	var before_count: int = 0
	if _ui_overlay_stack != null:
		before_count = _ui_overlay_stack.get_child_count()
	push_overlay(scene_id)
	if _ui_overlay_stack == null:
		return false
	var after_count: int = _ui_overlay_stack.get_child_count()
	return after_count > before_count

## Ensure scene_stack metadata matches actual overlay stack
func _sync_overlay_stack_state() -> void:
	if _store == null or _ui_overlay_stack == null:
		return

	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	if scene_state.is_empty():
		_update_particles_and_focus()
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
		_update_particles_and_focus()
		return

	if current_stack.size() > 0:
		_clear_scene_stack_state(current_stack.size())

	for scene_id in desired_stack:
		_store.dispatch(U_SCENE_ACTIONS.push_overlay(scene_id))

	_update_particles_and_focus()

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

## Update overlay visibility based on top overlay's hides_previous_overlays flag
func _update_overlay_visibility(overlay_ids: Array[StringName]) -> void:
	if _ui_overlay_stack == null or overlay_ids.is_empty():
		return

	# Check if top overlay should hide previous overlays
	var top_overlay_id: StringName = overlay_ids.back() if not overlay_ids.is_empty() else StringName("")
	var should_hide_previous: bool = false

	if top_overlay_id != StringName(""):
		var definition: Dictionary = U_UI_REGISTRY.get_screen(top_overlay_id)
		if not definition.is_empty():
			should_hide_previous = definition.get("hides_previous_overlays", false)

	# Update visibility of all overlays
	var child_count: int = _ui_overlay_stack.get_child_count()
	for i in range(child_count):
		var overlay: Node = _ui_overlay_stack.get_child(i)
		if overlay is CanvasItem:
			# Show all overlays if top doesn't hide, or show only the top overlay
			if should_hide_previous:
				overlay.visible = (i == child_count - 1)  # Only show top overlay
			else:
				overlay.visible = true  # Show all overlays

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

## Keep navigation shell/base scene aligned with the actual scene (manual transitions/tests)
## Phase 2 (T022): Removed _update_cursor_for_scene() - M_PauseManager now handles cursor state
func _sync_navigation_shell_with_scene(scene_id: StringName) -> void:
	if not _initial_navigation_synced:
		return
	if _store == null:
		return

	var nav_state: Dictionary = _store.get_slice(StringName("navigation"))
	if nav_state.is_empty():
		return

	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(scene_id)
	if scene_data.is_empty():
		return

	var scene_type: int = scene_data.get("scene_type", U_SCENE_REGISTRY.SceneType.GAMEPLAY)
	var desired_shell: StringName = nav_state.get("shell", StringName(""))
	match scene_type:
		U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			desired_shell = StringName("gameplay")
		U_SCENE_REGISTRY.SceneType.END_GAME:
			desired_shell = StringName("endgame")
		U_SCENE_REGISTRY.SceneType.MENU, U_SCENE_REGISTRY.SceneType.UI:
			desired_shell = StringName("main_menu")

	var current_shell: StringName = nav_state.get("shell", StringName(""))
	var current_scene: StringName = nav_state.get("base_scene_id", StringName(""))

	# If navigation already matches the loaded scene, no reconciliation needed.
	if current_shell == desired_shell and current_scene == scene_id:
		return

	# When a navigation-driven transition is in progress, the navigation slice
	# is the source of truth. Avoid clobbering a newer navigation target with
	# stale scene_id values from earlier transitions.
	if _navigation_pending_scene_id != StringName(""):
		# If navigation has requested a DIFFERENT scene than the one that just
		# finished loading, skip reconciliation entirely. This prevents races
		# where a late _sync_navigation_shell_with_scene call for a previous
		# scene overwrites the more recent navigation target.
		if _navigation_pending_scene_id != scene_id:
			return
		# If the pending navigation target matches the scene_id, the reducer
		# has already updated base_scene_id. Treat this as in-sync and skip.
		return

	match scene_type:
		U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			_store.dispatch(U_NAVIGATION_ACTIONS.start_game(scene_id))
		U_SCENE_REGISTRY.SceneType.END_GAME:
			_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(desired_shell, scene_id))
		U_SCENE_REGISTRY.SceneType.MENU, U_SCENE_REGISTRY.SceneType.UI:
			_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(desired_shell, scene_id))
		_:
			_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(desired_shell, scene_id))

## Configure transition-specific settings (T209)
##
## Applies default configuration to transition effects after creation by factory.
## Centralizes transition configuration that was previously in _create_transition_effect().
##
## Parameters:
##   transition: The transition effect instance to configure
##   transition_type: The transition type name (for type-checking)
func _configure_transition(transition: BaseTransitionEffect, transition_type: String) -> void:
	if transition == null:
		return

	# Configure fade transitions
	if transition is FADE_TRANSITION:
		var fade := transition as FADE_TRANSITION
		fade.duration = 0.2  # Shorter duration for faster tests

	# Configure loading screen transitions
	if transition is LOADING_SCREEN_TRANSITION:
		var loading := transition as LOADING_SCREEN_TRANSITION
		loading.min_duration = 1.5  # Minimum display time



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
		return

	# Start async load for each critical scene
	for scene_data in critical_scenes:
		var scene_id: StringName = scene_data.get("scene_id", StringName(""))
		var scene_path: String = scene_data.get("path", "")

		if scene_path.is_empty():
			push_warning("M_SceneManager: Critical scene '%s' has empty path" % scene_id)
			continue

		# Skip if already cached
		if _is_scene_cached(scene_path):
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

## Validate scene contract (Phase 12.5 - T306)
##
## Checks that loaded scene meets required contract based on scene type.
## Logs errors and warnings but does NOT block scene loading (fail-safe design).
##
## Parameters:
##   scene: The loaded scene to validate
##   scene_id: Scene identifier for looking up scene type
##
## Returns:
##   void (logs errors but always continues)
func _validate_scene_contract(scene: Node, scene_id: StringName) -> void:
	if scene == null:
		return

	# Skip validation for test scenes (res://tests/* paths)
	var scene_path: String = U_SCENE_REGISTRY.get_scene_path(scene_id)
	if scene_path.begins_with("res://tests/"):
		return

	# Get scene type from registry
	var registry_type: int = U_SCENE_REGISTRY.get_scene_type(scene_id)

	# Map registry SceneType to contract SceneType
	var contract_type: I_SCENE_CONTRACT.SceneType
	match registry_type:
		U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			contract_type = I_SCENE_CONTRACT.SceneType.GAMEPLAY
		U_SCENE_REGISTRY.SceneType.UI, U_SCENE_REGISTRY.SceneType.MENU, U_SCENE_REGISTRY.SceneType.END_GAME:
			contract_type = I_SCENE_CONTRACT.SceneType.UI
		_:
			# Unknown type - skip validation
			return

	# Create validator and validate scene
	var validator := I_SCENE_CONTRACT.new()
	var result: Dictionary = validator.validate_scene(scene, contract_type)

	# Log validation results
	if not result.get("valid", true):
		push_warning("Scene '%s' failed contract validation:" % scene_id)
		var errors: Array = result.get("errors", [])
		for error in errors:
			push_warning("  - %s" % error)

	# Log warnings (if any)
	var warnings: Array = result.get("warnings", [])
