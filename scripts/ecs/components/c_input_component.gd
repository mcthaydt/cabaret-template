@icon("res://assets/editor_icons/component.svg")
extends BaseECSComponent
class_name C_InputComponent

const COMPONENT_TYPE := StringName("C_InputComponent")
enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD,
	TOUCHSCREEN,
}

var move_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var sprint_pressed: bool = false
var _jump_requested: bool = false
var _last_jump_press_time: float = -INF
@export var device_type: int = DeviceType.KEYBOARD_MOUSE
var action_strengths: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func set_move_vector(value: Vector2) -> void:
	move_vector = value

func set_jump_pressed(pressed: bool) -> void:
	jump_pressed = pressed
	if pressed:
		_jump_requested = true
		_last_jump_press_time = ECS_UTILS.get_current_time()

func set_sprint_pressed(pressed: bool) -> void:
	sprint_pressed = pressed

func set_device_type(value: int) -> void:
	device_type = clampi(value, DeviceType.KEYBOARD_MOUSE, DeviceType.TOUCHSCREEN)

func set_action_strength(action: StringName, strength: float) -> void:
	if action == StringName():
		return
	action_strengths[action] = clampf(strength, 0.0, 1.0)

func clear_action_strengths() -> void:
	action_strengths.clear()

func get_action_strength(action: StringName) -> float:
	return float(action_strengths.get(action, 0.0))

func is_sprinting() -> bool:
	return sprint_pressed

func has_jump_request(buffer_time: float, current_time: float) -> bool:
	if not _jump_requested:
		return false
	if buffer_time <= 0.0:
		return true
	if current_time - _last_jump_press_time <= buffer_time:
		return true
	_jump_requested = false
	jump_pressed = false
	return false

func consume_jump_request() -> bool:
	var requested := _jump_requested
	_jump_requested = false
	jump_pressed = false
	return requested
