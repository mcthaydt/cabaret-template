extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"
const RS_BT_INVERTER_PATH := "res://scripts/resources/bt/rs_bt_inverter.gd"
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

func _new_inverter() -> Resource:
	var inverter_script: Script = _load_script(RS_BT_INVERTER_PATH)
	if inverter_script == null:
		return null
	var inverter_variant: Variant = inverter_script.new()
	assert_not_null(inverter_variant, "Expected RS_BTInverter.new() to succeed")
	if inverter_variant == null:
		return null
	return inverter_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func test_inverter_script_exists_and_loads() -> void:
	var inverter_script: Script = _load_script(RS_BT_INVERTER_PATH)
	assert_not_null(inverter_script, "RS_BTInverter script must exist and load")

func test_inverter_flips_success_to_failure() -> void:
	var inverter: Resource = _new_inverter()
	if inverter == null:
		return
	var child: Resource = _new_status_node(_status("SUCCESS"))
	if child == null:
		return
	inverter.set("child", child)

	var status: Variant = inverter.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Inverter should flip SUCCESS to FAILURE")
	assert_eq(child.get("tick_count"), 1, "Child should be ticked once")

func test_inverter_flips_failure_to_success() -> void:
	var inverter: Resource = _new_inverter()
	if inverter == null:
		return
	var child: Resource = _new_status_node(_status("FAILURE"))
	if child == null:
		return
	inverter.set("child", child)

	var status: Variant = inverter.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Inverter should flip FAILURE to SUCCESS")
	assert_eq(child.get("tick_count"), 1, "Child should be ticked once")

func test_inverter_passes_through_running() -> void:
	var inverter: Resource = _new_inverter()
	if inverter == null:
		return
	var child: Resource = _new_status_node(_status("RUNNING"))
	if child == null:
		return
	inverter.set("child", child)

	var status: Variant = inverter.call("tick", {}, {})
	assert_eq(status, _status("RUNNING"), "Inverter should pass through RUNNING status")
	assert_eq(child.get("tick_count"), 1, "Child should be ticked once")
