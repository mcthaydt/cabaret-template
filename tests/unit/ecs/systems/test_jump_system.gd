extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const JumpComponentScript = preload("res://scripts/ecs/components/c_jump_component.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const JumpSystemScript = preload("res://scripts/ecs/systems/s_jump_system.gd")
const FloatingComponentScript = preload("res://scripts/ecs/components/c_floating_component.gd")
const EventBus := preload("res://scripts/ecs/ecs_event_bus.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

class FakeBody extends CharacterBody3D:
	var grounded := true

	@warning_ignore("native_method_override")
	func is_on_floor() -> bool:
		return grounded

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity(with_floating := false) -> Dictionary:
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
	entity.name = "E_TestJumpEntity"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var jump_component: C_JumpComponent = JumpComponentScript.new()
	jump_component.settings = RS_JumpSettings.new()
	entity.add_child(jump_component)
	await _pump()

	var input = InputComponentScript.new()
	entity.add_child(input)
	await _pump()

	var body := FakeBody.new()
	entity.add_child(body)
	await _pump()

	jump_component.character_body_path = jump_component.get_path_to(body)
	var floating_component: C_FloatingComponent = null
	if with_floating:
		floating_component = FloatingComponentScript.new()
		floating_component.settings = RS_FloatingSettings.new()
		entity.add_child(floating_component)
		await _pump()
		floating_component.character_body_path = floating_component.get_path_to(body)

	var system: S_JumpSystem = JumpSystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"jump": jump_component,
		"input": input,
		"body": body,
		"system": system,
		"floating": floating_component,
	}

func test_jump_system_applies_vertical_velocity_when_jump_pressed() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	body.grounded = true

	input.set_jump_pressed(true)

	manager._physics_process(0.016)

	assert_true(body.velocity.y > 0.0)
	assert_eq(body.velocity.y, jump.settings.jump_force)

func test_jump_system_allows_jump_when_supported_by_floating_component() -> void:
	var context := await _setup_entity(true)
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var floating: C_FloatingComponent = context["floating"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	body.grounded = false

	var now := ECS_UTILS.get_current_time()
	floating.update_support_state(true, now)

	input.set_jump_pressed(true)

	manager._physics_process(0.016)

	assert_true(body.velocity.y > 0.0)
	assert_eq(body.velocity.y, jump.settings.jump_force)

func test_jump_system_uses_jump_buffer() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	jump.settings.jump_buffer_time = 0.25
	body.velocity = Vector3.ZERO
	body.grounded = false

	var now := ECS_UTILS.get_current_time()
	jump.mark_on_floor(now - jump.settings.coyote_time - 1.0)

	input.set_jump_pressed(true)

	manager._physics_process(0.016)
	assert_eq(body.velocity.y, 0.0)

	body.grounded = true
	jump.mark_on_floor(now)
	manager._physics_process(0.016)

	assert_eq(body.velocity.y, jump.settings.jump_force)

func test_jump_respects_max_air_jumps_setting() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	jump.settings.max_air_jumps = 0
	body.velocity = Vector3.ZERO
	body.grounded = true

	input.set_jump_pressed(true)
	manager._physics_process(0.016)

	assert_eq(body.velocity.y, jump.settings.jump_force)

	body.grounded = false
	body.velocity = Vector3.ZERO
	input.set_jump_pressed(true)
	manager._physics_process(0.016)

	assert_eq(body.velocity.y, 0.0)

func test_jump_component_tracks_apex_state() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	body.grounded = true
	input.set_jump_pressed(true)

	manager._physics_process(0.016)

	assert_false(jump.has_recent_apex(ECS_UTILS.get_current_time()))

	body.grounded = false
	body.velocity = Vector3(0.0, 0.2, 0.0)
	manager._physics_process(0.016)

	body.velocity = Vector3(0.0, -0.05, 0.0)
	manager._physics_process(0.016)

	var now := ECS_UTILS.get_current_time()
	assert_true(jump.has_recent_apex(now))

func test_jump_component_avoids_input_nodepath_exports() -> void:
	var jump_component: C_JumpComponent = JumpComponentScript.new()
	jump_component.settings = RS_JumpSettings.new()
	add_child(jump_component)
	autofree(jump_component)
	await _pump()

	var has_input_property := false
	for property in jump_component.get_property_list():
		if property.name == "input_component_path":
			has_input_property = true
			break
	assert_false(has_input_property, "C_JumpComponent should not expose input_component_path.")
	assert_false(jump_component.has_method("get_input_component"), "C_JumpComponent should not provide get_input_component().")

func test_jump_system_processes_without_manual_wiring() -> void:
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	body.grounded = true
	input.set_jump_pressed(true)

	manager._physics_process(0.016)

	assert_eq(body.velocity.y, jump.settings.jump_force)

func test_jump_system_publishes_entity_jumped_event() -> void:
	EventBus.reset()
	var context := await _setup_entity()
	autofree_context(context)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var manager: M_ECSManager = context["manager"]

	body.velocity = Vector3.ZERO
	body.grounded = true

	var received_events: Array = []
	var event_name := StringName("entity_jumped")
	var unsubscribe: Callable = EventBus.subscribe(
		event_name,
		func(event_data: Dictionary) -> void:
			received_events.append(event_data)
	)

	input.set_jump_pressed(true)

	manager._physics_process(0.016)

	unsubscribe.call()

	assert_eq(received_events.size(), 1)
	var event_data: Dictionary = received_events[0]
	assert_eq(event_data.get("name"), event_name)
	assert_true(event_data.has("timestamp"))
	assert_true(event_data["timestamp"] is float)

	var payload: Dictionary = event_data.get("payload")
	assert_eq(payload.get("entity"), body)
	assert_eq(payload.get("jump_component"), jump)
	assert_eq(payload.get("input_component"), input)
	assert_eq(payload.get("velocity"), body.velocity)
	EventBus.reset()
