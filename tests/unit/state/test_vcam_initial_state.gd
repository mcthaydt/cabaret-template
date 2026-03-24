extends GutTest


var initial_state: RS_VCamInitialState

func before_each() -> void:
	initial_state = RS_VCamInitialState.new()

func after_each() -> void:
	initial_state = null

func test_to_dictionary_active_vcam_id_defaults_to_empty_string_name() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("active_vcam_id"), StringName(""))

func test_to_dictionary_active_mode_defaults_to_empty_string() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("active_mode"), "")

func test_to_dictionary_previous_vcam_id_defaults_to_empty_string_name() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("previous_vcam_id"), StringName(""))

func test_to_dictionary_blend_progress_defaults_to_one() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("blend_progress"), 1.0)

func test_to_dictionary_is_blending_defaults_to_false() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_false(dict.get("is_blending", true))

func test_to_dictionary_silhouette_active_count_defaults_to_zero() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("silhouette_active_count"), 0)

func test_to_dictionary_blend_from_vcam_id_defaults_to_empty_string_name() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("blend_from_vcam_id"), StringName(""))

func test_to_dictionary_blend_to_vcam_id_defaults_to_empty_string_name() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("blend_to_vcam_id"), StringName(""))

func test_to_dictionary_active_target_valid_defaults_to_true() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_true(dict.get("active_target_valid", false))

func test_to_dictionary_last_recovery_reason_defaults_to_empty_string() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.get("last_recovery_reason"), "")

func test_to_dictionary_in_fov_zone_defaults_to_false() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_false(dict.get("in_fov_zone", true))

func test_to_dictionary_returns_exactly_eleven_keys() -> void:
	var dict: Dictionary = initial_state.to_dictionary()
	assert_eq(dict.size(), 11)
