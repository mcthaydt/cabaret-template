# Debug Manager Continuation Prompt

Use this prompt to resume Debug Manager implementation in a new session.

---

## Context

You are implementing a Debug Manager for a Godot 4.5 game using a Redux-style state architecture. The Debug Manager provides unified development-time debugging tools including telemetry logging, gameplay toggles, ECS inspection, and performance monitoring. All debug features are stripped from release builds.

## Documentation

Read these files before starting work:

1. `docs/debug manager/debug-manager-overview.md` - Architecture and API
2. `docs/debug manager/debug-manager-prd.md` - Requirements and specs
3. `docs/debug manager/debug-manager-tasks.md` - Implementation tasks with checkboxes
4. `AGENTS.md` - Project patterns and conventions

## Key Decisions

| Decision | Choice |
|----------|--------|
| Access method | F-keys: F1=Perf HUD, F2=ECS, F3=State (existing), F4=Toggle Menu |
| Build availability | Debug builds only (`OS.is_debug_build()` check) |
| State persistence | No persistence; reset on launch |
| State storage | Redux `debug` slice (extend existing) |
| Overlay pattern | CanvasLayer with `PROCESS_MODE_ALWAYS` |
| Telemetry storage | In-memory array, auto-save on exit |
| Log file location | `user://logs/debug_session_{timestamp}.json` |
| Export formats | JSON to file, JSON to clipboard |
| Time scale | Direct `Engine.time_scale` manipulation (range: 0.0 - 4.0) |
| ECS queries | Via M_ECSManager (existing API) |
| Visual debug aids | Manual geometry generation (no viewport debug settings for 3D) |
| Multiple overlays | Can coexist (independent toggles) |
| F3 migration | Move from M_StateStore to M_DebugManager |
| Log file cleanup | Auto-delete logs older than 7 days on startup |
| ECS overlay pagination | Paginated with 50 entities per page, dirty flag pattern for updates |
| Component value editing | Read-only (display only, no editing) |
| Platform scope | Desktop-only; mobile excluded via `OS.is_debug_build()` |
| Teleport implementation | PhysicsRayQueryParameters3D from camera through mouse position |

## Current Progress

**Last Updated**: 2025-12-27

**Completed Phases**:
- ⏳ **Phase 0**: Foundation - NOT STARTED

**Next Phase**: Phase 0 - Foundation

Check `debug-manager-tasks.md` for detailed task list and current phase. Look for `- [x]` vs `- [ ]`.

## Implementation Patterns

Follow existing codebase patterns:

- **Managers**: See `m_scene_manager.gd` - ServiceLocator registration, group fallback
- **Helpers**: See `scripts/managers/helpers/` - extracted logic with `u_` or `m_` prefix
- **Actions**: See `u_debug_actions.gd` - const action names, static creators, registry
- **Reducers**: See `u_debug_reducer.gd` - DEFAULT_STATE, match on action type
- **Selectors**: See `u_navigation_selectors.gd` - static methods returning state values
- **Overlays**: See `debug_state_overlay.gd` - CanvasLayer with PROCESS_MODE_ALWAYS
- **Events**: See `u_ecs_event_bus.gd` - subscribe/publish pattern

## Debug State Model

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

## Telemetry Log Entry Format

```gdscript
{
    "timestamp": 1234.567,       # Time.get_ticks_msec() / 1000.0
    "level": "INFO",             # DEBUG, INFO, WARN, ERROR
    "category": "scene",         # StringName for filtering
    "message": "Scene loaded",   # Human-readable
    "data": {                    # Optional structured data
        "scene_id": "gameplay_base"
    }
}
```

## Critical Notes

1. **Debug build gating**: All functionality gated by `OS.is_debug_build()` in `M_DebugManager._ready()`. Manager calls `queue_free()` in release builds.

2. **Migrate F3 from M_StateStore**: The existing F3 handling in `M_StateStore._input()` should be moved to M_DebugManager for centralized control.

3. **Overlays use PROCESS_MODE_ALWAYS**: Debug overlays must continue updating when game is paused.

4. **Systems query debug state**: ECS systems check debug toggles via `U_DebugSelectors` before processing (e.g., skip damage if god_mode).

5. **Time scale affects physics**: Setting `Engine.time_scale` affects `_physics_process` delta automatically.

6. **Telemetry is static**: `U_DebugTelemetry` uses static methods for global access (similar to `U_ECSEventBus`).

7. **Visual debug aids require manual geometry**: Godot 4.5 does not expose runtime 3D collision shape visibility. Phase 7 must generate ImmediateMesh/ArrayMesh wireframes manually for collision shapes, trigger zones, etc.

8. **ECS overlay performance**: Use dirty flag pattern and 100ms throttling to avoid frame hitches with many entities.

## Input Actions to Add

| Action | Key | Description |
|--------|-----|-------------|
| `debug_toggle_perf` | F1 | Toggle performance HUD |
| `debug_toggle_ecs` | F2 | Toggle ECS overlay |
| `toggle_debug_overlay` | F3 | Existing - state overlay |
| `debug_toggle_menu` | F4 | Toggle debug menu |

## File Structure

```
scripts/managers/
  m_debug_manager.gd                    # Core orchestrator

scripts/managers/helpers/
  u_debug_telemetry.gd                  # Logging helper
  u_debug_console_formatter.gd          # Console colors

scripts/debug/helpers/
  u_debug_perf_collector.gd             # Metrics collector
  u_debug_frame_graph.gd                # Frame graph

scripts/state/
  actions/u_debug_actions.gd            # EXTEND
  reducers/u_debug_reducer.gd           # EXTEND
  selectors/u_debug_selectors.gd        # CREATE

scenes/debug/
  debug_perf_hud.tscn                   # F1
  debug_ecs_overlay.tscn                # F2
  debug_state_overlay.tscn              # F3 (exists)
  debug_toggle_menu.tscn                # F4
```

## Next Steps

1. Check `debug-manager-tasks.md` for current phase
2. Find the first unchecked task `- [ ]`
3. Implement the task
4. Mark tasks complete as you finish them
5. Run tests after each phase

---

## Quick Start Prompt

Copy this to start a new session:

```
I'm continuing implementation of the Debug Manager.

Read the documentation at:
- docs/debug manager/debug-manager-overview.md
- docs/debug manager/debug-manager-tasks.md
- AGENTS.md

Check which phase I'm on and continue with the next unchecked task. Mark tasks complete as you finish them.
```
