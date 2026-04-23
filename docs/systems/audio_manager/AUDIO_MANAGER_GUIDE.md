# Audio Manager User Guide

## Overview

The Audio Manager provides a centralized, resource-driven system for managing all game audio including music, ambient sounds, UI sounds, and 3D sound effects. This guide covers common tasks and best practices.

## Quick Start

### Access the Audio Manager

```gdscript
# From any script
const U_AudioUtils := preload("res://scripts/utils/u_audio_utils.gd")
var audio_mgr := U_AudioUtils.get_audio_manager()
```

### Play Audio

```gdscript
# Music (crossfades automatically)
audio_mgr.play_music(StringName("main_menu"))

# Ambient sound (crossfades automatically)
audio_mgr.play_ambient(StringName("exterior"))

# UI sound
audio_mgr.play_ui_sound(StringName("ui_confirm"))

# 3D sound effect
const U_SFXSpawner := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
U_SFXSpawner.spawn_3d({
    "stream": preload("res://assets/audio/sfx/sfx_jump.wav"),
    "position": global_position,
    "bus": "SFX"
})
```

## Adding New Music Tracks

### Step 1: Create the Resource Definition

1. Create a new `.tres` file in `resources/audio/tracks/`:
   - Right-click → New Resource → `RS_MusicTrackDefinition`
   - Name it `music_your_track.tres`

2. Configure the resource:
   ```
   track_id: StringName("your_track")
   stream: AudioStream (drag your .mp3/.ogg file here)
   default_fade_duration: 1.5  # seconds
   base_volume_offset_db: 0.0
   loop: true
   pause_behavior: "pause"  # Options: "pause", "duck", "continue"
   ```

### Step 2: Register in the Loader

Open `scripts/managers/helpers/u_audio_registry_loader.gd` and add to `_register_music_tracks()`:

```gdscript
static func _register_music_tracks() -> void:
    # Existing tracks...

    # Your new track
    var your_track := preload("res://resources/audio/tracks/music_your_track.tres") as RS_MusicTrackDefinition
    _music_tracks[your_track.track_id] = your_track
```

### Step 3: Use in Code

```gdscript
# Play with default fade (1.5s)
audio_mgr.play_music(StringName("your_track"))

# Play with custom fade (3s)
audio_mgr.play_music(StringName("your_track"), 3.0)

# Play from specific position
audio_mgr.play_music(StringName("your_track"), 1.5, 30.0)  # Start at 30 seconds
```

### Pause Behavior Options

- **"pause"**: Music pauses when game is paused (default)
- **"duck"**: Music volume reduces during pause (not yet implemented)
- **"continue"**: Music continues playing during pause

## Adding New Ambient Sounds

### Step 1: Create the Resource Definition

1. Create a new `.tres` file in `resources/audio/ambient/`:
   - Right-click → New Resource → `RS_AmbientTrackDefinition`
   - Name it `ambient_your_area.tres`

2. Configure the resource:
   ```
   ambient_id: StringName("your_area")
   stream: AudioStream (drag your .wav/.ogg file here)
   default_fade_duration: 2.0  # seconds
   base_volume_offset_db: -3.0  # Ambient is usually quieter
   loop: true
   ```

### Step 2: Register in the Loader

Open `scripts/managers/helpers/u_audio_registry_loader.gd` and add to `_register_ambient_tracks()`:

```gdscript
static func _register_ambient_tracks() -> void:
    # Existing tracks...

    # Your new ambient
    var your_ambient := preload("res://resources/audio/ambient/ambient_your_area.tres") as RS_AmbientTrackDefinition
    _ambient_tracks[your_ambient.ambient_id] = your_ambient
```

### Step 3: Use in Code

```gdscript
# Play ambient (crossfades from current ambient)
audio_mgr.play_ambient(StringName("your_area"))

# Stop ambient with fade out
audio_mgr.stop_ambient(2.0)  # 2s fade out
```

## Adding New UI Sounds

### Step 1: Create the Resource Definition

1. Create a new `.tres` file in `resources/audio/ui/`:
   - Right-click → New Resource → `RS_UISoundDefinition`
   - Name it `ui_your_sound.tres`

2. Configure the resource:
   ```
   sound_id: StringName("ui_your_sound")
   stream: AudioStream (drag your .wav file here)
   volume_db: 0.0
   pitch_variation: 0.1  # Randomizes pitch ±10%
   throttle_ms: 0  # 0 = no throttle, 100 = minimum 100ms between plays
   ```

### Step 2: Register in the Loader

Open `scripts/managers/helpers/u_audio_registry_loader.gd` and add to `_register_ui_sounds()`:

```gdscript
static func _register_ui_sounds() -> void:
    # Existing sounds...

    # Your new sound
    var your_sound := preload("res://resources/audio/ui/ui_your_sound.tres") as RS_UISoundDefinition
    _ui_sounds[your_sound.sound_id] = your_sound
```

### Step 3: Use in Code

```gdscript
# Direct API
audio_mgr.play_ui_sound(StringName("ui_your_sound"))

# Helper API (recommended for common UI sounds)
const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")
U_UISoundPlayer.play_focus()  # Built-in helper
```

### Throttling UI Sounds

Use `throttle_ms` to prevent rapid repeated plays:

```
throttle_ms: 0   → No throttle (all plays allowed)
throttle_ms: 50  → Minimum 50ms between plays
throttle_ms: 100 → Minimum 100ms between plays
```

**Example:** Slider tick sounds should use `throttle_ms: 100` to avoid audio spam.

## Adding New 3D Sound Effects

### Option A: Simple One-Off Sounds

```gdscript
const U_SFXSpawner := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

func play_jump_sound() -> void:
    U_SFXSpawner.spawn_3d({
        "stream": preload("res://assets/audio/sfx/sfx_jump.wav"),
        "position": global_position,
        "volume_db": 0.0,
        "pitch_scale": 1.0,
        "bus": "SFX"
    })
```

### Option B: ECS Sound System (Recommended for Gameplay)

For gameplay sounds triggered by ECS events, create a dedicated sound system:

1. **Create the system** (e.g., `scripts/ecs/systems/s_your_sound_system.gd`):

```gdscript
extends BaseEventSFXSystem
class_name S_YourSoundSystem

@export var settings: RS_YourSoundSettings

func get_event_name() -> StringName:
    return U_ECSEventNames.YOUR_EVENT  # e.g., "entity_jumped"

func create_request_from_payload(payload: Dictionary) -> Dictionary:
    return {
        "position": payload.get("position", Vector3.ZERO),
        "entity_id": payload.get("entity_id", StringName(""))
    }

func _get_audio_stream() -> AudioStream:
    if settings == null:
        return null
    return settings.audio_stream

func process_tick(delta: float) -> void:
    if _should_skip_processing():
        return

    if _is_audio_blocked():  # Checks pause/transition/shell
        requests.clear()
        return

    var now := U_ECSUtils.get_current_time()

    for request in requests:
        if _is_throttled(settings.min_interval, now):
            continue

        var position: Vector3 = _extract_position(request)
        var pitch: float = _calculate_pitch(settings.pitch_variation)

        _spawn_sfx(
            settings.audio_stream,
            position,
            settings.volume_db,
            pitch,
            settings.bus_name
        )

        _last_play_time = now

    requests.clear()
```

2. **Create the settings resource** (`scripts/ecs/resources/rs_your_sound_settings.gd`):

```gdscript
extends Resource
class_name RS_YourSoundSettings

@export var enabled: bool = true
@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.1
@export var min_interval: float = 0.1
@export var bus_name: String = "SFX"
```

3. **Add to scene** and configure settings resource in Inspector.

## Configuring Scene Audio Mappings

Scene audio mappings automatically play music and ambient sounds when transitioning to a scene.

### Step 1: Create the Mapping Resource

1. Create a new `.tres` file in `resources/audio/scene_mappings/`:
   - Right-click → New Resource → `RS_SceneAudioMapping`
   - Name it `scene_your_scene.tres`

2. Configure the resource:
   ```
   scene_id: StringName("your_scene")
   music_track_id: StringName("your_track")  # Optional
   ambient_track_id: StringName("your_ambient")  # Optional
   ```

**Note:** Leave fields empty (`StringName("")`) if the scene should not change music/ambient.

### Step 2: Register in the Loader

Open `scripts/managers/helpers/u_audio_registry_loader.gd` and add to `_register_scene_audio_mappings()`:

```gdscript
static func _register_scene_audio_mappings() -> void:
    # Existing mappings...

    # Your new mapping
    var your_mapping := preload("res://resources/audio/scene_mappings/scene_your_scene.tres") as RS_SceneAudioMapping
    _scene_audio_map[your_mapping.scene_id] = your_mapping
```

### Step 3: Automatic Transitions

When a scene transition completes, the Audio Manager automatically:
1. Looks up the scene mapping for the new scene
2. Crossfades to the mapped music track (if specified)
3. Crossfades to the mapped ambient track (if specified)

No code required - it just works!

## Understanding the Bus Layout

### Bus Hierarchy

```
Master (0)
├── Music (1)
├── SFX (2)
│   ├── UI (3)
│   └── Footsteps (4)
└── Ambient (5)
```

### Bus Configuration

The bus layout is defined in `default_bus_layout.tres` (editor-defined, do not create at runtime).

**Available buses:**
- `"Master"` - Top-level volume control
- `"Music"` - Music tracks
- `"SFX"` - General sound effects
- `"UI"` - UI sounds (child of SFX)
- `"Footsteps"` - Footstep sounds (child of SFX)
- `"Ambient"` - Ambient/environmental sounds

### Bus Access

```gdscript
const U_AudioBusConstants := preload("res://scripts/managers/helpers/u_audio_bus_constants.gd")

# Safe bus access (returns Master if bus not found)
var bus_index := U_AudioBusConstants.get_bus_index_safe("SFX")

# Validate entire bus layout
if not U_AudioBusConstants.validate_bus_layout():
    push_error("Audio bus layout is invalid!")
```

### Choosing the Right Bus

- **Music** - Background music, theme songs, menu music
- **SFX** - Gameplay sounds, explosions, impacts, pickups
- **UI** - Menu navigation, button clicks, confirmations
- **Footsteps** - Character footstep sounds (separate for volume control)
- **Ambient** - Wind, rain, crowd noise, environmental loops

## Advanced Features

### Voice Stealing

When spawning more than 16 simultaneous 3D sounds, the oldest playing sound is automatically stopped ("stolen") to make room for new sounds.

**Stats tracking:**
```gdscript
const U_SFXSpawner := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

var stats := U_SFXSpawner.get_stats()
print("Spawns: ", stats.spawns)
print("Steals: ", stats.steals)
print("Peak usage: ", stats.peak_usage)

# Reset stats
U_SFXSpawner.reset_stats()
```

**Best practices:**
- Keep peak usage under 12 simultaneous sounds
- Voice stealing rate should be <5% of total spawns
- Use throttling to prevent audio spam

### Follow-Emitter Mode

Make a sound follow a moving entity:

```gdscript
U_SFXSpawner.spawn_3d({
    "stream": looping_engine_sound,
    "position": vehicle.global_position,
    "follow_target": vehicle,  # Sound follows this node
    "bus": "SFX"
})
```

The spawner automatically updates the sound position each frame until:
- The sound stops playing
- The entity is freed
- The sound is stolen by voice stealing

### Per-Sound Spatialization

Override spatialization settings per sound:

```gdscript
U_SFXSpawner.spawn_3d({
    "stream": explosion_sound,
    "position": global_position,
    "max_distance": 200.0,  # Can be heard from 200 units away
    "attenuation_model": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
    "bus": "SFX"
})
```

**Attenuation models:**
- `ATTENUATION_INVERSE_DISTANCE` - Realistic falloff (default)
- `ATTENUATION_INVERSE_SQUARE_DISTANCE` - Faster falloff
- `ATTENUATION_LOGARITHMIC` - Gradual falloff

### Audio Settings Preview

Temporarily override audio settings for real-time preview in settings menus:

```gdscript
# Enable preview mode
var preview_settings := {
    "master_volume": 0.8,
    "music_volume": 0.6,
    "sfx_volume": 0.7
}
audio_mgr.set_audio_settings_preview(preview_settings)

# Restore persisted settings
audio_mgr.clear_audio_settings_preview()
```

Used by `UI_VFXSettingsOverlay` for real-time audio settings adjustments.

## Troubleshooting

### Music doesn't play

**Check:**
1. Is the track registered in `U_AudioRegistryLoader._register_music_tracks()`?
2. Does the resource have a valid `stream` assigned?
3. Is the `track_id` correct (case-sensitive)?
4. Is the Music bus volume set to 0 in audio settings?

**Debug:**
```gdscript
var track := U_AudioRegistryLoader.get_music_track(StringName("your_track"))
if track == null:
    print("Track not found!")
else:
    print("Track found: ", track.track_id)
    print("Stream: ", track.stream)
```

### Ambient sound doesn't crossfade

**Check:**
1. Is the ambient track registered in `U_AudioRegistryLoader._register_ambient_tracks()`?
2. Is the scene mapping registered in `_register_scene_audio_mappings()`?
3. Does the scene mapping have the correct `ambient_track_id`?

**Debug:**
```gdscript
var mapping := U_AudioRegistryLoader.get_audio_for_scene(StringName("your_scene"))
if mapping == null:
    print("No mapping for scene!")
else:
    print("Ambient track: ", mapping.ambient_track_id)
```

### UI sound plays too frequently

**Solution:** Add throttling to the sound definition:

```
throttle_ms: 100  # Minimum 100ms between plays
```

### 3D sound doesn't play

**Check:**
1. Is the SFX pool exhausted? (Check `U_SFXSpawner.get_stats().peak_usage`)
2. Is the bus name correct?
3. Is the sound being played during pause/transition? (Use `_is_audio_blocked()` in systems)

**Debug:**
```gdscript
var stats := U_SFXSpawner.get_stats()
print("Peak usage: ", stats.peak_usage, "/16")
print("Voice steals: ", stats.steals)
```

### Sounds don't play during gameplay

**Check:**
1. Is the scene's `navigation.shell` set to `"gameplay"`?
2. Is the game paused? (`gameplay.is_paused`)
3. Is a scene transition in progress? (`scene.is_transitioning`)

All ECS sound systems check `_is_audio_blocked()` which returns true if:
- `gameplay.is_paused == true`
- `scene.is_transitioning == true`
- `navigation.shell != "gameplay"`

### Audio pops/clicks during crossfades

**Solution:** Increase fade duration:

```gdscript
# Longer fade = smoother transition
audio_mgr.play_music(StringName("your_track"), 2.5)  # 2.5s fade
```

### Console warnings about missing buses

**Error:** `U_SFXSpawner: Unknown bus 'CustomBus', falling back to SFX`

**Solution:**
1. Add the bus to `default_bus_layout.tres` in the Godot editor
2. Add the bus name to `U_AudioBusConstants.REQUIRED_BUSES` array
3. Use an existing bus instead (e.g., "SFX")

## Best Practices

### DO:

✅ Use resource definitions for all audio assets
✅ Register all tracks in `U_AudioRegistryLoader`
✅ Use scene mappings for automatic music/ambient transitions
✅ Check `_is_audio_blocked()` in ECS sound systems
✅ Include position in event payloads (not entity_id)
✅ Use throttling for UI sounds that can repeat rapidly
✅ Keep SFX pool usage under 12 concurrent sounds

### DON'T:

❌ Hard-code audio streams in scripts
❌ Create bus layout at runtime (use `default_bus_layout.tres`)
❌ Do O(n) entity lookups in sound systems (`find_child()`, `get_entity_by_id()`)
❌ Play audio during pause/transitions without gating
❌ Spawn >16 SFX simultaneously without monitoring stats
❌ Use very short throttle_ms (<50ms) for UI sounds

## Code Examples

### Complete Music Playback Example

```gdscript
extends Node

const U_AudioUtils := preload("res://scripts/utils/u_audio_utils.gd")

func _ready() -> void:
    await get_tree().process_frame
    var audio_mgr := U_AudioUtils.get_audio_manager()

    # Play main menu music with 2s crossfade
    audio_mgr.play_music(StringName("main_menu"), 2.0)

func transition_to_gameplay() -> void:
    var audio_mgr := U_AudioUtils.get_audio_manager()

    # Music and ambient will change automatically via scene mapping
    # No need to call play_music() or play_ambient() manually!
    scene_manager.transition_to_scene(StringName("gameplay_base"))
```

### Complete UI Sound Example

```gdscript
extends Button

const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")

func _ready() -> void:
    focus_entered.connect(_on_focus_entered)
    pressed.connect(_on_pressed)

func _on_focus_entered() -> void:
    U_UISoundPlayer.play_focus()

func _on_pressed() -> void:
    U_UISoundPlayer.play_confirm()
```

### Complete 3D SFX Example

```gdscript
extends Node3D

const U_SFXSpawner := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

@export var explosion_sound: AudioStream

func explode() -> void:
    U_SFXSpawner.spawn_3d({
        "stream": explosion_sound,
        "position": global_position,
        "volume_db": 3.0,  # Louder than default
        "pitch_scale": randf_range(0.9, 1.1),  # Slight pitch variation
        "max_distance": 150.0,  # Large explosion, heard from far away
        "bus": "SFX"
    })
```

## See Also

- **AGENTS.md** - Audio Manager Patterns section for architectural details
- **audio-manager-refactor-tasks.md** - Refactor task checklist and completion notes
- **Test files** - `tests/integration/audio/` and `tests/unit/managers/` for usage examples
