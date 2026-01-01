# Debug Manager Overview

**Project**: Cabaret Template (Godot 4.5)
**Created**: 2025-12-27
**Last Updated**: 2025-12-31
**Status**: Phase 7 Complete (Phase 8 Pending)
**Scope**: Telemetry logging, debug toggles, ECS overlay, performance HUD

## Summary

The Debug Manager is a unified orchestration layer for all development-time debugging tools. It consolidates scattered debug functionality into a central system with telemetry logging, gameplay toggles (god mode, speed modifiers, etc.), ECS inspection (entity browser, component inspector), and performance monitoring (FPS, memory, draw calls). The manager is stripped from release builds and provides keyboard shortcuts (F1-F4) for rapid access to different debug overlays.

## Goals

- Provide a single manager for all debug functionality with F-key toggles.
- Enable structured telemetry logging with levels (DEBUG/INFO/WARN/ERROR) and automatic session export.
- Expose gameplay cheats (god mode, infinite jump, speed modifiers) via Redux state for ECS systems to query.
- Enable real-time ECS inspection (entity browsing, component values, system execution order).
- Display comprehensive performance metrics (FPS, frame time, memory, draw calls, ECS/state metrics).
- Strip all debug code from release builds automatically.

## Non-Goals

- No persistence of debug settings between sessions (reset on launch).
- No remote telemetry or analytics export (local files/clipboard only).
- No debug features in release builds (hidden or otherwise).
- No debug profile system (save/load named debug configurations).
- No advanced 3D visualization beyond the Phase 7 visual aids set (e.g., navmesh/AI debugging).

## Responsibilities & Boundaries

**Debug Manager owns**

- F-key input handling (F1=Perf HUD, F2=ECS Overlay, F3=State Overlay, F4=Toggle Menu).
- Overlay lifecycle (instantiate on first toggle, show/hide on subsequent toggles).
- Telemetry logging coordination (subscribe to events, auto-save session on exit).
- Time scale control via `Engine.time_scale`.
- Debug build gating (strip self in release builds).

**Debug Manager depends on**

- `M_StateStore`: Debug toggles stored in `debug` Redux slice; systems query via selectors.
- `M_ECSManager`: Entity queries, component inspection, system list for ECS overlay.
- `U_ECSEventBus` / `U_StateEventBus`: Event subscriptions for telemetry logging.
- `U_ServiceLocator`: Registration for discovery by other systems.

**Note on existing debug overlay**: `SC_StateDebugOverlay` (F3) is managed by `M_DebugManager` for centralized control.

## Public API

```gdscript
# Toggle overlay visibility (called internally via F-keys)
M_DebugManager.toggle_overlay(overlay_id: StringName) -> void

# Get current overlay visibility state
M_DebugManager.is_overlay_visible(overlay_id: StringName) -> bool

# Telemetry logging (static helper, globally accessible)
# Note: add_log() instead of log() to avoid conflict with GDScript built-in
U_DebugTelemetry.add_log(level: LogLevel, category: StringName, message: String, data: Dictionary = {})
U_DebugTelemetry.log_debug(category: StringName, message: String, data: Dictionary = {})
U_DebugTelemetry.log_info(category: StringName, message: String, data: Dictionary = {})
U_DebugTelemetry.log_warn(category: StringName, message: String, data: Dictionary = {})
U_DebugTelemetry.log_error(category: StringName, message: String, data: Dictionary = {})

# Telemetry export
U_DebugTelemetry.export_to_clipboard() -> void
U_DebugTelemetry.export_to_file(path: String) -> Error
U_DebugTelemetry.get_session_log() -> Array

# Debug state selectors (query from Redux state)
U_DebugSelectors.is_god_mode(state: Dictionary) -> bool
U_DebugSelectors.is_infinite_jump(state: Dictionary) -> bool
U_DebugSelectors.get_speed_modifier(state: Dictionary) -> float
U_DebugSelectors.is_gravity_disabled(state: Dictionary) -> bool
U_DebugSelectors.is_input_disabled(state: Dictionary) -> bool
U_DebugSelectors.get_time_scale(state: Dictionary) -> float
U_DebugSelectors.is_showing_collision_shapes(state: Dictionary) -> bool
U_DebugSelectors.is_showing_spawn_points(state: Dictionary) -> bool
U_DebugSelectors.is_showing_trigger_zones(state: Dictionary) -> bool
U_DebugSelectors.is_showing_entity_labels(state: Dictionary) -> bool
```

## Debug State Model

### Redux Slice: `debug`

Extends existing `debug` slice (currently only has `disable_touchscreen`):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `disable_touchscreen` | bool | false | Existing - disables touchscreen input |
| `god_mode` | bool | false | Player takes no damage |
| `infinite_jump` | bool | false | Player can jump in air (no ground check) |
| `speed_modifier` | float | 1.0 | Movement speed multiplier (0.25 - 4.0) |
| `disable_gravity` | bool | false | Gravity system skips processing |
| `disable_input` | bool | false | Input system skips processing |
| `time_scale` | float | 1.0 | Engine time scale (0.0 = frozen, 0.25 = slow, 1.0 = normal, 4.0 = fast) |
| `show_collision_shapes` | bool | false | Render collision shapes (via generated wireframe meshes) |
| `show_spawn_points` | bool | false | Render spawn point markers |
| `show_trigger_zones` | bool | false | Render trigger zone outlines |
| `show_entity_labels` | bool | false | Render entity ID labels above entities |

**Note**: Debug state must be transient (not persisted to save files). The current codebase persists the `debug` slice unless explicitly excluded; implementation must mark the slice transient or filter it out of persistence.

## Overlay Architecture

### Overlay Registry

| Overlay ID | Shortcut | Scene | Description |
|------------|----------|-------|-------------|
| `perf_hud` | F1 | `debug_perf_hud.tscn` | Lightweight performance display (corner HUD) |
| `ecs_overlay` | F2 | `debug_ecs_overlay.tscn` | Entity browser, component inspector, system view |
| `state_overlay` | F3 | `debug_state_overlay.tscn` | Existing state JSON + action history overlay |
| `toggle_menu` | F4 | `debug_toggle_menu.tscn` | Tabbed menu for all debug toggles |

### Overlay Behavior

- **CanvasLayer-based**: Each overlay extends `CanvasLayer` for always-on-top rendering.
- **PROCESS_MODE_ALWAYS**: Overlays continue updating when game is paused.
- **Toggle behavior**: First press instantiates (if not yet created), subsequent presses toggle visibility.
- **Independence**: Multiple overlays can be visible simultaneously.
- **No persistence**: Overlay visibility resets on game restart.

## Telemetry System

### Log Levels

| Level | Color (Console) | Use Case |
|-------|-----------------|----------|
| DEBUG | Gray | Verbose development info (position updates, state changes) |
| INFO | White | Normal events (scene loaded, checkpoint activated) |
| WARN | Yellow | Recoverable issues (missing optional data, fallback used) |
| ERROR | Red | Failures (file not found, validation failed) |

### Log Entry Structure

```gdscript
{
    "timestamp": 1234.567,       # U_ECSUtils.get_current_time() (seconds)
    "level": "INFO",             # LogLevel enum name
    "category": "scene",         # StringName category for filtering
    "message": "Scene loaded",   # Human-readable message
    "data": {                    # Optional structured data
        "scene_id": "gameplay_base",
        "load_time_ms": 234
    }
}
```

### Automatic Event Subscriptions

Telemetry automatically logs these events when subscribed:

**ECS Events** (via `U_ECSEventBus`):
- `checkpoint_activated` -> INFO, category: `checkpoint`
- `entity_death` -> INFO, category: `gameplay`
- `damage_zone_entered` -> DEBUG, category: `gameplay`
- `victory_triggered` -> INFO, category: `gameplay`
- `save_started` / `save_completed` / `save_failed` -> INFO/ERROR, category: `save`

**Redux Actions** (via `M_StateStore.action_dispatched`):
- `scene/transition_completed` -> INFO, category: `scene`
- `gameplay/take_damage` -> DEBUG, category: `gameplay`
- `gameplay/reset_after_death` -> INFO, category: `gameplay` (respawn equivalent)

### Export Formats

**Session Log File** (`user://logs/debug_session_{timestamp}.json`):
```json
{
    "session_start": "2025-12-27T10:30:00Z",
    "session_end": "2025-12-27T11:45:00Z",
    "build_id": "0.1.0-dev",
    "entries": [
        { "timestamp": 0.0, "level": "INFO", "category": "system", "message": "Session started", "data": {} },
        ...
    ]
}
```

**Clipboard Export**: Same JSON format, formatted with tabs for readability.

## ECS Overlay Features

### Entity Browser (Left Panel)

- **Entity list**: All registered entities via `M_ECSManager.get_all_entity_ids()`.
- **Filter by tag**: TextEdit filter using `M_ECSManager.get_entities_by_tag()`.
- **Filter by component**: Dropdown to filter entities with specific component type.
- **Live updating**: List refreshes via throttling/dirty flag (e.g., 100ms debounce) to avoid hitches during scene load.

### Component Inspector (Center Panel)

- **Selected entity**: Click entity in list to inspect.
- **Component list**: All components on entity via `M_ECSManager.get_components_for_entity()`.
- **Property values**: Exported properties displayed with current values.
- **Live updating**: Values refresh via throttling (e.g., every 100ms), not every frame.
- **Read-only**: No editing (too complex for initial implementation).

### System Execution View (Right Panel)

- **System list**: All systems via `M_ECSManager.get_systems()`.
- **Execution order**: Sorted by priority (lower = earlier).
- **Timing**: Per-system `process_tick()` timing is not tracked by default; show execution order plus optional ECS query metrics instead.
- **Enable/disable toggle**: Checkbox calls `system.set_debug_disabled(true/false)` (not `process_mode`).

## Performance HUD Features

### Display Layout (Top-Left Corner)

```
FPS: 60 (16.7ms)
[========= ] Frame Graph (60 samples)

Memory: 128 MB static / 45 MB dynamic
Draw: 234 calls / 1,523 objects

ECS: 12 queries / 0.45ms avg
State: 156 dispatches / 0.02ms avg
```

### Metrics Sources

| Metric | Source |
|--------|--------|
| FPS | `Performance.get_monitor(Performance.TIME_FPS)` |
| Frame Time | `Performance.get_monitor(Performance.TIME_PROCESS)` |
| Memory (Static) | `Performance.get_monitor(Performance.MEMORY_STATIC)` |
| Memory (Dynamic) | `Performance.get_monitor(Performance.MEMORY_DYNAMIC)` |
| Draw Calls | `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` |
| Object Count | `Performance.get_monitor(Performance.OBJECT_COUNT)` |
| ECS Query Metrics | `M_ECSManager.get_query_metrics()` |
| State Dispatch Metrics | `M_StateStore.get_performance_metrics()` |

### Frame Graph

- **60-sample circular buffer** of frame times.
- **Visual graph**: Simple line/bar graph showing frame time history.
- **Target line**: Green line at 16.67ms (60 FPS target).
- **Warning threshold**: Yellow above 33.33ms (30 FPS), red above 50ms (20 FPS).

## Toggle Menu Features

### Tab Structure

**Tab 1: Gameplay Cheats**
- [ ] God Mode (invincibility)
- [ ] Infinite Jump (no ground check)
- Speed Modifier: [0.25x] [0.5x] [1x] [2x] [4x] slider

**Tab 2: Visual Debug**
- [ ] Show Collision Shapes
- [ ] Show Spawn Points
- [ ] Show Trigger Zones
- [ ] Show Entity Labels

**Tab 3: System Toggles**
- [ ] Disable Gravity
- [ ] Disable Input
- Time Scale: [Freeze] [0.25x] [0.5x] [1x] [2x] [4x] preset buttons

### Redux Integration

Each toggle dispatches a Redux action:
```gdscript
store.dispatch(U_DebugActions.set_god_mode(true))
store.dispatch(U_DebugActions.set_speed_modifier(2.0))
store.dispatch(U_DebugActions.set_time_scale(0.5))
```

ECS systems query state via selectors:
```gdscript
var state := store.get_state()
if U_DebugSelectors.is_god_mode(state):
    # Skip damage processing
    return
```

## ECS System Integration

### Systems Modified

| System | Toggle | Behavior |
|--------|--------|----------|
| `S_HealthSystem` | `god_mode` | Skip damage application |
| `S_JumpSystem` | `infinite_jump` | Skip `is_on_floor()` check |
| `S_MovementSystem` | `speed_modifier` | Multiply movement velocity |
| `S_GravitySystem` | `disable_gravity` | Skip gravity application |
| `S_InputSystem` | `disable_input` | Skip input capture |

### Time Scale Implementation

Handled directly by `M_DebugManager`:
```gdscript
func _on_time_scale_changed(new_scale: float) -> void:
    Engine.time_scale = new_scale
```

**Note**: Time scale affects `_physics_process` delta, so ECS systems automatically slow down.

## File Structure

```
scripts/managers/
  m_debug_manager.gd                    # Core orchestrator

scripts/managers/helpers/
  u_debug_telemetry.gd                  # Logging/export helper
  u_debug_console_formatter.gd          # Color-coded console output

scripts/debug/helpers/
  u_debug_perf_collector.gd             # FPS/memory/draw calls collector
  u_debug_frame_graph.gd                # Frame time graph renderer

scripts/state/
  actions/u_debug_actions.gd            # EXTEND with toggle actions
  reducers/u_debug_reducer.gd           # EXTEND with toggle state
  selectors/u_debug_selectors.gd        # EXTEND with toggle selectors

scenes/debug/
  debug_state_overlay.tscn              # EXISTS (F3)
  debug_perf_hud.tscn                   # NEW (F1)
  debug_ecs_overlay.tscn                # NEW (F2)
  debug_toggle_menu.tscn                # NEW (F4)
```

## Input Actions

Add to `project.godot`:

| Action | Key | Description |
|--------|-----|-------------|
| `debug_toggle_perf` | F1 | Toggle performance HUD |
| `debug_toggle_ecs` | F2 | Toggle ECS overlay |
| `toggle_debug_overlay` | F3 | Existing - toggle state overlay |
| `debug_toggle_menu` | F4 | Toggle debug toggle menu |

## Debug Build Gating

```gdscript
# In M_DebugManager._ready():
func _ready() -> void:
    if not OS.is_debug_build():
        queue_free()
        return
    # ... normal initialization
```

This ensures:
- Manager node is removed in release builds.
- No debug overlays are instantiated.
- No telemetry subscriptions are created.
- No input handling for F-keys.
- Zero runtime overhead in release.

**Note**: Until the F3 overlay is migrated out of `M_StateStore._input()`, release builds must also disable the existing overlay toggle via export preset ProjectSettings (or add `OS.is_debug_build()` gating to the toggle).

## Testing Strategy

### Unit Tests

- `U_DebugTelemetry`: Log level filtering, export formatting, session log structure.
- `U_DebugReducer`: Action handling, state mutations, default values.
- `U_DebugSelectors`: Selector return values for all toggle states.

### Integration Tests

- Toggle functionality: Dispatch action -> verify system behavior change.
- Time scale: Dispatch `set_time_scale` -> verify `Engine.time_scale` updated.
- Overlay toggle: Simulate F-key input -> verify overlay visibility.

### Manual Testing

- F1-F4 key toggles work correctly.
- Performance HUD displays accurate metrics.
- ECS overlay shows entities/components correctly.
- Toggle menu persists state during session.
- Session log exports correctly on exit.

## Resolved Questions

| Question | Decision |
|----------|----------|
| Overlay access method | Keyboard shortcuts (F1-F4) only; no unified menu |
| Telemetry export location | Local files (`user://logs/`) + clipboard; no remote |
| Build availability | Debug builds only; stripped from release |
| State persistence | No persistence; reset all on launch |
| Multiple overlays | Can show simultaneously; independent toggle |
| Existing F3 overlay | Migrate control from M_StateStore to M_DebugManager |
| Time scale method | Direct `Engine.time_scale` manipulation |
| Visual debug aids | Manual geometry generation (no viewport debug settings for 3D) |
| Log file cleanup | Auto-delete logs older than 7 days on startup |
| Platform scope | Desktop-only; debug-build gated. Mobile lacks F-keys (optional extra gating via `OS.has_feature("mobile")`). |
