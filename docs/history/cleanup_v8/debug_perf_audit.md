# Cleanup V8 P2.1 — Debug/Perf Audit (Post-P1.10)

Date: 2026-04-23  
Branch: `cleanup-v8`  
Scope roots: `scripts/managers/**`, `scripts/ecs/systems/**`

## Audit Commands

```bash
rg -n "\bprint\s*\(" scripts/managers scripts/ecs/systems
rg -n "push_warning\s*\(" scripts/managers scripts/ecs/systems
rg -n "Time\.get_ticks_(msec|usec)|OS\.get_ticks_(msec|usec)|Engine\.get_physics_frames\(" scripts/managers scripts/ecs/systems
rg -n "U_PerfProbe" scripts/managers scripts/ecs/systems
rg -n "U_DebugLogThrottle" scripts/managers scripts/ecs/systems
```

## Summary

| Category | Count | Classification |
|---|---:|---|
| bare `print(...)` sites | 39 | pollution |
| `push_warning(...)` sites | 57 | warning-signal (review for intent per-site in P2.3/P2.4) |
| inline timer/frame APIs | 21 | timing (mixed: runtime needs + instrumentation) |
| `U_PerfProbe` usage sites | 20 | perf-probe (consolidated baseline) |
| `U_DebugLogThrottle` usage sites | 1 | throttled-log (consolidated baseline) |

## Inventory — bare print() (pollution)

Each row is one grep site.

```text
scripts/managers/m_save_manager.gd:142:	print("M_SaveManager: Importing legacy save user://savegame.json -> %s" % autosave_path)
scripts/managers/m_save_manager.gd:147:		print("M_SaveManager: Successfully imported legacy save to autosave slot")
scripts/ecs/systems/s_victory_handler_system.gd:29:	print("[VictoryDebug][S_VictoryHandlerSystem] %s" % message)
scripts/ecs/systems/s_spawn_recovery_system.gd:285:	print("S_SpawnRecoverySystem[entity=%s] %s" % [str(entity_id), message])
scripts/ecs/systems/helpers/u_vcam_look_input.gd:161:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:83:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:127:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:148:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:188:		print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:193:		print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:226:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:250:	print(
scripts/ecs/systems/helpers/u_vcam_debug.gd:265:	print("S_VCamSystem[debug] %s: %s" % [str(vcam_id), message])
scripts/ecs/systems/helpers/u_vcam_debug.gd:273:	print(
scripts/ecs/systems/helpers/u_vcam_look_spring.gd:391:	print(
scripts/managers/m_run_coordinator_manager.gd:142:	print("M_RunCoordinatorManager: WARNING %s" % message)
scripts/managers/helpers/u_vcam_collision_detector.gd:253:	print(
scripts/managers/m_scene_director_manager.gd:126:		print(
scripts/ecs/systems/s_move_target_follower_system.gd:244:	print("S_MoveTargetFollowerSystem[entity=%s] %s%s" % [str(entity_id), message, render_probe])
scripts/ecs/systems/s_move_target_follower_system.gd:251:	print("S_MoveTargetFollowerSystem: query_entities([C_InputComponent, C_MovementComponent]) returned 0 entities")
scripts/managers/m_scene_manager.gd:174:	print("[VictoryDebug][M_SceneManager] %s" % message)
scripts/ecs/systems/s_movement_system.gd:277:					print(
scripts/ecs/systems/s_movement_system.gd:492:	print("S_MovementSystem[entity=%s] %s" % [str(entity_id), message])
scripts/ecs/systems/s_gravity_system.gd:154:	print("S_GravitySystem[entity=%s] %s" % [str(entity_id), message])
scripts/ecs/systems/s_floating_system.gd:249:			print(
scripts/ecs/systems/s_floating_system.gd:382:	print("S_FloatingSystem[entity=%s] %s" % [str(entity_id), message])
scripts/ecs/systems/s_input_system.gd:375:	print("S_InputSystem[debug]: %s" % message)
scripts/ecs/systems/s_rotate_to_input_system.gd:73:				print("S_RotateToInputSystem: target missing. entity=%s path=%s" % [
scripts/ecs/systems/s_rotate_to_input_system.gd:82:				print("S_RotateToInputSystem: input component missing. entity=%s" % ["%s" % [entity_id]])
scripts/ecs/systems/s_rotate_to_input_system.gd:88:				print("S_RotateToInputSystem: move_vector zero. entity=%s yaw=%.2f" % [
scripts/ecs/systems/s_rotate_to_input_system.gd:128:			print("S_RotateToInputSystem: entity=%s move=%s desired_yaw=%.2f current_yaw=%.2f vel_yaw=%s cam_yaw=%s" % [
scripts/managers/m_vcam_manager.gd:883:	print("[VCAM_OCCLUSION][VCamManager] %s" % message)
scripts/ecs/systems/s_ai_detection_system.gd:176:		print("[DETECT] %s (%s/%s) → detected %s at dist %.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:180:			print("[DETECT_TRACE] source=%s target_tag=%s candidates=%d nearest=%s tags=%s dist=%.1f enter_radius=%.1f exit_radius=%.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:222:			print("[DETECT] %s (%s/%s) → switched %s → %s at dist %.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:231:				print("[DETECT_TRACE] source=%s target_tag=%s candidates=%d switched_from=%s switched_to=%s tags=%s dist=%.1f enter_radius=%.1f exit_radius=%.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:248:		print("[DETECT] %s (%s/%s) → switched %s → %s at dist %.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:257:			print("[DETECT_TRACE] source=%s target_tag=%s candidates=%d switched_from=%s switched_to=%s tags=%s dist=%.1f enter_radius=%.1f exit_radius=%.1f" % [
scripts/ecs/systems/s_ai_detection_system.gd:275:	print("[DETECT] %s (%s/%s) → lost %s (dist %.1f > exit_radius %.1f)" % [
```

## Inventory — push_warning() (warning-signal)

Each row is one grep site.

```text
scripts/managers/m_save_manager.gd:80:		push_warning("M_SaveManager: No M_SceneManager registered with ServiceLocator")
scripts/managers/m_objectives_manager.gd:116:			push_warning("M_ObjectivesManager: Duplicate objective_id '%s' in set '%s'" % [
scripts/managers/m_objectives_manager.gd:198:			push_warning("M_ObjectivesManager: Condition missing evaluate(context): %s" % str(condition))
scripts/managers/m_objectives_manager.gd:224:			push_warning("M_ObjectivesManager: Effect missing execute(context): %s" % str(effect))
scripts/managers/m_objectives_manager.gd:348:			push_warning("M_ObjectivesManager: Duplicate objective set_id '%s'" % String(set_id))
scripts/managers/m_objectives_manager.gd:387:			push_warning("M_ObjectivesManager: Ignoring navigation/start_game because no objective set is available for reset.")
scripts/managers/m_objectives_manager.gd:391:			push_warning("M_ObjectivesManager: Failed to reset objective set '%s' on navigation/start_game." % str(set_id))
scripts/managers/m_objectives_manager.gd:489:			push_warning("M_ObjectivesManager: Failed to reload objective set '%s' for runtime recovery." % str(set_id))
scripts/ecs/systems/s_victory_handler_system.gd:89:		push_warning("S_VictoryHandlerSystem: victory_execution_requested missing required payload.trigger_node")
scripts/managers/helpers/display/u_display_post_process_applier.gd:128:		push_warning("U_DisplayPostProcessApplier: post_process_overlay service is not a Node")
scripts/managers/helpers/display/u_display_post_process_applier.gd:134:			push_warning("U_DisplayPostProcessApplier: game_viewport service not found, cannot add post-process overlay")
scripts/managers/helpers/display/u_display_post_process_applier.gd:177:		push_warning("U_DisplayPostProcessApplier: Cannot setup UI color blind layer, tree/root not available")
scripts/managers/helpers/display/u_display_window_applier.gd:107:		push_warning("U_DisplayWindowApplier: Window mode '%s' did not settle after retries" % mode)
scripts/managers/helpers/display/u_display_window_applier.gd:162:			push_warning("U_DisplayWindowApplier: Invalid window mode '%s'" % mode)
scripts/managers/helpers/display/u_display_quality_applier.gd:58:		push_warning("U_DisplayQualityApplier: Unknown quality preset '%s'" % preset)
scripts/managers/helpers/display/u_display_quality_applier.gd:73:			push_warning("U_DisplayQualityApplier: Unknown shadow quality '%s'" % shadow_quality)
scripts/managers/helpers/display/u_display_quality_applier.gd:97:			push_warning("U_DisplayQualityApplier: Unknown anti-aliasing '%s'" % anti_aliasing)
scripts/managers/helpers/u_sfx_spawner.gd:84:		push_warning("U_SFXSpawner.initialize: parent is null")
scripts/managers/helpers/u_sfx_spawner.gd:210:	push_warning("U_SFXSpawner.spawn_3d: SFX pool not initialized. Ensure M_AudioManager is in the scene or call U_SFXSpawner.initialize(...) before playing SFX.")
scripts/managers/helpers/u_sfx_spawner.gd:277:	push_warning("Unknown audio bus '%s', falling back to 'SFX'" % bus)
scripts/ecs/systems/s_checkpoint_handler_system.gd:39:		push_warning("S_CheckpointHandlerSystem: checkpoint_activation_requested missing required payload.checkpoint")
scripts/ecs/systems/s_checkpoint_handler_system.gd:42:		push_warning("S_CheckpointHandlerSystem: checkpoint_activation_requested missing required payload.spawn_point_id")
scripts/managers/helpers/u_audio_registry_loader.gd:114:			push_warning("U_AudioRegistryLoader: Music track '%s' has null stream" % track_id)
scripts/managers/helpers/u_audio_registry_loader.gd:119:			push_warning("U_AudioRegistryLoader: Ambient track '%s' has null stream" % ambient_id)
scripts/managers/helpers/u_audio_registry_loader.gd:124:			push_warning("U_AudioRegistryLoader: UI sound '%s' has null stream" % sound_id)
scripts/managers/helpers/u_audio_registry_loader.gd:130:			push_warning("U_AudioRegistryLoader: Scene '%s' references invalid music track '%s'" % [scene_id, mapping.music_track_id])
scripts/managers/helpers/u_audio_registry_loader.gd:132:			push_warning("U_AudioRegistryLoader: Scene '%s' references invalid ambient track '%s'" % [scene_id, mapping.ambient_track_id])
scripts/managers/m_spawn_manager.gd:54:		push_warning("M_SpawnManager: M_StateStore dependency not found. Ensure M_StateStore is registered with ServiceLocator")
scripts/ecs/systems/s_wall_visibility_system.gd:526:	push_warning(message)
scripts/managers/helpers/u_save_file_io.gd:51:			push_warning("Failed to create backup: %s (error %d)" % [bak_path, backup_error])
scripts/managers/helpers/u_save_file_io.gd:75:				push_warning("Main save file corrupted, attempting backup: %s" % file_path)
scripts/managers/helpers/u_save_file_io.gd:79:					push_warning("Successfully recovered from backup: %s" % backup_path)
scripts/managers/helpers/u_save_file_io.gd:92:				push_warning("Successfully recovered from backup: %s" % bak_path)
scripts/managers/helpers/u_save_file_io.gd:116:					push_warning("Cleaned up orphaned temporary file: %s" % tmp_path)
scripts/managers/helpers/u_save_file_io.gd:135:			push_warning("Save file is empty: %s" % file_path)
scripts/managers/m_time_manager.gd:36:		push_warning("M_TimeManager: M_StateStore not ready during _ready(). Deferring initialization.")
scripts/managers/m_audio_manager.gd:197:		push_warning("M_AudioManager: Unknown music track '%s'" % String(track_id))
scripts/managers/m_audio_manager.gd:202:		push_warning("M_AudioManager: Music track '%s' has no stream" % String(track_id))
scripts/managers/m_audio_manager.gd:224:		push_warning("M_AudioManager: Unknown ambient track '%s'" % String(ambient_id))
scripts/managers/m_audio_manager.gd:229:		push_warning("M_AudioManager: Ambient track '%s' has no stream" % String(ambient_id))
scripts/ecs/systems/s_footstep_sound_system.gd:53:			push_warning("S_FootstepSoundSystem: ECS manager not found; footsteps will not play. Ensure M_ECSManager is present or injected.")
scripts/ecs/systems/s_footstep_sound_system.gd:67:			push_warning("S_FootstepSoundSystem: No entities with C_SurfaceDetectorComponent registered. Check player prefab/component wiring.")
scripts/ecs/systems/s_footstep_sound_system.gd:82:				push_warning("S_FootstepSoundSystem: Surface detector has no CharacterBody3D (invalid character_body_path).")
scripts/managers/helpers/u_audio_bus_constants.gd:41:				push_warning("U_AudioBusConstants: Required audio bus '%s' is missing" % bus_name)
scripts/managers/helpers/u_audio_bus_constants.gd:52:			push_warning("U_AudioBusConstants: Bus '%s' not found, falling back to Master" % bus_name)
scripts/managers/m_ecs_manager.gd:125:		push_warning("Attempted to register a null component")
scripts/managers/m_ecs_manager.gd:237:		push_warning("Attempted to register a null system")
scripts/managers/m_ecs_manager.gd:252:		push_warning("M_ECSManager.query_entities called without required component types")
scripts/managers/m_ecs_manager.gd:342:		push_warning("M_ECSManager.query_entities_readonly called without required component types")
scripts/managers/m_scene_manager.gd:195:		push_warning("M_SceneManager: No M_CursorManager registered with ServiceLocator")
scripts/managers/m_scene_manager.gd:200:		push_warning("M_SceneManager: No M_SpawnManager registered with ServiceLocator")
scripts/managers/m_scene_manager.gd:205:		push_warning("M_SceneManager: No M_CameraManager registered with ServiceLocator")
scripts/managers/m_scene_manager.gd:309:		push_warning("M_SceneManager: No HUDLayer registered with ServiceLocator")
scripts/managers/m_scene_manager.gd:375:		push_warning("M_SceneManager: victory_routing missing target_scene")
scripts/managers/m_camera_manager.gd:82:		push_warning("M_CameraManager: No camera state available for blending")
scripts/ecs/systems/s_death_handler_system.gd:41:		push_warning("S_DeathHandlerSystem: entity_death_requested missing required payload.entity_id")
scripts/ecs/systems/s_death_handler_system.gd:54:		push_warning("S_DeathHandlerSystem: entity_respawn_requested missing required payload.entity_id")
```

## Inventory — inline timer/frame APIs

Each row is one grep site.

```text
scripts/managers/helpers/display/u_post_process_pipeline.gd:75:	var wall_time: float = float(Time.get_ticks_usec()) / 1_000_000.0
scripts/managers/helpers/u_sfx_spawner.gd:195:	_play_times[player] = Time.get_ticks_msec()
scripts/ecs/systems/s_ai_detection_system.gd:281:	detection.last_target_change_frame = int(Engine.get_physics_frames())
scripts/ecs/systems/s_ai_detection_system.gd:286:	var current_frame: int = int(Engine.get_physics_frames())
scripts/ecs/systems/s_rotate_to_input_system.gd:247:	var frame: int = Engine.get_physics_frames()
scripts/managers/m_scene_manager.gd:697:	_pause_suppressed_physics_frame = Engine.get_physics_frames()
scripts/managers/m_scene_manager.gd:702:		and _pause_suppressed_physics_frame == Engine.get_physics_frames()
scripts/managers/helpers/u_autosave_scheduler.gd:120:	var now := Time.get_ticks_msec() / 1000.0
scripts/managers/helpers/u_autosave_scheduler.gd:201:	var now := Time.get_ticks_msec() / 1000.0
scripts/managers/helpers/u_autosave_scheduler.gd:246:		_last_autosave_time = Time.get_ticks_msec() / 1000.0
scripts/managers/m_ecs_manager.gd:782:			var sys_start: int = Time.get_ticks_usec()
scripts/managers/m_ecs_manager.gd:784:			var sys_elapsed: int = Time.get_ticks_usec() - sys_start
scripts/managers/m_vcam_manager.gd:157:		"frame": Engine.get_physics_frames(),
scripts/managers/m_vcam_manager.gd:274:	var current_frame: int = Engine.get_physics_frames()
scripts/managers/m_vcam_manager.gd:475:	var frame_id: int = Engine.get_physics_frames()
scripts/managers/m_vcam_manager.gd:811:	var current_frame: int = Engine.get_physics_frames()
scripts/managers/m_vcam_manager.gd:832:		Engine.get_physics_frames(),
scripts/managers/m_spawn_manager.gd:298:			var current_frame: int = Engine.get_physics_frames()
scripts/ecs/systems/s_jump_system.gd:54:	var current_physics_frame: int = Engine.get_physics_frames()
scripts/ecs/systems/s_movement_system.gd:67:	var current_physics_frame: int = Engine.get_physics_frames()
scripts/ecs/systems/s_footstep_sound_system.gd:65:		if not _warned_no_entities and Engine.get_physics_frames() > 5:
```

## Inventory — U_PerfProbe sites (consolidated)

Each row is one grep site.

```text
scripts/ecs/systems/s_region_visibility_system.gd:44:var _perf_probe: U_PerfProbe = null
scripts/ecs/systems/s_region_visibility_system.gd:45:var _fade_probe: U_PerfProbe = null
scripts/ecs/systems/s_region_visibility_system.gd:53:	_perf_probe = U_PerfProbe.create("RegionVis", _is_mobile)
scripts/ecs/systems/s_region_visibility_system.gd:54:	_fade_probe = U_PerfProbe.create("RegionFadeApply", _is_mobile)
scripts/managers/m_display_manager.gd:61:var _perf_probe: U_PerfProbe = null
scripts/managers/m_display_manager.gd:72:	_perf_probe = U_PerfProbe.create("FilmGrain", _is_mobile_perf)
scripts/ecs/systems/s_movement_system.gd:39:var _perf_probe: U_PerfProbe = null
scripts/ecs/systems/s_movement_system.gd:43:	_perf_probe = U_PerfProbe.create("S_MovementSystem", _is_mobile)
scripts/ecs/systems/s_wall_visibility_system.gd:43:var _perf_probe: U_PerfProbe = null
scripts/ecs/systems/s_wall_visibility_system.gd:44:var _shader_probe: U_PerfProbe = null
scripts/ecs/systems/s_wall_visibility_system.gd:76:	_perf_probe = U_PerfProbe.create("WallVis", _is_mobile)
scripts/ecs/systems/s_wall_visibility_system.gd:77:	_shader_probe = U_PerfProbe.create("WallVisShader", _is_mobile)
scripts/ecs/systems/s_landing_indicator_system.gd:13:var _perf_probe: U_PerfProbe = null
scripts/ecs/systems/s_landing_indicator_system.gd:20:	_perf_probe = U_PerfProbe.create("S_LandingIndicator", _is_mobile)
scripts/ecs/systems/s_floating_system.gd:30:var _perf_probe: U_PerfProbe = null
scripts/ecs/systems/s_floating_system.gd:43:	_perf_probe = U_PerfProbe.create("S_FloatingSystem", _is_mobile)
scripts/managers/m_character_lighting_manager.gd:48:var _perf_probe: U_PerfProbe = null
scripts/managers/m_character_lighting_manager.gd:49:var _apply_probe: U_PerfProbe = null
scripts/managers/m_character_lighting_manager.gd:54:	_perf_probe = U_PerfProbe.create("CharLighting", _is_mobile)
scripts/managers/m_character_lighting_manager.gd:55:	_apply_probe = U_PerfProbe.create("CharLightApply", _is_mobile)
```

## Inventory — U_DebugLogThrottle sites (consolidated)

Each row is one grep site.

```text
scripts/ecs/systems/s_ai_behavior_system.gd:31:var _debug_log_throttle: U_DebugLogThrottle = U_DEBUG_LOG_THROTTLE.new()
```

## Notes for P2.2/P2.3

- P2.2 should backfill tests for existing `U_PerfProbe` behavior (no rewrite).
- P2.3 should prioritize conversion/removal of bare `print(...)` sites in managers/systems.
- `push_warning(...)` is not auto-pollution; keep intentional warnings and only migrate noisy debug-warnings when justified.
- Keep this audit file as the baseline snapshot for post-migration diff checks in P2.4 enforcement.
