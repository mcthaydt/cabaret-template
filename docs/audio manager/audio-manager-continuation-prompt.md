# Audio Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 0–5 complete and fully integrated
  - Phase 0-4: Audio Redux slice + M_AudioManager bus layout + volume/mute + music crossfade + scene/pause music switching + BaseEventSFXSystem pattern + pooled 3D SFX + jump/land/death/checkpoint/victory SFX systems
  - Phase 5: Footstep System (C_SurfaceDetectorComponent + S_FootstepSoundSystem + 24 placeholder footstep assets + scene integration)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`
- **Recent completions** (Phase 5 integration):
  - `C_SurfaceDetectorComponent` at `scripts/ecs/components/c_surface_detector_component.gd` (extends BaseECSComponent, 6 surface types, 15/15 tests passing)
  - `S_FootstepSoundSystem` at `scripts/ecs/systems/s_footstep_sound_system.gd` (per-tick system, velocity-based, 20/20 tests passing)
  - `RS_FootstepSoundSettings` at `scripts/ecs/resources/rs_footstep_sound_settings.gd` (6 surface type arrays with 4 variations each)
  - `resources/settings/footstep_sound_default.tres` (default settings resource with all 24 audio streams wired)
  - 24 footstep placeholder WAV files in `resources/audio/footsteps/` (generated via Python script)
  - Added `C_SurfaceDetectorComponent` to player prefab (`scenes/prefabs/prefab_player.tscn`)
  - Added `S_FootstepSoundSystem` to all 3 gameplay scenes (gameplay_base, gameplay_exterior, gameplay_interior_house)

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/audio manager/audio-manager-tasks.md`
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`

## Repo Reality Checks (Do Not Skip)

- There is **no** `scenes/main.tscn` in this project; `M_AudioManager` already exists in `scenes/root.tscn` under `Managers/`.
- `U_ServiceLocator` lives at `res://scripts/core/u_service_locator.gd` and its API is `U_ServiceLocator.register(...)` / `get_service(...)` / `try_get_service(...)`.
- `S_JumpSoundSystem` at `scripts/ecs/systems/s_jump_sound_system.gd` is implemented (event-driven SFX via BaseEventSFXSystem + pooled 3D spawner).
- `S_FootstepSoundSystem` is per-tick (extends BaseECSSystem), not event-driven, because footsteps are based on continuous movement state.
- `C_SurfaceDetectorComponent` extends BaseECSComponent (not Node3D) for ECS registration, but children can position 3D objects.
- `RS_GameplayInitialState` currently includes a small `gameplay.audio_settings` dictionary + `U_VisualSelectors.get_audio_settings()`; it is not currently used by any real audio playback path.
- `resources/audio/` now exists (music + SFX + footsteps placeholder assets already imported).

## Test Status

- **Unit tests**: 1341 / 1346 passing (99.6%)
  - Phase 0 Redux: 51/51 ✅
  - Phase 1 Manager: 11/11 ✅
  - Phase 2 Music: 4/4 ✅
  - Phase 3 Base SFX: 15/15 ✅
  - Phase 4 SFX Systems: 59/59 ✅
  - Phase 5 Footstep: 35/35 ✅
- **Pending tests**: 5 (scene transition timing tests - headless mode incompatible)
- **Integration tests**: 0 / 100 (Phases 6-9 not started)

## Next Step

- Start at **Phase 6 (Ambient System)** in `docs/audio manager/audio-manager-tasks.md` and complete tasks in order.
- Phase 5 is now fully integrated into gameplay scenes and ready for manual testing.
- After each completed phase:
  - Update `docs/audio manager/audio-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY
