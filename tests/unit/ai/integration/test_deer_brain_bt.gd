extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const DEER_BT_BRAIN_PATH := "res://resources/ai/forest/deer/cfg_deer_brain.tres"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")

const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")

const BT_ACTION_STATE_BAG_KEY := &"bt_action_state_bag"
const PREDATOR_ENTITY_ID := &"wolf_bt_threat"

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

func _create_fixture(predator_detected: bool, hunger: float) -> Dictionary:
	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(DEER_BT_BRAIN_PATH)
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

	var deer_entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	deer_entity.name = "E_DeerBT"
	deer_entity.entity_id = &"deer_bt"
	deer_entity.tags = [&"herbivore", &"ai", &"forest"]
	root.add_child(deer_entity)
	autofree(deer_entity)

	var body := CharacterBody3D.new()
	body.name = "DeerBody"
	deer_entity.add_child(body)
	autofree(body)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	deer_entity.add_child(brain)
	autofree(brain)
	manager.add_component_to_entity(deer_entity, brain)

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.detection_role = StringName("primary")
	detection.target_tag = StringName("predator")
	detection.is_player_in_range = predator_detected
	detection.last_detected_player_entity_id = PREDATOR_ENTITY_ID if predator_detected else StringName("")
	deer_entity.add_child(detection)
	autofree(detection)
	manager.add_component_to_entity(deer_entity, detection)

	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var needs_settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	needs_settings.initial_hunger = hunger
	needs_settings.sated_threshold = 0.75
	needs_settings.starving_threshold = 0.3
	needs_settings.gain_on_feed = 0.45
	needs.settings = needs_settings
	deer_entity.add_child(needs)
	autofree(needs)
	await get_tree().process_frame
	needs.hunger = hunger
	manager.add_component_to_entity(deer_entity, needs)

	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	deer_entity.add_child(move_target)
	autofree(move_target)
	manager.add_component_to_entity(deer_entity, move_target)

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	deer_entity.add_child(movement)
	autofree(movement)
	manager.add_component_to_entity(deer_entity, movement)

	if predator_detected:
		var predator := Node3D.new()
		predator.name = "E_WolfThreat"
		root.add_child(predator)
		predator.global_position = Vector3(0.3, 0.0, 0.0)
		autofree(predator)
		manager.register_entity_id(PREDATOR_ENTITY_ID, predator)

	return {
		"system": behavior_system,
		"brain": brain,
		"needs": needs,
		"detection": detection,
		"move_target": move_target,
	}

func _simulate_ticks(system: BaseECSSystem, tick_count: int, delta: float) -> void:
	for _i in range(max(tick_count, 0)):
		system.process_tick(delta)

func _brain_state_has_action_key(brain: C_AIBrainComponent, key: StringName) -> bool:
	for node_state_variant in brain.bt_state_bag.values():
		if not (node_state_variant is Dictionary):
			continue
		var node_state: Dictionary = node_state_variant as Dictionary
		var action_state_variant: Variant = node_state.get(BT_ACTION_STATE_BAG_KEY, null)
		if not (action_state_variant is Dictionary):
			continue
		var action_state: Dictionary = action_state_variant as Dictionary
		if action_state.has(key):
			return true
	return false

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

func test_deer_threat_response_runs_startle_then_flee() -> void:
	var fixture: Dictionary = await _create_fixture(true, 0.95)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var move_target: C_MoveTargetComponent = fixture.get("move_target") as C_MoveTargetComponent

	_simulate_ticks(system, 2, 0.1)
	assert_true(
		_brain_state_has_action_key(brain, U_AI_TASK_STATE_KEYS.SCAN_ELAPSED),
		"Threat response should enter startle scan action before flee."
	)
	assert_false(
		_brain_state_has_action_key(brain, U_AI_TASK_STATE_KEYS.MOVE_TARGET),
		"Flee should not start before startle scan/wait sequence completes."
	)

	var flee_started: bool = _observe_action_key_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.MOVE_TARGET,
		20,
		0.1
	)
	assert_true(flee_started, "Threat response should progress from startle into flee action.")
	assert_true(move_target.is_active, "Flee action should drive an active move-target request.")

func test_deer_without_threat_graze_sequence_increases_hunger() -> void:
	var fixture: Dictionary = await _create_fixture(false, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var starting_hunger: float = needs.hunger

	var observed_wait: bool = _observe_action_key_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.ELAPSED,
		12,
		0.1
	)
	assert_true(observed_wait, "Hungry deer should enter graze wait action before feed.")

	_simulate_ticks(system, 20, 0.1)
	assert_gt(needs.hunger, starting_hunger, "Graze sequence should eventually execute feed and raise hunger.")

func test_deer_without_threat_uses_wander_fallback_when_sated() -> void:
	var fixture: Dictionary = await _create_fixture(false, 0.95)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var move_target: C_MoveTargetComponent = fixture.get("move_target") as C_MoveTargetComponent

	_simulate_ticks(system, 1, 0.1)
	assert_true(
		_brain_state_has_action_key(brain, U_AI_TASK_STATE_KEYS.MOVE_TARGET),
		"Sated deer should fall back to wander and request a move target."
	)
	assert_true(move_target.is_active, "Wander action should leave move-target component active while moving.")
