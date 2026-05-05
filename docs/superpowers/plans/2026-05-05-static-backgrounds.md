# Task G: Replace Shader Backgrounds with Static Images — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace animated shader backgrounds with static PNG images, eliminating per-frame GPU cost and `_process()` overhead on all menu screens.

**Architecture:** `BaseMenuScreen._resolve_background_rect()` gains a sibling detection for `TextureRect` named `BackgroundImage`. When found, the image is used as background and shader setup/updates are skipped entirely. Same logic added to `UI_LoadingScreen`. All 9 scenes with shader backgrounds are migrated to use static images.

**Tech Stack:** Godot 4.7 (GDScript), GUT test framework, PixelLab MCP (images already generated)

---

## Task 1: Add BackgroundImage detection to BaseMenuScreen

**Files:**
- Modify: `scripts/core/ui/base/base_menu_screen.gd`
- Modify: `tests/unit/ui/test_base_ui_classes.gd`

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/ui/test_base_ui_classes.gd`:

```gdscript
func test_background_image_skips_shader_setup() -> void:
	var scene := BaseMenuScene.new()
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	scene.add_child(bg_image)
	scene.background_shader_preset = "retro_grid"
	scene._ready()
	assert_null(scene.get("_background_shader_material"), "Should skip shader when BackgroundImage present")
	assert_null(scene.get("_background_rect"), "Should not set _background_rect when BackgroundImage present")
	scene.free()

func test_background_image_takes_priority_over_color_rect() -> void:
	var scene := BaseMenuScene.new()
	var color_rect := ColorRect.new()
	color_rect.name = "Background"
	scene.add_child(color_rect)
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	scene.add_child(bg_image)
	scene.background_shader_preset = "retro_grid"
	scene._ready()
	assert_null(scene.get("_background_shader_material"), "BackgroundImage should take priority")
	scene.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_base_ui_classes.gd`
Expected: FAIL — `_background_shader_material` will be set because BackgroundImage detection doesn't exist yet.

- [ ] **Step 3: Implement BackgroundImage detection in BaseMenuScreen**

In `base_menu_screen.gd`, add:

```gdscript
const BACKGROUND_IMAGE_BY_PRESET := {
	BACKGROUND_SHADER_PRESET_RETRO_GRID: "res://assets/core/textures/bg_menu_main.png",
	BACKGROUND_SHADER_PRESET_SCANLINE_DRIFT: "res://assets/core/textures/bg_menu_pause.png",
	BACKGROUND_SHADER_PRESET_ARCADE_NOISE: "res://assets/core/textures/bg_game_over.png",
}

var _background_image: TextureRect = null
```

Modify `_resolve_background_rect()` → rename to `_resolve_background()` and have it check for `BackgroundImage` first:

```gdscript
func _resolve_background() -> Control:
	var bg_image := get_node_or_null("BackgroundImage") as TextureRect
	if bg_image != null:
		return bg_image
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		return background
	var overlay_background := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		return overlay_background
	return get_node_or_null("ColorRect") as ColorRect
```

Update `_setup_background_shader()`:
```gdscript
func _setup_background_shader() -> void:
	var bg := _resolve_background()
	if bg == null:
		return

	if bg is TextureRect:
		_background_image = bg
		_background_rect = null
		return

	_background_rect = bg as ColorRect

	if background_shader_preset == BACKGROUND_SHADER_PRESET_NONE:
		return

	var preset_mode := _get_background_shader_mode(background_shader_preset)
	if preset_mode < 0:
		return

	var shader_material := _background_rect.material as ShaderMaterial
	if shader_material == null or shader_material.shader != MENU_FULLSCREEN_SHADER:
		shader_material = ShaderMaterial.new()
		shader_material.shader = MENU_FULLSCREEN_SHADER
		_background_rect.material = shader_material

	_background_shader_material = shader_material
	_apply_background_shader_uniforms(preset_mode)
```

Update `_update_background_shader_state()`:
```gdscript
func _update_background_shader_state() -> void:
	if _background_image != null:
		return

	if background_shader_preset == BACKGROUND_SHADER_PRESET_NONE:
		return

	if _background_rect == null or not is_instance_valid(_background_rect):
		_setup_background_shader()

	if _background_shader_material == null:
		return

	var preset_mode := _get_background_shader_mode(background_shader_preset)
	if preset_mode < 0:
		return
	_apply_background_shader_uniforms(preset_mode)
```

Update `_has_backdrop_layer()`:
```gdscript
func _has_backdrop_layer() -> bool:
	return _resolve_background() != null
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_base_ui_classes.gd`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/base/base_menu_screen.gd tests/unit/ui/test_base_ui_classes.gd
git commit -m "(RED/GREEN) Add BackgroundImage detection to BaseMenuScreen"
```

---

## Task 2: Add BackgroundImage detection to UI_LoadingScreen

**Files:**
- Modify: `scripts/core/ui/hud/ui_loading_screen.gd`
- Modify: `tests/unit/ui/test_ui_loading_screen.gd` (create or extend)

- [ ] **Step 1: Write the failing test**

Add to tests for loading screen:

```gdscript
func test_loading_screen_background_image_skips_shader() -> void:
	var screen := UI_LoadingScreen.new()
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	screen.add_child(bg_image)
	screen.background_shader_preset = "scanline_drift"
	screen._ready()
	assert_null(screen.get("_background_shader_material"), "Should skip shader when BackgroundImage present")
	screen.free()
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement in ui_loading_screen.gd**

Add same `BACKGROUND_IMAGE_BY_PRESET` constant. Add `var _background_image: TextureRect = null`. Modify `_setup_background_shader()` to check for `BackgroundImage` child first — if found, set `_background_image` and return without shader setup. Add early return in `_apply_background_shader_uniforms()` if `_background_image != null`.

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/hud/ui_loading_screen.gd tests/unit/ui/test_ui_loading_screen.gd
git commit -m "(RED/GREEN) Add BackgroundImage detection to UI_LoadingScreen"
```

---

## Task 3: Migrate menu scenes to BackgroundImage (retro_grid)

**Files:**
- Modify: `scenes/core/ui/menus/ui_main_menu.tscn`
- Modify: `scenes/core/ui/menus/ui_victory.tscn`

These scenes use `background_shader_preset = "retro_grid"`. The `.tscn` changes are:

1. Add ext_resource for `bg_menu_main.png` texture
2. Remove the `Background` ColorRect node (or keep it and add `BackgroundImage` TextureRect sibling)
3. Add `BackgroundImage` TextureRect node with:
   - `texture = ExtResource("bg_menu_main")`
   - `expand_mode = 1` (FIT_WIDTH)
   - `stretch_mode = 5` (SCALE)
   - `anchors_preset = 15` (full rect)
   - Position behind all other children
4. Set `background_shader_preset = "none"` on scene root

**Important:** The `.tscn` files are built by builder scripts. Do NOT edit them by hand per AGENTS.md. Instead, update the builder scripts:

- Find the builder for each menu scene in `scripts/core/ui/builders/`
- Add `BackgroundImage` TextureRect creation in the builder
- Remove the `Background` ColorRect creation from the builder (or keep ColorRect with color as fallback, adding TextureRect on top)
- Set `background_shader_preset = "none"`

Then regenerate: `/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd`

After rebuild, run: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`

- [ ] **Step 1: Update builders for main_menu and victory**
- [ ] **Step 2: Regenerate scenes**
- [ ] **Step 3: Verify scenes in editor**
- [ ] **Step 4: Run style enforcement**
- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/builders/ scenes/core/ui/menus/ && git commit -m "(FIX) Migrate retro_grid menus to static background images"
```

---

## Task 4: Migrate menu scenes to BackgroundImage (scanline_drift)

**Files:**
- Modify builders for: `ui_pause_menu`, `ui_credits`, `ui_loading_screen`
- Modify builders for overlays: `ui_input_profile_selector`, `ui_input_rebinding_overlay`, `ui_edit_touch_controls_overlay`

Same pattern as Task 3 but using `bg_menu_pause.png`.

- [ ] **Step 1: Update builders**
- [ ] **Step 2: Regenerate scenes**
- [ ] **Step 3: Verify and run style enforcement**
- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui/builders/ scenes/ && git commit -m "(FIX) Migrate scanline_drift menus and overlays to static background images"
```

---

## Task 5: Migrate menu scenes to BackgroundImage (arcade_noise)

**Files:**
- Modify builders for: `ui_game_over`, `ui_language_selector`

Same pattern as Task 3 but using `bg_game_over.png`.

- [ ] **Step 1: Update builders**
- [ ] **Step 2: Regenerate scenes**
- [ ] **Step 3: Verify and run style enforcement**
- [ ] **Step 4: Commit**

```bash
git add scripts/core/ui/builders/ scenes/ && git commit -m "(FIX) Migrate arcade_noise menus to static background images"
```

---

## Task 6: Remove shader uniform pushes from _process() when not needed

**Files:**
- Modify: `scripts/core/ui/base/base_menu_screen.gd`
- Modify: `scripts/core/ui/hud/ui_loading_screen.gd`

Currently `_process()` calls `_update_background_shader_state()` every frame even when the background is a static image (the function returns early, but the call still happens). Optimize by checking `_background_image != null` before calling:

```gdscript
func _process(delta: float) -> void:
	if _background_image == null:
		_update_background_shader_state()
	# ... rest of _process unchanged
```

Same for `UI_LoadingScreen._process()` if it has one.

- [ ] **Step 1: Update _process in both files**
- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit**

```bash
git add scripts/core/ui/base/base_menu_screen.gd scripts/core/ui/hud/ui_loading_screen.gd
git commit -m "(OPT) Skip shader update in _process when using static background"
```

---

## Task 7: Add _setup_background_image() — auto-provision for backward compat

**Files:**
- Modify: `scripts/core/ui/base/base_menu_screen.gd`
- Modify: `tests/unit/ui/test_base_ui_classes.gd`

For backward compatibility, if a scene uses a non-"none" preset but hasn't been manually updated (no `BackgroundImage` node), `_setup_background_shader()` should auto-create a `BackgroundImage` TextureRect using the `BACKGROUND_IMAGE_BY_PRESET` mapping and fall back to the image instead of the shader.

```gdscript
func _setup_background_image(preset: String) -> bool:
	if not BACKGROUND_IMAGE_BY_PRESET.has(preset):
		return false
	var texture_path: String = BACKGROUND_IMAGE_BY_PRESET[preset]
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false
	var bg_image := TextureRect.new()
	bg_image.name = "BackgroundImage"
	bg_image.texture = texture
	bg_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg_image.stretch_mode = TextureRect.STRETCH_SCALE
	bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_image.z_index = -1
	add_child(bg_image)
	move_child(bg_image, 0)
	_background_image = bg_image
	return true
```

In `_setup_background_shader()`, before shader logic:

```gdscript
func _setup_background_shader() -> void:
	var existing := get_node_or_null("BackgroundImage") as TextureRect
	if existing != null:
		_background_image = existing
		_background_rect = null
		return

	if background_shader_preset != BACKGROUND_SHADER_PRESET_NONE:
		if _setup_background_image(background_shader_preset):
			return

	# ... existing shader logic unchanged ...
```

This means all 9 scenes automatically get static images even without manual `.tscn` changes. The manual `.tscn` changes in Tasks 3-5 become optional optimizations (reducing scene file size, removing ColorRect nodes, etc.).

- [ ] **Step 1: Write test for auto-provision**
- [ ] **Step 2: Run test (expect fail)**
- [ ] **Step 3: Implement _setup_background_image()**
- [ ] **Step 4: Run test (expect pass)**
- [ ] **Step 5: Commit**

```bash
git add scripts/core/ui/base/base_menu_screen.gd tests/unit/ui/test_base_ui_classes.gd
git commit -m "(GREEN) Add auto-provision of BackgroundImage for backward compat"
```

---

## Task 8: Final integration verification

- [ ] **Step 1: Run full test suite**
- [ ] **Step 2: Run style enforcement**
- [ ] **Step 3: Verify all scenes have `background_shader_preset = "none"` or `BackgroundImage`**
- [ ] **Step 4: Commit any fixes**

```bash
tools/run_gut_suite.sh
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```