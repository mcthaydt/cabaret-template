# Dialogue System Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-31
**Last Updated**: 2026-03-31
**Status**: PRE-IMPLEMENTATION (design phase)
**Scope**: Quality-based dialogue selection and presentation, powered by QB Rule Manager v2

## Summary

The dialogue system selects and presents dialogue lines to the player via a dedicated overlay UI. QB v2 rules score candidate dialogue entries from a dialogue set, the winning entry's lines are played sequentially, and optional player choices execute effects (typically setting narrative flags via `RS_EffectSetField`). The system is a **presentation layer** — it reads narrative state but does not own it. It handles speaker display, localized text with typewriter effect, choice buttons, and auto-advance timing.

## Repo Reality Checks

- Scene director beats already deliver simple text via `signpost_message` events to HUD — dialogue overlay is for richer interactions (speaker, choices, typewriter)
- Localization: `U_LocalizationUtils.localize(key)` and `localize_fmt(key, [args])` for text resolution
- Locale catalogs per domain: `cfg_locale_*_ui.tres`, `cfg_locale_*_hud.tres` — dialogue adds `cfg_locale_*_dialogue.tres`
- Overlay system: `M_SceneManager` manages overlay stack; `scenes/ui/overlays/` for overlay scenes
- UI screen registry: `RS_UIScreenDefinition` resources in `resources/core/ui_screens/`
- QB v2: `U_RuleScorer`, `U_RuleSelector` for scoring dialogue entry candidates
- Time Manager: `CHANNEL_CUTSCENE` exists; dialogue could use a new `CHANNEL_DIALOGUE` or share
- Input: gamepad navigation for choice buttons follows existing overlay patterns (D-pad + A/B)
- Existing overlay controllers extend scripts in `scripts/core/ui/overlays/` with `_on_overlay_entered()` / `_on_overlay_exited()` lifecycle

## Goals

- Select dialogue entries from a dialogue set using QB v2 condition scoring
- Present dialogue via a dedicated overlay: speaker name, localized text, optional choices
- Support typewriter text reveal with skip-ahead on input
- Support auto-advance (timed) and manual advance (input) for lines without choices
- Support player choices that execute QB v2 effects (set narrative flags, publish events, etc.)
- Integrate with localization (all text stored as localization keys)
- Support one-shot entries (play once per playthrough, tracked in dialogue state)
- Support triggered dialogue (NPC interaction, scene director beats) and ambient dialogue (proximity, events)
- Pause gameplay during dialogue via time manager pause channel

## Non-Goals

- No narrative state ownership (narrative system owns flags/arcs via Redux)
- No voice acting / audio playback
- No visual dialogue editor
- No complex dialogue graph / node-based editing
- No NPC portrait/emotion display (greybox demo has no character art)
- No dialogue log / history UI

## Architecture

```
M_DialogueManager (scripts/core/managers/m_dialogue_manager.gd)  [extends Node]
  Registered in ServiceLocator as "dialogue_manager"
  Composes:
  ├── U_DialogueSelector  (NEW, scripts/core/utils/dialogue/u_dialogue_selector.gd)  [extends RefCounted]
  │     Uses U_RuleScorer + U_RuleSelector to pick best entry from a dialogue set
  └── U_DialogueRunner    (NEW, scripts/core/utils/dialogue/u_dialogue_runner.gd)  [extends RefCounted]
        Manages active dialogue sequence: current line index, advance, choice handling, completion

UI_DialogueOverlay (scripts/core/ui/overlays/ui_dialogue_overlay.gd)
  Scene: scenes/ui/overlays/ui_dialogue_overlay.tscn
  Elements:
  ├── Speaker label (localized speaker name)
  ├── Text display (typewriter reveal)
  ├── Choice buttons (0-4, shown only when line has choices)
  └── Advance indicator (shown when waiting for input, hidden during typewriter)

Redux:
  dialogue slice (scripts/core/state/slices/sl_dialogue.gd)  [transient — not persisted]
    ├── is_dialogue_active: bool
    ├── active_set_id: StringName
    ├── active_entry_id: StringName
    ├── current_line_index: int
    └── seen_entry_ids: Array[StringName]  (for one-shot tracking — persisted separately via narrative flags)

Resources:
  RS_DialogueSet (scripts/core/resources/dialogue/rs_dialogue_set.gd)
    ├── set_id: StringName                 (e.g., "lumen_power_room")
    ├── entries: Array[RS_DialogueEntry]
    └── fallback_entry_id: StringName      (if no entry scores > 0)

  RS_DialogueEntry (scripts/core/resources/dialogue/rs_dialogue_entry.gd)
    ├── entry_id: StringName
    ├── conditions: Array[Resource]        (QB v2 typed conditions)
    ├── lines: Array[RS_DialogueLine]      (sequential lines in this entry)
    ├── is_one_shot: bool                  (only play once; tracked via narrative flag)
    └── priority: int                      (tiebreaker for equal scores)

  RS_DialogueLine (scripts/core/resources/dialogue/rs_dialogue_line.gd)
    ├── speaker_key: StringName            (localization key, e.g., "dialogue.speaker.lumen")
    ├── text_key: StringName               (localization key for line text)
    ├── duration: float                    (auto-advance timer; 0.0 = wait for input)
    ├── choices: Array[RS_DialogueChoice]  (empty = no choice, advance normally)
    └── effects: Array[Resource]           (QB v2 effects executed when line displays)

  RS_DialogueChoice (scripts/core/resources/dialogue/rs_dialogue_choice.gd)
    ├── choice_key: StringName             (localization key for button text)
    └── effects: Array[Resource]           (QB v2 effects on selection — e.g., RS_EffectSetField for narrative flags)

New Beat Effect:
  RS_EffectStartDialogue (scripts/core/resources/qb/effects/rs_effect_start_dialogue.gd)
    ├── dialogue_set_id: StringName        (which dialogue set to start)
    Scene director beats use this to trigger dialogue
```

## Dialogue Flow

```
1. Trigger source calls M_DialogueManager.start_dialogue(set_id)
   Sources: NPC interaction component, scene director beat effect, proximity trigger, ECS event
   ↓
2. U_DialogueSelector loads RS_DialogueSet, scores all entries via QB v2
   Context: {"state_store": store, "redux_state": state} (narrative flags available via dot-path)
   ↓
3. Winning entry selected (highest score, priority tiebreak, one-shot filter)
   ↓
4. M_DialogueManager pushes CHANNEL_DIALOGUE pause, requests overlay
   M_SceneManager pushes UI_DialogueOverlay onto overlay stack
   ↓
5. U_DialogueRunner advances through lines sequentially:
   For each line:
   a. Execute line.effects (if any)
   b. Display speaker + text (typewriter reveal)
   c. If choices: show choice buttons, wait for selection, execute choice effects
   d. If no choices: wait for input or auto-advance timer
   ↓
6. All lines complete → M_DialogueManager pops overlay, pops pause channel
   ↓
7. Optional: final line effects may publish events that trigger further game flow
```

## Responsibilities & Boundaries

### Dialogue System owns

- Dialogue entry selection using QB v2 scoring
- Dialogue sequence execution (line advancement, choice handling, completion)
- Dialogue overlay lifecycle (push/pop via scene manager)
- Pause coordination during dialogue (push/pop CHANNEL_DIALOGUE)
- Typewriter text effect and advance input handling
- One-shot tracking (sets narrative flag `dialogue_seen_<entry_id>` via narrative system)
- Localization key resolution for all displayed text
- `RS_EffectStartDialogue` effect type for scene director integration

### Dialogue System depends on

- `M_StateStore`: Reads narrative flags for QB condition evaluation
- `M_SceneManager`: Overlay stack for dialogue UI push/pop
- `M_TimeManager`: CHANNEL_DIALOGUE pause channel push/pop
- `M_LocalizationManager`: Text resolution for dialogue keys
- QB v2 utilities: `U_RuleScorer`, `U_RuleSelector` for entry selection
- Narrative system (Redux slice): Reads flags for conditions; choice effects write flags

### Dialogue System does NOT own

- Narrative state (narrative Redux slice owns flags, arcs, choice history)
- Scene director beat sequencing (scene director triggers dialogue via effects)
- NPC interaction trigger logic (ECS components detect interaction, call dialogue manager)
- Audio/voice playback
- Save/load of dialogue state (one-shot tracking uses narrative flags which persist automatically)

## Demo Integration (Signal Lost)

| Scene | Dialogue Set | Key Lines |
|-------|-------------|-----------|
| Exterior | `lumen_exterior` | LUMEN crackle: "Signal... detected... please... help..." |
| Hub (first visit) | `lumen_hub_intro` | 3 LUMEN lines introducing the station and directing to power core |
| Hub (power done) | `lumen_hub_power_done` | "Two paths are open now..." |
| Hub (all done) | `lumen_hub_all_done` | "The gold corridor awaits..." |
| Power Core | `lumen_power` | Guidance during puzzle + completion line |
| Comms Array | `lumen_comms` | Frequency choice: civilian vs military (2 `RS_DialogueChoice`, sets narrative flags) |
| Nav Nexus | `lumen_nav` | "Follow the light" + encouragement on fall + completion |
| Memory Vault | `lumen_memory` | Monologue + final choice: shutdown vs leave running (sets narrative flags) |
| Epilogue | `lumen_epilogue` | Conditional farewell based on narrative flags (or silence if shutdown chosen) |

~50 localization keys across `cfg_locale_*_dialogue.tres` for 5 languages.

## Implementation Phases

### Phase 1: Dialogue Resources
- Create `RS_DialogueSet`, `RS_DialogueEntry`, `RS_DialogueLine`, `RS_DialogueChoice` resource classes
- Validation: entry IDs unique within set, fallback_entry_id references valid entry
- Unit tests for resource creation and validation

### Phase 2: Dialogue Selector & Runner
- Create `U_DialogueSelector` composing QB v2 for entry scoring
- Create `U_DialogueRunner` managing sequence state machine (current line, advance, choices)
- Unit tests for selection logic and sequence advancement with mock resources

### Phase 3: Dialogue Manager
- Create `M_DialogueManager` orchestrating selector + runner + pause + overlay requests
- Register in ServiceLocator as `"dialogue_manager"`
- Redux `dialogue` slice (transient) for observability
- Integration tests with state store

### Phase 4: Dialogue Overlay UI
- Create `ui_dialogue_overlay.tscn` and `ui_dialogue_overlay.gd`
- Speaker label, text display with typewriter effect, choice buttons, advance indicator
- Register as overlay in UI screen registry (`RS_UIScreenDefinition`)
- Gamepad/touch navigation for choice selection (D-pad + A/B)
- Localization integration for all displayed text

### Phase 5: Scene Director Integration
- Create `RS_EffectStartDialogue` effect type
- Wire scene director beats to trigger dialogue via this effect
- Integration test: beat → dialogue → choice → narrative flag → subsequent beat condition

### Phase 6: Demo Content Authoring
- Author all LUMEN dialogue sets (9 sets, ~50 localization keys)
- Author localization entries for 5 languages
- Playtest full dialogue flow through all scenes

## Verification Checklist

1. QB scoring correctly selects highest-scoring dialogue entry from a set
2. Dialogue overlay displays speaker name and localized text
3. Typewriter text effect works and can be skipped with input
4. Player choices execute effects (narrative flag setting verified)
5. One-shot entries don't repeat after being played
6. Dialogue pauses gameplay and resumes on completion
7. Gamepad and touch can navigate choice buttons
8. All 5 locales display correct translations
9. Scene director beats successfully trigger dialogue via `RS_EffectStartDialogue`
10. Fallback entry plays when no entry scores > 0

## Resolved Questions

| Question | Decision |
|----------|----------|
| Coupled with narrative? | No. Dialogue is presentation + selection. Narrative is pure state (Redux). They interact via Redux reads/writes. |
| Reuse signpost_message? | No. Signpost is for ambient HUD text (simple, no choices). Dialogue gets a dedicated overlay. |
| Pause during dialogue? | Yes. Dedicated `CHANNEL_DIALOGUE` pause channel. |
| One-shot tracking? | Via narrative flags (`dialogue_seen_<entry_id> = true`). Persists with save system automatically. |

## Links

- Dialogue system plan/tasks/continuation docs are not present yet.
- [Narrative System Overview](../narrative_system/narrative-system-overview.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
