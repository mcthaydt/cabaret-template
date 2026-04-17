extends GutTest

const SCRIPT_PATH := "res://scripts/resources/ecs/rs_camera_state_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_CameraStateConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_CameraStateConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_match_camera_state_constants() -> void:
	var config := _new_config()
	if config == null:
		return
	assert_almost_eq(float(config.get("trauma_decay_rate")), 2.0, 0.0001)
	assert_almost_eq(float(config.get("max_offset_x")), 10.0, 0.0001)
	assert_almost_eq(float(config.get("max_offset_y")), 10.0, 0.0001)
	assert_almost_eq(float(config.get("max_rotation_rad")), 0.03, 0.0001)
	assert_eq(config.get("shake_frequency"), Vector3(17.0, 21.0, 13.0))
	assert_eq(config.get("shake_phase"), Vector3(1.1, 2.3, 0.7))
	assert_almost_eq(float(config.get("fov_min")), 1.0, 0.0001)
	assert_almost_eq(float(config.get("fov_max")), 179.0, 0.0001)

