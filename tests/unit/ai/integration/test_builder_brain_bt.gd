extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const BUILDER_BT_BRAIN_PATH := "res://resources/ai/woods/builder/cfg_builder_brain.tres"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"

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
	assert_not_null(brain_settings.root, "Expected BT builder brain to define a root node.")
	return brain_settings

func _create_fixture(needs_hunger: float = 0.3, needs_thirst: float = 0.3) -> Dictionary:
	U_ECS_EVENT_BUS.reset()

	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(BUILDER_BT_BRAIN_PATH)
	if system_script == null or brain_settings == null:
		return {}

	var root := Node3D.new()
	add_child_autofree(root)

	var manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(manager)
	U_SERVICE_LOCATOR.register(StringName("ecs_manager"), manager)

	var store: MockStateStore = MOCK_STATE_STORE.new()
	add_child_autofree(store)

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

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = "E_BuilderBT"
	entity.entity_id = &"builder_bt"
	entity.tags = [&"ai", &"builder"]
	root.add_child(entity)
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "BuilderBody"
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

	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var needs_settings := RS_NEEDS_SETTINGS.new()
	needs_settings.initial_hunger = needs_hunger
	needs.settings = needs_settings
	needs._on_required_settings_ready()
	entity.add_child(needs)
	autofree(needs)
	manager.add_component_to_entity(entity, needs)

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.target_tag = &"predator"
	entity.add_child(detection)
	autofree(detection)
	manager.add_component_to_entity(entity, detection)

	return {
		"system": behavior_system,
		"brain": brain,
		"entity": entity,
		"needs": needs,
	}

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

func _brain_state_has_action_key(brain: C_AIBrainComponent, key: StringName) -> bool:
	return _find_action_state_value(brain, key) != null

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

func test_builder_with_empty_inventory_selects_gather_wood() -> void:
	var fixture: Dictionary = _create_fixture(0.3, 0.3)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	assert_true(
		_observe_action_key_over_ticks(system, brain, U_AI_TASK_STATE_KEYS.MOVE_TARGET, 60, 0.1),
		"Builder with empty inventory should run gather_wood branch and set a move target."
	)

func test_builder_with_full_inventory_selects_haul_to_build_site() -> void:
	var fixture: Dictionary = _create_fixture(0.3, 0.3)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	assert_true(
		_observe_action_key_over_ticks(system, brain, U_AI_TASK_STATE_KEYS.MOVE_TARGET, 60, 0.1),
		"Builder with full inventory should run haul_to_build_site branch and set a move target."
	)

func test_builder_with_placed_materials_selects_build_stage() -> void:
	var fixture: Dictionary = _create_fixture(0.3, 0.3)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	assert_true(
		_observe_action_key_over_ticks(system, brain, U_AI_TASK_STATE_KEYS.MOVE_TARGET, 60, 0.1),
		"Builder with placed materials should run build_current_stage branch."
	)