# Audio Manager PRD

**Project**: Cabaret Template (Godot 4.5)
**Owner**: Development Team
**Feature Branch**: `feature/audio-manager`
**Created**: 2026-01-01
**Last Updated**: 2026-01-10
**Target Release**: Phase 1 (3 weeks)
**Status**: IN PROGRESS (Phase 0–9 complete; Phase 10 in progress)
**Version**: 1.0

## Problem Statement

### What Problem Are We Solving?

The game currently has no audio system. Players experience complete silence during gameplay, menu navigation, and critical events. Without music, sound effects, or UI feedback, the game feels lifeless and fails to provide essential audio cues for gameplay events (jumping, landing, taking damage, checkpoints).

### Why Now?

- **Game Feel**: Audio is fundamental to platformer game feel - silent jumps and landings feel broken
- **User Feedback**: UI interactions need audio confirmation (button presses, focus changes)
- **Immersion**: Background music and ambient sound create atmosphere and engagement
- **Accessibility**: Audio cues provide alternative feedback for visual events (damage, checkpoints)
- **Polish**: Audio is table-stakes for any shipping game - critical for first impressions

### User Impact

**Without Audio Manager**:
- Complete silence during gameplay (no music, SFX, ambient sound)
- No UI audio feedback (button presses feel unresponsive)
- Missing audio cues for critical events (damage, death, checkpoints)
- No volume controls or audio settings
- Poor accessibility for users who rely on audio cues

**With Audio Manager**:
- Background music with smooth crossfading between scenes
- Comprehensive SFX for all gameplay events (jump, land, damage, death, victory)
- Surface-aware footstep sounds (different sounds for grass, stone, wood, metal, water)
- Ambient audio per scene (outdoor wind/birds, indoor quiet hum)
- UI sound effects for menu navigation
- Settings panel for volume/mute controls per bus (Master, Music, SFX, Ambient)
- 3D spatial audio with attenuation and panning

## Goals

1. **Music System**: Background music with crossfading between scenes/screens
2. **SFX Systems**: Event-driven sound effects for all gameplay events via BaseEventSFXSystem
3. **Footstep System**: Surface-aware footsteps with raycast detection (6 surface types)
4. **Ambient System**: Per-scene ambient loops with crossfading
5. **UI Sound Integration**: Menu navigation sounds (focus, confirm, cancel, slider tick)
6. **Redux Integration**: Audio settings (4 volumes + 4 mutes + spatial toggle) in Redux state
7. **Audio Bus Management**: Hierarchical bus layout (Master → Music/SFX/Ambient, SFX → UI/Footsteps)
8. **3D Spatial Audio**: Position-based sound (AudioStreamPlayer3D) with a listener (AudioListener3D/camera) and an optional user toggle to disable attenuation/panning
9. **Settings Persistence**: Audio preferences saved with game progress
10. **Pooled Audio Players**: Efficient SFX spawning with 16-player pool for 3D sounds

## Non-Goals

- **Dynamic Music System** (adaptive layers, stems switching based on gameplay intensity) - Future enhancement
- **Voice/Dialogue System** - Out of scope for initial implementation
- **Audio Streaming from External Sources** - All audio bundled with game
- **Reverb Zones / Complex Acoustic Simulation** - Simple spatial attenuation only
- **Runtime Audio Generation / Synthesis** - Pre-recorded assets only
- **Music Composition / SFX Creation** - PRD specifies formats, not asset creation

## Functional Requirements

### Phase 0: Redux Foundation (FR-001 to FR-005)

**FR-001: Audio Redux Slice**
The Audio system SHALL define a Redux slice named `audio` with the following fields:

| Field | Type | Default | Range/Values | Description |
|-------|------|---------|--------------|-------------|
| `master_volume` | float | 1.0 | 0.0-1.0 | Global volume multiplier |
| `music_volume` | float | 1.0 | 0.0-1.0 | Music bus volume |
| `sfx_volume` | float | 1.0 | 0.0-1.0 | SFX bus volume |
| `ambient_volume` | float | 1.0 | 0.0-1.0 | Ambient bus volume |
| `master_muted` | bool | false | true/false | Global mute toggle |
| `music_muted` | bool | false | true/false | Music mute toggle |
| `sfx_muted` | bool | false | true/false | SFX mute toggle |
| `ambient_muted` | bool | false | true/false | Ambient mute toggle |
| `spatial_audio_enabled` | bool | true | true/false | 3D audio processing toggle |

**FR-002: Audio Action Creators**
The system SHALL provide action creators in `U_AudioActions` for all 12 settings:

```gdscript
class_name U_AudioActions
extends RefCounted

# Volume actions
const ACTION_SET_MASTER_VOLUME := StringName("audio/set_master_volume")
const ACTION_SET_MUSIC_VOLUME := StringName("audio/set_music_volume")
const ACTION_SET_SFX_VOLUME := StringName("audio/set_sfx_volume")
const ACTION_SET_AMBIENT_VOLUME := StringName("audio/set_ambient_volume")

# Mute actions
const ACTION_SET_MASTER_MUTED := StringName("audio/set_master_muted")
const ACTION_SET_MUSIC_MUTED := StringName("audio/set_music_muted")
const ACTION_SET_SFX_MUTED := StringName("audio/set_sfx_muted")
const ACTION_SET_AMBIENT_MUTED := StringName("audio/set_ambient_muted")

# Spatial audio action
const ACTION_SET_SPATIAL_AUDIO_ENABLED := StringName("audio/set_spatial_audio_enabled")

## Static initializer - automatically registers actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_MASTER_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_MUSIC_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_SFX_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_AMBIENT_VOLUME)
	U_ActionRegistry.register_action(ACTION_SET_MASTER_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_MUSIC_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_SFX_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_AMBIENT_MUTED)
	U_ActionRegistry.register_action(ACTION_SET_SPATIAL_AUDIO_ENABLED)

static func set_master_volume(volume: float) -> Dictionary:
	return {"type": ACTION_SET_MASTER_VOLUME, "payload": {"volume": volume}}

static func set_music_volume(volume: float) -> Dictionary:
	return {"type": ACTION_SET_MUSIC_VOLUME, "payload": {"volume": volume}}

static func set_sfx_volume(volume: float) -> Dictionary:
	return {"type": ACTION_SET_SFX_VOLUME, "payload": {"volume": volume}}

static func set_ambient_volume(volume: float) -> Dictionary:
	return {"type": ACTION_SET_AMBIENT_VOLUME, "payload": {"volume": volume}}

static func set_master_muted(muted: bool) -> Dictionary:
	return {"type": ACTION_SET_MASTER_MUTED, "payload": {"muted": muted}}

static func set_music_muted(muted: bool) -> Dictionary:
	return {"type": ACTION_SET_MUSIC_MUTED, "payload": {"muted": muted}}

static func set_sfx_muted(muted: bool) -> Dictionary:
	return {"type": ACTION_SET_SFX_MUTED, "payload": {"muted": muted}}

static func set_ambient_muted(muted: bool) -> Dictionary:
	return {"type": ACTION_SET_AMBIENT_MUTED, "payload": {"muted": muted}}

static func set_spatial_audio_enabled(enabled: bool) -> Dictionary:
	return {"type": ACTION_SET_SPATIAL_AUDIO_ENABLED, "payload": {"enabled": enabled}}
```

**FR-003: Audio Reducer**
The system SHALL implement `U_AudioReducer` with:
- Immutable state updates (no mutations)
- Volume clamping to 0.0-1.0 range
- Unknown action handling (return unchanged state)

```gdscript
class_name U_AudioReducer
extends RefCounted

const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName(""))
	var payload: Dictionary = action.get("payload", {})

	match action_type:
		U_AUDIO_ACTIONS.ACTION_SET_MASTER_VOLUME:
			var new_state := state.duplicate(true)
			var volume: float = payload.get("volume", 1.0)
			new_state["master_volume"] = clampf(volume, 0.0, 1.0)
			return new_state

		U_AUDIO_ACTIONS.ACTION_SET_MUSIC_VOLUME:
			var new_state := state.duplicate(true)
			var volume: float = payload.get("volume", 1.0)
			new_state["music_volume"] = clampf(volume, 0.0, 1.0)
			return new_state

		# ... (similar for sfx_volume, ambient_volume)

		U_AUDIO_ACTIONS.ACTION_SET_MASTER_MUTED:
			var new_state := state.duplicate(true)
			new_state["master_muted"] = payload.get("muted", false)
			return new_state

		# ... (similar for music_muted, sfx_muted, ambient_muted)

		U_AUDIO_ACTIONS.ACTION_SET_SPATIAL_AUDIO_ENABLED:
			var new_state := state.duplicate(true)
			new_state["spatial_audio_enabled"] = payload.get("enabled", true)
			return new_state

		_:
			return state
```

**FR-004: Audio Selectors**
The system SHALL provide selectors in `U_AudioSelectors`:

```gdscript
class_name U_AudioSelectors
extends RefCounted

static func get_master_volume(state: Dictionary) -> float:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("master_volume", 1.0)

static func get_music_volume(state: Dictionary) -> float:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("music_volume", 1.0)

static func get_sfx_volume(state: Dictionary) -> float:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("sfx_volume", 1.0)

static func get_ambient_volume(state: Dictionary) -> float:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("ambient_volume", 1.0)

static func is_master_muted(state: Dictionary) -> bool:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("master_muted", false)

static func is_music_muted(state: Dictionary) -> bool:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("music_muted", false)

static func is_sfx_muted(state: Dictionary) -> bool:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("sfx_muted", false)

static func is_ambient_muted(state: Dictionary) -> bool:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("ambient_muted", false)

static func is_spatial_audio_enabled(state: Dictionary) -> bool:
	var audio_slice: Dictionary = state.get("audio", {})
	return audio_slice.get("spatial_audio_enabled", true)
```

**FR-005: Audio Initial State Resource**
The system SHALL define `RS_AudioInitialState` resource:

```gdscript
class_name RS_AudioInitialState
extends Resource

@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var ambient_volume: float = 1.0
@export var master_muted: bool = false
@export var music_muted: bool = false
@export var sfx_muted: bool = false
@export var ambient_muted: bool = false
@export var spatial_audio_enabled: bool = true

func to_dictionary() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume,
		"master_muted": master_muted,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted,
		"ambient_muted": ambient_muted,
		"spatial_audio_enabled": spatial_audio_enabled,
	}
```

### Phase 1: Core Manager (FR-006 to FR-012)

**FR-006: M_AudioManager Lifecycle**
The Audio Manager SHALL:
- Extend `Node` with `process_mode = PROCESS_MODE_ALWAYS`
- Add itself to `"audio_manager"` group on `_ready()`
- Register with `U_ServiceLocator` as `"audio_manager"`
- Maintain single instance pattern

```gdscript
@icon("res://assets/editor_icons/manager.svg")
class_name M_AudioManager
extends Node

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_AUDIO_SELECTORS := preload("res://scripts/state/selectors/u_audio_selectors.gd")

var _state_store: I_StateStore
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _current_music_id: StringName = StringName("")
var _music_tween: Tween

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	U_ServiceLocator.register(StringName("audio_manager"), self)

	_state_store = U_StateUtils.get_store(self)
	if _state_store != null:
		_state_store.slice_updated.connect(_on_slice_updated)

	_create_audio_bus_layout()
	_initialize_music_players()
	_apply_audio_settings()
```

**FR-007: Redux State Subscription**
The manager SHALL subscribe to `M_StateStore.slice_updated` signal and apply audio settings changes in real-time:

```gdscript
func _on_slice_updated(slice_name: StringName, _new_slice: Variant) -> void:
	if slice_name != StringName("audio"):
		return

	_apply_audio_settings()

func _apply_audio_settings() -> void:
	if _state_store == null:
		return

	var state := _state_store.get_state()

	# Apply volumes (convert 0.0-1.0 to dB)
	var master_volume := U_AUDIO_SELECTORS.get_master_volume(state)
	var music_volume := U_AUDIO_SELECTORS.get_music_volume(state)
	var sfx_volume := U_AUDIO_SELECTORS.get_sfx_volume(state)
	var ambient_volume := U_AUDIO_SELECTORS.get_ambient_volume(state)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), _linear_to_db(ambient_volume))

	# Apply mutes
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), U_AUDIO_SELECTORS.is_master_muted(state))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), U_AUDIO_SELECTORS.is_music_muted(state))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), U_AUDIO_SELECTORS.is_sfx_muted(state))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambient"), U_AUDIO_SELECTORS.is_ambient_muted(state))

## Convert linear volume (0.0-1.0) to logarithmic dB (-80dB to 0dB)
static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0  # Effectively silent
	return 20.0 * log(linear) / log(10.0)
```

**FR-008: Audio Bus Layout Creation**
The manager SHALL create the following bus hierarchy at startup (if not already exists):

```
Master (bus 0)
├── Music (bus 1)
├── SFX (bus 2)
│   ├── UI (bus 3)
│   └── Footsteps (bus 4)
└── Ambient (bus 5)
```

```gdscript
func _create_audio_bus_layout() -> void:
	# Check if buses already exist (may be pre-configured in project)
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")

	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")

	if AudioServer.get_bus_index("UI") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "UI")
		AudioServer.set_bus_send(AudioServer.get_bus_index("UI"), "SFX")

	if AudioServer.get_bus_index("Footsteps") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Footsteps")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Footsteps"), "SFX")

	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Ambient")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Ambient"), "Master")
```

**FR-009: Music Playback API**
The manager SHALL provide a public method for music playback (manual override; music is primarily scene-driven via `scene/transition_completed` and pause actions):

```gdscript
func play_music(track_id: StringName, duration: float = 1.5) -> void
```

**FR-010: 3D SFX Pooling API**
The audio stack SHALL provide a pooled 3D SFX helper for gameplay systems:

```gdscript
U_SFXSpawner.spawn_3d({
	"audio_stream": stream,
	"position": position,
	"volume_db": volume_db,
	"pitch_scale": pitch_scale,
	"bus": "SFX",
}) -> AudioStreamPlayer3D
```

**FR-011: UI Sound Playback**
The manager SHALL provide UI sound playback, and UI scripts SHALL use `U_UISoundPlayer` for focus/confirm/cancel/tick:

```gdscript
M_AudioManager.play_ui_sound(sound_id: StringName) -> void
U_UISoundPlayer.play_focus()
U_UISoundPlayer.play_confirm()
U_UISoundPlayer.play_cancel()
U_UISoundPlayer.play_slider_tick()
```

**FR-012: Manager Public API Summary**
Complete public API for M_AudioManager:

```gdscript
# Music
func play_music(track_id: StringName, duration: float = 1.5) -> void

# UI Sounds
func play_ui_sound(sound_id: StringName) -> void

# 3D SFX (helper; used by ECS sound systems)
U_SFXSpawner.spawn_3d(config: Dictionary) -> AudioStreamPlayer3D
```

### Phase 2: Music System (FR-013 to FR-018)

**FR-013: Dual AudioStreamPlayer Architecture**
The music system SHALL use two `AudioStreamPlayer` instances for crossfading:

```gdscript
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer  # Points to current player
var _inactive_music_player: AudioStreamPlayer  # Points to fade-out player

func _initialize_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)

	_active_music_player = _music_player_a
	_inactive_music_player = _music_player_b
```

**FR-014: Music Track Registry**
The system SHALL maintain a registry mapping track IDs to AudioStream resources and scene associations:

```gdscript
var _music_registry: Dictionary = {
	StringName("main_menu"): {
		"stream": preload("res://assets/audio/music/main_menu.ogg"),
		"scene": StringName("main_menu")
	},
	StringName("gameplay_exterior"): {
		"stream": preload("res://assets/audio/music/gameplay_exterior.ogg"),
		"scene": StringName("gameplay_exterior")
	},
	StringName("gameplay_interior"): {
		"stream": preload("res://assets/audio/music/gameplay_interior.ogg"),
		"scene": StringName("gameplay_interior_house")
	},
	StringName("pause"): {
		"stream": preload("res://assets/audio/music/pause.ogg"),
		"scene": StringName("")  # Used for pause overlay
	},
	StringName("credits"): {
		"stream": preload("res://assets/audio/music/credits.ogg"),
		"scene": StringName("credits")
	}
}

func _get_music_stream(track_id: StringName) -> AudioStream:
	var entry: Dictionary = _music_registry.get(track_id, {})
	return entry.get("stream", null)
```

**FR-015: Crossfade Algorithm**
The music system SHALL crossfade using Tween with parallel fade out/in:

```gdscript
func _crossfade_music(new_stream: AudioStream, track_id: StringName, duration: float) -> void:
	# Kill existing tween
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	# Swap active/inactive players
	var old_player := _active_music_player
	var new_player := _inactive_music_player
	_active_music_player = new_player
	_inactive_music_player = old_player

	# Setup new player
	new_player.stream = new_stream
	new_player.volume_db = -80.0  # Start silent
	new_player.play()

	# Create parallel tween
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.set_trans(Tween.TRANS_CUBIC)
	_music_tween.set_ease(Tween.EASE_IN_OUT)

	# Fade out old player
	if old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", -80.0, duration)
		_music_tween.chain().tween_callback(old_player.stop)

	# Fade in new player
	_music_tween.tween_property(new_player, "volume_db", 0.0, duration)

	_current_music_id = track_id
```

**FR-016: Scene Transition Music Change**
The music system SHALL subscribe to `scene/transition_completed` Redux action to auto-change tracks:

```gdscript
func _ready() -> void:
	# ... existing setup ...

	if _state_store != null:
		_state_store.action_dispatched.connect(_on_action_dispatched)

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))

	if action_type == StringName("scene/transition_completed"):
		var payload: Dictionary = action.get("payload", {})
		var scene_id: StringName = payload.get("scene_id", StringName(""))
		_change_music_for_scene(scene_id)

func _change_music_for_scene(scene_id: StringName) -> void:
	# Find music track associated with scene
	for track_id in _music_registry:
		var entry: Dictionary = _music_registry[track_id]
		if entry.get("scene", StringName("")) == scene_id:
			play_music(track_id, 1.0)  # 1.0s crossfade
			return
```

**FR-017: Music Mute Behavior**
Music SHALL respect mute toggle with immediate silence/resume:

```gdscript
# In _apply_audio_settings():
var music_muted := U_AUDIO_SELECTORS.is_music_muted(state)
AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_muted)

# Mute is instant - no fade. Volume remains at previous level for unmute.
```

**FR-018: Music Volume Application**
Music volume SHALL apply from Redux state using logarithmic dB conversion:

```gdscript
# Formula: dB = 20 * log10(linear)
# Examples:
#   linear = 0.0 → -80dB (silent)
#   linear = 0.5 → -6dB (half perceived volume)
#   linear = 1.0 → 0dB (full volume)

static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
```

**FR-019: Pause Overlay Music Handling**
The music system SHALL handle pause overlay open/close with partial crossfade, and resume the pre-pause track from its previous playback position (no restart):

```gdscript
# Track previous music state for pause overlay
var _pre_pause_music_id: StringName = StringName("")
var _pre_pause_music_position: float = 0.0
var _is_pause_overlay_active: bool = false

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))

	match action_type:
		StringName("scene/transition_completed"):
			var payload: Dictionary = action.get("payload", {})
			var scene_id: StringName = payload.get("scene_id", StringName(""))
			_change_music_for_scene(scene_id)

		StringName("navigation/open_pause"):
			if _is_pause_overlay_active:
				return
			_is_pause_overlay_active = true
			_pre_pause_music_id = _current_music_id
			_pre_pause_music_position = _active_music_player.get_playback_position()
			play_music(StringName("pause"), 0.5)  # 0.5s crossfade

		StringName("navigation/close_pause"):
			if not _is_pause_overlay_active:
				return
			_is_pause_overlay_active = false
			if _pre_pause_music_id != StringName(""):
				play_music(_pre_pause_music_id, 0.5, _pre_pause_music_position)  # Restore previous track position
			_pre_pause_music_id = StringName("")
			_pre_pause_music_position = 0.0
```

**Note**: Pause overlay approach uses separate pause track. Alternative approach (apply low-pass filter to current track) is deferred to future enhancement.

### Phase 3: BaseEventSFXSystem Pattern (FR-020 to FR-024)

**FR-020: BaseEventSFXSystem Base Class**
The system SHALL implement `BaseEventSFXSystem` extending `BaseECSSystem` (mirrors `BaseEventVFXSystem`):

```gdscript
extends BaseECSSystem
class_name BaseEventSFXSystem

## Base class for SFX systems that respond to ECS events (mirrors BaseEventVFXSystem)

const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

## Queue of sound requests to be processed in process_tick()
var requests: Array = []

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	requests.clear()

## Override in subclass to return the event name to subscribe to
func get_event_name() -> StringName:
	push_error("BaseEventSFXSystem.get_event_name() must be overridden in subclass %s" % get_class())
	return StringName()

## Override in subclass to create a request dictionary from event payload
func create_request_from_payload(payload: Dictionary) -> Dictionary:
	push_error("BaseEventSFXSystem.create_request_from_payload() must be overridden in subclass %s" % get_class())
	return {}

func _subscribe() -> void:
	_unsubscribe()
	requests.clear()

	var event_name := get_event_name()
	if event_name == StringName():
		return

	_unsubscribe_callable = EVENT_BUS.subscribe(event_name, Callable(self, "_on_event"))

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable():
		_unsubscribe_callable.call()
		_unsubscribe_callable = Callable()

func _on_event(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := create_request_from_payload(payload)

	# Add timestamp if not already present
	if not request.has("timestamp"):
		request["timestamp"] = event_data.get("timestamp", 0.0)

	requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}

func process_tick(_delta: float) -> void:
	# Subclass implements sound spawning via U_SFXSpawner
	pass
```

**FR-021: Event Subscription Lifecycle**
The base class SHALL provide automatic event subscription/unsubscription:
- Subscribe on `_ready()`
- Unsubscribe on `_exit_tree()`
- Callable-based unsubscribe for clean memory management

**FR-022: Request Queue Management**
The base class SHALL manage request queue:
- Append requests on event publication (`_on_event`)
- Process requests in `process_tick()`
- Clear requests after processing (each frame)

**FR-023: Subclass Override Pattern**
Subclasses SHALL override two methods:
1. `get_event_name() -> StringName`: Return event to subscribe to
2. `create_request_from_payload(payload) -> Dictionary`: Extract relevant data from event payload

**FR-024: _spawn_sound() Pattern**
Subclasses SHALL implement `process_tick()` to dequeue and spawn sounds:

```gdscript
func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	for request in requests:
		_spawn_sound(request)

	requests.clear()

func _spawn_sound(request: Dictionary) -> void:
	var position: Vector3 = request.get("position", Vector3.ZERO)
	var config := {
		"audio_stream": settings.audio_stream,
		"position": position,
		"volume_db": settings.volume_db,
		"pitch_scale": randf_range(1.0 - settings.pitch_variation, 1.0 + settings.pitch_variation),
		"bus": "SFX"
	}
	U_SFXSpawner.spawn_3d(config)
```

### Phase 4: SFX Systems (FR-024 to FR-030)

**FR-025: S_JumpSoundSystem**
The system SHALL play jump SFX on `entity_jumped` event:

```gdscript
extends BaseEventSFXSystem
class_name S_JumpSoundSystem

@export var settings: RS_JumpSoundSettings

func get_event_name() -> StringName:
	return StringName("entity_jumped")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"jump_force": payload.get("jump_force", 0.0),
	}

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		U_SFXSpawner.spawn_3d({
			"audio_stream": settings.audio_stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": randf_range(1.0 - settings.pitch_variation, 1.0 + settings.pitch_variation),
			"bus": "SFX"
		})

	requests.clear()
```

**FR-026: S_LandingSoundSystem**
The system SHALL play landing SFX on `entity_landed` event with intensity based on fall velocity:

```gdscript
extends BaseEventSFXSystem
class_name S_LandingSoundSystem

@export var settings: RS_LandingSoundSettings

func get_event_name() -> StringName:
	return StringName("entity_landed")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"vertical_velocity": payload.get("vertical_velocity", 0.0),
	}

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		var vertical_velocity: float = absf(request.get("vertical_velocity", 0.0))

		# Choose soft or hard landing sound based on velocity
		var audio_stream: AudioStream
		if vertical_velocity < 15.0:
			audio_stream = settings.soft_landing_stream
		else:
			audio_stream = settings.hard_landing_stream

		U_SFXSpawner.spawn_3d({
			"audio_stream": audio_stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": randf_range(1.0 - settings.pitch_variation, 1.0 + settings.pitch_variation),
			"bus": "SFX"
		})

	requests.clear()
```

**FR-027: S_DeathSoundSystem**
The system SHALL play death SFX on `entity_death` event:

```gdscript
extends BaseEventSFXSystem
class_name S_DeathSoundSystem

@export var settings: RS_DeathSoundSettings

func get_event_name() -> StringName:
	return StringName("entity_death")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"entity_id": payload.get("entity_id", StringName("")),
	}

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		U_SFXSpawner.spawn_3d({
			"audio_stream": settings.audio_stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": 1.0,  # No pitch variation for death sound
			"bus": "SFX"
		})

	requests.clear()
```

**FR-028: S_CheckpointSoundSystem**
The system SHALL play checkpoint SFX on `checkpoint_activated` event:

```gdscript
extends BaseEventSFXSystem
class_name S_CheckpointSoundSystem

@export var settings: RS_CheckpointSoundSettings

func get_event_name() -> StringName:
	return StringName("checkpoint_activated")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"checkpoint_id": payload.get("checkpoint_id", StringName("")),
		"spawn_point_id": payload.get("spawn_point_id", StringName("")),
	}

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	var stream := settings.audio_stream as AudioStream
	if stream == null:
		requests.clear()
		return

	# Checkpoint sound plays at the activated checkpoint spawn point (3D).
	for request in requests:
		var spawn_point_id: StringName = request.get("spawn_point_id", StringName(""))
		var position := _resolve_spawn_point_position(spawn_point_id)
		U_SFXSpawner.spawn_3d({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": 1.0,
			"bus": "SFX"
		})

	requests.clear()

func _resolve_spawn_point_position(spawn_point_id: StringName) -> Vector3:
	if spawn_point_id == StringName(""):
		return Vector3.ZERO
	var node := get_tree().current_scene.find_child(String(spawn_point_id), true, false) as Node3D
	return node.global_position if node != null else Vector3.ZERO
```

**FR-029: S_VictorySoundSystem**
The system SHALL play victory fanfare on `victory_triggered` event:

```gdscript
extends BaseEventSFXSystem
class_name S_VictorySoundSystem

@export var settings: RS_VictorySoundSettings

func get_event_name() -> StringName:
	return StringName("victory_triggered")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	var position := Vector3.ZERO
	var body := payload.get("body") as Node3D
	if body != null and is_instance_valid(body):
		position = body.global_position
	else:
		var position_variant: Variant = payload.get("position", Vector3.ZERO)
		if position_variant is Vector3:
			position = position_variant

	return {
		"position": position,
	}

func process_tick(_delta: float) -> void:
	if settings == null or not settings.enabled:
		requests.clear()
		return

	var stream := settings.audio_stream as AudioStream
	if stream == null:
		requests.clear()
		return

	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		U_SFXSpawner.spawn_3d({
			"audio_stream": stream,
			"position": position,
			"volume_db": settings.volume_db,
			"pitch_scale": 1.0,
			"bus": "SFX"
		})

	requests.clear()
```

**FR-029: Sound Settings Resources**
Each sound system SHALL have a settings resource with common structure:

```gdscript
class_name RS_JumpSoundSettings
extends Resource

@export var enabled: bool = true
@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.1  # Random pitch ± this value
@export var min_interval: float = 0.1     # Prevent spam (future enhancement)
```

**FR-030: U_SFXSpawner Utility**
The system SHALL implement `U_SFXSpawner` for pooled AudioStreamPlayer3D management:

```gdscript
class_name U_SFXSpawner
extends RefCounted

const POOL_SIZE := 16  # Maximum concurrent 3D sounds
const META_IN_USE := &"_sfx_in_use"

static var _pool: Array[AudioStreamPlayer3D] = []
static var _container: Node3D = null

static func initialize(parent: Node) -> void:
	if parent == null:
		return

	if _container != null and is_instance_valid(_container):
		return

	_container = Node3D.new()
	_container.name = "SFXPool"
	parent.add_child(_container)

	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.set_meta(META_IN_USE, false)
		_container.add_child(player)
		_pool.append(player)

static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
	var audio_stream := config.get("audio_stream") as AudioStream
	if audio_stream == null:
		return null

	var player := _get_available_player()
	if player == null:
		# Pool exhausted, skip sound
		return null

	player.set_meta(META_IN_USE, true)
	player.stream = audio_stream
	player.global_position = config.get("position", Vector3.ZERO)
	player.volume_db = config.get("volume_db", 0.0)
	player.pitch_scale = config.get("pitch_scale", 1.0)
	player.bus = config.get("bus", "SFX")
	player.play()

	return player

static func _get_available_player() -> AudioStreamPlayer3D:
	for player in _pool:
		var in_use := bool(player.get_meta(META_IN_USE, false))
		if not in_use:
			return player
	return null  # Pool exhausted
```

### Phase 5: Footstep System (FR-031 to FR-034)

**FR-032: C_SurfaceDetectorComponent**
The system SHALL implement surface detection component using raycast:

```gdscript
class_name C_SurfaceDetectorComponent
extends BaseECSComponent

const COMPONENT_TYPE := StringName("C_SurfaceDetectorComponent")

enum SurfaceType {
	GRASS = 0,
	STONE = 1,
	WOOD = 2,
	METAL = 3,
	WATER = 4,
	DEFAULT = 5
}

@export var ray_length: float = 2.0
@export var default_surface: SurfaceType = SurfaceType.DEFAULT

var _raycast: RayCast3D

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	super._ready()
	_setup_raycast()

func _setup_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.target_position = Vector3(0, -ray_length, 0)
	_raycast.collision_mask = 1  # Ground layer
	add_child(_raycast)
	_raycast.enabled = true

func get_current_surface() -> SurfaceType:
	if _raycast == null or not _raycast.is_colliding():
		return default_surface

	var collider := _raycast.get_collider()
	if collider == null:
		return default_surface

	# Check physics material metadata
	if collider is StaticBody3D or collider is CharacterBody3D:
		var physics_material: PhysicsMaterial = collider.physics_material_override
		if physics_material != null:
			var material_name := physics_material.resource_name.to_lower()
			return _surface_type_from_name(material_name)

	# Check collision layer
	var collision_layer := collider.collision_layer
	if collision_layer & (1 << 10):  # Layer 11 = grass
		return SurfaceType.GRASS
	elif collision_layer & (1 << 11):  # Layer 12 = stone
		return SurfaceType.STONE
	elif collision_layer & (1 << 12):  # Layer 13 = wood
		return SurfaceType.WOOD
	elif collision_layer & (1 << 13):  # Layer 14 = metal
		return SurfaceType.METAL
	elif collision_layer & (1 << 14):  # Layer 15 = water
		return SurfaceType.WATER

	return default_surface

static func _surface_type_from_name(name: String) -> SurfaceType:
	if "grass" in name:
		return SurfaceType.GRASS
	elif "stone" in name or "rock" in name:
		return SurfaceType.STONE
	elif "wood" in name:
		return SurfaceType.WOOD
	elif "metal" in name:
		return SurfaceType.METAL
	elif "water" in name:
		return SurfaceType.WATER
	else:
		return SurfaceType.DEFAULT
```

**FR-033: Surface Type Enum and Detection**
The system SHALL support 6 surface types with detection via:
1. **Collision layer groups** (layers 11-15 for grass/stone/wood/metal/water)
2. **PhysicsMaterial metadata** (resource_name contains surface type)
3. **Node groups** (future fallback method)

**FR-034: S_FootstepSoundSystem**
The system SHALL play footsteps per-tick based on movement (NOT event-driven):

```gdscript
extends BaseECSSystem
class_name S_FootstepSoundSystem

const COMPONENT_TYPES := {
	"MOVEMENT": StringName("C_MovementComponent"),
	"SURFACE": StringName("C_SurfaceDetectorComponent"),
}

@export var settings: RS_FootstepSoundSettings

var _last_step_time: float = 0.0

func process_tick(delta: float) -> void:
	if settings == null or not settings.enabled:
		return

	var state := _store.get_state() if _store != null else {}
	if U_AudioSelectors.is_sfx_muted(state):
		return

	var manager := _get_manager()
	if manager == null:
		return

	var movement_components := manager.get_components(COMPONENT_TYPES.MOVEMENT)
	var surface_components := manager.get_components(COMPONENT_TYPES.SURFACE)

	# Map components by body
	var body_to_movement := {}
	var body_to_surface := {}

	for comp in movement_components:
		var movement := comp as C_MovementComponent
		var body := movement.get_body()
		if body != null:
			body_to_movement[body] = movement

	for comp in surface_components:
		var surface := comp as C_SurfaceDetectorComponent
		var parent := surface.get_parent()
		if parent is CharacterBody3D:
			body_to_surface[parent] = surface

	# Process footsteps
	var now := U_ECS_UTILS.get_current_time()
	for body in body_to_movement:
		var movement: C_MovementComponent = body_to_movement[body]
		var surface: C_SurfaceDetectorComponent = body_to_surface.get(body)

		# Check if moving and on ground
		if body.velocity.length() > 1.0 and body.is_on_floor():
			# Check step interval
			if now - _last_step_time >= settings.step_interval:
				_play_footstep(surface, body.global_position)
				_last_step_time = now

func _play_footstep(surface_detector: C_SurfaceDetectorComponent, position: Vector3) -> void:
	var surface_type := C_SurfaceDetectorComponent.SurfaceType.DEFAULT
	if surface_detector != null:
		surface_type = surface_detector.get_current_surface()

	var sounds := _get_sounds_for_surface(surface_type)
	if sounds.is_empty():
		return

	var audio_stream: AudioStream = sounds[randi() % sounds.size()]

	U_SFXSpawner.spawn_3d({
		"audio_stream": audio_stream,
		"position": position,
		"volume_db": settings.volume_db,
		"pitch_scale": randf_range(1.0 - settings.pitch_variation, 1.0 + settings.pitch_variation),
		"bus": "Footsteps"
	})

func _get_sounds_for_surface(surface_type: int) -> Array[AudioStream]:
	match surface_type:
		C_SurfaceDetectorComponent.SurfaceType.GRASS:
			return settings.grass_sounds
		C_SurfaceDetectorComponent.SurfaceType.STONE:
			return settings.stone_sounds
		C_SurfaceDetectorComponent.SurfaceType.WOOD:
			return settings.wood_sounds
		C_SurfaceDetectorComponent.SurfaceType.METAL:
			return settings.metal_sounds
		C_SurfaceDetectorComponent.SurfaceType.WATER:
			return settings.water_sounds
		_:
			return settings.default_sounds
```

**FR-035: Footstep Settings Resource**
The footstep system SHALL use settings resource with per-surface sound arrays:

```gdscript
class_name RS_FootstepSoundSettings
extends Resource

@export var enabled: bool = true
@export var step_interval: float = 0.4  # Seconds between steps
@export var grass_sounds: Array[AudioStream] = []
@export var stone_sounds: Array[AudioStream] = []
@export var wood_sounds: Array[AudioStream] = []
@export var metal_sounds: Array[AudioStream] = []
@export var water_sounds: Array[AudioStream] = []
@export var default_sounds: Array[AudioStream] = []
@export var volume_db: float = -6.0
@export var pitch_variation: float = 0.15
```

### Phase 6: Ambient System (FR-035 to FR-037)

**FR-036: S_AmbientSoundSystem**
The system SHALL manage per-scene ambient loops with crossfading:

```gdscript
extends BaseECSSystem
class_name S_AmbientSoundSystem

@export var settings: RS_AmbientSoundSettings

var _ambient_player_a: AudioStreamPlayer
var _ambient_player_b: AudioStreamPlayer
var _active_ambient_player: AudioStreamPlayer
var _inactive_ambient_player: AudioStreamPlayer
var _current_ambient_id: StringName = StringName("")
var _ambient_tween: Tween

var _ambient_registry: Dictionary = {
	StringName("exterior_ambience"): {
		"stream": preload("res://assets/audio/ambient/exterior_ambience.ogg"),
		"scene": StringName("gameplay_exterior")
	},
	StringName("interior_ambience"): {
		"stream": preload("res://assets/audio/ambient/interior_ambience.ogg"),
		"scene": StringName("gameplay_interior_house")
	}
}

func _ready() -> void:
	super._ready()
	_initialize_ambient_players()

	if _store != null:
		_store.action_dispatched.connect(_on_action_dispatched)

func _initialize_ambient_players() -> void:
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.bus = "Ambient"
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.bus = "Ambient"
	add_child(_ambient_player_b)

	_active_ambient_player = _ambient_player_a
	_inactive_ambient_player = _ambient_player_b

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))

	if action_type == StringName("scene/transition_completed"):
		var payload: Dictionary = action.get("payload", {})
		var scene_id: StringName = payload.get("scene_id", StringName(""))
		_change_ambient_for_scene(scene_id)

func _change_ambient_for_scene(scene_id: StringName) -> void:
	for ambient_id in _ambient_registry:
		var entry: Dictionary = _ambient_registry[ambient_id]
		if entry.get("scene", StringName("")) == scene_id:
			_play_ambient(ambient_id, 2.0)  # 2.0s crossfade
			return

func _play_ambient(ambient_id: StringName, crossfade_duration: float) -> void:
	if ambient_id == _current_ambient_id:
		return

	var entry: Dictionary = _ambient_registry.get(ambient_id, {})
	var audio_stream: AudioStream = entry.get("stream", null)
	if audio_stream == null:
		return

	# Crossfade logic (same as music system)
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()

	var old_player := _active_ambient_player
	var new_player := _inactive_ambient_player
	_active_ambient_player = new_player
	_inactive_ambient_player = old_player

	new_player.stream = audio_stream
	new_player.volume_db = -80.0
	new_player.play()

	_ambient_tween = create_tween()
	_ambient_tween.set_parallel(true)
	_ambient_tween.set_trans(Tween.TRANS_CUBIC)
	_ambient_tween.set_ease(Tween.EASE_IN_OUT)

	if old_player.playing:
		_ambient_tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)
		_ambient_tween.chain().tween_callback(old_player.stop)

	_ambient_tween.tween_property(new_player, "volume_db", 0.0, crossfade_duration)

	_current_ambient_id = ambient_id

func process_tick(_delta: float) -> void:
	# Ambient system is event-driven (scene transitions), not per-tick
	pass
```

**FR-037: Ambient Track Registry**
The system SHALL maintain registry mapping scene IDs to ambient AudioStream resources.

**FR-038: Ambient Crossfade on Scene Transition**
The system SHALL subscribe to `scene/transition_completed` and crossfade ambient over 2.0 seconds.

### Phase 7: UI Sound Integration (FR-038 to FR-039)

**FR-039: U_UISoundPlayer Utility**
The system SHALL implement utility class for UI sound playback:

```gdscript
class_name U_UISoundPlayer
extends RefCounted

const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

static func play_focus() -> void:
	_play(StringName("ui_focus"))

static func play_confirm() -> void:
	_play(StringName("ui_confirm"))

static func play_cancel() -> void:
	_play(StringName("ui_cancel"))

static func play_slider_tick() -> void:
	# Throttled to max 10 ticks / second
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_tick_time_ms < 100:
		return
	if _play(StringName("ui_tick")):
		_last_tick_time_ms = now_ms

static var _last_tick_time_ms: int = 0

static func _play(sound_id: StringName) -> bool:
	var audio_manager := _get_audio_manager()
	if audio_manager == null:
		return false
	if not audio_manager.has_method("play_ui_sound"):
		return false
	audio_manager.call("play_ui_sound", sound_id)
	return true

static func _get_audio_manager() -> Node:
	return U_ServiceLocator.try_get_service(StringName("audio_manager"))
```

**FR-040: UI Sound Integration Points**
The system SHALL integrate UI sounds into existing UI architecture:

**BasePanel focus sounds**:
```gdscript
# In scripts/ui/base/base_panel.gd
# BasePanel plays focus sound on `Viewport.gui_focus_changed` for focus changes
# within its subtree, and only when "armed" by real navigation input (initial
# focus is silent).
```

**Button press sounds**:
```gdscript
# In button handlers (various UI scripts)

func _on_button_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	# ... existing logic ...

func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	# ... existing logic ...
```

**Slider sounds (throttled)**:
```gdscript
# In settings sliders

func _on_slider_value_changed(value: float) -> void:
	U_UISoundPlayer.play_slider_tick()

	# ... existing slider logic ...
```

### Phase 8: Settings UI Integration (FR-040)

**FR-041: Audio Settings Panel**
The settings UI SHALL integrate audio controls:

```gdscript
# Audio Settings Tab UI Structure:
#
# VBoxContainer
#   ├── Label ("AUDIO SETTINGS")
#   ├── HBoxContainer (Master Volume)
#   │   ├── Label ("Master Volume")
#   │   ├── HSlider (0.0-1.0, step 0.05)
#   │   ├── Label (percentage)
#   │   └── CheckBox (mute)
#   ├── HBoxContainer (Music Volume)
#   │   └── ... (same structure)
#   ├── HBoxContainer (SFX Volume)
#   │   └── ... (same structure)
#   ├── HBoxContainer (Ambient Volume)
#   │   └── ... (same structure)
#   └── CheckBox (Spatial Audio)

# Apply/Cancel pattern implementation:

func _on_master_volume_slider_changed(value: float) -> void:
	_update_volume_label(_master_volume_label, value)
	_has_local_edits = true
	_preview_audio_settings()

func _on_master_mute_toggled(button_pressed: bool) -> void:
	_has_local_edits = true
	_preview_audio_settings()

# Similar for music, sfx, ambient...

func _on_spatial_audio_toggled(button_pressed: bool) -> void:
	_has_local_edits = true
	_preview_audio_settings()

func _preview_audio_settings() -> void:
	# Preview changes immediately (no dispatch) so users can hear the effect while editing.
	# Apply persists by dispatching; Cancel clears preview without dispatching.
	var audio_mgr := U_ServiceLocator.try_get_service(StringName("audio_manager")) as M_AudioManager
	if audio_mgr == null:
		return
	audio_mgr.set_audio_settings_preview({
		"master_volume": _master_volume_slider.value,
		"music_volume": _music_volume_slider.value,
		"sfx_volume": _sfx_volume_slider.value,
		"ambient_volume": _ambient_volume_slider.value,
		"master_muted": _master_mute_toggle.button_pressed,
		"music_muted": _music_mute_toggle.button_pressed,
		"sfx_muted": _sfx_mute_toggle.button_pressed,
		"ambient_muted": _ambient_mute_toggle.button_pressed,
		"spatial_audio_enabled": _spatial_audio_toggle.button_pressed,
	})

func _on_apply_pressed() -> void:
	# Dispatch all 9 fields, then close overlay.
	_store.dispatch(U_AudioActions.set_master_volume(_master_volume_slider.value))
	_store.dispatch(U_AudioActions.set_music_volume(_music_volume_slider.value))
	_store.dispatch(U_AudioActions.set_sfx_volume(_sfx_volume_slider.value))
	_store.dispatch(U_AudioActions.set_ambient_volume(_ambient_volume_slider.value))
	_store.dispatch(U_AudioActions.set_master_muted(_master_mute_toggle.button_pressed))
	_store.dispatch(U_AudioActions.set_music_muted(_music_mute_toggle.button_pressed))
	_store.dispatch(U_AudioActions.set_sfx_muted(_sfx_mute_toggle.button_pressed))
	_store.dispatch(U_AudioActions.set_ambient_muted(_ambient_mute_toggle.button_pressed))
	_store.dispatch(U_AudioActions.set_spatial_audio_enabled(_spatial_audio_toggle.button_pressed))
	var audio_mgr := U_ServiceLocator.try_get_service(StringName("audio_manager")) as M_AudioManager
	if audio_mgr != null:
		audio_mgr.clear_audio_settings_preview()

func _on_cancel_pressed() -> void:
	# Close overlay without dispatching changes.
	var audio_mgr := U_ServiceLocator.try_get_service(StringName("audio_manager")) as M_AudioManager
	if audio_mgr != null:
		audio_mgr.clear_audio_settings_preview()
	pass

func _on_reset_pressed() -> void:
	# Reset UI controls to defaults and dispatch defaults immediately.
	pass

func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(value * 100.0)
```

## Audio Asset Specifications

### Music Tracks

**Format (current placeholders)**: `.mp3`, stereo (imported by Godot)

| Asset Path | Description |
|------------|-------------|
| `resources/audio/music/main_menu.mp3` | Menu music track |
| `resources/audio/music/exterior.mp3` | Exterior gameplay music track |
| `resources/audio/music/interior.mp3` | Interior gameplay music track |
| `resources/audio/music/pause.mp3` | Pause overlay music track |
| `resources/audio/music/credits.mp3` | Credits music track |

**Note**: Early silent-loop OGG placeholders live under `resources/audio/music/placeholders/`.

### Sound Effects (SFX)

**Format**: `.wav` (PCM 16-bit), mono, 44.1kHz sample rate, one-shot

| Asset Path | Description |
|------------|-------------|
| `resources/audio/sfx/placeholder_jump.wav` | Placeholder jump sound |
| `resources/audio/sfx/placeholder_land.wav` | Placeholder landing sound |
| `resources/audio/sfx/placeholder_death.wav` | Placeholder death sound |
| `resources/audio/sfx/placeholder_checkpoint.wav` | Placeholder checkpoint sound |
| `resources/audio/sfx/placeholder_victory.wav` | Placeholder victory sound |

### UI Sounds

**Format**: `.wav` (PCM 16-bit), mono, 44.1kHz, very short (<0.2s)

| Asset Path | Description |
|------------|-------------|
| `resources/audio/sfx/placeholder_ui_focus.wav` | Focus change |
| `resources/audio/sfx/placeholder_ui_confirm.wav` | Confirm |
| `resources/audio/sfx/placeholder_ui_cancel.wav` | Cancel |
| `resources/audio/sfx/placeholder_ui_tick.wav` | Slider tick (throttled) |

### Footstep Sounds

**Format**: `.wav` (PCM 16-bit), mono, 44.1kHz, arrays of 4 variations per surface

| Asset Paths | Description |
|-------------|-------------|
| `resources/audio/footsteps/placeholder_grass_01.wav` through `_04.wav` | Placeholder grass footsteps |
| `resources/audio/footsteps/placeholder_stone_01.wav` through `_04.wav` | Placeholder stone footsteps |
| `resources/audio/footsteps/placeholder_wood_01.wav` through `_04.wav` | Placeholder wood footsteps |
| `resources/audio/footsteps/placeholder_metal_01.wav` through `_04.wav` | Placeholder metal footsteps |
| `resources/audio/footsteps/placeholder_water_01.wav` through `_04.wav` | Placeholder water footsteps |
| `resources/audio/footsteps/placeholder_default_01.wav` through `_04.wav` | Placeholder default footsteps |

### Ambient Tracks

**Format (current placeholders)**: `.wav`, looping

| Asset Path | Description |
|------------|-------------|
| `resources/audio/ambient/placeholder_exterior.wav` | Placeholder exterior ambient loop |
| `resources/audio/ambient/placeholder_interior.wav` | Placeholder interior ambient loop |

## Key Entities

### Redux State Shape

```gdscript
{
	"audio": {
		"master_volume": float,       # 0.0-1.0 (default: 1.0)
		"music_volume": float,        # 0.0-1.0 (default: 1.0)
		"sfx_volume": float,          # 0.0-1.0 (default: 1.0)
		"ambient_volume": float,      # 0.0-1.0 (default: 1.0)
		"master_muted": bool,         # default: false
		"music_muted": bool,          # default: false
		"sfx_muted": bool,            # default: false
		"ambient_muted": bool,        # default: false
		"spatial_audio_enabled": bool # default: true
	}
}
```

### Event Payloads

**entity_jumped Event**:
```gdscript
{
	"name": StringName("entity_jumped"),
	"payload": {
		"entity": CharacterBody3D,
		"position": Vector3,
		"velocity": Vector3,
		"jump_force": float,
		"timestamp": float
	}
}
```

**entity_landed Event**:
```gdscript
{
	"name": StringName("entity_landed"),
	"payload": {
		"entity": CharacterBody3D,
		"position": Vector3,
		"velocity": Vector3,
		"vertical_velocity": float,  # Abs fall speed
		"landing_time": float
	}
}
```

**checkpoint_activated Event** (typed):
```gdscript
{
	"name": StringName("checkpoint_activated"),
	"payload": {
		"checkpoint_id": StringName,
		"spawn_point_id": StringName
	}
}
```

### SFXConfig Dictionary

```gdscript
{
	"audio_stream": AudioStream,  # Sound to play
	"position": Vector3,          # 3D position
	"volume_db": float,           # Volume offset
	"pitch_scale": float,         # Pitch multiplier
	"bus": String                 # Audio bus name
}
```

## Implementation Phases

### Phase 0: Redux Foundation (Days 1-2)

**Objective**: Implement audio Redux layer with 9-field state management

**Deliverables**:
1. `scripts/state/resources/rs_audio_initial_state.gd`
2. `scripts/state/actions/u_audio_actions.gd` (12 actions)
3. `scripts/state/reducers/u_audio_reducer.gd`
4. `scripts/state/selectors/u_audio_selectors.gd` (9 selectors)
5. `tests/unit/state/test_audio_reducer.gd` (25 tests)

**Commit 1**: Audio initial state resource
**Commit 2**: Audio actions (12 action creators)
**Commit 3**: Audio reducer with volume clamping
**Commit 4**: Audio selectors (9 functions)
**Commit 5**: Unit tests for reducer (25 tests passing)

**Dependencies**: None

**Success Criteria**: All reducer tests pass, volume clamping works (0.0-1.0), immutability verified

---

### Phase 1: Core Manager (Days 3-5)

**Objective**: Implement M_AudioManager with audio bus management

**Deliverables**:
1. `scripts/managers/m_audio_manager.gd`
2. Update `scenes/root.tscn` - Add M_AudioManager
3. Update `scripts/root.gd` - ServiceLocator registration (Root bootstrap)
4. `tests/unit/managers/test_audio_manager.gd` (30 tests)

**Commit 1**: Manager scaffolding + bus layout creation
**Commit 2**: Redux subscription + volume application (linear to dB)
**Commit 3**: SFX pool initialization + spatial toggle wiring
**Commit 4**: UI sound playback (`play_ui_sound`) + `U_UISoundPlayer` utility
**Commit 5**: Unit tests (see current suite totals)

**Dependencies**: Phase 0, M_StateStore, U_ServiceLocator

**Success Criteria**: Audio buses created, volume/mute apply correctly, manager discoverable

---

### Phase 2: Music System (Days 6-8)

**Objective**: Implement dual-player music with crossfading

**Deliverables**:
1. Music track registry in M_AudioManager
2. Dual AudioStreamPlayer setup
3. Crossfade algorithm with Tween
4. Scene transition subscription
5. `tests/unit/managers/test_audio_music.gd` (20 tests)
6. `tests/integration/audio/test_music_crossfade.gd` (10 tests)

**Commit 1**: Dual music players + track registry
**Commit 2**: Crossfade algorithm implementation
**Commit 3**: Scene transition subscription
**Commit 4**: Unit + integration tests (30 tests passing)

**Dependencies**: Phase 1

**Success Criteria**: Music crossfades smoothly, no pops/clicks, scene transitions work

---

### Phase 3: BaseEventSFXSystem Pattern (Days 9-10)

**Objective**: Implement base class for event-driven SFX systems

**Deliverables**:
1. `scripts/ecs/base_event_sfx_system.gd`
2. `tests/unit/ecs/test_base_event_sfx_system.gd` (15 tests)

**Commit 1**: BaseEventSFXSystem base class (mirrors BaseEventVFXSystem)
**Commit 2**: Event subscription/unsubscription lifecycle
**Commit 3**: Request queue management
**Commit 4**: Unit tests (15 tests passing)

**Dependencies**: Phase 1, U_ECSEventBus

**Success Criteria**: Base class subscribes to events, queues requests, clears after process_tick()

---

### Phase 4: SFX Systems (Days 11-14)

**Objective**: Implement 5 SFX systems + spawner utility

**Deliverables**:
1. `scripts/managers/helpers/u_sfx_spawner.gd`
2. `scripts/ecs/systems/s_jump_sound_system.gd` + settings resource
3. `scripts/ecs/systems/s_landing_sound_system.gd` + settings resource
4. `scripts/ecs/systems/s_death_sound_system.gd` + settings resource
5. `scripts/ecs/systems/s_checkpoint_sound_system.gd` + settings resource
6. `scripts/ecs/systems/s_victory_sound_system.gd` + settings resource
7. `tests/unit/ecs/systems/test_*_sound_system.gd` (49 tests total)

**Commit 1**: U_SFXSpawner utility (pooled players)
**Commit 2**: S_JumpSoundSystem + tests
**Commit 3**: S_LandingSoundSystem + tests
**Commit 4**: S_DeathSoundSystem + S_CheckpointSoundSystem + tests
**Commit 5**: S_VictorySoundSystem + tests

**Dependencies**: Phase 3

**Success Criteria**: All gameplay events trigger SFX, pool management works, settings apply

---

### Phase 5: Footstep System (Days 15-17)

**Objective**: Implement surface-aware footsteps

**Deliverables**:
1. `scripts/ecs/components/c_surface_detector_component.gd`
2. `scripts/ecs/systems/s_footstep_sound_system.gd`
3. `scripts/ecs/resources/rs_footstep_sound_settings.gd`
4. `tests/unit/ecs/systems/test_footstep_sound_system.gd` (20 tests)

**Commit 1**: C_SurfaceDetectorComponent with raycast
**Commit 2**: Surface detection (collision layers + physics materials)
**Commit 3**: S_FootstepSoundSystem implementation
**Commit 4**: Per-surface sound arrays + tests

**Dependencies**: Phase 4

**Success Criteria**: Footsteps play at correct intervals, surface detection works, sounds differ per surface

---

### Phase 6: Ambient System (Days 18-19)

**Objective**: Implement per-scene ambient loops

**Deliverables**:
1. `scripts/ecs/systems/s_ambient_sound_system.gd`
2. Ambient track registry
3. `tests/unit/ecs/systems/test_ambient_sound_system.gd` (10 tests)

**Commit 1**: S_AmbientSoundSystem + track registry
**Commit 2**: Scene transition subscription + crossfade
**Commit 3**: Unit tests (10 tests passing)

**Dependencies**: Phase 1 (parallels music system)

**Success Criteria**: Ambient loops play per scene, crossfades on transitions, mute toggle works

---

### Phase 7: UI Sound Integration (Days 20-21)

**Objective**: Integrate UI sounds into existing UI architecture

**Deliverables**:
1. `scripts/managers/helpers/u_ui_sound_player.gd`
2. BasePanel focus sound integration
3. Button handler sound integration
4. Tab switch + slider sound integration (throttled)
5. `tests/integration/audio/test_ui_sounds.gd` (15 tests)

**Commit 1**: U_UISoundPlayer utility
**Commit 2**: BasePanel focus sounds
**Commit 3**: Button + tab + slider sounds
**Commit 4**: Integration tests (15 tests passing)

**Dependencies**: Phase 4, existing UI architecture

**Success Criteria**: UI sounds play on focus/press/tab/slider, throttling prevents spam

---

### Phase 8: Settings UI Integration (Days 22-23)

**Objective**: Add audio settings tab to game settings

**Deliverables**:
1. Audio settings tab UI
2. 4 volume sliders + 4 mute toggles + spatial audio toggle
3. Apply/Cancel/Reset pattern (dispatch on Apply; Reset applies immediately)
4. `tests/integration/audio/test_audio_settings_ui.gd` (10 tests)

**Commit 1**: Audio settings tab UI layout
**Commit 2**: Volume slider + mute toggle wiring
**Commit 3**: Apply/Cancel pattern implementation
**Commit 4**: Integration tests (10 tests passing)

**Dependencies**: All previous phases

**Success Criteria**: Apply updates Redux state (and audio) immediately, Cancel discards edits, persistence works

## Success Criteria

(Documenting first 10 of 35 total for brevity - full PRD would include all 35)

**SC-001: Redux Immutability**
Audio reducer SHALL NOT mutate state. Verify: `old_state is not new_state` after action dispatch.

**SC-002: Volume Clamping**
Volume values SHALL clamp to 0.0-1.0 range:
- Input: -0.5 → Output: 0.0
- Input: 1.5 → Output: 1.0
- Input: 0.7 → Output: 0.7

**SC-003: Mute Independence**
Mute toggles SHALL be independent of volume values. Verify:
- Mute at volume=0.8, unmute → volume returns to 0.8
- Volume changes while muted → volume stored, applied on unmute

**SC-004: Audio Bus Hierarchy**
Audio buses SHALL create correctly:
- Master → Music/SFX/Ambient
- SFX → UI/Footsteps

**SC-005: Volume dB Conversion**
Linear volume SHALL convert to logarithmic dB:
- 0.0 → -80dB (silent)
- 0.5 → -6dB (half perceived)
- 1.0 → 0dB (full)

**SC-006: Music Crossfade Smoothness**
Music crossfade SHALL have no pops/clicks/volume spikes:
- Measure peak amplitude during crossfade
- Verify smooth Tween curve (TRANS_CUBIC, EASE_IN_OUT)

**SC-007: Same Track No-Op**
Calling `play_music()` with same track SHALL not restart music:
- Track "A" playing → `play_music("A")` → continues without interruption

**SC-008: SFX Pool Management**
SFX pool SHALL manage 16 concurrent sounds:
- Play 16 sounds → all play
- Play 17th sound → skips (pool exhausted)
- Sound finishes → player returns to pool

**SC-009: Footstep Interval**
Footsteps SHALL play at a realistic cadence (0.5s at reference_speed 6.0 by default) and scale with movement speed:
- Player moving (default walk) → footstep every ~0.5s
- Player stops → footsteps cease

**SC-010: Surface Detection**
Surface detector SHALL identify all 6 surface types correctly:
- Collision layer tests (layers 11-15)
- PhysicsMaterial metadata tests
- Fallback to default

## Testing Strategy

(Note: Full PRD includes ~280 tests across 32 test files. Documenting representative samples)

### Unit Tests: Redux Layer (25 tests)

```gdscript
# test_audio_reducer.gd

func test_set_master_volume_valid():
	Given: Initial state
	When: Dispatch set_master_volume(0.7)
	Then: New state has master_volume = 0.7

func test_set_master_volume_clamp_lower():
	Given: Initial state
	When: Dispatch set_master_volume(-0.3)
	Then: New state has master_volume = 0.0

func test_set_master_volume_clamp_upper():
	Given: Initial state
	When: Dispatch set_master_volume(1.8)
	Then: New state has master_volume = 1.0

# ... (22 more tests for all actions)
```

### Unit Tests: Manager (20 tests)

```gdscript
# test_audio_manager.gd

func test_manager_creates_audio_bus_layout():
	Given: M_AudioManager instance
	When: _ready() called
	Then: Buses exist: Master, Music, SFX, UI, Footsteps, Ambient

func test_manager_applies_volume_to_master_bus():
	Given: Manager with Redux master_volume = 0.5
	When: Slice updated signal received
	Then: AudioServer.get_bus_volume_db("Master") ≈ -6.0dB

	func test_spatial_audio_setting_updates_sfx_spawner():
		Given: Manager initialized and subscribed to store
		When: Dispatch U_AudioActions.set_spatial_audio_enabled(false)
		Then: U_SFXSpawner.is_spatial_audio_enabled() == false

	# ... (remaining tests)
```

### Integration Tests: Full Audio System (30 tests)

```gdscript
# test_audio_integration.gd

func test_scene_transition_changes_music_and_ambient():
	Given: Gameplay exterior scene
	When: Transition to interior scene
	Then: Music crossfades to interior track AND ambient crossfades

func test_damage_event_triggers_sound():
	Given: Full scene with audio manager
	When: Dispatch take_damage action
	Then: Damage sound plays at player position

# ... (28 more integration tests)
```

## Deployment Strategy

### Feature Flags

**Audio Feature Flag** (`is_audio_enabled`):
- Default: `true` (audio enabled)
- Environment variable: `AUDIO_ENABLED=false` to disable
- Debug toggle: F4 menu "Disable Audio"

**Gradual Rollout**:
- Week 1: Music only (SFX disabled)
- Week 2: Music + gameplay SFX (UI sounds disabled)
- Week 3: Full audio (music + SFX + UI + ambient + footsteps)

### Rollback Steps

1. **Immediate Rollback**: Set `AUDIO_ENABLED=false` via env var
2. **Partial Rollback**: Disable specific features via settings defaults
3. **Full Rollback**: Revert Phase 8 → Phase 0 commits

### Backward Compatibility

**Save File Compatibility**:
- Pre-audio saves: Load with default audio settings
- Post-audio saves: Audio settings persist

**Redux State Migration**:
```gdscript
if not loaded_state.has("audio"):
	loaded_state["audio"] = RS_AudioInitialState.new().to_dictionary()
```

## File Structure

```
scripts/managers/
  m_audio_manager.gd
scripts/managers/helpers/
  u_audio_player_pool.gd
  u_sfx_spawner.gd
  u_ui_sound_player.gd
scripts/ecs/
  base_event_sfx_system.gd
scripts/ecs/systems/
  s_jump_sound_system.gd
  s_landing_sound_system.gd
  s_death_sound_system.gd
  s_checkpoint_sound_system.gd
  s_victory_sound_system.gd
  s_footstep_sound_system.gd
  s_ambient_sound_system.gd
scripts/ecs/components/
  c_surface_detector_component.gd
scripts/ecs/resources/
  rs_jump_sound_settings.gd
  rs_landing_sound_settings.gd
  rs_death_sound_settings.gd
  rs_checkpoint_sound_settings.gd
  rs_victory_sound_settings.gd
  rs_footstep_sound_settings.gd
  rs_ambient_sound_settings.gd
scripts/state/resources/
  rs_audio_initial_state.gd
scripts/state/actions/
  u_audio_actions.gd
scripts/state/reducers/
  u_audio_reducer.gd
scripts/state/selectors/
  u_audio_selectors.gd
resources/audio/
  music/
    main_menu.mp3
    exterior.mp3
    interior.mp3
    pause.mp3
    credits.mp3
    placeholders/
      placeholder_main_menu.ogg
      placeholder_gameplay.ogg
      placeholder_pause.ogg
  sfx/
    placeholder_jump.wav
    placeholder_land.wav
    placeholder_death.wav
    placeholder_checkpoint.wav
    placeholder_victory.wav
    placeholder_ui_focus.wav
    placeholder_ui_confirm.wav
    placeholder_ui_cancel.wav
    placeholder_ui_tick.wav
  ambient/
    placeholder_exterior.wav
    placeholder_interior.wav
  footsteps/
    placeholder_grass_01.wav through _04.wav
    placeholder_stone_01.wav through _04.wav
    placeholder_wood_01.wav through _04.wav
    placeholder_metal_01.wav through _04.wav
    placeholder_water_01.wav through _04.wav
    placeholder_default_01.wav through _04.wav
resources/base_settings/
  jump_sound_default.tres
  landing_sound_default.tres
  death_sound_default.tres
  checkpoint_sound_default.tres
  victory_sound_default.tres
  footstep_sound_default.tres
  ambient_sound_default.tres
tests/unit/state/
  test_audio_reducer.gd
tests/unit/managers/
  test_audio_manager.gd
tests/unit/managers/helpers/
  test_sfx_spawner.gd
  test_ui_sound_player.gd
tests/unit/ecs/
  test_base_event_sfx_system.gd
tests/unit/ecs/systems/
  test_jump_sound_system.gd
  test_landing_sound_system.gd
  test_death_sound_system.gd
  test_checkpoint_sound_system.gd
  test_victory_sound_system.gd
  test_footstep_sound_system.gd
  test_ambient_sound_system.gd
tests/integration/audio/
  test_audio_integration.gd
  test_music_crossfade.gd
  test_ui_sounds.gd
  test_audio_settings_ui.gd
```

## Dependencies & Integration Points

### Existing Code Modifications

**1. M_StateStore** (`scripts/state/m_state_store.gd`):
- **Add Reducer Preload** (after line 27):
  ```gdscript
  const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")
  ```
- **Add Export Variable** (after line 56):
  ```gdscript
  @export var audio_initial_state: RS_AudioInitialState
  ```
- **Update `_initialize_slices()` call** (line 164):
  ```gdscript
  U_STATE_SLICE_MANAGER.initialize_slices(
      _slice_configs,
      _state,
      boot_initial_state,
      menu_initial_state,
      navigation_initial_state,
      settings_initial_state,
      gameplay_initial_state,
      scene_initial_state,
      debug_initial_state,
      vfx_initial_state,  # If VFX Manager implemented first
      audio_initial_state  # ADD THIS
  )
  ```

**2. scenes/root.tscn**:
- Add `M_AudioManager` node under `Managers` group
- Position after M_StateStore in tree

**3. scripts/root.gd**:
- Add ServiceLocator registration:
  ```gdscript
  var audio_manager := get_node("Managers/M_AudioManager") as M_AudioManager
  U_ServiceLocator.register(StringName("audio_manager"), audio_manager)
  ```

**4. scripts/ui/base_panel.gd** (UI Sound Integration):
- Connect `focus_entered` signal to UI sound player:
  BasePanel focus sound is input-gated and driven by `Viewport.gui_focus_changed` (initial/programmatic focus changes are silent).

**5. Button/UI Controls** (various locations):
- Add confirm/cancel sounds to button handlers
- Add slider sounds (throttled) to volume sliders

### Integration Order

1. **Phase 0** (Redux): Independent, no dependencies
2. **Phase 1** (Manager Core): Depends on M_StateStore, U_ServiceLocator
3. **Phase 2** (Music System): Depends on Phase 1
4. **Phase 3** (BaseEventSFXSystem): Depends on Phase 1, U_ECSEventBus
5. **Phase 4** (SFX Systems): Depends on Phase 3
6. **Phase 5** (Footstep System): Depends on Phase 4
7. **Phase 6** (Ambient System): Depends on Phase 1
8. **Phase 7** (UI Sounds): Depends on Phase 1, existing UI architecture
9. **Phase 8** (Settings UI): Depends on all previous phases
10. **Phase 9** (Integration Testing): Depends on Phase 0–8
11. **Phase 10** (Manual QA): Depends on Phase 0–9

### External Dependencies

- **M_StateStore**: Redux store for audio slice
- **U_ECSEventBus**: Event subscription for gameplay/scene events
- **U_ServiceLocator**: Manager discovery
- **U_StateUtils**: Store lookup utility
- **M_SceneManager**: Scene transition events for music/ambient crossfading
- **AudioListener3D**: Ensure a 3D listener exists for spatial audio to behave as expected

---

**End of Audio Manager PRD**
**Review Status**: Phases 0–9 implemented; Phase 10 pending
**Next Steps**: Start Phase 10 manual QA (see `docs/audio_manager/audio-manager-tasks.md`)
