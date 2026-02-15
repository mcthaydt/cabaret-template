extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")
const I_LOCALIZATION_MANAGER := preload("res://scripts/interfaces/i_localization_manager.gd")

## Minimal mock for the localization manager — returns translated string or falls back to key.
class MockLocManager extends I_LocalizationManager:
	var _translations: Dictionary = {}
	func translate(key: StringName) -> String:
		return _translations.get(String(key), String(key))
	func register_ui_root(_root: Node) -> void:
		pass
	func unregister_ui_root(_root: Node) -> void:
		pass

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
	assert_false(hud.get_node("SignpostPanelContainer").visible, "Signpost panel should not show while paused")

	# Unpause: pop overlay
	_store.dispatch(U_NavigationActions.close_pause())
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Publish signpost message now; panel should show and prompt should hide to avoid overlap
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Hello after pause", "message_duration_sec": 0.2})
	await _await_frames(1)
	assert_true(hud.get_node("SignpostPanelContainer").visible, "Signpost panel should show when not paused")
	assert_false(hud.get_node("MarginContainer/InteractPrompt").visible, "Prompt should hide while signpost panel is visible")


## Phase 4A: Signpost localization tests
## test_signpost_message_resolved_via_localization (Red before 4A.2, Green after)
func test_signpost_message_resolved_via_localization() -> void:
	# Register a mock localization manager with a known translation.
	var mock_loc := MockLocManager.new()
	mock_loc._translations["signpost.cave_warning"] = "Cave Ahead!"
	add_child_autofree(mock_loc)
	U_ServiceLocator.register(StringName("localization_manager"), mock_loc)

	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "signpost.cave_warning", "message_duration_sec": 100.0})
	await _await_frames(1)

	var signpost_label := _hud.get_node("SignpostPanelContainer/PanelContainer/MarginContainer/SignpostMessage") as Label
	assert_not_null(signpost_label, "Signpost label must exist")
	assert_eq(signpost_label.text, "Cave Ahead!", "Signpost key should resolve to translated text via U_LocalizationUtils.localize()")

## test_signpost_literal_string_degrades_gracefully (passes both before and after 4A.2)
func test_signpost_literal_string_degrades_gracefully() -> void:
	# No localization manager registered — literal strings must pass through unchanged.
	U_ECSEventBus.publish(StringName("signpost_message"), {"message": "Beware the cave!", "message_duration_sec": 100.0})
	await _await_frames(1)

	var signpost_label := _hud.get_node("SignpostPanelContainer/PanelContainer/MarginContainer/SignpostMessage") as Label
	assert_not_null(signpost_label, "Signpost label must exist")
	assert_eq(signpost_label.text, "Beware the cave!", "Literal string must pass through unchanged when it is not a translation key")
