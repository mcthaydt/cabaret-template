extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")

var _store: M_StateStore
var _hud: CanvasLayer

func before_each() -> void:
	U_StateHandoff.clear_all()
	# Reset event bus between tests
	U_ECSEventBus.reset()

	# Create and add state store
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

	# Add HUD
	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
	_hud = null
	_store = null

func _await_frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

## Interact prompt hides while paused, and signpost messages suppressed when paused
func test_hud_prompt_and_signpost_pause_behavior() -> void:
	var hud := _hud
	assert_ne(hud, null, "HUD must be instantiated")

	# Show an interact prompt
	U_ECSEventBus.publish(StringName("interact_prompt_show"), {
		"controller_id": 42,
		"action": StringName("interact"),
		"prompt": "Read"
	})
	await _await_frames(1)
	assert_true(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should be visible before pause")

	# Pause by pushing overlay
	_store.dispatch(U_NavigationActions.open_pause())
	# StateStore batches updates and emits on physics_frame, not process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Prompt should hide while paused
	assert_false(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should be hidden while paused")

	# Signpost messages should be suppressed while paused
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Hello", "message_duration_sec": 0.2})
	await _await_frames(1)
	assert_false(hud.get_node("MarginContainer/SignpostPanelContainer").visible, "Signpost panel should not show while paused")

	# Unpause: pop overlay
	_store.dispatch(U_NavigationActions.close_pause())
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Publish signpost message now; panel should show and prompt should hide to avoid overlap
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Hello after pause", "message_duration_sec": 0.2})
	await _await_frames(1)
	assert_true(hud.get_node("MarginContainer/SignpostPanelContainer").visible, "Signpost panel should show when not paused")
	assert_false(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should hide while signpost panel is visible")
