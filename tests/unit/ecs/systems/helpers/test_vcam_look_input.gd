extends GutTest

const U_VCAM_LOOK_INPUT := preload("res://scripts/ecs/systems/helpers/u_vcam_look_input.gd")

func _new_response_values(
	deadzone: float = 0.02,
	hold_sec: float = 0.06,
	release_decay: float = 25.0
) -> Dictionary:
	return {
		"look_input_deadzone": deadzone,
		"look_input_hold_sec": hold_sec,
		"look_input_release_decay": release_decay,
	}

func test_filter_look_input_without_response_returns_raw_input() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var vcam_id := StringName("cam_raw")
	var raw_input := Vector2(1.5, -2.0)

	var filtered: Vector2 = helper.filter_look_input(vcam_id, raw_input, {}, 0.016)

	assert_eq(filtered, raw_input)
	var state: Dictionary = helper.get_state_snapshot().get(vcam_id, {}) as Dictionary
	assert_true(bool(state.get("input_active", false)))

func test_filter_look_input_applies_deadzone_to_activity() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var vcam_id := StringName("cam_deadzone")
	var response_values := _new_response_values(0.1, 0.0, 25.0)

	var filtered: Vector2 = helper.filter_look_input(vcam_id, Vector2(0.05, 0.0), response_values, 0.016)

	assert_true(filtered.is_zero_approx())
	assert_false(helper.is_active(filtered, response_values))

func test_filter_look_input_sets_hold_timer_on_active_input() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var vcam_id := StringName("cam_hold_timer")
	var response_values := _new_response_values(0.01, 0.2, 25.0)

	helper.filter_look_input(vcam_id, Vector2(4.0, 0.0), response_values, 0.016)

	var state: Dictionary = helper.get_state_snapshot().get(vcam_id, {}) as Dictionary
	assert_almost_eq(float(state.get("hold_timer_sec", 0.0)), 0.2, 0.0001)
	assert_true(bool(state.get("input_active", false)))
	assert_true(bool(state.get("raw_input_active", false)))

func test_filter_look_input_keeps_filtered_value_during_hold_window() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var vcam_id := StringName("cam_hold")
	var response_values := _new_response_values(0.01, 0.1, 25.0)

	helper.filter_look_input(vcam_id, Vector2(5.0, 0.0), response_values, 0.016)
	var held_filtered: Vector2 = helper.filter_look_input(vcam_id, Vector2.ZERO, response_values, 0.03)

	assert_almost_eq(held_filtered.x, 5.0, 0.0001)
	assert_true(helper.is_active(held_filtered, response_values))

func test_filter_look_input_release_decay_reduces_filtered_input() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var vcam_id := StringName("cam_decay")
	var response_values := _new_response_values(0.01, 0.0, 2.0)

	helper.filter_look_input(vcam_id, Vector2(10.0, 0.0), response_values, 0.016)
	var decayed: Vector2 = helper.filter_look_input(vcam_id, Vector2.ZERO, response_values, 0.25)

	assert_almost_eq(decayed.length(), 5.0, 0.0001)
	assert_true(helper.is_active(decayed, response_values))

func test_is_active_respects_deadzone_and_no_response_passthrough() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var response_values := _new_response_values(0.2, 0.06, 25.0)

	assert_false(helper.is_active(Vector2(0.1, 0.0), response_values))
	assert_true(helper.is_active(Vector2(0.3, 0.0), response_values))
	assert_true(helper.is_active(Vector2(0.001, 0.0), {}))

func test_prune_removes_non_active_vcam_state() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var response_values := _new_response_values()
	helper.filter_look_input(StringName("cam_a"), Vector2(1.0, 0.0), response_values, 0.016)
	helper.filter_look_input(StringName("cam_b"), Vector2(1.0, 0.0), response_values, 0.016)

	helper.prune([StringName("cam_a")])

	var snapshot: Dictionary = helper.get_state_snapshot()
	assert_true(snapshot.has(StringName("cam_a")))
	assert_false(snapshot.has(StringName("cam_b")))

func test_clear_for_vcam_and_clear_all_reset_state() -> void:
	var helper := U_VCAM_LOOK_INPUT.new()
	var response_values := _new_response_values()
	helper.filter_look_input(StringName("cam_a"), Vector2(1.0, 0.0), response_values, 0.016)
	helper.filter_look_input(StringName("cam_b"), Vector2(1.0, 0.0), response_values, 0.016)

	helper.clear_for_vcam(StringName("cam_a"))
	var after_single_clear: Dictionary = helper.get_state_snapshot()
	assert_false(after_single_clear.has(StringName("cam_a")))
	assert_true(after_single_clear.has(StringName("cam_b")))

	helper.clear_all()
	assert_true(helper.get_state_snapshot().is_empty())
