extends BaseTest

const S_AI_DETECTION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_detection_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")

class FakeBody extends CharacterBody3D:
	pass

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_entity(root: Node3D, name: String, position: Vector3, tags: Array[StringName]) -> Dictionary:
	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = name
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

func _set_detection_target_tag(detection: C_DetectionComponent, target_tag: StringName) -> void:
	for property_variant in detection.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property_info: Dictionary = property_variant as Dictionary
		if String(property_info.get("name", "")) != "target_tag":
			continue
		detection.set("target_tag", target_tag)
		return

func _create_fixture(target_tag: StringName = StringName("prey")) -> Dictionary:
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

	var detector_data: Dictionary = _create_entity(
		root,
		"E_Detector",
		Vector3.ZERO,
		[StringName("predator"), StringName("ai"), StringName("forest")]
	)
	var detector_entity: BaseECSEntity = detector_data.get("entity") as BaseECSEntity
	var detector_movement: C_MovementComponent = detector_data.get("movement") as C_MovementComponent

	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.detection_radius = 6.0
	_set_detection_target_tag(detection, target_tag)
	detector_entity.add_child(detection)
	autofree(detection)

	ecs_manager.add_component_to_entity(detector_entity, detector_movement)
	ecs_manager.add_component_to_entity(detector_entity, detection)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"store": store,
		"detector": detector_data,
		"detection": detection,
	}

func _register_target(
	fixture: Dictionary,
	name: String,
	position: Vector3,
	tags: Array[StringName],
	add_player_tag: bool = false
) -> Dictionary:
	var root: Node3D = fixture.get("detector", {}).get("entity", null) as Node3D
	var scene_root: Node3D = root.get_parent() as Node3D
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var target_data: Dictionary = _create_entity(scene_root, name, position, tags)
	var target_entity: BaseECSEntity = target_data.get("entity") as BaseECSEntity
	var target_movement: C_MovementComponent = target_data.get("movement") as C_MovementComponent
	ecs_manager.add_component_to_entity(target_entity, target_movement)

	if add_player_tag:
		var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
		target_entity.add_child(player_tag)
		autofree(player_tag)
		ecs_manager.add_component_to_entity(target_entity, player_tag)

	return target_data

func test_target_tag_prey_detects_matching_entity_in_range() -> void:
	var fixture: Dictionary = _create_fixture(StringName("prey"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	_register_target(
		fixture,
		"E_Rabbit",
		Vector3(3.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	system.process_tick(0.016)

	assert_true(
		detection.is_player_in_range,
		"Detector should enter range when a prey-tagged entity is inside detection_radius."
	)

func test_target_tag_prey_ignores_non_matching_entity() -> void:
	var fixture: Dictionary = _create_fixture(StringName("prey"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	_register_target(
		fixture,
		"E_Deer",
		Vector3(2.0, 0.0, 0.0),
		[StringName("herbivore"), StringName("ai"), StringName("forest")]
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	system.process_tick(0.016)

	assert_false(
		detection.is_player_in_range,
		"Detector should stay out-of-range when only non-matching tags are present."
	)

func test_detector_does_not_match_itself_when_target_tag_matches_self_tags() -> void:
	var fixture: Dictionary = _create_fixture(StringName("predator"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	system.process_tick(0.016)

	assert_false(
		detection.is_player_in_range,
		"Detector should not self-detect when target_tag matches its own entity tags."
	)

func test_default_player_target_tag_preserves_back_compat_detection() -> void:
	var fixture: Dictionary = _create_fixture(StringName("player"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	_register_target(
		fixture,
		"E_Player",
		Vector3(3.0, 0.0, 0.0),
		[StringName("player"), StringName("ai"), StringName("forest")],
		true
	)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	system.process_tick(0.016)

	assert_true(
		detection.is_player_in_range,
		"Default player targeting should still detect player-tag-component entities."
	)

func test_last_detected_entity_id_uses_base_ecs_entity_id() -> void:
	var fixture: Dictionary = _create_fixture(StringName("prey"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var rabbit_data: Dictionary = _register_target(
		fixture,
		"E_Rabbit",
		Vector3(2.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)
	var rabbit_entity: BaseECSEntity = rabbit_data.get("entity") as BaseECSEntity

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	system.process_tick(0.016)

	assert_eq(
		detection.last_detected_player_entity_id,
		rabbit_entity.get_entity_id(),
		"Detected entity ID should resolve from BaseECSEntity.get_entity_id()."
	)

func test_hysteresis_prevents_exit_in_tag_target_mode() -> void:
	var fixture: Dictionary = _create_fixture(StringName("prey"))
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var rabbit_data: Dictionary = _register_target(
		fixture,
		"E_Rabbit",
		Vector3(3.0, 0.0, 0.0),
		[StringName("prey"), StringName("ai"), StringName("forest")]
	)
	var rabbit_body: FakeBody = rabbit_data.get("body") as FakeBody

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	var detection: C_DetectionComponent = fixture.get("detection") as C_DetectionComponent
	detection.detection_radius = 6.0
	detection.detection_exit_radius = 10.0

	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should detect prey at 3.0 units")

	rabbit_body.global_position = Vector3(8.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(detection.is_player_in_range, "Should stay in range between detection_radius and exit_radius")

	rabbit_body.global_position = Vector3(11.0, 0.0, 0.0)
	system.process_tick(0.016)
	assert_false(detection.is_player_in_range, "Should exit past exit_radius")
