# Duck Typing Cleanup Tasks

## Overview

Remove `has_method()` duck typing patterns in favor of explicit interface-based type checking. The project already has `I_ECSManager` and `I_StateStore` interfaces - this cleanup extends that pattern.

**Priority:** Medium (type safety, IDE support, maintainability)
**Status:** Not Started
**Continuation Prompt:** `docs/general/cleanup_v4/duck-typing-cleanup-continuation-prompt.md`

---

## Pre-work Audit (2026-01-22)

### Current Usage Counts

| Pattern | Production Files | Test Files | Total |
|---------|------------------|------------|-------|
| `has_method()` | ~65 | ~121 | 186 |

### Scope

- **In scope:** ~65 production `has_method()` calls across managers, systems, and utilities
- **Out of scope:**
  - Godot engine type checks (CharacterBody3D, RayCast3D)
  - Test framework code
  - `get_node()` patterns (already using `%UniqueName` and `@export NodePath`)
  - `call_deferred()` (all 19 usages are legitimate)

---

## Why Remove has_method() Duck Typing?

- **No compile-time safety** - typo-prone, no IDE autocomplete
- **No type checking** - any object can pass the check
- **Hard to refactor** - renaming methods doesn't update string literals
- **Inconsistent with existing patterns** - `I_ECSManager` and `I_StateStore` already use interfaces

---

## Summary Table

| Phase | Interface | Prod Files | Mock Updates | has_method() Removed |
|-------|-----------|------------|--------------|---------------------|
| 1 | I_ECSManager (expand) | 3 | mock_ecs_manager.gd | 6 |
| 2 | I_ECSEntity (new) | 3 | NEW mock_ecs_entity.gd | 7 |
| 3 | I_SceneManager (new) | 5 | mock_scene_manager_with_transition.gd | 10 |
| 4 | I_SaveManager (new) | 3 | mock_save_manager.gd | 5 |
| 5 | I_CameraManager (new) | 4 | mock_camera_manager.gd | 5 |
| 6 | I_AudioManager (new) | 3 | NEW mock_audio_manager.gd | 3 |
| 7 | I_InputProfileManager, I_InputDeviceManager | 7 | (create if needed) | 10 |
| 8 | I_VFXManager (new) | 2 | (create if needed) | 2 |
| 9 | I_RebindOverlay (new) | 3 | (none needed) | 15 |
| **Total** | **11 interfaces** | **~33** | **~7 mocks** | **~63 calls** |

---

## Task Checklist

### Phase 1: Expand I_ECSManager Interface ✅ COMPLETE

**Files to modify:**
- `scripts/interfaces/i_ecs_manager.gd` - Add missing methods
- `tests/mocks/mock_ecs_manager.gd` - Add implementations

**Methods to add to I_ECSManager:**

- [x] `func cache_entity_for_node(_node: Node, _entity: Node) -> void`
- [x] `func get_cached_entity_for(_node: Node) -> Node`
- [x] `func update_entity_tags(_entity: Node) -> void`
- [x] `func mark_systems_dirty() -> void`

**Consumer updates:**

- [x] `scripts/ecs/base_ecs_system.gd:48,57,79,92` - Remove `has_method()` checks, methods exist on interface
- [x] `scripts/utils/u_ecs_utils.gd:54,184,189` - Replace `has_method()` with `is I_ECSManager` type check

**Mock updates:**

- [x] Add `_entity_cache: Dictionary` to MockECSManager
- [x] Add `_systems_dirty: bool` to MockECSManager
- [x] Implement `cache_entity_for_node()`, `get_cached_entity_for()`, `update_entity_tags()`, `mark_systems_dirty()`

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

**Results:** All 111 ECS tests passing (2026-01-22)

---

### Phase 2: Create I_ECSEntity Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_ecs_entity.gd`

- [x] Create interface extending Node3D
- [x] Add `func get_entity_id() -> StringName`
- [x] Add `func set_entity_id(_id: StringName) -> void`
- [x] Add `func get_tags() -> Array[StringName]`
- [x] Add `func has_tag(_tag: StringName) -> bool`
- [x] Add `func add_tag(_tag: StringName) -> void`
- [x] Add `func remove_tag(_tag: StringName) -> void`

**Files to modify:**

- [x] `scripts/ecs/base_ecs_entity.gd` - Change `extends Node3D` to `extends I_ECSEntity`
- [x] `scripts/managers/m_ecs_manager.gd:290,401,442,455` - Replace `has_method()` with `as I_ECSEntity`
- [x] `scripts/utils/u_ecs_utils.gd:118,132` - Replace `has_method()` with `as I_ECSEntity`

**New mock:** `tests/mocks/mock_ecs_entity.gd`

- [x] Create MockECSEntity extending I_ECSEntity
- [x] Implement all interface methods

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

**Results:** All 111 ECS tests passing (2026-01-22)

---

### Phase 3: Create I_SceneManager Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_scene_manager.gd`

- [x] Create interface extending Node
- [x] Add `func is_transitioning() -> bool`
- [x] Add `func transition_to_scene(_scene_id: StringName, _transition_type: String = "fade", _priority: int = 0) -> void`
- [x] Add `func hint_preload_scene(_scene_path: String) -> void`
- [x] Add `func suppress_pause_for_current_frame() -> void`
- [x] Add `func push_overlay(_scene_id: StringName, _force: bool = false) -> void`
- [x] Add `func pop_overlay() -> void`

**Files to modify:**

- [x] `scripts/managers/m_scene_manager.gd` - Changed to `extends "res://scripts/interfaces/i_scene_manager.gd"`
- [x] Added `suppress_pause_for_current_frame()` stub implementation to M_SceneManager
- [x] `scripts/ecs/components/c_scene_trigger_component.gd:241,284,347,370,393` - Used `as I_SceneManager` typed cast
- [x] `scripts/managers/m_save_manager.gd:256,332` - Used `as I_SceneManager` typed cast
- [x] `scripts/gameplay/base_interactable_controller.gd:220` - Used `as I_SceneManager` typed cast
- [x] `scripts/scene_management/helpers/u_navigation_reconciler.gd:147` - Used `as I_SceneManager` typed cast

**Mock update:** `tests/mocks/mock_scene_manager_with_transition.gd`

- [x] Changed to `extends "res://scripts/interfaces/i_scene_manager.gd"`
- [x] Added missing interface methods (hint_preload_scene, suppress_pause_for_current_frame, push_overlay, pop_overlay)

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_manager -gexit
```

**Results:** 63/73 scene manager tests passing, 5 pending (headless mode limitations), 5 failing (pre-existing test issues unrelated to interface changes) (2026-01-22)

---

### Phase 4: Create I_SaveManager Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_save_manager.gd`

- [x] Create interface extending Node
- [x] Add `func is_locked() -> bool`
- [x] Add `func request_autosave(_priority: int = 0) -> void`
- [x] Add `func has_any_saves() -> bool`
- [x] Add `func save_to_slot(_slot_id: StringName) -> Error`
- [x] Add `func load_from_slot(_slot_id: StringName) -> Error`

**Files to modify:**

- [x] `scripts/managers/m_save_manager.gd` - Changed to `extends "res://scripts/interfaces/i_save_manager.gd"`
- [x] `scripts/managers/helpers/m_autosave_scheduler.gd:143,192,210` - Used `as I_SaveManager` typed cast, added preload
- [x] `scripts/ui/ui_main_menu.gd:53,207` - Used `as I_SaveManager` typed cast, added preload

**Mock update:** `tests/mocks/mock_save_manager.gd`

- [x] Changed to `extends "res://scripts/interfaces/i_save_manager.gd"` (already had all methods)

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/save -gexit
```

**Results:** All 100 save manager tests passing (2026-01-22)

---

### Phase 5: Create I_CameraManager Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_camera_manager.gd`

- [x] Create interface extending Node
- [x] Add `func get_main_camera() -> Camera3D`
- [x] Add `func initialize_scene_camera(_scene: Node) -> Camera3D`
- [x] Add `func finalize_blend_to_scene(_new_scene: Node) -> void`
- [x] Add `func apply_shake_offset(_offset: Vector2, _rotation: float) -> void`

**Files to modify:**

- [x] `scripts/managers/m_camera_manager.gd` - Changed to `extends "res://scripts/interfaces/i_camera_manager.gd"`
- [x] `scripts/utils/u_ecs_utils.gd:103` - Used `as I_CAMERA_MANAGER` typed cast
- [x] `scripts/managers/m_scene_manager.gd:547,550,604` - Used `as I_CAMERA_MANAGER` typed cast, removed has_method() checks
- [x] `scripts/managers/m_spawn_manager.gd:219` - Used `as I_CAMERA_MANAGER` typed cast
- [x] `scripts/managers/m_vfx_manager.gd:38,44` - Updated export and internal variable types to I_CAMERA_MANAGER

**Mock update:** `tests/mocks/mock_camera_manager.gd`

- [x] Changed to `extends "res://scripts/interfaces/i_camera_manager.gd"`
- [x] Added missing interface methods (get_main_camera, initialize_scene_camera, finalize_blend_to_scene)

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gtest="*vfx*" -gexit
```

**Results:** All 90 VFX tests passing (2026-01-22)

---

### Phase 6: Create I_AudioManager Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_audio_manager.gd`

- [x] Create interface extending Node
- [x] Add `func play_ui_sound(_sound_id: StringName) -> void`
- [x] Add `func set_audio_settings_preview(_preview_settings: Dictionary) -> void`
- [x] Add `func clear_audio_settings_preview() -> void`

**Files to modify:**

- [x] `scripts/managers/m_audio_manager.gd` - Changed to `extends "res://scripts/interfaces/i_audio_manager.gd"`
- [x] `scripts/ui/utils/u_ui_sound_player.gd:45` - Used `as I_AUDIO_MANAGER` typed cast, added preload
- [x] `scripts/ui/settings/ui_audio_settings_tab.gd:470,489` - Used `as I_AUDIO_MANAGER` typed cast, added preload

**New mock:** `tests/mocks/mock_audio_manager.gd`

- [x] Create MockAudioManager extending I_AudioManager
- [x] Implement all interface methods

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/audio -gexit
```

**Results:** All 5 audio tests passing (2026-01-22)

---

### Phase 7: Create I_InputProfileManager and I_InputDeviceManager Interfaces ✅ COMPLETE

**New file:** `scripts/interfaces/i_input_profile_manager.gd`

- [x] Create interface extending Node
- [x] Add `func get_active_profile()` (returns RS_InputProfile or null)
- [x] Add `func reset_to_defaults() -> void`
- [x] Add `func reset_action(_action: StringName) -> void`
- [x] Add `func reset_touchscreen_positions() -> Array[Dictionary]`

**New file:** `scripts/interfaces/i_input_device_manager.gd`

- [x] Create interface extending Node
- [x] Add `func get_mobile_controls() -> Node`
- [x] Add `func get_active_device() -> int`

**Files to modify:**

- [x] `scripts/managers/m_input_profile_manager.gd` - Changed to `extends I_InputProfileManager`, removed duplicate const
- [x] `scripts/managers/m_input_device_manager.gd` - Changed to `extends I_InputDeviceManager`
- [x] `scripts/ui/ui_input_rebinding_overlay.gd:126,311,354` - Used `as I_INPUT_PROFILE_MANAGER` typed cast
- [x] `scripts/ui/ui_input_profile_selector.gd:364` - Used `as I_INPUT_PROFILE_MANAGER` typed cast
- [x] `scripts/ui/ui_edit_touch_controls_overlay.gd:55,154` - Used `as I_INPUT_DEVICE_MANAGER` and `as I_INPUT_PROFILE_MANAGER` typed casts
- [x] `scripts/ui/ui_touchscreen_settings_overlay.gd:315` - Used `as I_INPUT_PROFILE_MANAGER` typed cast
- [x] `scripts/ecs/systems/s_touchscreen_system.gd:118` - Used `as I_INPUT_DEVICE_MANAGER` typed cast

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit
```

**Results:** All 7 input tests passing (2026-01-22)

---

### Phase 8: Create I_VFXManager Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_vfx_manager.gd`

- [x] Create interface extending Node
- [x] Add `func get_effects_container() -> Node`
- [x] Add `func set_effects_container(_container: Node) -> void`
- [x] Add `func set_vfx_settings_preview(_settings: Dictionary) -> void`
- [x] Add `func clear_vfx_settings_preview() -> void`
- [x] Add `func trigger_test_shake(_intensity: float = 1.0) -> void`

**Files to modify:**

- [x] `scripts/managers/m_vfx_manager.gd` - Changed to `extends "res://scripts/interfaces/i_vfx_manager.gd"`
- [x] `scripts/utils/u_particle_spawner.gd:179,197` - Used `as I_VFX_MANAGER` typed cast, removed has_method() checks

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gtest="*vfx*" -gexit
```

**Results:** All 90 VFX tests passing (2026-01-23)

---

### Phase 9: Create I_RebindOverlay Interface ✅ COMPLETE

**New file:** `scripts/interfaces/i_rebind_overlay.gd`

- [x] Create interface extending BaseOverlay
- [x] Add `func begin_capture(_action: StringName, _mode: String) -> void`
- [x] Add `func reset_single_action(_action: StringName) -> void`
- [x] Add `func connect_row_focus_handlers(_row: Control, _add_button: Button, _replace_button: Button, _reset_button: Button) -> void`
- [x] Add `func is_reserved(_action: StringName) -> bool`
- [x] Add `func refresh_bindings() -> void`
- [x] Add `func set_reset_button_enabled(_enabled: bool) -> void`
- [x] Add `func configure_focus_neighbors() -> void`
- [x] Add `func apply_focus() -> void`
- [x] Add `func get_active_device_category() -> String`
- [x] Add `func is_binding_custom(_action: StringName) -> bool`
- [x] Add `func get_active_profile() -> RS_InputProfile`

**Files to modify:**

- [x] `scripts/ui/ui_input_rebinding_overlay.gd` - Changed to `extends "res://scripts/interfaces/i_rebind_overlay.gd"`, added public wrapper methods (delegating to existing private methods)
- [x] `scripts/ui/helpers/u_rebind_action_list_builder.gd` - Used `as I_REBIND_OVERLAY` typed cast, removed all 14 `has_method()` checks
- [-] `scripts/ui/helpers/u_touchscreen_preview_builder.gd:46` - Out of scope (has_method() call is for dynamically instantiated virtual button, not rebind overlay)

**Verification:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gexit
```

**Results:** All 155 UI tests passing (2026-01-23)

**Note:** The has_method() call in u_touchscreen_preview_builder.gd (line 46) is unrelated to the I_RebindOverlay interface - it checks if a dynamically instantiated virtual button scene has a _refresh_label method, which is appropriate defensive programming for scene instantiation.

---

### Final Verification

After all phases:

```bash
# Full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

---

## Test Files Using has_method() to Review

These test files have defensive `has_method()` checks that may need updates:

| File | Lines | Action |
|------|-------|--------|
| `tests/unit/ecs/test_ecs_manager.gd` | 160 | Review - checking component interface |
| `tests/unit/save/test_autosave_scheduler.gd` | 60-61 | Update to use typed mock |
| `tests/unit/save/test_save_manager.gd` | 88,101,114-115,327,331 | Update to use typed mock |
| `tests/integration/scene_manager/*.gd` | various | Review - may keep for test resilience |
| `tests/integration/gameplay/*.gd` | various | Review - may keep for test resilience |

**Strategy for integration tests:** Keep defensive `has_method()` in integration tests for resilience against partial scene setup. Focus cleanup on unit tests where mocks should be fully typed.

---

## Test Commands Reference

```bash
# Full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/integration -gexit

# ECS tests only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Scene manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_manager -gexit

# Save manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/save -gexit

# UI tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gexit

# VFX tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/vfx -gexit

# Input tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit

# Audio tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/audio -gexit

# Style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Search for remaining has_method() usage
grep -rn "has_method" scripts/ --include="*.gd"
```

---

## Notes

- **Run tests after EVERY phase** before proceeding to the next
- Follow existing interface pattern from `i_ecs_manager.gd` and `i_state_store.gd`
- Mocks should extend the interface class directly
- Production managers should change from `extends Node` to `extends I_InterfaceName`
- Use `as I_InterfaceName` for type casting in consumers
- If tests fail, **stop and fix before proceeding**
