# Project Reorganization Tasks - Complete Checklist

## Overview

Comprehensive reorganization of the cabaret-ball Godot project to improve folder structure clarity, enforce consistent naming conventions, and improve developer navigability.

**Scope**: 614 GDScript files, 76 scene files, 200+ file references
**Status**: In Progress (1/22 tasks complete)
**Continuation Prompt**: `docs/general/cleanup_v4/reorganization-continuation-prompt.md`

---

## Quick Reference Table

| Phase | Tasks | Completed | Risk Level |
|-------|-------|-----------|------------|
| Phase 1: Quick Wins | 4 | 1/4 | Low |
| Phase 2: Naming Fixes | 4 | 0/4 | Medium |
| Phase 3: Folder Restructuring | 8 | 0/8 | High |
| Phase 4: Organization | 4 | 0/4 | Medium |
| Phase 5: Optional Polish | 2 | 0/2 | Low |
| **TOTAL** | **22** | **1/22 (4.5%)** | - |

---

## Phase 1: Quick Wins (Low Risk)

### Task 1: Delete parse_test.gd ✅ COMPLETE

- [x] Delete `tools/parse_test.gd` and `tools/parse_test.gd.uid`
- [x] Verify no references exist

**Status**: COMPLETE (2026-01-23)
**Files affected**: 2
**References updated**: 0
**Risk**: None

---

### Task 2: Move Prototype Scenes 📋 PENDING

- [ ] Create `tests/scenes/prototypes/` directory
- [ ] Move `scenes/prototypes/camera_blend_test.tscn`
- [ ] Move `scenes/prototypes/root_prototype.tscn`
- [ ] Remove `scenes/prototypes/` directory
- [ ] Verify no references (grep for `res://scenes/prototypes`)

**Status**: READY TO EXECUTE
**Files affected**: 2
**References expected**: 0
**Risk**: Low

---

### Task 3: Move Prototype Scripts 📋 PENDING

- [ ] Create `tests/prototypes/` directory
- [ ] Move all 6 files from `scripts/prototypes/`:
  - `prototype_gamepad.gd`
  - `prototype_touch.gd`
  - `prototype_inputmap_safety.gd`
  - `benchmark_input_latency.gd`
  - `prototype_scene_restructuring.gd`
  - `prototype_camera_blending.gd`
- [ ] Move corresponding `.uid` files
- [ ] Remove `scripts/prototypes/` directory
- [ ] Verify no references (grep for `res://scripts/prototypes`)

**Status**: READY TO EXECUTE
**Files affected**: 6 (.gd files) + 6 (.uid files) = 12 total
**References expected**: 0
**Risk**: Low

---

### Task 4: Move ECS Helpers to Utils 📋 PENDING

- [ ] Create `scripts/utils/ecs/` directory
- [ ] Move `scripts/ecs/helpers/u_ecs_query_metrics.gd`
- [ ] Move corresponding `.uid` file
- [ ] Remove `scripts/ecs/helpers/` directory
- [ ] Update reference in `scripts/managers/m_ecs_manager.gd`
- [ ] Run ECS tests to verify

**Status**: READY TO EXECUTE
**Files affected**: 1 (.gd) + 1 (.uid) = 2 total
**References to update**: 1 (m_ecs_manager.gd)
**Risk**: Low

**Test Command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

---

## Phase 2: Naming Convention Fixes (Medium Risk)

### Task 5: Fix Manager Helper Prefixes (m_ → u_) 📋 PENDING

**Rationale**: These are utility classes, not managers. Current `m_` prefix is misleading.

- [ ] Scan for all references to these 8 files
- [ ] Rename files and update class names:
  - `m_autosave_scheduler.gd` → `u_autosave_scheduler.gd`
  - `m_damage_flash.gd` → `u_damage_flash.gd`
  - `m_input_profile_loader.gd` → `u_input_profile_loader.gd`
  - `m_save_file_io.gd` → `u_save_file_io.gd`
  - `m_save_migration_engine.gd` → `u_save_migration_engine.gd`
  - `m_screen_shake.gd` → `u_screen_shake.gd`
  - `m_sfx_spawner.gd` → `u_sfx_spawner.gd`
  - `m_shake_result.gd` → `u_shake_result.gd` (or `rs_` if it's a resource)
- [ ] Update all references (preloads, class names, variable names)
- [ ] Run affected tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: 8 helpers + unknown references
**Risk**: Medium

**Reference Scan Command**:
```bash
grep -rn "m_autosave_scheduler\|m_damage_flash\|m_input_profile_loader\|m_save_file_io\|m_save_migration_engine\|m_screen_shake\|m_sfx_spawner\|m_shake_result" scripts/ --include="*.gd"
```

---

### Task 6: Rename Interactable Controllers (e_ → inter_) 📋 PENDING

**Rationale**: Interactable controllers need distinct prefix from regular entities. New `inter_` prefix clarifies purpose.

- [ ] Scan for all references to these 6 files
- [ ] Rename files and update class names:
  - `e_door_trigger_controller.gd` → `inter_door_trigger.gd`
  - `e_checkpoint_zone.gd` → `inter_checkpoint_zone.gd`
  - `e_hazard_zone.gd` → `inter_hazard_zone.gd`
  - `e_victory_zone.gd` → `inter_victory_zone.gd`
  - `e_signpost.gd` → `inter_signpost.gd`
  - `e_endgame_goal_zone.gd` → `inter_endgame_goal_zone.gd` (verify this is an interactable)
- [ ] Update all scene references
- [ ] Update class names (E_* → Inter_*)
- [ ] Update STYLE_GUIDE.md to document `inter_` prefix
- [ ] Run affected tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: 6 files + scene references
**Risk**: Medium

**Reference Scan Command**:
```bash
grep -rn "e_door_trigger_controller\|e_checkpoint_zone\|e_hazard_zone\|e_victory_zone\|e_signpost\|e_endgame_goal_zone" . --include="*.gd" --include="*.tscn"
```

---

### Task 7: Convert Surface Marker to Component 📋 PENDING

**Rationale**: `marker_surface_type.gd` is functionally a component but uses incorrect prefix.

- [ ] Create `scripts/ecs/components/c_surface_type_component.gd`
  - Extend `BaseECSComponent`
  - Add `COMPONENT_TYPE := StringName("C_SurfaceTypeComponent")`
  - Port `surface_type` export and `get_surface_type()` method
- [ ] Update `scenes/gameplay/gameplay_exterior.tscn` to use new component
- [ ] Update `tests/unit/ecs/systems/test_footstep_sound_system.gd`
- [ ] Update `tests/unit/ecs/components/test_surface_detector.gd` (if exists)
- [ ] Delete `scripts/ecs/markers/marker_surface_type.gd`
- [ ] Run ECS tests

**Status**: READY TO PLAN
**Files affected**: 4 (1 new, 1 delete, 2 updates)
**Risk**: Low

---

### Task 8: Rename main.gd to root.gd 📋 PENDING

**Rationale**: Script is attached to `root.tscn`, should be named `root.gd` for clarity.

- [ ] Scan for all references to `main.gd` (33 known)
- [ ] Move `scripts/scene_structure/main.gd` → `scripts/root.gd`
- [ ] Update CRITICAL reference in `scenes/root.tscn` (line 11)
- [ ] Update all gameplay scene references
- [ ] Update all documentation references (AGENTS.md, PRDs, etc.)
- [ ] Run full test suite
- [ ] Verify root scene loads in Godot editor

**Status**: NEEDS CAREFUL EXECUTION
**Files affected**: 1 move + 33 reference updates
**Risk**: HIGH - breaks root scene if done incorrectly

**Test Command**:
```bash
# After update, verify root scene loads
# Also run full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

---

## Phase 3: Folder Restructuring (High Risk)

### Task 9: Move Templates to scenes/templates/ 📋 PENDING

- [ ] Create `scenes/templates/` directory
- [ ] Move all 4 template files:
  - `templates/tmpl_base_scene.tscn`
  - `templates/tmpl_camera.tscn`
  - `templates/tmpl_character.tscn`
  - `templates/tmpl_character_ragdoll.tscn`
- [ ] Update all references (21 files):
  - `project.godot` (main scene reference)
  - 6 scene files
  - 5 test files
  - 9 documentation files
- [ ] Remove `templates/` directory
- [ ] Run tests and verify scenes load

**Status**: READY TO EXECUTE
**Files affected**: 4 moves + 21 reference updates
**Risk**: Medium

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://templates/|res://scenes/templates/|g' {} +
```

---

### Task 10: Move Audio Assets to assets/audio/ 📋 PENDING

- [ ] Create `assets/audio/` directory structure
- [ ] Move `resources/audio/` → `assets/audio/` (100+ files including subdirs)
- [ ] Update all references (83 files):
  - `scripts/managers/m_audio_manager.gd` (lines 20-46: preloads)
  - `scripts/ecs/systems/s_ambient_sound_system.gd`
  - 6 `.tres` files in `resources/settings/`
  - 3 test files
  - 75+ `.import` files (will auto-regenerate)
- [ ] Run audio tests
- [ ] Verify audio plays in game

**Status**: READY TO EXECUTE
**Files affected**: 100+ moves + 83 reference updates
**Risk**: CRITICAL

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://resources/audio/|res://assets/audio/|g' {} +
```

**Test Command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/audio -gexit
```

---

### Task 11: Move Button Prompts to assets/button_prompts/ 📋 PENDING

- [ ] Create `assets/button_prompts/` directory structure
- [ ] Move `resources/button_prompts/` → `assets/button_prompts/` (80+ files including subdirs)
- [ ] Update all references (53 files):
  - `scripts/ui/u_button_prompt_registry.gd` (lines 18-49: hardcoded paths)
  - `scripts/ui/ui_virtual_joystick.gd`
  - `scripts/ui/ui_virtual_button.gd`
  - `scripts/utils/u_input_event_display.gd`
  - 3 scene files
  - 2 test files
  - 46+ `.import` files (will auto-regenerate)
- [ ] Run input tests
- [ ] Verify button prompts display correctly

**Status**: READY TO EXECUTE
**Files affected**: 80+ moves + 53 reference updates
**Risk**: CRITICAL

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://resources/button_prompts/|res://assets/button_prompts/|g' {} +
```

**Test Command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit
```

---

### Task 12: Move Editor Icons to assets/editor_icons/ 📋 PENDING

- [ ] Scan for all references to `resources/editor_icons/`
- [ ] Create `assets/editor_icons/` directory
- [ ] Move `resources/editor_icons/` → `assets/editor_icons/` (34 files)
- [ ] Update all references
- [ ] Verify icons display in Godot editor

**Status**: NEEDS REFERENCE SCAN
**Files affected**: 34 moves + unknown references
**Risk**: Medium

---

### Task 13: Consolidate ECS Resources 📋 PENDING

- [ ] Create `scripts/resources/ecs/` directory
- [ ] Move `scripts/ecs/resources/` → `scripts/resources/ecs/`
- [ ] Update all references (67 files: scripts, .tres, tests)
- [ ] Run ECS tests

**Status**: READY TO EXECUTE
**Files affected**: Many moves + 67 reference updates
**Risk**: HIGH

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ecs/resources/|res://scripts/resources/ecs/|g' {} +
```

---

### Task 14: Consolidate UI Resources 📋 PENDING

- [ ] Scan for all references to `scripts/ui/resources/`
- [ ] Create `scripts/resources/ui/` directory
- [ ] Move `scripts/ui/resources/` → `scripts/resources/ui/`
- [ ] Update all references
- [ ] Run UI tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: Unknown
**Risk**: Medium

---

### Task 15: Consolidate State Resources 📋 PENDING

- [ ] Scan for all references to `scripts/state/resources/`
- [ ] Create `scripts/resources/state/` directory
- [ ] Move `scripts/state/resources/` → `scripts/resources/state/`
- [ ] Update all references
- [ ] Run state tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: Unknown
**Risk**: Medium

---

### Task 16: Move Scattered Interfaces 📋 PENDING

**Rationale**: Three interface files are in `scripts/scene_management/` instead of `scripts/interfaces/`

- [ ] Move these 3 files to `scripts/interfaces/`:
  - `scripts/scene_management/i_scene_contract.gd`
  - `scripts/scene_management/i_scene_type_handler.gd`
  - `scripts/scene_management/i_transition_effect.gd`
- [ ] Update all references
- [ ] Run scene manager tests

**Status**: READY TO EXECUTE
**Files affected**: 3 moves + unknown references
**Risk**: Low

---

## Phase 4: Organization Improvements (Medium Risk)

### Task 17: Organize UI Scripts by Screen Type 📋 PENDING

**Proposed Organization**:
```
scripts/ui/
  ├── menus/       (main_menu, pause_menu, settings, credits)
  ├── overlays/    (save_load, rebinding, settings overlays)
  ├── hud/         (hud_controller, button_prompt, virtual controls)
  ├── settings/    (existing 3 files)
  ├── utils/       (existing 2 files + registry, sound_player)
  └── resources/   (existing 1 file)
```

- [ ] Create subdirectories: `menus/`, `overlays/`, `hud/`
- [ ] Scan all UI script references
- [ ] Move 18+ UI scripts to appropriate subdirectories
- [ ] Update all references
- [ ] Run UI tests

**Status**: CAN BE DEFERRED
**Files affected**: 18+ moves + many references
**Risk**: Medium

---

### Task 18: Split Settings by Domain 📋 PENDING

**Proposed Organization**:
```
resources/settings/
  ├── gameplay/  (movement, jump, gravity, etc.)
  ├── audio/     (sound settings)
  └── input/     (input profile settings)
```

- [ ] Create subdirectories by domain
- [ ] Move 17 settings files to appropriate subdirectories
- [ ] Update all references
- [ ] Run tests

**Status**: CAN BE DEFERRED
**Files affected**: 17 moves + unknown references
**Risk**: Low

---

### Task 19: Move Loose Trigger Settings 📋 PENDING

- [ ] Create `resources/triggers/` directory
- [ ] Move `resources/rs_scene_trigger_settings.tres` → `resources/triggers/`
- [ ] Update references
- [ ] Run tests

**Status**: READY TO EXECUTE
**Files affected**: 1 move + unknown references
**Risk**: Low

---

### Task 20: Rename Docs Folders (Spaces → Snake_Case) 📋 PENDING

**Rationale**: Documentation folders use spaces instead of snake_case convention

Rename these 10 folders in `docs/`:
- [ ] `"audio manager"` → `audio_manager`
- [ ] `"display manager"` → `display_manager`
- [ ] `"input manager"` → `input_manager`
- [ ] `"save manager"` → `save_manager`
- [ ] `"scene manager"` → `scene_manager`
- [ ] `"state store"` → `state_store`
- [ ] `"ui manager"` → `ui_manager`
- [ ] `"vfx manager"` → `vfx_manager`
- [ ] Update any documentation that references these folders

**Status**: READY TO EXECUTE
**Files affected**: 10 folder renames
**Risk**: LOW - documentation only

---

## Phase 5: Optional Polish

### Task 21: Add data_ Prefix to Resource Folders 📋 PENDING

**Rationale**: Clarify that `resources/` contains data-only .tres files, not binary assets

- [ ] Evaluate if this adds value
- [ ] If proceeding, rename resource subfolders with `data_` prefix
- [ ] Update all references

**Status**: CAN BE DEFERRED
**Risk**: Low

---

### Task 22: Clean Up Unused Test Files 📋 PENDING

- [ ] Audit `tests/` directory for orphaned files
- [ ] Remove unused test files
- [ ] Consolidate test helpers if needed

**Status**: CAN BE DEFERRED
**Risk**: Low

---

## Execution Strategy

### Batch 1: Zero-Risk Quick Wins (Execute First)
- Task 2: Move prototype scenes
- Task 3: Move prototype scripts
- Task 4: Move ECS helpers

### Batch 2: Naming Fixes (Needs Scanning)
- Task 5: Fix manager helper prefixes
- Task 6: Rename interactables
- Task 7: Convert surface marker
- Task 8: Rename main.gd (CRITICAL)

### Batch 3: Folder Restructuring (High Impact)
- Task 9: Move templates
- Task 10-11: Move audio/button prompt assets (CRITICAL)
- Task 12-16: Consolidate resources and interfaces

### Batch 4: Organization (Optional)
- Tasks 17-22: Polish and cleanup

---

## Test Commands Reference

```bash
# Full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Style enforcement only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Specific subsystem (replace 'ecs' with subsystem name)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

---

## Documentation Updates Required

After reorganization completion:

1. **STYLE_GUIDE.md**:
   - Add `inter_` prefix documentation for interactable controllers
   - Update examples to reflect new folder structure

2. **AGENTS.md**:
   - Update Repo Map with new file paths
   - Update helper extraction patterns section

3. **Continuation prompts**:
   - Update all references to moved files
   - Mark reorganization as complete

---

## Success Criteria

- [ ] All 22 tasks completed (or consciously deferred for Phase 5)
- [ ] All unit tests passing (1468/1473 or better)
- [ ] Style enforcement tests passing
- [ ] Scenes load in Godot editor
- [ ] No broken preload/load paths
- [ ] STYLE_GUIDE.md updated
- [ ] AGENTS.md updated
- [ ] Documentation updated

---

**Last Updated**: 2026-01-23
**Status**: In Progress (1/22 complete - 4.5%)
**Next Batch**: Batch 1 (Tasks 2-4) - Zero-risk quick wins
