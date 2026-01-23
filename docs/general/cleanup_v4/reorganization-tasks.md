# Project Reorganization Tasks

## Overview

This document tracks folder and file reorganization tasks for the cabaret-ball project. The goal is to improve project structure clarity, enforce consistent conventions, and reduce scattered/duplicate organization patterns.

---

## Tasks

### Resources Folder

- [ ] **Move image/audio assets from resources to assets**
  - Move `resources/audio/` → `assets/audio/` with `aud_` prefix
  - Move `resources/button_prompts/` → `assets/button_prompts/` with appropriate prefix
  - Keep only `.tres` data resources in `resources/`

- [ ] **Add `data_` prefix to resources folder items**
  - Rename resource folders to clarify data-only nature (e.g., `data_settings/`, `data_triggers/`)

- [ ] **Split resources/settings by domain**
  - Create subfolders: `gameplay/`, `audio/`, `input/`, `movement/`, etc.
  - Organize 17 settings files by domain

- [ ] **Add `base_` prefix to base resource folders**
  - Clarify which resources are base/default configurations

### Scenes Folder

- [ ] **Move prototype scenes to tests**
  - Move `scenes/prototypes/` → `tests/scenes/prototypes/`
  - Move `scenes/tmp_invalid_gameplay.tscn` → `tests/scenes/`

- [ ] **Move templates into scenes folder**
  - Move `templates/` → `scenes/templates/`
  - Update all references to template paths

### Scripts Folder

- [ ] **Delete parse_test**
  - Location: `tools/parse_test.gd` (simple test script, safe to delete)

- [ ] **Consolidate all utils to scripts/utils**
  - Check for scattered utility files across the codebase
  - Move any found utils to `scripts/utils/`
  - Move `scripts/ecs/helpers/` → `scripts/utils/ecs/`

- [ ] **Keep ECS events in scripts/ecs/events/**
  - ECS events stay coupled with ECS folder (evn_health_changed, evn_entity_death, etc.)
  - Only generic event bus stays in `scripts/events/`

- [ ] **Verify all interfaces are in scripts/interfaces**
  - Currently 11 files - verify none are scattered elsewhere

- [ ] **Create scripts/resources folder**
  - Move `scripts/ecs/resources/` → `scripts/resources/ecs/`
  - Move `scripts/ui/resources/` → `scripts/resources/ui/`
  - Move `scripts/state/resources/` → `scripts/resources/state/`
  - Consolidate all GDScript resource class definitions

- [ ] **Clean up ECS folder structure**
  - ECS should only contain: entities, components, systems (and events)
  - Move `scripts/ecs/helpers/` → `scripts/utils/ecs/`
  - Move `scripts/ecs/markers/` → `scripts/scene_structure/ecs/`
  - Move `scripts/ecs/resources/` → `scripts/resources/ecs/`

- [ ] **Convert marker_surface_type to a component**
  - Location: `scripts/ecs/markers/marker_surface_type.gd`
  - Currently: Marker node with `surface_type` export and getter
  - Convert to: `C_SurfaceTypeComponent` extending `BaseECSComponent`
  - Update any systems querying surface type

- [ ] **Rename interactable controllers from e_ to inter_**
  - Only interactable controllers get `inter_` prefix (regular entities keep `e_`)
  - Files to rename:
    - `e_door_trigger_controller.gd` → `inter_door_trigger.gd`
    - `e_checkpoint_zone.gd` → `inter_checkpoint_zone.gd`
    - `e_hazard_zone.gd` → `inter_hazard_zone.gd`
    - `e_victory_zone.gd` → `inter_victory_zone.gd`
    - `e_signpost.gd` → `inter_signpost.gd`
  - Update all scene references and class names

- [ ] **Move scripts/prototypes to tests**
  - Move `scripts/prototypes/` → `tests/prototypes/`

- [ ] **Rename main.gd to root.gd**
  - Rename `main.gd` → `root.gd`
  - Move to top-level scripts folder (`scripts/root.gd`)
  - Update scene references in `root.tscn`

- [ ] **Organize scripts/ui by screen type**
  - Create subfolders: `menus/`, `overlays/`, `hud/`, `settings/`
  - Organize 47+ UI files by their screen type

### Tests Folder

- [ ] **Clean up tests folder**
  - Review for unused test files
  - Consolidate test helpers
  - Ensure consistent organization

### Debug/Config Improvements

- [ ] **Remove debug settings from project.godot**
  - Create debug manager/component for runtime debug toggles
  - Keep debug configuration at system/manager/component level
  - No project settings required for debug features

---

## Priority Order

1. **High Impact**: Resources folder cleanup (affects imports/paths)
2. **Medium Impact**: Scripts reorganization (improves discoverability)
3. **Low Impact**: Naming convention updates (e_ → inter_)

---

## Notes

- All renames require updating `preload()` and `load()` paths
- Scene references in `.tscn` files must be updated
- Test imports need verification after moves
- STYLE_GUIDE.md prefix rules need update to add `inter_` prefix for interactables

