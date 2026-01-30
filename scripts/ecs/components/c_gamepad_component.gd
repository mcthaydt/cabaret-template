@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_GamepadComponent

const COMPONENT_TYPE := StringName("C_GamepadComponent")
const RS_GamepadSettings := preload("res://scripts/resources/input/rs_gamepad_settings.gd")

@export var settings: RS_GamepadSettings
@export var device_id: int = -1
@export var is_connected: bool = false
@export var vibration_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var vibration_intensity: float = 1.0
@export_range(0.0, 1.0, 0.01) var left_stick_deadzone: float = 0.2
@export_range(0.0, 1.0, 0.01) var right_stick_deadzone: float = 0.2

var left_stick: Vector2 = Vector2.ZERO
var right_stick: Vector2 = Vector2.ZERO
var button_states: Dictionary = {}  # Joypad button -> bool

var _deadzone_curve: int = RS_GamepadSettings.DeadzoneCurve.LINEAR
var _invert_y_axis: bool = false
var _trigger_deadzone: float = 0.1
var _right_stick_sensitivity: float = 1.0

var _start_vibration_callable: Callable = Callable()
var _stop_vibration_callable: Callable = Callable()

func _init() -> void:
	component_type = COMPONENT_TYPE

func _on_required_settings_ready() -> void:
	if settings != null:
		_apply_settings_resource(settings)

func apply_settings_from_dictionary(gamepad_settings: Dictionary) -> void:
	if gamepad_settings == null:
		return
	left_stick_deadzone = clampf(float(gamepad_settings.get("left_stick_deadzone", left_stick_deadzone)), 0.0, 1.0)
	right_stick_deadzone = clampf(float(gamepad_settings.get("right_stick_deadzone", right_stick_deadzone)), 0.0, 1.0)
	_trigger_deadzone = clampf(float(gamepad_settings.get("trigger_deadzone", _trigger_deadzone)), 0.0, 1.0)
	vibration_enabled = bool(gamepad_settings.get("vibration_enabled", vibration_enabled))
	vibration_intensity = clampf(float(gamepad_settings.get("vibration_intensity", vibration_intensity)), 0.0, 1.0)
	_invert_y_axis = bool(gamepad_settings.get("invert_y_axis", _invert_y_axis))
	_right_stick_sensitivity = clampf(float(gamepad_settings.get("right_stick_sensitivity", _right_stick_sensitivity)), 0.0, 5.0)
	_deadzone_curve = int(gamepad_settings.get("deadzone_curve", _deadzone_curve))

func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
	var curve_type := _deadzone_curve
	if settings != null:
		curve_type = settings.deadzone_curve
	return RS_GamepadSettings.apply_deadzone(input, deadzone, curve_type)

func apply_rumble(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if not vibration_enabled or device_id < 0:
		return
	var weak := clampf(abs(weak_magnitude) * vibration_intensity, 0.0, 1.0)
	var strong := clampf(abs(strong_magnitude) * vibration_intensity, 0.0, 1.0)
	var clamped_duration: float = max(duration, 0.0)
	if weak <= 0.0 and strong <= 0.0:
		return
	var callable := _get_start_vibration_callable()
	if callable == Callable():
		return
	callable.call(device_id, weak, strong, clamped_duration)

func stop_rumble() -> void:
	if device_id < 0:
		return
	var callable := _get_stop_vibration_callable()
	if callable == Callable():
		return
	callable.call(device_id)

func update_button_state(button_index: int, pressed: bool) -> void:
	button_states[button_index] = pressed

func get_snapshot() -> Dictionary:
	return {
		"device_id": device_id,
		"is_connected": is_connected,
		"left_stick": left_stick,
		"right_stick": right_stick,
		"vibration_enabled": vibration_enabled,
		"vibration_intensity": vibration_intensity,
		"left_deadzone": left_stick_deadzone,
		"right_deadzone": right_stick_deadzone,
	}

func set_vibration_callables(start_callable: Callable, stop_callable: Callable) -> void:
	_start_vibration_callable = start_callable
	_stop_vibration_callable = stop_callable

func _apply_settings_resource(resource: RS_GamepadSettings) -> void:
	left_stick_deadzone = resource.left_stick_deadzone
	right_stick_deadzone = resource.right_stick_deadzone
	_trigger_deadzone = resource.trigger_deadzone
	vibration_enabled = resource.vibration_enabled
	vibration_intensity = resource.vibration_intensity
	_invert_y_axis = resource.invert_y_axis
	_right_stick_sensitivity = resource.right_stick_sensitivity
	_deadzone_curve = resource.deadzone_curve

func _get_start_vibration_callable() -> Callable:
	if _start_vibration_callable != Callable():
		return _start_vibration_callable
	_start_vibration_callable = Callable(Input, "start_joy_vibration")
	return _start_vibration_callable

func _get_stop_vibration_callable() -> Callable:
	if _stop_vibration_callable != Callable():
		return _stop_vibration_callable
	_stop_vibration_callable = Callable(Input, "stop_joy_vibration")
	return _stop_vibration_callable
