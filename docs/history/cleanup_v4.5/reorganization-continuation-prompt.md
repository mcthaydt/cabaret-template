# Cleanup v4.5 Continuation Prompt

## Context

**Goal**: Standardize `resources/`, `scenes/`, and `assets/` to match `scripts/` organization quality.
**Scope**: ~212 files across 6 phases, 31 tasks.

---

## Read First

1. `docs/general/DEV_PITFALLS.md`
2. `docs/general/STYLE_GUIDE.md`
3. `docs/general/cleanup_v4.5/reorganization-tasks.md` (primary reference - all details)

---

## Current Status

- **Phase**: ALL PHASES COMPLETE ✅
- **Completed**: 31/31 (100%)
- **Status**: Cleanup v4.5 COMPLETE

---

## Resume Here

**Task 1**: ✅ VERIFIED COMPLETE - Textures already have `tex_` prefix
**Task 2**: ✅ COMPLETE - Editor icons renamed with `icn_` prefix (17 files)
**Task 3**: ✅ COMPLETE - SFX files renamed with `sfx_` prefix (9 files)
**Task 4**: ✅ COMPLETE - Music files renamed with `mus_` prefix (8 files)
**Task 5**: ✅ COMPLETE - Ambient files renamed with `amb_` prefix (2 files)
**Task 6**: ✅ COMPLETE - Rename base_settings/*.tres → cfg_* (16 files)
**Task 7**: ✅ COMPLETE - Rename input/*.tres → cfg_* (9 files)
**Task 8**: ✅ COMPLETE - Rename state/*.tres → cfg_* (11 files)
**Task 9**: ✅ COMPLETE - Rename scene_registry/*.tres → cfg_*_entry (12 files)
**Task 10**: ✅ COMPLETE - Rename ui_screens/*.tres → cfg_* (14 files)
**Task 11**: ✅ COMPLETE - Rename spawn_metadata/*.tres → cfg_sp_* (6 files)
**Task 12**: ✅ COMPLETE - Rename vfx/*.tres → cfg_* (2 files)
**Task 13**: ✅ COMPLETE - Rename triggers/*.tres → cfg_* (8 files)
**Task 14**: ✅ COMPLETE - Audit gameplay scenes for component violations (3 violations found)
**Task 15**: ✅ COMPLETE - Fix component attachments in gameplay_exterior.tscn (3 fixed)
**Task 16**: ✅ COMPLETE - Move scene_registry/README.md to docs (3 refs updated)
**Task 17**: ✅ COMPLETE - Create scenes/ui/ subfolders (5 directories)
**Task 18**: ✅ COMPLETE - Move menu scenes to menus/ (6 scenes, 10 refs updated)
**Task 19**: ✅ COMPLETE - Move overlay scenes to overlays/ (7 scenes, 15 refs updated)
**Task 20**: ✅ COMPLETE - Move settings overlays to overlays/settings/ (3 scenes, 7 files updated)
**Task 21**: ✅ COMPLETE - Move HUD scenes to hud/ (4 scenes, 20 refs updated)
**Task 22**: ✅ COMPLETE - Move widget scenes to widgets/ (3 scenes, 6 files updated)
**Task 23**: ✅ COMPLETE - Move debug script to scripts/debug/ (1 file relocated)

**Batch 4 Complete!** All scene organization tasks complete (7/7 tasks).
**Batch 3 Complete!** All resource instance prefixes updated (8/8 tasks).
**Batch 2 Complete!** All scene structure fixes complete (3/3 tasks).

**Batch 4 Details:** Scene Organization (Tasks 17-23) - 7/7 tasks complete
- Task 17: ✅ COMPLETE - UI subfolders created (5 directories)
- Task 18: ✅ COMPLETE - Menu scenes moved to menus/ (6 scenes, 10 refs)
- Task 19: ✅ COMPLETE - Overlay scenes moved to overlays/ (7 scenes, 15 refs)
- Task 20: ✅ COMPLETE - Settings overlays to overlays/settings/ (3 scenes, 7 files)
- Task 21: ✅ COMPLETE - HUD scenes to hud/ (4 scenes, 20 refs)
- Task 22: ✅ COMPLETE - Widget scenes to widgets/ (3 scenes, 6 files)
- Task 23: ✅ COMPLETE - Debug script to scripts/debug/ (1 file)

**Batch 5 Complete!** All Placeholder Quarantine tasks complete (4/4 tasks).

**Batch 5 Details:** Placeholder Quarantine (Tasks 24-27) - 4/4 tasks complete
- Task 24: ✅ COMPLETE - Create tests/assets/ structure (5 directories)
- Task 25: ✅ COMPLETE - Move placeholder audio to tests/assets/audio/ (62 files + 62 .import)
- Task 26: ✅ COMPLETE - Update audio references (10 files)
- Task 27: ✅ COMPLETE - Delete _originals folder (48 files deleted)

**Note**: Tasks 25, 26, and 27 were completed together in a single commit.

**Batch 6 Complete!** All Enforcement & Documentation tasks complete (4/4 tasks).

**Batch 6 Details:** Enforcement & Documentation (Tasks 28-31) - 4/4 tasks complete
- Task 28: ✅ COMPLETE - Add asset prefix validation test (test_asset_prefixes.gd created)
- Task 29: ✅ COMPLETE - Add component container structure test (test_component_structure.gd created)
- Task 30: ✅ COMPLETE - Update STYLE_GUIDE.md (already up-to-date from 2026-01-24)
- Task 31: ✅ COMPLETE - Update AGENTS.md with new paths (resource/asset prefixes + UI scene organization)

**ALL 6 BATCHES COMPLETE!**
**CLEANUP V4.5 IS 100% COMPLETE!**

Summary:
- 31/31 tasks completed (100%)
- All asset and resource prefixes standardized
- All scenes organized by type
- All placeholder assets quarantined to tests/
- Comprehensive validation tests added
- Documentation fully updated

---

## Key Conventions (Quick Reference)

### Resource Prefix Resolution
| Type | Prefix | Example |
|------|--------|---------|
| Class definitions (.gd) | `rs_` | `rs_movement_settings.gd` |
| Instances (.tres) | `cfg_` | `cfg_movement_default.tres` |

### Asset Prefixes
| Type | Prefix | Example |
|------|--------|---------|
| Textures | `tex_` | `tex_shadow_blob.png` |
| Materials | `mat_` | `mat_player_body.tres` |
| Music | `mus_` | `mus_main_menu.ogg` |
| SFX | `sfx_` | `sfx_jump.wav` |
| Ambient | `amb_` | `amb_exterior.wav` |
| Footsteps | `fst_` | `fst_grass_01.wav` |
| Editor Icons | `icn_` | `icn_component.svg` |
| Fonts | `fnt_` | `fnt_ui_default.ttf` |

### Component Attachment Pattern
Components (`c_*_component.gd`) must be attached to `Node` or `Node3D` types only.

**Correct:**
```
SO_Floor (CSGBox3D)
└── C_SurfaceTypeComponent (Node with c_surface_type_component.gd)
```

**Incorrect:**
```
SO_Floor (CSGBox3D with c_surface_type_component.gd)  ❌
```

---

## Execution Rules

### Before Each Task
- Ensure clean working tree (`git status`)
- Run tests to establish baseline

### During Each Task
- Use `git mv` for moves (preserves history)
- Update all references with find/replace
- Verify critical files manually

### After Each Task
- Run affected tests
- Commit: `refactor: [task name] - [file count] files updated`
- Update this prompt + tasks doc checkboxes

### Rollback
If tests fail: `git reset --hard HEAD`, analyze, retry.

---

## Batch Execution Order

| Batch | Phase | Tasks | Risk | Status |
|-------|-------|-------|------|--------|
| 1 | Asset Prefixes | 1-5 | Low | ✅ Complete (5/5) |
| 2 | Scene Structure | 14-16 | Medium | ✅ Complete (3/3) |
| 3 | Resource Prefixes | 6-13 | Medium | ✅ Complete (8/8) |
| 4 | Scene Organization | 17-23 | Medium | ✅ Complete (7/7) |
| 5 | Placeholder Cleanup | 24-27 | High | ✅ Complete (4/4) |
| 6 | Enforcement & Documentation | 28-31 | Low | ✅ Complete (4/4) |

**ALL BATCHES COMPLETE - CLEANUP V4.5 FINISHED!**

---

## Common Commands

```bash
# Find files to rename
find assets -type f -name "*.png" | grep -v "tex_"

# Reference scan
grep -rn "old_filename" . --include="*.gd" --include="*.tscn" --include="*.tres"

# Bulk path update
find . \( -name "*.gd" -o -name "*.tres" -o -name "*.tscn" \) -type f \
  -exec sed -i '' 's|old/path/|new/path/|g' {} +

# Run tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Refresh script cache
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

---

## Scenes/UI Target Structure

```
scenes/ui/
  ├── menus/           (main_menu, credits, game_over, victory)
  ├── overlays/
  │   ├── ui_pause_menu.tscn
  │   ├── ui_save_load_menu.tscn
  │   └── settings/    (audio, gamepad, touchscreen, vfx, input)
  ├── hud/             (hud_overlay, damage_flash, button_prompt, loading_screen)
  └── widgets/         (virtual_joystick, virtual_button, gamepad_preview, mobile_controls)
```

---

## Placeholder Quarantine Structure

```
tests/assets/
  ├── audio/
  │   ├── music/
  │   ├── sfx/
  │   ├── footsteps/
  │   └── ambient/
  └── textures/
```

---

**Last Updated**: 2026-01-25
**Status**: CLEANUP V4.5 COMPLETE - All 31 tasks finished (100%)
