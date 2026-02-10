extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")

var _store: M_StateStore
var _hud: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ECSEventBus.reset()
	U_InteractBlocker.cleanup()

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	_store.navigation_initial_state = RS_NavigationInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame
	_store.dispatch(U_NavigationActions.start_game(StringName("alleyway")))
	await get_tree().process_frame

	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)
	await get_tree().process_frame

func after_each() -> void:
	U_InteractBlocker.cleanup()
	U_StateHandoff.clear_all()
	_hud = null
	_store = null

func _await_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func test_feedback_channels_have_independent_visibility_state() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")

	assert_false(checkpoint_toast_container.visible, "Checkpoint toast channel should start hidden")
	assert_false(autosave_spinner_container.visible, "Autosave spinner channel should start hidden")
	assert_false(signpost_panel_container.visible, "Signpost panel channel should start hidden")

	_hud.call("_show_autosave_spinner")
	await _await_frames(1)
	assert_true(autosave_spinner_container.visible, "Autosave spinner channel should be visible after show")
	assert_false(checkpoint_toast_container.visible, "Checkpoint toast should remain hidden when spinner shows")
	assert_false(signpost_panel_container.visible, "Signpost panel should remain hidden when spinner shows")

	_hud.call("_hide_autosave_spinner")
	_hud.call("_show_signpost_panel", "Testing signpost panel")
	await _await_frames(1)
	assert_true(signpost_panel_container.visible, "Signpost panel channel should be visible after show")
	assert_false(checkpoint_toast_container.visible, "Checkpoint toast should remain hidden when signpost panel shows")
	assert_false(autosave_spinner_container.visible, "Autosave spinner should remain hidden when signpost panel shows")

	_hud.call("_hide_signpost_panel")
	_hud.call("_show_checkpoint_toast", "Checkpoint reached")
	await _await_frames(1)
	assert_true(checkpoint_toast_container.visible, "Checkpoint toast channel should be visible after show")
	assert_false(autosave_spinner_container.visible, "Autosave spinner should remain hidden when checkpoint toast shows")
	assert_false(signpost_panel_container.visible, "Signpost panel should remain hidden when checkpoint toast shows")

func test_phase2_routing_keeps_signpost_on_toast_but_moves_autosave_to_spinner() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")

	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Signpost text"})
	await _await_frames(1)
	assert_true(checkpoint_toast_container.visible, "Phase 2 keeps signpost routed through checkpoint toast")
	assert_false(autosave_spinner_container.visible, "Signpost should not show autosave spinner")
	assert_false(signpost_panel_container.visible, "Phase 2 keeps dedicated signpost panel channel inactive")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_false(checkpoint_toast_container.visible, "Autosave should not use checkpoint toast channel in Phase 2")
	assert_true(autosave_spinner_container.visible, "Autosave should show spinner channel in Phase 2")
	assert_false(signpost_panel_container.visible, "Autosave should not show signpost panel channel in Phase 2")

func test_autosave_spinner_lifecycle_hides_on_completion_and_failure() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_true(autosave_spinner_container.visible, "Autosave spinner should show on autosave start")
	assert_false(checkpoint_toast_container.visible, "Checkpoint toast should remain hidden for autosave start")
	assert_false(signpost_panel_container.visible, "Signpost panel should remain hidden for autosave start")

	U_ECSEventBus.publish(StringName("save_completed"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_false(autosave_spinner_container.visible, "Autosave spinner should hide on autosave completion")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_true(autosave_spinner_container.visible, "Autosave spinner should show again on subsequent start")

	U_ECSEventBus.publish(StringName("save_failed"), {
		"slot_id": StringName("autosave"),
		"is_autosave": true,
		"error_code": ERR_CANT_CREATE
	})
	await _await_frames(1)
	assert_false(autosave_spinner_container.visible, "Autosave spinner should hide on autosave failure")
	assert_false(checkpoint_toast_container.visible, "Checkpoint toast should remain hidden on autosave failure")
	assert_false(signpost_panel_container.visible, "Signpost panel should remain hidden on autosave failure")

func test_autosave_spinner_path_does_not_use_interact_blocker() -> void:
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	assert_false(U_InteractBlocker.is_blocked(), "Interact blocker should start unblocked")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_true(autosave_spinner_container.visible, "Autosave spinner should show")
	assert_false(U_InteractBlocker.is_blocked(), "Autosave spinner should not block interaction")

	U_ECSEventBus.publish(StringName("save_completed"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_false(U_InteractBlocker.is_blocked(), "Autosave completion should not alter interact blocker state")

func test_manual_save_events_do_not_toggle_autosave_spinner() -> void:
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	assert_false(autosave_spinner_container.visible, "Autosave spinner should start hidden")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("slot_01"), "is_autosave": false})
	await _await_frames(1)
	assert_false(autosave_spinner_container.visible, "Manual save start should not show autosave spinner")

	U_ECSEventBus.publish(StringName("save_completed"), {"slot_id": StringName("slot_01"), "is_autosave": false})
	await _await_frames(1)
	assert_false(autosave_spinner_container.visible, "Manual save completion should not affect autosave spinner")

	U_ECSEventBus.publish(StringName("save_failed"), {
		"slot_id": StringName("slot_01"),
		"is_autosave": false,
		"error_code": ERR_CANT_CREATE
	})
	await _await_frames(1)
	assert_false(autosave_spinner_container.visible, "Manual save failure should not affect autosave spinner")
