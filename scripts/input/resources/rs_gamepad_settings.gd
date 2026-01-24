@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_GamepadSettings

## Tunables for gamepad input handling.
##
## Stores stick/triggers deadzones, vibration preferences, and look sensitivity.
## Used by both runtime systems (S_InputSystem, S_GamepadVibrationSystem) and
## gameplay UI when applying per-device settings.

enum DeadzoneCurve {
	LINEAR,
	QUADRATIC,
	CUBIC,
}

@export_range(0.0, 1.0, 0.01) var left_stick_deadzone: float = 0.2
@export_range(0.0, 1.0, 0.01) var right_stick_deadzone: float = 0.2
@export_range(0.0, 1.0, 0.01) var trigger_deadzone: float = 0.1
@export var vibration_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var vibration_intensity: float = 1.0
@export var invert_y_axis: bool = false
@export_range(0.1, 5.0, 0.1) var right_stick_sensitivity: float = 1.0
@export_enum("Linear:0", "Quadratic:1", "Cubic:2") var deadzone_curve: int = DeadzoneCurve.LINEAR

## Applies a circular deadzone and optional response curve to a 2D stick vector.
static func apply_deadzone(
	input: Vector2,
	deadzone: float,
	curve_type: int = DeadzoneCurve.LINEAR,
	use_curve: bool = true,
	response_curve: Curve = null
) -> Vector2:
	if input.is_zero_approx():
		return Vector2.ZERO

	var clamped_deadzone := clampf(deadzone, 0.0, 0.95)
	var magnitude := clampf(input.length(), 0.0, 1.0)
	if magnitude <= clamped_deadzone:
		return Vector2.ZERO

	var rescaled := 0.0
	if clamped_deadzone >= 0.95:
		rescaled = 0.0
	else:
		rescaled = (magnitude - clamped_deadzone) / max(1.0 - clamped_deadzone, 0.0001)

	if use_curve:
		rescaled = _apply_curve_value(rescaled, curve_type, response_curve)

	return input.normalized() * clampf(rescaled, 0.0, 1.0)

static func _apply_curve_value(value: float, curve_type: int, response_curve: Curve) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	if response_curve != null:
		return response_curve.sample_baked(clamped_value)
	match curve_type:
		DeadzoneCurve.QUADRATIC:
			return clamped_value * clamped_value
		DeadzoneCurve.CUBIC:
			return clamped_value * clamped_value * clamped_value
		_:
			return clamped_value
