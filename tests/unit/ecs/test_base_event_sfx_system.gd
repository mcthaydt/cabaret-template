extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const EVENT_SFX_SYSTEM := preload("res://scripts/ecs/base_event_sfx_system.gd")
const EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const SFX_SYSTEM_STUB := preload("res://tests/test_doubles/ecs/event_sfx_system_stub.gd")

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

func test_system_extends_ecs_system() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)
	assert_true(system is BaseECSSystem)

func test_requests_array_is_initialized() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)
	assert_not_null(system.requests)
	assert_eq(system.requests.size(), 0)

func test_get_event_name_in_base_class_pushes_error() -> void:
	var system := EVENT_SFX_SYSTEM.new()
	autofree(system)
	var event_name := system.get_event_name()
	assert_push_error("BaseEventSFXSystem: get_event_name()")
	assert_eq(event_name, StringName())

func test_create_request_from_payload_in_base_class_pushes_error() -> void:
	var system := EVENT_SFX_SYSTEM.new()
	autofree(system)
	var request := system.create_request_from_payload({})
	assert_push_error("BaseEventSFXSystem: create_request_from_payload()")
	assert_eq(request, {})

func test_system_subscribes_to_event_on_ready_and_queues_request() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("data"), "test")

func test_system_unsubscribes_on_exit_tree() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	manager.remove_child(system)

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 0)

func test_multiple_events_accumulate_requests() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
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

func test_event_payload_is_passed_to_request_builder() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(payload: Dictionary) -> Dictionary:
		return {"extracted": payload.get("test_key", "")}
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"test_key": "test_value"})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("extracted"), "test_value")

func test_empty_request_is_not_appended() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(_payload: Dictionary) -> Dictionary:
		return {}
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 0)

func test_subscribe_clears_existing_requests() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	autofree(system)

	system.requests.append({"old": "data"})
	assert_eq(system.requests.size(), 1)

	system._subscribe()

	assert_eq(system.requests.size(), 0)
	system._unsubscribe()

func test_unsubscribe_prevents_receiving_events() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	system._unsubscribe()
	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 0)

func test_empty_event_name_warns_and_does_not_subscribe() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = StringName()
	manager.add_child(system)
	autofree(system)
	await _pump()
	assert_engine_error("get_event_name() returned empty StringName")

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})
	assert_eq(system.requests.size(), 0)

func test_request_is_deep_copied() -> void:
	var manager := _spawn_manager()
	await _pump()

	var original_request := {"nested": {"value": 1}}

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(_payload: Dictionary) -> Dictionary:
		return original_request
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	original_request["nested"]["value"] = 2

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0]["nested"]["value"], 1)

func test_non_dictionary_payload_is_treated_as_empty_dictionary() -> void:
	var manager := _spawn_manager()
	await _pump()

	var received_payload: Dictionary = {}

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	system.request_builder = func(payload: Dictionary) -> Dictionary:
		received_payload = payload
		return {"ok": true}
	manager.add_child(system)
	autofree(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT_NAME, "not_a_dictionary")

	assert_eq(system.requests.size(), 1)
	assert_eq(received_payload, {})

func test_resubscribe_does_not_duplicate_callbacks() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := SFX_SYSTEM_STUB.new()
	system.event_name = TEST_EVENT_NAME
	manager.add_child(system)
	autofree(system)
	await _pump()

	system._subscribe()

	EVENT_BUS.publish(TEST_EVENT_NAME, {"value": "test"})

	assert_eq(system.requests.size(), 1)

## Phase 6: Helper Method Tests

func test_should_skip_processing_with_null_settings() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.settings = null
	autofree(system)

	assert_true(system._should_skip_processing())

func test_should_skip_processing_with_disabled_settings() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.settings = {"enabled": false}
	autofree(system)

	assert_true(system._should_skip_processing())

func test_should_skip_processing_with_null_stream() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.settings = {"enabled": true}
	autofree(system)

	# _get_audio_stream() returns null by default
	assert_true(system._should_skip_processing())

func test_should_skip_processing_returns_false_when_ready() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.settings = {"enabled": true}
	system.mock_audio_stream = AudioStreamGenerator.new()
	autofree(system)

	assert_false(system._should_skip_processing())

func test_should_skip_processing_clears_requests_on_skip() -> void:
	var system := SFX_SYSTEM_STUB.new()
	system.settings = null
	system.requests.append({"test": "data"})
	autofree(system)

	assert_true(system._should_skip_processing())
	assert_eq(system.requests.size(), 0)

func test_is_throttled_enforces_min_interval() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)

	var now: float = 10.0
	var min_interval: float = 2.0

	# First call should not be throttled (last_play_time = -INF)
	assert_false(system._is_throttled(min_interval, now))

	# Simulate playing sound
	system._last_play_time = now

	# Immediate retry should be throttled
	assert_true(system._is_throttled(min_interval, now + 0.5))

	# After min_interval, should not be throttled
	assert_false(system._is_throttled(min_interval, now + 2.1))

func test_calculate_pitch_clamps_variation() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)

	# Test clamping to 0.95 max
	var pitch := system._calculate_pitch(1.5)
	assert_between(pitch, 0.05, 1.95, "Clamped to 0.95: should be 1.0 +/- 0.95")

	# Test normal variation
	pitch = system._calculate_pitch(0.2)
	assert_between(pitch, 0.8, 1.2, "Normal variation: should be 1.0 +/- 0.2")

	# Test zero variation returns 1.0
	pitch = system._calculate_pitch(0.0)
	assert_eq(pitch, 1.0)

func test_extract_position_from_request() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)

	var request := {"position": Vector3(1.0, 2.0, 3.0)}
	var position := system._extract_position(request)
	assert_eq(position, Vector3(1.0, 2.0, 3.0))

func test_extract_position_returns_zero_when_missing() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)

	var request := {}
	var position := system._extract_position(request)
	assert_eq(position, Vector3.ZERO)

func test_extract_position_returns_zero_on_invalid_type() -> void:
	var system := SFX_SYSTEM_STUB.new()
	autofree(system)

	var request := {"position": "not a vector"}
	var position := system._extract_position(request)
	assert_eq(position, Vector3.ZERO)
