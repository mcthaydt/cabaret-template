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


func _read_float(config: Resource, property_name: String) -> float:
	var value: Variant = config.get(property_name)
	assert_true(value is float or value is int, "%s should be defined as a numeric export" % property_name)
	if value is float or value is int:
		return float(value)
	return 0.0


func test_resource_script_loads_and_instantiates() -> void:
	_new_config()


func test_defaults_are_sane() -> void:
	var config := _new_config()
	if config == null:
		return
	var radius := float(config.get("disc_radius"))
	var falloff := float(config.get("disc_falloff"))
	var min_alpha := float(config.get("disc_min_alpha"))
	var center_offset := _read_float(config, "disc_center_height_offset")
	var target_coverage := _read_float(config, "disc_target_height_coverage")
	var max_radius := _read_float(config, "disc_max_radius")
	var player_height := _read_float(config, "disc_player_height_meters")

	assert_gt(radius, 0.0, "disc_radius should be positive by default")
	assert_lt(radius, 1.0, "disc_radius is fraction of viewport height; default should be much less than 1")
	assert_gt(falloff, 0.0, "disc_falloff should be positive so the cutout edge is soft")
	assert_between(min_alpha, 0.1, 0.4, "disc_min_alpha should keep wall residue so cutouts do not become solid black voids")
	assert_gt(center_offset, 0.0, "disc_center_height_offset should aim the cutout at the player's visual center")
	assert_almost_eq(center_offset, 0.5, 0.001,
		"disc_center_height_offset should match the one-tile player visual center")
	assert_gte(target_coverage, 2.0, "disc_target_height_coverage should make the cutout substantially larger than the projected player")
	assert_gt(max_radius, radius, "disc_max_radius should allow the radius to expand when the player is close")
	assert_gte(max_radius, 0.5, "disc_max_radius should allow large close-range cutouts now that per-wall occlusion gates prevent side-wall artifacts")
	assert_gt(player_height, center_offset, "disc_player_height_meters should describe the full visual height")
	assert_almost_eq(player_height, 1.0, 0.001,
		"disc_player_height_meters should match the one-tile default humanoid visual")


func test_class_name_is_registered() -> void:
	var script_obj := _load_script()
	if script_obj == null:
		return
	assert_eq(script_obj.get_global_name(), &"RS_WallCutoutConfig", "class_name must be RS_WallCutoutConfig")
