@icon("res://resources/editor_icons/component.svg")
extends ECSComponent
class_name C_JumpComponent

const COMPONENT_TYPE := StringName("C_JumpComponent")

@export var settings: RS_JumpSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath

var _last_on_floor_time: float = -INF
var _air_jumps_remaining: int = 0
var _last_jump_time: float = -INF
var _last_apex_time: float = -INF
var _last_vertical_velocity: float = 0.0
var _debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_JumpComponent missing settings; assign an RS_JumpSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	_air_jumps_remaining = settings.max_air_jumps

func mark_on_floor(current_time: float) -> void:
	_last_on_floor_time = current_time
	if settings != null:
		_air_jumps_remaining = settings.max_air_jumps

func can_jump(current_time: float) -> bool:
	var body := get_character_body()
	if body and body.is_on_floor():
		mark_on_floor(current_time)
		return true
	if settings != null and current_time - _last_on_floor_time <= settings.coyote_time:
		return true
	return _air_jumps_remaining > 0

func on_jump_performed(current_time: float, grounded: bool) -> void:
	_last_jump_time = current_time
	_last_on_floor_time = -INF
	if grounded:
		_air_jumps_remaining = settings.max_air_jumps if settings != null else 0
	elif _air_jumps_remaining > 0:
		_air_jumps_remaining -= 1

func has_air_jumps_remaining() -> bool:
	return _air_jumps_remaining > 0

func update_vertical_state(velocity_y: float, current_time: float) -> void:
	var previous_velocity := _last_vertical_velocity
	_last_vertical_velocity = velocity_y
	var threshold: float = settings.apex_velocity_threshold if settings != null else 0.1
	if previous_velocity > threshold and velocity_y <= threshold:
		_last_apex_time = current_time

func has_recent_apex(current_time: float) -> bool:
	if _last_apex_time == -INF:
		return false
	var window: float = settings.apex_coyote_time if settings != null else 0.1
	return current_time - _last_apex_time <= window

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path)

func update_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
	return _debug_snapshot.duplicate(true)
