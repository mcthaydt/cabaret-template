# Add Input Action / Profile

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new input action (e.g., `interact`, `sprint`)
- A new input profile (e.g., accessibility variant)
- A new input source device type

This recipe does **not** cover:

- ECS components/systems (see `ecs.md`)
- Manager registration (see `managers.md`)
- State slice creation (see `state.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md)

## Canonical Example

- Bootstrapper: `scripts/core/input/u_input_map_bootstrapper.gd` (`REQUIRED_ACTIONS`)
- Profile: `resources/core/input/profiles/cfg_default_keyboard.tres` (`RS_InputProfile`)
- Profile loader: `scripts/core/managers/helpers/u_input_profile_loader.gd`
- Source: `scripts/core/input/sources/keyboard_mouse_source.gd` (implements `I_InputSource`)
- Actions: `scripts/core/state/actions/u_input_actions.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `U_InputMapBootstrapper` | Validates `REQUIRED_ACTIONS` at startup. Patches missing in dev/test only. |
| `RS_InputProfile` | Resource: `profile_name`, `device_type`, `action_mappings`, accessibility fields. |
| `I_InputSource` | Interface: `get_device_type()`, `get_priority()`, `is_active()`, `capture_input()`. |
| `U_DeviceTypeConstants.DeviceType` | Enum: `KEYBOARD_MOUSE=0`, `GAMEPAD=1`, `TOUCHSCREEN=2`. |
| `M_InputDeviceManager` | Detects active device, routes input through sources. |
| `M_InputProfileManager` | Loads profiles, applies bindings to InputMap, handles rebinding. |

Profile naming: `cfg_<descriptor>_<device>.tres`. Action names: lowercase snake_case.

## Recipe

### Adding a new input action

1. Add action name to `U_InputMapBootstrapper.REQUIRED_ACTIONS`.
2. Add the action to `project.godot` InputMap (define key bindings).
3. Add action bindings to every `RS_InputProfile` `.tres` that should support it.
4. Optionally add Redux action creator in `U_InputActions` and selector in `U_InputSelectors`.

### Adding a new input profile

1. Create `RS_InputProfile` `.tres` under `resources/core/input/profiles/`: `cfg_<descriptor>_<device>.tres`.
2. Set `profile_name`, `device_type`, `action_mappings`, `description`, `is_system_profile`.
3. Register in `U_InputProfileLoader.load_available_profiles()`: add `load()` + insert into `profiles` dictionary.
4. Accessibility profiles (key starts with `"accessibility"`) auto-apply accessibility fields on switch.

### Adding a new input source device

1. Create class extending `I_InputSource` in `scripts/core/input/sources/`.
2. Add enum value to `U_DeviceTypeConstants.DeviceType`.
3. Register in `M_InputDeviceManager._register_input_sources()` and handle events in `_input()`.

## Anti-patterns

- **Adding actions only at runtime**: Actions must exist in `project.godot` for determinism. Bootstrapper only patches in dev/test.
- **Gating mobile gamepad input on cursor capture**: `Input.mouse_mode` is unreliable on mobile.
- **Ignoring Godot's touch-to-mouse conversion**: Must ignore emulated `InputEventMouseButton`/`Motion` on mobile or device type flickers.
- **Rebinding `pause` or `ui_cancel`**: These are reserved per `RS_RebindSettings.reserved_actions`.
- **Clobbering test-driven input state**: `S_InputSystem` must not dispatch zeros that overwrite test-set values.

## Out Of Scope

- ECS component/system: see `ecs.md`
- Manager registration: see `managers.md`
- State slice: see `state.md`

## References

- [Input Manager Overview](../../systems/input_manager/input-manager-overview.md)