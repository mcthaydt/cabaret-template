extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const MovementComponentScript = preload("res://scripts/ecs/components/c_movement_component.gd")
const MovementSystemScript = preload("res://scripts/ecs/systems/s_movement_system.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const FloatingComponentScript = preload("res://scripts/ecs/components/c_floating_component.gd")
const VCamComponentScript = preload("res://scripts/ecs/components/c_vcam_component.gd")
const OTSModeScript = preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const OrbitModeScript = preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const U_VCAM_ACTIONS = preload("res://scripts/state/actions/u_vcam_actions.gd")
const ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

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
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()
	
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

	var floating: C_FloatingComponent = null
	if include_floating:
		floating = FloatingComponentScript.new()
		floating.settings = RS_FloatingSettings.new()
		entity.add_child(floating)
		await _pump()
		floating.character_body_path = floating.get_path_to(body)

	var system = MovementSystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
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
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	assert_eq(movement.get_character_body(), body)

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	manager._physics_process(0.1)

	assert_true(body.velocity.x > 0.0)
	assert_true(body.velocity.length() <= movement.settings.max_speed + 0.01)
	assert_true(body.move_called)

func test_movement_system_applies_sprint_multiplier_to_speed() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.sprint_speed_multiplier = 2.0
	movement.settings.acceleration = 100.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(true)

	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 10.0, 0.01)
	assert_true(movement.get_last_debug_snapshot()["is_sprinting"])

func test_movement_grounded_friction_reduces_velocity_quickly() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var floating: C_FloatingComponent = context["floating"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.grounded_friction = 40.0
	movement.settings.air_friction = 5.0
	movement.settings.strafe_friction_scale = 1.0
	movement.settings.forward_friction_scale = 1.0

	body.velocity = Vector3(6.0, 0.0, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	floating.update_support_state(true, now)

	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 0.0, 0.01)
	assert_true(movement.get_last_debug_snapshot()["supported"])

func test_movement_air_friction_is_gentler_without_support() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var floating: C_FloatingComponent = context["floating"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.grounded_friction = 40.0
	movement.settings.air_friction = 2.0
	movement.settings.strafe_friction_scale = 1.0
	movement.settings.forward_friction_scale = 1.0

	body.velocity = Vector3(6.0, 0.0, 0.0)
	var now: float = ECS_UTILS.get_current_time()
	floating.update_support_state(false, now - 1.0)

	manager._physics_process(0.1)

	assert_true(body.velocity.x > 0.5)
	assert_false(movement.get_last_debug_snapshot()["supported"])

func test_second_order_dynamics_dampens_more_when_grounded() -> void:
	var context: Dictionary = await _setup_entity(true)
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
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

	manager._physics_process(0.1)
	manager._physics_process(0.1)

	var grounded_velocity: float = body.velocity.x
	var grounded_debug: Dictionary = movement.get_last_debug_snapshot()

	input.set_move_vector(Vector2.ZERO)
	floating.update_support_state(false, now)
	floating.is_supported = false
	floating._last_support_time = now - (movement.settings.support_grace_time + 0.5)

	# reset for airborne case
	body.velocity = Vector3.ZERO
	movement.reset_dynamics_state()

	input.set_move_vector(Vector2.RIGHT)

	manager._physics_process(0.1)
	manager._physics_process(0.1)

	var air_velocity: float = body.velocity.x

	assert_true(abs(grounded_velocity) < abs(air_velocity))
	assert_true(grounded_debug["supported"])

func test_movement_system_applies_deceleration_when_no_input() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3(5, 0, 0)
	input.set_move_vector(Vector2.ZERO)

	manager._physics_process(0.1)

	assert_true(body.velocity.x < 5.0)
	assert_true(body.velocity.x >= 0.0)
	assert_true(body.move_called)

func test_movement_system_second_order_dynamics_response() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	movement.settings.use_second_order_dynamics = true
	movement.settings.response_frequency = 1.0
	movement.settings.damping_ratio = 0.5
	movement.settings.max_speed = 10.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 3.9478, 0.01)
	assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 39.478, 0.1)

func test_movement_second_order_settles_quickly_after_input_release() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	movement.settings.use_second_order_dynamics = true
	movement.settings.response_frequency = 1.0
	movement.settings.damping_ratio = 0.5
	movement.settings.max_speed = 10.0
	movement.settings.deceleration = 25.0

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	manager._physics_process(0.1)

	input.set_move_vector(Vector2.ZERO)

	manager._physics_process(0.1)

	assert_true(body.velocity.x <= 1.5)
	assert_almost_eq(movement.get_horizontal_dynamics_velocity().x, 0.0, 0.01)

func test_movement_system_processes_without_manual_wiring() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)

	manager._physics_process(0.1)

	assert_true(body.velocity.x > 0.0, "Movement System should use query_entities to retrieve input component without manual wiring.")

func test_ots_active_with_null_profile_uses_base_movement_settings() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.acceleration = 100.0
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(false)

	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.movement_profile = null
	ots_mode.disable_sprint = false
	await _create_vcam_component(manager, StringName("cam_ots_base"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_base"), "ots")
	body.velocity = Vector3.ZERO
	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 5.0, 0.01)

func test_ots_movement_profile_overrides_base_settings_when_active() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 6.0
	movement.settings.acceleration = 100.0
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(false)

	var profile := RS_MovementSettings.new()
	profile.max_speed = 2.5
	profile.acceleration = 100.0
	profile.use_second_order_dynamics = false

	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.movement_profile = profile
	ots_mode.disable_sprint = false
	await _create_vcam_component(manager, StringName("cam_ots_profile"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_profile"), "ots")

	body.velocity = Vector3.ZERO
	manager._physics_process(0.1)
	assert_almost_eq(body.velocity.x, 2.5, 0.01)

	body.velocity = Vector3.ZERO
	_set_active_vcam(store, StringName(""), "")
	manager._physics_process(0.1)
	assert_almost_eq(body.velocity.x, 6.0, 0.01)

func test_ots_disable_sprint_ignores_sprint_input() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.sprint_speed_multiplier = 2.0
	movement.settings.acceleration = 100.0
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(true)

	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.disable_sprint = true
	await _create_vcam_component(manager, StringName("cam_ots_disable_sprint"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_disable_sprint"), "ots")

	body.velocity = Vector3.ZERO
	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.x, 5.0, 0.01)
	assert_false(bool(movement.get_last_debug_snapshot().get("is_sprinting", true)))

func test_ots_uses_camera_relative_strafe_direction() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.acceleration = 100.0

	var camera := Camera3D.new()
	manager.add_child(camera)
	autofree(camera)
	await _pump()
	camera.current = true
	camera.global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, PI * 0.5), Vector3.ZERO)

	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	await _create_vcam_component(manager, StringName("cam_ots_camera_relative"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_camera_relative"), "ots")

	body.velocity = Vector3.ZERO
	input.set_move_vector(Vector2.RIGHT)
	manager._physics_process(0.1)

	var velocity_horizontal := Vector2(body.velocity.x, body.velocity.z).normalized()
	var expected_right: Vector3 = camera.global_transform.basis.x.normalized()
	var expected_horizontal := Vector2(expected_right.x, expected_right.z).normalized()
	assert_true(
		velocity_horizontal.distance_to(expected_horizontal) <= 0.05,
		"OTS strafe input should move along camera-right direction"
	)

func test_non_ots_active_mode_ignores_ots_movement_profile() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var movement: C_MovementComponent = context["movement"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	movement.settings.use_second_order_dynamics = false
	movement.settings.max_speed = 5.0
	movement.settings.sprint_speed_multiplier = 2.0
	movement.settings.acceleration = 100.0
	input.set_move_vector(Vector2.RIGHT)
	input.set_sprint_pressed(true)

	await _create_vcam_component(manager, StringName("cam_orbit_active"), OrbitModeScript.new())
	_set_active_vcam(store, StringName("cam_orbit_active"), "orbit")

	body.velocity = Vector3.ZERO
	manager._physics_process(0.1)
	assert_almost_eq(body.velocity.x, 10.0, 0.01)

func _create_vcam_component(manager: M_ECSManager, vcam_id: StringName, mode: Resource) -> C_VCamComponent:
	var entity := Node3D.new()
	entity.name = "E_%sVcam" % String(vcam_id)
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component := VCamComponentScript.new()
	component.vcam_id = vcam_id
	component.mode = mode
	entity.add_child(component)
	await _pump()
	return component

func _set_active_vcam(store: M_StateStore, vcam_id: StringName, mode: String) -> void:
	store.dispatch(U_VCAM_ACTIONS.set_active_runtime(vcam_id, mode))
