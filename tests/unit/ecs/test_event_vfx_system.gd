extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const EVENT_VFX_SYSTEM := preload("res://scripts/ecs/event_vfx_system.gd")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

const TEST_EVENT_NAME := StringName("test_event")

func before_each() -> void:
	EVENT_BUS.reset()

func _pump() -> void:
	await get_tree().process_frame

func _spawn_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

## Test concrete implementation of EventVFXSystem
class TestVFXSystem:
	extends BaseEventVFXSystem

	var event_name: StringName = StringName()
	var request_builder: Callable = Callable()

	func get_event_name() -> StringName:
		return event_name

	func create_request_from_payload(payload: Dictionary) -> Dictionary:
		if request_builder != Callable() and request_builder.is_valid():
			return request_builder.call(payload)
		return {"data": payload.get("value", "")}

# Base Class Tests

func test_system_extends_ecs_system() -> void:
	var system := TestVFXSystem.new()
	autofree(system)
	assert_true(system is BaseECSSystem, "EventVFXSystem should extend ECSSystem")

func test_get_event_name_returns_empty_in_base_class() -> void:
	var system := TestVFXSystem.new()
	system.event_name = StringName()  # Empty name
	autofree(system)
	var event_name := system.get_event_name()
	assert_eq(event_name, StringName(), "Should return empty StringName when not overridden")

func test_create_request_returns_empty_with_no_builder() -> void:
	var system := TestVFXSystem.new()
	system.request_builder = Callable()  # No builder
	autofree(system)
	var payload := {"test": "value"}
	var request := system.create_request_from_payload(payload)
	# Default implementation returns {"data": payload.get("value", "")}
	assert_eq(request.get("data"), "", "Should use default implementation")

# Event Subscription Tests

func test_system_subscribes_to_event_on_ready() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	# Publish event - system should receive it
	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 1, "System should queue request after event")

func test_system_unsubscribes_on_exit_tree() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	# Remove from tree
	system.get_parent().remove_child(system)

	# Publish event - should not be received
	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 0, "Removed system should not receive events")

# Request Queue Tests

func test_requests_array_is_initialized() -> void:
	var system := TestVFXSystem.new()
	autofree(system)
	assert_not_null(system.requests, "Requests array should be initialized")
	assert_eq(system.requests.size(), 0, "Requests should start empty")

func test_request_is_queued_when_event_published() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test_data"})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("data"), "test_data")

func test_multiple_requests_queued() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "first"})
	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "second"})
	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "third"})

	assert_eq(system.requests.size(), 3)
	assert_eq(system.requests[0].get("data"), "first")
	assert_eq(system.requests[1].get("data"), "second")
	assert_eq(system.requests[2].get("data"), "third")

# Payload Extraction Tests

func test_payload_extracted_from_event_data() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(payload: Dictionary) -> Dictionary:
		return {
			"extracted_value": payload.get("test_key"),
		}
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"test_key": "test_value"})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("extracted_value"), "test_value")

func test_timestamp_added_to_request() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 1)
	assert_true(system.requests[0].has("timestamp"), "Request should have timestamp")
	assert_true(system.requests[0]["timestamp"] is float, "Timestamp should be float")

func test_timestamp_not_overwritten_if_present() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(payload: Dictionary) -> Dictionary:
		return {"data": payload.get("value"), "timestamp": 999.0}
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("timestamp"), 999.0, "Custom timestamp should not be overwritten")

# Resubscription Tests

func test_subscribe_clears_existing_requests() -> void:
	var system := TestVFXSystem.new()
	system.event_name = TEST_EVENT_NAME
	autofree(system)

	# Manually add requests
	system.requests.append({"old": "data"})
	assert_eq(system.requests.size(), 1)

	# Resubscribe should clear
	system._subscribe()

	assert_eq(system.requests.size(), 0, "Subscribe should clear existing requests")
