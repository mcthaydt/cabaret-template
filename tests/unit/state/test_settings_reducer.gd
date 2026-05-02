extends GutTest

const SETTINGS_REDUCER := preload("res://scripts/core/state/reducers/u_settings_reducer.gd")
const INPUT_REDUCER := preload("res://scripts/core/state/reducers/u_input_reducer.gd")

func test_profile_switch_updates_active_profile_id() -> void:
	var state := _make_state()
	var action := U_InputActions.profile_switched("alt")
	var reduced := SETTINGS_REDUCER.reduce(state, action)

	assert_eq(reduced["input_settings"].get("active_profile_id", ""), "alt")
	assert_eq(state["input_settings"].get("active_profile_id", ""), "default", "Original state should remain unchanged")

func test_rebind_action_updates_custom_bindings_without_mutating_original() -> void:
	var state := _make_state()
	var action := U_InputActions.rebind_action(StringName("jump"), {"type": "key", "keycode": KEY_SPACE})
	var reduced := SETTINGS_REDUCER.reduce(state, action)

	var bindings: Dictionary = reduced["input_settings"].get("custom_bindings", {})
	assert_true(bindings.has(StringName("jump")))
	assert_eq((bindings[StringName("jump")] as Array).size(), 1)
	assert_true(state["input_settings"].get("custom_bindings", {}).is_empty(), "Original custom bindings should remain empty")

func test_unhandled_action_returns_same_structure() -> void:
	var state := _make_state()
	var reduced := SETTINGS_REDUCER.reduce(state, {"type": StringName("noop")})

	assert_eq(reduced, state, "Reducer should return original state for unknown actions")

func test_missing_input_settings_initializes_defaults() -> void:
	var reduced := SETTINGS_REDUCER.reduce({}, U_InputActions.update_mouse_sensitivity(2.0))
	assert_true(reduced.has("input_settings"))
	assert_almost_eq(reduced["input_settings"].get("mouse_settings", {}).get("sensitivity", 0.0), 2.0, 0.0001)

func _make_state() -> Dictionary:
	return {
		"input_settings": INPUT_REDUCER.get_default_input_settings_state()
	}
