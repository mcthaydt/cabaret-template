# Localization Manager - Continuation Prompt

**Last Updated:** 2026-02-14
**Status:** Planning complete. Zero tasks implemented.

## Start Here

Read these before writing any code:
- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/localization_manager/localization-manager-plan.md`
- `docs/localization_manager/localization-manager-tasks.md`

Begin at **Task 0A.1 (Red)** — write tests for `RS_LocalizationInitialState`.

## Key Pitfalls

- `localization_initial_state` is the **13th parameter** to `initialize_slices()` — misaligning it silently breaks all existing slices
- `u_global_settings_serialization.gd` requires 4 method edits AND `u_global_settings_applier.gd` requires a new `_apply_localization()` — both are needed for save/load round-trip
- `preload()` on `.json` is a compile error — use `FileAccess.open()` with hardcoded paths
- `preload()` on `.ttf` does not work — use `load()` and guard with `if font == null: return`
- Never call bare `tr(key)` — always `U_LocalizationUtils.tr(key)` to avoid Godot's built-in `Object.tr()`
- Settings tab scenes live under `scenes/ui/overlays/settings/` (Phase 5 requires an overlay wrapper, UIScreenDefinition, SceneRegistryEntry, UIRegistry registration, and settings menu button — not just a tab scene)
- After Phase 0.5C changes `initial_scene_id` to `"language_selector"`, run the full regression suite immediately
