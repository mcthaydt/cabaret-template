extends GutTest

const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_FIXED := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")
const RS_VCAM_RESPONSE := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")

const DEFAULT_ORBIT_PATH := "res://resources/display/vcam/cfg_default_orbit.tres"
const DEFAULT_FIRST_PERSON_PATH := "res://resources/display/vcam/cfg_default_first_person.tres"
const DEFAULT_FIXED_PATH := "res://resources/display/vcam/cfg_default_fixed.tres"
const DEFAULT_RESPONSE_PATH := "res://resources/display/vcam/cfg_default_response.tres"

func test_default_orbit_preset_loads_as_orbit_mode() -> void:
	var preset := load(DEFAULT_ORBIT_PATH) as Resource
	assert_not_null(preset, "Default orbit preset should load")
	assert_true(preset.get_script() == RS_VCAM_MODE_ORBIT, "Default orbit preset should use RS_VCamModeOrbit")

func test_default_first_person_preset_loads_as_first_person_mode() -> void:
	var preset := load(DEFAULT_FIRST_PERSON_PATH) as Resource
	assert_not_null(preset, "Default first-person preset should load")
	assert_true(
		preset.get_script() == RS_VCAM_MODE_FIRST_PERSON,
		"Default first-person preset should use RS_VCamModeFirstPerson"
	)

func test_default_fixed_preset_loads_as_fixed_mode() -> void:
	var preset := load(DEFAULT_FIXED_PATH) as Resource
	assert_not_null(preset, "Default fixed preset should load")
	assert_true(preset.get_script() == RS_VCAM_MODE_FIXED, "Default fixed preset should use RS_VCamModeFixed")

func test_default_response_preset_loads_as_response_mode() -> void:
	var preset := load(DEFAULT_RESPONSE_PATH) as Resource
	assert_not_null(preset, "Default response preset should load")
	assert_true(preset.get_script() == RS_VCAM_RESPONSE, "Default response preset should use RS_VCamResponse")

func test_default_response_preset_matches_orbit_tuning_baseline() -> void:
	var preset := load(DEFAULT_RESPONSE_PATH) as Resource
	assert_not_null(preset, "Default response preset should load")
	assert_almost_eq(float(preset.get("follow_frequency")), 3.8, 0.0001)
	assert_almost_eq(float(preset.get("follow_damping")), 1.0, 0.0001)
	assert_almost_eq(float(preset.get("rotation_frequency")), 4.8, 0.0001)
	assert_almost_eq(float(preset.get("rotation_damping")), 0.9, 0.0001)
	assert_almost_eq(float(preset.get("look_ahead_distance")), 0.02, 0.0001)
	assert_almost_eq(float(preset.get("look_ahead_smoothing")), 1.77, 0.0001)
	assert_almost_eq(float(preset.get("orbit_look_bypass_enable_speed")), 7.0, 0.0001)
	assert_almost_eq(float(preset.get("orbit_look_bypass_disable_speed")), 8.5, 0.0001)
	assert_true(bool(preset.get("ground_relative_enabled")))
	assert_almost_eq(float(preset.get("ground_reanchor_min_height_delta")), 1.0, 0.0001)
	assert_almost_eq(float(preset.get("ground_probe_max_distance")), 12.0, 0.0001)
	assert_almost_eq(float(preset.get("ground_anchor_blend_hz")), 4.0, 0.0001)
