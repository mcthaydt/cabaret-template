@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_GamepadComponent

const COMPONENT_TYPE := StringName("C_GamepadComponent")
const RS_GamepadSettings := preload("res://scripts/ecs/resources/rs_gamepad_settings.gd")

@export var settings: RS_GamepadSettings
@export var device_id: int = -1
@export var is_connected: bool = false

var left_stick: Vector2 = Vector2.ZERO
var right_stick: Vector2 = Vector2.ZERO
var button_states: Dictionary = {}  # Joypad button -> bool

var _start_vibration_callable: Callable = Callable()
var _stop_vibration_callable: Callable = Callable()

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_GamepadComponent missing settings; assign an RS_GamepadSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	# Settings Resource is now the single source of truth - no copying needed
	pass

func update_settings_from_state(gamepad_settings: Dictionary) -> void:
	if settings == null or gamepad_settings == null:
		return
	settings.left_stick_deadzone = clampf(float(gamepad_settings.get("left_stick_deadzone", settings.left_stick_deadzone)), 0.0, 1.0)
	settings.right_stick_deadzone = clampf(float(gamepad_settings.get("right_stick_deadzone", settings.right_stick_deadzone)), 0.0, 1.0)
	settings.trigger_deadzone = clampf(float(gamepad_settings.get("trigger_deadzone", settings.trigger_deadzone)), 0.0, 1.0)
	settings.vibration_enabled = bool(gamepad_settings.get("vibration_enabled", settings.vibration_enabled))
	settings.vibration_intensity = clampf(float(gamepad_settings.get("vibration_intensity", settings.vibration_intensity)), 0.0, 1.0)
	settings.invert_y_axis = bool(gamepad_settings.get("invert_y_axis", settings.invert_y_axis))
	settings.right_stick_sensitivity = clampf(float(gamepad_settings.get("right_stick_sensitivity", settings.right_stick_sensitivity)), 0.0, 5.0)
	settings.deadzone_curve = int(gamepad_settings.get("deadzone_curve", settings.deadzone_curve))

func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
	if settings == null:
		return RS_GamepadSettings.apply_deadzone(input, deadzone, RS_GamepadSettings.DeadzoneCurve.LINEAR)
	return RS_GamepadSettings.apply_deadzone(input, deadzone, settings.deadzone_curve)

func apply_rumble(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if settings == null or not settings.vibration_enabled or device_id < 0:
		return
	var weak := clampf(abs(weak_magnitude) * settings.vibration_intensity, 0.0, 1.0)
	var strong := clampf(abs(strong_magnitude) * settings.vibration_intensity, 0.0, 1.0)
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
	var snapshot := {
		"device_id": device_id,
		"is_connected": is_connected,
		"left_stick": left_stick,
		"right_stick": right_stick,
	}
	if settings != null:
		snapshot["vibration_enabled"] = settings.vibration_enabled
		snapshot["vibration_intensity"] = settings.vibration_intensity
		snapshot["left_deadzone"] = settings.left_stick_deadzone
		snapshot["right_deadzone"] = settings.right_stick_deadzone
	return snapshot

func set_vibration_callables(start_callable: Callable, stop_callable: Callable) -> void:
	_start_vibration_callable = start_callable
	_stop_vibration_callable = stop_callable

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
