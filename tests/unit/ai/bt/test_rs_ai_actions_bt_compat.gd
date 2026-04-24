extends GutTest

const RS_BT_ACTION_PATH := "res://scripts/resources/ai/bt/rs_bt_action.gd"
const I_AI_ACTION_PATH := "res://scripts/interfaces/i_ai_action.gd"

const RS_AI_ACTION_PATHS := [
	"res://scripts/resources/ai/actions/rs_ai_action_animate.gd",
	"res://scripts/demo/resources/ai/actions/rs_ai_action_feed.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_move_to.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_publish_event.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_scan.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_set_field.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_wait.gd",
	"res://scripts/resources/ai/actions/rs_ai_action_wander.gd",
]

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _script_inherits_from(script: Script, base: Script) -> bool:
	var cursor: Script = script
	while cursor != null:
		if cursor == base:
			return true
		cursor = cursor.get_base_script()
	return false

func test_expected_action_count_is_ten() -> void:
	assert_eq(
		RS_AI_ACTION_PATHS.size(),
		10,
		"P1.3 verification expects exactly 10 RS_AIAction* scripts under BT without modification"
	)

func test_each_action_script_exists_and_extends_i_ai_action() -> void:
	var i_ai_action: Script = _load_script(I_AI_ACTION_PATH)
	assert_not_null(i_ai_action, "I_AIAction script must load")
	if i_ai_action == null:
		return

	for path in RS_AI_ACTION_PATHS:
		var script: Script = _load_script(path)
		assert_not_null(script, "Expected RS_AIAction script to load: %s" % path)
		if script == null:
			continue
		assert_true(
			_script_inherits_from(script, i_ai_action),
			"%s must extend I_AIAction to run under RS_BTAction without modification" % path
		)

func test_each_action_instantiates_and_binds_to_rs_bt_action() -> void:
	var bt_action_script: Script = _load_script(RS_BT_ACTION_PATH)
	assert_not_null(bt_action_script, "RS_BTAction script must load")
	if bt_action_script == null:
		return

	for path in RS_AI_ACTION_PATHS:
		var action_script: Script = _load_script(path)
		if action_script == null:
			continue

		var action_variant: Variant = action_script.new()
		assert_not_null(action_variant, "Expected %s.new() to succeed" % path)
		if action_variant == null:
			continue
		var action: Resource = action_variant as Resource
		assert_not_null(action, "Expected %s instance to be a Resource" % path)
		if action == null:
			continue

		var bt_action_variant: Variant = bt_action_script.new()
		assert_not_null(bt_action_variant, "Expected RS_BTAction.new() to succeed")
		if bt_action_variant == null:
			continue
		var bt_action: Resource = bt_action_variant as Resource

		bt_action.set("action", action)
		var bound: Variant = bt_action.get("action")
		assert_eq(
			bound,
			action,
			"RS_BTAction.action (typed I_AIAction) must accept %s unmodified" % path
		)
