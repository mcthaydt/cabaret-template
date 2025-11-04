# ECS Debugger Plugin Implementation Plan

**Overall Progress:** `0%`

**Latest Update (2025-10-23):** ❌ First implementation attempt failed during integration; repository reverted to pre-plugin state. The ECS debugger plugin has been **de-scoped indefinitely**—the remaining tasks are archived for historical reference only.

---

## Class Names & File Structure

| Class Name | File Path | Type |
|------------|-----------|------|
| `U_ECSDebugDataSource` | `addons/ecs_debugger/u_ecs_debug_data_source.gd` | RefCounted, static methods |
| `P_ECSDebuggerPlugin` | `addons/ecs_debugger/plugin.gd` | EditorPlugin |
| `T_ECSDebuggerPanel` | `addons/ecs_debugger/t_ecs_debugger_panel.gd` | Control |
| `T_ECSDebuggerQueriesTab` | `addons/ecs_debugger/tabs/t_ecs_debugger_queries_tab.gd` | Control |
| `T_ECSDebuggerEventsTab` | `addons/ecs_debugger/tabs/t_ecs_debugger_events_tab.gd` | Control |
| `T_ECSDebuggerSystemOrderTab` | `addons/ecs_debugger/tabs/t_ecs_debugger_system_order_tab.gd` | Control |

---

## 1. 🟥 **Phase 1: Data Layer Foundation (TDD-First)**

### 1.1 Create U_ECSDebugDataSource Utility
- [ ] 🟥 Create `addons/ecs_debugger/u_ecs_debug_data_source.gd`
  - Extends `RefCounted`
  - `class_name U_ECSDebugDataSource`
  - All methods are `static`
- [ ] 🟥 **TDD**: Test `serialize_event_history()` returns pretty JSON (2-space indent)
  - Empty array case
  - Single event case
  - Multiple events case
- [ ] 🟥 **Implement**: `static func serialize_event_history(events: Array) -> String`
  - Use `JSON.stringify(events, "  ", false, true)` with 2-space indent
  - Returns formatted string
- [ ] 🟥 **TDD**: Test `format_query_metrics()` groups by complexity
  - Simple (1 required component)
  - Moderate (2-3 required components)
  - Complex (4+ required components)
  - Returns hierarchical Dictionary for Tree population
- [ ] 🟥 **Implement**: `static func format_query_metrics(metrics: Array) -> Dictionary`
  - Groups queries by `metrics[i]["required"].size()`
  - Returns: `{ "simple": [...], "moderate": [...], "complex": [...] }`
- [ ] 🟥 **TDD**: Test `format_system_list()` extracts system data
  - Returns: `[{ name, priority, script_path, is_disabled }, ...]`
  - Script path from `system.get_script().resource_path`
- [ ] 🟥 **Implement**: `static func format_system_list(systems: Array) -> Array`
- [ ] 🟥 Verify all data layer tests pass (`-gselect=test_ecs_debugger_plugin -gexit`)

---

## 2. 🟥 **Phase 2: Main Panel Container (TDD-First)**

### 2.1 Create T_ECSDebuggerPanel Structure
- [ ] 🟥 Create `addons/ecs_debugger/t_ecs_debugger_panel.gd`
  - Extends `Control`
  - `class_name T_ECSDebuggerPanel`
- [ ] 🟥 **TDD**: Test panel instantiates with correct UI structure
  - Panel contains VBoxContainer
  - VBoxContainer contains:
    - HBoxContainer (top controls: refresh slider, refresh button)
    - TabContainer (main content area)
  - TabContainer has 3 tabs: "Queries", "Events", "System Order"
- [ ] 🟥 **Implement**: Base panel structure
  ```gdscript
  # UI hierarchy:
  # T_ECSDebuggerPanel (Control)
  #   └─ VBoxContainer
  #      ├─ HBoxContainer (top_controls)
  #      │  ├─ Label ("Refresh Rate:")
  #      │  ├─ HSlider (refresh_slider)
  #      │  ├─ Label (rate_display)
  #      │  └─ Button ("Refresh Now")
  #      └─ TabContainer (main_tabs)
  #         ├─ T_ECSDebuggerQueriesTab
  #         ├─ T_ECSDebuggerEventsTab
  #         └─ T_ECSDebuggerSystemOrderTab
  ```

### 2.2 Manager Discovery & Refresh
- [ ] 🟥 **TDD**: Test `find_manager()` locates M_ECSManager
  - Searches "ecs_manager" group via `get_tree().get_nodes_in_group()`
  - Returns first manager or null
  - Uses `push_warning()` if multiple managers found
- [ ] 🟥 **Implement**: `func find_manager() -> M_ECSManager`
- [ ] 🟥 **TDD**: Test refresh button appears when no manager
  - When `manager == null`: Shows Label ("No ECS Manager Found") + Button ("Retry")
  - When `manager != null`: Hides message, shows tabs
- [ ] 🟥 **Implement**: State switching logic between no-manager and normal modes

### 2.3 Auto-Refresh Timer
- [ ] 🟥 **TDD**: Test configurable auto-refresh timer
  - Default interval: 0.5s
  - Range: 0.1s to 5.0s
  - HSlider updates Timer.wait_time
  - Label displays current rate (e.g., "0.5s")
- [ ] 🟥 **Implement**: Timer + HSlider controls
- [ ] 🟥 **TDD**: Test timer triggers tab refresh
  - On timeout: calls `queries_tab.refresh()`, `events_tab.refresh()`, `system_order_tab.refresh()`
  - Only refreshes if manager is valid
- [ ] 🟥 **Implement**: Timer timeout signal connections

---

## 3. 🟥 **Phase 3: Queries Tab (TDD-First)**

### 3.1 Create T_ECSDebuggerQueriesTab
- [ ] 🟥 Create `addons/ecs_debugger/tabs/t_ecs_debugger_queries_tab.gd`
  - Extends `Control`
  - `class_name T_ECSDebuggerQueriesTab`
- [ ] 🟥 **TDD**: Test Tree displays hierarchical structure
  - Root nodes: "Simple (1)", "Moderate (2-3)", "Complex (4+)"
  - Child nodes: Individual query entries with metrics
  - All groups collapsed by default (`TreeItem.collapsed = true`)
- [ ] 🟥 **Implement**: Tree widget with hierarchical population from `U_ECSDebugDataSource.format_query_metrics()`

### 3.2 Column View Toggle
- [ ] 🟥 **TDD**: Test switchable column views
  - Essential mode (4 columns): Query ID, Total Calls, Hit Rate %, Last Duration
  - Detailed mode (9 columns): + Required, Optional, Cache Hits, Result Count, Timestamp
  - Button label: "Show Detailed" / "Show Essential"
  - Hit Rate % calculated as: `(cache_hits / total_calls * 100).round()`
- [ ] 🟥 **Implement**: Button toggle logic + `Tree.set_column_title()` / `Tree.columns`
- [ ] 🟥 **TDD**: Test column state persists per session
  - State stored in member variable (not ProjectSettings)
  - Resets when panel destroyed
- [ ] 🟥 **Implement**: Session state storage

### 3.3 Data Refresh
- [ ] 🟥 **TDD**: Test `refresh(manager: M_ECSManager)` updates Tree
  - Calls `manager.get_query_metrics()`
  - Uses `U_ECSDebugDataSource.format_query_metrics()`
  - Rebuilds Tree structure
  - Preserves expand/collapse state using TreeItem.get_metadata()
- [ ] 🟥 **Implement**: `func refresh(manager: M_ECSManager) -> void`

---

## 4. 🟥 **Phase 4: Events Tab (TDD-First)**

### 4.1 Create T_ECSDebuggerEventsTab Structure
- [ ] 🟥 Create `addons/ecs_debugger/tabs/t_ecs_debugger_events_tab.gd`
  - Extends `Control`
  - `class_name T_ECSDebuggerEventsTab`
- [ ] 🟥 **TDD**: Test UI structure
  - VBoxContainer contains:
    - HBoxContainer (filter controls)
      - Label ("Filter:")
      - LineEdit (filter_input)
      - Label (event_count, right-aligned)
    - HSplitContainer
      - ItemList (event_list, left pane)
      - TextEdit (payload_display, right pane, read-only)
    - HBoxContainer (action buttons)
      - Button ("Export to Clipboard")
      - Button ("Clear History")
- [ ] 🟥 **Implement**: UI structure

### 4.2 Substring Filter & Display
- [ ] 🟥 **TDD**: Test substring filter (case-insensitive)
  - LineEdit updates ItemList in real-time
  - Filter matches event name (case-insensitive via `.to_lower()`)
  - "jump" matches "entity_jumped"
- [ ] 🟥 **Implement**: LineEdit signal + filtering logic
- [ ] 🟥 **TDD**: Test event display
  - ItemList shows: `[HH:MM:SS.mmm] event_name` (formatted timestamp)
  - Selecting item populates TextEdit with pretty-printed payload JSON
  - TextEdit uses syntax highlighting (if available)
- [ ] 🟥 **Implement**: ItemList population + selection handling

### 4.3 Event Count & Export
- [ ] 🟥 **TDD**: Test event count display
  - Shows: "Showing X events" (when X < history limit)
  - Shows: "Showing X events (oldest truncated)" (when at limit)
  - Dynamically checks `U_ECSEventBus._event_history.size()`
  - Updates on filter change
- [ ] 🟥 **Implement**: Event count label logic
- [ ] 🟥 **TDD**: Test clipboard export
  - Button calls `U_ECSDebugDataSource.serialize_event_history(filtered_events)`
  - Copies to `DisplayServer.clipboard_set()`
  - Shows brief feedback (e.g., button text changes to "Copied!" for 1s)
- [ ] 🟥 **Implement**: Export button with clipboard logic

### 4.4 Clear History
- [ ] 🟥 **TDD**: Test clear history with confirmation
  - Button shows `ConfirmationDialog` ("Clear all event history? This cannot be undone.")
  - On confirm: calls `U_ECSEventBus.clear_history()`
  - On confirm: calls `refresh()` to update UI
- [ ] 🟥 **Implement**: Clear button + ConfirmationDialog

### 4.5 Data Refresh
- [ ] 🟥 **TDD**: Test `refresh()` updates events
  - Calls `U_ECSEventBus.get_event_history()`
  - Applies current filter
  - Updates ItemList
  - Preserves selection if possible
- [ ] 🟥 **Implement**: `func refresh() -> void` (no manager param needed)

---

## 5. 🟥 **Phase 5: System Order Tab (TDD-First)**

### 5.1 Create T_ECSDebuggerSystemOrderTab
- [ ] 🟥 Create `addons/ecs_debugger/tabs/t_ecs_debugger_system_order_tab.gd`
  - Extends `Control`
  - `class_name T_ECSDebuggerSystemOrderTab`
- [ ] 🟥 **TDD**: Test Tree displays systems in priority order
  - Sorted by `execution_priority` (ascending: 0 → 1000)
  - Columns: System Name, Priority, Enabled (checkbox via `Tree.create_item()` + CELL_MODE_CHECK)
  - System names extracted from script path (e.g., "res://scripts/ecs/systems/s_input_system.gd" → "S_InputSystem")
- [ ] 🟥 **Implement**: Tree widget with system list

### 5.2 Enable/Disable Toggles
- [ ] 🟥 **TDD**: Test checkbox toggles system state
  - Checking box → `system.set_debug_disabled(false)` (system enabled)
  - Unchecking box → `system.set_debug_disabled(true)` (system disabled)
  - Disabled systems show grayed text + `"(disabled) "` prefix via `TreeItem.set_custom_color()`
- [ ] 🟥 **Implement**: Checkbox signal handling (`Tree.item_edited`) + visual feedback
- [ ] 🟥 **TDD**: Test visual indicators persist
  - Visual state matches `system.is_debug_disabled()`
  - Refreshing preserves visual state
- [ ] 🟥 **Implement**: Visual update logic

### 5.3 State Persistence
- [ ] 🟥 **TDD**: Test state persists to ProjectSettings
  - Key: `ecs_debugger/disabled_systems` (PackedStringArray of script paths)
  - On checkbox change: updates ProjectSettings + calls `ProjectSettings.save()`
  - On startup: loads from ProjectSettings, applies to matching systems
  - Uses script path as identifier: `system.get_script().resource_path`
- [ ] 🟥 **Implement**: ProjectSettings save/load logic
- [ ] 🟥 **TDD**: Test graceful handling of missing systems
  - If persisted system no longer exists, skip (no error)
  - If new system appears, default to enabled
- [ ] 🟥 **Implement**: Defensive loading logic

### 5.4 Data Refresh
- [ ] 🟥 **TDD**: Test `refresh(manager: M_ECSManager)` updates systems
  - Calls `manager.get_systems()`
  - Uses `U_ECSDebugDataSource.format_system_list()`
  - Rebuilds Tree with priority sorting
  - Loads persisted toggle states from ProjectSettings
  - Applies states to systems via `set_debug_disabled()`
- [ ] 🟥 **Implement**: `func refresh(manager: M_ECSManager) -> void`

---

## 6. 🟥 **Phase 6: Plugin Integration**

### 6.1 Create Plugin Files
- [ ] 🟥 Create `addons/ecs_debugger/plugin.cfg`
  ```ini
  [plugin]
  name="ECS Debugger"
  description="Runtime debugger for ECS architecture. Shows query metrics, event history, and system execution order."
  author="Your Team"
  version="1.0.0"
  script="plugin.gd"
  ```
- [ ] 🟥 Create `addons/ecs_debugger/plugin.gd`
  - Add `@tool` annotation
  - Extend `EditorPlugin`
  - `class_name P_ECSDebuggerPlugin`

### 6.2 Editor Integration
- [ ] 🟥 **Implement**: `func _enter_tree() -> void`
  ```gdscript
  var _panel: T_ECSDebuggerPanel = null

  func _enter_tree() -> void:
      _panel = T_ECSDebuggerPanel.new()
      add_control_to_bottom_panel(_panel, "ECS Debug")
  ```
- [ ] 🟥 **Implement**: `func _exit_tree() -> void`
  ```gdscript
  func _exit_tree() -> void:
      if _panel:
          remove_control_from_bottom_panel(_panel)
          _panel.queue_free()
          _panel = null
  ```
- [ ] 🟥 **Note**: Runtime usage
  - Panel works in editor only via EditorPlugin
  - For runtime debugging: users manually add `T_ECSDebuggerPanel` to their game UI
  - Document this in usage guide (Phase 8.2)

### 6.3 Manual Testing
- [ ] 🟥 Enable plugin in Godot editor (Project Settings → Plugins → ECS Debugger → Enable)
- [ ] 🟥 Verify bottom panel appears with "ECS Debug" tab
- [ ] 🟥 Open scene with M_ECSManager (e.g., `templates/base_scene_template.tscn`)
- [ ] 🟥 Verify manager detected, tabs populate
- [ ] 🟥 **Test Queries Tab:**
  - Tree shows hierarchical structure (Simple/Moderate/Complex)
  - Groups are collapsed by default
  - Expand groups, verify query metrics display
  - Toggle "Show Detailed" / "Show Essential" columns
  - Verify Hit Rate % calculation
- [ ] 🟥 **Test Events Tab:**
  - Verify events display in ItemList
  - Type "jump" in filter, verify filtering works (case-insensitive)
  - Select event, verify payload displays in TextEdit
  - Click "Export to Clipboard", verify JSON copied
  - Click "Clear History", confirm dialog, verify history cleared
- [ ] 🟥 **Test System Order Tab:**
  - Tree shows systems sorted by priority (0 → 1000)
  - Uncheck a system, verify it's disabled (grayed with "(disabled)" prefix)
  - Run scene, verify disabled system doesn't tick
  - Restart editor, verify disabled state persisted
- [ ] 🟥 **Test Refresh Controls:**
  - Adjust refresh rate slider (0.1s to 5.0s)
  - Verify auto-refresh timer respects new rate
  - Click "Refresh Now", verify immediate refresh
- [ ] 🟥 **Test No Manager Scenario:**
  - Open scene without M_ECSManager
  - Verify "No ECS Manager Found" message + "Retry" button
  - Add manager to scene, click "Retry", verify tabs appear

---

## 7. 🟥 **Phase 7: Test Suite Completion**

### 7.1 Verify Test Coverage
- [ ] 🟥 Create `tests/unit/ecs/test_ecs_debugger_plugin.gd`
  - Extend `GutTest` (or `BaseTest` if custom base exists)
- [ ] 🟥 **Data Layer Tests** (full coverage):
  - `test_serialize_event_history_empty_array()`
  - `test_serialize_event_history_single_event()`
  - `test_serialize_event_history_multiple_events()`
  - `test_serialize_event_history_pretty_format()` (verify 2-space indent)
  - `test_format_query_metrics_groups_by_complexity()`
  - `test_format_query_metrics_simple_queries()`
  - `test_format_query_metrics_moderate_queries()`
  - `test_format_query_metrics_complex_queries()`
  - `test_format_system_list_extracts_data()`
  - `test_format_system_list_includes_script_path()`
- [ ] 🟥 **UI Layer Tests** (basic instantiation):
  - `test_panel_instantiates()`
  - `test_panel_has_tab_container()`
  - `test_panel_has_three_tabs()`
  - `test_queries_tab_instantiates()`
  - `test_events_tab_instantiates()`
  - `test_system_order_tab_instantiates()`
  - `test_find_manager_returns_null_when_no_manager()`
  - `test_find_manager_finds_manager_in_group()`
- [ ] 🟥 Run full test suite: `Godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_ecs_debugger_plugin -gexit`
- [ ] 🟥 Verify all tests pass (expected: ~18 tests)
- [ ] 🟥 Confirm hybrid test approach:
  - ✅ Data layer: Full coverage (serialization, formatting, edge cases)
  - ✅ UI layer: Basic instantiation (panel exists, tabs created, controls present)
  - ⏭️ Skip: Detailed UI interactions (manual testing covers this)

### 7.2 Integration Verification
- [ ] 🟥 Run full ECS test suite with debugger enabled: `Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- [ ] 🟥 Verify no test failures (debugger doesn't break existing tests)
- [ ] 🟥 Run performance baseline: `Godot --headless --path . -s tests/perf/perf_ecs_baseline.gd`
- [ ] 🟥 Verify no performance regression (target: <3ms/frame, same as pre-debugger)
- [ ] 🟥 Verify no warnings/errors in console during tests

---

## 8. 🟥 **Phase 8: Documentation Update**

### 8.1 Update Plan & Architecture Docs
- [ ] 🟥 Mark Step 2.1 complete in `docs/ecs/ecs_refactor_plan.md`
  - Update status from 🟥 to 🟩
  - Add completion notes (test counts, file list)
- [ ] 🟥 Add debugger section to `docs/ecs/ecs_architecture.md`
  - New section: "§9 ECS Debugger Tool"
  - Describe panel tabs, refresh mechanism, persistence
- [ ] 🟥 Update `docs/ecs/for humans/ecs_continuation_prompt.md`
  - Add note about debugger availability
  - Reference usage guide

### 8.2 User Guide
- [ ] 🟥 Create `docs/ecs plugin tool/ecs_debugger_usage.md` with:
  - **Installation**: How to enable plugin in editor
  - **Queries Tab**: How to read query metrics, what Hit Rate % means, when to optimize
  - **Events Tab**: How to filter events, export for bug reports, clear history
  - **System Order Tab**: How to disable systems for debugging, persistence behavior
  - **Refresh Controls**: How to adjust refresh rate, manual refresh
  - **Runtime Usage**: How to add panel to game UI for runtime debugging
    ```gdscript
    # Example: Add to your debug overlay scene
    var debug_panel = preload("res://addons/ecs_debugger/t_ecs_debugger_panel.gd").new()
    add_child(debug_panel)
    # Panel will auto-find manager and refresh
    ```
  - **Troubleshooting**: "No Manager Found", multiple managers warning, performance tips

---

## Key Constraints & Design Decisions

**Architecture:**
- ✅ Pure code UI (no .tscn files) - all UI created programmatically via GDScript
- ✅ Static utility class (U_ECSDebugDataSource extends RefCounted, all methods static)
- ✅ Single M_ECSManager support (warn via `push_warning()` if multiple)
- ✅ Plugin-specific location (`addons/ecs_debugger/`)

**Runtime Capability:**
- ✅ Editor-only via EditorPlugin (automatic bottom panel)
- ✅ Runtime-capable via manual instantiation (users add panel to their game UI)
- ✅ No automatic runtime injection (keeps plugin simple)

**UX:**
- ✅ Configurable refresh rate: 0.1s to 5.0s (default 0.5s) via HSlider
- ✅ Hierarchical query tree (by complexity: Simple/Moderate/Complex, collapsed by default)
- ✅ Switchable query columns (Essential ↔ Detailed) via toggle button
- ✅ Event display: ItemList (name+timestamp) + TextEdit (payload)
- ✅ Case-insensitive event filtering via `.to_lower()`
- ✅ Pretty JSON clipboard export (2-space indent)
- ✅ Disabled systems show grayed text + `"(disabled) "` prefix via `TreeItem.set_custom_color()`

**Persistence:**
- ✅ System disable state → ProjectSettings (`ecs_debugger/disabled_systems`: PackedStringArray of script paths)
- ✅ Column view state → Session only (member variable, resets on restart)
- ✅ Tree expand/collapse → Session only (preserved during refresh via TreeItem metadata)

**Error Handling:**
- ✅ No manager found → Show "No ECS Manager Found" + "Retry" button
- ✅ Multiple managers → `push_warning("Multiple ECS managers found, using first")`, use first
- ✅ Event history truncation → Show "Showing X events (oldest truncated)"
- ✅ Clear events → ConfirmationDialog required
- ✅ Missing persisted systems → Skip gracefully (no error)

**Integration:**
- ✅ Uses existing `M_ECSManager.get_query_metrics()` (scripts/managers/m_ecs_manager.gd:109)
- ✅ Uses existing `ECSSystem.set_debug_disabled()` (scripts/ecs/ecs_system.gd:50)
- ✅ Uses existing `U_ECSEventBus.get_event_history()` (scripts/ecs/u_ecs_event_bus.gd:81)
- ✅ Uses existing `U_ECSEventBus.clear_history()` (scripts/ecs/u_ecs_event_bus.gd:73)
- ✅ Uses existing GUT testing framework (addons/gut/)
- ✅ Follows codebase conventions (U_ prefix, static methods, push_warning(), class_name)

---

## Technical Specifications

### Manager Discovery Behavior

**Runtime (Scene Playing - F5/F6):**
```gdscript
func find_manager() -> M_ECSManager:
    if not get_tree():
        return null
    var managers = get_tree().get_nodes_in_group("ecs_manager")
    if managers.is_empty():
        return null
    if managers.size() > 1:
        push_warning("ECS Debugger: Multiple managers found, using first")
    return managers[0] as M_ECSManager
```

**Editor (Not Playing):**
- `M_ECSManager` does NOT add itself to `"ecs_manager"` group (because `_ready()` doesn't run)
- `find_manager()` will return `null`
- Panel displays: **"No ECS Manager found. Run the scene (F5/F6) to see data."** + **Refresh** button

**Implication:** The debugger **only shows data when a scene is running**. This is the primary use case.

### Color Coding Thresholds

**Query Cache Hit Rate:**

| Range | Color | Hex Code | Usage |
|-------|-------|----------|-------|
| **≥80%** | Green | `#4CAF50` | Excellent cache performance |
| **50-79%** | Yellow | `#FFC107` | Moderate cache performance |
| **<50%** | Red | `#F44336` | Poor cache performance |

**Implementation:**
```gdscript
func get_hit_rate_color(hit_rate: float) -> Color:
    if hit_rate >= 80.0:
        return Color("#4CAF50")  # Green
    elif hit_rate >= 50.0:
        return Color("#FFC107")  # Yellow
    else:
        return Color("#F44336")  # Red
```

**Accessibility:** Colors have sufficient contrast (WCAG AA) and are always accompanied by numerical percentages for users with color vision deficiency.

### Visual Indicators for Disabled Systems

**Original Plan:** Strikethrough text
**Issue:** `TreeItem` doesn't natively support strikethrough in Godot 4.x

**Revised Approach:**
- Grayed text via `TreeItem.set_custom_color(0, Color(0.5, 0.5, 0.5))`
- Prefix system name with `"(disabled) "` for clarity

**Example:**
```
Normal System:     S_MovementSystem
Disabled System:   (disabled) S_MovementSystem  [grayed text]
```

**Implementation:**
```gdscript
func update_system_visual_state(item: TreeItem, is_disabled: bool) -> void:
    if is_disabled:
        item.set_text(0, "(disabled) " + system_name)
        item.set_custom_color(0, Color(0.5, 0.5, 0.5))
    else:
        item.set_text(0, system_name)
        item.clear_custom_color(0)
```

### Query Sorting Specification

**Between Groups:** Complexity-based hierarchy
1. Simple (1) — One required component (expanded by default)
2. Moderate (2-3) — Two to three required components (collapsed by default)
3. Complex (4+) — Four or more required components (collapsed by default)

**Within Each Group:** Sort by `last_run_time` (most recent first, descending)

**Grouping Logic:**
```gdscript
var simple = []
var moderate = []
var complex = []

for metric in metrics:
    var required_count := int(metric.get("required", []).size())
    if required_count == 1:
        simple.append(metric)
    elif required_count >= 2 and required_count <= 3:
        moderate.append(metric)
    else:
        complex.append(metric)

simple.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
moderate.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
complex.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
```

### Timer Pause-on-Hidden Behavior

**Goal:** Zero frame impact when debugger panel is hidden

**Implementation:**
```gdscript
# In T_ECSDebuggerPanel
var _refresh_timer: Timer

func _ready() -> void:
    # ... timer setup ...
    visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
    if visible:
        _refresh_timer.start()
    else:
        _refresh_timer.stop()
```

**Behavior:**
- When panel is **visible**: Timer runs at configured refresh rate (default: 0.5s)
- When panel is **hidden**: Timer pauses, no polling occurs
- When panel **becomes visible**: Timer resumes immediately

### Units and Conversion

**API Data:** ECS systems track time in **seconds** (float)
**UI Display:** Show time in **milliseconds** (float with 2 decimal places)

**Conversion:**
```gdscript
func seconds_to_ms_display(seconds: float) -> String:
    return "%.2f ms" % (seconds * 1000.0)

# Example: 0.00152 seconds → "1.52 ms"
```

**Where Applied:**
- Queries Tab: "Last Duration" column (Essential and Detailed modes)

### Event Payload Serialization Rules

**Standard JSON Types:** Direct serialization
- `int`, `float`, `bool`, `String`: Direct
- `Array`, `Dictionary`: Recursive serialization

**Non-JSON Types:** Custom serialization

| Type | Serialization Rule | Example Output |
|------|-------------------|----------------|
| **Vector2/Vector3** | Dictionary with x/y/z keys | `{"x": 1.0, "y": 2.0, "z": 3.0}` |
| **Node** | String with type and instance ID | `"<Node#12345:CharacterBody2D>"` |
| **Resource** | String with resource path | `"<Resource:res://data/item.tres>"` |
| **Object** | String with class name and instance ID | `"<Object#67890:CustomClass>"` |
| **Callable** | String literal | `"<Callable>"` |
| **null** | JSON null | `null` |

**Implementation Approach:**
```gdscript
static func serialize_payload(payload: Variant) -> Variant:
    if payload is Vector2:
        return {"x": payload.x, "y": payload.y}
    elif payload is Vector3:
        return {"x": payload.x, "y": payload.y, "z": payload.z}
    elif payload is Node:
        return "<Node#%d:%s>" % [payload.get_instance_id(), payload.get_class()]
    elif payload is Resource:
        return "<Resource:%s>" % payload.resource_path
    elif payload is Object:
        return "<Object#%d:%s>" % [payload.get_instance_id(), payload.get_class()]
    elif payload is Callable:
        return "<Callable>"
    elif payload is Array:
        return payload.map(serialize_payload)
    elif payload is Dictionary:
        var result = {}
        for key in payload:
            result[key] = serialize_payload(payload[key])
        return result
    else:
        return payload  # Primitives, null, etc.
```

**Note:** This serialization happens **before** calling `JSON.stringify()`, ensuring the final JSON is valid.

### System Name Derivation

**Primary Source:** `system.get_class()` if available

**Fallback (Script Path Parsing):**
```gdscript
static func derive_system_name(system: BaseECSSystem) -> String:
    # Try get_class() first
    var class_name = system.get_class()
    if class_name != "GDScript":  # GDScript is the default for scripts without class_name
        return class_name

    # Fallback: Parse script path
    var script = system.get_script()
    if not script:
        return "<Unknown System>"

    var path: String = script.resource_path
    if path.is_empty():
        return "<Unknown System>"

    # Extract filename: "res://scripts/ecs/systems/s_input_system.gd" → "s_input_system"
    var filename = path.get_file().get_basename()

    # Convert to PascalCase: "s_input_system" → "SInputSystem"
    var parts = filename.split("_")
    var result = ""
    for part in parts:
        result += part.capitalize()

    return result
```

**Examples:**
- Script with `class_name S_MovementSystem` → `"S_MovementSystem"`
- Script path `s_input_system.gd` → `"SInputSystem"`
- No script → `"<Unknown System>"`

### Event History Truncation Detection

**Current API:** `U_ECSEventBus.get_event_history()` returns Array

**Issue:** No API to detect if history buffer hit its limit

**Workaround:**
```gdscript
# In T_ECSDebuggerEventsTab
const MAX_EVENT_HISTORY = 100  # Must match U_ECSEventBus internal limit

func update_event_count_label(filtered_count: int, total_count: int) -> void:
    if total_count >= MAX_EVENT_HISTORY:
        _count_label.text = "Showing %d / %d+ events (limit reached)" % [filtered_count, total_count]
    else:
        _count_label.text = "Showing %d / %d events" % [filtered_count, total_count]
```

**Limitation:** This assumes `U_ECSEventBus` has a fixed limit of 100. If the limit changes, this constant must be updated.

**Better Future Solution:** Add `U_ECSEventBus.get_history_limit()` and `U_ECSEventBus.is_history_truncated()` methods to the ECS core.

### Empty State Messages

**Queries Tab (No Manager):**
```
No ECS Manager found.
Run the scene (F5/F6) to see query data.
[Refresh Button]
```

**Queries Tab (No Queries):**
```
No queries registered yet.
Queries will appear here once they execute.
```

**Events Tab (No Events):**
```
No events published yet.
Events will appear here as they occur.
```

**System Order Tab (No Manager):**
```
No ECS Manager found.
Run the scene (F5/F6) to see system data.
[Refresh Button]
```

**System Order Tab (No Systems):**
```
No systems registered.
Systems will appear here once added to the manager.
```

### ProjectSettings Persistence Implications

**Key:** `ecs_debugger/disabled_systems`
**Type:** `PackedStringArray` of script resource paths

**Behavior:**
- Saved to `project.godot` file
- **Committed to version control** by default
- Shared across all developers on the project

**Trade-offs:**
| Pro | Con |
|-----|-----|
| Persistent across sessions | Can accidentally commit debug state |
| Works in builds/exports | All team members inherit disabled systems |
| No external config needed | Requires manual cleanup |

**Best Practice Recommendation:**
- Use for intentional long-term disables (e.g., deprecated systems)
- **Do NOT use** for temporary debugging (manually re-enable after testing)
- Document disabled systems in commit messages if intentional

**Alternative Considered (EditorSettings):**
- Would be per-developer, not in VCS
- Would NOT work in runtime (only editor)
- Rejected because runtime capability is a core requirement

---

## Files to Create

1. `addons/ecs_debugger/plugin.cfg` - Plugin manifest
2. `addons/ecs_debugger/plugin.gd` - P_ECSDebuggerPlugin (EditorPlugin)
3. `addons/ecs_debugger/u_ecs_debug_data_source.gd` - U_ECSDebugDataSource (static utility)
4. `addons/ecs_debugger/t_ecs_debugger_panel.gd` - T_ECSDebuggerPanel (main container)
5. `addons/ecs_debugger/tabs/t_ecs_debugger_queries_tab.gd` - Queries tab
6. `addons/ecs_debugger/tabs/t_ecs_debugger_events_tab.gd` - Events tab
7. `addons/ecs_debugger/tabs/t_ecs_debugger_system_order_tab.gd` - System Order tab
8. `tests/unit/ecs/test_ecs_debugger_plugin.gd` - Test suite (~18 tests)
9. `docs/ecs plugin tool/ecs_debugger_usage.md` - User guide

---

## Dependencies (Already Exist)

- ✅ `M_ECSManager.get_query_metrics()` - Returns Array of query metric Dictionaries
- ✅ `ECSSystem.set_debug_disabled(bool)` - Enables/disables system execution
- ✅ `ECSSystem.is_debug_disabled()` - Returns current disabled state
- ✅ `U_ECSEventBus.get_event_history()` - Returns Array of event Dictionaries
- ✅ `U_ECSEventBus.clear_history()` - Clears event history
- ✅ `M_ECSManager.get_systems()` - Returns Array[BaseECSSystem]
- ✅ GUT testing framework (`addons/gut/`, `-gselect` pattern)
- ✅ U_ECSUtils pattern (static methods, RefCounted, push_warning())

---

## Implementation Notes

**Script Path Extraction:**
```gdscript
# Get stable identifier for system persistence
var system: BaseECSSystem = ...
var script_path: String = system.get_script().resource_path
# Example: "res://scripts/ecs/systems/s_input_system.gd"
```

**Pretty JSON Serialization:**
```gdscript
# GDScript 4.x JSON formatting
var json_string = JSON.stringify(data, "  ", false, true)
# Note: "  " = 2-space indent (literal two spaces)
```

**Manager Discovery:**
```gdscript
# Consistent with U_ECSUtils pattern
func find_manager() -> M_ECSManager:
    if not get_tree():
        return null
    var managers = get_tree().get_nodes_in_group("ecs_manager")
    if managers.is_empty():
        return null
    if managers.size() > 1:
        push_warning("ECS Debugger: Multiple managers found, using first")
    return managers[0] as M_ECSManager
```

**System Name from Script Path:**
```gdscript
# Extract class name from path
# "res://scripts/ecs/systems/s_input_system.gd" → "S_InputSystem"
var path = "res://scripts/ecs/systems/s_input_system.gd"
var filename = path.get_file().get_basename()  # "s_input_system"
var parts = filename.split("_")
var class_name = ""
for part in parts:
    class_name += part.capitalize()
# Result: "SInputSystem" → manually adjust to "S_InputSystem" if needed
# OR: Use system.get_class() if available
```

---

**Total Steps:** 70 (updated from 64 after adding missing details)
**Completed:** 0
**In Progress:** 0
**To Do:** 70
