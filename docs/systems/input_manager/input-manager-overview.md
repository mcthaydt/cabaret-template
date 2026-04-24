# Input Manager Overview

Input Manager owns hardware input detection, input profile/rebind behavior, and mapping physical controls into canonical actions. UI flow decisions belong to UI Manager navigation state; gameplay movement consumption belongs to ECS systems.

## Key Docs

- PRD: `docs/systems/input_manager/input-manager-prd.md`
- Plan: `docs/systems/input_manager/input-manager-plan.md`
- Tasks: `docs/systems/input_manager/input-manager-tasks.md`
- File structure: `docs/systems/input_manager/general/input-manager-file-structure.md`
- Touchscreen architecture: `docs/systems/input_manager/general/phase-6-touchscreen-architecture.md`

## Ownership

Input Manager owns:

- keyboard/mouse, gamepad, and touchscreen device detection;
- `ui_*` and gameplay action mapping through Godot InputMap/profile resources;
- active device type updates through `M_InputDeviceManager`;
- input profile and rebind persistence through `M_InputProfileManager`;
- device-aware action availability.

Input Manager does not own:

- pause/overlay/menu flow decisions;
- direct scene-manager calls;
- UI focus routing;
- gameplay movement integration after actions are written into state/components.

See `docs/systems/ui_manager/ui-pitfalls.md` for the UI/Input boundary.

## Runtime Contracts

- `pause`, `ui_pause`, and `ui_cancel` keep ESC on keyboard and Start on gamepad.
- `RS_RebindSettings` marks pause as non-rebindable.
- `S_InputSystem` should avoid clobbering test-authored Redux input state in headless tests.
- Mobile and web builds should ignore Godot-emulated mouse events derived from touch events when updating active device type.
- Mobile gamepad input must not be gated on cursor capture; mobile platforms have no meaningful mouse cursor.
- Mobile controls visibility depends on `navigation.shell == SHELL_GAMEPLAY` unless intentionally forced during early boot/test setup.

## Pitfalls

- **Avoid clobbering test-driven input state**: Headless tests may set `gameplay.move_input`, `look_input`, and `jump_pressed` directly. If `S_InputSystem` dispatches zeros every frame, it overwrites test state. Non-mobile `S_InputSystem` dispatch should be gated by gameplay cursor capture.
- **Do not gate mobile gamepad input on cursor capture**: On mobile, `Input.mouse_mode` is not reliable. Apply cursor-capture gating only on non-mobile platforms.
- **Godot auto-converts touch to mouse events on mobile**: Android/iOS synthesize `InputEventMouseButton` and `InputEventMouseMotion` from screen touch/drag events. `M_InputDeviceManager` should ignore those emulated mouse events on mobile/web so device type does not flicker between touchscreen and keyboard/mouse mid-press.
- **MobileControls visibility depends on navigation shell**: Tests that construct `M_StateStore` manually must wire `navigation_initial_state` and dispatch gameplay navigation before instantiating `MobileControls`.
- **Pause is reserved**: Do not strip ESC/Start from `project.godot` or InputMap initialization when adding actions.
- **Mobile emulation is desktop QA only**: `--emulate-mobile` helps smoke test touchscreen UI on desktop, but real-device runs remain the source of truth.

## Testing

- Input map tests live under `tests/unit/input/`.
- UI/gamepad navigation deadzone tests live under `tests/unit/ui/`.
- Mobile controls tests should construct navigation state explicitly before asserting visibility.
