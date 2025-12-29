# Implementation Plan: Debug Manager System

**Branch**: `debug-manager` | **Date**: 2025-12-28 | **Spec**: [debug-manager-prd.md](./debug-manager-prd.md)
**Input**: Feature specification from `docs/debug manager/debug-manager-prd.md`

## Summary

The Debug Manager system provides unified development-time debugging tools for the Cabaret Ball project. It consolidates scattered debug functionality into a central orchestrator with:

- **Telemetry logging**: Structured logging with levels (DEBUG/INFO/WARN/ERROR), categories, and export.
- **Debug toggles**: Gameplay cheats (god mode, speed modifiers), visual aids (collision shapes), system controls (time scale).
- **ECS overlay**: Real-time entity browser, component inspector, system execution view.
- **Performance HUD**: FPS, memory, draw calls, ECS/state metrics.

**Technical approach**:
- M_DebugManager orchestrates all debug features, handles F1-F4 keyboard input.
- Debug state stored in Redux `debug` slice, queried by ECS systems via selectors.
- Telemetry uses static helper (`U_DebugTelemetry`) for global logging access.
- Overlays are CanvasLayer-based with `PROCESS_MODE_ALWAYS`.
- All code stripped from release builds via `OS.is_debug_build()` check.

## Technical Context

**Language/Version**: GDScript (Godot 4.5)
**Primary Dependencies**:
- Godot 4.5 engine
- Existing ECS framework (M_ECSManager, BaseECSComponent, BaseECSSystem)
- M_StateStore (Redux-style state management)
- U_ECSEventBus / U_StateEventBus (event buses)
- Existing debug_state_overlay.tscn (F3 overlay)

**Testing**: GUT framework for unit/integration tests
**Target Platform**: Debug builds only (stripped from release)

**Performance Goals**:
- Overlay toggle response: < 50ms
- HUD update overhead: < 1ms per frame
- Telemetry logging: < 0.1ms per entry
- Zero overhead in release builds

**Constraints**:
- **Debug builds only**: `OS.is_debug_build()` gating
- **No persistence**: Settings reset on launch
- **No autoloads**: Scene-tree-based architecture
- **Extend existing**: Build on existing debug slice and state overlay

## Project Structure

### Documentation

```text
docs/debug manager/
├── debug-manager-overview.md        # Feature overview
├── debug-manager-prd.md             # Feature specification
├── debug-manager-plan.md            # This file
├── debug-manager-tasks.md           # Task checklist
└── debug-manager-continuation-prompt.md  # Resume context
```

### Source Code

```text
# Manager
scripts/managers/
├── m_debug_manager.gd               # NEW - Core orchestrator

# Helpers
scripts/managers/helpers/
├── u_debug_telemetry.gd             # NEW - Logging helper
└── u_debug_console_formatter.gd     # NEW - Console colors

scripts/debug/helpers/
├── u_debug_perf_collector.gd        # NEW - Metrics collector
└── u_debug_frame_graph.gd           # NEW - Frame graph renderer

# State (extend existing)
scripts/state/
├── actions/u_debug_actions.gd       # MODIFY - Add toggle actions
├── reducers/u_debug_reducer.gd      # MODIFY - Add toggle handling
└── selectors/u_debug_selectors.gd   # MODIFY - Toggle selectors (file exists)

# Scenes
scenes/debug/
├── debug_state_overlay.tscn         # EXISTS (F3)
├── debug_perf_hud.tscn              # NEW (F1)
├── debug_ecs_overlay.tscn           # NEW (F2)
└── debug_toggle_menu.tscn           # NEW (F4)

# ECS (modify for toggles)
scripts/ecs/systems/
├── s_health_system.gd               # MODIFY - god_mode check
├── s_jump_system.gd                 # MODIFY - infinite_jump check
├── s_movement_system.gd             # MODIFY - speed_modifier apply
├── s_gravity_system.gd              # MODIFY - disable_gravity check
└── s_input_system.gd                # MODIFY - disable_input check
```

## Milestones

| Phase | Name | Deliverable | Dependency |
|-------|------|-------------|------------|
| 0 | Foundation | M_DebugManager skeleton, F-key input handling | None |
| 1 | Debug State | Extended Redux actions/reducer/selectors | Phase 0 |
| 2 | Telemetry | Logging helper with levels and export | Phase 0 |
| 3 | Perf HUD | F1 performance overlay | Phase 0, 1 |
| 4 | ECS Overlay | F2 entity/component/system inspector | Phase 0, 1 |
| 5 | System Integration | ECS systems query debug state | Phase 1 |
| 6 | Toggle Menu | F4 debug toggle UI | Phase 1 |
| 7 | Visual Aids | Collision/spawn/trigger visualization | Phase 1, 5 |
| 8 | Testing | Unit and integration tests | All |

## Work Breakdown

### Phase 0: Foundation (2-3 hours)

- [ ] Create `scripts/managers/m_debug_manager.gd`
  - Extend `Node`
  - Add debug build check in `_ready()` with `queue_free()` for release
  - Add to `"debug_manager"` group
  - Implement `_input()` for F-key handling
  - Create overlay toggle logic (instantiate on first use, show/hide on subsequent)

- [ ] Modify `scenes/main.tscn`
  - Add `M_DebugManager` node under Managers

- [ ] Modify `scripts/core/main.gd`
  - Register debug manager with ServiceLocator

- [ ] Add input actions to `project.godot`
  - `debug_toggle_perf` (F1)
  - `debug_toggle_ecs` (F2)
  - `debug_toggle_menu` (F4)
  - Note: `toggle_debug_overlay` (F3) already exists

- [ ] Migrate F3 handling from M_StateStore to M_DebugManager
  - Move overlay instantiation logic
  - Keep performance metrics in M_StateStore

- [ ] Ensure release builds disable debug overlay during migration
  - Gate the existing F3 toggle logic with `OS.is_debug_build()` (or override ProjectSettings in export presets)

**Exit criteria**: F1-F4 keys print debug messages; M_DebugManager registered in ServiceLocator.

### Phase 1: Debug State Extension (2-3 hours)

- [ ] Modify `scripts/state/actions/u_debug_actions.gd`
  - Add action constants for all toggles
  - Add action creators for each toggle
  - Register actions in `_static_init()`

- [ ] Modify `scripts/state/reducers/u_debug_reducer.gd`
  - Extend `DEFAULT_DEBUG_STATE` with all toggle fields
  - Add match cases for all new actions

- [ ] Extend `scripts/state/selectors/u_debug_selectors.gd`
  - Add selector for each toggle state
  - Follow existing selector pattern

- [ ] Exclude debug slice from persistence
  - Requirement: debug toggles reset on launch; saves must not contain debug state
  - Mark the `debug` slice transient (preferred) or filter it out of the persistence pipeline

**Exit criteria**: Can dispatch debug actions and query toggle state via selectors.

### Phase 2: Telemetry System (4-5 hours)

- [ ] Create `scripts/managers/helpers/u_debug_telemetry.gd`
  - Define `LogLevel` enum (DEBUG, INFO, WARN, ERROR)
  - Implement static `_session_log: Array`
  - Implement `log(level, category, message, data)` static method
  - Implement `log_debug/log_info/log_warn/log_error` convenience methods
  - Implement `get_session_log()` accessor
  - Implement `export_to_file(path)` with JSON formatting
  - Implement `export_to_clipboard()` via DisplayServer

- [ ] Create `scripts/managers/helpers/u_debug_console_formatter.gd`
  - Color codes for each log level
  - Formatted console output with timestamp/level/category

- [ ] Implement event subscriptions in M_DebugManager
  - Subscribe to `U_ECSEventBus` events
  - Subscribe to `M_StateStore.action_dispatched`
  - Log relevant events to telemetry

- [ ] Implement session auto-save
  - Save session log in `M_DebugManager._exit_tree()`
  - Path: `user://logs/debug_session_{timestamp}.json`

**Exit criteria**: Events logged to console and session; export to file/clipboard works.

### Phase 3: Performance HUD (4-5 hours)

- [ ] Create `scripts/debug/helpers/u_debug_perf_collector.gd`
  - Collect FPS, frame time, memory, draw calls via Performance monitors
  - Provide single `get_metrics()` method returning Dictionary

- [ ] Create `scripts/debug/helpers/u_debug_frame_graph.gd`
  - Circular buffer for 60 frame times
  - `_draw()` implementation for line graph
  - Target line at 16.67ms, warning thresholds

- [ ] Create `scenes/debug/debug_perf_hud.tscn`
  - CanvasLayer with corner positioning
  - FPS label, frame graph, collapsible metric sections

- [ ] Create `scenes/debug/debug_perf_hud.gd`
  - Update metrics each `_process()`
  - Pull ECS metrics from M_ECSManager
  - Pull state metrics from M_StateStore
  - Collapsible section logic

- [ ] Wire F1 toggle in M_DebugManager

**Exit criteria**: F1 toggles performance HUD; metrics update in real-time.

### Phase 4: ECS Overlay (6-8 hours)

**Performance note**: Entity/component updates should use throttling (100ms interval) or dirty flag pattern to avoid frame hitches with 100+ entities. Subscribe to `entity_registered`/`entity_unregistered` events for list changes.

- [ ] Create `scenes/debug/debug_ecs_overlay.tscn`
  - CanvasLayer with full-screen panel
  - Three-column layout: entity list, component inspector, system view

- [ ] Create `scenes/debug/debug_ecs_overlay.gd`
  - Entity list population via `M_ECSManager.get_all_entity_ids()`
  - Tag filter via TextEdit + `get_entities_by_tag()`
  - Component filter dropdown
  - Use dirty flag pattern: only rebuild list when entities change

- [ ] Implement component inspector
  - Selected entity display
  - Component list via `get_components_for_entity()`
  - Property display with exported values
  - Throttled update (100ms interval, not every frame)

- [ ] Implement system execution view
  - System list via `get_systems()`
  - Priority/execution order display
  - Query metrics timing display
  - Enable/disable checkbox (calls `system.set_debug_disabled(true/false)`)

- [ ] Wire F2 toggle in M_DebugManager

**Exit criteria**: F2 shows entity browser; can select entity and see component values.

### Phase 5: ECS System Integration (3-4 hours)

- [ ] Modify `scripts/ecs/systems/s_health_system.gd`
  - Query `U_DebugSelectors.is_god_mode(state)`
  - Skip damage processing when true

- [ ] Modify `scripts/ecs/systems/s_jump_system.gd`
  - Query `U_DebugSelectors.is_infinite_jump(state)`
  - Skip `is_on_floor()` check when true

- [ ] Modify `scripts/ecs/systems/s_movement_system.gd`
  - Query `U_DebugSelectors.get_speed_modifier(state)`
  - Multiply velocity by modifier

- [ ] Modify `scripts/ecs/systems/s_gravity_system.gd`
  - Query `U_DebugSelectors.is_gravity_disabled(state)`
  - Skip gravity when true

- [ ] Modify `scripts/ecs/systems/s_input_system.gd`
  - Query `U_DebugSelectors.is_input_disabled(state)`
  - Skip input capture when true

- [ ] Implement time scale in M_DebugManager
  - Subscribe to time_scale state changes
  - Apply via `Engine.time_scale`

**Exit criteria**: All gameplay toggles affect game behavior.

### Phase 6: Toggle Menu (4-5 hours)

- [ ] Create `scenes/debug/debug_toggle_menu.tscn`
  - CanvasLayer with centered panel
  - TabContainer with 3 tabs

- [ ] Create `scenes/debug/debug_toggle_menu.gd`
  - Tab 1: Gameplay Cheats
    - God mode checkbox
    - Infinite jump checkbox
    - Speed modifier slider (0.25 - 4.0)
    - Teleport button (deferred to Phase 7)
  - Tab 2: Visual Debug
    - Show collision shapes checkbox
    - Show spawn points checkbox
    - Show trigger zones checkbox
    - Show entity labels checkbox
  - Tab 3: System Toggles
    - Disable gravity checkbox
    - Disable input checkbox
    - Time scale preset buttons (0, 0.25, 0.5, 1.0, 2.0, 4.0)
    - Export telemetry button

- [ ] Wire toggle changes to Redux dispatch
- [ ] Wire F4 toggle in M_DebugManager

**Exit criteria**: F4 opens toggle menu; toggling dispatches Redux actions.

### Phase 7: Visual Debug Aids (4-5 hours)

**Note**: Godot 4.5 does not expose runtime collision shape visibility via viewport settings. Visual aids require creating debug geometry nodes manually.

- [ ] Create `scripts/debug/helpers/u_debug_visual_aids.gd`
  - Subscribe to debug state changes
  - Collision shapes: Generate ImmediateMesh or ArrayMesh wireframes from CollisionShape3D nodes
  - Spawn points: Create Label3D + sphere MeshInstance3D markers for each spawn
  - Trigger zones: Generate wireframe box/cylinder meshes from Area3D collision shapes
  - Entity labels: Create Label3D nodes attached to entities showing entity_id

- [ ] Implement teleport-to-cursor
  - Create PhysicsRayQueryParameters3D from camera origin through mouse position
  - Use PhysicsDirectSpaceState3D.intersect_ray() for hit detection
  - Move player entity to hit.position
  - Button in Toggle Menu Tab 1

**Exit criteria**: Visual toggles show/hide debug geometry.

### Phase 8: Testing & Polish (4-6 hours)

- [ ] Unit tests for `U_DebugTelemetry`
  - Log level filtering
  - Export format validation
  - Session log structure

- [ ] Unit tests for debug Redux
  - Action dispatch
  - State mutations
  - Selector returns

- [ ] Integration tests for toggles
  - Dispatch toggle -> verify system behavior

- [ ] Manual testing checklist
  - F1-F4 toggles
  - All toggle menu options
  - Telemetry export
  - Release build verification

- [ ] Performance assessment
  - Measure HUD update overhead
  - Measure telemetry logging overhead

**Exit criteria**: All tests pass; release build contains no debug code.

## Testing Strategy

### Unit Tests

| Test File | Coverage |
|-----------|----------|
| `test_debug_telemetry.gd` | Log levels, export, session structure |
| `test_debug_reducer.gd` | Action handling, state mutations, defaults |
| `test_debug_selectors.gd` | Selector return values |

### Integration Tests

| Test File | Coverage |
|-----------|----------|
| `test_debug_toggle_integration.gd` | Dispatch -> system behavior |
| `test_debug_time_scale.gd` | Time scale -> Engine.time_scale |

### Manual Tests

- [ ] F1 toggles performance HUD
- [ ] F2 toggles ECS overlay
- [ ] F3 toggles state overlay
- [ ] F4 toggles debug menu
- [ ] God mode prevents damage
- [ ] Infinite jump works mid-air
- [ ] Speed modifier affects movement
- [ ] Time scale affects physics
- [ ] Session log saves on exit
- [ ] Release build has no debug UI

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Debug overhead affects gameplay testing | Low | Medium | Lightweight HUD; overlays only update when visible |
| Debug code in release build | Low | High | `OS.is_debug_build()` check + manager self-removal |
| ECS overlay slow with many entities | Medium | Low | Pagination/filtering; lazy component loading |
| Time scale breaks UI | Low | Medium | Overlays use PROCESS_MODE_ALWAYS |
| Log file accumulation | Low | Low | Document cleanup; consider auto-delete |

## References

- [Debug Manager Overview](./debug-manager-overview.md)
- [Debug Manager PRD](./debug-manager-prd.md)
- [Debug Manager Tasks](./debug-manager-tasks.md)
- [Debug Manager Continuation Prompt](./debug-manager-continuation-prompt.md)
- [Existing State Overlay](../../scenes/debug/debug_state_overlay.gd)
- [ECS Manager](../../scripts/managers/m_ecs_manager.gd)
- [State Store](../../scripts/state/m_state_store.gd)
