# Save Manager Implementation Tasks

**Progress:** 0% (0 / 52 implementation tasks, 0 / 46 manual tests)

---

## Phase 0: Preparation & Existing Code Migration

**Exit Criteria:** M_StateStore timer removed, playtime system working, all Phase 0 tests pass

- [ ] **Task 0.1**: Remove autosave timer from M_StateStore
  - Delete `_autosave_timer` variable
  - Delete `_setup_autosave_timer()` function
  - Delete `_on_autosave_timeout()` function
  - Keep `save_state()`, `load_state()`, and `state_loaded` signal
- [ ] **Task 0.2**: Add `playtime_seconds` field to gameplay slice
  - Add to `RS_GameplayInitialState` with default `0`
  - Ensure field is NOT in transient_fields (persists across transitions)
- [ ] **Task 0.3**: Create playtime tracking action
  - Add `ACTION_INCREMENT_PLAYTIME` constant to `U_GameplayActions`
  - Add `increment_playtime(seconds: int)` action creator
  - Add reducer logic in `U_GameplayReducer`
- [ ] **Task 0.4**: Create S_PlaytimeSystem
  - Create `scripts/ecs/systems/s_playtime_system.gd` extending `BaseECSSystem`
  - Track elapsed time as float internally, dispatch whole seconds only
  - Carry sub-second remainder to prevent precision loss
  - Pause when: `navigation.shell != "gameplay" OR gameplay.paused OR scene.is_transitioning`
  - Register in ECS system runner
- [ ] **Task 0.5**: Add `death_in_progress` flag to gameplay slice
  - Add to `RS_GameplayInitialState` with default `false`
  - Set to `true` on death trigger, `false` on respawn/reset
  - Used by autosave scheduler to block saves during death

---

## Phase 1: Manager Lifecycle and Discovery

**Exit Criteria:** All Phase 1 tests pass, manager discoverable via ServiceLocator

- [ ] **Task 1.1 (Red)**: Write tests for manager initialization, ServiceLocator registration, dependency discovery
- [ ] **Task 1.2 (Green)**: Implement `m_save_manager.gd` with minimal code to pass tests
  - Extend Node, add to "save_manager" group
  - Register with ServiceLocator on `_ready()`
  - Discover M_StateStore and M_SceneManager dependencies
- [ ] **Task 1.3 (Refactor)**: Extract helpers if needed, cleanup

---

## Phase 2: Slot Registry and Metadata

**Exit Criteria:** All Phase 2 tests pass, slot metadata accurately reflects state

- [ ] **Task 2.1 (Red)**: Write tests for slot enumeration, metadata creation, conflict detection
- [ ] **Task 2.2 (Green)**: Implement `m_save_slot_registry.gd` and `u_save_metadata.gd`
  - Slot IDs: `autosave`, `slot_01`, `slot_02`, `slot_03`
  - Metadata: timestamp, playtime, area_name, scene_id, thumbnail_path
  - File path generation: `user://saves/{slot_id}.json`
- [ ] **Task 2.3 (Refactor)**: Clean up slot locking mechanism

---

## Phase 3: File I/O with Atomic Writes and Backups

**Exit Criteria:** All Phase 3 tests pass, no partial writes, corruption recovery verified

- [ ] **Task 3.1 (Red)**: Write tests for atomic writes, backups, corruption recovery
  - Test `.tmp` -> `.json` rename
  - Test `.bak` creation before overwrite
  - Test `.bak` fallback on corruption
- [ ] **Task 3.2 (Green)**: Implement `m_save_file_io.gd` with atomic operations
  - `ensure_save_directory()` -> `DirAccess.make_dir_recursive_absolute("user://saves")`
  - `save_to_file(path, data)` -> write `.tmp`, backup `.bak`, rename to `.json`
  - `load_from_file(path)` -> try `.json`, fallback to `.bak` if `.json` missing
  - Clean up orphaned `.tmp` files on startup
- [ ] **Task 3.3 (Refactor)**: Extract file path utilities if needed

---

## Phase 4: Save Workflow (Manual Saves)

**Exit Criteria:** All Phase 4 tests pass, manual saves write complete state with header

- [ ] **Task 4.1 (Red)**: Write tests for manual save workflow, signal emissions, transient field exclusion, locking
- [ ] **Task 4.2 (Green)**: Implement `M_SaveManager.save_to_slot(slot_id)`
  - Check `_is_saving` lock, reject if already saving
  - Set `_is_saving = true`, emit `save_started` event
  - Get state via `M_StateStore.get_state()` (NOT `save_state()`)
  - Filter transient fields using slice configs before serialization
  - Build header (playtime from state, scene_id from M_SceneManager, timestamp, etc.)
  - Write combined `{header, state}` via `m_save_file_io.gd`
  - Set `_is_saving = false`, emit `save_completed` or `save_failed`
- [ ] **Task 4.3**: Implement transient field filtering
  - Query `M_StateStore` for slice configs
  - Exclude fields marked as transient from each slice
  - Deep copy to avoid mutating live state
- [ ] **Task 4.4 (Refactor)**: Clean up error handling

---

## Phase 5: Load Workflow with M_SceneManager Integration

**Exit Criteria:** All Phase 5 tests pass, load integrates with scene transitions via StateHandoff

- [ ] **Task 5.1 (Red)**: Write tests for load rejection, autosave blocking, scene transitions, locking
  - Test rejection during active transition
  - Test rejection if `_is_loading` already true
  - Test autosave blocking during load
  - Test scene transition to loaded scene_id
  - Test StateHandoff integration
- [ ] **Task 5.2 (Green)**: Implement `M_SaveManager.load_from_slot(slot_id)`
  - Check `_is_loading` lock, reject if already loading
  - Check `M_SceneManager.is_transitioning()` and reject if true
  - Set `_is_loading = true`, block autosaves
  - Read and validate save file
  - Apply migrations if needed (raw Dictionary, before state application)
  - Use `U_STATE_HANDOFF` pattern: store loaded state for scene transition
  - Transition to `current_scene_id` via M_SceneManager
  - StateHandoff applies state after scene loads (existing pattern)
  - Set `_is_loading = false`, re-enable autosaves on completion
- [ ] **Task 5.3 (Refactor)**: Extract load validation logic

---

## Phase 6: Autosave Scheduler and Coalescing

**Exit Criteria:** All Phase 6 tests pass, autosaves triggered correctly, coalescing prevents spam

- [ ] **Task 6.1 (Red)**: Write tests for trigger evaluation, cooldown, priority escalation, coalescing, death blocking
  - Test 5s cooldown enforcement
  - Test HIGH priority override (>2s)
  - Test CRITICAL priority always override
  - Test coalescing multiple requests
  - Test autosave blocked when `death_in_progress == true`
- [ ] **Task 6.2 (Green)**: Implement `m_autosave_scheduler.gd`
  - Subscribe to ECS events: `checkpoint_activated`, `area_complete`
  - Subscribe to Redux actions: `scene/transition_completed`
  - (Settings autosave removed - only checkpoint/area events trigger saves)
  - Check `gameplay.death_in_progress == false` before allowing save
  - Dirty flag + priority tracking
  - Write on next stable frame: `await get_tree().process_frame` after cooldown
  - Define stable: `!scene.is_transitioning AND !_is_loading`
- [ ] **Task 6.3 (Refactor)**: Extract trigger evaluation helpers

---

## Phase 7: Migration System

**Exit Criteria:** All Phase 7 tests pass, migrations are pure and composable, v0 saves imported

- [ ] **Task 7.1 (Red)**: Write tests for version detection, migration chains, failure handling, v0 import
  - Test v0 (headerless) -> v1 migration
  - Test v1 -> v2 migration
  - Test v1 -> v3 chained migration
  - Test invalid version handling
  - Test old `user://savegame.json` detection and import
- [ ] **Task 7.2 (Green)**: Implement `m_save_migration_engine.gd`
  - Version detection from header (missing header = v0)
  - Migration registry: `{ version: Callable }`
  - Pure `Dictionary -> Dictionary` transforms
  - Chain migrations for multi-version jumps
- [ ] **Task 7.3**: Implement v0 -> v1 migration (legacy save import)
  - Detect headerless saves (old format is raw state, no `header` key)
  - Wrap in `{header: {...}, state: {...}}` structure
  - Generate header with defaults: `save_version=1`, `timestamp=now`, `playtime_seconds=0`
  - Extract `current_scene_id` from state if present
- [ ] **Task 7.4**: Implement legacy save import on first launch
  - Check for `user://savegame.json` on manager init
  - If exists: migrate to v1 format, save as `user://saves/autosave.json`
  - Delete original `user://savegame.json` after successful migration
  - Log migration result
- [ ] **Task 7.5 (Refactor)**: Clean up migration registry

---

## Phase 8: Error Handling and Corruption Recovery

**Exit Criteria:** All Phase 8 tests pass, corruption recovery functional, errors actionable

- [ ] **Task 8.1 (Red)**: Write tests for .bak fallback, validation errors, disk failures
- [ ] **Task 8.2 (Green)**: Implement `u_save_validator.gd` and enhance error signals
  - Validate header required fields
  - Validate state structure
  - Return actionable error codes
- [ ] **Task 8.3 (Refactor)**: Consolidate error message formatting

---

## Phase 9: UI - Pause Menu Integration

**Exit Criteria:** Save/Load buttons appear in pause menu, open combined overlay with correct mode

- [ ] **Task 9.1**: Add `save_load_mode` to navigation slice
  - Add field to `RS_NavigationInitialState`: `save_load_mode: StringName = ""`
  - Add action `U_NavigationActions.set_save_load_mode(mode: StringName)`
  - Add reducer handler in `U_NavigationReducer`
- [ ] **Task 9.2**: Add Save and Load buttons to `ui_pause_menu.gd`
  - Insert between Settings and Quit buttons
  - `_on_save_pressed()` -> dispatch `set_save_load_mode("save")` then `open_overlay`
  - `_on_load_pressed()` -> dispatch `set_save_load_mode("load")` then `open_overlay`
- [ ] **Task 9.3**: Create overlay definition in `resources/ui_screens/`
  - `save_load_menu_overlay.tres` (RS_UIScreenDefinition)
  - `allowed_shells`: ["gameplay"]
  - `allowed_parents`: ["pause_menu"]
- [ ] **Task 9.4**: Register scene in `U_SceneRegistry`
  - Scene ID: `save_load_menu`
  - Scene Type: `SceneType.UI`
  - Path: `res://scenes/ui/ui_save_load_menu.tscn`
- [ ] **Task 9.5**: Update pause menu scene (`ui_pause_menu.tscn`)
  - Add SaveButton and LoadButton nodes
  - Configure focus neighbors

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

| File | Type | Description |
|------|------|-------------|
| `scripts/managers/m_save_manager.gd` | Manager | Main orchestrator |
| `scripts/managers/helpers/m_save_slot_registry.gd` | Helper | Slot enumeration and metadata |
| `scripts/managers/helpers/m_save_file_io.gd` | Helper | Atomic file operations |
| `scripts/managers/helpers/m_autosave_scheduler.gd` | Helper | Autosave timing and coalescing |
| `scripts/managers/helpers/m_save_migration_engine.gd` | Helper | Version migrations |
| `scripts/utils/u_save_validator.gd` | Utility | Save file validation |
| `scripts/utils/u_save_metadata.gd` | Utility | Header metadata construction |
| `scripts/ecs/systems/s_playtime_system.gd` | System | Playtime tracking ECS system |
| `scripts/ui/ui_save_load_menu.gd` | UI | Combined save/load overlay controller |
| `scripts/ui/ui_save_slot_item.gd` | UI | Slot item component |
| `scenes/ui/ui_save_load_menu.tscn` | Scene | Combined save/load overlay scene |
| `resources/ui_screens/save_load_menu_overlay.tres` | Resource | Combined overlay definition |
| `resources/rs_save_manager_settings.gd` | Resource | Manager configuration |
| `tests/unit/save/test_save_manager.gd` | Test | Manager unit tests |
| `tests/unit/save/test_save_migrations.gd` | Test | Migration unit tests |
| `tests/unit/save/test_playtime_system.gd` | Test | Playtime system unit tests |
| `tests/integration/save/test_save_load_cycle.gd` | Test | Integration tests |
| `tests/mocks/mock_save_file_io.gd` | Mock | File IO mock for unit tests |

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
