extends BaseTest

const S_AI_DETECTION_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_ai_detection_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/core/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/core/resources/ecs/rs_movement_settings.gd")

class FakeBody extends CharacterBody3D:
	pass

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_entity(root: Node3D, entity_name: String, position: Vector3, tags: Array[StringName]) -> Dictionary:
	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = entity_name
	entity.tags = tags.duplicate()
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

func _create_detection(target_tag: StringName, detection_role: StringName, radius: float) -> C_DetectionComponent:
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.detection_radius = radius
	detection.target_tag = target_tag
	detection.detection_role = detection_role
	return detection

func _create_multi_fixture() -> Dictionary:
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

	# Wolf entity with TWO detection components: prey (primary) + predator (pack)
	var wolf_data: Dictionary = _create_entity(
		root,
		"E_Wolf",
		Vector3.ZERO,
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)
	var wolf_entity: BaseECSEntity = wolf_data.get("entity") as BaseECSEntity
	var wolf_movement: C_MovementComponent = wolf_data.get("movement") as C_MovementComponent

	var prey_detection: C_DetectionComponent = _create_detection(StringName("prey"), StringName("primary"), 12.0)
	wolf_entity.add_child(prey_detection)
	autofree(prey_detection)

	var pack_detection: C_DetectionComponent = _create_detection(StringName("predator"), StringName("pack"), 18.0)
	wolf_entity.add_child(pack_detection)
	autofree(pack_detection)

	ecs_manager.add_component_to_entity(wolf_entity, wolf_movement)
	ecs_manager.add_component_to_entity(wolf_entity, prey_detection)
	ecs_manager.add_component_to_entity(wolf_entity, pack_detection)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"store": store,
		"root": root,
		"wolf_entity": wolf_entity,
		"wolf_body": wolf_data.get("body") as FakeBody,
		"wolf_movement": wolf_movement,
		"prey_detection": prey_detection,
		"pack_detection": pack_detection,
	}

func _register_target(
	fixture: Dictionary,
	entity_name: String,
	position: Vector3,
	tags: Array[StringName],
	add_player_tag: bool = false
) -> Dictionary:
	var root: Node3D = fixture.get("root") as Node3D
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var target_data: Dictionary = _create_entity(root, entity_name, position, tags)
	var target_entity: BaseECSEntity = target_data.get("entity") as BaseECSEntity
	var target_movement: C_MovementComponent = target_data.get("movement") as C_MovementComponent
	ecs_manager.add_component_to_entity(target_entity, target_movement)

	if add_player_tag:
		var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
		target_entity.add_child(player_tag)
		autofree(player_tag)
		ecs_manager.add_component_to_entity(target_entity, player_tag)

	return target_data

# --- Tests ---

func test_both_detection_components_on_same_entity_detect_independently() -> void:
	var fixture: Dictionary = _create_multi_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	# Place a rabbit (prey) and another wolf (predator) near the detector
	_register_target(
		fixture,
		"E_Rabbit",
		Vector3(5.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)
	_register_target(
		fixture,
		"E_OtherWolf",
		Vector3(10.0, 0.0, 0.0),
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var prey_detection: C_DetectionComponent = fixture.get("prey_detection") as C_DetectionComponent
	var pack_detection: C_DetectionComponent = fixture.get("pack_detection") as C_DetectionComponent

	system.process_tick(0.016)

	assert_true(
		prey_detection.is_player_in_range,
		"Primary (prey) detection should detect the rabbit."
	)
	assert_true(
		pack_detection.is_player_in_range,
		"Pack (predator) detection should detect the other wolf."
	)

func test_detection_components_filter_by_their_own_target_tag() -> void:
	var fixture: Dictionary = _create_multi_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	# Only place a rabbit (prey-tagged) — no predator nearby
	_register_target(
		fixture,
		"E_Rabbit",
		Vector3(5.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var prey_detection: C_DetectionComponent = fixture.get("prey_detection") as C_DetectionComponent
	var pack_detection: C_DetectionComponent = fixture.get("pack_detection") as C_DetectionComponent

	system.process_tick(0.016)

	assert_true(
		prey_detection.is_player_in_range,
		"Primary (prey) detection should detect the rabbit."
	)
	assert_false(
		pack_detection.is_player_in_range,
		"Pack (predator) detection should NOT detect a prey-tagged rabbit."
	)

func test_only_pack_detection_triggers_when_predator_nearby() -> void:
	var fixture: Dictionary = _create_multi_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	# Only place another wolf (predator-tagged) — no prey nearby
	_register_target(
		fixture,
		"E_OtherWolf",
		Vector3(5.0, 0.0, 0.0),
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var prey_detection: C_DetectionComponent = fixture.get("prey_detection") as C_DetectionComponent
	var pack_detection: C_DetectionComponent = fixture.get("pack_detection") as C_DetectionComponent

	system.process_tick(0.016)

	assert_false(
		prey_detection.is_player_in_range,
		"Primary (prey) detection should NOT detect a predator-tagged wolf."
	)
	assert_true(
		pack_detection.is_player_in_range,
		"Pack (predator) detection should detect the other wolf."
	)

func test_detection_role_default_is_primary() -> void:
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	autofree(detection)
	assert_eq(
		detection.detection_role,
		StringName("primary"),
		"detection_role should default to &'primary'."
	)

func test_last_detected_entity_id_is_independent_per_component() -> void:
	var fixture: Dictionary = _create_multi_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var rabbit_data: Dictionary = _register_target(
		fixture,
		"E_Rabbit",
		Vector3(5.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)
	var other_wolf_data: Dictionary = _register_target(
		fixture,
		"E_OtherWolf",
		Vector3(10.0, 0.0, 0.0),
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)

	var rabbit_entity: BaseECSEntity = rabbit_data.get("entity") as BaseECSEntity
	var other_wolf_entity: BaseECSEntity = other_wolf_data.get("entity") as BaseECSEntity

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var prey_detection: C_DetectionComponent = fixture.get("prey_detection") as C_DetectionComponent
	var pack_detection: C_DetectionComponent = fixture.get("pack_detection") as C_DetectionComponent

	system.process_tick(0.016)

	assert_eq(
		prey_detection.last_detected_player_entity_id,
		rabbit_entity.get_entity_id(),
		"Primary (prey) detection should report the rabbit entity ID."
	)
	assert_eq(
		pack_detection.last_detected_player_entity_id,
		other_wolf_entity.get_entity_id(),
		"Pack (predator) detection should report the other wolf entity ID."
	)

func test_single_detection_component_back_compat() -> void:
	# Verify that an entity with only one detection component still works correctly
	var system_script: Script = _load_script(S_AI_DETECTION_SYSTEM_PATH)
	if system_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var system_variant: Variant = system_script.new()
	if not (system_variant is BaseECSSystem):
		return
	var system: BaseECSSystem = system_variant as BaseECSSystem
	system.ecs_manager = ecs_manager
	system.state_store = store
	root.add_child(system)
	autofree(system)
	system.configure(ecs_manager)

	var wolf_data: Dictionary = _create_entity(
		root,
		"E_Wolf",
		Vector3.ZERO,
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)
	var wolf_entity: BaseECSEntity = wolf_data.get("entity") as BaseECSEntity
	var wolf_movement: C_MovementComponent = wolf_data.get("movement") as C_MovementComponent

	var detection: C_DetectionComponent = _create_detection(StringName("prey"), StringName("primary"), 12.0)
	wolf_entity.add_child(detection)
	autofree(detection)

	ecs_manager.add_component_to_entity(wolf_entity, wolf_movement)
	ecs_manager.add_component_to_entity(wolf_entity, detection)

	# Register a rabbit target
	var rabbit_data: Dictionary = _create_entity(
		root,
		"E_Rabbit",
		Vector3(5.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)
	var rabbit_entity: BaseECSEntity = rabbit_data.get("entity") as BaseECSEntity
	var rabbit_movement: C_MovementComponent = rabbit_data.get("movement") as C_MovementComponent
	ecs_manager.add_component_to_entity(rabbit_entity, rabbit_movement)

	system.process_tick(0.016)

	assert_true(
		detection.is_player_in_range,
		"Single detection component should still detect targets via get_components() iteration."
	)
	assert_eq(
		detection.last_detected_player_entity_id,
		rabbit_entity.get_entity_id(),
		"Single detection component should report the correct detected entity ID."
	)