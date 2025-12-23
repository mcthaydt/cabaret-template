# Save Manager Implementation Plan

**Feature**: Multi-Slot Save System
**Status**: Phase 0 - Planning
**Last Updated**: 2025-12-22

---

## Architecture Overview

### File Structure

**New Files** (9 total):

```
scripts/state/utils/u_save_envelope.gd          # Data structures (SaveMetadata, SaveEnvelope)
scripts/state/utils/u_save_manager.gd           # Slot coordination (save/load/metadata)
scripts/state/actions/u_save_actions.gd         # Redux actions
scripts/state/reducers/u_save_reducer.gd        # Redux reducer
scripts/state/resources/rs_save_initial_state.gd # Initial state
scripts/state/selectors/u_save_selectors.gd     # State selectors
scripts/ui/ui_save_slot_selector.gd             # UI controller
scenes/ui/ui_save_slot_selector.tscn            # UI scene
resources/ui_screens/save_slot_selector_overlay.tres # UI definition
```

**Modified Files** (8 total):

```
scripts/state/m_state_store.gd                  # Register save slice, modify autosave
scripts/ui/u_ui_registry.gd                     # Register overlay
scripts/ui/ui_pause_menu.gd                     # Add Save button
scenes/ui/ui_pause_menu.tscn                    # Save button node
scripts/ui/ui_main_menu.gd                      # Add Continue/Load buttons
scenes/ui/ui_main_menu.tscn                     # Button nodes
scripts/state/actions/u_navigation_actions.gd   # Navigation action
scripts/scene_management/u_scene_registry.gd    # Register scene
```

---

## Data Model

### Save File Paths

```
user://save_slot_0.json  # Autosave (protected, read-only delete)
user://save_slot_1.json  # Manual Slot 1
user://save_slot_2.json  # Manual Slot 2
user://save_slot_3.json  # Manual Slot 3
user://savegame.json     # Legacy (migrated to slot 1)
```

### SaveMetadata Structure

```gdscript
class SaveMetadata:
    var slot_index: int
    var timestamp: int              # Unix timestamp
    var scene_name: StringName
    var scene_display_name: String
    var completion_percent: float
    var player_health: float
    var player_max_health: float
    var death_count: int
    var playtime_seconds: float
    var save_version: int
    var is_autosave: bool
```

### Save Envelope Format (JSON)

```json
{
  "metadata": {
    "slot_index": 1,
    "timestamp": 1734912345,
    "scene_name": "gameplay_exterior",
    "scene_display_name": "Exterior",
    "completion_percent": 40.0,
    "player_health": 75.0,
    "player_max_health": 100.0,
    "death_count": 3,
    "playtime_seconds": 450.0,
    "save_version": 1,
    "is_autosave": false
  },
  "state": {
    "gameplay": { ... },
    "scene": { ... },
    "settings": { ... }
  }
}
```

---

## Implementation Phases

### Phase 1: Data Layer Foundation (TDD)
**Goal**: Core data structures and save/load logic

**TDD Approach**: Write tests first, then implement to make them pass

1. **Create test file first**: `tests/unit/state/test_save_manager.gd`
   - Test SaveMetadata serialization/deserialization
   - Test SaveEnvelope format validation
   - Test slot path resolution
   - Test save_to_slot() creates correct file
   - Test load_from_slot() restores state
   - Test get_slot_metadata() returns correct info
   - Test delete_slot() removes file
   - Test autosave slot cannot be deleted
   - Test migrate_legacy_save() moves old file

2. **Run tests** (should fail - no implementation yet)

3. **Create `u_save_envelope.gd`** to make tests pass
   - Constants (slot count, paths)
   - SaveMetadata class with to/from dictionary
   - SaveEnvelope wrapper
   - Utility methods (get_slot_path, slot_exists, etc.)

4. **Create `u_save_manager.gd`** to make tests pass
   - Static methods for slot operations
   - `save_to_slot(slot_index, state, slice_configs, is_autosave)`
   - `load_from_slot(slot_index, state, slice_configs)`
   - `get_all_slot_metadata()` - for UI display
   - `get_slot_metadata(slot_index)` - individual slot
   - `delete_slot(slot_index)` - with autosave protection
   - `migrate_legacy_save()` - savegame.json → slot 1

5. **Run tests again** (should pass)

**Completion Criteria**: All Phase 1 tests green ✅

---

### Phase 2: Redux Integration (TDD)
**Goal**: State management for save operations

**TDD Approach**: Write reducer tests first

1. **Create test file**: `tests/unit/state/test_save_reducer.gd`
   - Test initial state
   - Test each action type updates state correctly
   - Test immutability (original state unchanged)

2. **Run tests** (should fail)

3. **Implement to make tests pass**

4. Create `u_save_actions.gd`
   - Actions: save_to_slot, load_from_slot, delete_slot
   - Actions: refresh_slot_metadata, set_last_save_slot
   - Actions: save_started, save_completed, save_failed
   - Actions: load_started, load_completed, load_failed

5. Create `rs_save_initial_state.gd`
   - Fields: last_save_slot, slot_metadata[], is_saving, is_loading, active_slot, last_error

6. Create `u_save_reducer.gd`
   - Handle all save actions
   - Update operation state (is_saving, is_loading)
   - Cache slot metadata

7. Create `u_save_selectors.gd`
   - get_last_save_slot()
   - get_slot_metadata()
   - is_saving(), is_loading()
   - get_most_recent_slot()

8. **Register save slice** - Modify multiple files:

   **In `m_state_store.gd` (top of file)**:
   ```gdscript
   const U_SAVE_REDUCER := preload("res://scripts/state/reducers/u_save_reducer.gd")
   const RS_SAVE_INITIAL_STATE := preload("res://scripts/state/resources/rs_save_initial_state.gd")
   ```

   **Add export variable (after other initial states)**:
   ```gdscript
   @export var save_initial_state: RS_SaveInitialState
   ```

   **In `u_state_slice_manager.gd` `initialize_slices()` method**:
   Add parameter: `save_initial_state: RS_SaveInitialState`

   Add slice registration code:
   ```gdscript
   # Save slice (for slot management and operation state)
   if save_initial_state != null:
       var save_config := RS_StateSliceConfig.new(StringName("save"))
       save_config.reducer = Callable(U_SaveReducer, "reduce")
       save_config.initial_state = save_initial_state.to_dictionary()
       save_config.dependencies = []
       save_config.transient_fields = ["is_saving", "is_loading", "active_slot", "last_error"]
       register_slice(slice_configs, state, save_config)
   ```

   **In `m_state_store._initialize_slices()`**:
   Pass `save_initial_state` to `U_STATE_SLICE_MANAGER.initialize_slices(...)`

**Completion Criteria**: Save state tracked in Redux store

---

### Phase 3: Autosave Modification
**Goal**: Redirect autosave to dedicated slot

9. **Modify `m_state_store._on_autosave_timeout()`** - Replace implementation:

   **Current code** (line ~134):
   ```gdscript
   func _on_autosave_timeout() -> void:
       _save_state_if_enabled()
   ```

   **New code**:
   ```gdscript
   func _on_autosave_timeout() -> void:
       _autosave_to_dedicated_slot()

   func _autosave_to_dedicated_slot() -> void:
       # Only autosave during active gameplay
       var nav_state := get_slice(StringName("navigation"))
       var shell: StringName = nav_state.get("shell", StringName(""))
       if shell != StringName("gameplay"):
           return  # Skip autosave in menus/boot

       # Don't save during scene transitions
       var scene_state := get_slice(StringName("scene"))
       if scene_state.get("is_transitioning", false):
           return  # Skip autosave while loading

       # Save to autosave slot (slot 0)
       const U_SAVE_MANAGER = preload("res://scripts/state/utils/u_save_manager.gd")
       const U_SAVE_ENVELOPE = preload("res://scripts/state/utils/u_save_envelope.gd")

       var err := U_SAVE_MANAGER.save_to_slot(
           U_SAVE_ENVELOPE.AUTOSAVE_SLOT,  # 0
           _state,
           _slice_configs,
           true  # is_autosave = true
       )

       if err != OK and settings != null and settings.enable_debug_logging:
           push_warning("M_StateStore: Autosave failed: ", error_string(err))
   ```

10. **Add preload constants** (if not already present):
   At top of `m_state_store.gd`:
   ```gdscript
   const U_SAVE_MANAGER := preload("res://scripts/state/utils/u_save_manager.gd")
   const U_SAVE_ENVELOPE := preload("res://scripts/state/utils/u_save_envelope.gd")
   ```

**Completion Criteria**: Autosave writes to slot 0 automatically

---

### Phase 4: Migration
**Goal**: Migrate legacy saves

11. Add migration logic to `m_state_store._ready()`
    - Call `U_SaveManager.migrate_legacy_save()`
    - Log migration result if debug enabled

12. Test migration
    - Create test `savegame.json`
    - Verify migrates to slot 1
    - Verify legacy renamed to `.backup`
    - Verify slot 1 loads correctly

**Completion Criteria**: Old saves auto-migrate on first launch

---

### Phase 5: UI Layer
**Goal**: Save/Load overlay interface

13. Create `ui_save_slot_selector.tscn`
    - Extends BaseOverlay
    - Title label (changes based on mode)
    - 4 slot buttons (VBoxContainer)
    - Back button

14. Create `ui_save_slot_selector.gd`
    - enum Mode { SAVE, LOAD }
    - _refresh_slots() - dispatch refresh_metadata, update UI
    - _update_slot_display() - format slot text with metadata
    - _on_slot_pressed(slot_index) - trigger save or load
    - _perform_save() / _perform_load()
    - Focus configuration for gamepad

15. Create `save_slot_selector_overlay.tres`
    - RS_UIScreenDefinition resource
    - screen_id: "save_slot_selector"
    - kind: OVERLAY
    - scene_id: "save_slot_selector"
    - allowed_shells: [gameplay, main_menu]

16. Register in `u_ui_registry.gd`
    - Add overlay definition to registry

17. Register in `u_scene_registry.gd`
    - Add save_slot_selector scene

**Completion Criteria**: Overlay opens and displays slots

---

### Phase 6: Menu Integration
**Goal**: Wire up pause and main menu

18. Add Save button to pause menu
    - Edit `scenes/ui/ui_pause_menu.tscn`: add SaveButton
    - Edit `scripts/ui/ui_pause_menu.gd`: add _on_save_pressed()
    - Handler dispatches open_overlay("save_slot_selector")

19. Add Continue/Load to main menu
    - Edit `scenes/ui/ui_main_menu.tscn`: add ContinueButton, LoadButton
    - Edit `scripts/ui/ui_main_menu.gd`:
      - _update_button_visibility() - show Continue only if saves exist
      - _on_continue_pressed() - find most recent slot, load directly
      - _on_load_pressed() - open save_slot_selector

20. Add navigation actions
    - Edit `u_navigation_actions.gd`: add open_save_selector(mode)

**Completion Criteria**: Can open save/load UI from menus

---

### Phase 7: Load Flow
**Goal**: Loading triggers scene transition

21. Implement load triggering transition
    - In `_perform_load()`: dispatch load_started
    - M_StateStore subscribes to load_started
    - On load_started: call U_SaveManager.load_from_slot()
    - Dispatch load_completed with immediate: true
    - M_SceneManager reacts to state change, transitions to loaded scene

22. Handle navigation after load
    - Close overlay after dispatching load
    - Scene transition handles rest

**Completion Criteria**: Loading a save transitions to that scene

---

### Phase 8: Polish
**Goal**: Error handling, confirmations, UX

23. Add confirmation dialogs
    - Overwrite confirmation when saving to populated slot
    - Delete confirmation for manual slots

24. Error handling
    - Corrupted save detection
    - Disk full errors
    - Display error messages to user

25. Focus management
    - Auto-focus first slot on open
    - Gamepad navigation support
    - Back button handling

**Completion Criteria**: Production-ready UX

---

## Key Integration Points

### With Existing Systems

- **M_StateStore**: Subscribes to save/load actions, coordinates with U_SaveManager
- **U_StatePersistence**: Used internally by U_SaveManager for I/O
- **M_SceneManager**: Handles scene transition after load
- **U_UIRegistry**: Registers save slot overlay
- **Navigation Slice**: Tracks UI state, shell context

### Critical Files

- `scripts/state/m_state_store.gd:710-780` - Autosave timer, persistence methods
- `scripts/state/utils/u_state_repository.gd` - Reference for persistence patterns
- `scripts/state/utils/u_state_persistence.gd` - Low-level file I/O
- `scripts/ui/ui_pause_menu.gd` - Pause menu controller
- `scripts/ui/ui_main_menu.gd` - Main menu controller

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Data loss during migration | Rename legacy save to `.backup`, don't delete |
| Corrupted saves | Validate on load, mark slot as corrupted, allow delete |
| Save during transition | Block saves when is_transitioning = true |
| Autosave performance | Already exists, just redirect to slot 0 |
| UI complexity | Reuse existing overlay patterns from pause/settings |

---

## Testing Strategy

### Unit Tests
- SaveMetadata serialization/deserialization
- SaveEnvelope format validation
- Slot path resolution

### Integration Tests
- Save → Load roundtrip
- Autosave triggers correctly
- Legacy migration

### Manual Tests
- All user stories from PRD
- Edge cases (corrupted files, disk full)
- Gamepad navigation
