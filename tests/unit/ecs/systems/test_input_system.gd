extends BaseTest

const ECS_MANAGER = preload("res://scripts/managers/m_ecs_manager.gd")
const InputComponentScript = preload("res://scripts/ecs/components/c_input_component.gd")
const InputSystemScript = preload("res://scripts/ecs/systems/s_input_system.gd")
const InputDeviceManagerScript = preload("res://scripts/managers/m_input_device_manager.gd")
const RS_SettingsInitialState = preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const U_StateHandoff = preload("res://scripts/state/utils/u_state_handoff.gd")
const U_InputActions = preload("res://scripts/state/actions/u_input_actions.gd")
const U_DeviceTypeConstants = preload("res://scripts/input/u_device_type_constants.gd")
const KeyboardMouseSource = preload("res://scripts/input/sources/keyboard_mouse_source.gd")
const GamepadSource = preload("res://scripts/input/sources/gamepad_source.gd")

func before_all() -> void:
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("move_forward")
	_ensure_action("move_backward")
	_ensure_action("jump")
	_ensure_action("sprint")

func before_each() -> void:
	U_StateHandoff.clear_all()  # Prevent StateHandoff pollution across tests (see DEV_PITFALLS)

func after_each() -> void:
	U_StateHandoff.clear_all()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("jump")
	Input.action_release("sprint")
	# Call parent to clear ServiceLocator
	super.after_each()

func _pump() -> void:
	await get_tree().process_frame

func _setup_entity() -> Dictionary:
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	store.settings = test_settings
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()

	# Create M_InputDeviceManager (required by S_InputSystem)
	var input_device_manager := InputDeviceManagerScript.new()
	add_child(input_device_manager)
	autofree(input_device_manager)
	await _pump()

	# Register input_device_manager with ServiceLocator so systems can find it
	U_ServiceLocator.register(StringName("input_device_manager"), input_device_manager)

	var manager = ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_InputTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component: C_InputComponent = InputComponentScript.new()
	entity.add_child(component)
	await _pump()

	var system = InputSystemScript.new()
	system.state_store = store
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"component": component,
		"system": system,
		"input_device_manager": input_device_manager,
	}

func test_input_system_updates_move_vector_from_actions() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	Input.action_press("move_right")
	Input.action_press("move_forward")

	manager._physics_process(0.016)

	assert_almost_eq(component.move_vector.x, 0.7071, 0.01)
	assert_almost_eq(component.move_vector.y, -0.7071, 0.01)

func test_input_system_sets_jump_flag_on_press() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	Input.action_press("jump")

	manager._physics_process(0.016)

	assert_true(component.jump_pressed)

func test_input_system_sets_sprint_flag_on_press() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var component: C_InputComponent = context["component"] as C_InputComponent
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	Input.action_press("sprint")

	manager._physics_process(0.016)

	assert_true(component.sprint_pressed)

func test_input_system_dispatches_state_updates_to_store() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var store: M_StateStore = context["store"] as M_StateStore
	var input_device_manager: M_InputDeviceManager = context["input_device_manager"] as M_InputDeviceManager

	Input.action_press("move_right")
	Input.action_press("move_forward")
	Input.action_press("jump")
	Input.action_press("sprint")

	# Simulate mouse motion through input device manager (it delegates to keyboard/mouse source)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(3.0, -2.0)
	input_device_manager._input(motion)

	manager._physics_process(0.016)

	var gameplay := store.get_slice(StringName("gameplay"))
	var input_state: Dictionary = gameplay.get("input", {})
	var move_vector: Vector2 = input_state.get("move_input", Vector2.ZERO)
	assert_almost_eq(move_vector.length(), 1.0, 0.01)
	assert_true(input_state.get("jump_pressed", false))
	assert_true(input_state.get("sprint_pressed", false))
	var look_vector: Vector2 = input_state.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_vector.x, 3.0, 0.001)
	assert_almost_eq(look_vector.y, -2.0, 0.001)

func test_mouse_sensitivity_updates_from_settings_slice() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var store: M_StateStore = context["store"] as M_StateStore
	var input_device_manager: M_InputDeviceManager = context["input_device_manager"] as M_InputDeviceManager

	# Initial tick to ensure store hookup
	var initial_motion := InputEventMouseMotion.new()
	initial_motion.relative = Vector2(1.0, 0.0)
	input_device_manager._input(initial_motion)
	manager._physics_process(0.016)

	store.dispatch(U_InputActions.update_mouse_sensitivity(2.5))
	await _pump()

	var second_motion := InputEventMouseMotion.new()
	second_motion.relative = Vector2(1.0, 0.0)
	input_device_manager._input(second_motion)
	manager._physics_process(0.016)

	var gameplay := store.get_slice(StringName("gameplay"))
	var input_state: Dictionary = gameplay.get("input", {})
	var look_vector: Vector2 = input_state.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_vector.x, 2.5, 0.0001)
	assert_almost_eq(look_vector.y, 0.0, 0.0001)

func test_gamepad_motion_updates_component_and_store() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var store: M_StateStore = context["store"] as M_StateStore
	var input_device_manager: M_InputDeviceManager = context["input_device_manager"] as M_InputDeviceManager
	var component: C_InputComponent = context["component"] as C_InputComponent

	store.dispatch(U_InputActions.gamepad_connected(9))
	store.dispatch(U_InputActions.device_changed(U_DeviceTypeConstants.DeviceType.GAMEPAD, 9))
	await _pump()

	var motion_x := InputEventJoypadMotion.new()
	motion_x.device = 9
	motion_x.axis = JOY_AXIS_LEFT_X
	motion_x.axis_value = 0.8
	input_device_manager._input(motion_x)
	var motion_y := InputEventJoypadMotion.new()
	motion_y.device = 9
	motion_y.axis = JOY_AXIS_LEFT_Y
	motion_y.axis_value = -0.6
	input_device_manager._input(motion_y)

	manager._physics_process(0.016)

	assert_true(component.move_vector.length() > 0.0)
	var gameplay: Dictionary = store.get_state().get("gameplay", {}) as Dictionary
	var input_slice: Dictionary = gameplay.get("input", {})
	assert_eq(input_slice.get("active_device", 0), U_DeviceTypeConstants.DeviceType.GAMEPAD)
	assert_eq(input_slice.get("gamepad_device_id", -1), 9)
	assert_true(input_slice.get("gamepad_connected", true))

func test_handle_gamepad_disconnected_resets_local_state_only() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var store: M_StateStore = context["store"] as M_StateStore
	var input_device_manager: M_InputDeviceManager = context["input_device_manager"] as M_InputDeviceManager
	var manager: M_ECSManager = context["manager"] as M_ECSManager

	store.dispatch(U_InputActions.gamepad_connected(3))
	store.dispatch(U_InputActions.device_changed(U_DeviceTypeConstants.DeviceType.GAMEPAD, 3))
	await _pump()

	var motion := InputEventJoypadMotion.new()
	motion.device = 3
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.5
	input_device_manager._input(motion)
	manager._physics_process(0.016)

	store.dispatch(U_InputActions.gamepad_disconnected(3))
	await _pump()
	manager._physics_process(0.016)

	var gameplay: Dictionary = store.get_state().get("gameplay", {}) as Dictionary
	var input_slice: Dictionary = gameplay.get("input", {})
	assert_eq(input_slice.get("active_device", 0), U_DeviceTypeConstants.DeviceType.GAMEPAD, "System should not force device change; manager handles it")
	assert_false(input_slice.get("gamepad_connected", true))
	assert_eq(input_slice.get("gamepad_device_id", 99), -1)

	# Verify gamepad source state is reset (state lives in source now, not system)
	var gamepad_source := input_device_manager.get_input_source_for_device(U_DeviceTypeConstants.DeviceType.GAMEPAD) as GamepadSource
	assert_not_null(gamepad_source)
	var button_states := gamepad_source.get_button_states()
	assert_true(button_states.is_empty())

func test_action_strengths_populated_on_components() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var component: C_InputComponent = context["component"] as C_InputComponent

	Input.action_press("move_right")
	manager._physics_process(0.016)

	assert_true(component.action_strengths.has(StringName("move")))
	assert_true(component.get_action_strength(StringName("move")) > 0.0)

func test_keyboard_input_does_not_dispatch_device_changed() -> void:
	var context: Dictionary = await _setup_entity()
	autofree_context(context)
	var manager: M_ECSManager = context["manager"] as M_ECSManager
	var store: M_StateStore = context["store"] as M_StateStore

	var dispatched_types: Array[StringName] = []
	store.action_dispatched.connect(func(action: Dictionary) -> void:
		if action.has("type"):
			dispatched_types.append(action["type"])
	)

	Input.action_press("move_left")
	manager._physics_process(0.016)

	assert_false(dispatched_types.has(U_InputActions.ACTION_DEVICE_CHANGED))

func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
