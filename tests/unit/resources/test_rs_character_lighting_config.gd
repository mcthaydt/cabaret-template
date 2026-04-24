extends GutTest

const SCRIPT_PATH := "res://scripts/core/resources/managers/rs_character_lighting_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_CharacterLightingConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_CharacterLightingConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_match_character_lighting_manager_fallbacks() -> void:
	var config := _new_config()
	if config == null:
		return
	assert_eq(int(config.get("mobile_tick_interval")), 3)
	assert_eq(config.get("default_profile"), null)
	assert_eq(config.get("default_tint"), Color(1.0, 1.0, 1.0, 1.0))
	assert_almost_eq(float(config.get("default_intensity")), 1.0, 0.0001)
	assert_almost_eq(float(config.get("default_blend_smoothing")), 0.15, 0.0001)


func test_get_default_profile_values_uses_fallback_without_profile() -> void:
	var config := _new_config()
	if config == null:
		return
	var resolved: Variant = config.call("get_default_profile_values")
	assert_true(resolved is Dictionary)
	var values: Dictionary = resolved as Dictionary
	assert_eq(values.get("tint"), Color(1.0, 1.0, 1.0, 1.0))
	assert_almost_eq(float(values.get("intensity", 0.0)), 1.0, 0.0001)
	assert_almost_eq(float(values.get("blend_smoothing", 0.0)), 0.15, 0.0001)
