extends GutTest

const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")
const RS_GamepadSettings := preload("res://scripts/ecs/resources/rs_gamepad_settings.gd")

func test_component_initializes_component_type() -> void:
	var component := C_GamepadComponent.new()
	component.settings = RS_GamepadSettings.new()
	add_child_autofree(component)
	assert_eq(component.get_component_type(), C_GamepadComponent.COMPONENT_TYPE)

func test_apply_deadzone_respects_settings_curve() -> void:
	var component := C_GamepadComponent.new()
	var settings := RS_GamepadSettings.new()
	settings.deadzone_curve = RS_GamepadSettings.DeadzoneCurve.CUBIC
	component.settings = settings
	add_child_autofree(component)

	var filtered := component.apply_deadzone(Vector2(0.8, 0.0), 0.2)
	assert_true(filtered.length() > 0.0, "Values above deadzone should pass through")
	assert_true(filtered.length() < 1.0, "Cubic curve should reduce magnitude below 1.0")

func test_apply_rumble_honors_vibration_intensity_and_flags() -> void:
	var component := C_GamepadComponent.new()
	var settings := RS_GamepadSettings.new()
	settings.vibration_enabled = true
	settings.vibration_intensity = 0.5
	component.settings = settings
	component.device_id = 1
	add_child_autofree(component)
	var mock := MockVibration.new()
	component.set_vibration_callables(Callable(mock, "record_start"), Callable(mock, "record_stop"))
	component.apply_rumble(0.6, 0.8, 0.25)
	assert_eq(mock.start_calls.size(), 1, "Should invoke vibration when enabled")
	var call: Dictionary = mock.start_calls[0] as Dictionary
	assert_eq(call.device_id, 1)
	assert_almost_eq(call.weak, 0.3, 0.0001)
	assert_almost_eq(call.strong, 0.4, 0.0001)
	assert_almost_eq(call.duration, 0.25, 0.0001)
	settings.vibration_enabled = false
	component.apply_rumble(1.0, 1.0, 1.0)
	assert_eq(mock.start_calls.size(), 1, "Disabled vibration should skip Input call")

func test_update_settings_from_state_clamps_values() -> void:
	var component := C_GamepadComponent.new()
	var settings := RS_GamepadSettings.new()
	component.settings = settings
	add_child_autofree(component)

	component.update_settings_from_state({
		"left_stick_deadzone": 1.5,
		"right_stick_deadzone": -0.5,
		"vibration_intensity": 2.0,
		"vibration_enabled": false,
		"invert_y_axis": true,
		"deadzone_curve": RS_GamepadSettings.DeadzoneCurve.QUADRATIC,
	})

	# Verify Resource was updated
	assert_almost_eq(settings.left_stick_deadzone, 1.0, 0.0001)
	assert_almost_eq(settings.right_stick_deadzone, 0.0, 0.0001)
	assert_almost_eq(settings.vibration_intensity, 1.0, 0.0001)
	assert_false(settings.vibration_enabled)
	assert_true(settings.invert_y_axis)
	assert_eq(settings.deadzone_curve, RS_GamepadSettings.DeadzoneCurve.QUADRATIC)

func test_update_settings_from_state_handles_null_settings() -> void:
	var component := C_GamepadComponent.new()
	component.settings = RS_GamepadSettings.new()
	add_child_autofree(component)
	# Set to null AFTER adding to tree (validation already passed)
	component.settings = null

	# Should not crash
	component.update_settings_from_state({
		"left_stick_deadzone": 0.5,
		"vibration_enabled": false,
	})

	# Should still be null
	assert_null(component.settings)

func test_apply_rumble_handles_null_settings() -> void:
	var component := C_GamepadComponent.new()
	component.settings = RS_GamepadSettings.new()
	component.device_id = 1
	add_child_autofree(component)
	# Set to null AFTER adding to tree (validation already passed)
	component.settings = null
	var mock := MockVibration.new()
	component.set_vibration_callables(Callable(mock, "record_start"), Callable(mock, "record_stop"))

	# Should not crash, just return early
	component.apply_rumble(0.5, 0.5, 0.1)
	assert_eq(mock.start_calls.size(), 0, "Should not vibrate when settings is null")

class MockVibration:
	var start_calls: Array = []
	var stop_calls: Array = []

	func record_start(device_id: int, weak: float, strong: float, duration: float) -> void:
		start_calls.append({
			"device_id": device_id,
			"weak": weak,
			"strong": strong,
			"duration": duration,
		})

	func record_stop(device_id: int) -> void:
		stop_calls.append(device_id)
