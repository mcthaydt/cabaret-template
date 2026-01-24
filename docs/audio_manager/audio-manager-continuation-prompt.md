# Audio Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 0–9 complete and fully integrated; Phase 10 in progress
  - Phase 0-4: Audio Redux slice + M_AudioManager bus layout + volume/mute + music crossfade + scene/pause music switching + BaseEventSFXSystem pattern + pooled 3D SFX + jump/land/death/checkpoint/victory SFX systems
  - Phase 5: Footstep System (C_SurfaceDetectorComponent + S_FootstepSoundSystem + 24 placeholder footstep assets + scene integration)
  - Phase 6: Ambient System (S_AmbientSoundSystem + dual-player crossfade + scene-based ambient selection + 2 placeholder ambient assets + scene integration)
  - Phase 7: UI Sound Integration (U_UISoundPlayer + AudioManager UIPlayer + input-gated BasePanel focus sounds + common UI confirm/cancel/tick wiring)
  - Phase 8: Audio Settings UI (Settings hub entry + Audio settings overlay + Apply/Cancel/Reset pattern wired to Audio Redux slice)
  - Phase 9: Integration Testing (100/100 audio integration tests passing across 4 suites)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/root.gd` registers manager services via `U_ServiceLocator`
- **Recent completions** (Phase 9 integration testing):
  - Added 4 integration suites (100 tests): `tests/integration/audio/test_audio_settings_ui.gd`, `tests/integration/audio/test_audio_integration.gd`, `tests/integration/audio/test_music_crossfade.gd`, `tests/integration/audio/test_sfx_pooling.gd`
  - Added shared helper: `tests/helpers/u_audio_test_helpers.gd`
  - Restored Apply/Cancel/Reset pattern for Audio Settings UI (Apply dispatches, Cancel discards; Reset applies defaults immediately)
  - Footstep cadence now scales with movement speed; SFX spawner now guards invalid config types and clamps pitch_scale

- **Phase 10 fixes** (Manual QA follow-up):
  - Pause overlay music now resumes the pre-pause track position (no restart): `scripts/managers/m_audio_manager.gd`
  - Footstep cadence tuned to realistic timing at default movement speed (no per-tick spam): `scripts/ecs/systems/s_footstep_sound_system.gd`, `scripts/ecs/resources/rs_footstep_sound_settings.gd`, `resources/base_settings/audio/footstep_sound_default.tres`
  - Audio settings now preview volume/mute changes live while editing; Apply persists: `scripts/ui/settings/ui_audio_settings_tab.gd`, `scripts/managers/m_audio_manager.gd`

- **Previous completions** (Phase 7 integration):
  - `U_UISoundPlayer` at `scripts/ui/utils/u_ui_sound_player.gd` (focus/confirm/cancel/tick + 100ms tick throttle)
  - `tests/unit/ui/test_ui_sound_player.gd` (5/5 tests)
  - `M_AudioManager` UI playback at `scripts/managers/m_audio_manager.gd` (`UIPlayer` on UI bus + `_UI_SOUND_REGISTRY` + `play_ui_sound()`)
  - `BasePanel` focus sounds at `scripts/ui/base/base_panel.gd` (plays focus sound via `Viewport.gui_focus_changed`, armed only by player navigation input; initial focus silent)
  - `S_AmbientSoundSystem` at `scripts/ecs/systems/s_ambient_sound_system.gd` (dual-player crossfade, scene-based selection, extends BaseECSSystem)
  - `RS_AmbientSoundSettings` at `scripts/ecs/resources/rs_ambient_sound_settings.gd` (enabled flag)
  - `resources/base_settings/audio/ambient_sound_default.tres` (default settings resource)
  - 2 ambient placeholder WAV files in `resources/audio/ambient/` (exterior: 80Hz, interior: 120Hz, 10s loops)
  - Added `S_AmbientSoundSystem` to all 3 gameplay scenes (gameplay_base, gameplay_exterior, gameplay_interior_house)
  - All tests passing (UI Phase 7: 5/5; full unit suite: 1371/1376 with 5 pending headless timing tests)

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/audio_manager/audio-manager-tasks.md`
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

- **Unit tests**: 1371 / 1376 passing
  - Phase 0 Redux: 51/51 ✅
  - Phase 1 Manager: 8/8 ✅
  - Phase 2 Music: 12/12 ✅
  - Phase 3 Base SFX: 15/15 ✅
  - Phase 4 SFX Systems: 61/61 ✅
  - Phase 5 Footstep: 35/35 ✅
  - Phase 6 Ambient: 10/10 ✅
  - Phase 7 UI Sounds: 5/5 ✅
- **Pending tests**: 5 (scene transition timing tests - headless mode incompatible)
- **Integration tests**: 100 / 100 passing (Phase 9 complete)

## Next Step

- Continue **Phase 10 (Manual QA)** in `docs/audio_manager/audio-manager-tasks.md` and complete the remaining checklist items.
- After each completed phase:
  - Update `docs/audio_manager/audio-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + "next step" ONLY
