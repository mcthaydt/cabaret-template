# Agents Notes

## Start Here

- Project type: Godot 4.5 (GDScript). Core area:
  - `scripts/ecs`: Lightweight ECS built on Nodes (components + systems + manager).
- Scenes and resources:
  - `templates/`: Base scene and player scene that wire components/systems together.
  - `resources/`: Default `*Settings.tres` for component configs; update when adding new exported fields.
- Documentation to consult (do not duplicate here):
  - General pitfalls: `docs/general/DEV_PITFALLS.md`
- Before adding or modifying code, re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md` to stay aligned with testing and formatting requirements.
- Keep project planning docs current: whenever a story advances, update the relevant plan and PRD documents immediately so written guidance matches the implementation state.
- **MANDATORY: Update continuation prompt and tasks checklist after EVERY phase**: When completing a phase (e.g., Phase 2 of Scene Manager), you MUST:
  1. Update the continuation prompt file (e.g., `docs/scene_manager/scene-manager-continuation-prompt.md`) with current status
  2. Update the tasks file (e.g., `docs/scene_manager/scene-manager-tasks.md`) to mark completed tasks with [x] and add completion notes
  3. Update AGENTS.md with new patterns/architecture (if applicable)
  4. Update DEV_PITFALLS.md with new pitfalls discovered (if applicable)
  5. Commit documentation updates separately from implementation
- Commit at the end of each completed story (or logical, test-green milestone) so every commit represents a verified state.
- Make a git commit whenever a feature, refactor, or documentation update moves the needle forward; keep commits focused and validated. Skipping required commits is a blocker—treat the guidance as non-optional.
- **MANDATORY: Run style and scene organization tests before merging**: After any changes to file naming, scene structure, or adding new scripts/scenes, run `tests/unit/style/test_style_enforcement.gd` to ensure prefix compliance and scene structure validity. Automated checks enforce the prefix rules documented in `STYLE_GUIDE.md`.

## Repo Map (essentials)

- `scripts/managers/m_ecs_manager.gd`: Registers components/systems; exposes `get_components(StringName)` and emits component signals.
- `scripts/managers/m_scene_manager.gd`: Scene transition coordinator (Phase 3+); manages ActiveSceneContainer.
- `scripts/state/m_state_store.gd`: Redux store; adds to "state_store" group for discovery via `U_StateUtils.get_store()`.
- `scripts/ui/u_ui_registry.gd` + `resources/ui_screens/`: UI registry definitions (`RS_UIScreenDefinition`) for base screens and overlays.
- `scripts/ecs/base_ecs_component.gd`: Base for components. Auto-registers with manager; exposes `get_snapshot()` hook.
- `scripts/ecs/base_ecs_system.gd`: Base for systems. Implement `process_tick(delta)`; runs via `_physics_process`.
- `scripts/ecs/components/*`: Gameplay components with `@export` NodePaths and typed getters.
- `scripts/ecs/systems/*`: Systems that query components by `StringName` and operate per-physics tick.
- `scripts/ecs/resources/*`: `Resource` classes holding tunables consumed by components/systems.
- `scenes/root.tscn`: Main scene (persistent managers + containers).
- `scenes/gameplay/*`: Gameplay scenes (dynamic loading, own M_ECSManager).
- `tests/unit/*`: GUT test suites for ECS and state management.

## ECS Guidelines

- Components
  - Extend `BaseECSComponent`; define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
  - Enforce required settings/resources by overriding `_validate_required_settings()` (call `push_error(...)` and return `false` to abort registration); use `_on_required_settings_ready()` for post-validation setup.
  - Prefer `@export` NodePaths with typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
  - Keep null-safe call sites; systems assume absent paths disable behavior rather than error.
  - If you expose debug state, copy via `snapshot.duplicate(true)` to avoid aliasing.
- Systems
  - Extend `BaseECSSystem`; implement `process_tick(delta)` (invoked from `_physics_process`).
  - Query with `get_components(StringName)`, dedupe per-body where needed, and clamp/guard values (see movement/rotation/floating examples).
  - Use `U_ECSUtils.map_components_by_body()` when multiple systems need shared body→component dictionaries (avoids duplicate loops).
  - Auto-discovers `M_ECSManager` via parent traversal or `ecs_manager` group; no manual wiring needed.
- Manager
  - Ensure exactly one `M_ECSManager` in-scene. It auto-adds to `ecs_manager` group on `_ready()`.
  - Emits `component_added`/`component_removed` and calls `component.on_registered(self)`.
  - `get_components()` strips out null entries automatically; only guard for missing components when logic truly requires it.
- Entities (Phase 6 - Entity IDs & Tags)
  - All entities extend `BaseECSEntity` (Node3D with entity_id and tags exports).
  - **Entity IDs**: Auto-generated from node name (`E_Player` → `"player"`), or manually set via `entity_id` export. Cached after first access. Duplicate IDs automatically get `_{instance_id}` suffix.
  - **Tags**: Freeform `Array[StringName]` for categorization. Use `add_tag(tag)`, `remove_tag(tag)`, `has_tag(tag)` to modify. Tags auto-update manager's tag index.
  - **Manager queries**: `get_entity_by_id(id)`, `get_entities_by_tag(tag)`, `get_entities_by_tags(tags, match_all)`.
  - **Auto-registration**: Entities automatically register with `M_ECSManager` when their first component registers. Publishes `"entity_registered"` event to `U_ECSEventBus`.
  - **State integration**: `U_ECSUtils.build_entity_snapshot(entity)` includes entity_id and tags for Redux persistence.
  - Example: `player.entity_id = StringName("player"); player.tags = [StringName("player"), StringName("controllable")]`

## Scene Organization

- **Root scene pattern (NEW - Phase 2)**: `scenes/root.tscn` persists throughout session
  - Persistent managers: `M_StateStore`, `M_CursorManager`, `M_SceneManager`
  - Scene containers: `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`
  - Gameplay scenes load/unload as children of `ActiveSceneContainer`
- Mobile touch controls: `scenes/ui/mobile_controls.tscn` CanvasLayer lives in root; shows virtual joystick/buttons on mobile or `--emulate-mobile`, hides during transitions/pause/gamepad input
- **Gameplay scenes**: Each has own `M_ECSManager` instance
  - Example: `scenes/gameplay/gameplay_base.tscn`
  - Contains: Systems, Entities, SceneObjects, Environment
  - HUD uses `U_StateUtils.get_store(self)` to find M_StateStore via "state_store" group
- Node tree structure: See `docs/scene_organization/SCENE_ORGANIZATION_GUIDE.md`
- Templates: `templates/tmpl_base_scene.tscn` (legacy reference), `templates/tmpl_character.tscn` (generic), `templates/tmpl_camera.tscn`
- Marker scripts: `scripts/scene_structure/*` (11 total) provide visual organization
- Systems organized by category: Core / Physics / Movement / Feedback
- Naming: Node names use prefixes matching their script types (E_, S_, C_, M_, SO_, Env_)

### Interactable Controllers

- Controllers live in `scripts/gameplay/` and replace ad-hoc `C_*` nodes; create a single `E_*` node per interactable:
  - Base stack: `base_volume_controller.gd`, `base_interactable_controller.gd`, `triggered_interactable_controller.gd`
  - Concrete controllers: `e_door_trigger_controller.gd`, `e_checkpoint_zone.gd`, `e_hazard_zone.gd`, `e_victory_zone.gd`, `e_signpost.gd`
- Controllers auto-create/adopt `Area3D` volumes using `RS_SceneTriggerSettings`—never author separate component or Area children manually.
- `triggered_interactable_controller.gd` publishes `interact_prompt_show` / `interact_prompt_hide` events; HUD renders the prompt label.
- `e_signpost.gd` emits `signpost_message` events; HUD reuses the checkpoint toast UI for signpost text.
- Exterior/interior scenes are now fixtures built on controllers; core flow routes through `gameplay_base` instead of these fixtures.
- Controller `settings` are auto-duplicated (`resource_local_to_scene = true`). Assign shared `.tres` files freely—each controller keeps a unique copy.
- Passive volumes (`E_CheckpointZone`, `E_HazardZone`, `E_VictoryZone`) keep `ignore_initial_overlap = false` so respawns inside the volume re-register automatically. Triggered interactables (doors, signposts) leave it `true` to avoid instant re-activation.
- Use `visual_paths` to toggle meshes/lights/particles when controllers enable/disable; keep visuals as controller children instead of wiring extra logic nodes.
- Controllers run with `process_mode = PROCESS_MODE_ALWAYS` and will not activate while `scene.is_transitioning` or `M_SceneManager.is_transitioning()` is true.

## Naming Conventions Quick Reference

**IMPORTANT**: All production scripts, scenes, and resources must follow documented prefix patterns. As of Phase 5 Complete (2025-12-08), 100% prefix compliance achieved - all files follow their respective prefix patterns. See `docs/general/STYLE_GUIDE.md` for the complete prefix matrix.

- **Base classes:** `base_*` prefix (e.g., `base_ecs_component.gd` → `BaseECSComponent`, `base_panel.gd` → `BasePanel`)
- **Utilities:** `u_*` prefix (e.g., `u_ecs_utils.gd` → `U_ECSUtils`, `u_entity_query.gd` → `U_EntityQuery`)
- **Managers:** `m_*` prefix (e.g., `m_ecs_manager.gd` → `M_ECSManager`, `m_state_store.gd` → `M_StateStore`)
- **Components:** `c_*` prefix (e.g., `c_movement_component.gd` → `C_MovementComponent`)
- **Systems:** `s_*` prefix (e.g., `s_gravity_system.gd` → `S_GravitySystem`)
- **Resources:** `rs_*` prefix (e.g., `rs_jump_settings.gd` → `RS_JumpSettings`)
- **Entities:** `e_*` prefix (e.g., `e_player.gd` → `E_Player`, `e_checkpoint_zone.gd` → `E_CheckpointZone`)
- **UI Scripts:** `ui_*` prefix (e.g., `ui_main_menu.gd` → `UI_MainMenu`)
- **Marker Scripts:** `marker_*` prefix (e.g., `marker_entities_group.gd`, `marker_main_root_node.gd`)
- **Transitions:** `trans_*` prefix (e.g., `trans_fade.gd` → `Trans_Fade`)
- **Interfaces:** `i_*` prefix (e.g., `i_scene_contract.gd` → `I_SCENE_CONTRACT`)
- **Prefabs:** `prefab_*` prefix for scenes (e.g., `prefab_death_zone.tscn`)

### Helper Extraction Pattern (Large Files)

- When core scripts approach 400–500 lines, prefer extracting pure helpers instead of adding more responsibilities:
  - Scene management helpers: `scripts/scene_management/helpers/u_scene_registry_loader.gd`
  - Input helpers: `scripts/managers/helpers/m_input_profile_loader.gd`
  - ECS helpers: `scripts/ecs/helpers/u_ecs_query_metrics.gd`
  - UI helpers/builders: `scripts/ui/helpers/u_rebind_action_list_builder.gd`, `scripts/ui/helpers/u_touchscreen_preview_builder.gd`
- Helper scripts:
  - Live under a `helpers/` subdirectory next to their parent domain.
  - Use existing prefixes (`u_` for utilities, `m_` for manager loaders) plus a descriptive suffix (e.g., `_loader`, `_builder`, `_metrics`).
  - Expose small, focused APIs that keep managers/systems under ~400 lines while preserving behavior.

## Conventions and Gotchas

- GDScript typing
  - Annotate locals receiving Variants (e.g., from `Callable.call()`, `JSON.parse_string`, `Time.get_ticks_msec()` calc). Prefer explicit `: float`, `: int`, `: Dictionary`, etc.
  - Use `StringName` for action/component identifiers; keep constants like `const MOVEMENT_TYPE := StringName("C_MovementComponent")`.
- Time helpers
  - For ECS timing, call `U_ECSUtils.get_current_time()` (seconds) instead of repeating `Time.get_ticks_msec() / 1000.0`.
- Copy semantics
  - Use `.duplicate(true)` for deep copies of `Dictionary`/`Array` before mutating; the codebase relies on immutability patterns both in ECS snapshots and state.
- Scenes and NodePaths
- Wire `@export` NodePaths in scenes; missing paths intentionally short-circuit behavior in systems. See `templates/tmpl_character.tscn` + `scenes/prefabs/prefab_player.tscn` for patterns.
- Resources
  - New exported fields in `*Settings.gd` require updating default `.tres` under `resources/` and any scene using them.
  - Trigger settings automatically clamp `player_mask` to at least layer 1; configure the desired mask on the resource instead of zeroing it at runtime.
- Tabs and warnings
  - Keep tab indentation in `.gd` files; tests use native method stubs on engine classes—suppress with `@warning_ignore("native_method_override")` where applicable (details in `docs/general/developer_pitfalls.md`).
- State store batching and input persistence
  - `M_StateStore` emits `slice_updated` once per physics frame; do not also flush on idle frames.
  - Actions that need same-frame visibility (e.g., input rebinds) must set `"immediate": true` on the dispatched payload; the store now flushes batched slice updates immediately for these actions.
  - Gameplay input fields are transient across scene transitions (StateHandoff) but are persisted to disk on save/load.
- State load normalization
  - `M_StateStore.load_state()` sanitizes unknown `current_scene_id`, `target_spawn_point`, and `last_checkpoint` values, falling back to `gameplay_base` / `sp_default` and deduping `completed_areas`.
- Style enforcement
  - `tests/unit/style/test_style_enforcement.gd` fails on leading spaces in gameplay/state/ui scripts and verifies trigger resources include `script = ExtResource(...)`.
- InputMap
  - The `interact` action must remain in `project.godot`; HUD/process prompts run in `PROCESS_MODE_ALWAYS` to stay responsive when the tree is paused.
  - Device detection is centralized in `M_InputDeviceManager`; gameplay systems read `U_InputSelectors.get_active_device_type()` / `get_active_gamepad_id()` instead of dispatching their own `device_changed` actions.
  - Rebinding flows must dispatch via Redux (`U_InputActions.rebind_action`)—`M_InputProfileManager` now derives InputMap state from the store, so avoid mutating InputMap directly in UI code.
  - `S_InputSystem` only gates input on cursor capture for desktop platforms; on mobile (`OS.has_feature("mobile")`), do not depend on `Input.mouse_mode` for gamepad routing so Bluetooth controllers remain functional when MobileControls hides the touchscreen UI.
- Button Prompt Patterns (Phase 1 - Generic Glyphs)
  - **Registry handles texture loading**: `U_ButtonPromptRegistry.get_prompt(action, device_type)` returns cached Texture2D for registered actions
  - **Automatic fallback**: When texture unavailable, ButtonPrompt falls back to text label
  - **Texture priority**: Show texture if available, otherwise show text binding label
  - **Caching**: Textures loaded once and cached in registry for performance
  - **Device switching**: ButtonPrompt automatically updates texture when device changes
  - **Texture display**: TextureRect with 32x32 minimum size, aspect ratio preserved (STRETCH_KEEP_ASPECT_CENTERED)
  - **Usage**:
    ```gdscript
    button_prompt.show_prompt(StringName("interact"), "Open Door")
    # Shows texture for current device, falls back to text if unavailable
    ```
  - **Note**: Textures are mapped to actions, not specific key bindings. When user rebinds an action, the texture remains the same (shows action's registered glyph, not the new key).

## Scene Manager Patterns (Phase 10 Complete)

### Scene Registration

- **Register all scenes**: Add scenes to `U_SceneRegistry._register_all_scenes()` before using them

  ```gdscript
  _register_scene(
    StringName("my_scene"),
    "res://scenes/gameplay/my_scene.tscn",
    SceneType.GAMEPLAY,
    "fade",  # default transition
    5        # preload priority (0-10)
  )
  ```

- **Preload priority guidelines**:
  - `10`: Critical UI (main_menu, pause_menu) - preloaded at startup
  - `5-7`: Frequently accessed scenes
  - `0-4`: Occasional access
  - `0`: No preload (loaded on-demand)

### Scene Transitions

- **Get scene manager**: `get_tree().get_first_node_in_group("scene_manager") as M_SceneManager`
- **Basic transition**: `scene_manager.transition_to_scene(StringName("scene_id"))`
- **Override transition type**: `scene_manager.transition_to_scene(StringName("scene_id"), "fade")`
- **Priority transitions**: `scene_manager.transition_to_scene(StringName("game_over"), "fade", M_SceneManager.Priority.CRITICAL)`
- **Transition types**:
  - `"instant"`: < 100ms, no visual effect (UI navigation)
  - `"fade"`: 0.2-0.5s, fade out → load → fade in (polished)
  - `"loading"`: 1.5s+, loading screen with progress bar (large scenes)
- **Priority levels**:
  - `NORMAL = 0`: Standard navigation
  - `HIGH = 1`: Important but not urgent
  - `CRITICAL = 2`: Death, game over (jumps to front of queue)

### Overlay Management (Pause/Menus)

- **Push overlay**: `scene_manager.push_overlay(StringName("pause_menu"))` - adds to stack, pauses tree
- **Pop overlay**: `scene_manager.pop_overlay()` - removes top overlay, resumes if empty
- **Return stack**: `push_overlay_with_return(StringName("settings_menu"))` - remember previous overlay
- **Auto-restore**: `pop_overlay_with_return()` - return to previous overlay automatically
- **Navigation**: `go_back()` - navigate back through UI history (UI scenes only, skips gameplay)

### Scene Triggers (Doors)

- **Component setup**: Add `C_SceneTriggerComponent` to door entities with Area3D collision
- **Required properties**:
  - `door_id`: Unique identifier (e.g., `"door_to_house"`)
  - `target_scene_id`: Destination scene (e.g., `"interior_house"`)
  - `target_spawn_point`: Spawn marker name (e.g., `"sp_entrance_from_exterior"`)
- **Trigger modes**:
  - `AUTO`: Triggers on collision (walk through)
  - `INTERACT`: Requires input action (press 'E')
- **Duplicate request protection**: Components check transition state and use cooldown/pending flags to prevent duplicate requests
- **Input blocking during transitions**: Transition effects temporarily block input to prevent accidental re-triggers; restore input on completion
- **Trigger shape configuration**: Use shape resources (Box or Cylinder). Avoid non-uniform scaling of nodes; adjust shape dimensions on the resource instead. Use `local_offset` to align triggers with visual geometry
- **Cooldown**: Set `cooldown_duration` (1-2 seconds) to prevent spam
- **Door pairings**: Register bidirectional doors in `U_SceneRegistry._register_door_pairings()`

  ```gdscript
  _register_door_pair(
    StringName("exterior"), StringName("door_to_house"),
    StringName("interior_house"), StringName("door_to_exterior")
  )
  ```

### Spawn Point Management

- **Naming convention**: `sp_` prefix + descriptive name (e.g., `sp_entrance_from_exterior`)
- **Container**: Place under `SP_SpawnPoints` (Node3D) in gameplay scenes
- **Default spawn**: Name one marker `sp_default` for initial scene load
- **Position**: Place spawn markers 2-3 units OUTSIDE trigger zones (prevents ping-pong)
- **Automatic restoration**: M_SpawnManager applies spawn on scene load using:
  - Priority: `target_spawn_point` → `last_checkpoint` → `sp_default`
  - Fallback: If a `last_checkpoint` from a different scene is invalid, fall back to `sp_default` automatically

### State Persistence

- **Automatic persistence**: `gameplay` slice persists across transitions via `StateHandoff`
- **Use action creators**: Modify state via `U_GameplayActions` (never set fields directly)

  ```gdscript
  const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
  store.dispatch(U_GameplayActions.take_damage(player_id, 25.0))
  store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))
  ```

- **Read state safely**: Use `U_StateUtils.get_store(self)` with `await` in `_ready()`

  ```gdscript
  await get_tree().process_frame
  var store := U_StateUtils.get_store(self)
  var state: Dictionary = store.get_state()
  ```

- **Transient fields**: Excluded from saves (e.g., `is_transitioning`, `transition_type`)
- **Save/load**: `store.save_state("user://savegame.json")` / `store.load_state("user://savegame.json")`

### Camera Blending

- **Automatic blending**: Gameplay → Gameplay transitions blend camera position, rotation, FOV
- **Requirements**: Both scenes must have camera in "main_camera" group
- **Transition type**: Only works with `"fade"` transitions (not instant/loading)
- **Scene-specific setup**: Configure camera per-scene (e.g., exterior: FOV 80°, interior: FOV 65°)
- **Implementation**: Uses transition camera + Tween (0.2s, TRANS_CUBIC, EASE_IN_OUT)

### Scene Preloading & Performance

- **Critical scene preload**: Scenes with `preload_priority >= 10` load at startup
- **Scene cache**: LRU cache with 5 scene limit + 100MB memory cap
- **Preload hints**: Call `hint_preload_scene(StringName("scene_id"))` when player approaches door
- **Automatic hints**: `C_SceneTriggerComponent` auto-hints target scene on player proximity
- **Async loading**: Gameplay scenes load asynchronously with real progress tracking
- **Performance targets**:
  - UI transitions: < 0.5s (cached scenes are instant)
  - Gameplay transitions: < 3s (async with loading screen)
  - Large scenes: < 5s (loading screen with progress bar)

## UI Manager Patterns

### Navigation State

- **Navigation slice**: Dedicated Redux slice managing UI location (`shell`, `overlay_stack`, `active_menu_panel`)
- **Shells**: `main_menu`, `gameplay`, `endgame`
- **Overlays**: Modal dialogs stacked on gameplay via `overlay_stack` array
- **Panels**: Embedded UI within shells (e.g., `menu/main`, `menu/settings`)

### Using Navigation Actions

```gdscript
const U_NavigationActions = preload("res://scripts/state/actions/u_navigation_actions.gd")

# Open pause overlay
store.dispatch(U_NavigationActions.open_pause())

# Open nested overlay
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))

# Close top overlay (CloseMode determines behavior)
store.dispatch(U_NavigationActions.close_top_overlay())

# Switch menu panels
store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
```

### UI Registry

- **Resource-based**: All screens defined in `resources/ui_screens/*.tres`
- **Screen definition**: `RS_UIScreenDefinition` with `screen_id`, `kind`, `scene_id`, `allowed_shells`, `close_mode`
- **Validation**: Registry validates parent-child relationships and scene references

### Base UI Classes

- **BasePanel**: Auto-store lookup, focus management, back button handling
- **BaseMenuScreen**: For full-screen UIs (main menu, endgame)
- **BaseOverlay**: For modal dialogs, sets `PROCESS_MODE_ALWAYS`, manages background dimming

### Common Patterns

- UI controllers extend base classes and dispatch actions (never call Scene Manager directly)
- Subscribe to `slice_updated` for reactive updates
- Use `U_NavigationSelectors.is_paused()` for pause state (single source of truth)
- Await store ready: `await get_tree().process_frame` before accessing store in `_ready()`

### Unified Settings Panel Patterns

**Architecture**:
- `SettingsPanel` extends `BaseMenuScreen` (gets analog stick repeater)
- Tab content panels extend plain `Control` (NO nested repeaters)
- Use `ButtonGroup` for tab radio behavior (automatic mutual exclusivity)
- Auto-save pattern: dispatch Redux actions immediately (no Apply/Cancel buttons)

**Base Class Hierarchy**:
```
BasePanel (store + focus helpers)
└─ BaseMenuScreen (+ U_AnalogStickRepeater)
    ├─ SettingsPanel ← extends this
    └─ BaseOverlay (+ PROCESS_MODE_ALWAYS)

Tab panels (gamepad_tab, touchscreen_tab, etc.)
└─ Control ← extends this (NOT BaseMenuScreen!)
```

**ButtonGroup Setup**:
```gdscript
# In settings_panel.gd:
var _tab_button_group := ButtonGroup.new()
func _ready():
    input_profiles_button.toggle_mode = true
    input_profiles_button.button_group = _tab_button_group
    gamepad_button.toggle_mode = true
    gamepad_button.button_group = _tab_button_group
    # ButtonGroup automatically handles button_pressed states
    _tab_button_group.pressed.connect(_on_tab_button_pressed)
```

**Focus Management Rules**:
1. **Tab switch**: Transfer focus to first control in new tab
   ```gdscript
   await get_tree().process_frame  # Let visibility settle
   var first_focusable := _get_first_focusable_in_active_tab()
   if first_focusable:
       first_focusable.grab_focus()
   ```

2. **Device switch**: If active tab becomes hidden, switch tab AND re-focus
   ```gdscript
   _update_tab_visibility()
   if not _is_active_tab_visible():
       _switch_to_first_visible_tab()
       await get_tree().process_frame
       _focus_first_control_in_active_tab()  # Critical!
   ```

3. **Tab content**: Use `U_FocusConfigurator` for focus chains, not custom `_navigate_focus()`
   ```gdscript
   # In gamepad_tab.gd:
   func _configure_focus_neighbors():
       var controls: Array[Control] = [left_slider, right_slider, checkbox]
       U_FocusConfigurator.configure_vertical_focus(controls, false)
   ```

**Auto-Save Pattern**:
```gdscript
# ✅ CORRECT - immediate dispatch
func _on_left_deadzone_changed(value: float):
    store.dispatch(U_InputActions.update_gamepad_setting("left_stick_deadzone", value))

# ❌ WRONG - batching with Apply button
var _pending_changes: Dictionary = {}
func _on_slider_changed(value: float):
    _pending_changes["deadzone"] = value
func _on_apply_pressed():
    store.dispatch(...)
```

**Input Actions for Tab Switching**:
- Add `ui_focus_prev` (L1/LB, Page Up) and `ui_focus_next` (R1/RB, Page Down) to `project.godot`
- Shoulder buttons cycle tabs, focus transfers automatically

**Anti-Patterns**:
- ❌ Tab panels extending `BaseMenuScreen` (creates nested repeater conflict)
- ❌ Manual button state management (use `ButtonGroup` instead)
- ❌ Apply/Cancel buttons (use auto-save pattern)
- ❌ Tab content overriding `_navigate_focus()` (conflicts with parent repeater)

## Test Commands

- Run ECS tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- Always include `-gexit` when running GUT via the command line so the runner terminates cleanly; without it the process hangs and triggers harness timeouts.
- Notes
  - Tests commonly `await get_tree().process_frame` after adding nodes to allow auto-registration with `M_ECSManager` before assertions.
  - When stubbing engine methods in tests (e.g., `is_on_floor`, `move_and_slide`), include `@warning_ignore("native_method_override")`.

## Quick How-Tos (non-duplicative)

- Add a new ECS Component
  - Create `scripts/ecs/components/c_your_component.gd` extending `BaseECSComponent` with `COMPONENT_TYPE` and exported NodePaths; add typed getters; update a scene to wire paths.
- Add a new ECS System
  - Create `scripts/ecs/systems/s_your_system.gd` extending `BaseECSSystem`; implement `process_tick(delta)`; query with your component's `StringName`; drop the node under a running scene—auto-configured.
- Find M_StateStore from any node
  - Use `U_StateUtils.get_store(self)` to find the store via "state_store" group.
  - In `_ready()`: add `await get_tree().process_frame` BEFORE calling `get_store()` to avoid race conditions.
  - In `process_tick()`: no await needed (store already registered).
- Create a new gameplay scene
  - Duplicate `scenes/gameplay/gameplay_base.tscn` as starting point.
  - Keep M_ECSManager + Systems + Entities + Environment structure.
  - Do NOT add M_StateStore or M_CursorManager (they live in root.tscn).
