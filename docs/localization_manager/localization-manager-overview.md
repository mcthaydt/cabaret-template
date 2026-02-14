# Localization Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-02-13
**Last Updated**: 2026-02-13
**Status**: PLANNED (no implementation yet)
**Scope**: UI and HUD text localization, JSON-based translation files, dyslexia-friendly font toggle, five supported languages

## Summary

The localization stack uses `M_LocalizationManager` (persistent manager) for loading JSON translation files, switching locale at runtime, and toggling a dyslexia-friendly font across all registered UI roots. Translation keys are resolved through `U_LocalizationUtils.tr(key)`. Settings live in the Redux `localization` slice and are applied in real time. This system deliberately avoids Godot's built-in `.po`/`Translation` infrastructure to remain mobile-safe and to keep translation files human-editable JSON.

## Repo Reality Checks

This system has **zero existing infrastructure**. Everything listed in this document must be created from scratch.

- No `assets/fonts/` directory exists — must be created along with the three font files
- No `resources/localization/` directory exists — must be created with all locale subdirectories
- No localization-related scripts, reducers, actions, or selectors exist anywhere in the codebase
- Interface file will be added to `scripts/interfaces/` (18 files already exist there; `i_localization_manager.gd` will be the 19th)
- `u_global_settings_serialization.gd` requires code modification for persistence (see Global Settings Persistence below)
- `m_state_store.gd`, `u_state_slice_manager.gd`, and `root.tscn` each require modification to register the new Redux slice (see Redux Slice Integration Steps below)
- `M_LocalizationManager` must be added as a persistent node in `root.tscn` and registered via `U_ServiceLocator.register()` in `root.gd` (lines 28–41)

## Goals

- Provide centralized locale switching with immediate UI refresh.
- Resolve translation keys at runtime from JSON files without runtime directory scanning.
- Support English, Spanish, Portuguese, Chinese (Simplified), and Japanese.
- Expose a dyslexia-friendly font toggle that applies a project-level theme override to all registered UI roots.
- Integrate locale and font settings with the existing Redux settings persistence pipeline.
- Follow the same mobile-safe file-loading pattern used by the rest of the codebase.

## Non-Goals

- No runtime translation editor or in-game string authoring.
- No pluralization rules or ICU message-format support (simple key → string substitution only).
- No right-to-left (RTL) layout support (Arabic, Hebrew).
- No voice/audio localization (dialogue audio out of scope).
- No Godot `.po` / `Translation` resource integration.
- No per-scene translation domains — all UI and HUD text shares a single merged dictionary per locale.

## Responsibilities & Boundaries

### Localization Manager owns

- Loading and merging JSON translation files at startup and on locale change.
- Notifying registered UI roots when the locale changes so labels re-query keys.
- Applying the dyslexia font override to all registered UI roots via a project-level `Theme` override.
- Redux `localization` slice subscription for settings changes.

### Localization Manager depends on

- `M_StateStore`: Locale and font settings stored in `localization` Redux slice; manager subscribes for changes.
- `U_ServiceLocator`: Registration for discovery by other systems.
- `U_LocalizationUtils`: Static helper for key resolution; consumed by UI scripts and HUD controllers.

### Localization Manager does NOT own

- Authoring or validation of translation JSON files.
- Font assets (stored under `assets/fonts/`).
- UI layout adjustments for CJK text overflow (handled per-scene by UI authors).

## Public API

```gdscript
# Manager (persistent)
M_LocalizationManager.set_locale(locale: StringName) -> void
M_LocalizationManager.get_locale() -> StringName
M_LocalizationManager.set_dyslexia_font_enabled(enabled: bool) -> void
M_LocalizationManager.register_ui_root(root: Node) -> void
M_LocalizationManager.unregister_ui_root(root: Node) -> void

# Static translation helper (used by UI scripts and HUD controllers)
# NOTE: Always call as U_LocalizationUtils.tr(key) — never as bare tr(key),
# which invokes Godot's built-in Object.tr() localization system instead.
U_LocalizationUtils.tr(key: StringName) -> String
U_LocalizationUtils.tr_fmt(key: StringName, args: Array) -> String  # Simple {0}/{1} substitution

# Localization selectors (query from Redux state)
U_LocalizationSelectors.get_locale(state: Dictionary) -> StringName
U_LocalizationSelectors.is_dyslexia_font_enabled(state: Dictionary) -> bool
U_LocalizationSelectors.get_ui_scale_override(state: Dictionary) -> float

# Redux actions — U_LocalizationActions uses _static_init() to register with U_ActionRegistry,
# matching the pattern used by all other action files in the codebase.
U_LocalizationActions.set_locale(locale: StringName) -> Dictionary
U_LocalizationActions.set_dyslexia_font_enabled(enabled: bool) -> Dictionary
U_LocalizationActions.set_ui_scale_override(scale: float) -> Dictionary
```

## Localization State Model

### Redux Slice: `localization`

| Field | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `current_locale` | StringName | `&"en"` | Active locale code |
| `dyslexia_font_enabled` | bool | `false` | Replaces default font with `fnt_dyslexia.ttf` on all registered UI roots |
| `ui_scale_override` | float | `1.0` | Per-locale scale multiplier; CJK locales default to `1.1` to improve readability |

**Note**: Localization settings persist to `user://global_settings.json` alongside display and audio settings. However, this does **not** happen automatically. Two explicit code changes are required in `u_global_settings_serialization.gd` — see Global Settings Persistence below.

## JSON Translation File Format

### File Layout per Locale

```text
resources/localization/
  en/
    ui.json
    hud.json
  es/
    ui.json
    hud.json
  pt/
    ui.json
    hud.json
  zh_CN/
    ui.json
    hud.json
  ja/
    ui.json
    hud.json
```

### Schema

Each JSON file is a flat key-value dictionary. Keys are `StringName`-compatible identifiers; values are translated strings. No nesting.

```json
{
  "menu.start": "Start Game",
  "menu.settings": "Settings",
  "menu.quit": "Quit",
  "settings.audio.title": "Audio",
  "settings.display.title": "Display",
  "hud.health_label": "HP",
  "hud.checkpoint_toast": "Checkpoint reached!"
}
```

### Key Naming Conventions

- `menu.*` — main menu and overlay button labels
- `settings.*` — settings panel labels and descriptions
- `hud.*` — HUD labels, toasts, and prompt text
- `signpost.*` — in-world signpost messages (see Signpost Localization below)
- `common.*` — shared strings (e.g., `common.confirm`, `common.cancel`, `common.back`)

### Mobile-Safe Loading

`preload()` only works with `.gd`, `.tres`, `.tscn`, and imported binary assets — **not `.json` files**. Using `preload()` on a `.json` file is a compile error in GDScript.

The correct mobile-safe approach is `FileAccess.open()` with a hardcoded `res://` path. `FileAccess` with a known path works on Android because JSON files are embedded in the PCK; only `DirAccess.open()` (runtime directory scanning) fails on packed Android builds.

At startup, `M_LocalizationManager` opens each file for the active locale by hardcoded path, parses with `JSON.parse_string()`, and merges into a single dictionary:

```gdscript
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

func _load_locale_files(locale: StringName) -> Dictionary:
    var merged: Dictionary = {}
    for path: String in _LOCALE_FILE_PATHS.get(locale, []):
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            push_error("LocalizationManager: could not open %s" % path)
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            merged.merge(parsed, true)  # true = overwrite duplicates (last file wins)
    return merged
```

At locale change, `M_LocalizationManager` calls `_load_locale_files()` for the new locale and signals registered UI roots to refresh.

## Signpost Localization

`inter_signpost.gd` emits a `signpost_message` event consumed by the HUD, which displays the text using the checkpoint toast UI. Signpost messages must be localized.

### Authoring Pattern

The existing `RS_SignpostInteractionConfig` has a `@export_multiline var message: String` field. To localize, authors put a **localization key** (e.g., `signpost.cave_warning`) in this `message` field instead of a literal string. No new fields or config resource changes are needed.

The HUD controller (`ui_hud_controller.gd`) passes the `message` value through `U_LocalizationUtils.tr()` before display:

```gdscript
# In _on_signpost_message() — the only code change needed:
var raw: String = String(data.get("message", ""))
var text: String = U_LocalizationUtils.tr(StringName(raw))
```

Signpost configs in `resources/interactions/` use the `signpost.*` key namespace:

```text
resources/interactions/
  cfg_signpost_ancient_door.tres   # message = "signpost.ancient_door"
  cfg_signpost_cave_warning.tres   # message = "signpost.cave_warning"
```

Corresponding entries in `resources/localization/en/hud.json`:

```json
{
  "signpost.ancient_door": "An ancient door. It hasn't opened in centuries.",
  "signpost.cave_warning": "Danger ahead. Proceed with caution."
}
```

### Fallback

If a signpost config stores a literal string instead of a key (e.g., during prototyping), `U_LocalizationUtils.tr()` will return the string unchanged (missing-key fallback returns the input as-is). This means unlocalized signposts degrade gracefully rather than crashing.

### What does NOT change

`inter_signpost.gd` and `U_ECSEventBus` require no changes — the localization contract lives entirely in the HUD controller's event handler and the config resource's field value.

## Redux Slice Integration Steps

Adding the `localization` Redux slice requires touching four files beyond the new slice scripts:

### 1. `scripts/state/m_state_store.gd`

Add the initial state resource constant and export:

```gdscript
const RS_LOCALIZATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_localization_initial_state.gd")

# Use Resource type to match the pattern used by navigation_initial_state and display_initial_state:
@export var localization_initial_state: Resource
```

### 2. `scripts/state/utils/u_state_slice_manager.gd`

Add the reducer constant, extend the function signature, and add the localization slice block inside `initialize_slices()`:

```gdscript
const U_LOCALIZATION_REDUCER := preload("res://scripts/state/reducers/u_localization_reducer.gd")

func initialize_slices(
    # ... existing parameters ...
    localization_initial_state: Resource  # Weak-typed to match display_initial_state pattern
) -> void:
    # ... existing slice blocks ...
    _register_slice(
        &"localization",
        U_LOCALIZATION_REDUCER,
        localization_initial_state.to_dictionary()
    )
```

### 3. `scripts/utils/u_global_settings_serialization.gd`

See Global Settings Persistence below.

### 4. `root.tscn`

Assign the new initial state resource to the `M_StateStore` node's `localization_initial_state` export in the inspector. Also add `M_LocalizationManager` as a persistent child node and register it in `root.gd` via `U_ServiceLocator.register()`.

## Global Settings Persistence

Localization settings do **not** persist automatically. `u_global_settings_serialization.gd` currently only recognizes `display/`, `audio/`, `vfx/`, and whitelisted input/gameplay action prefixes.

Four explicit changes are required (each follows the same pattern as the existing `display`/`vfx` blocks):

**Step 1** — Add `localization/` prefix check in `is_global_settings_action()` (after the `vfx/` check):

```gdscript
if action_name.begins_with("localization/"):
    return true
```

**Step 2** — Add localization slice extraction in `build_settings_from_state()` (after `vfx_slice` block):

```gdscript
var localization_slice := _get_slice_dict(state, StringName("localization"))
if not localization_slice.is_empty():
    settings["localization"] = localization_slice.duplicate(true)
```

**Step 3** — Add localization block in `_prepare_save_payload()` (after `vfx` block):

```gdscript
if settings.has("localization") and settings["localization"] is Dictionary:
    payload["localization"] = _deep_copy(settings["localization"])
```

**Step 4** — Add localization block in `_sanitize_loaded_settings()` (after `vfx` block):

```gdscript
if data.has("localization") and data["localization"] is Dictionary:
    sanitized["localization"] = _deep_copy(data["localization"])
```

Steps 3 and 4 are required for the save/load round-trip to work. Without them, localization settings written by `build_settings_from_state()` would be stripped during save and ignored during load.

## Supported Languages

| Locale | Code | Font Notes | CJK Scale Override |
| ------ | ---- | ---------- | ------------------ |
| English | `en` | Default font (`fnt_ui_default.ttf`) | 1.0 |
| Spanish | `es` | Default font | 1.0 |
| Portuguese | `pt` | Default font | 1.0 |
| Chinese (Simplified) | `zh_CN` | Requires CJK font (`fnt_cjk.ttf`) | 1.1 |
| Japanese | `ja` | Requires CJK font (`fnt_cjk.ttf`) | 1.1 |

CJK locales automatically set `ui_scale_override` to `1.1` in the reducer when the locale changes to `zh_CN` or `ja`, and reset it to `1.0` for Latin locales.

## Dyslexia Font System

### Font Asset

**Note**: `assets/fonts/` does not currently exist and must be created. All three font files below need to be added before the system can function.

- Default font: `assets/fonts/fnt_ui_default.ttf`
- Dyslexia font: `assets/fonts/fnt_dyslexia.ttf` (OpenDyslexic or equivalent)
- CJK font: `assets/fonts/fnt_cjk.ttf` (covers CJK Unified Ideographs for `zh_CN` and `ja`)

### Application Pattern

When `dyslexia_font_enabled` or the active locale changes, `M_LocalizationManager` sets a project-level `Theme` override on all registered UI roots. This mirrors the `UIScaleRoot` registration pattern used by `M_DisplayManager`:

```gdscript
# UI roots register on _ready()
func _ready() -> void:
    U_LocalizationUtils.register_ui_root(get_parent())

# M_LocalizationManager applies font override (CJK-aware)
func _apply_font_override(dyslexia_enabled: bool) -> void:
    var font: Font = _get_active_font(dyslexia_enabled)
    for root in _ui_roots:
        if not is_instance_valid(root):
            continue
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
```

### CJK Font Override

When locale is `zh_CN` or `ja`, the default and dyslexia fonts are replaced with `fnt_cjk.ttf` regardless of the dyslexia toggle (CJK font takes priority for correct glyph coverage).

### Locale Change Notification Contract

When the active locale changes, `M_LocalizationManager` calls `_on_locale_changed(locale: StringName)` on every registered UI root that implements the method. UI panels that display translated text should implement this method to re-query `U_LocalizationUtils.tr()` on all their labels:

```gdscript
# In any UI panel that displays localized text:
func _on_locale_changed(_locale: StringName) -> void:
    _title_label.text = U_LocalizationUtils.tr(&"settings.audio.title")
    _back_button.text = U_LocalizationUtils.tr(&"common.back")
```

Panels that do NOT display localized text (e.g., purely visual widgets) do not need this method. The HUD controller uses a separate `_on_slice_updated` path (listening for the `localization` slice) instead of `_on_locale_changed`.

## File Structure

```text
scripts/managers/
  m_localization_manager.gd

scripts/interfaces/
  i_localization_manager.gd

scripts/managers/helpers/
  u_locale_file_loader.gd        # Merges JSON files into active dictionary

scripts/utils/localization/
  u_localization_utils.gd        # Static tr() and tr_fmt() helpers; register_ui_root()

scripts/state/
  actions/u_localization_actions.gd
  reducers/u_localization_reducer.gd
  selectors/u_localization_selectors.gd

scripts/resources/state/
  rs_localization_initial_state.gd

assets/fonts/
  fnt_ui_default.ttf             # Must be created (directory does not exist yet)
  fnt_dyslexia.ttf
  fnt_cjk.ttf

resources/localization/
  en/
    ui.json
    hud.json
  es/
    ui.json
    hud.json
  pt/
    ui.json
    hud.json
  zh_CN/
    ui.json
    hud.json
  ja/
    ui.json
    hud.json

scenes/ui/overlays/settings/
  ui_localization_settings_overlay.tscn
  ui_localization_settings_tab.tscn

scripts/ui/settings/
  ui_localization_settings_overlay.gd
  ui_localization_settings_tab.gd

resources/ui_screens/
  cfg_localization_settings_overlay.tres

resources/scene_registry/
  cfg_ui_localization_settings_entry.tres
```

## Settings UI Integration

### Localization Settings Panel

Follows the same overlay + embedded tab pattern used by Audio, Display, and VFX settings:

- **Overlay wrapper**: `UI_LocalizationSettingsOverlay` extends `BaseOverlay`, contains the tab scene as a child. Registered as a UI screen definition in `resources/ui_screens/cfg_localization_settings_overlay.tres` and as a scene entry in `resources/scene_registry/cfg_ui_localization_settings_entry.tres`.
- **Tab content**: `UI_LocalizationSettingsTab` extends `VBoxContainer` (NOT `BaseMenuScreen` — see Unified Settings Panel anti-patterns in AGENTS.md). Exposes a language dropdown (`OptionButton` populated from `SUPPORTED_LOCALES`) and a dyslexia font toggle (`CheckButton`).
- **Settings menu button**: A "Language" button is added to `ui_settings_menu.tscn` and wired in `ui_settings_menu.gd` following the same `_open_settings_target()` pattern as other settings buttons.
- Auto-save pattern: dispatch Redux actions immediately on change (no Apply/Cancel).
- Language change triggers immediate locale switch; all registered UI roots refresh on the same frame.

### Settings Integration Checklist

Adding the localization settings tab to the settings menu requires touching these files:

1. **`scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn`** — overlay wrapper scene (create)
2. **`scripts/ui/settings/ui_localization_settings_overlay.gd`** — overlay controller with `_on_back_pressed()` (create)
3. **`scenes/ui/overlays/settings/ui_localization_settings_tab.tscn`** — tab content scene (create)
4. **`scripts/ui/settings/ui_localization_settings_tab.gd`** — tab controller (create)
5. **`resources/ui_screens/cfg_localization_settings_overlay.tres`** — UI screen definition (create)
6. **`resources/scene_registry/cfg_ui_localization_settings_entry.tres`** — scene registry entry (create)
7. **`scripts/ui/utils/u_ui_registry.gd`** — add preload + registration for localization settings overlay (modify)
8. **`scenes/ui/menus/ui_settings_menu.tscn`** — add "Language" button (modify)
9. **`scripts/ui/menus/ui_settings_menu.gd`** — wire button, add overlay constant, update focus neighbors (modify)

### Redux Actions for Settings

```gdscript
const U_LocalizationActions = preload("res://scripts/state/actions/u_localization_actions.gd")

# Switch locale
store.dispatch(U_LocalizationActions.set_locale(&"es"))

# Toggle dyslexia font
store.dispatch(U_LocalizationActions.set_dyslexia_font_enabled(true))

# Adjust CJK scale (usually set automatically by reducer)
store.dispatch(U_LocalizationActions.set_ui_scale_override(1.1))
```

## Testing Strategy

### Unit Tests

- `U_LocalizationReducer`: Action handling, locale switching, dyslexia flag, CJK scale auto-set.
- `U_LocalizationSelectors`: Selector return values for all fields.
- `U_LocaleFileLoader`: Merge logic, missing key fallback (returns key string), duplicate key resolution (last file wins).

### Integration Tests

- Locale switch → verify `U_LocalizationUtils.tr()` returns correct string for new locale.
- Dyslexia toggle → verify font override applied to all registered UI roots.
- CJK locale → verify `fnt_cjk.ttf` override and `ui_scale_override = 1.1`.
- Settings persistence → dispatch locale action → reload global settings → verify locale restored.
- Missing key → verify `U_LocalizationUtils.tr("missing.key")` returns `"missing.key"` (key as fallback, no crash).

### Manual Testing

- Switch each language from the settings panel; confirm all UI labels update immediately.
- Enable dyslexia font; confirm font changes throughout menus and HUD.
- Switch to `zh_CN` and `ja`; confirm CJK glyphs render without missing squares.
- Load game with a saved locale; confirm correct locale applied on boot.

## Resolved Questions

| Question | Decision |
| -------- | -------- |
| Godot built-in Translation vs JSON | JSON via `FileAccess`; human-editable, mobile-safe with hardcoded `res://` paths |
| Single file vs domain files | Two files per locale (`ui.json`, `hud.json`); merged into one dictionary at runtime |
| Missing key behavior | Return the key string as-is (no crash, visible in UI for easy debugging) |
| CJK font strategy | Single shared `fnt_cjk.ttf`; overrides dyslexia toggle for CJK locales |
| Dyslexia font scope | Project-level theme override on all registered UI roots (same pattern as UIScaleRoot) |
| Persistence | `localization` slice persists to `user://global_settings.json`; requires explicit changes to `u_global_settings_serialization.gd` |
| RTL support | Out of scope; not planned |
| Pluralization | Out of scope; simple key→string only |
