extends RefCounted
class_name U_InteractionConfigValidator

const C_SCENE_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")
const C_VICTORY_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_victory_trigger_component.gd")
const RS_SCENE_TRIGGER_SETTINGS := preload("res://scripts/resources/ecs/rs_scene_trigger_settings.gd")
const RS_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_interaction_config.gd")
const RS_DOOR_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_door_interaction_config.gd")
const RS_CHECKPOINT_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd")
const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_hazard_interaction_config.gd")
const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")
const RS_SIGNPOST_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_signpost_interaction_config.gd")
const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd")

static func validate_config(config: Resource, context_path: String = "", emit_messages: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var context := context_path if not context_path.is_empty() else "<unknown>"

	if config == null:
		_record_error(errors, context, "config", "config is null", emit_messages)
		return _build_result(errors, warnings)

	if not _script_matches(config, RS_INTERACTION_CONFIG):
		_record_error(errors, context, "config", "config must extend RS_InteractionConfig", emit_messages)
		return _build_result(errors, warnings)

	_validate_base(config, context, errors, emit_messages)

	if _script_matches(config, RS_DOOR_INTERACTION_CONFIG):
		_validate_door(config, context, errors, emit_messages)
	elif _script_matches(config, RS_CHECKPOINT_INTERACTION_CONFIG):
		_validate_checkpoint(config, context, errors, emit_messages)
	elif _script_matches(config, RS_HAZARD_INTERACTION_CONFIG):
		_validate_hazard(config, context, errors, emit_messages)
	elif _script_matches(config, RS_ENDGAME_GOAL_INTERACTION_CONFIG):
		_validate_victory(config, context, errors, emit_messages)
		_validate_endgame_goal(config, context, errors, emit_messages)
	elif _script_matches(config, RS_VICTORY_INTERACTION_CONFIG):
		_validate_victory(config, context, errors, emit_messages)
	elif _script_matches(config, RS_SIGNPOST_INTERACTION_CONFIG):
		_validate_signpost(config, context, errors, emit_messages)
	else:
		_record_warning(warnings, context, "config", "unknown interaction config subtype", emit_messages)

	return _build_result(errors, warnings)

static func _script_matches(config: Resource, expected_script: Script) -> bool:
	if config == null or expected_script == null:
		return false

	var script_obj := config.get_script() as Script
	while script_obj != null:
		if script_obj == expected_script:
			return true
		script_obj = script_obj.get_base_script()

	return false

static func _validate_base(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	var interaction_id := _as_string_name(config.get("interaction_id"))
	if interaction_id.is_empty():
		_record_error(errors, context, "interaction_id", "must be non-empty", emit_messages)

	var trigger_settings_variant: Variant = config.get("trigger_settings")
	if trigger_settings_variant == null:
		_record_error(errors, context, "trigger_settings", "must be assigned", emit_messages)
		return
	if not (trigger_settings_variant is Resource):
		_record_error(errors, context, "trigger_settings", "must be a Resource", emit_messages)
		return

	var trigger_settings := trigger_settings_variant as Resource
	if not _script_matches(trigger_settings, RS_SCENE_TRIGGER_SETTINGS):
		_record_error(
			errors,
			context,
			"trigger_settings",
			"must extend RS_SceneTriggerSettings",
			emit_messages
		)

	var hint_scale := _as_float(config.get("interaction_hint_scale"), 1.0)
	if hint_scale <= 0.0:
		_record_error(
			errors,
			context,
			"interaction_hint_scale",
			"must be > 0; got %s" % str(hint_scale),
			emit_messages
		)

	var hint_enabled := _as_bool(config.get("interaction_hint_enabled"), false)
	var hint_icon_variant: Variant = config.get("interaction_hint_icon")
	if hint_enabled and not (hint_icon_variant is Texture2D):
		_record_error(
			errors,
			context,
			"interaction_hint_icon",
			"must be assigned when interaction_hint_enabled is true",
			emit_messages
		)

static func _validate_door(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	if _as_string_name(config.get("door_id")).is_empty():
		_record_error(errors, context, "door_id", "must be non-empty", emit_messages)
	if _as_string_name(config.get("target_scene_id")).is_empty():
		_record_error(errors, context, "target_scene_id", "must be non-empty", emit_messages)
	if _as_string_name(config.get("target_spawn_point")).is_empty():
		_record_error(errors, context, "target_spawn_point", "must be non-empty", emit_messages)

	var trigger_mode := _as_int(config.get("trigger_mode"), -1)
	if trigger_mode != C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO and trigger_mode != C_SCENE_TRIGGER_COMPONENT.TriggerMode.INTERACT:
		_record_error(
			errors,
			context,
			"trigger_mode",
			"must be AUTO(0) or INTERACT(1); got %s" % str(trigger_mode),
			emit_messages
		)

	var cooldown_duration := _as_float(config.get("cooldown_duration"), 0.0)
	if cooldown_duration < 0.0:
		_record_error(
			errors,
			context,
			"cooldown_duration",
			"must be >= 0; got %s" % str(cooldown_duration),
			emit_messages
		)

static func _validate_checkpoint(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	if _as_string_name(config.get("checkpoint_id")).is_empty():
		_record_error(errors, context, "checkpoint_id", "must be non-empty", emit_messages)
	if _as_string_name(config.get("spawn_point_id")).is_empty():
		_record_error(errors, context, "spawn_point_id", "must be non-empty", emit_messages)

static func _validate_hazard(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	var damage_amount := _as_float(config.get("damage_amount"), 0.0)
	if damage_amount < 0.0:
		_record_error(
			errors,
			context,
			"damage_amount",
			"must be >= 0; got %s" % str(damage_amount),
			emit_messages
		)

	var damage_cooldown := _as_float(config.get("damage_cooldown"), 0.0)
	if damage_cooldown < 0.0:
		_record_error(
			errors,
			context,
			"damage_cooldown",
			"must be >= 0; got %s" % str(damage_cooldown),
			emit_messages
		)

static func _validate_victory(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	var victory_type := _as_int(config.get("victory_type"), -1)
	var level_complete := C_VICTORY_TRIGGER_COMPONENT.VictoryType.LEVEL_COMPLETE
	var game_complete := C_VICTORY_TRIGGER_COMPONENT.VictoryType.GAME_COMPLETE
	if victory_type != level_complete and victory_type != game_complete:
		_record_error(
			errors,
			context,
			"victory_type",
			"must be LEVEL_COMPLETE(0) or GAME_COMPLETE(1); got %s" % str(victory_type),
			emit_messages
		)

	var objective_id := _as_string_name(config.get("objective_id"))
	var area_id := _as_trimmed_string(config.get("area_id"))
	if objective_id.is_empty() and area_id.is_empty():
		_record_error(errors, context, "objective_id", "objective_id or area_id must be set", emit_messages)
	if victory_type == level_complete and objective_id.is_empty():
		_record_error(
			errors,
			context,
			"objective_id",
			"LEVEL_COMPLETE requires non-empty objective_id",
			emit_messages
		)

static func _validate_signpost(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	var message := _as_trimmed_string(config.get("message"))
	if message.is_empty():
		_record_error(errors, context, "message", "must be non-empty", emit_messages)

	var message_duration_sec := _as_float(config.get("message_duration_sec"), 0.0)
	if message_duration_sec <= 0.0:
		_record_error(
			errors,
			context,
			"message_duration_sec",
			"must be > 0; got %s" % str(message_duration_sec),
			emit_messages
		)

static func _validate_endgame_goal(config: Resource, context: String, errors: Array[String], emit_messages: bool) -> void:
	var required_area := _as_trimmed_string(config.get("required_area"))
	if required_area.is_empty():
		_record_error(errors, context, "required_area", "must be non-empty", emit_messages)

	var victory_type := _as_int(config.get("victory_type"), -1)
	if victory_type != C_VICTORY_TRIGGER_COMPONENT.VictoryType.GAME_COMPLETE:
		_record_error(
			errors,
			context,
			"victory_type",
			"must be GAME_COMPLETE(1) for endgame goals; got %s" % str(victory_type),
			emit_messages
		)

static func _as_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _as_trimmed_string(value: Variant) -> String:
	if value is String:
		return (value as String).strip_edges()
	if value is StringName:
		return String(value).strip_edges()
	return ""

static func _as_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback

static func _as_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback

static func _as_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	return fallback

static func _build_result(errors: Array[String], warnings: Array[String]) -> Dictionary:
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}

static func _record_error(errors: Array[String], context: String, field: String, message: String, emit_messages: bool) -> void:
	var text := "%s [%s] %s" % [context, field, message]
	errors.append(text)
	if emit_messages:
		push_error("U_InteractionConfigValidator: %s" % text)

static func _record_warning(warnings: Array[String], context: String, field: String, message: String, emit_messages: bool) -> void:
	var text := "%s [%s] %s" % [context, field, message]
	warnings.append(text)
	if emit_messages:
		push_warning("U_InteractionConfigValidator: %s" % text)
