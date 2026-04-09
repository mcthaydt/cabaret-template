extends BaseTest

const S_AI_NAVIGATION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_navigation_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")

class FakeBody extends CharacterBody3D:
	pass

class CameraManagerStub extends I_CAMERA_MANAGER:
	var main_camera: Camera3D = null

	func get_main_camera() -> Camera3D:
		return main_camera

	func apply_main_camera_transform(_transform: Transform3D) -> void:
		pass

	func is_blend_active() -> bool:
		return false

	func initialize_scene_camera(_scene: Node) -> Camera3D:
		return null

	func finalize_blend_to_scene(_new_scene: Node) -> void:
		pass

	func apply_shake_offset(_offset: Vector2, _rotation: float) -> void:
		pass

	func set_shake_source(_source: StringName, _offset: Vector2, _rotation: float) -> void:
		pass

	func clear_shake_source(_source: StringName) -> void:
		pass

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture(with_body: bool = true) -> Dictionary:
	var system_script: Script = _load_script(S_AI_NAVIGATION_SYSTEM_PATH)
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AINavigationSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)
	system.navigation_throttle_interval = 0.0

	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(system)

	var entity := Node3D.new()
	entity.name = "E_NavigationEntity"
	autofree(entity)
	root.add_child(entity)

	var body: FakeBody = null
	if with_body:
		body = FakeBody.new()
		entity.add_child(body)
		autofree(body)

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)

	var input: C_InputComponent = C_INPUT_COMPONENT.new()
	entity.add_child(input)
	autofree(input)

	var brain: Variant = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = RS_AI_BRAIN_SETTINGS.new()
	entity.add_child(brain)
	autofree(brain)

	ecs_manager.add_component_to_entity(entity, brain)
	ecs_manager.add_component_to_entity(entity, input)
	ecs_manager.add_component_to_entity(entity, movement)

	return {
		"system": system,
		"root": root,
		"ecs_manager": ecs_manager,
		"entity": entity,
		"body": body,
		"movement": movement,
		"input": input,
		"brain": brain,
	}

func _register_camera(camera: Camera3D) -> void:
	var camera_manager := CameraManagerStub.new()
	camera_manager.main_camera = camera
	autofree(camera_manager)
	U_SERVICE_LOCATOR.register(StringName("camera_manager"), camera_manager)

func test_system_extends_base_ecs_system() -> void:
	var system_script: Script = _load_script(S_AI_NAVIGATION_SYSTEM_PATH)
	if system_script == null:
		return

	var system_variant: Variant = system_script.new()
	if system_variant is Node:
		autofree(system_variant as Node)
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_AINavigationSystem should extend BaseECSSystem")

func test_execution_priority_is_negative_five() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	assert_eq(system.execution_priority, -5)

func test_writes_direction_toward_target() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {"ai_move_target": Vector3(10.0, 0.0, 0.0)}

	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.rotation = Vector3(0.0, -PI / 2.0, 0.0)
	_register_camera(camera)

	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 1.0, 0.01)
	assert_almost_eq(input.move_vector.y, 0.0, 0.01)

func test_writes_zero_when_no_target() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	brain.task_state = {}
	input.set_move_vector(Vector2(0.4, -0.6))
	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2.ZERO)

func test_writes_zero_when_at_target() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3(2.0, 0.0, 3.0)
	brain.task_state = {"ai_move_target": Vector3(2.02, 10.0, 3.01), "ai_arrival_threshold": 0.05}
	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2.ZERO)

func test_stops_moving_within_action_arrival_threshold() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3(1.0, 0.0, 1.0)
	brain.task_state = {"ai_move_target": Vector3(1.1, 0.0, 1.0), "ai_arrival_threshold": 0.25}
	input.set_move_vector(Vector2(0.6, -0.4))

	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2.ZERO)

func test_uses_default_threshold_when_not_in_task_state() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3(2.0, 0.0, 2.0)
	brain.task_state = {"ai_move_target": Vector3(2.2, 0.0, 2.0)}
	input.set_move_vector(Vector2(0.5, 0.3))

	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2.ZERO)

func test_ignores_y_axis() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {"ai_move_target": Vector3(0.0, 100.0, 10.0)}
	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 0.0, 0.01)
	assert_almost_eq(input.move_vector.y, 1.0, 0.01)

func test_skips_entity_without_body() -> void:
	var fixture: Dictionary = _create_fixture(false)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	brain.task_state = {"ai_move_target": Vector3(10.0, 0.0, 0.0)}
	input.set_move_vector(Vector2(0.33, -0.77))
	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2(0.33, -0.77))

func test_updates_direction_when_target_changes() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {"ai_move_target": Vector3(10.0, 0.0, 0.0)}
	system.process_tick(0.016)
	var first_vector: Vector2 = input.move_vector

	brain.task_state = {"ai_move_target": Vector3(0.0, 0.0, 10.0)}
	system.process_tick(0.016)
	var second_vector: Vector2 = input.move_vector

	assert_ne(first_vector, second_vector)
	assert_almost_eq(second_vector.x, 0.0, 0.01)
	assert_almost_eq(second_vector.y, 1.0, 0.01)

func test_writes_world_space_direction_without_camera_transform() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {"ai_move_target": Vector3(10.0, 0.0, 0.0)}

	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.rotation = Vector3(0.0, -PI / 2.0, 0.0)
	_register_camera(camera)

	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 1.0, 0.01)
	assert_almost_eq(input.move_vector.y, 0.0, 0.01)

func test_handles_no_camera_gracefully() -> void:
	var fixture: Dictionary = _create_fixture(true)
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var body: FakeBody = fixture["body"] as FakeBody
	var brain: Variant = fixture["brain"]
	var input: C_InputComponent = fixture["input"] as C_InputComponent
	var system: BaseECSSystem = fixture["system"] as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {"ai_move_target": Vector3(10.0, 0.0, 10.0)}
	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 0.7071, 0.01)
	assert_almost_eq(input.move_vector.y, 0.7071, 0.01)
