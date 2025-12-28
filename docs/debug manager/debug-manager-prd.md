# Debug Manager PRD

## Overview

- **Feature name**: Debug Manager
- **Owner**: TBD
- **Target release**: TBD
- **Status**: READY FOR IMPLEMENTATION

## Problem Statement

Developers need comprehensive, unified debugging tools during development, but currently:

1. **Scattered debug functionality**: Debug features are spread across multiple files (`M_StateStore` handles F3 overlay, `U_DebugActions` has limited toggles, `U_ECSQueryMetrics` tracks performance separately).
2. **No structured logging**: No centralized telemetry with log levels, categories, or export capabilities.
3. **Limited gameplay toggles**: Only `disable_touchscreen` exists; common dev tools (god mode, speed modifiers) are missing.
4. **No ECS inspection**: Developers cannot browse entities, inspect component values, or monitor system execution at runtime.
5. **Basic performance visibility**: Metrics exist but are buried in the state overlay; no lightweight always-on HUD.

**Why now?** The core systems (ECS, state management, scene manager) are mature enough that development efficiency becomes critical. Without proper debug tools, developers spend excessive time on manual testing, log hunting, and state reconstruction.

## Goals

- **Unified debug access**: Single F-key shortcuts (F1-F4) for all debug overlays, managed by one orchestrator.
- **Structured telemetry**: Log levels (DEBUG/INFO/WARN/ERROR), categories, automatic event subscription, and export to files/clipboard.
- **Gameplay cheats**: God mode, infinite jump, speed modifiers, teleportation for rapid testing.
- **ECS inspection**: Runtime entity browser, component inspector, system execution view.
- **Performance HUD**: Lightweight, always-visible metrics (FPS, memory, draw calls, ECS/state performance).
- **Visual debug aids**: Runtime toggles for collision shapes, spawn points, trigger zones, entity labels.
- **Zero release impact**: All debug code stripped from release builds automatically.

## Non-Goals

- **No persistence**: Debug settings reset on launch; no saved debug profiles.
- **No remote telemetry**: Local files and clipboard only; no analytics or cloud export.
- **No release availability**: Debug features completely stripped from release builds (not hidden behind secret combos).
- **No async file writes**: Synchronous logging acceptable for debug builds.
- **No in-game console**: Command-line style input deferred; focus on visual toggles and overlays.
- **No mobile touch alternatives**: F-key overlays are desktop-only; mobile builds exclude debug manager entirely via `OS.is_debug_build()` gating.

## User Experience

### Primary Entry Points

1. **Performance HUD (F1)**:
   - Toggle lightweight corner HUD showing FPS, frame time graph, memory, draw calls.
   - Non-intrusive; can remain visible during gameplay.
   - Collapsible sections for detailed ECS/state metrics.

2. **ECS Overlay (F2)**:
   - Full-screen overlay for entity inspection.
   - Left panel: filterable entity list.
   - Center panel: component inspector with live values.
   - Right panel: system execution order with timing.

3. **State Overlay (F3)** [Existing]:
   - Full state JSON view.
   - Action history with payload inspection.
   - Performance metrics (dispatch times, signal counts).

4. **Toggle Menu (F4)**:
   - Tabbed interface for all debug toggles.
   - Tab 1: Gameplay Cheats (god mode, infinite jump, speed slider).
   - Tab 2: Visual Debug (collision shapes, spawn points, trigger zones).
   - Tab 3: System Toggles (disable gravity/input, time scale presets).

5. **Telemetry (Automatic)**:
   - Runs silently, logging game events to session log.
   - Auto-saves session log on exit.
   - Manual export via Toggle Menu button.

### UI Flow

```
F1 → Performance HUD (corner overlay, toggleable)
     ├── FPS counter + frame time graph
     ├── Memory / Draw calls section (collapsible)
     └── ECS / State metrics section (collapsible)

F2 → ECS Overlay (full-screen)
     ├── Entity List (filterable by tag/component)
     ├── Component Inspector (selected entity, live values)
     └── System View (execution order, timing, enable/disable)

F3 → State Overlay (full-screen) [EXISTING]
     ├── State JSON view
     ├── Action history list
     └── Action detail view

F4 → Toggle Menu (modal overlay)
     ├── Tab 1: Gameplay Cheats
     │   ├── [ ] God Mode
     │   ├── [ ] Infinite Jump
     │   ├── Speed Modifier slider (0.25x - 4x)
     │   └── [Teleport to Cursor] button
     ├── Tab 2: Visual Debug
     │   ├── [ ] Show Collision Shapes
     │   ├── [ ] Show Spawn Points
     │   ├── [ ] Show Trigger Zones
     │   └── [ ] Show Entity Labels
     └── Tab 3: System Toggles
         ├── [ ] Disable Gravity
         ├── [ ] Disable Input
         ├── Time Scale presets: [Freeze] [0.25x] [0.5x] [1x] [2x] [4x]
         └── [Export Telemetry] button
```

### Critical Interactions

**Toggle behavior**:
- First F-key press instantiates overlay (if not created).
- Subsequent presses toggle visibility.
- Multiple overlays can be visible simultaneously.
- Overlays use `PROCESS_MODE_ALWAYS` to update while paused.

**Telemetry flow**:
- M_DebugManager subscribes to ECS events and Redux actions on startup.
- Events are logged to session buffer with timestamp, level, category, message, data.
- On `_exit_tree()`, session log auto-saves to `user://logs/debug_session_{timestamp}.json`.
- Manual export via Toggle Menu copies to clipboard or saves to custom path.

**Toggle application**:
- Toggle changes dispatch Redux actions to `debug` slice.
- ECS systems query debug state via `U_DebugSelectors`.
- Time scale is applied directly via `Engine.time_scale`.

## Technical Considerations

### Existing Code Migration

**Move from M_StateStore to M_DebugManager**:

- F3 overlay toggle logic in `_input()` method.
- Overlay instantiation and visibility management.
- Debug overlay node reference.

**Keep in M_StateStore**:

- `get_performance_metrics()` - consumed by overlays.
- `get_action_history()` - consumed by state overlay.
- Performance tracking internals.

### Dependencies

- **M_StateStore**: Debug toggles stored in `debug` Redux slice; systems query via selectors; performance metrics consumed by HUD.
- **M_ECSManager**: Entity queries (`get_all_entity_ids`, `get_components_for_entity`, `get_systems`) for ECS overlay; query metrics for HUD.
- **U_ECSEventBus / U_StateEventBus**: Telemetry subscribes to game events.
- **U_ServiceLocator**: Manager registration for discovery.
- **Engine singleton**: `Engine.time_scale` for time control.
- **Performance singleton**: FPS, memory, draw call metrics.

### Debug State Extension

Extend existing `debug` slice with new fields:

```gdscript
const DEFAULT_DEBUG_STATE := {
    # Existing
    "disable_touchscreen": false,

    # Gameplay Cheats
    "god_mode": false,
    "infinite_jump": false,
    "speed_modifier": 1.0,

    # Visual Debug
    "show_collision_shapes": false,
    "show_spawn_points": false,
    "show_trigger_zones": false,
    "show_entity_labels": false,

    # System Toggles
    "disable_gravity": false,
    "disable_input": false,
    "time_scale": 1.0,
}
```

### ECS System Modifications

| System | Toggle | Modification |
|--------|--------|--------------|
| S_HealthSystem | `god_mode` | Skip damage processing when true |
| S_JumpSystem | `infinite_jump` | Skip `is_on_floor()` check when true |
| S_MovementSystem | `speed_modifier` | Multiply velocity by modifier |
| S_GravitySystem | `disable_gravity` | Skip gravity application when true |
| S_InputSystem | `disable_input` | Skip input capture when true |

### File Structure

```
scripts/managers/
  m_debug_manager.gd                    # Core orchestrator

scripts/managers/helpers/
  u_debug_telemetry.gd                  # Logging/export helper
  u_debug_console_formatter.gd          # Color-coded console output

scripts/debug/helpers/
  u_debug_perf_collector.gd             # FPS/memory/draw calls
  u_debug_frame_graph.gd                # Frame time history graph

scripts/state/
  actions/u_debug_actions.gd            # EXTEND
  reducers/u_debug_reducer.gd           # EXTEND
  selectors/u_debug_selectors.gd        # EXTEND (or CREATE)

scenes/debug/
  debug_perf_hud.tscn                   # NEW (F1)
  debug_ecs_overlay.tscn                # NEW (F2)
  debug_state_overlay.tscn              # EXISTS (F3)
  debug_toggle_menu.tscn                # NEW (F4)
```

### Input Actions

Add to `project.godot`:

| Action | Key | Description |
|--------|-----|-------------|
| `debug_toggle_perf` | F1 | Toggle performance HUD |
| `debug_toggle_ecs` | F2 | Toggle ECS overlay |
| `toggle_debug_overlay` | F3 | Existing - state overlay |
| `debug_toggle_menu` | F4 | Toggle debug menu |

### Debug Build Gating

```gdscript
func _ready() -> void:
    if not OS.is_debug_build():
        queue_free()
        return
```

Ensures:
- Manager removed in release builds.
- No overlays instantiated.
- No telemetry subscriptions.
- No input handling.
- Zero runtime overhead.

### Risks / Mitigations

| Risk | Mitigation |
|------|------------|
| Debug overhead affects gameplay testing | Lightweight HUD uses minimal draw calls; overlays only update when visible |
| Forgetting to remove debug code | `OS.is_debug_build()` check + manager self-removal |
| Log file accumulation | Document cleanup; consider auto-delete policy in future |
| ECS overlay performance with many entities | Pagination or filtering; only update visible entries |
| Time scale affecting UI | Overlays use `PROCESS_MODE_ALWAYS` and unscaled delta where needed |
| Concurrent overlay keypresses | Simple toggle logic; no queuing needed |

## Success Metrics

- **F-key responsiveness**: All overlays toggle in <50ms.
- **HUD accuracy**: FPS counter matches engine profiler within 1 FPS.
- **Telemetry coverage**: All defined events logged correctly.
- **Session export**: 100% of sessions auto-save on exit.
- **Toggle effectiveness**: All gameplay toggles apply immediately.
- **Release build clean**: Zero debug code or overhead in release.
- **ECS overlay usability**: Entity list updates in real-time; component values refresh per-frame.

## Configuration Details

### Overlay Behavior

- **Multiple overlays**: Can be visible simultaneously.
- **Process mode**: `PROCESS_MODE_ALWAYS` for all overlays.
- **Persistence**: None; visibility resets on launch.
- **Render layer**: CanvasLayer-based, above game content.

### Telemetry Configuration

- **Log file path**: `user://logs/debug_session_{timestamp}.json`
- **Session buffer**: In-memory array, no size limit (debug builds only)
- **Auto-save trigger**: `M_DebugManager._exit_tree()`
- **Export formats**: JSON (file) or JSON (clipboard)

### Toggle Ranges

| Toggle | Type | Range | Default |
|--------|------|-------|---------|
| god_mode | bool | - | false |
| infinite_jump | bool | - | false |
| speed_modifier | float | 0.25 - 4.0 | 1.0 |
| disable_gravity | bool | - | false |
| disable_input | bool | - | false |
| time_scale | float | 0.0 - 4.0 | 1.0 |
| show_collision_shapes | bool | - | false |
| show_spawn_points | bool | - | false |
| show_trigger_zones | bool | - | false |
| show_entity_labels | bool | - | false |

## Resolved Decisions

| Question | Decision |
|----------|----------|
| Overlay access method | Keyboard shortcuts (F1-F4) only |
| Telemetry export location | Local files + clipboard; no remote |
| Build availability | Debug builds only; stripped from release |
| State persistence | No persistence; reset on launch |
| Multiple overlays | Independent toggles; can coexist |
| Existing F3 handling | Migrate control to M_DebugManager |
| Time scale method | Direct `Engine.time_scale` |
| Visual debug aids | Phase 7 (collision, spawns, triggers, labels) |
| Log file cleanup | Auto-delete logs older than 7 days on startup |
| ECS overlay pagination | Paginated with 50 entities per page |
| Component value editing | Read-only (display only, no editing) |
| Teleport method | Raycast from camera to mouse position |
