# UI Manager Overview

The UI Manager architecture is state-first: UI controllers dispatch Redux navigation actions, the registry defines valid screens/overlays, and scene/UI managers enforce the state. UI scripts should not call `M_SceneManager` directly.

## Status

- Core UI Manager implementation is complete through Phase 6.
- Phase 7 UX refinements are partially complete.
- Task history lives in `docs/systems/ui_manager/ui-manager-tasks.md`.
- Flow details live in `docs/systems/ui_manager/general/`.

## Navigation State

- Dedicated Redux slice: `navigation`.
- Shells: `main_menu`, `gameplay`, `endgame`.
- Overlays: modal dialogs tracked through overlay state.
- Panels: embedded UI within shells, for example `menu/main` and `menu/settings`.
- Navigation state is transient and is not persisted in save/load data.

Use `U_NavigationSelectors` for reads. `U_NavigationSelectors.is_paused()` is the single source of truth for pause state.

## Navigation Actions

UI controllers dispatch navigation actions rather than calling scene-manager APIs directly.

```gdscript
const U_NavigationActions = preload("res://scripts/state/actions/u_navigation_actions.gd")

store.dispatch(U_NavigationActions.open_pause())
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
store.dispatch(U_NavigationActions.close_top_overlay())
store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
```

## UI Registry

- Screen definitions are resource-based and live in `resources/ui_screens/cfg_*.tres`.
- `RS_UIScreenDefinition` defines `screen_id`, `kind`, `scene_id`, `allowed_shells`, and `close_mode`.
- `U_UIRegistry` validates parent-child relationships and scene references.
- UI screen definitions are the authoritative data source for what can open in each shell.

## Base UI Classes

- `BasePanel`: store lookup, focus helpers, back button handling, optional `motion_set`.
- `BaseMenuScreen`: full-screen UI such as main menu and endgame; includes analog stick repeater behavior.
- `BaseOverlay`: modal dialogs; sets `PROCESS_MODE_ALWAYS` and manages background dimming.

Common contracts:

- UI controllers extend base classes and dispatch actions.
- Controllers subscribe to `slice_updated` for reactive updates.
- Controllers that access the store in `_ready()` should wait one frame first: `await get_tree().process_frame`.

## Theme Pipeline

`RS_UIThemeConfig` is the canonical theme contract. The default instance is `resources/ui/cfg_ui_theme_default.tres`.

`U_UIThemeBuilder` is the single composition point for UI themes:

- Input: base font theme from `U_LocalizationFontApplier`, optional `RS_UIColorPalette`, required `RS_UIThemeConfig`.
- Output: merged `Theme` containing fonts, text colors, spacing constants, and styleboxes.
- Runtime-default contract: call `RS_UIThemeConfig.ensure_runtime_defaults()` inside `U_UIThemeBuilder` before stylebox application so loaded config resources hydrate missing styleboxes consistently on mobile/export builds.

Root/theme lifecycle:

- `scripts/core/root.gd` sets `U_UIThemeBuilder.active_config` on enter/ready.
- Only the persistent app root (`Managers/M_StateStore` present) clears the active config on exit.
- Non-persistent gameplay roots must not clear global theme config.
- `U_DisplayUIThemeApplier` stores active palette state and rebuilds registered UI roots through `U_UIThemeBuilder` in unified mode.
- When `U_UIThemeBuilder.active_config` is `null`, localization and display theming keep legacy behavior.
- When unified mode is active and a palette has not been applied yet, `U_UIThemeBuilder` should still apply config text colors for roots missing explicit font colors while preserving existing base-theme colors.

Tokenization contracts:

- Settings tabs embedded inside settings wrappers apply spacing/typography tokens in script through `U_UIThemeBuilder.active_config` and `RS_UIThemeConfig`.
- `scenes/ui/hud/ui_hud_overlay.tscn` should not keep inline `theme_override_*` entries. Apply HUD margins/typography/surface tokens in `UI_HudController._apply_theme_tokens()`.
- `scenes/ui/hud/ui_button_prompt.tscn` should not keep inline `theme_override_*` entries. Apply prompt spacing/panel/typography tokens in `UI_ButtonPrompt._apply_theme_tokens()`.
- Do not reintroduce non-semantic `theme_override_*` lines in `scenes/ui/**`. `test_no_inline_theme_overrides_except_semantic` enforces this.

## Motion Pipeline

Motion resources are data-driven and opt-in.

- `RS_UIMotionPreset` defines one tween step: property, from/to, duration, delay, interval, transition/ease, and parallel flag.
- `RS_UIMotionSet` groups motion sequences by interaction: `enter`, `exit`, `hover_in/out`, `press`, `focus_in/out`, and `pulse`.
- Default authored presets live under `resources/ui/motions/` and are baseline feel, not hard requirements.

`U_UIMotion` is the canonical playback helper:

- `play(node, presets)` supports sequential steps by default, optional parallel steps, and interval-only hold steps.
- `play_enter(...)`, `play_exit(...)`, and `play_pulse(...)` delegate to `RS_UIMotionSet` lifecycle/interaction arrays.
- `append_step(tween, node, preset)` is the public single-step API for custom tween composition.
- `bind_interactive(control, motion_set)` wires hover/focus/press signals without duplicating existing connections.

Base-class integration:

- `BasePanel.motion_set` is opt-in; when set, focusable child controls are bound through `U_UIMotion.bind_interactive(...)`.
- `BaseMenuScreen.play_enter_animation()` and `play_exit_animation()` delegate to `U_UIMotion` using a resolved motion target:
  - explicit `motion_target_path` when exported/set,
  - otherwise auto-target `CenterContainer` when a backdrop and `PanelContainer` are present,
  - otherwise fallback to the screen root.
- Prefer the default backdrop-fade plus panel-slide behavior over per-screen motion overrides for centered panel screens.
- `BaseOverlay` animates its dim `OverlayBackground` alpha in parallel with content enter/exit motion.
- Prefer `background_color` plus auto-created `OverlayBackground`; avoid an extra full-screen `Background` `ColorRect` unless `auto_create_background = false`.
- `motion_set = null` must remain a strict no-op: no signal binding side effects and no tween playback.

HUD feedback motion is data-driven through `cfg_motion_hud_checkpoint_toast.tres`, `cfg_motion_hud_signpost_fade_in.tres`, and `cfg_motion_hud_signpost_fade_out.tres`. Avoid hardcoded HUD fade durations in `UI_HudController`.

## Settings Panel

The reusable settings architecture uses one navigation owner and plain tab content panels.

- `SettingsPanel` extends `BaseMenuScreen`.
- Tab content panels extend `Control`, not `BaseMenuScreen`.
- Use `ButtonGroup` for tab radio behavior.
- Settings changes auto-save by dispatching Redux actions immediately; do not add Apply/Cancel batching.
- Add/use `ui_focus_prev` and `ui_focus_next` for shoulder-button tab switching.

Focus rules:

- Tab switch transfers focus to the first control in the new tab after one process frame.
- Device switch should switch tab and refocus if the active tab becomes hidden.
- Tab content should use `U_FocusConfigurator` for focus chains, not custom `_navigate_focus()` overrides.

Avoid:

- tab panels extending `BaseMenuScreen`;
- manual button state management instead of `ButtonGroup`;
- Apply/Cancel buttons for settings;
- tab content overriding `_navigate_focus()` and conflicting with the parent repeater.

## Verification

- Navigation state: `tests/unit/state/test_navigation_state.gd`
- UI registry/screens: `tests/unit/ui/`
- Style guard: `tests/unit/style/test_style_enforcement.gd`
