# UI Visual Overhaul — PRD

## Overview

- Feature name: UI Visual Overhaul
- Owner: Template team
- Target release: Post "UI, Layers & Transitions Refactor"

## Problem Statement

- The template's UI is functionally complete but visually bare: all styling is inline `theme_override_*` per scene (119 overrides across 13 `.tscn` files), no global Theme resource, no animation/motion system, and the HUD has only 4 widgets (health bar, checkpoint toast, signpost, interact prompt).
- Developers adopting this template get a working UI stack but must build all visual polish from scratch — theming, transitions, HUD modules, and designer tooling. This gap makes the template feel prototype-grade rather than production-ready.

## Goals

- Centralized, swappable Theme resource that integrates with the existing `U_LocalizationFontApplier` font cascade — one resource swap changes the entire visual identity.
- Resource-driven UI motion/animation framework (enter/exit, hover/press, focus) decoupled from sound.
- Migrate all inline `theme_override_*` to the global Theme resource.
- Polish all existing screens with consistent visual language and contextual motion.
- Enhance existing HUD by migrating inline styles and extracting hardcoded tween params to motion resources.
- AAA-quality visual polish with a minimal/cinematic aesthetic — no functionality changes.

## Non-Goals

- Changing existing UI functionality or control flow.
- Replacing `U_LocalizationFontApplier` — the new theme system extends it, not replaces it.
- Adding sound/audio integration to the motion framework (stays decoupled from `U_UISoundPlayer`).
- Custom rendering or shader-based UI effects (stays within Godot's built-in Theme/StyleBox system).
- Changing the health bar's dynamic palette-driven fill behavior (color-blind accessibility).
- New HUD widgets (notification queue, objective tracker, currency/score, timer, minimap slot) — deferred to a future pass.
- `@tool` editor preview scripts — deferred to a future pass.
- Animated number ticker utility — deferred to a future pass.

## User Experience Notes

- **Developers**: Assign a single `RS_UIThemeConfig` resource to change the entire UI look. Assign `RS_UIMotionSet` resources to panels/buttons for animation.
- **End users**: Menus animate in/out, buttons respond to hover/press with motion, HUD elements have consistent styling. All of this is invisible — it just feels polished.

## Technical Considerations

- **Prerequisite**: The "UI, Layers & Transitions Refactor" (7 phases in `docs/general/ui_layers_transitions_refactor/`) must be complete before starting this work. That refactor establishes the layer stack, ServiceLocator container registration, and Redux-driven HUD visibility that this overhaul builds on.
- **Integration point**: `U_LocalizationFontApplier.build_theme()` already creates a Theme per UI root. The new `U_UIThemeBuilder` merges styleboxes/sizes onto that output. If no font applier is available, it works standalone.
- **Config access**: `U_UIThemeBuilder.active_config` static var, set in `root.gd` via preload. No ServiceLocator involvement (ServiceLocator only accepts Node instances).
- **Unified theme pipeline**: Two existing systems (`U_LocalizationFontApplier` for fonts, `U_DisplayUIThemeApplier` for palette colors) both overwrite `control.theme =` independently — latent last-writer-wins bug. `U_UIThemeBuilder` becomes the single composition point: takes font applier output + palette + theme config → one merged Theme. Both existing appliers feed INTO the builder rather than applying independently. Fixes existing bug AND accommodates new styleboxes/spacing.
- **Existing systems**: `U_DisplayUIThemeApplier` (`scripts/managers/helpers/display/u_display_ui_theme_applier.gd`) currently applies palette colors to UI roots independently. `U_PaletteManager` (`scripts/managers/helpers/u_palette_manager.gd`) and `RS_UIColorPalette` provide the color-blind palette system. Both are subsumed into the unified pipeline in Phase 0C.
- **Mobile compatibility**: All resources use `preload()` / `const` arrays — no runtime `DirAccess` scanning.
- **Backward compatibility**: All new features are opt-in via exported resources. `null` resource = zero behavioral change.

## Success Metrics

- All 119 inline `theme_override_*` values migrated to the global Theme resource (zero remaining in `.tscn` files, except 4 per-element semantic overrides in `ui_virtual_button.tscn`).
- All existing screens (23 scenes including overlays and HUD components) polished with theme and motion.
- All existing screens animate on enter/exit when a motion set is assigned.
- HUD tween params (checkpoint toast, signpost) extracted to motion resources.
- All tests pass (existing + new).
- Manual smoke test: menus animate, buttons respond, HUD styling consistent, checkpoint toasts animate.
- Health bar background uses theme; fill remains palette-driven (color-blind accessibility preserved).

## Resolved Questions

### 1. Default Cinematic Theme Values

Derived from auditing all inline `theme_override_*` across `.tscn` files (excluding `addons/gut/`).

#### Typography (font sizes)

| Token | Size | Derived from |
|-------|------|-------------|
| `title` | 48 | Loading screen title |
| `heading` | 32 | Health label, loading subtitle |
| `subheading` | 24 | Save/load title, button prompt action text |
| `body` | 22 | Signpost body text |
| `body_small` | 18 | HUD labels, virtual button, loading hint |
| `caption` | 16 | HUD caption text |
| `section_header` | 14 | Settings section headers, sub-labels |
| `caption_small` | 12 | Button prompt sub-label |

#### Color Palette — Duel (256-color) from [Lospec](https://lospec.com/palette-list/duel)

| Token | Hex | Godot Color | Role |
|-------|-----|-------------|------|
| `bg_base` | `#1d1d21` | `Color(0.114, 0.114, 0.129, 1)` | Deepest background, screen clear |
| `bg_panel` | `#282b4a` | `Color(0.157, 0.169, 0.290, 1)` | Panel/card backgrounds |
| `bg_panel_light` | `#3b3855` | `Color(0.231, 0.220, 0.333, 1)` | Elevated panels, hover states |
| `bg_surface` | `#434549` | `Color(0.263, 0.271, 0.286, 1)` | Input fields, slider tracks |
| `text_primary` | `#f5f7fa` | `Color(0.961, 0.969, 0.980, 1)` | Primary body text |
| `text_secondary` | `#cdd2da` | `Color(0.804, 0.824, 0.855, 1)` | Secondary/muted text |
| `text_disabled` | `#828b98` | `Color(0.510, 0.545, 0.596, 1)` | Disabled/placeholder text |
| `accent_primary` | `#41b2e3` | `Color(0.255, 0.698, 0.890, 1)` | Buttons, links, focus rings |
| `accent_hover` | `#52d2ff` | `Color(0.322, 0.824, 1.000, 1)` | Hover highlight |
| `accent_pressed` | `#318eb8` | `Color(0.193, 0.557, 0.722, 1)` | Pressed/active state |
| `accent_focus` | `#55b1f1` | `Color(0.333, 0.694, 0.945, 1)` | Focus outline/ring |
| `section_header` | `#96b2d9` | `Color(0.588, 0.698, 0.851, 1)` | Settings section header text |
| `danger` | `#e45c5f` | `Color(0.894, 0.361, 0.373, 1)` | Delete, danger actions |
| `success` | `#7da42d` | `Color(0.490, 0.643, 0.176, 1)` | Completion, positive |
| `warning` | `#ffbc4e` | `Color(1.000, 0.737, 0.306, 1)` | Warnings, timer threshold |
| `golden` | `#ecc581` | `Color(0.925, 0.773, 0.506, 1)` | Signpost text, special callouts |
| `health_bg` | `#3a4568` | `Color(0.227, 0.271, 0.408, 1)` | Health bar background |
| `slider_fill` | `#41b2e3` | `Color(0.255, 0.698, 0.890, 1)` | Slider filled area |
| `slider_bg` | `#434549` | `Color(0.263, 0.271, 0.286, 1)` | Slider track background |

> **Note:** Health bar fill color is dynamically set by `U_PaletteManager` based on health percentage and color-blind mode (success/warning/danger). Only the background (`health_bg`) is theme-driven. `health_fill` is intentionally excluded from the theme config.

**Semantic per-element overrides** (stay in `.tscn`, NOT in theme):
- Signpost golden text — uses `golden` from palette but stays as a per-node override (not every Label should be golden)
- Save/load danger red — uses `danger` from palette, per-node override
- Virtual button text — per-node override (mobile-only widget)

#### Spacing

| Token | Value | Derived from |
|-------|-------|-------------|
| `margin_outer` | 20 | HUD outer margin, debug overlays |
| `margin_section` | 16 | Settings section padding |
| `margin_inner` | 12 | HUD inner containers |
| `separation_large` | 32 | End screen outer VBox |
| `separation_medium` | 24 | End screen inner, credits |
| `separation_default` | 12 | Settings lists, most VBoxes |
| `separation_compact` | 8 | Compact groups, slider rows |

#### StyleBoxes (to define in theme)

- `panel_section`: Settings section panel (currently `section_panel` SubResource in display/audio settings)
- `panel_signpost`: Signpost background panel
- `panel_button_prompt`: Button prompt background
- `separator_header`: Settings header separator line
- `progress_bar_bg` / `progress_bar_fill`: Health bar styles
- `slider_bg` / `slider_fill`: Audio/display slider styles

### 2. RS_UIMotionSet Chaining

**Answer: Support sequential playback (not just parallel).**

The existing HUD already uses sequential tween chaining — both checkpoint toast and signpost use Godot's default sequential tween behavior:
```
tween_property(fade_in) → tween_interval(hold) → tween_property(fade_out)
```

`RS_UIMotionPreset` already has `delay_sec` which handles staggered parallel starts. For true sequential chains (like fade-in → hold → fade-out), each preset in an `Array[RS_UIMotionPreset]` plays **sequentially by default** (matching Godot's `Tween` behavior). Add a `parallel` bool to `RS_UIMotionPreset` — when true, that step runs in parallel with the previous one (maps to `Tween.set_parallel(true)` for that step).

Additionally, add `interval_sec: float` to `RS_UIMotionPreset` — when > 0 and `property_path` is empty, acts as a `tween_interval()` hold step.
