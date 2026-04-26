extends RefCounted

const RS_CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const RS_AI_ACTION_MOVE_TO := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to.gd")
const RS_AI_ACTION_SCAN := preload("res://scripts/core/resources/ai/actions/rs_ai_action_scan.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd")

func build() -> RS_BTNode:
	var cond_proximity := RS_CONDITION_REDUX_FIELD.new()
	cond_proximity.state_path = "gameplay.ai_demo_flags.power_core_proximity"
	cond_proximity.match_mode = "equals"
	cond_proximity.match_value_string = "true"

	var cond_activated := RS_CONDITION_REDUX_FIELD.new()
	cond_activated.state_path = "gameplay.ai_demo_flags.power_core_activated"
	cond_activated.match_mode = "equals"
	cond_activated.match_value_string = "true"

	var scorer_proximity := U_BTBuilder.score_condition(cond_proximity, 11.0)
	var scorer_investigate := U_BTBuilder.score_condition(cond_activated, 9.0)
	var scorer_patrol := U_BTBuilder.score_const(1.0)

	var patrol_seq := _build_patrol_sequence()

	var proximity_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_proximity),
		_move_to("../../Interactions/Inter_ActivatableNode", 1.2),
		_scan(1.25),
		_wait(),
	])
	var proximity_branch := U_BTBuilder.selector([
		U_BTBuilder.cooldown(U_BTBuilder.rising_edge(proximity_seq, cond_proximity), 2.5),
		patrol_seq,
	])

	var investigate_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_activated),
		_move_to("../../Interactions/Inter_ActivatableNode", 1.2),
		_scan(1.25),
		_wait(),
	])
	var investigate_branch := U_BTBuilder.selector([
		U_BTBuilder.cooldown(U_BTBuilder.rising_edge(investigate_seq, cond_activated), 2.5),
		patrol_seq,
	])

	var root := U_BTBuilder.utility_selector([proximity_branch, investigate_branch, patrol_seq])
	root.child_scorers = [scorer_proximity, scorer_investigate, scorer_patrol]
	return root

func _build_patrol_sequence() -> RS_BTSequence:
	return U_BTBuilder.sequence([
		_move_to("../../Waypoints/WaypointA", 0.8), _wait(),
		_move_to("../../Waypoints/WaypointB", 0.8), _wait(),
		_move_to("../../Waypoints/WaypointC", 0.8), _wait(),
		_move_to("../../Waypoints/WaypointD", 0.8), _wait(),
	])

func _move_to(path: String, radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO.new()
	a.target_node_path = NodePath(path)
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

func _scan(speed: float = 1.0) -> RS_BTAction:
	var a := RS_AI_ACTION_SCAN.new()
	a.rotation_speed = speed
	return U_BTBuilder.action(a)

func _wait() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_WAIT.new())
