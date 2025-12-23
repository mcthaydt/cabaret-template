# Save Manager Test Plan

**Approach**: Test-Driven Development (TDD)
**Framework**: GUT (Godot Unit Testing)
**Last Updated**: 2025-12-22

---

## TDD Workflow

For each phase:
1. **RED**: Write failing tests first
2. **GREEN**: Implement minimal code to make tests pass
3. **REFACTOR**: Clean up while keeping tests green

---

## Test Files Structure

```
tests/unit/state/
├── test_save_manager.gd       # Phase 1: SaveEnvelope & SaveManager tests
├── test_save_reducer.gd       # Phase 2: Redux reducer tests
└── test_save_integration.gd   # Phase 7: End-to-end integration tests
```

---

## Phase 1: Data Layer Tests

### File: `test_save_manager.gd`

```gdscript
extends GutTest

const U_SAVE_ENVELOPE = preload("res://scripts/state/utils/u_save_envelope.gd")
const U_SAVE_MANAGER = preload("res://scripts/state/utils/u_save_manager.gd")

# Test SaveMetadata serialization
func test_save_metadata_to_dictionary():
    var meta := U_SAVE_ENVELOPE.SaveMetadata.new()
    meta.slot_index = 1
    meta.timestamp = 12345
    meta.scene_name = StringName("gameplay_exterior")

    var dict := meta.to_dictionary()

    assert_eq(dict["slot_index"], 1)
    assert_eq(dict["timestamp"], 12345)
    assert_eq(dict["scene_name"], "gameplay_exterior")

func test_save_metadata_from_dictionary():
    var dict := {
        "slot_index": 2,
        "timestamp": 67890,
        "scene_name": "gameplay_interior"
    }

    var meta := U_SAVE_ENVELOPE.SaveMetadata.from_dictionary(dict)

    assert_eq(meta.slot_index, 2)
    assert_eq(meta.timestamp, 67890)
    assert_eq(meta.scene_name, StringName("gameplay_interior"))

# Test slot path resolution
func test_get_slot_path():
    var path := U_SAVE_ENVELOPE.get_slot_path(1)
    assert_eq(path, "user://save_slot_1.json")

func test_slot_exists_when_no_file():
    var exists := U_SAVE_ENVELOPE.slot_exists(99)
    assert_false(exists)

# Test save operation
func test_save_to_slot_creates_file():
    var state := {"gameplay": {"player_health": 100.0}}
    var slice_configs := {}

    var err := U_SAVE_MANAGER.save_to_slot(1, state, slice_configs, false)

    assert_eq(err, OK)
    assert_true(U_SAVE_ENVELOPE.slot_exists(1))

    # Cleanup
    DirAccess.remove_absolute(U_SAVE_ENVELOPE.get_slot_path(1))

# Test load operation
func test_load_from_slot_restores_state():
    # Setup: create a save
    var original_state := {"gameplay": {"player_health": 75.0}}
    U_SAVE_MANAGER.save_to_slot(2, original_state, {}, false)

    # Load into empty state
    var loaded_state := {}
    var err := U_SAVE_MANAGER.load_from_slot(2, loaded_state, {})

    assert_eq(err, OK)
    assert_eq(loaded_state["gameplay"]["player_health"], 75.0)

    # Cleanup
    DirAccess.remove_absolute(U_SAVE_ENVELOPE.get_slot_path(2))

# Test metadata extraction
func test_get_slot_metadata_for_empty_slot():
    var meta := U_SAVE_MANAGER.get_slot_metadata(3)
    assert_true(meta.get("is_empty", false))

func test_get_slot_metadata_for_populated_slot():
    # Setup
    var state := {"gameplay": {"player_health": 50.0}}
    U_SAVE_MANAGER.save_to_slot(1, state, {}, false)

    var meta := U_SAVE_MANAGER.get_slot_metadata(1)

    assert_false(meta.get("is_empty", true))
    assert_true(meta.has("timestamp"))
    assert_true(meta.has("player_health"))

    # Cleanup
    DirAccess.remove_absolute(U_SAVE_ENVELOPE.get_slot_path(1))

# Test delete operation
func test_delete_slot_removes_file():
    # Setup
    U_SAVE_MANAGER.save_to_slot(2, {}, {}, false)
    assert_true(U_SAVE_ENVELOPE.slot_exists(2))

    # Delete
    var err := U_SAVE_MANAGER.delete_slot(2)

    assert_eq(err, OK)
    assert_false(U_SAVE_ENVELOPE.slot_exists(2))

# Test autosave protection
func test_delete_autosave_slot_fails():
    var err := U_SAVE_MANAGER.delete_slot(0)
    assert_ne(err, OK, "Should not allow deleting autosave slot")

# Test legacy migration
func test_migrate_legacy_save():
    # Setup: create fake legacy save
    var legacy_path := U_SAVE_ENVELOPE.LEGACY_SAVE_PATH
    var file := FileAccess.open(legacy_path, FileAccess.WRITE)
    file.store_string('{"gameplay": {"player_health": 100.0}}')
    file.close()

    # Migrate
    var migrated := U_SAVE_MANAGER.migrate_legacy_save()

    assert_true(migrated)
    assert_true(U_SAVE_ENVELOPE.slot_exists(1))
    assert_false(FileAccess.file_exists(legacy_path))
    assert_true(FileAccess.file_exists(legacy_path + ".backup"))

    # Cleanup
    DirAccess.remove_absolute(U_SAVE_ENVELOPE.get_slot_path(1))
    DirAccess.remove_absolute(legacy_path + ".backup")
```

---

## Phase 2: Redux Reducer Tests

### File: `test_save_reducer.gd`

```gdscript
extends GutTest

const U_SAVE_REDUCER = preload("res://scripts/state/reducers/u_save_reducer.gd")
const U_SAVE_ACTIONS = preload("res://scripts/state/actions/u_save_actions.gd")
const RS_SAVE_INITIAL_STATE = preload("res://scripts/state/resources/rs_save_initial_state.gd")

var initial_state: Dictionary

func before_each():
    var state_res := RS_SAVE_INITIAL_STATE.new()
    initial_state = state_res.to_dictionary()

# Test initial state
func test_initial_state_has_required_fields():
    assert_true(initial_state.has("last_save_slot"))
    assert_true(initial_state.has("slot_metadata"))
    assert_true(initial_state.has("is_saving"))
    assert_true(initial_state.has("is_loading"))

# Test SET_LAST_SAVE_SLOT
func test_set_last_save_slot():
    var action := U_SAVE_ACTIONS.set_last_save_slot(2)
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_eq(new_state["last_save_slot"], 2)

# Test SAVE_STARTED
func test_save_started():
    var action := U_SAVE_ACTIONS.save_started(1)
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_true(new_state["is_saving"])
    assert_eq(new_state["active_slot"], 1)
    assert_eq(new_state["last_error"], "")

# Test SAVE_COMPLETED
func test_save_completed():
    initial_state["is_saving"] = true
    var action := U_SAVE_ACTIONS.save_completed(2)
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_false(new_state["is_saving"])
    assert_eq(new_state["active_slot"], -1)
    assert_eq(new_state["last_save_slot"], 2)

# Test SAVE_FAILED
func test_save_failed():
    initial_state["is_saving"] = true
    var action := U_SAVE_ACTIONS.save_failed(1, "Disk full")
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_false(new_state["is_saving"])
    assert_eq(new_state["last_error"], "Disk full")

# Test LOAD_STARTED
func test_load_started():
    var action := U_SAVE_ACTIONS.load_started(3)
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_true(new_state["is_loading"])
    assert_eq(new_state["active_slot"], 3)

# Test LOAD_COMPLETED
func test_load_completed():
    initial_state["is_loading"] = true
    var action := U_SAVE_ACTIONS.load_completed(2)
    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_false(new_state["is_loading"])
    assert_eq(new_state["active_slot"], -1)

# Test state immutability
func test_reducer_does_not_mutate_original_state():
    var original_last_slot := initial_state["last_save_slot"]
    var action := U_SAVE_ACTIONS.set_last_save_slot(99)

    var new_state := U_SAVE_REDUCER.reduce(initial_state, action)

    assert_eq(initial_state["last_save_slot"], original_last_slot, "Original state mutated!")
    assert_eq(new_state["last_save_slot"], 99)
```

---

## Phase 7: Integration Tests

### File: `test_save_integration.gd`

```gdscript
extends GutTest

# End-to-end workflow tests

func test_complete_save_load_workflow():
    # 1. Save to slot 1
    # 2. Modify state
    # 3. Load from slot 1
    # 4. Verify state restored
    pass  # Implement after Phase 6

func test_autosave_workflow():
    # 1. Trigger autosave
    # 2. Verify slot 0 populated
    # 3. Load from slot 0
    pass  # Implement after Phase 3

func test_continue_button_workflow():
    # 1. Save to multiple slots
    # 2. Find most recent
    # 3. Load via Continue
    pass  # Implement after Phase 6
```

---

## Running Tests

### Run all save manager tests
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/state \
  -gtest=test_save*.gd \
  -gexit
```

### Run specific test file
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/state/test_save_manager.gd \
  -gexit
```

---

## Test Coverage Goals

- **Phase 1**: 100% coverage of SaveEnvelope and SaveManager static methods
- **Phase 2**: 100% coverage of reducer logic
- **Phase 7**: Key integration paths (save→load, autosave, Continue button)

---

## Test Data Cleanup

Always clean up test files in `after_each()` or test cleanup:

```gdscript
func after_each():
    for i in range(4):
        var path := U_SAVE_ENVELOPE.get_slot_path(i)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
```

---

## CI/CD Integration (Future)

When ready for CI:
1. Add GUT tests to GitHub Actions workflow
2. Fail build on test failures
3. Track test coverage metrics
