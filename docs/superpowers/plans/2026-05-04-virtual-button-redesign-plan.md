# Virtual Button Visual Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `UI_VirtualButton` visuals to match the Godot `VirtualJoystick` flat `StyleBoxFlat` circle style with a subtle border and SVG icons instead of text labels.

**Architecture:** Replace the old SVG texture background + text label with a `StyleBoxFlat` circle (matching joystick tip color: `rgba(102,102,102, 50% alpha)`) with a `1.5px solid rgba(255,255,255, 0.15)` border, and a single `TextureRect` (`ActionIcon`) displaying an action-specific SVG icon tinted via `modulate`. Per-action colors remain for icon tint only. Touch logic, bridge modes, and repositioning are unchanged.

**Tech Stack:** Godot 4.6.1 GDScript; SVG assets; StyleBoxFlat procedural styling

---

### Task 1: Create SVG Icon Assets

**Files:**
- Create: `assets/core/button_prompts/mobile/icon_jump.svg`
- Create: `assets/core/button_prompts/mobile/icon_sprint.svg`
- Create: `assets/core/button_prompts/mobile/icon_interact.svg`
- Create: `assets/core/button_prompts/mobile/icon_pause.svg`

- [ ] **Step 1: Create icon_jump.svg**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <path d="M6 16l6-10 6 10" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 2: Create icon_sprint.svg**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <path d="M5 6l10 6-10 6" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M13 6l7 6-7 6" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 3: Create icon_interact.svg**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="12" cy="12" r="3" fill="currentColor" stroke="none"/>
</svg>
```

- [ ] **Step 4: Create icon_pause.svg**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
  <rect x="5" y="4" width="7" height="24" rx="1.5" fill="currentColor"/>
  <rect x="20" y="4" width="7" height="24" rx="1.5" fill="currentColor"/>
</svg>
```

- [ ] **Step 5: Commit**

```bash
git add assets/core/button_prompts/mobile/icon_*.svg
git commit -m "feat: add SVG action icons for virtual button redesign"
```

---

### Task 2: Rewrite UI_VirtualButton Visual Layer

**Files:**
- Modify: `scripts/core/ui/hud/ui_virtual_button.gd` (full rewrite of visual system, retain all touch/bridge/reposition logic)

- [ ] **Step 1: Update imports and constants**

Read the current file, then rewrite the top section. Keep `ACTION_COLORS` and `ACTION_BRIDGE_MODES` (now used for icon tint). Remove `DEFAULT_TEXTURE_PATH`, `ACTION_LABEL_KEYS`, `U_LOCALIZATION_UTILS` preload. Add new style/icon constants.

Replace lines 1-47 with:

```gdscript
extends Control
class_name UI_VirtualButton


signal button_pressed(action: StringName)
signal button_released(action: StringName)

enum ActionType {
	TAP,
	HOLD
}

@export var action: StringName = StringName("jump")
@export var action_type: ActionType = ActionType.HOLD
@export var can_reposition: bool = false
@export var control_name: StringName = StringName()

const DEFAULT_SIZE := Vector2(100, 100)
const PRESSED_SCALE := Vector2(0.95, 0.95)
const RELEASED_SCALE := Vector2.ONE
const PRESSED_MODULATE := Color(0.8, 0.8, 0.8, 1.0)
const RELEASED_MODULATE := Color(1, 1, 1, 1)
const ACTION_COLORS := {
	StringName("jump"): Color(0.6, 0.9, 1.0),
	StringName("sprint"): Color(0.6, 1.0, 0.7),
	StringName("interact"): Color(1.0, 0.85, 0.6),
	StringName("pause"): Color(1.0, 0.6, 0.7)
}

const BUTTON_BG_COLOR := Color(0.4, 0.4, 0.4, 0.5)
const BUTTON_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const BUTTON_BORDER_WIDTH := 1.5
const CORNER_RADIUS := 999.0
const ICON_PREFIX := "res://assets/core/button_prompts/mobile/icon_"
const ICON_SUFFIX := ".svg"

const BRIDGE_MODE_NONE := 0
const BRIDGE_MODE_INPUT_ACTION := 1
const BRIDGE_MODE_PAUSE_TOGGLE := 2

const ACTION_BRIDGE_MODES := {
	StringName("interact"): BRIDGE_MODE_INPUT_ACTION,
	StringName("pause"): BRIDGE_MODE_PAUSE_TOGGLE,
}

@onready var _icon_texture_rect: TextureRect = null
```

- [ ] **Step 2: Keep all existing member variables but replace scene node refs**

Remove `_button_texture_rect: TextureRect` and `_action_label: Label`. Keep everything else intact.

Replace the `@onready` block (line 49-50) and the member vars section (lines 52-56) with:

```gdscript

var _touch_id: int = -1
var _is_pressed: bool = false
var _is_repositioning: bool = false
var _touch_offset_from_control: Vector2 = Vector2.ZERO
var _store: I_StateStore = null
var _is_icons_loaded: bool = false
```

- [ ] **Step 3: Rewrite _ready()**

Replace `_ready()` (lines 58-67) with:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_icon_texture_rect = get_node_or_null("ActionIcon") as TextureRect
	_ensure_default_size()
	_apply_button_style()
	_load_icon()
	_apply_release_visuals()
```

- [ ] **Step 4: Remove old texture/label methods, add new style/icon methods**

Remove these methods entirely:
- `_apply_button_texture()` (lines 139-149)
- `_refresh_label()` (lines 151-169)
- `_get_localized_action_label()` (lines 161-170 — note these use `_refresh_label` internally)
- `_load_texture()` (lines 248-252)
- `button_texture` export variable (line 17)

Add these new methods after `_ensure_default_size()`:

```gdscript
func _apply_button_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_BG_COLOR
	style.border_color = BUTTON_BORDER_COLOR
	style.border_width_left = BUTTON_BORDER_WIDTH
	style.border_width_right = BUTTON_BORDER_WIDTH
	style.border_width_top = BUTTON_BORDER_WIDTH
	style.border_width_bottom = BUTTON_BORDER_WIDTH
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	add_theme_stylebox_override("normal", style)

func _load_icon() -> void:
	if _icon_texture_rect == null:
		return
	if action == StringName():
		return
	var icon_path: String = ICON_PREFIX + String(action) + ICON_SUFFIX
	var texture: Texture2D = load(icon_path) as Texture2D
	if texture == null:
		return
	var tint: Color = ACTION_COLORS.get(action, Color(1, 1, 1, 0.9))
	_icon_texture_rect.texture = texture
	_icon_texture_rect.modulate = tint
	_is_icons_loaded = true

func _refresh_icon() -> void:
	if _icon_texture_rect == null:
		return
	var tint: Color = ACTION_COLORS.get(action, Color(1, 1, 1, 0.9))
	_icon_texture_rect.modulate = tint
```

- [ ] **Step 5: Update _press() and _apply_release_visuals() to use StyleBoxFlat color swap instead of modulate**

Keep `_press()` and `_apply_release_visuals()` structurally the same but ensure they still work with the StyleBoxFlat background + icon tint. The pressed/release visuals use the `Control.modulate` and `scale` properties which are already correct for the visual contract.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/ui/hud/ui_virtual_button.gd
git commit -m "feat: replace virtual button SVG texture with StyleBoxFlat circle + SVG icon"
```

---

### Task 3: Update ui_virtual_button.tscn Scene

**Files:**
- Modify: `scenes/core/ui/widgets/ui_virtual_button.tscn`

- [ ] **Step 1: Replace ButtonTexture + ActionLabel with ActionIcon**

The current scene has `ButtonTexture` (TextureRect) and `ActionLabel` (Label) as children. Replace both with a single `ActionIcon` (TextureRect). Edit the `.tscn` file:

Replace lines 13-31 (the `ButtonTexture` and `ActionLabel` nodes) with:

```
[node name="ActionIcon" type="TextureRect" parent="." unique_id=1344557202]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -24.0
offset_top = -24.0
offset_right = 24.0
offset_bottom = 24.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
```

Note: The `unique_id` is reused from `ButtonTexture` to keep the scene's internal ID consistent. The `unique_name_in_owner = true` is kept so `get_node("%ActionIcon")` works.

- [ ] **Step 2: Remove the old `button_texture` export that was set on the root node**

The old scene doesn't set `button_texture` on the root node (it defaults to null in the script which triggers `_load_texture(DEFAULT_TEXTURE_PATH)`). The new script has no `button_texture` export, so this is fine.

- [ ] **Step 3: Commit**

```bash
git add scenes/core/ui/widgets/ui_virtual_button.tscn
git commit -m "feat: replace ButtonTexture+ActionLabel with ActionIcon in virtual button scene"
```

---

### Task 4: Update Preview Helper and MobileControls References

**Files:**
- Modify: `scripts/core/ui/helpers/u_touchscreen_preview_helper.gd:82-83`
- Modify: `scripts/core/ui/hud/ui_mobile_controls.gd:120-123`

- [ ] **Step 1: Remove _refresh_label() call from preview helper**

In `u_touchscreen_preview_helper.gd`, replace lines 79-85:

```gdscript
			button_instance.name = "PreviewButton_%s" % String(actions[index])
			if "action" in button_instance:
				button_instance.action = actions[index]
			if button_instance.has_method("_refresh_label"):
				button_instance._refresh_label()
			button_instance.process_mode = Node.PROCESS_MODE_DISABLED
```

With:

```gdscript
			button_instance.name = "PreviewButton_%s" % String(actions[index])
			if "action" in button_instance:
				button_instance.action = actions[index]
			if button_instance.has_method("_refresh_icon"):
				button_instance._refresh_icon()
			button_instance.process_mode = Node.PROCESS_MODE_DISABLED
```

- [ ] **Step 2: Remove _refresh_label() call from ui_mobile_controls.gd**

In `ui_mobile_controls.gd`, replace lines 120-123:

```gdscript
func _on_locale_changed(_locale: StringName) -> void:
	for button in _buttons:
		if button != null and button.has_method("_refresh_label"):
			button._refresh_label()
```

With:

```gdscript
func _on_locale_changed(_locale: StringName) -> void:
	pass
```

The `_on_locale_changed` method stays (it's connected as a signal). We just make it a no-op since icons don't need localization.

- [ ] **Step 3: Commit**

```bash
git add scripts/core/ui/helpers/u_touchscreen_preview_helper.gd scripts/core/ui/hud/ui_mobile_controls.gd
git commit -m "feat: update preview helper and MobileControls for icon-based virtual buttons"
```

---

### Task 5: Update Tests

**Files:**
- Modify: `tests/unit/ui/test_virtual_button.gd` (visual feedback test tweak)
- No other test files need changes (all behavioral tests use `_create_button()` which creates script instances directly — they never access scene nodes)

- [ ] **Step 1: Verify test_virtual_button.gd still passes after the changes**

Run all virtual button tests:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_virtual_button.gd
```

Expected: all tests pass (or identify changes needed).

- [ ] **Step 2: Verify visual feedback test passes as-is**

The `test_visual_feedback_updates_on_press_and_release` test checks:
1. Press changes `modulate` and `scale` from defaults
2. Release restores `modulate` to `Color(1,1,1,1)` and `scale` to `Vector2.ONE`

The new implementation still applies `modulate = PRESSED_MODULATE` / `modulate = RELEASED_MODULATE` on the root `Control`, and `scale = PRESSED_SCALE` / `scale = RELEASED_SCALE`. This is identical. The test should pass unchanged.

- [ ] **Step 3: Run the full mobile controls test suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_virtual_button.gd && \
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_mobile_controls.gd && \
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_touchscreen_system.gd && \
tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_touchscreen_input_flow.gd
```

Expected: all pass.

- [ ] **Step 4: Run style enforcement suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: pass. The style suite checks scene node counts — since we go from 2 children to 1, the count assertion at `"res://scenes/core/ui/widgets/ui_virtual_button.tscn": 4` may need updating. If the scene has a root node + 1 child = 2 nodes + UID header = the count should change. Adjust the style test if needed.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/ui/test_virtual_button.gd
git commit -m "test: update virtual button tests for icon-based visuals (GREEN)"
```

---

### Task 6: Regenerate Scenes and Final Verification

- [ ] **Step 1: Regenerate all scenes via headless Godot**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd
```

Expected: "Rebuilding scenes... Done. Scenes rebuilt."

- [ ] **Step 2: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: all tests pass.

- [ ] **Step 3: Run style enforcement suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: pass.

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "chore: verify full test suite after virtual button redesign (GREEN)"
```
