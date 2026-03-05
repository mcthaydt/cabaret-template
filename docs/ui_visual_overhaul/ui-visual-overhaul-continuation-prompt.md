# UI Visual Overhaul — Continuation Prompt

## Current Focus

- Feature / story: UI Visual Overhaul (Screen-by-Screen)
- Branch: `UI-Looksmaxxing`
- Status summary: **Ready to implement** — plan revised to screen-by-screen approach, documentation updated.

## Recent Progress

- Created PRD (`docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`)
- Created task checklist (`docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md`)
- **"UI, Layers & Transitions Refactor" completed** — all 7 phases done on branch `UI-Looksmaxxing`
- **2026-03-05: Plan revised** — replaced framework-first approach (8 phases) with screen-by-screen approach (6 phases: 0-5). Deferred HUD widgets, @tool previews, and number ticker. Focus is on polishing all existing screens + enhancing existing HUD.

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

### Key Integration Points

- **Font applier**: `U_LocalizationFontApplier.build_theme()` already creates a Theme per UI root with font overrides. The new `U_UIThemeBuilder` extends this Theme — it does NOT replace the font applier.
- **ServiceLocator**: Theme config registered as `StringName("ui_theme_config")` — follows existing pattern.
- **Base classes**: `BasePanel` → `BaseMenuScreen` → `BaseOverlay` hierarchy gets opt-in motion support via exported `RS_UIMotionSet` resource (null = no change).

### Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Theme system | Extend `U_LocalizationFontApplier`, don't replace | Font cascade must be preserved; theme builder merges onto font applier output |
| Motion framework | Resource-driven tweens (`RS_UIMotionPreset`/`RS_UIMotionSet`) | Designer-friendly, swappable, no code changes needed to adjust feel |
| Motion ↔ Sound | Decoupled — motion never calls `U_UISoundPlayer` | Separate concerns; sound handled by existing systems |
| Backward compat | All features opt-in via exported resources | `null` resource = zero behavioral change everywhere |
| Color palette | Duel (256-color) from [Lospec](https://lospec.com/palette-list/duel) | Cohesive cinematic aesthetic; 20 semantic tokens mapped to palette hex values |
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
| `health_fill` | `#b64d46` | Health bar fill |
| `health_bg` | `#3a4568` | Health bar background |
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

1. Begin Phase 0A: Create `RS_UIThemeConfig` resource
2. Phase 0B: Create `U_UIThemeBuilder` utility
3. Phase 0C: Integrate font applier
4. Phase 0D-0E: Create motion resources and presets
5. Phase 0F: Base class integration
6. Phase 0G: Tests
7. Then proceed screen-by-screen through Phases 1-4

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
| `scripts/managers/helpers/localization/u_localization_font_applier.gd` | 0C | Call through `U_UIThemeBuilder` when theme config registered |
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
- Endgame screens (`ui_game_over.gd`, `ui_victory.gd`) currently use hardcoded tweens — Phase 1 should evaluate integrating them with the motion framework.

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
