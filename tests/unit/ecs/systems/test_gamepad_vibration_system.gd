extends BaseTest

const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const S_GamepadVibrationSystem := preload("res://scripts/ecs/systems/s_gamepad_vibration_system.gd")
const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

var _store: M_StateStore

func before_each() -> void:
	U_ECSEventBus.reset()

func after_each() -> void:
	_store = null

func test_entity_landing_triggers_vibration() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var component: C_GamepadComponent = context["component"]
	var mock: MockVibration = context["mock"] as MockVibration
	var system: S_GamepadVibrationSystem = context["system"]

	var body := _make_player_body()
	U_ECSEventBus.publish(StringName("entity_landed"), {"entity": body})
	await wait_physics_frames(2)

	assert_eq(mock.start_calls.size(), 1, "Landing should trigger vibration")

func test_damage_action_triggers_medium_vibration() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var mock: MockVibration = context["mock"] as MockVibration

	_store.dispatch(U_GameplayActions.take_damage("E_Player", 15.0))
	await _pump()

	assert_eq(mock.start_calls.size(), 1, "Damage should trigger vibration")

func test_vibration_disabled_blocks_events() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var mock: MockVibration = context["mock"] as MockVibration

	_store.dispatch(U_InputActions.toggle_vibration(false))
	await _pump()

	var body := _make_player_body()
	U_ECSEventBus.publish(StringName("entity_landed"), {"entity": body})
	assert_eq(mock.start_calls.size(), 0, "Disabled vibration should skip rumble")

func test_entity_death_event_triggers_vibration() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var mock: MockVibration = context["mock"] as MockVibration

	U_ECSEventBus.publish(StringName("entity_death"), {
		"entity_id": StringName("player"),
		"previous_health": 10.0,
		"new_health": 0.0,
		"is_dead": true,
	})
	await wait_physics_frames(2)

	assert_eq(mock.start_calls.size(), 1, "Death event should trigger vibration")

## Test that vibration does NOT trigger when using keyboard/mouse
## This verifies the fix where vibration only triggers for gamepad input
func test_vibration_blocked_when_keyboard_mouse_active() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var device_manager: M_InputDeviceManager = context["device_manager"]
	var mock: MockVibration = context["mock"] as MockVibration

	# Given: Active device is keyboard/mouse (device_type = 0)
	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.physical_keycode = KEY_Z
	device_manager._input(keyboard_event)
	await _pump()

	# When: Landing event occurs (would normally trigger vibration)
	var body := _make_player_body()
	U_ECSEventBus.publish(StringName("entity_landed"), {"entity": body})
	await wait_physics_frames(2)

	# Then: No vibration should trigger (keyboard/mouse doesn't vibrate)
	assert_eq(mock.start_calls.size(), 0,
		"Vibration should not trigger when keyboard/mouse is active device")

## Test that vibration DOES trigger when gamepad is active
func test_vibration_triggers_when_gamepad_active() -> void:
	var context := await _setup_system()
	autofree_context(context)
	var device_manager: M_InputDeviceManager = context["device_manager"]
	var mock: MockVibration = context["mock"] as MockVibration

	# Given: Active device is gamepad (device_type = 1)
	var motion := InputEventJoypadMotion.new()
	motion.device = 1
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.6
	device_manager._input(motion)
	await _pump()

	# When: Landing event occurs
	var body := _make_player_body()
	U_ECSEventBus.publish(StringName("entity_landed"), {"entity": body})
	await wait_physics_frames(2)

	# Then: Vibration should trigger (gamepad is active)
	assert_eq(mock.start_calls.size(), 1,
		"Vibration should trigger when gamepad is active device")

func _setup_system() -> Dictionary:
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(_store)
	await _pump()

	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await _pump()

	var entity := Node3D.new()
	entity.name = "E_TestEntity"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var component := C_GamepadComponent.new()
	component.device_id = 1
	entity.add_child(component)
	await _pump()
	await _pump()  # Wait extra frame for deferred component registration

	var mock := MockVibration.new()
	component.set_vibration_callables(Callable(mock, "record"), Callable())

	var system := S_GamepadVibrationSystem.new()
	system.state_store = _store  # Inject store to avoid ServiceLocator dependency in tests
	manager.add_child(system)
	await _pump()
	await _pump()  # Wait extra frame for deferred system registration
	await wait_physics_frames(2)

	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(device_manager)
	await _pump()

	device_manager._on_joy_connection_changed(1, true)
	await _pump()

	var activation_motion := InputEventJoypadMotion.new()
	activation_motion.device = 1
	activation_motion.axis = JOY_AXIS_LEFT_X
	activation_motion.axis_value = 0.3
	device_manager._input(activation_motion)
	await _pump()

	_store.dispatch(U_InputActions.toggle_vibration(true))  # Enable vibration
	await _pump()
	await wait_physics_frames(2)

	return {
		"manager": manager,
		"component": component,
		"system": system,
		"mock": mock,
		"device_manager": device_manager,
	}

func _pump() -> void:
	await get_tree().process_frame

func _make_player_body() -> Node3D:
	var base_entity := preload("res://scripts/ecs/base_ecs_entity.gd").new()
	base_entity.name = "E_Player"
	add_child_autofree(base_entity)
	var body := Node3D.new()
	body.name = "Body"
	base_entity.add_child(body)
	# Ensure the node is fully in the tree before events are published.
	body.set_physics_process(false)
	return body

class MockVibration:
	var start_calls: Array = []

	func record(device_id: int, weak: float, strong: float, duration: float) -> void:
		start_calls.append({
			"device_id": device_id,
			"weak": weak,
			"strong": strong,
			"duration": duration,
		})
