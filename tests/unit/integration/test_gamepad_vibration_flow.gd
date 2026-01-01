extends GutTest

const M_ECSManager := preload("res://scripts/managers/m_ecs_manager.gd")
const S_InputSystem := preload("res://scripts/ecs/systems/s_input_system.gd")
const S_GamepadVibrationSystem := preload("res://scripts/ecs/systems/s_gamepad_vibration_system.gd")
const C_InputComponent := preload("res://scripts/ecs/components/c_input_component.gd")
const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const DEFAULT_GAMEPAD_SETTINGS := preload("res://resources/input/gamepad_settings/default_gamepad_settings.tres")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_landing_event_triggers_vibration_end_to_end() -> void:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await _pump()

	var manager := M_ECSManager.new()
	add_child_autofree(manager)
	await _pump()

	var entity := TestEntity.new()
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var input_component := C_InputComponent.new()
	entity.add_child(input_component)
	await _pump()

	var gamepad_component := C_GamepadComponent.new()
	gamepad_component.settings = DEFAULT_GAMEPAD_SETTINGS.duplicate(true)
	gamepad_component.device_id = 2  # Match the device ID used in motion events
	entity.add_child(gamepad_component)
	await _pump()
	await _pump()  # Wait extra frame for deferred component registration

	var vibration_mock := MockVibration.new()
	gamepad_component.set_vibration_callables(Callable(vibration_mock, "record"), Callable())

	var input_system := S_InputSystem.new()
	manager.add_child(input_system)
	await _pump()

	var device_manager := M_InputDeviceManager.new()
	add_child_autofree(device_manager)
	await _pump()

	var vibration_system := S_GamepadVibrationSystem.new()
	manager.add_child(vibration_system)
	await _pump()
	await _pump()  # Wait extra frame for deferred system registration
	await wait_physics_frames(2)

	# Simulate gamepad connection and motion
	device_manager._on_joy_connection_changed(2, true)
	await _pump()
	store.dispatch(U_InputActions.toggle_vibration(true))  # Enable vibration
	var motion := InputEventJoypadMotion.new()
	motion.device = 2
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.5
	# device_manager._input() delegates to gamepad source, no need to call input_system._input()
	device_manager._input(motion)
	manager._physics_process(0.016)
	await wait_physics_frames(1) # Allow state to propagate to vibration system

	# Publish landing event for the player
	var body := Node3D.new()
	autofree(body)
	body.set_meta("entity_id", "E_Player")
	U_ECSEventBus.publish(StringName("entity_landed"), {"entity": body})
	await wait_physics_frames(2) # Allow event to be processed

	assert_gt(vibration_mock.start_calls.size(), 0, "Landing should trigger vibration through both systems")

func _pump() -> void:
	await get_tree().process_frame

class TestEntity extends Node3D:
	func _init() -> void:
		name = "E_TestEntity"

class MockVibration:
	var start_calls: Array = []

	func record(device_id: int, weak: float, strong: float, duration: float) -> void:
		start_calls.append({
			"device_id": device_id,
			"weak": weak,
			"strong": strong,
			"duration": duration,
		})
