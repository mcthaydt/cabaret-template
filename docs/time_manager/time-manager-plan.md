# Time Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.6)
**Status**: Planning
**Methodology**: Test-Driven Development (Red-Green-Refactor)
**Reference**: `docs/time_manager/time-manager-overview.md`

---

## Overview

Replace `M_PauseManager` with `M_TimeManager` — a central time authority that adds layered pause channels, timescale control, and a world simulation clock. Full backward compatibility with all existing pause consumers.

**TDD discipline**: Tests are written **within each phase**, not deferred to a final phase. Each helper commit (Phases 1–3) writes unit tests before implementing method bodies. Integration tests are added alongside the manager commits that make them pass. GDScript requires class files to exist before tests can reference them, so the practical cycle is: create class with method stubs → write tests (RED) → implement methods (GREEN).

## Key Patterns to Follow

Before implementation, study these reference files:

- `scripts/managers/m_pause_manager.gd` — Current pause logic to port (store subscription, overlay polling, cursor coordination)
- `scripts/managers/m_audio_manager.gd` — Hash-based optimization, store discovery, ServiceLocator registration
- `scripts/managers/helpers/localization/u_localization_catalog.gd` — RefCounted helper pattern (no signals)
- `scripts/state/utils/u_state_slice_manager.gd` — Slice registration (signature extension, transient_fields)
- `scripts/state/m_state_store.gd` — `@export` pattern, `const` preloads, `_initialize_slices()` call
- `scripts/state/actions/u_gameplay_actions.gd` — Action creator pattern with `_static_init()` registration
- `scripts/state/reducers/u_audio_reducer.gd` — Reducer pattern with `_with_values()` helper
- `scripts/interfaces/i_state_store.gd` — Interface pattern (extends Node, push_error stubs)
- `scripts/root.gd` — ServiceLocator bootstrap with `_register_if_exists()`

---

## Phase 1: Core Refactor — Replace M_PauseManager

**Goal**: `M_TimeManager` + `U_PauseSystem` replaces `M_PauseManager` with identical external behavior. All 10 existing pause tests pass without behavioral changes.

**Exit Criteria**: All existing pause integration tests pass; `is_paused()` / `pause_state_changed` / cursor coordination identical; `test_style_enforcement.gd` passes.

---

### Commit 1: U_PauseSystem Helper + Tests (TDD)

**Files to create**:

- `scripts/managers/helpers/time/u_pause_system.gd`
- `tests/unit/managers/test_time_manager.gd`

**TDD approach**: Create `U_PauseSystem` with method signatures returning defaults. Write the test cases below. Run tests (RED). Implement method bodies. Run tests (GREEN).

**U_PauseSystem unit tests** (write first, in `test_time_manager.gd`):

- `test_initial_state_not_paused` — `compute_is_paused()` returns `false` on fresh instance
- `test_request_pause_single_channel` — request → `compute_is_paused()` returns `true`
- `test_release_pause_single_channel` — request then release → `compute_is_paused()` returns `false`
- `test_ref_counting` — 2 requests, 1 release → still paused; 2nd release → not paused
- `test_multiple_channels` — request UI + cutscene, release UI → still paused (cutscene active)
- `test_is_channel_paused` — only requested channel returns `true`
- `test_get_active_channels` — returns only channels with count > 0
- `test_derive_from_overlay_state_pauses` — `derive_pause_from_overlay_state(1)` → `CHANNEL_UI` active
- `test_derive_from_overlay_state_unpauses` — `derive_pause_from_overlay_state(0)` → `CHANNEL_UI` inactive
- `test_release_below_zero_clamps` — release without request → count stays 0, no error

**Implementation**:

```gdscript
extends RefCounted
class_name U_PauseSystem

## Layered pause channels with reference counting.
## Computes the final pause boolean — does NOT apply get_tree().paused
## (RefCounted has no scene tree access; M_TimeManager applies it).

const CHANNEL_UI := &"ui"
const CHANNEL_CUTSCENE := &"cutscene"
const CHANNEL_DEBUG := &"debug"
const CHANNEL_SYSTEM := &"system"

## channel StringName -> int count
var _channels: Dictionary = {}

func request_pause(channel: StringName) -> void:
    var count: int = _channels.get(channel, 0)
    _channels[channel] = count + 1

func release_pause(channel: StringName) -> void:
    var count: int = _channels.get(channel, 0)
    _channels[channel] = maxi(count - 1, 0)
    if _channels[channel] == 0:
        _channels.erase(channel)

func is_channel_paused(channel: StringName) -> bool:
    return _channels.get(channel, 0) > 0

func compute_is_paused() -> bool:
    for channel in _channels:
        if _channels[channel] > 0:
            return true
    return false

func get_active_channels() -> Array[StringName]:
    var active: Array[StringName] = []
    for channel in _channels:
        if _channels[channel] > 0:
            active.append(channel)
    return active

## Called by M_TimeManager when overlay count changes.
## Auto-drives CHANNEL_UI: count = 1 if overlays > 0, else erased.
func derive_pause_from_overlay_state(overlay_count: int) -> void:
    if overlay_count > 0:
        _channels[CHANNEL_UI] = 1
    else:
        _channels.erase(CHANNEL_UI)
```

---

### Commit 2: I_TimeManager Interface

**Files to create**:

- `scripts/interfaces/i_time_manager.gd`

**Implementation**:

```gdscript
extends Node
class_name I_TimeManager

## Minimal interface for M_TimeManager.
## Enables dependency injection and mock testing.

func is_paused() -> bool:
    push_error("I_TimeManager.is_paused not implemented")
    return false

func request_pause(_channel: StringName) -> void:
    push_error("I_TimeManager.request_pause not implemented")

func release_pause(_channel: StringName) -> void:
    push_error("I_TimeManager.release_pause not implemented")

func is_channel_paused(_channel: StringName) -> bool:
    push_error("I_TimeManager.is_channel_paused not implemented")
    return false

func get_active_pause_channels() -> Array[StringName]:
    push_error("I_TimeManager.get_active_pause_channels not implemented")
    return []

func set_timescale(_scale: float) -> void:
    push_error("I_TimeManager.set_timescale not implemented")

func get_timescale() -> float:
    push_error("I_TimeManager.get_timescale not implemented")
    return 1.0

func get_scaled_delta(_raw_delta: float) -> float:
    push_error("I_TimeManager.get_scaled_delta not implemented")
    return _raw_delta

func get_world_time() -> Dictionary:
    push_error("I_TimeManager.get_world_time not implemented")
    return {}

func set_world_time(_hour: int, _minute: int) -> void:
    push_error("I_TimeManager.set_world_time not implemented")

func set_world_time_speed(_minutes_per_real_second: float) -> void:
    push_error("I_TimeManager.set_world_time_speed not implemented")

func is_daytime() -> bool:
    push_error("I_TimeManager.is_daytime not implemented")
    return true
```

---

### Commit 3: M_TimeManager Core + Pause Integration Tests (TDD)

**Files to create**:

- `scripts/managers/m_time_manager.gd`

**Port all logic from `m_pause_manager.gd`**:

- `_init()`: `process_mode = PROCESS_MODE_ALWAYS`
- `_ready()`: ServiceLocator store lookup → `_initialize()`
- `_deferred_init()`: fallback store lookup
- `_initialize()`: cursor manager lookup, UIOverlayStack find, store subscription, initial state read
- `_exit_tree()`: disconnect store subscription
- `_process()`: overlay resync polling (NOT `_physics_process` — preserving existing M_PauseManager behavior)
- `_on_slice_updated()`: scene slice handler
- `_apply_pause_and_cursor_state()`: engine pause + cursor coordination
- `_get_scene_type()`: scene type lookup via `U_SceneRegistry`
- `is_paused()`: backward compat
- Signal: `pause_state_changed(is_paused: bool)`

**Key difference from M_PauseManager**: Delegates pause computation to `U_PauseSystem` instance instead of inline boolean logic.

```gdscript
@icon("res://assets/editor_icons/icn_manager.svg")
extends I_TimeManager
class_name M_TimeManager

signal pause_state_changed(is_paused: bool)
signal timescale_changed(new_scale: float)
signal world_hour_changed(hour: int)

var _store: I_StateStore = null
var _cursor_manager: M_CursorManager = null
var _ui_overlay_stack: CanvasLayer = null
var _pause_system := U_PauseSystem.new()
var _is_paused: bool = false
var _current_scene_id: StringName = StringName("")
var _current_scene_type: int = -1

func _init() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

# ... (port _ready, _deferred_init, _initialize, _exit_tree from m_pause_manager.gd)

## Overlay resync — runs every _process() frame (NOT _physics_process).
## Preserves M_PauseManager's existing responsive update behavior.
func _process(__delta: float) -> void:
    _check_and_resync_pause_state()

func _check_and_resync_pause_state() -> void:
    if not _store or not _ui_overlay_stack:
        return
    # Derive CHANNEL_UI from overlay count
    var current_ui_count: int = _ui_overlay_stack.get_child_count()
    var scene_state: Dictionary = _store.get_slice(StringName("scene"))
    var scene_stack: Array = scene_state.get("scene_stack", [])
    var total_overlay_count: int = maxi(current_ui_count, scene_stack.size())
    _pause_system.derive_pause_from_overlay_state(total_overlay_count)

    var should_be_paused: bool = _pause_system.compute_is_paused()
    if should_be_paused != _is_paused or get_tree().paused != _is_paused:
        var pause_changed: bool = should_be_paused != _is_paused
        _is_paused = should_be_paused
        _apply_pause_and_cursor_state()
        if pause_changed:
            pause_state_changed.emit(_is_paused)

func _apply_pause_and_cursor_state() -> void:
    get_tree().paused = _is_paused
    # ... (cursor coordination identical to m_pause_manager.gd)

func is_paused() -> bool:
    return _is_paused

func request_pause(channel: StringName) -> void:
    _pause_system.request_pause(channel)
    _check_and_resync_pause_state()

func release_pause(channel: StringName) -> void:
    _pause_system.release_pause(channel)
    _check_and_resync_pause_state()

func is_channel_paused(channel: StringName) -> bool:
    return _pause_system.is_channel_paused(channel)

func get_active_pause_channels() -> Array[StringName]:
    return _pause_system.get_active_channels()

# Timescale stubs (Phase 2)
func set_timescale(_scale: float) -> void: pass
func get_timescale() -> float: return 1.0
func get_scaled_delta(raw_delta: float) -> float: return raw_delta

# World clock stubs (Phase 3)
func get_world_time() -> Dictionary: return {}
func set_world_time(_hour: int, _minute: int) -> void: pass
func set_world_time_speed(_minutes_per_real_second: float) -> void: pass
func is_daytime() -> bool: return true
```

**M_TimeManager pause integration tests** (add to `test_time_manager.gd`, require adding to tree with store):

- `test_backward_compat_pause_manager_lookup` — `get_service("pause_manager")` returns M_TimeManager
- `test_is_paused_false_initially` — `is_paused()` returns `false`
- `test_request_release_pause` — request → paused; release → not paused
- `test_pause_state_changed_signal` — signal emitted on pause transitions

---

### Commit 4: Root Scene & ServiceLocator Wiring

**Files to modify**:

**1. `scripts/root.gd`**:

```gdscript
# Change line 31:
# FROM: _register_if_exists(managers_node, "M_PauseManager", StringName("pause_manager"))
# TO:
_register_if_exists(managers_node, "M_TimeManager", StringName("time_manager"))
_register_if_exists(managers_node, "M_TimeManager", StringName("pause_manager"))  # backward compat alias

# Update dependency registrations (lines 45-46):
# FROM: U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("state_store"))
#        U_ServiceLocator.register_dependency(StringName("pause_manager"), StringName("cursor_manager"))
# TO:
U_ServiceLocator.register_dependency(StringName("time_manager"), StringName("state_store"))
U_ServiceLocator.register_dependency(StringName("time_manager"), StringName("cursor_manager"))
# Note: "pause_manager" dependencies no longer needed since it's an alias for the same node
```

**2. `scenes/root.tscn`** (manual edit):

- Rename `M_PauseManager` node → `M_TimeManager`
- Change script from `m_pause_manager.gd` → `m_time_manager.gd`

---

### Commit 5: Test Migration (10 files)

**Files to modify** (mechanical find-replace):

All 10 files replace `M_PauseManager` class references with `M_TimeManager` and update preload paths from `m_pause_manager.gd` to `m_time_manager.gd`.

**1. `tests/integration/scene_manager/test_pause_system.gd`**:

```gdscript
# Line 16 — FROM:
const S_PAUSE_SYSTEM := preload("res://scripts/managers/m_pause_manager.gd")
# TO:
const S_PAUSE_SYSTEM := preload("res://scripts/managers/m_time_manager.gd")
```

**2. `tests/integration/scene_manager/test_particles_pause.gd`**:

```gdscript
# Line 8 — same preload path change
```

**3. `tests/integration/scene_manager/test_pause_settings_flow.gd`**:

```gdscript
# Line 9 — same preload path change
```

**4. `tests/integration/scene_manager/test_cursor_reactive_updates.gd`**:

```gdscript
# Line 9 — FROM: var _pause_system: M_PauseManager
# TO:             var _pause_system: M_TimeManager
# Line 48 — FROM: _pause_system = M_PauseManager.new()
# TO:             _pause_system = M_TimeManager.new()
```

**5. `tests/integration/scene_manager/test_scene_preloading.gd`**:

```gdscript
# Line 12 — const preload path change
# Line 23 — type annotation change
# Line 61 — instantiation change
```

**6. `tests/unit/integration/test_navigation_integration.gd`**:

```gdscript
# Line 12 — type annotation
# Line 55 — instantiation
```

**7. `tests/unit/integration/test_input_profile_selector_overlay.gd`**:

```gdscript
# Line 13 — type annotation
# Line 107 — instantiation
```

**8. `tests/unit/scene_manager/test_overlay_stack_sync.gd`**:

```gdscript
# Line 13 — type annotation
# Line 59 — instantiation
```

**9. `tests/unit/integration/test_poc_pause_system.gd`**:

```gdscript
# Lines 56, 76, 100 — instantiation M_PauseManager.new() → M_TimeManager.new()
# Line 10 — type annotation
```

**10. `tests/unit/style/test_style_enforcement.gd`**:

```gdscript
# Line 67 — FROM: "res://scripts/ecs/systems": ["s_", "m_"], # m_ for M_PauseManager
# TO:             "res://scripts/ecs/systems": ["s_"],

# Line 303 — FROM: var has_pause_manager := false
# TO:              var has_time_manager := false

# Line 322-323 — FROM: elif node_name == "M_PauseManager" and path_str.contains("Managers"):
#                           has_pause_manager = true
# TO:                  elif node_name == "M_TimeManager" and path_str.contains("Managers"):
#                           has_time_manager = true

# Line 337 — FROM: assert_true(has_pause_manager, "Root scene must have M_PauseManager in Managers")
# TO:              assert_true(has_time_manager, "Root scene must have M_TimeManager in Managers")
```

---

### Commit 6: Delete M_PauseManager

**Files to delete**:

- `scripts/managers/m_pause_manager.gd`
- `scripts/managers/m_pause_manager.gd.uid`

**Verification**: Run all pause-related tests to confirm everything passes.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/integration -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_manager -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

---

## Phase 2: Timescale Support

**Goal**: Add timescale multiplier that scales ECS delta globally.

**Exit Criteria**: `get_scaled_delta(1.0)` returns `0.5` when timescale is `0.5`; ECS systems receive scaled delta; timescale clamped to `[0.01, 10.0]`.

---

### Commit 1: U_TimescaleController Helper + Tests (TDD)

**Files to create**:

- `scripts/managers/helpers/time/u_timescale_controller.gd`

**TDD approach**: Create class with method signatures. Write tests below in `test_time_manager.gd`. Run (RED). Implement. Run (GREEN).

**U_TimescaleController unit tests** (add to `test_time_manager.gd`):

- `test_default_timescale` — `get_timescale()` returns `1.0`
- `test_set_timescale` — set to `0.5` → `get_timescale()` returns `0.5`
- `test_timescale_clamp_lower` — set to `0.0` → clamped to `0.01`
- `test_timescale_clamp_upper` — set to `100.0` → clamped to `10.0`
- `test_scaled_delta` — timescale `0.5`, raw delta `1.0` → `get_scaled_delta()` returns `0.5`
- `test_scaled_delta_default` — timescale `1.0`, raw delta `0.016` → returns `0.016`

**Implementation**:

```gdscript
extends RefCounted
class_name U_TimescaleController

const MIN_TIMESCALE := 0.01
const MAX_TIMESCALE := 10.0

var _timescale: float = 1.0

func set_timescale(scale: float) -> void:
    _timescale = clampf(scale, MIN_TIMESCALE, MAX_TIMESCALE)

func get_timescale() -> float:
    return _timescale

func get_scaled_delta(raw_delta: float) -> float:
    return raw_delta * _timescale
```

---

### Commit 2: Wire Timescale into M_TimeManager

**Files to modify**:

- `scripts/managers/m_time_manager.gd`

**Changes**:

```gdscript
# Add member:
var _timescale_controller := U_TimescaleController.new()

# Replace stubs:
func set_timescale(scale: float) -> void:
    _timescale_controller.set_timescale(scale)
    timescale_changed.emit(_timescale_controller.get_timescale())

func get_timescale() -> float:
    return _timescale_controller.get_timescale()

func get_scaled_delta(raw_delta: float) -> float:
    return _timescale_controller.get_scaled_delta(raw_delta)
```

**M_TimeManager timescale integration test** (add to `test_time_manager.gd`):

- `test_get_scaled_delta_default` — returns raw delta when timescale 1.0

---

### Commit 3: ECS Manager Integration

**Files to modify**:

- `scripts/managers/m_ecs_manager.gd`

**Changes** (in `_physics_process`):

```gdscript
# Add lazy-cached member:
var _time_manager: Node = null  # Resolved once via ServiceLocator
var _time_manager_resolved: bool = false

func _physics_process(delta: float) -> void:
    _ensure_systems_sorted()
    if _sorted_systems.is_empty():
        return

    # Lazy-lookup time_manager (once)
    if not _time_manager_resolved:
        _time_manager = U_ServiceLocator.try_get_service(StringName("time_manager"))
        _time_manager_resolved = true

    # Apply timescale
    var scaled_delta: float = delta
    if _time_manager and _time_manager.has_method("get_scaled_delta"):
        scaled_delta = _time_manager.get_scaled_delta(delta)

    var needs_cleanup := false
    for system in _sorted_systems:
        if system == null or not is_instance_valid(system):
            needs_cleanup = true
            continue
        if system.is_debug_disabled():
            continue
        system.process_tick(scaled_delta)  # scaled delta instead of raw

    if needs_cleanup:
        mark_systems_dirty()
```

---

## Phase 3: World Clock

**Goal**: In-game simulation clock that advances during gameplay, stops when paused.

**Exit Criteria**: Clock advances at configurable speed; stops when any pause channel active; hour/minute callbacks fire at correct transitions; `is_daytime()` returns correct values.

---

### Commit 1: U_WorldClock Helper + Tests (TDD)

**Files to create**:

- `scripts/managers/helpers/time/u_world_clock.gd`

**TDD approach**: Create class with method signatures. Write tests below in `test_time_manager.gd`. Run (RED). Implement. Run (GREEN).

**U_WorldClock unit tests** (add to `test_time_manager.gd`):

- `test_default_time` — `get_time()` returns `{hour: 8, minute: 0, ...}`
- `test_advance_one_minute` — advance by `1.0` second at speed `1.0` → minute becomes 1
- `test_advance_one_hour` — advance by `60.0` → hour becomes 9
- `test_day_rollover` — advance past midnight → `day_count` increments
- `test_set_time` — `set_time(14, 30)` → hour 14, minute 30
- `test_set_speed` — `set_speed(2.0)` → advance `1.0` second → 2 minutes elapsed
- `test_is_daytime_true` — hour 12 → `true`
- `test_is_daytime_false` — hour 22 → `false`
- `test_minute_callback_fires` — advance crosses minute boundary → callback called
- `test_hour_callback_fires` — advance crosses hour boundary → callback called
- `test_callback_not_called_when_unset` — no callback set → no error on advance

**Implementation**:

```gdscript
extends RefCounted
class_name U_WorldClock

const MINUTES_PER_DAY := 1440.0
const DEFAULT_SUNRISE_HOUR := 6
const DEFAULT_SUNSET_HOUR := 18

var total_minutes: float = 480.0  # 8:00 AM
var day_count: int = 1
var minutes_per_real_second: float = 1.0

var sunrise_hour: int = DEFAULT_SUNRISE_HOUR
var sunset_hour: int = DEFAULT_SUNSET_HOUR

## Callable callbacks (RefCounted cannot have signals)
var on_minute_changed: Callable = Callable()
var on_hour_changed: Callable = Callable()

func advance(scaled_delta: float) -> void:
    var prev_minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
    total_minutes += minutes_per_real_second * scaled_delta

    # Day rollover
    while total_minutes >= float(day_count) * MINUTES_PER_DAY:
        day_count += 1

    var new_minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))

    # Minute change callback
    if new_minutes_today != prev_minutes_today:
        if on_minute_changed.is_valid():
            on_minute_changed.call(new_minutes_today % 60)

        # Hour change callback
        var prev_hour: int = prev_minutes_today / 60
        var new_hour: int = new_minutes_today / 60
        if new_hour != prev_hour:
            if on_hour_changed.is_valid():
                on_hour_changed.call(new_hour)

func get_time() -> Dictionary:
    var minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
    return {
        "hour": minutes_today / 60,
        "minute": minutes_today % 60,
        "total_minutes": total_minutes,
        "day_count": day_count,
    }

func set_time(hour: int, minute: int) -> void:
    var current_day_base: float = float(day_count - 1) * MINUTES_PER_DAY
    total_minutes = current_day_base + float(clampi(hour, 0, 23) * 60 + clampi(minute, 0, 59))

func set_speed(mps: float) -> void:
    minutes_per_real_second = maxf(mps, 0.0)

func is_daytime() -> bool:
    var minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
    var hour: int = minutes_today / 60
    return hour >= sunrise_hour and hour < sunset_hour
```

---

### Commit 2: Wire World Clock into M_TimeManager

**Files to modify**:

- `scripts/managers/m_time_manager.gd`

**Changes**:

```gdscript
# Add member:
var _world_clock := U_WorldClock.new()

# In _initialize() or _ready():
func _initialize() -> void:
    # ... existing store/cursor/overlay setup ...
    _world_clock.on_minute_changed = Callable(self, "_on_world_minute_changed")
    _world_clock.on_hour_changed = Callable(self, "_on_world_hour_changed")

# Add _physics_process for world clock (separate from _process overlay resync):
func _physics_process(delta: float) -> void:
    if not _is_paused:
        _world_clock.advance(get_scaled_delta(delta))

# Callback handlers:
func _on_world_minute_changed(_minute: int) -> void:
    # Dispatch to store (Phase 4 — stub for now)
    pass

func _on_world_hour_changed(hour: int) -> void:
    world_hour_changed.emit(hour)

# Replace stubs:
func get_world_time() -> Dictionary:
    return _world_clock.get_time()

func set_world_time(hour: int, minute: int) -> void:
    _world_clock.set_time(hour, minute)

func set_world_time_speed(mps: float) -> void:
    _world_clock.set_speed(mps)

func is_daytime() -> bool:
    return _world_clock.is_daytime()
```

**M_TimeManager world clock integration test** (add to `test_time_manager.gd`):

- `test_world_clock_stops_when_paused` — request pause → advance → clock unchanged

---

## Phase 4: Redux State & Persistence

**Goal**: Time slice in Redux store; world clock state persists across saves; transient fields reset on load.

**Exit Criteria**: `time` slice registered with correct transient_fields; save/load preserves world clock; `gameplay.paused` mirror stays in sync.

---

### Commit 1: RS_TimeInitialState Resource

**Files to create**:

- `scripts/resources/state/rs_time_initial_state.gd`

**Implementation**:

```gdscript
@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_TimeInitialState

@export_group("Transient")
@export var is_paused: bool = false
@export var active_channels: Array = []
@export var timescale: float = 1.0

@export_group("World Clock")
@export var world_hour: int = 8
@export var world_minute: int = 0
@export var world_total_minutes: float = 480.0
@export var world_day_count: int = 1
@export var world_time_speed: float = 1.0

@export_group("Derived")
@export var is_daytime: bool = true

func to_dictionary() -> Dictionary:
    return {
        "is_paused": is_paused,
        "active_channels": active_channels.duplicate(),
        "timescale": timescale,
        "world_hour": world_hour,
        "world_minute": world_minute,
        "world_total_minutes": world_total_minutes,
        "world_day_count": world_day_count,
        "world_time_speed": world_time_speed,
        "is_daytime": is_daytime,
    }
```

**Files to create**:

- `resources/base_settings/state/cfg_time_initial_state.tres` — default instance with all defaults

---

### Commit 2: U_TimeActions

**Files to create**:

- `scripts/state/actions/u_time_actions.gd`

**Implementation**:

```gdscript
extends RefCounted
class_name U_TimeActions

const ACTION_UPDATE_PAUSE_STATE := StringName("time/update_pause_state")
const ACTION_UPDATE_TIMESCALE := StringName("time/update_timescale")
const ACTION_UPDATE_WORLD_TIME := StringName("time/update_world_time")
const ACTION_SET_WORLD_TIME := StringName("time/set_world_time")
const ACTION_SET_WORLD_TIME_SPEED := StringName("time/set_world_time_speed")

static func _static_init() -> void:
    U_ActionRegistry.register_action(ACTION_UPDATE_PAUSE_STATE)
    U_ActionRegistry.register_action(ACTION_UPDATE_TIMESCALE)
    U_ActionRegistry.register_action(ACTION_UPDATE_WORLD_TIME)
    U_ActionRegistry.register_action(ACTION_SET_WORLD_TIME)
    U_ActionRegistry.register_action(ACTION_SET_WORLD_TIME_SPEED)

static func update_pause_state(paused: bool, channels: Array) -> Dictionary:
    return {
        "type": ACTION_UPDATE_PAUSE_STATE,
        "payload": {"is_paused": paused, "active_channels": channels.duplicate()},
    }

static func update_timescale(scale: float) -> Dictionary:
    return {
        "type": ACTION_UPDATE_TIMESCALE,
        "payload": scale,
    }

static func update_world_time(hour: int, minute: int, total_minutes: float, day_count: int) -> Dictionary:
    return {
        "type": ACTION_UPDATE_WORLD_TIME,
        "payload": {
            "world_hour": hour,
            "world_minute": minute,
            "world_total_minutes": total_minutes,
            "world_day_count": day_count,
        },
    }

static func set_world_time(hour: int, minute: int) -> Dictionary:
    return {
        "type": ACTION_SET_WORLD_TIME,
        "payload": {"hour": hour, "minute": minute},
    }

static func set_world_time_speed(mps: float) -> Dictionary:
    return {
        "type": ACTION_SET_WORLD_TIME_SPEED,
        "payload": mps,
    }
```

---

### Commit 3: U_TimeReducer

**Files to create**:

- `scripts/state/reducers/u_time_reducer.gd`

**Implementation**:

```gdscript
extends RefCounted
class_name U_TimeReducer

static func reduce(state: Dictionary, action: Dictionary) -> Variant:
    var action_type: Variant = action.get("type")

    match action_type:
        U_TimeActions.ACTION_UPDATE_PAUSE_STATE:
            var payload: Dictionary = action.get("payload", {})
            return _with_values(state, {
                "is_paused": payload.get("is_paused", false),
                "active_channels": payload.get("active_channels", []),
            })

        U_TimeActions.ACTION_UPDATE_TIMESCALE:
            var scale: float = clampf(float(action.get("payload", 1.0)), 0.01, 10.0)
            return _with_values(state, {"timescale": scale})

        U_TimeActions.ACTION_UPDATE_WORLD_TIME:
            var payload: Dictionary = action.get("payload", {})
            var hour: int = int(payload.get("world_hour", 8))
            return _with_values(state, {
                "world_hour": hour,
                "world_minute": int(payload.get("world_minute", 0)),
                "world_total_minutes": float(payload.get("world_total_minutes", 480.0)),
                "world_day_count": int(payload.get("world_day_count", 1)),
                "is_daytime": hour >= 6 and hour < 18,
            })

        U_TimeActions.ACTION_SET_WORLD_TIME:
            var payload: Dictionary = action.get("payload", {})
            var hour: int = clampi(int(payload.get("hour", 8)), 0, 23)
            var minute: int = clampi(int(payload.get("minute", 0)), 0, 59)
            var total: float = float(int(state.get("world_day_count", 1)) - 1) * 1440.0 + float(hour * 60 + minute)
            return _with_values(state, {
                "world_hour": hour,
                "world_minute": minute,
                "world_total_minutes": total,
                "is_daytime": hour >= 6 and hour < 18,
            })

        U_TimeActions.ACTION_SET_WORLD_TIME_SPEED:
            var speed: float = maxf(float(action.get("payload", 1.0)), 0.0)
            return _with_values(state, {"world_time_speed": speed})

        _:
            return null

static func _with_values(state: Dictionary, updates: Dictionary) -> Dictionary:
    var next := state.duplicate(true)
    for key in updates.keys():
        next[key] = updates[key]
    return next
```

---

### Commit 4: U_TimeSelectors

**Files to create**:

- `scripts/state/selectors/u_time_selectors.gd`

**Implementation**:

```gdscript
extends RefCounted
class_name U_TimeSelectors

static func get_is_paused(state: Dictionary) -> bool:
    return state.get("time", {}).get("is_paused", false)

static func get_active_channels(state: Dictionary) -> Array:
    return state.get("time", {}).get("active_channels", [])

static func get_timescale(state: Dictionary) -> float:
    return float(state.get("time", {}).get("timescale", 1.0))

static func get_world_hour(state: Dictionary) -> int:
    return int(state.get("time", {}).get("world_hour", 8))

static func get_world_minute(state: Dictionary) -> int:
    return int(state.get("time", {}).get("world_minute", 0))

static func get_world_total_minutes(state: Dictionary) -> float:
    return float(state.get("time", {}).get("world_total_minutes", 480.0))

static func get_world_day_count(state: Dictionary) -> int:
    return int(state.get("time", {}).get("world_day_count", 1))

static func get_world_time_speed(state: Dictionary) -> float:
    return float(state.get("time", {}).get("world_time_speed", 1.0))

static func is_daytime(state: Dictionary) -> bool:
    return bool(state.get("time", {}).get("is_daytime", true))
```

---

### Commit 5: Slice Registration in M_StateStore

**Files to modify** (3 files):

**1. `scripts/state/m_state_store.gd`**:

```gdscript
# Add const (after line ~45):
const RS_TIME_INITIAL_STATE := preload("res://scripts/resources/state/rs_time_initial_state.gd")

# Add export (after line ~70):
@export var time_initial_state: Resource

# Update _initialize_slices() call to pass new param:
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
    vfx_initial_state,
    audio_initial_state,
    display_initial_state,
    localization_initial_state,
    time_initial_state  # NEW — 14th param
)
```

**2. `scripts/state/utils/u_state_slice_manager.gd`**:

```gdscript
# Add const (after line ~13):
const U_TIME_REDUCER := preload("res://scripts/state/reducers/u_time_reducer.gd")

# Extend initialize_slices() signature — add after localization_initial_state param:
static func initialize_slices(
    # ... existing params ...
    localization_initial_state: Resource = null,
    time_initial_state: Resource = null  # NEW
) -> void:

# Add time slice block (after localization slice block, ~line 142):
    # Time slice
    if time_initial_state != null:
        var time_config := RS_StateSliceConfig.new(StringName("time"))
        time_config.reducer = Callable(U_TIME_REDUCER, "reduce")
        time_config.initial_state = time_initial_state.to_dictionary()
        time_config.dependencies = []
        time_config.transient_fields = [
            StringName("is_paused"),
            StringName("active_channels"),
            StringName("timescale"),
        ]
        register_slice(slice_configs, state, time_config)
```

**3. `scenes/root.tscn`** (manual):

- Assign `resources/base_settings/state/cfg_time_initial_state.tres` to `M_StateStore.time_initial_state` export

---

### Commit 6: Wire M_TimeManager Store Dispatches

**Files to modify**:

- `scripts/managers/m_time_manager.gd`

**Changes**:

```gdscript
const U_TimeActions := preload("res://scripts/state/actions/u_time_actions.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")

# In _check_and_resync_pause_state, after pause_state_changed.emit:
if pause_changed:
    pause_state_changed.emit(_is_paused)
    # Sync time slice
    if _store:
        _store.dispatch(U_TimeActions.update_pause_state(
            _is_paused,
            _pause_system.get_active_channels()
        ))
        # Backward-compat mirror: sync gameplay.paused
        if _is_paused:
            _store.dispatch(U_GameplayActions.pause_game())
        else:
            _store.dispatch(U_GameplayActions.unpause_game())

# In _on_world_minute_changed:
func _on_world_minute_changed(_minute: int) -> void:
    if _store:
        var time_data: Dictionary = _world_clock.get_time()
        _store.dispatch(U_TimeActions.update_world_time(
            time_data.get("hour", 8),
            time_data.get("minute", 0),
            time_data.get("total_minutes", 480.0),
            time_data.get("day_count", 1),
        ))

# In _on_world_hour_changed:
func _on_world_hour_changed(hour: int) -> void:
    world_hour_changed.emit(hour)
    # NOTE: Do NOT call _on_world_minute_changed here.
    # U_WorldClock.advance() calls on_minute_changed BEFORE on_hour_changed,
    # so the minute callback has already dispatched update_world_time for this tick.
    # Calling it again here would cause a double-dispatch on every hour transition.
```

---

## Phase 5: Documentation

**Goal**: AGENTS.md updated with Time Manager patterns.

**Exit Criteria**: All tests from Phases 1–4 pass; AGENTS.md updated; ServiceLocator list current.

---

### Commit 1: AGENTS.md Update

**Files to modify**:

- `AGENTS.md`

**Add** after "Localization Manager Patterns" section:

```markdown
## Time Manager Patterns

### Overview

M_TimeManager replaces M_PauseManager as the central time authority. Provides layered pause channels,
timescale control, and a world simulation clock.

### ServiceLocator Access

- `U_ServiceLocator.get_service(StringName("time_manager"))` — primary lookup
- `U_ServiceLocator.get_service(StringName("pause_manager"))` — backward-compat alias (returns same node)

### Pause Channels

- `request_pause(channel)` / `release_pause(channel)` — reference-counted per channel
- Predefined: `U_PauseSystem.CHANNEL_UI`, `CHANNEL_CUTSCENE`, `CHANNEL_DEBUG`, `CHANNEL_SYSTEM`
- `CHANNEL_UI` auto-driven from overlay stack size (preserves M_PauseManager behavior)
- Gameplay runs only when ALL channels have count zero

### Timescale

- `set_timescale(scale)` — clamped [0.01, 10.0], default 1.0
- `get_scaled_delta(raw_delta)` — called by M_ECSManager._physics_process
- Transient — resets to 1.0 on save/load

### World Clock

- Advances in _physics_process when not paused; uses scaled delta
- `get_world_time()` returns {hour, minute, total_minutes, day_count}
- `is_daytime()` — configurable sunrise/sunset hours (default 6:00–18:00)
- Persisted — hour/minute/day_count/speed survive save/load
```

**Update** ServiceLocator service list:

```markdown
- Available services: ..., `"time_manager"`, ... (note: `"pause_manager"` is a backward-compat alias for `"time_manager"`)
```

---

## Success Criteria

### Phase 1 Complete

- [ ] U_PauseSystem unit tests pass (10 tests — written first, TDD)
- [ ] M_TimeManager pause integration tests pass (4 tests — written first, TDD)
- [ ] All 10 existing pause tests pass with M_TimeManager
- [ ] `is_paused()` returns correct values through overlay push/pop
- [ ] Cursor coordination unchanged (gameplay = locked, overlays = visible)
- [ ] `pause_state_changed` signal fires correctly
- [ ] `U_ServiceLocator.get_service("pause_manager")` returns M_TimeManager
- [ ] `test_style_enforcement.gd` passes
- [ ] `m_pause_manager.gd` deleted

### Phase 2 Complete

- [ ] U_TimescaleController unit tests pass (6 tests — written first, TDD)
- [ ] M_TimeManager timescale integration test passes (1 test — written first, TDD)
- [ ] `get_scaled_delta(1.0)` returns `0.5` when timescale is `0.5`
- [ ] Timescale clamped to `[0.01, 10.0]`
- [ ] `timescale_changed` signal emitted
- [ ] `M_ECSManager` passes scaled delta to all systems
- [ ] Fallback to raw delta when no time_manager available

### Phase 3 Complete

- [ ] U_WorldClock unit tests pass (11 tests — written first, TDD)
- [ ] M_TimeManager world clock integration test passes (1 test — written first, TDD)
- [ ] World clock advances during gameplay
- [ ] World clock stops when any pause channel active
- [ ] Hour/minute callbacks fire at correct transitions
- [ ] `world_hour_changed` signal emitted on hour change
- [ ] `is_daytime()` returns correct values
- [ ] `set_time()` / `set_speed()` work correctly

### Phase 4 Complete

- [ ] `time` slice registered in M_StateStore
- [ ] Transient fields (`is_paused`, `active_channels`, `timescale`) reset on save/load
- [ ] Persisted fields (`world_hour`, `world_minute`, etc.) survive save/load
- [ ] `gameplay.paused` mirror syncs on every pause transition
- [ ] `is_daytime` recomputed by reducer from world_hour

### Phase 5 Complete

- [ ] All 33 new tests pass (verified across Phases 1–4)
- [ ] All existing integration tests pass
- [ ] AGENTS.md updated with Time Manager Patterns section
- [ ] ServiceLocator service list includes `"time_manager"`

---

## Common Pitfalls

1. **RefCounted helpers cannot have signals**: `U_PauseSystem`, `U_TimescaleController`, `U_WorldClock` use `Callable` callbacks, not GDScript signals.

2. **`_process()` vs `_physics_process()` distinction**: Overlay resync polling MUST stay in `_process()` (matching M_PauseManager). World clock advance MUST use `_physics_process()` (matching ECS timing). Using the wrong one breaks either responsiveness or determinism.

3. **Dual ServiceLocator registration**: Must register M_TimeManager under BOTH `"time_manager"` AND `"pause_manager"`. Forgetting the alias breaks all existing code that looks up `"pause_manager"`.

4. **`test_style_enforcement.gd` has TWO locations to update**: The ECS systems prefix map (line 67) AND the root scene structure assertion (lines 303–337). Missing either causes test failures.

5. **Transient fields must use `StringName`**: `RS_StateSliceConfig.transient_fields` expects `StringName` entries, not plain strings.

6. **`gameplay.paused` mirror must be dispatched, not set directly**: Use `U_GameplayActions.pause_game()` / `unpause_game()`. The gameplay reducer already handles these actions.

7. **Slice registration order matters**: The `time_initial_state` parameter goes AFTER `localization_initial_state` in `initialize_slices()`. Adding it in the wrong position breaks all existing slices.

8. **`_on_world_hour_changed` must NOT call `_on_world_minute_changed`**: `U_WorldClock.advance()` fires the minute callback before the hour callback within the same tick. Calling the minute handler from inside the hour handler causes a double-dispatch of `update_world_time` on every hour transition. The minute callback alone is sufficient.

9. **5 additional production files have stale `M_PauseManager` comments** (not functional code — do not block Phase 1 completion, but can be cleaned up opportunistically): `m_scene_manager.gd`, `m_save_manager.gd`, `m_cursor_manager.gd`, `u_service_locator.gd`, `tests/unit/test_cursor_manager.gd`.

---

## Testing Commands

```bash
# Run all pause-related integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit

# Run unit integration tests (poc_pause, navigation, input_profile_selector)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/integration -gexit

# Run overlay stack sync tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_manager -gexit

# Run style enforcement tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Run time manager unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_time_manager -gexit

# Run ALL tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

---

## References

- [Time Manager Overview](time-manager-overview.md)
- [M_PauseManager source](../../scripts/managers/m_pause_manager.gd) (to be replaced)
- [U_StateSliceManager](../../scripts/state/utils/u_state_slice_manager.gd) (slice registration)
- [U_GameplayActions](../../scripts/state/actions/u_gameplay_actions.gd) (pause_game/unpause_game)

---

**END OF TIME MANAGER PLAN**
