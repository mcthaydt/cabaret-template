# Localization Manager Refactor - Continuation Prompt

**Last Updated:** 2026-02-16
**Status:** Refactor planned. Progress 14% (8 / 59 tasks complete). Translation audit captured and partially resolved.

## Start Here

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/localization_manager/localization-manager-plan.md`
- `docs/localization_manager/localization-manager-refactor-tasks.md`

## Baseline (Pre-Refactor)

- Localization slice exists in Redux and persists via global settings serialization.
- `M_LocalizationManager` orchestrates locale selection, preview mode, font theme building, root registration, and UI scale dispatch.
- `U_LocalizationUtils.localize()` and `localize_fmt()` are the public helpers (do not call `tr()`).
- Locale catalogs are `.tres` resources (`RS_LocaleTranslations`) loaded via `U_LocaleFileLoader` constants for en/es/pt/ja/zh_CN.
- `U_LocalizationRoot` registers UI roots; many scenes include `LocalizationRoot`.
- `UI_LocalizationSettingsTab` provides apply/cancel/reset with confirm timer and preview integration.

## Refactor Goals (Short)

- Extract catalog, font applier, root registry, preview controller helpers.
- Clarify UI scale ownership between localization and display.
- Strengthen tests and reduce manager surface area.

## Last Work

- 2026-02-16: Closed several Task 7.2a gaps:
  - Localized HUD prompt fallbacks (`ui_button_prompt.gd`, `ui_virtual_button.gd`).
  - Localized input profile action labels and profile name/description via keys (updated `cfg_*.tres` profiles + selector UI).
  - Localized save/load timestamp tokens (month names + AM/PM) and added `date.*` keys.
  - Added `LocalizationRoot` to settings tab scenes (display/audio/localization).
  - Updated `test_locale_file_loader.gd` to validate `.tres` merge behavior.

## Audit Findings Summary (See Task 7.2a for Full List)

- Multiple UI settings overlays and helpers still contain hardcoded user-facing strings (display/audio/vfx/gamepad/touchscreen/input/rebind/save-load).
- Input profile `.tres` resources store display strings instead of localization keys. (resolved 2026-02-16)
- Save/load date formatting uses hardcoded month names and AM/PM tokens. (resolved 2026-02-16)
- Some settings tab scenes appear to be missing `LocalizationRoot`, so live locale updates are not applied. (resolved 2026-02-16)

## Immediate Next Steps

1. Phase 0 in `docs/localization_manager/localization-manager-refactor-tasks.md` (architecture contract freeze) to lock the target refactor surface.
2. Execute Task 7.2a to close translation coverage gaps before refactor churn.
3. Proceed with Phase 1 interface tests, then helper extraction phases.

## Key Pitfalls

- `localization_initial_state` is the 13th parameter to `initialize_slices()` in `M_StateStore`.
- Locale resources use `const` preload arrays in `U_LocaleFileLoader` (mobile-safe); do not revert to JSON file IO.
- Theme-based font cascade uses a constructed `Theme` assigned to root `Control.theme`; `_FONT_THEME_TYPES` includes `&"Control"`.
- `preload()` on `.ttf` does not work; use `load()` and guard for null.
- Do not use `tr()` or `Object.tr()`; use `U_LocalizationUtils.localize()` / `localize_fmt()`.
- Use `str(value)` for Variant-to-string conversion.
- Inner class names must start with a capital letter (GDScript 4 parser).
- Settings tab scenes live in `scenes/ui/overlays/settings/` and require overlay wrappers + registry entries.
