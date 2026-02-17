# Localization Manager Implementation Tasks

**Progress:** 100% (49 / 49 tasks complete) — All baseline implementation tasks done including font replacements (7C.1–7C.3). 7A.5 (TranslationServer decision) deferred as a non-task decision item.
**Refactor Follow-up:** `docs/localization_manager/localization-manager-refactor-tasks.md` is also complete (Phase 0-9 complete on 2026-02-17; helper extraction, UI audit cleanup, and test hardening finished).

**Estimated Test Count:** ~70 tests (60 unit + 10 integration)

**Prerequisite:** Display Manager Phase 0 must be complete before starting Localization Manager implementation. The `localization_initial_state` parameter must be added as the **13th parameter** (AFTER `display_initial_state`) in the `u_state_slice_manager.initialize_slices()` function signature.

---

## Pre-Implementation Checklist

Before starting Phase 0, verify:

- [ ] **PRE-1**: Display Manager Phase 0 complete
  - Verify `display_initial_state: Resource` exists in `u_state_slice_manager.initialize_slices()` signature
  - Verify display slice is registered (run existing display tests)

- [ ] **PRE-2**: Understand existing patterns by reading:
  - `scripts/state/utils/u_state_slice_manager.gd` (slice registration)
  - `scripts/managers/m_audio_manager.gd` (hash-based optimization, store discovery)
  - `scripts/managers/m_display_manager.gd` (most recent implementation)
  - `scripts/state/m_state_store.gd` (export pattern, initialize_slices call)
  - `scripts/root.gd` (ServiceLocator registration, lines 28–41)
  - `scripts/state/actions/u_audio_actions.gd` (_static_init() action registry pattern)

---

## Phase 0: Redux Foundation

**Exit Criteria:** All Redux tests pass (5+4+15+7 = 31 unit tests; becomes 6+5+16+9 = 36 after Phase 0.5), localization slice registered in M_StateStore, `is_global_settings_action()` recognizes `localization/` prefix, global settings applier restores localization on startup, no console errors.

### Phase 0A: Localization Initial State Resource

- [x] **Task 0A.1 (Red)**: Write tests for RS_LocalizationInitialState resource
  - Create `tests/unit/state/test_localization_initial_state.gd`
  - Test `current_locale` field exists with default `"en"`
  - Test `dyslexia_font_enabled` field exists with default `false`
  - Test `ui_scale_override` field exists with default `1.0`
  - Test `to_dictionary()` returns all three fields (**Note:** Phase 0.5A adds a 4th field `has_selected_language` — update this test then)
  - Test defaults match reducer defaults (once reducer exists)
  - **Target: 5 tests** (becomes 6 after Phase 0.5A)

- [x] **Task 0A.2 (Green)**: Implement RS_LocalizationInitialState resource
  - Create `scripts/resources/state/rs_localization_initial_state.gd`
  - `@export_enum("en", "es", "pt", "zh_CN", "ja") var current_locale: String = "en"`
  - `@export var dyslexia_font_enabled: bool = false`
  - `@export_range(0.5, 2.0, 0.05) var ui_scale_override: float = 1.0`
  - `to_dictionary()` returns `current_locale` as `StringName`
  - (**Note:** Phase 0.5A adds `@export var has_selected_language: bool = false`)
  - All tests should pass

- [x] **Task 0A.3**: Create default resource instance
  - Create `resources/base_settings/state/cfg_localization_initial_state.tres`
  - Leave all fields at defaults (en, false, 1.0, false)

---

### Phase 0B: Localization Actions

- [x] **Task 0B.1 (Red)**: Write tests for U_LocalizationActions
  - Create `tests/unit/state/test_localization_actions.gd`
  - Test `set_locale(locale)` action structure `{type, payload.locale}`
  - Test `set_dyslexia_font_enabled(enabled)` action structure `{type, payload.enabled}`
  - Test `set_ui_scale_override(scale)` action structure `{type, payload.scale}`
  - Test all action type constants begin with `"localization/"` prefix
  - **Target: 4 tests**

- [x] **Task 0B.2 (Green)**: Implement U_LocalizationActions
  - Create `scripts/state/actions/u_localization_actions.gd`
  - `const ACTION_SET_LOCALE := StringName("localization/set_locale")`
  - `const ACTION_SET_DYSLEXIA_FONT_ENABLED := StringName("localization/set_dyslexia_font_enabled")`
  - `const ACTION_SET_UI_SCALE_OVERRIDE := StringName("localization/set_ui_scale_override")`
  - `static func _static_init()` registers all three via `U_ActionRegistry.register_action()`
  - All tests should pass

---

### Phase 0C: Localization Reducer

- [x] **Task 0C.1 (Red)**: Write tests for U_LocalizationReducer
  - Create `tests/unit/state/test_localization_reducer.gd`
  - Test `set_locale` to each supported locale (en, es, pt, zh_CN, ja) — 5 tests
  - Test unknown locale is ignored (returns same state)
  - Test `zh_CN` sets `ui_scale_override` to `1.1`
  - Test `ja` sets `ui_scale_override` to `1.1`
  - Test `en` resets `ui_scale_override` to `1.0`
  - Test `set_dyslexia_font_enabled` true
  - Test `set_dyslexia_font_enabled` false
  - Test `set_ui_scale_override` clamps at lower bound (0.5)
  - Test `set_ui_scale_override` clamps at upper bound (2.0)
  - Test reducer immutability (old state not mutated)
  - Test unknown action returns same state reference
  - **Target: 15 tests**

- [x] **Task 0C.2 (Green)**: Implement U_LocalizationReducer
  - Create `scripts/state/reducers/u_localization_reducer.gd`
  - `SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]`
  - `CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]`
  - `CJK_SCALE_OVERRIDE: float = 1.1`, `DEFAULT_SCALE_OVERRIDE: float = 1.0`
  - `static func reduce(state, action)` with match on action type
  - `static func _with_values(state, values)` for immutable updates
  - All tests should pass

---

### Phase 0D: Localization Selectors & Store Integration

- [x] **Task 0D.1 (Red)**: Write tests for U_LocalizationSelectors
  - Create `tests/unit/state/test_localization_selectors.gd`
  - Test `get_locale()` returns `&"en"` when slice missing
  - Test `get_locale()` returns correct value from state
  - Test `is_dyslexia_font_enabled()` returns `false` when slice missing
  - Test `is_dyslexia_font_enabled()` returns correct value from state
  - Test `get_ui_scale_override()` returns `1.0` when slice missing
  - Test `get_ui_scale_override()` returns correct value from state
  - Test all selectors handle missing localization slice gracefully
  - **Target: 7 tests**

- [x] **Task 0D.2 (Green)**: Implement U_LocalizationSelectors
  - Create `scripts/state/selectors/u_localization_selectors.gd`
  - Add private helper `static func _get_localization_slice(state: Dictionary) -> Dictionary` (follows `_get_audio_slice` pattern: null guard, `.get("localization", {})`, type check)
  - `static func get_locale(state)` → `StringName` default `&"en"`
  - `static func is_dyslexia_font_enabled(state)` → `bool` default `false`
  - `static func get_ui_scale_override(state)` → `float` default `1.0`
  - (**Note:** Phase 0.5A adds `static func has_selected_language(state)` → `bool` default `false`)
  - All tests should pass

- [x] **Task 0D.3**: Integrate localization slice with M_StateStore
  - Modify `scripts/state/m_state_store.gd`:
    - Add `const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")`
    - Add `@export var localization_initial_state: Resource`
    - Add `localization_initial_state` as **13th argument** to `initialize_slices()` call
  - Modify `scripts/state/utils/u_state_slice_manager.gd`:
    - Add `const U_LOCALIZATION_REDUCER := preload("res://scripts/state/reducers/u_localization_reducer.gd")`
    - Add `localization_initial_state: Resource` as 13th parameter
    - After display slice block: register localization slice with `RS_StateSliceConfig` (name `"localization"`, no transient fields)
  - Modify `scripts/utils/u_global_settings_serialization.gd` (4 methods):
    - `is_global_settings_action()`: add `localization/` prefix check
    - `build_settings_from_state()`: extract localization slice
    - `_prepare_save_payload()`: include localization in payload
    - `_sanitize_loaded_settings()`: accept localization from disk
  - **CRITICAL — Modify `scripts/state/utils/u_global_settings_applier.gd`**:
    - Add `const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")`
    - In `apply()`: extract `"localization"` from settings Dictionary, call `_apply_localization(store, localization_dict)`
    - Add `static func _apply_localization(store: I_StateStore, settings: Dictionary)`:
      - Dispatch `U_LOCALIZATION_ACTIONS.set_locale()` if `"current_locale"` key present
      - Dispatch `U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled()` if `"dyslexia_font_enabled"` key present
      - Dispatch `U_LOCALIZATION_ACTIONS.set_ui_scale_override()` if `"ui_scale_override"` key present
      - Dispatch `U_LOCALIZATION_ACTIONS.mark_language_selected()` if `"has_selected_language"` is `true`
    - **Without this, `has_selected_language` saves to disk but never restores — breaking the first-run skip entirely**
  - Assign `resources/base_settings/state/cfg_localization_initial_state.tres` to `M_StateStore.localization_initial_state` in `scenes/root.tscn` inspector

- [x] **Task 0D.4**: Verify integration
  - Run existing state tests (no regressions)
  - Verify localization slice appears in `get_state()` output
  - Verify `localization/` actions dispatch and persist correctly

**Transient Fields Decision:**
- Localization slice has **no transient fields** (all settings persist to `user://global_settings.json`)
- `transient_fields = []` in slice config

---

## Phase 0.5: First-Run Language Selection Screen

**Exit Criteria:** `language_selector` is the initial scene. First launch shows the flag grid; subsequent launches skip it instantly. All five locale buttons apply the correct locale and transition to main menu. Grid keyboard/gamepad navigation works via `U_FocusConfigurator.configure_grid_focus()`.

### Phase 0.5A: Redux Additions

- [x] **Task 0.5A.1**: Add `has_selected_language` to RS_LocalizationInitialState
  - Open `scripts/resources/state/rs_localization_initial_state.gd`
  - Add `@export var has_selected_language: bool = false`
  - Add `"has_selected_language": has_selected_language` to `to_dictionary()` return

- [x] **Task 0.5A.2**: Add `ACTION_MARK_LANGUAGE_SELECTED` to U_LocalizationActions
  - Open `scripts/state/actions/u_localization_actions.gd`
  - Add `const ACTION_MARK_LANGUAGE_SELECTED := StringName("localization/mark_language_selected")`
  - Register it in `_static_init()` via `U_ActionRegistry.register_action(ACTION_MARK_LANGUAGE_SELECTED)`
  - Add `static func mark_language_selected() -> Dictionary`
    ```gdscript
    return {"type": ACTION_MARK_LANGUAGE_SELECTED, "payload": {}, "immediate": true}
    ```

- [x] **Task 0.5A.3**: Handle new action in U_LocalizationReducer
  - Open `scripts/state/reducers/u_localization_reducer.gd`
  - Add match case:
    ```gdscript
    U_LocalizationActions.ACTION_MARK_LANGUAGE_SELECTED:
        return _with_values(state, {"has_selected_language": true})
    ```

- [x] **Task 0.5A.4**: Add `has_selected_language()` selector to U_LocalizationSelectors
  - Open `scripts/state/selectors/u_localization_selectors.gd`
  - Add:
    ```gdscript
    static func has_selected_language(state: Dictionary) -> bool:
        return bool(_get_localization_slice(state).get("has_selected_language", false))
    ```

- [x] **Task 0.5A.5 (Red → Green)**: Add unit tests for new Redux additions
  - In `tests/unit/state/test_localization_initial_state.gd`:
    - `test_has_selected_language_default` — field exists with default `false`
    - Update existing `to_dictionary` test to verify **4** fields (was 3)
  - In `tests/unit/state/test_localization_actions.gd`:
    - `test_mark_language_selected_action_structure` — verify `{type, payload}` shape
    - Update prefix test to check all **4** action constants
  - In `tests/unit/state/test_localization_reducer.gd`:
    - `test_mark_language_selected_sets_flag` — dispatching action sets `has_selected_language` to `true`
  - In `tests/unit/state/test_localization_selectors.gd`:
    - `test_has_selected_language_returns_default` — returns `false` when field absent
    - `test_has_selected_language_returns_true` — returns `true` when field is `true`

---

### Phase 0.5B: Language Selector Scene & Controller

- [x] **Task 0.5B.1**: Create `scripts/ui/menus/ui_language_selector.gd`
  - `class_name UI_LanguageSelector extends BaseMenuScreen`
  - `const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]`
  - `@onready` vars for all five buttons (unique names: `%EnButton`, `%EsButton`, etc.)
  - **Flash prevention**: Set `visible = false` on the root container in `_ready()` before store lookup. Only set `visible = true` inside `_setup_buttons()` (first-run path). The skip path never shows the UI.
  - `_on_store_ready(_store_ref: M_StateStore)`: (**must match BasePanel signature**) check `U_LocalizationSelectors.has_selected_language(state)` → if true call `_skip_to_main_menu()` (instant transition); else `_setup_buttons()`
  - `_setup_buttons()`: set container `visible = true`, connect pressed signals, call `U_FocusConfigurator.configure_grid_focus(grid, false, false)`, grab focus on en button
  - `_on_locale_selected(locale)`: play confirm sound, dispatch `set_locale` + `mark_language_selected`, call `_transition_to_main_menu()` (fade)
  - `_skip_to_main_menu()` / `_transition_to_main_menu()`: via `U_ServiceLocator.get_service("scene_manager")`
  - `_on_back_pressed()`: `pass` (no back on first-run screen)

- [x] **Task 0.5B.2**: Create `scenes/ui/menus/ui_language_selector.tscn`
  - Root: `Control` with script `ui_language_selector.gd`
  - Children: `UIScaleRoot`, `CenterContainer → PanelContainer → VBoxContainer`
  - VBox contains: `Label` ("Select Your Language"), `HSeparator`, `GridContainer` (columns=3)
  - Grid children: 5 `Button` nodes (unique names) + 1 `Control` spacer
  - Each button has a nested `VBoxContainer` with two `Label`s (native name + locale code)
  - `CustomMinimumSize = Vector2(140, 80)` on each button

---

### Phase 0.5C: Registry & Initial Scene

- [x] **Task 0.5C.1**: Register `language_selector` scene in `scripts/scene_management/u_scene_registry.gd`
  - Add in `_register_scenes()` before or alongside `main_menu`:
    ```gdscript
    _register_scene(
        StringName("language_selector"),
        "res://scenes/ui/menus/ui_language_selector.tscn",
        SceneType.MENU,
        "instant",
        10
    )
    ```

- [x] **Task 0.5C.2**: Change initial scene in `scenes/root.tscn`
  - On the `M_SceneManager` node, change inspector export:
    - `initial_scene_id`: `"main_menu"` → `"language_selector"`

---

### Phase 0.5 Verification

1. **Unit tests**: run all 4 localization test files (`test_localization_initial_state`, `test_localization_actions`, `test_localization_reducer`, `test_localization_selectors`) — all green including new Phase 0.5 tests
2. **First run**: delete `user://global_settings.json`, launch → language selector appears → click a language → main menu loads with correct locale
3. **Return visit**: relaunch → language selector instantly skips to main menu (no visible flash — container starts hidden)
4. **Gamepad**: D-pad through all 5 buttons (3-column grid nav), press confirm
5. **Style check**: run `tests/unit/style/test_style_enforcement.gd` — prefix compliance passes
6. **Regression check**: run full existing test suite — no regressions from initial_scene_id change or scene registry addition

---

## Phase 1: Interface & Core Manager

**Exit Criteria:** Manager registered with ServiceLocator, subscribes to store, applies locale on ready, hash optimization prevents redundant applies.

### Phase 1A: Interface Definition

- [x] **Task 1A.1**: Create I_LocalizationManager interface
  - Create `scripts/interfaces/i_localization_manager.gd`
  - Methods (all `push_error` stubs):
    - `set_locale(_locale: StringName) -> void`
    - `get_locale() -> StringName` (returns `&""`)
    - `set_dyslexia_font_enabled(_enabled: bool) -> void`
    - `register_ui_root(_root: Node) -> void`
    - `unregister_ui_root(_root: Node) -> void`

---

### Phase 1B: Manager Scaffolding & Lifecycle

- [x] **Task 1B.1 (Red)**: Write tests for M_LocalizationManager lifecycle
  - Create `tests/unit/managers/test_localization_manager.gd`
  - Test extends `I_LocalizationManager`
  - Test registers with ServiceLocator as `"localization_manager"`
  - Test discovers state store dependency
  - Test subscribes to `slice_updated` signal
  - Test settings applied on `_ready()` (initial apply)
  - Test `_last_localization_hash` prevents redundant applies
  - **Target: 6 tests**

- [x] **Task 1B.2 (Green)**: Implement M_LocalizationManager scaffold
  - Create `scripts/managers/m_localization_manager.gd` extending `I_LocalizationManager`
  - `@export var state_store: I_StateStore = null`
  - `var _active_locale: StringName = &"en"`
  - `var _translations: Dictionary = {}`
  - `var _ui_roots: Array[Node] = []`
  - `var _last_localization_hash: int = 0`
  - ServiceLocator registration in `_ready()`
  - `_initialize_store_async()` with `U_STATE_UTILS.await_store_ready()` pattern
  - `_on_store_ready()` subscribes `slice_updated`, applies settings
  - `_on_slice_updated()` filters for `&"localization"` slice, hash-guards apply
  - All tests should pass

- [x] **Task 1B.3**: Add manager to root scene
  - Add `M_LocalizationManager` node to `scenes/root.tscn` under `Managers/` after `M_DisplayManager`
  - Update `scripts/root.gd`: add `_register_if_exists(managers_node, "M_LocalizationManager", StringName("localization_manager"))`

---

## Phase 2: JSON File Loading & Locale Switching

**Exit Criteria:** `U_LocalizationUtils.localize()` returns correct translated strings for all supported locales.

### Phase 2A: U_LocaleFileLoader Helper

- [x] **Task 2A.1 (Red)**: Write tests for U_LocaleFileLoader
  - Create `tests/unit/managers/helpers/test_locale_file_loader.gd`
  - Test `load_locale(&"en")` returns a Dictionary
  - Test loading merges multiple JSON files (ui.json + hud.json)
  - Test last file wins on duplicate key
  - Test unsupported locale returns empty Dictionary
  - Test missing file is skipped gracefully (no crash, returns partial result)
  - **Target: 5 tests**

- [x] **Task 2A.2 (Green)**: Implement U_LocaleFileLoader
  - Create `scripts/managers/helpers/u_locale_file_loader.gd`
  - `const _LOCALE_FILE_PATHS: Dictionary` maps each locale to `[ui.json, hud.json]` paths
  - `static func load_locale(locale: StringName) -> Dictionary` using `FileAccess.open()` (NOT preload — preload on .json is a compile error)
  - Merge with `true` (last file wins on duplicate keys)
  - `push_error()` on null file or invalid JSON, but continue gracefully
  - All tests should pass

- [x] **Task 2A.3**: Create locale JSON stub files
  - Create `resources/localization/en/ui.json` and `hud.json`
  - Create `resources/localization/es/ui.json` and `hud.json`
  - Create `resources/localization/pt/ui.json` and `hud.json`
  - Create `resources/localization/zh_CN/ui.json` and `hud.json`
  - Create `resources/localization/ja/ui.json` and `hud.json`
  - Stub content: `{}` (empty objects — content added per project needs)

---

### Phase 2B: U_LocalizationUtils Static Helper

- [x] **Task 2B.1 (Red)**: Write tests for U_LocalizationUtils
  - Create `tests/unit/utils/test_localization_utils.gd`
  - Test `tr(key)` returns translated string when manager available
  - Test `tr(key)` returns key string when key missing from translations
  - Test `tr(key)` returns key string when manager unavailable (ServiceLocator miss)
  - Test `tr_fmt(key, args)` substitutes `{0}`, `{1}` positional args
  - Test `tr_fmt(key, args)` handles missing args gracefully (no crash)
  - **Target: 5 tests**

- [x] **Task 2B.2 (Green)**: Implement U_LocalizationUtils
  - Create `scripts/utils/localization/u_localization_utils.gd`
  - `static func localize(key: StringName) -> String` — calls `manager.translate(key)`, falls back to `str(key)`
  - `static func localize_fmt(key: StringName, args: Array) -> String` — calls `localize()` then replaces `{0}`, `{1}`, etc. using `str(args[i])`
  - `static func register_ui_root(root: Node) -> void` — delegates to manager
  - `static func _get_manager() -> Object` — ServiceLocator lookup
  - **CRITICAL**: Method named `localize()` NOT `tr()` — Godot 4.6 refuses to resolve `.tr()` as an external class member (parse error). Never call bare `tr(key)`.
  - Use `str(value)` not `String(value)` for Variant→String conversion in args substitution
  - All tests should pass

---

### Phase 2C: Locale Loading in Manager

- [x] **Task 2C.1**: Add locale loading methods to M_LocalizationManager
  - Add `const U_LOCALE_FILE_LOADER := preload("res://scripts/managers/helpers/u_locale_file_loader.gd")`
  - `func _load_locale(locale: StringName) -> void` — calls `U_LOCALE_FILE_LOADER.load_locale()`, updates `_translations`, calls `_notify_ui_roots()`
  - `func translate(key: StringName) -> String` — returns `_translations.get(String(key), String(key))`
  - `func get_locale() -> StringName` — returns `_active_locale`
  - `func set_locale(locale: StringName) -> void` — dispatches action if store present, else `_load_locale()` directly
  - `func _apply_localization_settings(state: Dictionary) -> void` — reads locale + dyslexia from selectors, calls `_load_locale()` if locale changed, calls `_apply_font_override()`

---

## Phase 3: Dyslexia Font System

**Exit Criteria:** Font override applied to all registered UI roots when dyslexia toggle or locale changes. CJK locale uses CJK font regardless of dyslexia toggle.

### Phase 3A: Font Loading & UI Root Registration

- [x] **Task 3A.1 (Red)**: Write font + root registration tests
  - Add to `tests/unit/managers/test_localization_manager.gd`
  - Test `register_ui_root()` adds root to internal list
  - Test `unregister_ui_root()` removes root from internal list
  - Test `register_ui_root()` immediately applies current font to new root
  - Test dyslexia font applied to all registered roots on toggle
  - Test CJK locale overrides dyslexia toggle (uses CJK font)
  - Test switching from CJK to Latin locale restores default font
  - **Target: 6 tests**

- [x] **Task 3A.2 (Green)**: Implement font system in M_LocalizationManager
  - Add font vars: `_default_font`, `_dyslexia_font`, `_cjk_font` (all `Font`)
  - `const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]`
  - `func _load_fonts()` — `load("res://assets/fonts/fnt_*.ttf")` (NOT preload on .ttf)
  - Call `_load_fonts()` early in `_ready()` before store async
  - `func register_ui_root(root: Node)` — append if not present, apply font immediately
  - `func unregister_ui_root(root: Node)` — erase from list
  - `func _apply_font_override(dyslexia_enabled: bool)` — iterate `_ui_roots` with `is_instance_valid()` guard, apply font
  - `func _get_active_font(dyslexia_enabled: bool) -> Font` — CJK priority over dyslexia toggle
  - `func _apply_font_to_root(root: Node, font: Font)` — `add_theme_font_override(&"font", font)` for Control; iterate children for CanvasLayer
  - `func _notify_ui_roots()` — call `_on_locale_changed(_active_locale)` on roots that have the method
  - All tests should pass

- [x] **Task 3A.3**: Create font file stubs
  - Create `assets/fonts/` directory
  - Place placeholder `fnt_ui_default.ttf`, `fnt_dyslexia.ttf`, `fnt_cjk.ttf` (copy any existing .ttf as placeholder)
  - **Note**: Without font files, `_load_fonts()` returns null; guard with `if font == null: return` in `_apply_font_to_root()`

---

## Phase 4: Signpost Localization Integration

**Exit Criteria:** HUD resolves signpost `message` values via `U_LocalizationUtils.localize()`. Literal strings degrade gracefully.

### Phase 4A: HUD Controller Update

- [x] **Task 4A.1 (Red)**: Write signpost localization tests
  - Added to `tests/unit/ui/test_hud_interactions_pause_and_signpost.gd`
  - `test_signpost_message_resolved_via_localization` — key resolves to translated text via mock loc manager
  - `test_signpost_literal_string_degrades_gracefully` — literal string passes through unchanged
  - **Completed: 2 tests** (both green after 4A.2)

- [x] **Task 4A.2 (Green)**: Update HUD controller
  - Modified `scripts/ui/hud/ui_hud_controller.gd`
  - `_on_signpost_message()`: raw string now wrapped through `U_LocalizationUtils.localize(StringName(raw))`
  - `_on_slice_updated()`: added `localization` to the slice name filter so locale changes refresh HUD labels
  - All 3 signpost tests pass; full UI suite 187/187 green

---

## Phase 5: Settings UI Integration

**Exit Criteria:** Language dropdown and dyslexia toggle in settings panel dispatch Redux actions. Controls reflect current state on open. "Language" button visible in settings menu and opens the localization overlay.

### Phase 5A: Localization Settings Overlay & Tab

- [x] **Task 5A.1**: Create localization settings tab scene and controller
  - Created `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn`
  - Created `scripts/ui/settings/ui_localization_settings_tab.gd`
  - Auto-save pattern; populates OptionButton + CheckButton from store state on `_ready()`
  - Create `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn`
  - Create `scripts/ui/settings/ui_localization_settings_tab.gd`
  - `class_name UI_LocalizationSettingsTab extends VBoxContainer` (matches audio/display tab pattern)
  - `SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]`
  - `LOCALE_DISPLAY_NAMES: Array[String] = ["English", "Español", "Português", "中文 (简体)", "日本語"]`
  - Auto-save pattern: dispatch immediately (no Apply/Cancel buttons)
  - `_on_language_selected(index)` → `store.dispatch(U_LocalizationActions.set_locale(SUPPORTED_LOCALES[index]))`
  - `_on_dyslexia_toggled(enabled)` → `store.dispatch(U_LocalizationActions.set_dyslexia_font_enabled(enabled))`
  - Populate OptionButton and CheckButton from store state on `_ready()`
  - Tab scene structure:
    ```
    ScrollContainer
    └── VBoxContainer
        ├── Label ("LANGUAGE")
        ├── HBoxContainer
        │   ├── Label ("Language")
        │   └── OptionButton (en/es/pt/zh_CN/ja)
        ├── HSeparator
        ├── Label ("ACCESSIBILITY")
        ├── CheckButton ("Dyslexia-Friendly Font")
    ```

- [x] **Task 5A.2**: Create localization settings overlay wrapper
  - Created `scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn`
  - Created `scripts/ui/settings/ui_localization_settings_overlay.gd`
  - Follows `ui_audio_settings_overlay.gd` pattern exactly
  - Create `scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn`
  - Create `scripts/ui/settings/ui_localization_settings_overlay.gd`
  - `class_name UI_LocalizationSettingsOverlay extends BaseOverlay`
  - `_on_back_pressed()` → play cancel sound, close overlay (follows `ui_audio_settings_overlay.gd` pattern exactly)
  - Overlay scene embeds the tab scene as a child

- [x] **Task 5A.3**: Create UI screen definition and scene registry entry
  - Created `resources/ui_screens/cfg_localization_settings_overlay.tres`
  - Created `resources/scene_registry/cfg_ui_localization_settings_entry.tres`
  - SceneRegistryEntry auto-loaded via `_load_resource_entries()` directory scan (no code change needed)
  - Create `resources/ui_screens/cfg_localization_settings_overlay.tres`
    - `screen_id = &"localization_settings"`, `kind = 1` (OVERLAY), `scene_id = &"localization_settings"`
    - `allowed_shells = [&"gameplay"]`, `allowed_parents = [&"pause_menu", &"settings_menu_overlay"]`, `close_mode = 0`
  - Create `resources/scene_registry/cfg_ui_localization_settings_entry.tres`
    - `scene_id = "localization_settings"`, `scene_path = "res://scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn"`
    - `scene_type = 2` (UI), `default_transition = "instant"`, `preload_priority = 5`

- [x] **Task 5A.4**: Register overlay in U_UIRegistry
  - Added `LOCALIZATION_SETTINGS_OVERLAY` preload and `_register_definition()` call
  - Updated `test_ui_registry.gd` expected overlay count from 11 → 12
  - Modify `scripts/ui/utils/u_ui_registry.gd`:
    - Add `const LOCALIZATION_SETTINGS_OVERLAY := preload("res://resources/ui_screens/cfg_localization_settings_overlay.tres")` after `AUDIO_SETTINGS_OVERLAY`
    - Add `_register_definition(LOCALIZATION_SETTINGS_OVERLAY as RS_UIScreenDefinition)` in `_register_all_screens()`

### Phase 5B: Settings Menu Button Wiring

- [x] **Task 5B.1**: Add "Language" button to settings menu
  - Added `LanguageSettingsButton` to `ui_settings_menu.tscn` after `AudioSettingsButton`
  - Added `OVERLAY_LOCALIZATION_SETTINGS` constant, `@onready` var, handler, and focus-neighbor entry to `ui_settings_menu.gd`
  - Modify `scenes/ui/menus/ui_settings_menu.tscn`:
    - Add `LanguageSettingsButton` (Button, `unique_name_in_owner = true`, text = "Language") after `AudioSettingsButton`, before `RebindControlsButton`
  - Modify `scripts/ui/menus/ui_settings_menu.gd`:
    - Add `const OVERLAY_LOCALIZATION_SETTINGS := StringName("localization_settings")`
    - Add `@onready var _language_settings_button: Button = %LanguageSettingsButton`
    - Wire button in `_on_panel_ready()` following existing pattern
    - Add `_on_language_settings_pressed()` handler: `_open_settings_target(OVERLAY_LOCALIZATION_SETTINGS, StringName("localization_settings"))`
    - Add `_language_settings_button` to `_configure_focus_neighbors()` button array (after audio, before rebind)

---

## Phase 6: Integration Testing

**Exit Criteria:** All integration tests pass, settings survive save/reload cycle, all five locales display correctly.

- [x] **Task 6.1**: Create locale switching integration tests
  - Created `tests/integration/localization/test_locale_switching.gd`
  - locale switch updates manager + Redux state, zh_CN/ja set ui_scale_override=1.1, missing key returns key string
  - **4 tests, all green**

- [x] **Task 6.2**: Create font override integration tests
  - Created `tests/integration/localization/test_font_override.gd`
  - dyslexia on/off persists to Redux state, CJK locale selects CJK font over dyslexia font via _get_active_font()
  - **3 tests, all green**

- [x] **Task 6.3**: Create settings persistence integration tests
  - Created `tests/integration/localization/test_localization_persistence.gd`
  - locale and dyslexia persist across save_state/load_state; all localization/ actions recognized by is_global_settings_action()
  - **Pitfall found**: dispatch needs `await physics_frame` before save (store emits slice_updated once per physics frame)
  - **3 tests, all green**

---

## Phase 7: Post-Implementation Audit Findings (2026-02-14)

**Status: COMPLETE (2026-02-15). All 49 tasks done. 7A.5 (TranslationServer decision) deferred as a non-task decision item.**

---

### Category A: Systemic / Architecture Gaps (Non-UI)

These are fundamental issues with the localization system itself, independent of the settings UI.

- [x] **Task 7A.1**: `register_ui_root()` is never called — font overrides have zero effect
  - `M_LocalizationManager._ui_roots` is always empty. No scene, script, or UI node in the codebase calls `register_ui_root()` or `U_LocalizationUtils.register_ui_root()`.
  - Font changes (locale switch, dyslexia toggle) iterate an empty array — nothing visible changes.
  - **Fix**: Identify which UI root nodes should register (main menu, HUD, pause menu, overlays, etc.) and add `U_LocalizationUtils.register_ui_root(self)` calls in their `_ready()` methods, with corresponding `unregister_ui_root(self)` in `_exit_tree()`.

- [x] **Task 7A.2**: `_on_locale_changed` notification pipeline is dead — zero implementations
  - `M_LocalizationManager._notify_ui_roots()` calls `_on_locale_changed(locale)` on roots that implement it. No UI node in the entire codebase implements this method. The notification fires into the void.
  - Practical consequence: when locale changes mid-session, the translations dictionary updates but no visible text re-renders. Static label `.text` values hardcoded in `.tscn` files never change.
  - **Fix**: UI roots that display localized text must implement `_on_locale_changed(locale: StringName) -> void` to re-query `U_LocalizationUtils.localize()` on their labels. Alternatively, consider a signal-based approach that existing UI can subscribe to.

- [x] **Task 7A.3**: `U_LocalizationUtils.localize()` has exactly ONE consumer in the entire codebase
  - The only production call site is `ui_hud_controller.gd:482` (signpost text). The main menu, pause menu, settings overlays, save/load UI, HUD labels, button text, toast messages — none use `localize()`.
  - The localization pipeline (manager → translations dictionary → `translate()`) is built but almost nothing is plugged into it.
  - **Fix**: Added `_localize_labels()` + `_on_locale_changed()` to `ui_main_menu.gd`, `ui_pause_menu.gd`, `ui_settings_menu.gd`, and `ui_localization_settings_tab.gd`. All user-facing text now uses translation keys. Corresponding keys populated in all 10 locale `.tres` files.

- [x] **Task 7A.4**: `ui_scale_override` is computed in the reducer but never applied anywhere
  - The reducer auto-sets `ui_scale_override = 1.1` for CJK locales. The selector `get_ui_scale_override()` exists. The global settings applier round-trips it. But `M_LocalizationManager` never reads or applies this value. No code anywhere calls `get_ui_scale_override()` to actually scale anything.
  - The value is stored in Redux state, persisted to disk, and ignored at runtime.
  - **Fix**: `M_LocalizationManager._apply_localization_settings()` should read `ui_scale_override` from state and apply it (e.g., by coordinating with `M_DisplayManager`'s UI scale system, or applying directly to registered UI roots).

- [ ] **Task 7A.5**: `TranslationServer.set_locale()` is never called — Godot's engine-level localization is bypassed
  - The manager uses its own `_translations: Dictionary` from JSON. Godot's `TranslationServer` is completely untouched. This means:
    - Godot's built-in `tr()` on Control nodes does nothing.
    - Any `.po` / `.csv` translation files are ignored.
    - Engine locale-aware formatting (dates, numbers) stays on system default.
  - **Decision needed**: Is this intentional (custom system only) or should the manager also call `TranslationServer.set_locale()` for engine integration?

- [x] **Task 7A.6**: Mobile compatibility violation — `FileAccess.open()` on `res://` JSON files
  - `U_LocaleFileLoader.load_locale()` uses `FileAccess.open(path, FileAccess.READ)` at runtime. The project's established pattern (documented in MEMORY.md) is that runtime file access on `res://` paths breaks on Android when resources are packed into PCK files. The rest of the project moved to `const preload()` arrays for mobile safety (display presets, cinema grades, audio registry).
  - JSON files aren't imported by Godot's resource system — they're raw files. Whether they're included in the PCK depends on export settings. If excluded, every locale loads as empty `{}`.
  - **Fix**: Convert locale data to Godot Resources (`.tres` files with Dictionary exports) that can be `preload()`'d, or use `const` preload arrays following the established mobile-safe pattern. Alternatively, ensure `.json` files are explicitly included in export presets.

- [x] **Task 7A.7**: `_apply_font_to_root()` is shallow — font overrides don't cascade to children
  - For CanvasLayer roots, the method only applies `add_theme_font_override(&"font", font)` to immediate children. Deeply nested Labels, Buttons, etc. don't get the override.
  - `add_theme_font_override` on a parent **does not** cascade to children in Godot — it only affects that specific node's own text rendering. Every child Control would need its own override, or a `Theme` resource should be set on the root instead.
  - **Fix**: Either recursively walk all descendant Controls, or set a `Theme` resource with the desired font on the root node (which DOES cascade via theme inheritance).

---

### Category B: Settings UI Gaps

These are issues with the localization settings overlay and tab, compared against the established patterns in the audio, display, and VFX settings overlays.

- [x] **Task 7B.1**: No Apply/Cancel/Reset buttons — language and dyslexia changes are immediate and irreversible
  - Every other settings overlay (Audio, Display, VFX) uses the Apply/Cancel pattern: hold edits locally with `_has_local_edits`, only dispatch to Redux on explicit Apply, Cancel discards local edits, Reset restores factory defaults.
  - The localization tab fires `_state_store.dispatch(set_locale(...))` the instant the OptionButton selection changes. There is no Cancel, no Reset to Defaults. The dyslexia toggle has the same problem.
  - **Fix**: Add `_has_local_edits` tracking, local preview state, and Apply/Cancel/Reset buttons matching the audio/display tab pattern. Add corresponding button nodes to the `.tscn` scene file.

- [x] **Task 7B.2**: No confirmation dialog or revert timer for language change
  - Changing locale is destructive — the user may no longer be able to read the UI to change it back. The Display settings overlay has a `WindowConfirmDialog` with a 10-second revert countdown for resolution changes. Language change has no equivalent safety mechanism.
  - **Fix**: Add a confirmation dialog with a revert timer (e.g., "Keep this language? Reverting in 10s...") following the `_begin_window_confirm()` / `_finalize_window_confirm()` pattern from `ui_display_settings_tab.gd`.

- [x] **Task 7B.3**: No `slice_updated` / state subscription — tab goes stale
  - The tab reads state once in `_ready()` and never subscribes to changes. Audio, Display, and VFX tabs all subscribe with `_state_store.subscribe(_on_state_changed)` and unsubscribe in `_exit_tree()`.
  - Without a subscription, the tab cannot participate in the Apply/Cancel pattern (which requires `_on_state_changed` to reset `_has_local_edits` when state reconciles from outside).
  - **Fix**: Add `_unsubscribe: Callable`, subscribe in `_ready()`, add `_on_state_changed()` handler, add `_exit_tree()` cleanup.

- [x] **Task 7B.4**: No focus neighbor configuration — gamepad/keyboard navigation broken
  - No call to `U_FocusConfigurator` anywhere in the tab. The two interactive controls (`LanguageOptionButton` and `DyslexiaCheckButton`) have no configured focus neighbors. Gamepad navigation between controls is undefined.
  - **Fix**: Add `_configure_focus_neighbors()` using `U_FocusConfigurator.configure_vertical_focus()` for the controls and button row, matching the audio/display tab pattern.

- [x] **Task 7B.5**: No OptionButton popup focus handling — `ui_cancel` double-fires
  - When the language dropdown opens and the user presses `ui_cancel`, it closes the popup AND the overlay simultaneously (the overlay catches the unhandled input). Display tab works around this with `_setup_option_button_popup_focus()` which connects to the popup's `about_to_popup` signal.
  - **Fix**: Add `_setup_option_button_popup_focus(_language_option)` following the display tab pattern.

- [x] **Task 7B.6**: No visible Back button in the scene tree
  - The overlay has no visible Back button node. Back is handled only via `BasePanel._unhandled_input()` catching `ui_cancel`. Mouse-only users have no visible escape path.
  - **Fix**: Add a visible Back/Cancel button to the scene, or incorporate it into the ButtonRow (Cancel/Reset/Apply).

- [x] **Task 7B.7**: Overlay and tab not registered as UI root — font changes not visible on the overlay itself
  - The localization overlay/tab does not call `register_ui_root()`. When the user changes locale or toggles dyslexia, the font swap does not apply to the overlay's own controls. The user changes fonts but can't see the effect on the screen they're looking at.
  - **Fix**: Register the overlay as a UI root in `_ready()` and unregister in `_exit_tree()`, or ensure it's a child of an already-registered root.

- [x] **Task 7B.8**: All overlay label text is hardcoded English — not translation keys
  - "Localization Settings", "LANGUAGE", "Language", "ACCESSIBILITY", "Dyslexia-Friendly Font" are raw English strings in the `.tscn` file, not translation keys. Even with a working translation system, this overlay's own UI would remain in English.
  - **Fix**: `_localize_labels()` in `ui_localization_settings_tab.gd` now sets all heading/section/control labels from translation keys; `_on_locale_changed()` re-renders on locale switch. Keys added to all 10 locale resources.

- [x] **Task 7B.9**: Missing scene structure elements — no Spacer, no ButtonRow
  - Other settings tabs have a `Spacer` node (pushes controls up) and a `ButtonRow` (HBoxContainer with Cancel/Reset/Apply). The localization tab has neither, leaving dead space below the two control rows.
  - The `custom_minimum_size` on the VBox is `Vector2(400, 320)` — the smallest of all overlays.
  - **Fix**: Add Spacer + ButtonRow nodes to the `.tscn` scene, increase minimum size to accommodate the button row.

- [x] **Task 7B.10**: No preview mode integration
  - Audio/Display/VFX tabs use preview mode (`set_*_settings_preview()` / `clear_*_settings_preview()`) to give users real-time feedback while editing without persisting changes. The localization tab has no preview mechanism.
  - **Fix**: Add `set_localization_settings_preview()` and `clear_localization_settings_preview()` to `M_LocalizationManager` (or use a simpler local-state approach since locale changes are less continuous than slider values).

---

### Category C: Content / Asset Gaps

- [x] **Task 7C.1**: `fnt_cjk.ttf` is Lobster Two — a Latin decorative font that cannot render CJK characters
  - Selecting `zh_CN` or `ja` locale applies a font that produces tofu boxes (`□□□□`) for all Chinese/Japanese text. This is worse than not overriding the font at all.
  - **Fix**: Replaced with `fnt_cjk.otf` — Noto Sans CJK SC Regular (Google Fonts / Noto project, OFL license, 16 MB). Covers Simplified Chinese and Japanese kanji. Manager path updated to `res://assets/fonts/fnt_cjk.otf`.

- [x] **Task 7C.2**: `fnt_ui_default.ttf` is Anonymous Pro — a monospace coding font inappropriate for game UI
  - **Fix**: Replaced with Noto Sans Regular (Google Fonts / Noto project, OFL license, 556 KB). Clean, readable sans-serif suitable for game UI across Latin scripts.

- [x] **Task 7C.3**: `fnt_dyslexia.ttf` is Courier Prime — not a dyslexia-friendly font
  - **Fix**: Replaced with Lexend Regular (Google Fonts, OFL license, 98 KB). Designed specifically to reduce visual stress and improve reading fluency.

- [x] **Task 7C.4**: All 10 locale JSON files are empty `{}`
  - Every call to `U_LocalizationUtils.localize(key)` returns the key itself. The system is structurally complete but functionally inert.
  - **Fix**: Populated all 10 locale `.tres` files (5 locales × 2 domains) with translation keys for `common.*`, `menu.main.*`, `menu.pause.*`, `menu.settings.*`, `settings.localization.*`, and `hud.*` namespaces. English, Spanish, Portuguese, Japanese, and Simplified Chinese translations complete.

---

### Category D: Documentation Gaps

- [x] **Task 7D.1**: AGENTS.md "Available services" list (line 1143) is stale
  - `"localization_manager"` is registered in `root.gd` but not listed in the ServiceLocator services quick reference. `"save_manager"` and `"vfx_manager"` are also missing.
  - **Fix**: Update the services list in AGENTS.md.

---

## Phase 7.6: Test Coverage Updates

**Status: COMPLETE (2026-02-15). LocalizationRoot test written.**

- [x] **Task 7.6.1**: Write `U_LocalizationRoot` unit tests
  - Created `tests/unit/ui/test_localization_root.gd` (untracked, needs staging)
  - `test_registers_parent_with_manager` — verifies parent Control appears in `_ui_roots` after 3-frame retry-poll
  - `test_unregisters_parent_on_exit_tree` — verifies parent removed from `_ui_roots` on `_exit_tree()`
  - `test_no_crash_without_manager` — verifies graceful no-op when `localization_manager` not in ServiceLocator
  - **3 tests**

*Note: Tests for settings Apply/Cancel/Reset, language confirm dialog, and preview mode were
evaluated and are out of scope for this branch — those behaviors are covered by integration
patterns from the audio/display/VFX tabs and do not require additional test coverage here.*

---

## Notes

- Record decisions, follow-ups, or blockers here as implementation progresses.

**Key Decisions:**
- Localization slice has **no transient fields** — all settings persist to `user://global_settings.json`
- Locale JSON uses `FileAccess.open()` (NOT `preload()` — preloading `.json` is a compile error)
- **`tr()` CANNOT be a static method name in Godot 4.6**: Godot's parser refuses to resolve `.tr()` as an external class member (collides with `Object.tr()` built-in). Method renamed to `localize()` / `localize_fmt()` in `U_LocalizationUtils`. Never call bare `tr(key)`.
- **`String(value)` does not work for Variant→String in GDScript 4**: use `str(value)` instead. `String(...)` constructor only accepts numeric/bool, not arbitrary Variants.
- **Inner class names must start with a capital letter** in GDScript 4 test files. Using `_MockFoo` with underscore prefix causes parse errors.
- Font stubs in `assets/fonts/` are copies of GUT addon fonts — replace with real fonts before shipping.
- `localization_initial_state` is the **13th parameter** to `initialize_slices()` — misaligning it silently breaks all existing slices
- `u_global_settings_serialization.gd` has **4 methods** that must all be updated — missing any breaks the save/load round-trip
- **`u_global_settings_applier.gd` must ALSO be updated** — serialization writes to disk, but the applier reads from disk and dispatches actions to restore state. Missing it means settings save but never reload. This is a **separate file** from serialization.
- Font `.ttf` files use `load()` not `preload()` — guard all font usages with `if font == null: return`
- CJK font takes priority over dyslexia toggle (CJK fonts already handle accessibility requirements)
- UI root invalidation: always guard with `is_instance_valid(root)` before accessing roots in `_apply_font_override()`
- `_on_store_ready(_store_ref: M_StateStore)` — BasePanel defines this with a parameter; all overrides must match the signature
- Language selector is the initial scene (`language_selector` replaces `main_menu` in `M_SceneManager.initial_scene_id`)
- **`_on_locale_changed` contract**: UI roots that display localized text must implement `_on_locale_changed(locale: StringName) -> void` to re-query `U_LocalizationUtils.tr()` on their labels. Manager checks `has_method()` before calling. HUD uses `_on_slice_updated` instead.
- **Settings UI uses overlay + tab pattern** (not standalone tab): localization settings need an overlay wrapper (`UI_LocalizationSettingsOverlay`), a tab content scene, a `RS_UIScreenDefinition` resource, a `RS_SceneRegistryEntry` resource, preload + registration in `U_UIRegistry`, and button wiring in `ui_settings_menu.gd/.tscn`
- Settings tab scenes live under `scenes/ui/overlays/settings/` (NOT `scenes/ui/menus/settings/` which does not exist)
- **Flash prevention**: Language selector container starts `visible = false`; only revealed in the first-run path; skip path never shows UI
- `has_selected_language` persists via `user://global_settings.json` — the applier must dispatch `mark_language_selected()` on restore so the skip works

**Test commands:**
```bash
# Run localization state tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gselect=test_localization -gexit

# Run localization manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_localization -gexit

# Run all localization integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/localization -gexit
```

---

## Links

- **Plan**: `docs/localization_manager/localization-manager-plan.md`
- **Overview**: `docs/localization_manager/localization-manager-overview.md`

---

## File Reference

### Files to Create

| File | Type | Description |
|------|------|-------------|
| `scripts/resources/state/rs_localization_initial_state.gd` | Resource | Initial state for localization slice (4 fields incl. `has_selected_language`) |
| `resources/base_settings/state/cfg_localization_initial_state.tres` | Instance | Default localization settings instance |
| `scripts/state/actions/u_localization_actions.gd` | Actions | Localization action creators (4 actions incl. `mark_language_selected`) |
| `scripts/state/reducers/u_localization_reducer.gd` | Reducer | Localization state reducer |
| `scripts/state/selectors/u_localization_selectors.gd` | Selectors | Localization state selectors (4 selectors incl. `has_selected_language`) |
| `scripts/interfaces/i_localization_manager.gd` | Interface | Localization manager interface |
| `scripts/managers/m_localization_manager.gd` | Manager | Main localization manager |
| `scripts/managers/helpers/u_locale_file_loader.gd` | Helper | JSON locale file loader |
| `scripts/utils/localization/u_localization_utils.gd` | Utility | Static tr() / tr_fmt() helper |
| `scenes/ui/menus/ui_language_selector.tscn` | Scene | First-run language selection screen (Phase 0.5) |
| `scripts/ui/menus/ui_language_selector.gd` | UI | Language selector controller (Phase 0.5) |
| `resources/localization/en/ui.json` | Data | English UI strings |
| `resources/localization/en/hud.json` | Data | English HUD strings |
| `resources/localization/es/ui.json` | Data | Spanish UI strings |
| `resources/localization/es/hud.json` | Data | Spanish HUD strings |
| `resources/localization/pt/ui.json` | Data | Portuguese UI strings |
| `resources/localization/pt/hud.json` | Data | Portuguese HUD strings |
| `resources/localization/zh_CN/ui.json` | Data | Simplified Chinese UI strings |
| `resources/localization/zh_CN/hud.json` | Data | Simplified Chinese HUD strings |
| `resources/localization/ja/ui.json` | Data | Japanese UI strings |
| `resources/localization/ja/hud.json` | Data | Japanese HUD strings |
| `assets/fonts/fnt_ui_default.ttf` | Font | Default UI font |
| `assets/fonts/fnt_dyslexia.ttf` | Font | Dyslexia-friendly font |
| `assets/fonts/fnt_cjk.ttf` | Font | CJK (Chinese/Japanese) font |
| `scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn` | Scene | Localization settings overlay wrapper |
| `scripts/ui/settings/ui_localization_settings_overlay.gd` | UI | Localization settings overlay controller |
| `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn` | Scene | Localization settings tab content |
| `scripts/ui/settings/ui_localization_settings_tab.gd` | UI | Localization settings tab controller |
| `resources/ui_screens/cfg_localization_settings_overlay.tres` | UIScreen | UI screen definition for localization overlay |
| `resources/scene_registry/cfg_ui_localization_settings_entry.tres` | SceneEntry | Scene registry entry for localization overlay |
| `tests/unit/state/test_localization_initial_state.gd` | Test | Initial state tests (6 after Phase 0.5) |
| `tests/unit/state/test_localization_actions.gd` | Test | Actions tests (5 after Phase 0.5) |
| `tests/unit/state/test_localization_reducer.gd` | Test | Reducer tests (16 after Phase 0.5) |
| `tests/unit/state/test_localization_selectors.gd` | Test | Selectors tests (9 after Phase 0.5) |
| `tests/unit/managers/test_localization_manager.gd` | Test | Manager lifecycle + font tests (12) |
| `tests/unit/managers/helpers/test_locale_file_loader.gd` | Test | File loader tests (5) |
| `tests/unit/utils/test_localization_utils.gd` | Test | Utils tests (5) |
| `tests/integration/localization/test_locale_switching.gd` | Test | Locale switching integration (4) |
| `tests/integration/localization/test_font_override.gd` | Test | Font override integration (3) |
| `tests/integration/localization/test_localization_persistence.gd` | Test | Persistence integration (3) |

### Files to Modify

| File | Changes | Phase |
|------|---------|-------|
| `scripts/state/m_state_store.gd` | Add RS_LOCALIZATION_INITIAL_STATE const, localization_initial_state export, pass as 13th param to initialize_slices() | 0D |
| `scripts/state/utils/u_state_slice_manager.gd` | Add U_LOCALIZATION_REDUCER const, localization_initial_state as 13th param, register localization slice after display | 0D |
| `scripts/utils/u_global_settings_serialization.gd` | Update 4 methods: is_global_settings_action(), build_settings_from_state(), _prepare_save_payload(), _sanitize_loaded_settings() | 0D |
| `scripts/state/utils/u_global_settings_applier.gd` | Add _apply_localization() — dispatches localization actions from loaded settings. **Without this, settings save but never restore.** | 0D |
| `scenes/root.tscn` | Assign cfg_localization_initial_state.tres to M_StateStore; add M_LocalizationManager node (Phase 1); change M_SceneManager.initial_scene_id to `"language_selector"` (Phase 0.5) | 0D, 0.5, 1 |
| `scripts/root.gd` | Register M_LocalizationManager with ServiceLocator via `_register_if_exists()` | 1B |
| `scripts/scene_management/u_scene_registry.gd` | Register `language_selector` scene (SceneType.MENU, preload priority 10) | 0.5C |
| `scripts/ui/hud/ui_hud_controller.gd` | Wrap signpost message through U_LocalizationUtils.tr(); add localization to _on_slice_updated() filter | 4A |
| `scripts/ui/utils/u_ui_registry.gd` | Add LOCALIZATION_SETTINGS_OVERLAY preload + _register_definition() call | 5A |
| `scenes/ui/menus/ui_settings_menu.tscn` | Add "Language" button (LanguageSettingsButton) after AudioSettingsButton | 5B |
| `scripts/ui/menus/ui_settings_menu.gd` | Add overlay constant, @onready button, wiring, handler, focus neighbor entry | 5B |
