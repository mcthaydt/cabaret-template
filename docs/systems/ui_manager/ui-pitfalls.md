# UI Pitfalls

UI pitfalls collected from the legacy developer pitfalls guide. Keep this file focused on UI Manager, navigation, focus, settings, and UI/Input ownership boundaries.

## UI/Input Boundary

The Input Manager and UI Manager have clear, separated responsibilities. Violating this boundary causes double-handling, race conditions, and unpredictable pause behavior.

Input Manager owns:

- hardware-to-action mapping for keyboard, gamepad, and touch;
- active device detection through `M_InputDeviceManager`;
- action context based on device capabilities;
- rebinding through `M_InputProfileManager` and Redux state.

Input Manager does not:

- make UI navigation decisions;
- call `M_SceneManager.push_overlay()` or `pop_overlay()`;
- handle ESC/pause keys to toggle pause state;
- know about navigation slice UI flow.

UI Manager owns:

- `navigation` slice state for shells, overlays, and panels;
- UI flow logic for pause, overlay return/resume behavior, and active panels;
- navigation actions through `U_NavigationActions`;
- scene-tree reconciliation through `M_SceneManager`.

UI Manager does not:

- read raw `InputEventKey` / `InputEventJoypadButton` for ESC/pause detection;
- map hardware buttons to actions;
- directly control cursor lock/visibility.

Correct pause flow:

1. `M_UIInputHandler` or a virtual button dispatches `U_NavigationActions.open_pause()`.
2. Navigation reducer updates overlay state.
3. `M_SceneManager` reconciles overlays and scene stack.
4. `M_TimeManager` sees scene/overlay state and applies engine pause.

Common mistakes:

- Do not add pause logic to both Input Manager systems and UI controllers.
- Do not call `M_SceneManager.push_overlay()` directly from UI controllers.
- Do not check `Input.is_action_pressed("ui_cancel")` in UI scripts.
- Do not assume overlays push immediately during base-scene transitions; reconciliation may be deferred.

Testing pattern:

```gdscript
_store.navigation_initial_state = RS_NavigationInitialState.new()
_store.dispatch(U_NavigationActions.open_pause())
await wait_physics_frames(2)
```

## Time Manager Initialization

`M_TimeManager` must initialize synchronously enough to subscribe to state updates before `M_SceneManager` syncs overlay state. Async initialization can miss initial state changes and leave `get_tree().paused` out of sync.

Fix pattern:

- get the store synchronously in `_ready()` with `U_StateUtils.get_store(self)`;
- defer only if the store is unavailable;
- keep `_process()` resync polling as a backup against signal timing mismatches between state and actual overlay children.

## Store Access

Accessing the store in `_ready()` before it is registered can return `null`.

```gdscript
func _ready() -> void:
	await get_tree().process_frame
	var store := U_StateUtils.get_store(self)
```

Use this pattern in UI controllers that need store access during setup.

## Focus Sound Arming

`BasePanel` only plays focus sounds when a focus change was preceded by player navigation input. If a `BasePanel` subclass overrides `_input(event)`, it must call `super._input(event)` or keyboard/D-pad focus moves become silent.

## Deadzone Consistency

Inconsistent deadzone values between InputMap actions and device detection cause unpredictable gamepad navigation. Standardize UI navigation actions and device detection to `0.25`:

- `ui_up`, `ui_down`, `ui_left`, `ui_right` in `project.godot`;
- `M_InputDeviceManager.DEVICE_SWITCH_DEADZONE`.

Run `tests/unit/ui/test_joystick_navigation_deadzone.gd` after changing navigation input mappings.

## Explicit Focus Neighbors

Godot automatic focus neighbor calculation can be unreliable with complex UI layouts. Use `U_FocusConfigurator` for gamepad navigation:

- `configure_vertical_focus(...)` for menus and vertical lists;
- `configure_horizontal_focus(...)` for button rows;
- `configure_grid_focus(...)` for grid layouts.

Call `_configure_focus_neighbors()` after `@onready` vars are initialized and whenever visible controls change.

## Dynamic Visibility and Focus Chains

Focus configurators should receive visible controls only. If a hidden control remains in a neighbor chain, gamepad navigation can appear stuck or skip visible controls.

Fix pattern:

- filter focus lists by `control.visible`;
- rerun `_configure_focus_neighbors()` whenever runtime visibility changes;
- use the same pattern for bottom button bars and tab strips.

## Overlay Parent Validation

Opening an overlay without its required parent can fail or reconcile unexpectedly. Check navigation overlay state or open the parent first.

```gdscript
store.dispatch(U_NavigationActions.open_pause())
await get_tree().process_frame
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_panel")))
```

## Custom Overlay Navigation

Overlays that need non-standard left/right behavior, such as cycling profiles, must handle that behavior locally without letting parent repeaters process the same input.

Fix pattern:

- override `_navigate_focus(direction: StringName)` only for custom directions;
- return early after handling custom input;
- use default/super navigation for normal focus movement;
- avoid wiring focus neighbors that send parent navigation into the same custom path.

## Stateful Rebind Navigation

Overlays that keep navigation indices can drift out of sync with real focus.

Fix pattern:

- add a focus-sync hook that recomputes internal indices from the focused control;
- call it from row/container/button `focus_entered` handlers;
- keep `_unhandled_key_input(...)` from hijacking arrow keys while `LineEdit` search fields are focused.

Relevant files:

- `scripts/core/ui/overlays/ui_input_rebinding_overlay.gd`
- `scripts/core/ui/helpers/u_rebind_focus_navigation.gd`

## Await Before Wiring Signals

Awaiting before connecting critical UI signals can leave a one-frame window where buttons emit `pressed` with no listener.

Fix pattern:

- connect buttons/toggles at the top of `_ready()` / `_on_panel_ready()`;
- make handlers lazily resolve dependencies if async setup is still settling;
- populate required state defensively before acting.

## Panel Filtering

Main menu controllers can accidentally respond to pause-menu panel updates if they read shared `active_menu_panel` state without filtering.

```gdscript
func _on_panel_changed(panel_id: StringName) -> void:
	if not panel_id.begins_with("menu/"):
		return
	_show_panel(panel_id)
```

## Direct Scene Manager Calls

UI controllers must dispatch navigation actions instead of calling `M_SceneManager` directly.

```gdscript
store.dispatch(U_NavigationActions.open_pause())
```

## Overlay Process Mode

Overlays freeze when the tree is paused unless they use `PROCESS_MODE_ALWAYS`. `BaseOverlay` sets this automatically; custom overlays should not override it incorrectly.

## Pause State Detection

Use `U_NavigationSelectors.is_paused(state)` for pause state. Do not infer pause from `scene.scene_stack` or `get_tree().paused` in UI code.

## Unified Settings Base Classes

Tab panels extending `BaseMenuScreen` create nested `U_AnalogStickRepeater` conflicts.

Correct structure:

- parent `SettingsPanel` extends `BaseMenuScreen`;
- child tab panels extend plain `Control`;
- child tabs configure focus with `U_FocusConfigurator`.

## Settings Button Groups

Manual tab button state management is error-prone. Use Godot `ButtonGroup` for tab radio behavior so only one tab button is pressed at a time.

## Settings Focus Transfer

After a tab switch, focus should move to the first focusable control in the new tab after visibility settles.

```gdscript
await get_tree().process_frame
var first_focusable := _get_first_focusable_in_active_tab()
if first_focusable:
	first_focusable.grab_focus()
```

If a device switch hides the active tab, switch to the first visible tab and re-establish focus.

## Settings Persistence Pattern

Default to auto-save for simple, low-risk settings where each control maps cleanly to a single action.

Use Apply/Cancel when changes should be atomic across multiple fields, involve preview/test mode, or are disruptive enough to require confirmation. If using Apply/Cancel, guard against external state updates overwriting local edits while the overlay is open.

## State Store Subscribe Signature

`M_StateStore.subscribe()` callbacks receive two arguments: `(action, state)`. UI callbacks must match that signature.

```gdscript
func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	pass
```

## Tab Content Navigation

Tab content should use `U_FocusConfigurator` for focus chains and let the parent handle analog navigation. Do not override `_navigate_focus()` in tab content unless the override is specifically required and isolated.

## Missing Tab Switch Actions

Shoulder-button tab switching needs `ui_focus_prev` and `ui_focus_next` in `project.godot` before tab cycling is implemented.

Typical bindings:

- `ui_focus_prev`: L1/LB and Page Up
- `ui_focus_next`: R1/RB and Page Down
