extends RefCounted
class_name U_AIBTFactory

const RS_BT_PLANNER := preload("res://scripts/core/resources/ai/bt/rs_bt_planner.gd")

const RS_AI_ACTION_MOVE_TO := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to.gd")
const RS_AI_ACTION_MOVE_TO_DETECTED := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to_detected.gd")
const RS_AI_ACTION_MOVE_TO_NEAREST := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to_nearest.gd")
const RS_AI_ACTION_FLEE := preload("res://scripts/core/resources/ai/actions/rs_ai_action_flee_from_detected.gd")
const RS_AI_ACTION_WANDER := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wander.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd")
const RS_AI_ACTION_SCAN := preload("res://scripts/core/resources/ai/actions/rs_ai_action_scan.gd")
const RS_AI_ACTION_ANIMATE := preload("res://scripts/core/resources/ai/actions/rs_ai_action_animate.gd")
const RS_AI_ACTION_PUBLISH_EVENT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_publish_event.gd")
const RS_AI_ACTION_SET_FIELD := preload("res://scripts/core/resources/ai/actions/rs_ai_action_set_field.gd")

const RS_CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")
const RS_CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")
const RS_CONDITION_CONTEXT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_context_field.gd")
const RS_CONDITION_ENTITY_TAG := preload("res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd")
const RS_CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const RS_CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")

static func move_to(target: Vector3, radius: float = 0.5) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_MOVE_TO.new()
	a.target_position = target
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

static func move_to_detected(radius: float = 0.5) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_MOVE_TO_DETECTED.new()
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

static func move_to_nearest(scan_type: StringName, radius: float = 1.5) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_MOVE_TO_NEAREST.new()
	a.scan_component_type = scan_type
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

static func flee(distance: float = 6.0, radius: float = 0.5) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_FLEE.new()
	a.flee_distance = distance
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

static func wander(home_radius: float = 6.0) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_WANDER.new()
	a.home_radius = home_radius
	return U_BTBuilder.action(a)

static func wait(duration: float = 1.0) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_WAIT.new()
	a.duration = duration
	return U_BTBuilder.action(a)

static func scan(duration: float = 2.0, speed: float = 1.0) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_SCAN.new()
	a.scan_duration = duration
	a.rotation_speed = speed
	return U_BTBuilder.action(a)

static func animate(state_name: StringName) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_ANIMATE.new()
	a.animation_state = state_name
	return U_BTBuilder.action(a)

static func publish_event(name: StringName, payload: Dictionary = {}) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_PUBLISH_EVENT.new()
	a.event_name = name
	a.payload = payload
	return U_BTBuilder.action(a)

static func set_field(path: String, value: Variant) -> RS_BTAction:
	var a: Resource = RS_AI_ACTION_SET_FIELD.new()
	a.field_path = path
	if value is bool:
		a.value_type = "bool"
		a.bool_value = value
	elif value is int:
		a.value_type = "int"
		a.int_value = value
	elif value is float:
		a.value_type = "float"
		a.float_value = value
	elif value is StringName:
		a.value_type = "string_name"
		a.string_name_value = value
	elif value is String:
		a.value_type = "string"
		a.string_value = value
	return U_BTBuilder.action(a)

static func always() -> RS_BTCondition:
	var c: Resource = RS_CONDITION_CONSTANT.new()
	c.score = 1.0
	return U_BTBuilder.condition(c)

static func never() -> RS_BTCondition:
	var c: Resource = RS_CONDITION_CONSTANT.new()
	c.score = 0.0
	return U_BTBuilder.condition(c)

static func component_field(type: StringName, field: String) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_COMPONENT_FIELD.new()
	c.component_type = type
	c.field_path = field
	return U_BTBuilder.condition(c)

static func context_field(path: String) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_CONTEXT_FIELD.new()
	c.field_path = path
	return U_BTBuilder.condition(c)

static func entity_tag(tag: StringName) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_ENTITY_TAG.new()
	c.tag_name = tag
	return U_BTBuilder.condition(c)

static func redux_field(path: String) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_REDUX_FIELD.new()
	c.state_path = path
	return U_BTBuilder.condition(c)

static func composite_all(conditions: Array) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_COMPOSITE.new()
	c.set("mode", 0)
	var sanitized: Variant = c.call("_sanitize_children", conditions)
	c.set("_children", sanitized)
	return U_BTBuilder.condition(c)

static func composite_any(conditions: Array) -> RS_BTCondition:
	var c: Resource = RS_CONDITION_COMPOSITE.new()
	c.set("mode", 1)
	var sanitized: Variant = c.call("_sanitize_children", conditions)
	c.set("_children", sanitized)
	return U_BTBuilder.condition(c)

static func planner(goal: Resource, action_pool: Array = [], max_depth: int = 6) -> RS_BTPlanner:
	var node: RS_BTPlanner = RS_BT_PLANNER.new()
	node.set("goal", goal)
	node.set("action_pool", action_pool)
	node.max_depth = max_depth
	return node
