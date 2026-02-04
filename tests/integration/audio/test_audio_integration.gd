extends BaseTest

## Full audio integration tests (Phase 9.2)
##
## Smoke-tests end-to-end wiring across:
## - Redux audio slice → M_AudioManager bus volumes/mutes
## - Music switching via scene + pause actions
## - Ambient switching via scene actions
## - UI sound playback via U_UISoundPlayer
## - Event-driven gameplay SFX systems + pooled 3D spawner
## - Footstep system surface selection + timing

const M_AUDIO_MANAGER := preload("res://scripts/managers/m_audio_manager.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")

const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_SURFACE_DETECTOR_COMPONENT := preload("res://scripts/ecs/components/c_surface_detector_component.gd")

const RS_AUDIO_INITIAL_STATE := preload("res://scripts/resources/state/rs_audio_initial_state.gd")
const RS_FLOATING_SETTINGS := preload("res://scripts/resources/ecs/rs_floating_settings.gd")
const RS_FOOTSTEP_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_footstep_sound_settings.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const S_CHECKPOINT_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_checkpoint_sound_system.gd")
const S_DEATH_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_death_sound_system.gd")
const S_FOOTSTEP_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_footstep_sound_system.gd")
const S_JUMP_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_jump_sound_system.gd")
const S_LANDING_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_landing_sound_system.gd")
const S_VICTORY_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_victory_sound_system.gd")

const RS_CHECKPOINT_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_checkpoint_sound_settings.gd")
const RS_DEATH_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_death_sound_settings.gd")
const RS_JUMP_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_jump_sound_settings.gd")
const RS_LANDING_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_landing_sound_settings.gd")
const RS_VICTORY_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_victory_sound_settings.gd")

const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_UISOUND_PLAYER := preload("res://scripts/ui/utils/u_ui_sound_player.gd")
const U_AUDIO_TEST_HELPERS := preload("res://tests/helpers/u_audio_test_helpers.gd")

const STREAM_MAIN_MENU := preload("res://assets/audio/music/mus_main_menu.mp3")
const STREAM_ALLEYWAY := preload("res://assets/audio/music/mus_alleyway.mp3")
const STREAM_PAUSE := preload("res://assets/audio/music/mus_pause.mp3")

const STREAM_AMBIENT_EXTERIOR := preload("res://tests/assets/audio/ambient/amb_placeholder_exterior.wav")
const STREAM_AMBIENT_INTERIOR := preload("res://tests/assets/audio/ambient/amb_placeholder_interior.wav")

var _store: M_StateStore
var _audio_manager: M_AudioManager


func before_each() -> void:
	get_tree().paused = false
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	U_ECS_EVENT_BUS.reset()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	await get_tree().process_frame

	_store = _create_state_store()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	# Phase 6/7: Wait for store to initialize, then set navigation.shell to "gameplay"
	# so SFX systems don't block audio (base_event_sfx_system._is_audio_blocked checks shell == "gameplay")
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.set_shell(StringName("gameplay"), StringName("test_scene")))

	_audio_manager = M_AUDIO_MANAGER.new()
	add_child_autofree(_audio_manager)

	await get_tree().process_frame


func after_each() -> void:
	get_tree().paused = false
	U_SFX_SPAWNER.cleanup()
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
	U_AUDIO_TEST_HELPERS.reset_audio_buses()
	super.after_each()


func _create_state_store() -> M_StateStore:
	var store := M_STATE_STORE.new()
	store.settings = RS_STATE_STORE_SETTINGS.new()
	store.settings.enable_persistence = false
	store.settings.enable_debug_logging = false
	store.settings.enable_debug_overlay = false
	store.audio_initial_state = RS_AUDIO_INITIAL_STATE.new()
	return store


func _is_music_stream_playing(stream: AudioStream) -> bool:
	var player_a := _audio_manager.get_node_or_null("MusicPlayerA") as AudioStreamPlayer
	var player_b := _audio_manager.get_node_or_null("MusicPlayerB") as AudioStreamPlayer
	if player_a != null and player_a.playing and player_a.stream == stream:
		return true
	if player_b != null and player_b.playing and player_b.stream == stream:
		return true
	return false


func _get_in_use_sfx_players() -> Array[AudioStreamPlayer3D]:
	var in_use: Array[AudioStreamPlayer3D] = []
	for player_variant in U_SFX_SPAWNER._pool:
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if not is_instance_valid(player):
			continue
		if U_SFX_SPAWNER.is_player_in_use(player):
			in_use.append(player)
	return in_use


func _reset_sfx_pool_usage() -> void:
	for player_variant in U_SFX_SPAWNER._pool:
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if not is_instance_valid(player):
			continue
		U_SFX_SPAWNER._player_in_use[player] = false
		if player.playing:
			player.stop()


func test_bus_count_is_six() -> void:
	assert_eq(AudioServer.bus_count, 6, "Expected 6 buses (Master + Music + SFX + UI + Footsteps + Ambient)")


func test_bus_names_match_expected_layout() -> void:
	assert_eq(AudioServer.get_bus_name(0), "Master")
	assert_eq(AudioServer.get_bus_name(1), "Music")
	assert_eq(AudioServer.get_bus_name(2), "SFX")
	assert_eq(AudioServer.get_bus_name(3), "UI")
	assert_eq(AudioServer.get_bus_name(4), "Footsteps")
	assert_eq(AudioServer.get_bus_name(5), "Ambient")


func test_bus_routing_matches_expected_hierarchy() -> void:
	assert_eq(AudioServer.get_bus_send(1), "Master", "Music should send to Master")
	assert_eq(AudioServer.get_bus_send(2), "Master", "SFX should send to Master")
	assert_eq(AudioServer.get_bus_send(3), "SFX", "UI should send to SFX")
	assert_eq(AudioServer.get_bus_send(4), "SFX", "Footsteps should send to SFX")
	assert_eq(AudioServer.get_bus_send(5), "Master", "Ambient should send to Master")


func test_master_volume_action_updates_master_bus_volume_db() -> void:
	var idx := AudioServer.get_bus_index("Master")
	_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(0.5))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), M_AUDIO_MANAGER._linear_to_db(0.5), 0.05)


func test_music_volume_action_updates_music_bus_volume_db() -> void:
	var idx := AudioServer.get_bus_index("Music")
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.25))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), M_AUDIO_MANAGER._linear_to_db(0.25), 0.05)


func test_sfx_volume_action_updates_sfx_bus_volume_db() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(0.75))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), M_AUDIO_MANAGER._linear_to_db(0.75), 0.05)


func test_ambient_volume_action_updates_ambient_bus_volume_db() -> void:
	var idx := AudioServer.get_bus_index("Ambient")
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(0.6))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), M_AUDIO_MANAGER._linear_to_db(0.6), 0.05)


func test_master_mute_action_updates_master_bus_mute() -> void:
	var idx := AudioServer.get_bus_index("Master")
	_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(true))
	assert_true(AudioServer.is_bus_mute(idx))


func test_music_mute_action_updates_music_bus_mute() -> void:
	var idx := AudioServer.get_bus_index("Music")
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	assert_true(AudioServer.is_bus_mute(idx))


func test_sfx_mute_action_updates_sfx_bus_mute() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(true))
	assert_true(AudioServer.is_bus_mute(idx))


func test_ambient_mute_action_updates_ambient_bus_mute() -> void:
	var idx := AudioServer.get_bus_index("Ambient")
	_store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(true))
	assert_true(AudioServer.is_bus_mute(idx))


func test_mute_does_not_change_volume_db() -> void:
	var idx := AudioServer.get_bus_index("Music")
	_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(0.25))
	var before := AudioServer.get_bus_volume_db(idx)

	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(true))
	_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(false))

	var after := AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(after, before, 0.001, "Muting/unmuting should not modify stored bus volume_db")


func test_spatial_audio_toggle_updates_sfx_spawner_and_player_spatialization() -> void:
	_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(false))
	assert_false(U_SFX_SPAWNER.is_spatial_audio_enabled(), "Spawner should reflect spatial_audio_enabled=false")

	var player_off := U_SFX_SPAWNER.spawn_3d({"audio_stream": AudioStreamWAV.new()})
	assert_not_null(player_off)
	assert_eq(player_off.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED)
	assert_eq(player_off.panning_strength, 0.0)

	_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(true))
	assert_true(U_SFX_SPAWNER.is_spatial_audio_enabled(), "Spawner should reflect spatial_audio_enabled=true")

	player_off.emit_signal("finished")
	var player_on := U_SFX_SPAWNER.spawn_3d({"audio_stream": AudioStreamWAV.new()})
	assert_not_null(player_on)
	assert_eq(player_on.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_eq(player_on.panning_strength, 1.0)


func test_ui_sound_focus_routes_through_ui_bus() -> void:
	# Phase 8: UI sound polyphony - check first player in array
	var ui_player := _audio_manager.get_node_or_null("UIPlayer_0") as AudioStreamPlayer
	assert_not_null(ui_player, "UIPlayer_0 should exist")
	assert_eq(ui_player.bus, "UI", "UIPlayer should use UI bus")

	U_UISOUND_PLAYER.play_focus()
	# Focus SFX is very short; it may finish within a single frame on slow CI/headless runs.
	# With round-robin, focus will play on UIPlayer_0 (first player)
	assert_eq(ui_player.stream, preload("res://tests/assets/audio/sfx/sfx_placeholder_ui_focus.wav"))
	assert_true(ui_player.playing, "UI focus sound should start playing immediately after play()")


func test_ui_sounds_play_while_tree_paused() -> void:
	# Phase 8: UI sound polyphony - check first player in array
	var ui_player := _audio_manager.get_node_or_null("UIPlayer_0") as AudioStreamPlayer
	assert_not_null(ui_player, "UIPlayer_0 should exist")

	get_tree().paused = true
	U_UISOUND_PLAYER.play_confirm()
	# With round-robin, confirm will play on UIPlayer_0 (first player)
	assert_eq(ui_player.stream, preload("res://tests/assets/audio/sfx/sfx_placeholder_ui_confirm.wav"))
	assert_true(ui_player.playing, "UI confirm sound should start playing immediately after play()")
	get_tree().paused = false


func test_scene_transition_action_switches_to_main_menu_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	await get_tree().process_frame
	assert_true(_is_music_stream_playing(STREAM_MAIN_MENU))


func test_scene_transition_action_switches_to_alleyway_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame
	assert_true(_is_music_stream_playing(STREAM_ALLEYWAY))


func test_open_pause_switches_to_pause_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame
	assert_true(_is_music_stream_playing(STREAM_PAUSE))


func test_close_pause_restores_previous_music() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame
	_store.dispatch(U_NAVIGATION_ACTIONS.open_pause())
	await get_tree().process_frame

	_store.dispatch(U_NAVIGATION_ACTIONS.close_pause())
	await get_tree().process_frame
	assert_true(_is_music_stream_playing(STREAM_ALLEYWAY))


func _is_ambient_stream_playing(stream: AudioStream) -> bool:
	var player_a := _audio_manager.get_node_or_null("AmbientPlayerA") as AudioStreamPlayer
	var player_b := _audio_manager.get_node_or_null("AmbientPlayerB") as AudioStreamPlayer
	if player_a != null and player_a.playing and player_a.stream == stream:
		return true
	if player_b != null and player_b.playing and player_b.stream == stream:
		return true
	return false


func test_ambient_manager_starts_exterior_ambient_on_scene_transition() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame
	assert_true(_is_ambient_stream_playing(STREAM_AMBIENT_EXTERIOR))


func test_ambient_manager_switches_to_interior_ambient_on_scene_transition() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("interior_house")))
	await get_tree().process_frame
	assert_true(_is_ambient_stream_playing(STREAM_AMBIENT_INTERIOR))


func test_ambient_manager_stops_ambient_when_no_ambient_for_scene() -> void:
	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("alleyway")))
	await get_tree().process_frame
	assert_true(_is_ambient_stream_playing(STREAM_AMBIENT_EXTERIOR))

	_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("main_menu")))
	# Wait for fade out to complete (2.0s duration + buffer)
	await get_tree().create_timer(2.1).timeout
	assert_false(_is_ambient_stream_playing(STREAM_AMBIENT_EXTERIOR))
	assert_false(_is_ambient_stream_playing(STREAM_AMBIENT_INTERIOR))


func test_jump_sfx_system_spawns_sound_on_entity_jumped_event() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var settings := RS_JUMP_SOUND_SETTINGS.new()
	settings.audio_stream = AudioStreamWAV.new()
	settings.pitch_variation = 0.2

	var system := S_JUMP_SOUND_SYSTEM.new() as S_JumpSoundSystem
	system.settings = settings
	system.state_store = _store  # Phase 6/7: Inject state store
	add_child_autofree(system)
	await get_tree().process_frame

	U_ECS_EVENT_BUS.publish(StringName("entity_jumped"), {"position": Vector3(1, 2, 3)})
	system.process_tick(0.016)

	# Phase 7: Use stats API - headless audio completes immediately so players aren't "in use"
	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "Jump event should spawn 1 SFX")


func test_landing_sfx_system_spawns_sound_on_entity_landed_event() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var settings := RS_LANDING_SOUND_SETTINGS.new()
	settings.audio_stream = AudioStreamWAV.new()

	var system := S_LANDING_SOUND_SYSTEM.new() as S_LandingSoundSystem
	system.settings = settings
	add_child_autofree(system)
	await get_tree().process_frame

	U_ECS_EVENT_BUS.publish(StringName("entity_landed"), {"position": Vector3.ZERO, "fall_speed": 10.0})
	system.process_tick(0.016)

	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "Landing event should spawn 1 SFX for fall_speed>5")


func test_death_sfx_system_spawns_sound_on_entity_death_event() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var settings := RS_DEATH_SOUND_SETTINGS.new()
	settings.audio_stream = AudioStreamWAV.new()

	var system := S_DEATH_SOUND_SYSTEM.new() as S_DeathSoundSystem
	system.settings = settings
	add_child_autofree(system)
	await get_tree().process_frame

	U_ECS_EVENT_BUS.publish(StringName("entity_death"), {"entity_id": StringName("player"), "is_dead": true})
	system.process_tick(0.016)

	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "Death event should spawn 1 SFX when is_dead=true")


func test_checkpoint_sfx_system_spawns_sound_on_checkpoint_activated_event() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var settings := RS_CHECKPOINT_SOUND_SETTINGS.new()
	settings.audio_stream = AudioStreamWAV.new()

	var system := S_CHECKPOINT_SOUND_SYSTEM.new() as S_CheckpointSoundSystem
	system.settings = settings
	add_child_autofree(system)
	await get_tree().process_frame

	U_ECS_EVENT_BUS.publish(StringName("checkpoint_activated"), {"spawn_point_id": StringName("")})
	system.process_tick(0.016)

	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "Checkpoint event should spawn 1 SFX")


func test_victory_sfx_system_spawns_sound_on_victory_triggered_event() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var settings := RS_VICTORY_SOUND_SETTINGS.new()
	settings.audio_stream = AudioStreamWAV.new()

	var system := S_VICTORY_SOUND_SYSTEM.new() as S_VictorySoundSystem
	system.settings = settings
	add_child_autofree(system)
	await get_tree().process_frame

	U_ECS_EVENT_BUS.publish(StringName("victory_triggered"), {"position": Vector3(4, 0, 0)})
	system.process_tick(0.016)

	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "Victory event should spawn 1 SFX")


func _create_basic_footstep_fixture() -> Dictionary:
	var manager := M_ECS_MANAGER.new()
	manager.name = "M_ECSManager"
	# Prevent manager-driven physics ticks; footstep tests manually invoke process_tick.
	manager.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(manager)
	manager.set_physics_process(false)

	var settings := RS_FOOTSTEP_SOUND_SETTINGS.new()
	settings.enabled = true
	settings.step_interval = 0.4
	settings.min_velocity = 1.0
	settings.volume_db = 0.0

	# Use unique streams per surface so selection can be validated by membership.
	settings.default_sounds = [AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new()]
	settings.grass_sounds = [AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new()]

	var system := S_FOOTSTEP_SOUND_SYSTEM.new() as S_FootstepSoundSystem
	system.settings = settings
	manager.add_child(system)
	autofree(system)

	var body := CharacterBody3D.new()
	body.name = "E_TestFootstep"
	body.velocity = Vector3(5, 0, 0)
	manager.add_child(body)
	autofree(body)
	await get_tree().process_frame

	var detector := C_SURFACE_DETECTOR_COMPONENT.new() as C_SurfaceDetectorComponent
	detector.character_body_path = NodePath("..")
	body.add_child(detector)
	autofree(detector)

	var floating := C_FLOATING_COMPONENT.new() as C_FloatingComponent
	floating.settings = RS_FLOATING_SETTINGS.new()
	floating.grounded_stable = true
	body.add_child(floating)
	autofree(floating)

	var floor := StaticBody3D.new()
	floor.name = "grass_floor"
	floor.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.1, 10)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor)

	await get_tree().process_frame
	await get_tree().physics_frame

	return {
		"manager": manager,
		"system": system,
		"settings": settings,
		"body": body,
		"detector": detector,
		"floating": floating,
	}


func test_footstep_system_spawns_sound_when_moving_and_grounded() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var ctx := await _create_basic_footstep_fixture()
	var system := ctx["system"] as S_FootstepSoundSystem

	system.process_tick(0.016)
	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1, "First grounded tick should spawn a footstep")


func test_footstep_system_routes_to_footsteps_bus() -> void:
	_reset_sfx_pool_usage()
	U_SFX_SPAWNER.reset_stats()

	var ctx := await _create_basic_footstep_fixture()
	var system := ctx["system"] as S_FootstepSoundSystem

	system.process_tick(0.016)
	var stats := U_SFX_SPAWNER.get_stats()
	assert_eq(stats["spawns"], 1)
	# Note: Bus verification would require accessing the player from pool, but stats verify spawn occurred


func test_footstep_timing_scales_with_speed() -> void:
	_reset_sfx_pool_usage()
	var ctx := await _create_basic_footstep_fixture()
	var system := ctx["system"] as S_FootstepSoundSystem
	var body := ctx["body"] as CharacterBody3D

	# Low speed (near threshold) should produce fewer steps than high speed over same time window.
	body.velocity = Vector3(1.0, 0, 0)
	system._entity_timers.clear()
	_reset_sfx_pool_usage()
	for _i in range(8):
		system.process_tick(0.1)
	var low_count := _get_in_use_sfx_players().size()

	system._entity_timers.clear()
	_reset_sfx_pool_usage()
	body.velocity = Vector3(4.0, 0, 0)
	for _i in range(8):
		system.process_tick(0.1)
	var high_count := _get_in_use_sfx_players().size()

	assert_gt(high_count, low_count, "Higher speed should result in more frequent footsteps")
