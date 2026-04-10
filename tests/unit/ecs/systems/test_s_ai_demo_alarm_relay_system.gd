extends BaseTest

const S_AI_DEMO_ALARM_RELAY_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_demo_alarm_relay_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture() -> Dictionary:
	var system_script: Script = _load_script(S_AI_DEMO_ALARM_RELAY_SYSTEM_PATH)
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AIDemoAlarmRelaySystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	system.ecs_manager = ecs_manager
	system.state_store = store
	var relay_flags: Array[StringName] = [
		StringName("power_core_activated"),
		StringName("power_core_proximity"),
		StringName("comms_disturbance_heard"),
		StringName("comms_disturbance_proximity"),
	]
	system.relay_flag_ids = relay_flags
	add_child_autofree(system)
	system.configure(ecs_manager)

	return {
		"system": system,
		"store": store,
	}

func test_system_extends_base_ecs_system() -> void:
	var system_script: Script = _load_script(S_AI_DEMO_ALARM_RELAY_SYSTEM_PATH)
	if system_script == null:
		return
	var instance_variant: Variant = system_script.new()
	if instance_variant is Node:
		autofree(instance_variant as Node)
	assert_true(instance_variant is BASE_ECS_SYSTEM, "S_AIDemoAlarmRelaySystem should extend BaseECSSystem")

func test_alarm_event_dispatches_configured_flags() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var store: MockStateStore = fixture["store"] as MockStateStore
	U_ECS_EVENT_BUS.publish(StringName("ai_alarm_triggered"), {"source_entity_id": StringName("sentry")})

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 4)
	assert_eq(actions[0].get("type", StringName("")), U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG)
	assert_eq(actions[1].get("type", StringName("")), U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG)
	assert_eq(actions[2].get("type", StringName("")), U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG)
	assert_eq(actions[3].get("type", StringName("")), U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG)
	var flag_ids: Array[StringName] = [
		actions[0].get("payload", {}).get("flag_id", StringName("")),
		actions[1].get("payload", {}).get("flag_id", StringName("")),
		actions[2].get("payload", {}).get("flag_id", StringName("")),
		actions[3].get("payload", {}).get("flag_id", StringName("")),
	]
	assert_true(flag_ids.has(StringName("power_core_activated")), "Should dispatch power_core_activated")
	assert_true(flag_ids.has(StringName("power_core_proximity")), "Should dispatch power_core_proximity")
	assert_true(flag_ids.has(StringName("comms_disturbance_heard")), "Should dispatch comms_disturbance_heard")
	assert_true(flag_ids.has(StringName("comms_disturbance_proximity")), "Should dispatch comms_disturbance_proximity")

func test_empty_flag_ids_are_ignored() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var store: MockStateStore = fixture["store"] as MockStateStore
	var relay_flags: Array[StringName] = [StringName(""), StringName("power_core_activated")]
	system.relay_flag_ids = relay_flags

	U_ECS_EVENT_BUS.publish(StringName("ai_alarm_triggered"), {})

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	assert_eq(actions[0].get("payload", {}).get("flag_id", StringName("")), StringName("power_core_activated"))
