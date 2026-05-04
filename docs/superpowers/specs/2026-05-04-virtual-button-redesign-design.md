# Virtual Button Visual Redesign — Design

**Date**: 2026-05-04
**Status**: Approved
**Approach**: Buttons adopt joystick's flat StyleBoxFlat style; icons replace text labels

## Goal

Redesign `UI_VirtualButton` visuals to match the recently-migrated Godot `VirtualJoystick` styling. The joystick uses flat `StyleBoxFlat` circles (no gradients, borders, or shadows). The buttons currently use an SVG texture (`button_background.svg`) with radial gradients, stroke borders, and drop shadows — a completely different design language.

## Background

- Commit `2c4427e5` replaced the custom joystick with Godot 4.7's built-in `VirtualJoystick`, applying `StyleBoxFlat` with solid gray colors as the theme overrides.
- The joystick base uses `Color(0.2, 0.2, 0.2, 0.3)` and the tip uses `Color(0.4, 0.4, 0.4, 0.8)`.
- The `UI_VirtualButton` still uses `button_background.svg` (96px, radial gradient, stroke, drop shadow, highlight ellipse) loaded into a `TextureRect`.
- The button's `ActionLabel` renders localized text inside the circle, tinted per-action.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Buttons adopt joystick's flat style | Consistency — players already see the joystick; a second style is jarring |
| `StyleBoxFlat` circle (no SVG texture) | Matches joystick exactly; procedural, no asset loading |
| Subtle border: 1.5px solid rgba(255,255,255, 0.15) | Adds definition without the busy gradients/shadows of the old SVG |
| SVG icons replace text labels | More modern, universal (no localization needed), cleaner at small sizes |
| Per-action colors retained for icon tint only | Background is uniform gray across all buttons; action identity comes from icon shape + tinted color |
| Jump = up chevron (^), Sprint = horizontal double chevron (>>), Interact = target circle with center dot, Pause = double bar | Clean geometric shapes that render well at 30-50px |

## Changes

### 1. New SVG Icon Assets

**Location**: `assets/core/button_prompts/mobile/`

| File | Shape | Description |
|------|-------|-------------|
| `icon_jump.svg` | Up chevron | `M6 16l6-10 6 10` |
| `icon_sprint.svg` | Horizontal double chevron | `M5 6l10 6-10 6` + `M13 6l7 6-7 6` |
| `icon_interact.svg` | Target circle + dot | Outer ring r=8, inner dot r=3 |
| `icon_pause.svg` | Double bar | 2 rectangles |

Strokes use currentColor with no fill (except the inner interact dot and pause bars). The `modulate` property on the `TextureRect` will apply the per-action tint color — SVGs should use `stroke="currentColor"` so the icon inherits the color from modulate.

### 2. `UI_VirtualButton` Script Changes

**File**: `scripts/core/ui/hud/ui_virtual_button.gd`

- **Remove**: `DEFAULT_TEXTURE_PATH` constant, `button_background.svg` texture loading, label-related constants (`ACTION_LABEL_KEYS`, `U_LOCALIZATION_UTILS` preload, text-related label methods)
- **Remove**: `_action_label: Label` member, `_button_texture_rect: TextureRect` member
- **Add**: `_icon_texture_rect: TextureRect` member (replaces both)
- **Add**: `DEFAULT_ICON_PREFIX := "res://assets/core/button_prompts/mobile/icon_"` constant
- **Add**: `_create_button_style() -> StyleBoxFlat` — creates the button background style and applies via `add_theme_stylebox_override`
- **Add**: `_load_action_icon(action: StringName) -> Texture2D` — loads SVG from the prefix + action name
- **Modify**: `_ready()` — create and apply StyleBoxFlat to self (Control), load action icon into `_icon_texture_rect`
- **Modify**: Scene node references change from `ButtonTexture` + `ActionLabel` to just `ActionIcon`
- **Retain unchanged**: All touch handling (`_input`, `_handle_touch_press`, `_handle_touch_release`, `_handle_drag`), bridge modes, repositioning, position save/restore, `ACTION_COLORS` (now used for `_icon_texture_rect.modulate` only), pressed/release visuals

### 3. Scene File Changes

**File**: `scenes/core/ui/widgets/ui_virtual_button.tscn`

- **Remove**: `ButtonTexture` (TextureRect), `ActionLabel` (Label)
- **Add**: `ActionIcon` (TextureRect) — centered in parent, default size 100x100, `mouse_filter = IGNORE`

Note: Scenes must be regenerated via builder, not edited by hand. The builder script (`tools/rebuild_scenes.gd`) will be updated to emit the new node structure.

### 4. Settings/Preview Helpers

**Files**: `scripts/core/ui/helpers/u_touchscreen_preview_helper.gd`

- Must update any preview button instancing to use the new icon-based approach.

## What Stays the Same

- Touch event handling (tap/hold modes, multi-touch ID tracking, drag-to-reposition, cancel on drag-out)
- Bridge modes (`interact` → `Input.action_press/release`, `pause` → Redux toggle)
- Position save/restore via `U_InputActions.save_virtual_control_position`
- Runtime scale/opacity properties from Redux `touchscreen_settings`
- All existing signal contracts (`button_pressed`, `button_released`)
- Pressed visual mechanic (scale 95% + modulate darken)

## Test Impact

Existing `test_virtual_button.gd` (14 tests) must be updated:
- Tests referencing `ButtonTexture` node or `ActionLabel` node need to reference `ActionIcon` instead
- Tests asserting label text content should instead assert the icon texture exists and has the right tint
- Tests for tap/hold, reposition, touch ID tracking, bridge behavior remain structurally identical

No new tests needed — this is a visual-only change with the same behavioral contracts.
