extends GutTest

const ECS_MANAGER = preload("res://scripts/ecs/m_ecs_manager.gd")
const JumpComponentScript = preload("res://scripts/ecs/components/c_jump_component.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const JumpSystemScript = preload("res://scripts/ecs/systems/s_jump_system.gd")
const FloatingComponentScript = preload("res://scripts/ecs/components/c_floating_component.gd")

class FakeBody extends CharacterBody3D:
	var grounded := true

	@warning_ignore("native_method_override")
	func is_on_floor() -> bool:
		return grounded

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity(with_floating := false) -> Dictionary:
	var manager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var jump_component: C_JumpComponent = JumpComponentScript.new()
	jump_component.settings = RS_JumpSettings.new()
	add_child(jump_component)
	await _pump()

	var input = InputComponentScript.new()
	add_child(input)
	await _pump()

	var body := FakeBody.new()
	add_child(body)
	await _pump()

	jump_component.character_body_path = jump_component.get_path_to(body)
	jump_component.input_component_path = jump_component.get_path_to(input)

	var floating_component: C_FloatingComponent = null
	if with_floating:
		floating_component = FloatingComponentScript.new()
		floating_component.settings = RS_FloatingSettings.new()
		add_child(floating_component)
		await _pump()
		floating_component.character_body_path = floating_component.get_path_to(body)

	var system: S_JumpSystem = JumpSystemScript.new()
	add_child(system)
	await _pump()

	return {
		"manager": manager,
		"jump": jump_component,
		"input": input,
		"body": body,
		"system": system,
		"floating": floating_component,
	}

func test_jump_system_applies_vertical_velocity_when_jump_pressed() -> void:
	var context := await _setup_entity()
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var system: S_JumpSystem = context["system"]

	body.velocity = Vector3.ZERO
	body.grounded = true

	input.set_jump_pressed(true)

	system._physics_process(0.016)

	assert_true(body.velocity.y > 0.0)
	assert_eq(body.velocity.y, jump.settings.jump_force)

	await _cleanup(context)

func test_jump_system_allows_jump_when_supported_by_floating_component() -> void:
	var context := await _setup_entity(true)
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var floating: C_FloatingComponent = context["floating"]
	var system: S_JumpSystem = context["system"]

	body.velocity = Vector3.ZERO
	body.grounded = false

	var now := Time.get_ticks_msec() / 1000.0
	floating.update_support_state(true, now)

	input.set_jump_pressed(true)

	system._physics_process(0.016)

	assert_true(body.velocity.y > 0.0)
	assert_eq(body.velocity.y, jump.settings.jump_force)

	await _cleanup(context)

func test_jump_system_uses_jump_buffer() -> void:
	var context := await _setup_entity()
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var system: S_JumpSystem = context["system"]

	jump.settings.jump_buffer_time = 0.25
	body.velocity = Vector3.ZERO
	body.grounded = false

	var now := Time.get_ticks_msec() / 1000.0
	jump.mark_on_floor(now - jump.settings.coyote_time - 1.0)

	input.set_jump_pressed(true)

	system._physics_process(0.016)
	assert_eq(body.velocity.y, 0.0)

	body.grounded = true
	jump.mark_on_floor(now)
	system._physics_process(0.016)

	assert_eq(body.velocity.y, jump.settings.jump_force)

	await _cleanup(context)

func test_jump_respects_max_air_jumps_setting() -> void:
	var context := await _setup_entity()
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var system: S_JumpSystem = context["system"]

	jump.settings.max_air_jumps = 0
	body.velocity = Vector3.ZERO
	body.grounded = true

	input.set_jump_pressed(true)
	system._physics_process(0.016)

	assert_eq(body.velocity.y, jump.settings.jump_force)

	body.grounded = false
	body.velocity = Vector3.ZERO
	input.set_jump_pressed(true)
	system._physics_process(0.016)

	assert_eq(body.velocity.y, 0.0)

	await _cleanup(context)

func test_jump_component_tracks_apex_state() -> void:
	var context := await _setup_entity()
	var jump: C_JumpComponent = context["jump"]
	var input: C_InputComponent = context["input"]
	var body: FakeBody = context["body"]
	var system: S_JumpSystem = context["system"]

	body.velocity = Vector3.ZERO
	body.grounded = true
	input.set_jump_pressed(true)

	system._physics_process(0.016)

	assert_false(jump.has_recent_apex(Time.get_ticks_msec() / 1000.0))

	body.grounded = false
	body.velocity = Vector3(0.0, 0.2, 0.0)
	system._physics_process(0.016)

	body.velocity = Vector3(0.0, -0.05, 0.0)
	system._physics_process(0.016)

	var now := Time.get_ticks_msec() / 1000.0
	assert_true(jump.has_recent_apex(now))

	await _cleanup(context)

func _cleanup(context: Dictionary) -> void:
	for value in context.values():
		if value is Node:
			value.queue_free()
	await _pump()
