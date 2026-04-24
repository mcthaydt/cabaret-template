# Developer Pitfalls

> Godot engine pitfalls (Scene UIDs, Physics, Script Class Cache, UI, Audio) → `docs/guides/pitfalls/GODOT_ENGINE.md`

> vCam, QB camera rule, room fade, wall visibility, and camera integration pitfalls → `docs/systems/vcam_manager/vcam-pitfalls.md`

> GDScript typing pitfalls → `docs/guides/pitfalls/GDSCRIPT_4_6.md`

> Testing, GUT, headless, and asset-import pitfalls → `docs/guides/pitfalls/TESTING.md`

## Scene Director Pitfalls

- **`gameplay/reset_progress` is not an objectives reset**: Dispatching `U_GameplayActions.reset_progress()` clears gameplay progression fields but does not rebuild objective statuses/event log. Endgame Continue/retry flows must route through the run-reset contract (`U_RunActions.reset_run`) so `M_RunCoordinator` can call `M_ObjectivesManager.reset_for_new_run(...)` and re-arm root objectives (`bar_complete` active, `final_complete` inactive) with an empty objective event log.

## AI System Pitfalls

- **Tag-based detection must exclude the detector entity itself**: `S_AIDetectionSystem` candidate pools built from all movement entities can accidentally include the detector's own entity. When `target_tag` matches the detector's tags (for example pack detection with `target_tag = predator`), the detector can lock onto itself at distance `0` unless source/target identity is explicitly filtered.
  - **Fix pattern**: carry source entity identity into nearest-target resolution and skip candidates with matching entity instance ID (or matching entity ID fallback).
- **Interaction chains can silently no-op when the action resolves targets from live detection at consume/use time**: in multi-step loops (`approach -> interact/consume`), live nearest-target re-resolution can drift to a different entity (or clear), so state can advance without applying the intended world-side effect.
  - **Fix pattern**: lock target identity when the chain starts (task-state ID plus optional component-level pending ID), and make the final action consume/operate on the locked target first; add unit tests for locked-target success and out-of-range failure.
- **Approach completion range must be compatible with interaction range**: when move completion thresholds are tighter than consume/interact radii, AI can be “in range to act” but still fail the move action completion gate and stall the sequence.
  - **Fix pattern**: align move completion radius with the downstream action radius (or allow an override that uses the larger value) and keep movement-action tests that assert completion at interaction range.
- **Utility-scored loops need explicit terminal-state gates**: if scorer conditions only consider local readiness (for example inventory state) and ignore terminal world state, agents can continue selecting obsolete branches and spin on no-op tasks.
  - **Fix pattern**: include terminal-state predicates (for example target complete/disabled/exhausted) in scorer gates, and keep integration tests that assert fallback behavior once terminal state is reached.
- **Acquire/deposit loops must be deficit-driven to avoid progress deadlocks**: choosing any valid source and depositing all carried items can repeatedly over-supply irrelevant types and under-supply the blocking requirement, preventing stage/objective progression.
  - **Fix pattern**: derive required type(s) from the active deficit, filter source scans accordingly, and cap deposits to outstanding deficits before recomputing readiness.

## QB Rule Engine v2 Pitfalls

- **`U_PathResolver` intentionally has no method-call fallback**: Conditions/effects must resolve data through dictionary/object property paths only. Do not rely on `has_method()` + call behavior for rule evaluation.
- **Rule-consumer systems should use typed arrays + coerce setters**: New rule-consumer systems should use `@export var rules: Array[RS_Rule] = []` (or the relevant interface type) with an F7-style coerce setter matching existing `RS_Rule`/BT resource patterns. `U_RuleValidator` validates semantics; typed arrays + coerce setters enforce schema at the GDScript level.
- **Condition/effect subresources must match v2 subclasses**: Rule assets should use `RS_Condition*` and `RS_Effect*` resources only; validator failures should block runtime registration.
- **Context-driven effects require explicit context contracts**: `RS_EffectSetField.use_context_value` will no-op or write wrong values if the expected context path is missing/mistyped. Keep context keys documented per consumer (`components`, `event_payload`, `state`, etc.) and verify in unit tests.
- **Trackers are per-system state, not shared utilities**: `RuleStateTracker` stores cooldown/rising-edge/one-shot state. Reusing one tracker across systems causes cross-domain gating bugs.

> vCam, QB camera rule, room fade, wall visibility, and camera integration pitfalls → `docs/systems/vcam_manager/vcam-pitfalls.md`

> Character lighting patterns and pitfalls → `docs/systems/lighting_manager/lighting-manager-overview.md`

> UI Manager navigation, focus, settings, and UI/Input boundary pitfalls → `docs/systems/ui_manager/ui-pitfalls.md`

> State store (Redux-style) pitfalls → `docs/guides/pitfalls/STATE.md`

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
  3. **DO NOT use groups** - The codebase does not use Godot's groups feature for manager discovery

- **Why no groups**: Groups add hidden coupling that's hard to track in code. ServiceLocator provides explicit, type-safe manager registration with O(1) lookup. Use `U_ServiceLocator` for all manager discovery instead of `get_tree().get_first_node_in_group()`

- **State store**:
  - Required callers: `U_StateUtils.get_store(node)` / `U_StateUtils.await_store_ready(node)`
  - Optional callers (standalone scenes / editor-opened gameplay scenes): `U_StateUtils.try_get_store(node)` to avoid noisy errors

- **Avoid ad-hoc group scanning in leaf nodes**: Prefer the standard chain for managers like `scene_manager`, `input_profile_manager`, `input_device_manager`, etc. Only drop to `get_tree().get_first_node_in_group(...)` when ServiceLocator may not be initialized (tests / isolated scenes).

## Scene Transition Pitfalls

- Door trigger re-entry can cause ping-pong transitions:
  - Ensure `C_SceneTriggerComponent` guards are active (cooldown + `is_transitioning` checks).
  - Keep spawn markers positioned outside trigger volumes to avoid immediate re-trigger on load.
- Avoid leaving `initial_scene_id = alleyway` outside of manual tests; prefer `main_menu` to follow the flow and reduce confusion.

- Trigger geometry pitfalls (Cylinder default):
  - `CylinderShape3D` is Y-up; do not rotate unless your door axis demands it.
  - Avoid non-uniform scaling on trigger nodes; set `radius/height` (or `box_size`) via settings instead.
  - Too-small radius/height leads to flickery enter/exit at edges—add margin.
  - Keep collision masks consistent with the player layer (`player_mask` in RS_SceneTriggerSettings). A mismatch causes no events.
- Interactable controllers refuse to fire while `M_SceneManager` (or the scene slice) reports `is_transitioning`. When debugging a “stuck” interact prompt, confirm the active transition finished before calling `activate()`.
- Passive volumes (hazards, checkpoints, victory zones) must re-arm and detect spawn-inside overlaps. Leave `ignore_initial_overlap` disabled for these controllers; only doors / INTERACT prompts keep it enabled to avoid instant re-activation.
- Per-instance trigger settings must be unique. Controllers automatically duplicate shared `.tres` references and set `resource_local_to_scene = true`; avoid manually reusing the same resource via code or editor overrides, otherwise one instance will mutate all others.
- Trigger volumes now clamp `player_mask` to at least `1`. If you intentionally need a different mask, update the settings resource—forcing the mask to `0` will be ignored.

> GDScript language pitfalls → `docs/guides/pitfalls/GDSCRIPT_4_6.md`

> ECS system pitfalls → `docs/guides/pitfalls/ECS.md`

> State store integration pitfalls → `docs/guides/pitfalls/STATE.md`

> GUT and headless testing pitfalls → `docs/guides/pitfalls/TESTING.md`

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
  - `s_victory_handler_system.gd` → publishes post-validation victory event consumed by scene transitions to `"victory"` (scene must exist and be registered)
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
  - **Gameplay scenes**: Cursor is locked and hidden (for gameplay camera controls)

  DO NOT manually call `M_CursorManager.set_cursor_state()` in scene scripts unless you have a specific override requirement. The automatic management happens in `M_SceneManager._update_cursor_for_scene()` which is called after every scene transition. This prevents the common pitfall of loading a menu scene with a locked cursor (making buttons unclickable) or loading gameplay with a visible cursor (breaking immersion).

- **Transition callbacks should use a typed shared state object, not Array wrappers**: In `M_SceneManager`, mutable callback state now lives in `U_TransitionState` (`scripts/scene_management/helpers/u_transition_state.gd`).
  - Preferred pattern: create one `U_TransitionState` object before building callbacks, and let callbacks mutate fields on that object.
  - Avoid reintroducing `var something: Array = [value]` mutable-capture wrappers for transition state.
  - Keep camera blend handoff checks on the camera-manager interface (`I_CameraManager.is_blend_active()`), not private-member reflection.

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

> vCam, QB camera rule, room fade, wall visibility, and camera integration pitfalls → `docs/systems/vcam_manager/vcam-pitfalls.md`

> UI Manager navigation, focus, settings, and UI/Input boundary pitfalls → `docs/systems/ui_manager/ui-pitfalls.md`

> Test coverage status and manual QA limitations → `docs/guides/pitfalls/TESTING.md`
- **No C-style ternaries**: GDScript 4.5 rejects `condition ? a : b`. Use the native `a if condition else b` form and keep payload normalization readable.
- **Keep component discovery consistent**: Decoupled components (e.g., `C_MovementComponent`, `C_JumpComponent`, `C_RotateToInputComponent`, `C_AlignWithSurfaceComponent`) now auto-discover their peers, but components that still export NodePaths for scene nodes (landing indicator markers, floating raycasts, etc.) require those paths to be wired. Mixing patterns silently disables behaviour and breaks tests.
- **Reset support timers after jumps**: When modifying jump logic, remember to clear support/apex timers just like `C_JumpComponent.on_jump_performed()` does. Forgetting this can enable double jumps that tests catch.
- **Second-order tuning must respect clamped limits**: While tweaking response/damping values, verify they still honour `max_turn_speed_degrees` and `max_speed`. Oversight here reintroduces overshoot regressions covered by rotation/movement tests.
 - **ECS components require an entity root**: `M_ECSManager` associates components to entities by walking ancestors and picking the first node whose name starts with `E_`. If a component is not under such a parent, registration logs `push_error("M_ECSManager: Component <Name> has no entity root ancestor")` and the component is not tracked for entity queries. In tests and scenes, create an entity node (e.g., `var e := Node.new(); e.name = "E_Player"; e.add_child(component)`).
 - **Registration is deferred; yield a frame**: `ECSComponent._ready()` uses `call_deferred("_register_with_manager")`. After adding a manager/component, `await get_tree().process_frame` before asserting on registration (`get_components(...)`) or entity tracking to avoid race conditions.
 - **Required settings block registration**: Components like `C_JumpComponent`, `C_MovementComponent`, `C_FloatingComponent`, and `C_AlignWithSurfaceComponent` validate that their `*Settings` resources are assigned. Missing settings produce a `push_error("<Component> missing settings; assign an <Resource>.")` and skip registration. Wire default `.tres` in scenes, or set `component.settings = RS_*Settings.new()` in tests.
- **Input.mouse_mode changes may need a frame**: When toggling cursor lock/visibility rapidly (e.g., calling `toggle_cursor()` twice), yield a frame between calls in tests to let `Input.mouse_mode` settle on headless runners. Example: `manager.toggle_cursor(); await get_tree().process_frame; manager.toggle_cursor(); await get_tree().process_frame`.
- **Camera-relative forward uses negative Z**: Our input vector treats `Vector2.UP` (`y = -1`) as forward. When converting to camera space (see `S_MovementSystem`), multiply the input’s Y by `-1` before combining with `cam_forward`, otherwise forward/backward movement inverts.

> Mobile/touchscreen pitfalls → `docs/guides/pitfalls/MOBILE.md`

> UI Manager navigation, focus, settings, and UI/Input boundary pitfalls → `docs/systems/ui_manager/ui-pitfalls.md`

## Display Manager Pitfalls

### DisplayServer Thread Safety

**Problem**: Calling DisplayServer methods from non-main threads causes crashes or undefined behavior

**Solution**: Always use `call_deferred()` for DisplayServer operations:
```gdscript
# ❌ WRONG - direct call may be from wrong thread
func set_window_mode(mode: String) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ✅ CORRECT - deferred to main thread
func set_window_mode(mode: String) -> void:
    call_deferred("_apply_window_mode", mode)

func _apply_window_mode(mode: String) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
```

### UI Scale Transform Origin

**Problem**: Layout scaling via `Control.scale` or `CanvasLayer.transform` can push UI off-screen because scaling happens around the node's origin (top-left by default).

**Current behavior (2026-02-01)**: UI scale is **font-only** (no layout scaling). This avoids transform-origin issues entirely.

**If you reintroduce layout scaling**: Center the pivot or compensate position to avoid drift:
```gdscript
# For CanvasLayer - no pivot issue, transform is applied uniformly
canvas_layer.transform = Transform2D().scaled(Vector2(scale, scale))

# For Control - may need pivot adjustment
control.pivot_offset = control.size / 2  # Center pivot
control.scale = Vector2(scale, scale)
```

**Why this matters**: At high scales, a Control anchored to top-left will expand rightward/downward and can clip. Use pivoting or a centered container if layout scaling returns.

### Post-Process Layer Ordering

**Problem**: Post-process effects rendering on wrong layer obscure UI or fail to affect gameplay

**Solution**: Post-process overlay uses CanvasLayer at layer 100:
- Gameplay renders at layer 0 (default)
- Post-process effects render at layer 100 (above gameplay, below UI overlays)
- UI overlays render at layer 128+ (settings, pause, etc.)

**Do NOT add UIScaleRoot to the post-process overlay** - it's not UI and should not scale with UI settings.

### Headless DisplayServer Limitations

**Problem**: DisplayServer operations fail or behave unexpectedly in headless mode (CI, tests)

**Solution**: Tests that verify DisplayServer calls should be marked pending in headless mode:
```gdscript
func test_window_mode_fullscreen() -> void:
    if DisplayServer.get_name() == "headless":
        pending("Skipped: DisplayServer unavailable in headless mode")
        return
    # ... test logic
```

**Affected operations**:
- `DisplayServer.window_set_mode()` - window mode changes
- `DisplayServer.window_set_size()` - window resizing
- `DisplayServer.window_set_vsync_mode()` - vsync toggle
- Viewport texture capture

## Style & Resource Hygiene

- `.gd` files under `scripts/` (and the gameplay/unit tests that exercise them) must use tab indentation. The style suite (`tests/unit/style/test_style_enforcement.gd`) fails immediately on leading spaces, so run it before committing editor-authored changes.
- Trigger configuration resources (`RS_SceneTriggerSettings` derivatives) must include `script = ExtResource(...)` and should remain scene-local. Controllers now duplicate shared `.tres` files automatically, but avoid manually reusing the same resource across entities or the inspector will apply mutations to every instance.
- Avoid `Resource.new()` fallback allocation in hot-path config resolvers (for example ECS `process_tick` systems). Use canonical default config `.tres` instances (`resources/base_settings/*/cfg_*_config_default.tres`) and wire manager/system exports in scenes where applicable so tuning remains content-driven and allocation-free at runtime.

## AI System Pitfalls

- **`C_AIBrainComponent` rejects missing or wrong-type settings**: AI placeholder entities cannot leave `brain_settings` unset and cannot assign non-`RS_AIBrainSettings` resources. Registration is intentionally aborted in `_validate_required_settings()` when this contract is violated.
  - **Fix pattern**: for placeholders/demo scenes, assign a minimal valid `RS_AIBrainSettings` resource instead of `null`.

- **`RS_AIActionMoveTo` stalls on scene-authored NPCs that lack movement runtime components**: BT branches can score and start actions, but without `CharacterBody3D` + `C_InputComponent` + `C_MovementComponent`, `S_MoveTargetFollowerSystem` has no valid movement pipeline and the NPC never reaches move targets.
  - **Fix pattern**: when wiring demo/scene NPCs, always author the full runtime movement stack and assign valid movement settings (`cfg_movement_default` or equivalent) in addition to `C_AIBrainComponent`.

- **Transient input booleans are unsafe as BT utility-branch gates when evaluation is throttled**: gating branch conditions on one-frame fields like `gameplay.input.camera_center_just_pressed` can be missed entirely when `RS_AIBrainSettings.evaluation_interval` is greater than the pulse window.
  - **Fix pattern**: gate authored/demo BT branches on durable Redux flags (for example `gameplay.ai_demo_flags.*`) and set those flags from scene trigger zones (for example `Inter_AIDemoFlagZone`) instead of raw one-frame input pulses.

- **AI demo flags are gameplay actions, not navigation actions**: there is no `U_NavigationActions.set_gameplay_ai_demo_flag(...)`; trying to route AI trigger updates through navigation actions either fails at compile time or silently bypasses gameplay reducers.
  - **Fix pattern**: dispatch `U_GameplayActions.set_ai_demo_flag(flag_id, value)` from detection/interaction/alarm systems.

- **AI spawn-recovery tests can false-negative when movement support grace is still active**: if `C_MovementComponent.settings.support_grace_time > 0`, a freshly reset floating component may still be treated as "recently supported" for a short window, so `S_AISpawnRecoverySystem` intentionally does not recover yet. Waiting a frame can also let AI systems repopulate input/task state before assertions run.
  - **Fix pattern**: in deterministic tests, set `support_grace_time = 0.0` (or age `_last_support_time` well past grace), trigger recovery, and assert immediately after the recovery tick rather than after an extra physics frame.

- **`hover_height` must not exceed HoverRay length or the spring can never settle**: `S_FloatingSystem` uses raycasts to measure distance-to-ground and applies a spring-damper to hold the body at `hover_height`. If `RS_FloatingSettings.hover_height` exceeds the raycast `target_position.y` magnitude, rays lose contact before reaching the target altitude. This creates a perpetual bounce cycle: the body falls until rays detect ground, the spring launches it back up past ray range, rays lose contact, body falls again (~9-frame oscillation at 60fps).
  - **Symptom**: entity visibly bounces/jitters on flat ground while the player (with shorter `hover_height`) is perfectly stable.
  - **Fix pattern**: ensure every entity's HoverRay `target_position.y` magnitude is at least `hover_height + margin` (e.g., hover_height=1.75 → ray length ≥ 2.5). Override ray lengths in the prefab when the template's default rays are too short for the entity's hover settings.

- **Prefab NPC instances inherit placeholder brain settings unless overridden in the scene**: `prefab_demo_npc.tscn` ships with `cfg_ai_brain_placeholder.tres` (empty goals, no default goal). If a gameplay scene instances the prefab and overrides `entity_id`/`tags` but forgets to override `C_AIBrainComponent.brain_settings`, the entity registers with the ECS but has zero goals — it will never plan or move.
  - **Symptom**: NPC is visible and floating but completely stationary; `S_AIBehaviorSystem` finds the entity but `_select_goal()` always returns `null`.
  - **Fix pattern**: when instancing `prefab_demo_npc` in a gameplay scene, always override `brain_settings` on the `C_AIBrainComponent` child to point at the entity-specific brain resource (e.g., `cfg_patrol_drone_brain.tres`).

- **Scene-authored AI roots may not move even when the actor moves**: character prefabs commonly keep the entity root stationary and move the child `CharacterBody3D` (`Player_Body`). Movement-sensitive actions that compare against `entity.global_position` will think the actor or target never arrived, or will consume/chase/flee from stale positions.
  - **Symptom**: headless scene smoke shows brains ticking, but authored AI loops stall or silently complete without visible movement/progression. In the Woods scene this made Builder gather/haul/build fail even though the `CharacterBody3D` was moving correctly.
  - **Fix pattern**: use `U_AIActionPositionResolver.resolve_actor_position(context)` and `resolve_entity_position(target_entity)` in movement-sensitive AI actions. The resolver checks explicit `entity_position`, then `C_MovementComponent.get_character_body().global_position`, then the entity root fallback.

- **BT AI actions that scan scene entities need the active ECS manager in context**: scan/reserve/harvest/deposit/build actions resolve authored targets through `context["ecs_manager"]`. If `U_AIContextAssembler` omits it, actions can start and even advance BT sequence state, but target resolution returns null and side effects never happen.
  - **Symptom**: `RS_AIActionMoveToNearest` completes as if no target was found, `RS_AIActionHarvest` loops with empty inventory/resource changes, and scene smoke fails progression assertions.
  - **Fix pattern**: keep `U_AIContextAssembler.build_context(...)` injecting the active scene manager via `rule_context.set_extra(&"ecs_manager", manager)` and add focused tests when introducing new scan/target actions.
