# Phase 6: Touchscreen Support - Comprehensive Architecture Document

**Date:** 2025-11-16 (Updated with final user decisions and comprehensive gap analysis)
**Status:** Tasks 6.1-6.2 Complete - Virtual Controls UI Next
**Phase Progress:** 22% (2 / 9 core tasks complete: RS_TouchscreenSettings + Redux Integration)

---

## Executive Summary

Phase 6 adds mobile touchscreen support with virtual on-screen controls (joystick + buttons). This document captures the comprehensive architectural audit conducted to avoid the refactoring issues experienced in Phases 0-5.

**Key Decisions (Finalized 2025-11-16):**
- ✅ **Positioning:** Drag-to-reposition overlay (separate EditTouchControlsOverlay screen)
- ✅ **Visibility:** Hidden during scene transitions (cleaner visual), hidden during pause menu
- ✅ **Opacity:** Dynamic fade (30% opacity after 2s idle, full on touch)
- ✅ **Button Set:** Complete (Jump + Sprint + Interact + Pause - 4 buttons)
- ✅ **Auto-hide:** When gamepad OR keyboard connected (device detection)
- ✅ **Orientation:** Landscape only (no rotation support in Phase 6)
- ✅ **Assets:** Kenney.nl Mobile pack (joystick_base, joystick_thumb, button_background)
- ✅ **Testing:** Physical mobile device available for verification; desktop --emulate-mobile flag only for fallback smoke + comprehensive unit tests
- ✅ **Reset:** Default touchscreen profile with metadata-driven button configuration

---

## 0. ARCHITECTURE VALIDATION & GAP ANALYSIS

### 0.1 What Went Wrong in backup-input-manager Branch

**Problem 1: Hardcoded Phone Dimensions**
- **Issue:** Code used literal values like `1080x1920` instead of viewport-relative coordinates
- **Impact:** Controls didn't scale across different screen sizes
- **Root Cause:** Not using project viewport settings (960x540 with stretch mode)

**Problem 2: Multiple Sources of Truth for Positions**
- **Issue:** Positions stored in UI local vars, profile metadata, AND partial Redux state
- **Impact:** State sync bugs, unclear reset behavior, save/load inconsistencies
- **Root Cause:** No clear ownership - which system is authoritative?

**Problem 3: Excessive Programmatic UI**
- **Issue:** Virtual controls built entirely in code (no .tscn scenes)
- **Impact:** Hard to iterate, no visual preview in editor, difficult to adjust sizing/layout
- **Root Cause:** Not following project pattern (95% Godot editor, 5% programmatic)

**Problem 4: No Clear Reset Path**
- **Issue:** No default touchscreen profile, unclear how to restore factory positions
- **Impact:** Users couldn't undo bad customizations
- **Root Cause:** Missing profile metadata for touchscreen device type

### 0.2 Current Architecture Strengths (Why Phase 6 Will Succeed)

**✅ Viewport Scaling is CORRECT**

Project settings validate proper configuration:
```
window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="viewport"
```

**Evidence:**
- ✅ No hardcoded phone dimensions found in codebase (searched for 1080, 720, 1920, "phone")
- ✅ All UI in `scenes/ui/*.tscn` uses anchor presets for automatic scaling
- ✅ CanvasLayers use process_mode for pause handling (not dimension-dependent)
- ✅ No direct `get_viewport().size` calls for layout (only for input handling in rebinding overlay)

**Recommendation:** Continue using viewport-relative coords (e.g., `Vector2(120, 450)` for 960x540 base) with anchor-based layouts for automatic scaling.

**✅ Redux State Management is READY**

Existing state structure already has touchscreen_settings:
```gdscript
settings.input_settings.touchscreen_settings = {
    "virtual_joystick_size": 1.0,
    "joystick_opacity": 0.7,
    "button_size": 1.0,
    "button_opacity": 0.8
}
```

**What's Missing:**
- `custom_joystick_position: Vector2(-1, -1)`
- `custom_button_positions: Dictionary` (action → Vector2)
- `joystick_deadzone: float`
- `button_opacity: float`

**Vector2 Serialization Pattern (User Decision: Hybrid Approach):**

Redux state stores Vector2 objects directly (in-memory), but save/load converts to/from dictionaries for JSON compatibility:

```gdscript
# In-memory (Redux state):
"touchscreen_settings": {
    "custom_joystick_position": Vector2(120, 450),  # Native Vector2
    "custom_button_positions": {
        "jump": Vector2(800, 450),  # Native Vector2
        "sprint": Vector2(800, 350)
    }
}

# On-disk (JSON):
{
    "touchscreen_settings": {
        "custom_joystick_position": {"x": 120.0, "y": 450.0},  # Dict for JSON
        "custom_button_positions": {
            "jump": {"x": 800.0, "y": 450.0},
            "sprint": {"x": 800.0, "y": 350.0}
        }
    }
}
```

**Conversion Points:**
- **Actions:** Receive Vector2, store Vector2 (no conversion)
- **Reducers:** Store Vector2 directly (no conversion)
- **Selectors:** Return Vector2 directly (no conversion)
- **U_InputSerialization.save_settings():** Convert Vector2 → {x, y} dict before JSON.stringify()
- **U_InputSerialization.load_settings():** Convert {x, y} dict → Vector2 after JSON.parse_string()

**Benefits:**
- ✅ Simpler reducer/selector code (no conversion overhead)
- ✅ JSON-compatible persistence
- ✅ Type safety in memory (Vector2 vs Dictionary)
- ✅ No runtime conversion during gameplay

**✅ Device Detection Already Handles Touch Events**

`M_InputDeviceManager` (lines 75-81) already detects:
- `InputEventScreenTouch` → switches to TOUCHSCREEN device type
- `InputEventScreenDrag` → switches to TOUCHSCREEN device type
- Emits `device_changed` signal → UI updates automatically
- Dispatches to Redux → state store tracks active device

**✅ ECS Pattern Can Reuse Existing Component**

Key insight: Phase 6 does NOT need `C_TouchscreenComponent`!

**S_TouchscreenSystem** will:
1. Query existing `C_InputComponent` (same component used by keyboard/gamepad)
2. Read `VirtualJoystick.get_vector()` and `VirtualButton.is_pressed()` states
3. Update `input.set_move_vector()`, `input.set_jump_pressed()`, etc.

**Pattern Match:** Follows `S_GamepadVibrationSystem` (queries components, processes via cached references)

**✅ Profile System is Extensible**

Existing profiles:
- `default_keyboard.tres` (WASD + Space + Shift)
- `alternate_keyboard.tres` (Arrows + Space + Shift)
- `default_gamepad.tres` (Gamepad bindings)

**To Add:** `default_touchscreen.tres` with virtual button metadata (4 buttons: jump, sprint, interact, pause)

### 0.3 Architecture Gaps Summary

**Gap 1: No Touchscreen UI Components**
- Missing: `VirtualJoystick.tscn` + `virtual_joystick.gd`
- Missing: `VirtualButton.tscn` + `virtual_button.gd`
- Missing: `MobileControls.tscn` + `mobile_controls.gd` (CanvasLayer container)
- Impact: Zero touchscreen functionality exists

**Gap 2: No Touchscreen System**
- Missing: `S_TouchscreenSystem` extends BaseECSSystem
- Current: `S_InputSystem` handles keyboard/gamepad but has no touchscreen path
- Impact: Even if UI existed, it wouldn't integrate with gameplay

**Gap 3: Incomplete Redux State Schema**
- Exists: Basic touchscreen_settings (4 fields)
- Missing: Position storage fields (`custom_joystick_position`, `custom_button_positions`)
- Missing: Deadzone field
- Impact: No persistence for user customization

**Gap 4: No Touchscreen Profile**
- Exists: Keyboard and gamepad profiles
- Missing: `default_touchscreen.tres` with virtual button metadata
- Impact: No reset-to-defaults capability, no metadata-driven button configuration

**Gap 5: No Resource Class**
- Missing: `RS_TouchscreenSettings` (equivalent to `RS_GamepadSettings`)
- Impact: No centralized tuning resource, no static deadzone helper

**Gap 6: No Settings UI**
- Missing: `TouchscreenSettingsOverlay` (sliders + live preview, like GamepadSettingsOverlay)
- Missing: `EditTouchControlsOverlay` for drag-to-reposition mode
- Impact: No user-facing customization

### 0.4 Critical Findings & Solutions (2025-11-16 Deep Analysis)

Following "Depth Prompt" analysis, 12 critical issues identified with severity ratings and user-approved solutions:

**🚨 BLOCKER (Must fix before Phase 6.0.1):**

1. **RS_InputProfile Serialization Bug**
   - **Finding:** Touchscreen fields (virtual_buttons, virtual_joystick_position) exist but NOT serialized in to_dictionary() / from_dictionary()
   - **Impact:** Default touchscreen profile won't save/load, reset-to-defaults will fail
   - **Solution:** Added as Task 6.0.0 (PREREQUISITE) - TDD approach, fix serialization methods
   - **User Decision:** Document as blocking task, fix before 6.0.1 starts

2. **Vector2 Serialization Strategy**
   - **Finding:** Redux state needs Vector2 positions, but JSON can't serialize Vector2 directly
   - **Impact:** Save/load will fail or corrupt position data
   - **Solution (User Decision: Hybrid Approach):**
     - Redux stores Vector2 in memory (native Godot, no conversion overhead)
     - Save converts Vector2 → {x, y} dict for JSON compatibility
     - Load converts {x, y} dict → Vector2 after deserialization
   - **Implementation:** Added as Task 6.2.8, pattern documented in Task 6.2

3. **Device Switching Race Condition**
   - **Finding:** MobileControls.visible updates on signal, but S_TouchscreenSystem runs in process_tick (1 frame lag)
   - **Impact:** Touchscreen input could bleed into gamepad frame after device switch
   - **Solution:** S_TouchscreenSystem checks active device type BEFORE processing
   - **Implementation:** Added to Task 6.6.2 as CRITICAL pattern with code example

**⚠️ GAP (Must implement in Phase 6):**

4. **Missing Redux State Fields**
   - **Finding:** touchscreen_settings exists but missing: joystick_deadzone, button_opacity, custom_joystick_position, custom_button_positions
   - **Impact:** No position storage, incomplete settings
   - **Solution:** Added to Task 6.2.4 initial state update

5. **Dynamic Opacity Implementation**
   - **Finding:** _process() approach in docs wastes CPU/battery on mobile
   - **Impact:** Poor mobile battery life, unnecessary frame overhead
   - **Solution (User Decision: Tween):** Use create_tween() for GPU-accelerated fade
   - **Implementation:** Updated Task 6.5.3 with Tween code example

6. **No Emergency Rollback Flag**
   - **Finding:** No way to disable touchscreen if critical bug found on mobile
   - **Impact:** Can't hotfix production issues without full redeploy
   - **Solution (User Decision: Add flag):** debug.disable_touchscreen in Redux debug slice
   - **Implementation:** Added as Task 6.6.4 with debug action/selector pattern

**🔍 CONCERN (Important for quality):**

7. **Vector2 Deserialization Testing Gap**
   - **Finding:** Migration test doesn't verify Vector2 fields deserialize correctly from JSON
   - **Impact:** Silent data corruption if dict → Vector2 conversion fails
   - **Solution:** Added Vector2 deserialization scenario to Task 6.8.1 integration test

8. **Multi-Touch Capacity Overflow**
   - **Finding:** Godot supports 32 simultaneous touches, design assumes 5 max
   - **Impact:** Edge case if user rests palm (5+ touches) could cause unexpected behavior
   - **Solution:** Documented as low-risk (VirtualJoystick/Button ignore non-assigned touches)

9. **HUD Safe Margin Metadata Missing**
   - **Finding:** Architecture mentions metadata pattern but no HUD elements have it yet
   - **Impact:** Virtual controls will overlap HUD on mobile
   - **Solution:** Added to Task 6.12.1 - manually add metadata to health bar, checkpoint toast, interact prompt

10. **Desktop Emulation Limitations**
    - **Finding:** `--emulate-mobile` can't test multi-touch, pressure, rotation, real performance
    - **Impact:** Bugs may only surface on physical devices
    - **Solution:** Documented limitations, defer physical testing to Phase 7

11. **Task Dependencies Not Explicit**
    - **Finding:** Task order implies dependencies but doesn't state them clearly
    - **Impact:** Could attempt tasks out of order, causing confusion/blocks
    - **Solution:** Added prerequisite notes to Task 6.0.0, Task 6.2.8

12. **Asset Attribution Missing**
    - **Finding:** Kenney assets are CC0 but best practice is to credit
    - **Impact:** Poor open-source etiquette
    - **Solution:** Added Task 6.15 to create CREDITS.md

**User Decisions Summary:**
- ✅ Profile bug: Document as Task 6.0.0 prerequisite (not fix immediately)
- ✅ Vector2 storage: Hybrid (Vector2 in memory, {x, y} on disk)
- ✅ Opacity fade: Tween (GPU-accelerated, better battery life)
- ✅ Rollback flag: Yes - add debug.disable_touchscreen

---

## 1. INTEGRATION WITH EXISTING SYSTEMS

### 1.1 Redux State Store Integration

**Pattern Established in Phases 1-5:**
- State lives in two slices:
  - `gameplay.input` (transient runtime state)
  - `settings.input_settings` (persistent)
- Actions dispatched via `U_InputActions`
- Reducers in `U_InputReducer`
- Selectors in `U_InputSelectors`

**Current Touchscreen State Support:**

The reducer already includes a `touchscreen_settings` structure:
```gdscript
"touchscreen_settings": {
	"virtual_joystick_size": 1.0,
	"virtual_joystick_opacity": 0.7,
	"button_layout": "default",
	"button_size": 1.0,
}
```

**Required Additions for Phase 6:**

**Extended touchscreen_settings structure:**
```gdscript
"touchscreen_settings": {
	"virtual_joystick_size": 1.0,
	"virtual_joystick_opacity": 0.7,
	"virtual_joystick_deadzone": 0.15,
	"button_size": 1.0,
	"button_opacity": 0.8,
	"button_layout": "default",  # References touchscreen profile
	"custom_joystick_position": Vector2(-1, -1),  # -1,-1 = use profile default
	"custom_button_positions": {}  # action_name -> Vector2, overrides profile
}
```

**CRITICAL CLARIFICATION - Position Storage Architecture:**
- **Profile fields (RS_InputProfile)** = DEFAULT positions (source of truth for reset)
  - `virtual_joystick_position: Vector2` - Default joystick position
  - `virtual_buttons: Array[Dictionary]` - Default button positions with actions
  - Set once in `.tres` file, rarely modified
- **Redux touchscreen_settings** = CUSTOM positions (player overrides)
  - `custom_joystick_position: Vector2(-1, -1)` - Player-dragged position override
  - `custom_button_positions: {}` - Player-dragged button position overrides
  - Saved to `user://input_settings.json`, persists across sessions
- **Selector priority (get_virtual_control_position):**
  1. Check Redux custom position (if not Vector2(-1, -1))
  2. Fall back to profile default position
  3. This pattern allows per-player customization with reset-to-defaults capability

**New Actions (U_InputActions):**
```gdscript
const ACTION_UPDATE_TOUCHSCREEN_SETTINGS := StringName("input/update_touchscreen_settings")
const ACTION_SAVE_VIRTUAL_CONTROL_POSITION := StringName("input/save_virtual_control_position")

static func update_touchscreen_settings(field: String, value: Variant) -> Dictionary:
	return {
		"type": ACTION_UPDATE_TOUCHSCREEN_SETTINGS,
		"payload": {"field": field, "value": value}
	}

static func save_virtual_control_position(control_name: String, position: Vector2) -> Dictionary:
	return {
		"type": ACTION_SAVE_VIRTUAL_CONTROL_POSITION,
		"payload": {"control_name": control_name, "position": position}
	}
```

**New Reducer Cases (U_InputReducer):**
```gdscript
U_InputActions.ACTION_UPDATE_TOUCHSCREEN_SETTINGS:
	var ts_payload: Dictionary = action.get("payload", {})
	var field: String = String(ts_payload.get("field", ""))
	if field.is_empty(): return current
	var ts_settings: Dictionary = _duplicate_dict(current.get("touchscreen_settings", {}))
	ts_settings[field] = ts_payload.get("value")
	return _with_values(current, {"touchscreen_settings": ts_settings})

U_InputActions.ACTION_SAVE_VIRTUAL_CONTROL_POSITION:
	var pos_payload: Dictionary = action.get("payload", {})
	var control_name: String = String(pos_payload.get("control_name", ""))
	var position: Vector2 = pos_payload.get("position", Vector2(-1, -1))
	if control_name.is_empty(): return current

	var ts_settings: Dictionary = _duplicate_dict(current.get("touchscreen_settings", {}))
	if control_name == "virtual_joystick":
		ts_settings["custom_joystick_position"] = position
	else:
		var button_positions: Dictionary = _duplicate_dict(ts_settings.get("custom_button_positions", {}))
		button_positions[control_name] = position
		ts_settings["custom_button_positions"] = button_positions

	return _with_values(current, {"touchscreen_settings": ts_settings})
```

**New Selectors (U_InputSelectors):**
```gdscript
static func get_touchscreen_settings(state: Dictionary) -> Dictionary:
	var settings: Variant = _get_input_settings_state(state).get("touchscreen_settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}

static func get_virtual_control_position(state: Dictionary, control_name: String, profile: RS_InputProfile = null) -> Vector2:
	# Priority: Custom position from Redux, fallback to profile default
	var ts_settings: Dictionary = get_touchscreen_settings(state)

	if control_name == "virtual_joystick":
		# Check Redux custom position first
		var custom_pos: Variant = ts_settings.get("custom_joystick_position", Vector2(-1, -1))
		if custom_pos is Vector2 and custom_pos != Vector2(-1, -1):
			return custom_pos as Vector2

		# Fall back to profile default
		if profile != null and profile.virtual_joystick_position != Vector2(-1, -1):
			return profile.virtual_joystick_position

		return Vector2(-1, -1)  # No position set
	else:
		# Check Redux custom button position first
		var button_positions: Variant = ts_settings.get("custom_button_positions", {})
		if button_positions is Dictionary:
			var pos: Variant = (button_positions as Dictionary).get(control_name, Vector2(-1, -1))
			if pos is Vector2 and pos != Vector2(-1, -1):
				return pos as Vector2

		# Fall back to profile default
		if profile != null:
			for button in profile.virtual_buttons:
				if button.get("action") == StringName(control_name):
					var default_pos: Variant = button.get("position", Vector2(-1, -1))
					if default_pos is Vector2:
						return default_pos as Vector2

		return Vector2(-1, -1)  # No position set
```

### 1.2 M_InputDeviceManager Integration

**EXCELLENT NEWS:** Touch device detection is already fully implemented!

**Existing Implementation (m_input_device_manager.gd:75-81, 107-108):**
```gdscript
func _input(event: InputEvent) -> void:
	# ... existing keyboard/mouse/gamepad handling ...
	elif event is InputEventScreenTouch:
		if not screen_touch.pressed: return
		_handle_touch_input()
	elif event is InputEventScreenDrag:
		_handle_touch_input()

func _handle_touch_input() -> void:
	_switch_device(DeviceType.TOUCHSCREEN, -1)
```

**What This Means:**
- ✅ Touch events already detected
- ✅ Device switches to TOUCHSCREEN automatically
- ✅ Redux action already dispatched (`device_changed`)
- ✅ Signal already emitted for UI components

**Required Additions:**
- **NONE!** Device detection is complete.

**Virtual Control Visibility Integration:**
- Virtual controls subscribe to `M_InputDeviceManager.device_changed` signal
- Hide when `device_type == DeviceType.GAMEPAD`
- Show when `device_type == DeviceType.TOUCHSCREEN`
- This matches the auto-hide behavior requested by user

### 1.3 ECS Manager Integration

**Pattern from S_InputSystem and S_GamepadVibrationSystem:**

**S_TouchscreenSystem Structure:**
```gdscript
@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_TouchscreenSystem

const INPUT_TYPE := StringName("C_InputComponent")

# References to virtual controls (cached in on_configured)
var _virtual_joystick: VirtualJoystick = null
var _virtual_buttons: Dictionary = {}  # action_name -> VirtualButton
var _state_store: M_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _touchscreen_settings: Dictionary = {}

func on_configured() -> void:
	_cache_virtual_controls()
	_ensure_state_store_ready()

func _cache_virtual_controls() -> void:
	# Find MobileControls layer and cache references
	var mobile_layer := get_tree().get_first_node_in_group("mobile_controls") as CanvasLayer
	if mobile_layer == null: return

	_virtual_joystick = mobile_layer.get_node_or_null("VirtualJoystick") as VirtualJoystick
	# ... cache button references ...

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return
	var store := U_StateUtils.get_store(self)
	if store == null: return
	_state_store = store
	_store_unsubscribe = store.subscribe(_on_state_changed)

func _on_state_changed(_prev: Dictionary, current: Dictionary) -> void:
	_touchscreen_settings = U_InputSelectors.get_touchscreen_settings(current)

func process_tick(_delta: float) -> void:
	if not OS.has_feature("mobile") and not _emulate_mobile_mode:
		return

	var entities := query_entities([INPUT_TYPE], [])
	for entity_query in entities:
		var input := entity_query.get_component(INPUT_TYPE) as C_InputComponent
		if input == null: continue

		# Update from virtual joystick
		if _virtual_joystick != null and _virtual_joystick.is_active():
			input.set_move_vector(_virtual_joystick.get_vector())

		# Update from virtual buttons
		for action in _virtual_buttons:
			var button := _virtual_buttons[action] as VirtualButton
			if button != null and button.is_pressed():
				# Dispatch action or update component directly
				pass
```

**Key Integration Points:**
- ✅ Extends `BaseECSSystem` (follows existing pattern)
- ✅ Queries existing `C_InputComponent` (NO new component needed!)
- ✅ Uses `U_StateUtils.get_store()` pattern
- ✅ Processes in `process_tick(_delta)` not `_physics_process()`
- ✅ Caches UI references in `on_configured()`

### 1.4 Scene Manager Integration

**Decision: Virtual Controls Are NOT Overlays**

Virtual controls are NOT managed by Scene Manager's overlay stack. They are persistent HUD elements that appear only on mobile devices.

**Scene Structure:**

**Mobile CanvasLayer - Root Scene Addition:**
```
Root (scenes/root.tscn)
├── Managers (Node)
│   ├── M_StateStore
│   ├── M_InputDeviceManager
│   └── M_InputProfileManager
├── HUD_Overlay (CanvasLayer)
│   └── ... (existing HUD elements)
└── MobileControls (CanvasLayer)  ← NEW - Added to root.tscn
    ├── VirtualJoystick (Control)
    └── VirtualButtons (Control)  ← Buttons instantiated dynamically from profile metadata
```

**S_TouchscreenSystem Placement:**
```
gameplay_base.tscn
├── Systems (Node)
│   ├── S_InputSystem  ← Existing
│   ├── S_GamepadVibrationSystem  ← Existing
│   └── S_TouchscreenSystem  ← NEW - Manual placement, same pattern as other systems
```

**CLARIFICATION**: S_TouchscreenSystem is manually placed in gameplay_base.tscn, NOT auto-instantiated by M_ECSManager.

**Why Separate CanvasLayer:**
- Easier show/hide logic (toggle entire layer)
- Independent Z-index control
- Cleaner HUD organization
- Conditional instantiation: only add on mobile

**MobileControls Script Pattern:**
```gdscript
extends CanvasLayer
class_name MobileControls

var _device_manager: M_InputDeviceManager = null
var _scene_manager: M_SceneManager = null
var _is_visible: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Stay responsive when paused
	add_to_group("mobile_controls")

	# Only instantiate on mobile or emulation mode
	if not OS.has_feature("mobile") and not _is_emulate_mode():
		queue_free()
		return

	_device_manager = get_tree().get_first_node_in_group("input_device_manager") as M_InputDeviceManager
	if _device_manager:
		_device_manager.device_changed.connect(_on_device_changed)

	_scene_manager = get_tree().get_first_node_in_group("scene_manager") as M_SceneManager
	if _scene_manager:
		_scene_manager.overlay_pushed.connect(_on_overlay_pushed)
		_scene_manager.overlay_popped.connect(_on_overlay_popped)

	_update_visibility()

func _on_device_changed(device_type: int, _device_id: int) -> void:
	# Hide when gamepad connected (auto-hide behavior)
	if device_type == M_InputDeviceManager.DeviceType.GAMEPAD:
		_is_visible = false
	else:
		_is_visible = true
	_update_visibility()

func _on_overlay_pushed(overlay_id: StringName) -> void:
	# Hide during pause menu (user requirement)
	if overlay_id == StringName("pause_menu"):
		_update_visibility()

func _on_overlay_popped() -> void:
	_update_visibility()

func _update_visibility() -> void:
	var in_pause := _scene_manager != null and _scene_manager.is_overlay_active(StringName("pause_menu"))
	visible = _is_visible and not in_pause
```

**Visibility Rules:**
1. **Show:** When `active_device == TOUCHSCREEN` AND NOT in pause menu
2. **Hide:** When gamepad connected (auto-hide)
3. **Hide:** When pause menu overlay active
4. **Visible:** During scene transitions (ignore `is_transitioning` flag)

### 1.5 M_InputProfileManager Integration

**New Profile Type: Touchscreen**

Like keyboard and gamepad profiles, we need default touchscreen profiles for reset capability.

**Touchscreen Profile Structure (RS_InputProfile):**
```gdscript
# resources/input/profiles/default_touchscreen.tres
profile_name: "Default (Touchscreen)"
device_type: 2  # DeviceType.TOUCHSCREEN
action_mappings: {}  # Touchscreen doesn't use InputMap

# Default positions for virtual controls (960x540 viewport)
virtual_joystick_position: Vector2(120, 300)  # bottom-left (clamped for 960x540 viewport)
virtual_buttons: [
	{"action": &"jump", "position": Vector2(800, 440)},      # bottom-right
	{"action": &"sprint", "position": Vector2(800, 340)},    # above jump
	{"action": &"interact", "position": Vector2(700, 440)},  # left of jump
	{"action": &"pause", "position": Vector2(700, 340)}      # left of sprint
]

# Complete button set (user decision: 4 buttons)
# Layout:
#                    [Pause]   [Sprint]
#                 [Interact]     [Jump]
# [Joystick]

# Note: Size/opacity/deadzone NOT stored in profile
# Those are global settings in Redux touchscreen_settings
```

**Profile Manager Extensions:**

Add methods for touchscreen profile management:
```gdscript
func reset_touchscreen_positions() -> void:
	var touchscreen_profile := _get_default_touchscreen_profile()
	if touchscreen_profile == null: return

	# Reset joystick position to profile default
	if touchscreen_profile.virtual_joystick_position != Vector2(-1, -1):
		_state_store.dispatch(U_InputActions.save_virtual_control_position(
			"virtual_joystick",
			touchscreen_profile.virtual_joystick_position
		))

	# Reset button positions to profile defaults
	for button in touchscreen_profile.virtual_buttons:
		var action: Variant = button.get("action")
		var position: Variant = button.get("position")
		if action is StringName and position is Vector2:
			_state_store.dispatch(U_InputActions.save_virtual_control_position(
				String(action),
				position
			))

func _get_default_touchscreen_profile() -> RS_InputProfile:
	# Use cached profile from available_profiles if loaded
	if available_profiles.has("default_touchscreen"):
		return available_profiles["default_touchscreen"]
	# Otherwise load directly
	return load("res://resources/input/profiles/default_touchscreen.tres") as RS_InputProfile
```

### 1.6 S_InputSystem Integration

**Current S_InputSystem Behavior:**
- Blends keyboard + gamepad input
- Reads `C_InputComponent` for movement

**Required Changes:**

**NONE!** S_InputSystem already reads from `C_InputComponent`. Since S_TouchscreenSystem writes to the same component, the integration is automatic.

**Verification:**
```gdscript
# In S_InputSystem.process_tick()
var final_movement := keyboard_vector

# Gamepad input
if active_device_type == DeviceType.GAMEPAD:
	final_movement = _gamepad_left_stick

# Touchscreen input (NEW - automatic!)
# S_TouchscreenSystem already updated C_InputComponent.move_vector
# S_InputSystem reads it naturally through the component query

# No code changes needed!
```

**Alternative Approach (if needed):**
If we want explicit touchscreen handling:
```gdscript
elif active_device_type == DeviceType.TOUCHSCREEN:
	# Read from component (already updated by S_TouchscreenSystem)
	final_movement = input_component.get_move_vector()
```

But this is **NOT NECESSARY** since the component is already updated!

---

## 2. COMPONENT-TO-PATTERN MAPPING

### 2.1 VirtualJoystick → ButtonPrompt + PrototypeTouch Pattern

**Reference Implementations:**
- `scripts/ui/button_prompt.gd` (UI component pattern)
- `scripts/prototypes/prototype_touch.gd` (touch handling logic)

**VirtualJoystick Structure:**
```gdscript
@icon("res://resources/editor_icons/utility.svg")
extends Control
class_name VirtualJoystick

signal joystick_moved(vector: Vector2)
signal joystick_released()

@export var joystick_radius: float = 120.0
@export var deadzone: float = 0.15
@export var base_texture: Texture2D
@export var thumb_texture: Texture2D
@export var can_reposition: bool = false  # Enable drag-to-reposition mode

# Internal state
var _touch_id: int = -1
var _touch_start_position: Vector2 = Vector2.ZERO
var _current_vector: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _is_repositioning: bool = false

func _ready() -> void:
	# Load textures from Kenney.nl assets
	if base_texture == null:
		base_texture = load("res://resources/button_prompts/stick_base.png")
	if thumb_texture == null:
		thumb_texture = load("res://resources/button_prompts/stick_thumb.png")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Check if touch is within joystick area
		if _is_touch_inside(event.position):
			_touch_id = event.index
			_touch_start_position = event.position
			_is_active = true
	else:
		# Touch released
		if event.index == _touch_id:
			_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return

	if _is_repositioning:
		# Update joystick position and save to Redux
		position = event.position - size / 2
		_save_position()
	else:
		# Update joystick vector
		var offset := event.position - _touch_start_position
		_current_vector = _calculate_joystick_vector(offset)
		joystick_moved.emit(_current_vector)
		queue_redraw()

func _calculate_joystick_vector(offset: Vector2) -> Vector2:
	# Clamp to radius
	var clamped := offset.limit_length(joystick_radius)
	# Normalize to -1..1 range
	var normalized := clamped / joystick_radius
	# Apply deadzone
	return RS_TouchscreenSettings.apply_touch_deadzone(normalized, deadzone)

func _release() -> void:
	_touch_id = -1
	_current_vector = Vector2.ZERO
	_is_active = false
	joystick_released.emit()
	queue_redraw()

func _is_touch_inside(touch_position: Vector2) -> bool:
	var local_pos := touch_position - global_position
	return local_pos.length() <= joystick_radius

func get_vector() -> Vector2:
	return _current_vector

func is_active() -> bool:
	return _is_active

func _save_position() -> void:
	var store := U_StateUtils.get_store(self)
	if store:
		store.dispatch(U_InputActions.save_virtual_control_position("virtual_joystick", position))
```

**Key Patterns:**
- ✅ Extends `Control` (UI component)
- ✅ Processes input in `_input()` (low latency)
- ✅ Tracks touch ID (multi-touch safe)
- ✅ Emits signals for state changes
- ✅ Applies deadzone via `RS_TouchscreenSettings.apply_touch_deadzone()`
- ✅ Supports drag-to-reposition with Redux save

### 2.2 VirtualButton → VirtualJoystick Pattern

**Similar Structure:**
```gdscript
@icon("res://resources/editor_icons/utility.svg")
extends Control
class_name VirtualButton

signal button_pressed(action: StringName)
signal button_released(action: StringName)

@export var action: StringName = StringName("jump")
@export var button_texture: Texture2D
@export var button_icon: Texture2D
@export var can_reposition: bool = false

var _touch_id: int = -1
var _is_pressed: bool = false
var _is_repositioning: bool = false

func _ready() -> void:
	# Load textures from Kenney.nl assets
	if button_texture == null:
		button_texture = load("res://resources/button_prompts/button_background.png")
	if button_icon == null:
		# Load action-specific icon (jump = button_south, sprint = button_east, etc.)
		button_icon = _load_action_icon()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_touch_inside(event.position):
			_touch_id = event.index
			_on_press()
	else:
		if event.index == _touch_id:
			_on_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return

	if _is_repositioning:
		position = event.position - size / 2
		_save_position()
	else:
		# Drag-out behavior: release if finger slides off button
		if not _is_touch_inside(event.position):
			_on_release()

func _on_press() -> void:
	_is_pressed = true
	button_pressed.emit(action)
	queue_redraw()

func _on_release() -> void:
	_touch_id = -1
	_is_pressed = false
	button_released.emit(action)
	queue_redraw()

func is_pressed() -> bool:
	return _is_pressed

func _save_position() -> void:
	var store := U_StateUtils.get_store(self)
	if store:
		store.dispatch(U_InputActions.save_virtual_control_position(action, position))
```

**Key Differences from VirtualJoystick:**
- Discrete press/release (not analog)
- Drag-out behavior (release if finger slides off)
- Action-specific icon loading

### 2.3 S_TouchscreenSystem → S_GamepadVibrationSystem Pattern

**Reference:** `scripts/ecs/systems/s_gamepad_vibration_system.gd`

**Similarities:**
- Extends `BaseECSSystem`
- Subscribes to state store
- Caches UI/component references
- Reacts to device changes

**Key Difference:**
- **S_GamepadVibrationSystem:** Triggers output (vibration)
- **S_TouchscreenSystem:** Reads input (touches) and updates components

**Implementation:** See Section 1.3 for full structure.

### 2.4 RS_TouchscreenSettings → RS_GamepadSettings Pattern

**Reference:** `scripts/input/resources/rs_gamepad_settings.gd`

**Structure:**
```gdscript
@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_TouchscreenSettings

@export_range(0.5, 2.0, 0.1) var virtual_joystick_size: float = 1.0
@export_range(0.3, 1.0, 0.05) var virtual_joystick_opacity: float = 0.7
@export_range(0.0, 0.5, 0.05) var joystick_deadzone: float = 0.15
@export var joystick_radius: float = 120.0

@export_range(0.5, 2.0, 0.1) var button_size: float = 1.0
@export_range(0.3, 1.0, 0.05) var button_opacity: float = 0.8

# Default positions (can be overridden by Redux state)
@export var default_joystick_position: Vector2 = Vector2(120, 520)
@export var default_button_positions: Dictionary = {
	"jump": Vector2(920, 520),
	"sprint": Vector2(820, 480)
}

# Static helper method (like RS_GamepadSettings.apply_deadzone)
static func apply_touch_deadzone(touch_vector: Vector2, deadzone: float) -> Vector2:
	if touch_vector.length() < deadzone:
		return Vector2.ZERO

	# Rescale to 0..1 range after deadzone
	var rescaled := (touch_vector.length() - deadzone) / (1.0 - deadzone)
	return touch_vector.normalized() * clampf(rescaled, 0.0, 1.0)
```

**Patterns Followed:**
- ✅ Extends `Resource`
- ✅ Uses `@export` for editor configuration
- ✅ Static helper methods for shared logic
- ✅ Default `.tres` file in `resources/input/touchscreen_settings/`

---

## 3. MISSING REQUIREMENTS ADDRESSED

### 3.1 Virtual Control Positioning

**User Decision:** Draggable (global)

**Implementation:**
- Custom positions saved in `settings.input_settings.touchscreen_settings`
- `custom_joystick_position: Vector2(-1, -1)` = use profile default
- `custom_button_positions: Dictionary` = override profile defaults
- Drag-to-reposition mode enabled via `can_reposition: bool` export
- Position saved to Redux on drag end via `U_InputActions.save_virtual_control_position()`

**Reset to Defaults:**
- Load `default_touchscreen.tres` profile
- Apply metadata positions to Redux
- Same pattern as keyboard/gamepad reset

### 3.2 Virtual Control Visibility Rules

**User Decisions (Finalized 2025-11-16):**
- ✅ Hide during scene transitions (cleaner visual)
- ✅ Hide during pause menu
- ✅ Dynamic opacity fade (30% after 2s idle, full on touch)
- ✅ Auto-hide when gamepad OR keyboard connected

**Implementation:**
```gdscript
# MobileControls visibility logic
func _update_visibility() -> void:
	var device_is_touchscreen := _device_manager.get_active_device_type() == DeviceType.TOUCHSCREEN
	var in_pause := _scene_manager != null and _scene_manager.is_overlay_active(StringName("pause_menu"))
	var is_transitioning := _scene_manager != null and _scene_manager.is_transitioning()

	# Hidden during transitions (user decision: cleaner visual)
	visible = device_is_touchscreen and not in_pause and not is_transitioning

# MobileControls opacity fade logic using Tween (User Decision: GPU-accelerated)
var _idle_tween: Tween = null
const FADE_DELAY: float = 2.0  # Fade after 2 seconds of no input
const IDLE_OPACITY: float = 0.3  # 30% opacity when idle
const ACTIVE_OPACITY: float = 1.0  # Full opacity when active

func _on_input_activity() -> void:
	# Called when joystick/button receives input
	# Kill existing tween if active
	if _idle_tween and _idle_tween.is_running():
		_idle_tween.kill()

	# Restore to full opacity immediately
	modulate.a = ACTIVE_OPACITY

	# Start new fade tween after delay
	_idle_tween = create_tween()
	_idle_tween.tween_interval(FADE_DELAY)  # Wait 2 seconds
	_idle_tween.tween_property(self, "modulate:a", IDLE_OPACITY, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# VirtualJoystick and VirtualButton emit signals on input:
# joystick.joystick_moved.connect(_on_input_activity)
# button.button_pressed.connect(_on_input_activity)
```

**Benefits of Tween Approach:**
- ✅ GPU-accelerated (property animation runs in Godot's render thread)
- ✅ No _process() overhead (no per-frame checks)
- ✅ Better mobile battery life (fewer CPU cycles)
- ✅ Smoother animation (Godot interpolates at display refresh rate)
- ✅ Easy to customize easing (TRANS_CUBIC, EASE_OUT for natural feel)

**Clarifications:**
- ✅ Scene transitions: HIDDEN (user decision changed from "gray out" to "hidden")
- ✅ Pause menu: HIDDEN completely
- ✅ Other overlays: Remain visible (except pause)
- ✅ Gamepad connect: Auto-hide (device switches to GAMEPAD)
- ✅ Keyboard connect: Auto-hide (device switches to KEYBOARD_MOUSE)
- ✅ Idle fade: 30% opacity after 2 seconds, full opacity on touch

### 3.3 Hybrid Input Handling

**User Decision:** Auto-hide (like gamepad detection)

**Implementation:**
- Virtual controls auto-hide when gamepad or keyboard detected
- Device manager already handles device switching
- Virtual controls subscribe to `device_changed` signal
- No explicit input blending logic needed (S_InputSystem handles it)

**Clarifications:**
- ✅ Bluetooth keyboard + touchscreen: Controls hide on keyboard input
- ✅ Bluetooth gamepad + touchscreen: Controls hide on gamepad input
- ✅ Touch re-activates: Controls reappear when screen touched

### 3.4 Multi-Touch Handling

**Pattern from PrototypeTouch:**
```gdscript
# First touch to joystick area
if _joystick_touch_id == -1 and _is_within_joystick(position):
	_assign_joystick_touch(touch_id, position)
	return

# Subsequent touches to buttons
for button_name in _button_regions.keys():
	var region: Rect2 = _button_regions[button_name]
	if region.has_point(position):
		_button_touch_ids[touch_id] = button_name
		_button_states[button_name] = true
		return
```

**Implementation:**
- VirtualJoystick tracks `_touch_id: int` (first touch only)
- VirtualButton tracks `_touch_id: int` (independent)
- Each component ignores touches with different IDs
- Multi-touch safe: Can press joystick + jump simultaneously

### 3.5 Screen Rotation Handling

**User Decision:** Lock to landscape

**Implementation:**
- Set in `project.godot`:
  ```
  [display]
  window/handheld/orientation="landscape"
  ```
- No rotation handling code needed in Phase 6
- Defer rotation support to Phase 7 (if requested)

### 3.6 Performance Considerations

**Target:** Input latency < 16ms (one frame @ 60 FPS), 60 FPS sustained

**Strategy:**
- VirtualJoystick/VirtualButton process input in `_input()` (immediate)
- S_TouchscreenSystem reads component state in `process_tick()` (1 frame lag acceptable)
- No performance issues expected (prototype validated < 16ms)

**Optimizations (User Decisions):**
1. **Tween for Opacity Fade** (GPU-Accelerated)
   - Using `create_tween()` instead of `_process()` checks
   - Property animations run in render thread (no CPU overhead)
   - Better mobile battery life
   - Smoother interpolation at display refresh rate

2. **Device Type Check** (Prevent Unnecessary Processing)
   - S_TouchscreenSystem checks active device type before processing
   - Early return if not TOUCHSCREEN device
   - Prevents wasted CPU cycles when gamepad/keyboard active

3. **Multi-Touch Capacity** (32 Touch Points Max)
   - Godot supports up to 32 simultaneous touches
   - Phase 6 design uses maximum 5 touches (1 joystick + 4 buttons)
   - VirtualJoystick/Button ignore non-assigned touch IDs (safe overflow handling)
   - Edge case: Palm resting on screen (5+ touches) won't cause issues

**Alternative (if lag becomes issue):**
- VirtualJoystick updates `C_InputComponent` directly in `_input()`
- Bypasses system entirely for lowest latency
- Not needed for Phase 6 (< 16ms validated)

### 3.7 Testing Strategy

**User Decision:** Physical device primary; desktop emulation as fallback + unit tests

**Implementation:**

**Desktop Emulation Mode (fallback):**
```gdscript
# MobileControls._ready()
func _is_emulate_mode() -> bool:
	# Phase 6: Command-line flag ONLY
	return OS.has_cmdline_arg("--emulate-mobile")

	# Phase 7 (DEFERRED): Add runtime debug setting toggle
	# var store := U_StateUtils.get_store(self)
	# if store:
	#     var debug_settings: Dictionary = store.get_state().get("debug", {})
	#     return debug_settings.get("emulate_mobile_mode", false)
```

**Usage (optional smoke only):**
- Run game with: `/Applications/Godot.app/Contents/MacOS/Godot --emulate-mobile`
- Enable "Emulate Touch from Mouse" in Godot project settings
- Virtual controls will instantiate on desktop for testing

**Unit Test Pattern:**
```gdscript
# tests/unit/ui/test_virtual_joystick.gd
func test_touch_input_updates_vector():
	var joystick := VirtualJoystick.new()
	add_child_autofree(joystick)

	# Simulate touch press
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = joystick.global_position + Vector2(50, 0)
	touch_press.pressed = true
	Input.parse_input_event(touch_press)

	# Simulate drag
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = joystick.global_position + Vector2(80, 0)
	Input.parse_input_event(touch_drag)

	await get_tree().process_frame

	assert_true(joystick.is_active(), "Joystick should be active")
	assert_gt(joystick.get_vector().x, 0.0, "Joystick should have rightward vector")
```

**Project Setting:**
- Enable "Emulate Touch from Mouse" in project settings for manual testing

### 3.8 Asset Requirements

**User Decision:** Kenney.nl Mobile pack

**Required Assets (Task 6.0.5):**
- Download Kenney Input Prompts - Mobile pack (free, CC0) from kenney.nl
- Extract and import to `resources/button_prompts/mobile/`:
  - `joystick_base.png` (joystick base circle)
  - `joystick_thumb.png` (joystick thumb circle)
  - `button_background.png` (virtual button background)
- Add `LICENSE_Kenney_Mobile.txt` to resources folder
- Configure import settings: 64x64 PNG, mipmaps disabled, filter enabled
- Reuse existing button prompt assets for action icons (button_south, button_east, etc.)

**Fallback:**
- If assets missing, use colored circles as placeholders
- VirtualJoystick/VirtualButton handle `null` textures gracefully

### 3.9 Settings Overlay UI (Gap Fill)

**User Decision:** Full touchscreen settings overlay

**Implementation (Task 6.10):**
- Create `TouchscreenSettingsOverlay` (similar to `GamepadSettingsOverlay`)
- Sliders:
  - Joystick Size (0.5-2.0)
  - Button Size (0.5-2.0)
  - Joystick Opacity (0.3-1.0)
  - Button Opacity (0.3-1.0)
  - Joystick Deadzone (0.0-0.5)
- Live preview: VirtualJoystick + VirtualButton visualization (updates in real-time on slider change)
- Buttons: Apply (dispatch to Redux), Cancel (discard changes), Reset to Defaults (call profile manager)
- Wire to Scene Registry (`touchscreen_settings`) and Pause Menu ("Touchscreen Settings" button)

**Pattern Reference:**
- Follow `GamepadSettingsOverlay` pattern exactly
- Subscribe to state store for current settings
- Preview updates on slider value_changed signals
- Apply button dispatches `update_touchscreen_settings` actions

### 3.10 Edit Layout Overlay UI (Gap Fill)

**User Decision:** Edit Touch Controls overlay for drag mode

**Implementation (Task 6.11):**
- Create `EditTouchControlsOverlay`
- Toggle drag mode: Enable/disable `can_reposition` on VirtualJoystick/VirtualButton
- Visual feedback:
  - Semi-transparent grid overlay (snap-to-grid guides)
  - Instructions label: "Drag controls to reposition. Tap 'Save' when done."
- Buttons:
  - Save Positions (dispatch positions to Redux, close overlay)
  - Reset to Defaults (call `M_InputProfileManager.reset_touchscreen_positions()`)
  - Cancel (revert positions, close overlay without saving)
- Wire to TouchscreenSettingsOverlay ("Edit Layout" button)
- Register in Scene Registry (`edit_touch_controls`)

**Integration:**
- Communicate with MobileControls via direct reference (`get_tree().get_first_node_in_group("mobile_controls")`)
- Toggle `can_reposition` property on all virtual controls
- Listen for position changes, store temporarily, commit on Save

### 3.11 HUD Safe Area Margins (Gap Fill)

**User Decision:** Add safe margins to avoid overlap

**Implementation (Task 6.12):**
```gdscript
# In HUD_Controller
func _calculate_safe_margins() -> Dictionary:
	if not OS.has_feature("mobile") and not _is_emulate_mode():
		return {"bottom": 0, "left": 0, "right": 0, "top": 0}

	return {
		"bottom": 150,  # Virtual controls at bottom
		"left": 200,    # Virtual joystick on left
		"right": 200,   # Virtual buttons on right
		"top": 0        # No top margin needed
	}

func _apply_safe_margins(margins: Dictionary) -> void:
	# Apply margins to all HUD children with safe_margin_aware metadata
	for child in get_children():
		if not child.has_meta("safe_margin_aware"):
			continue

		var margin_edges: Array = child.get_meta("safe_margin_edges", [])
		var offset := Vector2.ZERO

		if "left" in margin_edges:
			offset.x += margins.left
		if "right" in margin_edges:
			offset.x -= margins.right
		if "bottom" in margin_edges:
			offset.y -= margins.bottom
		if "top" in margin_edges:
			offset.y += margins.top

		child.position += offset
```

**Metadata Pattern for HUD Elements:**
```gdscript
# In health_bar.tscn (or via script in _ready)
set_meta("safe_margin_aware", true)
set_meta("safe_margin_edges", ["left"])  # Health bar avoids left joystick overlap

# In checkpoint_toast.tscn
set_meta("safe_margin_aware", true)
set_meta("safe_margin_edges", ["bottom"])  # Toast avoids bottom button overlap

# In interact_prompt.tscn
set_meta("safe_margin_aware", true)
set_meta("safe_margin_edges", ["bottom"])  # Prompt avoids bottom overlap
```

**Benefits:**
- Extensible: New HUD elements declare their own margin needs via metadata
- No hardcoded element references in HUD_Controller
- Easy to add/remove margin-aware elements without code changes

### 3.12 Save File Migration (Gap Fill)

**User Decision:** Explicit migration test

**Implementation (Task 6.13):**
```gdscript
# tests/unit/integration/test_touchscreen_settings_migration.gd
func test_phase5_to_phase6_migration():
	# Simulate Phase 5 save (no touchscreen_settings)
	var phase5_save := {
		"settings": {
			"input_settings": {
				"gamepad_settings": {...},
				# NO touchscreen_settings
			}
		}
	}

	# Load via M_StateStore
	store.load_state(phase5_save)

	# Verify reducer populated defaults
	var ts_settings := U_InputSelectors.get_touchscreen_settings(store.get_state())
	assert_eq(ts_settings.custom_joystick_position, Vector2(-1, -1))
	assert_eq(ts_settings.custom_button_positions, {})
	assert_eq(ts_settings.virtual_joystick_size, 1.0)
	assert_eq(ts_settings.joystick_opacity, 0.7)
```

**Validation:**
- Test reducer `.get("field", default)` pattern handles missing fields
- Test save roundtrip: Load Phase 5 → Add positions → Save → Load → Verify persistence
- Test backward compatibility: Phase 6 saves can load in Phase 5 (gracefully ignore new fields)

### 3.13 Performance Testing (Gap Fill)

**User Decision:** Automated performance test

**Implementation (Task 6.14):**
```gdscript
# tests/unit/integration/test_touchscreen_performance.gd
func test_60fps_sustained_input():
	# Simulate heavy input load
	for frame in range(60):
		var start_time := Time.get_ticks_usec()

		# Simulate joystick drag
		var drag_event := InputEventScreenDrag.new()
		drag_event.index = 0
		drag_event.position = Vector2(100 + frame, 500)
		Input.parse_input_event(drag_event)

		# Simulate button presses (2 simultaneous)
		_press_virtual_button("jump")
		_press_virtual_button("sprint")

		# Process system tick
		touchscreen_system.process_tick(0.016667)

		var end_time := Time.get_ticks_usec()
		var frame_time_ms := (end_time - start_time) / 1000.0

		frame_times.append(frame_time_ms)

	# Assert performance targets
	var avg_frame_time := _calculate_average(frame_times)
	assert_lt(avg_frame_time, 16.67, "Average frame time must be < 16.67ms")

	var max_frame_time := frame_times.max()
	assert_lt(max_frame_time, 20.0, "No frame should exceed 20ms")
```

**Metrics Tracked:**
- Average frame time across 60 frames (target: < 16.67ms)
- Maximum frame time (regression threshold: < 20ms)
- Minimum frame time (for debugging)
- Log stats to console for performance analysis

### 3.14 Emergency Rollback (User Decision)

**Problem:** What if Phase 6 ships with a critical bug on mobile that can't be immediately fixed?

**Solution:** Add `debug.disable_touchscreen` flag for emergency disable

**Implementation (Task 6.6.4):**

**Redux Debug Slice Extension:**
```gdscript
# scripts/state/reducers/u_debug_reducer.gd (or extend if doesn't exist)
func _get_default_state() -> Dictionary:
	return {
		"disable_touchscreen": false,  # Emergency killswitch
		# ... other debug flags
	}
```

**S_TouchscreenSystem Check:**
```gdscript
func process_tick(_delta: float) -> void:
	# Check emergency disable flag FIRST
	var debug_settings := U_DebugSelectors.get_debug_settings(_state_store.get_state())
	if debug_settings.get("disable_touchscreen", false):
		return  # Emergency disable active - skip all touchscreen processing

	# ... rest of touchscreen processing
```

**Debug Action:**
```gdscript
# scripts/state/actions/u_debug_actions.gd
const ACTION_SET_DISABLE_TOUCHSCREEN := StringName("debug/set_disable_touchscreen")

static func set_disable_touchscreen(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_TOUCHSCREEN,
		"payload": {"enabled": enabled},
		"immediate": true  # Flush to disk immediately
	}
```

**Usage:**
1. **Via Debug Console** (if available):
   ```gdscript
   store.dispatch(U_DebugActions.set_disable_touchscreen(true))
   ```

2. **Via Settings File** (emergency hotfix):
   - User edits `user://input_settings.json`
   - Add: `"debug": {"disable_touchscreen": true}`
   - Game loads setting on next launch

3. **Via Remote Config** (if implemented in Phase 7):
   - Server sends config update
   - Game applies without code change

**Benefits:**
- ✅ Immediate disable without code redeploy
- ✅ Per-user control (user can disable locally)
- ✅ Server-side control possible (if remote config added)
- ✅ Visible continues to work (just system disabled, not UI)
- ✅ Easy to re-enable when fix deployed

**Note:** This is a SAFETY NET, not a substitute for proper testing. Primary coverage now comes from the physical device pass; desktop emulation + unit tests remain fallback guards.

---

## 4. ARCHITECTURE DECISIONS SUMMARY

### 4.1 State Management

**Redux Integration:**
- Extend `settings.input_settings.touchscreen_settings` with position data
- Add actions: `update_touchscreen_settings()`, `save_virtual_control_position()`
- Add selectors: `get_touchscreen_settings()`, `get_virtual_control_position()`
- Persistence: Settings saved to `user://input_settings.json` (existing mechanism)

**Transient State:**
- NO touchscreen-specific transient state needed
- Reuse existing `move_input`, `look_input` fields in `gameplay.input`
- Touch tracking (active touch IDs) stays internal to VirtualJoystick/VirtualButton

### 4.2 Component Architecture

**VirtualJoystick:**
- Extends `Control`
- Processes input in `_input()` (low latency)
- Tracks touch ID (multi-touch safe)
- Emits signals: `joystick_moved(vector)`, `joystick_released()`
- Supports drag-to-reposition with Redux save

**VirtualButton:**
- Extends `Control`
- Similar to VirtualJoystick but discrete press/release
- Emits signals: `button_pressed(action)`, `button_released(action)`
- Supports drag-out behavior (release on finger slide-off)

**MobileControls:**
- Extends `CanvasLayer`
- Conditional instantiation (mobile or emulation mode)
- Manages visibility based on device type and overlay stack
- Loads saved positions from Redux on startup

### 4.3 System Architecture

**S_TouchscreenSystem:**
- Extends `BaseECSSystem`
- Queries existing `C_InputComponent` (NO new component!)
- Caches VirtualJoystick/VirtualButton references
- Reads virtual control state, updates component in `process_tick()`
- Only processes on mobile or emulation mode

**Integration with S_InputSystem:**
- NO changes needed to S_InputSystem
- S_TouchscreenSystem writes to `C_InputComponent`
- S_InputSystem reads from `C_InputComponent`
- Automatic integration!

### 4.4 Profile Architecture

**Default Touchscreen Profile:**
```gdscript
# resources/input/profiles/default_touchscreen.tres
profile_name: "Default (Touchscreen)"
profile_type: "touchscreen"
device_type: DeviceType.TOUCHSCREEN
action_mappings: {}  # Not used for touchscreen

metadata: {
	"virtual_joystick_position": Vector2(120, 520),
	"virtual_button_positions": {
		"jump": Vector2(920, 520),
		"sprint": Vector2(820, 480)
	},
	"joystick_size": 1.0,
	"joystick_opacity": 0.7,
	"joystick_deadzone": 0.15,
	"button_size": 1.0,
	"button_opacity": 0.8
}
```

**Reset Mechanism:**
- `M_InputProfileManager.reset_touchscreen_positions()`
- Loads default profile metadata
- Dispatches position updates to Redux
- Same pattern as keyboard/gamepad reset

### 4.5 Testing Architecture

**Desktop Emulation:**
- Command-line flag: `--emulate-mobile`
- Debug setting: `debug.emulate_mobile_mode`
- MobileControls instantiates if mobile OR emulation mode
- Project setting: "Emulate Touch from Mouse" enabled

**Unit Tests:**
- Simulate touch events via `Input.parse_input_event()`
- Test VirtualJoystick vector calculation
- Test VirtualButton press/release
- Test multi-touch handling (joystick + button simultaneously)

**Integration Tests:**
- Test S_TouchscreenSystem updates `C_InputComponent`
- Test device detection triggers visibility changes
- Test pause menu hides virtual controls
- Test position persistence (save/load)

---

## 5. RISKS AND MITIGATIONS

### 5.1 High Risk: Multi-Touch Tracking

**Risk:** Touch ID conflicts, simultaneous joystick + button presses fail

**Mitigation:**
- Follow PrototypeTouch pattern (proven in Phase 0)
- Each component tracks independent touch ID
- First touch to joystick area, subsequent to buttons
- Unit tests for multi-touch scenarios

### 5.2 Medium Risk: Desktop Emulation Fidelity

**Risk:** Desktop emulation doesn't match real mobile behavior

**Mitigation:**
- Prefer on-device validation on the available handset for every release
- Keep DEV_PITFALLS.md notes on emulation limitations for fallback use
- Treat `--emulate-mobile` as smoke-only between device runs

### 5.3 Medium Risk: Input Latency

**Risk:** 1-frame lag between touch and component update

**Mitigation:**
- Prototype validated < 16ms latency
- VirtualJoystick processes in `_input()` (immediate)
- If needed: Direct component update in `_input()` (bypasses system)

### 5.4 Low Risk: State Synchronization

**Risk:** Position save/load desync

**Mitigation:**
- Immediate dispatch on position change
- Reducer handles merge correctly
- Integration tests verify roundtrip

### 5.5 Low Risk: Visibility Logic

**Risk:** Virtual controls show/hide incorrectly

**Mitigation:**
- Clear visibility rules documented
- Subscribe to device_changed signal (reliable)
- Subscribe to overlay stack signals (reliable)
- Unit tests for each visibility scenario

### 5.6 Medium Risk: Device Switching Race Condition (NEW - 2025-11-16)

**Risk:** MobileControls.visible updates on signal, but S_TouchscreenSystem processes in process_tick (1 frame lag). Touchscreen input could bleed into gamepad frame after device switch.

**Mitigation:**
- S_TouchscreenSystem checks active device type BEFORE processing (Task 6.6.2)
- Early return if `device_type != TOUCHSCREEN`
- Integration test validates no input ghosting (Task 6.8.1)
- Pattern documented in architecture and tasks

### 5.7 Low Risk: Vector2 Serialization Complexity (NEW - 2025-11-16)

**Risk:** Vector2 → {x, y} dict conversion could fail silently, corrupting position data

**Mitigation:**
- Hybrid approach: Vector2 in memory, dict on disk (clear separation)
- U_InputSerialization handles conversion in ONE place (Task 6.2.8)
- Migration test validates Vector2 deserialization (Task 6.8.1)
- Integration test verifies save/load roundtrip

### 5.8 Low Risk: Multi-Touch Capacity Overflow (NEW - 2025-11-16)

**Risk:** Edge case if user rests palm on screen (5+ simultaneous touches), could overwhelm system

**Mitigation:**
- Godot supports 32 touch points (far exceeds Phase 6 design: 5 max)
- VirtualJoystick/Button ignore touches with non-assigned IDs
- Each component tracks independent touch ID (no conflicts)
- Multi-touch safe by design (proven in PrototypeTouch)
- Low probability (requires unusual user behavior)

---

## 6. SUCCESS CRITERIA

**Before Implementation:**
- [x] All clarifying questions answered
- [x] User decisions documented
- [x] Architecture patterns mapped to existing systems
- [x] Integration points identified

**After Implementation:**
- [ ] FR-046 through FR-056 implemented
- [ ] Default touchscreen profile created
- [ ] Virtual controls visible only on mobile or emulation mode
- [ ] VirtualJoystick updates `C_InputComponent` movement
- [ ] VirtualButton triggers jump/sprint actions
- [ ] Auto-hide when gamepad/keyboard detected
- [ ] Hide during pause menu, visible during transitions
- [ ] Draggable positioning with Redux persistence
- [ ] Reset to defaults button functional
- [ ] Physical device QA pass (baseline joystick/buttons/hide/reposition)
- [ ] Desktop emulation fallback working (smoke only)
- [ ] All unit tests passing (90%+ coverage)
- [ ] All integration tests passing
- [ ] No regressions in existing tests
- [ ] Touch input latency < 16ms validated

---

## 7. NEXT STEPS

1. **Update input-manager-tasks.md** with expanded Phase 6 tasks
2. **Update input-manager-plan.md** with implementation specification
3. **Update input-manager-prd.md** with clarified requirements
4. **Create default_touchscreen.tres** profile resource
5. **Begin implementation** (Task 6.0: Profile, then 6.1: Settings Resource)

---

## APPENDIX A: File Structure

### New Files to Create

**Resources:**
- `resources/input/profiles/default_touchscreen.tres` (touchscreen profile with metadata-driven buttons)
- `resources/input/touchscreen_settings/default_touchscreen_settings.tres` (settings resource)
- `resources/button_prompts/mobile/joystick_base.png` (Kenney.nl asset)
- `resources/button_prompts/mobile/joystick_thumb.png` (Kenney.nl asset)
- `resources/button_prompts/mobile/button_background.png` (Kenney.nl asset)
- `resources/button_prompts/mobile/LICENSE_Kenney_Mobile.txt` (CC0 license)

**Scripts:**
- `scripts/input/resources/rs_touchscreen_settings.gd` (settings resource)
- `scripts/ecs/systems/s_touchscreen_system.gd` (ECS system)
- `scripts/ui/virtual_joystick.gd` (joystick component)
- `scripts/ui/virtual_button.gd` (button component)
- `scripts/ui/mobile_controls.gd` (container layer with metadata-driven button instantiation)
- `scripts/ui/touchscreen_settings_overlay.gd` (settings UI - Gap Fill)
- `scripts/ui/edit_touch_controls_overlay.gd` (layout editor UI - Gap Fill)

**Scenes:**
- `scenes/ui/virtual_joystick.tscn` (joystick scene)
- `scenes/ui/virtual_button.tscn` (button scene)
- `scenes/ui/mobile_controls.tscn` (container scene)
- `scenes/ui/touchscreen_settings_overlay.tscn` (settings overlay - Gap Fill)
- `scenes/ui/edit_touch_controls_overlay.tscn` (layout editor overlay - Gap Fill)

**Tests:**
- `tests/unit/resources/test_rs_touchscreen_settings.gd`
- `tests/unit/ecs/systems/test_s_touchscreen_system.gd`
- `tests/unit/ui/test_virtual_joystick.gd`
- `tests/unit/ui/test_virtual_button.gd`
- `tests/unit/ui/test_mobile_controls.gd`
- `tests/unit/ui/test_touchscreen_settings_overlay.gd` (Gap Fill)
- `tests/unit/ui/test_edit_touch_controls_overlay.gd` (Gap Fill)
- `tests/unit/ui/test_hud_safe_margins.gd` (Gap Fill)
- `tests/unit/integration/test_touchscreen_input_flow.gd`
- `tests/unit/integration/test_touchscreen_settings_migration.gd` (Gap Fill)
- `tests/unit/integration/test_touchscreen_performance.gd` (Gap Fill)

### Files to Modify

**State Management:**
- `scripts/state/actions/u_input_actions.gd` (add touchscreen actions)
- `scripts/state/reducers/u_input_reducer.gd` (add touchscreen reducer cases)
- `scripts/state/selectors/u_input_selectors.gd` (add touchscreen selectors)

**Managers:**
- `scripts/managers/m_input_profile_manager.gd` (add touchscreen profile methods, reset positions)

**UI:**
- `scripts/ui/hud_controller.gd` (add safe area margin calculation and application - Gap Fill)

**Root Scene:**
- `scenes/root.tscn` (add MobileControls CanvasLayer)

**Documentation:**
- `AGENTS.md` (add touchscreen patterns after Phase 6 completion)
- `docs/general/DEV_PITFALLS.md` (add desktop emulation notes)

**Total New Files:** +27 (was ~45, now ~56 including gap-fill additions)

---

**Document Status:** ✅ Complete - Ready for Task Breakdown
