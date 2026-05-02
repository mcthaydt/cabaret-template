# 2.5D Template Pivot Plan

## Status

This is a planning document for the broader runtime pivot. It is not a Phase 5 implementation checklist.

The hybrid direction is now established on the canonical player path: `prefab_player.tscn` uses a `Sprite3D` body visual through `prefab_player_body.tscn` while preserving the shared `CharacterBody3D` and ECS contract.

Phase 5 may prepare the scene path for this direction by cleaning the canonical base scene, rebuilding a demo entry with builder-backed blockout authoring, and removing temp/fake scenes. Directional sprite runtime systems, camera behavior changes, narrative systems, cutscene orchestration, and encounter loops should land in later focused phases.

## Target Direction

The template should support a Xenogears-style presentation: 2D directional character sprites moving through authored 3D spaces with freely rotatable horizontal camera control, camera-relative movement, and JRPG interaction loops.

Default 2.5D world, tile, sprite, and collision scale lives in `docs/systems/2_5d/2_5d-units-and-scale.md`. Future room builders, character prefabs, and camera work should use that contract unless a focused design explicitly overrides it.

The first target is a small but real demo path that proves the template can host:

- 3D blockout spaces with readable traversal, interactables, and spawn points.
- Sprite-based characters that face and animate by direction.
- Free horizontal camera rotation that keeps rooms readable from arbitrary yaw angles.
- Dialogue, narrative, and cutscene hooks as first-class interactions.
- Encounter stubs that can later connect to combat or scene-director flows.

## Phase Boundaries

Phase 5 owns scene cleanup only:

- Keep `scenes/core/templates/tmpl_base_scene.tscn` as the canonical base scene.
- Use `U_EditorBlockoutBuilder` for demo-entry reconstruction.
- Use `U_EditorPrefabBuilder` when prefab normalization is required.
- Avoid new runtime systems unless preserving existing behavior requires them.
- Delete temp/fake scenes only after inventory and rebuild verification.

Later phases own runtime implementation:

- Directional sprite character templates.
- Free horizontal camera rotation.
- Camera-relative movement.
- Dialogue, narrative, cutscene, and encounter loops.
- Tooling and docs for authoring 2.5D rooms.

## Runtime Slices

### Directional Sprites

- `prefab_player.tscn` is the canonical sprite-character prefab. It reuses `tmpl_character.tscn`, keeps the `CharacterBody3D` and existing ECS components, and uses the sprite body visual from `prefab_player_body.tscn`.
- Introduce Sprite3D or AnimatedSprite3D character templates that inherit from the existing character prefab contracts where practical.
- Support 4-direction first, with room to expand to 8-direction if the art pipeline needs it.
- Define animation names around intent and direction, for example `idle_down`, `walk_left`, and `talk_up`.
- Keep ECS identity, input, movement, spawn recovery, and interaction components reusable.
- Decide billboard behavior explicitly per character type; avoid accidental always-face-camera sprites if directional facing matters.

### Free Horizontal Camera

- Add horizontal camera rotation that can move freely around authored rooms while preserving readable traversal and interaction framing.
- Route behavior through vCam/camera-manager contracts instead of ad-hoc Camera3D manipulation.
- Define input response, rotation speed, recentering, and cutscene lock rules explicitly.
- Treat optional snap points as a later accessibility or authored-room presentation feature, not the primary camera model.
- Preserve scene-manager camera handoff rules for gameplay-to-gameplay transitions.

### Camera-Relative Movement

- Convert input intent through the current camera basis so up/down/left/right stay readable throughout free horizontal rotation.
- Keep movement ECS-driven; avoid special-case player scripts that bypass `S_MovementSystem`.
- Define how sprite facing is derived from movement vector, interaction target, and cutscene override.
- Add tests for camera basis changes so continuous horizontal rotation does not invert or drift input.

### Interaction, Dialogue, And Cutscenes

- Prioritize JRPG interaction flow before combat depth.
- Interactables should continue using controller/config patterns instead of hand-authored trigger stacks.
- Dialogue should integrate with localization and UI manager contracts.
- Cutscenes should coordinate input lock, camera lock, actor facing, dialogue, and scene-director objectives.
- Narrative and cutscene docs should own runtime contracts once implementation starts.

### Encounter Stubs

- Add encounter stubs only after the basic room, movement, camera, and interaction loop is stable.
- Start with trigger/scene-director events that prove the handoff shape without implementing full combat.
- Keep encounter state saveable and scene-manager friendly from the first implementation pass.

## Authoring And Builders

- Use `U_EditorBlockoutBuilder` for room blockouts and demo-entry reconstruction.
- Use `U_EditorPrefabBuilder` for reusable 2.5D character, interactable, and prop prefabs when those prefabs become concrete.
- Keep builder scripts readable enough for LLM edits: small methods, explicit paths, and stable node names.
- Prefer generated blockout scenes over manual `.tscn` editing when a scene is expected to iterate.

## Verification Targets

Future implementation phases should add:

- Scene inventory consistency tests for the keep/delete scene set.
- Builder smoke tests for every new scene or prefab builder script.
- Character template tests for required Sprite3D or AnimatedSprite3D nodes and ECS components.
- Camera rotation tests for horizontal look input, recentering, camera locks, and camera-relative input mapping.
- Interaction/dialogue/cutscene tests for input lock and state cleanup.
- Encounter stub tests for scene-director or event-bus handoff.

Manual checks should include launching the demo entry from `scenes/core/root.tscn`, rotating the camera left/right, walking through the room, interacting with an NPC/object, and confirming transitions leave state clean.
