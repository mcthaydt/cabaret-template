extends RefCounted

const RS_CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")
const RS_AI_ACTION_FLEE := preload("res://scripts/core/resources/ai/actions/rs_ai_action_flee_from_detected.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd")
const RS_AI_ACTION_WANDER := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wander.gd")
const RS_AI_ACTION_FEED := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_feed.gd")

func build() -> RS_BTNode:
	var cond_threat := RS_CONDITION_COMPONENT_FIELD.new()
	cond_threat.component_type = &"C_DetectionComponent"
	cond_threat.field_path = "is_player_in_range"

	var cond_hunger_low := RS_CONDITION_COMPONENT_FIELD.new()
	cond_hunger_low.component_type = &"C_NeedsComponent"
	cond_hunger_low.field_path = "hunger"
	cond_hunger_low.range_min = 0.3
	cond_hunger_low.range_max = 0.0

	var scorer_flee := U_BTBuilder.score_condition(cond_threat, 10.0)
	var scorer_graze := U_BTBuilder.score_condition(cond_hunger_low, 6.0)
	var scorer_wander := U_BTBuilder.score_const(1.0)

	var flee_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_threat),
		_flee(10.0, 0.6, 14.0),
	])

	var graze_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_hunger_low),
		_wait(1.8),
		_feed(),
	])

	var wander := _wander(10.0)

	var root := U_BTBuilder.utility_selector([flee_seq, graze_seq, wander])
	root.child_scorers = [scorer_flee, scorer_graze, scorer_wander]
	return root

func _flee(distance: float, radius: float, home_radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_FLEE.new()
	a.flee_distance = distance
	a.arrival_threshold = radius
	a.clamp_to_home_radius = true
	a.home_radius = home_radius
	return U_BTBuilder.action(a)

func _wait(duration: float = 1.0) -> RS_BTAction:
	var a := RS_AI_ACTION_WAIT.new()
	a.duration = duration
	return U_BTBuilder.action(a)

func _feed() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_FEED.new())

func _wander(home_radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_WANDER.new()
	a.home_radius = home_radius
	return U_BTBuilder.action(a)
