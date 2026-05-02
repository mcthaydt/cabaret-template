# Phase 10B-6 T140c - Direct Manager Call Audit

**Date**: 2025-12-16
**Status**: ✅ Complete

## Audit Scope

Verify that:
1. Systems don't call `_scene_manager.*` methods directly
2. `M_SceneManager` is a pure event subscriber for game flow
3. State dispatches are used appropriately (not events)

---

## Results

### 1. Scene Manager Direct Calls in Systems

**Search**: `grep -r "_scene_manager\." scripts/ecs/systems/`

**Result**: ✅ **No direct calls found**

**Conclusion**: Phase 10B-1 successfully migrated all direct scene manager calls to events. Systems now publish events (`entity_death`, `victory_triggered`) instead of calling manager methods directly.

---

### 2. M_SceneManager as Event Subscriber

**Subscriptions** (from `scripts/managers/m_scene_manager.gd:207-211`):

```gdscript
# Subscribe to ECS events with priorities
# entity_death: Priority 10 (high - quick transition to game over)
_entity_death_unsubscribe = U_ECS_EVENT_BUS.subscribe(StringName("entity_death"), _on_entity_death, 10)
# victory_triggered: Priority 5 (medium - after S_VictorySystem processes state)
_victory_triggered_unsubscribe = U_ECS_EVENT_BUS.subscribe(StringName("victory_triggered"), _on_victory_triggered, 5)
```

**M_SceneManager State Dispatches** (legitimate):

| Line | Dispatch | Purpose |
|------|----------|---------|
| 418 | `transition_started(scene_id)` | Notify state of scene transition start |
| 428 | `transition_completed(scene_id)` | Notify state of scene transition completion |
| 917 | `push_overlay(scene_id)` | Notify state of overlay push |
| 931 | `pop_overlay()` | Notify state of overlay pop |
| 1009 | Navigation action | Notify state of navigation changes |

**Conclusion**: ✅ **M_SceneManager is a pure event subscriber for game flow**

- Subscribes to: `entity_death` (priority 10), `victory_triggered` (priority 5)
- Does NOT call other managers directly
- Only dispatches its OWN lifecycle state (transitions, overlays, navigation)
- This is the correct pattern: events for cross-system communication, state for internal lifecycle

---

### 3. State Dispatch Usage in ECS

**Found 20 dispatch calls across systems**:

| System | Dispatches | Purpose | Correct? |
|--------|-----------|---------|----------|
| `s_input_system.gd` | `update_move_input`, `update_look_input`, `update_jump_state`, `update_sprint_state` | Update input state from hardware | ✅ Yes |
| `s_touchscreen_system.gd` | `update_move_input`, `update_jump_state`, `update_sprint_state` | Update input state from touch | ✅ Yes |
| `s_movement_system.gd` | `update_entity_snapshot` | Update entity position/velocity in state | ✅ Yes |
| `s_jump_system.gd` | `update_entity_snapshot` | Update entity jump state | ✅ Yes |
| `s_rotate_to_input_system.gd` | `update_entity_snapshot` | Update entity rotation | ✅ Yes |
| `s_health_system.gd` | `take_damage`, `heal`, `increment_death_count`, `trigger_death`, `update_entity_snapshot` | Update health state | ✅ Yes |
| `s_victory_system.gd` | `trigger_victory`, `mark_area_complete` | Update objective/area completion | ✅ Yes |
| `s_checkpoint_system.gd` | `set_last_checkpoint` | Update respawn point | ✅ Yes |
| `c_scene_trigger_component.gd` | Spawn action | Trigger spawn point change | ✅ Yes |

**Pattern Analysis**:

✅ **Correct Usage** - State dispatches for:
- Input state (keyboard, gamepad, touchscreen)
- Entity state (position, velocity, rotation, health)
- Gameplay state (objectives, checkpoints, death count)

❌ **Should be Events** - None found

**Conclusion**: ✅ **All state dispatches are appropriate**

No dispatches should be converted to events. The current architecture correctly uses:
- **Events** → Cross-system communication (death → scene manager, victory → victory system)
- **State Dispatch** → Internal state updates (input, entity snapshots, gameplay state)

---

## Architecture Patterns (Confirmed Correct)

### Event vs State Dispatch Decision Matrix

| Use Case | Pattern | Example |
|----------|---------|---------|
| Cross-system notification | **Event** | `entity_death` → notifies scene manager & haptics |
| State update | **Dispatch** | `update_move_input` → stores input in state |
| Manager lifecycle | **Dispatch** | `transition_started` → tracks transition state |
| UI feedback | **Event** | `checkpoint_activated` → shows toast |
| Data persistence | **Dispatch** | `update_entity_snapshot` → stores entity state |

### Why This Separation?

**Events**:
- Decoupled pub/sub
- Multiple subscribers
- Priority ordering
- Doesn't persist in state
- Used for notifications and cross-cutting concerns

**State Dispatch**:
- Centralized state management
- Single source of truth
- State persistence
- Reducers validate/transform
- Used for application data

---

## Recommendations

### ✅ No Changes Needed

The current architecture is correct. All identified patterns follow best practices:

1. **Systems → Events** for cross-system communication
2. **Systems → State** for data updates
3. **Managers → Events** for subscribing to game flow
4. **Managers → State** for their own lifecycle

### Future Guidance

When adding new functionality, use:

- **Event** if:
  - Multiple systems need to react
  - Order matters (use priority)
  - Notification-style (fire and forget)
  - Example: `level_completed`, `power_up_collected`

- **State Dispatch** if:
  - Updating application data
  - Single source of truth needed
  - Need to query state later
  - Example: `update_score`, `set_difficulty`, `add_inventory_item`

---

## Phase 10B-6 T140c Status

✅ **COMPLETE**

- No direct manager calls in systems
- M_SceneManager is pure event subscriber for game flow
- All state dispatches are appropriate
- No architectural issues found
- Current patterns confirmed correct
