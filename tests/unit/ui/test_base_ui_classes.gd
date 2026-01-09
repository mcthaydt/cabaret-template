extends GutTest

const BasePanel := preload("res://scripts/ui/base/base_panel.gd")
const BaseMenuScreen := preload("res://scripts/ui/base/base_menu_screen.gd")
const BaseOverlay := preload("res://scripts/ui/base/base_overlay.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const OverlayStub := preload("res://tests/test_doubles/ui/overlay_stub.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")


class MockAudioManager:
	extends Node

	var played: Array[StringName] = []

	func play_ui_sound(sound_id: StringName) -> void:
		played.append(sound_id)


var _mock_audio_manager: MockAudioManager


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = MockAudioManager.new()
	add_child_autofree(_mock_audio_manager)
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), _mock_audio_manager)


func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_mock_audio_manager = null

func test_base_panel_focuses_first_focusable_child() -> void:
	var store := await _create_state_store()
	assert_not_null(store, "State store should be available for BasePanel tests")

	var panel := BasePanel.new()
	var unfocusable_button := Button.new()
	unfocusable_button.focus_mode = Control.FOCUS_NONE
	panel.add_child(unfocusable_button)

	var focus_button := Button.new()
	focus_button.name = "SecondButton"
	focus_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(focus_button)

	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_true(focus_button.has_focus(),
		"BasePanel should automatically focus the first focusable descendant control")

func test_base_panel_does_not_play_focus_sound_when_applying_initial_focus() -> void:
	await _create_state_store()
	var panel := BasePanel.new()
	var focus_button := Button.new()
	focus_button.focus_mode = Control.FOCUS_ALL
	panel.add_child(focus_button)
	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_eq(_mock_audio_manager.played, [],
		"Initial/programmatic focus should not trigger a focus sound")

func test_base_panel_plays_focus_sound_only_when_armed_by_navigation_action() -> void:
	await _create_state_store()
	var panel := BasePanel.new()

	var button_a := Button.new()
	button_a.name = "ButtonA"
	button_a.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_a)

	var button_b := Button.new()
	button_b.name = "ButtonB"
	button_b.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_b)

	add_child_autofree(panel)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on ButtonA")

	_mock_audio_manager.played.clear()

	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true
	panel._input(down_event)

	button_b.grab_focus()
	await wait_process_frames(1)

	assert_eq(_mock_audio_manager.played, [StringName("ui_focus")],
		"Focus sound should play only after a navigation input moves focus")

func test_base_panel_does_not_arm_focus_sound_for_joypad_motion_events() -> void:
	await _create_state_store()
	var panel := BasePanel.new()

	var button_a := Button.new()
	button_a.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_a)

	var button_b := Button.new()
	button_b.focus_mode = Control.FOCUS_ALL
	panel.add_child(button_b)

	add_child_autofree(panel)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on the first button")

	_mock_audio_manager.played.clear()

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis = JOY_AXIS_LEFT_Y
	motion_event.axis_value = 1.0
	panel._input(motion_event)

	button_b.grab_focus()
	await wait_process_frames(1)

	assert_eq(_mock_audio_manager.played, [],
		"Joypad motion should not arm focus sounds (analog navigation arms at grab_focus)")

func test_base_menu_screen_plays_focus_sound_on_analog_navigation() -> void:
	await _create_state_store()
	var screen := BaseMenuScreen.new()

	var button_a := Button.new()
	button_a.name = "ButtonA"
	button_a.focus_mode = Control.FOCUS_ALL
	screen.add_child(button_a)

	var button_b := Button.new()
	button_b.name = "ButtonB"
	button_b.focus_mode = Control.FOCUS_ALL
	screen.add_child(button_b)

	button_a.focus_neighbor_bottom = button_a.get_path_to(button_b)
	button_b.focus_neighbor_top = button_b.get_path_to(button_a)

	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_true(button_a.has_focus(), "Initial focus should be on ButtonA")

	_mock_audio_manager.played.clear()

	screen._navigate_focus(StringName("ui_down"))
	await wait_process_frames(1)

	assert_true(button_b.has_focus(), "Analog navigation should move focus to ButtonB")
	assert_eq(_mock_audio_manager.played, [StringName("ui_focus")],
		"Analog navigation focus moves should trigger focus sound")

func test_base_overlay_handles_ui_cancel_back_action() -> void:
	await _create_state_store()
	var overlay := OverlayStub.new()
	var button := Button.new()
	overlay.add_child(button)
	add_child_autofree(overlay)
	await wait_process_frames(3)

	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS,
		"BaseOverlay should process even when the tree is paused")

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	overlay._unhandled_input(cancel_event)

	assert_true(overlay.back_pressed,
		"BaseOverlay should call _on_back_pressed() when ui_cancel is pressed")

func test_base_panel_exposes_state_store_reference() -> void:
	var store := await _create_state_store()
	var panel := BasePanel.new()
	add_child_autofree(panel)
	await wait_process_frames(3)

	assert_is(panel.get_store(), M_StateStore,
		"BasePanel should store an M_StateStore reference after ready")
	assert_eq(panel.get_store(), store,
		"BasePanel should resolve the same store instance in the scene tree")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.menu_initial_state = RS_MenuInitialState.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	store.scene_initial_state = RS_SceneInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store
