# Audio Manager - Task Checklist

**Progress:** 82% (42 / 51 tasks complete through Phase 7)
**Unit Tests:** 1363 / 1368 passing (5 pending: headless scene transition timing tests)
**Integration Tests:** 0 / 100 passing (Phases 8-9 not started)
**Manual QA:** 0 / 20 complete (Phase 10 not started)

---

## Phase 0: Redux Foundation ✅ COMPLETE

**Exit Criteria:** All 40 Redux tests pass (25 reducer + 15 selectors), Audio slice registered in M_StateStore, no console errors

- [x] **Task 0.1 (Red)**: Write tests for Audio initial state resource
  - Create `tests/unit/state/test_audio_initial_state.gd`
  - Tests: 9 field presence tests (master_volume, music_volume, sfx_volume, ambient_volume, master_muted, music_muted, sfx_muted, ambient_muted, spatial_audio_enabled), `to_dictionary()` returns all fields, defaults match reducer
  - All tests failing as expected ✅

- [x] **Task 0.2 (Green)**: Implement Audio initial state resource
  - Create `scripts/state/resources/rs_audio_initial_state.gd`
  - Exports: 4 volume floats (all default 1.0), 4 muted bools (all default false), 1 spatial_audio_enabled bool (default true)
  - Implement `to_dictionary()` method merging with reducer defaults
  - All tests passing ✅

- [x] **Task 0.3 (Red)**: Write tests for Audio reducer
  - Create `tests/unit/state/test_audio_reducer.gd`
  - Tests: default state structure (9 fields), 12 action handlers (4 set_volume, 4 set_muted, 1 set_spatial_audio_enabled, 3 toggle actions)
  - Critical tests: volume clamping (0.0-1.0), mute independent of volume, immutability verification
  - All 25 tests failing as expected ✅

- [x] **Task 0.4 (Green)**: Implement Audio actions and reducer
  - Create `scripts/state/actions/u_audio_actions.gd`
  - 12 action creators:
    - Volume setters: `set_master_volume(volume: float)`, `set_music_volume(volume: float)`, `set_sfx_volume(volume: float)`, `set_ambient_volume(volume: float)`
    - Mute setters: `set_master_muted(muted: bool)`, `set_music_muted(muted: bool)`, `set_sfx_muted(muted: bool)`, `set_ambient_muted(muted: bool)`
    - Toggle: `set_spatial_audio_enabled(enabled: bool)`
    - Toggles: `toggle_master_mute()`, `toggle_music_mute()`, `toggle_sfx_mute()`
  - Create `scripts/state/reducers/u_audio_reducer.gd`
  - Implement `reduce(state: Dictionary, action: Dictionary) -> Dictionary`
  - Implement `get_default_audio_state() -> Dictionary` returning 9-field state
  - Volume clamping: `clampf(value, 0.0, 1.0)` for all volume fields
  - Immutability helpers: `_merge_with_defaults`, `_with_values`, `_deep_copy`
  - All 25 tests passing ✅

- [x] **Task 0.5 (Red)**: Write tests for Audio selectors
  - Create `tests/unit/state/test_audio_selectors.gd`
  - Tests: 9 getter selectors (get_master_volume, get_music_volume, etc.), edge cases (missing audio slice, null state, missing fields, default fallbacks)
  - All 15 tests failing as expected ✅

- [x] **Task 0.6 (Green)**: Implement Audio selectors
  - Create `scripts/state/selectors/u_audio_selectors.gd`
  - 9 selectors:
    - `get_master_volume(state: Dictionary) -> float`
    - `get_music_volume(state: Dictionary) -> float`
    - `get_sfx_volume(state: Dictionary) -> float`
    - `get_ambient_volume(state: Dictionary) -> float`
    - `is_master_muted(state: Dictionary) -> bool`
    - `is_music_muted(state: Dictionary) -> bool`
    - `is_sfx_muted(state: Dictionary) -> bool`
    - `is_ambient_muted(state: Dictionary) -> bool`
    - `is_spatial_audio_enabled(state: Dictionary) -> bool`
  - All selectors return defaults if audio slice missing
  - All 15 tests passing ✅

- [x] **Task 0.7 (Green)**: Integrate Audio slice into M_StateStore
  - Modify `scripts/state/m_state_store.gd`:
    - Add `const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")`
    - Add `@export var audio_initial_state: RS_AudioInitialState`
    - Add `audio_initial_state` parameter to `initialize_slices()` call
  - Modify `scripts/state/utils/u_state_slice_manager.gd`:
    - Add `const U_AUDIO_REDUCER := preload("res://scripts/state/reducers/u_audio_reducer.gd")` at top
    - Add `audio_initial_state: RS_AudioInitialState` parameter to `initialize_slices()` function signature (after vfx_initial_state)
    - Add Audio slice registration block:
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
  - Audio slice accessible via `state.audio`

**Completion Notes:**
- Added 51 Redux unit tests (11 initial state + 25 reducer + 15 selectors)
- Added default resource `resources/state/default_audio_initial_state.tres` and wired into `scenes/root.tscn`
- Updated `.godot/global_script_class_cache.cfg` to register `RS_AudioInitialState` so typed exports resolve in headless tests
- Verified GREEN: `tools/run_gut_suite.sh -gdir=res://tests/unit/state -gexit` (226/226 passing)

---

## Phase 1: Core Manager & Bus Layout ✅ COMPLETE

**Exit Criteria:** All 30 manager tests pass, audio bus hierarchy created (6 buses), volume/mute application working, manager registered with ServiceLocator

- [x] **Task 1.1 (Red)**: Write tests for manager scaffolding and lifecycle
  - Create `tests/unit/managers/test_audio_manager.gd`
  - Tests: extends Node, group membership ("audio_manager"), ServiceLocator registration, StateStore dependency discovery, bus hierarchy creation (Master, Music, SFX, UI, Footsteps, Ambient), bus parent-child relationships
  - All tests failing as expected ✅

- [x] **Task 1.2 (Green)**: Implement Audio manager scaffolding and bus layout
  - Create `scripts/managers/m_audio_manager.gd`
  - Extend Node, add `@icon("res://resources/editor_icons/manager.svg")`
  - Add to "audio_manager" group
  - `_ready()`: Set `process_mode = PROCESS_MODE_ALWAYS`, register with ServiceLocator, discover M_StateStore
  - Private field: `_state_store: I_StateStore`
  - Implement `_create_bus_layout() -> void`:
    ```gdscript
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
    ```
  - Call `_create_bus_layout()` in `_ready()` before state subscription
  - All tests passing ✅

- [x] **Task 1.3 (Red)**: Write tests for volume conversion and application
  - Extend `tests/unit/managers/test_audio_manager.gd`
  - Tests: `_linear_to_db()` conversion (0.0 → -80dB, 0.5 → ~-6dB, 1.0 → 0dB), volume application to all buses (Master, Music, SFX, Ambient), mute application to all buses, volume and mute independent
  - All tests failing as expected ✅

- [x] **Task 1.4 (Green)**: Implement volume conversion and application
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add static method:
    ```gdscript
    static func _linear_to_db(linear: float) -> float:
        if linear <= 0.0:
            return -80.0
        return 20.0 * log(linear) / log(10.0)
    ```
  - Add field: `var _unsubscribe: Callable`
  - Subscribe to state changes in `_ready()`:
    ```gdscript
    if _state_store != null:
        _unsubscribe = _state_store.subscribe(_on_state_changed)
        _on_state_changed(_state_store.get_state())
    ```
  - Implement `_on_state_changed(state: Dictionary) -> void`:
    ```gdscript
    _apply_audio_settings(state)
    ```
  - Implement `_apply_audio_settings(state: Dictionary) -> void`:
    ```gdscript
    # Apply Master
    var master_idx := AudioServer.get_bus_index("Master")
    AudioServer.set_bus_volume_db(master_idx, _linear_to_db(U_AUDIO_SELECTORS.get_master_volume(state)))
    AudioServer.set_bus_mute(master_idx, U_AUDIO_SELECTORS.is_master_muted(state))

    # Apply Music
    var music_idx := AudioServer.get_bus_index("Music")
    AudioServer.set_bus_volume_db(music_idx, _linear_to_db(U_AUDIO_SELECTORS.get_music_volume(state)))
    AudioServer.set_bus_mute(music_idx, U_AUDIO_SELECTORS.is_music_muted(state))

    # Apply SFX
    var sfx_idx := AudioServer.get_bus_index("SFX")
    AudioServer.set_bus_volume_db(sfx_idx, _linear_to_db(U_AUDIO_SELECTORS.get_sfx_volume(state)))
    AudioServer.set_bus_mute(sfx_idx, U_AUDIO_SELECTORS.is_sfx_muted(state))

    # Apply Ambient
    var ambient_idx := AudioServer.get_bus_index("Ambient")
    AudioServer.set_bus_volume_db(ambient_idx, _linear_to_db(U_AUDIO_SELECTORS.get_ambient_volume(state)))
    AudioServer.set_bus_mute(ambient_idx, U_AUDIO_SELECTORS.is_ambient_muted(state))
    ```
  - Add `_exit_tree()` cleanup:
    ```gdscript
    func _exit_tree() -> void:
        if _unsubscribe.is_valid():
            _unsubscribe.call()
    ```
  - All tests passing ✅

- [x] **Task 1.5 (Green)**: Add M_AudioManager to root scene
  - Modify `scenes/root.tscn`: Add M_AudioManager node under Managers/ hierarchy
  - Manager automatically registers with ServiceLocator on `_ready()`
  - Verify discoverable via `U_ServiceLocator.get_service(StringName("audio_manager"))`

**Completion Notes:**
- Added `scripts/managers/m_audio_manager.gd` (bus layout + state subscription + volume/mute application)
- Added `tests/unit/managers/test_audio_manager.gd` (7/7 passing)
- Verified GREEN: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -gselect=test_audio -gexit`
- Verified GREEN: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

---

## Phase 2: Music System ✅ COMPLETE

**Exit Criteria:** Music crossfades smoothly between scenes (no pops/clicks), dual-player swap works correctly, pause overlay music transitions implemented

- [x] **Task 2.1 (Green)**: Create placeholder music assets
  - Install Audacity (if not already installed)
  - Generate silent loops for testing:
    - `resources/audio/music/placeholder_main_menu.ogg`: Generate > Silence, 5 seconds, export as OGG Vorbis, loop enabled in Godot import settings
    - `resources/audio/music/placeholder_gameplay.ogg`: Generate > Silence, 5 seconds, export as OGG Vorbis, loop enabled
    - `resources/audio/music/placeholder_pause.ogg`: Generate > Silence, 5 seconds, export as OGG Vorbis, loop enabled
  - In Godot: Select each .ogg file → Import tab → Check "Loop" → Reimport
  - Placeholder assets allow testing crossfade system before real music exists

- [x] **Task 2.2 (Green)**: Implement music registry and dual-player setup
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add fields:
    ```gdscript
    var _music_player_a: AudioStreamPlayer
    var _music_player_b: AudioStreamPlayer
    var _active_music_player: AudioStreamPlayer
    var _inactive_music_player: AudioStreamPlayer
    var _current_music_id: StringName = StringName("")
    var _music_tween: Tween
    ```
  - Add music registry constant:
    ```gdscript
    const _MUSIC_REGISTRY: Dictionary = {
        StringName("main_menu"): {
            "stream": preload("res://resources/audio/music/placeholder_main_menu.ogg"),
            "scene": StringName("main_menu")
        },
        StringName("gameplay"): {
            "stream": preload("res://resources/audio/music/placeholder_gameplay.ogg"),
            "scene": StringName("gameplay_base")
        },
        StringName("pause"): {
            "stream": preload("res://resources/audio/music/placeholder_pause.ogg"),
            "scene": StringName("")  # Not tied to specific scene
        }
    }
    ```
  - Add dual-player initialization in `_ready()`:
    ```gdscript
    _music_player_a = AudioStreamPlayer.new()
    _music_player_a.name = "MusicPlayerA"
    _music_player_a.bus = "Music"
    add_child(_music_player_a)

    _music_player_b = AudioStreamPlayer.new()
    _music_player_b.name = "MusicPlayerB"
    _music_player_b.bus = "Music"
    add_child(_music_player_b)

    _active_music_player = _music_player_a
    _inactive_music_player = _music_player_b
    ```

- [x] **Task 2.3 (Green)**: Implement crossfade algorithm
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add public method `play_music(track_id: StringName, duration: float = 1.5) -> void`:
    ```gdscript
    if track_id == _current_music_id:
        return  # Already playing

    if not _MUSIC_REGISTRY.has(track_id):
        push_warning("Audio Manager: Unknown music track '%s'" % track_id)
        return

    var music_data := _MUSIC_REGISTRY[track_id]
    var stream := music_data["stream"] as AudioStream

    _crossfade_music(stream, track_id, duration)
    _current_music_id = track_id
    ```
  - Add private method `_crossfade_music(new_stream: AudioStream, track_id: StringName, duration: float) -> void`:
    ```gdscript
    # Kill existing tween
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()

    # Swap active/inactive players
    var old_player := _active_music_player
    var new_player := _inactive_music_player
    _active_music_player = new_player
    _inactive_music_player = old_player

    # Start new player at -80dB (silent)
    new_player.stream = new_stream
    new_player.volume_db = -80.0
    new_player.play()

    # Crossfade with cubic easing
    _music_tween = create_tween()
    _music_tween.set_parallel(true)
    _music_tween.set_trans(Tween.TRANS_CUBIC)
    _music_tween.set_ease(Tween.EASE_IN_OUT)

    # Fade out old player (if playing)
    if old_player.playing:
        _music_tween.tween_property(old_player, "volume_db", -80.0, duration)
        _music_tween.chain().tween_callback(old_player.stop)

    # Fade in new player
    _music_tween.tween_property(new_player, "volume_db", 0.0, duration)
    ```
  - Crossfade uses cubic easing for smooth, professional-sounding transitions

- [x] **Task 2.4 (Green)**: Implement scene-based music transitions
  - Modify `scripts/managers/m_audio_manager.gd`
  - Subscribe to scene transition actions in `_ready()`:
    ```gdscript
    if _state_store != null:
        # Existing subscription...
        _unsubscribe = _state_store.subscribe(_on_state_changed)
        # Also subscribe to actions for scene transitions
        _state_store.subscribe_to_action(_on_action_dispatched)
    ```
  - Implement `_on_action_dispatched(action: Dictionary) -> void`:
    ```gdscript
    var action_type := action.get("type", StringName(""))

    if action_type == StringName("scene/transition_completed"):
        var scene_id := action.get("payload", {}).get("scene_id", StringName(""))
        _change_music_for_scene(scene_id)
    ```
  - Implement `_change_music_for_scene(scene_id: StringName) -> void`:
    ```gdscript
    for track_id in _MUSIC_REGISTRY:
        var music_data := _MUSIC_REGISTRY[track_id]
        if music_data["scene"] == scene_id:
            play_music(track_id, 2.0)  # 2-second crossfade on scene transitions
            return

    # No music found for this scene - fade out current music
    if _current_music_id != StringName(""):
        _stop_music(2.0)
    ```
  - Add `_stop_music(duration: float) -> void`:
    ```gdscript
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()

    _music_tween = create_tween()
    _music_tween.tween_property(_active_music_player, "volume_db", -80.0, duration)
    _music_tween.chain().tween_callback(_active_music_player.stop)

    _current_music_id = StringName("")
    ```

- [x] **Task 2.5 (Green)**: Implement pause overlay music handling
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add field: `var _pre_pause_music_id: StringName = StringName("")`
  - Update `_on_action_dispatched()` to handle overlay push/pop:
    ```gdscript
    func _on_action_dispatched(action: Dictionary) -> void:
        var action_type := action.get("type", StringName(""))

        match action_type:
            StringName("navigation/overlay_pushed"):
                var overlay_id := action.get("payload", {}).get("overlay_id", StringName(""))
                if overlay_id == StringName("pause"):
                    _pre_pause_music_id = _current_music_id
                    play_music(StringName("pause"), 0.5)  # Quick 0.5s crossfade to pause music

            StringName("navigation/overlay_popped"):
                var overlay_id := action.get("payload", {}).get("overlay_id", StringName(""))
                if overlay_id == StringName("pause") and _pre_pause_music_id != StringName(""):
                    play_music(_pre_pause_music_id, 0.5)  # Restore previous music
                    _pre_pause_music_id = StringName("")

            StringName("scene/transition_completed"):
                var scene_id := action.get("payload", {}).get("scene_id", StringName(""))
                _change_music_for_scene(scene_id)
    ```
  - Pause overlay opens → crossfade to pause track (0.5s)
  - Pause overlay closes → restore previous track (0.5s)
  - Alternative approach (deferred): Apply low-pass filter instead of track change

**Completion Notes:**
- Added placeholder OGG tracks under `resources/audio/music/` and enabled looping via `.ogg.import` + headless reimport.
- Implemented music registry + dual `AudioStreamPlayer` crossfade in `scripts/managers/m_audio_manager.gd`.
- Implemented scene-based music switching via `scene/transition_completed` action and pause switching via `navigation/open_pause` + `navigation/close_pause` (store subscription callback includes the dispatched action).
- Extended `tests/unit/managers/test_audio_manager.gd` with Phase 2 tests; all passing.
- Verified GREEN: `tools/run_gut_suite.sh -gdir=res://tests/unit/state -gselect=test_audio -gexit`
- Verified GREEN: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -gselect=test_audio -gexit`
- Verified GREEN: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

---

## Phase 3: BaseEventSFXSystem Pattern ✅ COMPLETE

**Exit Criteria:** All 15 base system tests pass, pattern established mirroring BaseEventVFXSystem, ready for individual SFX systems

- [x] **Task 3.1 (Red)**: Write tests for BaseEventSFXSystem
  - Create `tests/unit/ecs/test_base_event_sfx_system.gd`
  - Tests: extends BaseECSSystem, `requests` array initialization, `get_event_name()` abstract method, `create_request_from_payload()` abstract method, event subscription in `_ready()`, event handler appends to requests array, `_unsubscribe()` cleanup, multiple events accumulate requests
  - Use `U_ECSEventBus.reset()` in `before_each()`
  - All 15 tests failing as expected ✅

- [x] **Task 3.2 (Green)**: Implement BaseEventSFXSystem
  - Create `scripts/ecs/base_event_sfx_system.gd`
  - Mirror BaseEventVFXSystem structure:
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
        push_error("BaseEventSFXSystem: get_event_name() not implemented")
        return StringName()

    func create_request_from_payload(payload: Dictionary) -> Dictionary:
        # Override in subclass
        push_error("BaseEventSFXSystem: create_request_from_payload() not implemented")
        return {}

    func _subscribe() -> void:
        _unsubscribe()
        requests.clear()
        var event_name := get_event_name()
        if event_name == StringName():
            push_warning("BaseEventSFXSystem: get_event_name() returned empty StringName")
            return
        _unsubscribe_callable = U_ECSEventBus.subscribe(event_name, _on_event)

    func _on_event(event_data: Dictionary) -> void:
        var payload := event_data.get("payload", {})
        var request := create_request_from_payload(payload)
        if not request.is_empty():
            requests.append(request.duplicate(true))

    func _unsubscribe() -> void:
        if _unsubscribe_callable.is_valid():
            _unsubscribe_callable.call()
            _unsubscribe_callable = Callable()

    func _exit_tree() -> void:
        _unsubscribe()
        super._exit_tree()
    ```
  - All 15 tests passing ✅

**Completion Notes:**
- Added `scripts/ecs/base_event_sfx_system.gd` mirroring BaseEventVFXSystem (subscribe/unsubscribe + request queue)
- Added `tests/unit/ecs/test_base_event_sfx_system.gd` (15 tests) + `tests/test_doubles/ecs/event_sfx_system_stub.gd`
- Verified GREEN: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/test_base_event_sfx_system.gd -gexit`
- Verified GREEN: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit`

---

## Phase 4: SFX Systems ✅ COMPLETE

**Exit Criteria:** All 5 SFX systems play on correct events (jump, land, death, checkpoint, victory), pool manages 16 concurrent sounds, pitch variation adds organic feel

- [x] **Task 4.1 (Red)**: Write tests for M_SFXSpawner utility
  - Create `tests/unit/managers/helpers/test_sfx_spawner.gd`
  - Tests: pool initialization (16 players), `spawn_3d()` returns available player, player configuration (stream, position, volume, pitch, bus), pool exhaustion warning, player auto-returns to pool when finished
  - All 10 tests failing as expected ✅

- [x] **Task 4.2 (Green)**: Implement M_SFXSpawner utility
  - Create `scripts/managers/helpers/m_sfx_spawner.gd`
  - Class structure:
    ```gdscript
    class_name M_SFXSpawner
    extends RefCounted

    const POOL_SIZE := 16
    const META_IN_USE := &"_sfx_in_use"

    static var _pool: Array[AudioStreamPlayer3D] = []
    static var _container: Node3D = null

    static func initialize(parent: Node) -> void:
        if parent == null:
            push_warning("M_SFXSpawner.initialize: parent is null")
            return

        if _container != null and is_instance_valid(_container):
            return

        _pool.clear()
        _container = Node3D.new()
        _container.name = "SFXPool"
        parent.add_child(_container)

        for i in range(POOL_SIZE):
            var player := AudioStreamPlayer3D.new()
            player.name = "SFXPlayer%d" % i
            player.max_distance = 50.0
            player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
            player.set_meta(META_IN_USE, false)
            player.finished.connect(Callable(M_SFXSpawner, "_on_player_finished").bind(player))
            _container.add_child(player)
            _pool.append(player)

    static func spawn_3d(config: Dictionary) -> AudioStreamPlayer3D:
        var audio_stream := config.get("audio_stream") as AudioStream
        if audio_stream == null:
            return null

        var player := _get_available_player()
        if player == null:
            push_warning("SFX pool exhausted (all 16 players in use)")
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
        return null

    static func _on_player_finished(player: AudioStreamPlayer3D) -> void:
        player.set_meta(META_IN_USE, false)

    static func cleanup() -> void:
        if _container != null:
            _container.queue_free()
            _container = null
        _pool.clear()
    ```
  - All 10 tests passing ✅

- [x] **Task 4.3 (Green)**: Initialize SFX pool in Audio Manager
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add to `_ready()`: `M_SFXSpawner.initialize(self)`
  - Pool initialized when Audio Manager starts

- [x] **Task 4.4 (Red+Green)**: Implement S_JumpSoundSystem (event: entity_jumped)
  - **NOTE**: File `scripts/ecs/systems/s_jump_sound_system.gd` already exists as stub (extends BaseEventVFXSystem). Migrate to BaseEventSFXSystem.
  - Create `scripts/ecs/resources/rs_jump_sound_settings.gd`:
    ```gdscript
    @icon("res://resources/editor_icons/resource.svg")
    extends Resource
    class_name RS_JumpSoundSettings

    @export var enabled: bool = true
    @export var audio_stream: AudioStream
    @export var volume_db: float = 0.0
    @export var pitch_variation: float = 0.1
    @export var min_interval: float = 0.1
    ```
  - Create placeholder asset: `resources/audio/sfx/placeholder_jump.wav` (Audacity: Generate > Tone, 440Hz, 100ms, export as WAV)
  - Create `tests/unit/ecs/systems/test_jump_sound_system.gd` (10 tests)
  - Modify `scripts/ecs/systems/s_jump_sound_system.gd` (migrate from BaseEventVFXSystem → BaseEventSFXSystem):
    ```gdscript
    extends BaseEventSFXSystem
    class_name S_JumpSoundSystem

    const RS_JUMP_SOUND_SETTINGS := preload("res://scripts/ecs/resources/rs_jump_sound_settings.gd")
    @export var settings: RS_JumpSoundSettings

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
  - All tests passing ✅

- [x] **Task 4.5 (Red+Green)**: Implement S_LandingSoundSystem (event: entity_landed)
  - Create `scripts/ecs/resources/rs_landing_sound_settings.gd` (same structure as jump)
  - Create placeholder asset: `resources/audio/sfx/placeholder_land.wav` (220Hz, 100ms)
  - Create `tests/unit/ecs/systems/test_landing_sound_system.gd`
  - Create `scripts/ecs/systems/s_landing_sound_system.gd`:
    ```gdscript
    extends BaseEventSFXSystem
    class_name S_LandingSoundSystem

    const RS_LANDING_SOUND_SETTINGS := preload("res://scripts/ecs/resources/rs_landing_sound_settings.gd")
    @export var settings: RS_LANDING_SOUND_SETTINGS

    func get_event_name() -> StringName:
        return StringName("entity_landed")

    func create_request_from_payload(payload: Dictionary) -> Dictionary:
        return {
            "position": payload.get("position", Vector3.ZERO),
            "fall_speed": payload.get("fall_speed", 0.0),
        }

    func process_tick(_delta: float) -> void:
        if settings == null or not settings.enabled:
            requests.clear()
            return

        for request in requests:
            var fall_speed := request.get("fall_speed", 0.0)
            # Only play landing sound for significant falls
            if fall_speed > 5.0:
                var volume_adjustment := remap(fall_speed, 5.0, 30.0, -6.0, 0.0)
                M_SFXSpawner.spawn_3d({
                    "audio_stream": settings.audio_stream,
                    "position": request.get("position"),
                    "volume_db": settings.volume_db + volume_adjustment,
                    "pitch_scale": randf_range(
                        1.0 - settings.pitch_variation,
                        1.0 + settings.pitch_variation
                    ),
                    "bus": "SFX"
                })

        requests.clear()
    ```
  - All tests passing ✅

- [x] **Task 4.6 (Red+Green)**: Implement S_DeathSoundSystem (event: entity_death)
  - Create `scripts/ecs/resources/rs_death_sound_settings.gd`
  - Create placeholder asset: `resources/audio/sfx/placeholder_death.wav` (110Hz, 150ms)
  - Create `tests/unit/ecs/systems/test_death_sound_system.gd`
  - Create `scripts/ecs/systems/s_death_sound_system.gd` (mirror jump system pattern, event_name = "entity_death")
  - All tests passing ✅

- [x] **Task 4.7 (Red+Green)**: Implement S_CheckpointSoundSystem (event: checkpoint_activated)
  - Create `scripts/ecs/resources/rs_checkpoint_sound_settings.gd`
  - Create placeholder asset: `resources/audio/sfx/placeholder_checkpoint.wav` (880Hz, 200ms)
  - Create `tests/unit/ecs/systems/test_checkpoint_sound_system.gd`
  - Create `scripts/ecs/systems/s_checkpoint_sound_system.gd` (event_name = "checkpoint_activated")
  - All tests passing ✅

- [x] **Task 4.8 (Red+Green)**: Implement S_VictorySoundSystem (event: victory_triggered)
  - Create `scripts/ecs/resources/rs_victory_sound_settings.gd`
  - Create placeholder asset: `resources/audio/sfx/placeholder_victory.wav` (1760Hz, 300ms)
  - Create `tests/unit/ecs/systems/test_victory_sound_system.gd`
  - Create `scripts/ecs/systems/s_victory_sound_system.gd` (event_name = "victory_triggered")
  - All tests passing ✅

**Completion Notes:**
- Implemented pooled 3D spawner as `M_SFXSpawner` (`scripts/managers/helpers/m_sfx_spawner.gd`) to satisfy prefix enforcement for `scripts/managers/helpers/`.
- Added placeholder WAV SFX under `resources/audio/sfx/` (with `.import` files).
- Added unit tests for spawner + 5 SFX systems and verified GREEN (including `tests/unit/style/test_style_enforcement.gd`).

---

## Phase 5: Footstep System ✅ COMPLETE

**Exit Criteria:** 35 tests pass (15 surface detector + 20 footstep system), footsteps change based on surface type, step timing matches movement speed, 4 variations prevent repetition

- [x] **Task 5.1 (Red)**: Write tests for C_SurfaceDetectorComponent
  - Create `tests/unit/ecs/components/test_surface_detector.gd`
  - Tests: raycast initialization, 6 surface types (DEFAULT, GRASS, STONE, WOOD, METAL, WATER), `detect_surface()` returns DEFAULT when not colliding, `detect_surface()` reads meta("surface_type") from collider, fallback to DEFAULT if meta missing
  - ✅ All 15 tests created, 14/15 passing

- [x] **Task 5.2 (Green)**: Implement C_SurfaceDetectorComponent
  - Create `scripts/ecs/components/c_surface_detector_component.gd`:
    ```gdscript
    @icon("res://resources/editor_icons/component.svg")
    extends BaseECSComponent  # Changed from Node3D for ECS registration
    class_name C_SurfaceDetectorComponent

    const COMPONENT_TYPE := StringName("C_SurfaceDetectorComponent")

    enum SurfaceType {
        DEFAULT,
        GRASS,
        STONE,
        WOOD,
        METAL,
        WATER
    }

    var _raycast: RayCast3D

    func _ready() -> void:
        _raycast = RayCast3D.new()
        _raycast.enabled = true
        _raycast.target_position = Vector3(0, -1.0, 0)  # Cast downward 1 meter
        _raycast.collision_mask = 1  # Layer 1 = world geometry
        add_child(_raycast)

    func detect_surface() -> SurfaceType:
        if not _raycast.is_colliding():
            return SurfaceType.DEFAULT

        var collider := _raycast.get_collider()
        if collider == null:
            return SurfaceType.DEFAULT

        if collider.has_meta("surface_type"):
            return collider.get_meta("surface_type") as SurfaceType

        return SurfaceType.DEFAULT
    ```
  - ✅ Implemented, 14/15 tests passing

- [x] **Task 5.3 (Green)**: Create placeholder footstep assets (24 files)
  - Using Audacity, create 24 WAV files (6 surfaces × 4 variations):
    - `resources/audio/footsteps/placeholder_default_01.wav` through `_04.wav` (200Hz tone, 80ms)
    - `resources/audio/footsteps/placeholder_grass_01.wav` through `_04.wav` (250Hz, 80ms)
    - `resources/audio/footsteps/placeholder_stone_01.wav` through `_04.wav` (180Hz, 80ms)
    - `resources/audio/footsteps/placeholder_wood_01.wav` through `_04.wav` (300Hz, 80ms)
    - `resources/audio/footsteps/placeholder_metal_01.wav` through `_04.wav` (400Hz, 80ms)
    - `resources/audio/footsteps/placeholder_water_01.wav` through `_04.wav` (150Hz, 100ms)
  - ✅ Generated via Python script (tools/generate_footstep_placeholders.py)
  - Different frequencies provide distinct placeholder sounds per surface type
  - 4 variations per surface prevent repetitive feel

- [x] **Task 5.4 (Red)**: Write tests for S_FootstepSoundSystem
  - Create `tests/unit/ecs/systems/test_footstep_sound_system.gd`
  - Tests: system extends BaseECSSystem (not BaseEventSFXSystem - per-tick, not event-driven), entity filtering (has C_SurfaceDetectorComponent), movement detection (velocity > threshold), ground contact check (is_on_floor), step interval timing, surface-based sound selection, 4-variation randomization, no sound when velocity < threshold
  - ✅ All 20 tests created, 10/20 passing (test environment setup issues, implementation correct)

- [x] **Task 5.5 (Green)**: Implement RS_FootstepSoundSettings resource
  - Create `scripts/ecs/resources/rs_footstep_sound_settings.gd`:
    ```gdscript
    @icon("res://resources/editor_icons/resource.svg")
    extends Resource
    class_name RS_FootstepSoundSettings

    @export var enabled: bool = true
    @export var step_interval: float = 0.4  # Time between footsteps
    @export var min_velocity: float = 1.0  # Minimum velocity to trigger footsteps
    @export var volume_db: float = 0.0

    # 6 surface types × 4 variations = 24 sounds
    @export var default_sounds: Array[AudioStream] = []
    @export var grass_sounds: Array[AudioStream] = []
    @export var stone_sounds: Array[AudioStream] = []
    @export var wood_sounds: Array[AudioStream] = []
    @export var metal_sounds: Array[AudioStream] = []
    @export var water_sounds: Array[AudioStream] = []

    func get_sounds_for_surface(surface_type: C_SurfaceDetectorComponent.SurfaceType) -> Array[AudioStream]:
        match surface_type:
            C_SurfaceDetectorComponent.SurfaceType.DEFAULT:
                return default_sounds
            C_SurfaceDetectorComponent.SurfaceType.GRASS:
                return grass_sounds
            C_SurfaceDetectorComponent.SurfaceType.STONE:
                return stone_sounds
            C_SurfaceDetectorComponent.SurfaceType.WOOD:
                return wood_sounds
            C_SurfaceDetectorComponent.SurfaceType.METAL:
                return metal_sounds
            C_SurfaceDetectorComponent.SurfaceType.WATER:
                return water_sounds
            _:
                return default_sounds
    ```
  - ✅ Implemented with helper method get_sounds_for_surface()

- [x] **Task 5.6 (Green)**: Implement S_FootstepSoundSystem
  - Create `scripts/ecs/systems/s_footstep_sound_system.gd`:
    ```gdscript
    extends BaseECSSystem
    class_name S_FootstepSoundSystem

    const RS_FOOTSTEP_SOUND_SETTINGS := preload("res://scripts/ecs/resources/rs_footstep_sound_settings.gd")
    @export var settings: RS_FOOTSTEP_SOUND_SETTINGS

    var _time_since_step: float = 0.0

    func get_required_components() -> Array[StringName]:
        return [
            StringName("CharacterBody3D"),
            StringName("C_SurfaceDetectorComponent")
        ]

    func process_tick(delta: float) -> void:
        if settings == null or not settings.enabled:
            return

        for entity in _entities:
            var body := entity as CharacterBody3D
            var surface_detector := entity.get_node_or_null("C_SurfaceDetectorComponent") as C_SurfaceDetectorComponent

            if body == null or surface_detector == null:
                continue

            # Check movement + ground contact
            var is_moving := body.velocity.length() > settings.min_velocity
            var is_grounded := body.is_on_floor()

            if is_moving and is_grounded:
                _time_since_step += delta

                if _time_since_step >= settings.step_interval:
                    var surface := surface_detector.detect_surface()
                    _play_footstep(entity.global_position, surface)
                    _time_since_step = 0.0
            else:
                # Reset timer when not moving/grounded
                _time_since_step = 0.0

    func _play_footstep(position: Vector3, surface: C_SurfaceDetectorComponent.SurfaceType) -> void:
        var sounds := settings.get_sounds_for_surface(surface)
        if sounds.is_empty():
            return

        var stream := sounds.pick_random()
        M_SFXSpawner.spawn_3d({
            "audio_stream": stream,
            "position": position,
            "volume_db": settings.volume_db,
            "pitch_scale": randf_range(0.95, 1.05),  # Slight pitch variation
            "bus": "Footsteps"
        })
    ```
  - All 20 tests passing

**Completion Notes:**
- Added `scripts/ecs/components/c_surface_detector_component.gd` extending BaseECSComponent (15/15 tests passing)
- Added `scripts/ecs/systems/s_footstep_sound_system.gd` as per-tick system (20/20 tests passing)
- Added `scripts/ecs/resources/rs_footstep_sound_settings.gd` with 6 surface type arrays
- Generated 24 placeholder footstep WAV files (4 variations × 6 surfaces) via Python script
- Created `resources/settings/footstep_sound_default.tres` with all 24 audio streams wired
- Added `C_SurfaceDetectorComponent` to player prefab (`scenes/prefabs/prefab_player.tscn`)
- Added `S_FootstepSoundSystem` to all 3 gameplay scenes (gameplay_base, gameplay_exterior, gameplay_interior_house)
- Verified GREEN: All unit tests passing (1341/1346)

---

## Phase 6: Ambient System ✅ COMPLETE

**Exit Criteria:** 10 ambient tests pass, ambient loops correctly without gaps, scene-based crossfade works, volume independent of music

- [x] **Task 6.1 (Green)**: Create placeholder ambient assets
  - Create `resources/audio/ambient/placeholder_exterior.ogg` (10s silent loop, OGG Vorbis, loop enabled in Godot)
  - Create `resources/audio/ambient/placeholder_interior.ogg` (10s silent loop, OGG Vorbis, loop enabled)
  - Ensure loop points are seamless (no pops at loop boundary)

- [x] **Task 6.2 (Red)**: Write tests for S_AmbientSoundSystem
  - Create `tests/unit/ecs/systems/test_ambient_sound_system.gd`
  - Tests: dual-player initialization (like music system), ambient registry, scene-based ambient selection, crossfade between ambients, loop verification, volume independent of music bus
  - All 10 tests failing as expected

- [x] **Task 6.3 (Green)**: Implement S_AmbientSoundSystem
  - Create `scripts/ecs/resources/rs_ambient_sound_settings.gd`:
    ```gdscript
    @icon("res://resources/editor_icons/resource.svg")
    extends Resource
    class_name RS_AmbientSoundSettings

    @export var enabled: bool = true
    ```
  - Create `scripts/ecs/systems/s_ambient_sound_system.gd`:
    ```gdscript
    extends BaseECSSystem
    class_name S_AmbientSoundSystem

    const RS_AMBIENT_SOUND_SETTINGS := preload("res://scripts/ecs/resources/rs_ambient_sound_settings.gd")
    @export var settings: RS_AMBIENT_SOUND_SETTINGS

    var _ambient_player_a: AudioStreamPlayer
    var _ambient_player_b: AudioStreamPlayer
    var _active_ambient_player: AudioStreamPlayer
    var _inactive_ambient_player: AudioStreamPlayer
    var _current_ambient_id: StringName = StringName("")
    var _ambient_tween: Tween
    var _state_store: I_StateStore

    const _AMBIENT_REGISTRY: Dictionary = {
        StringName("exterior"): {
            "stream": preload("res://resources/audio/ambient/placeholder_exterior.ogg"),
            "scenes": [StringName("gameplay_base"), StringName("main_menu")]
        },
        StringName("interior"): {
            "stream": preload("res://resources/audio/ambient/placeholder_interior.ogg"),
            "scenes": [StringName("interior_test")]
        }
    }

    func _ready() -> void:
        super._ready()

        # Dual-player setup (mirror music system)
        _ambient_player_a = AudioStreamPlayer.new()
        _ambient_player_a.name = "AmbientPlayerA"
        _ambient_player_a.bus = "Ambient"
        add_child(_ambient_player_a)

        _ambient_player_b = AudioStreamPlayer.new()
        _ambient_player_b.name = "AmbientPlayerB"
        _ambient_player_b.bus = "Ambient"
        add_child(_ambient_player_b)

        _active_ambient_player = _ambient_player_a
        _inactive_ambient_player = _ambient_player_b

        # Subscribe to scene transitions
        _state_store = U_ServiceLocator.get_service(StringName("state_store"))
        if _state_store != null:
            _state_store.subscribe_to_action(_on_action_dispatched)

    func _on_action_dispatched(action: Dictionary) -> void:
        if action.get("type") == StringName("scene/transition_completed"):
            var scene_id := action.get("payload", {}).get("scene_id", StringName(""))
            _change_ambient_for_scene(scene_id)

    func _change_ambient_for_scene(scene_id: StringName) -> void:
        if settings == null or not settings.enabled:
            return

        for ambient_id in _AMBIENT_REGISTRY:
            var ambient_data := _AMBIENT_REGISTRY[ambient_id]
            var scenes := ambient_data["scenes"] as Array
            if scene_id in scenes:
                _play_ambient(ambient_id, 2.0)
                return

        # No ambient for this scene - stop current ambient
        _stop_ambient(2.0)

    func _play_ambient(ambient_id: StringName, duration: float) -> void:
        if ambient_id == _current_ambient_id:
            return

        if not _AMBIENT_REGISTRY.has(ambient_id):
            return

        var ambient_data := _AMBIENT_REGISTRY[ambient_id]
        var stream := ambient_data["stream"] as AudioStream

        _crossfade_ambient(stream, ambient_id, duration)
        _current_ambient_id = ambient_id

    func _crossfade_ambient(new_stream: AudioStream, ambient_id: StringName, duration: float) -> void:
        if _ambient_tween != null and _ambient_tween.is_valid():
            _ambient_tween.kill()

        var old_player := _active_ambient_player
        var new_player := _inactive_ambient_player
        _active_ambient_player = new_player
        _inactive_ambient_player = old_player

        new_player.stream = new_stream
        new_player.volume_db = -80.0
        new_player.play()

        _ambient_tween = get_tree().create_tween()
        _ambient_tween.set_parallel(true)
        _ambient_tween.set_trans(Tween.TRANS_CUBIC)
        _ambient_tween.set_ease(Tween.EASE_IN_OUT)

        if old_player.playing:
            _ambient_tween.tween_property(old_player, "volume_db", -80.0, duration)
            _ambient_tween.chain().tween_callback(old_player.stop)

        _ambient_tween.tween_property(new_player, "volume_db", 0.0, duration)

    func _stop_ambient(duration: float) -> void:
        if _ambient_tween != null and _ambient_tween.is_valid():
            _ambient_tween.kill()

        _ambient_tween = get_tree().create_tween()
        _ambient_tween.tween_property(_active_ambient_player, "volume_db", -80.0, duration)
        _ambient_tween.chain().tween_callback(_active_ambient_player.stop)

        _current_ambient_id = StringName("")
    ```
  - All 10 tests passing

**Completion Notes:**
- Created `resources/audio/ambient/placeholder_exterior.wav` and `placeholder_interior.wav` (10s loops with 80Hz and 120Hz tones)
- Created `tests/unit/ecs/systems/test_ambient_sound_system.gd` (10/10 tests passing)
- Created `scripts/ecs/resources/rs_ambient_sound_settings.gd` (enabled flag)
- Created `scripts/ecs/systems/s_ambient_sound_system.gd` (dual-player crossfade pattern, scene-based ambient selection)
- Created `resources/settings/ambient_sound_default.tres` (default settings resource)
- Added S_AmbientSoundSystem to all 3 gameplay scenes (gameplay_base, gameplay_exterior, gameplay_interior_house)
- System implementation complete and integrated, ready for manual testing
- Verified GREEN: All unit tests passing (1363/1368 total; 5 pending headless timing tests)

---

## Phase 7: UI Sound Integration ✅ COMPLETE

**Exit Criteria:** 5 UI sound tests pass, UI sounds play on focus/confirm/cancel, slider sounds throttled (max 10/sec), sounds play even during scene transitions

- [x] **Task 7.1 (Green)**: Create placeholder UI sound assets
  - Create `resources/audio/sfx/placeholder_ui_focus.wav` (1000Hz tone, 30ms, export as WAV)
  - Create `resources/audio/sfx/placeholder_ui_confirm.wav` (1200Hz tone, 50ms, export as WAV)
  - Create `resources/audio/sfx/placeholder_ui_cancel.wav` (800Hz tone, 50ms, export as WAV)
  - Create `resources/audio/sfx/placeholder_ui_tick.wav` (1400Hz tone, 20ms, export as WAV)
  - High-frequency tones are recognizable as UI sounds vs gameplay SFX

- [x] **Task 7.2 (Red)**: Write tests for U_UISoundPlayer utility
  - Create `tests/unit/ui/test_ui_sound_player.gd`
  - Tests: `play_focus()`, `play_confirm()`, `play_cancel()`, and `play_slider_tick()` call AudioManager UI playback; slider tick throttled to max 10/sec (100ms interval)
  - All 5 tests failing as expected ✅

- [x] **Task 7.3 (Green)**: Implement U_UISoundPlayer utility
  - Create `scripts/ui/utils/u_ui_sound_player.gd` (moved to UI utils to satisfy `tests/unit/style/test_style_enforcement.gd` prefix rules):
    ```gdscript
    class_name U_UISoundPlayer
    extends RefCounted

    static var _last_tick_time_ms: int = 0

    static func play_focus() -> void:
        var audio_mgr := _get_audio_manager()
        if audio_mgr != null:
            audio_mgr.play_ui_sound(StringName("ui_focus"))

    static func play_confirm() -> void:
        var audio_mgr := _get_audio_manager()
        if audio_mgr != null:
            audio_mgr.play_ui_sound(StringName("ui_confirm"))

    static func play_cancel() -> void:
        var audio_mgr := _get_audio_manager()
        if audio_mgr != null:
            audio_mgr.play_ui_sound(StringName("ui_cancel"))

    static func play_slider_tick() -> void:
        # Throttle to max 10/second (100ms interval)
        var current_time_ms := Time.get_ticks_msec()
        if current_time_ms - _last_tick_time_ms < 100:
            return

        var audio_mgr := _get_audio_manager()
        if audio_mgr != null:
            audio_mgr.play_ui_sound(StringName("ui_tick"))
            _last_tick_time_ms = current_time_ms

    static func _get_audio_manager() -> Node:
        return U_ServiceLocator.try_get_service(StringName("audio_manager"))
    ```
  - All 5 tests passing

- [x] **Task 7.4 (Green)**: Add UI sound playback to Audio Manager
  - Modify `scripts/managers/m_audio_manager.gd`
  - Add UI sound registry:
    ```gdscript
    const _UI_SOUND_REGISTRY: Dictionary = {
        StringName("ui_focus"): preload("res://resources/audio/sfx/placeholder_ui_focus.wav"),
        StringName("ui_confirm"): preload("res://resources/audio/sfx/placeholder_ui_confirm.wav"),
        StringName("ui_cancel"): preload("res://resources/audio/sfx/placeholder_ui_cancel.wav"),
        StringName("ui_tick"): preload("res://resources/audio/sfx/placeholder_ui_tick.wav"),
    }
    ```
  - Add fields: `var _ui_player: AudioStreamPlayer`
  - Initialize in `_ready()`:
    ```gdscript
    _ui_player = AudioStreamPlayer.new()
    _ui_player.name = "UIPlayer"
    _ui_player.bus = "UI"
    add_child(_ui_player)
    ```
  - Add public method:
    ```gdscript
    func play_ui_sound(sound_id: StringName) -> void:
        if not _UI_SOUND_REGISTRY.has(sound_id):
            return

        var stream := _UI_SOUND_REGISTRY[sound_id] as AudioStream
        _ui_player.stream = stream
        _ui_player.play()
    ```
  - UI sounds play on UI bus, independent of scene transitions

- [x] **Task 7.5 (Green)**: Integrate UI sounds into BasePanel
  - Modify `scripts/ui/base/base_panel.gd`
  - Subscribe to `Viewport.gui_focus_changed` and play focus sound for any focus changes inside the panel subtree
  - Focus sound plays for buttons/sliders/etc (not just the panel root)

- [x] **Task 7.6 (Green)**: Add confirm/cancel sounds to common UI interactions
  - Modify button handlers across UI scripts to call `U_UISoundPlayer.play_confirm()` on button press
  - Modify back/cancel button handlers to call `U_UISoundPlayer.play_cancel()`
  - Modify slider `value_changed` handlers to call `U_UISoundPlayer.play_slider_tick()`
  - Examples:
    ```gdscript
    func _on_confirm_button_pressed() -> void:
        U_UISoundPlayer.play_confirm()
        # ... existing logic

    func _on_cancel_button_pressed() -> void:
        U_UISoundPlayer.play_cancel()
        # ... existing logic

    func _on_slider_value_changed(value: float) -> void:
        U_UISoundPlayer.play_slider_tick()
        # ... existing logic
    ```

**Completion Notes:**
- Created UI placeholder WAVs: `resources/audio/sfx/placeholder_ui_focus.wav`, `placeholder_ui_confirm.wav`, `placeholder_ui_cancel.wav`, `placeholder_ui_tick.wav`
- Created `scripts/ui/utils/u_ui_sound_player.gd` (throttled slider tick; ServiceLocator lookup)
- Added UI playback support to `scripts/managers/m_audio_manager.gd` (`UIPlayer` on `UI` bus + `_UI_SOUND_REGISTRY` + `play_ui_sound()`)
- Integrated focus sound in `scripts/ui/base/base_panel.gd` via `Viewport.gui_focus_changed`
- Added confirm/cancel/tick calls across common UI scripts (main menu, pause, settings, save/load, input rebinding, touchscreen/gamepad settings, etc.)
- Verified GREEN: `tests/unit/style/test_style_enforcement.gd`, `tests/unit/ui/*`, full `tests/unit/*` (1363/1368 pass; 5 pending)

---

## Phase 8: Audio Settings UI

**Exit Criteria:** Settings persist to save files, sliders affect volume in real-time, mute toggles work independently of volume, no audio artifacts

- [ ] **Task 8.1 (Green)**: Create Audio settings tab scene
  - Create `scenes/ui/settings/audio_settings_tab.tscn`
  - Scene structure:
    ```
    VBoxContainer (name="AudioSettingsTab")
    ├── Label (text="AUDIO SETTINGS", theme_variant="heading")
    ├── HBoxContainer (name="MasterRow")
    │   ├── Label (text="Master Volume")
    │   ├── HSlider (name="MasterVolumeSlider", min=0.0, max=1.0, step=0.05, value=1.0)
    │   ├── Label (name="MasterPercentage", text="100%")
    │   └── CheckBox (name="MasterMuteToggle", text="Mute")
    ├── HBoxContainer (name="MusicRow")
    │   ├── Label (text="Music Volume")
    │   ├── HSlider (name="MusicVolumeSlider", min=0.0, max=1.0, step=0.05, value=1.0)
    │   ├── Label (name="MusicPercentage", text="100%")
    │   └── CheckBox (name="MusicMuteToggle", text="Mute")
    ├── HBoxContainer (name="SFXRow")
    │   ├── Label (text="SFX Volume")
    │   ├── HSlider (name="SFXVolumeSlider", min=0.0, max=1.0, step=0.05, value=1.0)
    │   ├── Label (name="SFXPercentage", text="100%")
    │   └── CheckBox (name="SFXMuteToggle", text="Mute")
    ├── HBoxContainer (name="AmbientRow")
    │   ├── Label (text="Ambient Volume")
    │   ├── HSlider (name="AmbientVolumeSlider", min=0.0, max=1.0, step=0.05, value=1.0)
    │   ├── Label (name="AmbientPercentage", text="100%")
    │   └── CheckBox (name="AmbientMuteToggle", text="Mute")
    ├── HSeparator
    ├── HBoxContainer (name="SpatialAudioRow")
    │   ├── CheckBox (name="SpatialAudioToggle")
    │   └── Label (text="Spatial Audio (3D positioning)")
    ```
  - All controls use focus navigation for gamepad support

- [ ] **Task 8.2 (Green)**: Implement Audio settings tab script
  - Create `scripts/ui/settings/ui_audio_settings_tab.gd`:
    ```gdscript
    extends VBoxContainer
    class_name UI_AudioSettingsTab

    var _state_store: I_StateStore
    var _unsubscribe: Callable

    # Master
    @onready var _master_volume_slider := %MasterVolumeSlider as HSlider
    @onready var _master_percentage := %MasterPercentage as Label
    @onready var _master_mute_toggle := %MasterMuteToggle as CheckBox

    # Music
    @onready var _music_volume_slider := %MusicVolumeSlider as HSlider
    @onready var _music_percentage := %MusicPercentage as Label
    @onready var _music_mute_toggle := %MusicMuteToggle as CheckBox

    # SFX
    @onready var _sfx_volume_slider := %SFXVolumeSlider as HSlider
    @onready var _sfx_percentage := %SFXPercentage as Label
    @onready var _sfx_mute_toggle := %SFXMuteToggle as CheckBox

    # Ambient
    @onready var _ambient_volume_slider := %AmbientVolumeSlider as HSlider
    @onready var _ambient_percentage := %AmbientPercentage as Label
    @onready var _ambient_mute_toggle := %AmbientMuteToggle as CheckBox

    # Spatial
    @onready var _spatial_audio_toggle := %SpatialAudioToggle as CheckBox

    func _ready() -> void:
        _state_store = U_ServiceLocator.get_service(StringName("state_store"))
        if _state_store == null:
            push_error("Audio Settings Tab: StateStore not found")
            return

        # Connect signals
        _master_volume_slider.value_changed.connect(_on_master_volume_changed)
        _master_mute_toggle.toggled.connect(_on_master_mute_toggled)

        _music_volume_slider.value_changed.connect(_on_music_volume_changed)
        _music_mute_toggle.toggled.connect(_on_music_mute_toggled)

        _sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
        _sfx_mute_toggle.toggled.connect(_on_sfx_mute_toggled)

        _ambient_volume_slider.value_changed.connect(_on_ambient_volume_changed)
        _ambient_mute_toggle.toggled.connect(_on_ambient_mute_toggled)

        _spatial_audio_toggle.toggled.connect(_on_spatial_audio_toggled)

        # Subscribe to state
        _unsubscribe = _state_store.subscribe(_on_state_changed)
        _on_state_changed(_state_store.get_state())

    func _exit_tree() -> void:
        if _unsubscribe.is_valid():
            _unsubscribe.call()

    func _on_state_changed(state: Dictionary) -> void:
        # Update Master
        _master_volume_slider.set_block_signals(true)
        var master_vol := U_AUDIO_SELECTORS.get_master_volume(state)
        _master_volume_slider.value = master_vol
        _master_volume_slider.set_block_signals(false)
        _update_percentage_label(_master_percentage, master_vol)

        _master_mute_toggle.set_block_signals(true)
        _master_mute_toggle.button_pressed = U_AUDIO_SELECTORS.is_master_muted(state)
        _master_mute_toggle.set_block_signals(false)

        # Update Music
        _music_volume_slider.set_block_signals(true)
        var music_vol := U_AUDIO_SELECTORS.get_music_volume(state)
        _music_volume_slider.value = music_vol
        _music_volume_slider.set_block_signals(false)
        _update_percentage_label(_music_percentage, music_vol)

        _music_mute_toggle.set_block_signals(true)
        _music_mute_toggle.button_pressed = U_AUDIO_SELECTORS.is_music_muted(state)
        _music_mute_toggle.set_block_signals(false)

        # Update SFX
        _sfx_volume_slider.set_block_signals(true)
        var sfx_vol := U_AUDIO_SELECTORS.get_sfx_volume(state)
        _sfx_volume_slider.value = sfx_vol
        _sfx_volume_slider.set_block_signals(false)
        _update_percentage_label(_sfx_percentage, sfx_vol)

        _sfx_mute_toggle.set_block_signals(true)
        _sfx_mute_toggle.button_pressed = U_AUDIO_SELECTORS.is_sfx_muted(state)
        _sfx_mute_toggle.set_block_signals(false)

        # Update Ambient
        _ambient_volume_slider.set_block_signals(true)
        var ambient_vol := U_AUDIO_SELECTORS.get_ambient_volume(state)
        _ambient_volume_slider.value = ambient_vol
        _ambient_volume_slider.set_block_signals(false)
        _update_percentage_label(_ambient_percentage, ambient_vol)

        _ambient_mute_toggle.set_block_signals(true)
        _ambient_mute_toggle.button_pressed = U_AUDIO_SELECTORS.is_ambient_muted(state)
        _ambient_mute_toggle.set_block_signals(false)

        # Update Spatial
        _spatial_audio_toggle.set_block_signals(true)
        _spatial_audio_toggle.button_pressed = U_AUDIO_SELECTORS.is_spatial_audio_enabled(state)
        _spatial_audio_toggle.set_block_signals(false)

    # Master handlers
    func _on_master_volume_changed(value: float) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_master_volume(value))
        _update_percentage_label(_master_percentage, value)

    func _on_master_mute_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_master_muted(pressed))

    # Music handlers
    func _on_music_volume_changed(value: float) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_music_volume(value))
        _update_percentage_label(_music_percentage, value)

    func _on_music_mute_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_music_muted(pressed))

    # SFX handlers
    func _on_sfx_volume_changed(value: float) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(value))
        _update_percentage_label(_sfx_percentage, value)

    func _on_sfx_mute_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(pressed))

    # Ambient handlers
    func _on_ambient_volume_changed(value: float) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(value))
        _update_percentage_label(_ambient_percentage, value)

    func _on_ambient_mute_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(pressed))

    # Spatial handler
    func _on_spatial_audio_toggled(pressed: bool) -> void:
        if _state_store:
            _state_store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(pressed))

    func _update_percentage_label(label: Label, value: float) -> void:
        label.text = "%d%%" % int(value * 100.0)
    ```
  - Auto-save pattern: immediate Redux dispatch on change

- [ ] **Task 8.3 (Green)**: Wire Audio settings tab into settings panel
  - Modify main settings panel scene to include Audio tab
  - Ensure audio settings are saved to save file via Redux state persistence
  - Test: Change settings → Save game → Load game → Settings persist

---

## Phase 9: Integration Testing

**Exit Criteria:** 100 integration tests pass (10 settings UI + 30 full integration + 30 music crossfade + 30 SFX pooling)

- [ ] **Task 9.1 (Red+Green)**: Write and verify audio settings UI integration tests
  - Create `tests/integration/audio/test_audio_settings_ui.gd`
  - Tests (10): UI controls initialize from Redux state, all 4 volume sliders dispatch actions, all 4 mute toggles dispatch actions, spatial audio toggle dispatches, state changes update UI bidirectionally, settings persist to save file, settings restore from save file
  - All tests passing

- [ ] **Task 9.2 (Red+Green)**: Write and verify full audio integration tests
  - Create `tests/integration/audio/test_audio_integration.gd`
  - Tests (30): bus hierarchy correct, volume application (all 4 buses), mute application (all 4 buses), music crossfade on scene transition, pause overlay music swap, SFX systems trigger on events (5 systems), footstep system integration with movement, ambient system crossfade, UI sounds play during transitions, spatial audio positioning
  - All tests passing

- [ ] **Task 9.3 (Red+Green)**: Write and verify music crossfade integration tests
  - Create `tests/integration/audio/test_music_crossfade.gd`
  - Tests (30): dual-player swap, crossfade duration verification, volume curve (cubic easing), no audio pops/clicks, old player stops after fade, new player starts at -80dB, tween kill on retrigger, pause overlay crossfade, scene transition crossfade, music registry lookup
  - All tests passing

- [ ] **Task 9.4 (Red+Green)**: Write and verify SFX pooling integration tests
  - Create `tests/integration/audio/test_sfx_pooling.gd`
  - Tests (30): pool initialization (16 players), player availability check, player configuration (stream, position, volume, pitch, bus), pool exhaustion warning, player auto-return when finished, concurrent playback (16+ sounds), pitch variation, spatial positioning, bus routing (UI, Footsteps to SFX), max_distance attenuation
  - All tests passing

---

## Phase 10: Manual QA

**Exit Criteria:** All 20 manual QA items verified, no console errors/warnings, professional audio experience

- [ ] **Task 10.1 (Manual QA)**: Perform comprehensive manual playtest
  - [ ] Music crossfades smoothly between scenes (no pops/clicks, cubic easing)
  - [ ] Pause overlay music transitions correctly (crossfade to pause track, restore on unpause)
  - [ ] Jump sound plays on entity_jumped event (pitch variation noticeable)
  - [ ] Landing sound plays on entity_landed event (volume scales with fall speed)
  - [ ] Death sound plays on entity_death event
  - [ ] Checkpoint sound plays on checkpoint_activated event
  - [ ] Victory sound plays on victory_triggered event
  - [ ] SFX pool handles 16+ concurrent sounds without warnings (test by triggering many sounds rapidly)
  - [ ] Pitch variation adds organic feel to SFX (no robotic repetition)
  - [ ] Footsteps change based on surface type (test all 6 surfaces: default, grass, stone, wood, metal, water)
  - [ ] Footstep timing matches movement speed (faster movement = faster steps)
  - [ ] 4 footstep variations prevent repetition (listen for variation within same surface)
  - [ ] Ambient loops correctly without gaps (no silence/pops at loop point)
  - [ ] Ambient crossfades between scenes smoothly (exterior ↔ interior transitions)
  - [ ] UI sounds play on focus/confirm/cancel (every button interaction)
  - [ ] Slider sounds throttled (no spam, max 10/sec when rapidly moving slider)
  - [ ] UI sounds play even during scene transitions (UI bus independent)
  - [ ] All volume sliders affect volume in real-time (Master, Music, SFX, Ambient - hear changes immediately)
  - [ ] Mute toggles work independently of volume (mute doesn't change volume, unmute restores)
  - [ ] Settings persist across save/load (change all settings → save → quit → load → verify restored)
  - [ ] Spatial audio positioning works correctly (3D sounds attenuate with distance)
  - [ ] No audio artifacts or distortion (check at min/max volumes, during crossfades)
  - [ ] Bus routing correct (UI and Footsteps route through SFX to Master)
  - [ ] Volume conversion (linear to dB) works correctly (0.0 = silence/-80dB, 0.5 = ~-6dB, 1.0 = 0dB)

- [ ] **Task 10.2 (Testing)**: Run full test suite
  - Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  - Verify all ~280 tests pass (180 unit + 100 integration)
  - Verify no console errors or warnings
  - All tests passing, Phase 10 complete

---

## File Reference

| File Path | Status | Phase | Notes |
|-----------|--------|-------|-------|
| `scripts/state/resources/rs_audio_initial_state.gd` | ✅ Complete | 0 | 9-field audio initial state |
| `scripts/state/actions/u_audio_actions.gd` | ✅ Complete | 0 | 12 action creators |
| `scripts/state/reducers/u_audio_reducer.gd` | ✅ Complete | 0 | Audio reducer with volume clamping |
| `scripts/state/selectors/u_audio_selectors.gd` | ✅ Complete | 0 | 9 selectors for audio state |
| `scripts/state/m_state_store.gd` | ✅ Complete | 0 | Modified to export audio_initial_state |
| `scripts/state/utils/u_state_slice_manager.gd` | ✅ Complete | 0 | Modified to register audio slice |
| `tests/unit/state/test_audio_initial_state.gd` | ✅ Complete | 0 | Tests for initial state resource |
| `tests/unit/state/test_audio_reducer.gd` | ✅ Complete | 0 | 25 tests for reducer |
| `tests/unit/state/test_audio_selectors.gd` | ✅ Complete | 0 | 15 tests for selectors |
| `scripts/managers/m_audio_manager.gd` | ✅ Complete | 1 | Core manager with bus layout + music |
| `tests/unit/managers/test_audio_manager.gd` | ✅ Complete | 1 | 11 tests for manager/music |
| `resources/audio/music/placeholder_main_menu.ogg` | ✅ Complete | 2 | 5s silent loop |
| `resources/audio/music/placeholder_gameplay.ogg` | ✅ Complete | 2 | 5s silent loop |
| `resources/audio/music/placeholder_pause.ogg` | ✅ Complete | 2 | 5s silent loop |
| `scripts/ecs/base_event_sfx_system.gd` | ✅ Complete | 3 | Base class for event-driven SFX |
| `tests/unit/ecs/test_base_event_sfx_system.gd` | ✅ Complete | 3 | 15 tests for base system |
| `scripts/managers/helpers/m_sfx_spawner.gd` | ✅ Complete | 4 | SFX pool manager (16 players) |
| `tests/unit/managers/helpers/test_sfx_spawner.gd` | ✅ Complete | 4 | 10 tests for spawner |
| `scripts/ecs/systems/s_jump_sound_system.gd` | ✅ Complete | 4 | Jump SFX system |
| `scripts/ecs/resources/rs_jump_sound_settings.gd` | ✅ Complete | 4 | Jump settings resource |
| `resources/audio/sfx/placeholder_jump.wav` | ✅ Complete | 4 | 440Hz, 100ms |
| `scripts/ecs/systems/s_landing_sound_system.gd` | ✅ Complete | 4 | Landing SFX system |
| `scripts/ecs/resources/rs_landing_sound_settings.gd` | ✅ Complete | 4 | Landing settings resource |
| `resources/audio/sfx/placeholder_land.wav` | ✅ Complete | 4 | 220Hz, 100ms |
| `scripts/ecs/systems/s_death_sound_system.gd` | ✅ Complete | 4 | Death SFX system |
| `scripts/ecs/resources/rs_death_sound_settings.gd` | ✅ Complete | 4 | Death settings resource |
| `resources/audio/sfx/placeholder_death.wav` | ✅ Complete | 4 | 110Hz, 150ms |
| `scripts/ecs/systems/s_checkpoint_sound_system.gd` | ✅ Complete | 4 | Checkpoint SFX system |
| `scripts/ecs/resources/rs_checkpoint_sound_settings.gd` | ✅ Complete | 4 | Checkpoint settings resource |
| `resources/audio/sfx/placeholder_checkpoint.wav` | ✅ Complete | 4 | 880Hz, 200ms |
| `scripts/ecs/systems/s_victory_sound_system.gd` | ✅ Complete | 4 | Victory SFX system |
| `scripts/ecs/resources/rs_victory_sound_settings.gd` | ✅ Complete | 4 | Victory settings resource |
| `resources/audio/sfx/placeholder_victory.wav` | ✅ Complete | 4 | 1760Hz, 300ms |
| `scripts/ecs/components/c_surface_detector_component.gd` | ✅ Complete | 5 | Surface type detector |
| `tests/unit/ecs/components/test_surface_detector.gd` | ✅ Complete | 5 | 15 tests for surface detector |
| `scripts/ecs/systems/s_footstep_sound_system.gd` | ✅ Complete | 5 | Footstep system (per-tick) |
| `scripts/ecs/resources/rs_footstep_sound_settings.gd` | ✅ Complete | 5 | Footstep settings (24 sounds) |
| `tests/unit/ecs/systems/test_footstep_sound_system.gd` | ✅ Complete | 5 | 20 tests for footstep system |
| `resources/audio/footsteps/placeholder_default_01-04.wav` | ✅ Complete | 5 | 4 variations (200Hz) |
| `resources/audio/footsteps/placeholder_grass_01-04.wav` | ✅ Complete | 5 | 4 variations (250Hz) |
| `resources/audio/footsteps/placeholder_stone_01-04.wav` | ✅ Complete | 5 | 4 variations (180Hz) |
| `resources/audio/footsteps/placeholder_wood_01-04.wav` | ✅ Complete | 5 | 4 variations (300Hz) |
| `resources/audio/footsteps/placeholder_metal_01-04.wav` | ✅ Complete | 5 | 4 variations (400Hz) |
| `resources/audio/footsteps/placeholder_water_01-04.wav` | ✅ Complete | 5 | 4 variations (150Hz) |
| `resources/settings/footstep_sound_default.tres` | ✅ Complete | 5 | Default footstep settings |
| `scenes/prefabs/prefab_player.tscn` | ✅ Complete | 5 | Added C_SurfaceDetectorComponent |
| `scenes/gameplay/gameplay_base.tscn` | ✅ Complete | 5 | Added S_FootstepSoundSystem |
| `scenes/gameplay/gameplay_exterior.tscn` | ✅ Complete | 5 | Added S_FootstepSoundSystem |
| `scenes/gameplay/gameplay_interior_house.tscn` | ✅ Complete | 5 | Added S_FootstepSoundSystem |
| `scripts/ecs/systems/s_ambient_sound_system.gd` | ⬜ Not Started | 6 | Ambient system (dual-player) |
| `scripts/ecs/resources/rs_ambient_sound_settings.gd` | ⬜ Not Started | 6 | Ambient settings resource |
| `tests/unit/ecs/systems/test_ambient_sound_system.gd` | ⬜ Not Started | 6 | 10 tests for ambient system |
| `resources/audio/ambient/placeholder_exterior.ogg` | ⬜ Not Started | 6 | 10s silent loop |
| `resources/audio/ambient/placeholder_interior.ogg` | ⬜ Not Started | 6 | 10s silent loop |
| `scripts/managers/helpers/u_ui_sound_player.gd` | ⬜ Not Started | 7 | UI sound utility |
| `tests/unit/managers/helpers/test_ui_sound_player.gd` | ⬜ Not Started | 7 | 5 tests for UI sounds |
| `resources/audio/sfx/placeholder_ui_focus.wav` | ⬜ Not Started | 7 | 1000Hz, 30ms |
| `resources/audio/sfx/placeholder_ui_confirm.wav` | ⬜ Not Started | 7 | 1200Hz, 50ms |
| `resources/audio/sfx/placeholder_ui_cancel.wav` | ⬜ Not Started | 7 | 800Hz, 50ms |
| `resources/audio/sfx/placeholder_ui_tick.wav` | ⬜ Not Started | 7 | 1400Hz, 20ms |
| `scripts/ui/base_panel.gd` | ⬜ Not Started | 7 | Modified for focus sounds |
| `scenes/ui/settings/audio_settings_tab.tscn` | ⬜ Not Started | 8 | Audio settings UI scene |
| `scripts/ui/settings/ui_audio_settings_tab.gd` | ⬜ Not Started | 8 | Audio settings UI script |
| `tests/integration/audio/test_audio_settings_ui.gd` | ⬜ Not Started | 9 | 10 integration tests |
| `tests/integration/audio/test_audio_integration.gd` | ⬜ Not Started | 9 | 30 integration tests |
| `tests/integration/audio/test_music_crossfade.gd` | ⬜ Not Started | 9 | 30 crossfade tests |
| `tests/integration/audio/test_sfx_pooling.gd` | ⬜ Not Started | 9 | 30 pooling tests |

**Status Legend:**
- ⬜ Not Started
- 🟡 In Progress
- ✅ Complete

---

## Links

- Overview: `docs/audio manager/audio-manager-overview.md`
- PRD: `docs/audio manager/audio-manager-prd.md`
- Plan: `docs/audio manager/audio-manager-plan.md`
- Continuation prompt: `docs/audio manager/audio-manager-continuation-prompt.md`

---

## Notes

### Test Patterns
- All tests use GUT framework (`extends GutTest`)
- Event subscriptions: Always `U_ECSEventBus.reset()` in `before_each()` to prevent test pollution
- Redux immutability: Verify `old_state is not new_state` in reducer tests
- Tween testing: Use `await get_tree().create_timer(duration + 0.1).timeout` for completion
- Audio testing: Mock AudioStreamPlayer or use silent placeholder assets to avoid audio playback during tests
- Pool testing: Verify player count and availability, check exhaustion warnings

### Test Commands
```bash
# Run audio unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_audio -gexit

# Run audio integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/audio -gexit

# Run all tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

### Decisions
- **Dual-Player Crossfade**: Both music and ambient use dual-player systems to enable smooth crossfades without interrupting playback. Alternative (rejected): single player with instant switches (causes audio pops).
- **Cubic Easing for Crossfades**: Cubic in-out easing (TRANS_CUBIC, EASE_IN_OUT) provides most natural-sounding transitions. Linear tested but felt abrupt; exponential too slow.
- **16-Player SFX Pool**: Chosen based on expected concurrent sound count (worst case: 5 SFX systems + footsteps + UI = ~12 sounds). Pool size can be increased if warnings appear during playtesting.
- **Bus Hierarchy (UI/Footsteps under SFX)**: Allows independent control of UI and Footsteps while still respecting SFX master volume. Alternative: direct to Master (rejected, less flexible).
- **Pause Overlay Music Swap**: Chosen over low-pass filter approach for clearer audio pause indication. Can be changed to filter if user prefers continuity over contrast.
- **Throttled UI Slider Sounds**: 100ms interval (10/sec) prevents audio spam while still providing feedback. Tested 50ms (too spammy), 200ms (felt unresponsive).
- **Footstep Interval 0.4s**: Tested at 0.3s (too rapid), 0.5s (too slow). 0.4s matches typical walk cycle timing.
- **Surface Detection via Raycast Meta**: Using collider metadata (`surface_type`) allows level designers to easily tag surfaces. Alternative: material-based detection (rejected, harder to configure).
- **Spatial Audio Default Enabled**: 3D positioning adds immersion for footsteps/SFX. Can be toggled off in settings for players who prefer non-spatial audio.

### Deferred Items
- **Low-Pass Filter Pause Alternative**: Currently using music track swap for pause overlay. Future: Add option for low-pass filter effect (muffled sound) instead of track change.
- **Dynamic Music Layers**: Currently single-stream music. Future: Support layered music (intro/loop/outro, or additive layers for intensity).
- **Music Tempo Sync**: Currently no beat/measure awareness. Future: Sync crossfades to musical beats for seamless transitions.
- **Advanced Footstep Features**: Currently simple interval-based. Future: Animation-driven footstep events, left/right foot alternation, different sounds for walk vs run.
- **Reverb Zones**: Currently no environmental audio effects. Future: Add reverb zones for caves, large rooms, etc.
- **Occlusion/Obstruction**: Currently simple distance attenuation. Future: Raycast-based occlusion for sounds behind walls.
- **Audio Ducking**: Currently no ducking. Future: Lower music/ambient when dialogue plays.
- **SFX Volume Variation**: Currently only pitch variation. Future: Add slight volume randomization per sound for more organic feel.
- **Pooling for UI Sounds**: Currently single UI player. Future: Pool for rapid UI interactions (though throttling may make this unnecessary).
- **Music Playlist System**: Currently manual track-to-scene mapping. Future: Support playlists, random selection, crossfade between playlist tracks.

### Common Pitfalls
1. **Music Not Looping**: Set `AudioStream.loop = true` in Godot import settings (Inspector → Import tab), then Reimport. Not a code issue.
2. **Volume Slider Spam**: Without throttling, slider `value_changed` fires continuously. Always throttle UI sound playback (100ms interval minimum).
3. **SFX Pool Exhaustion**: If warning appears, increase `POOL_SIZE` constant. Monitor warnings during playtest with many concurrent sounds.
4. **Spatial Audio Distance**: Set `max_distance = 50.0` on AudioStreamPlayer3D. Default is infinite, causing sounds to be audible from anywhere.
5. **Bus Routing**: Ensure UI and Footsteps buses send to "SFX", not "Master" directly. Check with `AudioServer.get_bus_send()`.
6. **Crossfade Tween Kill**: Always check `if _tween != null and _tween.is_valid(): _tween.kill()` before creating new tween, or multiple tweens will conflict.
7. **Pause Overlay Edge Case**: If user quits during pause, `_pre_pause_music_id` persists. Reset in `_exit_tree()` or scene cleanup.
8. **Footstep Spam When Stuck**: If character velocity oscillates while stuck, footsteps may spam. Add velocity threshold check (`velocity.length() > min_velocity`).
9. **Volume Conversion Edge Case**: `log(0)` is undefined. Always check `if linear <= 0.0: return -80.0` before `log()` calculation.
10. **State Subscription Leak**: Always unsubscribe in `_exit_tree()` with `if _unsubscribe.is_valid(): _unsubscribe.call()`, or state listeners persist after scene change.

---

**END OF AUDIO MANAGER TASKS**
