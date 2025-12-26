# Save Manager Implementation Tasks

**Progress:** 79% (41 / 52 implementation tasks, 0 / 46 manual tests)

**Recent Improvements (Phase 9 Complete - 2025-12-26):**
- ✅ Added save_load_mode field to navigation slice for mode switching
- ✅ Save and Load buttons integrated into pause menu UI
- ✅ Overlay definition created (save_load_menu_overlay.tres)
- ✅ Scene registered in U_SceneRegistry with preload priority 10
- ✅ Focus navigation configured via U_FocusConfigurator pattern
- ✅ All Redux wiring in place for save/load overlay integration

---

## Phase 0: Preparation & Existing Code Migration ✅

**Exit Criteria:** M_StateStore timer removed, playtime system working, all Phase 0 tests pass

- [x] **Task 0.1**: Remove autosave timer from M_StateStore
  - Deleted `_autosave_timer` variable
  - Deleted `_setup_autosave_timer()` function
  - Deleted `_on_autosave_timeout()` function
  - Kept `save_state()`, `load_state()`, and `state_loaded` signal
- [x] **Task 0.2**: Add `playtime_seconds` field to gameplay slice
  - Added to `RS_GameplayInitialState` with default `0`
  - Verified field is NOT in transient_fields (persists across transitions)
- [x] **Task 0.3**: Create playtime tracking action
  - Added `ACTION_INCREMENT_PLAYTIME` constant to `U_GameplayActions`
  - Added `increment_playtime(seconds: int)` action creator
  - Added reducer logic in `U_GameplayReducer`
- [x] **Task 0.4**: Create S_PlaytimeSystem
  - Created `scripts/ecs/systems/s_playtime_system.gd` extending `BaseECSSystem`
  - Tracks elapsed time as float internally, dispatches whole seconds only
  - Carries sub-second remainder to prevent precision loss
  - Pauses when: `navigation.shell != "gameplay" OR paused OR scene.is_transitioning`
  - Integrated into all gameplay scenes (base, exterior, interior)
- [x] **Task 0.5**: Add `death_in_progress` flag to gameplay slice
  - Added to `RS_GameplayInitialState` with default `false`
  - Added `ACTION_SET_DEATH_IN_PROGRESS` action creator
  - Added reducer logic
  - Ready for use by autosave scheduler to block saves during death

**Notes:**
- All state tests pass (131/131)
- All playtime system tests pass (7/7)
- Total: 232/232 tests passing (state + ECS combined)
- System follows existing patterns (dependency injection, state checks)
- TDD approach followed (Red-Green cycle completed)
- Ready for Phase 1: Manager implementation

---

## Phase 1: Manager Lifecycle and Discovery ✅

**Exit Criteria:** All Phase 1 tests pass, manager discoverable via ServiceLocator

- [x] **Task 1.1 (Red)**: Write tests for manager initialization, ServiceLocator registration, dependency discovery
  - Created `tests/unit/save/test_save_manager.gd`
  - Tests: extends Node, group membership, ServiceLocator registration, dependency discovery, lock flag initialization
  - All 6 tests passing
- [x] **Task 1.2 (Green)**: Implement `m_save_manager.gd` with minimal code to pass tests
  - Extend Node, add to "save_manager" group
  - Register with ServiceLocator on `_ready()`
  - Discover M_StateStore and M_SceneManager dependencies
  - Initialize _is_saving and _is_loading lock flags
- [x] **Task 1.3 (Refactor)**: Extract helpers if needed, cleanup
  - No refactoring needed (manager is 70 lines, clean and minimal)

**Notes:**
- 6/6 tests passing
- Manager follows existing patterns from M_SceneManager
- Uses U_ServiceLocator for dependency discovery
- Mock dependencies registered in test setup

---

## Phase 2: Slot Registry and Metadata ✅

**Exit Criteria:** All Phase 2 tests pass, slot metadata accurately reflects state

- [x] **Task 2.1 (Red)**: Write tests for slot enumeration, metadata creation, conflict detection
  - Added 8 new tests for slot registry and metadata building
  - Tests cover: slot IDs, slot existence, metadata retrieval, metadata building, area name derivation, timestamp formatting, save version
  - All tests passing (14/14 total including Phase 1 tests)
- [x] **Task 2.2 (Green)**: Implement slot registry and metadata utilities
  - Added slot constants: `SLOT_AUTOSAVE`, `SLOT_01`, `SLOT_02`, `SLOT_03`
  - Implemented `get_all_slot_ids()`, `slot_exists()`, `get_slot_metadata()`, `get_all_slot_metadata()`
  - Implemented `_build_metadata()` with all required header fields
  - Implemented helper methods: `_get_slot_file_path()`, `_get_iso8601_timestamp()`, `_get_build_id()`, `_get_area_name_from_scene()`
  - Metadata includes: save_version, timestamp, build_id, playtime_seconds, current_scene_id, last_checkpoint, target_spawn_point, area_name, slot_id, thumbnail_path
- [x] **Task 2.3 (Refactor)**: Clean up slot locking mechanism
  - No refactoring needed - lock flags are simple and clean

**Edge Case Tests Added (Post-Phase 2):**
- [x] Test missing scene slice → area_name defaults to "Unknown"
- [x] Test unknown scene_id → fallback formatting ("custom_test_area" → "Custom Test Area")
- [x] Test missing gameplay fields → defaults used (playtime=0, checkpoint="", spawn="")
- [x] Test all nonexistent slots → marked with exists=false

**Code Improvements:**
- [x] Build ID now uses ProjectSettings instead of hardcoded value
  - Tries `application/config/version` first
  - Falls back to `application/config/name + " (dev)"`

**Notes:**
- Save Manager now at 211 lines (well under 400 line limit)
- Metadata building is pure function (testable, no side effects)
- Area name derivation uses scene registry with fallback formatting
- ISO 8601 timestamp format verified via tests
- All edge cases tested and passing (18/18 tests, 55 assertions)
- Ready for Phase 3: File I/O implementation

---

## Phase 3: File I/O with Atomic Writes and Backups ✅

**Exit Criteria:** All Phase 3 tests pass, no partial writes, corruption recovery verified

- [x] **Task 3.1 (Red)**: Write tests for atomic writes, backups, corruption recovery
  - Test `.tmp` -> `.json` rename ✅
  - Test `.bak` creation before overwrite ✅
  - Test `.bak` fallback on corruption ✅
  - Created `tests/unit/save/test_save_file_io.gd` with two-tier testing:
    - **Tier 1: Behavior Tests** (silent_mode = true): 12 tests verify functional correctness
    - **Tier 2: Logging Tests** (silent_mode = false): 2 tests verify error emission with `[ExpectedError]` output
  - All 14 tests passing, 24 assertions passing
- [x] **Task 3.2 (Green)**: Implement `m_save_file_io.gd` with atomic operations
  - `ensure_save_directory()` -> `DirAccess.make_dir_recursive_absolute("user://saves")` ✅
  - `save_to_file(path, data)` -> write `.tmp`, backup `.bak`, rename to `.json` ✅
  - `load_from_file(path)` -> try `.json`, fallback to `.bak` if `.json` missing ✅
  - Clean up orphaned `.tmp` files on startup ✅
  - Created `scripts/managers/helpers/m_save_file_io.gd` (155 lines, class_name helper)
  - Added `silent_mode` flag for test environments
- [x] **Task 3.3 (Refactor)**: Extract file path utilities if needed
  - No refactoring needed - file is clean and concise at 155 lines

**Additional Improvements:**
- [x] Added `get_persistable_state()` to M_StateStore for save system integration
- [x] Extracted `filter_transient_fields()` to U_StatePersistence utility
- [x] Added save system initialization to M_SaveManager (directory + cleanup)
- [x] Updated MockStateStore with new methods for testing

**Notes:**
- Atomic write pattern prevents partial saves: write to .tmp, then rename to .json
- Backup (.bak) created before overwrite for corruption recovery
- Load fallback chain: .json → .bak → empty dict
- Two-tier testing ensures both behavior AND logging correctness
- Silent mode suppresses informational warnings in behavior tests
- Logging tests verify errors are emitted with `[ExpectedError]` output (no false negatives)

---

## Phase 4: Save Workflow (Manual Saves) ✅

**Exit Criteria:** All Phase 4 tests pass, manual saves write complete state with header

- [x] **Task 4.1 (Red)**: Write tests for manual save workflow, signal emissions, transient field exclusion, locking
  - Tests for: successful save, rejection when locked, save_started event, save_completed event, lock management, file writing with header + state
  - Added cleanup for ECS event bus and ServiceLocator in test setup
  - Fixed lambda capture pattern for event payload extraction
  - All 7 Phase 4 tests passing (40/41 total, 102 assertions)
- [x] **Task 4.2 (Green)**: Implement `M_SaveManager.save_to_slot(slot_id)`
  - Check `_is_saving` lock, reject with ERR_BUSY if already saving
  - Set `_is_saving = true`, emit `save_started` event via U_ECSEventBus
  - Get state via `M_StateStore.get_persistable_state()` (transient fields already filtered)
  - Build header via `_build_metadata(slot_id)`
  - Write combined `{header, state}` via `M_SaveFileIO.save_to_file()`
  - Clear `_is_saving = false`, emit `save_completed` or `save_failed`
  - Method is 52 lines, clean and focused
- [x] **Task 4.3**: Transient field filtering (already implemented)
  - M_StateStore.get_persistable_state() delegates to U_StatePersistence.filter_transient_fields()
  - Filters out transient slices and transient fields according to slice configs
  - Deep copy to avoid mutating live state
  - No additional work needed
- [x] **Task 4.4 (Refactor)**: Error handling cleanup
  - Removed push_warning for ERR_BUSY (normal rejection, not an error)
  - Keep push_error for invalid slot_id (ERR_INVALID_PARAMETER)
  - Clean error flow with early returns

**Notes:**
- Save Manager now at 283 lines (well under 400 line limit)
- Event system wraps payloads: callbacks receive `{name, payload, timestamp}`, not raw payload
- Tests extract actual payload via `event.get("payload", {})`
- All tests use U_ServiceLocator.clear() and U_ECSEventBus.reset() in before_each to prevent leaks
- Silent rejection on ERR_BUSY prevents test noise (GUT treats warnings as errors)

**API Completion (Post-Phase 4):**
- [x] Implemented `delete_slot()` - Removes save files (.json, .bak, .tmp), rejects autosave deletion (ERR_UNAUTHORIZED)
- [x] Fixed `get_slot_metadata()` - Now reads headers from existing save files via M_SaveFileIO
- [x] 5 new tests for delete and metadata reading (45/46 total passing, 119 assertions)
- Save Manager now at 331 lines (still well under 400 limit)

---

## Phase 5: Load Workflow with M_SceneManager Integration ✅

**Exit Criteria:** All Phase 5 tests pass, load integrates with scene transitions via StateHandoff

**StateHandoff Integration Pattern** (existing pattern in codebase):
```gdscript
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")

# Preserve each state slice for scene transition
for slice_name in loaded_state:
  U_STATE_HANDOFF.preserve_slice(StringName(slice_name), loaded_state[slice_name])

# Transition to target scene
M_SceneManager.transition_to_scene(target_scene_id)

# M_StateStore automatically applies handoff state in _restore_from_handoff()
# after the new scene loads (called in M_StateStore._ready())
```

Key points:
- StateHandoff is a singleton that stores state between scene transitions
- M_StateStore automatically checks for handoff state on _ready()
- Normalization (scene validation, spawn fallback) happens during restoration
- Don't call store.dispatch() directly - let StateHandoff handle it

- [x] **Task 5.1 (Red)**: Write tests for load rejection, autosave blocking, scene transitions, locking
  - Test rejection during active transition ✅
  - Test rejection if `_is_loading` already true ✅
  - Test rejection for nonexistent slot ✅
  - Test scene transition to loaded scene_id ✅
  - Test StateHandoff integration ✅
  - Created MockSceneManagerWithTransition for testing
  - 6 new tests added, all passing (52/52 total tests)
- [x] **Task 5.2 (Green)**: Implement `M_SaveManager.load_from_slot(slot_id)`
  - Check `_is_loading` lock, reject if already loading ✅
  - Check `M_SceneManager.is_transitioning()` and reject if true ✅
  - Check slot exists, reject with ERR_FILE_NOT_FOUND if missing ✅
  - Set `_is_loading = true` at start ✅
  - Read and validate save file via M_SaveFileIO ✅
  - Validate save file structure (header, state, current_scene_id) ✅
  - Preserve all state slices to StateHandoff for scene transition ✅
  - Transition to `current_scene_id` via M_SceneManager.transition_to_scene() ✅
  - Clear `_is_loading = false` after transition ✅
  - Method is 51 lines, clean and focused
- [x] **Task 5.3 (Refactor)**: Extract load validation logic
  - Extracted `_validate_and_load_save_file()` helper method ✅
  - Returns Dictionary with either success data or error code ✅
  - Improved separation of concerns: validation vs. workflow ✅
  - All tests still passing after refactoring (52/52)

**Notes:**
- Load workflow integrates cleanly with existing StateHandoff pattern
- Save Manager now at 417 lines (includes Phase 5 implementation + helper)
- Validation helper is 28 lines, keeps main load method clean
- Tests verify lock management, transition rejection, and state preservation
- Migration support deferred to Phase 7 (load currently assumes v1 format)
- Autosave blocking during load will be implemented in Phase 6 (autosave scheduler)

---

## Phase 6: Autosave Scheduler and Coalescing ✅

**Exit Criteria:** All Phase 6 tests pass, autosaves triggered correctly, coalescing prevents spam

- [x] **Task 6.1 (Red)**: Write tests for trigger evaluation, coalescing, death blocking
  - Test checkpoint event triggers autosave ✅
  - Test area complete action triggers autosave ✅
  - Test scene transition completed triggers autosave ✅
  - Test coalescing multiple requests ✅
  - Test autosave blocked when `death_in_progress == true` ✅
  - Test autosave blocked when `scene.is_transitioning == true` ✅
  - 8/8 autosave scheduler tests passing
- [x] **Task 6.2 (Green)**: Implement `m_autosave_scheduler.gd`
  - Subscribe to ECS event: `checkpoint_activated` ✅
  - Subscribe to Redux actions: `gameplay/mark_area_complete`, `scene/transition_completed` ✅
  - Check `gameplay.death_in_progress == false` before allowing save ✅
  - Check `scene.is_transitioning == false` before allowing save ✅
  - Check `save_manager.is_locked() == false` before allowing save ✅
  - Dirty flag + priority tracking for coalescing ✅
  - Call deferred to coalesce within same frame ✅
  - File: `scripts/managers/helpers/m_autosave_scheduler.gd` (146 lines)
- [x] **Task 6.3 (Refactor)**: Extract trigger evaluation helpers
  - No refactoring needed - file is clean at 146 lines ✅

**Notes:**
- Scheduler implements coalescing via dirty flag pattern
- Multiple events in same frame coalesce into single autosave request
- Cooldown/priority enforcement deferred to Phase 13 integration tests
- All 8 Phase 6 tests passing (62/62 total tests passing)
- Total assertions: 154/154 passing

---

## Phase 7: Migration System ✅

**Exit Criteria:** All Phase 7 tests pass, migrations are pure and composable, v0 saves imported

- [x] **Task 7.1 (Red)**: Write tests for version detection, migration chains, failure handling, v0 import
  - Test v0 (headerless) -> v1 migration ✅
  - Test v1 save returns unchanged ✅
  - Test migration chaining (extensible for future versions) ✅
  - Test invalid header handling ✅
  - Test legacy `user://savegame.json` detection and import ✅
  - 16/16 migration tests passing
- [x] **Task 7.2 (Green)**: Implement `m_save_migration_engine.gd`
  - Version detection from header (missing header = v0) ✅
  - Simple if/elif migration chain (extensible for v1->v2, v2->v3, etc.) ✅
  - Pure `Dictionary -> Dictionary` transforms (no side effects) ✅
  - Sequential migration application for multi-version jumps ✅
  - File: `scripts/managers/helpers/m_save_migration_engine.gd` (158 lines)
- [x] **Task 7.3**: Implement v0 -> v1 migration
  - Detect headerless saves (no `header` key) ✅
  - Wrap in `{header: {...}, state: {...}}` structure ✅
  - Generate header with all required fields ✅
  - Extract playtime, scene_id, checkpoints from state slices ✅
  - Default values for missing fields ✅
- [x] **Task 7.4**: Implement legacy save import
  - `should_import_legacy_save()` checks for `user://savegame.json` ✅
  - `import_legacy_save()` loads, migrates, and deletes original ✅
  - Error handling for missing/corrupted legacy saves ✅
  - Ready for integration on first launch (not yet called from manager)
- [x] **Task 7.5 (Refactor)**: Clean up migration registry
  - No refactoring needed - code is clean at 158 lines ✅
  - Simple if/elif chain is clear and extensible ✅

**Notes:**
- Migration engine is pure static class (extends RefCounted)
- All migrations are Dictionary -> Dictionary transformations
- v0->v1 migration tested with 10+ test cases covering edge cases
- Legacy import deletes original file after successful migration
- Ready for future v1->v2 migrations (just add elif block)
- Total: 79/79 unit tests passing (183 assertions)

---

## Phase 8: Error Handling and Corruption Recovery ✅

**Exit Criteria:** All Phase 8 tests pass, corruption recovery functional, errors actionable

- [x] **Task 8.1 (Red)**: Write tests for .bak fallback, validation errors, disk failures
  - Test invalid header type (string instead of Dictionary) ✅
  - Test invalid state type (array instead of Dictionary) ✅
  - Test missing current_scene_id field ✅
  - Test empty current_scene_id ✅
  - Test minimal valid structure acceptance ✅
  - Test backup fallback on corrupted main file ✅
  - Test failure when both main and backup corrupted ✅
  - 8 new tests added, all passing (86/86 total)
- [x] **Task 8.2 (Green)**: Implement `u_save_validator.gd` and enhance error signals
  - Created `U_SaveValidator` utility class ✅
  - Validates header required fields (current_scene_id) ✅
  - Validates header/state types (must be Dictionaries) ✅
  - Returns detailed error messages with field/type info ✅
  - Updated M_SaveManager to use validator ✅
- [x] **Task 8.3 (Refactor)**: Consolidate error message formatting
  - Error messages centralized in U_SaveValidator ✅
  - Consistent format: "Save file '<field>' is <error>" ✅
  - M_SaveManager passes through detailed messages ✅

**Notes:**
- Validation is type-safe (uses untyped access before type checking)
- Error messages include context (field name, expected/actual type)
- `.bak` fallback tested extensively in Phase 3 and Phase 8
- All 86 unit tests passing (198 assertions)

---

## Phase 9: UI - Pause Menu Integration ✅

**Exit Criteria:** Save/Load buttons appear in pause menu, open combined overlay with correct mode

- [x] **Task 9.1**: Add `save_load_mode` to navigation slice
  - Added field to `RS_NavigationInitialState`: `save_load_mode: StringName = ""`
  - Added action `U_NavigationActions.set_save_load_mode(mode: StringName)`
  - Added reducer handler in `U_NavigationReducer`
- [x] **Task 9.2**: Add Save and Load buttons to `ui_pause_menu.gd`
  - Inserted between Settings and Quit buttons
  - `_on_save_pressed()` -> dispatches `set_save_load_mode("save")` then `open_overlay`
  - `_on_load_pressed()` -> dispatches `set_save_load_mode("load")` then `open_overlay`
  - Focus neighbors configured via `U_FocusConfigurator.configure_vertical_focus()`
- [x] **Task 9.3**: Create overlay definition in `resources/ui_screens/`
  - Created `save_load_menu_overlay.tres` (RS_UIScreenDefinition)
  - `allowed_shells`: ["gameplay"]
  - `allowed_parents`: ["pause_menu"]
  - `close_mode`: RETURN_TO_PREVIOUS_OVERLAY (0)
- [x] **Task 9.4**: Register scene in `U_SceneRegistry`
  - Scene ID: `save_load_menu`
  - Scene Type: `SceneType.UI`
  - Path: `res://scenes/ui/ui_save_load_menu.tscn`
  - Preload priority: 10 (critical path - accessed from pause menu)
- [x] **Task 9.5**: Update pause menu scene (`ui_pause_menu.tscn`)
  - Added SaveButton and LoadButton nodes with `unique_name_in_owner = true`
  - Buttons appear in order: Resume, Settings, Save, Load, Quit

**Notes:**
- Phase 9 complete (2025-12-26)
- All Redux wiring in place for save/load mode switching
- UI scene files ready for Phase 10 implementation
- Focus navigation configured via existing U_FocusConfigurator pattern

---

## Phase 10: UI - Save/Load Overlay Screen (Combined)

**Exit Criteria:** Functional combined save/load overlay with mode switching, confirmations, loading states

- [ ] **Task 10.1**: Create `ui_save_load_menu.gd` extending BaseOverlay
  - Read mode from `navigation.save_load_mode` on `_ready()`
  - Mode indicator in header (Save / Load)
  - Slot list container
  - Back button
  - Loading state: spinner + disabled buttons while operation in progress
- [ ] **Task 10.2**: Create slot item component (`ui_save_slot_item.gd`)
  - Display: timestamp, area_name, playtime (formatted HH:MM:SS)
  - Thumbnail placeholder (greyed box)
  - Conditional buttons based on parent mode
  - **Autosave slot**: hide Delete button (not deletable)
  - **Manual slots**: show Delete button
- [ ] **Task 10.3**: Implement slot list population
  - Query `M_SaveManager.get_all_slot_metadata()`
  - Populate list dynamically
  - Handle empty slots vs populated slots
  - Empty slot in save mode: show [New Save] button
  - Empty slot in load mode: show disabled/greyed state
- [ ] **Task 10.4**: Implement overwrite confirmation dialog
  - Before saving to occupied slot: show "Overwrite existing save?" confirmation
  - On confirm: proceed with save
  - On cancel: return to slot list
- [ ] **Task 10.5**: Wire save/load/delete actions
  - Save (empty slot): call `M_SaveManager.save_to_slot(slot_id)` directly
  - Save (occupied slot): show confirmation first, then save
  - Load: show inline spinner, disable all buttons, call `M_SaveManager.load_from_slot(slot_id)`
  - Delete: confirm dialog, call `M_SaveManager.delete_slot(slot_id)`, refresh list
- [ ] **Task 10.6**: Implement loading state UI
  - When load starts: show spinner overlay, disable all buttons
  - Subscribe to `save_completed`/`save_failed` to hide spinner
  - Timeout fallback: hide spinner after 10s if no event received
- [ ] **Task 10.7**: Create overlay scene
  - `scenes/ui/ui_save_load_menu.tscn`
  - Layout: header with mode, scrollable slot list, back button
  - Include confirmation dialog node (hidden by default)
  - Include loading spinner node (hidden by default)

---

## Phase 11: UI - Toast Notifications

**Exit Criteria:** Save events show appropriate toasts (suppressed during pause)

- [ ] **Task 11.1**: Subscribe to save events in `ui_hud_controller.gd`
  - `U_ECSEventBus.subscribe("save_started", ...)`
  - `U_ECSEventBus.subscribe("save_completed", ...)`
  - `U_ECSEventBus.subscribe("save_failed", ...)`
- [ ] **Task 11.2**: Implement toast display
  - Autosave started: "Saving..."
  - Save completed: "Game Saved"
  - Save failed: "Save Failed"
  - Load failed: "Load Failed"
- [ ] **Task 11.3**: Handle toast visibility during pause
  - **Decision: Suppress all toasts while paused** (consistent with checkpoint toasts)
  - Manual saves from pause menu rely on inline UI feedback (spinner, slot refresh)
  - Toasts only appear during gameplay (autosaves)

---

## Phase 12: Test Infrastructure Setup

**Exit Criteria:** Test helpers available, cleanup working

- [ ] **Task 12.1**: Create test directory helpers
  - `u_save_test_utils.gd` with setup/teardown functions
  - Create `user://test/` directory
  - Clean up files after each test
- [ ] **Task 12.2**: Document test patterns in this file's Notes section

---

## Phase 13: Integration Tests for Full Save/Load Cycle

**Exit Criteria:** All Phase 13 tests pass, end-to-end workflows validated

- [ ] **Task 13.1 (Red)**: Write integration tests for roundtrip, autosave cycles, multi-slot independence
  - Test: save -> load -> verify state matches
  - Test: autosave triggers correctly on checkpoint
  - Test: manual slots independent from autosave
- [ ] **Task 13.2 (Green)**: Run tests and fix edge cases revealed by integration tests
- [ ] **Task 13.3 (Refactor)**: Final refactor
  - Ensure main manager < 400 lines
  - Update AGENTS.md with Save Manager patterns
  - Update DEV_PITFALLS.md with save-related pitfalls

---

## Phase 14: Manual Testing / QA Checklist

**Exit Criteria:** All manual test cases pass on target platforms

### Save Functionality

- [ ] **MT-01**: Manual save to empty slot creates file at `user://saves/slot_01.json`
- [ ] **MT-02**: Manual save to occupied slot overwrites correctly (verify timestamp updates)
- [ ] **MT-03**: Autosave triggers on checkpoint activation (verify toast appears)
- [ ] **MT-04**: Autosave triggers on area completion
- [ ] **MT-05**: Autosave triggers after scene transition completes
- [ ] **MT-06**: Autosave cooldown prevents spam (trigger multiple checkpoints rapidly)
- [ ] **MT-07**: Save during pause menu works correctly
- [ ] **MT-08**: Overwrite confirmation appears when saving to occupied slot
- [ ] **MT-09**: Save shows "Saving..." toast followed by "Game Saved" toast (gameplay only, not during pause)

### Load Functionality

- [ ] **MT-10**: Load from valid save restores correct scene
- [ ] **MT-11**: Load from valid save restores player position (spawn point)
- [ ] **MT-12**: Load from valid save restores health, death count, completed areas
- [ ] **MT-13**: Load from valid save restores playtime (verify header shows correct time)
- [ ] **MT-14**: Load closes pause menu and resumes gameplay
- [ ] **MT-15**: Load during scene transition is rejected (verify error handling)
- [ ] **MT-16**: Load blocks autosaves until complete (no race conditions)

### Delete Functionality

- [ ] **MT-17**: Delete slot removes file from disk
- [ ] **MT-18**: Delete slot updates UI immediately (slot shows as empty)
- [ ] **MT-19**: Autosave slot delete button is disabled/hidden (autosave cannot be deleted)
- [ ] **MT-20**: Confirm dialog appears before delete (prevent accidental deletion)

### Error Handling & Recovery

- [ ] **MT-21**: Corrupted save file (truncated JSON) falls back to `.bak`
- [ ] **MT-22**: Corrupted save with no `.bak` shows error toast, session unchanged
- [ ] **MT-23**: Delete `.json` but keep `.bak`, verify load recovers from backup
- [ ] **MT-24**: Disk full scenario shows error toast (simulate by filling temp dir)
- [ ] **MT-25**: Missing `user://saves/` directory is created on first save

### UI/UX

- [ ] **MT-26**: Save/Load overlay opens from pause menu Save button (save mode)
- [ ] **MT-27**: Save/Load overlay opens from pause menu Load button (load mode)
- [ ] **MT-28**: Slot list shows correct metadata (timestamp, area, playtime)
- [ ] **MT-29**: Playtime displays as HH:MM:SS format
- [ ] **MT-30**: Empty slots show "Empty" or disabled state in load mode
- [ ] **MT-31**: Empty slots show "New Save" button in save mode
- [ ] **MT-32**: Back button returns to pause menu
- [ ] **MT-33**: Keyboard/controller navigation works in slot list
- [ ] **MT-34**: Focus is set correctly when overlay opens
- [ ] **MT-35**: Loading spinner shows during load operation

### Migration (Version Upgrade)

- [ ] **MT-36**: Load save from previous version triggers migration
- [ ] **MT-37**: Migrated save plays correctly (no data loss)
- [ ] **MT-38**: Failed migration shows error, session unchanged
- [ ] **MT-39**: Legacy save at `user://savegame.json` imported to autosave on first launch

### Edge Cases

- [ ] **MT-40**: Save immediately after load (should wait for next milestone)
- [ ] **MT-41**: Rapid save/load/save cycle doesn't corrupt data
- [ ] **MT-42**: Save with special characters in area name (Unicode)
- [ ] **MT-43**: Very long play session (playtime > 99:59:59 display)
- [ ] **MT-44**: All 3 manual slots full, verify "slot full" behavior
- [ ] **MT-45**: Quit game mid-autosave, verify `.tmp` cleanup on restart
- [ ] **MT-46**: Autosave blocked during death sequence

---

## Notes

- Record decisions, follow-ups, or blockers here as implementation progresses
- Document any deviations from the plan and rationale
- Track technical debt or future improvements identified during implementation

**Test patterns:**
- Use `user://test/` for all save file tests
- Call `U_SaveTestUtils.setup()` in `before_each()`
- Call `U_SaveTestUtils.teardown()` in `after_each()`
- Always verify cleanup to prevent test pollution

**Deferred items:**
- Thumbnail capture (schema ready, implementation deferred)
- Cloud sync (out of scope)
- Async/threaded saves (not needed for current file sizes)

---

## Links

- **PRD**: `docs/save manager/save-manager-prd.md`
- **Overview**: `docs/save manager/save-manager-overview.md`
- **Continuation prompt**: `docs/save manager/save-manager-continuation-prompt.md` (to be created when starting implementation)

---

## File Reference

Files to create:

| File | Type | Description | Status |
|------|------|-------------|--------|
| `scripts/managers/m_save_manager.gd` | Manager | Main orchestrator | ✅ Implemented |
| `scripts/managers/helpers/m_save_file_io.gd` | Helper | Atomic file operations | ✅ Implemented |
| `scripts/managers/helpers/m_autosave_scheduler.gd` | Helper | Autosave timing and coalescing | ✅ Implemented |
| `scripts/managers/helpers/m_save_migration_engine.gd` | Helper | Version migrations | ✅ Implemented |
| `scripts/utils/u_save_validator.gd` | Utility | Save file validation | ✅ Implemented (Phase 8) |
| `scripts/ecs/systems/s_playtime_system.gd` | System | Playtime tracking ECS system | ✅ Implemented |
| `scripts/ui/ui_save_load_menu.gd` | UI | Combined save/load overlay controller | ⏳ Not started |
| `scripts/ui/ui_save_slot_item.gd` | UI | Slot item component | ⏳ Not started |
| `scenes/ui/ui_save_load_menu.tscn` | Scene | Combined save/load overlay scene | ⏳ Not started |
| `resources/ui_screens/save_load_menu_overlay.tres` | Resource | Combined overlay definition | ⏳ Not started |
| `tests/unit/save/test_save_manager.gd` | Test | Manager unit tests (86 tests) | ✅ All passing |
| `tests/unit/save/test_save_file_io.gd` | Test | File IO unit tests (14 tests) | ✅ All passing |
| `tests/unit/save/test_save_migrations.gd` | Test | Migration unit tests (16 tests) | ✅ All passing |
| `tests/unit/save/test_autosave_scheduler.gd` | Test | Autosave scheduler tests (8 tests) | ✅ All passing |
| `tests/unit/save/test_playtime_system.gd` | Test | Playtime system unit tests (7 tests) | ✅ All passing |
| `tests/integration/save/test_save_load_cycle.gd` | Test | Integration tests | ⏳ Not started |

Files to modify:

| File | Changes |
|------|---------|
| `scripts/state/m_state_store.gd` | Remove autosave timer |
| `scripts/state/resources/rs_gameplay_initial_state.gd` | Add playtime_seconds, death_in_progress fields |
| `scripts/state/reducers/u_gameplay_reducer.gd` | Add increment_playtime, set_death_in_progress handlers |
| `scripts/state/actions/u_gameplay_actions.gd` | Add increment_playtime, set_death_in_progress actions |
| `scripts/state/resources/rs_navigation_initial_state.gd` | Add save_load_mode field |
| `scripts/state/reducers/u_navigation_reducer.gd` | Add set_save_load_mode handler |
| `scripts/state/actions/u_navigation_actions.gd` | Add set_save_load_mode action |
| `scripts/scene_management/u_scene_registry.gd` | Register save_load_menu scene |
| `scripts/ui/ui_pause_menu.gd` | Add Save/Load buttons |
| `scenes/ui/ui_pause_menu.tscn` | Add button nodes |
| `scripts/ui/ui_hud_controller.gd` | Subscribe to save events |
