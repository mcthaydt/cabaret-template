extends RefCounted

const RS_CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const RS_AI_ACTION_MOVE_TO := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to.gd")
const RS_AI_ACTION_SCAN := preload("res://scripts/core/resources/ai/actions/rs_ai_action_scan.gd")
const RS_AI_ACTION_PUBLISH_EVENT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_publish_event.gd")

func build() -> RS_BTNode:
	var cond_proximity := RS_CONDITION_REDUX_FIELD.new()
	cond_proximity.state_path = "gameplay.ai_demo_flags.comms_disturbance_proximity"
	cond_proximity.match_mode = RS_ConditionReduxField.MATCH_EQUALS
	cond_proximity.match_value_string = "true"

	var cond_heard := RS_CONDITION_REDUX_FIELD.new()
	cond_heard.state_path = "gameplay.ai_demo_flags.comms_disturbance_heard"
	cond_heard.match_mode = RS_ConditionReduxField.MATCH_EQUALS
	cond_heard.match_value_string = "true"

	var scorer_proximity := U_BTBuilder.score_condition(cond_proximity, 11.0)
	var scorer_heard := U_BTBuilder.score_condition(cond_heard, 9.0)
	var scorer_guard := U_BTBuilder.score_const(1.0)

	var guard_seq := _build_guard_sequence()

	var proximity_investigate_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_proximity),
		_publish_alarm(),
		_move_to("../../NoiseSources/Inter_NoiseSourceA", 1.1),
		_scan(4.0, 1.4),
		_move_to("../../Waypoints/WaypointGuardB", 0.9),
	])
	var proximity_branch := U_BTBuilder.selector([
		U_BTBuilder.cooldown(U_BTBuilder.rising_edge(proximity_investigate_seq, cond_proximity), 3.0),
		guard_seq,
	])

	var heard_investigate_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_heard),
		_publish_alarm(),
		_move_to("../../NoiseSources/Inter_NoiseSourceA", 1.1),
		_scan(4.0, 1.4),
		_move_to("../../Waypoints/WaypointGuardB", 0.9),
	])
	var heard_branch := U_BTBuilder.selector([
		U_BTBuilder.cooldown(U_BTBuilder.rising_edge(heard_investigate_seq, cond_heard), 3.0),
		guard_seq,
	])

	var root := U_BTBuilder.utility_selector([proximity_branch, heard_branch, guard_seq])
	root.child_scorers = [scorer_proximity, scorer_heard, scorer_guard]
	return root

func _build_guard_sequence() -> RS_BTSequence:
	return U_BTBuilder.sequence([
		_scan(3.0),
		_move_to("../../Waypoints/WaypointGuardA", 0.9),
		_scan(2.8, 1.1),
		_move_to("../../Waypoints/WaypointGuardB", 0.9),
		_scan(2.6),
		_move_to("../../Waypoints/WaypointGuardC", 0.9),
	])

func _move_to(path: String, radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO.new()
	a.target_node_path = NodePath(path)
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

func _scan(duration: float = 2.0, speed: float = 1.0) -> RS_BTAction:
	var a := RS_AI_ACTION_SCAN.new()
	a.scan_duration = duration
	a.rotation_speed = speed
	return U_BTBuilder.action(a)

func _publish_alarm() -> RS_BTAction:
	var a := RS_AI_ACTION_PUBLISH_EVENT.new()
	a.event_name = &"ai_alarm_triggered"
	a.payload = {"source": &"sentry"}
	return U_BTBuilder.action(a)
