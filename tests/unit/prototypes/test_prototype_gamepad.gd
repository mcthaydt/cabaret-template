extends GutTest

const PrototypeGamepad := preload("res://tests/prototypes/prototype_gamepad.gd")

func test_list_connected_devices_reports_metadata() -> void:
	var adapter := MockAdapter.new()
	adapter.connected_ids = [3, 7]
	adapter.names = {
		3: "Pad A",
		7: "Pad B",
	}
	adapter.guids = {
		3: "GUID_A",
		7: "GUID_B",
	}

	var prototype := PrototypeGamepad.new(adapter)
	var devices := prototype.list_connected_devices()

	assert_eq(devices.size(), 2, "Should report each connected device")
	assert_eq(devices[0].name, "Pad A")
	assert_eq(devices[1].guid, "GUID_B")

func test_sample_left_stick_applies_deadzone() -> void:
	var adapter := MockAdapter.new()
	adapter.axis_values = {
		Vector2i(1, JOY_AXIS_LEFT_X): 0.05,
		Vector2i(1, JOY_AXIS_LEFT_Y): 0.04,
		Vector2i(1, JOY_AXIS_RIGHT_X): 0.25,
		Vector2i(1, JOY_AXIS_RIGHT_Y): 0.5,
	}

	var prototype := PrototypeGamepad.new(adapter)
	var left_result := prototype.sample_left_stick(1, 0.1)
	assert_true(left_result.filtered.is_zero_approx(), "Values under deadzone should zero out")

	var right_result := prototype.sample_right_stick(1, 0.1)
	assert_almost_eq(right_result.filtered.x, 0.25, 0.001)
	assert_almost_eq(right_result.filtered.y, 0.5, 0.001)

func test_sample_buttons_reports_requested_indices() -> void:
	var adapter := MockAdapter.new()
	adapter.button_states = {
		Vector2i(5, JOY_BUTTON_A): true,
		Vector2i(5, JOY_BUTTON_B): false,
	}

	var prototype := PrototypeGamepad.new(adapter)
	var states := prototype.sample_buttons(5, [JOY_BUTTON_A, JOY_BUTTON_B])

	assert_true(states[JOY_BUTTON_A])
	assert_false(states[JOY_BUTTON_B])

func test_latency_measurement_uses_time_provider() -> void:
	var adapter := MockAdapter.new()
	var time_source := MockTimeSource.new([0, 8000])
	var prototype := PrototypeGamepad.new(adapter, Callable(time_source, "next"))

	prototype.mark_input_event()
	var result := prototype.conclude_latency_measure()

	assert_almost_eq(result.latency_ms, 8.0, 0.001)
	assert_true(result.within_target, "8 ms latency meets 16 ms target")

func test_compare_latency_reports_per_device_results() -> void:
	var adapter := MockAdapter.new()
	var prototype := PrototypeGamepad.new(adapter)

	var summary := prototype.compare_device_latency(
		[10.0, 12.0, 9.5],
		[6.0, 7.2, 8.1]
	)

	assert_true(summary.gamepad.within_target)
	assert_true(summary.keyboard.within_target)
	assert_true(summary.all_within_target)
	assert_almost_eq(summary.gamepad.average_ms, 10.5, 0.001)

class MockAdapter extends RefCounted:
	var connected_ids: Array = []
	var names: Dictionary = {}
	var guids: Dictionary = {}
	var axis_values: Dictionary = {}
	var button_states: Dictionary = {}

	func get_connected_joypads() -> Array:
		return connected_ids.duplicate()

	func get_joy_name(device_id: int) -> String:
		return names.get(device_id, "Unknown")

	func get_joy_guid(device_id: int) -> String:
		return guids.get(device_id, "")

	func get_joy_axis(device_id: int, axis: int) -> float:
		return float(axis_values.get(Vector2i(device_id, axis), 0.0))

	func is_joy_button_pressed(device_id: int, button: int) -> bool:
		return bool(button_states.get(Vector2i(device_id, button), false))

class MockTimeSource:
	var _values: Array[int]
	var _index: int = 0

	func _init(values: Array[int]) -> void:
		_values = values.duplicate()

	func next() -> int:
		if _index >= _values.size():
			return _values.back()
		var value := _values[_index]
		_index += 1
		return value
