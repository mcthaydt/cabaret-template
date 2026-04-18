extends GutTest

const RS_AI_GOAL_PATH := "res://scripts/resources/ai/goals/rs_ai_goal.gd"
const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/resources/ai/brain/rs_ai_brain_settings.gd"
const RS_AI_PRIMITIVE_TASK_PATH := "res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd"
const CONDITION_COMPONENT_FIELD_PATH := "res://scripts/resources/qb/conditions/rs_condition_component_field.gd"

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_goal_has_id_conditions_and_root_task() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	var primitive_task_script: Script = _load_script(RS_AI_PRIMITIVE_TASK_PATH)
	var condition_script: Script = _load_script(CONDITION_COMPONENT_FIELD_PATH)
	if goal_script == null or primitive_task_script == null or condition_script == null:
		return

	var goal_variant: Variant = goal_script.new()
	var goal: RS_AIGoal = goal_variant as RS_AIGoal
	var root_task_variant: Variant = primitive_task_script.new()
	var root_task: RS_AIPrimitiveTask = root_task_variant as RS_AIPrimitiveTask
	root_task.set("task_id", StringName("patrol_root"))
	var condition_variant: Variant = condition_script.new()
	var condition: I_Condition = condition_variant as I_Condition
	condition.set("component_type", StringName("C_TestComponent"))
	condition.set("field_path", "is_alert")

	goal.set("goal_id", StringName("patrol"))
	var conditions: Array[I_Condition] = [condition]
	goal.set("conditions", conditions)
	goal.set("root_task", root_task)

	assert_eq(goal.get("goal_id"), StringName("patrol"), "RS_AIGoal.goal_id should be assignable as StringName")
	var conditions_variant: Variant = goal.get("conditions")
	assert_true(conditions_variant is Array, "RS_AIGoal.conditions should be an array")
	if not (conditions_variant is Array):
		return
	var stored_conditions: Array = conditions_variant as Array
	assert_eq(stored_conditions.size(), 1, "RS_AIGoal.conditions should keep configured entries")
	assert_eq(stored_conditions[0], condition, "RS_AIGoal.conditions should accept RS_Condition* resources")
	assert_eq(goal.get("root_task"), root_task, "RS_AIGoal.root_task should hold an AI task resource")

func test_goal_priority_defaults_to_zero() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	assert_eq(goal.get("priority"), 0, "RS_AIGoal.priority should default to 0")

func test_goal_state_gate_fields_have_defaults_and_are_assignable() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	assert_almost_eq(float(goal.get("score_threshold")), 0.0, 0.0001, "RS_AIGoal.score_threshold should default to 0.0")
	assert_almost_eq(float(goal.get("cooldown")), 0.0, 0.0001, "RS_AIGoal.cooldown should default to 0.0")
	assert_false(bool(goal.get("one_shot")), "RS_AIGoal.one_shot should default to false")
	assert_false(bool(goal.get("requires_rising_edge")), "RS_AIGoal.requires_rising_edge should default to false")

	goal.set("score_threshold", 0.25)
	goal.set("cooldown", 1.5)
	goal.set("one_shot", true)
	goal.set("requires_rising_edge", true)

	assert_almost_eq(float(goal.get("score_threshold")), 0.25, 0.0001)
	assert_almost_eq(float(goal.get("cooldown")), 1.5, 0.0001)
	assert_true(bool(goal.get("one_shot")))
	assert_true(bool(goal.get("requires_rising_edge")))

func test_brain_settings_evaluation_interval_default() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	assert_almost_eq(float(brain_settings.get("evaluation_interval")), 0.5, 0.0001, "RS_AIBrainSettings.evaluation_interval should default to 0.5")

func test_root_task_typed_rs_ai_task() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	var prop := _get_property_definition(goal, "root_task")
	_assert_typed_property_hint(prop, "RS_AITask", false, "RS_AIGoal.root_task should be typed RS_AITask")

func test_conditions_array_typed_i_condition() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	var prop := _get_property_definition(goal, "conditions")
	_assert_typed_property_hint(prop, "I_Condition", true, "RS_AIGoal.conditions should be typed Array[I_Condition]")

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}

func _assert_typed_property_hint(property_definition: Dictionary, expected_type: String, expect_array: bool, message: String) -> void:
	var hint_string: String = str(property_definition.get("hint_string", ""))
	if expect_array:
		var is_human_readable: bool = hint_string == "Array[%s]" % expected_type
		var is_engine_encoded: bool = hint_string.ends_with(":%s" % expected_type)
		assert_true(
			is_human_readable or is_engine_encoded,
			"%s (actual hint_string=%s)" % [message, hint_string]
		)
		return
	assert_true(
		hint_string == expected_type or hint_string.ends_with(":%s" % expected_type),
		"%s (actual hint_string=%s)" % [message, hint_string]
	)
