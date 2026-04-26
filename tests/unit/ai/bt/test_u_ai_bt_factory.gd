extends GutTest

const U_AI_BT_FACTORY_PATH := "res://scripts/core/utils/ai/u_ai_bt_factory.gd"
const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const U_BT_RUNNER_PATH := "res://scripts/core/utils/bt/u_bt_runner.gd"

const RS_AI_ACTION_MOVE_TO_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_move_to.gd"
const RS_AI_ACTION_MOVE_TO_DETECTED_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_move_to_detected.gd"
const RS_AI_ACTION_MOVE_TO_NEAREST_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_move_to_nearest.gd"
const RS_AI_ACTION_FLEE_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_flee_from_detected.gd"
const RS_AI_ACTION_WANDER_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_wander.gd"
const RS_AI_ACTION_WAIT_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_wait.gd"
const RS_AI_ACTION_SCAN_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_scan.gd"
const RS_AI_ACTION_ANIMATE_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_animate.gd"
const RS_AI_ACTION_PUBLISH_EVENT_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_publish_event.gd"
const RS_AI_ACTION_SET_FIELD_PATH := "res://scripts/core/resources/ai/actions/rs_ai_action_set_field.gd"
const RS_BT_PLANNER_PATH := "res://scripts/core/resources/ai/bt/rs_bt_planner.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_constant.gd"
const RS_CONDITION_COMPONENT_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd"
const RS_CONDITION_CONTEXT_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_context_field.gd"
const RS_CONDITION_ENTITY_TAG_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd"
const RS_CONDITION_REDUX_FIELD_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_redux_field.gd"
const RS_CONDITION_COMPOSITE_PATH := "res://scripts/core/resources/qb/conditions/rs_condition_composite.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var s: Variant = load(path)
	assert_not_null(s, "Expected script to load: %s" % path)
	if s == null or not (s is Script):
		return null
	return s as Script

func _new_factory() -> Object:
	var script: Script = _load_script(U_AI_BT_FACTORY_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Object):
		return null
	return v as Object

func _new_runner() -> Object:
	var script: Script = _load_script(U_BT_RUNNER_PATH)
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

func _status(name: String) -> int:
	var script: Script = _load_script(RS_BT_NODE_PATH)
	if script == null:
		return -1
	var enum_variant: Variant = script.get("Status")
	if not (enum_variant is Dictionary):
		return -1
	return int((enum_variant as Dictionary).get(name, -1))

func _inner_action(node: Variant) -> Resource:
	if node == null or not (node is Resource):
		return null
	var a: Variant = (node as Resource).get("action")
	if a == null or not (a is Resource):
		return null
	return a as Resource

func _inner_condition(node: Variant) -> Resource:
	if node == null or not (node is Resource):
		return null
	var c: Variant = (node as Resource).get("condition")
	if c == null or not (c is Resource):
		return null
	return c as Resource

func _script_path(r: Resource) -> String:
	if r == null:
		return ""
	var s: Script = r.get_script() as Script
	if s == null:
		return ""
	return s.get_path()

func test_u_ai_bt_factory_script_exists_and_loads() -> void:
	var script: Script = _load_script(U_AI_BT_FACTORY_PATH)
	assert_not_null(script, "U_AIBTFactory script must exist and load")

func test_move_to_creates_bt_action_with_move_to_action() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("move_to", Vector3(1.0, 0.0, 2.0), 0.75)
	assert_not_null(node, "move_to() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "move_to() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_MOVE_TO_PATH, "move_to() must wrap RS_AIActionMoveTo")
	assert_eq(inner.get("target_position"), Vector3(1.0, 0.0, 2.0), "move_to must set target_position")
	assert_eq(inner.get("arrival_threshold"), 0.75, "move_to must set arrival_threshold")

func test_move_to_detected_creates_bt_action_with_radius() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("move_to_detected", 1.2)
	assert_not_null(node, "move_to_detected() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "move_to_detected() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_MOVE_TO_DETECTED_PATH, "move_to_detected() must wrap RS_AIActionMoveToDetected")
	assert_eq(inner.get("arrival_threshold"), 1.2, "move_to_detected must set arrival_threshold")

func test_move_to_nearest_creates_bt_action_with_scan_type_and_radius() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("move_to_nearest", &"C_ResourceNode", 2.0)
	assert_not_null(node, "move_to_nearest() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "move_to_nearest() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_MOVE_TO_NEAREST_PATH, "move_to_nearest() must wrap RS_AIActionMoveToNearest")
	assert_eq(inner.get("scan_component_type"), &"C_ResourceNode", "move_to_nearest must set scan_component_type")
	assert_eq(inner.get("arrival_threshold"), 2.0, "move_to_nearest must set arrival_threshold")

func test_flee_creates_bt_action_with_distance_and_radius() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("flee", 8.0, 0.6)
	assert_not_null(node, "flee() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "flee() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_FLEE_PATH, "flee() must wrap RS_AIActionFleeFromDetected")
	assert_eq(inner.get("flee_distance"), 8.0, "flee must set flee_distance")
	assert_eq(inner.get("arrival_threshold"), 0.6, "flee must set arrival_threshold")

func test_wander_creates_bt_action_with_home_radius() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("wander", 12.0)
	assert_not_null(node, "wander() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "wander() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_WANDER_PATH, "wander() must wrap RS_AIActionWander")
	assert_eq(inner.get("home_radius"), 12.0, "wander must set home_radius")

func test_wait_creates_bt_action_with_duration() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("wait", 3.5)
	assert_not_null(node, "wait() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "wait() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_WAIT_PATH, "wait() must wrap RS_AIActionWait")
	assert_eq(inner.get("duration"), 3.5, "wait must set duration")

func test_scan_creates_bt_action_with_duration_and_speed() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("scan", 4.0, 2.5)
	assert_not_null(node, "scan() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "scan() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_SCAN_PATH, "scan() must wrap RS_AIActionScan")
	assert_eq(inner.get("scan_duration"), 4.0, "scan must set scan_duration")
	assert_eq(inner.get("rotation_speed"), 2.5, "scan must set rotation_speed")

func test_animate_creates_bt_action_with_animation_state() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("animate", &"run")
	assert_not_null(node, "animate() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "animate() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_ANIMATE_PATH, "animate() must wrap RS_AIActionAnimate")
	assert_eq(inner.get("animation_state"), &"run", "animate must set animation_state")

func test_publish_event_creates_bt_action_with_name_and_payload() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var payload: Dictionary = {"key": "value"}
	var node: Variant = factory.call("publish_event", &"test_event", payload)
	assert_not_null(node, "publish_event() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "publish_event() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_PUBLISH_EVENT_PATH, "publish_event() must wrap RS_AIActionPublishEvent")
	assert_eq(inner.get("event_name"), &"test_event", "publish_event must set event_name")
	assert_eq(inner.get("payload"), payload, "publish_event must set payload")

func test_set_field_float_creates_bt_action_with_float_value() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("set_field", "health", 0.5)
	assert_not_null(node, "set_field() must return non-null")
	var inner: Resource = _inner_action(node)
	assert_not_null(inner, "set_field() node must have an inner action")
	assert_eq(_script_path(inner), RS_AI_ACTION_SET_FIELD_PATH, "set_field() must wrap RS_AIActionSetField")
	assert_eq(inner.get("field_path"), "health", "set_field must set field_path")
	assert_eq(inner.get("value_type"), "float", "set_field float must set value_type to float")
	assert_eq(inner.get("float_value"), 0.5, "set_field float must set float_value")

func test_always_creates_bt_condition_with_score_one() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("always")
	assert_not_null(node, "always() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "always() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_CONSTANT_PATH, "always() must wrap RS_ConditionConstant")
	assert_eq(inner.get("score"), 1.0, "always() score must be 1.0")

func test_never_creates_bt_condition_with_score_zero() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("never")
	assert_not_null(node, "never() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "never() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_CONSTANT_PATH, "never() must wrap RS_ConditionConstant")
	assert_eq(inner.get("score"), 0.0, "never() score must be 0.0")

func test_component_field_creates_bt_condition_with_type_and_field() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("component_field", &"C_HealthComponent", "health")
	assert_not_null(node, "component_field() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "component_field() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_COMPONENT_FIELD_PATH, "component_field() must wrap RS_ConditionComponentField")
	assert_eq(inner.get("component_type"), &"C_HealthComponent", "component_field must set component_type")
	assert_eq(inner.get("field_path"), "health", "component_field must set field_path")

func test_context_field_creates_bt_condition_with_path() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("context_field", "entity.health")
	assert_not_null(node, "context_field() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "context_field() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_CONTEXT_FIELD_PATH, "context_field() must wrap RS_ConditionContextField")
	assert_eq(inner.get("field_path"), "entity.health", "context_field must set field_path")

func test_entity_tag_creates_bt_condition_with_tag_name() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("entity_tag", &"prey")
	assert_not_null(node, "entity_tag() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "entity_tag() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_ENTITY_TAG_PATH, "entity_tag() must wrap RS_ConditionEntityTag")
	assert_eq(inner.get("tag_name"), &"prey", "entity_tag must set tag_name")

func test_redux_field_creates_bt_condition_with_state_path() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var node: Variant = factory.call("redux_field", "gameplay.hunger")
	assert_not_null(node, "redux_field() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "redux_field() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_REDUX_FIELD_PATH, "redux_field() must wrap RS_ConditionReduxField")
	assert_eq(inner.get("state_path"), "gameplay.hunger", "redux_field must set state_path")

func test_composite_all_creates_bt_condition_with_all_mode_and_children() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var cond_a: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	var cond_b: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if cond_a == null or cond_b == null:
		return
	var node: Variant = factory.call("composite_all", [cond_a, cond_b])
	assert_not_null(node, "composite_all() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "composite_all() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_COMPOSITE_PATH, "composite_all() must wrap RS_ConditionComposite")
	assert_eq(inner.get("mode"), 0, "composite_all must set mode to ALL (0)")
	var children: Variant = inner.get("children")
	assert_true(children is Array, "composite_all inner condition must have children array")
	assert_eq((children as Array).size(), 2, "composite_all children count must match input")

func test_composite_any_creates_bt_condition_with_any_mode_and_children() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var cond_a: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if cond_a == null:
		return
	var node: Variant = factory.call("composite_any", [cond_a])
	assert_not_null(node, "composite_any() must return non-null")
	var inner: Resource = _inner_condition(node)
	assert_not_null(inner, "composite_any() node must have an inner condition")
	assert_eq(_script_path(inner), RS_CONDITION_COMPOSITE_PATH, "composite_any() must wrap RS_ConditionComposite")
	assert_eq(inner.get("mode"), 1, "composite_any must set mode to ANY (1)")
	var children: Variant = inner.get("children")
	assert_true(children is Array, "composite_any inner condition must have children array")
	assert_eq((children as Array).size(), 1, "composite_any children count must match input")

func test_planner_creates_rs_bt_planner_with_goal_and_depth() -> void:
	var factory: Object = _new_factory()
	if factory == null:
		return
	var goal: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if goal == null:
		return
	goal.set("score", 1.0)
	var node: Variant = factory.call("planner", goal, [], 4)
	assert_not_null(node, "planner() must return non-null")
	assert_true(node is Resource, "planner() must return a Resource")
	assert_eq(_script_path(node as Resource), RS_BT_PLANNER_PATH, "planner() must return RS_BTPlanner")
	assert_eq((node as Resource).get("goal"), goal, "planner must set goal")
	assert_eq((node as Resource).get("max_depth"), 4, "planner must set max_depth")

func test_wait_zero_ticks_success_with_runner() -> void:
	var factory: Object = _new_factory()
	var runner: Object = _new_runner()
	if factory == null or runner == null:
		return
	var node: Variant = factory.call("wait", 0.0)
	if node == null:
		return
	var state_bag: Dictionary = {}
	var result: Variant = runner.call("tick", node, {}, state_bag)
	assert_eq(result, _status("SUCCESS"), "wait(0.0) must tick SUCCESS immediately")
