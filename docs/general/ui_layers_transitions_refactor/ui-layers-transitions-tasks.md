# UI, Layers & Transitions Refactor — Tasks

## Scope / Goals

- Centralize canvas layer constants, fix z-order bugs, eliminate runtime reparenting hacks, standardize node discovery, decouple transitions from HUD knowledge, unify tween creation, and remove dead code.
- Result: a predictable, single-source-of-truth layer stack where no gameplay VFX can render above system overlays, and transitions/VFX are cleanly separated from UI concerns.

## Constraints (Non-Negotiable)

- Do not start implementation while the working tree is in an unknown/dirty state.
- Keep commits small and test-green.
- Commit documentation updates separately from implementation changes.
- After any file move/rename or scene/resource structure change, run `tests/unit/style/test_style_enforcement.gd`.
- Do not break existing transition behavior — fade, loading screen, and instant transitions must continue to work identically from the user's perspective.
- Update `SCENE_ORGANIZATION_GUIDE.md` after any layer number or container changes.

---

## Phase 0 — Baseline & Inventory (Read-Only)

- [ ] Confirm test baselines:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_management -ginclude_subdirs=true` (if exists)
- [ ] Record baseline results and any pre-existing failures in this document.
- [ ] Audit all canvas layer numbers currently in use:
  - Grep for `layer = ` in `.tscn` files and `\.layer\s*=` in `.gd` files.
  - Document the full layer map with source file references.

---

## Phase 1 — Centralize Canvas Layer Constants + Fix DamageFlash Z-Order

### 1A — Create `U_CanvasLayers` Constant Class

- [ ] Create `scripts/ui/u_canvas_layers.gd` with `class_name U_CanvasLayers extends RefCounted`.
- [ ] Define all layer constants:
  ```gdscript
  # Root viewport layers (draw order)
  const HUD := 6
  const UI_OVERLAY := 10
  const UI_COLOR_BLIND := 11
  const TRANSITION := 50
  const DAMAGE_FLASH := 90       # was 110, moved BELOW loading
  const LOADING := 100
  const MOBILE_CONTROLS := 101
  const DEBUG_OVERLAY := 128

  # GameViewport-internal layers (separate layer space)
  const PP_FILM_GRAIN := 2
  const PP_DITHER := 3
  const PP_CRT := 4
  const PP_COLOR_BLIND := 5
  ```
- [ ] Verify no existing `class_name U_CanvasLayers` conflicts.

### 1B — Replace Hardcoded Layer Numbers

- [ ] Update `scenes/ui/overlays/ui_damage_flash_overlay.tscn`: change `layer` from `110` to `90`.
- [ ] Update `scripts/ui/hud/ui_hud_controller.gd`: replace hardcoded `layer = 6` with `U_CanvasLayers.HUD`.
- [ ] Update `scripts/managers/helpers/display/u_display_post_process_applier.gd`: UIColorBlindLayer `layer = 11` → `U_CanvasLayers.UI_COLOR_BLIND`.
- [ ] Verify `scenes/root.tscn` layer values match constants (HUDLayer=6, UIOverlayStack=10, TransitionOverlay=50, LoadingOverlay=100). These are in `.tscn` so can stay as literals but document they must match `U_CanvasLayers`.
- [ ] **Note:** Post-process layers (2-5) in `ui_post_process_overlay.tscn` are inside `GameViewport` (different layer space). Keep as `.tscn` literals; the `PP_*` constants are reference documentation only.
- [ ] Grep for any remaining hardcoded layer assignments and update them.
- [ ] Update `docs/general/SCENE_ORGANIZATION_GUIDE.md` with the new canonical layer map referencing `U_CanvasLayers`.

### 1C — Tests

- [ ] Run style enforcement tests.
- [ ] Run manager and display test suites.
- [ ] Verify no regressions.

---

## Phase 2 — Remove Dead Code

### 2A — `_tween_pause_mode` in `u_damage_flash.gd`

- [ ] Remove `var _tween_pause_mode: int = -1` (line 9).
- [ ] Remove `_tween_pause_mode = Tween.TWEEN_PAUSE_PROCESS` (line 32).
- [ ] Update test in `tests/` that reads `_damage_flash._tween_pause_mode` — either remove that assertion or replace with checking the tween directly.
- [ ] Confirm no external code references this field.

### 2B — `_effects_container` — DO NOT REMOVE

> **WARNING:** This is **live code** used by `U_ParticleSpawner` → `S_SpawnParticlesSystem`, `S_JumpParticlesSystem`, `S_LandingParticlesSystem`. Leave it alone.

### 2C — Tests

- [ ] Run VFX-related tests (if any exist).
- [ ] Run full manager test suite.

---

## Phase 3 — Unify Tween Creation (DamageFlash → U_TweenManager)

### 3A — Route DamageFlash Through U_TweenManager

- [ ] Change `U_DamageFlash._init` signature from `(flash_rect, scene_tree)` to `(flash_rect, owner_node)` where `owner_node` is the `CanvasLayer` instance (the DamageFlashOverlay).
- [ ] Replace tween creation:
  ```gdscript
  # Before:
  _tween = _scene_tree.create_tween()
  _tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

  # After:
  var config := U_TweenManager.TweenConfig.new()
  config.process_mode = Tween.TWEEN_PROCESS_IDLE  # not PHYSICS — visual-only fade
  _tween = U_TweenManager.create_transition_tween(_owner_node, config)
  _tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  ```
- [ ] **Note:** `U_TweenManager.create_transition_tween` calls `set_process_mode` but not `set_pause_mode`. The pause mode (`TWEEN_PAUSE_PROCESS` = runs during pause) is a separate Tween concept. Set it explicitly after creation.
- [ ] Remove manual tween kill logic if `U_TweenManager` handles it.

### 3B — Update Caller in `m_vfx_manager.gd`

- [ ] Update construction call:
  ```gdscript
  # Before (line ~107):
  _damage_flash = U_DamageFlash.new(flash_rect, get_tree())
  # After:
  _damage_flash = U_DamageFlash.new(flash_rect, flash_instance)
  ```

### 3C — Audit Other Manual Tween Sites

- [ ] Grep for `create_tween()` calls outside of `U_TweenManager`.
- [ ] Evaluate each for migration — only migrate if it's a transition/VFX tween (don't touch gameplay animation tweens).

### 3D — Tests

- [ ] Verify damage flash still triggers and fades correctly.
- [ ] Verify fade transitions still work.
- [ ] Run manager test suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`

---

## Phase 4 — Standardize Node Discovery (ServiceLocator Only)

### 4A — Register Containers in `root.gd`

- [ ] Add container registrations after the manager registrations (containers are direct children of Root, not Managers):
  ```gdscript
  _register_container("HUDLayer", StringName("hud_layer"))
  _register_container("UIOverlayStack", StringName("ui_overlay_stack"))
  _register_container("TransitionOverlay", StringName("transition_overlay"))
  _register_container("LoadingOverlay", StringName("loading_overlay"))
  _register_container("GameViewportContainer/GameViewport/ActiveSceneContainer", StringName("active_scene_container"))
  ```
- [ ] Add helper method:
  ```gdscript
  func _register_container(path: String, service_name: StringName) -> void:
      var node := get_node_or_null(path)
      if node != null:
          U_ServiceLocator.register(service_name, node)
  ```
- [ ] Also register post-process and game viewport nodes:
  ```gdscript
  _register_container("GameViewportContainer/GameViewport/PostProcessOverlay", StringName("post_process_overlay"))
  _register_container("GameViewportContainer/GameViewport", StringName("game_viewport"))
  ```

### 4B — Update `U_SceneManagerNodeFinder.find_containers()`

- [ ] Replace all `find_child()` with `ServiceLocator.try_get_service()`:
  ```gdscript
  refs.active_scene_container = U_SERVICE_LOCATOR.try_get_service(StringName("active_scene_container"))
  refs.ui_overlay_stack = U_SERVICE_LOCATOR.try_get_service(StringName("ui_overlay_stack")) as CanvasLayer
  refs.transition_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("transition_overlay")) as CanvasLayer
  refs.loading_overlay = U_SERVICE_LOCATOR.try_get_service(StringName("loading_overlay")) as CanvasLayer
  ```
- [ ] Remove the `root` walk-up logic and all `find_child` fallbacks.
- [ ] Keep error/warning pushes for null results.

### 4C — Update `U_DisplayPostProcessApplier._setup_post_process_overlay()`

- [ ] Replace `tree.root.find_child("PostProcessOverlay")` with ServiceLocator lookup using `StringName("post_process_overlay")`.
- [ ] Use `StringName("game_viewport")` for the fallback instantiation path.

### 4D — Test Considerations

- [ ] Tests that previously relied on `find_child()` auto-discovery will need to register their mock nodes in `ServiceLocator` in `before_each`.
- [ ] `TransitionOverlay` and `LoadingOverlay` already have this pattern — extend it to `ActiveSceneContainer` and `UIOverlayStack`.
- [ ] Run scene management tests.
- [ ] Run display tests.
- [ ] Run full test suite to catch regressions.

---

## Phase 5 — Decouple Transitions from HUD via Redux

### 5A — HUD Subscribes to Redux for Visibility

Key insight: `UI_HudController` already subscribes to `slice_updated` for the `"scene"` slice (line 131-133) and calls `_update_display()`. The `_update_health()` method already hides the health bar when `shell != "gameplay"`.

- [ ] Add visibility toggle to `_on_slice_updated` or `_update_display`:
  ```gdscript
  var scene_state: Dictionary = state.get("scene", {})
  var is_transitioning: bool = scene_state.get("is_transitioning", false)
  visible = not is_transitioning and shell == StringName("gameplay")
  ```
  This replaces the need for `Trans_LoadingScreen` to reach in and hide the HUD.

### 5B — Remove HUD Hiding from `Trans_LoadingScreen`

- [ ] Remove `_hide_hud_layers()` calls (lines 71, 130, 193).
- [ ] Remove `_restore_hidden_hud_layers()` call (line 249).
- [ ] Remove these methods entirely:
  - `_resolve_hud_controller()`
  - `_hide_hud_layers()`
  - `_restore_hidden_hud_layers()`
  - `_toggle_visibility()`
- [ ] Remove `_temporarily_hidden_hud_nodes` array.
- [ ] Remove the `U_ServiceLocator` import/usage if no longer needed.

### 5C — Remove HUD Registration from M_SceneManager

- [ ] Remove from `m_scene_manager.gd`: `_hud_controller` field, `register_hud_controller()`, `unregister_hud_controller()`, `get_hud_controller()`.
- [ ] Remove same methods from `i_scene_manager.gd` interface.
- [ ] Remove same methods from `tests/mocks/mock_scene_manager_with_transition.gd`.
- [ ] Remove `_register_with_scene_manager()` and `_unregister_from_scene_manager()` from `ui_hud_controller.gd`.
- [ ] Remove the `_unregister_from_scene_manager()` call from `_exit_tree()`.

### 5D — Tests

- [ ] Verify loading screen transition still hides HUD (via Redux now).
- [ ] Verify HUD reappears after transition completes.
- [ ] Verify fade transitions (which don't involve HUD hiding) are unaffected.
- [ ] Run scene management and manager test suites.

---

## Phase 6 — Replace HUD Self-Reparenting with Manager-Driven Instantiation

### 6A — Remove HUD from Gameplay Scene Template

- [ ] Remove `[node name="HUD" ... instance=ExtResource("11_hud")]` from `scenes/templates/tmpl_base_scene.tscn`.
- [ ] Remove the `ext_resource` for `ui_hud_overlay.tscn` from the same file.
- [ ] Check all gameplay scenes that inherit from this template — they should inherit the removal.

### 6B — M_SceneManager Instantiates HUD Under HUDLayer

- [ ] In `M_SceneManager._ready()`, after containers are found:
  ```gdscript
  const HUD_SCENE := preload("res://scenes/ui/hud/ui_hud_overlay.tscn")

  # In _ready() after find_containers:
  var hud_layer := U_ServiceLocator.try_get_service(StringName("hud_layer")) as CanvasLayer
  if hud_layer != null:
      var hud_instance := HUD_SCENE.instantiate()
      hud_layer.add_child(hud_instance)
  ```

### 6C — Remove Reparenting from `UI_HudController`

- [ ] Remove `_reparent_to_root_hud_layer()` method entirely.
- [ ] Remove the `_reparent_to_root_hud_layer()` call from `_complete_initialization()`.
- [ ] The HUD is now born in `HUDLayer` — no reparenting needed.
- [ ] Remove the `layer = 6` assignment (it's a child of HUDLayer, which is already at layer 6).
- [ ] **Keep** `_complete_initialization()` for event subscriptions — just remove the reparent call from it.

### 6D — HUD Visibility Driven by Redux (from Phase 5)

- [ ] HUD starts hidden (`visible = false` in scene or `_ready()`).
- [ ] When the navigation shell changes to `"gameplay"` and `is_transitioning` is false, it becomes visible.
- [ ] When transitioning or in a non-gameplay shell, it hides.

### 6E — Tests

- [ ] Verify HUD appears correctly during gameplay.
- [ ] Verify HUD is hidden/absent during menus.
- [ ] Verify transitions still work with the new HUD lifecycle.
- [ ] Run HUD tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true`
- [ ] Run full test suite.

---

## Phase 7 — Final Validation & Documentation

- [ ] Run full test suite: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true`.
- [ ] Update `docs/general/SCENE_ORGANIZATION_GUIDE.md` with:
  - New canonical layer map referencing `U_CanvasLayers`.
  - ServiceLocator container registration list.
  - HUD lifecycle description.
- [ ] Update `docs/general/DEV_PITFALLS.md` with:
  - "Always use `U_CanvasLayers` constants for layer assignments."
  - "HUD is manager-instantiated under HUDLayer — do not add to gameplay scenes."
- [ ] Update `AGENTS.md` if new architectural patterns were introduced.
- [ ] Update this task list with final completion notes.
- [ ] Update continuation prompt with final status.
- [ ] Manual smoke test:
  - Launch game, take damage (flash should appear below loading screen).
  - Trigger a loading transition (HUD should hide).
  - Navigate menus → gameplay → menus (HUD toggles correctly).

---

## Files Modified (Summary)

| File | Phase | Change |
|------|-------|--------|
| `scripts/ui/u_canvas_layers.gd` | 1 | **NEW** — layer constants |
| `scenes/ui/overlays/ui_damage_flash_overlay.tscn` | 1 | layer 110→90 |
| `scripts/ui/hud/ui_hud_controller.gd` | 1,5,6 | Use constant, add visibility logic, remove reparent+registration |
| `scripts/managers/helpers/display/u_display_post_process_applier.gd` | 1,4 | Use constant, ServiceLocator discovery |
| `scripts/managers/helpers/u_damage_flash.gd` | 2,3 | Remove vestigial field, use U_TweenManager |
| `scripts/managers/m_vfx_manager.gd` | 3 | Update U_DamageFlash construction |
| `scripts/root.gd` | 4 | Register containers in ServiceLocator |
| `scripts/scene_management/helpers/u_scene_manager_node_finder.gd` | 4 | ServiceLocator only |
| `scripts/scene_management/transitions/trans_loading_screen.gd` | 5 | Remove HUD hiding logic |
| `scripts/managers/m_scene_manager.gd` | 5,6 | Remove HUD registration, add HUD instantiation |
| `scripts/interfaces/i_scene_manager.gd` | 5 | Remove HUD methods from interface |
| `tests/mocks/mock_scene_manager_with_transition.gd` | 5 | Remove HUD mock methods |
| `scenes/templates/tmpl_base_scene.tscn` | 6 | Remove HUD instance |
| Tests (various) | 2-6 | Update for new APIs, ServiceLocator registrations |

---

## Verification Checkpoints

1. **After Phase 1:** Run `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
2. **After Phase 3:** Run `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (VFX/damage flash tests)
3. **After Phase 4:** Run scene management and display tests
4. **After Phase 5:** Run scene management tests
5. **After Phase 6:** Run HUD tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true`
6. **Final:** Run full suite: `tools/run_gut_suite.sh -gdir=res://tests/ -ginclude_subdirs=true`
