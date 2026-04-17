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
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")

const WOLF_BRAIN := preload("res://resources/ai/forest/wolf/cfg_wolf_brain.tres")
const RABBIT_BRAIN := preload("res://resources/ai/forest/rabbit/cfg_rabbit_brain.tres")

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture(brain_settings: RS_AIBrainSettings, hunger: float, detection_in_range: bool) -> Dictionary:
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

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = "E_ForestTest"
	entity.entity_id = &"forest_test"
	root.add_child(entity)
	autofree(entity)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	entity.add_child(brain)
	autofree(brain)
	manager.add_component_to_entity(entity, brain)

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.is_player_in_range = detection_in_range
	entity.add_child(detection)
	autofree(detection)
	manager.add_component_to_entity(entity, detection)
	if detection_in_range:
		var target := Node3D.new()
		target.name = "E_Target"
		root.add_child(target)
		autofree(target)
		manager.register_entity_id(&"forest_target", target)
		detection.last_detected_player_entity_id = &"forest_target"

	var needs: Variant = C_NEEDS_COMPONENT.new()
	var needs_settings: Variant = RS_NEEDS_SETTINGS.new()
	needs_settings.initial_hunger = hunger
	needs.settings = needs_settings
	entity.add_child(needs)
	autofree(needs)
	await get_tree().process_frame
	needs.hunger = hunger
	manager.add_component_to_entity(entity, needs)

	return {
		"system": behavior_system,
		"brain": brain,
	}

func test_hungry_wolf_prefers_hunt_over_wander() -> void:
	var fixture: Dictionary = await _create_fixture(WOLF_BRAIN, 0.1, true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	system.process_tick(0.016)

	assert_eq(brain.get_active_goal_id(), StringName("hunt"))

func test_sated_wolf_prefers_wander_over_hunt() -> void:
	var fixture: Dictionary = await _create_fixture(WOLF_BRAIN, 0.95, true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	system.process_tick(0.016)

	assert_eq(brain.get_active_goal_id(), StringName("wander"))

func test_hungry_rabbit_prefers_graze_over_wander() -> void:
	var fixture: Dictionary = await _create_fixture(RABBIT_BRAIN, 0.15, false)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	system.process_tick(0.016)

	assert_eq(brain.get_active_goal_id(), StringName("graze"))

func test_sated_rabbit_prefers_wander_over_graze() -> void:
	var fixture: Dictionary = await _create_fixture(RABBIT_BRAIN, 0.95, false)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	system.process_tick(0.016)

	assert_eq(brain.get_active_goal_id(), StringName("wander"))
