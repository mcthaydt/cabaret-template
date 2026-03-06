# UI Visual Overhaul — Tasks (Screen-by-Screen)

**Progress:** 63% (106 / 168 tasks complete)

**Approach:** TDD where possible. Write/update tests BEFORE implementation, then make them pass. Manual smoke tests for visual feel that can't be automated.

## Prerequisite

- [x] Confirm "UI, Layers & Transitions Refactor" is complete (all 7 phases in `docs/general/ui_layers_transitions_refactor/`) — completed 2026-03-03, branch `UI-Looksmaxxing`
- [x] Confirm test baselines: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` — baselines green

---

## Phase 0 — Infrastructure (Minimal)

Build just enough shared infrastructure so screens have a common visual language.

### 0A — Theme Config Resource

- [x] Create `scripts/resources/ui/rs_ui_theme_config.gd` — `RS_UIThemeConfig extends Resource` with `@export_group` sections:
  - Typography: font sizes for title(48), heading(32), subheading(24), body(22), body_small(18), caption(16), section_header(14), caption_small(12)
  - Colors: Duel palette tokens — bg_base, bg_panel, bg_panel_light, bg_surface, text_primary, text_secondary, text_disabled, accent_primary, accent_hover, accent_pressed, accent_focus, section_header, danger, success, warning, golden, health_bg, slider_fill, slider_bg (note: `health_fill` excluded — dynamically palette-driven for color-blind accessibility)
  - Spacing: margin_outer(20), margin_section(16), margin_inner(12), separation_large(32), separation_medium(24), separation_default(12), separation_compact(8)
  - Button Styles: normal/hover/pressed/focus/disabled `StyleBoxFlat`
  - Panel Styles: panel_section, panel_signpost, panel_button_prompt
  - Bar Styles: progress_bar_bg, progress_bar_fill, slider_bg, slider_fill, slider_grabber, slider_grabber_highlight
  - Focus: focus_stylebox
  - Separator: separator_style
- [x] Create `resources/ui/cfg_ui_theme_default.tres` — default instance with Duel palette values

### 0B — Theme Builder Utility (TDD)

**Write tests first**, then implement to make them pass.

- [x] Create `tests/unit/ui/test_ui_theme_builder.gd` — tests BEFORE implementation:
  - `test_build_theme_returns_theme_with_font_sizes` — build with default config, assert `theme.get_font_size(&"font_size", &"Label") == config.body` (pattern: `test_display_manager.gd`)
  - `test_build_theme_applies_button_styleboxes` — assert `theme.get_stylebox(&"normal", &"Button") is StyleBoxFlat` and `bg_color` matches config
  - `test_build_theme_applies_progress_bar_styles` — assert `theme.get_stylebox(&"fill", &"ProgressBar") is StyleBoxFlat`
  - `test_build_theme_applies_slider_styles` — assert `theme.get_stylebox(&"slider", &"HSlider") is StyleBoxFlat`
  - `test_build_theme_applies_panel_styles` — assert `theme.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat`
  - `test_build_theme_applies_separator_style` — assert `theme.get_stylebox(&"separator", &"HSeparator") is StyleBoxFlat`
  - `test_build_theme_applies_label_colors` — assert `theme.get_color(&"font_color", &"Label").is_equal_approx(config.text_primary)` (pattern: `test_ui_scale_and_theme.gd`)
  - `test_build_theme_merges_onto_font_theme` — create a font-only theme via `U_LocalizationFontApplier.build_theme()`, pass to builder, assert both font AND styleboxes present
  - `test_build_theme_standalone_without_font_theme` — pass `null` base theme, assert Theme returned with styleboxes (no crash)
  - `test_build_theme_null_config_returns_null` — pass `null` config, assert returns `null` (no-op)
  - `test_build_theme_spacing_constants` — assert `theme.get_constant(&"separation", &"VBoxContainer") == config.separation_default`
  - `test_build_theme_merges_palette_colors` — pass palette, assert `theme.get_color(&"font_color", &"Label") == palette.text`
  - `test_build_theme_without_palette_preserves_font_theme` — pass null palette, assert font theme colors untouched
- [x] Create `scripts/ui/utils/u_ui_theme_builder.gd` — static utility: `build_theme(config: Resource, base_font_theme: Theme = null, palette: Resource = null) -> Theme` with runtime validation (`RS_UIThemeConfig`/`RS_UIColorPalette`). Builder merges: fonts from base_font_theme + palette colors (font_color on text types, replaces what `U_DisplayUIThemeApplier._configure_ui_theme()` does) + styleboxes/spacing/sizes from config. Sets type variations for Button, Label, PanelContainer, ProgressBar, HSlider, HSeparator, VBoxContainer, HBoxContainer.
- [x] Run tests — all `test_ui_theme_builder.gd` tests pass

### 0C — Unified Theme Pipeline Integration (TDD)

- [x] Add test to `tests/unit/ui/test_ui_theme_builder.gd`:
  - `test_font_applier_uses_theme_builder_when_config_set` — set `U_UIThemeBuilder.active_config`, call `apply_theme_to_root()`, assert the root's theme has both fonts AND styleboxes
  - `test_font_applier_unchanged_when_no_config_set` — do NOT set `U_UIThemeBuilder.active_config`, call `apply_theme_to_root()`, assert theme has fonts but NOT styleboxes (existing behavior preserved)
  - `test_palette_change_triggers_theme_rebuild` — change palette, assert resulting theme has both font AND palette colors
- [x] Add `static var active_config` to `scripts/ui/utils/u_ui_theme_builder.gd` — set in `root.gd` via preload. No ServiceLocator involvement (ServiceLocator only accepts Node instances). Keep `Resource` typing for headless parser compatibility.
- [x] Modify `scripts/managers/helpers/localization/u_localization_font_applier.gd` — after building the font-only theme, call `U_UIThemeBuilder.build_theme(active_config, font_theme, active_palette)` to compose the full theme when `U_UIThemeBuilder.active_config` is set. If not set, existing font-only behavior unchanged.
- [x] Modify `M_DisplayManager._apply_accessibility_settings()` to trigger theme rebuild through the unified pipeline instead of calling `_ui_theme_applier.apply_theme_to_roots()` independently.
- [x] Modify `U_DisplayUIThemeApplier.apply_theme_from_palette()` — still builds palette data, but the actual theme application goes through `U_UIThemeBuilder` instead of applying independently.
- [x] Run tests — new tests pass, all existing localization and display tests still pass

Completion note (2026-03-05): Implemented 0A-0C in commit `b372980d` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd`
- `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/localization/test_localization_font_applier.gd -gtest=res://tests/unit/managers/test_display_manager.gd -gtest=res://tests/unit/managers/test_display_manager_high_contrast.gd -gtest=res://tests/integration/display/test_ui_scale_and_theme.gd -gtest=res://tests/integration/localization/test_locale_switching.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

Follow-up note (2026-03-06): Fixed unified-theme lifecycle regression caused by shared `root.gd` usage in gameplay scenes.
- Root cause: gameplay scene roots also use `scripts/root.gd`; unconditional `_exit_tree()` cleanup cleared `U_UIThemeBuilder.active_config`, causing later UI screens to render default gray styles.
- Fix: guard theme-config teardown so only the persistent app root (has `Managers/M_StateStore`) clears `U_UIThemeBuilder.active_config`.
- Added regression coverage: `tests/unit/ui/test_root_ui_theme_lifecycle.gd`.
- Validation:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_root_ui_theme_lifecycle.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

Follow-up note (2026-03-06): Fixed mobile/export stylebox hydration gap in unified theme builder.
- Symptom on device: startup logs showed `U_UIThemeBuilder` building with `button_normal_null=true` / `panel_section_null=true`, producing text colors but no panel/button styleboxes (gray default UI chrome).
- Root cause: loaded `cfg_ui_theme_default.tres` can arrive with stylebox fields unset on export paths when hydration depends only on `RS_UIThemeConfig._init()`.
- Fix:
  - Added `RS_UIThemeConfig.ensure_runtime_defaults()` and made `_init()` delegate to it.
  - `U_UIThemeBuilder.build_theme(...)` now calls `ensure_runtime_defaults()` before applying styleboxes/tokens.
- Added regression coverage:
  - `test_build_theme_hydrates_runtime_style_defaults_for_loaded_config_resource` in `tests/unit/ui/test_ui_theme_builder.gd`.
- Validation:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd`
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd -gtest=res://tests/unit/managers/test_display_manager.gd -gtest=res://tests/unit/managers/test_localization_manager.gd`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

### 0D — Motion Resources (TDD)

**Write tests first**, then implement to make them pass.

- [x] Create `tests/unit/ui/test_ui_motion.gd` — tests BEFORE implementation:
  - `test_play_returns_tween_for_valid_presets` — create an `RS_UIMotionPreset` (property_path="modulate:a", from=0.0, to=1.0, duration=0.3), call `U_UIMotion.play(node, [preset])`, assert returns a `Tween`
  - `test_play_applies_property_change` — play a preset, await tween finished, assert `node.modulate.a == 1.0` with `assert_almost_eq(..., 0.01)` (pattern: `test_mobile_controls.gd`)
  - `test_play_sequential_chain` — create 3 presets (fade-in, interval, fade-out), play all, assert sequencing by checking intermediate `modulate.a` values after frame advances
  - `test_play_parallel_presets` — create 2 presets with `parallel=true`, play both, assert they run concurrently (both properties change within same frame window)
  - `test_play_interval_preset` — create preset with empty `property_path` and `interval_sec=0.5`, assert acts as hold (tween duration includes interval)
  - `test_play_null_presets_returns_null` — `U_UIMotion.play(node, [])` returns `null`, no crash
  - `test_play_null_node_returns_null` — `U_UIMotion.play(null, presets)` returns `null`
  - `test_play_enter_delegates_to_motion_set` — create `RS_UIMotionSet` with `enter` presets, call `play_enter()`, assert tween returned
  - `test_play_exit_delegates_to_motion_set` — same for `exit`
  - `test_play_enter_null_motion_set_returns_null` — `play_enter(node, null)` returns `null`, no-op
  - `test_bind_interactive_connects_signals` — call `bind_interactive(button, motion_set)`, assert `mouse_entered`/`mouse_exited`/`focus_entered`/`focus_exited` signals are connected
  - `test_bind_interactive_null_motion_set_no_op` — `bind_interactive(button, null)` does nothing, no crash
- [x] Create `scripts/resources/ui/rs_ui_motion_preset.gd` — single tween recipe: property_path, from_value, to_value, relative, duration_sec, delay_sec, transition_type, ease_type, parallel, interval_sec
- [x] Create `scripts/resources/ui/rs_ui_motion_set.gd` — collection per interaction: enter, exit, hover_in, hover_out, press, focus_in, focus_out, pulse
- [x] Create `scripts/ui/utils/u_ui_motion.gd` — static utility: `play()`, `play_enter()`, `play_exit()`, `bind_interactive()`
- [x] Run tests — all `test_ui_motion.gd` tests pass

Completion note (2026-03-05): Implemented 0D in commit `11571760` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_motion.gd`

### 0E — Default Motion Presets

- [x] Create `resources/ui/motions/cfg_motion_fade_slide.tres` — screen enter/exit (fade + slide-up)
- [x] Create `resources/ui/motions/cfg_motion_button_default.tres` — button hover/press scale
- [x] Create `resources/ui/motions/cfg_motion_hud_pop.tres` — HUD widget pop-in

Completion note (2026-03-05): Implemented 0E in commit `11571760` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_motion.gd -gtest=res://tests/unit/ui/test_ui_theme_builder.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

### 0F — Base Class Integration (TDD)

- [x] Add tests to `tests/unit/ui/test_base_ui_classes.gd`:
  - `test_base_panel_null_motion_set_no_bind` — instantiate BasePanel with `motion_set = null`, assert no signal connections added to focusable children (existing behavior preserved)
  - `test_base_panel_motion_set_binds_focusable_children` — instantiate BasePanel with a motion_set, assert `mouse_entered` signal connected on focusable child buttons
  - `test_base_menu_screen_play_enter_with_motion_set` — assign motion_set with enter presets, call `play_enter_animation()`, assert returns Tween, assert `modulate.a` changes (pattern: `test_mobile_controls.gd`)
  - `test_base_menu_screen_play_enter_without_motion_set_returns_null` — no motion_set assigned, `play_enter_animation()` returns null (no-op)
  - `test_base_overlay_animates_dim_on_enter` — assign motion_set to overlay, assert background `ColorRect.modulate.a` changes alongside content
- [x] Modify `scripts/ui/base/base_panel.gd` — add `@export var motion_set: RS_UIMotionSet = null`; if set, call `U_UIMotion.bind_interactive()` on focusable children
- [x] Modify `scripts/ui/base/base_menu_screen.gd` — add `play_enter_animation()` / `play_exit_animation()` delegating to `U_UIMotion`
- [x] Modify `scripts/ui/base/base_overlay.gd` — animate dim ColorRect alongside content motion
- [x] Run tests — new tests pass, all existing base UI tests still pass

Completion note (2026-03-05): Implemented 0F in commit `3a011b62` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_base_ui_classes.gd`
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_motion.gd -gtest=res://tests/unit/ui/test_pause_menu.gd -gtest=res://tests/unit/ui/test_main_menu.gd -gtest=res://tests/unit/ui/test_settings_menu_visibility.gd -gtest=res://tests/unit/ui/test_save_load_menu.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

### 0G — Full Suite Verification

- [x] Run full test suite: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` — confirm zero regressions
- [x] Run style enforcement: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

Completion note (2026-03-05): Phase 0G verification completed after infrastructure gap patch.
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2793/2802 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing

---

## Phase 1 — Simple Full-Screen Menus

### Screen 1: Main Menu (`scenes/ui/menus/ui_main_menu.tscn`)

- [x] Apply theme resource to root (via font applier integration — automatic)
- [x] Add bg_base ColorRect or background styling
- [x] Style VBoxContainer button group with panel_section background
- [x] Title label uses `title` font size token
- [x] Buttons get accent_primary styling from theme
- [x] Assign `cfg_motion_fade_slide` for enter/exit
- [x] Run existing `test_main_menu.gd` — all tests pass (Redux navigation, button dispatch, quit visibility, focus chain)
- [x] Run full test suite
- [x] **Manual smoke test:** Launch main menu, verify bg color matches bg_base (#1d1d21), buttons have accent_primary (#41b2e3) styling, title is visually larger than button text, enter/exit animation plays smoothly, settings embed still opens

Completion note (2026-03-05): Implemented Screen 1 in commit `aaa7f75c` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2795/2804 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified).

### Screen 2: Game Over (`scenes/ui/menus/ui_game_over.tscn`)

- [x] Migrate separation overrides to theme tokens (separation_large, separation_medium)
- [x] Replace 96px anchor offsets with proper margin container using theme spacing
- [x] Title "Game Over" uses `title` size, danger color
- [x] Death count uses `heading` size, text_secondary
- [x] Buttons styled via theme, bg_base background
- [x] Motion: Fade-in enter, title with slight delay
- [x] Run existing `test_endgame_screens.gd` — all game over tests pass (button dispatch, ui_cancel behavior)
- [x] Run full test suite
- [x] **Manual smoke test:** Die in gameplay, verify game over screen shows with danger-colored title, death count is readable, Retry/Menu buttons work, fade-in animation plays

Completion note (2026-03-05): Implemented Screen 2 in commit `f2fb658a` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2796/2805 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified, 2026-03-06).

### Screen 3: Victory (`scenes/ui/menus/ui_victory.tscn`)

- [x] Same migration as Game Over — separation overrides to theme tokens
- [x] Title "Victory!" uses `title` size, success color
- [x] Stats use text_secondary
- [x] Remove or properly hide disabled Credits button
- [x] Motion: Similar to Game Over with success feel
- [x] Run existing `test_endgame_screens.gd` — all victory tests pass
- [x] Run full test suite
- [x] **Manual smoke test:** Win in gameplay, verify victory screen shows with success-colored title, stats readable, Reset Run/Menu work, fade-in plays

Completion note (2026-03-05): Implemented Screen 3 in commit `b05c75df` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd`
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2797/2806 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified, 2026-03-06).

### Screen 4: Credits (`scenes/ui/menus/ui_credits.tscn`)

- [x] Migrate separation to theme token
- [x] Replace manual spacer Control nodes with proper VBox separation
- [x] Header uses `title`, names use `body`, footer uses `caption`
- [x] Fix Skip button from hardcoded pixel offsets to anchored margin
- [x] bg_base background, fade-in motion
- [x] Run existing `test_endgame_screens.gd` — credits tests pass (auto-return timer, skip)
- [x] Run full test suite
- [x] **Manual smoke test:** Open credits, verify text hierarchy is visually clear (title > body > caption), Skip button is accessible, auto-scroll completes

Completion note (2026-03-05): Implemented Screen 4 in commit `c747d478` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd` → 13/13 passing
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2798/2807 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified).

Follow-up note (2026-03-05): Fixed black-screen regression when opening credits from Victory after overlay snap + instant transition.
- `scripts/scene_management/u_transition_orchestrator.gd` now clears `TransitionColorRect` alpha after instant scene swap.
- Added integration coverage in `tests/integration/scene_manager/test_endgame_flows.gd` to assert overlay alpha is reset on Victory → Credits.

### Screen 5: Language Selector (`scenes/ui/menus/ui_language_selector.tscn`)

- [x] Migrate separations to theme tokens
- [x] Style PanelContainer with panel_section from theme
- [x] Title uses `heading` size, language buttons get accent styling
- [x] bg_base background, fade-in motion
- [x] Run existing `test_language_selector.gd` (if exists) or run full suite
- [x] Run full test suite
- [x] **Manual smoke test:** Clear first-run flag, launch game, verify language selector appears, buttons are styled, selecting a language persists and skips on next launch

Completion note (2026-03-05): Implemented Screen 5 in commit `3a9ab267` and validated with:
- `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_language_selector.gd` → 3/3 passing
- `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2801/2810 passing, 0 failing, 9 pending/risky (headless/mobile-gated)
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified, 2026-03-06).

---

## Phase 2 — Overlay Screens

### Screen 6: Pause Menu (`scenes/ui/menus/ui_pause_menu.tscn`)

- [x] Standardize dim to bg_base at 0.7 alpha (via BaseOverlay export)
- [x] Add panel_section background behind button group
- [x] "Paused" title uses `heading` size, buttons styled via theme
- [x] Overlay fade-in (dim + content), buttons get interactive motion
- [x] Run existing `test_pause_menu.gd` — all tests pass (Resume, settings open, PROCESS_MODE_ALWAYS)
- [x] Run full test suite
- [x] **Manual smoke test:** Pause during gameplay, verify dim background is consistent (#1d1d21 at 0.7), buttons are styled, Resume/Settings/Quit all work, overlay fade-in plays

Completion note (2026-03-06): Implemented Screen 6 (automation + manual-smoke verified) with:
- Scene migration to panel-backed pause layout + motion-set assignment (`cfg_motion_fade_slide`)
- BaseOverlay dim normalization to `bg_base` at 0.7 alpha via theme-token application
- Pause-menu token plumbing (`heading`, `separation_default`, `margin_section`, `panel_section`)
- Integration test hardening by switching pause-menu settings button lookup to `%SettingsButton`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd` → 8/8 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd -gtest=res://tests/unit/ui/test_settings_menu_visibility.gd` → 10/10 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2803/2812 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
Follow-up note (2026-03-06): User manual smoke passed for Screen 6. Enter/exit animation was refined so only the pause panel slides while the dim backdrop remains stationary (fade-only), avoiding visible backdrop cutoff during slide motion.
- Post-refinement verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd` → 10/10 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2804/2813 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Centering follow-up (2026-03-06): Added `MainPanelMotionHost` under `CenterContainer` so slide animation runs on `MainPanel` inside a centered host, preventing drift from true vertical center after animation.
- Default-behavior follow-up (2026-03-06): Promoted panel-only slide behavior to `BaseMenuScreen` so backdrop + centered-panel screens animate content by default while backdrop remains stationary.
  - `BaseMenuScreen` now supports optional `motion_target_path` override and auto-targets `CenterContainer` when a backdrop (`Background` / `OverlayBackground` / `ColorRect`) and `PanelContainer` are present.
  - `UI_PauseMenu` removed local enter/exit animation overrides and now relies on base behavior.
  - Added base coverage in `tests/unit/ui/test_base_ui_classes.gd`: `test_base_menu_screen_targets_center_container_when_backdrop_and_panel_exist`.
  - Hardened `tests/unit/integration/test_input_profile_selector_overlay.gd` by disabling state persistence in test setup to avoid locale bleed-through.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_base_ui_classes.gd -gtest=res://tests/unit/ui/test_pause_menu.gd` → 23/23 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd -gtest=res://tests/unit/ui/test_endgame_screens.gd -gtest=res://tests/unit/ui/test_language_selector.gd` → 30/30 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2806/2815 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing

### Screen 7: Settings Menu (`scenes/ui/menus/ui_settings_menu.tscn`)

- [x] Standardize dim opacity to 0.7 (matching BaseOverlay default; current 0.647 is an outlier)
- [x] Add panel background behind scroll/button list
- [x] "Settings" title uses `heading` size, category buttons styled via theme
- [x] Overlay fade-in, scroll follows focus
- [x] Run existing `test_settings_menu_visibility.gd` — all tests pass (8 category buttons, back, embedded mode)
- [x] Run full test suite
- [x] **Manual smoke test:** Open settings from pause, verify all 8 categories open correct overlays, back works, dim is consistent with pause menu. Open settings from main menu embedded mode — verify no dim, panel background visible.

Completion note (2026-03-06): Implemented Screen 7 with centered panel/scroll layout, `cfg_motion_fade_slide`, theme-token application (`heading`, `margin_section`, `separation_default`, `panel_section`), and context-aware dim behavior (`0.7` in overlay mode, `0.0` when embedded in main menu).
- Implementation commit: `ca75551a`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_menu_visibility.gd -gtest=res://tests/unit/ui/test_pause_menu.gd -gtest=res://tests/unit/ui/test_main_menu.gd` → 29/29 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2809/2818 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test passed (user-verified on 2026-03-06).

### Screen 8: Save/Load Menu (`scenes/ui/overlays/ui_save_load_menu.tscn`)

- [x] Migrate error color to `danger` token (keep as semantic per-node override)
- [x] Migrate font sizes to theme tokens (section_header, subheading)
- [x] Style slot list items, loading spinner uses consistent styling
- [x] Overlay fade-in, slot selection feedback
- [x] Run existing `test_save_load_menu.gd` — all tests pass (Save/Load/Delete/Overwrite, mode detection, confirmation)
- [x] Run full test suite
- [x] **Manual smoke test:** Open save/load from pause, verify error text is danger-colored, slot items are styled, loading spinner visible during operations

Completion note (2026-03-06): Implemented Screen 8 with centered panel-backed layout, `cfg_motion_fade_slide`, theme-token application (`danger`, `subheading`, `section_header`, `margin_section`, `separation_default`, `separation_compact`, `panel_section`), and tokenized slot-row styling for runtime-created items.
- Implementation commit: `c969b7f4`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_save_load_menu.gd -gtest=res://tests/unit/ui/test_save_load_menu_localization.gd` → 14/14 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2810/2819 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified on 2026-03-06).

Follow-up note (2026-03-06): Confirmation dialog chrome was still rendering with default gray window styling in save/load flows.
- Initial fix attempt tokenized `ConfirmationDialog` and `Window` `panel` paths, but `Window` chrome still rendered gray because Godot uses embedded border stylebox keys for window chrome.
- Regression coverage added: `tests/unit/ui/test_ui_theme_builder.gd::test_build_theme_applies_dialog_window_panel_styles`.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd -gtest=res://tests/unit/ui/test_save_load_menu.gd` → 31/31 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Implementation commit: `1b91c156`

Follow-up correction (2026-03-06): Applied the actual `Window` chrome keys used by Godot.
- Fix applied in shared theme builder: `Window.embedded_border` + `Window.embedded_unfocused_border` now use `panel_section`, plus themed `title_color`/`title_outline_modulate`.
- Regression test updated to assert embedded border styleboxes and title colors on `Window`.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd -gtest=res://tests/unit/ui/test_save_load_menu.gd` → 31/31 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Implementation commit: `2f61c70f`

### Screens 9-13: Remaining Overlays (batch)

- [x] **9. Input Rebinding** (`ui_input_rebinding_overlay.tscn`) — migrated to overlay-panel pattern with tokenized styling + dialog theming support.
- [x] **10. Input Profile Selector** (`ui_input_profile_selector.tscn`) — migrated to overlay-panel pattern with tokenized spacing and `bg_base@0.5` dim.
- [x] **11. Gamepad Settings** (`ui_gamepad_settings_overlay.tscn`) — migrated to overlay-panel pattern with tokenized slider/preview styling and `bg_base@0.5` dim.
- [x] **12. Touchscreen Settings** (`ui_touchscreen_settings_overlay.tscn`) — migrated to overlay-panel pattern with tokenized slider/preview styling and `bg_base@0.5` dim.
- [x] **13. Edit Touch Controls** (`ui_edit_touch_controls_overlay.tscn`) — migrated to overlay-panel pattern with tokenized toolbar styling while preserving translucent dim (`bg_base@0.05`).
- [x] Run existing overlay tests (rebinding, input profile, gamepad, touchscreen, edit touch) — all pass
- [x] Run full test suite after batch
- [x] **Manual smoke test:** Open each overlay in sequence, verify dim is consistent (0.5 for most, 0.05 for edit touch), panels styled, sliders functional, preview areas render

Completion note (2026-03-06): Implemented Screen 9 with centered panel-backed layout (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`), `cfg_motion_fade_slide`, and token-driven styling from `U_UIThemeBuilder.active_config` (`heading`, `section_header`, `body_small`, `margin_section`, `separation_default`, `separation_compact`, `panel_section`, `bg_base@0.5`).
- Implementation commit: `3739f301`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/integration/test_rebinding_flow.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2812/2821 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified on 2026-03-06).

Follow-up note (2026-03-06): Addressed Screen 9 usability regressions found during manual smoke.
- Search box now uses tokenized style overrides (`normal`/`focus`/`read_only`, placeholder/caret colors) so it matches panel chrome.
- Keyboard left/right navigation now cycles center row action buttons correctly, and row highlight state stays in sync when focus changes via keyboard/default focus handling.
- Added regression coverage in `tests/unit/ui/test_input_rebinding_overlay.gd`:
  - `test_keyboard_horizontal_navigation_cycles_row_buttons_and_preserves_row_highlight`
  - Extended token test assertions for search-box style overrides.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/integration/test_rebinding_flow.gd` → 13/13 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Implementation commit: `3ad822c9`
- Manual smoke re-run completed (user-verified on 2026-03-06).

Completion note (2026-03-06): Implemented Screen 10 with centered panel-backed layout (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`), `cfg_motion_fade_slide`, and token-driven styling from `U_UIThemeBuilder.active_config` (`heading`, `subheading`, `body_small`, `section_header`, `margin_section`, `separation_default`, `separation_compact`, `panel_section`, `bg_base@0.5`).
- Implementation commit: `509e75de`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/input/test_input_profile_mobile_regression.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2814/2823 passing, 0 failing, 9 pending/risky
- Manual smoke test completed (user-verified on 2026-03-06).

Completion note (2026-03-06): Implemented Screen 11 with centered panel-backed layout (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`), `cfg_motion_fade_slide`, and token-driven styling from `U_UIThemeBuilder.active_config` (`heading`, `section_header`, `body_small`, `margin_section`, `separation_compact`, `panel_section`, `bg_base@0.5`) including themed preview-panel chrome.
- Implementation commit: `5a40761f`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd` → 3/3 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd` → 1/1 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2815/2824 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Manual smoke test completed (user-verified on 2026-03-06).

Completion note (2026-03-06): Implemented Screen 12 with centered panel-backed layout (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`), `cfg_motion_fade_slide`, and token-driven styling from `U_UIThemeBuilder.active_config` (`heading`, `section_header`, `body_small`, `margin_section`, `separation_default`, `separation_compact`, `panel_section`, `bg_base@0.5`) including themed preview-panel chrome.
- Implementation commit: `1c9f52ab`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 40/40 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2822/2831 passing, 0 failing, 9 pending/risky
- Manual smoke test completed (user-verified on 2026-03-06).

Follow-up note (2026-03-06): Adjusted Screen 12 preview layout after user feedback that joystick/buttons were drifting to the bottom of the preview panel.
- Fix: restored original panel footprint (`560x520`) and wrapped `PreviewContainer` in a centering host (`PreviewCenterContainer`) so preview controls remain visually centered in the bottom preview panel.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing

Follow-up note (2026-03-06): Enforced panel-fit size limits for Screen 12 joystick/button scaling so controls cannot exceed preview panel bounds.
- Fix:
  - Reset flow now dispatches clamped slider values (not raw defaults), so persisted settings cannot bypass panel-fit size limits.
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing

Completion note (2026-03-06): Implemented Screen 13 with centered panel-backed layout (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`), `cfg_motion_fade_slide`, and token-driven styling from `U_UIThemeBuilder.active_config` (`heading`, `section_header`, `body_small`, `margin_section`, `separation_default`, `separation_compact`, `panel_section`, `bg_base@0.05`) while retaining low-opacity grid overlay behavior.
- Implementation commit: `63e0746e`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 7/7 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 41/41 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2823/2832 passing, 0 failing, 9 pending/risky
- Manual smoke test completed (user-verified on 2026-03-06).

### Settings Overlay Wrappers (batch — all 0 overrides)

These wrapper overlays contain the settings tab content. They need theme application and consistent dim styling.

- [x] `ui_audio_settings_overlay.tscn` — wrapper for audio settings tab
- [x] `ui_display_settings_overlay.tscn` — wrapper for display settings tab
- [x] `ui_localization_settings_overlay.tscn` — wrapper for localization settings tab
- [x] `ui_vfx_settings_overlay.tscn` — wrapper for VFX settings (no tab file, standalone)
- [x] Run full test suite after batch

Completion note (2026-03-06): Completed settings-overlay wrapper batch migration.
- Removed legacy inline `Background` `ColorRect` nodes from all four wrappers and standardized on `BaseOverlay` auto `OverlayBackground` dim.
- Added `cfg_motion_fade_slide` assignment to all wrapper roots and invoked `play_enter_animation()` from wrapper `_on_panel_ready()`.
- Added theme-token wrapper styling in overlay controllers:
  - dim uses `bg_base@0.5`,
  - panel chrome uses `panel_section`,
  - wrapper content spacing uses `separation_default`.
- Added wrapper regression coverage: `tests/unit/ui/test_settings_overlay_wrappers.gd` (4 tests).
- Implementation commit: `96df500e`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd -gtest=res://tests/integration/display/test_display_settings.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd -gtest=res://tests/unit/ui/test_vfx_settings_overlay_localization.gd` → 49/49 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2827/2836 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing

Follow-up note (2026-03-06): Phase 2 overlay audit hardening pass completed.
- Gap closures:
  - Normalized input-rebinding dim to `bg_base@0.5` (scene + script + unit test expectations aligned).
  - Standardized close-path behavior for settings-related overlays:
    - `close_top_overlay()` when an overlay stack is present.
    - `navigate_to_ui_screen("settings_menu", "fade", 2)` when returning from main-menu shell without overlays.
    - `set_shell("main_menu", "settings_menu")` retained as non-main-menu fallback.
  - Removed transient debug `print(...)` logging from touchscreen settings overlay close flow.
  - Added style regression guard in `tests/unit/style/test_style_enforcement.gd`:
    - `test_polished_overlay_scenes_have_no_inline_theme_overrides`.
- Verification:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd -gexit` → 4/4 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gexit` → 11/11 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gexit` → 11/11 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gexit` → 6/6 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gexit` → 4/4 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd -gexit` → 10/10 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/display/test_display_settings.gd -gexit` → 17/17 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd -gexit` → 9/9 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd -gexit` → 8/8 passing
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/style/test_style_enforcement.gd -gexit` → 12/12 passing

---

## Phase 3 — Settings Tabs (Override-Heavy)

### Screen 14: Localization Settings Tab (`ui_localization_settings_tab.tscn`)

- [x] Migrate separation (1 override), apply theme to language list
- [x] Run existing localization settings tests — pass
- [x] Run full test suite
- [x] **Manual smoke test:** Open localization settings, verify language list styled, font preview works

Completion note (2026-03-06): Implemented Screen 14 in commit `c94de23c`.
- Removed the final inline `theme_override_constants/separation` from `ui_localization_settings_tab.tscn`.
- Added token-driven localization tab styling in `UI_LocalizationSettingsTab` (`heading`, `section_header`, `body_small`, `section_header_color`, `text_secondary`, `separation_default`, `separation_compact`).
- Added `tests/unit/ui/test_localization_settings_tab_theme.gd` for Screen 14 theme-token coverage.
- Validation:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_localization_settings_tab_theme.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd -gtest=res://tests/unit/ui/test_display_settings_tab_localization.gd -gtest=res://tests/unit/ui/test_audio_settings_tab_localization.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2829/2838 passing, 0 failing, 9 pending/risky
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing

Follow-up note (2026-03-06): Localization overlay centering regression fix in commit `abc897ed`.
- Root cause: wrapper enter motion was auto-targeting `CenterContainer`, which could leave the panel visually offset during/after tween sampling.
- Fix: set `motion_target_path = NodePath("CenterContainer/Panel")` in `ui_localization_settings_overlay.tscn` so slide animation targets the panel while preserving container centering.
- Added regression coverage in `tests/unit/ui/test_settings_overlay_wrappers.gd`:
  - `test_localization_settings_overlay_keeps_panel_vertically_centered_after_enter`
- Validation:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd` → 14/14 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing

### Screen 15: Audio Settings Tab (`ui_audio_settings_tab.tscn`)

**Add automated test for slider styling** (TDD — follows `test_health_bar_color_blind_integration.gd` pattern):

- [x] Add test to existing audio settings test file or create `tests/unit/ui/test_audio_settings_theme.gd`:
  - `test_audio_sliders_use_theme_styles` — instantiate audio settings tab with theme applied, for each slider assert `slider.get_theme_stylebox("slider") is StyleBoxFlat` and `slider.get_theme_stylebox("grabber_area") is StyleBoxFlat`
  - `test_audio_sliders_no_inline_overrides` — assert `slider.has_theme_stylebox_override("slider") == false` (overrides migrated to theme)
- [x] Migrate all 18 overrides: 4x slider styleboxes (slider, grabber_area, grabber_area_highlight) + row separations
- [x] Sliders get slider_fill/slider_bg from Duel palette
- [x] Run tests — new slider theme tests pass
- [x] Run existing audio settings tests — all pass (4 volume sliders, values persist)
- [x] Run full test suite
- [x] **Manual smoke test:** Open audio settings, verify sliders have Duel palette fill (#41b2e3), track (#434549), all 4 sliders respond to input

Completion note (2026-03-06): Implemented Screen 15 in commit `2b4db1c9`.
- Added `tests/unit/ui/test_audio_settings_theme.gd` with Screen 15 coverage:
  - `test_audio_sliders_use_theme_styles`
  - `test_audio_sliders_no_inline_overrides`
  - `test_audio_settings_tab_applies_row_separation_tokens_when_active_config_set`
- Removed all inline slider style and row/button/root separation overrides from `ui_audio_settings_tab.tscn`.
- Added `UI_AudioSettingsTab._apply_theme_tokens()` to apply token-driven spacing/typography (`separation_default`, `separation_compact`, `heading`, `body_small`, `section_header`, `text_secondary`) while relying on theme-provided slider styles.
- Validation:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_audio_settings_theme.gd -gtest=res://tests/unit/ui/test_audio_settings_tab_localization.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd` → 14/14 passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
  - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2833/2842 passing, 0 failing, 9 pending/risky

### Screen 16: Display Settings Tab (`ui_display_settings_tab.tscn`)

**Add automated test for section panel styling** (TDD):

- [ ] Add test to existing display settings test file or create `tests/unit/ui/test_display_settings_theme.gd`:
  - `test_display_section_panels_use_theme_style` — instantiate display settings tab with theme, find PanelContainer nodes, assert `panel.get_theme_stylebox("panel") is StyleBoxFlat` (theme-provided, not inline override)
  - `test_display_section_headers_use_theme_color` — find section header Labels, assert `label.get_theme_color("font_color").is_equal_approx(config.section_header_color)` (pattern: `test_ui_scale_and_theme.gd`)
  - `test_display_no_inline_overrides_remaining` — scan all child nodes, assert none have `theme_override_constants/separation` set (all migrated to theme)
- [ ] Migrate all 43 overrides — the most complex screen:
  - 4 section panels -> theme's panel_section
  - 4 section headers -> theme's section_header color + size tokens
  - 4 separator styles -> theme's separator_style
  - 1 slider -> theme's slider styles
  - ~20 separation constants -> theme tokens
- [ ] Run tests — new display theme tests pass
- [ ] Run existing display settings tests — all pass (dropdowns, UI scale slider, toggle checkboxes)
- [ ] Run full test suite
- [ ] **Manual smoke test:** Open display settings, verify 4 sections have consistent panel backgrounds, headers are section_header color (#96b2d9), separators visible, UI scale slider works

---

## Phase 4 — HUD Enhancement

### Screen 17: HUD Overlay (`scenes/ui/hud/ui_hud_overlay.tscn`)

**28 overrides total** (4 outer margins, 1 pause font, 2 health bar styles, 1 health label font, 4 toast margins, 1 toast font, 1 autosave panel style, 4 autosave zero-margins, 1 autosave zero-separation, 1 autosave font, 1 signpost panel style, 4 signpost margins, 1 signpost font_color, 1 signpost line_spacing, 1 signpost font)

**Add automated tests** (TDD — extends existing HUD test patterns):

- [ ] Add to `tests/unit/ui/test_hud_controller.gd` or create `tests/unit/ui/test_hud_theme.gd`:
  - `test_health_bar_uses_theme_styles` — instantiate HUD with theme, assert `health_bar.get_theme_stylebox("background") is StyleBoxFlat`, assert `(stylebox as StyleBoxFlat).bg_color.is_equal_approx(config.health_bg)`. Only the BACKGROUND stylebox comes from theme; fill color is palette-driven (existing `tests/integration/ui/test_health_bar_color_blind_integration.gd` already covers fill).
  - `test_health_bar_no_inline_style_overrides` — assert `health_bar.has_theme_stylebox_override("background") == false`
  - `test_signpost_golden_override_preserved` — assert signpost label still has `theme_override_colors/font_color` set (semantic override stays)
  - `test_toast_uses_motion_resource` — trigger checkpoint event, verify tween is created (existing pattern in `test_hud_feedback_channels.gd`, extend to verify motion resource is used)
- [ ] Health bar: migrate StyleBoxFlat background to theme's progress_bar_bg, health_bg (#3a4568). Health bar fill remains palette-driven via `U_PaletteManager` for color-blind accessibility. Do not migrate fill color to theme.
- [ ] Health label: migrate font_size 18 to theme token
- [ ] Pause label: migrate font_size 32 to theme token
- [ ] Outer margins: migrate 20px to theme margin_outer
- [ ] Toast: migrate inner margins (12/8) and font_size 18 to theme tokens
- [ ] Signpost: migrate margins (28/18), font_size 22, line_spacing=4, font_color to theme. Update golden color to #ecc581 (keep as semantic per-node override)
- [ ] Autosave: migrate font_size 16, StyleBoxEmpty panel, zero-margins (4), and zero-separation to theme
- [ ] Extract hardcoded tween params from script into `RS_UIMotionPreset` resources:
  - Checkpoint toast: fade-in 0.2s TRANS_CUBIC, hold 1.0s, fade-out 0.3s
  - Signpost: fade-in 0.14s EASE_OUT, fade-out 0.18s EASE_IN
- [ ] Use motion resources for toast/signpost animations instead of hardcoded values
- [ ] Run new HUD theme tests — pass
- [ ] Run existing HUD tests (`test_hud_controller.gd`, `test_hud_feedback_channels.gd`, `test_hud_button_prompts.gd`, `test_hud_interactions_pause_and_signpost.gd`) — all pass
- [ ] Run full test suite
- [ ] **Manual smoke test:** Play gameplay, verify: health bar background is health_bg (#3a4568), fill is palette-driven (changes with health % and color-blind mode), checkpoint toast fades in/holds/fades out smoothly, signpost shows golden text on dark panel, autosave spinner rotates during save, interact prompt appears near interactables

### Screen 18: Button Prompt (`scenes/ui/hud/ui_button_prompt.tscn`)

**5 overrides** (separation=12, panel StyleBox, font_size 20/12/24)

- [ ] Migrate separation to theme token (separation_default)
- [ ] Migrate panel StyleBox to theme's panel_button_prompt
- [ ] Migrate font_sizes: 24 -> subheading, 20 -> body, 12 -> caption_small
- [ ] Run existing `test_hud_button_prompts.gd` — all pass (icon/text updates, device switch, localization)
- [ ] Run full test suite
- [ ] **Manual smoke test:** Approach interactable in gameplay, verify prompt panel is styled, text hierarchy is clear (action name larger than sub-label), device icons render correctly

### Screen 19: Loading Screen (`scenes/ui/hud/ui_loading_screen.tscn`)

- [ ] Migrate all font sizes to theme tokens (title, heading, body_small, section_header)
- [ ] Migrate separation to theme margin_outer
- [ ] Style progress bar with theme's progress_bar_bg/fill
- [ ] bg_base solid background, fade-in on load start, progress bar smooth fill
- [ ] Run full test suite
- [ ] **Manual smoke test:** Trigger scene transition, verify loading screen shows with bg_base background, progress bar fills with accent_primary color, text hierarchy visible, tip text shows in body_small size

---

## Phase 5 — Polish & Verification

### 5A — Automated Override Migration Verification

**Add a style enforcement test** to permanently guard against override regression:

- [ ] Add to `tests/unit/style/test_style_enforcement.gd`:
  - `test_no_inline_theme_overrides_except_semantic` — scan all `.tscn` files under `scenes/ui/`, count `theme_override_` lines. Assert total <= 4 (only `ui_virtual_button.tscn` semantic overrides remain). List files with violations in assertion message.
- [ ] Run style enforcement — new test passes

### 5B — Visual Consistency Pass

- [ ] Review all screens side by side for visual consistency
- [ ] Verify overlay dim opacity is consistent with the current two-tier convention (0.7: pause/settings-overlay/save-load, 0.5: rebinding/profile/gamepad/touchscreen/settings wrappers, 0.05: edit-touch, 0.0: embedded settings, 1.0: loading)
- [ ] Verify excluded scenes still render correctly: `ui_mobile_controls.tscn`, `ui_damage_flash_overlay.tscn`, `ui_post_process_overlay.tscn`, `ui_gamepad_preview_prompt.tscn`, `ui_virtual_joystick.tscn`, `ui_virtual_button.tscn`

### 5C — Full Test Suite

- [ ] `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` — all tests pass
- [ ] Style enforcement: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` — all pass including new override guard

### 5D — Manual Smoke Test Checklist

Run through each flow end-to-end in the game (not headless):

- [ ] **Boot flow:** Launch game -> language selector (if first run) -> main menu. Verify consistent bg_base background, buttons styled, title prominent.
- [ ] **Menu navigation:** Main menu -> Settings (embedded) -> Back. Verify panel backgrounds, button hover/press feedback.
- [ ] **Gameplay entry:** Start game -> gameplay HUD visible. Verify health bar background (health_bg), fill is palette-driven (color-blind), pause label hidden, interact prompt appears near interactables.
- [ ] **Pause flow:** Pause -> Settings -> Audio -> adjust sliders -> Back -> Resume. Verify dim consistency, slider styling, category buttons all work.
- [ ] **Save/Load flow:** Pause -> Save/Load -> save to slot -> load from slot. Verify slot items styled, error text danger-colored, spinner visible.
- [ ] **Death flow:** Die -> Game Over screen. Verify danger-colored title, fade-in animation, Retry/Menu buttons work.
- [ ] **Victory flow:** Win -> Victory screen. Verify success-colored title, stats readable, Reset Run works.
- [ ] **Credits flow:** Victory -> Credits. Verify text hierarchy, Skip button, auto-scroll.
- [ ] **HUD feedback:** Trigger checkpoint toast, signpost message, autosave. Verify animations play smoothly, golden signpost text, spinner rotates.
- [ ] **Loading screen:** Trigger scene transition. Verify progress bar fills, bg_base background, tip text shows.
- [ ] **Overlay stacking:** Pause -> Settings -> Input Rebinding -> assign key -> Back -> Back -> Resume. Verify dim consistency across overlay stack.

### 5E — Documentation Updates

- [ ] Update `AGENTS.md` with theme system and motion framework patterns
- [ ] Update `docs/general/DEV_PITFALLS.md` with new pitfalls:
  - "Use `RS_UIThemeConfig` for styling, not inline `theme_override_*`"
  - "Motion resources are opt-in — `null` motion_set = zero behavioral change"
  - "Semantic per-node overrides (signpost golden, error red, virtual button) are intentional exceptions"
- [ ] Update this task list with final completion notes
- [ ] Update continuation prompt with final status

---

## Testing Strategy Summary

### Automated (TDD — write tests BEFORE implementation)

| Test File | Phase | What It Verifies |
| --------- | ----- | ---------------- |
| `test_ui_theme_builder.gd` | 0B | Theme config -> Godot Theme: font sizes, styleboxes, colors, spacing, merging with font theme, null safety |
| `test_ui_motion.gd` | 0D | Motion preset playback: property changes, sequential/parallel chaining, intervals, null safety, signal binding |
| `test_base_ui_classes.gd` (additions) | 0F | Base class motion integration: null motion_set no-op, enter/exit animation, overlay dim animation |
| `test_audio_settings_theme.gd` | 3/S15 | Slider theme styles applied, no inline overrides remaining |
| `test_display_settings_theme.gd` | 3/S16 | Section panel styles, header colors, no inline overrides remaining |
| `test_hud_theme.gd` | 4/S17 | Health bar background theme style, no inline style overrides, signpost semantic override preserved, motion resource used for toast |
| `test_style_enforcement.gd` (addition) | 5A | Global guard: total inline overrides <= 4 across all UI scenes |

### Automated (Existing — Run After Each Screen)

Run existing tests to confirm zero behavioral regression:

- `test_main_menu.gd` — Redux navigation, button dispatch, quit visibility, focus chain
- `test_endgame_screens.gd` — Game over/victory/credits button dispatch, auto-return
- `test_pause_menu.gd` — Resume, settings, PROCESS_MODE_ALWAYS
- `test_settings_menu_visibility.gd` — 8 categories, back, embedded mode
- `test_save_load_menu.gd` — Save/Load/Delete/Overwrite, mode detection
- `test_hud_controller.gd` — Health bar visibility, pause hide, transition hide
- `test_hud_feedback_channels.gd` — Toast/spinner/signpost channels, interact blocker, layout geometry, tween animation
- `test_hud_button_prompts.gd` — Prompt icon/text, device switch, localization
- `test_hud_interactions_pause_and_signpost.gd` — Pause suppression, signpost localization
- `tests/integration/ui/test_health_bar_color_blind_integration.gd` — Palette color binding, live color update
- All overlay-specific tests (rebinding, input profile, gamepad, touchscreen, edit touch controls)

### Manual (Visual Feel — Cannot Be Automated)

These verify visual polish that requires human eyes:

- Background color correctness against Duel palette reference
- Animation smoothness and timing feel (easing curves)
- Text hierarchy legibility (title > heading > body > caption)
- Button hover/press visual feedback
- Overlay dim consistency across stack
- Color harmony and contrast between elements
- Font rendering at different sizes
- Platform-specific rendering (mobile vs desktop)

---

## Notes

- **Scope change (2026-03-05)**: Replaced framework-first approach with screen-by-screen pass. No new HUD widgets (notification queue, objective tracker, currency/score, timer, minimap slot) — those are deferred. No @tool editor previews — deferred. No number ticker utility — deferred.
- Phase 0 builds minimal shared infrastructure (theme config, theme builder, motion resources, base class integration).
- Phases 1-4 systematically polish each screen, migrating inline overrides and adding motion.
- Phase 5 is final verification and documentation.
- After **every screen**: run full test suite, verify behavior unchanged, confirm visual improvement.
- If `motion_set` is null (the default), zero behavioral change — all existing screens work identically.

### Override Inventory (verified 2026-03-05)

**Total: 119** `theme_override_` lines across 13 files (115 excluding 4 virtual_button semantic overrides).

| File | Count | Notes |
| ---- | ----- | ----- |
| `ui_display_settings_tab.tscn` | 43 | 4 section panels, 4 headers, 4 separators, 1 slider, ~20 separations |
| `ui_hud_overlay.tscn` | 28 | Margins, fonts, 4 StyleBox sub-resources, signpost styling |
| `ui_audio_settings_tab.tscn` | 18 | 4x slider styling + row separations |
| `ui_button_prompt.tscn` | 5 | Separation, panel StyleBox, 3 font sizes |
| `ui_loading_screen.tscn` | 5 | Separation, 4 font sizes |
| `ui_input_profile_selector.tscn` | 4 | 4 spacing overrides |
| `ui_virtual_button.tscn` | 4 | Semantic per-node (excluded from migration) |
| `ui_language_selector.tscn` | 3 | VBox + Grid separations |
| `ui_save_load_menu.tscn` | 3 | Error color, 2 font sizes |
| `ui_game_over.tscn` | 2 | VBox separations |
| `ui_victory.tscn` | 2 | VBox separations |
| `ui_credits.tscn` | 1 | VBox separation |
| `ui_localization_settings_tab.tscn` | 1 | Separation |

### Dim Opacity Inventory (verified 2026-03-06)

| File | Current Alpha | Notes |
| ---- | ------------- | ----- |
| `ui_edit_touch_controls_overlay.tscn` | 0.05 | Intentionally translucent for touch editing |
| `ui_pause_menu.tscn` | 0.7 | Overlay mode |
| `ui_settings_menu.tscn` | 0.7 / 0.0 | 0.7 in overlay mode, 0.0 when embedded in main menu |
| `ui_save_load_menu.tscn` | 0.7 | Matches BaseOverlay default |
| `ui_input_rebinding_overlay.tscn` | 0.5 | Screen 9 dim normalized in audit pass |
| `ui_input_profile_selector.tscn` | 0.5 | |
| `ui_gamepad_settings_overlay.tscn` | 0.5 | |
| `ui_touchscreen_settings_overlay.tscn` | 0.5 | |
| `ui_audio_settings_overlay.tscn` | 0.5 | Settings wrapper |
| `ui_display_settings_overlay.tscn` | 0.5 | Settings wrapper |
| `ui_localization_settings_overlay.tscn` | 0.5 | Settings wrapper |
| `ui_vfx_settings_overlay.tscn` | 0.5 | Settings wrapper |
| `ui_loading_screen.tscn` | 1.0 | Fully opaque (intentional) |
| BaseOverlay default | 0.7 | Code default in `base_overlay.gd` |

### Zero-Override Baseline Scenes (verified 2026-03-05)

These scenes currently have no `theme_override_*` lines, so they do not need override-migration work. Some are still explicit Screen tasks for composition/motion polish.

- `ui_main_menu.tscn`, `ui_pause_menu.tscn`, `ui_settings_menu.tscn` — zero overrides, but still in Phases 1-2 for layout/panel/motion polish
- `ui_input_rebinding_overlay.tscn`, `ui_gamepad_settings_overlay.tscn`, `ui_touchscreen_settings_overlay.tscn`, `ui_edit_touch_controls_overlay.tscn` — zero overrides, still included in the batch overlay polish pass
- `ui_mobile_controls.tscn` — mobile-only control container, no text styling
- `ui_damage_flash_overlay.tscn` — fullscreen color flash, no theme elements
- `ui_post_process_overlay.tscn` — post-processing container, no theme elements
- `ui_gamepad_preview_prompt.tscn` — gamepad preview widget, no overrides
- `ui_virtual_joystick.tscn` — mobile joystick widget, no overrides
- `ui_virtual_button.tscn` — 4 overrides but **semantic per-node** (mobile-only, excluded from migration)

## Links

- PRD: `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`
- Continuation prompt: `docs/ui_visual_overhaul/ui-visual-overhaul-continuation-prompt.md`
- Prerequisite refactor: `docs/general/ui_layers_transitions_refactor/`
