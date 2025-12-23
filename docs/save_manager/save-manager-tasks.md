# Save Manager Task Checklist

**Status**: Phase 1 - Data Layer Foundation COMPLETE ✅
**Last Updated**: 2025-12-23

---

## Phase 1: Data Layer Foundation (TDD) ✅ COMPLETE

**Completion Date**: 2025-12-23
**Commit**: cff8a3b

**RED**: Write failing tests first

- [x] Create `tests/unit/state/test_save_manager.gd`
  - [x] Test SaveMetadata.to_dictionary() / from_dictionary()
  - [x] Test U_SaveManager.get_slot_path() returns correct paths
  - [x] Test U_SaveManager.slot_exists() detects files
  - [x] Test U_SaveManager.save_to_slot() creates file
  - [x] Test U_SaveManager.load_from_slot() restores state
  - [x] Test U_SaveManager.get_slot_metadata() returns correct data
  - [x] Test U_SaveManager.get_all_slots() returns array
  - [x] Test U_SaveManager.delete_slot() removes file
  - [x] Test U_SaveManager.get_most_recent_slot() finds newest
  - [x] Test U_SaveManager.has_any_save() detection

- [x] Run tests → ALL FAIL (no implementation yet) ❌

**GREEN**: Implement to make tests pass

- [x] Create `rs_save_slot_metadata.gd` (Resource-based metadata)
  - [x] Define SlotType enum (MANUAL, AUTO)
  - [x] Implement to_dictionary()
  - [x] Implement from_dictionary()
  - [x] Implement get_display_summary()
  - [x] **Fixed**: Changed timestamp from int to float for sub-second precision

- [x] Create `u_save_envelope.gd` with data structures
  - [x] Define constants (paths, SAVE_VERSION)
  - [x] Implement write_envelope()
  - [x] Implement try_read_envelope()
  - [x] Implement try_read_metadata()
  - [x] Implement try_import_legacy_as_auto_slot()

- [x] Create `u_save_manager.gd` with save/load logic
  - [x] Implement save_to_slot()
  - [x] Implement save_to_auto_slot()
  - [x] Implement load_from_slot()
  - [x] Implement load_from_auto_slot()
  - [x] Implement get_slot_metadata()
  - [x] Implement get_all_slots()
  - [x] Implement get_most_recent_slot()
  - [x] Implement has_any_save()
  - [x] Implement delete_slot() (autosave delete NOT implemented - returns error for slot 0)
  - [x] Implement try_migrate_legacy_save()
  - [x] Implement _build_metadata_from_state()

- [x] Create `rs_save_manager_settings.gd` (configurable paths/settings)

- [x] Run tests → ALL PASS ✅ (27/27 tests passing)

**REFACTOR**: Clean up code

- [x] Review for code smells - None found
- [x] Add docstrings - Complete
- [x] **Fixed**: Test error suppression using assert_push_error()

**Key Implementation Notes**:
- Used Resource-based approach for metadata (RS_SaveSlotMetadata) instead of plain class
- Autosave protection: Manual delete_slot() rejects slot 0 with ERR_INVALID_PARAMETER
- Slot ordering: get_all_slots() returns [1, 2, 3, 0] for UI display
- Legacy migration: Copies savegame.json → slot 0, renames to .backup
- Timestamp bug fixed: Changed from int to float to preserve sub-second precision

---

## Phase 2: Redux Integration (TDD)

**RED**: Write failing tests

- [ ] Create `tests/unit/state/test_save_reducer.gd`
  - [ ] Test initial state structure
  - [ ] Test SET_LAST_SAVE_SLOT updates last_save_slot
  - [ ] Test REFRESH_SLOT_METADATA populates slot_metadata array
  - [ ] Test SAVE_STARTED sets is_saving = true
  - [ ] Test SAVE_COMPLETED sets is_saving = false, updates last_save_slot
  - [ ] Test SAVE_FAILED sets is_saving = false, sets error
  - [ ] Test LOAD_STARTED sets is_loading = true
  - [ ] Test LOAD_COMPLETED sets is_loading = false
  - [ ] Test LOAD_FAILED sets is_loading = false, sets error
  - [ ] Test state immutability (original state unchanged)

- [ ] Run tests → ALL FAIL ❌

**GREEN**: Implement to make tests pass

- [ ] Create `u_save_actions.gd`
  - [ ] Define action constants
  - [ ] Implement save_to_slot()
  - [ ] Implement load_from_slot()
  - [ ] Implement delete_slot()
  - [ ] Implement refresh_slot_metadata()
  - [ ] Implement operation state actions (started/completed/failed)
  - [ ] Register all actions in U_ActionRegistry

- [ ] Create `rs_save_initial_state.gd`
  - [ ] Define @export fields
  - [ ] Implement to_dictionary()

- [ ] Create `u_save_reducer.gd`
  - [ ] Handle SET_LAST_SAVE_SLOT
  - [ ] Handle REFRESH_SLOT_METADATA
  - [ ] Handle SAVE_STARTED/COMPLETED/FAILED
  - [ ] Handle LOAD_STARTED/COMPLETED/FAILED

- [ ] Create `u_save_selectors.gd`
  - [ ] Implement get_last_save_slot()
  - [ ] Implement get_slot_metadata()
  - [ ] Implement is_saving() / is_loading()
  - [ ] Implement get_most_recent_slot()

- [ ] Register save slice in `m_state_store.gd`
  - [ ] Add to _slice_configs dictionary
  - [ ] Add to _reducers dictionary
  - [ ] Import required files

---

## Phase 3: Autosave Modification

- [ ] Modify `m_state_store.gd` autosave
  - [ ] Update _on_autosave_timeout() to use U_SaveManager
  - [ ] Add shell check (only in "gameplay")
  - [ ] Add transition check (skip if is_transitioning)
  - [ ] Test autosave triggers to slot 0

---

## Phase 4: Migration

- [ ] Add migration to `m_state_store._ready()`
  - [ ] Call U_SaveManager.migrate_legacy_save()
  - [ ] Log migration result

- [ ] Test migration
  - [ ] Create test savegame.json
  - [ ] Verify migrates to slot 1
  - [ ] Verify legacy renamed to .backup
  - [ ] Verify slot 1 data valid

---

## Phase 5: UI Layer

- [ ] Create `ui_save_slot_selector.tscn`
  - [ ] Add TitleLabel
  - [ ] Add SlotContainer (VBoxContainer)
  - [ ] Add AutosaveSlot button
  - [ ] Add Slot1/2/3 buttons
  - [ ] Add BackButton
  - [ ] Configure unique names (%)

- [ ] Create `ui_save_slot_selector.gd`
  - [ ] Extend BaseOverlay
  - [ ] Define Mode enum (SAVE, LOAD)
  - [ ] Implement _ready()
  - [ ] Implement set_mode()
  - [ ] Implement _refresh_slots()
  - [ ] Implement _update_slot_display()
  - [ ] Implement _on_slot_pressed()
  - [ ] Implement _perform_save()
  - [ ] Implement _perform_load()
  - [ ] Configure focus chain

- [ ] Create `save_slot_selector_overlay.tres`
  - [ ] Set screen_id
  - [ ] Set kind = OVERLAY
  - [ ] Set scene_id
  - [ ] Set allowed_shells

- [ ] Register overlay
  - [ ] Add to u_ui_registry.gd
  - [ ] Add scene to u_scene_registry.gd

---

## Phase 6: Menu Integration

- [ ] Modify pause menu
  - [ ] Add SaveButton to ui_pause_menu.tscn
  - [ ] Add _on_save_pressed() handler in ui_pause_menu.gd
  - [ ] Connect button signal
  - [ ] Update focus chain

- [ ] Modify main menu
  - [ ] Add ContinueButton to ui_main_menu.tscn
  - [ ] Add LoadButton to ui_main_menu.tscn
  - [ ] Implement _update_button_visibility()
  - [ ] Implement _on_continue_pressed()
  - [ ] Implement _on_load_pressed()
  - [ ] Update focus chain
  - [ ] Call visibility update in _ready()

- [ ] Add navigation actions
  - [ ] Add open_save_selector() to u_navigation_actions.gd
  - [ ] Handle in navigation reducer

---

## Phase 7: Load Flow

- [ ] Implement load triggering
  - [ ] Subscribe to load_started in m_state_store.gd
  - [ ] Call U_SaveManager.load_from_slot()
  - [ ] Dispatch load_completed with immediate: true
  - [ ] Close overlay after dispatching load

- [ ] Test load flow
  - [ ] Verify scene transition after load
  - [ ] Verify correct spawn point
  - [ ] Verify state restored (health, checkpoints, etc.)

---

## Phase 8: Polish

- [ ] Add confirmation dialogs
  - [ ] Overwrite confirmation when saving to populated slot
  - [ ] Delete confirmation for manual slots
  - [ ] Autosave delete blocked message

- [ ] Error handling
  - [ ] Detect corrupted saves on load
  - [ ] Handle disk full errors
  - [ ] Display error messages to user
  - [ ] Mark corrupted slots in UI

- [ ] Focus management
  - [ ] Auto-focus first available slot
  - [ ] Gamepad/keyboard navigation
  - [ ] Back button handling
  - [ ] Tab/shoulder button support

- [ ] Visual feedback
  - [ ] Save completion toast
  - [ ] Loading indicator
  - [ ] Autosave icon/indicator

---

## Testing & Validation

- [ ] Manual testing
  - [ ] Test all user stories from PRD
  - [ ] Test edge cases (corrupted file, disk full)
  - [ ] Test with gamepad
  - [ ] Test with keyboard
  - [ ] Test on mobile (touch)

- [ ] Code review
  - [ ] Verify prefix conventions (u_, rs_, ui_)
  - [ ] Check for proper error handling
  - [ ] Validate Redux patterns
  - [ ] Review focus management

- [ ] Documentation
  - [ ] Update AGENTS.md if new patterns added
  - [ ] Update DEV_PITFALLS.md if issues discovered
  - [ ] Update continuation prompt

---

## Commit Strategy

- [ ] Phase 1 complete → Commit "Add save envelope data structures and manager"
- [ ] Phase 2 complete → Commit "Add Redux integration for save system"
- [ ] Phase 3-4 complete → Commit "Redirect autosave to slot 0 and add migration"
- [ ] Phase 5 complete → Commit "Add save slot selector UI"
- [ ] Phase 6 complete → Commit "Wire save/load to pause and main menus"
- [ ] Phase 7-8 complete → Commit "Complete save manager with load flow and polish"

---

---

## TDD Guidelines

**For every phase**:
1. Write tests FIRST (they should fail)
2. Run tests to confirm failure
3. Write minimal implementation to pass tests
4. Run tests to confirm success
5. Refactor while keeping tests green

**Test locations**:
- `tests/unit/state/test_save_manager.gd` - Phase 1 tests
- `tests/unit/state/test_save_reducer.gd` - Phase 2 tests
- `tests/unit/state/test_save_integration.gd` - Phase 7 tests

See `save-manager-test-plan.md` for complete test specifications.

---

**Notes**:
- Mark tasks with [x] as completed
- Add completion timestamps and notes where helpful
- Update this file after each phase
- Always run tests before marking phase complete
