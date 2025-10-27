# Developer Pitfalls

## Godot Scene UIDs

- **Never manually specify UIDs in .tscn files**: When creating scene files programmatically or via text editing, do NOT include `uid://` lines in the scene file. Godot automatically generates and manages UIDs when you save scenes in the editor. Manually-specified UIDs will cause "Unrecognized UID" errors because Godot's UID registry doesn't know about them. **Solution**: Let Godot generate UIDs by either:
  - Creating scenes in the Godot editor and saving normally
  - Creating scene files without the `uid=` parameter in the header line
  - Opening manually-created scenes in the editor and re-saving to generate proper UIDs
  
  Example of WRONG approach:
  ```
  [gd_scene load_steps=3 format=3 uid="uid://cjxbw8u5jn7nn"]  # DON'T DO THIS
  ```
  
  Example of CORRECT approach:
  ```
  [gd_scene load_steps=3 format=3]  # Let Godot add UID when you save in editor
  ```

## Godot UI Pitfalls

- **Full-screen overlay containers block input by default**: When creating HUD overlays or full-screen UI containers (using `anchors_preset = 15`), the container will block ALL mouse input to UI elements below it, even if the container's children only occupy a small portion of the screen. This happens because Control nodes use `mouse_filter = MOUSE_FILTER_STOP` (value 0) by default, which intercepts and stops mouse events from propagating.
  
  **Problem**: A MarginContainer covering the entire screen for a HUD overlay will prevent clicks from reaching buttons or UI elements below it, even though the HUD content (health/score labels) only appears in the corner.
  
  **Solution**: Set `mouse_filter = 2` (MOUSE_FILTER_IGNORE) on full-screen containers that should display information without blocking interaction:
  ```gdscript
  # In .tscn file:
  [node name="MarginContainer" type="MarginContainer" parent="."]
  anchors_preset = 15
  anchor_right = 1.0
  anchor_bottom = 1.0
  mouse_filter = 2  # MOUSE_FILTER_IGNORE - lets clicks pass through
  ```
  
  **When to use each mouse_filter mode:**
  - `MOUSE_FILTER_STOP` (0 - default): Block mouse events (use for clickable buttons, interactive panels)
  - `MOUSE_FILTER_PASS` (1): Receive mouse events but let them continue to nodes below
  - `MOUSE_FILTER_IGNORE` (2): Completely ignore mouse events (use for non-interactive overlays, info displays)
  
  **Real example**: `scenes/ui/hud_overlay.tscn` uses a full-screen MarginContainer to provide consistent margins for HUD elements. Without `mouse_filter = 2`, it blocked all clicks to test scene buttons below it, even though the HUD labels only occupied the top-left corner.

## GDScript Language Pitfalls

- **Lambda closures cannot reassign outer scope variables**: GDScript lambdas capture variables by reference but **cannot reassign them**. Writing `var x = 1; var f = func(): x = 2` will not modify the outer `x`. **Solution**: Use mutable containers like Arrays or Dictionaries. Example: `var result: Array = []; var callback = func(val): result.append(val)`. This commonly occurs when capturing action results in subscriber callbacks or signal handlers. See `state_test_us1a.gd` for a real-world example where `var action_received: Array = []` works but `var action_received: Dictionary = {}` does not.
- **Always add explicit types when pulling Variants**: Helpers such as `C_InputComponent.get_move_vector()` or `Time.get_ticks_msec()` return Variants. Define locals with `: Vector2`, `: float`, etc., instead of relying on inference, otherwise the parser fails with "typed as Variant" errors.
- **Annotate Callable results**: `Callable.call()` and similar helpers also return Variants. When reducers or action handlers return dictionaries, capture them with explicit types (e.g., `var next_state: Dictionary = root.call(...)`) so tests load without Variant inference errors.
- **Respect tab indentation in scripts**: Godot scripts under `res://` expect tabs. Mixing spaces causes parse errors that look unrelated to the actual change, so configure your editor accordingly before editing `.gd` files.

## ECS System Pitfalls

- **All ECS systems need @icon annotation**: Every system extending ECSSystem should have `@icon("res://resources/editor_icons/system.svg")` at the top of the file. This provides visual consistency in the Godot editor and makes systems easy to identify in the scene tree. Without this annotation, systems appear with the default script icon.

- **Event-driven state updates can invalidate cached checks**: When systems fire events (like landing events), other systems may respond by modifying entity state (position resets, velocity changes). If your system caches state BEFORE firing the event, subsequent checks may use stale data. **Solution**: Update cached state AFTER events fire, not before. Example: S_JumpSystem marks the player as "on floor" AFTER publishing `EVENT_ENTITY_LANDED` to ensure jump permission checks see post-reset floor state. This prevents race conditions where landing position resets temporarily invalidate `is_on_floor()` checks, blocking immediate jump attempts.

## State Store Integration Pitfalls

- **System initialization race condition**: Systems that access M_StateStore in `_ready()` must use `await get_tree().process_frame` BEFORE calling `U_StateUtils.get_store()`. The store adds itself to the "state_store" group in its own `_ready()`, so other nodes' `_ready()` methods run concurrently. Without the await, systems will fail to find the store. Example:
  ```gdscript
  func _ready() -> void:
      super._ready()
      await get_tree().process_frame  # CRITICAL: Wait for store to register
      _store = U_StateUtils.get_store(self)
  ```
  Systems that get the store in `process_tick()` don't need this await since process_tick runs after all _ready() calls complete.

- **Input processing order matters**: Godot processes input in a specific order: `_input()` → `_gui_input()` → `_unhandled_input()`. If one system calls `set_input_as_handled()` in `_unhandled_input()`, other systems using `_unhandled_input()` may never see the input. **Solution**: Systems that need priority access to input should use `_input()` instead of `_unhandled_input()`. Example: S_PauseSystem uses `_input()` to process pause before M_CursorManager (which uses `_unhandled_input()`) can consume it. Both call `set_input_as_handled()` to prevent further propagation.

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

- **Systems requiring M_StateStore need it in test setup**: Phase 16 systems (S_LandingIndicatorSystem, S_JumpSystem, S_InputSystem, S_GravitySystem, etc.) call `U_StateUtils.get_store(self)` in `process_tick()` to read state. Tests must provide a store or these systems will error with `push_error("No M_StateStore in 'state_store' group")`. **Solution**: In test setup, create and add a store:
  ```gdscript
  func _setup_entity(max_distance: float = 10.0) -> Dictionary:
      var store: M_StateStore = M_StateStore.new()
      add_child(store)
      await _pump()
      
      var manager: M_ECSManager = ECS_MANAGER.new()
      add_child(manager)
      await _pump()
      # ... rest of setup
  ```
  For tests needing gameplay state (entity coordination, etc.), initialize `store.gameplay_initial_state = RS_GameplayInitialState.new()` before adding as child.

- **StateHandoff pollutes between tests without explicit clearing**: `StateHandoff.preserve_slice()` saves state that persists across test runs, causing state bleed where test B sees test A's entities/data. This manifests as "Expected 2 entities, got 3" failures. **Solution**: Call `StateHandoff.clear_all()` in `before_each()`:
  ```gdscript
  func before_each() -> void:
      StateHandoff.clear_all()  # CRITICAL for state coordination tests
      ECSEventBus.reset()        # CRITICAL for ECS event tests
      store = M_StateStore.new()
      store.gameplay_initial_state = RS_GameplayInitialState.new()
      add_child_autofree(store)
  ```

- **Integration tests need extra initialization frames**: Full scene tests (`BASE_SCENE.instantiate()`) involve complex initialization with multiple managers and systems subscribing to events. If tests run assertions too soon, systems may not be fully initialized. **Symptom**: Event subscribers not found, empty request arrays when events fire. **Solution**: Add physics frame waits after scene instantiation:
  ```gdscript
  func _setup_scene() -> Dictionary:
      await get_tree().process_frame
      var scene := BASE_SCENE.instantiate()
      add_child(scene)
      autofree(scene)
      await get_tree().process_frame
      await get_tree().process_frame
      await get_tree().physics_frame  # Extra waits for state store
      await get_tree().physics_frame  # and system initialization
      # Now safe to query systems/managers
  ```

- **wait_frames is deprecated, use wait_physics_frames**: GUT 9.5+ deprecates `wait_frames()` in favor of explicit `wait_physics_frames()` (counted in `_physics_process`) or `wait_process_frames()` (counted in `_process`). Using deprecated `wait_frames` generates warnings. Since ECS systems run in `_physics_process`, use `wait_physics_frames`:
  ```gdscript
  # WRONG (deprecated):
  store.dispatch(action)
  await wait_frames(1)
  
  # CORRECT:
  store.dispatch(action)
  await wait_physics_frames(1)
  ```

## Test Coverage Status

As of 2025-10-27:
- **Total Tests**: 312 tests across 46 test scripts
- **Passing**: 312/312 (100%)
- **Total Assertions**: 856
- **Test Execution Time**: ~22 seconds for full suite

Test directories:
- `tests/unit/ecs` - ECS component and system tests (62 tests)
- `tests/unit/ecs/components` - Component-specific tests (24 tests)
- `tests/unit/ecs/systems` - System-specific tests (74 tests)
- `tests/unit/state` - State management tests (112 tests)
- `tests/unit/state/integration` - State slice transition tests (4 tests)
- `tests/unit/integration` - ECS/State integration tests (15 tests)
- `tests/integration` - Full scene integration tests (10 tests)
- `tests/unit/utils` - Utility tests (11 tests)

All critical paths tested including error conditions, edge cases, integration scenarios, and Phase 16 state coordination patterns.
- **No C-style ternaries**: GDScript 4.5 rejects `condition ? a : b`. Use the native `a if condition else b` form and keep payload normalization readable.
- **Keep component discovery consistent**: Decoupled components (e.g., `C_MovementComponent`, `C_JumpComponent`, `C_RotateToInputComponent`, `C_AlignWithSurfaceComponent`) now auto-discover their peers, but components that still export NodePaths for scene nodes (landing indicator markers, floating raycasts, etc.) require those paths to be wired. Mixing patterns silently disables behaviour and breaks tests.
- **Reset support timers after jumps**: When modifying jump logic, remember to clear support/apex timers just like `C_JumpComponent.on_jump_performed()` does. Forgetting this can enable double jumps that tests catch.
- **Second-order tuning must respect clamped limits**: While tweaking response/damping values, verify they still honour `max_turn_speed_degrees` and `max_speed`. Oversight here reintroduces overshoot regressions covered by rotation/movement tests.
 - **ECS components require an entity root**: `M_ECSManager` associates components to entities by walking ancestors and picking the first node whose name starts with `E_`. If a component is not under such a parent, registration logs `push_error("M_ECSManager: Component <Name> has no entity root ancestor")` and the component is not tracked for entity queries. In tests and scenes, create an entity node (e.g., `var e := Node.new(); e.name = "E_Player"; e.add_child(component)`).
 - **Registration is deferred; yield a frame**: `ECSComponent._ready()` uses `call_deferred("_register_with_manager")`. After adding a manager/component, `await get_tree().process_frame` before asserting on registration (`get_components(...)`) or entity tracking to avoid race conditions.
 - **Required settings block registration**: Components like `C_JumpComponent`, `C_MovementComponent`, `C_FloatingComponent`, and `C_AlignWithSurfaceComponent` validate that their `*Settings` resources are assigned. Missing settings produce a `push_error("<Component> missing settings; assign an <Resource>.")` and skip registration. Wire default `.tres` in scenes, or set `component.settings = RS_*Settings.new()` in tests.
 - **Input.mouse_mode changes may need a frame**: When toggling cursor lock/visibility rapidly (e.g., calling `toggle_cursor()` twice), yield a frame between calls in tests to let `Input.mouse_mode` settle on headless runners. Example: `manager.toggle_cursor(); await get_tree().process_frame; manager.toggle_cursor(); await get_tree().process_frame`.
- **Camera-relative forward uses negative Z**: Our input vector treats `Vector2.UP` (`y = -1`) as forward. When converting to camera space (see `S_MovementSystem`), multiply the input’s Y by `-1` before combining with `cam_forward`, otherwise forward/backward movement inverts.
