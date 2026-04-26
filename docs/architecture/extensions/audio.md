# Add Audio Track / Event

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new music track
- A new ambient track
- A new UI sound
- A new scene-audio mapping (music + ambient per scene)

This recipe does **not** cover:

- ECS SFX spawner usage (see `ecs.md`)
- Manager registration (see `managers.md`)
- State slice creation (see `state.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md)

## Canonical Example

- Music track: `resources/demo/audio/tracks/music_bar.tres` (`RS_MusicTrackDefinition`)
- Ambient track: `resources/demo/audio/ambient/ambient_exterior.tres` (`RS_AmbientTrackDefinition`)
- UI sound: `resources/demo/audio/ui/ui_confirm.tres` (`RS_UISoundDefinition`)
- Scene mapping: `resources/demo/audio/scene_mappings/scene_bar.tres` (`RS_SceneAudioMapping`)
- Registry: `scripts/core/managers/helpers/u_audio_registry_loader.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `M_AudioManager` | Singleton. `play_music()`, `stop_music()`, `play_ambient()`, `stop_ambient()`, `play_ui_sound()`. |
| `U_AudioRegistryLoader` | Static O(1) dictionaries: `_music_tracks`, `_ambient_tracks`, `_ui_sounds`, `_scene_audio_map`. |
| `U_CrossfadePlayer` | Handles music/ambient crossfades. |
| `U_SFXSpawner` | 16-voice 3D SFX pool with voice stealing. |
| `U_AudioBusConstants` | Bus layout: Master → Music, SFX (UI, Footsteps), Ambient. |

Registry IDs are plain lowercase StringNames matching the `.tres` filename stem.

## Recipe

### Adding a new music track

1. Create `RS_MusicTrackDefinition` `.tres` under `resources/demo/audio/tracks/` named `music_<id>.tres`. Set `track_id`, `stream`, `default_fade_duration`, `base_volume_offset_db`, `loop`, `pause_behavior`.
2. Register in `U_AudioRegistryLoader._register_music_tracks()`: add `preload()` + `_music_tracks[StringName("<id>")]`.

### Adding a new ambient track

1. Create `RS_AmbientTrackDefinition` `.tres` under `resources/demo/audio/ambient/` named `ambient_<id>.tres`. Set fields.
2. Register in `U_AudioRegistryLoader._register_ambient_tracks()`.

### Adding a new UI sound

1. Create `RS_UISoundDefinition` `.tres` under `resources/demo/audio/ui/` named `ui_<id>.tres`. Set `sound_id`, `stream`, `volume_db`, `pitch_variation`, `throttle_ms`.
2. Register in `U_AudioRegistryLoader._register_ui_sounds()`.
3. Call: `U_AudioUtils.get_audio_manager().play_ui_sound(StringName("ui_<id>"))`.

### Adding a new scene audio mapping

1. Create `RS_SceneAudioMapping` `.tres` under `resources/demo/audio/scene_mappings/` named `scene_<scene_id>.tres`. Set `scene_id`, `music_track_id`, `ambient_track_id`. Empty `StringName` = no audio for that category.
2. Register in `U_AudioRegistryLoader._register_scene_audio_mappings()`.

## Anti-patterns

- **Calling `AudioServer.set_bus_volume_db` directly**: All volume/mute changes go through Redux actions.
- **Unregistered tracks**: A `.tres` without a registry entry is never found; `get_music_track()` returns null.
- **Creating `AudioStreamPlayer` nodes for music/ambient directly**: Use `M_AudioManager.play_music()` / `play_ambient()` for proper crossfading.
- **Missing bus validation**: If buses are misconfigured, `validate_bus_layout()` returns false. All operations fall back to Master.
- **UI sound polyphony**: Capped at 4 round-robin players. Rapid navigation reuses players.

## Out Of Scope

- ECS component/system: see `ecs.md`
- Manager registration: see `managers.md`
- State slice: see `state.md`

## References

- [Audio Manager Guide](../../systems/audio_manager/AUDIO_MANAGER_GUIDE.md)