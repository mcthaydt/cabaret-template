extends GutTest

const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_status_enum_has_running_success_failure_only() -> void:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return

	assert_eq(
		node_script.get("Status").size(),
		3,
		"RS_BTNode.Status should expose exactly RUNNING, SUCCESS, FAILURE"
	)
	assert_eq(node_script.get("Status").get("RUNNING"), 0, "RUNNING should be enum value 0")
	assert_eq(node_script.get("Status").get("SUCCESS"), 1, "SUCCESS should be enum value 1")
	assert_eq(node_script.get("Status").get("FAILURE"), 2, "FAILURE should be enum value 2")

func test_tick_base_stub_pushes_error_and_returns_failure() -> void:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return

	var node_variant: Variant = node_script.new()
	assert_not_null(node_variant, "Expected RS_BTNode.new() to succeed")
	if node_variant == null:
		return

	var node: Resource = node_variant as Resource
	var status: Variant = node.call("tick", {}, {})
	assert_push_error("RS_BTNode.tick: not implemented")
	assert_eq(status, node_script.get("Status").get("FAILURE"), "Base tick should return FAILURE")

func test_node_id_is_stable_per_instance_and_unique_across_instances() -> void:
	var node_script: Script = _load_script(RS_BT_NODE_PATH)
	if node_script == null:
		return

	var first_node_variant: Variant = node_script.new()
	var second_node_variant: Variant = node_script.new()
	assert_not_null(first_node_variant)
	assert_not_null(second_node_variant)
	if first_node_variant == null or second_node_variant == null:
		return

	var first_node: Resource = first_node_variant as Resource
	var second_node: Resource = second_node_variant as Resource

	var first_id_initial: Variant = first_node.get("node_id")
	var first_id_again: Variant = first_node.get("node_id")
	var second_id: Variant = second_node.get("node_id")

	assert_true(first_id_initial is int, "node_id should be an int")
	assert_eq(first_id_initial, first_id_again, "node_id should stay stable for one instance")
	assert_ne(first_id_initial, second_id, "node_id should differ across instances")
