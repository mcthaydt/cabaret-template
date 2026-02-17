# Localization Manager Refactor - Continuation Prompt

**Last Updated:** 2026-02-17
**Status:** Refactor in progress. Phase 8 complete (100% of Phase 0-8 tasks: 63 / 63). Phase 9 documentation sync is next.

## Start Here

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/localization_manager/localization-manager-plan.md`
- `docs/localization_manager/localization-manager-refactor-tasks.md`

## Baseline (Pre-Refactor)

- Localization slice exists in Redux and persists via global settings serialization.
- `M_LocalizationManager` orchestrates locale selection, preview mode (via helper), font/theme application (via helper), and root registration (via helper).
- `U_LocalizationUtils.localize()` and `localize_fmt()` are the public helpers (do not call `tr()`).
- Locale catalogs are `.tres` resources (`RS_LocaleTranslations`) loaded via `U_LocalizationCatalog` constants for en/es/pt/ja/zh_CN (`U_LocaleFileLoader` kept as compatibility shim).
- `U_LocalizationRoot` registers UI roots; many scenes include `LocalizationRoot`.
- `UI_LocalizationSettingsTab` provides apply/cancel/reset with confirm timer and preview integration.

## Refactor Goals (Short)

- Extract catalog, font applier, root registry, preview controller helpers.
- Clarify UI scale ownership between localization and display.
- Strengthen tests and reduce manager surface area.

## Last Work

- 2026-02-17: Completed Phase 8 (test hardening):
  - Completed Task 8.1 by replacing brittle localization tests that asserted `M_LocalizationManager` internals with behavior-based checks:
    - updated `tests/unit/managers/test_localization_manager.gd` to validate store-sync, root-notification lifecycle, theme propagation, and CJK/dyslexia behavior through public APIs + root-observable behavior.
    - updated `tests/integration/localization/test_font_override.gd` to validate CJK font precedence via registered root theme behavior (no private method/property access).
  - Completed Task 8.3 by keeping integration coverage end-to-end (removed direct calls to `_get_active_font` and `_cjk_font` assertions).
  - Completed Task 8.4 with full localization suite verification:
    - `tests/unit/managers/test_localization_manager.gd` (25/25)
    - `tests/unit/managers/helpers/localization` (20/20)
    - `tests/unit/managers/helpers/test_locale_file_loader.gd` (3/3)
    - `tests/unit/utils/test_localization_utils.gd` (5/5)
    - `tests/unit/ui` localization scripts via `-gselect=localization` (10/10)
    - `tests/integration/localization` (20/20)
    - `tests/unit/style` (12/12)
- 2026-02-17: Completed Phase 7 (UI integration cleanup + translation coverage audit):
  - Completed Task 7.2 and 7.2a top-level audit closure for direct UI localization-manager usage and translation coverage.
  - Completed Task 7.2a.4 (`UI_GamepadSettingsOverlay`) with localized title/labels/tooltips/preview prompts + live locale relabeling.
  - Completed Task 7.2a.5 (`UI_TouchscreenSettingsOverlay` + `UI_EditTouchControlsOverlay`) with localized titles/labels/tooltips/buttons/instructions + live locale relabeling.
  - Completed Task 7.2a.8 (`UI_SaveLoadMenu`) with localized autosave/slot fallback labels, loading text, confirm title/buttons, unknown-area fallback, and operation error messaging.
  - Completed Task 7.2a.11 verification: locale key coverage expanded across en/es/pt/ja/zh_CN and audited files no longer ship hardcoded user-facing runtime labels.
  - Added new unit localization regression suites:
    - `tests/unit/ui/test_gamepad_settings_overlay_localization.gd`
    - `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
    - `tests/unit/ui/test_edit_touch_controls_overlay_localization.gd`
    - `tests/unit/ui/test_save_load_menu_localization.gd`
  - Cleared scene-authored static label defaults in:
    - `scenes/ui/overlays/ui_gamepad_settings_overlay.tscn`
    - `scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn`
    - `scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn`
    - `scenes/ui/overlays/ui_save_load_menu.tscn`
  - Verified `tests/unit/ui` (new localization suites + touched existing suites), `tests/integration/localization`, and `tests/unit/style` all pass.
- 2026-02-17: Completed Task 7.2a.3 (VFX settings overlay localization):
  - Localized `UI_VFXSettingsOverlay` title, row labels, action buttons, and control tooltips via `settings.vfx.*` + `common.*` keys.
  - Added live locale relabeling in `UI_VFXSettingsOverlay` (`_on_locale_changed`) for labels and tooltips.
  - Removed hardcoded user-facing text defaults from `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn` so runtime localization owns display strings.
  - Added/expanded `settings.vfx.*` keys in `resources/localization/cfg_locale_*_ui.tres` for en/es/pt/ja/zh_CN.
  - Added `tests/unit/ui/test_vfx_settings_overlay_localization.gd` for initial localization + live locale switch relabel assertions.
  - Verified `tests/unit/ui/test_vfx_settings_overlay_localization.gd`, `tests/integration/vfx/test_vfx_settings_ui.gd`, `tests/integration/localization`, and `tests/unit/style/test_style_enforcement.gd` all pass.
- 2026-02-17: Completed Task 7.2a.2 (Audio settings tab localization):
  - Localized `UI_AudioSettingsTab` heading, row labels, mute labels, button labels, and slider/toggle tooltips via `settings.audio.*` + `common.*` keys.
  - Added live locale relabeling in `UI_AudioSettingsTab` (`_on_locale_changed`) for labels and tooltips.
  - Removed hardcoded user-facing text defaults from `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn` so runtime localization owns display strings.
  - Added/expanded `settings.audio.*` keys in `resources/localization/cfg_locale_*_ui.tres` for en/es/pt/ja/zh_CN.
  - Added `tests/unit/ui/test_audio_settings_tab_localization.gd` for initial localization + live locale switch relabel assertions.
  - Verified `tests/unit/ui/test_audio_settings_tab_localization.gd`, `tests/integration/audio/test_audio_settings_ui.gd`, `tests/integration/localization`, and `tests/unit/style/test_style_enforcement.gd` all pass.
- 2026-02-17: Completed Task 7.2a.1 (Display settings tab localization + localized display option catalog):
  - Localized `UI_DisplaySettingsTab` heading/section labels, row labels, toggle labels, action buttons, tooltips, and display-change confirm dialog text/buttons via `settings.display.*` keys.
  - Added live locale relabeling (`_on_locale_changed`) for display settings UI, including option dropdown relabel while preserving selected values.
  - Updated `U_DisplayOptionCatalog` option entries to expose/use localization keys (`label_key`) and localize option labels (window mode/color blind/post-processing/quality presets).
  - Added/expanded `settings.display.*` locale keys in `cfg_locale_*_ui.tres` for en/es/pt/ja/zh_CN.
  - Added/updated tests:
    - `tests/unit/ui/test_display_settings_tab_localization.gd` (live relabeling coverage)
    - `tests/unit/utils/test_display_option_catalog.gd` (localization key presence + localized label resolution)
  - Verified `tests/unit/utils/test_display_option_catalog.gd`, `tests/unit/ui` display suites, `tests/integration/display/test_display_settings.gd`, localization integration suite, and style enforcement all pass.
- 2026-02-17: Completed Task 7.2a.7 (Input rebinding overlay + helper localization):
  - Localized `UI_InputRebindingOverlay` title/search/buttons/dialog labels/status text via `overlay.input_rebinding.*` keys and added live locale relabel support for capture-state status updates.
  - Localized `U_RebindActionListBuilder` category/action/button/tooltip/unbound text through localization keys and `input.action.*` display key lookups.
  - Localized `U_RebindCaptureHandler` capture prompt/cancel/success/conflict/error flows and added localized validation-error mapping for rebind guardrails.
  - Added expanded key coverage to `resources/localization/cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN), including rebinding overlay/status/error keys and missing action-label keys used by rebinding categories.
  - Removed hardcoded rebinding overlay scene text defaults from `scenes/ui/overlays/ui_input_rebinding_overlay.tscn` so runtime localization fully owns labels.
  - Verified `tests/unit/ui/test_input_rebinding_overlay.gd`, `tests/integration/localization`, and `tests/unit/style/test_style_enforcement.gd` all pass.
- 2026-02-17: Completed Task 7.2a.6 (Input profile selector localization):
  - Localized overlay heading/profile/reset/apply/cancel labels in `UI_InputProfileSelector` via `overlay.input_profile_selector.*` + `common.*` keys.
  - Added matching locale keys across `cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN).
  - Added regression assertions in `tests/unit/integration/test_input_profile_selector_overlay.gd` for default localized labels and live relabeling on locale switch.
  - Verified selector integration, localization integration, and style suites pass.
- 2026-02-17: Completed Task 7.3 UX parity validation for localization settings overlay:
  - Expanded `tests/integration/localization/test_localization_settings_tab.gd` with cancel/reset/state-sync coverage.
  - Added explicit locale confirm cancel-path regression and kept timer-revert coverage.
  - Re-ran full localization integration suite; all tests pass.
- 2026-02-17: Closed additional Phase 7 localization gaps + added Task 7.4 regression coverage:
  - Localized locale display labels in `UI_LocalizationSettingsTab` via shared `locale.name.*` keys across all locale catalogs.
  - Localized `UI_LanguageSelector` title + locale button labels and added live relabeling on locale changes.
  - Localized HUD autosave spinner text in `UI_HudController` (`hud.autosave_saving`) and removed dead hardcoded prompt-formatting helpers.
  - Removed hardcoded loading/localization/language selector fallback label text from `.tscn` files where runtime localization already owns labels.
  - Added `tests/integration/localization/test_localization_settings_tab.gd` covering preview-only edits, apply flow, confirm-keep flow, and timer-based locale revert.
  - Verified style enforcement + localization integration suites (including new regression tests) pass.
- 2026-02-17: Completed Phase 6 (UI scale ownership refactor):
  - Removed cross-manager display dispatch side effects from `M_LocalizationManager`.
  - Updated `M_DisplayManager` to compute effective `ui_scale` from display `ui_scale` and localization `ui_scale_override`.
  - Added no-loop + ownership tests in `tests/unit/managers/test_display_manager.gd`.
  - Updated integration coverage in `tests/integration/localization/test_locale_switching.gd` to verify CJK locale scaling applies through `M_DisplayManager` without `display/*` dispatches.
  - Verified display/localization regression and style suites all pass.
- 2026-02-17: Completed Phase 5 (preview controller extraction + manager slim-down):
  - Added `scripts/managers/helpers/localization/u_localization_preview_controller.gd` with:
    - preview lifecycle (`start_preview`, `clear_preview`, `is_preview_active`)
    - store-update gating (`should_ignore_store_updates`)
    - preview value resolution (`locale`, `dyslexia_font_enabled`, `ui_scale_override`)
  - Updated `M_LocalizationManager` to delegate preview state and effective preview values to the helper.
  - Added helper tests: `tests/unit/managers/helpers/localization/test_localization_preview_controller.gd`.
  - Verified `_await_store_ready_soft()` behavior remains unchanged and localization regression/style suites all pass.
- 2026-02-17: Completed Phase 4 (UI root registry extraction):
  - Added `scripts/managers/helpers/localization/u_localization_root_registry.gd` with:
    - duplicate-safe registration and unregister APIs
    - dead-node pruning
    - locale-change notifications (`_on_locale_changed`)
  - Updated `M_LocalizationManager` to route root registration/unregistration and locale notifications through the registry helper.
  - Added helper tests: `tests/unit/managers/helpers/localization/test_localization_root_registry.gd`.
  - Verified `U_LocalizationRoot` tests and full localization regression/style suites all pass.
- 2026-02-17: Completed Phase 3 (font/theme applier extraction):
  - Added `scripts/managers/helpers/localization/u_localization_font_applier.gd` with:
    - locale-aware font resolution (CJK locale priority over dyslexia toggle)
    - `build_theme(locale, dyslexia_enabled) -> Theme`
    - `apply_theme_to_root(root, theme) -> void`
    - CJK fallback chaining for default/dyslexia fonts
  - Updated `M_LocalizationManager` to delegate font loading/theme application to the helper.
  - Added helper tests: `tests/unit/managers/helpers/localization/test_localization_font_applier.gd`.
  - Verified localization unit/integration + style suites all pass.
- 2026-02-17: Completed Phase 2 (translation catalog extraction):
  - Added `scripts/managers/helpers/localization/u_localization_catalog.gd` with:
    - locale support checks
    - fallback merge chain (`requested -> en`)
    - cached raw/effective catalog loading
    - cache invalidation (`clear_cache`, `force_refresh`)
  - Updated `M_LocalizationManager` to consume `U_LocalizationCatalog` directly.
  - Converted `U_LocaleFileLoader` into a compatibility shim backed by the new helper.
  - Added focused helper tests: `tests/unit/managers/helpers/localization/test_localization_catalog.gd`.
  - Verified localization unit/integration + style suites all pass.
- 2026-02-16: Closed several Task 7.2a gaps:
  - Localized HUD prompt fallbacks (`ui_button_prompt.gd`, `ui_virtual_button.gd`).
  - Localized input profile action labels and profile name/description via keys (updated `cfg_*.tres` profiles + selector UI).
  - Localized save/load timestamp tokens (month names + AM/PM) and added `date.*` keys.
  - Added `LocalizationRoot` to settings tab scenes (display/audio/localization).
  - Updated `test_locale_file_loader.gd` to validate `.tres` merge behavior.
- 2026-02-16: Completed Phase 0 contract freeze (architecture decisions, public API contract, migration notes, plan summary).
- 2026-02-16: Completed Phase 1 (interface/tests):
  - Added interface contract tests for supported locales, effective settings, preview state, locale change signal.
  - Updated `I_LocalizationManager` with new API + signal and implemented in `M_LocalizationManager`.
  - Updated localization mock in tests to conform.

## Phase Plan Summary

- **Phase 0**: Lock architecture contract (responsibilities, fallback, preview, UI scale ownership).
- **Phase 1**: Interface tests + update `I_LocalizationManager` contract.
- **Phase 2**: Extract catalog loader with unit tests.
- **Phase 3**: Extract font/theme applier with unit tests.
- **Phase 4**: Extract root registry with unit tests.
- **Phase 5**: Extract preview controller; slim manager.
- **Phase 6**: Move UI scale ownership to display manager; update tests.
- **Phase 7**: UI integration cleanup + translation coverage audit.
- **Phase 8**: Test hardening and helper-focused coverage.
- **Phase 9**: Final documentation sync and completion.

## Audit Findings Summary (See Task 7.2a for Full List)

- Phase 7 translation audit findings are fully resolved.
- Input profile `.tres` resources store display strings instead of localization keys. (resolved 2026-02-16)
- Save/load date formatting uses hardcoded month names and AM/PM tokens. (resolved 2026-02-16)
- Some settings tab scenes appear to be missing `LocalizationRoot`, so live locale updates are not applied. (resolved 2026-02-16)
- Remaining intentional non-localized strings in audited files are debug/developer logs and defensive fallback literals used only when a localization key is missing.

## Immediate Next Steps

1. Begin Phase 9 Task 9.1/9.2: synchronize `localization-manager-overview.md` and `localization-manager-plan.md` with finalized helper architecture and Phase 8 test-hardening outcomes.
2. Complete Phase 9 Task 9.3/9.4: finalize continuation prompt + tasks summary for refactor completion handoff.
3. Complete Phase 9 Task 9.5/9.6 updates (`AGENTS.md`, `DEV_PITFALLS.md`) if additional reusable patterns/pitfalls emerge during final doc pass.

## Key Pitfalls

- `localization_initial_state` is the 13th parameter to `initialize_slices()` in `M_StateStore`.
- Locale resources use `const` preload arrays in `U_LocalizationCatalog` (mobile-safe); do not revert to JSON file IO.
- Theme-based font cascade now lives in `U_LocalizationFontApplier`; keep `FONT_THEME_TYPES` aligned with supported `Theme` control types (includes `&"Control"`).
- Root lifecycle (register/unregister/prune/notify) now lives in `U_LocalizationRootRegistry`; manager should not mutate root arrays directly.
- Preview state now lives in `U_LocalizationPreviewController`; while preview is active, manager must ignore `slice_updated` localization events.
- Effective UI scale ownership is now in `M_DisplayManager`; localization manager must never dispatch `display/*` actions.
- Locale labels shared across settings + selector UI now resolve through `locale.name.*` keys in `cfg_locale_*_ui.tres`; avoid hardcoded locale display strings in UI scripts/scenes.
- `preload()` on `.ttf` does not work; use `load()` and guard for null.
- Do not use `tr()` or `Object.tr()`; use `U_LocalizationUtils.localize()` / `localize_fmt()`.
- Use `str(value)` for Variant-to-string conversion.
- Inner class names must start with a capital letter (GDScript 4 parser).
- Settings tab scenes live in `scenes/ui/overlays/settings/` and require overlay wrappers + registry entries.
