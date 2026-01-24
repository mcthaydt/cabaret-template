# Project Reorganization Tasks - Complete Reference

## Overview

Comprehensive reorganization of the cabaret-ball Godot project to improve folder structure clarity, enforce consistent naming conventions, and improve developer navigability.

**Scope**: 614 GDScript files, 76 scene files, 200+ file references
**Status**: In Progress (6/23 tasks complete)
**Continuation Prompt**: `docs/general/cleanup_v4/reorganization-continuation-prompt.md`

---

## Quick Reference Table

| Phase | Tasks | Completed | Risk Level |
|-------|-------|-----------|------------|
| Phase 1: Quick Wins | 4 | 4/4 | Low |
| Phase 2: Naming Fixes | 4 | 2/4 | Medium |
| Phase 3: Folder Restructuring | 8 | 0/8 | High |
| Phase 4: Organization | 4 | 0/4 | Medium |
| Phase 5: Optional Polish | 3 | 0/3 | Medium |
| **TOTAL** | **23** | **6/23 (26.1%)** | - |

---

## Risk Assessment Matrix

| Task | Risk | Impact | Files | References | Test Coverage |
|------|------|--------|-------|------------|---------------|
| 1. Delete parse_test | None | Low | 2 | 0 | N/A |
| 2. Move prototype scenes | Low | Low | 3 | Tests only | Yes |
| 3. Move prototype scripts | Low | Low | 12 | 0 | No |
| 4. Move ECS helpers | Low | Low | 2 | 1 | Yes |
| 5. Fix manager helper prefixes | Medium | Medium | 8 | Unknown | Yes |
| 6. Rename interactables | Medium | Medium | 6 | Unknown | Yes |
| 7. Convert surface marker | Low | Low | 4 | 4 | Yes |
| 8. Rename main.gd | **HIGH** | **Critical** | 1 | 33 | Partial |
| 9. Move templates | Medium | High | 4 | 21 | Partial |
| 10. Move audio assets | **CRITICAL** | **Critical** | 100+ | 83 | Yes |
| 11. Move button prompts | **CRITICAL** | **Critical** | 80+ | 53 | Yes |
| 12. Move editor icons | Medium | Medium | 34 | Unknown | Partial |
| 13. Consolidate ECS resources | High | High | Many | 67 | Yes |
| 14. Consolidate UI resources | Medium | Medium | Unknown | Unknown | Partial |
| 15. Consolidate state resources | High | High | Unknown | Unknown | Partial |
| 16. Move interfaces | Low | Low | 4 | Unknown | Yes |
| 17-23. Organization tasks | Medium | Medium | Various | Various | Partial |

---

## Phase 1: Quick Wins (Low Risk)

### Task 1: Delete parse_test.gd COMPLETE

- [x] Delete `tools/parse_test.gd` and `tools/parse_test.gd.uid`
- [x] Verify no references exist

**Status**: COMPLETE (2026-01-23)
**Files affected**: 2
**References updated**: 0
**Risk**: None

---

### Task 2: Move Prototype Scenes COMPLETE

- [x] Create `tests/scenes/prototypes/` directory
- [x] Move `scenes/prototypes/camera_blend_test.tscn`
- [x] Move `scenes/prototypes/root_prototype.tscn`
- [x] Remove `scenes/prototypes/` directory
- [x] Verify no references (grep for `res://scenes/prototypes`)
- [x] Move test-only scene `scenes/tmp_invalid_gameplay.tscn` -> `tests/scenes/tmp_invalid_gameplay.tscn`
- [x] Update test references that load `res://scenes/tmp_invalid_gameplay.tscn` to the new path

**Status**: COMPLETE (2026-01-23)
**Files affected**: 3
**References expected**: Yes (tests only)
**Risk**: Low

**Execution Commands**:
```bash
mkdir -p tests/scenes/prototypes
git mv scenes/prototypes/* tests/scenes/prototypes/
rmdir scenes/prototypes
git mv scenes/tmp_invalid_gameplay.tscn tests/scenes/
grep -r "res://scenes/prototypes" . --include="*.gd" --include="*.tscn"
grep -r "res://scenes/tmp_invalid_gameplay.tscn" tests/ --include="*.gd"
# Update any found references, then commit
git add . && git commit -m "refactor: move prototype scenes to tests folder"
```

---

### Task 3: Move Prototype Scripts COMPLETE

- [x] Create `tests/prototypes/` directory
- [x] Move all 6 files from `scripts/prototypes/`:
  - `prototype_gamepad.gd`
  - `prototype_touch.gd`
  - `prototype_inputmap_safety.gd`
  - `benchmark_input_latency.gd`
  - `prototype_scene_restructuring.gd`
  - `prototype_camera_blending.gd`
- [x] Move corresponding `.uid` files
- [x] Remove `scripts/prototypes/` directory
- [x] Verify no references (grep for `res://scripts/prototypes`)

**Status**: COMPLETE (2026-01-23)
**Files affected**: 6 (.gd files) + 6 (.uid files) = 12 total
**References expected**: Yes (tests + prototype scenes)
**Risk**: Low
**Notes**: Removed `class_name` from prototype scripts and loosened adapter typing to avoid global class conflicts in headless tests.

**Execution Commands**:
```bash
mkdir -p tests/prototypes
git mv scripts/prototypes/*.gd tests/prototypes/
mv scripts/prototypes/*.gd.uid tests/prototypes/
rmdir scripts/prototypes
grep -r "res://scripts/prototypes" . --include="*.gd" --include="*.tscn"
git add . && git commit -m "refactor: move prototype scripts to tests folder"
```

---

### Task 4: Move ECS Helpers to Utils COMPLETE

- [x] Create `scripts/utils/ecs/` directory
- [x] Move `scripts/ecs/helpers/u_ecs_query_metrics.gd`
- [x] Move corresponding `.uid` file
- [x] Remove `scripts/ecs/helpers/` directory
- [x] Update reference in `scripts/managers/m_ecs_manager.gd`
- [x] Run ECS tests to verify

**Status**: COMPLETE (2026-01-23)
**Files affected**: 1 (.gd) + 1 (.uid) = 2 total
**References to update**: 1 (m_ecs_manager.gd)
**Risk**: Low
**Notes**: Removed `class_name` from the helper to avoid global class cache conflicts in headless tests.

**Execution Commands**:
```bash
mkdir -p scripts/utils/ecs
git mv scripts/ecs/helpers/u_ecs_query_metrics.gd scripts/utils/ecs/
mv scripts/ecs/helpers/u_ecs_query_metrics.gd.uid scripts/utils/ecs/
rmdir scripts/ecs/helpers
# Update reference
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ecs/helpers/|res://scripts/utils/ecs/|g' {} +
# Test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
git add . && git commit -m "refactor: consolidate ECS helpers to scripts/utils/ecs/"
```

---

## Phase 2: Naming Convention Fixes (Medium Risk)

### Task 5: Fix Manager Helper Prefixes (m_ -> u_) COMPLETE

**Rationale**: These are utility classes, not managers. Current `m_` prefix is misleading.

- [x] Scan for all references to these 8 files
- [x] Rename files and update class names:
  - `m_autosave_scheduler.gd` -> `u_autosave_scheduler.gd`
  - `m_damage_flash.gd` -> `u_damage_flash.gd`
  - `m_input_profile_loader.gd` -> `u_input_profile_loader.gd`
  - `m_save_file_io.gd` -> `u_save_file_io.gd`
  - `m_save_migration_engine.gd` -> `u_save_migration_engine.gd`
  - `m_screen_shake.gd` -> `u_screen_shake.gd`
  - `m_sfx_spawner.gd` -> `u_sfx_spawner.gd`
  - `m_shake_result.gd` -> `u_shake_result.gd` (class renamed to `U_ShakeResult`)
- [x] Update all references (preloads, class names, variable names)
- [x] Run affected tests + style enforcement

**Status**: COMPLETE (2026-01-24)
**Files affected**: 8 helpers + references (scripts/tests/docs)
**Risk**: Medium
**Notes**:
- Updated style guide + style enforcement to allow `u_` helper scripts under `scripts/managers/helpers`.
- Updated tests to use preloaded helper scripts to avoid headless class cache issues.

**Reference Scan Command**:
```bash
grep -rn "m_autosave_scheduler\|m_damage_flash\|m_input_profile_loader\|m_save_file_io\|m_save_migration_engine\|m_screen_shake\|m_sfx_spawner\|m_shake_result" scripts/ --include="*.gd"
```

---

### Task 6: Rename Interactable Controllers (e_ -> inter_) COMPLETE

**Rationale**: Interactable controllers need distinct prefix from regular entities. New `inter_` prefix clarifies purpose.

**RESOLVED**: `e_endgame_goal_zone.gd` IS an interactable and should be renamed to `inter_endgame_goal_zone.gd`.

- [x] Scan for all references to these 6 files
- [x] Rename files and update class names:
  - `e_door_trigger_controller.gd` -> `inter_door_trigger.gd`
  - `e_checkpoint_zone.gd` -> `inter_checkpoint_zone.gd`
  - `e_hazard_zone.gd` -> `inter_hazard_zone.gd`
  - `e_victory_zone.gd` -> `inter_victory_zone.gd`
  - `e_signpost.gd` -> `inter_signpost.gd`
  - `e_endgame_goal_zone.gd` -> `inter_endgame_goal_zone.gd`
- [x] Update all scene references
- [x] Update class names (E_* -> Inter_*)
- [x] Update STYLE_GUIDE.md to document `inter_` prefix
- [x] Run affected tests

**Status**: COMPLETE (2026-01-24)
**Files affected**: 6 files + scene references
**Risk**: Medium
**Notes**: Updated style enforcement to allow `inter_` in gameplay scripts. Ran interactables + style tests.

**Reference Scan Command**:
```bash
grep -rn "e_door_trigger_controller\|e_checkpoint_zone\|e_hazard_zone\|e_victory_zone\|e_signpost\|e_endgame_goal_zone" . --include="*.gd" --include="*.tscn"
```

---

### Task 7: Convert Surface Marker to Component PENDING

**Rationale**: `marker_surface_type.gd` is functionally a component but uses incorrect prefix.

- [ ] Create `scripts/ecs/components/c_surface_type_component.gd`
  - Extend `BaseECSComponent`
  - Add `COMPONENT_TYPE := StringName("C_SurfaceTypeComponent")`
  - Port `surface_type` export and `get_surface_type()` method
- [ ] Update `scenes/gameplay/gameplay_exterior.tscn` to use new component
- [ ] Update `tests/unit/ecs/systems/test_footstep_sound_system.gd`
- [ ] Update `tests/unit/ecs/components/test_surface_detector.gd` (if exists)
- [ ] Delete `scripts/ecs/markers/marker_surface_type.gd`
- [ ] Update the exterior and interior scenes to use the component
- [ ] Run ECS tests

**Status**: READY TO PLAN
**Files affected**: 4 (1 new, 1 delete, 2 updates)
**Risk**: Low

---

### Task 8: Rename main.gd to root.gd PENDING

**Rationale**: Script is attached to `root.tscn`, should be named `root.gd` for clarity.

- [ ] Scan for all references to `main.gd` (33 known)
- [ ] Move `scripts/scene_structure/main.gd` -> `scripts/root.gd`
- [ ] Update CRITICAL reference in `scenes/root.tscn` (line 11)
- [ ] Update all gameplay scene references
- [ ] Update all documentation references (AGENTS.md, PRDs, etc.)
- [ ] Run full test suite
- [ ] Verify root scene loads in Godot editor

**Status**: NEEDS CAREFUL EXECUTION
**Files affected**: 1 move + 33 reference updates
**Risk**: HIGH - breaks root scene if done incorrectly

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/scene_structure/main.gd|res://scripts/root.gd|g' {} +
```

**Critical Files for Manual Verification**:
- `scenes/root.tscn` (line 11: CRITICAL - script attachment)
- All gameplay scenes
- `AGENTS.md`

---

## Phase 3: Folder Restructuring (High Risk)

### Task 9: Move Templates to scenes/templates/ PENDING

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

**Critical Files for Manual Verification**:
- `project.godot` (main scene reference)
- `scenes/root.tscn`
- `scenes/gameplay/gameplay_base.tscn`
- `scenes/prefabs/prefab_player.tscn`

---

### Task 10: Move Audio Assets to assets/audio/ PENDING

- [ ] Create `assets/audio/` directory structure
- [ ] Move `resources/audio/` -> `assets/audio/` (100+ files including subdirs)
- [ ] Update all references (83 files):
  - `scripts/managers/m_audio_manager.gd` (lines 20-46: preloads)
  - `scripts/ecs/systems/s_ambient_sound_system.gd`
  - Base settings `.tres` files (in `resources/settings/`)
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

**Critical Files for Manual Verification**:
- `scripts/managers/m_audio_manager.gd` (lines 18-46: preloads)
- `resources/settings/*_sound_default.tres` (6 files)
- `tests/unit/managers/test_audio_manager.gd`

**Test Command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/audio -gexit
```

---

### Task 11: Move Button Prompts to assets/button_prompts/ PENDING

- [ ] Create `assets/button_prompts/` directory structure
- [ ] Move `resources/button_prompts/` -> `assets/button_prompts/` (80+ files including subdirs)
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

**Critical Files for Manual Verification**:
- `scripts/ui/u_button_prompt_registry.gd` (lines 18-49: paths)
- `scenes/ui/ui_virtual_joystick.tscn`
- `scenes/ui/ui_virtual_button.tscn`
- `scenes/ui/ui_button_prompt.tscn`

**Test Command**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit
```

---

### Task 12: Move Editor Icons to assets/editor_icons/ PENDING

- [ ] Scan for all references to `resources/editor_icons/`
- [ ] Create `assets/editor_icons/` directory
- [ ] Move `resources/editor_icons/` -> `assets/editor_icons/` (34 files)
- [ ] Update all references
- [ ] Verify icons display in Godot editor

**Status**: NEEDS REFERENCE SCAN
**Files affected**: 34 moves + unknown references
**Risk**: Medium

---

### Task 13: Consolidate ECS Resources PENDING

- [ ] Create `scripts/resources/ecs/` directory
- [ ] Move `scripts/ecs/resources/` -> `scripts/resources/ecs/`
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

**Critical Files for Manual Verification**:
- `scripts/managers/m_ecs_manager.gd`
- All component/system files with resource imports
- All .tres files with script references

---

### Task 14: Consolidate UI Resources PENDING

- [ ] Scan for all references to `scripts/ui/resources/`
- [ ] Create `scripts/resources/ui/` directory
- [ ] Move `scripts/ui/resources/` -> `scripts/resources/ui/`
- [ ] Update all references
- [ ] Run UI tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: Unknown
**Risk**: Medium

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ui/resources/|res://scripts/resources/ui/|g' {} +
```

---

### Task 15: Consolidate State Resources PENDING

- [ ] Scan for all references to `scripts/state/resources/`
- [ ] Create `scripts/resources/state/` directory
- [ ] Move `scripts/state/resources/` -> `scripts/resources/state/`
- [ ] Update all references
- [ ] Run state tests
- [ ] Scan for all references to `scripts/input/resources/`
- [ ] Create `scripts/resources/input/` directory
- [ ] Move `scripts/input/resources/` -> `scripts/resources/input/`
- [ ] Update all references
- [ ] Run input tests
- [ ] Scan for all references to `scripts/scene_management/resources/`
- [ ] Create `scripts/resources/scene_management/` directory
- [ ] Move `scripts/scene_management/resources/` -> `scripts/resources/scene_management/`
- [ ] Update all references (includes `.tres` under `resources/scene_registry/`)
- [ ] Run scene manager tests

**Status**: NEEDS REFERENCE SCAN
**Files affected**: Unknown
**Risk**: High - broad reference updates across resources + scripts

**Path Update Commands**:
```bash
# State resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/state/resources/|res://scripts/resources/state/|g' {} +

# Input resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/input/resources/|res://scripts/resources/input/|g' {} +

# Scene management resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/scene_management/resources/|res://scripts/resources/scene_management/|g' {} +
```

---

### Task 16: Move Scattered Interfaces PENDING

**Rationale**: Interface scripts should be centralized under `scripts/interfaces/`.

- [ ] Move these interface scripts to `scripts/interfaces/`:
  - `scripts/scene_management/i_scene_contract.gd`
  - `scripts/scene_management/i_scene_type_handler.gd`
  - `scripts/scene_management/i_transition_effect.gd`
  - `scripts/input/i_input_source.gd`
- [ ] Update all references
- [ ] Run scene manager tests

**Status**: READY TO EXECUTE
**Files affected**: 4 moves + unknown references
**Risk**: Low

---

## Phase 4: Organization Improvements (Medium Risk)

### Task 17: Organize UI Scripts by Screen Type PENDING

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

### Task 18: Split Settings by Domain PENDING

**RESOLVED - Naming Convention**: Use `rs_*_settings.gd` for resource scripts and `rs_*_default.tres` for default instances. This is consistent with existing patterns.

**Proposed Organization**:
```
resources/base_settings/
  ├── gameplay/  (movement, jump, gravity, etc.)
  ├── audio/     (sound settings)
  └── input/     (input profile settings)
```

- [ ] Rename `resources/settings/` -> `resources/base_settings/`
- [ ] Create domain subdirectories under `resources/base_settings/`
- [ ] Move base settings files into the correct domain subdirectories
- [ ] Update all references
- [ ] Run tests

**Status**: CAN BE DEFERRED
**Files affected**: 17 moves + unknown references
**Risk**: Low

**Path Update Command**:
```bash
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://resources/settings/|res://resources/base_settings/|g' {} +
```

---

### Task 19: Move Loose Trigger Settings PENDING

- [ ] Create `resources/triggers/` directory
- [ ] Move `resources/rs_scene_trigger_settings.tres` -> `resources/triggers/`
- [ ] Update references
- [ ] Run tests

**Status**: READY TO EXECUTE
**Files affected**: 1 move + unknown references
**Risk**: Low

---

### Task 20: Rename Docs Folders (Spaces -> Snake_Case) PENDING

**Rationale**: Documentation folders use spaces instead of snake_case convention

Rename these 10 folders in `docs/`:
- [ ] `"audio manager"` -> `audio_manager`
- [ ] `"display manager"` -> `display_manager`
- [ ] `"input manager"` -> `input_manager`
- [ ] `"save manager"` -> `save_manager`
- [ ] `"scene manager"` -> `scene_manager`
- [ ] `"state store"` -> `state_store`
- [ ] `"ui manager"` -> `ui_manager`
- [ ] `"vfx manager"` -> `vfx_manager`
- [ ] Update any documentation that references these folders

**Status**: READY TO EXECUTE
**Files affected**: 10 folder renames
**Risk**: LOW - documentation only

---

## Phase 5: Optional Polish

### Task 21: Consolidate Utilities into Domain Subfolders PENDING

**RESOLVED - Scope**: Create these domain folders under `scripts/utils/`:
- `ecs/` (required - Task 4 creates this)
- `input/` (optional)
- `state/` (optional)

Do NOT move `scripts/state/utils` or `scripts/ui/utils` - they can stay domain-local.

**Proposed Organization**:
```
scripts/utils/
  ├── ecs/
  ├── input/
  └── state/
```

- [ ] Decide the minimum set of domain folders to introduce (ecs is required)
- [ ] Move domain-specific utility scripts into the corresponding subfolders
- [ ] Update all references (preloads, docs)
- [ ] Run unit tests + style enforcement

**Status**: CAN BE DEFERRED
**Risk**: Medium - widespread reference updates depending on scope

---

### Task 22: Clean Up Unused Test Files PENDING

- [ ] Audit `tests/` directory for orphaned files
- [ ] Remove unused test files
- [ ] Consolidate test helpers if needed

**Status**: CAN BE DEFERRED
**Risk**: Low

---

### Task 23: Consolidate Event Code Under scripts/events/ PENDING

**RESOLVED - Design**: Consolidate under `scripts/events/` with this structure:
```
scripts/events/
  ├── base_event_bus.gd
  ├── ecs/    (ECS bus + typed ECS events)
  └── state/  (State bus + typed state events)
```

- [ ] Move files into `scripts/events/` domain subfolders:
  - `U_ECSEventBus`, `U_ECSEventNames`, and `scripts/ecs/events/*`
  - `U_StateEventBus`
- [ ] Update all references (preloads, docs)
- [ ] Run unit tests + style enforcement

**Status**: DESIGN CONFIRMED - NEEDS REFERENCE SCAN
**Risk**: Medium/High - potentially many call sites

---

## Execution Strategy

### Batch 1: Zero-Risk Quick Wins (Execute First)
- Task 2: Move prototype scenes (done)
- Task 3: Move prototype scripts (done)
- Task 4: Move ECS helpers (done)


### Batch 2: Naming Fixes (Needs Scanning)
- Task 5: Fix manager helper prefixes (done)
- Task 6: Rename interactables
- Task 7: Convert surface marker
- Task 8: Rename main.gd (CRITICAL)

### Batch 3: Folder Restructuring (High Impact)
- Task 9: Move templates
- Task 10-11: Move audio/button prompt assets (CRITICAL)
- Task 12-16: Consolidate resources and interfaces

### Batch 4: Organization (Optional)
- Tasks 17-23: Polish and cleanup

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

## Rollback Strategy

If tests fail after a task:

1. **Immediate rollback**: `git reset --hard HEAD`
2. **Analyze failure**: Review test output, check file paths
3. **Re-evaluate approach**: Consider breaking task into smaller steps
4. **Retry with caution**: Fix issues before re-attempting

Keep each task/batch in a separate commit for granular rollback capability.

---

## Known Gaps (Verify During Execution)

These items need verification during execution:

1. **.import files**: Will Godot auto-regenerate all .import files after moves? (Test and verify)
2. **Dynamic paths**: Are there any runtime path constructions that won't be caught by find/replace? (Verify during testing)
3. **Asset file naming prefixes**: If adopting prefixes for moved assets (audio/prompts/icons), decide per-task

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

- [ ] All 23 tasks completed (or consciously deferred for Phase 5)
- [ ] All unit tests passing (1468/1473 or better)
- [ ] Style enforcement tests passing
- [ ] Scenes load in Godot editor
- [ ] No broken preload/load paths
- [ ] STYLE_GUIDE.md updated
- [ ] AGENTS.md updated
- [ ] Documentation updated

---

**Last Updated**: 2026-01-23
**Status**: In Progress (1/23 complete - 4.3%)
**Next Batch**: Batch 1 (Tasks 2-4) - Zero-risk quick wins
