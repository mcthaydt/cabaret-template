# Groups Cleanup Tasks

## Overview

Remove `add_to_group()`/`is_in_group()`/`get_nodes_in_group()` usage throughout the codebase in favor of explicit, type-safe alternatives (manager dictionaries, direct references, tag components).

**Priority:** Low (architectural consistency)
**Status:** Not Started

---

## Why Remove Groups?

- **String-based lookups** - typo-prone, no compile-time safety
- **Implicit coupling** - any node can join any group, hard to trace
- **Global queries** - scattered `get_nodes_in_group()` calls instead of centralized tracking
- **Inconsistent with ECS** - components and manager dictionaries should handle categorization

---

## Groups Usage Categories

### 1. Manager/Service Discovery (High Priority)
**Files:** 12 | **Pattern:** Singleton service locator via groups

| File | Group | Usage |
|------|-------|-------|
| `m_state_store.gd` | `state_store` | Self-registers, queried by others |
| `m_ecs_manager.gd` | `ecs_manager` | Self-registers |
| `m_scene_manager.gd` | `scene_manager` | Self-registers |
| `m_audio_manager.gd` | `audio_manager` | Self-registers |
| `m_vfx_manager.gd` | `vfx_manager` | Self-registers |
| `m_spawn_manager.gd` | `spawn_manager` | Self-registers |
| `m_camera_manager.gd` | `camera_manager` | Self-registers |
| `m_save_manager.gd` | `save_manager` | Self-registers |
| `m_input_device_manager.gd` | `input_device_manager` | Self-registers |
| `m_input_profile_manager.gd` | `input_profile_manager` | Self-registers |
| `m_cursor_manager.gd` | `cursor_manager` | Self-registers |
| `m_pause_manager.gd` | `pause_manager` | Self-registers |

**Queried by:**
- `u_scene_manager_node_finder.gd:88` - `state_store`
- `u_state_utils.gd:40` - `state_store`
- `ui_input_rebinding_overlay.gd:153` - `state_store`
- `ui_button_prompt.gd:197` - `input_device_manager`

**Proposed Solution:**
- Use `U_ServiceLocator` exclusively for manager discovery
- Remove all `add_to_group()` calls from managers
- Replace `get_nodes_in_group()` with `U_ServiceLocator.get_service()`

---

### 2. Entity Group (High Priority)
**Files:** 3 | **Pattern:** ECS entity categorization

| File | Lines | Usage |
|------|-------|-------|
| `base_ecs_entity.gd` | 16-17 | Adds to `ENTITY_GROUP` on init |
| `u_ecs_utils.gd` | 62 | Checks `is_in_group(ENTITY_GROUP)` |
| `u_ecs_utils.gd` | 106, 122 | `get_nodes_in_group()` queries |

**Proposed Solution:**
- `M_ECSManager` already tracks entities in dictionaries
- Replace `is_in_group(ENTITY_GROUP)` with manager lookup or type check
- Remove `ENTITY_GROUP` constant and usage

---

### 3. Camera Discovery (Medium Priority)
**Files:** 2 | **Pattern:** Main camera lookup

| File | Lines | Usage |
|------|-------|-------|
| `m_camera_manager.gd` | 156 | `is_in_group("main_camera")` |
| `m_scene_manager.gd` | 532 | `get_nodes_in_group("main_camera")` |
| `m_spawn_manager.gd` | 222 | `get_nodes_in_group("main_camera")` |

**Proposed Solution:**
- `M_CameraManager` should track the main camera directly
- Expose `get_main_camera()` method on camera manager
- Other managers query camera manager instead of groups

---

### 4. UI Groups (Medium Priority)
**Files:** 3 | **Pattern:** UI element discovery

| File | Lines | Group | Usage |
|------|-------|-------|-------|
| `ui_mobile_controls.gd` | 53 | `mobile_controls` | Self-registers |
| `ui_hud_controller.gd` | 35, 60 | `hud_controllers` | Self-registers, cleanup |
| `trans_loading_screen.gd` | 289 | `hud_controllers` | Queries for HUD |
| `m_state_store.gd` | 176 | `state_debug_overlay` | Debug overlay |

**Proposed Solution:**
- Track UI elements in their respective managers
- HUD: Track in scene handler or UI manager
- Mobile controls: Track in input manager
- Debug overlay: Track in state store directly

---

### 5. Effects Container (Low Priority)
**Files:** 1 | **Pattern:** VFX container discovery

| File | Lines | Usage |
|------|-------|-------|
| `u_particle_spawner.gd` | 178, 192 | `effects_container` group |

**Proposed Solution:**
- `M_VFXManager` should track/provide the effects container
- Remove group-based container discovery

---

### 6. Manager Group (Low Priority)
**Files:** 1 | **Pattern:** Generic manager check

| File | Lines | Usage |
|------|-------|-------|
| `u_ecs_utils.gd` | 244 | `is_in_group(MANAGER_GROUP)` |

**Proposed Solution:**
- Check against `U_ServiceLocator` registered services instead
- Or use base class/interface check

---

### 7. Scene Contract (Low Priority)
**Files:** 1 | **Pattern:** Generic group membership check

| File | Lines | Usage |
|------|-------|-------|
| `i_scene_contract.gd` | 158 | `node.is_in_group(group_name)` |

**Proposed Solution:**
- Review usage context - may need case-by-case replacement

---

## Task Checklist

### Phase 1: Service Locator Migration
- [ ] Audit all manager `add_to_group()` calls
- [ ] Ensure all managers register with `U_ServiceLocator`
- [ ] Replace `get_nodes_in_group("state_store")` → `U_ServiceLocator.get_service()`
- [ ] Replace `get_nodes_in_group("input_device_manager")` → `U_ServiceLocator.get_service()`
- [ ] Remove `add_to_group()` from all 12 managers
- [ ] Remove group cleanup in `_exit_tree()` for managers

### Phase 2: Entity Group Removal
- [ ] Add entity lookup method to `M_ECSManager` if not present
- [ ] Replace `is_in_group(ENTITY_GROUP)` in `u_ecs_utils.gd` with manager lookup
- [ ] Replace `get_nodes_in_group()` entity queries with manager queries
- [ ] Remove `ENTITY_GROUP` constant from `base_ecs_entity.gd`
- [ ] Remove `add_to_group(ENTITY_GROUP)` call

### Phase 3: Camera Tracking
- [ ] Add `_main_camera: Camera3D` tracking to `M_CameraManager`
- [ ] Add `get_main_camera() -> Camera3D` method
- [ ] Replace `get_nodes_in_group("main_camera")` in `m_scene_manager.gd`
- [ ] Replace `get_nodes_in_group("main_camera")` in `m_spawn_manager.gd`
- [ ] Replace `is_in_group("main_camera")` check in camera manager
- [ ] Remove `main_camera` group from camera scenes

### Phase 4: UI Element Tracking
- [ ] Track HUD controller in scene handler or create UI manager
- [ ] Replace `get_nodes_in_group("hud_controllers")` queries
- [ ] Remove `add_to_group(HUD_GROUP)` from `ui_hud_controller.gd`
- [ ] Track mobile controls in input manager
- [ ] Remove `add_to_group("mobile_controls")`
- [ ] Track debug overlay directly in state store (already a direct reference?)

### Phase 5: VFX Container
- [ ] Add effects container tracking to `M_VFXManager`
- [ ] Add `get_effects_container()` method
- [ ] Replace `get_nodes_in_group("effects_container")` in particle spawner
- [ ] Remove `add_to_group("effects_container")`

### Phase 6: Miscellaneous
- [ ] Replace `MANAGER_GROUP` check in `u_ecs_utils.gd`
- [ ] Review `i_scene_contract.gd` group usage
- [ ] Search for any remaining group usage
- [ ] Remove unused group constants

---

## Notes

- Run tests after each phase
- `U_ServiceLocator` must be robust before Phase 1
- Some group queries may be in test files - update those too
- Camera tracking is critical path - affects spawn and scene transitions
