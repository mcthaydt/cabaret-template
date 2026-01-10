extends RefCounted

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/state/resources/rs_audio_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")


static func reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)


static func create_state_store(include_scene_slice: bool = true) -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	if include_scene_slice:
		store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	return store


static func register_state_store(store: Node) -> void:
	if store == null:
		return
	U_SERVICE_LOCATOR.register(StringName("state_store"), store)


static func remove_test_file(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
