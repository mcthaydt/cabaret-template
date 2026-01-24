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

- **Refresh UID cache after moving scenes**: Moving `.tscn` files can leave `.godot/uid_cache.bin` pointing at old paths, which triggers instance warnings like "node ... has been removed or moved" and causes missing nodes in headless tests. **Fix**: refresh the UID cache by opening the project once in the editor or running:
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
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

## GDScript Typing Pitfalls

- **New `class_name` types can break type hints in headless tests**: When adding a brand-new helper script with `class_name Foo`, using `Foo` as a member variable annotation in an existing script can fail to parse under headless GUT runs (`Parse Error: Could not find type "Foo" in the current scope`). Prefer untyped members (or a base type like `RefCounted`) and instantiate via `preload("...").new()` until the class is reliably discovered/loaded.

- **Child scripts cannot redeclare parent members (incl. `const`)**: If a base class defines a member like `const U_Foo := preload("...")`, declaring another `const U_Foo := ...` in a derived script causes a parse error (`The member "U_Foo" already exists in parent class ...`). Prefer inheriting the constant, or use a different name in the child.

## Asset Import Pitfalls (Headless Tests)

- **New assets used with `preload()` can fail until `.import` files exist**: If you add a new `*.ogg`, `*.png`, etc and immediately reference it via `preload("res://...")`, headless GUT runs can fail because Godot hasn’t generated the sidecar `*.import` file yet.
  - **Fix**: Run a one-time import pass before running tests: `HOME="$PWD/.godot_user" /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
  - Commit the generated `*.import` files (next to the asset); do not commit `.godot/imported` (it is cache and ignored).

## Test Execution Pitfalls

- **GUT needs recursive dirs**: `-gdir` is not recursive by default; suites in nested folders are silently skipped if you point at a parent. Always pass each test root explicitly (e.g., `-gdir=res://tests/unit -gdir=res://tests/integration`) or list the concrete leaf directories you added to ensure new suites actually run.

## UI Navigation Pitfalls (Gamepad/Joystick)

### Focus Sound Arming (Phase 7 - UI Audio)

- **BasePanel focus sound is input-gated**: `BasePanel` only plays the focus sound when a focus change was preceded by player navigation input (and analog stick navigation arms at the actual focus move point).
  - If a `BasePanel` subclass overrides `_input(event)`, it must call `super._input(event)` (or conditionally call it when not capturing input) or keyboard/D-pad focus moves will become silent.

### UI Navigation Deadzone Consistency

- **Problem**: Inconsistent deadzone values between InputMap actions and device detection cause unpredictable gamepad navigation behavior. If `ui_up/down/left/right` actions use a 0.2 deadzone while device detection uses 0.25, analog stick values between 0.2-0.25 will trigger navigation but might not register as device input, creating timing inconsistencies. Additionally, stick drift (typical range 0.15-0.2) can cause false navigation triggers with low deadzones.

- **Solution**: Standardize all UI navigation actions and device detection to use **0.25 deadzone**:
  - In `project.godot`, set `"deadzone": 0.25` for `ui_up`, `ui_down`, `ui_left`, `ui_right`
  - Match `M_InputDeviceManager.DEVICE_SWITCH_DEADZONE = 0.25`
  - This threshold is above typical stick drift (0.15-0.2) while remaining responsive

- **Why 0.25**:
  - Industry standard for reliable gamepad navigation
  - Above typical controller stick drift threshold
  - Prevents false triggers from controller calibration variance
  - Provides consistent "device switched" + "navigation input" timing

- **Code Example**:
  ```gdscript
  # project.godot (for each ui_* action)
  ui_up={
  "deadzone": 0.25,  # Must match DEVICE_SWITCH_DEADZONE
  "events": [...]
  }

  # M_InputDeviceManager.gd
  const DEVICE_SWITCH_DEADZONE: float = 0.25
  ```

- **Testing**: Run `tests/unit/ui/test_joystick_navigation_deadzone.gd` to verify all ui_* actions have correct deadzone and that stick drift values don't trigger navigation.

### Overlays with Custom Navigation Must Override _navigate_focus

- **Problem**: When an overlay (like InputProfileSelector) needs custom joystick navigation behavior, setting focus neighbors causes the parent menu's analog stick repeater to also process the same input, creating a conflict where both menus try to navigate simultaneously. This happens because both `BaseMenuScreen` instances (parent menu and overlay) run their own `_process()` loops with analog stick repeaters.

- **Symptom**: Navigation appears to work for one frame, then immediately reverses or toggles rapidly. Logs show both parent and overlay calling `_navigate_focus()` for the same input event.

- **Solution**: When an overlay needs custom navigation behavior:
  1. **Override `_navigate_focus(direction: StringName)`** to handle all navigation manually
  2. **Do NOT set focus neighbors** using `U_FocusConfigurator` or manually - leave them empty
  3. **Handle all directions explicitly** in the override and return early without calling `super._navigate_focus(direction)`

  ```gdscript
  # InputProfileSelector example - custom left/right for cycling, up/down for navigation
  func _navigate_focus(direction: StringName) -> void:
      var focused := get_viewport().gui_get_focus_owner()

      # Handle left/right on ProfileButton: cycle profiles (matches slider UX)
      if focused == _profile_button and (direction == "ui_left" or direction == "ui_right"):
          if direction == "ui_left":
              _cycle_profile(-1)
          else:
              _cycle_profile(1)
          return  # Don't call super - prevents other repeaters/parents from also processing

      # For any other cases, use default behavior
      super._navigate_focus(direction)

  func _configure_focus_neighbors() -> void:
      # Configure focus neighbors normally so ui_up/ui_down moves between rows.
      # Only override the custom directions (above).
      ...
  ```

- **Why this works**: Without focus neighbors set, the parent menu's `_navigate_focus()` finds no valid `focus_neighbor_left/right` paths and does nothing. Only the overlay's override processes the input.

- **When to use**: Any overlay that needs non-standard navigation (cycling values, custom layouts) instead of simple focus neighbor traversal.

- **Real example**: `scripts/ui/ui_input_profile_selector.gd` - Uses left/right to cycle through profile names on the focused ProfileButton, while focus neighbors handle up/down navigation between UI rows.

### Avoid Await Before Wiring UI Signals

- **Problem**: Awaiting (e.g., `await get_tree().process_frame`) before connecting critical UI signals can create a 1+ frame window where buttons emit `pressed` but nothing is listening yet.

- **Symptom**: Tests (or very fast user input) can press Apply/Close immediately after an overlay is created and the handler never fires, leaving the overlay stuck on the stack.

- **Solution**:
  1. Connect critical signals first (buttons, toggles) at the top of `_ready()` / `_on_panel_ready()`.
  2. If dependencies initialize asynchronously (store/managers), make the handler defensive (lazy-resolve dependency and/or repopulate state before acting).

  ```gdscript
  func _on_panel_ready() -> void:
      _apply_button.pressed.connect(_on_apply_pressed)  # connect first
      _manager = _resolve_manager()  # may be null, handler can re-resolve

  func _on_apply_pressed() -> void:
      if _manager == null:
          _manager = _resolve_manager()
      if _available_profiles.is_empty():
          _populate_profiles()
      _manager.switch_profile(_available_profiles[_current_index])
  ```

### Explicit Focus Neighbor Configuration

- **Problem**: Godot's automatic focus neighbor calculation can be unreliable with complex UI layouts, causing unexpected focus jumps or broken gamepad navigation. Auto-calculated paths may skip controls, jump to non-adjacent elements, or fail entirely in nested container hierarchies.

- **Solution**: Explicitly configure `focus_neighbor_top/bottom/left/right` properties using `U_FocusConfigurator` helper:
  ```gdscript
  # scripts/ui/helpers/u_focus_configurator.gd

  # For vertical lists (main menu, pause menu)
  var buttons: Array[Control] = [play_button, settings_button, quit_button]
  U_FocusConfigurator.configure_vertical_focus(buttons, true)  # true = wrap navigation

  # For horizontal lists (endgame button rows)
  var buttons: Array[Control] = [retry_button, menu_button]
  U_FocusConfigurator.configure_horizontal_focus(buttons, true)

  # For grids (settings panels, inventories)
  var grid: Array = [[btn1, btn2], [btn3, btn4]]
  U_FocusConfigurator.configure_grid_focus(grid, true, true)  # wrap_vert, wrap_horiz
  ```

- **When to use**:
  - Call `_configure_focus_neighbors()` in `_ready()` or `_on_panel_ready()` after `@onready` vars are initialized
  - Use for all UI screens with gamepad navigation (main menu, pause, settings, endgame)
  - Prefer explicit configuration over relying on Godot's auto-calculation

- **Wrapping behavior**: With `wrap=true`, pressing up on the first control focuses the last (and vice versa), creating circular navigation. Disable wrapping for non-circular flows.

- **Real examples**:
  - `scripts/ui/main_menu.gd` - Vertical focus for Play/Settings buttons
  - `scripts/ui/pause_menu.gd` - Vertical focus for 7 menu options
  - `scripts/ui/game_over.gd` - Horizontal focus for Retry/Menu buttons

### Dynamic Button Visibility and Focus Chains

- **Problem**: When using `U_FocusConfigurator.configure_horizontal_focus()` or `configure_vertical_focus()` with controls that may be hidden at runtime, the helper still wires focus neighbors for ALL controls passed in. If one of those controls later becomes invisible (e.g., `Edit Layout` hidden in touchscreen settings when opened from main menu), gamepad navigation will try to move focus into an invisible control, causing the focus “cursor” to appear stuck or to skip visible buttons unexpectedly.

- **Solution**:
  - Always build the focus list from **visible** controls only. Filter out any controls where `control.visible == false` before calling `U_FocusConfigurator`.
  - When visibility changes at runtime (e.g., toggling a button on/off based on shell or device type), immediately re-run `_configure_focus_neighbors()` so focus neighbors match the new layout.
  - Use the same pattern for bottom-row button bars (Cancel/Reset/Apply) and tab strips so that hiding a single button never leaves it in the focus chain.

- **Why it matters**:
  - BaseMenuScreen’s analog stick navigation relies entirely on focus neighbors. If hidden controls remain in the neighbor chain, navigation appears broken even though the buttons still work when clicked.
  - This surfaced in `TouchscreenSettingsOverlay`: `Edit Layout` is hidden in main-menu flow, but remained in the horizontal focus list. The fix was to include only visible buttons when configuring focus and to re-run configuration whenever `Edit Layout` visibility changes.

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

## Save Manager Pitfalls (Phase 13 Complete)

- **Autosave requires navigation.shell == "gameplay"**
  - U_AutosaveScheduler blocks autosaves when `navigation.shell != "gameplay"` to prevent saves during menus/UI
  - **Testing pitfall**: Tests that trigger autosave events must dispatch `U_NavigationActions.set_shell(StringName("gameplay"), StringName("scene_id"))` first, or autosave will silently fail
  - Example:
    ```gdscript
    # ❌ WRONG - autosave won't trigger (shell defaults to empty or "main_menu")
    U_ECSEventBus.publish(StringName("checkpoint_activated"), {...})

    # ✅ CORRECT - set navigation shell to gameplay first
    store.dispatch(U_NavigationActions.set_shell(StringName("gameplay"), StringName("gameplay_base")))
    await get_tree().physics_frame
    U_ECSEventBus.publish(StringName("checkpoint_activated"), {...})
    ```

- **Don't bypass M_SaveManager for saves**
  - `M_StateStore.save_state(filepath)` writes raw state without header metadata, migrations, or atomic writes
  - **Always use** `M_SaveManager.save_to_slot(slot_id)` for production saves to get:
    - Header metadata (version, timestamp, playtime, scene context)
    - Atomic writes with `.bak` backup
    - Migration support for future schema changes
  - Example:
    ```gdscript
    # ❌ WRONG - bypasses save manager (no header, no migrations, no atomic writes)
    store.save_state("user://manual_save.json")

    # ✅ CORRECT - uses save manager with full feature set
    var save_manager := U_ServiceLocator.get_service(StringName("save_manager")) as M_SaveManager
    save_manager.save_to_slot(StringName("slot_01"))
    ```

- **Autosave blocking conditions**
  - Autosave is suppressed when:
    - `gameplay.death_in_progress == true` (prevents "bad autosave" during death)
    - `scene.is_transitioning == true` (prevents inconsistent snapshot during transition)
    - `M_SaveManager.is_locked()` (save/load already in progress)
  - These are **intentional blocks** to ensure save quality, not bugs
  - Don't try to work around these blocks; let the autosave scheduler handle timing

- **Entity ID for gameplay actions (testing)**
  - `U_GameplayActions.take_damage(entity_id, amount)` expects either:
    - Empty string `""` (reducer applies to player)
    - `"E_Player"` (default player entity ID from `RS_GameplayInitialState`)
  - **Testing pitfall**: Using `"player"` or other incorrect IDs will silently fail to apply damage
  - Example:
    ```gdscript
    # ❌ WRONG - entity_id doesn't match player_entity_id
    store.dispatch(U_GameplayActions.take_damage("player", 50.0))  # No effect!

    # ✅ CORRECT - empty string applies to player
    store.dispatch(U_GameplayActions.take_damage("", 50.0))

    # ✅ CORRECT - explicit player entity ID
    store.dispatch(U_GameplayActions.take_damage("E_Player", 50.0))
    ```

## VFX Gating Pitfalls

- **Player-only gating blocks when `player_entity_id` is missing**:
  - `M_VFXManager` filters requests via `gameplay.player_entity_id`. If it is empty/missing, VFX requests are ignored.
- **Transition gating blocks outside gameplay shell**:
  - VFX is blocked when `navigation.shell != "gameplay"`, `scene.is_transitioning == true`, or `scene.scene_stack` is not empty.
- **Testing setup**:
  - Integration tests using `M_StateStore` must set `gameplay_initial_state.player_entity_id` and `navigation_initial_state.shell = "gameplay"` (or dispatch `U_NavigationActions.set_shell(...)`) before publishing VFX requests, otherwise gating will silently block effects.

## Dependency Lookup Rule

- **Standard chain (preferred)**:
  1. `@export` injection (tests)
  2. `U_ServiceLocator.try_get_service(StringName("..."))` (production)
  3. Group lookup / tree traversal only as a compatibility fallback

- **State store**:
  - Required callers: `U_StateUtils.get_store(node)` / `U_StateUtils.await_store_ready(node)`
  - Optional callers (standalone scenes / editor-opened gameplay scenes): `U_StateUtils.try_get_store(node)` to avoid noisy errors

- **Avoid ad-hoc group scanning in leaf nodes**: Prefer the standard chain for managers like `scene_manager`, `input_profile_manager`, `input_device_manager`, etc. Only drop to `get_tree().get_first_node_in_group(...)` when ServiceLocator may not be initialized (tests / isolated scenes).

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
- Interactable controllers refuse to fire while `M_SceneManager` (or the scene slice) reports `is_transitioning`. When debugging a “stuck” interact prompt, confirm the active transition finished before calling `activate()`.
- Passive volumes (hazards, checkpoints, victory zones) must re-arm and detect spawn-inside overlaps. Leave `ignore_initial_overlap` disabled for these controllers; only doors / INTERACT prompts keep it enabled to avoid instant re-activation.
- Per-instance trigger settings must be unique. Controllers automatically duplicate shared `.tres` references and set `resource_local_to_scene = true`; avoid manually reusing the same resource via code or editor overrides, otherwise one instance will mutate all others.
- Trigger volumes now clamp `player_mask` to at least `1`. If you intentionally need a different mask, update the settings resource—forcing the mask to `0` will be ignored.

## GDScript Language Pitfalls

- **Don't preload script files as type constants when using class_name**: When a script defines `class_name MyClass`, don't create a constant that preloads the script file itself (`const MyClass := preload("res://path/to/my_class.gd")`). This creates a type conflict where Godot sees preloaded resources as generic `Resource` instead of the specific class type, causing "Invalid type in function" errors when passing them to typed parameters.

  **Problem**: Type checking fails when passing preloaded `.tres` resources to functions expecting the class type:
  ```gdscript
  # WRONG - creates type conflict:
  const RS_UIScreenDefinition := preload("res://scripts/ui/resources/rs_ui_screen_definition.gd")
  const MAIN_MENU := preload("res://resources/ui_screens/main_menu.tres")

  static func register(definition: RS_UIScreenDefinition) -> void:
      # ...

  register(MAIN_MENU)  # ERROR: Resource is not a subclass of expected argument class
  ```

  **Solution**: Remove the script preload constant. The `class_name` directive makes the class globally available:
  ```gdscript
  # CORRECT - use class_name directly:
  # (RS_UIScreenDefinition is already available via class_name in the script)
  const MAIN_MENU := preload("res://resources/ui_screens/main_menu.tres")

  static func register(definition: RS_UIScreenDefinition) -> void:
      # ...

  register(MAIN_MENU)  # Works correctly
  ```

  **Real example**: `U_UIRegistry.gd` had `const RS_UIScreenDefinition := preload(...)` which conflicted with the `class_name RS_UIScreenDefinition` in the resource script. Removing the preload constant fixed the type checking error.

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

  **Parser warnings indicate this issue**: GDScript 4.5+ emits `CONFUSABLE_CAPTURE_REASSIGNMENT` warnings when lambdas reassign captured primitives. If you see "Reassigning lambda capture does not modify the outer local variable" in diagnostics, switch to Array wrapper pattern immediately to prevent silent test failures.
- **Always add explicit types when pulling Variants**: Helpers such as `C_InputComponent.get_move_vector()` or `Time.get_ticks_msec()` return Variants. Define locals with `: Vector2`, `: float`, etc., instead of relying on inference, otherwise the parser fails with "typed as Variant" errors.
- **Annotate Callable results**: `Callable.call()` and similar helpers also return Variants. When reducers or action handlers return dictionaries, capture them with explicit types (e.g., `var next_state: Dictionary = root.call(...)`) so tests load without Variant inference errors.
- **Respect tab indentation in scripts**: Godot scripts under `res://` expect tabs. Mixing spaces causes parse errors that look unrelated to the actual change, so configure your editor accordingly before editing `.gd` files.
- **Don't call `super._exit_tree()` unless the parent script defines it**: Calling `super._exit_tree()` only works when the parent script implements `_exit_tree()`. If the parent script does not define it, Godot fails to compile with `Cannot call the parent class' virtual function "_exit_tree()" because it hasn't been defined.` Prefer omitting the `super` call or adding an `_exit_tree()` stub to the parent script.

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

- **Input processing order matters**: Godot processes input in a specific order: `_input()` → `_gui_input()` → `_unhandled_input()`. If one system calls `set_input_as_handled()` in `_unhandled_input()`, other systems using `_unhandled_input()` may never see the input. **Solution**: Systems that need priority access to input should use `_input()` instead of `_unhandled_input()`. Example: M_PauseManager uses `_input()` to process pause before M_CursorManager (which uses `_unhandled_input()`) can consume it. Both call `set_input_as_handled()` to prevent further propagation.

- **Single source of truth for ESC/pause**: To avoid double-toggles, route ESC/pause through `M_SceneManager` only when it is present. `M_PauseManager` now defers input handling if a Scene Manager exists and should only be used as a fallback (or via direct `toggle_pause()` in tests). Ensure the InputMap maps `pause` to ESC for consistency (project.godot already does).

## GUT Testing Pitfalls

- **Expected errors must use assert_push_error() AFTER the action**: When testing code that intentionally triggers `push_error()`, call `assert_push_error("error pattern")` immediately AFTER the action that causes the error, not before. Example:
  ```gdscript
  var result := ActionRegistry.validate_action(invalid_action)
  assert_push_error("Action missing 'type' field")  # After validation
  assert_false(result)
  ```
  **Wrong**: `gut.p("Expect error...")` before the action - this doesn't work and will show "Unexpected Errors".
- **Prefer `print()` for temporary diagnostics**: GUT buffers its own `gut.p()` output and the CLI harness discards it in failures, which makes debugging harder. Emit short, prefixed messages with `print()` instead so they appear in the raw Godot log and in failing test transcripts. Remember to remove or guard noisy prints before merging.
- **State handoff persists across tests**: `M_StateStore` restores slices from `U_StateHandoff` on `_ready()`. If a previous test left the store mid-transition, the next store instance inherits that old state. Call `U_StateHandoff.clear_all()` in `before_each` / `after_each` whenever a test instantiates `M_StateStore` to guarantee a clean slate.

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

- **Moving `class_name` scripts can require cache regeneration**: Godot caches global script classes and resource UIDs under `.godot/` (ignored by git). If you move or rename a script that declares `class_name` (e.g., `RS_*` resources), headless loads can still point at the old path and `.tres`/`.tscn` parsing can fail.
  - Fix: delete `.godot/global_script_class_cache.cfg` and `.godot/uid_cache.bin` (they regenerate), or open the project in the editor once to refresh caches, then rerun `tools/run_gut_suite.sh`.
  - Symptom: errors like “Could not parse global class `RS_*` from `res://old/path.gd`” or “[ext_resource] referenced non-existent resource”.

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

- **Fade transitions need adequate wait time in tests**: Trans_Fade duration defaults to 0.2 seconds. Tests using fade transitions must wait at least 15 physics frames (0.25s at 60fps) for completion. Waiting only 4 frames (0.067s) will cause assertions to run before transitions complete, resulting in `is_transitioning` still being true or `current_scene_id` not yet updated. Use `await wait_physics_frames(15)` after fade transitions in tests.

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

- **Async loading progress requires explicit callbacks**: `ResourceLoader.load_threaded_get_status()` returns progress in `[0.0, 1.0]` range, but loading screens need callbacks to update UI. The `Trans_LoadingScreen` polls progress and calls `update_progress_callback` regularly.

  **Problem**: Custom loading screens don't update progress bar.

  **Solution**: Implement `update_progress(progress: float)` method in loading screen script and connect to `Trans_LoadingScreen` via callback pattern. See `scripts/scene_management/transitions/trans_loading_screen.gd` for reference.

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

- **Do not gate mobile gamepad input on cursor capture**: On mobile platforms there is no meaningful mouse cursor, so `Input.mouse_mode` is not a reliable signal. Gating `S_InputSystem` on `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED` will silently block Bluetooth gamepad input on mobile while still hiding the touchscreen UI (MobileControls). The fix pattern is: only apply the cursor-capture gate on non-mobile platforms (`if not OS.has_feature("mobile")`), so mobile gamepad input continues to flow even when the virtual controls are hidden.

- **Godot auto-converts touch to mouse events on mobile, causing device type flicker**: On Android/iOS, Godot automatically synthesizes `InputEventMouseButton` and `InputEventMouseMotion` from `InputEventScreenTouch` and `InputEventScreenDrag` for compatibility. If `M_InputDeviceManager` processes both the original touch event AND the emulated mouse event, the device type will flicker between `TOUCHSCREEN` (2) and `KEYBOARD_MOUSE` (0) on every touch, causing UI buttons that are conditionally shown based on device type to hide mid-press and cancel touch events.

  **Problem**: Tapping a button that's only visible when `device_type == TOUCHSCREEN` (like the touchscreen settings button in pause menu):
  1. Touch begins → `InputEventScreenTouch` → device type set to TOUCHSCREEN → button visible ✓
  2. Godot emulates mouse → `InputEventMouseButton` → device type set to KEYBOARD_MOUSE → button hidden ✗
  3. Button becomes invisible mid-touch, Godot cancels the press, `pressed` signal never fires
  4. Touch ends → `InputEventScreenTouch` → device type back to TOUCHSCREEN → button visible again (but press was already canceled)

  **Symptom**: Button receives `gui_input` events (touch press/release detected) but `pressed` signal never fires. Rapid visibility toggling in logs (visible→hidden→visible) when tapping.

  **Solution**: In `M_InputDeviceManager._input()`, ignore emulated mouse events on mobile platforms:
  ```gdscript
  elif event is InputEventMouseButton:
      var mouse_button := event as InputEventMouseButton
      if not mouse_button.pressed:
          return
      # CRITICAL FIX: Ignore mouse events emulated from touch on mobile
      # Godot automatically converts touch to mouse for compatibility, but we handle
      # touch separately. This prevents device type from flickering 2→0→2 on touch.
      if OS.has_feature("mobile") or OS.has_feature("web"):
          return
      _handle_keyboard_mouse_input(mouse_button)

  elif event is InputEventMouseMotion:
      var mouse_motion := event as InputEventMouseMotion
      if mouse_motion.relative.length_squared() <= 0.0:
          return
      # CRITICAL FIX: Ignore mouse motion emulated from touch on mobile
      if OS.has_feature("mobile") or OS.has_feature("web"):
          return
      _handle_keyboard_mouse_input(mouse_motion)
  ```

  **Why this works**: On mobile, only `InputEventScreenTouch`/`InputEventScreenDrag` trigger device detection, keeping device type stable at `TOUCHSCREEN`. On desktop, mouse events still work normally (no `mobile` feature flag). Buttons stay visible throughout the entire touch interaction, allowing Godot's button press detection to complete normally.

  **Alternate manifestation**: This same bug can affect ANY UI element that conditionally shows/hides based on `device_type` - not just buttons. If a control becomes invisible during an interaction due to device type flickering, the interaction will be canceled mid-gesture.

- **MobileControls visibility depends on navigation shell**: `MobileControls._update_visibility()` only shows controls when the navigation slice reports `shell == SHELL_GAMEPLAY` (or an empty shell with `force_enable` in very early boot). In tests that construct `M_StateStore` manually, forgetting to wire `navigation_initial_state` (via `RS_NavigationInitialState`) and/or dispatch `U_NavigationActions.start_game(...)` leaves `shell == "main_menu"`, so MobileControls stays hidden even if `device_type == TOUCHSCREEN` and `force_enable == true`. Fix pattern: for touchscreen or MobileControls tests, always provide a navigation slice and move it into gameplay before instantiating MobileControls; in production, let the Scene Manager drive navigation state instead of bypassing it.

- **Pause is the only reserved binding**: `pause/ui_pause/ui_cancel` must keep ESC (keyboard) and Start (gamepad). RS_RebindSettings marks pause as non-rebindable; do not strip ESC/Start from `project.godot` or InputMap initialization when adding new actions. Both bindings are required for UI Manager navigation flows and tests.

- **Mobile emulation flag is for desktop QA only**: Use `--emulate-mobile` to smoke test touchscreen UI on desktop; real device runs remain the source of truth. Do not ship builds with emulation flags enabled, and remember that device detection still relies on `M_InputDeviceManager` even when emulating.

## UI Manager / Input Manager Boundary (Phase 4b - T075)

The Input Manager and UI Manager have clear, separated responsibilities. Violating this boundary causes double-handling, race conditions, and unpredictable pause behavior.

### Input Manager Responsibilities (What Input Manager DOES)

- **Hardware → Action Mapping**: Translate physical input (keyboard, gamepad, touch) into `ui_*` actions and gameplay actions
- **Device Detection**: Track active device type (keyboard/mouse, gamepad, touchscreen) via `M_InputDeviceManager`
- **Action Context**: Determine which actions are available based on device capabilities
- **Rebinding**: Handle input remapping through `M_InputProfileManager` and Redux state

**Input Manager does NOT**:
- ❌ Make UI navigation decisions (which overlay to open, when to pause)
- ❌ Directly call `M_SceneManager.push_overlay()` or `pop_overlay()`
- ❌ Handle ESC/pause keys to toggle pause state
- ❌ Know about navigation slice or UI flow

### UI Manager Responsibilities (What UI Manager DOES)

- **Navigation State**: Own the `navigation` slice (shells, overlays, panels) as source of truth
- **UI Flow Logic**: Decide when to open pause, which overlay to show, return vs resume behavior
- **Navigation Actions**: All UI flow changes go through `U_NavigationActions` (open_pause, close_top_overlay, etc.)
- **Reconciliation**: `M_SceneManager` reconciles navigation state to scene tree (push/pop overlays to match state)

**UI Manager does NOT**:
- ❌ Read raw input events (`InputEventKey`, `InputEventJoypadButton`) to detect ESC/pause
- ❌ Map hardware buttons to actions (that's Input Manager's job)
- ❌ Directly control cursor lock/visibility (delegates to `M_CursorManager` via `M_PauseManager`)

### System-Level Responsibilities (Phase 4b Refactor)

**M_PauseManager** (T070):
- Subscribes to `navigation` slice, NOT raw input
- Derives pause state from `U_NavigationSelectors.is_paused(state)`
- Applies engine-level pause (`get_tree().paused = is_paused`)
- Coordinates cursor state with `M_CursorManager` (paused = visible, unpaused = hidden)
- Emits `pause_state_changed` signal for other systems

**M_CursorManager** (T071):
- Exposes `set_cursor_state(locked, visible)`, `set_cursor_locked()`, `set_cursor_visible()`
- Reacts ONLY to explicit calls from `M_PauseManager` or `M_SceneManager`
- Does NOT listen to pause/ESC input directly

**M_SceneManager** (T072):
- Removed `_input()` ESC/pause handling (was lines 194-230)
- Reconciles navigation slice state to scene tree (overlays, base scenes)
- Defers overlay reconciliation during base scene transitions (`_is_processing_transition` guard)
- All pause/overlay behavior driven by navigation actions + reconciliation

### Correct Flow Examples

**Opening Pause (Gameplay)**:
```gdscript
# ❌ WRONG (old pattern, removed in T070-T072):
func _input(event):
    if event.is_action_pressed("pause"):
        M_SceneManager.push_overlay("pause_menu")

# ✅ CORRECT:
# 1. M_UIInputHandler or virtual button dispatches action:
store.dispatch(U_NavigationActions.open_pause())

# 2. Navigation reducer updates state:
# navigation.overlay_stack = ["pause_menu"]

# 3. M_PauseManager sees navigation change:
# U_NavigationSelectors.is_paused(state) == true → sets get_tree().paused = true

# 4. M_SceneManager reconciles overlays:
# Pushes "pause_menu" scene to UIOverlayStack to match navigation state
```

**Closing Pause**:
```gdscript
# ✅ User presses back button in pause menu:
store.dispatch(U_NavigationActions.close_pause())
# → Navigation reducer clears overlay_stack
# → M_PauseManager sets get_tree().paused = false
# → M_SceneManager pops overlay to match empty stack
```

### Common Mistakes

1. **Handling pause in multiple places**: Don't add pause logic to both Input Manager systems AND UI controllers. Pause flows through navigation actions ONLY.

2. **Bypassing navigation state**: Don't call `M_SceneManager.push_overlay()` directly from UI controllers. Dispatch `U_NavigationActions.open_overlay(screen_id)` instead.

3. **Reading input in UI controllers**: Don't check `Input.is_action_pressed("ui_cancel")` in UI scripts. React to navigation state changes or let M_UIInputHandler handle input.

4. **Ignoring transition state**: Overlay reconciliation defers during base scene transitions. Don't assume pause overlays push immediately—reconciliation may be deferred.

5. **Pause system initialization timing**: M_PauseManager must initialize synchronously (not async) to subscribe to state updates before M_SceneManager syncs overlay state in its `_ready()`. Async initialization causes the pause system to miss initial state changes. See "M_PauseManager Initialization Timing" section below.

### Testing Patterns (Phase 4b)

When testing pause/UI flows:
```gdscript
# ✅ Setup navigation slice in tests:
_store.navigation_initial_state = RS_NavigationInitialState.new()

# ✅ Trigger pause via actions, not input events:
_store.dispatch(U_NavigationActions.open_pause())
await wait_physics_frames(2)

# ❌ Don't call removed methods:
_scene_manager._input(event)  # Removed in T072
_cursor_manager.toggle_cursor()  # Removed in T071
```

### M_PauseManager Initialization Timing

**Problem**: M_PauseManager may miss state updates if initialization is async

The pause system subscribes to `scene.slice_updated` to detect overlay changes and apply engine pause. If initialization uses `await get_tree().process_frame`, the following race condition occurs:

1. M_PauseManager added to tree → `_ready()` starts → awaits frame (paused in middle of `_ready()`)
2. M_SceneManager added to tree → `_ready()` runs completely → syncs overlay state (clears stale overlays)
3. Frame completes, test checks state
4. M_PauseManager's await completes AFTER test checks → subscribes too late

**Symptoms**:
- `get_tree().paused` doesn't match actual overlay state
- Tests fail with "Tree should be unpaused without overlays" when state is correct but pause system hasn't synced yet
- Pause system's `is_paused()` returns stale value

**Solution** (implemented in m_pause_manager.gd:43-95):
```gdscript
func _ready() -> void:
    super._ready()

    # Get store synchronously - no await!
    _store = U_StateUtils.get_store(self)

    if not _store:
        # Defer if store not ready, but don't block _ready()
        call_deferred("_deferred_init")
        return

    _initialize()  # Synchronous initialization

# Also use _process() polling as backup:
func _process(_delta: float) -> void:
    _check_and_resync_pause_state()  # Detects state/engine pause mismatches
```

**Why polling is needed**:
Even with synchronous initialization, state updates can arrive BEFORE UI changes (or vice versa) due to signal timing. The `_process()` polling ensures pause state stays synced by checking BOTH:
- `scene.scene_stack` (state)
- `UIOverlayStack.get_child_count()` (actual UI)

If they disagree with current pause state, force a resync.

**Related**: See "Store Access Race Condition" below for general store initialization patterns.

### Documentation References

- UI Manager PRD: `docs/ui manager/ui-manager-prd.md`
- Input Manager PRD: `docs/input manager/input-manager-prd.md`
- Navigation Data Model: `docs/ui manager/general/data-model.md`
- Input/UI Flow Matrix: `docs/ui manager/general/flows-and-input.md`

## UI Navigation Pitfalls

### Store Access Race Condition

**Problem**: Accessing store in `_ready()` before it's registered causes null reference

**Solution**: Always await one frame before store lookup
```gdscript
# ❌ WRONG
func _ready():
	var store = U_StateUtils.get_store(self)  # May be null!

# ✅ CORRECT
func _ready():
	await get_tree().process_frame
	var store = U_StateUtils.get_store(self)
```

### Overlay Parent Validation

**Problem**: Opening overlay without parent overlay in stack silently fails

**Solution**: Check `U_NavigationSelectors.get_overlay_stack()` or ensure pause is open first
```gdscript
# Settings overlay requires pause_menu parent
store.dispatch(U_NavigationActions.open_pause())  # First open pause
await get_tree().process_frame
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))
```

### Panel Filtering

**Problem**: Main menu controller responds to pause menu panel updates (shared `active_menu_panel` state)

**Solution**: Filter panel updates by prefix
```gdscript
func _on_panel_changed(panel_id: StringName):
	if not panel_id.begins_with("menu/"):
		return  # Ignore pause/* panels
	_show_panel(panel_id)
```

### Direct Scene Manager Calls

**Problem**: UI calling `M_SceneManager.push_overlay()` bypasses navigation state

**Solution**: Always dispatch navigation actions
```gdscript
# ❌ WRONG
scene_manager.push_overlay(StringName("pause_menu"))

# ✅ CORRECT
store.dispatch(U_NavigationActions.open_pause())
```

### Process Mode for Overlays

**Problem**: Overlays freeze when tree is paused

**Solution**: Set `process_mode = PROCESS_MODE_ALWAYS` (BaseOverlay does this automatically)

### Pause State Detection

**Problem**: Multiple systems checking `scene.scene_stack` or `get_tree().paused` for pause state

**Solution**: Use canonical selector
```gdscript
# ❌ WRONG
var is_paused = state.get("scene", {}).get("scene_stack", []).size() > 0

# ✅ CORRECT
var is_paused = U_NavigationSelectors.is_paused(state)
```

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

## Mobile/Touchscreen Pitfalls

- **Device state must persist across game resets**: When implementing game reset/restart actions (like `U_GameplayActions.reset_progress()`), DO NOT reset the entire input state to defaults. Device-specific state fields must be preserved across progress resets to maintain correct device type after restarting the run.

  **Problem**: After completing the game and clicking "reset run" from the victory screen, the touchscreen controls become unresponsive. The game resets `active_device` from `2` (TOUCHSCREEN) to `0` (KEYBOARD_MOUSE), causing `MobileControls` to hide and input to stop working.

  **Why this happens**: When `reset_progress()` calls `INPUT_REDUCER.get_default_gameplay_input_state()`, it resets ALL input state including device detection fields. The default state has `active_device: 0` (KEYBOARD_MOUSE), which overrides the actual device type.

  **Solution**: When resetting gameplay state, preserve device state from the current input state before applying defaults:
  ```gdscript
  # In u_gameplay_reducer.gd ACTION_RESET_PROGRESS handler:

  # ❌ WRONG - resets everything including device state:
  var reset_input := INPUT_REDUCER.get_default_gameplay_input_state()
  return _apply_input_state(reset_state, reset_input)

  # ✅ CORRECT - preserve device state:
  var current_input: Dictionary = _get_current_input(state)
  var reset_input := INPUT_REDUCER.get_default_gameplay_input_state()
  reset_input["active_device"] = current_input.get("active_device", 0)
  reset_input["gamepad_connected"] = current_input.get("gamepad_connected", false)
  reset_input["gamepad_device_id"] = current_input.get("gamepad_device_id", -1)
  reset_input["touchscreen_enabled"] = current_input.get("touchscreen_enabled", false)
  reset_input["last_input_time"] = current_input.get("last_input_time", 0.0)
  return _apply_input_state(reset_state, reset_input)
  ```

  **Fields that must be preserved**:
  - `active_device` (TOUCHSCREEN/GAMEPAD/KEYBOARD_MOUSE)
  - `gamepad_connected` status
  - `gamepad_device_id`
  - `touchscreen_enabled`
  - `last_input_time`

  **Fields that should be reset** (transient gameplay input):
  - `move_input` → Vector2.ZERO
  - `look_input` → Vector2.ZERO
  - `jump_pressed` → false
  - `jump_just_pressed` → false
  - `sprint_pressed` → false

  **Testing**: After implementing a reset action, verify device type persists:
  1. Start game on mobile (device_type should be 2)
  2. Complete game or trigger reset action
  3. Verify device_type remains 2 (not reset to 0)
  4. Verify touchscreen controls continue working without gamepad input

  **Real example**: `scripts/state/reducers/u_gameplay_reducer.gd:199-207` preserves device state during `ACTION_RESET_PROGRESS` to fix touchscreen controls becoming unresponsive after victory screen reset.

## Unified Settings Panel Pitfalls

### Base Class Selection

**Problem**: Tab panels extending `BaseMenuScreen` create nested `U_AnalogStickRepeater` conflicts

**Solution**: Parent `SettingsPanel` extends `BaseMenuScreen`; child tab panels extend plain `Control`
```gdscript
# ❌ WRONG - creates duplicate analog repeater
# scripts/ui/panels/gamepad_tab.gd
extends BaseMenuScreen  # Parent already has repeater!

# ✅ CORRECT - parent handles all analog input
extends Control
const U_FocusConfigurator := preload("...")
func _configure_focus_neighbors():
    U_FocusConfigurator.configure_vertical_focus([...], false)
```

### ButtonGroup for Tab Radio Behavior

**Problem**: Manual button state management is error-prone and verbose

**Solution**: Use Godot's `ButtonGroup` resource for automatic mutual exclusivity
```gdscript
# ✅ In settings_panel.gd _ready():
var _tab_button_group := ButtonGroup.new()
input_profiles_button.toggle_mode = true
input_profiles_button.button_group = _tab_button_group
gamepad_button.toggle_mode = true
gamepad_button.button_group = _tab_button_group
# ButtonGroup automatically ensures only one button is pressed
_tab_button_group.pressed.connect(_on_tab_button_pressed)
```

### Focus Transfer on Tab Switch

**Problem**: Focus remains on tab button after switching, requiring extra navigation

**Solution**: Always transfer focus to first control in new tab
```gdscript
# ❌ WRONG - focus stuck on tab button
func _activate_tab(tab_button: Button):
    _show_tab_content(tab_button.name)
    # User must press down arrow to reach sliders

# ✅ CORRECT - automatic focus transfer
func _activate_tab(tab_button: Button):
    _show_tab_content(tab_button.name)
    await get_tree().process_frame  # Let visibility settle
    var first_focusable := _get_first_focusable_in_active_tab()
    if first_focusable:
        first_focusable.grab_focus()  # Ready to navigate immediately
```

### Device Switch Focus Recovery

**Problem**: When device switches and active tab becomes hidden, focus is lost on invisible control

**Solution**: Re-establish focus on first control of new active tab
```gdscript
# ✅ In _on_device_changed():
_update_tab_visibility()
if not _is_active_tab_visible():
    _switch_to_first_visible_tab()
    await get_tree().process_frame
    var first_focusable := _get_first_focusable_in_active_tab()
    if first_focusable:
        first_focusable.grab_focus()  # ⚠️ CRITICAL - prevents lost focus
```

### Auto-Save vs Apply/Cancel Pattern

**Problem**: Inconsistent settings UX and mismatched state synchronization patterns cause confusing behavior (unexpected immediate changes, lost local edits, or settings that feel like they “didn’t save”).

**Guideline**:
- **Default: auto-save** (immediate dispatch) for simple, low-risk settings where each control maps cleanly to a single action.
- **Use Apply/Cancel** when changes should be **atomic across multiple fields**, when there is a **preview/test mode**, or when changes are potentially disruptive and the user should confirm.

**Auto-save (immediate dispatch)**:
```gdscript
func _on_slider_changed(value: float) -> void:
	store.dispatch(U_InputActions.update_gamepad_setting("left_stick_deadzone", value))
```

**Apply/Cancel (dispatch on Apply)**:
```gdscript
func _on_apply_pressed() -> void:
	store.dispatch(U_VFXActions.set_screen_shake_enabled(_shake_enabled_toggle.button_pressed))
	store.dispatch(U_VFXActions.set_screen_shake_intensity(_intensity_slider.value))
```

**Tip**: If using Apply/Cancel, guard against external state updates overwriting local edits while the overlay is open (see the `_has_local_edits` pattern in touchscreen settings).

### M_StateStore.subscribe Callback Signature

**Problem**: `M_StateStore.subscribe()` calls subscribers with **two arguments** `(action, state)`. If your callback only accepts one argument, it will throw at runtime when an action is dispatched.

**Solution**: Match the signature:
```gdscript
func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	# Update UI from state
	pass
```

### Tab Content vs Parent Navigation

**Problem**: Tab content overriding `_navigate_focus()` conflicts with parent's analog repeater

**Solution**: Tab content uses `U_FocusConfigurator` for focus chains; parent handles navigation
```gdscript
# ❌ WRONG - tab overrides navigation
func _navigate_focus(direction: StringName):
    # Custom logic here...
    # Parent's analog repeater ALSO fires → double navigation!

# ✅ CORRECT - configure neighbors, let parent navigate
func _configure_focus_neighbors():
    var controls: Array[Control] = [slider1, slider2, checkbox]
    U_FocusConfigurator.configure_vertical_focus(controls, false)
    # Parent's _navigate_focus() follows these neighbors automatically
```

### Missing ui_focus_prev/ui_focus_next Actions

**Problem**: Shoulder button tab switching fails at runtime with missing action errors

**Solution**: Add input actions to `project.godot` BEFORE implementing tab cycling
```ini
ui_focus_prev={
  "deadzone": 0.2,
  "events": [
    Object(InputEventJoypadButton, button_index=9),  # L1/LB
    Object(InputEventKey, keycode=4194323)            # Page Up
  ]
}
ui_focus_next={
  "deadzone": 0.2,
  "events": [
    Object(InputEventJoypadButton, button_index=10), # R1/RB
    Object(InputEventKey, keycode=4194324)            # Page Down
  ]
}
```

## Style & Resource Hygiene

- `.gd` files under `scripts/` (and the gameplay/unit tests that exercise them) must use tab indentation. The style suite (`tests/unit/style/test_style_enforcement.gd`) fails immediately on leading spaces, so run it before committing editor-authored changes.
- Trigger configuration resources (`RS_SceneTriggerSettings` derivatives) must include `script = ExtResource(...)` and should remain scene-local. Controllers now duplicate shared `.tres` files automatically, but avoid manually reusing the same resource across entities or the inspector will apply mutations to every instance.
