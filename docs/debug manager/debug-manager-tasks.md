# Debug Manager Implementation Tasks

**Progress:** 0% (0 / 51 tasks complete)

**Status:** Ready for Implementation

---

## Phase 0: Foundation

**Exit Criteria:** M_DebugManager registered, F1-F4 keys print debug messages

- [ ] **Task 0.1**: Create `scripts/managers/m_debug_manager.gd`
  - Extend `Node`, class_name `M_DebugManager`
  - Add debug build check in `_ready()` with `queue_free()` for release
  - Add to `"debug_manager"` group
  - Preload overlay scenes (lazy instantiation)

- [ ] **Task 0.2**: Add M_DebugManager to `scenes/root.tscn`
  - Add node under Managers section
  - Position after existing managers

- [ ] **Task 0.3**: Register in `scripts/scene_structure/main.gd`
  - Add ServiceLocator registration: `U_ServiceLocator.register_service(StringName("debug_manager"), debug_manager_node)`
  - Follow existing manager registration pattern

- [ ] **Task 0.4**: Add input actions to `project.godot`
  - `debug_toggle_perf` → F1
  - `debug_toggle_ecs` → F2
  - Note: `toggle_debug_overlay` (F3) already exists
  - `debug_toggle_menu` → F4

- [ ] **Task 0.5a**: Implement F-key handling in M_DebugManager
  - Implement `_input(event)` method
  - Check for each debug action (F1, F2, F3, F4)
  - Call `_toggle_overlay(overlay_id)` for each
  - Guard against rapid toggle race condition (use instantiating flag)

- [ ] **Task 0.5b**: Remove F3 handling from M_StateStore
  - Remove `_input()` method from `M_StateStore`
  - Keep overlay instantiation code until M_DebugManager verified working
  - Test F3 works via M_DebugManager before removing

- [ ] **Task 0.6**: Create skeleton `u_debug_selectors.gd`
  - Create file at `scripts/state/selectors/u_debug_selectors.gd`
  - Add stub methods returning default values:
    - `is_god_mode(state) -> bool: return false`
    - `is_infinite_jump(state) -> bool: return false`
    - `get_speed_modifier(state) -> float: return 1.0`
    - (etc. for all selectors)
  - Prevents preload errors when ECS systems are modified in Phase 5

**Notes:**
- F3 currently handled in `M_StateStore._input()` - migrated in 0.5a/0.5b
- Skeleton selectors prevent editor errors during Phase 5 system modifications

---

## Phase 1: Debug State Extension

**Exit Criteria:** Can dispatch debug actions and query toggle state via selectors

- [ ] **Task 1.1**: Extend `scripts/state/actions/u_debug_actions.gd`
  - Add action constants:
    - `ACTION_SET_GOD_MODE`
    - `ACTION_SET_INFINITE_JUMP`
    - `ACTION_SET_SPEED_MODIFIER`
    - `ACTION_SET_SHOW_COLLISION_SHAPES`
    - `ACTION_SET_SHOW_SPAWN_POINTS`
    - `ACTION_SET_SHOW_TRIGGER_ZONES`
    - `ACTION_SET_SHOW_ENTITY_LABELS`
    - `ACTION_SET_DISABLE_GRAVITY`
    - `ACTION_SET_DISABLE_INPUT`
    - `ACTION_SET_TIME_SCALE`
  - Add action creators for each
  - Register in `_static_init()`

- [ ] **Task 1.2**: Extend `scripts/state/reducers/u_debug_reducer.gd`
  - Extend `DEFAULT_DEBUG_STATE` with all new fields
  - Add match cases for all new actions
  - Follow existing `_with_values()` pattern

- [ ] **Task 1.3**: Implement `scripts/state/selectors/u_debug_selectors.gd`
  - **DEPENDENCY**: Task 1.2 must be complete first (reducer defines state fields)
  - Update skeleton from Task 0.6 with real implementations
  - Use null-safe access: `state.get("debug", {}).get("field", default)`
  - Add selectors:
    - `is_god_mode(state) -> bool`
    - `is_infinite_jump(state) -> bool`
    - `get_speed_modifier(state) -> float`
    - `is_showing_collision_shapes(state) -> bool`
    - `is_showing_spawn_points(state) -> bool`
    - `is_showing_trigger_zones(state) -> bool`
    - `is_showing_entity_labels(state) -> bool`
    - `is_gravity_disabled(state) -> bool`
    - `is_input_disabled(state) -> bool`
    - `get_time_scale(state) -> float`
  - Follow existing selector pattern

**Notes:**
- Debug state is transient (not persisted to saves)

---

## Phase 2: Telemetry System

**Exit Criteria:** Events logged to console and session; export to file/clipboard works

- [ ] **Task 2.1**: Create `scripts/managers/helpers/u_debug_telemetry.gd`
  - Define `LogLevel` enum: `DEBUG = 0`, `INFO = 1`, `WARN = 2`, `ERROR = 3`
  - Static `_session_log: Array = []`
  - Static `_session_start_time: float`
  - Implement `log(level, category, message, data)` static method
  - Implement convenience methods: `log_debug`, `log_info`, `log_warn`, `log_error`
  - Implement `get_session_log() -> Array`
  - Implement `clear_session_log()`
  - Log "Session started" as first entry during initialization (captures session start time)

- [ ] **Task 2.2**: Create `scripts/managers/helpers/u_debug_console_formatter.gd`
  - Color constants for each level (using ANSI escape codes)
  - Implement `format_entry(entry: Dictionary) -> String`
  - Format: `[HH:MM:SS] [LEVEL] [category] message {data}`

- [ ] **Task 2.3**: Implement file export in U_DebugTelemetry
  - Implement `export_to_file(path: String) -> Error`
  - Create session wrapper: `{session_start, session_end, build_id, entries}`
  - Use JSON.stringify with formatting
  - Handle file write errors gracefully (log to console, continue session)

- [ ] **Task 2.4**: Implement clipboard export in U_DebugTelemetry
  - Implement `export_to_clipboard()`
  - Use `DisplayServer.clipboard_set()`
  - Same format as file export

- [ ] **Task 2.5**: Implement event subscriptions in M_DebugManager
  - Subscribe to `U_ECSEventBus` events:
    - `checkpoint_activated` → INFO
    - `entity_death` → INFO
    - `save_started`, `save_completed`, `save_failed` → INFO/ERROR
  - Subscribe to `M_StateStore.action_dispatched`:
    - `scene/transition_completed` → INFO
    - `gameplay/take_damage` → DEBUG

- [ ] **Task 2.6**: Implement log cleanup (auto-delete >7 days old)
  - In `M_DebugManager._ready()` or U_DebugTelemetry init:
    - Create `user://logs/` directory if missing before cleanup
    - Scan `user://logs/` directory
    - Parse timestamps from filenames
    - Delete files older than 7 days

- [ ] **Task 2.7**: Implement session auto-save
  - In `M_DebugManager._exit_tree()`:
    - Create `user://logs/` directory if needed
    - Generate timestamp filename
    - Call `U_DebugTelemetry.export_to_file()`

**Notes:**
- Telemetry only active in debug builds (M_DebugManager gates this)
- Log cleanup runs on startup to prevent disk accumulation

---

## Phase 3: Performance HUD (F1)

**Exit Criteria:** F1 toggles performance HUD; metrics update in real-time

- [ ] **Task 3.1**: Create `scripts/debug/helpers/u_debug_perf_collector.gd`
  - Implement `get_metrics() -> Dictionary`:
    - `fps`: `Performance.get_monitor(Performance.TIME_FPS)`
    - `frame_time_ms`: `Performance.get_monitor(Performance.TIME_PROCESS) * 1000`
    - `memory_static_mb`: `Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576`
    - `memory_dynamic_mb`: `Performance.get_monitor(Performance.MEMORY_DYNAMIC) / 1048576`
    - `draw_calls`: `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`
    - `object_count`: `Performance.get_monitor(Performance.OBJECT_COUNT)`

- [ ] **Task 3.2**: Create `scripts/debug/helpers/u_debug_frame_graph.gd`
  - Extend `Control`
  - Circular buffer for 60 frame times
  - Implement `add_sample(frame_time_ms: float)`
  - Implement `_draw()` for line graph
  - Draw target line at 16.67ms (green)
  - Warning thresholds: yellow > 33.33ms, red > 50ms

- [ ] **Task 3.3**: Create `scenes/debug/debug_perf_hud.tscn`
  - CanvasLayer with layer 100 (above game, below other debug)
  - MarginContainer anchored top-left
  - VBoxContainer with:
    - FPS label
    - FrameGraph custom control
    - Collapsible Memory section
    - Collapsible Draw section
    - Collapsible ECS/State section

- [ ] **Task 3.4**: Create `scenes/debug/debug_perf_hud.gd`
  - Extend `CanvasLayer`, class_name `SC_DebugPerfHUD`
  - `process_mode = PROCESS_MODE_ALWAYS`
  - In `_process()`:
    - Update metrics via U_DebugPerfCollector
    - Update frame graph
    - Update ECS metrics via M_ECSManager
    - Update state metrics via M_StateStore
  - Implement section collapse/expand

- [ ] **Task 3.5**: Wire F1 toggle in M_DebugManager
  - Instantiate overlay on first toggle
  - Show/hide on subsequent toggles

**Notes:**
- HUD should be non-intrusive (corner position, minimal size)

---

## Phase 4: ECS Overlay (F2)

**Exit Criteria:** F2 shows entity browser; can select entity and see component values

- [ ] **Task 4.1**: Create `scenes/debug/debug_ecs_overlay.tscn`
  - CanvasLayer with layer 100
  - Full-screen panel with background
  - HSplitContainer for 3 columns:
    - Left: Entity list (VBoxContainer + ItemList)
    - Center: Component inspector (VBoxContainer + ScrollContainer)
    - Right: System view (VBoxContainer + ItemList)
  - Filter TextEdit above entity list

- [ ] **Task 4.2**: Create `scenes/debug/debug_ecs_overlay.gd`
  - Extend `CanvasLayer`, class_name `SC_DebugECSOverlay`
  - `process_mode = PROCESS_MODE_ALWAYS`
  - Store references to M_ECSManager
  - Track selected entity

- [ ] **Task 4.3**: Implement entity list with pagination (50 per page)
  - Use dirty flag pattern: only rebuild list when entities change
  - Subscribe to `entity_registered`/`entity_unregistered` events via U_ECSEventBus
  - **Add debounce**: accumulate changes for 100ms before rebuilding (prevents UI freeze during scene load)
    ```gdscript
    var _list_dirty := false
    var _rebuild_timer := 0.0

    func _on_entity_registered(_entity) -> void:
        _list_dirty = true  # Just mark dirty, don't rebuild

    func _process(delta: float) -> void:
        if _list_dirty:
            _rebuild_timer += delta
            if _rebuild_timer >= 0.1:  # 100ms debounce
                _rebuild_entity_list()
                _list_dirty = false
                _rebuild_timer = 0.0
    ```
  - Paginate results: show 50 entities per page
  - Add prev/next page buttons and page indicator (e.g., "Page 1 of 3")
  - Populate ItemList with current page entity IDs
  - Handle selection: store selected entity, trigger inspector update

- [ ] **Task 4.4**: Implement entity filtering
  - Filter by tag: TextEdit → `M_ECSManager.get_entities_by_tag()`
  - Filter by component: OptionButton → filter list
  - Clear filter button

- [ ] **Task 4.5**: Implement component inspector (read-only)
  - On entity selection: Query `M_ECSManager.get_components_for_entity()`
  - For each component:
    - Display component type name
    - List exported properties with current values (read-only, no editing)
  - Throttled update (100ms interval, not every frame) to avoid performance issues

- [ ] **Task 4.6**: Implement system execution view
  - Query `M_ECSManager.get_systems()`
  - Display: name, priority, enabled state
  - Checkbox to enable/disable (sets `process_mode`)
  - Show query metrics if available

- [ ] **Task 4.7**: Wire F2 toggle in M_DebugManager

**Notes:**
- Pagination: 50 entities per page with prev/next buttons (resolved decision)
- Component values are read-only (display only, no editing)

---

## Phase 5: ECS System Integration

**Exit Criteria:** All gameplay toggles affect game behavior

**Rationale:** System integration moved before Toggle Menu so toggles work when UI is built.

- [ ] **Task 5.1**: Modify `scripts/ecs/systems/s_health_system.gd`
  - Add state store query in `process_tick()`
  - Check `U_DebugSelectors.is_god_mode(state)`
  - Skip damage processing when true

- [ ] **Task 5.2**: Modify `scripts/ecs/systems/s_jump_system.gd`
  - Check `U_DebugSelectors.is_infinite_jump(state)`
  - Skip `is_on_floor()` check when true

- [ ] **Task 5.3**: Modify `scripts/ecs/systems/s_movement_system.gd`
  - Check `U_DebugSelectors.get_speed_modifier(state)`
  - Multiply velocity by modifier

- [ ] **Task 5.4**: Modify `scripts/ecs/systems/s_gravity_system.gd`
  - Check `U_DebugSelectors.is_gravity_disabled(state)`
  - Skip gravity when true

- [ ] **Task 5.5**: Modify `scripts/ecs/systems/s_input_system.gd`
  - Check `U_DebugSelectors.is_input_disabled(state)`
  - Skip input capture when true

- [ ] **Task 5.6**: Implement time scale in M_DebugManager
  - Subscribe to `debug` slice changes
  - On `time_scale` change: set `Engine.time_scale`
  - Use `TWEEN_PROCESS_IDLE` for any overlay animations to ignore time scale

- [ ] **Task 5.7**: Update AGENTS.md with Debug Manager Patterns
  - Add "Debug Manager Patterns" section documenting toggle query pattern for ECS systems
  - Document the U_DebugSelectors usage pattern in process_tick()
  - Example: `if U_DebugSelectors.is_god_mode(store.get_state()): return`

**Notes:**
- Systems already have state store injection support

---

## Phase 6: Toggle Menu (F4)

**Exit Criteria:** F4 opens toggle menu; toggling dispatches Redux actions

- [ ] **Task 6.1**: Create `scenes/debug/debug_toggle_menu.tscn`
  - CanvasLayer with layer 100
  - Centered panel (not full screen)
  - TabContainer with 3 tabs:
    - "Cheats"
    - "Visual"
    - "System"
  - Close button (X)

- [ ] **Task 6.2**: Create `scenes/debug/debug_toggle_menu.gd`
  - Extend `CanvasLayer`, class_name `SC_DebugToggleMenu`
  - `process_mode = PROCESS_MODE_ALWAYS`
  - Store reference to M_StateStore
  - Initialize controls from current state

- [ ] **Task 6.3**: Implement Cheats tab
  - God Mode: CheckBox → dispatch `set_god_mode`
  - Infinite Jump: CheckBox → dispatch `set_infinite_jump`
  - Speed Modifier: HSlider (0.25-4.0) → dispatch `set_speed_modifier`
  - Teleport button (placeholder for Phase 7)

- [ ] **Task 6.4**: Implement Visual tab
  - Show Collision Shapes: CheckBox → dispatch
  - Show Spawn Points: CheckBox → dispatch
  - Show Trigger Zones: CheckBox → dispatch
  - Show Entity Labels: CheckBox → dispatch

- [ ] **Task 6.5**: Implement System tab
  - Disable Gravity: CheckBox → dispatch
  - Disable Input: CheckBox → dispatch
  - Time Scale: HSlider or preset buttons (0, 0.25, 0.5, 1.0, 2.0, 4.0)
  - Export Telemetry: Button → call `U_DebugTelemetry.export_to_clipboard()`

- [ ] **Task 6.6**: Wire F4 toggle in M_DebugManager

**Notes:**
- Subscribe to state changes to keep UI in sync
- Toggles now functional (Phase 5 complete)

---

## Phase 7: Visual Debug Aids

**Exit Criteria:** Visual toggles show/hide debug geometry

**Note:** Godot 4.5 does not expose runtime collision shape visibility via viewport settings. Visual aids require creating debug geometry nodes manually.

- [ ] **Task 7.1**: Create `scripts/debug/helpers/u_debug_visual_aids.gd`
  - Extend `Node`, class_name `U_DebugVisualAids`
  - Subscribe to debug state changes via store
  - Track active debug geometry nodes for cleanup
  - **Scene transition handling**:
    - Subscribe to `scene/transition_started` Redux action
    - On transition start: clear all tracked geometry references
    - On transition complete: rebuild geometry for new scene if toggles still on
    - Use `is_instance_valid()` before accessing any geometry reference

- [ ] **Task 7.2**: Implement collision shape visualization
  - Iterate all CollisionShape3D nodes in scene tree
  - Generate ImmediateMesh or ArrayMesh wireframes from shape resources
  - Support: BoxShape3D, CapsuleShape3D, SphereShape3D, CylinderShape3D
  - Add/remove MeshInstance3D with wireframe material on toggle

- [ ] **Task 7.3**: Implement spawn point markers
  - Find all nodes in "spawn_points" group
  - Create Label3D + sphere MeshInstance3D marker above each spawn point
  - Use bright color (e.g., green) for visibility

- [ ] **Task 7.4**: Implement trigger zone outlines
  - Find all Area3D nodes with trigger controllers
  - Generate wireframe box/cylinder meshes from CollisionShape3D children
  - Use distinct color (e.g., yellow) from collision shapes

- [ ] **Task 7.5**: Implement entity ID labels
  - Find all entities via M_ECSManager.get_all_entity_ids()
  - Create Label3D nodes attached to entity root nodes
  - Display entity_id text floating above entity

- [ ] **Task 7.6**: Implement teleport-to-cursor
  - In Toggle Menu: connect teleport button
  - Create PhysicsRayQueryParameters3D from camera origin through mouse position
  - Use PhysicsDirectSpaceState3D.intersect_ray() for hit detection
  - Move player entity to hit.position

**Notes:**
- Visual aids require manual geometry generation (no viewport debug settings for 3D physics)
- All debug geometry should be cleaned up when toggled off or scene changes

---

## Phase 8: Testing & Polish

**Exit Criteria:** All tests pass; release build contains no debug code

- [ ] **Task 8.1**: Create `tests/unit/debug/test_debug_telemetry.gd`
  - Test log level filtering
  - Test export format (JSON structure)
  - Test session log structure

- [ ] **Task 8.2**: Create `tests/unit/debug/test_debug_reducer.gd`
  - Test all action handling
  - Test state mutations
  - Test default values

- [ ] **Task 8.3**: Create `tests/unit/debug/test_debug_selectors.gd`
  - Test all selector return values
  - Test with various state configurations

- [ ] **Task 8.4**: Create `tests/integration/debug/test_debug_toggles.gd`
  - Test dispatch toggle → verify system behavior
  - Test time scale → verify Engine.time_scale

- [ ] **Task 8.5**: Manual testing checklist
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

- [ ] **Task 8.6**: Performance assessment
  - Measure HUD update overhead (target < 1ms)
  - Measure telemetry logging overhead (target < 0.1ms)
  - Verify no overhead in release build

- [ ] **Task 8.7**: Release build verification
  - Build release: `godot --headless --export-release "Windows Desktop" build/release.exe`
  - Or for macOS: `godot --headless --export-release "macOS" build/release.app`
  - Verify M_DebugManager `queue_free()` called (check via logging or breakpoint)
  - Verify no F-key responses in release build
  - Verify no debug overlays appear
  - **Grep verification**: Search codebase for `m_debug_manager` references outside `/scripts/managers/` and `/scenes/debug/` folders

- [ ] **Task 8.8**: Update AGENTS.md with Debug Overlays section
  - Document F1-F4 keyboard shortcuts
  - Document overlay purposes and access patterns
  - Document debug build gating pattern

**Notes:**
- Follow existing GUT test patterns

---

## Notes

- Debug Manager gates all debug functionality via `OS.is_debug_build()`
- All overlays use `PROCESS_MODE_ALWAYS` to function during pause
- Debug state is transient (never persisted)
- F3 handling migrated from M_StateStore to M_DebugManager

---

## Links

- **PRD**: `docs/debug manager/debug-manager-prd.md`
- **Plan**: `docs/debug manager/debug-manager-plan.md`
- **Overview**: `docs/debug manager/debug-manager-overview.md`
- **Continuation Prompt**: `docs/debug manager/debug-manager-continuation-prompt.md`

---

## File Reference

### Files to Create

| File | Type | Description | Status |
|------|------|-------------|--------|
| `scripts/managers/m_debug_manager.gd` | Manager | Core orchestrator | ⏳ Pending |
| `scripts/managers/helpers/u_debug_telemetry.gd` | Helper | Logging helper | ⏳ Pending |
| `scripts/managers/helpers/u_debug_console_formatter.gd` | Helper | Console colors | ⏳ Pending |
| `scripts/debug/helpers/u_debug_perf_collector.gd` | Helper | Metrics collector | ⏳ Pending |
| `scripts/debug/helpers/u_debug_frame_graph.gd` | Helper | Frame graph | ⏳ Pending |
| `scripts/debug/helpers/u_debug_visual_aids.gd` | Helper | Visual debug aids | ⏳ Pending |
| `scripts/state/selectors/u_debug_selectors.gd` | Selector | Toggle selectors | ⏳ Pending |
| `scenes/debug/debug_perf_hud.tscn` | Scene | F1 overlay | ⏳ Pending |
| `scenes/debug/debug_perf_hud.gd` | Script | F1 controller | ⏳ Pending |
| `scenes/debug/debug_ecs_overlay.tscn` | Scene | F2 overlay | ⏳ Pending |
| `scenes/debug/debug_ecs_overlay.gd` | Script | F2 controller | ⏳ Pending |
| `scenes/debug/debug_toggle_menu.tscn` | Scene | F4 overlay | ⏳ Pending |
| `scenes/debug/debug_toggle_menu.gd` | Script | F4 controller | ⏳ Pending |
| `tests/unit/debug/test_debug_telemetry.gd` | Test | Telemetry tests | ⏳ Pending |
| `tests/unit/debug/test_debug_reducer.gd` | Test | Reducer tests | ⏳ Pending |
| `tests/unit/debug/test_debug_selectors.gd` | Test | Selector tests | ⏳ Pending |
| `tests/integration/debug/test_debug_toggles.gd` | Test | Integration tests | ⏳ Pending |

### Files to Modify

| File | Changes | Status |
|------|---------|--------|
| `scripts/state/actions/u_debug_actions.gd` | Add toggle actions | ⏳ Pending |
| `scripts/state/reducers/u_debug_reducer.gd` | Add toggle state | ⏳ Pending |
| `scripts/ecs/systems/s_health_system.gd` | Add god_mode check | ⏳ Pending |
| `scripts/ecs/systems/s_jump_system.gd` | Add infinite_jump check | ⏳ Pending |
| `scripts/ecs/systems/s_movement_system.gd` | Add speed_modifier | ⏳ Pending |
| `scripts/ecs/systems/s_gravity_system.gd` | Add disable check | ⏳ Pending |
| `scripts/ecs/systems/s_input_system.gd` | Add disable check | ⏳ Pending |
| `scenes/root.tscn` | Add M_DebugManager | ⏳ Pending |
| `scripts/scene_structure/main.gd` | Register with ServiceLocator | ⏳ Pending |
| `project.godot` | Add F1/F2/F4 input actions | ⏳ Pending |
