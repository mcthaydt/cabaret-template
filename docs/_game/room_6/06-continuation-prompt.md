# 06 — Continuation Prompt: Room 6

Living document. Update at end of every work session. A new session starts by pasting this doc into the AI's first prompt.

## Update rhythm

- At session end, update every section below.
- Always bump **Last updated** and **Session #**.
- Never edit beats in doc 05 from this doc — this is state, not design.

---

## Current focus

- Project: `docs/_game/room_6/`
- Branch: `<to-be-set when implementation starts>`
- Last updated: `2026-04-14`
- Session #: `0` (pre-implementation — design pack only)

## Status summary

- Beats implemented: `0 of 56` (`0%`)
- Last verified beat: `—`
- Known-failing tests: `none` (no code yet)
- Build runs on: `none yet`

## Required readings (in order)

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/general/STYLE_GUIDE.md`, `SCENE_ORGANIZATION_GUIDE.md`, `DEV_PITFALLS.md`
4. `docs/_game/room_6/00-README.md`
5. `docs/_game/room_6/01-game-brief.md`
6. `docs/_game/room_6/02-story-and-characters.md`
7. `docs/_game/room_6/03-world-and-scenes.md`
8. `docs/_game/room_6/04-interactions-and-puzzles.md`
9. `docs/_game/room_6/05-beat-sheet.md` — **authoritative implementation order**
10. Subsystem overviews relevant to the current session:
    - `docs/scene_manager/ADDING_SCENES_GUIDE.md` (scene registry)
    - `docs/vcam_manager/` (camera constraints — Room 6 uses constrained orbit)
    - `docs/dialogue_system/` (Clerk, Phone trees)
    - `docs/cutscene_system/` (three cutscenes in doc 03)
    - `docs/narrative_system/` (flag slice)
    - `docs/ui_manager/` (screens in doc 04)
    - `docs/input_manager/` (bindings in doc 04)
    - `docs/save_manager/` (minimal persistence model)

## Where we left off

- Last completed beat: `—` (nothing implemented yet)
- First pending beat: `B001` (boot → root scene)
- In-flight work (uncommitted): `none`
- Open decisions blocking progress:
  - Confirm starting scope: implement **B001–B006** (boot → opening cutscene end) as first session, or go straight to **B001–B013** (through office dialogue + key handoff)?
  - Confirm placeholder-art strategy: pure grey-box / labeled rects, or grab simple free-art packs before starting?

## Next steps (session 1 proposal)

Cap at 5 beats. For first session, recommend one of:

### Option A — thin vertical slice (recommended for risk reduction)

1. `B001` — root scene boots cleanly with all managers
2. `B002` — main menu renders with "Room 6" title + New Game
3. `B003` — fade transition to a placeholder `scene_highway_arrival`
4. `B006` — (condensed) opening cutscene plays to `arrived_motel` flag set
5. `B007` — `scene_motel_office` loads with Traveler spawned

### Option B — full office chapter

1. `B001`–`B003` — boot + menu + first scene load
2. `B007`–`B013` — office chapter, Clerk dialogue, key handoff, room entry

Option A de-risks the scene flow + cutscene plumbing first; Option B gets a playable slice to credits faster but depends on all three subsystems (scene, dialogue, items) in one sitting.

## Known issues / deferred

- No art assets yet — everything is placeholder grey-box / labeled rects/quads
- No audio assets yet — silence + placeholder SFX only
- Hidden "escape?" ending is not implemented; not planned for MVP
- Gamepad UI affordances not tuned
- Mobile touch has no on-screen movement controls — relies on mouse-look-equivalent drag; revisit after desktop MVP plays end-to-end
- `cfg_camera_room6_clamp_rule.tres` needs authoring during session 1 (or substitute inline vcam clamps until then)

## Links

- Plan: `/Users/mcthaydt/.claude/plans/fizzy-gliding-adleman.md`
- Tasks: `—` (not created yet; create during session 1 if beat list needs tracking beyond doc 06)
- Design docs: `docs/_game/room_6/`
- Source comic: pasted into session 0 chat; archive into `docs/_game/room_6/source_comic.md` if useful

---

## AI instructions (do not remove)

When you open a new session with this doc pasted in:

1. Re-read the Required Readings in order.
2. Confirm with the user: "Last completed beat is `<value from Status summary>`. Starting next at `<First pending beat>`. Correct?" before editing any code.
3. Implement beats strictly in the order listed in **Next steps**. Do not skip ahead. Do not bundle unrelated beats.
4. After each beat:
   - Run `tools/run_gut_suite.sh` (or the narrower subsuite relevant to the change).
   - Commit with a message that includes the beat ID, e.g. `feat(room6-B007): office scene loads with traveler spawn`.
   - Update this doc's **Status summary** and **Where we left off** fields.
5. If a beat needs to split mid-implementation, add `B0xxA` / `B0xxB` rows to doc 05 first, then continue.
6. At session end, update **all** sections above and propose a commit of the updated continuation prompt (message: `docs(room6): continuation prompt — session <N>`).
