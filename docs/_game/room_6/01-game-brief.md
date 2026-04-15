# 01 — Game Brief: Room 6

## Identity

- Working title: **Room 6**
- Genre / subgenre: Short scripted horror / interactive comic
- Perspective: Constrained 3D third-person (near-first-person feel) — see doc 03 for camera approach
- Tone / references: "Twilight Zone meets a quiet PS1 horror demo." Slow, observational, no jump scares; dread accumulates through small wrongness.
- Target length: 8–12 minutes on the golden path

## Platform & input

- Primary platform: Desktop (keyboard + mouse)
- Also supported: Mobile touch
- Gamepad: accepted (template default) but not a target for the first build
- Resolution / aspect: 1920x1080, 16:9 (mobile scales via template's viewport scaling)
- Language(s): English only

## Scope budget

| Bucket            | Max | Used                                 |
| ----------------- | --- | ------------------------------------ |
| Scenes/locations  | 6   | 6 (highway, office, room 6, bath, room-morning, office-morning)  — ending plays inside office-morning as a cutscene overlay |
| NPCs              | 4   | 1 (Clerk)                            |
| Interactable items| 12  | 7 (key, phone, TV, mirror, bathroom door, bag, wallpaper)         |
| Puzzles           | 4   | 0 — replaced by 7 observation triggers (see doc 04) |
| Cutscenes         | 3   | 3 (opening drive, TV-shows-sleeping-self, morning reveal)         |
| Endings           | 2   | 1 canon (trapped) + optional hidden "escape?" stretch goal        |

## Pillars (what this game IS)

1. **Observation as mechanic** — wrongness is rewarded by noticing it, not by solving it.
2. **Delayed reactions** — the mirror, TV, and phone all hint that *you* are one step behind yourself.
3. **Fidelity to the comic** — every panel is a beat; the player should feel they're walking the comic.

## Non-goals (what this game is NOT)

- No combat, no chase sequences, no fail states mid-beat
- No inventory combinations, no item crafting
- No procedural content or randomized horror
- No multiple storylines — single scripted arc with one hidden branch at the end

## Core gameplay loop

```text
look → notice a change → interact/examine the changed thing → script advances → look again
```

Five-second cycle. The player's only verbs are **look** (free camera within per-scene clamps), **interact** (context-sensitive single verb), and **examine** (when an interactable supports it). Every observation trigger in doc 04 fires when the player *looks at* or *interacts with* the changed object; flags advance; next beat unlocks.

Anything outside this loop (dialogue, cutscenes, menus) is an interruption, not a second loop.

## Assets

- Art source: **Placeholders for MVP** — grey-boxed room, colored-rect NPCs labeled by name, TV as a quad with render-target texture, mirror as a quad. Replace after MVP with user-provided art.
- Audio source: Template default bus layout; ambient loops and SFX from `<user-provided or placeholder>`. Music: silence during room scenes; a low drone during cutscenes.
- Font: template default
- Placeholder convention: labeled colored rects/quads; signs rendered as 3D text labels

## Golden-path script (index into doc 05)

Terse index. Full detail in `05-beat-sheet.md`.

```text
1.  Boot → main menu → New Game                                       [B001–B003]
2.  Opening drive cutscene → motel exterior                           [B004–B006]
3.  Enter motel office → talk to Clerk → get key 6                    [B007–B012]
4.  Walk to Room 6 → enter room                                       [B013–B015]
5.  Drop bag → notice bathroom door close itself                      [B016–B019]
6.  Open bathroom (empty) → TV turns on (static → room from above)    [B020–B024]
7.  Observe TV delay (wave hand) → TV shows Traveler behind self      [B025–B028]
8.  Phone rings → answer → "...don't fall asleep..." / "...it moves"  [B029–B032]
9.  Lights flicker red → wallpaper faces → mirror posture mismatch    [B033–B037]
10. Bathroom door slowly opens → Traveler closes eyes                 [B038–B040]
11. Room rearranged: TV shows self sleeping, mirror smiling           [B041–B043]
12. Morning → walk to office → try to check out                       [B044–B047]
13. Clerk: "We don't have a Room 6." → step outside                   [B048–B051]
14. Neon flicker: NO VACANCY → EXCEPT ONE → reflection shows Traveler still in room [B052–B055]
15. Credits (ending_trapped)                                          [B056]
```

## Optional hidden-end script (stretch)

Not required for one-shot; leave unimplemented unless explicitly requested. If built: the player must *not* answer the phone AND must keep the bathroom door open every time they check it, enabling a different morning beat.

## Acceptance criteria

- [ ] Main menu → credits completes without errors on desktop (keyboard + mouse)
- [ ] Same on mobile touch (at minimum: launches, inputs respond, transitions don't stall)
- [ ] Every beat `B001`–`B056` in doc 05 is implemented and fires in order
- [ ] Every scene in doc 03 is reachable; every item in doc 04 is obtainable or examinable
- [ ] All dialogue trees in doc 02 terminate (no dead-end nodes)
- [ ] Save/load mid-game preserves: current scene ID + all narrative flags
- [ ] `tools/run_gut_suite.sh` passes (no new test failures introduced)
- [ ] Camera never unclamps from per-scene limits (no floor-clipping, no out-of-bounds yaw)

## Out-of-scope / deferred

- Hidden "escape?" ending
- Real art/audio (MVP is placeholders)
- Gamepad-specific UI affordances
- Localization beyond English
- A true first-person camera mode
