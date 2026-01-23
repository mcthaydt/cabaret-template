# Project Reorganization Continuation Prompt

Use this prompt to resume the project reorganization effort (cleanup_v4).

---

## Context

- **Goal**: Comprehensive reorganization to improve folder structure clarity, enforce consistent naming conventions, and improve developer navigability
- **Scope**: 614 GDScript files, 76 scene files, 200+ file references
- **Approach**: Execute in 5 phases (22 tasks total) with testing between each batch to prevent breaking changes

**Core Principles**:
- Never break the working tree - commit after each task or logical batch
- Update all references (scripts, scenes, resources, tests, docs) for each move
- Run tests after each batch to verify integrity
- Use find/replace for bulk path updates to ensure consistency
- Prioritize low-risk tasks first, save critical path changes for later

---

## Read First

- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/general/cleanup_v4/reorganization-tasks.md` (complete 22-task checklist)
- `docs/general/cleanup_v4/reorganization-audit.md` (comprehensive impact analysis)

---

## Current Progress

### Phase 1: Quick Wins (Low Risk) - 4 Tasks

- [x] **Task 1: Delete parse_test.gd** ✅ COMPLETE (2026-01-23)
  - Deleted `tools/parse_test.gd` and `tools/parse_test.gd.uid`
  - No references found in codebase
  - Risk: None
  - Status: DONE

- [ ] **Task 2: Move prototype scenes** 📋 PENDING
  - **Target**: `scenes/prototypes/` → `tests/scenes/prototypes/` (2 files)
  - **Risk**: LOW - no active references
  - **Status**: READY TO EXECUTE

- [ ] **Task 3: Move prototype scripts** 📋 PENDING
  - **Target**: `scripts/prototypes/` → `tests/prototypes/` (6 files)
  - **Risk**: LOW - no active references
  - **Status**: READY TO EXECUTE

- [ ] **Task 4: Move ECS helpers** 📋 PENDING
  - **Target**: `scripts/ecs/helpers/` → `scripts/utils/ecs/` (1 file)
  - **Files to update**: `scripts/managers/m_ecs_manager.gd` (1 preload)
  - **Risk**: LOW
  - **Status**: READY TO EXECUTE

### Phase 2: Naming Convention Fixes (Medium Risk) - 4 Tasks

- [ ] **Task 5: Fix manager helper prefixes** 📋 PENDING
  - **Target**: Rename 8 files in `scripts/managers/helpers/` from `m_` to `u_` prefix
  - **Files affected**: 8 helpers + unknown references
  - **Risk**: MEDIUM - need to scan for all references
  - **Status**: NEEDS REFERENCE SCAN

- [ ] **Task 6: Rename interactables** 📋 PENDING
  - **Target**: `e_*.gd` → `inter_*.gd` for 6 interactable controller files
  - **Files affected**: 6 files + scene references
  - **Risk**: MEDIUM - scene references + STYLE_GUIDE.md update
  - **Status**: NEEDS REFERENCE SCAN

- [ ] **Task 7: Convert surface marker to component** 📋 PENDING
  - **Target**: `marker_surface_type.gd` → `c_surface_type_component.gd`
  - **Files to update**: 4 (tests + gameplay_exterior.tscn)
  - **Risk**: LOW - isolated change
  - **Status**: READY TO PLAN

- [ ] **Task 8: Rename main.gd to root.gd** 📋 PENDING
  - **Target**: `scripts/scene_structure/main.gd` → `scripts/root.gd`
  - **Files to update**: 33 (CRITICAL: scenes/root.tscn line 11, plus gameplay scenes + docs)
  - **Risk**: HIGH - breaks root scene if not done correctly
  - **Status**: NEEDS CAREFUL EXECUTION

### Phase 3: Folder Restructuring (High Risk) - 8 Tasks

- [ ] **Task 9: Move templates** 📋 PENDING
  - **Target**: `templates/` → `scenes/templates/` (4 template files)
  - **Files to update**: 21 (project.godot, scenes, tests, docs)
  - **Risk**: MEDIUM - affects scene loading
  - **Status**: READY TO EXECUTE

- [ ] **Task 10: Move audio assets** 📋 PENDING
  - **Target**: `resources/audio/` → `assets/audio/` (100+ files)
  - **Files to update**: 83 files (`m_audio_manager.gd`, 6 .tres, 75+ .import, 3 tests)
  - **Risk**: CRITICAL - high file count
  - **Status**: READY TO EXECUTE

- [ ] **Task 11: Move button prompts** 📋 PENDING
  - **Target**: `resources/button_prompts/` → `assets/button_prompts/` (80+ files)
  - **Files to update**: 53 files (`u_button_prompt_registry.gd`, 3 .tscn, 46+ .import, 2 tests)
  - **Risk**: CRITICAL - high file count
  - **Status**: READY TO EXECUTE

- [ ] **Task 12: Move editor icons** 📋 PENDING
  - **Target**: `resources/editor_icons/` → `assets/editor_icons/` (34 files)
  - **Files to update**: Unknown (needs scan)
  - **Risk**: MEDIUM - not data resources
  - **Status**: NEEDS REFERENCE SCAN

- [ ] **Task 13: Consolidate ECS resources** 📋 PENDING
  - **Target**: `scripts/ecs/resources/` → `scripts/resources/ecs/`
  - **Files to update**: 67 (scripts, .tres, tests)
  - **Risk**: HIGH - widespread impact
  - **Status**: READY TO EXECUTE

- [ ] **Task 14: Consolidate UI resources** 📋 PENDING
  - **Target**: `scripts/ui/resources/` → `scripts/resources/ui/`
  - **Files to update**: Unknown (needs scan)
  - **Risk**: MEDIUM
  - **Status**: NEEDS REFERENCE SCAN

- [ ] **Task 15: Consolidate state resources** 📋 PENDING
  - **Target**: `scripts/state/resources/` → `scripts/resources/state/`
  - **Files to update**: Unknown (needs scan)
  - **Risk**: MEDIUM
  - **Status**: NEEDS REFERENCE SCAN

- [ ] **Task 16: Move scattered interfaces** 📋 PENDING
  - **Target**: Move 3 interface files from `scripts/scene_management/` to `scripts/interfaces/`
  - **Files to move**: `i_scene_contract.gd`, `i_scene_type_handler.gd`, `i_transition_effect.gd`
  - **Risk**: LOW - simple move
  - **Status**: READY TO EXECUTE

### Phase 4: Organization Improvements (Medium Risk) - 4 Tasks

- [ ] **Task 17: Organize UI scripts** 📋 PENDING
  - **Target**: Organize 18+ UI scripts into `menus/`, `overlays/`, `hud/` subdirectories
  - **Files to update**: Unknown (needs comprehensive scan)
  - **Risk**: MEDIUM - cosmetic but affects many imports
  - **Status**: CAN BE DEFERRED

- [ ] **Task 18: Split settings by domain** 📋 PENDING
  - **Target**: Split `resources/settings/` by domain (gameplay/, audio/, input/)
  - **Files affected**: 17 settings files
  - **Risk**: LOW - organizational
  - **Status**: CAN BE DEFERRED

- [ ] **Task 19: Move loose trigger settings** 📋 PENDING
  - **Target**: `resources/rs_scene_trigger_settings.tres` → `resources/triggers/`
  - **Files affected**: 1 file
  - **Risk**: LOW
  - **Status**: READY TO EXECUTE

- [ ] **Task 20: Rename docs folders** 📋 PENDING
  - **Target**: Rename 10 docs folders from spaces to snake_case
  - **Folders**: "audio manager" → audio_manager, "display manager" → display_manager, etc.
  - **Risk**: LOW - documentation only
  - **Status**: READY TO EXECUTE

### Phase 5: Optional Polish - 2 Tasks

- [ ] **Task 21: Add data_ prefix to resource folders** 📋 PENDING
  - **Target**: Cosmetic rename for clarity
  - **Risk**: LOW - optional
  - **Status**: CAN BE DEFERRED

- [ ] **Task 22: Clean up unused test files** 📋 PENDING
  - **Target**: Remove orphaned test files
  - **Risk**: LOW - optional
  - **Status**: CAN BE DEFERRED

---

## Execution Rules

### Before Each Phase
1. Ensure working tree is clean (`git status`)
2. Run full test suite to establish baseline
3. Create checkpoint commit if needed

### During Each Task
1. Perform file moves using `git mv` (preserves history)
2. Update all references using find/replace
3. Manually verify critical files (scenes, managers, tests)
4. Run style enforcement tests
5. Run affected unit tests

### After Each Task
1. Verify scenes load in Godot editor
2. Run full test suite
3. Commit with descriptive message: `refactor: [task name] - [file count] files updated`
4. Update this continuation prompt with progress
5. Update `reorganization-tasks.md` checkboxes

### Path Update Commands

```bash
# Audio assets
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://resources/audio/|res://assets/audio/|g' {} +

# Button prompts
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://resources/button_prompts/|res://assets/button_prompts/|g' {} +

# Templates
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://templates/|res://scenes/templates/|g' {} +

# ECS resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ecs/resources/|res://scripts/resources/ecs/|g' {} +

# UI resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ui/resources/|res://scripts/resources/ui/|g' {} +

# State resources
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/state/resources/|res://scripts/resources/state/|g' {} +

# Main script
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/scene_structure/main.gd|res://scripts/root.gd|g' {} +
```

### Test Commands

```bash
# Full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Style enforcement only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Specific subsystem (e.g., ECS)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

---

## Risk Assessment Matrix

| Task | Risk | Impact | Files | References | Test Coverage |
|------|------|--------|-------|------------|---------------|
| 1. Delete parse_test | ✅ None | Low | 2 | 0 | N/A |
| 2. Move audio assets | 🔴 Critical | Critical | 100+ | 83 | Yes |
| 3. Move prototypes | 🟢 Low | Low | 8 | 0 | No |
| 4. Move templates | 🟡 Medium | High | 4 | 21 | Partial |
| 5. Surface marker → component | 🟢 Low | Low | 1 | 4 | Yes |
| 6. Rename interactables | 🟡 Medium | Medium | 6 | Unknown | Yes |
| 7. Rename main.gd | 🔴 High | Critical | 1 | 33 | Partial |
| 8. Consolidate ECS helpers | 🟢 Low | Low | 1 | 1 | Yes |
| 9. Clean up ECS folders | 🔴 High | High | Many | 67 | Yes |
| 10. Organize UI scripts | 🟡 Medium | Medium | 18 | Unknown | Partial |

---

## Critical Files Requiring Manual Verification

After path updates, manually verify these files:

### Audio Move (Task 2)
- `scripts/managers/m_audio_manager.gd` (lines 18-46: preloads)
- `resources/settings/*_sound_default.tres` (6 files)
- `tests/unit/managers/test_audio_manager.gd`

### Button Prompts Move (Task 2)
- `scripts/ui/u_button_prompt_registry.gd` (lines 18-49: paths)
- `scenes/ui/ui_virtual_joystick.tscn`
- `scenes/ui/ui_virtual_button.tscn`
- `scenes/ui/ui_button_prompt.tscn`

### Templates Move (Task 4)
- `project.godot` (main scene reference)
- `scenes/root.tscn`
- `scenes/gameplay/gameplay_base.tscn`
- `scenes/prefabs/prefab_player.tscn`

### Main Script Rename (Task 7)
- `scenes/root.tscn` (line 11: CRITICAL)
- All gameplay scenes

### ECS Reorganization (Task 9)
- `scripts/managers/m_ecs_manager.gd`
- All component/system files with resource imports
- All .tres files with script references

---

## Rollback Strategy

If tests fail after a phase:

1. **Immediate rollback**: `git reset --hard HEAD`
2. **Analyze failure**: Review test output, check file paths
3. **Re-evaluate approach**: Consider breaking task into smaller steps
4. **Retry with caution**: Fix issues before re-attempting

Keep each phase in a separate commit for granular rollback capability.

---

## Known Gaps & Open Questions

1. **.import files**: Will Godot auto-regenerate all .import files after moves, or do some need manual updates?
2. **UID references**: Do .tres files using UIDs break when source files move, or does Godot track them?
3. **Dynamic paths**: Are there any runtime path constructions that won't be caught by find/replace?
4. **Hidden .tscn refs**: Do scene files have embedded paths outside ExtResource declarations?
5. **Documentation**: Should doc updates happen per-phase or in a final cleanup commit?
6. **e_endgame_goal_zone.gd**: Is this an interactable that needs renaming to `inter_` prefix?
7. **scripts/prototypes/**: Should this be moved to tests? (Found 6 prototype scripts)
8. **UI organization**: Should we create new subdirs or consolidate into existing `settings/` and `utils/`?

---

## Next Steps

### Immediate Actions (Complete Batch 1)

**RESUME HERE**: Execute Batch 1 - Zero-Risk Quick Wins

**Batch 1 Tasks (Already Scoped)**:
1. Task 2: Move prototype scenes to tests/
2. Task 3: Move prototype scripts to tests/
3. Task 4: Move ECS helpers to utils/

**Execution Order**:
```bash
# Task 2: Move prototype scenes
mkdir -p tests/scenes/prototypes
git mv scenes/prototypes/* tests/scenes/prototypes/
rmdir scenes/prototypes
grep -r "res://scenes/prototypes" . --include="*.gd" --include="*.tscn"  # Verify no refs
git add . && git commit -m "refactor: move prototype scenes to tests folder"

# Task 3: Move prototype scripts
mkdir -p tests/prototypes
git mv scripts/prototypes/* tests/prototypes/
rmdir scripts/prototypes
grep -r "res://scripts/prototypes" . --include="*.gd" --include="*.tscn"  # Verify no refs
git add . && git commit -m "refactor: move prototype scripts to tests folder"

# Task 4: Move ECS helpers
mkdir -p scripts/utils/ecs
git mv scripts/ecs/helpers/u_ecs_query_metrics.gd scripts/utils/ecs/
rmdir scripts/ecs/helpers
# Update reference in m_ecs_manager.gd
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|res://scripts/ecs/helpers/|res://scripts/utils/ecs/|g' {} +
# Run ECS tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
git add . && git commit -m "refactor: consolidate ECS helpers to scripts/utils/ecs/"
```

### After Batch 1 Completion

**Before starting Batch 2**, perform these actions:
1. Update this continuation prompt (mark Tasks 2-4 complete)
2. Update `reorganization-tasks.md` checkboxes
3. Commit documentation updates separately
4. Run full test suite to verify green baseline
5. Get user approval before proceeding to Batch 2

### Batch 2: Naming Fixes (Needs Reference Scans)

Tasks 5-8 require comprehensive reference scanning before execution:
- Task 5: Scan all references to `scripts/managers/helpers/m_*.gd` files
- Task 6: Scan all references to `e_door_trigger_controller.gd`, `e_checkpoint_zone.gd`, etc.
- Task 7: Low risk, proceed after Tasks 5-6
- Task 8: Scan all references to `main.gd` (CRITICAL - 33 known refs)

### Batch 3: Folder Restructuring (Careful Testing)

Tasks 9-16 are high-impact moves requiring extensive testing:
- Task 9: Move templates (21 refs)
- Tasks 10-11: Move audio/button prompts (CRITICAL - 136 refs combined)
- Task 12: Move editor icons (needs scan)
- Tasks 13-15: Consolidate resource scripts (67+ refs)
- Task 16: Move interfaces (3 files, simple move)

### Batch 4: Organization (Optional)

Tasks 17-22 are lower priority polish tasks that can be deferred

---

## Success Criteria

### Batch 1 Complete (Quick Wins)
- [x] Task 1: parse_test deleted ✅
- [ ] Task 2: Prototype scenes moved to tests/
- [ ] Task 3: Prototype scripts moved to tests/
- [ ] Task 4: ECS helpers consolidated to utils/

### Batch 2 Complete (Naming Fixes)
- [ ] Task 5: Manager helper prefixes fixed (m_ → u_)
- [ ] Task 6: Interactables renamed (e_ → inter_)
- [ ] Task 7: Surface marker converted to component
- [ ] Task 8: main.gd renamed to root.gd

### Batch 3 Complete (Folder Restructuring)
- [ ] Task 9: Templates moved to scenes/templates/
- [ ] Task 10: Audio assets moved to assets/audio/
- [ ] Task 11: Button prompts moved to assets/button_prompts/
- [ ] Task 12: Editor icons moved to assets/editor_icons/
- [ ] Task 13: ECS resources consolidated
- [ ] Task 14: UI resources consolidated
- [ ] Task 15: State resources consolidated
- [ ] Task 16: Scattered interfaces moved

### Batch 4 Complete (Organization - Optional)
- [ ] Task 17: UI scripts organized
- [ ] Task 18: Settings split by domain
- [ ] Task 19: Loose trigger settings moved
- [ ] Task 20: Docs folders renamed (spaces → snake_case)
- [ ] Task 21: data_ prefixes added (optional)
- [ ] Task 22: Unused test files cleaned (optional)

### Overall Success Criteria
- [ ] All unit tests passing (1468/1473 or better)
- [ ] Style enforcement tests passing
- [ ] Scenes load successfully in Godot editor
- [ ] No broken preload/load paths
- [ ] STYLE_GUIDE.md updated with `inter_` prefix convention
- [ ] AGENTS.md updated with new file paths
- [ ] Documentation updated (this file + tasks file)
- [ ] Clean commits for each task/batch

---

## Estimated Effort

- **Batch 1 (Tasks 2-4)**: 30-45 minutes (simple moves, no references)
- **Batch 2 (Tasks 5-8)**: 2-3 hours (scanning refs, careful testing)
- **Batch 3 (Tasks 9-16)**: 4-5 hours (high-impact, extensive testing)
- **Batch 4 (Tasks 17-22)**: 2-3 hours (optional polish)
- **Total remaining**: 8-11 hours (6-8 hours for required tasks only)

---

## NEW Issues Discovered

This reorganization revealed several inconsistencies not in the original plan:

1. **Manager helpers with wrong prefix** (8 files) - Should use `u_` not `m_` (Task 5)
2. **Scattered interfaces** (3 files) - Should consolidate to `scripts/interfaces/` (Task 16)
3. **Docs folder naming** (10 folders) - Should use snake_case not spaces (Task 20)
4. **Loose resource file** - `rs_scene_trigger_settings.tres` not in proper folder (Task 19)
5. **Editor icons in resources** - Non-data assets in wrong folder (Task 12)

These findings justify the expanded 22-task scope.

---

## Additional Resources

- **Audit document**: `docs/general/cleanup_v4/reorganization-audit.md` - Comprehensive impact analysis
- **Tasks document**: `docs/general/cleanup_v4/reorganization-tasks.md` - Complete 22-task checklist
- **Style guide**: `docs/general/STYLE_GUIDE.md` - Prefix conventions (will need `inter_` prefix added)
- **Agents guide**: `AGENTS.md` - Repo map (will need path updates)
- **Dev pitfalls**: `docs/general/DEV_PITFALLS.md` - Common issues to avoid

---

**Last Updated**: 2026-01-23
**Current Status**: Phase 1 Batch 1 ready (1/4 tasks complete)
**Next Actions**: Execute Tasks 2-4 (prototype scenes/scripts + ECS helpers)
**Total Progress**: 1/22 tasks complete (4.5%)
