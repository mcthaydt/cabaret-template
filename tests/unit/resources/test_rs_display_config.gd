extends GutTest

const SCRIPT_PATH := "res://scripts/core/resources/managers/rs_display_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_DisplayConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_DisplayConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_match_display_manager_limits() -> void:
	var config := _new_config()
	if config == null:
		return
	assert_almost_eq(float(config.get("min_ui_scale")), 0.8, 0.0001)
	assert_almost_eq(float(config.get("max_ui_scale")), 1.3, 0.0001)
	assert_almost_eq(float(config.get("min_mobile_resolution_scale")), 0.35, 0.0001)
