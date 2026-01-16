# Audio Manager Refactoring - Task Checklist

## Overview

This document tracks the refactoring tasks for the existing Audio Manager system. The Audio Manager currently works but needs architectural improvements for better maintainability, scalability, and consistency.

**Status:** Not Started
**Approach:** TDD where practical, refactoring with tests for complex logic

---

## Phase 1: Registry & Data Architecture

**Goal**: Replace hard-coded registries with resource-driven definitions and loader pattern.

### 1.1 Music Track Definition Resource
- [ ] 🧪 Create `tests/unit/ecs/resources/test_rs_music_track_definition.gd`
  - [ ] Test required fields validation (track_id, stream)
  - [ ] Test default values (fade_duration, volume_offset, loop, pause_behavior)
  - [ ] Test pause_behavior enum values ("pause", "duck", "continue")
- [ ] Create `scripts/ecs/resources/rs_music_track_definition.gd`
  - [ ] Implement exports: track_id, stream, default_fade_duration (1.5s), base_volume_offset_db (0.0), loop (true), pause_behavior ("pause")
  - [ ] Add validation in _validate_property() or export hints

### 1.2 Ambient Track Definition Resource
- [ ] 🧪 Create `tests/unit/ecs/resources/test_rs_ambient_track_definition.gd`
  - [ ] Test required fields validation
  - [ ] Test default values
- [ ] Create `scripts/ecs/resources/rs_ambient_track_definition.gd`
  - [ ] Implement exports: ambient_id, stream, default_fade_duration (2.0s), base_volume_offset_db (0.0), loop (true)

### 1.3 UI Sound Definition Resource
- [ ] 🧪 Create `tests/unit/ecs/resources/test_rs_ui_sound_definition.gd`
  - [ ] Test required fields
  - [ ] Test throttle_ms behavior (0 = no throttle)
- [ ] Create `scripts/ecs/resources/rs_ui_sound_definition.gd`
  - [ ] Implement exports: sound_id, stream, volume_db (0.0), pitch_variation (0.0), throttle_ms (0)

### 1.4 Scene Audio Mapping Resource
- [ ] 🧪 Create `tests/unit/ecs/resources/test_rs_scene_audio_mapping.gd`
  - [ ] Test O(1) lookup pattern
  - [ ] Test optional fields (empty StringNames)
- [ ] Create `scripts/ecs/resources/rs_scene_audio_mapping.gd`
  - [ ] Implement exports: scene_id, music_track_id, ambient_track_id

### 1.5 Audio Registry Loader
- [ ] 🧪 Create `tests/unit/managers/helpers/test_u_audio_registry_loader.gd`
  - [ ] Test initialize() populates all dictionaries
  - [ ] Test get_music_track() returns correct definition or null
  - [ ] Test get_ambient_track() returns correct definition or null
  - [ ] Test get_ui_sound() returns correct definition or null
  - [ ] Test get_audio_for_scene() returns correct mapping or null
  - [ ] Test _validate_registrations() warns on duplicates
  - [ ] Test _validate_registrations() warns on missing streams
- [ ] Create `scripts/managers/helpers/u_audio_registry_loader.gd`
  - [ ] Implement static dictionaries
  - [ ] Implement initialize() calling all registration methods
  - [ ] Implement getter methods with null safety
  - [ ] Implement _validate_registrations() with warnings
  - [ ] Implement private registration methods (initially empty, populate in 1.7)

### 1.6 Create Default Resource Files
- [ ] Create `resources/audio/tracks/music_main_menu.tres` (RS_MusicTrackDefinition)
- [ ] Create `resources/audio/tracks/music_exterior.tres`
- [ ] Create `resources/audio/tracks/music_interior.tres`
- [ ] Create `resources/audio/tracks/music_pause.tres` (pause_behavior = "pause")
- [ ] Create `resources/audio/tracks/music_credits.tres`
- [ ] Create `resources/audio/ambient/ambient_exterior.tres` (RS_AmbientTrackDefinition)
- [ ] Create `resources/audio/ambient/ambient_interior.tres`
- [ ] Create `resources/audio/ui/ui_focus.tres` (RS_UISoundDefinition)
- [ ] Create `resources/audio/ui/ui_confirm.tres`
- [ ] Create `resources/audio/ui/ui_cancel.tres`
- [ ] Create `resources/audio/ui/ui_tick.tres` (throttle_ms = 100)
- [ ] Create `resources/audio/scene_mappings/*.tres` for each gameplay scene

### 1.7 Wire Registry Loader
- [ ] 🔧 Update `U_AudioRegistryLoader._register_music_tracks()`
  - [ ] Load all 5 music track .tres files
  - [ ] Store in _music_tracks dictionary
- [ ] 🔧 Update `U_AudioRegistryLoader._register_ambient_tracks()`
  - [ ] Load all 2 ambient track .tres files
  - [ ] Store in _ambient_tracks dictionary
- [ ] 🔧 Update `U_AudioRegistryLoader._register_ui_sounds()`
  - [ ] Load all 4 UI sound .tres files
  - [ ] Store in _ui_sounds dictionary
- [ ] 🔧 Update `U_AudioRegistryLoader._register_scene_audio_mappings()`
  - [ ] Load all scene mapping .tres files
  - [ ] Store in _scene_audio_map dictionary

### 1.8 Integrate Registry into Manager
- [ ] 🔧 Update `M_AudioManager._ready()` to call `U_AudioRegistryLoader.initialize()`
- [ ] 📝 Update `tests/unit/managers/test_audio_manager.gd` to use registry loader
- [ ] 🔧 ⚠️ Remove hard-coded `_MUSIC_REGISTRY` constant from M_AudioManager
- [ ] 🔧 ⚠️ Remove hard-coded `_UI_SOUND_REGISTRY` constant from M_AudioManager
- [ ] 🔧 Update music playback to use `U_AudioRegistryLoader.get_music_track()`
- [ ] 🔧 Update UI sound playback to use `U_AudioRegistryLoader.get_ui_sound()`

### 1.9 Phase 1 Verification
- [ ] Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers/helpers -gselect=test_u_audio_registry -gexit`
- [ ] Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/resources -gexit`
- [ ] Manual verification: Audio still plays correctly
- [ ] Git commit: "Phase 1: Resource-driven audio registry"

---

## Phase 2: Crossfade Helper Extraction

**Goal**: Extract shared dual-player crossfader utility to eliminate duplication.

### 2.1 Crossfade Player Helper - Tests
- [ ] 🧪 Create `tests/unit/managers/helpers/test_u_crossfade_player.gd`
  - [ ] Test initialization creates two AudioStreamPlayers
  - [ ] Test crossfade_to() swaps players correctly
  - [ ] Test crossfade_to() starts new player at -80dB
  - [ ] Test crossfade_to() fades old player out
  - [ ] Test crossfade_to() fades new player in
  - [ ] Test overlapping crossfades kill previous tween
  - [ ] Test stop() fades active player out
  - [ ] Test pause() stores playback position
  - [ ] Test resume() continues from stored position
  - [ ] Test get_current_track_id() returns correct ID
  - [ ] Test get_playback_position() returns position
  - [ ] Test is_playing() returns correct state
  - [ ] Test cleanup() frees both players

### 2.2 Crossfade Player Helper - Implementation
- [ ] Create `scripts/managers/helpers/u_crossfade_player.gd`
  - [ ] Implement RefCounted class
  - [ ] Add fields: _player_a, _player_b, _active_player, _inactive_player, _current_track_id, _tween, _owner_node
  - [ ] Implement _init(owner: Node, bus: StringName) creating two players
  - [ ] Implement crossfade_to(stream, track_id, duration, start_position)
    - [ ] Kill existing tween if valid
    - [ ] Swap active/inactive players
    - [ ] Configure new player (stream, volume -80dB, play from position)
    - [ ] Create parallel tween with TRANS_CUBIC, EASE_IN_OUT
    - [ ] Fade out old player if playing
    - [ ] Fade in new player to 0dB
    - [ ] Update _current_track_id
  - [ ] Implement stop(duration) fading active player out
  - [ ] Implement pause() calling active_player.pause() (if available) or storing position
  - [ ] Implement resume() calling active_player.play() from stored position
  - [ ] Implement get_current_track_id() returning _current_track_id
  - [ ] Implement get_playback_position() returning active_player.get_playback_position()
  - [ ] Implement is_playing() returning active_player.playing
  - [ ] Implement cleanup() queuing free on both players

### 2.3 Replace Music Crossfade in Manager
- [ ] 🔧 Update `M_AudioManager`
  - [ ] Add field: `var _music_crossfader: U_CrossfadePlayer`
  - [ ] Initialize in _ready(): `_music_crossfader = U_CrossfadePlayer.new(self, &"Music")`
  - [ ] ⚠️ Remove lines 50-58 (old dual-player creation)
  - [ ] ⚠️ Remove lines 200-239 (old _crossfade_music implementation)
  - [ ] Update _crossfade_music() to:
    - [ ] Load track definition from registry
    - [ ] Call _music_crossfader.crossfade_to(track_def.stream, track_id, duration)
  - [ ] Update stop_music() to call _music_crossfader.stop(duration)
  - [ ] Add _exit_tree() calling _music_crossfader.cleanup()
- [ ] 📝 Update tests for new crossfader usage

### 2.4 Phase 2 Verification
- [ ] Run tests
- [ ] Manual verification: Music crossfades smoothly, no audio pops
- [ ] Git commit: "Phase 2: Extract crossfade helper"

---

## Phase 3: Ambient Migration to Persistent Manager

**Goal**: Move ambient playback from ECS system to M_AudioManager for cross-scene reliability.

**Note**: `_AMBIENT_REGISTRY` currently exists in `S_AmbientSoundSystem:19-30` (hard-coded dictionary). This must be migrated to `U_AudioRegistryLoader` as part of Phase 1.7, then referenced here.

### 3.1 Add Ambient Crossfader to Manager
- [ ] 🔧 Update `M_AudioManager`
  - [ ] Add field: `var _ambient_crossfader: U_CrossfadePlayer`
  - [ ] Initialize in _ready(): `_ambient_crossfader = U_CrossfadePlayer.new(self, &"Ambient")`
  - [ ] Add method: `play_ambient(ambient_id: StringName, duration: float = 2.0)`
    - [ ] Load ambient definition from registry
    - [ ] Call _ambient_crossfader.crossfade_to()
  - [ ] Add method: `stop_ambient(duration: float = 2.0)`
    - [ ] Call _ambient_crossfader.stop()
  - [ ] Update _exit_tree() to call _ambient_crossfader.cleanup()
- [ ] 📝 Write test for ambient crossfade

### 3.2 Update Scene Transition Handler
- [ ] 🔧 Update `M_AudioManager._on_state_changed()`
  - [ ] Extract new method: `_change_audio_for_scene(scene_id: StringName)`
  - [ ] Load scene audio mapping from registry
  - [ ] Crossfade music if music_track_id is set
  - [ ] Crossfade ambient if ambient_track_id is set
  - [ ] Stop ambient if no ambient_track_id and currently playing
  - [ ] Call from transition_completed handler

### 3.3 Integration Test
- [ ] 🧪 Create `tests/integration/audio/test_audio_scene_transitions.gd`
  - [ ] Test cross-scene ambient persistence
  - [ ] Test ambient crossfade between scenes
  - [ ] Test ambient stops when scene has no ambient

### 3.4 Remove Old Ambient System
- [ ] ⚠️ Delete `scripts/ecs/systems/s_ambient_sound_system.gd`
- [ ] ⚠️ Remove S_AmbientSoundSystem nodes from gameplay scenes
- [ ] ⚠️ Delete tests for old ambient system

### 3.5 Phase 3 Verification
- [ ] Run tests
- [ ] Manual test: Ambient crossfades correctly between exterior/interior
- [ ] Git commit: "Phase 3: Migrate ambient to persistent manager"

---

## Phase 4: Bus Layout & Validation

**Goal**: Define buses in project.godot, validate at runtime instead of destructively creating.

### 4.1 Bus Constants - Tests
- [ ] 🧪 Create `tests/unit/managers/helpers/test_u_audio_bus_constants.gd`
  - [ ] Test validate_bus_layout() with all buses present
  - [ ] Test validate_bus_layout() with missing bus returns false
  - [ ] Test get_bus_index_safe() with valid bus
  - [ ] Test get_bus_index_safe() with invalid bus falls back to Master (0)
  - [ ] Test REQUIRED_BUSES array contains all 6 buses

### 4.2 Bus Constants - Implementation
- [ ] Create `scripts/managers/helpers/u_audio_bus_constants.gd`
  - [ ] Define constants: BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI, BUS_FOOTSTEPS, BUS_AMBIENT
  - [ ] Define REQUIRED_BUSES array
  - [ ] Implement validate_bus_layout() checking all required buses exist
  - [ ] Implement get_bus_index_safe(bus_name) with fallback to 0

### 4.3 Editor Bus Layout
- [ ] Open Godot Editor → Project Settings → Audio → Buses
- [ ] Verify bus hierarchy exists (or create if missing):
  ```
  Master (0)
  ├── Music (1)
  ├── SFX (2)
  │   ├── UI (3)
  │   └── Footsteps (4)
  └── Ambient (5)
  ```
- [ ] Save project settings

### 4.4 Update Manager Validation
- [ ] 🔧 Update `M_AudioManager._ready()`
  - [ ] ⚠️ Remove _create_bus_layout() call (lines ~104-142)
  - [ ] Add: `if not U_AudioBusConstants.validate_bus_layout(): push_error("Bus layout invalid")`
  - [ ] Add after service registration
- [ ] ⚠️ Delete _create_bus_layout() method completely

### 4.5 Test Helper for Bus Reset
- [ ] 🔧 Replace `tests/helpers/u_audio_test_helpers.gd` with complete implementation
  - [ ] Current file has `reset_audio_buses()` but doesn't recreate required buses
  - [ ] Implement `reset_audio_buses_for_testing()`:
    - [ ] Clear all buses > 0
    - [ ] Recreate required buses from U_AudioBusConstants.REQUIRED_BUSES
    - [ ] Set parent buses correctly (UI/Footsteps → SFX, others → Master)
  - [ ] Add comment: "TEST ONLY - destructive operation"
  - [ ] Preserve existing `create_state_store()` and `register_state_store()` helpers

### 4.6 Phase 4 Verification
- [ ] Run tests
- [ ] Manual verification: Audio works from editor-defined layout
- [ ] Git commit: "Phase 4: Non-destructive bus validation"

---

## Phase 5: I_AudioManager Interface

**Goal**: Add contract interface for type-safe access, remove has_method()/call() patterns.

### 5.1 Interface Definition
- [ ] Create `scripts/interfaces/i_audio_manager.gd`
  - [ ] Define abstract methods with push_error() stubs:
    - [ ] play_ui_sound(sound_id: StringName)
    - [ ] play_music(track_id: StringName, duration: float, start_position: float)
    - [ ] stop_music(duration: float)
    - [ ] play_ambient(ambient_id: StringName, duration: float)
    - [ ] stop_ambient(duration: float)
    - [ ] set_spatial_audio_enabled(enabled: bool)

### 5.2 Manager Implementation
- [ ] 🔧 Update `M_AudioManager`
  - [ ] Change extends to: `extends I_AudioManager`
  - [ ] Verify all interface methods are implemented
  - [ ] Add override comments

### 5.3 Utility Helper - Tests
- [ ] 🧪 Create `tests/unit/utils/test_u_audio_utils.gd`
  - [ ] Test get_audio_manager() with ServiceLocator
  - [ ] Test get_audio_manager() group fallback
  - [ ] Test get_audio_manager() returns null when missing
  - [ ] Test returns I_AudioManager type

### 5.4 Utility Helper - Implementation
- [ ] Create `scripts/utils/u_audio_utils.gd`
  - [ ] Implement static get_audio_manager(from_node: Node = null) -> I_AudioManager
  - [ ] Check ServiceLocator first
  - [ ] Fall back to group lookup if from_node provided
  - [ ] Return null if not found

### 5.5 Update Call Sites
- [ ] 🔧 Update `scripts/ui/utils/u_ui_sound_player.gd`
  - [ ] ⚠️ Replace has_method()/call() pattern in _play()
  - [ ] Use U_AudioUtils.get_audio_manager()
  - [ ] Call audio_mgr.play_ui_sound() directly
- [ ] 🔧 Update `scripts/ui/settings/ui_audio_settings_tab.gd` (if exists)
  - [ ] Add typed field: `var _audio_manager: I_AudioManager`
  - [ ] Initialize with U_AudioUtils.get_audio_manager(self)
- [ ] Search for other has_method() calls: `grep -r "has_method.*audio" scripts/`
- [ ] Update any additional call sites found

### 5.6 Phase 5 Verification
- [ ] Run tests
- [ ] Manual verification: UI sounds play correctly
- [ ] Git commit: "Phase 5: Type-safe audio manager interface"

---

## Phase 6: ECS Sound System Refactor

**Goal**: Extract shared helpers, add consistent pause/transition gating, fix performance issues.

### 6.1 Base System Helpers - Tests
- [ ] 🧪 Update `tests/unit/ecs/test_base_event_sfx_system.gd`
  - [ ] Test _should_skip_processing() with null settings
  - [ ] Test _should_skip_processing() with disabled settings
  - [ ] Test _should_skip_processing() with null stream
  - [ ] Test _is_audio_blocked() during pause
  - [ ] Test _is_audio_blocked() during scene transition
  - [ ] Test _is_audio_blocked() outside gameplay shell
  - [ ] Test _is_throttled() enforcing min_interval
  - [ ] Test _calculate_pitch() clamping variation to 0.0-0.95
  - [ ] Test _extract_position() from request Dictionary
  - [ ] Test _spawn_sfx() calls M_SFXSpawner.spawn_3d()

### 6.2 Base System Helpers - Implementation
- [ ] 🔧 Update `scripts/ecs/base_event_sfx_system.gd`
  - [ ] Add method: _should_skip_processing() -> bool
    - [ ] Check settings == null or not enabled
    - [ ] Check _get_audio_stream() == null
    - [ ] Clear requests if should skip
  - [ ] Add abstract method: _get_audio_stream() -> AudioStream (returns null by default)
  - [ ] Add method: _is_audio_blocked() -> bool
    - [ ] Get state store
    - [ ] Check gameplay.is_paused
    - [ ] Check scene.is_transitioning
    - [ ] Check navigation.shell != "gameplay"
  - [ ] Add method: _is_throttled(min_interval: float, now: float) -> bool
  - [ ] Add method: _calculate_pitch(pitch_variation: float) -> float
    - [ ] Clamp variation to 0.0-0.95
    - [ ] Return randf_range(1.0 - clamped, 1.0 + clamped)
  - [ ] Add method: _extract_position(request: Dictionary) -> Vector3
  - [ ] Add method: _spawn_sfx(stream, position, volume_db, pitch_scale, bus)
    - [ ] Call M_SFXSpawner.spawn_3d() with Dictionary config

### 6.3 Standardize Request Schema
- [ ] 📝 Document request schema in base_event_sfx_system.gd:
  ```gdscript
  ## Standard request format:
  ## {
  ##   "position": Vector3,  # Required
  ##   "entity_id": StringName  # Optional (for debugging)
  ## }
  ```

### 6.4 Update Event Publishers
- [ ] 🔧 Update event publishers to include position in payload
  - [ ] Find jump event publisher: `grep -r "entity_jumped" scripts/`
  - [ ] Update to include position: Vector3
  - [ ] Find landing event publisher
  - [ ] Update to include position
  - [ ] Find death event publisher
  - [ ] Update to include position (resolve at publish time, not in sound system)
  - [ ] Find checkpoint event publisher
  - [ ] Update to include position
  - [ ] Find victory event publisher
  - [ ] Update to include position

### 6.5 🔴 CRITICAL: Refactor Checkpoint Sound System (Performance Fix)
**Priority:** This is the ONLY system with O(n) find_child() traversal per event - fix first.

- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_checkpoint_sound_system.gd`
  - [ ] Remove slow find_child() tests
  - [ ] Add test for pause blocking
  - [ ] Add test for transition blocking
- [ ] 🔧 Refactor `scripts/ecs/systems/s_checkpoint_sound_system.gd`
  - [ ] ⚠️ Remove find_child() logic (line 76) - position now in payload
  - [ ] Use base class helpers
  - [ ] Add _is_audio_blocked() check

### 6.6 Refactor Jump Sound System
- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_jump_sound_system.gd`
  - [ ] Add test for pause blocking
  - [ ] Add test for transition blocking
  - [ ] Add test for throttling
- [ ] 🔧 Refactor `scripts/ecs/systems/s_jump_sound_system.gd`
  - [ ] Implement _get_audio_stream() returning settings.audio_stream
  - [ ] Update process_tick() to use _should_skip_processing()
  - [ ] Add _is_audio_blocked() check
  - [ ] Use _is_throttled() for interval check
  - [ ] Use _extract_position() and _calculate_pitch()
  - [ ] Use _spawn_sfx() helper
  - [ ] Target: ~40 lines (down from ~70)

### 6.7 Refactor Landing Sound System
- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_landing_sound_system.gd`
- [ ] 🔧 Refactor `scripts/ecs/systems/s_landing_sound_system.gd` (same pattern as jump)

### 6.8 Refactor Death Sound System
- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_death_sound_system.gd`
  - [ ] Add test verifying position comes from request
- [ ] 🔧 Refactor `scripts/ecs/systems/s_death_sound_system.gd`
  - [ ] Use base class helpers
  - [ ] Position already comes from entity lookup (acceptable)

### 6.9 Refactor Victory Sound System
- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_victory_sound_system.gd`
- [ ] 🔧 Refactor `scripts/ecs/systems/s_victory_sound_system.gd` (same pattern)

### 6.10 Footstep Timer Cleanup
- [ ] 🧪 Update `tests/unit/ecs/systems/test_s_footstep_sound_system.gd`
  - [ ] Add test for _entity_timers cleanup in _exit_tree()
  - [ ] Add test for timer removal when entity freed
- [ ] 🔧 Update `scripts/ecs/systems/s_footstep_sound_system.gd`
  - [ ] Add _exit_tree() calling _entity_timers.clear()
  - [ ] Add entity removal callback if manager supports it

### 6.11 Phase 6 Verification
- [ ] Run tests
- [ ] Manual verification: All ECS sounds respect pause/transitions
- [ ] Git commit: "Phase 6: Standardize ECS sound systems"

---

## Phase 7: SFX Spawner Improvements

**Goal**: Voice stealing, per-sound configuration, bus fallback, follow-emitter mode.

### 7.1 Voice Stealing - Tests
- [ ] 🧪 Create `tests/unit/managers/helpers/test_m_sfx_spawner_voice_stealing.gd`
  - [ ] Test pool exhaustion (spawn 17 sounds)
  - [ ] Test _steal_oldest_voice() selects oldest playing sound
  - [ ] Test stats tracking (spawns, steals, drops, peak_usage)
  - [ ] Test reset_stats() clears counters

### 7.2 Voice Stealing - Implementation
- [ ] 🔧 Update `scripts/managers/helpers/m_sfx_spawner.gd`
  - [ ] Add field: `static var _play_times: Dictionary = {}` (player -> start_time)
  - [ ] Implement _steal_oldest_voice() -> AudioStreamPlayer3D
    - [ ] Find oldest playing player by _play_times
    - [ ] Stop oldest player
    - [ ] Clear metadata and follow_targets
    - [ ] Increment _stats["steals"]
    - [ ] Return player
  - [ ] Update spawn_3d() to call _steal_oldest_voice() on pool exhaustion
  - [ ] Store start time in _play_times on spawn

### 7.3 Bus Fallback - Tests
- [ ] 🧪 Add test for unknown bus fallback to "SFX"
- [ ] Test _validate_bus() with valid bus
- [ ] Test _validate_bus() with invalid bus pushes warning

### 7.4 Bus Fallback - Implementation
- [ ] 🔧 Update `scripts/managers/helpers/m_sfx_spawner.gd`
  - [ ] Implement _validate_bus(bus: String) -> String
    - [ ] Check AudioServer.get_bus_index(bus) != -1
    - [ ] Return "SFX" if not found
    - [ ] Push warning for unknown bus
  - [ ] Update spawn_3d() to use _validate_bus() on bus parameter

### 7.5 Per-Sound Spatialization - Tests
- [ ] 🧪 Add test for max_distance config override
- [ ] Add test for attenuation_model config override
- [ ] Add test respects _spatial_audio_enabled flag

### 7.6 Per-Sound Spatialization - Implementation
- [ ] 🔧 Update `scripts/managers/helpers/m_sfx_spawner.gd`
  - [ ] Implement _configure_player_spatialization(player, max_distance, attenuation_model)
    - [ ] Apply max_distance if > 0, else use default (50.0)
    - [ ] Apply attenuation_model if >= 0, else use default
    - [ ] If _spatial_audio_enabled false: disable attenuation and panning
  - [ ] Update spawn_3d() to extract max_distance and attenuation_model from config
  - [ ] Call _configure_player_spatialization()

### 7.7 Follow-Emitter Mode - Tests
- [ ] 🧪 Create `tests/unit/managers/helpers/test_m_sfx_spawner_follow_emitter.gd`
  - [ ] Test follow_target config stores target
  - [ ] Test update_follow_targets() updates positions
  - [ ] Test follow_target cleanup when entity freed
  - [ ] Test follow_target cleanup when playback stops

### 7.8 Follow-Emitter Mode - Implementation
- [ ] 🔧 Update `scripts/managers/helpers/m_sfx_spawner.gd`
  - [ ] Add field: `static var _follow_targets: Dictionary = {}` (player -> Node3D)
  - [ ] Update spawn_3d() to extract follow_target from config
    - [ ] Store in _follow_targets if valid Node3D
  - [ ] Implement update_follow_targets() static method
    - [ ] Iterate _follow_targets
    - [ ] Update player.global_position = target.global_position
    - [ ] Remove invalid/stopped entries
  - [ ] Update _steal_oldest_voice() to erase from _follow_targets

### 7.9 Stats & Metrics - Tests
- [ ] 🧪 Add test for get_stats() returning current stats
- [ ] Test reset_stats() clears all counters
- [ ] Test _update_peak_usage() tracks max concurrent

### 7.10 Stats & Metrics - Implementation
- [ ] 🔧 Update `scripts/managers/helpers/m_sfx_spawner.gd`
  - [ ] Add field: `static var _stats: Dictionary = {spawns: 0, steals: 0, drops: 0, peak_usage: 0}`
  - [ ] Implement get_stats() returning _stats.duplicate()
  - [ ] Implement reset_stats() clearing counters
  - [ ] Implement _update_peak_usage() tracking max concurrent
  - [ ] Update spawn_3d() to increment stats

### 7.11 Documentation
- [ ] 📝 Add docstring to spawn_3d() documenting config Dictionary keys
- [ ] Document voice stealing behavior
- [ ] Document all config parameters with types and defaults

### 7.12 Phase 7 Verification
- [ ] Run tests
- [ ] Manual verification: Voice stealing works under load (>16 sounds)
- [ ] Git commit: "Phase 7: SFX spawner improvements"

---

## Phase 8: UI Sound Improvements

**Goal**: Polyphony support, per-sound throttles.

### 8.1 UI Sound Polyphony - Tests
- [ ] 🧪 Create `tests/integration/audio/test_ui_sound_polyphony.gd`
  - [ ] Test 4 overlapping UI sounds play simultaneously
  - [ ] Test round-robin player selection
  - [ ] Test sounds don't cut each other off

### 8.2 UI Sound Polyphony - Implementation
- [ ] 🔧 Update `scripts/managers/m_audio_manager.gd`
  - [ ] Add constant: `UI_SOUND_POLYPHONY := 4`
  - [ ] Add field: `var _ui_sound_players: Array[AudioStreamPlayer] = []`
  - [ ] Add field: `var _ui_sound_index: int = 0`
  - [ ] Implement _setup_ui_sound_players()
    - [ ] Create 4 AudioStreamPlayers on UI bus
    - [ ] Add as children
    - [ ] Store in array
  - [ ] Call _setup_ui_sound_players() in _ready()
  - [ ] Update play_ui_sound() to use round-robin selection
    - [ ] Get player at _ui_sound_index
    - [ ] Increment index modulo POLYPHONY
    - [ ] Apply volume_db and pitch_variation from sound definition

### 8.3 Per-Sound Throttles - Tests
- [ ] 🧪 Update `tests/unit/ui/test_u_ui_sound_player.gd`
  - [ ] Test throttle_ms blocks rapid plays
  - [ ] Test throttle_ms = 0 allows all plays
  - [ ] Test different sounds have independent throttles

### 8.4 Per-Sound Throttles - Implementation
**Dependency:** Requires Phase 1 to be complete (throttle_ms comes from RS_UISoundDefinition resources)

- [ ] 🔧 Update `scripts/ui/utils/u_ui_sound_player.gd`
  - [ ] Add field: `static var _last_play_times: Dictionary = {}` (sound_id -> timestamp_ms)
  - [ ] Update _play() to load sound definition from U_AudioRegistryLoader.get_ui_sound()
  - [ ] Check sound_def.throttle_ms (from RS_UISoundDefinition resource)
    - [ ] Compare Time.get_ticks_msec() - _last_play_times[sound_id]
    - [ ] Return false if within throttle window
    - [ ] Update _last_play_times[sound_id] on successful play

### 8.5 Phase 8 Verification
- [ ] Run tests
- [ ] Manual verification: Multiple UI sounds can overlap
- [ ] Git commit: "Phase 8: UI sound improvements"

---

## Phase 9: State-Driven Architecture

**Goal**: Improve subscription efficiency, optimize audio settings updates.

**Note**: Audio preview may already exist in state. Check existing implementation first.

### 9.1 Manager Subscription Optimization - Tests
- [ ] 🧪 Update `tests/unit/managers/test_audio_manager.gd`
  - [ ] Test hash-based change detection (only apply when slice changes)
  - [ ] Test _apply_audio_settings_from_dict() extracts logic
  - [ ] Test redundant updates are skipped

### 9.2 Manager Subscription Optimization - Implementation
- [ ] 🔧 Update `scripts/managers/m_audio_manager.gd`
  - [ ] Add field: `var _last_audio_hash: int = 0`
  - [ ] Update _on_state_changed(action, state)
    - [ ] Extract audio slice
    - [ ] Compute hash: audio_slice.hash()
    - [ ] Only apply if hash changed
    - [ ] Update _last_audio_hash
  - [ ] Extract _apply_audio_settings_from_dict(settings: Dictionary)
    - [ ] Move bus application logic here
    - [ ] Apply master, music, sfx, ambient volumes and mutes

### 9.3 Phase 9 Verification
- [ ] Run tests
- [ ] Profile: Verify reduced bus updates during state changes
- [ ] Git commit: "Phase 9: Optimize state subscription"

---

## Phase 10: Testing & Documentation

**Goal**: Comprehensive test coverage, update documentation.

### 10.1 Test Coverage Review
- [ ] Review test coverage for all new helpers
  - [ ] U_AudioRegistryLoader
  - [ ] U_CrossfadePlayer
  - [ ] U_AudioBusConstants
  - [ ] M_SFXSpawner (voice stealing, follow-emitter)
  - [ ] U_AudioUtils
- [ ] Review test coverage for refactored systems
  - [ ] All 5 event-driven sound systems
  - [ ] BaseEventSFXSystem helpers
  - [ ] Footstep timer cleanup

### 10.2 Integration Tests
- [ ] Verify `tests/integration/audio/test_audio_scene_transitions.gd` exists
  - [ ] If not, create tests for cross-scene music/ambient
- [ ] Verify `tests/integration/audio/test_ui_sound_polyphony.gd` exists
  - [ ] If not, create tests for UI sound overlap
- [ ] Create `tests/integration/audio/test_sfx_voice_stealing_load.gd`
  - [ ] Test spawning >16 sounds simultaneously
  - [ ] Verify voice stealing occurs
  - [ ] Verify no console errors

### 10.3 Update AGENTS.md
- [ ] 📝 Add Audio Manager patterns section to `AGENTS.md`
  - [ ] Registry & Data patterns (resource-driven, O(1) lookup)
  - [ ] Crossfade patterns (U_CrossfadePlayer usage)
  - [ ] Bus Layout patterns (validation, constants)
  - [ ] SFX Spawner patterns (Dictionary API, voice stealing, follow-emitter)
  - [ ] ECS Sound Systems patterns (request schema, shared helpers, pause/transition gating)
  - [ ] State-driven patterns (hash-based updates)

### 10.4 Create User Guide
- [ ] 📝 Create `docs/audio manager/AUDIO_MANAGER_GUIDE.md`
  - [ ] Quick start guide
  - [ ] Adding new music tracks (create .tres, register in loader)
  - [ ] Adding new sound effects (create .tres, use M_SFXSpawner)
  - [ ] Configuring scene audio mappings
  - [ ] Understanding bus layout
  - [ ] Troubleshooting common issues

### 10.5 Update Refactor Documentation
- [ ] 📝 Update `audio-manager-refactor.md` with completion notes
  - [ ] Mark all phases complete
  - [ ] Document deviations from plan (if any)
  - [ ] List performance improvements measured

### 10.6 Code Health Check
- [ ] Run Godot static analyzer (if available)
- [ ] Check for unused imports/variables
- [ ] Verify all `@warning_ignore` annotations are necessary
- [ ] Ensure consistent naming conventions (u_, m_, s_, rs_ prefixes)
- [ ] Run style enforcement: `tests/unit/style/test_style_enforcement.gd`

### 10.7 Performance Verification
- [ ] Measure SFX pool usage stats: `M_SFXSpawner.get_stats()`
- [ ] Verify voice stealing is rare (<5% of spawns)
- [ ] Verify no audio dropouts during intense gameplay
- [ ] Profile state subscription overhead (should be minimal with hash optimization)

### 10.8 Full Test Suite
- [ ] Run full test suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- [ ] All tests passing
- [ ] No console errors or warnings

### 10.9 Manual Gameplay Test
- [ ] Full playthrough testing all audio systems
- [ ] Music crossfades between scenes
- [ ] Ambient crossfades between scenes
- [ ] All SFX systems trigger correctly
- [ ] UI sounds play correctly
- [ ] Audio settings apply correctly
- [ ] No audio artifacts or glitches

### 10.10 Phase 10 Completion
- [ ] Git commit: "Phase 10: Testing and documentation complete"
- [ ] Final commit: "Audio Manager refactor complete"

---

## Dependencies

**Sequential (must complete in order):**
- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

**Parallelizable (after Phase 5):**
- Phase 6 (ECS refactor)
- Phase 7 (SFX spawner)
- Phase 8 (UI sounds)

**Sequential (after Phase 5):**
- Phase 9 (state-driven)

**Final:**
- Phase 10 (after all others)

---

## Test Commands

```bash
# Run all unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run audio integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/audio -gexit

# Run full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit
```

---

## Notes

### Legend
- 🧪 = Write tests first (TDD)
- 🔧 = Refactor existing code
- 📝 = Update tests after implementation
- ⚠️ = Breaking change requiring updates

### Key Improvements from Refactor
1. **Registry system** eliminates hard-coded dictionaries (5 music, 4 UI sounds, 2 ambients)
2. **Crossfade helper** eliminates ~40 lines of duplication between music and ambient
3. **Persistent ambient** fixes cross-scene ambient reliability (was per-scene ECS system)
4. **Non-destructive bus layout** prevents production bus clearing
5. **Type-safe interface** eliminates has_method()/call() patterns
6. **Shared ECS helpers** reduces ~40-50 lines per sound system (5 systems)
7. **Consistent gating** adds pause/transition checks to all ECS sound systems
8. **Voice stealing** fixes pool exhaustion (16 player limit)
9. **Per-sound config** enables spatialization overrides per sound effect
10. **Hash-based subscription** reduces redundant bus updates

### Common Pitfalls
1. **Breaking changes**: Phases 1, 3, 4, 5, 6 contain breaking changes - update call sites
2. **Test isolation**: Always reset audio buses in test helpers
3. **Tween cleanup**: Always kill existing tweens before creating new ones
4. **Position resolution**: Resolve entity positions at event publish time, not in sound systems
5. **Follow-emitter cleanup**: Remember to clear follow_targets when players stop or are stolen

---

## File Changes Summary

### New Files (27)
- 4 resource definitions (music, ambient, UI sound, scene mapping)
- 3 helper utilities (registry loader, crossfade player, bus constants, audio utils)
- 1 interface (I_AudioManager)
- 12 resource .tres files (5 music, 2 ambient, 4 UI sounds, 1+ scene mappings)
- ~7 new test files

### Modified Files (12)
- M_AudioManager (major refactor)
- M_SFXSpawner (voice stealing, config, follow-emitter)
- BaseEventSFXSystem (shared helpers)
- 5 event sound systems (jump, landing, death, checkpoint, victory)
- S_FootstepSoundSystem (timer cleanup)
- U_UISoundPlayer (per-sound throttles, interface usage)
- AGENTS.md (audio patterns section)

### Deleted Files (1-2)
- S_AmbientSoundSystem (migrated to manager)
- Associated ambient system tests

---

**END OF AUDIO MANAGER REFACTORING TASKS**
