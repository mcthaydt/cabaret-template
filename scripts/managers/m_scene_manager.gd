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
const U_SCENE_CACHE := preload("res://scripts/scene_management/helpers/u_scene_cache.gd")
const U_SCENE_LOADER := preload("res://scripts/scene_management/helpers/u_scene_loader.gd")
const U_OVERLAY_STACK_MANAGER := preload("res://scripts/scene_management/helpers/u_overlay_stack_manager.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const C_VICTORY_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")
const U_TRANSITION_ORCHESTRATOR := preload("res://scripts/scene_management/u_transition_orchestrator.gd")
# T209: Transition class imports removed - now handled by U_TransitionFactory
# Kept for type checking only:
const FADE_TRANSITION := preload("res://scripts/scene_management/transitions/trans_fade.gd")
const LOADING_SCREEN_TRANSITION := preload("res://scripts/scene_management/transitions/trans_loading_screen.gd")

# T137a: Phase 10B-3 - Scene type handler imports
const I_SCENE_TYPE_HANDLER := preload("res://scripts/scene_management/i_scene_type_handler.gd")
const H_GAMEPLAY_SCENE_HANDLER := preload("res://scripts/scene_management/handlers/h_gameplay_scene_handler.gd")
const H_MENU_SCENE_HANDLER := preload("res://scripts/scene_management/handlers/h_menu_scene_handler.gd")
const H_UI_SCENE_HANDLER := preload("res://scripts/scene_management/handlers/h_ui_scene_handler.gd")
const H_ENDGAME_SCENE_HANDLER := preload("res://scripts/scene_management/handlers/h_endgame_scene_handler.gd")

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
var _store: I_StateStore = null
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
## Backed by U_SceneCache helper
var _scene_cache_helper := U_SCENE_CACHE.new()

## Cache: path → PackedScene (exposed for tests via manager properties)
var _scene_cache:
	get:
		return _scene_cache_helper._scene_cache

## Background loading tracking (Phase 8)
## Key: path (String), Value: { scene_id, status, start_time }
var _background_loads:
	get:
		return _scene_cache_helper._background_loads

## Cache limits (Phase 8)
var _max_cached_scenes:
	get:
		return _scene_cache_helper._max_cached_scenes
	set(value):
		_scene_cache_helper._max_cached_scenes = int(value)
var _max_cache_memory:
	get:
		return _scene_cache_helper._max_cache_memory
	set(value):
		_scene_cache_helper._max_cache_memory = int(value)

## LRU tracking (Phase 8)
## Key: path (String), Value: timestamp (float)
var _cache_access_times:
	get:
		return _scene_cache_helper._cache_access_times

## Background polling active flag (Phase 8)
var _is_background_polling_active:
	get:
		return _scene_cache_helper._is_background_polling_active

## Helpers
var _scene_loader := U_SCENE_LOADER.new()
var _overlay_helper := U_OVERLAY_STACK_MANAGER.new()
var _transition_orchestrator := U_TRANSITION_ORCHESTRATOR.new()

## Scene type handlers (T137a: Phase 10B-3)
## Maps SceneType enum values to handler instances
var _scene_type_handlers: Dictionary = {}  # int (SceneType) -> I_SCENE_TYPE_HANDLER

## Store subscription
var _unsubscribe: Callable

## ECS event bus subscriptions
var _entity_death_unsubscribe: Callable
var _victory_triggered_unsubscribe: Callable

## Skip initial scene load (for tests)
var skip_initial_scene_load: bool = false

## Initial scene to load on startup (configurable for testing)
@export var initial_scene_id: StringName = StringName("main_menu")

func _ready() -> void:
	# Add to scene_manager group for discovery
	add_to_group("scene_manager")

	# Find managers via ServiceLocator (Phase 10B-7: T141c)
	await get_tree().process_frame  # Wait for ServiceLocator to initialize

	_store = U_ServiceLocator.get_service(StringName("state_store")) as M_StateStore
	if not _store:
		push_error("M_SceneManager: No M_StateStore registered with ServiceLocator")
		return

	# Optional dependencies - use try_get_service to avoid error spam in tests
	_cursor_manager = U_ServiceLocator.try_get_service(StringName("cursor_manager")) as M_CursorManager
	if not _cursor_manager:
		push_warning("M_SceneManager: No M_CursorManager registered with ServiceLocator")

	# Find M_SpawnManager via ServiceLocator (Phase 12.1: T225)
	_spawn_manager = U_ServiceLocator.try_get_service(StringName("spawn_manager"))
	if not _spawn_manager:
		push_warning("M_SceneManager: No M_SpawnManager registered with ServiceLocator")

	# Find M_CameraManager via ServiceLocator (Phase 12.2: T243)
	_camera_manager = U_ServiceLocator.try_get_service(StringName("camera_manager"))
	if not _camera_manager:
		push_warning("M_SceneManager: No M_CameraManager found in 'camera_manager' group")

	# Find container nodes
	_find_container_nodes()
	_sync_overlay_stack_state()

	# Subscribe to scene slice updates
	if _store != null:
		_unsubscribe = _store.subscribe(_on_state_changed)
		if not _store.slice_updated.is_connected(_on_slice_updated):
			_store.slice_updated.connect(_on_slice_updated)
			_navigation_slice_connected = true

	# Subscribe to ECS events with priorities
	# entity_death: Priority 10 (high - quick transition to game over)
	_entity_death_unsubscribe = U_ECS_EVENT_BUS.subscribe(StringName("entity_death"), _on_entity_death, 10)
	# victory_triggered: Priority 5 (medium - after S_VictorySystem processes state)
	_victory_triggered_unsubscribe = U_ECS_EVENT_BUS.subscribe(StringName("victory_triggered"), _on_victory_triggered, 5)

	# Register scene type handlers (T137c: Phase 10B-3)
	_register_scene_type_handlers()

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


## Register all scene type handlers (T137c: Phase 10B-3)
##
## Creates handler instances for each SceneType enum value and registers them
## in the _scene_type_handlers dictionary. Handlers encapsulate scene-type-specific
## behavior for loading, unloading, and navigation.
func _register_scene_type_handlers() -> void:
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.GAMEPLAY] = H_GAMEPLAY_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.MENU] = H_MENU_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.UI] = H_UI_SCENE_HANDLER.new()
	_scene_type_handlers[U_SCENE_REGISTRY.SceneType.END_GAME] = H_ENDGAME_SCENE_HANDLER.new()


func _exit_tree() -> void:
	# Unsubscribe from state updates
	if _unsubscribe != null and _unsubscribe.is_valid():
		_unsubscribe.call()
	if _store != null and _navigation_slice_connected and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	_navigation_slice_connected = false

	# Unsubscribe from ECS events
	if _entity_death_unsubscribe != null and _entity_death_unsubscribe.is_valid():
		_entity_death_unsubscribe.call()
	if _victory_triggered_unsubscribe != null and _victory_triggered_unsubscribe.is_valid():
		_victory_triggered_unsubscribe.call()

## Find container nodes in the scene tree
func _find_container_nodes() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var root: Node = self
	# Walk up until we reach the scene root (direct child of SceneTree.root),
	# so we only search within the same root scene as this manager.
	while root.get_parent() != null and root.get_parent() != tree.root:
		root = root.get_parent()
	if root.get_parent() != tree.root:
		root = tree.root
	# Find ActiveSceneContainer
	_active_scene_container = root.find_child("ActiveSceneContainer", true, false)
	if _active_scene_container == null:
		push_error("M_SceneManager: ActiveSceneContainer not found")

	# Find UIOverlayStack
	_ui_overlay_stack = root.find_child("UIOverlayStack", true, false)
	if _ui_overlay_stack == null:
		push_error("M_SceneManager: UIOverlayStack not found")

	# Find TransitionOverlay (check ServiceLocator first for test environments)
	_transition_overlay = U_ServiceLocator.try_get_service(StringName("transition_overlay")) as CanvasLayer
	if _transition_overlay == null:
		_transition_overlay = root.find_child("TransitionOverlay", true, false)
	if _transition_overlay == null:
		push_error("M_SceneManager: TransitionOverlay not found")

	# Find LoadingOverlay (check ServiceLocator first for test environments)
	_loading_overlay = U_ServiceLocator.try_get_service(StringName("loading_overlay")) as CanvasLayer
	if _loading_overlay == null:
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

## ECS event handler: entity_death
## Phase 10B (T130): Subscribe to entity_death event instead of direct call from S_HealthSystem
func _on_entity_death(event: Dictionary) -> void:
	# Trigger game over transition when player dies
	transition_to_scene(StringName("game_over"), "fade", Priority.CRITICAL)

## ECS event handler: victory_triggered
## Phase 10B (T131): Subscribe to victory_triggered event instead of direct call from S_VictorySystem
func _on_victory_triggered(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var trigger := payload.get("trigger_node") as C_VictoryTriggerComponent
	if trigger == null or not is_instance_valid(trigger):
		return

	# Determine target scene based on victory type
	var target_scene := _get_victory_target_scene(trigger)
	transition_to_scene(target_scene, "fade", Priority.HIGH)

## Determine target scene for victory transition
func _get_victory_target_scene(trigger: C_VictoryTriggerComponent) -> StringName:
	match trigger.victory_type:
		C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE:
			return StringName("victory")
		_:
			return StringName("exterior")

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

	# Phase 8: Check if scene is cached
	var use_cached: bool = _is_scene_cached(scene_path)

	# Phase 8: Create progress callback for async loading
	# T208: Array wrapper for closure to capture mutable value (see method doc comment)
	var current_progress: Array = [0.0]
	var progress_callback: Callable = func(progress: float) -> void:
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

		# Determine scene type for handler delegation
		var scene_type: int = U_SCENE_REGISTRY.get_scene_type(request.scene_id)

		# T137c (Phase 10B-3): Set gameplay metadata BEFORE adding to tree
		# This must happen before _ready() calls fire, so M_GameplayInitializer sees it
		if scene_type == U_SCENE_REGISTRY.SceneType.GAMEPLAY:
			new_scene.set_meta("_scene_manager_spawned", true)

		# Add new scene to ActiveSceneContainer
		if _active_scene_container != null:
			_add_scene(new_scene)
		# Store for post-transition finalization
		new_scene_ref[0] = new_scene

		# Phase 12.2: Blend cameras using M_CameraManager (T244)
		# IMPORTANT: Start camera blend IMMEDIATELY after scene is added, BEFORE spawn waits.
		# This ensures the camera blend tween exists for tests that query it during transitions.
		# The spawn waits (frame waits + spawn operations) can delay tween creation and cause
		# tests to timeout when waiting for the tween.
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

		# T137c (Phase 10B-3): Delegate scene-type-specific load behavior to handler
		# Handlers encapsulate scene-type logic (metadata, spawning, etc.)
		# Wait for scene tree to fully initialize before calling handler
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().process_frame  # Extra wait for deferred operations

		# Check scene is still valid before handler call (can be freed during test cleanup)
		if is_instance_valid(new_scene):
			var handler := _scene_type_handlers.get(scene_type) as I_SCENE_TYPE_HANDLER
			if handler != null:
				var managers := {
					"spawn_manager": _spawn_manager,
					"state_store": _store
				}
				await handler.on_load(new_scene, request.scene_id, managers)

		scene_swap_complete[0] = true

	# Phase 10B-2 (T136b): Delegate transition effect execution to TransitionOrchestrator
	var overlays := {
		"transition_overlay": _transition_overlay,
		"loading_overlay": _loading_overlay
	}

	await _transition_orchestrator.execute_transition_effect(
		request.transition_type,
		scene_swap_callback,
		func() -> void: pass,  # Completion handled below
		overlays
	)

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
	_scene_loader.unfreeze_player_physics(scene)

## Find player in scene tree
func _find_player_in_scene(scene: Node) -> Node3D:
	return _scene_loader.find_player_in_scene(scene)

## Remove current scene from ActiveSceneContainer
func _remove_current_scene() -> void:
	_scene_loader.remove_current_scene(_active_scene_container)

## Load scene via ResourceLoader (sync for now)
func _load_scene(scene_path: String) -> Node:
	return _scene_loader.load_scene(scene_path)

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
	return await _scene_loader.load_scene_async(scene_path, progress_callback, _background_loads)

## Add scene to ActiveSceneContainer
func _add_scene(scene: Node) -> void:
	_scene_loader.add_scene(_active_scene_container, scene)

## Push overlay scene onto UIOverlayStack
func push_overlay(scene_id: StringName, force: bool = false) -> void:
	_overlay_helper.push_overlay(self, scene_id, force)

## Pop top overlay from UIOverlayStack
func pop_overlay() -> void:
	_overlay_helper.pop_overlay(self)

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
	_overlay_helper.push_overlay_with_return(self, overlay_id)

## Pop overlay with automatic return navigation (Phase 6.5)
##
## Pops the current overlay and restores the previous overlay from the return stack.
## If the return stack is empty, this behaves like pop_overlay().
## If the return stack has a non-empty overlay ID, that overlay is pushed.
##
## This provides stack-based overlay navigation without hardcoded logic.
func pop_overlay_with_return() -> void:
	_overlay_helper.pop_overlay_with_return(self)

## Internal: deferred restore helper for return navigation
func _push_overlay_for_return(scene_id: StringName) -> void:
	push_overlay(scene_id, true)

## Get the scene_id of the current top overlay (helper for return stack)
##
## Returns StringName("") if no overlays are active.
func _get_top_overlay_id() -> StringName:
	return _overlay_helper.get_top_overlay_id(self)

## Configure overlay scene for pause handling
func _configure_overlay_scene(overlay_scene: Node, scene_id: StringName) -> void:
	_overlay_helper.configure_overlay_scene(overlay_scene, scene_id)

func _restore_focus_to_top_overlay() -> void:
	_overlay_helper.restore_focus_to_top_overlay(self)

func _find_first_focusable_in(root: Node) -> Control:
	return _overlay_helper.find_first_focusable_in(root)

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

	# Default transition settings come from the scene registry.
	var transition_type: String = String(scene_data.get("default_transition", "instant"))
	var priority: int = Priority.HIGH

	# Navigation slice may provide override metadata (e.g., endgame flows
	# that should use instant transitions instead of long fades).
	if not _latest_navigation_state.is_empty():
		var metadata: Dictionary = _latest_navigation_state.get("_transition_metadata", {})
		if not metadata.is_empty():
			var type_variant: Variant = metadata.get("transition_type", transition_type)
			if type_variant is String:
				transition_type = String(type_variant)
			var priority_variant: Variant = metadata.get("priority", priority)
			if priority_variant is int:
				priority = int(priority_variant)

	if transition_type.is_empty():
		transition_type = "instant"

	transition_to_scene(desired_scene_id, transition_type, priority)
	_navigation_pending_scene_id = desired_scene_id

func _is_scene_in_queue(scene_id: StringName) -> bool:
	for request in _transition_queue:
		if request is TransitionRequest and request.scene_id == scene_id:
			return true
	return false

func _reconcile_overlay_stack(desired_overlay_ids: Array[StringName], current_stack: Array[StringName]) -> void:
	_overlay_helper.reconcile_overlay_stack(self, desired_overlay_ids, current_stack)

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
	return _overlay_helper.get_overlay_scene_ids_from_ui(self)

## Clear scene_stack metadata by dispatching pop actions
func _clear_scene_stack_state(count: int) -> void:
	if _store == null or count <= 0:
		return

	for _i in range(count):
		_store.dispatch(U_SCENE_ACTIONS.pop_overlay())

## Compare overlay stacks for equality
func _overlay_stacks_match(stack_a: Array[StringName], stack_b: Array[StringName]) -> bool:
	return _overlay_helper.overlay_stacks_match(stack_a, stack_b)

## Update overlay visibility based on top overlay's hides_previous_overlays flag
func _update_overlay_visibility(overlay_ids: Array[StringName]) -> void:
	_overlay_helper.update_overlay_visibility(self, overlay_ids)

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

	# T137c (Phase 10B-3): Delegate shell determination to handler
	var handler := _scene_type_handlers.get(scene_type) as I_SCENE_TYPE_HANDLER
	if handler == null:
		push_error("M_SceneManager: No handler registered for scene_type %d" % scene_type)
		return

	var desired_shell: StringName = handler.get_shell_id()

	var current_shell: StringName = nav_state.get("shell", StringName(""))
	var current_scene: StringName = nav_state.get("base_scene_id", StringName(""))

	# If navigation already matches the loaded scene, no reconciliation needed.
	if current_shell == desired_shell and current_scene == scene_id:
		return

	# When a navigation-driven transition is in progress, the navigation slice
	# is the source of truth. Avoid clobbering a newer navigation target with
	# stale scene_id values from earlier transitions.
	if _navigation_pending_scene_id != StringName(""):
		# Endgame scenes (death/victory) must always override any stale pending
		# navigation targets so UI state matches the actual loaded screen.
		if scene_type == U_SCENE_REGISTRY.SceneType.END_GAME:
			_navigation_pending_scene_id = StringName("")
		else:
			# If navigation has requested a DIFFERENT scene than the one that just
			# finished loading, skip reconciliation entirely. This prevents races
			# where a late _sync_navigation_shell_with_scene call for a previous
			# scene overwrites the more recent navigation target.
			if _navigation_pending_scene_id != scene_id:
				return
			# If the pending navigation target matches the scene_id, the reducer
			# has already updated base_scene_id. Treat this as in-sync and skip.
			return

	# T137c (Phase 10B-3): Dispatch navigation action from handler
	var nav_action := handler.get_navigation_action(scene_id)
	if not nav_action.is_empty():
		_store.dispatch(nav_action)

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

	# T112 + T137c (Phase 10B-3): Delegate history tracking decision to handlers
	# Add current scene to history BEFORE transitioning (if handler says to track)
	var current_handler := _scene_type_handlers.get(current_scene_type) as I_SCENE_TYPE_HANDLER
	var should_track_current: bool = current_handler != null and current_handler.should_track_history()

	if should_track_current and not _current_scene_id.is_empty():
		# Avoid adding duplicate consecutive entries
		if _scene_history.is_empty() or _scene_history.back() != _current_scene_id:
			_scene_history.append(_current_scene_id)

	# T113 + T137c (Phase 10B-3): Clear history if target scene handler doesn't track
	# (e.g., GAMEPLAY scenes clear history stack, END_GAME scenes don't track)
	var target_handler := _scene_type_handlers.get(target_scene_type) as I_SCENE_TYPE_HANDLER
	if target_handler != null and not target_handler.should_track_history():
		_scene_history.clear()

## ============================================================================
## Phase 8: Scene Cache Management
## ============================================================================

## Check if scene is cached
func _is_scene_cached(scene_path: String) -> bool:
	return _scene_cache_helper.is_scene_cached(scene_path)

## Get cached PackedScene (updates LRU access time)
func _get_cached_scene(scene_path: String) -> PackedScene:
	return _scene_cache_helper.get_cached_scene(scene_path)

## Add PackedScene to cache (with eviction if needed)
func _add_to_cache(scene_path: String, packed_scene: PackedScene) -> void:
	_scene_cache_helper.add_to_cache(scene_path, packed_scene)

## Check cache pressure and evict if necessary (hybrid policy)
func _check_cache_pressure() -> void:
	_scene_cache_helper._check_cache_pressure()

## Evict least-recently-used scene from cache
func _evict_cache_lru() -> void:
	_scene_cache_helper._evict_cache_lru()

## Get estimated cache memory usage in bytes
func _get_cache_memory_usage() -> int:
	return _scene_cache_helper._get_cache_memory_usage()

## ============================================================================
## Phase 8: Scene Preloading at Startup
## ============================================================================

## Preload critical scenes at startup (Phase 8)
##
## Loads scenes with priority >= 10 in background for instant transitions.
## Critical scenes: main_menu, pause_menu, loading_screen
func _preload_critical_scenes() -> void:
	var critical_scenes: Array = U_SCENE_REGISTRY.get_preloadable_scenes(10)
	_scene_cache_helper.preload_critical_scenes(critical_scenes)

## Start background polling loop for preloaded scenes (Phase 8)
func _start_background_load_polling() -> void:
	await _scene_cache_helper._start_background_load_polling()

## Hint to preload a scene in background (Phase 8)
##
## Called when player approaches a door trigger to preload target scene.
## Non-blocking - loads in background while player is in trigger zone.
##
## @param scene_path: Resource path to .tscn file
func hint_preload_scene(scene_path: String) -> void:
	_scene_cache_helper.hint_preload_scene(scene_path)

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
	_scene_loader.validate_scene_contract(scene, scene_id)
