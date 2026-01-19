extends BaseTest

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const S_InputSystem := preload("res://scripts/ecs/systems/s_input_system.gd")
const C_InputComponent := preload("res://scripts/ecs/components/c_input_component.gd")
const U_StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

func before_each() -> void:
	U_StateHandoff.clear_all()
	_ensure_default_actions()

func after_each() -> void:
	U_StateHandoff.clear_all()
	# Call parent to clear ServiceLocator
	super.after_each()

func test_keyboard_to_gamepad_switch_updates_store_and_component() -> void:
	var ctx := await _setup_environment()
	var device_manager: M_InputDeviceManager = ctx["device_manager"]
	var ecs_manager: M_ECSManager = ctx["ecs_manager"]
	var store: M_StateStore = ctx["store"]
	var component: C_InputComponent = ctx["component"]

	device_manager._on_joy_connection_changed(1, true)
	await _pump()

	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_Q
	device_manager._input(keyboard_event)
	await _pump()

	var motion := InputEventJoypadMotion.new()
	motion.device = 1
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.65
	device_manager._input(motion)
	await _pump()

	ecs_manager._physics_process(0.016)

	var input_slice := _get_input_slice(store)
	assert_eq(input_slice.get("active_device", -1), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(input_slice.get("gamepad_device_id", -1), 1)
	assert_true(input_slice.get("gamepad_connected", false))
	assert_eq(component.device_type, C_InputComponent.DeviceType.GAMEPAD)

func test_hotplug_updates_connection_state_without_forcing_device_switch() -> void:
	var ctx := await _setup_environment()
	var device_manager: M_InputDeviceManager = ctx["device_manager"]
	var ecs_manager: M_ECSManager = ctx["ecs_manager"]
	var store: M_StateStore = ctx["store"]
	var component: C_InputComponent = ctx["component"]

	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_R
	device_manager._input(keyboard_event)
	await _pump()

	device_manager._on_joy_connection_changed(5, true)
	await _pump()
	ecs_manager._physics_process(0.016)

	var connected_slice := _get_input_slice(store)
	assert_true(connected_slice.get("gamepad_connected", false))
	assert_eq(connected_slice.get("gamepad_device_id", -1), 5)
	assert_eq(connected_slice.get("active_device", -1), M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE)
	assert_eq(component.device_type, C_InputComponent.DeviceType.KEYBOARD_MOUSE)

	device_manager._on_joy_connection_changed(5, false)
	await _pump()
	ecs_manager._physics_process(0.016)

	var disconnected_slice := _get_input_slice(store)
	assert_false(disconnected_slice.get("gamepad_connected", true))
	assert_eq(disconnected_slice.get("gamepad_device_id", 99), -1)

func test_multi_gamepad_switch_prioritizes_latest_active_device() -> void:
	var ctx := await _setup_environment()
	var device_manager: M_InputDeviceManager = ctx["device_manager"]
	var ecs_manager: M_ECSManager = ctx["ecs_manager"]
	var store: M_StateStore = ctx["store"]

	device_manager._on_joy_connection_changed(0, true)
	device_manager._on_joy_connection_changed(2, true)
	await _pump()

	var motion_primary := InputEventJoypadMotion.new()
	motion_primary.device = 0
	motion_primary.axis = JOY_AXIS_RIGHT_X
	motion_primary.axis_value = 0.5
	device_manager._input(motion_primary)
	await _pump()
	ecs_manager._physics_process(0.016)

	var first_slice := _get_input_slice(store)
	assert_eq(first_slice.get("gamepad_device_id", -1), 0)

	var motion_secondary := InputEventJoypadMotion.new()
	motion_secondary.device = 2
	motion_secondary.axis = JOY_AXIS_RIGHT_Y
	motion_secondary.axis_value = -0.7
	device_manager._input(motion_secondary)
	await _pump()
	ecs_manager._physics_process(0.016)

	var second_slice := _get_input_slice(store)
	assert_eq(second_slice.get("active_device", -1), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(second_slice.get("gamepad_device_id", -1), 2)
	assert_eq(device_manager.get_gamepad_device_id(), 2)

func test_input_system_recovers_when_state_store_initializes_late() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.settings.enable_history = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await _pump()

	var ecs_manager := M_ECSManager.new()
	add_child_autofree(ecs_manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_DeviceRecovery"
	ecs_manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component := C_InputComponent.new()
	entity.add_child(component)
	await _pump()

	var system := S_InputSystem.new()
	system.state_store = store
	ecs_manager.add_child(system)
	await _pump()

	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(device_manager)
	await _pump()

	# Register input_device_manager with ServiceLocator so systems can find it
	U_ServiceLocator.register(StringName("input_device_manager"), device_manager)

	var motion := InputEventJoypadMotion.new()
	motion.device = 8
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.9
	device_manager._input(motion)
	await _pump()

	ecs_manager._physics_process(0.016)

	var input_slice := _get_input_slice(store)
	assert_eq(input_slice.get("active_device", -1), M_InputDeviceManager.DeviceType.GAMEPAD)
	assert_eq(component.device_type, C_InputComponent.DeviceType.GAMEPAD)

func _setup_environment() -> Dictionary:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.settings.enable_history = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await _pump()

	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(device_manager)
	await _pump()

	# Register input_device_manager with ServiceLocator so systems can find it
	U_ServiceLocator.register(StringName("input_device_manager"), device_manager)

	var ecs_manager := M_ECSManager.new()
	add_child_autofree(ecs_manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_DeviceDetection"
	ecs_manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component := C_InputComponent.new()
	entity.add_child(component)
	await _pump()

	var system := S_InputSystem.new()
	system.state_store = store
	ecs_manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"device_manager": device_manager,
		"ecs_manager": ecs_manager,
		"component": component,
		"system": system,
	}

func _get_input_slice(store: M_StateStore) -> Dictionary:
	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if gameplay_variant is Dictionary:
		var gameplay: Dictionary = gameplay_variant
		var input_variant: Variant = gameplay.get("input", {})
		if input_variant is Dictionary:
			return input_variant as Dictionary
	return {}

func _ensure_default_actions() -> void:
	_ensure_action(StringName("move_left"), KEY_A)
	_ensure_action(StringName("move_right"), KEY_D)
	_ensure_action(StringName("move_forward"), KEY_W)
	_ensure_action(StringName("move_backward"), KEY_S)
	_ensure_action(StringName("jump"), KEY_SPACE)
	_ensure_action(StringName("sprint"), KEY_SHIFT)

func _ensure_action(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if InputMap.action_get_events(action_name).is_empty():
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _pump() -> void:
	await get_tree().process_frame
