extends BaseTest

const ECS_MANAGER = preload("res://scripts/ecs/m_ecs_manager.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const InputSystemScript = preload("res://scripts/ecs/systems/s_input_system.gd")

func before_all() -> void:
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("move_forward")
	_ensure_action("move_backward")
	_ensure_action("jump")
	_ensure_action("sprint")

func after_each() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("jump")
	Input.action_release("sprint")

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity() -> Dictionary:
	var manager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var component: C_InputComponent = InputComponentScript.new()
	add_child(component)
	await _pump()

	var system = InputSystemScript.new()
	add_child(system)
	await _pump()

	return {
		"manager": manager,
		"component": component,
		"system": system,
	}

func test_input_system_updates_move_vector_from_actions() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var system: S_InputSystem = context["system"] as S_InputSystem

	Input.action_press("move_right")
	Input.action_press("move_forward")

	system._physics_process(0.016)

	assert_almost_eq(component.move_vector.x, 0.7071, 0.01)
	assert_almost_eq(component.move_vector.y, -0.7071, 0.01)

func test_input_system_sets_jump_flag_on_press() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var system: S_InputSystem = context["system"] as S_InputSystem

	Input.action_press("jump")

	system._physics_process(0.016)

	assert_true(component.jump_pressed)

func test_input_system_sets_sprint_flag_on_press() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var system: S_InputSystem = context["system"] as S_InputSystem

	Input.action_press("sprint")

	system._physics_process(0.016)

	assert_true(component.sprint_pressed)

func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
