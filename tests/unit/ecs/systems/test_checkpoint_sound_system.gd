extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const CHECKPOINT_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_checkpoint_sound_system.gd")
const CHECKPOINT_SOUND_SETTINGS := preload("res://scripts/resources/ecs/rs_checkpoint_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
const EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

const TEST_EVENT := StringName("checkpoint_activated")

var _pool_parent: Node3D

func before_each() -> void:
	EVENT_BUS.reset()
	SFX_SPAWNER.cleanup()
	_reset_audio_buses()
	_ensure_sfx_bus_exists()

	_pool_parent = Node3D.new()
	add_child(_pool_parent)
	autofree(_pool_parent)
	SFX_SPAWNER.initialize(_pool_parent)

func after_each() -> void:
	SFX_SPAWNER.cleanup()
	_reset_audio_buses()
	_pool_parent = null

func _pump() -> void:
	await get_tree().process_frame

func _reset_audio_buses() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

func _ensure_sfx_bus_exists() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")

func _spawn_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func _get_in_use_players() -> Array[AudioStreamPlayer3D]:
	var players: Array[AudioStreamPlayer3D] = []
	for player_variant in SFX_SPAWNER._pool:
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if SFX_SPAWNER.is_player_in_use(player):
			players.append(player)
	return players

func _make_settings(stream: AudioStream) -> Resource:
	var settings := CHECKPOINT_SOUND_SETTINGS.new()
	settings.enabled = true
	settings.audio_stream = stream
	settings.volume_db = -3.0
	settings.pitch_variation = 0.0
	settings.min_interval = 0.0
	return settings

func test_system_extends_ecs_system() -> void:
	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	assert_true(system is BaseECSSystem)

func test_get_event_name_is_checkpoint_activated() -> void:
	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	assert_eq(system.get_event_name(), TEST_EVENT)

func test_event_queues_request_with_spawn_point_id() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})

	assert_eq(system.requests.size(), 1)
	assert_eq(system.requests[0].get("spawn_point_id"), StringName("sp_test"))

func test_process_tick_with_null_settings_clears_requests_and_spawns_nothing() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	assert_eq(system.requests.size(), 1)

	system.process_tick(0.016)

	assert_eq(system.requests.size(), 0)
	assert_eq(_get_in_use_players().size(), 0)

func test_process_tick_when_disabled_clears_requests_and_spawns_nothing() -> void:
	var manager := _spawn_manager()
	await _pump()

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	var stream := AudioStreamWAV.new()
	var settings := _make_settings(stream)
	settings.enabled = false
	system.settings = settings
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	system.process_tick(0.016)

	assert_eq(system.requests.size(), 0)
	assert_eq(_get_in_use_players().size(), 0)

func test_checkpoint_spawns_sound_at_spawn_point_position_when_present() -> void:
	var manager := _spawn_manager()
	await _pump()

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	add_child(spawn_point)
	autofree(spawn_point)
	spawn_point.global_position = Vector3(7, 8, 9)

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	var stream := AudioStreamWAV.new()
	system.settings = _make_settings(stream)
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	system.process_tick(0.016)

	var used := _get_in_use_players()
	assert_eq(used.size(), 1)
	assert_eq(used[0].global_position, Vector3(7, 8, 9))

func test_spawned_player_applies_volume_and_bus() -> void:
	var manager := _spawn_manager()
	await _pump()

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	add_child(spawn_point)
	autofree(spawn_point)
	spawn_point.global_position = Vector3.ZERO

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	var stream := AudioStreamWAV.new()
	var settings := _make_settings(stream)
	settings.volume_db = -6.0
	system.settings = settings
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	system.process_tick(0.016)

	var used := _get_in_use_players()
	assert_eq(used.size(), 1)
	assert_eq(used[0].volume_db, -6.0)
	assert_eq(used[0].bus, "SFX")

func test_pitch_variation_zero_results_in_default_pitch_scale() -> void:
	var manager := _spawn_manager()
	await _pump()

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	add_child(spawn_point)
	autofree(spawn_point)
	spawn_point.global_position = Vector3.ZERO

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	var stream := AudioStreamWAV.new()
	var settings := _make_settings(stream)
	settings.pitch_variation = 0.0
	system.settings = settings
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	system.process_tick(0.016)

	var used := _get_in_use_players()
	assert_eq(used.size(), 1)
	assert_eq(used[0].pitch_scale, 1.0)

func test_min_interval_prevents_multiple_spawns_in_same_tick() -> void:
	var manager := _spawn_manager()
	await _pump()

	var spawn_point := Node3D.new()
	spawn_point.name = "sp_test"
	add_child(spawn_point)
	autofree(spawn_point)
	spawn_point.global_position = Vector3.ZERO

	var system := CHECKPOINT_SOUND_SYSTEM.new()
	autofree(system)
	var stream := AudioStreamWAV.new()
	var settings := _make_settings(stream)
	settings.min_interval = 10.0
	system.settings = settings
	manager.add_child(system)
	await _pump()

	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	EVENT_BUS.publish(TEST_EVENT, {"spawn_point_id": StringName("sp_test")})
	system.process_tick(0.016)

	var used := _get_in_use_players()
	assert_eq(used.size(), 1)
