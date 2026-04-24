extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_behavior_system.gd"
const PATROL_DRONE_BT_BRAIN_PATH := "res://resources/ai/patrol_drone/cfg_patrol_drone_brain.tres"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"
const INVESTIGATE_TARGET_PATH := "../../Interactions/Inter_ActivatableNode"
const PATROL_TARGET_PATH := "../../Waypoints/WaypointA"

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
	assert_not_null(brain_settings.root, "Expected BT brain to define a root node.")
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
	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(PATROL_DRONE_BT_BRAIN_PATH)
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
	_create_waypoint(waypoints, "WaypointA", Vector3(-6.0, 1.0, -6.0))
	_create_waypoint(waypoints, "WaypointB", Vector3(6.0, 1.0, -6.0))
	_create_waypoint(waypoints, "WaypointC", Vector3(6.0, 1.0, 6.0))
	_create_waypoint(waypoints, "WaypointD", Vector3(-6.0, 1.0, 6.0))

	var interactions := Node3D.new()
	interactions.name = "Interactions"
	add_child_autofree(interactions)
	var activatable := Node3D.new()
	activatable.name = "Inter_ActivatableNode"
	interactions.add_child(activatable)
	autofree(activatable)
	activatable.global_position = Vector3(4.0, 1.0, 0.0)

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = "E_PatrolDroneBT"
	entity.entity_id = &"patrol_drone_bt"
	entity.tags = [&"ai", &"patrol_drone"]
	root.add_child(entity)
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "PatrolDroneBody"
	entity.add_child(body)
	autofree(body)
	body.global_position = Vector3(-4.0, 2.5, 0.0)

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
		"store": store,
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

func test_patrol_drone_without_flags_runs_patrol_waypoint_move() -> void:
	var fixture: Dictionary = _create_fixture({})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		24,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		PATROL_TARGET_PATH,
		"Patrol drone should target the first patrol waypoint when no investigate flags are active."
	)
	assert_false(
		_brain_state_has_action_key(brain, U_AI_TASK_STATE_KEYS.SCAN_ELAPSED),
		"Patrol loop should not start investigate scan without a trigger flag."
	)

func test_patrol_drone_power_core_flag_runs_investigate_scan_sequence() -> void:
	var fixture: Dictionary = _create_fixture({"power_core_activated": true})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		24,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		INVESTIGATE_TARGET_PATH,
		"Investigate branch should move toward the activatable interaction node."
	)

func test_patrol_drone_proximity_flag_runs_proximity_investigate_branch() -> void:
	var fixture: Dictionary = _create_fixture({"power_core_proximity": true})
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	var requested_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		24,
		0.1
	)
	assert_eq(
		str(requested_path_variant),
		INVESTIGATE_TARGET_PATH,
		"Proximity investigate branch should use the activatable interaction target."
	)
