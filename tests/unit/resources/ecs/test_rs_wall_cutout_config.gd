extends GutTest

const SCRIPT_PATH := "res://scripts/core/resources/ecs/rs_wall_cutout_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_WallCutoutConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_WallCutoutConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_are_sane() -> void:
	var config := _new_config()
	if config == null:
		return
	var near_radius := float(config.get("cone_near_radius"))
	var far_radius := float(config.get("cone_far_radius"))
	var falloff := float(config.get("cone_falloff"))
	var min_alpha := float(config.get("cone_min_alpha"))

	assert_gt(near_radius, 0.0, "near radius should be positive by default")
	assert_gt(far_radius, near_radius, "far radius should be larger than near radius (cone widens toward player)")
	assert_gt(falloff, 0.0, "falloff should be positive so the cutout edge is soft")
	assert_between(min_alpha, 0.0, 1.0, "min_alpha must be a valid alpha in [0,1]")


func test_class_name_is_registered() -> void:
	var script_obj := _load_script()
	if script_obj == null:
		return
	assert_eq(script_obj.get_global_name(), &"RS_WallCutoutConfig", "class_name must be RS_WallCutoutConfig")
