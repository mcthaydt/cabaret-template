extends RefCounted
class_name U_BTBuilder

const RS_BT_SEQUENCE := preload("res://scripts/core/resources/bt/rs_bt_sequence.gd")
const RS_BT_SELECTOR := preload("res://scripts/core/resources/bt/rs_bt_selector.gd")
const RS_BT_UTILITY_SELECTOR := preload("res://scripts/core/resources/bt/rs_bt_utility_selector.gd")
const RS_BT_SCORED_NODE := preload("res://scripts/core/resources/bt/rs_bt_scored_node.gd")
const RS_BT_COOLDOWN := preload("res://scripts/core/resources/bt/rs_bt_cooldown.gd")
const RS_BT_ONCE := preload("res://scripts/core/resources/bt/rs_bt_once.gd")
const RS_BT_RISING_EDGE := preload("res://scripts/core/resources/bt/rs_bt_rising_edge.gd")
const RS_BT_INVERTER := preload("res://scripts/core/resources/bt/rs_bt_inverter.gd")
const RS_BT_ACTION := preload("res://scripts/core/resources/ai/bt/rs_bt_action.gd")
const RS_BT_CONDITION := preload("res://scripts/core/resources/ai/bt/rs_bt_condition.gd")
const RS_AI_SCORER_CONSTANT := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_constant.gd")
const RS_AI_SCORER_CONDITION := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_condition.gd")
const RS_AI_SCORER_CONTEXT_FIELD := preload("res://scripts/core/resources/ai/bt/scorers/rs_ai_scorer_context_field.gd")

static func sequence(children: Array) -> RS_BTSequence:
	var node: RS_BTSequence = RS_BT_SEQUENCE.new()
	var coerced: Variant = node.call("_coerce_children", children)
	node.set("_children", coerced)
	return node

static func selector(children: Array) -> RS_BTSelector:
	var node: RS_BTSelector = RS_BT_SELECTOR.new()
	var coerced: Variant = node.call("_coerce_children", children)
	node.set("_children", coerced)
	return node

static func utility_selector(children: Array) -> RS_BTUtilitySelector:
	var node: RS_BTUtilitySelector = RS_BT_UTILITY_SELECTOR.new()
	var coerced: Variant = node.call("_coerce_children", children)
	node.set("_children", coerced)
	return node

static func scored(child: RS_BTNode, scorer: Resource) -> RS_BTDecorator:
	var node: RS_BTDecorator = RS_BT_SCORED_NODE.new()
	node.child = child
	node.set("scorer", scorer)
	return node

static func cooldown(child: RS_BTNode, duration: float) -> RS_BTCooldown:
	var node: RS_BTCooldown = RS_BT_COOLDOWN.new()
	node.child = child
	node.duration = duration
	return node

static func once(child: RS_BTNode) -> RS_BTOnce:
	var node: RS_BTOnce = RS_BT_ONCE.new()
	node.child = child
	return node

static func rising_edge(child: RS_BTNode, gate: Resource) -> RS_BTRisingEdge:
	var node: RS_BTRisingEdge = RS_BT_RISING_EDGE.new()
	node.child = child
	node.gate_condition = gate
	return node

static func inverter(child: RS_BTNode) -> RS_BTInverter:
	var node: RS_BTInverter = RS_BT_INVERTER.new()
	node.child = child
	return node

static func action(action_resource: Resource) -> RS_BTAction:
	var node: RS_BTAction = RS_BT_ACTION.new()
	node.set("action", action_resource)
	return node

static func condition(condition_resource: Resource) -> RS_BTCondition:
	var node: RS_BTCondition = RS_BT_CONDITION.new()
	node.set("condition", condition_resource)
	return node

static func score_const(value: float) -> RS_AIScorerConstant:
	var scorer: RS_AIScorerConstant = RS_AI_SCORER_CONSTANT.new()
	scorer.value = value
	return scorer

static func score_condition(condition: Resource, if_true: float = 1.0, if_false: float = 0.0) -> RS_AIScorerCondition:
	var scorer: RS_AIScorerCondition = RS_AI_SCORER_CONDITION.new()
	scorer.set("condition", condition)
	scorer.if_true = if_true
	scorer.if_false = if_false
	return scorer

static func score_context_field(path: String, multiplier: float = 1.0) -> RS_AIScorerContextField:
	var scorer: RS_AIScorerContextField = RS_AI_SCORER_CONTEXT_FIELD.new()
	scorer.path = path
	scorer.multiplier = multiplier
	return scorer
