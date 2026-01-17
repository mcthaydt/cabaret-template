extends RefCounted
class_name M_SFXSpawner

const POOL_SIZE := 16

const _DEFAULT_MAX_DISTANCE: float = 50.0
const _DEFAULT_ATTENUATION_MODEL: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
const _DEFAULT_PANNING_STRENGTH: float = 1.0

static var _spatial_audio_enabled: bool = true
static var _pool: Array[AudioStreamPlayer3D] = []
static var _container: Node3D = null
static var _player_in_use: Dictionary = {}

static func set_spatial_audio_enabled(enabled: bool) -> void:
	_spatial_audio_enabled = enabled

static func is_spatial_audio_enabled() -> bool:
	return _spatial_audio_enabled

static func initialize(parent: Node) -> void:
	if parent == null:
		push_warning("M_SFXSpawner.initialize: parent is null")
		return

	if _container != null and is_instance_valid(_container):
		return

	_pool.clear()
	_player_in_use.clear()
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
		player.finished.connect(Callable(M_SFXSpawner, "_on_player_finished").bind(player))
		_container.add_child(player)
		_pool.append(player)

static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
	if config == null or config.is_empty():
		return null

	var audio_stream_variant: Variant = config.get("audio_stream", null)
	var audio_stream: AudioStream = null
	if audio_stream_variant is AudioStream:
		audio_stream = audio_stream_variant as AudioStream
	if audio_stream == null:
		return null

	var player := _get_available_player()
	if player == null:
		push_warning("SFX pool exhausted (all 16 players in use)")
		return null

	_player_in_use[player] = true

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
	var bus: String = String(bus_variant)

	if player.playing:
		player.stop()

	_configure_player_spatialization(player)

	player.stream = audio_stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus
	player.play()

	return player

static func _configure_player_spatialization(player: AudioStreamPlayer3D) -> void:
	if player == null or not is_instance_valid(player):
		return

	if _spatial_audio_enabled:
		player.attenuation_model = _DEFAULT_ATTENUATION_MODEL
		player.panning_strength = _DEFAULT_PANNING_STRENGTH
		player.max_distance = _DEFAULT_MAX_DISTANCE
		return

	# When disabled, make 3D playback behave like 2D:
	# - No distance attenuation
	# - No left/right panning
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.panning_strength = 0.0

static func _get_available_player() -> AudioStreamPlayer3D:
	for player_variant in _pool:
		var player := player_variant as AudioStreamPlayer3D
		if player == null:
			continue
		if not is_instance_valid(player):
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

static func cleanup() -> void:
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_pool.clear()
	_player_in_use.clear()
	_spatial_audio_enabled = true
