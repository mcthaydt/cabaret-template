# Room 6 — Game Design Pack

Video-game adaptation of the "Room 6" comic (8 pages, slow-burn motel horror) built on top of the cabaret-template (Godot 4.6).

## Source material

Short form horror comic, 8 pages, ~5 panels per page. Protagonist checks into Room 6 at a roadside motel. Reality distorts through observation (mirror, TV, phone, wallpaper). Twist: in the morning the clerk says "We don't have a Room 6." Final panel: the Traveler is still inside, visible in the motel window's reflection.

The comic script is the ground truth. Every beat in doc 05 traces back to a specific panel.

## Files in this pack

- `00-README.md` — this file
- `01-game-brief.md` — identity, scope, core loop, golden path, acceptance criteria
- `02-story-and-characters.md` — premise, Traveler & Clerk, narrative flags, dialogue trees
- `03-world-and-scenes.md` — scene list, flow graph, cutscenes, per-scene vcam constraints
- `04-interactions-and-puzzles.md` — items, verbs, observation triggers, UI, input, save model
- `05-beat-sheet.md` — ~40-row panel-by-panel implementation table
- `06-continuation-prompt.md` — session-resume prompt; update at end of every work session

Templates these were filled from: `docs/_templates/_game/00-README.md` through `06-continuation-prompt.md`.

## Template fit (important context)

The cabaret-template ships a **3D third-person orbit camera**. For Room 6 we keep that system but **constrain it per scene** — lock camera distance near the Traveler's head, clamp yaw/pitch tight, and use per-scene vcam swap points to simulate the comic's fixed panel framing. No new camera managers. Details in doc 03.

If a future phase wants a true first-person mode, that's an additive change to the vcam system (new `RS_VCamModeFirstPerson`) and is explicitly out of scope for the one-shot build.

## One-shot prompt header

Prepend this to the concatenated docs (01–06) when asking an AI to build the game:

```text
You are implementing a short horror game "Room 6" inside the existing Godot 4.6
cabaret-template. This is a scripted, beat-driven experience — not a puzzle game.

Before writing any code, read:
- AGENTS.md and CLAUDE.md (rules of engagement)
- docs/general/STYLE_GUIDE.md, SCENE_ORGANIZATION_GUIDE.md, DEV_PITFALLS.md
- docs/architecture/dependency_graph.md, ecs_state_contract.md
- docs/scene_manager/ADDING_SCENES_GUIDE.md
- docs/vcam_manager/* (camera constraint patterns — Room 6 uses constrained orbit)
- Overviews under docs/ for: dialogue_system, narrative_system, cutscene_system,
  scene_director, ui_manager, input_manager, save_manager

Follow existing conventions (prefixes, scene tree layout, Redux state store,
RS_SceneRegistryEntry, RS_UIScreenDefinition). Do not invent new managers.
Use placeholder art/audio unless specific asset paths are provided.

The full design follows. Doc 05 (beat sheet) is the authoritative implementation
order — walk it top-to-bottom. Doc 06 is session state; consult it for where
we left off. Implement only what the docs specify; ask before inventing.
```

## Working rhythm

1. Session starts → paste doc 06 contents into AI prompt → confirm starting beat → work.
2. Implement 3–5 beats per session. Commit per beat with the beat ID in the message.
3. Session ends → update doc 06's Status Summary + Where We Left Off → commit.
4. Design changes (new flag, new item, new scene) → update the relevant doc 02/03/04 **and** add/amend rows in doc 05 **before** coding.
