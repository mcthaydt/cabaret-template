# Developer Pitfalls

## GDScript Language Pitfalls

- **Lambda closures cannot reassign outer scope variables**: GDScript lambdas capture variables by reference but **cannot reassign them**. Writing `var x = 1; var f = func(): x = 2` will not modify the outer `x`. **Solution**: Use mutable containers like Arrays or Dictionaries. Example: `var result: Array = []; var callback = func(val): result.append(val)`. This commonly occurs when capturing action results in subscriber callbacks or signal handlers. See `state_test_us1a.gd` for a real-world example where `var action_received: Array = []` works but `var action_received: Dictionary = {}` does not.
- **Always add explicit types when pulling Variants**: Helpers such as `C_InputComponent.get_move_vector()` or `Time.get_ticks_msec()` return Variants. Define locals with `: Vector2`, `: float`, etc., instead of relying on inference, otherwise the parser fails with "typed as Variant" errors.
- **Annotate Callable results**: `Callable.call()` and similar helpers also return Variants. When reducers or action handlers return dictionaries, capture them with explicit types (e.g., `var next_state: Dictionary = root.call(...)`) so tests load without Variant inference errors.
- **Respect tab indentation in scripts**: Godot scripts under `res://` expect tabs. Mixing spaces causes parse errors that look unrelated to the actual change, so configure your editor accordingly before editing `.gd` files.

## GUT Testing Pitfalls

- **Expected errors must use assert_push_error() AFTER the action**: When testing code that intentionally triggers `push_error()`, call `assert_push_error("error pattern")` immediately AFTER the action that causes the error, not before. Example:
  ```gdscript
  var result := ActionRegistry.validate_action(invalid_action)
  assert_push_error("Action missing 'type' field")  # After validation
  assert_false(result)
  ```
  **Wrong**: `gut.p("Expect error...")` before the action - this doesn't work and will show "Unexpected Errors".

- **Warnings treated as unexpected errors**: GUT treats `push_warning()` calls as unexpected errors in test output. If your code legitimately needs warnings (like deprecation notices), either:
  - Reconsider if it should be a warning (default settings creation is NOT warning-worthy)
  - Test the warning-causing path explicitly with intentional setup
  - Accept that warnings will appear in test output but won't fail tests

- **Mock overrides need warning suppression**: GUT tests that subclass engine nodes often stub methods like `is_on_floor()` or `move_and_slide()`. Godot 4 treats these as warnings, and our CI escalates warnings to errors. Add `@warning_ignore("native_method_override")` to those stubs to keep tests loading.

- **Always register fixtures with GUT autofree**: Every node you instantiate in a test (managers, entities, components, fake bodies, etc.) must be queued through `autofree()`/`autofree_context()` so the runner releases them. Forgetting this leaks children and leaves failing cleanup warnings even when assertions pass.

- **Clear static state between tests**: Static classes (like `StateHandoff`, `ActionRegistry`) retain state across tests. Always call reset/clear methods in `before_each()` and `after_each()`:
  ```gdscript
  func before_each() -> void:
      StateStoreEventBus.reset()  # For state tests
      StateHandoff.clear_all()     # Prevents state pollution
      # ECSEventBus.reset() for ECS tests
  
  func after_each() -> void:
      StateHandoff.clear_all()
      StateStoreEventBus.reset()
  ```
  This prevents test pollution where one test's state affects another, causing false failures like getting `health=100` instead of expected `health=75`.

## Test Coverage Status

As of 2025-10-26:
- **ECS Tests**: 62/62 passing (100%)
- **State Store Tests**: 87/87 passing (100%)
- **Total**: 149/149 tests passing (100%)

All critical paths tested including error conditions, edge cases, and integration scenarios.
- **No C-style ternaries**: GDScript 4.5 rejects `condition ? a : b`. Use the native `a if condition else b` form and keep payload normalization readable.
- **Keep component discovery consistent**: Decoupled components (e.g., `C_MovementComponent`, `C_JumpComponent`, `C_RotateToInputComponent`, `C_AlignWithSurfaceComponent`) now auto-discover their peers, but components that still export NodePaths for scene nodes (landing indicator markers, floating raycasts, etc.) require those paths to be wired. Mixing patterns silently disables behaviour and breaks tests.
- **Reset support timers after jumps**: When modifying jump logic, remember to clear support/apex timers just like `C_JumpComponent.on_jump_performed()` does. Forgetting this can enable double jumps that tests catch.
- **Second-order tuning must respect clamped limits**: While tweaking response/damping values, verify they still honour `max_turn_speed_degrees` and `max_speed`. Oversight here reintroduces overshoot regressions covered by rotation/movement tests.
 - **ECS components require an entity root**: `M_ECSManager` associates components to entities by walking ancestors and picking the first node whose name starts with `E_`. If a component is not under such a parent, registration logs `push_error("M_ECSManager: Component <Name> has no entity root ancestor")` and the component is not tracked for entity queries. In tests and scenes, create an entity node (e.g., `var e := Node.new(); e.name = "E_Player"; e.add_child(component)`).
 - **Registration is deferred; yield a frame**: `ECSComponent._ready()` uses `call_deferred("_register_with_manager")`. After adding a manager/component, `await get_tree().process_frame` before asserting on registration (`get_components(...)`) or entity tracking to avoid race conditions.
 - **Required settings block registration**: Components like `C_JumpComponent`, `C_MovementComponent`, `C_FloatingComponent`, and `C_AlignWithSurfaceComponent` validate that their `*Settings` resources are assigned. Missing settings produce a `push_error("<Component> missing settings; assign an <Resource>.")` and skip registration. Wire default `.tres` in scenes, or set `component.settings = RS_*Settings.new()` in tests.
 - **Input.mouse_mode changes may need a frame**: When toggling cursor lock/visibility rapidly (e.g., calling `toggle_cursor()` twice), yield a frame between calls in tests to let `Input.mouse_mode` settle on headless runners. Example: `manager.toggle_cursor(); await get_tree().process_frame; manager.toggle_cursor(); await get_tree().process_frame`.
- **Camera-relative forward uses negative Z**: Our input vector treats `Vector2.UP` (`y = -1`) as forward. When converting to camera space (see `S_MovementSystem`), multiply the input’s Y by `-1` before combining with `cam_forward`, otherwise forward/backward movement inverts.
