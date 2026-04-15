# 06 — Continuation Prompt

This is the **living** document of the game build. Unlike docs 01–05, which are written once and mostly stable, this one is *updated at the end of every session*. A new session starts by pasting this doc into the AI's first prompt.

Patterned on `docs/_templates/continuation-template.md` but specialized for game builds driven by doc 05's beat sheet.

## Update rhythm

- At session end, update every section below.
- Always bump **Last updated** date and **Session #**.
- Never edit beats in doc 05 from this doc — this is state, not design.

---

## Current focus

- Project: `<game folder, e.g. docs/_game/<slug>>`
- Branch: `<git branch>`
- Last updated: `<YYYY-MM-DD>`
- Session #: `<0, 1, 2, ...>`

## Status summary

- Beats implemented: `<N of M>` (`<percent>`)
- Last verified beat: `<B0xx>`
- Known-failing tests: `<list | none>`
- Build runs on: `<desktop | desktop+mobile | none yet>`

## Required readings (in order)

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/general/STYLE_GUIDE.md`, `SCENE_ORGANIZATION_GUIDE.md`, `DEV_PITFALLS.md`
4. `docs/_game/<slug>/00-README.md` through `05-beat-sheet.md`
5. `<any subsystem overview docs in play this session, e.g. docs/dialogue_system/>`

## Where we left off

- Last completed beat: `<B0xx — one-line description>`
- First pending beat: `<B0yy — one-line description>`
- In-flight work (uncommitted): `<branch status / WIP notes | none>`
- Open decisions blocking progress: `<list | none>`

## Next steps (this session)

1. `<B0yy>` — `<what to implement>`
2. `<B0yz>` — `<what to implement>`
3. `<B0zz>` — `<what to implement>`

Cap at 5 beats per session unless trivial. If a beat expands during implementation, stop and add sub-beats to doc 05 before continuing.

## Known issues / deferred

- `<asset gap, placeholder in use>`
- `<camera constraint still loose on scene_X>`
- `<tech debt item>`

## Links

- Plan: `<path or URL>`
- Tasks: `<path or URL | none>`
- Design docs: `docs/_game/<slug>/`

---

## AI instructions (do not remove)

When you open a new session with this doc pasted in:

1. Re-read the Required Readings in order.
2. Confirm with the user: "Last completed beat is `<B0xx>`. Starting next at `<B0yy>`. Correct?" before editing any code.
3. Implement beats strictly in the order listed in **Next steps**. Do not skip ahead.
4. After each beat: run the relevant tests, commit with a message that includes the beat ID, and update this doc's **Status summary** and **Where we left off** fields.
5. At session end, update **all** sections above and propose a commit of the updated continuation prompt.
