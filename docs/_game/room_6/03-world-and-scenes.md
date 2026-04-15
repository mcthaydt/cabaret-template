# 03 — World & Scenes: Room 6

Each scene here becomes a Godot scene under `scenes/gameplay/` (suggested naming `room_6_<slug>.tscn`) plus an `RS_SceneRegistryEntry` under `resources/scene_registry/`. Follow `docs/scene_manager/ADDING_SCENES_GUIDE.md`.

## Camera approach (applies to every scene)

The template's camera is 3D third-person orbit (`RS_VCamModeOrbit`, `S_VCamSystem`). Room 6 uses it **constrained**:

- **Follow target**: an anchor on `pc_traveler` positioned roughly at head height.
- **Distance**: clamped very short (≈ 0.15–0.25 m) so the view reads as near-first-person with the Traveler's shoulder barely visible.
- **Yaw / pitch clamps**: tight per-scene limits authored as vcam swap points (see each scene below). Player look input stays within clamps.
- **Swap points**: each scene defines 2–4 named vcam positions (e.g. "bed view," "mirror view"). Interacting with fixed "look-at" hotspots blends to the matching vcam. Between hotspots, the clamped orbit is free.
- **No new managers**. Implement via existing `RS_VCam*` resources and the rule infrastructure in `resources/qb/camera/`.

Rationale: retains mobile touch drag-look (template-supported), avoids any new camera code for the one-shot, and reproduces the comic's fixed-panel feel via swap points.

## Scene list

### `scene_main_menu`

Not gameplay; lives under `scenes/ui/` (use template's existing main menu pattern). New Game → `scene_highway_arrival`.

### `scene_highway_arrival`

```text
- ID: scene_highway_arrival
- Kind: cutscene
- Background: empty highway at night, single car driving (simple environment; camera on dolly)
- Music: silence + wind + engine hum
- Ambient SFX: wind, distant engine
- Contains NPCs: []
- Contains items: []
- Contains triggers: [cutscene_opening_drive auto-plays on enter]
- Entry conditions: main menu "New Game"
- First-visit cutscene: cutscene_opening_drive
- Vcam swap points: [cutscene_cam_highway_wide, cutscene_cam_motel_approach]
```

### `scene_motel_office`

```text
- ID: scene_motel_office
- Kind: gameplay
- Background: small motel office interior; counter, neon sign visible through window (flickering "VACANCY")
- Music: silence
- Ambient SFX: neon buzz (one letter), distant cicadas
- Contains NPCs: [npc_clerk]
- Contains items: [item_key_6 (on counter after dialogue)]
- Contains triggers: [trigger_talk_clerk_arrival, trigger_exit_office]
- Entry conditions: flag arrived_motel
- First-visit cutscene: none
- Vcam swap points: [office_entry_vcam, office_counter_vcam]
- Exit: trigger_exit_office → scene_room_6 (gate: has_key_6)
```

### `scene_room_6`

The central scene. Layered triggers fire as flags accumulate; the same scene covers pages 2–6 of the comic.

```text
- ID: scene_room_6
- Kind: gameplay
- Background: small motel room: bed (left), TV on dresser (facing bed), mirror on wall (right), bathroom door (back wall), window (front-left), phone on bedside table
- Music: silence
- Ambient SFX: low room tone, HVAC hum
- Contains NPCs: [] (phone voice is environmental dialogue)
- Contains items: [item_bed, item_tv, item_mirror, item_bathroom_door, item_phone, item_wallpaper, item_window]
- Contains triggers: see doc 04
- Entry conditions: flag has_key_6
- First-visit cutscene: none
- Vcam swap points:
    room_bed_vcam            # looking toward bed / bag drop
    room_tv_vcam             # facing TV
    room_mirror_vcam         # facing mirror on right wall
    room_bathroom_vcam       # facing bathroom door on back wall
    room_phone_vcam          # facing bedside phone
    room_wide_vcam           # default exploratory clamp
- Camera clamps (room_wide_vcam): yaw ±90°, pitch -20° / +15°
```

### `scene_room_6_bathroom`

```text
- ID: scene_room_6_bathroom
- Kind: gameplay (sub-area)
- Background: small tiled bathroom; always empty
- Music: silence
- Ambient SFX: faint drip, fluorescent hum
- Contains NPCs: []
- Contains items: [item_bathroom_interior (examine-only)]
- Contains triggers: [trigger_return_to_room]
- Entry conditions: flag opened_bathroom_once OR player opens bathroom door
- Vcam swap points: [bathroom_interior_vcam]
- Transition from scene_room_6: instant (no fade) — comic has no transition between door-open and empty-bathroom
```

### `scene_room_6_morning`

Re-dress of `scene_room_6` with altered object states. Uses the *same* Godot scene with a "morning state" applied (swap materials / toggled props) OR a duplicated scene — implementer's choice, but the scene ID is distinct so the registry tracks it separately.

```text
- ID: scene_room_6_morning
- Kind: gameplay
- Background: identical layout; bright daylight through window; subtle furniture rearrangement
- Music: silence
- Ambient SFX: birds outside, low ambient
- Contains NPCs: []
- Contains items: [item_mirror_smiling (examine-only overlay), item_tv_self_sleeping (examine-only overlay), item_bed_rumpled]
- Contains triggers: [trigger_exit_room_morning]
- Entry conditions: flag closed_eyes
- First-visit cutscene: none (the "morning" reveal is an in-place state swap, not a separate cutscene)
- Vcam swap points: same IDs as scene_room_6 for implementation symmetry
```

### `scene_office_morning`

```text
- ID: scene_office_morning
- Kind: gameplay
- Background: motel office in daylight; sign outside visible through window
- Music: silence
- Ambient SFX: birds, distant traffic
- Contains NPCs: [npc_clerk]
- Contains items: []
- Contains triggers: [trigger_talk_clerk_morning, trigger_step_outside]
- Entry conditions: flag room_rearranged AND player exits scene_room_6_morning
- First-visit cutscene: none
- Vcam swap points: [office_entry_vcam, office_counter_vcam] (reused from scene_motel_office)
```

### `scene_ending_reflection`

```text
- ID: scene_ending_reflection
- Kind: ending (cutscene-only)
- Background: motel exterior by day; neon sign and window visible
- Music: a low drone fades in
- Ambient SFX: neon buzz (morning version), birds abruptly silencing
- Contains NPCs: []
- Contains items: []
- Contains triggers: [cutscene_morning_reveal auto-plays on enter → credits]
- Entry conditions: flag clerk_denied_room_6 AND player steps outside
- Vcam swap points: [exterior_sign_vcam, exterior_window_reflection_vcam]
```

## Scene flow graph

```text
scene_main_menu        --[new_game]-->                                        scene_highway_arrival
scene_highway_arrival  --[cutscene_opening_drive ends]-->                     scene_motel_office
scene_motel_office     --[trigger_exit_office, gate: has_key_6]-->            scene_room_6
scene_room_6           --[interact item_bathroom_door, gate: noticed_door_closed]--> scene_room_6_bathroom
scene_room_6_bathroom  --[trigger_return_to_room]-->                          scene_room_6
scene_room_6           --[trigger_close_eyes, gate: saw_bathroom_reopen]-->   scene_room_6_morning
scene_room_6_morning   --[trigger_exit_room_morning]-->                       scene_office_morning
scene_office_morning   --[trigger_step_outside, gate: clerk_denied_room_6]--> scene_ending_reflection
scene_ending_reflection --[cutscene_morning_reveal ends]-->                   credits
```

## Transitions

| From → To                                           | Transition | Duration |
| --------------------------------------------------- | ---------- | -------- |
| `scene_main_menu → scene_highway_arrival`           | fade       | 1.0s     |
| `scene_highway_arrival → scene_motel_office`        | fade       | 1.0s     |
| `scene_motel_office → scene_room_6`                 | fade       | 0.6s     |
| `scene_room_6 ↔ scene_room_6_bathroom`              | instant    | —        |
| `scene_room_6 → scene_room_6_morning`               | fade-to-black, hold 1.5s, fade-in | 2.5s total |
| `scene_room_6_morning → scene_office_morning`       | fade       | 0.6s     |
| `scene_office_morning → scene_ending_reflection`    | fade       | 1.0s     |
| `scene_ending_reflection → credits`                 | fade       | 1.5s     |

The fade-to-black at step 5 is the "close your eyes" moment — single most important transition in the game.

## Cutscenes

### `cutscene_opening_drive`

```text
- Plays on: scene_highway_arrival entry
- Blocking: yes
- Skippable: yes (hold any input 1s)
- Beats:
  1. Wide shot: empty highway, one car (vcam cutscene_cam_highway_wide)
  2. Caption overlay: "Somewhere past the last exit..." (2.5s)
  3. Cut to motel approach (vcam cutscene_cam_motel_approach)
  4. Neon "VACANCY" sign visible; one letter flickers
  5. Fade to scene_motel_office
- Flags set: arrived_motel
```

### `cutscene_tv_shows_sleeping_self`

Optional cutscene that plays *inside* `scene_room_6` after the player closes their eyes (B041). Implementer can do this as either a short cutscene or an in-scene state swap — the design treats it as a cutscene for clarity.

```text
- Plays on: trigger_close_eyes resolves
- Blocking: yes
- Skippable: no
- Beats:
  1. Black panel, 1.0s silence
  2. Room fades back in; vcam pans slowly across: rumpled bed, TV showing Traveler sleeping, mirror reflection smiling
  3. Transition to scene_room_6_morning
- Flags set: room_rearranged, saw_self_sleeping, saw_mirror_smile
```

### `cutscene_morning_reveal`

```text
- Plays on: scene_ending_reflection entry
- Blocking: yes
- Skippable: no
- Beats:
  1. Exterior shot of motel sign (vcam exterior_sign_vcam)
  2. Sign flickers: "NO VACANCY" → glitches → "EXCEPT ONE"
  3. Cut to window reflection (vcam exterior_window_reflection_vcam)
  4. Reflection shows Traveler still inside Room 6
  5. Hold 2.5s, fade to credits
- Flags set: saw_reflection_self, ending_trapped
```

## Camera / vcam rules

- Default across scenes: constrained orbit at ~0.2 m distance around the Traveler's head anchor.
- Per-scene vcam swap points listed per scene above.
- Use existing `qb/camera/` rule resources as patterns (e.g. `cfg_camera_landing_impact_rule.tres` — ignore for Room 6, no jumping) but **do not reuse shake/landing-impact rules**; Room 6 has no impacts.
- Add a single new rule if needed: `cfg_camera_room6_clamp_rule.tres` that enforces the tight clamp when the player isn't in a swap-point-targeted state.

## Environment details per scene (layout sketches)

### `scene_room_6` layout

```text
+------------------------------+
| [window]            [mirror] |
|                              |
|  [bed]    [phone]            |
|    ^bag_drop_point           |
|                              |
|  [TV on dresser]             |
|                              |
|  [pc_traveler spawn]         |
|                              |
|                  [bathroom]  |
+------------------------------+

Door to hallway: out of frame on the +y side (door closes on entry; reopening is not a story beat).
Bathroom door: back wall, slightly ajar on first entry (per comic P2.2).
```
