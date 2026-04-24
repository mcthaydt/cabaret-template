extends GutTest

const I_AI_ACTION_PATH := "res://scripts/core/interfaces/i_ai_action.gd"
const ACTION_SCRIPT_PATHS := [
	"res://scripts/resources/ai/actions/rs_ai_action_move_to.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_wait.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_scan.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_animate.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_publish_event.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_set_field.gd",
]

func _read_script_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Expected script file to exist: %s" % path)
	if file == null:
		return ""
	var content: String = file.get_as_text()
	file.close()
	return content

func test_subclass_extends_class_name() -> void:
	var violations: Array[String] = []
	for path in ACTION_SCRIPT_PATHS:
		var source: String = _read_script_text(path)
		if source.find("extends I_AIAction") == -1:
			violations.append(path)

	assert_eq(
		violations.size(),
		0,
		"AI action scripts should extend class_name base I_AIAction:\n%s" % "\n".join(violations)
	)

func test_base_virtuals_are_callable_and_return_defaults() -> void:
	var interface_script_variant: Variant = load(I_AI_ACTION_PATH)
	assert_not_null(interface_script_variant, "Expected script to exist: %s" % I_AI_ACTION_PATH)
	if interface_script_variant == null or not (interface_script_variant is Script):
		return

	var interface_script: Script = interface_script_variant as Script
	var interface_instance_variant: Variant = interface_script.new()
	assert_true(interface_instance_variant is I_AIAction, "Expected I_AIAction.new() instance")
	if not (interface_instance_variant is I_AIAction):
		return

	var interface_instance: I_AIAction = interface_instance_variant as I_AIAction

	interface_instance.start({}, {})
	assert_push_error("I_AIAction.start: not implemented")
	interface_instance.tick({}, {}, 0.0)
	assert_push_error("I_AIAction.tick: not implemented")
	var is_complete: bool = interface_instance.is_complete({}, {})
	assert_push_error("I_AIAction.is_complete: not implemented")
	assert_false(is_complete, "I_AIAction.is_complete should default to false in base implementation")

func test_base_stubs_push_error_on_start() -> void:
	var interface_script_variant: Variant = load(I_AI_ACTION_PATH)
	if interface_script_variant == null or not (interface_script_variant is Script):
		return
	var interface_script: Script = interface_script_variant as Script
	var instance: I_AIAction = interface_script.new() as I_AIAction
	if instance == null:
		return
	instance.start({}, {})
	assert_push_error("I_AIAction.start: not implemented")

func test_base_stubs_push_error_on_tick() -> void:
	var interface_script_variant: Variant = load(I_AI_ACTION_PATH)
	if interface_script_variant == null or not (interface_script_variant is Script):
		return
	var interface_script: Script = interface_script_variant as Script
	var instance: I_AIAction = interface_script.new() as I_AIAction
	if instance == null:
		return
	instance.tick({}, {}, 0.0)
	assert_push_error("I_AIAction.tick: not implemented")

func test_base_stubs_push_error_on_is_complete() -> void:
	var interface_script_variant: Variant = load(I_AI_ACTION_PATH)
	if interface_script_variant == null or not (interface_script_variant is Script):
		return
	var interface_script: Script = interface_script_variant as Script
	var instance: I_AIAction = interface_script.new() as I_AIAction
	if instance == null:
		return
	instance.is_complete({}, {})
	assert_push_error("I_AIAction.is_complete: not implemented")
