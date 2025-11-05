extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud_overlay.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/state/resources/rs_boot_initial_state.gd")
const RS_MenuInitialState := preload("res://scripts/state/resources/rs_menu_initial_state.gd")
const RS_GameplayInitialState := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SceneInitialState := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

var _store: M_StateStore
var _hud: CanvasLayer

func before_each() -> void:
	# Reset event bus between tests
	U_ECSEventBus.reset()

	# Create and add state store
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.boot_initial_state = RS_BootInitialState.new()
	_store.menu_initial_state = RS_MenuInitialState.new()
	_store.gameplay_initial_state = RS_GameplayInitialState.new()
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)

	# Add HUD
	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)
	await get_tree().process_frame

func after_each() -> void:
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
	_store.dispatch(U_SceneActions.push_overlay(StringName("pause_menu")))
	await _await_frames(2)

	# Prompt should hide while paused
	assert_false(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should be hidden while paused")

	# Signpost messages should be suppressed while paused
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Hello"})
	await _await_frames(1)
	assert_false(hud.get_node("MarginContainer/CheckpointToast").visible, "Toast should not show while paused")

	# Unpause: pop overlay
	_store.dispatch(U_SceneActions.pop_overlay())
	await _await_frames(2)

	# Publish signpost message now; toast should show and prompt should hide to avoid overlap
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Hello after pause"})
	await _await_frames(1)
	assert_true(hud.get_node("MarginContainer/CheckpointToast").visible, "Toast should show when not paused")
	assert_false(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should hide while toast is visible")

