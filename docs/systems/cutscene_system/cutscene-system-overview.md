# Cutscene System Overview

**Project**: Automata Template (Godot 4.7)
**Created**: 2026-03-31
**Last Updated**: 2026-03-31
**Status**: PRE-IMPLEMENTATION (design phase)
**Scope**: Quality-based cutscene sequencing with camera choreography, powered by scene director beats and vCam blending

## Summary

The cutscene system orchestrates scripted camera sequences, entity actions, and visual effects during non-interactive moments. It extends the existing scene director beat system with new cutscene-specific effect types (`RS_EffectCameraMove`, `RS_EffectCameraBlend`, `RS_EffectTimescale`, `RS_EffectCinemaGrade`) rather than building a parallel sequencing engine. Cutscenes pause gameplay via `M_TimeManager`'s `CHANNEL_CUTSCENE` pause channel (already defined), disable player input, and hand camera control to scripted vCam positions. The system leverages the existing vCam blending infrastructure for smooth camera transitions.

## Repo Reality Checks

- `M_TimeManager` already defines `CHANNEL_CUTSCENE = &"cutscene"` pause channel — infrastructure ready, no consumer exists yet
- `M_VCamManager` supports vCam blending with easing, transition types, and mid-blend interruption (`scripts/core/managers/m_vcam_manager.gd`)
- `M_CameraManager` has `apply_shake_offset()` and scene transition camera (`scripts/core/managers/m_camera_manager.gd`)
- Scene Director `RS_BeatDefinition` supports typed effects, wait modes (INSTANT, TIMED, SIGNAL), and flow control (next_beat_id, parallel fork/join)
- `U_BeatRunner` manages beat execution state machine — cutscene beats execute within this existing runner
- VFX Manager provides screen shake, damage flash, and particle gating
- Display Manager provides cinema grading with per-scene artistic color profiles
- `RS_EffectDispatchAction` and `RS_EffectPublishEvent` already exist as beat effects — cutscene effects follow the same pattern
- Input system: `M_InputDeviceManager` can be disabled/enabled for player input suppression during cutscenes

## Goals

- Provide scripted camera sequences authored as scene director beat chains with cutscene-specific effects
- Leverage existing vCam blending for smooth camera transitions between scripted positions
- Support camera choreography: dolly (move along path), orbit (rotate around point), cut (instant switch), blend (smooth transition)
- Pause gameplay during cutscenes via `CHANNEL_CUTSCENE` pause channel
- Suppress player input during cutscenes (camera and movement)
- Support letterbox bars for cinematic framing
- Allow timescale manipulation during cutscenes (slow-motion for dramatic beats)
- Allow runtime cinema grade transitions (color mood shifts within a cutscene)
- Integrate with VFX (screen shake, particle bursts triggered mid-cutscene)
- Support skippable cutscenes (player presses skip → jump to end state)

## Non-Goals

- No visual timeline editor (author beats in Godot inspector or `.tres` files)
- No Godot `AnimationPlayer` integration for cutscene sequencing (uses beat system instead)
- No pre-rendered video cutscenes (all real-time)
- No NPC animation choreography within this system (animation system handles that; cutscenes trigger animation requests via effects)
- No dialogue display (dialogue system handles text; cutscenes trigger dialogue via `RS_EffectStartDialogue`)
- No camera shake authoring (uses existing VFX Manager shake API)

## Architecture

```
Cutscene System (extends Scene Director with new effect types — not a separate manager)

New Effect Types (scripts/core/resources/qb/effects/):
  ├── RS_EffectCameraMove       → Tween a cutscene vCam to target transform over duration
  ├── RS_EffectCameraBlend      → Blend between two vCams using M_VCamManager
  ├── RS_EffectCameraCut        → Instant switch to a cutscene vCam
  ├── RS_EffectTimescale        → Set M_TimeManager timescale (slow-mo)
  ├── RS_EffectCinemaGrade      → Transition cinema grade profile over duration
  ├── RS_EffectLetterbox        → Show/hide letterbox bars with fade
  ├── RS_EffectSuppressInput    → Enable/disable player input
  └── RS_EffectPauseChannel     → Push/pop a specific pause channel

Cutscene vCam Nodes (placed in gameplay scenes):
  C_VCamComponent instances with is_cutscene_cam = true
  Pre-positioned at authored transforms in the scene
  Not tracked by vCam soft-zone — purely position-driven

Cutscene Beat Chain Example:
  Beat 1: effects=[PauseChannel(cutscene,push), SuppressInput(true), Letterbox(show)]
  Beat 2: effects=[CameraBlend(gameplay_cam → cutscene_cam_1, 1.0s)]
           wait_mode=TIMED, wait_duration=1.5
  Beat 3: effects=[CameraMove(cutscene_cam_1 → target_transform, 2.0s)]
           wait_mode=TIMED, wait_duration=2.5
  Beat N: effects=[CameraBlend(→ gameplay_cam), Letterbox(hide), SuppressInput(false), PauseChannel(cutscene,pop)]
```

## Responsibilities & Boundaries

### Cutscene System owns

- Cutscene-specific effect type implementations (camera move/blend/cut, letterbox, input suppression)
- Cutscene vCam transform interpolation (tweening to target transforms)
- Letterbox bar display (HUD-level cinematic bars)
- Skip logic (jump to final beat, execute cleanup effects)

### Cutscene System depends on

- `M_SceneDirectorManager` + `U_BeatRunner`: Beat sequencing, flow control, effect execution
- `M_VCamManager`: vCam blending API for camera transitions
- `M_CameraManager`: Camera transform application
- `M_TimeManager`: `CHANNEL_CUTSCENE` pause channel push/pop, timescale control
- `M_DisplayManager`: Cinema grade transition
- `M_VFXManager`: Screen shake, damage flash during cutscenes
- `M_InputDeviceManager`: Input suppression

### Cutscene System does NOT own

- Beat sequencing (scene director)
- Camera shake (VFX Manager)
- Dialogue display (dialogue system)
- NPC animation (animation system)
- Cinema grading state (display manager — cutscene system requests transitions)

## New Effect Types Detail

| Effect | Parameters | Runtime Behavior |
|--------|-----------|-----------------|
| `RS_EffectCameraMove` | `target_vcam_path: NodePath`, `target_transform: Transform3D`, `duration: float`, `easing: Tween.EaseType` | Tweens cutscene vCam's transform to target over duration |
| `RS_EffectCameraBlend` | `from_vcam_path: NodePath`, `to_vcam_path: NodePath`, `duration: float`, `easing: Tween.EaseType` | Calls `M_VCamManager.blend_to()` for smooth camera transition |
| `RS_EffectCameraCut` | `to_vcam_path: NodePath` | Instant vCam switch, no blend |
| `RS_EffectTimescale` | `scale: float`, `duration: float` | Sets timescale; optionally tweens back to 1.0 |
| `RS_EffectCinemaGrade` | `grade_resource: RS_SceneCinemaGrade`, `duration: float` | Crossfades cinema grade over duration |
| `RS_EffectLetterbox` | `visible: bool`, `fade_duration: float` | Shows/hides letterbox bars with fade |
| `RS_EffectSuppressInput` | `suppress: bool` | Enables/disables player movement and camera input |
| `RS_EffectPauseChannel` | `channel: StringName`, `action: StringName` (push/pop) | Pushes or pops a pause channel |

## Demo Integration (Signal Lost)

5 cutscene moments authored as scene director beat chains:

1. **Opening Arrival** (15s, 3 beats): Wide establishing shot → sweep to player → blend to orbit cam
2. **Power Restoration** (8s, 3 beats): Screen shake, camera pulls back to wide shot, return to orbit
3. **Antenna Extension** (6s, 2 beats): Cut to exterior roof vCam, antenna extends, cut back
4. **Signal Transmission** (12s, 4 beats): Orbit data core, VFX + timescale 0.5x, cinema grade → white, fade
5. **Epilogue** (10s, 3 beats): Player-level exterior, camera rises to sky, fade to victory

Each cutscene directive has `is_cutscene: true` flag for skip handling.

## Implementation Phases

### Phase 1: Scaffolding Effects
- Create `RS_EffectPauseChannel`, `RS_EffectSuppressInput`, `RS_EffectLetterbox`
- These handle cutscene enter/exit lifecycle
- Unit tests for each effect's `execute()` method

### Phase 2: Camera Effects
- Create `RS_EffectCameraMove`, `RS_EffectCameraBlend`, `RS_EffectCameraCut`
- Integration with `M_VCamManager` blend API
- Cutscene vCam component flag (`is_cutscene_cam`)
- Unit tests with mock vCam setup

### Phase 3: Atmosphere Effects
- Create `RS_EffectTimescale`, `RS_EffectCinemaGrade`
- Tween-based transitions for timescale and cinema grade
- Integration tests with display manager and time manager

### Phase 4: Letterbox & Skip UI
- Letterbox bar HUD element (top + bottom black bars)
- Skip prompt (hold button to skip) → jumps to final beat, executes cleanup effects
- Gamepad/touch skip input support

### Phase 5: Demo Cutscenes
- Author 5 cutscene directives for Signal Lost
- Place cutscene vCam nodes in gameplay scenes
- Author beat chains with all effect types
- Playtest transitions, timing, and camera feel

## Verification Checklist

1. Cutscene pauses gameplay via `CHANNEL_CUTSCENE` and resumes on completion
2. Player input suppressed during cutscene and restored after
3. Camera blends smoothly between gameplay and cutscene vCams
4. Camera move interpolates transform with correct easing
5. Letterbox bars appear/disappear with fade
6. Timescale manipulation works (slow-mo visible)
7. Cinema grade transitions smoothly
8. Skip jumps to end and cleans up state
9. All 5 demo cutscenes play without camera jank
10. Cutscene vCams don't interfere with gameplay vCam soft-zone

## Resolved Questions

| Question | Decision |
|----------|----------|
| Separate cutscene manager? | No. Cutscenes are scene director beat chains with new effect types. No duplicated sequencing. |
| AnimationPlayer for camera? | No. Tween-based interpolation is simpler and data-driven. |
| Letterbox as overlay? | No. HUD-level element — overlays trigger pause stack changes which would conflict. |
| How to skip? | Jump to last beat, execute only cleanup effects (unpause, restore input, hide letterbox, blend back). |

## Links

- Cutscene system plan/tasks/continuation docs are not present yet.
- [Scene Director Overview](../scene_director/scene-director-overview.md)
