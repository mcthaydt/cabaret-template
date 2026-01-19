# Groups Cleanup Tasks

## Overview

Remove `add_to_group()`/`is_in_group()`/`get_nodes_in_group()` usage throughout the codebase in favor of explicit, type-safe alternatives (manager dictionaries, direct references, tag components).

**Priority:** Low (architectural consistency)
**Status:** In Progress (Phase 0 Complete)
**Continuation Prompt:** `docs/general/cleanup_v3/groups-cleanup-continuation-prompt.md`

---

## Pre-work Audit (2026-01-19)

### Current Usage Counts

| Pattern | Production Files | Test Files | Total |
|---------|------------------|------------|-------|
| `add_to_group()` | 14 | 40 | 54 |
| `get_nodes_in_group()` | 10 | 26 | 36 |
| `is_in_group()` | 10 | 9 | 19 |

### ServiceLocator State (Updated 2026-01-19)

`U_ServiceLocator` exists and is robust (`scripts/core/u_service_locator.gd`).

**Registered via `main.gd` (centralized) - 12 services:**

- `state_store`, `cursor_manager`, `scene_manager`, `pause_manager`, `spawn_manager`
- `camera_manager`, `vfx_manager`, `audio_manager`, `input_profile_manager`, `input_device_manager`
- `ui_input_handler`, `save_manager`

**Dual registration (centralized + self-register) - 3 managers:**

- `save_manager` - Listed in `main.gd` AND self-registers in `m_save_manager.gd:62`
- `audio_manager` - Listed in `main.gd` AND self-registers in `m_audio_manager.gd:70`
- `camera_manager` - Listed in `main.gd` AND self-registers in `m_camera_manager.gd:57`

**Dependency registrations in `main.gd`:**

- `pause_manager` → `state_store`, `cursor_manager`
- `spawn_manager` → `state_store`
- `scene_manager` → `state_store`
- `camera_manager` → `state_store`
- `vfx_manager` → `state_store`, `camera_manager`
- `audio_manager` → `state_store`
- `input_profile_manager` → `state_store`
- `input_device_manager` → `state_store`
- `save_manager` → `state_store`, `scene_manager`

### Blockers / Prerequisites (Resolved)

1. ✅ **Standardize registration pattern** - Decision: Do both centralized + self-registration as fallback

2. ✅ **Add `audio_manager` to `main.gd`** - Added in Phase 0

3. ~~**Remove duplicate `save_manager` self-registration**~~ - Kept for fallback pattern (intentional)

4. **Test files use groups extensively** - 40+ test files add nodes to groups for setup; these need ServiceLocator registration instead

---

## Why Remove Groups?

- **String-based lookups** - typo-prone, no compile-time safety
- **Implicit coupling** - any node can join any group, hard to trace
- **Global queries** - scattered `get_nodes_in_group()` calls instead of centralized tracking
- **Inconsistent with ECS** - components and manager dictionaries should handle categorization

---

## Migration Strategy: Keep Fallbacks Until Complete

**CRITICAL**: The utility functions (`U_StateUtils.get_store()`, `U_ECSUtils.get_manager()`) already have a 3-tier fallback:

1. `@export` injection (for tests)
2. ServiceLocator lookup (primary)
3. Group lookup (backward compatibility)

**Safe Migration Order:**

1. Update all consumers to use ServiceLocator first
2. Update all tests to use ServiceLocator registration
3. Verify all tests pass with ServiceLocator
4. Remove group fallback from utility functions
5. Remove `add_to_group()` calls from managers

---

## Groups Usage Categories

### 1. Manager/Service Discovery (High Priority)

**Files:** 12 managers | **Pattern:** Singleton service locator via groups

| File | Line | Group | Current State |
|------|------|-------|---------------|
| `m_state_store.gd` | 80 | `state_store` | Adds to group in `_ready()` |
| `m_ecs_manager.gd` | 46 | `ecs_manager` | Adds to group in `_ready()` |
| `m_scene_manager.gd` | - | `scene_manager` | Adds to group in `_ready()` |
| `m_audio_manager.gd` | 69 | `audio_manager` | Adds to group + self-registers ServiceLocator |
| `m_vfx_manager.gd` | - | `vfx_manager` | Adds to group in `_ready()` |
| `m_spawn_manager.gd` | - | `spawn_manager` | Adds to group in `_ready()` |
| `m_camera_manager.gd` | - | `camera_manager` | Adds to group in `_ready()` |
| `m_save_manager.gd` | 62 | `save_manager` | Adds to group + self-registers ServiceLocator |
| `m_input_device_manager.gd` | 64 | `input_device_manager` | Adds to group in `_ready()` |
| `m_input_profile_manager.gd` | - | `input_profile_manager` | Adds to group in `_ready()` |
| `m_cursor_manager.gd` | 26 | `cursor_manager` | Adds to group in `_ready()` |
| `m_pause_manager.gd` | - | `pause_manager` | Adds to group in `_ready()` |

**Production code querying these groups:**

| File | Line | Group | Query Method |
|------|------|-------|--------------|
| `u_state_utils.gd` | 40 | `state_store` | `get_nodes_in_group()` (fallback) |
| `u_scene_manager_node_finder.gd` | 88 | `state_store` | `get_nodes_in_group()` |
| `ui_input_rebinding_overlay.gd` | 153 | `state_store` | `get_nodes_in_group()` |
| `ui_button_prompt.gd` | 197 | `input_device_manager` | `is_in_group()` traversal |

**Migration:** Replace with `U_ServiceLocator.get_service()` or `U_ServiceLocator.try_get_service()`.

---

### 2. Entity Group (High Priority)

**Files:** 3 | **Pattern:** ECS entity categorization

| File | Line | Usage |
|------|------|-------|
| `base_ecs_entity.gd` | 16-17 | Conditional add via `add_legacy_group` flag |
| `u_ecs_utils.gd` | 62 | `is_in_group(ENTITY_GROUP)` check in `find_entity_root()` |
| `u_ecs_utils.gd` | 106,122 | Generic group query helpers |

**Current State:** `add_legacy_group` is `false` by default - entities do NOT add to group unless explicitly enabled.

**Migration:**

- Remove `is_in_group(ENTITY_GROUP)` check in `find_entity_root()` - rely on script type check and `E_` prefix
- Remove `ENTITY_GROUP` constant
- Remove `add_legacy_group` export (no longer needed)

---

### 3. Camera Discovery (Medium Priority)

**Files:** 3 | **Pattern:** Main camera lookup

| File | Line | Usage |
|------|------|-------|
| `m_camera_manager.gd` | 156 | `is_in_group("main_camera")` to detect camera changes |
| `m_scene_manager.gd` | 532 | `get_nodes_in_group("main_camera")` for camera blending |
| `m_spawn_manager.gd` | 222 | `get_nodes_in_group("main_camera")` for spawn positioning |

**Test files using this group (36 occurrences):**

| File | Occurrences | Pattern |
|------|-------------|---------|
| `test_camera_manager.gd` | 18 | `camera.add_to_group("main_camera")` |
| `test_camera_state.gd` | 12 | `camera.add_to_group("main_camera")` |
| `test_vfx_camera_integration.gd` | 1 | `_camera.add_to_group("main_camera")` |
| `test_scene_contract.gd` | 3 | `camera.add_to_group("main_camera")` |
| `perf_ecs_baseline.gd` | 1 | `camera.add_to_group("main_camera")` |
| `test_u_ecs_utils.gd` | 1 | `camera.add_to_group(StringName("main_camera"))` |

**Migration:**

1. Add `M_CameraManager.register_main_camera(camera: Camera3D)` method
2. Add `M_CameraManager.unregister_main_camera()` method
3. Add `M_CameraManager.get_main_camera() -> Camera3D` method
4. Track camera directly in manager's `_main_camera` variable
5. Update all test files to use `camera_manager.register_main_camera(camera)`
6. Update production consumers to use `camera_manager.get_main_camera()`

---

### 4. UI Groups (Medium Priority)

**Files:** 4 | **Pattern:** UI element discovery

| File | Line | Group | Usage |
|------|------|-------|-------|
| `ui_mobile_controls.gd` | 53 | `mobile_controls` | Self-registers |
| `ui_hud_controller.gd` | 35,60,66 | `hud_controllers` | Self-registers, cleanup, duplicate check |
| `trans_loading_screen.gd` | 289 | `hud_controllers` | Queries for HUD visibility |
| `m_state_store.gd` | 176 | `state_debug_overlay` | Debug overlay tracking |

**Migration:**

- `hud_controllers`: Track in `M_SceneManager` or create lightweight UI registry
- `mobile_controls`: Track in `M_InputDeviceManager`
- `state_debug_overlay`: Already tracked as direct reference in state store

---

### 5. Effects Container (Low Priority)

**Files:** 1 | **Pattern:** VFX container discovery

| File | Line | Usage |
|------|------|-------|
| `u_particle_spawner.gd` | 178,192 | `get_nodes_in_group("effects_container")` |

**Migration:**

- `M_VFXManager` should track/provide the effects container
- Add `M_VFXManager.get_effects_container() -> Node` method

---

### 6. Manager Group (Low Priority)

**Files:** 1 | **Pattern:** Generic manager check

| File | Line | Usage |
|------|------|-------|
| `u_ecs_utils.gd` | 244 | `is_in_group(MANAGER_GROUP)` |

**Migration:**

- Check against `U_ServiceLocator.get_registered_services()` instead
- Or use `node is I_ECSManager` type check

---

### 7. Scene Contract (Low Priority)

**Files:** 1 | **Pattern:** Generic group membership check

| File | Line | Usage |
|------|------|-------|
| `i_scene_contract.gd` | 158 | `node.is_in_group(group_name)` |

**Migration:**

- Review usage context - this is a generic contract validation
- May need case-by-case replacement based on what groups are being validated

---

## Test File Migration Details

### Category A: Manager Group Tests (ServiceLocator Migration)

These tests add nodes to manager groups. Replace with `U_ServiceLocator.register()`.

**Pattern to replace:**

```gdscript
# OLD
_store = M_StateStore.new()
_store.add_to_group("state_store")
add_child_autofree(_store)

# NEW
_store = M_StateStore.new()
add_child_autofree(_store)
U_ServiceLocator.register(StringName("state_store"), _store)
```

**Files requiring this change:**

| File | Line | Group | Change |
|------|------|-------|--------|
| `test_pause_menu_navigation.gd` | 15 | `state_store` | Replace with ServiceLocator |
| `test_input_profile_selector.gd` | 32 | `state_store` | Replace with ServiceLocator |
| `test_input_profile_selector.gd` | 43 | `input_profile_manager` | Replace with ServiceLocator |
| `test_edit_touch_controls_overlay.gd` | 38 | `input_profile_manager` | Replace with ServiceLocator |
| `test_touchscreen_settings_overlay.gd` | 27 | `input_profile_manager` | Replace with ServiceLocator |
| `test_input_rebinding_overlay.gd` | 38 | `scene_manager` | Replace with ServiceLocator |
| `test_input_rebinding_overlay.gd` | 421 | `input_profile_manager` | Replace with ServiceLocator |
| `test_ui_input_handler.gd` | 229 | `state_store` | Replace with ServiceLocator |
| `test_spawn_system_basic.gd` | 18 | `spawn_manager` | Replace with ServiceLocator |
| `test_triggered_interactable_controller.gd` | 205 | `scene_manager` | Replace with ServiceLocator |
| `test_e_door_trigger_controller.gd` | 22 | `scene_manager` | Replace with ServiceLocator |
| `test_victory_system_example.gd` | 195 | `scene_manager` | Replace with ServiceLocator |
| `test_health_system.gd` | 266 | `scene_manager` | Replace with ServiceLocator |
| `test_damage_system.gd` | 287 | `scene_manager` | Replace with ServiceLocator |
| `mock_save_manager.gd` | 24 | `save_manager` | Replace with ServiceLocator |

**Cleanup requirement:** Add `U_ServiceLocator.clear()` to `after_each()` in all test files to prevent cross-test pollution.

```gdscript
func after_each() -> void:
    U_ServiceLocator.clear()
```

---

### Category B: Camera Group Tests (Camera Manager Migration)

These tests add cameras to `main_camera` group. Replace with camera manager registration.

**Prerequisite:** Create `M_CameraManager.register_main_camera()` and `get_main_camera()` methods.

**Pattern to replace:**

```gdscript
# OLD
var camera := Camera3D.new()
camera.add_to_group("main_camera")
test_scene.add_child(camera)

# NEW (after camera manager method exists)
var camera := Camera3D.new()
test_scene.add_child(camera)
camera_manager.register_main_camera(camera)
```

**Files requiring this change:**

| File | Occurrences | Notes |
|------|-------------|-------|
| `test_camera_manager.gd` | 18 | Core camera tests - update method signatures |
| `test_camera_state.gd` | 12 | Camera state capture tests |
| `test_vfx_camera_integration.gd` | 1 | VFX camera tests |
| `test_scene_contract.gd` | 3 | Scene validation tests |
| `perf_ecs_baseline.gd` | 1 | Performance baseline |
| `test_u_ecs_utils.gd` | 1 | ECS utility tests |

**Total: 36 occurrences across 6 files**

---

### Category C: Generic Group Tests (ECS Utils)

| File | Line | Usage | Migration |
|------|------|-------|-----------|
| `test_u_ecs_utils.gd` | 151 | `singleton.add_to_group(group_name)` | Test-specific, may keep for testing group utils |
| `test_u_ecs_utils.gd` | 177 | `node.add_to_group(group_name)` | Test-specific, may keep for testing group utils |
| `test_input_manager_integration_points.gd` | 35 | `manager.add_to_group("test_manager_group")` | Custom test group, not production |

**Note:** Some of these are testing the group utility functions themselves. These may need to remain as-is until we remove the utility functions entirely.

---

## Task Checklist

### Phase 0: ServiceLocator Prerequisites ✅

- [x] **Decision made**: Do both centralized registration AND self-registration as fallback
- [x] Add `M_AudioManager` registration to `main.gd:35` (after `M_VFXManager`)
  - File: `scripts/scene_structure/main.gd`
  - Added: `_register_if_exists(managers_node, "M_AudioManager", StringName("audio_manager"))`
- [x] Keep self-registration in managers (provides fallback for gameplay scenes)
- [x] Verify all 12 managers listed in `main.gd`
- [x] Add missing dependency registrations to `main.gd`:
  - Added: `vfx_manager` → `state_store`, `camera_manager`
  - Added: `audio_manager` → `state_store`
- [ ] Run all tests to confirm baseline passes:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/integration -gexit
  ```

### Phase 1: Camera Manager Infrastructure

Create camera tracking methods before updating any consumers.

- [x] Add to `m_camera_manager.gd`:
  ```gdscript
  var _main_camera: Camera3D = null

  func register_main_camera(camera: Camera3D) -> void:
      _main_camera = camera

  func unregister_main_camera() -> void:
      _main_camera = null

  func get_main_camera() -> Camera3D:
      return _main_camera
  ```
- [x] Update `_on_scene_registered()` (line 156) to use `register_main_camera()` instead of group check *(manager has no scene registration hook; `_find_camera_in_scene()` now prefers the registered main camera when present)*
- [x] Run camera tests to verify infrastructure works:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/camera_system -gdir=res://tests/integration/camera_system -gexit
  ```

### Phase 2: Camera Test Migration (36 occurrences)

- [x] Updated camera/system tests, VFX integration, scene contract validation tests, perf baseline, and ECS utils tests to use camera registration / type-based lookup (removed all `add_to_group("main_camera")` usage).
- [x] Added ServiceLocator main-camera fallback in `U_ECSUtils.get_active_camera()` and cleared ServiceLocator in camera-related tests to prevent duplicate registration warnings.
- [x] Verify camera tests pass:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/camera_system -gdir=res://tests/integration/camera_system -gexit
  ```

### Phase 3: Production Camera Code Migration

- [x] Update `m_scene_manager.gd:532`:
  ```gdscript
  # OLD
  var new_cameras: Array = get_tree().get_nodes_in_group("main_camera")

  # NEW
  var camera_manager := U_ServiceLocator.try_get_service(StringName("camera_manager"))
  var new_camera: Camera3D = null
  if camera_manager and camera_manager.has_method("get_main_camera"):
      new_camera = camera_manager.get_main_camera()
  ```
- [x] Update `m_spawn_manager.gd:222`:
  ```gdscript
  # OLD
  var cameras: Array = get_tree().get_nodes_in_group("main_camera")

  # NEW
  var camera_manager := U_ServiceLocator.try_get_service(StringName("camera_manager"))
  var camera: Camera3D = null
  if camera_manager and camera_manager.has_method("get_main_camera"):
      camera = camera_manager.get_main_camera()
  ```
- [x] Remove `is_in_group("main_camera")` from `m_camera_manager.gd:156` - use internal tracking instead *(done in Phase 2 alongside registration updates)*
- [x] **Scene contract camera validation** - Update `i_scene_contract.gd:80-82`:
  ```gdscript
  # OLD: var camera: Node = _find_node_in_group(scene, "main_camera")
  # NEW: Find Camera3D by type (not group)
  var camera: Node = _find_camera_by_type(scene)
  # Update error message (line 82)
  if camera == null:
      result.errors.append("Gameplay scene missing camera (expected Camera3D node)")
  ```
  - Add `_find_camera_by_type()` helper that recursively finds Camera3D nodes by type
  - Camera already named `E_PlayerCamera` in `tmpl_camera.tscn` (no renaming needed)
- [x] **Template cleanup** - Remove `groups=["main_camera"]` from `templates/tmpl_camera.tscn:10`
- [x] Run integration tests (2026-02-08): all scene manager integration suites passing; warnings only for intentionally missing managers/overlays in test scaffolds.
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit
  ```

### Phase 4: Manager Test Migration (15 occurrences)

Update tests to use `U_ServiceLocator.register()` instead of `add_to_group()`.

**For each file, make two changes:**

1. Replace `add_to_group()` with `U_ServiceLocator.register()`
2. Add `U_ServiceLocator.clear()` to `after_each()`

#### state_store tests

- [x] `test_pause_menu_navigation.gd:15`:
  ```gdscript
  # OLD: _store.add_to_group("state_store")
  # NEW:
  U_ServiceLocator.register(StringName("state_store"), _store)
  ```
- [x] Add `after_each()` with `U_ServiceLocator.clear()`
- [x] `test_input_profile_selector.gd:32` - same pattern
- [x] `test_ui_input_handler.gd:229` - same pattern

#### input_profile_manager tests

- [x] `test_input_profile_selector.gd:43`:
  ```gdscript
  # OLD: _manager.add_to_group("input_profile_manager")
  # NEW:
  U_ServiceLocator.register(StringName("input_profile_manager"), _manager)
  ```
- [x] `test_edit_touch_controls_overlay.gd:38` - same pattern
- [x] `test_touchscreen_settings_overlay.gd:27` - same pattern
- [x] `test_input_rebinding_overlay.gd:421` - same pattern

#### scene_manager tests

- [x] `test_input_rebinding_overlay.gd:38`:
  ```gdscript
  # OLD: _scene_manager_mock.add_to_group("scene_manager")
  # NEW:
  U_ServiceLocator.register(StringName("scene_manager"), _scene_manager_mock)
  ```
- [x] `test_triggered_interactable_controller.gd:205` - same pattern
- [x] `test_e_door_trigger_controller.gd:22` - same pattern
- [x] `test_victory_system_example.gd:195` - same pattern
- [x] `test_health_system.gd:266` - same pattern
- [x] `test_damage_system.gd:287` - same pattern

#### Other manager tests

- [x] `test_spawn_system_basic.gd:18` - spawn_manager
- [x] `mock_save_manager.gd:24` - save_manager (register only when unregistered to avoid duplicate warnings)

#### Verify UI tests pass (Ran 2026-02-08 - green)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gexit
```

Additional targeted test runs (2026-02-08):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/gameplay -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/spawn_system -gexit
```

### Phase 5: Production Manager Code Migration

- [x] Update `u_scene_manager_node_finder.gd:88`:
  ```gdscript
  # OLD: var stores := tree.get_nodes_in_group("state_store")
  # NEW:
  var store := U_ServiceLocator.try_get_service(StringName("state_store"))
  ```
- [x] Update `ui_input_rebinding_overlay.gd:153`:
  ```gdscript
  # OLD: var stores := get_tree().get_nodes_in_group("state_store")
  # NEW:
  var store := U_ServiceLocator.try_get_service(StringName("state_store"))
  ```
- [x] Update `ui_button_prompt.gd:197`:
  ```gdscript
  # OLD: if node.is_in_group("input_device_manager"):
  # NEW:
  var manager := U_ServiceLocator.try_get_service(StringName("input_device_manager"))
  if manager == node:
  ```
- [x] Run full test suite (2026-02-08):
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
  # Command used with dirs:
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/integration -gexit
  ```

### Phase 6: Remove Group Fallback from Utilities

Only after all tests pass with ServiceLocator.

- [x] Remove group fallback from `u_state_utils.gd:34-48`:
  ```gdscript
  # REMOVE this block:
  # Priority 3: Group lookup (backward compatibility)
  if store == null:
      var tree: SceneTree = node.get_tree()
      ...
  ```
- [x] Run tests to verify nothing depends on group fallback
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/integration -gexit`
- [x] If tests fail, identify which tests still need group fallback and fix them first

### Phase 7: Remove Manager Group Registration

- [x] `m_state_store.gd:80` - Remove `add_to_group("state_store")`
- [x] `m_ecs_manager.gd:46` - Remove `add_to_group("ecs_manager")`
- [x] `m_scene_manager.gd` - Remove `add_to_group("scene_manager")`
- [x] `m_audio_manager.gd:69` - Remove `add_to_group("audio_manager")`
- [x] `m_vfx_manager.gd` - Remove `add_to_group("vfx_manager")`
- [x] `m_spawn_manager.gd` - Remove `add_to_group("spawn_manager")`
- [x] `m_camera_manager.gd` - Remove `add_to_group("camera_manager")`
- [x] `m_save_manager.gd` - Remove `add_to_group("save_manager")`
- [x] `m_input_device_manager.gd:64` - Remove `add_to_group("input_device_manager")`
- [x] `m_input_profile_manager.gd` - Remove `add_to_group("input_profile_manager")`
- [x] `m_cursor_manager.gd:26` - Remove `add_to_group("cursor_manager")`
- [x] `m_pause_manager.gd` - Remove `add_to_group("pause_manager")`
- [x] Remove duplicate check `is_in_group()` calls in managers (prevents double registration)
- [x] Run full test suite

Notes:
- M_ECSManager now self-registers with ServiceLocator and `U_ECSUtils.get_manager()` falls back to ServiceLocator for discovery (replaces group fallback).
- Full unit+integration suite run via `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/integration -gexit` (2026-02-09).

### Phase 8: Entity Group Removal

- [x] Remove `is_in_group(ENTITY_GROUP)` check from `u_ecs_utils.gd:62`
- [x] Remove `ENTITY_GROUP` constant from `u_ecs_utils.gd:5`
- [x] Remove `add_legacy_group` export from `base_ecs_entity.gd:9`
- [x] Remove `ENTITY_GROUP` constant from `base_ecs_entity.gd:7`
- [x] Remove conditional `add_to_group()` from `base_ecs_entity.gd:16-17`
- [x] Run ECS tests:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
  ```
  - ECS unit suite green via command above.

### Phase 9: UI Group Migration

- [ ] Create HUD tracking mechanism in `M_SceneManager`:
  ```gdscript
  var _hud_controller: Node = null

  func register_hud_controller(hud: Node) -> void:
      _hud_controller = hud

  func get_hud_controller() -> Node:
      return _hud_controller
  ```
- [ ] Update `trans_loading_screen.gd:289` to use new mechanism
- [ ] Remove `add_to_group(HUD_GROUP)` from `ui_hud_controller.gd:35`
- [ ] Remove HUD group cleanup from `ui_hud_controller.gd:60`
- [ ] Remove `is_in_group(HUD_GROUP)` check from `ui_hud_controller.gd:66`
- [ ] Track mobile controls in `M_InputDeviceManager`:
  ```gdscript
  var _mobile_controls: Node = null

  func register_mobile_controls(controls: Node) -> void:
      _mobile_controls = controls

  func get_mobile_controls() -> Node:
      return _mobile_controls
  ```
- [ ] Remove `add_to_group("mobile_controls")` from `ui_mobile_controls.gd:53`
- [ ] Run UI tests

### Phase 10: VFX Container Migration

- [ ] Add to `M_VFXManager`:
  ```gdscript
  var _effects_container: Node = null

  func set_effects_container(container: Node) -> void:
      _effects_container = container

  func get_effects_container() -> Node:
      return _effects_container
  ```
- [ ] Update `u_particle_spawner.gd:178,192`:
  ```gdscript
  # OLD: var containers: Array[Node] = tree.get_nodes_in_group("effects_container")
  # NEW:
  var vfx_manager := U_ServiceLocator.try_get_service(StringName("vfx_manager"))
  var container: Node = null
  if vfx_manager and vfx_manager.has_method("get_effects_container"):
      container = vfx_manager.get_effects_container()
  ```
- [ ] Remove `add_to_group("effects_container")` from container node
- [ ] Run VFX tests:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/vfx -gdir=res://tests/integration/vfx -gexit
  ```

### Phase 11: Miscellaneous Cleanup

- [ ] Remove `MANAGER_GROUP` constant from `u_ecs_utils.gd:6`
- [ ] Update `u_ecs_utils.gd:244` to check ServiceLocator instead:
  ```gdscript
  # OLD: if candidate.is_in_group(MANAGER_GROUP):
  # NEW:
  var registered := U_ServiceLocator.get_registered_services()
  for service_name in registered:
      if U_ServiceLocator.get_service(service_name) == candidate:
          return true
  ```
- [ ] Review `i_scene_contract.gd:158` - determine if generic group check needed
- [ ] Remove `get_singleton_from_group()` from `u_ecs_utils.gd:98-112`
- [ ] Remove `get_nodes_from_group()` from `u_ecs_utils.gd:114-123`
- [ ] Search for any remaining group usage:
  ```bash
  grep -r "add_to_group\|is_in_group\|get_nodes_in_group" scripts/
  ```
- [ ] Final full test suite run:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
  ```

---

## Test Commands Reference

```bash
# Full test suite (baseline, use before and after each phase)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit

# Camera tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/camera_system -gdir=res://tests/integration/camera_system -gexit

# UI tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gexit

# ECS tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# VFX tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/vfx -gdir=res://tests/integration/vfx -gexit

# Scene manager integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit

# Search for remaining group usage
grep -r "add_to_group\|is_in_group\|get_nodes_in_group" scripts/
```

---

## Notes

- **Run tests after EVERY phase** before proceeding to the next
- `U_ServiceLocator` is robust and ready (verified 2026-01-19)
- **40+ test files** use `add_to_group()` for setup - each is documented above
- Camera tracking is critical path - affects spawn and scene transitions
- Gameplay scenes each own an `M_ECSManager` instance; managers self-register with ServiceLocator (no groups)
- Some `is_in_group()` checks are for Godot built-in groups - review individually
- **Always add `U_ServiceLocator.clear()` to test cleanup** to prevent cross-test pollution
- Entity detection now relies on `BaseECSEntity` + `E_` naming; the legacy `ecs_entity` group has been removed
- If any phase causes test failures, **stop and fix before proceeding**
