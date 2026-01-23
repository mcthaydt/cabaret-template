# Reorganization Audit - Full Impact Analysis

## Executive Summary

This reorganization involves **614 GDScript files**, **76 scene files**, and **hundreds of resource files**. The scope is significantly larger than initially documented. This audit identifies all affected files and the proper sequencing to avoid breaking the codebase.

---

## Impact Assessment by Task

### Task 1: Delete parse_test.gd ✅ COMPLETED
- **Files removed**: 2 (parse_test.gd, parse_test.gd.uid)
- **References**: 0 found
- **Risk**: None
- **Status**: DONE

### Task 2: Move Audio/Image Assets (HIGH RISK - 83+ files affected)

#### Files to Move
```
resources/audio/ → assets/audio/
  ├── music/ (8 files + imports)
  ├── sfx/ (10 files + imports)
  ├── footsteps/ (64 files + imports)
  └── ambient/ (2 files + imports)

resources/button_prompts/ → assets/button_prompts/
  ├── gamepad/ (56 files + imports)
  ├── keyboard/ (16 files + imports)
  └── mobile/ (6 files + imports)
```

#### Files Requiring Path Updates (83 for audio, 53 for button_prompts)

**Audio References**:
1. **GDScript Files** (2):
   - `scripts/managers/m_audio_manager.gd` - Lines 20-46 (hardcoded preloads)
   - `scripts/ecs/systems/s_ambient_sound_system.gd`

2. **Resource Files** (.tres) (6):
   - `resources/settings/victory_sound_default.tres`
   - `resources/settings/landing_sound_default.tres`
   - `resources/settings/jump_sound_default.tres`
   - `resources/settings/footstep_sound_default.tres`
   - `resources/settings/death_sound_default.tres`
   - `resources/settings/checkpoint_sound_default.tres`

3. **Import Files**: 75+ (will auto-regenerate after move)

4. **Test Files** (3):
   - `tests/unit/ecs/systems/test_footstep_sound_system.gd`
   - `tests/unit/managers/test_audio_manager.gd`
   - `tests/integration/audio/test_audio_integration.gd`

**Button Prompt References**:
1. **GDScript Files** (4):
   - `scripts/ui/u_button_prompt_registry.gd` - Lines 18-49 (hardcoded paths)
   - `scripts/ui/ui_virtual_joystick.gd`
   - `scripts/ui/ui_virtual_button.gd`
   - `scripts/utils/u_input_event_display.gd`

2. **Scene Files** (.tscn) (3):
   - `scenes/ui/ui_virtual_joystick.tscn`
   - `scenes/ui/ui_virtual_button.tscn`
   - `scenes/ui/ui_button_prompt.tscn`

3. **Import Files**: 46+ (will auto-regenerate)

4. **Test Files** (2):
   - `tests/unit/ui/test_button_prompt.gd`
   - `tests/unit/input_manager/test_u_button_prompt_registry.gd`

**Action Required**: Find/replace all occurrences of:
- `res://resources/audio/` → `res://assets/audio/`
- `res://resources/button_prompts/` → `res://assets/button_prompts/`

### Task 3: Move Prototype Scenes (LOW RISK)

#### Files to Move
```
scenes/prototypes/ → tests/scenes/prototypes/
  ├── camera_blend_test.tscn
  └── root_prototype.tscn

scenes/tmp_invalid_gameplay.tscn → tests/scenes/tmp_invalid_gameplay.tscn (if exists)
```

#### Files Requiring Updates (0)
- No references found in active code

### Task 4: Move Templates (MEDIUM RISK - 21 files affected)

#### Files to Move
```
templates/ → scenes/templates/
  ├── tmpl_base_scene.tscn
  ├── tmpl_camera.tscn
  ├── tmpl_character.tscn
  └── tmpl_character_ragdoll.tscn
```

#### Files Requiring Path Updates (21)
1. **project.godot** - main scene reference
2. **Scene Files** (.tscn) (6):
   - `scenes/prefabs/prefab_player.tscn`
   - `scenes/prefabs/prefab_player_ragdoll.tscn`
   - `scenes/gameplay/gameplay_base.tscn`
   - `scenes/gameplay/gameplay_exterior.tscn`
   - `scenes/gameplay/gameplay_interior_house.tscn`
   - `tests/scenes/test_exterior.tscn`
3. **Test Files** (.gd) (5):
   - All test files that instantiate templates
4. **Documentation** (9 files):
   - Various markdown files (low priority)

**Action Required**: Find/replace:
- `res://templates/` → `res://scenes/templates/`

### Task 5: Convert marker_surface_type to Component (LOW RISK - 4 files)

#### Files Affected
1. `scripts/ecs/markers/marker_surface_type.gd` - Delete
2. `tests/unit/ecs/systems/test_footstep_sound_system.gd` - Update
3. `tests/unit/ecs/components/test_surface_detector.gd` - Update
4. `scenes/gameplay/gameplay_exterior.tscn` - Update node type

#### Action Required
1. Create `scripts/ecs/components/c_surface_type_component.gd`
2. Update scene to use component instead of marker
3. Update tests to use component API
4. Delete marker file

### Task 6: Rename Interactable Controllers (MEDIUM RISK - unknown file count)

#### Files to Rename
```
scripts/gameplay/e_door_trigger_controller.gd → inter_door_trigger.gd
scripts/gameplay/e_checkpoint_zone.gd → inter_checkpoint_zone.gd
scripts/gameplay/e_hazard_zone.gd → inter_hazard_zone.gd
scripts/gameplay/e_victory_zone.gd → inter_victory_zone.gd
scripts/gameplay/e_signpost.gd → inter_signpost.gd
scripts/gameplay/e_endgame_goal_zone.gd → inter_endgame_goal_zone.gd (?)
```

#### Files Requiring Updates
- All gameplay scenes that use these controllers
- Tests that reference these scripts
- STYLE_GUIDE.md - Add `inter_` prefix documentation

**Action Required**: Need to grep for all references before proceeding

### Task 7: Rename main.gd to root.gd (HIGH RISK - 33 files affected)

#### File to Move
```
scripts/scene_structure/main.gd → scripts/root.gd
```

#### Files Requiring Updates (33)
1. **scenes/root.tscn** - Line 11 (CRITICAL)
2. **Scene Files** (10):
   - All gameplay scenes
   - All test scenes
   - Template scenes
3. **Documentation** (22 files):
   - AGENTS.md
   - Multiple PRD/plan/task files
   - STYLE_GUIDE.md
4. **Test Files** (unknown count)

**Action Required**: Find/replace:
- `res://scripts/scene_structure/main.gd` → `res://scripts/root.gd`

### Task 8: Consolidate Utils (LOW RISK - 1 file)

#### Files to Move
```
scripts/ecs/helpers/ → scripts/utils/ecs/
  └── u_ecs_query_metrics.gd
```

#### Files Requiring Updates (1)
- `scripts/managers/m_ecs_manager.gd` - preload statement

### Task 9: Clean up ECS Folder (HIGH RISK - 67+ files affected)

#### Files to Move
```
scripts/ecs/helpers/ → scripts/utils/ecs/
scripts/ecs/markers/ → scripts/scene_structure/ecs/
scripts/ecs/resources/ → scripts/resources/ecs/
scripts/ui/resources/ → scripts/resources/ui/
scripts/state/resources/ → scripts/resources/state/
```

#### Files Requiring Updates (67)
- 67 files reference `res://scripts/ecs/resources/`
- Multiple systems, components, tests, .tres files

**Action Required**: Find/replace:
- `res://scripts/ecs/resources/` → `res://scripts/resources/ecs/`
- `res://scripts/ui/resources/` → `res://scripts/resources/ui/`
- `res://scripts/state/resources/` → `res://scripts/resources/state/`

### Task 10: Organize UI Scripts (MEDIUM RISK)

#### Current State
UI already has partial organization:
- `scripts/ui/settings/` (3 files)
- `scripts/ui/utils/` (2 files)
- `scripts/ui/resources/` (1 file)
- `scripts/ui/` (18 files)

#### Proposed Organization
```
scripts/ui/
  ├── menus/       (main_menu, pause_menu, settings_menu, credits)
  ├── overlays/    (save_load, rebinding, gamepad_settings, touchscreen_settings)
  ├── hud/         (hud_controller, button_prompt, virtual_joystick, virtual_button)
  ├── utils/       (existing + registry, sound_player)
  └── resources/   (existing)
```

#### Action Required
- Need comprehensive scene file scan to find all UI script references

---

## Recommended Execution Order

### Phase 1: Low-Risk Moves (Independent)
1. ✅ Delete parse_test.gd (DONE)
2. Move prototype scenes (no dependencies)
3. Consolidate ECS helpers (single file)

### Phase 2: Medium-Risk Structural Changes
4. Convert marker_surface_type to component (isolated)
5. Rename interactable controllers (after full reference scan)

### Phase 3: High-Impact Path Changes (Requires Testing)
6. Move templates → scenes/templates/ (update 21 files)
7. Clean up ECS resources folder (update 67 files)
8. Rename main.gd → root.gd (update 33 files)

### Phase 4: Asset Moves (Highest Risk)
9. Move audio assets (update 83+ files)
10. Move button_prompts (update 53+ files)

### Phase 5: Organization (Optional)
11. Organize UI scripts (cosmetic, can be deferred)

---

## Critical Path Items

### Before ANY Moves
1. ✅ Commit current working tree
2. Run full test suite to establish baseline
3. Create branch for reorganization work

### After Each Major Move
1. Run style enforcement tests
2. Run affected unit tests
3. Test scene loading in Godot editor
4. Commit if green

### Path Update Strategy
Use multi-file find/replace with these patterns:
```bash
# Audio
find . -name "*.gd" -o -name "*.tres" -o -name "*.tscn" | xargs sed -i '' 's|res://resources/audio/|res://assets/audio/|g'

# Button prompts
find . -name "*.gd" -o -name "*.tres" -o -name "*.tscn" | xargs sed -i '' 's|res://resources/button_prompts/|res://assets/button_prompts/|g'

# Templates
find . -name "*.gd" -o -name "*.tres" -o -name "*.tscn" | xargs sed -i '' 's|res://templates/|res://scenes/templates/|g'

# ECS resources
find . -name "*.gd" -o -name "*.tres" -o -name "*.tscn" | xargs sed -i '' 's|res://scripts/ecs/resources/|res://scripts/resources/ecs/|g'

# Main script
find . -name "*.gd" -o -name "*.tres" -o -name "*.tscn" | xargs sed -i '' 's|res://scripts/scene_structure/main.gd|res://scripts/root.gd|g'
```

---

## Risk Assessment

| Task | Risk Level | Impact | File Count | Test Coverage |
|------|-----------|--------|------------|---------------|
| Delete parse_test | ✅ None | Low | 2 | N/A |
| Move prototypes | Low | Low | 2 | None |
| Move templates | Medium | High | 4 + 21 refs | Partial |
| Convert surface marker | Low | Low | 1 + 3 refs | Yes |
| Rename interactables | Medium | Medium | 6 + unknown refs | Yes |
| Rename main.gd | High | Critical | 1 + 33 refs | Partial |
| Consolidate utils | Low | Low | 1 + 1 ref | Yes |
| Clean ECS folder | High | High | Multiple + 67 refs | Yes |
| Move audio assets | **Critical** | **Critical** | 100+ + 83 refs | Yes |
| Move button prompts | **Critical** | **Critical** | 80+ + 53 refs | Yes |
| Organize UI | Medium | Medium | 18 files | Partial |

---

## Testing Strategy

### Pre-Move Validation
```bash
# Run full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

### Post-Move Validation
Same as above, plus:
1. Load each gameplay scene in Godot editor
2. Run gameplay test manually
3. Verify audio playback
4. Verify UI button prompts display

---

## Estimated Effort

- **Phase 1 (Low-risk)**: 15 minutes ✅ (Parse test done)
- **Phase 2 (Structural)**: 1-2 hours
- **Phase 3 (Path changes)**: 2-3 hours
- **Phase 4 (Asset moves)**: 3-4 hours (includes testing)
- **Phase 5 (UI org)**: 1 hour

**Total**: 7-10 hours of careful, systematic work with testing between each phase.

---

## Rollback Plan

1. Use git to track each phase separately
2. Commit after each successful phase
3. If tests fail, `git reset --hard` to last good commit
4. Re-evaluate approach before retrying

---

## Open Questions

1. Should we move `scripts/prototypes/` to tests as well? (Found in file scan)
2. Is `e_endgame_goal_zone.gd` an interactable that needs renaming?
3. Should UI organization create new subdirs or use existing ones?
4. Are there .import files we need to manually update, or will Godot regenerate all?
5. Should we update documentation references in Phase 1 or save for end?
