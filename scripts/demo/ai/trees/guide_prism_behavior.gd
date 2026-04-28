extends RefCounted

const RS_CONDITION_REDUX_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd")
const RS_AI_ACTION_MOVE_TO := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to.gd")
const RS_AI_ACTION_WAIT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd")
const RS_AI_ACTION_ANIMATE := preload("res://scripts/core/resources/ai/actions/rs_ai_action_animate.gd")
const RS_AI_ACTION_PUBLISH_EVENT := preload("res://scripts/core/resources/ai/actions/rs_ai_action_publish_event.gd")

func build() -> RS_BTNode:
	var cond_nav_goal := RS_CONDITION_REDUX_FIELD.new()
	cond_nav_goal.state_path = "gameplay.ai_demo_flags.nav_goal_reached"
	cond_nav_goal.match_mode = RS_ConditionReduxField.MATCH_EQUALS
	cond_nav_goal.match_value_string = "true"

	var cond_airborne := RS_CONDITION_REDUX_FIELD.new()
	cond_airborne.state_path = "gameplay.entities.player.is_on_floor"
	cond_airborne.match_mode = RS_ConditionReduxField.MATCH_NOT_EQUALS
	cond_airborne.match_value_string = "true"

	var scorer_celebrate := U_BTBuilder.score_condition(cond_nav_goal, 12.0)
	var scorer_encourage := U_BTBuilder.score_condition(cond_airborne, 8.0)
	var scorer_show_path := U_BTBuilder.score_const(1.0)

	var show_path_seq := _build_show_path_sequence()

	var celebrate_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_nav_goal),
		_animate(&"spin"),
		_publish_event(&"signpost_message", {
			"message": "gameplay.signpost.default_message",
			"message_duration_sec": 2.5,
			"source": &"guide_prism",
		}),
		_wait(3.0),
	])
	var celebrate_branch := U_BTBuilder.selector([
		U_BTBuilder.once(celebrate_seq),
		show_path_seq,
	])

	var encourage_seq := U_BTBuilder.sequence([
		U_BTBuilder.condition(cond_airborne),
		_move_to("../../SpawnPoints/sp_default", 1.0),
		_animate(&"pulse"),
		_wait(1.5),
	])
	var encourage_branch := U_BTBuilder.selector([
		U_BTBuilder.cooldown(U_BTBuilder.rising_edge(encourage_seq, cond_airborne), 2.0),
		show_path_seq,
	])

	var root := U_BTBuilder.utility_selector([celebrate_branch, encourage_branch, show_path_seq])
	root.child_scorers = [scorer_celebrate, scorer_encourage, scorer_show_path]
	return root

func _build_show_path_sequence() -> RS_BTSequence:
	return U_BTBuilder.sequence([
		_move_to("../../PathMarkers/PathMarkerA", 0.9), _wait(),
		_move_to("../../PathMarkers/PathMarkerB", 0.9), _wait(),
		_move_to("../../PathMarkers/PathMarkerC", 0.9), _wait(),
		_move_to("../../PathMarkers/PathMarkerD", 0.9), _wait(),
	])

func _move_to(path: String, radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO.new()
	a.target_node_path = NodePath(path)
	a.arrival_threshold = radius
	return U_BTBuilder.action(a)

func _wait(duration: float = 0.0) -> RS_BTAction:
	var a := RS_AI_ACTION_WAIT.new()
	if duration > 0.0:
		a.duration = duration
	return U_BTBuilder.action(a)

func _animate(state: StringName) -> RS_BTAction:
	var a := RS_AI_ACTION_ANIMATE.new()
	a.animation_state = state
	return U_BTBuilder.action(a)

func _publish_event(name: StringName, payload: Dictionary) -> RS_BTAction:
	var a := RS_AI_ACTION_PUBLISH_EVENT.new()
	a.event_name = name
	a.payload = payload
	return U_BTBuilder.action(a)
