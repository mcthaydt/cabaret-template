@icon("res://assets/editor_icons/icn_manager.svg")
extends Node
class_name M_PauseManager

## Pause Manager - SOLE AUTHORITY for engine pause and cursor coordination
##
## Phase 2 (T021): Refactored to derive pause and cursor state from scene slice.
## Phase 2.1 (Post-T021): Added UIOverlayStack reference to bridge state sync timing gap.
##
## Responsibilities:
## - Subscribe to scene slice updates
## - Derive pause from scene.scene_stack size (overlays = paused)
## - Check UIOverlayStack directly for immediate pause detection (bridges timing gap)
## - Apply engine-level pause (get_tree().paused)
## - Coordinate cursor state with M_CursorManager based on BOTH pause state AND scene type
## - Emit pause_state_changed signal for other systems
##
## Cursor logic:
## - If paused (overlays present): cursor visible & unlocked
## - If not paused:
##   - MENU/UI/END_GAME scenes: cursor visible & unlocked
##   - GAMEPLAY scenes: cursor hidden & locked
##
## Does NOT handle input directly - pause/unpause flows through scene overlay actions.

signal pause_state_changed(is_paused: bool)


var _store: I_StateStore = null
var _cursor_manager: M_CursorManager = null
var _ui_overlay_stack: CanvasLayer = null
var _is_paused: bool = false
var _current_scene_id: StringName = StringName("")
var _current_scene_type: int = -1

func _init() -> void:
	# CRITICAL: Pause system must process even when tree is paused
	# Otherwise it can't unpause the tree or handle scene transitions
	# Set this in _init() so it's active before _ready()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# Get reference to state store via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	_store = U_ServiceLocator.try_get_service(StringName("state_store")) as M_StateStore

	if not _store:
		# Phase 10B (T133): Warn if M_StateStore missing for fail-fast feedback
		# This is normal in some test environments without a full state store
		push_warning("M_PauseManager: M_StateStore not ready during _ready(). Deferring initialization.")
		call_deferred("_deferred_init")
		return

	# Store exists - initialize immediately
	_initialize()

## Deferred initialization if store isn't ready yet
func _deferred_init() -> void:
	# Use try_get_service to avoid errors in test environments
	_store = U_ServiceLocator.try_get_service(StringName("state_store")) as M_StateStore

	if not _store:
		# No store available - pause system will remain inactive
		# This is expected in test environments that don't use state management
		return

	_initialize()

## Main initialization logic
func _initialize() -> void:
	# Get reference to cursor manager via ServiceLocator (Phase 10B-7: T141c)
	# Optional - pause still works without it. Use try_get_service to avoid errors in test environments.
	_cursor_manager = U_ServiceLocator.try_get_service(StringName("cursor_manager")) as M_CursorManager

	# Get reference to UIOverlayStack (for immediate pause detection)
	_ui_overlay_stack = get_tree().root.find_child("UIOverlayStack", true, false)
	# Note: UIOverlayStack is optional in test environments - pause still works via scene state

	# Subscribe to scene slice updates (Phase 2: derive pause and cursor from scene slice)
	_store.slice_updated.connect(_on_slice_updated)

	# Read initial state from scene slice
	var full_state: Dictionary = _store.get_state()
	var scene_state: Dictionary = full_state.get("scene", {})

	# Pause is determined by overlay stack size from BOTH state and actual UI
	var scene_stack: Array = scene_state.get("scene_stack", [])
	var has_overlays_in_state: bool = scene_stack.size() > 0
	var has_overlays_in_ui: bool = _ui_overlay_stack != null and _ui_overlay_stack.get_child_count() > 0
	# Use OR logic: pause if either state or UI indicates overlays exist
	_is_paused = has_overlays_in_state or has_overlays_in_ui

	_current_scene_id = scene_state.get("current_scene_id", StringName(""))
	_current_scene_type = _get_scene_type(_current_scene_id)

	_apply_pause_and_cursor_state()

	# NOTE: _process() will continuously poll and correct any state mismatches

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

## Poll UI overlay stack to detect changes not captured by state updates
## This handles cases where M_SceneManager modifies UI without dispatching state actions
## Using _process instead of _physics_process for more responsive updates
func _process(_delta: float) -> void:
	_check_and_resync_pause_state()

## Check if pause state is out of sync and resynchronize if needed
func _check_and_resync_pause_state() -> void:
	if not _store or not _ui_overlay_stack:
		return

	# Check if UI overlay count has changed since last update
	var current_ui_count: int = _ui_overlay_stack.get_child_count()
	var has_overlays_in_ui: bool = current_ui_count > 0

	# Get current scene state
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	var scene_stack: Array = scene_state.get("scene_stack", [])
	var has_overlays_in_state: bool = scene_stack.size() > 0

	# Calculate what pause state SHOULD be
	var should_be_paused: bool = has_overlays_in_state or has_overlays_in_ui

	# If there's a mismatch between our internal state and what it should be, OR
	# if the engine pause doesn't match our internal state, force a resync
	if should_be_paused != _is_paused or get_tree().paused != _is_paused:
		var pause_changed: bool = should_be_paused != _is_paused
		_is_paused = should_be_paused
		_apply_pause_and_cursor_state()

		if pause_changed:
			pause_state_changed.emit(_is_paused)

## Handle state store slice updates (Phase 2: watch scene slice for both pause and scene type)
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("scene"):
		return

	var state_changed: bool = false
	var pause_changed: bool = false

	# Check pause state (derived from scene_stack size AND actual UI)
	var scene_stack: Array = slice_state.get("scene_stack", [])
	var has_overlays_in_state: bool = scene_stack.size() > 0
	var has_overlays_in_ui: bool = _ui_overlay_stack != null and _ui_overlay_stack.get_child_count() > 0
	var new_paused: bool = has_overlays_in_state or has_overlays_in_ui

	if new_paused != _is_paused:
		_is_paused = new_paused
		state_changed = true
		pause_changed = true

	# CRITICAL FIX: Also detect when engine pause state is out of sync with our internal state
	# This can happen when external code (like test cleanup) modifies get_tree().paused
	if get_tree().paused != _is_paused:
		state_changed = true

	# Check scene type changes
	var new_scene_id: StringName = slice_state.get("current_scene_id", StringName(""))
	if new_scene_id != _current_scene_id:
		_current_scene_id = new_scene_id
		_current_scene_type = _get_scene_type(_current_scene_id)
		state_changed = true

	# Apply changes if pause or scene type changed, OR if engine pause is out of sync
	if state_changed:
		_apply_pause_and_cursor_state()
		# Emit signal only if pause state changed
		if pause_changed:
			pause_state_changed.emit(_is_paused)

## Apply pause state to engine and cursor (Phase 2: SOLE AUTHORITY for both)
##
## Cursor logic:
## - If paused (overlay stack not empty): cursor visible & unlocked
## - If not paused:
##   - MENU/UI/END_GAME scenes: cursor visible & unlocked
##   - GAMEPLAY scenes: cursor hidden & locked
func _apply_pause_and_cursor_state() -> void:
	# Apply pause to engine
	get_tree().paused = _is_paused

	# Coordinate cursor state based on pause AND scene type
	if _cursor_manager:
		if _is_paused:
			# Paused: show cursor for UI interaction (overlays)
			_cursor_manager.set_cursor_state(false, true)
		else:
			# Not paused: cursor depends on scene type
			match _current_scene_type:
				U_SceneRegistry.SceneType.MENU, U_SceneRegistry.SceneType.UI, U_SceneRegistry.SceneType.END_GAME:
					# UI scenes: cursor visible & unlocked
					_cursor_manager.set_cursor_state(false, true)
				U_SceneRegistry.SceneType.GAMEPLAY:
					# Gameplay scenes: cursor hidden & locked
					_cursor_manager.set_cursor_state(true, false)
				_:
					# Unknown scene type: default to locked & hidden (safe default)
					_cursor_manager.set_cursor_state(true, false)

## Get scene type from scene ID
func _get_scene_type(scene_id: StringName) -> int:
	if scene_id.is_empty():
		return -1
	var scene_data: Dictionary = U_SceneRegistry.get_scene(scene_id)
	if scene_data.is_empty():
		return -1
	return scene_data.get("scene_type", -1)

## Check if game is currently paused (for other systems)
func is_paused() -> bool:
	return _is_paused
