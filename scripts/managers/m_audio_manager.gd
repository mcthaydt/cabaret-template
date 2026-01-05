@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_AudioManager

## Audio Manager (Phase 1 - Core Manager & Bus Layout)
##
## Creates the audio bus hierarchy and applies volume/mute settings from the
## Redux audio slice.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")

var _state_store: I_StateStore = null
var _unsubscribe: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	U_SERVICE_LOCATOR.register(StringName("audio_manager"), self)

	_state_store = U_STATE_UTILS.try_get_store(self)
	if _state_store == null:
		print_verbose("M_AudioManager: StateStore not found. Audio settings will not be applied.")

	_create_bus_layout()

	if _state_store != null:
		_unsubscribe = _state_store.subscribe(_on_state_changed)
		_apply_audio_settings(_state_store.get_state())

func _exit_tree() -> void:
	if _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	_state_store = null

func _create_bus_layout() -> void:
	# Clear existing buses beyond Master (bus 0)
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)

	# Create bus hierarchy
	# Master (bus 0) - already exists
	# ├── Music (bus 1)
	# ├── SFX (bus 2)
	# │   ├── UI (bus 3)
	# │   └── Footsteps (bus 4)
	# └── Ambient (bus 5)

	AudioServer.add_bus(1)  # Music
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	AudioServer.add_bus(2)  # SFX
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")

	AudioServer.add_bus(3)  # UI
	AudioServer.set_bus_name(3, "UI")
	AudioServer.set_bus_send(3, "SFX")

	AudioServer.add_bus(4)  # Footsteps
	AudioServer.set_bus_name(4, "Footsteps")
	AudioServer.set_bus_send(4, "SFX")

	AudioServer.add_bus(5)  # Ambient
	AudioServer.set_bus_name(5, "Ambient")
	AudioServer.set_bus_send(5, "Master")

static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

func _on_state_changed(_action: Dictionary, state: Dictionary) -> void:
	_apply_audio_settings(state)

func _apply_audio_settings(state: Dictionary) -> void:
	if state == null:
		return

	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")

	AudioServer.set_bus_volume_db(master_idx, _linear_to_db(U_AUDIO_SELECTORS.get_master_volume(state)))
	AudioServer.set_bus_mute(master_idx, U_AUDIO_SELECTORS.is_master_muted(state))

	AudioServer.set_bus_volume_db(music_idx, _linear_to_db(U_AUDIO_SELECTORS.get_music_volume(state)))
	AudioServer.set_bus_mute(music_idx, U_AUDIO_SELECTORS.is_music_muted(state))

	AudioServer.set_bus_volume_db(sfx_idx, _linear_to_db(U_AUDIO_SELECTORS.get_sfx_volume(state)))
	AudioServer.set_bus_mute(sfx_idx, U_AUDIO_SELECTORS.is_sfx_muted(state))

	AudioServer.set_bus_volume_db(ambient_idx, _linear_to_db(U_AUDIO_SELECTORS.get_ambient_volume(state)))
	AudioServer.set_bus_mute(ambient_idx, U_AUDIO_SELECTORS.is_ambient_muted(state))

