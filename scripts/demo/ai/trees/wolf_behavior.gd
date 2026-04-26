extends RefCounted

const RS_CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")
const RS_CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")
const RS_AI_ACTION_MOVE_TO_DETECTED := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to_detected.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd")
const RS_AI_ACTION_WANDER := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wander.gd")
const RS_AI_ACTION_FEED := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_feed.gd")

func build() -> RS_BTNode:
	var cond_prey_detected := RS_CONDITION_COMPONENT_FIELD.new()
	cond_prey_detected.component_type = &"C_DetectionComponent"
	cond_prey_detected.field_path = "is_player_in_range"

	var cond_hunger_low := RS_CONDITION_COMPONENT_FIELD.new()
	cond_hunger_low.component_type = &"C_NeedsComponent"
	cond_hunger_low.field_path = "hunger"
	cond_hunger_low.range_min = 1.0
	cond_hunger_low.range_max = 0.0

	var cond_hunt_gate := RS_CONDITION_COMPOSITE.new()
	cond_hunt_gate.set("mode", 0)
	var hunt_coerced: Variant = cond_hunt_gate.call("_coerce_children", [cond_prey_detected, cond_hunger_low])
	cond_hunt_gate.set("_children", hunt_coerced)

	var scorer_hunt := U_BTBuilder.score_condition(cond_hunt_gate, 10.0)
	var scorer_search := U_BTBuilder.score_condition(cond_hunger_low, 6.0)
	var scorer_wander := U_BTBuilder.score_const(1.0)

	var hunt_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_prey_detected),
		U_BTBuilder.condition(cond_hunger_low),
		_move_to_detected(0.6, 1.25),
		_wait(0.4),
		_move_to_detected(0.6, 1.25),
		_feed(true),
	])

	var search_food := U_BTBuilder.cooldown(_wander(24.0), 6.0)
	var wander := _wander(10.0)

	var root := U_BTBuilder.utility_selector([hunt_seq, search_food, wander])
	root.child_scorers = [scorer_hunt, scorer_search, scorer_wander]
	return root

func _move_to_detected(radius: float, completion_override: float) -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO_DETECTED.new()
	a.arrival_threshold = radius
	a.completion_radius_override = completion_override
	return U_BTBuilder.action(a)

func _wait(duration: float = 1.0) -> RS_BTAction:
	var a := RS_AI_ACTION_WAIT.new()
	a.duration = duration
	return U_BTBuilder.action(a)

func _feed(consume_detected: bool = false) -> RS_BTAction:
	var a := RS_AI_ACTION_FEED.new()
	a.consume_detected_target = consume_detected
	return U_BTBuilder.action(a)

func _wander(home_radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_WANDER.new()
	a.home_radius = home_radius
	return U_BTBuilder.action(a)
