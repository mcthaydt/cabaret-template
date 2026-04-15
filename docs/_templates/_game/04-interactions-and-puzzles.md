# 04 — Interactions, Puzzles, UI, Input, Save

## Items (max 12)

Repeat per item. Each becomes an interactable entity + inventory entry.

```text
- ID: item_<slug>
- Display name: "<...>"
- Description (examine text): "<≤ 200 chars>"
- Art: <asset path | placeholder>
- Starts in: <scene_id | pc_inventory | nowhere (spawned later)>
- Can be: [<pick_up>, <examine>, <use_on_target>, <combine_with_item>]
- Consumed on use: <yes | no>
- Sets flag on pickup: <flag_id | none>
```

## Interaction verbs

Pick one scheme and stick to it across the game.

- [ ] `examine / use / talk` (classic point-and-click)
- [ ] `interact` (single-verb, context-sensitive)
- [ ] other: `<...>`

Input bindings for each verb — fill in for every supported device. Update `resources/input/profiles/`.

| Verb      | Keyboard   | Gamepad   | Touch          |
| --------- | ---------- | --------- | -------------- |
| interact  | `E`        | `A`       | tap            |
| examine   | `Q`        | `Y`       | long-press     |
| inventory | `Tab`      | `Select`  | on-screen btn  |
| pause     | `Esc`      | `Start`   | on-screen btn  |

## Puzzles (max 4)

Repeat per puzzle.

```text
- ID: puzzle_<slug>
- Located in: <scene_id>
- Goal: <one sentence>
- Required items: [<item_id>, ...]
- Required flags: [<flag_id>, ...]
- Solution (ordered steps):
  1. <step>
  2. <step>
- On success:
  - sets: [<flag_id>, ...]
  - grants: [<item_id>, ...]
  - plays: <cutscene_id | none>
- On wrong attempt:
  - feedback: "<line or sfx>"
  - consequences: <none | lose_item:<id> | set_flag:<id>>
- Hints available: <none | talk to <npc_id> | examine <item_id>>
```

## UI screens

Each becomes an `RS_UIScreenDefinition` registered via `U_UIRegistry`. See `docs/ui_manager/`.

| Screen ID           | Purpose             | Triggered by           | Layer    |
| ------------------- | ------------------- | ---------------------- | -------- |
| `ui_main_menu`      | title + new/continue| boot                   | base     |
| `ui_pause`          | pause overlay       | pause action           | overlay  |
| `ui_inventory`      | item list + examine | inventory action       | overlay  |
| `ui_dialogue`       | NPC lines + choices | dialogue_system        | overlay  |
| `ui_settings`       | audio/input/etc     | from menu/pause        | overlay  |
| `ui_credits`        | end card            | ending cutscene        | base     |

For each custom screen, specify:

```text
- ID: ui_<slug>
- Layout sketch: <rough description or ascii>
- Data source: <selector name or action — e.g. select_inventory_items>
- Dismiss behavior: <back action | auto on condition>
```

## HUD

- Always visible: `<e.g. interact prompt when near interactable>`
- Contextual: `<e.g. objective banner on flag change>`
- Hidden during: `<cutscenes, dialogue, menus>`

## Save / load model

Feeds `save_manager`. Specify exactly what persists.

- [ ] Current scene ID
- [ ] Protagonist position in scene
- [ ] Inventory
- [ ] All narrative flags
- [ ] Dialogue node history per NPC (for "already said")
- [ ] Puzzle solved states
- [ ] `<other>`

Save triggers:

- [ ] Autosave on scene transition
- [ ] Manual save from pause menu
- [ ] Checkpoint before cutscenes
- [ ] `<other>`

Slot model: `<single-slot | N-slot>` (N = `<...>`).

## Audio rules

- Music behavior on scene change: `<crossfade | cut | continue>`
- SFX categories: `<ui, footstep, interact, ambient>`
- Master/music/sfx buses: `<use template default bus layout>`

## Accessibility (pick what applies)

- [ ] Text size scalable
- [ ] High-contrast mode
- [ ] No timed puzzles
- [ ] Subtitles always on
- [ ] Colorblind-safe puzzle cues
- [ ] `<other>`

## Done-definition cross-check

Before submitting the one-shot prompt, verify:

- [ ] Every `item_id` referenced in docs 01–03 is defined here
- [ ] Every `flag_id` referenced anywhere is either set or read here
- [ ] Every `puzzle_id` gates at least one edge in doc 03's flow graph
- [ ] Every UI screen used in the golden path is listed above
- [ ] Every input verb used in the golden path has bindings for all supported devices
