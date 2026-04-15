# 02 — Story & Characters

## Premise (≤ 150 words)

`<Who is the protagonist, where are they, what just happened, what do they want?>`

## Setting

- Time / place: `<...>`
- World rules (1–3 bullets that constrain puzzles): `<...>`

## Protagonist

- ID: `pc_<slug>`
- Name / pronouns: `<...>`
- Voice / speech style: `<e.g. terse, wry, formal>`
- Starting inventory: `<item_ids from doc 04, or empty>`
- Starting scene: `<scene_id from doc 03>`

## NPCs

Repeat the block below for each NPC (max 4).

```
- ID: npc_<slug>
- Name / role: <...>
- Located in: <scene_id>
- Wants: <one sentence>
- Blocks progress until: <flag_id or item_id>
- Voice: <2–3 adjectives>
```

## Narrative flags

These become keys in the narrative state slice. Keep names `snake_case`.

| Flag ID                | Set when                         | Read by                |
| ---------------------- | -------------------------------- | ---------------------- |
| `met_<npc_id>`         | dialogue node `<id>` completes   | `<scene/puzzle>`       |
| `has_<item_id>`        | item picked up                   | `<dialogue/puzzle>`    |
| `solved_<puzzle_id>`   | puzzle `<id>` resolves           | `<scene transition>`   |
| `ending_<slug>`        | ending cutscene plays            | credits                |

## Dialogue trees

One block per NPC. Nodes are addressed `<npc_id>.<node_id>`. Every node must have a terminal path.

```
npc_<slug>:
  entry: root
  nodes:
    root:
      npc: "<line>"
      choices:
        - text: "<player line>"
          requires: <flag_id | item_id | none>
          effect:  <set_flag:<id> | give_item:<id> | take_item:<id> | none>
          next:    <node_id | exit>
        - text: "<...>"
          next:    <...>
    <node_id>:
      npc: "<line>"
      choices: [...]
    exit:
      # terminal; returns to gameplay
```

### Dialogue authoring rules (AI must follow)

- Every branch ends at `exit` or loops back to a visited node
- Choices gated by flags/items must show a visible hint when unavailable (e.g. greyed-out) — or hide entirely (specify per NPC)
- No node has more than 4 choices
- Lines ≤ 200 characters

## Cast-wide voice rules

- `<e.g. no profanity>`
- `<e.g. NPCs never break the fourth wall>`
- `<e.g. protagonist's inner thoughts use italics>`
