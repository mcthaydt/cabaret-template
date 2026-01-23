extends RefCounted

## Research prototype for validating multi-device input behavior.
##
## Provides helpers for discovering connected gamepads, sampling analog sticks,
## reading button states, and benchmarking input latency relative to the
## 16 ms/frame target documented in the Input Manager plan.

const TARGET_LATENCY_MS := 16.0
const DEFAULT_DEADZONE := 0.2

var _adapter: RefCounted
var _time_provider: Callable
var _pending_latency_event_us: int = -1

func _init(adapter: RefCounted = null, time_provider: Callable = Callable()) -> void:
	_adapter = adapter if adapter != null else InputAdapter.new()
	if time_provider.is_valid():
		_time_provider = time_provider
	else:
		_time_provider = Callable(self, "_default_time_provider")

func list_connected_devices() -> Array[Dictionary]:
	var devices: Array[Dictionary] = []
	for device_id in _adapter.get_connected_joypads():
		devices.append({
			"device_id": device_id,
			"name": _adapter.get_joy_name(device_id),
			"guid": _adapter.get_joy_guid(device_id),
		})
	return devices

func sample_left_stick(device_id: int, deadzone: float = DEFAULT_DEADZONE) -> Dictionary:
	return _sample_axes(device_id, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, deadzone)

func sample_right_stick(device_id: int, deadzone: float = DEFAULT_DEADZONE) -> Dictionary:
	return _sample_axes(device_id, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, deadzone)

func sample_buttons(device_id: int, buttons: Array[int]) -> Dictionary:
	var states: Dictionary = {}
	for button in buttons:
		states[button] = _adapter.is_joy_button_pressed(device_id, button)
	return states

func mark_input_event() -> void:
	_pending_latency_event_us = int(_time_provider.call())

func conclude_latency_measure(processed_time_us: int = -1) -> Dictionary:
	if _pending_latency_event_us < 0:
		return {
			"latency_ms": 0.0,
			"within_target": true,
		}

	var end_us := processed_time_us
	if end_us < 0:
		end_us = int(_time_provider.call())

	var latency_ms: float = maxf(float(end_us - _pending_latency_event_us) / 1000.0, 0.0)
	_pending_latency_event_us = -1
	return {
		"latency_ms": latency_ms,
		"within_target": latency_ms <= TARGET_LATENCY_MS,
	}

func summarize_latency(samples_ms: Array[float]) -> Dictionary:
	if samples_ms.is_empty():
		return {
			"average_ms": 0.0,
			"max_ms": 0.0,
			"min_ms": 0.0,
			"within_target": true,
		}

	var total := 0.0
	var highest := -INF
	var lowest := INF
	for sample in samples_ms:
		var value: float = maxf(sample, 0.0)
		total += value
		highest = maxf(highest, value)
		lowest = minf(lowest, value)

	var average: float = total / samples_ms.size()
	return {
		"average_ms": average,
		"max_ms": highest,
		"min_ms": lowest,
		"within_target": highest <= TARGET_LATENCY_MS,
	}

func compare_device_latency(gamepad_samples_ms: Array[float], keyboard_samples_ms: Array[float]) -> Dictionary:
	var gamepad_summary := summarize_latency(gamepad_samples_ms)
	var keyboard_summary := summarize_latency(keyboard_samples_ms)
	return {
		"gamepad": gamepad_summary,
		"keyboard": keyboard_summary,
		"all_within_target": gamepad_summary.within_target and keyboard_summary.within_target,
	}

func _sample_axes(device_id: int, axis_x: int, axis_y: int, deadzone: float) -> Dictionary:
	var raw_vector := Vector2(
		_adapter.get_joy_axis(device_id, axis_x),
		_adapter.get_joy_axis(device_id, axis_y)
	)
	var magnitude := raw_vector.length()
	var filtered_vector := raw_vector
	if magnitude < maxf(deadzone, 0.0):
		filtered_vector = Vector2.ZERO
	return {
		"raw": raw_vector,
		"filtered": filtered_vector,
		"magnitude": magnitude,
		"deadzone": deadzone,
	}

func _default_time_provider() -> int:
	return Time.get_ticks_usec()

class InputAdapter extends RefCounted:
	var _input_singleton: Variant

	func _init(input_singleton: Variant = null) -> void:
		_input_singleton = input_singleton if input_singleton != null else Input

	func get_connected_joypads() -> Array:
		return _input_singleton.get_connected_joypads()

	func get_joy_name(device_id: int) -> String:
		return _input_singleton.get_joy_name(device_id)

	func get_joy_guid(device_id: int) -> String:
		return _input_singleton.get_joy_guid(device_id)

	func get_joy_axis(device_id: int, axis: int) -> float:
		return _input_singleton.get_joy_axis(device_id, axis)

	func is_joy_button_pressed(device_id: int, button: int) -> bool:
		return _input_singleton.is_joy_button_pressed(device_id, button)
