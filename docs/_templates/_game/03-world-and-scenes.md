# 03 — World & Scenes

Each scene here becomes a Godot scene under `scenes/gameplay/` plus an `RS_SceneRegistryEntry` under `resources/scene_registry/`. Follow `docs/scene_manager/ADDING_SCENES_GUIDE.md`.

## Scene list

Repeat this block per scene (max 6).

```text
- ID: scene_<slug>           # matches registry entry file name
- Display name: "<...>"
- Kind: <menu | gameplay | cutscene | ending>
- Background: <asset path or placeholder description>
- Music: <asset path | silence>
- Ambient SFX: <...>
- Contains NPCs: [<npc_id>, ...]
- Contains items: [<item_id>, ...]     # from doc 04
- Contains triggers: [<trigger_id>, ...]
- Entry conditions: <flag_id required | none>
- First-visit cutscene: <cutscene_id | none>
```

## Scene flow graph

Directed edges. Each edge names the trigger and any gate.

```text
<scene_id_a> --[<trigger_id>, gate: <flag_id | none>]--> <scene_id_b>
```

Example:

```text
main_menu    --[new_game_button]--> bedroom
bedroom      --[door_exit,   gate: has_key]--> hallway
hallway      --[stairs_down]--> basement
basement     --[ritual_complete, gate: solved_ritual]--> ending_scene
```

Rules:

- Exactly one edge into the first gameplay scene from `main_menu`
- Every non-ending scene has at least one outgoing edge the player can reach
- No dead ends off the golden path (or list them here explicitly as intentional)

## Transitions

Per edge, specify the transition kind supported by the scene manager:

| From → To           | Transition | Duration |
| ------------------- | ---------- | -------- |
| `main_menu → <...>` | `fade`     | 0.5s     |
| `<...> → <...>`     | `instant`  | –        |
| `<...> → <...>`     | `loading`  | n/a      |

## Cutscenes

Repeat per cutscene (max 3). Feeds `cutscene_system`.

```text
- ID: cutscene_<slug>
- Plays on: <event — e.g. entering scene_x with flag_y set>
- Blocking: <yes | no>
- Beats:
  1. <camera/scene action — e.g. fade in on npc_a>
  2. <dialogue line or narration>
  3. <state effect — e.g. set_flag:met_boss>
  4. <fade out → transition to scene_z>
- Skippable: <yes | no>
```

## Camera / vcam rules

- Default behavior: `<follow protagonist | static per scene | mix>`
- Per-scene overrides: `<list or "none">`
- Landing-impact / other vcam rules: `<use template defaults | custom cfg>`

## Environment details per scene (optional but recommended)

For any scene with non-obvious geometry, sketch the layout:

```text
scene_<slug>:
  layout: |
    +----------------------+
    | door                  |
    |   npc_a          item |
    | pc_start              |
    +----------------------+
  notes: <...>
```
