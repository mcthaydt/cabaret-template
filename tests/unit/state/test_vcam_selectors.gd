extends GutTest


func test_get_active_vcam_id_returns_value_from_state() -> void:
	var state := _make_state({"active_vcam_id": StringName("vcam_orbit")})
	assert_eq(U_VCamSelectors.get_active_vcam_id(state), StringName("vcam_orbit"))

func test_get_active_vcam_id_returns_empty_when_slice_missing() -> void:
	assert_eq(U_VCamSelectors.get_active_vcam_id({}), StringName(""))

func test_get_active_mode_returns_value_from_state() -> void:
	var state := _make_state({"active_mode": "orbit"})
	assert_eq(U_VCamSelectors.get_active_mode(state), "orbit")

func test_get_active_mode_returns_empty_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_active_mode(state), "")

func test_get_previous_vcam_id_returns_value_from_state() -> void:
	var state := _make_state({"previous_vcam_id": StringName("vcam_fixed")})
	assert_eq(U_VCamSelectors.get_previous_vcam_id(state), StringName("vcam_fixed"))

func test_get_previous_vcam_id_returns_empty_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_previous_vcam_id(state), StringName(""))

func test_get_blend_progress_returns_value_from_state() -> void:
	var state := _make_state({"blend_progress": 0.25})
	assert_almost_eq(U_VCamSelectors.get_blend_progress(state), 0.25, 0.0001)

func test_get_blend_progress_returns_one_when_field_missing() -> void:
	var state := _make_state({})
	assert_almost_eq(U_VCamSelectors.get_blend_progress(state), 1.0, 0.0001)

func test_is_blending_returns_value_from_state() -> void:
	var state := _make_state({"is_blending": true})
	assert_true(U_VCamSelectors.is_blending(state))

func test_is_blending_returns_false_when_field_missing() -> void:
	var state := _make_state({})
	assert_false(U_VCamSelectors.is_blending(state))

func test_get_silhouette_active_count_returns_value_from_state() -> void:
	var state := _make_state({"silhouette_active_count": 4})
	assert_eq(U_VCamSelectors.get_silhouette_active_count(state), 4)

func test_get_silhouette_active_count_returns_zero_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_silhouette_active_count(state), 0)

func test_get_blend_from_vcam_id_returns_value_from_state() -> void:
	var state := _make_state({"blend_from_vcam_id": StringName("vcam_a")})
	assert_eq(U_VCamSelectors.get_blend_from_vcam_id(state), StringName("vcam_a"))

func test_get_blend_from_vcam_id_returns_empty_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_blend_from_vcam_id(state), StringName(""))

func test_get_blend_to_vcam_id_returns_value_from_state() -> void:
	var state := _make_state({"blend_to_vcam_id": StringName("vcam_b")})
	assert_eq(U_VCamSelectors.get_blend_to_vcam_id(state), StringName("vcam_b"))

func test_get_blend_to_vcam_id_returns_empty_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_blend_to_vcam_id(state), StringName(""))

func test_is_active_target_valid_returns_value_from_state() -> void:
	var state := _make_state({"active_target_valid": false})
	assert_false(U_VCamSelectors.is_active_target_valid(state))

func test_is_active_target_valid_returns_true_when_field_missing() -> void:
	var state := _make_state({})
	assert_true(U_VCamSelectors.is_active_target_valid(state))

func test_get_last_recovery_reason_returns_value_from_state() -> void:
	var state := _make_state({"last_recovery_reason": "target_invalid"})
	assert_eq(U_VCamSelectors.get_last_recovery_reason(state), "target_invalid")

func test_get_last_recovery_reason_returns_empty_when_field_missing() -> void:
	var state := _make_state({})
	assert_eq(U_VCamSelectors.get_last_recovery_reason(state), "")

func test_is_in_fov_zone_returns_value_from_state() -> void:
	var state := _make_state({"in_fov_zone": true})
	assert_true(U_VCamSelectors.is_in_fov_zone(state))

func test_is_in_fov_zone_returns_false_when_field_missing() -> void:
	var state := _make_state({})
	assert_false(U_VCamSelectors.is_in_fov_zone(state))

func test_selectors_do_not_mutate_state() -> void:
	var state := _make_state({
		"active_vcam_id": StringName("vcam_orbit"),
		"active_mode": "orbit",
		"previous_vcam_id": StringName("vcam_fixed"),
		"blend_progress": 0.5,
		"is_blending": true,
		"silhouette_active_count": 2,
		"blend_from_vcam_id": StringName("vcam_fixed"),
		"blend_to_vcam_id": StringName("vcam_orbit"),
		"active_target_valid": false,
		"last_recovery_reason": "target_invalid",
		"in_fov_zone": true,
	})
	var copy := state.duplicate(true)

	var _active_id := U_VCamSelectors.get_active_vcam_id(state)
	var _active_mode := U_VCamSelectors.get_active_mode(state)
	var _previous_id := U_VCamSelectors.get_previous_vcam_id(state)
	var _blend_progress := U_VCamSelectors.get_blend_progress(state)
	var _is_blending := U_VCamSelectors.is_blending(state)
	var _silhouette_count := U_VCamSelectors.get_silhouette_active_count(state)
	var _blend_from := U_VCamSelectors.get_blend_from_vcam_id(state)
	var _blend_to := U_VCamSelectors.get_blend_to_vcam_id(state)
	var _target_valid := U_VCamSelectors.is_active_target_valid(state)
	var _last_recovery := U_VCamSelectors.get_last_recovery_reason(state)
	var _in_fov_zone := U_VCamSelectors.is_in_fov_zone(state)

	assert_eq(state, copy)

func _make_state(vcam_updates: Dictionary) -> Dictionary:
	var vcam_state := {
		"active_vcam_id": StringName(""),
		"active_mode": "",
		"previous_vcam_id": StringName(""),
		"blend_progress": 1.0,
		"is_blending": false,
		"silhouette_active_count": 0,
		"blend_from_vcam_id": StringName(""),
		"blend_to_vcam_id": StringName(""),
		"active_target_valid": true,
		"last_recovery_reason": "",
		"in_fov_zone": false,
	}
	for key in vcam_updates.keys():
		vcam_state[key] = vcam_updates[key]
	return {"vcam": vcam_state}
