extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")

const WOLF_BRAIN := preload("res://resources/ai/forest/wolf/cfg_wolf_brain.tres")

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_wolf_entity(
	root: Node3D,
	manager: MockECSManager,
	entity_name: String,
	prey_detection_in_range: bool,
	pack_detection_in_range: bool,
	hunger: float,
	detected_entity_id: StringName
) -> Dictionary:
	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = entity_name
	entity.entity_id = StringName(entity_name.to_lower())
	entity.tags = [&"predator", &"ai", &"forest"]
	root.add_child(entity)
	autofree(entity)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = WOLF_BRAIN
	entity.add_child(brain)
	autofree(brain)
	manager.add_component_to_entity(entity, brain)

	var prey_detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	prey_detection.detection_role = StringName("primary")
	prey_detection.target_tag = StringName("prey")
	prey_detection.detection_radius = 12.0
	prey_detection.is_player_in_range = prey_detection_in_range
	prey_detection.last_detected_player_entity_id = detected_entity_id if prey_detection_in_range else StringName("")
	entity.add_child(prey_detection)
	autofree(prey_detection)
	manager.add_component_to_entity(entity, prey_detection)

	var pack_detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	pack_detection.detection_role = StringName("pack")
	pack_detection.target_tag = StringName("predator")
	pack_detection.detection_radius = 18.0
	pack_detection.is_player_in_range = pack_detection_in_range
	pack_detection.last_detected_player_entity_id = StringName("other_wolf") if pack_detection_in_range else StringName("")
	entity.add_child(pack_detection)
	autofree(pack_detection)
	manager.add_component_to_entity(entity, pack_detection)

	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var needs_settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	needs_settings.initial_hunger = hunger
	needs_settings.sated_threshold = 0.75
	needs_settings.starving_threshold = 0.3
	needs_settings.gain_on_feed = 0.45
	needs.settings = needs_settings
	entity.add_child(needs)
	autofree(needs)
	await get_tree().process_frame
	needs.hunger = hunger
	manager.add_component_to_entity(entity, needs)

	var movement: C_MovementComponent = C_MovementComponent.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)
	manager.add_component_to_entity(entity, movement)

	return {
		"entity": entity,
		"brain": brain,
		"prey_detection": prey_detection,
		"pack_detection": pack_detection,
		"needs": needs,
	}

func _create_fixture(
	prey_in_range: bool,
	pack_in_range: bool,
	hunger: float,
	detected_entity_id: StringName = StringName("rabbit")
) -> Dictionary:
	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	if system_script == null:
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

	var wolf_data: Dictionary = await _create_wolf_entity(
		root, manager, "E_Wolf", prey_in_range, pack_in_range, hunger, detected_entity_id
	)

	if prey_in_range:
		var target_node := Node3D.new()
		target_node.name = "E_Rabbit"
		root.add_child(target_node)
		autofree(target_node)
		manager.register_entity_id(detected_entity_id, target_node)

	if pack_in_range:
		var other_wolf_node := Node3D.new()
		other_wolf_node.name = "E_OtherWolf"
		root.add_child(other_wolf_node)
		autofree(other_wolf_node)
		manager.register_entity_id(StringName("other_wolf"), other_wolf_node)

	return {
		"system": behavior_system,
		"brain": wolf_data.get("brain"),
		"prey_detection": wolf_data.get("prey_detection"),
		"pack_detection": wolf_data.get("pack_detection"),
		"needs": wolf_data.get("needs"),
		"manager": manager,
		"root": root,
	}

func _simulate_ticks(system: BaseECSSystem, tick_count: int, delta: float) -> void:
	for _i in range(max(tick_count, 0)):
		system.process_tick(delta)

func test_hungry_wolf_with_pack_and_prey_selects_hunt_pack() -> void:
	var fixture: Dictionary = await _create_fixture(true, true, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	_simulate_ticks(system, 1, 0.016)

	assert_eq(
		brain.get_active_goal_id(),
		StringName("hunt_pack"),
		"Hungry wolf with pack + prey detection should select hunt_pack goal."
	)

func test_hungry_wolf_with_prey_but_no_pack_selects_hunt() -> void:
	var fixture: Dictionary = await _create_fixture(true, false, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	_simulate_ticks(system, 1, 0.016)

	assert_eq(
		brain.get_active_goal_id(),
		StringName("hunt"),
		"Hungry wolf with prey but no pack should select hunt goal."
	)

func test_sated_wolf_with_pack_and_prey_selects_wander() -> void:
	var fixture: Dictionary = await _create_fixture(true, true, 0.95)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	_simulate_ticks(system, 1, 0.016)

	assert_eq(
		brain.get_active_goal_id(),
		StringName("wander"),
		"Sated wolf should select wander even with pack + prey detection."
	)

func test_hungry_wolf_with_pack_but_no_prey_selects_wander() -> void:
	var fixture: Dictionary = await _create_fixture(false, true, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	_simulate_ticks(system, 1, 0.016)

	assert_eq(
		brain.get_active_goal_id(),
		StringName("wander"),
		"Hungry wolf with pack but no prey should select wander."
	)