# Localization Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-02-13
**Last Updated**: 2026-02-17
**Status**: IMPLEMENTED. Refactor complete (Phases 0-9 complete on 2026-02-17).
**Scope**: UI and HUD text localization, resource-based translation catalogs, dyslexia-friendly font toggle, five supported languages

## Summary

The localization stack uses `M_LocalizationManager` (persistent manager) for loading translation catalogs from `.tres` resources, switching locale at runtime, and toggling a dyslexia-friendly font across all registered UI roots. Translation keys are resolved through `U_LocalizationUtils.localize(key)` / `localize_fmt()`. Settings live in the Redux `localization` slice and are applied in real time. This system deliberately avoids Godot's built-in `.po`/`Translation` infrastructure to remain mobile-safe and to keep translations as editable Resource data.

Refactor outcome: catalog loading, font/theme application, root lifecycle, and preview lifecycle are now extracted into dedicated helpers, `M_DisplayManager` owns effective UI scale composition, and localization coverage/tests were hardened through Phase 8.

## Repo Reality Checks

Baseline infrastructure exists and is active:

- `assets/fonts/` contains `fnt_ui_default.ttf`, `fnt_dyslexia.ttf`, `fnt_cjk.otf`.
- `resources/localization/` contains `cfg_locale_*_ui.tres` and `cfg_locale_*_hud.tres` resources (`RS_LocaleTranslations`).
- Localization slice (actions/reducer/selectors) is integrated in `M_StateStore` and global settings persistence.
- `M_LocalizationManager` is a persistent manager in `root.tscn` and registered via `U_ServiceLocator`.
- `U_LocalizationRoot` is used by UI scenes to register roots for locale changes and font overrides.

## Goals

- Provide centralized locale switching with immediate UI refresh.
- Resolve translation keys at runtime from `.tres` resources without runtime directory scanning.
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

## Architecture Decisions (Phase 0 Contract)

- **Manager vs helpers**: `M_LocalizationManager` orchestrates only. Extract and own logic in helpers:
  - Catalog loader/merger + fallback policy
  - Font/theme builder + applier
  - UI root registry + dead-root pruning
  - Preview controller (store vs preview arbitration)
- **Translation fallback policy**: `requested locale → fallback locale (en) → key string`. Unsupported locale requests do **not** change the active locale.
- **Locale preview contract**: Preview applies locale + dyslexia setting visually without dispatching to Redux; store updates are ignored while preview is active; clearing preview re-applies store-driven state.
- **Locale change notification**: Manager emits `locale_changed(locale)` and calls `_on_locale_changed(locale)` on registered UI roots that implement the method.
- **UI scale ownership**: `M_DisplayManager` computes effective UI scale using display + localization slices. `M_LocalizationManager` must not dispatch display actions.

## Responsibilities & Boundaries

### Localization Manager owns

- Loading and merging translation catalog resources at startup and on locale change.
- Notifying registered UI roots when the locale changes so labels re-query keys.
- Applying the dyslexia font override to all registered UI roots via a project-level `Theme` override.
- Redux `localization` slice subscription for settings changes.

### Localization Manager depends on

- `M_StateStore`: Locale and font settings stored in `localization` Redux slice; manager subscribes for changes.
- `U_ServiceLocator`: Registration for discovery by other systems.
- `U_LocalizationUtils`: Static helper for key resolution; consumed by UI scripts and HUD controllers.

### Localization Manager does NOT own

- Authoring or validation of translation data content.
- Font assets (stored under `assets/fonts/`).
- UI layout adjustments for CJK text overflow (handled per-scene by UI authors).

## Public API (Refactor Contract)

```gdscript
# Manager (persistent)
M_LocalizationManager.set_locale(locale: StringName) -> void
M_LocalizationManager.get_locale() -> StringName
M_LocalizationManager.set_dyslexia_font_enabled(enabled: bool) -> void
M_LocalizationManager.register_ui_root(root: Node) -> void
M_LocalizationManager.unregister_ui_root(root: Node) -> void
M_LocalizationManager.translate(key: StringName) -> String
M_LocalizationManager.set_localization_preview(preview: Dictionary) -> void
M_LocalizationManager.clear_localization_preview() -> void
M_LocalizationManager.get_supported_locales() -> Array[StringName]
M_LocalizationManager.get_effective_settings() -> Dictionary
M_LocalizationManager.is_preview_active() -> bool

signal locale_changed(locale: StringName)

# Static translation helper (used by UI scripts and HUD controllers)
# NOTE: Always call as U_LocalizationUtils.localize(key) — never as bare tr(key),
# which invokes Godot's built-in Object.tr() localization system instead.
U_LocalizationUtils.localize(key: StringName) -> String
U_LocalizationUtils.localize_fmt(key: StringName, args: Array) -> String  # Simple {0}/{1} substitution

# Localization selectors (query from Redux state)
U_LocalizationSelectors.get_locale(state: Dictionary) -> StringName
U_LocalizationSelectors.is_dyslexia_font_enabled(state: Dictionary) -> bool
U_LocalizationSelectors.get_ui_scale_override(state: Dictionary) -> float
U_LocalizationSelectors.has_selected_language(state: Dictionary) -> bool

# Redux actions — U_LocalizationActions uses _static_init() to register with U_ActionRegistry,
# matching the pattern used by all other action files in the codebase.
U_LocalizationActions.set_locale(locale: StringName) -> Dictionary
U_LocalizationActions.set_dyslexia_font_enabled(enabled: bool) -> Dictionary
U_LocalizationActions.set_ui_scale_override(scale: float) -> Dictionary
U_LocalizationActions.mark_language_selected() -> Dictionary
```

## Migration Notes (Call Sites to Audit)

- `scripts/ui/settings/ui_localization_settings_tab.gd`: depends on preview APIs (`set_localization_preview` / `clear_localization_preview`) and confirm timer flow.
- `scripts/ui/helpers/u_localization_root.gd` + `LocalizationRoot` nodes in UI scenes: depend on `register_ui_root` / `unregister_ui_root` and `_on_locale_changed` callbacks.
- UI screens implementing `_on_locale_changed`: `ui_main_menu.gd`, `ui_settings_menu.gd`, `ui_pause_menu.gd`, `ui_game_over.gd`, `ui_victory.gd`, `ui_credits.gd`, `ui_save_load_menu.gd`, `ui_input_profile_selector.gd`, `ui_localization_settings_tab.gd`.
- HUD/localized prompts: `ui_hud_controller.gd`, `ui_button_prompt.gd`, `ui_virtual_button.gd`.
- Loading screen/tips: `trans_loading_screen.gd` uses localization keys for status/tips.
- Input profiles: `resources/input/profiles/cfg_*.tres` now store localization keys; `ui_input_profile_selector.gd` localizes profile name/description and action labels.
- Persistence/restore: `u_global_settings_serialization.gd` + `u_global_settings_applier.gd` depend on localization slice shape (including `has_selected_language`).
- UI scale coupling: Phase 6 completed. `M_DisplayManager` now owns effective UI scale (`display.ui_scale * localization.ui_scale_override`) and reacts to localization slice updates directly.

## Localization State Model

### Redux Slice: `localization`

| Field | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `current_locale` | StringName | `&"en"` | Active locale code |
| `dyslexia_font_enabled` | bool | `false` | Replaces default font with `fnt_dyslexia.ttf` on all registered UI roots |
| `ui_scale_override` | float | `1.0` | Per-locale scale multiplier; CJK locales default to `1.1` to improve readability |
| `has_selected_language` | bool | `false` | First-run language selection gate (true after language selector completes) |

**Note**: Localization settings persist to `user://global_settings.json` alongside display and audio settings via `u_global_settings_serialization.gd` and `u_global_settings_applier.gd`.

## Locale Catalog Resources

### File Layout per Locale

```text
resources/localization/
  cfg_locale_en_ui.tres
  cfg_locale_en_hud.tres
  cfg_locale_es_ui.tres
  cfg_locale_es_hud.tres
  cfg_locale_pt_ui.tres
  cfg_locale_pt_hud.tres
  cfg_locale_zh_CN_ui.tres
  cfg_locale_zh_CN_hud.tres
  cfg_locale_ja_ui.tres
  cfg_locale_ja_hud.tres
```

### Schema

Each locale catalog is a `RS_LocaleTranslations` Resource with a flat `translations: Dictionary` (no nesting). Keys are `StringName`-compatible identifiers; values are translated strings.

```gdscript
[resource]
script = ExtResource("res://scripts/resources/localization/rs_locale_translations.gd")
locale = &"en"
domain = &"ui"
translations = {
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

`U_LocalizationCatalog` preloads the `.tres` catalogs via const arrays (mobile-safe, no runtime directory scanning), caches merged catalogs, and applies fallback merge behavior (`requested -> en`) before key-level fallback. `M_LocalizationManager` now requests `U_LocalizationCatalog.load_catalog(locale)`. `U_LocaleFileLoader` remains as a temporary compatibility shim.

## Signpost Localization

`inter_signpost.gd` emits a `signpost_message` event consumed by the HUD, which displays the text using the checkpoint toast UI. Signpost messages must be localized.

### Authoring Pattern

The existing `RS_SignpostInteractionConfig` has a `@export_multiline var message: String` field. To localize, authors put a **localization key** (e.g., `signpost.cave_warning`) in this `message` field instead of a literal string. No new fields or config resource changes are needed.

The HUD controller (`ui_hud_controller.gd`) passes the `message` value through `U_LocalizationUtils.localize()` before display:

```gdscript
# In _on_signpost_message() — the only code change needed:
var raw: String = String(data.get("message", ""))
var text: String = U_LocalizationUtils.localize(StringName(raw))
```

Signpost configs in `resources/interactions/` use the `signpost.*` key namespace:

```text
resources/interactions/
  cfg_signpost_ancient_door.tres   # message = "signpost.ancient_door"
  cfg_signpost_cave_warning.tres   # message = "signpost.cave_warning"
```

Corresponding entries in `resources/localization/cfg_locale_en_hud.tres`:

```gdscript
translations = {
  "signpost.ancient_door": "An ancient door. It hasn't opened in centuries.",
  "signpost.cave_warning": "Danger ahead. Proceed with caution."
}
```

### Fallback

If a signpost config stores a literal string instead of a key (e.g., during prototyping), `U_LocalizationUtils.localize()` will return the string unchanged (missing-key fallback returns the input as-is). This means unlocalized signposts degrade gracefully rather than crashing.

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
| Chinese (Simplified) | `zh_CN` | Requires CJK font (`fnt_cjk.otf`) | 1.1 |
| Japanese | `ja` | Requires CJK font (`fnt_cjk.otf`) | 1.1 |

CJK locales automatically set `ui_scale_override` to `1.1` in the reducer when the locale changes to `zh_CN` or `ja`, and reset it to `1.0` for Latin locales.

## Dyslexia Font System

### Font Asset

- Default font: `assets/fonts/fnt_ui_default.ttf`
- Dyslexia font: `assets/fonts/fnt_dyslexia.ttf` (OpenDyslexic or equivalent)
- CJK font: `assets/fonts/fnt_cjk.otf` (covers CJK Unified Ideographs for `zh_CN` and `ja`)

### Application Pattern

`U_LocalizationFontApplier` owns locale-to-font resolution and theme application. `M_LocalizationManager` delegates to helper APIs:

```gdscript
# In manager startup
_font_applier.load_fonts()

# On locale/font setting updates
var theme := _font_applier.build_theme(_active_locale, _dyslexia_enabled)
for root in _root_registry.get_live_roots():
    _font_applier.apply_theme_to_root(root, theme)
```

### CJK Font Override

When locale is `zh_CN` or `ja`, the default and dyslexia fonts are replaced with `fnt_cjk.otf` regardless of the dyslexia toggle (CJK font takes priority for correct glyph coverage).

### Locale Change Notification Contract

When the active locale changes, `M_LocalizationManager` calls `_on_locale_changed(locale: StringName)` on every registered UI root that implements the method. UI panels that display translated text should implement this method to re-query `U_LocalizationUtils.localize()` on all their labels:

```gdscript
# In any UI panel that displays localized text:
func _on_locale_changed(_locale: StringName) -> void:
    _title_label.text = U_LocalizationUtils.localize(&"settings.audio.title")
    _back_button.text = U_LocalizationUtils.localize(&"common.back")
```

Panels that do NOT display localized text (e.g., purely visual widgets) do not need this method. The HUD controller uses a separate `_on_slice_updated` path (listening for the `localization` slice) instead of `_on_locale_changed`.

## File Structure

```text
scripts/managers/
  m_localization_manager.gd

scripts/interfaces/
  i_localization_manager.gd

scripts/managers/helpers/
  u_locale_file_loader.gd        # Compatibility shim
  localization/u_localization_catalog.gd   # Catalog merge + cache + fallback helper
  localization/u_localization_font_applier.gd   # Font selection + theme application helper
  localization/u_localization_root_registry.gd  # Root lifecycle + locale notification helper
  localization/u_localization_preview_controller.gd  # Preview lifecycle + store-update gating helper

scripts/utils/localization/
  u_localization_utils.gd        # Static localize() and localize_fmt() helpers; register_ui_root()

scripts/state/
  actions/u_localization_actions.gd
  reducers/u_localization_reducer.gd
  selectors/u_localization_selectors.gd

scripts/resources/state/
  rs_localization_initial_state.gd

assets/fonts/
  fnt_ui_default.ttf
  fnt_dyslexia.ttf
  fnt_cjk.otf

resources/localization/
  cfg_locale_en_ui.tres
  cfg_locale_en_hud.tres
  cfg_locale_es_ui.tres
  cfg_locale_es_hud.tres
  cfg_locale_pt_ui.tres
  cfg_locale_pt_hud.tres
  cfg_locale_zh_CN_ui.tres
  cfg_locale_zh_CN_hud.tres
  cfg_locale_ja_ui.tres
  cfg_locale_ja_hud.tres

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
- **Editing flow**: preview values apply live through `set_localization_preview(...)`; Redux is updated on explicit Apply/Reset, and Cancel discards pending edits.
- **Locale confirmation flow**: locale changes use a confirm timer; cancel/timeout reverts to previous locale.

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
- `U_LocalizationCatalog`: Merge logic for `.tres` catalogs, duplicate key resolution (last resource wins), fallback chain, cache invalidation.
- `U_LocalizationFontApplier`: Locale-aware font selection and root theme application behavior.
- `U_LocalizationRootRegistry`: Root registration/unregistration, dead-node pruning, locale notification behavior.
- `U_LocalizationPreviewController`: Preview lifecycle, store-update gating, and effective preview value resolution.

### Integration Tests

- Locale switch → verify `U_LocalizationUtils.localize()` returns correct string for new locale.
- Dyslexia toggle → verify font override applied to all registered UI roots.
- CJK locale → verify `fnt_cjk.otf` override and locale-driven effective UI scale via `M_DisplayManager` (`ui_scale_override = 1.1`).
- Settings persistence → dispatch locale action → reload global settings → verify locale restored.
- Missing key → verify `U_LocalizationUtils.localize("missing.key")` returns `"missing.key"` (key as fallback, no crash).

### Manual Testing

- Switch each language from the settings panel; confirm all UI labels update immediately.
- Enable dyslexia font; confirm font changes throughout menus and HUD.
- Switch to `zh_CN` and `ja`; confirm CJK glyphs render without missing squares.
- Load game with a saved locale; confirm correct locale applied on boot.

## Resolved Questions

| Question | Decision |
| -------- | -------- |
| Godot built-in Translation vs Resource catalogs | `.tres` catalogs via `U_LocalizationCatalog` (preloaded resources); no TranslationServer |
| Single file vs domain files | Two resources per locale (`cfg_locale_*_ui.tres`, `cfg_locale_*_hud.tres`); merged into one dictionary at runtime |
| Missing key behavior | Return the key string as-is (no crash, visible in UI for easy debugging) |
| CJK font strategy | Single shared `fnt_cjk.otf`; overrides dyslexia toggle for CJK locales |
| Dyslexia font scope | Project-level theme override on all registered UI roots (same pattern as UIScaleRoot) |
| Persistence | `localization` slice persists to `user://global_settings.json` via global settings serialization/applier |
| RTL support | Out of scope; not planned |
| Pluralization | Out of scope; simple key→string only |
