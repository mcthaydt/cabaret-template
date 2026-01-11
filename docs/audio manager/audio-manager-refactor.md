# Audio Manager Refactoring Plan

## Overview

This plan addresses issues identified in the Audio Manager system, organized into 10 incremental phases. The refactoring improves architecture, correctness, scalability, code health, and testing while maintaining backward compatibility.

## Current State Analysis

### Verified Issues

1. **Hard-coded registries** - `_MUSIC_REGISTRY` (5 tracks), `_UI_SOUND_REGISTRY` (4 sounds), `_AMBIENT_REGISTRY` (2 ambients) don't scale
2. **Crossfade duplication** - ~40 lines of identical dual-player crossfade logic in both M_AudioManager and S_AmbientSoundSystem
3. **Ambient tied to gameplay scene** - S_AmbientSoundSystem exists per-scene, cross-scene crossfades unreliable
4. **Destructive bus creation** - `_create_bus_layout()` clears all buses > 1 (line 104)
5. **No I_AudioManager interface** - UI uses `has_method()`/`call()` dynamic patterns
6. **ECS system duplication** - ~40-50 lines duplicated across 5 event-driven sound systems
7. **Inconsistent pause gating** - Only footsteps check pause; jump/land/death/checkpoint/victory don't
8. **Slow scene-tree searches** - Death/checkpoint systems call `find_child()` per request per frame
9. **Per-entity timer leak** - Footstep `_entity_timers` never cleaned for freed entities
10. **Fixed SFX pool** - 16 players, drops audio on exhaustion with no recovery strategy
11. **Inefficient state subscription** - Reapplies ALL audio settings on every state change
12. **Preview bypasses Redux** - Direct bus manipulation instead of state-driven

### Key Files

- `scripts/managers/m_audio_manager.gd` (~400 lines)
- `scripts/managers/helpers/m_sfx_spawner.gd` (~133 lines)
- `scripts/ecs/systems/s_ambient_sound_system.gd` (~130 lines)
- `scripts/ecs/systems/s_footstep_sound_system.gd` (~150 lines)
- `scripts/ecs/systems/s_jump_sound_system.gd`, `s_landing_sound_system.gd`, `s_death_sound_system.gd`, `s_checkpoint_sound_system.gd`, `s_victory_sound_system.gd`
- `scripts/ui/utils/u_ui_sound_player.gd` (~60 lines)
- `scripts/ui/settings/ui_audio_settings_tab.gd` (~500 lines)

---

## Phase 1: Registry & Data Architecture

**Goal**: Replace hard-coded registries with resource-driven definitions and loader pattern (same as U_SceneRegistryLoader).

### New Resource: `scripts/ecs/resources/rs_music_track_definition.gd`

```gdscript
extends Resource
class_name RS_MusicTrackDefinition

@export var track_id: StringName = &""
@export var stream: AudioStream = null
@export var default_fade_duration: float = 1.5
@export var base_volume_offset_db: float = 0.0
@export var loop: bool = true
@export var pause_behavior: StringName = &"pause"  # "pause", "duck", "continue"
```

### New Resource: `scripts/ecs/resources/rs_ambient_track_definition.gd`

```gdscript
extends Resource
class_name RS_AmbientTrackDefinition

@export var ambient_id: StringName = &""
@export var stream: AudioStream = null
@export var default_fade_duration: float = 2.0
@export var base_volume_offset_db: float = 0.0
@export var loop: bool = true
```

### New Resource: `scripts/ecs/resources/rs_ui_sound_definition.gd`

```gdscript
extends Resource
class_name RS_UISoundDefinition

@export var sound_id: StringName = &""
@export var stream: AudioStream = null
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.0
@export var throttle_ms: int = 0  # Per-sound throttle (0 = no throttle)
```

### New Resource: `scripts/ecs/resources/rs_scene_audio_mapping.gd`

```gdscript
extends Resource
class_name RS_SceneAudioMapping

## Maps scene_id to audio track IDs (O(1) lookup instead of O(n) scene lists)
@export var scene_id: StringName = &""
@export var music_track_id: StringName = &""
@export var ambient_track_id: StringName = &""
```

### New Loader: `scripts/managers/helpers/u_audio_registry_loader.gd`

```gdscript
class_name U_AudioRegistryLoader
extends RefCounted

static var _music_tracks: Dictionary = {}  # track_id -> RS_MusicTrackDefinition
static var _ambient_tracks: Dictionary = {}  # ambient_id -> RS_AmbientTrackDefinition
static var _ui_sounds: Dictionary = {}  # sound_id -> RS_UISoundDefinition
static var _scene_audio_map: Dictionary = {}  # scene_id -> RS_SceneAudioMapping

static func initialize() -> void:
    _register_music_tracks()
    _register_ambient_tracks()
    _register_ui_sounds()
    _register_scene_audio_mappings()
    _validate_registrations()

static func get_music_track(track_id: StringName) -> RS_MusicTrackDefinition
static func get_ambient_track(ambient_id: StringName) -> RS_AmbientTrackDefinition
static func get_ui_sound(sound_id: StringName) -> RS_UISoundDefinition
static func get_audio_for_scene(scene_id: StringName) -> RS_SceneAudioMapping
static func _validate_registrations() -> void  # Warn on duplicates, missing streams
```

### Default Resource Files

- `resources/audio/tracks/music_main_menu.tres`
- `resources/audio/tracks/music_exterior.tres`
- `resources/audio/tracks/music_interior.tres`
- `resources/audio/tracks/music_pause.tres`
- `resources/audio/tracks/music_credits.tres`
- `resources/audio/ambient/ambient_exterior.tres`
- `resources/audio/ambient/ambient_interior.tres`
- `resources/audio/ui/ui_focus.tres`
- `resources/audio/ui/ui_confirm.tres`
- `resources/audio/ui/ui_cancel.tres`
- `resources/audio/ui/ui_tick.tres`
- `resources/audio/scene_mappings/scene_audio_*.tres`

### Mix Snapshots / Pause Behavior

The `pause_behavior` field in RS_MusicTrackDefinition enables per-track behavior during pause:

| Value | Behavior |
|-------|----------|
| `&"pause"` | Stop playback, resume from same position when unpaused |
| `&"duck"` | Reduce volume (e.g., -12dB) during pause, restore on unpause |
| `&"continue"` | Continue playing at full volume during pause |

Implementation in M_AudioManager:
```gdscript
const DUCK_VOLUME_DB := -12.0
const DUCK_FADE_DURATION := 0.3

func _on_pause_state_changed(is_paused: bool) -> void:
    var track_def := U_AudioRegistryLoader.get_music_track(_music_crossfader.get_current_track_id())
    if track_def == null:
        return

    match track_def.pause_behavior:
        &"pause":
            if is_paused:
                _music_crossfader.pause()
            else:
                _music_crossfader.resume()
        &"duck":
            if is_paused:
                _duck_music(DUCK_VOLUME_DB, DUCK_FADE_DURATION)
            else:
                _unduck_music(DUCK_FADE_DURATION)
        &"continue":
            pass  # No action needed

func _duck_music(target_db: float, duration: float) -> void:
    var tween := create_tween()
    tween.tween_method(_set_music_duck_offset, 0.0, target_db, duration)

func _unduck_music(duration: float) -> void:
    var tween := create_tween()
    tween.tween_method(_set_music_duck_offset, _current_duck_offset, 0.0, duration)

func _set_music_duck_offset(offset_db: float) -> void:
    _current_duck_offset = offset_db
    _apply_music_volume()
```

---

## Phase 2: Crossfade Helper Extraction

**Goal**: Extract shared dual-player crossfader utility used by both music and ambient.

### New Helper: `scripts/managers/helpers/u_crossfade_player.gd`

```gdscript
class_name U_CrossfadePlayer
extends RefCounted

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_track_id: StringName = &""
var _tween: Tween
var _owner_node: Node  # For create_tween()

func _init(owner: Node, bus: StringName) -> void:
    _owner_node = owner
    _player_a = AudioStreamPlayer.new()
    _player_b = AudioStreamPlayer.new()
    _player_a.bus = bus
    _player_b.bus = bus
    owner.add_child(_player_a)
    owner.add_child(_player_b)
    _active_player = _player_a
    _inactive_player = _player_b

func crossfade_to(stream: AudioStream, track_id: StringName, duration: float, start_position: float = 0.0) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()

    # Swap players
    var old_player := _active_player
    _active_player = _inactive_player
    _inactive_player = old_player

    # Configure new player
    _active_player.stream = stream
    _active_player.volume_db = -80.0
    if start_position > 0.0:
        _active_player.play(start_position)
    else:
        _active_player.play()

    # Create crossfade tween
    _tween = _owner_node.create_tween()
    _tween.set_parallel(true)
    _tween.set_trans(Tween.TRANS_CUBIC)
    _tween.set_ease(Tween.EASE_IN_OUT)

    if old_player.playing:
        _tween.tween_property(old_player, "volume_db", -80.0, duration)
        _tween.chain().tween_callback(old_player.stop)

    _tween.tween_property(_active_player, "volume_db", 0.0, duration)
    _current_track_id = track_id

func stop(duration: float) -> void
func pause() -> void
func resume() -> void
func get_current_track_id() -> StringName
func get_playback_position() -> float
func is_playing() -> bool
func cleanup() -> void  # Called in _exit_tree()
```

### Update M_AudioManager

Replace lines 50-58 and 200-239 with:
```gdscript
var _music_crossfader: U_CrossfadePlayer

func _ready() -> void:
    _music_crossfader = U_CrossfadePlayer.new(self, &"Music")
    # ...

func _crossfade_music(track_id: StringName, duration: float, start_position: float = 0.0) -> void:
    var track_def := U_AudioRegistryLoader.get_music_track(track_id)
    if track_def == null or track_def.stream == null:
        push_warning("Missing music track: %s" % track_id)
        return
    _music_crossfader.crossfade_to(track_def.stream, track_id, duration, start_position)
```

---

## Phase 3: Ambient Migration to Persistent Manager

**Goal**: Move ambient playback into M_AudioManager for reliable cross-scene crossfades.

### Update M_AudioManager

Add ambient crossfader alongside music:
```gdscript
var _ambient_crossfader: U_CrossfadePlayer

func _ready() -> void:
    _music_crossfader = U_CrossfadePlayer.new(self, &"Music")
    _ambient_crossfader = U_CrossfadePlayer.new(self, &"Ambient")
    # ...

func play_ambient(ambient_id: StringName, duration: float = 2.0) -> void:
    var track_def := U_AudioRegistryLoader.get_ambient_track(ambient_id)
    if track_def == null or track_def.stream == null:
        push_warning("Missing ambient track: %s" % ambient_id)
        return
    _ambient_crossfader.crossfade_to(track_def.stream, ambient_id, duration)

func stop_ambient(duration: float = 2.0) -> void:
    _ambient_crossfader.stop(duration)
```

### Update Scene Transition Handler

In `_handle_music_actions()`, also handle ambient:
```gdscript
func _on_state_changed(action: Dictionary, _state: Dictionary) -> void:
    var action_type: StringName = action.get("type", &"")
    if action_type == StringName("scene/transition_completed"):
        var scene_id: StringName = action.get("payload", {}).get("scene_id", &"")
        _change_audio_for_scene(scene_id)

func _change_audio_for_scene(scene_id: StringName) -> void:
    var mapping := U_AudioRegistryLoader.get_audio_for_scene(scene_id)
    if mapping == null:
        return
    if not mapping.music_track_id.is_empty():
        _crossfade_music(mapping.music_track_id)
    if not mapping.ambient_track_id.is_empty():
        play_ambient(mapping.ambient_track_id)
    elif _ambient_crossfader.is_playing():
        stop_ambient()
```

### Remove S_AmbientSoundSystem

Delete `scripts/ecs/systems/s_ambient_sound_system.gd` - functionality now in M_AudioManager.

---

## Phase 4: Bus Layout & Validation

**Goal**: Define buses in project.godot, runtime validates and warns.

### Define Buses in Editor

In Godot editor: Project → Project Settings → Audio → Buses:
```
Master (bus 0)
├── Music (bus 1)
├── SFX (bus 2)
│   ├── UI (bus 3)
│   └── Footsteps (bus 4)
└── Ambient (bus 5)
```

Export as `default_bus_layout.tres` in project root.

### New Constants: `scripts/managers/helpers/u_audio_bus_constants.gd`

```gdscript
class_name U_AudioBusConstants
extends RefCounted

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_FOOTSTEPS := &"Footsteps"
const BUS_AMBIENT := &"Ambient"

const REQUIRED_BUSES: Array[StringName] = [
    BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI, BUS_FOOTSTEPS, BUS_AMBIENT
]

static func validate_bus_layout() -> bool:
    var all_valid := true
    for bus_name in REQUIRED_BUSES:
        var idx := AudioServer.get_bus_index(String(bus_name))
        if idx == -1:
            push_error("Audio bus '%s' not found. Define in project audio bus layout." % bus_name)
            all_valid = false
    return all_valid

static func get_bus_index_safe(bus_name: StringName) -> int:
    var idx := AudioServer.get_bus_index(String(bus_name))
    if idx == -1:
        push_warning("Bus '%s' not found, falling back to Master" % bus_name)
        return 0
    return idx
```

### Update M_AudioManager

Replace `_create_bus_layout()` with validation:
```gdscript
func _ready() -> void:
    # Validate instead of create
    if not U_AudioBusConstants.validate_bus_layout():
        push_error("Audio bus layout invalid. Check Project Settings → Audio → Buses")
    # ...
```

### Update Test Helper

Keep destructive reset only in tests:
```gdscript
# tests/helpers/u_audio_test_helpers.gd
static func reset_audio_buses_for_testing() -> void:
    # Only call in tests - recreates expected bus layout
    while AudioServer.bus_count > 1:
        AudioServer.remove_bus(1)
    # Recreate required buses for test isolation
    for bus_name in U_AudioBusConstants.REQUIRED_BUSES:
        if bus_name == U_AudioBusConstants.BUS_MASTER:
            continue
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, String(bus_name))
```

---

## Phase 5: I_AudioManager Interface

**Goal**: Add contract interface for type-safe access, remove has_method()/call() patterns.

### New Interface: `scripts/interfaces/i_audio_manager.gd`

```gdscript
class_name I_AudioManager
extends Node

## Interface for audio manager. Extend this class and implement all methods.

func play_ui_sound(_sound_id: StringName) -> void:
    push_error("I_AudioManager.play_ui_sound not implemented")

func play_music(_track_id: StringName, _duration: float = 1.5, _start_position: float = 0.0) -> void:
    push_error("I_AudioManager.play_music not implemented")

func stop_music(_duration: float = 1.5) -> void:
    push_error("I_AudioManager.stop_music not implemented")

func play_ambient(_ambient_id: StringName, _duration: float = 2.0) -> void:
    push_error("I_AudioManager.play_ambient not implemented")

func stop_ambient(_duration: float = 2.0) -> void:
    push_error("I_AudioManager.stop_ambient not implemented")

func set_audio_settings_preview(_preview_settings: Dictionary) -> void:
    push_error("I_AudioManager.set_audio_settings_preview not implemented")

func clear_audio_settings_preview() -> void:
    push_error("I_AudioManager.clear_audio_settings_preview not implemented")

func set_spatial_audio_enabled(_enabled: bool) -> void:
    push_error("I_AudioManager.set_spatial_audio_enabled not implemented")
```

### Update M_AudioManager

```gdscript
extends I_AudioManager
class_name M_AudioManager

# Implement all interface methods...
```

### New Helper: `scripts/utils/u_audio_utils.gd`

```gdscript
class_name U_AudioUtils
extends RefCounted

static func get_audio_manager(from_node: Node = null) -> I_AudioManager:
    var manager := U_ServiceLocator.try_get_service(StringName("audio_manager"))
    if manager != null:
        return manager as I_AudioManager
    # Fallback to group lookup
    if from_node != null:
        var managers := from_node.get_tree().get_nodes_in_group("audio_manager")
        if not managers.is_empty():
            return managers[0] as I_AudioManager
    return null
```

### Update U_UISoundPlayer

Remove has_method()/call() pattern:
```gdscript
static func _play(sound_id: StringName) -> bool:
    var audio_mgr := U_AudioUtils.get_audio_manager()
    if audio_mgr == null:
        return false
    audio_mgr.play_ui_sound(sound_id)
    return true
```

### Update UI_AudioSettingsTab

```gdscript
var _audio_manager: I_AudioManager = null

func _ready() -> void:
    _audio_manager = U_AudioUtils.get_audio_manager(self)
    # ...

func _update_preview() -> void:
    if _audio_manager != null:
        _audio_manager.set_audio_settings_preview({...})
```

---

## Phase 6: ECS Sound System Refactor

**Goal**: Extract shared helpers, add consistent pause/transition gating.

### Standardized Request Schema

All ECS sound systems use a consistent request Dictionary format:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `position` | `Vector3` | Yes | World position where sound should play |
| `entity_id` | `StringName` | No | Optional entity reference for debugging |

The `create_request_from_payload()` method in each system transforms event payloads into this schema. Publishers should include `position` in event payloads (resolved at publish time, not lookup time).

### New Base Helper Methods in BaseEventSFXSystem

Add to `scripts/ecs/base_event_sfx_system.gd`:
```gdscript
## Shared settings validation - returns true if should skip processing
func _should_skip_processing() -> bool:
    if settings == null or not settings.enabled:
        requests.clear()
        return true
    if _get_audio_stream() == null:
        requests.clear()
        return true
    return false

## Override in subclass to return the audio stream
func _get_audio_stream() -> AudioStream:
    return null

## Shared gating check for pause and transitions
func _is_audio_blocked() -> bool:
    var store := _get_state_store()
    if store == null:
        return false
    var state: Dictionary = store.get_state()

    # Block during pause
    var gameplay: Dictionary = state.get("gameplay", {})
    if gameplay.get("is_paused", false):
        return true

    # Block during transitions
    var scene: Dictionary = state.get("scene", {})
    if scene.get("is_transitioning", false):
        return true

    # Block if not in gameplay shell
    var nav: Dictionary = state.get("navigation", {})
    if nav.get("shell", &"") != &"gameplay":
        return true

    return false

## Shared interval check - returns true if should skip this request
func _is_throttled(min_interval: float, now: float) -> bool:
    if min_interval > 0.0 and now - _last_play_time < min_interval:
        return true
    return false

## Shared pitch calculation
func _calculate_pitch(pitch_variation: float) -> float:
    var clamped := clampf(pitch_variation, 0.0, 0.95)
    return randf_range(1.0 - clamped, 1.0 + clamped)

## Shared position extraction from request
func _extract_position(request: Dictionary) -> Vector3:
    var pos_variant: Variant = request.get("position", Vector3.ZERO)
    if pos_variant is Vector3:
        return pos_variant
    return Vector3.ZERO

## Shared SFX spawning (matches current spawn_3d Dictionary API)
func _spawn_sfx(stream: AudioStream, position: Vector3, volume_db: float, pitch_scale: float, bus: StringName = &"SFX") -> void:
    M_SFXSpawner.spawn_3d({
        "audio_stream": stream,
        "position": position,
        "volume_db": volume_db,
        "pitch_scale": pitch_scale,
        "bus": String(bus)
    })
```

### Simplified Event Systems

Example refactored `S_JumpSoundSystem`:
```gdscript
extends BaseEventSFXSystem
class_name S_JumpSoundSystem

func get_event_name() -> StringName:
    return &"entity_jumped"

func _get_audio_stream() -> AudioStream:
    return settings.audio_stream if settings != null else null

func create_request_from_payload(payload: Dictionary) -> Dictionary:
    return {
        "position": payload.get("position", Vector3.ZERO)
    }

func process_tick(_delta: float) -> void:
    if _should_skip_processing():
        return
    if _is_audio_blocked():
        requests.clear()
        return

    var stream := _get_audio_stream()
    var min_interval: float = maxf(settings.min_interval, 0.0)
    var now: float = U_ECSUtils.get_current_time()

    for request_variant in requests:
        if _is_throttled(min_interval, now):
            continue
        var request := request_variant as Dictionary
        if request == null:
            continue

        var position := _extract_position(request)
        var pitch := _calculate_pitch(settings.pitch_variation)
        _spawn_sfx(stream, position, settings.volume_db, pitch)
        _last_play_time = now

    requests.clear()
```

### Fix Slow Scene-Tree Searches

For death/checkpoint systems, resolve position at event time:
```gdscript
# In the system that PUBLISHES the event (not the sound system):
func _publish_death_event(entity_id: StringName, entity: Node3D) -> void:
    var position := entity.global_position if entity != null else Vector3.ZERO
    U_ECSEventBus.publish(&"entity_death", {
        "entity_id": entity_id,
        "position": position  # Include position in payload
    })
```

### Fix Per-Entity Timer Cleanup in Footstep System

```gdscript
func _exit_tree() -> void:
    super._exit_tree()
    _entity_timers.clear()

# Also add entity removal callback if manager supports it
func _on_entity_removed(entity: Node) -> void:
    _entity_timers.erase(entity)
```

---

## Phase 7: SFX Spawner Improvements

**Goal**: Voice stealing, per-sound configuration, bus fallback, follow-emitter mode.

**Note**: Current `spawn_3d()` uses Dictionary config API. This phase extends it while preserving the signature.

### Update M_SFXSpawner

```gdscript
const POOL_SIZE := 16
const MAX_POOL_SIZE := 32  # For potential soft growth later

static var _pool: Array[AudioStreamPlayer3D] = []
static var _play_times: Dictionary = {}  # player -> start_time (for voice stealing)
static var _follow_targets: Dictionary = {}  # player -> Node3D (for follow emitter mode)

## Spawn with voice stealing on exhaustion (preserves Dictionary API)
static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
    if config == null or config.is_empty():
        return null

    var audio_stream_variant: Variant = config.get("audio_stream", null)
    var audio_stream: AudioStream = null
    if audio_stream_variant is AudioStream:
        audio_stream = audio_stream_variant as AudioStream
    if audio_stream == null:
        push_warning("M_SFXSpawner: null audio stream")
        return null

    var player := _get_available_player()
    if player == null:
        # Voice stealing: find oldest playing sound
        player = _steal_oldest_voice()
        if player == null:
            push_warning("SFX pool exhausted, could not steal voice")
            _stats["drops"] += 1
            return null

    # Extract config values
    var position: Vector3 = Vector3.ZERO
    var pos_variant: Variant = config.get("position", Vector3.ZERO)
    if pos_variant is Vector3:
        position = pos_variant

    var volume_db: float = float(config.get("volume_db", 0.0))
    var pitch_scale: float = float(config.get("pitch_scale", 1.0))
    if pitch_scale <= 0.0:
        pitch_scale = 1.0

    var bus: String = String(config.get("bus", "SFX"))
    var validated_bus := _validate_bus(bus)

    # Optional per-sound spatialization overrides
    var max_distance: float = float(config.get("max_distance", -1.0))
    var attenuation_model: int = int(config.get("attenuation_model", -1))

    # Optional follow emitter mode
    var follow_target_variant: Variant = config.get("follow_target", null)
    var follow_target: Node3D = null
    if follow_target_variant is Node3D:
        follow_target = follow_target_variant

    player.set_meta(META_IN_USE, true)
    _play_times[player] = Time.get_ticks_msec()
    player.stream = audio_stream
    player.global_position = position
    player.volume_db = volume_db
    player.pitch_scale = pitch_scale
    player.bus = validated_bus
    _configure_player_spatialization(player, max_distance, attenuation_model)

    # Store follow target for _process updates
    if follow_target != null and is_instance_valid(follow_target):
        _follow_targets[player] = follow_target
    else:
        _follow_targets.erase(player)

    player.play()
    _stats["spawns"] += 1
    _update_peak_usage()
    return player

static func _steal_oldest_voice() -> AudioStreamPlayer3D:
    var oldest_player: AudioStreamPlayer3D = null
    var oldest_time: int = Time.get_ticks_msec()

    for player in _pool:
        if not player.get_meta(META_IN_USE, false):
            continue
        var start_time: int = _play_times.get(player, 0)
        if start_time < oldest_time:
            oldest_time = start_time
            oldest_player = player

    if oldest_player != null:
        oldest_player.stop()
        oldest_player.set_meta(META_IN_USE, false)
        _follow_targets.erase(oldest_player)
        _stats["steals"] += 1

    return oldest_player

static func _validate_bus(bus: String) -> String:
    var idx := AudioServer.get_bus_index(bus)
    if idx == -1:
        push_warning("Unknown audio bus '%s', falling back to SFX" % bus)
        return "SFX"
    return bus

static func _configure_player_spatialization(
    player: AudioStreamPlayer3D,
    max_distance: float,
    attenuation_model: int
) -> void:
    if _spatial_audio_enabled:
        player.max_distance = max_distance if max_distance > 0 else _DEFAULT_MAX_DISTANCE
        player.attenuation_model = attenuation_model if attenuation_model >= 0 else _DEFAULT_ATTENUATION_MODEL
        player.panning_strength = _DEFAULT_PANNING_STRENGTH
    else:
        player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
        player.panning_strength = 0.0

## Call from _process in container (or via SceneTree.process_frame signal)
static func update_follow_targets() -> void:
    for player in _follow_targets.keys():
        if not is_instance_valid(player) or not player.playing:
            _follow_targets.erase(player)
            continue
        var target: Node3D = _follow_targets.get(player)
        if target == null or not is_instance_valid(target):
            _follow_targets.erase(player)
            continue
        player.global_position = target.global_position
```

### spawn_3d Config Reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `audio_stream` | `AudioStream` | **required** | The audio stream to play |
| `position` | `Vector3` | `Vector3.ZERO` | Initial world position |
| `volume_db` | `float` | `0.0` | Volume offset in decibels |
| `pitch_scale` | `float` | `1.0` | Playback speed/pitch multiplier |
| `bus` | `String` | `"SFX"` | Audio bus name (falls back to SFX if invalid) |
| `max_distance` | `float` | `-1.0` | Max audible distance (-1 = use default 50.0) |
| `attenuation_model` | `int` | `-1` | Godot attenuation model (-1 = use default) |
| `follow_target` | `Node3D` | `null` | Entity to follow (enables follow-emitter mode) |

### Add Metrics/Debug Hooks

```gdscript
static var _stats: Dictionary = {
    "spawns": 0,
    "steals": 0,
    "drops": 0,
    "peak_usage": 0
}

static func get_stats() -> Dictionary:
    return _stats.duplicate()

static func reset_stats() -> void:
    _stats = {"spawns": 0, "steals": 0, "drops": 0, "peak_usage": 0}

static func _update_peak_usage() -> void:
    var in_use := 0
    for player in _pool:
        if player.get_meta(META_IN_USE, false):
            in_use += 1
    if in_use > _stats["peak_usage"]:
        _stats["peak_usage"] = in_use
```

---

## Phase 8: UI Sound Improvements

**Goal**: Polyphony support, per-sound throttles, data-driven registry.

### Update M_AudioManager for UI Sound Polyphony

```gdscript
const UI_SOUND_POLYPHONY := 4
var _ui_sound_players: Array[AudioStreamPlayer] = []
var _ui_sound_index: int = 0

func _setup_ui_sound_players() -> void:
    for i in range(UI_SOUND_POLYPHONY):
        var player := AudioStreamPlayer.new()
        player.bus = String(U_AudioBusConstants.BUS_UI)
        add_child(player)
        _ui_sound_players.append(player)

func play_ui_sound(sound_id: StringName) -> void:
    var sound_def := U_AudioRegistryLoader.get_ui_sound(sound_id)
    if sound_def == null or sound_def.stream == null:
        push_warning("Unknown UI sound: %s" % sound_id)
        return

    # Round-robin through players for polyphony
    var player := _ui_sound_players[_ui_sound_index]
    _ui_sound_index = (_ui_sound_index + 1) % UI_SOUND_POLYPHONY

    player.stream = sound_def.stream
    player.volume_db = sound_def.volume_db
    if sound_def.pitch_variation > 0.0:
        player.pitch_scale = randf_range(1.0 - sound_def.pitch_variation, 1.0 + sound_def.pitch_variation)
    else:
        player.pitch_scale = 1.0
    player.play()
```

### Update U_UISoundPlayer for Per-Sound Throttles

```gdscript
static var _last_play_times: Dictionary = {}  # sound_id -> timestamp_ms

static func _play(sound_id: StringName) -> bool:
    var sound_def := U_AudioRegistryLoader.get_ui_sound(sound_id)
    if sound_def == null:
        return false

    # Check per-sound throttle
    if sound_def.throttle_ms > 0:
        var now := Time.get_ticks_msec()
        var last_time: int = _last_play_times.get(sound_id, 0)
        if now - last_time < sound_def.throttle_ms:
            return false
        _last_play_times[sound_id] = now

    var audio_mgr := U_AudioUtils.get_audio_manager()
    if audio_mgr == null:
        return false
    audio_mgr.play_ui_sound(sound_id)
    return true
```

---

## Phase 9: State-Driven Architecture

**Goal**: Move preview to transient state, improve subscription efficiency.

**Note**: M_StateStore uses `subscribe(callback)` which receives `(action, state)`. There is no `subscribe_to_slice()` method. Efficiency improvements must filter within the callback.

### Add Audio Preview to State

In `scripts/state/resources/rs_audio_preview_initial_state.gd`:

```gdscript
extends Resource
class_name RS_AudioPreviewInitialState

func get_initial_state() -> Dictionary:
    return {
        "active": false,
        "master_volume": 1.0,
        "music_volume": 1.0,
        "sfx_volume": 1.0,
        "ambient_volume": 1.0,
        "master_muted": false,
        "music_muted": false,
        "sfx_muted": false,
        "ambient_muted": false,
        "spatial_audio_enabled": true,
    }
```

Register as `audio_preview` slice in M_StateStore initialization.

### Add Preview Actions

In `scripts/state/actions/u_audio_actions.gd`:

```gdscript
const ACTION_SET_PREVIEW_ACTIVE := &"audio_preview/set_active"
const ACTION_UPDATE_PREVIEW := &"audio_preview/update"
const ACTION_CLEAR_PREVIEW := &"audio_preview/clear"

static func set_preview_active(active: bool) -> Dictionary:
    return {"type": ACTION_SET_PREVIEW_ACTIVE, "payload": {"active": active}}

static func update_preview_settings(settings: Dictionary) -> Dictionary:
    return {"type": ACTION_UPDATE_PREVIEW, "payload": settings, "immediate": true}

static func clear_preview() -> Dictionary:
    return {"type": ACTION_CLEAR_PREVIEW, "payload": {}}
```

### Add Preview Reducer

In `scripts/state/reducers/r_audio_preview_reducer.gd`:

```gdscript
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", &"")
    match action_type:
        U_AudioActions.ACTION_SET_PREVIEW_ACTIVE:
            var new_state := state.duplicate()
            new_state["active"] = action.get("payload", {}).get("active", false)
            return new_state
        U_AudioActions.ACTION_UPDATE_PREVIEW:
            var new_state := state.duplicate()
            var payload: Dictionary = action.get("payload", {})
            for key in payload:
                new_state[key] = payload[key]
            new_state["active"] = true
            return new_state
        U_AudioActions.ACTION_CLEAR_PREVIEW:
            # Reset to initial state
            return RS_AudioPreviewInitialState.new().get_initial_state()
    return state
```

### Update M_AudioManager - Efficient Subscription

```gdscript
var _last_audio_hash: int = 0
var _last_preview_hash: int = 0

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
    # Handle music/ambient transitions (action-driven)
    _handle_music_actions(action)

    # Only apply audio settings if relevant slices changed
    var audio_slice: Dictionary = state.get("audio", {})
    var preview_slice: Dictionary = state.get("audio_preview", {})

    var audio_hash := audio_slice.hash()
    var preview_hash := preview_slice.hash()

    if preview_slice.get("active", false):
        # Preview mode - apply preview settings
        if preview_hash != _last_preview_hash:
            _apply_audio_settings_from_dict(preview_slice)
            _last_preview_hash = preview_hash
    else:
        # Normal mode - apply audio settings
        if audio_hash != _last_audio_hash:
            _apply_audio_settings_from_dict(audio_slice)
            _last_audio_hash = audio_hash

func _apply_audio_settings_from_dict(settings: Dictionary) -> void:
    var master_idx := AudioServer.get_bus_index("Master")
    var music_idx := AudioServer.get_bus_index("Music")
    var sfx_idx := AudioServer.get_bus_index("SFX")
    var ambient_idx := AudioServer.get_bus_index("Ambient")

    AudioServer.set_bus_volume_db(master_idx, _linear_to_db(settings.get("master_volume", 1.0)))
    AudioServer.set_bus_mute(master_idx, settings.get("master_muted", false))
    # ... etc for other buses
```

### Update UI_AudioSettingsTab

```gdscript
func _on_slider_changed() -> void:
    if _updating_from_state:
        return
    _store.dispatch(U_AudioActions.update_preview_settings({
        "master_volume": _master_slider.value,
        "music_volume": _music_slider.value,
        "sfx_volume": _sfx_slider.value,
        "ambient_volume": _ambient_slider.value,
    }))

func _on_cancel_pressed() -> void:
    _store.dispatch(U_AudioActions.clear_preview())
    _close_overlay()

func _on_apply_pressed() -> void:
    # Apply preview values to actual audio slice
    var preview: Dictionary = _store.get_slice(&"audio_preview")
    _store.dispatch(U_AudioActions.set_master_volume(preview.get("master_volume", 1.0)))
    _store.dispatch(U_AudioActions.set_music_volume(preview.get("music_volume", 1.0)))
    _store.dispatch(U_AudioActions.set_sfx_volume(preview.get("sfx_volume", 1.0)))
    _store.dispatch(U_AudioActions.set_ambient_volume(preview.get("ambient_volume", 1.0)))
    _store.dispatch(U_AudioActions.clear_preview())
    _close_overlay()
```

---

## Phase 10: Testing & Documentation

**Goal**: Comprehensive test coverage, docs update.

### New Test Files

1. `tests/unit/managers/helpers/test_u_crossfade_player.gd` - Crossfade utility tests
2. `tests/unit/managers/helpers/test_u_audio_registry_loader.gd` - Registry validation tests
3. `tests/unit/managers/helpers/test_m_sfx_spawner_voice_stealing.gd` - Voice stealing tests
4. `tests/integration/audio/test_audio_scene_transitions.gd` - Cross-scene music/ambient
5. `tests/integration/audio/test_ui_sound_polyphony.gd` - UI sound overlap tests

### Test Patterns

```gdscript
# Test voice stealing (uses Dictionary config API)
func test_voice_stealing_on_pool_exhaustion() -> void:
    M_SFXSpawner.reset_stats()
    # Fill pool with 16 sounds
    for i in range(16):
        M_SFXSpawner.spawn_3d({
            "audio_stream": _test_stream,
            "position": Vector3.ZERO
        })

    # 17th sound should steal oldest
    var stolen := M_SFXSpawner.spawn_3d({
        "audio_stream": _test_stream,
        "position": Vector3.ZERO
    })
    assert_not_null(stolen)
    assert_eq(M_SFXSpawner.get_stats()["steals"], 1)

# Test bus fallback
func test_unknown_bus_falls_back_to_sfx() -> void:
    var player := M_SFXSpawner.spawn_3d({
        "audio_stream": _test_stream,
        "position": Vector3.ZERO,
        "bus": "NonExistentBus"
    })
    assert_eq(player.bus, "SFX")

# Test follow emitter mode
func test_follow_emitter_updates_position() -> void:
    var emitter := Node3D.new()
    add_child(emitter)
    emitter.global_position = Vector3(10, 0, 0)

    var player := M_SFXSpawner.spawn_3d({
        "audio_stream": _test_stream,
        "position": emitter.global_position,
        "follow_target": emitter
    })

    # Move emitter
    emitter.global_position = Vector3(20, 0, 0)
    M_SFXSpawner.update_follow_targets()

    assert_eq(player.global_position, Vector3(20, 0, 0))
    emitter.queue_free()
```

### Update AGENTS.md

Add Audio Manager patterns section:
```markdown
## Audio Manager Patterns

### Registry & Data
- All audio tracks/sounds defined as resources in `resources/audio/`
- Use `U_AudioRegistryLoader` for O(1) lookup by ID
- Scene→audio mappings stored separately from track definitions
- Per-track pause behavior: `"pause"`, `"duck"`, or `"continue"`

### Crossfade
- Use `U_CrossfadePlayer` utility for music and ambient
- Both managed by persistent M_AudioManager (not per-scene)
- Mix snapshots via per-track `pause_behavior` field

### Bus Layout
- Buses defined in project.godot, runtime validates only
- Use `U_AudioBusConstants` for bus name constants
- Always use `get_bus_index_safe()` to handle missing buses

### SFX Spawner
- Uses Dictionary config API: `spawn_3d(config: Dictionary)`
- Voice stealing (oldest) on pool exhaustion
- Per-sound spatialization via `max_distance`, `attenuation_model` config keys
- Follow-emitter mode via `follow_target` config key
- Bus fallback to "SFX" on unknown bus
- Metrics via `get_stats()`: spawns, steals, drops, peak_usage

### ECS Sound Systems
- Standardized request schema: `{position: Vector3, entity_id?: StringName}`
- Shared helpers in `BaseEventSFXSystem`: `_should_skip_processing()`, `_is_audio_blocked()`, `_is_throttled()`, `_spawn_sfx()`
- Consistent pause/transition gating across all systems
- Resolve entity positions at event publish time, not in sound system
```

---

## Verification Strategy

1. **Phase 1**: Create resources, verify loader validates correctly
2. **Phase 2**: Test crossfader in isolation, verify no audio glitches
3. **Phase 3**: Test cross-scene ambient transitions
4. **Phase 4**: Remove runtime bus creation, verify editor layout works
5. **Phase 5**: Remove all has_method()/call() patterns, verify type safety
6. **Phase 6**: Test ECS systems with pause gating, verify consistency
7. **Phase 7**: Test voice stealing under load
8. **Phase 8**: Test UI sound overlap
9. **Phase 9**: Test preview via Redux state
10. **Phase 10**: Full test suite pass

**Test command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

---

## Implementation Order

**Critical path** (sequential): Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

**Parallelizable after Phase 5**:
- Phase 6 (ECS refactor)
- Phase 7 (SFX spawner)
- Phase 8 (UI sounds)

**Final phases**:
- Phase 9 (state-driven) - after Phase 5
- Phase 10 (testing/docs) - last

---

## Files to Modify

### New Files
- `scripts/ecs/resources/rs_music_track_definition.gd`
- `scripts/ecs/resources/rs_ambient_track_definition.gd`
- `scripts/ecs/resources/rs_ui_sound_definition.gd`
- `scripts/ecs/resources/rs_scene_audio_mapping.gd`
- `scripts/managers/helpers/u_audio_registry_loader.gd`
- `scripts/managers/helpers/u_crossfade_player.gd`
- `scripts/managers/helpers/u_audio_bus_constants.gd`
- `scripts/interfaces/i_audio_manager.gd`
- `scripts/utils/u_audio_utils.gd`
- `resources/audio/tracks/*.tres` (5 music tracks)
- `resources/audio/ambient/*.tres` (2 ambient tracks)
- `resources/audio/ui/*.tres` (4 UI sounds)
- `resources/audio/scene_mappings/*.tres`

### Modified Files
- `scripts/managers/m_audio_manager.gd` - Major refactor
- `scripts/managers/helpers/m_sfx_spawner.gd` - Voice stealing, config
- `scripts/ecs/base_event_sfx_system.gd` - Shared helpers
- `scripts/ecs/systems/s_jump_sound_system.gd` - Simplify
- `scripts/ecs/systems/s_landing_sound_system.gd` - Simplify
- `scripts/ecs/systems/s_death_sound_system.gd` - Simplify, fix search
- `scripts/ecs/systems/s_checkpoint_sound_system.gd` - Simplify, fix search
- `scripts/ecs/systems/s_victory_sound_system.gd` - Simplify
- `scripts/ecs/systems/s_footstep_sound_system.gd` - Timer cleanup
- `scripts/ui/utils/u_ui_sound_player.gd` - Per-sound throttles
- `scripts/ui/settings/ui_audio_settings_tab.gd` - Type-safe, Redux preview
- `scripts/scene_structure/main.gd` - Service registration
- `AGENTS.md` - Add audio patterns

### Deleted Files
- `scripts/ecs/systems/s_ambient_sound_system.gd` - Moved to manager
