extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_behavior_system.gd"
const GUIDE_PRISM_BT_BRAIN_PATH := "res://resources/ai/guide_prism/cfg_guide_brain.tres"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/core/events/ecs/u_ecs_event_bus.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/demo/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

const RS_MOVEMENT_SETTINGS := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/core/resources/ai/brain/rs_ai_brain_settings.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"
const SHOW_PATH_TARGET := "../../PathMarkers/PathMarkerA"
const ENCOURAGE_TARGET := "../../SpawnPoints/sp_default"

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

func _set_gameplay_state(store: MockStateStore, ai_flags: Dictionary, is_on_floor: bool) -> void:
	var gameplay: Dictionary = {
		"ai_demo_flags": ai_flags.duplicate(true),
		"entities": {
			"player": {
				"is_on_floor": is_on_floor,
			},
		},
	}
	store.set_slice(StringName("gameplay"), gameplay)

func _create_marker(parent: Node3D, marker_name: String, position: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = marker_name
	parent.add_child(marker)
	marker.global_position = position

func _create_fixture(ai_flags: Dictionary, is_on_floor: bool) -> Dictionary:
	U_ECS_EVENT_BUS.reset()

	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(GUIDE_PRISM_BT_BRAIN_PATH)
	if system_script == null or brain_settings == null:
		return {}

	var root := Node3D.new()
	add_child_autofree(root)

	var manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(manager)
	U_SERVICE_LOCATOR.register(StringName("ecs_manager"), manager)

	var store: MockStateStore = MOCK_STATE_STORE.new()
	add_child_autofree(store)
	_set_gameplay_state(store, ai_flags, is_on_floor)

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

	var path_markers := Node3D.new()
	path_markers.name = "PathMarkers"
	add_child_autofree(path_markers)
	_create_marker(path_markers, "PathMarkerA", Vector3(-3.0, 1.0, -3.0))
	_create_marker(path_markers, "PathMarkerB", Vector3(3.0, 1.0, -3.0))
	_create_marker(path_markers, "PathMarkerC", Vector3(3.0, 1.0, 3.0))
	_create_marker(path_markers, "PathMarkerD", Vector3(-3.0, 1.0, 3.0))

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	add_child_autofree(spawn_points)
	var default_spawn := Node3D.new()
	default_spawn.name = "sp_default"
	spawn_points.add_child(default_spawn)
	autofree(default_spawn)
	default_spawn.global_position = Vector3(0.0, 1.0, 4.0)

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = "E_GuidePrismBT"
	entity.entity_id = &"guide_prism_bt"
	entity.tags = [&"ai", &"guide_prism"]
	root.add_child(entity)
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "GuideBody"
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

func _count_published_events(event_name: StringName) -> int:
	var count: int = 0
	for event_variant in U_ECS_EVENT_BUS.get_event_history():
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant as Dictionary
		if event.get("name", StringName()) == event_name:
			count += 1
	return count

func test_guide_prism_without_flags_runs_show_path_sequence() -> void:
	var fixture: Dictionary = _create_fixture({}, true)
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
		SHOW_PATH_TARGET,
		"Guide prism should default to path guidance branch."
	)
	assert_eq(
		_count_published_events(&"signpost_message"),
		0,
		"Show-path branch should not emit celebration signpost events."
	)

func test_guide_prism_player_airborne_runs_encourage_animation_branch() -> void:
	var fixture: Dictionary = _create_fixture({}, false)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	var encourage_path_variant: Variant = _observe_action_value_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET_REQUESTED_NODE_PATH,
		20,
		0.1
	)
	assert_eq(
		str(encourage_path_variant),
		ENCOURAGE_TARGET,
		"Encourage branch should move guide prism toward respawn marker."
	)

func test_guide_prism_nav_goal_reached_celebrates_once_with_signpost_message() -> void:
	var fixture: Dictionary = _create_fixture({"nav_goal_reached": true}, true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	for _i in range(20):
		system.process_tick(0.1)
	assert_gt(
		_count_published_events(&"signpost_message"),
		0,
		"Celebrate branch should publish signpost_message event."
	)
	for _i in range(40):
		system.process_tick(0.1)
	assert_eq(
		_count_published_events(&"signpost_message"),
		1,
		"Celebrate branch should be one-shot and publish signpost_message once."
	)
