# Save Manager Continuation Prompt

**Current Phase**: Phase 5 Complete ✅ - Ready for Phase 6 (Menu Integration)
**Branch**: `save-manager-v2`
**Last Updated**: 2025-12-23 (UI Layer Complete)

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

✅ **Phase 4.5 Complete** (2025-12-23, commit 23d12ba):
- ✅ Added screenshot support to prevent Bug #2 from LESSONS_LEARNED.md
- ✅ Added `screenshot_data: PackedByteArray` to RS_SaveSlotMetadata
- ✅ Implemented `_capture_viewport_screenshot()` in U_SaveManager
- ✅ Screenshot capture: 256x144 PNG thumbnail with LANCZOS interpolation
- ✅ Headless mode detection (gracefully skips capture in tests)
- ✅ Verified mode management pattern in Redux (prevents Bug #8)
- ✅ **Total tests**: 40/40 passing (no regressions)

✅ **Phase 5 Complete** (2025-12-23, commit 5487b2a):
- ✅ Created `scenes/ui/ui_save_slot_selector.tscn` - Save/load overlay UI
- ✅ Created `scripts/ui/ui_save_slot_selector.gd` - Overlay controller
- ✅ Created `resources/ui_screens/save_slot_selector_overlay.tres` - Screen definition
- ✅ Registered in `u_ui_registry.gd` and `u_scene_registry.gd`
- ✅ Implemented Mode enum (SAVE, LOAD) with dynamic UI updates
- ✅ Implemented slot display with metadata (timestamp, location, health, deaths)
- ✅ Implemented screenshot display and caching system
- ✅ Implemented save/load/delete operations with confirmation dialogs
- ✅ Implemented focus navigation (vertical slots + horizontal actions)
- ✅ Added playtime tracking and formatting
- ✅ Prevented all bugs from LESSONS_LEARNED.md (focus, overlay closing, mode management)
- ✅ **Total tests**: 81/81 passing (22 integration + 59 unit tests)

❌ **Not Started**:
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

### ✅ Phase 1-5 Complete - Ready for Phase 6 (Menu Integration)

**Phase 5 Accomplishments** (commit 5487b2a):
- ✅ Full UI layer implementation complete
- ✅ Overlay with dynamic SAVE/LOAD modes
- ✅ Screenshot display and caching
- ✅ Confirmation dialogs (overwrite, delete)
- ✅ Focus navigation using U_FocusConfigurator
- ✅ All LESSONS_LEARNED.md bugs prevented
- ✅ 81/81 tests passing (no regressions)

**Phase 5 Key Implementation Patterns**:
1. **Two-Tier Focus System**:
   - Vertical navigation for slots (up/down)
   - Horizontal navigation for actions within slot (left/right)
   - U_FocusConfigurator handles neighbor setup

2. **Screenshot Caching**:
   - TextureRect nodes created/cached per slot
   - Prevents redundant image loading
   - Gracefully handles missing screenshots

3. **Overlay Closing Pattern**:
   ```gdscript
   # CORRECT: Close overlay first, then dispatch load
   close()
   await get_tree().process_frame
   store.dispatch(U_SaveActions.load_started(slot_index))
   ```
   This prevents Bug #6 (menu reopening, player stuck)

4. **Mode Management**:
   ```gdscript
   # CORRECT: Dispatch mode BEFORE opening overlay
   store.dispatch(U_SaveActions.set_save_mode("SAVE"))
   scene_manager.push_overlay(StringName("save_slot_selector_overlay"))
   ```
   This prevents Bug #8 (wrong dialog type)

### Immediate Next Actions: Phase 6 (Menu Integration)

**Goal**: Wire save/load overlay to pause menu and main menu

**Step 1: Pause Menu Integration**
1. **Modify `scenes/ui/ui_pause_menu.tscn`**:
   - Add "Save Game" button to menu
   - Update focus chain to include new button

2. **Modify `scripts/ui/ui_pause_menu.gd`**:
   - Add `_on_save_pressed()` handler
   - Dispatch `U_SaveActions.set_save_mode("SAVE")`
   - Dispatch `U_NavigationActions.open_overlay("save_slot_selector_overlay")`

**Step 2: Main Menu Integration**
1. **Modify `scenes/ui/ui_main_menu.tscn`**:
   - Add "Continue" button (loads most recent save)
   - Add "Load Game" button (opens load overlay)
   - Update focus chain

2. **Modify `scripts/ui/ui_main_menu.gd`**:
   - Add `_update_button_visibility()` (hide Continue if no saves)
   - Add `_on_continue_pressed()` (auto-load most recent)
   - Add `_on_load_pressed()` (open selector in LOAD mode)
   - Call visibility update in `_ready()`

**Step 3: After Phase 6**
- Move to Phase 7: Load Flow (connect Redux actions to scene transitions)
- Move to Phase 8: Polish (error handling, visual feedback)
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
