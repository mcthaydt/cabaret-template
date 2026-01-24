# Audio Manager Overview

**Project**: Cabaret Template (Godot 4.5)
**Created**: 2026-01-01
**Last Updated**: 2026-01-10
**Status**: IN PROGRESS (Phase 0–9 complete)
**Scope**: Music with crossfading, comprehensive SFX, ambient audio, footsteps, 3D spatial audio

## Summary

The audio stack uses `M_AudioManager` (persistent manager) for bus layout + volume/mute + music crossfades + UI sounds, plus ECS systems for gameplay SFX/footsteps/ambient. Settings live in the Redux `audio` slice and are applied to Godot audio buses in real time.

## Repo Reality Checks

- Main scene is `scenes/root.tscn` (there is no `scenes/main.tscn` in this repo).
- Service registration is bootstrapped by `scripts/root.gd` using `U_ServiceLocator` (`res://scripts/core/u_service_locator.gd`).
- `S_JumpSoundSystem` exists at `scripts/ecs/systems/s_jump_sound_system.gd` and is implemented (event-driven SFX via BaseEventSFXSystem + pooled 3D spawner).
- `RS_GameplayInitialState` currently includes `gameplay.audio_settings` + `U_VisualSelectors.get_audio_settings()`; this is not used by any real audio playback path today.
- `BaseEventSFXSystem` exists (mirrors BaseEventVFXSystem) and is used by event-driven sound systems.
- Placeholder audio assets live under `resources/audio/` and are imported (see `resources/audio/music/` and `resources/audio/sfx/`).

## Goals

- Provide centralized music playback with smooth crossfading between scenes/screens.
- Play comprehensive SFX for gameplay events (jump, land, death, checkpoint, victory).
- Support full UI audio feedback (focus, confirm, cancel, tab switch, slider changes).
- Play per-scene ambient audio tracks with crossfading.
- Implement surface-aware footstep sounds.
- Support 3D spatial audio (AudioStreamPlayer3D) with a user toggle to disable attenuation/panning.
- Expose volume controls and mute toggles via Redux state for settings UI.

## Non-Goals

- No dynamic music system (adaptive layers, stems switching based on gameplay intensity).
- No voice/dialogue system (out of scope for initial implementation).
- No audio streaming from external sources (all audio bundled with game).
- No reverb zones or complex acoustic simulation (simple spatial attenuation only).
- No runtime audio generation or synthesis.

## Responsibilities & Boundaries

**Audio Manager owns**

- Audio bus volume/mute control (Master, Music, SFX, Ambient).
- Background music player with crossfade transitions.
- UI sound playback coordination (`UI` bus + `U_UISoundPlayer` helper).
- 3D SFX pooling helper initialization (`U_SFXSpawner`) and spatial toggle wiring.
- Redux `audio` slice subscription for settings changes.

**Audio Manager depends on**

- `M_StateStore`: Audio settings stored in `audio` Redux slice; manager subscribes for changes.
- `M_SceneManager`: Indirectly (dispatches scene transition actions consumed by music/ambient systems).
- `U_ECSEventBus`: Gameplay events (jump, land, death, etc.) trigger SFX systems.
- `U_ServiceLocator`: Registration for discovery by other systems.

**Note on ECS pattern**: Sound systems extend `BaseEventSFXSystem` (mirrors `BaseEventVFXSystem`) and process sound requests in `process_tick()` via `U_SFXSpawner`.

## Public API

```gdscript
# Manager (persistent)
M_AudioManager.play_music(track_id: StringName, duration: float = 1.5) -> void
M_AudioManager.play_ui_sound(sound_id: StringName) -> void

# UI convenience (used by UI scripts)
U_UISoundPlayer.play_focus() -> void
U_UISoundPlayer.play_confirm() -> void
U_UISoundPlayer.play_cancel() -> void
U_UISoundPlayer.play_slider_tick() -> void

# 3D SFX pool (used by ECS sound systems / gameplay)
U_SFXSpawner.spawn_3d(config: Dictionary) -> AudioStreamPlayer3D

# Audio selectors (query from Redux state)
U_AudioSelectors.get_master_volume(state: Dictionary) -> float
U_AudioSelectors.get_music_volume(state: Dictionary) -> float
U_AudioSelectors.get_sfx_volume(state: Dictionary) -> float
U_AudioSelectors.get_ambient_volume(state: Dictionary) -> float
U_AudioSelectors.is_master_muted(state: Dictionary) -> bool
U_AudioSelectors.is_music_muted(state: Dictionary) -> bool
U_AudioSelectors.is_sfx_muted(state: Dictionary) -> bool
U_AudioSelectors.is_ambient_muted(state: Dictionary) -> bool
U_AudioSelectors.is_spatial_audio_enabled(state: Dictionary) -> bool
```

## Audio State Model

### Redux Slice: `audio`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `master_volume` | float | 1.0 | Global volume multiplier (0.0-1.0) |
| `music_volume` | float | 1.0 | Music bus volume (0.0-1.0) |
| `sfx_volume` | float | 1.0 | SFX bus volume (0.0-1.0) |
| `ambient_volume` | float | 1.0 | Ambient bus volume (0.0-1.0) |
| `master_muted` | bool | false | Global mute toggle |
| `music_muted` | bool | false | Music mute toggle |
| `sfx_muted` | bool | false | SFX mute toggle |
| `ambient_muted` | bool | false | Ambient mute toggle |
| `spatial_audio_enabled` | bool | true | 3D audio processing toggle |

**Note**: Audio settings persist to save files as part of the `audio` slice (non-transient).

## Audio Bus Layout

```
Master
├── Music
├── SFX
│   ├── UI
│   └── Footsteps
└── Ambient
```

### Bus Configuration

| Bus | Volume Source | Mute Source |
|-----|---------------|-------------|
| Master | `master_volume` | `master_muted` |
| Music | `music_volume` | `music_muted` |
| SFX | `sfx_volume` | `sfx_muted` |
| UI | Inherits SFX | Inherits SFX |
| Footsteps | Inherits SFX | Inherits SFX |
| Ambient | `ambient_volume` | `ambient_muted` |

## Music System

### Track Registry

Music tracks are registered with scene/screen associations:

| Track ID | Scene/Screen | Description |
|----------|--------------|-------------|
| `main_menu` | Main Menu | Menu theme |
| `gameplay_exterior` | gameplay_exterior | Exterior gameplay theme |
| `gameplay_interior` | gameplay_interior_house | Interior gameplay theme |
| `pause` | Pause Menu Overlay | Ambient/filtered version |
| `credits` | Credits Screen | Credits theme |

### Crossfade Behavior

- **Scene transitions**: Crossfade to new scene's music track over 1.0s.
- **Overlay push (pause)**: Fade to pause track (or apply low-pass filter) over 0.5s.
- **Overlay pop**: Restore previous track over 0.5s.
- **Same track**: No crossfade if target track is already playing.

### Music Player Architecture

```gdscript
# M_AudioManager internal structure
var _music_player_a: AudioStreamPlayer  # Current track
var _music_player_b: AudioStreamPlayer  # Crossfade target
var _music_tween: Tween                  # Crossfade animation
var _current_music_id: StringName        # Currently playing track
```

## SFX System

### Event-Driven Architecture

Sound systems extend `BaseEventSFXSystem` (mirrors `BaseEventVFXSystem`):

```gdscript
extends BaseECSSystem
class_name BaseEventSFXSystem

## Base class for SFX systems that respond to ECS events (mirrors BaseEventVFXSystem)

const EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

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
    for request in requests:
        _spawn_sound(request)
    requests.clear()

func _spawn_sound(_request: Dictionary) -> void:
    # Subclass implements specific sound spawning via U_SFXSpawner
    pass
```

### Sound Systems

| System | Event | Description |
|--------|-------|-------------|
| `S_JumpSoundSystem` | `entity_jumped` | Plays jump SFX at entity position |
| `S_LandingSoundSystem` | `entity_landed` | Plays landing SFX (intensity based on fall height) |
| `S_DeathSoundSystem` | `entity_death` | Plays death SFX |
| `S_CheckpointSoundSystem` | `checkpoint_activated` | Plays checkpoint activation SFX |
| `S_VictorySoundSystem` | `victory_triggered` | Plays victory fanfare |
| `S_FootstepSoundSystem` | Per-tick (movement) | Surface-aware footstep sounds |
| `S_AmbientSoundSystem` | `scene/transition_completed` | Manages per-scene ambient loops |

### SFX Spawner Utility

`U_SFXSpawner` manages pooled AudioStreamPlayer3D instances (see `scripts/managers/helpers/u_sfx_spawner.gd`):

```gdscript
class_name U_SFXSpawner
extends RefCounted

const POOL_SIZE := 16  # Max concurrent 3D sounds

static func initialize(parent: Node) -> void:
    # Creates "SFXPool" and pooled players under parent
    pass

static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
    # {audio_stream, position, volume_db, pitch_scale, bus}
    return null

static func cleanup() -> void:
    # Frees container + clears pool
    pass
```

### Sound Settings Resources

Each sound system has configurable settings:

```gdscript
class_name RS_JumpSoundSettings
extends Resource

@export var enabled: bool = true
@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.1  # Random pitch ± this value
@export var min_interval: float = 0.1     # Prevent spam
```

## Footstep System

### Surface Detection

`C_SurfaceDetectorComponent` detects ground material for footsteps:

```gdscript
class_name C_SurfaceDetectorComponent
extends BaseECSComponent

enum SurfaceType { GRASS, STONE, WOOD, METAL, WATER, DEFAULT }

@export var ray_length: float = 2.0
@export var default_surface: SurfaceType = SurfaceType.DEFAULT

func get_current_surface() -> SurfaceType:
    # Raycast down, check collision layer or material metadata
    pass
```

### Surface Detection Methods

1. **Collision layer groups**: Assign surfaces to specific layers (e.g., layer 10 = grass).
2. **PhysicsMaterial metadata**: Check `physics_material_override.resource_name`.
3. **Node groups**: Check if collider parent is in surface group (e.g., `surface_grass`).

### Footstep Settings

```gdscript
class_name RS_FootstepSoundSettings
extends Resource

@export var enabled: bool = true
@export var step_interval: float = 0.4  # Base seconds between steps (scaled by speed)
@export var min_velocity: float = 1.0  # Minimum horizontal speed to trigger
@export var volume_db: float = 0.0
@export var default_sounds: Array[AudioStream]
@export var grass_sounds: Array[AudioStream]
@export var stone_sounds: Array[AudioStream]
@export var wood_sounds: Array[AudioStream]
@export var metal_sounds: Array[AudioStream]
@export var water_sounds: Array[AudioStream]
```

## Ambient System

### Per-Scene Ambient Tracks

| Scene ID | Ambient Track | Description |
|----------|---------------|-------------|
| `gameplay_exterior` | `exterior_ambience` | Wind, birds, outdoor sounds |
| `gameplay_interior_house` | `interior_ambience` | Indoor hum, creaks, quiet |

### Ambient Crossfading

- Subscribes to `scene/transition_completed` Redux action.
- Crossfades to new scene's ambient track over 2.0s.
- Loops indefinitely until scene change.

## UI Sound Integration

### U_UISoundPlayer

Centralized utility for UI sound playback:

```gdscript
U_UISoundPlayer.play_focus()
U_UISoundPlayer.play_confirm()
U_UISoundPlayer.play_cancel()
U_UISoundPlayer.play_slider_tick()
```

### UI Event Integration

Base UI classes call sound player methods:

| Event | Sound | Trigger Location |
|-------|-------|------------------|
| Focus gained | `ui_focus` | `BasePanel._on_focus_entered()` signal |
| Button pressed | `ui_confirm` | Button `pressed` signal handler |
| Back/Cancel | `ui_cancel` | `_on_back_pressed()` or B/Escape input |
| Slider change | `ui_tick` | Slider `value_changed` signal (throttled) |

## 3D Spatial Audio

### Spatial Audio Settings

3D sounds use `AudioStreamPlayer3D`. Ensure your active camera/player provides the 3D listener (e.g., add an `AudioListener3D` node) so panning/attenuation behave as expected.

When `spatial_audio_enabled = false`:
- 3D sounds play as 2D (no attenuation or panning).
- Useful for accessibility or performance on low-end devices.

Implementation:
- Applied by `M_AudioManager` to `U_SFXSpawner` via `set_spatial_audio_enabled(...)`.
- `U_SFXSpawner.spawn_3d(...)` configures `AudioStreamPlayer3D`:
  - Enabled: inverse-distance attenuation, `panning_strength = 1.0`, `max_distance = 50`
  - Disabled: `ATTENUATION_DISABLED`, `panning_strength = 0.0`

## File Structure

```
scripts/managers/
  m_audio_manager.gd

scripts/managers/helpers/
  u_sfx_spawner.gd

scripts/ui/utils/
  u_ui_sound_player.gd

scripts/ui/settings/
  ui_audio_settings_tab.gd
  ui_audio_settings_overlay.gd

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

scripts/state/
  resources/rs_audio_initial_state.gd
  actions/u_audio_actions.gd
  reducers/u_audio_reducer.gd
  selectors/u_audio_selectors.gd

resources/
  audio/
    music/
    sfx/
    ambient/
    footsteps/
  settings/
    jump_sound_default.tres
    landing_sound_default.tres
    footstep_sound_default.tres
    ambient_sound_default.tres
```

## Settings UI Integration

### Audio Settings Overlay

- Implemented as `UI_AudioSettingsOverlay` (`scenes/ui/ui_audio_settings_overlay.tscn`) and `UI_AudioSettingsTab` (`scenes/ui/settings/ui_audio_settings_tab.tscn`).
- Uses Apply/Cancel/Reset pattern: edits are local until Apply; Cancel discards; Reset applies defaults immediately.
- Opened from `UI_SettingsMenu`:
  - Gameplay (pause/settings overlay): opens as an overlay (`overlay_id = "audio_settings"`).
  - Main menu settings: navigates via `navigate_to_ui_screen(scene_id = "audio_settings")`.

### Redux Actions for Settings

```gdscript
const U_AudioActions = preload("res://scripts/state/actions/u_audio_actions.gd")

# Volume changes
store.dispatch(U_AudioActions.set_master_volume(0.8))
store.dispatch(U_AudioActions.set_music_volume(1.0))
store.dispatch(U_AudioActions.set_sfx_volume(0.7))
store.dispatch(U_AudioActions.set_ambient_volume(0.5))

# Mute toggles
store.dispatch(U_AudioActions.set_master_muted(false))
store.dispatch(U_AudioActions.set_music_muted(false))

# Spatial audio toggle
store.dispatch(U_AudioActions.set_spatial_audio_enabled(true))
```

## Performance Budget

### Audio Manager

- **SFX Pool**: 16 concurrent AudioStreamPlayer3D instances
- **Pool exhaustion**: Log warning, skip sound (don't block gameplay)
- **CPU**: < 0.5ms per frame for music crossfade + SFX spawning
- **Memory**: ~50KB for manager + pools, plus loaded audio streams
- **Footstep cadence**: Base interval `step_interval` scaled by movement speed (clamped to 0.1–`step_interval`)

### Profiling

Use Godot Profiler (Debugger > Profiler) to measure actual overhead:
- Monitor "Audio" category for bus processing
- Check "Script Functions" for U_SFXSpawner and M_AudioManager
- Reduce concurrent sound limit if CPU budget exceeded on target hardware

### Optimization Guidelines

- If pool exhaustion occurs frequently, increase `POOL_SIZE` in `U_SFXSpawner`
- Compress audio files (OGG for music/ambient, WAV for short SFX)
- Keep music loops under 2MB, SFX under 50KB each
- Disable spatial audio on low-end devices via settings

## Testing Strategy

### Unit Tests

- `U_AudioReducer`: Action handling, volume clamping, mute state.
- `U_AudioSelectors`: Selector return values for all settings.
- `U_SFXSpawner`: Pool management, sound spawning, cleanup.
- `BaseEventSFXSystem`: Event subscription, request queuing.

### Integration Tests

- Implemented 4 suites under `tests/integration/audio/` (100 tests total).
- Run: `tools/run_gut_suite.sh -gdir=res://tests/integration/audio -ginclude_subdirs=true`
- Music crossfade: Transition scenes -> verify crossfade behavior.
- SFX playback: Dispatch gameplay event -> verify sound plays.
- Settings application: Dispatch volume action -> verify bus volume updated.
- Footstep system: Move player -> verify surface-appropriate sounds play.

### Manual Testing

- All volume sliders affect correct audio buses.
- Mute toggles immediately silence respective buses.
- Music crossfades smoothly during scene transitions.
- Footsteps change based on ground surface.
- 3D sounds attenuate with distance from player.

## Placeholder Asset Creation Guide

Use Audacity to create temporary placeholder files for testing and development:

### Music/Ambient (silent loops)

1. Generate > Silence (5-10 seconds)
2. File > Export > Export as OGG
3. Commit to `resources/audio/music/` or `resources/audio/ambient/`

### SFX (tone beeps)

1. Generate > Tone (specify frequency/duration per table below)
2. File > Export > Export as WAV
3. Commit to appropriate `resources/audio/` subfolder

| Sound Type | Frequency | Duration | Path |
|------------|-----------|----------|------|
| Jump | 440 Hz | 100ms | resources/audio/sfx/placeholder_jump.wav |
| Landing | 220 Hz | 100ms | resources/audio/sfx/placeholder_land.wav |
| Death | 110 Hz | 150ms | resources/audio/sfx/placeholder_death.wav |
| UI Focus | 1000 Hz | 30ms | resources/audio/sfx/placeholder_ui_focus.wav |
| UI Confirm | 1200 Hz | 50ms | resources/audio/sfx/placeholder_ui_confirm.wav |
| UI Cancel | 800 Hz | 50ms | resources/audio/sfx/placeholder_ui_cancel.wav |

### Footsteps (4 variations per surface)

1. Generate > Noise (white noise, 50ms)
2. Effect > Equalize (adjust for surface type: low-pass for grass, high-pass for metal)
3. Export 4 files per surface: `placeholder_grass_01.wav` through `_04.wav`

**Surfaces to create** (6 × 4 = 24 files):
- `placeholder_default_01.wav` → `_04.wav`
- `placeholder_grass_01.wav` → `_04.wav`
- `placeholder_stone_01.wav` → `_04.wav`
- `placeholder_wood_01.wav` → `_04.wav`
- `placeholder_metal_01.wav` → `_04.wav`
- `placeholder_water_01.wav` → `_04.wav`

### Replacement Strategy

- Placeholders are committed to repo for testing
- Before release, replace with real assets (same filenames)
- Tests use placeholders, shipped game uses real audio
- Keep placeholder file sizes small (< 50KB each)

## Resolved Questions

| Question | Decision |
|----------|----------|
| Music during pause | Fade to pause track or apply low-pass filter to current track |
| Footstep interval | Fixed interval (0.4s) based on movement, not animation sync |
| Surface detection method | ECS component tagging and events, fallback to collision layers |
| SFX pool size | 16 concurrent 3D sounds (skip if pool exhausted) |
| UI sound throttling | Slider changes throttled to max 10 sounds/second |
| Volume scale | 0.0-1.0 logarithmic, converted to dB for audio buses |
| Settings persistence | Included in settings slice, persisted to save files |
| Ambient during menus | Continue ambient during pause, fade out during main menu |
| Audio bus hierarchy | UI and Footsteps as children of SFX for unified volume control |
| 3D audio fallback | When disabled, 3D sounds play as 2D with no attenuation |
