# Add UI Screen / Overlay / Panel

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new full-screen UI menu (extends `BaseMenuScreen`)
- A new overlay (extends `BaseOverlay`)
- A new settings tab
- A new embedded panel

This recipe does **not** cover:

- Manager registration (see `managers.md`)
- State slice creation (see `state.md`)
- Scene transitions (see `scenes.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md) (navigation via Redux, not direct manager calls)

## Canonical Example

- Overlay: `scripts/core/ui/menus/ui_pause_menu.gd` (extends `BaseOverlay`)
- Full-screen menu: `scripts/core/ui/menus/ui_main_menu.gd` (extends `BaseMenuScreen`)
- Screen definition: `resources/core/ui_screens/cfg_pause_menu_overlay.tres`
- Navigation actions: `scripts/core/state/actions/u_navigation_actions.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `BasePanel` | Base: store lookup, focus, back handling, motion set. |
| `BaseMenuScreen` | Full-screen: analog stick repeater, background shader. Extends `BasePanel`. |
| `BaseOverlay` | Overlay: `PROCESS_MODE_ALWAYS`, dim background, enter/exit animation. Extends `BaseMenuScreen`. |
| `RS_UIScreenDefinition` | Data resource: `screen_id`, `kind` (BASE_SCENE/OVERLAY/PANEL), `scene_id`, `allowed_shells`, `allowed_parents`, `close_mode`. |
| `U_UIRegistry` | Static registry of screen definitions. `const X := preload(...)` + `_register_definition()`. |
| `U_NavigationActions` | All UI state changes dispatch through here, never call `M_SceneManager` directly. |
| `U_UIThemeBuilder` | Token-based theming. No inline `theme_override_*` in `.tscn` files. |

`kind` enum: `BASE_SCENE=0`, `OVERLAY=1`, `PANEL=2`. `close_mode` enum: `RETURN_TO_PREVIOUS_OVERLAY=0`, `RESUME_TO_GAMEPLAY=1`, `RESUME_TO_MENU=2`.

## Recipe

### Adding a new overlay

1. Register scene in `U_SceneRegistry` with `SceneType.UI`.
2. Create `RS_UIScreenDefinition` `.tres` at `resources/core/ui_screens/cfg_<name>_overlay.tres`: set `screen_id`, `kind = OVERLAY`, `scene_id`, `allowed_shells`, `allowed_parents`, `close_mode`.
3. Preload in `U_UIRegistry`: add `const <NAME>_OVERLAY := preload(...)` and `_register_definition()` in `_register_all_screens()`.
4. Create script: `scripts/core/ui/<category>/ui_<name>.gd`, extend `BaseOverlay`, override `_on_panel_ready()` and `_on_back_pressed()`.
5. Create `.tscn` scene under `scenes/core/ui/overlays/`.
6. All button handlers dispatch `U_NavigationActions` — never call `M_SceneManager` directly.

### Adding a new full-screen screen

Same steps but: `kind = BASE_SCENE`, script extends `BaseMenuScreen`, navigate via `U_NavigationActions.navigate_to_ui_screen(screen_id)`.

### Adding a new panel

Same `.tres` pattern with `kind = PANEL`, no `scene_id`. Panels use `panel_id` format `"{context}/{name}"`. Switch via `U_NavigationActions.set_menu_panel(panel_id)`.

### Adding a new settings tab

Extend plain `Control` (not `BaseMenuScreen`), live under a `SettingsPanel` that extends `BaseMenuScreen`, use `ButtonGroup` for tab radio. Changes auto-save via immediate Redux dispatch.

Use `U_SettingsTabBuilder` in `_setup_builder()` to wire theming, localization, and focus:
```gdscript
func _setup_builder() -> void:
    _builder = U_SettingsTabBuilder.new(self)
    _builder.bind_heading(heading_label, &"settings.audio.title", "Audio") \
           .bind_action_button(cancel_button, &"common.cancel", _on_cancel_pressed, "Cancel") \
           .build()
```

### Adding a new menu screen with U_UIMenuBuilder

Use `U_UIMenuBuilder` in `_setup_menu_builder()` to wire theming, localization, and focus:
```gdscript
func _setup_menu_builder() -> void:
    _menu_builder = U_UIMenuBuilder.new(self)
    _menu_builder.bind_title(title_label, &"menu.main.title", "Main Menu") \
                  .bind_button_group([...]) \
                  .build()
```

## Anti-patterns

- **Calling `M_SceneManager.push_overlay()` from UI controllers**: Dispatch navigation actions instead.
- **Tab panels extending `BaseMenuScreen`**: Causes nested `U_AnalogStickRepeater` conflicts.
- **Inline `theme_override_*` in `.tscn` files**: Use `U_UIThemeBuilder` tokens in script.
- **Defining `_localize_with_fallback` in UI scripts**: Use `U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)` instead.
- **Manual focus neighbor wiring**: Use `U_FocusConfigurator` or builder `bind_*` methods.
- **Apply/Cancel buttons for simple settings**: Auto-save via immediate Redux dispatch.
- **Checking `Input.is_action_pressed("ui_cancel")` in UI scripts**: Use the action dispatch flow.
- **Overriding `PROCESS_MODE_ALWAYS`** on overlays: `BaseOverlay` sets this automatically.

## Out Of Scope

- Manager registration: see `managers.md`
- Scene transitions: see `scenes.md`
- State slice: see `state.md`

## References

- [ADR 0013: UI Menu/Settings Builder Pattern](../adr/0013-ui-menu-settings-builder-pattern.md)
- [UI Manager Overview](../../systems/ui_manager/ui-manager-overview.md)
- [UI Pitfalls](../../systems/ui_manager/ui-pitfalls.md)