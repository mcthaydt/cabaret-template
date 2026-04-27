extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_behavior_system.gd"
const SENTRY_BT_BRAIN_PATH := "res://resources/demo/ai/sentry/cfg_sentry_brain_script.tres"

const BASE_ECS_SYSTEM := preload("res://scripts/core/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/core/utils/ai/u_ai_task_state_keys.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")

const RS_MOVEMENT_SETTINGS := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/core/resources/ai/brain/rs_ai_brain_settings.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"
const GUARD_TARGET_PATH := "../../Waypoints/WaypointGuardA"
const INVESTIGATE_TARGET_PATH := "../../NoiseSources/Inter_NoiseSourceA"

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _load_required_brain_settings(path: String) -> RS_AIBrainSettings:
	if not FileAccess.file_exists(path):
		assert_true(false, "Expected BT brain resource to exist: %s" % path)
		return null
	var brain_variant: Variant = load(path)
	assert_not_null(brain_variant, "Expected BT brain resource to exist: %s" % path)
	if brain_variant == null or not (brain_variant is RS_AIBrainSettings):
		return null
	var brain_settings: RS_AIBrainSettings = brain_variant as RS_AIBrainSettings
	assert_not_null(brain_settings.get_root(), "Expected BT brain to define a root node.")
	return brain_settings

func _set_demo_flags(store: MockStateStore, flags: Dictionary) -> void:
	var gameplay: Dictionary = {"ai_demo_flags": flags.duplicate(true)}
	store.set_slice(StringName("gameplay"), gameplay)

func _create_waypoint(parent: Node3D, waypoint_name: String, position: Vector3) -> void:
	var waypoint := Node3D.new()
	waypoint.name = waypoint_name
	parent.add_child(waypoint)
	waypoint.global_position = position

func _create_fixture(flags: Dictionary) -> Dictionary:
	U_ECS_EVENT_BUS.reset()

	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(SENTRY_BT_BRAIN_PATH)
	if system_script == null or brain_settings == null:
		return {}

	var root := Node3D.new()
	add_child_autofree(root)

	var manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(manager)
	U_SERVICE_LOCATOR.register(StringName("ecs_manager"), manager)

	var store: MockStateStore = MOCK_STATE_STORE.new()
	add_child_autofree(store)
	_set_demo_flags(store, flags)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AIBehaviorSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var behavior_system: BaseECSSystem = system_variant as BaseECSSystem
	root.add_child(behavior_system)
	autofree(behavior_system)
	behavior_system.ecs_manager = manager
	behavior_system.set("state_store", store)
	behavior_system.configure(manager)

	var waypoints := Node3D.new()
	waypoints.name = "Waypoints"
	add_child_autofree(waypoints)
	_create_waypoint(waypoints, "WaypointGuardA", Vector3(-2.0, 1.0, -2.0))
	_create_waypoint(waypoints, "WaypointGuardB", Vector3(2.0, 1.0, -2.0))
	_create_waypoint(waypoints, "WaypointGuardC", Vector3(0.0, 1.0, 2.0))

	var noise_sources := Node3D.new()
	noise_sources.name = "NoiseSources"
	add_child_autofree(noise_sources)
	var noise_source := Node3D.new()
	noise_source.name = "Inter_NoiseSourceA"
	noise_sources.add_child(noise_source)
	autofree(noise_source)
	noise_source.global_position = Vector3(4.0, 1.0, 0.0)

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = "E_SentryBT"
	entity.entity_id = &"sentry_bt"
	entity.tags = [&"ai", &"sentry"]
	root.add_child(entity)
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "SentryBody"
	entity.add_child(body)
	autofree(body)
	body.global_position = Vector3(0.0, 1.0, 0.0)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	entity.add_child(brain)
	autofree(brain)
	manager.add_component_to_entity(entity, brain)

	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	entity.add_child(move_target)
	autofree(move_target)
	manager.add_component_to_entity(entity, move_target)

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)
	manager.add_component_to_entity(entity, movement)

	return {
		"system": behavior_system,
		"brain": brain,
	}

func _brain_state_has_action_key(brain: C_AIBrainComponent, key: StringName) -> bool:
	return _find_action_state_value(brain, key) != null

func _find_action_state_value(brain: C_AIBrainComponent, key: StringName) -> Variant:
	for node_state_variant in brain.bt_state_bag.values():
		if not (node_state_variant is Dictionary):
			continue
		var node_state: Dictionary = node_state_variant as Dictionary
		var action_state_variant: Variant = node_state.get(BT_ACTION_STATE_BAG_KEY, null)
		if not (action_state_variant is Dictionary):
			continue
		var action_state: Dictionary = action_state_variant as Dictionary
		if action_state.has(key):
			return action_state.get(key)
	return null

func _observe_action_key_over_ticks(
	system: BaseECSSystem,
	brain: C_AIBrainComponent,
	key: StringName,
	ticks: int,
	delta: float
) -> bool:
	for _i in range(max(ticks, 0)):
		system.process_tick(delta)
		if _brain_state_has_action_key(brain, key):
			return true
	return false

func _observe_action_value_over_ticks(
	system: BaseECSSystem,
	brain: C_AIBrainComponent,
	key: StringName,
	ticks: int,
	delta: float
) -> Variant:
	for _i in range(max(ticks, 0)):
		system.process_tick(delta)
		var value: Variant = _find_action_state_value(brain, key)
		if value != null:
			return value
	return null

func _count_published_events(event_name: StringName) -> int:
	var count: int = 0
	for event_variant in U_ECS_EVENT_BUS.get_event_history():
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant as Dictionary
		if event.get("name", StringName()) == event_name:
			count += 1
	return count

func _find_last_event_payload(event_name: StringName) -> Dictionary:
	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	for index in range(history.size() - 1, -1, -1):
		var event_variant: Variant = history[index]
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant as Dictionary
		if event.get("name", StringName()) != event_name:
			continue
		var payload_variant: Variant = event.get("payload", {})
		if payload_variant is Dictionary:
			return payload_variant as Dictionary
	return {}

func test_sentry_without_disturbance_runs_guard_scan_then_patrol_move() -> void:
	var fixture: Dictionary = _create_fixture({})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	assert_true(
		_observe_action_key_over_ticks(system, brain, U_AI_TASK_STATE_KEYS.SCAN_ELAPSED, 8, 0.1),
		"Guard branch should run a scan action while idle at post."
	)
	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		80,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		GUARD_TARGET_PATH,
		"Sentry should resume guard route by moving toward guard waypoint A."
	)
	assert_eq(
		_count_published_events(&"ai_alarm_triggered"),
		0,
		"Guard branch should not publish alarm events without disturbance flags."
	)

func test_sentry_disturbance_flag_triggers_alarm_investigation_sequence() -> void:
	var fixture: Dictionary = _create_fixture({"comms_disturbance_heard": true})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		30,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		INVESTIGATE_TARGET_PATH,
		"Disturbance investigate branch should move toward the noise source."
	)
	assert_gt(
		_count_published_events(&"ai_alarm_triggered"),
		0,
		"Sentry investigate branch should publish ai_alarm_triggered."
	)
	var payload: Dictionary = _find_last_event_payload(&"ai_alarm_triggered")
	assert_eq(payload.get("source", StringName("")), StringName("sentry"), "Alarm payload should tag sentry source.")

func test_sentry_proximity_flag_triggers_proximity_investigation_branch() -> void:
	var fixture: Dictionary = _create_fixture({"comms_disturbance_proximity": true})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		30,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		INVESTIGATE_TARGET_PATH,
		"Proximity investigate branch should move toward the shared noise source target."
	)
	assert_gt(
		_count_published_events(&"ai_alarm_triggered"),
		0,
		"Proximity investigate branch should publish ai_alarm_triggered."
	)
