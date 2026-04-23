# Localization Manager Refactor Tasks

**Created:** 2026-02-15  
**Status:** Complete  
**Progress:** 100% (69 / 69 tasks complete)

## Goal

Refactor localization to match manager quality standards used by display/audio: clear module boundaries, minimal manager orchestration, explicit contracts, and high-confidence tests.

## Scope

- In scope:
  - `M_LocalizationManager` architecture cleanup.
  - Helper extraction for catalog loading, font/theme application, root registration, preview state.
  - Cross-manager policy for localization-driven UI scale behavior.
  - Updated interfaces, tests, and docs.
- Out of scope:
  - Adding new locales.
  - Changing translation content.
  - Reworking gameplay/UI strings beyond integration touchpoints required by refactor.

## Quality Bar

- Keep `M_LocalizationManager` focused on orchestration only.
- No hidden cross-slice side effects without explicit policy docs and tests.
- New helper modules must have direct unit tests.
- Integration tests must prove end-to-end locale switching, preview, persistence, and font application still work.

## Pre-Flight Checklist

- [x] Re-read `docs/general/DEV_PITFALLS.md`. (2026-02-16)
- [x] Re-read `docs/general/STYLE_GUIDE.md`. (2026-02-16)
- [x] Capture baseline status: (re-verified 2026-02-17)
  - [x] `tests/unit/managers/test_localization_manager.gd`
  - [x] `tests/unit/managers/helpers/test_locale_file_loader.gd`
  - [x] `tests/unit/utils/test_localization_utils.gd`
  - [x] `tests/unit/ui/test_localization_root.gd`
  - [x] `tests/integration/localization/test_locale_switching.gd`
  - [x] `tests/integration/localization/test_font_override.gd`
  - [x] `tests/integration/localization/test_localization_persistence.gd`

---

## Phase 0: Architecture Contract Freeze

**Exit Criteria:** Refactor target contract is explicit before moving code.

- [x] **Task 0.1**: Add an architecture decision section to `docs/localization_manager/localization-manager-overview.md`. (done 2026-02-16)
  - [x] Manager responsibilities vs helper responsibilities.
  - [x] Translation fallback policy.
  - [x] Locale preview behavior contract.
  - [x] UI scale ownership contract (Localization vs Display).
- [x] **Task 0.2**: Define final public API for `I_LocalizationManager`. (documented in overview; done 2026-02-16)
- [x] **Task 0.3**: Add a migration note listing current call sites that depend on existing behavior. (done 2026-02-16)
- [x] **Task 0.4**: Add phase plan summary to `docs/localization_manager/localization-manager-continuation-prompt.md`. (done 2026-02-16)

---

## Phase 1: Interface and Contracts

**Exit Criteria:** Interface and core contracts are test-covered before implementation extraction.

- [x] **Task 1.1 (Red)**: Extend interface tests in `tests/unit/managers/test_localization_manager.gd`. (done 2026-02-16)
  - [x] supported locales contract
  - [x] effective settings contract
  - [x] preview state contract
  - [x] locale change notification contract
- [x] **Task 1.2 (Green)**: Update `scripts/interfaces/i_localization_manager.gd`. (done 2026-02-16)
  - [x] add `get_supported_locales() -> Array[StringName]`
  - [x] add `get_effective_settings() -> Dictionary`
  - [x] add `is_preview_active() -> bool`
  - [x] add signal stub docs for locale changes
- [x] **Task 1.3**: Update mock localization managers in tests to conform to interface changes. (done 2026-02-16)
- [x] **Task 1.4**: Confirm all existing localization tests still pass after interface evolution. (done 2026-02-16)

---

## Phase 2: Translation Catalog Extraction

**Exit Criteria:** Catalog loading/caching/fallback is independent and unit-tested.

- [x] **Task 2.1 (Red)**: Create focused tests for catalog behavior. (done 2026-02-17 in `tests/unit/managers/helpers/localization/test_localization_catalog.gd`)
  - [x] merges domain resources for locale
  - [x] deterministic overwrite behavior for duplicate keys
  - [x] fallback chain behavior (`requested -> fallback locale -> key`)
  - [x] unsupported locale behavior
- [x] **Task 2.2 (Green)**: Create `scripts/managers/helpers/localization/u_localization_catalog.gd`. (done 2026-02-17)
- [x] **Task 2.3**: Move/reshape logic from `u_locale_file_loader.gd` into catalog helper. (done 2026-02-17)
- [x] **Task 2.4**: Keep `u_locale_file_loader.gd` as compatibility shim or remove with call-site updates. (shim retained; done 2026-02-17)
- [x] **Task 2.5**: Add cache invalidation strategy in helper (if resources are reloaded). (`clear_cache()` + `force_refresh`; done 2026-02-17)
- [x] **Task 2.6**: Ensure helper API is typed and side-effect-free. (done 2026-02-17)
- [x] **Task 2.7**: Update manager to consume catalog helper only. (`M_LocalizationManager` now uses `U_LocalizationCatalog`; done 2026-02-17)

---

## Phase 3: Font and Theme Application Extraction

**Exit Criteria:** Font selection and theme application are isolated from manager orchestration.

- [x] **Task 3.1 (Red)**: Add helper unit tests for: (done 2026-02-17 in `tests/unit/managers/helpers/localization/test_localization_font_applier.gd`)
  - [x] locale-to-font resolution (`CJK` priority over dyslexia toggle)
  - [x] theme construction contains expected control types
  - [x] no-op behavior when fonts are missing
- [x] **Task 3.2 (Green)**: Create `scripts/managers/helpers/localization/u_localization_font_applier.gd`. (done 2026-02-17)
- [x] **Task 3.3**: Move `_get_active_font`, `_build_font_theme`, `_apply_font_to_root` logic into helper. (done 2026-02-17)
- [x] **Task 3.4**: Add clear runtime API: (done 2026-02-17)
  - [x] `build_theme(locale, dyslexia_enabled) -> Theme`
  - [x] `apply_theme_to_root(root, theme) -> void`
- [x] **Task 3.5**: Ensure manager only requests/apply theme; no font details inline. (done 2026-02-17)

---

## Phase 4: UI Root Registry Extraction

**Exit Criteria:** Root lifecycle management is centralized and leak-resistant.

- [x] **Task 4.1 (Red)**: Add registry tests: (done 2026-02-17 in `tests/unit/managers/helpers/localization/test_localization_root_registry.gd`)
  - [x] register once / no duplicates
  - [x] unregister behavior
  - [x] dead-node pruning
  - [x] locale change notifications (`_on_locale_changed`)
- [x] **Task 4.2 (Green)**: Create `scripts/managers/helpers/localization/u_localization_root_registry.gd`. (done 2026-02-17)
- [x] **Task 4.3**: Move `_ui_roots` list operations from manager to registry helper. (done 2026-02-17)
- [x] **Task 4.4**: Route `register_ui_root` / `unregister_ui_root` through registry helper. (done 2026-02-17)
- [x] **Task 4.5**: Update `scripts/ui/helpers/u_localization_root.gd` tests if lifecycle behavior changes. (existing tests pass without behavior changes; verified 2026-02-17)

---

## Phase 5: Preview State Extraction and Manager Slim-Down

**Exit Criteria:** Manager uses composition; preview flow is explicit and testable.

- [x] **Task 5.1 (Red)**: Add preview controller tests: (done 2026-02-17 in `tests/unit/managers/helpers/localization/test_localization_preview_controller.gd`)
  - [x] start preview applies temporary effective settings
  - [x] clear preview restores store-driven state
  - [x] store updates ignored while preview active
- [x] **Task 5.2 (Green)**: Create `scripts/managers/helpers/localization/u_localization_preview_controller.gd`. (done 2026-02-17)
- [x] **Task 5.3**: Move preview flags/state from manager into controller helper. (done 2026-02-17)
- [x] **Task 5.4**: Refactor `M_LocalizationManager` to orchestration-only flow: (done 2026-02-17)
  - [x] load state
  - [x] build effective settings
  - [x] delegate translation, font, and root operations
- [x] **Task 5.5**: Keep `_await_store_ready_soft()` behavior unchanged unless tests are updated first. (verified unchanged behavior on 2026-02-17)

---

## Phase 6: UI Scale Ownership Refactor

**Exit Criteria:** UI scale behavior is explicit, deterministic, and owned by the correct manager.

- [x] **Task 6.1**: Decide ownership policy: (done 2026-02-17)
  - [x] Option A (I choose this): `M_DisplayManager` computes effective UI scale using display + localization slices.
- [x] **Task 6.2 (Red)**: Add tests proving selected policy, including no dispatch loops. (done 2026-02-17 in `tests/unit/managers/test_display_manager.gd`)
- [x] **Task 6.3 (Green)**: Remove hidden cross-manager dispatch from `M_LocalizationManager`. (done 2026-02-17)
- [x] **Task 6.4**: Implement selected policy in owner module. (`M_DisplayManager` now reacts to localization slice updates and computes effective ui_scale; done 2026-02-17)
- [x] **Task 6.5**: Update integration tests for locale-driven CJK scale behavior accordingly. (`tests/integration/localization/test_locale_switching.gd`; done 2026-02-17)

---

## Phase 7: Utilities and UI Integration Cleanup

**Exit Criteria:** Utility and UI callers consume the refactored contract without regressions.

- [x] **Task 7.1**: Update `scripts/utils/localization/u_localization_utils.gd` if manager API changes. (no API call-site changes required after helper extraction; verified 2026-02-17)
- [x] **Task 7.2**: Audit and update all direct localization manager usage in UI controllers. (audited Phase 7 target UI controllers; runtime localization now owns static UI copy and locale-change relabel paths are covered by unit tests; done 2026-02-17)
- [x] **Task 7.2a**: Audit translation coverage across UI and helper labels: (completed 2026-02-17)
  - [x] ensure all user-facing strings route through localization keys (including tooltips, prompts, and dialogs)
  - [x] update locale resources for corrected/added strings
  - [x] document intentional non-localized strings (debug-only or developer-facing)
  - [x] **Task 7.2a.1**: Localize Display settings UI (`scripts/ui/settings/ui_display_settings_tab.gd`) and add live locale updates: (localized section headers/labels/tooltips/dialog/buttons + live locale relabeling in tab; catalog option entries now include localization keys and localized labels; expanded locale keys across en/es/pt/ja/zh_CN; added unit localization coverage in `tests/unit/ui/test_display_settings_tab_localization.gd` and catalog localization key coverage in `tests/unit/utils/test_display_option_catalog.gd`; done 2026-02-17)
    - [x] add localization keys for section headers, labels, tooltips, dialog text, and option labels
    - [x] update `scripts/utils/display/u_display_option_catalog.gd` to provide localization keys for option entries and quality presets
    - [x] add `LocalizationRoot` to `scenes/ui/overlays/settings/ui_display_settings_tab.tscn` (done 2026-02-16)
  - [x] **Task 7.2a.2**: Localize Audio settings UI (`scripts/ui/settings/ui_audio_settings_tab.gd`) and add live locale updates: (localized heading/row labels/mute labels/buttons/tooltips + live locale relabeling in tab; removed hardcoded scene label/button text defaults so runtime localization owns UI copy; added `settings.audio.*` keys across en/es/pt/ja/zh_CN; added `tests/unit/ui/test_audio_settings_tab_localization.gd`; verified unit audio localization, `tests/integration/audio/test_audio_settings_ui.gd`, localization integration, and style suites; done 2026-02-17)
    - [x] add localization keys for headers, labels, tooltips, and buttons
    - [x] add `LocalizationRoot` to `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn` (done 2026-02-16)
  - Note: `LocalizationRoot` also added to `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` (2026-02-16) to enable live locale updates.
  - [x] **Task 7.2a.3**: Localize VFX settings UI (`scripts/ui/settings/ui_vfx_settings_overlay.gd`): (localized title/row labels/action buttons/tooltips + live locale relabeling via `_on_locale_changed`; removed hardcoded VFX scene label/button defaults so runtime localization owns UI copy; added `settings.vfx.*` keys across en/es/pt/ja/zh_CN; added `tests/unit/ui/test_vfx_settings_overlay_localization.gd`; verified VFX localization unit, `tests/integration/vfx/test_vfx_settings_ui.gd`, localization integration, and style suites; done 2026-02-17)
    - [x] add localization keys for headers, labels, tooltips, and buttons
  - [x] **Task 7.2a.4**: Localize Gamepad settings overlay (`scripts/ui/overlays/ui_gamepad_settings_overlay.gd`): (localized title/labels/tooltips/preview prompts + live locale relabeling; removed scene-authored static label defaults; added `settings.gamepad.*` keys across en/es/pt/ja/zh_CN and `tests/unit/ui/test_gamepad_settings_overlay_localization.gd`; done 2026-02-17)
    - [x] add localization keys for titles, labels, tooltips, and preview instructions
  - [x] **Task 7.2a.5**: Localize Touchscreen settings overlays: (localized touchscreen + edit-touch overlays title/labels/tooltips/button copy + live locale relabeling; removed scene-authored static label defaults; added `settings.touchscreen.*` + `overlay.edit_touch_controls.*` keys across en/es/pt/ja/zh_CN and unit localization coverage in `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd` + `tests/unit/ui/test_edit_touch_controls_overlay_localization.gd`; done 2026-02-17)
    - [x] `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd` titles/labels/tooltips/preview instructions
    - [x] `scripts/ui/overlays/ui_edit_touch_controls_overlay.gd` buttons/labels/preview text
  - [x] **Task 7.2a.6**: Localize Input profile selector (`scripts/ui/overlays/ui_input_profile_selector.gd`) and profile resources: (overlay labels + action labels localized and regression-covered in `tests/unit/integration/test_input_profile_selector_overlay.gd`; done 2026-02-17)
    - [x] add localization keys for overlay text and action group labels (action group labels done 2026-02-16; overlay labels completed 2026-02-17)
    - [x] update `resources/input/profiles/cfg_*.tres` to use localization keys for `profile_name` and `description` (done 2026-02-16)
    - [x] ensure UI resolves profile name/description via localization keys (done 2026-02-16)
  - [x] **Task 7.2a.7**: Localize Input rebinding overlay and helpers: (localized overlay/dialog/status strings, builder action/category/button/tooltip labels, and capture/conflict/status messaging with new `overlay.input_rebinding.*` keys across en/es/pt/ja/zh_CN; updated overlay scene to runtime-localized labels only; verified via `tests/unit/ui/test_input_rebinding_overlay.gd`, `tests/integration/localization`, and style suite; done 2026-02-17)
    - [x] `scripts/ui/overlays/ui_input_rebinding_overlay.gd` dialog/status/tooltips
    - [x] `scripts/ui/helpers/u_rebind_action_list_builder.gd` action/category labels via localization keys
    - [x] `scripts/ui/helpers/u_rebind_capture_handler.gd` capture status strings
  - [x] **Task 7.2a.8**: Localize Save/Load menu (`scripts/ui/overlays/ui_save_load_menu.gd`): (localized autosave label, slot fallback labels, confirm dialog title/buttons, operation error messaging, loading label, and unknown-area fallback; removed scene-authored static label defaults; added `overlay.save_load.*` keys across en/es/pt/ja/zh_CN and `tests/unit/ui/test_save_load_menu_localization.gd`; done 2026-02-17)
    - [x] autosave label, slot labels, confirm dialog text, error messages, loading text
    - [x] localized date formatting (month names + AM/PM tokens) (done 2026-02-16)
  - [x] **Task 7.2a.9**: Localize HUD prompt labels: (all Phase 7 HUD prompt gaps closed; done 2026-02-17)
    - [x] `scripts/ui/hud/ui_button_prompt.gd` fallback “Interact” label (done 2026-02-16)
    - [x] `scripts/ui/hud/ui_virtual_button.gd` action labels (done 2026-02-16)
    - [x] `scripts/ui/hud/ui_hud_controller.gd` autosave spinner label and transient HUD labels (autosave spinner label now localized via `hud.autosave_saving`; done 2026-02-17)
  - [x] **Task 7.2a.10**: Localize loading and language selector UI: (all listed loading/language selector UI copy now localized; done 2026-02-17)
    - [x] `scripts/scene_management/transitions/trans_loading_screen.gd` loading title text (runtime label localization verified; hardcoded loading fallback text removed from `ui_loading_screen.tscn`; done 2026-02-17)
    - [x] `scripts/ui/menus/ui_language_selector.gd` header/title label (title + locale button labels localized with live locale refresh; done 2026-02-17)
  - [x] **Task 7.2a.11**: Add/verify localization keys across all locales: (verified 2026-02-17)
    - [x] update `resources/localization/cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN) for all added keys (input action/profile + date tokens added 2026-02-16; input rebinding overlay/action/category/status/error keys expanded 2026-02-17; audio/display/vfx settings keys expanded 2026-02-17)
    - [x] confirm no hardcoded user-facing strings remain in audited files
- [x] **Task 7.3**: Ensure settings overlay preview/apply/cancel behavior remains unchanged in UX. (expanded `tests/integration/localization/test_localization_settings_tab.gd` for cancel/reset/state-sync + confirm cancel/timer flows; done 2026-02-17)
- [x] **Task 7.4**: Add targeted regression tests for `UI_LocalizationSettingsTab` around preview + confirm timer flow. (added `tests/integration/localization/test_localization_settings_tab.gd`; done 2026-02-17)

### Audit Findings (2026-02-16)

The following translation coverage gaps were identified and should be addressed as part of Task 7.2a:

- `scripts/ui/settings/ui_display_settings_tab.gd`: hardcoded section headers, labels, button text, confirm dialog title/body, tooltip strings, and option labels (resolution, window mode, UI scale, vsync, etc.) should be localized. Also ensure option labels come from catalog rather than display catalog literals. (resolved 2026-02-17)
- `scripts/utils/display/u_display_option_catalog.gd`: display option entries and quality presets need localization keys (not hardcoded user-facing labels). (resolved 2026-02-17)
- `scripts/ui/settings/ui_audio_settings_tab.gd`: all labels, section headers, slider labels, button text, tooltips are hardcoded. (resolved 2026-02-17)
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`: all headers, slider labels, toggle labels, and button text are hardcoded. (resolved 2026-02-17)
- `scripts/ui/overlays/ui_gamepad_settings_overlay.gd`: overlay title/labels/tooltips and preview instructions are hardcoded. (resolved 2026-02-17)
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`: overlay title/labels/tooltips and preview instructions are hardcoded. (resolved 2026-02-17)
- `scripts/ui/overlays/ui_edit_touch_controls_overlay.gd`: buttons, labels, and preview text are hardcoded. (resolved 2026-02-17)
- `scripts/ui/overlays/ui_input_profile_selector.gd`: overlay labels, “default profiles” header, profile name/description fields, and action group labels should be localized. Profiles should source localized name/description via keys. (resolved 2026-02-17)
- `resources/input/profiles/cfg_*.tres`: `profile_name` and `description` should be localization keys, not display strings. (resolved 2026-02-16)
- `scripts/ui/overlays/ui_input_rebinding_overlay.gd`: all dialog text, tooltips, and status messages (including “press any key”, “already bound”, “reserved”, etc.) should be localized. (resolved 2026-02-17)
- `scripts/ui/helpers/u_rebind_action_list_builder.gd`: action and category labels should be fetched via localization keys. (resolved 2026-02-17)
- `scripts/ui/helpers/u_rebind_capture_handler.gd`: capture status strings should be localized. (resolved 2026-02-17)
- `scripts/ui/overlays/ui_save_load_menu.gd`: autosave label, slot labels, confirm dialog text, error messages, loading text, and date formatting should be localized (month names + AM/PM via keys). (resolved 2026-02-17)
- `scripts/ui/hud/ui_button_prompt.gd`: fallback “Interact” label should be localized. (resolved 2026-02-16)
- `scripts/ui/hud/ui_virtual_button.gd`: action labels should be localized. (resolved 2026-02-16)
- `scripts/ui/hud/ui_hud_controller.gd`: autosave spinner label and other transient HUD labels should be localized. (autosave spinner label resolved 2026-02-17)
- `scripts/scene_management/transitions/trans_loading_screen.gd`: loading title text should be localized. (resolved 2026-02-17)
- `scripts/ui/menus/ui_language_selector.gd`: header/title label should be localized. (resolved 2026-02-17)
- Scene roots: `scenes/ui/overlays/settings/ui_display_settings_tab.tscn`, `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn`, and `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` appear to lack a `LocalizationRoot` node, preventing live locale updates. (resolved 2026-02-16)
- Locale resources: add missing keys across `resources/localization/cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN) for all new/covered strings, including common labels, date tokens, and settings labels. (resolved 2026-02-17)

---

## Phase 8: Test Hardening

**Exit Criteria:** Tests validate behavior, not internals; helper coverage is strong.

- [x] **Task 8.1**: Replace brittle tests that inspect private manager internals where possible. (completed 2026-02-17 by migrating localization manager and font override assertions from private fields/methods to behavior checks in `tests/unit/managers/test_localization_manager.gd` and `tests/integration/localization/test_font_override.gd`)
- [x] **Task 8.2**: Add helper-focused test files: (completed 2026-02-17)
  - [x] `tests/unit/managers/helpers/localization/test_localization_catalog.gd` (added 2026-02-17)
  - [x] `tests/unit/managers/helpers/localization/test_localization_font_applier.gd` (added 2026-02-17)
  - [x] `tests/unit/managers/helpers/localization/test_localization_root_registry.gd` (added 2026-02-17)
  - [x] `tests/unit/managers/helpers/localization/test_localization_preview_controller.gd` (added 2026-02-17)
- [x] **Task 8.3**: Keep integration tests for end-to-end guarantees only. (completed 2026-02-17; removed `M_LocalizationManager` private method/property assertions from integration coverage and validated via root-theme behavior in `tests/integration/localization/test_font_override.gd`)
- [x] **Task 8.4**: Run and record full localization suite status. (completed 2026-02-17)
  - [x] `tests/unit/managers/test_localization_manager.gd` (25/25 pass)
  - [x] `tests/unit/managers/helpers/localization` (20/20 pass)
  - [x] `tests/unit/managers/helpers/test_locale_file_loader.gd` (3/3 pass)
  - [x] `tests/unit/utils/test_localization_utils.gd` (5/5 pass)
  - [x] `tests/unit/ui` localization suites via `-gselect=localization` (10/10 pass)
  - [x] `tests/integration/localization` (20/20 pass)
  - [x] `tests/unit/style` (12/12 pass)

---

## Phase 9: Documentation and Completion

**Exit Criteria:** Docs match implementation and continuation context is ready.

- [x] **Task 9.1**: Update `docs/localization_manager/localization-manager-overview.md` to reflect final architecture. (completed 2026-02-17)
- [x] **Task 9.2**: Update `docs/localization_manager/localization-manager-plan.md` with completed design changes. (completed 2026-02-17)
- [x] **Task 9.3**: Update `docs/localization_manager/localization-manager-continuation-prompt.md` with final status and next risks. (completed 2026-02-17)
- [x] **Task 9.4**: Update `docs/localization_manager/localization-manager-tasks.md` summary to reference refactor completion. (completed 2026-02-17)
- [x] **Task 9.5**: Update `AGENTS.md` with any new reusable localization patterns. (completed 2026-02-17; Phase 7/8 localization patterns and test-hardening guidance captured)
- [x] **Task 9.6**: Update `docs/general/DEV_PITFALLS.md` with any refactor-discovered pitfalls. (completed 2026-02-17; inner-class naming collision + private-manager assertion pitfalls added)

---

## Validation Commands

Use project-standard Godot headless test commands for each phase boundary.

- [x] Localization unit tests (`tests/unit/managers/test_localization_manager.gd`, helper localization suites, localization utils/root/UI localization suites; all pass on 2026-02-17)
- [x] Localization integration tests (`tests/integration/localization`; all pass on 2026-02-17)
- [x] Manager regression tests (display/audio/localization touchpoints) (`tests/integration/display/test_display_settings.gd`, `tests/integration/audio/test_audio_settings_ui.gd`, `tests/unit/managers/test_display_manager.gd`; all pass on 2026-02-17)
- [x] `tests/unit/style/test_style_enforcement.gd` when adding/renaming scripts/scenes/resources (style suite pass confirmed on 2026-02-17)

---

## Commit Plan

- [x] Commit each completed phase as a focused, test-green milestone.
- [x] Keep documentation-only updates in separate commits from implementation changes.
- [x] Do not batch multiple phases into one commit unless all included phases are green.

---

## Final Sign-Off Checklist

- [x] `M_LocalizationManager` is orchestration-only and materially smaller.
- [x] Helper modules own catalog/font/registry/preview responsibilities.
- [x] UI scale ownership is explicit and tested.
- [x] Interface/API documentation matches code.
- [x] No localization regressions in first-run language selector, settings preview, persistence, or live locale switching.
