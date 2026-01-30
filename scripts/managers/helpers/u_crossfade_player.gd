extends RefCounted
class_name U_CrossfadePlayer

## Crossfade Player Helper
##
## Manages dual AudioStreamPlayer instances for smooth crossfading between audio tracks.
## Used by M_AudioManager for music and ambient crossfades.

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_track_id: StringName = StringName("")
var _tween: Tween
var _owner_node: Node
var _paused_position: float = 0.0

func _init(owner: Node, bus: StringName) -> void:
	_owner_node = owner
	var bus_string := String(bus)

	# Create dual players
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "%sPlayerA" % bus_string
	_owner_node.add_child(_player_a)
	_player_a.bus = bus_string

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "%sPlayerB" % bus_string
	_owner_node.add_child(_player_b)
	_player_b.bus = bus_string

	_active_player = _player_a
	_inactive_player = _player_b

func crossfade_to(stream: AudioStream, track_id: StringName, duration: float, start_position: float = 0.0) -> void:
	"""Crossfade to a new audio stream.

	Args:
		stream: The audio stream to play
		track_id: Identifier for the track (for tracking)
		duration: Crossfade duration in seconds
		start_position: Position to start playback from (seconds)
	"""
	if stream == null:
		return

	# Kill existing tween
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Swap active/inactive players
	var old_player := _active_player
	var new_player := _inactive_player
	_active_player = new_player
	_inactive_player = old_player

	# Configure new player
	new_player.stream = stream
	new_player.volume_db = -80.0
	if start_position < 0.0:
		start_position = 0.0
	new_player.play(start_position)

	# Update track ID
	_current_track_id = track_id

	# Crossfade with cubic easing
	if duration < 0.0:
		duration = 0.0

	_tween = _owner_node.create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)

	# Fade out old player (if playing)
	if old_player.playing:
		_tween.tween_property(old_player, "volume_db", -80.0, duration)
		_tween.chain().tween_callback(old_player.stop)

	# Fade in new player
	_tween.tween_property(new_player, "volume_db", 0.0, duration)

func stop(duration: float = 0.0) -> void:
	"""Stop playback with optional fade out.

	Args:
		duration: Fade out duration in seconds
	"""
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if _active_player == null:
		return

	if duration < 0.0:
		duration = 0.0

	_tween = _owner_node.create_tween()
	_tween.tween_property(_active_player, "volume_db", -80.0, duration)
	_tween.chain().tween_callback(_active_player.stop)
	_current_track_id = StringName("")

func pause() -> void:
	"""Pause playback and store current position."""
	if _active_player == null or not _active_player.playing:
		return

	_paused_position = _active_player.get_playback_position()
	_active_player.stop()

func resume() -> void:
	"""Resume playback from stored position."""
	if _active_player == null or _active_player.stream == null:
		return

	_active_player.play(_paused_position)

func get_current_track_id() -> StringName:
	"""Get the ID of the currently playing track."""
	return _current_track_id

func get_playback_position() -> float:
	"""Get the current playback position in seconds."""
	if _active_player == null:
		return 0.0
	return _active_player.get_playback_position()

func is_playing() -> bool:
	"""Check if audio is currently playing."""
	if _active_player == null:
		return false
	return _active_player.playing

func cleanup() -> void:
	"""Free both players and clean up resources."""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	if _player_a != null and is_instance_valid(_player_a):
		_player_a.stop()
		_player_a.queue_free()

	if _player_b != null and is_instance_valid(_player_b):
		_player_b.stop()
		_player_b.queue_free()

	_player_a = null
	_player_b = null
	_active_player = null
	_inactive_player = null
