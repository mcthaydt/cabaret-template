extends BaseTest

const ACTION_WAIT_PATH := "res://scripts/resources/ai/actions/rs_ai_action_wait.gd"
const ACTION_PUBLISH_EVENT_PATH := "res://scripts/resources/ai/actions/rs_ai_action_publish_event.gd"
const ACTION_SET_FIELD_PATH := "res://scripts/resources/ai/actions/rs_ai_action_set_field.gd"
const ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	ECS_EVENT_BUS.reset()

func after_each() -> void:
	ECS_EVENT_BUS.reset()

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_wait_action_completes_after_duration() -> void:
	var action_script: Script = _load_script(ACTION_WAIT_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("duration", 0.5)

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	action.tick(context, task_state, 0.2)
	assert_false(action.is_complete(context, task_state))
	action.tick(context, task_state, 0.3)
	assert_true(action.is_complete(context, task_state))

func test_wait_action_tracks_elapsed_in_task_state() -> void:
	var action_script: Script = _load_script(ACTION_WAIT_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("duration", 10.0)
	var context: Dictionary = {}
	var task_state: Dictionary = {}

	action.start(context, task_state)
	action.tick(context, task_state, 0.25)
	action.tick(context, task_state, 0.5)

	assert_true(task_state.has("elapsed"))
	assert_almost_eq(float(task_state.get("elapsed", -1.0)), 0.75, 0.0001)

func test_publish_event_action_fires_and_completes_immediately() -> void:
	var action_script: Script = _load_script(ACTION_PUBLISH_EVENT_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("event_name", StringName("ai/task_event"))
	action.set("payload", {"source": "unit_test"})

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var history: Array = ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 1)
	if history.size() != 1:
		return
	var event_entry: Dictionary = history[0] as Dictionary
	assert_eq(event_entry.get("name", StringName()), StringName("ai/task_event"))
	assert_eq((event_entry.get("payload", {}) as Dictionary).get("source", ""), "unit_test")
	assert_true(action.is_complete(context, task_state))

func test_set_field_action_modifies_component_and_completes() -> void:
	var action_script: Script = _load_script(ACTION_SET_FIELD_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("field_path", "components.C_TestComponent.alert_level")
	action.set("value_type", "float")
	action.set("float_value", 0.75)

	var component: Dictionary = {"alert_level": 0.0}
	var context: Dictionary = {
		"components": {
			"C_TestComponent": component,
		}
	}
	var task_state: Dictionary = {}

	action.start(context, task_state)

	assert_almost_eq(float(component.get("alert_level", -1.0)), 0.75, 0.0001)
	assert_true(action.is_complete(context, task_state))

func test_set_field_action_typed_exports() -> void:
	var action_script: Script = _load_script(ACTION_SET_FIELD_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	var property_list: Array[Dictionary] = action.get_property_list()
	var names: Dictionary = {}
	for property_info in property_list:
		names[str(property_info.get("name", ""))] = true

	assert_true(names.has("field_path"))
	assert_true(names.has("value_type"))
	assert_true(names.has("float_value"))
	assert_true(names.has("int_value"))
	assert_true(names.has("bool_value"))
	assert_true(names.has("string_value"))
