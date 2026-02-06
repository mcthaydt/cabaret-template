extends BaseTest

const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const DEFAULT_BOOT_STATE := preload("res://resources/state/cfg_default_boot_initial_state.tres")
const DEFAULT_MENU_STATE := preload("res://resources/state/cfg_default_menu_initial_state.tres")
const DEFAULT_GAMEPLAY_STATE := preload("res://resources/state/cfg_default_gameplay_initial_state.tres")
const DEFAULT_SCENE_STATE := preload("res://resources/state/cfg_default_scene_initial_state.tres")
const DEFAULT_SETTINGS_STATE := preload("res://resources/state/cfg_default_settings_initial_state.tres")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/managers/m_input_device_manager.gd")
const S_INPUT_SYSTEM := preload("res://scripts/ecs/systems/s_input_system.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const ECSEntity := preload("res://scripts/ecs/base_ecs_entity.gd")

func before_each() -> void:
	U_STATE_HANDOFF.clear_all()

func after_each() -> void:
	U_STATE_HANDOFF.clear_all()
	# Call parent to clear ServiceLocator
	super.after_each()

func test_state_store_discovery_via_utils() -> void:
	var store: M_StateStore = await _spawn_state_store()
	var found: M_StateStore = U_StateUtils.get_store(self)
	assert_not_null(found, "Store should be discoverable via U_StateUtils")
	assert_eq(found, store)
	await _cleanup_node(store)

func test_service_locator_registers_manager() -> void:
	var manager: Node = Node.new()
	manager.name = "M_TestManager"
	add_child(manager)
	autofree(manager)

	U_ServiceLocator.register(StringName("test_manager"), manager)
	var found: Node = U_ServiceLocator.try_get_service(StringName("test_manager"))
	assert_eq(found, manager, "ServiceLocator should return registered manager")

func test_ecs_component_auto_registers_with_manager() -> void:
	var ecs_manager: M_ECSManager = M_ECSManager.new()
	add_child(ecs_manager)
	autofree(ecs_manager)
	await get_tree().process_frame

	var entity: ECSEntity = ECSEntity.new()
	ecs_manager.add_child(entity)
	autofree(entity)

	var component: C_InputComponent = C_InputComponent.new()
	entity.add_child(component)
	autofree(component)
	await get_tree().process_frame

	var components: Array = ecs_manager.get_components(C_InputComponent.COMPONENT_TYPE)
	assert_eq(components.size(), 1, "Manager should register component automatically")
	assert_eq(components[0], component)

func test_state_dispatch_and_selectors_round_trip() -> void:
	var store: M_StateStore = await _spawn_state_store()
	var move_input: Vector2 = Vector2(0.5, -0.25)
	store.dispatch(U_InputActions.update_move_input(move_input))
	var state: Dictionary = store.get_state()
	var selected: Vector2 = U_InputSelectors.get_move_input(state)
	assert_almost_eq(selected.x, move_input.x, 0.0001)
	assert_almost_eq(selected.y, move_input.y, 0.0001)
	await _cleanup_node(store)

func test_input_settings_persist_across_state_handoff() -> void:
	var store: M_StateStore = await _spawn_state_store()
	store.dispatch(U_InputActions.profile_switched("accessibility"))
	store.dispatch(U_InputActions.update_mouse_sensitivity(1.85))
	store.call("_preserve_to_handoff")
	await _cleanup_node(store)

	var restored_store: M_StateStore = await _spawn_state_store()
	var state: Dictionary = restored_store.get_state()
	var settings_slice: Dictionary = state.get("settings", {})
	var input_settings: Dictionary = settings_slice.get("input_settings", {})
	assert_eq(input_settings.get("active_profile_id", ""), "accessibility")
	assert_almost_eq(float(input_settings.get("mouse_settings", {}).get("sensitivity", 0.0)), 1.85, 0.0001)
	await _cleanup_node(restored_store)

func test_gameplay_input_resets_between_scene_transitions() -> void:
	var store: M_StateStore = await _spawn_state_store()
	store.dispatch(U_InputActions.update_move_input(Vector2(0.3, -0.6)))
	store.dispatch(U_InputActions.update_jump_state(true, true))
	store.call("_preserve_to_handoff")
	await _cleanup_node(store)

	var restored_store: M_StateStore = await _spawn_state_store()
	var state: Dictionary = restored_store.get_state()
	var gameplay_slice: Dictionary = state.get("gameplay", {})
	assert_eq(gameplay_slice.get("move_input", Vector2.ONE), Vector2.ZERO)
	var nested_input: Dictionary = gameplay_slice.get("input", {})
	assert_eq(nested_input.get("move_input", Vector2.ONE), Vector2.ZERO)
	assert_false(nested_input.get("jump_pressed", true))
	assert_false(nested_input.get("jump_just_pressed", true))
	await _cleanup_node(restored_store)

func test_input_system_end_to_end_updates_store_and_component() -> void:
	_ensure_default_actions()
	var store: M_StateStore = await _spawn_state_store()

	# Create M_InputDeviceManager (required by S_InputSystem for input sources)
	var input_device_manager: M_InputDeviceManager = M_INPUT_DEVICE_MANAGER.new()
	add_child(input_device_manager)
	autofree(input_device_manager)
	await get_tree().process_frame

	# Register input_device_manager with ServiceLocator so systems can find it
	U_ServiceLocator.register(StringName("input_device_manager"), input_device_manager)

	var manager: M_ECSManager = M_ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var entity: ECSEntity = ECSEntity.new()
	entity.name = "E_TestInput"
	manager.add_child(entity)
	autofree(entity)
	await get_tree().process_frame

	var component: C_InputComponent = C_INPUT_COMPONENT.new()
	entity.add_child(component)
	await get_tree().process_frame

	var system: S_InputSystem = S_INPUT_SYSTEM.new()
	system.state_store = store
	manager.add_child(system)
	await get_tree().process_frame

	Input.action_press("move_right")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("jump")

	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(4.0, -1.5)
	# Input events are handled by M_InputDeviceManager which delegates to input sources
	input_device_manager._input(mouse_motion)

	manager._physics_process(0.016)

	var gameplay: Dictionary = store.get_state().get("gameplay", {})
	var input_state: Dictionary = gameplay.get("input", {})
	assert_almost_eq((input_state.get("move_input", Vector2.ZERO) as Vector2).length(), 1.0, 0.01)
	assert_true(input_state.get("jump_pressed", false))
	assert_true(input_state.get("sprint_pressed", false))
	var look_vector: Vector2 = input_state.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_vector.x, 4.0, 0.001)
	assert_almost_eq(look_vector.y, -1.5, 0.001)
	assert_almost_eq(component.move_vector.length(), 1.0, 0.01)
	assert_true(component.jump_pressed)
	assert_true(component.sprint_pressed)

	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("jump")
	await _cleanup_node(manager)
	await _cleanup_node(store)

func _spawn_state_store() -> M_StateStore:
	var store: M_StateStore = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	store.settings = test_settings
	store.boot_initial_state = DEFAULT_BOOT_STATE
	store.menu_initial_state = DEFAULT_MENU_STATE
	store.gameplay_initial_state = DEFAULT_GAMEPLAY_STATE
	store.scene_initial_state = DEFAULT_SCENE_STATE
	store.settings_initial_state = DEFAULT_SETTINGS_STATE
	add_child(store)
	autofree(store)
	await get_tree().process_frame
	return store

func _cleanup_node(node: Node) -> void:
	if node == null:
		return
	node.queue_free()
	await get_tree().process_frame

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
