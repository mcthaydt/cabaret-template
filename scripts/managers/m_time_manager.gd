@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_time_manager.gd"
class_name M_TimeManager

signal pause_state_changed(is_paused: bool)
signal timescale_changed(new_scale: float)
signal world_hour_changed(hour: int)

const U_PAUSE_SYSTEM := preload("res://scripts/managers/helpers/time/u_pause_system.gd")
const U_TIMESCALE_CONTROLLER := preload("res://scripts/managers/helpers/time/u_timescale_controller.gd")
const U_WORLD_CLOCK := preload("res://scripts/managers/helpers/time/u_world_clock.gd")
const U_TIME_ACTIONS := preload("res://scripts/state/actions/u_time_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const TIME_SLICE_NAME := StringName("time")

var _store: I_StateStore = null
var _cursor_manager: M_CursorManager = null
var _ui_overlay_stack: CanvasLayer = null
var _pause_system = U_PAUSE_SYSTEM.new()
var _timescale_controller = U_TIMESCALE_CONTROLLER.new()
var _world_clock = U_WORLD_CLOCK.new()
var _is_paused: bool = false
var _current_scene_id: StringName = StringName("")
var _current_scene_type: int = -1
var _is_hydrating_time_slice: bool = false

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
	_world_clock.on_minute_changed = Callable(self, "_on_world_minute_changed")
	_world_clock.on_hour_changed = Callable(self, "_on_world_hour_changed")

	_store.slice_updated.connect(_on_slice_updated)
	_hydrate_from_time_slice(_store.get_slice(TIME_SLICE_NAME))

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

func _physics_process(delta: float) -> void:
	if _is_paused:
		return
	if _current_scene_type != U_SceneRegistry.SceneType.GAMEPLAY:
		return
	_world_clock.advance(get_scaled_delta(delta))

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
			if _store != null:
				_store.dispatch(U_TIME_ACTIONS.update_pause_state(_is_paused, _pause_system.get_active_channels()))
				if _is_paused:
					_store.dispatch(U_GAMEPLAY_ACTIONS.pause_game())
				else:
					_store.dispatch(U_GAMEPLAY_ACTIONS.unpause_game())

func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == TIME_SLICE_NAME:
		_hydrate_from_time_slice(slice_state)
		return

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
			if _store != null:
				_store.dispatch(U_TIME_ACTIONS.update_pause_state(_is_paused, _pause_system.get_active_channels()))
				if _is_paused:
					_store.dispatch(U_GAMEPLAY_ACTIONS.pause_game())
				else:
					_store.dispatch(U_GAMEPLAY_ACTIONS.unpause_game())

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
	var clamped_scale: float = _timescale_controller.get_timescale()
	timescale_changed.emit(clamped_scale)
	if _store != null and not _is_hydrating_time_slice:
		_store.dispatch(U_TIME_ACTIONS.update_timescale(clamped_scale))

func get_timescale() -> float:
	return _timescale_controller.get_timescale()

func get_scaled_delta(raw_delta: float) -> float:
	return _timescale_controller.get_scaled_delta(raw_delta)

func get_world_time() -> Dictionary:
	return _world_clock.get_time()

func set_world_time(hour: int, minute: int) -> void:
	_world_clock.set_time(hour, minute)
	_dispatch_world_time_snapshot()

func set_world_time_speed(minutes_per_real_second: float) -> void:
	_world_clock.set_speed(minutes_per_real_second)
	_dispatch_world_time_snapshot()

func is_daytime() -> bool:
	return _world_clock.is_daytime()

func _on_world_minute_changed(_minute: int) -> void:
	_dispatch_world_time_snapshot()

func _on_world_hour_changed(hour: int) -> void:
	world_hour_changed.emit(hour)

func _dispatch_world_time_snapshot() -> void:
	if _store == null or _is_hydrating_time_slice:
		return
	var time_data: Dictionary = _world_clock.get_time()
	_store.dispatch(U_TIME_ACTIONS.update_world_time(
		int(time_data.get("hour", 8)),
		int(time_data.get("minute", 0)),
		float(time_data.get("total_minutes", 480.0)),
		int(time_data.get("day_count", 1)),
	))

func _hydrate_from_time_slice(slice_state: Dictionary) -> void:
	if slice_state.is_empty():
		return
	if _is_hydrating_time_slice:
		return

	_is_hydrating_time_slice = true
	_timescale_controller.set_timescale(float(slice_state.get("timescale", 1.0)))
	_world_clock.set_state(
		float(slice_state.get("world_total_minutes", 480.0)),
		int(slice_state.get("world_day_count", 1)),
		float(slice_state.get("world_time_speed", 1.0))
	)
	_is_hydrating_time_slice = false
