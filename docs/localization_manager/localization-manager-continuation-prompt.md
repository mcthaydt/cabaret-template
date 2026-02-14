# Localization Manager - Continuation Prompt

**Last Updated:** 2026-02-14
**Status:** Phases 0, 0.5, 1, 2, 3 complete. 28 / 45 tasks done.

## Completed Phases

- **Phase 0**: Redux Foundation — RS_LocalizationInitialState, U_LocalizationActions (4 actions including `mark_language_selected`), U_LocalizationReducer, U_LocalizationSelectors (4 selectors), slice registered in M_StateStore as 13th param, `localization/` prefix wired into U_GlobalSettingsSerialization and U_GlobalSettingsApplier, `cfg_localization_initial_state.tres` assigned in `scenes/root.tscn`.
- **Phase 0.5**: First-Run Language Selector — `has_selected_language` field added to RS_LocalizationInitialState + reducer + selectors, `UI_LanguageSelector` scene + controller created, `language_selector` registered in U_SceneRegistry (preload priority 10), `M_SceneManager.initial_scene_id` changed to `"language_selector"` in `scenes/root.tscn`.
- **Phase 1**: Interface & Core Manager — `I_LocalizationManager` interface created, `M_LocalizationManager` scaffold with hash-based dedup, store subscription, `_initialize_store_async()` pattern, node added to `root.tscn` + registered in `root.gd`. 12 unit tests.
- **Phase 2**: JSON File Loading & Locale Switching — `U_LocaleFileLoader` (FileAccess-based JSON merger), locale JSON stubs (en/es/pt/zh_CN/ja, ui.json + hud.json), `U_LocalizationUtils` with `localize()` / `localize_fmt()` helpers. 10 unit tests.
- **Phase 3**: Dyslexia Font System — `_load_fonts()`, `register_ui_root()`, `_apply_font_override()`, `_get_active_font()`, `_apply_font_to_root()`. CJK priority logic. Font file stubs in `assets/fonts/`. 6 additional unit tests.

## Start Here

Read these before writing any code:
- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/localization_manager/localization-manager-plan.md`
- `docs/localization_manager/localization-manager-tasks.md`

Begin at **Task 4A.1** — write signpost localization tests, then **Task 4A.2** — update `scripts/ui/hud/ui_hud_controller.gd`.

## Key Pitfalls

- `localization_initial_state` is the **13th parameter** to `initialize_slices()` — misaligning it silently breaks all existing slices
- `u_global_settings_serialization.gd` requires 4 method edits AND `u_global_settings_applier.gd` requires a new `_apply_localization()` — both are needed for save/load round-trip
- `preload()` on `.json` is a compile error — use `FileAccess.open()` with hardcoded paths
- `preload()` on `.ttf` does not work — use `load()` and guard with `if font == null: return`
- **`tr()` CANNOT be a static method name in Godot 4.6** — Godot's parser refuses to resolve `.tr()` as an external class member (collides with `Object.tr()` built-in). `U_LocalizationUtils` uses `localize()` / `localize_fmt()` instead. Never call bare `tr(key)`.
- **`String(value)` does not work for Variant→String** — use `str(value)` for arbitrary Variants in arg substitution
- **Inner class names must start with a capital letter** — `_MockFoo` causes a GDScript 4 parse error; use `MockFoo`
- Settings tab scenes live under `scenes/ui/overlays/settings/` (Phase 5 requires an overlay wrapper, UIScreenDefinition, SceneRegistryEntry, UIRegistry registration, and settings menu button — not just a tab scene)
- After Phase 0.5C changes `initial_scene_id` to `"language_selector"`, run the full regression suite immediately
- Font stubs in `assets/fonts/` are placeholder copies of GUT fonts — replace with real fonts before shipping
