extends BaseTest

const S_MOVE_TARGET_FOLLOWER_SYSTEM_PATH := "res://scripts/ecs/systems/s_move_target_follower_system.gd"
const C_MOVE_TARGET_COMPONENT_PATH := "res://scripts/ecs/components/c_move_target_component.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/brain/rs_ai_brain_settings.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")

class FakeBody extends CharacterBody3D:
	pass

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture() -> Dictionary:
	var system_script: Script = _load_script(S_MOVE_TARGET_FOLLOWER_SYSTEM_PATH)
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_MoveTargetFollowerSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)
	system.set("navigation_throttle_interval", 0.0)

	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(system)

	return {
		"system": system,
		"root": root,
		"ecs_manager": ecs_manager,
	}

func _add_entity(
	fixture: Dictionary,
	entity_name: String,
	with_brain: bool = false,
	with_move_target_component: bool = false
) -> Dictionary:
	var root: Node3D = fixture.get("root", null) as Node3D
	var ecs_manager: MockECSManager = fixture.get("ecs_manager", null) as MockECSManager
	if root == null or ecs_manager == null:
		return {}

	var entity := Node3D.new()
	entity.name = entity_name
	root.add_child(entity)
	autofree(entity)

	var body := FakeBody.new()
	entity.add_child(body)
	autofree(body)

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)

	var input: C_InputComponent = C_INPUT_COMPONENT.new()
	entity.add_child(input)
	autofree(input)

	ecs_manager.add_component_to_entity(entity, input)
	ecs_manager.add_component_to_entity(entity, movement)

	var brain: Variant = null
	if with_brain:
		brain = C_AI_BRAIN_COMPONENT.new()
		brain.brain_settings = RS_AI_BRAIN_SETTINGS.new()
		entity.add_child(brain)
		autofree(brain)
		ecs_manager.add_component_to_entity(entity, brain)

	var move_target_component: Variant = null
	if with_move_target_component:
		var move_target_script: Script = _load_script(C_MOVE_TARGET_COMPONENT_PATH)
		if move_target_script == null:
			return {}
		move_target_component = move_target_script.new()
		entity.add_child(move_target_component)
		autofree(move_target_component)
		ecs_manager.add_component_to_entity(entity, move_target_component)

	return {
		"entity": entity,
		"body": body,
		"movement": movement,
		"input": input,
		"brain": brain,
		"move_target_component": move_target_component,
	}

func test_non_ai_entity_moves_toward_target() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var entity: Dictionary = _add_entity(fixture, "E_NonAI", false, true)
	if entity.is_empty():
		return
	var body: FakeBody = entity.get("body", null) as FakeBody
	var input: C_InputComponent = entity.get("input", null) as C_InputComponent
	var move_target: Variant = entity.get("move_target_component", null)
	var system: BaseECSSystem = fixture.get("system", null) as BaseECSSystem

	body.global_position = Vector3.ZERO
	move_target.set("is_active", true)
	move_target.set("target_position", Vector3(10.0, 0.0, 0.0))
	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 1.0, 0.01)
	assert_almost_eq(input.move_vector.y, 0.0, 0.01)

func test_writes_zero_move_vector_within_arrival_threshold() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var entity: Dictionary = _add_entity(fixture, "E_NonAI", false, true)
	if entity.is_empty():
		return
	var body: FakeBody = entity.get("body", null) as FakeBody
	var input: C_InputComponent = entity.get("input", null) as C_InputComponent
	var move_target: Variant = entity.get("move_target_component", null)
	var system: BaseECSSystem = fixture.get("system", null) as BaseECSSystem

	body.global_position = Vector3(2.0, 0.0, 3.0)
	move_target.set("is_active", true)
	move_target.set("target_position", Vector3(2.1, 0.0, 3.0))
	move_target.set("arrival_threshold", 0.25)
	input.set_move_vector(Vector2(0.75, -0.25))
	system.process_tick(0.016)

	assert_eq(input.move_vector, Vector2.ZERO)

func test_reads_ai_brain_task_state_when_move_target_component_absent_back_compat() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var entity: Dictionary = _add_entity(fixture, "E_AIAgent", true, false)
	if entity.is_empty():
		return
	var body: FakeBody = entity.get("body", null) as FakeBody
	var input: C_InputComponent = entity.get("input", null) as C_InputComponent
	var brain: Variant = entity.get("brain", null)
	var system: BaseECSSystem = fixture.get("system", null) as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {U_AITaskStateKeys.MOVE_TARGET: Vector3(0.0, 0.0, 8.0)}
	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 0.0, 0.01)
	assert_almost_eq(input.move_vector.y, 1.0, 0.01)

func test_prefers_move_target_component_when_both_sources_present() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var entity: Dictionary = _add_entity(fixture, "E_AIAgent", true, true)
	if entity.is_empty():
		return
	var body: FakeBody = entity.get("body", null) as FakeBody
	var input: C_InputComponent = entity.get("input", null) as C_InputComponent
	var brain: Variant = entity.get("brain", null)
	var move_target: Variant = entity.get("move_target_component", null)
	var system: BaseECSSystem = fixture.get("system", null) as BaseECSSystem

	body.global_position = Vector3.ZERO
	brain.task_state = {U_AITaskStateKeys.MOVE_TARGET: Vector3(0.0, 0.0, 10.0)}
	move_target.set("is_active", true)
	move_target.set("target_position", Vector3(10.0, 0.0, 0.0))
	move_target.set("arrival_threshold", 0.5)
	system.process_tick(0.016)

	assert_almost_eq(input.move_vector.x, 1.0, 0.01)
	assert_almost_eq(input.move_vector.y, 0.0, 0.01)

func test_per_entity_throttle_honored() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture.get("system", null) as BaseECSSystem
	system.set("navigation_throttle_interval", 0.3)

	var entity_a: Dictionary = _add_entity(fixture, "E_AgentA", false, true)
	if entity_a.is_empty():
		return
	var body_a: FakeBody = entity_a.get("body", null) as FakeBody
	var input_a: C_InputComponent = entity_a.get("input", null) as C_InputComponent
	var move_target_a: Variant = entity_a.get("move_target_component", null)

	body_a.global_position = Vector3.ZERO
	move_target_a.set("is_active", true)
	move_target_a.set("target_position", Vector3(10.0, 0.0, 0.0))
	input_a.set_move_vector(Vector2(-0.4, -0.6))

	system.process_tick(0.2)
	assert_eq(input_a.move_vector, Vector2(-0.4, -0.6), "Entity A should be throttled on first partial tick")

	var entity_b: Dictionary = _add_entity(fixture, "E_AgentB", false, true)
	if entity_b.is_empty():
		return
	var body_b: FakeBody = entity_b.get("body", null) as FakeBody
	var input_b: C_InputComponent = entity_b.get("input", null) as C_InputComponent
	var move_target_b: Variant = entity_b.get("move_target_component", null)

	body_b.global_position = Vector3.ZERO
	move_target_b.set("is_active", true)
	move_target_b.set("target_position", Vector3(0.0, 0.0, 10.0))
	input_b.set_move_vector(Vector2(0.2, -0.9))

	system.process_tick(0.15)
	assert_almost_eq(input_a.move_vector.x, 1.0, 0.01, "Entity A should update after accumulated interval")
	assert_almost_eq(input_a.move_vector.y, 0.0, 0.01, "Entity A should update after accumulated interval")
	assert_eq(input_b.move_vector, Vector2(0.2, -0.9), "Entity B should still be throttled on its first partial tick")
