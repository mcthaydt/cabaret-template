# UI Visual Overhaul — Continuation Prompt

## Current Focus

- Feature / story: UI Visual Overhaul (Screen-by-Screen)
- Branch: `UI-Looksmaxxing`
- Status summary: **In progress** — Phase 0A-0G complete, Phase 1 Screens 1-5 complete, Phase 2 Screens 6-13 + settings-overlay wrappers complete (implementation + automated verification + audit hardening), Phase 3 Screens 14-16 complete (automated verification), Phase 4 Screens 17-18 complete (implementation + automated verification). Pending manual smoke for Screens 15-18. Next: Phase 4 Screen 19 (`ui_loading_screen.tscn`).

## Recent Progress

- **2026-03-06: Phase 4 Screen 18 implemented (`ui_button_prompt.tscn`)**
  - Button prompt migrated off inline scene overrides:
    - Removed all Screen 18 inline `theme_override_*` entries (root separation, text-icon panel stylebox, and 3 font-size overrides).
    - Added `UI_ButtonPrompt._apply_theme_tokens()` to apply tokenized styling from `U_UIThemeBuilder.active_config`.
  - Screen 18 token mapping now centralized in script:
    - `separation_default` for root prompt spacing
    - `panel_button_prompt` for `TextIcon` panel chrome
    - `subheading` for prompt action text, `body` for binding label, `caption_small` for mobile label text
  - Added Screen 18 regression coverage:
    - `tests/unit/ui/test_button_prompt.gd`
      - `test_button_prompt_applies_theme_tokens_when_active_config_set`
      - `test_button_prompt_scene_has_no_inline_theme_overrides`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_button_prompt.gd -gtest=res://tests/unit/ui/test_hud_button_prompts.gd` → 17/17 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2845/2854 passing, 0 failing, 9 pending/risky
  - Implementation commit: `1755bc5b`
  - Manual smoke for Screen 18 is still pending.

- **2026-03-06: Phase 4 Screen 17 implemented (`ui_hud_overlay.tscn`)**
  - HUD overlay migrated off inline scene overrides:
    - Removed all 28 Screen 17 `theme_override_*` entries from `ui_hud_overlay.tscn`.
    - Added token application in `UI_HudController._apply_theme_tokens()` for margins/typography/signpost styling.
    - Health bar background now comes from themed `ProgressBar.background`; fill remains palette-driven (`_update_health_bar_colors`) for color-blind accessibility.
  - Motion extraction completed for HUD feedback channels:
    - `resources/ui/motions/cfg_motion_hud_checkpoint_toast.tres`
    - `resources/ui/motions/cfg_motion_hud_signpost_fade_in.tres`
    - `resources/ui/motions/cfg_motion_hud_signpost_fade_out.tres`
    - `UI_HudController` now consumes these resources instead of hardcoded checkpoint/signpost fade timings.
  - Added Screen 17 regression coverage:
    - `tests/unit/ui/test_hud_theme.gd`
      - `test_health_bar_uses_theme_styles`
      - `test_health_bar_no_inline_style_overrides`
      - `test_signpost_golden_override_preserved`
      - `test_toast_uses_motion_resource`
  - Stability hardening:
    - `tests/integration/ui/test_health_bar_color_blind_integration.gd` now resets `U_UIThemeBuilder.active_config` in setup/teardown to prevent cross-suite static-theme leakage.
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_hud_theme.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_hud_theme.gd -gtest=res://tests/unit/ui/test_hud_controller.gd -gtest=res://tests/unit/ui/test_hud_feedback_channels.gd -gtest=res://tests/unit/ui/test_hud_button_prompts.gd -gtest=res://tests/unit/ui/test_hud_interactions_pause_and_signpost.gd -gtest=res://tests/integration/ui/test_health_bar_color_blind_integration.gd` → 33/33 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2843/2852 passing, 0 failing, 9 pending/risky
  - Implementation commit: `9e306d4d`
- **2026-03-06: Display/VFX settings overlay centering follow-up**
  - Root cause: `UI_DisplaySettingsOverlay` and `UI_VFXSettingsOverlay` enter motion auto-targeted `CenterContainer`, which could introduce vertical drift for wrapper panels during tween sampling.
  - Fix: set `motion_target_path = NodePath("CenterContainer/Panel")` in both overlay scenes so slide animation applies to the panel while preserving center-container alignment.
  - Added regression coverage:
    - `tests/unit/ui/test_settings_overlay_wrappers.gd::test_display_settings_overlay_keeps_panel_vertically_centered_after_enter`
    - `tests/unit/ui/test_settings_overlay_wrappers.gd::test_vfx_settings_overlay_keeps_panel_vertically_centered_after_enter`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/display/test_display_settings.gd -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd` → 33/33 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
  - Implementation commit: `828ca262`
- **2026-03-06: Phase 3 Screen 16 implemented (`ui_display_settings_tab.tscn`)**
  - Display settings tab migrated to token-driven styling:
    - Removed inline section panel/separator/slider/separation overrides from the scene.
    - Added `UI_DisplaySettingsTab._apply_theme_tokens()` to apply typography/color/margin tokens (`heading`, `section_header`, `section_header_color`, `body_small`, `text_secondary`, `margin_section`).
    - Section panels/separators/slider now source styleboxes from unified theme builder (`panel_section`, `separator_style`, `slider_bg`/`slider_fill`) instead of scene-local subresources.
  - Added Screen 16 regression coverage:
    - `tests/unit/ui/test_display_settings_theme.gd`
      - `test_display_section_panels_use_theme_style`
      - `test_display_section_headers_use_theme_color`
      - `test_display_no_inline_overrides_remaining`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_display_settings_theme.gd -gtest=res://tests/unit/ui/test_display_settings_tab_localization.gd -gtest=res://tests/integration/display/test_display_settings.gd` → 21/21 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2837/2846 passing, 0 failing, 9 pending/risky
  - Implementation commit: `7f7ece0c`
- **2026-03-06: Screen 15 audio overlay centering follow-up**
  - Root cause: `UI_AudioSettingsOverlay` enter motion was auto-targeting `CenterContainer`, which could introduce vertical drift for the wrapper panel during tween sampling.
  - Fix: set `motion_target_path = NodePath("CenterContainer/Panel")` so slide animation applies to the panel while preserving center-container alignment.
  - Added regression coverage:
    - `tests/unit/ui/test_settings_overlay_wrappers.gd::test_audio_settings_overlay_keeps_panel_vertically_centered_after_enter`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd` → 16/16 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
  - Implementation commit: `217f77a6`
- **2026-03-06: Phase 3 Screen 15 implemented (`ui_audio_settings_tab.tscn`)**
  - Audio settings tab migrated to token-driven styling:
    - Removed all inline slider style overrides (`slider`, `grabber_area`, `grabber_area_highlight`) and row/root/button separation overrides from the tab scene.
    - Added `UI_AudioSettingsTab._apply_theme_tokens()` for spacing/typography tokens (`separation_default`, `separation_compact`, `heading`, `body_small`, `section_header`, `text_secondary`).
    - Slider visuals now come from unified theme builder styleboxes (`slider_bg` / `slider_fill`) instead of per-node scene overrides.
  - Added Screen 15 regression coverage:
    - `tests/unit/ui/test_audio_settings_theme.gd`
      - `test_audio_sliders_use_theme_styles`
      - `test_audio_sliders_no_inline_overrides`
      - `test_audio_settings_tab_applies_row_separation_tokens_when_active_config_set`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_audio_settings_theme.gd -gtest=res://tests/unit/ui/test_audio_settings_tab_localization.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd` → 14/14 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2833/2842 passing, 0 failing, 9 pending/risky
  - Implementation commit: `2b4db1c9`
- **2026-03-06: Screen 14 localization overlay centering follow-up**
  - Root cause: `UI_LocalizationSettingsOverlay` enter motion was auto-targeting `CenterContainer`, which introduced vertical drift for the wrapper panel.
  - Fix: set `motion_target_path = NodePath("CenterContainer/Panel")` so slide animation applies to the panel while preserving center-container layout.
  - Added regression coverage:
    - `tests/unit/ui/test_settings_overlay_wrappers.gd::test_localization_settings_overlay_keeps_panel_vertically_centered_after_enter`
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd` → 14/14 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
  - Implementation commit: `abc897ed`
- **2026-03-06: Phase 3 Screen 14 implemented (`ui_localization_settings_tab.tscn`)**
  - Localization settings tab migrated to token-driven styling:
    - Removed the final inline `theme_override_constants/separation` from the tab scene.
    - Added `UI_LocalizationSettingsTab._apply_theme_tokens()` for language-list styling using `RS_UIThemeConfig` tokens (`heading`, `section_header`, `body_small`, `section_header_color`, `text_secondary`, `separation_default`, `separation_compact`).
  - Added Screen 14 regression coverage:
    - `tests/unit/ui/test_localization_settings_tab_theme.gd` validates spacing and typography/color token application when `U_UIThemeBuilder.active_config` is set.
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_localization_settings_tab_theme.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd -gtest=res://tests/unit/ui/test_display_settings_tab_localization.gd -gtest=res://tests/unit/ui/test_audio_settings_tab_localization.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2829/2838 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
  - Implementation commit: `c94de23c`
- **2026-03-06: Phase 2 overlay audit hardening pass**
  - Gap closures completed:
    - Normalized Screen 9 dim to `bg_base@0.5` across scene/script/tests.
    - Standardized settings-overlay close paths so main-menu returns use `navigate_to_ui_screen("settings_menu", "fade", 2)` while stacked overlays still use `close_top_overlay()`.
    - Removed transient debug `print(...)` logging from `UI_TouchscreenSettingsOverlay`.
    - Added style guard `test_polished_overlay_scenes_have_no_inline_theme_overrides` in `tests/unit/style/test_style_enforcement.gd`.
  - Validation:
    - `... -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd` → 4/4 passing
    - `... -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd` → 11/11 passing
    - `... -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd` → 11/11 passing
    - `... -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd` → 6/6 passing
    - `... -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd` → 4/4 passing
    - `... -gtest=res://tests/integration/audio/test_audio_settings_ui.gd` → 10/10 passing
    - `... -gtest=res://tests/integration/display/test_display_settings.gd` → 17/17 passing
    - `... -gtest=res://tests/integration/localization/test_localization_settings_tab.gd` → 9/9 passing
    - `... -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd` → 8/8 passing
    - `... -gtest=res://tests/unit/style/test_style_enforcement.gd` → 12/12 passing
- **2026-03-06: Phase 2 settings-overlay wrappers implemented (`ui_audio_settings_overlay`, `ui_display_settings_overlay`, `ui_localization_settings_overlay`, `ui_vfx_settings_overlay`)**
  - Wrapper overlays migrated to shared overlay behavior:
    - Removed legacy inline `Background` color rects and standardized on `BaseOverlay` `OverlayBackground`.
    - Assigned `motion_set = cfg_motion_fade_slide` to all four wrapper roots.
    - Added wrapper `_on_panel_ready()` token plumbing (dim/panel/spacing) and `play_enter_animation()` hooks.
  - Added wrapper regression suite:
    - `tests/unit/ui/test_settings_overlay_wrappers.gd` (4 tests) validates motion assignment + `bg_base@0.5` dim + `panel_section` + `separation_default` application across all wrappers.
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_overlay_wrappers.gd -gtest=res://tests/integration/audio/test_audio_settings_ui.gd -gtest=res://tests/integration/display/test_display_settings.gd -gtest=res://tests/integration/localization/test_localization_settings_tab.gd -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd -gtest=res://tests/unit/ui/test_vfx_settings_overlay_localization.gd` → 49/49 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2827/2836 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `96df500e`
- **2026-03-06: Mobile stylebox hydration fix (unified theme)**
  - Device trace showed unified bootstrap running, but `U_UIThemeBuilder` reported `button_normal_null=true` and `panel_section_null=true`, so built themes had text colors but no button/panel styleboxes.
  - Root cause: loaded `cfg_ui_theme_default.tres` may not hydrate stylebox fields on export paths if defaults rely only on `RS_UIThemeConfig._init()`.
  - Fix:
    - Added `RS_UIThemeConfig.ensure_runtime_defaults()`.
    - `_init()` now delegates to `ensure_runtime_defaults()`.
    - `U_UIThemeBuilder.build_theme(...)` now explicitly calls `ensure_runtime_defaults()` before stylebox/token application.
  - Added regression test:
    - `test_build_theme_hydrates_runtime_style_defaults_for_loaded_config_resource` in `tests/unit/ui/test_ui_theme_builder.gd`.
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd` → 19/19 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd -gtest=res://tests/unit/managers/test_display_manager.gd -gtest=res://tests/unit/managers/test_localization_manager.gd` → 64/64 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- **2026-03-06: Theme lifecycle regression hardening**
  - Root cause: gameplay scenes also attach `scripts/root.gd`; unloading gameplay roots ran `_exit_tree()` and cleared `U_UIThemeBuilder.active_config`, so later menu screens could render default gray chrome.
  - Fix: `scripts/root.gd` now clears `U_UIThemeBuilder.active_config` only for the persistent app root (detected via `Managers/M_StateStore`).
  - Added regression tests: `tests/unit/ui/test_root_ui_theme_lifecycle.gd` (`non_persistent_root_exit_does_not_clear_active_theme_config`, `persistent_root_exit_clears_active_theme_config`).
  - Validation:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_root_ui_theme_lifecycle.gd` → 2/2 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd` → 14/14 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- Created PRD (`docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`)
- Created task checklist (`docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md`)
- **"UI, Layers & Transitions Refactor" completed** — all 7 phases done on branch `UI-Looksmaxxing`
- **2026-03-05: Plan revised** — replaced framework-first approach (8 phases) with screen-by-screen approach (6 phases: 0-5). Deferred HUD widgets, @tool previews, and number ticker. Focus is on polishing all existing screens + enhancing existing HUD.
- **2026-03-05: Phase 0A-0C implemented**
  - Added `RS_UIThemeConfig` + default config resource (`resources/ui/cfg_ui_theme_default.tres`)
  - Added `U_UIThemeBuilder` and static `active_config` wiring in `root.gd`
  - Unified theme pipeline: localization font applier composes fonts+theme; display theme applier feeds active palette and rebuilds via builder
  - Added `tests/unit/ui/test_ui_theme_builder.gd` (16 tests) including 0C integration coverage
  - Verified related display/localization suites + style suite all pass
- **2026-03-05: Phase 0D-0E implemented**
  - Added motion resource contracts: `RS_UIMotionPreset`, `RS_UIMotionSet`
  - Added motion utility: `U_UIMotion.play/play_enter/play_exit/bind_interactive`
  - Added `tests/unit/ui/test_ui_motion.gd` (12 tests) covering sequential, parallel, interval, and signal binding behavior
  - Authored default motion sets:
    - `resources/ui/motions/cfg_motion_fade_slide.tres`
    - `resources/ui/motions/cfg_motion_button_default.tres`
    - `resources/ui/motions/cfg_motion_hud_pop.tres`
  - Verified new motion tests, theme builder tests, and style suite all pass
- **2026-03-05: Phase 0F implemented**
  - Added motion integration tests to `tests/unit/ui/test_base_ui_classes.gd` (null-bind, bind, menu enter/no-enter, overlay dim)
  - `BasePanel` now supports optional exported `motion_set` and binds interactive child controls through `U_UIMotion`
  - `BaseMenuScreen` now exposes `play_enter_animation()` / `play_exit_animation()`
  - `BaseOverlay` now animates dim background alpha alongside enter/exit motion
  - Verified base UI tests plus menu/overlay regression suites and style suite all pass
- **2026-03-05: Phase 0G verification completed**
  - Full suite: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true`
  - Result: 2802 total tests, 2793 passing, 0 failing, 9 pending/risky (headless/mobile-gated skips)
  - Style suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (13/13 passing)
  - Follow-up hardening patch applied:
    - `U_UIThemeBuilder` now applies config text colors when palette is not yet available and the base theme has no colors.
    - Builder kept `Resource` typing for `active_config`/palette parameters to maintain headless parser compatibility.
    - `resources/ui/cfg_ui_theme_default.tres` now pins primitive default tokens explicitly.
- **2026-03-05: Phase 1 Screen 1 implemented (`ui_main_menu.tscn`)**
  - Scene composition updated: full-screen `Background` (`bg_base`) + centered `PanelContainer` for the main button group.
  - Assigned `motion_set = cfg_motion_fade_slide` on `UI_MainMenu` root and trigger `play_enter_animation()` on panel ready.
  - `UI_MainMenu` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config` (`bg_base` for background + `title` font size for `TitleLabel`).
  - Updated `tests/unit/ui/test_main_menu.gd`:
    - Added coverage for motion assignment and token application from active theme config.
    - Switched brittle path-based button lookups to `%UniqueName` access for hierarchy-safe assertions.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd` → 14/14 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2795/2804 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `aaa7f75c`
- **2026-03-05: Phase 1 Screen 2 implemented (`ui_game_over.tscn`)**
  - Scene composition updated: full-screen `Background` (`bg_base`) + centered `PanelContainer` layout replacing hard-coded 96px offsets.
  - Assigned `motion_set = cfg_motion_fade_slide` on `UI_GameOver` root and trigger `play_enter_animation()` on panel ready.
  - Added token-driven visual application in `UI_GameOver` from `U_UIThemeBuilder.active_config`:
    - `title` size + `danger` color for title label,
    - `heading` size + `text_secondary` for death count,
    - `separation_large` / `separation_medium` for content and button row spacing,
    - `bg_base` for background color.
  - Added slight delayed title fade-in motion for Screen 2 feel polish.
  - Updated `tests/unit/ui/test_endgame_screens.gd`:
    - Added coverage for Game Over motion/theme-token application with active config.
    - Migrated Game Over button lookups to `%UniqueName` for hierarchy-safe assertions.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd` → 11/11 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2796/2805 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `f2fb658a`
- **2026-03-05: Phase 1 Screen 3 implemented (`ui_victory.tscn`)**
  - Scene composition updated to match Screen 2 pattern: full-screen `Background` (`bg_base`) + centered `PanelContainer` replacing hard-coded margin offsets.
  - Assigned `motion_set = cfg_motion_fade_slide` on `UI_Victory` root and trigger `play_enter_animation()` on panel ready.
  - Added token-driven visual application in `UI_Victory` from `U_UIThemeBuilder.active_config`:
    - `title` size + `success` color for title label,
    - `heading` size + `text_secondary` for completion stats,
    - `separation_large` / `separation_medium` for content and button-row spacing,
    - `bg_base` for background color.
  - Added slight delayed title fade-in motion for endgame polish.
  - Focus-chain hardening: credits button only participates when visible and enabled (prevents hidden focus target behavior).
  - Updated `tests/unit/ui/test_endgame_screens.gd`:
    - Added victory motion/theme-token coverage with active config.
    - Migrated victory button lookups to `%UniqueName` hierarchy-safe selectors.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2797/2806 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `b05c75df`
- **2026-03-05: Phase 1 Screen 4 implemented (`ui_credits.tscn`)**
  - Scene composition updated to match migrated endgame pattern: full-screen `Background` (`bg_base`) + centered `PanelContainer` credits layout replacing fixed 96px offsets.
  - Assigned `motion_set = cfg_motion_fade_slide` on `UI_Credits` root and trigger `play_enter_animation()` on panel ready.
  - Replaced spacer `Control` nodes with token-driven VBox separation and moved Skip button to anchored margin-based placement (no fixed bottom-right pixel block).
  - Added token-driven visual application in `UI_Credits` from `U_UIThemeBuilder.active_config`:
    - `title` size for header label,
    - `body` size for credits names/thanks,
    - `caption` size for footer label,
    - `separation_medium` for content spacing,
    - `bg_base` for background color.
  - Updated `tests/unit/ui/test_endgame_screens.gd`:
    - Added credits motion/theme-token coverage with active config.
    - Migrated credits skip button lookup to `%UniqueName` hierarchy-safe selector.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2798/2807 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `c747d478`
- **2026-03-05: Credits black-screen follow-up fix**
  - Root cause: Victory button flows snap `TransitionColorRect` to opaque black before dispatching navigation. `skip_to_credits` uses `instant` transition, which previously had no fade-in step to clear overlay alpha.
  - Fix: `U_TransitionOrchestrator` now clears `TransitionColorRect.modulate.a` after instant scene swap completion.
  - Added regression coverage in `tests/integration/scene_manager/test_endgame_flows.gd` asserting transition overlay alpha resets to `0.0` after Victory → Credits.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/integration/scene_manager/test_endgame_flows.gd` → 5/5 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_endgame_screens.gd` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- **2026-03-05: Phase 1 Screen 5 implemented (`ui_language_selector.tscn`)**
  - Scene composition updated: full-screen `Background` (`bg_base`) + centered `PanelContainer` with padded content and tokenized grid spacing.
  - Assigned `motion_set = cfg_motion_fade_slide` on `UI_LanguageSelector` root and trigger `play_enter_animation()` when first-run button grid appears.
  - Added token-driven visual application in `UI_LanguageSelector` from `U_UIThemeBuilder.active_config`:
    - `heading` size for title label,
    - `panel_section` style for the panel container,
    - `separation_default` for vertical content spacing,
    - `separation_compact` for language grid spacing,
    - `margin_section` for panel padding,
    - `bg_base` for background color.
  - Refactored scene-manager lookup to use `I_SceneManager` service typing for both skip and transition paths.
  - Added `tests/unit/ui/test_language_selector.gd` covering:
    - theme/motion token application,
    - skip-to-main-menu behavior when language is already selected,
    - locale selection dispatch + transition behavior.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_language_selector.gd` → 3/3 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2801/2810 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `3a9ab267`
- **2026-03-06: Phase 1 manual-smoke and integration hardening follow-up**
  - User completed manual smoke verification for remaining Phase 1 screens: `ui_game_over.tscn`, `ui_victory.tscn`, and `ui_language_selector.tscn`.
  - Landed navigation/transition integration stabilization:
    - Updated integration suites to target canonical gameplay scene id `alleyway` instead of legacy `scene1`.
    - Hardened `_await_scene(...)` helpers to wait for both `current_scene_id` match and `scene.is_transitioning == false` before asserting.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_navigation_integration.gd` → 7/7 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2801/2810 passing, 0 failing, 9 pending/risky
  - Implementation commits: `4f7bdccb`, `b9197a89`
- **2026-03-06: Phase 2 Screen 6 implemented (`ui_pause_menu.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy static `ColorRect` dim and normalized BaseOverlay dim to `bg_base` at alpha `0.7`.
    - Added panel-backed content layout (`MainPanel` + `MainPanelPadding` + `MainPanelContent`) for consistent `panel_section` styling.
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_PauseMenu` for enter/exit and interactive button motion.
  - `UI_PauseMenu` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - heading token for `TitleLabel`,
    - `margin_section` for panel padding,
    - `separation_default` for button-stack spacing,
    - `panel_section` style override for panel background,
    - `bg_base` with 0.7 alpha for overlay dim.
  - Updated tests:
    - Added pause-menu motion/theme token coverage in `tests/unit/ui/test_pause_menu.gd`.
    - Updated pause-menu settings button integration lookups to `%SettingsButton` in `tests/unit/integration/test_input_profile_selector_overlay.gd` for hierarchy-safe assertions.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd` → 8/8 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd -gtest=res://tests/unit/ui/test_settings_menu_visibility.gd` → 10/10 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2803/2812 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `5a4ee078`
  - Manual smoke: completed (user-verified)
- **2026-03-06: Screen 6 animation follow-up refinement**
  - Updated pause-menu enter/exit behavior so only `MainPanel` receives slide motion.
  - Backdrop (`OverlayBackground`) now fades only and no longer slides, removing visible edge/cutoff artifacts during transition.
  - Centering fix: introduced `MainPanelMotionHost` under `CenterContainer` and moved `MainPanel` inside it so slide animation no longer displaces center alignment.
  - Added regression coverage in `tests/unit/ui/test_pause_menu.gd`:
    - `test_enter_animation_keeps_overlay_root_position_static`
    - `test_pause_menu_panel_stays_vertically_centered_after_enter_animation`
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_pause_menu.gd` → 10/10 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2804/2813 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- **2026-03-06: Default panel-only slide behavior generalized**
  - `BaseMenuScreen` now resolves a motion target automatically:
    - optional explicit `motion_target_path`,
    - otherwise auto-targets `CenterContainer` when a backdrop (`Background` / `OverlayBackground` / `ColorRect`) and `PanelContainer` are present,
    - otherwise falls back to animating the root node.
  - This makes backdrop fade + panel slide the default behavior across migrated menu/overlay screens without per-screen overrides.
  - `UI_PauseMenu` removed custom enter/exit motion overrides and now inherits base behavior.
  - Added base regression coverage in `tests/unit/ui/test_base_ui_classes.gd`:
    - `test_base_menu_screen_targets_center_container_when_backdrop_and_panel_exist`
  - Integration hardening:
    - `tests/unit/integration/test_input_profile_selector_overlay.gd` now sets `store.settings.enable_persistence = false` in setup to prevent persisted locale leakage.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_base_ui_classes.gd -gtest=res://tests/unit/ui/test_pause_menu.gd` → 23/23 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_main_menu.gd -gtest=res://tests/unit/ui/test_endgame_screens.gd -gtest=res://tests/unit/ui/test_language_selector.gd` → 30/30 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd` → 4/4 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2806/2815 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `87865a19`
- **2026-03-06: Phase 2 Screen 7 implemented (`ui_settings_menu.tscn`)**
  - Scene composition migrated to centered panel/scroll pattern:
    - Removed legacy inline dim `ColorRect` and moved to `BaseOverlay` background handling.
    - Added `CenterContainer` + `MainPanel` + `MainPanelPadding` + `ScrollContainer/ButtonsVBox` structure for panel-backed settings categories.
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_SettingsMenu` for enter/exit and interactive button motion.
  - `UI_SettingsMenu` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for `TitleLabel`,
    - `margin_section` for panel padding,
    - `separation_default` for panel content and button list spacing,
    - `panel_section` style override for `MainPanel`.
  - Dim behavior is now context-aware:
    - Overlay mode (`settings_menu_overlay` on top): `bg_base` at alpha `0.7`.
    - Embedded main-menu mode: no dim (`alpha = 0.0`) while preserving panel styling.
  - Updated `tests/unit/ui/test_settings_menu_visibility.gd`:
    - Added motion assignment coverage.
    - Added theme-token + overlay-dim coverage for overlay context.
    - Added regression coverage ensuring embedded mode keeps dim disabled.
    - Migrated node lookups to `%UniqueName` selectors for hierarchy safety.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_settings_menu_visibility.gd -gtest=res://tests/unit/ui/test_pause_menu.gd -gtest=res://tests/unit/ui/test_main_menu.gd` → 29/29 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2809/2818 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `ca75551a`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Phase 2 Screen 7 manual-smoke verified (`ui_settings_menu.tscn`)**
  - User-verified pause-overlay flow and embedded main-menu flow.
  - Verified all 8 category buttons open expected overlays, Back behavior is correct, overlay dim remains consistent with pause flow, and embedded mode keeps dim disabled while retaining panel styling.
- **2026-03-06: Phase 2 Screen 8 implemented (`ui_save_load_menu.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline dim `ColorRect`.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_SaveLoadMenu`.
  - `UI_SaveLoadMenu` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `subheading` for mode/spinner labels,
    - `section_header` for loading/error/back labels,
    - `danger` for error color,
    - `margin_section` for panel padding,
    - `separation_default`/`separation_compact` for content and slot spacing,
    - `panel_section` for panel surface styling,
    - `bg_base` at `0.5` alpha for dim background.
  - Runtime slot-row styling now uses the active theme tokens for row spacing, button font sizes, and thumbnail sizing.
  - Updated `tests/unit/ui/test_save_load_menu.gd`:
    - Added motion assignment + theme-token coverage with active config.
    - Added teardown/reset handling for `U_UIThemeBuilder.active_config` between tests.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_save_load_menu.gd -gtest=res://tests/unit/ui/test_save_load_menu_localization.gd` → 14/14 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2810/2819 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `c969b7f4`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Screen 8 confirmation-dialog chrome follow-up**
  - User feedback: default gray confirmation window chrome remained visually off-theme in save/load.
  - Initial fix attempt mapped `panel_section` to `ConfirmationDialog` and `Window` `panel` path; this was insufficient because Godot `Window` chrome does not use `panel`.
  - Added regression coverage in `tests/unit/ui/test_ui_theme_builder.gd`:
    - `test_build_theme_applies_dialog_window_panel_styles`
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd -gtest=res://tests/unit/ui/test_save_load_menu.gd` → 31/31 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `1b91c156`
- **2026-03-06: Screen 8 confirmation-dialog chrome correction**
  - Root cause verified via headless theme inspection: `Window` uses `embedded_border` / `embedded_unfocused_border` styleboxes (not `panel`).
  - Corrected fix in `U_UIThemeBuilder`:
    - Apply `panel_section` to `Window.embedded_border` and `Window.embedded_unfocused_border`.
    - Apply `title_color = text_primary` and transparent `title_outline_modulate` for themed window headers.
  - Updated regression coverage in `tests/unit/ui/test_ui_theme_builder.gd::test_build_theme_applies_dialog_window_panel_styles` to assert `Window` embedded border styleboxes + title colors.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_ui_theme_builder.gd -gtest=res://tests/unit/ui/test_save_load_menu.gd` → 31/31 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `2f61c70f`
- **2026-03-06: Phase 2 Screen 9 implemented (`ui_input_rebinding_overlay.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline `Background` color rect.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_InputRebindingOverlay`.
  - `UI_InputRebindingOverlay` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for title,
    - `section_header` for status + action buttons,
    - `body_small` for search box text,
    - `margin_section` for panel padding,
    - `separation_default`/`separation_compact` for button/action list spacing,
    - `panel_section` for panel surface styling,
    - `bg_base` at `0.7` alpha for dim background.
  - Updated `tests/unit/ui/test_input_rebinding_overlay.gd`:
    - Added motion/theme-token coverage with active config.
    - Added setup/teardown reset handling for `U_UIThemeBuilder.active_config`.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/integration/test_rebinding_flow.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2812/2821 passing, 0 failing, 9 pending/risky
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `3739f301`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Screen 9 input-rebinding follow-up (search styling + row keyboard nav)**
  - User feedback from manual smoke: search action box looked off-theme, and keyboard left/right navigation in center rebind rows was not selecting/highlighting correctly.
  - `UI_InputRebindingOverlay` updates:
    - Added tokenized search `LineEdit` style overrides (`normal`/`focus`/`read_only`) with themed placeholder/caret colors.
    - Added `_unhandled_key_input(...)` directional handling for row/bottom controls (while preserving search-caret behavior).
    - Added focus-sync helpers so internal row/bottom indices stay aligned with actual focused controls.
  - `U_RebindFocusNavigation.connect_row_focus_handlers(...)` now syncs overlay focus-tracking state on `focus_entered` for row container/add/replace/reset controls.
  - Updated `tests/unit/ui/test_input_rebinding_overlay.gd`:
    - Added `test_keyboard_horizontal_navigation_cycles_row_buttons_and_preserves_row_highlight`.
    - Extended theme-token coverage assertions for search style overrides.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/integration/test_rebinding_flow.gd` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
  - Implementation commit: `3ad822c9`
  - Manual smoke re-run: completed (user-verified on 2026-03-06)
- **2026-03-06: Phase 2 Screen 10 implemented (`ui_input_profile_selector.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline `Background` color rect.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_InputProfileSelector`.
  - `UI_InputProfileSelector` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for title,
    - `subheading` for active-profile preview header,
    - `section_header` for profile/action buttons,
    - `body_small` + `text_secondary` for description/action labels,
    - `margin_section` for panel padding,
    - `separation_default`/`separation_compact` for profile/preview/action spacing,
    - `panel_section` for panel surface styling,
    - `bg_base` at `0.5` alpha for dim background.
  - Updated tests:
    - Added Screen 10 motion/theme token coverage in `tests/unit/ui/test_input_profile_selector.gd`.
    - Migrated input-profile-selector test lookups to `%UniqueName` selectors in `tests/unit/ui/test_input_profile_selector.gd`, `tests/unit/input/test_input_profile_mobile_regression.gd`, and `tests/unit/integration/test_input_profile_selector_overlay.gd`.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/input/test_input_profile_mobile_regression.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2814/2823 passing, 0 failing, 9 pending/risky
  - Implementation commit: `509e75de`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Phase 2 Screen 11 implemented (`ui_gamepad_settings_overlay.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline `Background` color rect.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_GamepadSettingsOverlay`.
  - `UI_GamepadSettingsOverlay` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for title,
    - `section_header` for slider/setting labels and action buttons,
    - `body_small` + `text_secondary` for numeric value labels,
    - `margin_section` for panel padding,
    - `separation_compact` for row spacing,
    - `panel_section` for both main panel and preview-panel chrome,
    - `bg_base` at `0.5` alpha for dim background.
  - Updated tests:
    - Added Screen 11 motion/theme token coverage in `tests/unit/ui/test_gamepad_settings_overlay.gd`.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd` → 3/3 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd` → 1/1 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2815/2824 passing, 0 failing, 9 pending/risky
  - Implementation commit: `5a40761f`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Phase 2 Screen 12 implemented (`ui_touchscreen_settings_overlay.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline `Background` color rect.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Added themed preview chrome (`PreviewPanel`) and assigned `motion_set = cfg_motion_fade_slide` to `UI_TouchscreenSettingsOverlay`.
  - `UI_TouchscreenSettingsOverlay` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for title,
    - `section_header` for slider row labels and action buttons,
    - `body_small` + `text_secondary` for slider numeric values,
    - `margin_section` for panel padding,
    - `separation_default`/`separation_compact` for content and row spacing,
    - `panel_section` for main panel + preview panel chrome,
    - `bg_base` at `0.5` alpha for dim background.
  - Updated tests:
    - Added Screen 12 motion/theme token coverage in `tests/unit/ui/test_touchscreen_settings_overlay.gd`.
    - Added test hygiene reset for `U_UIThemeBuilder.active_config` and disabled state-store persistence in setup to avoid ambient save leakage.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 40/40 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2822/2831 passing, 0 failing, 9 pending/risky
  - Implementation commit: `1c9f52ab`
  - Manual smoke: completed (user-verified on 2026-03-06)
- **2026-03-06: Screen 12 preview-centering follow-up**
  - User feedback: touchscreen preview joystick/buttons were drifting to the bottom of the preview panel.
  - Fix:
    - Restored Screen 12 panel footprint to the original `560x520`.
    - Added `PreviewCenterContainer` under `PreviewPanel` and re-parented `%PreviewContainer` through it so preview content remains centered.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing
- **2026-03-06: Screen 12 panel-fit size-limit follow-up**
  - User feedback: touchscreen size sliders could grow controls beyond preview panel dimensions.
  - Fix:
    - Reset now dispatches clamped slider values (`_joystick_size_slider.value`, `_button_size_slider.value`) instead of raw resource defaults, so persisted settings cannot bypass panel-fit size limits.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` → 12/12 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
- **2026-03-06: Phase 2 Screen 13 implemented (`ui_edit_touch_controls_overlay.tscn`)**
  - Scene composition migrated to overlay-panel pattern:
    - Removed legacy inline background dim node and standardized on `BaseOverlay` backdrop color.
    - Added centered panel structure (`MainPanelMotionHost` + `MainPanel` + `MainPanelPadding` + `MainPanelContent`).
    - Assigned `motion_set = cfg_motion_fade_slide` to `UI_EditTouchControlsOverlay`.
  - `UI_EditTouchControlsOverlay` now applies `RS_UIThemeConfig` tokens from `U_UIThemeBuilder.active_config`:
    - `heading` for title,
    - `section_header` for drag-mode toggle and action buttons,
    - `body_small` + `text_secondary` for instructions,
    - `margin_section` for panel padding,
    - `separation_default`/`separation_compact` for content and row spacing,
    - `panel_section` for panel surface styling,
    - `bg_base` at `0.05` alpha for dim background (unique translucent feel preserved).
  - Added regression coverage:
    - `tests/unit/ui/test_edit_touch_controls_overlay.gd::test_edit_touch_controls_overlay_has_motion_and_theme_tokens_when_active_config_set`
    - `tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` now resets `U_UIThemeBuilder.active_config` for test isolation.
  - Verification:
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 7/7 passing
    - `tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_input_rebinding_overlay.gd -gtest=res://tests/unit/ui/test_input_profile_selector.gd -gtest=res://tests/unit/integration/test_input_profile_selector_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay.gd -gtest=res://tests/unit/ui/test_gamepad_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay.gd -gtest=res://tests/unit/ui/test_touchscreen_settings_overlay_localization.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay.gd -gtest=res://tests/unit/ui/test_edit_touch_controls_overlay_localization.gd` → 41/41 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` → 13/13 passing
    - `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` → 2823/2832 passing, 0 failing, 9 pending/risky
  - Implementation commit: `63e0746e`
  - Manual smoke: completed (user-verified on 2026-03-06)

- **2026-03-06: Phase 2 Screens 8-13 manual-smoke verified**
  - User confirmed all remaining manual smoke checks passed for:
    - `ui_save_load_menu.tscn`
    - `ui_input_rebinding_overlay.tscn`
    - `ui_input_profile_selector.tscn`
    - `ui_gamepad_settings_overlay.tscn`
    - `ui_touchscreen_settings_overlay.tscn`
    - `ui_edit_touch_controls_overlay.tscn`
  - Phase 2 overlay-screen pass is now implementation + manual-smoke complete.

### Plan Change Summary (2026-03-05)

| Aspect | Old Plan | New Plan |
|--------|----------|----------|
| Approach | Framework-first (build all infrastructure, then migrate) | Screen-by-screen (minimal infrastructure, then polish each screen) |
| Phases | 8 (Theme → Motion → Base Classes → HUD Framework → Widgets → Migration → @tool → Docs) | 6 (0: Infrastructure → 1: Menus → 2: Overlays → 3: Settings Tabs → 4: HUD → 5: Polish) |
| HUD Widgets | 5 new widgets (notification, objectives, currency, timer, minimap) | Deferred — no new HUD widgets |
| @tool Previews | Theme + motion preview scripts | Deferred |
| Number Ticker | `U_UINumberTicker` utility | Deferred |
| Scope | New features + migration | Polish existing screens only |

### Branch State (as of 2026-03-06)

The `UI-Looksmaxxing` branch contains:
- Completed "UI, Layers & Transitions Refactor" (7 phases)
- Ad-hoc visual polish commits (fade-in transitions for endgame screens, red flash removal)
- Documentation updates for the revised plan
- Phase 1 Screen 1 main-menu migration commit: `aaa7f75c`
- Phase 1 Screen 2 game-over migration commit: `f2fb658a`
- Phase 1 Screen 3 victory migration commit: `b05c75df`
- Phase 1 Screen 4 credits migration commit: `c747d478`
- Phase 1 Screen 5 language-selector migration commit: `3a9ab267`
- Navigation reducer follow-up commit: `4f7bdccb`
- Integration await hardening commit: `b9197a89`
- Phase 2 Screen 6 pause-menu migration commit: `5a4ee078`
- Screen 6 documentation update commit: `b156374e`
- Screen 6 commit-reference doc patch: `e3a2375f`
- Screen 6 panel-only-slide refinement commit: `0df2deae`
- Screen 6 centering regression fix commit: `5e7e679b`
- Default panel-only motion-target rollout commit: `87865a19`
- Phase 2 Screen 7 settings-menu migration commit: `ca75551a`
- Phase 2 Screen 8 save-load-menu migration commit: `c969b7f4`
- Screen 8 confirmation-dialog chrome follow-up commit: `1b91c156`
- Screen 8 confirmation-dialog chrome correction commit: `2f61c70f`
- Phase 2 Screen 9 input-rebinding-overlay migration commit: `3739f301`
- Screen 9 input-rebinding follow-up commit: `3ad822c9`
- Phase 2 Screen 10 input-profile-selector migration commit: `509e75de`
- Phase 2 Screen 11 gamepad-settings-overlay migration commit: `5a40761f`
- Phase 2 Screen 12 touchscreen-settings-overlay migration commit: `1c9f52ab`
- Phase 2 Screen 13 edit-touch-controls-overlay migration commit: `63e0746e`
- Screen 13 documentation + continuation update commit: `a53b0d78`
- Phase 2 settings-overlay wrappers migration commit: `96df500e`
- Phase 3 Screen 14 localization-settings-tab migration commit: `c94de23c`
- Screen 14 localization-overlay centering fix commit: `abc897ed`
- Phase 3 Screen 15 audio-settings-tab migration commit: `2b4db1c9`
- Screen 15 audio-settings-overlay centering fix commit: `217f77a6`
- Phase 4 Screen 17 HUD-overlay migration commit: `9e306d4d`
- Phase 4 Screen 18 button-prompt migration commit: `1755bc5b`

## Context

The template's UI is functionally complete but visually bare. All styling is inline `theme_override_*` per scene (119 overrides across 13 `.tscn` files), there is no global Theme resource, no animation/motion system. This overhaul systematically polishes each screen while migrating inline overrides to a shared theme.

Additionally, the two existing theme systems (font applier + display theme applier) have a latent last-writer-wins bug where both overwrite `control.theme =` independently. Phase 0C fixes this as part of the unification.

### Key Integration Points

- **Font applier**: `U_LocalizationFontApplier.build_theme()` already creates a Theme per UI root with font overrides. The new `U_UIThemeBuilder` extends this Theme — it does NOT replace the font applier.
- **Config access**: `U_UIThemeBuilder.active_config` static var, set in `root.gd` via preload. No ServiceLocator involvement (ServiceLocator only accepts Node instances).
- **Display theme applier**: `U_DisplayUIThemeApplier` currently applies palette colors independently. Phase 0C migrates this into the unified pipeline — palette data feeds into `U_UIThemeBuilder` alongside fonts and theme config.
- **Palette manager**: `U_PaletteManager` provides color-blind palette to both the unified theme builder (for font_color) and the HUD controller (for health bar fill). These are separate consumers.
- **Base classes**: `BasePanel` → `BaseMenuScreen` → `BaseOverlay` hierarchy gets opt-in motion support via exported `RS_UIMotionSet` resource (null = no change).

### Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Theme system | Extend `U_LocalizationFontApplier`, don't replace | Font cascade must be preserved; theme builder merges onto font applier output |
| Motion framework | Resource-driven tweens (`RS_UIMotionPreset`/`RS_UIMotionSet`) | Designer-friendly, swappable, no code changes needed to adjust feel |
| Motion ↔ Sound | Decoupled — motion never calls `U_UISoundPlayer` | Separate concerns; sound handled by existing systems |
| Backward compat | All features opt-in via exported resources | `null` resource = zero behavioral change everywhere |
| Config access | Static var on `U_UIThemeBuilder`, set in `root.gd` | ServiceLocator only accepts Node instances; static var is simpler and type-safe |
| Theme unification | `U_UIThemeBuilder` composes fonts + palette colors + styleboxes into single Theme | Replaces independent application by font applier and display theme applier. Fixes latent last-writer-wins bug where both overwrite `control.theme =` independently |
| Health bar fill | Stays palette-driven (color-blind). Only background migrates to theme | `U_PaletteManager` dynamically sets fill based on health % and color-blind mode (success/warning/danger) |
| Color palette | Duel (256-color) from [Lospec](https://lospec.com/palette-list/duel) | Cohesive cinematic aesthetic; 19 semantic tokens mapped to palette hex values (`health_fill` excluded — palette-driven) |
| Approach | Screen-by-screen (not framework-first) | Ensures behavior preservation, contextual visual improvements, and incremental progress |

### Color Token Quick Reference

| Token | Hex | Role |
|-------|-----|------|
| `bg_base` | `#1d1d21` | Deepest background |
| `bg_panel` | `#282b4a` | Panel backgrounds |
| `bg_panel_light` | `#3b3855` | Elevated panels, hover |
| `bg_surface` | `#434549` | Input fields, slider tracks |
| `text_primary` | `#f5f7fa` | Primary text |
| `text_secondary` | `#cdd2da` | Muted text |
| `text_disabled` | `#828b98` | Disabled text |
| `accent_primary` | `#41b2e3` | Buttons, links, focus |
| `accent_hover` | `#52d2ff` | Hover highlight |
| `accent_pressed` | `#318eb8` | Pressed state |
| `accent_focus` | `#55b1f1` | Focus ring |
| `section_header` | `#96b2d9` | Section header text |
| `danger` | `#e45c5f` | Danger actions |
| `success` | `#7da42d` | Positive/completion |
| `warning` | `#ffbc4e` | Warnings |
| `golden` | `#ecc581` | Special callouts |
| `health_bg` | `#3a4568` | Health bar background (fill is palette-driven) |
| `slider_fill` | `#41b2e3` | Slider fill |
| `slider_bg` | `#434549` | Slider track |

Full Godot `Color()` values and derivation details in PRD "Resolved Questions" section.

### Phase Overview

```
Phase 0 (Infrastructure) ── Phase 1 (Full-Screen Menus) ── Phase 2 (Overlays) ── Phase 3 (Settings Tabs) ── Phase 4 (HUD) ── Phase 5 (Polish)
```

All phases are sequential. After every screen: run full test suite, verify behavior, confirm visual improvement.

## Required Readings

- `AGENTS.md` — project conventions, testing, and update rules
- `docs/general/DEV_PITFALLS.md` — known gotchas
- `docs/general/STYLE_GUIDE.md` — naming, formatting, prefix rules
- `docs/general/SCENE_ORGANIZATION_GUIDE.md` — layer/container reference
- `docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md` — the task checklist
- `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md` — requirements

## Next Steps

1. Run manual smoke for Phase 3 Screens 15/16 (`ui_audio_settings_tab.tscn`, `ui_display_settings_tab.tscn`) and Phase 4 Screens 17/18 (`ui_hud_overlay.tscn`, `ui_button_prompt.tscn`) to verify in-game visual feel and HUD feedback timing.
2. Begin Phase 4 Screen 19 (`ui_loading_screen.tscn`) and migrate loading-screen typography/progress-bar overrides to token-driven styling.
3. Continue with Phase 5 polish verification once Screen 19 automated checks are green.

Updated next action (2026-03-06): Run pending manual smoke for Screens 15/16/17/18, then start Phase 4 Screen 19 loading-screen migration.

## Key Files (Phase 0 Infrastructure — Completed)

### Infrastructure (Phase 0)

| File | Purpose |
|------|---------|
| `scripts/resources/ui/rs_ui_theme_config.gd` | Master theme config resource |
| `resources/ui/cfg_ui_theme_default.tres` | Default theme instance |
| `scripts/ui/utils/u_ui_theme_builder.gd` | Theme merge utility |
| `scripts/resources/ui/rs_ui_motion_preset.gd` | Single tween recipe |
| `scripts/resources/ui/rs_ui_motion_set.gd` | Motion preset collection |
| `resources/ui/motions/cfg_motion_fade_slide.tres` | Screen enter/exit preset |
| `resources/ui/motions/cfg_motion_button_default.tres` | Button hover/press preset |
| `resources/ui/motions/cfg_motion_hud_pop.tres` | HUD widget pop-in preset |
| `scripts/ui/utils/u_ui_motion.gd` | Motion playback utility |

### Tests (Phase 0)

| File | Purpose |
|------|---------|
| `tests/unit/ui/test_ui_theme_builder.gd` | Theme merging tests |
| `tests/unit/ui/test_ui_motion.gd` | Motion play/bind tests |

## Key Files (Modified)

| File | Phase | Change |
|------|-------|--------|
| `scripts/managers/helpers/localization/u_localization_font_applier.gd` | 0C | Call through `U_UIThemeBuilder` when `active_config` set |
| `scripts/managers/m_display_manager.gd` | 0C | Stop independent theme application, trigger unified rebuild |
| `scripts/managers/helpers/display/u_display_ui_theme_applier.gd` | 0C | Feeds palette into builder instead of applying independently |
| `scripts/ui/base/base_panel.gd` | 0F | Add `@export var motion_set` + bind interactive children |
| `scripts/ui/base/base_menu_screen.gd` | 0F | Add enter/exit animation methods |
| `scripts/ui/base/base_overlay.gd` | 0F | Animate dim background with content motion |
| `scripts/ui/hud/ui_hud_controller.gd` | 4 | Extract tween params to motion resources |
| `scripts/ui/hud/ui_button_prompt.gd` | 4 | Apply button-prompt token overrides from active theme config |
| 14 `.tscn` files with overrides (124 total) | 1-4 | Remove inline `theme_override_*` values, apply theme |
| 4 settings overlay wrappers | 2 | Theme application, dim standardization |
| `AGENTS.md` | 5C | New patterns |
| `docs/general/DEV_PITFALLS.md` | 5C | New pitfalls |

## Deferred Items (Not in Current Scope)

These were in the original plan but are deferred to a future pass:

- `scripts/ui/utils/u_ui_number_ticker.gd` — animated number counting utility
- `scripts/ui/hud/base_hud_widget.gd` — HUD widget base class
- `scripts/resources/ui/rs_hud_widget_config.gd` — per-widget config
- 5 HUD widgets: notification queue, objective tracker, currency/score, timer, minimap slot
- `@tool` editor preview scripts for themes and motion
- All corresponding tests and `.tres` configs for the above

## Outstanding Risks

- Default theme values documented in PRD "Resolved Questions" — derived from auditing ~130 inline overrides. Low risk.
- Phase 3-4 migration (removing inline overrides from override-heavy screens) could cause subtle visual regressions — mitigated by per-screen test runs.
- Unified theme pipeline (Phase 0C) touches both display manager and localization manager — integration testing critical.
- Endgame screens have no existing tweens — Phase 1 adds new motion (fade-in enter), no extraction needed.
- Health bar fill stays palette-driven; must NOT be migrated to theme config.

## Verification Strategy

After **every screen**:
1. Run the full test suite to catch regressions
2. Verify the specific screen's behavior is unchanged (buttons work, navigation works, data displays correctly)
3. Confirm visual improvement is contextually appropriate

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes -> update references -> run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.

## Links

- PRD: `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`
- Tasks: `docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md`
- Prerequisite refactor: `docs/general/ui_layers_transitions_refactor/`
