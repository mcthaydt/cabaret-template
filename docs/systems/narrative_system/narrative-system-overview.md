# Narrative System Overview

**Project**: Automata Template (Godot 4.7)
**Created**: 2026-03-31
**Last Updated**: 2026-03-31
**Status**: PRE-IMPLEMENTATION (design phase)
**Scope**: Quality-based narrative state tracking and story branching via Redux, powered by QB Rule Manager v2

## Summary

The narrative system tracks story progression through a Redux `narrative` slice containing flags, choice history, and arc state. It is a **pure state system** — it stores and queries narrative data but does not present UI or play dialogue. Other systems (dialogue, scene director, objectives) read narrative state via selectors to make branching decisions. Player choices set narrative flags via Redux actions; QB v2 conditions in other systems check those flags to select appropriate content.

## Repo Reality Checks

- Redux slice registration: `U_StateSliceManager.initialize_slices()` in `scripts/core/state/slices/u_state_slice_manager.gd`
- Slice pattern: `sl_*.gd` files in `scripts/core/state/slices/`, actions in `scripts/core/state/actions/`, reducers in `scripts/core/state/reducers/`, selectors in `scripts/core/state/selectors/`
- `RS_StateSliceConfig` controls persistence (`is_transient`, `transient_fields`)
- QB v2 `RS_ConditionReduxField` can already read any Redux field — narrative flags are queryable by existing conditions
- Objectives system already uses Redux state + QB conditions for progression gating
- Scene director beats already evaluate QB conditions for directive/beat selection
- Save system persists non-transient slices automatically
- `RS_EffectSetField` can set arbitrary Redux fields — could set narrative flags from dialogue choices or beat effects

## Goals

- Provide a Redux `narrative` slice for persistent story state (flags, choices, arcs)
- Support narrative flags as key-value pairs (StringName → Variant) for maximum flexibility
- Track player choice history with timestamps for debugging and analytics
- Support narrative arcs (named story threads that can be active or completed)
- Provide selectors for querying narrative state (flag values, arc status, choice history)
- Integrate with save/load system automatically via Redux persistence
- Be consumed by other systems (dialogue, scene director, objectives) via QB conditions reading Redux state

## Non-Goals

- No UI presentation (dialogue system handles text display)
- No dialogue selection logic (dialogue system handles that)
- No cutscene triggering (cutscene system handles that)
- No quest/objective tracking (objectives system handles that)
- No relationship/reputation system
- No procedural narrative generation

## Architecture

```
Redux narrative slice (pure state — no manager node needed):

  sl_narrative.gd  (scripts/core/state/slices/sl_narrative.gd)
    State shape:
    ├── narrative_flags: Dictionary      (StringName → Variant, e.g., {"chose_civilian": true, "lumen_trust": 3})
    ├── choice_history: Array[Dictionary] ([{"choice_id": "freq_select", "value": "civilian", "timestamp": 12345}])
    ├── current_arc_id: StringName       (active story thread, e.g., "signal_lost_main")
    └── completed_arcs: Array[StringName]

  U_NarrativeActions  (scripts/core/state/actions/u_narrative_actions.gd)
    ├── set_flag(flag_name: StringName, value: Variant)
    ├── clear_flag(flag_name: StringName)
    ├── record_choice(choice_id: StringName, value: Variant)
    ├── set_arc(arc_id: StringName)
    ├── complete_arc(arc_id: StringName)
    └── reset_narrative()

  U_NarrativeReducers  (scripts/core/state/reducers/u_narrative_reducers.gd)
    Pure functions handling each action type

  U_NarrativeSelectors  (scripts/core/state/selectors/u_narrative_selectors.gd)
    ├── get_flag(state, flag_name) → Variant
    ├── has_flag(state, flag_name) → bool
    ├── get_choice_history(state) → Array
    ├── get_current_arc(state) → StringName
    ├── is_arc_completed(state, arc_id) → bool
    └── get_all_flags(state) → Dictionary

Integration with existing QB conditions:
  RS_ConditionReduxField can query "narrative.narrative_flags.chose_civilian"
  via U_PathResolver dot-path traversal into the narrative slice
```

## Responsibilities & Boundaries

### Narrative System owns

- Redux `narrative` slice definition (state shape, actions, reducers, selectors)
- Narrative flag CRUD operations
- Choice history recording
- Arc lifecycle (active → completed)

### Narrative System depends on

- `M_StateStore`: Redux store for state management
- Save system: Automatic persistence via non-transient slice config

### Narrative System does NOT own

- Dialogue presentation (dialogue system)
- Dialogue line selection (dialogue system)
- Story beat sequencing (scene director)
- Objective/progression tracking (objectives system)
- Any UI or visual presentation

## Demo Integration (Signal Lost)

Narrative flags used:

| Flag | Set By | Read By |
|------|--------|---------|
| `chose_civilian` | Dialogue choice effect (Comms room) | Scene director beat conditions (Memory Vault monologue variant) |
| `chose_military` | Dialogue choice effect (Comms room) | Scene director beat conditions (Memory Vault monologue variant) |
| `chose_shutdown` | Dialogue choice effect (Memory Vault) | Scene director beat conditions (epilogue variant) |
| `chose_running` | Dialogue choice effect (Memory Vault) | Scene director beat conditions (epilogue variant) |

Arc: `signal_lost_main` — set active on game start, completed on signal transmission.

## Implementation Phases

### Phase 1: Redux Slice
- Create `sl_narrative.gd` with state shape
- Create `U_NarrativeActions` with all action creators
- Create `U_NarrativeReducers` with pure reducer functions
- Create `U_NarrativeSelectors` with all selector functions
- Create `RS_StateSliceConfig` for narrative (persisted, not transient)
- Register in `U_StateSliceManager.initialize_slices()`
- Unit tests for all actions/reducers/selectors

### Phase 2: QB Integration Verification
- Verify `RS_ConditionReduxField` can read `narrative.narrative_flags.*` via `U_PathResolver`
- Verify `RS_EffectSetField` can write narrative flags from beat/dialogue effects
- Integration test: set flag → condition reads flag → confirms score > 0

### Phase 3: Demo Content
- Author narrative flag names for Signal Lost demo
- Wire dialogue choice effects to set narrative flags
- Wire scene director beat conditions to read narrative flags for branching
- Playtest both choice paths

## Verification Checklist

1. Narrative flags persist through save/load cycle
2. `RS_ConditionReduxField` reads narrative flags correctly via dot-path
3. `RS_EffectSetField` sets narrative flags correctly
4. Choice history records with timestamps
5. Arc lifecycle (set active → complete) works
6. `reset_narrative()` clears all state for new game
7. Both demo choice paths produce different scene director behavior

## Resolved Questions

| Question | Decision |
|----------|----------|
| Separate from dialogue? | Yes. Narrative is pure state (Redux slice). Dialogue is presentation + selection. They interact via Redux, not coupling. |
| Manager node needed? | No. Pure Redux slice — actions/reducers/selectors only. No runtime node needed. |
| Flag types? | `Dictionary` with `Variant` values — supports bool, int, float, StringName for maximum flexibility. |

## Links

- Narrative system plan/tasks/continuation docs are not present yet.
- [Dialogue System Overview](../dialogue_system/dialogue-system-overview.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
