# UI Visual Overhaul — Continuation Prompt

## Current Focus

- Feature / story: UI Visual Overhaul (Screen-by-Screen)
- Branch: `UI-Looksmaxxing`
- Status summary: **In progress** — Phase 0A-0F complete (theme + unified pipeline + motion resources + base class integration). Next: Phase 0G full-suite verification.

## Recent Progress

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

### Plan Change Summary (2026-03-05)

| Aspect | Old Plan | New Plan |
|--------|----------|----------|
| Approach | Framework-first (build all infrastructure, then migrate) | Screen-by-screen (minimal infrastructure, then polish each screen) |
| Phases | 8 (Theme → Motion → Base Classes → HUD Framework → Widgets → Migration → @tool → Docs) | 6 (0: Infrastructure → 1: Menus → 2: Overlays → 3: Settings Tabs → 4: HUD → 5: Polish) |
| HUD Widgets | 5 new widgets (notification, objectives, currency, timer, minimap) | Deferred — no new HUD widgets |
| @tool Previews | Theme + motion preview scripts | Deferred |
| Number Ticker | `U_UINumberTicker` utility | Deferred |
| Scope | New features + migration | Polish existing screens only |

### Branch State (as of 2026-03-05)

The `UI-Looksmaxxing` branch contains:
- Completed "UI, Layers & Transitions Refactor" (7 phases)
- Ad-hoc visual polish commits (fade-in transitions for endgame screens, red flash removal)
- Documentation updates for the revised plan

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

1. Begin Phase 0G: Run full suite verification for completed Phase 0
2. Then proceed screen-by-screen through Phases 1-4 (starting Phase 1 Screen 1: Main Menu)

Updated next action (2026-03-05): Run `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true` for Phase 0G gate, then begin Phase 1 Screen 1 migration.

## Key Files (New — To Be Created)

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
| 13 `.tscn` files with overrides (119 total) | 1-4 | Remove inline `theme_override_*` values, apply theme |
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
