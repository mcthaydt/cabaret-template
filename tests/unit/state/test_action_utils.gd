extends GutTest

const ActionUtils: Script = preload("res://scripts/state/action.gd")

func test_create_action_converts_type_to_string_name() -> void:
	var action: Dictionary = ActionUtils.create_action("game/add_score", 42)
	assert_true(action.has("type"))
	assert_true(action.has("payload"))
	assert_eq(typeof(action["type"]), TYPE_STRING_NAME)
	assert_eq(action["type"], StringName("game/add_score"))
	assert_eq(action["payload"], 42)

func test_create_action_defaults_payload_to_null() -> void:
	var action: Dictionary = ActionUtils.create_action(StringName("ui/open_menu"))
	assert_eq(action["type"], StringName("ui/open_menu"))
	assert_true(action.has("payload"))
	assert_null(action["payload"])

func test_is_action_validates_structure() -> void:
	var valid: Dictionary = ActionUtils.create_action("session/set_slot", 3)
	assert_true(ActionUtils.is_action(valid))

	var invalid := {"payload": 10}
	assert_false(ActionUtils.is_action(invalid))

	var wrong_type := {"type": 123, "payload": null}
	assert_false(ActionUtils.is_action(wrong_type))

func test_define_registers_namespaced_string_name() -> void:
	ActionUtils.clear_registry()
	var action_type: StringName = ActionUtils.define("game", "add_score")
	assert_eq(action_type, StringName("game/add_score"))

	var second_call: StringName = ActionUtils.define("game", "add_score")
	assert_eq(second_call, action_type)

	var all_types: Array[StringName] = ActionUtils.get_registered_types()
	assert_true(all_types.has(StringName("game/add_score")))
