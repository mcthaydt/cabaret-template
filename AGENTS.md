# Agents Notes

## Start Here

- Project type: Godot 4.7 (GDScript).
- Do not create or use git worktrees for this project unless explicitly requested.
- Before changing code, read `docs/guides/STYLE_GUIDE.md` and the relevant system overview under `docs/systems/**`.
- For workflow and commit expectations, read `docs/guides/COMMIT_WORKFLOW.md`.
- For architecture orientation and repo map, read `docs/guides/ARCHITECTURE.md`.
- Keep project planning docs current whenever a story advances.
- Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` after file naming, scene structure, script/resource, or docs-structure changes.
- **Never create `.tscn` files by hand.** New scenes and prefabs must be created via builder scripts (`U_EditorPrefabBuilder`, `U_TemplateBaseSceneBuilder`, etc.). See `docs/guides/pitfalls/GODOT_ENGINE.md` → Template Scene Authoring and `docs/architecture/extensions/builders.md`.
- **After modifying a builder that emits scene nodes, regenerate `.tscn` files**: run the rebuild script headless:
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd
  ```

## Core Routing

- Architecture map and dependency lookup: `docs/guides/ARCHITECTURE.md`
- Commit/TDD workflow: `docs/guides/COMMIT_WORKFLOW.md`
- Style and naming: `docs/guides/STYLE_GUIDE.md`
- Scene organization and interactable authoring: `docs/guides/SCENE_ORGANIZATION_GUIDE.md`
- Testing/headless pitfalls: `docs/guides/pitfalls/TESTING.md`
- Godot engine pitfalls: `docs/guides/pitfalls/GODOT_ENGINE.md`
- GDScript pitfalls: `docs/guides/pitfalls/GDSCRIPT_4_6.md`
- State pitfalls: `docs/guides/pitfalls/STATE.md`
- ECS pitfalls: `docs/guides/pitfalls/ECS.md`
- Mobile/touchscreen pitfalls: `docs/guides/pitfalls/MOBILE.md`

## System Docs

- ECS: `docs/systems/ecs/ecs_architecture.md`
- 2.5D Template Pivot: `docs/systems/2_5d/2_5d-template-pivot-plan.md`
- 2.5D Units and Scale: `docs/systems/2_5d/2_5d-units-and-scale.md`
- QB Rule Engine v2: `docs/systems/qb_rule_manager/qb-v2-overview.md`
- AI System: `docs/systems/ai_system/ai-system-overview.md`
- Scene Director/Objectives: `docs/systems/scene_director/scene-director-overview.md`
- Scene Manager: `docs/systems/scene_manager/scene-manager-overview.md`
- Input Manager: `docs/systems/input_manager/input-manager-overview.md`
- UI Manager: `docs/systems/ui_manager/ui-manager-overview.md`
- UI pitfalls: `docs/systems/ui_manager/ui-pitfalls.md`
- vCam Manager: `docs/systems/vcam_manager/vcam-manager-overview.md`
- vCam pitfalls: `docs/systems/vcam_manager/vcam-pitfalls.md`
- VFX Manager: `docs/systems/vfx_manager/vfx-manager-overview.md`
- Save Manager: `docs/systems/save_manager/save-manager-overview.md`
- Time Manager: `docs/systems/time_manager/time-manager-overview.md`
- Localization Manager: `docs/systems/localization_manager/localization-manager-overview.md`
- Audio Manager: `docs/systems/audio_manager/AUDIO_MANAGER_GUIDE.md`
- Display Manager: `docs/systems/display_manager/display-manager-overview.md`
- Lighting Manager: `docs/systems/lighting_manager/lighting-manager-overview.md`

## ADRs & Extensions

- ADR index ("why we chose X"): `docs/architecture/adr/README.md`
- Extension recipes ("how to add a feature"): `docs/architecture/extensions/README.md`

## Active Cleanup V8 Tracking

- Archived task checklist: `docs/history/cleanup_v8/cleanup-v8-tasks.md`
- Archived continuation prompt: `docs/history/cleanup_v8/cleanup-v8-continuation-prompt.md`
- Archived docs inventory: `docs/history/cleanup_v8/docs_inventory.md`
