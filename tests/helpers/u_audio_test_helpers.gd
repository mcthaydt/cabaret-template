extends RefCounted

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AUDIO_SERIALIZATION := preload("res://scripts/utils/u_audio_serialization.gd")


static func reset_audio_buses() -> void:
	# Clear all buses beyond Master
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

	# Recreate required bus layout for tests
	# Master (0) already exists

	# Music (1)
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	# SFX (2)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")

	# UI (3) - child of SFX
	AudioServer.add_bus(3)
	AudioServer.set_bus_name(3, "UI")
	AudioServer.set_bus_send(3, "SFX")

	# Footsteps (4) - child of SFX
	AudioServer.add_bus(4)
	AudioServer.set_bus_name(4, "Footsteps")
	AudioServer.set_bus_send(4, "SFX")

	# Ambient (5)
	AudioServer.add_bus(5)
	AudioServer.set_bus_name(5, "Ambient")
	AudioServer.set_bus_send(5, "Master")

	remove_test_file(U_AUDIO_SERIALIZATION.SAVE_PATH)
	remove_test_file(U_AUDIO_SERIALIZATION.BACKUP_PATH)


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
