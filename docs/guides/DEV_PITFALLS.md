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

> Scene Manager transition, overlay, trigger, spawn, camera-blend, cache, and pitfall guidance → `docs/systems/scene_manager/scene-manager-overview.md`

> Input Manager ownership, runtime contracts, and pitfalls → `docs/systems/input_manager/input-manager-overview.md`

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
