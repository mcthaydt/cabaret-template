# UI Visual Overhaul — Tasks

**Progress:** 3% (2 / 62 tasks complete)

## Prerequisite

- [x] Confirm "UI, Layers & Transitions Refactor" is complete (all 7 phases in `docs/general/ui_layers_transitions_refactor/`) — completed 2026-03-03, branch `UI-Looksmaxxing`
- [x] Confirm test baselines: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` — baselines green

---

## Phase 1 — Global Theme Resource System

### 1A — Theme Config Resource

- [ ] Create `scripts/resources/ui/rs_ui_theme_config.gd` — `RS_UIThemeConfig extends Resource` with `@export_group` sections:
  - Typography: font sizes for title, heading, body, caption, button
  - Spacing: margins, separations
  - Button Styles: normal/hover/pressed/focus/disabled `StyleBoxFlat`
  - Panel Styles
  - Progress Bar Styles
  - Focus styling
- [ ] Create `resources/ui/cfg_ui_theme_default.tres` — default minimal/cinematic theme instance. **Default values (typography, colors, spacing) are documented in the PRD "Resolved Questions" section.**

### 1B — Theme Builder Utility

- [ ] Create `scripts/ui/utils/u_ui_theme_builder.gd` — static utility that merges `RS_UIThemeConfig` styleboxes/sizes onto a `U_LocalizationFontApplier.build_theme()` output. Fallback: works standalone if no font applier available.

### 1C — Font Applier Integration

- [ ] Modify `scripts/managers/helpers/localization/u_localization_font_applier.gd` — `apply_theme_to_root()` calls through `U_UIThemeBuilder` when a theme config is registered via ServiceLocator (`StringName("ui_theme_config")`). If none registered, existing font-only behavior unchanged.

### 1D — Tests

- [ ] Create `tests/unit/ui/test_ui_theme_builder.gd` — test theme merging, standalone fallback, null config path
- [ ] Run style enforcement: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [ ] Run full test suite to confirm no regressions

---

## Phase 2 — UI Motion/Animation Framework

### 2A — Motion Resources

- [ ] Create `scripts/resources/ui/rs_ui_motion_preset.gd` — single tween recipe: `property_path` (String), `from_value`/`to_value` (Variant), `relative` (bool), `duration_sec`, `delay_sec`, `transition_type`, `ease_type`, `parallel` (bool — when true, runs in parallel with previous step instead of sequentially), `interval_sec` (float — when > 0 and `property_path` is empty, acts as a `tween_interval()` hold step)
- [ ] Create `scripts/resources/ui/rs_ui_motion_set.gd` — collection of presets per interaction: `enter`, `exit`, `hover_in`, `hover_out`, `press`, `focus_in`, `focus_out`, `pulse` (all `Array[RS_UIMotionPreset]`)

### 2B — Default Motion Presets

- [ ] Create `resources/ui/motions/cfg_motion_fade_slide.tres` — default screen enter/exit (fade + slide-up)
- [ ] Create `resources/ui/motions/cfg_motion_button_default.tres` — default button hover/press
- [ ] Create `resources/ui/motions/cfg_motion_hud_pop.tres` — HUD widget pop-in/pulse

### 2C — Motion Utility

- [ ] Create `scripts/ui/utils/u_ui_motion.gd` — static utility: `play()`, `play_enter()`, `play_exit()`, `bind_interactive()` (connects mouse/focus signals to motion presets). Decoupled from sound — never calls `U_UISoundPlayer`.

### 2D — Number Ticker

- [ ] Create `scripts/ui/utils/u_ui_number_ticker.gd` — animated number counting utility for score/health/currency/timer labels. Tweens a float value and updates a Label each step with configurable format string.

### 2E — Tests

- [ ] Create `tests/unit/ui/test_ui_motion.gd`
- [ ] Create `tests/unit/ui/test_ui_number_ticker.gd`
- [ ] Run style enforcement
- [ ] Run full test suite

---

## Phase 3 — Base Class Integration

### 3A — BasePanel Motion Support

- [ ] Modify `scripts/ui/base/base_panel.gd` — add `@export var motion_set: RS_UIMotionSet = null`. In `_on_panel_ready()`, if motion_set is set, call `U_UIMotion.bind_interactive()` on all focusable children (reuse existing `_find_focusable_in()`)

### 3B — BaseMenuScreen Enter/Exit

- [ ] Modify `scripts/ui/base/base_menu_screen.gd` — add `play_enter_animation()` and `play_exit_animation()` methods that delegate to `U_UIMotion` if `motion_set` is assigned. Returns tween.finished signal for chaining.

### 3C — BaseOverlay Animation

- [ ] Modify `scripts/ui/base/base_overlay.gd` — override enter/exit to animate the dim `ColorRect` background alongside content motion

### 3D — Regression Tests

- [ ] Confirm null `motion_set` path is identical to current behavior (zero behavioral change)
- [ ] Run full test suite

---

## Phase 4 — HUD Widget Framework + Existing HUD Enhancement

### 4A — Widget Base Class

- [ ] Create `scripts/ui/hud/base_hud_widget.gd` — `BaseHUDWidget extends Control`: store subscription via `U_StateUtils`, `show_widget()`/`hide_widget()` with motion, `_should_show(state)` visibility gating by shell/pause/transition state
- [ ] Create `scripts/resources/ui/rs_hud_widget_config.gd` — per-widget config: `widget_id` (StringName), `visible_shells` (Array[StringName], default `[&"gameplay"]`), `hide_when_paused` (bool), `hide_during_transition` (bool)
- [ ] Create `tests/unit/ui/test_base_hud_widget.gd`

### 4B — Existing HUD Enhancement

- [ ] Modify `scripts/ui/hud/ui_hud_controller.gd` — extract hardcoded tween params into exported `RS_UIMotionPreset` resources with defaults matching current values:
  - Checkpoint toast: fade-in 0.2s TRANS_CUBIC, hold 1.0s, fade-out 0.3s
  - Signpost: fade-in 0.14s EASE_OUT, fade-out 0.18s EASE_IN
- [ ] Integrate `U_UINumberTicker` for health label animated value changes
- [ ] Verify visual behavior identical unless resources are swapped

### 4C — Tests

- [ ] Run HUD tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true`
- [ ] Run full test suite

---

## Phase 5 — Opt-In HUD Widgets

### 5A — Notification Queue

- [ ] Create `scripts/ui/hud/ui_notification_queue.gd` + `.tscn`
- [ ] Create `scripts/resources/ui/rs_notification_config.gd` + `resources/ui/hud/cfg_notification_default.tres`
- [ ] Create `tests/unit/ui/test_ui_notification_queue.gd`

### 5B — Objective Tracker

- [ ] Create `scripts/ui/hud/ui_objective_tracker.gd` + `.tscn`
- [ ] Create `scripts/resources/ui/rs_objective_tracker_config.gd` + `resources/ui/hud/cfg_objective_tracker_default.tres`
- [ ] Create `tests/unit/ui/test_ui_objective_tracker.gd`

### 5C — Currency/Score Display

- [ ] Create `scripts/ui/hud/ui_currency_display.gd` + `.tscn`
- [ ] Create `scripts/resources/ui/rs_currency_display_config.gd` + `resources/ui/hud/cfg_currency_display_default.tres`
- [ ] Create `tests/unit/ui/test_ui_currency_display.gd`

### 5D — Timer Widget

- [ ] Create `scripts/ui/hud/ui_timer_widget.gd` + `.tscn`
- [ ] Create `scripts/resources/ui/rs_timer_config.gd` + `resources/ui/hud/cfg_timer_default.tres`
- [ ] Create `tests/unit/ui/test_ui_timer_widget.gd`

### 5E — Minimap Slot

- [ ] Create `scripts/ui/hud/ui_minimap_slot.gd` + `.tscn`
- [ ] Create `scripts/resources/ui/rs_minimap_slot_config.gd` + `resources/ui/hud/cfg_minimap_slot_default.tres`
- [ ] Create `tests/unit/ui/test_ui_minimap_slot.gd`

### 5F — Tests

- [ ] Run full test suite after all widgets

---

## Phase 6 — Theme Migration

- [ ] Migrate `scenes/ui/hud/ui_hud_overlay.tscn` (~28 overrides) — remove inline overrides covered by Theme, verify visual match
- [ ] Migrate `scenes/ui/settings/ui_display_settings_tab.tscn` (~43 overrides)
- [ ] Migrate `scenes/ui/settings/ui_audio_settings_tab.tscn` (~18 overrides)
- [ ] Migrate remaining ~10 scenes (1-5 overrides each)
- [ ] Keep per-element semantic overrides (e.g., signpost golden text)
- [ ] Run full test suite
- [ ] Before/after visual comparison per scene

---

## Phase 7 — @tool Editor Preview Scripts

- [ ] Create `scripts/ui/tools/u_ui_theme_preview.gd` — `@tool`, drop into any UI scene, assign `RS_UIThemeConfig`, see theme applied live. Setter triggers `_update_preview()` on resource change. `queue_free()` at runtime, `Engine.is_editor_hint()` guards, `_get_configuration_warnings()`.
- [ ] Create `scripts/ui/tools/u_ui_motion_preview.gd` — `@tool`, drop into any UI scene, assign `RS_UIMotionSet`, toggle `@export var preview_enter: bool` to play animation in editor viewport. Same runtime/editor guards.
- [ ] Run style enforcement

---

## Phase 8 — Documentation & Polish

- [ ] Update `AGENTS.md` — add patterns for theme system, motion framework, HUD widget architecture
- [ ] Update `docs/general/DEV_PITFALLS.md` — add:
  - "Use `RS_UIThemeConfig` for styling, not inline `theme_override_*`"
  - "HUD widgets extend `BaseHUDWidget`"
  - "`@tool` scripts must `queue_free()` at runtime"
- [ ] Final full test suite: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true`
- [ ] Manual smoke test: menu animations, button effects, HUD pop-in, health ticker, checkpoint toast animation
- [ ] Mobile compatibility verification
- [ ] Update this task list with final completion notes
- [ ] Update continuation prompt with final status

---

## Notes

- Phases 1 and 2 can be developed in parallel (no dependencies between them).
- Phase 6 (Theme Migration) can run in parallel with Phases 4-5.
- Phase 7 depends on Phases 1 and 2.
- Phase 8 runs after all other phases.
- If `motion_set` is null (the default), zero behavioral change — all existing screens work identically.
- Inline `theme_override_*` values stay in `.tscn` files until Phase 6 migration (they override the Theme resource).

## Links

- PRD: `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`
- Continuation prompt: `docs/ui_visual_overhaul/ui-visual-overhaul-continuation-prompt.md`
- Prerequisite refactor: `docs/general/ui_layers_transitions_refactor/`
