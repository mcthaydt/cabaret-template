extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const PLAYER_SCENE := preload("res://scenes/prefabs/prefab_player.tscn")
const BASE_SCENE := preload("res://scenes/templates/tmpl_base_scene.tscn")

class FakeComponent extends BaseECSComponent:
	const TYPE := StringName("C_FakeComponent")

	func _init():
		component_type = TYPE

	func get_snapshot() -> Dictionary:
		return {"id": 42}

class FakeSystem extends BaseECSSystem:
	var observed_components: Array = []

	func process_tick(_delta: float) -> void:
		observed_components = get_components(FakeComponent.TYPE)

class PrioritySystem extends BaseECSSystem:
	var label: String = ""
	var log: Array = []

	func configure_for_test(name: String, priority: int, target_log: Array) -> void:
		label = name
		execution_priority = priority
		log = target_log

	func process_tick(_delta: float) -> void:
		if log == null:
			return
		log.append(label)

class DebugToggleSystem extends BaseECSSystem:
	var tick_count: int = 0

	func process_tick(_delta: float) -> void:
		tick_count += 1

class QueryMovementComponent extends BaseECSComponent:
	const TYPE := StringName("C_QueryMovementComponent")

	func _init() -> void:
		component_type = TYPE

class QueryInputComponent extends BaseECSComponent:
	const TYPE := StringName("C_QueryInputComponent")

	func _init() -> void:
		component_type = TYPE

class QueryFloatingComponent extends BaseECSComponent:
	const TYPE := StringName("C_QueryFloatingComponent")

	func _init() -> void:
		component_type = TYPE

var _expected_component
var _expected_manager
var _added_calls := 0
var _registered_calls := 0
var _state_store: M_StateStore = null

func before_each() -> void:
	# Create and add M_StateStore for tests that use BASE_SCENE
	_state_store = M_StateStore.new()
	add_child(_state_store)
	autofree(_state_store)
	await get_tree().process_frame
	# Register state_store with ServiceLocator so scenes can find it
	U_ServiceLocator.register(StringName("state_store"), _state_store)

	# Provide HUDLayer for HUD reparenting in template scenes.
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)
	autofree(hud_layer)

func _on_component_added(component_type, received) -> void:
	_added_calls += 1
	assert_eq(component_type, FakeComponent.TYPE)
	assert_eq(received, _expected_component)

func _on_component_registered(received_manager, received_component) -> void:
	_registered_calls += 1
	assert_eq(received_manager, _expected_manager)
	assert_eq(received_component, _expected_component)

func test_component_auto_registers_with_manager_on_ready() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	entity.add_child(component)
	autofree(component)
	await get_tree().process_frame

	var components := manager.get_components(FakeComponent.TYPE)
	assert_eq(components, [component])

func test_system_auto_registers_with_manager_on_ready() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var system := FakeSystem.new()
	add_child(system)
	autofree(system)
	await get_tree().process_frame

	var systems: Array = manager.get_systems()
	assert_true(systems.has(system))
	assert_eq(system.get_manager(), manager)

func test_register_component_adds_to_lookup() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_ManualRegister"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	entity.add_child(component)
	autofree(component)
	manager.register_component(component)

	var components := manager.get_components(FakeComponent.TYPE)
	assert_not_null(components)
	assert_eq(components.size(), 1)
	assert_true(components.has(component))

func test_register_component_emits_signals() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_SignalEntity"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	entity.add_child(component)
	autofree(component)
	_expected_component = component
	_expected_manager = manager
	_added_calls = 0
	_registered_calls = 0

	assert_true(component.has_method("on_registered"))

	# Test manager signal
	var add_err: int = manager.component_added.connect(Callable(self, "_on_component_added"))
	assert_eq(add_err, OK)

	# Phase 7E: component.registered signal migrated to event bus
	# Subscribe to component_registered event
	U_ECSEventBus.reset()

	manager.register_component(component)

	assert_eq(_added_calls, 1)

	# Verify event bus published component_registered event
	var history := U_ECSEventBus.get_event_history()
	assert_true(history.any(func(event): return event.get("name") == StringName("component_registered")),
		"component_registered event should be published")

func test_register_system_configures_and_queries_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_SystemEntity"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	entity.add_child(component)
	autofree(component)
	manager.register_component(component)

	var system := FakeSystem.new()
	autofree(system)
	manager.register_system(system)

	manager._physics_process(0.016)

	assert_eq(system.observed_components, [component])

func test_systems_execute_in_execution_priority_order() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	var late_system := PrioritySystem.new()
	autofree(late_system)
	late_system.configure_for_test("late", 100, execution_log)

	var early_system := PrioritySystem.new()
	autofree(early_system)
	early_system.configure_for_test("early", 0, execution_log)

	var mid_system := PrioritySystem.new()
	autofree(mid_system)
	mid_system.configure_for_test("mid", 50, execution_log)

	manager.register_system(late_system)
	manager.register_system(early_system)
	manager.register_system(mid_system)

	manager._physics_process(0.016)

	assert_eq(execution_log, ["early", "mid", "late"])

func test_get_components_filters_null_entries() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_FilterEntity"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	entity.add_child(component)
	autofree(component)
	manager.register_component(component)

	# Inject a null entry to simulate improper cleanup
	var stored: Array = manager._components[FakeComponent.TYPE]
	stored.append(null)

	var result: Array = manager.get_components(FakeComponent.TYPE)
	assert_eq(result, [component])

	var cleaned: Array = manager._components.get(FakeComponent.TYPE, [])
	assert_eq(cleaned, [component])

func test_player_template_components_register_with_manager() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	autofree(player)
	await get_tree().process_frame

	var expected_types := [
		StringName("C_MovementComponent"),
		StringName("C_JumpComponent"),
		StringName("C_InputComponent"),
		StringName("C_RotateToInputComponent"),
	]

	for component_type in expected_types:
		var components := manager.get_components(component_type)
		assert_eq(components.size(), 1, "Expected component %s to auto-register" % component_type)

func test_base_scene_systems_register_with_manager() -> void:
	var scene := BASE_SCENE.instantiate()
	add_child(scene)
	autofree(scene)
	await get_tree().process_frame

	var manager: M_ECSManager = scene.get_node("Managers/M_ECSManager") as M_ECSManager
	assert_not_null(manager)

	var systems: Array = manager.get_systems()
	assert_true(systems.size() >= 1, "Expected systems to auto-register in base scene")

func test_register_component_tracks_entity_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	component.name = "C_FakeComponent"
	entity.add_child(component)
	autofree(component)

	manager.register_component(component)

	var tracked: Dictionary = manager.get_components_for_entity(entity)
	assert_true(tracked.has(FakeComponent.TYPE))
	assert_eq(tracked[FakeComponent.TYPE], component)

func test_unregister_component_removes_entity_tracking() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity := Node.new()
	entity.name = "E_Tracked"
	add_child(entity)
	autofree(entity)

	var component := FakeComponent.new()
	component.name = "C_FakeComponent"
	entity.add_child(component)
	autofree(component)

	manager.register_component(component)
	var tracked_before: Dictionary = manager.get_components_for_entity(entity)
	assert_true(tracked_before.has(FakeComponent.TYPE))

	manager.unregister_component(component)

	var tracked_after: Dictionary = manager.get_components_for_entity(entity)
	assert_false(tracked_after.has(FakeComponent.TYPE))
	assert_true(tracked_after.is_empty())

func test_register_component_without_entity_logs_error() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var container := Node.new()
	container.name = "Container"
	add_child(container)
	autofree(container)

	var component := FakeComponent.new()
	component.name = "C_FakeComponent"
	container.add_child(component)
	autofree(component)

	manager.register_component(component)
	assert_push_error("M_ECSManager: Component C_FakeComponent has no entity root ancestor")

	var tracked: Dictionary = manager.get_components_for_entity(container)
	assert_true(tracked.is_empty())

func _spawn_query_entity(
	manager: M_ECSManager,
	name: String,
	include_movement: bool,
	include_input: bool = false,
	include_floating: bool = false
) -> Dictionary:
	var entity := Node.new()
	entity.name = name
	add_child(entity)
	autofree(entity)

	var components: Dictionary = {}

	if include_movement:
		var movement := QueryMovementComponent.new()
		entity.add_child(movement)
		autofree(movement)
		manager.register_component(movement)
		components[QueryMovementComponent.TYPE] = movement

	if include_input:
		var input := QueryInputComponent.new()
		entity.add_child(input)
		autofree(input)
		manager.register_component(input)
		components[QueryInputComponent.TYPE] = input

	if include_floating:
		var floating := QueryFloatingComponent.new()
		entity.add_child(floating)
		autofree(floating)
		manager.register_component(floating)
		components[QueryFloatingComponent.TYPE] = floating

	return {
		"entity": entity,
		"components": components,
	}

func test_query_entities_with_single_required_component() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity_a := _spawn_query_entity(manager, "E_QuerySingleA", true)
	var entity_b := _spawn_query_entity(manager, "E_QuerySingleB", true, true)
	var entity_c := _spawn_query_entity(manager, "E_QuerySingleC", true, false, true)
	_spawn_query_entity(manager, "E_QuerySingleD", false, true)

	var results: Array = manager.query_entities([QueryMovementComponent.TYPE])
	assert_eq(results.size(), 3)

	var expected := {
		entity_a["entity"]: entity_a["components"][QueryMovementComponent.TYPE],
		entity_b["entity"]: entity_b["components"][QueryMovementComponent.TYPE],
		entity_c["entity"]: entity_c["components"][QueryMovementComponent.TYPE],
	}

	for query in results:
		var entity: Node = query.entity
		assert_true(expected.has(entity), "Unexpected entity returned from query")
		var movement: BaseECSComponent = query.get_component(QueryMovementComponent.TYPE)
		assert_eq(movement, expected[entity])
		expected.erase(entity)

	assert_true(expected.is_empty())

func test_query_entities_with_multiple_required_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity_a := _spawn_query_entity(manager, "E_QueryMultiA", true, true)
	_spawn_query_entity(manager, "E_QueryMultiB", true)
	var entity_c := _spawn_query_entity(manager, "E_QueryMultiC", true, true, true)

	var results: Array = manager.query_entities([
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	])

	assert_eq(results.size(), 2)

	var expected_entities := {
		entity_a["entity"]: true,
		entity_c["entity"]: true,
	}

	for query in results:
		var entity: Node = query.entity
		assert_true(expected_entities.has(entity))
		assert_not_null(query.get_component(QueryMovementComponent.TYPE))
		assert_not_null(query.get_component(QueryInputComponent.TYPE))
		assert_false(query.has_component(QueryFloatingComponent.TYPE))
		expected_entities.erase(entity)

	assert_true(expected_entities.is_empty())

func test_query_entities_with_optional_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity_a := _spawn_query_entity(manager, "E_QueryOptionalA", true, true)
	var entity_b := _spawn_query_entity(manager, "E_QueryOptionalB", true, true, true)

	var results: Array = manager.query_entities(
		[
			QueryMovementComponent.TYPE,
			QueryInputComponent.TYPE,
		],
		[
			QueryFloatingComponent.TYPE,
		]
	)

	assert_eq(results.size(), 2)

	var entities_with_optional: Array = []
	for query in results:
		assert_not_null(query.get_component(QueryMovementComponent.TYPE))
		assert_not_null(query.get_component(QueryInputComponent.TYPE))

		if query.has_component(QueryFloatingComponent.TYPE):
			entities_with_optional.append(query.entity)
			var expected_component: BaseECSComponent = entity_b["components"][QueryFloatingComponent.TYPE]
			assert_eq(query.get_component(QueryFloatingComponent.TYPE), expected_component)
		else:
			assert_eq(query.entity, entity_a["entity"])

	assert_eq(entities_with_optional.size(), 1)
	assert_true(entities_with_optional.has(entity_b["entity"]))

func test_query_entities_reuses_entity_queries_from_cache() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var entity_a := _spawn_query_entity(manager, "E_CacheA", true, true)

	var first: Array = manager.query_entities([
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	])
	var second: Array = manager.query_entities([
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	])

	assert_eq(first.size(), 1)
	assert_eq(second.size(), 1)
	assert_true(first[0] == second[0])

func test_query_entities_cache_invalidates_when_new_entity_registered() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	_spawn_query_entity(manager, "E_CacheInvalidateA", true, true)

	var initial: Array = manager.query_entities([
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	])
	assert_eq(initial.size(), 1)

	var entity_b := _spawn_query_entity(manager, "E_CacheInvalidateB", true, true)

	var subsequent: Array = manager.query_entities([
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	])

	assert_eq(subsequent.size(), 2)
	var found_new := false
	for query in subsequent:
		if query.entity == entity_b["entity"]:
			found_new = true
			break

	assert_true(found_new)

func test_query_metrics_capture_results_and_cache_hits() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var required: Array[StringName] = [
		QueryMovementComponent.TYPE,
		QueryInputComponent.TYPE,
	]

	manager.set_time_provider(_create_time_provider([
		1.0, 1.1, 2.0, 2.1,
	]))

	_spawn_query_entity(manager, "E_DebugMetrics", true, true)

	var first: Array = manager.query_entities(required)
	assert_eq(first.size(), 1)

	var second: Array = manager.query_entities(required)
	assert_eq(second.size(), 1)

	var metrics: Array = manager.get_query_metrics()
	assert_eq(metrics.size(), 1)

	var entry: Dictionary = metrics[0]
	var recorded_required: Array = entry["required"]
	recorded_required.sort()
	var expected_required: Array = required.duplicate()
	expected_required.sort()
	assert_eq(recorded_required, expected_required)

	var optional_components: Array = entry["optional"]
	assert_true(optional_components.is_empty())

	assert_eq(entry["total_calls"], 2)
	assert_eq(entry["cache_hits"], 1)
	assert_eq(entry["last_result_count"], 1)

	var last_duration: float = entry["last_duration"]
	assert_true(last_duration >= 0.0)

	var last_run_time: float = entry["last_run_time"]
	assert_true(last_run_time >= 2.0)

func test_debug_disabling_system_skips_process_tick() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var system := DebugToggleSystem.new()
	autofree(system)
	manager.register_system(system)

	manager._physics_process(0.016)
	assert_eq(system.tick_count, 1)

	system.set_debug_disabled(true)
	manager._physics_process(0.016)
	assert_eq(system.tick_count, 1)

	system.set_debug_disabled(false)
	manager._physics_process(0.016)
	assert_eq(system.tick_count, 2)

func _create_time_provider(sequence: Array) -> Callable:
	var remaining: Array = sequence.duplicate()
	var last_value := 0.0
	return func() -> float:
		if remaining.is_empty():
			return last_value
		last_value = float(remaining.pop_front())
		return last_value
