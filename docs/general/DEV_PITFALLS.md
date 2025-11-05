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

## Scene Transition Pitfalls

- Door trigger re-entry can cause ping-pong transitions:
  - Ensure `C_SceneTriggerComponent` guards are active (cooldown + `is_transitioning` checks).
  - Keep spawn markers positioned outside trigger volumes to avoid immediate re-trigger on load.
  - Avoid leaving `initial_scene_id = exterior` outside of manual tests; prefer `main_menu` to follow the flow and reduce confusion.

- Trigger geometry pitfalls (Cylinder default):
  - `CylinderShape3D` is Y-up; do not rotate unless your door axis demands it.
  - Avoid non-uniform scaling on trigger nodes; set `radius/height` (or `box_size`) via settings instead.
  - Too-small radius/height leads to flickery enter/exit at edges—add margin.
  - Keep collision masks consistent with the player layer (`player_mask` in RS_SceneTriggerSettings). A mismatch causes no events.

## GDScript Language Pitfalls

- **Lambda closures cannot reassign primitive variables**: GDScript lambdas capture variables but **cannot reassign primitive types** (bool, int, float). Writing `var completed = false; var callback = func(): completed = true` will NOT modify the outer `completed` variable - the callback will set a local copy instead. **Solution**: Wrap primitives in mutable containers like Arrays. Example:
  ```gdscript
  # WRONG - closure doesn't modify outer variable:
  var completed: bool = false
  var callback := func() -> void:
      completed = true  # Sets local copy, NOT outer variable
  callback.call()
  assert_true(completed)  # FAILS - still false!

  # CORRECT - use Array wrapper:
  var completed: Array = [false]
  var callback := func() -> void:
      completed[0] = true  # Modifies array element
  callback.call()
  assert_true(completed[0])  # PASSES
  ```
  This commonly occurs in:
  - Test callbacks waiting for async operations to complete
  - Transition effects with completion callbacks
  - Action result capture in subscriber callbacks
  - Signal handlers needing to set flags

  See `test_transitions.gd` for examples where all boolean flags use `Array = [false]` pattern to work with closures.
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

- **Single source of truth for ESC/pause**: To avoid double-toggles, route ESC/pause through `M_SceneManager` only when it is present. `S_PauseSystem` now defers input handling if a Scene Manager exists and should only be used as a fallback (or via direct `toggle_pause()` in tests). Ensure the InputMap maps `pause` to ESC for consistency (project.godot already does).

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

- **Always register fixtures with GUT autofree**: Every node you instantiate in a test (managers, entities, components, fake bodies, etc.) must be registered with GUT's autofree system. Use `add_child_autofree(node)` instead of `add_child(node)` + `queue_free()`. GUT will automatically free these nodes after each test completes. Forgetting this leaks children and shows "Test script has N unfreed children" warnings even when assertions pass. Example:
  ```gdscript
  # WRONG - causes memory leaks:
  func test_something() -> void:
      var store := M_StateStore.new()
      add_child(store)
      # ... test logic ...
      store.queue_free()  # Too late - test completes before queue processes

  # CORRECT - GUT frees after test:
  func test_something() -> void:
      var store := M_StateStore.new()
      add_child_autofree(store)  # GUT tracks and frees this
      # ... test logic ...
      # No manual cleanup needed
  ```

- **Clear static state between tests**: Static classes (like `StateHandoff`, `ActionRegistry`) retain state across tests. Always call reset/clear methods in `before_each()` and `after_each()`:
  ```gdscript
  func before_each() -> void:
      U_StateEventBus.reset()  # For state tests
      StateHandoff.clear_all()     # Prevents state pollution
      # U_ECSEventBus.reset() for ECS tests
  
  func after_each() -> void:
      StateHandoff.clear_all()
      U_StateEventBus.reset()
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
      U_ECSEventBus.reset()        # CRITICAL for ECS event tests
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

## Headless Test Pitfalls

- **Headless GUT runs crash if `user://` resolves outside the sandbox**: The CLI harness blocks writes to `~/Library/Application Support/Godot/...`, so running Godot headless without overriding the user directory makes `RotatedFileLogger` abort during startup. Always launch tests via `tools/run_gut_suite.sh` (or manually prepend `HOME="$PWD/.godot_user"` to the Godot command). The script also enables `-ginclude_subdirs=true` so nested test suites execute instead of being skipped silently.

## Documentation and Planning Pitfalls

- **MANDATORY: Update continuation prompt and tasks after EVERY phase**: Failing to update planning documentation after completing a phase creates confusion for future work sessions. After completing ANY phase of ANY feature:
  1. Update the continuation prompt file with current status and what's next
  2. Update the tasks file to mark completed tasks [x] with completion notes
  3. Update AGENTS.md if new patterns/architecture were introduced
  4. Update DEV_PITFALLS.md if new pitfalls were discovered
  5. Commit documentation separately with clear message

  **Why this matters**: The continuation prompt is the first thing read when resuming work. Stale status causes wasted time re-assessing progress and can lead to duplicate work or missed dependencies.

  **Example**: After completing Scene Manager Phase 2, the continuation prompt MUST be updated from "Ready for Phase 2" to "Phase 2 Complete - Ready for Phase 3", and tasks.md must show all T003-T024 marked [x] with test results.

- **Always commit documentation updates separately from implementation**: Documentation changes (AGENTS.md, DEV_PITFALLS.md, continuation prompts, task lists) should be in their own commit after the implementation commit. This makes it easier to review documentation changes and revert them independently if needed.

## Scene Manager Pitfalls (Phase 2+)

- **Always create and register scenes before referencing them in transitions**: Systems that call `M_SceneManager.transition_to_scene()` must ensure the target scene exists and is registered in `U_SceneRegistry` BEFORE the transition can occur. Missing scenes cause crashes with "Scene not found in registry" errors.

  **Problem**: Phase 8.5 implemented victory/death trigger systems that reference scenes that don't exist yet:
  - `s_health_system.gd:151` → transitions to `"game_over"` (scene doesn't exist, not registered)
  - `s_victory_system.gd:47` → transitions to `"victory"` (scene doesn't exist, not registered)
  - When these triggers fire, the game crashes because Scene Manager can't load non-existent scenes

  **Solution**: Follow this order when implementing transition flows:
  1. Create the .tscn scene file first (e.g., `scenes/ui/game_over.tscn`)
  2. Register the scene in `U_SceneRegistry._register_all_scenes()` with proper metadata
  3. Then implement/enable systems that transition to that scene

  **Registry Registration Example**:
  ```gdscript
  # In u_scene_registry.gd:
  func _register_all_scenes() -> void:
      # ... existing registrations ...

      # End-game scenes (Phase 9)
      _register_scene(
          StringName("game_over"),
          "res://scenes/ui/game_over.tscn",
          SceneType.END_GAME,
          "fade",
          8  # High priority - deaths are common
      )

      _register_scene(
          StringName("victory"),
          "res://scenes/ui/victory.tscn",
          SceneType.END_GAME,
          "fade",
          5  # Medium priority - less frequent
      )
  ```

  **Testing**: Before enabling a transition system, manually call `M_SceneManager.transition_to_scene()` in a test to verify the target scene loads successfully.

  **Incremental Development Safety**: When implementing features that add new scene transitions (like Phase 9 end-game flows), temporarily disable or guard the transition triggers until all scenes are created and registered. This prevents crashes during incremental development.

  **Example**:
  ```gdscript
  # In s_health_system.gd (temporary guard during Phase 9 development)
  func _handle_death_sequence(component: C_HealthComponent, entity: Node3D) -> void:
      if component.death_timer <= 0.0:
          # TODO: Remove this guard after T166 (scene registry) completes
          if not U_SceneRegistry.has_scene(StringName("game_over")):
              push_warning("game_over scene not registered yet, skipping transition")
              return

          var scene_manager := get_tree().get_nodes_in_group("scene_manager")[0]
          scene_manager.transition_to_scene(StringName("game_over"), "fade", TransitionPriority.CRITICAL)
  ```

- **Root scene architecture is mandatory**: As of Phase 2, the project uses a root scene pattern where `scenes/root.tscn` persists throughout the session. DO NOT create gameplay scenes with M_StateStore or M_CursorManager - these managers live ONLY in root.tscn. Each gameplay scene should have its own M_ECSManager instance.

- **Gameplay scenes must be self-contained**: When creating new gameplay scenes, duplicate `scenes/gameplay/gameplay_base.tscn` as a template. Include:
  - ✅ M_ECSManager (per-scene instance)
  - ✅ Systems (Core, Physics, Movement, Feedback)
  - ✅ Entities (player, camera, spawn points)
  - ✅ SceneObjects (floors, blocks, props)
  - ✅ Environment (lighting, world environment)
  - ❌ M_StateStore (lives in root.tscn)
  - ❌ M_CursorManager (lives in root.tscn)

- **HUD and UI components must use U_StateUtils**: UI elements that need M_StateStore access MUST use `U_StateUtils.get_store(self)` instead of direct parent traversal. The store is in root.tscn while UI may be in child scenes. Add `await get_tree().process_frame` in `_ready()` before calling `get_store()` to avoid race conditions.

- **Never instantiate root.tscn in tests**: The root scene is the main scene and should never be instantiated in tests. Test individual gameplay scenes by instantiating them directly (e.g., `BASE_SCENE.instantiate()` for `base_scene_template.tscn` or `GAMEPLAY_BASE.instantiate()` for `gameplay_base.tscn`). The test harness provides its own scene tree root.

- **ActiveSceneContainer manages scene lifecycle**: Scene loading/unloading will be managed by M_SceneManager (Phase 3+) which adds/removes scenes as children of ActiveSceneContainer. Direct manipulation of ActiveSceneContainer children is not supported - use M_SceneManager's transition methods instead.

- **UIDs must be managed by Godot**: When creating new scene files (like root.tscn), DO NOT manually specify UIDs in the scene header. Either omit the `uid=` parameter entirely or use `res://path/to/scene.tscn` paths in project.godot. Manually-specified UIDs cause "Unrecognized UID" errors because they're not registered in Godot's UID cache. Let Godot generate UIDs by opening and saving scenes in the editor.

- **StateHandoff works across scene transitions**: The existing StateHandoff system automatically preserves state when scenes are removed from the tree and restores it when they're added back. This works correctly with the root scene pattern - you'll see `[STATE] Preserved state to StateHandoff for scene transition` and `[STATE] Restored slice 'X' from StateHandoff` logs during scene changes.

- **M_SceneManager automatically manages cursor state**: As of Phase 3, M_SceneManager automatically sets cursor visibility based on scene type when scenes load:
  - **UI/Menu/End-game scenes**: Cursor is visible and unlocked (for button clicks)
  - **Gameplay scenes**: Cursor is locked and hidden (for first-person controls)

  DO NOT manually call `M_CursorManager.set_cursor_state()` in scene scripts unless you have a specific override requirement. The automatic management happens in `M_SceneManager._update_cursor_for_scene()` which is called after every scene transition. This prevents the common pitfall of loading a menu scene with a locked cursor (making buttons unclickable) or loading gameplay with a visible cursor (breaking immersion).

- **Transition callbacks MUST use Array wrappers for primitive flags**: When implementing transition effects or any async callbacks in M_SceneManager, use Arrays for boolean/primitive flags due to GDScript closure limitations. Example from `M_SceneManager._perform_transition()`:
  ```gdscript
  # WRONG - closures won't modify these:
  var transition_complete: bool = false
  var completion_callback := func() -> void:
      transition_complete = true  # Won't modify outer variable!

  # CORRECT - use Array wrapper:
  var transition_complete: Array = [false]
  var completion_callback := func() -> void:
      transition_complete[0] = true  # Modifies array element

  # Wait for transition
  while not transition_complete[0]:  # Check array element
      await get_tree().process_frame
  ```
  Without Array wrappers, transitions will never complete because the `while` loop checks a flag that the callback can't modify, causing infinite loops or test timeouts.

- **Fade transitions need adequate wait time in tests**: FadeTransition duration defaults to 0.2 seconds. Tests using fade transitions must wait at least 15 physics frames (0.25s at 60fps) for completion. Waiting only 4 frames (0.067s) will cause assertions to run before transitions complete, resulting in `is_transitioning` still being true or `current_scene_id` not yet updated. Use `await wait_physics_frames(15)` after fade transitions in tests.

- **Tween process mode must match wait loop (idle vs physics)**: Headless runs can stall if a transition tween updates on one process domain while the manager waits on the other (e.g., tween on PHYSICS but loop yields IDLE frames). We removed the physics-only tween path and aligned the manager’s wait loop with idle frames again. This eliminates the idle/physics mismatch that previously stalled completion. Guidance:
  - If you choose physics: set `_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)`, wait with `await get_tree().physics_frame`, and prefer `await wait_physics_frames(...)` in tests.
  - If you choose idle: keep the tween on default (IDLE), wait with `await get_tree().process_frame`, and prefer `await wait_seconds(...)` in tests.
  - Avoid pausing the tree during fades unless the overlay/tween are explicitly configured to run while paused (e.g., container `process_mode = ALWAYS`).

- **Paused SceneTree stalls Tweens/Timers unless owner runs while paused**: If `get_tree().paused == true`, tweens and timers won't advance for nodes in the default/pausable modes. This caused transition tests to hang while awaiting `tween.finished` or `wait_seconds(...)`.
  - For transitions, temporarily set both `TransitionOverlay` and its `TransitionColorRect` to `process_mode = Node.PROCESS_MODE_ALWAYS` during the fade and restore their original modes on completion.
  - In tests, avoid relying on `wait_seconds(...)` when the tree may be paused. Instead, either wait on `tween.finished` with a timeout loop that yields `process_frame`, or create timers that run while paused. Diagnostics should log `paused`, `Engine.time_scale`, and the nodes’ `process_mode` values.
  - Symptom: alpha/modulate never changes, `tween.is_running == true`, and wait loops time out with the tree paused.

- **Don't kill a Tween before `finished`**: Calling `Tween.kill()` (or equivalent) inside the tween chain prevents the `finished` signal from emitting. Tests that `await tween.finished` will hang.
  - Use `tween.finished.connect(...)` to run cleanup and completion callbacks, and only clear references after `finished` fires.
  - If a synchronous completion is needed, use a final `tween_callback(...)` in the chain instead of killing the tween.

- **ESC must be ignored during active transitions**: Pressing ESC while a fade/loading transition is running can pause the tree, freezing tweens and leaving the transition incomplete. The Scene Manager now ignores ESC when `is_transitioning()` or while processing the transition queue. Tests that emit ESC on the same frame as a door trigger rely on this guard to avoid accidental pause overlays.

- **Transition type override parameter**: M_SceneManager supports three transition types: "instant" (no delay), "fade" (crossfade effect), and "loading" (loading screen with progress bar). To override the default transition type for a specific scene transition, pass the transition_type parameter:
  ```gdscript
  # Use explicit transition type (overrides registry default)
  M_SceneManager.transition_to_scene(StringName("main_menu"), "loading")
  M_SceneManager.transition_to_scene(StringName("settings_menu"), "instant")

  # Use registry default (recommended for most cases)
  M_SceneManager.transition_to_scene(StringName("gameplay_base"))  # Uses default from U_SceneRegistry
  ```

  **Transition Selection Priority**:
  1. Explicit override parameter (if provided)
  2. Default from U_SceneRegistry.get_default_transition()
  3. Fallback to "instant" if unknown type

  **Choosing Transition Types**:
  - **instant**: UI → UI transitions, fast menu navigation (< 100ms)
  - **fade**: Menu → Gameplay transitions, smooth visual polish (0.2-0.5s)
  - **loading**: Large scene loads, async loading in Phase 8 (1.5s minimum duration)

  **Note**: Loading transitions require LoadingOverlay in root.tscn. If LoadingOverlay is missing, loading transitions will fall back to instant.

### Phase 10-Specific Pitfalls (Camera Blending, Edge Cases, Performance)

- **Camera blending only works for GAMEPLAY → GAMEPLAY transitions**: Camera position/rotation/FOV blending requires both source and target scenes to be `SceneType.GAMEPLAY` with cameras in "main_camera" group. UI → Gameplay or Gameplay → UI transitions will NOT blend cameras.

  **Requirements checklist**:
  - ✅ Both scenes have `SceneType.GAMEPLAY` in registry
  - ✅ Both scenes have Camera3D in "main_camera" group
  - ✅ Transition type is `"fade"` (not `"instant"` or `"loading"`)
  - ❌ UI scenes don't have cameras to blend

  **Problem**: Camera jumps instead of smooth interpolation.

  **Solution**: Verify all requirements met. Check camera is added to "main_camera" group in scene editor (Inspector → Node tab → Groups → Add "main_camera").

- **Camera blend runs in background, doesn't block state updates**: As of Phase 10, camera blending uses signal-based finalization (`Tween.finished` with `CONNECT_ONE_SHOT`) instead of blocking the transition. State dispatch happens immediately after scene load completes, camera blend continues in background.

  **Why it matters**: Tests should not wait for camera blend to complete - check `is_transitioning` immediately after scene load, not after camera finishes blending.

  **Impact**: Faster transitions, no artificial delays waiting for camera animation.

- **Transition queue handles concurrent transitions with priority sorting**: When multiple transitions are queued (e.g., rapid door triggers or death during scene load), `M_SceneManager` processes them by priority (`CRITICAL > HIGH > NORMAL`). Tests that spam transitions should verify the final scene matches the highest-priority request, not necessarily the last request.

  **Example**: If player triggers door (NORMAL) then dies mid-transition (CRITICAL), the death transition takes precedence and executes first when the door transition completes.

- **Scene cache eviction uses LRU strategy with dual limits**: The scene cache has TWO eviction triggers:
  1. **Count limit**: Max 5 cached scenes (hard limit)
  2. **Memory limit**: Max 100MB total cache size (soft limit)

  **LRU (Least Recently Used) behavior**: Oldest accessed scenes evict first when limits exceeded.

  **Gotcha**: Preloaded critical scenes (main_menu, pause_menu) still count toward cache limit. If you load 6 gameplay scenes, the first preloaded scene may be evicted and need to reload later.

  **Solution**: Set appropriate preload priorities (10 = always cached, 0 = never preloaded). Don't mark every scene as priority 10 or cache fills with rarely-used scenes.

- **Async loading progress requires explicit callbacks**: `ResourceLoader.load_threaded_get_status()` returns progress in `[0.0, 1.0]` range, but loading screens need callbacks to update UI. The `LoadingScreenTransition` polls progress and calls `update_progress_callback` regularly.

  **Problem**: Custom loading screens don't update progress bar.

  **Solution**: Implement `update_progress(progress: float)` method in loading screen script and connect to `LoadingScreenTransition` via callback pattern. See `scripts/scene_management/transitions/loading_screen_transition.gd` for reference.

- **Headless mode fallback**: ResourceLoader async loading (`load_threaded_request`) may fail in headless mode if no rendering backend is available. `M_SceneManager` detects stuck progress (progress doesn't change for multiple frames) and falls back to synchronous loading.

  **Impact on tests**: Tests run in headless mode use sync loading (instant), so async loading paths are not fully tested in CI. Manual testing in editor required to validate loading screen animations.

- **Scene triggers auto-hint preload on player proximity**: `C_SceneTriggerComponent` calls `M_SceneManager.hint_preload_scene()` when player enters the Area3D, triggering background load of target scene. This happens BEFORE player activates the trigger (walks through/presses 'E').

  **Benefit**: Door transitions feel instant because scene is already cached by the time player triggers transition.

  **Gotcha**: Rapid door approach + leave + approach may trigger multiple preload hints. `M_SceneManager` deduplicates requests (checks if scene already cached/loading before starting new async load).

- **Interactable events wrap payloads**: `U_ECSEventBus.publish()` wraps user payloads in an event dictionary (`{ "name": ..., "payload": ..., "timestamp": ... }`). When listening to `interact_prompt_show`, `interact_prompt_hide`, or `signpost_message`, unwrap `event["payload"]` before accessing controller data. Forgetting to unwrap leads to empty prompt text or missing controller IDs.

- **Controllers expect no authored components**: When using `E_*` interactable controllers, do NOT add `C_*` component nodes or extra `Area3D` children manually. Controllers assign `area_path` to the auto-managed volume and maintain state; authored extras create duplicate signals and inconsistent cooldowns.

- **Spawn marker positioning prevents ping-pong loops**: Place spawn markers 2-3 units OUTSIDE trigger zones, not inside. If spawn marker is inside trigger area, player spawns and immediately re-triggers the door, causing rapid back-and-forth transitions.

  **Example (WRONG)**:
  ```
  [Door Trigger Zone @ X=0, radius=2]
    └─ sp_exit_from_house @ X=0 (inside zone, immediate re-trigger)
  ```

  **Example (CORRECT)**:
  ```
  [Door Trigger Zone @ X=0, radius=2]
  ← sp_exit_from_house @ X=4 (outside zone, player has time to move away)
  ```

- **Cooldown duration must exceed transition duration**: If `C_SceneTriggerComponent.cooldown_duration` is shorter than transition duration (e.g., cooldown=0.5s, fade transition=0.2s), player can re-trigger during the fade-in phase after spawning.

  **Recommended minimum**: `cooldown_duration = 1.0` seconds (gives player time to see new environment before trigger reactivates).

- **Test coverage note - Tween timing tests pending in headless mode**: Some transition timing tests are marked pending because Tween animations don't run consistently in headless mode (requires GPU rendering for accurate frame timing).

  **Pending tests** (4 total, expected):
  - `test_fade_transition_uses_tween`
  - `test_input_blocking_enabled`
  - `test_fade_transition_easing`
  - `test_transition_cleans_up_tween`

  **Not a failure**: These tests pass when run in Godot editor with rendering enabled. Manual validation required for visual polish.

- **Scene registry validation happens at startup**: `M_SceneManager._ready()` calls `U_SceneRegistry.validate_door_pairings()` to check all door targets exist. Invalid pairings log errors but don't crash.

  **Example error**: `"Door 'door_to_house' targets scene 'interior_house' which is not registered"`

  **Solution**: Check console logs at startup for validation errors. Fix by registering missing scenes or correcting door_id/target_scene_id in `C_SceneTriggerComponent`.

## Input System Pitfalls

- **Avoid clobbering test-driven input state**: In headless tests there is no real keyboard/mouse input, but tests may set `gameplay.move_input`, `look_input`, and `jump_pressed` directly to validate persistence across transitions. If `S_InputSystem` dispatches zeros every frame, it will overwrite these values and break tests. To prevent this, `S_InputSystem` only dispatches when `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED` (i.e., gameplay with cursor locked by `M_CursorManager`). This keeps tests deterministic while preserving correct behavior in real gameplay.

## Test Coverage Status

As of 2025-11-03 (Phase 10 Complete - Scene Manager Finished):
- **Total Tests**: 502/506 tests passing (99.2%), 4 pending (Tween timing in headless mode)
- **Total Assertions**: 1349
- **Test Execution Time**: ~54 seconds for full suite
- **Test Breakdown**:
  - Cursor Manager: 13/13 ✅
  - ECS: 62/62 ✅
  - State: 104/104 ✅
  - Utils: 11/11 ✅
  - Unit/Integration: 12/12 ✅
  - Integration: 10/10 ✅
  - **Scene Manager (Phases 0-10)**:
    - Integration: 13 (basic transitions) ✅
    - Integration: 8 (state persistence) ✅
    - Integration: 16 (pause system) ✅
    - Integration: 9 (area transitions) ✅
    - Integration: 10 (scene preloading) ✅
    - Integration: 6 (camera blending) ✅
    - Integration: 15 (edge cases) ✅
    - M_SceneManager: 23 ✅
    - U_SceneRegistry: 19 ✅
    - Scene Reducer: 10 ✅
    - Transition Effects: 16 (4 pending - Tween timing)
  - **Gameplay Mechanics (Phase 8.5)**:
    - Health System: tests integrated ✅
    - Damage System: tests integrated ✅
    - Victory System: tests integrated ✅
  - **End-Game Flows (Phase 9)**:
    - Death/victory/credits integration: tests integrated ✅
- **Status**: All tests passing except 4 expected pending (Tween timing in headless mode)

Test directories:
- `tests/unit/ecs` - ECS component and system tests
- `tests/unit/state` - State management tests
- `tests/unit/integration` - ECS/State coordination tests
- `tests/integration/scene_manager` - Scene Manager integration tests
- `tests/integration/gameplay` - Gameplay mechanics integration tests
- `tests/unit/utils` - Utility tests

All critical paths tested including error conditions, edge cases, integration scenarios, scene restructuring patterns, camera blending, async loading, cache management, and end-game flows.
- **No C-style ternaries**: GDScript 4.5 rejects `condition ? a : b`. Use the native `a if condition else b` form and keep payload normalization readable.
- **Keep component discovery consistent**: Decoupled components (e.g., `C_MovementComponent`, `C_JumpComponent`, `C_RotateToInputComponent`, `C_AlignWithSurfaceComponent`) now auto-discover their peers, but components that still export NodePaths for scene nodes (landing indicator markers, floating raycasts, etc.) require those paths to be wired. Mixing patterns silently disables behaviour and breaks tests.
- **Reset support timers after jumps**: When modifying jump logic, remember to clear support/apex timers just like `C_JumpComponent.on_jump_performed()` does. Forgetting this can enable double jumps that tests catch.
- **Second-order tuning must respect clamped limits**: While tweaking response/damping values, verify they still honour `max_turn_speed_degrees` and `max_speed`. Oversight here reintroduces overshoot regressions covered by rotation/movement tests.
 - **ECS components require an entity root**: `M_ECSManager` associates components to entities by walking ancestors and picking the first node whose name starts with `E_`. If a component is not under such a parent, registration logs `push_error("M_ECSManager: Component <Name> has no entity root ancestor")` and the component is not tracked for entity queries. In tests and scenes, create an entity node (e.g., `var e := Node.new(); e.name = "E_Player"; e.add_child(component)`).
 - **Registration is deferred; yield a frame**: `ECSComponent._ready()` uses `call_deferred("_register_with_manager")`. After adding a manager/component, `await get_tree().process_frame` before asserting on registration (`get_components(...)`) or entity tracking to avoid race conditions.
 - **Required settings block registration**: Components like `C_JumpComponent`, `C_MovementComponent`, `C_FloatingComponent`, and `C_AlignWithSurfaceComponent` validate that their `*Settings` resources are assigned. Missing settings produce a `push_error("<Component> missing settings; assign an <Resource>.")` and skip registration. Wire default `.tres` in scenes, or set `component.settings = RS_*Settings.new()` in tests.
 - **Input.mouse_mode changes may need a frame**: When toggling cursor lock/visibility rapidly (e.g., calling `toggle_cursor()` twice), yield a frame between calls in tests to let `Input.mouse_mode` settle on headless runners. Example: `manager.toggle_cursor(); await get_tree().process_frame; manager.toggle_cursor(); await get_tree().process_frame`.
- **Camera-relative forward uses negative Z**: Our input vector treats `Vector2.UP` (`y = -1`) as forward. When converting to camera space (see `S_MovementSystem`), multiply the input’s Y by `-1` before combining with `cam_forward`, otherwise forward/backward movement inverts.
