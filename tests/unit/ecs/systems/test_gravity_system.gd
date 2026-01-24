extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const GravitySystemScript = preload("res://scripts/ecs/systems/s_gravity_system.gd")
const MovementComponentScript = preload("res://scripts/ecs/components/c_movement_component.gd")
const FloatingComponentScript = preload("res://scripts/ecs/components/c_floating_component.gd")
const ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

class FakeBody extends CharacterBody3D:
	var grounded := false

	@warning_ignore("native_method_override")
	func is_on_floor() -> bool:
		return grounded

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity() -> Dictionary:
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()
	
	var manager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_GravityTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := FakeBody.new()
	entity.add_child(body)
	await _pump()

	var movement: C_MovementComponent = MovementComponentScript.new()
	movement.settings = RS_MovementSettings.new()
	entity.add_child(movement)
	await _pump()

	var system = GravitySystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"body": body,
		"movement": movement,
		"system": system,
	}

func test_gravity_system_accelerates_downward_when_not_on_floor() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var body: FakeBody = context["body"]

	body.velocity = Vector3.ZERO
	body.grounded = false

	var manager: M_ECSManager = context["manager"]
	manager._physics_process(0.1)

	assert_true(body.velocity.y < 0.0)

func test_gravity_system_skips_entities_with_floating_component() -> void:
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()
	
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_GravityFloatingTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := FakeBody.new()
	entity.add_child(body)
	await _pump()

	var movement: C_MovementComponent = MovementComponentScript.new()
	movement.settings = RS_MovementSettings.new()
	entity.add_child(movement)
	await _pump()

	var floating: C_FloatingComponent = FloatingComponentScript.new()
	floating.settings = RS_FloatingSettings.new()
	entity.add_child(floating)
	await _pump()
	floating.character_body_path = floating.get_path_to(body)

	var system := GravitySystemScript.new()
	manager.add_child(system)
	await _pump()

	body.velocity = Vector3.ZERO
	body.grounded = false
	floating.update_support_state(true, ECS_UTILS.get_current_time())

	manager._physics_process(0.1)

	assert_almost_eq(body.velocity.y, 0.0, 0.0001)
