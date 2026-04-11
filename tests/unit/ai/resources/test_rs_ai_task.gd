extends GutTest

const I_AI_ACTION_PATH := "res://scripts/interfaces/i_ai_action.gd"
const I_CONDITION_PATH := "res://scripts/interfaces/i_condition.gd"
const RS_AI_TASK_PATH := "res://scripts/resources/ai/tasks/rs_ai_task.gd"
const RS_AI_PRIMITIVE_TASK_PATH := "res://scripts/resources/ai/tasks/rs_ai_primitive_task.gd"
const RS_AI_COMPOUND_TASK_PATH := "res://scripts/resources/ai/tasks/rs_ai_compound_task.gd"

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_primitive_task_holds_action_resource() -> void:
	var primitive_task_script: Script = _load_script(RS_AI_PRIMITIVE_TASK_PATH)
	var interface_script: Script = _load_script(I_AI_ACTION_PATH)
	if primitive_task_script == null or interface_script == null:
		return

	var primitive_task: Resource = primitive_task_script.new()
	var action: Resource = interface_script.new()
	primitive_task.set("action", action)

	assert_eq(primitive_task.get("action"), action, "RS_AIPrimitiveTask.action should hold I_AIAction resources")

func test_compound_task_has_subtasks_array() -> void:
	var compound_task_script: Script = _load_script(RS_AI_COMPOUND_TASK_PATH)
	var task_script: Script = _load_script(RS_AI_TASK_PATH)
	if compound_task_script == null or task_script == null:
		return

	var first_task_variant: Variant = task_script.new()
	var first_task: RS_AITask = first_task_variant as RS_AITask
	first_task.set("task_id", StringName("first"))
	var second_task_variant: Variant = task_script.new()
	var second_task: RS_AITask = second_task_variant as RS_AITask
	second_task.set("task_id", StringName("second"))

	var compound_task: Resource = compound_task_script.new()
	var subtasks: Array[RS_AITask] = [first_task, second_task]
	compound_task.set("subtasks", subtasks)

	var subtasks_variant: Variant = compound_task.get("subtasks")
	assert_true(subtasks_variant is Array, "RS_AICompoundTask.subtasks should be an array")
	if not (subtasks_variant is Array):
		return
	var ordered_subtasks: Array = subtasks_variant as Array
	assert_eq(ordered_subtasks.size(), 2, "RS_AICompoundTask.subtasks should keep ordered entries")
	assert_eq(ordered_subtasks[0], first_task, "First subtask should stay first")
	assert_eq(ordered_subtasks[1], second_task, "Second subtask should stay second")

func test_compound_task_has_method_conditions_array() -> void:
	var compound_task_script: Script = _load_script(RS_AI_COMPOUND_TASK_PATH)
	var condition_interface_script: Script = _load_script(I_CONDITION_PATH)
	if compound_task_script == null or condition_interface_script == null:
		return

	var first_condition_variant: Variant = condition_interface_script.new()
	var first_condition: I_Condition = first_condition_variant as I_Condition
	var second_condition_variant: Variant = condition_interface_script.new()
	var second_condition: I_Condition = second_condition_variant as I_Condition

	var compound_task: Resource = compound_task_script.new()
	var method_conditions: Array[I_Condition] = [first_condition, second_condition]
	compound_task.set("method_conditions", method_conditions)

	var conditions_variant: Variant = compound_task.get("method_conditions")
	assert_true(conditions_variant is Array, "RS_AICompoundTask.method_conditions should be an array")
	if not (conditions_variant is Array):
		return
	var ordered_conditions: Array = conditions_variant as Array
	assert_eq(ordered_conditions.size(), 2, "RS_AICompoundTask.method_conditions should keep ordered entries")
	assert_eq(ordered_conditions[0], first_condition, "First method condition should stay first")
	assert_eq(ordered_conditions[1], second_condition, "Second method condition should stay second")

func test_task_id_is_string_name() -> void:
	var task_script: Script = _load_script(RS_AI_TASK_PATH)
	if task_script == null:
		return

	var task: Resource = task_script.new()
	task.set("task_id", StringName("investigate"))

	var task_id_variant: Variant = task.get("task_id")
	assert_true(task_id_variant is StringName, "RS_AITask.task_id should be StringName")
	assert_eq(task_id_variant, StringName("investigate"))

func test_i_ai_action_interface_contract() -> void:
	var interface_script: Script = _load_script(I_AI_ACTION_PATH)
	if interface_script == null:
		return

	var interface_instance: Resource = interface_script.new()
	assert_true(interface_instance.has_method("start"), "I_AIAction must declare start(context, task_state)")
	assert_true(interface_instance.has_method("tick"), "I_AIAction must declare tick(context, task_state, delta)")
	assert_true(interface_instance.has_method("is_complete"), "I_AIAction must declare is_complete(context, task_state)")

func test_primitive_task_action_defaults_to_null() -> void:
	var primitive_task_script: Script = _load_script(RS_AI_PRIMITIVE_TASK_PATH)
	if primitive_task_script == null:
		return

	var primitive_task: Resource = primitive_task_script.new()
	assert_null(primitive_task.get("action"), "RS_AIPrimitiveTask.action should default to null")

# --- R1: Typed field tests ---

func test_primitive_task_action_typed_i_ai_action() -> void:
	var primitive_task_script: Script = _load_script(RS_AI_PRIMITIVE_TASK_PATH)
	if primitive_task_script == null:
		return

	var primitive_task: Resource = primitive_task_script.new()
	var prop := _get_property_definition(primitive_task, "action")
	_assert_typed_property_hint(prop, "I_AIAction", false, "RS_AIPrimitiveTask.action should be typed I_AIAction")

func test_compound_task_subtasks_typed_rs_ai_task() -> void:
	var compound_task_script: Script = _load_script(RS_AI_COMPOUND_TASK_PATH)
	if compound_task_script == null:
		return

	var compound_task: Resource = compound_task_script.new()
	var prop := _get_property_definition(compound_task, "subtasks")
	_assert_typed_property_hint(prop, "RS_AITask", true, "RS_AICompoundTask.subtasks should be typed Array[RS_AITask]")

func test_compound_task_method_conditions_typed_i_condition() -> void:
	var compound_task_script: Script = _load_script(RS_AI_COMPOUND_TASK_PATH)
	if compound_task_script == null:
		return

	var compound_task: Resource = compound_task_script.new()
	var prop := _get_property_definition(compound_task, "method_conditions")
	_assert_typed_property_hint(prop, "I_Condition", true, "RS_AICompoundTask.method_conditions should be typed Array[I_Condition]")

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
