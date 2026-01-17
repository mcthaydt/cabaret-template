# Duck Typing & Node Path Cleanup Tasks

## Overview

Remove `has_method()` duck typing, hardcoded `get_node()` / `$` paths, and unnecessary `call_deferred()` workarounds in favor of explicit interfaces, typed references, and proper lifecycle management.

**Priority:** Medium (architectural consistency, type safety)
**Status:** Not Started

---

## Why Clean This Up?

### `has_method()` Duck Typing

- **Stringly-typed** - method names as strings are typo-prone
- **No compile-time checking** - errors only surface at runtime
- **Implicit contracts** - unclear what interfaces are expected
- **Hard to refactor** - renaming methods doesn't update string checks

### `get_node()` / `$` Paths

- **Brittle** - breaks if scene structure changes
- **Implicit dependencies** - hard to trace what a script requires
- **No type safety** - returns `Node` requiring casts

### `call_deferred()` Workarounds

- **Timing hacks** - often masks underlying lifecycle issues
- **Hard to debug** - execution order becomes unclear
- **May indicate** - missing proper initialization patterns

---

## Category 1: `has_method()` Duck Typing (High Priority)

### 1.1 ECS Manager Interface Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `u_ecs_utils.gd` | 54, 87, 142, 156, 208, 213 | Manager/entity method checks |
| `base_ecs_system.gd` | 48, 57, 79, 92 | Manager interface validation |
| `base_ecs_entity.gd` | 19, 77 | Manager method checks |
| `m_ecs_manager.gd` | 182, 290, 401, 442, 455 | Entity method checks |

**Proposed Solution:**

- Create `I_ECSManager` interface with required methods
- Create `I_ECSEntity` interface for entity contracts
- Use `is I_ECSManager` type checks instead of `has_method()`

---

### 1.2 Scene Manager Interface Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `base_interactable_controller.gd` | 220 | `is_transitioning()` check |
| `u_navigation_reconciler.gd` | 117, 125, 147 | Transition method checks |
| `m_save_manager.gd` | 259, 335 | Scene manager method checks |
| `c_scene_trigger_component.gd` | 241, 284, 347, 370, 393 | Manager method checks |
| `m_scene_manager.gd` | 584 | Camera manager method check |

**Proposed Solution:**

- Scene manager already has `class_name M_SceneManager`
- Replace `has_method()` with direct type checks or interface
- Ensure callers get typed reference from service locator

---

### 1.3 Save Manager Interface Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `ui_main_menu.gd` | 53, 207 | `has_any_saves()` check |
| `m_save_manager.gd` | 313 | State store method check |
| `m_autosave_scheduler.gd` | 143, 192, 210 | Save manager method checks |

**Proposed Solution:**

- Type save manager references explicitly
- Remove defensive `has_method()` guards

---

### 1.4 Profile Manager Interface Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `ui_input_rebinding_overlay.gd` | 126, 316, 359 | Profile manager methods |
| `ui_input_profile_selector.gd` | 364 | Profile manager validation |
| `ui_edit_touch_controls_overlay.gd` | 133, 135, 175 | Touchscreen methods |
| `ui_touchscreen_settings_overlay.gd` | 315 | Reset positions check |

**Proposed Solution:**

- Create `I_InputProfileManager` interface
- Type references explicitly in UI scripts

---

### 1.5 Audio Manager Interface Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `u_ui_sound_player.gd` | 45 | `play_ui_sound()` check |
| `ui_audio_settings_tab.gd` | 470, 489 | Audio preview methods |

**Proposed Solution:**

- Type audio manager references
- Part of audio manager refactor

---

### 1.6 UI Overlay/Helper Callbacks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `u_rebind_action_list_builder.gd` | 132-344 (14 occurrences) | Overlay method checks |
| `u_touchscreen_preview_builder.gd` | 46 | Button refresh check |

**Proposed Solution:**

- Define explicit overlay interface or base class
- Helpers should receive typed overlay references

---

### 1.7 Physics/Movement Checks

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `s_movement_system.gd` | 147, 199 | Body method checks |
| `s_landing_indicator_system.gd` | 56, 116 | Space state / world checks |
| `s_floating_system.gd` | 150 | Raycast method check |
| `m_spawn_manager.gd` | 513 | Raycast method check |

**Proposed Solution:**

- These check Godot built-in types - may be acceptable
- Consider explicit type casting instead: `body as CharacterBody3D`

---

### 1.8 Death Sound System

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `s_death_sound_system.gd` | 56 | `get_entity_by_id()` check |

**Proposed Solution:**

- Type manager reference explicitly

---

## Category 2: `get_node()` / `$` Paths (Medium Priority)

### 2.1 UI Child References

| File | Occurrences | Pattern |
| ---- | ----------- | ------- |
| `ui_hud_controller.gd` | 6 | Child node lookups |
| `ui_victory.gd` | 4 | Child node lookups |
| `ui_audio_settings_tab.gd` | 4 | Child node lookups |
| `ui_input_profile_selector.gd` | 4 | Child node lookups |
| `ui_game_over.gd` | 3 | Child node lookups |
| `ui_credits.gd` | 2 | Child node lookups |
| `ui_edit_touch_controls_overlay.gd` | 1 | Child node lookups |
| `ui_input_rebinding_overlay.gd` | 1 | Child node lookups |

**Proposed Solution:**

- Replace with `@export` node references where possible
- Use `@onready var node: Type = $Path` with explicit types
- Consider `%UniqueName` syntax for important nodes

---

### 2.2 Gameplay/Component References

| File | Occurrences | Pattern |
| ---- | ----------- | ------- |
| `base_menu_screen.gd` | 4 | NodePath exports |
| `ui_button_prompt.gd` | 6 | NodePath usage |
| `prototype_camera_blending.gd` | 3 | NodePath usage |
| Various gameplay entities | 2 each | Component lookups |

**Proposed Solution:**

- NodePath exports are acceptable for designer-configured references
- Ensure paths are validated on `_ready()`

---

### 2.3 Service Locator / Core

| File | Occurrences | Pattern |
| ---- | ----------- | ------- |
| `u_service_locator.gd` | 4 | Root node access |
| `main.gd` | 3 | Child access |

**Proposed Solution:**

- Core infrastructure `get_node()` is acceptable
- Ensure type safety with explicit casts

---

## Category 3: `call_deferred()` Workarounds (Low Priority)

### 3.1 Legitimate Deferred Calls

| File | Lines | Reason |
| ---- | ----- | ------ |
| `u_particle_spawner.gd` | 2 | Node reparenting |
| `trans_fade.gd` | 2 | Tween completion |
| `m_scene_manager.gd` | 4 | Scene transition timing |
| `m_pause_manager.gd` | 1 | Pause state change |

**Assessment:** These are likely legitimate - scene/UI lifecycle requires deferred calls.

---

### 3.2 Potential Workarounds to Review

| File | Lines | Pattern |
| ---- | ----- | ------- |
| `base_ecs_component.gd` | 1 | Deferred call |
| `c_checkpoint_component.gd` | 1 | Deferred call |
| `c_landing_indicator_component.gd` | 2 | Deferred calls |
| `ui_virtual_button.gd` | 1 | Deferred call |
| `ui_pause_menu.gd` | 1 | Deferred call |
| `ui_main_menu.gd` | 1 | Deferred call |
| `ui_save_load_menu.gd` | 2 | Deferred calls |
| `m_autosave_scheduler.gd` | 2 | Deferred calls |
| `m_input_profile_manager.gd` | 1 | Deferred call |
| `m_audio_manager.gd` | 1 | Deferred call |
| `s_movement_system.gd` | 1 | Deferred call |

**Proposed Solution:**

- Review each case to determine if it's masking a lifecycle issue
- Document legitimate cases
- Refactor workarounds to proper initialization patterns

---

## Task Checklist

### Phase 1: Create Interfaces

- [ ] Create `I_ECSManager` interface with core methods
- [ ] Create `I_ECSEntity` interface with entity contract
- [ ] Create `I_SceneManager` interface (or use existing class_name)
- [ ] Create `I_InputProfileManager` interface
- [ ] Create `I_SaveManager` interface
- [ ] Create `I_AudioManager` interface

### Phase 2: ECS Duck Typing Removal

- [ ] Update `u_ecs_utils.gd` to use typed checks
- [ ] Update `base_ecs_system.gd` to use typed checks
- [ ] Update `base_ecs_entity.gd` to use typed checks
- [ ] Update `m_ecs_manager.gd` to use typed checks
- [ ] Update `s_death_sound_system.gd` to use typed checks

### Phase 3: Manager Duck Typing Removal

- [ ] Update scene manager consumers to use typed references
- [ ] Update save manager consumers to use typed references
- [ ] Update profile manager consumers to use typed references
- [ ] Update audio manager consumers to use typed references

### Phase 4: UI Helper Cleanup

- [ ] Define overlay interface/base class for rebind helpers
- [ ] Update `u_rebind_action_list_builder.gd` to use typed overlay
- [ ] Update `u_touchscreen_preview_builder.gd` to use typed reference

### Phase 5: Node Path Improvements

- [ ] Audit UI scripts for hardcoded paths
- [ ] Convert critical paths to `@export` or `%UniqueName`
- [ ] Add type annotations to `@onready` declarations
- [ ] Add `_ready()` validation for required nodes

### Phase 6: Deferred Call Review

- [ ] Audit each `call_deferred()` usage
- [ ] Document legitimate deferred calls
- [ ] Refactor workarounds to proper patterns
- [ ] Remove unnecessary deferred calls

---

## Notes

- Interfaces in GDScript use `class_name` + base class pattern
- `is` keyword works for type checking: `if manager is I_ECSManager`
- Some `has_method()` for Godot built-ins may be acceptable (CharacterBody3D, etc.)
- Physics method checks on engine types are harder to eliminate
- Run tests after each phase
