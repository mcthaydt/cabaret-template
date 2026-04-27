extends RefCounted
class_name U_QBRuleBuilder

const RS_RULE := preload("res://scripts/core/resources/qb/rs_rule.gd")

const RS_CONDITION_EVENT_NAME := preload("res://scripts/core/resources/qb/conditions/rs_condition_event_name.gd")
const RS_CONDITION_EVENT_PAYLOAD := preload("res://scripts/core/resources/qb/conditions/rs_condition_event_payload.gd")
const RS_CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")
const RS_CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const RS_CONDITION_ENTITY_TAG := preload("res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd")
const RS_CONDITION_CONTEXT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_context_field.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")
const RS_CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")

const RS_EFFECT_PUBLISH_EVENT := preload("res://scripts/core/resources/qb/effects/rs_effect_publish_event.gd")
const RS_EFFECT_SET_FIELD := preload("res://scripts/core/resources/qb/effects/rs_effect_set_field.gd")
const RS_EFFECT_SET_CONTEXT_VALUE := preload("res://scripts/core/resources/qb/effects/rs_effect_set_context_value.gd")
const RS_EFFECT_DISPATCH_ACTION := preload("res://scripts/core/resources/qb/effects/rs_effect_dispatch_action.gd")


static func rule(rule_id: StringName, conditions: Array, effects: Array = [], config: Dictionary = {}) -> RS_Rule:
	var r: RS_Rule = RS_RULE.new()
	r.rule_id = rule_id
	r.description = config.get("description", "")
	r.trigger_mode = config.get("trigger_mode", "tick")
	r.score_threshold = config.get("score_threshold", 0.0)
	r.decision_group = config.get("decision_group", StringName())
	r.priority = config.get("priority", 0)
	r.cooldown = config.get("cooldown", 0.0)
	r.one_shot = config.get("one_shot", false)
	r.requires_rising_edge = config.get("requires_rising_edge", false)
	var coerced_conditions: Variant = r.call("_coerce_conditions", conditions)
	r.set("_conditions", coerced_conditions)
	var coerced_effects: Variant = r.call("_coerce_effects", effects)
	r.set("_effects", coerced_effects)
	return r


static func event_name(expected: StringName, match_mode: String = "equals") -> RS_ConditionEventName:
	var c: RS_ConditionEventName = RS_CONDITION_EVENT_NAME.new()
	c.expected_event_name = expected
	c.match_mode = match_mode
	return c


static func event_payload(field_path: String = "", match_mode: String = "exists", range_min: float = 0.0, range_max: float = 1.0) -> RS_ConditionEventPayload:
	var c: RS_ConditionEventPayload = RS_CONDITION_EVENT_PAYLOAD.new()
	c.field_path = field_path
	c.match_mode = match_mode
	c.match_value_string = "" if match_mode == "exists" else c.match_value_string
	c.range_min = range_min
	c.range_max = range_max
	return c


static func component_field(component_type: StringName, field_path: String = "", range_min: float = 0.0, range_max: float = 1.0) -> RS_ConditionComponentField:
	var c: RS_ConditionComponentField = RS_CONDITION_COMPONENT_FIELD.new()
	c.component_type = component_type
	c.field_path = field_path
	c.range_min = range_min
	c.range_max = range_max
	return c


static func redux_field(state_path: String, match_mode: String = "normalize", match_value: String = "", range_min: float = 0.0, range_max: float = 1.0) -> RS_ConditionReduxField:
	var c: RS_ConditionReduxField = RS_CONDITION_REDUX_FIELD.new()
	c.state_path = state_path
	c.match_mode = match_mode
	c.match_value_string = match_value
	c.range_min = range_min
	c.range_max = range_max
	return c


static func entity_tag(tag_name: StringName) -> RS_ConditionEntityTag:
	var c: RS_ConditionEntityTag = RS_CONDITION_ENTITY_TAG.new()
	c.tag_name = tag_name
	return c


static func context_field(field_path: String, match_mode: String = "normalize", match_value: String = "", range_min: float = 0.0, range_max: float = 1.0) -> RS_ConditionContextField:
	var c: RS_ConditionContextField = RS_CONDITION_CONTEXT_FIELD.new()
	c.field_path = field_path
	c.match_mode = match_mode
	c.match_value_string = match_value
	c.range_min = range_min
	c.range_max = range_max
	return c


static func constant(score: float = 1.0) -> RS_ConditionConstant:
	var c: RS_ConditionConstant = RS_CONDITION_CONSTANT.new()
	c.score = score
	return c


static func composite_all(children: Array) -> RS_ConditionComposite:
	var c: RS_ConditionComposite = RS_CONDITION_COMPOSITE.new()
	c.set("mode", 0)
	var coerced: Variant = c.call("_coerce_children", children)
	c.set("_children", coerced)
	return c


static func composite_any(children: Array) -> RS_ConditionComposite:
	var c: RS_ConditionComposite = RS_CONDITION_COMPOSITE.new()
	c.set("mode", 1)
	var coerced: Variant = c.call("_coerce_children", children)
	c.set("_children", coerced)
	return c


static func publish_event(event_name: StringName, payload: Dictionary = {}, inject_entity_id: bool = true) -> RS_EffectPublishEvent:
	var e: RS_EffectPublishEvent = RS_EFFECT_PUBLISH_EVENT.new()
	e.event_name = event_name
	e.payload = payload
	e.inject_entity_id = inject_entity_id
	return e


static func set_field(component_type: StringName, field_name: StringName, value: Variant = null, config: Dictionary = {}) -> RS_EffectSetField:
	var e: RS_EffectSetField = RS_EFFECT_SET_FIELD.new()
	e.component_type = component_type
	e.field_name = field_name
	if value != null:
		_set_effect_value(e, value)
	e.operation = config.get("operation", "set")
	if config.has("use_context_value"):
		e.use_context_value = config.get("use_context_value")
	if config.has("context_value_path"):
		e.context_value_path = config.get("context_value_path")
	if config.has("scale_by_rule_score"):
		e.scale_by_rule_score = config.get("scale_by_rule_score")
	if config.has("rule_score_context_path"):
		e.rule_score_context_path = config.get("rule_score_context_path")
	if config.has("use_clamp"):
		e.use_clamp = config.get("use_clamp")
	if config.has("clamp_min"):
		e.clamp_min = config.get("clamp_min")
	if config.has("clamp_max"):
		e.clamp_max = config.get("clamp_max")
	return e


static func set_context(context_key: StringName, value: Variant = null, config: Dictionary = {}) -> RS_EffectSetContextValue:
	var e: RS_EffectSetContextValue = RS_EFFECT_SET_CONTEXT_VALUE.new()
	e.context_key = context_key
	if value != null:
		_set_context_effect_value(e, value)
	return e


static func dispatch_action(action_type: StringName, payload: Dictionary = {}) -> RS_EffectDispatchAction:
	var e: RS_EffectDispatchAction = RS_EFFECT_DISPATCH_ACTION.new()
	e.action_type = action_type
	e.payload = payload
	return e


static func _set_effect_value(effect: Resource, value: Variant) -> void:
	if value is bool:
		effect.value_type = "bool"
		effect.bool_value = value
	elif value is int:
		effect.value_type = "int"
		effect.int_value = value
	elif value is float:
		effect.value_type = "float"
		effect.float_value = value
	elif value is StringName:
		effect.value_type = "string_name"
		effect.string_name_value = value
	elif value is String:
		effect.value_type = "string"
		effect.string_value = value
	elif value is Vector2:
		effect.value_type = "vector2"
		effect.vector2_value = value
	elif value is Vector3:
		effect.value_type = "vector3"
		effect.vector3_value = value


static func _set_context_effect_value(effect: Resource, value: Variant) -> void:
	if value is bool:
		effect.value_type = "bool"
		effect.bool_value = value
	elif value is int:
		effect.value_type = "int"
		effect.int_value = value
	elif value is float:
		effect.value_type = "float"
		effect.float_value = value
	elif value is StringName:
		effect.value_type = "string_name"
		effect.string_name_value = value
	elif value is String:
		effect.value_type = "string"
		effect.string_value = value
