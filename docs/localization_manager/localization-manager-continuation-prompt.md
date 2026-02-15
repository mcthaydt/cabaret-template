# Localization Manager - Continuation Prompt

**Last Updated:** 2026-02-15
**Status:** Phases 0–6 + 7.1–7.3, 7.5–7.6 complete. 44 / 46 tasks done.

## Completed Phases

- **Phase 0**: Redux Foundation — RS_LocalizationInitialState, U_LocalizationActions (4 actions including `mark_language_selected`), U_LocalizationReducer, U_LocalizationSelectors (4 selectors), slice registered in M_StateStore as 13th param, `localization/` prefix wired into U_GlobalSettingsSerialization and U_GlobalSettingsApplier, `cfg_localization_initial_state.tres` assigned in `scenes/root.tscn`.
- **Phase 0.5**: First-Run Language Selector — `has_selected_language` field added to RS_LocalizationInitialState + reducer + selectors, `UI_LanguageSelector` scene + controller created, `language_selector` registered in U_SceneRegistry (preload priority 10), `M_SceneManager.initial_scene_id` changed to `"language_selector"` in `scenes/root.tscn`.
- **Phase 1**: Interface & Core Manager — `I_LocalizationManager` interface created, `M_LocalizationManager` scaffold with hash-based dedup, store subscription, `_initialize_store_async()` pattern, node added to `root.tscn` + registered in `root.gd`. 12 unit tests.
- **Phase 2**: JSON File Loading & Locale Switching — `U_LocaleFileLoader` (FileAccess-based JSON merger), locale JSON stubs (en/es/pt/zh_CN/ja, ui.json + hud.json), `U_LocalizationUtils` with `localize()` / `localize_fmt()` helpers. 10 unit tests.
- **Phase 3**: Dyslexia Font System — `_load_fonts()`, `register_ui_root()`, `_apply_font_override()`, `_get_active_font()`, `_apply_font_to_root()`. CJK priority logic. Font file stubs in `assets/fonts/`. 6 additional unit tests.
- **Phase 4**: Signpost Localization Integration — `ui_hud_controller.gd` wraps signpost `message` through `U_LocalizationUtils.localize(StringName(raw))` before display; `localization` slice added to `_on_slice_updated()` filter. 2 unit tests in `test_hud_interactions_pause_and_signpost.gd`.
- **Phase 5**: Settings UI Integration — `UI_LocalizationSettingsTab` (language OptionButton + dyslexia CheckButton, auto-save), `UI_LocalizationSettingsOverlay` (BaseOverlay wrapper), `cfg_localization_settings_overlay.tres` (UIScreenDefinition), `cfg_ui_localization_settings_entry.tres` (SceneRegistryEntry), `U_UIRegistry` updated (12 overlays), "Language" button wired in `ui_settings_menu.tscn/.gd`. `test_ui_registry.gd` updated (expected count 11→12).
- **Phase 6**: Integration Tests — `test_locale_switching.gd` (4), `test_font_override.gd` (3), `test_localization_persistence.gd` (3). 10/10 pass. Key pitfall: dispatch needs `await physics_frame` before asserting manager state (store emits `slice_updated` once per physics frame).
- **Phase 7.1**: Infrastructure Fixes — Converted locale JSON files to mobile-safe `.tres` resources (`RS_LocaleTranslations`), rewrote `U_LocaleFileLoader` with `const` preload arrays, rewrote `M_LocalizationManager` with Theme-based font cascade (`_build_font_theme()` + `_FONT_THEME_TYPES`), added `_apply_ui_scale_override()` dispatching `U_DisplayActions.set_ui_scale()`, added preview mode (`set_localization_preview()` / `clear_localization_preview()`). Updated `I_LocalizationManager` with preview stubs.
- **Phase 7.2**: UI Root Registration — Created `U_LocalizationRoot` helper (mirrors `U_UIScaleRoot` retry-polling pattern), added `LocalizationRoot` node to all 20 `.tscn` files that have `UIScaleRoot`, added `_on_locale_changed()` callback to `UI_LocalizationSettingsTab`.
- **Phase 7.3**: Settings UI Overhaul — Full rewrite of `UI_LocalizationSettingsTab` with Apply/Cancel/Reset pattern, language confirm dialog with 10s revert timer, state subscription with `_unsubscribe` cleanup, focus configuration via `U_FocusConfigurator`, preview mode integration. Updated `.tscn` with Spacer, ButtonRow, LanguageConfirmDialog, LanguageConfirmTimer.
- **Phase 7.5**: Documentation — Updated AGENTS.md services list, updated task tracker progress.
- **Phase 7.6**: Testing — `tests/unit/ui/test_localization_root.gd` written (3 tests: registers parent with manager after retry-poll, unregisters on exit_tree, no crash without manager). File is currently untracked; needs staging.

## Start Here

Read these before writing any code:
- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/localization_manager/localization-manager-plan.md`
- `docs/localization_manager/localization-manager-tasks.md`

Phases 0–6 and 7.1–7.3, 7.5–7.6 are complete (44/46 tasks). Remaining work:
- **Phase 7.4** (7A.3, 7C.1–7C.4): Wire `U_LocalizationUtils.localize()` calls to UI controllers
  and populate `.tres` translation resources with actual keys (7A.3, 7C.4 — in scope, not
  started). Replace font stubs with real fonts (7C.1–7C.3 — blocked on user-provided assets).

## Key Pitfalls

- `localization_initial_state` is the **13th parameter** to `initialize_slices()` — misaligning it silently breaks all existing slices
- `u_global_settings_serialization.gd` requires 4 method edits AND `u_global_settings_applier.gd` requires a new `_apply_localization()` — both are needed for save/load round-trip
- **Locale resources use `const` preload arrays** — `U_LocaleFileLoader` uses `const _LOCALE_RESOURCES: Array` with preloaded `.tres` files (mobile-safe, replaces old JSON approach)
- **Theme-based font cascade** — `M_LocalizationManager` builds a `Theme` resource and assigns it to root Control's `.theme` property; `_FONT_THEME_TYPES` includes `&"Control"` for plain Control nodes
- `preload()` on `.ttf` does not work — use `load()` and guard with `if font == null: return`
- **`tr()` CANNOT be a static method name in Godot 4.6** — Godot's parser refuses to resolve `.tr()` as an external class member (collides with `Object.tr()` built-in). `U_LocalizationUtils` uses `localize()` / `localize_fmt()` helpers. Never call bare `tr(key)`.
- **`String(value)` does not work for Variant→String** — use `str(value)` for arbitrary Variants in arg substitution
- **Inner class names must start with a capital letter** — `_MockFoo` causes a GDScript 4 parse error; use `MockFoo`
- Settings tab scenes live under `scenes/ui/overlays/settings/` (Phase 5 requires an overlay wrapper, UIScreenDefinition, SceneRegistryEntry, UIRegistry registration, and settings menu button — not just a tab scene)
- After Phase 0.5C changes `initial_scene_id` to `"language_selector"`, run the full regression suite immediately
- Font stubs in `assets/fonts/` are placeholder copies of GUT fonts — replace with real fonts before shipping
