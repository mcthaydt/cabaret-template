# Save Manager Continuation Prompt

**Current Phase**: Phase 3 Complete ✅ - Ready for Phase 4 (Migration)
**Branch**: `save-manager-v2`
**Last Updated**: 2025-12-23

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

✅ **Phase 3 Complete** (2025-12-23, commit pending):
- ✅ Modified `m_state_store._on_autosave_timeout()` to use U_SaveManager
- ✅ Added navigation shell check (only autosave in "gameplay")
- ✅ Added transition check (skip if is_transitioning)
- ✅ Autosave now writes to slot 0 via `U_SaveManager.save_to_auto_slot()`
- ✅ **Total tests**: 40/40 passing (no regressions)

❌ **Not Started**:
- Migration (Phase 4)
- UI layer (Phase 5)

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

### ✅ Phase 1, 2 & 3 Complete - Ready for Phase 4

**Phase 1 Accomplishments** (commit cff8a3b):
- ✅ All data layer utilities implemented
- ✅ 27/27 tests passing
- ✅ Timestamp precision bug fixed

**Phase 2 Accomplishments** (commit a82cdfc):
- ✅ Redux integration complete
- ✅ 40/40 tests passing (27 manager + 13 reducer)
- ✅ Save slice registered with transient fields

**Phase 3 Accomplishments** (commit pending):
- ✅ Autosave redirected to U_SaveManager
- ✅ Shell and transition checks implemented
- ✅ 40/40 tests still passing (no regressions)

### Immediate Next Actions: Phase 4 (Migration)

**Goal**: Migrate legacy `savegame.json` to slot 0 on first launch

**Step 1: Add Migration to m_state_store._ready()**
1. **Call migration helper**:
   - Add call to `U_SaveManager.try_migrate_legacy_save()` in `_ready()`
   - Log migration result if debug logging enabled
   - Migration should happen after store initialization but before UI load

2. **Test migration behavior**:
   - Create test `user://savegame.json` file
   - Verify migrates to `user://save_slot_0.json`
   - Verify legacy file renamed to `user://savegame.json.backup`
   - Verify slot 0 loads correctly after migration

**Step 2: After Phase 4**
- Move to Phase 5: UI Layer (save/load overlay)
- Move to Phase 6: Menu Integration (pause menu + main menu)
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
