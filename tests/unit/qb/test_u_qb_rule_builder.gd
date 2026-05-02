extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/qb/u_qb_rule_builder.gd"
const RS_RULE_PATH := "res://scripts/core/resources/qb/rs_rule.gd"

const CONDITION_EVENT_NAME_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_event_name.gd"
const CONDITION_EVENT_PAYLOAD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_event_payload.gd"
const CONDITION_COMPONENT_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd"
const CONDITION_REDUX_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd"
const CONDITION_ENTITY_TAG_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd"
const CONDITION_CONTEXT_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_context_field.gd"
const CONDITION_CONSTANT_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_constant.gd"
const CONDITION_COMPOSITE_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_composite.gd"

const EFFECT_PUBLISH_EVENT_PATH := "res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd"
const EFFECT_SET_FIELD_PATH := "res://scripts/core/resources/qb/effects/rs_effect_set_field.gd"
const EFFECT_SET_CONTEXT_VALUE_PATH := "res://scripts/core/resources/qb/effects/rs_effect_set_context_value.gd"
const EFFECT_DISPATCH_ACTION_PATH := "res://scripts/core/resources/qb/effects/rs_effect_dispatch_action.gd"

const U_RULE_VALIDATOR_PATH := "res://scripts/core/utils/qb/u_rule_validator.gd"


func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var s: Variant = load(path)
	assert_not_null(s, "Expected script to load: %s" % path)
	if s == null or not (s is Script):
		return null
	return s as Script


func _new_builder() -> Object:
	var script: Script = _load_script(BUILDER_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Object):
		return null
	return v as Object


func _new_resource(path: String) -> Resource:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null:
		return null
	return v as Resource


func _script_path(resource: Resource) -> String:
	if resource == null:
		return ""
	var s: Script = resource.get_script()
	if s == null:
		return ""
	return s.resource_path


func _validate_rules(rules: Array) -> Dictionary:
	var validator_script: Script = _load_script(U_RULE_VALIDATOR_PATH)
	if validator_script == null:
		return {}
	return validator_script.call("validate_rules", rules)


# ── Existence ────────────────────────────────────────────────────────────────

func test_u_qb_rule_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_QBRuleBuilder must instantiate")


# ── Condition Factories ─────────────────────────────────────────────────────

func test_condition_event_name_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("event_name", &"victory_triggered", "equals")
	assert_not_null(cond, "event_name factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_EVENT_NAME_PATH, "must be RS_ConditionEventName")
	assert_eq((cond as Resource).get("expected_event_name"), &"victory_triggered", "expected_event_name must match")
	assert_eq((cond as Resource).get("match_mode"), "equals", "match_mode must match")


func test_condition_event_payload_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("event_payload", "fall_speed", "normalize", 5.0, 30.0)
	assert_not_null(cond, "event_payload factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_EVENT_PAYLOAD_PATH, "must be RS_ConditionEventPayload")
	assert_eq((cond as Resource).get("field_path"), "fall_speed", "field_path must match")
	assert_eq((cond as Resource).get("match_mode"), "normalize", "match_mode must match")
	assert_eq((cond as Resource).get("range_min"), 5.0, "range_min must match")
	assert_eq((cond as Resource).get("range_max"), 30.0, "range_max must match")


func test_condition_component_field_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("component_field", &"C_HealthComponent", "_is_dead", 0.0, 1.0)
	assert_not_null(cond, "component_field factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_COMPONENT_FIELD_PATH, "must be RS_ConditionComponentField")
	assert_eq((cond as Resource).get("component_type"), &"C_HealthComponent", "component_type must match")
	assert_eq((cond as Resource).get("field_path"), "_is_dead", "field_path must match")


func test_condition_redux_field_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("redux_field", "time.is_paused", "equals", "true", 0.0, 1.0)
	assert_not_null(cond, "redux_field factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_REDUX_FIELD_PATH, "must be RS_ConditionReduxField")
	assert_eq((cond as Resource).get("state_path"), "time.is_paused", "state_path must match")
	assert_eq((cond as Resource).get("match_mode"), "equals", "match_mode must match")
	assert_eq((cond as Resource).get("match_value_string"), "true", "match_value_string must match")


func test_condition_entity_tag_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("entity_tag", &"predator")
	assert_not_null(cond, "entity_tag factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_ENTITY_TAG_PATH, "must be RS_ConditionEntityTag")
	assert_eq((cond as Resource).get("tag_name"), &"predator", "tag_name must match")


func test_condition_context_field_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("context_field", "score", "normalize", "", 0.0, 1.0)
	assert_not_null(cond, "context_field factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_CONTEXT_FIELD_PATH, "must be RS_ConditionContextField")
	assert_eq((cond as Resource).get("field_path"), "score", "field_path must match")


func test_condition_constant_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Variant = builder.call("constant", 0.85)
	assert_not_null(cond, "constant factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_CONSTANT_PATH, "must be RS_ConditionConstant")
	assert_eq((cond as Resource).get("score"), 0.85, "score must match")


func test_condition_composite_all_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child_a: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	var child_b: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(child_a, "child_a must instantiate")
	assert_not_null(child_b, "child_b must instantiate")
	var cond: Variant = builder.call("composite_all", [child_a, child_b])
	assert_not_null(cond, "composite_all factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_COMPOSITE_PATH, "must be RS_ConditionComposite")
	var mode: int = (cond as Resource).get("mode")
	assert_eq(mode, 0, "mode must be ALL (0)")
	var children: Array = (cond as Resource).get("children")
	assert_eq(children.size(), 2, "composite_all must contain 2 children")


func test_condition_composite_any_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child_a: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	var child_b: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(child_a, "child_a must instantiate")
	assert_not_null(child_b, "child_b must instantiate")
	var cond: Variant = builder.call("composite_any", [child_a, child_b])
	assert_not_null(cond, "composite_any factory must return a resource")
	assert_eq(_script_path(cond as Resource), CONDITION_COMPOSITE_PATH, "must be RS_ConditionComposite")
	var mode: int = (cond as Resource).get("mode")
	assert_eq(mode, 1, "mode must be ANY (1)")
	var children: Array = (cond as Resource).get("children")
	assert_eq(children.size(), 2, "composite_any must contain 2 children")


# ── Effect Factories ────────────────────────────────────────────────────────

func test_effect_publish_event_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("publish_event", &"checkpoint_activation_requested", {}, true)
	assert_not_null(effect, "publish_event factory must return a resource")
	assert_eq(_script_path(effect as Resource), EFFECT_PUBLISH_EVENT_PATH, "must be RS_EffectPublishEvent")
	assert_eq((effect as Resource).get("event_name"), &"checkpoint_activation_requested", "event_name must match")
	assert_eq((effect as Resource).get("inject_entity_id"), true, "inject_entity_id must match")


func test_effect_set_field_factory_with_float() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_field", &"C_CameraStateComponent", &"target_fov", 60.0, {})
	assert_not_null(effect, "set_field factory must return a resource")
	assert_eq(_script_path(effect as Resource), EFFECT_SET_FIELD_PATH, "must be RS_EffectSetField")
	assert_eq((effect as Resource).get("component_type"), &"C_CameraStateComponent", "component_type must match")
	assert_eq((effect as Resource).get("field_name"), &"target_fov", "field_name must match")
	assert_eq((effect as Resource).get("value_type"), "float", "value_type must be float")
	assert_eq((effect as Resource).get("float_value"), 60.0, "float_value must match")


func test_effect_set_field_factory_with_bool() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_field", &"C_CameraStateComponent", &"is_active", true, {})
	assert_not_null(effect, "set_field factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "bool", "value_type must be bool")
	assert_eq((effect as Resource).get("bool_value"), true, "bool_value must match")


func test_effect_set_field_factory_with_int() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_field", &"C_SpawnStateComponent", &"priority", 5, {})
	assert_not_null(effect, "set_field factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "int", "value_type must be int")
	assert_eq((effect as Resource).get("int_value"), 5, "int_value must match")


func test_effect_set_field_factory_with_string_name() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_field", &"C_StateComponent", &"state", &"idle", {})
	assert_not_null(effect, "set_field factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "string_name", "value_type must be string_name")
	assert_eq((effect as Resource).get("string_name_value"), &"idle", "string_name_value must match")


func test_effect_set_field_factory_with_vector3() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var v: Vector3 = Vector3(0, -0.3, 0)
	var effect: Variant = builder.call("set_field", &"C_CameraStateComponent", &"landing_impact_offset", v, {})
	assert_not_null(effect, "set_field factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "vector3", "value_type must be vector3")
	assert_eq((effect as Resource).get("vector3_value"), v, "vector3_value must match")


func test_effect_set_field_factory_with_config() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_field", &"C_CameraStateComponent", &"speed_fov_bonus", 5.0, {
		"operation": "add",
		"scale_by_rule_score": true,
		"use_clamp": true,
		"clamp_min": 0.0,
		"clamp_max": 15.0,
	})
	assert_not_null(effect, "set_field with config must return a resource")
	assert_eq((effect as Resource).get("operation"), "add", "operation must match")
	assert_eq((effect as Resource).get("scale_by_rule_score"), true, "scale_by_rule_score must match")
	assert_eq((effect as Resource).get("use_clamp"), true, "use_clamp must match")
	assert_eq((effect as Resource).get("clamp_max"), 15.0, "clamp_max must match")


func test_effect_set_context_value_factory_with_bool() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_context", &"is_gameplay_active", true, {})
	assert_not_null(effect, "set_context factory must return a resource")
	assert_eq(_script_path(effect as Resource), EFFECT_SET_CONTEXT_VALUE_PATH, "must be RS_EffectSetContextValue")
	assert_eq((effect as Resource).get("context_key"), &"is_gameplay_active", "context_key must match")
	assert_eq((effect as Resource).get("value_type"), "bool", "value_type must be bool")
	assert_eq((effect as Resource).get("bool_value"), true, "bool_value must match")


func test_effect_set_context_value_factory_with_float() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_context", &"score", 0.75, {})
	assert_not_null(effect, "set_context factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "float", "value_type must be float")
	assert_eq((effect as Resource).get("float_value"), 0.75, "float_value must match")


func test_effect_set_context_value_factory_with_string_name() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("set_context", &"state", &"idle", {})
	assert_not_null(effect, "set_context factory must return a resource")
	assert_eq((effect as Resource).get("value_type"), "string_name", "value_type must be string_name")
	assert_eq((effect as Resource).get("string_name_value"), &"idle", "string_name_value must match")


func test_effect_dispatch_action_factory() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var effect: Variant = builder.call("dispatch_action", &"set_checkpoint", {"checkpoint": &"zone_a"})
	assert_not_null(effect, "dispatch_action factory must return a resource")
	assert_eq(_script_path(effect as Resource), EFFECT_DISPATCH_ACTION_PATH, "must be RS_EffectDispatchAction")
	assert_eq((effect as Resource).get("action_type"), &"set_checkpoint", "action_type must match")
	var payload: Dictionary = (effect as Resource).get("payload")
	assert_eq(payload.get("checkpoint"), &"zone_a", "payload must match")


# ── Rule Factory ────────────────────────────────────────────────────────────

func test_rule_factory_creates_rs_rule() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(cond, "condition must instantiate")
	var rule: Variant = builder.call("rule", &"test_rule", [cond], [], {})
	assert_not_null(rule, "rule factory must return a resource")
	assert_eq(_script_path(rule as Resource), RS_RULE_PATH, "must be RS_Rule")
	assert_eq((rule as Resource).get("rule_id"), &"test_rule", "rule_id must match")


func test_rule_factory_applies_config() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(cond, "condition must instantiate")
	var effect: Resource = _new_resource(EFFECT_SET_CONTEXT_VALUE_PATH)
	assert_not_null(effect, "effect must instantiate")
	effect.set("context_key", &"test_key")
	effect.set("bool_value", true)

	var rule: Variant = builder.call("rule", &"config_test", [cond], [effect], {
		"trigger_mode": "event",
		"score_threshold": 0.5,
		"decision_group": &"test_group",
		"priority": 10,
		"cooldown": 1.5,
		"one_shot": true,
		"requires_rising_edge": true,
		"description": "Test description",
	})
	assert_not_null(rule, "rule factory must return a resource")
	assert_eq((rule as Resource).get("trigger_mode"), "event", "trigger_mode must match")
	assert_eq((rule as Resource).get("score_threshold"), 0.5, "score_threshold must match")
	assert_eq((rule as Resource).get("decision_group"), &"test_group", "decision_group must match")
	assert_eq((rule as Resource).get("priority"), 10, "priority must match")
	assert_eq((rule as Resource).get("cooldown"), 1.5, "cooldown must match")
	assert_eq((rule as Resource).get("one_shot"), true, "one_shot must match")
	assert_eq((rule as Resource).get("requires_rising_edge"), true, "requires_rising_edge must match")
	assert_eq((rule as Resource).get("description"), "Test description", "description must match")


func test_rule_factory_populates_conditions_in_headless() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(cond, "condition must instantiate")
	var rule: Variant = builder.call("rule", &"headless_test", [cond], [], {})
	assert_not_null(rule, "rule factory must return a resource")
	var conditions: Array = (rule as Resource).get("conditions")
	assert_eq(conditions.size(), 1, "conditions must contain 1 entry in headless mode")
	assert_eq(_script_path(conditions[0] as Resource), CONDITION_CONSTANT_PATH, "condition type must match")


func test_rule_factory_populates_effects_in_headless() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	var effect: Resource = _new_resource(EFFECT_SET_CONTEXT_VALUE_PATH)
	assert_not_null(cond, "condition must instantiate")
	assert_not_null(effect, "effect must instantiate")
	effect.set("context_key", &"test_key")
	effect.set("bool_value", true)
	var rule: Variant = builder.call("rule", &"headless_effects", [cond], [effect], {})
	assert_not_null(rule, "rule factory must return a resource")
	var effects: Array = (rule as Resource).get("effects")
	assert_eq(effects.size(), 1, "effects must contain 1 entry in headless mode")
	assert_eq(_script_path(effects[0] as Resource), EFFECT_SET_CONTEXT_VALUE_PATH, "effect type must match")


func test_rule_factory_produces_valid_rules() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var cond: Resource = _new_resource(CONDITION_CONSTANT_PATH)
	assert_not_null(cond, "condition must instantiate")
	var rule: Variant = builder.call("rule", &"valid_test", [cond], [], {})
	assert_not_null(rule, "rule factory must return a resource")
	var report: Dictionary = _validate_rules([rule])
	var valid_rules: Array = report.get("valid_rules", [])
	assert_eq(valid_rules.size(), 1, "built rule must pass validation")


# ── Round-trip: builder parity with existing .tres ─────────────────────────

func test_camera_shake_rule_parity() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var rule: Variant = builder.call("rule", &"camera_shake", [
		builder.call("event_name", &"entity_death"),
	], [
		builder.call("set_field", &"C_CameraStateComponent", &"shake_trauma", 0.5, {
			"operation": "add",
			"use_clamp": true,
		}),
	], {"trigger_mode": "event"})
	assert_not_null(rule, "rule must build")
	assert_eq((rule as Resource).get("rule_id"), &"camera_shake", "rule_id must match")
	assert_eq((rule as Resource).get("trigger_mode"), "event", "trigger_mode must match")
	var report: Dictionary = _validate_rules([rule])
	var valid_rules: Array = report.get("valid_rules", [])
	assert_eq(valid_rules.size(), 1, "camera_shake builder rule must pass validation")


func test_victory_forward_rule_parity() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var rule: Variant = builder.call("rule", &"victory_forward", [
		builder.call("event_name", &"victory_triggered"),
	], [
		builder.call("publish_event", &"victory_execution_requested"),
	], {"trigger_mode": "event"})
	assert_not_null(rule, "rule must build")
	assert_eq((rule as Resource).get("rule_id"), &"victory_forward", "rule_id must match")
	var report: Dictionary = _validate_rules([rule])
	var valid_rules: Array = report.get("valid_rules", [])
	assert_eq(valid_rules.size(), 1, "victory_forward builder rule must pass validation")


func test_pause_gate_paused_rule_parity() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var rule: Variant = builder.call("rule", &"pause_gate_paused", [
		builder.call("redux_field", "time.is_paused", "equals", "true"),
	], [
		builder.call("set_context", &"is_gameplay_active", false, {}),
	], {
		"decision_group": &"pause_gate",
	})
	assert_not_null(rule, "rule must build")
	assert_eq((rule as Resource).get("rule_id"), &"pause_gate_paused", "rule_id must match")
	assert_eq((rule as Resource).get("decision_group"), &"pause_gate", "decision_group must match")
	var report: Dictionary = _validate_rules([rule])
	var valid_rules: Array = report.get("valid_rules", [])
	assert_eq(valid_rules.size(), 1, "pause_gate_paused builder rule must pass validation")


func test_landing_impact_rule_parity() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var rule: Variant = builder.call("rule", &"camera_landing_impact", [
		builder.call("event_name", &"entity_landed"),
		builder.call("event_payload", "fall_speed", "normalize"),
	], [
		builder.call("set_field", &"C_CameraStateComponent", &"landing_impact_offset", Vector3(0, -0.3, 0), {
			"scale_by_rule_score": true,
		}),
	], {
		"trigger_mode": "event",
		"score_threshold": -1.0,
	})
	assert_not_null(rule, "rule must build")
	assert_eq((rule as Resource).get("rule_id"), &"camera_landing_impact", "rule_id must match")
	assert_eq((rule as Resource).get("trigger_mode"), "event", "trigger_mode must match")
	var conditions: Array = (rule as Resource).get("conditions")
	assert_eq(conditions.size(), 2, "landing_impact must have 2 conditions")
	var report: Dictionary = _validate_rules([rule])
	var valid_rules: Array = report.get("valid_rules", [])
	assert_eq(valid_rules.size(), 1, "landing_impact builder rule must pass validation")
