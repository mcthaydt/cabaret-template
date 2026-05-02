extends GutTest

const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_ONCE_PATH := "res://scripts/core/resources/bt/rs_bt_once.gd"
const TEST_STATUS_NODE_PATH := "res://tests/unit/ai/bt/helpers/test_bt_status_node.gd"

class BrainOnceResetStub extends RefCounted:
	var _state_bag_ref: Dictionary

	func _init(state_bag_ref: Dictionary) -> void:
		_state_bag_ref = state_bag_ref

	func reset_once_nodes() -> void:
		_state_bag_ref.clear()

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

func _new_once() -> Resource:
	var once_script: Script = _load_script(RS_BT_ONCE_PATH)
	if once_script == null:
		return null
	var once_variant: Variant = once_script.new()
	assert_not_null(once_variant, "Expected RS_BTOnce.new() to succeed")
	if once_variant == null:
		return null
	return once_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func test_once_script_exists_and_loads() -> void:
	var once_script: Script = _load_script(RS_BT_ONCE_PATH)
	assert_not_null(once_script, "RS_BTOnce script must exist and load")

func test_once_runs_child_once_then_blocks_subsequent_entries() -> void:
	var once: Resource = _new_once()
	if once == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	once.set("child", child)

	var state_bag: Dictionary = {}
	var first_status: Variant = once.call("tick", {}, state_bag)
	assert_eq(first_status, _status("SUCCESS"), "First entry should return child status")
	assert_eq(child.get("tick_count"), 1, "Child should run once on first entry")

	var blocked_status: Variant = once.call("tick", {}, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "Once should block after child has completed once")
	assert_eq(child.get("tick_count"), 1, "Child should not run after once lockout")

func test_once_allows_running_child_to_finish_before_locking() -> void:
	var once: Resource = _new_once()
	if once == null:
		return
	var child: Resource = _new_status_node(_status("RUNNING"))
	if child == null:
		return
	once.set("child", child)

	var state_bag: Dictionary = {}
	var running_status: Variant = once.call("tick", {}, state_bag)
	assert_eq(running_status, _status("RUNNING"), "Once should pass through RUNNING child status")
	assert_eq(child.get("tick_count"), 1, "Running child should tick on first frame")

	child.set("fixed_status", _status("SUCCESS"))
	var success_status: Variant = once.call("tick", {}, state_bag)
	assert_eq(success_status, _status("SUCCESS"), "Once should allow running child to complete")
	assert_eq(child.get("tick_count"), 2, "Running child should re-tick while active")

	var blocked_status: Variant = once.call("tick", {}, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "Once should block new entries after completion")
	assert_eq(child.get("tick_count"), 2, "Child should not re-enter once completion is locked")

func test_once_can_be_reset_via_context_brain_reset_once_nodes() -> void:
	var once: Resource = _new_once()
	if once == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	once.set("child", child)

	var state_bag: Dictionary = {}
	var brain_reset_stub: BrainOnceResetStub = BrainOnceResetStub.new(state_bag)
	var context := {
		"brain": brain_reset_stub,
	}

	var first_status: Variant = once.call("tick", context, state_bag)
	assert_eq(first_status, _status("SUCCESS"), "Once should execute child before reset")
	var blocked_status: Variant = once.call("tick", context, state_bag)
	assert_eq(blocked_status, _status("FAILURE"), "Once should block before reset")

	brain_reset_stub.reset_once_nodes()
	var reset_status: Variant = once.call("tick", context, state_bag)
	assert_eq(reset_status, _status("SUCCESS"), "Once should execute again after reset")
	assert_eq(child.get("tick_count"), 2, "Child should run again after reset")
