extends GutTest

const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"
const RS_BT_SELECTOR_PATH := "res://scripts/core/resources/bt/rs_bt_selector.gd"
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

func _new_selector() -> Resource:
	var selector_script: Script = _load_script(RS_BT_SELECTOR_PATH)
	if selector_script == null:
		return null
	var selector_variant: Variant = selector_script.new()
	assert_not_null(selector_variant, "Expected RS_BTSelector.new() to succeed")
	if selector_variant == null:
		return null
	return selector_variant as Resource

func _new_status_node(status: int) -> Resource:
	var node_script: Script = _load_script(TEST_STATUS_NODE_PATH)
	if node_script == null:
		return null
	var node_variant: Variant = node_script.new(status)
	assert_not_null(node_variant, "Expected status stub node to instantiate")
	if node_variant == null:
		return null
	return node_variant as Resource

func _set_children_for_test(selector: Resource, child_nodes: Array) -> void:
	var coerced_children: Variant = selector.call("_coerce_children", child_nodes)
	selector.set("_children", coerced_children)

func test_selector_script_exists_and_loads() -> void:
	var selector_script: Script = _load_script(RS_BT_SELECTOR_PATH)
	assert_not_null(selector_script, "RS_BTSelector script must exist and load")

func test_selector_without_children_returns_failure() -> void:
	var selector: Resource = _new_selector()
	if selector == null:
		return
	_set_children_for_test(selector, [])
	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Empty selector should return FAILURE")

func test_selector_returns_success_and_short_circuits() -> void:
	var selector: Resource = _new_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("SUCCESS"))
	var second: Resource = _new_status_node(_status("FAILURE"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("SUCCESS"), "Selector should return SUCCESS on first successful child")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked once")
	assert_eq(second.get("tick_count"), 0, "Selector should not tick later children after success")

func test_selector_returns_running_and_stops_after_running_child() -> void:
	var selector: Resource = _new_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("FAILURE"))
	var second: Resource = _new_status_node(_status("RUNNING"))
	var third: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null or third == null:
		return
	_set_children_for_test(selector, [first, second, third])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("RUNNING"), "Selector should return RUNNING on first running child")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked")
	assert_eq(second.get("tick_count"), 1, "Second child should be ticked")
	assert_eq(third.get("tick_count"), 0, "Selector should stop before ticking later children")

func test_selector_all_failures_returns_failure() -> void:
	var selector: Resource = _new_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("FAILURE"))
	var second: Resource = _new_status_node(_status("FAILURE"))
	if first == null or second == null:
		return
	_set_children_for_test(selector, [first, second])

	var status: Variant = selector.call("tick", {}, {})
	assert_eq(status, _status("FAILURE"), "Selector should return FAILURE when all children fail")
	assert_eq(first.get("tick_count"), 1, "First child should be ticked")
	assert_eq(second.get("tick_count"), 1, "Second child should be ticked")

func test_selector_reenters_running_child_on_next_tick() -> void:
	var selector: Resource = _new_selector()
	if selector == null:
		return
	var first: Resource = _new_status_node(_status("FAILURE"))
	var second: Resource = _new_status_node(_status("RUNNING"))
	var third: Resource = _new_status_node(_status("SUCCESS"))
	if first == null or second == null or third == null:
		return
	_set_children_for_test(selector, [first, second, third])

	var state_bag := {}
	var first_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(first_tick, _status("RUNNING"), "First tick should return RUNNING")

	second.set("fixed_status", _status("SUCCESS"))
	var second_tick: Variant = selector.call("tick", {}, state_bag)
	assert_eq(second_tick, _status("SUCCESS"), "Second tick should resume running child and return SUCCESS")
	assert_eq(first.get("tick_count"), 1, "First child should not be re-ticked while resuming running child")
	assert_eq(second.get("tick_count"), 2, "Running child should be re-ticked on next frame")
	assert_eq(third.get("tick_count"), 0, "Later children should not be ticked after resumed success")
