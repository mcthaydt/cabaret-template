extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")

var _store: M_StateStore
var _hud: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ECSEventBus.reset()

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

func test_phase1_routing_keeps_signpost_and_autosave_on_checkpoint_toast() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")

	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Signpost text"})
	await _await_frames(1)
	assert_true(checkpoint_toast_container.visible, "Phase 1 keeps signpost routed through checkpoint toast")
	assert_false(autosave_spinner_container.visible, "Phase 1 keeps autosave spinner channel inactive")
	assert_false(signpost_panel_container.visible, "Phase 1 keeps dedicated signpost panel channel inactive")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_true(checkpoint_toast_container.visible, "Phase 1 keeps autosave feedback routed through checkpoint toast")
	assert_false(autosave_spinner_container.visible, "Autosave spinner channel should remain inactive in Phase 1")
	assert_false(signpost_panel_container.visible, "Signpost panel channel should remain inactive in Phase 1")
