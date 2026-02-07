extends RefCounted
class_name U_SFXSpawner

## Phase 7 - SFX Spawner Improvements
## Adds voice stealing, per-sound configuration, bus fallback, follow-emitter mode

const POOL_SIZE := 16

const _DEFAULT_MAX_DISTANCE: float = 50.0
const _DEFAULT_ATTENUATION_MODEL: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
const _DEFAULT_PANNING_STRENGTH: float = 1.0

static var _spatial_audio_enabled: bool = true
static var _pool: Array[AudioStreamPlayer3D] = []
static var _container: Node3D = null
static var _player_in_use: Dictionary = {}
static var _play_times: Dictionary = {}  # player -> start_time (for voice stealing)
static var _follow_targets: Dictionary = {}  # player -> Node3D (for follow-emitter mode)
static var _stats: Dictionary = {
	"spawns": 0,
	"steals": 0,
	"drops": 0,
	"peak_usage": 0
}
static var _warned_uninitialized: bool = false

static func set_spatial_audio_enabled(enabled: bool) -> void:
	_spatial_audio_enabled = enabled

static func is_spatial_audio_enabled() -> bool:
	return _spatial_audio_enabled

## Get current stats (spawns, steals, drops, peak_usage)
static func get_stats() -> Dictionary:
	return _stats.duplicate()

## Reset stats counters
static func reset_stats() -> void:
	_stats["spawns"] = 0
	_stats["steals"] = 0
	_stats["drops"] = 0
	_stats["peak_usage"] = 0

## Update follow targets - moves players to follow their target nodes
static func update_follow_targets() -> void:
	var to_remove: Array[AudioStreamPlayer3D] = []

	for player in _follow_targets.keys():
		var target_variant: Variant = _follow_targets.get(player)

		# Check if player is invalid
		if player == null or not is_instance_valid(player):
			to_remove.append(player)
			continue

		# Check if target is invalid (handle freed nodes)
		if target_variant == null:
			to_remove.append(player)
			continue

		var target: Node3D = null
		if target_variant is Node3D:
			target = target_variant as Node3D

		if target == null or not is_instance_valid(target):
			to_remove.append(player)
			continue

		# Check if player is no longer playing
		if not player.playing:
			to_remove.append(player)
			continue

		# Update position (with safety check)
		if target.is_inside_tree():
			player.global_position = target.global_position

	# Clean up invalid entries
	for player in to_remove:
		_follow_targets.erase(player)

static func initialize(parent: Node) -> void:
	if parent == null:
		push_warning("U_SFXSpawner.initialize: parent is null")
		return

	if _container != null and is_instance_valid(_container):
		return

	_pool.clear()
	_player_in_use.clear()
	_play_times.clear()
	_follow_targets.clear()
	_container = Node3D.new()
	_container.name = "SFXPool"
	parent.add_child(_container)

	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFXPlayer%d" % i
		player.max_distance = _DEFAULT_MAX_DISTANCE
		player.attenuation_model = _DEFAULT_ATTENUATION_MODEL
		player.panning_strength = _DEFAULT_PANNING_STRENGTH
		_player_in_use[player] = false
		player.finished.connect(Callable(U_SFXSpawner, "_on_player_finished").bind(player))
		_container.add_child(player)
		_pool.append(player)

## Spawn a 3D audio player with the given configuration
##
## Config parameters:
## - audio_stream: AudioStream (required) - The audio stream to play
## - position: Vector3 (default: Vector3.ZERO) - World position for the sound
## - volume_db: float (default: 0.0) - Volume in decibels
## - pitch_scale: float (default: 1.0) - Pitch multiplier (must be > 0)
## - bus: String (default: "SFX") - Audio bus name (validates existence, falls back to "SFX")
## - max_distance: float (default: 50.0) - Maximum audible distance (only if > 0)
## - attenuation_model: int (default: ATTENUATION_INVERSE_DISTANCE) - Attenuation model (only if >= 0)
## - follow_target: Node3D (optional) - Node to follow for moving sounds
##
## Voice stealing: If all 16 players are in use, the oldest playing sound will be stopped
## and reused for the new sound. Stats are tracked via get_stats().
static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
	if config == null or config.is_empty():
		return null

	var audio_stream_variant: Variant = config.get("audio_stream", null)
	var audio_stream: AudioStream = null
	if audio_stream_variant is AudioStream:
		audio_stream = audio_stream_variant as AudioStream
	if audio_stream == null:
		return null

	if _pool.is_empty():
		_warn_uninitialized()

	var player := _get_available_player()
	if player == null:
		# Voice stealing: steal oldest playing sound
		player = _steal_oldest_voice()
		if player == null:
			_stats["drops"] += 1
			return null

	_player_in_use[player] = true
	_stats["spawns"] += 1

	var position_variant: Variant = config.get("position", Vector3.ZERO)
	var position: Vector3 = Vector3.ZERO
	if position_variant is Vector3:
		position = position_variant

	var volume_db_variant: Variant = config.get("volume_db", 0.0)
	var volume_db: float = float(volume_db_variant)

	var pitch_scale_variant: Variant = config.get("pitch_scale", 1.0)
	var pitch_scale: float = float(pitch_scale_variant)
	if pitch_scale <= 0.0:
		pitch_scale = 1.0

	var bus_variant: Variant = config.get("bus", "SFX")
	var bus: String = _validate_bus(String(bus_variant))

	# Extract per-sound spatialization config
	var max_distance_variant: Variant = config.get("max_distance", 0.0)
	var max_distance: float = float(max_distance_variant)

	var attenuation_model_variant: Variant = config.get("attenuation_model", -1)
	var attenuation_model: int = int(attenuation_model_variant)

	# Extract follow_target config
	var follow_target_variant: Variant = config.get("follow_target", null)
	var follow_target: Node3D = null
	if follow_target_variant is Node3D:
		follow_target = follow_target_variant as Node3D

	var emitter_variant: Variant = config.get("debug_emitter", null)
	var emitter: Node3D = null
	if emitter_variant is Node3D:
		emitter = emitter_variant as Node3D

	if player.playing:
		player.stop()

	_configure_player_spatialization(player, max_distance, attenuation_model)

	player.stream = audio_stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus
	player.play()

	# Store play time for voice stealing
	_play_times[player] = Time.get_ticks_msec()

	# Store follow target if valid
	if follow_target != null and is_instance_valid(follow_target):
		_follow_targets[player] = follow_target

	# Update peak usage stat
	_update_peak_usage()

	return player

static func _warn_uninitialized() -> void:
	if _warned_uninitialized:
		return
	_warned_uninitialized = true
	push_warning("U_SFXSpawner.spawn_3d: SFX pool not initialized. Ensure M_AudioManager is in the scene or call U_SFXSpawner.initialize(...) before playing SFX.")

static func _configure_player_spatialization(
	player: AudioStreamPlayer3D,
	max_distance: float = 0.0,
	attenuation_model: int = -1
) -> void:
	if player == null or not is_instance_valid(player):
		return

	if _spatial_audio_enabled:
		# Apply per-sound max_distance if provided (> 0), else use default
		if max_distance > 0.0:
			player.max_distance = max_distance
		else:
			player.max_distance = _DEFAULT_MAX_DISTANCE

		# Apply per-sound attenuation_model if provided (>= 0), else use default
		if attenuation_model >= 0:
			player.attenuation_model = attenuation_model
		else:
			player.attenuation_model = _DEFAULT_ATTENUATION_MODEL

		player.panning_strength = _DEFAULT_PANNING_STRENGTH
		return

	# When disabled, make 3D playback behave like 2D:
	# - No distance attenuation
	# - No left/right panning
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.panning_strength = 0.0

## Steal the oldest playing voice when pool is exhausted
static func _steal_oldest_voice() -> AudioStreamPlayer3D:
	var oldest_player: AudioStreamPlayer3D = null
	var oldest_time: int = 2147483647  # Max int

	for player_variant in _pool:
		if player_variant == null:
			continue
		if not is_instance_valid(player_variant):
			continue
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if not player.playing:
			continue

		var play_time := int(_play_times.get(player, 0))
		if play_time < oldest_time:
			oldest_time = play_time
			oldest_player = player

	if oldest_player != null:
		oldest_player.stop()
		_player_in_use[oldest_player] = false
		_play_times.erase(oldest_player)
		_follow_targets.erase(oldest_player)
		_stats["steals"] += 1

	return oldest_player

## Validate bus exists, fallback to "SFX" if not found
static func _validate_bus(bus: String) -> String:
	if AudioServer.get_bus_index(bus) != -1:
		return bus

	push_warning("Unknown audio bus '%s', falling back to 'SFX'" % bus)
	return "SFX"

## Update peak usage stat
static func _update_peak_usage() -> void:
	var current_usage := 0
	for player in _pool:
		if player != null and is_instance_valid(player) and player.playing:
			current_usage += 1

	if current_usage > _stats["peak_usage"]:
		_stats["peak_usage"] = current_usage

static func _get_available_player() -> AudioStreamPlayer3D:
	for player_variant in _pool:
		if player_variant == null:
			continue
		if not is_instance_valid(player_variant):
			continue
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		var in_use := bool(_player_in_use.get(player, false))
		if not in_use:
			return player
	return null

static func is_player_in_use(player: AudioStreamPlayer3D) -> bool:
	if player == null:
		return false
	return bool(_player_in_use.get(player, false))

static func _on_player_finished(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	if not is_instance_valid(player):
		return
	_player_in_use[player] = false
	_play_times.erase(player)
	_follow_targets.erase(player)

static func cleanup() -> void:
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_pool.clear()
	_player_in_use.clear()
	_play_times.clear()
	_follow_targets.clear()
	_spatial_audio_enabled = true
