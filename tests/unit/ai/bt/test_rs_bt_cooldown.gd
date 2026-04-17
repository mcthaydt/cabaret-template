extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_BT_COOLDOWN_PATH := "res://scripts/resources/bt/rs_bt_cooldown.gd"
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

func _status(name: String) -> int:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return -1
	var status_enum: Variant = node_script.get("Status")
	if not (status_enum is Dictionary):
		return -1
	return int((status_enum as Dictionary).get(name, -1))

func _new_cooldown(duration: float) -> Resource:
	var cooldown_script: Script = _load_script(RS_BT_COOLDOWN_PATH)
	if cooldown_script == null:
		return null
	var cooldown_variant: Variant = cooldown_script.new()
	assert_not_null(cooldown_variant, "Expected RS_BTCooldown.new() to succeed")
	if cooldown_variant == null:
		return null
	var cooldown: Resource = cooldown_variant as Resource
	cooldown.set("duration", duration)
	return cooldown

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func test_cooldown_script_exists_and_loads() -> void:
	var cooldown_script: Script = _load_script(RS_BT_COOLDOWN_PATH)
	assert_not_null(cooldown_script, "RS_BTCooldown script must exist and load")

func test_cooldown_blocks_for_duration_after_success() -> void:
	var cooldown: Resource = _new_cooldown(1.0)
	if cooldown == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	cooldown.set("child", child)

	var state_bag: Dictionary = {}
	var first_status: Variant = cooldown.call("tick", {"time": 0.0}, state_bag)
	assert_eq(first_status, _status("SUCCESS"), "First execution should run child")
	assert_eq(child.get("tick_count"), 1, "Child should run once on initial execution")

	var blocked_status: Variant = cooldown.call("tick", {"time": 0.25}, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "Cooldown should block while active")
	assert_eq(child.get("tick_count"), 1, "Child should not tick while cooldown is active")

	var resumed_status: Variant = cooldown.call("tick", {"time": 1.25}, state_bag)
	assert_eq(resumed_status, _status("SUCCESS"), "Cooldown should allow execution after duration")
	assert_eq(child.get("tick_count"), 2, "Child should tick again once cooldown expires")

func test_cooldown_starts_only_after_child_success() -> void:
	var cooldown: Resource = _new_cooldown(1.0)
	if cooldown == null:
		return
	var child: Resource = _new_status_node(_status("RUNNING"))
	if child == null:
		return
	cooldown.set("child", child)

	var state_bag: Dictionary = {}
	var first_status: Variant = cooldown.call("tick", {"time": 0.0}, state_bag)
	assert_eq(first_status, _status("RUNNING"), "Cooldown should pass through RUNNING children")

	var second_status: Variant = cooldown.call("tick", {"time": 0.25}, state_bag)
	assert_eq(second_status, _status("RUNNING"), "Cooldown should not block while child remains RUNNING")

	child.set("fixed_status", _status("SUCCESS"))
	var success_status: Variant = cooldown.call("tick", {"time": 0.5}, state_bag)
	assert_eq(success_status, _status("SUCCESS"), "Cooldown should pass through child SUCCESS")

	var blocked_status: Variant = cooldown.call("tick", {"time": 0.75}, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "Cooldown should begin blocking after child SUCCESS")
