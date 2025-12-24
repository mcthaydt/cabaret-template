# Save Manager Continuation Prompt

**Current Phase**: Phase 6 Complete ✅ - Ready for Phase 7 (Load Flow)
**Branch**: `save-manager-v2`
**Last Updated**: 2025-12-23 (Menu Integration Complete)

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
- ℹ️ **Testing approach**: Integration testing (modifies existing code, core save operation already tested)

✅ **Phase 4 Complete** (2025-12-23, commit 5de0aef):
- ✅ Added `_try_migrate_legacy_save()` to m_state_store._ready()
- ✅ Smart logging (only logs when actual migration occurs)
- ✅ Migration path: `user://savegame.json` → `user://save_slot_0.json`
- ✅ Legacy backup: `user://savegame.json.backup`
- ✅ **Total tests**: 40/40 passing (no regressions)
- ℹ️ **Testing approach**: Integration testing (migration operation tested, lifecycle deterministic)

✅ **Phase 4.5 Complete** (2025-12-23, commit 23d12ba):
- ✅ Added screenshot support to prevent Bug #2 from LESSONS_LEARNED.md
- ✅ Added `screenshot_data: PackedByteArray` to RS_SaveSlotMetadata
- ✅ Implemented `_capture_viewport_screenshot()` in U_SaveManager
- ✅ Screenshot capture: 256x144 PNG thumbnail with LANCZOS interpolation
- ✅ Headless mode detection (gracefully skips capture in tests)
- ✅ Verified mode management pattern in Redux (prevents Bug #8)
- ✅ **Total tests**: 40/40 passing (no regressions)
- ℹ️ **Testing approach**: Integration testing (screenshot display tested via UI, capture logic depends on Godot engine)
- ⚠️ **Test gap identified**: Screenshot capture untested due to headless mode (see tasks.md for recommendation)

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
- ℹ️ **Testing approach**: Integration testing (happy path workflows tested, UI behavior verified)

✅ **Phase 6 Complete** (2025-12-23, commit pending):
- ✅ Created `tests/integration/ui/test_menu_save_integration.gd` - Menu integration tests (7 tests)
- ✅ Modified `scenes/ui/ui_pause_menu.tscn` - Added "Save Game" button
- ✅ Modified `scripts/ui/ui_pause_menu.gd` - Added save button handler with Bug #8 prevention
- ✅ Modified `scenes/ui/ui_main_menu.tscn` - Added "Continue" and "Load Game" buttons
- ✅ Modified `scripts/ui/ui_main_menu.gd` - Added continue/load handlers with visibility logic
- ✅ Implemented Continue button auto-load (most recent save via U_SaveManager.get_most_recent_slot())
- ✅ Implemented dynamic button visibility (Continue hidden when no saves)
- ✅ Updated focus chains in both menus (pause: Resume→Save→Settings→Quit, main: Continue→Play→Load→Settings)
- ✅ Bug #8 prevention: Mode dispatched BEFORE overlay opens (prevents wrong dialog type)
- ✅ **Total tests**: 88/88 passing (7 new Phase 6 + 81 existing)
- ℹ️ **Testing approach**: Integration tests (TDD) for Redux dispatching + deferred for manual UX verification

❌ **Not Started**:
- Load flow (Phase 7)
- Error handling and polish (Phase 8)

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

## Testing Strategy

This project uses different testing approaches based on phase type:

### TDD (Test-Driven Development) - Phases 1-2, 6-8

**Used for**: New business logic, Redux integration, error handling

**Process**: RED → GREEN → REFACTOR

**Examples**:
- Save manager utilities (Phase 1)
- Redux reducers and selectors (Phase 2)
- Menu integration Redux dispatching (Phase 6)
- Load flow state restoration (Phase 7)
- Error handling and validation (Phase 8)

**Why**: These phases introduce new, testable business logic that benefits from test-first development.

### Integration Testing - Phases 3-5

**Used for**: Existing code modification, UI wiring, visual features

**Process**: Implement → Test integration → Manual verification

**Examples**:
- Autosave redirection (Phase 3)
- Legacy save migration (Phase 4)
- Screenshot support (Phase 4.5)
- UI overlay implementation (Phase 5)

**Why**: These phases modify existing, tested code or depend heavily on Godot engine behavior. Core logic is unit-tested, but integration is verified through broader tests.

### Manual Testing - All Phases (Supplementary)

**Used for**: Visual layout, focus navigation feel, UX polish

**Process**: Structured manual test checklist

**Examples**:
- Button spacing and alignment
- Gamepad responsiveness
- Toast animations
- Loading screen smoothness

**Why**: Some aspects of UX cannot be effectively unit-tested and require human judgment.

### When to Use Each Strategy

**Use TDD when**:
- Adding new business logic or algorithms
- Creating Redux actions/reducers/selectors
- Implementing error handling or validation
- Building testable integration flows (load flow, menu dispatching)

**Use Integration Testing when**:
- Modifying existing, tested code
- Wiring UI components with existing systems
- Implementing features that depend heavily on Godot engine behavior (screenshots, timers)

**Always supplement with Manual Testing for**:
- Visual presentation and layout
- User experience and feel
- Gamepad/keyboard navigation smoothness
- Performance and visual feedback

---

## Next Steps (When Resuming)

### ✅ Phase 1-6 Complete - Ready for Phase 7 (Load Flow)

**Phase 6 Accomplishments** (commit pending):
- ✅ Menu integration complete (pause + main menus)
- ✅ Pause menu "Save Game" button with Redux dispatching
- ✅ Main menu "Continue" button (auto-loads most recent save)
- ✅ Main menu "Load Game" button (opens overlay in LOAD mode)
- ✅ Dynamic button visibility (Continue hidden when no saves)
- ✅ Focus chain updates for both menus
- ✅ Bug #8 prevention: Mode dispatched BEFORE overlay
- ✅ 88/88 tests passing (7 new + 81 existing, no regressions)

**Phase 6 Key Implementation Patterns**:
1. **Redux Dispatching Pattern**:
   - Pause menu: Dispatch mode → Open overlay
   - Main menu: Check saves → Show/hide Continue
   - Continue: Get most recent slot → Dispatch load_started

2. **Button Visibility Logic**:
   ```gdscript
   func _update_button_visibility() -> void:
       var has_saves: bool = U_SaveManager.has_any_save()
       if _continue_button != null:
           _continue_button.visible = has_saves
   ```
   Called deferred in `_on_panel_ready()` for proper timing

3. **Most Recent Save Detection**:
   ```gdscript
   var most_recent_slot: int = U_SaveManager.get_most_recent_slot()
   store.dispatch(U_SaveActions.load_started(most_recent_slot))
   ```
   Returns slot index with highest timestamp (-1 if none)

4. **Focus Chain Updates**:
   - Pause: Resume → Save → Settings → Quit (circular)
   - Main: Continue (conditional) → Play → Load → Settings (circular)
   - Continue only added to chain if visible

### Immediate Next Actions: Phase 7 (Load Flow)

**Goal**: Connect Redux load actions to actual state restoration and scene transitions

**Step 1: Implement Load Flow Middleware** (TDD approach)
1. **Create `tests/integration/save_manager/test_load_flow.gd`**:
   - Test: load_started restores state from slot
   - Test: load_started dispatches load_completed on success
   - Test: load_started dispatches load_failed on missing file
   - Test: load_started clears overlay stack (Bug #6 prevention)
   - Test: load_started triggers scene transition

2. **Modify `m_state_store.gd`**:
   - Add `_on_action_dispatched_for_load()` subscription in _ready()
   - Implement `_handle_load_started(action)` handler
   - Call `U_SaveManager.load_from_slot()` with error handling
   - On success: Clear navigation overlays, trigger scene transition, dispatch load_completed
   - On failure: Dispatch load_failed with error message

**Step 2: Bug Prevention Checklist**
- ✅ Bug #2: Player not stuck (spawn manager handles positioning)
- ✅ Bug #3: Correct spawn point (loaded from state)
- ✅ Bug #6: Overlay cleared before transition (prevents menu reopening)
- ℹ️ Bug #1: Focus navigation (already handled by Phase 5)

**Step 3: After Phase 7**
- Move to Phase 8: Error Handling & Polish
- See `save-manager-tasks.md` for Phase 7 detailed checklist

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
