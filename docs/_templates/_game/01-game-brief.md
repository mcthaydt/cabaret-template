# 01 — Game Brief

## Identity

- Working title: `<title>`
- Genre / subgenre: `<e.g. 2D point-and-click mystery>`
- Perspective: `<top-down | side-scroller | first-person static screens | other>`
- Tone / references: `<3–5 words; 1–2 "feels like X meets Y" comparisons>`
- Target length: `<minutes of play for the golden path>`

## Platform & input

- Primary platform: `<desktop | mobile | web>`
- Supported input devices: `<keyboard+mouse | gamepad | touch>` (template supports all three)
- Resolution / aspect: `<e.g. 1920x1080, 16:9>`
- Language(s): `<en only | en + ...>`

## Scope budget (do not exceed without splitting into phases)

| Bucket            | Max |
| ----------------- | --- |
| Scenes/locations  | 6   |
| NPCs              | 4   |
| Interactable items| 12  |
| Puzzles           | 4   |
| Cutscenes         | 3   |
| Endings           | 2   |

## Pillars (what this game IS)

1. `<pillar 1 — e.g. exploration over combat>`
2. `<pillar 2>`
3. `<pillar 3>`

## Core gameplay loop

The five-second thing the player does repeatedly. Write it as a short cycle, not prose.

```text
<verb 1> → <verb 2> → <feedback/payoff> → <verb 1 again>
```

Example (scripted horror): `look → notice a change → interact with the changed thing → script advances → look again`

Example (puzzle adventure): `explore scene → pick up/examine items → try combinations → puzzle clears → new scene unlocks`

Constraints:

- One loop, not many. If you have two, you probably have two games.
- The loop must be directly supported by the input bindings in doc 04.
- Anything outside the loop (menus, cutscenes, one-off puzzles) is *not* the loop — it interrupts it.

## Non-goals (what this game is NOT)

- `<e.g. no real-time combat>`
- `<e.g. no procedural generation>`
- `<e.g. no multiplayer>`

## Assets

- Art source: `<user-provided paths | use placeholder shapes/colors>`
- Audio source: `<user-provided paths | silence | placeholder SFX>`
- Font: `<path or "template default">`
- Placeholder convention: `<e.g. colored rects, labeled by entity name>`

## Golden-path script (REQUIRED)

Write the exact playthrough that constitutes a successful completion. Every step must map to a scene, interaction, or dialogue choice defined in docs 02–04.

```
1. Boot → main menu → New Game
2. Enter scene <scene_id> → <action>
3. Talk to <npc_id>, choose <dialogue_node_id>
4. Pick up <item_id> from <scene_id>
5. Use <item_id> on <target_id> in <scene_id>
6. Enter <scene_id> (unlocked by flag <flag_id>)
...
N. Trigger ending cutscene <cutscene_id> → credits
```

## Optional bad-end / failure script

```
<steps that lead to the bad end, if any>
```

## Acceptance criteria

- [ ] Golden path completes without errors on `<platform>`
- [ ] Every scene listed in doc 03 is reachable
- [ ] Every item listed in doc 04 is obtainable
- [ ] All dialogue trees in doc 02 have at least one path to exit
- [ ] Save/load mid-game preserves: `<list state domains>`
- [ ] `tools/run_gut_suite.sh` passes
- [ ] `<additional criteria>`

## Out-of-scope / deferred

- `<items explicitly deferred to a later phase>`
