# Save Manager - Lessons Learned from Previous Implementation

**Date**: 2025-12-22
**Context**: Previous implementation (Dec 19) was deleted due to critical bugs
**Status**: Starting from scratch with bug prevention strategies

---

## 🔴 Critical Bugs from Previous Implementation

The following bugs caused the previous implementation to be abandoned. **Each must be explicitly prevented in the new implementation.**

---

### Bug #1: Focus Navigation Broken in Slot Selector

**Issue**:
> Pressing down after Auto on the Load Game should go to Load, left and right movement should only work if you're down in the Load, Delete, Back to Main Menu

**Root Cause**: Incorrect focus neighbor configuration

**Prevention Strategy**:
```gdscript
# In ui_save_slot_selector.gd
func _configure_focus() -> void:
    # Vertical navigation through slots only
    var slots: Array[Control] = [_autosave_slot, _slot_1, _slot_2, _slot_3]
    U_FocusConfigurator.configure_vertical_focus(slots, false)

    # Action buttons are separate focus group
    var action_buttons: Array[Control] = [_load_button, _delete_button, _back_button]
    U_FocusConfigurator.configure_horizontal_focus(action_buttons, false)

    # Connect slot group to action group
    _slot_3.focus_neighbor_bottom = _load_button.get_path()
    _load_button.focus_neighbor_top = _autosave_slot.get_path()

    # Disable left/right on slots
    for slot in slots:
        slot.focus_neighbor_left = NodePath()
        slot.focus_neighbor_right = NodePath()
```

**Test Case**:
- Navigate with gamepad through all slots
- Verify down from last slot goes to action buttons
- Verify left/right only works on action buttons

---

### Bug #2: Missing Screenshot Preview

**Issue**:
> Add a screenshot to Load Game

**Root Cause**: Save metadata doesn't include screenshot, UI has no preview area

**Prevention Strategy**:
```gdscript
# Phase 1: Add screenshot to SaveMetadata
class SaveMetadata:
    var screenshot_data: PackedByteArray = []  # PNG bytes

# Phase 5: Capture screenshot on save
func save_to_slot(slot_index: int, ...):
    var screenshot := _capture_viewport_screenshot()
    metadata.screenshot_data = screenshot

func _capture_viewport_screenshot() -> PackedByteArray:
    var viewport := get_viewport()
    var img := viewport.get_texture().get_image()
    # Resize to thumbnail (256x144)
    img.resize(256, 144, Image.INTERPOLATE_LANCZOS)
    return img.save_png_to_buffer()

# In UI: Display screenshot
@onready var _screenshot_rect: TextureRect = %ScreenshotPreview

func _update_slot_display(slot: Button, meta: Dictionary):
    if not meta.get("is_empty", true):
        var screenshot_bytes: PackedByteArray = meta.get("screenshot_data", [])
        if screenshot_bytes.size() > 0:
            var img := Image.new()
            img.load_png_from_buffer(screenshot_bytes)
            var texture := ImageTexture.create_from_image(img)
            _screenshot_rect.texture = texture
```

**Test Case**:
- Save game in different scenes
- Verify each slot shows correct screenshot thumbnail
- Verify empty slots show placeholder image

---

### Bug #3: Continue Button Shown When No Saves Exist

**Issue**:
> Continue shouldn't be an option if there's no saves

**Root Cause**: Button visibility not updated based on save existence

**Prevention Strategy**:
```gdscript
# In ui_main_menu.gd
func _ready() -> void:
    await super._ready()
    _update_button_visibility()

func _update_button_visibility() -> void:
    var has_saves := _check_for_saves()

    if _continue_button != null:
        _continue_button.visible = has_saves

    # Update focus chain when Continue is hidden
    if not has_saves and _new_game_button != null:
        _new_game_button.grab_focus()

func _check_for_saves() -> bool:
    const U_SAVE_ENVELOPE = preload("res://scripts/state/utils/u_save_envelope.gd")
    for i in range(4):  # Check all 4 slots
        if U_SAVE_ENVELOPE.slot_exists(i):
            return true
    return false
```

**Test Case**:
- Delete all saves, restart game
- Verify Continue button hidden
- Create save, return to main menu
- Verify Continue button now visible

---

### Bug #4: Main Menu Should Show "New Game" vs "Continue"

**Issue**:
> Instead of Play, it should be New Game or Continue depending on if we have an existing save slot or not

**Root Cause**: Static button labels, not dynamic based on save state

**Prevention Strategy**:
```gdscript
# In ui_main_menu.gd
@onready var _primary_button: Button = %PrimaryButton  # Dynamic label
@onready var _load_button: Button = %LoadButton

func _update_primary_button() -> void:
    var has_saves := _check_for_saves()

    if has_saves:
        _primary_button.text = "Continue"
        _primary_button.pressed.connect(_on_continue_pressed)
        _load_button.visible = true
        _load_button.text = "Load Game"
    else:
        _primary_button.text = "New Game"
        _primary_button.pressed.connect(_on_new_game_pressed)
        _load_button.visible = false

func _on_continue_pressed() -> void:
    var most_recent_slot := _find_most_recent_slot()
    if most_recent_slot >= 0:
        store.dispatch(U_SaveActions.load_from_slot(most_recent_slot))

func _find_most_recent_slot() -> int:
    const U_SAVE_MANAGER = preload("res://scripts/state/utils/u_save_manager.gd")
    var all_meta := U_SAVE_MANAGER.get_all_slot_metadata()

    var most_recent_slot := -1
    var most_recent_time := 0

    for meta in all_meta:
        if meta.get("is_empty", true):
            continue
        var timestamp: int = meta.get("timestamp", 0)
        if timestamp > most_recent_time:
            most_recent_time = timestamp
            most_recent_slot = meta.get("slot_index", -1)

    return most_recent_slot
```

**Test Case**:
- No saves: Verify "New Game" shown, Load hidden
- With saves: Verify "Continue" shown, "Load Game" visible
- Continue loads most recent save (not always autosave)

---

### Bug #5: Continue Loads Wrong Location First Time

**Issue**:
> Pressing continue, doesn't load the correct location until we exit again then press continue again. It kept the autosave behavior from before we created the save manager for initial continue

**Root Cause**: State handoff interference, old persistence system conflict

**Prevention Strategy**:
```gdscript
# CRITICAL: Ensure old save system is completely disabled
# In m_state_store.gd _ready()
func _ready() -> void:
    # ... existing initialization ...

    # DO NOT auto-load from legacy system if slot-based saves exist
    # Comment out or remove:
    # _try_autoload_state()  # ❌ REMOVE THIS

    # Instead: Check for slot-based saves first
    _try_autoload_from_slots()

func _try_autoload_from_slots() -> void:
    const U_SAVE_MANAGER = preload("res://scripts/state/utils/u_save_manager.gd")

    # Find most recent save
    var all_meta := U_SAVE_MANAGER.get_all_slot_metadata()
    var most_recent_slot := _find_most_recent_slot(all_meta)

    if most_recent_slot >= 0:
        var err := U_SAVE_MANAGER.load_from_slot(
            most_recent_slot,
            _state,
            _slice_configs
        )
        if err == OK:
            if settings != null and settings.enable_debug_logging:
                print("Auto-loaded from slot ", most_recent_slot)
    else:
        # No saves exist, use initial state
        pass
```

**Test Case**:
- Create save in Scene A
- Restart game
- Press Continue
- Verify loads Scene A immediately (not default scene)
- Verify correct spawn point

---

### Bug #6: Load Reopens Menu and Player Stuck

**Issue**:
> Pressing Load Game opens up the correct save, but it reopens the save menu and the player is completely stuck in the air

**Root Cause**:
1. Scene transition doesn't close overlay
2. Physics state not reset after load
3. Navigation state persisted incorrectly

**Prevention Strategy**:
```gdscript
# In ui_save_slot_selector.gd
func _perform_load(slot_index: int) -> void:
    var store := get_store()
    if store == null:
        return

    # CRITICAL: Close overlay BEFORE dispatching load
    store.dispatch(U_NavigationActions.close_all_overlays())

    # Wait for overlay to close
    await get_tree().process_frame

    # Dispatch load action
    store.dispatch(U_SaveActions.load_from_slot(slot_index))

# In m_state_store.gd - Subscribe to load actions
func _ready() -> void:
    # ... existing ...
    action_dispatched.connect(_on_action_dispatched)

func _on_action_dispatched(action: Dictionary) -> void:
    var action_type: StringName = action.get("type", StringName(""))

    if action_type == U_SaveActions.ACTION_LOAD_STARTED:
        _handle_load_started(action)

func _handle_load_started(action: Dictionary) -> void:
    var slot_index: int = action.get("slot_index", -1)

    # Load state from slot
    const U_SAVE_MANAGER = preload("res://scripts/state/utils/u_save_manager.gd")
    var err := U_SAVE_MANAGER.load_from_slot(slot_index, _state, _slice_configs)

    if err != OK:
        dispatch(U_SaveActions.load_failed(slot_index, error_string(err)))
        return

    # Clear navigation stack (critical!)
    dispatch(U_NavigationActions.reset_navigation())

    # Trigger scene transition to loaded scene
    var scene_state := get_slice(StringName("scene"))
    var target_scene: StringName = scene_state.get("current_scene_id", StringName("gameplay_base"))

    dispatch(U_SceneActions.transition_to_scene(target_scene))
    dispatch(U_SaveActions.load_completed(slot_index))

# CRITICAL: In gameplay scene, reset physics on load
# In gameplay_base.gd or similar
func _ready() -> void:
    var store := U_StateUtils.get_store(self)
    store.action_dispatched.connect(_on_action_dispatched)

func _on_action_dispatched(action: Dictionary) -> void:
    if action.get("type") == U_SaveActions.ACTION_LOAD_COMPLETED:
        _reset_player_physics()

func _reset_player_physics() -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player and player is CharacterBody3D:
        player.velocity = Vector3.ZERO
        # Apply spawn point position from state
        var store := U_StateUtils.get_store(self)
        var gameplay := store.get_slice(StringName("gameplay"))
        var spawn_point: StringName = gameplay.get("target_spawn_point", StringName("sp_default"))

        var spawn_manager := get_tree().get_first_node_in_group("spawn_manager") as M_SpawnManager
        if spawn_manager:
            spawn_manager.apply_spawn_to_player(spawn_point)
```

**Test Case**:
- Save in mid-air location
- Load that save
- Verify menu closes completely
- Verify player spawns at correct spawn point
- Verify player physics working (can move/jump)

---

### Bug #7: UI Button Mapping Backwards

**Issue**:
> Pressing ui accept should save a slot and ui cancel should delete it

**Root Cause**: Incorrect input action mapping in UI

**Prevention Strategy**:
```gdscript
# In ui_save_slot_selector.gd
func _ready() -> void:
    super._ready()

    # DO NOT use ui_accept/ui_cancel directly
    # Use explicit button presses instead

    # When slot is selected (focused)
    _connect_slot_buttons()

func _connect_slot_buttons() -> void:
    for i in range(_slots.size()):
        var slot := _slots[i]

        # Button press = SELECT slot (for save or load depending on mode)
        slot.pressed.connect(_on_slot_selected.bind(i))

        # Custom input handling for delete
        slot.gui_input.connect(_on_slot_gui_input.bind(i))

func _on_slot_selected(slot_index: int) -> void:
    match mode:
        Mode.SAVE:
            _show_save_confirmation(slot_index)
        Mode.LOAD:
            _show_load_confirmation(slot_index)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
    # Delete on specific button (e.g., Triangle/Y, or right-click)
    if event.is_action_pressed("ui_delete"):  # Add this action
        _show_delete_confirmation(slot_index)
        get_viewport().set_input_as_handled()
```

**Input Map Addition**:
```
# In project.godot, add:
input/ui_delete={
  "deadzone": 0.5,
  "events": [
    Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194326,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
    , Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":3,"pressure":0.0,"pressed":false,"script":null)
  ]
}
```

**Test Case**:
- Select slot, press A/Enter → Save/Load action
- Select slot, press Y/Delete → Delete confirmation
- Verify no cross-wiring between actions

---

### Bug #8: Load Triggers Save Dialog

**Issue**:
> I'm getting a request to save a slot dialog when I try to load while in the game

**Root Cause**: Mode detection broken, save selector opened in wrong mode

**Prevention Strategy**:
```gdscript
# In ui_pause_menu.gd
func _on_save_pressed() -> void:
    var store := get_store()
    if store == null:
        return

    # CRITICAL: Set mode BEFORE opening overlay
    store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.SAVE))
    store.dispatch(U_NavigationActions.open_overlay(OVERLAY_SAVE_SLOT_SELECTOR))

func _on_load_pressed() -> void:
    var store := get_store()
    if store == null:
        return

    # CRITICAL: Set mode BEFORE opening overlay
    store.dispatch(U_SaveActions.set_save_mode(UI_SaveSlotSelector.Mode.LOAD))
    store.dispatch(U_NavigationActions.open_overlay(OVERLAY_SAVE_SLOT_SELECTOR))

# In ui_save_slot_selector.gd
func _ready() -> void:
    super._ready()

    # Read mode from state (set by caller)
    var store := get_store()
    var save_state := store.get_slice(StringName("save"))
    var mode_value: int = save_state.get("current_mode", Mode.LOAD)
    mode = mode_value as Mode

    _update_for_mode()

func _update_for_mode() -> void:
    match mode:
        Mode.SAVE:
            _title_label.text = "Save Game"
            _autosave_slot.disabled = true  # Can't save to autosave
        Mode.LOAD:
            _title_label.text = "Load Game"
            _autosave_slot.disabled = false  # Can load autosave
```

**Additional Save Slice Fields**:
```gdscript
# In rs_save_initial_state.gd
@export var current_mode: int = 1  # 0=SAVE, 1=LOAD

# In u_save_actions.gd
static func set_save_mode(mode: int) -> Dictionary:
    return {"type": ACTION_SET_SAVE_MODE, "mode": mode}

# In u_save_reducer.gd
match action_type:
    U_SaveActions.ACTION_SET_SAVE_MODE:
        var new_state := state.duplicate(true)
        new_state["current_mode"] = action.get("mode", 1)
        return new_state
```

**Test Case**:
- From pause menu, click Save → Verify "Save Game" title
- From pause menu, click Load → Verify "Load Game" title
- Verify autosave disabled in Save mode
- Verify correct confirmation dialogs per mode

---

## 🎯 New Implementation Checklist

Before declaring each phase complete, explicitly test for these bugs:

### Phase 5 (UI Layer) Checklist:
- [ ] Focus navigation: Down from last slot goes to action buttons
- [ ] Focus navigation: Left/Right only works on action buttons, not slots
- [ ] Screenshot capture working (viewport → thumbnail)
- [ ] Screenshot display in slot UI
- [ ] Mode detection: Save mode disables autosave slot
- [ ] Mode detection: Correct title shown per mode

### Phase 6 (Menu Integration) Checklist:
- [ ] Continue button hidden when no saves exist
- [ ] Continue button visible when saves exist
- [ ] Main menu shows "New Game" when no saves
- [ ] Main menu shows "Continue" when saves exist
- [ ] Load Game button visibility tied to save existence

### Phase 7 (Load Flow) Checklist:
- [ ] Load closes overlay BEFORE scene transition
- [ ] Navigation stack cleared on load
- [ ] Physics state reset after load (velocity = zero)
- [ ] Spawn point correctly applied
- [ ] No stuck-in-air bugs
- [ ] First Continue loads correct scene (not default)

### Phase 8 (Polish) Checklist:
- [ ] Button mapping: Accept = Select slot
- [ ] Button mapping: Delete key = Delete slot
- [ ] No cross-wiring between save/load actions
- [ ] Confirmation dialogs match mode

---

## 📝 Architecture Decisions to Prevent Bugs

1. **Mode is State, Not Constructor Param**
   - Previous: `UI_SaveSlotSelector.new(Mode.SAVE)` → easy to get wrong
   - New: Mode stored in Redux, set before overlay opens

2. **Close Overlay Before Scene Transition**
   - Previous: Transition closed overlay → race condition
   - New: Explicit close, await frame, then transition

3. **Physics Reset is Explicit**
   - Previous: Assumed scene load resets physics → didn't
   - New: Gameplay scene listens for load_completed, resets explicitly

4. **Focus Configuration is Two-Tier**
   - Previous: Single focus chain → confusing navigation
   - New: Vertical for slots, horizontal for actions, explicit connection

5. **Screenshot is Part of Metadata**
   - Previous: Not saved
   - New: Captured on save, stored in envelope, displayed in UI

---

## 🚨 Critical Testing Protocol

**Manual Test Suite** (Run before marking feature complete):

1. **Focus Test**: Navigate entire slot UI with gamepad only
2. **Screenshot Test**: Save in 3 different scenes, verify thumbnails
3. **Continue Test**: Restart game 3 times, verify correct scene each time
4. **Load Test**: Load mid-gameplay, verify no physics bugs
5. **Mode Test**: Open Save from pause, Load from pause, verify titles
6. **Button Test**: Test all button mappings (accept, cancel, delete)
7. **Empty State Test**: Delete all saves, verify UI correct
8. **Rapid Test**: Rapid save/load cycles, look for race conditions

---

**Status**: These bugs MUST NOT reoccur. Each has explicit prevention strategy documented above.
