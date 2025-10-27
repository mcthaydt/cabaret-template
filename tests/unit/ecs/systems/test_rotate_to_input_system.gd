extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const InputComponentScript := preload("res://scripts/ecs/components/c_input_component.gd")
const RotateComponentScript := preload("res://scripts/ecs/components/c_rotate_to_input_component.gd")
const RotateSystemScript := preload("res://scripts/ecs/systems/s_rotate_to_input_system.gd")

func _pump() -> void:
	await get_tree().process_frame

func _setup_context() -> Dictionary:
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()
	
	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_RotateInputTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var input: C_InputComponent = InputComponentScript.new()
	entity.add_child(input)
	await _pump()

	var target := Node3D.new()
	entity.add_child(target)
	await _pump()

	var component: C_RotateToInputComponent = RotateComponentScript.new()
	component.settings = RS_RotateToInputSettings.new()
	entity.add_child(component)
	await _pump()

	component.target_node_path = component.get_path_to(target)

	var system := RotateSystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"input": input,
		"target": target,
		"component": component,
		"system": system,
	}

func test_rotates_right_input_to_positive_x() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]

	input.set_move_vector(Vector2.RIGHT)
	manager._physics_process(1.0)

	var expected := -PI / 2.0
	assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

func test_rotates_left_input_to_negative_x() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]

	input.set_move_vector(Vector2.LEFT)
	manager._physics_process(1.0)

	var expected := PI / 2.0
	assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

func test_rotate_component_has_no_input_nodepath_export() -> void:
	var component: C_RotateToInputComponent = RotateComponentScript.new()
	component.settings = RS_RotateToInputSettings.new()
	add_child(component)
	autofree(component)
	await _pump()

	var has_input_property := false
	for property in component.get_property_list():
		if property.name == "input_component_path":
			has_input_property = true
			break
	assert_false(has_input_property, "C_RotateToInputComponent should not expose input_component_path.")
