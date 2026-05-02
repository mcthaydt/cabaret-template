extends GutTest

## Tests for RS_GameConfig schema validation (F15).
##
## Validates that required fields push_error when set to empty values,
## and that valid values produce no errors.

const RS_GAME_CONFIG_PATH := "res://scripts/core/resources/rs_game_config.gd"
const TEST_RESOURCE_PATH := "res://tests/unit/resources/test_cfg_game_config_invalid.tres"


func test_empty_default_gameplay_scene_id_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.default_gameplay_scene_id = StringName("")
	assert_push_error("default_gameplay_scene_id must not be empty")


func test_empty_route_retry_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.route_retry = StringName("")
	assert_push_error("route_retry must not be empty")


func test_empty_default_objective_set_id_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.default_objective_set_id = StringName("")
	assert_push_error("default_objective_set_id must not be empty")


func test_empty_required_final_area_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.required_final_area = ""
	assert_push_error("required_final_area must not be empty")


func test_empty_game_name_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.game_name = ""
	assert_push_error("game_name must not be empty")


func test_empty_studio_name_pushes_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.studio_name = ""
	assert_push_error("studio_name must not be empty")


func test_valid_defaults_produce_no_errors() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	# Defaults are all non-empty, so no errors should be pushed.
	# Re-assigning defaults should also be clean.
	config.retry_scene_id = config.retry_scene_id
	config.default_gameplay_scene_id = config.default_gameplay_scene_id
	config.route_retry = config.route_retry
	config.default_objective_set_id = config.default_objective_set_id
	config.required_final_area = config.required_final_area
	config.game_name = config.game_name
	config.studio_name = config.studio_name
	assert_eq(config.retry_scene_id, StringName("demo_room"), "Default retry_scene_id preserved")
	assert_eq(config.default_gameplay_scene_id, StringName("demo_room"), "Default gameplay scene preserved")
	assert_eq(config.get_default_gameplay_scene_id(), StringName("demo_room"), "Resolved default gameplay scene preserved")
	assert_eq(config.get_retry_scene_id(), StringName("demo_room"), "Resolved retry scene preserved")
	assert_eq(config.route_retry, StringName("retry"), "Default route_retry preserved")
	assert_eq(config.default_objective_set_id, StringName("default_progression"), "Default objective set preserved")
	assert_eq(config.required_final_area, "demo_room", "Default required_final_area preserved")
	assert_eq(config.game_name, "Automata Template", "Default game_name preserved")
	assert_eq(config.studio_name, "Ruken", "Default studio_name preserved")


func test_resolved_retry_scene_uses_default_gameplay_scene_when_retry_is_empty() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.default_gameplay_scene_id = StringName("scene2")
	config.retry_scene_id = StringName("")
	assert_eq(config.get_retry_scene_id(), StringName("scene2"), "Empty retry scene should resolve to default gameplay scene")


func test_error_includes_resource_path() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	# Assign a resource_path to simulate .tres loading, then set invalid value.
	config.resource_path = TEST_RESOURCE_PATH
	config.default_gameplay_scene_id = StringName("")
	assert_push_error(TEST_RESOURCE_PATH)


func test_multiple_empty_fields_each_push_error() -> void:
	var config := RS_GameConfig.new()
	autofree(config)
	config.retry_scene_id = StringName("")
	config.default_gameplay_scene_id = StringName("")
	config.route_retry = StringName("")
	config.default_objective_set_id = StringName("")
	config.required_final_area = ""
	config.game_name = ""
	config.studio_name = ""
	assert_push_error("default_gameplay_scene_id must not be empty")
	assert_push_error("route_retry must not be empty")
	assert_push_error("default_objective_set_id must not be empty")
	assert_push_error("required_final_area must not be empty")
	assert_push_error("game_name must not be empty")
	assert_push_error("studio_name must not be empty")
