# Audio Manager - Continuation Prompt

## Current Status

- **Implementation status**: Phase 0–2 complete (Audio Redux slice + M_AudioManager bus layout + volume/mute + music crossfade + scene/pause music switching)
- **Main scene**: `scenes/root.tscn` (project `run/main_scene` points here)
- **Root bootstrap**: `scripts/scene_structure/main.gd` registers manager services via `U_ServiceLocator`

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`
- Use strict TDD against `docs/audio manager/audio-manager-tasks.md`
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`

## Repo Reality Checks (Do Not Skip)

- There is **no** `scenes/main.tscn` in this project; add `M_AudioManager` to `scenes/root.tscn` under `Managers/`.
- `U_ServiceLocator` lives at `res://scripts/core/u_service_locator.gd` and its API is `U_ServiceLocator.register(...)` / `get_service(...)` / `try_get_service(...)`.
- There is already a stub `S_JumpSoundSystem` at `scripts/ecs/systems/s_jump_sound_system.gd` (currently clears requests; no playback yet).
- `RS_GameplayInitialState` currently includes a small `gameplay.audio_settings` dictionary + `U_VisualSelectors.get_audio_settings()`; it is not currently used by any real audio playback path.
- There is no `resources/audio/` directory yet in this repo; any placeholder audio assets will need to be added with naming/prefix conventions in mind.

## Next Step

- Start at **Phase 3** in `docs/audio manager/audio-manager-tasks.md` and complete tasks in order.
- After each completed phase:
  - Update `docs/audio manager/audio-manager-tasks.md` checkboxes + completion notes
  - Update this file with the new current status + “next step” ONLY
