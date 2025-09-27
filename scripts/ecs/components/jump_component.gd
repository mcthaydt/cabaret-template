extends ECSComponent

class_name JumpComponent

const COMPONENT_TYPE := StringName("JumpComponent")

@export var jump_force: float = 12.0
@export var coyote_time: float = 0.15
@export var max_air_jumps: int = 0
@export_node_path("CharacterBody3D") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath

var _last_on_floor_time: float = 0.0

func _init() -> void:
    component_type = COMPONENT_TYPE

func mark_on_floor() -> void:
    _last_on_floor_time = Time.get_ticks_msec() / 1000.0

func can_jump(current_time: float) -> bool:
    var body := get_character_body()
    if body and body.is_on_floor():
        mark_on_floor()
        return true
    return current_time - _last_on_floor_time <= coyote_time

func get_character_body() -> CharacterBody3D:
    if character_body_path.is_empty():
        return null
    return get_node_or_null(character_body_path)

func get_input_component():
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path)
