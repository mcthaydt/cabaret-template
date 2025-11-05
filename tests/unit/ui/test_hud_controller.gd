extends GutTest

const HUD_SCENE := preload("res://scenes/ui/hud_overlay.tscn")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")

func test_hud_controller_uses_process_mode_always() -> void:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	add_child(store)
	autofree(store)
	await get_tree().process_frame

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	autofree(hud)
	await get_tree().process_frame

	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD controller should process even when the scene tree is paused.")
