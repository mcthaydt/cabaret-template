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

func _await_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

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

func test_phase4_routing_moves_signpost_to_dedicated_panel_and_keeps_autosave_spinner() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")
	var signpost_message_label: Label = _hud.get_node("MarginContainer/SignpostPanelContainer/PanelContainer/MarginContainer/SignpostMessage")

	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Signpost text", "message_duration_sec": 0.2})
	await _await_frames(1)
	assert_false(checkpoint_toast_container.visible, "Signpost should no longer use checkpoint toast channel in Phase 4")
	assert_false(autosave_spinner_container.visible, "Signpost should not show autosave spinner")
	assert_true(signpost_panel_container.visible, "Signpost should use dedicated signpost panel channel in Phase 4")
	assert_eq(signpost_message_label.text, "Signpost text", "Signpost panel should render signpost message text")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_false(checkpoint_toast_container.visible, "Autosave should not use checkpoint toast channel in Phase 2")
	assert_true(autosave_spinner_container.visible, "Autosave should show spinner channel in Phase 2")
	assert_false(signpost_panel_container.visible, "Autosave should not show signpost panel channel in Phase 2")

func test_signpost_panel_auto_hides_by_payload_duration_and_restores_prompt() -> void:
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")
	var prompt: Control = _hud.get_node("MarginContainer/InteractPrompt")

	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 991,
		"action": StringName("interact"),
		"prompt": "Read"
	})
	await _await_frames(1)
	assert_true(prompt.visible, "Prompt should be visible before signpost panel")

	U_ECSEventBus.publish(StringName("signpost_message"), {
		"message": "Read this placard",
		"message_duration_sec": 0.2
	})
	await _await_frames(1)
	assert_true(signpost_panel_container.visible, "Signpost panel should show when message arrives")
	assert_false(prompt.visible, "Prompt should hide while signpost panel is visible")

	await _await_seconds(0.7)
	assert_false(signpost_panel_container.visible, "Signpost panel should auto-hide after configured duration")
	assert_true(prompt.visible, "Prompt should restore after signpost panel auto-hide completes")

func test_signpost_panel_uses_default_duration_when_payload_duration_missing() -> void:
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")

	U_ECSEventBus.publish(StringName("signpost_message"), {
		"message": "Default duration signpost"
	})
	await _await_frames(1)
	assert_true(signpost_panel_container.visible, "Signpost panel should show with legacy payloads")

	await _await_seconds(1.0)
	assert_true(signpost_panel_container.visible, "Signpost panel should remain visible before 3.0s default duration elapses")

func test_signpost_panel_path_uses_interact_blocker_but_autosave_spinner_stays_non_blocking() -> void:
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")

	assert_false(U_InteractBlocker.is_blocked(), "Interact blocker should start unblocked")
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Blocked briefly", "message_duration_sec": 0.2})
	await _await_frames(1)
	assert_true(signpost_panel_container.visible, "Signpost panel should show")
	assert_true(U_InteractBlocker.is_blocked(), "Signpost panel should block interaction while visible")

	await _await_seconds(0.7)
	assert_false(signpost_panel_container.visible, "Signpost panel should auto-hide")
	assert_false(U_InteractBlocker.is_blocked(), "Signpost blocker should clear after hide + cooldown")

	U_ECSEventBus.publish(StringName("save_started"), {"slot_id": StringName("autosave"), "is_autosave": true})
	await _await_frames(1)
	assert_true(autosave_spinner_container.visible, "Autosave spinner should show")
	assert_false(U_InteractBlocker.is_blocked(), "Autosave spinner should not block interaction")

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

func test_checkpoint_event_uses_checkpoint_channel_only() -> void:
	var checkpoint_toast_container: Control = _hud.get_node("MarginContainer/ToastContainer")
	var autosave_spinner_container: Control = _hud.get_node("MarginContainer/AutosaveSpinnerContainer")
	var signpost_panel_container: Control = _hud.get_node("MarginContainer/SignpostPanelContainer")
	var checkpoint_toast_label: Label = _hud.get_node("MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast")

	U_ECSEventBus.publish(StringName("checkpoint_activated"), {
		"checkpoint_id": StringName("cp_bar_tutorial")
	})
	await _await_frames(1)

	assert_true(checkpoint_toast_container.visible, "Checkpoint event should show checkpoint toast channel")
	assert_false(autosave_spinner_container.visible, "Checkpoint event should not show autosave spinner")
	assert_false(signpost_panel_container.visible, "Checkpoint event should not show signpost panel")
	assert_eq(checkpoint_toast_label.text, "Checkpoint: Bar Tutorial",
		"Checkpoint message should use player-facing copy instead of raw ID")

func test_checkpoint_event_prefers_explicit_player_facing_label() -> void:
	var checkpoint_toast_label: Label = _hud.get_node("MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast")

	U_ECSEventBus.publish(StringName("checkpoint_activated"), {
		"checkpoint_id": StringName("cp_internal_name"),
		"checkpoint_label": "Backstage Entry"
	})
	await _await_frames(1)

	assert_eq(checkpoint_toast_label.text, "Checkpoint: Backstage Entry",
		"Checkpoint should prefer explicit player-facing label when provided")

func test_checkpoint_toast_preserves_prompt_hide_and_restore_timing() -> void:
	var prompt: Control = _hud.get_node("MarginContainer/InteractPrompt")

	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 777,
		"action": StringName("interact"),
		"prompt": "Read"
	})
	await _await_frames(1)
	assert_true(prompt.visible, "Prompt should be visible before checkpoint toast")
	assert_eq(int(_hud.get("_active_prompt_id")), 777, "Prompt event should track active controller for restoration")

	U_ECSEventBus.publish(StringName("checkpoint_activated"), {
		"checkpoint_id": StringName("cp_stage_left")
	})
	await _await_frames(1)
	assert_false(prompt.visible, "Prompt should hide while checkpoint toast is visible")

	# Checkpoint toast duration baseline: 0.2 fade-in + 1.0 hold + 0.3 fade-out.
	await _await_seconds(2.0)
	assert_true(prompt.visible, "Prompt should restore after checkpoint toast lifecycle completes")
