# Input Manager File Structure

## Overview

This document captures the agreed-upon directory layout for the Input Manager initiative (Phases 0‑7). It builds on the conventions in `AGENTS.md`, `DEV_PITFALLS.md`, and the Style Guide so every new script, resource, scene, and test lands in the expected location. Use this as the single source of truth when creating files referenced by the plan/PRD.

```
scripts/
├── ecs/
│   ├── components/
│   ├── systems/
│   └── resources/
├── managers/
├── state/
│   ├── actions/
│   ├── reducers/
│   ├── selectors/
│   └── utils/
├── ui/
└── prototypes/
resources/
├── input/
├── state/
└── triggers/
scenes/
├── ui/
└── gameplay/
tests/
├── unit/
│   ├── input/
│   ├── managers/
│   ├── ecs/
│   └── ui/
└── integration/
```

## Scripts

### Managers (`scripts/managers`)
- `m_input_profile_manager.gd` – Loads/activates `RS_InputProfile`, applies bindings to `InputMap`, exposes profile APIs, emits `profile_switched`.
- `m_input_device_manager.gd` – Detects active device, tracks last-used device, emits device-change signals, updates HUD prompt state.
- Both managers live under `Managers` in `scenes/root.tscn` (siblings to `M_StateStore`/`M_SceneManager`) and join groups `"input_profile_manager"` / `"input_device_manager"`.

### ECS Components (`scripts/ecs/components`)
- `c_input_component.gd` – Existing keyboard/mouse component (extended but stays in place).
- `c_gamepad_component.gd` – Stores per-device state (axes, buttons, vibration flags).
- `c_touch_input_component.gd` – Captures virtual joystick/button metrics for mobile.

### ECS Systems (`scripts/ecs/systems`)
- `s_input_system.gd` – Enhanced keyboard/mouse/gamepad capture, dispatches Redux actions.
- `s_touchscreen_system.gd` – Reads virtual control nodes, updates `C_TouchInputComponent`.
- `s_input_feedback_system.gd` (Phase 4+) – Routes vibration/tactile feedback to devices.

### Resources (`scripts/ecs/resources`)
- `rs_input_profile.gd` – Defines bindings + metadata for a profile.
- `rs_gamepad_settings.gd` – Deadzones, sensitivity, vibration curves.
- `rs_touchscreen_settings.gd` – Virtual joystick layout, opacity, drag zones.
- `rs_rebind_settings.gd` – Constraints for runtime rebinding (conflict policies, reserved actions).
- Resource `.tres` instances live under `resources/input/…`.

### State Layer (`scripts/state`)
- `actions/u_input_actions.gd` – Existing gameplay slice actions.
- `actions/u_input_settings_actions.gd` – Persistent settings actions (profiles, sensitivity).
- `reducers/u_gameplay_reducer.gd` – Already handles gameplay input values; keep updates here.
- `reducers/u_input_settings_reducer.gd` – New persistent slice for profile metadata + user preferences.
- `selectors/u_input_selectors.gd` – Existing file (extend as needed).
- `selectors/u_input_settings_selectors.gd` – Accessors for settings slice.
- `utils/u_input_serialization.gd` – Handles read/write of `user://input_settings.json`.

### UI + Utilities
- `scripts/ui/input_prompts/u_button_prompt_registry.gd` – Maps logical actions to prompt textures.
- `scripts/ui/mobile_controls/virtual_joystick.gd` / `virtual_button.gd` – Control scripts instanced in `mobile_controls.tscn`.
- Prototypes stay under `tests/prototypes/` (already housing gamepad, touch, latency, InputMap research helpers).

## Scenes & UI

### Root Scene (`scenes/root.tscn`)
- Add `M_InputProfileManager` and `M_InputDeviceManager` under `Managers`.
- Ensure both nodes call `process_mode = PROCESS_MODE_ALWAYS` so device detection/profile updates run during pause/transition windows.

### UI Scenes (`scenes/ui`)
- `input_settings_menu.tscn` – Main rebinding/profile UI (desktop).
- `input_profile_selector.tscn` – Overlay for quick profile switching.
- `controller_prompts_overlay.tscn` – CanvasLayer that listens for `device_changed` and updates button icons.
- `mobile_controls.tscn` – Virtual joystick/buttons (duplicated per scene where `OS.has_feature("mobile")`).

### Gameplay Scenes
- No new gameplay scenes are created for this feature; existing scenes consume the new managers/components automatically.

## Resources & Assets

- `resources/input/profiles/*.tres` – Built-in `RS_InputProfile` assets (default, accessibility, gamepad).
- `resources/input/gamepad_settings/*.tres` – `RS_GamepadSettings` variants per device family.
- `resources/input/touch/*.tres` – `RS_TouchscreenSettings` presets (phone/tablet layout).
- `resources/ui/button_prompts/` – PNG textures sourced from the Kenney Input Prompts pack (64×64). Reference them via `Texture2D` in prompt registry.
- `resources/state/default_input_settings_state.tres` – Initial state used by `M_StateStore` when creating the settings slice.

## Tests

### Unit Tests (`tests/unit`)
- `tests/unit/managers/test_m_input_profile_manager.gd` – Profile loading, switching, InputMap updates.
- `tests/unit/managers/test_m_input_device_manager.gd` – Device detection, signal emission, debounce logic.
- `tests/unit/ecs/components/test_c_gamepad_component.gd` – Snapshot and registration behavior.
- `tests/unit/ecs/systems/test_s_touchscreen_system.gd` – Virtual control ingestion.
- `tests/unit/state/test_u_input_settings_reducer.gd` / `test_u_input_settings_actions.gd`.
- `tests/unit/ui/test_u_button_prompt_registry.gd` – Asset lookup + fallback rules.
- Prototypes keep their suites under `tests/unit/prototypes/`.

### Integration Tests (`tests/integration`)
- `tests/integration/input/test_profile_switching_flow.gd` – Simulates switching profiles + confirming InputMap updates.
- `tests/integration/input/test_device_prompt_updates.gd` – Ensures HUD switches prompts when active device changes.

## Persistence & Data

- Input settings JSON path: `user://input_settings.json` (managed by `u_input_serialization.gd`).
- State slices:
  - `gameplay.input` – transient actions (move/look/jump) already covered.
  - `settings.input_settings` – persistent overrides (active profile id, custom bindings, sensitivity).
- When adding new fields, update:
  1. `resources/state/default_input_settings_state.tres`
  2. `u_input_settings_reducer.gd` defaults
  3. Serialization schema version in `u_input_serialization.gd`

## Notes

- No new `scripts/input/` directory—place files within existing prefixes (components, systems, managers, state, ui).
- Keep `.tres` resources referencing their script via `script = ExtResource(...)` to satisfy style enforcement tests.
- Each phase completion requires updates to this document if the file layout changes.
