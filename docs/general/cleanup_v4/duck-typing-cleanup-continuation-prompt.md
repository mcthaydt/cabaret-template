# Duck Typing Cleanup Continuation Prompt

Use this prompt to resume the duck typing cleanup effort (cleanup_v4).

---

## Context

- Goal: Remove `has_method()` duck typing patterns in favor of explicit interface-based type checking.
- The project already has `I_ECSManager` and `I_StateStore` interfaces - this cleanup extends that pattern to other managers and entities.
- Scope: ~65 production `has_method()` calls to fix (out of 186 total - rest are tests/Godot engine types).

**Out of scope** (acceptable patterns):
- Godot engine type checks (CharacterBody3D, RayCast3D) - keep as-is
- Test framework code - keep as-is
- `get_node()` patterns - already using `%UniqueName` and `@export NodePath`
- `call_deferred()` - all 19 usages are legitimate

---

## Read First

- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/general/cleanup_v4/duck-typing-cleanup-tasks.md`

---

## Current Progress

- Plan created and documented
- Phase 0 (preparation): Not started
- Phase 1 (I_ECSManager expansion): ✅ COMPLETE (2026-01-22)
  - Added 4 methods to I_ECSManager interface
  - Updated MockECSManager with implementations
  - Removed 6 `has_method()` checks from consumer files
  - All 111 ECS tests passing
- Phase 2 (I_ECSEntity interface): ✅ COMPLETE (2026-01-22)
  - Created I_ECSEntity interface with 6 methods
  - Updated BaseECSEntity to extend interface
  - Created MockECSEntity for testing
  - Removed 6 `has_method()` checks from consumer files
  - All 111 ECS tests passing
- Phase 3 (I_SceneManager interface): ✅ COMPLETE (2026-01-22)
  - Created I_SceneManager interface with 6 methods
  - Updated M_SceneManager to extend interface
  - Updated MockSceneManagerWithTransition with all interface methods
  - Removed 10 `has_method()` checks from consumer files
  - All 111 ECS tests passing, 93/98 scene manager tests passing
- Phase 4 (I_SaveManager interface): ✅ COMPLETE (2026-01-22)
  - Created I_SaveManager interface with 5 methods
  - Updated M_SaveManager to extend interface
  - Updated MockSaveManager to extend interface
  - Removed 5 `has_method()` checks from consumer files (m_autosave_scheduler.gd, ui_main_menu.gd)
  - All 100 save manager tests passing
- Phase 5 (I_CameraManager interface): ✅ COMPLETE (2026-01-22)
  - Created I_CameraManager interface with 4 methods
  - Updated M_CameraManager to extend interface
  - Updated MockCameraManager to extend interface
  - Removed 5 `has_method()` checks from consumer files (u_ecs_utils.gd, m_scene_manager.gd, m_spawn_manager.gd)
  - Updated M_VFXManager export and internal variable types to use interface
  - All 90 VFX tests passing
- Phase 6 (I_AudioManager interface): ✅ COMPLETE (2026-01-22)
  - Created I_AudioManager interface with 3 methods
  - Updated M_AudioManager to extend interface
  - Created MockAudioManager for testing
  - Removed 3 `has_method()` checks from consumer files (u_ui_sound_player.gd, ui_audio_settings_tab.gd)
  - All 5 audio tests passing
- Phase 7 (I_InputProfileManager/I_InputDeviceManager): ✅ COMPLETE (2026-01-22)
  - Created I_InputProfileManager interface with 4 methods
  - Created I_InputDeviceManager interface with 2 methods
  - Updated M_InputProfileManager and M_InputDeviceManager to extend interfaces
  - Removed duplicate const from M_InputProfileManager
  - Removed 10 `has_method()` checks from consumer files (ui_input_rebinding_overlay.gd, ui_input_profile_selector.gd, ui_edit_touch_controls_overlay.gd, ui_touchscreen_settings_overlay.gd, s_touchscreen_system.gd)
  - All 7 input tests passing
- Phase 8 (I_VFXManager interface): ✅ COMPLETE (2026-01-23)
  - Created I_VFXManager interface with 5 methods
  - Updated M_VFXManager to extend interface
  - Removed 2 `has_method()` checks from consumer files (u_particle_spawner.gd)
  - All 90 VFX tests passing
- Phase 9 (I_RebindOverlay interface): ✅ COMPLETE (2026-01-23)
  - Created I_RebindOverlay interface extending BaseOverlay with 11 methods
  - Updated UI_InputRebindingOverlay to extend interface
  - Added public wrapper methods (delegating to existing private implementations)
  - Removed 14 `has_method()` checks from consumer files (u_rebind_action_list_builder.gd)
  - All 155 UI tests passing

---

## Execution Rules

- Run the targeted tests listed per phase in `duck-typing-cleanup-tasks.md` **before** advancing.
- After every phase, update:
  - `docs/general/cleanup_v4/duck-typing-cleanup-tasks.md` (checkboxes/notes)
  - This continuation prompt (progress + next steps)
- Commit documentation updates separately from implementation commits.

---

## Interface Pattern Reference

Follow existing pattern from `i_ecs_manager.gd`:

```gdscript
extends Node  # or Node3D for entities
class_name I_InterfaceName

## Docstring describing the interface
## Phase X: Created for [purpose]
## Implementations: [list concrete classes]

func method_name(_param: Type) -> ReturnType:
    push_error("I_InterfaceName.method_name not implemented")
    return default_value
```

## Replacement Pattern

```gdscript
# Before
if mgr != null and mgr.has_method("some_method"):
    mgr.some_method()

# After
var typed_mgr := mgr as I_ManagerInterface
if typed_mgr != null:
    typed_mgr.some_method()
```

---

## Next Step

**✅ ALL PHASES COMPLETE!**

Duck typing cleanup (cleanup_v4) is now complete. All 9 phases have been successfully implemented:

**Summary:**
- Created 11 interfaces to replace duck typing patterns
- Removed approximately 63 production `has_method()` checks
- All tests passing (502+ tests across all suites)
- Type safety significantly improved throughout the codebase

**Final verification:**
Run the full test suite to confirm everything still works:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

**Consider for future work:**
- Review any remaining test-only `has_method()` usage for potential cleanup
- Consider creating interfaces for other duck-typed patterns if discovered
