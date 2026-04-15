# 02 — Story & Characters: Room 6

## Premise

A traveler pulls off a deserted highway at night and checks into the only motel in sight. The clerk — tired, too still — slides them a key marked "6" and murmurs, *"Don't ignore the room."* Inside, small things are wrong: the bathroom door closes itself, the TV shows the room from angles that shouldn't exist, the phone rings with a warning from someone who shouldn't know they're there. By morning the clerk insists there's no Room 6. The traveler steps outside and sees themselves, still in the window. They never actually left.

## Setting

- Time / place: present day, 3 AM, rural highway motel, United States
- World rules (constrain everything that follows):
  1. The room reacts to observation. Looking *away* is when things shift; looking *at* freezes them.
  2. The Traveler cannot actually leave Room 6 once inside. Apparent exits are illusions, reset after the morning reveal.
  3. There is only one instance of the Traveler at any time — the "other" on the TV / in the mirror is a displaced observation, not a second character.

## Protagonist

- ID: `pc_traveler`
- Name / pronouns: unspecified / they
- Voice / speech style: terse, unadorned, a little weary. Never breaks the fourth wall. Inner monologue (rare) is unvoiced — rendered as caption text only.
- Starting inventory: `item_bag` (unused except to drop on bed)
- Starting scene: `scene_highway_arrival` (cutscene), then `scene_motel_office`

## NPCs

```text
- ID: npc_clerk
- Name / role: the Clerk
- Located in: scene_motel_office (arrival) and scene_office_morning (morning)
- Wants: unclear; performs the check-in ritual and nothing else
- Blocks progress until: hands key (flag has_key_6); in the morning, blocks until dialogue exit
- Voice: flat, polite, one beat behind every question. Does not elaborate.
```

No other NPCs. The *Phone Voice* (page 5) and the *Mirror Reflection* (pages 6–7) are treated as **environmental dialogue sources**, not NPCs. They have dialogue trees but no embodied presence.

## Narrative flags

Snake_case. These are the keys in the narrative state slice. An implementation can extend this table but must not rename.

| Flag ID                     | Set when                                                                 | Read by                        |
| --------------------------- | ------------------------------------------------------------------------ | ------------------------------ |
| `arrived_motel`             | opening cutscene `cutscene_opening_drive` ends                           | scene_motel_office entry       |
| `met_clerk`                 | dialogue `clerk.arrival.root` entered                                     | clerk.arrival branches         |
| `has_key_6`                 | dialogue `clerk.arrival.key_handed` completes                             | scene_room_6 entry gate        |
| `entered_room`              | player enters `scene_room_6` for the first time                          | B016+ triggers                 |
| `dropped_bag`               | player interacts with bed                                                 | B017 gate                      |
| `noticed_door_closed`       | observation trigger `obs_door_closed_itself` fires                        | B020 gate                      |
| `opened_bathroom_once`      | player opens bathroom door                                                | B022 gate (TV turns on)        |
| `saw_tv_static`             | TV static visible to camera                                               | B025 gate                      |
| `saw_tv_delay`              | observation trigger `obs_tv_delay` fires (player waves)                   | B028 gate                      |
| `saw_tv_behind_self`        | observation trigger `obs_tv_behind_self` fires                            | B029 gate (phone call)         |
| `answered_phone`            | dialogue `phone.voice.root` entered                                       | B032 branches                  |
| `heard_dont_sleep`          | dialogue `phone.voice.warn_sleep` completes                               | B033 gate (lights flicker)     |
| `saw_wallpaper_faces`       | observation trigger `obs_wallpaper_faces` fires                           | B036 gate                      |
| `saw_mirror_mismatch`       | observation trigger `obs_mirror_mismatch` fires                           | B038 gate                      |
| `saw_bathroom_reopen`       | observation trigger `obs_bathroom_reopens` fires                          | B040 gate                      |
| `closed_eyes`               | player holds interact on "close eyes" prompt ≥1s                          | B041 (room rearranges)         |
| `room_rearranged`           | `scene_room_6_morning` dressing applied                                   | B043 gate                      |
| `saw_self_sleeping`         | TV shows Traveler in bed                                                  | B044 gate                      |
| `saw_mirror_smile`          | morning mirror shows smiling reflection                                   | B044 gate                      |
| `checked_out`               | dialogue `clerk.morning.checkout` entered                                 | B048                           |
| `clerk_denied_room_6`       | dialogue `clerk.morning.no_such_room` completes                           | B050 gate (step outside)       |
| `saw_reflection_self`       | `scene_ending_reflection` cutscene plays                                  | ending credits                 |
| `ending_trapped`            | credits start                                                             | —                              |

## Dialogue trees

Node addresses: `<source>.<tree>.<node>`. Every tree must have a path to `exit`.

### `clerk.arrival`

```text
entry: root
nodes:
  root:
    npc: "Got a room?"          # player-initiated; this is the Clerk's response after the Traveler's opening line
    choices:
      - text: "Yeah. Anything'll do."
        next: key_handed
  key_handed:
    npc: "Just one left."
    effect: set_flag:has_key_6
    # animation: clerk slides key across counter
    choices:
      - text: "(take the key)"
        next: warning
  warning:
    npc: "Don't ignore the room."
    choices:
      - text: "(leave)"
        effect: set_flag:met_clerk
        next: exit
      - text: "What does that mean?"
        next: no_answer
  no_answer:
    npc: "…"                     # Clerk does not answer
    choices:
      - text: "(leave)"
        effect: set_flag:met_clerk
        next: exit
  exit: {}
```

### `phone.voice`

Triggered when player picks up ringing phone in Room 6 (B030). Text is jagged / corrupted-render style. Lines quoted from the comic verbatim.

```text
entry: root
nodes:
  root:
    npc: "…don't fall asleep…"
    choices:
      - text: "Who is this?!"
        next: warn_motion
  warn_motion:
    npc: "…it moves when you don't look…"
    effect: set_flag:heard_dont_sleep
    choices:
      - text: "(silence)"
        next: exit
      - text: "Where are you?"
        next: no_answer
  no_answer:
    npc: "<static>"
    choices:
      - text: "(hang up)"
        next: exit
  exit:
    effect: set_flag:answered_phone
```

### `clerk.morning`

```text
entry: root
nodes:
  root:
    npc: "Checking out?"
    choices:
      - text: "Yeah. Room 6."
        next: no_such_room
        effect: set_flag:checked_out
  no_such_room:
    npc: "We don't have a Room 6."
    effect: set_flag:clerk_denied_room_6
    choices:
      - text: "What?"
        next: insist
      - text: "(leave the office)"
        next: exit
  insist:
    npc: "We don't have a Room 6."       # identical line, identical delivery
    choices:
      - text: "(leave the office)"
        next: exit
  exit: {}
```

### Authoring rules (enforced at implementation)

- Every tree terminates. No orphaned nodes.
- Gated choices (none in this game yet) would hide rather than grey out — consistent with the minimal UI.
- Line length ≤ 200 chars. Phone lines are short by design (jagged overlay rendering).
- The Clerk speaks identical lines when insisted upon (no escalation). This is a deliberate tone choice.

## Cast-wide voice rules

- No profanity. No modern slang.
- NPCs never reference the player's prior choices across scenes (except via flags listed above).
- Phone lines and mirror lines are **lowercase with ellipses**. Clerk lines are **plain sentence case**. This visual distinction should persist in the UI.
- No internal monologue except as minimal captions during the opening drive (`"Somewhere past the last exit..."`).
