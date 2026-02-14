# Localization Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.6)
**Status**: Planning
**Methodology**: Test-Driven Development (Red-Green-Refactor)

---

## Overview

The Localization Manager handles runtime locale switching, JSON translation file loading, and a dyslexia-friendly font toggle applied to all registered UI roots. Implementation follows the same Redux slice, manager, and settings UI patterns established by M_AudioManager and M_DisplayManager.

## Key Patterns to Follow

Before implementation, study these reference files:

- `scripts/managers/m_audio_manager.gd` — hash-based optimization, store discovery, preview mode
- `scripts/managers/m_display_manager.gd` — same pattern, most recent implementation
- `scripts/state/utils/u_state_slice_manager.gd` — slice registration pattern; localization is the 13th parameter
- `scripts/state/m_state_store.gd` — export pattern, `_initialize_slices()` call
- `scripts/root.gd` — ServiceLocator registration (lines 28–41)
- `scripts/state/actions/u_audio_actions.gd` — `_static_init()` action registry pattern

---

## Phase 0: Redux Foundation

**Exit Criteria**: All Redux tests pass, localization slice registered in M_StateStore, no console errors.

### Commit 1: Localization Initial State Resource

**Files to create**:

- `scripts/resources/state/rs_localization_initial_state.gd`
- `resources/base_settings/state/cfg_localization_initial_state.tres`
- `tests/unit/state/test_localization_initial_state.gd`

**Implementation**:

```gdscript
@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_LocalizationInitialState

@export_enum("en", "es", "pt", "zh_CN", "ja") var current_locale: String = "en"
@export var dyslexia_font_enabled: bool = false
@export_range(0.5, 2.0, 0.05) var ui_scale_override: float = 1.0

func to_dictionary() -> Dictionary:
    return {
        "current_locale": StringName(current_locale),
        "dyslexia_font_enabled": dyslexia_font_enabled,
        "ui_scale_override": ui_scale_override,
    }
```

**Tests**:

- `test_has_current_locale_field`
- `test_has_dyslexia_font_enabled_field`
- `test_has_ui_scale_override_field`
- `test_to_dictionary_returns_all_fields`
- `test_defaults_match_reducer`

---

### Commit 2: Localization Actions

**Files to create**:

- `scripts/state/actions/u_localization_actions.gd`
- `tests/unit/state/test_localization_actions.gd`

**Implementation**:

```gdscript
class_name U_LocalizationActions
extends RefCounted

const ACTION_SET_LOCALE := StringName("localization/set_locale")
const ACTION_SET_DYSLEXIA_FONT_ENABLED := StringName("localization/set_dyslexia_font_enabled")
const ACTION_SET_UI_SCALE_OVERRIDE := StringName("localization/set_ui_scale_override")

static func _static_init() -> void:
    U_ActionRegistry.register_action(ACTION_SET_LOCALE)
    U_ActionRegistry.register_action(ACTION_SET_DYSLEXIA_FONT_ENABLED)
    U_ActionRegistry.register_action(ACTION_SET_UI_SCALE_OVERRIDE)

static func set_locale(locale: StringName) -> Dictionary:
    return {"type": ACTION_SET_LOCALE, "payload": {"locale": locale}}

static func set_dyslexia_font_enabled(enabled: bool) -> Dictionary:
    return {"type": ACTION_SET_DYSLEXIA_FONT_ENABLED, "payload": {"enabled": enabled}}

static func set_ui_scale_override(scale: float) -> Dictionary:
    return {"type": ACTION_SET_UI_SCALE_OVERRIDE, "payload": {"scale": scale}}
```

**Tests**:

- `test_set_locale_action`
- `test_set_dyslexia_font_enabled_action`
- `test_set_ui_scale_override_action`
- `test_action_types_use_localization_prefix`

---

### Commit 3: Localization Reducer

**Files to create**:

- `scripts/state/reducers/u_localization_reducer.gd`
- `tests/unit/state/test_localization_reducer.gd`

**Implementation**:

```gdscript
class_name U_LocalizationReducer
extends RefCounted

const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]
const CJK_SCALE_OVERRIDE: float = 1.1
const DEFAULT_SCALE_OVERRIDE: float = 1.0

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", StringName(""))
    var payload: Dictionary = action.get("payload", {})

    match action_type:
        U_LocalizationActions.ACTION_SET_LOCALE:
            var locale: StringName = payload.get("locale", &"en")
            if locale not in SUPPORTED_LOCALES:
                return state
            var scale: float = CJK_SCALE_OVERRIDE if locale in CJK_LOCALES else DEFAULT_SCALE_OVERRIDE
            return _with_values(state, {"current_locale": locale, "ui_scale_override": scale})
        U_LocalizationActions.ACTION_SET_DYSLEXIA_FONT_ENABLED:
            return _with_values(state, {"dyslexia_font_enabled": payload.get("enabled", false)})
        U_LocalizationActions.ACTION_SET_UI_SCALE_OVERRIDE:
            var scale: float = clampf(payload.get("scale", 1.0), 0.5, 2.0)
            return _with_values(state, {"ui_scale_override": scale})

    return state

static func _with_values(state: Dictionary, values: Dictionary) -> Dictionary:
    var new_state := state.duplicate(true)
    for key in values:
        new_state[key] = values[key]
    return new_state
```

**Tests**:

- `test_set_locale_to_english`
- `test_set_locale_to_spanish`
- `test_set_locale_to_portuguese`
- `test_set_locale_to_chinese`
- `test_set_locale_to_japanese`
- `test_unknown_locale_ignored`
- `test_set_locale_zh_CN_sets_cjk_scale`
- `test_set_locale_ja_sets_cjk_scale`
- `test_set_locale_en_resets_scale`
- `test_set_dyslexia_font_enabled_true`
- `test_set_dyslexia_font_enabled_false`
- `test_set_ui_scale_override_clamp_lower`
- `test_set_ui_scale_override_clamp_upper`
- `test_reducer_immutability`
- `test_unknown_action_returns_same_state`

---

### Commit 4: Localization Selectors & M_StateStore Integration

**Files to create**:

- `scripts/state/selectors/u_localization_selectors.gd`
- `tests/unit/state/test_localization_selectors.gd`

**Files to modify**:

**1. `scripts/resources/state/rs_localization_initial_state.gd`** — already created above.

**2. `scripts/state/m_state_store.gd`**:

```gdscript
# Add const near the other RS_ preloads:
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")

# Add export near the other initial state exports (use Resource type to match
# the pattern used by navigation_initial_state and display_initial_state):
@export var localization_initial_state: Resource

# In _initialize_slices(), add as 13th argument:
U_STATE_SLICE_MANAGER.initialize_slices(
    _slice_configs,
    _state,
    boot_initial_state,
    menu_initial_state,
    navigation_initial_state,
    settings_initial_state,
    gameplay_initial_state,
    scene_initial_state,
    debug_initial_state,
    vfx_initial_state,
    audio_initial_state,
    display_initial_state,
    localization_initial_state  # ADD THIS AS 13TH ARG
)
```

**3. `scripts/state/utils/u_state_slice_manager.gd`**:

```gdscript
# Add const near the other reducer preloads:
const U_LOCALIZATION_REDUCER := preload("res://scripts/state/reducers/u_localization_reducer.gd")

# Add 13th parameter to initialize_slices():
static func initialize_slices(
    slice_configs: Dictionary,
    state: Dictionary,
    boot_initial_state: RS_BootInitialState,
    menu_initial_state: RS_MenuInitialState,
    navigation_initial_state: Resource,
    settings_initial_state: RS_SettingsInitialState,
    gameplay_initial_state: RS_GameplayInitialState,
    scene_initial_state: RS_SceneInitialState,
    debug_initial_state: RS_DebugInitialState,
    vfx_initial_state: RS_VFXInitialState,
    audio_initial_state: RS_AudioInitialState,
    display_initial_state: Resource,
    localization_initial_state: Resource  # ADD THIS
) -> void:

# After the display slice block, add:
if localization_initial_state != null:
    var loc_config := RS_StateSliceConfig.new(StringName("localization"))
    loc_config.reducer = Callable(U_LOCALIZATION_REDUCER, "reduce")
    loc_config.initial_state = localization_initial_state.to_dictionary()
    loc_config.dependencies = []
    loc_config.transient_fields = []  # All localization settings persist
    register_slice(slice_configs, state, loc_config)
```

**4. `scripts/utils/u_global_settings_serialization.gd`** (4 methods need changes):

```gdscript
# 1. In is_global_settings_action(), add after the vfx/ check (line ~130):
if action_name.begins_with("localization/"):
    return true

# 2. In build_settings_from_state(), add after vfx_slice block (line ~96):
var localization_slice := _get_slice_dict(state, StringName("localization"))
if not localization_slice.is_empty():
    settings["localization"] = localization_slice.duplicate(true)

# 3. In _prepare_save_payload(), add after vfx block (line ~180):
if settings.has("localization") and settings["localization"] is Dictionary:
    payload["localization"] = _deep_copy(settings["localization"])

# 4. In _sanitize_loaded_settings(), add after vfx block (line ~196):
if data.has("localization") and data["localization"] is Dictionary:
    sanitized["localization"] = _deep_copy(data["localization"])
```

**Note**: All four methods follow the same pattern as the `display` and `vfx` slices — `_deep_copy()` is sufficient since localization has no complex nested types requiring custom serialization (unlike audio which uses `U_AUDIO_SERIALIZATION`).

**5. `scenes/root.tscn`**:

- Assign `resources/base_settings/state/cfg_localization_initial_state.tres` to `M_StateStore.localization_initial_state` in the inspector.

**Selectors**:

```gdscript
class_name U_LocalizationSelectors
extends RefCounted

static func get_locale(state: Dictionary) -> StringName:
    return state.get("localization", {}).get("current_locale", &"en")

static func is_dyslexia_font_enabled(state: Dictionary) -> bool:
    return state.get("localization", {}).get("dyslexia_font_enabled", false)

static func get_ui_scale_override(state: Dictionary) -> float:
    return state.get("localization", {}).get("ui_scale_override", 1.0)
```

**Selector Tests**:

- `test_get_locale_returns_default`
- `test_get_locale_returns_value`
- `test_is_dyslexia_font_enabled_returns_default`
- `test_is_dyslexia_font_enabled_returns_value`
- `test_get_ui_scale_override_returns_default`
- `test_get_ui_scale_override_returns_value`
- `test_selectors_handle_missing_localization_slice`

---

## Phase 1: Interface & Core Manager

**Exit Criteria**: Manager registered with ServiceLocator, subscribes to store, applies locale on ready.

### Commit 1: I_LocalizationManager Interface

**Files to create**:

- `scripts/interfaces/i_localization_manager.gd`

```gdscript
extends Node
class_name I_LocalizationManager

func set_locale(_locale: StringName) -> void:
    push_error("I_LocalizationManager.set_locale not implemented")

func get_locale() -> StringName:
    push_error("I_LocalizationManager.get_locale not implemented")
    return &""

func set_dyslexia_font_enabled(_enabled: bool) -> void:
    push_error("I_LocalizationManager.set_dyslexia_font_enabled not implemented")

func register_ui_root(_root: Node) -> void:
    push_error("I_LocalizationManager.register_ui_root not implemented")

func unregister_ui_root(_root: Node) -> void:
    push_error("I_LocalizationManager.unregister_ui_root not implemented")
```

---

### Commit 2: Manager Scaffolding & Lifecycle

**Files to create**:

- `scripts/managers/m_localization_manager.gd`
- `tests/unit/managers/test_localization_manager.gd`

**Manager Structure**:

```gdscript
@icon("res://assets/editor_icons/icn_manager.svg")
class_name M_LocalizationManager
extends I_LocalizationManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")

@export var state_store: I_StateStore = null

var _active_locale: StringName = &"en"
var _translations: Dictionary = {}
var _ui_roots: Array[Node] = []
var _last_localization_hash: int = 0

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    U_SERVICE_LOCATOR.register(StringName("localization_manager"), self)
    _initialize_store_async()

func _initialize_store_async() -> void:
    if state_store != null:
        _on_store_ready()
        return
    # await_store_ready polls ServiceLocator for up to max_frames (120 = ~2s at 60fps)
    state_store = await U_STATE_UTILS.await_store_ready(self, 120)
    if state_store != null:
        _on_store_ready()
    else:
        push_warning("M_LocalizationManager: Could not discover state store; loading default locale")
        _load_locale(&"en")

func _on_store_ready() -> void:
    state_store.slice_updated.connect(_on_slice_updated)
    var state: Dictionary = state_store.get_state()
    _apply_localization_settings(state)

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    if slice_name != &"localization":
        return
    var state: Dictionary = state_store.get_state()
    var loc_slice: Dictionary = state.get("localization", {})
    var loc_hash: int = loc_slice.hash()
    if loc_hash != _last_localization_hash:
        _apply_localization_settings(state)
        _last_localization_hash = loc_hash
```

**Tests**:

- `test_manager_extends_i_localization_manager`
- `test_manager_registers_with_service_locator`
- `test_manager_discovers_state_store`
- `test_manager_subscribes_to_slice_updates`
- `test_settings_applied_on_ready`
- `test_hash_prevents_redundant_applies`

---

### Commit 3: Add to Root Scene

**Files to modify**:

**1. `scenes/root.tscn`**:

- Add `M_LocalizationManager` node under `Managers/` after `M_DisplayManager`.

**2. `scripts/root.gd`**:

```gdscript
# In the manager registration block (around lines 28-41):
_register_if_exists(managers_node, "M_LocalizationManager", StringName("localization_manager"))
```

---

## Phase 2: JSON File Loading & Locale Switching

**Exit Criteria**: `U_LocalizationUtils.tr()` returns correct translated strings for all supported locales.

### Commit 1: U_LocaleFileLoader Helper

**Files to create**:

- `scripts/managers/helpers/u_locale_file_loader.gd`
- `tests/unit/managers/helpers/test_locale_file_loader.gd`

**Implementation**:

```gdscript
class_name U_LocaleFileLoader
extends RefCounted

const _LOCALE_FILE_PATHS: Dictionary = {
    &"en":    ["res://resources/localization/en/ui.json",
               "res://resources/localization/en/hud.json"],
    &"es":    ["res://resources/localization/es/ui.json",
               "res://resources/localization/es/hud.json"],
    &"pt":    ["res://resources/localization/pt/ui.json",
               "res://resources/localization/pt/hud.json"],
    &"zh_CN": ["res://resources/localization/zh_CN/ui.json",
               "res://resources/localization/zh_CN/hud.json"],
    &"ja":    ["res://resources/localization/ja/ui.json",
               "res://resources/localization/ja/hud.json"],
}

static func load_locale(locale: StringName) -> Dictionary:
    var merged: Dictionary = {}
    for path: String in _LOCALE_FILE_PATHS.get(locale, []):
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            push_error("U_LocaleFileLoader: could not open %s" % path)
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            merged.merge(parsed, true)  # true = last file wins on duplicate keys
        else:
            push_error("U_LocaleFileLoader: invalid JSON in %s" % path)
    return merged
```

**Tests**:

- `test_load_locale_returns_dictionary`
- `test_load_locale_merges_multiple_files`
- `test_load_locale_last_file_wins_on_duplicate_key`
- `test_load_locale_unsupported_returns_empty`
- `test_load_locale_missing_file_skipped_gracefully`

---

### Commit 2: U_LocalizationUtils Static Helper

**Files to create**:

- `scripts/utils/localization/u_localization_utils.gd`
- `tests/unit/utils/test_localization_utils.gd`

**Implementation**:

```gdscript
class_name U_LocalizationUtils
extends RefCounted

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

# NOTE: Always call as U_LocalizationUtils.tr(key). Never call bare tr(key),
# which invokes Godot's built-in Object.tr() system instead.
static func tr(key: StringName) -> String:
    var manager := _get_manager()
    if manager == null:
        return String(key)
    return manager.translate(key)

static func tr_fmt(key: StringName, args: Array) -> String:
    var base: String = tr(key)
    for i: int in args.size():
        base = base.replace("{%d}" % i, String(args[i]))
    return base

static func register_ui_root(root: Node) -> void:
    var manager := _get_manager()
    if manager != null:
        manager.register_ui_root(root)

static func _get_manager() -> M_LocalizationManager:
    return U_SERVICE_LOCATOR.get_service(StringName("localization_manager")) as M_LocalizationManager
```

**Tests**:

- `test_tr_returns_translated_string`
- `test_tr_returns_key_on_missing_key`
- `test_tr_returns_key_when_manager_unavailable`
- `test_tr_fmt_substitutes_positional_args`
- `test_tr_fmt_handles_missing_args_gracefully`

---

### Commit 3: Locale Loading in Manager

**Files to modify**:

- `scripts/managers/m_localization_manager.gd`

Add locale loading and `translate()` method:

```gdscript
func _load_locale(locale: StringName) -> void:
    _translations = U_LOCALE_FILE_LOADER.load_locale(locale)
    _active_locale = locale
    _notify_ui_roots()

func translate(key: StringName) -> String:
    return _translations.get(String(key), String(key))

func get_locale() -> StringName:
    return _active_locale

func set_locale(locale: StringName) -> void:
    if state_store != null:
        state_store.dispatch(U_LocalizationActions.set_locale(locale))
    else:
        _load_locale(locale)

func _apply_localization_settings(state: Dictionary) -> void:
    var locale: StringName = U_LOCALIZATION_SELECTORS.get_locale(state)
    var dyslexia: bool = U_LOCALIZATION_SELECTORS.is_dyslexia_font_enabled(state)
    if locale != _active_locale:
        _load_locale(locale)
    _apply_font_override(dyslexia)
```

---

## Phase 3: Dyslexia Font System

**Exit Criteria**: Font override applied to all registered UI roots when dyslexia toggle changes.

### Commit 1: Font Loading & UI Root Registration

**Files to modify**:

- `scripts/managers/m_localization_manager.gd`

```gdscript
const CJK_LOCALES: Array[StringName] = [&"zh_CN", &"ja"]

var _default_font: Font = null
var _dyslexia_font: Font = null
var _cjk_font: Font = null

func _ready() -> void:
    _load_fonts()
    # ... rest of _ready()

func _load_fonts() -> void:
    # Fonts loaded at runtime from known paths (not preload — Font is not .tres)
    _default_font = load("res://assets/fonts/fnt_ui_default.ttf") as Font
    _dyslexia_font = load("res://assets/fonts/fnt_dyslexia.ttf") as Font
    _cjk_font = load("res://assets/fonts/fnt_cjk.ttf") as Font

func register_ui_root(root: Node) -> void:
    if root not in _ui_roots:
        _ui_roots.append(root)
        _apply_font_to_root(root, _get_active_font())

func unregister_ui_root(root: Node) -> void:
    _ui_roots.erase(root)

func _apply_font_override(dyslexia_enabled: bool) -> void:
    var font: Font = _get_active_font(dyslexia_enabled)
    for root in _ui_roots:
        _apply_font_to_root(root, font)

func _get_active_font(dyslexia_enabled: bool = false) -> Font:
    if _active_locale in CJK_LOCALES:
        return _cjk_font  # CJK takes priority over dyslexia toggle
    return _dyslexia_font if dyslexia_enabled else _default_font

func _apply_font_to_root(root: Node, font: Font) -> void:
    if font == null:
        return
    if root is Control:
        root.add_theme_font_override(&"font", font)
    elif root is CanvasLayer:
        for child in root.get_children():
            if child is Control:
                child.add_theme_font_override(&"font", font)

func _notify_ui_roots() -> void:
    # Signal registered roots to re-query translation keys.
    # UI panels that display localized text should implement:
    #   func _on_locale_changed(_locale: StringName) -> void:
    #       _title_label.text = U_LocalizationUtils.tr(&"settings.audio.title")
    # Panels that do NOT display localized text do not need this method.
    # The HUD uses a separate _on_slice_updated path (localization slice filter).
    for root in _ui_roots:
        if not is_instance_valid(root):
            continue
        if root.has_method("_on_locale_changed"):
            root._on_locale_changed(_active_locale)
```

**`_on_locale_changed` contract**: Any registered UI root that displays translated text must implement `_on_locale_changed(locale: StringName) -> void` to re-query `U_LocalizationUtils.tr()` on all its labels. Roots that don't display localized text can omit this method — the manager checks `has_method()` before calling. The HUD controller uses `_on_slice_updated` with the `localization` slice filter instead.

**Tests** (add to `test_localization_manager.gd`):

- `test_register_ui_root_adds_to_list`
- `test_unregister_ui_root_removes_from_list`
- `test_font_override_applied_on_register`
- `test_dyslexia_font_applied_to_all_roots`
- `test_cjk_locale_overrides_dyslexia_toggle`
- `test_font_override_cleared_on_latin_locale`

---

## Phase 4: Signpost Localization Integration

**Exit Criteria**: HUD resolves signpost message values via `U_LocalizationUtils.tr()` before display.

### Commit 1: HUD Controller Update

**File to modify**: `scripts/ui/hud/ui_hud_controller.gd`

The existing signpost flow:

1. `RS_SignpostInteractionConfig` has `@export_multiline var message: String` (line 5)
2. `inter_signpost.gd` reads `typed.message` and publishes `{"message": effective_message, ...}` (line 40-41)
3. `ui_hud_controller.gd` `_on_signpost_message()` reads `data.get("message", "")` (line 480)

No changes are needed to `inter_signpost.gd` or the config resource. The localization contract lives entirely in the HUD handler — pass the `message` value through `U_LocalizationUtils.tr()` before display:

```gdscript
# In _on_signpost_message() (line ~480):
# Before:
var text: String = String(data.get("message", ""))

# After:
var raw: String = String(data.get("message", ""))
var text: String = U_LocalizationUtils.tr(StringName(raw))
```

**How this works**: Authors put localization keys (e.g., `signpost.cave_warning`) in the config's `message` field instead of literal text. The HUD passes the value through `tr()`, which resolves it to the translated string. If the value is not a known key (e.g., a literal string during prototyping), `tr()` returns it unchanged — graceful degradation with zero runtime cost.

**Also required**: Add `localization` to the `_on_slice_updated()` filter (line 127-130) so HUD labels refresh when locale changes:

```gdscript
if slice_name != StringName("gameplay") \
        and slice_name != StringName("scene") \
        and slice_name != StringName("navigation") \
        and slice_name != StringName("display") \
        and slice_name != StringName("localization"):  # ADD THIS
    return
```

**Tests**:

- `test_signpost_message_resolved_via_localization` — verify key is resolved to translated text
- `test_signpost_literal_string_degrades_gracefully` — verify non-key string passes through unchanged

---

## Phase 5: Settings UI Integration

**Exit Criteria**: Language dropdown and dyslexia toggle in settings panel dispatch Redux actions correctly. Settings menu has a "Language" button that opens the localization overlay.

### Commit 1: Localization Settings Overlay & Tab

The localization settings follow the same overlay + embedded tab architecture as Audio, Display, and VFX settings. This requires creating 6 files and modifying 3 existing files.

**Files to create**:

- `scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn`
- `scripts/ui/settings/ui_localization_settings_overlay.gd`
- `scenes/ui/overlays/settings/ui_localization_settings_tab.tscn`
- `scripts/ui/settings/ui_localization_settings_tab.gd`
- `resources/ui_screens/cfg_localization_settings_overlay.tres`
- `resources/scene_registry/cfg_ui_localization_settings_entry.tres`

**Files to modify**:

- `scripts/ui/utils/u_ui_registry.gd` — add preload + registration
- `scenes/ui/menus/ui_settings_menu.tscn` — add "Language" button
- `scripts/ui/menus/ui_settings_menu.gd` — wire button, overlay constant, focus neighbors

**Overlay controller** (follows `ui_audio_settings_overlay.gd` pattern):

```gdscript
@icon("res://assets/editor_icons/icn_utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"
class_name UI_LocalizationSettingsOverlay

func _on_back_pressed() -> void:
    U_UISoundPlayer.play_cancel()
    _close_overlay()

func _close_overlay() -> void:
    var store := get_store()
    if store == null:
        return
    var nav_slice: Dictionary = store.get_state().get("navigation", {})
    var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
    if not overlay_stack.is_empty():
        store.dispatch(U_NavigationActions.close_top_overlay())
    else:
        store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))
```

**Tab scene structure**:

```text
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

**Tab controller**:

```gdscript
class_name UI_LocalizationSettingsTab
extends VBoxContainer  # Matches UI_DisplaySettingsTab / UI_AudioSettingsTab pattern

const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")
const U_LOCALIZATION_SELECTORS := preload("res://scripts/state/selectors/u_localization_selectors.gd")

const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"es", &"pt", &"zh_CN", &"ja"]
const LOCALE_DISPLAY_NAMES: Array[String] = ["English", "Español", "Português", "中文 (简体)", "日本語"]

# Auto-save pattern: dispatch immediately, no Apply/Cancel buttons
func _on_language_selected(index: int) -> void:
    if index < 0 or index >= SUPPORTED_LOCALES.size():
        return
    store.dispatch(U_LocalizationActions.set_locale(SUPPORTED_LOCALES[index]))

func _on_dyslexia_toggled(enabled: bool) -> void:
    store.dispatch(U_LocalizationActions.set_dyslexia_font_enabled(enabled))
```

**UI screen definition** (`cfg_localization_settings_overlay.tres`):

```tres
screen_id = &"localization_settings"
kind = 1  # OVERLAY
scene_id = &"localization_settings"
allowed_shells = Array[StringName]([&"gameplay"])
allowed_parents = Array[StringName]([&"pause_menu", &"settings_menu_overlay"])
close_mode = 0
```

**Scene registry entry** (`cfg_ui_localization_settings_entry.tres`):

```tres
scene_id = "localization_settings"
scene_path = "res://scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn"
scene_type = 2  # UI
default_transition = "instant"
preload_priority = 5
```

**U_UIRegistry changes** (`u_ui_registry.gd`):

```gdscript
# Add const after AUDIO_SETTINGS_OVERLAY:
const LOCALIZATION_SETTINGS_OVERLAY := preload("res://resources/ui_screens/cfg_localization_settings_overlay.tres")

# Add registration after _register_definition(AUDIO_SETTINGS_OVERLAY):
_register_definition(LOCALIZATION_SETTINGS_OVERLAY as RS_UIScreenDefinition)
```

**Settings menu changes** (`ui_settings_menu.gd`):

```gdscript
# Add overlay constant:
const OVERLAY_LOCALIZATION_SETTINGS := StringName("localization_settings")

# Add @onready var:
@onready var _language_settings_button: Button = %LanguageSettingsButton

# Add button wiring in _on_panel_ready():
if _language_settings_button != null and not _language_settings_button.pressed.is_connected(_on_language_settings_pressed):
    _language_settings_button.pressed.connect(_on_language_settings_pressed)

# Add handler:
func _on_language_settings_pressed() -> void:
    U_UISoundPlayer.play_confirm()
    _open_settings_target(OVERLAY_LOCALIZATION_SETTINGS, StringName("localization_settings"))

# Add to _configure_focus_neighbors() button array (after audio, before rebind):
if _language_settings_button != null and _language_settings_button.visible:
    buttons.append(_language_settings_button)
```

**Settings menu scene** (`ui_settings_menu.tscn`):

Add a "Language" button node after `AudioSettingsButton`, before `RebindControlsButton`:

```tscn
[node name="LanguageSettingsButton" type="Button" parent="ScrollContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Language"
```

---

## Phase 6: Integration Testing

**Files to create**:

- `tests/integration/localization/test_locale_switching.gd`
- `tests/integration/localization/test_font_override.gd`
- `tests/integration/localization/test_localization_persistence.gd`

**Test Categories**:

- Locale switch → `U_LocalizationUtils.tr()` returns correct string for new locale
- CJK locale → `ui_scale_override` auto-set to `1.1`, CJK font applied
- Dyslexia toggle → font override applied to all registered roots, cleared on toggle-off
- Settings persistence → dispatch locale action → reload `user://global_settings.json` → correct locale restored
- Missing key → `tr("missing.key")` returns `"missing.key"`, no crash
- Signpost key → HUD displays resolved string, not raw key

---

## Success Criteria

### Phase 0 Complete

- [ ] All Redux tests pass (initial state + actions + reducer + selectors)
- [ ] Localization slice registered as 13th slice in M_StateStore
- [ ] `is_global_settings_action()` recognizes `localization/` prefix
- [ ] `build_settings_from_state()` extracts localization slice
- [ ] `cfg_localization_initial_state.tres` assigned in `root.tscn` inspector
- [ ] No console errors

### Phase 1 Complete

- [ ] Manager registered with ServiceLocator as `"localization_manager"`
- [ ] Manager subscribes to `slice_updated` and applies settings on store ready
- [ ] Hash-based optimization prevents redundant reloads
- [ ] Manager node added to `root.tscn`, registered in `root.gd`

### Phase 2 Complete

- [ ] `U_LocalizationUtils.tr(key)` returns correct translation for active locale
- [ ] Missing keys return the key string unchanged
- [ ] `U_LocalizationUtils.tr_fmt(key, args)` substitutes `{0}`, `{1}` positional args
- [ ] Locale switch reloads translations and notifies UI roots

### Phase 3 Complete

- [ ] Dyslexia font applied to all registered roots on toggle
- [ ] CJK locale applies `fnt_cjk.ttf`, ignores dyslexia toggle
- [ ] Latin locale restores default font when switching from CJK
- [ ] `register_ui_root()` immediately applies current font to new root

### Phase 4 Complete

- [ ] Signpost messages resolve through `U_LocalizationUtils.tr()` in HUD
- [ ] Literal-string signpost configs degrade gracefully (return string unchanged)

### Phase 5 Complete

- [ ] Localization settings overlay registered in U_UIRegistry and scene registry
- [ ] "Language" button added to settings menu, opens localization overlay
- [ ] Language dropdown shows correct current locale on open
- [ ] Selecting a language dispatches action and refreshes all UI labels on same frame
- [ ] Dyslexia toggle reflects current state and dispatches immediately
- [ ] Focus neighbors updated in settings menu to include the new button

### Phase 6 Complete

- [ ] All integration tests pass
- [ ] Settings survive save/reload cycle
- [ ] Manual playtest: all five locales display correctly, CJK glyphs render without squares

---

## Common Pitfalls

1. **`preload()` on `.json` is a compile error** — use `FileAccess.open()` with hardcoded `res://` paths. Only `DirAccess` fails on Android PCK; `FileAccess` with known paths is safe.

2. **Bare `tr(key)` invokes Godot's built-in** — `Object.tr()` is a Godot built-in. Always call `U_LocalizationUtils.tr(key)`. Never call bare `tr(key)` in any GDScript.

3. **`initialize_slices()` parameter count** — localization is the **13th** argument. Adding it as anything else will silently misalign all existing slices.

4. **`u_global_settings_serialization.gd` is not auto-updated** — four methods must be edited manually: `is_global_settings_action()`, `build_settings_from_state()`, `_prepare_save_payload()`, and `_sanitize_loaded_settings()`. Missing any of these breaks the save/load round-trip for localization settings.

5. **Font loading** — `FontFile` (`.ttf`) is loaded via `load()`, not `preload()`. `preload()` works for `.tres` font wrapper resources, not raw `.ttf` files. Wrap fonts in `FontFile` resources if `preload()` is needed.

6. **`assets/fonts/` does not exist** — the directory and all three font files must be created before Phase 3. Attempting to `load()` a missing font returns null; guard with a null check to avoid crashing.

7. **UI root invalidation** — if a root node is freed without calling `unregister_ui_root()`, the array holds a dangling reference. Use `is_instance_valid(root)` before accessing roots in `_apply_font_override()`.

8. **HUD `_on_slice_updated` filter** — `ui_hud_controller.gd` (line 124-131) only processes `gameplay`, `scene`, `navigation`, and `display` slices. If HUD labels need to refresh on locale change, add `localization` to the filter. Otherwise HUD text won't update until the next gameplay/scene slice change.

---

## Testing Commands

```bash
# Run localization state tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gselect=test_localization -gexit

# Run localization manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_localization -gexit

# Run all integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/localization -gexit
```

---

## File Structure

```text
scripts/interfaces/
  i_localization_manager.gd

scripts/managers/
  m_localization_manager.gd

scripts/managers/helpers/
  u_locale_file_loader.gd

scripts/utils/localization/
  u_localization_utils.gd

scripts/resources/state/
  rs_localization_initial_state.gd

scripts/state/actions/
  u_localization_actions.gd

scripts/state/reducers/
  u_localization_reducer.gd

scripts/state/selectors/
  u_localization_selectors.gd

scripts/ui/settings/
  ui_localization_settings_overlay.gd
  ui_localization_settings_tab.gd

assets/fonts/
  fnt_ui_default.ttf              # Must be created
  fnt_dyslexia.ttf
  fnt_cjk.ttf

resources/base_settings/state/
  cfg_localization_initial_state.tres

resources/localization/
  en/  es/  pt/  zh_CN/  ja/
    ui.json
    hud.json

scenes/ui/overlays/settings/
  ui_localization_settings_overlay.tscn
  ui_localization_settings_tab.tscn

resources/ui_screens/
  cfg_localization_settings_overlay.tres

resources/scene_registry/
  cfg_ui_localization_settings_entry.tres

tests/unit/state/
  test_localization_initial_state.gd
  test_localization_actions.gd
  test_localization_reducer.gd
  test_localization_selectors.gd

tests/unit/managers/
  test_localization_manager.gd
  helpers/
    test_locale_file_loader.gd

tests/unit/utils/
  test_localization_utils.gd

tests/integration/localization/
  test_locale_switching.gd
  test_font_override.gd
  test_localization_persistence.gd

docs/localization_manager/
  localization-manager-overview.md
  localization-manager-plan.md
  localization-manager-tasks.md       # To be created
```

---

---

*End of localization manager plan.*
