# 04 — Interactions, Observations, UI, Input, Save: Room 6

Room 6 has **no traditional puzzles**. In place of puzzles, the game uses **observation triggers** — scripted moments that fire when the player looks at or interacts with a specific object, setting a flag that gates the next beat.

## Items

All items in this game are in-scene props, not inventory objects (except the starting bag, which is only ever dropped). Keep the inventory UI present for consistency but largely empty.

```text
- ID: item_bag
- Display name: "overnight bag"
- Description: "Your bag. Empty except for what you need."
- Art: grey rectangular prism
- Starts in: pc_inventory
- Can be: [drop_on_bed]
- Consumed on use: no (removed from inventory after drop)
- Sets flag on pickup: —
- Sets flag on drop: dropped_bag
```

```text
- ID: item_key_6
- Display name: "motel key, tag '6'"
- Description: "A brass tag, '6' stamped in black. Heavier than it should be."
- Art: grey diamond + label
- Starts in: nowhere (spawned on counter after dialogue clerk.arrival.key_handed)
- Can be: [pick_up, examine]
- Consumed on use: yes (disappears when scene_room_6 entered)
- Sets flag on pickup: has_key_6 (already set by dialogue; idempotent)
```

```text
- ID: item_tv
- Display name: "television"
- Description: varies by state — off / static / room-from-above / Traveler-behind-self / Traveler-sleeping
- Art: dark quad on dresser, render-target texture
- Starts in: scene_room_6 (off)
- Can be: [examine] (interact does nothing)
- State machine:
    off                 -> static            on flag opened_bathroom_once
    static              -> room_from_above   on flag saw_tv_static (auto after 2s)
    room_from_above     -> delayed_mirror    on flag saw_tv_delay (player waves)
    delayed_mirror      -> behind_self       on flag saw_tv_behind_self (auto after player turns away)
    <any>               -> self_sleeping     on flag closed_eyes (applies in scene_room_6_morning)
- Sets flag on examine per state: saw_tv_static, saw_tv_delay, saw_tv_behind_self, saw_self_sleeping
```

```text
- ID: item_mirror
- Display name: "mirror"
- Description: varies — normal / posture-mismatch / smiling (morning)
- Art: reflective quad; uses a separate scene-tree viewport to render the Traveler with adjustable pose offset
- Starts in: scene_room_6
- Can be: [examine]
- Sets flag on examine: saw_mirror_mismatch (during scene_room_6 after saw_wallpaper_faces); saw_mirror_smile (morning)
```

```text
- ID: item_bathroom_door
- Display name: "bathroom door"
- Description: "The door to the bathroom. Slightly ajar." → "Closed." → "Slowly opening."
- Art: hinged quad
- Starts in: scene_room_6 (slightly ajar)
- Can be: [interact (open/close), examine]
- State transitions drive observation triggers — see below
- Sets flag on interact first-time: opened_bathroom_once
```

```text
- ID: item_phone
- Display name: "bedside phone"
- Description: "A cream-colored landline phone. Silent." → "Ringing."
- Art: small prism on a box
- Starts in: scene_room_6 (silent)
- Can be: [interact (pick up / hang up)]
- State machine:
    silent -> ringing on flag saw_tv_behind_self
    ringing -> active_call on interact (plays dialogue phone.voice)
    active_call -> silent on dialogue exit
- Sets flag on interact: answered_phone (via dialogue effect)
```

```text
- ID: item_wallpaper
- Display name: "wallpaper"
- Description: "A beige floral pattern." → "The pattern has faces now."
- Art: textured wall; swaps to alternate texture when observed
- Starts in: scene_room_6
- Can be: [examine]
- Sets flag on examine: saw_wallpaper_faces (only after heard_dont_sleep)
```

```text
- ID: item_window
- Display name: "window"
- Description: "A parking lot, a single lamp, nothing else." (Room 6) / "Your own reflection." (ending)
- Art: quad with offset reflection render
- Starts in: scene_room_6 and scene_ending_reflection
- Can be: [examine]
- Sets flag on examine (ending): saw_reflection_self
```

Bed, dresser, and other furniture are not items — they're set dressing without `examine`.

## Interaction verbs

Scheme: **single-verb `interact`** (context-sensitive) + **`examine`** (when the prop supports it). No `talk` verb — dialogue triggers via `interact` on NPCs.

| Verb      | Keyboard    | Mouse            | Gamepad    | Touch                              |
| --------- | ----------- | ---------------- | ---------- | ---------------------------------- |
| look      | W/A/S/D or arrow keys (camera yaw/pitch via mouse) | mouse move (when captured) | right stick | drag on screen |
| interact  | `E`         | left-click       | `A`        | tap on highlighted prop            |
| examine   | `Q`         | right-click      | `Y`        | long-press (≥400ms) on prop        |
| hold-interact (for "close eyes") | `E` (hold 1s) | LMB hold | `A` hold | tap-and-hold              |
| pause     | `Esc`       | —                | `Start`    | on-screen ☰ button (top-right)     |

These bindings are added to `resources/input/profiles/` as a new "Room 6" profile, or extend the default if no conflict.

## Observation triggers (the "puzzles")

Each trigger fires once, sets a flag, and may change an object's state. Triggers are authored as small `BaseECSSystem`s or scene-local `Area3D` signals — implementer's choice. Listed in fire order.

```text
- ID: obs_door_closed_itself
- Fires when: player is in scene_room_6, has flag dropped_bag, and turns camera back toward bathroom vcam
- Effect: bathroom_door state → closed (was ajar); set flag noticed_door_closed
- Cosmetic: silent (no SFX — matches comic "no sound effect")
```

```text
- ID: obs_tv_turns_on
- Fires when: flag opened_bathroom_once set AND player exits scene_room_6_bathroom back to scene_room_6
- Effect: tv state → static; set flag saw_tv_static (after 2s on-screen)
- Cosmetic: sudden pop of static audio
```

```text
- ID: obs_tv_shows_ceiling_view
- Fires when: flag saw_tv_static AND player looks at TV
- Effect: tv state → room_from_above
- Cosmetic: the TV shows the room from a top-down angle; when the player tilts camera up to "check the ceiling," nothing is there (beat B025)
```

```text
- ID: obs_tv_delay
- Fires when: player waves hand (mouse/touch movement while vcam is room_tv_vcam, OR dedicated "wave" interact prompt)
- Effect: TV echoes the motion ~1s late; set flag saw_tv_delay
- Cosmetic: TV shows player with 1s buffer delay
```

```text
- ID: obs_tv_behind_self
- Fires when: flag saw_tv_delay AND player turns camera away from TV (yaw > 90° from tv anchor)
- Effect: next glance at TV shows Traveler standing behind themselves; set flag saw_tv_behind_self
- Cosmetic: subtle low hum ramps on
```

```text
- ID: obs_phone_call
- Fires when: flag saw_tv_behind_self (phone starts ringing)
- Effect: dialogue phone.voice plays on interact; flag answered_phone / heard_dont_sleep set via dialogue
- Cosmetic: ringing SFX, loud in silence
```

```text
- ID: obs_wallpaper_faces
- Fires when: flag heard_dont_sleep AND player examines wallpaper
- Effect: wallpaper texture swaps to faces variant; set flag saw_wallpaper_faces
- Cosmetic: lights flicker red briefly on entry (scene-wide event, not this trigger)
```

```text
- ID: obs_mirror_mismatch
- Fires when: flag saw_wallpaper_faces AND player examines mirror
- Effect: reflection pose offsets (3–5° shoulder twist, head tilt); on player's fast camera-flick back, reflection normalizes; set flag saw_mirror_mismatch
- Cosmetic: brief asymmetry; no SFX
```

```text
- ID: obs_bathroom_reopens
- Fires when: flag saw_mirror_mismatch AND camera faces bathroom_vcam
- Effect: bathroom door slowly swings open (no one inside, slightly out of focus); set flag saw_bathroom_reopen
- Cosmetic: wood creak (faint)
```

```text
- ID: obs_close_eyes
- Fires when: flag saw_bathroom_reopen; "close eyes" prompt appears
- Effect: on hold-interact ≥1s, fade to black, play cutscene_tv_shows_sleeping_self, enter scene_room_6_morning; set flag closed_eyes
- Cosmetic: this is the emotional pivot of the game; UI hides completely during the prompt
```

All observation triggers must be idempotent: if conditions re-fire, they must not re-set a flag that's already set, and must not replay their cosmetic effect.

## UI screens

Each becomes an `RS_UIScreenDefinition` registered via `U_UIRegistry`. See `docs/ui_manager/`.

| Screen ID           | Purpose                        | Triggered by             | Layer    |
| ------------------- | ------------------------------ | ------------------------ | -------- |
| `ui_main_menu`      | title + New Game / Continue    | boot                     | base     |
| `ui_pause`          | pause + resume / quit          | pause action             | overlay  |
| `ui_dialogue`       | NPC lines + player choices     | dialogue_system          | overlay  |
| `ui_phone`          | jagged phone-call overlay      | phone.voice dialogue     | overlay  |
| `ui_interact_prompt`| small world-space prompt near interactables | proximity   | hud      |
| `ui_caption`        | lower-third caption (drive intro, "close eyes" prompt) | cutscene / obs_close_eyes | overlay |
| `ui_credits`        | end card                       | cutscene_morning_reveal  | base     |

Custom screens' details:

```text
- ID: ui_phone
- Layout sketch: centered black-bleed overlay, jagged lowercase text, occasional flicker; shows choices in the same jagged font
- Data source: dialogue_system (phone.voice tree)
- Dismiss behavior: auto on dialogue exit
```

```text
- ID: ui_interact_prompt
- Layout sketch: small "E / tap" icon + one-line verb ("examine" / "interact") near prop at screen-edge offset
- Data source: ECS query — entities with tag "interactable" within interact range of pc_traveler
- Dismiss behavior: auto when out of range
- Hides during: cutscenes, dialogue, pause
```

```text
- ID: ui_caption
- Layout sketch: lower-third; monospaced; auto-fade after duration
- Data source: triggered by cutscenes and obs_close_eyes
```

## HUD

- Always visible: none. The HUD is invisible by default — the game is about looking at the world.
- Contextual: `ui_interact_prompt` (near interactables), `ui_caption` (scripted beats)
- Hidden during: cutscenes, dialogue, menus, observation trigger peaks (the "close eyes" prompt hides everything first)

## Input bindings summary

See verb table above. Additional rules:

- Mouse captured while in-scene (relative mouse mode). `Esc` releases + opens pause.
- Touch: on-screen pause button only; all other input is gestural.
- Gamepad accepted but not tuned — the one-shot does not ship with gamepad HUD affordances.

## Save / load model

Minimal. Feeds `save_manager`.

- [x] Current scene ID
- [x] All narrative flags
- [ ] Protagonist position in scene — **not persisted**; on reload, spawn at the scene's default spawn point
- [x] Dialogue node history per tree (to mark "already heard" for the Clerk and Phone trees)
- [ ] Inventory — **not persisted** (effectively empty after scene_motel_office)
- [x] Puzzle / observation trigger fired states (derivable from flags; don't double-store)

Save triggers:

- [x] Autosave on scene transition (every fade)
- [x] Manual save from pause menu (single-slot, overwrites autosave)
- [ ] Checkpoints before cutscenes — not needed; transitions already autosave

Slot model: **single slot**. Genre convention + simplicity.

## Audio rules

- Music: silence during all Room 6 scenes. Drone fades in only during `cutscene_morning_reveal`.
- SFX categories: ambient, interact, phone_ring, tv_static, wood_creak, neon_buzz
- Master / music / SFX buses: use the template's default `default_bus_layout.tres`
- Mobile: the template's CPU throttling + FPS cap are fine; no audio-specific overrides needed

## Accessibility

- [x] Subtitles always on (all spoken/phoned dialogue is text-only anyway)
- [x] No timed puzzles (the only "timed" input is hold-interact for close-eyes, which has no failure state)
- [x] Colorblind-safe (game is almost entirely desaturated)
- [ ] Text size scalable — deferred to post-MVP

## Done-definition cross-check

- [ ] Every `item_id` referenced in docs 01–03 and 05 is defined here
- [ ] Every `flag_id` referenced anywhere is either set by dialogue/trigger here or by flags listed in doc 02
- [ ] Every observation trigger's prerequisite flag exists (no forward references to unset flags)
- [ ] Every UI screen used in the golden path is listed above
- [ ] Every input verb used in doc 05 has bindings for keyboard/mouse AND touch
- [ ] Every beat in doc 05's **Next-beat gate** column corresponds to a flag, trigger, or cutscene-end defined in docs 02/03/04
