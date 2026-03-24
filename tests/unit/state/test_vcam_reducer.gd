extends GutTest


func test_set_active_runtime_updates_active_fields() -> void:
	var state := _make_state()
	var action := U_VCamActions.set_active_runtime(&"vcam_orbit", "orbit")
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(reduced.get("active_vcam_id"), StringName("vcam_orbit"))
	assert_eq(reduced.get("active_mode"), "orbit")

func test_start_blend_sets_blend_state() -> void:
	var state := _make_state()
	var set_active := U_VCamActions.set_active_runtime(&"vcam_new", "fixed")
	var active_state: Dictionary = U_VCamReducer.reduce(state, set_active)
	var blend_action := U_VCamActions.start_blend(&"vcam_prev")
	var reduced: Dictionary = U_VCamReducer.reduce(active_state, blend_action)

	assert_true(reduced.get("is_blending", false))
	assert_almost_eq(float(reduced.get("blend_progress", 1.0)), 0.0, 0.0001)
	assert_eq(reduced.get("previous_vcam_id"), StringName("vcam_prev"))
	assert_eq(reduced.get("blend_from_vcam_id"), StringName("vcam_prev"))
	assert_eq(reduced.get("blend_to_vcam_id"), StringName("vcam_new"))

func test_update_blend_clamps_progress_to_zero_to_one() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_blend(0.5)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("blend_progress", -1.0)), 0.5, 0.0001)

func test_update_blend_clamps_progress_below_zero() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_blend(-2.0)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("blend_progress", -1.0)), 0.0, 0.0001)

func test_update_blend_clamps_progress_above_one() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_blend(4.0)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_almost_eq(float(reduced.get("blend_progress", -1.0)), 1.0, 0.0001)

func test_complete_blend_clears_transient_blend_fields() -> void:
	var state := _make_state()
	state["is_blending"] = true
	state["blend_progress"] = 0.33
	state["previous_vcam_id"] = StringName("vcam_prev")
	state["blend_from_vcam_id"] = StringName("vcam_prev")
	state["blend_to_vcam_id"] = StringName("vcam_new")
	var action := U_VCamActions.complete_blend()
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_false(reduced.get("is_blending", true))
	assert_almost_eq(float(reduced.get("blend_progress", -1.0)), 1.0, 0.0001)
	assert_eq(reduced.get("previous_vcam_id"), StringName(""))
	assert_eq(reduced.get("blend_from_vcam_id"), StringName(""))
	assert_eq(reduced.get("blend_to_vcam_id"), StringName(""))

func test_update_silhouette_count_clamps_to_non_negative() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_silhouette_count(7)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(reduced.get("silhouette_active_count"), 7)

func test_update_silhouette_count_negative_clamps_to_zero() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_silhouette_count(-9)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(reduced.get("silhouette_active_count"), 0)

func test_update_target_validity_sets_flag() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_target_validity(false)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_false(reduced.get("active_target_valid", true))

func test_record_recovery_sets_reason() -> void:
	var state := _make_state()
	var action := U_VCamActions.record_recovery("fixed_anchor_invalid")
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(reduced.get("last_recovery_reason"), "fixed_anchor_invalid")

func test_update_fov_zone_sets_flag() -> void:
	var state := _make_state()
	var action := U_VCamActions.update_fov_zone(true)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_true(reduced.get("in_fov_zone", false))

func test_unknown_action_returns_same_state() -> void:
	var state := _make_state()
	var action := {"type": StringName("vcam/unknown")}
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(reduced, state)

func test_reducer_immutability_original_state_not_mutated() -> void:
	var state := _make_state()
	var original_copy := state.duplicate(true)
	var action := U_VCamActions.update_fov_zone(true)
	var reduced: Dictionary = U_VCamReducer.reduce(state, action)

	assert_eq(state, original_copy)
	assert_ne(reduced, state)

func _make_state() -> Dictionary:
	return U_VCamReducer.get_default_vcam_state()
