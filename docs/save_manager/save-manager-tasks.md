# Save Manager Task Checklist

**Status**: Phase 2 - Redux Integration COMPLETE ✅
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

## Phase 2: Redux Integration (TDD) ✅ COMPLETE

**Completion Date**: 2025-12-23
**Commits**: Implementation (pending), Documentation (pending)

**RED**: Write failing tests

- [x] Create `tests/unit/state/test_save_reducer.gd`
  - [x] Test initial state structure
  - [x] Test SAVE_STARTED/COMPLETED/FAILED state transitions
  - [x] Test LOAD_STARTED/COMPLETED/FAILED state transitions
  - [x] Test DELETE_STARTED/COMPLETED/FAILED state transitions
  - [x] Test SET_SAVE_MODE updates current_mode
  - [x] Test state immutability (original state unchanged)
  - [x] Test unhandled actions return same state

- [x] Run tests → ALL FAIL (3/13 passed initially) ❌

**GREEN**: Implement to make tests pass

- [x] Create `u_save_actions.gd`
  - [x] Define action constants (save/load/delete started/completed/failed)
  - [x] Implement save_started/completed/failed()
  - [x] Implement load_started/completed/failed()
  - [x] Implement delete_started/completed/failed()
  - [x] Implement set_save_mode()
  - [x] Register all actions in U_ActionRegistry

- [x] Create `rs_save_initial_state.gd`
  - [x] Define @export fields (is_saving, is_loading, is_deleting, last_save_slot, current_mode, last_error)
  - [x] Implement to_dictionary()

- [x] Create `u_save_reducer.gd`
  - [x] Handle SAVE_STARTED/COMPLETED/FAILED
  - [x] Handle LOAD_STARTED/COMPLETED/FAILED
  - [x] Handle DELETE_STARTED/COMPLETED/FAILED
  - [x] Handle SET_SAVE_MODE
  - [x] Return unchanged state for unhandled actions

- [x] Create `u_save_selectors.gd`
  - [x] Implement is_saving() / is_loading() / is_deleting()
  - [x] Implement get_last_save_slot()
  - [x] Implement get_current_mode()
  - [x] Implement get_last_error()
  - [x] Implement is_busy() (any operation in progress)

- [x] Register save slice in `m_state_store.gd`
  - [x] Add const for U_SAVE_REDUCER and RS_SAVE_INITIAL_STATE
  - [x] Add @export save_initial_state field
  - [x] Pass to initialize_slices()
  - [x] Register in u_state_slice_manager.gd with transient fields

- [x] Run tests → ALL PASS (40/40 tests: 27 manager + 13 reducer) ✅

**REFACTOR**: Clean up code

- [x] Review for code smells - None found
- [x] Patterns match existing Redux slices - Consistent

**Key Implementation Notes**:
- Transient fields: is_saving, is_loading, is_deleting, last_error (not persisted)
- Persisted fields: last_save_slot, current_mode
- Action structure uses flat parameters (not nested payload objects)
- Selectors provide type-safe access to save state

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
