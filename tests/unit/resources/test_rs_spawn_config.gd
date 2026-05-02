extends GutTest

const SCRIPT_PATH := "res://scripts/core/resources/managers/rs_spawn_config.gd"


func _load_script() -> Script:
	var script_obj := load(SCRIPT_PATH) as Script
	assert_not_null(script_obj, "RS_SpawnConfig script should exist")
	return script_obj


func _new_config() -> Resource:
	var script_obj := _load_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	assert_true(config is Resource, "RS_SpawnConfig should instantiate as Resource")
	return config as Resource


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_match_spawn_manager_constants() -> void:
	var config := _new_config()
	if config == null:
		return
	assert_almost_eq(float(config.get("ground_snap_max_distance")), 8.0, 0.0001)
	assert_almost_eq(float(config.get("hover_snap_max_distance")), 0.75, 0.0001)
	assert_eq(int(config.get("spawn_condition_always")), 0)
	assert_eq(int(config.get("spawn_condition_checkpoint_only")), 1)
	assert_eq(int(config.get("spawn_condition_disabled")), 2)

