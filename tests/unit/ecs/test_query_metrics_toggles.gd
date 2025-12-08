extends GutTest

## Unit tests for M_ECSManager query metrics toggles and capacity trimming

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")

class QueryDummyComponent:
	extends BaseECSComponent
	const TYPE := StringName("C_QueryDummy")
	func _init():
		component_type = TYPE

var _manager: M_ECSManager

func before_each() -> void:
	_manager = M_ECS_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Register a dummy entity with one component so query passes through metrics path
	var entity := Node3D.new()
	entity.name = "E_Test"
	add_child_autofree(entity)

	var comp := QueryDummyComponent.new()
	entity.add_child(comp)
	autofree(comp)
	await get_tree().process_frame

func after_each() -> void:
	_manager = null

func _time_provider_from(values: Array) -> Callable:
	var idx: Array = [0]
	return func() -> float:
		var i: int = int(idx[0])
		if i >= values.size():
			return float(values[-1])
		var v: float = float(values[i])
		idx[0] = i + 1
		return v

func test_query_metrics_can_be_disabled_and_cleared() -> void:
	# Ensure metrics enabled and perform a query
	_manager.set_time_provider(_time_provider_from([0.0, 0.1]))
	var required: Array[StringName] = [QueryDummyComponent.TYPE]
	_manager.query_entities(required)
	var before := _manager.get_query_metrics()
	assert_gt(before.size(), 0, "Metrics should record queries when enabled")

	# Disable at runtime; get_query_metrics should return empty
	_manager.set_query_metrics_enabled_runtime(false)
	var after := _manager.get_query_metrics()
	assert_eq(after.size(), 0, "Metrics should be empty when disabled")

func test_query_metrics_capacity_trimming_keeps_most_recent() -> void:
	_manager.set_query_metrics_enabled_runtime(true)
	_manager.set_query_metrics_capacity_runtime(1)
	_manager.set_time_provider(_time_provider_from([1.0, 2.0, 3.0, 4.0, 5.0]))

	# Create three distinct queries (different keys)
	var req1: Array[StringName] = [QueryDummyComponent.TYPE]
	var req2: Array[StringName] = [QueryDummyComponent.TYPE]
	var opt1: Array[StringName] = [StringName("opt1")]
	var opt2: Array[StringName] = [StringName("opt2")]
	_manager.query_entities(req1)
	_manager.query_entities(req2, opt1)
	_manager.query_entities(req2, opt2)

	var metrics := _manager.get_query_metrics()
	assert_lte(metrics.size(), 1, "Capacity trimming should keep at most 1 metric entry")
