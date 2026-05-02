# State Store Pitfalls

Redux-style state store and integration gotchas.

---

## State Store Pitfalls (Redux-style)

- Signal batching timing
  - Emit batched `slice_updated` signals in `_physics_process` only. Flushing in both `_process` and `_physics_process` can double-emit in a single frame and break tests expecting one emission.
  - Actions that need same-frame visibility (e.g., input rebind flows) must set `"immediate": true`; the store flushes pending slice updates instantly for those actions. Forgetting the flag leaves UI stuck until the next physics tick.

- Input state transient vs persistence
  - Gameplay input fields (`input`, `move_input`, `look_input`, `jump_*`, `sprint_pressed`) should be transient across scene transitions (StateHandoff) to avoid sticky input on load.
  - Persist full gameplay slice for save/load. Special-case serialization so input fields are written to disk even if marked transient for handoff.

- Performance considerations
  - Skip reducer work when the returned state equals the current slice (unchanged-state short-circuit).
  - Route actions to slice reducers by prefix (`gameplay/`, `settings/`, `scene/`, etc.) to avoid evaluating every reducer for every action.
  - Use shallow copies for history array returns; history entries already contain deep-copied snapshots.

- Input binding serialization
  - Always dispatch rebinds via `U_InputActions.rebind_action()` so the helper serializes the canonical `events` array; hand-built actions that omit the array will cause `M_InputProfileManager` to drop default bindings when it rebuilds the InputMap from Redux.

- Device detection flow
  - `device_changed` actions must originate from `M_InputDeviceManager`. `S_InputSystem` only reads `U_InputSelectors.get_active_device_type()` / `get_active_gamepad_id()`; dispatching from multiple sources causes duplicate logs and race conditions.
  - Gamepad hot-plug events dispatch `gamepad_connected` / `gamepad_disconnected` from the manager. Keep connection-dependent systems (e.g., vibration) subscribed to Redux state rather than polling the manager directly.

---

## State Store Integration Pitfalls

- **System initialization race condition**: Systems that access M_StateStore in `_ready()` must use `await get_tree().process_frame` BEFORE calling `U_StateUtils.get_store()`. The store adds itself to the "state_store" group in its own `_ready()`, so other nodes' `_ready()` methods run concurrently. Without the await, systems will fail to find the store. Example:
  ```gdscript
  func _ready() -> void:
      super._ready()
      await get_tree().process_frame  # CRITICAL: Wait for store to register
      _store = U_StateUtils.get_store(self)
  ```
  Systems that get the store in `process_tick()` don't need this await since process_tick runs after all _ready() calls complete.

- **Input processing order matters**: Godot processes input in a specific order: `_input()` → `_gui_input()` → `_unhandled_input()`. If one system calls `set_input_as_handled()`, later handlers may never see the event. **Solution**: Keep pause intent centralized in `_input()` (`M_UIInputHandler`), dispatch navigation actions there, and avoid duplicate pause handling in later stages.

- **Single source of truth for ESC/pause**: To avoid double-toggles, route ESC/pause through `M_UIInputHandler` navigation actions, then let `M_SceneManager` reconcile overlays and `M_TimeManager` derive pause state from the scene/UI overlay stack. Keep InputMap `pause` mapped to ESC for consistency.
