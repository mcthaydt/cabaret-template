extends ECSComponent

class_name InputComponent

const COMPONENT_TYPE := StringName("InputComponent")

var move_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false

func _init() -> void:
    component_type = COMPONENT_TYPE

func set_move_vector(value: Vector2) -> void:
    move_vector = value

func set_jump_pressed(pressed: bool) -> void:
    jump_pressed = pressed

func consume_jump() -> bool:
    var was_pressed := jump_pressed
    jump_pressed = false
    return was_pressed
