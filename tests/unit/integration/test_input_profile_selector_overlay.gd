extends GutTest

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const M_SceneManager := preload("res://scripts/managers/m_scene_manager.gd")
const M_CursorManager := preload("res://scripts/managers/m_cursor_manager.gd")
const M_SpawnManager := preload("res://scripts/managers/m_spawn_manager.gd")
const M_CameraManager := preload("res://scripts/managers/m_camera_manager.gd")
const M_InputProfileManager := preload("res://scripts/managers/m_input_profile_manager.gd")
const M_PauseManager := preload("res://scripts/managers/m_pause_manager.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _ui_overlay_stack: CanvasLayer
var _active_scene_container: Node
var _transition_overlay: CanvasLayer
var _cursor_manager: M_CursorManager
var _spawn_manager: M_SpawnManager
var _camera_manager: M_CameraManager
var _profile_manager: M_InputProfileManager
var _pause_system: M_PauseManager

const _DEBUG_LOGS: bool = false

func _one_line(value: Variant) -> String:
	var s := var_to_str(value)
	s = s.replace("\n", "\\n")
	s = s.replace("\t", "\\t")
	return s

func _debug_overlay_snapshot(context: String) -> void:
	if not _DEBUG_LOGS:
		return

	var overlay_names: Array[String] = []
	if _ui_overlay_stack != null and is_instance_valid(_ui_overlay_stack):
		for child in _ui_overlay_stack.get_children():
			overlay_names.append(String(child.name))

	var scene_state: Dictionary = {}
	if _store != null and is_instance_valid(_store):
		scene_state = _store.get_slice(StringName("scene"))

	var nav_state: Dictionary = {}
	if _store != null and is_instance_valid(_store):
		nav_state = _store.get_slice(StringName("navigation"))

	print("[test_input_profile_selector_overlay] %s paused=%s ui_stack=%s scene={id=%s transitioning=%s stack=%s} nav={shell=%s base=%s overlays=%s}" % [
		context,
		str(get_tree().paused),
		_one_line(overlay_names),
		str(scene_state.get("current_scene_id", StringName(""))),
		str(scene_state.get("is_transitioning", false)),
		_one_line(scene_state.get("scene_stack", [])),
		str(nav_state.get("shell", StringName(""))),
		str(nav_state.get("base_scene_id", StringName(""))),
		_one_line(nav_state.get("overlay_stack", [])),
	])

func before_each() -> void:
	# Clear ServiceLocator first to ensure clean state between tests
	U_ServiceLocator.clear()

	# Minimal scene tree for SceneManager overlays
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	_transition_overlay.add_child(color_rect)
	add_child_autofree(_transition_overlay)

	var loading_overlay := CanvasLayer.new()
	loading_overlay.name = "LoadingOverlay"
	add_child_autofree(loading_overlay)

	_cursor_manager = M_CursorManager.new()
	add_child_autofree(_cursor_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)

	_spawn_manager = M_SpawnManager.new()
	add_child_autofree(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)
	await get_tree().process_frame

	_camera_manager = M_CameraManager.new()
	add_child_autofree(_camera_manager)
	U_ServiceLocator.register(StringName("camera_manager"), _camera_manager)
	await get_tree().process_frame

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_profile_manager = M_InputProfileManager.new()
	add_child_autofree(_profile_manager)
	U_ServiceLocator.register(StringName("input_profile_manager"), _profile_manager)
	await get_tree().process_frame

	# Create M_PauseManager to apply pause based on scene state
	_pause_system = M_PauseManager.new()
	add_child_autofree(_pause_system)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)
	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

	get_tree().paused = false  # Reset pause state
	_store = null
	_ui_overlay_stack = null
	_active_scene_container = null
	_transition_overlay = null
	_profile_manager = null
	_pause_system = null

func test_pause_menu_opens_profile_selector_overlay() -> void:
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	U_ServiceLocator.register(StringName("scene_manager"), manager)
	await get_tree().process_frame

	await _start_game_and_pause()

	# Find pause menu node and press Settings, then InputProfilesButton in settings overlay
	if _ui_overlay_stack.get_child_count() == 0:
		assert_true(false, "UIOverlayStack should have at least one child (pause menu)")
		return
	var pause_menu := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	assert_not_null(pause_menu, "Pause menu overlay should exist")
	var settings_button := pause_menu.get_node("CenterContainer/VBoxContainer/SettingsButton") as Button
	assert_not_null(settings_button, "SettingsButton should exist on pause menu")
	settings_button.emit_signal("pressed")
	await wait_physics_frames(4)

	var settings_overlay := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	assert_not_null(settings_overlay, "Settings overlay should exist after pressing Settings")
	var profiles_button := settings_overlay.get_node("CenterContainer/VBoxContainer/InputProfilesButton") as Button
	assert_not_null(profiles_button, "InputProfilesButton should exist on settings overlay")
	profiles_button.emit_signal("pressed")
	# Allow selector overlay to finish loading and register to the stack.
	await wait_physics_frames(4)

	# Top of UIOverlayStack should now be input_profile_selector
	var top_overlay := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1)
	assert_eq(String(top_overlay.name), "InputProfileSelector", "Input profile selector overlay should be active")

func test_apply_closes_overlays_and_resumes() -> void:
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	U_ServiceLocator.register(StringName("scene_manager"), manager)
	await get_tree().process_frame

	await _start_game_and_pause()
	_debug_overlay_snapshot("after _start_game_and_pause")

	# Open the settings overlay, then the profile selector overlay
	if _ui_overlay_stack.get_child_count() == 0:
		assert_true(false, "UIOverlayStack should have at least one child (pause menu)")
		return
	var pause_menu := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var settings_button := pause_menu.get_node("CenterContainer/VBoxContainer/SettingsButton") as Button
	settings_button.emit_signal("pressed")
	await wait_physics_frames(2)
	_debug_overlay_snapshot("after SettingsButton pressed + wait(2)")

	var settings_overlay := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var profiles_button := settings_overlay.get_node("CenterContainer/VBoxContainer/InputProfilesButton") as Button
	profiles_button.emit_signal("pressed")
	await wait_physics_frames(2)
	_debug_overlay_snapshot("after InputProfilesButton pressed + wait(2)")

	# Press Apply on the selector
	var selector := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var apply_button := selector.get_node("HBoxContainer/ApplyButton") as Button
	apply_button.emit_signal("pressed")
	_debug_overlay_snapshot("after ApplyButton pressed")

	# Wait for overlay stack to reconcile (overlay pop happens asynchronously via Redux/navigation)
	# Manual polling loop with timeout for reliability
	var max_attempts := 100
	var attempts := 0
	var last_signature := ""
	while _ui_overlay_stack.get_child_count() > 1 and attempts < max_attempts:
		await get_tree().physics_frame
		attempts += 1
		var overlay_names: Array[String] = []
		for child in _ui_overlay_stack.get_children():
			overlay_names.append(String(child.name))
		var signature := _one_line(overlay_names)
		if signature != last_signature:
			last_signature = signature
			_debug_overlay_snapshot("poll attempt=%d" % attempts)

	if attempts >= max_attempts:
		_debug_overlay_snapshot("timeout after %d frames" % max_attempts)
		fail_test("Timeout: Overlay was not popped after %d frames" % max_attempts)

	# Expect to return to settings overlay and remain paused
	_debug_overlay_snapshot("final (before assertions)")
	assert_eq(_ui_overlay_stack.get_child_count(), 1, "Should return to a single settings overlay after apply")
	var top_after := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1)
	assert_eq(String(top_after.name), "SettingsMenu", "Top overlay should be the settings menu after applying profile")
	assert_true(get_tree().paused, "Tree should remain paused while in settings")

	# Allow queued frees from overlay reconciliation to flush so GUT doesn't
	# report orphaned nodes from the popped overlay.
	await get_tree().process_frame

func test_profile_selector_shows_binding_preview() -> void:
	var manager := M_SceneManager.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	U_ServiceLocator.register(StringName("scene_manager"), manager)
	await get_tree().process_frame

	await _start_game_and_pause()

	# Open the settings overlay, then the profile selector overlay
	if _ui_overlay_stack.get_child_count() == 0:
		assert_true(false, "UIOverlayStack should have at least one child (pause menu)")
		return
	var pause_menu := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var settings_button := pause_menu.get_node("CenterContainer/VBoxContainer/SettingsButton") as Button
	assert_not_null(settings_button, "SettingsButton should exist on pause menu")
	settings_button.emit_signal("pressed")
	await wait_physics_frames(4)

	var settings_overlay := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var profiles_button := settings_overlay.get_node("CenterContainer/VBoxContainer/InputProfilesButton") as Button
	assert_not_null(profiles_button, "InputProfilesButton should exist on settings overlay")
	profiles_button.emit_signal("pressed")
	await wait_physics_frames(4)

	var selector := _ui_overlay_stack.get_child(_ui_overlay_stack.get_child_count() - 1) as Control
	var preview_container := selector.get_node("PreviewContainer") as VBoxContainer
	assert_not_null(preview_container, "PreviewContainer should exist on profile selector")
	var header_label := preview_container.get_node("HeaderLabel") as Label
	assert_not_null(header_label, "HeaderLabel should exist in preview container")
	# The bindings container should have child nodes showing the bindings with icons
	var bindings_container := preview_container.get_node("BindingsContainer") as VBoxContainer
	assert_not_null(bindings_container, "BindingsContainer should exist in preview container")
	assert_gt(bindings_container.get_child_count(), 0, "Bindings container should show action bindings")

func _start_game_and_pause() -> void:
	_store.dispatch(U_NavigationActions.start_game(StringName("scene1")))
	await _await_scene(StringName("scene1"))
	_store.dispatch(U_NavigationActions.open_pause())
	await wait_physics_frames(4)

func _await_scene(scene_id: StringName, limit_frames: int = 30) -> void:
	for _i in range(limit_frames):
		var scene_state: Dictionary = _store.get_state().get("scene", {})
		if scene_state.get("current_scene_id") == scene_id:
			return
		await wait_physics_frames(1)
	assert_true(false, "Timed out waiting for scene_id %s" % scene_id)
