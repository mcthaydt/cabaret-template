extends GutTest

const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_FIXED := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")

const DEFAULT_ORBIT_PATH := "res://resources/display/vcam/cfg_default_orbit.tres"
const DEFAULT_FIRST_PERSON_PATH := "res://resources/display/vcam/cfg_default_first_person.tres"
const DEFAULT_FIXED_PATH := "res://resources/display/vcam/cfg_default_fixed.tres"

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
