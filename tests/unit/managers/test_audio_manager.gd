extends GutTest

# Test suite for M_AudioManager scaffolding and bus layout (Audio Phase 1)

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SETTINGS_INITIAL_STATE := preload("res://scripts/state/resources/rs_settings_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const RS_AUDIO_INITIAL_STATE := preload("res://scripts/state/resources/rs_audio_initial_state.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")

var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_reset_audio_buses()
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_reset_audio_buses()
	_manager = null
	_store = null

func test_manager_extends_node() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is Node, "M_AudioManager should extend Node")

func test_manager_adds_to_audio_manager_group() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_true(_manager.is_in_group("audio_manager"), "M_AudioManager should be in 'audio_manager' group")
	assert_eq(_manager.process_mode, Node.PROCESS_MODE_ALWAYS, "M_AudioManager should process even when tree paused")

func test_manager_registers_with_service_locator() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.get_service(StringName("audio_manager"))
	assert_not_null(service, "M_AudioManager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the Audio manager instance")

func test_manager_creates_audio_bus_layout() -> void:
	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_eq(AudioServer.bus_count, 6, "Audio bus count should be 6 (Master + 5)")
	assert_eq(AudioServer.get_bus_name(0), "Master", "Bus 0 should be Master")
	assert_eq(AudioServer.get_bus_name(1), "Music", "Bus 1 should be Music")
	assert_eq(AudioServer.get_bus_name(2), "SFX", "Bus 2 should be SFX")
	assert_eq(AudioServer.get_bus_name(3), "UI", "Bus 3 should be UI")
	assert_eq(AudioServer.get_bus_name(4), "Footsteps", "Bus 4 should be Footsteps")
	assert_eq(AudioServer.get_bus_name(5), "Ambient", "Bus 5 should be Ambient")

	# Parent/child relationships
	assert_eq(AudioServer.get_bus_send(1), "Master", "Music should send to Master")
	assert_eq(AudioServer.get_bus_send(2), "Master", "SFX should send to Master")
	assert_eq(AudioServer.get_bus_send(3), "SFX", "UI should send to SFX")
	assert_eq(AudioServer.get_bus_send(4), "SFX", "Footsteps should send to SFX")
	assert_eq(AudioServer.get_bus_send(5), "Master", "Ambient should send to Master")

func test_manager_rebuilds_bus_layout_when_extra_buses_exist() -> void:
	_reset_audio_buses()
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Temp")
	assert_eq(AudioServer.bus_count, 2, "Precondition: Temp bus added")

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_eq(AudioServer.bus_count, 6, "Manager should rebuild bus layout to 6 buses")
	assert_eq(AudioServer.get_bus_name(1), "Music", "Bus 1 should be Music after rebuild")

# ============================================================================
# Phase 1 - Volume conversion and application tests (Tasks 1.3/1.4)
# ============================================================================

func test_linear_to_db_conversion() -> void:
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(0.0), -80.0, 0.001, "0.0 should map to -80dB")
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(1.0), 0.0, 0.001, "1.0 should map to 0dB")
	assert_almost_eq(M_AUDIO_MANAGER._linear_to_db(0.5), -6.0206, 0.05, "0.5 should map to ~-6dB")

func test_volume_and_mute_apply_to_buses_via_state_store() -> void:
	_store = _make_store_with_audio_slice()
	add_child_autofree(_store)
	await get_tree().process_frame

	_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")

	# Set volumes
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.5))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.25))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(0.75))
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(0.0))

	assert_almost_eq(AudioServer.get_bus_volume_db(master_idx), -6.0206, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_idx), -12.0412, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), -2.4988, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(ambient_idx), -80.0, 0.001)

	# Mutes (independent of volume)
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(true))

	assert_false(AudioServer.is_bus_mute(master_idx))
	assert_true(AudioServer.is_bus_mute(music_idx))
	assert_true(AudioServer.is_bus_mute(sfx_idx))
	assert_false(AudioServer.is_bus_mute(ambient_idx))

	# Volume remains unchanged when muted
	assert_almost_eq(AudioServer.get_bus_volume_db(music_idx), -12.0412, 0.05)
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), -2.4988, 0.05)

func _make_store_with_audio_slice() -> Node:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_history = false
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	store.settings_initial_state = RS_SETTINGS_INITIAL_STATE.new()
	store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	return store

func _reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

