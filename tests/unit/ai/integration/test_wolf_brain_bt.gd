extends BaseTest

const S_AI_BEHAVIOR_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
const WOLF_BT_BRAIN_PATH := "res://resources/ai/forest/wolf/cfg_wolf_brain_bt.tres"

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
const PREY_ENTITY_ID := &"rabbit_bt_test"
const PACK_ENTITY_ID := &"other_wolf_bt"

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

func _create_fixture(prey_detected: bool, pack_detected: bool, hunger: float) -> Dictionary:
	var system_script: Script = _load_required_script(S_AI_BEHAVIOR_SYSTEM_PATH)
	var brain_settings: RS_AIBrainSettings = _load_required_brain_settings(WOLF_BT_BRAIN_PATH)
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

	var wolf_entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	wolf_entity.name = "E_WolfBT"
	wolf_entity.entity_id = &"wolf_bt"
	wolf_entity.tags = [&"predator", &"ai", &"forest"]
	root.add_child(wolf_entity)
	autofree(wolf_entity)

	var body := CharacterBody3D.new()
	body.name = "WolfBody"
	wolf_entity.add_child(body)
	autofree(body)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = brain_settings
	wolf_entity.add_child(brain)
	autofree(brain)
	manager.add_component_to_entity(wolf_entity, brain)

	var primary_detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	primary_detection.detection_role = StringName("primary")
	primary_detection.target_tag = StringName("prey")
	primary_detection.is_player_in_range = prey_detected
	primary_detection.last_detected_player_entity_id = PREY_ENTITY_ID if prey_detected else StringName("")
	wolf_entity.add_child(primary_detection)
	autofree(primary_detection)
	manager.add_component_to_entity(wolf_entity, primary_detection)

	var pack_detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	pack_detection.detection_role = StringName("pack")
	pack_detection.target_tag = StringName("predator")
	pack_detection.is_player_in_range = pack_detected
	pack_detection.last_detected_player_entity_id = PACK_ENTITY_ID if pack_detected else StringName("")
	wolf_entity.add_child(pack_detection)
	autofree(pack_detection)
	manager.add_component_to_entity(wolf_entity, pack_detection)

	var needs: C_NeedsComponent = C_NEEDS_COMPONENT.new()
	var needs_settings: RS_NeedsSettings = RS_NEEDS_SETTINGS.new()
	needs_settings.initial_hunger = hunger
	needs_settings.sated_threshold = 0.75
	needs_settings.starving_threshold = 0.3
	needs_settings.gain_on_feed = 0.45
	needs.settings = needs_settings
	wolf_entity.add_child(needs)
	autofree(needs)
	await get_tree().process_frame
	needs.hunger = hunger
	manager.add_component_to_entity(wolf_entity, needs)

	var move_target: C_MoveTargetComponent = C_MOVE_TARGET_COMPONENT.new()
	wolf_entity.add_child(move_target)
	autofree(move_target)
	manager.add_component_to_entity(wolf_entity, move_target)

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	wolf_entity.add_child(movement)
	autofree(movement)
	manager.add_component_to_entity(wolf_entity, movement)

	var prey: Node3D = null
	if prey_detected:
		prey = Node3D.new()
		prey.name = "E_RabbitBT"
		root.add_child(prey)
		prey.global_position = Vector3(0.2, 0.0, 0.2)
		autofree(prey)
		manager.register_entity_id(PREY_ENTITY_ID, prey)

	if pack_detected:
		var pack_member := Node3D.new()
		pack_member.name = "E_OtherWolfBT"
		root.add_child(pack_member)
		autofree(pack_member)
		manager.register_entity_id(PACK_ENTITY_ID, pack_member)

	return {
		"system": behavior_system,
		"brain": brain,
		"needs": needs,
		"primary_detection": primary_detection,
		"prey": prey,
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

func test_wolf_hunt_pack_sequence_runs_move_wait_move_feed() -> void:
	var fixture: Dictionary = await _create_fixture(true, true, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var primary_detection: C_DetectionComponent = fixture.get("primary_detection") as C_DetectionComponent
	var prey: Node3D = fixture.get("prey") as Node3D
	var starting_hunger: float = needs.hunger

	_simulate_ticks(system, 2, 0.1)
	assert_eq(
		needs.hunger,
		starting_hunger,
		"Hunt sequence should not feed before its wait gate elapses."
	)
	assert_eq(
		primary_detection.pending_feed_entity_id,
		PREY_ENTITY_ID,
		"Move-to-detected should lock prey id before feed executes."
	)
	assert_true(
		_brain_state_has_action_key(brain, U_AI_TASK_STATE_KEYS.ELAPSED),
		"Hunt sequence should enter wait action between move and feed."
	)

	_simulate_ticks(system, 4, 0.1)
	await get_tree().process_frame

	assert_gt(
		needs.hunger,
		starting_hunger,
		"Hunt sequence should eventually execute feed and increase hunger."
	)
	assert_eq(
		primary_detection.last_detected_player_entity_id,
		StringName(""),
		"Feed step should clear active detection id after prey consumption."
	)
	assert_false(
		is_instance_valid(prey),
		"Feed step should consume prey entity by the end of the sequence."
	)

func test_wolf_without_prey_uses_wander_branch() -> void:
	var fixture: Dictionary = await _create_fixture(false, true, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var needs: C_NeedsComponent = fixture.get("needs") as C_NeedsComponent
	var primary_detection: C_DetectionComponent = fixture.get("primary_detection") as C_DetectionComponent
	var starting_hunger: float = needs.hunger

	var observed_wander_state: bool = _observe_action_key_over_ticks(
		system,
		brain,
		U_AI_TASK_STATE_KEYS.WANDER_HOME,
		8,
		0.1
	)

	assert_true(
		observed_wander_state,
		"Without prey detection, wolf BT should enter wander action state."
	)
	assert_eq(
		primary_detection.pending_feed_entity_id,
		StringName(""),
		"Wander branch should not lock any prey id."
	)
	assert_eq(
		needs.hunger,
		starting_hunger,
		"Wander branch should not change hunger via feed."
	)

func test_wolf_hunt_pack_branch_reports_planner_plan_snapshot() -> void:
	var fixture: Dictionary = await _create_fixture(true, true, 0.1)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent

	system.process_tick(0.1)
	var snapshot: Dictionary = brain.get_debug_snapshot()
	assert_true(
		snapshot.has(&"last_plan"),
		"Hunt-pack branch should execute through RS_BTPlanner and expose last_plan debug data."
	)
	if not snapshot.has(&"last_plan"):
		return

	var last_plan_variant: Variant = snapshot.get(&"last_plan", [])
	assert_true(last_plan_variant is Array, "last_plan should be an array of planner action ids.")
	if not (last_plan_variant is Array):
		return
	var last_plan: Array = last_plan_variant as Array
	assert_eq(
		last_plan,
		[
			StringName("planner_pack_close_in"),
			StringName("planner_pack_hold"),
			StringName("planner_pack_reacquire"),
			StringName("planner_pack_feed"),
		],
		"Wolf planner path should expose the authored hunt_pack action plan in order."
	)
	assert_almost_eq(
		float(snapshot.get(&"last_plan_cost", -1.0)),
		4.0,
		0.0001,
		"Wolf planner path should report the summed planner action cost."
	)
