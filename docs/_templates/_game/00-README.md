# One-Shot Adventure Game Pack

Fill-in-the-blanks templates for prompting an AI to build a small adventure game on top of this Godot 4.6 template in a single prompt.

## How to use

1. Copy this `_game/` folder somewhere (or edit in place), rename to your project.
2. Fill out the four design docs in order. Leave no `<...>` placeholders — every one is a decision the AI cannot make for you without drifting.
3. Assemble the one-shot prompt: paste the filled-out docs below a prompt header that points the AI at the template's conventions.

## Scope guardrails (read before filling anything out)

A single prompt realistically produces a **very small** adventure game. Budget:

- 3–6 scenes (rooms/locations)
- 1 protagonist + 2–4 NPCs
- 6–12 interactable items
- 2–4 puzzles, mostly linear
- 1 ending (optionally one bad-end)
- Placeholder art/audio, or user-provided asset paths — **no AI-generated assets**

If your design exceeds this, split into phases and only ship phase 1 in the one-shot.

## Prompt header (prepend to the filled-out docs)

```
You are implementing a small adventure game inside an existing Godot 4.6 template.

Before writing any code, read:
- AGENTS.md and CLAUDE.md (rules of engagement)
- docs/general/STYLE_GUIDE.md, SCENE_ORGANIZATION_GUIDE.md, DEV_PITFALLS.md
- docs/architecture/dependency_graph.md, ecs_state_contract.md
- docs/scene_manager/ADDING_SCENES_GUIDE.md
- Overviews under docs/ for: dialogue_system, narrative_system, cutscene_system,
  scene_director, ui_manager, input_manager, save_manager, qb_rule_manager

Follow existing conventions (prefixes, scene tree layout, state store,
RS_SceneRegistryEntry, RS_UIScreenDefinition). Do not invent new managers.
Use placeholder art/audio where assets are not provided.

The game design follows below in four sections. Implement exactly what is
specified; ask before inventing content the design omits.
```

## What goes in each doc

- `01-game-brief.md` — concept, tone, scope, platform, acceptance criteria
- `02-story-and-characters.md` — premise, cast, narrative flags, dialogue trees
- `03-world-and-scenes.md` — locations, scene-flow graph, cutscenes
- `04-interactions-and-puzzles.md` — items, puzzles, UI, input, save model

## Acceptance test

Your `01-game-brief.md` must include a **golden-path script** — the exact sequence of scenes, interactions, and dialogue choices that completes the game. The AI uses this to self-verify. Without it, "done" is undefined.
