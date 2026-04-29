# ADR-0013: UI Menu/Settings Builder Pattern

**Status**: Accepted

## Context

During Cleanup V8 Phase 8, settings tabs and menu screens were using `@onready`-heavy scripts with inline theme overrides, duplicated `_localize_with_fallback()` methods (13 copies), and manual focus wiring. The goals were:

1. **LLM-friendly**: Builder APIs are easier for AI assistants to read and modify than scattered `@onready` + manual signal connections.
2. **DRY theme/localization/focus**: Eliminate duplicated localization helpers and theme token application.
3. **Headless-testable**: Builder logic testable in GUT without running editor.
4. **Consistent fallbacks**: Localization fallbacks for headless runs should produce human-readable text, not raw keys like `"common.cancel"`.

## Decision

Two fluent `RefCounted` builder classes provide the core API:
- `U_SettingsTabBuilder` — for settings tabs (bind existing controls or create new ones)
- `U_UIMenuBuilder` — for menu screens (bind existing buttons or create new ones)

Both builders share a common pattern:
1. **Constructor** takes the parent `Control`
2. **Fluent bind methods** register existing controls for theming, localization, and focus (`bind_heading`, `bind_field_label`, `bind_button`, etc.)
3. **Fluent create methods** create new controls and auto-register them (`add_dropdown`, `add_toggle`, `add_slider`, `add_button`, etc.)
4. **`build()`** applies theme tokens, localizes labels, and configures the vertical focus chain

### Localization deduplication

All 13 copies of `_localize_with_fallback(key, fallback)` were extracted into `U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)`. Builder `bind_*` methods accept an optional `fallback` parameter; when localization keys don't resolve (headless), the fallback text appears instead of the raw key string.

### Base settings consolidation

`BaseSettingsSimpleOverlay` was updated to use `U_SettingsTabBuilder.bind_panel()` for panel/content theming, replacing its inline `_apply_theme_tokens()` with `_apply_overlay_theme()` (dim background only).

## Alternatives

| Alternative | Why Rejected |
|---|---|
| Keep `@onready` + manual wiring | Duplicated localization, no headless test coverage, LLM-unfriendly |
| Use `U_UIThemeBuilder` directly in every script | No focus or localization wiring; builder provides all three in one call |
| Create nodes entirely in builder (no `.tscn`) | Premature; `bind` pattern allows incremental migration |
| Put `_localize_with_fallback` on each script | 13 copies violated DRY; shared utility ensures consistent fallback behavior |

## Consequences

- **Positive**: 13 copies of `_localize_with_fallback` eliminated. All UI scripts use `U_LOCALIZATION_UTILS.localize_with_fallback`.
- **Positive**: Builder LOC caps enforce modularity (SettingsTabBuilder ≤300, UIMenuBuilder ≤200, SettingsCatalog ≤150).
- **Positive**: `bind_panel()` allows `BaseSettingsSimpleOverlay` to delegate panel theming to the builder.
- **Tradeoff**: `bind` approach retains `@onready` vars in scripts; full node creation by the builder would eliminate them but requires more extensive scene restructuring.
- **Tradeoff**: Builders store `_label_fallbacks` dict alongside `_label_keys` for localization fallback; memory impact is negligible.

## References

- `scripts/core/ui/helpers/u_settings_tab_builder.gd`
- `scripts/core/ui/helpers/u_ui_menu_builder.gd`
- `scripts/core/ui/helpers/u_ui_settings_catalog.gd`
- `scripts/core/utils/localization/u_localization_utils.gd`
- `scripts/core/ui/settings/base_settings_simple_overlay.gd`
- `tests/unit/ui/menus/test_ui_menu_builder_integration.gd`
- `tests/unit/ui/helpers/test_u_settings_tab_builder.gd`