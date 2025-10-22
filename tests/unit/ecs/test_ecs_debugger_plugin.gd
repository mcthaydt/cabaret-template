extends BaseTest

const PANEL_PATH := "res://addons/ecs_debugger/t_ecs_debugger_panel.gd"
const PLUGIN_PATH := "res://addons/ecs_debugger/p_ecs_debugger_plugin.gd"
const M_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")

class StubDataSource:
	var _queries: Array
	var _events: Array
	var _systems: Array
	var serialized_payload: String = "[]"

	func _init(queries: Array, events: Array, systems: Array) -> void:
		_queries = queries
		_events = events
		_systems = systems

	func get_query_metrics(manager: M_ECSManager) -> Array:
		return _queries

	func get_event_history() -> Array:
		return _events

	func get_system_overview(manager: M_ECSManager) -> Array:
		return _systems

	func serialize_event_history(events: Array) -> String:
		return serialized_payload

class StubSystem extends ECS_SYSTEM:
	var toggled_states: Array = []

	func _init(instance_id_value: int, enabled: bool) -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
		_debug_disabled = not enabled
		set_meta("instance_id_override", instance_id_value)

	func get_instance_id() -> int:
		return int(get_meta("instance_id_override"))

	func set_debug_disabled(disabled: bool) -> void:
		toggled_states.append(disabled)
		_debug_disabled = disabled

class StubManager extends M_MANAGER:
	var _systems_override: Array = []

	func _init(systems: Array) -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
		_systems_override = systems

	func get_systems() -> Array:
		return _systems_override.duplicate()

func _await_ready(node: Node) -> void:
	add_child(node)
	autofree(node)
	await get_tree().process_frame

func test_query_tab_populates_tree_with_metrics() -> void:
	var panel_script := load(PANEL_PATH)
	assert_not_null(panel_script, "Panel script must exist for testing.")
	var panel: Node = panel_script.new()
	var queries := [
		{
			"id": "req:C_MovementComponent|opt:",
			"required": [StringName("C_MovementComponent")],
			"optional": [],
			"total_calls": 3,
			"cache_hits": 1,
			"cache_hit_rate": 1.0 / 3.0,
			"last_duration": 0.002,
			"last_result_count": 5,
		},
	]
	var data_source: StubDataSource = StubDataSource.new(queries, [], [])
	if panel.has_method("set_data_source"):
		panel.set_data_source(data_source)
	await _await_ready(panel)

	if panel.has_method("refresh_with_manager"):
		panel.refresh_with_manager(null)

	if panel.has_method("get_query_tree"):
		var tree: Tree = panel.get_query_tree()
		assert_not_null(tree)
		var root := tree.get_root()
		assert_not_null(root)
		assert_eq(root.get_child_count(), 1)
		var item := root.get_child(0)
		assert_eq(item.get_text(1), "3")
		assert_eq(item.get_text(2), "1")
	else:
		fail_test("Panel must expose get_query_tree() for inspection.")

func test_toggling_system_updates_underlying_instance() -> void:
	var panel_script := load(PANEL_PATH)
	assert_not_null(panel_script)

	var system := StubSystem.new(42, true)
	autofree(system)
	var manager := StubManager.new([system])
	autofree(manager)
	var overview := [
		{
			"name": "S_TestSystem",
			"class": "S_TestSystem",
			"script": "res://scripts/ecs/systems/s_test_system.gd",
			"priority": 50,
			"instance_id": 42,
			"enabled": true,
		},
	]
	var data_source: StubDataSource = StubDataSource.new([], [], overview)

	var panel: Node = panel_script.new()
	if panel.has_method("set_data_source"):
		panel.set_data_source(data_source)
	await _await_ready(panel)

	if panel.has_method("refresh_with_manager"):
		panel.refresh_with_manager(manager)

	if panel.has_method("toggle_system_by_instance"):
		panel.toggle_system_by_instance(manager, 42, false)
		assert_eq(system.toggled_states.size(), 1)
		assert_true(system.toggled_states[0])
	else:
		fail_test("Panel must expose toggle_system_by_instance(manager, id, enabled) for testing.")

func test_plugin_creates_panel_with_default_data_source() -> void:
	var plugin_script := load(PLUGIN_PATH)
	assert_not_null(plugin_script, "Plugin script must exist for testing.")

	assert_true(plugin_script.has_method("create_panel_for_tests"))
	var panel: Node = plugin_script.call("create_panel_for_tests", null)
	assert_not_null(panel)
	assert_true(panel.has_method("get_data_source"))
	var data_source: Object = panel.get_data_source()
	assert_not_null(data_source)
	var script: Script = data_source.get_script()
	assert_not_null(script)
	assert_eq(script.resource_path, "res://scripts/utils/u_ecs_debug_data_source.gd")
	panel.free()
