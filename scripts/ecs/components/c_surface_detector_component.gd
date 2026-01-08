@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_SurfaceDetectorComponent

const COMPONENT_TYPE := StringName("C_SurfaceDetectorComponent")

## Component that detects surface types beneath the entity via raycast.
##
## Detects surface types by casting a ray downward and reading metadata
## from collision objects. Used by S_FootstepSoundSystem to play
## appropriate footstep sounds for different surfaces.
##
## Surface types are set via meta("surface_type") on collision objects:
##   floor.set_meta("surface_type", C_SurfaceDetectorComponent.SurfaceType.GRASS)

enum SurfaceType {
	DEFAULT,
	GRASS,
	STONE,
	WOOD,
	METAL,
	WATER
}

var _raycast: RayCast3D

func _ready() -> void:
	super._ready()  # Register with ECS manager
	_raycast = RayCast3D.new()
	_raycast.name = "RayCast3D"
	_raycast.enabled = true
	_raycast.target_position = Vector3(0, -1.0, 0)  # Cast downward 1 meter
	_raycast.collision_mask = 1  # Layer 1 = world geometry
	add_child(_raycast)

## Returns the surface type beneath this detector.
## Returns DEFAULT if no collision, collider is null, or metadata is missing/invalid.
func detect_surface() -> SurfaceType:
	if not _raycast.is_colliding():
		return SurfaceType.DEFAULT

	var collider := _raycast.get_collider()
	if collider == null:
		return SurfaceType.DEFAULT

	if collider.has_meta("surface_type"):
		var surface_meta: Variant = collider.get_meta("surface_type")
		# Verify metadata is a valid int (enum value)
		if surface_meta is int:
			return surface_meta as SurfaceType
		else:
			return SurfaceType.DEFAULT

	return SurfaceType.DEFAULT
