# Demo Game: "Signal Lost" — Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-31
**Last Updated**: 2026-03-31
**Status**: PRE-IMPLEMENTATION (design phase)
**Scope**: Complete <10min demo game showcasing all template systems (existing + new)

## Summary

"Signal Lost" is a short atmospheric 3D exploration game set in an abandoned relay station. The player is a technician responding to an emergency signal. The station's AI — **LUMEN** — has fragmented across 4 subsystems (power, comms, navigation, memory). The player restores each subsystem, reassembles LUMEN, and transmits a rescue signal. Greybox/CSG art with atmospheric lighting, audio, and post-processing. The demo serves as both a polished player experience and a feature showcase for template buyers.

## Why This Demo

- **Brutalist relay station = CSG shapes look intentional**, not placeholder. Industrial geometry reads as stylized, not unfinished.
- **Hub-and-spoke structure** naturally exercises scene management, transitions, objectives DAG, and save checkpoints.
- **3 NPC types** prove GOAP/HTN AI with distinct behavior profiles.
- **LUMEN** carries narrative + dialogue without character art — text + audio atmosphere.
- **5 cutscene moments** prove the cutscene system with camera choreography.
- **2 player choices** prove narrative branching with different endings.
- **Every existing system** gets exercised naturally (no forced showcasing).
- **Cinema grading per room** creates visual identity without textures.
- **Post-processing** (bloom, grain, vignette) elevates CSG dramatically.

## Minute-by-Minute Flow (~8 min)

| Time | Area | What Happens | Key Systems |
|------|------|-------------|-------------|
| 0:00-0:30 | **Exterior** | Opening cutscene: camera sweeps station, LUMEN crackles. Walk to entrance. | Cutscene, vCam blend, Audio ambient (rain/wind) |
| 0:30-1:30 | **Hub** | Central atrium, 4 color-coded corridors (red/blue/green/gold). LUMEN intro dialogue. Only red unlocked. Checkpoint. | Scene Director beats, Objectives, Save, Dialogue, Localization |
| 1:30-3:00 | **Power Core** (red) | 3 power nodes activated in sequence. Patrol Drone NPC blocks path. Screen shake on completion. Cutscene: power grid lights up. | GOAP AI, Animation, Cinema grading (red), VFX shake, Cutscene |
| 3:00-4:30 | **Comms Array** (blue) | Pressure plate sequence puzzle. Sentry NPC investigates wrong attempts. **Dialogue choice**: civilian or military frequency. Antenna cutscene. | HTN AI, Dialogue choices, Narrative flags, Footstep surfaces, vCam blend |
| 4:30-6:00 | **Nav Nexus** (green) | Vertical platforming. Guide Prism NPC shows safe path. Fall = damage + respawn. Landing VFX. | GOAP AI (cooperative), ECS physics, VFX damage flash, Landing particles |
| 6:00-7:30 | **Memory Vault** (gold) | Narrative climax. LUMEN monologue. **Final choice**: shut LUMEN down or leave running. Signal transmission cutscene with timescale slowdown. | Dialogue, Narrative branching, Cutscene, Timescale, Screen shake |
| 7:30-8:00 | **Epilogue** (exterior) | Rain stopped. Choice-dependent farewell. Camera rises to sky. Victory. | Scene transition, Audio change, Victory objective, Save |

## Scene Breakdown

| Scene ID | File | Cinema Grade | Music | Ambient |
|----------|------|-------------|-------|---------|
| `demo_exterior` | `gameplay_demo_exterior.tscn` | Cool neutral | Sparse piano | Rain, wind, ocean |
| `demo_hub` | `gameplay_demo_hub.tscn` | Neutral warm | Ambient electronic | Low hum, distant echoes |
| `demo_power` | `gameplay_demo_power.tscn` | Warm red/amber | Industrial drone | Machinery, electrical crackle |
| `demo_comms` | `gameplay_demo_comms.tscn` | Cool blue | Electronic pulse | Radio static, electronic hum |
| `demo_nav` | `gameplay_demo_nav.tscn` | Green/teal | Ethereal strings | Wind through vertical space |
| `demo_memory` | `gameplay_demo_memory.tscn` | Gold → white | Emotional piano | Deep resonance, data processing |

## Objective Dependency Graph

```
              [enter_station]        (auto-activate)
                    |
              [restore_power]        (depends: enter_station)
               /           \
    [restore_comms]    [restore_nav]  (both depend: restore_power)
               \           /
            [access_memory]           (depends: comms AND nav)
                    |
            [transmit_signal]         (VICTORY, depends: access_memory)
```

6 objectives. Fan-out after power, fan-in before memory.

## NPC Entities

| NPC | Room | Visual (CSG) | AI Type | Behavior |
|-----|------|-------------|---------|----------|
| **Patrol Drone** | Power Core | Sphere + cylinder spotlight, orange | GOAP | Patrol waypoints vs investigate (player activates node) |
| **Sentry** | Comms Array | Box + sphere "eye", blue | HTN | Guard area vs investigate disturbance (wrong plate sequence) |
| **Guide Prism** | Nav Nexus | Prism/pyramid, green + particle trail | GOAP | Show path vs encourage (player fell) vs celebrate (reached goal) |

LUMEN is non-physical — pure dialogue system + scene director beats.

## Dialogue Moments

~50 localization keys across 9 dialogue sets:

| Set | Scene | Lines | Choices |
|-----|-------|-------|---------|
| `lumen_exterior` | Exterior | 1 | — |
| `lumen_hub_intro` | Hub (first) | 3 | — |
| `lumen_hub_power_done` | Hub (after power) | 1 | — |
| `lumen_hub_all_done` | Hub (after comms+nav) | 1 | — |
| `lumen_power` | Power Core | 3 | — |
| `lumen_comms` | Comms Array | 2 | Civilian vs Military |
| `lumen_nav` | Nav Nexus | 3 | — |
| `lumen_memory` | Memory Vault | 3 | Shutdown vs Leave running |
| `lumen_epilogue` | Epilogue | 1 (conditional) | — |

## Cutscene Moments

| # | Scene | Duration | Camera |
|---|-------|----------|--------|
| 1 | Exterior | 15s | Wide establishing → sweep → blend to orbit |
| 2 | Power Core | 8s | Shake + pullback showing power grid |
| 3 | Comms Array | 6s | Cut to roof, antenna extends, cut back |
| 4 | Memory Vault | 12s | Orbit core, timescale 0.5x, grade → white |
| 5 | Epilogue | 10s | Camera rises to sky, fade to victory |

## Narrative Flags

| Flag | Set By | Read By |
|------|--------|---------|
| `chose_civilian` | Comms dialogue choice | Memory Vault monologue variant, epilogue |
| `chose_military` | Comms dialogue choice | Memory Vault monologue variant, epilogue |
| `chose_shutdown` | Memory Vault dialogue choice | Epilogue (silence) |
| `chose_running` | Memory Vault dialogue choice | Epilogue (LUMEN farewell) |

## Full System Coverage

### Existing Systems (all 25+ exercised)
Redux state, ECS, scene management + transitions, audio (music crossfade, ambient, footsteps, SFX, UI sounds), display (post-processing, cinema grading, quality presets), VFX (screen shake ×3, damage flash), vCam (orbit, soft-zone, occlusion, blend), input (KB/gamepad/touch), objectives (6-node DAG), scene director (~12 directives, ~35 beats), save/load (checkpoints + manual), localization (5 languages), accessibility (color blind + dyslexia font + high contrast), QB Rule Manager v2, time manager (world clock, timescale), cursor manager, spawn points, settings hub.

### New Systems (all 4 proven)
- **AI**: 3 NPC profiles (GOAP ×2, HTN ×1) with distinct behaviors
- **Narrative**: Redux slice with 4 flags, 2 choices, branching epilogue
- **Dialogue**: 9 dialogue sets, ~50 localization keys, 2 choice moments, typewriter overlay
- **Cutscene**: 5 scripted camera sequences with vCam blending
- **Animation**: 10 procedural animation states across 3 NPCs

## Resource Budget

| Type | Count |
|------|-------|
| Gameplay scenes | 6 |
| Scene registry entries | 6 |
| Objective definitions | 6 |
| Scene directives | ~12 |
| Beat definitions | ~35 |
| Cinema grades | 6 |
| Audio scene configs | 6 |
| Dialogue sets | 9 |
| Dialogue entries | ~15 |
| Localization keys (dialogue) | ~50 |
| QB rules (NPC AI goals) | ~8 |
| AI brain settings | 3 |
| Animation settings | 3 |
| Procedural animation states | 10 |
| NPC entity prefabs | 3 |
| Cutscene vCam nodes | ~10 |
| Door configs | 10 (5 bidirectional) |

## Implementation Order

The demo depends on the 4 new systems. Recommended build order:

1. **Narrative System** (Phase 1) — Redux slice only, no dependencies on other new systems
2. **Dialogue System** (Phases 1-5) — Depends on narrative slice for flag reads/writes
3. **Animation System** (Phases 1-3) — Independent of narrative/dialogue
4. **AI System** (Phases 1-4) — Depends on animation for `animate` primitive task
5. **Cutscene System** (Phases 1-4) — Independent, but demo content needs scenes built
6. **Demo Content** (scenes, NPCs, resources, localization) — Depends on all 4 systems

## Verification

1. Full playthrough completing all 6 objectives in order
2. Both dialogue branches (civilian/military × shutdown/running = 4 combinations)
3. Each NPC responds to player state (drone avoidance, sentry alerting, guide leading)
4. All 5 cutscenes play without camera jank, blend back to gameplay
5. Toggle every setting mid-game (audio, display, VFX, localization, accessibility)
6. Save at checkpoint, quit, reload — state restored correctly
7. Test KB/mouse, gamepad, and touch through full playthrough
8. Switch to each of 5 languages, verify all text translates
9. Mobile: run on Android, verify preloaded resources work

## Links

- [Demo Plan](demo-signal-lost-plan.md)
- [Demo Tasks](demo-signal-lost-tasks.md)
- [Demo Continuation Prompt](demo-signal-lost-continuation-prompt.md)
- [AI System Overview](../ai_system/ai-system-overview.md)
- [Narrative System Overview](../narrative_system/narrative-system-overview.md)
- [Dialogue System Overview](../dialogue_system/dialogue-system-overview.md)
- [Cutscene System Overview](../cutscene_system/cutscene-system-overview.md)
- [Animation System Overview](../animation_system/animation-system-overview.md)
