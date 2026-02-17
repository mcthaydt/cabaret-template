# Localization Manager Refactor Tasks

**Created:** 2026-02-15  
**Status:** In progress  
**Progress:** 64% (38 / 59 tasks complete)

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
- [ ] Capture baseline status:
  - [ ] `tests/unit/managers/test_localization_manager.gd`
  - [ ] `tests/unit/managers/helpers/test_locale_file_loader.gd`
  - [ ] `tests/unit/utils/test_localization_utils.gd`
  - [ ] `tests/unit/ui/test_localization_root.gd`
  - [ ] `tests/integration/localization/test_locale_switching.gd`
  - [ ] `tests/integration/localization/test_font_override.gd`
  - [ ] `tests/integration/localization/test_localization_persistence.gd`

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

- [ ] **Task 6.1**: Decide ownership policy:
  - [ ] Option A (I choose this): `M_DisplayManager` computes effective UI scale using display + localization slices.
- [ ] **Task 6.2 (Red)**: Add tests proving selected policy, including no dispatch loops.
- [ ] **Task 6.3 (Green)**: Remove hidden cross-manager dispatch from `M_LocalizationManager`.
- [ ] **Task 6.4**: Implement selected policy in owner module.
- [ ] **Task 6.5**: Update integration tests for locale-driven CJK scale behavior accordingly.

---

## Phase 7: Utilities and UI Integration Cleanup

**Exit Criteria:** Utility and UI callers consume the refactored contract without regressions.

- [ ] **Task 7.1**: Update `scripts/utils/localization/u_localization_utils.gd` if manager API changes.
- [ ] **Task 7.2**: Audit and update all direct localization manager usage in UI controllers.
- [ ] **Task 7.2a**: Audit translation coverage across UI and helper labels:
  - [ ] ensure all user-facing strings route through localization keys (including tooltips, prompts, and dialogs)
  - [ ] update locale resources for corrected/added strings
  - [ ] document intentional non-localized strings (debug-only or developer-facing)
  - [ ] **Task 7.2a.1**: Localize Display settings UI (`scripts/ui/settings/ui_display_settings_tab.gd`) and add live locale updates:
    - [ ] add localization keys for section headers, labels, tooltips, dialog text, and option labels
    - [ ] update `scripts/utils/display/u_display_option_catalog.gd` to provide localization keys for option entries and quality presets
    - [x] add `LocalizationRoot` to `scenes/ui/overlays/settings/ui_display_settings_tab.tscn` (done 2026-02-16)
  - [ ] **Task 7.2a.2**: Localize Audio settings UI (`scripts/ui/settings/ui_audio_settings_tab.gd`) and add live locale updates:
    - [ ] add localization keys for headers, labels, tooltips, and buttons
    - [x] add `LocalizationRoot` to `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn` (done 2026-02-16)
  - Note: `LocalizationRoot` also added to `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` (2026-02-16) to enable live locale updates.
  - [ ] **Task 7.2a.3**: Localize VFX settings UI (`scripts/ui/settings/ui_vfx_settings_overlay.gd`):
    - [ ] add localization keys for headers, labels, tooltips, and buttons
  - [ ] **Task 7.2a.4**: Localize Gamepad settings overlay (`scripts/ui/overlays/ui_gamepad_settings_overlay.gd`):
    - [ ] add localization keys for titles, labels, tooltips, and preview instructions
  - [ ] **Task 7.2a.5**: Localize Touchscreen settings overlays:
    - [ ] `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd` titles/labels/tooltips/preview instructions
    - [ ] `scripts/ui/overlays/ui_edit_touch_controls_overlay.gd` buttons/labels/preview text
  - [ ] **Task 7.2a.6**: Localize Input profile selector (`scripts/ui/overlays/ui_input_profile_selector.gd`) and profile resources:
    - [ ] add localization keys for overlay text and action group labels (action group labels done 2026-02-16; overlay text pending)
    - [x] update `resources/input/profiles/cfg_*.tres` to use localization keys for `profile_name` and `description` (done 2026-02-16)
    - [x] ensure UI resolves profile name/description via localization keys (done 2026-02-16)
  - [ ] **Task 7.2a.7**: Localize Input rebinding overlay and helpers:
    - [ ] `scripts/ui/overlays/ui_input_rebinding_overlay.gd` dialog/status/tooltips
    - [ ] `scripts/ui/helpers/u_rebind_action_list_builder.gd` action/category labels via localization keys
    - [ ] `scripts/ui/helpers/u_rebind_capture_handler.gd` capture status strings
  - [ ] **Task 7.2a.8**: Localize Save/Load menu (`scripts/ui/overlays/ui_save_load_menu.gd`):
    - [ ] autosave label, slot labels, confirm dialog text, error messages, loading text
    - [x] localized date formatting (month names + AM/PM tokens) (done 2026-02-16)
  - [ ] **Task 7.2a.9**: Localize HUD prompt labels:
    - [x] `scripts/ui/hud/ui_button_prompt.gd` fallback “Interact” label (done 2026-02-16)
    - [x] `scripts/ui/hud/ui_virtual_button.gd` action labels (done 2026-02-16)
    - [ ] `scripts/ui/hud/ui_hud_controller.gd` autosave spinner label and transient HUD labels
  - [ ] **Task 7.2a.10**: Localize loading and language selector UI:
    - [ ] `scripts/scene_management/transitions/trans_loading_screen.gd` loading title text
    - [ ] `scripts/ui/menus/ui_language_selector.gd` header/title label
  - [ ] **Task 7.2a.11**: Add/verify localization keys across all locales:
    - [x] update `resources/localization/cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN) for all added keys (input action/profile + date tokens added 2026-02-16)
    - [ ] confirm no hardcoded user-facing strings remain in audited files
- [ ] **Task 7.3**: Ensure settings overlay preview/apply/cancel behavior remains unchanged in UX.
- [ ] **Task 7.4**: Add targeted regression tests for `UI_LocalizationSettingsTab` around preview + confirm timer flow.

### Audit Findings (2026-02-16)

The following translation coverage gaps were identified and should be addressed as part of Task 7.2a:

- `scripts/ui/settings/ui_display_settings_tab.gd`: hardcoded section headers, labels, button text, confirm dialog title/body, tooltip strings, and option labels (resolution, window mode, UI scale, vsync, etc.) should be localized. Also ensure option labels come from catalog rather than display catalog literals.
- `scripts/utils/display/u_display_option_catalog.gd`: display option entries and quality presets need localization keys (not hardcoded user-facing labels).
- `scripts/ui/settings/ui_audio_settings_tab.gd`: all labels, section headers, slider labels, button text, tooltips are hardcoded.
- `scripts/ui/settings/ui_vfx_settings_overlay.gd`: all headers, slider labels, toggle labels, and button text are hardcoded.
- `scripts/ui/overlays/ui_gamepad_settings_overlay.gd`: overlay title/labels/tooltips and preview instructions are hardcoded.
- `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`: overlay title/labels/tooltips and preview instructions are hardcoded.
- `scripts/ui/overlays/ui_edit_touch_controls_overlay.gd`: buttons, labels, and preview text are hardcoded.
- `scripts/ui/overlays/ui_input_profile_selector.gd`: overlay labels, “default profiles” header, profile name/description fields, and action group labels should be localized. Profiles should source localized name/description via keys.
- `resources/input/profiles/cfg_*.tres`: `profile_name` and `description` should be localization keys, not display strings.
- `scripts/ui/overlays/ui_input_rebinding_overlay.gd`: all dialog text, tooltips, and status messages (including “press any key”, “already bound”, “reserved”, etc.) should be localized.
- `scripts/ui/helpers/u_rebind_action_list_builder.gd`: action and category labels should be fetched via localization keys.
- `scripts/ui/helpers/u_rebind_capture_handler.gd`: capture status strings should be localized.
- `scripts/ui/overlays/ui_save_load_menu.gd`: autosave label, slot labels, confirm dialog text, error messages, loading text, and date formatting should be localized (month names + AM/PM via keys).
- `scripts/ui/hud/ui_button_prompt.gd`: fallback “Interact” label should be localized.
- `scripts/ui/hud/ui_virtual_button.gd`: action labels should be localized.
- `scripts/ui/hud/ui_hud_controller.gd`: autosave spinner label and other transient HUD labels should be localized.
- `scripts/scene_management/transitions/trans_loading_screen.gd`: loading title text should be localized.
- `scripts/ui/menus/ui_language_selector.gd`: header/title label should be localized.
- Scene roots: `scenes/ui/overlays/settings/ui_display_settings_tab.tscn`, `scenes/ui/overlays/settings/ui_audio_settings_tab.tscn`, and `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` appear to lack a `LocalizationRoot` node, preventing live locale updates.
- Locale resources: add missing keys across `resources/localization/cfg_locale_*_ui.tres` (en/es/pt/ja/zh_CN) for all new/covered strings, including common labels, date tokens, and settings labels.

---

## Phase 8: Test Hardening

**Exit Criteria:** Tests validate behavior, not internals; helper coverage is strong.

- [ ] **Task 8.1**: Replace brittle tests that inspect private manager internals where possible.
- [ ] **Task 8.2**: Add helper-focused test files:
  - [ ] `tests/unit/managers/helpers/localization/test_localization_catalog.gd`
  - [ ] `tests/unit/managers/helpers/localization/test_localization_font_applier.gd`
  - [x] `tests/unit/managers/helpers/localization/test_localization_root_registry.gd` (added 2026-02-17)
  - [x] `tests/unit/managers/helpers/localization/test_localization_preview_controller.gd` (added 2026-02-17)
- [ ] **Task 8.3**: Keep integration tests for end-to-end guarantees only.
- [ ] **Task 8.4**: Run and record full localization suite status.

---

## Phase 9: Documentation and Completion

**Exit Criteria:** Docs match implementation and continuation context is ready.

- [ ] **Task 9.1**: Update `docs/localization_manager/localization-manager-overview.md` to reflect final architecture.
- [ ] **Task 9.2**: Update `docs/localization_manager/localization-manager-plan.md` with completed design changes.
- [ ] **Task 9.3**: Update `docs/localization_manager/localization-manager-continuation-prompt.md` with final status and next risks.
- [ ] **Task 9.4**: Update `docs/localization_manager/localization-manager-tasks.md` summary to reference refactor completion.
- [ ] **Task 9.5**: Update `AGENTS.md` with any new reusable localization patterns.
- [ ] **Task 9.6**: Update `docs/general/DEV_PITFALLS.md` with any refactor-discovered pitfalls.

---

## Validation Commands

Use project-standard Godot headless test commands for each phase boundary.

- [ ] Localization unit tests
- [ ] Localization integration tests
- [ ] Manager regression tests (display/audio/localization touchpoints)
- [ ] `tests/unit/style/test_style_enforcement.gd` when adding/renaming scripts/scenes/resources

---

## Commit Plan

- [ ] Commit each completed phase as a focused, test-green milestone.
- [ ] Keep documentation-only updates in separate commits from implementation changes.
- [ ] Do not batch multiple phases into one commit unless all included phases are green.

---

## Final Sign-Off Checklist

- [ ] `M_LocalizationManager` is orchestration-only and materially smaller.
- [ ] Helper modules own catalog/font/registry/preview responsibilities.
- [ ] UI scale ownership is explicit and tested.
- [ ] Interface/API documentation matches code.
- [ ] No localization regressions in first-run language selector, settings preview, persistence, or live locale switching.
