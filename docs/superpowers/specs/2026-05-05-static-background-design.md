# Task G: Replace Shader Backgrounds with Static Images

## Problem

`BaseMenuScreen._process()` pushes shader uniforms every frame for all menu screens. The `sh_menu_fullscreen_shader.gdshader` fragment shader runs a full-screen pass per menu. This is wasteful on mobile and unnecessary — the animated effects are subtle and add no gameplay value.

## Decision

Replace all 3 shader preset modes with static PNG images generated via PixelLab MCP. GTA-style atmospheric painted backgrounds.

## Background Images

| Asset | File | Replaces | Screens |
|-------|------|----------|---------|
| Aurora | `assets/core/textures/bg_menu_main.png` (400×400) | `retro_grid` | Main Menu, Victory |
| Gradient | `assets/core/textures/bg_menu_pause.png` (400×400) | `scanline_drift` | Pause, Credits, Loading, Input Profile Selector, Input Rebinding, Edit Touch Controls |
| CRT Static | `assets/core/textures/bg_game_over.png` (400×400) | `arcade_noise` | Game Over, Language Selector |

400×400 is sufficient because these are gradient/atmospheric images that scale well via `TextureRect.expand_mode`.

## Architecture

### BaseMenuScreen changes

`_resolve_background_rect()` now also checks for a `TextureRect` child named `BackgroundImage`:

- If `BackgroundImage` exists → use it as the background, skip shader setup entirely
- If only `Background`/`OverlayBackground` `ColorRect` exists → fall back to current shader behavior (backward compat)
- `_process()` skips `_update_background_shader_state()` when `BackgroundImage` is present

### Scene changes

For each scene using a shader background:

1. Remove the `Background`/`OverlayBackground` `ColorRect` node from the `.tscn`
2. Add a `BackgroundImage` `TextureRect` node with:
   - `texture = preload("res://assets/core/textures/bg_*.png")`
   - `expand_mode = TextureRect.EXPAND_FIT_WIDTH`
   - `stretch_mode = TextureRect.STRETCH_SCALE`
   - `anchors_preset = 15` (full rect)
   - Positioned behind all other children (z_index or draw order)
3. Set `background_shader_preset = "none"` on the scene

### UI_LoadingScreen changes

`UI_LoadingScreen` duplicates the shader background logic. Apply the same `BackgroundImage` detection:
- Check for `BackgroundImage` child first
- If found, skip shader setup and `_process()` uniform updates
- Replace the `ColorRect` in `ui_loading_screen.tscn` with a `BackgroundImage` `TextureRect`

### Preset → Image mapping

`BaseMenuScreen` gets a new constant mapping shader presets to texture paths:

```gdscript
const BACKGROUND_IMAGE_BY_PRESET := {
    "retro_grid": "res://assets/core/textures/bg_menu_main.png",
    "scanline_drift": "res://assets/core/textures/bg_menu_pause.png",
    "arcade_noise": "res://assets/core/textures/bg_game_over.png",
}
```

This allows `_setup_background_shader()` to auto-create a `BackgroundImage` node if the scene uses a non-"none" preset, enabling backward compat for scenes that haven't been manually updated yet.

## Performance Impact

- Eliminates per-frame `_process()` shader uniform pushes on 9 screens
- Eliminates full-screen fragment shader pass on menu screens
- 400×400 PNGs are ~20-40KB each — negligible memory footprint
- TextureRect with FIT_WIDTH is GPU-cheap (single texture sample per pixel)

## Backward Compatibility

- Scenes without `BackgroundImage` fall back to shader behavior automatically
- `background_shader_preset` export still works for scenes not yet migrated
- The shader file `sh_menu_fullscreen_shader.gdshader` is kept but no longer referenced by migrated scenes

## Test Updates

- `test_base_ui_classes.gd` — update shader material tests to also verify `BackgroundImage` detection
- Add test: `BaseMenuScene` with `BackgroundImage` node skips shader setup
- Add test: `BaseMenuScene` without `BackgroundImage` node falls back to shader