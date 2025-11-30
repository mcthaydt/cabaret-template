# UI Manager Task Checklist

**Progress:** 57% (31 / 54 tasks complete)

**Architecture Decisions Made:**
- Dedicated `navigation` slice (Option A)
- Navigation slice is fully transient
- Only settings_menu_overlay returns to pause; all other overlays resume gameplay
- ESC and Start are identical for pause toggle
- First focusable control receives focus (no per-screen config)
- Quick fade (0.1-0.2s) for overlay animations
- ECS systems dispatch navigation actions (Strategy B)
- SettingsPanel is the only reusable panel
- Standardize return stack pattern across all overlays
- Virtual button dispatches NAV/OPEN_PAUSE (not direct call)
- Endgame screens dispatch navigation actions
- Save/load restores to main_menu (navigation transient)
- Main menu uses panel-based settings (embedded)
- HUD uses U_NavigationSelectors.is_paused()
- Mobile controls simplified with navigation selectors

## Task Groups

### Phase 0: Prerequisites (Input Manager Integration)

These tasks must be completed before UI Manager implementation can proceed. They establish the input foundation that UI Manager depends on.

- [x] T001_pre [PREREQ] Define ui_* actions in project.godot.
  - **Files**: `project.godot`
  - **Actions to define**:
    - `ui_accept` - Enter / gamepad A / touchscreen tap
    - `ui_cancel` - ESC / gamepad B
    - `ui_up`, `ui_down`, `ui_left`, `ui_right` - Arrows / D-pad / left stick
    - `ui_pause` - ESC / gamepad Start (same as ui_cancel for consistency)
  - **Mappings**:
    ```
    ui_accept: KEY_ENTER, KEY_SPACE, JOY_BUTTON_A
    ui_cancel: KEY_ESCAPE, JOY_BUTTON_B
    ui_pause: KEY_ESCAPE, JOY_BUTTON_START
    ui_up: KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y (negative)
    ui_down: KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y (positive)
    ui_left: KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X (negative)
    ui_right: KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X (positive)
    ```
  - **Acceptance**: All ui_* actions defined and testable via Input.is_action_pressed()
  - **Verification Script** (run before Phase 1):
    ```gdscript
    # Verify all required ui_* actions exist
    func verify_ui_actions() -> bool:
        var required := ["ui_accept", "ui_cancel", "ui_pause", "ui_up", "ui_down", "ui_left", "ui_right"]
        for action in required:
            if not InputMap.has_action(action):
                push_error("Missing required UI action: " + action)
                return false
        return true
    ```

- [x] T002_pre [PREREQ] Extend U_ButtonPromptRegistry for ui_* actions.
  - **Files**: `scripts/ui/u_button_prompt_registry.gd`
  - **Mappings to add**:
    | Action | Keyboard | Gamepad | Touchscreen |
    |--------|----------|---------|-------------|
    | ui_accept | "Enter" | "A" | "Tap" |
    | ui_cancel | "Esc" | "B" | "Back" |
    | ui_pause | "Esc" | "Start" | "Pause" |
  - **Acceptance**: Button prompts correctly display for ui_* actions per device type

- [x] T003_pre [PREREQ] Document pause action reservation and --emulate-mobile flag.
  - **Files**: `docs/general/DEV_PITFALLS.md`
  - **Content**:
    - Explain that "pause" is the only non-rebindable action (enforced by RS_RebindSettings)
    - Document `--emulate-mobile` flag for testing touchscreen UI
    - Note that ui_pause and ui_cancel share ESC key (intentional for consistent back behavior)
  - **Acceptance**: DEV_PITFALLS documents these patterns for future developers

### Phase 0: Architecture & Data Model

- [x] T001 [ARCH] Define navigation/UI slice schema and ownership rules (doc only, no code).
  - **Files**: Update `docs/ui manager/general/data-model.md`
  - **Deliverables**:
    - Document decision to use dedicated `navigation` slice (Option A) ✅ DONE
    - Define all navigation state fields: `shell`, `base_scene_id`, `overlay_stack`, `active_menu_panel`
    - Specify that slice is fully transient (not saved/loaded)
  - **Acceptance**: Data model doc has explicit schema with field types and example values

- [x] T002 [ARCH] Document invariants between navigation slice, `scene` slice, and `M_SceneManager` behavior.
  - **Files**: Update `docs/ui manager/general/data-model.md`
  - **Deliverables**:
    - List all invariants that must hold (e.g., `navigation.base_scene_id == scene.current_scene_id`)
    - Document Scene Manager's role as enforcer (reads state, doesn't own navigation logic)
    - Clarify sync behavior between navigation and scene slices
  - **Acceptance**: Invariants section is comprehensive and testable

- [x] T003 [ARCH] Specify `RS_UIScreenDefinition` fields and `U_UIRegistry` responsibilities.
  - **Files**: Update `docs/ui manager/general/data-model.md`
  - **Deliverables**:
    - Finalize resource fields (remove `default_focus_path` since using first focusable)
    - Document all enum values for `UIScreenKind` and `CloseMode`
    - Specify registry validation rules
  - **Acceptance**: Resource schema is implementation-ready with all fields documented

### Phase 1: Navigation Slice & Selectors

> **PREREQUISITE CHECK**: Before starting Phase 1, verify that T001_pre through T003_pre are complete. Run the verification script from T001_pre to confirm all `ui_*` actions exist in project.godot.

- [x] T010 [TDD] Define initial navigation state resource.
  - **Files**:
    - Create `scripts/state/resources/rs_navigation_initial_state.gd`
    - Create `resources/state/navigation_initial_state.tres`
  - **Initial State Shape**:
    ```gdscript
    {
      "shell": StringName("main_menu"),
      "base_scene_id": StringName("main_menu"),
      "overlay_stack": [],
      "active_menu_panel": StringName("menu/main")
    }
    ```
  - **Acceptance**: Resource loads and returns valid initial state dictionary
  - **Status**: Added `RS_NavigationInitialState` + `navigation_initial_state.tres` with default main_menu shell/panel.

- [x] T011 [TDD] Implement navigation reducer with core actions.
  - **Files**: Create `scripts/state/reducers/u_navigation_reducer.gd`
  - **Actions to implement**:
    - `NAV/SET_SHELL` - Update shell and base_scene_id
    - `NAV/OPEN_PAUSE` - Push "pause_menu" to overlay_stack
    - `NAV/CLOSE_PAUSE` - Clear overlay_stack, resume gameplay
    - `NAV/OPEN_OVERLAY` - Push overlay_id to stack (validate via registry)
    - `NAV/CLOSE_TOP_OVERLAY` - Pop top overlay, handle CloseMode
    - `NAV/SET_MENU_PANEL` - Update active_menu_panel
    - `NAV/START_GAME` - Set shell to "gameplay", set base_scene_id (new run or continue from save)
    - `NAV/OPEN_ENDGAME` - Set shell to "endgame", clear overlays
    - `NAV/RETRY` - Set shell to "gameplay", restore last checkpoint scene
    - `NAV/SKIP_TO_CREDITS` - Set base_scene_id to "credits"
    - `NAV/SKIP_TO_MENU` - Set shell to "main_menu"
    - `NAV/RETURN_TO_MAIN_MENU` - Set shell to "main_menu", clear overlays
  - **Acceptance**: All actions have unit tests, reducer is pure function
  - **Status**: Reducer added with close-mode handling, pause/overlay guards, and retry fallback to last gameplay scene.

- [x] T012 [TDD] Register navigation slice in `M_StateStore._initialize_slices()`.
  - **Files**:
    - Modify `scripts/state/m_state_store.gd`
    - Create `resources/state/navigation_slice_config.tres`
  - **Config**:
    - `slice_name`: "navigation"
    - `is_transient`: true (entire slice is transient)
    - `reducer_path`: "res://scripts/state/reducers/u_navigation_reducer.gd"
  - **Acceptance**: Navigation slice initializes on store startup, can dispatch actions
  - **Status**: Navigation slice registered (transient, skipped in persistence/StateHandoff); config resource added.

- [x] T013 [TDD] Implement `U_NavigationSelectors` for common queries.
  - **Files**: Create `scripts/state/selectors/u_navigation_selectors.gd`
  - **Selectors to implement**:
    - `get_shell(state) -> StringName`
    - `get_base_scene_id(state) -> StringName`
    - `get_overlay_stack(state) -> Array`
    - `get_top_overlay_id(state) -> StringName` (empty if no overlays)
    - `is_paused(state) -> bool` (true if overlay_stack not empty in gameplay)
    - `get_active_menu_panel(state) -> StringName`
    - `get_top_overlay_close_mode(state) -> int` (lookup from registry)
    - `is_in_endgame(state) -> bool`
  - **Acceptance**: All selectors have unit tests with various state configurations
  - **Status**: Selectors implemented with close-mode lookup and defensive copies.

- [x] T014 [TDD] Add comprehensive unit tests for navigation reducer and selectors.
  - **Files**: Create `tests/unit/state/test_navigation_state.gd`
  - **Test scenarios**:
    - Open/close pause flow
    - Nested overlay navigation (pause → settings → back)
    - Menu panel switching
    - Endgame flows (death → game_over → retry/menu)
    - Victory flow (victory → credits → menu via skip)
    - Invalid action handling (e.g., open overlay in wrong shell)
  - **Acceptance**: All tests pass, coverage for all action types and selectors
  - **Status**: Added coverage for pause, overlay return/resume, endgame retry/skip, and selector behavior; state suite passes.

- [x] T015 [IMPL] Create navigation action creators.
  - **Files**: Create `scripts/state/actions/u_navigation_actions.gd`
  - **Action creators**:
    ```gdscript
    static func open_pause() -> Dictionary:
        return { "type": "NAV/OPEN_PAUSE" }

    static func close_pause() -> Dictionary:
        return { "type": "NAV/CLOSE_PAUSE" }

    static func open_overlay(screen_id: StringName) -> Dictionary:
        return { "type": "NAV/OPEN_OVERLAY", "screen_id": screen_id }

    static func close_top_overlay() -> Dictionary:
        return { "type": "NAV/CLOSE_TOP_OVERLAY" }

    static func set_menu_panel(panel_id: StringName) -> Dictionary:
        return { "type": "NAV/SET_MENU_PANEL", "panel_id": panel_id }

    static func open_endgame(scene_id: StringName) -> Dictionary:
        return { "type": "NAV/OPEN_ENDGAME", "scene_id": scene_id }

    static func retry() -> Dictionary:
        return { "type": "NAV/RETRY" }

    static func skip_to_credits() -> Dictionary:
        return { "type": "NAV/SKIP_TO_CREDITS" }

    static func skip_to_menu() -> Dictionary:
        return { "type": "NAV/SKIP_TO_MENU" }

    static func return_to_main_menu() -> Dictionary:
        return { "type": "NAV/RETURN_TO_MAIN_MENU" }

    static func start_game(scene_id: StringName) -> Dictionary:
        return { "type": "NAV/START_GAME", "scene_id": scene_id }
    ```
  - **Acceptance**: All action creators follow existing patterns, used by UI code
  - **Status**: Action creators added with ActionRegistry registration; retry/start support optional scene payloads.

### Phase 2: UI Registry & Screen Definitions

- [x] T020 [TDD] Implement `RS_UIScreenDefinition` resource and validation helpers.
  - **Files**: Create `scripts/ui/resources/rs_ui_screen_definition.gd`
  - **Resource Fields**:
    ```gdscript
    @export var screen_id: StringName
    @export var kind: int  # UIScreenKind enum
    @export var scene_id: StringName  # Reference to U_SceneRegistry
    @export var allowed_shells: Array[StringName]
    @export var allowed_parents: Array[StringName]
    @export var close_mode: int  # CloseMode enum
    ```
  - **Enums** (define in same file or separate):
    ```gdscript
    enum UIScreenKind { BASE_SCENE, OVERLAY, PANEL }
    enum CloseMode { RETURN_TO_PREVIOUS_OVERLAY, RESUME_TO_GAMEPLAY, RESUME_TO_MENU }
    ```
  - **Validation**: `validate() -> bool` checks scene_id exists in U_SceneRegistry
  - **Acceptance**: Resource can be created in editor, validation works
  - **Status**: Resource added with enums, `to_dictionary()`, and validation that checks required fields + `U_SceneRegistry` entries.

- [x] T021 [TDD] Implement `U_UIRegistry` loader and lookup helpers.
  - **Files**: Create `scripts/ui/u_ui_registry.gd`
  - **Responsibilities**:
    - Load all `.tres` from `res://resources/ui_screens/`
    - Store in dictionary keyed by `screen_id`
    - Validate all entries on load
  - **Static Methods**:
    - `get_screen(screen_id: StringName) -> Dictionary`
    - `get_overlays_for_shell(shell: StringName) -> Array[Dictionary]`
    - `get_close_mode(screen_id: StringName) -> int`
    - `is_valid_overlay_for_parent(overlay_id: StringName, parent_id: StringName) -> bool`
    - `validate_all() -> bool` (returns false if any invalid)
  - **Acceptance**: Registry loads, lookups work, validation catches errors
  - **Status**: Registry helper loads definitions from game/test dirs, returns defensive copies, validates definitions, and exposes parent/close mode helpers.

- [x] T022 [DATA] Create registry entries for base UI scenes.
  - **Files**: Create in `resources/ui_screens/`
    - `main_menu_screen.tres`
    - `game_over_screen.tres`
    - `victory_screen.tres`
    - `credits_screen.tres`
  - **Example (main_menu_screen.tres)**:
    ```
    screen_id = "main_menu"
    kind = UIScreenKind.BASE_SCENE
    scene_id = "main_menu"
    allowed_shells = ["main_menu"]
    allowed_parents = []
    close_mode = CloseMode.RESUME_TO_MENU
    ```
  - **Acceptance**: All 4 base scene definitions created and valid
  - **Status**: Base scene definitions added with main_menu (shell main_menu) and endgame trio (shell endgame, RESUME_TO_MENU close behavior).

- [x] T023 [DATA] Create registry entries for all overlays.
  - **Files**: Create in `resources/ui_screens/`
    - `pause_menu_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
    - `settings_menu_overlay.tres` (close_mode = RETURN_TO_PREVIOUS_OVERLAY)
    - `input_profile_selector_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
    - `gamepad_settings_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
    - `touchscreen_settings_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
    - `input_rebinding_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
    - `edit_touch_controls_overlay.tres` (close_mode = RESUME_TO_GAMEPLAY)
  - **All overlays**: `allowed_shells = ["gameplay"]`, `allowed_parents = ["pause_menu"]` (except pause_menu itself)
  - **Acceptance**: All 7 overlay definitions created with correct close modes
  - **Status**: Overlay definitions added with gameplay shell, pause parent gating, and close modes matching return vs resume semantics.

- [x] T024 [TEST] Add unit tests for UI registry loading and validation.
  - **Files**: Create `tests/unit/ui/test_ui_registry.gd`
  - **Test scenarios**:
    - Registry loads all screen definitions
    - Lookup by screen_id returns correct data
    - `get_overlays_for_shell("gameplay")` returns all gameplay overlays
    - `get_close_mode()` returns correct enum for each overlay
    - Validation fails for invalid scene_id reference
    - Validation fails for missing required fields
  - **Acceptance**: All tests pass, error paths covered
  - **Status**: Added registry unit test covering base/overlay lookups, close modes, and invalid definition validation; full `tests/unit/ui` suite passing headless.

### Phase 3: Scene Manager Integration (Reactive Mode)

> ✅ Phase 3 complete (navigation slice now drives Scene Manager; overlay reconciliation tested) – proceed to Phase 4 tasks below.

- [x] T030 [ARCH] Design minimal reconciliation algorithm.
  - **Files**: Update `docs/ui manager/general/data-model.md` with algorithm description
  - **Algorithm**:
    1. Read `navigation.base_scene_id` and `navigation.overlay_stack`
    2. Compare with current `scene.current_scene_id` and `scene.scene_stack`
    3. Compute delta: scenes to load/unload, overlays to push/pop
    4. Apply changes via existing Scene Manager methods
  - **Key decisions**:
    - Reconciliation runs on `slice_updated` signal for navigation slice
    - Overlay animation: 0.1-0.2s quick fade for push/pop
    - CloseMode determines what happens after pop (check `RESUME_TO_GAMEPLAY` vs `RETURN_TO_PREVIOUS_OVERLAY`)
  - **Acceptance**: Algorithm documented with pseudocode and edge cases
  - **Status**: Section 8 of `data-model.md` now spells out triggers, pseudocode, and guard rails for the reconciliation loop.

- [x] T031 [IMPL] Add reconciliation helpers to `M_SceneManager`.
  - **Files**: Modify `scripts/managers/m_scene_manager.gd`
  - **New Methods**:
    - `_on_navigation_slice_updated()` - Subscribe to navigation state changes
    - `_reconcile_overlays(desired_stack: Array, current_stack: Array)` - Push/pop to match
    - `_reconcile_base_scene(desired_id: StringName, current_id: StringName)` - Transition if different
  - **Behavior**:
    - On `NAV/CLOSE_TOP_OVERLAY` with `RESUME_TO_GAMEPLAY`: pop all overlays, unpause tree
    - On `NAV/CLOSE_TOP_OVERLAY` with `RETURN_TO_PREVIOUS_OVERLAY`: pop one overlay, stay paused
    - Overlay fade animation: 0.15s using Tween
  - **Acceptance**: Scene tree matches navigation state after any action dispatch
  - **Status**: Scene Manager now listens for navigation slice updates, dedupes transitions, trims/pushes overlays via registry lookups, and keeps legacy APIs intact.

- [x] T032 [TEST] Add integration tests for key navigation flows.
  - **Files**: Create `tests/unit/integration/test_navigation_integration.gd`
  - **Test scenarios**:
    - **Pause flow**: gameplay → dispatch OPEN_PAUSE → verify pause_menu in stack → dispatch CLOSE_PAUSE → verify empty stack
    - **Nested overlay**: pause → settings → back → verify returns to pause → back → verify resumes gameplay
    - **Resume overlays**: pause → gamepad_settings → back → verify resumes gameplay directly (not back to pause)
    - **Endgame retry**: game_over → dispatch RETRY → verify transitions to gameplay scene
    - **Victory skip**: victory → dispatch SKIP_TO_CREDITS → credits → dispatch SKIP_TO_MENU → verify main_menu
    - **Menu panel switch**: main_menu → dispatch SET_MENU_PANEL("menu/settings") → verify panel state
  - **Acceptance**: All flows work with correct scene/overlay states
  - **Status**: Added `test_navigation_integration.gd` covering pause, nested overlays, retry, and victory → credits → menu; runs headless via gut.

- [x] T033 [SAFETY] Ensure existing Scene Manager tests remain green.
  - **Files**: Review and update `tests/unit/scene_manager/` tests
  - **Approach**:
    - Run full test suite before changes
    - After integration, run again and compare
    - Update tests only for intentional behavior changes
    - Document any breaking changes
  - **Acceptance**: Zero test regressions, or all regressions explicitly approved and documented
  - **Status**: Re-ran `tests/unit/scene_manager` (existing warnings remain unchanged) plus the new nav integration suite to confirm no regressions.

### Phase 4: UI Panels & Controller Refactors

- [x] T040 [ARCH] Document reusable panels and their responsibilities.
  - **Files**: Update `docs/ui manager/general/data-model.md`
  - **Reusable Panels**:
    - **SettingsPanel** - Audio, graphics, accessibility settings; used in main_menu and pause_menu
  - **Panel Architecture**:
    - Panels are scenes that can be instanced as children of base screens/overlays
    - Panels read state via selectors, dispatch actions on user input
    - Panels do NOT call Scene Manager directly
  - **Acceptance**: Panel architecture documented with integration pattern
  - **Status**: Section 3.4 now details SettingsPanel responsibilities, BasePanel contract, focus + store wiring, and parent/child integration flow.

- [x] T041 [IMPL] Introduce base classes for UI components.
  - **Files**: Create in `scripts/ui/base/`
    - `base_menu_screen.gd` - For full-screen base scenes (main_menu, game_over, etc.)
    - `base_overlay.gd` - For overlay scenes (pause_menu, settings, etc.)
    - `base_panel.gd` - For embedded panels (SettingsPanel)
  - **Common Functionality**:
    - `process_mode = PROCESS_MODE_ALWAYS` for overlays
    - Store access via `U_StateUtils.get_store(self)`
    - `_on_back_pressed()` virtual method - dispatches appropriate navigation action
    - `_get_first_focusable() -> Control` - returns first control in tab order
    - Auto-focus first control on `_ready()`
  - **Acceptance**: Base classes provide consistent behavior, reduce boilerplate
  - **Status**: Added `BasePanel`, `BaseMenuScreen`, and `BaseOverlay` under `scripts/ui/base/` with shared store lookup, focus auto-selection, and back-action hooks plus new `test_base_ui_classes.gd` coverage.

- [x] T042 [REF] Refactor main_menu to panel-based architecture.
  - **Files**: Modify `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`
  - **Changes**:
    - Extend `BaseMenuScreen`
    - Read `active_menu_panel` from navigation selectors
    - Show/hide panels based on state (main panel, settings panel)
    - "Settings" button dispatches `NAV/SET_MENU_PANEL("menu/settings")`
    - "Play" button dispatches `NAV/START_GAME` with target scene_id
    - Remove any direct `M_SceneManager` calls
    - `ui_cancel` at root panel: no-op
  - **Acceptance**: Main menu works via state, no Scene Manager calls
  - **Status**: `MainMenu` now extends `BaseMenuScreen`, listens to navigation slice changes, toggles between `menu/main` and `menu/settings` panels, and dispatches navigation actions for Play/Settings; coverage added in `tests/unit/ui/test_main_menu.gd`.

- [x] T043 [REF] Refactor pause_menu to use navigation actions.
  - **Files**: Modify `scenes/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd`
  - **Changes**:
    - Extend `BaseOverlay`
    - "Resume" button dispatches `NAV/CLOSE_PAUSE`
    - "Settings" button dispatches `NAV/OPEN_OVERLAY("settings_menu_overlay")`
    - Other buttons (gamepad, touchscreen, rebinding, etc.) dispatch `NAV/OPEN_OVERLAY` with appropriate screen_id
    - Remove direct `push_overlay_with_return` calls
    - `ui_back` dispatches `NAV/CLOSE_PAUSE`
  - **Acceptance**: Pause menu works via navigation actions
  - **Status**: Pause menu now dispatches navigation actions for resume/settings/input/profile flows, and dependent overlays were updated to dispatch navigation open/close actions so the nav slice stays authoritative.

- [x] T044 [REF] Refactor all settings/input overlays.
  - **Files**: Modify in `scenes/ui/` and `scripts/ui/`:
    - `settings_menu.tscn/gd` - Extend BaseOverlay, close returns to previous overlay
    - `gamepad_settings_overlay.tscn/gd` - Close resumes gameplay
    - `touchscreen_settings_overlay.tscn/gd` - Close resumes gameplay
    - `input_rebinding_overlay.tscn/gd` - Close resumes gameplay
    - `input_profile_selector.tscn/gd` - Close resumes gameplay
    - `edit_touch_controls_overlay.tscn/gd` - Close resumes gameplay
  - **Pattern for each**:
    - Extend `BaseOverlay`
    - Remove direct Scene Manager calls
    - Use `_on_back_pressed()` from base class (reads CloseMode from registry)
  - **Acceptance**: All overlays use consistent base class pattern

- [x] T045 [TEST] Add tests for panel switching and close behavior.
  - **Files**: Create `tests/unit/ui/test_ui_panels.gd`
  - **Test scenarios**:
    - Main menu panel switching (main → settings → back)
    - Pause menu opens via OPEN_PAUSE action
    - Settings overlay closes back to pause (RETURN_TO_PREVIOUS_OVERLAY)
    - Gamepad settings closes to gameplay (RESUME_TO_GAMEPLAY)
    - First focusable control receives focus on screen/overlay open
  - **Acceptance**: Panel behavior verified through state changes

- [x] T047 [REF] Migrate game_over.gd to dispatch navigation actions.
  - **Files**: Modify `scripts/ui/game_over.gd`
  - **Changes**:
    - "Retry" button → `store.dispatch(U_NavigationActions.retry())`
    - "Menu" button → `store.dispatch(U_NavigationActions.return_to_main_menu())`
    - Remove direct `transition_to_scene()` calls
  - **Acceptance**: Game over screen uses navigation actions
- _Notes (2025-12-??)_: Game over now extends BaseMenuScreen, dispatches nav actions, and has dedicated unit coverage in `tests/unit/ui/test_endgame_screens.gd`.

- [x] T048 [REF] Migrate victory.gd to dispatch navigation actions.
  - **Files**: Modify `scripts/ui/victory.gd`
  - **Changes**:
    - "Continue" button → `store.dispatch(U_NavigationActions.return_to_main_menu())` or continue logic
    - "Credits" button → `store.dispatch(U_NavigationActions.skip_to_credits())`
    - "Menu" button → `store.dispatch(U_NavigationActions.return_to_main_menu())`
    - Remove direct `transition_to_scene()` calls
  - **Acceptance**: Victory screen uses navigation actions
- _Notes (2025-12-??)_: Victory view now extends BaseMenuScreen, dispatches nav actions (continue/credits/menu/back), and is covered by `tests/unit/ui/test_endgame_screens.gd`.

- [x] T049 [REF] Migrate credits.gd to dispatch navigation actions.
  - **Files**: Modify `scripts/ui/credits.gd`
  - **Changes**:
    - "Skip" button → `store.dispatch(U_NavigationActions.skip_to_menu())`
    - Auto-scroll timeout → `store.dispatch(U_NavigationActions.skip_to_menu())`
    - Remove direct `transition_to_scene()` calls
  - **Acceptance**: Credits screen uses navigation actions for all exits
- _Notes (2025-12-??)_: Credits controller now dispatches `skip_to_menu()` for skip/back/auto return and includes timer coverage in `tests/unit/ui/test_endgame_screens.gd`.

- [x] T050_a [REF] Migrate hud_controller.gd to use navigation selectors.
  - **Files**: Modify `scripts/ui/hud_controller.gd`
  - **Current Code** (lines 213-216):
    ```gdscript
    func _is_paused(state: Dictionary) -> bool:
        var scene_state: Dictionary = state.get("scene", {})
        var stack: Array = scene_state.get("scene_stack", [])
        return stack.size() > 0
    ```
  - **New Code**:
    ```gdscript
    func _is_paused(state: Dictionary) -> bool:
        return U_NavigationSelectors.is_paused(state)
    ```
  - **Acceptance**: HUD uses canonical pause check from navigation selectors
- _Notes (2025-12-??)_: HUD pause detection now defers to `U_NavigationSelectors.is_paused`, and `tests/unit/ui/test_hud_controller.gd` & `test_hud_interactions_pause_and_signpost.gd` updated accordingly.

- [x] T050_b [REF] Simplify mobile_controls.gd visibility with navigation selectors.
  - **Files**: Modify `scripts/ui/mobile_controls.gd`
  - **Current Code** (lines 301-306) - 6 conditions:
    ```gdscript
    var device_allows: bool = _device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN
    var scene_allows: bool = _is_gameplay_root_scene()
    var overlay_allows: bool = not _has_overlay_active or _is_edit_overlay_active
    var should_show: bool = device_allows and scene_allows and not _is_transitioning and overlay_allows
    ```
  - **New Code**:
    ```gdscript
    var device_allows: bool = _device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN
    var state := _store.get_state()
    var shell := U_NavigationSelectors.get_shell(state)
    var is_editing := U_NavigationSelectors.get_top_overlay_id(state) == "edit_touch_controls"
    var overlay_allows: bool = not U_NavigationSelectors.is_paused(state) or is_editing
    var should_show: bool = device_allows and shell == "gameplay" and not _is_transitioning and overlay_allows
    ```
  - **Acceptance**: Mobile controls use navigation selectors for cleaner logic
- _Notes (2025-12-??)_: MobileControls now checks `navigation.shell` and overlay IDs; `tests/unit/ui/test_mobile_controls.gd` updated to dispatch navigation actions.

### Phase 4b: Pause/Input Consolidation

These tasks remove direct pause/ESC input handling from existing systems, consolidating all UI navigation through navigation actions.

- [x] T070 [REF] Align Pause System with Navigation Slice.
  - **Files**:
    - `scripts/ecs/systems/s_pause_system.gd`
    - `tests/unit/ecs/systems/test_s_pause_system.gd`
  - **Deliverables**:
    - S_PauseSystem no longer reads input events (`event.is_action_pressed("pause")`) directly
    - System subscribes to store and derives pause state from navigation selectors (`U_NavigationSelectors.is_paused(state)`)
    - System is responsible only for applying engine-level pause (`get_tree().paused`), emitting `pause_state_changed`, and coordinating with cursor manager
  - **Acceptance**: All pause toggling is driven by navigation state changes, not raw input; existing tests updated to drive pause via actions/state
- _Notes (2025-11-26)_: S_PauseSystem refactored to watch navigation slice, removed input handling, now only applies engine pause and coordinates cursor state.

- [x] T071 [REF] Decouple Cursor Manager from "pause" Input Action.
  - **Files**:
    - `scripts/managers/m_cursor_manager.gd`
    - `tests/unit/managers/test_m_cursor_manager.gd`
  - **Deliverables**:
    - M_CursorManager no longer toggles on the "pause" InputMap action in `_unhandled_input()`
    - Cursor manager exposes `set_cursor_state()`, `set_cursor_locked()`, `set_cursor_visible()` and reacts only to explicit calls/signals from S_PauseSystem or Scene Manager
  - **Acceptance**: No direct references to "pause" remain in M_CursorManager; cursor state changes are triggered via pause/navigation flows
- _Notes (2025-11-26)_: Removed `_unhandled_input()` and `toggle_cursor()` methods; cursor now controlled via explicit calls from S_PauseSystem.

- [x] T072 [REF] Remove ESC/Pause Handling from Scene Manager Input Path.
  - **Files**:
    - `scripts/managers/m_scene_manager.gd` (lines 168-204)
    - `tests/unit/scene_manager/*`
  - **Deliverables**:
    - `_input()` in M_SceneManager no longer handles ESC/"pause" to push/pop overlays
    - All pause/open-overlay behavior is driven by navigation actions (NAV/OPEN_PAUSE, NAV/CLOSE_TOP_OVERLAY) and reconciliation logic
  - **Acceptance**: No ESC/"pause" branches remain in M_SceneManager._input(); pause tests updated to assert navigation + reconciliation behavior
- _Notes (2025-11-26)_: Removed entire `_input()` method and pause-blocking variables; added transition guard to `_reconcile_overlay_stack()` to defer overlay changes during scene transitions.

- [x] T073 [REF] Wire Virtual Pause Button to Navigation Actions.
  - **Files**:
    - `scripts/ui/virtual_button.gd`
    - `tests/unit/ui/test_virtual_button.gd`
  - **Deliverables**:
    - VirtualButton keeps direct `Input.action_press/release` for gameplay actions (jump, sprint, interact)
    - Pause-type virtual button dispatches `U_NavigationActions.open_pause()`/`close_pause()` directly
    - No longer reads `scene.scene_stack` or calls `M_SceneManager.push_overlay/pop_overlay`
  - **Note**: This supersedes T046
  - **Acceptance**: All references to `scene_stack` and direct overlay calls removed; tests confirm navigation-driven pause behavior
- _Notes (2025-12-??)_: Pause button toggles `NAV/OPEN_PAUSE`/`NAV/CLOSE_PAUSE`; `tests/unit/ui/test_virtual_button.gd` includes new coverage.

- [x] T074 [TEST] Refresh Pause/Input Integration Tests for New Flow.
  - **Files**:
    - `tests/integration/scene_manager/test_pause_system.gd`
    - `tests/integration/scene_manager/test_edge_cases.gd`
    - `tests/integration/scene_manager/test_input_during_transition.gd`
  - **Deliverables**:
    - Integration tests drive pause flows via navigation actions / `ui_*` actions
    - Input Manager tests assert correct device + action context, but do not own UI navigation decisions
  - **Acceptance**: All updated tests pass; no tests rely on direct "pause"/ESC handling in systems
- _Notes (2025-11-26)_: Updated 3 tests to use navigation actions instead of calling removed `_input()` method; all scene manager integration tests pass (89/89).

- [x] T075 [DOC] Document Input Manager / UI Manager Boundary.
  - **Files**:
    - `docs/general/DEV_PITFALLS.md`
  - **Deliverables**:
    - PRDs explicitly state that Input Manager owns hardware→action mapping (including `ui_*`) and device state
    - UI Manager + navigation slice own UI flow (pause, back, overlays)
    - DEV_PITFALLS adds note: "Do not handle UI navigation or pause directly inside Input Manager systems/managers; use navigation actions + selectors instead"
  - **Acceptance**: Docs are consistent with implemented architecture and cross-referenced
- _Notes (2025-11-26)_: Added comprehensive "UI Manager / Input Manager Boundary" section to DEV_PITFALLS with responsibilities, flow examples, common mistakes, and testing patterns.

### Phase 5: UI Input Handler (Gamepad & Keyboard)

> ✅ Phase 5 complete (UI input handler implemented and integrated; all context-based routing tests pass) – proceed to Phase 6 tasks below.

- [x] T053 [ARCH] Document canonical `ui_*` actions and input mapping.
  - **Files**: Update `docs/ui manager/general/flows-and-input.md`
  - **Canonical Actions** (matching Godot built-ins + custom):
    - `ui_accept` - Enter / gamepad A - activate focused control
    - `ui_cancel` - ESC / gamepad B - context-dependent back behavior
    - `ui_pause` - ESC / gamepad Start - identical to ui_cancel (opens pause in gameplay)
    - `ui_up/down/left/right` - Arrows / D-pad / left stick - focus navigation
  - **Mapping Rules**:
    - ESC and Start both map to `ui_pause` (they are identical)
    - In gameplay with no overlays: `ui_pause` opens pause
    - In any other context: `ui_pause` behaves as `ui_cancel`
  - **Acceptance**: All actions documented with hardware mappings
- _Notes (2025-11-26)_: Added comprehensive section 2 to `flows-and-input.md` documenting all canonical ui_* actions, ESC/Start mapping rules, behavior matrix by context, and focus navigation patterns.

- [x] T054 [IMPL] Implement thin UI input handler.
  - **Files**: Create `scripts/ui/ui_input_handler.gd`
  - **Architecture**:
    - Runs with `process_mode = PROCESS_MODE_ALWAYS`
    - Lives in root.tscn alongside M_SceneManager
    - Listens to `_unhandled_input()` for ui_* actions
  - **Input Routing Logic**:
    ```gdscript
    func _handle_ui_cancel():
        var state = store.get_state()
        var shell = U_NavigationSelectors.get_shell(state)
        var overlay_stack = U_NavigationSelectors.get_overlay_stack(state)

        if shell == "gameplay" and overlay_stack.is_empty():
            # No overlays, open pause
            store.dispatch(U_NavigationActions.open_pause())
        elif shell == "gameplay" and not overlay_stack.is_empty():
            # Has overlays, close top one (CloseMode handled by reducer/reconciliation)
            store.dispatch(U_NavigationActions.close_top_overlay())
        elif shell == "main_menu":
            var panel = U_NavigationSelectors.get_active_menu_panel(state)
            if panel != "menu/main":
                store.dispatch(U_NavigationActions.set_menu_panel("menu/main"))
            # else: no-op at root
        elif shell == "endgame":
            var scene = U_NavigationSelectors.get_base_scene_id(state)
            match scene:
                "game_over": store.dispatch(U_NavigationActions.retry())
                "victory": store.dispatch(U_NavigationActions.skip_to_credits())
                "credits": store.dispatch(U_NavigationActions.skip_to_menu())
    ```
  - **Note**: CloseMode (RESUME_TO_GAMEPLAY vs RETURN_TO_PREVIOUS_OVERLAY) is handled by the reducer when processing NAV/CLOSE_TOP_OVERLAY, not by the input handler
  - **Acceptance**: All context-based routing works correctly
- _Notes (2025-11-26)_: Created `scripts/ui/ui_input_handler.gd` with process_mode=ALWAYS, _unhandled_input() listening for ui_cancel/ui_pause, context matrix routing per flows-and-input.md section 3.2, and integrated into root.tscn under Managers group.

- [x] T055 [TEST] Add tests for input routing across all contexts.
  - **Files**: Create `tests/unit/ui/test_ui_input_handler.gd`
  - **Test scenarios**:
    - **Gameplay no overlays**: `ui_cancel` → dispatches OPEN_PAUSE
    - **Gameplay with pause**: `ui_cancel` → dispatches CLOSE_TOP_OVERLAY
    - **Gameplay with settings**: `ui_cancel` → dispatches CLOSE_TOP_OVERLAY
    - **Gameplay with gamepad_settings**: `ui_cancel` → dispatches CLOSE_TOP_OVERLAY
    - **Main menu settings panel**: `ui_cancel` → dispatches SET_MENU_PANEL("menu/main")
    - **Main menu root panel**: `ui_cancel` → no-op (no action dispatched)
    - **Game over**: `ui_cancel` → dispatches RETRY
    - **Victory**: `ui_cancel` → dispatches SKIP_TO_CREDITS
    - **Credits**: `ui_cancel` → dispatches SKIP_TO_MENU
  - **Test method**: Mock store, verify correct actions dispatched for each context
  - **Acceptance**: All 9+ test scenarios pass
- _Notes (2025-11-26)_: Created `tests/unit/ui/test_ui_input_handler.gd` with 10 test scenarios covering gameplay (no overlays, pause, settings, gamepad_settings), main menu (settings panel, root panel), endgame (game_over, victory, credits), and ui_pause/ui_cancel equivalence; all tests pass (92/92 in full UI suite).

### Phase 6: Hardening & Regression Guardrails

- [x] T060 [TEST] Run full GUT suite and record baseline.
  - **Command**: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
  - **Record**:
    - Total test count before changes
    - Total test count after changes
    - Any new failures with explanations
  - **Acceptance**: Zero unexpected failures, test count maintained or increased
  - _Notes (2025-11-26)_: Ran `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`; baseline = 121 scripts / 800 tests / 796 passing / 4 pending (tween timing skips only).

- [x] T060b [FIX] Add automatic background management to BaseOverlay.
  - **Files**: `scripts/ui/base/base_overlay.gd`
  - **Issue**: When overlays stack (e.g., Pause → Settings), both overlays were visible simultaneously due to missing background panels
  - **Solution**:
    - BaseOverlay now automatically detects and reuses existing ColorRect backgrounds (backward compatible)
    - For overlays without manual ColorRects, creates automatic background with configurable opacity
    - Ensures `MOUSE_FILTER_STOP` to block input to overlays underneath
    - Preserves existing color customizations (pause: 50% opacity, settings: 65% opacity)
  - **Exports**:
    - `background_color: Color` - Default semi-transparent black (0.7 opacity)
    - `auto_create_background: bool` - Enable/disable automatic creation (default: true)
    - `custom_background_panel: ColorRect` - Optional manual override
  - **Acceptance**: All overlays extending BaseOverlay get proper visual separation when stacked
  - _Notes (2025-11-27)_: Implemented smart detection that reuses first-child ColorRect if present, otherwise creates new background panel; all 7 overlays benefit automatically.

- [x] T060c [FIX] Fix navigation reducer to use UI registry for parent validation.
  - **Files**:
    - `scripts/state/reducers/u_navigation_reducer.gd`
    - `resources/ui_screens/edit_touch_controls_overlay.tres`
    - `scenes/ui/edit_touch_controls_overlay.tscn`
  - **Issue**: Edit Touch Controls overlay couldn't be opened from Touchscreen Settings because `_is_overlay_allowed_for_parent` was hardcoded to only allow pause_menu as immediate parent
  - **Root Cause**: Navigation reducer had hardcoded parent validation instead of using UI registry's `allowed_parents` field
  - **Solution**:
    - Updated `_is_overlay_allowed_for_parent()` to call `U_UIRegistry.is_valid_overlay_for_parent()`
    - Added `touchscreen_settings` to `edit_touch_controls_overlay.tres` allowed_parents
    - Removed hardcoded overlay whitelist from reducer (now uses registry as source of truth)
    - Reduced background opacity from 50% → 5% so users can see game screen while editing controls
  - **Impact**: Enables proper 3-level overlay nesting: Pause → Touchscreen Settings → Edit Layout
  - **Acceptance**: Edit Touch Controls can be opened from both pause_menu and touchscreen_settings; background is transparent enough to see game
  - _Notes (2025-11-27)_: Architectural fix - navigation reducer now delegates parent validation to UI registry instead of maintaining parallel logic. Edit overlay uses 5% opacity background (vs 50-70% for other overlays) to maintain visibility.

- [x] T060d [FEATURE] Add exclusive overlay pattern to hide previous overlays.
  - **Files**:
    - `scripts/ui/resources/rs_ui_screen_definition.gd`
    - `scripts/managers/m_scene_manager.gd`
    - `resources/ui_screens/edit_touch_controls_overlay.tres`
    - `scenes/ui/mobile_controls.tscn`
  - **Issue**: Edit Touch Controls has transparent background but pause/touchscreen settings overlays underneath still visible, cluttering view
  - **Solution**:
    - Added `@export var hides_previous_overlays: bool` to RS_UIScreenDefinition
    - Scene Manager's `_reconcile_overlay_stack()` now calls `_update_overlay_visibility()` after reconciliation
    - `_update_overlay_visibility()` checks top overlay's `hides_previous_overlays` flag and sets `visible = false` on all previous overlays if true
    - Enabled flag for `edit_touch_controls_overlay.tres`
    - Set MobileControls CanvasLayer to `layer = 50` to render above all overlays (layer 0) but below loading screen (layer 100)
  - **Layer Hierarchy**:
    - Layer 0: UIOverlayStack (pause, settings, edit overlays)
    - Layer 50: MobileControls (always visible on top when editing)
    - Layer 100: LoadingOverlay (covers everything during transitions)
  - **Pattern**: Declarative, reusable for any overlay that needs exclusive visibility (e.g., fullscreen photo viewer, video player)
  - **Acceptance**: When Edit Touch Controls opens, pause/settings hidden and mobile controls visible on top for dragging; when it closes, overlays become visible again
  - _Notes (2025-11-27)_: Elegant declarative pattern - configure once in registry, Scene Manager handles visibility automatically during reconciliation. Preserves overlay stack for navigation (back button works correctly) while hiding UI for clear view. CanvasLayer ordering ensures mobile controls always render on top of edit overlay.

- [x] T061 [QA] Manual verification of all UI flows.
  - **Test Matrix** (keyboard + gamepad for each):
    - [x] Main menu → Play → gameplay hub loads
    - [x] Gameplay → ESC → pause overlay appears, game paused
    - [x] Pause → Settings → settings overlay (should NOT see pause underneath), back → returns to pause
    - [x] Pause → Gamepad Settings → overlay, back → resumes gameplay directly
    - [x] Pause → Touchscreen Settings → overlay, back → resumes gameplay directly
    - [x] Pause → Rebinding → overlay, back → resumes gameplay directly
    - [x] Pause → Input Profiles → overlay, apply → resumes gameplay directly
    - [x] Pause → Resume → gameplay resumes
    - [x] Gameplay → death → Game Over screen
    - [x] Game Over → Retry → gameplay resumes from checkpoint
    - [x] Game Over → back key → triggers Retry
    - [x] Victory → Credits → credits screen shows
    - [x] Victory → back key → skips to Credits
    - [x] Credits → back key → returns to main menu
    - [x] Main menu → Settings panel → shows settings, back → returns to main panel
    - [x] Main menu root panel → back key → no-op
  - **Mobile-specific**:
    - [x] Edit Touch Controls overlay → close → resumes gameplay
    - [x] Touchscreen Settings overlay → close → resumes gameplay
  - **Acceptance**: All 17+ test cases pass with both input methods

- [x] T062 [DOC] Update all related documentation.
  - **Files updated** (commit 8894d33):
    - `AGENTS.md` - Added UI Manager patterns section with navigation state, actions, registry, base classes
    - `docs/scene manager/scene-manager-prd.md` - Added UI Manager integration cross-reference
    - `docs/state store/redux-state-store-prd.md` - Documented navigation slice
    - `docs/input manager/input-manager-prd.md` - Documented ui_* actions table
    - `docs/general/DEV_PITFALLS.md` - Added 6 UI navigation pitfalls with examples
  - **Content added**:
    - Navigation actions quick reference
    - UI registry usage patterns
    - Common mistakes (store race, parent validation, panel filtering, direct calls, process mode, pause detection)
  - **Verification**: All docs cross-referenced and consistent

- [x] T063 [CLEANUP] Remove obsolete code paths.
  - **Code removed** (commit 82c8f08):
    - pause_menu.gd - ~162 lines (SCRIPT_VERSION, print statements, diagnostic functions)
    - u_navigation_reducer.gd - 17 lines (DIAG-REDUCER, DIAG-VALID prints)
    - virtual_button.gd - 4 lines (DIAG-VBUTTON prints)
    - mobile_controls.gd - 3 lines (visibility logging)
    - gamepad_settings_overlay.gd - 5 lines (state sync logging)
  - **Total cleanup**: ~191 lines removed
  - **Verification**:
    - grep -r "\[DIAG-" scripts/ui/ scripts/state/ → 0 results
    - grep -r "SCRIPT_VERSION" scripts/ui/ → 0 results
    - All 135 state tests passing
  - **Result**: No duplicate navigation logic outside reducers/actions; all UI properly uses navigation actions

### Phase 7: UX Refinements & Polish

Issues discovered during testing that need to be addressed:

- [ ] T070 [UX] Fix joystick menu navigation sensitivity.
  - **Issue**: Joystick requires exact up/hard press for menu navigation
  - **Expected**: Smooth analog stick navigation with appropriate deadzone
  - **Files**: `scripts/ui/base/base_panel.gd`, possibly input mapping

- [ ] T071 [UX] Add menu option cycling when input held.
  - **Issue**: Menu options don't cycle continuously when directional input is held
  - **Expected**: Options should cycle/scroll when ui_up/ui_down held
  - **Files**: UI focus system or base panel input handling

- [ ] T072 [UX] Context-aware settings visibility.
  - **Issue**: Gamepad controls shown when not using gamepad
  - **Expected**: Settings menu hides irrelevant options based on active device type
  - **Files**: Settings menu UI, device detection integration
  - **Dependencies**: `M_InputDeviceManager` device type

- [ ] T073 [UX] Consolidate all settings into unified settings menu.
  - **Issue**: Settings scattered across multiple overlays
  - **Expected**: Single settings menu with tabs/sections for different categories
  - **Files**: `scripts/ui/settings_menu.gd`, pause menu structure

- [ ] T074 [BUG] Mobile touchscreen controls appearing after gamepad menu exit.
  - **Issue**: Touchscreen controls show after exiting menu with gamepad on mobile
  - **Expected**: Controls remain hidden if exited with gamepad
  - **Files**: `scripts/ui/mobile_controls.gd` visibility logic
  - **Root cause**: Device detection not updating correctly on menu close

- [ ] T075 [UX] Gamepad-accessible scrollbars in rebind controls.
  - **Issue**: Rebind controls overlay not fully controllable with gamepad (scrollbar navigation fails)
  - **Expected**: Full gamepad navigation including scroll areas
  - **Files**: `scripts/ui/input_rebinding_overlay.gd`

- [ ] T076 [UX] Context-sensitive rebind controls.
  - **Issue**: Rebind controls shows all device inputs regardless of active device
  - **Expected**: Only show rebindable actions for current device type
  - **Files**: `scripts/ui/input_rebinding_overlay.gd`

- [ ] T077 [UX] Context-sensitive input profiles with visual feedback.
  - **Issue**: Input profiles don't show what the actual inputs are
  - **Expected**: Profile selector shows preview of bindings for selected profile
  - **Files**: `scripts/ui/input_profile_selector.gd`

- [ ] T078 [UX] Visual button prompts in gamepad control UI.
  - **Issue**: Gamepad control UI should visualize actual button being pressed
  - **Expected**: Show Xbox/PS button glyphs matching physical controller
  - **Files**: Gamepad settings overlay, button prompt system
  - **Dependencies**: Button glyph assets, device type detection

- [ ] T079 [ARCH] Remove overlay stacking (flatten UI).
  - **Issue**: Menus should not stack as overlays
  - **Expected**: Settings/input screens replace pause menu instead of stacking
  - **Impact**: Requires rethinking overlay_stack vs panel switching
  - **Files**: Navigation reducer, UI registry overlay definitions

- [ ] T080 [UX] Cancel button exits menu directly.
  - **Issue**: Cancel (B/Circle) button doesn't exit menu
  - **Expected**: Cancel button should close current menu/return to previous
  - **Files**: `scripts/ui/ui_input_handler.gd`, base overlay input handling
  - **Note**: May conflict with T079 depending on final architecture

## Notes

- Each task includes specific file paths, code examples, and acceptance criteria to enable implementation without ambiguity.
- "Everything still works" is a hard requirement: any behavioral change must be explicitly approved and reflected in tests and docs.
- Follow TDD discipline: write tests first, verify they fail, implement, verify they pass.
- Commit at the end of each completed task or logical milestone.

## Summary of New Files to Create

**Scripts:**
- `scripts/state/resources/rs_navigation_initial_state.gd`
- `scripts/state/reducers/u_navigation_reducer.gd`
- `scripts/state/selectors/u_navigation_selectors.gd`
- `scripts/state/actions/u_navigation_actions.gd`
- `scripts/ui/resources/rs_ui_screen_definition.gd`
- `scripts/ui/u_ui_registry.gd`
- `scripts/ui/base/base_menu_screen.gd`
- `scripts/ui/base/base_overlay.gd`
- `scripts/ui/base/base_panel.gd`
- `scripts/ui/ui_input_handler.gd`

**Resources:**
- `resources/state/navigation_initial_state.tres`
- `resources/state/navigation_slice_config.tres`
- `resources/ui_screens/*.tres` (11 screen definitions)

**Tests:**
- `tests/unit/state/test_navigation_state.gd`
- `tests/unit/ui/test_ui_registry.gd`
- `tests/unit/ui/test_ui_panels.gd`
- `tests/unit/ui/test_ui_input_handler.gd`
- `tests/unit/integration/test_navigation_integration.gd`

## Files to Migrate (Direct Scene Manager Calls → Navigation Actions)

| File | Lines | Current Pattern | Migration |
|------|-------|-----------------|-----------|
| `scripts/ui/pause_menu.gd` | 49, 58, 63, 67, 71, 76, 85 | `push_overlay_with_return()`, `pop_overlay()` | Dispatch NAV actions |
| `scripts/ui/virtual_button.gd` | 234-237 | `push_overlay()`, `pop_overlay()` | Dispatch NAV/OPEN_PAUSE, NAV/CLOSE_PAUSE |
| `scripts/ui/game_over.gd` | Multiple | `transition_to_scene()` | Dispatch NAV/RETRY, NAV/RETURN_TO_MAIN_MENU |
| `scripts/ui/victory.gd` | Multiple | `transition_to_scene()` | Dispatch NAV actions |
| `scripts/ui/credits.gd` | Multiple | `transition_to_scene()` | Dispatch NAV/SKIP_TO_MENU |
| `scripts/ui/main_menu.gd` | Multiple | `transition_to_scene()` | Dispatch NAV/SET_MENU_PANEL, extend BaseMenuScreen |
| `scripts/ui/settings_menu.gd` | 55 | `pop_overlay_with_return()` | Extend BaseOverlay |
| `scripts/ui/input_rebinding_overlay.gd` | 646 | `pop_overlay()` | Extend BaseOverlay (RESUME_TO_GAMEPLAY) |
| `scripts/ui/touchscreen_settings_overlay.gd` | 254, 361 | `push_overlay_with_return()`, `pop_overlay()` | Extend BaseOverlay |
| `scripts/ui/gamepad_settings_overlay.gd` | 118 | `pop_overlay()` | Extend BaseOverlay |
| `scripts/ui/edit_touch_controls_overlay.gd` | 188 | `pop_overlay()` | Extend BaseOverlay |
| `scripts/ui/input_profile_selector.gd` | 47 | `pop_overlay()` | Extend BaseOverlay |
| `scripts/ui/hud_controller.gd` | 213-216 | Check `scene_stack` size | Use `U_NavigationSelectors.is_paused()` |
| `scripts/ui/mobile_controls.gd` | 301-306 | 6-condition visibility | Use navigation selectors |

## Links

- Plan: `docs/ui manager/ui-manager-plan.md`
- PRD: `docs/ui manager/ui-manager-prd.md`
- Scene Manager PRD: `docs/scene manager/scene-manager-prd.md`
- Input Manager PRD: `docs/input manager/input-manager-prd.md`
