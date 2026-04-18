extends GutTest

const RS_BT_PLANNER_ACTION_PATH := "res://scripts/resources/ai/bt/rs_bt_planner_action.gd"
const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/resources/qb/conditions/rs_condition_constant.gd"
const RS_WORLD_STATE_EFFECT_PATH := "res://scripts/resources/ai/bt/rs_world_state_effect.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_resource(path: String) -> Resource:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	assert_not_null(instance_variant, "Expected resource to instantiate: %s" % path)
	if instance_variant == null:
		return null
	return instance_variant as Resource

func _new_planner_action() -> Resource:
	return _new_resource(RS_BT_PLANNER_ACTION_PATH)

func _new_constant_condition(score: float) -> Resource:
	var condition: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if condition == null:
		return null
	condition.set("score", score)
	return condition

func _new_world_state_effect() -> Resource:
	return _new_resource(RS_WORLD_STATE_EFFECT_PATH)

func _status(name: String) -> int:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return -1
	var status_enum: Variant = node_script.get("Status")
	if not (status_enum is Dictionary):
		return -1
	return int((status_enum as Dictionary).get(name, -1))

func _new_status_node(status: int) -> Resource:
	var status_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if status_script == null:
		return null
	var node_variant: Variant = status_script.new(status)
	assert_not_null(node_variant, "Expected status-node helper to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property: Dictionary = property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}

func _assert_typed_property_hint(property_definition: Dictionary, expected_type: String, expect_array: bool, message: String) -> void:
	var hint_string: String = str(property_definition.get("hint_string", ""))
	if expect_array:
		var is_human_readable: bool = hint_string == "Array[%s]" % expected_type
		var is_engine_encoded: bool = hint_string.ends_with(":%s" % expected_type)
		assert_true(is_human_readable or is_engine_encoded, "%s (actual hint_string=%s)" % [message, hint_string])
		return
	assert_true(
		hint_string == expected_type or hint_string.ends_with(":%s" % expected_type),
		"%s (actual hint_string=%s)" % [message, hint_string]
	)

func test_planner_action_script_exists_and_loads() -> void:
	var script: Script = _load_script(RS_BT_PLANNER_ACTION_PATH)
	assert_not_null(script, "RS_BTPlannerAction script must exist and load")

func test_preconditions_are_typed_and_coerce_invalid_entries() -> void:
	var planner_action: Resource = _new_planner_action()
	if planner_action == null:
		return
	var condition_true: Resource = _new_constant_condition(1.0)
	if condition_true == null:
		return

	planner_action.set("preconditions", [condition_true, "invalid", null, 3])
	var preconditions_variant: Variant = planner_action.get("preconditions")
	assert_true(preconditions_variant is Array, "preconditions should remain an array")
	if not (preconditions_variant is Array):
		return
	var preconditions: Array = preconditions_variant as Array
	assert_eq(preconditions.size(), 1, "preconditions should keep only I_Condition entries")
	assert_eq(preconditions[0], condition_true, "preconditions should retain valid I_Condition resources")

	var prop: Dictionary = _get_property_definition(planner_action, "preconditions")
	_assert_typed_property_hint(prop, "I_Condition", true, "preconditions should be typed Array[I_Condition]")

func test_effects_are_typed_and_coerce_invalid_entries() -> void:
	var planner_action: Resource = _new_planner_action()
	if planner_action == null:
		return
	var effect: Resource = _new_world_state_effect()
	if effect == null:
		return

	planner_action.set("effects", [effect, "invalid", null, 2])
	var effects_variant: Variant = planner_action.get("effects")
	assert_true(effects_variant is Array, "effects should remain an array")
	if not (effects_variant is Array):
		return
	var effects: Array = effects_variant as Array
	assert_eq(effects.size(), 1, "effects should keep only RS_WorldStateEffect entries")
	assert_eq(effects[0], effect, "effects should retain valid RS_WorldStateEffect resources")

	var prop: Dictionary = _get_property_definition(planner_action, "effects")
	_assert_typed_property_hint(prop, "RS_WorldStateEffect", true, "effects should be typed Array[RS_WorldStateEffect]")

func test_cost_defaults_to_one_and_invalid_cost_fails_loud() -> void:
	var planner_action: Resource = _new_planner_action()
	if planner_action == null:
		return
	assert_almost_eq(float(planner_action.get("cost")), 1.0, 0.0001, "cost should default to 1.0")

	planner_action.set("cost", 0.0)
	var applicable: Variant = planner_action.call("is_applicable", {})
	assert_false(bool(applicable), "cost <= 0 should make planner action inapplicable")
	assert_push_error("RS_BTPlannerAction.is_applicable: cost must be > 0.0")

func test_is_applicable_requires_all_preconditions_to_pass() -> void:
	var planner_action: Resource = _new_planner_action()
	var condition_true: Resource = _new_constant_condition(1.0)
	var condition_false: Resource = _new_constant_condition(0.0)
	if planner_action == null or condition_true == null or condition_false == null:
		return
	planner_action.set("cost", 1.0)

	planner_action.set("preconditions", [condition_true, condition_true])
	assert_true(bool(planner_action.call("is_applicable", {})), "all positive preconditions should pass")

	planner_action.set("preconditions", [condition_true, condition_false])
	assert_false(bool(planner_action.call("is_applicable", {})), "any non-positive precondition should fail")

func test_tick_delegates_to_child_node_status() -> void:
	var planner_action: Resource = _new_planner_action()
	if planner_action == null:
		return
	var child: Resource = _new_status_node(_status("RUNNING"))
	if child == null:
		return
	planner_action.set("cost", 1.0)
	planner_action.set("child", child)

	var state_bag: Dictionary = {}
	var status: Variant = planner_action.call("tick", {}, state_bag)
	assert_eq(status, _status("RUNNING"), "planner action should return child tick status")
	assert_eq(child.get("tick_count"), 1, "planner action should delegate tick to child")

