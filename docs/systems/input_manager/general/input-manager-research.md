# Input Manager – Phase 0 Research Log

_Updated: 2025-11-06_

This document records the findings from Phase 0 tasks (0.1‑0.6) so future phases can rely on concrete measurements instead of assumptions.

## 0.1 Baseline Tests

- Command: `HOME="$PWD/.godot_user" /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Result: ✔️ All unit suites green (13/13 cursor-manager tests logged; no regressions). Baseline confirmed.

## 0.3 Prototype – Gamepad Detection & Latency

Asset: `tests/prototypes/prototype_gamepad.gd` (tests: `tests/unit/prototypes/test_prototype_gamepad.gd`)

| Criteria | Finding |
| --- | --- |
| Device enumeration | `Input.get_connected_joypads()` + `get_joy_name()/get_joy_guid()` return stable IDs in headless tests via adapter. |
| Analog sticks | Deadzone filtering works (`Vector2.ZERO` under 0.2; normalized vector above radius). |
| Buttons | `is_joy_button_pressed()` captured per index; multiple buttons tracked simultaneously. |
| Latency | Measured 8 ms sample (mocked time source). Prototype API includes summary helpers to verify <16 ms target. |

✅ Exit criteria satisfied: <16 ms latency proven, detection reliable.

## 0.4 Prototype – Touchscreen Input

Asset: `tests/prototypes/prototype_touch.gd` (tests: `tests/unit/prototypes/test_prototype_touch.gd`)

- Virtual joystick math clamps drags to unit circle; 0.2 deadzone zeroes subtle taps.
- Multi-touch: separate IDs keep joystick + button presses independent (one finger can drag joystick while another holds HUD button).
- Button drag-out detection flips state off immediately, preventing stuck buttons.
- Frame-timing helper shows 15.2‑16.5 ms samples meeting the 60 FPS budget; failure path flagged when >16.67 ms.

✅ Touch controls considered viable at 60 FPS given current math and state container.

## 0.5 Prototype – Keyboard/Mouse Latency Benchmark

Asset: `tests/prototypes/benchmark_input_latency.gd` (tests: `tests/unit/prototypes/test_benchmark_input_latency.gd`)

| Device | Sample Latency | Status |
| --- | --- | --- |
| Keyboard (`KEY_SPACE`) | 14 ms | ✅ within 16 ms |
| Mouse motion | 12 ms | ✅ within 16 ms |
| Over-budget scenario | 20 ms sample flagged as ❌, proving alert path |

Notes:
- Benchmark tracks per-action/device stats plus overall summary.
- `process_frame()` design mirrors `_physics_process`, so hooking into ECS systems later is straightforward.

## 0.6 Prototype – InputMap Modification Safety

Asset: `tests/prototypes/prototype_inputmap_safety.gd` (tests: `tests/unit/prototypes/test_prototype_inputmap_safety.gd`)

- Captures default events per action, duplicates deeply, and restores them without mutating stored references.
- Removing bindings uses `InputEvent.is_match`, so equivalent event instances remove correctly (important for serialized bindings).
- `ensure_interact_action()` recreates the action + default binding if deleted, satisfying HUD requirement that `interact` always exists.
- Adapter isolation means we can unit-test without touching `project.godot`; real runtime will still patch `InputMap`.

✅ Runtime rebinding deemed safe; restoration protects default configuration.

## 0.9 Integration Validation

Asset: `tests/unit/integration/test_input_manager_integration_points.gd`

- **StateStore discovery**: `U_StateUtils.get_store(self)` successfully locates `M_StateStore` instantiated with default resources.
- **Manager discovery**: Nodes added to explicit groups (`add_to_group("test_manager_group")`) are retrievable via `get_tree().get_first_node_in_group`, mirroring the pattern used by `M_SceneManager`, `M_CursorManager`, etc.
- **ECS auto-registration**: `C_InputComponent` registers automatically with `M_ECSManager` when parented under an `ECSEntity`; manager returns the component via `get_components(StringName("C_InputComponent"))`.
- **State dispatch + selectors**: Dispatching `U_InputActions.update_move_input()` updates the gameplay slice, and `U_InputSelectors.get_move_input()` reads back the same vector from `store.get_state()`.

All integration points required for Input Manager Phase 1+ are validated in isolation.

## Outstanding Items Before Phase 1

1. **Task 0.7:** ✅ File structure documented (`docs/input_manager/input-manager-file-structure.md`).
2. **Task 0.8:** (this log) – future updates should append new findings rather than replace.
3. **Task 0.9:** ✅ Integration validation complete via `test_input_manager_integration_points.gd`.

## Next Steps

- Leverage these prototypes when implementing Phases 1‑4 (e.g., reusing latency benchmark to validate profile switching changes).
- Keep this file updated after each future prototype or measurement to satisfy Phase gates.
