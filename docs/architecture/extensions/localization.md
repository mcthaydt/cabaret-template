# Add Localization Key / Language

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new localization key across all locales
- A new language (locale) with full translation files

This recipe does **not** cover:

- State slice creation (see `state.md`)
- Manager registration (see `managers.md`)
- UI screen authoring (see `ui.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md)

## Canonical Example

- Translation resource: `resources/core/localization/cfg_locale_en_ui.tres` (`RS_LocaleTranslations`)
- Catalog: `scripts/core/managers/helpers/localization/u_localization_catalog.gd`
- Utils: `scripts/core/utils/localization/u_localization_utils.gd`
- Language selector: `scripts/core/ui/menus/ui_language_selector.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `M_LocalizationManager` | Singleton. `set_locale()`, `translate()`, `register_ui_root()`. |
| `RS_LocaleTranslations` | Resource: `locale`, `domain`, `translations: Dictionary`. |
| `U_LocalizationCatalog` | Static: `SUPPORTED_LOCALES`, `load_catalog(locale)` merges requested locale onto `en` fallback. |
| `U_LocalizationUtils` | Static: `localize(key)`, `localize_fmt(key, args)`, `register_ui_root()`. |
| `U_LocalizationFontApplier` | Auto-selects CJK font for `zh_CN`/`ja`. |

Key domains: `ui` (menus/overlays), `hud` (in-world labels/prompts). Key prefixes: `menu.*`, `settings.*`, `hud.*`, `signpost.*`, `common.*`.

Supported locales: `en`, `es`, `pt`, `zh_CN`, `ja`.

## Recipe

### Adding a new localization key

1. Add the key to every locale's `translations` Dictionary in the appropriate domain resource files: `resources/core/localization/cfg_locale_{code}_ui.tres` or `cfg_locale_{code}_hud.tres`.
2. Follow key naming conventions: `menu.*`, `settings.*`, `hud.*`, `signpost.*`, `common.*`.
3. In UI code, resolve via `U_LocalizationUtils.localize(StringName("key_name"))` — never bare `tr(key)`.
4. Implement `_on_locale_changed(_locale: StringName)` on UI panels displaying the key, re-querying `localize()`.
5. No code changes needed in `U_LocalizationCatalog` or the manager — they auto-merge all keys from preloaded `.tres` files.

### Adding a new language

1. Create two `.tres` files: `resources/core/localization/cfg_locale_{code}_ui.tres` and `cfg_locale_{code}_hud.tres` using `RS_LocaleTranslations`, with `locale` and `domain` set and all existing keys translated.
2. Add both to `U_LocalizationCatalog._LOCALE_RESOURCES` (const preload array).
3. Add locale code to `U_LocalizationCatalog.SUPPORTED_LOCALES`.
4. If CJK font handling needed: add scale override entry in `U_LocalizationReducer` (auto-sets `ui_scale_override` to `1.1`).
5. If CJK, ensure `fnt_cjk.otf` covers the glyphs. `U_LocalizationFontApplier` auto-selects for `zh_CN` and `ja`.
6. Add locale option to `scripts/core/ui/menus/ui_language_selector.gd`.

## Anti-patterns

- **Bare `tr(key)`**: Invokes Godot's `Object.tr()`, not the project system. Use `U_LocalizationUtils.localize(key)`.
- **Runtime directory scanning for locale files**: Breaks on Android/PCK. Must use const preload arrays.
- **Using Godot's `.po`/`TranslationServer` infrastructure**: Explicitly out of scope.
- **Missing key in a locale file**: Graceful fallback returns key string, but should be populated.
- **Direct state access to localization slice outside selectors/reducers**.
- **Adding locale codes without updating `SUPPORTED_LOCALES`**.

## Out Of Scope

- State slice: see `state.md`
- Manager registration: see `managers.md`
- UI screen: see `ui.md`

## References

- [Localization Manager Overview](../../systems/localization_manager/localization-manager-overview.md)