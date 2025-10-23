# ECS Debugger Plugin Architecture Documentation

**Owner**: Development Team | **Last Updated**: 2025-10-22

---

## Table of Contents

1. [Overview](#1-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Component Breakdown](#3-component-breakdown)
4. [Data Flow](#4-data-flow)
5. [Integration Points](#5-integration-points)
6. [Key Patterns](#6-key-patterns)
7. [Example Flows](#7-example-flows)
8. [Current Limitations](#8-current-limitations)
9. [Summary](#9-summary)

---

## 1. Overview

### 1.1 What Is This System?

The ECS Debugger Plugin is an **EditorPlugin-based debugging tool** that provides real-time visibility into the ECS architecture's runtime state. This project implements a **bottom-panel UI** that streams live data from `M_ECSManager`, `ECSEventBus`, and `ECSSystem` instances.

Key capabilities:

- **Query Metrics Visualization** - Monitor query performance, cache hit rates, and execution times
- **Event History Inspection** - Filter, view, and export gameplay events with full payloads
- **System Execution Control** - Enable/disable systems, view priority ordering, persist debug states

### 1.2 Why This Tool?

**Problems Solved**:

- **Query Performance Mystery**: Without metrics, developers can't identify slow queries
- **Event Debugging Blindness**: No visibility into which events fired, when, or with what data
- **System Ordering Confusion**: Unclear execution order leads to timing bugs
- **Runtime State Opacity**: Hard to understand what's happening inside ECS during gameplay

**Goals**:

- **Real-Time Visibility**: Live streaming of ECS state without performance impact (<0.1ms overhead)
- **Developer Productivity**: Reduce debugging time from hours to minutes
- **Performance Optimization**: Identify query bottlenecks via cache hit rate metrics
- **Bug Reproduction**: Export event history to recreate issues from log files

**Trade-offs Accepted**:

- Editor-only by default (users must manually instantiate for runtime debugging)
- Single manager support (warns if multiple managers present)
- Session-only UI state (column toggles, tree expansion don't persist)
- Hybrid test coverage (full data layer, basic UI instantiation, skip detailed interactions)

### 1.3 Core Principles

1. **Non-Invasive Observability** - Plugin reads state, never modifies ECS logic
2. **Performance-First** - Configurable refresh rate (0.1-5.0s), minimal frame impact
3. **Data Layer Separation** - `U_ECSDebugDataSource` isolates formatting from UI
4. **Pure Code UI** - No .tscn files, all widgets created programmatically
5. **TDD-Driven** - All data layer and core panel logic tested before implementation

---

## 2. High-Level Architecture

### 2.1 System Diagram

```
Godot Editor
│
├─ Bottom Panel Dock
│  └─ T_ECSDebuggerPanel (Control)
│     ├─ HBoxContainer (controls)
│     │  ├─ HSlider (refresh rate: 0.1-5.0s)
│     │  └─ Button ("Refresh Now")
│     └─ TabContainer
│        ├─ T_ECSDebuggerQueriesTab
│        │  ├─ Tree (hierarchical: Simple/Moderate/Complex)
│        │  └─ Button ("Show Detailed" ↔ "Show Essential")
│        ├─ T_ECSDebuggerEventsTab
│        │  ├─ LineEdit (filter input)
│        │  ├─ ItemList (event names + timestamps)
│        │  ├─ TextEdit (payload JSON)
│        │  └─ Buttons ("Export" | "Clear History")
│        └─ T_ECSDebuggerSystemOrderTab
│           └─ Tree (systems by priority + checkboxes)
│
├─ P_ECSDebuggerPlugin (EditorPlugin)
│  └─ Manages panel lifecycle (_enter_tree / _exit_tree)
│
└─ Data Sources (Read-Only)
   ├─ M_ECSManager.get_query_metrics()
   ├─ M_ECSManager.get_systems()
   ├─ ECSEventBus.get_event_history()
   └─ ECSSystem.is_debug_disabled()
```

### 2.2 Data Flow Overview

```
[1] Plugin Enabled (Project Settings → Plugins)
     ↓
[2] P_ECSDebuggerPlugin._enter_tree()
     ├─ Instantiate T_ECSDebuggerPanel
     └─ add_control_to_bottom_panel(panel, "ECS Debug")
     ↓
[3] T_ECSDebuggerPanel._ready()
     ├─ Create UI hierarchy (VBoxContainer → HBoxContainer + TabContainer)
     ├─ Instantiate 3 tabs (Queries, Events, System Order)
     ├─ Start auto-refresh Timer (default 0.5s)
     └─ find_manager() → searches "ecs_manager" group
     ↓
[4] Auto-Refresh Timer Fires (every 0.5s)
     ├─ find_manager() → M_ECSManager or null
     ├─ IF manager found:
     │   ├─ queries_tab.refresh(manager)
     │   ├─ events_tab.refresh() (no manager needed)
     │   └─ system_order_tab.refresh(manager)
     └─ ELSE: Show "No Manager Found" + Retry button
     ↓
[5] Tab Refresh Cycle (Example: Queries Tab)
     ├─ manager.get_query_metrics() → Array[Dictionary]
     ├─ U_ECSDebugDataSource.format_query_metrics(metrics) → hierarchical structure
     ├─ Populate Tree widget (Simple/Moderate/Complex groups)
     └─ Update columns based on toggle state (Essential vs Detailed)
     ↓
[6] User Interactions
     ├─ Adjust refresh rate → Update Timer.wait_time
     ├─ Filter events → Re-populate ItemList with substring match
     ├─ Toggle system → system.set_debug_disabled() + save to ProjectSettings
     ├─ Export events → Copy JSON to DisplayServer.clipboard_set()
     └─ Clear history → ECSEventBus.clear_history() + refresh()
```

---

## 3. Component Breakdown

### 3.1 P_ECSDebuggerPlugin

**Location**: `addons/ecs_debugger/plugin.gd`

**Purpose**: EditorPlugin lifecycle manager. Adds panel to editor, cleans up on disable.

**Key Properties**:

```gdscript
@tool
extends EditorPlugin
class_name P_ECSDebuggerPlugin

var _panel: T_ECSDebuggerPanel = null
```

**Key Methods**:

#### `func _enter_tree() -> void`

```gdscript
# Called when plugin enabled
# Instantiates panel and adds to bottom dock
_panel = T_ECSDebuggerPanel.new()
add_control_to_bottom_panel(_panel, "ECS Debug")
```

#### `func _exit_tree() -> void`

```gdscript
# Called when plugin disabled
# Removes panel and cleans up references
if _panel:
    remove_control_from_bottom_panel(_panel)
    _panel.queue_free()
    _panel = null
```

**Integration Points**:

- Uses Godot's EditorPlugin API (`add_control_to_bottom_panel`)
- Appears alongside other editor panels (Output, Debugger, GUT)

---

### 3.2 T_ECSDebuggerPanel

**Location**: `addons/ecs_debugger/t_ecs_debugger_panel.gd`

**Purpose**: Main panel container. Manages UI hierarchy, refresh timer, manager discovery.

**Key Properties**:

```gdscript
extends Control
class_name T_ECSDebuggerPanel

var _manager: M_ECSManager = null
var _refresh_timer: Timer = null
var _refresh_rate: float = 0.5  # Default 0.5s
var _queries_tab: T_ECSDebuggerQueriesTab = null
var _events_tab: T_ECSDebuggerEventsTab = null
var _system_order_tab: T_ECSDebuggerSystemOrderTab = null
```

**UI Hierarchy**:

```
T_ECSDebuggerPanel (Control)
└─ VBoxContainer
   ├─ HBoxContainer (top_controls)
   │  ├─ Label ("Refresh Rate:")
   │  ├─ HSlider (min: 0.1, max: 5.0, value: 0.5)
   │  ├─ Label ("0.5s")
   │  └─ Button ("Refresh Now")
   └─ TabContainer (main_tabs)
      ├─ T_ECSDebuggerQueriesTab
      ├─ T_ECSDebuggerEventsTab
      └─ T_ECSDebuggerSystemOrderTab
```

**Key Methods**:

#### `func find_manager() -> M_ECSManager`

```gdscript
# Searches "ecs_manager" group
# Returns first manager or null
# Warns if multiple managers found
if not get_tree():
    return null
var managers = get_tree().get_nodes_in_group("ecs_manager")
if managers.is_empty():
    return null
if managers.size() > 1:
    push_warning("ECS Debugger: Multiple managers found, using first")
return managers[0] as M_ECSManager
```

#### `func _on_refresh_timer_timeout() -> void`

```gdscript
# Fired every 0.5s (or user-configured rate)
# Triggers tab refresh if manager exists
_manager = find_manager()
if _manager:
    _queries_tab.refresh(_manager)
    _events_tab.refresh()
    _system_order_tab.refresh(_manager)
```

#### `func _on_refresh_rate_changed(value: float) -> void`

```gdscript
# User adjusted slider
# Update timer interval and label
_refresh_rate = value
_refresh_timer.wait_time = value
_rate_label.text = "%.1fs" % value
```

---

### 3.3 U_ECSDebugDataSource

**Location**: `addons/ecs_debugger/u_ecs_debug_data_source.gd`

**Purpose**: Static utility for data formatting and serialization. Isolates business logic from UI.

**Key Properties**:

```gdscript
extends RefCounted
class_name U_ECSDebugDataSource

# All methods static (no instance state)
```

**Key Methods**:

#### `static func serialize_event_history(events: Array) -> String`

```gdscript
# Converts event array to pretty JSON (2-space indent)
# Used for clipboard export
return JSON.stringify(events, "  ", false, true)
```

#### `static func format_query_metrics(metrics: Array) -> Dictionary`

```gdscript
# Groups queries by complexity (# required components)
# Returns: { "simple": [...], "moderate": [...], "complex": [...] }
var grouped = { "simple": [], "moderate": [], "complex": [] }
for metric in metrics:
    var required_count = metric["required"].size()
    if required_count == 1:
        grouped["simple"].append(metric)
    elif required_count >= 2 and required_count <= 3:
        grouped["moderate"].append(metric)
    else:
        grouped["complex"].append(metric)
return grouped
```

#### `static func format_system_list(systems: Array) -> Array`

```gdscript
# Extracts system metadata for display
# Returns: [{ name, priority, script_path, is_disabled }, ...]
var formatted = []
for system in systems:
    if system == null or not is_instance_valid(system):
        continue
    formatted.append({
        "name": _extract_system_name(system),
        "priority": system.execution_priority,
        "script_path": system.get_script().resource_path,
        "is_disabled": system.is_debug_disabled()
    })
return formatted
```

---

### 3.4 T_ECSDebuggerQueriesTab

**Location**: `addons/ecs_debugger/tabs/t_ecs_debugger_queries_tab.gd`

**Purpose**: Displays query metrics in hierarchical Tree. Supports column toggling.

**Key Properties**:

```gdscript
extends Control
class_name T_ECSDebuggerQueriesTab

var _tree: Tree = null
var _toggle_button: Button = null
var _show_detailed: bool = false  # Session state
```

**UI Structure**:

```
VBoxContainer
├─ HBoxContainer
│  └─ Button ("Show Detailed" / "Show Essential")
└─ Tree (hierarchical)
   ├─ TreeItem ("Simple (1)")
   │  ├─ TreeItem (query metrics)
   │  └─ TreeItem (query metrics)
   ├─ TreeItem ("Moderate (2-3)")
   │  └─ TreeItem (query metrics)
   └─ TreeItem ("Complex (4+)")
      └─ TreeItem (query metrics)
```

**Column Modes**:

**Essential (4 columns)**:

1. Query ID
2. Total Calls
3. Hit Rate % (calculated: `cache_hits / total_calls * 100`)
4. Last Duration (ms)

**Detailed (9 columns)**:

1. Query ID
2. Required Components
3. Optional Components
4. Total Calls
5. Cache Hits
6. Hit Rate %
7. Last Duration (ms)
8. Last Result Count
9. Last Run Time (timestamp)

**Key Methods**:

#### `func refresh(manager: M_ECSManager) -> void`

```gdscript
# Called by panel timer
# Rebuilds tree from manager metrics
var metrics = manager.get_query_metrics()
var grouped = U_ECSDebugDataSource.format_query_metrics(metrics)

_tree.clear()
var root = _tree.create_item()

# Create hierarchy
_populate_group(root, "Simple (1)", grouped["simple"])
_populate_group(root, "Moderate (2-3)", grouped["moderate"])
_populate_group(root, "Complex (4+)", grouped["complex"])
```

#### `func _on_toggle_columns() -> void`

```gdscript
# User clicked toggle button
# Switch between essential/detailed views
_show_detailed = not _show_detailed
_toggle_button.text = "Show Essential" if _show_detailed else "Show Detailed"
_update_tree_columns()
```

---

### 3.5 T_ECSDebuggerEventsTab

**Location**: `addons/ecs_debugger/tabs/t_ecs_debugger_events_tab.gd`

**Purpose**: Displays event history with filtering, payload inspection, and export.

**Key Properties**:

```gdscript
extends Control
class_name T_ECSDebuggerEventsTab

var _filter_input: LineEdit = null
var _event_list: ItemList = null
var _payload_display: TextEdit = null
var _event_count_label: Label = null
var _filtered_events: Array = []
```

**UI Structure**:

```
VBoxContainer
├─ HBoxContainer (filter controls)
│  ├─ Label ("Filter:")
│  ├─ LineEdit
│  └─ Label ("Showing X events")
├─ HSplitContainer
│  ├─ ItemList (event names + timestamps)
│  └─ TextEdit (payload JSON, read-only)
└─ HBoxContainer (action buttons)
   ├─ Button ("Export to Clipboard")
   └─ Button ("Clear History")
```

**Event Display Format**:

```
ItemList entry: "[14:32:15.234] entity_jumped"
Payload display: Pretty-printed JSON (2-space indent)
```

**Key Methods**:

#### `func refresh() -> void`

```gdscript
# Called by panel timer
# Updates event list from ECSEventBus
var all_events = ECSEventBus.get_event_history()
_apply_filter(all_events)
_update_event_count(all_events.size())
```

#### `func _on_filter_changed(filter_text: String) -> void`

```gdscript
# User typed in filter input
# Re-filter events (case-insensitive)
var all_events = ECSEventBus.get_event_history()
_filtered_events.clear()
var lower_filter = filter_text.to_lower()
for event in all_events:
    if event["name"].to_lower().contains(lower_filter):
        _filtered_events.append(event)
_populate_event_list()
```

#### `func _on_export_clicked() -> void`

```gdscript
# User clicked "Export to Clipboard"
# Serialize filtered events to JSON
var json = U_ECSDebugDataSource.serialize_event_history(_filtered_events)
DisplayServer.clipboard_set(json)
_export_button.text = "Copied!"
await get_tree().create_timer(1.0).timeout
_export_button.text = "Export to Clipboard"
```

#### `func _on_clear_clicked() -> void`

```gdscript
# User clicked "Clear History"
# Show confirmation dialog
var dialog = ConfirmationDialog.new()
dialog.dialog_text = "Clear all event history? This cannot be undone."
add_child(dialog)
dialog.confirmed.connect(_do_clear_history)
dialog.popup_centered()
```

---

### 3.6 T_ECSDebuggerSystemOrderTab

**Location**: `addons/ecs_debugger/tabs/t_ecs_debugger_system_order_tab.gd`

**Purpose**: Displays systems in priority order. Supports enable/disable toggles with persistence.

**Key Properties**:

```gdscript
extends Control
class_name T_ECSDebuggerSystemOrderTab

var _tree: Tree = null
var _system_map: Dictionary = {}  # script_path → ECSSystem
```

**UI Structure**:

```
VBoxContainer
└─ Tree
   ├─ TreeItem (S_InputSystem, Priority: 0, [✓] Enabled)
   ├─ TreeItem (S_JumpSystem, Priority: 40, [✓] Enabled)
   ├─ TreeItem (S_MovementSystem, Priority: 50, [✗] Disabled - grayed)
   └─ ...
```

**Tree Columns**:

1. System Name (extracted from script path)
2. Priority (0-1000)
3. Enabled (checkbox, CELL_MODE_CHECK)

**Order**:

- Systems are displayed in ascending priority (lower runs first): priority `0` runs before `1000`.

**Visual Indicators**:

- Disabled systems: Grayed text + `"(disabled) "` prefix via `TreeItem.set_custom_color()`

**Key Methods**:

#### `func refresh(manager: M_ECSManager) -> void`

```gdscript
# Called by panel timer
# Rebuilds tree from manager.get_systems()
var systems = manager.get_systems()
var formatted = U_ECSDebugDataSource.format_system_list(systems)

_tree.clear()
var root = _tree.create_item()

# Populate sorted by priority
for system_data in formatted:
    var item = _tree.create_item(root)
    item.set_text(0, system_data["name"])
    item.set_text(1, str(system_data["priority"]))
    item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
    item.set_editable(2, true)
    item.set_checked(2, not system_data["is_disabled"])

    # Visual feedback for disabled
    if system_data["is_disabled"]:
        item.set_custom_color(0, Color.GRAY)
```

#### `func _on_tree_item_edited() -> void`

```gdscript
# User toggled checkbox
# Update system state + persist to ProjectSettings
var item = _tree.get_edited()
var column = _tree.get_edited_column()
if column != 2: return

var system_name = item.get_text(0)
var is_enabled = item.is_checked(2)
var script_path = _get_script_path_for_system(system_name)

# Update system state
var system = _system_map.get(script_path)
if system:
    system.set_debug_disabled(not is_enabled)

# Persist to ProjectSettings
_save_disabled_state(script_path, not is_enabled)

# Update visual
item.set_custom_color(0, Color.WHITE if is_enabled else Color.GRAY)
```

#### `func _save_disabled_state(script_path: String, disabled: bool) -> void`

```gdscript
# Persist to ProjectSettings
var disabled_systems: PackedStringArray = ProjectSettings.get_setting(
    "ecs_debugger/disabled_systems", PackedStringArray()
)

if disabled and not script_path in disabled_systems:
    disabled_systems.append(script_path)
elif not disabled and script_path in disabled_systems:
    disabled_systems.remove_at(disabled_systems.find(script_path))

ProjectSettings.set_setting("ecs_debugger/disabled_systems", disabled_systems)
ProjectSettings.save()
```

---

## 4. Data Flow

### 4.1 Query Metrics Flow

```
[User opens scene with M_ECSManager]
        ↓
[Auto-refresh timer fires (0.5s)]
        ↓
[Panel calls queries_tab.refresh(manager)]
        ↓
[Tab calls manager.get_query_metrics()]
        ↓
[Manager returns Array[Dictionary]]
Example: [
  {
    "id": "req:C_MovementComponent,C_InputComponent|opt:",
    "required": ["C_MovementComponent", "C_InputComponent"],
    "optional": [],
    "total_calls": 120,
    "cache_hits": 115,
    "last_duration": 0.00042,
    "last_result_count": 3,
    "last_run_time": 1634567890.123
  },
  ...
]
        ↓
[Tab calls U_ECSDebugDataSource.format_query_metrics(metrics)]
        ↓
[Data source groups by complexity]
Returns: {
  "simple": [...],      # 1 required component
  "moderate": [...],    # 2-3 required components
  "complex": [...]      # 4+ required components
}
        ↓
[Tab populates Tree widget]
        ↓
[User sees hierarchical view]
Simple (1)
  └─ req:C_MovementComponent|opt: [120 calls, 95% hit rate, 0.4ms]
Moderate (2-3)
  └─ req:C_MovementComponent,C_InputComponent|opt: [120 calls, 95% hit rate, 0.4ms]
```

### 4.2 Event History Flow

```
[Systems publish events via ECSEventBus]
        ↓
[ECSEventBus stores in _event_history (rolling 1000)]
        ↓
[Auto-refresh timer fires]
        ↓
[Panel calls events_tab.refresh()]
        ↓
[Tab calls ECSEventBus.get_event_history()]
        ↓
[Event bus returns Array[Dictionary]]
Example: [
  {
    "name": "entity_jumped",
    "payload": { "entity": <Object>, "velocity": Vector3(0, 5, 0) },
    "timestamp": 1634567890.123
  },
  ...
]
        ↓
[Tab applies filter (case-insensitive substring)]
        ↓
[Tab formats timestamp as "[HH:MM:SS.mmm] event_name"]
        ↓
[Tab populates ItemList + TextEdit]
        ↓
[User clicks event → Payload displays as pretty JSON]
```

### 4.3 System Toggle Flow

```
[User unchecks system in tree]
        ↓
[Tree emits "item_edited" signal]
        ↓
[Tab handles _on_tree_item_edited()]
        ↓
[Tab extracts script_path from system_map]
        ↓
[Tab calls system.set_debug_disabled(true)]
        ↓
[System sets _debug_disabled = true]
        ↓
[M_ECSManager._physics_process() checks is_debug_disabled()]
        ↓
[Manager skips disabled system (no process_tick() call)]
        ↓
[Tab persists to ProjectSettings]
ProjectSettings["ecs_debugger/disabled_systems"] = [
  "res://scripts/ecs/systems/s_movement_system.gd"
]
        ↓
[Tab calls ProjectSettings.save()]
        ↓
[Editor restarts → Tab loads persisted state]
        ↓
[Tab applies disabled_systems to matching systems]
```

---

## 5. Integration Points

### 5.1 M_ECSManager Integration

**Used Methods**:

```gdscript
# Query metrics (scripts/managers/m_ecs_manager.gd:109)
func get_query_metrics() -> Array
# Returns: [{ id, required, optional, total_calls, cache_hits, ... }, ...]

# System list (scripts/managers/m_ecs_manager.gd:86)
func get_systems() -> Array
# Returns: Array[ECSSystem] (already sorted by priority)
```

**Data Format**:

```gdscript
# Query metric structure:
{
  "id": String,                    # Cache key
  "required": Array[StringName],   # Required component types
  "optional": Array[StringName],   # Optional component types
  "total_calls": int,              # Lifetime call count
  "cache_hits": int,               # Lifetime cache hits
  "last_duration": float,          # Last execution time (seconds)
  "last_result_count": int,        # Last result array size
  "last_run_time": float           # Timestamp of last execution
}
```

### 5.2 ECSEventBus Integration

**Used Methods**:

```gdscript
# Event history (scripts/ecs/ecs_event_bus.gd:81)
static func get_event_history() -> Array
# Returns: [{ name, payload, timestamp }, ...]

# Clear history (scripts/ecs/ecs_event_bus.gd:73)
static func clear_history() -> void
# Clears _event_history array
```

**Data Format**:

```gdscript
# Event structure:
{
  "name": StringName,        # Event name (e.g., "entity_jumped")
  "payload": Variant,        # Deep-copied payload (Dictionary, Array, or primitive)
  "timestamp": float         # U_ECSUtils.get_current_time() when published
}
```

### 5.3 ECSSystem Integration

**Used Methods**:

```gdscript
# Debug disable (scripts/ecs/ecs_system.gd:50)
func set_debug_disabled(disabled: bool) -> void
func is_debug_disabled() -> bool
# Controls whether M_ECSManager calls process_tick()

# Metadata (via Godot API)
func get_script() -> Script
script.resource_path -> String
# Used for persistence identifier
```

### 5.4 ProjectSettings Integration

**Used Keys**:

```gdscript
# System disable persistence
"ecs_debugger/disabled_systems": PackedStringArray
# Example: ["res://scripts/ecs/systems/s_movement_system.gd", ...]
```

**Persistence Flow**:

```gdscript
# Save
ProjectSettings.set_setting("ecs_debugger/disabled_systems", disabled_array)
ProjectSettings.save()

# Load
var disabled = ProjectSettings.get_setting(
    "ecs_debugger/disabled_systems",
    PackedStringArray()  # Default if not set
)
```

---

## 6. Key Patterns

### 6.1 Manager Discovery Pattern

Used by all tabs to find M_ECSManager in scene:

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

**Rationale**: Consistent with `U_ECSUtils.get_manager()` pattern.

### 6.2 Static Data Source Pattern

All data formatting isolated to static methods:

```gdscript
# Pure functions, no state
class_name U_ECSDebugDataSource extends RefCounted

static func serialize_event_history(events: Array) -> String:
    return JSON.stringify(events, "  ", false, true)

static func format_query_metrics(metrics: Array) -> Dictionary:
    # Group by complexity...
    return grouped

static func format_system_list(systems: Array) -> Array:
    # Extract metadata...
    return formatted
```

**Benefits**:

- Testable in isolation (no UI dependencies)
- Reusable across tabs
- Clear separation of data vs presentation

### 6.3 Refresh-On-Timer Pattern

All tabs implement `refresh()` method called by panel timer:

```gdscript
# In T_ECSDebuggerPanel
func _on_refresh_timer_timeout() -> void:
    _manager = find_manager()
    if _manager:
        _queries_tab.refresh(_manager)
        _events_tab.refresh()  # No manager needed
        _system_order_tab.refresh(_manager)

# In each tab
func refresh(manager: M_ECSManager) -> void:
    # Fetch latest data
    # Update UI widgets
    # Preserve user state (expand/collapse, selection)
```

**Benefits**:

- Configurable refresh rate (0.1-5.0s)
- Manual refresh via button
- Predictable, consistent update cycle

### 6.4 Session State Pattern

Some UI state persists during session, some doesn't:

**Persists (ProjectSettings)**:

- System disable toggles

**Session-Only (member variables)**:

- Column view toggle (Essential vs Detailed)
- Tree expand/collapse state
- Current filter text
- Selected event

```gdscript
# Session state example
class_name T_ECSDebuggerQueriesTab

var _show_detailed: bool = false  # Resets on restart

func _on_toggle_columns() -> void:
    _show_detailed = not _show_detailed  # Only lasts this session
```

**Rationale**: Balance between convenience and simplicity. System toggles persist because they affect runtime behavior; UI preferences are session-only.

### 6.5 Hierarchical Tree Pattern

Used in Queries and System Order tabs:

```gdscript
func _populate_tree() -> void:
    _tree.clear()
    var root = _tree.create_item()  # Invisible root

    # Create parent nodes
    var simple_group = _tree.create_item(root)
    simple_group.set_text(0, "Simple (1)")
    simple_group.collapsed = true  # Collapsed by default

    # Create child nodes
    for query in simple_queries:
        var item = _tree.create_item(simple_group)
        item.set_text(0, query["id"])
        item.set_text(1, str(query["total_calls"]))
        # ... populate columns
```

**Benefits**:

- Logical grouping (complexity, priority bands)
- Collapsible sections reduce visual clutter
- Preserves expand/collapse state during refresh via metadata

### 6.6 Editor vs Runtime Discovery Behavior

**Critical Limitation**: The debugger **only shows data when a scene is running** (F5/F6).

**Why**:

- `M_ECSManager` adds itself to the `"ecs_manager"` group in its `_ready()` method
- In the editor (not playing), `_ready()` doesn't execute
- `find_manager()` returns `null` because the group is empty

**User Experience**:

| State | `find_manager()` Result | UI Behavior |
|-------|------------------------|-------------|
| **Scene Running** (F5/F6) | Returns `M_ECSManager` | Full debugger functionality |
| **Editor (Not Playing)** | Returns `null` | Shows: "No ECS Manager found. Run the scene (F5/F6) to see data." + Refresh button |
| **No Manager in Scene** | Returns `null` | Same error message |

**Implementation**:

```gdscript
func _on_refresh_timer_timeout() -> void:
    _manager = find_manager()

    if not _manager:
        _show_no_manager_message()
        return

    _hide_no_manager_message()
    _refresh_all_tabs()
```

**Alternative Considered**: Use `EditorInterface.get_edited_scene_root()` and scan for `M_ECSManager` by type (not group). This would work in the editor, but was rejected because:

- Runtime capability is a core requirement
- Group-based discovery is more flexible
- Consistent with existing ECS patterns

### 6.7 Color Coding and Accessibility

**Query Cache Hit Rate Colors**:

| Range | Color | Hex Code | Purpose |
|-------|-------|----------|---------|
| ≥80% | Green | `#4CAF50` | Excellent cache performance |
| 50-79% | Yellow | `#FFC107` | Moderate cache performance |
| <50% | Red | `#F44336` | Poor cache performance |

**Implementation**:

```gdscript
func get_hit_rate_color(hit_rate: float) -> Color:
    if hit_rate >= 80.0:
        return Color("#4CAF50")  # Green
    elif hit_rate >= 50.0:
        return Color("#FFC107")  # Yellow
    else:
        return Color("#F44336")  # Red

# Apply to TreeItem
var color = get_hit_rate_color(hit_rate)
item.set_custom_color(column_index, color)
```

**Accessibility**:

- All colors meet WCAG AA contrast standards
- Colors are **always accompanied by numerical percentages**
- Users with color vision deficiency can rely on the numbers
- No information is conveyed by color alone

**System Disabled State**:

```gdscript
if system.is_debug_disabled():
    item.set_text(0, "(disabled) " + system_name)
    item.set_custom_color(0, Color(0.5, 0.5, 0.5))  # Gray
```

**Note**: TreeItem doesn't support strikethrough natively in Godot 4.x, so we use grayed text + prefix.

### 6.8 Query Sorting and Grouping

**Between-Group Hierarchy (Complexity-Based)**:

1. **Simple (1)** — One required component (collapsed by default)
2. **Moderate (2-3)** — Two to three required components (collapsed by default)
3. **Complex (4+)** — Four or more required components (collapsed by default)

**Grouping Criteria**:

```gdscript
var simple := []
var moderate := []
var complex := []

for metric in metrics:
    var required_count := int(metric.get("required", []).size())
    if required_count == 1:
        simple.append(metric)
    elif required_count >= 2 and required_count <= 3:
        moderate.append(metric)
    else:
        complex.append(metric)
```

**Within-Group Sorting**: By `last_run_time` descending (most recent first)

```gdscript
simple.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
moderate.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
complex.sort_custom(func(a, b): return float(a.get("last_run_time", 0.0)) > float(b.get("last_run_time", 0.0)))
```

**Rationale**: Prioritizes currently-used queries at the top of their group, making recent performance issues easier to spot.

### 6.9 Units and Conversion

**Time Display Convention**:

- **API Data**: ECS systems track time in **seconds** (float)
- **UI Display**: Show time in **milliseconds** (float, 2 decimal places)

**Conversion Helper**:

```gdscript
static func seconds_to_ms_display(seconds: float) -> String:
    return "%.2f ms" % (seconds * 1000.0)

# Example: 0.00152 → "1.52 ms"
```

**Applied To**:

- Queries Tab: "Last Duration" column (Essential and Detailed modes)

**Rationale**: Milliseconds are more intuitive for developers analyzing performance (easier to compare "1.52 ms" vs "15.3 ms" than "0.00152 s" vs "0.0153 s").

### 6.10 Timer Pause-on-Hidden

**Goal**: Zero frame impact when debugger panel is hidden.

**Implementation**:

```gdscript
# In T_ECSDebuggerPanel
func _ready() -> void:
    _refresh_timer = Timer.new()
    add_child(_refresh_timer)
    _refresh_timer.timeout.connect(_on_refresh_timer_timeout)

    visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
    if visible:
        _refresh_timer.start()
    else:
        _refresh_timer.stop()
```

**Behavior**:

- **Panel Visible**: Timer runs at configured refresh rate (default 0.5s)
- **Panel Hidden**: Timer stops, no polling occurs, zero CPU usage
- **Panel Becomes Visible**: Timer resumes immediately with fresh data

**Performance Impact**:

- Hidden panel: **0.0ms/frame**
- Visible panel: **<0.1ms/frame** (depends on data size and refresh rate)

### 6.11 Event Payload Serialization

**Problem**: Events may contain types that don't serialize to JSON directly (Node, Vector3, Resource).

**Solution**: Pre-serialize payloads before calling `JSON.stringify()`.

**Serialization Rules**:

| Type | Output |
|------|--------|
| `int`, `float`, `bool`, `String` | Direct |
| `Array`, `Dictionary` | Recursive serialization |
| `Vector2`, `Vector3` | `{"x": float, "y": float, "z": float}` |
| `Node` | `"<Node#12345:CharacterBody2D>"` |
| `Resource` | `"<Resource:res://data/item.tres>"` |
| `Object` | `"<Object#67890:CustomClass>"` |
| `Callable` | `"<Callable>"` |
| `null` | `null` |

**Implementation**:

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
        return payload  # Primitives, null
```

**Usage**:

```gdscript
static func serialize_event_history(events: Array) -> String:
    var serialized_events = []
    for event in events:
        var serialized_payload = serialize_payload(event["payload"])
        serialized_events.append({
            "event_name": event["event_name"],
            "timestamp": event["timestamp"],
            "payload": serialized_payload
        })
    return JSON.stringify(serialized_events, "  ", false, true)
```

### 6.12 System Name Derivation

**Primary Source**: `system.get_class()`

**Fallback**: Parse script resource path

**Implementation**:

```gdscript
static func derive_system_name(system: ECSSystem) -> String:
    # Try get_class() first
    var class_name = system.get_class()
    if class_name != "GDScript":  # "GDScript" means no class_name declared
        return class_name

    # Fallback: Parse script path
    var script = system.get_script()
    if not script:
        return "<Unknown System>"

    var path: String = script.resource_path
    if path.is_empty():
        return "<Unknown System>"

    # "res://scripts/ecs/systems/s_input_system.gd" → "s_input_system"
    var filename = path.get_file().get_basename()

    # "s_input_system" → "SInputSystem"
    var parts = filename.split("_")
    var result = ""
    for part in parts:
        result += part.capitalize()

    return result
```

**Examples**:

- Script with `class_name S_MovementSystem` → `"S_MovementSystem"`
- Script path `s_input_system.gd` → `"SInputSystem"`
- No script → `"<Unknown System>"`

### 6.13 Empty State Messages

**Queries Tab (No Manager)**:

```
No ECS Manager found.
Run the scene (F5/F6) to see query data.
[Refresh Button]
```

**Queries Tab (No Queries)**:

```
No queries registered yet.
Queries will appear here once they execute.
```

**Events Tab (No Events)**:

```
No events published yet.
Events will appear here as they occur.
```

**System Order Tab (No Manager)**:

```
No ECS Manager found.
Run the scene (F5/F6) to see system data.
[Refresh Button]
```

**System Order Tab (No Systems)**:

```
No systems registered.
Systems will appear here once added to the manager.
```

**Implementation Pattern**:

```gdscript
func refresh(manager: M_ECSManager) -> void:
    var queries = manager.get_query_metrics()

    if queries.is_empty():
        _show_empty_state("No queries registered yet.\nQueries will appear here once they execute.")
        return

    _hide_empty_state()
    _populate_tree(queries)
```

### 6.14 Event History Truncation Detection

**Problem**: `ECSEventBus` has a fixed history limit (typically 100 events), but no API to detect truncation.

**Workaround**:

```gdscript
# In T_ECSDebuggerEventsTab
const MAX_EVENT_HISTORY = 100  # Must match ECSEventBus internal limit

func update_event_count_label(filtered_count: int, total_count: int) -> void:
    if total_count >= MAX_EVENT_HISTORY:
        _count_label.text = "Showing %d / %d+ events (limit reached)" % [filtered_count, total_count]
    else:
        _count_label.text = "Showing %d / %d events" % [filtered_count, total_count]
```

**Limitation**: Assumes `ECSEventBus._event_history` max size is 100. If ECS core changes this, the constant must be updated.

**Better Future Solution**: Add to ECS core:

```gdscript
# In ECSEventBus
static func get_history_limit() -> int:
    return 100

static func is_history_truncated() -> bool:
    return _event_history.size() >= get_history_limit()
```

---

## 7. Example Flows

### 7.1 First-Time Plugin Enable

```
[Developer enables plugin]
        ↓
[Godot calls P_ECSDebuggerPlugin._enter_tree()]
        ↓
[Plugin creates T_ECSDebuggerPanel]
        ↓
[Plugin calls add_control_to_bottom_panel()]
        ↓
[Panel appears in editor bottom dock as "ECS Debug" tab]
        ↓
[Panel._ready() runs]
        ↓
[Panel creates UI hierarchy (VBox → HBox + TabContainer)]
        ↓
[Panel creates 3 tab instances]
        ↓
[Panel starts Timer (0.5s interval)]
        ↓
[First timer tick: find_manager() returns null (no scene open)]
        ↓
[Panel shows "No ECS Manager Found" + Retry button]
        ↓
[Developer opens scene with M_ECSManager]
        ↓
[Next timer tick: find_manager() returns manager]
        ↓
[Panel hides "No Manager Found", shows tabs]
        ↓
[All 3 tabs refresh with initial data]
```

### 7.2 Identifying Slow Query

```
[Developer notices frame drops during gameplay]
        ↓
[Opens ECS Debug panel → Queries tab]
        ↓
[Clicks "Show Detailed" to see all columns]
        ↓
[Expands "Complex (4+)" group]
        ↓
[Sees query with high call count + low cache hit rate]
Example: req:C_Movement,C_Input,C_Jump,C_Floating|opt:C_Align
  - Total Calls: 3600 (60 fps × 60 seconds)
  - Cache Hits: 180
  - Hit Rate: 5% ← PROBLEM!
  - Last Duration: 2.5ms ← SLOW!
        ↓
[Realizes query is called in wrong system]
        ↓
[Refactors to cache result or reduce query frequency]
        ↓
[Next refresh shows improved metrics]
  - Cache Hits: 3500
  - Hit Rate: 97% ← FIXED!
  - Last Duration: 0.4ms ← FAST!
```

### 7.3 Debugging Event Chain

```
[Developer reports: "Jump particles not spawning"]
        ↓
[Opens ECS Debug → Events tab]
        ↓
[Types "jump" in filter]
        ↓
[Sees no "entity_jumped" events in history]
        ↓
[Conclusion: S_JumpSystem not publishing events]
        ↓
[Checks S_JumpSystem.process_tick() → missing ECSEventBus.publish() call]
        ↓
[Adds event publication code]
        ↓
[Next refresh shows events appearing]
ItemList: "[14:32:15.234] entity_jumped"
        ↓
[Clicks event → Inspects payload]
{
  "entity": <CharacterBody3D#12345>,
  "velocity": Vector3(0, 5.2, 0),
  "position": Vector3(10, 2, 5)
}
        ↓
[Realizes S_ParticleSystem not subscribed]
        ↓
[Adds ECSEventBus.subscribe() in particle system]
        ↓
[Particles now spawn correctly!]
```

### 7.4 Debugging System Execution Order

```
[Developer reports: "Player jumps before input is read"]
        ↓
[Opens ECS Debug → System Order tab]
        ↓
[Sees system priority order]
  - S_JumpSystem (Priority: 40)
  - S_InputSystem (Priority: 50) ← WRONG ORDER!
        ↓
[Realizes jump is processing before input]
        ↓
[Opens s_input_system.gd, changes priority to 0]
        ↓
[Next refresh shows corrected order]
  - S_InputSystem (Priority: 0) ← NOW FIRST
  - S_JumpSystem (Priority: 40)
        ↓
[Jump now works correctly!]
```

### 7.5 Temporarily Disabling System for Testing

```
[Developer wants to test movement without gravity]
        ↓
[Opens ECS Debug → System Order tab]
        ↓
[Unchecks S_GravitySystem]
        ↓
[System grays out (visual feedback)]
        ↓
[Runs scene → Player moves without falling]
        ↓
[Tests movement mechanics in isolation]
        ↓
[Re-checks S_GravitySystem when done]
        ↓
[System re-enables, normal behavior restored]
        ↓
[Restarts editor → Disabled state persisted!]
(Thanks to ProjectSettings persistence)
```

---

## 8. Current Limitations

### 8.1 Single Manager Support

**Limitation**: Plugin assumes one M_ECSManager per scene. Multiple managers trigger warning.

**Workaround**: Use first manager found, ignore others.

**Future**: Add dropdown to switch between managers.

### 8.2 Editor-Only by Default

**Limitation**: Plugin uses EditorPlugin, only available in editor.

**Workaround**: Users can manually instantiate `T_ECSDebuggerPanel` in game UI:

```gdscript
# In debug overlay scene
var debug_panel = preload("res://addons/ecs_debugger/t_ecs_debugger_panel.gd").new()
add_child(debug_panel)
```

**Future**: Provide runtime overlay scene template.

### 8.3 Session-Only UI State

**Limitation**: Column toggle, tree expansion don't persist between sessions.

**Workaround**: None (design decision for simplicity).

**Future**: Add ProjectSettings for UI preferences if users request.

### 8.4 No Historical Metrics

**Limitation**: Query metrics show only current snapshot, no historical trends.

**Workaround**: Export event history includes timestamps for manual analysis.

**Future**: Add performance graphs (call count over time, hit rate trends).

### 8.5 Synchronous Refresh Only

**Limitation**: All tabs refresh on same timer, can't have different rates.

**Workaround**: Global refresh rate applies to all tabs.

**Future**: Per-tab refresh intervals if needed.

---

## 9. Summary

The ECS Debugger Plugin provides **real-time observability** into the ECS architecture via a **bottom-panel UI** with three specialized tabs:

**Architecture Highlights**:

- **Non-invasive**: Read-only access to ECS state, no logic modification
- **Performant**: Configurable refresh rate (0.1-5.0s), minimal overhead (<0.1ms)
- **Maintainable**: Data layer (U_ECSDebugDataSource) isolated from UI (T_* tabs)
- **Testable**: TDD-first approach, hybrid coverage (full data layer + basic UI)
- **Persistent**: System disable toggles saved to ProjectSettings

**Integration Points**:

- M_ECSManager: `get_query_metrics()`, `get_systems()`
- ECSEventBus: `get_event_history()`, `clear_history()`
- ECSSystem: `set_debug_disabled()`, `is_debug_disabled()`
- ProjectSettings: `ecs_debugger/disabled_systems`

**Key Workflows**:

1. **Query Optimization**: Identify slow queries via cache hit rate metrics
2. **Event Debugging**: Filter/inspect events to trace gameplay interactions
3. **System Ordering**: Verify execution priority, temporarily disable systems
4. **Bug Reproduction**: Export event history for issue reports

**Next Steps**:

- Implement Phase 1-8 per `ecs_plugin_tool_plan.md`
- Run TDD test suite (`test_ecs_debugger_plugin.gd`)
- Document usage patterns in `ecs_debugger_usage.md`
- Mark Story 2.1 complete in `ecs_refactor_plan.md`

For beginner-friendly overview, see `ecs_plugin_tool_ELI5.md`.
For product requirements, see `ecs_plugin_tool_prd.md`.
