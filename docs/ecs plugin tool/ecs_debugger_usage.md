# ECS Debugger Usage Guide

**Version:** 1.0
**Last Updated:** 2025-10-22

---

## Table of Contents

1. [Installation](#installation)
2. [Accessing the Debugger](#accessing-the-debugger)
3. [Runtime vs Editor Behavior](#runtime-vs-editor-behavior)
4. [Tab-by-Tab Usage](#tab-by-tab-usage)
   - [Queries Tab](#queries-tab)
   - [Events Tab](#events-tab)
   - [System Order Tab](#system-order-tab)
5. [Common Workflows](#common-workflows)
6. [Troubleshooting](#troubleshooting)
7. [Known Limitations](#known-limitations)

---

## Installation

### Step 1: Enable the Plugin

1. Open your project in Godot 4.x
2. Navigate to **Project → Project Settings → Plugins**
3. Find **"ECS Debugger"** in the plugin list
4. Check the **Enable** checkbox
5. Click **Close**

### Step 2: Verify Installation

You should now see an **"ECS Debugger"** button in the bottom panel area (next to Output, Debugger, etc.).

**Note:** If the button doesn't appear, try:
- Restarting Godot
- Checking that `addons/ecs_debugger/plugin.cfg` exists
- Verifying that `addons/ecs_debugger/plugin.gd` has no syntax errors

---

## Accessing the Debugger

### In the Editor

1. Click the **"ECS Debugger"** button in the bottom panel
2. The debugger panel will expand, showing three tabs

### During Runtime

The debugger remains accessible while your game is running (F5/F6). This is the primary use case, as it displays live ECS data.

---

## Runtime vs Editor Behavior

**IMPORTANT:** The ECS Debugger displays meaningful data **only when a scene is running** (F5 or F6).

### Why?

The `M_ECSManager` node only adds itself to the `"ecs_manager"` group when its `_ready()` method runs. In the editor (when not playing), `_ready()` doesn't execute, so the debugger cannot discover the manager.

### What You'll See

| State | Behavior |
|-------|----------|
| **Scene Running** (F5/F6) | Full debugger functionality, live data updates |
| **Editor (Not Playing)** | Error message: "No ECS Manager found. Run the scene (F5/F6) to see data." |
| **No Manager in Scene** | Same error message with "Refresh" button |

### Refresh Button

If you add an `M_ECSManager` node to your scene tree while the debugger is open:
1. Click the **Refresh** button in the error message
2. The debugger will attempt to rediscover the manager
3. If found, data will begin streaming immediately

---

## Tab-by-Tab Usage

### Queries Tab

**Purpose:** Monitor query performance and cache efficiency in real-time.

#### Layout

The tab displays a hierarchical tree with three top-level nodes:
- **Simple Queries (1 component)** (collapsed by default)
- **Moderate Queries (2-3 components)** (collapsed by default)
- **Complex Queries (4+ components)** (collapsed by default)

#### Columns

You can toggle between two column modes using the **"Toggle Columns"** button:

**Mode 1: Essential**
| Column | Description | Units |
|--------|-------------|-------|
| Query ID | Cache key (e.g., `req:C_Movement\|opt:`) | - |
| Total Calls | Number of times query executed this session | count |
| Hit Rate | Cache hit percentage | % |
| Last Duration | Execution time of most recent call | ms |

**Mode 2: Detailed**
| Column | Description | Units |
|--------|-------------|-------|
| Query ID | Cache key | - |
| Required | Required component types | - |
| Optional | Optional component types | - |
| Total Calls | Lifetime call count | count |
| Cache Hits | Successful cache retrievals | count |
| Hit Rate | Cache hit percentage | % |
| Last Duration | Most recent execution time | ms |
| Last Result Count | Entities matched in last call | count |
| Last Run Time | Timestamp of last execution | unix time |

#### Color Coding

Cache hit rates are color-coded for quick identification:
- **Green** (>80%): Excellent cache performance
- **Yellow** (50-80%): Moderate cache performance
- **Red** (<50%): Poor cache performance (consider optimization)

**Accessibility Note:** Colors use sufficient contrast and are accompanied by numerical values. Users with color vision deficiency can rely on the percentage numbers.

#### Grouping Logic

| Group | Criteria |
|-------|----------|
| **Simple Queries** | `required.size() == 1` |
| **Moderate Queries** | `required.size() >= 2 AND required.size() <= 3` |
| **Complex Queries** | `required.size() >= 4` |

Within each complexity group, queries are sorted by `last_run_time` (most recent first) for quick identification of hot paths.

#### Example Workflow: Identifying Cache Issues

1. Run your scene (F5)
2. Open the ECS Debugger → Queries tab
3. Look for **red-highlighted** hit rates (<50%)
4. Switch to **Detailed** mode (Toggle Columns)
5. Note the `Cache Misses` count
6. If misses are high, consider:
   - Reducing component mutations
   - Increasing cache lifetime
   - Reviewing query invalidation logic

---

### Events Tab

**Purpose:** Filter, inspect, and export ECS event history.

#### Layout

- **Filter Input** (top): Case-insensitive substring search
- **Event List** (left, 30% width): Scrollable list of event names
- **Event Details** (right, 70% width): Pretty-printed JSON payload
- **Export Button** (bottom): Copy all visible events to clipboard

#### Features

##### Filtering

1. Type any substring into the filter input (e.g., `"damage"`)
2. The event list updates in real-time to show only matching events
3. Filtering is **case-insensitive** (`"Damage"` matches `"entity_damage_taken"`)
4. Clear the filter to see all events

##### Inspecting Events

1. Click any event name in the list
2. The right panel displays the full event payload as JSON
3. JSON is pretty-printed with 2-space indentation for readability

**Example Output:**
```json
{
  "entity_id": 42,
  "damage": 15.5,
  "source": "Player",
  "timestamp": 1698765432.123
}
```

##### Exporting Events

1. Apply any filter (or leave empty to export all)
2. Click the **"Export to Clipboard"** button
3. The entire filtered event history is copied as a JSON array
4. Paste into a text editor, log file, or analysis tool

**Export Format:**
```json
[
  {
    "name": "entity_damage_taken",
    "timestamp": 1698765432.123,
    "payload": {
      "entity_id": 42,
      "damage": 15.5
    }
  },
  {
    "name": "entity_health_changed",
    "timestamp": 1698765432.456,
    "payload": {
      "entity_id": 42,
      "new_health": 84.5
    }
  }
]
```

##### Clearing History

1. Click the **"Clear Events"** button
2. A confirmation dialog appears: **"Are you sure you want to clear event history? This cannot be undone."**
3. Click **OK** to clear, or **Cancel** to abort

##### Event Count Indicator

At the top of the tab, you'll see a count indicator:
- **"Showing 47 / 1000 events"**: 47 events match your filter, 1000 total in history
- **"Showing 1000 / 1000 events (limit reached)"**: History buffer is full; oldest events are being discarded

#### Non-JSON Payloads

Some events may contain payloads with types that don't serialize to JSON directly (e.g., `Node`, `Vector3`, `Resource`):

| Type | Serialization |
|------|---------------|
| **Node** | `<Node#12345:CharacterBody2D>` |
| **Vector3** | `{"x": 1.0, "y": 2.0, "z": 3.0}` |
| **Resource** | `<Resource#67890:res://data/item.tres>` |
| **Callable** | `"<Callable>"` |
| **Object** | `<Object#11111:CustomClass>` |

#### Example Workflow: Debugging Event Flow

1. Run your scene (F5)
2. Perform an action that should trigger events (e.g., take damage)
3. Open ECS Debugger → Events tab
4. Filter for `"damage"`
5. Click the first `"entity_damage_taken"` event
6. Inspect the payload to verify `entity_id`, `damage`, and `source` values
7. Export to clipboard and save to a file for later analysis

---

### System Order Tab

**Purpose:** View execution order and enable/disable systems at runtime.

#### Layout

The tab displays a table with three columns:

| Column | Description |
|--------|-------------|
| **System** | System class name (e.g., `S_MovementSystem`) |
| **Priority** | Execution priority (0-1000, lower runs first) |
| **Enabled** | Checkbox to enable/disable the system |

#### Sorting

Systems are automatically sorted by execution priority (lowest first), matching the order in which they run each frame.

#### Enabling/Disabling Systems

1. Locate the system in the table
2. Toggle the **Enabled** checkbox
3. The change takes effect immediately:
   - **Unchecked**: System's `process()` and `physics_process()` are skipped
   - **Checked**: System resumes normal execution

**Visual Indicators:**
- Disabled systems are shown in **gray text** with a `"(disabled)"` prefix
- Enabled systems use normal text color

#### Persistence

System enable/disable states are saved to **ProjectSettings** under the key:
```
ecs_debugger/disabled_systems = [
  "res://scripts/ecs/systems/s_movement_system.gd",
  "res://scripts/ecs/systems/s_damage_system.gd"
]
```

**Important:** This means disabled systems will remain disabled across editor sessions and in version control. To reset:
1. Re-enable systems manually in the debugger, OR
2. Remove the `ecs_debugger/disabled_systems` entry from `project.godot`

#### Example Workflow: Isolating a Bug

1. Run your scene (F5)
2. Open ECS Debugger → System Order tab
3. Observe execution order and verify priority values
4. Disable all systems except the one you're debugging
5. Test the isolated system behavior
6. Re-enable systems one at a time to identify conflicts

---

## Common Workflows

### 1. Optimizing Query Performance

**Goal:** Reduce frame time by improving cache hit rates.

**Steps:**
1. Open Queries tab during gameplay
2. Identify queries with **red** hit rates (<50%)
3. Switch to Cache Analysis mode
4. Note which queries have high miss counts
5. Review code to reduce component mutations or invalidation frequency
6. Re-test and verify hit rate improvement

---

### 2. Debugging Event Timing

**Goal:** Verify events fire in the correct order.

**Steps:**
1. Open Events tab
2. Perform an action that triggers multiple events
3. Scroll through the event list (ordered by timestamp)
4. Click each event to inspect payloads
5. Export to clipboard for detailed analysis in a text editor

---

### 3. Disabling Problematic Systems

**Goal:** Temporarily disable a system causing crashes or errors.

**Steps:**
1. Open System Order tab
2. Uncheck the problematic system's **Enabled** checkbox
3. Continue testing with the system disabled
4. Fix the system code
5. Re-enable the system to verify the fix

---

### 4. Exporting Debug Data for Bug Reports

**Goal:** Provide detailed ECS state in a bug report.

**Steps:**
1. Reproduce the bug with the debugger open
2. Open Queries tab → Take a screenshot
3. Open Events tab → Export to clipboard, save to `debug_events.json`
4. Open System Order tab → Take a screenshot
5. Attach screenshots and JSON file to your bug report

---

## Troubleshooting

### Problem: "No ECS Manager found" Error

**Cause:** The scene is not running, or no `M_ECSManager` node exists in the scene tree.

**Solutions:**
1. **Run the scene** (F5 or F6) if you're in the editor
2. **Add an `M_ECSManager` node** to your scene if missing
3. Click the **Refresh** button after adding the manager

---

### Problem: Queries Tab Shows No Data

**Cause:** No queries have been executed yet, or the manager hasn't collected metrics.

**Solutions:**
1. **Wait a few seconds** for queries to run
2. **Interact with the game** to trigger query execution
3. **Verify queries are registered** by checking `M_ECSManager.get_query_metrics()`

---

### Problem: Events Tab is Empty

**Cause:** No events have been published, or event history was cleared.

**Solutions:**
1. **Trigger events** by performing in-game actions
2. **Verify event publishing** by checking `ECSEventBus.publish()` calls in your code
3. **Check the event count indicator** at the top of the tab

---

### Problem: System Order Tab Shows Grayed-Out Systems

**Cause:** Systems are disabled (either manually or via ProjectSettings).

**Solutions:**
1. **Re-enable systems** by checking the **Enabled** checkbox
2. **Check ProjectSettings** for `ecs_debugger/disabled_systems` and remove entries
3. **Restart Godot** to reload ProjectSettings

---

### Problem: Debugger Panel is Frozen

**Cause:** The auto-refresh timer is paused or the refresh rate is set too low.

**Solutions:**
1. **Check the refresh rate slider** (default: 0.5s)
2. **Verify the scene is still running** (not paused)
3. **Restart the debugger** by closing and reopening the panel

---

### Problem: Event Payloads Show "<Object>" Instead of Data

**Cause:** The payload contains a type that doesn't serialize to JSON (e.g., `Node`, `Object`).

**Solutions:**
1. **Check the serialization rules** in the [Non-JSON Payloads](#non-json-payloads) section
2. **Modify event payloads** to use primitive types (int, float, String, Array, Dictionary)
3. **Use custom serialization** by converting objects to dictionaries before publishing

---

## Known Limitations

### 1. Single Manager Support

The debugger only supports **one `M_ECSManager`** per scene. If multiple managers are detected:
- The first manager in the group is used
- A warning is logged: `"ECS Debugger: Multiple managers found, using first"`

**Workaround:** Use a single centralized manager for all ECS operations.

---

### 2. Editor-Only Data Display

The debugger **cannot display data while in the editor** (when not running a scene). This is because `M_ECSManager._ready()` doesn't run in edit mode.

**Workaround:** Always run the scene (F5/F6) to see debugger data.

---

### 3. Event History Limit

The event history buffer has a fixed size (default: 1000 events). Once full:
- **Oldest events are discarded** automatically
- The count indicator shows **"1000 / 1000 events (limit reached)"**

**Workaround:** Export events to clipboard periodically to preserve history.

---

### 4. No Historical Query Data

The Queries tab only shows **current session metrics**. Query call counts, hit rates, and durations **reset to zero** when the scene restarts.

**Workaround:** Take screenshots or manually record metrics for long-term tracking.

---

### 5. ProjectSettings Persistence

Disabled system states are saved to **ProjectSettings** (not EditorSettings), which means:
- **Changes are committed to version control** (in `project.godot`)
- **All developers share the same disabled state** (unless manually changed)

**Workaround:** Use ProjectSettings for intentional long-term disables, or manually re-enable systems after testing.

---

### 6. Performance Impact

The debugger polls `M_ECSManager.get_query_metrics()` and `ECSEventBus.get_event_history()` at the configured refresh rate (default: 0.5s).

**Frame Impact:**
- **Minimal** (<0.1ms per refresh on typical projects)
- **Increased** if you have hundreds of queries or thousands of events

**Workaround:** Increase the refresh rate slider (e.g., 2.0s) if you notice frame drops.

---

### 7. No Undo for Clear Events

Clearing event history is **permanent**. There is no undo functionality.

**Workaround:** Export events to clipboard before clearing, or use the confirmation dialog as a double-check.

---

### 8. No Real-Time System Priority Editing

You cannot change system execution priorities from the debugger. The **Priority** column is read-only.

**Workaround:** Modify `execution_priority` values in system scripts and restart the scene.

---

## Summary

The ECS Debugger provides three powerful tools for inspecting and optimizing your ECS architecture:
1. **Queries Tab**: Monitor performance and cache efficiency
2. **Events Tab**: Filter, inspect, and export event history
3. **System Order Tab**: View execution order and toggle systems at runtime

**Key Reminders:**
- Run the scene (F5/F6) to see data
- Use color coding and sorting to quickly identify issues
- Export data for detailed analysis or bug reports
- Be mindful of ProjectSettings persistence for disabled systems

For technical details and architecture, see:
- `docs/ecs plugin tool/ecs_plugin_tool_architecture.md`
- `docs/ecs plugin tool/ecs_plugin_tool_ELI5.md`

For implementation steps, see:
- `docs/ecs plugin tool/ecs_plugin_tool_plan.md`

Happy debugging!
