# Save Manager Continuation Prompt

**Current Phase**: Phase 4.5 Complete ✅ - Ready for Phase 5 (UI Layer)
**Branch**: `save-manager-v2`
**Last Updated**: 2025-12-23 (Screenshot Support Added)

---

## ⚠️ CRITICAL: Previous Implementation Failed

**Context**: A previous implementation (Dec 19, 2025) was **deleted due to 8 critical bugs**.

**MUST READ FIRST**: [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - Contains all bugs and prevention strategies

**Key Bugs That Caused Deletion**:
1. Focus navigation completely broken
2. Load reopened menu + player stuck in air
3. Continue loaded wrong location first time
4. Button mappings backwards (accept/cancel swapped)
5. Screenshot feature missing
6. Mode detection broken (load triggered save dialog)

**This implementation starts from scratch with explicit bug prevention.**

---

## Context for Resuming Work

### What This Feature Does

Implements a multi-slot save system with:
- 3 manual save slots (user-initiated)
- 1 autosave slot (automatic, protected)
- Save slot metadata (timestamp, location, progress)
- Continue button (loads most recent save)
- Legacy save migration (savegame.json → slot 0 autosave)

### Current Status

✅ **Phase 1 Complete** (2025-12-23, commit cff8a3b):
- ✅ Data layer utilities (U_SaveManager, U_SaveEnvelope, RS_SaveSlotMetadata)
- ✅ 27/27 tests passing
- ✅ Timestamp precision bug fixed

✅ **Phase 2 Complete** (2025-12-23, commit a82cdfc):
- ✅ `rs_save_initial_state.gd` - Redux state resource
- ✅ `u_save_actions.gd` - Action creators (save/load/delete operations)
- ✅ `u_save_reducer.gd` - State reducer with immutable updates
- ✅ `u_save_selectors.gd` - Type-safe getter functions
- ✅ `tests/unit/state/test_save_reducer.gd` - 13/13 tests passing
- ✅ Save slice registered in m_state_store.gd
- ✅ **Total tests**: 40/40 passing (27 manager + 13 reducer)

✅ **Phase 3 Complete** (2025-12-23, commit 7abd336):
- ✅ Modified `m_state_store._on_autosave_timeout()` to use U_SaveManager
- ✅ Added navigation shell check (only autosave in "gameplay")
- ✅ Added transition check (skip if is_transitioning)
- ✅ Autosave now writes to slot 0 via `U_SaveManager.save_to_auto_slot()`
- ✅ **Total tests**: 40/40 passing (no regressions)

✅ **Phase 4 Complete** (2025-12-23, commit 5de0aef):
- ✅ Added `_try_migrate_legacy_save()` to m_state_store._ready()
- ✅ Smart logging (only logs when actual migration occurs)
- ✅ Migration path: `user://savegame.json` → `user://save_slot_0.json`
- ✅ Legacy backup: `user://savegame.json.backup`
- ✅ **Total tests**: 40/40 passing (no regressions)

✅ **Phase 4.5 Complete** (2025-12-23, commit pending):
- ✅ Added screenshot support to prevent Bug #2 from LESSONS_LEARNED.md
- ✅ Added `screenshot_data: PackedByteArray` to RS_SaveSlotMetadata
- ✅ Implemented `_capture_viewport_screenshot()` in U_SaveManager
- ✅ Screenshot capture: 256x144 PNG thumbnail with LANCZOS interpolation
- ✅ Headless mode detection (gracefully skips capture in tests)
- ✅ Verified mode management pattern in Redux (prevents Bug #8)
- ✅ **Total tests**: 171/171 passing (no regressions)

❌ **Not Started**:
- UI layer (Phase 5)
- Menu integration (Phase 6)

---

## Quick Start Guide

### To Resume This Feature

1. **Read the context**:
   ```
   docs/save_manager/save-manager-prd.md          # User stories, requirements
   docs/save_manager/save-manager-plan.md         # Implementation approach
   docs/save_manager/save-manager-tasks.md        # Task checklist
   ```

2. **Start with Phase 1** (Data Layer):
   - Create `scripts/state/utils/u_save_envelope.gd`
   - Create `scripts/state/utils/u_save_manager.gd`
   - See `save-manager-tasks.md` for detailed checklist

3. **Reference existing code**:
   - `scripts/state/utils/u_state_persistence.gd` - File I/O patterns
   - `scripts/state/utils/u_state_repository.gd` - Persistence coordination
   - `scripts/state/m_state_store.gd:710-780` - Current autosave implementation

4. **Follow patterns**:
   - Prefix conventions: `u_` for utilities, `rs_` for resources
   - Redux actions → reducers → selectors
   - BaseOverlay for UI overlays

---

## Key Architecture Decisions

### File Paths
```
user://save_slot_0.json  # Autosave (cannot be deleted)
user://save_slot_1.json  # Manual Slot 1
user://save_slot_2.json  # Manual Slot 2
user://save_slot_3.json  # Manual Slot 3
```

### Save Envelope Format
Each save wraps metadata + state in single JSON:
```json
{
  "metadata": {
    "slot_index": 1,
    "timestamp": 1734912345,
    "scene_display_name": "Exterior",
    "completion_percent": 40.0,
    "player_health": 75.0,
    ...
  },
  "state": {
    "gameplay": {...},
    "scene": {...},
    ...
  }
}
```

### Integration Points
- **M_StateStore**: Autosave timer redirected to slot 0
- **U_SaveManager**: Static utility for all slot operations
- **Redux**: New "save" slice tracks operation state
- **UI**: Save from pause menu, Load/Continue from main menu

---

## Critical Design Decisions

1. **Continue Button**: Loads most recent save (any slot) automatically
2. **Autosave Protection**: Slot 0 cannot be deleted by player
3. **New Game Flow**: Auto-selects first empty slot
4. **Migration**: Legacy `savegame.json` → slot 1, renamed to `.backup`

---

## Common Tasks

### Add a new save-related action
1. Define in `u_save_actions.gd`
2. Handle in `u_save_reducer.gd`
3. Dispatch from UI or M_StateStore

### Test save/load roundtrip
```gdscript
# Save
U_SaveManager.save_to_slot(1, state, slice_configs, false)

# Load
U_SaveManager.load_from_slot(1, state, slice_configs)
```

### Check if slot has data
```gdscript
var has_save := U_SaveEnvelope.slot_exists(1)
```

### Get slot metadata for UI
```gdscript
var meta := U_SaveManager.get_slot_metadata(1)
# Returns: {slot_index, timestamp, scene_name, is_empty, ...}
```

---

## Next Steps (When Resuming)

### ✅ Phase 1, 2, 3 & 4 Complete - Ready for Phase 5

**Phase 1 Accomplishments** (commit cff8a3b):
- ✅ All data layer utilities implemented
- ✅ 27/27 tests passing
- ✅ Timestamp precision bug fixed

**Phase 2 Accomplishments** (commit a82cdfc):
- ✅ Redux integration complete
- ✅ 40/40 tests passing (27 manager + 13 reducer)
- ✅ Save slice registered with transient fields

**Phase 3 Accomplishments** (commit 7abd336):
- ✅ Autosave redirected to U_SaveManager
- ✅ Shell and transition checks implemented
- ✅ 40/40 tests still passing (no regressions)

**Phase 4 Accomplishments** (commit pending):
- ✅ Legacy save migration implemented
- ✅ Smart logging for migration events
- ✅ 40/40 tests still passing (no regressions)

### Pre-Phase 5 Concerns Addressed

Before starting Phase 5 UI implementation, the following concerns from code review were addressed:

1. **Screenshot Feature** (Bug #2 Prevention):
   - Added `screenshot_data` field to metadata
   - Implemented viewport screenshot capture (256x144 PNG thumbnails)
   - Graceful degradation in headless/test environments

2. **Mode Management** (Bug #8 Prevention):
   - Verified `U_SaveActions.set_save_mode()` pattern
   - Redux state correctly tracks SAVE vs LOAD mode
   - Pattern: Dispatch mode BEFORE opening overlay

3. **Focus Navigation** (Bug #1 Prevention):
   - Two-tier focus pattern documented
   - Use `U_FocusConfigurator` for vertical slots + horizontal actions

4. **Overlay Closing** (Bug #6 Prevention):
   - Pattern documented: close → await frame → dispatch load
   - Prevents menu reopening and player physics bugs

### Immediate Next Actions: Phase 5 (UI Layer)

**Goal**: Create save/load overlay UI for slot selection

**Step 1: Create UI Scene**
1. **Create `scenes/ui/ui_save_slot_selector.tscn`**:
   - Extend BaseOverlay
   - Add TitleLabel (changes based on mode: "Save Game" vs "Load Game")
   - Add SlotContainer (VBoxContainer) with 4 slot buttons
   - Add BackButton for navigation
   - Configure unique names (%) for node references

2. **Create `scripts/ui/ui_save_slot_selector.gd`**:
   - Define Mode enum (SAVE, LOAD)
   - Implement set_mode() to switch between save/load
   - Implement _refresh_slots() to update UI from metadata
   - Implement _on_slot_pressed() to handle slot selection
   - Configure focus chain for gamepad navigation

**Step 2: Register Overlay**
1. Create `resources/ui_screens/save_slot_selector_overlay.tres`
2. Register in `u_ui_registry.gd`
3. Register scene in `u_scene_registry.gd`

**Step 3: After Phase 5**
- Move to Phase 6: Menu Integration (pause menu + main menu buttons)
- Move to Phase 7: Load Flow (scene transitions after load)
- See `save-manager-tasks.md` for full checklist

---

## Useful References

### Existing Patterns to Follow

**Save/Load I/O**:
- `scripts/state/utils/u_state_persistence.gd:35-89` - save_state()
- `scripts/state/utils/u_state_persistence.gd:91-145` - load_state()

**Redux Actions**:
- `scripts/state/actions/u_gameplay_actions.gd` - Action creator patterns
- `scripts/state/reducers/u_gameplay_reducer.gd` - Reducer patterns

**UI Overlays**:
- `scripts/ui/ui_pause_menu.gd` - BaseOverlay extension
- `scenes/ui/ui_pause_menu.tscn` - Overlay structure

**Metadata Display**:
- Format timestamp: `Time.get_datetime_string_from_unix_time(ts, true)`
- Scene display names: `U_SceneRegistry.get_scene(scene_id).get("display_name")`

### Testing Commands

Run style enforcement:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/style -gexit
```

---

## Blockers & Dependencies

**None currently** - All prerequisites exist:
- ✅ Redux state management in place
- ✅ U_StatePersistence working
- ✅ Overlay system functional
- ✅ Navigation actions pattern established

---

## Questions for Future Consideration

- Should we add save slot screenshots/thumbnails?
- Quicksave/quickload hotkeys for PC?
- Cloud save sync integration point?
- Playtime tracking accuracy (pause time excluded)?

---

**Remember**: Update this file after completing each phase with progress notes and any new patterns/pitfalls discovered.
