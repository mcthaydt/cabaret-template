@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_time_manager.gd"
class_name M_TimeManager

signal pause_state_changed(is_paused: bool)
signal timescale_changed(new_scale: float)
signal world_hour_changed(hour: int)

const U_PAUSE_SYSTEM := preload("res://scripts/managers/helpers/time/u_pause_system.gd")
const U_TIMESCALE_CONTROLLER := preload("res://scripts/managers/helpers/time/u_timescale_controller.gd")

var _store: I_StateStore = null
var _cursor_manager: M_CursorManager = null
var _ui_overlay_stack: CanvasLayer = null
var _pause_system = U_PAUSE_SYSTEM.new()
var _timescale_controller = U_TIMESCALE_CONTROLLER.new()
var _is_paused: bool = false
var _current_scene_id: StringName = StringName("")
var _current_scene_type: int = -1

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_store = U_ServiceLocator.try_get_service(StringName("state_store")) as I_StateStore
	if not _store:
		push_warning("M_TimeManager: M_StateStore not ready during _ready(). Deferring initialization.")
		call_deferred("_deferred_init")
		return
	_initialize()

func _deferred_init() -> void:
	_store = U_ServiceLocator.try_get_service(StringName("state_store")) as I_StateStore
	if not _store:
		return
	_initialize()

func _initialize() -> void:
	_cursor_manager = U_ServiceLocator.try_get_service(StringName("cursor_manager")) as M_CursorManager
	_ui_overlay_stack = get_tree().root.find_child("UIOverlayStack", true, false) as CanvasLayer

	_store.slice_updated.connect(_on_slice_updated)

	var full_state: Dictionary = _store.get_state()
	var scene_state: Dictionary = full_state.get("scene", {})
	var scene_stack: Array = scene_state.get("scene_stack", [])
	var ui_overlay_count: int = 0
	if _ui_overlay_stack != null:
		ui_overlay_count = _ui_overlay_stack.get_child_count()
	var total_overlay_count: int = maxi(ui_overlay_count, scene_stack.size())
	_pause_system.derive_pause_from_overlay_state(total_overlay_count)

	_is_paused = _pause_system.compute_is_paused()
	_current_scene_id = scene_state.get("current_scene_id", StringName(""))
	_current_scene_type = _get_scene_type(_current_scene_id)

	_apply_pause_and_cursor_state()

func _exit_tree() -> void:
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

func _process(__delta: float) -> void:
	_check_and_resync_pause_state()

func _check_and_resync_pause_state() -> void:
	if not _store or not _ui_overlay_stack:
		return

	var current_ui_count: int = _ui_overlay_stack.get_child_count()
	var scene_state: Dictionary = _store.get_slice(StringName("scene"))
	var scene_stack: Array = scene_state.get("scene_stack", [])
	var total_overlay_count: int = maxi(current_ui_count, scene_stack.size())
	_pause_system.derive_pause_from_overlay_state(total_overlay_count)

	var should_be_paused: bool = _pause_system.compute_is_paused()
	if should_be_paused != _is_paused or get_tree().paused != _is_paused:
		var pause_changed: bool = should_be_paused != _is_paused
		_is_paused = should_be_paused
		_apply_pause_and_cursor_state()
		if pause_changed:
			pause_state_changed.emit(_is_paused)

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("scene"):
		return

	var state_changed: bool = false
	var pause_changed: bool = false

	var scene_stack: Array = slice_state.get("scene_stack", [])
	var ui_overlay_count: int = 0
	if _ui_overlay_stack != null:
		ui_overlay_count = _ui_overlay_stack.get_child_count()
	var total_overlay_count: int = maxi(ui_overlay_count, scene_stack.size())
	_pause_system.derive_pause_from_overlay_state(total_overlay_count)
	var new_paused: bool = _pause_system.compute_is_paused()

	if new_paused != _is_paused:
		_is_paused = new_paused
		state_changed = true
		pause_changed = true

	if get_tree().paused != _is_paused:
		state_changed = true

	var new_scene_id: StringName = slice_state.get("current_scene_id", StringName(""))
	if new_scene_id != _current_scene_id:
		_current_scene_id = new_scene_id
		_current_scene_type = _get_scene_type(_current_scene_id)
		state_changed = true

	if state_changed:
		_apply_pause_and_cursor_state()
		if pause_changed:
			pause_state_changed.emit(_is_paused)

func _apply_pause_and_cursor_state() -> void:
	get_tree().paused = _is_paused

	if _cursor_manager:
		if _is_paused:
			_cursor_manager.set_cursor_state(false, true)
		else:
			match _current_scene_type:
				U_SceneRegistry.SceneType.MENU, U_SceneRegistry.SceneType.UI, U_SceneRegistry.SceneType.END_GAME:
					_cursor_manager.set_cursor_state(false, true)
				U_SceneRegistry.SceneType.GAMEPLAY:
					_cursor_manager.set_cursor_state(true, false)
				_:
					_cursor_manager.set_cursor_state(true, false)

func _get_scene_type(scene_id: StringName) -> int:
	if scene_id.is_empty():
		return -1
	var scene_data: Dictionary = U_SceneRegistry.get_scene(scene_id)
	if scene_data.is_empty():
		return -1
	return scene_data.get("scene_type", -1)

func is_paused() -> bool:
	return _is_paused

func request_pause(channel: StringName) -> void:
	_pause_system.request_pause(channel)
	_check_and_resync_pause_state()

func release_pause(channel: StringName) -> void:
	_pause_system.release_pause(channel)
	_check_and_resync_pause_state()

func is_channel_paused(channel: StringName) -> bool:
	return _pause_system.is_channel_paused(channel)

func get_active_pause_channels() -> Array[StringName]:
	return _pause_system.get_active_channels()

func set_timescale(scale: float) -> void:
	_timescale_controller.set_timescale(scale)
	timescale_changed.emit(_timescale_controller.get_timescale())

func get_timescale() -> float:
	return _timescale_controller.get_timescale()

func get_scaled_delta(raw_delta: float) -> float:
	return _timescale_controller.get_scaled_delta(raw_delta)

func get_world_time() -> Dictionary:
	return {}

func set_world_time(_hour: int, _minute: int) -> void:
	pass

func set_world_time_speed(_minutes_per_real_second: float) -> void:
	pass

func is_daytime() -> bool:
	return true
