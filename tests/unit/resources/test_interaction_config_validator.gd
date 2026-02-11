extends GutTest

const BASE_CONFIG_PATH := "res://scripts/resources/interactions/rs_interaction_config.gd"
const DOOR_CONFIG_PATH := "res://scripts/resources/interactions/rs_door_interaction_config.gd"
const CHECKPOINT_CONFIG_PATH := "res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd"
const HAZARD_CONFIG_PATH := "res://scripts/resources/interactions/rs_hazard_interaction_config.gd"
const VICTORY_CONFIG_PATH := "res://scripts/resources/interactions/rs_victory_interaction_config.gd"
const SIGNPOST_CONFIG_PATH := "res://scripts/resources/interactions/rs_signpost_interaction_config.gd"
const ENDGAME_CONFIG_PATH := "res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd"
const VALIDATOR_PATH := "res://scripts/gameplay/helpers/u_interaction_config_validator.gd"

func _load_script(path: String) -> Script:
	var script_obj := load(path) as Script
	assert_not_null(script_obj, "Script should load: %s" % path)
	return script_obj

func _new_resource(path: String) -> Resource:
	var script_obj := _load_script(path)
	if script_obj == null:
		return null
	var instance := script_obj.new() as Resource
	assert_not_null(instance, "Resource instance should be creatable: %s" % path)
	return instance

func test_resource_scripts_load_and_instantiate() -> void:
	_new_resource(BASE_CONFIG_PATH)
	_new_resource(DOOR_CONFIG_PATH)
	_new_resource(CHECKPOINT_CONFIG_PATH)
	_new_resource(HAZARD_CONFIG_PATH)
	_new_resource(VICTORY_CONFIG_PATH)
	_new_resource(SIGNPOST_CONFIG_PATH)
	_new_resource(ENDGAME_CONFIG_PATH)
	_load_script(VALIDATOR_PATH)

func test_base_config_defaults_and_required_trigger_settings() -> void:
	var base_config := _new_resource(BASE_CONFIG_PATH)
	if base_config == null:
		return

	assert_eq(base_config.get("interaction_id"), StringName(""))
	assert_eq(base_config.get("enabled_by_default"), true)
	assert_not_null(base_config.get("trigger_settings"), "Base config should create default trigger settings")
	assert_false(base_config.get("interaction_hint_enabled"), "World hint should default to opt-in disabled")
	assert_eq(base_config.get("interaction_hint_scale"), 1.0, "World hint scale should have stable default")

func test_validator_rejects_empty_base_interaction_id() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var base_config := _new_resource(BASE_CONFIG_PATH)
	if validator == null or base_config == null:
		return

	var result: Dictionary = validator.call("validate_config", base_config, "res://tests/unit/resources/base")
	assert_false(bool(result.get("is_valid", true)))
	assert_gt((result.get("errors", []) as Array).size(), 0)

func test_validator_rejects_door_missing_target_fields() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var door_config := _new_resource(DOOR_CONFIG_PATH)
	if validator == null or door_config == null:
		return

	door_config.set("interaction_id", StringName("door_main"))
	door_config.set("door_id", StringName(""))
	door_config.set("target_scene_id", StringName(""))
	door_config.set("target_spawn_point", StringName(""))

	var result: Dictionary = validator.call("validate_config", door_config, "res://tests/unit/resources/door")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("door_id")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("target_scene_id")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("target_spawn_point")))

func test_validator_rejects_door_invalid_trigger_mode_and_negative_cooldown() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var door_config := _new_resource(DOOR_CONFIG_PATH)
	if validator == null or door_config == null:
		return

	door_config.set("interaction_id", StringName("door_mode_check"))
	door_config.set("door_id", StringName("door_a"))
	door_config.set("target_scene_id", StringName("scene_a"))
	door_config.set("target_spawn_point", StringName("sp_a"))
	door_config.set("trigger_mode", 77)
	door_config.set("cooldown_duration", -2.0)

	var result: Dictionary = validator.call("validate_config", door_config, "res://tests/unit/resources/door_invalid")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("trigger_mode")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("cooldown_duration")))

func test_validator_rejects_checkpoint_missing_required_ids() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var checkpoint_config := _new_resource(CHECKPOINT_CONFIG_PATH)
	if validator == null or checkpoint_config == null:
		return

	checkpoint_config.set("interaction_id", StringName("checkpoint_main"))
	checkpoint_config.set("checkpoint_id", StringName(""))
	checkpoint_config.set("spawn_point_id", StringName(""))

	var result: Dictionary = validator.call("validate_config", checkpoint_config, "res://tests/unit/resources/checkpoint")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("checkpoint_id")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("spawn_point_id")))

func test_validator_rejects_hazard_negative_values() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var hazard_config := _new_resource(HAZARD_CONFIG_PATH)
	if validator == null or hazard_config == null:
		return

	hazard_config.set("interaction_id", StringName("hazard_main"))
	hazard_config.set("damage_amount", -1.0)
	hazard_config.set("damage_cooldown", -0.1)

	var result: Dictionary = validator.call("validate_config", hazard_config, "res://tests/unit/resources/hazard")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("damage_amount")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("damage_cooldown")))

func test_validator_rejects_invalid_victory_enum_and_missing_fields() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var victory_config := _new_resource(VICTORY_CONFIG_PATH)
	if validator == null or victory_config == null:
		return

	victory_config.set("interaction_id", StringName("victory_main"))
	victory_config.set("objective_id", StringName(""))
	victory_config.set("area_id", "")
	victory_config.set("victory_type", 999)

	var result: Dictionary = validator.call("validate_config", victory_config, "res://tests/unit/resources/victory")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("victory_type")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("objective_id") or String(msg).contains("area_id")))

func test_validator_rejects_level_complete_without_objective_id() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var victory_config := _new_resource(VICTORY_CONFIG_PATH)
	if validator == null or victory_config == null:
		return

	victory_config.set("interaction_id", StringName("victory_combo"))
	victory_config.set("victory_type", 0) # LEVEL_COMPLETE
	victory_config.set("objective_id", StringName(""))
	victory_config.set("area_id", "interior_house")

	var result: Dictionary = validator.call("validate_config", victory_config, "res://tests/unit/resources/victory_combo")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("LEVEL_COMPLETE")))

func test_validator_rejects_empty_signpost_message() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var signpost_config := _new_resource(SIGNPOST_CONFIG_PATH)
	if validator == null or signpost_config == null:
		return

	signpost_config.set("interaction_id", StringName("signpost_main"))
	signpost_config.set("message", "")

	var result: Dictionary = validator.call("validate_config", signpost_config, "res://tests/unit/resources/signpost")
	assert_false(bool(result.get("is_valid", true)))
	assert_true((result.get("errors", []) as Array).any(func(msg: Variant): return String(msg).contains("message")))

func test_signpost_config_defaults_message_duration_to_three_seconds() -> void:
	var signpost_config := _new_resource(SIGNPOST_CONFIG_PATH)
	if signpost_config == null:
		return

	assert_eq(signpost_config.get("message_duration_sec"), 3.0,
		"Signpost config should default message_duration_sec to 3.0 seconds")

func test_validator_rejects_signpost_non_positive_message_duration() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var signpost_config := _new_resource(SIGNPOST_CONFIG_PATH)
	if validator == null or signpost_config == null:
		return

	signpost_config.set("interaction_id", StringName("signpost_duration_check"))
	signpost_config.set("message", "Valid message")
	signpost_config.set("message_duration_sec", 0.0)

	var result: Dictionary = validator.call("validate_config", signpost_config, "res://tests/unit/resources/signpost_duration")
	assert_false(bool(result.get("is_valid", true)))
	assert_true((result.get("errors", []) as Array).any(func(msg: Variant): return String(msg).contains("message_duration_sec")))

func test_validator_rejects_endgame_goal_when_required_area_empty_or_wrong_type() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var endgame_config := _new_resource(ENDGAME_CONFIG_PATH)
	if validator == null or endgame_config == null:
		return

	endgame_config.set("interaction_id", StringName("endgame_goal"))
	endgame_config.set("required_area", "")
	endgame_config.set("victory_type", 0) # LEVEL_COMPLETE should be invalid for endgame goal

	var result: Dictionary = validator.call("validate_config", endgame_config, "res://tests/unit/resources/endgame")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("required_area")))
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("GAME_COMPLETE")))

func test_validator_rejects_missing_trigger_settings() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var base_config := _new_resource(BASE_CONFIG_PATH)
	if validator == null or base_config == null:
		return

	base_config.set("interaction_id", StringName("base_trigger_type"))
	base_config.set("trigger_settings", null)

	var result: Dictionary = validator.call("validate_config", base_config, "res://tests/unit/resources/base_trigger")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("trigger_settings")))

func test_validator_rejects_enabled_world_hint_without_texture() -> void:
	var validator := _load_script(VALIDATOR_PATH)
	var base_config := _new_resource(BASE_CONFIG_PATH)
	if validator == null or base_config == null:
		return

	base_config.set("interaction_id", StringName("hint_enabled_without_texture"))
	base_config.set("interaction_hint_enabled", true)
	base_config.set("interaction_hint_icon", null)

	var result: Dictionary = validator.call("validate_config", base_config, "res://tests/unit/resources/base_hint")
	assert_false(bool(result.get("is_valid", true)))
	var errors := result.get("errors", []) as Array
	assert_true(errors.any(func(msg: Variant): return String(msg).contains("interaction_hint_icon")))
