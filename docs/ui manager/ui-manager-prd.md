# Feature Specification: UI Navigation & Manager System

**Feature Branch**: `ui-manager`
**Created**: 2025-11-24
**Status**: Draft
**Input**: User description: "UI / Menu handling as well‑architected as the rest of the codebase (Gamepad Controllable, Modular UI, Data‑Driven, Everything still works)"

## Problem Statement

The current UI and menu handling is built on a solid Scene Manager, State Store, and Input Manager foundation, but the UI layer itself is more ad‑hoc than the rest of the architecture:

- Individual UI scenes call `M_SceneManager` directly for transitions and overlays.
- The `menu` slice exists and is tested, but real menus do not yet use it as their source of truth.
- Overlay behavior (push vs push_with_return, pop vs pop_with_return) and ESC / gamepad back semantics are encoded in multiple controllers instead of one central policy.
- Gamepad support exists at the input layer, but there is no unified, declarative model for UI routing that is as clean as the Redux + ECS patterns elsewhere.

We need a UI / Navigation architecture that:

- Treats UI location and menu flow as first‑class state with reducers and selectors.
- Uses declarative data (resources) to describe screens, overlays, and panels.
- Lets `M_SceneManager` act as a reactive enforcer of desired UI state, not the sole owner of navigation logic.
- Keeps UI panels dumb, testable views that read state and dispatch actions, supporting keyboard, mouse, and gamepad uniformly.
- Preserves all existing behaviors (main menu → gameplay → pause → endgame flows) while enabling future modular UI features.

## Goals

1. **Gamepad Controllable UI**
   - All menus, overlays, and settings flows must be fully navigable via gamepad using the existing Input Manager + device detection patterns.
   - ESC / gamepad “back” semantics must be consistent and defined centrally, not per‑scene.

2. **Modular UI**
   - Break UI into reusable panels and overlays that can be composed in different shells (main menu, pause overlay, endgame screens) without duplicating logic.
   - Allow new flows (e.g., inventory, map, quest log) to be added primarily by defining state, panels, and registry entries—not by rewriting managers.

3. **Data‑Driven Navigation**
   - Define a navigation / UI state slice that fully models UI location (base scene, overlays, menu panels).
   - Introduce a UI registry (resource‑backed) describing screens/overlays/panels, their scene paths, contexts, and close behavior.
   - Move navigation rules into reducers + registry lookups so behavior is visible and testable outside the scene tree.

4. **Compatibility: Everything Still Works**
   - Preserve existing user‑visible flows:
     - Main menu → gameplay hub → pause → settings / input flows → resume.
     - Door‑based area transitions (exterior ↔ interior).
     - Endgame flows (death → game over, victory → credits → main menu).
   - Keep current Scene Manager responsibilities intact (transition queue, async loading, camera/spawn managers, pause, HUD hiding).
   - Do not regress existing tests and acceptance criteria for Scene Manager, State Store, and Input Manager.

## Non-Goals

- Replace or radically redesign `M_SceneManager`, `M_SpawnManager`, or `M_CameraManager`.
- Introduce autoload singletons for UI; managers must remain scene‑based and discoverable via groups.
- Implement a generic in‑editor menu authoring tool; the focus is on runtime architecture, not editor UX.
- Redesign the visual look or layout of existing menus and HUD; this is primarily about flow and architecture.

## User Experience Notes

**Primary Entry Points**

- **Game Launch**
  - Player starts the game and arrives at the Main Menu.
  - Gamepad, keyboard, and mouse can all navigate the menu.
  - “Play” starts or continues a run; “Settings” opens a settings panel; “Quit” exits.

- **In‑Game Pause**
  - Player presses pause (ESC / gamepad Start) in gameplay.
  - Pause overlay appears over gameplay; gameplay freezes.
  - From pause, player can:
    - Resume gameplay.
    - Open settings, input profiles, gamepad/touchscreen settings, or rebinding.
    - Return to main menu or quit to desktop, as currently implemented.

- **Endgame**
  - On death, the game over screen appears with death count and options to retry or return to menu.
  - On victory, the victory screen appears with completion stats and options to continue, view credits, or return to menu.
  - Credits screen auto‑scrolls and returns to main menu or can be skipped via a button.

**Critical Interactions**

- **Gamepad Navigation**
  - D‑pad / left stick moves focus between buttons and controls using `ui_*` actions.
  - “Confirm” (A / Cross / Enter) activates the focused control.
  - “Back” (B / Circle / ESC) behaves consistently:
    - In gameplay: opens pause.
    - In pause: closes pause to gameplay.
    - In pause sub‑overlays tagged as “return overlays” (settings, input settings, rebinding): close to previous overlay (pause).
    - In main menu panels: navigates back within the menu, not to gameplay.

- **Device Switching**
  - When the active device switches between keyboard/mouse and gamepad, prompts and focus behavior update automatically based on `M_InputDeviceManager` and existing selectors.

- **HUD Interaction**
  - HUD remains responsive and non‑blocking during gameplay.
  - HUD hides during loading screen transitions and does not overlap with modal overlays in ways that confuse input or readability.

## Technical Considerations

### Core Architecture

The target architecture:

- A **navigation / UI state slice** that fully models:
  - Base scene (`current_scene_id`, shell).
  - Overlay stack (by logical IDs).
  - Active menu panel(s) within shells like main menu and pause.
- A **data‑driven UI registry** describing:
  - Screens, overlays, and panels (IDs, scene paths, kinds, allowed contexts, close behavior).
  - Optionally recommended focus nodes for gamepad navigation.
- `M_SceneManager` as a **reactive enforcer**:
  - Reads navigation + scene slices.
  - Ensures the scene tree (ActiveSceneContainer + UIOverlayStack) matches the desired state (transitions, overlays, loading).
  - Keeps all existing responsibilities (queueing, async loading, camera/spawn/pause integration).
- **UI panels as dumb views**:
  - Panels read slices via selectors (menu, settings, input, gameplay).
  - Panels dispatch actions (menu, settings, navigation), but never call Scene Manager directly.
- A **thin UI input handler**:
  - Listens to `ui_*` actions (keyboard + gamepad) and dispatches navigation actions based on context (navigation slice + scene type).
  - Delegates device detection to `M_InputDeviceManager` and Input Manager selectors.

### Dependencies

- **State Store**: `M_StateStore`, existing slices (`scene`, `menu`, `settings`, `input`, `gameplay`, `debug`).
- **Scene Manager**: `M_SceneManager`, `U_SceneRegistry`, Transition effects (Fade, Loading).
- **Input Manager**: `M_InputDeviceManager`, `M_InputProfileManager`, `U_InputSelectors`, `U_InputActions`, virtual controls architecture.
- **HUD**: `hud_overlay.tscn`, `hud_controller.gd`, HUD group (`hud_layers`) and loading transition HUD hide/restore behavior.

### Risks / Mitigations

- **Risk: Double source of truth for navigation**
  - Mitigation: Clearly define the navigation slice as the only logical source of truth. `M_SceneManager` is an enforcer/view that never mutates navigation fields on its own—only in response to actions.

- **Risk: Regression in existing flows**
  - Mitigation: Introduce navigation slice and registry behind feature flags or incremental wiring. Maintain existing Scene Manager APIs; add tests for both old and new flows, then gradually migrate call sites.

- **Risk: Over‑engineering the registry**
  - Mitigation: Start small: describe only existing screens/overlays, with minimal fields (id, path, kind, close_mode). Expand only when needed.

## Success Metrics

- **Functional**
  - All existing UI flows (main menu, pause, settings, input overlays, endgame) operate as before, with no regressions in manual QA.
  - Gamepad control works end‑to‑end across all menus and overlays.

- **Architectural**
  - Navigation logic lives primarily in reducers + registry, not scattered across controllers.
  - New UI flows (e.g., adding an inventory overlay) can be implemented primarily by:
    - Adding registry entries.
    - Adding/using panels.
    - Extending reducers and selectors.
    - With minimal or no changes to `M_SceneManager`.

- **Testing**
  - New unit tests for navigation reducers, selectors, and registry integration.
  - New integration tests verifying scene/overlay stacks for key flows.

## Unified Settings Panel

### Overview

All input-related settings are consolidated into a single unified settings panel with tabbed sections. This panel is accessible from both the main menu (as an embedded panel) and the pause menu (as an overlay), providing a consistent settings experience across contexts.

### Architecture

**Base Class**: `SettingsPanel` extends `BaseMenuScreen`
- Inherits `AnalogStickRepeater` for smooth gamepad navigation (held-stick repeat behavior)
- Supports dual contexts (main menu panel / pause overlay) without special handling

**Tab Structure**: Single-level tabs for Input settings (Phase 1)
```
[Input Profiles] [Gamepad] [Touchscreen] [Keyboard/Mouse]
```

**Tab Content**: Plain `Control` nodes (do NOT extend `BaseMenuScreen`)
- Parent `SettingsPanel` handles all analog stick input via inherited repeater
- Tabs use `U_FocusConfigurator` for focus chain configuration
- Avoids nested analog repeater conflicts

**Radio Behavior**: `ButtonGroup` resource for tab mutual exclusivity
- Automatic visual state management (only one tab active)
- Connect to `ButtonGroup.pressed` signal for tab switching logic

### Tab Visibility Rules

**Device-Based Filtering**:
- **Input Profiles tab**: Always visible (all devices)
- **Gamepad tab**: Visible only when `M_InputDeviceManager.DeviceType.GAMEPAD` active
- **Touchscreen tab**: Visible only when `DeviceType.TOUCHSCREEN` active
- **Keyboard/Mouse tab**: Visible when keyboard, mouse, or combined device active

**Device Switch Behavior**:
- Silent auto-switch to first visible tab (no toast notification)
- Focus transfers to first focusable control in new tab
- Critical: `_focus_first_control_in_active_tab()` must be called after device switch

### Tab Content Details

#### Input Profiles Tab
- Profile cycling buttons (up/down to cycle, button to apply)
- Binding preview showing effective action mappings for selected profile
- Auto-save: Profile switches dispatch immediately to Redux
- No Apply/Cancel buttons (consistent with auto-save pattern)

#### Gamepad Tab
- Left/right stick deadzone sliders
- Vibration enable/disable toggle
- Vibration intensity slider
- Interactive stick preview for testing
- Auto-save: Slider changes dispatch immediately
- No Apply/Cancel buttons

#### Touchscreen Tab
- Virtual joystick size/opacity sliders
- Button size/opacity sliders
- Joystick deadzone slider
- Live preview showing button layout
- "Edit Layout" button → opens `edit_touch_controls_overlay` (modal)
- Auto-save: Slider changes dispatch immediately
- No Apply/Cancel buttons

#### Keyboard/Mouse Tab
- "Rebind Controls" button → opens `input_rebinding_overlay` (modal)
- Placeholder for future mouse sensitivity slider
- Minimal UI (one button initially)

### Focus Management

**Tab Switching Focus Flow**:
1. User presses R1/L1 (shoulder buttons) or clicks tab button
2. `SettingsPanel` catches `ui_focus_next`/`ui_focus_prev` or button press
3. `ButtonGroup` automatically updates button states (radio behavior)
4. `_activate_tab()` hides old content, shows new content
5. **Critical**: `_focus_first_control_in_active_tab()` transfers focus to new tab
6. Must `await get_tree().process_frame` before focusing (ensure visibility)

**Device Switch Focus Flow**:
1. `M_InputDeviceManager` detects device change
2. `SettingsPanel` receives device change signal
3. `_update_tab_visibility()` hides/shows tabs per device
4. If active tab becomes hidden, `_switch_to_first_visible_tab()`
5. **Critical**: `_focus_first_control_in_active_tab()` re-establishes focus

### Input Actions

**New Actions Required** (add to `project.godot`):
```ini
ui_focus_prev={
  "deadzone": 0.2,
  "events": [
    InputEventJoypadButton(button_index=9),  # L1/LB shoulder
    InputEventKey(keycode=4194323)            # Page Up (keyboard fallback)
  ]
}
ui_focus_next={
  "deadzone": 0.2,
  "events": [
    InputEventJoypadButton(button_index=10), # R1/RB shoulder
    InputEventKey(keycode=4194324)            # Page Down (keyboard fallback)
  ]
}
```

### Dual Context Integration

**Main Menu Context**:
- Settings panel shown when `navigation.active_menu_panel == "menu/settings"`
- Back button dispatches `NAV/SET_MENU_PANEL("menu/main")`
- Normal process mode (not PROCESS_MODE_ALWAYS)
- Panel blends with menu background

**Pause Menu Context**:
- Settings panel embedded in `settings_menu_overlay`
- Back button dispatches `NAV/CLOSE_TOP_OVERLAY` (returns to pause)
- Parent overlay provides PROCESS_MODE_ALWAYS + background dimming
- Panel works identically to main menu context (context-agnostic design)

### Anti-Patterns

**❌ WRONG - Tab panels extend BaseMenuScreen**:
```gdscript
# scripts/ui/panels/gamepad_tab.gd
extends BaseMenuScreen  # Creates nested AnalogStickRepeater conflict!
```

**✅ CORRECT - Tab panels extend Control**:
```gdscript
extends Control
const U_FocusConfigurator := preload("...")
func _ready():
    _configure_focus_neighbors()  # Use helper, not custom repeater
```

**❌ WRONG - Apply/Cancel buttons**:
```gdscript
func _on_apply_pressed():
    # Batch save all changes
```

**✅ CORRECT - Auto-save pattern**:
```gdscript
func _on_slider_changed(value: float):
    store.dispatch(U_InputActions.update_setting("key", value))
    # ✅ Saved immediately to Redux
```

### Future Scalability (Phase 2+)

**Category → Sub-Tab Architecture**:
When adding Audio/Graphics/Accessibility settings, refactor to two-level hierarchy:

```
[Input] [Audio] [Graphics] [Accessibility]
   ^top-level category tabs^

When Input selected:
  [Profiles] [Gamepad] [Touch] [KB/Mouse]
       ^device-specific sub-tabs^
```

Current implementation uses single-level tabs to keep Phase 1 simple. Future refactor will nest tabs under categories without breaking existing panel components.

## Open Questions

- Should we introduce a dedicated `navigation` slice, or extend the existing `scene` + `menu` slices with navigation fields and adopt a clear ownership model? ✅ **RESOLVED**: Dedicated navigation slice implemented
- How much of the current `scene.scene_stack` semantics should be preserved exactly vs refactored to be fully driven by navigation reducers? ✅ **RESOLVED**: Flattened overlay architecture (T079) with return stack for navigation
- Do we want a separate continuation prompt and phases for "UI Manager / Navigation" similar to Scene Manager and Input Manager, or keep this as a sub‑phase of Scene Manager evolution? ✅ **RESOLVED**: Separate UI Manager phases complete

