@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_SurfaceDetectorComponent

const COMPONENT_TYPE := StringName("C_SurfaceDetectorComponent")

## NodePath to the CharacterBody3D this detector is attached to.
## Must be wired in the scene editor.
@export_node_path("CharacterBody3D") var character_body_path: NodePath

## Component that detects surface types beneath the entity.
##
## Uses CharacterBody3D's floor collision to detect surface types.
## Surfaces are identified by collider name patterns (e.g., "grass", "stone", "wood").
## Fallback to surface-type providers when pattern matching fails.
##
## Used by S_FootstepSoundSystem to play appropriate footstep sounds.

enum SurfaceType {
	DEFAULT,
	GRASS,
	STONE,
	WOOD,
	METAL,
	WATER
}

var _raycast: RayCast3D
var _enable_attempts: int = 0
const _MAX_ENABLE_ATTEMPTS := 20

func _init() -> void:
	component_type = COMPONENT_TYPE

func _ready() -> void:
	super._ready()  # Register with ECS manager
	_setup_raycast()

func _setup_raycast() -> void:
	"""Creates and attaches a raycast to the CharacterBody3D for surface detection."""
	var body := get_character_body()
	if body == null:
		push_error("C_SurfaceDetectorComponent: character_body_path not set or invalid")
		return

	# Create raycast as child of CharacterBody3D so it follows the character
	_raycast = RayCast3D.new()
	_raycast.name = "SurfaceDetectorRay"
	# Do not enable immediately: when running inside the editor (GUT, tool runs),
	# there may be no valid 3D physics space, and RayCast3D will spam engine errors.
	_raycast.enabled = false
	_raycast.target_position = Vector3(0, -2.0, 0)  # Cast 2m down
	_raycast.collision_mask = 1  # Layer 1 = world geometry
	_raycast.hit_from_inside = true  # Allow detection even if starting inside collider
	body.add_child(_raycast)
	call_deferred("_try_enable_raycast")

func _try_enable_raycast() -> void:
	if _raycast == null or not is_instance_valid(_raycast):
		return
	if _raycast.enabled:
		return
	if not _raycast.is_inside_tree():
		return

	var world := _raycast.get_world_3d()
	if world == null or not world.space.is_valid():
		_enable_attempts += 1
		if _enable_attempts < _MAX_ENABLE_ATTEMPTS:
			call_deferred("_try_enable_raycast")
		return

	_raycast.enabled = true

## Returns the surface type beneath this detector.
## Uses raycast to identify surfaces (works for both grounded and floating characters).
## Returns DEFAULT if no collision or surface cannot be identified.
func detect_surface() -> SurfaceType:
	if _raycast == null or not is_instance_valid(_raycast):
		return SurfaceType.DEFAULT
	if not _raycast.is_inside_tree():
		return SurfaceType.DEFAULT
	var world := _raycast.get_world_3d()
	if world == null or not world.space.is_valid():
		return SurfaceType.DEFAULT

	# Force raycast update (it's attached to CharacterBody3D, so position is correct)
	_raycast.force_raycast_update()

	if not _raycast.is_colliding():
		return SurfaceType.DEFAULT

	var collider := _raycast.get_collider()
	if collider == null:
		return SurfaceType.DEFAULT

	# Try to identify surface by collider name pattern (case-insensitive)
	var detected_type := _identify_surface_by_name(collider.name)
	if detected_type != SurfaceType.DEFAULT:
		return detected_type

	var provided_type := _get_surface_type_from_provider(collider)
	if provided_type != SurfaceType.DEFAULT:
		return provided_type

	return SurfaceType.DEFAULT

## Identifies surface type by collider name patterns.
## Returns DEFAULT if no pattern matches.
func _identify_surface_by_name(collider_name: String) -> SurfaceType:
	var name_lower := collider_name.to_lower()

	# Check for grass/vegetation
	if name_lower.contains("grass") or name_lower.contains("lawn") or name_lower.contains("turf"):
		return SurfaceType.GRASS

	# Check for stone/rock/concrete
	if name_lower.contains("stone") or name_lower.contains("rock") or name_lower.contains("concrete") or name_lower.contains("brick"):
		return SurfaceType.STONE

	# Check for wood
	if name_lower.contains("wood") or name_lower.contains("plank") or name_lower.contains("timber"):
		return SurfaceType.WOOD

	# Check for metal
	if name_lower.contains("metal") or name_lower.contains("steel") or name_lower.contains("iron"):
		return SurfaceType.METAL

	# Check for water
	if name_lower.contains("water") or name_lower.contains("liquid") or name_lower.contains("puddle"):
		return SurfaceType.WATER

	return SurfaceType.DEFAULT

func _get_surface_type_from_provider(collider: Object) -> SurfaceType:
	if collider == null:
		return SurfaceType.DEFAULT
	if collider.has_method("get_surface_type"):
		var surface_value: Variant = collider.call("get_surface_type")
		if surface_value is int:
			var normalized: int = surface_value
			if normalized >= SurfaceType.DEFAULT and normalized <= SurfaceType.WATER:
				return normalized as SurfaceType
	return SurfaceType.DEFAULT

func _surface_type_to_string(type: SurfaceType) -> String:
	match type:
		SurfaceType.DEFAULT: return "DEFAULT"
		SurfaceType.GRASS: return "GRASS"
		SurfaceType.STONE: return "STONE"
		SurfaceType.WOOD: return "WOOD"
		SurfaceType.METAL: return "METAL"
		SurfaceType.WATER: return "WATER"
		_: return "UNKNOWN"

## Returns the CharacterBody3D this component is attached to.
## Returns null if character_body_path is not set or invalid.
func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path) as CharacterBody3D
