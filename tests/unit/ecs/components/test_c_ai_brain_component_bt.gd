extends BaseTest

const C_AI_BRAIN_COMPONENT_PATH := "res://scripts/ecs/components/c_ai_brain_component.gd"

func _load_component_script() -> Script:
	var script_variant: Variant = load(C_AI_BRAIN_COMPONENT_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % C_AI_BRAIN_COMPONENT_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_component() -> BaseECSComponent:
	var component_script: Script = _load_component_script()
	if component_script == null:
		return null
	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BaseECSComponent, "C_AIBrainComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return null
	var component: BaseECSComponent = component_variant as BaseECSComponent
	autofree(component)
	return component

func _has_property(object: Object, property_name: String) -> bool:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property: Dictionary = property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return true
	return false

func test_bt_state_bag_field_exists_and_defaults_to_empty_dictionary() -> void:
	var component: BaseECSComponent = _new_component()
	if component == null:
		return

	assert_true(
		_has_property(component, "bt_state_bag"),
		"C_AIBrainComponent should expose bt_state_bag for per-node BT runtime state."
	)
	var state_bag_variant: Variant = component.get("bt_state_bag")
	assert_true(state_bag_variant is Dictionary, "bt_state_bag should be a Dictionary.")
	if state_bag_variant is Dictionary:
		assert_eq((state_bag_variant as Dictionary).size(), 0, "bt_state_bag should default to an empty Dictionary.")

func test_get_debug_snapshot_reports_active_path_and_bt_state_key_count() -> void:
	var component: BaseECSComponent = _new_component()
	if component == null:
		return

	component.set("bt_state_bag", {
		101: {"running": true},
		202: {"running": false},
	})

	var snapshot_variant: Variant = component.call("get_debug_snapshot")
	assert_true(snapshot_variant is Dictionary, "get_debug_snapshot() should return a Dictionary.")
	if not (snapshot_variant is Dictionary):
		return

	var snapshot: Dictionary = snapshot_variant as Dictionary
	assert_true(snapshot.has("active_path"), "Debug snapshot should expose active_path for BT panel rendering.")
	assert_true(snapshot.has("bt_state_keys"), "Debug snapshot should expose bt_state_keys for BT-state observability.")

	var active_path_variant: Variant = snapshot.get("active_path", [])
	assert_true(active_path_variant is Array, "active_path should be an Array[String].")
	if active_path_variant is Array:
		var active_path: Array = active_path_variant as Array
		assert_eq(active_path.size(), 0, "Default active_path should be empty before runner integration.")

	assert_eq(int(snapshot.get("bt_state_keys", -1)), 2, "bt_state_keys should match bt_state_bag key count.")

func test_legacy_goal_task_runtime_fields_removed() -> void:
	var component: BaseECSComponent = _new_component()
	if component == null:
		return

	assert_false(
		_has_property(component, "current_task_queue"),
		"Legacy current_task_queue should be removed in BT brain component refactor."
	)
	assert_false(
		_has_property(component, "current_task_index"),
		"Legacy current_task_index should be removed in BT brain component refactor."
	)
	assert_false(
		_has_property(component, "task_state"),
		"Legacy task_state should be removed in BT brain component refactor."
	)
	assert_false(
		_has_property(component, "suspended_goal_state"),
		"Legacy suspended_goal_state should be removed in BT brain component refactor."
	)
