@icon("res://assets/editor_icons/system.svg")
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

## Injected state store (for testing and pause detection)
@export var state_store: I_StateStore = null

func process_tick(delta: float) -> void:
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
		return

	# Query entities that have surface detector components (floating is optional)
	var entities := manager.query_entities(
		[SURFACE_DETECTOR_TYPE],
		[FLOATING_TYPE]
	)
	var floating_by_body: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_TYPE)

	for entity_query in entities:
		var surface_detector := entity_query.get_component(SURFACE_DETECTOR_TYPE) as C_SurfaceDetectorComponent
		if surface_detector == null:
			continue

		# Get the entity's CharacterBody3D via the wired character_body_path
		var body := surface_detector.get_character_body()
		if body == null:
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
		return

	# Select random sound from variations
	var sound_index := randi() % sounds.size()
	var stream := sounds[sound_index]

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
	})
