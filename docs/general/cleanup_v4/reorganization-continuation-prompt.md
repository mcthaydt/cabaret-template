# Project Reorganization Continuation Prompt

Use this prompt to resume the project reorganization effort (cleanup_v4).

---

## Context

- **Goal**: Improve folder structure clarity, enforce consistent conventions, and consolidate scattered organization patterns
- **Scope**: 614 GDScript files, 76 scene files, hundreds of resource files
- **Impact**: 200+ file references require path updates
- **Approach**: Execute in 5 phases with testing between each to prevent breaking changes

**Core Principles**:
- Never break the working tree - commit after each phase
- Update all references (scripts, scenes, resources, tests, docs) for each move
- Run tests after each phase to verify integrity
- Use find/replace for bulk path updates to ensure consistency

---

## Read First

- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/general/cleanup_v4/reorganization-tasks.md` (original task list)
- `docs/general/cleanup_v4/reorganization-audit.md` (comprehensive impact analysis)

---

## Current Progress

### Phase 1: Low-Risk Moves ⚠️ IN PROGRESS

- [x] **Task 1: Delete parse_test.gd** ✅ COMPLETE (2026-01-23)
  - Deleted `tools/parse_test.gd` and `tools/parse_test.gd.uid`
  - No references found in codebase
  - Risk: None
  - Status: DONE

- [x] **Task 2: Move audio/image assets** ⚠️ BLOCKED - NEEDS EXECUTION
  - **Target**: `resources/audio/` → `assets/audio/` (100+ files)
  - **Target**: `resources/button_prompts/` → `assets/button_prompts/` (80+ files)
  - **Risk**: CRITICAL - 136 file references need updates
  - **Files to update**:
    - Audio: 83 files (`m_audio_manager.gd`, 6 .tres, 75+ .import, 3 tests)
    - Button prompts: 53 files (`u_button_prompt_registry.gd`, 3 .tscn, 46+ .import, 2 tests)
  - **Strategy**: Use find/replace, then manual verification of critical files
  - **Status**: READY TO EXECUTE

- [ ] **Task 3: Move prototype scenes/scripts** 📋 PENDING
  - **Target scenes**: `scenes/prototypes/` → `tests/scenes/prototypes/` (2 files)
  - **Target scripts**: `scripts/prototypes/` → `tests/prototypes/` (6 files)
  - **Risk**: LOW - no active references found
  - **Status**: READY TO EXECUTE

- [ ] **Task 8: Consolidate ECS helpers** 📋 PENDING
  - **Target**: `scripts/ecs/helpers/` → `scripts/utils/ecs/` (1 file)
  - **Files to update**: `scripts/managers/m_ecs_manager.gd` (1 preload)
  - **Risk**: LOW
  - **Status**: READY TO EXECUTE

### Phase 2: Structural Changes 📋 PENDING

- [ ] **Task 5: Convert marker_surface_type to component** 📋 PENDING
  - **Target**: Convert `scripts/ecs/markers/marker_surface_type.gd` to `scripts/ecs/components/c_surface_type_component.gd`
  - **Files to update**: 4 (tests + gameplay_exterior.tscn)
  - **Risk**: LOW - isolated change
  - **Status**: READY TO PLAN

- [ ] **Task 6: Rename interactable controllers** 📋 PENDING
  - **Target**: `e_*.gd` → `inter_*.gd` for 6 controller files
  - **Files to update**: Unknown (needs comprehensive grep)
  - **Risk**: MEDIUM - scene references + STYLE_GUIDE.md update
  - **Status**: NEEDS REFERENCE SCAN

### Phase 3: High-Impact Path Changes 📋 PENDING

- [ ] **Task 4: Move templates** 📋 PENDING
  - **Target**: `templates/` → `scenes/templates/` (4 template files)
  - **Files to update**: 21 (project.godot, 6 scenes, 5 tests, 9 docs)
  - **Risk**: MEDIUM - affects scene loading
  - **Status**: NEEDS EXECUTION

- [ ] **Task 9: Clean up ECS folder structure** 📋 PENDING
  - **Target**: Move `ecs/resources/`, `ui/resources/`, `state/resources/` → `scripts/resources/*/`
  - **Target**: Move `ecs/markers/` → `scripts/scene_structure/ecs/`
  - **Files to update**: 67 (scripts, .tres, tests)
  - **Risk**: HIGH - widespread impact
  - **Status**: NEEDS EXECUTION

- [ ] **Task 7: Rename main.gd to root.gd** 📋 PENDING
  - **Target**: `scripts/scene_structure/main.gd` → `scripts/root.gd`
  - **Files to update**: 33 (CRITICAL: scenes/root.tscn line 11, plus all gameplay scenes + docs)
  - **Risk**: HIGH - breaks root scene if not done correctly
  - **Status**: NEEDS CAREFUL EXECUTION

### Phase 4: Organization (Optional) 📋 PENDING

- [ ] **Task 10: Organize UI scripts** 📋 PENDING
  - **Target**: Organize 18 UI scripts into `menus/`, `overlays/`, `hud/` subdirectories
  - **Files to update**: Unknown (needs comprehensive scan)
  - **Risk**: MEDIUM - cosmetic but affects many imports
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

### Immediate (Phase 1 Completion)

**RESUME HERE**: Complete Phase 1 tasks

1. **Task 2: Move audio/image assets** (CRITICAL PATH)
   ```bash
   # Step 1: Create target directories
   mkdir -p assets/audio assets/button_prompts

   # Step 2: Move audio files (preserves git history)
   git mv resources/audio assets/audio
   git mv resources/button_prompts assets/button_prompts

   # Step 3: Update all references
   # Use find/replace commands from "Path Update Commands" section

   # Step 4: Verify critical files manually
   # Check m_audio_manager.gd, u_button_prompt_registry.gd, .tres files

   # Step 5: Test
   # Run style tests, audio tests, input tests, full suite

   # Step 6: Commit
   git add .
   git commit -m "refactor: move audio and button prompt assets to assets/ folder

   - Move resources/audio/ → assets/audio/ (100+ files)
   - Move resources/button_prompts/ → assets/button_prompts/ (80+ files)
   - Update 136 file references (scripts, scenes, resources, tests)
   - All tests passing
   "
   ```

2. **Task 3: Move prototype scenes/scripts** (LOW RISK - Quick win)
   ```bash
   # Create target directories
   mkdir -p tests/scenes/prototypes tests/prototypes

   # Move files
   git mv scenes/prototypes/* tests/scenes/prototypes/
   git mv scripts/prototypes/* tests/prototypes/

   # Check for references (should be none)
   grep -r "res://scenes/prototypes" . --include="*.gd" --include="*.tscn"
   grep -r "res://scripts/prototypes" . --include="*.gd" --include="*.tscn"

   # Commit
   git add .
   git commit -m "refactor: move prototype scenes and scripts to tests folder"
   ```

3. **Task 8: Consolidate ECS helpers** (LOW RISK - Single file)
   ```bash
   # Create target directory
   mkdir -p scripts/utils/ecs

   # Move file
   git mv scripts/ecs/helpers/u_ecs_query_metrics.gd scripts/utils/ecs/

   # Update reference in m_ecs_manager.gd
   # Find: res://scripts/ecs/helpers/u_ecs_query_metrics.gd
   # Replace: res://scripts/utils/ecs/u_ecs_query_metrics.gd

   # Test ECS subsystem
   # Run: tests/unit/ecs

   # Commit
   git add .
   git commit -m "refactor: consolidate ECS helpers to scripts/utils/ecs/"
   ```

### After Phase 1 Completion

4. Update this continuation prompt with Phase 1 completion status
5. Update `reorganization-tasks.md` checkboxes
6. Commit documentation updates separately
7. Get user approval before proceeding to Phase 2

---

## Success Criteria

Phase 1 is complete when:
- [x] Task 1: parse_test deleted
- [ ] Task 2: Audio/button prompt assets moved + all references updated + tests passing
- [ ] Task 3: Prototype scenes/scripts moved
- [ ] Task 8: ECS helpers consolidated
- [ ] All unit tests passing (1468/1473 or better)
- [ ] Style enforcement tests passing
- [ ] Scenes load successfully in Godot editor
- [ ] Documentation updated (this file + tasks file)
- [ ] Clean commits for each task

---

## Estimated Effort

- **Phase 1 remaining**: 2-3 hours (mostly Task 2 - audio/button prompt moves)
- **Phase 2**: 1-2 hours (structural changes)
- **Phase 3**: 2-3 hours (high-impact path changes)
- **Phase 4**: 1 hour (optional UI organization)
- **Total remaining**: 6-9 hours

---

## Additional Resources

- **Audit document**: `docs/general/cleanup_v4/reorganization-audit.md` - Comprehensive impact analysis
- **Tasks document**: `docs/general/cleanup_v4/reorganization-tasks.md` - Original task checklist
- **Style guide**: `docs/general/STYLE_GUIDE.md` - Prefix conventions (will need updates for `inter_` prefix)
- **Dev pitfalls**: `docs/general/DEV_PITFALLS.md` - Common issues to avoid

---

**Last Updated**: 2026-01-23
**Current Status**: Phase 1 in progress (1/4 tasks complete)
**Next Task**: Move audio/image assets to assets/ folder (Task 2)
