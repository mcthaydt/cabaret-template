extends GutTest

const SCRIPT_PATH := "res://scripts/resources/ecs/rs_wall_visibility_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_WallVisibilityConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_WallVisibilityConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_match_wall_visibility_constants() -> void:
	var config := _new_config()
	if config == null:
		return
	assert_almost_eq(float(config.get("fade_dot_threshold")), 0.3, 0.0001)
	assert_almost_eq(float(config.get("fade_speed")), 4.0, 0.0001)
	assert_almost_eq(float(config.get("min_alpha")), 0.05, 0.0001)
	assert_almost_eq(float(config.get("clip_height_offset")), 1.5, 0.0001)
	assert_almost_eq(float(config.get("room_aabb_margin")), 2.0, 0.0001)
	assert_almost_eq(float(config.get("corridor_occlusion_margin")), 2.0, 0.0001)
	assert_eq(int(config.get("invalidate_interval")), 30)
	assert_eq(int(config.get("mobile_tick_interval")), 4)
	assert_almost_eq(float(config.get("roof_normal_dot_min")), 0.9, 0.0001)
	assert_almost_eq(float(config.get("roof_height_margin")), 0.5, 0.0001)

