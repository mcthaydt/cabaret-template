extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")
const DEBUG_DATA := preload("res://scripts/utils/u_ecs_debug_data_source.gd")
const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")

class DebugMovementComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_DebugMovementComponent")

	func _init() -> void:
		component_type = TYPE

class DebugInputComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_DebugInputComponent")

	func _init() -> void:
		component_type = TYPE

class DebugSystem extends ECS_SYSTEM:
	var tick_count: int = 0

	func process_tick(_delta: float) -> void:
		tick_count += 1

func before_each() -> void:
	EVENT_BUS.reset()

func test_get_query_metrics_formats_manager_snapshot() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	manager.set_time_provider(_create_time_provider([
		1.0, 1.1, 2.0,
	]))

	_spawn_entity(manager, true, true)

	var required: Array[StringName] = [
		DebugMovementComponent.TYPE,
		DebugInputComponent.TYPE,
	]

	var first: Array = manager.query_entities(required)
	assert_eq(first.size(), 1)

	var second: Array = manager.query_entities(required)
	assert_eq(second.size(), 1)

	var metrics: Array = DEBUG_DATA.get_query_metrics(manager)
	assert_eq(metrics.size(), 1)

	var entry: Dictionary = metrics[0]
	assert_eq(entry["total_calls"], 2)
	assert_eq(entry["cache_hits"], 1)
	assert_almost_eq(entry["cache_hit_rate"], 0.5, 0.0001)
	assert_eq(entry["last_result_count"], 1)

func test_get_system_overview_reflects_debug_disabled_state() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var system := DebugSystem.new()
	autofree(system)
	system.execution_priority = 50
	manager.register_system(system)

	var overview: Array = DEBUG_DATA.get_system_overview(manager)
	assert_eq(overview.size(), 1)

	var entry: Dictionary = overview[0]
	assert_eq(entry["priority"], 50)
	assert_true(entry["enabled"])

	system.set_debug_disabled(true)

	var updated: Array = DEBUG_DATA.get_system_overview(manager)
	assert_eq(updated.size(), 1)
	assert_false(updated[0]["enabled"])

func test_get_event_history_returns_deep_copy() -> void:
	var payload := {"value": 42}
	EVENT_BUS.publish(StringName("debug_event"), payload)

	var history: Array = DEBUG_DATA.get_event_history()
	assert_eq(history.size(), 1)
	assert_eq(history[0]["payload"]["value"], 42)

	history[0]["payload"]["value"] = 100

	var second_history: Array = DEBUG_DATA.get_event_history()
	assert_eq(second_history[0]["payload"]["value"], 42)

func test_serialize_event_history_returns_json() -> void:
	var events: Array = [
		{
			"name": StringName("debug_event"),
			"payload": {"value": 12},
			"timestamp": 1.0,
		},
	]

	var json := DEBUG_DATA.serialize_event_history(events)
	assert_true(json.find("\"debug_event\"") != -1)

	var parsed : Variant = JSON.parse_string(json)
	assert_true(parsed is Array)
	assert_eq((parsed as Array).size(), 1)

func test_build_snapshot_combines_sections() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var system := DebugSystem.new()
	autofree(system)
	manager.register_system(system)

	var snapshot: Dictionary = DEBUG_DATA.build_snapshot(manager)
	assert_true(snapshot.has("queries"))
	assert_true(snapshot.has("events"))
	assert_true(snapshot.has("systems"))

func _spawn_entity(
	manager: M_ECSManager,
	include_movement: bool,
	include_input: bool
) -> void:
	var entity := Node.new()
	entity.name = "E_DebugEntity"
	add_child(entity)
	autofree(entity)

	if include_movement:
		var movement := DebugMovementComponent.new()
		entity.add_child(movement)
		autofree(movement)
		manager.register_component(movement)

	if include_input:
		var input := DebugInputComponent.new()
		entity.add_child(input)
		autofree(input)
		manager.register_component(input)

func _create_time_provider(sequence: Array) -> Callable:
	var remaining: Array = sequence.duplicate()
	var last_value := 0.0
	return func() -> float:
		if remaining.is_empty():
			return last_value
		last_value = float(remaining.pop_front())
		return last_value
