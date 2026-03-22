extends BaseTest

const MOBILE_CONTROLS_SCENE := preload("res://scenes/ui/hud/ui_mobile_controls.tscn")
const TOUCHSCREEN_SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn")

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BOOT_INITIAL_STATE := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_MENU_INITIAL_STATE := preload("res://scripts/resources/state/rs_menu_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_DEBUG_INITIAL_STATE := preload("res://scripts/resources/state/rs_debug_initial_state.gd")

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_INPUT_ACTIONS := preload("res://scripts/state/actions/u_input_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_TOUCHSCREEN_SYSTEM := preload("res://scripts/ecs/systems/s_touchscreen_system.gd")
const S_INPUT_SYSTEM := preload("res://scripts/ecs/systems/s_input_system.gd")
const S_VCAM_SYSTEM := preload("res://scripts/ecs/systems/s_vcam_system.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")

class VCamManagerStub extends I_VCamManager:
	var active_vcam_id: StringName = StringName("")
	var previous_vcam_id: StringName = StringName("")
	var blending: bool = false
	var submissions: Dictionary = {}

	func register_vcam(_vcam: Node) -> void:
		pass

	func unregister_vcam(_vcam: Node) -> void:
		pass

	func set_active_vcam(vcam_id: StringName, _blend_duration: float = -1.0) -> void:
		previous_vcam_id = active_vcam_id
		active_vcam_id = vcam_id

	func get_active_vcam_id() -> StringName:
		return active_vcam_id

	func get_previous_vcam_id() -> StringName:
		return previous_vcam_id

	func submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void:
		submissions[vcam_id] = result.duplicate(true)

	func get_blend_progress() -> float:
		return 0.0

	func is_blending() -> bool:
		return blending

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()

func after_each() -> void:
	U_STATE_HANDOFF.clear_all()
	super.after_each()

func test_drag_look_feeds_orbit_camera_through_shared_gameplay_look_input() -> void:
	var fixture := await _setup_mobile_vcam_fixture(_new_orbit_mode(), false)
	autofree_context(fixture)
	var controls: UI_MobileControls = fixture["controls"] as UI_MobileControls
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var store: M_StateStore = fixture["store"] as M_StateStore
	var component: C_VCamComponent = fixture["component"] as C_VCamComponent

	var start := _get_empty_space_position(controls)
	var finish := start + Vector2(18.0, -7.0)
	_drag_mobile_controls(controls, 30, start, finish)

	ecs_manager._physics_process(0.016)

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_input.x, 18.0, 0.001)
	assert_almost_eq(look_input.y, -7.0, 0.001)
	assert_true(absf(component.runtime_yaw) > 0.1, "Orbit runtime yaw should update from touchscreen look input")

func test_touchscreen_move_and_look_work_simultaneously_on_separate_touches() -> void:
	var fixture := await _setup_mobile_vcam_fixture(_new_orbit_mode(), false)
	autofree_context(fixture)
	var controls: UI_MobileControls = fixture["controls"] as UI_MobileControls
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var store: M_StateStore = fixture["store"] as M_StateStore
	var joystick: UI_VirtualJoystick = fixture["joystick"] as UI_VirtualJoystick

	_press_joystick(joystick, Vector2.ZERO, Vector2(joystick.joystick_radius, 0.0))
	var start := _get_empty_space_position(controls)
	var finish := start + Vector2(14.0, 4.0)
	_drag_mobile_controls(controls, 32, start, finish)

	ecs_manager._physics_process(0.016)

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var move_input: Vector2 = input_slice.get("move_input", Vector2.ZERO)
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_true(move_input.x > 0.5, "Joystick touch should still drive move input")
	assert_false(look_input.is_zero_approx(), "Second touch should drive look input simultaneously")

func test_input_system_does_not_clobber_touchscreen_owned_look_input() -> void:
	var fixture := await _setup_mobile_vcam_fixture(_new_orbit_mode(), true)
	autofree_context(fixture)
	var controls: UI_MobileControls = fixture["controls"] as UI_MobileControls
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var store: M_StateStore = fixture["store"] as M_StateStore

	var start := _get_empty_space_position(controls)
	var finish := start + Vector2(16.0, -6.0)
	_drag_mobile_controls(controls, 33, start, finish)

	ecs_manager._physics_process(0.016)

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_false(look_input.is_zero_approx(),
		"S_InputSystem should not overwrite touchscreen-owned look_input with zero payloads")

func test_touchscreen_settings_overlay_updates_drag_look_sensitivity() -> void:
	var fixture := await _setup_mobile_vcam_fixture(_new_orbit_mode(), false)
	autofree_context(fixture)
	var controls: UI_MobileControls = fixture["controls"] as UI_MobileControls
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var store: M_StateStore = fixture["store"] as M_StateStore

	var overlay := TOUCHSCREEN_SETTINGS_OVERLAY_SCENE.instantiate() as UI_TouchscreenSettingsOverlay
	add_child_autofree(overlay)
	await _await_frames(2)
	overlay._look_sensitivity_slider.value = 2.0
	overlay._apply_button.emit_signal("pressed")
	await _await_frames(1)
	if is_instance_valid(overlay):
		overlay.queue_free()
	store.dispatch(U_NAVIGATION_ACTIONS.start_game(StringName("alleyway")))
	store.dispatch(U_INPUT_ACTIONS.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(2)

	var start := _get_empty_space_position(controls)
	var finish := start + Vector2(10.0, 0.0)
	_drag_mobile_controls(controls, 34, start, finish)
	ecs_manager._physics_process(0.016)

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_almost_eq(look_input.x, 20.0, 0.001, "Applied overlay sensitivity should scale drag-look input")

func test_invert_look_y_flips_vertical_drag_direction() -> void:
	var fixture := await _setup_mobile_vcam_fixture(_new_orbit_mode(), false)
	autofree_context(fixture)
	var controls: UI_MobileControls = fixture["controls"] as UI_MobileControls
	var ecs_manager: M_ECSManager = fixture["ecs_manager"] as M_ECSManager
	var store: M_StateStore = fixture["store"] as M_StateStore

	store.dispatch(U_INPUT_ACTIONS.update_touchscreen_settings({
		"look_drag_sensitivity": 1.0,
		"invert_look_y": true,
	}))
	await _await_frames(1)

	var start := _get_empty_space_position(controls)
	var finish := start + Vector2(0.0, 6.0)
	_drag_mobile_controls(controls, 35, start, finish)
	ecs_manager._physics_process(0.016)

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var input_slice: Dictionary = gameplay_slice.get("input", {})
	var look_input: Vector2 = input_slice.get("look_input", Vector2.ZERO)
	assert_true(look_input.y < 0.0, "invert_look_y should flip positive drag Y to negative look_input.y")

func _setup_mobile_vcam_fixture(mode: Resource, include_input_system: bool) -> Dictionary:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BOOT_INITIAL_STATE.new()
	store.menu_initial_state = RS_MENU_INITIAL_STATE.new()
	var gameplay_initial := RS_GAMEPLAY_INITIAL_STATE.new()
	gameplay_initial.player_entity_id = "player"
	store.gameplay_initial_state = gameplay_initial
	var navigation_initial := RS_NAVIGATION_INITIAL_STATE.new()
	navigation_initial.shell = StringName("gameplay")
	navigation_initial.base_scene_id = StringName("alleyway")
	store.navigation_initial_state = navigation_initial
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.settings_initial_state = RS_SETTINGS_INITIAL_STATE.new()
	store.debug_initial_state = RS_DEBUG_INITIAL_STATE.new()
	add_child_autofree(store)
	await _await_store_ready(store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), store)

	var ecs_manager := M_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	await _await_frames(2)

	var input_entity := BASE_ECS_ENTITY.new()
	input_entity.name = "E_InputEntity"
	ecs_manager.add_child(input_entity)
	autofree(input_entity)
	var input_component := C_INPUT_COMPONENT.new()
	input_entity.add_child(input_component)
	autofree(input_component)

	var follow_target := BASE_ECS_ENTITY.new()
	follow_target.name = "E_Player"
	follow_target.entity_id = StringName("player")
	ecs_manager.add_child(follow_target)
	autofree(follow_target)

	var vcam_host := BASE_ECS_ENTITY.new()
	vcam_host.name = "E_CameraHost"
	ecs_manager.add_child(vcam_host)
	autofree(vcam_host)
	var vcam_component := C_VCAM_COMPONENT.new()
	vcam_component.vcam_id = StringName("cam_mobile")
	vcam_component.mode = mode
	vcam_component.follow_target_path = follow_target.get_path()
	vcam_host.add_child(vcam_component)
	autofree(vcam_component)

	var vcam_manager := VCamManagerStub.new()
	add_child_autofree(vcam_manager)
	vcam_manager.active_vcam_id = StringName("cam_mobile")
	U_SERVICE_LOCATOR.register(StringName("vcam_manager"), vcam_manager)

	var touchscreen_system := S_TOUCHSCREEN_SYSTEM.new()
	touchscreen_system.force_enable = true
	touchscreen_system.execution_priority = 10
	ecs_manager.add_child(touchscreen_system)
	autofree(touchscreen_system)

	if include_input_system:
		var input_system := S_INPUT_SYSTEM.new()
		input_system.execution_priority = 50
		ecs_manager.add_child(input_system)
		autofree(input_system)

	var vcam_system := S_VCAM_SYSTEM.new()
	vcam_system.execution_priority = 100
	ecs_manager.add_child(vcam_system)
	autofree(vcam_system)

	var controls := MOBILE_CONTROLS_SCENE.instantiate() as UI_MobileControls
	controls.force_enable = true
	add_child_autofree(controls)
	await _await_frames(3)

	store.dispatch(U_NAVIGATION_ACTIONS.start_game(StringName("alleyway")))
	store.dispatch(U_INPUT_ACTIONS.device_changed(M_InputDeviceManager.DeviceType.TOUCHSCREEN, -1))
	await _await_frames(2)

	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as UI_VirtualJoystick
	return {
		"store": store,
		"ecs_manager": ecs_manager,
		"controls": controls,
		"joystick": joystick,
		"vcam_manager": vcam_manager,
		"component": vcam_component,
	}

func _new_orbit_mode() -> RS_VCamModeOrbit:
	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.allow_player_rotation = true
	mode.lock_x_rotation = false
	mode.lock_y_rotation = false
	mode.rotation_speed = 1.0
	mode.distance = 5.0
	return mode

func _await_store_ready(store: M_StateStore) -> void:
	if store != null and not store.is_ready():
		await store.store_ready

func _await_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _get_empty_space_position(controls: UI_MobileControls) -> Vector2:
	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size
	var candidates := [
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.2),
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5),
		Vector2(viewport_size.x * 0.5, viewport_size.y * 0.75),
	]
	for candidate in candidates:
		if not _is_position_over_controls(controls, candidate):
			return candidate
	return candidates[0]

func _is_position_over_controls(controls: UI_MobileControls, position: Vector2) -> bool:
	var joystick := controls.get_node_or_null("Controls/VirtualJoystick") as Control
	if joystick != null and joystick.get_global_rect().has_point(position):
		return true
	for button in controls.get_buttons():
		if not (button is Control):
			continue
		if (button as Control).get_global_rect().has_point(position):
			return true
	return false

func _drag_mobile_controls(controls: UI_MobileControls, touch_id: int, start: Vector2, finish: Vector2) -> void:
	var pressed := InputEventScreenTouch.new()
	pressed.index = touch_id
	pressed.pressed = true
	pressed.position = start
	controls._input(pressed)

	var drag := InputEventScreenDrag.new()
	drag.index = touch_id
	drag.position = finish
	controls._input(drag)

func _press_joystick(joystick: UI_VirtualJoystick, start: Vector2, finish: Vector2) -> void:
	if joystick == null:
		return
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = start
	joystick._input(touch)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = finish
	joystick._input(drag)
