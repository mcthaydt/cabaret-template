# Audio Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.5)
**Status**: In Progress (Phase 4 complete)
**Estimated Duration**: 23 days
**Test Count**: ~280 tests
**Methodology**: Test-Driven Development (Red-Green-Refactor)

---

## Overview

The Audio Manager provides comprehensive audio system with music, SFX, footsteps, ambient, and UI sounds. Features Redux integration, bus layout management, dual-player crossfading, and event-driven SFX systems.

---

## Phase 0: Redux Foundation (Days 1-2)

**PREREQUISITE**: VFX Manager Phase 0 must be complete before starting Audio Manager implementation. The `audio_initial_state` parameter must be added AFTER `vfx_initial_state` in the `u_state_slice_manager.initialize_slices()` function signature.

### 9-Field Audio Slice

**Files to create**:
- `scripts/state/resources/rs_audio_initial_state.gd`
- `scripts/state/actions/u_audio_actions.gd` (12 action creators)
- `scripts/state/reducers/u_audio_reducer.gd`
- `scripts/state/selectors/u_audio_selectors.gd`
- `tests/unit/state/test_audio_reducer.gd` (25 tests)
- `tests/unit/state/test_audio_selectors.gd` (15 tests)

**Files to modify**:
- `scripts/state/m_state_store.gd`:
  - Add `const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")`
  - Add `@export var audio_initial_state: RS_AudioInitialState`
  - Add `audio_initial_state` to `initialize_slices()` call

- `scripts/state/utils/u_state_slice_manager.gd`:
  - **Add parameter** to `initialize_slices()` function signature:
    ```gdscript
    static func initialize_slices(
        # ... existing parameters ...
        vfx_initial_state: RS_VFXInitialState,
        audio_initial_state: RS_AudioInitialState  # ADD THIS
    ) -> void:
    ```
  - **Add Audio slice registration** (after VFX slice block):
    ```gdscript
    # Audio slice
    if audio_initial_state != null:
        var audio_config := RS_StateSliceConfig.new(StringName("audio"))
        audio_config.reducer = Callable(U_AudioReducer, "reduce")
        audio_config.initial_state = audio_initial_state.to_dictionary()
        audio_config.dependencies = []
        audio_config.transient_fields = []
        register_slice(slice_configs, state, audio_config)
    ```
  - **Add reducer preload** at top of file:
    ```gdscript
    const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")
    ```

**State Shape**:
```gdscript
{
    "master_volume": 1.0,      // 0.0-1.0
    "music_volume": 1.0,       // 0.0-1.0
    "sfx_volume": 1.0,         // 0.0-1.0
    "ambient_volume": 1.0,     // 0.0-1.0
    "master_muted": false,
    "music_muted": false,
    "sfx_muted": false,
    "ambient_muted": false,
    "spatial_audio_enabled": true
}
```

**Key Tests**:
- Volume clamping (0.0-1.0)
- Mute toggles independent of volume
- Immutability verification

---

## Phase 1: Core Manager & Bus Layout (Days 3-5)

### Audio Bus Hierarchy

**Files to create**:
- `scripts/managers/m_audio_manager.gd`
- `tests/unit/managers/test_audio_manager.gd` (30 tests)

**Bus Structure**:
```
Master (bus 0)
├── Music (bus 1)
├── SFX (bus 2)
│   ├── UI (bus 3)
│   └── Footsteps (bus 4)
└── Ambient (bus 5)
```

### Audio Bus Layout Creation

**Action**: Create bus hierarchy in AudioServer during `M_AudioManager._ready()`

```gdscript
func _create_bus_layout() -> void:
    # Create buses if they don't exist
    if AudioServer.get_bus_index("Music") == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
        AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")

    if AudioServer.get_bus_index("SFX") == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
        AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")

    if AudioServer.get_bus_index("Ambient") == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambient")
        AudioServer.set_bus_send(AudioServer.get_bus_index("Ambient"), "Master")

    if AudioServer.get_bus_index("UI") == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "UI")
        AudioServer.set_bus_send(AudioServer.get_bus_index("UI"), "SFX")

    if AudioServer.get_bus_index("Footsteps") == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "Footsteps")
        AudioServer.set_bus_send(AudioServer.get_bus_index("Footsteps"), "SFX")
```

**Alternative**: Add buses to `project.godot` manually before implementation (in `[audio]` section).

**Volume Conversion**:
```gdscript
static func _linear_to_db(linear: float) -> float:
    if linear <= 0.0:
        return -80.0
    return 20.0 * log(linear) / log(10.0)
```

**Redux Application**:
```gdscript
func _apply_audio_settings() -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Master"),
        _linear_to_db(U_AUDIO_SELECTORS.get_master_volume(state))
    )
    AudioServer.set_bus_mute(
        AudioServer.get_bus_index("Master"),
        U_AUDIO_SELECTORS.is_master_muted(state)
    )
    # ... repeat for Music, SFX, Ambient
```

---

## Phase 2: Music System (Days 6-8)

### Dual-Player Crossfading

**Placeholder Assets** (create with Audacity: Generate > Silence, export as OGG):
- `resources/audio/music/placeholder_main_menu.ogg` (5s silent loop)
- `resources/audio/music/placeholder_gameplay.ogg` (5s silent loop)

**Music Registry**:
```gdscript
var _music_registry: Dictionary = {
    StringName("main_menu"): {
        "stream": preload("res://resources/audio/music/placeholder_main_menu.ogg"),
        "scene": StringName("main_menu")
    },
    StringName("gameplay"): {
        "stream": preload("res://resources/audio/music/placeholder_gameplay.ogg"),
        "scene": StringName("gameplay_base")
    }
}
```

**Crossfade Algorithm**:
```gdscript
func _crossfade_music(new_stream: AudioStream, track_id: StringName, duration: float) -> void:
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()

    # Swap active/inactive players
    var old_player := _active_music_player
    var new_player := _inactive_music_player
    _active_music_player = new_player
    _inactive_music_player = old_player

    # Start new player at -80dB
    new_player.stream = new_stream
    new_player.volume_db = -80.0
    new_player.play()

    # Crossfade with cubic easing
    _music_tween = create_tween()
    _music_tween.set_parallel(true)
    _music_tween.set_trans(Tween.TRANS_CUBIC)
    _music_tween.set_ease(Tween.EASE_IN_OUT)

    if old_player.playing:
        _music_tween.tween_property(old_player, "volume_db", -80.0, duration)
        _music_tween.chain().tween_callback(old_player.stop)

    _music_tween.tween_property(new_player, "volume_db", 0.0, duration)
```

**Scene Transition Integration**:
```gdscript
func _on_action_dispatched(action: Dictionary) -> void:
    if action.get("type") == StringName("scene/transition_completed"):
        var scene_id := action.get("payload", {}).get("scene_id", StringName(""))
        _change_music_for_scene(scene_id)
```

### Pause Overlay Music Handling (FR-019)

When pause overlay opens, crossfade to pause track and restore on unpause:

```gdscript
var _pre_pause_music_id: StringName = StringName("")

func _on_action_dispatched(action: Dictionary) -> void:
    var action_type := action.get("type", StringName(""))

    match action_type:
        StringName("navigation/overlay_pushed"):
            var overlay_id := action.get("payload", {}).get("overlay_id", StringName(""))
            if overlay_id == StringName("pause"):
                _pre_pause_music_id = _current_music_id
                play_music(StringName("pause"), 0.5)

        StringName("navigation/overlay_popped"):
            var overlay_id := action.get("payload", {}).get("overlay_id", StringName(""))
            if overlay_id == StringName("pause") and _pre_pause_music_id != StringName(""):
                play_music(_pre_pause_music_id, 0.5)
                _pre_pause_music_id = StringName("")

        StringName("scene/transition_completed"):
            var scene_id := action.get("payload", {}).get("scene_id", StringName(""))
            _change_music_for_scene(scene_id)
```

**Alternative**: Apply low-pass filter to current track instead of switching:
```gdscript
func _apply_pause_filter() -> void:
    var low_pass := AudioEffectLowPassFilter.new()
    low_pass.cutoff_hz = 500.0
    AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), low_pass)

func _remove_pause_filter() -> void:
    AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"), 0)
```

---

## Phase 3: BaseEventSFXSystem Pattern (Days 9-10)

### Mirror BaseEventVFXSystem

**Files to create**:
- `scripts/ecs/base_event_sfx_system.gd`
- `tests/unit/ecs/test_base_event_sfx_system.gd` (15 tests)

**Structure** (identical to BaseEventVFXSystem):
```gdscript
@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name BaseEventSFXSystem

var requests: Array = []
var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
    super._ready()
    _subscribe()

func get_event_name() -> StringName:
    # Override in subclass
    return StringName()

func create_request_from_payload(payload: Dictionary) -> Dictionary:
    # Override in subclass
    return {}

func _subscribe() -> void:
    _unsubscribe()
    requests.clear()
    var event_name := get_event_name()
    if event_name == StringName():
        return
    _unsubscribe_callable = U_ECSEventBus.subscribe(event_name, _on_event)

func _on_event(event_data: Dictionary) -> void:
    var payload := event_data.get("payload", {})
    var request := create_request_from_payload(payload)
    requests.append(request.duplicate(true))
```

---

## Phase 4: SFX Systems (Days 11-14)

### M_SFXSpawner Utility

**Files to create**:
- `scripts/managers/helpers/m_sfx_spawner.gd`
- `tests/unit/managers/helpers/test_sfx_spawner.gd` (10 tests)

**AudioStreamPlayer3D Pool**:
```gdscript
class_name M_SFXSpawner
extends RefCounted

const POOL_SIZE := 16
const META_IN_USE := &"_sfx_in_use"

static var _pool: Array[AudioStreamPlayer3D] = []
static var _container: Node3D = null

static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
    var player := _get_available_player()
    if player == null:
        push_warning("SFX pool exhausted")
        return null

    player.set_meta(META_IN_USE, true)
    player.stream = config.get("audio_stream") as AudioStream
    player.global_position = config.get("position", Vector3.ZERO)
    player.volume_db = config.get("volume_db", 0.0)
    player.pitch_scale = config.get("pitch_scale", 1.0)
    player.bus = config.get("bus", "SFX")
    player.play()

    return player
```

### Individual SFX Systems (5 systems)

**NOTE**: `S_JumpSoundSystem` exists at `scripts/ecs/systems/s_jump_sound_system.gd` and serves as reference for event-driven SFX systems.

Implement one system per commit:
1. `S_JumpSoundSystem` (entity_jumped) - **MODIFY existing stub**
2. `S_LandingSoundSystem` (entity_landed) - CREATE
3. `S_DeathSoundSystem` (entity_death) - CREATE
4. `S_CheckpointSoundSystem` (checkpoint_activated) - CREATE
5. `S_VictorySoundSystem` (victory_triggered) - CREATE

**Pattern** (example: S_JumpSoundSystem):
```gdscript
extends BaseEventSFXSystem
class_name S_JumpSoundSystem

const RS_JUMP_SOUND_SETTINGS := preload("...")
@export var settings: RS_JUMP_SOUND_SETTINGS

func get_event_name() -> StringName:
    return StringName("entity_jumped")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
    return {
        "position": payload.get("position", Vector3.ZERO),
        "jump_force": payload.get("jump_force", 0.0),
    }

func process_tick(_delta: float) -> void:
    if settings == null or not settings.enabled:
        requests.clear()
        return

    for request in requests:
        M_SFXSpawner.spawn_3d({
            "audio_stream": settings.audio_stream,
            "position": request.get("position"),
            "volume_db": settings.volume_db,
            "pitch_scale": randf_range(
                1.0 - settings.pitch_variation,
                1.0 + settings.pitch_variation
            ),
            "bus": "SFX"
        })

    requests.clear()
```

**Settings Resource Pattern**:
```gdscript
class_name RS_JumpSoundSettings
extends Resource

@export var enabled: bool = true
@export var audio_stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.1
@export var min_interval: float = 0.1
```

**Placeholder Assets** (create with Audacity: Generate > Tone):
- Jump: 440Hz, 100ms
- Land: 220Hz, 100ms
- Death: 110Hz, 150ms
- etc.

---

## Phase 5: Footstep System (Days 15-17)

### Surface Detection Component

**Files to create**:
- `scripts/ecs/components/c_surface_detector_component.gd`
- `tests/unit/ecs/components/test_surface_detector.gd` (15 tests)

**Surface Types**:
```gdscript
enum SurfaceType {
    DEFAULT,
    GRASS,
    STONE,
    WOOD,
    METAL,
    WATER
}

# Raycast-based detection
func detect_surface() -> SurfaceType:
    if not _raycast.is_colliding():
        return SurfaceType.DEFAULT

    var collider := _raycast.get_collider()
    if collider.has_meta("surface_type"):
        return collider.get_meta("surface_type")

    return SurfaceType.DEFAULT
```

### Footstep Sound System

**Files to create**:
- `scripts/ecs/systems/s_footstep_sound_system.gd`
- `scripts/ecs/resources/rs_footstep_sound_settings.gd`
- `tests/unit/ecs/systems/test_footstep_sound_system.gd` (20 tests)

**Pattern**: Per-tick system (NOT event-driven)
```gdscript
func process_tick(delta: float) -> void:
    if settings == null or not settings.enabled:
        return

    for entity in _entities:
        var surface_detector := entity.get_node("SurfaceDetector")
        var body := entity as CharacterBody3D

        # Check movement + ground contact
        if body.is_on_floor() and body.velocity.length() > 1.0:
            _time_since_step += delta

            if _time_since_step >= settings.step_interval:
                var surface := surface_detector.detect_surface()
                _play_footstep(entity.global_position, surface)
                _time_since_step = 0.0

func _play_footstep(position: Vector3, surface: SurfaceType) -> void:
    var sounds := settings.get_sounds_for_surface(surface)
    var stream := sounds.pick_random()
    M_SFXSpawner.spawn_3d({
        "audio_stream": stream,
        "position": position,
        "volume_db": settings.volume_db,
        "pitch_scale": randf_range(0.95, 1.05),
        "bus": "Footsteps"
    })
```

**Placeholder Assets** (create 24 files):
- `resources/audio/footsteps/placeholder_grass_01.wav` through `_04.wav`
- Same for stone, wood, metal, water, default (6 surfaces × 4 variations = 24 files)

---

## Phase 6: Ambient System (Days 18-19)

### Ambient Sound System

**Files to create**:
- `scripts/ecs/systems/s_ambient_sound_system.gd`
- `scripts/ecs/resources/rs_ambient_sound_settings.gd`
- `tests/unit/ecs/systems/test_ambient_sound_system.gd` (10 tests)

**Pattern**: Dual players (like music), scene-based crossfade
```gdscript
var _ambient_player_a: AudioStreamPlayer
var _ambient_player_b: AudioStreamPlayer
var _ambient_registry: Dictionary = {
    StringName("exterior"): preload("res://resources/audio/ambient/placeholder_exterior.ogg"),
    StringName("interior"): preload("res://resources/audio/ambient/placeholder_interior.ogg")
}

func _on_scene_transition(scene_id: StringName) -> void:
    var ambient_id := _get_ambient_for_scene(scene_id)
    if ambient_id != _current_ambient:
        _crossfade_ambient(ambient_id, 2.0)
```

**Placeholder Assets**:
- `placeholder_exterior.ogg` (10s silent loop)
- `placeholder_interior.ogg` (10s silent loop)

---

## Phase 7: UI Sound Integration (Days 20-21)

### U_UISoundPlayer Utility

**Files to create**:
- `scripts/managers/helpers/u_ui_sound_player.gd`
- `tests/unit/managers/helpers/test_ui_sound_player.gd` (5 tests)

**API**:
```gdscript
class_name U_UISoundPlayer
extends RefCounted

static func play_focus() -> void:
    _get_audio_manager().play_sfx(StringName("ui_focus"))

static func play_confirm() -> void:
    _get_audio_manager().play_sfx(StringName("ui_confirm"))

static func play_cancel() -> void:
    _get_audio_manager().play_sfx(StringName("ui_cancel"))

static func play_slider_tick() -> void:
    # Throttled to 10/second
    if Time.get_ticks_msec() - _last_tick_time < 100:
        return
    _get_audio_manager().play_sfx(StringName("ui_tick"))
    _last_tick_time = Time.get_ticks_msec()
```

### BasePanel Integration

**Files to modify**:
- `scripts/ui/base_panel.gd`: Add `focus_entered` signal handler
- Button handlers: Add confirm/cancel sounds
- Settings panel: Add tab switch sound
- Sliders: Add throttled tick sound

**Example**:
```gdscript
# In BasePanel
func _ready() -> void:
    focus_entered.connect(_on_focus_entered)

func _on_focus_entered() -> void:
    U_UISoundPlayer.play_focus()

# In button handlers
func _on_confirm_pressed() -> void:
    U_UISoundPlayer.play_confirm()
    # ... existing logic
```

**Placeholder Assets** (create with Audacity: Generate > Tone at high frequency):
- `placeholder_ui_focus.wav` (1000Hz, 30ms)
- `placeholder_ui_confirm.wav` (1200Hz, 50ms)
- `placeholder_ui_cancel.wav` (800Hz, 50ms)

---

## Phase 8: Audio Settings UI (Days 22-23)

### Audio Section in Accessibility Tab

**Files to create**:
- `scenes/ui/settings/audio_settings_tab.tscn`
- `scripts/ui/settings/ui_audio_settings_tab.gd`
- `tests/integration/audio/test_audio_settings_ui.gd` (10 tests)
- `tests/integration/audio/test_audio_integration.gd` (30 tests)

**Scene Structure**:
```
VBoxContainer
├── Label ("AUDIO SETTINGS")
├── HBoxContainer (Master)
│   ├── Label ("Master Volume")
│   ├── HSlider (0.0-1.0, step 0.05)
│   ├── Label (percentage)
│   └── CheckBox (mute)
├── [Same for Music, SFX, Ambient]
├── HSeparator
├── CheckBox ("Spatial Audio (3D positioning)")
```

**Auto-Save Pattern**:
```gdscript
func _on_master_volume_changed(value: float) -> void:
    if _store:
        _store.dispatch(U_AUDIO_ACTIONS.set_master_volume(value))
    _update_percentage_label(value)

func _on_master_mute_toggled(pressed: bool) -> void:
    if _store:
        _store.dispatch(U_AUDIO_ACTIONS.set_master_muted(pressed))
```

---

## Success Criteria

### Phase 0-1 Complete:
- [x] All Redux tests pass (40 tests)
- [x] Audio bus layout created correctly
- [x] Volume/mute application works
- [x] Manager registered with ServiceLocator

### Phase 2 Complete:
- [x] Music crossfades smoothly between scenes
- [x] No audio pops or clicks during transitions
- [x] Dual-player swap works correctly

### Phase 3-4 Complete:
- [ ] BaseEventSFXSystem mirrors BaseEventVFXSystem
- [ ] All 5 SFX systems play on correct events
- [ ] Pool manages 16 concurrent sounds
- [ ] Pitch variation adds organic feel

### Phase 5 Complete:
- [ ] Footsteps change based on surface
- [ ] Step timing matches movement speed
- [ ] 4 variations prevent repetition

### Phase 6 Complete:
- [ ] Ambient loops correctly
- [ ] Crossfade between scenes smooth
- [ ] Volume independent of music

### Phase 7 Complete:
- [ ] UI sounds play on focus/confirm/cancel
- [ ] Slider sounds throttled (no spam)
- [ ] Sounds play even during transitions

### Phase 8 Complete:
- [ ] All ~280 tests pass
- [ ] Settings persist to save files
- [ ] Sliders affect volume in real-time
- [ ] Mute toggles independent of volume
- [ ] No audio artifacts

---

## Common Pitfalls

1. **Music Not Looping**: Set `AudioStream.loop = true` in import settings
2. **Volume Slider Spam**: Throttle to max 10 sounds/second (100ms interval)
3. **Pool Exhaustion**: Log warnings, consider increasing POOL_SIZE if needed
4. **Spatial Audio Distance**: Set `max_distance = 50.0` on AudioStreamPlayer3D
5. **Bus Routing**: Ensure UI and Footsteps route to SFX (not Master directly)

---

## Testing Commands

```bash
# Run audio unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_audio -gexit

# Run audio integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/audio -gexit
```

---

## File Structure

```
scripts/managers/
  m_audio_manager.gd
  helpers/
    m_sfx_spawner.gd
    u_ui_sound_player.gd

scripts/ecs/
  base_event_sfx_system.gd
  systems/
    s_jump_sound_system.gd
    s_landing_sound_system.gd
    s_death_sound_system.gd
    s_checkpoint_sound_system.gd
    s_victory_sound_system.gd
    s_footstep_sound_system.gd
    s_ambient_sound_system.gd
  components/
    c_surface_detector_component.gd
  resources/
    rs_jump_sound_settings.gd
    rs_landing_sound_settings.gd
    [etc.]

scripts/state/
  resources/rs_audio_initial_state.gd
  actions/u_audio_actions.gd
  reducers/u_audio_reducer.gd
  selectors/u_audio_selectors.gd

resources/audio/
  music/
    placeholder_main_menu.ogg
    placeholder_gameplay.ogg
  sfx/
    placeholder_jump.wav
    placeholder_land.wav
    placeholder_ui_*.wav
  footsteps/
    placeholder_grass_01.wav → _04.wav
    placeholder_stone_01.wav → _04.wav
    [etc. for 6 surfaces]
  ambient/
    placeholder_exterior.ogg
    placeholder_interior.ogg
```

---

**END OF AUDIO MANAGER PLAN**
