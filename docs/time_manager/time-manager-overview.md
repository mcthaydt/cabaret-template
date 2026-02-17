# Time Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-02-17
**Last Updated**: 2026-02-17
**Status**: PLANNING (Phase 0)
**Scope**: Layered pause channels, timescale control, world simulation clock

## Summary

`M_TimeManager` replaces `M_PauseManager` as the central time authority. It absorbs pause logic into a `U_PauseSystem` helper with layered channels, adds timescale control via `U_TimescaleController`, and introduces an in-game world simulation clock via `U_WorldClock`. `S_PlaytimeSystem` (elapsed gameplay time) remains in ECS unchanged. Runtime authority stays inside `M_TimeManager`; the Redux `time` slice is a synchronized mirror for persistence and selectors.

## Repo Reality Checks

- Main scene is `scenes/root.tscn`; service registration bootstrapped by `scripts/root.gd` via `U_ServiceLocator`.
- `M_PauseManager` currently at `scripts/managers/m_pause_manager.gd`, registered as `"pause_manager"` in ServiceLocator.
- Pause state is derived from `scene.scene_stack` size AND `UIOverlayStack` child count (OR logic). Engine pause applied via `get_tree().paused`.
- `M_PauseManager` coordinates cursor state with `M_CursorManager` based on pause state AND scene type.
- `M_PauseManager` uses `process_mode = PROCESS_MODE_ALWAYS`. It polls overlay state every `_process()` frame (not `_physics_process`) for the resync loop. This distinction is important — the new `M_TimeManager` must keep `_process()` for the overlay resync loop and add `_physics_process()` only for world clock advance.
- `U_NavigationSelectors.is_paused(state)` returns `true` only when `shell == "gameplay"` AND `overlay_stack.size() > 0`. It does NOT return `true` when overlays are open on the main menu shell.
- `U_GameplaySelectors.get_is_paused()` reads `gameplay.paused` from the state store.
- `S_PlaytimeSystem` tracks `gameplay.playtime_seconds` in ECS, incrementing during gameplay.
- `M_ECSManager._physics_process(delta)` passes raw `delta` to each system's `process_tick(delta)`.
- All helper scripts in this codebase extend `RefCounted` (e.g. `U_LocalizationCatalog`, `U_InputProfileLoader`). `RefCounted` cannot declare GDScript signals. Helper callbacks must use `Callable` patterns, not signals.
- Slice registration lives in **`U_StateSliceManager.initialize_slices()`** (not directly in `M_StateStore._ready()`). Adding a new slice requires extending the signature of `initialize_slices()` and adding an `@export` var to `M_StateStore`.
- Transient fields are stripped from both StateHandoff preservation and disk saves via `RS_StateSliceConfig.transient_fields`. StateHandoff is for cross-scene persistence (in-memory), not disk. The two mechanisms — handoff and disk save — both strip the same `transient_fields` list. Setting `RS_StateSliceConfig.is_transient = true` marks the ENTIRE slice as skipped during handoff restoration (used by the `navigation` slice).
- `test_style_enforcement.gd` line 337 unconditionally asserts `has_pause_manager` (which checks for an `M_PauseManager` node by name in `Managers`). Line 67 also carries `# m_ for M_PauseManager` in the ECS systems prefix table — that exception only exists because `m_pause_manager.gd` sits in the ECS systems folder. Both must be updated in Phase 1.

## Goals

- Replace binary pause with layered pause channels (UI, cutscene, debug, system).
- Provide timescale control so ECS systems receive scaled delta without per-system changes.
- Add an in-game world simulation clock (hours/minutes, day/night cycle, configurable speed).
- Maintain full backward compatibility with existing `"pause_manager"` service lookups, `is_paused()`, `pause_state_changed` signal, and all selectors.
- Persist world clock state (hour, minute, day count, speed) through the save system.

## Non-Goals

- No animation speed control (systems consuming scaled delta handle this implicitly).
- No per-entity timescale (all entities share a single global timescale).
- No real-world calendar or date system (world clock is hours/minutes only).
- No automatic day/night visual changes (world clock provides data; lighting/environment systems consume it separately).
- No changes to `S_PlaytimeSystem` (it continues tracking real elapsed gameplay time independently).

## Architecture

```
M_TimeManager (scripts/managers/m_time_manager.gd)  [extends Node]
  ├── U_PauseSystem (scripts/managers/helpers/time/u_pause_system.gd)  [extends RefCounted]
  │     Layered pause channels, derives final pause bool
  │     M_TimeManager applies get_tree().paused = <result>
  ├── U_TimescaleController (scripts/managers/helpers/time/u_timescale_controller.gd)  [extends RefCounted]
  │     Timescale multiplier, provides scaled delta
  └── U_WorldClock (scripts/managers/helpers/time/u_world_clock.gd)  [extends RefCounted]
        In-game world simulation clock (hours/minutes, day/night)
        Uses Callable callbacks instead of signals (RefCounted limitation)
```

**Important**: `U_PauseSystem` and `U_WorldClock` extend `RefCounted` and therefore cannot declare GDScript signals. Internal state-change notifications use `Callable` callbacks registered by `M_TimeManager` at construction time.

## Responsibilities & Boundaries

### M_TimeManager owns

- Pause channel management (delegates computation to `U_PauseSystem`; applies `get_tree().paused` itself).
- Timescale multiplier (delegates to `U_TimescaleController`).
- World simulation clock (delegates to `U_WorldClock`).
- Cursor coordination with `M_CursorManager` based on pause state AND scene type (ported from `M_PauseManager`).
- Redux `time` slice dispatches for pause/timescale/world-clock changes.
- Time slice hydration/reconciliation after store boot and save-load restore.
- Backward-compat sync of `gameplay.paused` mirror field.
- `_process()` loop for overlay resync polling (preserves existing `M_PauseManager` behavior).
- `_physics_process()` for world clock advance (aligns with ECS physics timing).

### M_TimeManager depends on

- `M_StateStore`: Subscribes to `scene` slice (pause derivation) and `time` slice (hydration/reconciliation); dispatches `time` and `gameplay` actions.
- `M_CursorManager`: Optional cursor coordination (same pattern as current `M_PauseManager`).
- `UIOverlayStack`: Direct polling for immediate pause detection (bridges state sync timing gap).
- `U_ServiceLocator`: Registration as both `"time_manager"` and `"pause_manager"` (backward compat).

### M_TimeManager does NOT own

- `S_PlaytimeSystem` (remains ECS, tracks real elapsed time independently).
- Visual day/night changes (world clock provides data; other systems consume it).
- Per-system delta scaling (ECS manager applies scaled delta uniformly).

## Public API

```gdscript
# --- Pause channels (delegates to U_PauseSystem) ---
func request_pause(channel: StringName) -> void
func release_pause(channel: StringName) -> void
func is_channel_paused(channel: StringName) -> bool
func is_paused() -> bool                           # backward compat
func get_active_pause_channels() -> Array[StringName]

# --- Timescale (delegates to U_TimescaleController) ---
func set_timescale(scale: float) -> void
func get_timescale() -> float
func get_scaled_delta(raw_delta: float) -> float

# --- World clock (delegates to U_WorldClock) ---
func get_world_time() -> Dictionary  # {hour, minute, total_minutes, day_count}
func set_world_time(hour: int, minute: int) -> void
func set_world_time_speed(minutes_per_real_second: float) -> void
func is_daytime() -> bool

# --- Signals ---
signal pause_state_changed(is_paused: bool)
signal timescale_changed(new_scale: float)
signal world_hour_changed(hour: int)
```

## U_PauseSystem Design

### Predefined Channels

| Channel Constant | StringName | Purpose |
|------------------|------------|---------|
| `CHANNEL_UI` | `&"ui"` | Overlays/menus open — auto-driven by overlay stack size (reserved, not manual) |
| `CHANNEL_CUTSCENE` | `&"cutscene"` | Cutscene playback |
| `CHANNEL_DEBUG` | `&"debug"` | Debug/editor pause |
| `CHANNEL_SYSTEM` | `&"system"` | System-level pause (loading, save operations) |

### Reference Counting

- Internal storage: `Dictionary` mapping `StringName` channel → `int` count.
- `request_pause(channel)` increments the channel's count for non-UI channels. Count 0→1 = channel becomes active.
- `release_pause(channel)` decrements (clamped to 0) for non-UI channels. Count 1→0 = channel becomes inactive.
- `compute_is_paused()` returns `true` if ANY channel has count > 0.
- Gameplay runs only when ALL channels have count zero.
- **`CHANNEL_UI` is manager-reserved and auto-driven**: `M_TimeManager` calls `derive_pause_from_overlay_state(overlay_count)` which sets or clears the UI channel count. Manual `request_pause(CHANNEL_UI)` / `release_pause(CHANNEL_UI)` should be treated as no-op to avoid ref-count corruption.

### Engine Pause Application

`U_PauseSystem` computes the boolean — it does NOT call `get_tree().paused` directly (it is a `RefCounted`, not a Node). `M_TimeManager._apply_pause_and_cursor_state()` calls `get_tree().paused = _pause_system.compute_is_paused()`.

### Derive Method

```gdscript
## Called by M_TimeManager when overlay count changes.
## Sets CHANNEL_UI count to 1 if overlays > 0, or 0 if none.
## CHANNEL_UI is reserved and should not be manually requested/released.
func derive_pause_from_overlay_state(overlay_count: int) -> void

## Returns true if any channel has count > 0.
func compute_is_paused() -> bool

## Returns list of channel names with count > 0.
func get_active_channels() -> Array[StringName]
```

## U_TimescaleController Design

- `set_timescale(scale)` — clamped to `[0.01, 10.0]`.
- `get_timescale()` — returns current multiplier (default `1.0`).
- `get_scaled_delta(raw_delta)` — returns `raw_delta * timescale`.
- No state persistence (timescale is transient, resets to `1.0` on load).

### ECS Integration

`M_ECSManager._physics_process(delta)` is the **only** ECS file that changes:

```gdscript
# Lazy-lookup time_manager via ServiceLocator (retry when unavailable/invalid)
if _time_manager == null or not is_instance_valid(_time_manager):
    _time_manager = U_ServiceLocator.try_get_service(StringName("time_manager"))

var scaled_delta: float = delta
if _time_manager:
    scaled_delta = _time_manager.get_scaled_delta(delta)

for system in _sorted_systems:
    system.process_tick(scaled_delta)
```

All systems automatically receive scaled delta with zero per-system changes.

## U_WorldClock Design

`U_WorldClock` extends `RefCounted`. It cannot declare GDScript signals. Instead it accepts `Callable` callbacks at construction time that `M_TimeManager` registers:

```gdscript
## M_TimeManager registers these during _ready():
_world_clock.on_minute_changed = _on_world_minute_changed
_world_clock.on_hour_changed   = _on_world_hour_changed
```

### Core State

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `total_minutes` | float | 480.0 | Accumulated minutes (0.0 – ∞, mod 1440 gives time of day) |
| `day_count` | int | 1 | Number of in-game days elapsed (increments when total_minutes crosses 1440 boundary) |
| `minutes_per_real_second` | float | 1.0 | World clock speed |

`hour` and `minute` are **derived** from `total_minutes` on each access — not stored separately:

```gdscript
var minutes_today: int = int(fmod(total_minutes, 1440.0))
var hour: int = minutes_today / 60   # integer division
var minute: int = minutes_today % 60
```

### Methods

```gdscript
func advance(scaled_delta: float) -> void   # Called by M_TimeManager._physics_process when not paused
func get_time() -> Dictionary                # {hour, minute, total_minutes, day_count}
func set_time(hour: int, minute: int) -> void
func set_state(total_minutes: float, day_count: int, minutes_per_real_second: float) -> void
func set_speed(minutes_per_real_second: float) -> void
func is_daytime() -> bool                    # Configurable sunrise/sunset hours (default 6:00–18:00)
```

### Advance Logic

```gdscript
func advance(scaled_delta: float) -> void:
    var prev_minutes_today: int = int(fmod(total_minutes, 1440.0))
    total_minutes += minutes_per_real_second * scaled_delta
    var new_minutes_today: int = int(fmod(total_minutes, 1440.0))
    # Day rollover — use while in case multiple days pass in one frame (high time speed)
    while total_minutes >= float(day_count) * 1440.0:
        day_count += 1
    # Minute change callback
    if new_minutes_today != prev_minutes_today and on_minute_changed != Callable():
        on_minute_changed.call(new_minutes_today % 60)
    # Hour change callback
    var prev_hour: int = prev_minutes_today / 60
    var new_hour: int = new_minutes_today / 60
    if new_hour != prev_hour and on_hour_changed != Callable():
        on_hour_changed.call(new_hour)
```

### Callbacks (not signals)

| Callable field | Signature | Raised when |
|----------------|-----------|-------------|
| `on_minute_changed` | `(minute: int) -> void` | Integer minute changes (coalesced to current frame state, not replayed minute-by-minute for large deltas) |
| `on_hour_changed` | `(hour: int) -> void` | Hour transitions — `M_TimeManager` re-emits as `world_hour_changed` (no extra store dispatch) |

## Redux Time Slice

### State Shape

```gdscript
{
    "time": {
        # Transient — reset on load, excluded from disk saves and StateHandoff
        "is_paused": false,
        "active_channels": [],
        "timescale": 1.0,
        # Persisted — included in disk saves and StateHandoff
        "world_hour": 8,
        "world_minute": 0,
        "world_total_minutes": 480.0,
        "world_day_count": 1,
        "world_time_speed": 1.0,
        # Computed — recomputed by reducer from world_hour on each time update; not persisted independently
        "is_daytime": true,
    }
}
```

### Runtime ↔ Store Sync Contract

- Runtime authority lives in `M_TimeManager` (`U_PauseSystem`, `U_TimescaleController`, `U_WorldClock`).
- `M_TimeManager` dispatches to `time` slice on:
  - pause transitions (`time/update_pause_state`)
  - timescale changes (`time/update_timescale`)
  - world-minute transitions and explicit set-time/speed API calls (`time/update_world_time`)
- `M_TimeManager` hydrates runtime values from `time` slice on initialization and on external restore flows (`load_state` / `apply_loaded_state`) by handling `slice_updated("time", ...)`.
- Slice reconciliation must be no-op when incoming state already matches runtime values to avoid feedback loops.

### Transient vs Persisted

Controlled by `RS_StateSliceConfig.transient_fields` (an `Array[StringName]`). Both `_preserve_to_handoff()` and `apply_loaded_state()` strip these fields from the slice before storing/applying, so they revert to initial values after every scene change or save/load.

| Field | Transient? |
|-------|------------|
| `is_paused` | Yes — stripped from handoff and disk saves |
| `active_channels` | Yes — stripped from handoff and disk saves |
| `timescale` | Yes — stripped from handoff and disk saves |
| `world_hour` | No — persisted |
| `world_minute` | No — persisted |
| `world_total_minutes` | No — persisted |
| `world_day_count` | No — persisted |
| `world_time_speed` | No — persisted |
| `is_daytime` | Computed field — recomputed each action, not persisted independently |

### Backward Compatibility

`gameplay.paused` is kept as a deprecated mirror of `time.is_paused`. The `gameplay` reducer already handles `ACTION_PAUSE_GAME` / `ACTION_UNPAUSE_GAME` — no reducer changes needed. `M_TimeManager` dispatches `U_GameplayActions.pause_game()` or `U_GameplayActions.unpause_game()` on every pause state transition to keep `gameplay.paused` in sync. Existing code reading `gameplay.paused` continues to work.

### Redux Files

| File | Class | Purpose |
|------|-------|---------|
| `scripts/state/actions/u_time_actions.gd` | `U_TimeActions` | Action creators |
| `scripts/state/reducers/u_time_reducer.gd` | `U_TimeReducer` | Pure reducer |
| `scripts/state/selectors/u_time_selectors.gd` | `U_TimeSelectors` | State selectors |
| `scripts/resources/state/rs_time_initial_state.gd` | `RS_TimeInitialState` | Initial state resource class |
| `resources/base_settings/state/cfg_time_initial_state.tres` | — | Default instance |

### Actions

| Action Constant | Payload | Description |
|-----------------|---------|-------------|
| `time/update_pause_state` | `{is_paused: bool, active_channels: Array}` | Sync pause state to store |
| `time/update_timescale` | `float` | Sync timescale to store |
| `time/update_world_time` | `{world_hour, world_minute, world_total_minutes, world_day_count}` | Dispatched on minute changes and explicit set-time/speed calls |
| `time/set_world_time` | `{hour: int, minute: int}` | Manual time set |
| `time/set_world_time_speed` | `float` | Change clock speed |

### Selectors

```gdscript
U_TimeSelectors.get_is_paused(state: Dictionary) -> bool
U_TimeSelectors.get_active_channels(state: Dictionary) -> Array[StringName]
U_TimeSelectors.get_timescale(state: Dictionary) -> float
U_TimeSelectors.get_world_hour(state: Dictionary) -> int
U_TimeSelectors.get_world_minute(state: Dictionary) -> int
U_TimeSelectors.get_world_day_count(state: Dictionary) -> int
U_TimeSelectors.get_world_time_speed(state: Dictionary) -> float
U_TimeSelectors.is_daytime(state: Dictionary) -> bool
```

## File Structure

```
scripts/managers/
    m_time_manager.gd                          # Main manager (replaces m_pause_manager.gd)

scripts/interfaces/
    i_time_manager.gd                          # Interface for dependency injection

scripts/managers/helpers/time/
    u_pause_system.gd                          # Layered pause channels (RefCounted)
    u_timescale_controller.gd                  # Timescale multiplier (RefCounted)
    u_world_clock.gd                           # World simulation clock (RefCounted, Callable callbacks)

scripts/state/actions/
    u_time_actions.gd                          # Time slice action creators

scripts/state/reducers/
    u_time_reducer.gd                          # Time slice reducer

scripts/state/selectors/
    u_time_selectors.gd                        # Time slice selectors

scripts/resources/state/
    rs_time_initial_state.gd                   # Initial state resource class

resources/base_settings/state/
    cfg_time_initial_state.tres                # Default initial state instance

tests/unit/managers/
    test_time_manager.gd                       # Unit + integration tests
```

## Implementation Phases

### Phase 1: Core Refactor — Replace M_PauseManager

**Goal**: `M_TimeManager` + `U_PauseSystem` replaces `M_PauseManager` with identical behavior.

**New files**: `m_time_manager.gd`, `i_time_manager.gd`, `u_pause_system.gd`

**Steps**:

1. Create `U_PauseSystem` (extends `RefCounted`) — channel dict, `request_pause`, `release_pause`, `compute_is_paused`, `get_active_channels`, `derive_pause_from_overlay_state(overlay_count)`.
2. Create `M_TimeManager` — port ALL logic from `m_pause_manager.gd`: store subscription, `_process()` overlay resync loop, cursor coordination, `pause_state_changed` signal. Owns `U_PauseSystem` instance. Calls `get_tree().paused = _pause_system.compute_is_paused()`. `process_mode = PROCESS_MODE_ALWAYS`.
3. Create `I_TimeManager` (extends `Node`) — minimal interface: `is_paused()`, `request_pause()`, `release_pause()`, `get_scaled_delta()`, `get_world_time()`.
4. Update `scripts/root.gd` — change `_register_if_exists(managers_node, "M_PauseManager", ...)` to `M_TimeManager`. Register the same node under BOTH `"time_manager"` AND `"pause_manager"`. Update dependency registrations accordingly.
5. Update `scenes/root.tscn` — rename node from `M_PauseManager` to `M_TimeManager`; swap script to `m_time_manager.gd`.
6. Update `test_style_enforcement.gd`:
   - Line 67: remove `# m_ for M_PauseManager` exception from ECS systems prefix map (delete `"m_"` from that entry).
   - Lines 303/322–323/337: rename `has_pause_manager` → `has_time_manager`, update the node name check to `"M_TimeManager"`, update the assert message.
7. Update all compile-time test references to `M_PauseManager` class name or `m_pause_manager.gd` path (see list below; verify with repo-wide `rg` before deleting the old file).
8. Delete `scripts/managers/m_pause_manager.gd`.

**All test files to update** (complete list from codebase scan):

| File | What changes |
|------|--------------|
| `tests/integration/scene_manager/test_pause_system.gd` | Preload path, type annotation |
| `tests/integration/scene_manager/test_particles_pause.gd` | `S_PAUSE_SYSTEM` const preload path |
| `tests/integration/scene_manager/test_pause_settings_flow.gd` | `S_PAUSE_SYSTEM` const preload path |
| `tests/integration/scene_manager/test_cursor_reactive_updates.gd` | Type annotation `M_PauseManager` |
| `tests/integration/scene_manager/test_scene_preloading.gd` | Const preload, type annotation |
| `tests/unit/integration/test_navigation_integration.gd` | Type annotation |
| `tests/unit/integration/test_input_profile_selector_overlay.gd` | Type annotation |
| `tests/unit/scene_manager/test_overlay_stack_sync.gd` | Type annotation |
| `tests/unit/integration/test_poc_pause_system.gd` | Type annotation, instantiation |
| `tests/unit/style/test_style_enforcement.gd` | Node name assertion + prefix map |

**Backward compatibility**:

- `U_ServiceLocator.get_service("pause_manager")` still returns valid node with `is_paused()`.
- `U_NavigationSelectors.is_paused(nav_state)` unchanged — reads `navigation.overlay_stack` directly and gates on `shell == "gameplay"`.
- `U_GameplaySelectors.get_is_paused()` unchanged — M_TimeManager syncs `gameplay.paused` via existing `U_GameplayActions.pause_game()` / `unpause_game()`.
- `pause_state_changed` signal name preserved.

### Phase 2: Timescale Support

**New file**: `u_timescale_controller.gd`

**Steps**:

1. Create `U_TimescaleController` (extends `RefCounted`) — `set_timescale(scale)` clamped `[0.01, 10.0]`, `get_scaled_delta(raw_delta)`.
2. Wire into `M_TimeManager` — expose `set_timescale()`, `get_timescale()`, `get_scaled_delta()`, emit `timescale_changed`.
3. Modify `m_ecs_manager.gd` `_physics_process(delta)` — lazy-lookup `time_manager` via ServiceLocator with retry (do not one-shot cache failure), call `time_manager.get_scaled_delta(delta)`, pass scaled delta to `system.process_tick()`. Fallback to raw delta if no time_manager.

### Phase 3: World Clock

**New file**: `u_world_clock.gd`

**Steps**:

1. Create `U_WorldClock` (extends `RefCounted`) — `Callable` fields `on_minute_changed` / `on_hour_changed`. Implement `advance(scaled_delta)`, `get_time()`, `set_time(hour, minute)`, `set_state(total_minutes, day_count, speed)`, `set_speed(mps)`, `is_daytime()` (configurable sunrise/sunset hours).
2. Wire into `M_TimeManager._ready()` — create `_world_clock`, register callbacks `_on_world_minute_changed` / `_on_world_hour_changed`.
3. Wire into `M_TimeManager._physics_process(delta)` — when not paused, call `_world_clock.advance(get_scaled_delta(delta))`.
4. In `_on_world_minute_changed`: dispatch `U_TimeActions.update_world_time()` to store.
5. In `_on_world_hour_changed`: emit `world_hour_changed` signal only (minute callback already handles store sync for that tick).

### Phase 4: Redux State & Persistence

**Files to create**: `u_time_actions.gd`, `u_time_reducer.gd`, `u_time_selectors.gd`, `rs_time_initial_state.gd`, `cfg_time_initial_state.tres`

**Files to modify** (3 files, not 1):

1. `scripts/resources/state/rs_time_initial_state.gd` — new resource class with `to_dictionary()`.
2. `scripts/state/m_state_store.gd` — add `@export var time_initial_state: RS_TimeInitialState` and pass it to `U_StateSliceManager.initialize_slices(...)`.
3. `scripts/state/utils/u_state_slice_manager.gd` — extend `initialize_slices()` signature with `time_initial_state: Resource = null` parameter; add a `time` slice block with `transient_fields = [StringName("is_paused"), StringName("active_channels"), StringName("timescale")]`.

**Steps**:

1. Create `RS_TimeInitialState` — all world clock fields as `@export` vars, `to_dictionary()` returns full state shape.
2. Create `U_TimeActions` — action constants (`time/update_pause_state`, `time/update_timescale`, `time/update_world_time`, `time/set_world_time`, `time/set_world_time_speed`), `_static_init()` registers all.
3. Create `U_TimeReducer` — pure `reduce(state, action)` function; for `time/update_world_time`, recompute `is_daytime` from the incoming `world_hour` field.
4. Create `U_TimeSelectors` — one static function per readable field.
5. Register the `time` slice in `U_StateSliceManager.initialize_slices()` with `transient_fields = [&"is_paused", &"active_channels", &"timescale"]`.
6. `M_TimeManager` dispatches `U_GameplayActions.pause_game()` / `unpause_game()` on pause transitions, dispatches `time/update_timescale` on timescale changes, and dispatches `time/update_world_time` on world-minute and explicit set-time/speed updates.
7. `M_TimeManager` hydrates `U_TimescaleController` + `U_WorldClock` from `time` slice on startup and external restore (`slice_updated("time", ...)`) using no-op reconciliation guards.
8. Create `cfg_time_initial_state.tres` as instance of `RS_TimeInitialState`; wire it to `M_StateStore.time_initial_state` in `root.tscn`.

### Phase 5: Documentation

**TDD note**: Tests are written within Phases 1–3 (not deferred to Phase 5). `test_time_manager.gd` is created in Phase 1 Commit 1 and extended in Phases 2–3. Total: 34 tests (10 + 6 + 12 unit + 4 + 1 + 1 integration).

**AGENTS.md updates**:

- Add "Time Manager Patterns" section.
- Update ServiceLocator service list (add `"time_manager"`; annotate `"pause_manager"` as backward-compat alias).
- Remove stale `# m_ for M_PauseManager` comment from ECS systems prefix notes.

## Verification Checklist

1. All existing pause integration tests pass with `M_TimeManager`.
2. `is_paused()` returns correct values through overlay push/pop.
3. Cursor coordination unchanged (gameplay = locked, overlays = visible/unlocked).
4. Setting timescale to 0.5 halves ECS system speed.
5. World clock advances during gameplay, stops when paused.
6. `U_NavigationSelectors.is_paused()` and `U_GameplaySelectors.get_is_paused()` unchanged.
7. Save/load preserves and rehydrates world clock state (hour, minute, total_minutes, day_count, speed).
8. `U_ServiceLocator.get_service("pause_manager")` still returns a node with `is_paused()`.
9. `test_style_enforcement.gd` passes with no assertion failures.
10. `on_minute_changed` callback fires exactly once per in-game minute.
11. `on_hour_changed` callback fires exactly once per in-game hour; `world_hour_changed` re-emits it.

## Resolved Questions

| Question | Decision |
|----------|----------|
| Where does pause logic live? | `U_PauseSystem` helper (RefCounted) computes boolean; `M_TimeManager` applies it to engine |
| How are pause channels reference-counted? | Dictionary mapping channel StringName → int count |
| Does U_PauseSystem call get_tree().paused? | No — it's RefCounted. M_TimeManager calls it |
| How do U_WorldClock and U_PauseSystem emit events? | Callable fields (not signals); RefCounted cannot declare signals |
| Is timescale per-entity? | No, single global timescale applied in `M_ECSManager` |
| Does world clock advance when paused? | No — only advances when all pause channels are clear |
| What is the world clock speed unit? | In-game minutes per real second (default 1.0) |
| How is backward compat maintained? | `"pause_manager"` registered as alias; `gameplay.paused` mirror kept via existing gameplay actions |
| Does S_PlaytimeSystem change? | No — tracks real elapsed time independently |
| Where does timescale scaling happen? | `M_ECSManager._physics_process()` — single integration point |
| Is timescale persisted? | No, transient — resets to 1.0 on load |
| Is world clock persisted? | Yes, hour/minute/total_minutes/day_count/speed persist in time slice and are rehydrated by M_TimeManager |
| How are transient fields excluded from saves? | Via `RS_StateSliceConfig.transient_fields` — stripped before both StateHandoff and disk saves |
| How many test files reference M_PauseManager? | 10 (including test_poc_pause_system.gd and test_style_enforcement.gd) |
| How many files does Phase 4 slice registration touch? | 3: `m_state_store.gd`, `u_state_slice_manager.gd`, new `rs_time_initial_state.gd` |
| What does U_NavigationSelectors.is_paused() actually check? | `shell == "gameplay"` AND `overlay_stack.size() > 0` — NOT paused when overlays are open in main_menu shell |
| Should M_TimeManager use _process or _physics_process? | Both — `_process()` for overlay resync loop (matches M_PauseManager behavior); `_physics_process()` for world clock advance |
