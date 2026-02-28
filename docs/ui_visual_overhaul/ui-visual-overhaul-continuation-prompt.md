# UI Visual Overhaul — Continuation Prompt

## Current Focus

- Feature / story: UI Visual Overhaul
- Branch: TBD (create after prerequisite refactor completes)
- Status summary: **Not started** — documentation phase complete, awaiting "UI, Layers & Transitions Refactor" completion.

## Recent Progress

- Created PRD (`docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`)
- Created task checklist (`docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md`)
- Created this continuation prompt

## Context

The template's UI is functionally complete but visually bare. All styling is inline `theme_override_*` per scene (~119 overrides across ~13 `.tscn` files), there is no global Theme resource, no animation/motion system, and the HUD has only 4 widgets. This overhaul adds AAA-quality visual polish without changing any existing functionality.

### Key Integration Points

- **Font applier**: `U_LocalizationFontApplier.build_theme()` (`scripts/managers/helpers/localization/u_localization_font_applier.gd:45`) already creates a Theme per UI root with font overrides. The new `U_UIThemeBuilder` extends this Theme — it does NOT replace the font applier.
- **ServiceLocator**: Theme config registered as `StringName("ui_theme_config")` — follows existing pattern.
- **Redux/State**: HUD widgets subscribe to relevant slices via `U_StateUtils` — follows existing `UI_HudController` pattern.
- **Base classes**: `BasePanel` → `BaseMenuScreen` → `BaseOverlay` hierarchy gets opt-in motion support via exported `RS_UIMotionSet` resource (null = no change).

### Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Theme system | Extend `U_LocalizationFontApplier`, don't replace | Font cascade must be preserved; theme builder merges onto font applier output |
| Motion framework | Resource-driven tweens (`RS_UIMotionPreset`/`RS_UIMotionSet`) | Designer-friendly, swappable, no code changes needed to adjust feel |
| Motion ↔ Sound | Decoupled — motion never calls `U_UISoundPlayer` | Separate concerns; sound handled by existing systems |
| HUD widgets | Opt-in via `BaseHUDWidget` base class | No default HUD changes; developers add widgets they need |
| Backward compat | All features opt-in via exported resources | `null` resource = zero behavioral change everywhere |
| Editor tooling | `@tool` scripts following `U_CinemaGradePreview` pattern | `queue_free()` at runtime, `Engine.is_editor_hint()` guards |
| Color palette | Duel (256-color) from [Lospec](https://lospec.com/palette-list/duel) | Cohesive cinematic aesthetic; 20 semantic tokens mapped to palette hex values (see PRD "Resolved Questions") |
| Motion chaining | Sequential by default, `parallel` bool for concurrent steps, `interval_sec` for holds | Matches Godot's `Tween` default sequential behavior; existing HUD already chains fade-in → hold → fade-out |
| Default theme values | Typography (8 sizes), spacing (7 tokens), styleboxes (8 types) documented in PRD | Derived from auditing all ~119 inline `theme_override_*` across `.tscn` files |
| Inline overrides | Stay until Phase 6 migration | They override Theme resource, so migration can happen independently |

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

### Phase Dependency Graph

```
Phase 1 (Theme) ──┐
                   ├── Phase 3 (Base Class Integration) ── Phase 4 (HUD Framework) ── Phase 5 (Widgets)
Phase 2 (Motion) ─┘                                            │
     │                                                    Phase 6 (Migration) ← can parallel 4/5
     └── Phase 7 (@tool Previews)
                                                          Phase 8 (Docs) ← after all
```

## Required Readings

- `AGENTS.md` — project conventions, testing, and update rules
- `docs/general/DEV_PITFALLS.md` — known gotchas
- `docs/general/STYLE_GUIDE.md` — naming, formatting, prefix rules
- `docs/general/SCENE_ORGANIZATION_GUIDE.md` — layer/container reference
- `docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md` — the task checklist
- `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md` — requirements
- `docs/general/ui_layers_transitions_refactor/` — prerequisite refactor docs

## Next Steps

1. Complete the "UI, Layers & Transitions Refactor" (all 7 phases)
2. Confirm test baselines pass
3. Begin Phase 1 (Theme) and Phase 2 (Motion) in parallel
4. Phase 1A: Create `RS_UIThemeConfig` resource — audit current inline overrides to derive default values

## Key Files (New — To Be Created)

| File | Phase | Purpose |
|------|-------|---------|
| `scripts/resources/ui/rs_ui_theme_config.gd` | 1 | Master theme config resource |
| `resources/ui/cfg_ui_theme_default.tres` | 1 | Default theme instance |
| `scripts/ui/utils/u_ui_theme_builder.gd` | 1 | Theme merge utility |
| `scripts/resources/ui/rs_ui_motion_preset.gd` | 2 | Single tween recipe |
| `scripts/resources/ui/rs_ui_motion_set.gd` | 2 | Motion preset collection |
| `resources/ui/motions/cfg_motion_*.tres` | 2 | Default motion presets |
| `scripts/ui/utils/u_ui_motion.gd` | 2 | Motion playback utility |
| `scripts/ui/utils/u_ui_number_ticker.gd` | 2 | Animated number counter |
| `scripts/ui/hud/base_hud_widget.gd` | 4 | HUD widget base class |
| `scripts/resources/ui/rs_hud_widget_config.gd` | 4 | Per-widget config |
| `scripts/ui/hud/ui_notification_queue.gd` | 5 | Notification queue widget |
| `scripts/ui/hud/ui_objective_tracker.gd` | 5 | Objective tracker widget |
| `scripts/ui/hud/ui_currency_display.gd` | 5 | Currency/score widget |
| `scripts/ui/hud/ui_timer_widget.gd` | 5 | Timer widget |
| `scripts/ui/hud/ui_minimap_slot.gd` | 5 | Minimap container widget |
| `scripts/ui/tools/u_ui_theme_preview.gd` | 7 | @tool theme preview |
| `scripts/ui/tools/u_ui_motion_preview.gd` | 7 | @tool motion preview |

## Key Files (Modified)

| File | Phase | Change |
|------|-------|--------|
| `scripts/managers/helpers/localization/u_localization_font_applier.gd` | 1 | Call through `U_UIThemeBuilder` when theme config registered |
| `scripts/ui/base/base_panel.gd` | 3 | Add `@export var motion_set` + bind interactive children |
| `scripts/ui/base/base_menu_screen.gd` | 3 | Add enter/exit animation methods |
| `scripts/ui/base/base_overlay.gd` | 3 | Animate dim background with content motion |
| `scripts/ui/hud/ui_hud_controller.gd` | 4 | Extract tween params to resources, add number ticker |
| ~13 `.tscn` files | 6 | Remove inline `theme_override_*` values |
| `AGENTS.md` | 8 | New patterns |
| `docs/general/DEV_PITFALLS.md` | 8 | New pitfalls |

## Outstanding Risks

- Prerequisite refactor not yet complete — this work cannot begin until it is.
- Default theme values need to be derived from auditing ~119 inline overrides — tedious but low risk.
- Phase 6 migration (removing inline overrides) could cause subtle visual regressions — mitigated by per-scene before/after comparison.
- `@tool` scripts must be carefully guarded to avoid runtime side effects — follow `U_CinemaGradePreview` pattern exactly.

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes → update references → run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.

## Links

- PRD: `docs/ui_visual_overhaul/ui-visual-overhaul-prd.md`
- Tasks: `docs/ui_visual_overhaul/ui-visual-overhaul-tasks.md`
- Prerequisite refactor: `docs/general/ui_layers_transitions_refactor/`
