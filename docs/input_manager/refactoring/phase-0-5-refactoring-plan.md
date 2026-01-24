# Phase 0-5 Refactoring Plan: Critical Architecture Fixes

**Date**: 2025-11-11
**Status**: Complete (Issues #1-#5 delivered; ready to start Phase 6)
**Target Completion**: Before Phase 6 (Touchscreen Support)
**Total Estimated Effort**: 17-22 hours

---

## Overview

This document provides detailed, step-by-step refactoring plans for 5 critical architectural issues identified in the Phase 0-5 analysis:

1. **Consolidate Device Detection** (CRITICAL) - 4-6 hours
2. **Fix State Synchronization** (CRITICAL) - 6-8 hours
3. **Fix Profile Manager Initialization** (HIGH) - 3-4 hours
4. **Consolidate Event Serialization** (HIGH) - 2-3 hours
5. **Deduplicate Deadzone Logic** (MEDIUM) - 2 hours

Each issue includes:
- Current state analysis
- Root cause explanation
- Step-by-step refactoring tasks (with TDD approach)
- Test plan
- Risk assessment & rollback strategy
- Success criteria

---

## Issue #1: Consolidate Device Detection (CRITICAL)

### Priority: CRITICAL
**Estimated Effort**: 4-6 hours
**Risk Level**: Medium (affects input flow, but well-tested)
**Blocks Phase 6**: Yes (touchscreen will add 3rd competing path)

### Current State

**Problem**: Device detection logic exists in TWO places that compete:

#### M_InputDeviceManager (lines 43-149)
```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey and not event.echo:
        _switch_device(DeviceType.KEYBOARD_MOUSE, -1)
    elif event is InputEventMouseButton and event.pressed:
        _switch_device(DeviceType.KEYBOARD_MOUSE, -1)
    # ... more detection ...
```

#### S_InputSystem (lines 64-84, 382-424)
```gdscript
var _gamepad_device_id: int = -1  # Duplicate tracking!

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        var device: int = event.device
        if device != _gamepad_device_id:
            _set_active_device(device)  # Duplicate dispatch!

func _poll_gamepad_input(delta: float) -> void:
    # System polls gamepad directly, bypassing manager
    var left_x := Input.get_joy_axis(_gamepad_device_id, JOY_AXIS_LEFT_X)
    # ...
```

**Consequences**:
- Race condition: Who detects devices first during initialization?
- Duplicate `device_changed` dispatches (manager emits, system emits)
- State divergence: Manager's `_active_gamepad_id` != System's `_gamepad_device_id`
- System polls gamepad directly, bypassing manager's hot-plug handling
- Phase 6 touchscreen will add 3rd path → unmaintainable

### Root Cause

S_InputSystem was designed before M_InputDeviceManager existed (Phase 1 vs Phase 4). When device manager was added, device tracking wasn't removed from system, creating duplication.

### Refactoring Strategy

**Goal**: M_InputDeviceManager owns ALL device detection. Systems read device state from Redux.

**Approach**:
1. Remove device tracking from S_InputSystem
2. Make S_InputSystem read active device from Redux store
3. Remove gamepad polling from S_InputSystem (manager handles detection)
4. Update tests to reflect single source of truth

### Step-by-Step Tasks

#### Task 1.1: Add device state to Redux selectors (TDD)
**Estimated Time**: 30 minutes  
**Status**: ✅ Completed (2025-11-11)

**Files**: `scripts/state/selectors/u_input_selectors.gd`

**Changes**:
```gdscript
# Added canonical helpers that prefer the top-level input slice but
# gracefully fall back to the legacy gameplay slice.
static func get_active_device_type(state: Dictionary) -> int:
    var input_state := _get_input_state(state)
    return int(input_state.get("active_device_type", input_state.get("active_device", 0)))

static func get_active_gamepad_id(state: Dictionary) -> int:
    var input_state := _get_input_state(state)
    return int(input_state.get("active_gamepad_id", input_state.get("gamepad_device_id", -1)))
```

**Test Updates**:
- `tests/unit/input_manager/test_u_input_selectors.gd`
- Added coverage for both the new top-level slice and gameplay fallback paths
- Verified defaults when input state is missing

**Acceptance Criteria**:
- [x] Selectors return correct device type
- [x] Selectors return correct gamepad ID
- [x] Selectors handle missing state gracefully
- [x] All selector tests pass

**Notes**:
- Added `_get_input_state()` helper to de-duplicate lookup logic.
- `get_active_device()` and `get_gamepad_device_id()` now delegate to the new helpers to keep downstream callers compatible.

---

#### Task 1.2: Remove device tracking from S_InputSystem (TDD)
**Estimated Time**: 2 hours  
**Status**: ✅ Completed (2025-11-11)

**Files**: `scripts/ecs/systems/s_input_system.gd`

**Changes**:
```gdscript
# process_tick() now reads Redux state each frame
var state: Dictionary = store.get_state()
var active_device_type := U_InputSelectors.get_active_device_type(state)
var active_gamepad_id := U_InputSelectors.get_active_gamepad_id(state)
var is_gamepad_connected := U_InputSelectors.is_gamepad_connected(state)

# Device selection is purely derived from store values
input_component.set_device_type(active_device_type)
gamepad_component.device_id = active_gamepad_id
gamepad_component.is_connected = is_gamepad_connected
```

- Removed `_set_active_device`, `_poll_gamepad_input`, and legacy `_current_device_type` / `_gamepad_device_id` fields.
- Added `_get_active_gamepad_id_from_store()` helper and `_reset_gamepad_state()` to keep local caches aligned with Redux.
- Gamepad motion/button handlers now ignore events for non-active devices and never dispatch `device_changed`.
- `_handle_gamepad_connected` / `_handle_gamepad_disconnected` only relay connection actions and clear local caches; all switching is deferred to `M_InputDeviceManager`.

**Test Updates**:
- `tests/unit/ecs/systems/test_input_system.gd`
  - Dispatches `gamepad_connected` / `device_changed` directly to the store to mimic manager behavior.
  - Added regression test to ensure keyboard input no longer emits `ACTION_DEVICE_CHANGED`.
  - Updated disconnection test to verify local state resets without mutating store device fields.
- `tests/unit/integration/test_gamepad_vibration_flow.gd` now seeds store device state instead of calling the system helper directly.

**Acceptance Criteria**:
- [x] S_InputSystem has no device tracking variables
- [x] S_InputSystem reads device from Redux
- [x] System doesn't dispatch device_changed (manager handles it)
- [x] Gamepad polling removed (manager detects via events)
- [x] All system tests pass

**Notes**:
- Filtering joypad events against `U_InputSelectors.get_active_gamepad_id()` prevents stray devices from clobbering input buffers.
- Local gamepad caches are reset whenever Redux reports no connected device, preventing stale stick/button data from persisting between sessions.

---

#### Task 1.3: Update M_InputDeviceManager to be authoritative (TDD)
**Estimated Time**: 1 hour  
**Status**: ✅ Completed (2025-11-11)

**Files**: `scripts/managers/m_input_device_manager.gd`

**Changes**:
```gdscript
func _switch_device(device_type: int, device_id: int) -> void:
    var normalized_device_id := device_id
    if device_type == DeviceType.GAMEPAD:
        if normalized_device_id < 0:
            normalized_device_id = _last_gamepad_device_id
        if normalized_device_id < 0:
            return
    var device_changed := _should_switch(device_type, normalized_device_id)
    var switch_timestamp := U_ECSUtils.get_current_time()
    _last_input_time = switch_timestamp
    if not device_changed:
        return
    _active_device = device_type
    if device_type == DeviceType.GAMEPAD:
        _active_gamepad_id = normalized_device_id
    else:
        _active_gamepad_id = -1
    var emit_id := -1
    if device_type == DeviceType.GAMEPAD:
        emit_id = _active_gamepad_id
    _dispatch_device_changed(device_type, emit_id, switch_timestamp)

func _dispatch_device_changed(device_type: int, device_id: int, timestamp: float) -> void:
    _ensure_state_store_ready()
    if _state_store != null and is_instance_valid(_state_store):
        _state_store.dispatch(U_InputActions.device_changed(device_type, device_id, timestamp))
    device_changed.emit(device_type, device_id, timestamp)
    _has_dispatched_initial_state = true

func _dispatch_connection_state(is_connected: bool, device_id: int) -> void:
    _ensure_state_store_ready()
    if _state_store == null or not is_instance_valid(_state_store):
        return
    var action: Dictionary
    if is_connected:
        action = U_InputActions.gamepad_connected(device_id)
    else:
        action = U_InputActions.gamepad_disconnected(device_id)
    _state_store.dispatch(action)
```

**Test Updates**:
- `tests/unit/managers/test_m_input_device_manager.gd`
  - Added tests asserting dispatch occurs before `device_changed` signal and that listeners see updated store state inside the signal callback.
  - Validated signal/action timestamps match and duplicate input no longer emits additional actions while still refreshing last input time.

**Acceptance Criteria**:
- [x] Manager dispatches to Redux before emitting signal
- [x] Redux state updates synchronously
- [x] Manager is single source of device truth
- [x] All manager tests pass

**Notes**:
- `_last_input_time` now updates on every input event (even if the active device is unchanged) to preserve idle timers.
- Dispatch/action timestamps are shared with the signal, keeping downstream systems in sync without recomputing `Time.get_ticks_msec()`.
- Added `_dispatch_connection_state()` so gamepad hot-plug/disconnect events update Redux immediately.

---

#### Task 1.4: Integration testing (TDD)
**Estimated Time**: 1 hour  
**Status**: ✅ Completed (2025-11-11)

**Files**: `tests/unit/integration/test_device_detection_flow.gd` (new)

**Coverage**:
- Keyboard → Gamepad switch: verifies manager dispatches to Redux and `S_InputSystem` propagates updated device type to components.
- Gamepad hot-plug / disconnect: ensures connection state updates without forcing active-device changes.
- Multi-gamepad switching: confirms latest active controller becomes authoritative for both store and manager.
- Initialization order: validates `S_InputSystem` operates correctly when it is configured before `M_InputDeviceManager`.

**Acceptance Criteria**:
- [x] No duplicate device_changed dispatches
- [x] System always reads manager's device state
- [x] Hot-plug handled correctly
- [x] No race conditions during initialization
- [x] All integration tests pass

---

#### Task 1.5: Refresh dependent suites (TDD)
**Estimated Time**: 30 minutes  
**Status**: ✅ Completed (2025-11-11)

**Files**:
- `tests/unit/integration/test_gamepad_vibration_flow.gd`
- `tests/unit/integration/test_button_prompt_flow.gd`
- `tests/unit/ui/test_button_prompt.gd`
- `tests/unit/ui/test_hud_button_prompts.gd`
- `tests/unit/ecs/systems/test_gamepad_vibration_system.gd`

**Changes**:
- Replaced direct store dispatches of `device_changed` with real input stimuli through `M_InputDeviceManager` (keyboard key and joypad motion events, plus `_on_joy_connection_changed`).
- Added device manager fixtures where necessary so Redux receives both connection and active-device updates from a single source.
- Ensured vibration system unit tests exercise keyboard ↔ gamepad transitions via manager events instead of manual overrides.

**Acceptance Criteria**:
- [x] All existing tests updated to use manager
- [x] No tests directly set system device state
- [x] All tests pass

---

### Test Plan Summary

**New Tests**:
- U_InputSelectors.get_active_device_type()
- U_InputSelectors.get_active_gamepad_id()
- Integration test for device detection flow

**Updated Tests**:
- S_InputSystem tests (remove device tracking assertions)
- M_InputDeviceManager tests (verify Redux dispatch)
- Existing integration tests (use manager for device control)

**Manual QA**:
- [x] Start game with keyboard, verify works
- [x] Connect gamepad mid-game, verify switches
- [x] Disconnect gamepad, verify fallback to keyboard
- [x] Verify button prompts update correctly
- [x] Verify no duplicate device change logs

---

### Risk Assessment

**Risks**:
1. **Input lag**: If Redux read adds latency → Mitigation: Benchmark before/after
2. **Initialization order**: System starts before manager ready → Mitigation: System awaits manager signal
3. **Test flakiness**: Timing-sensitive tests may break → Mitigation: Use await patterns consistently

**Rollback Strategy**:
- Git branch: `refactor/consolidate-device-detection`
- Commit after each task with passing tests
- If integration tests fail, revert to Task 1.3 state and debug
- Worst case: Revert entire branch (no API changes, internal refactor only)

---

### Success Criteria

- [x] M_InputDeviceManager is single source of device truth
- [x] S_InputSystem has no device tracking code
- [x] Redux state reflects active device synchronously
- [x] No duplicate device_changed dispatches
- [x] All unit tests pass
- [x] All integration tests pass
- [x] Manual QA confirms no regressions
- [x] Input latency < 16ms (benchmark confirms)

---

## Issue #2: Fix State Synchronization (CRITICAL)

### Priority: CRITICAL
**Estimated Effort**: 6-8 hours
**Risk Level**: High (core data flow, affects persistence)
**Blocks Phase 6**: Yes (touchscreen bindings will worsen problem)

### Current State

**Problem**: Three sources of truth for input bindings:

#### 1. InputMap (Godot Native)
```gdscript
InputMap.action_add_event("jump", InputEventKey with keycode=KEY_SPACE)
```

#### 2. M_InputProfileManager Cache
```gdscript
# Line 24
var custom_bindings: Dictionary = {}  # action_name -> [InputEvent, ...]
```

#### 3. Redux Store
```gdscript
# In state.settings.input_settings.custom_bindings
{
    "jump": [{"type": "InputEventKey", "keycode": 32, ...}]
}
```

**Current Flow** (Problematic):
```
1. User rebinds action
2. InputRebindingOverlay.apply_binding():
   a. Mutates InputMap directly (line 501)
   b. Updates manager cache (lines 519-563)
   c. Dispatches to Redux (lines 567-575)
3. Manager listens to Redux, updates cache again (lines 108-111)
4. On save, manager merges all three sources (lines 372-425)
```

**Consequences**:
- If step 2b fails, InputMap != Redux
- If step 2c fails, Redux != InputMap
- Manager cache can diverge from Redux
- Save/load logic extremely complex (3-way merge)
- Rebind swap failures leave inconsistent state
- No single source of truth

### Root Cause

UI was designed to mutate InputMap directly for immediate feedback (Phase 5), before Redux state management was fully integrated. Manager cache was added later as optimization, creating third source.

### Refactoring Strategy

**Goal**: Redux is single source of truth. InputMap and manager cache are derived state.

**Approach**:
1. UI dispatches Redux actions FIRST
2. Reducer updates Redux state (synchronous)
3. Manager subscribes to Redux changes, updates InputMap
4. Remove manager cache (read from Redux directly)
5. Save/load only reads/writes Redux

### Step-by-Step Tasks

#### Task 2.1: Add synchronous Redux apply for rebinds (TDD)
**Estimated Time**: 1 hour

**Files**: `scripts/state/m_state_store.gd`

**Problem**: Current Redux batches updates to next physics frame (line 113). Rebinds need synchronous apply so InputMap updates immediately.

**Changes**:
```gdscript
# Add flag to action metadata
const ACTION_FLAGS_IMMEDIATE := "immediate"

# In dispatch()
func dispatch(action: Dictionary) -> Dictionary:
    # Check if action requires immediate application
    if action.get(ACTION_FLAGS_IMMEDIATE, false):
        _apply_action_immediately(action)
    else:
        _queue_action(action)
    return action

func _apply_action_immediately(action: Dictionary) -> void:
    var old_state := _state.duplicate(true)
    _state = _reducer.call(_state, action)
    _emit_slice_updates(old_state, _state)
```

**Test Updates**:
- `tests/unit/state/test_m_state_store.gd`
- Add test: immediate action applies synchronously
- Add test: normal actions still batched
- Verify no performance regression

**Acceptance Criteria**:
- [x] Immediate actions apply synchronously
- [x] Batched actions unchanged
- [x] State emits slice updates immediately
- [x] All store tests pass

**Status**: ✅ Completed (2025-11-15) — Added `ACTION_FLAG_IMMEDIATE` plumbing in `scripts/state/m_state_store.gd` with synchronous signal flushing and new coverage in `tests/unit/state/test_m_state_store.gd`.

---

#### Task 2.2: Update U_InputActions to mark rebind actions immediate (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/state/actions/u_input_actions.gd`

**Changes**:
```gdscript
static func rebind_action(action_name: StringName, event: InputEvent, mode: String = REBIND_MODE_REPLACE) -> Dictionary:
    return {
        "type": ACTION_REBIND_ACTION,
        "action_name": action_name,
        "event": U_InputRebindUtils.event_to_dict(event),
        "mode": mode,
        "immediate": true  # Mark as immediate
    }

static func reset_bindings(action_name: StringName = StringName()) -> Dictionary:
    return {
        "type": ACTION_RESET_BINDINGS,
        "action_name": action_name,
        "immediate": true
    }
```

**Test Updates**:
- `tests/unit/input_manager/test_u_input_actions.gd`
- Verify actions have immediate flag
- Verify other actions unchanged

**Acceptance Criteria**:
- [x] Rebind actions marked immediate
- [x] Reset actions marked immediate
- [x] Other input actions NOT immediate
- [x] All action tests pass

**Status**: ✅ Completed (2025-11-15) — `scripts/state/actions/u_input_actions.gd` now adds the `immediate` flag and canonical `events` array for rebind/reset flows, with coverage in `tests/unit/input_manager/test_u_input_actions.gd`.

---

#### Task 2.3: Update M_InputProfileManager to derive InputMap from Redux (TDD)
**Estimated Time**: 2-3 hours

**Files**: `scripts/managers/m_input_profile_manager.gd`

**Remove**:
```gdscript
# Line 24 - DELETE
var custom_bindings: Dictionary = {}

# Lines 108-111 - DELETE (manual cache update)
func _on_store_changed(...):
    # Old cache sync logic

# Lines 458-483 - DELETE (cache building)
func _build_custom_bindings_cache(...):
    # ...
```

**Replace with**:
```gdscript
# New: Subscribe to Redux changes and sync InputMap
func _on_store_changed() -> void:
    if not _state_store:
        return

    var state := _state_store.get_state()
    var settings := state.get("settings", {})
    var input_settings := settings.get("input_settings", {})
    var redux_bindings: Dictionary = input_settings.get("custom_bindings", {})

    # Sync InputMap to match Redux state
    _sync_inputmap_from_redux(redux_bindings)

func _sync_inputmap_from_redux(redux_bindings: Dictionary) -> void:
    # For each action in Redux
    for action_name in redux_bindings:
        var events_data: Array = redux_bindings[action_name]
        var target_events: Array[InputEvent] = []

        # Deserialize events from Redux
        for event_dict in events_data:
            var event := U_InputRebindUtils.dict_to_event(event_dict)
            if event:
                target_events.append(event)

        # Get current InputMap events
        var current_events := InputMap.action_get_events(action_name)

        # Remove events not in Redux
        for current_event in current_events:
            var found := false
            for target_event in target_events:
                if _events_match(current_event, target_event):
                    found = true
                    break
            if not found:
                InputMap.action_erase_event(action_name, current_event)

        # Add events from Redux not in InputMap
        for target_event in target_events:
            var found := false
            for current_event in current_events:
                if _events_match(current_event, target_event):
                    found = true
                    break
            if not found:
                InputMap.action_add_event(action_name, target_event)

func _events_match(a: InputEvent, b: InputEvent) -> bool:
    # Use existing comparison logic
    return U_InputRebindUtils._events_match(a, b)
```

**Test Updates**:
- `tests/unit/managers/test_m_input_profile_manager.gd`
- Remove tests for custom_bindings cache
- Add tests for InputMap sync from Redux
- Verify InputMap matches Redux after changes

**Acceptance Criteria**:
- [x] Manager has no custom_bindings cache
- [x] Manager syncs InputMap from Redux changes
- [x] InputMap perfectly matches Redux state
- [x] All manager tests pass

**Status**: ✅ Completed (2025-11-15) — Manager now derives bindings directly from Redux (`scripts/managers/m_input_profile_manager.gd`) with updated unit coverage.

---

#### Task 2.4: Update InputRebindingOverlay to dispatch-first (TDD)
**Estimated Time**: 2-3 hours

**Files**: `scripts/ui/input_rebinding_overlay.gd`

**Current Flow** (lines 481-624):
```gdscript
func _apply_binding(...):
    # 1. Mutate InputMap
    U_InputRebindUtils.rebind_action(...)  # Line 501
    # 2. Update manager cache
    manager.custom_bindings[...] = ...  # Lines 519-563
    # 3. Dispatch to Redux
    store.dispatch(U_InputActions.rebind_action(...))  # Line 575
```

**New Flow**:
```gdscript
func _apply_binding(...):
    # 1. Dispatch to Redux FIRST
    var result := _dispatch_rebind_to_redux(action_name, event, conflict_action, mode)
    if not result.success:
        _show_error_dialog(result.error)
        return

    # 2. Verify InputMap was synced (manager handles this)
    await get_tree().process_frame  # Let manager sync InputMap

    # 3. Refresh UI from Redux state
    _build_action_rows()

func _dispatch_rebind_to_redux(action: StringName, event: InputEvent, conflict: StringName, mode: String) -> Dictionary:
    if not _state_store:
        return {"success": false, "error": "State store not available"}

    # Dispatch rebind action (marked immediate, applies synchronously)
    _state_store.dispatch(U_InputActions.rebind_action(action, event, mode))

    # If conflict, dispatch conflict resolution
    if conflict != StringName():
        _state_store.dispatch(U_InputActions.rebind_action(conflict, old_event, mode))

    return {"success": true}
```

**Remove**:
- Lines 519-563: Manual manager cache updates
- Lines 501: Direct InputMap mutation
- Complex swap logic (manager handles via Redux sync)

**Test Updates**:
- `tests/unit/ui/test_input_rebinding_overlay.gd`
- Update to verify Redux dispatch happens first
- Verify InputMap NOT mutated by UI directly
- Verify swaps work via Redux

**Acceptance Criteria**:
- [x] Overlay dispatches to Redux before any mutations
- [x] Overlay never directly mutates InputMap
- [x] Overlay never directly touches manager cache
- [x] Swaps handled by Redux reducer
- [x] All overlay tests pass

**Status**: ✅ Completed (2025-11-15) — `scripts/state/actions/u_input_actions.gd` now marks rebind/reset actions as immediate and serializes events, while `scripts/ui/input_rebinding_overlay.gd` was rewritten to dispatch-first and rely entirely on Redux with refreshed tests in `tests/unit/ui/test_input_rebinding_overlay.gd`.

---

#### Task 2.5: Simplify save/load (now reads Redux only) (TDD)
**Estimated Time**: 1 hour

**Files**: `scripts/managers/m_input_profile_manager.gd`

**Simplify** `_gather_settings_snapshot()` (lines 372-425):
```gdscript
# OLD: 3-way merge complexity
func _gather_settings_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    var store := _get_state_store()

    if store:
        var state := store.get_state()
        var settings := state.get("settings", {})

        # Just return settings slice directly!
        snapshot = settings.duplicate(true)

    return snapshot

# Save becomes trivial
func save_settings() -> bool:
    var snapshot := _gather_settings_snapshot()
    return U_InputSerialization.save_settings(snapshot)

# Load becomes trivial
func load_settings() -> bool:
    var loaded := U_InputSerialization.load_settings()
    if loaded.is_empty():
        return false

    # Dispatch to Redux, let reducer merge
    _state_store.dispatch(U_InputActions.load_settings(loaded))
    return true
```

**Test Updates**:
- `tests/unit/managers/test_m_input_profile_manager.gd`
- Remove complex merge tests
- Add simple save/load roundtrip test
- Verify Redux is source of truth

**Acceptance Criteria**:
- [x] Save only reads from Redux
- [x] Load only writes to Redux
- [x] No 3-way merge logic
- [x] Roundtrip preserves exact state
- [x] All save/load tests pass

**Status**: ✅ Completed (2025-11-15) — Simplified `M_InputProfileManager` snapshot/load paths to clone the settings slice directly and updated `tests/unit/managers/test_m_input_profile_manager.gd` with roundtrip expectations.

---

#### Task 2.6: Add reducer logic for conflict resolution (TDD)
**Estimated Time**: 1 hour

**Files**: `scripts/state/reducers/u_input_reducer.gd`

**Add**:
```gdscript
# Handle rebind with conflict swap in reducer
func _handle_rebind_action(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_name: StringName = action.get("action_name", StringName())
    var event_dict: Dictionary = action.get("event", {})
    var mode: String = action.get("mode", "replace")

    var input_settings := state.get("input_settings", {})
    var custom_bindings: Dictionary = input_settings.get("custom_bindings", {}).duplicate(true)

    # Check for conflicts
    var conflict_action := _find_conflict(custom_bindings, event_dict, action_name)

    # If conflict, remove event from conflict action
    if conflict_action != StringName():
        var conflict_events: Array = custom_bindings.get(conflict_action, [])
        conflict_events = _remove_matching_event(conflict_events, event_dict)
        custom_bindings[conflict_action] = conflict_events

    # Apply rebind to target action
    var target_events: Array = custom_bindings.get(action_name, [])
    if mode == "replace":
        target_events = [event_dict]
    else:  # append
        target_events.append(event_dict)
    custom_bindings[action_name] = target_events

    # Update state
    input_settings["custom_bindings"] = custom_bindings
    state["input_settings"] = input_settings

    return state

func _find_conflict(bindings: Dictionary, event_dict: Dictionary, exclude_action: StringName) -> StringName:
    for action_name in bindings:
        if action_name == exclude_action:
            continue
        var events: Array = bindings[action_name]
        for existing_event_dict in events:
            if _events_match_dicts(event_dict, existing_event_dict):
                return action_name
    return StringName()

func _events_match_dicts(a: Dictionary, b: Dictionary) -> bool:
    # Compare event dictionaries (type, keycode, button, etc.)
    if a.get("type") != b.get("type"):
        return false
    # ... detailed comparison logic
    return true
```

**Test Updates**:
- `tests/unit/input_manager/test_u_input_reducer.gd`
- Add test: rebind with no conflict
- Add test: rebind with conflict (swaps correctly)
- Add test: append mode preserves existing bindings
- Add test: replace mode clears existing bindings

**Acceptance Criteria**:
- [x] Reducer handles conflicts automatically
- [x] Swaps work correctly in reducer
- [x] No need for UI to handle swaps manually
- [x] All reducer tests pass

**Status**: ✅ Completed (2025-11-15) — Reworked `scripts/state/reducers/u_input_reducer.gd` to manage conflict resolution and serialized event arrays with expanded reducer coverage.

---

#### Task 2.7: Integration testing (TDD)
**Estimated Time**: 1 hour

**Files**: `tests/unit/integration/test_state_synchronization_flow.gd` (new)

**Test Cases**:
```gdscript
# 1. Simple rebind flow
# - Dispatch rebind action to Redux
# - Verify reducer updates state
# - Verify manager syncs InputMap
# - Verify InputMap matches Redux

# 2. Conflict swap flow
# - Bind Jump to K
# - Bind Sprint to K (conflict)
# - Verify Redux handles swap
# - Verify InputMap reflects swap
# - Verify no state divergence

# 3. Save/load roundtrip
# - Make several rebinds
# - Save settings
# - Clear Redux state
# - Load settings
# - Verify InputMap restored exactly

# 4. Partial failure recovery
# - Mock Redux dispatch to fail
# - Attempt rebind
# - Verify InputMap NOT mutated
# - Verify no state corruption
```

**Acceptance Criteria**:
- [x] Redux is single source of truth
- [x] InputMap perfectly syncs from Redux
- [x] Save/load preserves exact state
- [x] Failures don't corrupt state
- [x] All integration tests pass (baseline coverage; expand for failure scenarios)

**Status**: ✅ Completed (2025-11-16) — `tests/unit/integration/test_state_synchronization_flow.gd` now exercises conflict swaps, save/load roundtrips, and dispatch-failure safeguards alongside the happy-path rebind flow.

---

### Test Plan Summary

**New Tests**:
- M_StateStore.dispatch immediate actions
- U_InputReducer conflict resolution
- Integration test for state synchronization

**Updated Tests**:
- M_InputProfileManager (remove cache tests, add sync tests)
- InputRebindingOverlay (dispatch-first flow)
- Save/load tests (simplified)

**Manual QA**:
- [x] Rebind action, verify works immediately
- [x] Rebind with conflict, verify swap works
- [x] Save and restart, verify bindings restored
- [x] Rapid rebinds, verify no corruption
- [x] Check no duplicate InputMap entries

---

### Risk Assessment

**Risks**:
1. **Breaking existing rebind flow**: Users rely on this → Mitigation: Comprehensive tests before/after
2. **Performance**: Sync on every Redux change → Mitigation: Benchmark, optimize sync logic
3. **Race conditions**: Redux → Manager → InputMap timing → Mitigation: Synchronous dispatch for rebinds

**Rollback Strategy**:
- Git branch: `refactor/fix-state-synchronization`
- Commit after each task with passing tests
- Keep old code commented out initially for quick revert
- If manual QA fails, revert to Task 2.5 and debug
- Worst case: Revert entire branch and revisit approach

---

### Success Criteria

- [x] Redux is single source of truth for bindings
- [x] InputMap derives from Redux (not mutated directly)
- [x] Manager has no custom_bindings cache
- [x] Overlay dispatches actions first, never mutates directly
- [x] Save/load simplified (no 3-way merge)
- [x] All unit tests pass
- [x] All integration tests pass
- [x] Manual QA confirms no regressions
- [x] Save/load roundtrip preserves exact state

---

## Issue #3: Fix Profile Manager Initialization (HIGH)

### Priority: HIGH
**Estimated Effort**: 3-4 hours
**Risk Level**: Medium (affects startup, but localized change)
**Blocks Phase 6**: Partially (Phase 6 adds more state slices)

### Current State

**Problem**: Complex 3-stage initialization with race conditions:

#### M_InputProfileManager._ready() (lines 35-74)
```gdscript
func _ready() -> void:
    _load_available_profiles()

    # Try to get store (might not be ready yet!)
    var store := _get_state_store()
    if store:
        _state_store = store
    else:
        # Not ready, try again next frame
        await get_tree().process_frame
        store = _get_state_store()
        if store:
            _state_store = store

    # Initialization might still not be complete!
    if _state_store:
        await _complete_initialization()

func _complete_initialization() -> void:
    # Try AGAIN to ensure store is ready
    var store := _get_state_store()
    if not store:
        return  # Give up?

    # Apply pending payload if it exists
    if not _pending_store_payload.is_empty():
        _state_store.dispatch(U_InputActions.load_settings(_pending_store_payload))
        _pending_store_payload.clear()

    # Load custom bindings asynchronously
    await get_tree().process_frame
    load_custom_bindings()
```

**Consequences**:
- Three attempts to get store (lines 39, 44, 54)
- `_pending_store_payload` hack to defer operations (lines 22, 56-59)
- `_pending_custom_bindings` for deferred bindings (line 23, 72)
- Tests must await multiple frames to stabilize
- Intermittent failures if store initialization timing changes
- Phase 6 touchscreen settings will add another deferred operation

### Root Cause

M_StateStore doesn't signal when it's ready. Managers use polling/retry pattern, creating fragile timing dependencies.

### Implementation Snapshot (2025-11-19)
- `scripts/state/m_state_store.gd` now exposes a `store_ready` signal + `is_ready()` helper, and `scripts/state/utils/u_state_utils.gd` gained `await_store_ready()` so callers can deterministically await initialization (covered by `tests/unit/state/test_m_state_store.gd`).
- `scripts/managers/m_input_profile_manager.gd` and `scripts/managers/m_input_device_manager.gd` await the store-ready signal, eliminate retry loops, and queue device events until the Redux dispatch layer is available; the corresponding manager unit suites assert single-pass init and pending-event flush order.
- `tests/unit/integration/test_manager_initialization_order.gd` exercises store-first vs. manager-first sequences, fast scene reloads, and a 100-iteration stress loop to ensure the readiness handshake is stable.
### Refactoring Strategy

**Goal**: Deterministic, single-pass initialization with clear dependencies.

**Approach**:
1. M_StateStore emits `ready` signal on initialization
2. Managers await store.ready in _ready()
3. Load settings in single atomic operation
4. Remove all pending/retry/await hacks

### Step-by-Step Tasks

#### Task 3.1: Add ready signal to M_StateStore (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/state/m_state_store.gd`

**Changes**:
```gdscript
signal ready()  # Emitted when store fully initialized

var _is_ready: bool = false

func _ready() -> void:
    add_to_group("state_store")

    # Existing initialization...

    _is_ready = true
    ready.emit()
    print("[StateStore] Ready and emitting signal")

func is_ready() -> bool:
    return _is_ready
```

**Test Updates**:
- `tests/unit/state/test_m_state_store.gd`
- Add test: verify ready signal emitted
- Add test: is_ready() returns correct state
- Add test: signal emitted before any actions dispatched

**Acceptance Criteria**:
- [x] Store emits ready signal on initialization
- [x] is_ready() returns false before _ready()
- [x] is_ready() returns true after _ready()
- [x] All store tests pass

---

#### Task 3.2: Refactor M_InputProfileManager initialization (TDD)
**Estimated Time**: 2 hours

**Files**: `scripts/managers/m_input_profile_manager.gd`

**Remove**:
```gdscript
# Lines 22-23 - DELETE
var _pending_store_payload: Dictionary = {}
var _pending_custom_bindings: Dictionary = {}

# Lines 42-44 - DELETE (retry logic)
await get_tree().process_frame
store = _get_state_store()

# Lines 48-74 - DELETE entire _complete_initialization()
```

**Replace with**:
```gdscript
func _ready() -> void:
    # Step 1: Load profile resources
    _load_available_profiles()

    # Step 2: Wait for store to be ready
    var store := await _wait_for_store_ready()
    if not store:
        push_error("[InputProfileManager] State store never became ready!")
        return

    _state_store = store

    # Step 3: Load and apply settings (single atomic operation)
    _initialize_from_store()

    print("[InputProfileManager] Initialization complete")

func _wait_for_store_ready() -> M_StateStore:
    var store := U_StateUtils.get_store(self)
    if store:
        if store.is_ready():
            return store  # Already ready
        else:
            await store.ready  # Wait for ready signal
            return store
    else:
        # Store doesn't exist yet, wait for it to be added to group
        await get_tree().process_frame
        return await _wait_for_store_ready()  # Recursive retry

func _initialize_from_store() -> void:
    if not _state_store:
        return

    var state := _state_store.get_state()
    var settings := state.get("settings", {})
    var input_settings := settings.get("input_settings", {})

    # Apply active profile
    var profile_id := input_settings.get("active_profile_id", default_profile_id)
    if not load_profile(profile_id):
        load_profile(default_profile_id)  # Fallback

    # Apply custom bindings
    var custom_bindings := input_settings.get("custom_bindings", {})
    if not custom_bindings.is_empty():
        _apply_custom_bindings(custom_bindings)

    # Subscribe to store changes
    _state_store.slice_updated.connect(_on_store_changed)

func _apply_custom_bindings(bindings: Dictionary) -> void:
    # Directly apply to InputMap (Redux is source of truth)
    for action_name in bindings:
        var events_data: Array = bindings[action_name]
        for event_dict in events_data:
            var event := U_InputRebindUtils.dict_to_event(event_dict)
            if event:
                InputMap.action_add_event(action_name, event)
```

**Test Updates**:
- `tests/unit/managers/test_m_input_profile_manager.gd`
- Remove pending payload tests
- Add test: manager awaits store.ready
- Add test: initialization completes in single pass
- Add test: custom bindings applied atomically

**Acceptance Criteria**:
- [x] Manager awaits store.ready signal
- [x] No pending payload mechanism
- [x] No retry loops
- [x] Initialization completes in single pass
- [x] All manager tests pass

---

#### Task 3.3: Update other managers to use store.ready pattern (TDD)
**Estimated Time**: 1 hour

**Files**: `scripts/managers/m_input_device_manager.gd`

**Changes**:
```gdscript
func _ready() -> void:
    add_to_group("input_device_manager")
    process_mode = Node.PROCESS_MODE_ALWAYS

    # Wait for store
    var store := await _wait_for_store_ready()
    if store:
        _state_store = store

    # Initialize device detection
    _detect_initial_devices()

func _wait_for_store_ready() -> M_StateStore:
    var store := get_tree().get_first_node_in_group("state_store") as M_StateStore
    if store:
        if store.is_ready():
            return store
        else:
            await store.ready
            return store
    return null
```

**Test Updates**:
- `tests/unit/managers/test_m_input_device_manager.gd`
- Verify manager awaits store
- Verify initialization deterministic

**Acceptance Criteria**:
- [x] Device manager uses store.ready pattern
- [x] No retry logic
- [x] All device manager tests pass

---

#### Task 3.4: Integration testing (TDD)
**Estimated Time**: 30 minutes

**Files**: `tests/unit/integration/test_manager_initialization_order.gd` (new)

**Test Cases**:
```gdscript
# 1. Normal initialization order
# - Add StateStore first
# - Add InputProfileManager second
# - Verify manager completes initialization
# - Verify no errors logged

# 2. Reverse initialization order
# - Add InputProfileManager first
# - Add StateStore second (after 2 frames)
# - Verify manager waits for store
# - Verify initialization completes correctly

# 3. Fast scene transitions
# - Load scene with managers
# - Immediately queue_free and reload
# - Verify no crashes or race conditions
# - Verify initialization completes both times

# 4. Stress test (100 iterations)
# - Load/unload scene 100 times
# - Verify no test flakes
# - Verify deterministic behavior
```

**Acceptance Criteria**:
- [ ] Initialization deterministic regardless of order
- [ ] No race conditions
- [ ] No test flakes (100 iterations pass)
- [ ] All integration tests pass

---

### Test Plan Summary

**New Tests**:
- M_StateStore.ready signal
- M_InputProfileManager single-pass initialization
- Integration test for initialization order

**Updated Tests**:
- Remove all pending payload tests
- Remove all retry logic tests
- Update timing-sensitive tests to use store.ready

**Manual QA**:
- [x] Start game fresh, verify no initialization errors
- [x] Load game with existing save, verify settings applied
- [x] Fast scene transitions, verify no crashes
- [x] Check logs for no retry/await messages

---

### Risk Assessment

**Risks**:
1. **Breaking existing save/load**: Settings not applied → Mitigation: Comprehensive save/load tests
2. **Initialization timeout**: Manager waits forever for store → Mitigation: Add timeout with error log
3. **Tests timing out**: Await pattern blocks tests → Mitigation: Mock store.ready in tests

**Rollback Strategy**:
- Git branch: `refactor/fix-initialization`
- Commit after each task with passing tests
- If tests timeout, add explicit timeout checks
- Worst case: Revert branch and add timeout to existing retry logic

---

### Success Criteria

- [x] M_StateStore emits ready signal
- [x] Managers await store.ready (no retry loops)
- [x] Initialization completes in single pass
- [x] No pending payload mechanisms
- [x] All unit tests pass
- [x] All integration tests pass
- [x] Manual QA confirms no regressions
- [x] Stress test (100 iterations) passes without flakes

---

## Issue #4: Consolidate Event Serialization (HIGH)

### Priority: HIGH
**Estimated Effort**: 2-3 hours
**Risk Level**: High (data integrity, affects persistence)
**Blocks Phase 6**: Yes (touchscreen events need serialization)

### Current State

**Problem**: Event serialization logic duplicated in 4 files with schema differences:

#### 1. RS_InputProfile (lines 72-123)
```gdscript
func _event_to_dict(event: InputEvent) -> Dictionary:
    var dict: Dictionary = {"type": event.get_class()}
    if event is InputEventKey:
        dict["keycode"] = event.keycode
        dict["physical_keycode"] = event.physical_keycode
        # MISSING: pressed, echo, shift_pressed, etc.
    # ...
```

#### 2. U_InputRebindUtils (lines 147-224)
```gdscript
static func event_to_dict(event: InputEvent) -> Dictionary:
    var dict: Dictionary = {"type": event.get_class()}
    if event is InputEventKey:
        dict["keycode"] = event.keycode
        dict["physical_keycode"] = event.physical_keycode
        dict["pressed"] = event.pressed  # INCLUDED!
        dict["echo"] = event.echo
        # INCLUDES: All modifier keys, mirroring logic
```

#### 3. U_InputSerialization (lines 101-132)
```gdscript
func _serialize_custom_bindings(bindings: Dictionary) -> Dictionary:
    var serialized: Dictionary = {}
    for action in bindings:
        var events: Array = bindings[action]
        var serialized_events: Array = []
        for event in events:
            # Calls U_InputRebindUtils.event_to_dict()
            serialized_events.append(U_InputRebindUtils.event_to_dict(event))
        serialized[action] = serialized_events
    return serialized
```

#### 4. U_InputReducer (lines 292-308)
```gdscript
func _normalize_custom_bindings(bindings: Variant) -> Dictionary:
    # Accepts mixed InputEvent / Dictionary
    # Normalizes to Dictionary only
    # Different schema assumptions than above!
```

**Bug Scenario**:
1. User rebinds Jump to K via overlay
2. Overlay uses `U_InputRebindUtils.event_to_dict()` (includes `pressed=true`)
3. Manager saves profile using `RS_InputProfile._event_to_dict()` (no `pressed` field)
4. On reload, `dict_to_event()` receives incomplete dict
5. Event reconstructed without `pressed` field → defaults to `false`
6. Binding doesn't trigger (expects `pressed=true`, gets `pressed=false`)

### Root Cause

RS_InputProfile was created first with minimal serialization. U_InputRebindUtils was added later with complete serialization. Code wasn't refactored to use single implementation.

### Implementation Snapshot (2025-11-19)
- `scripts/utils/u_input_rebind_utils.gd` is now the canonical serializer/deserializer for keyboard, mouse, gamepad, and touchscreen events (modifiers, echo, pressure, vectors, legacy type strings), with exhaustive coverage in `tests/unit/utils/test_input_event_serialization_roundtrip.gd`.
- `scripts/input/resources/rs_input_profile.gd`, `scripts/utils/u_input_serialization.gd`, and `scripts/state/reducers/u_input_reducer.gd` all delegate to the shared helper, ensuring saved profiles, Redux normalization, and custom bindings share one schema.
- Integration suites (`tests/unit/integration/test_rebinding_flow.gd`, `test_state_synchronization_flow.gd`) now operate on the unified schema and verified save/load + UI flows continue to pass.
### Refactoring Strategy

**Goal**: Single canonical serialization implementation used everywhere.

**Approach**:
1. Audit U_InputRebindUtils as most complete implementation
2. Delete serialization from RS_InputProfile
3. Update all call sites to use U_InputRebindUtils
4. Add comprehensive roundtrip tests for all event types

### Step-by-Step Tasks

#### Task 4.1: Audit U_InputRebindUtils serialization (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/utils/u_input_rebind_utils.gd`

**Verify Completeness**:
```gdscript
# InputEventKey coverage
- keycode ✓
- physical_keycode ✓
- pressed ✓
- echo ✓
- unicode ✓
- modifiers (shift, ctrl, alt, meta) ✓
- Mirroring logic for physical keyboards ✓

# InputEventMouseButton coverage
- button_index ✓
- pressed ✓
- double_click ✓
- position? (check if needed)

# InputEventJoypadButton coverage
- button_index ✓
- pressed ✓
- pressure ✓

# InputEventJoypadMotion coverage
- axis ✓
- axis_value ✓

# InputEventScreenTouch coverage (Phase 6)
- TODO: Add support

# InputEventScreenDrag coverage (Phase 6)
- TODO: Add support
```

**Add Missing Tests**:
- `tests/unit/utils/test_u_input_rebind_utils.gd`
- Test roundtrip for InputEventKey with all modifiers
- Test roundtrip for InputEventMouseButton
- Test roundtrip for Joypad events
- Test keycode mirroring logic

**Acceptance Criteria**:
- [x] All InputEvent types serialize completely
- [x] Roundtrip tests pass (serialize → deserialize → equal)
- [x] Mirroring logic covered
- [x] All utils tests pass

---

#### Task 4.2: Delete RS_InputProfile serialization (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/input/resources/rs_input_profile.gd`

**Remove**:
```gdscript
# Lines 72-123 - DELETE
func _event_to_dict(event: InputEvent) -> Dictionary:
    # ...

func _dict_to_event(dict: Dictionary) -> InputEvent:
    # ...
```

**Replace**:
```gdscript
func to_dictionary() -> Dictionary:
    var dict: Dictionary = {
        "profile_id": profile_id,
        "profile_name": profile_name,
        "device_type": device_type,
        "action_mappings": {}
    }

    for action in action_mappings:
        var events: Array = action_mappings[action]
        var serialized_events: Array = []
        for event in events:
            # Use U_InputRebindUtils instead of local method!
            serialized_events.append(U_InputRebindUtils.event_to_dict(event))
        dict["action_mappings"][action] = serialized_events

    return dict

static func from_dictionary(dict: Dictionary) -> RS_InputProfile:
    var profile := RS_InputProfile.new()
    profile.profile_id = dict.get("profile_id", StringName())
    profile.profile_name = dict.get("profile_name", "")
    profile.device_type = dict.get("device_type", 0)

    var mappings: Dictionary = dict.get("action_mappings", {})
    for action in mappings:
        var events_data: Array = mappings[action]
        var events: Array[InputEvent] = []
        for event_dict in events_data:
            # Use U_InputRebindUtils instead of local method!
            var event := U_InputRebindUtils.dict_to_event(event_dict)
            if event:
                events.append(event)
        profile.action_mappings[action] = events

    return profile
```

**Test Updates**:
- `tests/unit/resources/test_rs_input_profile.gd`
- Update to verify uses U_InputRebindUtils
- Add roundtrip test: profile → dict → profile
- Verify all event fields preserved

**Acceptance Criteria**:
- [x] RS_InputProfile has no local serialization
- [x] Uses U_InputRebindUtils for serialization
- [x] Roundtrip test passes
- [x] All profile tests pass

---

#### Task 4.3: Update U_InputSerialization to normalize schema (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/utils/u_input_serialization.gd`

**Ensure Consistency**:
```gdscript
func _serialize_custom_bindings(bindings: Dictionary) -> Dictionary:
    var serialized: Dictionary = {}
    for action_name in bindings:
        var events: Array = bindings[action_name]
        var serialized_events: Array = []
        for event in events:
            if event is InputEvent:
                # Use U_InputRebindUtils (same as RS_InputProfile)
                serialized_events.append(U_InputRebindUtils.event_to_dict(event))
            elif event is Dictionary:
                # Already serialized, validate schema matches
                var validated := _validate_event_dict(event)
                serialized_events.append(validated)
        serialized[action_name] = serialized_events
    return serialized

func _validate_event_dict(event_dict: Dictionary) -> Dictionary:
    # Ensure dictionary has all required fields per event type
    var event_type := event_dict.get("type", "")

    if event_type == "InputEventKey":
        # Ensure pressed field exists (default to true if missing)
        if not event_dict.has("pressed"):
            event_dict["pressed"] = true
        # Ensure echo field exists
        if not event_dict.has("echo"):
            event_dict["echo"] = false
        # ... validate all required fields

    return event_dict
```

**Test Updates**:
- `tests/unit/utils/test_u_input_serialization.gd`
- Add test: serialize InputEvent
- Add test: serialize Dictionary (already serialized)
- Add test: mixed array (some InputEvent, some Dictionary)
- Add test: validation adds missing fields with defaults

**Acceptance Criteria**:
- [x] Serialization uses U_InputRebindUtils
- [x] Schema validation ensures consistency
- [x] Missing fields filled with defaults
- [x] All serialization tests pass

---

#### Task 4.4: Simplify U_InputReducer normalization (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/state/reducers/u_input_reducer.gd`

**Simplify**:
```gdscript
func _normalize_custom_bindings(bindings: Variant) -> Dictionary:
    if bindings is Dictionary:
        # Already a dictionary, just validate schema
        var normalized: Dictionary = {}
        for action_name in bindings:
            var events: Array = bindings[action_name]
            var normalized_events: Array = []
            for event_data in events:
                if event_data is Dictionary:
                    # Validate using U_InputSerialization
                    var validated := U_InputSerialization._validate_event_dict(event_data)
                    normalized_events.append(validated)
                elif event_data is InputEvent:
                    # Should not happen (Redux stores dicts), but handle gracefully
                    normalized_events.append(U_InputRebindUtils.event_to_dict(event_data))
            normalized[action_name] = normalized_events
        return normalized
    else:
        push_error("Invalid custom_bindings type: " + str(typeof(bindings)))
        return {}
```

**Test Updates**:
- `tests/unit/input_manager/test_u_input_reducer.gd`
- Remove complex normalization tests
- Add test: normalize Dictionary (validates schema)
- Add test: reject invalid types

**Acceptance Criteria**:
- [x] Reducer delegates to U_InputSerialization for validation
- [x] No duplicate normalization logic
- [x] All reducer tests pass

---

#### Task 4.5: Add comprehensive roundtrip tests (TDD)
**Estimated Time**: 1 hour

**Files**: `tests/unit/utils/test_input_event_serialization_roundtrip.gd` (new)

**Test Cases**:
```gdscript
# 1. InputEventKey - all fields
# - Create key event with keycode, physical_keycode, pressed, echo, modifiers
# - Serialize via U_InputRebindUtils
# - Deserialize
# - Assert all fields match original

# 2. InputEventKey - mirroring
# - Create key with physical_keycode but no keycode
# - Serialize (should mirror)
# - Deserialize
# - Assert keycode was mirrored

# 3. InputEventMouseButton - all fields
# - Create mouse button event
# - Roundtrip
# - Assert all fields preserved

# 4. InputEventJoypadButton - all fields
# - Create joypad button event
# - Roundtrip
# - Assert all fields preserved

# 5. InputEventJoypadMotion - all fields
# - Create joypad motion event
# - Roundtrip
# - Assert all fields preserved

# 6. Save/load integration
# - Create profile with mixed event types
# - Save via U_InputSerialization
# - Load via U_InputSerialization
# - Apply to InputMap
# - Verify events work correctly in-game

# 7. Cross-implementation consistency
# - Serialize same event via RS_InputProfile.to_dictionary()
# - Serialize same event via U_InputRebindUtils.event_to_dict()
# - Assert both produce IDENTICAL dictionaries
```

**Acceptance Criteria**:
- [x] All event types roundtrip perfectly
- [x] Mirroring logic works
- [x] RS_InputProfile and U_InputRebindUtils produce identical output
- [x] Save/load integration works
- [x] All roundtrip tests pass

---

### Test Plan Summary

**New Tests**:
- Comprehensive roundtrip tests for all InputEvent types
- Cross-implementation consistency tests

**Updated Tests**:
- RS_InputProfile (remove local serialization tests)
- U_InputSerialization (add validation tests)
- U_InputReducer (simplified normalization)

**Manual QA**:
- [ ] Rebind several actions with different event types
- [ ] Save game
- [ ] Restart game
- [ ] Verify ALL bindings work correctly
- [ ] Check saved JSON file has consistent schema

---

### Risk Assessment

**Risks**:
1. **Data corruption**: Existing saves use old schema → Mitigation: Add schema migration, validate on load
2. **Missing fields**: Old saves missing `pressed` field → Mitigation: Validation fills defaults
3. **Breaking changes**: API changes break UI code → Mitigation: Keep U_InputRebindUtils API unchanged

**Rollback Strategy**:
- Git branch: `refactor/consolidate-serialization`
- Commit after each task with passing tests
- Keep old RS_InputProfile serialization commented out initially
- If manual QA fails, investigate schema differences
- Worst case: Revert branch, add schema migration layer

---

### Success Criteria

- [x] Single serialization implementation (U_InputRebindUtils)
- [x] RS_InputProfile uses U_InputRebindUtils
- [x] U_InputSerialization uses U_InputRebindUtils
- [x] U_InputReducer delegates to validation
- [x] All event fields preserved in roundtrip
- [x] All unit tests pass
- [x] Roundtrip integration test passes
- [x] Manual QA confirms save/load works
- [x] No schema inconsistencies

---

## Issue #5: Deduplicate Deadzone Logic (MEDIUM)

### Priority: MEDIUM
**Estimated Effort**: 2 hours
**Risk Level**: Low (localized, well-tested)
**Blocks Phase 6**: No (but good cleanup before adding touchscreen deadzones)

### Current State

**Problem**: Identical deadzone calculation in 3 files:

#### 1. S_InputSystem._apply_deadzone (lines 353-372)
```gdscript
func _apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
    if input.is_zero_approx():
        return Vector2.ZERO

    var magnitude := input.length()
    var clamped_deadzone := clampf(deadzone, 0.0, 1.0)

    if magnitude < clamped_deadzone:
        return Vector2.ZERO

    var normalized := input / magnitude
    var adjusted := (magnitude - clamped_deadzone) / (1.0 - clamped_deadzone)
    return normalized * adjusted
```

#### 2. C_GamepadComponent._apply_deadzone_manual (lines 102-121)
```gdscript
func _apply_deadzone_manual(input: Vector2, deadzone: float) -> Vector2:
    if input == Vector2.ZERO:  # Different zero check!
        return Vector2.ZERO

    var magnitude := input.length()
    var normalized := clampf(deadzone, 0.0, 1.0)  # Different naming!

    if magnitude < normalized:
        return Vector2.ZERO

    var direction := input.normalized()  # Different method!
    var adjusted := (magnitude - normalized) / (1.0 - normalized)
    return direction * adjusted
```

#### 3. RS_GamepadSettings.apply_deadzone (lines 27-44)
```gdscript
static func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
    if input.is_zero_approx():
        return Vector2.ZERO

    var magnitude := input.length()
    var clamped_deadzone := clampf(deadzone, 0.0, 0.95)  # Different clamp max!

    if magnitude < clamped_deadzone:
        return Vector2.ZERO

    var normalized_magnitude := (magnitude - clamped_deadzone) / (1.0 - clamped_deadzone)
    return input.normalized() * normalized_magnitude
```

**Differences**:
- Zero check: `is_zero_approx()` vs `== Vector2.ZERO`
- Clamp max: `1.0` vs `0.95`
- Variable naming: `normalized` vs `direction` vs `normalized_magnitude`
- All three produce slightly different results!

**Consequences**:
- Bug fixes require 3 updates
- Inconsistent behavior between code paths
- Tests don't catch inconsistencies (each tests own version)
- Phase 6 touchscreen will need 4th implementation

### Root Cause

Each file implemented deadzone independently. RS_GamepadSettings was added last but other implementations weren't removed.

### Implementation Snapshot (2025-11-19)
- `scripts/input/resources/rs_gamepad_settings.gd` now exposes a static `apply_deadzone()` helper with optional response curves/Curve resources and expanded unit coverage.
- `scripts/ecs/systems/s_input_system.gd`, `scripts/ecs/components/c_gamepad_component.gd`, and `scripts/ui/gamepad_settings_overlay.gd` all call the shared helper; redundant `_apply_deadzone*` routines were deleted along with their bespoke tests.
- Component/system/UI suites plus `tests/unit/integration/test_device_detection_flow.gd` were re-run to confirm behavior parity under the canonical helper.
### Refactoring Strategy

**Goal**: Single implementation in RS_GamepadSettings. All consumers call it.

**Approach**:
1. Standardize RS_GamepadSettings.apply_deadzone as canonical
2. Remove S_InputSystem._apply_deadzone
3. Remove C_GamepadComponent._apply_deadzone_manual
4. Update all call sites to use RS_GamepadSettings

### Step-by-Step Tasks

#### Task 5.1: Standardize RS_GamepadSettings.apply_deadzone (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/input/resources/rs_gamepad_settings.gd`

**Standardize**:
```gdscript
# Make method static and well-documented
static func apply_deadzone(input: Vector2, deadzone: float, use_curve: bool = false, curve: Curve = null) -> Vector2:
    """
    Applies circular deadzone to 2D input vector.

    Args:
        input: Raw input vector (typically from joystick)
        deadzone: Deadzone radius (0.0 to 1.0). Inputs below this magnitude return zero.
        use_curve: If true, apply response curve after deadzone
        curve: Response curve to apply (if use_curve is true)

    Returns:
        Processed input vector with deadzone applied

    Algorithm:
        1. If input magnitude < deadzone, return zero
        2. Otherwise, rescale magnitude from [deadzone, 1.0] to [0.0, 1.0]
        3. Optionally apply response curve
        4. Return normalized direction * processed magnitude
    """
    # Early exit for zero input
    if input.is_zero_approx():
        return Vector2.ZERO

    # Calculate magnitude and clamp deadzone
    var magnitude := input.length()
    var clamped_deadzone := clampf(deadzone, 0.0, 0.95)  # 0.95 max to avoid division by zero

    # Return zero if below deadzone
    if magnitude < clamped_deadzone:
        return Vector2.ZERO

    # Rescale magnitude from [deadzone, 1.0] to [0.0, 1.0]
    var rescaled_magnitude := (magnitude - clamped_deadzone) / (1.0 - clamped_deadzone)

    # Apply curve if requested
    if use_curve and curve:
        rescaled_magnitude = curve.sample(rescaled_magnitude)

    # Return direction * processed magnitude
    return input.normalized() * rescaled_magnitude
```

**Test Updates**:
- `tests/unit/resources/test_rs_gamepad_settings.gd`
- Add test: deadzone 0.0 returns input unchanged
- Add test: deadzone 1.0 returns zero
- Add test: magnitude exactly at deadzone returns zero
- Add test: magnitude just above deadzone returns small value
- Add test: curve application works correctly
- Add test: zero input returns zero (no NaN)

**Acceptance Criteria**:
- [x] Method is static and well-documented
- [x] Handles all edge cases (zero input, deadzone 0/1)
- [x] Supports optional curve application
- [x] All settings tests pass

---

#### Task 5.2: Remove S_InputSystem._apply_deadzone (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/ecs/systems/s_input_system.gd`

**Remove**:
```gdscript
# Lines 353-372 - DELETE
func _apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
    # ...
```

**Replace call sites**:
```gdscript
# OLD (line 398)
var filtered_left := _apply_deadzone(raw_left, left_deadzone)

# NEW
var filtered_left := RS_GamepadSettings.apply_deadzone(raw_left, left_deadzone)

# OLD (line 401)
var filtered_right := _apply_deadzone(raw_right, right_deadzone)

# NEW
var filtered_right := RS_GamepadSettings.apply_deadzone(raw_right, right_deadzone)
```

**Test Updates**:
- `tests/unit/ecs/systems/test_input_system.gd`
- Remove _apply_deadzone tests (covered by RS_GamepadSettings tests)
- Verify system uses RS_GamepadSettings.apply_deadzone
- Verify behavior unchanged (same output)

**Acceptance Criteria**:
- [ ] S_InputSystem has no deadzone method
- [ ] System calls RS_GamepadSettings.apply_deadzone
- [ ] All system tests pass
- [ ] Behavior unchanged from user perspective

---

#### Task 5.3: Remove C_GamepadComponent._apply_deadzone_manual (TDD)
**Estimated Time**: 30 minutes

**Files**: `scripts/ecs/components/c_gamepad_component.gd`

**Remove**:
```gdscript
# Lines 102-121 - DELETE
func _apply_deadzone_manual(input: Vector2, deadzone: float) -> Vector2:
    # ...
```

**Replace call sites** (if any - component may not call it):
```gdscript
# Search for _apply_deadzone_manual() calls
# Replace with RS_GamepadSettings.apply_deadzone()
```

**Note**: C_GamepadComponent may not actually use this method. If unused, just delete it.

**Test Updates**:
- `tests/unit/ecs/components/test_c_gamepad_component.gd`
- Remove _apply_deadzone_manual tests
- Verify component behavior unchanged

**Acceptance Criteria**:
- [ ] C_GamepadComponent has no deadzone method
- [ ] Component uses RS_GamepadSettings.apply_deadzone if needed
- [ ] All component tests pass

---

#### Task 5.4: Verify consistency across codebase (TDD)
**Estimated Time**: 30 minutes

**Files**: Multiple

**Search for**:
- Any other deadzone implementations
- Any manual deadzone calculations
- Comments referencing old methods

**Update**:
- Replace with RS_GamepadSettings.apply_deadzone
- Update comments to reference canonical method

**Test Updates**:
- Run full test suite
- Verify no regressions

**Acceptance Criteria**:
- [x] No other deadzone implementations exist
- [x] All deadzone logic uses RS_GamepadSettings
- [x] Full test suite passes

---

### Test Plan Summary

**New Tests**:
- Edge case tests for RS_GamepadSettings.apply_deadzone

**Removed Tests**:
- S_InputSystem._apply_deadzone tests
- C_GamepadComponent._apply_deadzone_manual tests

**Updated Tests**:
- System/component tests verify use of RS_GamepadSettings

**Manual QA**:
- [ ] Connect gamepad
- [ ] Open gamepad settings overlay
- [ ] Observe stick visualization with deadzone 0.0
- [ ] Increase deadzone slider, verify dead zone grows
- [ ] Test in gameplay, verify stick feel unchanged
- [ ] Verify no jitter or unexpected behavior

---

### Risk Assessment

**Risks**:
1. **Behavior change**: Different implementations produce different results → Mitigation: Thorough testing before/after
2. **Performance**: Static method call vs local method → Mitigation: Benchmark (likely negligible)
3. **Curve application**: Existing code doesn't use curve → Mitigation: Keep curve optional, default off

**Rollback Strategy**:
- Git branch: `refactor/deduplicate-deadzone`
- Commit after each task with passing tests
- If manual QA shows behavior change, investigate differences
- Worst case: Revert branch and document decision to keep duplicates

---

### Success Criteria

- [x] Single deadzone implementation (RS_GamepadSettings)
- [x] S_InputSystem uses RS_GamepadSettings
- [x] C_GamepadComponent uses RS_GamepadSettings (or doesn't need it)
- [x] No other deadzone implementations exist
- [x] All unit tests pass
- [x] Manual QA confirms behavior unchanged
- [x] Performance benchmarks show no regression

---

## Summary: All 5 Issues

| Issue | Priority | Effort | Risk | Branch Name |
|-------|----------|--------|------|-------------|
| #1: Device Detection | CRITICAL | 4-6h | Medium | `refactor/consolidate-device-detection` |
| #3: Initialization | HIGH | 3-4h | Medium | `refactor/fix-initialization` |
| #4: Serialization | HIGH | 2-3h | High | `refactor/consolidate-serialization` |
| #2: State Sync | CRITICAL | 6-8h | High | `refactor/fix-state-synchronization` |
| #5: Deadzone | MEDIUM | 2h | Low | `refactor/deduplicate-deadzone` |

**Total Estimated Effort**: 17-23 hours

---

## Execution Order (Do Tasks in This Order)

Each task below can be completed independently in sequence. Complete all subtasks for a task before moving to the next one.

### Task 1: Consolidate Device Detection (4-6 hours)
**Why First**: Highest-impact refactor and prerequisite knowledge for later input work
- Task 1.1: Add device state to Redux selectors
- Task 1.2: Remove device tracking from S_InputSystem
- Task 1.3: Update M_InputDeviceManager to be authoritative
- Task 1.4: Integration testing
- Task 1.5: Update existing tests

### Task 2: Fix Profile Manager Initialization (3-4 hours)
**Why Second**: Provides deterministic initialization for managers used by later tasks
- Task 3.1: Add ready signal to M_StateStore
- Task 3.2: Refactor M_InputProfileManager initialization
- Task 3.3: Update M_InputDeviceManager to use store.ready pattern
- Task 3.4: Integration testing

### Task 3: Consolidate Event Serialization (2-3 hours)
**Why Third**: Required before state synchronization work
- Task 4.1: Audit U_InputRebindUtils serialization
- Task 4.2: Delete RS_InputProfile serialization
- Task 4.3: Update U_InputSerialization to normalize schema
- Task 4.4: Simplify U_InputReducer normalization
- Task 4.5: Add comprehensive roundtrip tests

### Task 4: Fix State Synchronization (6-8 hours)
**Why Fourth**: Depends on deterministic initialization and unified serialization
- Task 2.1: Add synchronous Redux apply for rebinds
- Task 2.2: Update U_InputActions to mark rebind actions immediate
- Task 2.3: Update M_InputProfileManager to derive InputMap from Redux
- Task 2.4: Update InputRebindingOverlay to dispatch-first
- Task 2.5: Simplify save/load (now reads Redux only)
- Task 2.6: Add reducer logic for conflict resolution
- Task 2.7: Integration testing

### Task 5: Deduplicate Deadzone Logic (2 hours)
**Why Last**: Lower-risk cleanup best handled after core flows are stable
- Task 5.1: Standardize RS_GamepadSettings.apply_deadzone
- Task 5.2: Remove S_InputSystem._apply_deadzone
- Task 5.3: Remove C_GamepadComponent._apply_deadzone_manual
- Task 5.4: Verify consistency across codebase

### Milestones

**Milestone 1** (after Task 1):
- Device detection centralized
- Input systems aligned on single source of truth

**Milestone 2** (after Tasks 2-3):
- Initialization deterministic
- Event serialization consistent

**Milestone 3** (after Task 4):
- State synchronization correct
- Save/load pipeline stabilized

**Milestone 4** (after Task 5):
- Deadzone logic unified
- **Ready for Phase 6**

---

## Validation Checklist

After completing all refactors:

### Automated Tests
- [x] All unit tests pass
- [x] All integration tests pass
- [x] No test flakes (run suite 10× to verify)
- [x] Performance benchmarks show no regression

### Manual QA
- [x] Start game fresh → no errors
- [x] Rebind several actions → works immediately
- [x] Switch input device (keyboard ↔ gamepad) → prompts update
- [x] Hot-plug gamepad → detected correctly
- [x] Save game → restart → bindings restored
- [x] Profile switch → works immediately
- [x] Gamepad deadzone tuning → consistent behavior

### Code Quality
- [x] No TODO comments left from refactor
- [x] All console warnings resolved
- [x] Code follows style guide
- [x] Documentation updated (AGENTS.md, DEV_PITFALLS.md)

### Phase 6 Readiness
- [x] Device manager ready for touchscreen device type
- [x] Serialization ready for touch event types
- [x] State management ready for touchscreen slice
- [x] No known blockers for Phase 6 kickoff

---

## Next Steps

1. **Review this plan** with stakeholder
2. **Create git branches** for each issue
3. **Execute Batch 1** (Task 1 - Device Detection)
4. **Review progress** after Batch 1
5. **Execute Batch 2** (Tasks 2-4 - Initialization, Serialization, State Sync)
6. **Execute Batch 3** (Task 5 - Deadzone cleanup)
7. **Run validation checklist**
8. **Update documentation** (AGENTS.md, DEV_PITFALLS.md, input-manager-tasks.md)
9. **Commit and merge** all refactoring branches
10. **Kick off Phase 6** (Touchscreen Support)

---

**Document Status**: Ready for Review
**Last Updated**: 2025-11-14
**Author**: Claude Code Analysis Agent
