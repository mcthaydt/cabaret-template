extends BaseTest

const S_AI_DETECTION_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_detection_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

class FakeBody extends CharacterBody3D:
	pass

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

func _create_entity(root: Node3D, name: String, position: Vector3) -> Dictionary:
	var entity := Node3D.new()
	entity.name = name
	root.add_child(entity)
	autofree(entity)

	var body := FakeBody.new()
	entity.add_child(body)
	autofree(body)
	body.global_position = position

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)

	return {
		"entity": entity,
		"body": body,
		"movement": movement,
	}

func _create_fixture() -> Dictionary:
	var system_script: Script = _load_script(S_AI_DETECTION_SYSTEM_PATH)
	if system_script == null:
		return {}

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AIDetectionSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	system.ecs_manager = ecs_manager
	system.state_store = store
	root.add_child(system)
	autofree(system)
	system.configure(ecs_manager)

	var player_data: Dictionary = _create_entity(root, "E_Player", Vector3.ZERO)
	var player_entity: Node3D = player_data.get("entity") as Node3D
	var player_movement: C_MovementComponent = player_data.get("movement") as C_MovementComponent
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_movement)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	var npc_data: Dictionary = _create_entity(root, "E_NPC", Vector3(20.0, 0.0, 0.0))
	var npc_entity: Node3D = npc_data.get("entity") as Node3D
	var npc_movement: C_MovementComponent = npc_data.get("movement") as C_MovementComponent
	var detection: Variant = C_DETECTION_COMPONENT.new()
	detection.ai_flag_id = StringName("power_core_proximity")
	detection.detection_radius = 6.0
	npc_entity.add_child(detection)
	autofree(detection)
	ecs_manager.add_component_to_entity(npc_entity, npc_movement)
	ecs_manager.add_component_to_entity(npc_entity, detection)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"store": store,
		"player": player_data,
		"npc": npc_data,
		"detection": detection,
	}

func test_system_extends_base_ecs_system() -> void:
	var system_script: Script = _load_script(S_AI_DETECTION_SYSTEM_PATH)
	if system_script == null:
		return
	var instance_variant: Variant = system_script.new()
	if instance_variant is Node:
		autofree(instance_variant as Node)
	assert_true(instance_variant is BASE_ECS_SYSTEM, "S_AIDetectionSystem should extend BaseECSSystem")

func test_enters_range_dispatches_ai_flag_once() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var store: MockStateStore = fixture["store"] as MockStateStore
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]

	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	system.process_tick(0.016)
	system.process_tick(0.016)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Expected one enter dispatch only")
	assert_true(detection.is_player_in_range)
	assert_eq(actions[0].get("type", StringName("")), U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG)
	var payload: Dictionary = actions[0].get("payload", {})
	assert_eq(payload.get("flag_id", StringName("")), StringName("power_core_proximity"))
	assert_eq(payload.get("value", false), true)

func test_exit_dispatches_false_when_enabled() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var store: MockStateStore = fixture["store"] as MockStateStore
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]

	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range)

	npc_body.global_position = Vector3(20.0, 0.0, 0.0)
	system.process_tick(0.016)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 2)
	var exit_payload: Dictionary = actions[1].get("payload", {})
	assert_eq(exit_payload.get("flag_id", StringName("")), StringName("power_core_proximity"))
	assert_eq(exit_payload.get("value", true), false)
	assert_false(detection.is_player_in_range)

func test_enter_event_publishes_once() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]
	detection.enter_event_name = StringName("ai_player_spotted")
	detection.enter_event_payload = {"source": StringName("npc")}

	var received_events: Array = []
	var unsubscribe: Callable = U_ECS_EVENT_BUS.subscribe(StringName("ai_player_spotted"), func(payload: Variant) -> void:
		received_events.append(payload)
	)

	npc_body.global_position = Vector3(2.0, 0.0, 0.0)
	system.process_tick(0.016)
	system.process_tick(0.016)

	assert_eq(received_events.size(), 1, "Expected one enter event only")
	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

func test_no_players_keeps_detection_false() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var store: MockStateStore = fixture["store"] as MockStateStore
	var ecs_manager: MockECSManager = fixture["ecs_manager"] as MockECSManager
	var detection: Variant = fixture["detection"]

	ecs_manager.clear_all_components()
	system.process_tick(0.016)

	assert_false(detection.is_player_in_range)
	assert_eq(store.get_dispatched_actions().size(), 0)

func test_hysteresis_does_not_exit_at_detection_radius() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]
	detection.detection_radius = 6.0
	detection.detection_exit_radius = 10.0

	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should enter detection at detection_radius")

	npc_body.global_position = Vector3(8.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should stay in range between detection_radius and exit_radius")

func test_hysteresis_exits_past_exit_radius() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]
	detection.detection_radius = 6.0
	detection.detection_exit_radius = 10.0

	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should enter detection")

	npc_body.global_position = Vector3(11.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_false(detection.is_player_in_range, "Should exit past exit_radius")

func test_hysteresis_default_exit_radius_equals_detection_radius() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: Variant = fixture["detection"]
	detection.detection_radius = 6.0
	detection.detection_exit_radius = 0.0

	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should enter detection")

	npc_body.global_position = Vector3(7.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_false(detection.is_player_in_range, "With no exit hysteresis, should exit immediately past detection_radius")
