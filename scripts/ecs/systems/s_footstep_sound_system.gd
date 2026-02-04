@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_FootstepSoundSystem

## Per-tick footstep sound system.
##
## Plays footstep sounds based on:
## - Entity movement (velocity > min_velocity)
## - Ground contact (is_on_floor)
## - Surface type detection (via C_SurfaceDetectorComponent)
## - Timing interval (step_interval)
##
## This is a per-tick system (not event-driven) because footsteps are based on
## continuous movement state rather than discrete events.

const SETTINGS_TYPE := preload("res://scripts/resources/ecs/rs_footstep_sound_settings.gd")
const SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")
const SURFACE_DETECTOR_TYPE := StringName("C_SurfaceDetectorComponent")
const FLOATING_TYPE := StringName("C_FloatingComponent")

@export var settings: SETTINGS_TYPE

## Per-entity timers tracking time since last footstep
## Key: CharacterBody3D, Value: float (time in seconds)
var _entity_timers: Dictionary = {}
var _warned_missing_manager: bool = false
var _warned_no_entities: bool = false
var _warned_missing_body: bool = false
const DEBUG_VERSION := "2026-02-03a"

var _debug_logged_ready: bool = false
var _debug_logged_tick: bool = false
var _debug_logged_camera: bool = false
var _debug_logged_entity_state: bool = false
var _debug_logged_no_sounds: bool = false
var _debug_logged_play: bool = false

## Injected state store (for testing and pause detection)
@export var state_store: I_StateStore = null

func _exit_tree() -> void:
	# Phase 6.10: Clean up entity timers to prevent memory leaks
	_entity_timers.clear()

func _ready() -> void:
	super._ready()
	if _debug_logged_ready:
		return
	_debug_logged_ready = true
	var script_path: String = "<no script>"
	var script_obj: Script = get_script()
	if script_obj != null:
		script_path = String(script_obj.resource_path)
	print("S_FootstepSoundSystem[%s]: ready at %s script=%s" % [
		DEBUG_VERSION,
		String(get_path()),
		script_path
	])

func process_tick(delta: float) -> void:
	if not _debug_logged_tick and (OS.is_debug_build() or Engine.is_editor_hint()):
		_debug_logged_tick = true
		print("S_FootstepSoundSystem[%s]: tick settings=%s" % [DEBUG_VERSION, settings != null])
	if not _debug_logged_camera:
		_debug_logged_camera = true
		var camera := ECS_UTILS.get_active_camera(self)
		var camera_path := "<none>"
		if camera != null and is_instance_valid(camera):
			camera_path = String(camera.get_path())
		print("S_FootstepSoundSystem: active_camera=%s" % camera_path)
	# Early exit if disabled or no settings
	if settings == null or not settings.enabled:
		return

	# Check pause state (skip if no state store available, e.g., in tests)
	var store: I_StateStore = state_store
	if store == null:
		# Try to find store in scene tree (only in production)
		if not Engine.is_editor_hint():
			store = U_StateUtils.try_get_store(self)

	if store != null:
		var gameplay_state: Dictionary = store.get_slice(StringName("gameplay"))
		if U_GameplaySelectors.get_is_paused(gameplay_state):
			return

	# Get manager
	var manager := get_manager()
	if manager == null:
		if not _warned_missing_manager:
			_warned_missing_manager = true
			push_warning("S_FootstepSoundSystem: ECS manager not found; footsteps will not play. Ensure M_ECSManager is present or injected.")
		return

	# Query entities that have surface detector components (floating is optional)
	var entities := manager.query_entities(
		[SURFACE_DETECTOR_TYPE],
		[FLOATING_TYPE]
	)
	if entities.is_empty():
		if not _warned_no_entities and Engine.get_physics_frames() > 5:
			_warned_no_entities = true
			push_warning("S_FootstepSoundSystem: No entities with C_SurfaceDetectorComponent registered. Check player prefab/component wiring.")
		return
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)

	for entity_query in entities:
		var surface_detector := entity_query.get_component(SURFACE_DETECTOR_TYPE) as C_SurfaceDetectorComponent
		if surface_detector == null:
			continue

		# Get the entity's CharacterBody3D via the wired character_body_path
		var body := surface_detector.get_character_body()
		if body == null:
			if not _warned_missing_body:
				_warned_missing_body = true
				push_warning("S_FootstepSoundSystem: Surface detector has no CharacterBody3D (invalid character_body_path).")
			continue

		# Get floating component if available (for hover-based characters)
		var floating_component: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		if floating_component == null:
			floating_component = floating_by_body.get(body, null) as C_FloatingComponent

		# Process footstep logic for this entity
		_process_entity_footstep(body, surface_detector, floating_component, delta)

func _process_entity_footstep(body: CharacterBody3D, surface_detector: C_SurfaceDetectorComponent, floating_component: C_FloatingComponent, delta: float) -> void:
	"""Process footstep logic for a single entity."""
	# Check if entity is on the ground
	# Support both traditional is_on_floor() and floating component's grounded state
	var is_on_floor_raw: bool = body.is_on_floor()
	var floating_grounded: bool = false
	if floating_component != null:
		floating_grounded = floating_component.grounded_stable
	var is_grounded: bool = is_on_floor_raw or floating_grounded
	if not _debug_logged_entity_state:
		_debug_logged_entity_state = true
		print("S_FootstepSoundSystem: entity=%s grounded=%s is_on_floor=%s floating_grounded=%s speed=%.2f min_velocity=%.2f" % [
			String(body.name),
			is_grounded,
			is_on_floor_raw,
			floating_grounded,
			Vector3(body.velocity.x, 0, body.velocity.z).length(),
			settings.min_velocity
		])

	if not is_grounded:
		# Reset timer when airborne so footstep plays immediately on landing
		_entity_timers.erase(body)
		return

	# Check velocity threshold
	var horizontal_velocity := Vector3(body.velocity.x, 0, body.velocity.z)
	var speed := horizontal_velocity.length()

	if speed < settings.min_velocity:
		# Reset timer when not moving
		_entity_timers.erase(body)
		return

	# Update timer
	var base_interval: float = max(settings.step_interval, 0.05)
	var reference_speed: float = max(settings.reference_speed, settings.min_velocity)
	var speed_ratio: float = reference_speed / max(speed, 0.001)
	var effective_interval: float = base_interval * sqrt(speed_ratio)
	effective_interval = clampf(effective_interval, 0.2, base_interval * 2.0)

	var time_since_last_step: float = _entity_timers.get(body, effective_interval)
	time_since_last_step += delta

	# Check if interval elapsed
	if time_since_last_step < effective_interval:
		_entity_timers[body] = time_since_last_step
		return

	# Play footstep sound
	_play_footstep(body, surface_detector)

	# Reset timer
	_entity_timers[body] = 0.0

func _play_footstep(body: CharacterBody3D, surface_detector: C_SurfaceDetectorComponent) -> void:
	"""Play a footstep sound at the entity's position."""
	# Detect surface type
	var surface_type := surface_detector.detect_surface()

	# Get sounds for this surface
	var sounds := settings.get_sounds_for_surface(surface_type)

	# Early exit if no sounds available
	if sounds.size() == 0:
		if not _debug_logged_no_sounds:
			_debug_logged_no_sounds = true
			print("S_FootstepSoundSystem: no sounds for surface=%s (default=%d grass=%d stone=%d wood=%d metal=%d water=%d)" % [
				str(surface_type),
				settings.default_sounds.size(),
				settings.grass_sounds.size(),
				settings.stone_sounds.size(),
				settings.wood_sounds.size(),
				settings.metal_sounds.size(),
				settings.water_sounds.size()
			])
		return

	# Select random sound from variations
	var sound_index := randi() % sounds.size()
	var stream := sounds[sound_index]
	if not _debug_logged_play:
		_debug_logged_play = true
		var bus_idx := AudioServer.get_bus_index("Footsteps")
		var bus_vol := AudioServer.get_bus_volume_db(bus_idx) if bus_idx >= 0 else 0.0
		var bus_muted := AudioServer.is_bus_mute(bus_idx) if bus_idx >= 0 else false
		var stream_path := ""
		if stream != null:
			stream_path = String(stream.resource_path)
		print("S_FootstepSoundSystem: play surface=%s sounds=%d stream=%s bus=Footsteps vol_db=%.2f muted=%s" % [
			str(surface_type),
			sounds.size(),
			stream_path,
			bus_vol,
			bus_muted
		])

	# Apply pitch variation (±5%)
	var pitch_scale := randf_range(0.95, 1.05)

	# Get position from body
	var position := body.global_position

	# Spawn 3D sound via U_SFXSpawner
	SFX_SPAWNER.spawn_3d({
		"audio_stream": stream,
		"position": position,
		"volume_db": settings.volume_db,
		"pitch_scale": pitch_scale,
		"bus": "Footsteps",
		"debug_emitter": body,
	})
