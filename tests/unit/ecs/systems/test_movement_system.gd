extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const MovementComponentScript = preload("res://scripts/ecs/components/c_movement_component.gd")
const MovementSystemScript = preload("res://scripts/ecs/systems/s_movement_system.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const FloatingComponentScript = preload("res://scripts/ecs/components/c_floating_component.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

class FakeBody extends CharacterBody3D:
	var move_called: bool = false
	var grounded: bool = false

	@warning_ignore("native_method_override")
	func move_and_slide() -> bool:
		move_called = true
		return super.move_and_slide()

	@warning_ignore("native_method_override")
	func is_on_floor() -> bool:
		return grounded

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity(include_floating: bool = false) -> Dictionary:
	var manager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_TestMovementEntity"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var movement = MovementComponentScript.new()
	movement.settings = RS_MovementSettings.new()
	entity.add_child(movement)
	await _pump()

	var input = InputComponentScript.new()
	entity.add_child(input)
	await _pump()

	var body: FakeBody = FakeBody.new()
	entity.add_child(body)
	await _pump()

	movement.character_body_path = movement.get_path_to(body)
	movement.input_component_path = movement.get_path_to(input)

	var floating: C_FloatingComponent = null
	if include_floating:
		floating = FloatingComponentScript.new()
		floating.settings = RS_FloatingSettings.new()
		entity.add_child(floating)
		await _pump()
		floating.character_body_path = floating.get_path_to(body)
		movement.support_component_path = movement.get_path_to(floating)

	var system = MovementSystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"manager": manager,
		"movement": movement,
		"input": input,
		"body": body,
		"system": system,
		"floating": floating,
	}

func test_movement_system_updates_velocity_towards_input() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement = context["movement"]
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	system._physics_process(0.1)

	assert_true(body.velocity.x > 0.0)
	assert_true(body.velocity.length() <= movement.settings.max_speed + 0.01)
	assert_true(body.move_called)

func test_movement_system_applies_sprint_multiplier_to_speed() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.sprint_speed_multiplier = 2.0
	movement.settings.acceleration = 100.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(true)

	system._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 10.0, 0.01)
	assert_true(movement.get_last_debug_snapshot()["is_sprinting"])

func test_movement_grounded_friction_reduces_velocity_quickly() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var body: FakeBody = context["body"]
	var system = context["system"]
	var floating: C_FloatingComponent = context["floating"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.grounded_friction = 40.0
	movement.settings.air_friction = 5.0
	movement.settings.strafe_friction_scale = 1.0
	movement.settings.forward_friction_scale = 1.0

	body.velocity = Vector3(6.0, 0.0, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	floating.update_support_state(true, now)

	system._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 0.0, 0.01)
	assert_true(movement.get_last_debug_snapshot()["supported"])

func test_movement_air_friction_is_gentler_without_support() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var body: FakeBody = context["body"]
	var system = context["system"]
	var floating: C_FloatingComponent = context["floating"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.grounded_friction = 40.0
	movement.settings.air_friction = 2.0
	movement.settings.strafe_friction_scale = 1.0
	movement.settings.forward_friction_scale = 1.0

	body.velocity = Vector3(6.0, 0.0, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	floating.update_support_state(false, now - 1.0)

	system._physics_process(0.1)

	assert_true(body.velocity.x > 0.5)
	assert_false(movement.get_last_debug_snapshot()["supported"])

func test_second_order_dynamics_dampens_more_when_grounded() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]
	var floating: C_FloatingComponent = context["floating"]

	movement.settings.use_second_order_dynamics = true
	movement.settings.response_frequency = 1.0
	movement.settings.damping_ratio = 0.5
	movement.settings.grounded_damping_multiplier = 2.0
	movement.settings.air_damping_multiplier = 0.5
	movement.settings.max_speed = 10.0
	# Ensure equal target magnitude in air and ground to isolate damping
	movement.settings.air_control_scale = 1.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	var now: float = ECS_UTILS.get_current_time()
	floating.update_support_state(true, now)

	system._physics_process(0.1)
	system._physics_process(0.1)

	var grounded_velocity: float = body.velocity.x
	var grounded_dyn: Vector2 = movement.get_horizontal_dynamics_velocity()
	var grounded_debug: Dictionary = movement.get_last_debug_snapshot()

	input.set_move_vector(Vector2.ZERO)
	floating.update_support_state(false, now)
	floating.is_supported = false
	floating._last_support_time = now - (movement.settings.support_grace_time + 0.5)

	# reset for airborne case
	body.velocity = Vector3.ZERO
	movement.reset_dynamics_state()

	input.set_move_vector(Vector2.RIGHT)

	system._physics_process(0.1)
	system._physics_process(0.1)

	var air_velocity: float = body.velocity.x
	var air_dyn: Vector2 = movement.get_horizontal_dynamics_velocity()
	var air_debug: Dictionary = movement.get_last_debug_snapshot()
	var expected_air_desired: float = movement.settings.max_speed * max(movement.settings.air_control_scale, 0.0)

	assert_true(abs(grounded_velocity) < abs(air_velocity))
	assert_true(grounded_debug["supported"])

func test_movement_system_applies_deceleration_when_no_input() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	body.velocity = Vector3(5, 0, 0)
	input.set_move_vector(Vector2.ZERO)

	system._physics_process(0.1)

	assert_true(body.velocity.x < 5.0)
	assert_true(body.velocity.x >= 0.0)
	assert_true(body.move_called)

func test_movement_system_second_order_dynamics_response() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement = context["movement"]
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	movement.settings.use_second_order_dynamics = true
	movement.settings.response_frequency = 1.0
	movement.settings.damping_ratio = 0.5
	movement.settings.max_speed = 10.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	system._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 3.9478, 0.01)
	assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 39.478, 0.1)

func test_movement_second_order_settles_quickly_after_input_release() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement = context["movement"]
	var input = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	movement.settings.use_second_order_dynamics = true
	movement.settings.response_frequency = 1.0
	movement.settings.damping_ratio = 0.5
	movement.settings.max_speed = 10.0
	movement.settings.deceleration = 25.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	system._physics_process(0.1)

	input.set_move_vector(Vector2.ZERO)

	system._physics_process(0.1)

	assert_true(body.velocity.x <= 1.5)
	assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 0.0, 0.01)

func test_movement_system_still_processes_without_input_nodepath_via_queries() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var system = context["system"]

	movement.input_component_path = NodePath()

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	system._physics_process(0.1)

	assert_true(body.velocity.x > 0.0, "Movement System should use query_entities to retrieve input component when NodePath is missing.")
