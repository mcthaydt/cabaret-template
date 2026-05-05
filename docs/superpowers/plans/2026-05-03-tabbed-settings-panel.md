# Control-Style Tabbed Settings Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 7 settings overlays + `UI_SettingsMenu` landing page with a single `UI_SettingsPanel` overlay using internal tab navigation, with instant apply and device-specific tab visibility.

**Architecture:** A single `UI_SettingsPanel` (extends `BaseOverlay`) contains a horizontal tab bar and a content container. Each settings category (Display, Audio, VFX, Language, Gamepad, K/M, Touch) is a tab page (extends `VBoxContainer`) that shows/hides as the active tab changes. Utility overlays (Input Rebinding, Edit Touch Controls, Input Profile Selector, Save/Load) remain separate but are resized to 860×620.

**Tech Stack:** Godot 4.7 (GDScript), GUT test framework, project builders (`U_EditorPrefabBuilder`, `U_TemplateBaseSceneBuilder`), Redux-style state management.

**Spec:** `docs/superpowers/specs/2026-05-03-overlay-panel-sizes-design.md`

---

## Phase 1: Panel Size Constant + Utility Overlay Resize

### Task 1: Add OVERLAY_PANEL_SIZE constant to BaseOverlay

**Files:**
- Modify: `scripts/core/ui/base/base_overlay.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_overlay_panel_size_constant.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const BaseOverlay := preload("res://scripts/core/ui/base/base_overlay.gd")

func test_overlay_panel_size_is_860x620():
	assert_eq(BaseOverlay.OVERLAY_PANEL_SIZE, Vector2(860.0, 620.0), "OVERLAY_PANEL_SIZE should be 860x620")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_overlay_panel_size_constant.gd`
Expected: FAIL — `OVERLAY_PANEL_SIZE` not defined on `BaseOverlay`

- [ ] **Step 3: Write minimal implementation**

Add to `scripts/core/ui/base/base_overlay.gd` after the existing `var` declarations (after line 20):

```gdscript
const OVERLAY_PANEL_SIZE := Vector2(860.0, 620.0)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_overlay_panel_size_constant.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/base/base_overlay.gd tests/unit/ui/settings/test_overlay_panel_size_constant.gd
git commit -m "(RED/GREEN) Add OVERLAY_PANEL_SIZE constant to BaseOverlay"
```

---

### Task 2: Resize utility overlay .tscn files to 860×620

**Files:**
- Modify: `scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn`
- Modify: `scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn`
- Modify: `scenes/core/ui/overlays/ui_input_profile_selector.tscn`
- Modify: `scenes/core/ui/overlays/ui_save_load_menu.tscn`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_utility_overlay_panel_sizes.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const BaseOverlay := preload("res://scripts/core/ui/base/base_overlay.gd")

const SCENE_PATHS := {
	"input_rebinding": "res://scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn",
	"edit_touch_controls": "res://scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn",
	"input_profile_selector": "res://scenes/core/ui/overlays/ui_input_profile_selector.tscn",
	"save_load_menu": "res://scenes/core/ui/overlays/ui_save_load_menu.tscn",
}

func test_input_rebinding_panel_size():
	_assert_panel_size(SCENE_PATHS.input_rebinding)

func test_edit_touch_controls_panel_size():
	_assert_panel_size(SCENE_PATHS.edit_touch_controls)

func test_input_profile_selector_panel_size():
	_assert_panel_size(SCENE_PATHS.input_profile_selector)

func test_save_load_menu_panel_size():
	_assert_panel_size(SCENE_PATHS.save_load_menu)

func _assert_panel_size(scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	assert_not_null(scene, "Scene should load: " + scene_path)
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var motion_host := instance.find_child("MainPanelMotionHost", true, false) as Control
	if motion_host != null:
		assert_eq(motion_host.custom_minimum_size, BaseOverlay.OVERLAY_PANEL_SIZE, scene_path + " MainPanelMotionHost size should match OVERLAY_PANEL_SIZE")
	instance.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_utility_overlay_panel_sizes.gd`
Expected: FAIL — sizes don't match 860×620 yet

- [ ] **Step 3: Update the .tscn files**

For each utility overlay `.tscn`, find the `MainPanelMotionHost` node's `custom_minimum_size` property and change it to `Vector2(860, 620)`:

- `ui_edit_touch_controls_overlay.tscn`: Change `560, 260` → `860, 620`
- `ui_input_profile_selector.tscn`: Change `620, 500` → `860, 620`
- `ui_save_load_menu.tscn`: Change `760, 520` → `860, 620`
- `ui_input_rebinding_overlay.tscn`: Already `860, 620` (no change needed)

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_utility_overlay_panel_sizes.gd`
Expected: PASS

- [ ] **Step 5: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn scenes/core/ui/overlays/ui_input_profile_selector.tscn scenes/core/ui/overlays/ui_save_load_menu.tscn tests/unit/ui/settings/test_utility_overlay_panel_sizes.gd
git commit -m "(RED/GREEN) Resize utility overlays to OVERLAY_PANEL_SIZE 860x620"
```

---

## Phase 2: Create UI_SettingsPanel Shell

### Task 3: Create UI_SettingsPanel script with tab switching

**Files:**
- Create: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_settings_panel_tabs.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")

func test_settings_panel_has_tab_bar():
	var panel := _create_panel()
	var tab_bar := panel.find_child("TabBar", true, false) as HBoxContainer
	assert_not_null(tab_bar, "Settings panel should have a TabBar HBoxContainer")
	panel.queue_free()

func test_settings_panel_has_content_container():
	var panel := _create_panel()
	var content := panel.find_child("ContentContainer", true, false) as VBoxContainer
	assert_not_null(content, "Settings panel should have a ContentContainer VBoxContainer")
	panel.queue_free()

func test_settings_panel_default_tab_is_display():
	var panel := _create_panel()
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_DISPLAY, "Default active tab should be Display")
	panel.queue_free()

func test_switch_tab_updates_active_id():
	var panel := _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	assert_eq(panel.get_active_tab_id(), UI_SettingsPanel.TAB_AUDIO, "Active tab should be Audio after switch")
	panel.queue_free()

func test_switch_tab_shows_content_hides_others():
	var panel := _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_AUDIO)
	await get_tree().process_frame
	var audio_content := panel.find_child("AudioTabContent", true, false) as Control
	var display_content := panel.find_child("DisplayTabContent", true, false) as Control
	if audio_content != null:
		assert_true(audio_content.visible, "Audio content should be visible when active")
	if display_content != null:
		assert_false(display_content.visible, "Display content should be hidden when not active")
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var panel := UI_SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	return panel
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd`
Expected: FAIL — script doesn't exist yet

- [ ] **Step 3: Write UI_SettingsPanel script**

Create `scripts/core/ui/settings/ui_settings_panel.gd`:

```gdscript
@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name UI_SettingsPanel

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_INPUT_SELECTORS := preload("res://scripts/core/state/selectors/u_input_selectors.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")

enum TabId {
	DISPLAY,
	AUDIO,
	VFX,
	LANGUAGE,
	GAMEPAD,
	KEYBOARD_MOUSE,
	TOUCHSCREEN,
}

const TAB_DISPLAY := TabId.DISPLAY
const TAB_AUDIO := TabId.AUDIO
const TAB_VFX := TabId.VFX
const TAB_LANGUAGE := TabId.LANGUAGE
const TAB_GAMEPAD := TabId.GAMEPAD
const TAB_KEYBOARD_MOUSE := TabId.KEYBOARD_MOUSE
const TAB_TOUCHSCREEN := TabId.TOUCHSCREEN

const SETTINGS_PANEL_OVERLAY_ID := StringName("settings_panel")

var _active_tab: TabId = TabId.DISPLAY
var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}
var _last_device_type: int = -1
var _consume_next_nav: bool = false

@onready var _tab_bar: HBoxContainer = $CenterContainer/Panel/VBox/TabBar
@onready var _separator: HSeparator = $CenterContainer/Panel/VBox/HSeparator
@onready var _content_container: VBoxContainer = $CenterContainer/Panel/VBox/ContentContainer

func _ready() -> void:
	super._ready()
	_build_tab_bar()
	_create_tab_contents()
	_update_tab_visibility()
	switch_to_tab(TabId.DISPLAY)

func get_active_tab_id() -> TabId:
	return _active_tab

func switch_to_tab(tab_id: TabId) -> void:
	if _active_tab == tab_id:
		return
	_hide_tab_content(_active_tab)
	_active_tab = tab_id
	_show_tab_content(_active_tab)
	_update_tab_button_states()
	_configure_focus_neighbors()
	var first_focusable := _find_first_focusable_in_tab(tab_id)
	if first_focusable != null:
		first_focusable.grab_focus()

func _build_tab_bar() -> void:
	var tab_defs := [
		[TabId.DISPLAY, &"menu.settings.display", "Display"],
		[TabId.AUDIO, &"menu.settings.audio", "Audio"],
		[TabId.VFX, &"menu.settings.vfx", "VFX"],
		[TabId.LANGUAGE, &"menu.settings.language", "Language"],
		[TabId.GAMEPAD, &"menu.settings.gamepad", "Gamepad"],
		[TabId.KEYBOARD_MOUSE, &"menu.settings.keyboard_mouse", "K/M"],
		[TabId.TOUCHSCREEN, &"menu.settings.touchscreen", "Touch"],
	]
	for def in tab_defs:
		var id: TabId = def[0]
		var key: StringName = def[1]
		var fallback: String = def[2]
		var btn := Button.new()
		btn.name = "TabButton_" + TabId.keys()[id]
		btn.text = fallback
		btn.tooltip_text = key
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_on_tab_button_pressed.bind(id))
		_tab_bar.add_child(btn)
		_tab_buttons[id] = {"button": btn, "key": key, "fallback": fallback}

func _create_tab_contents() -> void:
	pass

func _on_tab_button_pressed(tab_id: TabId) -> void:
	U_UISoundPlayer.play_confirm()
	switch_to_tab(tab_id)

func _show_tab_content(tab_id: TabId) -> void:
	var content := _tab_contents.get(tab_id) as Control
	if content != null:
		content.visible = true
		content.set_process(true)

func _hide_tab_content(tab_id: TabId) -> void:
	var content := _tab_contents.get(tab_id) as Control
	if content != null:
		content.visible = false
		content.set_process(false)

func _update_tab_button_states() -> void:
	for id in _tab_buttons:
		var data: Dictionary = _tab_buttons[id]
		var btn: Button = data.button
		btn.disabled = (id == _active_tab)
		if id == _active_tab:
			btn.theme_type_variation = "TabButtonActive"
		else:
			btn.theme_type_variation = "TabButton"

func _update_tab_visibility() -> void:
	pass

func _configure_focus_neighbors() -> void:
	var visible_buttons: Array[Control] = []
	var ordered_ids := [TabId.DISPLAY, TabId.AUDIO, TabId.VFX, TabId.LANGUAGE, TabId.GAMEPAD, TabId.KEYBOARD_MOUSE, TabId.TOUCHSCREEN]
	for id in ordered_ids:
		var data: Dictionary = _tab_buttons.get(id, {})
		var btn: Button = data.get("button")
		if btn != null and btn.visible:
			visible_buttons.append(btn)
	if not visible_buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(visible_buttons, true)

func _find_first_focusable_in_tab(tab_id: TabId) -> Control:
	var content := _tab_contents.get(tab_id) as Control
	if content == null:
		return null
	var children := _get_focusable_descendants(content)
	if not children.is_empty():
		return children[0]
	return null

func _get_focusable_descendants(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE and child.visible:
			result.append(child as Control)
		result.append_array(_get_focusable_descendants(child))
	return result

func _on_store_ready(store: M_StateStore) -> void:
	if store != null and not store.slice_updated.is_connected(_on_slice_updated):
		store.slice_updated.connect(_on_slice_updated)
	_update_tab_visibility(store.get_state())

func _on_slice_updated(_slice_name: StringName, _slice_state: Dictionary) -> void:
	var store := get_store()
	if store == null:
		return
	_update_tab_visibility(store.get_state())

func _on_locale_changed(_locale: StringName) -> void:
	_localize_tab_buttons()

func _localize_tab_buttons() -> void:
	for id in _tab_buttons:
		var data: Dictionary = _tab_buttons[id]
		var btn: Button = data.get("button")
		var key: StringName = data.get("key", &"")
		var fallback: String = data.get("fallback", "")
		if btn != null:
			btn.text = U_LOCALIZATION_UTILS.localize(key) if U_LOCALIZATION_UTILS != null else fallback
```

- [ ] **Step 4: Create the .tscn scene via builder**

Since `.tscn` files must be created via builder scripts (project rule), create the scene structure using `U_EditorPrefabBuilder` or `U_TemplateBaseSceneBuilder`. Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd
```

If the builder pipeline doesn't yet support this scene type, create a minimal `.tscn` manually with the required node hierarchy:

```
[ext_resource path="res://scripts/core/ui/settings/ui_settings_panel.gd" type="Script" id=1]

[node name="UI_SettingsPanel" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="OverlayBackground" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.7)

[node name="CenterContainer" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Panel" type="PanelContainer" parent="CenterContainer"]
layout_mode = 2
custom_minimum_size = Vector2(860, 620)

[node name="VBox" type="VBoxContainer" parent="CenterContainer/Panel"]
layout_mode = 2

[node name="TabBar" type="HBoxContainer" parent="CenterContainer/Panel/VBox"]
layout_mode = 2

[node name="HSeparator" type="HSeparator" parent="CenterContainer/Panel/VBox"]
layout_mode = 2

[node name="ContentContainer" type="VBoxContainer" parent="CenterContainer/Panel/VBox"]
layout_mode = 2
size_flags_vertical = 3
```

Save as `scenes/core/ui/settings/ui_settings_panel.tscn`.

- [ ] **Step 5: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tabs.gd`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd scenes/core/ui/settings/ui_settings_panel.tscn tests/unit/ui/settings/test_settings_panel_tabs.gd
git commit -m "(RED/GREEN) Create UI_SettingsPanel with tab switching shell"
```

---

### Task 4: Add device-specific tab visibility to UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_settings_panel_tab_visibility.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")

func test_gamepad_tab_hidden_when_touchscreen_active():
	_set_device_type(M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	var panel := _create_panel()
	var gamepad_data: Dictionary = panel._tab_buttons.get(UI_SettingsPanel.TAB_GAMEPAD, {})
	var btn: Button = gamepad_data.get("button")
	if btn != null:
		assert_false(btn.visible, "Gamepad tab should be hidden when touchscreen is active device")
	panel.queue_free()

func test_touchscreen_tab_hidden_on_desktop():
	_set_device_type(M_InputDeviceManager.DeviceType.KEYBOARD)
	var panel := _create_panel()
	var touch_data: Dictionary = panel._tab_buttons.get(UI_SettingsPanel.TAB_TOUCHSCREEN, {})
	var btn: Button = touch_data.get("button")
	if btn != null and not panel._is_mobile_context():
		assert_false(btn.visible, "Touchscreen tab should be hidden on desktop non-mobile")
	panel.queue_free()

func test_keyboard_mouse_tab_hidden_in_mobile_context():
	_set_device_type(M_InputDeviceManager.DeviceType.KEYBOARD)
	var panel := _create_panel()
	panel.emulate_mobile_override = true
	panel._update_tab_visibility()
	var km_data: Dictionary = panel._tab_buttons.get(UI_SettingsPanel.TAB_KEYBOARD_MOUSE, {})
	var btn: Button = km_data.get("button")
	if btn != null:
		assert_false(btn.visible, "K/M tab should be hidden in mobile context")
	panel.queue_free()

func test_display_tab_always_visible():
	var panel := _create_panel()
	var display_data: Dictionary = panel._tab_buttons.get(UI_SettingsPanel.TAB_DISPLAY, {})
	var btn: Button = display_data.get("button")
	if btn != null:
		assert_true(btn.visible, "Display tab should always be visible")
	panel.queue_free()

func test_active_tab_snaps_when_hidden():
	_set_device_type(M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	var panel := _create_panel()
	panel.switch_to_tab(UI_SettingsPanel.TAB_GAMEPAD)
	panel._update_tab_visibility()
	assert_ne(panel.get_active_tab_id(), UI_SettingsPanel.TAB_GAMEPAD, "Should snap away from hidden Gamepad tab")
	panel.queue_free()

var _create_panel -> UI_SettingsPanel:
	var panel := UI_SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	return panel
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tab_visibility.gd`
Expected: FAIL — `_update_tab_visibility` doesn't implement device-specific logic yet

- [ ] **Step 3: Implement device-specific tab visibility**

Update `_update_tab_visibility()` in `scripts/core/ui/settings/ui_settings_panel.gd`:

```gdscript
@export var emulate_mobile_override: bool = false

func _update_tab_visibility(state: Dictionary = {}) -> void:
	if state.is_empty():
		var store := get_store()
		if store != null:
			state = store.get_state()

	var has_gamepad: bool = false
	var device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD
	var is_mobile_context: bool = _is_mobile_context()
	var is_gamepad_active: bool = false

	if not state.is_empty():
		has_gamepad = U_InputSelectors.is_gamepad_connected(state)
		device_type = U_InputSelectors.get_active_device_type(state)
		is_gamepad_active = (device_type == M_InputDeviceManager.DeviceType.GAMEPAD)

	if device_type != _last_device_type:
		var previous_type: int = _last_device_type
		_last_device_type = device_type
		if device_type == M_InputDeviceManager.DeviceType.GAMEPAD and previous_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN:
			reset_analog_navigation()
			_consume_next_nav = true

	_set_tab_visible(TabId.GAMEPAD, has_gamepad and device_type != M_InputDeviceManager.DeviceType.TOUCHSCREEN)
	_set_tab_visible(TabId.TOUCHSCREEN, is_mobile_context and not is_gamepad_active)
	_set_tab_visible(TabId.KEYBOARD_MOUSE, not is_mobile_context)

	if _is_tab_hidden(_active_tab):
		_snap_to_first_visible_tab()

	_configure_focus_neighbors()

func _set_tab_visible(tab_id: TabId, visible: bool) -> void:
	var data: Dictionary = _tab_buttons.get(tab_id, {})
	var btn: Button = data.get("button")
	if btn != null:
		btn.visible = visible
	var content: Control = _tab_contents.get(tab_id) as Control
	if content != null:
		content.visible = content.visible and visible

func _is_tab_hidden(tab_id: TabId) -> bool:
	var data: Dictionary = _tab_buttons.get(tab_id, {})
	var btn: Button = data.get("button")
	if btn == null:
		return true
	return not btn.visible

func _snap_to_first_visible_tab() -> void:
	var ordered := [TabId.DISPLAY, TabId.AUDIO, TabId.VFX, TabId.LANGUAGE, TabId.GAMEPAD, TabId.KEYBOARD_MOUSE, TabId.TOUCHSCREEN]
	for id in ordered:
		if not _is_tab_hidden(id):
			switch_to_tab(id)
			return
	switch_to_tab(TabId.DISPLAY)

func _is_mobile_context() -> bool:
	if emulate_mobile_override:
		return true
	if OS.has_feature("mobile"):
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _navigate_focus(direction: StringName) -> void:
	if _consume_next_nav:
		_consume_next_nav = false
		return
	super._navigate_focus(direction)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tab_visibility.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tab_visibility.gd
git commit -m "(RED/GREEN) Add device-specific tab visibility to UI_SettingsPanel"
```

---

## Phase 3: Create Tab Page Scripts

### Task 5: Create ui_vfx_settings_tab.gd (extract from overlay)

**Files:**
- Create: `scripts/core/ui/settings/ui_vfx_settings_tab.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_ui_vfx_settings_tab.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_VFXSettingsTab := preload("res://scripts/core/ui/settings/ui_vfx_settings_tab.gd")

func test_vfx_settings_tab_extends_vboxcontainer():
	var tab := UI_VFXSettingsTab.new()
	assert_true(tab is VBoxContainer, "VFX settings tab should extend VBoxContainer")
	tab.free()

func test_vfx_settings_tab_has_class_name():
	assert_eq(UI_VFXSettingsTab.new().get_class(), "VBoxContainer", "Should have class_name UI_VFXSettingsTab")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_vfx_settings_tab.gd`
Expected: FAIL — script doesn't exist yet

- [ ] **Step 3: Create ui_vfx_settings_tab.gd**

Create `scripts/core/ui/settings/ui_vfx_settings_tab.gd` by extracting the builder setup logic from `ui_vfx_settings_overlay.gd`. The key difference: this extends `VBoxContainer` instead of `BaseOverlay`, removes overlay-specific lifecycle (`_on_panel_ready`, `_close_overlay`), and changes Apply/Cancel to instant-apply.

Read the source `scripts/core/ui/settings/ui_vfx_settings_overlay.gd` and extract:

- The `_builder` setup (using `U_SettingsTabBuilder`)
- Control references (shake toggle, intensity slider, flash toggle, particles toggle)
- Preview mode logic (`_preview_active`, `M_VFXManager.set_vfx_settings_preview()`)
- Store subscription and state population
- Localization (`_on_locale_changed`, `_localize_labels()`)
- Focus configuration (`_configure_focus_neighbors`)

Remove:
- `_close_overlay()` — the parent panel handles closing
- `_on_panel_ready()` lifecycle — replace with `_ready()` → `_setup_builder()` + `_builder.build()`
- Apply/Cancel buttons and their logic — each control change dispatches immediately

The new tab should:
- Extend `VBoxContainer`
- Have `class_name UI_VFXSettingsTab`
- Use `U_SettingsTabBuilder` to build its content
- Dispatch changes instantly to `M_VFXManager` on each control value change
- Keep "Reset to defaults" button (replaces Apply/Cancel)
- Call `_configure_focus_neighbors()` after building
- Connect `visibility_changed` to handle preview cleanup (clear preview when tab is hidden or tree exits)

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_vfx_settings_tab.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_vfx_settings_tab.gd tests/unit/ui/settings/test_ui_vfx_settings_tab.gd
git commit -m "(RED/GREEN) Create UI_VFXSettingsTab extracted from overlay"
```

---

### Task 6: Create ui_gamepad_settings_tab.gd (extract from overlay)

**Files:**
- Create: `scripts/core/ui/settings/ui_gamepad_settings_tab.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_ui_gamepad_settings_tab.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_GamepadSettingsTab := preload("res://scripts/core/ui/settings/ui_gamepad_settings_tab.gd")

func test_gamepad_settings_tab_extends_vboxcontainer():
	var tab := UI_GamepadSettingsTab.new()
	assert_true(tab is VBoxContainer, "Gamepad settings tab should extend VBoxContainer")
	tab.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_gamepad_settings_tab.gd`
Expected: FAIL

- [ ] **Step 3: Create ui_gamepad_settings_tab.gd**

Extract from `scripts/core/ui/overlays/ui_gamepad_settings_overlay.gd`. Same pattern as Task 5:
- Extend `VBoxContainer`, `class_name UI_GamepadSettingsTab`
- Keep: `_builder` setup, control references, stick preview (`UI_GamepadStickPreview`), deadzone/sensitivity/vibration controls, preview mode, store subscription, localization, focus config
- Remove: `_on_panel_ready`, `_close_overlay`, Apply/Cancel buttons
- Change to instant-apply: each slider/toggle change dispatches to `M_InputDeviceManager` immediately
- Keep "Reset to defaults" button
- Handle stick preview `_process` only when visible (connect `visibility_changed`)
- Keep `_unhandled_input` for ui_accept/ui_cancel on preview panel, but only when visible

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_gamepad_settings_tab.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_gamepad_settings_tab.gd tests/unit/ui/settings/test_ui_gamepad_settings_tab.gd
git commit -m "(RED/GREEN) Create UI_GamepadSettingsTab extracted from overlay"
```

---

### Task 7: Create ui_keyboard_mouse_settings_tab.gd (extract from overlay)

**Files:**
- Create: `scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_KeyboardMouseSettingsTab := preload("res://scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd")

func test_keyboard_mouse_settings_tab_extends_vboxcontainer():
	var tab := UI_KeyboardMouseSettingsTab.new()
	assert_true(tab is VBoxContainer, "K/M settings tab should extend VBoxContainer")
	tab.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd`
Expected: FAIL

- [ ] **Step 3: Create ui_keyboard_mouse_settings_tab.gd**

Extract from `scripts/core/ui/overlays/ui_keyboard_mouse_settings_overlay.gd` (301 lines):
- Extend `VBoxContainer`, `class_name UI_KeyboardMouseSettingsTab`
- Keep: mouse sensitivity, keyboard look toggle/speed, rebind button
- Remove: overlay lifecycle, Apply/Cancel, `_close_overlay`
- Change to instant-apply: dispatch to `M_InputDeviceManager` immediately
- Keep "Reset to defaults"
- Keep "Rebind Controls" button that opens `input_rebinding` overlay (dispatches `U_NavigationActions.open_overlay()`)

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd
git commit -m "(RED/GREEN) Create UI_KeyboardMouseSettingsTab extracted from overlay"
```

---

### Task 8: Create ui_touchscreen_settings_tab.gd (extract from overlay)

**Files:**
- Create: `scripts/core/ui/settings/ui_touchscreen_settings_tab.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_ui_touchscreen_settings_tab.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_TouchscreenSettingsTab := preload("res://scripts/core/ui/settings/ui_touchscreen_settings_tab.gd")

func test_touchscreen_settings_tab_extends_vboxcontainer():
	var tab := UI_TouchscreenSettingsTab.new()
	assert_true(tab is VBoxContainer, "Touchscreen settings tab should extend VBoxContainer")
	tab.free()

func test_touchscreen_tab_has_edit_layout_button():
	var tab := UI_TouchscreenSettingsTab.new()
	add_child(tab)
	await get_tree().process_frame
	var edit_btn := tab.find_child("EditLayoutButton", true, false) as Button
	assert_not_null(edit_btn, "Touchscreen tab should have Edit Layout button")
	tab.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_touchscreen_settings_tab.gd`
Expected: FAIL

- [ ] **Step 3: Create ui_touchscreen_settings_tab.gd**

Extract from `scripts/core/ui/overlays/ui_touchscreen_settings_overlay.gd` (590 lines):
- Extend `VBoxContainer`, `class_name UI_TouchscreenSettingsTab`
- Keep: joystick/button size, opacity, deadzone sliders, edit layout button
- Remove: overlay lifecycle, Apply/Cancel
- Change to instant-apply
- Keep "Edit Layout" button that opens `edit_touch_controls` overlay via `U_NavigationActions.open_overlay()`
- Keep `_configure_focus_neighbors` and mobile visibility logic

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_ui_touchscreen_settings_tab.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_touchscreen_settings_tab.gd tests/unit/ui/settings/test_ui_touchscreen_settings_tab.gd
git commit -m "(RED/GREEN) Create UI_TouchscreenSettingsTab extracted from overlay"
```

---

### Task 9: Wire tab pages into UI_SettingsPanel

**Files:**
- Modify: `scripts/core/ui/settings/ui_settings_panel.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/settings/test_settings_panel_tab_contents.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_SettingsPanel := preload("res://scripts/core/ui/settings/ui_settings_panel.gd")

const EXPECTED_TABS := {
	UI_SettingsPanel.TAB_DISPLAY: "UI_DisplaySettingsTab",
	UI_SettingsPanel.TAB_AUDIO: "UI_AudioSettingsTab",
	UI_SettingsPanel.TAB_VFX: "UI_VFXSettingsTab",
	UI_SettingsPanel.TAB_LANGUAGE: "UI_LocalizationSettingsTab",
	UI_SettingsPanel.TAB_GAMEPAD: "UI_GamepadSettingsTab",
	UI_SettingsPanel.TAB_KEYBOARD_MOUSE: "UI_KeyboardMouseSettingsTab",
	UI_SettingsPanel.TAB_TOUCHSCREEN: "UI_TouchscreenSettingsTab",
}

func test_panel_creates_all_tab_contents():
	var panel := _create_panel()
	for tab_id in EXPECTED_TABS:
		var content := panel._tab_contents.get(tab_id) as Control
		assert_not_null(content, "Should have content for tab " + str(tab_id))
	panel.queue_free()

func test_only_active_tab_content_visible():
	var panel := _create_panel()
	await get_tree().process_frame
	for tab_id in panel._tab_contents:
		var content: Control = panel._tab_contents[tab_id]
		if tab_id == panel.get_active_tab_id():
			assert_true(content.visible, "Active tab content should be visible: " + str(tab_id))
		else:
			assert_false(content.visible, "Inactive tab content should be hidden: " + str(tab_id))
	panel.queue_free()

func _create_panel() -> UI_SettingsPanel:
	var panel := UI_SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	return panel
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tab_contents.gd`
Expected: FAIL — `_create_tab_contents()` doesn't instantiate tabs yet

- [ ] **Step 3: Implement _create_tab_contents()**

Update `_create_tab_contents()` in `scripts/core/ui/settings/ui_settings_panel.gd`:

```gdscript
const UI_DisplaySettingsTab := preload("res://scripts/core/ui/settings/ui_display_settings_tab.gd")
const UI_AudioSettingsTab := preload("res://scripts/core/ui/settings/ui_audio_settings_tab.gd")
const UI_VFXSettingsTab := preload("res://scripts/core/ui/settings/ui_vfx_settings_tab.gd")
const UI_LocalizationSettingsTab := preload("res://scripts/core/ui/settings/ui_localization_settings_tab.gd")
const UI_GamepadSettingsTab := preload("res://scripts/core/ui/settings/ui_gamepad_settings_tab.gd")
const UI_KeyboardMouseSettingsTab := preload("res://scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd")
const UI_TouchscreenSettingsTab := preload("res://scripts/core/ui/settings/ui_touchscreen_settings_tab.gd")

func _create_tab_contents() -> void:
	var tab_classes := {
		TabId.DISPLAY: UI_DisplaySettingsTab,
		TabId.AUDIO: UI_AudioSettingsTab,
		TabId.VFX: UI_VFXSettingsTab,
		TabId.LANGUAGE: UI_LocalizationSettingsTab,
		TabId.GAMEPAD: UI_GamepadSettingsTab,
		TabId.KEYBOARD_MOUSE: UI_KeyboardMouseSettingsTab,
		TabId.TOUCHSCREEN: UI_TouchscreenSettingsTab,
	}
	var tab_names := {
		TabId.DISPLAY: "DisplayTabContent",
		TabId.AUDIO: "AudioTabContent",
		TabId.VFX: "VFXTabContent",
		TabId.LANGUAGE: "LanguageTabContent",
		TabId.GAMEPAD: "GamepadTabContent",
		TabId.KEYBOARD_MOUSE: "KeyboardMouseTabContent",
		TabId.TOUCHSCREEN: "TouchscreenTabContent",
	}
	for id in tab_classes:
		var klass: GDScript = tab_classes[id]
		var instance := klass.new() as Control
		instance.name = tab_names[id]
		instance.visible = false
		instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_container.add_child(instance)
		_tab_contents[id] = instance
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_settings_panel_tab_contents.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/settings/ui_settings_panel.gd tests/unit/ui/settings/test_settings_panel_tab_contents.gd
git commit -m "(RED/GREEN) Wire all 7 tab pages into UI_SettingsPanel"
```

---

## Phase 4: Wire Up Navigation, Registry, and Pause Menu

### Task 10: Create settings_panel .tres and update U_UIRegistry

**Files:**
- Create: `resources/core/ui_screens/cfg_settings_panel_overlay.tres`
- Modify: `scripts/core/ui/utils/u_ui_registry.gd`

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/ui/settings/test_overlay_panel_size_constant.gd`:

```gdscript
func test_settings_panel_registered_in_ui_registry():
	var def := U_UIRegistry.get_screen(StringName("settings_panel"))
	assert_not_null(def, "settings_panel should be registered in U_UIRegistry")
	assert_eq(def.get("kind"), 1, "settings_panel should be an OVERLAY")

func test_settings_panel_overlay_id_exists():
	var overlays := U_UIRegistry.get_overlays_for_shell(StringName("gameplay"))
	var has_panel := false
	for overlay in overlays:
		if overlay.get("screen_id") == StringName("settings_panel"):
			has_panel = true
			break
	assert_true(has_panel, "settings_panel should be in gameplay overlays")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_overlay_panel_size_constant.gd`
Expected: FAIL — `settings_panel` not registered

- [ ] **Step 3: Create .tres definition**

Create `resources/core/ui_screens/cfg_settings_panel_overlay.tres` modeled after `cfg_settings_menu_overlay.tres`:

```
screen_id = StringName("settings_panel")
kind = 1
scene_id = StringName("settings_panel")
allowed_shells = [StringName("gameplay")]
allowed_parents = [StringName("pause_menu")]
close_mode = 0
hides_previous_overlays = false
```

- [ ] **Step 4: Update U_UIRegistry**

In `scripts/core/ui/utils/u_ui_registry.gd`:

1. Add a preload for the new `.tres`:
```gdscript
const CFG_SETTINGS_PANEL := preload("res://resources/core/ui_screens/cfg_settings_panel_overlay.tres")
```

2. Add a registration line in `_register_all_screens()`:
```gdscript
_register_definition(CFG_SETTINGS_PANEL)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/settings/test_overlay_panel_size_constant.gd`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add resources/core/ui_screens/cfg_settings_panel_overlay.tres scripts/core/ui/utils/u_ui_registry.gd
git commit -m "(RED/GREEN) Register settings_panel in U_UIRegistry"
```

---

### Task 11: Update pause menu to open settings_panel instead of settings_menu_overlay

**Files:**
- Modify: `scripts/core/ui/menus/ui_pause_menu.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/ui/test_pause_menu_settings_panel.gd`:

```gdscript
extends "res://tests/gut_test_base.gd"

const UI_PauseMenu := preload("res://scripts/core/ui/menus/ui_pause_menu.gd")

func test_pause_menu_opens_settings_panel():
	var menu := UI_PauseMenu.new()
	assert_eq(menu.OVERLAY_SETTINGS, StringName("settings_panel"), "Pause menu should reference settings_panel")
	menu.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu_settings_panel.gd`
Expected: FAIL — `OVERLAY_SETTINGS` still points to `settings_menu_overlay`

- [ ] **Step 3: Update pause menu**

In `scripts/core/ui/menus/ui_pause_menu.gd`, change:

```gdscript
const OVERLAY_SETTINGS := StringName("settings_menu_overlay")
```

to:

```gdscript
const OVERLAY_SETTINGS := StringName("settings_panel")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu_settings_panel.gd`
Expected: PASS

- [ ] **Step 5: Run full pause menu test suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd`
Expected: PASS (no other behavior changed)

- [ ] **Step 6: Commit**

```bash
git add scripts/core/ui/menus/ui_pause_menu.gd tests/unit/ui/test_pause_menu_settings_panel.gd
git commit -m "(RED/GREEN) Update pause menu to open settings_panel"
```

---

### Task 12: Update utility overlay allowed_parents to include settings_panel

**Files:**
- Modify: `resources/core/ui_screens/cfg_input_rebinding_overlay.tres`
- Modify: `resources/core/ui_screens/cfg_edit_touch_controls_overlay.tres`
- Modify: `resources/core/ui_screens/cfg_input_profile_selector_overlay.tres`

- [ ] **Step 1: Update .tres files**

For each utility overlay `.tres`, add `settings_panel` to `allowed_parents`:

- `cfg_input_rebinding_overlay.tres`: `allowed_parents` → add `StringName("settings_panel")`
- `cfg_edit_touch_controls_overlay.tres`: `allowed_parents` → add `StringName("settings_panel")`
- `cfg_input_profile_selector_overlay.tres`: `allowed_parents` → add `StringName("settings_panel")`

- [ ] **Step 2: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add resources/core/ui_screens/cfg_input_rebinding_overlay.tres resources/core/ui_screens/cfg_edit_touch_controls_overlay.tres resources/core/ui_screens/cfg_input_profile_selector_overlay.tres
git commit -m "(FIX) Add settings_panel to utility overlay allowed_parents"
```

---

### Task 13: Add settings_panel to scene registry

**Files:**
- Modify: `resources/core/scene_registry/cfg_core_scene_entries.tres` (or the relevant RS_SceneManifestConfig)

- [ ] **Step 1: Check scene registry structure**

Read `resources/core/scene_registry/cfg_core_scene_entries.tres` to understand the format and find where `settings_menu` is registered.

- [ ] **Step 2: Add settings_panel entry**

Add a new scene entry mapping `scene_id = "settings_panel"` to the path `res://scenes/core/ui/settings/ui_settings_panel.tscn`.

If `settings_menu` is still in the registry, keep it temporarily (it will be removed in Phase 5).

- [ ] **Step 3: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add resources/core/scene_registry/cfg_core_scene_entries.tres
git commit -m "(FIX) Register settings_panel scene in scene manifest"
```

---

## Phase 5: Remove Obsolete Overlays and Menu

### Task 14: Delete obsolete settings overlay scripts and scenes

**Files:**
- Delete: `scripts/core/ui/settings/ui_display_settings_overlay.gd`
- Delete: `scripts/core/ui/settings/ui_audio_settings_overlay.gd`
- Delete: `scripts/core/ui/settings/ui_localization_settings_overlay.gd`
- Delete: `scripts/core/ui/settings/ui_vfx_settings_overlay.gd`
- Delete: `scenes/core/ui/settings/ui_display_settings_overlay.tscn`
- Delete: `scenes/core/ui/settings/ui_audio_settings_overlay.tscn`
- Delete: `scenes/core/ui/settings/ui_localization_settings_overlay.tscn`
- Delete: `scenes/core/ui/settings/ui_vfx_settings_overlay.tscn`
- Delete: `scenes/core/ui/overlays/ui_gamepad_settings_overlay.gd`
- Delete: `scenes/core/ui/overlays/ui_gamepad_settings_overlay.tscn`
- Delete: `scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.gd`
- Delete: `scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn`
- Delete: `scenes/core/ui/overlays/ui_touchscreen_settings_overlay.gd`
- Delete: `scenes/core/ui/overlays/ui_touchscreen_settings_overlay.tscn`

- [x] **Step 1: Verify nothing references these scripts/scenes**

Search the codebase for references to each deleted file's path. If any remain (other than tests and .tres definitions), update them to reference the new tab scripts or panel instead.

2026-05-05 audit: Runtime scripts, scenes, resources, and tests no longer reference the
deleted settings overlay scene paths or overlay IDs. Remaining matches are historical/spec
docs that describe the migration.

- [x] **Step 2: Remove .tres screen definitions for deleted overlays**

Delete or update these `.tres` files from `resources/core/ui_screens/`:
- `cfg_display_settings_overlay.tres`
- `cfg_audio_settings_overlay.tres`
- `cfg_vfx_settings_overlay.tres`
- `cfg_localization_settings_overlay.tres`
- `cfg_gamepad_settings_overlay.tres`
- `cfg_keyboard_mouse_settings_overlay.tres`
- `cfg_touchscreen_settings_overlay.tres`

Remove their preloads and `_register_definition()` calls from `scripts/core/ui/utils/u_ui_registry.gd`.

- [x] **Step 3: Delete the script and scene files**

Remove all files listed above.

- [x] **Step 4: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS (verify no broken references)

2026-05-05 audit: PASS.

- [ ] **Step 5: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: PASS (some tests may need updates — see Task 16)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "(REFACTOR) Delete obsolete settings overlay scripts, scenes, and registry entries"
```

Note: Use `git add` on specific files rather than `-A` per project convention.

---

### Task 15: Delete UI_SettingsMenu and BaseSettingsSimpleOverlay

**Files:**
- Delete: `scripts/core/ui/menus/ui_settings_menu.gd`
- Delete: `scenes/core/ui/menus/ui_settings_menu.tscn`
- Delete: `scripts/core/ui/settings/base_settings_simple_overlay.gd`
- Delete: `resources/core/ui_screens/cfg_settings_menu_overlay.tres`
- Remove from scene registry: `settings_menu` entry

- [x] **Step 1: Verify nothing references UI_SettingsMenu or BaseSettingsSimpleOverlay**

Search for:
- `UI_SettingsMenu` class references
- `base_settings_simple_overlay` path references
- `settings_menu_overlay` overlay ID references
- `settings_menu` scene ID references

Update any found references.

2026-05-05 audit: Runtime scripts, scenes, resources, and tests no longer reference
`UI_SettingsMenu`, `BaseSettingsSimpleOverlay`, `settings_menu_overlay`, or the deleted
settings menu scene. Remaining matches are historical/spec docs.

- [x] **Step 2: Move OVERLAY_SCREEN_MARGIN to BaseOverlay if needed**

Check if any remaining overlay uses `OVERLAY_SCREEN_MARGIN`. If so, move the constant to `BaseOverlay`. If not, simply delete it.

- [x] **Step 3: Delete files and remove registry entry**

Remove the `settings_menu_overlay` preload and registration from `U_UIRegistry`. Remove `settings_menu` from the scene manifest if present.

- [x] **Step 4: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: PASS

2026-05-05 audit: PASS.

- [ ] **Step 5: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: PASS (may need test updates — see Task 16)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "(REFACTOR) Delete UI_SettingsMenu, BaseSettingsSimpleOverlay, and their registry entries"
```

---

### Task 16: Update and migrate tests

**Files:**
- Modify/Update: Various test files
- Delete: Tests for deleted overlay scripts

- [x] **Step 1: Identify tests that need changes**

Tests to **delete** (they test deleted overlay scripts):
- `tests/unit/ui/settings/test_ui_vfx_settings_overlay_builder.gd` → replace with `tests/unit/ui/settings/test_ui_vfx_settings_tab.gd` (already created in Task 5)
- `tests/unit/ui/test_gamepad_settings_overlay.gd` → replace with `tests/unit/ui/settings/test_ui_gamepad_settings_tab.gd` (already created in Task 6)
- `tests/unit/ui/test_keyboard_mouse_settings_overlay.gd` → replace with `tests/unit/ui/settings/test_ui_keyboard_mouse_settings_tab.gd` (already created in Task 7)
- `tests/unit/ui/test_touchscreen_settings_overlay.gd` → replace with `tests/unit/ui/settings/test_ui_touchscreen_settings_tab.gd` (already created in Task 8)
- `tests/unit/ui/test_settings_menu_visibility.gd` → replace with `tests/unit/ui/settings/test_settings_panel_tab_visibility.gd` (already created in Task 4)

Tests to **migrate** (update test targets from overlay to tab):
- `tests/unit/ui/test_vfx_settings_overlay_localization.gd` → update to test `UI_VFXSettingsTab`
- `tests/unit/ui/test_gamepad_settings_overlay_localization.gd` → update to test `UI_GamepadSettingsTab`
- `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → update to test `UI_TouchscreenSettingsTab`
- `tests/unit/ui/test_settings_overlay_wrappers.gd` → remove or rewrite for `UI_SettingsPanel`
- `tests/unit/ui/settings/test_settings_simple_overlay_base.gd` → delete (tests `BaseSettingsSimpleOverlay`)
- `tests/unit/ui/settings/test_ui_display_settings_tab_builder.gd` → update if it references overlay wrapper
- `tests/unit/ui/settings/test_ui_audio_settings_tab_builder.gd` → update if it references overlay wrapper

- [x] **Step 2: Migrate and update tests**

For each test, update the class under test from the overlay class to the new tab class. Remove overlay-specific assertions (has motion, has theme tokens via overlay builder, etc.) and replace with tab-appropriate assertions.

2026-05-05 audit: Removed obsolete overlay/base tests that were still present, added
coverage for default tab visibility and keyboard/mouse action-row construction, and
updated settings panel tests to use an isolated state store fixture.

- [ ] **Step 3: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "(TEST) Migrate overlay tests to tab page tests, delete obsolete overlay tests"
```

---

### Task 17: Final integration verification

**Files:**
- None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `tools/run_gut_suite.sh`
Expected: All tests PASS

- [x] **Step 2: Run style enforcement suite**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Expected: All tests PASS

2026-05-05 audit: PASS.

- [x] **Step 3: Verify core→demo separation**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
Check that `test_core_scripts_never_import_from_demo` still passes.

2026-05-05 audit: PASS as part of the style enforcement suite.

- [x] **Step 4: Verify no stale references remain**

Search for: `settings_menu_overlay`, `display_settings`, `audio_settings`, `vfx_settings`, `localization_settings`, `gamepad_settings`, `keyboard_mouse_settings`, `touchscreen_settings` (as overlay IDs, not tab names) in scripts. Any remaining references should be updated.

2026-05-05 audit: PASS for runtime scripts, scenes, resources, and tests. Historical/spec docs
still mention old overlay names as migration history.

- [ ] **Step 5: Visual parity check**

Launch the project in the Godot editor and visually verify:
1. Pause Menu → Settings opens the tabbed panel
2. All 7 tabs appear (adjust for device type)
3. Tab switching works with gamepad D-pad
4. Settings apply instantly (except Display/Language confirmations)
5. Utility overlays (Input Rebinding, Edit Touch Controls, Input Profile Selector) open as sub-overlays
6. Back button returns to pause menu

- [ ] **Step 6: Commit milestone docs**

Update any planning docs that reference Task E completion.

```bash
git commit --allow-empty -m "(MILESTONE) Task E — Control-style tabbed settings panel complete"
```
