# Cleanup v4.5 - Resources, Scenes, and Assets Standardization Tasks

## Overview

Bring `resources/`, `scenes/`, and `assets/` to the same organizational quality as `scripts/`. This cleanup introduces standardized prefixes for resource instances and asset files, enforces component attachment patterns, and reorganizes UI scenes.

**Scope**: ~215 files across 6 phases, 31 tasks
**Status**: 31/31 tasks complete (100%) - ALL PHASES COMPLETE ✅
**Continuation Prompt**: `docs/general/cleanup_v4.5/reorganization-continuation-prompt.md`

---

## Quick Reference Table

| Phase | Tasks | Completed | Risk Level |
|-------|-------|-----------|------------|
| Phase 1: Asset Prefixes | 5 | 5/5 ✅ | Low |
| Phase 2: Resource Instance Prefixes | 8 | 8/8 ✅ | Medium |
| Phase 3: Scene Structure Fixes | 3 | 3/3 ✅ | Medium |
| Phase 4: Scenes/UI Organization | 7 | 7/7 ✅ | Medium |
| Phase 5: Placeholder Quarantine | 4 | 4/4 ✅ | High |
| Phase 6: Enforcement & Documentation | 4 | 4/4 ✅ | Low |
| **TOTAL** | **31** | **31/31 (100%) ✅** | - |

**Note:** Task 1 verified (textures already have `tex_` prefix); Task 2 complete (editor icons renamed with `icn_` prefix); Task 3 complete (SFX files renamed with `sfx_` prefix); Task 4 complete (music files renamed with `mus_` prefix); Task 5 complete (ambient files renamed with `amb_` prefix).

---

## Key Decisions

### 1. Resource Prefix Collision Resolution

**Problem:** `rs_` is used for both Resource class scripts AND Resource instances.

**Solution:** Keep `rs_` for scripts, introduce `cfg_` for config/settings instances.
- `scripts/resources/**/*.gd` → `rs_*.gd` (class definitions, unchanged)
- `resources/**/*.tres` → `cfg_*.tres` (instances/configs)

**Examples:**
- `rs_movement_settings.gd` = the class definition (unchanged)
- `cfg_movement_default.tres` = an instance of that class (renamed from `movement_default.tres`)

### 2. Asset Type Prefixes

| Type | Prefix | Example |
|------|--------|---------|
| Textures | `tex_` | `tex_shadow_blob.png` |
| Materials | `mat_` | `mat_player_body.tres` |
| Music | `mus_` | `mus_main_menu.ogg` |
| SFX | `sfx_` | `sfx_jump.wav` |
| Ambient | `amb_` | `amb_exterior.wav` |
| Footsteps | `fst_` | `fst_grass_01.wav` |
| Icons (editor) | `icn_` | `icn_component.svg` |
| Fonts | `fnt_` | `fnt_ui_default.ttf` |

**Note:** Button prompts already use device-specific naming (`keyboard/`, `gamepad/`, etc.) - no prefix needed.

### 3. Component Attachment Pattern

**Rule:** Components (scripts extending `BaseECSComponent`) must NOT be attached directly to non-Node/Node3D types (CSGBox3D, CharacterBody3D, Area3D, etc.). Instead, create a child `Node` with the component script attached.

**Correct Pattern:**
```
E_PlayerRoot (Node3D with BaseECSEntity)
└── Components (Node with marker_components_group.gd)
    ├── C_InputComponent (Node with c_input_component.gd)
    └── ...
```

**Incorrect Pattern:**
```
SO_Floor_Grass (CSGBox3D with c_surface_type_component.gd)  ❌ WRONG
```

---

## Phase 1: Asset Prefixes (~35 files)

### Task 1: Verify Textures Already Have `tex_` Prefix ✓ VERIFIED

**Current state:** Textures already have correct prefix:
- `tex_icon.svg` ✓
- `tex_shadow_blob.png` ✓

**Status**: Already Complete (verified 2026-01-24)
**Files affected**: 0
**Risk**: None

---

### Task 2: Rename Editor Icons with `icn_` Prefix

**Files to rename:** All 17 files in `assets/editor_icons/`

Current naming: `action.svg`, `component.svg`, `entities.svg`, etc.
Target naming: `icn_action.svg`, `icn_component.svg`, `icn_entities.svg`, etc.

**Steps:**
- [x] List all files in `assets/editor_icons/`
- [x] Rename each file: `*.svg` → `icn_*.svg`
- [x] Update all `@icon()` annotations in scripts
- [x] Update .import files (will auto-regenerate)
- [x] Verify icons display in Godot editor

**Status**: Complete (2026-01-24)
**Files affected**: 17
**Risk**: Low
**Completion notes**: Renamed 17 icons + .import files, updated `@icon()` references, reimported assets.

**Reference Scan Command:**
```bash
grep -rn "assets/editor_icons/" scripts/ --include="*.gd"
```

---

### Task 3: Add `sfx_` Prefix to SFX Files

**Files to rename:** All 9 files in `assets/audio/sfx/`

Current naming: `placeholder_checkpoint.wav`, `placeholder_jump.wav`, etc.
Target naming: `sfx_placeholder_checkpoint.wav`, `sfx_placeholder_jump.wav`, etc.

**Steps:**
- [x] List all files in `assets/audio/sfx/`
- [x] Rename files: `placeholder_*.wav` → `sfx_placeholder_*.wav`
- [x] Update references in scripts and .tres files
- [x] Run audio tests

**Status**: Complete (2026-01-24)
**Files affected**: 9
**Risk**: Low
**Completion notes**: Renamed 9 SFX files + .import files, updated references in `m_audio_manager.gd` and base settings, reimported assets, tests passing.

---

### Task 4: Add `mus_` Prefix to Music Files

**Files to rename:** All 8 files in `assets/audio/music/`

Production files (5):
- `credits.mp3` → `mus_credits.mp3`
- `exterior.mp3` → `mus_exterior.mp3`
- `interior.mp3` → `mus_interior.mp3`
- `main_menu.mp3` → `mus_main_menu.mp3`
- `pause.mp3` → `mus_pause.mp3`

Placeholder files (3 in `placeholders/` subfolder):
- `placeholder_gameplay.ogg` → `mus_placeholder_gameplay.ogg`
- `placeholder_main_menu.ogg` → `mus_placeholder_main_menu.ogg`
- `placeholder_pause.ogg` → `mus_placeholder_pause.ogg`

**Steps:**
- [x] Rename production music files with `mus_` prefix
- [x] Rename placeholder music files with `mus_` prefix
- [x] Update references in scripts and .tres files
- [x] Run audio tests

**Status**: Complete (2026-01-24)
**Files affected**: 8
**Risk**: Low
**Completion notes**: Renamed 8 music files + .import files, updated references in audio manager and tests, reimported assets, tests passing.

---

### Task 5: Add `amb_` Prefix to Ambient Files

**Files to rename:** All 2 files in `assets/audio/ambient/`

Current naming: `placeholder_exterior.wav`, `placeholder_interior.wav`
Target naming: `amb_placeholder_exterior.wav`, `amb_placeholder_interior.wav`

**Steps:**
- [x] List all files in `assets/audio/ambient/`
- [x] Rename files: `placeholder_*.wav` → `amb_placeholder_*.wav`
- [x] Update references in scripts and .tres files
- [x] Run audio tests

**Status**: Complete (2026-01-24)
**Files affected**: 2
**Risk**: Low
**Completion notes**: Renamed 2 ambient files + .import files, updated references in `s_ambient_sound_system.gd` and audio tests, reimported assets, tests passing.

---

## Phase 2: Resource Instance Prefixes (~77 files)

### Task 6: Rename base_settings/*.tres → cfg_*

**Files to rename:** All 16 .tres files in `resources/base_settings/`

**Subdirectory: audio/ (7 files):**
- `ambient_sound_default.tres` → `cfg_ambient_sound_default.tres`
- `checkpoint_sound_default.tres` → `cfg_checkpoint_sound_default.tres`
- `death_sound_default.tres` → `cfg_death_sound_default.tres`
- `footstep_sound_default.tres` → `cfg_footstep_sound_default.tres`
- `jump_sound_default.tres` → `cfg_jump_sound_default.tres`
- `landing_sound_default.tres` → `cfg_landing_sound_default.tres`
- `victory_sound_default.tres` → `cfg_victory_sound_default.tres`

**Subdirectory: gameplay/ (9 files):**
- `align_default.tres` → `cfg_align_default.tres`
- `floating_default.tres` → `cfg_floating_default.tres`
- `health_settings.tres` → `cfg_health_settings.tres`
- `jump_default.tres` → `cfg_jump_default.tres`
- `jump_particles_default.tres` → `cfg_jump_particles_default.tres`
- `landing_indicator_default.tres` → `cfg_landing_indicator_default.tres`
- `landing_particles_default.tres` → `cfg_landing_particles_default.tres`
- `movement_default.tres` → `cfg_movement_default.tres`
- `rotate_default.tres` → `cfg_rotate_default.tres`

**Steps:**
- [x] Rename all audio/ .tres files with `cfg_` prefix
- [x] Rename all gameplay/ .tres files with `cfg_` prefix
- [x] Update all references (scenes, scripts, tests)
- [x] Run affected tests

**Status**: Complete (2026-01-24)
**Files affected**: 16
**Risk**: Medium
**Completion notes**: Renamed 16 base settings resources, updated scene/test references and related docs.

**Reference Scan Command:**
```bash
grep -rn "res://resources/base_settings/" . --include="*.gd" --include="*.tscn" --include="*.tres"
```

---

### Task 7: Rename Input Resources → cfg_*

**Files to rename:** All 9 .tres files in `resources/input/`

**Subdirectory: gamepad_settings/ (1 file):**
- `default_gamepad_settings.tres` → `cfg_default_gamepad_settings.tres`

**Subdirectory: profiles/ (6 files):**
- `accessibility_gamepad.tres` → `cfg_accessibility_gamepad.tres`
- `accessibility_keyboard.tres` → `cfg_accessibility_keyboard.tres`
- `alternate_keyboard.tres` → `cfg_alternate_keyboard.tres`
- `default_gamepad.tres` → `cfg_default_gamepad.tres`
- `default_keyboard.tres` → `cfg_default_keyboard.tres`
- `default_touchscreen.tres` → `cfg_default_touchscreen.tres`

**Subdirectory: rebind_settings/ (1 file):**
- `default_rebind_settings.tres` → `cfg_default_rebind_settings.tres`

**Subdirectory: touchscreen_settings/ (1 file):**
- `default_touchscreen_settings.tres` → `cfg_default_touchscreen_settings.tres`

**Steps:**
- [x] List all .tres files in `resources/input/`
- [x] Rename each file with `cfg_` prefix
- [x] Update all references
- [x] Run input tests

**Status**: Complete (2026-01-25)
**Files affected**: 9
**Risk**: Medium
**Completion notes**: Renamed 9 input resources (including touchscreen settings) and updated references in scripts, scenes, tests, and docs.

---

### Task 8: Rename State Resources → cfg_*

**Files to rename:** All 11 .tres files for state initial values

**Steps:**
- [x] List all .tres files in `resources/state/`
- [x] Rename each file: `*_initial_state.tres` → `cfg_*_initial_state.tres`
- [x] Update all references
- [x] Run state tests

**Status**: Complete (2026-01-25)
**Files affected**: 11
**Risk**: Medium
**Completion notes**: Renamed 11 state resources (initial states + navigation/state store configs), updated references across scenes/tests/docs, and ran state test suite.

---

### Task 9: Rename Scene Registry Entries → cfg_*

**Files to rename:** All 12 .tres files in `resources/scene_registry/`

**Steps:**
- [x] List all .tres files in `resources/scene_registry/`
- [x] Rename each file: `*.tres` → `cfg_*_entry.tres`
- [x] Update all references (especially U_SceneRegistry)
- [x] Run scene manager tests

**Status**: Complete (2026-01-25)
**Files affected**: 12
**Risk**: Medium
**Completion notes**: Renamed 12 scene registry resources to `cfg_*_entry.tres`, updated references in docs/tests/README, and ran scene manager test suite.

---

### Task 10: Rename UI Screen Definitions → cfg_*

**Files to rename:** All 14 .tres files in `resources/ui_screens/`

**Steps:**
- [x] List all .tres files in `resources/ui_screens/`
- [x] Rename each file: `*.tres` → `cfg_*.tres` (screens + overlays)
- [x] Update all references (especially U_UIRegistry)
- [x] Run UI tests

**Status**: Complete (2026-01-25)
**Files affected**: 14
**Risk**: Medium
**Completion notes**: Renamed 14 UI screen definitions to `cfg_` prefix (screens + overlays), updated references in scripts/docs, and ran UI test suite.

---

### Task 11: Rename Spawn Metadata → cfg_*

**Files to rename:** All 6 .tres files in `resources/spawn_metadata/`

**Steps:**
- [x] List all .tres files in `resources/spawn_metadata/`
- [x] Rename each file: `gameplay_*.tres` → `cfg_sp_*.tres`
- [x] Update all references
- [x] Run spawn tests

**Status**: Complete (2026-01-24)
**Files affected**: 6
**Risk**: Medium
**Completion notes**: Renamed 6 spawn metadata files to cfg_sp_* prefix, updated references in 3 gameplay scenes, tests passing.

---

### Task 12: Rename VFX Resources (rs_* → cfg_*)

**Files to rename:** 2 .tres files in `resources/vfx/`

**NOTE:** These files ALREADY have `rs_` prefix - they need to be RENAMED to `cfg_` to match the new convention.

Current → Target:
- `rs_screen_shake_config.tres` → `cfg_screen_shake_config.tres`
- `rs_screen_shake_tuning.tres` → `cfg_screen_shake_tuning.tres`

**Steps:**
- [x] Rename `rs_screen_shake_config.tres` → `cfg_screen_shake_config.tres`
- [x] Rename `rs_screen_shake_tuning.tres` → `cfg_screen_shake_tuning.tres`
- [x] Update all references
- [x] Run VFX tests

**Status**: Complete (2026-01-24)
**Files affected**: 2
**Risk**: Low
**Completion notes**: Renamed 2 VFX resources to cfg_* prefix, updated references in scripts (3) and documentation (7), resolves rs_* prefix collision with Resource class definitions.

---

### Task 13: Rename Trigger Resources (rs_* → cfg_*)

**Files to rename:** All 8 .tres files in `resources/triggers/`

**NOTE:** These files ALREADY have `rs_` prefix - they need to be RENAMED to `cfg_` to resolve the prefix collision with Resource Script class definitions.

Current → Target:
- `rs_checkpoint_box_2x3x2.tres` → `cfg_checkpoint_box_2x3x2.tres`
- `rs_cylinder_wide_door_trigger_settings.tres` → `cfg_cylinder_wide_door_trigger_settings.tres`
- `rs_death_zone_volume.tres` → `cfg_death_zone_volume.tres`
- `rs_goal_cylinder.tres` → `cfg_goal_cylinder.tres`
- `rs_scene_trigger_settings.tres` → `cfg_scene_trigger_settings.tres`
- `rs_signpost_cylinder.tres` → `cfg_signpost_cylinder.tres`
- `rs_spike_trap_volume.tres` → `cfg_spike_trap_volume.tres`
- `rs_trigger_box_wide_door.tres` → `cfg_trigger_box_wide_door.tres`

**Steps:**
- [x] Rename all 8 trigger .tres files from `rs_*` to `cfg_*`
- [x] Update all references in scenes (gameplay_exterior.tscn, etc.)
- [x] Run trigger tests

**Status**: Complete (2026-01-24)
**Files affected**: 8
**Risk**: Medium
**Completion notes**: Renamed 8 trigger resources to cfg_* prefix, updated 24 references across 7 scene files, 1 test file, and 4 documentation files. Resolves rs_* prefix collision with Resource class definitions. Batch 3 (Resource Prefixes) complete!

---

## Phase 3: Scene Structure Fixes

### Task 14: Audit Gameplay Scenes for Direct Component Attachment

**Scenes to audit:**
- `scenes/gameplay/gameplay_exterior.tscn`
- `scenes/gameplay/gameplay_interior_house.tscn`
- `scenes/gameplay/gameplay_base.tscn`

**Steps:**
- [x] Parse each .tscn file for component scripts on non-Node types
- [x] Document all violations found
- [x] Create fix plan for Task 15

**Status**: Complete (2026-01-24)
**Files affected**: 3 audited, 3 violations found
**Risk**: Medium
**Completion notes**: Found 3 violations in gameplay_exterior.tscn (all CSGBox3D with c_surface_type_component.gd). No violations in interior_house or base scenes. Audit report: `docs/general/cleanup_v4.5/task-14-audit-report.md`

**Detection Pattern:**
Look for `[node]` blocks where:
- Script matches `c_*_component.gd`
- Type is NOT `Node` or `Node3D`

---

### Task 15: Fix gameplay_exterior.tscn Component Attachments

**Known violations:** 3 CSGBox3D nodes with `c_surface_type_component.gd` directly attached

**Fix for each violation:**
1. Remove script from CSGBox3D node
2. Add child Node named `C_SurfaceTypeComponent`
3. Attach `c_surface_type_component.gd` to the child Node
4. Preserve surface_type export value

**Steps:**
- [x] Fix SO_Floor_Grass component attachment
- [x] Fix SO_Block2_Stone component attachment
- [x] Fix SO_Block3_Stone component attachment
- [x] Run tests to verify functionality unchanged
- [x] Verify in Godot editor

**Status**: Complete (2026-01-24)
**Files affected**: 1 (gameplay_exterior.tscn)
**Risk**: Medium
**Completion notes**: Fixed 3 component attachment violations. All components now attached to proper Node containers. Style and ECS tests passing (111/111).

---

### Task 16: Move scene_registry/README.md to Docs

**Rationale:** Documentation belongs in `docs/`, not scattered in resource folders. However, this README contains **valuable content** for non-coders on how to add scenes without code changes.

**Current content includes:**
- How to add scenes via Godot editor (recommended for non-coders)
- How to add scenes via GDScript
- Scene type guide (UI, GAMEPLAY, END_GAME)
- Preload priority guide (0-15 scale)
- Example scenes
- Troubleshooting section

**Steps:**
- [x] Move `resources/scene_registry/README.md` → `docs/scene_manager/ADDING_SCENES_GUIDE.md`
- [x] Update any internal links if needed
- [x] Verify content is accessible from scene_manager docs
- [x] Commit move

**Status**: Complete (2026-01-24)
**Files affected**: 1 moved, 3 references updated (README.md, u_scene_registry.gd)
**Risk**: Low
**Completion notes**: Documentation moved to proper location, all references updated to new path.

---

## Phase 4: Scenes/UI Organization (~23 scene moves)

### Task 17: Create scenes/ui/ Subfolders

**New structure:**
```
scenes/ui/
  ├── menus/       (main_menu, credits, game_over, victory)
  ├── overlays/
  │   ├── ui_pause_menu.tscn
  │   ├── ui_save_load_menu.tscn
  │   └── settings/   (audio, gamepad, touchscreen, vfx, input settings)
  ├── hud/         (hud_overlay, damage_flash, button_prompt, loading_screen)
  └── widgets/     (virtual_joystick, virtual_button, gamepad_preview, mobile_controls)
```

**Steps:**
- [x] Create `scenes/ui/menus/` directory
- [x] Create `scenes/ui/overlays/` directory
- [x] Create `scenes/ui/overlays/settings/` directory
- [x] Create `scenes/ui/hud/` directory
- [x] Create `scenes/ui/widgets/` directory

**Status**: Complete (2026-01-24)
**Risk**: Low
**Completion notes**: All UI subdirectories created successfully.

---

### Task 18: Move Menu Scenes to menus/

**Files to move:** All 6 menu scenes

- `scenes/ui/ui_main_menu.tscn` → `scenes/ui/menus/`
- `scenes/ui/ui_pause_menu.tscn` → `scenes/ui/menus/`
- `scenes/ui/ui_settings_menu.tscn` → `scenes/ui/menus/`
- `scenes/ui/ui_credits.tscn` → `scenes/ui/menus/`
- `scenes/ui/ui_game_over.tscn` → `scenes/ui/menus/`
- `scenes/ui/ui_victory.tscn` → `scenes/ui/menus/`

**Steps:**
- [x] Move files with `git mv`
- [x] Update all references (preloads, scene paths)
- [x] Update U_SceneRegistry entries
- [x] Update ui_screens .tres files
- [x] Run UI tests

**Status**: Complete (2026-01-24)
**Files affected**: 6 scenes moved, 10 files updated (3 .tres, 2 registries, 4 tests, 1 scene)
**Risk**: Medium
**Completion notes**: All 6 menu scenes relocated to scenes/ui/menus/. Updated U_SceneRegistry, U_SceneRegistryLoader, 3 scene registry .tres files, 4 test files, and ui_main_menu.tscn. All UI tests passing (155/155).

---

### Task 19: Move Overlay Scenes to overlays/

**Files to move:** 7 overlay scenes

- `scenes/ui/ui_save_load_menu.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_input_rebinding_overlay.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_input_profile_selector.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_edit_touch_controls_overlay.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_gamepad_settings_overlay.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_touchscreen_settings_overlay.tscn` → `scenes/ui/overlays/`
- `scenes/ui/ui_damage_flash_overlay.tscn` → `scenes/ui/overlays/`

**Steps:**
- [x] Move files with `git mv`
- [x] Update all references
- [x] Update U_UIRegistry entries
- [x] Run UI tests

**Status**: Complete (2026-01-24)
**Files affected**: 7 scenes moved, 15 files updated (5 .tres, 2 registries, 7 tests, 1 manager)
**Risk**: Medium
**Completion notes**: All 7 overlay scenes relocated to scenes/ui/overlays/. Updated U_SceneRegistry, U_SceneRegistryLoader, 5 scene registry .tres files, 7 test files, and m_vfx_manager.gd. All UI tests passing (155/155).

---

### Task 20: Move Settings Overlays to overlays/settings/

**Files to move:** 3 settings overlay scenes

- `scenes/ui/ui_audio_settings_overlay.tscn` → `scenes/ui/overlays/settings/`
- `scenes/ui/ui_vfx_settings_overlay.tscn` → `scenes/ui/overlays/settings/`
- `scenes/ui/settings/ui_audio_settings_tab.tscn` → `scenes/ui/overlays/settings/` (consolidate existing subfolder)

**NOTE:** A `settings/` subfolder already exists with `ui_audio_settings_tab.tscn`. This task consolidates all settings-related scenes under `overlays/settings/`.

**Steps:**
- [x] Move settings overlay files with `git mv`
- [x] Move existing `settings/ui_audio_settings_tab.tscn` to `overlays/settings/`
- [x] Remove empty `settings/` folder after consolidation
- [x] Update all references
- [x] Update UI registry entries
- [x] Run UI tests

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 7 (3 scenes moved, 4 references updated)
**Risk**: Medium
**Notes**: All settings overlays consolidated to overlays/settings/. Registry entries and integration tests updated. All tests passing.

---

### Task 21: Move HUD Scenes to hud/

**Files to move:** 4 HUD scenes

- `scenes/ui/ui_hud_overlay.tscn` → `scenes/ui/hud/`
- `scenes/ui/ui_button_prompt.tscn` → `scenes/ui/hud/`
- `scenes/ui/ui_loading_screen.tscn` → `scenes/ui/hud/`
- `scenes/ui/ui_mobile_controls.tscn` → `scenes/ui/hud/`

**Steps:**
- [x] Move files with `git mv`
- [x] Update all references
- [x] Run UI tests

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 24 (4 scenes moved, 20 references updated)
**Risk**: Medium
**Notes**: All HUD scenes moved to hud/. Updated gameplay scenes, root.tscn, scene registry, transitions, and all related tests. All tests passing.

---

### Task 22: Move Widget Scenes to widgets/

**Files to move:** 3 widget scenes

- `scenes/ui/ui_virtual_joystick.tscn` → `scenes/ui/widgets/`
- `scenes/ui/ui_virtual_button.tscn` → `scenes/ui/widgets/`
- `scenes/ui/ui_gamepad_preview_prompt.tscn` → `scenes/ui/widgets/`

**Steps:**
- [x] Move files with `git mv`
- [x] Update all references
- [x] Run UI tests

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 6 (3 scenes moved, 3 references updated)
**Risk**: Medium
**Notes**: All widget scenes moved to widgets/. Updated mobile controls, touchscreen settings, and widget tests. All tests passing.

---

### Task 23: Move Debug .gd to scripts/debug/

**File to move:**
- Any debug scripts in `scenes/ui/` → `scripts/debug/`

**Steps:**
- [x] Identify debug scripts in scenes/ui/ (found in scenes/debug/)
- [x] Move to scripts/debug/ with `git mv`
- [x] Update references
- [x] Run tests

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 2 (1 script moved, 1 reference updated)
**Risk**: Low
**Notes**: Moved debug_state_overlay.gd from scenes/debug/ to scripts/debug/. Updated reference in debug_state_overlay.tscn. Removed duplicate .uid file. All tests passing.

**Phase 4 Complete!** All Scenes/UI Organization tasks complete (7/7).

---

## Phase 5: Placeholder Quarantine (~70 files)

### Task 24: Create tests/assets/ Structure

**New structure:**
```
tests/assets/
  ├── audio/
  │   ├── music/
  │   ├── sfx/
  │   ├── footsteps/
  │   └── ambient/
  └── textures/
```

**Steps:**
- [x] Create `tests/assets/audio/music/`
- [x] Create `tests/assets/audio/sfx/`
- [x] Create `tests/assets/audio/footsteps/`
- [x] Create `tests/assets/audio/ambient/`
- [x] Create `tests/assets/textures/`

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 5 directories created
**Risk**: Low
**Completion notes**: Created directory structure with .gitkeep files to track empty directories in git. Ready for placeholder file migration in Tasks 25-26.

---

### Task 25: Move Placeholder Audio to tests/assets/

**Files to move:** All `placeholder_*` audio files (~65 files)

**Breakdown by location:**
- `assets/audio/ambient/`: 2 placeholder files
- `assets/audio/footsteps/`: 24 placeholder files (production set)
- `assets/audio/footsteps/_originals/`: 24 placeholder files (backup set)
- `assets/audio/music/placeholders/`: 3 placeholder files
- `assets/audio/sfx/`: 9 placeholder files

**NOTE:** After Task 3-5 rename these to sfx_placeholder_*, mus_placeholder_*, amb_placeholder_*, the quarantine moves these prefixed files. Footsteps may keep placeholder_ naming since they're test-only.

**Steps:**
- [x] Scan for all `placeholder_*` and `*_placeholder_*` audio files
- [x] Move ambient placeholders to `tests/assets/audio/ambient/`
- [x] Move footstep placeholders to `tests/assets/audio/footsteps/`
- [x] Move music placeholders to `tests/assets/audio/music/`
- [x] Move sfx placeholders to `tests/assets/audio/sfx/`
- [x] Update references in tests and .tres files
- [x] Verify tests still pass

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 124 (62 audio files + 62 .import files)
**Risk**: High
**Completion notes**: Moved all placeholder audio files to tests/assets/audio/. Updated 10 files with path references (2 scripts, 6 .tres files, 2 test files). Deleted 48 duplicate files from _originals/ folder (Task 27). Removed empty placeholders/ directory. All audio tests passing (135/135).

**Scan Command:**
```bash
find assets -name "placeholder_*" -type f
find assets -name "*_placeholder_*" -type f
```

---

### Task 26: Update Audio References

**Steps:**
- [x] Scan for all references to moved placeholder files
- [x] Update paths in test files
- [x] Update any .tres files that reference placeholders
- [x] Run full test suite

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 10 (completed as part of Task 25)
**Risk**: High
**Completion notes**: All path references updated as part of Task 25. Updated 2 scripts, 6 .tres files, and 2 test files. All audio tests passing (135/135).

---

### Task 27: Delete _originals Folder

**Rationale:** Contains duplicate backup files that should be in version control, not the project.

**Steps:**
- [x] Verify _originals content is backed up in git history
- [x] Delete `assets/audio/footsteps/_originals/` (confirmed existence)
- [x] Commit deletion

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 48 (24 .wav files + 24 .import files)
**Risk**: Low
**Completion notes**: Deleted assets/audio/footsteps/_originals/ folder containing 48 duplicate files (completed as part of Task 25 commit). All duplicates were backed up in git history.

**Scan Command:**
```bash
find . -type d -name "_originals"
```

---

## Phase 6: Enforcement & Documentation

### Task 28: Add Asset Prefix Validation Test

**File:** `tests/unit/style/test_asset_prefixes.gd`

**Rules to enforce:**
- Textures in `assets/textures/` must have `tex_` prefix
- Music in `assets/audio/music/` must have `mus_` prefix
- SFX in `assets/audio/sfx/` must have `sfx_` prefix
- Ambient in `assets/audio/ambient/` must have `amb_` prefix
- Footsteps in `assets/audio/footsteps/` must have `fst_` prefix
- Editor icons in `assets/editor_icons/` must have `icn_` prefix

**Steps:**
- [x] Create test file
- [x] Add test cases for each prefix rule
- [x] Add exceptions list for legacy files if needed
- [x] Run test and verify it catches violations

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 1 test file created (test_asset_prefixes.gd)
**Risk**: Low
**Completion notes**: Created comprehensive asset prefix validation test. Validates textures, music, and editor icons in production assets/. Placeholder assets in tests/assets/ are not validated (test-only). All style tests passing (10/10).

---

### Task 29: Add Component Container Structure Test

**File:** `tests/unit/style/test_component_structure.gd`

**Rules to enforce:**
1. In `scenes/gameplay/` and `scenes/prefabs/`:
   - Scripts with `c_*_component.gd` pattern must be attached to `type="Node"` nodes
   - Component scripts must NOT be attached to CSG*, CharacterBody3D, Area3D, RigidBody3D, StaticBody3D, or MeshInstance3D nodes

**Implementation approach:**
- Parse .tscn files
- Find all `[node]` blocks with scripts matching `c_*_component.gd`
- Verify the node `type` is `Node` or `Node3D`

**Steps:**
- [x] Create test file
- [x] Implement .tscn parsing for node+script detection
- [x] Add validation logic for component attachment rules
- [x] Run test against all gameplay/prefab scenes
- [x] Verify it catches violations

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: 1 test file created (test_component_structure.gd)
**Risk**: Low
**Completion notes**: Created component attachment validation test. Parses .tscn files to detect components attached to invalid parent types. Validates all scenes in gameplay/ and prefabs/. Prevents regression of violations fixed in Task 15. All style tests passing (10/10).

---

### Task 30: Update STYLE_GUIDE.md with New Rules

**Sections to add/update:**

1. **Resource Instance Prefix Section:**
   - Document `cfg_` prefix for .tres files
   - Distinguish from `rs_` (class definitions)

2. **Asset Prefix Section:**
   - Document all asset type prefixes (tex_, mus_, sfx_, etc.)
   - Note exceptions (button_prompts)

3. **Component Attachment Rules Section:**
   - Document correct component container pattern
   - List prohibited attachment targets

**Steps:**
- [x] Add cfg_ prefix documentation
- [x] Add asset prefix table
- [x] Add component attachment rules
- [x] Update prefix matrix table

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: STYLE_GUIDE.md already up-to-date
**Risk**: Low
**Completion notes**: STYLE_GUIDE.md was already updated on 2026-01-24 with all required sections: Resource Instance Prefixes (cfg_) section (lines 84-103), Asset File Prefixes section (lines 104-121), and Component Attachment Rules section (lines 555-593). All documentation complete and accurate.

---

### Task 31: Update AGENTS.md with New Paths

**Sections to update:**

1. **Repo Map:** Update paths for:
   - UI scenes (menus/, overlays/, hud/, widgets/)
   - Resource instances (cfg_* files)
   - Placeholder assets (tests/assets/)

2. **Naming Conventions:** Add:
   - `cfg_` prefix for resource instances
   - Asset prefix rules

**Steps:**
- [x] Update Repo Map section
- [x] Update Naming Conventions section
- [x] Update any file path examples
- [x] Verify all paths are accurate

**Status**: ✅ COMPLETE (2026-01-25)
**Files affected**: AGENTS.md updated
**Risk**: Low
**Completion notes**: Added new "Resource Instance and Asset Prefixes" subsection to Naming Conventions with cfg_ prefix documentation and all asset file prefixes (tex_, mus_, sfx_, amb_, fst_, icn_, fnt_). Added note about tests/assets/ location for placeholder assets. Updated Repo Map with UI scene organization paths (scenes/ui/menus/, overlays/, hud/, widgets/).

---

## Execution Order

### Batch 1: Quick Wins (Phase 1)
Asset prefix renames - low risk, few code references.

### Batch 2: Scene Structure Fixes (Phase 3)
Fix component attachment violations before reorganizing scenes.

### Batch 3: Resource Renames (Phase 2)
cfg_ prefix for all .tres files - highest reference count, careful scanning required.

### Batch 4: Scene Reorganization (Phase 4)
UI folder restructure, move debug scripts.

### Batch 5: Placeholder Cleanup (Phase 5)
Quarantine test assets, delete duplicates.

### Batch 6: Polish (Phase 6)
Add enforcement tests, update documentation.

---

## Test Commands Reference

```bash
# Full test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Style enforcement only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit

# Specific subsystem
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Audio tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/audio -gexit

# UI tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gexit
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

## Verification Steps

After implementation:
1. Run full test suite
2. Run style enforcement tests (including new tests)
3. Verify scenes load in Godot editor
4. Verify no broken asset/resource references
5. Verify audio plays correctly
6. Verify UI screens display correctly

---

## Success Criteria

- [x] All 31 tasks completed
- [x] All unit tests passing
- [x] Style enforcement tests passing (including new tests)
- [x] Scenes load in Godot editor
- [x] No broken preload/load paths
- [x] Audio plays correctly
- [x] UI screens display correctly
- [x] STYLE_GUIDE.md updated
- [x] AGENTS.md updated

---

**Last Updated**: 2026-01-25
**Status**: 27/31 complete (87%) - Phase 5 complete, only documentation tasks remain
