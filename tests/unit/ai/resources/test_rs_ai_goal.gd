extends GutTest

const RS_AI_GOAL_PATH := "res://scripts/resources/ai/rs_ai_goal.gd"
const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/resources/ai/rs_ai_brain_settings.gd"
const RS_AI_PRIMITIVE_TASK_PATH := "res://scripts/resources/ai/rs_ai_primitive_task.gd"
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

	var goal: Resource = goal_script.new()
	var root_task: Resource = primitive_task_script.new()
	root_task.set("task_id", StringName("patrol_root"))
	var condition: Resource = condition_script.new()
	condition.set("component_type", StringName("C_TestComponent"))
	condition.set("field_path", "is_alert")

	goal.set("goal_id", StringName("patrol"))
	var conditions: Array[Resource] = [condition]
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

func test_brain_settings_holds_goals_array() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if brain_settings_script == null or goal_script == null:
		return

	var first_goal: Resource = goal_script.new()
	first_goal.set("goal_id", StringName("patrol"))
	var second_goal: Resource = goal_script.new()
	second_goal.set("goal_id", StringName("investigate"))

	var brain_settings: Resource = brain_settings_script.new()
	var goals: Array[Resource] = [first_goal, second_goal]
	brain_settings.set("goals", goals)

	var goals_variant: Variant = brain_settings.get("goals")
	assert_true(goals_variant is Array, "RS_AIBrainSettings.goals should be an array")
	if not (goals_variant is Array):
		return
	var stored_goals: Array = goals_variant as Array
	assert_eq(stored_goals.size(), 2, "RS_AIBrainSettings.goals should keep configured goals")
	assert_eq(stored_goals[0], first_goal, "First goal should stay first")
	assert_eq(stored_goals[1], second_goal, "Second goal should stay second")

func test_brain_settings_default_goal_id() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	brain_settings.set("default_goal_id", StringName("idle"))
	var default_goal_id: Variant = brain_settings.get("default_goal_id")
	assert_true(default_goal_id is StringName, "RS_AIBrainSettings.default_goal_id should be StringName")
	assert_eq(default_goal_id, StringName("idle"))

func test_brain_settings_evaluation_interval_default() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	assert_almost_eq(float(brain_settings.get("evaluation_interval")), 0.5, 0.0001, "RS_AIBrainSettings.evaluation_interval should default to 0.5")

# --- R1: Typed field tests ---

func test_goals_array_is_typed_rs_ai_goal() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	var prop := _get_property_definition(brain_settings, "goals")
	assert_eq(str(prop.get("hint_string", "")), "Array[RS_AIGoal]", "RS_AIBrainSettings.goals hint_string should be Array[RS_AIGoal]")

func test_goals_rejects_non_rs_ai_goal_entries() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if brain_settings_script == null or goal_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	var valid_goal: Resource = goal_script.new()
	valid_goal.set("goal_id", StringName("patrol"))

	# Assigning a valid RS_AIGoal should work
	var goals_typed: Array = brain_settings.get("goals")
	goals_typed.append(valid_goal)
	assert_eq(goals_typed.size(), 1, "Valid RS_AIGoal should be appendable to goals array")

	# Assigning a non-RS_AIGoal Resource should be rejected by the typed array
	var invalid_entry: Resource = Resource.new()
	goals_typed.append(invalid_entry)
	assert_eq(goals_typed.size(), 1, "Non-RS_AIGoal Resource should be rejected by typed goals array")

func test_root_task_typed_rs_ai_task() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	var prop := _get_property_definition(goal, "root_task")
	assert_eq(str(prop.get("hint_string", "")), "RS_AITask", "RS_AIGoal.root_task hint_string should be RS_AITask")

func test_conditions_array_typed_i_condition() -> void:
	var goal_script: Script = _load_script(RS_AI_GOAL_PATH)
	if goal_script == null:
		return

	var goal: Resource = goal_script.new()
	var prop := _get_property_definition(goal, "conditions")
	assert_eq(str(prop.get("hint_string", "")), "Array[I_Condition]", "RS_AIGoal.conditions hint_string should be Array[I_Condition]")

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}
