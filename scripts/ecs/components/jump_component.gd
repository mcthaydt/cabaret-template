extends ECSComponent

class_name JumpComponent

const COMPONENT_TYPE := StringName("JumpComponent")

@export var jump_force: float = 12.0
@export var coyote_time: float = 0.15
@export var max_air_jumps: int = 0
@export var jump_buffer_time: float = 0.15
@export var apex_coyote_time: float = 0.1
@export var apex_velocity_threshold: float = 0.1
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

var _last_on_floor_time: float = -INF
var _air_jumps_remaining: int = 0
var _last_jump_time: float = -INF
var _last_apex_time: float = -INF
var _last_vertical_velocity: float = 0.0
var _debug_snapshot: Dictionary = {}

func _init() -> void:
    component_type = COMPONENT_TYPE
    _air_jumps_remaining = max_air_jumps

func mark_on_floor(current_time: float) -> void:
    _last_on_floor_time = current_time
    _air_jumps_remaining = max_air_jumps

func can_jump(current_time: float) -> bool:
    var body := get_character_body()
    if body and body.is_on_floor():
        mark_on_floor(current_time)
        return true
    if current_time - _last_on_floor_time <= coyote_time:
        return true
    return _air_jumps_remaining > 0

func on_jump_performed(current_time: float, grounded: bool) -> void:
    _last_jump_time = current_time
    _last_on_floor_time = -INF
    if grounded:
        _air_jumps_remaining = max_air_jumps
    elif _air_jumps_remaining > 0:
        _air_jumps_remaining -= 1

func has_air_jumps_remaining() -> bool:
    return _air_jumps_remaining > 0

func update_vertical_state(velocity_y: float, current_time: float) -> void:
    var previous_velocity := _last_vertical_velocity
    _last_vertical_velocity = velocity_y
    if previous_velocity > apex_velocity_threshold and velocity_y <= apex_velocity_threshold:
        _last_apex_time = current_time

func has_recent_apex(current_time: float) -> bool:
    if _last_apex_time == -INF:
        return false
    return current_time - _last_apex_time <= apex_coyote_time

func get_character_body() -> CharacterBody3D:
    if character_body_path.is_empty():
        return null
    return get_node_or_null(character_body_path)

func get_input_component():
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path)

func update_debug_snapshot(snapshot: Dictionary) -> void:
    _debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
    return _debug_snapshot.duplicate(true)
