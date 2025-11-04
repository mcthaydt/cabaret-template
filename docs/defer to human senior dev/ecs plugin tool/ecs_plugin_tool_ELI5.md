# ECS Debugger Plugin - Explain Like I'm 5

**Purpose**: A simple, friendly guide to understanding and using the ECS Debugger Plugin.

**Last Updated**: 2025-10-23 (Shelved)

> **Status Notice (2025-10-23):** The ECS debugger plugin project has been de-scoped. This ELI5 guide reflects the original vision and is kept for archival purposes.

---

## What Is It? (The Simple Version)

Imagine you're building a LEGO city, and you need to know:
- **Which pieces are being used the most?** (Query Metrics)
- **What events happened today?** (Event History)
- **Which workers are currently building?** (System Status)

Without the debugger, you'd have to manually write down every time you use a piece, every event that happens, and check each worker one by one. **That's exhausting!**

**The ECS Debugger Plugin is like a magical display board** that shows you all this information automatically, updating every half-second, right in your Godot editor!

---

## The Big Picture

```
Your Game with ECS
├─ M_ECSManager ← Keeps track of all components
├─ U_ECSEventBus ← Records all events
├─ Systems ← Process components
└─ Components ← Store data

ECS Debugger Plugin
├─ Queries Tab ← "Which pieces am I using most?"
├─ Events Tab ← "What events just happened?"
└─ System Order Tab ← "Which workers are building?"
```

**Every 0.5 seconds (you can change this!), the plugin asks:**
1. "Hey M_ECSManager, what queries ran recently?" → Shows in Queries tab
2. "Hey U_ECSEventBus, what events happened?" → Shows in Events tab
3. "Hey M_ECSManager, which systems are running?" → Shows in System Order tab

**You see the answers instantly in the editor!**

---

## Where to Find It

### Step 1: Enable the Plugin

```
1. Open your Godot project
2. Click "Project" menu → "Project Settings"
3. Click "Plugins" tab on the left
4. Find "ECS Debugger" in the list
5. Check the "Enable" box
6. Close Project Settings
```

### Step 2: Open the Panel

```
1. Look at the bottom of the editor (where "Output" and "Debugger" are)
2. You should see a new tab called "ECS Debug"
3. Click it!
```

### Step 3: Run a Scene with M_ECSManager

**IMPORTANT**: The debugger only shows data when a scene is **running** (F5 or F6).

**Why?** The M_ECSManager only registers itself when the scene starts playing. In the editor (when not running), the manager isn't active yet, so the debugger can't find it.

```
1. Open a scene that has M_ECSManager (like player_template.tscn or base_scene_template.tscn)
2. Press F5 (run project) or F6 (run current scene)
3. The debugger panel will automatically find the manager
4. All three tabs will populate with live data!
```

**If you see "No ECS Manager found. Run the scene (F5/F6) to see data.":**
- The scene isn't running yet → Press F5 or F6
- You're in a scene without M_ECSManager → Open a different scene with the manager
- Click "Refresh" button after starting the scene

---

## The Three Tabs Explained

### Tab 1: Queries (Performance Detective)

**What it does**: Shows how often queries run and how fast they are.

**When to use it**: When your game feels slow or stutters.

**What you see**:

```
Simple (1) ▼
  └─ req:C_MovementComponent|opt: [120 calls, 95% hit rate, 0.4ms]

Moderate (2-3) ▼
  └─ req:C_MovementComponent,C_InputComponent|opt: [120 calls, 97% hit rate, 0.3ms]

Complex (4+) ▼
  └─ req:C_Movement,C_Input,C_Jump,C_Floating|opt: [3600 calls, 5% hit rate, 2.5ms]
```

**How to read it**:

**Simple/Moderate/Complex** = Groups queries by how many components they need
- Simple: 1 component (easy, fast)
- Moderate: 2-3 components (okay)
- Complex: 4+ components (harder, can be slow)

**[120 calls, 95% hit rate, 0.4ms]**:
- **120 calls** = Query ran 120 times since you opened the scene
- **95% hit rate** = 95% of the time, results were cached (didn't need to search again) ← GOOD!
- **0.4ms** = Last time it ran, it took 0.4 milliseconds ← FAST!

**What to look for**:

🟢 **Healthy Query**: High hit rate (>80%), low time (<1ms)
```
req:C_MovementComponent,C_InputComponent|opt: [120 calls, 97% hit rate, 0.3ms] ← GOOD!
```

🔴 **Problem Query**: Low hit rate (<50%), high time (>1ms)
```
req:C_Movement,C_Input,C_Jump,C_Floating|opt: [3600 calls, 5% hit rate, 2.5ms] ← BAD!
```

**What to do when you find a problem**:
1. Note which query is slow (copy the "req:..." text)
2. Search your code for that query (usually in a system's `process_tick()`)
3. Ask yourself: "Am I calling this query too often?"
4. Move it outside loops or cache the result

**Column Toggle Button**:

Click **"Show Detailed"** to see ALL 9 columns (useful for deep investigation):
- Query ID
- Required Components
- Optional Components
- Total Calls
- Cache Hits
- Hit Rate %
- Last Duration
- Last Result Count
- Last Run Time

Click **"Show Essential"** to see only 4 columns (quick scanning):
- Query ID
- Total Calls
- Hit Rate %
- Last Duration

---

### Tab 2: Events (Event Detective)

**What it does**: Shows all events that happened in your game, like a journal.

**When to use it**: When something isn't working right and you need to see if events are firing.

**What you see**:

```
Filter: [jump______] ← You typed "jump" here

Showing 3 events

[14:32:15.234] entity_jumped
[14:32:16.102] entity_jumped
[14:32:17.456] entity_jumped

Payload (when you click an event):
{
  "entity": <CharacterBody3D#12345>,
  "velocity": Vector3(0, 5.2, 0),
  "position": Vector3(10, 2, 5),
  "jump_time": 1634567890.123
}
```

**How to use it**:

1. **Type in the filter box** to find specific events:
   - Type "jump" → Shows only events with "jump" in the name
   - Type "particle" → Shows only particle events
   - Leave blank → Shows ALL events

2. **Click an event** in the left list to see its details on the right

3. **Read the payload** to understand what data was included:
   - `entity`: Which entity did this?
   - `velocity`: How fast was it moving?
   - `position`: Where did it happen?

4. **Export events** by clicking "Export to Clipboard":
   - Copies the filtered events as JSON
   - Paste into bug reports or share with teammates
   - Example: "Here's the event sequence before the crash..."

5. **Clear history** by clicking "Clear History":
   - Shows a confirmation ("Are you sure?")
   - Clears all events (useful for starting a fresh test)

**Example Workflow**:

```
Problem: "Jump particles aren't spawning"

1. Open Events tab
2. Type "jump" in filter
3. Look for events... see no "particle_spawn" events!
4. Conclusion: Particle system isn't listening to jump events
5. Fix: Add U_ECSEventBus.subscribe("entity_jumped", ...) in particle system
6. Re-test, see "particle_spawn" events appearing!
```

**Event Count Indicator**:

- **"Showing 15 events"** = 15 events match your filter
- **"Showing 1000 events (oldest truncated)"** = Event history is full (max 1000), oldest events were removed

---

### Tab 3: System Order (System Controller)

**What it does**: Shows all systems in execution order, lets you turn them on/off.

**When to use it**: When you need to test one system at a time or check execution order.

**What you see**:

```
System Name              Priority    Enabled
S_InputSystem            0           [✓]
S_JumpSystem             40          [✓]
S_MovementSystem         50          [✓]
S_GravitySystem          60          [✗] ← Disabled, grayed out
S_FloatingSystem         70          [✓]
```

**How to read it**:

**System Name** = Which system is this? (e.g., S_InputSystem handles input)

**Priority** = Execution order number (lower runs first):
- 0 → Runs FIRST
- 100 → Runs LAST
- Systems run in priority order every frame

**Enabled** checkbox:
- [✓] = System is RUNNING (processing components every frame)
- [✗] = System is DISABLED (skipped during processing) ← grayed text with "(disabled)" prefix

**How to use it**:

1. **Check execution order**: Make sure systems run in the right order
   - Input should run BEFORE movement
   - Gravity should run AFTER floating (so float can override gravity)

2. **Disable systems for testing**:
   - Uncheck S_GravitySystem to test movement without gravity
   - Uncheck S_JumpSystem to test movement without jumping
   - Uncheck S_FloatingSystem to test normal gravity

3. **Test in isolation**:
   - Disable ALL systems except one
   - Run the game, see if that one system works correctly
   - Re-enable others one-by-one to find which one breaks it

**Example Workflow**:

```
Problem: "Player is falling through the floor"

1. Open System Order tab
2. See which systems are enabled
3. Disable S_GravitySystem to test without gravity
4. Run game → Player stays still (no falling)
5. Re-enable S_GravitySystem
6. Disable S_FloatingSystem (maybe it's interfering?)
7. Run game → Player falls correctly now!
8. Conclusion: S_FloatingSystem has a bug
9. Fix the floating system
```

**Persistence (Magic Feature!)**:

When you disable a system, it **stays disabled even after you restart Godot!**

This is saved in ProjectSettings (`ecs_debugger/disabled_systems`).

**To reset**: Just re-check the checkboxes and the state is saved again.

---

## The Controls

### Refresh Rate Slider

**What it does**: Controls how often the panel updates.

**Where**: Top of the panel, says "Refresh Rate: [slider] 0.5s"

**How to use**:
- **Drag left** (0.1s) = Updates very fast (10 times per second) ← Use for live monitoring
- **Drag middle** (0.5s) = Default, updates twice per second ← Good balance
- **Drag right** (5.0s) = Updates slowly (once every 5 seconds) ← Use for manual review

**Why change it?**
- **Fast refresh (0.1s)**: Watch metrics change in real-time as you play
- **Slow refresh (5.0s)**: Reduce visual noise, save performance when panel is open but not actively debugging

### Refresh Now Button

**What it does**: Immediately updates all tabs (doesn't wait for timer).

**When to use**:
- You made a change and want to see results NOW
- You just opened a scene and want to refresh manually
- Timer is set slow (5.0s) but you want a quick update

---

## Common Scenarios

### Scenario 1: "My game is laggy"

```
1. Open ECS Debug → Queries tab
2. Click "Show Detailed" to see all columns
3. Expand all groups (Simple, Moderate, Complex)
4. Look for queries with:
   - High call counts (>1000)
   - Low hit rates (<50%)
   - High durations (>1ms)
5. Copy the query ID (e.g., "req:C_Movement,C_Input,C_Jump,C_Floating|opt:")
6. Search your code for that query
7. Find where it's called (probably in a system's process_tick)
8. Optimize: Move outside loops, cache the result, or reduce calls
```

### Scenario 2: "Events aren't firing"

```
1. Open ECS Debug → Events tab
2. Type event name in filter (e.g., "entity_jumped")
3. Run your game, try to trigger the event
4. Look at the event list...
   - If events appear: Event IS firing, problem is elsewhere (maybe subscriber not listening?)
   - If events DON'T appear: Event NOT firing, problem is in publisher (check S_JumpSystem code)
5. Click event to see payload, check data is correct
```

### Scenario 3: "System order is wrong"

```
1. Open ECS Debug → System Order tab
2. Read the list from top to bottom (top runs first)
3. Check if order makes sense:
   - Input → Movement → Jump → Gravity → Floating ← CORRECT ORDER
   - Jump → Input → Movement ← WRONG! Jump runs before input is read!
4. Fix priorities in your system files:
   - S_InputSystem: execution_priority = 0 (first)
   - S_JumpSystem: execution_priority = 40 (after input)
   - S_MovementSystem: execution_priority = 50 (after jump)
```

### Scenario 4: "I want to test without gravity"

```
1. Open ECS Debug → System Order tab
2. Find S_GravitySystem in the list
3. Uncheck the checkbox next to it
4. System grays out (visual feedback)
5. Run your game → Player moves without falling!
6. Test your movement mechanics
7. When done, re-check the checkbox to restore gravity
8. (Bonus: The disabled state persists even after restarting Godot!)
```

### Scenario 5: "I need to share a bug report"

```
1. Reproduce the bug while ECS Debug → Events tab is open
2. Type keyword in filter (e.g., "particle" if it's a particle bug)
3. Click "Export to Clipboard"
4. Paste into bug report:

   "Here's the event sequence before the crash:
   [14:32:15.234] entity_jumped { velocity: (0, 5.2, 0), position: (10, 2, 5) }
   [14:32:15.240] particle_spawn_requested { position: (10, 2, 5), count: 10 }
   [14:32:15.245] particle_spawn_requested { position: (10, 2, 5), count: 10 } ← DUPLICATE!
   [14:32:15.250] CRASH"

5. Team can now see exact event sequence and reproduce!
```

---

## Mental Models (Ways to Think About It)

### The Dashboard Analogy

The ECS Debugger is like **your car's dashboard**:

- **Queries Tab** = Speedometer + Fuel Gauge
  - Shows how fast queries run (speed)
  - Shows cache efficiency (fuel efficiency)
  - Alerts you when something's wrong (red zones)

- **Events Tab** = Trip Computer / Event Log
  - Records every event (like a trip log: "Left home at 2:00pm, Arrived at store at 2:15pm")
  - You can filter to see specific types of events (e.g., only show "refueling" events)
  - You can export the log for record-keeping

- **System Order Tab** = Maintenance Panel
  - Shows which engine components are running (systems)
  - Lets you temporarily disable components for testing (e.g., turn off AC to test engine alone)
  - Shows the order components run in (e.g., fuel pump → engine → transmission)

**Just like a car dashboard helps you drive safely and diagnose problems, the ECS Debugger helps you develop efficiently and fix bugs quickly!**

### The Security Camera Analogy

The ECS Debugger is like **a security camera system** for your code:

- **Queries Tab** = Traffic Monitor
  - Shows how many times each "door" was opened (query called)
  - Shows if people are using cached badges (cache hits) or manual entry (cache miss)
  - Alerts you to congestion (slow queries)

- **Events Tab** = Event Recorder
  - Records every event with timestamp
  - You can replay events (inspect payload)
  - You can filter to see specific types of events (e.g., only show "door opened" events)
  - You can export recordings for evidence (bug reports)

- **System Order Tab** = Guard Schedule
  - Shows which guards are on duty (systems enabled)
  - Shows the order guards patrol (priority order)
  - Lets you temporarily suspend guards for testing (disable systems)

---

## Tips & Tricks

### Tip 1: Use Essential Mode for Quick Scanning

Don't need all 9 columns? Click **"Show Essential"** in Queries tab to see only:
- Query ID
- Total Calls
- Hit Rate %
- Last Duration

Perfect for quick performance checks!

### Tip 2: Set Refresh Rate Based on Task

- **Debugging actively?** → 0.1s (real-time updates)
- **General development?** → 0.5s (default, good balance)
- **Just checking once in a while?** → 5.0s (manual refresh mostly)

### Tip 3: Filter Events Before Exporting

Before clicking "Export to Clipboard", type a filter to only export relevant events:
- Type "jump" → Only export jump-related events
- Type "particle" → Only export particle events
- Cleaner bug reports!

### Tip 4: Use System Toggles for Isolation Testing

Having a bug but not sure which system causes it?
1. Disable ALL systems
2. Re-enable them ONE AT A TIME
3. Test after each enable
4. When the bug appears, you found the culprit!

### Tip 5: Check Event Tab After Making Changes

Made a change to event publishing/subscribing?
1. Open Events tab
2. Clear history (fresh start)
3. Run your game, trigger the event
4. Check if event appears with correct payload
5. Instant feedback!

### Tip 6: Refresh Now After Scene Changes

Just loaded a new scene with different systems/components?
Click **"Refresh Now"** to immediately see the new state (don't wait for timer).

---

## Troubleshooting

### Problem: "I don't see the ECS Debug tab"

**Solution**:
1. Check if plugin is enabled: Project → Project Settings → Plugins → "ECS Debugger" (should be checked)
2. Restart Godot editor after enabling
3. Check for errors in Output tab (might be a plugin error)

### Problem: "It says 'No ECS Manager Found'"

**Solution**:
1. You're probably in a scene without M_ECSManager
2. Open a scene that has the manager (like player_template.tscn or base_scene_template.tscn)
3. Click "Retry" button
4. Tabs should populate!

### Problem: "Queries tab is empty"

**Solution**:
1. Manager might not have run any queries yet
2. Run the scene (press F6 or click "Play Scene")
3. Let it run for a few seconds
4. Queries should appear as systems execute

### Problem: "Events tab is empty"

**Solution**:
1. No events have been published yet
2. Run the scene and trigger events (e.g., make the player jump)
3. Events should appear in chronological order
4. If still empty, check if systems are publishing events via `U_ECSEventBus.publish(...)`

### Problem: "System toggles don't persist"

**Solution**:
1. Make sure you're toggling in System Order tab, not elsewhere
2. Check that ProjectSettings.save() isn't failing (check Output for errors)
3. Try manually saving: Project → Project Settings → click "Save" button
4. If still not working, check file permissions (can Godot write to project.godot?)

### Problem: "Refresh rate slider doesn't work"

**Solution**:
1. Check that slider is visible at top of panel
2. Make sure you're dragging the slider, not just clicking
3. Watch the label next to slider update (e.g., "0.5s" → "1.0s")
4. If timer isn't updating, restart plugin (disable/enable in Project Settings → Plugins)

### Problem: "Panel causes lag in editor"

**Solution**:
1. Increase refresh rate to 5.0s (less frequent updates)
2. Close tabs you're not using (click "X" on tab or just use one tab at a time)
3. If still laggy, disable plugin when not actively debugging

---

## Quick Reference Card

### Opening the Plugin

```
Project Settings → Plugins → Enable "ECS Debugger" → Bottom panel "ECS Debug" tab
```

### Queries Tab Cheat Sheet

```
🟢 GOOD: High hit rate (>80%), low time (<1ms)
🟡 OKAY: Medium hit rate (50-80%), medium time (1-2ms)
🔴 BAD:  Low hit rate (<50%), high time (>2ms)
```

### Events Tab Cheat Sheet

```
Type in filter → See matching events
Click event → See payload
"Export to Clipboard" → Copy JSON for bug reports
"Clear History" → Fresh start (requires confirmation)
```

### System Order Tab Cheat Sheet

```
Top of list = Runs FIRST (priority 0)
Bottom of list = Runs LAST (priority 1000)
[✓] = Enabled (processing every frame)
[✗] = Disabled (skipped, grayed out)
```

### Refresh Controls Cheat Sheet

```
Slider left (0.1s) = Fast refresh (real-time monitoring)
Slider middle (0.5s) = Default (good balance)
Slider right (5.0s) = Slow refresh (manual checking)
"Refresh Now" button = Immediate update (ignores timer)
```

---

## Common Questions

### Q: Do I have to keep the panel open all the time?

**A**: Nope! Only open it when you're actively debugging. Close it (or hide the bottom panel) during normal development. It doesn't run when hidden.

### Q: Will this slow down my game?

**A**: The plugin only reads data, it doesn't change anything. The refresh overhead is <0.1ms, which is tiny (60fps = 16.6ms per frame). You won't notice any slowdown.

### Q: Can I use this while my game is running?

**A**: By default, it works in the editor only. But you CAN use it at runtime if you manually add the panel to your game UI:

```gdscript
# In your debug overlay:
var debug_panel = preload("res://addons/ecs_debugger/t_ecs_debugger_panel.gd").new()
add_child(debug_panel)
```

Then the panel appears in your running game!

### Q: What if I have multiple M_ECSManagers?

**A**: The plugin will use the FIRST one it finds and show a warning. If you need to debug a different manager, you'd need to disable the first one temporarily. (Multi-manager support might come in a future version!)

### Q: Why do disabled systems stay disabled after restarting Godot?

**A**: This is a feature! The plugin saves disabled systems to ProjectSettings, so your debugging state persists. This is useful when you're debugging over multiple sessions. Just re-check the checkbox to re-enable.

### Q: Can I export event history to a file instead of clipboard?

**A**: Not in v1.0. The current version only copies to clipboard (you can then paste into a file manually). If this is important to you, let the team know!

### Q: What's the difference between "Essential" and "Detailed" columns?

**A**:
- **Essential** = 4 columns (ID, Calls, Hit %, Duration) ← Quick scanning
- **Detailed** = 9 columns (+ Required, Optional, Cache Hits, Result Count, Timestamp) ← Deep investigation

Use Essential for everyday debugging, Detailed when you need the full picture.

### Q: How do I know if a query is "too slow"?

**A**: General rule of thumb:
- <0.5ms = Fast (no worries)
- 0.5-1.0ms = Okay (monitor it)
- 1.0-2.0ms = Slow (optimize soon)
- >2.0ms = Very Slow (optimize NOW!)

Also look at hit rate:
- >80% = Good caching
- <50% = Cache thrashing (problem!)

---

## Summary

The ECS Debugger Plugin is your **X-ray vision for ECS**:

### Queries Tab = Performance Monitor
- See which queries are slow
- Check cache hit rates
- Identify optimization targets

### Events Tab = Event Journal
- See all events in chronological order
- Filter by event name
- Inspect payloads
- Export for bug reports

### System Order Tab = System Controller
- See execution order (priority)
- Enable/disable systems for testing
- State persists between sessions

### Refresh Controls = Update Settings
- Adjust refresh rate (0.1s to 5.0s)
- Manual refresh button
- Balance real-time vs. performance

**Bottom Line**: This plugin turns ECS debugging from **hours of manual logging** into **seconds of visual inspection**. It's like having a magnifying glass for your code!

---

## Next Steps

Want to learn more? Check out:

- **docs/ecs plugin tool/ecs_plugin_tool_architecture.md** - Detailed technical architecture
- **docs/ecs plugin tool/ecs_plugin_tool_prd.md** - Product requirements and use cases
- **docs/ecs plugin tool/ecs_debugger_usage.md** - Advanced usage guide (created after implementation)
- **docs/ecs/** - ECS architecture documentation
- **addons/ecs_debugger/** - Plugin source code (after implementation)

**Happy debugging!** 🎉
