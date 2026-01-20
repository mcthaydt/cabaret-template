# Metadata Cleanup Tasks

## Overview

Remove `get_meta()`/`set_meta()` usage throughout the codebase in favor of explicit, type-safe alternatives (components, properties, dictionaries).

**Priority:** Low (architectural consistency, not blocking)
**Status:** In Progress (surface detector review pending)

---

## Metadata Usage Categories

### 1. Spawn Physics Freeze (High Priority)
**Files:** 6 | **Pattern:** Transient state tracking across systems

| File | Lines | Usage |
|------|-------|-------|
| `m_spawn_manager.gd` | 150-151 | Sets `META_SPAWN_PHYSICS_FROZEN` |
| `u_scene_loader.gd` | 181-192 | Checks/removes frozen meta |
| `s_floating_system.gd` | 50 | Checks frozen |
| `s_movement_system.gd` | 78, 261-284 | Checks frozen + unfreeze timing |
| `s_jump_system.gd` | 75, 212-226 | Checks frozen + landing suppression |

**Proposed Solution:** Create `C_SpawnStateComponent` with:
- `is_physics_frozen: bool`
- `unfreeze_at_frame: int`
- `suppress_landing_until_frame: int`

---

### 2. Entity ID/Type Fallbacks (High Priority)
**Files:** 5 | **Pattern:** Fallback when entity root not found

| File | Lines | Usage |
|------|-------|-------|
| `s_movement_system.gd` | 352-359 | `entity_id`, `entity_type` |
| `s_damage_system.gd` | 119-123 | `entity_id` |
| `s_gamepad_vibration_system.gd` | 193-194 | `entity_id` |
| `s_jump_system.gd` | 207-208 | `entity_id` |
| `s_rotate_to_input_system.gd` | 125-126 | `entity_id` |

**Proposed Solution:**
- Ensure all entities extend `BaseECSEntity` (which has `entity_id` property)
- Remove metadata fallbacks entirely - if entity root isn't found, that's a bug

---

### 3. Entity Root Tracking (Medium Priority)
**Files:** 3 | **Pattern:** ECS infrastructure caching

| File | Lines | Usage |
|------|-------|-------|
| `u_ecs_utils.gd` | 54-55, 215-219 | Cache entity root lookups |
| `m_ecs_manager.gd` | 454, 458-471, 511-512 | Track component-entity relationships |
| `base_ecs_entity.gd` | 17 | Self-reference |

**Proposed Solution:**
- Move to `Dictionary` lookup in `M_ECSManager` (node instance_id → entity)
- Remove per-node metadata caching

---

### 4. SFX Pool Tracking (Medium Priority)
**Files:** 1 | **Pattern:** Object pool in-use flags

| File | Lines | Usage |
|------|-------|-------|
| `m_sfx_spawner.gd` | 40, 61, 116, 126 | `META_IN_USE` for pool tracking |

**Proposed Solution:**
- Use parallel `Dictionary[AudioStreamPlayer3D, bool]` for in-use tracking
- Or wrap pool items in a struct/class

---

### 5. Overlay Stack Manager (Medium Priority)
**Files:** 1 | **Pattern:** Scene ID tracking on overlay instances

| File | Lines | Usage |
|------|-------|-------|
| `u_overlay_stack_manager.gd` | 113, 165-166, 234-235 | `OVERLAY_META_SCENE_ID` |

**Proposed Solution:**
- Use `Dictionary[Node, StringName]` in the manager to track overlay → scene_id mapping

---

### 6. Camera Shake Parent (Low Priority)
**Files:** 1 | **Pattern:** Marker for shake node hierarchy

| File | Lines | Usage |
|------|-------|-------|
| `m_camera_manager.gd` | 259, 267 | `META_SHAKE_PARENT` |

**Proposed Solution:**
- Store reference directly in manager instead of marking node

---

### 7. Scene Manager Infrastructure (Low Priority)
**Files:** 3 | **Pattern:** Scene lifecycle markers

| File | Lines | Usage |
|------|-------|-------|
| `m_scene_manager.gd` | 515, 724-734 | `_scene_manager_spawned`, `PARTICLE_META_ORIG_SPEED` |
| `m_gameplay_initializer.gd` | 31 | Check spawned |
| `i_scene_type_handler.gd` | 19 | Documentation |

**Proposed Solution:**
- Track spawned scenes in manager's `Dictionary`
- Store particle speeds in separate `Dictionary` during transitions

---

### 8. Fade Transition (Low Priority)
**Files:** 1 | **Pattern:** UI state preservation

| File | Lines | Usage |
|------|-------|-------|
| `trans_fade.gd` | 66-67, 121-123 | `_META_ORIGINAL_MOUSE_FILTER` |

**Proposed Solution:**
- Store in local `Dictionary` during transition lifecycle

---

### 9. Surface Detection (Low Priority)
**Files:** 1 | **Pattern:** Material/surface type on colliders

| File | Lines | Usage |
|------|-------|-------|
| `c_surface_detector_component.gd` | 76-77 | `surface_type` on colliders |

**Proposed Solution:**
- This is actually reasonable for static level geometry
- Consider keeping OR use physics layers + lookup table

---

### 10. Health System Ragdoll (Low Priority)
**Files:** 1 | **Pattern:** Ragdoll identification

| File | Lines | Usage |
|------|-------|-------|
| `s_health_system.gd` | 254 | `player_ragdoll` marker |

**Proposed Solution:**
- Add ragdoll to a group instead (`ragdoll.add_to_group("player_ragdoll")`)

---

## Task Checklist

### Phase 1: Spawn State (High Impact)
- [x] Create `C_SpawnStateComponent` with frozen/unfreeze fields
- [x] Update `M_SpawnManager` to add component instead of metadata
- [x] Update `S_MovementSystem` to query component
- [x] Update `S_JumpSystem` to query component
- [x] Update `S_FloatingSystem` to query component
- [x] Update `U_SceneLoader` to check component
- [x] Remove all `META_SPAWN_*` constants
- [x] Test spawn/respawn flows (full unit+integration run via GUT headless command on 2026-01-19)

### Phase 2: Entity ID Fallbacks
- [x] Audit entities not extending `BaseECSEntity`
- [x] Remove `entity_id`/`entity_type` metadata fallbacks from systems
- [x] Update `_get_entity_id()` helpers to fail explicitly if entity root missing

### Phase 3: ECS Infrastructure
- [x] Add `Dictionary` in `M_ECSManager` for node→entity lookup
- [x] Update `U_ECSUtils.find_entity_root()` to use manager lookup
- [x] Remove `META_ENTITY_ROOT` and `META_ENTITY_TRACKED`

### Phase 4: Manager Cleanup
- [x] Refactor `M_SFXSpawner` pool tracking to Dictionary
- [x] Refactor `U_OverlayStackManager` scene_id tracking to Dictionary
- [x] Refactor `M_CameraManager` shake parent to direct reference
- [x] Refactor `M_SceneManager` spawned tracking to Dictionary
- [x] Refactor `Trans_Fade` mouse filter storage to local Dictionary

### Phase 5: Miscellaneous
- [x] Replace `player_ragdoll` metadata with group membership
- [x] Evaluate `surface_type` metadata (may keep for level geometry)
  - Decision: keep the provider method pattern (no metadata tags required) for static geometry compatibility.

---

## Notes

- Run tests after each phase
- Some metadata (surface_type) may be acceptable for static data
- Surface detection remains provider-method-based; no metadata tags should be added for `surface_type`
- Prioritize spawn state cleanup if it causes issues during audio refactor
